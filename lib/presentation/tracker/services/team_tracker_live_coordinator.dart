import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import '../models/action_tracker_protocol.dart';
import '../models/tracker_live_models.dart';
import 'action_tracker_ble_service.dart';
import 'team_action_tracker_ble_pool.dart';
import 'tracker_live_api.dart';

class TeamTrackerBinding {
  final int playerId;
  final String playerName;
  final String deviceUuid;
  final String deviceName;
  final int? batteryPercent;

  const TeamTrackerBinding({
    required this.playerId,
    required this.playerName,
    required this.deviceUuid,
    required this.deviceName,
    this.batteryPercent,
  });
}

class TeamTrackerChannelDebug {
  final int playerId;
  final String playerName;
  final String deviceUuid;
  final String deviceName;
  final bool bleReady;
  final int? liveSessionId;
  final DateTime? lastRxAt;
  final DateTime? lastGpsAt;
  final DateTime? lastServerSaveAt;
  final String? lastError;
  final int receivedPackets;
  final int savedPoints;
  final double totalDistanceM;
  final double lastSpeedKmh;
  final double maxSpeedKmh;
  final double avgSpeedKmh;
  final int recoveryCount;
  final bool serverGapActive;
  final bool backfillRequired;

  const TeamTrackerChannelDebug({
    required this.playerId,
    required this.playerName,
    required this.deviceUuid,
    required this.deviceName,
    required this.bleReady,
    required this.liveSessionId,
    required this.lastRxAt,
    required this.lastGpsAt,
    required this.lastServerSaveAt,
    required this.lastError,
    required this.receivedPackets,
    required this.savedPoints,
    required this.totalDistanceM,
    required this.lastSpeedKmh,
    required this.maxSpeedKmh,
    required this.avgSpeedKmh,
    required this.recoveryCount,
    required this.serverGapActive,
    required this.backfillRequired,
  });
}

class _TrackerGap {
  final DateTime from;
  final DateTime to;

  const _TrackerGap({required this.from, required this.to});

  Map<String, dynamic> toJson() => <String, dynamic>{
        'from_ms': from.millisecondsSinceEpoch,
        'to_ms': to.millisecondsSinceEpoch,
      };
}

class _Runtime {
  final TeamTrackerBinding binding;
  int? liveSessionId;
  bool txInFlight = false;
  DateTime? lastRxAt;
  DateTime? lastGpsAt;
  DateTime? lastServerSaveAt;
  String? lastError;
  int receivedPackets = 0;
  int savedPoints = 0;
  double totalDistanceM = 0;
  double lastSpeedKmh = 0;
  double maxSpeedKmh = 0;
  double speedSum = 0;
  int speedCount = 0;
  double? lastLat;
  double? lastLon;
  int? lastTimeMs;
  DateTime watchdogBaselineAt = DateTime.now();
  DateTime? lastDeviceKeepAliveAt;
  DateTime? lastRecoveryAttemptAt;
  int recoveryCount = 0;
  DateTime? liveStartedAt;
  DateTime? liveStoppedAt;
  int? finalSessionId;
  int? finalizedLiveSessionId;
  bool recoveryJobCreated = false;
  DateTime? bleGapStartedAt;
  DateTime? serverGapStartedAt;
  int? lastServerSavedPointTimeMs;
  ActionTrackerGpsPoint? lastPoint;
  final List<_TrackerGap> gaps = <_TrackerGap>[];
  bool backfillRequired = false;

  _Runtime(this.binding);
}

class _OfflineRecordMatch {
  final ActionTrackerRecord record;
  final int clockShiftMs;
  final int overlapMs;

  const _OfflineRecordMatch({
    required this.record,
    required this.clockShiftMs,
    required this.overlapMs,
  });
}

/// Одна командная тренировка на планшете, но отдельная активная строка сервера
/// и отдельный BLE-канал для каждого игрока/UUID.
class TeamTrackerLiveCoordinator {
  // BLE-пакет трекера не передаёт accuracy/HDOP, поэтому дрожание GPS
  // отсеиваем по минимальному смещению координат и скорости. Порог 1.5 км/ч
  // сохраняет обычную ходьбу, в отличие от прежних 4 км/ч.
  static const double _stationarySpeedDeadbandKmh = 1.5;
  static const double _stationaryCoordinateJitterM = 0.35;
  static const Duration _deviceKeepAliveInterval = Duration(seconds: 20);
  static const Duration _silentRxTimeout = Duration(seconds: 55);
  static const Duration _silentGpsTimeout = Duration(seconds: 75);
  static const Duration _disconnectedRecoveryDelay = Duration(seconds: 12);
  static const Duration _recoveryCooldown = Duration(seconds: 45);
  static const Duration _offlineRecoveryRetryInterval = Duration(seconds: 30);
  // Один и тот же Team Workspace может пережить hot-reload/переоткрытие окна,
  // поэтому в процессе иногда остаются несколько coordinator с одинаковыми
  // pending recovery jobs. In-flight guard защищает только от ОДНОВРЕМЕННОЙ
  // попытки, но после быстрого Apple `device not found` следующий coordinator
  // раньше тут же пробовал снова. Общий cooldown на process/team/device не даёт
  // таким экземплярам превращать recovery в reconnect/log storm.
  static const Duration _sharedAutoRecoveryCooldown = Duration(seconds: 90);
  static final Set<String> _sharedRecoveryInFlightDevices = <String>{};
  static final Map<String, DateTime> _sharedRecoveryNextAttemptAt =
      <String, DateTime>{};

  final int clubId;
  final int teamId;
  int? fieldId;
  final TeamActionTrackerBlePool pool;
  final TrackerLiveApi api;
  final String bleLeaseToken;
  final Map<String, _Runtime> _runtime = {};
  StreamSubscription<TeamTrackerBleEvent>? _dataSub;
  Timer? _heartbeat;
  Timer? _gpsScheduler;
  Timer? _bleWatchdog;
  int _gpsSchedulerCursor = 0;
  bool _heartbeatInFlight = false;
  bool _bleWatchdogInFlight = false;
  bool _running = false;
  bool _starting = false;
  bool _localOnly = false;
  bool _promotionInFlight = false;
  bool _stoppedLocalRunPending = false;
  DateTime? _pendingLocalStoppedAt;
  String? _clientSessionKey;
  DateTime? _lastPromotionAttemptAt;
  Timer? _offlineRecoveryRetryTimer;
  bool _offlineRecoveryRetryTickInFlight = false;
  final Map<String, TeamTrackerBinding> _recoveryBindingHints =
      <String, TeamTrackerBinding>{};
  final Set<String> _pendingRecoveryKeys = <String>{};
  int _offlineRecoveryTasks = 0;
  bool _persistentRecoveryLeaseHeld = false;
  bool _uiDetached = false;
  void Function(String message)? onRecoveryChanged;

  TeamTrackerLiveCoordinator({
    required this.clubId,
    required this.teamId,
    required this.pool,
    required this.bleLeaseToken,
    TrackerLiveApi? api,
    this.fieldId,
    this.onRecoveryChanged,
  }) : api = api ?? TrackerLiveApi();

  bool get running => _running || _starting;
  bool get localOnly => _localOnly;
  bool get offlineRecoveryBusy =>
      _offlineRecoveryTasks > 0 ||
      _pendingRecoveryKeys.isNotEmpty ||
      pool.offlineTransferActive ||
      _stoppedLocalRunPending;

  /// Снимок командного Live из BLE-памяти процесса. Панель использует его,
  /// когда HTTP недоступен: карта, игроки, скорость и дистанция продолжают
  /// обновляться локально, не ожидая ответа сервера.
  List<TrackerLiveSessionModel> get localLiveSessions {
    final now = DateTime.now();
    return _runtime.values.map((r) {
      final started = r.liveStartedAt ?? now;
      final duration = math.max(0, now.difference(started).inSeconds);
      final avg = r.speedCount == 0 ? 0.0 : r.speedSum / r.speedCount;
      final metersPerMinute = duration <= 0
          ? 0.0
          : r.totalDistanceM / (duration / 60.0);
      final point = r.lastPoint;
      final gpsFresh = r.lastGpsAt != null &&
          now.difference(r.lastGpsAt!) <= const Duration(seconds: 5);
      final liveSpeedKmh = gpsFresh ? r.lastSpeedKmh : 0.0;
      return TrackerLiveSessionModel(
        id: r.liveSessionId ?? _localSessionId(r.binding.playerId),
        clubId: clubId,
        teamId: teamId,
        playerId: r.binding.playerId,
        playerName: r.binding.playerName,
        deviceUuid: r.binding.deviceUuid,
        deviceName: r.binding.deviceName,
        fieldId: fieldId,
        status: _running ? 'active' : 'finished',
        source: _localOnly ? 'team_tracker_local_offline' : 'team_tracker_local',
        activityType: 'football_field',
        totalDistanceM: r.totalDistanceM,
        maxSpeedKmh: r.maxSpeedKmh,
        avgSpeedKmh: avg,
        metersPerMinute: metersPerMinute,
        loadScore: r.totalDistanceM / 100.0,
        loadPerMinute: duration <= 0
            ? 0.0
            : (r.totalDistanceM / 100.0) / (duration / 60.0),
        fatigueIndex: 0,
        speedDropPercent: 0,
        hsrDistanceM: 0,
        hirDistanceM: 0,
        vhirDistanceM: 0,
        sprintDistanceM: 0,
        sprintCount: 0,
        accelCount: 0,
        decelCount: 0,
        changeOfDirectionCount: 0,
        footballMovementScore: 0,
        metabolicPowerProxy: 0,
        durationSec: duration,
        latitude: point?.latitude,
        longitude: point?.longitude,
        speedKmh: liveSpeedKmh,
        batteryPercent: r.binding.batteryPercent,
        lastSeenAt: (r.lastGpsAt ?? r.lastRxAt ?? now).toUtc().toIso8601String(),
      );
    }).toList(growable: false);
  }

  int? liveSessionIdForPlayer(int playerId) {
    for (final runtime in _runtime.values) {
      if (runtime.binding.playerId == playerId) return runtime.liveSessionId;
    }
    return null;
  }

