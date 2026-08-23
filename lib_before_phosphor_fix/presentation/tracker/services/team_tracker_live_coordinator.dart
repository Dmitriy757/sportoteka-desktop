import 'dart:async';
import 'dart:math' as math;

import '../models/tracker_live_models.dart';
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
  });
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
  double maxSpeedKmh = 0;
  double speedSum = 0;
  int speedCount = 0;
  double? lastLat;
  double? lastLon;
  int? lastTimeMs;

  _Runtime(this.binding);
}

/// Одна командная тренировка на планшете, но отдельная активная строка сервера
/// и отдельный BLE-канал для каждого игрока/UUID.
class TeamTrackerLiveCoordinator {
  final int clubId;
  final int teamId;
  int? fieldId;
  final TeamActionTrackerBlePool pool;
  final TrackerLiveApi api;
  final Map<String, _Runtime> _runtime = {};
  StreamSubscription<TeamTrackerBleEvent>? _dataSub;
  Timer? _heartbeat;
  Timer? _gpsScheduler;
  int _gpsSchedulerCursor = 0;
  bool _heartbeatInFlight = false;
  bool _running = false;
  bool _starting = false;

  TeamTrackerLiveCoordinator({
    required this.clubId,
    required this.teamId,
    required this.pool,
    TrackerLiveApi? api,
    this.fieldId,
  }) : api = api ?? TrackerLiveApi();

  bool get running => _running || _starting;

  int? liveSessionIdForPlayer(int playerId) {
    for (final runtime in _runtime.values) {
      if (runtime.binding.playerId == playerId) return runtime.liveSessionId;
    }
    return null;
  }