  List<TeamTrackerChannelDebug> get debugRows {
    final now = DateTime.now();
    return _runtime.values.map((r) {
      final gpsFresh = r.lastGpsAt != null &&
          now.difference(r.lastGpsAt!) <= const Duration(seconds: 5);
      return TeamTrackerChannelDebug(
          playerId: r.binding.playerId,
          playerName: r.binding.playerName,
          deviceUuid: r.binding.deviceUuid,
          deviceName: r.binding.deviceName,
          bleReady: pool.isConnected(r.binding.deviceUuid),
          liveSessionId: r.liveSessionId,
          lastRxAt: r.lastRxAt,
          lastGpsAt: r.lastGpsAt,
          lastServerSaveAt: r.lastServerSaveAt,
          lastError: r.lastError,
          receivedPackets: r.receivedPackets,
          savedPoints: r.savedPoints,
          totalDistanceM: r.totalDistanceM,
          lastSpeedKmh: gpsFresh ? r.lastSpeedKmh : 0.0,
          maxSpeedKmh: r.maxSpeedKmh,
          avgSpeedKmh: r.speedCount == 0 ? 0 : r.speedSum / r.speedCount,
          recoveryCount: r.recoveryCount,
          serverGapActive: r.serverGapStartedAt != null,
          backfillRequired: r.backfillRequired,
        );
      }).toList(growable: false);
  }

  Future<void> start(List<TeamTrackerBinding> bindings) async {
    if (_running || _starting) return;
    if (pool.livePolling) {
      throw StateError(
        'Командный Live уже работает в другом окне этой команды. Вернитесь в него или сначала выполните Stop.',
      );
    }
    // Ожидающие server recovery jobs больше не блокируют новый матч. Они уже
    // привязаны к своим final_session_id и безопасно продолжатся после Stop.
    // Но единственный ещё не зарегистрированный локальный матч нельзя стереть
    // новым _runtime: сначала пробуем отправить его на сервер.
    if (_stoppedLocalRunPending) {
      await _finalizeStoppedLocalRunIfPossible();
    }
    if (_stoppedLocalRunPending) {
      throw StateError(
        'Предыдущий локальный Live ещё не зарегистрирован на сервере. Подключите интернет и повторите Старт — GPS-запись сохранена в трекерах.',
      );
    }
    if (bindings.isEmpty)
      throw StateError('Нет привязанных GPS-трекеров команды');
    _starting = true;

    try {
      // Один ATP не может одновременно отдавать старый файл и текущий GPS.
      // Поэтому активную выгрузку не ждём до конца: безопасно закрываем её GATT,
      // переподключаем тот же точный ATP и сразу запускаем новый матч. Recovery
      // остаётся waiting и автоматически продолжится после Stop.
      final recoveryWasPending = offlineRecoveryBusy;
      final interruptedTransfers =
          await pool.pauseOfflineRecoveryForLive();
      if (recoveryWasPending || interruptedTransfers.isNotEmpty) {
        _notifyRecoveryChanged(
          'GPS recovery поставлен на паузу · новый Team Live имеет приоритет',
        );
      }
      if (interruptedTransfers.isNotEmpty) {
        await pool.ensureConnected(interruptedTransfers);
      }

      final startedAt = DateTime.now();
      _localOnly = false;
      _stoppedLocalRunPending = false;
      _pendingLocalStoppedAt = null;
      _releasePersistentRecoveryLeaseIfIdle();
      _clientSessionKey =
          'team_${teamId}_${startedAt.toUtc().millisecondsSinceEpoch}';
      final duplicateDevices = <String>{};
      final seenDevices = <String>{};
      final seenPlayers = <int>{};
      for (final b in bindings) {
        if (!seenDevices.add(b.deviceUuid)) duplicateDevices.add(b.deviceUuid);
        if (!seenPlayers.add(b.playerId)) {
          throw StateError(
              'Игрок ${b.playerName} привязан более чем к одному GPS');
        }
      }
      if (duplicateDevices.isNotEmpty) {
        throw StateError(
            'Один UUID назначен нескольким игрокам: ${duplicateDevices.join(', ')}');
      }

      _runtime.clear();
      for (final b in bindings) {
        if (!pool.isConnected(b.deviceUuid)) {
          throw StateError(
              'GPS ${b.deviceName} (${b.deviceUuid}) не подключён');
        }
        final runtime = _Runtime(b)
          ..liveStartedAt = startedAt
          ..watchdogBaselineAt = startedAt;
        _runtime[b.deviceUuid] = runtime;
        _rememberRecoveryBinding(b);
      }

      // С этого момента запрещаем всем остальным открытым workspace запускать
      // BLE scan. Одновременно освобождаем GATT-слоты от датчиков, которые не
      // входят в текущий состав: сохранённые серверные назначения не удаляются.
      pool.setLivePolling(true);
      await pool.disconnectExcept(seenDevices);

      // Все серверные строки создаются одной транзакцией. Это не оставляет
      // пять активных игроков, если шестой трекер не прошёл проверку.
      List<Map<String, dynamic>> serverSessions =
          const <Map<String, dynamic>>[];
      try {
        serverSessions = await _startServerSessions(
          bindings,
          startedAt: startedAt,
        );
      } catch (e) {
        // Конфликт BLE lease — это не потеря интернета. Второй планшет не должен
        // переходить в local-only и физически отбирать занятый GPS у владельца.
        if (_isBleLeaseConflict(e)) rethrow;
        // Интернет не является условием старта BLE Live. Назначаем локальные
        // положительные id, включаем GPS polling и позже автоматически
        // поднимаем серверные строки с тем же client_session_key.
        _localOnly = true;
        for (final runtime in _runtime.values) {
          runtime.liveSessionId = _localSessionId(runtime.binding.playerId);
          runtime.serverGapStartedAt = startedAt;
          runtime.backfillRequired = true;
          runtime.lastError =
              'Серверный Live пока не создан · запись идёт локально: $e';
        }
      }

      for (final item in serverSessions) {
        final uuid = '${item['device_uuid'] ?? ''}'.trim();
        final name = '${item['device_name'] ?? ''}'.trim();
        final playerId = int.tryParse('${item['player_id'] ?? 0}') ?? 0;
        final id =
            int.tryParse('${item['live_session_id'] ?? item['id'] ?? 0}') ?? 0;
        if (id <= 0) continue;

        _Runtime? target = _runtime[uuid];
        if (target == null) {
          for (final runtime in _runtime.values) {
            if (_samePhysicalTracker(
              runtime.binding.deviceUuid,
              runtime.binding.deviceName,
              uuid,
              name,
            )) {
              target = runtime;
              break;
            }
          }
        }
        if (target == null && playerId > 0) {
          for (final runtime in _runtime.values) {
            if (runtime.binding.playerId == playerId) {
              target = runtime;
              break;
            }
          }
        }
        if (target != null) {
          target.liveSessionId = id;
          target.liveStartedAt = startedAt;
        }
      }
      final missing = _runtime.values
          .where((r) => r.liveSessionId == null)
          .toList(growable: false);
      if (!_localOnly && missing.isNotEmpty) {
        throw StateError(
          'Сервер не создал Live для: ${missing.map((r) => r.binding.playerName).join(', ')}',
        );
      }

      _dataSub = pool.dataStream.listen(_onData);
      _running = true;
      unawaited(ActionTrackerBleService.setTrackerKeepScreenOn(true));
      _startGpsScheduler();
      _startBleWatchdog();
      _ensureOfflineRecoveryRetryTimer();

      _heartbeat = Timer.periodic(const Duration(seconds: 5), (_) async {
        if (_heartbeatInFlight) return;
        _heartbeatInFlight = true;
        try {
          if (_localOnly) {
            await _promoteActiveLocalLiveIfPossible();
            if (_localOnly) return;
          }
          try {
            await api.heartbeatBleTrackerLeases(
              teamId: teamId,
              leaseToken: bleLeaseToken,
            );
          } catch (_) {
            // Live GPS не зависит от сети. Lease продлится при следующем
            // успешном heartbeat; серверный TTL защищает от вечной блокировки.
          }
          await Future.wait(_runtime.values.map((r) async {
            final id = r.liveSessionId;
            if (id == null) return;
            try {
              await api.heartbeatLiveSession(
                liveSessionId: id,
                statusText:
                    'team_live:${pool.connectedCount}/${_runtime.length}',
              );
            } catch (e) {
              r.lastError = 'heartbeat: $e';
            }
          }));
        } finally {
          _heartbeatInFlight = false;
        }
      });
    } catch (_) {
      _running = false;
      pool.setLivePolling(false);
      try {
        await api.releaseBleTrackerLeases(
          teamId: teamId,
          leaseToken: bleLeaseToken,
        );
      } catch (_) {}
      _gpsScheduler?.cancel();
      _gpsScheduler = null;
      _bleWatchdog?.cancel();
      _bleWatchdog = null;
      unawaited(ActionTrackerBleService.setTrackerKeepScreenOn(false));
      _heartbeat?.cancel();
      _heartbeat = null;
      await _dataSub?.cancel();
      _dataSub = null;
      for (final r in _runtime.values) {
        final id = r.liveSessionId;
        if (id == null || _localOnly) continue;
        try {
          await api.stopLiveSession(
              liveSessionId: id, createFinalSession: false);
        } catch (_) {}
      }
      rethrow;
    } finally {
      _starting = false;
    }
  }

  void _startGpsScheduler() {
    _gpsScheduler?.cancel();
    _gpsSchedulerCursor = 0;
    _gpsScheduler = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!_running || _runtime.isEmpty) return;
      final rows = _runtime.values.toList(growable: false);
      if (_gpsSchedulerCursor >= rows.length) _gpsSchedulerCursor = 0;
      final runtime = rows[_gpsSchedulerCursor++];
      if (runtime.txInFlight) return;
      runtime.txInFlight = true;
      unawaited(() async {
        try {
          final now = DateTime.now();
          final lastKeepAlive = runtime.lastDeviceKeepAliveAt;
          final keepAliveDue = lastKeepAlive == null ||
              now.difference(lastKeepAlive) >= _deviceKeepAliveInterval;
          if (keepAliveDue) {
            // 0x20 не только читает батарею/GPS-ready, но и не даёт прошивке
            // некоторых партий трекеров уйти в 30-минутный idle/sleep.
            runtime.lastDeviceKeepAliveAt = now;
            await pool.requestBattery(runtime.binding.deviceUuid);
          } else {
            await pool.requestCurrentGps(runtime.binding.deviceUuid);
          }
        } catch (e) {
          runtime.lastError = 'TX: $e';
        } finally {
          runtime.txInFlight = false;
        }
      }());
    });
  }

  void _startBleWatchdog() {
    _bleWatchdog?.cancel();
    _bleWatchdog = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(_runBleWatchdog());
    });
  }

  Future<void> _runBleWatchdog() async {
    if (!_running ||
        _bleWatchdogInFlight ||
        pool.recoveryInProgress ||
        _runtime.isEmpty) return;
    _bleWatchdogInFlight = true;
    try {
      final now = DateTime.now();
      final candidates = _runtime.values.where((runtime) {
        final connected = pool.isConnected(runtime.binding.deviceUuid);
        final rxSilentFor =
            now.difference(runtime.lastRxAt ?? runtime.watchdogBaselineAt);
        final gpsSilentFor =
            now.difference(runtime.lastGpsAt ?? runtime.watchdogBaselineAt);
        final stale = connected
            ? rxSilentFor >= _silentRxTimeout ||
                gpsSilentFor >= _silentGpsTimeout
            : rxSilentFor >= _disconnectedRecoveryDelay;
        if (!stale) return false;
        final lastRecovery = runtime.lastRecoveryAttemptAt;
        return lastRecovery == null ||
            now.difference(lastRecovery) >= _recoveryCooldown;
      }).toList(growable: false)
        ..sort((a, b) {
          final aRx = a.lastRxAt ?? a.watchdogBaselineAt;
          final bRx = b.lastRxAt ?? b.watchdogBaselineAt;
          return aRx.compareTo(bRx);
        });

      // За один проход восстанавливаем только один GATT, иначе Android может
      // вернуть 133 и сбросить уже работающие каналы.
      if (candidates.isEmpty) return;
      final runtime = candidates.first;
      final connected = pool.isConnected(runtime.binding.deviceUuid);
      final rxSilentSeconds = now
          .difference(runtime.lastRxAt ?? runtime.watchdogBaselineAt)
          .inSeconds;
      final gpsSilentSeconds = now
          .difference(runtime.lastGpsAt ?? runtime.watchdogBaselineAt)
          .inSeconds;
      final reason = !connected
          ? 'канал отключён ${rxSilentSeconds}s'
          : rxSilentSeconds >= _silentRxTimeout.inSeconds
              ? 'нет RX ${rxSilentSeconds}s'
              : 'нет валидного GPS ${gpsSilentSeconds}s';
      runtime.lastRecoveryAttemptAt = now;
      if (runtime.bleGapStartedAt == null) {
        runtime.bleGapStartedAt =
            runtime.lastGpsAt ?? runtime.lastRxAt ?? now;
        _sendGapDebug(
          runtime,
          source: 'team_ble_gap_open',
          message:
              'BLE GAP OPEN · сохраняю начало с последней GPS-точки · from=${runtime.bleGapStartedAt!.toUtc().toIso8601String()}',
        );
      }
      runtime.lastError =
          'BLE watchdog: $reason, восстанавливаю канал';

      var recovered = false;
      try {
        recovered = await pool.recoverConnection(
          runtime.binding.deviceUuid,
          reason: reason,
        );
      } catch (e) {
        runtime.lastError = 'BLE watchdog reconnect: $e';
      }
      runtime.watchdogBaselineAt = DateTime.now();
      runtime.lastDeviceKeepAliveAt = null;
      if (recovered) {
        runtime.recoveryCount++;
        // GATT уже поднялся, но BLE-gap закрываем только первой реальной
        // GPS-точкой. Ответ батареи/TX30 ещё не означает, что Live GPS вернулся.
        runtime.lastError =
            'BLE восстановлен автоматически · ожидаем GPS · попыток ${runtime.recoveryCount}';
      } else {
        runtime.lastError =
            'Трекер пока не отвечает · повтор через ${_recoveryCooldown.inSeconds}s';
      }
    } finally {
      _bleWatchdogInFlight = false;
    }
  }

  Future<void> _onData(TeamTrackerBleEvent event) async {
    final r = _runtime[event.deviceUuid];
    if (r == null) return;
    r.receivedPackets++;
    final rxAt = DateTime.now();
    r.lastRxAt = rxAt;
    r.watchdogBaselineAt = r.lastRxAt!;
    r.lastError = null;

    final chunk = event.data.gpsChunk;
    if (chunk == null || chunk.points.isEmpty) return;

    // Закрываем BLE/GPS-разрыв только когда реально вернулась хотя бы одна
    // валидная GPS-точка, а не по battery/record-list служебному ответу.
    final hasValidGps = chunk.points.any(
      (p) => p.latitude.abs() >= 0.000001 || p.longitude.abs() >= 0.000001,
    );
    if (hasValidGps) {
      // Короткий уход из зоны мог завершиться раньше первого watchdog-pass.
      // Всё равно создаём точное окно от последней GPS-точки, чтобы после Stop
      // дочитать даже такой небольшой пропуск из внутренней записи ATP.
      final previousGpsAt = r.lastGpsAt;
      if (r.bleGapStartedAt == null &&
          previousGpsAt != null &&
          rxAt.difference(previousGpsAt) > const Duration(seconds: 5)) {
        r.bleGapStartedAt = previousGpsAt;
        _sendGapDebug(
          r,
          source: 'team_ble_gap_open',
          message:
              'BLE GAP OPEN ON RETURN · пропуск обнаружен по GPS ${rxAt.difference(previousGpsAt).inSeconds}s · from=${previousGpsAt.toUtc().toIso8601String()}',
        );
      }
      _closeOpenGap(r, rxAt);
    }

    for (final p in chunk.points) {
      if (p.latitude.abs() < 0.000001 && p.longitude.abs() < 0.000001) {
        r.lastError = 'GPS 0,0: нет спутниковой фиксации';
        continue;
      }

      final nowMs =
          p.timeMs > 0 ? p.timeMs : DateTime.now().millisecondsSinceEpoch;
      double deltaM = 0;
      double speedKmh = 0;
      double rawSpeedKmh = 0;
      var acceptedForMetrics = true;
      String? rejectReason;
      var advanceAnchor = r.lastLat == null || r.lastLon == null || r.lastTimeMs == null;

      if (!advanceAnchor) {
        deltaM = _distanceM(r.lastLat!, r.lastLon!, p.latitude, p.longitude);
        final dt = (nowMs - r.lastTimeMs!) / 1000.0;

        if (dt <= 0) {
          // Дубликат/откат времени: не используем точку и, главное, не делаем
          // её новой опорой — иначе следующая нормальная точка породит ложный пик.
          speedKmh = 0;
          deltaM = 0;
          rejectReason = 'GPS-время дублировано/откатилось — точка отброшена';
          acceptedForMetrics = false;
          r.lastError = rejectReason;
        } else if (dt >= 10) {
          // После длинного BLE/GPS-разрыва начинаем новый сегмент маршрута.
          // Расстояние через разрыв не дорисовываем.
          speedKmh = 0;
          deltaM = 0;
          advanceAnchor = true;
        } else if (deltaM >= 300) {
          speedKmh = 0;
          deltaM = 0;
          rejectReason = 'GPS-телепорт координаты отброшен';
          acceptedForMetrics = false;
          r.lastError = rejectReason;
        } else {
          rawSpeedKmh = deltaM / dt * 3.6;
          speedKmh = rawSpeedKmh;

          if (speedKmh.isFinite &&
              deltaM >= _stationaryCoordinateJitterM &&
              speedKmh >= _stationarySpeedDeadbandKmh &&
              speedKmh <= 36) {
            r.totalDistanceM += deltaM;
            r.maxSpeedKmh = math.max(r.maxSpeedKmh, speedKmh);
            r.speedSum += speedKmh;
            r.speedCount++;
            advanceAnchor = true;
          } else if (speedKmh.isFinite &&
              speedKmh >= 0 &&
              (deltaM < _stationaryCoordinateJitterM ||
                  speedKmh < _stationarySpeedDeadbandKmh)) {
            // Покой/мелкий GPS-jitter: нулевая скорость, но опору обновляем,
            // чтобы небольшие смещения не накопились в один большой сегмент.
            speedKmh = 0;
            deltaM = 0;
            advanceAnchor = true;
          } else {
            // Ключевой V86 fix: выброс НЕ становится новой опорной координатой.
            // Раньше >36 отбрасывался, но следующая точка считалась уже от
            // плохой координаты и могла дать вторичный ложный 34–35.6 км/ч.
            speedKmh = 0;
            deltaM = 0;
            rejectReason = 'GPS-выброс скорости отброшен без сдвига опоры';
            acceptedForMetrics = false;
            r.lastError = rejectReason;
          }
        }
      }

      if (advanceAnchor) {
        r.lastLat = p.latitude;
        r.lastLon = p.longitude;
        r.lastTimeMs = nowMs;
      }
      // Карта и server last_position получают последнюю принятую координату.
      // Сырой GPS-выброс всё равно отправляем отдельно в rawLatitude/rawLongitude
      // для диагностики, но он больше не телепортирует аватар к краю поля.
      final displayLatitude = acceptedForMetrics
          ? p.latitude
          : (r.lastLat ?? r.lastPoint?.latitude ?? p.latitude);
      final displayLongitude = acceptedForMetrics
          ? p.longitude
          : (r.lastLon ?? r.lastPoint?.longitude ?? p.longitude);
      r.lastGpsAt = DateTime.now();
      r.lastSpeedKmh = speedKmh;
      r.lastPoint = ActionTrackerGpsPoint(
        timeMs: nowMs,
        latitude: displayLatitude,
        longitude: displayLongitude,
        speedKmh: speedKmh,
        distanceDeltaM: deltaM,
        totalDistanceM: r.totalDistanceM,
        playerId: r.binding.playerId,
      );

      final id = r.liveSessionId;
      if (id == null) continue;
      if (_localOnly) {
        r.serverGapStartedAt ??=
            r.liveStartedAt ?? DateTime.fromMillisecondsSinceEpoch(nowMs);
        r.backfillRequired = true;
        r.lastError =
            'Серверный Live недоступен · GPS и метрики продолжаются локально';
        continue;
      }
      try {
        await api.saveLivePoint(TrackerLivePointPayload(
          liveSessionId: id,
          clubId: clubId,
          teamId: teamId,
          playerId: r.binding.playerId,
          deviceUuid: r.binding.deviceUuid,
          latitude: displayLatitude,
          longitude: displayLongitude,
          rawLatitude: p.latitude,
          rawLongitude: p.longitude,
          acceptedForMetrics: acceptedForMetrics,
          rejectReason: rejectReason,
          timeMs: nowMs,
          speedKmh: speedKmh,
          rawSpeedKmh: rawSpeedKmh,
          distanceDeltaM: deltaM,
          totalDistanceM: r.totalDistanceM,
          maxSpeedKmh: r.maxSpeedKmh,
          avgSpeedKmh: r.speedCount == 0 ? 0 : r.speedSum / r.speedCount,
          rawHex: event.data.rawHex,
        ));
        r.savedPoints++;
        r.lastServerSaveAt = DateTime.now();
        r.lastServerSavedPointTimeMs = nowMs;
        _closeServerGap(
          r,
          DateTime.fromMillisecondsSinceEpoch(nowMs),
        );
        r.lastError = null;
      } catch (e) {
        // Интернет может пропасть при полностью рабочем BLE. Локальные метрики
        // продолжают считаться, а окно несохранённых GPS-точек запоминаем для
        // последующей выгрузки из памяти трекера. Раньше recovery создавался
        // только при BLE-разрыве, поэтому сетевой gap мог потеряться.
        r.serverGapStartedAt ??= DateTime.fromMillisecondsSinceEpoch(
          r.lastServerSavedPointTimeMs ?? nowMs,
        );
        r.backfillRequired = true;
        r.lastError = 'server offline · Live локально продолжается: $e';
      }
    }
  }

  Future<void> stop({bool createFinalSession = true}) async {
    // Идемпотентная остановка: повторный сигнал от UI не должен повторно
    // закрывать первую/отдельную сессию команды.
    if (!_running) return;
    final stoppedAt = DateTime.now();

    // Если интернет вернулся ровно к нажатию «Стоп», сначала регистрируем
    // локально начатый Live на сервере. Весь интервал до регистрации уже
    // помечен как gap и будет взят из памяти трекера.
    if (_localOnly) {
      await _promoteActiveLocalLiveIfPossible(force: true);
    }
    for (final r in _runtime.values) {
      // Если игрок потерялся прямо перед STOP и watchdog ещё не успел сработать,
      // всё равно фиксируем хвост от последней GPS-точки до конца матча.
      if (r.bleGapStartedAt == null) {
        final lastGps = r.lastGpsAt;
        if (lastGps != null &&
            stoppedAt.difference(lastGps) > const Duration(seconds: 5)) {
          r.bleGapStartedAt = lastGps;
        } else if (lastGps == null &&
            r.liveStartedAt != null &&
            stoppedAt.difference(r.liveStartedAt!) >
                const Duration(seconds: 10)) {
          // Live мог вообще не получить первую GPS-точку, хотя внутренняя
          // запись трекера шла. Тогда recovery имеет право проверить весь матч.
          r.bleGapStartedAt = r.liveStartedAt;
        }
      }
      if (r.bleGapStartedAt != null) {
        _closeOpenGap(r, stoppedAt, gpsReturned: false);
      }
      if (r.serverGapStartedAt != null) _closeServerGap(r, stoppedAt);

      // Финальная аналитика должна строиться не только по Live-точкам и не
      // только по отдельным BLE/network gap. На Stop всегда создаём окно всего
      // матча: готовый файл ATP станет источником истины, а серверная дедупликация
      // не вставит повторно уже принятые Live-точки.
      if (createFinalSession) {
        _requireFullMatchRecovery(r, stoppedAt);
      }
    }

    _running = false;
    pool.setLivePolling(false);
    _gpsScheduler?.cancel();
    _gpsScheduler = null;
    _bleWatchdog?.cancel();
    _bleWatchdog = null;
    unawaited(ActionTrackerBleService.setTrackerKeepScreenOn(false));
    _heartbeat?.cancel();
    _heartbeat = null;
    await _dataSub?.cancel();
    _dataSub = null;

    if (_localOnly) {
      // Сервер всё ещё недоступен. Не отправляем синтетические id в API.
      // Сохраняем контекст в координаторе и повторяем регистрацию/финализацию
      // в фоне, пока открыт экран. Внутренняя запись ATP остаётся источником
      // полного маршрута.
      _stoppedLocalRunPending = createFinalSession;
      _pendingLocalStoppedAt = stoppedAt;
      if (_stoppedLocalRunPending) _ensurePersistentRecoveryLease();
      for (final r in _runtime.values) {
        r.liveStoppedAt = stoppedAt;
        if (createFinalSession) _requireFullMatchRecovery(r, stoppedAt);
      }
      _ensureOfflineRecoveryRetryTimer();
      // Если полный recovery не нужен, BLE можно сразу отдать другому
      // планшету. Иначе lease удерживает recovery timer до завершения выгрузки.
      if (_stoppedLocalRunPending) {
        try {
          await api.heartbeatBleTrackerLeases(
            teamId: teamId,
            leaseToken: bleLeaseToken,
          );
        } catch (_) {}
      } else {
        try {
          await api.releaseBleTrackerLeases(
            teamId: teamId,
            leaseToken: bleLeaseToken,
          );
        } catch (_) {}
      }
      return;
    }

    final recoveryBindings = <TeamTrackerBinding>[];
    var stopComplete = true;
    for (final r in _runtime.values) {
      final id = r.liveSessionId;
      if (id == null) continue;
      try {
        final result = await api.stopLiveSession(
          liveSessionId: id,
          createFinalSession: createFinalSession,
        );
        r.liveStoppedAt = stoppedAt;
        r.finalSessionId = int.tryParse(
          '${result['final_session_id'] ?? result['session_id'] ?? 0}',
        );
        r.finalizedLiveSessionId = id;
        r.liveSessionId = null;

        if (createFinalSession &&
            r.backfillRequired &&
            (r.finalSessionId ?? 0) > 0) {
          final jobId = await api.createOfflineRecoveryJob(
            liveSessionId: id,
            finalSessionId: r.finalSessionId!,
            teamId: teamId,
            playerId: r.binding.playerId,
            deviceUuid: r.binding.deviceUuid,
            deviceName: r.binding.deviceName,
            liveStartedMs: r.liveStartedAt?.millisecondsSinceEpoch ??
                stoppedAt.millisecondsSinceEpoch,
            liveStoppedMs: stoppedAt.millisecondsSinceEpoch,
            gaps: r.gaps.map((g) => g.toJson()).toList(growable: false),
          );
          if (jobId > 0) {
            r.recoveryJobCreated = true;
            _markRecoveryPending(r.binding);
            recoveryBindings.add(r.binding);
            await api.sendDebugLog(
              teamId: teamId,
              playerId: r.binding.playerId,
              liveSessionId: id,
              level: 'info',
              source: 'team_offline_recovery_job',
              message:
                  'Создана полная послематчевая выгрузка ATP · job=$jobId · ${r.binding.deviceName} · full_window=${r.gaps.length} · final_session=${r.finalSessionId}',
              deviceUuid: r.binding.deviceUuid,
              deviceName: r.binding.deviceName,
              context: <String, dynamic>{
                'job_id': jobId,
                'final_session_id': r.finalSessionId,
                'full_match_recovery': true,
                'gaps': r.gaps.map((g) => g.toJson()).toList(growable: false),
              },
            );
          }
        }
      } catch (e) {
        r.lastError = 'stop: $e';
        stopComplete = false;
      }
      if (createFinalSession && (r.finalSessionId ?? 0) <= 0) {
        stopComplete = false;
      }
      if (createFinalSession &&
          r.backfillRequired &&
          !r.recoveryJobCreated) {
        stopComplete = false;
      }
    }

    // Интернет мог пропасть уже после нормального серверного старта. В таком
    // случае повторяем не только локальную регистрацию, но и Stop/job: иначе
    // запись оставалась active и никогда не попадала в аналитику.
    if (createFinalSession && !stopComplete) {
      _stoppedLocalRunPending = true;
      _pendingLocalStoppedAt = stoppedAt;
      _ensurePersistentRecoveryLease();
      _ensureOfflineRecoveryRetryTimer();
    }

    // Пока идёт чтение finished-файла ATP, физический BLE остаётся занят этим
    // планшетом. Не отдаём lease второму планшету до завершения recovery.
    final keepBleLeaseForRecovery = _stoppedLocalRunPending ||
        recoveryBindings.isNotEmpty ||
        _pendingRecoveryKeys.isNotEmpty;
    try {
      if (keepBleLeaseForRecovery) {
        await api.heartbeatBleTrackerLeases(
          teamId: teamId,
          leaseToken: bleLeaseToken,
        );
      } else {
        await api.releaseBleTrackerLeases(
          teamId: teamId,
          leaseToken: bleLeaseToken,
        );
      }
    } catch (_) {}

    // Задача полного матча уже надёжно записана на сервере, а выгрузку запускаем
    // сразу в фоне. Новый Team Live не блокируется длинным файлом: start()
    // безопасно поставит активный transfer на паузу и продолжит его после Stop.
    if (recoveryBindings.isNotEmpty || _pendingRecoveryKeys.isNotEmpty) {
      _notifyRecoveryChanged(
        'Live остановлен · GPS recovery продолжен автоматически',
      );
    }
    if (recoveryBindings.isNotEmpty) {
      unawaited(_recoverBindingsSequentially(recoveryBindings));
    }
  }

  void _requireFullMatchRecovery(_Runtime runtime, DateTime stoppedAt) {
    final startedAt = runtime.liveStartedAt;
    runtime.backfillRequired = true;
    if (startedAt == null || !stoppedAt.isAfter(startedAt)) return;

    // Одно полное окно заменяет накопленные частичные разрывы. Это уменьшает
    // payload create_job и явно сообщает серверу: сверить весь матч с ATP.
    runtime.gaps
      ..clear()
      ..add(_TrackerGap(from: startedAt, to: stoppedAt));
  }

  Future<List<Map<String, dynamic>>> _startServerSessions(
    Iterable<TeamTrackerBinding> bindings, {
    required DateTime startedAt,
  }) async {
    final rows = bindings.toList(growable: false);

    // Привязки обновляет сам start_team_tracker_live_sessions.php внутри
    // одной транзакции. Отдельный pre-sync здесь опасен: второй планшет мог бы
    // перепривязать GPS ещё до проверки BLE lease.
    return api.startTeamLiveSessions(
      clubId: clubId,
      teamId: teamId,
      fieldId: fieldId,
      bindings: rows
          .map((b) => <String, dynamic>{
                'player_id': b.playerId,
                'device_uuid': b.deviceUuid,
                'device_name': b.deviceName,
                'battery_percent': b.batteryPercent,
              })
          .toList(growable: false),
      activityType: 'football_field',
      fieldRequired: fieldId != null,
      clientSessionKey: _clientSessionKey,
      startedAtMs: startedAt.millisecondsSinceEpoch,
      bleLeaseToken: bleLeaseToken,
    );
  }

  bool _applyServerSessionIds(List<Map<String, dynamic>> serverSessions) {
    final assignedPlayers = <int>{};
    for (final item in serverSessions) {
      final uuid = '${item['device_uuid'] ?? ''}'.trim();
      final name = '${item['device_name'] ?? ''}'.trim();
      final playerId = int.tryParse('${item['player_id'] ?? 0}') ?? 0;
      final id =
          int.tryParse('${item['live_session_id'] ?? item['id'] ?? 0}') ?? 0;
      if (id <= 0) continue;

      _Runtime? target = _runtime[uuid];
      if (target == null) {
        for (final runtime in _runtime.values) {
          if (_samePhysicalTracker(
            runtime.binding.deviceUuid,
            runtime.binding.deviceName,
            uuid,
            name,
          )) {
            target = runtime;
            break;
          }
        }
      }
      if (target == null && playerId > 0) {
        for (final runtime in _runtime.values) {
          if (runtime.binding.playerId == playerId) {
            target = runtime;
            break;
          }
        }
      }
      if (target == null) continue;
      target.liveSessionId = id;
      assignedPlayers.add(target.binding.playerId);
    }
    return _runtime.values
        .where((r) => r.finalSessionId == null)
        .every((r) => assignedPlayers.contains(r.binding.playerId));
  }

  Future<void> _pushLocalSummaryCheckpoint(_Runtime r) async {
    final liveId = r.liveSessionId;
    final point = r.lastPoint;
    if (liveId == null || liveId <= 0 || point == null) return;

    final timeMs = r.lastTimeMs ?? point.timeMs;
    await api.saveLivePoint(TrackerLivePointPayload(
      liveSessionId: liveId,
      clubId: clubId,
      teamId: teamId,
      playerId: r.binding.playerId,
      deviceUuid: r.binding.deviceUuid,
      latitude: point.latitude,
      longitude: point.longitude,
      rawLatitude: point.latitude,
      rawLongitude: point.longitude,
      acceptedForMetrics: true,
      timeMs: timeMs,
      batteryPercent: r.binding.batteryPercent,
      speedKmh: r.lastSpeedKmh,
      rawSpeedKmh: r.lastSpeedKmh,
      // Ноль здесь принципиален: накопленный метраж передаётся отдельным total,
      // поэтому checkpoint не должен прибавлять последнюю дельту второй раз.
      distanceDeltaM: 0,
      totalDistanceM: r.totalDistanceM,
      maxSpeedKmh: r.maxSpeedKmh,
      avgSpeedKmh: r.speedCount == 0 ? 0 : r.speedSum / r.speedCount,
      rawHex: 'LOCAL_OFFLINE_SUMMARY_CHECKPOINT',
    ));
    r.savedPoints++;
    r.lastServerSaveAt = DateTime.now();
    r.lastServerSavedPointTimeMs = timeMs;
  }

  Future<bool> _registerLocalRunOnServer({bool force = false}) async {
    if (!_localOnly || _promotionInFlight) return !_localOnly;
    final now = DateTime.now();
    if (!force &&
        _lastPromotionAttemptAt != null &&
        now.difference(_lastPromotionAttemptAt!).inSeconds < 12) {
      return false;
    }
    _lastPromotionAttemptAt = now;
    _promotionInFlight = true;
    try {
      final pending = _runtime.values
          .where((r) => r.finalSessionId == null)
          .map((r) => r.binding)
          .toList(growable: false);
      if (pending.isEmpty) {
        _localOnly = false;
        return true;
      }
      final startedAt = _runtime.values
          .map((r) => r.liveStartedAt)
          .whereType<DateTime>()
          .fold<DateTime?>(null,
              (old, value) => old == null || value.isBefore(old) ? value : old) ??
          now;
      final sessions = await _startServerSessions(
        pending,
        startedAt: startedAt,
      );
      if (!_applyServerSessionIds(sessions)) {
        throw StateError('Сервер создал не все каналы локального Live');
      }

      // Серверный Live только что появился после локальной работы. До Stop
      // обязательно отправляем один summary-checkpoint с уже накопленным total,
      // иначе финальная сессия могла создаться с 0 м до offline-recovery.
      for (final r in _runtime.values) {
        await _pushLocalSummaryCheckpoint(r);
      }

      _localOnly = false;
      for (final r in _runtime.values) {
        r.lastError =
            'Серверный Live подключён · локальные метрики синхронизированы';
        if (_running) _closeServerGap(r, now);
      }
      return true;
    } catch (e) {
      for (final r in _runtime.values) {
        r.lastError =
            'Сервер пока не принял локальный Live · данные сохранены локально: $e';
      }
      return false;
    } finally {
      _promotionInFlight = false;
    }
  }

  Future<void> _promoteActiveLocalLiveIfPossible({bool force = false}) async {
    if (!_localOnly) return;
    await _registerLocalRunOnServer(force: force);
  }

  Future<void> _finalizeStoppedLocalRunIfPossible() async {
    if (!_stoppedLocalRunPending || _promotionInFlight) return;
    if (_localOnly && !await _registerLocalRunOnServer()) return;

    final stoppedAt = _pendingLocalStoppedAt ?? DateTime.now();
    final recoveryBindings = <TeamTrackerBinding>[];
    var complete = true;
    for (final r in _runtime.values) {
      try {
        if ((r.finalSessionId ?? 0) <= 0) {
          final liveId = r.liveSessionId;
          if (liveId == null || liveId <= 0) {
            complete = false;
            continue;
          }
          final result = await api.stopLiveSession(
            liveSessionId: liveId,
            createFinalSession: true,
          );
          r.finalSessionId = int.tryParse(
            '${result['final_session_id'] ?? result['session_id'] ?? 0}',
          );
          r.finalizedLiveSessionId = liveId;
          r.liveSessionId = null;
          r.liveStoppedAt = stoppedAt;
        }

        if ((r.finalSessionId ?? 0) <= 0) {
          complete = false;
          continue;
        }

        if (r.backfillRequired && !r.recoveryJobCreated) {
          final jobId = await api.createOfflineRecoveryJob(
            liveSessionId: r.finalizedLiveSessionId ?? 0,
            finalSessionId: r.finalSessionId!,
            teamId: teamId,
            playerId: r.binding.playerId,
            deviceUuid: r.binding.deviceUuid,
            deviceName: r.binding.deviceName,
            liveStartedMs: r.liveStartedAt?.millisecondsSinceEpoch ??
                stoppedAt.millisecondsSinceEpoch,
            liveStoppedMs: stoppedAt.millisecondsSinceEpoch,
            gaps: r.gaps.isEmpty && r.liveStartedAt != null
                ? <Map<String, dynamic>>[
                    _TrackerGap(from: r.liveStartedAt!, to: stoppedAt).toJson(),
                  ]
                : r.gaps.map((g) => g.toJson()).toList(growable: false),
          );
          r.recoveryJobCreated = jobId > 0;
          if (jobId > 0) {
            _markRecoveryPending(r.binding);
            recoveryBindings.add(r.binding);
          }
        }
        if (r.backfillRequired && !r.recoveryJobCreated) complete = false;
      } catch (e) {
        r.lastError = 'ожидаю интернет для сохранения локального Live: $e';
        complete = false;
      }
    }

    if (complete) {
      _stoppedLocalRunPending = false;
      _pendingLocalStoppedAt = null;
      _releasePersistentRecoveryLeaseIfIdle();
    }
    if (recoveryBindings.isNotEmpty) {
      unawaited(_recoverBindingsSequentially(recoveryBindings));
    }
  }

  void _rememberRecoveryBinding(TeamTrackerBinding binding) {
    _recoveryBindingHints[_recoveryKey(binding.deviceUuid, binding.deviceName)] =
        binding;
    _ensureOfflineRecoveryRetryTimer();
  }

  void _markRecoveryPending(TeamTrackerBinding binding) {
    _rememberRecoveryBinding(binding);
    _pendingRecoveryKeys.add(
      _recoveryKey(binding.deviceUuid, binding.deviceName),
    );
    _ensurePersistentRecoveryLease();
  }

  void _clearRecoveryPending(TeamTrackerBinding binding) {
    _pendingRecoveryKeys.remove(
      _recoveryKey(binding.deviceUuid, binding.deviceName),
    );
    _releasePersistentRecoveryLeaseIfIdle();
  }

  void _ensurePersistentRecoveryLease() {
    if (_persistentRecoveryLeaseHeld) return;
    _persistentRecoveryLeaseHeld = true;
    pool.retainBackgroundWork();
  }

  void _releasePersistentRecoveryLeaseIfIdle() {
    if (_stoppedLocalRunPending || _pendingRecoveryKeys.isNotEmpty) return;
    if (_persistentRecoveryLeaseHeld) {
      _persistentRecoveryLeaseHeld = false;
      pool.releaseBackgroundWork();
    }
    // После detach coordinator живёт ровно столько, сколько требуется для
    // pending recovery. Когда всё готово, таймер больше не удерживает объект.
    if (_uiDetached && _offlineRecoveryTasks == 0) {
      _offlineRecoveryRetryTimer?.cancel();
      _offlineRecoveryRetryTimer = null;
    }
  }

  void _notifyRecoveryChanged(String message) {
    if (_uiDetached) return;
    onRecoveryChanged?.call(message);
  }

  void _ensureOfflineRecoveryRetryTimer() {
    _offlineRecoveryRetryTimer ??=
        Timer.periodic(_offlineRecoveryRetryInterval, (_) {
      unawaited(_runOfflineRecoveryRetryTick());
    });
  }

  Future<void> _runOfflineRecoveryRetryTick() async {
    // Один проход может занять больше 15 секунд (особенно при GATT 133).
    // Не складываем следующие Timer-tick в BLE-очередь поверх незавершённого:
    // это раньше само усиливало reconnect storm после Stop.
    if (_offlineRecoveryRetryTickInFlight) return;
    _offlineRecoveryRetryTickInFlight = true;
    try {
      if (_running || _starting) return;
      if (_stoppedLocalRunPending || _pendingRecoveryKeys.isNotEmpty) {
        try {
          await api.heartbeatBleTrackerLeases(
            teamId: teamId,
            leaseToken: bleLeaseToken,
          );
        } catch (_) {}
      }
      if (_stoppedLocalRunPending) {
        await _finalizeStoppedLocalRunIfPossible();
        if (_stoppedLocalRunPending) return;
      }
      final bindings = _recoveryBindingHints.values.toList(growable: false);
      for (final binding in bindings) {
        if (_running || _starting) return;
        // Не пропускаем disconnected GPS. tryRecover сам последовательно
        // восстановит точный UUID/MAC и только затем запросит file-list.
        await tryRecoverPendingForBinding(binding);
      }
      _releasePersistentRecoveryLeaseIfIdle();
      if (!_stoppedLocalRunPending && _pendingRecoveryKeys.isEmpty) {
        try {
          await api.releaseBleTrackerLeases(
            teamId: teamId,
            leaseToken: bleLeaseToken,
          );
        } catch (_) {}
      }
    } finally {
      _offlineRecoveryRetryTickInFlight = false;
    }
  }

  void _closeOpenGap(
    _Runtime runtime,
    DateTime at, {
    bool gpsReturned = true,
  }) {
    final from = runtime.bleGapStartedAt;
    if (from == null) return;
    runtime.bleGapStartedAt = null;
    if (!at.isAfter(from)) return;
    final duration = at.difference(from);
    if (duration.inSeconds < 2) return;
    runtime.gaps.add(_TrackerGap(from: from, to: at));
    runtime.backfillRequired = true;
    _sendGapDebug(
      runtime,
      source: 'team_ble_gap_closed',
      message: gpsReturned
          ? 'BLE GAP CLOSED · связь и валидный GPS вернулись · ${duration.inSeconds}s · участок будет дочитан из памяти после Stop'
          : 'BLE GAP CLOSED BY STOP · хвост без GPS ${duration.inSeconds}s · участок будет дочитан из памяти трекера',
    );
  }

  void _sendGapDebug(
    _Runtime runtime, {
    required String source,
    required String message,
  }) {
    unawaited(() async {
      try {
        await api.sendDebugLog(
          teamId: teamId,
          playerId: runtime.binding.playerId,
          liveSessionId: runtime.liveSessionId,
          level: 'info',
          source: source,
          message: message,
          deviceUuid: runtime.binding.deviceUuid,
          deviceName: runtime.binding.deviceName,
          context: <String, dynamic>{
            'gaps': runtime.gaps.map((gap) => gap.toJson()).toList(growable: false),
          },
        );
      } catch (_) {}
    }());
  }

  void _closeServerGap(_Runtime runtime, DateTime at) {
    final from = runtime.serverGapStartedAt;
    if (from == null) return;
    runtime.serverGapStartedAt = null;
    if (!at.isAfter(from)) return;
    // Даже короткий сетевой gap важен: BLE мог принять несколько GPS-точек,
    // которые не дошли до HTTP API. Сервер recovery сам удалит дубликаты.
    runtime.gaps.add(_TrackerGap(from: from, to: at));
    runtime.backfillRequired = true;
  }

  Future<void> _recoverBindingsSequentially(
    Iterable<TeamTrackerBinding> bindings, {
    bool force = false,
  }) async {
    for (final binding in bindings) {
      if (_running || _starting || pool.livePolling) return;
      await tryRecoverPendingForBinding(binding, force: force);
    }
  }

  /// Немедленно повторяет pending-recovery для переданных GPS. Используется
  /// ручной кнопкой «Восстановить GPS», но выполняет тот же безопасный путь,
  /// что и автоматический recovery: существующая final_session дополняется,
  /// новая дублирующая тренировка не создаётся.
  Future<void> recoverAllNow(
    Iterable<TeamTrackerBinding> bindings,
  ) async {
    final unique = <String, TeamTrackerBinding>{};
    for (final binding in bindings) {
      unique[_recoveryKey(binding.deviceUuid, binding.deviceName)] = binding;
      _rememberRecoveryBinding(binding);
    }
    await _recoverBindingsSequentially(unique.values, force: true);
  }

  /// Короткая диагностика для UI восстановления: какие server jobs ждут,
  /// подключён ли GPS и какой ATP file совпадает с окном матча.
  Future<List<Map<String, dynamic>>> loadRecoveryOverview(
    Iterable<TeamTrackerBinding> bindings,
  ) async {
    final rows = <Map<String, dynamic>>[];
    final unique = <String, TeamTrackerBinding>{};
    for (final binding in bindings) {
      unique[_recoveryKey(binding.deviceUuid, binding.deviceName)] = binding;
    }
    for (final binding in unique.values) {
      List<Map<String, dynamic>> jobs;
      try {
        jobs = await api.loadPendingOfflineRecoveryJobs(
          teamId: teamId,
          deviceUuid: binding.deviceUuid,
          deviceName: binding.deviceName,
          playerId: binding.playerId,
        );
      } catch (e) {
        rows.add(<String, dynamic>{
          'player_id': binding.playerId,
          'player_name': binding.playerName,
          'device_uuid': binding.deviceUuid,
          'device_name': binding.deviceName,
          'connected': pool.isConnected(binding.deviceUuid),
          'error': '$e',
        });
        continue;
      }
      if (jobs.isEmpty) continue;
      _markRecoveryPending(binding);

      // Recovery overview is diagnostics only. Opening/refreshing the sheet must
      // never wake every saved GPS. Background recovery owns radio retries;
      // otherwise UI refresh + timer + post-Stop pass all called connect().
      final connected = pool.isConnected(binding.deviceUuid);
      List<ActionTrackerRecord> records = const <ActionTrackerRecord>[];
      String? recordError;
      if (connected &&
          !_running &&
          !_starting &&
          !pool.livePolling &&
          !pool.offlineTransferActive &&
          _offlineRecoveryTasks == 0) {
        try {
          records = await _requestRecordListWithRetry(binding.deviceUuid);
        } catch (e) {
          recordError = '$e';
        }
      } else if (pool.offlineTransferActive || _offlineRecoveryTasks > 0) {
        recordError = 'Автовыгрузка уже выполняется';
      }
      for (final job in jobs) {
        final match = records.isEmpty ? null : _findRecordMatchForJob(records, job);
        rows.add(<String, dynamic>{
          'player_id': binding.playerId,
          'player_name': binding.playerName,
          'device_uuid': binding.deviceUuid,
          'device_name': binding.deviceName,
          'connected': connected,
          'job_id': int.tryParse('${job['id'] ?? job['job_id'] ?? 0}') ?? 0,
          'final_session_id':
              int.tryParse('${job['final_session_id'] ?? 0}') ?? 0,
          'status': '${job['status'] ?? 'pending'}',
          'message': '${job['message'] ?? ''}',
          'received_points': int.tryParse('${job['received_points'] ?? 0}') ?? 0,
          if (recordError != null) 'record_error': recordError,
          if (match != null) ...<String, dynamic>{
            'file_id': match.record.fileId,
            'file_state': match.record.state.name,
            'file_length': match.record.length,
            'clock_shift_ms': match.clockShiftMs,
            'overlap_ms': match.overlapMs,
          },
        });
      }
    }
    return rows;
  }

  Future<void> tryRecoverPendingForBinding(
    TeamTrackerBinding binding, {
    bool force = false,
  }) async {
    _rememberRecoveryBinding(binding);
    if (_running || _starting || pool.livePolling) return;

    final recoveryKey = _recoveryKey(
      binding.deviceUuid,
      binding.deviceName,
    );
    final sharedRecoveryKey = '$teamId|$recoveryKey';

    // Cross-coordinator gate. Set BEFORE HTTP/BLE work so a stale coordinator
    // from a previous window/hot-reload cannot start the same retry a few ms
    // later after the first one quickly returns `GPS not found`.
    if (!force) {
      final now = DateTime.now();
      final nextAllowed = _sharedRecoveryNextAttemptAt[sharedRecoveryKey];
      if (nextAllowed != null && now.isBefore(nextAllowed)) return;
      _sharedRecoveryNextAttemptAt[sharedRecoveryKey] =
          now.add(_sharedAutoRecoveryCooldown);
    }

    if (!_sharedRecoveryInFlightDevices.add(sharedRecoveryKey)) return;

    pool.retainBackgroundWork();
    _offlineRecoveryTasks++;
    try {
      List<Map<String, dynamic>> jobs;
      try {
        // Сначала спрашиваем сервер. Так мы не будим/не переподключаем GPS,
        // если для него вообще нет незавершённых задач.
        jobs = await api.loadPendingOfflineRecoveryJobs(
          teamId: teamId,
          deviceUuid: binding.deviceUuid,
          deviceName: binding.deviceName,
          playerId: binding.playerId,
        );
      } catch (_) {
        // Интернет ещё не вернулся — persistent lease + timer сохраняют задачу.
        return;
      }
      if (jobs.isEmpty) {
        _clearRecoveryPending(binding);
        _sharedRecoveryNextAttemptAt.remove(sharedRecoveryKey);
        return;
      }
      _markRecoveryPending(binding);
      if (_running || _starting || pool.livePolling) return;

      // Ключевое исправление: раньше pending job просто пропускался, если после
      // Stop BLE успел отвалиться/GATT 133 удалил connection из pool. Теперь
      // каждые 15 секунд пробуем вернуть точный UUID и продолжаем автоматически.
      final connected = await pool.ensureRecoveryConnection(
        binding.deviceUuid,
        deviceName: binding.deviceName,
      );
      if (!connected) {
        _notifyRecoveryChanged(
          'GPS recovery: ${binding.playerName} · жду переподключение ${binding.deviceName}',
        );
        return;
      }

      for (final job in jobs) {
        if (_running || _starting || pool.livePolling) return;
        final jobId = int.tryParse('${job['id'] ?? job['job_id'] ?? 0}') ?? 0;
        if (jobId <= 0) continue;

        try {
          // Если BLE-файл уже оказался в staging, но MySQL finalize поймал
          // deadlock/lock wait, повторяем только серверную транзакцию.
          final receivedPoints =
              int.tryParse('${job['received_points'] ?? 0}') ?? 0;
          final previousMessage = '${job['message'] ?? ''}'.toLowerCase();
          final stagedAfterLockError = receivedPoints > 0 &&
              (previousMessage.contains('deadlock') ||
                  previousMessage.contains('1213') ||
                  previousMessage.contains('lock wait') ||
                  previousMessage.contains('1205'));
          final stagedRecord = _recordJsonFromRecoveryJob(job);
          if (stagedAfterLockError && stagedRecord.isNotEmpty) {
            final result = await api.finalizeOfflineRecovery(
              jobId: jobId,
              record: stagedRecord,
            );
            _notifyRecoveryChanged(
              'GPS recovery готов: ${binding.playerName} · session ${job['final_session_id'] ?? ''}',
            );
            try {
              await api.sendDebugLog(
                teamId: teamId,
                playerId: binding.playerId,
                level: 'info',
                source: 'team_offline_recovery_done',
                message:
                    'Офлайн GPS финализирован из server staging · ${binding.deviceName} · job=$jobId · staged=$receivedPoints · inserted=${result['inserted_points'] ?? 0}',
                deviceUuid: binding.deviceUuid,
                deviceName: binding.deviceName,
                context: <String, dynamic>{
                  'job_id': jobId,
                  'record': stagedRecord,
                  'result': result,
                },
              );
            } catch (_) {}
            continue;
          }

          final records = await _requestRecordListWithRetry(binding.deviceUuid);
          if (_running || _starting || pool.livePolling) return;
          final match = _findRecordMatchForJob(records, job);
          if (match == null) {
            const waitMessage =
                'Подходящая запись в памяти трекера пока не найдена';
            await api.markOfflineRecoveryWaiting(
              jobId: jobId,
              message: waitMessage,
            );
            _notifyRecoveryChanged(
              'GPS recovery: ${binding.playerName} · жду finished-файл ATP',
            );
            try {
              await api.sendDebugLog(
                teamId: teamId,
                playerId: binding.playerId,
                level: 'info',
                source: 'team_offline_recovery_wait',
                message:
                    'Офлайн GPS ждёт · ${binding.deviceName} · job=$jobId · $waitMessage',
                deviceUuid: binding.deviceUuid,
                deviceName: binding.deviceName,
              );
            } catch (_) {}
            continue;
          }
          if (match.record.state != ActionTrackerRecordState.finished) {
            final waitMessage =
                'file ${match.record.fileId} ещё не finished (${match.record.state.name})';
            await api.markOfflineRecoveryWaiting(
              jobId: jobId,
              message: waitMessage,
            );
            _notifyRecoveryChanged(
              'GPS recovery: ${binding.playerName} · file ${match.record.fileId} ещё ${match.record.state.name}',
            );
            try {
              await api.sendDebugLog(
                teamId: teamId,
                playerId: binding.playerId,
                level: 'info',
                source: 'team_offline_recovery_wait',
                message:
                    'Офлайн GPS ждёт · ${binding.deviceName} · job=$jobId · $waitMessage',
                deviceUuid: binding.deviceUuid,
                deviceName: binding.deviceName,
                context: <String, dynamic>{
                  'record': match.record.toJson(),
                  'clock_shift_ms': match.clockShiftMs,
                },
              );
            } catch (_) {}
            continue;
          }

          if (match.clockShiftMs != 0) {
            try {
              await api.sendDebugLog(
                teamId: teamId,
                playerId: binding.playerId,
                level: 'info',
                source: 'team_offline_recovery_clock_shift',
                message:
                    'ATP clock скорректирован для recovery · file=${match.record.fileId} · shift=${match.clockShiftMs}ms',
                deviceUuid: binding.deviceUuid,
                deviceName: binding.deviceName,
                context: <String, dynamic>{
                  'job_id': jobId,
                  'clock_shift_ms': match.clockShiftMs,
                  'overlap_ms': match.overlapMs,
                },
              );
            } catch (_) {}
          }

          final rawPoints = await pool.downloadFinishedRecord(
            binding.deviceUuid,
            match.record,
          );
          // Start может прийти в момент чтения большого ATP-файла. Pool в
          // таком случае завершает transfer пустым техническим результатом,
          // закрывает GATT и отдаёт канал новому Live. Ничего из этого буфера
          // нельзя отправлять в старую сессию — job останется waiting и после
          // следующего Stop файл будет считан заново полностью.
          if (_running || _starting || pool.livePolling) {
            throw StateError('Восстановление поставлено на паузу новым Team Live');
          }
          final points = _offlinePointsForJob(
            match.record,
            rawPoints,
            job,
            clockShiftMs: match.clockShiftMs,
          );
          if (points.isEmpty) {
            await api.markOfflineRecoveryWaiting(
              jobId: jobId,
              message:
                  'Файл ${match.record.fileId} прочитан, но точек окна матча нет',
            );
            continue;
          }

          final recordPayload = <String, dynamic>{
            ...match.record.toJson(),
            'recovery_clock_shift_ms': match.clockShiftMs,
          };
          const batchSize = 1500;
          var first = true;
          for (var offset = 0; offset < points.length; offset += batchSize) {
            if (_running || _starting || pool.livePolling) {
              throw StateError('Восстановление прервано новым Team Live');
            }
            final end = offset + batchSize < points.length
                ? offset + batchSize
                : points.length;
            await api.uploadOfflineRecoveryChunk(
              jobId: jobId,
              record: recordPayload,
              points: points.sublist(offset, end),
              reset: first,
            );
            first = false;
          }

          final result = await api.finalizeOfflineRecovery(
            jobId: jobId,
            record: recordPayload,
          );
          _notifyRecoveryChanged(
            'GPS восстановлен: ${binding.playerName} · ${points.length} точек · session ${job['final_session_id'] ?? ''}',
          );
          try {
            await api.sendDebugLog(
              teamId: teamId,
              playerId: binding.playerId,
              level: 'info',
              source: 'team_offline_recovery_done',
              message:
                  'Офлайн GPS восстановлен · ${binding.deviceName} · file=${match.record.fileId} · downloaded=${rawPoints.length} · window=${points.length} · inserted=${result['inserted_points'] ?? 0}',
              deviceUuid: binding.deviceUuid,
              deviceName: binding.deviceName,
              context: <String, dynamic>{
                'job_id': jobId,
                'record': recordPayload,
                'result': result,
              },
            );
          } catch (_) {}
        } catch (e) {
          try {
            await api.markOfflineRecoveryWaiting(
              jobId: jobId,
              message: '$e',
            );
          } catch (_) {}
          try {
            await api.sendDebugLog(
              teamId: teamId,
              playerId: binding.playerId,
              level: 'warning',
              source: 'team_offline_recovery_wait',
              message:
                  'Офлайн GPS пока не восстановлен · ${binding.deviceName}: $e',
              deviceUuid: binding.deviceUuid,
              deviceName: binding.deviceName,
            );
          } catch (_) {}
        }
      }

      // Освобождаем долгоживущий background lease только когда сервер
      // действительно больше не возвращает pending/waiting jobs для GPS.
      try {
        final remaining = await api.loadPendingOfflineRecoveryJobs(
          teamId: teamId,
          deviceUuid: binding.deviceUuid,
          deviceName: binding.deviceName,
          playerId: binding.playerId,
        );
        if (remaining.isEmpty) {
          _clearRecoveryPending(binding);
        } else {
          _markRecoveryPending(binding);
        }
      } catch (_) {
        // Сеть снова исчезла — pending оставляем живым.
      }
    } finally {
      if (_offlineRecoveryTasks > 0) _offlineRecoveryTasks--;
      pool.releaseBackgroundWork();
      _sharedRecoveryInFlightDevices.remove(sharedRecoveryKey);
      _releasePersistentRecoveryLeaseIfIdle();
    }
  }

  Map<String, dynamic> _recordJsonFromRecoveryJob(
    Map<String, dynamic> job,
  ) {
    final value = job['record_json'];
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is! String || value.trim().isEmpty) {
      return <String, dynamic>{};
    }
    try {
      final decoded = jsonDecode(value);
      return decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<List<ActionTrackerRecord>> _requestRecordListWithRetry(
    String deviceUuid,
  ) async {
    Object? lastError;
    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        return await pool.requestRecordListFor(
          deviceUuid,
          timeout: const Duration(seconds: 12),
        );
      } catch (e) {
        lastError = e;
        if (attempt < 3) {
          await Future<void>.delayed(Duration(milliseconds: 600 * attempt));
        }
      }
    }
    throw StateError(
      'Список записей GPS не получен после 3 попыток: $lastError',
    );
  }

  _OfflineRecordMatch? _findRecordMatchForJob(
    List<ActionTrackerRecord> records,
    Map<String, dynamic> job,
  ) {
    final liveStartMs = int.tryParse('${job['live_started_ms'] ?? 0}') ?? 0;
    final liveStopMs = int.tryParse('${job['live_stopped_ms'] ?? 0}') ?? 0;
    if (records.isEmpty) return null;

    _OfflineRecordMatch? bestForShift(int shiftMs) {
      final candidates = <_OfflineRecordMatch>[];
      for (final record in records) {
        final rawStart = _recordDateTime(record.startDateRaw, record.startTimeMs);
        if (rawStart == null) continue;
        final start = rawStart.add(Duration(milliseconds: shiftMs));

        DateTime end;
        if (record.state == ActionTrackerRecordState.recording ||
            record.endTimeMs <= 0) {
          // recording-файл пока не скачиваем, но должны уметь показать, что
          // именно его ждём. Четыре часа — безопасная верхняя граница выбора.
          end = start.add(const Duration(hours: 4));
        } else {
          final rawEnd = _recordDateTime(
            record.endDateRaw > 0 ? record.endDateRaw : record.startDateRaw,
            record.endTimeMs,
          );
          end = (rawEnd ?? rawStart.add(const Duration(hours: 4)))
              .add(Duration(milliseconds: shiftMs));
          if (!end.isAfter(start)) end = end.add(const Duration(days: 1));
        }

        var overlap = 1;
        if (liveStartMs > 0 && liveStopMs > 0) {
          final from = math.max(start.millisecondsSinceEpoch, liveStartMs);
          final to = math.min(end.millisecondsSinceEpoch, liveStopMs);
          overlap = math.max(0, to - from);
          if (overlap <= 0) {
            // Небольшой допуск нужен для файлов, которые открылись за секунды
            // до Live/закрылись сразу после Stop.
            const tolerance = Duration(minutes: 10);
            final startMs = start.millisecondsSinceEpoch;
            final nearWindow = startMs >= liveStartMs - tolerance.inMilliseconds &&
                startMs <= liveStopMs + tolerance.inMilliseconds;
            if (!nearWindow) continue;
          }
        }
        candidates.add(_OfflineRecordMatch(
          record: record,
          clockShiftMs: shiftMs,
          overlapMs: overlap,
        ));
      }
      if (candidates.isEmpty) return null;
      candidates.sort((a, b) {
        final overlapCompare = b.overlapMs.compareTo(a.overlapMs);
        if (overlapCompare != 0) return overlapCompare;
        final aFinished =
            a.record.state == ActionTrackerRecordState.finished ? 1 : 0;
        final bFinished =
            b.record.state == ActionTrackerRecordState.finished ? 1 : 0;
        if (aFinished != bFinished) return bFinished.compareTo(aFinished);
        return b.record.fileId.compareTo(a.record.fileId);
      });
      return candidates.first;
    }

    // Сначала сохраняем прежнее поведение: если часы ATP уже совпадают с UTC,
    // никакая эвристика смещения не участвует в выборе файла.
    final direct = bestForShift(0);
    if (direct != null) return direct;

    // Некоторые партии ATP сохраняют date/time как локальное/GPS-время, тогда
    // job создан по epoch UTC, а список файлов выглядит сдвинутым (например +3ч).
    // Только если прямого совпадения НЕТ, перебираем получасовые timezone-like
    // сдвиги. Это устраняет «подходящая запись не найдена», не меняя нормальные
    // трекеры. При равном overlap предпочитаем минимальную поправку.
    final shifted = <_OfflineRecordMatch>[];
    for (var minutes = -14 * 60; minutes <= 14 * 60; minutes += 30) {
      if (minutes == 0) continue;
      final candidate = bestForShift(Duration(minutes: minutes).inMilliseconds);
      if (candidate != null && candidate.overlapMs > 0) shifted.add(candidate);
    }
    if (shifted.isEmpty) return null;
    shifted.sort((a, b) {
      final overlapCompare = b.overlapMs.compareTo(a.overlapMs);
      if (overlapCompare != 0) return overlapCompare;
      final shiftCompare = a.clockShiftMs.abs().compareTo(b.clockShiftMs.abs());
      if (shiftCompare != 0) return shiftCompare;
      final aFinished =
          a.record.state == ActionTrackerRecordState.finished ? 1 : 0;
      final bFinished =
          b.record.state == ActionTrackerRecordState.finished ? 1 : 0;
      if (aFinished != bFinished) return bFinished.compareTo(aFinished);
      return b.record.fileId.compareTo(a.record.fileId);
    });
    return shifted.first;
  }

  List<Map<String, dynamic>> _offlinePointsForJob(
    ActionTrackerRecord record,
    List<ActionTrackerGpsPoint> points,
    Map<String, dynamic> job, {
    int clockShiftMs = 0,
  }) {
    final rawBase = _recordDateTime(record.startDateRaw, 0);
    final base = rawBase?.add(Duration(milliseconds: clockShiftMs));
    if (base == null) return const <Map<String, dynamic>>[];
    final liveStartMs = int.tryParse('${job['live_started_ms'] ?? 0}') ?? 0;
    final liveStopMs = int.tryParse('${job['live_stopped_ms'] ?? 0}') ?? 0;
    final int? minMs = liveStartMs > 0
        ? liveStartMs - const Duration(seconds: 3).inMilliseconds
        : null;
    final int? maxMs = liveStopMs > 0
        ? liveStopMs + const Duration(seconds: 3).inMilliseconds
        : null;

    final result = <Map<String, dynamic>>[];
    var dayOffset = 0;
    int? previousTod;
    for (final point in points) {
      if (point.latitude.abs() < 0.000001 &&
          point.longitude.abs() < 0.000001) continue;
      var raw = point.timeMs;
      int epochMs;
      if (raw > 1000000000000) {
        epochMs = raw;
      } else if (raw >= 86400000) {
        epochMs = base.millisecondsSinceEpoch + raw;
      } else {
        if (previousTod != null && raw + 12 * 60 * 60 * 1000 < previousTod) {
          dayOffset++;
        }
        previousTod = raw;
        epochMs = base.millisecondsSinceEpoch +
            dayOffset * 24 * 60 * 60 * 1000 +
            raw;
      }
      if (minMs != null && epochMs < minMs) continue;
      if (maxMs != null && epochMs > maxMs) continue;
      result.add(<String, dynamic>{
        'time_ms': epochMs,
        'latitude': point.latitude,
        'longitude': point.longitude,
      });
    }
    result.sort((a, b) =>
        (a['time_ms'] as int).compareTo(b['time_ms'] as int));
    return result;
  }

  DateTime? _recordDateTime(int dateRaw, int timeMs) {
    if (dateRaw <= 0) return null;
    var year = dateRaw ~/ 10000;
    final ddmm = dateRaw % 10000;
    final day = ddmm ~/ 100;
    final month = ddmm % 100;
    if (year < 100) year += 2000;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    // Базово трактуем clock ATP как UTC. Для партий датчиков, которые пишут
    // локальное/GPS-время, recovery отдельно вычисляет безопасный clockShift.
    final midnightUtc = DateTime.utc(year, month, day);
    return midnightUtc.add(
      Duration(milliseconds: timeMs < 0 ? 0 : timeMs),
    );
  }


  static double _distanceM(double lat1, double lon1, double lat2, double lon2) {
    const earth = 6371000.0;
    final p1 = lat1 * math.pi / 180;
    final p2 = lat2 * math.pi / 180;
    final dp = (lat2 - lat1) * math.pi / 180;
    final dl = (lon2 - lon1) * math.pi / 180;
    final a = math.sin(dp / 2) * math.sin(dp / 2) +
        math.cos(p1) * math.cos(p2) * math.sin(dl / 2) * math.sin(dl / 2);
    return earth * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static bool _samePhysicalTracker(
    String firstUuid,
    String firstName,
    String secondUuid,
    String secondName,
  ) {
    String normalizeId(String value) =>
        value.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    String normalizeName(String value) =>
        value.trim().toUpperCase().replaceAll(RegExp(r'\s+'), ' ');

    final firstId = normalizeId(firstUuid);
    final secondId = normalizeId(secondUuid);
    if (firstId.isNotEmpty && secondId.isNotEmpty) {
      if (firstId == secondId ||
          (firstId.length >= 12 &&
              secondId.length >= 12 &&
              (firstId.endsWith(secondId) || secondId.endsWith(firstId)))) {
        return true;
      }
    }

    final a = normalizeName(firstName);
    final b = normalizeName(secondName);
    final namedTracker =
        a.startsWith(r'$ATP') || a.startsWith(r'$ACT') || a.startsWith(r'$GPS');
    return namedTracker && a.isNotEmpty && a == b;
  }

  bool _isBleLeaseConflict(Object error) {
    final text = error.toString().toUpperCase();
    return text.contains('BLE_LEASE_BUSY') ||
        text.contains('ИСПОЛЬЗУЕТСЯ ДРУГОЙ АКТИВНОЙ СЕССИЕЙ');
  }

  int _localSessionId(int playerId) {
    // Положительный id нужен существующему интерфейсу Live, но диапазон
    // намеренно далёк от реальных AUTO_INCREMENT id и никогда не отправляется
    // в API. После восстановления интернета он заменяется серверным id.
    final safeTeam = teamId.abs() % 100000;
    final safePlayer = playerId.abs() % 1000;
    return 700000000 + safeTeam * 1000 + safePlayer;
  }

  static String _recoveryKey(String uuid, String name) {
    final normalizedName = name
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'\s+'), ' ');
    if (normalizedName.startsWith(r'$ATP') ||
        normalizedName.startsWith(r'$ACT') ||
        normalizedName.startsWith(r'$GPS')) {
      return 'NAME:$normalizedName';
    }
    return 'ID:${uuid.trim().toUpperCase()}';
  }

  Future<void> dispose() async {
    // UI может закрыться сразу после Stop. Сам recovery при этом не должен
    // умереть: coordinator остаётся жить своим Timer, а shared BLE-pool
    // удерживается persistent background lease до завершения server jobs.
    _uiDetached = true;
    onRecoveryChanged = null;
    if (_running) await stop(createFinalSession: true);
    if (_stoppedLocalRunPending) {
      await _finalizeStoppedLocalRunIfPossible();
    }
    _bleWatchdog?.cancel();
    _bleWatchdog = null;

    if (_stoppedLocalRunPending || _pendingRecoveryKeys.isNotEmpty) {
      _ensurePersistentRecoveryLease();
      _ensureOfflineRecoveryRetryTimer();
    } else {
      _offlineRecoveryRetryTimer?.cancel();
      _offlineRecoveryRetryTimer = null;
      _releasePersistentRecoveryLeaseIfIdle();
    }
  }
}