  List<TeamTrackerChannelDebug> get debugRows => _runtime.values.map((r) {
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
        );
      }).toList(growable: false);

  Future<void> start(List<TeamTrackerBinding> bindings) async {
    if (_running || _starting) return;
    if (bindings.isEmpty) throw StateError('Нет привязанных GPS-трекеров команды');
    _starting = true;

    try {
      final duplicateDevices = <String>{};
      final seenDevices = <String>{};
      final seenPlayers = <int>{};
      for (final b in bindings) {
        if (!seenDevices.add(b.deviceUuid)) duplicateDevices.add(b.deviceUuid);
        if (!seenPlayers.add(b.playerId)) {
          throw StateError('Игрок ${b.playerName} привязан более чем к одному GPS');
        }
      }
      if (duplicateDevices.isNotEmpty) {
        throw StateError('Один UUID назначен нескольким игрокам: ${duplicateDevices.join(', ')}');
      }

      _runtime.clear();
      for (final b in bindings) {
        if (!pool.isConnected(b.deviceUuid)) {
          throw StateError('GPS ${b.deviceName} (${b.deviceUuid}) не подключён');
        }
        _runtime[b.deviceUuid] = _Runtime(b);
      }

      // Все серверные строки создаются одной транзакцией. Это не оставляет
      // пять активных игроков, если шестой трекер не прошёл проверку.
      final serverSessions = await api.startTeamLiveSessions(
        clubId: clubId,
        teamId: teamId,
        fieldId: fieldId,
        bindings: bindings.map((b) => <String, dynamic>{
          'player_id': b.playerId,
          'device_uuid': b.deviceUuid,
          'device_name': b.deviceName,
          'battery_percent': b.batteryPercent,
        }).toList(growable: false),
        activityType: 'football_field',
        fieldRequired: fieldId != null,
      );

      for (final item in serverSessions) {
        final uuid = '${item['device_uuid'] ?? ''}'.trim();
        final name = '${item['device_name'] ?? ''}'.trim();
        final playerId =
            int.tryParse('${item['player_id'] ?? 0}') ?? 0;
        final id = int.tryParse('${item['live_session_id'] ?? item['id'] ?? 0}') ?? 0;
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
        target?.liveSessionId = id;
      }
      final missing = _runtime.values.where((r) => r.liveSessionId == null).toList(growable: false);
      if (missing.isNotEmpty) {
        throw StateError(
          'Сервер не создал Live для: ${missing.map((r) => r.binding.playerName).join(', ')}',
        );
      }

      _dataSub = pool.dataStream.listen(_onData);
      _running = true;
      pool.setLivePolling(true);
      _startGpsScheduler();

      _heartbeat = Timer.periodic(const Duration(seconds: 5), (_) async {
        if (_heartbeatInFlight) return;
        _heartbeatInFlight = true;
        try {
          await Future.wait(_runtime.values.map((r) async {
            final id = r.liveSessionId;
            if (id == null) return;
            try {
              await api.heartbeatLiveSession(
                liveSessionId: id,
                statusText: 'team_live:${pool.connectedCount}/${_runtime.length}',
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
      _gpsScheduler?.cancel();
      _gpsScheduler = null;
      _heartbeat?.cancel();
      _heartbeat = null;
      await _dataSub?.cancel();
      _dataSub = null;
      for (final r in _runtime.values) {
        final id = r.liveSessionId;
        if (id == null) continue;
        try {
          await api.stopLiveSession(liveSessionId: id, createFinalSession: false);
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
          await pool.requestCurrentGps(runtime.binding.deviceUuid);
          runtime.lastError = null;
        } catch (e) {
          runtime.lastError = 'TX: $e';
        } finally {
          runtime.txInFlight = false;
        }
      }());
    });
  }

  Future<void> _onData(TeamTrackerBleEvent event) async {
    final r = _runtime[event.deviceUuid];
    if (r == null) return;
    r.receivedPackets++;
    r.lastRxAt = DateTime.now();

    final chunk = event.data.gpsChunk;
    if (chunk == null || chunk.points.isEmpty) return;

    for (final p in chunk.points) {
      if (p.latitude.abs() < 0.000001 && p.longitude.abs() < 0.000001) {
        r.lastError = 'GPS 0,0: нет спутниковой фиксации';
        continue;
      }

      final nowMs = p.timeMs > 0 ? p.timeMs : DateTime.now().millisecondsSinceEpoch;
      double deltaM = 0;
      double speedKmh = 0;
      if (r.lastLat != null && r.lastLon != null && r.lastTimeMs != null) {
        deltaM = _distanceM(r.lastLat!, r.lastLon!, p.latitude, p.longitude);
        final dt = (nowMs - r.lastTimeMs!) / 1000.0;
        if (dt > 0 && dt < 30 && deltaM < 300) speedKmh = deltaM / dt * 3.6;
        if (speedKmh <= 45) {
          r.totalDistanceM += deltaM;
          r.maxSpeedKmh = math.max(r.maxSpeedKmh, speedKmh);
          r.speedSum += speedKmh;
          r.speedCount++;
        }
      }
      r.lastLat = p.latitude;
      r.lastLon = p.longitude;
      r.lastTimeMs = nowMs;
      r.lastGpsAt = DateTime.now();

      final id = r.liveSessionId;
      if (id == null) continue;
      try {
        await api.saveLivePoint(TrackerLivePointPayload(
          liveSessionId: id,
          clubId: clubId,
          teamId: teamId,
          playerId: r.binding.playerId,
          deviceUuid: r.binding.deviceUuid,
          latitude: p.latitude,
          longitude: p.longitude,
          timeMs: nowMs,
          speedKmh: speedKmh,
          rawSpeedKmh: speedKmh,
          distanceDeltaM: deltaM,
          totalDistanceM: r.totalDistanceM,
          maxSpeedKmh: r.maxSpeedKmh,
          avgSpeedKmh: r.speedCount == 0 ? 0 : r.speedSum / r.speedCount,
          rawHex: event.data.rawHex,
        ));
        r.savedPoints++;
        r.lastServerSaveAt = DateTime.now();
        r.lastError = null;
      } catch (e) {
        r.lastError = 'save: $e';
      }
    }
  }

  Future<void> stop({bool createFinalSession = true}) async {
    // Идемпотентная остановка: повторный сигнал от UI не должен повторно
    // закрывать первую/отдельную сессию команды.
    if (!_running) return;
    _running = false;
    pool.setLivePolling(false);
    _gpsScheduler?.cancel();
    _gpsScheduler = null;
    _heartbeat?.cancel();
    _heartbeat = null;
    await _dataSub?.cancel();
    _dataSub = null;

    for (final r in _runtime.values) {
      final id = r.liveSessionId;
      if (id == null) continue;
      try {
        await api.stopLiveSession(
          liveSessionId: id,
          createFinalSession: createFinalSession,
        );
        r.liveSessionId = null;
      } catch (e) {
        r.lastError = 'stop: $e';
      }
    }
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
    final namedTracker = a.startsWith(r'$ATP') ||
        a.startsWith(r'$ACT') ||
        a.startsWith(r'$GPS');
    return namedTracker && a.isNotEmpty && a == b;
  }

  Future<void> dispose() async {
    if (_running) await stop(createFinalSession: false);
  }
}
