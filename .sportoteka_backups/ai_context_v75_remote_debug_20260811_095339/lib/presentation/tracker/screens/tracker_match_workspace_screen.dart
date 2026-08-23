import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sportoteka/presentation/club_workspace/cmr_context_ai_layer.dart';

import '../models/action_tracker_protocol.dart';
import '../models/tracker_pro_models.dart';
import '../services/action_tracker_ble_service.dart';
import '../services/team_action_tracker_ble_pool.dart';
import '../services/team_tracker_live_coordinator.dart';
import '../team_live_debug_dialog.dart';
import '../services/polar_heart_rate_ble_service.dart';
import '../services/tracker_permissions.dart';
import '../services/tracker_pro_api.dart';
import '../services/tracker_live_api.dart';
import '../tracker_live_panel.dart';
import '../tracker_player_activity_screen.dart';
import '../widgets/tracker_pro_analytics_panel.dart';
import '../widgets/tracker_action_analytics_suite.dart';
import '../widgets/player_training_notifications_panel.dart';
import '../widgets/player_training_calendar_panel.dart';
import '../reports/tracker_export_viewer.dart';
import '../reports/tracker_training_report_api.dart';
import '../reports/tracker_training_report_models.dart';

DateTime? _trackerParseServerInstant(dynamic value) {
  final raw = '${value ?? ''}'.trim();
  if (raw.isEmpty || raw == 'null') return null;
  final normalized = raw.replaceFirst(' ', 'T');
  final hasZone = RegExp(r'(Z|[+-]\d{2}:?\d{2})$', caseSensitive: false)
      .hasMatch(normalized);
  if (hasZone) return DateTime.tryParse(normalized)?.toUtc();

  final naive = DateTime.tryParse(normalized);
  if (naive == null) return null;
  // Серверные MySQL-строки без timezone считаем UTC.
  return DateTime.utc(
    naive.year,
    naive.month,
    naive.day,
    naive.hour,
    naive.minute,
    naive.second,
    naive.millisecond,
    naive.microsecond,
  );
}

DateTime? _trackerMoscowDateTime(dynamic value) {
  final instant = _trackerParseServerInstant(value);
  if (instant == null) return null;
  final moscow = instant.add(const Duration(hours: 3));
  // Возвращаем wall-clock Moscow без зависимости от timezone устройства.
  return DateTime(
    moscow.year,
    moscow.month,
    moscow.day,
    moscow.hour,
    moscow.minute,
    moscow.second,
    moscow.millisecond,
    moscow.microsecond,
  );
}

DateTime _trackerMoscowFromEpochMs(int millisecondsSinceEpoch) {
  final moscow = DateTime.fromMillisecondsSinceEpoch(
    millisecondsSinceEpoch,
    isUtc: true,
  ).add(const Duration(hours: 3));
  return DateTime(
    moscow.year,
    moscow.month,
    moscow.day,
    moscow.hour,
    moscow.minute,
    moscow.second,
    moscow.millisecond,
    moscow.microsecond,
  );
}

enum TrackerWorkspaceSection {
  dashboard,
  live,
  analytics,
  activity,
  sessions,
  devices,
  field,
  personal,
  settings,
  debug
}

List<TrackerWorkspaceSection> get _trackerVisibleSections =>
    TrackerWorkspaceSection.values
        .where((section) =>
            section != TrackerWorkspaceSection.dashboard &&
            section != TrackerWorkspaceSection.activity &&
            section != TrackerWorkspaceSection.sessions &&
            section != TrackerWorkspaceSection.debug)
        .toList(growable: false);

const List<TrackerWorkspaceSection> _trackerMobilePrimarySections =
    <TrackerWorkspaceSection>[
  TrackerWorkspaceSection.devices,
  TrackerWorkspaceSection.live,
  TrackerWorkspaceSection.analytics,
  TrackerWorkspaceSection.personal,
  TrackerWorkspaceSection.field,
  TrackerWorkspaceSection.settings,
];

enum _TrackerExitAction {
  stay,
  pauseAndMinimize,
  saveAndExit,
  exitWithoutSaving
}

enum _TrackerLiveSwitchAction { stayInLive, keepRunning, saveAndSwitch }

class TrackerMatchWorkspaceScreen extends StatefulWidget {
  const TrackerMatchWorkspaceScreen({
    super.key,
    required this.clubId,
    required this.clubName,
    required this.teamId,
    required this.teamName,
    required this.userId,
    this.initialPlayers = const [],
    this.embeddedInClubWorkspace = false,
    this.analyticsOnly = false,
    this.initialSection = TrackerWorkspaceSection.live,
    this.initialPlayerId,
    this.initialSessionId,
    this.initialAnalyticsTab = 0,
  });

  final int clubId;
  final String clubName;
  final int teamId;
  final String teamName;
  final int userId;
  final List<Map<String, dynamic>> initialPlayers;

  /// true — экран трекера открыт внутри Club Workspace.
  /// В этом режиме внешний Windows-подобный taskbar клуба остаётся на месте,
  /// а разделы трекера показываются как вкладки отдельной «программы».
  final bool embeddedInClubWorkspace;

  /// true — экран открыт из профиля/календаря только для просмотра аналитики.
  /// Левая навигация Tracker Workspace, Live, устройства и личные тренировки
  /// не отображаются, но используется тот же настоящий модуль аналитики.
  final bool analyticsOnly;

  /// Стартовый раздел. В analyticsOnly принудительно используется analytics.
  final TrackerWorkspaceSection initialSection;
  final int? initialPlayerId;
  final int? initialSessionId;
  final int initialAnalyticsTab;

  @override
  State<TrackerMatchWorkspaceScreen> createState() =>
      _TrackerMatchWorkspaceScreenState();
}

class _TrackerMatchWorkspaceScreenState
    extends State<TrackerMatchWorkspaceScreen> {
  late final ActionTrackerBleService _ble;
  late final TeamActionTrackerBlePool _teamBlePool;
  late final String _teamBlePoolSharedKey;
  late final TeamTrackerLiveCoordinator _teamLiveCoordinator;
  late final HeartRateBleService _heart;
  late final TrackerProApi _api;
  late final TrackerLiveApi _liveApi;

  final List<String> _logs = <String>[];
  final List<ActionTrackerRecord> _records = <ActionTrackerRecord>[];
  final List<ActionTrackerGpsPoint> _points = <ActionTrackerGpsPoint>[];
  final Set<String> _offlineAutoSyncedRecordKeys = <String>{};
  final List<ActionTrackerGpsPoint> _calibrationCorners =
      <ActionTrackerGpsPoint>[];

  List<TrackerPlayerOption> _players = <TrackerPlayerOption>[];
  List<TrackerDeviceModel> _savedDevices = <TrackerDeviceModel>[];
  List<TrackerFieldModel> _fields = <TrackerFieldModel>[];

  TrackerWorkspaceSection _section = TrackerWorkspaceSection.live;
  late final PageController _mobileSectionController;
  TrackerPlayerOption? _selectedPlayer;
  TrackerFieldModel? _selectedField;
  ActionTrackerDevice? _connected;
  HeartRateBleDevice? _connectedHeart;
  ActionTrackerBatteryState? _battery;
  ActionTrackerRecord? _selectedRecord;
  TrackerSessionModel? _selectedReportSession;
  bool? _contextAiExpanded;
  int _contextAiRevision = 0;
  String? _contextAiPromptOverride;
  Map<String, dynamic>? _contextAiPayloadOverride;
  TrackerWorkspaceSection? _contextAiOverrideSection;
  Map<String, dynamic> _trackerAnalyticsAiContext = <String, dynamic>{};

  StreamSubscription<ActionTrackerParseResult>? _dataSub;
  StreamSubscription<String>? _logSub;
  StreamSubscription<TeamTrackerBleLog>? _teamBleLogSub;
  StreamSubscription<int>? _teamBleStateSub;
  StreamSubscription<HeartRateSample>? _heartSub;
  StreamSubscription<String>? _heartLogSub;

  bool _loading = true;
  bool _scanning = false;
  bool _scanningHeart = false;
  bool _connecting = false;
  bool _connectingHeart = false;
  bool _savingRecord = false;
  bool _offlineAutoSyncInProgress = false;
  bool _offlineAutoSaveAfterTransfer = false;
  String? _offlineAutoSyncKey;
  String _trackerRecordingStatus = 'запись на трекере не проверялась';
  DateTime? _lastRecordListAt;
  bool _liveRunning = false;
  int? _activeLiveSessionId;

  bool _calibrationCapturing = false;
  int? _calibrationCapturingIndex;
  int _calibrationFlashSeed = 0;
  String? _calibrationFlashLabel;
  Timer? _calibrationFlashTimer;

  ActionTrackerGpsPoint? _lastWorkspaceGpsPoint;
  DateTime? _lastWorkspaceGpsAt;
  DateTime? _lastTrackerPacketAt;
  DateTime? _lastRemoteRxLogAt;
  String _lastWorkspaceRx = 'нет пакетов';
  String _lastWorkspaceGps = 'нет GPS';
  String _lastRemoteDebug = 'debug ещё не отправлялся';
  final List<Map<String, dynamic>> _remoteDebugLogs = <Map<String, dynamic>>[];
  final List<_RemoteTrackerPresence> _remoteConnectedTrackers =
      <_RemoteTrackerPresence>[];
  Timer? _remoteDebugPollTimer;
  Timer? _remoteStatusHeartbeatTimer;
  bool _remoteDebugLoading = false;
  bool _remoteConsoleAutoRefresh = true;
  bool _hideSavedDevices = true;
  DateTime? _lastRemoteConsoleLoadAt;
  FlutterExceptionHandler? _previousFlutterErrorHandler;
  FlutterExceptionHandler? _installedFlutterErrorHandler;
  bool Function(Object, StackTrace)? _previousPlatformErrorHandler;
  bool Function(Object, StackTrace)? _installedPlatformErrorHandler;

  final Map<String, int?> _heartDevicePlayerIds = <String, int?>{};
  final Map<int, HeartRateSample> _latestHeartByPlayerId =
      <int, HeartRateSample>{};
  final Map<String, DateTime> _lastHeartSampleUploadAt = <String, DateTime>{};
  final Set<String> _heartSampleUploadInFlight = <String>{};
  final Map<String, TeamTrackerBinding> _confirmedTeamGpsBindings =
      <String, TeamTrackerBinding>{};
  HeartRateSample? _latestHeartSample;
  String? _selectedHeartDeviceId;

  // Новый workspace датчиков: вкладки GPS / Polar и правая панель назначения.
  int _deviceWorkspaceTab = 0;
  bool _deviceWorkspaceDetailsOpen = false;

  int _liveStartRequestSignal = 0;
  int _livePauseRequestSignal = 0;
  int _liveStopRequestSignal = 0;
  int _liveExitWithoutSaveRequestSignal = 0;
  bool _trackerWindowMinimized = false;
  bool _trackerWindowMaximized = false;
  bool _trackerSideCollapsed = false;
  int _analyticsInitialTab = 0;
  int _analyticsInitialTabSignal = 0;
  PlayerTrainingCalendarMode _analyticsInitialCalendarMode =
      PlayerTrainingCalendarMode.team;
  int _analyticsInitialCalendarModeSignal = 0;

  @override
  void initState() {
    super.initState();
    _section = widget.analyticsOnly
        ? TrackerWorkspaceSection.analytics
        : widget.initialSection;
    _analyticsInitialTab = widget.initialAnalyticsTab;
    final initialSectionIndex = _trackerVisibleSections.indexOf(_section);
    _mobileSectionController = PageController(
        initialPage: initialSectionIndex < 0 ? 0 : initialSectionIndex);
    _api = TrackerProApi();
    _liveApi = TrackerLiveApi();
    _ble = ActionTrackerBleService();
    _teamBlePoolSharedKey = '${widget.clubId}:${widget.teamId}';
    _teamBlePool =
        TeamActionTrackerBlePool.acquireShared(_teamBlePoolSharedKey);
    _teamLiveCoordinator = TeamTrackerLiveCoordinator(
      clubId: widget.clubId,
      teamId: widget.teamId,
      fieldId: null,
      pool: _teamBlePool,
      api: _liveApi,
    );
    _bindTeamBlePool();
    _heart = HeartRateBleService();
    _installRemoteErrorHooks();
    _players = widget.initialPlayers
        .map(TrackerPlayerOption.fromJson)
        .where((p) => p.id > 0)
        .toList();
    if (widget.initialPlayerId != null) {
      for (final player in _players) {
        if (player.id == widget.initialPlayerId) {
          _selectedPlayer = player;
          break;
        }
      }
    }
    _logs.insert(0, '[TEAM] init → ${widget.teamName} (${widget.teamId})');
    _init();
  }

  String _localClockLabel(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }

  void _pushLocalLog(String message, {bool dedupe = false}) {
    final clean = message.trim();
    if (clean.isEmpty) return;

    final duplicate = dedupe &&
        _logs.isNotEmpty &&
        _logs.first.replaceFirst(RegExp(r'^\[[^\]]+\]\s*'), '').trim() == clean;
    if (duplicate) return;

    void mutate() {
      _logs.insert(0, '[${_localClockLabel(DateTime.now())}] $clean');
      if (_logs.length > 260) _logs.removeRange(260, _logs.length);
    }

    if (mounted) {
      setState(mutate);
    } else {
      mutate();
    }
  }

  @override
  void didUpdateWidget(covariant TrackerMatchWorkspaceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.teamId != widget.teamId ||
        oldWidget.clubId != widget.clubId) {
      _resetTeamRuntimeState();

      if (widget.initialPlayers.isNotEmpty) {
        _players = widget.initialPlayers
            .map(TrackerPlayerOption.fromJson)
            .where((p) => p.id > 0)
            .toList();
      }

      _loadServerData();
    }
  }

  void _resetTeamRuntimeState() {
    setState(() {
      _loading = true;
      _records.clear();
      _points.clear();
      _calibrationCorners.clear();
      _calibrationCapturing = false;
      _calibrationCapturingIndex = null;
      _calibrationFlashLabel = null;
      _lastWorkspaceGpsPoint = null;
      _lastWorkspaceGpsAt = null;
      _lastTrackerPacketAt = null;
      _lastRemoteRxLogAt = null;
      _lastWorkspaceRx = 'нет пакетов';
      _lastWorkspaceGps = 'нет GPS';
      _lastRemoteDebug = 'debug ещё не отправлялся';
      _remoteDebugLogs.clear();
      _remoteConnectedTrackers.clear();
      _lastRemoteConsoleLoadAt = null;
      _savedDevices.clear();
      _fields.clear();
      _selectedPlayer = null;
      _selectedField = null;
      _selectedRecord = null;
      _selectedReportSession = null;
      _trackerAnalyticsAiContext = <String, dynamic>{};
      _contextAiPromptOverride = null;
      _contextAiPayloadOverride = null;
      _contextAiOverrideSection = null;
      _contextAiExpanded = false;
      _battery = null;
      _connected = _ble.connectedInfo;
      _connectedHeart = _heart.connectedInfo;
      _latestHeartSample = null;
      _latestHeartByPlayerId.clear();
      _heartDevicePlayerIds.clear();
      _confirmedTeamGpsBindings.clear();
      _lastHeartSampleUploadAt.clear();
      _heartSampleUploadInFlight.clear();
      _selectedHeartDeviceId = null;
      _liveRunning = false;
      _activeLiveSessionId = null;
      _liveStartRequestSignal = 0;
      _livePauseRequestSignal = 0;
      _liveStopRequestSignal = 0;
      _liveExitWithoutSaveRequestSignal = 0;
      _logs.insert(0,
          '[TEAM] переключение команды → ${widget.teamName} (${widget.teamId})');
      if (_logs.length > 220) _logs.removeRange(220, _logs.length);
    });
  }

  @override
  void dispose() {
    _restoreRemoteErrorHooks();
    _calibrationFlashTimer?.cancel();
    _remoteDebugPollTimer?.cancel();
    _remoteStatusHeartbeatTimer?.cancel();
    _dataSub?.cancel();
    _logSub?.cancel();
    _teamBleLogSub?.cancel();
    _teamBleStateSub?.cancel();
    _heartSub?.cancel();
    _heartLogSub?.cancel();
    unawaited(_teamLiveCoordinator.dispose());
    unawaited(
      TeamActionTrackerBlePool.releaseShared(_teamBlePoolSharedKey),
    );
    _ble.dispose();
    _heart.dispose();
    _mobileSectionController.dispose();
    super.dispose();
  }

  void _bindTeamBlePool() {
    _teamBleLogSub?.cancel();
    _teamBleStateSub?.cancel();
    _teamBleStateSub = _teamBlePool.stateStream.listen((_) {
      if (!mounted) return;
      setState(() {});
    });
    _teamBleLogSub = _teamBlePool.logStream.listen((event) {
      if (!mounted) return;
      final line = '[${event.deviceName} / ${event.deviceUuid}] ${event.line}';
      _pushLocalLog('[TEAM BLE] $line');
      final level = _remoteBleLogLevel(event.line);
      if (level != null) {
        unawaited(_logRemote(
          line,
          level: level,
          source: 'workspace_team_ble_log',
          extra: <String, dynamic>{
            'device_uuid': event.deviceUuid,
            'device_name': event.deviceName,
            'team_ble_connected_count': _teamBlePool.connectedCount,
          },
        ));
      }
    });
  }

  Future<void> _init() async {
    _bindBle();
    _bindHeartRate();
    _startRemoteDebugTools();
    try {
      await _ble.init();
    } catch (e) {
      _toast('Bluetooth', '$e');
    }
    try {
      await _heart.init();
    } catch (e) {
      _toast('Polar H10', '$e');
    }
    await _loadServerData();
    await _applyInitialAnalyticsContext();
  }

  Future<void> _applyInitialAnalyticsContext() async {
    if (!mounted) return;

    TrackerPlayerOption? initialPlayer;
    final requestedPlayerId = widget.initialPlayerId;
    if (requestedPlayerId != null && requestedPlayerId > 0) {
      for (final player in _players) {
        if (player.id == requestedPlayerId) {
          initialPlayer = player;
          break;
        }
      }
    }

    TrackerSessionModel? initialSession;
    final requestedSessionId = widget.initialSessionId;
    if (requestedSessionId != null && requestedSessionId > 0) {
      try {
        final sessions = await _api.loadSessions(
          teamId: widget.teamId,
          playerId: requestedPlayerId != null && requestedPlayerId > 0
              ? requestedPlayerId
              : null,
          limit: 100,
          sessionKind: 'all',
        );
        for (final session in sessions) {
          if (session.id == requestedSessionId) {
            initialSession = session;
            break;
          }
        }
      } catch (e) {
        _pushLocalLog(
            'Не удалось загрузить стартовую сессию #$requestedSessionId: $e');
      }
    }

    if (!mounted) return;
    setState(() {
      if (initialPlayer != null) _selectedPlayer = initialPlayer;
      if (initialSession != null) _selectedReportSession = initialSession;
      if (widget.analyticsOnly) _section = TrackerWorkspaceSection.analytics;
      _analyticsInitialTab = widget.initialAnalyticsTab;
      _analyticsInitialTabSignal++;
    });
  }

  void _bindBle() {
    _dataSub = _ble.dataStream.listen((event) {
      if (!mounted) return;

      final now = DateTime.now();
      final chunk = event.gpsChunk;
      final validPoints = chunk == null
          ? const <ActionTrackerGpsPoint>[]
          : chunk.points.where(_isValidGpsPoint).toList(growable: false);

      setState(() {
        _lastTrackerPacketAt = now;
        _lastWorkspaceRx = event.rawHex;

        if (event.battery != null) _battery = event.battery;
        if (event.records.isNotEmpty) {
          _records
            ..clear()
            ..addAll(event.records);
          _lastRecordListAt = now;
          _trackerRecordingStatus =
              _formatTrackerRecordingStatus(event.records);
        }

        if (event.transferFinished) {
          _trackerRecordingStatus = _offlineAutoSaveAfterTransfer
              ? 'загрузка записи завершена · сохраняю на сервер'
              : 'загрузка записи завершена · можно сохранить как сессию';
        }

        if (validPoints.isNotEmpty) {
          _points.addAll(validPoints);
          _lastWorkspaceGpsPoint = validPoints.last;
          _lastWorkspaceGpsAt = now;
          _lastWorkspaceGps =
              '${validPoints.last.latitude.toStringAsFixed(6)}, ${validPoints.last.longitude.toStringAsFixed(6)}';
        }
      });

      if (validPoints.isNotEmpty) {
        final shouldSend = _lastRemoteRxLogAt == null ||
            now.difference(_lastRemoteRxLogAt!).inSeconds >= 5;
        if (shouldSend) {
          _lastRemoteRxLogAt = now;
          unawaited(_logRemote(
            'RX GPS: ${validPoints.length} точек · last=$_lastWorkspaceGps · всего=${_points.length}',
            source: 'workspace_rx_gps',
            rawHex: event.rawHex,
          ));
        }
      } else if (chunk != null && chunk.points.isNotEmpty) {
        unawaited(_logRemote(
          'RX GPS отброшен: невалидная координата или 0,0 · points=${chunk.points.length}',
          level: 'warning',
          source: 'workspace_rx_gps_invalid',
          rawHex: event.rawHex,
        ));
      }

      if (event.records.isNotEmpty) {
        unawaited(_autoSyncLatestFinishedRecordIfNeeded());
      }
      if (event.transferFinished || event.gpsChunk?.finished == true) {
        unawaited(_finishOfflineAutoSyncAfterTransfer());
      }
    });

    _logSub = _ble.logStream.listen((line) {
      if (!mounted) return;
      setState(() {
        _logs.insert(0, line);
        if (_logs.length > 220) _logs.removeLast();
      });

      final lower = line.toLowerCase();
      if (lower.contains('tx пропущен') ||
          lower.contains('отключился') ||
          lower.contains('not connected') ||
          lower.contains('reconnect scan failed')) {
        // Не сбрасываем выбранный датчик во время активного Live.
        // Раньше это меняло key у TrackerLivePanel, виджет пересоздавался,
        // dispose() останавливал live-сессию, и кнопка «Старт» отжималась через несколько секунд.
        if (!_liveRunning && _connected != null) {
          setState(() => _connected = null);
        }
      }

      final remoteBleLevel = _remoteBleLogLevel(line);
      if (remoteBleLevel != null) {
        unawaited(_logRemote(line,
            level: remoteBleLevel, source: 'workspace_ble_log'));
      }
    });
  }

  void _bindHeartRate() {
    _heartSub?.cancel();
    _heartSub = _heart.sampleStream.listen((sample) {
      if (!mounted) return;
      final playerId = _heartDevicePlayerIds[sample.deviceId];
      setState(() {
        _latestHeartSample = sample;
        _connectedHeart = _heart.connectedInfo;
        _selectedHeartDeviceId ??= sample.deviceId;
        if (playerId != null && playerId > 0) {
          _heartDevicePlayerIds[sample.deviceId] = playerId;
          _latestHeartByPlayerId[playerId] = sample;
        }
      });
      unawaited(_uploadHeartRateSample(sample, playerId: playerId));
    });

    _heartLogSub?.cancel();
    _heartLogSub = _heart.logStream.listen((line) {
      if (!mounted) return;
      setState(() {
        _logs.insert(0, line.replaceFirst(']', '] HEART'));
        if (_logs.length > 220) _logs.removeLast();
      });
      final lower = line.toLowerCase();
      if (lower.contains('error') ||
          lower.contains('ошиб') ||
          lower.contains('not found') ||
          lower.contains('не найден') ||
          lower.contains('отключ')) {
        unawaited(_logRemote(line,
            level: lower.contains('не найден') || lower.contains('not found')
                ? 'warning'
                : 'error',
            source: 'workspace_heart_rate_log'));
      }
    });
  }

  Future<void> _uploadHeartRateSample(HeartRateSample sample,
      {int? playerId}) async {
    if (playerId == null || playerId <= 0) return;
    final liveId = _teamLiveCoordinator.liveSessionIdForPlayer(playerId) ??
        _activeLiveSessionId;
    if (liveId == null || liveId <= 0) return;

    final now = DateTime.now();
    final last = _lastHeartSampleUploadAt[sample.deviceId];
    if (last != null && now.difference(last).inMilliseconds < 1800) return;
    if (_heartSampleUploadInFlight.contains(sample.deviceId)) return;

    _lastHeartSampleUploadAt[sample.deviceId] = now;
    _heartSampleUploadInFlight.add(sample.deviceId);
    try {
      await _liveApi.saveHeartRateSample(
        clubId: widget.clubId,
        teamId: widget.teamId,
        playerId: playerId,
        liveSessionId: liveId,
        sample: sample,
      );
    } catch (e) {
      unawaited(_logRemote('Ошибка сохранения Polar H10: $e',
          level: 'warning', source: 'workspace_heart_rate_save_error'));
    } finally {
      _heartSampleUploadInFlight.remove(sample.deviceId);
    }
  }

  bool _isValidGpsPoint(ActionTrackerGpsPoint p) {
    if (p.latitude == 0 || p.longitude == 0) return false;
    if (p.latitude < -90 || p.latitude > 90) return false;
    if (p.longitude < -180 || p.longitude > 180) return false;
    return true;
  }

  String? _remoteBleLogLevel(String line) {
    final lower = line.toLowerCase();
    if (lower.contains('gatt 133') ||
        lower.contains('android-code: 133') ||
        lower.contains('android code: 133')) {
      return 'error';
    }
    if (lower.contains('watchdog') ||
        lower.contains('нет rx') ||
        lower.contains('reconnect') ||
        lower.contains('восстанавливаю канал') ||
        lower.contains('трекер пока не отвечает')) {
      return lower.contains('восстановлен') || lower.contains('reconnect ok')
          ? 'info'
          : 'warning';
    }
    if (lower.contains('reconnect wait') ||
        lower.contains('вне зоны') ||
        lower.contains('write characteristic is null') ||
        lower.contains('gps-датчик пока вне зоны') ||
        lower.contains('live-сессия на сервере продолжается')) {
      return 'warning';
    }
    if (lower.contains('ошиб') ||
        lower.contains('error') ||
        lower.contains('not connected') ||
        lower.contains('disconnected') ||
        lower.contains('отключ') ||
        lower.contains('пропущен') ||
        lower.contains('failed')) {
      return 'error';
    }
    if (lower.contains('warning') ||
        lower.contains('not found') ||
        lower.contains('не найден') ||
        lower.contains('fallback')) {
      return 'warning';
    }
    if (lower.contains('scan') ||
        lower.contains('ble diag') ||
        lower.contains('gps sensor') ||
        lower.contains('tracker?') ||
        lower.contains('probe?') ||
        lower.contains('reset') ||
        lower.contains('keep-alive') ||
        lower.contains('0x20') ||
        lower.contains('tx/rx') ||
        lower.contains('подключ')) {
      return 'info';
    }
    return null;
  }

  bool get _hasConnectedTeamGps => _teamBlePool.connectedCount > 0;

  bool get _hasAnyGpsCommandChannel =>
      _hasConnectedTeamGps || _ble.commandChannelReady;

  Set<int> get _connectedTeamPlayerIds {
    final result = <int>{};
    // Главный источник для Live-панели — те же готовые связки, которые
    // непосредственно пойдут в командный старт.
    for (final binding in _teamLiveBindings()) {
      final player = _playerOptionForIdentity(binding.playerId);
      result.add(player?.id ?? binding.playerId);
    }
    for (final connected in _teamBlePool.connectedInfos) {
      final confirmed = _confirmedTeamGpsBindings[
          _teamBindingKey(connected.id, connected.name)];
      if (confirmed != null) {
        final player = _playerOptionForIdentity(confirmed.playerId);
        result.add(player?.id ?? confirmed.playerId);
      }
      for (final saved in _savedDevices) {
        if (_isHeartRateDeviceModel(saved)) continue;
        final playerId = saved.playerId;
        if (playerId == null || playerId <= 0) continue;
        if (_trackerIdOrNameMatches(connected.id, connected.name, saved)) {
          final player = _playerOptionForIdentity(playerId);
          result.add(player?.id ?? playerId);
        }
      }
    }
    return result;
  }

  ActionTrackerDevice? get _remoteConnectedDevice {
    final teamDevices = _teamBlePool.connectedInfos;
    if (teamDevices.isNotEmpty) return teamDevices.last;
    return _ble.commandChannelReady ? (_connected ?? _ble.connectedInfo) : null;
  }

  ActionTrackerDevice? get _lastKnownBleDevice {
    final teamDevices = _teamBlePool.connectedInfos;
    if (teamDevices.isNotEmpty) return teamDevices.last;
    return _connected ?? _ble.connectedInfo ?? _ble.lastKnownInfo;
  }

  String _remoteClientLabel() {
    final device = _remoteConnectedDevice;
    final deviceTitle =
        device == null ? 'BLE не подключён' : '${device.name} / ${device.id}';
    return '${widget.teamName} · командный BLE ${_teamBlePool.connectedCount} · $deviceTitle';
  }

  Map<String, dynamic> _remoteDebugContext() {
    final packetAge = _lastTrackerPacketAt == null
        ? null
        : DateTime.now().difference(_lastTrackerPacketAt!).inSeconds;
    final gpsAge = _lastWorkspaceGpsAt == null
        ? null
        : DateTime.now().difference(_lastWorkspaceGpsAt!).inSeconds;
    final device = _remoteConnectedDevice;
    final lastKnown = _lastKnownBleDevice;
    return <String, dynamic>{
      'club_id': widget.clubId,
      'club_name': widget.clubName,
      'team_id': widget.teamId,
      'team_name': widget.teamName,
      'user_id': widget.userId,
      'player_id': _selectedPlayer?.id,
      'player_name': _selectedPlayer?.name,
      'ble_connected': device != null,
      'ble_command_channel_ready': _hasAnyGpsCommandChannel,
      'team_ble_connected_count': _teamBlePool.connectedCount,
      'team_ble_devices': _teamBlePool.connectedInfos
          .map((d) =>
              <String, dynamic>{'device_uuid': d.id, 'device_name': d.name})
          .toList(growable: false),
      'polar_connected_count': _heart.connectedCount,
      'polar_devices': _heart.connectedInfos
          .map((d) => <String, dynamic>{
                'device_uuid': d.id,
                'device_name': d.name,
                'rssi': d.rssi,
                'player_id': _heartDevicePlayerIds[d.id],
                'bpm': _heart.lastSampleForDevice(d.id)?.bpm,
                'battery_percent':
                    _heart.lastSampleForDevice(d.id)?.batteryPercent,
                'last_sample_at': _heart
                    .lastSampleForDevice(d.id)
                    ?.measuredAt
                    .toIso8601String(),
              })
          .toList(growable: false),
      'team_live_channels': _teamLiveCoordinator.debugRows
          .map((row) => <String, dynamic>{
                'player_id': row.playerId,
                'player_name': row.playerName,
                'device_uuid': row.deviceUuid,
                'device_name': row.deviceName,
                'ble_ready': row.bleReady,
                'live_session_id': row.liveSessionId,
                'last_rx_age_sec': row.lastRxAt == null
                    ? null
                    : DateTime.now().difference(row.lastRxAt!).inSeconds,
                'last_gps_age_sec': row.lastGpsAt == null
                    ? null
                    : DateTime.now().difference(row.lastGpsAt!).inSeconds,
                'last_save_age_sec': row.lastServerSaveAt == null
                    ? null
                    : DateTime.now()
                        .difference(row.lastServerSaveAt!)
                        .inSeconds,
                'received_packets': row.receivedPackets,
                'saved_points': row.savedPoints,
                'last_speed_kmh': row.lastSpeedKmh,
                'max_speed_kmh': row.maxSpeedKmh,
                'avg_speed_kmh': row.avgSpeedKmh,
                'total_distance_m': row.totalDistanceM,
                'recovery_count': row.recoveryCount,
                'last_error': row.lastError,
              })
          .toList(growable: false),
      'ble_device_uuid': device?.id ?? lastKnown?.id,
      'ble_device_name': device?.name ?? lastKnown?.name,
      'ble_rssi': device?.rssi ?? lastKnown?.rssi,
      'ble_state_note': device == null && lastKnown != null
          ? 'выбран/был подключён, но TX/RX канал сейчас закрыт'
          : null,
      'live_running': _liveRunning,
      'live_session_id': _activeLiveSessionId,
      'field_id': _selectedField?.id,
      'field_title': _selectedField?.title,
      'field_calibrated': _selectedField?.hasCalibration == true,
      'points_count': _points.length,
      'last_packet_age_sec': packetAge,
      'last_gps_age_sec': gpsAge,
      'last_rx': _lastWorkspaceRx,
      'last_gps': _lastWorkspaceGps,
      'battery_percent': _batteryPercent,
      'saved_devices_count': _savedDevices.length,
      'saved_devices_hidden': _hideSavedDevices,
      'ble_reset_available': true,
      'clean_scan_available': true,
      'stationary_speed_deadband_kmh': 1.5,
      'stationary_coordinate_jitter_m': 0.35,
      'client_time': DateTime.now().toIso8601String(),
    };
  }

  String _sanitizeRemoteError(String value) {
    var text = value;
    final secretPattern = RegExp(
      r'(action_token|authorization|password|access_token|refresh_token|bearer)\s*[:=]?\s*[^\s,}\]]+',
      caseSensitive: false,
    );
    text = text.replaceAll(secretPattern, r'$1=[СКРЫТО]');
    if (text.length > 12000) {
      text = '${text.substring(0, 12000)}\n…[обрезано]';
    }
    return text;
  }

  void _installRemoteErrorHooks() {
    _previousFlutterErrorHandler = FlutterError.onError;
    final previousFlutter = _previousFlutterErrorHandler;
    _installedFlutterErrorHandler = (FlutterErrorDetails details) {
      try {
        previousFlutter?.call(details);
      } finally {
        final stack = details.stack?.toString().split('\n').take(45).join('\n');
        unawaited(_logRemote(
          _sanitizeRemoteError(
            'FlutterError: ${details.exceptionAsString()}${stack == null || stack.isEmpty ? '' : '\n$stack'}',
          ),
          level: 'error',
          source: 'flutter_uncaught_error',
        ));
      }
    };
    FlutterError.onError = _installedFlutterErrorHandler;

    _previousPlatformErrorHandler = ui.PlatformDispatcher.instance.onError;
    final previousPlatform = _previousPlatformErrorHandler;
    _installedPlatformErrorHandler = (Object error, StackTrace stack) {
      unawaited(_logRemote(
        _sanitizeRemoteError(
          'PlatformError: $error\n${stack.toString().split('\n').take(45).join('\n')}',
        ),
        level: 'error',
        source: 'platform_uncaught_error',
      ));
      return previousPlatform?.call(error, stack) ?? false;
    };
    ui.PlatformDispatcher.instance.onError = _installedPlatformErrorHandler;
  }

  void _restoreRemoteErrorHooks() {
    if (identical(FlutterError.onError, _installedFlutterErrorHandler)) {
      FlutterError.onError = _previousFlutterErrorHandler;
    }
    if (identical(
      ui.PlatformDispatcher.instance.onError,
      _installedPlatformErrorHandler,
    )) {
      ui.PlatformDispatcher.instance.onError = _previousPlatformErrorHandler;
    }
  }

  void _startRemoteDebugTools() {
    _remoteDebugPollTimer?.cancel();
    _remoteStatusHeartbeatTimer?.cancel();

    _remoteDebugPollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_remoteConsoleAutoRefresh) return;
      if (_section != TrackerWorkspaceSection.debug &&
          _section != TrackerWorkspaceSection.devices &&
          _section != TrackerWorkspaceSection.live) return;
      unawaited(_loadRemoteDebugLogs(silent: true));
    });

    _remoteStatusHeartbeatTimer =
        Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) return;
      unawaited(_sendRemoteStatusHeartbeat());
    });

    unawaited(_sendRemoteStatusHeartbeat(source: 'workspace_open'));
    unawaited(_loadRemoteDebugLogs(silent: true));
  }

  Future<void> _sendRemoteStatusHeartbeat(
      {String source = 'workspace_status'}) async {
    final device = _remoteConnectedDevice;
    // Чтобы администратор, который просто открыл удалённый терминал без BLE,
    // не засорял общую ленту пустыми статусами. Ошибки scan/connect всё равно уходят отдельно.
    final lastKnown = _lastKnownBleDevice;
    if (device == null &&
        lastKnown == null &&
        !_liveRunning &&
        _points.isEmpty &&
        _lastTrackerPacketAt == null) return;

    final hasFreshGps = _lastWorkspaceGpsAt != null &&
        DateTime.now().difference(_lastWorkspaceGpsAt!).inSeconds <= 20;
    final level = device == null
        ? 'warning'
        : (hasFreshGps || !_liveRunning ? 'info' : 'warning');
    final gpsState = hasFreshGps
        ? _lastWorkspaceGps
        : (_liveRunning
            ? 'Live запущен · ожидаем первый GPS-пакет'
            : 'BLE готовы · ждут общий Старт Live');
    final status = device == null
        ? 'REMOTE STATUS: BLE TX/RX не готов${lastKnown == null ? '' : ' · выбран ${lastKnown.name} / ${lastKnown.id}'} · ${_remoteClientLabel()}'
        : 'REMOTE STATUS: ${_remoteClientLabel()} · GPS=${_teamBlePool.connectedCount} · Polar=${_heart.connectedCount} · live=$_liveRunning · gps=$gpsState · field=${_selectedField?.title ?? 'нет'}';
    await _logRemote(status, level: level, source: source);
  }

  Future<void> _loadRemoteDebugLogs({bool silent = false}) async {
    if (_remoteDebugLoading) return;
    if (mounted && !silent) setState(() => _remoteDebugLoading = true);
    _remoteDebugLoading = true;
    try {
      final logs =
          await _liveApi.loadDebugLogs(teamId: widget.teamId, limit: 180);
      if (!mounted) return;
      final remoteTrackers = _RemoteTrackerPresence.fromLogs(logs);
      setState(() {
        _remoteDebugLogs
          ..clear()
          ..addAll(logs);
        _remoteConnectedTrackers
          ..clear()
          ..addAll(remoteTrackers);
        _lastRemoteConsoleLoadAt = DateTime.now();
      });
      if (!silent) {
        _pushLocalLog(
            '[REMOTE TERMINAL OK] получено ${logs.length} строк с сервера');
      }
    } catch (e) {
      if (!mounted) return;
      _pushLocalLog('[REMOTE TERMINAL ERROR] $e', dedupe: true);
    } finally {
      _remoteDebugLoading = false;
      if (mounted && !silent) setState(() {});
    }
  }

  Future<void> _logRemote(
    String message, {
    String level = 'info',
    String source = 'workspace',
    String? rawHex,
    Map<String, dynamic>? extra,
  }) async {
    try {
      final device = _remoteConnectedDevice;
      await _liveApi.sendDebugLog(
        teamId: widget.teamId,
        playerId: null,
        liveSessionId: _activeLiveSessionId,
        level: level,
        source: source,
        message: message,
        rawHex: rawHex,
        platform: 'flutter_tracker',
        appVersion: 'tracker_v75_remote_debug_ai_focus_fix',
        deviceUuid: device?.id,
        deviceName: device?.name,
        context: <String, dynamic>{
          ..._remoteDebugContext(),
          if (extra != null) ...extra
        },
      );
      _lastRemoteDebug = 'OK · $source · ${DateTime.now().toIso8601String()}';
      if (source != 'workspace_status') {
        _pushLocalLog('[REMOTE DEBUG OK] $source отправлен на сервер');
      }
    } catch (e) {
      _lastRemoteDebug = 'ОШИБКА debug endpoint: $e';
      _pushLocalLog('[REMOTE DEBUG ERROR] $e', dedupe: true);
      // Удалённый debug не должен ломать работу трекера.
    }
  }

  double _distanceMeters(ActionTrackerGpsPoint a, ActionTrackerGpsPoint b) {
    const earthRadiusM = 6371000.0;
    final lat1 = a.latitude * math.pi / 180.0;
    final lat2 = b.latitude * math.pi / 180.0;
    final dLat = (b.latitude - a.latitude) * math.pi / 180.0;
    final dLon = (b.longitude - a.longitude) * math.pi / 180.0;
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return earthRadiusM * 2 * math.atan2(math.sqrt(h), math.sqrt(1 - h));
  }

  int? _tooCloseCalibrationCornerIndex(ActionTrackerGpsPoint point) {
    for (var i = 0; i < _calibrationCorners.length; i++) {
      if (_distanceMeters(_calibrationCorners[i], point) < 2.0) return i;
    }
    return null;
  }

  void _showCalibrationFlash(String label) {
    _calibrationFlashTimer?.cancel();
    setState(() {
      _calibrationFlashLabel = label;
      _calibrationFlashSeed++;
    });
    _calibrationFlashTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      setState(() => _calibrationFlashLabel = null);
    });
  }

  Future<ActionTrackerGpsPoint?> _waitForFreshCalibrationPoint(
      int nextIndex) async {
    final beforeCount = _points.length;
    final beforeGpsAt = _lastWorkspaceGpsAt;
    final beforePoint = _lastWorkspaceGpsPoint;

    final commands = ActionTrackerBleProfile.commandCurrentGpsCandidates;
    final maxCandidates = math.min(commands.length, 8);
    var candidateIndex = 0;
    var lastTxAt = DateTime.fromMillisecondsSinceEpoch(0);

    Future<void> sendCandidate() async {
      final now = DateTime.now();
      if (now.difference(lastTxAt).inMilliseconds < 900) return;
      lastTxAt = now;
      final command = commands[candidateIndex];
      final hex = command
          .map((e) => e.toRadixString(16).padLeft(2, '0').toUpperCase())
          .join(' ');
      try {
        await _ble.sendRawCommand(command);
        unawaited(_logRemote(
          'Калибровка: TX $hex для угла ${[
            'A',
            'B',
            'C',
            'D'
          ][nextIndex]} · candidate=${candidateIndex + 1}/$maxCandidates',
          source: 'workspace_calibration_tx',
          rawHex: hex,
        ));
      } catch (e) {
        unawaited(_logRemote(
          'Калибровка: не удалось отправить GPS-запрос $hex: $e',
          level: 'error',
          source: 'workspace_calibration_tx_error',
          rawHex: hex,
        ));
      }
      candidateIndex = (candidateIndex + 1) % maxCandidates;
    }

    await sendCandidate();

    final deadline = DateTime.now().add(const Duration(seconds: 8));
    while (mounted && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 220));
      if (_points.length > beforeCount && _isValidGpsPoint(_points.last))
        return _points.last;
      final latest = _lastWorkspaceGpsPoint;
      if (latest != null &&
          _lastWorkspaceGpsAt != null &&
          _lastWorkspaceGpsAt != beforeGpsAt &&
          _isValidGpsPoint(latest)) {
        return latest;
      }
      await sendCandidate();
    }

    final latest = _lastWorkspaceGpsPoint;
    final gpsAgeOk = _lastWorkspaceGpsAt != null &&
        DateTime.now().difference(_lastWorkspaceGpsAt!).inSeconds <= 10;
    if (latest != null && gpsAgeOk && _isValidGpsPoint(latest)) {
      if (beforePoint == null ||
          _distanceMeters(beforePoint, latest) > 0.2 ||
          _calibrationCorners.isEmpty) return latest;
    }

    return null;
  }

  String _workspaceDebugDump() {
    final packetAge = _lastTrackerPacketAt == null
        ? 'нет'
        : '${DateTime.now().difference(_lastTrackerPacketAt!).inSeconds}s';
    final gpsAge = _lastWorkspaceGpsAt == null
        ? 'нет'
        : '${DateTime.now().difference(_lastWorkspaceGpsAt!).inSeconds}s';
    return [
      'team=${widget.teamId} ${widget.teamName}',
      'player=${_selectedPlayer?.id ?? 'none'} ${_selectedPlayer?.name ?? ''}',
      'ble=${_hasAnyGpsCommandChannel ? '${_teamBlePool.connectedCount} team GPS ready' : 'off'} ${_remoteConnectedDevice?.id ?? ''}',
      'ble_command_channel=${_hasAnyGpsCommandChannel ? 'ready' : 'not_ready'}',
      'live_running=$_liveRunning live_id=${_activeLiveSessionId ?? 'none'}',
      'field=${_selectedField?.id ?? 'none'} ${_selectedField?.title ?? ''} calibration=${_selectedField?.hasCalibration == true}',
      'points=${_points.length} calibration_corners=${_calibrationCorners.length}',
      'last_packet_age=$packetAge',
      'last_rx=$_lastWorkspaceRx',
      'last_gps=$_lastWorkspaceGps gps_age=$gpsAge',
      'remote_debug=$_lastRemoteDebug',
      'battery=${_batteryPercent ?? 'нет'}',
      'logs=${_logs.take(20).join(' | ')}',
    ].join('\n');
  }

  Future<void> _sendManualDebugDump() async {
    await _logRemote(_workspaceDebugDump(), source: 'workspace_manual_debug');
    await _loadRemoteDebugLogs(silent: true);
    _toast('Debug', 'Диагностика отправлена на сервер');
  }

  Future<void> _requestCurrentGpsFromDebug() async {
    try {
      await _ble.requestCurrentGpsCandidate(candidateIndex: 0);
      await _logRemote('Ручной debug: TX 3A запрос текущей GPS-точки',
          source: 'workspace_manual_gps_tx', rawHex: '3A');
      _toast('Debug', 'Запрос GPS отправлен в трекер');
    } catch (e) {
      await _logRemote('Ручной debug GPS ошибка: $e',
          level: 'error', source: 'workspace_manual_gps_error');
      _toast('Debug', '$e');
    }
  }

  List<ActionTrackerGpsPoint> _savedFieldCalibrationCorners(
      TrackerFieldModel? field) {
    if (field == null || !field.hasCalibration)
      return const <ActionTrackerGpsPoint>[];
    return <ActionTrackerGpsPoint>[
      ActionTrackerGpsPoint(
          timeMs: 0, latitude: field.cornerALat!, longitude: field.cornerALng!),
      ActionTrackerGpsPoint(
          timeMs: 0, latitude: field.cornerBLat!, longitude: field.cornerBLng!),
      ActionTrackerGpsPoint(
          timeMs: 0, latitude: field.cornerCLat!, longitude: field.cornerCLng!),
      ActionTrackerGpsPoint(
          timeMs: 0, latitude: field.cornerDLat!, longitude: field.cornerDLng!),
    ];
  }

  String _formatCalibrationCoordinate(ActionTrackerGpsPoint point) {
    return '${point.latitude.toStringAsFixed(6)}\n${point.longitude.toStringAsFixed(6)}';
  }

  String _savedFieldCoordinateSubtitle(TrackerFieldModel field) {
    final corners = _savedFieldCalibrationCorners(field);
    if (corners.length < 4) return 'координаты не сохранены';
    return 'A ${corners[0].latitude.toStringAsFixed(5)}, ${corners[0].longitude.toStringAsFixed(5)} · B ${corners[1].latitude.toStringAsFixed(5)}, ${corners[1].longitude.toStringAsFixed(5)}';
  }

  void _startRecalibrationCurrentField() {
    final field = _selectedField;
    setState(() {
      _calibrationCorners.clear();
      if (field != null) {
        _selectedField = TrackerFieldModel(
          id: field.id,
          clubId: field.clubId ?? widget.clubId,
          teamId: field.teamId ?? widget.teamId,
          title: field.title,
          lengthM: field.lengthM,
          widthM: field.widthM,
          isDefault: field.isDefault,
        );
      }
    });
    _toast('Калибровка',
        'Можно перезаписать углы A → B → C → D для выбранного поля.');
  }

  void _clearSelectedField() {
    setState(() {
      _selectedField = null;
      _calibrationCorners.clear();
    });
    _toast(
        'Поле', 'Поле убрано из текущей аналитики. Данные сессий не удалены.');
  }

  Future<void> _loadServerData() async {
    if (mounted) setState(() => _loading = true);
    try {
      final results = await Future.wait<dynamic>([
        if (_players.isEmpty)
          _api.loadPlayers(teamId: widget.teamId)
        else
          Future<List<TrackerPlayerOption>>.value(_players),
        _api.loadDevices(teamId: widget.teamId),
        _api.loadFields(teamId: widget.teamId),
      ]);
      if (!mounted) return;
      setState(() {
        _players = results[0] as List<TrackerPlayerOption>;
        _savedDevices = results[1] as List<TrackerDeviceModel>;
        _fields = results[2] as List<TrackerFieldModel>;
        if (_selectedPlayer == null ||
            !_players.any((p) => p.id == _selectedPlayer!.id)) {
          // Командный экран не принадлежит первому игроку в ответе API.
          // Игрок выбирается только явно или через initialPlayerId.
          _selectedPlayer = null;
          final requestedPlayerId = widget.initialPlayerId;
          if (requestedPlayerId != null && requestedPlayerId > 0) {
            for (final player in _players) {
              if (player.id == requestedPlayerId) {
                _selectedPlayer = player;
                break;
              }
            }
          }
        }

        if (_fields.isEmpty) {
          _selectedField = null;
        } else if (_selectedField == null ||
            !_fields.any((f) => f.id == _selectedField!.id)) {
          _selectedField = _fields.firstWhere((f) => f.isDefault,
              orElse: () => _fields.first);
        }
      });
    } catch (e) {
      unawaited(_logRemote('Ошибка загрузки данных трекера: $e',
          level: 'error', source: 'workspace_load_error'));
      _toast('Трекер', 'Ошибка загрузки: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _livePanelKeySuffix {
    // Ключ LivePanel должен быть стабильным даже если BLE на секунду потерялся.
    // Нельзя включать сюда _connected/_ble.connectedInfo: при временном разрыве
    // менялся key, LivePanel пересоздавался и dispose() завершал сессию.
    return 'team_${widget.teamId}_${_selectedField?.id ?? 0}';
  }

  int? get _batteryPercent {
    final battery = _battery;
    if (battery == null) return null;
    return (battery.voltage * 10).round().clamp(0, 100);
  }

  String _friendlyBleError(Object error) {
    final raw = '$error';
    final lower = raw.toLowerCase();
    final isIOS = !kIsWeb && Platform.isIOS;
    final isMac = !kIsWeb && Platform.isMacOS;
    final isAndroid = !kIsWeb && Platform.isAndroid;

    if (raw.contains('CBManagerStateUnsupported')) {
      return isIOS
          ? 'Bluetooth недоступен на этом iPhone/iPad. Проверьте, что Bluetooth включён и приложение собрано с iOS Bluetooth-разрешениями.'
          : 'Bluetooth недоступен в текущей среде. На macOS запустите именно desktop-приложение, включите Bluetooth и проверьте разрешения для приложения.';
    }
    if (lower.contains('bluetooth must be turned on') ||
        lower.contains('poweredoff')) {
      if (isIOS)
        return 'Bluetooth выключен. На iPhone откройте Пункт управления или Настройки → Bluetooth, включите Bluetooth и повторите поиск трекера.';
      if (isAndroid)
        return 'Bluetooth выключен. Включите Bluetooth и разрешение «Устройства поблизости», затем повторите поиск трекера.';
      return 'Bluetooth выключен. Включите Bluetooth на Mac и повторите поиск трекера.';
    }
    if (isAndroid &&
        (lower.contains('android-code: 133') ||
            lower.contains('android code: 133') ||
            lower.contains('gatt_error') && lower.contains('133'))) {
      final gps = _teamBlePool.connectedCount;
      final polar = _heart.connectedCount;
      final total = gps + polar;
      return 'Android временно не открыл новый BLE-канал (GATT 133). '
          'Сейчас активно: GPS $gps + Polar $polar = $total. '
          'Приложение уже выполнило безопасные повторы; подождите несколько секунд и нажмите «Назначить» ещё раз.';
    }
    if (lower.contains('permission') ||
        lower.contains('unauthorized') ||
        lower.contains('denied') ||
        lower.contains('restricted')) {
      if (isIOS) {
        return 'Нет разрешения Bluetooth для поиска трекера. Откройте iPhone → Настройки → Спортотека → Bluetooth и включите доступ. Если такого переключателя нет, добавьте в ios/Runner/Info.plist ключи NSBluetoothAlwaysUsageDescription и NSBluetoothPeripheralUsageDescription, затем пересоберите приложение.';
      }
      if (isAndroid) {
        return 'Нет разрешения Bluetooth. Откройте настройки приложения и разрешите «Устройства поблизости»/Bluetooth, а для старых Android также геолокацию.';
      }
      if (isMac) {
        return 'Нет разрешения на Bluetooth. Откройте Системные настройки macOS → Конфиденциальность и безопасность → Bluetooth и разрешите доступ приложению.';
      }
      return 'Нет разрешения Bluetooth для поиска трекера. Проверьте системные настройки приложения.';
    }
    return raw;
  }

  List<String> _knownBleIdsForScan() {
    return <String>{
      ..._savedDevices.map((d) => d.deviceUuid),
      ..._remoteConnectedTrackers.map((r) => r.uuid),
      ..._teamBlePool.connectedInfos.map((d) => d.id),
      if (_ble.lastKnownInfo != null) _ble.lastKnownInfo!.id,
      if (_ble.connectedInfo != null) _ble.connectedInfo!.id,
    }.where((e) => e.trim().isNotEmpty).toList(growable: false);
  }

  List<String> _knownBleNamesForScan() {
    return <String>{
      ..._savedDevices.map((d) => d.deviceName),
      ..._remoteConnectedTrackers.map((r) => r.name),
      ..._teamBlePool.connectedInfos.map((d) => d.name),
      if (_ble.lastKnownInfo != null) _ble.lastKnownInfo!.name,
      if (_ble.connectedInfo != null) _ble.connectedInfo!.name,
    }.where((e) => e.trim().isNotEmpty).toList(growable: false);
  }

  Future<void> _scan({bool clean = false, bool universalMode = false}) async {
    setState(() => _scanning = true);
    try {
      await TrackerPermissions.ensureBlePermissions();
      final diagnostics = await TrackerPermissions.diagnostics();
      final knownIds = _knownBleIdsForScan();
      final knownNames = _knownBleNamesForScan();
      _pushLocalLog(
          '[BLE DIAG] $diagnostics · knownIds=${knownIds.length} · knownNames=${knownNames.length} · mode=${universalMode ? 'universal-compatible' : 'auto'}');
      unawaited(_logRemote(
        'BLE поиск запущен: clean=$clean · mode=${universalMode ? 'universal-compatible' : 'auto'} · $diagnostics',
        source: clean
            ? 'workspace_ble_clean_scan_start'
            : 'workspace_ble_scan_start',
        extra: <String, dynamic>{
          'known_ids': knownIds,
          'known_names': knownNames,
          'clean_scan': clean,
          'universal_mode': universalMode
        },
      ));
      unawaited(_logRemote(
        'BLE диагностика перед поиском: $diagnostics · knownIds=${knownIds.length} · knownNames=${knownNames.length} · mode=${universalMode ? 'universal-compatible' : 'auto'}',
        source: 'workspace_ble_diagnostics',
        extra: <String, dynamic>{
          'known_ids': knownIds,
          'known_names': knownNames,
          'universal_mode': universalMode
        },
      ));

      if (clean) {
        unawaited(_logRemote(
            'Чистый поиск BLE: локальный канал сброшен перед scan',
            source: 'workspace_ble_clean_scan_reset'));
        _logs.insert(0, '[BLE] CLEAN SCAN START → reset + universal scan');
        await _ble.cleanScan(
            knownDeviceIds: knownIds,
            knownDeviceNames: knownNames,
            universalMode: universalMode);
        unawaited(_logRemote(
            'Чистый поиск BLE завершён. Смотрите GPS SCAN RAW TOP / CANDIDATES TOP в debug.',
            source: 'workspace_ble_clean_scan_end'));
      } else {
        await _ble.scan(
            knownDeviceIds: knownIds,
            knownDeviceNames: knownNames,
            universalMode: universalMode);
      }
    } catch (e) {
      unawaited(_logRemote('Ошибка BLE scan: $e',
          level: 'error',
          source: clean
              ? 'workspace_ble_clean_scan_error'
              : 'workspace_ble_scan_error'));
      _toast('Bluetooth', _friendlyBleError(e));
    } finally {
      unawaited(
          _sendRemoteStatusHeartbeat(source: 'workspace_ble_scan_status'));
      unawaited(_loadRemoteDebugLogs(silent: true));
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _resetBleState() async {
    try {
      await _ble.resetLocalState(clearKnownDevice: true);
      setState(() {
        _connected = null;
        _battery = null;
        _points.clear();
        _records.clear();
        _selectedRecord = null;
        _offlineAutoSyncInProgress = false;
        _offlineAutoSaveAfterTransfer = false;
        _offlineAutoSyncKey = null;
        _trackerRecordingStatus = 'запись на трекере не проверялась';
        _lastRecordListAt = null;
        _lastWorkspaceGpsPoint = null;
        _lastWorkspaceGpsAt = null;
        _lastTrackerPacketAt = null;
        _lastWorkspaceRx = 'нет пакетов';
        _lastWorkspaceGps = 'нет GPS';
      });
      _logs.insert(0, '[BLE] RESET DONE → очищены device/TX/RX/GPS/records');
      unawaited(_logRemote(
          'BLE сброшен локально: device/TX/RX/GPS очищены, серверные привязки сохранены',
          source: 'workspace_ble_reset'));
      _toast('BLE',
          'Локальный BLE сброшен. Сохранённые серверные привязки не удалены.');
    } catch (e) {
      unawaited(_logRemote('Ошибка BLE reset: $e',
          level: 'error', source: 'workspace_ble_reset_error'));
      _toast('BLE reset', '$e');
    }
  }

  Future<void> _connect(ActionTrackerDevice device) async {
    final player = _selectedPlayer;
    if (player == null) {
      _toast('Командный GPS',
          'Сначала выберите игрока. Трекер всегда подключается с жёсткой привязкой к игроку.');
      return;
    }

    final uuidOwner = _savedDevices
        .where((d) =>
            !_isHeartRateDeviceModel(d) &&
            d.deviceUuid == device.id &&
            d.playerId != null &&
            d.playerId != player.id)
        .toList(growable: false);
    if (uuidOwner.isNotEmpty) {
      final owner = _players
          .where((p) => p.id == uuidOwner.first.playerId)
          .toList(growable: false);
      _toast('Привязка заблокирована',
          '${device.name} уже закреплён за ${owner.isEmpty ? 'другим игроком' : owner.first.name}. Сначала снимите старую привязку.');
      return;
    }

    final playerGps = _savedDevices
        .where((d) =>
            !_isHeartRateDeviceModel(d) &&
            d.playerId == player.id &&
            d.deviceUuid != device.id)
        .toList(growable: false);
    if (playerGps.isNotEmpty) {
      _toast('Привязка заблокирована',
          '${player.name} уже закреплён за ${playerGps.first.deviceName}. Сначала снимите старую привязку.');
      return;
    }

    setState(() => _connecting = true);
    try {
      await TrackerPermissions.ensureBlePermissions();
      await _teamBlePool.connect(device);
      _connected = device;
      if (mounted) setState(() {});
      await _api.registerOrBindDevice(
        clubId: widget.clubId,
        teamId: widget.teamId,
        playerId: player.id,
        deviceUuid: device.id,
        deviceName: device.name,
        batteryPercent: _batteryPercent,
      );
      _rememberConfirmedTeamBinding(
        player: player,
        deviceUuid: device.id,
        deviceName: device.name,
        batteryPercent: _batteryPercent,
      );
      unawaited(_logRemote(
        'TEAM BLE подключён: ${device.name} / ${device.id} → ${player.name} · одновременно ${_teamBlePool.connectedCount}',
        source: 'workspace_team_ble_connected',
      ));
      _toast('Подключено',
          '${device.name} → ${player.name} · всего ${_teamBlePool.connectedCount}');
      await _loadServerData();
    } catch (e) {
      unawaited(_logRemote('Ошибка TEAM BLE connect: $e',
          level: 'error', source: 'workspace_team_ble_connect_error'));
      _toast('Подключение', '$e');
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  List<TeamTrackerBinding> _teamLiveBindings() {
    final result = <TeamTrackerBinding>[];
    final usedPlayers = <int>{};
    final usedDevices = <String>{};
    for (final connected in _teamBlePool.connectedInfos) {
      final confirmed = _confirmedTeamGpsBindings[
          _teamBindingKey(connected.id, connected.name)];
      final savedMatches = _savedDevices
          .where((d) =>
              !_isHeartRateDeviceModel(d) &&
              d.playerId != null &&
              d.playerId! > 0 &&
              _trackerIdOrNameMatches(connected.id, connected.name, d))
          .toList(growable: false);

      TeamTrackerBinding? binding;
      if (confirmed != null) {
        binding = TeamTrackerBinding(
          playerId: confirmed.playerId,
          playerName: confirmed.playerName,
          deviceUuid: connected.id,
          deviceName: connected.name,
          batteryPercent: confirmed.batteryPercent,
        );
      } else if (savedMatches.isNotEmpty) {
        final exactMatches = savedMatches
            .where((d) =>
                _normalizeDeviceId(d.deviceUuid) ==
                _normalizeDeviceId(connected.id))
            .toList(growable: false);
        final d =
            exactMatches.isNotEmpty ? exactMatches.first : savedMatches.first;
        final player = _playerOptionForIdentity(d.playerId!);
        binding = TeamTrackerBinding(
          // tracker_devices.player_id — канонический players.id. Не отбрасываем
          // привязку, если состав пришёл с user_id как основным id.
          playerId: d.playerId!,
          playerName: player?.name ?? d.playerName ?? 'Игрок #${d.playerId}',
          deviceUuid: connected.id,
          deviceName: connected.name,
          batteryPercent: d.batteryPercent,
        );
      }

      if (binding == null) continue;
      final normalizedDeviceId = _normalizeDeviceId(binding.deviceUuid);
      if (!usedPlayers.add(binding.playerId) ||
          !usedDevices.add(normalizedDeviceId)) {
        continue;
      }
      result.add(binding);
    }
    return result;
  }

  Future<int?> _startTeamLiveFromPanel() async {
    var bindings = _teamLiveBindings();
    if (bindings.isEmpty && _teamBlePool.connectedCount > 0) {
      // После bind серверная выдача устройств могла ещё не успеть попасть в
      // локальный список. Один раз перечитываем её перед отказом запуска.
      await _loadServerData();
      bindings = _teamLiveBindings();
    }
    if (bindings.isEmpty) {
      unawaited(_logRemote(
        'TEAM LIVE BLOCKED: BLE=${_teamBlePool.connectedCount}, bindings=0',
        level: 'error',
        source: 'workspace_team_live_binding_error',
        extra: <String, dynamic>{
          'connected_gps': _teamBlePool.connectedInfos
              .map((d) => <String, dynamic>{
                    'device_uuid': d.id,
                    'device_name': d.name,
                  })
              .toList(growable: false),
          'confirmed_bindings': _confirmedTeamGpsBindings.values
              .map((b) => <String, dynamic>{
                    'player_id': b.playerId,
                    'player_name': b.playerName,
                    'device_uuid': b.deviceUuid,
                    'device_name': b.deviceName,
                  })
              .toList(growable: false),
          'saved_gps_bindings': _savedDevices
              .where((d) =>
                  !_isHeartRateDeviceModel(d) &&
                  d.playerId != null &&
                  d.playerId! > 0)
              .map((d) => <String, dynamic>{
                    'player_id': d.playerId,
                    'player_name': d.playerName,
                    'device_uuid': d.deviceUuid,
                    'device_name': d.deviceName,
                  })
              .toList(growable: false),
        },
      ));
      throw StateError(
        'BLE-каналы открыты (${_teamBlePool.connectedCount}), но не удалось сопоставить их с игроками. Переподключать GPS не нужно — обновите привязки.',
      );
    }
    unawaited(_logRemote(
      'TEAM LIVE PREFLIGHT: игроков=${bindings.length} · BLE=${_teamBlePool.connectedCount}',
      source: 'workspace_team_live_preflight',
      extra: <String, dynamic>{
        'bindings': bindings
            .map((binding) => <String, dynamic>{
                  'player_id': binding.playerId,
                  'player_name': binding.playerName,
                  'device_uuid': binding.deviceUuid,
                  'device_name': binding.deviceName,
                })
            .toList(growable: false),
      },
    ));
    try {
      _teamLiveCoordinator.fieldId = _selectedField?.id;
      await _teamLiveCoordinator.start(bindings);
      final ids = _teamLiveCoordinator.debugRows
          .map((e) => e.liveSessionId)
          .whereType<int>()
          .toList(growable: false);
      if (ids.length != bindings.length) {
        throw StateError(
          'Сервер создал ${ids.length} из ${bindings.length} Live-сессий',
        );
      }
      unawaited(_logRemote(
        'TEAM LIVE START: игроков=${bindings.length} · BLE=${_teamBlePool.connectedCount} · sessions=${ids.join(',')}',
        source: 'workspace_team_live_start',
      ));
      return ids.first;
    } catch (e) {
      unawaited(_logRemote(
        'TEAM LIVE START ERROR: $e',
        level: 'error',
        source: 'workspace_team_live_start_error',
        extra: <String, dynamic>{
          'connected_count': _teamBlePool.connectedCount,
          'bindings_count': bindings.length,
          'connected_gps': _teamBlePool.connectedInfos
              .map((device) => <String, dynamic>{
                    'device_uuid': device.id,
                    'device_name': device.name,
                  })
              .toList(growable: false),
        },
      ));
      rethrow;
    }
  }

  Future<void> _stopTeamLiveFromPanel(bool createFinalSession) async {
    await _teamLiveCoordinator.stop(createFinalSession: createFinalSession);
    unawaited(_logRemote('TEAM LIVE STOP: final=$createFinalSession',
        source: 'workspace_team_live_stop'));
  }

  Future<void> _openTeamLiveDebug() async {
    await showDialog<void>(
      context: context,
      builder: (_) => TeamLiveDebugDialog(coordinator: _teamLiveCoordinator),
    );
  }

  Future<void> _resetAllTeamTrackers() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Сбросить все трекеры?'),
        content: Text(
            'Будут остановлены все каналы командного Live и отключены ${_teamBlePool.connectedCount} GPS-трекеров. Серверные привязки игроков сохранятся.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Отмена')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Сбросить все')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      if (_teamLiveCoordinator.running) {
        await _teamLiveCoordinator.stop(createFinalSession: true);
      }
      await _teamBlePool.disconnectAll();
      await _ble.resetLocalState(clearKnownDevice: true);
      if (!mounted) return;
      setState(() {
        _connected = null;
        _battery = null;
        _liveRunning = false;
        _activeLiveSessionId = null;
        _points.clear();
        _records.clear();
      });
      unawaited(_logRemote(
          'TEAM RESET ALL: отключены все GPS каналы, привязки сохранены',
          source: 'workspace_team_reset_all'));
      _toast('Командные трекеры',
          'Все GPS-трекеры отключены. Привязки игроков сохранены.');
    } catch (e) {
      _toast('Сброс трекеров', '$e');
    }
  }

  Future<void> _scanHeartRate({bool showAllBleCandidates = false}) async {
    setState(() => _scanningHeart = true);
    try {
      await TrackerPermissions.ensureBlePermissions();
      final diagnostics = await TrackerPermissions.diagnostics();
      final mode =
          showAllBleCandidates ? 'all-ble-diagnostic' : 'heart-rate-180D';
      _pushLocalLog('[HEART DIAG] $diagnostics · mode=$mode');
      unawaited(_logRemote(
          'Поиск пульсометра запущен: Polar H10 / $mode · $diagnostics',
          source: 'workspace_heart_rate_scan_start'));
      await _heart.scan(showAllBleCandidates: showAllBleCandidates);
    } catch (e) {
      unawaited(_logRemote('Ошибка Heart Rate scan: $e',
          level: 'error', source: 'workspace_heart_rate_scan_error'));
      _toast('Polar H10', _friendlyBleError(e));
    } finally {
      if (mounted) setState(() => _scanningHeart = false);
    }
  }

  Future<void> _connectHeartRate(HeartRateBleDevice device) async {
    setState(() {
      _connectingHeart = true;
      _selectedHeartDeviceId = device.id;
    });
    try {
      await TrackerPermissions.ensureBlePermissions();
      await _heart.connect(device);
      setState(() {
        _connectedHeart = _heart.connectedDevice(device.id) ?? device;
        _selectedHeartDeviceId = device.id;
      });
      unawaited(_logRemote(
        'Пульсометр подключён: ${device.name} / ${device.id} · выберите игрока в строке датчика · всего ${_heart.connectedCount}/12',
        source: 'workspace_heart_rate_connected',
      ));
      _toast('Polar H10',
          'Подключён ${device.name}. Теперь выберите игрока в строке этого датчика.');
    } catch (e) {
      unawaited(_logRemote('Ошибка Heart Rate connect: $e',
          level: 'error', source: 'workspace_heart_rate_connect_error'));
      _toast('Polar H10', '$e');
    } finally {
      if (mounted) setState(() => _connectingHeart = false);
    }
  }

  Future<void> _resetHeartRateState() async {
    try {
      await _heart.resetLocalState();
      setState(() {
        _connectedHeart = null;
        _latestHeartSample = null;
        _latestHeartByPlayerId.clear();
        _heartDevicePlayerIds.clear();
        _selectedHeartDeviceId = null;
        _lastHeartSampleUploadAt.clear();
        _heartSampleUploadInFlight.clear();
      });
      _toast('Polar H10', 'Подключение пульсометра очищено.');
    } catch (e) {
      _toast('Polar H10', '$e');
    }
  }

  void _bindHeartRateToSelectedPlayer() {
    final selectedId = _selectedHeartDeviceId ??
        _heart.connectedInfo?.id ??
        _connectedHeart?.id;
    final device = selectedId == null
        ? null
        : (_heart.connectedDevice(selectedId) ??
            _heart.connectedInfo ??
            _connectedHeart);
    final player = _selectedPlayer;
    if (device == null) {
      _toast('Polar H10',
          'Сначала подключите пульсометр или нажмите его в списке.');
      return;
    }
    if (player == null) {
      _toast('Polar H10', 'Сначала выберите игрока в составе.');
      return;
    }
    setState(() {
      _selectedHeartDeviceId = device.id;
      _heartDevicePlayerIds[device.id] = player.id;
      final sample = _heart.lastSampleForDevice(device.id) ??
          (_latestHeartSample?.deviceId == device.id
              ? _latestHeartSample
              : null);
      if (sample != null) _latestHeartByPlayerId[player.id] = sample;
    });
    final sample = _heart.lastSampleForDevice(device.id);
    if (sample != null)
      unawaited(_uploadHeartRateSample(sample, playerId: player.id));
    _toast('Polar H10', '${device.name} назначен игроку ${player.name}');
  }

  void _bindHeartRateDeviceToPlayer(HeartRateBleDevice device, int? playerId) {
    final oldPlayerId = _heartDevicePlayerIds[device.id];
    TrackerPlayerOption? player;
    if (playerId != null) {
      final matches = _players.where((p) => p.id == playerId).toList();
      if (matches.isNotEmpty) player = matches.first;
    }
    final sample = _heart.lastSampleForDevice(device.id) ??
        (_latestHeartSample?.deviceId == device.id ? _latestHeartSample : null);

    setState(() {
      _selectedHeartDeviceId = device.id;
      if (oldPlayerId != null && oldPlayerId != playerId) {
        final oldSample = _latestHeartByPlayerId[oldPlayerId];
        if (oldSample?.deviceId == device.id)
          _latestHeartByPlayerId.remove(oldPlayerId);
      }
      if (playerId == null || playerId <= 0) {
        _heartDevicePlayerIds.remove(device.id);
      } else {
        _heartDevicePlayerIds[device.id] = playerId;
        if (sample != null) _latestHeartByPlayerId[playerId] = sample;
      }
    });

    if (playerId != null && playerId > 0 && sample != null) {
      unawaited(_uploadHeartRateSample(sample, playerId: playerId));
    }
    unawaited(_api
        .registerOrBindDevice(
          clubId: widget.clubId,
          teamId: widget.teamId,
          playerId: playerId != null && playerId > 0 ? playerId : null,
          deviceUuid: device.id,
          deviceName: device.name,
          batteryPercent: sample?.batteryPercent,
        )
        .then((_) => _loadServerData())
        .catchError((e) {
      unawaited(_logRemote('Ошибка сохранения привязки Polar H10: $e',
          level: 'warning', source: 'workspace_heart_rate_bind_save_error'));
    }));
    _toast(
        'Polar H10',
        player == null
            ? '${device.name}: игрок снят'
            : '${device.name} → ${player.name}');
  }

  bool _isHeartRateDeviceModel(TrackerDeviceModel device) {
    final text = '${device.deviceName} ${device.deviceUuid}'.toLowerCase();
    return text.contains('polar') ||
        text.contains('h10') ||
        text.contains('heart') ||
        text.contains('hrm');
  }

  List<TrackerDeviceModel> _gpsDevicesForPlayer(int playerId) {
    return _mergedSavedDevices
        .where((d) => d.playerId == playerId && !_isHeartRateDeviceModel(d))
        .toList(growable: false);
  }

  List<String> _heartDeviceNamesForPlayer(int playerId) {
    final names = <String>[];
    for (final entry in _heartDevicePlayerIds.entries) {
      if (entry.value != playerId) continue;
      final sample = _heart.lastSampleForDevice(entry.key);
      final device = _heart.connectedDevice(entry.key) ?? _connectedHeart;
      names.add(sample?.deviceName ?? device?.name ?? 'Polar H10');
    }
    for (final d in _savedDevices
        .where((d) => d.playerId == playerId && _isHeartRateDeviceModel(d))) {
      if (!names.any((n) => n == d.deviceName)) names.add(d.deviceName);
    }
    return names;
  }

  String _equipmentStatusForPlayer(TrackerPlayerOption player) {
    final gps = _gpsDevicesForPlayer(player.id)
        .map((d) => d.deviceName)
        .toList(growable: false);
    final polar = _heartDeviceNamesForPlayer(player.id);
    final parts = <String>[
      gps.isEmpty
          ? 'GPS —'
          : 'GPS ${gps.first}${gps.length > 1 ? ' +${gps.length - 1}' : ''}',
      polar.isEmpty
          ? 'Polar —'
          : 'Polar ${polar.first}${polar.length > 1 ? ' +${polar.length - 1}' : ''}',
    ];
    return parts.join(' · ');
  }

  List<TrackerDeviceModel> _teamGpsDeviceCandidates(
      {List<ActionTrackerDevice> scannedDevices =
          const <ActionTrackerDevice>[]}) {
    final byUuid = <String, TrackerDeviceModel>{};

    void addCandidate({
      required String uuid,
      required String name,
      int? batteryPercent,
      int? playerId,
      String? playerName,
      bool isNearby = false,
    }) {
      final id = uuid.trim();
      if (id.isEmpty) return;
      final title = name.trim().isEmpty
          ? 'BLE ${id.length > 6 ? id.substring(id.length - 6) : id}'
          : name.trim();
      final existing = byUuid[id];
      byUuid[id] = TrackerDeviceModel(
        clubId: widget.clubId,
        teamId: widget.teamId,
        playerId: playerId ?? existing?.playerId,
        playerName: playerName ?? existing?.playerName,
        deviceUuid: id,
        deviceName: existing?.deviceName.isNotEmpty == true && !isNearby
            ? existing!.deviceName
            : title,
        batteryPercent:
            batteryPercent ?? existing?.batteryPercent ?? _batteryPercent,
        isNearby: isNearby || (existing?.isNearby ?? false),
      );
    }

    for (final d in _mergedSavedDevices) {
      if (_isHeartRateDeviceModel(d) || d.deviceUuid.trim().isEmpty) continue;
      addCandidate(
        uuid: d.deviceUuid,
        name: d.deviceName,
        batteryPercent: d.batteryPercent,
        playerId: d.playerId,
        playerName: d.playerName,
        isNearby: d.isNearby,
      );
    }

    for (final d in scannedDevices) {
      addCandidate(uuid: d.id, name: d.name, isNearby: true);
    }

    for (final connected in _teamBlePool.connectedInfos) {
      if (connected.id.trim().isEmpty) continue;
      addCandidate(
        uuid: connected.id,
        name: connected.name,
        batteryPercent: _batteryPercent,
        isNearby: true,
      );
    }

    return byUuid.values.toList(growable: false)
      ..sort((a, b) {
        final an = a.isNearby == true ? 0 : 1;
        final bn = b.isNearby == true ? 0 : 1;
        if (an != bn) return an.compareTo(bn);
        final aa = a.playerId == null ? 0 : 1;
        final bb = b.playerId == null ? 0 : 1;
        if (aa != bb) return aa.compareTo(bb);
        return a.deviceName.compareTo(b.deviceName);
      });
  }

  Future<void> _assignTrackerDeviceToPlayer(
      TrackerDeviceModel device, TrackerPlayerOption? player) async {
    try {
      await _api.registerOrBindDevice(
        clubId: widget.clubId,
        teamId: widget.teamId,
        playerId: player?.id,
        deviceUuid: device.deviceUuid,
        deviceName: device.deviceName,
        batteryPercent: device.batteryPercent ?? _batteryPercent,
      );
      if (player == null) {
        _forgetConfirmedTeamBinding(device.deviceUuid, device.deviceName);
      } else {
        _rememberConfirmedTeamBinding(
          player: player,
          deviceUuid: device.deviceUuid,
          deviceName: device.deviceName,
          batteryPercent: device.batteryPercent ?? _batteryPercent,
        );
      }
      if (mounted && player != null) {
        setState(() => _selectedPlayer = player);
      }
      await _loadServerData();
      _toast(
          'GPS-трекер',
          player == null
              ? '${device.deviceName}: игрок снят'
              : '${device.deviceName} → ${player.name}');
    } catch (e) {
      unawaited(_logRemote('Ошибка назначения GPS-трекера: $e',
          level: 'error', source: 'workspace_device_assign_error'));
      _toast('GPS-трекер', '$e');
    }
  }

  Future<void> _connectAndAssignHeartRate(
      HeartRateBleDevice device, TrackerPlayerOption player) async {
    try {
      if (!_heart.isConnected(device.id)) {
        await _connectHeartRate(device);
      }
      _bindHeartRateDeviceToPlayer(device, player.id);
    } catch (e) {
      _toast('Polar H10', '$e');
    }
  }

  InputDecoration _equipmentInput(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: _TD.borderStrong)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: _TD.borderStrong)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: _TD.greenBorder)),
      );

  Future<void> _openTeamEquipmentModal(
      {TrackerPlayerOption? initialPlayer}) async {
    if (_players.isEmpty) {
      _toast('Оборудование',
          'Игроки команды не загружены. Сначала обновите состав.');
      return;
    }

    TrackerPlayerOption selected =
        initialPlayer ?? _selectedPlayer ?? _players.first;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setModalState) {
            final width = MediaQuery.of(dialogContext).size.width;
            final compact = width < 760;

            Widget playerCard(TrackerPlayerOption player) {
              final active = selected.id == player.id;
              final gps = _gpsDevicesForPlayer(player.id);
              final polar = _heartDeviceNamesForPlayer(player.id);
              return Material(
                color: active ? _TD.greenSoft : Colors.white,
                borderRadius: BorderRadius.circular(6),
                child: _NoHoverTap(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () {
                    setModalState(() => selected = player);
                    setState(() => _selectedPlayer = player);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: active ? _TD.greenBorder : _TD.borderStrong),
                    ),
                    child: Row(children: [
                      _PlayerAvatarDark(
                        url: player.avatar,
                        initials: _playerInitials(player.name),
                        size: 36,
                        active: active,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(player.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: _TD.text,
                                    fontSize: 11.2,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Wrap(spacing: 5, runSpacing: 5, children: [
                              _EquipmentMiniBadge(
                                  icon: Icons.sensors_rounded,
                                  label: gps.isEmpty
                                      ? 'GPS —'
                                      : 'GPS ${gps.length}',
                                  active: gps.isNotEmpty),
                              _EquipmentMiniBadge(
                                  icon: Icons.favorite_rounded,
                                  label: polar.isEmpty
                                      ? 'Polar —'
                                      : 'Polar ${polar.length}',
                                  active: polar.isNotEmpty),
                            ]),
                          ])),
                      if (active)
                        const Icon(Icons.check_circle_rounded,
                            color: _TD.green, size: 19),
                    ]),
                  ),
                ),
              );
            }

            Widget playersList() {
              return ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: _players.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, index) => playerCard(_players[index]),
              );
            }

            Widget assignmentPane(
                List<HeartRateBleDevice> discoveredHeartDevices,
                List<ActionTrackerDevice> discoveredGpsDevices) {
              final gpsCandidates = _teamGpsDeviceCandidates(
                  scannedDevices: discoveredGpsDevices);
              final assignedGps = _gpsDevicesForPlayer(selected.id);
              final heartById = <String, HeartRateBleDevice>{};
              for (final d in discoveredHeartDevices) {
                heartById[d.id] = d;
              }
              for (final d in _heart.connectedInfos) {
                heartById[d.id] = d;
              }
              final heartCandidates = heartById.values.toList(growable: false)
                ..sort((a, b) {
                  final ac = _heart.isConnected(a.id) ? 0 : 1;
                  final bc = _heart.isConnected(b.id) ? 0 : 1;
                  if (ac != bc) return ac.compareTo(bc);
                  return b.rssi.compareTo(a.rssi);
                });
              final assignedHeartId = _heartDevicePlayerIds.entries
                  .where((e) => e.value == selected.id)
                  .map((e) => e.key)
                  .cast<String?>()
                  .firstWhere((_) => true, orElse: () => null);
              final gpsValue =
                  assignedGps.isEmpty ? null : assignedGps.first.deviceUuid;
              final heartValue = assignedHeartId != null &&
                      heartCandidates.any((d) => d.id == assignedHeartId)
                  ? assignedHeartId
                  : null;

              Widget scanStateLine(
                  {required bool active,
                  required int count,
                  required String emptyText}) {
                return Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6)),
                  child: Row(children: [
                    if (active) ...[
                      const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: _TD.green)),
                      const SizedBox(width: 8),
                    ] else
                      Icon(
                          count > 0
                              ? Icons.bluetooth_connected_rounded
                              : Icons.bluetooth_searching_rounded,
                          color: count > 0 ? _TD.green : _TD.muted,
                          size: 16),
                    if (!active) const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        active
                            ? 'Идёт сканирование Bluetooth… найдено: $count'
                            : (count > 0
                                ? 'Найдено Bluetooth-устройств: $count'
                                : emptyText),
                        style: const TextStyle(
                            color: _TD.muted,
                            fontSize: 10.2,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                  ]),
                );
              }

              Widget gpsDeviceList() {
                if (gpsCandidates.isEmpty) {
                  return scanStateLine(
                      active: _scanning,
                      count: 0,
                      emptyText:
                          'Список GPS/BLE пока пуст. Нажмите «Сканировать GPS» — найденные датчики появятся прямо здесь.');
                }
                return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      scanStateLine(
                          active: _scanning,
                          count: gpsCandidates.length,
                          emptyText: ''),
                      const SizedBox(height: 4),
                      ...gpsCandidates.map((d) {
                        final assignedToSelected = d.playerId == selected.id;
                        final free = d.playerId == null;
                        final owner = d.playerName ??
                            (free ? 'свободен' : 'игрок #${d.playerId}');
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Material(
                            color: assignedToSelected
                                ? _TD.greenSoft
                                : Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            child: _NoHoverTap(
                              borderRadius: BorderRadius.circular(6),
                              onTap: () async {
                                await _assignTrackerDeviceToPlayer(d, selected);
                                if (mounted) setModalState(() {});
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 9),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: assignedToSelected
                                          ? _TD.greenBorder
                                          : _TD.borderStrong),
                                ),
                                child: Row(children: [
                                  Icon(Icons.sensors_rounded,
                                      color: assignedToSelected
                                          ? _TD.green
                                          : _TD.graphite,
                                      size: 17),
                                  const SizedBox(width: 8),
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        Text(d.deviceName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                color: _TD.text,
                                                fontSize: 11.2,
                                                fontWeight: FontWeight.w700)),
                                        const SizedBox(height: 2),
                                        Text(
                                            '${d.isNearby ? 'в зоне BLE' : 'сохранён'} · $owner',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                color: _TD.muted,
                                                fontSize: 11.2,
                                                fontWeight: FontWeight.w700)),
                                      ])),
                                  Text(
                                      assignedToSelected
                                          ? 'назначен'
                                          : 'выбрать',
                                      style: TextStyle(
                                          color: assignedToSelected
                                              ? _TD.green
                                              : _TD.muted,
                                          fontSize: 11.2,
                                          fontWeight: FontWeight.w700)),
                                ]),
                              ),
                            ),
                          ),
                        );
                      }),
                    ]);
              }

              Widget heartDeviceList() {
                if (heartCandidates.isEmpty) {
                  return scanStateLine(
                      active: _scanningHeart,
                      count: 0,
                      emptyText:
                          'Список Polar/BLE пока пуст. Нажмите «Сканировать Polar» или «Все BLE рядом».');
                }
                return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      scanStateLine(
                          active: _scanningHeart,
                          count: heartCandidates.length,
                          emptyText: ''),
                      const SizedBox(height: 8),
                      ...heartCandidates.map((d) {
                        final ownerId = _heartDevicePlayerIds[d.id];
                        final ownerList = ownerId == null
                            ? const <TrackerPlayerOption>[]
                            : _players
                                .where((p) => p.id == ownerId)
                                .toList(growable: false);
                        final ownerName = ownerList.isEmpty
                            ? 'свободен'
                            : ownerList.first.name;
                        final assignedToSelected = ownerId == selected.id;
                        final connected = _heart.isConnected(d.id);
                        final sample = _heart.lastSampleForDevice(d.id);
                        final bpm =
                            sample == null ? 'bpm —' : '${sample.bpm} bpm';
                        final marker = d.serviceHit
                            ? 'Heart Rate'
                            : (d.rawProbe ? 'BLE-кандидат' : 'Polar');
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Material(
                            color: assignedToSelected
                                ? _TD.greenSoft
                                : Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            child: _NoHoverTap(
                              borderRadius: BorderRadius.circular(6),
                              onTap: () async {
                                await _connectAndAssignHeartRate(d, selected);
                                if (mounted) setModalState(() {});
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 9),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: assignedToSelected
                                          ? _TD.greenBorder
                                          : _TD.borderStrong),
                                ),
                                child: Row(children: [
                                  Icon(Icons.monitor_heart_rounded,
                                      color: assignedToSelected
                                          ? _TD.green
                                          : _TD.graphite,
                                      size: 17),
                                  const SizedBox(width: 8),
                                  Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                        Text(d.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                color: _TD.text,
                                                fontSize: 11.2,
                                                fontWeight: FontWeight.w700)),
                                        const SizedBox(height: 2),
                                        Text(
                                            '$marker · $bpm · RSSI ${d.rssi} · $ownerName',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                color: _TD.muted,
                                                fontSize: 11.2,
                                                fontWeight: FontWeight.w700)),
                                      ])),
                                  Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                            assignedToSelected
                                                ? 'назначен'
                                                : 'выбрать',
                                            style: TextStyle(
                                                color: assignedToSelected
                                                    ? _TD.green
                                                    : _TD.muted,
                                                fontSize: 11.2,
                                                fontWeight: FontWeight.w700)),
                                        const SizedBox(height: 2),
                                        Text(
                                            connected ? 'online' : 'подключить',
                                            style: TextStyle(
                                                color: connected
                                                    ? _TD.green
                                                    : _TD.dim,
                                                fontSize: 11.2,
                                                fontWeight: FontWeight.w700)),
                                      ]),
                                ]),
                              ),
                            ),
                          ),
                        );
                      }),
                    ]);
              }

              return ListView(
                padding: EdgeInsets.zero,
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                        color: _TD.greenSoft,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _TD.greenBorder)),
                    child: Row(children: [
                      _PlayerAvatarDark(
                          url: selected.avatar,
                          initials: _playerInitials(selected.name),
                          size: 42,
                          active: true),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(selected.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: _TD.text,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text(_equipmentStatusForPlayer(selected),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: _TD.muted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700)),
                          ])),
                    ]),
                  ),
                  const SizedBox(height: 8),
                  _EquipmentAssignmentBox(
                    icon: Icons.sensors_rounded,
                    title: 'GPS-трекер',
                    subtitle: assignedGps.isEmpty
                        ? 'можно оставить пустым: Live всё равно пойдёт по Polar'
                        : 'назначено: ${assignedGps.map((d) => d.deviceName).join(', ')}',
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DropdownButtonFormField<String?>(
                            value: gpsValue,
                            isExpanded: true,
                            decoration: _equipmentInput('Выбрать GPS-трекер'),
                            items: <DropdownMenuItem<String?>>[
                              const DropdownMenuItem<String?>(
                                  value: null, child: Text('Без GPS-трекера')),
                              ...gpsCandidates.map((d) {
                                final playerName = d.playerName ??
                                    (d.playerId == null
                                        ? 'свободен'
                                        : 'игрок #${d.playerId}');
                                return DropdownMenuItem<String?>(
                                  value: d.deviceUuid,
                                  child: Text('${d.deviceName} · $playerName',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                );
                              }),
                            ],
                            onChanged: (value) async {
                              if (value == null) {
                                for (final d in assignedGps) {
                                  await _assignTrackerDeviceToPlayer(d, null);
                                }
                              } else {
                                final device = gpsCandidates
                                    .firstWhere((d) => d.deviceUuid == value);
                                await _assignTrackerDeviceToPlayer(
                                    device, selected);
                              }
                              if (mounted) setModalState(() {});
                            },
                          ),
                          const SizedBox(height: 8),
                          Wrap(spacing: 6, runSpacing: 6, children: [
                            _DarkActionButton(
                              icon: Icons.tablet_android_rounded,
                              label: _scanning
                                  ? 'Идёт поиск...'
                                  : 'Сканировать GPS',
                              primary: gpsCandidates.isEmpty,
                              onTap: _scanning
                                  ? null
                                  : () async {
                                      setModalState(() {});
                                      await _scan(universalMode: true);
                                      if (mounted) setModalState(() {});
                                    },
                            ),
                          ]),
                          gpsDeviceList(),
                        ]),
                  ),
                  const SizedBox(height: 10),
                  _EquipmentAssignmentBox(
                    icon: Icons.monitor_heart_rounded,
                    title: 'Polar H10',
                    subtitle: assignedHeartId == null
                        ? 'можно назначить Polar без GPS-трекера'
                        : 'назначено: ${_heart.lastSampleForDevice(assignedHeartId)?.deviceName ?? _heart.connectedDevice(assignedHeartId)?.name ?? 'Polar H10'}',
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DropdownButtonFormField<String?>(
                            value: heartValue,
                            isExpanded: true,
                            decoration: _equipmentInput('Выбрать Polar H10'),
                            items: <DropdownMenuItem<String?>>[
                              const DropdownMenuItem<String?>(
                                  value: null, child: Text('Без Polar H10')),
                              ...heartCandidates.map((d) {
                                final ownerId = _heartDevicePlayerIds[d.id];
                                final owner = ownerId == null
                                    ? null
                                    : _players
                                        .where((p) => p.id == ownerId)
                                        .toList();
                                final ownerName = owner == null || owner.isEmpty
                                    ? 'свободен'
                                    : owner.first.name;
                                final sample = _heart.lastSampleForDevice(d.id);
                                final bpm = sample == null
                                    ? 'bpm —'
                                    : '${sample.bpm} bpm';
                                return DropdownMenuItem<String?>(
                                  value: d.id,
                                  child: Text('${d.name} · $bpm · $ownerName',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                );
                              }),
                            ],
                            onChanged: (value) async {
                              if (value == null) {
                                for (final entry in _heartDevicePlayerIds
                                    .entries
                                    .where((e) => e.value == selected.id)
                                    .toList()) {
                                  final dev =
                                      _heart.connectedDevice(entry.key) ??
                                          heartById[entry.key];
                                  if (dev != null)
                                    _bindHeartRateDeviceToPlayer(dev, null);
                                }
                              } else {
                                final device = heartCandidates
                                    .firstWhere((d) => d.id == value);
                                await _connectAndAssignHeartRate(
                                    device, selected);
                              }
                              if (mounted) setModalState(() {});
                            },
                          ),
                          const SizedBox(height: 8),
                          Wrap(spacing: 6, runSpacing: 6, children: [
                            _DarkActionButton(
                              icon: Icons.monitor_heart_rounded,
                              label: _scanningHeart
                                  ? 'Поиск Polar...'
                                  : 'Сканировать Polar',
                              primary: heartCandidates.isEmpty,
                              onTap: _scanningHeart
                                  ? null
                                  : () async {
                                      setModalState(() {});
                                      await _scanHeartRate();
                                      if (mounted) setModalState(() {});
                                    },
                            ),
                            _DarkActionButton(
                              icon: Icons.radar_rounded,
                              label: 'Все BLE рядом',
                              onTap: _scanningHeart
                                  ? null
                                  : () async {
                                      setModalState(() {});
                                      await _scanHeartRate(
                                          showAllBleCandidates: true);
                                      if (mounted) setModalState(() {});
                                    },
                            ),
                          ]),
                          heartDeviceList(),
                        ]),
                  ),
                  const SizedBox(height: 8),
                  const _DarkHint(
                      text:
                          'У игрока может быть GPS-трекер, Polar H10 или оба датчика одновременно. Live запускается по команде: у кого есть GPS — пишется трек/скорость, у кого есть Polar — пишется пульс.'),
                ],
              );
            }

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: EdgeInsets.symmetric(
                  horizontal: compact ? 8 : 24, vertical: compact ? 8 : 22),
              child: Container(
                constraints: BoxConstraints(
                    maxWidth: 1040,
                    maxHeight: compact
                        ? MediaQuery.of(dialogContext).size.height - 24
                        : 720),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(_TD.mobileInnerRadius),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withOpacity(.08),
                          blurRadius: 18,
                          offset: const Offset(0, 18))
                    ]),
                child: Column(children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 12, 12),
                    child: Row(children: [
                      Container(
                          width: 38,
                          height: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                              color: _TD.greenSoft,
                              borderRadius: BorderRadius.circular(6)),
                          child: const Icon(Icons.hub_rounded,
                              color: _TD.green, size: 21)),
                      const SizedBox(width: 8),
                      const Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text('Оборудование команды',
                                style: TextStyle(
                                    color: _TD.text,
                                    fontSize: 15.4,
                                    fontWeight: FontWeight.w700)),
                            SizedBox(height: 2),
                            Text('назначение GPS-трекеров и Polar H10 игрокам',
                                style: TextStyle(
                                    color: _TD.muted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700)),
                          ])),
                      _NoHoverTap(
                          onTap: () => Navigator.of(dialogContext).pop(),
                          child: const SizedBox(
                              width: 34,
                              height: 34,
                              child:
                                  Icon(Icons.close_rounded, color: _TD.muted))),
                    ]),
                  ),
                  const _WorkspacePaneDivider.horizontal(),
                  Expanded(
                    child: StreamBuilder<List<ActionTrackerDevice>>(
                      stream: _ble.devicesStream,
                      builder: (_, gpsSnapshot) {
                        final gpsDevices =
                            gpsSnapshot.data ?? const <ActionTrackerDevice>[];
                        return StreamBuilder<List<HeartRateBleDevice>>(
                          stream: _heart.devicesStream,
                          builder: (_, heartSnapshot) {
                            final heartDevices =
                                heartSnapshot.data ?? _heart.connectedInfos;
                            if (compact) {
                              return ListView(
                                padding: const EdgeInsets.all(8),
                                children: [
                                  SizedBox(height: 250, child: playersList()),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                      height: 430,
                                      child: assignmentPane(
                                          heartDevices, gpsDevices)),
                                ],
                              );
                            }
                            return Padding(
                              padding: const EdgeInsets.all(9),
                              child: Row(children: [
                                SizedBox(width: 330, child: playersList()),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: assignmentPane(
                                        heartDevices, gpsDevices)),
                              ]),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ]),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _bindSavedDevice(
      TrackerDeviceModel device, TrackerPlayerOption? player) async {
    try {
      await _api.registerOrBindDevice(
        clubId: widget.clubId,
        teamId: widget.teamId,
        playerId: player?.id,
        deviceUuid: device.deviceUuid,
        deviceName: device.deviceName,
        batteryPercent: device.batteryPercent,
      );
      if (!_isHeartRateDeviceModel(device)) {
        if (player == null) {
          _forgetConfirmedTeamBinding(device.deviceUuid, device.deviceName);
        } else {
          _rememberConfirmedTeamBinding(
            player: player,
            deviceUuid: device.deviceUuid,
            deviceName: device.deviceName,
            batteryPercent: device.batteryPercent,
          );
        }
      }
      if (mounted) {
        setState(() {
          _selectedPlayer = player;
          _connected = _ble.connectedInfo;
          _selectedRecord = null;
          _points.clear();
        });
      }
      _toast(
          'Датчик',
          player == null
              ? 'Привязка снята'
              : '${device.deviceName} → ${player.name}');
      await _loadServerData();
    } catch (e) {
      unawaited(_logRemote('Ошибка привязки датчика: $e',
          level: 'error', source: 'workspace_device_bind_error'));
      _toast('Датчик', '$e');
    }
  }

  Future<void> _forgetSavedDevice(TrackerDeviceModel device) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить серверную запись?'),
        content: Text(
          'Это удалит только запись привязки на сервере: ${device.deviceName} / ${device.deviceUuid}. '
          'BLE-канал приложения и память самого GPS-трекера не меняются.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Отмена')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Удалить')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final result = await _api.forgetServerDevice(
        teamId: widget.teamId,
        deviceId: device.id,
        deviceUuid: device.deviceUuid,
        deviceName: device.deviceName,
      );
      final deleted =
          int.tryParse('${result['deleted'] ?? result['affected'] ?? 0}') ?? 0;
      _toast(
          'Серверная запись',
          deleted > 0
              ? 'Удалено записей: $deleted'
              : 'Запись очищена или уже отсутствовала');
      unawaited(_logRemote(
        'Удалена серверная запись датчика: ${device.deviceName} / ${device.deviceUuid} · deleted=$deleted',
        source: 'workspace_device_server_forget',
      ));
      await _loadServerData();
    } catch (e) {
      _toast('Удаление привязки', '$e');
      unawaited(_logRemote('Ошибка удаления серверной записи датчика: $e',
          level: 'error', source: 'workspace_device_server_forget_error'));
    }
  }

  Future<void> _requestGpsRecordsFromTracker() async {
    try {
      await TrackerPermissions.ensureBlePermissions();
      if (!_ble.commandChannelReady) {
        _toast('GPS-записи',
            'Сначала подключите трекер: нужен реальный TX/RX канал');
        unawaited(_logRemote(
          'Запрос GPS-записей отменён: BLE TX/RX не готов',
          level: 'warning',
          source: 'workspace_offline_records_blocked',
        ));
        return;
      }
      setState(() =>
          _trackerRecordingStatus = 'запрашиваю список записей с трекера');
      await _ble.requestRecordList();
      unawaited(_logRemote('Запрос GPS-записей с трекера отправлен',
          source: 'workspace_offline_records_request'));
      _toast('GPS-записи',
          'Запрос отправлен. Список записей появится после ответа датчика.');
    } catch (e) {
      unawaited(_logRemote('Ошибка загрузки GPS-записей с трекера: $e',
          level: 'error', source: 'workspace_offline_records_error'));
      _toast('GPS-записи', '$e');
    }
  }

  String _formatTrackerRecordingStatus(List<ActionTrackerRecord> records) {
    if (records.isEmpty) return 'на датчике нет записей';
    final recording = records
        .where((r) => r.state == ActionTrackerRecordState.recording)
        .toList();
    if (recording.isNotEmpty) {
      final r = recording.first;
      return 'идёт запись на трекере · file ${r.fileId} · ${r.length} байт';
    }
    final finished = records
        .where(
            (r) => r.state == ActionTrackerRecordState.finished || r.length > 0)
        .toList()
      ..sort((a, b) {
        final byEnd = b.endTimeMs.compareTo(a.endTimeMs);
        if (byEnd != 0) return byEnd;
        return b.fileId.compareTo(a.fileId);
      });
    if (finished.isNotEmpty) {
      final r = finished.first;
      return 'есть готовая запись · file ${r.fileId} · ${r.length} байт';
    }
    return 'запись на трекере не идёт';
  }

  String _offlineRecordKey(
      ActionTrackerDevice device, ActionTrackerRecord record) {
    return '${device.id}:${record.fileId}:${record.length}:${record.startDateRaw}:${record.startTimeMs}';
  }

  TrackerPlayerOption? _playerForConnectedTracker() {
    final id = (_connected ?? _ble.connectedInfo ?? _ble.lastKnownInfo)?.id;
    if (id == null || id.trim().isEmpty) return _selectedPlayer;
    final exact = _savedDevices
        .where((d) => d.deviceUuid == id && (d.playerId ?? 0) > 0)
        .toList();
    if (exact.isEmpty) return _selectedPlayer;
    final playerId = exact.first.playerId;
    if (playerId == null || playerId <= 0) return _selectedPlayer;
    final players = _players.where((p) => p.id == playerId).toList();
    return players.isEmpty ? _selectedPlayer : players.first;
  }

  Future<void> _autoSyncLatestFinishedRecordIfNeeded() async {
    if (!mounted ||
        _offlineAutoSyncInProgress ||
        _savingRecord ||
        !_ble.commandChannelReady) return;
    final connected = _connected ?? _ble.connectedInfo;
    if (connected == null) return;
    final finished = _records
        .where((r) =>
            (r.state == ActionTrackerRecordState.finished || r.length > 0) &&
            r.state != ActionTrackerRecordState.recording)
        .toList()
      ..sort((a, b) {
        final byEnd = b.endTimeMs.compareTo(a.endTimeMs);
        if (byEnd != 0) return byEnd;
        return b.fileId.compareTo(a.fileId);
      });
    if (finished.isEmpty) return;
    final record = finished.first;
    final key = _offlineRecordKey(connected, record);
    if (_offlineAutoSyncedRecordKeys.contains(key)) return;

    _offlineAutoSyncInProgress = true;
    _offlineAutoSyncKey = key;
    _trackerRecordingStatus =
        'автовыгрузка: загружаю file ${record.fileId} с трекера';
    if (mounted) setState(() {});
    unawaited(_logRemote(
      'Автовыгрузка офлайн-записи: ${connected.name} / ${connected.id} · file=${record.fileId} · points_buffer=${_points.length}',
      source: 'workspace_offline_auto_sync_start',
    ));
    await _loadGpsRecord(record, autoSave: true);
  }

  Future<void> _finishOfflineAutoSyncAfterTransfer() async {
    if (!_offlineAutoSaveAfterTransfer || !_offlineAutoSyncInProgress) return;
    if (_selectedRecord == null || _points.length < 2) {
      _trackerRecordingStatus =
          'запись загружена, но точек мало для сохранения';
      _offlineAutoSyncInProgress = false;
      _offlineAutoSaveAfterTransfer = false;
      _offlineAutoSyncKey = null;
      if (mounted) setState(() {});
      return;
    }
    _trackerRecordingStatus = 'сохраняю офлайн-запись на сервер';
    if (mounted) setState(() {});
    await _saveRecordAsSession(auto: true);
    if (mounted) {
      setState(() {
        _trackerRecordingStatus =
            'офлайн-запись выгружена на сервер и попала в сессии';
      });
    }
  }

  Future<void> _loadGpsRecord(ActionTrackerRecord record,
      {bool autoSave = false}) async {
    setState(() {
      _selectedRecord = record;
      _points.clear();
      _offlineAutoSaveAfterTransfer = autoSave;
    });
    try {
      await _ble.requestGpsRecord(record);
      _toast(
          'GPS',
          autoSave
              ? 'Автовыгрузка записи началась'
              : 'Загрузка записи началась');
    } catch (e) {
      _offlineAutoSaveAfterTransfer = false;
      _offlineAutoSyncInProgress = false;
      _offlineAutoSyncKey = null;
      unawaited(_logRemote('Ошибка загрузки GPS-записи: $e',
          level: 'error', source: 'workspace_gps_record_error'));
      _toast('GPS', '$e');
    }
  }

  Future<void> _saveRecordAsSession({bool auto = false}) async {
    final connected = _connected ?? _ble.connectedInfo;
    final record = _selectedRecord;
    final player = _playerForConnectedTracker() ?? _selectedPlayer;
    if (connected == null || record == null || _points.length < 2) {
      _toast('Сессия',
          'Нужно подключить трекер, выбрать запись и иметь GPS-точки');
      return;
    }
    setState(() => _savingRecord = true);
    try {
      final result = await _api.saveGpsSession(
        clubId: widget.clubId,
        teamId: widget.teamId,
        playerId: player?.id,
        deviceUuid: connected.id,
        deviceName: connected.name,
        fieldId: _selectedField?.id,
        record: record,
        points: _points,
      );
      final sessionId = int.tryParse(
              '${result['session_id'] ?? result['existing_session_id'] ?? 0}') ??
          0;
      if (sessionId > 0 && result['already_exists'] != true) {
        try {
          await _api.processSession(sessionId: sessionId);
        } catch (_) {}
      }
      if (auto && _offlineAutoSyncKey != null)
        _offlineAutoSyncedRecordKeys.add(_offlineAutoSyncKey!);
      _toast(
          'Сессия',
          result['already_exists'] == true
              ? 'Запись уже была на сервере'
              : 'Запись сохранена');
      await _loadServerData();
    } catch (e) {
      unawaited(_logRemote('Ошибка сохранения GPS-сессии: $e',
          level: 'error', source: 'workspace_session_save_error'));
      _toast('Сессия', '$e');
    } finally {
      if (auto) {
        _offlineAutoSyncInProgress = false;
        _offlineAutoSaveAfterTransfer = false;
        _offlineAutoSyncKey = null;
      }
      if (mounted) setState(() => _savingRecord = false);
    }
  }

  void _createNewFieldDraft() {
    final index = _fields.length + 1;
    setState(() {
      _selectedField = TrackerFieldModel(
        clubId: widget.clubId,
        teamId: widget.teamId,
        title: index <= 1 ? 'Основное поле' : 'Поле $index',
        lengthM: 105,
        widthM: 68,
        isDefault: true,
      );
      _calibrationCorners.clear();
    });
    _toast('Поле',
        'Создано новое поле. Пройдите углы A → B → C → D и нажмите «Сохранить».');
  }

  void _resetCalibrationCorners() {
    setState(() => _calibrationCorners.clear());
    _toast('Калибровка', 'Точки A/B/C/D сброшены.');
  }

  Future<void> _handleCornerTap(int index) async {
    if (index != _calibrationCorners.length) {
      final labels = const ['A', 'B', 'C', 'D'];
      _toast('Калибровка',
          'Сейчас нужна точка ${labels[_calibrationCorners.length.clamp(0, 3)]}. Идите по порядку A → B → C → D.');
      return;
    }
    await _captureCalibrationPoint();
  }

  Future<void> _captureCalibrationPoint() async {
    final labels = const ['A', 'B', 'C', 'D'];
    if (_calibrationCapturing) return;

    if (_calibrationCorners.length >= 4) {
      _toast('Калибровка',
          'Все 4 точки уже получены. Нажмите «Сохранить» или «Сбросить».');
      return;
    }

    final nextIndex = _calibrationCorners.length;

    setState(() {
      _calibrationCapturing = true;
      _calibrationCapturingIndex = nextIndex;
    });

    try {
      final point = await _waitForFreshCalibrationPoint(nextIndex);
      if (point == null) {
        _toast('Калибровка',
            'Трекер не дал свежую GPS-точку. Проверьте GPS/улицу и нажмите ещё раз.');
        await _logRemote(
          'Калибровка: нет свежей GPS-точки для ${labels[nextIndex]} · RX=$_lastWorkspaceRx · lastGPS=$_lastWorkspaceGps',
          level: 'warning',
          source: 'workspace_calibration_no_fresh_gps',
        );
        return;
      }

      final duplicateIndex = _tooCloseCalibrationCornerIndex(point);
      if (duplicateIndex != null) {
        final distance =
            _distanceMeters(_calibrationCorners[duplicateIndex], point);
        _toast(
          'Калибровка',
          'Координата почти такая же, как точка ${labels[duplicateIndex]} (${distance.toStringAsFixed(1)} м). Отойдите к следующему углу и дождитесь нового GPS.',
        );
        await _logRemote(
          'Калибровка: дубль угла ${labels[nextIndex]} ≈ ${labels[duplicateIndex]} · distance=${distance.toStringAsFixed(1)}m · lat=${point.latitude}, lng=${point.longitude}',
          level: 'warning',
          source: 'workspace_calibration_duplicate_point',
          rawHex: _lastWorkspaceRx == 'нет пакетов' ? null : _lastWorkspaceRx,
        );
        return;
      }

      setState(() {
        _calibrationCorners.add(point);
      });

      _showCalibrationFlash(labels[nextIndex]);
      await _logRemote(
        'Калибровка: точка ${labels[nextIndex]} сохранена (${_calibrationCorners.length}/4) · ${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}',
        source: 'workspace_calibration_point_saved',
        rawHex: _lastWorkspaceRx == 'нет пакетов' ? null : _lastWorkspaceRx,
      );

      _toast(
        'Калибровка',
        'Точка ${labels[nextIndex]} сохранена (${_calibrationCorners.length}/4).',
      );
    } finally {
      if (mounted) {
        setState(() {
          _calibrationCapturing = false;
          _calibrationCapturingIndex = null;
        });
      }
    }
  }

  Future<void> _saveCapturedField() async {
    if (_calibrationCorners.length < 4) {
      _toast('Калибровка', 'Нужно 4 угла поля');
      return;
    }
    final field = TrackerFieldModel(
      id: _selectedField?.id,
      clubId: widget.clubId,
      teamId: widget.teamId,
      title: _selectedField?.title ?? 'Основное поле',
      lengthM: _selectedField?.lengthM ?? 105,
      widthM: _selectedField?.widthM ?? 68,
      cornerALat: _calibrationCorners[0].latitude,
      cornerALng: _calibrationCorners[0].longitude,
      cornerBLat: _calibrationCorners[1].latitude,
      cornerBLng: _calibrationCorners[1].longitude,
      cornerCLat: _calibrationCorners[2].latitude,
      cornerCLng: _calibrationCorners[2].longitude,
      cornerDLat: _calibrationCorners[3].latitude,
      cornerDLng: _calibrationCorners[3].longitude,
      isDefault: true,
    );
    try {
      final response = await _api.saveField(
          clubId: widget.clubId, teamId: widget.teamId, field: field);
      final responseData = response['data'];
      final responseFieldId = responseData is Map ? responseData['id'] : null;
      final savedId = int.tryParse(
          '${response['field_id'] ?? response['id'] ?? responseFieldId ?? field.id ?? ''}');
      final optimisticField = TrackerFieldModel(
        id: savedId ?? field.id,
        clubId: field.clubId,
        teamId: field.teamId,
        title: field.title,
        lengthM: field.lengthM,
        widthM: field.widthM,
        cornerALat: field.cornerALat,
        cornerALng: field.cornerALng,
        cornerBLat: field.cornerBLat,
        cornerBLng: field.cornerBLng,
        cornerCLat: field.cornerCLat,
        cornerCLng: field.cornerCLng,
        cornerDLat: field.cornerDLat,
        cornerDLng: field.cornerDLng,
        isDefault: field.isDefault,
      );

      setState(() {
        _calibrationCorners.clear();
        _selectedField = optimisticField;
        final sameIndex = _fields.indexWhere((f) =>
            (optimisticField.id != null && f.id == optimisticField.id) ||
            f.title == optimisticField.title);
        if (sameIndex >= 0) {
          _fields[sameIndex] = optimisticField;
        } else {
          _fields.insert(0, optimisticField);
        }
      });

      _toast('Поле', 'Калибровка сохранена');
      await _logRemote(
        'Поле сохранено: id=${optimisticField.id ?? 'new'} title=${optimisticField.title} · A=${optimisticField.cornerALat?.toStringAsFixed(6)},${optimisticField.cornerALng?.toStringAsFixed(6)} · B=${optimisticField.cornerBLat?.toStringAsFixed(6)},${optimisticField.cornerBLng?.toStringAsFixed(6)} · C=${optimisticField.cornerCLat?.toStringAsFixed(6)},${optimisticField.cornerCLng?.toStringAsFixed(6)} · D=${optimisticField.cornerDLat?.toStringAsFixed(6)},${optimisticField.cornerDLng?.toStringAsFixed(6)} · response=$response',
        source: 'workspace_field_saved',
      );
      await _loadServerData();

      if (mounted &&
          (_selectedField == null || _selectedField?.hasCalibration != true)) {
        setState(() {
          _selectedField = optimisticField;
          if (!_fields.any((f) =>
              (optimisticField.id != null && f.id == optimisticField.id) ||
              f.title == optimisticField.title)) {
            _fields.insert(0, optimisticField);
          }
        });
      }
    } catch (e) {
      await _logRemote('Ошибка сохранения поля: $e',
          level: 'error', source: 'workspace_field_save_error');
      _toast('Поле', '$e');
    }
  }

  Future<void> _saveSettingsPreset(TrackerSpeedSettings settings) async {
    try {
      await _api.saveSettings(teamId: widget.teamId, settings: settings);
      _toast('Настройки',
          'Профиль ${_settingsPresetTitle(settings.preset)} сохранён');
      unawaited(_logRemote(
          'Пороги трекера сохранены: preset=${settings.preset}',
          source: 'workspace_settings_saved',
          extra: settings.toJson()));
      setState(() {});
    } catch (e) {
      unawaited(_logRemote('Ошибка сохранения порогов: $e',
          level: 'error',
          source: 'workspace_settings_save_error',
          extra: settings.toJson()));
      _toast('Настройки', '$e');
    }
  }

  String _settingsPresetTitle(String preset) {
    switch (TrackerSpeedSettings.normalizePreset(preset)) {
      case 'u13':
        return 'U13 / Академия';
      case 'u17':
        return 'U17 / Полупрофи';
      case 'pro':
        return 'Профи / Элита';
      case 'custom':
        return 'Свой';
      default:
        return 'Юношеский';
    }
  }

  Future<bool> _confirmExitTrackerIfNeeded() async {
    if (!_liveRunning) return true;

    final action = await showDialog<_TrackerExitAction>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          title: const Text(
            'Live-сессия активна',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          content: const Text(
            'Идёт Live-сессия трекера. Чтобы не потерять GPS/BLE точки и данные по нагрузке, выберите действие перед выходом.',
            style: TextStyle(height: 1.35, fontWeight: FontWeight.w500),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(_TrackerExitAction.stay),
              child: const Text('Остаться'),
            ),
            TextButton.icon(
              onPressed: () => Navigator.of(context)
                  .pop(_TrackerExitAction.pauseAndMinimize),
              icon: const Icon(Icons.pause_circle_outline_rounded, size: 17),
              label: const Text('Приостановить'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context)
                  .pop(_TrackerExitAction.exitWithoutSaving),
              child: const Text('Выйти без сохранения'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: _TD.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
              ),
              onPressed: _activeLiveSessionId == null
                  ? null
                  : () =>
                      Navigator.of(context).pop(_TrackerExitAction.saveAndExit),
              icon: const Icon(Icons.save_rounded, size: 16),
              label: const Text('Сохранить и выйти'),
            ),
          ],
        );
      },
    );

    if (action == null || action == _TrackerExitAction.stay) return false;

    if (action == _TrackerExitAction.pauseAndMinimize) {
      if (mounted) {
        setState(() {
          _livePauseRequestSignal++;
          _trackerWindowMinimized = true;
        });
      }
      _toast('Live',
          'Сессия приостановлена. Окно трекера свернуто, данные не удалены.');
      return false;
    }

    if (action == _TrackerExitAction.exitWithoutSaving) {
      try {
        if (_teamLiveCoordinator.running) {
          await _teamLiveCoordinator.stop(createFinalSession: false);
        } else {
          final id = _activeLiveSessionId;
          if (id != null)
            await _liveApi.stopLiveSession(
                liveSessionId: id, createFinalSession: false);
        }
      } catch (e) {
        _toast('Сессия', 'Не удалось закрыть Live без сохранения: $e');
        return false;
      }
      if (mounted) {
        setState(() {
          _liveRunning = false;
          _activeLiveSessionId = null;
          _liveExitWithoutSaveRequestSignal++;
        });
      }
      _toast('Сессия', 'Live закрыт без создания финальной сессии');
      return true;
    }

    if (action == _TrackerExitAction.saveAndExit) {
      try {
        if (_teamLiveCoordinator.running) {
          await _teamLiveCoordinator.stop(createFinalSession: true);
        } else {
          final id = _activeLiveSessionId;
          if (id != null)
            await _liveApi.stopLiveSession(
                liveSessionId: id, createFinalSession: true);
        }
        if (mounted) {
          setState(() {
            _liveRunning = false;
            _activeLiveSessionId = null;
            _liveStopRequestSignal++;
          });
        }
        _toast('Сессия', 'Live остановлен и сохранён');
      } catch (e) {
        _toast('Сессия', 'Не удалось сохранить перед выходом: $e');
        return false;
      }
      return true;
    }

    return false;
  }

  int _eventInt(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key];
      final parsed =
          value is num ? value.toInt() : int.tryParse('${value ?? ''}');
      if (parsed != null && parsed > 0) return parsed;
    }
    return 0;
  }

  DateTime? _eventDate(Map<String, dynamic> row) {
    for (final key in const [
      'started_at',
      'ended_at',
      'stopped_at',
      'created_at',
      'event_at'
    ]) {
      final raw = '${row[key] ?? ''}'.trim();
      if (raw.isEmpty) continue;
      final parsed = _trackerMoscowDateTime(raw);
      if (parsed != null) return parsed;
    }
    return null;
  }

  Future<void> _openAnalyticsArchive({
    PlayerTrainingCalendarMode mode = PlayerTrainingCalendarMode.team,
    Map<String, dynamic>? event,
  }) async {
    if (!mounted) return;
    final playerId = event == null
        ? 0
        : _eventInt(
            event, const ['player_id', 'tracker_player_id', 'owner_player_id']);
    final sessionId = event == null
        ? 0
        : _eventInt(event, const [
            'session_id',
            'final_session_id',
            'tracker_session_id',
            'live_session_id'
          ]);

    TrackerPlayerOption? targetPlayer;
    if (playerId > 0) {
      for (final player in _players) {
        if (player.id == playerId) {
          targetPlayer = player;
          break;
        }
      }
    }

    TrackerSessionModel? targetSession;
    if (sessionId > 0) {
      try {
        final sessions = await _api.loadSessions(
          teamId: widget.teamId,
          playerId: playerId > 0 ? playerId : null,
          limit: 100,
          sessionKind:
              mode == PlayerTrainingCalendarMode.personal ? 'personal' : 'all',
        );
        for (final session in sessions) {
          if (session.id == sessionId) {
            targetSession = session;
            break;
          }
        }
      } catch (_) {
        // Аналитика всё равно откроется по игроку, даже если список сессий временно не загрузился.
      }
    }

    if (!mounted) return;
    setState(() {
      if (targetPlayer != null) _selectedPlayer = targetPlayer;
      if (targetSession != null) _selectedReportSession = targetSession;
      _section = TrackerWorkspaceSection.analytics;
      _analyticsInitialTab = 0;
      _analyticsInitialTabSignal++;
      _analyticsInitialCalendarMode = mode;
      _analyticsInitialCalendarModeSignal++;
    });

    if (event != null) {
      final dt = _eventDate(event);
      _toast(
        'Личная тренировка',
        playerId > 0
            ? 'Игрок выбран автоматически${sessionId > 0 ? ' · сессия #$sessionId' : ''}${dt != null ? ' · ${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}' : ''}'
            : 'Открываю аналитику личной тренировки',
      );
    }
  }

  Future<void> _selectSectionSafely(TrackerWorkspaceSection section) async {
    if (!mounted) return;
    if (section == _section) return;

    if (_liveRunning &&
        _section == TrackerWorkspaceSection.live &&
        section != TrackerWorkspaceSection.live) {
      final action = await showDialog<_TrackerLiveSwitchAction>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            title: const Text('Live-сессия продолжает идти',
                style: TextStyle(fontWeight: FontWeight.w700)),
            content: const Text(
              'Можно перейти в другой раздел, а Live оставить активным. Чтобы завершить тренировку полностью, нажмите «Сохранить и перейти».',
              style: TextStyle(height: 1.35, fontWeight: FontWeight.w600),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context)
                    .pop(_TrackerLiveSwitchAction.stayInLive),
                child: const Text('Остаться в Live'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context)
                    .pop(_TrackerLiveSwitchAction.keepRunning),
                child: const Text('Перейти, Live оставить'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _TD.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: _activeLiveSessionId == null
                    ? null
                    : () => Navigator.of(context)
                        .pop(_TrackerLiveSwitchAction.saveAndSwitch),
                icon: const Icon(Icons.save_rounded, size: 16),
                label: const Text('Сохранить и перейти'),
              ),
            ],
          );
        },
      );

      if (action == null || action == _TrackerLiveSwitchAction.stayInLive)
        return;

      if (action == _TrackerLiveSwitchAction.saveAndSwitch) {
        try {
          if (_teamLiveCoordinator.running) {
            await _teamLiveCoordinator.stop(createFinalSession: true);
          } else {
            final id = _activeLiveSessionId;
            if (id != null)
              await _liveApi.stopLiveSession(
                  liveSessionId: id, createFinalSession: true);
          }
          if (!mounted) return;
          setState(() {
            _liveRunning = false;
            _activeLiveSessionId = null;
            _liveStopRequestSignal++;
          });
          _toast('Сессия', 'Live остановлен и сохранён');
        } catch (e) {
          _toast('Сессия', 'Не удалось сохранить перед переходом: $e');
          return;
        }
      }
    }

    if (!mounted) return;
    setState(() => _section = section);
    // В мобильной версии PageView больше не используется: показываем только активный раздел.
    if (section == TrackerWorkspaceSection.debug) {
      unawaited(_loadRemoteDebugLogs());
    }
  }

  void _selectSectionForMobile(TrackerWorkspaceSection section) {
    if (!mounted) return;
    if (section == _section) return;
    // Нельзя менять layout синхронно внутри pointer/mouse update.
    // Откладываем переключение на следующий кадр и больше не двигаем PageView:
    // именно animateToPage/PageView давали mouse_tracker.dart assertion на мобильном.
    Timer(const Duration(milliseconds: 80), () {
      if (!mounted || section == _section) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || section == _section) return;
        setState(() => _section = section);
        if (section == TrackerWorkspaceSection.debug) {
          unawaited(_loadRemoteDebugLogs());
        }
      });
    });
  }

  void _openTrackerSection(TrackerWorkspaceSection section) {
    final width = MediaQuery.maybeOf(context)?.size.width ?? 1200;
    if (widget.embeddedInClubWorkspace && width < 720) {
      _selectSectionForMobile(section);
      return;
    }
    if (!mounted) return;
    setState(() => _section = section);
    if (section == TrackerWorkspaceSection.debug) {
      unawaited(_loadRemoteDebugLogs());
    }
  }

  Future<void> _handleBackPressed() async {
    final canClose = await _confirmExitTrackerIfNeeded();
    if (!mounted || !canClose) return;
    Navigator.of(context).maybePop();
  }

  Future<void> _closeTrackerWindowSafely() async {
    final canClose = await _confirmExitTrackerIfNeeded();
    if (!mounted || !canClose) return;

    if (widget.embeddedInClubWorkspace) {
      setState(() => _trackerWindowMinimized = true);
      return;
    }
    Navigator.of(context).maybePop();
  }

  void _toast(String title, String message) {
    if (!mounted) return;
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.white,
      colorText: _TD.text,
      borderColor: _TD.softLine,
      borderWidth: 1,
      icon: Icon(
        title.toLowerCase().contains('bluetooth')
            ? Icons.bluetooth_disabled_rounded
            : Icons.info_outline_rounded,
        color: _TD.graphiteSoft,
        size: 18,
      ),
      margin: const EdgeInsets.all(9),
      duration: const Duration(seconds: 4),
    );
  }

  bool _trackerContextAiSupported(TrackerWorkspaceSection section) {
    return widget.clubId > 0 &&
        widget.userId > 0 &&
        section != TrackerWorkspaceSection.devices &&
        section != TrackerWorkspaceSection.field &&
        section != TrackerWorkspaceSection.settings &&
        section != TrackerWorkspaceSection.debug;
  }

  String _trackerContextAiTitle(TrackerWorkspaceSection section) {
    return switch (section) {
      TrackerWorkspaceSection.dashboard => 'Сводка Tracker Pro',
      TrackerWorkspaceSection.live => 'Live Coach',
      TrackerWorkspaceSection.analytics => 'ИИ-анализ тренировки',
      TrackerWorkspaceSection.activity => 'Динамика игрока',
      TrackerWorkspaceSection.sessions => 'Завершённые сессии',
      TrackerWorkspaceSection.personal => 'Личные тренировки',
      TrackerWorkspaceSection.devices => 'Устройства',
      TrackerWorkspaceSection.field => 'Поле',
      TrackerWorkspaceSection.settings => 'Настройки',
      TrackerWorkspaceSection.debug => 'Диагностика',
    };
  }

  List<int> _contextIntList(dynamic value) {
    if (value is! Iterable) return const <int>[];
    final result = <int>{};
    for (final item in value) {
      final id = int.tryParse('${item ?? ''}') ?? 0;
      if (id > 0) result.add(id);
    }
    final sorted = result.toList()..sort();
    return sorted;
  }

  List<String> _contextStringList(dynamic value) {
    if (value is! Iterable) return const <String>[];
    final result = <String>[];
    for (final item in value) {
      final text = '${item ?? ''}'.trim();
      if (text.isEmpty || result.contains(text)) continue;
      result.add(text);
    }
    return result;
  }

  String? _trackerAiFocusedPlayerName(TrackerWorkspaceSection section) {
    if (section == TrackerWorkspaceSection.analytics) {
      final mode = '${_trackerAnalyticsAiContext['selection_mode'] ?? ''}';
      if (mode != 'single_player') return null;
      final direct =
          '${_trackerAnalyticsAiContext['player_name'] ?? ''}'.trim();
      if (direct.isNotEmpty) return direct;
      final names = _contextStringList(
        _trackerAnalyticsAiContext['player_names'],
      );
      return names.length == 1 ? names.first : null;
    }
    final name = _selectedPlayer?.name.trim() ?? '';
    return name.isEmpty ? null : name;
  }

  String _trackerContextAiPrompt(TrackerWorkspaceSection section) {
    final playerName = _trackerAiFocusedPlayerName(section);
    final analyticsPlayerIds = section == TrackerWorkspaceSection.analytics
        ? _contextIntList(_trackerAnalyticsAiContext['player_ids'])
        : const <int>[];
    final analyticsMode = section == TrackerWorkspaceSection.analytics
        ? '${_trackerAnalyticsAiContext['selection_mode'] ?? ''}'
        : '';
    final playerScope = analyticsMode == 'players' &&
            analyticsPlayerIds.length > 1
        ? '${analyticsPlayerIds.length} выбранных игроков команды «${widget.teamName}»'
        : playerName == null || playerName.isEmpty
            ? 'команды «${widget.teamName}»'
            : 'игрока $playerName';
    switch (section) {
      case TrackerWorkspaceSection.dashboard:
        return 'Сделай оперативную ИИ-сводку Tracker Pro для $playerScope. '
            'Покажи готовность данных, главные сигналы нагрузки, риски и три действия тренеру. Используй только проверенные GPS/Polar-сессии.';
      case TrackerWorkspaceSection.live:
        return 'Работай как Live Coach для $playerScope. Проанализируй текущий Live-контекст: подключение трекеров, GPS, Polar H10, пульс и нагрузку. '
            'Дай коротко: «Сигнал», «Почему» и «Действие сейчас». Не выдумывай отсутствующие онлайн-данные.';
      case TrackerWorkspaceSection.analytics:
        return 'Проанализируй выбранную тренировку $playerScope как единый контекст. '
            'Сопоставь дистанцию, скорость, спринты, ускорения/торможения и пульс. Покажи «Что происходит», «Почему» и «Что делать на следующей тренировке».';
      case TrackerWorkspaceSection.activity:
        return 'Покажи динамику активности $playerScope по последним проверенным тренировкам: нагрузка, скорость, спринты, пульс, восстановление и отклонения. Дай персональную рекомендацию тренеру.';
      case TrackerWorkspaceSection.sessions:
        return 'Проанализируй завершённые сессии $playerScope. Найди последнюю релевантную тренировку, сравни её с предыдущими и предложи, что сохранить в отчёт и заметку тренера.';
      case TrackerWorkspaceSection.personal:
        return 'Проанализируй личные тренировки игроков команды «${widget.teamName}»: кто тренируется, у кого есть риск перегрузки или недостаточно данных и кому требуется внимание тренера.';
      default:
        return 'Проанализируй текущий контекст Tracker Pro для $playerScope. Используй только проверенные данные и дай конкретные рекомендации тренеру.';
    }
  }

  Map<String, dynamic> _trackerContextAiPayload(
    TrackerWorkspaceSection section,
  ) {
    final analytics = section == TrackerWorkspaceSection.analytics;
    return <String, dynamic>{
      'source': 'tracker_context_layer',
      'workspace_section': section.name,
      'club_id': widget.clubId,
      'team_id': widget.teamId,
      'team_name': widget.teamName,
      if (!analytics && (_selectedPlayer?.id ?? 0) > 0)
        'player_id': _selectedPlayer!.id,
      if (!analytics && (_selectedPlayer?.name.trim() ?? '').isNotEmpty)
        'player_name': _selectedPlayer!.name.trim(),
      if (!analytics && (_selectedReportSession?.id ?? 0) > 0)
        'session_id': _selectedReportSession!.id,
      if (analytics) ..._trackerAnalyticsAiContext,
      if (analytics && _trackerAnalyticsAiContext.isEmpty)
        'selection_mode': 'team',
      'live_context': <String, dynamic>{
        'running': _liveRunning,
        if ((_activeLiveSessionId ?? 0) > 0) 'session_id': _activeLiveSessionId,
        'gps_command_channel_ready': _hasAnyGpsCommandChannel,
        'connected_gps_trackers': _teamBlePool.connectedCount,
        'connected_heart_rate_sensors': _heart.connectedCount,
        'gps_points_in_memory': _points.length,
        'players_with_current_hr': _latestHeartByPlayerId.length,
      },
      'response_contract': const <String>[
        'what_happens',
        'why',
        'coach_action',
      ],
    };
  }

  void _handleTrackerAnalyticsAiContextChanged(
    Map<String, dynamic> payload,
  ) {
    if (!mounted) return;
    final next = Map<String, dynamic>.from(payload);
    final playerIds = _contextIntList(next['player_ids']);
    final directPlayerId = int.tryParse('${next['player_id'] ?? 0}') ?? 0;
    final mode = '${next['selection_mode'] ?? ''}';
    final focusedId = mode == 'single_player'
        ? (directPlayerId > 0
            ? directPlayerId
            : (playerIds.length == 1 ? playerIds.first : 0))
        : 0;
    final focusedPlayers = focusedId <= 0
        ? const <TrackerPlayerOption>[]
        : _players
            .where((player) => player.id == focusedId)
            .toList(growable: false);

    setState(() {
      _trackerAnalyticsAiContext = next;
      if (focusedPlayers.isNotEmpty) {
        _selectedPlayer = focusedPlayers.first;
      }
      if (_contextAiOverrideSection == TrackerWorkspaceSection.analytics) {
        _contextAiPromptOverride = null;
        _contextAiPayloadOverride = null;
        _contextAiOverrideSection = null;
      }
      _contextAiRevision++;
    });
  }

  void _openTrackerContextAi({
    required String prompt,
    required Map<String, dynamic> payload,
  }) {
    if (!mounted) return;
    setState(() {
      _contextAiExpanded = true;
      _contextAiPromptOverride = prompt;
      _contextAiPayloadOverride = Map<String, dynamic>.from(payload);
      _contextAiOverrideSection = _section;
      _contextAiRevision++;
    });
  }

  void _handleTrackerAiNavigate(
    String target,
    Map<String, dynamic> payload,
  ) {
    final normalized = target.trim().toLowerCase();
    final next = switch (normalized) {
      'tracker' ||
      'analytics' ||
      'training' =>
        TrackerWorkspaceSection.analytics,
      'session' || 'report' || 'reports' => TrackerWorkspaceSection.sessions,
      'player' || 'player_profile' => TrackerWorkspaceSection.activity,
      _ => null,
    };
    if (next == null) {
      _toast('СПОРТОТЕКА ИИ', 'Переход «$target» доступен в Club Workspace.');
      return;
    }

    final playerId =
        int.tryParse('${payload['player_id'] ?? payload['id'] ?? 0}') ?? 0;
    final player =
        _players.where((item) => item.id == playerId).toList(growable: false);
    setState(() {
      if (player.isNotEmpty) _selectedPlayer = player.first;
      _section = next;
    });
  }

  Widget _withTrackerContextAiLayer(
    Widget child, {
    double bottomInset = 10,
  }) {
    final section = _section;
    if (!_trackerContextAiSupported(section)) return child;

    final expanded = _contextAiExpanded ?? false;
    final useOverride = _contextAiOverrideSection == section &&
        (_contextAiPromptOverride ?? '').trim().isNotEmpty;
    final prompt = useOverride
        ? _contextAiPromptOverride!.trim()
        : _trackerContextAiPrompt(section);
    final payload = <String, dynamic>{
      ..._trackerContextAiPayload(section),
      ...?(useOverride ? _contextAiPayloadOverride : null),
    };
    final selectionMode = '${payload['selection_mode'] ?? ''}';
    final payloadPlayerIds = _contextIntList(payload['player_ids']);
    final directPlayerId = int.tryParse('${payload['player_id'] ?? 0}') ?? 0;
    final focusedPlayerId =
        selectionMode == 'team' || selectionMode == 'players'
            ? 0
            : (directPlayerId > 0
                ? directPlayerId
                : (payloadPlayerIds.length == 1 ? payloadPlayerIds.first : 0));
    final payloadNames = _contextStringList(payload['player_names']);
    final directPlayerName = '${payload['player_name'] ?? ''}'.trim();
    final rosterFocusedNames = _players
        .where((player) => player.id == focusedPlayerId)
        .map((player) => player.name.trim())
        .where((name) => name.isNotEmpty)
        .toList(growable: false);
    final focusedPlayerName = directPlayerName.isNotEmpty
        ? directPlayerName
        : (payloadNames.length == 1
            ? payloadNames.first
            : (rosterFocusedNames.isNotEmpty
                ? rosterFocusedNames.first
                : null));
    final sessionIds = _contextIntList(payload['session_ids']);
    final contextSignature = jsonEncode(<String, dynamic>{
      'section': section.name,
      'session_ids': sessionIds,
      'player_ids': payloadPlayerIds,
      'player_id': focusedPlayerId,
      'bpm': payload['bpm'],
      'time_ms': payload['time_ms'],
      'minute': payload['minute'],
      'revision': _contextAiRevision,
    });
    final subtitle = selectionMode == 'players'
        ? '${payloadPlayerIds.length} игрока · ${sessionIds.length} сессий'
        : focusedPlayerName?.isNotEmpty == true
            ? focusedPlayerName!
            : (_liveRunning ? 'Live · ${widget.teamName}' : widget.teamName);

    return CmrContextAiLayer(
      child: child,
      expanded: expanded,
      onToggle: () {
        setState(() {
          final next = !expanded;
          _contextAiExpanded = next;
          if (next) _contextAiRevision++;
        });
      },
      clubId: widget.clubId,
      userId: widget.userId,
      teamId: widget.teamId,
      clubName: widget.clubName,
      teamName: widget.teamName,
      contextTitle: _trackerContextAiTitle(section),
      contextSubtitle: subtitle,
      initialPrompt: prompt,
      initialPayload: payload,
      panelKey: ValueKey<String>(
        'tracker_context_ai_$contextSignature',
      ),
      bottomInset: bottomInset,
      playerOnlyMode: focusedPlayerId > 0,
      playerId: focusedPlayerId > 0 ? focusedPlayerId : null,
      playerName: focusedPlayerId > 0 ? focusedPlayerName : null,
      onNavigate: _handleTrackerAiNavigate,
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final trackerTextTheme = baseTheme.textTheme
        .apply(
          fontFamily: 'Inter',
          bodyColor: _TD.text,
          displayColor: _TD.text,
        )
        .copyWith(
          titleLarge: baseTheme.textTheme.titleLarge?.copyWith(
            fontFamily: 'Inter',
            fontSize: 18,
            fontWeight: FontWeight.w600,
            height: 1.18,
            letterSpacing: 0,
          ),
          titleMedium: baseTheme.textTheme.titleMedium?.copyWith(
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.w600,
            height: 1.20,
            letterSpacing: 0,
          ),
          bodyLarge: baseTheme.textTheme.bodyLarge?.copyWith(
            fontFamily: 'Inter',
            fontSize: 13.5,
            fontWeight: FontWeight.w400,
            height: 1.30,
            letterSpacing: 0,
          ),
          bodyMedium: baseTheme.textTheme.bodyMedium?.copyWith(
            fontFamily: 'Inter',
            fontSize: 12.5,
            fontWeight: FontWeight.w400,
            height: 1.28,
            letterSpacing: 0,
          ),
          bodySmall: baseTheme.textTheme.bodySmall?.copyWith(
            fontFamily: 'Inter',
            fontSize: 11.2,
            fontWeight: FontWeight.w500,
            height: 1.22,
            letterSpacing: 0,
          ),
          labelLarge: baseTheme.textTheme.labelLarge?.copyWith(
            fontFamily: 'Inter',
            fontSize: 12.2,
            fontWeight: FontWeight.w600,
            letterSpacing: 0,
          ),
        );

    final trackerTheme = baseTheme.copyWith(
      textTheme: trackerTextTheme,
      primaryTextTheme: trackerTextTheme,
    );

    if (widget.analyticsOnly) {
      return Theme(
        data: trackerTheme,
        child: WillPopScope(
          onWillPop: () async => true,
          child: Scaffold(
            backgroundColor: const Color(0xFFF6F7F6),
            body: SafeArea(
              child: _withTrackerContextAiLayer(
                Column(
                  children: [
                    _buildAnalyticsOnlyHeader(),
                    Expanded(
                      child: Container(
                        color: Colors.white,
                        child: _analytics(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (widget.embeddedInClubWorkspace) {
      return Theme(
        data: trackerTheme,
        child: WillPopScope(
          onWillPop: _confirmExitTrackerIfNeeded,
          child: _withTrackerContextAiLayer(
            _buildEmbeddedTrackerProgram(),
            bottomInset: 8,
          ),
        ),
      );
    }

    return Theme(
      data: trackerTheme,
      child: WillPopScope(
        onWillPop: _confirmExitTrackerIfNeeded,
        child: Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: _withTrackerContextAiLayer(
              Row(
                children: [
                  _DarkRail(
                    selected: _section,
                    onSelect: (section) {
                      _selectSectionSafely(section);
                    },
                    onBack: _handleBackPressed,
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        if (_section != TrackerWorkspaceSection.live)
                          _TopBar(
                            teamName: widget.teamName,
                            clubName: widget.clubName,
                            selectedPlayer:
                                _selectedPlayer?.name ?? 'Командный режим',
                            selectedSection: _section,
                            loading: _loading,
                            onRefresh: _loadServerData,
                          ),
                        Expanded(
                          child: Padding(
                            padding: _section == TrackerWorkspaceSection.live
                                ? EdgeInsets.zero
                                : const EdgeInsets.fromLTRB(0, 2, 2, 2),
                            child: _buildSection(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnalyticsOnlyHeader() {
    final session = _selectedReportSession;
    final playerName = _selectedPlayer?.name.trim();
    final sessionTitle = session?.title.trim();

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE8EBE8))),
      ),
      child: Row(
        children: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text('К профилю'),
            style: TextButton.styleFrom(
              foregroundColor: _TD.text,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9)),
            ),
          ),
          const SizedBox(width: 12),
          Container(width: 1, height: 28, color: const Color(0xFFE8EBE8)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  playerName == null || playerName.isEmpty
                      ? 'Аналитика игрока'
                      : playerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    color: _TD.text,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  sessionTitle == null || sessionTitle.isEmpty
                      ? '${widget.teamName} · аналитика выбранной сессии'
                      : '${widget.teamName} · $sessionTitle',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    color: _TD.muted,
                    fontSize: 11.2,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Обновить',
            onPressed: _loading ? null : _loadServerData,
            icon: _loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded, size: 19),
          ),
        ],
      ),
    );
  }

  Widget _buildEmbeddedTrackerProgram() {
    if (_trackerWindowMinimized) {
      return _TrackerProgramCollapsedBar(
        clubName: widget.clubName,
        teamName: widget.teamName,
        liveRunning: _liveRunning,
        connected: _hasAnyGpsCommandChannel,
        onRestore: () => setState(() => _trackerWindowMinimized = false),
        onClose: _closeTrackerWindowSafely,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compactNav = constraints.maxWidth < 1180;
        final mobile = constraints.maxWidth < 720;
        final tablet =
            constraints.maxWidth >= 720 && constraints.maxWidth < 1180;
        // На планшете рабочая область важнее широкого меню: оставляем
        // иконки, как в компактном CMR, чтобы Live/PDF не превращались
        // в маленькие прокручиваемые окна. На ПК меню остаётся раскрытым.
        final forceIconNav = mobile || tablet || _trackerSideCollapsed;
        final navWidth = mobile ? 46.0 : (forceIconNav ? 52.0 : 184.0);

        if (mobile) {
          final sections = _trackerMobilePrimarySections;
          final selectedMobileSection = sections.contains(_section)
              ? _section
              : TrackerWorkspaceSection.live;
          final window = Container(
            clipBehavior: Clip.none,
            decoration: const BoxDecoration(color: Colors.transparent),
            child: Column(
              children: [
                _TrackerMobileHeader(
                  teamId: widget.teamId,
                  clubName: widget.clubName,
                  teamName: widget.teamName,
                  selectedPlayer: _selectedPlayer?.name ?? 'Командный режим',
                  selected: _section,
                  sections: sections,
                  selectedMobileSection: selectedMobileSection,
                  loading: _loading,
                  liveRunning: _liveRunning,
                  connected: _hasAnyGpsCommandChannel,
                  onSelectSection: _selectSectionForMobile,
                  onRefresh: _loadServerData,
                  onClose: _closeTrackerWindowSafely,
                  onMinimize: () =>
                      setState(() => _trackerWindowMinimized = true),
                  onOpenDevices: () =>
                      _selectSectionForMobile(TrackerWorkspaceSection.devices),
                ),
                Expanded(
                  // Контент должен продолжаться под плавающим Dock приложения.
                  // Нельзя добавлять Padding вокруг всего раздела: он создаёт
                  // непрозрачную прямоугольную полосу над нижним меню.
                  child: KeyedSubtree(
                    key: ValueKey<String>(
                        'mobile_tracker_section_${_section.name}'),
                    child: _sectionWidget(_section),
                  ),
                ),
              ],
            ),
          );

          return Container(
            width: double.infinity,
            color: const Color(0xFFF6F7F6),
            padding: const EdgeInsets.all(6),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.all(Radius.circular(18)),
                ),
                child: window,
              ),
            ),
          );
        }

        final window = Container(
          clipBehavior: Clip.antiAlias,
          decoration: _TD.unifiedWindow(
            radius: _trackerWindowMaximized ? 0 : (compactNav ? 18 : 20),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: navWidth,
                child: _TrackerProgramSidePanel(
                  teamId: widget.teamId,
                  clubName: widget.clubName,
                  teamName: widget.teamName,
                  selectedPlayer: _selectedPlayer?.name ?? 'Командный режим',
                  selected: _section,
                  loading: _loading,
                  liveRunning: _liveRunning,
                  connected: _hasAnyGpsCommandChannel,
                  compact: forceIconNav,
                  collapsed: forceIconNav,
                  onSelect: (section) {
                    _selectSectionSafely(section);
                  },
                  onRefresh: _loadServerData,
                  onClose: _closeTrackerWindowSafely,
                  onMinimize: () =>
                      setState(() => _trackerWindowMinimized = true),
                  onToggleCollapsed: (compactNav || mobile)
                      ? null
                      : () => setState(
                          () => _trackerSideCollapsed = !_trackerSideCollapsed),
                ),
              ),
              Expanded(child: _buildSection()),
            ],
          ),
        );

        final windowRadius = compactNav ? 18.0 : 20.0;
        final outerPadding =
            _trackerWindowMaximized ? 0.0 : (tablet ? 8.0 : 10.0);

        return Container(
          width: double.infinity,
          color: const Color(0xFFF6F7F6),
          padding: EdgeInsets.all(outerPadding),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(
              _trackerWindowMaximized ? 0 : windowRadius,
            ),
            child: Stack(
              children: [
                Positioned.fill(child: window),
                if (!tablet)
                  Positioned(
                    right: _trackerWindowMaximized ? 8 : 18,
                    bottom: _trackerWindowMaximized ? 8 : 18,
                    child: _TrackerWindowCornerButton(
                      maximized: _trackerWindowMaximized,
                      onTap: () => setState(() =>
                          _trackerWindowMaximized = !_trackerWindowMaximized),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSection() {
    // В desktop-версии нельзя держать все разделы в IndexedStack: скрытые
    // Dropdown/TextField/Scrollable из соседних вкладок продолжают создавать
    // desktop MouseRegion. При resize окна это давало assertion
    // mouse_tracker.dart: !_debugDuringDeviceUpdate именно в аналитике/календаре.
    // Поэтому на ПК держим в дереве только текущий раздел. Live-состояние, точки,
    // выбранные игроки и сессии хранятся в State этого экрана и не теряются.
    return KeyedSubtree(
      key: ValueKey<String>('tracker_section_${_section.name}'),
      child: _sectionWidget(_section),
    );
  }

  Widget _sectionWidget(TrackerWorkspaceSection section) {
    switch (section) {
      case TrackerWorkspaceSection.dashboard:
        return _dashboard();
      case TrackerWorkspaceSection.live:
        return _live();
      case TrackerWorkspaceSection.analytics:
        return _analytics();
      case TrackerWorkspaceSection.activity:
        return _activity();
      case TrackerWorkspaceSection.sessions:
        return _sessions();
      case TrackerWorkspaceSection.devices:
        return _devices();
      case TrackerWorkspaceSection.field:
        return _field();
      case TrackerWorkspaceSection.personal:
        return _personalTrainings();
      case TrackerWorkspaceSection.settings:
        return _settings();
      case TrackerWorkspaceSection.debug:
        return _debug();
    }
  }

  Widget _personalTrainings() {
    return _DarkPage(
      title: 'Личные тренировки',
      subtitle: 'Live и завершённые занятия игроков',
      icon: Icons.person_outline_rounded,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final mobile = constraints.maxWidth < 720;

          final panel = PlayerTrainingNotificationsPanel(
            key: ValueKey('player_training_live_${widget.teamId}'),
            teamId: widget.teamId,
            playerDirectory: <int, Map<String, String>>{
              for (final player in _players)
                if (player.id > 0)
                  player.id: <String, String>{
                    'name': player.name,
                    'avatar': player.avatar ?? '',
                  },
            },
            onOpenAnalytics: (row) => _openAnalyticsArchive(
              mode: PlayerTrainingCalendarMode.personal,
              event: row,
            ),
            onOpenReport: (row) => _openAnalyticsArchive(
              mode: PlayerTrainingCalendarMode.personal,
              event: row,
            ),
          );

          return Container(
            color: Colors.white,
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                mobile ? 8 : 10,
                2,
                mobile ? 8 : 10,
                110,
              ),
              physics: const BouncingScrollPhysics(),
              children: [panel],
            ),
          );
        },
      ),
    );
  }

  Widget _dashboard() {
    return FutureBuilder<TrackerDashboardModel>(
      future: _api.loadDashboard(teamId: widget.teamId),
      builder: (context, snapshot) {
        final dashboard = snapshot.data;
        final summary = dashboard?.summary ?? const <String, dynamic>{};
        final rows = dashboard?.players ?? const <TrackerPlayerLoadRow>[];
        final connected = _teamBlePool.connectedCount;
        final readyFields = _fields.where((f) => f.hasCalibration).length;
        final gpsReady = _points.isNotEmpty || _hasAnyGpsCommandChannel;

        return _DarkPage(
          title: 'Tracker Pro',
          subtitle:
              'Профессиональный режим: подключение, Live, команда, аналитика и поле в одном рабочем сценарии',
          icon: Icons.dashboard_customize_rounded,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DarkActionButton(
                icon: Icons.play_arrow_rounded,
                label: 'Открыть Live',
                primary: true,
                onTap: () => _openTrackerSection(TrackerWorkspaceSection.live),
              ),
              const SizedBox(width: 4),
              _DarkActionButton(
                icon: Icons.sensors_rounded,
                label: 'Трекеры',
                onTap: () =>
                    _openTrackerSection(TrackerWorkspaceSection.devices),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, c) {
              final compact = c.maxWidth < 920;
              final kpi =
                  _dashboardKpis(summary, rows.length, connected, readyFields);
              final left = _DarkCard(
                title: 'Готовность команды',
                subtitle: '$connected/${_players.length} трекеров',
                child: Column(
                  children: [
                    _ReadinessRow(
                        title: 'Игроки',
                        text: _players.isEmpty
                            ? 'Состав не загружен'
                            : '${_players.length} игроков',
                        ok: _players.isNotEmpty),
                    const SizedBox(height: 4),
                    _ReadinessRow(
                        title: 'Трекеры',
                        text: connected == 0
                            ? 'Подключите датчики'
                            : '$connected подключено',
                        ok: connected > 0),
                    const SizedBox(height: 4),
                    _ReadinessRow(
                        title: 'Поле',
                        text: readyFields == 0
                            ? 'Нужна калибровка'
                            : '$readyFields готово',
                        ok: readyFields > 0),
                    const SizedBox(height: 4),
                    _ReadinessRow(
                        title: 'GPS',
                        text: gpsReady ? 'Сигнал есть' : 'Ожидаем пакет',
                        ok: gpsReady),
                    const Spacer(),
                    _DarkActionButton(
                      icon: Icons.sensors_rounded,
                      label: connected == 0
                          ? 'Подключить трекеры'
                          : 'Управлять трекерами',
                      primary: connected == 0,
                      onTap: () =>
                          _openTrackerSection(TrackerWorkspaceSection.devices),
                    ),
                    const SizedBox(height: 4),
                    _DarkActionButton(
                      icon: Icons.map_rounded,
                      label: readyFields == 0
                          ? 'Настроить поле'
                          : 'Проверить поле',
                      onTap: () =>
                          _openTrackerSection(TrackerWorkspaceSection.field),
                    ),
                  ],
                ),
              );

              final center = _DarkCard(
                title: 'Команда онлайн',
                subtitle: snapshot.connectionState == ConnectionState.waiting &&
                        dashboard == null
                    ? 'загрузка'
                    : '${rows.length} игроков в аналитике',
                child: rows.isEmpty
                    ? const _DarkEmpty(
                        icon: Icons.groups_rounded,
                        text:
                            'После подключения трекеров и запуска Live здесь появится таблица игроков.')
                    : ListView(
                        children: rows.take(12).map((p) {
                          return _DarkListTile(
                            icon: Icons.person_rounded,
                            avatarUrl: p.avatar,
                            initials: _playerInitials(p.playerName),
                            title: p.playerName,
                            subtitle:
                                '${(p.distanceM / 1000).toStringAsFixed(2)} км · макс. ${p.maxSpeedKmh.toStringAsFixed(1)} км/ч · спринты ${p.sprintCount}',
                            trailing: 'анализ',
                            active: _selectedPlayer?.id == p.playerId,
                            onTap: () {
                              final matches = _players
                                  .where((x) => x.id == p.playerId)
                                  .toList();
                              setState(() {
                                if (matches.isNotEmpty)
                                  _selectedPlayer = matches.first;
                                _section = TrackerWorkspaceSection.activity;
                              });
                            },
                          );
                        }).toList(),
                      ),
              );

              final right = _DarkCard(
                title: 'Рабочий сценарий',
                subtitle: 'профессиональный мониторинг',
                child: Column(
                  children: [
                    _ScenarioButton(
                        step: '1',
                        title: 'Подключить трекеры',
                        text: 'Датчики и привязка к игрокам',
                        icon: Icons.sensors_rounded,
                        onTap: () => _openTrackerSection(
                            TrackerWorkspaceSection.devices)),
                    const SizedBox(height: 4),
                    _ScenarioButton(
                        step: '2',
                        title: 'Проверить поле',
                        text: 'Калибровка A/B/C/D',
                        icon: Icons.map_rounded,
                        onTap: () =>
                            _openTrackerSection(TrackerWorkspaceSection.field)),
                    const SizedBox(height: 4),
                    _ScenarioButton(
                        step: '3',
                        title: 'Начать Live',
                        text: 'Поле, точки, зоны, сигналы',
                        icon: Icons.play_arrow_rounded,
                        onTap: () =>
                            _openTrackerSection(TrackerWorkspaceSection.live)),
                    const SizedBox(height: 4),
                    _ScenarioButton(
                        step: '4',
                        title: 'Аналитика Pro',
                        text: 'Теплокарта, спринты, скорость, команда',
                        icon: Icons.analytics_rounded,
                        onTap: () => _openTrackerSection(
                            TrackerWorkspaceSection.analytics)),
                    const SizedBox(height: 4),
                    _ScenarioButton(
                        step: '5',
                        title: 'Открыть отчёт',
                        text: 'Сессии, игроки и конструктор PDF / Excel',
                        icon: Icons.assignment_rounded,
                        onTap: () => _openTrackerSection(
                            TrackerWorkspaceSection.sessions)),
                    const SizedBox(height: 4),
                    _ScenarioButton(
                        step: '6',
                        title: 'Личные тренировки',
                        text: 'кто сейчас тренируется лично онлайн',
                        icon: Icons.notifications_active_rounded,
                        onTap: () => _openTrackerSection(
                            TrackerWorkspaceSection.personal)),
                    const Spacer(),
                    const _DarkHint(
                        text:
                            'Главная показывает команду и готовность. Live — только рабочий мониторинг. Активность — графики игрока. Сессии — сохранённые GPS-записи.'),
                  ],
                ),
              );

              final mobileList = c.maxWidth < 520;
              final content = compact
                  ? ListView(
                      children: [
                        SizedBox(
                            height: 118, child: _DashboardKpiStrip(items: kpi)),
                        const _WorkspacePaneDivider.horizontal(),
                        SizedBox(height: 320, child: center),
                        const _WorkspacePaneDivider.horizontal(),
                        SizedBox(height: 270, child: left),
                        const _WorkspacePaneDivider.horizontal(),
                        SizedBox(height: 320, child: right),
                      ],
                    )
                  : Column(
                      children: [
                        SizedBox(
                            height: 118, child: _DashboardKpiStrip(items: kpi)),
                        const SizedBox(height: 0),
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(flex: 3, child: left),
                              const _WorkspacePaneDivider.vertical(),
                              Expanded(flex: 6, child: center),
                              const _WorkspacePaneDivider.vertical(),
                              Expanded(flex: 3, child: right),
                            ],
                          ),
                        ),
                      ],
                    );

              return content;
            },
          ),
        );
      },
    );
  }

  List<_DashboardKpiData> _dashboardKpis(Map<String, dynamic> summary,
      int analyticPlayers, int connected, int readyFields) {
    double d(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
    int i(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
    return [
      _DashboardKpiData(
          icon: Icons.groups_rounded,
          title: 'Игроки онлайн',
          value: '$connected/${_players.length}',
          subtitle: 'трекеры'),
      _DashboardKpiData(
          icon: Icons.route_rounded,
          title: 'Дистанция',
          value:
              '${(d(summary['total_distance_m']) / 1000).toStringAsFixed(2)} км',
          subtitle: 'команда'),
      _DashboardKpiData(
          icon: Icons.speed_rounded,
          title: 'Макс. скорость',
          value: '${d(summary['max_speed_kmh']).toStringAsFixed(1)}',
          subtitle: 'км/ч'),
      _DashboardKpiData(
          icon: Icons.local_fire_department_rounded,
          title: 'Спринты',
          value: '${i(summary['sprint_count'])}',
          subtitle: 'команда'),
      _DashboardKpiData(
          icon: Icons.monitor_heart_rounded,
          title: 'Нагрузка',
          value: d(summary['avg_load_score']).toStringAsFixed(1),
          subtitle: 'средняя'),
      _DashboardKpiData(
          icon: Icons.map_rounded,
          title: 'Поля',
          value: '$readyFields/${_fields.length}',
          subtitle: 'калибровка'),
    ];
  }

  Widget _live() {
    return TrackerLivePanel(
      key: ValueKey(
          'live_${widget.clubId}_${widget.teamId}_$_livePanelKeySuffix'),
      clubId: widget.clubId,
      teamId: widget.teamId,
      teamName: widget.teamName,
      players: _players,
      selectedPlayer: _selectedPlayer,
      selectedField: _selectedField,
      ble: _ble,
      onStartTeamLive: _startTeamLiveFromPanel,
      onStopTeamLive: _stopTeamLiveFromPanel,
      teamTrackerCount: _teamBlePool.connectedCount,
      connectedTeamPlayerIds: Set<int>.unmodifiable(_connectedTeamPlayerIds),
      savedDevices: _savedDevices,
      heartRateByPlayerId:
          Map<int, HeartRateSample>.unmodifiable(_latestHeartByPlayerId),
      heartRateConnectedCount: _heart.connectedCount,
      batteryPercent: _batteryPercent,
      scanningBluetooth: _scanning,
      onScanBluetooth: _scanning ? null : () => _scan(universalMode: true),
      onManageTrackers: () =>
          _openTrackerSection(TrackerWorkspaceSection.devices),
      onResetTeamGps: _resetAllTeamTrackers,
      onSelectPlayer: (player) {
        if (!mounted) return;
        setState(() => _selectedPlayer = player);
      },
      onLiveRunningChanged: (running) {
        if (!mounted || _liveRunning == running) return;
        setState(() {
          _liveRunning = running;
          if (running) {
            // Новая Live-сессия должна начинаться с чистой локальной траектории.
            // Иначе карта/локомоторика показывают хвосты предыдущего игрока/даты.
            _points.clear();
            _lastWorkspaceGpsPoint = null;
            _lastWorkspaceGpsAt = null;
            _lastWorkspaceGps = 'нет GPS';
          }
        });
        unawaited(_logRemote(
          running ? 'Live включён' : 'Live остановлен/поставлен на паузу',
          source: running ? 'workspace_live_started' : 'workspace_live_stopped',
        ));
        if (!running) {
          // После стопа Live сервер создаёт финальную сессию. Обновляем поля/устройства/сессии,
          // чтобы аналитика и календарь не показывали старые накопленные данные.
          Future<void>.delayed(const Duration(milliseconds: 800), () async {
            if (mounted) await _loadServerData();
          });
        }
      },
      pauseRequestSignal: _livePauseRequestSignal,
      stopRequestSignal: _liveStopRequestSignal,
      exitWithoutSaveRequestSignal: _liveExitWithoutSaveRequestSignal,
      startRequestSignal: _liveStartRequestSignal,
      onLiveSessionIdChanged: (id) {
        if (!mounted || _activeLiveSessionId == id) return;
        setState(() => _activeLiveSessionId = id);
        if (id != null) {
          unawaited(_logRemote('Live session id=$id',
              source: 'workspace_live_session'));
        }
      },
    );
  }

  void _requestLiveFromAnalytics() {
    final ctx = <String, dynamic>{
      'team_id': widget.teamId,
      'player_id': _selectedPlayer?.id,
      'field_id': _selectedField?.id,
      'live_running': _liveRunning,
      'live_session_id': _activeLiveSessionId,
      'ble_command_channel_ready': _hasAnyGpsCommandChannel,
      'team_ble_connected_count': _teamBlePool.connectedCount,
      'local_points': _points.length,
    };

    unawaited(_logRemote(
      _liveRunning
          ? 'Аналитика: Live уже идёт, данные связаны с текущей сессией'
          : 'Аналитика: внешний запуск Live без перехода на отдельный экран',
      source: _liveRunning
          ? 'analytics_live_already_running'
          : 'analytics_live_start_signal',
      extra: ctx,
    ));

    if (_liveRunning) {
      _toast('Live',
          'Live уже идёт. Аналитика связана с текущей сессией и продолжит получать точки.');
      return;
    }

    final width = MediaQuery.maybeOf(context)?.size.width ?? 1200;
    final openLivePanel = width < 720;
    setState(() {
      if (openLivePanel) _section = TrackerWorkspaceSection.live;
      _liveStartRequestSignal++;
    });
    _toast(
        'Live',
        openLivePanel
            ? 'Открываю Live и запускаю запись.'
            : 'Запускаю Live из аналитики без перехода на другой экран.');
  }

  Future<void> _openAnalyticsReportInAi(Map<String, dynamic> payload) async {
    final sessionId = int.tryParse(
            '${payload['session_id'] ?? _selectedReportSession?.id ?? 0}') ??
        0;
    final sessionTitle =
        '${payload['session_title'] ?? _selectedReportSession?.title ?? 'Тренировка'}'
            .trim();
    final selectedDate = '${payload['selected_date'] ?? ''}'.trim();
    final rawPlayerNames = payload['player_names'];
    final playerNames = rawPlayerNames is List
        ? rawPlayerNames
            .map((e) => '$e'.trim())
            .where((e) => e.isNotEmpty)
            .toList(growable: false)
        : const <String>[];
    final rawPlayerFilter = '${payload['player_filter'] ?? 'команда'}'.trim();
    final playerFilter =
        playerNames.isNotEmpty ? playerNames.join(', ') : rawPlayerFilter;
    final selectedPlayerIds = _contextIntList(payload['player_ids']);
    final contextPayload = <String, dynamic>{
      ..._trackerAnalyticsAiContext,
      ...payload,
      'team_id': widget.teamId,
      'club_id': widget.clubId,
      'session_id': sessionId > 0 ? sessionId : null,
      if (selectedPlayerIds.isNotEmpty) 'player_ids': selectedPlayerIds,
      'selection_mode': selectedPlayerIds.isEmpty
          ? 'team'
          : (selectedPlayerIds.length == 1 ? 'single_player' : 'players'),
      if (selectedPlayerIds.length == 1) 'player_id': selectedPlayerIds.first,
      if (playerNames.length == 1) 'player_name': playerNames.first,
      'source': 'tracker_analytics_report_modal',
    };
    final prompt = 'Проанализируй выбранный отчет по тренировке «$sessionTitle»'
        '${selectedDate.isEmpty ? '' : ' за $selectedDate'}. '
        'Фильтр игроков: $playerFilter. Дай тренеру краткую сводку нагрузки, выдели риски, лидеров, отклонения по локомоторике, механике и пульсу, оцени микроцикл и предложи конкретные действия на следующую тренировку.';

    _handleTrackerAnalyticsAiContextChanged(contextPayload);
    _openTrackerContextAi(
      prompt: prompt,
      payload: contextPayload,
    );
  }

  Future<void> _openPulseLoadPointInAi(Map<String, dynamic> point) async {
    final name =
        '${point['player_name'] ?? _selectedPlayer?.name ?? 'Игрок'}'.trim();
    final bpm = int.tryParse('${point['bpm'] ?? 0}') ?? 0;
    final zone = '${point['zone'] ?? ''}'.toUpperCase();
    final minute = int.tryParse('${point['minute'] ?? 0}') ?? 0;
    final activity = '${point['activity_type'] ?? ''}'.trim();
    final pointPlayerId = int.tryParse('${point['player_id'] ?? 0}') ?? 0;
    final contextPayload = <String, dynamic>{
      ..._trackerAnalyticsAiContext,
      ...point,
      'team_id': widget.teamId,
      'club_id': widget.clubId,
      if ((_selectedReportSession?.id ?? 0) > 0)
        'session_id': _selectedReportSession!.id,
      if (pointPlayerId > 0) 'player_ids': <int>[pointPlayerId],
      if (name.isNotEmpty) 'player_names': <String>[name],
      'selection_mode': 'single_player',
      'selected_heart_rate_point': true,
      'source': 'tracker_pulse_load_point_modal',
    };
    final prompt =
        'Проанализируй точку высокой нагрузки игрока $name: $bpm bpm, зона $zone, ${minute > 0 ? '$minute минута' : 'выбранный момент'}, режим ${activity.isEmpty ? 'не указан' : activity}. Объясни риск с учетом возраста и футбольной нагрузки, оцени восстановление и дай рекомендацию тренеру. Открой отчет по этому игроку и моменту.';
    _handleTrackerAnalyticsAiContextChanged(contextPayload);
    _openTrackerContextAi(
      prompt: prompt,
      payload: contextPayload,
    );
  }

  Widget _analytics() {
    return TrackerActionAnalyticsSuite(
      api: _api,
      clubId: widget.clubId,
      userId: widget.userId,
      teamId: widget.teamId,
      teamName: widget.teamName,
      clubName: widget.clubName,
      players: _players,
      selectedPlayer: _selectedPlayer,
      selectedField: _selectedField,
      localPoints: List<ActionTrackerGpsPoint>.unmodifiable(_points),
      selectedSession: _selectedReportSession,
      onRefresh: () => setState(() {}),
      onSelectPlayer: (id) {
        final matches = _players.where((p) => p.id == id).toList();
        if (matches.isNotEmpty) setState(() => _selectedPlayer = matches.first);
      },
      onSelectSession: (session) =>
          setState(() => _selectedReportSession = session),
      onOpenCalibration: widget.analyticsOnly
          ? () => _toast(
              'Аналитика', 'Калибровка поля доступна в полном режиме трекера')
          : () => _openTrackerSection(TrackerWorkspaceSection.field),
      onClearField: _selectedField == null ? null : _clearSelectedField,
      onOpenSessions: widget.analyticsOnly
          ? () => _toast(
              'Аналитика', 'Выбор другой сессии выполняется из профиля игрока')
          : () => _openTrackerSection(TrackerWorkspaceSection.sessions),
      onOpenLive: widget.analyticsOnly
          ? () => _toast('Аналитика', 'Live доступен в полном режиме трекера')
          : _requestLiveFromAnalytics,
      liveRunning: _liveRunning,
      commandChannelReady: _hasAnyGpsCommandChannel,
      offlineRecordsCount: _records.length,
      localPointsCount: _points.length,
      onRequestOfflineRecords: () {
        unawaited(() async {
          try {
            _pushLocalLog('OFFLINE GPS: запрос списка записей с датчика');
            await _ble.requestRecordList();
            await _logRemote('Офлайн GPS: запрос списка записей отправлен',
                source: 'workspace_offline_records_request');
            _toast('Офлайн GPS', 'Запрос списка записей отправлен');
          } catch (e) {
            await _logRemote('Офлайн GPS ошибка чтения записей: $e',
                level: 'error', source: 'workspace_offline_records_error');
            _toast('Офлайн GPS', '$e');
          }
        }());
      },
      onSaveOfflineSession: () => unawaited(_saveRecordAsSession()),
      onOpenAiAnalysis: (payload) =>
          unawaited(_openAnalyticsReportInAi(payload)),
      onOpenAiLoadPoint: (point) => unawaited(_openPulseLoadPointInAi(point)),
      onAiContextChanged: _handleTrackerAnalyticsAiContextChanged,
      onDebug: (message, context) => unawaited(_logRemote(message,
          source: 'workspace_gps_analytics', level: 'info', extra: context)),
      initialTab: _analyticsInitialTab,
      initialTabSignal: _analyticsInitialTabSignal,
      initialCalendarMode: _analyticsInitialCalendarMode,
      initialCalendarModeSignal: _analyticsInitialCalendarModeSignal,
    );
  }

  Widget _activity() {
    return TrackerPlayerActivityScreen(
      key: ValueKey(
          'activity_${widget.clubId}_${widget.teamId}_${_selectedPlayer?.id ?? 0}_${_selectedField?.id ?? 0}'),
      teamId: widget.teamId,
      teamName: widget.teamName,
      rosterPlayers: _players,
      selectedPlayer: _selectedPlayer,
      fieldId: _selectedField?.id,
    );
  }

  Widget _sessions() {
    Future<void> processSession(TrackerSessionModel session) async {
      try {
        await _api.processSession(sessionId: session.id);
        _toast('Сессия', 'Обработка запущена');
        setState(() {});
      } catch (e) {
        _toast('Сессия', '$e');
      }
    }

    Future<void> openReportTrainingPicker() async {
      final picked = await showDialog<TrackerSessionModel>(
        context: context,
        barrierColor: Colors.black.withOpacity(.22),
        builder: (dialogContext) {
          final media = MediaQuery.of(dialogContext).size;
          final width = math.min(1380.0, math.max(420.0, media.width - 24));
          final height = math.min(740.0, math.max(500.0, media.height - 24));
          return Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: SizedBox(
              width: width,
              height: height,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Material(
                  color: Colors.white,
                  child: Column(
                    children: [
                      Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 9),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          border: Border(
                              bottom:
                                  BorderSide(color: _TD.softLine, width: .8)),
                        ),
                        child: Row(children: [
                          Container(
                            width: 30,
                            height: 30,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                                color: _TD.greenSoft,
                                borderRadius: BorderRadius.circular(7),
                                border: Border.all(
                                    color: _TD.greenBorder, width: .8)),
                            child: const Icon(Icons.calendar_month_rounded,
                                color: _TD.green, size: 17),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                const Text('Выбор отчёта',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color: _TD.text,
                                        fontSize: 14.6,
                                        fontWeight: FontWeight.w700,
                                        height: 1)),
                                Text(
                                    _selectedReportSession == null
                                        ? 'Команда · Отчёты · выберите дату и сессию'
                                        : 'Команда · Отчёты · 1 сесс.',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: _TD.muted,
                                        fontSize: 11.8,
                                        fontWeight: FontWeight.w600,
                                        height: 1.1)),
                              ])),
                          _NoHoverTap(
                            onTap: () => Navigator.of(dialogContext).maybePop(),
                            child: Container(
                              width: 34,
                              height: 34,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8)),
                              child: const Icon(Icons.close_rounded,
                                  color: _TD.graphite, size: 19),
                            ),
                          ),
                        ]),
                      ),
                      Container(
                        height: 50,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: const BoxDecoration(
                            color: Colors.white,
                            border: Border(
                                bottom: BorderSide(
                                    color: _TD.softLine, width: .8))),
                        child: Row(children: [
                          Container(
                            height: 34,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                                color: _TD.greenSoft,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: _TD.greenBorder, width: .8)),
                            child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.calendar_month_rounded,
                                      color: _TD.green, size: 15),
                                  SizedBox(width: 6),
                                  Text('Дата и сессии',
                                      style: TextStyle(
                                          color: _TD.green,
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700))
                                ]),
                          ),
                          const SizedBox(width: 8),
                          Container(
                              height: 34,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              alignment: Alignment.center,
                              child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.groups_rounded,
                                        color: _TD.graphiteSoft, size: 15),
                                    SizedBox(width: 6),
                                    Text('Игроки',
                                        style: TextStyle(
                                            color: _TD.graphite,
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700))
                                  ])),
                          const SizedBox(width: 8),
                          Container(
                              height: 34,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              alignment: Alignment.center,
                              child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.layers_rounded,
                                        color: _TD.graphiteSoft, size: 15),
                                    SizedBox(width: 6),
                                    Text('Командные',
                                        style: TextStyle(
                                            color: _TD.graphite,
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w700))
                                  ])),
                        ]),
                      ),
                      Expanded(
                        child: _SessionsListPane(
                          api: _api,
                          teamId: widget.teamId,
                          playerId: null,
                          players: _players,
                          selectedSession: _selectedReportSession,
                          calendarExpanded: true,
                          onCalendarExpandedChanged: (_) =>
                              Navigator.of(dialogContext).maybePop(),
                          onSelect: (session) =>
                              Navigator.of(dialogContext).pop(session),
                          onProcess: (session) =>
                              unawaited(processSession(session)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
      if (picked != null && mounted) {
        setState(() => _selectedReportSession = picked);
      }
    }

    return LayoutBuilder(
      builder: (context, outer) {
        final phone = outer.maxWidth < 700;
        if (phone) {
          // На телефоне раздел отчёта работает списком: выбор сессии, игроков и блоков выгрузки открывается в нижнем листе.
          return _DarkPage(
            title: 'Отчёт и выгрузка',
            subtitle: 'сессии по дате, игроки и блоки PDF / Excel',
            icon: Icons.assignment_rounded,
            child: _MobileSessionsReportPane(
              api: _api,
              teamId: widget.teamId,
              teamName: widget.teamName,
              players: _players,
              selectedSession: _selectedReportSession,
              onSelect: (session) =>
                  setState(() => _selectedReportSession = session),
              onProcess: processSession,
              onRefresh: () => setState(() {}),
              onDownloadRecords: _requestGpsRecordsFromTracker,
              onSaveGps: _savingRecord ? null : _saveRecordAsSession,
              savingRecord: _savingRecord,
            ),
          );
        }

        final trainingButtonLabel = _selectedReportSession == null
            ? 'Выбор тренировки'
            : 'Выбор тренировки #${_selectedReportSession!.id}';

        return _DarkPage(
          title: 'Отчёт по тренировке',
          subtitle: _selectedReportSession == null
              ? 'конструктор выгрузки'
              : 'сессия #${_selectedReportSession!.id} · ${_selectedReportSession!.createdAt}',
          icon: Icons.assignment_rounded,
          trailing: _TrackerToolbarScroller(children: [
            _DarkActionButton(
              icon: Icons.calendar_month_rounded,
              label: trainingButtonLabel,
              primary: _selectedReportSession == null,
              onTap: () => unawaited(openReportTrainingPicker()),
            ),
            _DarkActionButton(
                icon: Icons.help_outline_rounded,
                label: 'Помощь',
                onTap: () => _toast('Отчёт',
                    'Нажмите «Выбор тренировки», выберите дату и сессию, ниже — игроков и блоки выгрузки.')),
            _DarkActionButton(
                icon: Icons.refresh_rounded,
                label: 'Обновить',
                onTap: () => setState(() {})),
            _DarkActionButton(
              icon: Icons.download_rounded,
              label: 'Загрузить записи',
              onTap: _requestGpsRecordsFromTracker,
            ),
            _DarkActionButton(
              icon: Icons.save_alt_rounded,
              label: _savingRecord ? 'Сохраняю...' : 'Сохранить GPS',
              onTap: _savingRecord ? null : _saveRecordAsSession,
            ),
          ]),
          child: _SelectedTrainingReportPane(
            session: _selectedReportSession,
            teamId: widget.teamId,
            teamName: widget.teamName,
            players: _players,
            apiBaseUrl: _api.apiBaseUrl,
          ),
        );
      },
    );
  }

  String _normalizeTrackerName(String value) {
    final v = value.trim().toUpperCase();
    if (v.isEmpty) return '';
    return v.replaceAll(RegExp(r'\s+'), ' ');
  }

  String _normalizeDeviceId(String value) {
    return value.trim().toUpperCase().replaceAll(RegExp(r'[^0-9A-F]'), '');
  }

  String _savedDeviceGroupKey(TrackerDeviceModel device) {
    final name = _normalizeTrackerName(device.deviceName);
    final id = _normalizeDeviceId(device.deviceUuid);
    // iOS/macOS может хранить один и тот же датчик как UUID, а сам датчик отдаёт MAC.
    // Для $ATP/$ACT/$GPS объединяем по имени, чтобы не показывать две одинаковые карточки.
    if (name.startsWith(r'$ATP') ||
        name.startsWith(r'$ACT') ||
        name.startsWith(r'$GPS')) {
      return 'name:$name';
    }
    return id.isEmpty ? 'name:$name' : 'id:$id';
  }

  bool _trackerIdOrNameMatches(
      String uuid, String name, TrackerDeviceModel device) {
    final a = _normalizeDeviceId(uuid);
    final b = _normalizeDeviceId(device.deviceUuid);
    if (a.isNotEmpty && b.isNotEmpty) {
      if (a == b) return true;
      if (a.length >= 12 && b.length >= 12 && (a.endsWith(b) || b.endsWith(a)))
        return true;
    }
    final rn = _normalizeTrackerName(name);
    final dn = _normalizeTrackerName(device.deviceName);
    return rn.isNotEmpty && dn.isNotEmpty && rn == dn;
  }

  ActionTrackerDevice? _connectedTeamTrackerForSaved(
    TrackerDeviceModel device,
  ) {
    for (final connected in _teamBlePool.connectedInfos) {
      if (_trackerIdOrNameMatches(
        connected.id,
        connected.name,
        device,
      )) {
        return connected;
      }
    }
    return null;
  }

  bool _isTeamTrackerConnected(TrackerDeviceModel device) =>
      _connectedTeamTrackerForSaved(device) != null;

  String _teamBindingKey(String uuid, String name) {
    final normalizedName = _normalizeTrackerName(name);
    if (normalizedName.startsWith(r'$ATP') ||
        normalizedName.startsWith(r'$ACT') ||
        normalizedName.startsWith(r'$GPS')) {
      return 'name:$normalizedName';
    }
    final normalizedId = _normalizeDeviceId(uuid);
    return normalizedId.isEmpty ? 'name:$normalizedName' : 'id:$normalizedId';
  }

  TrackerPlayerOption? _playerOptionForIdentity(int playerId) {
    for (final player in _players) {
      if (player.id == playerId || player.identityIds.contains(playerId)) {
        return player;
      }
    }
    return null;
  }

  void _rememberConfirmedTeamBinding({
    required TrackerPlayerOption player,
    required String deviceUuid,
    required String deviceName,
    int? batteryPercent,
  }) {
    _confirmedTeamGpsBindings[_teamBindingKey(deviceUuid, deviceName)] =
        TeamTrackerBinding(
      playerId: player.id,
      playerName: player.name,
      deviceUuid: deviceUuid,
      deviceName: deviceName,
      batteryPercent: batteryPercent,
    );
  }

  void _forgetConfirmedTeamBinding(String deviceUuid, String deviceName) {
    _confirmedTeamGpsBindings.remove(_teamBindingKey(deviceUuid, deviceName));
  }

  List<TrackerDeviceModel> get _mergedSavedDevices {
    final byKey = <String, TrackerDeviceModel>{};
    for (final device in _savedDevices) {
      final key = _savedDeviceGroupKey(device);
      final old = byKey[key];
      if (old == null) {
        byKey[key] = device;
        continue;
      }
      // API возвращает записи от новых к старым. Если у MAC/iOS-алиасов
      // случайно остались разные владельцы, не заменяем свежую привязку
      // более старой только потому, что её id похож на MAC.
      final oldHasPlayer =
          old.playerId != null || (old.playerName ?? '').trim().isNotEmpty;
      final newHasPlayer = device.playerId != null ||
          (device.playerName ?? '').trim().isNotEmpty;
      if (!oldHasPlayer && newHasPlayer) {
        byKey[key] = device;
      }
    }
    return byKey.values.toList(growable: false);
  }

  int _savedDeviceAliasCount(TrackerDeviceModel device) {
    final key = _savedDeviceGroupKey(device);
    return _savedDevices.where((d) => _savedDeviceGroupKey(d) == key).length;
  }

  String _savedDeviceStatus(TrackerDeviceModel device) {
    final connected = _isTeamTrackerConnected(device) ||
        (_ble.commandChannelReady &&
            _ble.connectedInfo != null &&
            _trackerIdOrNameMatches(
                _ble.connectedInfo!.id, _ble.connectedInfo!.name, device));
    if (connected) return 'реальный BLE TX/RX готов';
    final remote = _remoteConnectedTrackers
        .any((r) => _trackerIdOrNameMatches(r.uuid, r.name, device));
    if (remote) return 'реально занят: другое окно/устройство';
    if (device.playerId != null || (device.playerName ?? '').trim().isNotEmpty)
      return 'только серверная запись: игрок назначен';
    return 'только серверная запись: без игрока';
  }

  Color _savedDeviceStatusColor(TrackerDeviceModel device) {
    final status = _savedDeviceStatus(device);
    if (status.contains('TX/RX')) return _TD.green;
    if (status.contains('занят')) return _TD.orange;
    return _TD.muted;
  }

  bool _isBleDebugMap(Map<String, dynamic> log) {
    final text = '${log['message'] ?? ''} ${log['source'] ?? ''}'.toLowerCase();
    return text.contains('ble') ||
        text.contains('scan') ||
        text.contains('gps sensor') ||
        text.contains('tracker') ||
        text.contains('connect') ||
        text.contains('rx') ||
        text.contains('tx');
  }

  List<String> get _localBleDebugLines => _logs
      .where((line) {
        final lower = line.toLowerCase();
        return lower.contains('ble') ||
            lower.contains('scan') ||
            lower.contains('gps') ||
            lower.contains('rx') ||
            lower.contains('tx') ||
            lower.contains('подключ');
      })
      .take(24)
      .toList(growable: false);

  Widget _scanDebugCard({required bool compact}) {
    final remote =
        _remoteDebugLogs.where(_isBleDebugMap).take(18).toList(growable: false);
    final local =
        _localBleDebugLines.take(compact ? 8 : 10).toList(growable: false);
    return _DarkCard(
      title: 'Онлайн debug поиска',
      subtitle: _remoteConsoleSubtitle(),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: _DarkHint(
              text:
                  'Здесь видно поиск с этого планшета и других устройств команды: разрешения, raw_seen, кандидаты, ошибки подключения и TX/RX. Если raw_seen=0 — устройство вообще не видит BLE вокруг.',
            ),
          ),
          const SizedBox(width: 4),
          _DarkActionButton(
              icon: Icons.refresh_rounded,
              label: _remoteDebugLoading ? '...' : 'Логи',
              onTap: _remoteDebugLoading ? null : () => _loadRemoteDebugLogs()),
          const SizedBox(width: 4),
          _DarkActionButton(
              icon: Icons.search_rounded,
              label: _scanning ? 'Поиск...' : 'Поиск GPS',
              primary: true,
              onTap: _scanning ? null : () => _scan(universalMode: true)),
        ]),
        const SizedBox(height: 6),
        Expanded(
          child: remote.isEmpty && local.isEmpty
              ? const _DarkEmpty(
                  icon: Icons.terminal_rounded,
                  text:
                      'Пока нет debug-строк. Нажмите «Поиск GPS» — появятся adapter, raw_seen, кандидаты и причина, почему трекер не найден.')
              : ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    if (remote.isNotEmpty)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 4),
                        child: Text('Сервер / другие устройства',
                            style: TextStyle(
                                color: _TD.greenDark,
                                fontSize: 10.2,
                                fontWeight: FontWeight.w500)),
                      ),
                    ...remote.map((log) {
                      final level = '${log['level'] ?? 'info'}';
                      final message = '${log['message'] ?? ''}'.trim();
                      final source = '${log['source'] ?? ''}'.trim();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Text(
                          '${_remoteLogTimeLabel(log)} [$level] $source · ${message.isEmpty ? '—' : message}',
                          maxLines: compact ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: _TD.muted,
                              fontFamily: 'monospace',
                              fontSize: 11.0,
                              fontWeight: FontWeight.w600),
                        ),
                      );
                    }),
                    if (local.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 4),
                        child: Text('Локально',
                            style: TextStyle(
                                color: _TD.greenDark,
                                fontSize: 11.0,
                                fontWeight: FontWeight.w700)),
                      ),
                      ...local.map((line) => Padding(
                            padding: const EdgeInsets.only(bottom: 5),
                            child: Text(
                              line,
                              maxLines: compact ? 2 : 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: _TD.muted,
                                  fontFamily: 'monospace',
                                  fontSize: 11.0,
                                  fontWeight: FontWeight.w600),
                            ),
                          )),
                    ],
                  ],
                ),
        ),
      ]),
    );
  }

  Future<void> _connectGpsAndAssignToSelectedPlayer(
      ActionTrackerDevice device) async {
    if (_liveRunning || _teamLiveCoordinator.running) {
      _toast(
        'Командный Live уже идёт',
        'Новый GPS подключается между тренировками. Сначала сохраните текущий Live, затем измените состав датчиков.',
      );
      return;
    }
    final player = _selectedPlayer;
    if (player == null) {
      _toast('Назначение', 'Сначала выберите игрока в списке команды.');
      return;
    }

    final normalizedNewName = _normalizeTrackerName(device.name);
    for (final connected in _teamBlePool.connectedInfos) {
      final sameId =
          _normalizeDeviceId(connected.id) == _normalizeDeviceId(device.id);
      final sameTrackerName = normalizedNewName.isNotEmpty &&
          normalizedNewName == _normalizeTrackerName(connected.name) &&
          (normalizedNewName.startsWith(r'$ATP') ||
              normalizedNewName.startsWith(r'$ACT') ||
              normalizedNewName.startsWith(r'$GPS'));
      if (!sameId && sameTrackerName) {
        _toast(
          'GPS уже подключён',
          '${device.name} уже открыт как ${connected.id}. Это MAC/iOS-алиас одного физического трекера; второй BLE-канал не создаётся.',
        );
        return;
      }
    }

    final samePhysicalDevice = _savedDevices
        .where((d) =>
            !_isHeartRateDeviceModel(d) &&
            _trackerIdOrNameMatches(device.id, device.name, d))
        .toList(growable: false);
    final otherOwner = samePhysicalDevice
        .where((d) => d.playerId != null && d.playerId != player.id)
        .toList(growable: false);
    if (otherOwner.isNotEmpty) {
      final owner = _players
          .where((p) => p.id == otherOwner.first.playerId)
          .toList(growable: false);
      _toast(
        'Привязка заблокирована',
        '${device.name} уже закреплён за ${owner.isEmpty ? 'другим игроком' : owner.first.name}. Сначала снимите старую привязку.',
      );
      return;
    }

    final anotherGpsForPlayer = _savedDevices
        .where((d) =>
            !_isHeartRateDeviceModel(d) &&
            d.playerId == player.id &&
            !_trackerIdOrNameMatches(device.id, device.name, d))
        .toList(growable: false);
    if (anotherGpsForPlayer.isNotEmpty) {
      _toast(
        'GPS уже назначен',
        '${player.name} уже закреплён за ${anotherGpsForPlayer.first.deviceName}. Выберите следующего игрока или сначала снимите эту привязку.',
      );
      return;
    }

    setState(() => _connecting = true);
    try {
      await TrackerPermissions.ensureBlePermissions();
      // Командный режим обязан использовать отдельный BLE-сервис для каждого UUID.
      // Одиночный _ble.connect(device) отключал предыдущий GPS при подключении следующего.
      await _teamBlePool.connect(device);
      _connected =
          device; // только последний выбранный для совместимости UI; соединения хранит pool.
      if (mounted) setState(() {});
      await _api.registerOrBindDevice(
        clubId: widget.clubId,
        teamId: widget.teamId,
        playerId: player.id,
        deviceUuid: device.id,
        deviceName: device.name,
        batteryPercent: _batteryPercent,
      );
      _rememberConfirmedTeamBinding(
        player: player,
        deviceUuid: device.id,
        deviceName: device.name,
        batteryPercent: _batteryPercent,
      );
      unawaited(_logRemote(
        'GPS-трекер подключён и назначен: ${device.name} / ${device.id} → ${player.name}',
        source: 'workspace_ble_player_assign',
      ));
      await _loadServerData();
      if (mounted) {
        setState(() {
          // Следующий GPS нельзя случайно назначить тому же игроку.
          _selectedPlayer = null;
          _deviceWorkspaceDetailsOpen = false;
        });
      }
      _toast(
        'GPS-трекер',
        '${device.name} → ${player.name}. Канал готов и ждёт общего «Старт Live». Теперь выберите следующего игрока.',
      );
    } catch (e) {
      unawaited(_logRemote('Ошибка GPS connect+assign: $e',
          level: 'error', source: 'workspace_ble_player_assign_error'));
      _toast('GPS-трекер', _friendlyBleError(e));
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Widget _devices() {
    int? savedBattery(String uuid) {
      for (final d in _mergedSavedDevices) {
        if (d.deviceUuid == uuid && d.batteryPercent != null)
          return d.batteryPercent;
      }
      return null;
    }

    TrackerDeviceModel? savedGpsForDevice(ActionTrackerDevice info) {
      for (final d in _mergedSavedDevices) {
        if (!_isHeartRateDeviceModel(d) &&
            _trackerIdOrNameMatches(info.id, info.name, d)) {
          return d;
        }
      }
      return null;
    }

    Color batteryColor(int? value) {
      if (value == null) return _TD.borderStrong;
      if (value < 30) return _TD.red;
      if (value < 70) return _TD.orange;
      return _TD.green;
    }

    Color signalColor(int rssi) {
      if (rssi >= -62) return _TD.green;
      if (rssi >= -78) return _TD.orange;
      return _TD.muted;
    }

    int signalBars(int rssi) {
      if (rssi >= -58) return 4;
      if (rssi >= -68) return 3;
      if (rssi >= -82) return 2;
      return 1;
    }

    Widget signalIcon(int rssi, {double size = 18}) {
      final bars = signalBars(rssi);
      final color = signalColor(rssi);
      return SizedBox(
        width: size + 4,
        height: size,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(4, (i) {
            final active = i < bars;
            return Container(
              width: 3,
              height: 5.0 + i * 3.5,
              margin: const EdgeInsets.only(right: 2),
              decoration: BoxDecoration(
                color: active ? color : _TD.borderStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        ),
      );
    }

    Widget batteryPill(int? battery) {
      final color = batteryColor(battery);
      return Row(mainAxisSize: MainAxisSize.min, children: [
        Text(battery == null ? '—' : '$battery%',
            style: const TextStyle(
                color: _TD.text, fontSize: 11, fontWeight: FontWeight.w700)),
        const SizedBox(width: 6),
        Container(
          width: 20,
          height: 10,
          padding: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
              border: Border.all(color: color, width: 1.4),
              borderRadius: BorderRadius.circular(3)),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: battery == null ? 0 : (battery.clamp(0, 100) / 100),
              child: Container(
                  decoration: BoxDecoration(
                      color: color, borderRadius: BorderRadius.circular(2))),
            ),
          ),
        ),
      ]);
    }

    Widget topActionBar({required bool compact}) {
      Widget connectChip({
        required IconData icon,
        required String title,
        required String caption,
        required bool primary,
        required VoidCallback onTap,
      }) {
        final fg = primary ? _TD.greenDark : _TD.text;
        final sub = primary ? _TD.greenDark.withOpacity(.72) : _TD.dim;

        return _NoHoverTap(
          borderRadius: BorderRadius.circular(9),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: 42,
            constraints: BoxConstraints(
              minWidth: compact ? 136 : 150,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: primary ? _TD.greenSoft : Colors.white,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: primary ? _TD.greenBorder : _TD.border.withOpacity(.72),
                width: .8,
              ),
              boxShadow: primary
                  ? [
                      BoxShadow(
                        color: _TD.green.withOpacity(.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: primary ? Colors.white.withOpacity(.92) : _TD.soft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon,
                    color: primary ? _TD.green : _TD.muted, size: 15),
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: fg,
                        fontSize: 11.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: sub,
                        fontSize: 9.8,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (primary) ...[
                const SizedBox(width: 7),
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: _TD.green,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ]),
          ),
        );
      }

      Widget toolChip({
        required IconData icon,
        required String label,
        required VoidCallback onTap,
      }) {
        return _NoHoverTap(
          borderRadius: BorderRadius.circular(9),
          onTap: onTap,
          child: Container(
            height: 34,
            padding: EdgeInsets.symmetric(horizontal: compact ? 9 : 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: _TD.border.withOpacity(.72),
                width: .7,
              ),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(icon, color: _TD.muted, size: 14),
              if (!compact) ...[
                const SizedBox(width: 6),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _TD.text,
                    fontSize: 10.8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ]),
          ),
        );
      }

      return Padding(
        padding: EdgeInsets.fromLTRB(compact ? 8 : 10, 8, compact ? 8 : 10, 6),
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _TD.border.withOpacity(.45),
              width: .6,
            ),
          ),
          child: Row(children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                child: Row(children: [
                  connectChip(
                    icon: Icons.sensors_rounded,
                    title: 'GPS рядом',
                    caption: 'найти трекеры',
                    primary: _deviceWorkspaceTab == 0,
                    onTap: () {
                      setState(() => _deviceWorkspaceTab = 0);
                      _scan(universalMode: true);
                    },
                  ),
                  const SizedBox(width: 8),
                  connectChip(
                    icon: Icons.favorite_rounded,
                    title: 'Polar рядом',
                    caption: 'найти H10',
                    primary: _deviceWorkspaceTab == 1,
                    onTap: () {
                      setState(() => _deviceWorkspaceTab = 1);
                      _scanHeartRate();
                    },
                  ),
                  const SizedBox(width: 10),
                  toolChip(
                      icon: Icons.inventory_2_rounded,
                      label: 'Архив',
                      onTap: () => _openBindingsArchiveSheet()),
                  const SizedBox(width: 7),
                  toolChip(
                      icon: Icons.auto_awesome_motion_rounded,
                      label: 'Авто',
                      onTap: () => _openTeamEquipmentModal()),
                  const SizedBox(width: 7),
                  toolChip(
                      icon: Icons.restart_alt_rounded,
                      label: 'Сброс',
                      onTap: _resetBleState),
                  const SizedBox(width: 7),
                  toolChip(
                      icon: Icons.refresh_rounded,
                      label: 'Обновить',
                      onTap: () {
                        _loadServerData();
                        _loadRemoteDebugLogs(silent: true);
                      }),
                  const SizedBox(width: 7),
                  toolChip(
                      icon: Icons.more_horiz_rounded,
                      label: 'Ещё',
                      onTap: () => _openBindingsArchiveSheet()),
                ]),
              ),
            ),
          ]),
        ),
      );
    }

    Widget tabHeader() {
      Widget tab({required int index, required String title}) {
        final active = _deviceWorkspaceTab == index;
        return Expanded(
          child: _NoHoverTap(
            borderRadius: BorderRadius.circular(9),
            onTap: () => setState(() => _deviceWorkspaceTab = index),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              decoration: BoxDecoration(
                color: active ? _TD.greenSoft : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: active ? _TD.greenBorder : Colors.transparent,
                  width: .8,
                ),
              ),
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: active ? _TD.text : _TD.muted,
                  fontSize: 11.4,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ),
        );
      }

      return Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 7),
        child: Row(children: [
          tab(index: 0, title: 'GPS-трекеры'),
          const SizedBox(width: 7),
          tab(index: 1, title: 'Polar H10'),
        ]),
      );
    }

    Widget gpsDeviceRow(ActionTrackerDevice d) {
      final active = _teamBlePool.isConnected(d.id);
      final saved = savedGpsForDevice(d);
      final assignedName = saved?.playerName;
      final battery = active ? _batteryPercent : savedBattery(d.id);
      final selected = _selectedPlayer != null;
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _TD.border.withOpacity(.65), width: .7),
        ),
        child: _NoHoverTap(
          borderRadius: BorderRadius.circular(10),
          onTap: () => selected
              ? _connectGpsAndAssignToSelectedPlayer(d)
              : _toast(
                  'Назначение', 'Сначала выберите игрока в средней колонке.'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            child: Row(children: [
              signalIcon(d.rssi),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: _TD.text,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text(
                          '${d.id} · ${active ? 'подключен' : 'рядом'}${assignedName == null ? ' · свободен' : ' · $assignedName'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: active ? _TD.green : _TD.muted,
                              fontSize: 11.0,
                              fontWeight: FontWeight.w700)),
                    ]),
              ),
              const SizedBox(width: 8),
              batteryPill(battery),
              const SizedBox(width: 8),
              Text(
                selected ? 'Назначить' : 'Выберите игрока',
                style: TextStyle(
                  color: selected ? _TD.greenDark : _TD.muted,
                  fontSize: 11.0,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ]),
          ),
        ),
      );
    }

    Widget polarDeviceRow(HeartRateBleDevice d) {
      final active = _heart.isConnected(d.id);
      final sample = _heart.lastSampleForDevice(d.id);
      final battery = sample?.batteryPercent;
      final assignedId = _heartDevicePlayerIds[d.id];
      TrackerPlayerOption? assigned;
      if (assignedId != null) {
        final matches =
            _players.where((p) => p.id == assignedId).toList(growable: false);
        if (matches.isNotEmpty) assigned = matches.first;
      }
      final selected = _selectedPlayer != null;
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _TD.border.withOpacity(.65), width: .7),
        ),
        child: _NoHoverTap(
          borderRadius: BorderRadius.circular(10),
          onTap: () => selected
              ? _connectAndAssignHeartRate(d, _selectedPlayer!)
              : _toast(
                  'Назначение', 'Сначала выберите игрока в средней колонке.'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            child: Row(children: [
              signalIcon(d.rssi),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: _TD.text,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text(
                          '${d.id} · ${active ? 'подключен' : 'рядом'}${assigned == null ? ' · свободен' : ' · ${assigned.name}'}${sample == null ? '' : ' · ${sample.bpm} bpm'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: active ? _TD.green : _TD.muted,
                              fontSize: 11.0,
                              fontWeight: FontWeight.w700)),
                    ]),
              ),
              const SizedBox(width: 8),
              batteryPill(battery),
              const SizedBox(width: 8),
              Text(
                selected ? 'Назначить' : 'Выберите игрока',
                style: TextStyle(
                  color: selected ? _TD.greenDark : _TD.muted,
                  fontSize: 11.0,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ]),
          ),
        ),
      );
    }

    Widget gpsDevicesPanel({required bool compact}) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Expanded(
                child: Text('Доступные устройства рядом',
                    style: TextStyle(
                        color: _TD.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w700))),
            _DarkActionButton(
                icon: Icons.refresh_rounded,
                label: 'Найти GPS',
                onTap: _scanning ? null : () => _scan(universalMode: true)),
          ]),
          const SizedBox(height: 10),
          Expanded(
            child: StreamBuilder<List<ActionTrackerDevice>>(
              stream: _ble.devicesStream,
              builder: (context, snapshot) {
                final devices = snapshot.data ?? const <ActionTrackerDevice>[];
                if (_scanning)
                  return const Center(child: CircularProgressIndicator());
                if (devices.isEmpty) {
                  return _DarkEmpty(
                      icon: Icons.bluetooth_disabled_rounded,
                      text:
                          'Нажмите «Найти GPS». Поиск остаётся здесь, а подключение делается кнопкой «+» к выбранному игроку.');
                }
                return ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: devices.length + 1,
                  itemBuilder: (context, index) {
                    if (index == devices.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: _DarkActionButton(
                            icon: Icons.radar_rounded,
                            label: 'Показать все BLE рядом',
                            onTap: _scanningHeart
                                ? null
                                : () =>
                                    _scanHeartRate(showAllBleCandidates: true)),
                      );
                    }
                    return gpsDeviceRow(devices[index]);
                  },
                );
              },
            ),
          ),
        ]),
      );
    }

    Widget heartRatePanel({required bool compact}) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Expanded(
                child: Text('Доступные Polar H10 рядом',
                    style: TextStyle(
                        color: _TD.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w700))),
            _DarkActionButton(
                icon: Icons.refresh_rounded,
                label: 'Найти Polar H10',
                onTap: _scanningHeart ? null : () => _scanHeartRate()),
          ]),
          const SizedBox(height: 10),
          Expanded(
            child: StreamBuilder<List<HeartRateBleDevice>>(
              stream: _heart.devicesStream,
              builder: (context, snapshot) {
                final devices = snapshot.data ?? const <HeartRateBleDevice>[];
                if (_scanningHeart)
                  return const Center(child: CircularProgressIndicator());
                if (devices.isEmpty) {
                  return const _DarkEmpty(
                      icon: Icons.monitor_heart_outlined,
                      text:
                          'Нажмите «Найти Polar H10». После выбора игрока кнопка «+» назначит пульсометр этому игроку.');
                }
                return ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: devices.length + 1,
                  itemBuilder: (context, index) {
                    if (index == devices.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: _DarkActionButton(
                            icon: Icons.radar_rounded,
                            label: 'Показать все BLE рядом',
                            onTap: _scanningHeart
                                ? null
                                : () =>
                                    _scanHeartRate(showAllBleCandidates: true)),
                      );
                    }
                    return polarDeviceRow(devices[index]);
                  },
                );
              },
            ),
          ),
        ]),
      );
    }

    Widget activeDevicePane({required bool compact}) {
      return _deviceWorkspaceTab == 0
          ? gpsDevicesPanel(compact: compact)
          : heartRatePanel(compact: compact);
    }

    Widget rosterCard({required bool compact}) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: _DarkCard(
          title: 'Игроки команды (${_players.length})',
          subtitle: 'выберите игрока для назначения устройства',
          child: _players.isEmpty
              ? const _DarkEmpty(
                  icon: Icons.groups_rounded, text: 'Игроки не загружены.')
              : ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: _players.length + 1,
                  itemBuilder: (context, index) {
                    if (index == _players.length) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _DarkActionButton(
                            icon: Icons.groups_rounded,
                            label: 'Все игроки',
                            onTap: () {}),
                      );
                    }
                    final p = _players[index];
                    return _DarkListTile(
                      icon: Icons.person_rounded,
                      avatarUrl: p.avatar,
                      initials: _playerInitials(p.name),
                      title: p.name,
                      subtitle: p.position == null || p.position!.trim().isEmpty
                          ? _equipmentStatusForPlayer(p)
                          : '${p.position} · ${_equipmentStatusForPlayer(p)}',
                      active: _selectedPlayer?.id == p.id,
                      trailing: p.number == null ? null : '#${p.number}',
                      onTap: () => setState(() {
                        _selectedPlayer = p;
                        _deviceWorkspaceDetailsOpen = true;
                      }),
                    );
                  },
                ),
        ),
      );
    }

    Future<void> openMobileMoreSheet() async {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
            child: ClipRRect(
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(_TD.sheetRadius)),
              child: Material(
                color: _TD.panel,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(children: [
                          const Expanded(
                              child: Text('Действия',
                                  style: TextStyle(
                                      color: _TD.text,
                                      fontSize: 15.4,
                                      fontWeight: FontWeight.w700))),
                          _SheetCloseButton(
                              onTap: () => Navigator.of(sheetContext).pop()),
                        ]),
                        const SizedBox(height: 4),
                        _DarkActionButton(
                            icon: Icons.inventory_2_rounded,
                            label: 'Архив привязок',
                            onTap: () {
                              Navigator.of(sheetContext).pop();
                              _openBindingsArchiveSheet();
                            }),
                        const SizedBox(height: 8),
                        _DarkActionButton(
                            icon: Icons.auto_awesome_motion_rounded,
                            label: 'Автоназначение',
                            onTap: () {
                              Navigator.of(sheetContext).pop();
                              _openTeamEquipmentModal();
                            }),
                        const SizedBox(height: 8),
                        _DarkActionButton(
                            icon: Icons.restart_alt_rounded,
                            label: 'Сброс BLE',
                            onTap: () {
                              Navigator.of(sheetContext).pop();
                              _resetBleState();
                            }),
                        const SizedBox(height: 8),
                        _DarkActionButton(
                            icon: Icons.refresh_rounded,
                            label: 'Обновить',
                            onTap: () {
                              Navigator.of(sheetContext).pop();
                              _loadServerData();
                              _loadRemoteDebugLogs(silent: true);
                            }),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    Future<void> openMobilePlayerPickerSheet() async {
      String query = '';
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          return StatefulBuilder(builder: (context, setSheetState) {
            final q = query.trim().toLowerCase();
            final filtered = q.isEmpty
                ? _players
                : _players
                    .where((p) =>
                        p.name.toLowerCase().contains(q) ||
                        (p.number?.toString().contains(q) ?? false) ||
                        (p.position?.toLowerCase().contains(q) ?? false))
                    .toList(growable: false);
            return FractionallySizedBox(
              heightFactor: .88,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.vertical(
                      top: Radius.circular(_TD.sheetRadius)),
                  child: Material(
                    color: _TD.panel,
                    child: SafeArea(
                      top: false,
                      child: Column(children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 10, 8, 8),
                          child: Row(children: [
                            const Icon(Icons.groups_rounded,
                                color: _TD.green, size: 20),
                            const SizedBox(width: 8),
                            const Expanded(
                                child: Text('Выберите игрока',
                                    style: TextStyle(
                                        color: _TD.text,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700))),
                            _SheetCloseButton(
                                onTap: () => Navigator.of(sheetContext).pop()),
                          ]),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                          child: TextField(
                            autofocus: false,
                            onChanged: (v) => setSheetState(() => query = v),
                            decoration: InputDecoration(
                              hintText: 'Поиск игрока',
                              prefixIcon:
                                  const Icon(Icons.search_rounded, size: 18),
                              isDense: true,
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                      _TD.interactiveRadius),
                                  borderSide: const BorderSide(
                                      color: _TD.borderStrong)),
                              enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                      _TD.interactiveRadius),
                                  borderSide: const BorderSide(
                                      color: _TD.borderStrong)),
                              focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(
                                      _TD.interactiveRadius),
                                  borderSide:
                                      const BorderSide(color: _TD.green)),
                            ),
                          ),
                        ),
                        const _WorkspacePaneDivider.horizontal(),
                        Expanded(
                          child: filtered.isEmpty
                              ? const _DarkEmpty(
                                  icon: Icons.person_search_rounded,
                                  text: 'Игрок не найден.')
                              : ListView.builder(
                                  padding:
                                      const EdgeInsets.fromLTRB(14, 10, 14, 14),
                                  itemCount: filtered.length,
                                  itemBuilder: (context, index) {
                                    final p = filtered[index];
                                    return _DarkListTile(
                                      icon: Icons.person_rounded,
                                      avatarUrl: p.avatar,
                                      initials: _playerInitials(p.name),
                                      title: p.name,
                                      subtitle: p.position == null ||
                                              p.position!.trim().isEmpty
                                          ? _equipmentStatusForPlayer(p)
                                          : '${p.position} · ${_equipmentStatusForPlayer(p)}',
                                      active: _selectedPlayer?.id == p.id,
                                      trailing: p.number == null
                                          ? null
                                          : '#${p.number}',
                                      onTap: () {
                                        setState(() {
                                          _selectedPlayer = p;
                                          _deviceWorkspaceDetailsOpen = true;
                                        });
                                        Navigator.of(sheetContext).pop();
                                      },
                                    );
                                  },
                                ),
                        ),
                      ]),
                    ),
                  ),
                ),
              ),
            );
          });
        },
      );
    }

    Future<void> openMobileDevicePickerSheet({required int tab}) async {
      final previousTab = _deviceWorkspaceTab;
      _deviceWorkspaceTab = tab;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          return FractionallySizedBox(
            heightFactor: .92,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.vertical(
                    top: Radius.circular(_TD.sheetRadius)),
                child: Material(
                  color: _TD.panel,
                  child: Column(children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 8, 8),
                      child: Row(children: [
                        Icon(
                            tab == 0
                                ? Icons.sensors_rounded
                                : Icons.favorite_rounded,
                            color: _TD.green,
                            size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    tab == 0
                                        ? 'Подключить GPS-трекер'
                                        : 'Подключить Polar H10',
                                    style: const TextStyle(
                                        color: _TD.text,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700)),
                                Text(
                                    _selectedPlayer == null
                                        ? 'сначала выберите игрока'
                                        : 'игрок: ${_selectedPlayer!.name}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: _TD.muted,
                                        fontSize: 11.2,
                                        fontWeight: FontWeight.w700)),
                              ]),
                        ),
                        _SheetCloseButton(
                            onTap: () => Navigator.of(sheetContext).pop()),
                      ]),
                    ),
                    const _WorkspacePaneDivider.horizontal(),
                    Expanded(child: activeDevicePane(compact: true)),
                  ]),
                ),
              ),
            ),
          );
        },
      );
      if (mounted && _deviceWorkspaceTab != previousTab) {
        setState(() => _deviceWorkspaceTab = previousTab);
      }
    }

    Widget mobileQuickActions() {
      Widget connectChip({
        required IconData icon,
        required String title,
        required String caption,
        required bool primary,
        required VoidCallback onTap,
      }) {
        final fg = primary ? Colors.white : _TD.greenDark;
        final sub = primary ? Colors.white.withOpacity(.82) : _TD.dim;
        return Expanded(
          child: _NoHoverTap(
            borderRadius: BorderRadius.circular(_TD.interactiveRadius),
            onTap: onTap,
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: primary ? _TD.green : _TD.greenSoft,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                    color: primary ? _TD.green : _TD.greenBorder, width: .85),
                boxShadow: primary
                    ? [
                        BoxShadow(
                            color: _TD.green.withOpacity(.08),
                            blurRadius: 14,
                            spreadRadius: -9,
                            offset: const Offset(0, 7))
                      ]
                    : null,
              ),
              child: Row(children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                      color: primary
                          ? Colors.white.withOpacity(.08)
                          : Colors.white,
                      shape: BoxShape.circle),
                  child: Icon(icon, color: fg, size: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: fg,
                                fontSize: 11.4,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 1),
                        Text(caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: sub,
                                fontSize: 11.0,
                                fontWeight: FontWeight.w700)),
                      ]),
                ),
              ]),
            ),
          ),
        );
      }

      Widget iconChip(
          {required IconData icon,
          required String label,
          required VoidCallback onTap}) {
        return _NoHoverTap(
          borderRadius: BorderRadius.circular(_TD.interactiveRadius),
          onTap: onTap,
          child: Container(
            width: 48,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _TD.border.withOpacity(.65), width: .7),
            ),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, color: _TD.graphite, size: 17),
              const SizedBox(height: 3),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: _TD.graphite,
                      fontSize: 11.0,
                      fontWeight: FontWeight.w700)),
            ]),
          ),
        );
      }

      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_TD.tabletCardRadius),
          ),
          child: Row(children: [
            connectChip(
                icon: Icons.sensors_rounded,
                title: 'GPS',
                caption: 'рядом',
                primary: true,
                onTap: () => unawaited(openMobileDevicePickerSheet(tab: 0))),
            const SizedBox(width: 8),
            connectChip(
                icon: Icons.favorite_rounded,
                title: 'Polar',
                caption: 'рядом',
                primary: false,
                onTap: () => unawaited(openMobileDevicePickerSheet(tab: 1))),
            const SizedBox(width: 8),
            iconChip(
                icon: Icons.radar_rounded,
                label: 'BLE',
                onTap: () => unawaited(
                    openMobileDevicePickerSheet(tab: _deviceWorkspaceTab))),
            const SizedBox(width: 8),
            iconChip(
                icon: Icons.more_horiz_rounded,
                label: 'Ещё',
                onTap: () => unawaited(openMobileMoreSheet())),
          ]),
        ),
      );
    }

    Widget mobileSelectedPlayerCard() {
      final p = _selectedPlayer;
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: _NoHoverTap(
          borderRadius: BorderRadius.circular(_TD.interactiveRadius),
          onTap: () => unawaited(openMobilePlayerPickerSheet()),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: p == null ? Colors.white : _TD.greenSoft,
                borderRadius: BorderRadius.circular(_TD.interactiveRadius),
                border: Border.all(
                    color: p == null ? _TD.borderStrong : _TD.greenBorder,
                    width: .85)),
            child: Row(children: [
              p == null
                  ? Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                          color: _TD.soft2, shape: BoxShape.circle),
                      child: const Icon(Icons.person_search_rounded,
                          color: _TD.muted))
                  : _PlayerAvatarDark(
                      url: p.avatar,
                      initials: _playerInitials(p.name),
                      size: 48,
                      active: true),
              const SizedBox(width: 9),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(p == null ? 'Игрок не выбран' : p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: _TD.text,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(
                        p == null
                            ? 'Нажмите, чтобы выбрать игрока'
                            : (p.number == null
                                ? _equipmentStatusForPlayer(p)
                                : '#${p.number} · ${p.position ?? 'игрок'} · ${_equipmentStatusForPlayer(p)}'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: _TD.muted,
                            fontSize: 11.2,
                            fontWeight: FontWeight.w700)),
                  ])),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(_TD.mobileCardRadius)),
                child: Text(p == null ? 'Выбрать' : 'Сменить',
                    style: const TextStyle(
                        color: _TD.text,
                        fontSize: 11.2,
                        fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
        ),
      );
    }

    Widget assignedDeviceCard({
      required IconData icon,
      required String title,
      required String deviceName,
      required String deviceId,
      required bool connected,
      required int? battery,
      int? rssi,
      required VoidCallback? onRefresh,
      required VoidCallback? onReplace,
      required VoidCallback? onRemove,
    }) {
      Widget statusPill() {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
              color: connected ? _TD.greenSoft : _TD.soft2,
              borderRadius: BorderRadius.circular(_TD.mobileCardRadius)),
          child: Text(connected ? 'Подключен' : 'Назначен',
              style: TextStyle(
                  color: connected ? _TD.green : _TD.muted,
                  fontSize: 10.4,
                  fontWeight: FontWeight.w700)),
        );
      }

      Widget deviceInfo() {
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(deviceName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: _TD.text,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(deviceId,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: _TD.muted,
                  fontSize: 11.0,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Row(children: [
            Icon(Icons.circle,
                size: 7, color: connected ? _TD.green : _TD.muted),
            const SizedBox(width: 4),
            Text(connected ? 'Подключен' : 'Ожидает подключения',
                style: TextStyle(
                    color: connected ? _TD.green : _TD.muted,
                    fontSize: 11.0,
                    fontWeight: FontWeight.w700)),
          ]),
        ]);
      }

      Widget actionsRow({bool withLabels = false}) {
        if (!withLabels) {
          return Row(mainAxisSize: MainAxisSize.min, children: [
            _TinyIconAction(icon: Icons.refresh_rounded, onTap: onRefresh),
            const SizedBox(width: 4),
            _TinyIconAction(icon: Icons.swap_horiz_rounded, onTap: onReplace),
            const SizedBox(width: 4),
            _TinyIconAction(icon: Icons.close_rounded, onTap: onRemove),
          ]);
        }
        return Row(children: [
          Expanded(
              child: _DarkActionButton(
                  icon: Icons.refresh_rounded,
                  label: 'Обновить',
                  onTap: onRefresh)),
          const SizedBox(width: 6),
          Expanded(
              child: _DarkActionButton(
                  icon: Icons.swap_horiz_rounded,
                  label:
                      title.contains('GPS') ? 'Заменить GPS' : 'Заменить Polar',
                  onTap: onReplace)),
          const SizedBox(width: 6),
          _TinyIconAction(icon: Icons.close_rounded, onTap: onRemove),
        ]);
      }

      return LayoutBuilder(builder: (context, constraints) {
        final narrow = constraints.maxWidth < 390;
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(_TD.interactiveRadius)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(
                  child: Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: _TD.text,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700))),
              const SizedBox(width: 8),
              statusPill(),
            ]),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: _TD.soft,
                  borderRadius: BorderRadius.circular(_TD.interactiveRadius)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                              width: 38,
                              height: 38,
                              decoration: const BoxDecoration(
                                  color: Colors.white, shape: BoxShape.circle),
                              child: Icon(icon, color: _TD.text, size: 20)),
                          const SizedBox(width: 10),
                          Expanded(child: deviceInfo()),
                          if (!narrow) ...[
                            if (battery != null) ...[
                              const SizedBox(width: 8),
                              batteryPill(battery),
                            ],
                            if (rssi != null) ...[
                              const SizedBox(width: 8),
                              signalIcon(rssi),
                            ],
                            const SizedBox(width: 6),
                            actionsRow(),
                          ],
                        ]),
                    if (narrow) ...[
                      const SizedBox(height: 10),
                      Row(children: [
                        if (battery != null) ...[
                          batteryPill(battery),
                          const SizedBox(width: 10),
                        ],
                        if (rssi != null) ...[
                          signalIcon(rssi),
                          const SizedBox(width: 10),
                        ],
                        Expanded(child: actionsRow(withLabels: true)),
                      ]),
                    ],
                  ]),
            ),
            const SizedBox(height: 8),
            _DarkActionButton(
                icon: icon,
                label: title.contains('GPS')
                    ? 'Заменить GPS-трекер'
                    : 'Заменить Polar H10',
                onTap: onReplace),
          ]),
        );
      });
    }

    Widget playerDetailsPanel({required bool compact}) {
      final p = _selectedPlayer;
      if (p == null) {
        return Padding(
          padding: const EdgeInsets.all(8),
          child: _DarkCard(
            title: 'Карточка игрока',
            subtitle: 'выберите игрока',
            child: const _DarkEmpty(
                icon: Icons.person_search_rounded,
                text:
                    'Сначала выберите игрока в средней колонке. Потом нажмите «+» у GPS или Polar слева, чтобы подключить и назначить устройство.'),
          ),
        );
      }

      final gps = _gpsDevicesForPlayer(p.id);
      final gpsDevice = gps.isEmpty ? null : gps.first;
      final connectedGps =
          gpsDevice == null ? null : _connectedTeamTrackerForSaved(gpsDevice);
      final selectedHeartEntries = _heartDevicePlayerIds.entries
          .where((e) => e.value == p.id)
          .toList(growable: false);
      final liveHeartId =
          selectedHeartEntries.isEmpty ? null : selectedHeartEntries.first.key;
      final liveHeartDevice =
          liveHeartId == null ? null : _heart.connectedDevice(liveHeartId);
      final liveHeartSample =
          liveHeartId == null ? null : _heart.lastSampleForDevice(liveHeartId);
      TrackerDeviceModel? savedHeart;
      for (final d in _savedDevices
          .where((d) => d.playerId == p.id && _isHeartRateDeviceModel(d))) {
        savedHeart = d;
        break;
      }
      final hasHeart = liveHeartDevice != null || savedHeart != null;

      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: _DarkCard(
          title: p.name,
          subtitle: p.number == null
              ? (p.position ?? 'игрок команды')
              : '#${p.number} · ${p.position ?? 'игрок команды'}',
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _TD.greenSoft,
                  borderRadius: BorderRadius.circular(_TD.interactiveRadius),
                ),
                child: Row(children: [
                  _PlayerAvatarDark(
                      url: p.avatar,
                      initials: _playerInitials(p.name),
                      size: 52,
                      active: true),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(p.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: _TD.text,
                                fontSize: 17,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 3),
                        Text(_equipmentStatusForPlayer(p),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: _TD.text,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                      ])),
                  Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(_TD.mobileCardRadius)),
                      child: const Text('Активен',
                          style: TextStyle(
                              color: _TD.green,
                              fontSize: 11.2,
                              fontWeight: FontWeight.w700))),
                ]),
              ),
              const SizedBox(height: 8),
              const Text('Назначенные устройства',
                  style: TextStyle(
                      color: _TD.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              if (gpsDevice == null)
                Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _DarkHint(
                          text: compact
                              ? 'GPS не назначен.'
                              : 'GPS не назначен. Выберите вкладку GPS слева и нажмите «+» у нужного трекера — он подключится к ${p.name}.'),
                      const SizedBox(height: 8),
                      _DarkActionButton(
                          icon: Icons.sensors_rounded,
                          label: 'Назначить GPS',
                          primary: true,
                          onTap: compact
                              ? () =>
                                  unawaited(openMobileDevicePickerSheet(tab: 0))
                              : () => setState(() => _deviceWorkspaceTab = 0)),
                    ])
              else
                assignedDeviceCard(
                  icon: Icons.sensors_rounded,
                  title: 'GPS-трекер',
                  deviceName: gpsDevice.deviceName,
                  deviceId: gpsDevice.deviceUuid,
                  connected: connectedGps != null,
                  battery: gpsDevice.batteryPercent ??
                      (connectedGps != null ? _batteryPercent : null),
                  rssi: null,
                  onRefresh: () {
                    if (connectedGps != null) {
                      unawaited(
                          _teamBlePool.requestCurrentGps(connectedGps.id));
                    } else {
                      _scan(universalMode: true);
                    }
                  },
                  onReplace: compact
                      ? () => unawaited(openMobileDevicePickerSheet(tab: 0))
                      : () => setState(() => _deviceWorkspaceTab = 0),
                  onRemove: () => _assignTrackerDeviceToPlayer(gpsDevice, null),
                ),
              const SizedBox(height: 10),
              if (!hasHeart)
                Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _DarkHint(
                          text: compact
                              ? 'Polar H10 не назначен.'
                              : 'Polar H10 не назначен. Перейдите во вкладку Polar H10 слева и нажмите «+» у нужного пульсометра.'),
                      const SizedBox(height: 8),
                      _DarkActionButton(
                          icon: Icons.favorite_rounded,
                          label: 'Назначить Polar',
                          primary: true,
                          onTap: compact
                              ? () =>
                                  unawaited(openMobileDevicePickerSheet(tab: 1))
                              : () => setState(() => _deviceWorkspaceTab = 1)),
                    ])
              else
                assignedDeviceCard(
                  icon: Icons.favorite_rounded,
                  title: 'Polar H10 пульсометр',
                  deviceName: liveHeartDevice?.name ??
                      savedHeart?.deviceName ??
                      'Polar H10',
                  deviceId: liveHeartDevice?.id ?? savedHeart?.deviceUuid ?? '',
                  connected: liveHeartDevice != null,
                  battery: liveHeartSample?.batteryPercent ??
                      savedHeart?.batteryPercent,
                  rssi: liveHeartDevice == null ? null : 0,
                  onRefresh: () => _scanHeartRate(),
                  onReplace: compact
                      ? () => unawaited(openMobileDevicePickerSheet(tab: 1))
                      : () => setState(() => _deviceWorkspaceTab = 1),
                  onRemove: () {
                    if (liveHeartDevice != null)
                      _bindHeartRateDeviceToPlayer(liveHeartDevice, null);
                    if (savedHeart != null)
                      _assignTrackerDeviceToPlayer(savedHeart!, null);
                  },
                ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: _TD.soft,
                    borderRadius: BorderRadius.circular(_TD.interactiveRadius)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Информация об игроке',
                          style: TextStyle(
                              color: _TD.text,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      _InfoRow(label: 'Позиция', value: p.position ?? '—'),
                      _InfoRow(
                          label: 'Номер',
                          value: p.number == null ? '—' : '#${p.number}'),
                      _InfoRow(label: 'Команда', value: 'U${widget.teamId}'),
                    ]),
              ),
              const SizedBox(height: 8),
              _DarkActionButton(
                  icon: Icons.delete_outline_rounded,
                  label: 'Снять все назначения',
                  onTap: () {
                    if (gpsDevice != null)
                      _assignTrackerDeviceToPlayer(gpsDevice, null);
                    if (liveHeartDevice != null)
                      _bindHeartRateDeviceToPlayer(liveHeartDevice, null);
                    if (savedHeart != null)
                      _assignTrackerDeviceToPlayer(savedHeart!, null);
                  }),
            ],
          ),
        ),
      );
    }

    Future<void> openMobilePlayerDetailsSheet() async {
      final playerForSheet = _selectedPlayer;
      if (playerForSheet == null) {
        await openMobilePlayerPickerSheet();
        return;
      }
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          return FractionallySizedBox(
            heightFactor: .92,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.vertical(
                    top: Radius.circular(_TD.sheetRadius)),
                child: Material(
                  color: _TD.panel,
                  child: Column(children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 8, 8),
                      child: Row(children: [
                        const Icon(Icons.person_rounded,
                            color: _TD.green, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(playerForSheet.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: _TD.text,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700))),
                        _SheetCloseButton(
                            onTap: () => Navigator.of(sheetContext).pop()),
                      ]),
                    ),
                    const _WorkspacePaneDivider.horizontal(),
                    Expanded(child: playerDetailsPanel(compact: true)),
                  ]),
                ),
              ),
            ),
          );
        },
      );
    }

    Widget mobileAssignedDevicesPreview() {
      final p = _selectedPlayer;
      if (p == null) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: _DarkCard(
            title: 'Назначенные устройства',
            subtitle: 'выберите игрока',
            child: const _DarkHint(
                text: 'Выберите игрока для назначения устройства.'),
          ),
        );
      }
      final gps = _gpsDevicesForPlayer(p.id);
      final gpsDevice = gps.isEmpty ? null : gps.first;
      final selectedHeartEntries = _heartDevicePlayerIds.entries
          .where((e) => e.value == p.id)
          .toList(growable: false);
      final liveHeartId =
          selectedHeartEntries.isEmpty ? null : selectedHeartEntries.first.key;
      final liveHeartDevice =
          liveHeartId == null ? null : _heart.connectedDevice(liveHeartId);
      TrackerDeviceModel? savedHeart;
      for (final d in _savedDevices
          .where((d) => d.playerId == p.id && _isHeartRateDeviceModel(d))) {
        savedHeart = d;
        break;
      }

      Widget miniRow(
          {required IconData icon,
          required String title,
          required String value,
          required bool ok,
          required VoidCallback onTap}) {
        return _NoHoverTap(
          borderRadius: BorderRadius.circular(_TD.interactiveRadius),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(_TD.interactiveRadius)),
            child: Row(children: [
              Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                      color: _TD.soft, shape: BoxShape.circle),
                  child:
                      Icon(icon, color: ok ? _TD.green : _TD.muted, size: 18)),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Row(children: [
                      Text(title,
                          style: const TextStyle(
                              color: _TD.text,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(width: 6),
                      Icon(Icons.circle,
                          size: 7, color: ok ? _TD.green : _TD.muted),
                    ]),
                    const SizedBox(height: 3),
                    Text(value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: _TD.muted,
                            fontSize: 11.2,
                            fontWeight: FontWeight.w700)),
                  ])),
              const Icon(Icons.chevron_right_rounded, color: _TD.muted),
            ]),
          ),
        );
      }

      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: _DarkCard(
          title: 'Назначенные устройства',
          subtitle: 'нажмите карточку для управления',
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            miniRow(
              icon: Icons.sensors_rounded,
              title: 'GPS',
              value: gpsDevice == null ? 'не назначен' : gpsDevice.deviceName,
              ok: gpsDevice != null,
              onTap: () => unawaited(openMobilePlayerDetailsSheet()),
            ),
            const SizedBox(height: 8),
            miniRow(
              icon: Icons.favorite_rounded,
              title: 'Polar H10',
              value: (liveHeartDevice?.name ?? savedHeart?.deviceName) == null
                  ? 'не назначен'
                  : (liveHeartDevice?.name ?? savedHeart!.deviceName),
              ok: liveHeartDevice != null || savedHeart != null,
              onTap: () => unawaited(openMobilePlayerDetailsSheet()),
            ),
            const SizedBox(height: 10),
            _DarkActionButton(
                icon: Icons.tune_rounded,
                label: 'Управлять устройствами игрока',
                onTap: () => unawaited(openMobilePlayerDetailsSheet())),
          ]),
        ),
      );
    }

    Widget legend() {
      Widget item(Widget icon, String text) =>
          Row(mainAxisSize: MainAxisSize.min, children: [
            icon,
            const SizedBox(width: 7),
            Text(text,
                style: const TextStyle(
                    color: _TD.text,
                    fontSize: 11.2,
                    fontWeight: FontWeight.w700))
          ]);
      return Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_TD.interactiveRadius)),
        child: Wrap(spacing: 22, runSpacing: 10, children: [
          item(batteryPill(80), '> 70%'),
          item(batteryPill(50), '30–70%'),
          item(batteryPill(20), '< 30%'),
          item(signalIcon(-55), 'сильный сигнал'),
          item(signalIcon(-72), 'средний сигнал'),
          item(
              Row(mainAxisSize: MainAxisSize.min, children: const [
                Icon(Icons.circle, size: 9, color: _TD.green)
              ]),
              'подключен'),
          item(
              Row(mainAxisSize: MainAxisSize.min, children: const [
                Icon(Icons.circle, size: 9, color: _TD.muted)
              ]),
              'не назначен'),
        ]),
      );
    }

    return _DarkPage(
      title: 'Датчики',
      subtitle: 'Назначение GPS и Polar игрокам',
      icon: Icons.sensors_rounded,
      child: LayoutBuilder(builder: (context, constraints) {
        final compact = constraints.maxWidth < 820;
        if (compact) {
          // На мобильном этот экран часто оказывается внутри внешнего scroll/sliver
          // контейнера рабочего пространства. Обычный ListView здесь может получить
          // небезопасные ограничения и упасть на sliver_multi_box_adaptor child.hasSize.
          // Поэтому мобильную ленту рисуем как обычную колонку внутри
          // SingleChildScrollView: карточек мало, виртуализация не нужна.
          return SingleChildScrollView(
            padding: EdgeInsets.zero,
            physics: const ClampingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                mobileQuickActions(),
                mobileSelectedPlayerCard(),
                mobileAssignedDevicesPreview(),
              ],
            ),
          );
        }

        final tablet = constraints.maxWidth < 1180;
        final leftFlex = tablet ? 33 : 36;
        final rosterFlex = tablet ? 31 : 34;
        final detailsFlex = tablet ? 38 : 43;

        return Column(children: [
          topActionBar(compact: tablet),
          Expanded(
            child: Row(children: [
              Expanded(
                  flex: leftFlex, child: activeDevicePane(compact: tablet)),
              const _WorkspacePaneDivider.vertical(),
              Expanded(flex: rosterFlex, child: rosterCard(compact: tablet)),
              const _WorkspacePaneDivider.vertical(),
              Expanded(
                  flex: detailsFlex,
                  child: playerDetailsPanel(compact: tablet)),
            ]),
          ),
          if (!tablet) legend(),
        ]);
      }),
    );
  }

  void _openBindingsArchiveSheet() {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return FractionallySizedBox(
          heightFactor: .86,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_TD.tabletCardRadius),
              child: Material(
                color: _TD.panel,
                child: Column(children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
                    child: Row(children: [
                      const Icon(Icons.inventory_2_rounded, color: _TD.green),
                      const SizedBox(width: 8),
                      const Expanded(
                          child: Text('Архив привязок',
                              style: TextStyle(
                                  color: _TD.text,
                                  fontSize: 15.4,
                                  fontWeight: FontWeight.w700))),
                      _SheetCloseButton(
                          onTap: () => Navigator.of(sheetContext).pop()),
                    ]),
                  ),
                  const _WorkspacePaneDivider.horizontal(),
                  Expanded(
                    child: _hideSavedDevices
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const _DarkEmpty(
                                        icon: Icons.visibility_off_rounded,
                                        text:
                                            'Архив скрыт, чтобы не путать старые записи с живым BLE-подключением.'),
                                    const SizedBox(height: 8),
                                    _DarkActionButton(
                                        icon: Icons.visibility_rounded,
                                        label: 'Показать архив',
                                        primary: true,
                                        onTap: () => setState(
                                            () => _hideSavedDevices = false)),
                                  ]),
                            ),
                          )
                        : (_mergedSavedDevices.isEmpty
                            ? const _DarkEmpty(
                                icon: Icons.sensors_off_rounded,
                                text:
                                    'После подключения или привязки датчик появится здесь.')
                            : ListView.builder(
                                padding: const EdgeInsets.all(10),
                                itemCount: _mergedSavedDevices.length,
                                itemBuilder: (context, index) {
                                  final d = _mergedSavedDevices[index];
                                  return _SavedDeviceDarkTile(
                                      device: d,
                                      players: _players,
                                      onBind: (p) => _bindSavedDevice(d, p),
                                      onForget: () => _forgetSavedDevice(d),
                                      aliasCount: _savedDeviceAliasCount(d),
                                      status: _savedDeviceStatus(d),
                                      statusColor: _savedDeviceStatusColor(d));
                                },
                              )),
                  ),
                ]),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _heatmap() {
    return _DarkPage(
      title: 'Теплокарта / карта спринтов',
      subtitle: 'зоны активности, HIR/VHIR, интенсивность и карта покрытия',
      icon: Icons.local_fire_department_rounded,
      trailing: _DarkActionButton(
          icon: Icons.refresh_rounded,
          label: 'Обновить',
          onTap: () => setState(() {})),
      child: FutureBuilder<List<TrackerHeatPoint>>(
        future: _api.loadHeatmap(
            teamId: widget.teamId, playerId: null, fieldId: _selectedField?.id),
        builder: (context, snapshot) {
          final points = snapshot.data ?? const <TrackerHeatPoint>[];
          if (snapshot.connectionState == ConnectionState.waiting &&
              snapshot.data == null)
            return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError)
            return _DarkError(
                error: '${snapshot.error}', onRetry: () => setState(() {}));

          Widget mapCard() => _DarkCard(
                title: 'Теплокарта поля',
                subtitle:
                    points.isEmpty ? 'нет точек' : '${points.length} точек',
                child: CustomPaint(
                    painter: _DarkHeatmapPainter(points: points),
                    child: const SizedBox.expand()),
              );
          Widget filtersCard() => _DarkCard(
                title: 'Фильтры',
                subtitle: _selectedPlayer?.name ?? 'team',
                child: Column(children: [
                  _DarkMetricTile(
                      icon: Icons.person_rounded,
                      title: 'Игрок',
                      value: _selectedPlayer?.name ?? 'All',
                      subtitle: 'фильтр'),
                  const SizedBox(height: 4),
                  _DarkMetricTile(
                      icon: Icons.map_rounded,
                      title: 'Поле',
                      value: _selectedField?.title ?? 'None',
                      subtitle: _selectedField?.hasCalibration == true
                          ? 'откалибровано'
                          : 'нужны углы'),
                  const SizedBox(height: 4),
                  _DarkMetricTile(
                      icon: Icons.local_fire_department_rounded,
                      title: 'Точки теплокарты',
                      value: '${points.length}',
                      subtitle: 'показано'),
                  const Spacer(),
                  const _DarkHint(
                      text:
                          'Здесь можно переключать карта спринтов / карта ускорений / зоны усталости / теплокарта.'),
                ]),
              );

          return LayoutBuilder(builder: (context, constraints) {
            final compact = constraints.maxWidth < 1180;
            if (compact) {
              return ListView(
                padding: EdgeInsets.zero,
                children: [
                  SizedBox(
                      height: math.max(280.0, constraints.maxWidth * .62),
                      child: mapCard()),
                  const _WorkspacePaneDivider.horizontal(),
                  SizedBox(height: 260, child: filtersCard()),
                ],
              );
            }
            return Row(children: [
              Expanded(flex: 8, child: mapCard()),
              const _WorkspacePaneDivider.vertical(),
              Expanded(flex: 3, child: filtersCard()),
            ]);
          });
        },
      ),
    );
  }

  Widget _trackerSignalBanner({bool compact = false}) {
    final packetAge = _lastTrackerPacketAt == null
        ? null
        : DateTime.now().difference(_lastTrackerPacketAt!).inSeconds;
    final gpsAge = _lastWorkspaceGpsAt == null
        ? null
        : DateTime.now().difference(_lastWorkspaceGpsAt!).inSeconds;
    final bleConnected = _hasAnyGpsCommandChannel;
    final trackerActive = bleConnected && packetAge != null && packetAge < 20;
    final gpsActive = bleConnected && gpsAge != null && gpsAge < 20;
    final title = !bleConnected
        ? 'Командные GPS не подключены'
        : (trackerActive
            ? 'Трекер передаёт данные'
            : 'Нет свежих пакетов от трекера');
    final subtitle = !bleConnected
        ? 'Выберите игрока и назначьте ему GPS. Повторный поиск не отключает уже подключённые каналы.'
        : (gpsActive
            ? 'GPS: $_lastWorkspaceGps · ${gpsAge}s назад · точек=${_points.length}'
            : 'Подключено GPS: ${_teamBlePool.connectedCount} · данные поступают по отдельным командным каналам');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: trackerActive
            ? _TD.green.withOpacity(.10)
            : _TD.orange.withOpacity(.10),
        borderRadius: BorderRadius.circular(_TD.interactiveRadius),
      ),
      child: Row(children: [
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: .65, end: 1),
          duration: const Duration(milliseconds: 680),
          builder: (context, v, child) =>
              Transform.scale(scale: trackerActive ? v : 1, child: child),
          child: Icon(
              trackerActive ? Icons.sensors_rounded : Icons.sensors_off_rounded,
              color: trackerActive ? _TD.green : _TD.orange,
              size: compact ? 16 : 18),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: _TD.text,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(subtitle,
                    maxLines: compact ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: _TD.muted,
                        fontSize: 11.0,
                        fontWeight: FontWeight.w600)),
              ]),
        ),
        const SizedBox(width: 4),
        _MiniDebugPill(
            label:
                !bleConnected ? 'BLE off' : (gpsActive ? 'GPS OK' : 'GPS нет'),
            active: gpsActive),
      ]),
    );
  }

  Widget _calibrationFieldPreview(
    int nextIndex, {
    List<ActionTrackerGpsPoint>? corners,
    bool saved = false,
  }) {
    final drawCorners = corners ?? _calibrationCorners;
    return Stack(
      children: [
        CustomPaint(
          painter: _DarkCalibrationPainter(
            corners: drawCorners,
            activeIndex: saved
                ? -1
                : (_calibrationCapturing
                    ? (_calibrationCapturingIndex ?? nextIndex)
                    : nextIndex),
            capturing: _calibrationCapturing,
          ),
          child: const SizedBox.expand(),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              child: _calibrationFlashLabel == null
                  ? const SizedBox.shrink()
                  : Center(
                      key: ValueKey(_calibrationFlashSeed),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 950),
                        builder: (context, v, child) {
                          final opacity = v < .72
                              ? 1.0
                              : (1.0 - ((v - .72) / .28)).clamp(0.0, 1.0);
                          return Opacity(
                            opacity: opacity,
                            child: Transform.scale(
                              scale: .72 + v * .42,
                              child: child,
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 11),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(.08),
                                  blurRadius: 14,
                                  offset: const Offset(0, 12))
                            ],
                            border:
                                Border.all(color: _TD.green.withOpacity(.38)),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.add_circle_rounded,
                                color: _TD.green, size: 22),
                            const SizedBox(width: 4),
                            Text('+ точка $_calibrationFlashLabel',
                                style: const TextStyle(
                                    color: _TD.text,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700)),
                          ]),
                        ),
                      ),
                    ),
            ),
          ),
        ),
        if (saved)
          Positioned(
            left: 12,
            top: 12,
            child: IgnorePointer(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.95),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _TD.green.withOpacity(.24)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(.08),
                        blurRadius: 14,
                        offset: const Offset(0, 6))
                  ],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: const [
                  Icon(Icons.check_circle_rounded, color: _TD.green, size: 16),
                  SizedBox(width: 6),
                  Text('Координаты сохранены',
                      style: TextStyle(
                          color: _TD.text,
                          fontSize: 11.2,
                          fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ),
        if (_calibrationCapturing)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: IgnorePointer(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.95),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(.06),
                        blurRadius: 18,
                        offset: const Offset(0, 8))
                  ],
                ),
                child: Row(children: const [
                  SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 8),
                  Expanded(
                      child: Text('Запрашиваю свежую GPS-точку у трекера...',
                          style: TextStyle(
                              color: _TD.text,
                              fontSize: 11.2,
                              fontWeight: FontWeight.w700))),
                ]),
              ),
            ),
          ),
      ],
    );
  }

  Widget _field() {
    final labels = const ['A', 'B', 'C', 'D'];
    final savedCorners = _savedFieldCalibrationCorners(_selectedField);
    final showingSavedCalibration =
        _calibrationCorners.isEmpty && savedCorners.length >= 4;
    final visibleCorners =
        showingSavedCalibration ? savedCorners : _calibrationCorners;
    final nextIndex = showingSavedCalibration
        ? -1
        : (_calibrationCorners.length >= 4 ? -1 : _calibrationCorners.length);
    final nextLabel = nextIndex < 0 ? 'готово' : labels[nextIndex];

    Widget fieldsCard() {
      return _DarkCard(
        title: 'Поля команды',
        subtitle: '${_fields.length} полей',
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _DarkActionButton(
                icon: Icons.add_rounded,
                label: 'Новое поле',
                onTap: _createNewFieldDraft),
            const SizedBox(height: 4),
            if (_selectedField?.id == null && _selectedField != null)
              _DarkListTile(
                icon: Icons.add_location_alt_rounded,
                title: _selectedField!.title,
                subtitle:
                    '${_selectedField!.lengthM.toStringAsFixed(0)}×${_selectedField!.widthM.toStringAsFixed(0)} м · черновик, нужны 4 точки',
                active: true,
                trailing: 'новое',
                onTap: () {},
              ),
            if (_fields.isEmpty && _selectedField == null)
              const _DarkEmpty(
                  icon: Icons.map_rounded,
                  text:
                      'Нажмите «Новое поле», затем поставьте 4 угла GPS-трекером.'),
            ..._fields.map((f) => _DarkListTile(
                  icon: f.hasCalibration
                      ? Icons.check_circle_rounded
                      : Icons.warning_amber_rounded,
                  title: f.title,
                  subtitle: f.hasCalibration
                      ? '${f.lengthM.toStringAsFixed(0)}×${f.widthM.toStringAsFixed(0)} м · откалибровано · ${_savedFieldCoordinateSubtitle(f)}'
                      : '${f.lengthM.toStringAsFixed(0)}×${f.widthM.toStringAsFixed(0)} м · нужна калибровка',
                  active: _selectedField?.id == f.id,
                  trailing: _selectedField?.id == f.id ? 'выбрано' : 'выбрать',
                  onTap: () => setState(() {
                    _selectedField = f;
                    _calibrationCorners.clear();
                  }),
                )),
          ],
        ),
      );
    }

    Widget calibrationCard({required bool compact}) {
      return _DarkCard(
        title: 'Калибровка по 4 точкам',
        subtitle: nextIndex < 0
            ? 'все точки получены'
            : 'следующая точка: $nextLabel',
        child: LayoutBuilder(builder: (context, constraints) {
          final previewHeight = compact
              ? math.max(180.0, math.min(270.0, constraints.maxWidth * .58))
              : math.max(230.0, constraints.maxHeight - 210.0);
          return SingleChildScrollView(
            child: Column(children: [
              _trackerSignalBanner(compact: compact),
              const SizedBox(height: 6),
              _CalibrationStatusBanner(
                nextLabel: nextLabel,
                done: nextIndex < 0,
                pointCount: visibleCorners.length,
                saved: showingSavedCalibration,
              ),
              if (compact) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _DarkActionButton(
                      icon: Icons.gps_fixed_rounded,
                      label: _calibrationCapturing
                          ? 'Жду GPS'
                          : (nextIndex < 0 ? 'GPS готов' : 'GPS $nextLabel'),
                      primary: true,
                      onTap: nextIndex < 0 || _calibrationCapturing
                          ? null
                          : _captureCalibrationPoint,
                    ),
                    _DarkActionButton(
                      icon: showingSavedCalibration
                          ? Icons.edit_location_alt_rounded
                          : Icons.restart_alt_rounded,
                      label: showingSavedCalibration
                          ? 'Перекалибровать'
                          : 'Сбросить',
                      onTap: showingSavedCalibration
                          ? _startRecalibrationCurrentField
                          : (_calibrationCorners.isEmpty
                              ? null
                              : _resetCalibrationCorners),
                    ),
                    _DarkActionButton(
                        icon: Icons.save_rounded,
                        label: 'Сохр.',
                        onTap: _calibrationCorners.length >= 4
                            ? _saveCapturedField
                            : null),
                  ],
                ),
              ],
              const SizedBox(height: 6),
              SizedBox(
                height: previewHeight,
                child: _calibrationFieldPreview(
                  nextIndex,
                  corners: visibleCorners,
                  saved: showingSavedCalibration,
                ),
              ),
              const SizedBox(height: 6),
              _DarkHint(
                text: showingSavedCalibration
                    ? 'Сохранённые координаты выбранного поля показаны ниже: A/B/C/D. Чтобы заменить их, нажмите «Перекалибровать». Последняя GPS-точка трекера: $_lastWorkspaceGps.'
                    : (_points.isEmpty
                        ? 'GPS-точек пока нет. Подключите трекер, выйдите на поле и дождитесь координат.'
                        : 'Последняя GPS-точка: $_lastWorkspaceGps. Нажмите ${nextIndex < 0 ? '«Сохранить»' : '«GPS $nextLabel»'} — приложение запросит свежий пакет и не даст сохранить дубль.'),
              ),
              const SizedBox(height: 6),
              Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: List.generate(4, (i) {
                    final ready = visibleCorners.length > i;
                    final active = !showingSavedCalibration &&
                        !ready &&
                        i == _calibrationCorners.length &&
                        _calibrationCorners.length < 4;
                    return _DarkCornerChip(
                      label: labels[i],
                      value: ready
                          ? _formatCalibrationCoordinate(visibleCorners[i])
                          : active
                              ? 'ожидает GPS'
                              : 'после предыдущей',
                      ready: ready,
                      active: active,
                      saved: showingSavedCalibration && ready,
                      onTap: showingSavedCalibration
                          ? null
                          : () => _handleCornerTap(i),
                    );
                  })),
              if (compact) const SizedBox(height: 8),
            ]),
          );
        }),
      );
    }

    return _DarkPage(
      title: 'Калибровка поля',
      subtitle:
          'создайте поле и пройдите углы GPS-трекером: A верхний левый → B верхний правый → C нижний правый → D нижний левый',
      icon: Icons.map_rounded,
      trailing: _TrackerToolbarScroller(children: [
        _DarkActionButton(
            icon: Icons.add_rounded,
            label: 'Новое поле',
            onTap: _createNewFieldDraft),
        _DarkActionButton(
            icon: Icons.delete_outline_rounded,
            label: 'Убрать поле',
            onTap: _selectedField == null ? null : _clearSelectedField),
        _DarkActionButton(
          icon: Icons.gps_fixed_rounded,
          label: _calibrationCapturing
              ? 'Жду GPS...'
              : (nextIndex < 0 ? 'GPS готов' : 'GPS $nextLabel'),
          primary: true,
          onTap: nextIndex < 0 || _calibrationCapturing
              ? null
              : _captureCalibrationPoint,
        ),
        _DarkActionButton(
          icon: showingSavedCalibration
              ? Icons.edit_location_alt_rounded
              : Icons.restart_alt_rounded,
          label: showingSavedCalibration ? 'Перекалибровать' : 'Сбросить',
          onTap: showingSavedCalibration
              ? _startRecalibrationCurrentField
              : (_calibrationCorners.isEmpty ? null : _resetCalibrationCorners),
        ),
        _DarkActionButton(
            icon: Icons.save_rounded,
            label: 'Сохр.',
            onTap: _calibrationCorners.length >= 4 ? _saveCapturedField : null),
      ]),
      child: LayoutBuilder(builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        if (compact) {
          final fieldCount = _fields.length +
              ((_selectedField?.id == null && _selectedField != null) ? 1 : 0);
          final selectedTitle = _selectedField?.title ?? 'Поле не выбрано';
          final selectedSubtitle = _selectedField == null
              ? 'создайте или выберите поле команды'
              : '${_selectedField!.lengthM.toStringAsFixed(0)}×${_selectedField!.widthM.toStringAsFixed(0)} м · ${_selectedField!.hasCalibration ? 'откалибровано' : 'нужна калибровка'}';
          final previewHeight =
              math.max(240.0, math.min(360.0, constraints.maxWidth * .62));

          Widget mobileCard(
              {required IconData icon,
              required String title,
              String? subtitle,
              Widget? trailing,
              required Widget child}) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(_TD.mobileInnerRadius),
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                      child: Row(children: [
                        Container(
                          width: 42,
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                              color: _TD.greenSoft,
                              borderRadius:
                                  BorderRadius.circular(_TD.mobileInnerRadius),
                              border: Border.all(
                                  color: _TD.greenBorder, width: .9)),
                          child: Icon(icon, color: _TD.green, size: 16),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: _TD.text,
                                      fontSize: 14.2,
                                      fontWeight: FontWeight.w700,
                                      height: 1.0)),
                              if ((subtitle ?? '').trim().isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(subtitle!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: _TD.muted,
                                        fontSize: 11.2,
                                        fontWeight: FontWeight.w600,
                                        height: 1.1)),
                              ],
                            ])),
                        if (trailing != null) trailing,
                      ]),
                    ),
                    Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        child: child),
                  ]),
            );
          }

          Widget mobileAction(
              {required IconData icon,
              required String label,
              required VoidCallback? onTap,
              bool primary = false}) {
            final disabled = onTap == null;
            return _NoHoverTap(
              onTap: onTap,
              child: Container(
                height: 42,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 7),
                decoration: BoxDecoration(
                  color: disabled
                      ? _TD.soft2
                      : (primary ? _TD.green : Colors.white),
                  borderRadius: BorderRadius.circular(_TD.mobileInnerRadius),
                  border: Border.all(
                      color: disabled
                          ? _TD.borderStrong
                          : (primary ? _TD.green : _TD.greenBorder),
                      width: .9),
                ),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon,
                          size: 17,
                          color: disabled
                              ? _TD.dim
                              : (primary ? Colors.white : _TD.graphite)),
                      const SizedBox(width: 5),
                      Flexible(
                          child: Text(label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: disabled
                                      ? _TD.dim
                                      : (primary ? Colors.white : _TD.graphite),
                                  fontSize: 11.2,
                                  fontWeight: FontWeight.w700))),
                    ]),
              ),
            );
          }

          Widget fieldTile(TrackerFieldModel f, {bool draft = false}) {
            final selected = draft || _selectedField?.id == f.id;
            final calibrated = f.hasCalibration;
            final subtitle = calibrated
                ? '${f.lengthM.toStringAsFixed(0)}×${f.widthM.toStringAsFixed(0)} м · откалибровано · ${_savedFieldCoordinateSubtitle(f)}'
                : '${f.lengthM.toStringAsFixed(0)}×${f.widthM.toStringAsFixed(0)} м · нужна калибровка';
            return _NoHoverTap(
              onTap: () => setState(() {
                _selectedField = f;
                _calibrationCorners.clear();
              }),
              child: Container(
                margin: const EdgeInsets.only(bottom: 7),
                padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
                decoration: BoxDecoration(
                  color: selected ? _TD.greenSoft : _TD.card2,
                  borderRadius: BorderRadius.circular(_TD.tabletCardRadius),
                  border: Border.all(
                      color: selected ? _TD.greenBorder : _TD.borderStrong,
                      width: .9),
                ),
                child: Row(children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: selected
                            ? Colors.white.withOpacity(.82)
                            : Colors.white,
                        borderRadius:
                            BorderRadius.circular(_TD.interactiveRadius),
                        border: Border.all(
                            color: selected ? _TD.greenBorder : _TD.softLine,
                            width: .8)),
                    child: Icon(
                        calibrated
                            ? Icons.check_circle_rounded
                            : Icons.warning_amber_rounded,
                        color: calibrated ? _TD.green : _TD.orange,
                        size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(f.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: _TD.text,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                height: 1.0)),
                        const SizedBox(height: 4),
                        Text(subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: _TD.muted,
                                fontSize: 11.2,
                                fontWeight: FontWeight.w700,
                                height: 1.05)),
                      ])),
                  const SizedBox(width: 8),
                  Text(selected ? 'выбрано' : 'выбрать',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: selected ? _TD.green : _TD.graphite,
                          fontSize: 11.2,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded,
                      color: _TD.dim, size: 22),
                ]),
              ),
            );
          }

          final cornerChips = List<Widget>.generate(4, (i) {
            final ready = visibleCorners.length > i;
            final active = !showingSavedCalibration &&
                !ready &&
                i == _calibrationCorners.length &&
                _calibrationCorners.length < 4;
            return SizedBox(
              width: (constraints.maxWidth - 44) / 2,
              child: _DarkCornerChip(
                label: labels[i],
                value: ready
                    ? _formatCalibrationCoordinate(visibleCorners[i])
                    : active
                        ? 'ожидает GPS'
                        : 'после предыдущей',
                ready: ready,
                active: active,
                saved: showingSavedCalibration && ready,
                onTap:
                    showingSavedCalibration ? null : () => _handleCornerTap(i),
              ),
            );
          });

          return ListView(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 20),
            children: [
              mobileCard(
                icon: Icons.map_rounded,
                title: selectedTitle,
                subtitle: selectedSubtitle,
                trailing: _MobileReportOutlineButton(
                    label: 'Новое', onTap: _createNewFieldDraft),
                child: Row(children: [
                  Expanded(
                      child: _MobileReportMetricTile(
                          icon: Icons.grid_view_rounded,
                          value: '$fieldCount',
                          subtitle: 'Полей')),
                  Expanded(
                      child: _MobileReportMetricTile(
                          icon: Icons.straighten_rounded,
                          value: _selectedField == null
                              ? '—'
                              : '${_selectedField!.lengthM.toStringAsFixed(0)}×${_selectedField!.widthM.toStringAsFixed(0)}',
                          subtitle: 'Размер')),
                  Expanded(
                      child: _MobileReportMetricTile(
                          icon: Icons.gps_fixed_rounded,
                          value: '${visibleCorners.length}/4',
                          subtitle: 'Точки')),
                  Expanded(
                      child: _MobileReportMetricTile(
                          icon: Icons.check_circle_rounded,
                          value: showingSavedCalibration
                              ? 'OK'
                              : (nextIndex < 0 ? 'OK' : nextLabel),
                          subtitle: 'GPS')),
                ]),
              ),
              Row(children: [
                Expanded(
                    child: mobileAction(
                        icon: Icons.gps_fixed_rounded,
                        label: _calibrationCapturing
                            ? 'Жду'
                            : (nextIndex < 0 ? 'GPS' : nextLabel),
                        primary: true,
                        onTap: nextIndex < 0 || _calibrationCapturing
                            ? null
                            : _captureCalibrationPoint)),
                const SizedBox(width: 8),
                Expanded(
                    child: mobileAction(
                        icon: showingSavedCalibration
                            ? Icons.edit_location_alt_rounded
                            : Icons.restart_alt_rounded,
                        label: showingSavedCalibration ? 'Калибр.' : 'Сброс',
                        onTap: showingSavedCalibration
                            ? _startRecalibrationCurrentField
                            : (_calibrationCorners.isEmpty
                                ? null
                                : _resetCalibrationCorners))),
                const SizedBox(width: 8),
                Expanded(
                    child: mobileAction(
                        icon: Icons.save_rounded,
                        label: 'Сохр.',
                        onTap: _calibrationCorners.length >= 4
                            ? _saveCapturedField
                            : null)),
              ]),
              const SizedBox(height: 10),
              mobileCard(
                icon: Icons.sports_soccer_rounded,
                title: 'Поля команды',
                subtitle: '$fieldCount полей',
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_selectedField?.id == null && _selectedField != null)
                        fieldTile(_selectedField!, draft: true),
                      if (_fields.isEmpty && _selectedField == null)
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius:
                                  BorderRadius.circular(_TD.tabletCardRadius)),
                          child: const Text(
                              'Нажмите «Новое», затем пройдите 4 угла GPS-трекером.',
                              style: TextStyle(
                                  color: _TD.muted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ..._fields.map((f) => fieldTile(f)),
                    ]),
              ),
              mobileCard(
                icon: Icons.gps_fixed_rounded,
                title: 'Калибровка по 4 точкам',
                subtitle: nextIndex < 0
                    ? 'все точки получены'
                    : 'следующая точка: $nextLabel',
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _trackerSignalBanner(compact: true),
                      const SizedBox(height: 8),
                      _CalibrationStatusBanner(
                          nextLabel: nextLabel,
                          done: nextIndex < 0,
                          pointCount: visibleCorners.length,
                          saved: showingSavedCalibration),
                      const SizedBox(height: 10),
                      Wrap(spacing: 8, runSpacing: 8, children: cornerChips),
                    ]),
              ),
              mobileCard(
                icon: Icons.crop_free_rounded,
                title: 'Схема поля',
                subtitle: showingSavedCalibration
                    ? 'координаты сохранены'
                    : 'углы A/B/C/D',
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                          height: previewHeight,
                          child: _calibrationFieldPreview(nextIndex,
                              corners: visibleCorners,
                              saved: showingSavedCalibration)),
                      const SizedBox(height: 10),
                      _DarkHint(
                        text: showingSavedCalibration
                            ? 'Координаты A/B/C/D уже сохранены. Чтобы заменить их, нажмите «Перекалибровать».'
                            : (_points.isEmpty
                                ? 'GPS-точек пока нет. Подключите трекер и дождитесь координат на поле.'
                                : 'Последняя GPS-точка: $_lastWorkspaceGps. Нажмите ${nextIndex < 0 ? '«Сохранить»' : '«GPS $nextLabel»'}.'),
                      ),
                    ]),
              ),
            ],
          );
        }
        return Row(children: [
          Expanded(flex: 4, child: fieldsCard()),
          const _WorkspacePaneDivider.vertical(),
          Expanded(flex: 8, child: calibrationCard(compact: false)),
        ]);
      }),
    );
  }

  Widget _video() {
    return const _DarkPage(
      title: 'Синхронизация видео / мастер событий',
      subtitle: 'синхронизация трекера, видео и автоматической нарезки',
      icon: Icons.video_library_rounded,
      child: Row(children: [
        Expanded(
            flex: 8,
            child: _DarkCard(
                title: 'Лента видео',
                subtitle: 'событий from speed/load alerts',
                child: CustomPaint(
                    painter: _DarkTimelinePainter(),
                    child: SizedBox.expand()))),
        SizedBox(width: 10),
        Expanded(
            flex: 4,
            child: _DarkCard(
                title: 'Мастер событий',
                subtitle: 'auto clips',
                child: Column(children: [
                  _DarkHint(
                      text:
                          'Сценарии: спринт > 30 км/ч, усталость > 70%, падение скорости > 20%, рывок в штрафной, частые COD.'),
                  SizedBox(height: 10),
                  _DarkMetricTile(
                      icon: Icons.content_cut_rounded,
                      title: 'Автонарезки',
                      value: '0',
                      subtitle: 'пока не создано'),
                  SizedBox(height: 8),
                  _DarkMetricTile(
                      icon: Icons.sync_rounded,
                      title: 'Sync',
                      value: 'GPS + видео',
                      subtitle: 'roadmap'),
                ]))),
      ]),
    );
  }

  Widget _settings() {
    return _DarkPage(
      title: 'Пороги / настройки',
      subtitle: 'скоростные зоны, пороги спринта и правила ускорений',
      icon: Icons.tune_rounded,
      trailing: _DarkActionButton(
          icon: Icons.refresh_rounded,
          label: 'Обновить',
          onTap: () => setState(() {})),
      child: FutureBuilder<TrackerSpeedSettings>(
        future: _api.loadSettings(teamId: widget.teamId),
        builder: (context, snapshot) {
          final settings = snapshot.data ?? const TrackerSpeedSettings();

          Widget thresholdsCard({required bool compact}) => _DarkCard(
                title: 'Текущие пороги',
                subtitle: settings.preset,
                child: LayoutBuilder(builder: (context, c) {
                  final cols =
                      compact && c.maxWidth >= 360 ? 2 : (compact ? 1 : 2);
                  return GridView.count(
                    padding: EdgeInsets.zero,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: cols,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 6,
                    childAspectRatio: compact ? (cols == 2 ? 3.35 : 5.2) : 2.25,
                    children: [
                      _DarkMetricTile(
                          icon: Icons.directions_walk_rounded,
                          title: 'Лёгкий бег',
                          value:
                              '${settings.jogRuleMps.toStringAsFixed(1)} m/s',
                          subtitle: 'низкая зона'),
                      _DarkMetricTile(
                          icon: Icons.speed_rounded,
                          title: 'Средний бег',
                          value:
                              '${settings.mediumRuleMps.toStringAsFixed(1)} m/s',
                          subtitle: 'беговая зона'),
                      _DarkMetricTile(
                          icon: Icons.local_fire_department_rounded,
                          title: 'Высокая инт.',
                          value:
                              '${settings.highRuleMps.toStringAsFixed(1)} m/s',
                          subtitle: 'интенсивность'),
                      _DarkMetricTile(
                          icon: Icons.flash_on_rounded,
                          title: 'Спринт',
                          value:
                              '${settings.sprintRuleMps.toStringAsFixed(1)} m/s',
                          subtitle: 'порог'),
                      _DarkMetricTile(
                          icon: Icons.timer_rounded,
                          title: 'Время',
                          value:
                              '${settings.sprintTimeSec.toStringAsFixed(1)} s',
                          subtitle: 'спринт'),
                      _DarkMetricTile(
                          icon: Icons.compare_arrows_rounded,
                          title: 'Ускор.',
                          value:
                              '${settings.accelerationRuleMps2.toStringAsFixed(1)} m/s²',
                          subtitle: 'механика'),
                    ],
                  );
                }),
              );

          Widget presetsCard({required bool compact}) => _DarkCard(
                title: 'Профили',
                subtitle: 'быстрое применение',
                child: Column(children: [
                  _PresetDarkButton(
                      title: 'U13 / Академия',
                      subtitle: 'мягкие зоны для детского футбола',
                      onTap: () => _saveSettingsPreset(settings.copyWith(
                          preset: 'u13',
                          jogRuleMps: 1.2,
                          mediumRuleMps: 3.0,
                          highRuleMps: 4.0,
                          sprintRuleMps: 5.5,
                          accelerationRuleMps2: 1.8))),
                  _PresetDarkButton(
                      title: 'U17 / Полупрофи',
                      subtitle: 'усиленные зоны высокой интенсивности',
                      onTap: () => _saveSettingsPreset(settings.copyWith(
                          preset: 'u17',
                          jogRuleMps: 1.5,
                          mediumRuleMps: 3.5,
                          highRuleMps: 5.0,
                          sprintRuleMps: 6.4,
                          accelerationRuleMps2: 2.0))),
                  _PresetDarkButton(
                      title: 'Профи / Элита',
                      subtitle: 'порог спринта выше',
                      onTap: () => _saveSettingsPreset(settings.copyWith(
                          preset: 'pro',
                          jogRuleMps: 1.8,
                          mediumRuleMps: 4.0,
                          highRuleMps: 5.5,
                          sprintRuleMps: 7.0,
                          accelerationRuleMps2: 2.5))),
                  if (!compact) ...[
                    const Spacer(),
                    const _DarkHint(
                        text:
                            'Пороги используются для зон высокой интенсивности, спринтов и ускорений. Если сервер ругается на preset, обновите save_tracker_settings.php из архива.'),
                  ],
                ]),
              );

          return LayoutBuilder(builder: (context, constraints) {
            final compact = constraints.maxWidth < 1180;
            if (compact) {
              return ListView(
                padding: const EdgeInsets.all(10),
                children: [
                  SizedBox(
                      height: constraints.maxWidth >= 760
                          ? 255
                          : (constraints.maxWidth >= 360 ? 205 : 310),
                      child: thresholdsCard(compact: true)),
                  const SizedBox(height: 10),
                  SizedBox(
                      height: constraints.maxWidth >= 760 ? 255 : 205,
                      child: presetsCard(compact: true)),
                ],
              );
            }
            return Row(children: [
              Expanded(child: thresholdsCard(compact: false)),
              const _WorkspacePaneDivider.vertical(),
              Expanded(child: presetsCard(compact: false)),
            ]);
          });
        },
      ),
    );
  }

  String _remoteLogTimeLabel(Map<String, dynamic> log) {
    final raw = '${log['created_at'] ?? ''}'.trim();
    if (raw.isEmpty) return '—';
    try {
      final dt = _trackerMoscowDateTime(raw);
      if (dt == null) return raw;
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw.length > 19 ? raw.substring(11, 19) : raw;
    }
  }

  String _remoteConsoleSubtitle() {
    if (_lastRemoteConsoleLoadAt == null) return 'ждём данные с сервера';
    final age = DateTime.now().difference(_lastRemoteConsoleLoadAt!).inSeconds;
    return 'обновлено ${age}s назад · ${_remoteDebugLogs.length} строк';
  }

  Color _remoteLogLevelColor(String level) {
    final l = level.toLowerCase();
    if (l.contains('error')) return _TD.red;
    if (l.contains('warn')) return _TD.orange;
    return _TD.greenDark;
  }

  String _remoteLogDeviceLabel(Map<String, dynamic> log) {
    final name = '${log['device_name'] ?? ''}'.trim();
    final uuid = '${log['device_uuid'] ?? ''}'.trim();
    if (name.isEmpty && uuid.isEmpty) return 'без BLE';
    if (uuid.isEmpty) return name;
    final shortUuid = uuid.length > 10 ? uuid.substring(0, 10) : uuid;
    return name.isEmpty ? shortUuid : '$name · $shortUuid';
  }

  Widget _remoteTerminalPanel() {
    final logs = _remoteDebugLogs;
    return _DarkCard(
      title: 'Удалённый терминал',
      subtitle: _remoteConsoleSubtitle(),
      child: Column(children: [
        Row(children: [
          Expanded(
            child: _DarkHint(
              text:
                  'Это общий терминал команды. Если другой человек открыл трекер и интернет есть — здесь будут его BLE, GPS, поле, Live и ошибки API.',
            ),
          ),
          const SizedBox(width: 4),
          _DarkActionButton(
            icon: _remoteConsoleAutoRefresh
                ? Icons.pause_rounded
                : Icons.play_arrow_rounded,
            label: _remoteConsoleAutoRefresh ? 'Авто' : 'Пауза',
            onTap: () => setState(
                () => _remoteConsoleAutoRefresh = !_remoteConsoleAutoRefresh),
          ),
          const SizedBox(width: 4),
          _DarkActionButton(
            icon: Icons.refresh_rounded,
            label: _remoteDebugLoading ? '...' : 'Логи',
            primary: true,
            onTap: _remoteDebugLoading ? null : () => _loadRemoteDebugLogs(),
          ),
        ]),
        const SizedBox(height: 0),
        Expanded(
          child: logs.isEmpty
              ? const _DarkEmpty(
                  icon: Icons.terminal_rounded,
                  text:
                      'Удалённых логов пока нет. На устройстве с трекером должен быть интернет и открыто окно трекера.')
              : ListView.builder(
                  itemCount: logs.length,
                  itemBuilder: (_, i) {
                    final log = logs[i];
                    final level = '${log['level'] ?? 'info'}';
                    final source = '${log['source'] ?? 'app'}';
                    final message = '${log['message'] ?? ''}'.trim();
                    final raw = '${log['raw_hex'] ?? ''}'.trim();
                    final playerId = '${log['player_id'] ?? ''}'.trim();
                    final liveId = '${log['live_session_id'] ?? ''}'.trim();
                    return Container(
                      margin: const EdgeInsets.only(bottom: 7),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _TD.soft2,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                    color: _remoteLogLevelColor(level),
                                    shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 7),
                              Expanded(
                                child: Text(
                                  '${_remoteLogTimeLabel(log)}  [$level] $source',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: _TD.text,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      fontFamily: 'monospace'),
                                ),
                              ),
                            ]),
                            const SizedBox(height: 5),
                            Text(
                              _remoteLogDeviceLabel(log),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: _TD.greenDark,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              message.isEmpty ? '—' : message,
                              style: const TextStyle(
                                  color: _TD.muted,
                                  fontSize: 11.5,
                                  height: 1.25,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w600),
                            ),
                            if (raw.isNotEmpty) ...[
                              const SizedBox(height: 5),
                              Text('RX/TX: $raw',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: _TD.dim,
                                      fontSize: 11.2,
                                      fontFamily: 'monospace')),
                            ],
                            if (playerId.isNotEmpty || liveId.isNotEmpty) ...[
                              const SizedBox(height: 5),
                              Text('player=$playerId  live=$liveId',
                                  style: const TextStyle(
                                      color: _TD.dim,
                                      fontSize: 11.2,
                                      fontFamily: 'monospace')),
                            ],
                          ]),
                    );
                  },
                ),
        ),
      ]),
    );
  }

  Widget _debug() {
    return _DarkPage(
      title: 'Диагностика устройства / RX-TX',
      subtitle:
          'слева локально на этом устройстве, справа удалённый терминал команды',
      icon: Icons.bug_report_rounded,
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        _DarkActionButton(
            icon: Icons.bug_report_rounded,
            label: 'Debug команды',
            onTap: _openTeamLiveDebug),
        _DarkActionButton(
            icon: Icons.restart_alt_rounded,
            label: 'Сбросить все GPS',
            onTap: _resetAllTeamTrackers),
        _DarkActionButton(
            icon: Icons.cloud_upload_rounded,
            label: 'Debug сервер',
            onTap: _sendManualDebugDump),
        const SizedBox(width: 4),
        _DarkActionButton(
            icon: Icons.gps_fixed_rounded,
            label: 'Запрос GPS',
            onTap: _requestCurrentGpsFromDebug),
        const SizedBox(width: 4),
        _DarkActionButton(
            icon: Icons.search_rounded,
            label: _scanning ? 'Поиск...' : 'Поиск GPS',
            primary: true,
            onTap: _scanning ? null : () => _scan(universalMode: true)),
        const SizedBox(width: 4),
        _DarkActionButton(
            icon: Icons.delete_outline_rounded,
            label: 'Очистить',
            onTap: () => setState(() => _logs.clear())),
        const SizedBox(width: 4),
        _DarkActionButton(
            icon: Icons.refresh_rounded,
            label: 'Обновить',
            primary: true,
            onTap: _loadServerData),
      ]),
      child: Row(children: [
        Expanded(
          flex: 6,
          child: _DarkCard(
            title: 'Локальный терминал этого окна',
            subtitle: '${_logs.length} строк · только этот компьютер/планшет',
            child: _logs.isEmpty
                ? const _DarkEmpty(
                    icon: Icons.terminal_rounded,
                    text:
                        'Здесь локальные действия этого окна: отправка debug, ошибки API, запрос GPS, поиск BLE. Удалённый трекер другого человека показывается справа.')
                : ListView.builder(
                    itemCount: _logs.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Text(
                        _logs[i],
                        style: const TextStyle(
                            color: _TD.muted,
                            fontFamily: 'monospace',
                            fontSize: 10.4,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
          ),
        ),
        const _WorkspacePaneDivider.vertical(),
        Expanded(flex: 7, child: _remoteTerminalPanel()),
        const _WorkspacePaneDivider.vertical(),
        Expanded(
            flex: 4,
            child: _DarkCard(
                title: 'Состояние',
                subtitle: 'быстрая диагностика',
                child: Column(children: [
                  _trackerSignalBanner(compact: true),
                  const SizedBox(height: 4),
                  _DarkMetricTile(
                      icon: Icons.bluetooth_rounded,
                      title: 'BLE',
                      value: _hasAnyGpsCommandChannel
                          ? '${_teamBlePool.connectedCount} GPS подключено'
                          : 'TX/RX не готов',
                      subtitle: _remoteConnectedDevice?.id ??
                          'сначала выберите трекер'),
                  const SizedBox(height: 4),
                  _DarkMetricTile(
                      icon: Icons.person_rounded,
                      title: 'Игрок',
                      value: _selectedPlayer?.name ?? 'none',
                      subtitle: 'active'),
                  const SizedBox(height: 4),
                  _DarkMetricTile(
                      icon: Icons.map_rounded,
                      title: 'Поле',
                      value: _selectedField?.title ?? 'none',
                      subtitle: _selectedField?.hasCalibration == true
                          ? 'откалибровано'
                          : 'не готово'),
                  const SizedBox(height: 4),
                  _DarkMetricTile(
                      icon: Icons.route_rounded,
                      title: 'GPS-точки',
                      value: '${_points.length}',
                      subtitle: 'последняя: $_lastWorkspaceGps'),
                  const SizedBox(height: 4),
                  _DarkMetricTile(
                      icon: Icons.cloud_sync_rounded,
                      title: 'Remote debug',
                      value:
                          _lastRemoteDebug.startsWith('OK') ? 'OK' : 'ошибка',
                      subtitle: _lastRemoteDebug),
                  const SizedBox(height: 4),
                  _DarkMetricTile(
                      icon: Icons.receipt_long_rounded,
                      title: 'RX',
                      value: _lastWorkspaceRx,
                      subtitle: 'последний пакет'),
                ]))),
      ]),
    );
  }
}

class _MobileSessionsReportPane extends StatefulWidget {
  const _MobileSessionsReportPane({
    required this.api,
    required this.teamId,
    required this.teamName,
    required this.players,
    required this.selectedSession,
    required this.onSelect,
    required this.onProcess,
    required this.onRefresh,
    required this.onDownloadRecords,
    required this.onSaveGps,
    required this.savingRecord,
  });

  final TrackerProApi api;
  final int teamId;
  final String teamName;
  final List<TrackerPlayerOption> players;
  final TrackerSessionModel? selectedSession;
  final ValueChanged<TrackerSessionModel> onSelect;
  final ValueChanged<TrackerSessionModel> onProcess;
  final VoidCallback onRefresh;
  final VoidCallback onDownloadRecords;
  final VoidCallback? onSaveGps;
  final bool savingRecord;

  @override
  State<_MobileSessionsReportPane> createState() =>
      _MobileSessionsReportPaneState();
}

class _MobileSessionsReportPaneState extends State<_MobileSessionsReportPane> {
  void _handleMobileAction(String value) {
    switch (value) {
      case 'refresh':
        widget.onRefresh();
        setState(() {});
        break;
      case 'download':
        widget.onDownloadRecords();
        break;
      case 'save':
        widget.onSaveGps?.call();
        break;
    }
  }

  Future<void> _openTrainingPickerSheet() async {
    final picked = await showModalBottomSheet<TrackerSessionModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: .92,
        minChildSize: .62,
        maxChildSize: .98,
        builder: (context, controller) {
          return Container(
            clipBehavior: Clip.antiAlias,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Column(children: [
              Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(top: 8, bottom: 6),
                decoration: BoxDecoration(
                    color: _TD.borderStrong,
                    borderRadius: BorderRadius.circular(99)),
              ),
              Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: const BoxDecoration(color: Colors.white),
                child: Row(children: [
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: _TD.greenSoft,
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: _TD.greenBorder, width: .8)),
                    child: const Icon(Icons.calendar_month_rounded,
                        color: _TD.green, size: 16),
                  ),
                  const SizedBox(width: 9),
                  const Expanded(
                      child: Text('Выбор тренировки',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: _TD.text,
                              fontSize: 14.2,
                              fontWeight: FontWeight.w700,
                              height: 1))),
                  _NoHoverTap(
                      onTap: () => Navigator.of(context).maybePop(),
                      child: const SizedBox(
                          width: 34,
                          height: 34,
                          child: Icon(Icons.close_rounded,
                              color: _TD.dim, size: 20))),
                ]),
              ),
              Expanded(
                child: PrimaryScrollController(
                  controller: controller,
                  child: _SessionsListPane(
                    api: widget.api,
                    teamId: widget.teamId,
                    playerId: null,
                    players: widget.players,
                    selectedSession: widget.selectedSession,
                    calendarExpanded: true,
                    onCalendarExpandedChanged: (_) {},
                    onSelect: (session) => Navigator.of(context).pop(session),
                    onProcess: (session) => widget.onProcess(session),
                  ),
                ),
              ),
            ]),
          );
        },
      ),
    );
    if (picked != null && mounted) {
      widget.onSelect(picked);
      setState(() {});
    }
  }

  Future<void> _openReportFullSheet(TrackerSessionModel session) async {
    widget.onSelect(session);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: .96,
        minChildSize: .70,
        maxChildSize: .99,
        builder: (context, controller) {
          return Container(
            clipBehavior: Clip.antiAlias,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Column(
              children: [
                Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(top: 8, bottom: 6),
                  decoration: BoxDecoration(
                      color: _TD.borderStrong,
                      borderRadius: BorderRadius.circular(99)),
                ),
                Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 9),
                  decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(
                          bottom: BorderSide(color: _TD.softLine, width: .7))),
                  child: Row(children: [
                    const Icon(Icons.assignment_rounded,
                        color: _TD.green, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Отчёт #${session.id} · ${(session.distanceM / 1000).toStringAsFixed(2)} км · ${session.sprintCount} спр.',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: _TD.text,
                            fontSize: 13.6,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                    _NoHoverTap(
                      onTap: _openTrainingPickerSheet,
                      child: Container(
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 9),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            color: _TD.greenSoft,
                            borderRadius: BorderRadius.circular(7),
                            border:
                                Border.all(color: _TD.greenBorder, width: .8)),
                        child: const Text('Выбор',
                            style: TextStyle(
                                color: _TD.green,
                                fontSize: 11.2,
                                fontWeight: FontWeight.w700,
                                height: 1)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _NoHoverTap(
                        onTap: () => Navigator.of(context).pop(),
                        child: const SizedBox(
                            width: 34,
                            height: 34,
                            child: Icon(Icons.close_rounded,
                                color: _TD.dim, size: 20))),
                  ]),
                ),
                Expanded(
                  child: PrimaryScrollController(
                    controller: controller,
                    child: _SelectedTrainingReportPane(
                      session: session,
                      teamId: widget.teamId,
                      teamName: widget.teamName,
                      players: widget.players,
                      apiBaseUrl: widget.api.apiBaseUrl,
                      onPickSession: _openTrainingPickerSheet,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _refreshMobileReports() async {
    widget.onRefresh();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TrackerSessionModel>>(
      future: widget.api.loadSessions(teamId: widget.teamId, playerId: null),
      builder: (context, snapshot) {
        final sessions = snapshot.data ?? const <TrackerSessionModel>[];
        final selected = widget.selectedSession ??
            (sessions.isNotEmpty ? sessions.first : null);

        if (snapshot.connectionState == ConnectionState.waiting &&
            snapshot.data == null) {
          return const _DarkCard(
              title: 'Отчёт',
              subtitle: 'загрузка тренировок',
              child: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasError) {
          return _DarkCard(
            title: 'Отчёт',
            subtitle: 'ошибка загрузки',
            child: _DarkError(
                error: '${snapshot.error}', onRetry: () => setState(() {})),
          );
        }

        if (selected == null) {
          return RefreshIndicator(
            color: _TD.green,
            onRefresh: _refreshMobileReports,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 24),
              children: [
                _MobileReportHeroPanel(
                  session: selected,
                  players: widget.players,
                  onPick: _openTrainingPickerSheet,
                  onOpenReport: _openTrainingPickerSheet,
                  onDownload: widget.onDownloadRecords,
                ),
                const SizedBox(height: 10),
                const _DarkEmpty(
                    icon: Icons.storage_rounded,
                    text:
                        'Сессии появятся после Live или сохранения GPS-записи.'),
              ],
            ),
          );
        }

        return RefreshIndicator(
          color: _TD.green,
          onRefresh: _refreshMobileReports,
          child: _SelectedTrainingReportPane(
            session: selected,
            teamId: widget.teamId,
            teamName: widget.teamName,
            players: widget.players,
            apiBaseUrl: widget.api.apiBaseUrl,
            onPickSession: _openTrainingPickerSheet,
          ),
        );
      },
    );
  }
}

class _MobileReportsActionRail extends StatelessWidget {
  const _MobileReportsActionRail({
    required this.savingRecord,
    required this.onRefresh,
    required this.onDownload,
    required this.onSave,
  });

  final bool savingRecord;
  final VoidCallback onRefresh;
  final VoidCallback onDownload;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: Row(
        children: [
          SizedBox(
            width: 42,
            child: _MobileReportActionChip(
                icon: Icons.refresh_rounded,
                label: '',
                onTap: onRefresh,
                compact: true),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 5,
            child: _MobileReportActionChip(
                icon: Icons.download_rounded,
                label: 'Загрузить',
                primary: true,
                onTap: onDownload,
                expanded: true),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 4,
            child: _MobileReportActionChip(
                icon: Icons.save_alt_rounded,
                label: savingRecord ? 'Сохраняю…' : 'GPS',
                onTap: savingRecord ? null : onSave,
                expanded: true),
          ),
        ],
      ),
    );
  }
}

class _MobileReportActionChip extends StatelessWidget {
  const _MobileReportActionChip(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.primary = false,
      this.compact = false,
      this.expanded = false});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool primary;
  final bool compact;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: primary && enabled ? _TD.green : _TD.card,
      borderRadius: BorderRadius.circular(6),
      child: _NoHoverTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          height: 42,
          alignment: Alignment.center,
          padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
                color: primary && enabled ? _TD.green : _TD.borderStrong),
          ),
          child: Row(
            mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16,
                  color: primary && enabled
                      ? Colors.white
                      : (enabled ? _TD.graphite : _TD.dim)),
              if (label.trim().isNotEmpty) ...[
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: primary && enabled
                          ? Colors.white
                          : (enabled ? _TD.graphite : _TD.dim),
                      fontSize: 11.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileTrainingSelectorCard extends StatelessWidget {
  const _MobileTrainingSelectorCard({
    required this.session,
    required this.sessionsCount,
    required this.onPick,
    required this.onOpen,
    required this.onProcess,
  });

  final TrackerSessionModel? session;
  final int sessionsCount;
  final VoidCallback onPick;
  final VoidCallback? onOpen;
  final VoidCallback? onProcess;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final hasSession = s != null;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border.fromBorderSide(
            BorderSide(color: _TD.borderStrong, width: .7)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: const BoxDecoration(
              border:
                  Border(bottom: BorderSide(color: _TD.softLine, width: .7))),
          child: Row(children: [
            const Icon(Icons.calendar_month_rounded,
                color: _TD.green, size: 17),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                hasSession ? 'Выбор тренировки #${s.id}' : 'Выбор тренировки',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: _TD.text,
                    fontSize: 13.2,
                    fontWeight: FontWeight.w700,
                    height: 1),
              ),
            ),
            Text('$sessionsCount сесс.',
                style: const TextStyle(
                    color: _TD.muted,
                    fontSize: 11.0,
                    fontWeight: FontWeight.w600,
                    height: 1)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (hasSession) ...[
              Row(children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: _TD.greenSoft,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: _TD.greenBorder, width: .8)),
                  child: const Icon(Icons.assignment_turned_in_rounded,
                      color: _TD.green, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(s.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: _TD.text,
                              fontSize: 13.4,
                              fontWeight: FontWeight.w700,
                              height: 1.05)),
                      const SizedBox(height: 3),
                      Text(
                        '${s.playerName ?? 'Команда'} · ${s.createdAt}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: _TD.muted,
                            fontSize: 11.2,
                            fontWeight: FontWeight.w600,
                            height: 1.05),
                      ),
                    ])),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                _MobileTinyMetric(
                    icon: Icons.route_rounded,
                    value: '${(s.distanceM / 1000).toStringAsFixed(2)} км'),
                _MobileTinyMetric(
                    icon: Icons.speed_rounded,
                    value: '${s.maxSpeedKmh.toStringAsFixed(1)} км/ч'),
                _MobileTinyMetric(
                    icon: Icons.flash_on_rounded,
                    value: '${s.sprintCount} спр.'),
              ]),
            ] else
              const Text(
                'Выберите дату и сессию: календарь откроется отдельным окном, а отчёт останется чистым и широким.',
                style: TextStyle(
                    color: _TD.muted,
                    fontSize: 11.3,
                    fontWeight: FontWeight.w600,
                    height: 1.22),
              ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: _MobileFlatButton(
                  icon: Icons.calendar_month_rounded,
                  label: hasSession ? 'Сменить' : 'Выбрать тренировку',
                  primary: !hasSession,
                  onTap: onPick,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _MobileFlatButton(
                  icon: Icons.tune_rounded,
                  label: 'Конструктор',
                  primary: hasSession,
                  onTap: onOpen,
                ),
              ),
              const SizedBox(width: 7),
              _NoHoverTap(
                onTap: onProcess,
                child: Container(
                  width: 42,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: Colors.white),
                  child: Icon(Icons.playlist_add_check_rounded,
                      color: onProcess == null ? _TD.dim : _TD.green, size: 18),
                ),
              ),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _MobileTinyMetric extends StatelessWidget {
  const _MobileTinyMetric({required this.icon, required this.value});
  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(children: [
        Icon(icon, color: _TD.green, size: 13),
        const SizedBox(width: 4),
        Expanded(
            child: Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: _TD.graphite,
                    fontSize: 11.2,
                    fontWeight: FontWeight.w700,
                    height: 1))),
      ]),
    );
  }
}

class _MobileFlatButton extends StatelessWidget {
  const _MobileFlatButton(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.primary = false});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return _NoHoverTap(
      onTap: onTap,
      child: Container(
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: primary && enabled ? _TD.green : _TD.card2,
            border: Border.all(
                color: primary && enabled ? _TD.green : _TD.borderStrong,
                width: .7)),
        child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  color: primary && enabled
                      ? Colors.white
                      : (enabled ? _TD.graphite : _TD.dim),
                  size: 15),
              const SizedBox(width: 6),
              Flexible(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: primary && enabled
                              ? Colors.white
                              : (enabled ? _TD.graphite : _TD.dim),
                          fontSize: 11.2,
                          fontWeight: FontWeight.w700,
                          height: 1))),
            ]),
      ),
    );
  }
}

class _MobileSelectedSessionCard extends StatelessWidget {
  const _MobileSelectedSessionCard(
      {required this.session,
      required this.sessionsCount,
      required this.onOpen,
      required this.onProcess});
  final TrackerSessionModel session;
  final int sessionsCount;
  final VoidCallback onOpen;
  final VoidCallback onProcess;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _TD.greenBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: _TD.greenSoft,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _TD.greenBorder)),
            child: const Icon(Icons.assignment_turned_in_rounded,
                color: _TD.green, size: 21),
          ),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(session.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: _TD.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(
                '${session.playerName ?? 'Команда'} · ${session.createdAt} · ${(session.distanceM / 1000).toStringAsFixed(2)} км · $sessionsCount сессий',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: _TD.muted,
                    fontSize: 11.2,
                    fontWeight: FontWeight.w700),
              ),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: onOpen,
              style: FilledButton.styleFrom(
                  backgroundColor: _TD.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                  padding: const EdgeInsets.symmetric(horizontal: 10)),
              icon: const Icon(Icons.open_in_full_rounded, size: 16),
              label: const Text('Открыть сессию',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      TextStyle(fontSize: 11.3, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onProcess,
              style: OutlinedButton.styleFrom(
                  foregroundColor: _TD.graphite,
                  side: const BorderSide(color: _TD.borderStrong),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                  padding: const EdgeInsets.symmetric(horizontal: 10)),
              icon: const Icon(Icons.playlist_add_check_rounded, size: 16),
              label: const Text('Обраб.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      TextStyle(fontSize: 11.3, fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ]),
    );
  }
}

class _MobileReportsEmptySelector extends StatelessWidget {
  const _MobileReportsEmptySelector();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(6)),
      child: const Row(children: [
        Icon(Icons.storage_rounded, color: _TD.dim, size: 24),
        SizedBox(width: 10),
        Expanded(
            child: Text(
                'Сессия не выбрана. После Live или сохранения GPS здесь появится список сессий.',
                style: TextStyle(
                    color: _TD.muted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700))),
      ]),
    );
  }
}

class _MobileReportsSectionTitle extends StatelessWidget {
  const _MobileReportsSectionTitle(
      {required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
              color: _TD.greenSoft,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _TD.greenBorder)),
          child: const Icon(Icons.table_chart_rounded,
              color: _TD.green, size: 17)),
      const SizedBox(width: 9),
      Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: _TD.text, fontSize: 14, fontWeight: FontWeight.w700)),
        Text(subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: _TD.muted, fontSize: 11.0, fontWeight: FontWeight.w700)),
      ])),
    ]);
  }
}

class _MobileSessionChipCard extends StatelessWidget {
  const _MobileSessionChipCard(
      {required this.session,
      required this.active,
      required this.onTap,
      required this.onOpen});
  final TrackerSessionModel session;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      child: Material(
        color: active ? _TD.greenSoft : Colors.white,
        borderRadius: BorderRadius.circular(6),
        child: _NoHoverTap(
          onTap: onTap,
          onLongPress: onOpen,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: active ? _TD.greenBorder : _TD.borderStrong)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(
                    active
                        ? Icons.check_circle_rounded
                        : Icons.assignment_rounded,
                    color: active ? _TD.green : _TD.dim,
                    size: 18),
                const SizedBox(width: 6),
                Expanded(
                    child: Text(session.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: _TD.text,
                            fontSize: 11.4,
                            fontWeight: FontWeight.w700))),
              ]),
              const SizedBox(height: 5),
              Text(session.playerName ?? 'Команда',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: _TD.muted,
                      fontSize: 11.2,
                      fontWeight: FontWeight.w700)),
              const Spacer(),
              Row(children: [
                Expanded(
                    child: Text(
                        '${(session.distanceM / 1000).toStringAsFixed(2)} км · ${session.maxSpeedKmh.toStringAsFixed(1)} км/ч',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: _TD.dim,
                            fontSize: 11.0,
                            fontWeight: FontWeight.w700))),
                _NoHoverTap(
                  onTap: onOpen,
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6)),
                      child: const Icon(Icons.open_in_new_rounded,
                          color: _TD.green, size: 15)),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

class _MobileSessionListCard extends StatelessWidget {
  const _MobileSessionListCard(
      {required this.session,
      required this.active,
      required this.onTap,
      required this.onProcess});
  final TrackerSessionModel session;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onProcess;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? _TD.greenSoft : Colors.white,
      borderRadius: BorderRadius.circular(6),
      child: _NoHoverTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 9, 8, 9),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color: active ? _TD.greenBorder : _TD.borderStrong)),
          child: Row(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                  color: active ? Colors.white : _TD.soft,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: active ? _TD.greenBorder : _TD.softLine)),
              child: Icon(
                  active ? Icons.checklist_rounded : Icons.assignment_rounded,
                  color: active ? _TD.green : _TD.dim,
                  size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(session.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: _TD.text,
                            fontSize: 12.2,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      '${session.playerName ?? 'Команда'} · ${session.createdAt} · ${(session.distanceM / 1000).toStringAsFixed(2)} км',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: _TD.muted,
                          fontSize: 11.2,
                          fontWeight: FontWeight.w700),
                    ),
                  ]),
            ),
            const SizedBox(width: 8),
            _NoHoverTap(
              onTap: onProcess,
              child: const SizedBox(
                  width: 34,
                  height: 34,
                  child: Icon(Icons.playlist_add_check_rounded,
                      color: _TD.green, size: 18)),
            ),
            const Icon(Icons.chevron_right_rounded, color: _TD.dim, size: 20),
          ]),
        ),
      ),
    );
  }
}

class _MobileReportHeroPanel extends StatelessWidget {
  const _MobileReportHeroPanel({
    required this.session,
    required this.players,
    required this.onPick,
    required this.onOpenReport,
    required this.onDownload,
  });

  final TrackerSessionModel? session;
  final List<TrackerPlayerOption> players;
  final VoidCallback onPick;
  final VoidCallback onOpenReport;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final hasSession = session != null;
    final s = session;
    final subtitle = hasSession
        ? 'Сессия #${s!.id} · ${_reportShortDate(s.createdAt)} · ${_reportFieldLabel(s)}'
        : 'Сначала выберите сессию, затем откройте PDF / выгрузку';
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_TD.mobileInnerRadius),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: _TD.greenSoft,
                borderRadius: BorderRadius.circular(_TD.mobileInnerRadius),
                border: Border.all(color: _TD.greenBorder, width: .9)),
            child: const Icon(Icons.assignment_rounded,
                color: _TD.green, size: 22),
          ),
          const SizedBox(width: 8),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('Отчёт по тренировке',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: _TD.text,
                        fontSize: 16.2,
                        fontWeight: FontWeight.w700,
                        height: 1.06)),
                const SizedBox(height: 5),
                Text(subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: _TD.muted,
                        fontSize: 11.2,
                        fontWeight: FontWeight.w600,
                        height: 1.15)),
              ])),
          const SizedBox(width: 10),
          SizedBox(
            width: 128,
            child: _MobileReportPrimaryButton(
              icon: Icons.picture_as_pdf_rounded,
              label: 'PDF',
              onTap: onOpenReport,
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: _MobileReportSoftButton(
              icon: Icons.calendar_month_rounded,
              label: 'Выбор сессии',
              onTap: onPick,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _MobileReportSoftButton(
              icon: Icons.download_rounded,
              label: 'GPS записи',
              onTap: onDownload,
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
              child: _MobileReportStatusChip(
                  icon: Icons.groups_rounded,
                  label: '${players.length} игрока')),
          const SizedBox(width: 8),
          const Expanded(
              child: _MobileReportStatusChip(
                  icon: Icons.favorite_border_rounded, label: 'GPS + HR')),
          const SizedBox(width: 8),
          const Expanded(
              child: _MobileReportStatusChip(
                  icon: Icons.list_alt_rounded, label: '10 разделов')),
        ]),
      ]),
    );
  }
}

class _MobileReportSelectedSessionCard extends StatelessWidget {
  const _MobileReportSelectedSessionCard(
      {required this.session,
      required this.playersCount,
      required this.onOpen});

  final TrackerSessionModel session;
  final int playersCount;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_TD.mobileInnerRadius),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _TD.greenSoft,
              borderRadius: BorderRadius.circular(_TD.mobileInnerRadius),
              border: Border.all(color: _TD.greenBorder, width: .9),
            ),
            child: const Icon(Icons.calendar_month_rounded,
                color: _TD.green, size: 18),
          ),
          const SizedBox(width: 10),
          const Expanded(
              child: Text('Выбранная сессия',
                  style: TextStyle(
                      color: _TD.text,
                      fontSize: 14.6,
                      fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 8),
        Text('Сессия #${session.id}',
            style: const TextStyle(
                color: _TD.text, fontSize: 13.8, fontWeight: FontWeight.w700)),
        const SizedBox(height: 5),
        Text(
          '${_reportShortDate(session.createdAt)} · ${_reportShortTime(session.createdAt)} · ${_reportDurationLabel(session.durationSec)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
              color: _TD.muted, fontSize: 11.3, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFCFDFC),
            borderRadius: BorderRadius.circular(_TD.mobileInnerRadius),
          ),
          child: Column(
            children: [
              Row(children: [
                Expanded(
                    child: _MobileReportMetricTile(
                        icon: Icons.route_rounded,
                        value: _reportDistanceKm(session.distanceM),
                        subtitle: 'Дист.')),
                Expanded(
                    child: _MobileReportMetricTile(
                        icon: Icons.speed_rounded,
                        value: '${session.maxSpeedKmh.toStringAsFixed(1)} км/ч',
                        subtitle: 'Макс.')),
              ]),
              Container(height: .8, color: _TD.borderStrong),
              Row(children: [
                const Expanded(
                    child: _MobileReportMetricTile(
                        icon: Icons.favorite_rounded,
                        value: '111 уд/мин',
                        subtitle: 'Ср. пульс')),
                Expanded(
                    child: _MobileReportMetricTile(
                        icon: Icons.groups_rounded,
                        value: '$playersCount',
                        subtitle: 'Игрока')),
              ]),
            ],
          ),
        ),
      ]),
    );
  }
}

class _MobileReportPlayersExportCard extends StatelessWidget {
  const _MobileReportPlayersExportCard(
      {required this.players, required this.onTap});

  final List<TrackerPlayerOption> players;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shown = players.take(3).toList(growable: false);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_TD.mobileInnerRadius),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: _TD.greenSoft,
                borderRadius: BorderRadius.circular(_TD.mobileInnerRadius),
                border: Border.all(color: _TD.greenBorder, width: .9)),
            child: const Icon(Icons.groups_rounded, color: _TD.green, size: 18),
          ),
          const SizedBox(width: 10),
          const Expanded(
              child: Text('Игроки для выгрузки',
                  style: TextStyle(
                      color: _TD.text,
                      fontSize: 14.6,
                      fontWeight: FontWeight.w700))),
          const SizedBox(width: 8),
          _MobileReportOutlineButton(label: 'Изменить', onTap: onTap),
        ]),
        const SizedBox(height: 8),
        if (shown.isEmpty)
          const Text('Игроки команды появятся после загрузки состава',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: _TD.muted,
                  fontSize: 11.1,
                  fontWeight: FontWeight.w700))
        else
          Row(
            children: [
              for (final p in shown)
                Expanded(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    _PlayerAvatarDark(
                        url: p.avatar,
                        initials: _playerInitials(p.name),
                        size: 46),
                    const SizedBox(height: 5),
                    Text(_compactPlayerName(p.name),
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: _TD.text,
                            fontSize: 11.0,
                            fontWeight: FontWeight.w700,
                            height: 1.05)),
                  ]),
                ),
            ],
          ),
      ]),
    );
  }
}

class _MobileReportIncludeBlocksCard extends StatelessWidget {
  const _MobileReportIncludeBlocksCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const items = <String>[
      'Сводка команды',
      'Таблицы игроков',
      'Пульс Polar',
      'Локомоторика',
      'Механика',
      'Карта',
      'Скорость',
      'Сравнение'
    ];
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_TD.mobileInnerRadius)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: _TD.greenSoft,
                  borderRadius: BorderRadius.circular(_TD.mobileInnerRadius),
                  border: Border.all(color: _TD.greenBorder, width: .9)),
              child: const Icon(Icons.playlist_add_check_circle_rounded,
                  color: _TD.green, size: 18)),
          const SizedBox(width: 10),
          const Expanded(
              child: Text('Что включить в отчёт',
                  style: TextStyle(
                      color: _TD.text,
                      fontSize: 14.6,
                      fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in items)
              _NoHoverTap(
                onTap: onTap,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                      color: _TD.greenSoft,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: _TD.greenBorder, width: .9)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(item,
                        style: const TextStyle(
                            color: _TD.graphite,
                            fontSize: 11.4,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(width: 7),
                    const Icon(Icons.check_circle_rounded,
                        color: _TD.green, size: 16),
                  ]),
                ),
              ),
          ],
        ),
      ]),
    );
  }
}

class _MobileReportPdfParamsCard extends StatelessWidget {
  const _MobileReportPdfParamsCard();

  @override
  Widget build(BuildContext context) {
    const items = <({IconData icon, String label})>[
      (icon: Icons.shield_outlined, label: 'По команде'),
      (icon: Icons.groups_rounded, label: 'По игрокам'),
      (icon: Icons.business_center_outlined, label: 'С логотипом'),
      (icon: Icons.photo_outlined, label: 'Фото игроков'),
    ];
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_TD.mobileInnerRadius)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: _TD.soft,
                  borderRadius: BorderRadius.circular(_TD.mobileInnerRadius)),
              child: const Icon(Icons.description_outlined,
                  color: _TD.graphite, size: 18)),
          const SizedBox(width: 10),
          const Expanded(
              child: Text('Параметры PDF',
                  style: TextStyle(
                      color: _TD.text,
                      fontSize: 14.6,
                      fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 14,
          children: [
            for (final item in items)
              SizedBox(
                width: 164,
                child: Row(children: [
                  Icon(item.icon, size: 16, color: _TD.graphite),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: _TD.graphite,
                              fontSize: 11.8,
                              fontWeight: FontWeight.w700))),
                  const SizedBox(width: 8),
                  const _MobileReportToggle(active: true),
                ]),
              ),
          ],
        ),
      ]),
    );
  }
}

class _MobileReportPreviewOverviewCard extends StatelessWidget {
  const _MobileReportPreviewOverviewCard(
      {required this.session, required this.onTap});

  final TrackerSessionModel session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    Widget card({required Widget child}) => Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: const Color(0xFFFCFDFC),
              borderRadius: BorderRadius.circular(_TD.mobileInnerRadius)),
          child: child,
        );

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_TD.mobileInnerRadius)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: _TD.soft,
                  borderRadius: BorderRadius.circular(_TD.mobileInnerRadius)),
              child: const Icon(Icons.remove_red_eye_outlined,
                  color: _TD.graphite, size: 18)),
          const SizedBox(width: 10),
          const Expanded(
              child: Text('Предпросмотр отчёта',
                  style: TextStyle(
                      color: _TD.text,
                      fontSize: 14.6,
                      fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: 8),
        _NoHoverTap(
          onTap: onTap,
          child: card(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Сводка команды',
                  style: TextStyle(
                      color: _TD.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              const Text('Ключевые показатели',
                  style: TextStyle(
                      color: _TD.muted,
                      fontSize: 11.0,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              _MiniPreviewMetric(
                  icon: Icons.route_rounded,
                  value: _reportDistanceKm(session.distanceM),
                  label: 'Дистанция'),
              const SizedBox(height: 8),
              _MiniPreviewMetric(
                  icon: Icons.speed_rounded,
                  value: '${session.maxSpeedKmh.toStringAsFixed(1)} км/ч',
                  label: 'Макс. скорость'),
              const SizedBox(height: 8),
              const _MiniPreviewMetric(
                  icon: Icons.favorite_rounded,
                  value: '111 уд/мин',
                  label: 'Ср. пульс'),
              const SizedBox(height: 8),
              _MiniPreviewMetric(
                  icon: Icons.timer_outlined,
                  value: _reportDurationLabel(session.durationSec),
                  label: 'Длительность'),
            ]),
          ),
        ),
        const SizedBox(height: 10),
        _NoHoverTap(
          onTap: onTap,
          child: card(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Карта перемещений',
                      style: TextStyle(
                          color: _TD.text,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                  SizedBox(height: 2),
                  Text('6 точек',
                      style: TextStyle(
                          color: _TD.muted,
                          fontSize: 11.0,
                          fontWeight: FontWeight.w700)),
                  SizedBox(height: 10),
                  SizedBox(height: 150, child: _ReportMiniPitchPreview()),
                  SizedBox(height: 8),
                  _ReportMiniHeatLegend(),
                ]),
          ),
        ),
        const SizedBox(height: 10),
        _NoHoverTap(
          onTap: onTap,
          child: card(
            child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Пульс команды',
                      style: TextStyle(
                          color: _TD.text,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                  SizedBox(height: 2),
                  Text('111 уд/мин · Ср. пульс',
                      style: TextStyle(
                          color: _TD.muted,
                          fontSize: 11.0,
                          fontWeight: FontWeight.w700)),
                  SizedBox(height: 12),
                  SizedBox(height: 150, child: _ReportMiniHrChart()),
                ]),
          ),
        ),
      ]),
    );
  }
}

class _MobileReportSprintFooterCard extends StatelessWidget {
  const _MobileReportSprintFooterCard(
      {required this.session, required this.onTap});
  final TrackerSessionModel session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _NoHoverTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_TD.mobileInnerRadius)),
        child: Row(children: [
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Спринты',
                  style: TextStyle(
                      color: _TD.text,
                      fontSize: 14.6,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(
                  'Макс. скорость ${session.maxSpeedKmh.toStringAsFixed(1)} км/ч',
                  style: const TextStyle(
                      color: _TD.muted,
                      fontSize: 11.2,
                      fontWeight: FontWeight.w700)),
            ]),
          ),
          _SprintSummaryMini(value: '${session.sprintCount}', label: 'Спринта'),
          _SprintSummaryMini(
              value: _reportDistanceKm(session.sprintDistanceM),
              label: 'Общая дистанция'),
          _SprintSummaryMini(
              value: '${(session.durationSec / 60).toStringAsFixed(1)} мин.',
              label: 'Длительность'),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded,
              color: _TD.graphite, size: 22),
        ]),
      ),
    );
  }
}

class _MobileReportPrimaryButton extends StatelessWidget {
  const _MobileReportPrimaryButton(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _TD.green,
      borderRadius: BorderRadius.circular(_TD.mobileInnerRadius),
      child: _NoHoverTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_TD.mobileInnerRadius),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
              color: _TD.green,
              borderRadius: BorderRadius.circular(_TD.mobileInnerRadius),
              border: Border.all(color: _TD.green, width: .9)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 20, color: Colors.white),
            const SizedBox(width: 8),
            Flexible(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.6,
                        fontWeight: FontWeight.w700))),
          ]),
        ),
      ),
    );
  }
}

class _MobileReportSoftButton extends StatelessWidget {
  const _MobileReportSoftButton(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(_TD.mobileInnerRadius),
      child: _NoHoverTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_TD.mobileInnerRadius),
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(_TD.mobileInnerRadius)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 18, color: _TD.graphite),
            const SizedBox(width: 8),
            Flexible(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: _TD.graphite,
                        fontSize: 12.3,
                        fontWeight: FontWeight.w700))),
          ]),
        ),
      ),
    );
  }
}

class _MobileReportOutlineButton extends StatelessWidget {
  const _MobileReportOutlineButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _NoHoverTap(
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_TD.mobileInnerRadius),
            border: Border.all(color: _TD.greenBorder, width: .9)),
        child: Text(label,
            style: const TextStyle(
                color: _TD.green, fontSize: 12.6, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _MobileReportStatusChip extends StatelessWidget {
  const _MobileReportStatusChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_TD.mobileInnerRadius)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: _TD.graphite),
        const SizedBox(width: 7),
        Text(label,
            style: const TextStyle(
                color: _TD.graphite,
                fontSize: 11.7,
                fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _MobileReportMetricTile extends StatelessWidget {
  const _MobileReportMetricTile(
      {required this.icon, required this.value, required this.subtitle});
  final IconData icon;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 16, color: _TD.green),
        const SizedBox(height: 7),
        Text(value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: _TD.text,
                fontSize: 11.0,
                fontWeight: FontWeight.w700,
                height: 1.05)),
        const SizedBox(height: 2),
        Text(subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: _TD.muted,
                fontSize: 10.4,
                fontWeight: FontWeight.w700,
                height: 1.04)),
      ]),
    );
  }
}

class _MobileReportToggle extends StatelessWidget {
  const _MobileReportToggle({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 20,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
          color: active ? _TD.green : _TD.borderStrong,
          borderRadius: BorderRadius.circular(999)),
      child: Align(
        alignment: active ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
            width: 16,
            height: 16,
            decoration: const BoxDecoration(
                color: Colors.white, shape: BoxShape.circle)),
      ),
    );
  }
}

class _MiniPreviewMetric extends StatelessWidget {
  const _MiniPreviewMetric(
      {required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 15, color: _TD.green),
      const SizedBox(width: 7),
      Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: _TD.text, fontSize: 11.5, fontWeight: FontWeight.w700)),
        Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: _TD.muted, fontSize: 11.2, fontWeight: FontWeight.w700)),
      ])),
    ]);
  }
}

class _ReportMiniPitchPreview extends StatelessWidget {
  const _ReportMiniPitchPreview();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.35,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: CustomPaint(
          painter: _MiniPitchPainter(),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _ReportMiniHeatLegend extends StatelessWidget {
  const _ReportMiniHeatLegend();

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      const Text('Низкая',
          style: TextStyle(
              color: _TD.graphite,
              fontSize: 11.0,
              fontWeight: FontWeight.w700)),
      const SizedBox(width: 6),
      Expanded(
        child: Container(
          height: 5,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: const LinearGradient(colors: [
              Color(0xFF86EFAC),
              Color(0xFFFACC15),
              Color(0xFFEF4444)
            ]),
          ),
        ),
      ),
      const SizedBox(width: 6),
      const Text('Высокая',
          style: TextStyle(
              color: _TD.graphite,
              fontSize: 11.0,
              fontWeight: FontWeight.w700)),
    ]);
  }
}

class _ReportMiniHrChart extends StatelessWidget {
  const _ReportMiniHrChart();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
        painter: _MiniHrChartPainter(), child: const SizedBox.expand());
  }
}

class _SprintSummaryMini extends StatelessWidget {
  const _SprintSummaryMini({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 78,
      child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Text(value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: _TD.text, fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: _TD.muted, fontSize: 11.0, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _MiniPitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = const Color(0xFFE9F6ED);
    final stripe = Paint()..color = const Color(0xFFDFF1E5);
    final line = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final route1 = Paint()
      ..color = const Color(0xFF16A34A)
      ..strokeWidth = 2.1
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final route2 = Paint()
      ..color = const Color(0xFFF97316)
      ..strokeWidth = 2.1
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawRect(Offset.zero & size, fill);
    final cols = 7;
    for (var i = 0; i < cols; i++) {
      if (i.isEven) {
        canvas.drawRect(
            Rect.fromLTWH(
                size.width / cols * i, 0, size.width / cols, size.height),
            stripe);
      }
    }
    final inset = 8.0;
    final field = RRect.fromRectAndRadius(
        Rect.fromLTWH(
            inset, inset, size.width - inset * 2, size.height - inset * 2),
        const Radius.circular(6));
    canvas.drawRRect(field, line);
    final midX = size.width / 2;
    final midY = size.height / 2;
    canvas.drawLine(
        Offset(midX, inset), Offset(midX, size.height - inset), line);
    canvas.drawCircle(Offset(midX, midY), 16, line);
    canvas.drawRect(Rect.fromLTWH(inset, midY - 28, 24, 56), line);
    canvas.drawRect(
        Rect.fromLTWH(size.width - inset - 24, midY - 28, 24, 56), line);
    final pathA = Path()
      ..moveTo(inset + 10, inset + 14)
      ..lineTo(size.width * .26, size.height * .34)
      ..lineTo(size.width * .55, size.height * .48)
      ..lineTo(size.width * .74, size.height * .57);
    final pathB = Path()
      ..moveTo(size.width * .74, size.height * .57)
      ..lineTo(size.width * .68, size.height * .74)
      ..lineTo(size.width * .86, size.height * .79)
      ..lineTo(size.width - inset - 10, size.height - inset - 10);
    canvas.drawPath(pathA, route1);
    canvas.drawPath(pathB, route2);
    for (final p in [
      Offset(inset + 10, inset + 14),
      Offset(size.width * .26, size.height * .34),
      Offset(size.width * .55, size.height * .48),
      Offset(size.width * .74, size.height * .57),
      Offset(size.width - inset - 10, size.height - inset - 10)
    ]) {
      canvas.drawCircle(p, 2.6, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MiniHrChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = _TD.borderStrong
      ..strokeWidth = .8;
    final axisLabels = TextStyle(
        color: _TD.graphite, fontSize: 10.4, fontWeight: FontWeight.w700);
    for (var i = 0; i < 4; i++) {
      final y = size.height / 4 * i + 6;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final points = <Offset>[];
    final values = [
      48.0,
      120,
      42,
      98,
      34,
      90,
      38,
      130,
      44,
      126,
      46,
      136,
      40,
      144,
      50,
      36,
      72,
      34,
      138
    ];
    for (var i = 0; i < values.length; i++) {
      final dx = size.width * i / (values.length - 1);
      final normalized = (values[i] - 30) / 130;
      final dy = size.height - 18 - normalized * (size.height - 32);
      points.add(Offset(dx, dy));
    }
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    final line = Paint()
      ..color = _TD.green
      ..strokeWidth = 2.1
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, line);
    const labels = ['160', '120', '80', '40'];
    for (var i = 0; i < labels.length; i++) {
      final tp = TextPainter(
          text: TextSpan(text: labels[i], style: axisLabels),
          textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(canvas, Offset(0, (size.height - 18) / 4 * i));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

String _reportShortDate(String raw) {
  final s = raw.trim();
  final match = RegExp(r'(\d{4})-(\d{2})-(\d{2})').firstMatch(s);
  if (match != null) {
    return '${match.group(3)}.${match.group(2)}.${match.group(1)}';
  }
  return s.isEmpty ? 'дата не указана' : s;
}

String _reportShortTime(String raw) {
  final match = RegExp(r'(\d{2}:\d{2})').firstMatch(raw);
  return match?.group(1) ?? '--:--';
}

String _reportDurationLabel(int sec) {
  if (sec <= 0) return '190 сек.';
  if (sec < 120) return '$sec сек.';
  final min = sec ~/ 60;
  return '$min мин.';
}

String _reportDistanceKm(double meters) {
  return meters >= 1000
      ? '${(meters / 1000).toStringAsFixed(2)} км'
      : '${meters.toStringAsFixed(0)} м';
}

String _reportFieldLabel(TrackerSessionModel session) {
  final title = session.title.trim();
  final match =
      RegExp(r'поле\s*#?\s*(\d+)', caseSensitive: false).firstMatch(title);
  if (match != null) return 'Поле ${match.group(1)}';
  return 'Поле 7';
}

String _compactPlayerName(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (parts.isEmpty) return 'Игрок';
  if (parts.length == 1) return parts.first;
  final last = parts.first;
  final first = parts.length > 1 ? parts[1] : '';
  return '$last ${first.isNotEmpty ? '${first.substring(0, 1)}.' : ''}'.trim();
}

class _SessionsListPane extends StatefulWidget {
  const _SessionsListPane({
    required this.api,
    required this.teamId,
    required this.playerId,
    required this.players,
    required this.selectedSession,
    this.calendarExpanded = false,
    this.onCalendarExpandedChanged,
    required this.onSelect,
    required this.onProcess,
  });

  final TrackerProApi api;
  final int teamId;
  final int? playerId;
  final List<TrackerPlayerOption> players;
  final TrackerSessionModel? selectedSession;
  final bool calendarExpanded;
  final ValueChanged<bool>? onCalendarExpandedChanged;
  final ValueChanged<TrackerSessionModel> onSelect;
  final ValueChanged<TrackerSessionModel> onProcess;

  @override
  State<_SessionsListPane> createState() => _SessionsListPaneState();
}

class _SessionsListPaneState extends State<_SessionsListPane> {
  late Future<List<TrackerSessionModel>> _future;
  late DateTime _selectedDate;
  late DateTime _visibleMonth;
  bool _allDates = false;
  final Map<int, Future<int>> _participantCountFutures = <int, Future<int>>{};

  @override
  void initState() {
    super.initState();
    _future = widget.api
        .loadSessions(teamId: widget.teamId, playerId: widget.playerId);
    _selectedDate =
        _dateOnly(_sessionDate(widget.selectedSession) ?? DateTime.now());
    _visibleMonth = DateTime(_selectedDate.year, _selectedDate.month);
  }

  @override
  void didUpdateWidget(covariant _SessionsListPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.api != widget.api ||
        oldWidget.teamId != widget.teamId ||
        oldWidget.playerId != widget.playerId) {
      _future = widget.api
          .loadSessions(teamId: widget.teamId, playerId: widget.playerId);
    }
    if (oldWidget.selectedSession?.id != widget.selectedSession?.id &&
        widget.selectedSession != null) {
      final parsed = _sessionDate(widget.selectedSession!);
      if (parsed != null) {
        _selectedDate = _dateOnly(parsed);
        _visibleMonth = DateTime(_selectedDate.year, _selectedDate.month);
        _allDates = false;
      }
    }
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  DateTime? _tryParseSessionDate(String raw) {
    final source = raw.trim();
    if (source.isEmpty) return null;
    final normalized =
        source.contains('T') ? source : source.replaceFirst(' ', 'T');
    final direct = DateTime.tryParse(normalized);
    if (direct != null) return direct;
    final dot = RegExp(
            r'^(\d{2})\.(\d{2})\.(\d{4})(?:\s+(\d{2}):(\d{2})(?::(\d{2}))?)?$')
        .firstMatch(source);
    if (dot != null) {
      return DateTime(
        int.parse(dot.group(3)!),
        int.parse(dot.group(2)!),
        int.parse(dot.group(1)!),
        int.tryParse(dot.group(4) ?? '') ?? 0,
        int.tryParse(dot.group(5) ?? '') ?? 0,
        int.tryParse(dot.group(6) ?? '') ?? 0,
      );
    }
    final dash = RegExp(
            r'^(\d{4})-(\d{2})-(\d{2})(?:[ T](\d{2}):(\d{2})(?::(\d{2}))?)?$')
        .firstMatch(source);
    if (dash != null) {
      return DateTime(
        int.parse(dash.group(1)!),
        int.parse(dash.group(2)!),
        int.parse(dash.group(3)!),
        int.tryParse(dash.group(4) ?? '') ?? 0,
        int.tryParse(dash.group(5) ?? '') ?? 0,
        int.tryParse(dash.group(6) ?? '') ?? 0,
      );
    }
    return null;
  }

  DateTime? _sessionDate(TrackerSessionModel? session) =>
      session == null ? null : _tryParseSessionDate(session.createdAt);

  String _formatDay(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

  String _dateSubtitle(DateTime date) {
    final today = _dateOnly(DateTime.now());
    if (_sameDay(date, today)) return 'сегодня';
    if (_sameDay(date, today.subtract(const Duration(days: 1)))) return 'вчера';
    return 'дата';
  }

  int? _technicalPlayerId(String? raw) {
    final value = (raw ?? '').trim();
    final match = RegExp(r'^(?:игрок|player)\s*#?(\d+)$', caseSensitive: false)
        .firstMatch(value);
    return match == null ? null : int.tryParse(match.group(1) ?? '');
  }

  String _cleanPlayerName(String? raw) {
    final value = (raw ?? '').trim();
    if (value.isEmpty || value.toLowerCase() == 'null') return '';
    // Сервер иногда возвращает техническую подпись «Игрок 106» вместо ФИО.
    // В интерфейсе тренера такую подпись не показываем, если можем взять игрока из состава.
    if (_technicalPlayerId(value) != null) return '';
    return value;
  }

  TrackerPlayerOption? _playerById(int? id) {
    if (id == null || id <= 0) return null;
    for (final p in widget.players) {
      if (p.id == id) return p;
    }
    return null;
  }

  String _sessionPlayerLabel(TrackerSessionModel s) {
    final fromRoster = _playerById(s.playerId);
    if (fromRoster != null && fromRoster.name.trim().isNotEmpty)
      return fromRoster.name.trim();
    final technicalId = _technicalPlayerId(s.playerName);
    final fromTechnical = _playerById(technicalId);
    if (fromTechnical != null && fromTechnical.name.trim().isNotEmpty)
      return fromTechnical.name.trim();
    final fromSession = _cleanPlayerName(s.playerName);
    if (fromSession.isNotEmpty) return fromSession;
    final id = s.playerId ?? technicalId;
    return id == null ? 'Команда' : 'ID игрока $id';
  }

  String _monthLabel(DateTime month) {
    const months = <String>[
      'январь',
      'февраль',
      'март',
      'апрель',
      'май',
      'июнь',
      'июль',
      'август',
      'сентябрь',
      'октябрь',
      'ноябрь',
      'декабрь'
    ];
    return '${months[month.month - 1]} ${month.year}';
  }

  List<TrackerSessionModel> _sortedSessions(
      List<TrackerSessionModel> sessions) {
    final sorted = List<TrackerSessionModel>.from(sessions);
    sorted.sort((a, b) {
      final bd = _sessionDate(b) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final ad = _sessionDate(a) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad);
    });
    return sorted;
  }

  String _trainingGroupKey(TrackerSessionModel s) {
    final dt = _sessionDate(s);
    final day = dt == null
        ? s.createdAt.trim().split(' ').first
        : '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    var title = s.title.trim().toLowerCase().replaceAll('ё', 'е');
    if (title.isEmpty || title == 'сессия') title = 'тренировочная сессия';
    // Сервер может сохранить GPS и Polar одного занятия отдельными строками и
    // с разницей в несколько минут. В календаре это одна тренировка: группируем
    // по дню и названию, а не по точной минуте старта конкретного игрока.
    return '$day|$title';
  }

  List<List<TrackerSessionModel>> _trainingGroups(
      List<TrackerSessionModel> sessions) {
    final map = <String, List<TrackerSessionModel>>{};
    for (final s in _sortedSessions(sessions)) {
      map
          .putIfAbsent(_trainingGroupKey(s), () => <TrackerSessionModel>[])
          .add(s);
    }
    return map.values.toList(growable: false);
  }

  int _participantCount(List<TrackerSessionModel> group) {
    final keys = <Object>{};
    for (final s in group) {
      final id = s.playerId ?? _technicalPlayerId(s.playerName);
      if (id != null && id > 0) {
        keys.add(id);
      } else {
        final name = _sessionPlayerLabel(s).trim().toLowerCase();
        if (name.isNotEmpty && name != 'команда') keys.add(name);
      }
    }
    return math.max(1, keys.length);
  }

  Future<int> _resolvedParticipantCount(
      TrackerSessionModel session, int fallback) {
    return _participantCountFutures.putIfAbsent(session.id, () async {
      try {
        final report = await TrackerTrainingReportApi(
                apiBaseUrl: widget.api.apiBaseUrl)
            .loadTrainingReport(sessionId: session.id, teamId: widget.teamId);
        final unique = <Object>{};
        void addPlayer(int? id, String rawName) {
          if (id != null && id > 0) {
            unique.add('id:$id');
            return;
          }
          final name = rawName
              .trim()
              .toLowerCase()
              .replaceAll('ё', 'е')
              .replaceAll(RegExp(r'\s+'), ' ');
          if (name.isNotEmpty && name != 'игрок' && name != 'команда')
            unique.add('name:$name');
        }

        for (final p in report.players) {
          addPlayer(p.playerId, p.name);
        }
        for (final p in report.diagnosticPlayers) {
          addPlayer(p.playerId, p.name);
        }
        // Polar-only игроки могут отсутствовать в GPS-таблице, но присутствуют
        // в общей HR timeline. Их обязательно считаем участниками тренировки.
        for (final point in report.heartRateTimeline) {
          addPlayer(point.playerId, point.playerName);
        }
        return math.max(fallback, unique.length);
      } catch (_) {
        return fallback;
      }
    });
  }

  TrackerSessionModel _groupRepresentative(List<TrackerSessionModel> group) {
    final selectedId = widget.selectedSession?.id;
    if (selectedId != null) {
      for (final s in group) {
        if (s.id == selectedId) return s;
      }
    }
    return group.first;
  }

  List<TrackerSessionModel> _filteredSessions(
      List<TrackerSessionModel> sessions) {
    final sorted = _sortedSessions(sessions);
    if (_allDates) return sorted;
    return sorted.where((s) {
      final date = _sessionDate(s);
      return date != null && _sameDay(date, _selectedDate);
    }).toList(growable: false);
  }

  DateTime _firstDate(List<TrackerSessionModel> sessions) {
    final parsed = sessions
        .map((s) => _sessionDate(s))
        .whereType<DateTime>()
        .toList(growable: false);
    if (parsed.isEmpty) return DateTime(DateTime.now().year - 1, 1, 1);
    parsed.sort((a, b) => a.compareTo(b));
    return _dateOnly(parsed.first);
  }

  DateTime _lastDate(List<TrackerSessionModel> sessions) {
    final parsed = sessions
        .map((s) => _sessionDate(s))
        .whereType<DateTime>()
        .toList(growable: false);
    if (parsed.isEmpty) return _dateOnly(DateTime.now());
    parsed.sort((a, b) => a.compareTo(b));
    return _dateOnly(parsed.last);
  }

  int _sessionsOnDay(DateTime day, List<TrackerSessionModel> sessions) {
    return sessions.where((s) {
      final date = _sessionDate(s);
      return date != null && _sameDay(date, day);
    }).length;
  }

  void _applyDayFilter(DateTime date, List<TrackerSessionModel> sessions,
      {bool autoSelectSession = true}) {
    final clean = _dateOnly(date);
    final filtered = _sortedSessions(sessions).where((s) {
      final d = _sessionDate(s);
      return d != null && _sameDay(d, clean);
    }).toList(growable: false);
    setState(() {
      _selectedDate = clean;
      _visibleMonth = DateTime(clean.year, clean.month);
      _allDates = false;
    });
    if (autoSelectSession && filtered.isNotEmpty) {
      final selectedId = widget.selectedSession?.id;
      if (selectedId == null || !filtered.any((s) => s.id == selectedId)) {
        widget.onSelect(filtered.first);
      }
    }
  }

  void _setCalendarExpanded(bool value) {
    widget.onCalendarExpandedChanged?.call(value);
  }

  Widget _topHeader(
      List<TrackerSessionModel> sessions, List<TrackerSessionModel> filtered) {
    final selected = widget.selectedSession;
    final title = _allDates ? 'Все даты' : _formatDay(_selectedDate);
    final subtitle = _allDates
        ? '${sessions.length} сессий за весь период'
        : '${_dateSubtitle(_selectedDate)} · ${filtered.length} ${filtered.length == 1 ? 'сессия' : filtered.length < 5 ? 'сессии' : 'сессий'}';
    return LayoutBuilder(
      builder: (context, box) {
        final compact = box.maxWidth < 420;
        final info = Row(children: [
          Container(
              width: compact ? 30 : 36,
              height: compact ? 30 : 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: _TD.greenSoft,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _TD.greenBorder)),
              child: Icon(Icons.calendar_month_rounded,
                  color: _TD.green, size: compact ? 16 : 19)),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                Text('Сессии',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: _TD.text,
                        fontSize: 13.4,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.25)),
                const SizedBox(height: 2),
                Text(
                    '$title · $subtitle${selected == null ? '' : ' · #${selected.id}'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: _TD.muted,
                        fontSize: 11.2,
                        fontWeight: FontWeight.w600)),
              ])),
        ]);
        final actions = <Widget>[
          _DarkActionButton(
              icon: widget.calendarExpanded
                  ? Icons.close_rounded
                  : Icons.calendar_today_rounded,
              label: widget.calendarExpanded ? 'Закрыть' : 'Календарь',
              primary: true,
              onTap: () => _setCalendarExpanded(!widget.calendarExpanded)),
          const SizedBox(width: 6),
          _DarkActionButton(
              icon: Icons.today_rounded,
              label: 'Сегодня',
              onTap: () => _applyDayFilter(DateTime.now(), sessions,
                  autoSelectSession: !widget.calendarExpanded)),
          const SizedBox(width: 6),
          _DarkActionButton(
              icon: Icons.filter_alt_off_rounded,
              label: 'Все',
              onTap: () {
                setState(() => _allDates = true);
                final sorted = _sortedSessions(sessions);
                if (sorted.isNotEmpty && widget.selectedSession == null)
                  widget.onSelect(sorted.first);
              }),
        ];
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(8)),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                      info,
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(children: actions)),
                    ])
              : Row(children: [
                  Expanded(child: info),
                  const SizedBox(width: 8),
                  ...actions,
                ]),
        );
      },
    );
  }

  String _sessionSourceLabel(TrackerSessionModel s) {
    final hasGps = s.distanceM > 0 || s.maxSpeedKmh > 0 || s.sprintCount > 0;
    final text = '${s.title} ${s.playerName ?? ''}'.toLowerCase();
    final hasPolar = text.contains('polar') ||
        text.contains('h10') ||
        text.contains('hr') ||
        text.contains('пульс');
    if (hasGps && hasPolar) return 'GPS+HR';
    if (hasPolar) return 'Polar';
    if (hasGps) return 'GPS';
    return 'нет';
  }

  Color _sessionSourceColor(String label) {
    if (label.toLowerCase().contains('polar')) return _TD.violet;
    if (label == 'нет') return _TD.dim;
    return _TD.green;
  }

  Widget _sessionChip(TrackerSessionModel s, bool active, {double? width}) {
    final dt = _sessionDate(s);
    final time = dt == null
        ? s.createdAt
        : '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    final source = _sessionSourceLabel(s);
    final sourceColor = _sessionSourceColor(source);
    final playerCount =
        s.playerId != null || _technicalPlayerId(s.playerName) != null
            ? 1
            : math.max(1, widget.players.length);
    final distanceLabel = s.distanceM >= 1000
        ? '${(s.distanceM / 1000).toStringAsFixed(2)} км'
        : '${s.distanceM.toStringAsFixed(0)} м';
    return _NoHoverTap(
      onTap: () => widget.onSelect(s),
      child: Container(
        width: width,
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: active ? _TD.greenSoft.withOpacity(.72) : Colors.white,
          border: Border(
            left: BorderSide(
                color: active ? _TD.green : Colors.transparent,
                width: active ? 2 : 0),
            bottom: const BorderSide(color: _TD.softLine, width: .7),
          ),
        ),
        child: Row(children: [
          SizedBox(
              width: 48,
              child: Text(time,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: _TD.graphite,
                      fontSize: 10.4,
                      fontWeight: FontWeight.w700,
                      height: 1))),
          Container(
            height: 16,
            constraints: const BoxConstraints(minWidth: 42),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: _TD.soft2,
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: _TD.softLine, width: .6)),
            child: Text('#${s.id}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: _TD.text,
                    fontSize: 11.2,
                    fontWeight: FontWeight.w700,
                    height: 1)),
          ),
          _sessionMiniMetric(Icons.groups_rounded, '$playerCount'),
          _sessionMiniMetric(Icons.route_rounded, distanceLabel, flex: 3),
          _sessionMiniMetric(Icons.flash_on_rounded, '${s.sprintCount}'),
          const SizedBox(width: 2),
          Container(
            height: 17,
            constraints: const BoxConstraints(minWidth: 42),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: source == 'Polar'
                  ? const Color(0xFFF5F0FF)
                  : source == 'нет'
                      ? _TD.soft2
                      : _TD.greenSoft,
              borderRadius: BorderRadius.circular(99),
              border:
                  Border.all(color: sourceColor.withOpacity(.08), width: .6),
            ),
            child: Text(source,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: sourceColor,
                    fontSize: 9.6,
                    fontWeight: FontWeight.w700,
                    height: 1)),
          ),
          SizedBox(
              width: 16,
              child: Icon(
                  active
                      ? Icons.check_circle_rounded
                      : Icons.chevron_right_rounded,
                  color: active ? _TD.green : _TD.dim,
                  size: active ? 12 : 13)),
        ]),
      ),
    );
  }

  Widget _sessionMiniMetric(IconData icon, String value, {int flex = 1}) {
    return Flexible(
      flex: flex,
      child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _TD.graphiteSoft, size: 10),
            const SizedBox(width: 1.5),
            Flexible(
                child: Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: _TD.graphite,
                        fontSize: 9.6,
                        fontWeight: FontWeight.w700,
                        height: 1))),
          ]),
    );
  }

  Widget _calendarCell(DateTime day, bool outsideMonth, bool outsideRange,
      int count, List<TrackerSessionModel> sessions, VoidCallback onPicked) {
    final selected = !_allDates && _sameDay(day, _selectedDate);
    final today = _sameDay(day, DateTime.now());
    final hasSessions = count > 0;
    final disabled = outsideRange;
    final dayColor = selected
        ? Colors.white
        : outsideMonth
            ? _TD.dim.withOpacity(.38)
            : today
                ? _TD.green
                : _TD.text;

    return Opacity(
      opacity: disabled ? .30 : 1,
      child: Material(
        color: Colors.transparent,
        child: _NoHoverTap(
          onTap: disabled
              ? null
              : () {
                  _applyDayFilter(day, sessions,
                      autoSelectSession: !widget.calendarExpanded);
                  onPicked();
                },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              color: selected
                  ? _TD.green
                  : hasSessions
                      ? _TD.greenSoft.withOpacity(.20)
                      : Colors.white,
              border: Border(
                right: const BorderSide(color: _TD.softLine, width: .7),
                bottom: const BorderSide(color: _TD.softLine, width: .7),
                left: BorderSide(
                    color: selected ? _TD.green : Colors.transparent,
                    width: selected ? 1.2 : 0),
                top: BorderSide(
                    color: selected ? _TD.green : Colors.transparent,
                    width: selected ? 1.2 : 0),
              ),
            ),
            child: Stack(clipBehavior: Clip.hardEdge, children: [
              Positioned(
                left: 5,
                top: 4,
                child: Text('${day.day}',
                    maxLines: 1,
                    style: TextStyle(
                        color: dayColor,
                        fontSize: 11.0,
                        fontWeight: FontWeight.w700,
                        height: 1)),
              ),
              if (hasSessions)
                Positioned(
                  right: 4,
                  bottom: 4,
                  child: Container(
                    width: 15,
                    height: 15,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: selected ? Colors.white : _TD.greenSoft,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: selected ? Colors.white : _TD.greenBorder,
                            width: .6)),
                    child: Text(count > 9 ? '9+' : '$count',
                        maxLines: 1,
                        style: const TextStyle(
                            color: _TD.green,
                            fontSize: 9.6,
                            fontWeight: FontWeight.w700,
                            height: 1)),
                  ),
                )
              else
                Positioned(
                  left: 5,
                  bottom: 6,
                  child: Container(
                      width: 10,
                      height: 2,
                      decoration: BoxDecoration(
                          color: selected
                              ? Colors.white.withOpacity(.82)
                              : _TD.softLine,
                          borderRadius: BorderRadius.circular(99))),
                ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _calendarIconButton(
      {required IconData icon, required VoidCallback? onTap}) {
    final enabled = onTap != null;
    return _NoHoverTap(
      onTap: onTap,
      child: Opacity(
        opacity: enabled ? 1 : .35,
        child: SizedBox(
          width: 26,
          height: 26,
          child: Icon(icon, color: _TD.graphite, size: 17),
        ),
      ),
    );
  }

  Widget _calendarTextButton(
      {required IconData icon,
      required String label,
      required VoidCallback? onTap,
      bool primary = false}) {
    return _NoHoverTap(
      onTap: onTap,
      child: Container(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: primary ? _TD.green : Colors.white,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
                color: primary ? _TD.green : _TD.borderStrong, width: .7)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: primary ? Colors.white : _TD.graphite, size: 13),
          const SizedBox(width: 3),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: primary ? Colors.white : _TD.graphite,
                  fontSize: 10.4,
                  fontWeight: FontWeight.w700,
                  height: 1)),
        ]),
      ),
    );
  }

  Widget _cmrCalendarGrid(
      List<TrackerSessionModel> sessions,
      DateTime firstDate,
      DateTime lastDate,
      VoidCallback onPicked,
      VoidCallback onMonthChanged,
      {VoidCallback? onClose}) {
    const weekdays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    final month = _visibleMonth;
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final prevMonthDays = DateTime(month.year, month.month, 0).day;
    final leading = first.weekday - 1;
    final total = 42;
    final canPrev = DateTime(month.year, month.month - 1, 1)
        .isAfter(DateTime(firstDate.year, firstDate.month - 1, 1));
    final canNext = DateTime(month.year, month.month + 1, 1)
        .isBefore(DateTime(lastDate.year, lastDate.month + 1, 1));

    DateTime cellDate(int index) {
      final raw = index - leading + 1;
      if (raw < 1)
        return DateTime(month.year, month.month - 1, prevMonthDays + raw);
      if (raw > daysInMonth)
        return DateTime(month.year, month.month + 1, raw - daysInMonth);
      return DateTime(month.year, month.month, raw);
    }

    return Container(
      color: Colors.white,
      child: Column(children: [
        SizedBox(
          height: 30,
          child: Row(children: [
            _calendarIconButton(
                icon: Icons.chevron_left_rounded,
                onTap: canPrev
                    ? () {
                        setState(() => _visibleMonth =
                            DateTime(month.year, month.month - 1, 1));
                        onMonthChanged();
                      }
                    : null),
            Expanded(
                child: Text(_monthLabel(month),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: _TD.text,
                        fontSize: 11.8,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.08,
                        height: 1))),
            _calendarIconButton(
                icon: Icons.chevron_right_rounded,
                onTap: canNext
                    ? () {
                        setState(() => _visibleMonth =
                            DateTime(month.year, month.month + 1, 1));
                        onMonthChanged();
                      }
                    : null),
            _calendarTextButton(
                icon: Icons.today_rounded,
                label: 'Сегодня',
                primary: false,
                onTap: () {
                  _applyDayFilter(DateTime.now(), sessions,
                      autoSelectSession: !widget.calendarExpanded);
                  onPicked();
                }),
            const SizedBox(width: 2),
          ]),
        ),
        Container(
          height: 18,
          decoration: const BoxDecoration(
              border: Border(
                  top: BorderSide(color: _TD.softLine, width: .7),
                  bottom: BorderSide(color: _TD.softLine, width: .7))),
          child: Row(
              children: weekdays
                  .map((d) => Expanded(
                      child: Center(
                          child: Text(d,
                              style: const TextStyle(
                                  color: _TD.muted,
                                  fontSize: 11.2,
                                  fontWeight: FontWeight.w700,
                                  height: 1)))))
                  .toList()),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, gridBox) {
              final cellWidth = gridBox.maxWidth / 7;
              final cellHeight = gridBox.maxHeight / 6;
              final ratio = cellWidth / math.max(12.0, cellHeight);
              return GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                itemCount: total,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 0,
                    crossAxisSpacing: 0,
                    childAspectRatio: ratio),
                itemBuilder: (context, index) {
                  final day = cellDate(index);
                  final outsideMonth = day.month != month.month;
                  final outsideRange =
                      day.isBefore(firstDate) || day.isAfter(lastDate);
                  final count = _sessionsOnDay(day, sessions);
                  return _calendarCell(day, outsideMonth, outsideRange, count,
                      sessions, onPicked);
                },
              );
            },
          ),
        ),
      ]),
    );
  }

  Widget _calendarMetric(
      {required IconData icon, required String title, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
          color: _TD.soft2, borderRadius: BorderRadius.circular(6)),
      child: Row(children: [
        Icon(icon, color: _TD.green, size: 13),
        const SizedBox(width: 5),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: _TD.dim, fontSize: 10.4, fontWeight: FontWeight.w700)),
          const SizedBox(height: 1),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: _TD.text,
                  fontSize: 11.2,
                  fontWeight: FontWeight.w700)),
        ])),
      ]),
    );
  }

  Widget _calendarDaySessionsPanel(List<TrackerSessionModel> sessions) {
    final selectedSessions = _filteredSessions(sessions);
    final selectedDayPlayers = selectedSessions
        .map((s) {
          final id = s.playerId ?? _technicalPlayerId(s.playerName);
          return id == null ? _sessionPlayerLabel(s) : 'id:$id';
        })
        .toSet()
        .length;

    return Container(
      color: Colors.white,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: const BoxDecoration(
              border:
                  Border(bottom: BorderSide(color: _TD.softLine, width: .7))),
          child: Row(children: [
            Expanded(
                child: Text('Сессии дня',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: _TD.text,
                        fontSize: 11.2,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.12,
                        height: 1))),
            Text(_formatDay(_selectedDate),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: _TD.muted,
                    fontSize: 10.4,
                    fontWeight: FontWeight.w600,
                    height: 1)),
          ]),
        ),
        Expanded(
          child: selectedSessions.isEmpty
              ? const _DarkEmpty(
                  icon: Icons.event_busy_rounded,
                  text: 'На выбранный день нет сохранённых GPS-сессий.')
              : ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: _trainingGroups(selectedSessions).length,
                  itemBuilder: (_, i) {
                    final groups = _trainingGroups(selectedSessions);
                    final group = groups[i];
                    final session = _groupRepresentative(group);
                    final active =
                        group.any((x) => x.id == widget.selectedSession?.id);
                    final fallbackCount = _participantCount(group);
                    return FutureBuilder<int>(
                      future: _resolvedParticipantCount(session, fallbackCount),
                      initialData: fallbackCount,
                      builder: (_, snapshot) => _sessionDetailedRow(
                        session,
                        active,
                        participantCount: snapshot.data ?? fallbackCount,
                      ),
                    );
                  },
                ),
        ),
        Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: _TD.softLine, width: .7))),
          child: Row(children: [
            _footerMetric(Icons.calendar_today_rounded,
                '${_trainingGroups(selectedSessions).length} тренировок'),
            _footerMetric(Icons.groups_rounded, '$selectedDayPlayers игрока'),
            _footerMetric(Icons.route_rounded,
                '${(selectedSessions.fold<double>(0, (a, x) => a + x.distanceM) / 1000).toStringAsFixed(2)} км'),
            _footerMetric(Icons.flash_on_rounded,
                '${selectedSessions.fold<int>(0, (a, x) => a + x.sprintCount)} спр.'),
          ]),
        ),
      ]),
    );
  }

  Widget _sessionDetailedRow(TrackerSessionModel s, bool active,
      {int? participantCount}) {
    final dt = _sessionDate(s);
    final time = dt == null
        ? s.createdAt
        : '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    final source = _sessionSourceLabel(s);
    final sourceColor = _sessionSourceColor(source);
    final cleanTitle = s.title.trim();
    final trainingTitle =
        cleanTitle.isEmpty || cleanTitle.toLowerCase() == 'сессия'
            ? 'Тренировочная сессия'
            : cleanTitle;
    final playerCount = participantCount ??
        (s.playerId != null || _technicalPlayerId(s.playerName) != null
            ? 1
            : math.max(1, widget.players.length));
    final distanceLabel = s.distanceM >= 1000
        ? '${(s.distanceM / 1000).toStringAsFixed(2)} км'
        : '${s.distanceM.toStringAsFixed(0)} м';
    final duration = s.durationSec <= 0
        ? '—'
        : '${(s.durationSec / 60).toStringAsFixed(0)} мин';
    return _NoHoverTap(
      onTap: () => widget.onSelect(s),
      child: Container(
        constraints: const BoxConstraints(minHeight: 82),
        margin: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: active ? _TD.greenSoft : _TD.soft2,
          borderRadius: BorderRadius.circular(12),
          boxShadow: active
              ? const [
                  BoxShadow(
                      color: Color(0x1400A750),
                      blurRadius: 12,
                      offset: Offset(0, 4))
                ]
              : const [],
        ),
        child: Row(children: [
          SizedBox(
              width: 50,
              child: Text(time,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: _TD.text,
                      fontSize: 12.0,
                      fontWeight: FontWeight.w600,
                      height: 1))),
          const SizedBox(width: 4),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(trainingTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: _TD.text,
                          fontSize: 12.0,
                          fontWeight: FontWeight.w700,
                          height: 1)),
                  const SizedBox(height: 7),
                  Wrap(spacing: 10, runSpacing: 6, children: [
                    _sessionDetailMetric(
                        Icons.groups_rounded, '$playerCount игр.'),
                    _sessionDetailMetric(Icons.route_rounded, distanceLabel),
                    _sessionDetailMetric(Icons.speed_rounded,
                        '${s.maxSpeedKmh.toStringAsFixed(1)} км/ч'),
                    _sessionDetailMetric(
                        Icons.flash_on_rounded, '${s.sprintCount} спр.'),
                    _sessionDetailMetric(Icons.timer_rounded, duration),
                  ]),
                ]),
          ),
          const SizedBox(width: 8),
          Container(
            height: 22,
            constraints: const BoxConstraints(minWidth: 58),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: source == 'Polar'
                  ? const Color(0xFFF5F0FF)
                  : source == 'нет'
                      ? _TD.soft2
                      : _TD.greenSoft,
              borderRadius: BorderRadius.circular(99),
              border:
                  Border.all(color: sourceColor.withOpacity(.20), width: .7),
            ),
            child: Text(source,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: sourceColor,
                    fontSize: 11.2,
                    fontWeight: FontWeight.w600,
                    height: 1)),
          ),
          const SizedBox(width: 8),
          Icon(
              active ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
              color: active ? _TD.green : _TD.dim,
              size: 17),
        ]),
      ),
    );
  }

  Widget _sessionDetailMetric(IconData icon, String value) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: _TD.graphiteSoft, size: 11),
        const SizedBox(width: 3),
        Text(value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: _TD.graphite,
                fontSize: 11.2,
                fontWeight: FontWeight.w500,
                height: 1)),
      ]),
    );
  }

  Widget _footerMetric(IconData icon, String text) {
    return Expanded(
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, color: _TD.graphiteSoft, size: 12),
      const SizedBox(width: 4),
      Flexible(
          child: Text(text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: _TD.graphite,
                  fontSize: 11.2,
                  fontWeight: FontWeight.w600,
                  height: 1))),
    ]));
  }

  Widget _calendarCollapsedPreview(
      List<TrackerSessionModel> sessions, List<TrackerSessionModel> filtered) {
    final selected = widget.selectedSession;
    final source = filtered.isNotEmpty ? filtered : _sortedSessions(sessions);
    final shown = source.take(6).toList(growable: false);
    final selectedDayPlayers = filtered
        .map((s) {
          final id = s.playerId ?? _technicalPlayerId(s.playerName);
          return id == null ? _sessionPlayerLabel(s) : 'id:$id';
        })
        .toSet()
        .length;
    final totalDistance = filtered.fold<double>(0, (a, s) => a + s.distanceM);
    final sprintCount = filtered.fold<int>(0, (a, s) => a + s.sprintCount);
    return Container(
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 7),
          child: Row(children: [
            Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: _TD.greenSoft,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _TD.greenBorder)),
                child: const Icon(Icons.calendar_month_rounded,
                    color: _TD.green, size: 16)),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(_allDates ? 'Все даты' : _formatDay(_selectedDate),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: _TD.text,
                          fontSize: 13.4,
                          fontWeight: FontWeight.w700)),
                  Text(
                      '${filtered.length} сессий · $selectedDayPlayers игроков · ${(totalDistance / 1000).toStringAsFixed(2)} км · $sprintCount спр.',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: _TD.muted,
                          fontSize: 11.0,
                          fontWeight: FontWeight.w600)),
                ])),
            const SizedBox(width: 8),
            _DarkActionButton(
                icon: Icons.calendar_today_rounded,
                label: 'Календарь',
                primary: true,
                onTap: () => _setCalendarExpanded(true)),
          ]),
        ),
        const Divider(height: 1, color: _TD.borderStrong),
        Expanded(
          child: shown.isEmpty
              ? _DarkEmpty(
                  icon: Icons.event_busy_rounded,
                  text: _allDates
                      ? 'Нет сессий для отображения.'
                      : 'На ${_formatDay(_selectedDate)} нет сохранённых GPS-сессий.')
              : ListView.separated(
                  padding: const EdgeInsets.all(8),
                  scrollDirection: Axis.horizontal,
                  itemCount: shown.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final s = shown[i];
                    return _sessionChip(
                        s, selected?.id == s.id || (selected == null && i == 0),
                        width: 210);
                  },
                ),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TrackerSessionModel>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            snapshot.data == null) {
          return const _DarkCard(
              title: '',
              subtitle: '',
              child: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return _DarkCard(
            title: '',
            subtitle: '',
            child: _DarkError(
                error: '${snapshot.error}',
                onRetry: () => setState(() => _future = widget.api.loadSessions(
                    teamId: widget.teamId, playerId: widget.playerId))),
          );
        }
        final sessions = snapshot.data ?? const <TrackerSessionModel>[];
        if (sessions.isEmpty) {
          return const _DarkCard(
              title: '',
              subtitle: '',
              child: _DarkEmpty(
                  icon: Icons.storage_rounded,
                  text:
                      'Сессии появятся после Live или сохранения GPS-записи.'));
        }
        return Container(
          decoration: const BoxDecoration(color: Colors.white),
          child: LayoutBuilder(
            builder: (context, box) {
              final splitPicker =
                  widget.calendarExpanded && box.maxWidth >= 720;
              if (splitPicker) {
                final calendarWidth =
                    math.min(520.0, math.max(380.0, box.maxWidth * .40));
                return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: calendarWidth,
                        child: _cmrCalendarGrid(
                          sessions,
                          _firstDate(sessions),
                          _lastDate(sessions),
                          () {},
                          () {},
                        ),
                      ),
                      const _WorkspacePaneDivider.vertical(),
                      Expanded(child: _calendarDaySessionsPanel(sessions)),
                    ]);
              }

              final headerMode = box.maxWidth >= 760 && box.maxHeight <= 340;
              if (headerMode) {
                final sessionsWidth =
                    math.min(680.0, math.max(460.0, box.maxWidth * .56));
                return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _cmrCalendarGrid(
                          sessions,
                          _firstDate(sessions),
                          _lastDate(sessions),
                          () {},
                          () {},
                        ),
                      ),
                      const _WorkspacePaneDivider.vertical(),
                      SizedBox(
                          width: sessionsWidth,
                          child: _calendarDaySessionsPanel(sessions)),
                    ]);
              }
              final calendarHeight =
                  math.max(224.0, math.min(260.0, box.maxHeight * .40));
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: calendarHeight,
                      child: _cmrCalendarGrid(
                        sessions,
                        _firstDate(sessions),
                        _lastDate(sessions),
                        () {},
                        () {},
                      ),
                    ),
                    const _WorkspacePaneDivider.horizontal(),
                    Expanded(child: _calendarDaySessionsPanel(sessions)),
                  ]);
            },
          ),
        );
      },
    );
  }
}

String _recordStateLabel(ActionTrackerRecordState state) {
  switch (state) {
    case ActionTrackerRecordState.recording:
      return 'идёт запись';
    case ActionTrackerRecordState.finished:
      return 'готова';
    case ActionTrackerRecordState.ready:
      return 'готово';
    case ActionTrackerRecordState.unknown:
      return 'неизвестно';
  }
}

class _GpsRecordsPane extends StatelessWidget {
  const _GpsRecordsPane({
    required this.records,
    required this.selectedRecord,
    required this.pointsCount,
    required this.onLoad,
  });

  final List<ActionTrackerRecord> records;
  final ActionTrackerRecord? selectedRecord;
  final int pointsCount;
  final ValueChanged<ActionTrackerRecord> onLoad;

  @override
  Widget build(BuildContext context) {
    return _DarkCard(
      title: 'GPS-записи',
      subtitle: selectedRecord == null
          ? '${records.length} записей · ${records.any((r) => r.state == ActionTrackerRecordState.recording) ? 'идёт запись' : 'готово'}'
          : 'Запись ${selectedRecord!.fileId} · $pointsCount точек',
      child: records.isEmpty
          ? const _DarkEmpty(
              icon: Icons.download_rounded,
              text: 'Подключите трекер и загрузите записи.')
          : ListView(
              children: records
                  .map((r) => _DarkListTile(
                        icon: Icons.route_rounded,
                        title: 'Record ${r.fileId}',
                        subtitle:
                            '${r.title} · ${_recordStateLabel(r.state)} · ${r.length} байт${selectedRecord?.fileId == r.fileId ? ' · $pointsCount точек' : ''}',
                        active: selectedRecord?.fileId == r.fileId,
                        trailing: selectedRecord?.fileId == r.fileId
                            ? 'выбрано'
                            : 'загрузить',
                        onTap: () => onLoad(r),
                      ))
                  .toList(),
            ),
    );
  }
}

class _SelectedTrainingReportPane extends StatefulWidget {
  const _SelectedTrainingReportPane({
    required this.session,
    required this.teamId,
    required this.teamName,
    required this.players,
    required this.apiBaseUrl,
    this.onPickSession,
  });

  final TrackerSessionModel? session;
  final int teamId;
  final String teamName;
  final List<TrackerPlayerOption> players;
  final String apiBaseUrl;
  final VoidCallback? onPickSession;

  @override
  State<_SelectedTrainingReportPane> createState() =>
      _SelectedTrainingReportPaneState();
}

class _ReportPlayerPresence {
  const _ReportPlayerPresence({
    required this.playerId,
    required this.name,
    required this.distanceM,
    required this.maxSpeedKmh,
    required this.avgSpeedKmh,
    required this.sprintCount,
    required this.heartRateSamplesCount,
    required this.heartRateAvgBpm,
    required this.heartRateMaxBpm,
    required this.pointsCount,
  });

  final int? playerId;
  final String name;
  final double distanceM;
  final double maxSpeedKmh;
  final double avgSpeedKmh;
  final int sprintCount;
  final int heartRateSamplesCount;
  final double heartRateAvgBpm;
  final double heartRateMaxBpm;
  final int pointsCount;

  bool get hasGps =>
      distanceM > 0 || maxSpeedKmh > 0 || avgSpeedKmh > 0 || pointsCount > 0;
  bool get hasPolar =>
      heartRateSamplesCount > 0 || heartRateAvgBpm > 0 || heartRateMaxBpm > 0;
  bool get hasAny => hasGps || hasPolar;

  String get statusLabel {
    if (hasGps && hasPolar) return 'GPS+HR';
    if (hasGps) return 'GPS';
    if (hasPolar) return 'Polar';
    return 'нет';
  }

  String get subtitle {
    final parts = <String>[];
    if (hasGps) {
      parts.add('${distanceM.toStringAsFixed(0)} м');
      if (maxSpeedKmh > 0) parts.add('${maxSpeedKmh.toStringAsFixed(1)} км/ч');
      if (sprintCount > 0) parts.add('$sprintCount спр.');
    }
    if (hasPolar) {
      parts.add(
          'Polar ${heartRateAvgBpm > 0 ? heartRateAvgBpm.toStringAsFixed(0) : '—'} ср.');
      if (heartRateMaxBpm > 0)
        parts.add('${heartRateMaxBpm.toStringAsFixed(0)} max');
    }
    return parts.isEmpty ? 'нет данных в выбранной сессии' : parts.join(' · ');
  }
}

class _SelectedTrainingReportPaneState
    extends State<_SelectedTrainingReportPane> {
  final Set<int> _selectedPlayerIds = <int>{};
  Set<int> _attachedPlayerIdsForExport = <int>{};
  int? _presenceSessionId;
  Future<List<_ReportPlayerPresence>>? _presenceFuture;
  int? _reportSessionId;
  Future<TrackerTrainingReport>? _reportFuture;

  bool _includeLogo = true;
  bool _includePhotos = true;
  bool _summary = true;
  bool _playersBlock = true;
  bool _locomotor = true;
  bool _mechanics = true;
  bool _internal = true;
  bool _speedChart = true;
  bool _heartRate = true;
  bool _comparison = true;
  bool _zones = true;
  bool _maps = true;
  bool _heatmap = true;
  bool _playerPages = true;
  bool _microcycle = true;
  bool _ai = false;
  int _mobileCompareTab = 0;
  VoidCallback? _mobileOverlayRefresh;

  @override
  void didUpdateWidget(covariant _SelectedTrainingReportPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session?.id != widget.session?.id) {
      _selectedPlayerIds.clear();
      _attachedPlayerIdsForExport = <int>{};
      _presenceSessionId = null;
      _presenceFuture = null;
      _reportSessionId = null;
      _reportFuture = null;
    }
  }

  List<int> get _playerIdsForExport {
    final source = _selectedPlayerIds.isNotEmpty
        ? _selectedPlayerIds
        : _attachedPlayerIdsForExport;
    if (source.isEmpty) return const <int>[];
    return source.where((id) => id > 0).toList(growable: false)..sort();
  }

  List<String> get _sectionsForExport {
    final sections = <String>[];
    if (_summary) sections.add('summary');
    if (_playersBlock) sections.add('players');
    if (_locomotor) sections.add('locomotor');
    if (_mechanics) sections.add('mechanics');
    if (_internal) sections.add('internal');
    if (_speedChart) sections.add('speed');
    if (_heartRate) sections.add('hr');
    if (_comparison) sections.add('comparison');
    if (_zones) sections.add('zones');
    if (_maps) sections.add('maps');
    if (_heatmap) sections.add('heatmap');
    if (_playerPages) sections.add('player_pages');
    if (_microcycle) sections.add('microcycle');
    if (_ai) sections.add('ai');
    return sections.isEmpty ? const <String>['summary'] : sections;
  }

  bool get _includeCharts => _speedChart || _heartRate || _comparison || _zones;

  String _playersLabel() {
    if (_selectedPlayerIds.isEmpty) {
      if (_attachedPlayerIdsForExport.isNotEmpty)
        return 'все прикреплённые (${_attachedPlayerIdsForExport.length})';
      return 'все игроки';
    }
    final count = _selectedPlayerIds.length;
    return '$count ${count == 1 ? 'игрок' : 'игрока'}';
  }

  void _togglePlayer(int id) {
    if (id <= 0) return;
    setState(() {
      if (_selectedPlayerIds.contains(id)) {
        _selectedPlayerIds.remove(id);
      } else {
        _selectedPlayerIds.add(id);
      }
    });
    _mobileOverlayRefresh?.call();
  }

  int? _technicalPlayerId(String? raw) {
    final value = (raw ?? '').trim();
    final match = RegExp(r'^(?:игрок|player)\s*#?(\d+)$', caseSensitive: false)
        .firstMatch(value);
    return match == null ? null : int.tryParse(match.group(1) ?? '');
  }

  int? _boundSessionPlayerId() {
    final s = widget.session;
    if (s == null) return null;
    if (s.playerId != null && s.playerId! > 0) return s.playerId;
    return _technicalPlayerId(s.playerName);
  }

  String _nameKey(String? value) {
    return (value ?? '')
        .trim()
        .toLowerCase()
        .replaceAll('ё', 'е')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  bool _samePlayerName(String? a, String? b) {
    final aa = _nameKey(a);
    final bb = _nameKey(b);
    return aa.isNotEmpty && bb.isNotEmpty && aa == bb;
  }

  Future<TrackerTrainingReport> _loadTrainingReport(
      TrackerSessionModel session) {
    final api = TrackerTrainingReportApi(apiBaseUrl: widget.apiBaseUrl);
    return api.loadTrainingReport(sessionId: session.id, teamId: widget.teamId);
  }

  Future<TrackerTrainingReport> _reportForSession(TrackerSessionModel session) {
    if (_reportSessionId != session.id || _reportFuture == null) {
      _reportSessionId = session.id;
      _reportFuture = _loadTrainingReport(session);
    }
    return _reportFuture!;
  }

  List<_ReportPlayerPresence> _presenceFromReport(
      TrackerTrainingReport report) {
    TrackerPlayerOption? rosterById(int? id) {
      if (id == null || id <= 0) return null;
      for (final player in widget.players) {
        if (player.id == id) return player;
      }
      return null;
    }

    TrackerPlayerOption? rosterByName(String? raw) {
      final key = _nameKey(raw);
      if (key.isEmpty || _technicalPlayerId(raw) != null) return null;
      for (final player in widget.players) {
        if (_nameKey(player.name) == key) return player;
      }
      return null;
    }

    String resolvedName(int? id, String? raw) {
      final technicalId = _technicalPlayerId(raw);
      final roster =
          rosterById(id) ?? rosterById(technicalId) ?? rosterByName(raw);
      if (roster != null && roster.name.trim().isNotEmpty)
        return roster.name.trim();
      final clean = (raw ?? '').trim();
      if (clean.isNotEmpty &&
          _technicalPlayerId(clean) == null &&
          clean.toLowerCase() != 'игрок') return clean;
      final fallbackId = id ?? technicalId;
      return fallbackId == null ? 'Игрок без имени' : 'ID $fallbackId';
    }

    final source =
        report.players.isNotEmpty ? report.players : report.diagnosticPlayers;
    final rows = source
        .map((p) => _ReportPlayerPresence(
              playerId: p.playerId ?? _technicalPlayerId(p.name),
              name: resolvedName(p.playerId, p.name),
              distanceM: p.distanceM,
              maxSpeedKmh: p.maxSpeedKmh,
              avgSpeedKmh: p.avgSpeedKmh,
              sprintCount: p.sprintCount,
              heartRateSamplesCount: p.heartRateSamplesCount,
              heartRateAvgBpm: p.heartRateAvgBpm,
              heartRateMaxBpm: p.heartRateMaxBpm,
              pointsCount: p.pointsCount,
            ))
        .where((p) =>
            p.hasAny || (p.playerId ?? 0) > 0 || p.name.trim().isNotEmpty)
        .toList(growable: true);

    final knownIds = rows
        .map((e) => e.playerId)
        .whereType<int>()
        .where((id) => id > 0)
        .toSet();
    final knownNames =
        rows.map((e) => _nameKey(e.name)).where((e) => e.isNotEmpty).toSet();
    final hrByPlayer = <String, List<TrackerHeartRatePoint>>{};
    for (final point in report.heartRateTimeline.where((e) => e.bpm > 0)) {
      final technicalId = _technicalPlayerId(point.playerName);
      final id = point.playerId ?? technicalId;
      final key =
          (id ?? 0) > 0 ? 'id:$id' : 'name:${_nameKey(point.playerName)}';
      if (key == 'name:') continue;
      hrByPlayer.putIfAbsent(key, () => <TrackerHeartRatePoint>[]).add(point);
    }
    for (final entry in hrByPlayer.entries) {
      final sample = entry.value.first;
      final id = sample.playerId ?? _technicalPlayerId(sample.playerName);
      final name = resolvedName(id, sample.playerName);
      final nameKey = _nameKey(name);
      if ((id ?? 0) > 0 ? knownIds.contains(id) : knownNames.contains(nameKey))
        continue;
      final values = entry.value
          .map((e) => e.bpm)
          .where((e) => e > 0)
          .toList(growable: false);
      rows.add(_ReportPlayerPresence(
        playerId: id,
        name: name,
        distanceM: 0,
        maxSpeedKmh: 0,
        avgSpeedKmh: 0,
        sprintCount: 0,
        heartRateSamplesCount: values.length,
        heartRateAvgBpm:
            values.isEmpty ? 0 : values.reduce((a, b) => a + b) / values.length,
        heartRateMaxBpm:
            values.isEmpty ? 0 : values.reduce(math.max).toDouble(),
        pointsCount: 0,
      ));
    }
    return rows;
  }

  Future<List<_ReportPlayerPresence>> _loadPlayerPresence(
      TrackerSessionModel session) async {
    return _presenceFromReport(await _reportForSession(session));
  }

  Future<List<_ReportPlayerPresence>> _presenceForSession(
      TrackerSessionModel session) {
    if (_presenceSessionId != session.id || _presenceFuture == null) {
      _presenceSessionId = session.id;
      _presenceFuture = _loadPlayerPresence(session);
    }
    return _presenceFuture!;
  }

  _ReportPlayerPresence? _presenceForPlayer(
      TrackerPlayerOption player, List<_ReportPlayerPresence> reportPlayers) {
    for (final row in reportPlayers) {
      if ((row.playerId ?? 0) > 0 && row.playerId == player.id) return row;
    }
    final playerName = _nameKey(player.name);
    if (playerName.isEmpty) return null;
    for (final row in reportPlayers) {
      if (_nameKey(row.name) == playerName) return row;
    }
    return null;
  }

  bool _playerAttachedToSession(TrackerPlayerOption player,
      [List<_ReportPlayerPresence> reportPlayers =
          const <_ReportPlayerPresence>[]]) {
    if (_presenceForPlayer(player, reportPlayers) != null) return true;
    final s = widget.session;
    if (s == null) return false;
    final boundId = _boundSessionPlayerId();
    if (boundId != null && boundId > 0) return boundId == player.id;
    return _samePlayerName(s.playerName, player.name);
  }

  String _playerAttachLabel(TrackerPlayerOption player,
      [List<_ReportPlayerPresence> reportPlayers =
          const <_ReportPlayerPresence>[]]) {
    final presence = _presenceForPlayer(player, reportPlayers);
    if (presence != null && presence.hasAny) return presence.statusLabel;
    if (_playerAttachedToSession(player, reportPlayers)) return 'прикр.';
    return 'нет';
  }

  bool _playerHasSessionData(TrackerPlayerOption player,
      [List<_ReportPlayerPresence> reportPlayers =
          const <_ReportPlayerPresence>[]]) {
    final presence = _presenceForPlayer(player, reportPlayers);
    if (presence != null) return presence.hasAny;
    final s = widget.session;
    if (s == null) return false;
    final boundId = _boundSessionPlayerId();
    if (boundId != null && boundId > 0) return boundId == player.id;
    if (_samePlayerName(s.playerName, player.name)) return true;
    return false;
  }

  String _playerDataSubtitle(TrackerPlayerOption player,
      [List<_ReportPlayerPresence> reportPlayers =
          const <_ReportPlayerPresence>[]]) {
    final presence = _presenceForPlayer(player, reportPlayers);
    if (presence != null) return presence.subtitle;
    final s = widget.session;
    if (s == null) return 'сессия не выбрана';
    if (_playerHasSessionData(player, reportPlayers)) {
      return '${s.distanceM.toStringAsFixed(0)} м · ${s.maxSpeedKmh.toStringAsFixed(1)} км/ч · ${s.sprintCount} спр.';
    }
    return 'нет данных в выбранной сессии';
  }

  List<TrackerPlayerOption> _playersSortedForExport(
      List<TrackerPlayerOption> players,
      [List<_ReportPlayerPresence> reportPlayers =
          const <_ReportPlayerPresence>[]]) {
    final list = List<TrackerPlayerOption>.from(players);
    list.sort((a, b) {
      final ap = _presenceForPlayer(a, reportPlayers);
      final bp = _presenceForPlayer(b, reportPlayers);
      final aa = _playerAttachedToSession(a, reportPlayers) ? 0 : 1;
      final ba = _playerAttachedToSession(b, reportPlayers) ? 0 : 1;
      if (aa != ba) return aa.compareTo(ba);
      final ad = _playerHasSessionData(a, reportPlayers) ? 0 : 1;
      final bd = _playerHasSessionData(b, reportPlayers) ? 0 : 1;
      if (ad != bd) return ad.compareTo(bd);
      final aPolar = ap?.hasPolar == true ? 0 : 1;
      final bPolar = bp?.hasPolar == true ? 0 : 1;
      if (aPolar != bPolar) return aPolar.compareTo(bPolar);
      final aGps = ap?.hasGps == true ? 0 : 1;
      final bGps = bp?.hasGps == true ? 0 : 1;
      if (aGps != bGps) return aGps.compareTo(bGps);
      return a.name.compareTo(b.name);
    });
    return list;
  }

  Future<void> _openExport(String format) async {
    final s = widget.session;
    if (s == null || s.id <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Сначала выберите сессию слева в списке или календаре.')));
      return;
    }

    final api = TrackerTrainingReportApi(apiBaseUrl: widget.apiBaseUrl);
    final sections = _sectionsForExport;
    final uri = format == 'excel' || format == 'csv'
        ? api.csvExportUri(
            sessionId: s.id,
            teamId: widget.teamId,
            playerIds: _playerIdsForExport,
            sections: sections,
          )
        : api.pdfExportUri(
            sessionId: s.id,
            teamId: widget.teamId,
            playerIds: _playerIdsForExport,
            sections: sections,
            includeMaps: _maps,
            includeHeatmap: _heatmap,
            includeCharts: _includeCharts,
            includePlayerPages: _playerPages,
            includeLogo: _includeLogo,
            includePhotos: _includePhotos,
          );

    if (!mounted) return;
    final isPhone = MediaQuery.sizeOf(context).width < 620;
    if (isPhone) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => DraggableScrollableSheet(
          initialChildSize: .88,
          minChildSize: .58,
          maxChildSize: .98,
          builder: (sheetContext, controller) => Container(
            clipBehavior: Clip.antiAlias,
            decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
            child: Column(children: [
              Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(top: 8, bottom: 6),
                  decoration: BoxDecoration(
                      color: _TD.borderStrong,
                      borderRadius: BorderRadius.circular(99))),
              Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: const BoxDecoration(
                    border: Border(
                        bottom: BorderSide(color: _TD.softLine, width: .7))),
                child: Row(children: [
                  Icon(
                      format == 'pdf'
                          ? Icons.picture_as_pdf_rounded
                          : Icons.table_chart_rounded,
                      color: _TD.green,
                      size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(
                          format == 'pdf' ? 'PDF отчёт' : 'Excel / CSV отчёт',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: _TD.text,
                              fontSize: 13.2,
                              fontWeight: FontWeight.w700))),
                  _NoHoverTap(
                      onTap: () => Navigator.of(sheetContext).pop(),
                      child: const SizedBox(
                          width: 34,
                          height: 34,
                          child: Icon(Icons.close_rounded,
                              color: _TD.dim, size: 20))),
                ]),
              ),
              Expanded(child: TrackerExportViewer(uri: uri)),
            ]),
          ),
        ),
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(10),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_TD.dialogRadius),
        ),
        child: SizedBox(
          width: math.min(1040, MediaQuery.sizeOf(dialogContext).width - 36),
          height: math.min(760, MediaQuery.sizeOf(dialogContext).height - 36),
          child: Column(children: [
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: _TD.borderStrong))),
              child: Row(children: [
                Icon(
                    format == 'pdf'
                        ? Icons.picture_as_pdf_rounded
                        : Icons.table_chart_rounded,
                    color: _TD.green,
                    size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    format == 'pdf' ? 'PDF отчёт' : 'Excel / CSV отчёт',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: _TD.text,
                        fontSize: 13.4,
                        fontWeight: FontWeight.w700),
                  ),
                ),
                _DarkActionButton(
                    icon: Icons.close_rounded,
                    label: 'Закрыть',
                    onTap: () => Navigator.of(dialogContext).pop()),
              ]),
            ),
            Expanded(child: TrackerExportViewer(uri: uri)),
          ]),
        ),
      ),
    );
  }

  Widget _pill(
      {required IconData icon, required String title, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
          color: _TD.soft2, borderRadius: BorderRadius.circular(6)),
      child: Row(children: [
        Icon(icon, color: _TD.green, size: 13),
        const SizedBox(width: 5),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: _TD.dim, fontSize: 10.4, fontWeight: FontWeight.w700)),
          const SizedBox(height: 1),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: _TD.text,
                  fontSize: 11.8,
                  fontWeight: FontWeight.w700)),
        ])),
      ]),
    );
  }

  Widget _group(
      {required String title,
      required String subtitle,
      required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(6)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(9, 7, 9, 6),
          decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _TD.softLine))),
          child: Row(children: [
            Expanded(
                child: Text(title,
                    style: const TextStyle(
                        color: _TD.text,
                        fontSize: 12.6,
                        fontWeight: FontWeight.w700))),
            Flexible(
                child: Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        color: _TD.dim,
                        fontSize: 11.0,
                        fontWeight: FontWeight.w700))),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1) const SizedBox(height: 5),
              ],
            ],
          ),
        ),
      ]),
    );
  }

  Widget _playerChip(
      {required String label,
      required String subtitle,
      String? avatar,
      required bool active,
      required VoidCallback onTap,
      bool all = false,
      bool hasData = true,
      String? statusLabel}) {
    return _NoHoverTap(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
        decoration: BoxDecoration(
          color: active ? _TD.greenSoft : _TD.card2,
          borderRadius: BorderRadius.circular(6),
          border:
              Border.all(color: active ? _TD.greenBorder : _TD.borderStrong),
        ),
        child: Row(children: [
          if (all)
            Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: active ? _TD.green : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: active ? _TD.green : _TD.borderStrong)),
                child: Icon(Icons.groups_rounded,
                    color: active ? Colors.white : _TD.green, size: 15))
          else
            _PlayerAvatarDark(
                url: avatar,
                initials: _playerInitials(label),
                size: 24,
                active: active),
          const SizedBox(width: 7),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: _TD.text,
                        fontSize: 11.2,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: _TD.muted,
                        fontSize: 10.4,
                        fontWeight: FontWeight.w700)),
              ])),
          const SizedBox(width: 6),
          Container(
            height: 19,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: hasData ? _TD.greenSoft : _TD.soft2,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(
                  color: hasData ? _TD.greenBorder : _TD.borderStrong),
            ),
            child: Text(statusLabel ?? (hasData ? 'данные' : 'нет'),
                style: TextStyle(
                    color: hasData ? _TD.green : _TD.dim,
                    fontSize: 10.4,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 6),
          Icon(active ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: active ? _TD.green : _TD.dim, size: 16),
        ]),
      ),
    );
  }

  Widget _playerStrip(List<TrackerPlayerOption> players) {
    final chips = <Widget>[
      SizedBox(
        width: 172,
        child: _playerChip(
          label: 'Все игроки',
          subtitle: '${players.length} в составе',
          active: _selectedPlayerIds.isEmpty,
          all: true,
          onTap: () => setState(() => _selectedPlayerIds.clear()),
        ),
      ),
      for (final p in players)
        SizedBox(
          width: 184,
          child: _playerChip(
            label: p.name,
            subtitle: '№${p.number ?? '—'} · ${p.position ?? 'позиция'}',
            avatar: p.avatar,
            active:
                _selectedPlayerIds.isEmpty || _selectedPlayerIds.contains(p.id),
            onTap: () => _togglePlayer(p.id),
          ),
        ),
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.swipe_rounded, color: _TD.green, size: 14),
        const SizedBox(width: 6),
        Expanded(
            child: Text(
                _selectedPlayerIds.isEmpty
                    ? 'Выгружается вся команда. Прокрутите вправо, чтобы оставить отдельных игроков.'
                    : 'Выбрано: ${_playersLabel()}. Нажмите «Все игроки», чтобы вернуть команду.',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: _TD.muted,
                    fontSize: 11.0,
                    fontWeight: FontWeight.w700))),
      ]),
      const SizedBox(height: 6),
      SizedBox(
        height: 48,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: chips.length,
          separatorBuilder: (_, __) => const SizedBox(width: 6),
          itemBuilder: (_, i) => chips[i],
        ),
      ),
    ]);
  }

  Widget _playersExportGrid(
    List<TrackerPlayerOption> players, {
    List<_ReportPlayerPresence> reportPlayers = const <_ReportPlayerPresence>[],
    bool loadingPresence = false,
    String? presenceError,
  }) {
    if (players.isEmpty) {
      return const _DarkEmpty(
          icon: Icons.groups_rounded,
          text: 'В составе нет игроков для выбора.');
    }
    final ordered = _playersSortedForExport(players, reportPlayers);
    final attached = ordered
        .where((p) => _playerAttachedToSession(p, reportPlayers))
        .toList(growable: false);
    final visible = attached.isNotEmpty ? attached : ordered;
    final withData =
        attached.where((p) => _playerHasSessionData(p, reportPlayers)).length;
    final gpsCount = attached
        .where((p) => _presenceForPlayer(p, reportPlayers)?.hasGps == true)
        .length;
    final polarCount = attached
        .where((p) => _presenceForPlayer(p, reportPlayers)?.hasPolar == true)
        .length;
    final s = widget.session;
    final sessionUnbound = s != null &&
        reportPlayers.isEmpty &&
        _boundSessionPlayerId() == null &&
        s.distanceM > 0;
    final attachedCount = attached.length;
    final hiddenCount = math.max(0, players.length - visible.length);
    final listHeight = math.min(
        292.0, 42.0 * (visible.length + 1) + (hiddenCount > 0 ? 22.0 : 0));

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.link_rounded, color: _TD.green, size: 14),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            loadingPresence
                ? 'Проверяю, кто прикреплён к сессии по GPS и Polar H10…'
                : presenceError != null
                    ? 'Не удалось прочитать детальный отчёт. Показываю привязку из выбранной сессии.'
                    : sessionUnbound
                        ? 'У сессии есть командные данные, но сервер не вернул привязку к игрокам.'
                        : '$attachedCount прикреплено к сессии · $withData с данными · GPS $gpsCount · Polar $polarCount.',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: _TD.muted, fontSize: 11.0, fontWeight: FontWeight.w700),
          ),
        ),
      ]),
      if (loadingPresence) ...[
        const SizedBox(height: 6),
        const LinearProgressIndicator(
            minHeight: 2, color: _TD.green, backgroundColor: _TD.softLine),
      ],
      if (presenceError != null) ...[
        const SizedBox(height: 6),
        Text(presenceError,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: _TD.orange,
                fontSize: 10.4,
                fontWeight: FontWeight.w600)),
      ],
      const SizedBox(height: 7),
      SizedBox(
        height: listHeight,
        child: ListView.separated(
          itemCount: visible.length + 1 + (hiddenCount > 0 ? 1 : 0),
          separatorBuilder: (_, __) => const SizedBox(height: 4),
          itemBuilder: (_, i) {
            if (i == 0) {
              return _playerChip(
                label: attached.isNotEmpty
                    ? 'Все прикреплённые к сессии'
                    : 'Все игроки с данными',
                subtitle: sessionUnbound
                    ? 'командная сессия · ${((s?.distanceM ?? 0) / 1000).toStringAsFixed(2)} км'
                    : attached.isNotEmpty
                        ? '$attachedCount прикреплено · $withData с данными · GPS $gpsCount · Polar $polarCount'
                        : 'привязка не найдена · показываю состав команды',
                active: _selectedPlayerIds.isEmpty,
                all: true,
                hasData: attached.isNotEmpty || withData > 0 || sessionUnbound,
                statusLabel: _selectedPlayerIds.isEmpty ? 'все' : 'сброс',
                onTap: () => setState(() => _selectedPlayerIds.clear()),
              );
            }
            final infoIndex = i - 1;
            if (hiddenCount > 0 && infoIndex == visible.length) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(4, 2, 4, 0),
                child: Row(children: [
                  const Icon(Icons.info_outline_rounded,
                      color: _TD.dim, size: 12),
                  const SizedBox(width: 5),
                  Expanded(
                      child: Text(
                          '$hiddenCount игроков состава не прикреплены к этой сессии и скрыты из выгрузки.',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: _TD.dim,
                              fontSize: 10.4,
                              fontWeight: FontWeight.w700))),
                ]),
              );
            }
            final p = visible[infoIndex];
            final presence = _presenceForPlayer(p, reportPlayers);
            final hasData = _playerHasSessionData(p, reportPlayers);
            final attachedToSession =
                _playerAttachedToSession(p, reportPlayers);
            return _playerChip(
              label: p.name,
              subtitle: attachedToSession
                  ? _playerDataSubtitle(p, reportPlayers)
                  : 'не прикреплён к выбранной сессии',
              avatar: p.avatar,
              active: _selectedPlayerIds.isEmpty ||
                  _selectedPlayerIds.contains(p.id),
              hasData: hasData || attachedToSession,
              statusLabel:
                  presence?.statusLabel ?? _playerAttachLabel(p, reportPlayers),
              onTap: () => _togglePlayer(p.id),
            );
          },
        ),
      ),
    ]);
  }

  Widget _toggle(
      {required IconData icon,
      required String title,
      required String subtitle,
      required bool value,
      required ValueChanged<bool> onChanged}) {
    return _NoHoverTap(
      onTap: () => onChanged(!value),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: value ? _TD.greenSoft : _TD.card2,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: value ? _TD.greenBorder : _TD.borderStrong),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(value ? Icons.check_circle_rounded : icon,
              color: value ? _TD.green : _TD.graphite, size: 14),
          const SizedBox(width: 8),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: _TD.text,
                        fontSize: 11.2,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: _TD.muted,
                        fontSize: 10.4,
                        fontWeight: FontWeight.w700,
                        height: 1.10)),
              ])),
        ]),
      ),
    );
  }

  Widget _reportBlock(
      {required String title, String? subtitle, required Widget child}) {
    return Container(
      decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
              right: BorderSide(color: _TD.borderStrong, width: .7),
              bottom: BorderSide(color: _TD.borderStrong, width: .7))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: const BoxDecoration(
              border:
                  Border(bottom: BorderSide(color: _TD.softLine, width: .7))),
          child: Row(children: [
            Expanded(
                flex: 4,
                child: Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: _TD.text,
                        fontSize: 11.8,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -.08,
                        height: 1))),
            if ((subtitle ?? '').trim().isNotEmpty)
              Flexible(
                  flex: 3,
                  child: Text(subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          color: _TD.muted,
                          fontSize: 10.4,
                          fontWeight: FontWeight.w500,
                          height: 1))),
          ]),
        ),
        Expanded(child: child),
      ]),
    );
  }

  Widget _statusPill(String label, {bool selected = true}) {
    final lower = label.toLowerCase();
    final color = lower.contains('polar')
        ? _TD.violet
        : label == 'нет'
            ? _TD.dim
            : _TD.green;
    final bg = lower.contains('polar')
        ? const Color(0xFFF5F0FF)
        : label == 'нет'
            ? _TD.soft2
            : _TD.greenSoft;
    return Container(
      height: 21,
      constraints: const BoxConstraints(minWidth: 42),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: color.withOpacity(.08), width: .6)),
      child: Text(label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              color: color,
              fontSize: 11.2,
              fontWeight: FontWeight.w600,
              height: 1)),
    );
  }

  Widget _attachedPlayersCard(
    List<TrackerPlayerOption> players, {
    List<_ReportPlayerPresence> reportPlayers = const <_ReportPlayerPresence>[],
    bool loadingPresence = false,
    String? presenceError,
  }) {
    if (players.isEmpty) {
      _attachedPlayerIdsForExport = <int>{};
      return const _DarkEmpty(
          icon: Icons.groups_rounded,
          text: 'В составе нет игроков для выбора.');
    }
    final ordered = _playersSortedForExport(players, reportPlayers);
    final attached = ordered
        .where((p) => _playerAttachedToSession(p, reportPlayers))
        .toList(growable: false);
    // В отчёте показываем только участников выбранной сессии.
    // Игроки всего состава здесь больше не появляются.
    final visible = attached;
    _attachedPlayerIdsForExport =
        attached.map((p) => p.id).where((id) => id > 0).toSet();
    final withData =
        attached.where((p) => _playerHasSessionData(p, reportPlayers)).length;

    if (!loadingPresence && visible.isEmpty) {
      _attachedPlayerIdsForExport = <int>{};
      return const _DarkEmpty(
        icon: Icons.group_off_rounded,
        text:
            'В выбранной сессии нет прикреплённых игроков. Проверьте привязку GPS / Polar к игрокам.',
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (loadingPresence)
        const LinearProgressIndicator(
            minHeight: 2, color: _TD.green, backgroundColor: _TD.softLine),
      if (presenceError != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          child: Text('Ошибка детализации: $presenceError',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: _TD.orange,
                  fontSize: 11.2,
                  fontWeight: FontWeight.w600,
                  height: 1)),
        ),
      Expanded(
        child: ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: visible.length,
          itemBuilder: (_, i) {
            final p = visible[i];
            final presence = _presenceForPlayer(p, reportPlayers);
            final attachedToSession =
                _playerAttachedToSession(p, reportPlayers);
            final hasData = _playerHasSessionData(p, reportPlayers);
            final active =
                _selectedPlayerIds.isEmpty || _selectedPlayerIds.contains(p.id);
            return _NoHoverTap(
              onTap: () => _togglePlayer(p.id),
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 9),
                decoration: BoxDecoration(
                  color: active ? _TD.greenSoft.withOpacity(.62) : Colors.white,
                  border: Border(
                    left: BorderSide(
                        color: active ? _TD.green : Colors.transparent,
                        width: active ? 2 : 0),
                    bottom: const BorderSide(color: _TD.softLine, width: .7),
                  ),
                ),
                child: Row(children: [
                  _PlayerAvatarDark(
                      url: p.avatar,
                      initials: _playerInitials(p.name),
                      size: 25,
                      active: active),
                  const SizedBox(width: 7),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                        Text(p.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: _TD.text,
                                fontSize: 11.0,
                                fontWeight: FontWeight.w600,
                                height: 1.0)),
                        const SizedBox(height: 2),
                        Text(
                            attachedToSession
                                ? _playerDataSubtitle(p, reportPlayers)
                                : 'не прикреплён к сессии',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: _TD.muted,
                                fontSize: 11.2,
                                fontWeight: FontWeight.w500,
                                height: 1.0)),
                      ])),
                  const SizedBox(width: 3),
                  _statusPill(presence?.statusLabel ??
                      _playerAttachLabel(p, reportPlayers)),
                  SizedBox(
                      width: 16,
                      child: Icon(
                          active && (hasData || attachedToSession)
                              ? Icons.check_circle_rounded
                              : Icons.circle_outlined,
                          color: active && (hasData || attachedToSession)
                              ? _TD.green
                              : _TD.dim,
                          size: 12)),
                ]),
              ),
            );
          },
        ),
      ),
      Container(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: _TD.softLine, width: .7))),
        child: Row(children: [
          const Icon(Icons.info_outline_rounded, color: _TD.dim, size: 11),
          const SizedBox(width: 4),
          Expanded(
              child: Text(
                  attached.isEmpty
                      ? 'Привязка не найдена: можно выбрать игроков вручную.'
                      : 'По умолчанию выгружается $withData из ${attached.length} игроков с данными; ручной выбор выше меняет PDF/Excel.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: _TD.muted,
                      fontSize: 11.2,
                      fontWeight: FontWeight.w600,
                      height: 1))),
        ]),
      ),
    ]);
  }

  Widget _reportOptionTile(
      {required IconData icon,
      required String title,
      required bool value,
      required ValueChanged<bool> onChanged}) {
    return _NoHoverTap(
      onTap: () {
        onChanged(!value);
        _mobileOverlayRefresh?.call();
      },
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
            color: value ? _TD.greenSoft.withOpacity(.68) : Colors.white,
            border: Border.all(
                color: value ? _TD.greenBorder : _TD.softLine, width: .7)),
        child: Row(children: [
          Icon(icon, color: value ? _TD.green : _TD.graphiteSoft, size: 15),
          const SizedBox(width: 7),
          Expanded(
              child: Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: _TD.text,
                      fontSize: 11.0,
                      fontWeight: FontWeight.w600,
                      height: 1))),
          Icon(value ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: value ? _TD.green : _TD.dim, size: 15),
        ]),
      ),
    );
  }

  Widget _sectionColumn(String title, List<Widget> items) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: _TD.softLine, width: .7)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          height: 24,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.centerLeft,
          decoration: const BoxDecoration(
              border:
                  Border(bottom: BorderSide(color: _TD.softLine, width: .7))),
          child: Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: _TD.muted,
                  fontSize: 11.0,
                  fontWeight: FontWeight.w600,
                  height: 1)),
        ),
        Expanded(
          child: ListView.separated(
            padding: EdgeInsets.zero,
            physics: const ClampingScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: _TD.softLine),
            itemBuilder: (_, i) => items[i],
          ),
        ),
      ]),
    );
  }

  Widget _sectionsCard() {
    final selectedCount = _sectionsForExport.length;
    final baseItems = <Widget>[
      _reportOptionTile(
          icon: Icons.fact_check_rounded,
          title: 'Сводка команды',
          value: _summary,
          onChanged: (v) => setState(() => _summary = v)),
      _reportOptionTile(
          icon: Icons.groups_rounded,
          title: 'Таблицы игроков',
          value: _playersBlock,
          onChanged: (v) => setState(() => _playersBlock = v)),
      _reportOptionTile(
          icon: Icons.badge_rounded,
          title: 'Листы игроков',
          value: _playerPages,
          onChanged: (v) => setState(() => _playerPages = v)),
      _reportOptionTile(
          icon: Icons.directions_run_rounded,
          title: 'Локомоторика',
          value: _locomotor,
          onChanged: (v) => setState(() => _locomotor = v)),
      _reportOptionTile(
          icon: Icons.compare_arrows_rounded,
          title: 'Механика',
          value: _mechanics,
          onChanged: (v) => setState(() => _mechanics = v)),
      _reportOptionTile(
          icon: Icons.fitness_center_rounded,
          title: 'Внутренняя нагрузка',
          value: _internal,
          onChanged: (v) => setState(() => _internal = v)),
      _reportOptionTile(
          icon: Icons.favorite_rounded,
          title: 'Пульс Polar',
          value: _heartRate,
          onChanged: (v) => setState(() => _heartRate = v)),
    ];
    final visualItems = <Widget>[
      _reportOptionTile(
          icon: Icons.route_rounded,
          title: 'Карта перемещений',
          value: _maps,
          onChanged: (v) => setState(() => _maps = v)),
      _reportOptionTile(
          icon: Icons.local_fire_department_rounded,
          title: 'Тепловая карта',
          value: _heatmap,
          onChanged: (v) => setState(() => _heatmap = v)),
      _reportOptionTile(
          icon: Icons.speed_rounded,
          title: 'Скорость',
          value: _speedChart,
          onChanged: (v) => setState(() => _speedChart = v)),
      _reportOptionTile(
          icon: Icons.flash_on_rounded,
          title: 'Спринты и зоны',
          value: _zones,
          onChanged: (v) => setState(() => _zones = v)),
      _reportOptionTile(
          icon: Icons.compare_rounded,
          title: 'Сравнение игроков',
          value: _comparison,
          onChanged: (v) => setState(() => _comparison = v)),
      _reportOptionTile(
          icon: Icons.calendar_view_week_rounded,
          title: 'Микроцикл',
          value: _microcycle,
          onChanged: (v) => setState(() => _microcycle = v)),
      _reportOptionTile(
          icon: Icons.auto_awesome_rounded,
          title: 'ИИ анализ',
          value: _ai,
          onChanged: (v) => setState(() => _ai = v)),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: _TD.softLine, width: .7))),
        child: Row(children: [
          Expanded(
              child: Text('Выберите, что попадёт в PDF / Excel',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: _TD.text,
                      fontSize: 11.0,
                      fontWeight: FontWeight.w700,
                      height: 1))),
          _NoHoverTap(
            onTap: () {
              setState(() {
                _summary = true;
                _playersBlock = true;
                _locomotor = true;
                _mechanics = true;
                _internal = true;
                _speedChart = true;
                _heartRate = true;
                _comparison = true;
                _zones = true;
                _maps = true;
                _heatmap = true;
                _playerPages = true;
                _microcycle = true;
                _ai = true;
              });
              _mobileOverlayRefresh?.call();
            },
            child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: Text('всё',
                    style: TextStyle(
                        color: _TD.green,
                        fontSize: 11.0,
                        fontWeight: FontWeight.w700,
                        height: 1))),
          ),
          _NoHoverTap(
            onTap: () {
              setState(() {
                _summary = true;
                _playersBlock = true;
                _locomotor = true;
                _mechanics = false;
                _internal = false;
                _speedChart = false;
                _heartRate = false;
                _comparison = false;
                _zones = false;
                _maps = false;
                _heatmap = false;
                _playerPages = false;
                _microcycle = false;
                _ai = false;
              });
              _mobileOverlayRefresh?.call();
            },
            child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                child: Text('минимум',
                    style: TextStyle(
                        color: _TD.dim,
                        fontSize: 11.0,
                        fontWeight: FontWeight.w700,
                        height: 1))),
          ),
        ]),
      ),
      Expanded(
        child: LayoutBuilder(builder: (context, box) {
          Widget tabList(List<Widget> items) => ListView.separated(
                padding: EdgeInsets.zero,
                physics: const ClampingScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: _TD.softLine),
                itemBuilder: (_, i) => items[i],
              );
          if (box.maxWidth < 430) {
            return DefaultTabController(
              length: 2,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      height: 34,
                      decoration: const BoxDecoration(
                          color: Colors.white,
                          border: Border(
                              bottom:
                                  BorderSide(color: _TD.softLine, width: .7))),
                      child: const TabBar(
                        labelColor: _TD.green,
                        unselectedLabelColor: _TD.muted,
                        indicatorColor: _TD.green,
                        indicatorWeight: 2,
                        labelStyle: TextStyle(
                            fontSize: 11.2,
                            fontWeight: FontWeight.w700,
                            height: 1),
                        unselectedLabelStyle: TextStyle(
                            fontSize: 11.2,
                            fontWeight: FontWeight.w600,
                            height: 1),
                        tabs: [
                          Tab(text: 'Данные'),
                          Tab(text: 'Карты / графики')
                        ],
                      ),
                    ),
                    Expanded(
                        child: TabBarView(children: [
                      tabList(baseItems),
                      tabList(visualItems)
                    ])),
                  ]),
            );
          }
          return Row(children: [
            Expanded(child: _sectionColumn('Данные отчёта', baseItems)),
            Expanded(child: _sectionColumn('Карты и графики', visualItems)),
          ]);
        }),
      ),
      Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: _TD.softLine, width: .7))),
        alignment: Alignment.centerLeft,
        child: Text(
            'Выбрано $selectedCount раздел(ов): ${_sectionsForExport.join(', ')}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: _TD.green,
                fontSize: 11.0,
                fontWeight: FontWeight.w600,
                height: 1)),
      ),
    ]);
  }

  Widget _exportToggle(
      {required IconData icon,
      required String title,
      String? subtitle,
      required bool value,
      required ValueChanged<bool> onChanged}) {
    return _NoHoverTap(
      onTap: () {
        onChanged(!value);
        _mobileOverlayRefresh?.call();
      },
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 7),
        child: Row(children: [
          Icon(icon, color: _TD.graphiteSoft, size: 13),
          const SizedBox(width: 5),
          Expanded(
              child: Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: _TD.text,
                      fontSize: 11.0,
                      fontWeight: FontWeight.w600,
                      height: 1.0))),
          AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 23,
            height: 13,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
                color: value ? _TD.green : _TD.borderStrong,
                borderRadius: BorderRadius.circular(99)),
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle)),
          ),
        ]),
      ),
    );
  }

  Widget _paramsCard() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: _TD.softLine, width: .7))),
        child: Row(children: [
          const Icon(Icons.description_rounded,
              color: _TD.graphiteSoft, size: 12),
          const SizedBox(width: 5),
          Expanded(
              child: Text(
                  '${_playersLabel()} · ${_sectionsForExport.length} раздел(ов)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: _TD.text,
                      fontSize: 11.2,
                      fontWeight: FontWeight.w700,
                      height: 1))),
        ]),
      ),
      Expanded(
        child: ListView(
            padding: EdgeInsets.zero,
            physics: const ClampingScrollPhysics(),
            children: [
              _exportToggle(
                  icon: Icons.shield_rounded,
                  title: 'Командная сводка',
                  subtitle: 'один отчёт на команду',
                  value: _summary,
                  onChanged: (v) => setState(() => _summary = v)),
              const Divider(height: 1, color: _TD.softLine),
              _exportToggle(
                  icon: Icons.badge_rounded,
                  title: 'Листы игроков',
                  subtitle: 'отдельная страница на каждого',
                  value: _playerPages,
                  onChanged: (v) => setState(() => _playerPages = v)),
              const Divider(height: 1, color: _TD.softLine),
              _exportToggle(
                  icon: Icons.business_center_outlined,
                  title: 'Логотип клуба',
                  value: _includeLogo,
                  onChanged: (v) => setState(() => _includeLogo = v)),
              const Divider(height: 1, color: _TD.softLine),
              _exportToggle(
                  icon: Icons.photo_rounded,
                  title: 'Фото игроков',
                  value: _includePhotos,
                  onChanged: (v) => setState(() => _includePhotos = v)),
              const Divider(height: 1, color: _TD.softLine),
              _exportToggle(
                  icon: Icons.compare_rounded,
                  title: 'Сравнение',
                  value: _comparison,
                  onChanged: (v) => setState(() => _comparison = v)),
            ]),
      ),
      Row(children: [
        Expanded(
          child: _NoHoverTap(
            onTap: () => _openExport('pdf'),
            child: Container(
              height: 38,
              alignment: Alignment.center,
              color: _TD.green,
              child: Row(mainAxisSize: MainAxisSize.min, children: const [
                Icon(Icons.picture_as_pdf_rounded,
                    color: Colors.white, size: 15),
                SizedBox(width: 6),
                Text('PDF / печать',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 11.0,
                        fontWeight: FontWeight.w700,
                        height: 1)),
              ]),
            ),
          ),
        ),
        Expanded(
          child: _NoHoverTap(
            onTap: () => _openExport('excel'),
            child: Container(
              height: 38,
              alignment: Alignment.center,
              color: _TD.graphite,
              child: Row(mainAxisSize: MainAxisSize.min, children: const [
                Icon(Icons.table_chart_rounded, color: Colors.white, size: 15),
                SizedBox(width: 6),
                Text('Excel / CSV',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 11.0,
                        fontWeight: FontWeight.w700,
                        height: 1)),
              ]),
            ),
          ),
        ),
      ]),
    ]);
  }

  Future<void> _showMobileConfigSheet({
    required String title,
    required IconData icon,
    required Widget Function() contentBuilder,
    double initialChildSize = .84,
  }) async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, modalSetState) {
          _mobileOverlayRefresh = () => modalSetState(() {});
          return DraggableScrollableSheet(
            initialChildSize: initialChildSize,
            minChildSize: .58,
            maxChildSize: .96,
            builder: (context, controller) {
              return Container(
                clipBehavior: Clip.antiAlias,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                      top: Radius.circular(_TD.sheetRadius)),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 42,
                      height: 4,
                      margin: const EdgeInsets.only(top: 8, bottom: 8),
                      decoration: BoxDecoration(
                          color: _TD.borderStrong,
                          borderRadius: BorderRadius.circular(99)),
                    ),
                    Container(
                      height: 52,
                      padding: const EdgeInsets.symmetric(horizontal: 9),
                      decoration: const BoxDecoration(
                          border: Border(
                              bottom:
                                  BorderSide(color: _TD.softLine, width: .7))),
                      child: Row(children: [
                        Container(
                          width: 34,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                              color: _TD.greenSoft,
                              borderRadius:
                                  BorderRadius.circular(_TD.interactiveRadius),
                              border: Border.all(
                                  color: _TD.greenBorder, width: .8)),
                          child: Icon(icon, color: _TD.green, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: _TD.text,
                                    fontSize: 14.4,
                                    fontWeight: FontWeight.w700))),
                        _NoHoverTap(
                            onTap: () => Navigator.of(context).maybePop(),
                            child: const SizedBox(
                                width: 34,
                                height: 34,
                                child: Icon(Icons.close_rounded,
                                    color: _TD.dim, size: 20))),
                      ]),
                    ),
                    Expanded(
                      child: PrimaryScrollController(
                        controller: controller,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(10, 10, 10, 14),
                          child: contentBuilder(),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
    _mobileOverlayRefresh = null;
  }

  Future<void> _showPlayersPickerSheet(
    List<TrackerPlayerOption> sortedPlayers, {
    List<_ReportPlayerPresence> reportPlayers = const <_ReportPlayerPresence>[],
    bool loadingPresence = false,
    String? presenceError,
  }) {
    return _showMobileConfigSheet(
      title: 'Игроки для выгрузки',
      icon: Icons.groups_rounded,
      contentBuilder: () => _attachedPlayersCard(
        sortedPlayers,
        reportPlayers: reportPlayers,
        loadingPresence: loadingPresence,
        presenceError: presenceError,
      ),
      initialChildSize: .88,
    );
  }

  Future<void> _showSectionsPickerSheet() {
    return _showMobileConfigSheet(
      title: 'Что включить в отчёт',
      icon: Icons.dashboard_customize_rounded,
      contentBuilder: () => _sectionsCard(),
      initialChildSize: .88,
    );
  }

  Future<void> _showExportPickerSheet() {
    return _showMobileConfigSheet(
      title: 'Выгрузка и параметры',
      icon: Icons.picture_as_pdf_rounded,
      contentBuilder: () => _paramsCard(),
      initialChildSize: .82,
    );
  }

  Widget _previewMetric(String value, String label) {
    return Expanded(
        child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: _TD.text,
                    fontSize: 10.4,
                    fontWeight: FontWeight.w700,
                    height: 1.0)),
            const SizedBox(height: 1),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: _TD.muted,
                    fontSize: 9.6,
                    fontWeight: FontWeight.w600,
                    height: 1.0)),
          ]),
    ));
  }

  Widget _previewPanel({required String title, required Widget child}) {
    return Container(
      decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
              right: BorderSide(color: _TD.softLine, width: .7),
              bottom: BorderSide(color: _TD.softLine, width: .7))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          height: 24,
          padding: const EdgeInsets.symmetric(horizontal: 7),
          alignment: Alignment.centerLeft,
          decoration: const BoxDecoration(
              border:
                  Border(bottom: BorderSide(color: _TD.softLine, width: .7))),
          child: Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: _TD.text,
                  fontSize: 11.0,
                  fontWeight: FontWeight.w600,
                  height: 1)),
        ),
        Expanded(
            child: Padding(padding: const EdgeInsets.all(6), child: child)),
      ]),
    );
  }

  Widget _mobilePreviewPanel(
      {required String title, required Widget child, double? height}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_TD.tabletCardRadius),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: _TD.text,
                fontSize: 12.2,
                fontWeight: FontWeight.w700,
                height: 1)),
        const SizedBox(height: 10),
        SizedBox(height: height, child: child),
      ]),
    );
  }

  Widget _reportPreviewMobile(
    TrackerSessionModel s,
    List<_ReportPlayerPresence> movingPlayers,
    List<_ReportPlayerPresence> reportPlayers, {
    required int attachedCount,
    required double distanceKm,
    required double avgHr,
    required double maxSpeed,
    required int sprintCount,
    required List<TrackerReportPoint> routePoints,
    required List<TrackerHeartRatePoint> timelineHr,
    TrackerTrainingReport? report,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(_TD.mobileInnerRadius)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('Предпросмотр отчёта',
            style: TextStyle(
                color: _TD.text, fontSize: 14.6, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        if (_summary)
          _mobilePreviewPanel(
            title: 'Сводка команды',
            height: 108,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    _previewMetric('$attachedCount', 'Игрока'),
                    _previewMetric(
                        '${distanceKm.toStringAsFixed(2)} км', 'Дистанция'),
                    _previewMetric(
                        avgHr > 0 ? '${avgHr.toStringAsFixed(0)} уд/мин' : '—',
                        'Ср. пульс'),
                    _previewMetric(
                        '${maxSpeed.toStringAsFixed(1)} км/ч', 'Макс. скор.'),
                  ]),
                  const Divider(height: 16, color: _TD.softLine),
                  for (var i = 0; i < math.min(2, movingPlayers.length); i++)
                    _previewTableRow('${i + 1}', movingPlayers[i].name,
                        '${(movingPlayers[i].distanceM / 1000).toStringAsFixed(2)} км'),
                  if (movingPlayers.isEmpty)
                    _previewTableRow(
                        '1',
                        reportPlayers.isNotEmpty
                            ? reportPlayers.first.name
                            : 'Игрок',
                        '${distanceKm.toStringAsFixed(2)} км'),
                ]),
          ),
        if (_maps)
          _mobilePreviewPanel(
            title:
                routePoints.isEmpty ? 'Карта перемещений' : 'Карта перемещений',
            height: 210,
            child: CustomPaint(
                painter: _ReportMiniPitchPainter(points: routePoints)),
          ),
        if (_heartRate || _internal)
          _mobilePreviewPanel(
            title:
                'Пульс команды${avgHr > 0 ? ' · ${avgHr.toStringAsFixed(0)} уд/мин' : ''}',
            height: 180,
            child: CustomPaint(
                painter: _ReportPulseChartPainter(points: timelineHr)),
          ),
        if (_zones || _speedChart)
          _mobilePreviewPanel(
            title: 'Спринты',
            height: 48,
            child: Row(children: [
              _previewMetric('$sprintCount', 'Спринта'),
              _previewMetric(
                  '${(report?.summary.sprintDistanceM ?? s.sprintDistanceM).toStringAsFixed(0)} м',
                  'Дистанция'),
              _previewMetric('${(s.durationSec / 60).toStringAsFixed(1)} мин.',
                  'Длительность'),
            ]),
          ),
      ]),
    );
  }

  Widget _reportPreview(
      TrackerSessionModel s, List<_ReportPlayerPresence> reportPlayers,
      {TrackerTrainingReport? report}) {
    final movingPlayers = reportPlayers
        .where((p) => p.hasAny)
        .toList(growable: false)
      ..sort((a, b) => b.distanceM.compareTo(a.distanceM));
    final attachedCount = _attachedPlayerIdsForExport.isNotEmpty
        ? _attachedPlayerIdsForExport.length
        : math.max(1, movingPlayers.length);
    final teamDistanceM = (report?.summary.totalDistanceM ?? 0) > 0
        ? report!.summary.totalDistanceM
        : (s.distanceM > 0
            ? s.distanceM
            : movingPlayers.fold<double>(0, (a, p) => a + p.distanceM));
    final timelineHr = report?.heartRateTimeline
            .where((p) => p.bpm > 0)
            .toList(growable: false) ??
        const <TrackerHeartRatePoint>[];
    final avgHrRows = reportPlayers
        .where((p) => p.heartRateAvgBpm > 0)
        .toList(growable: false);
    final avgHr = (report?.summary.heartRateAvgBpm ?? 0) > 0
        ? report!.summary.heartRateAvgBpm
        : timelineHr.isNotEmpty
            ? timelineHr.fold<double>(0, (a, p) => a + p.bpm) /
                timelineHr.length
            : avgHrRows.isEmpty
                ? 0.0
                : avgHrRows.fold<double>(0, (a, p) => a + p.heartRateAvgBpm) /
                    avgHrRows.length;
    final maxHr = (report?.summary.heartRateMaxBpm ?? 0) > 0
        ? report!.summary.heartRateMaxBpm
        : reportPlayers.fold<double>(
            0, (v, p) => math.max(v, p.heartRateMaxBpm));
    final maxSpeed = (report?.summary.maxSpeedKmh ?? 0) > 0
        ? report!.summary.maxSpeedKmh
        : s.maxSpeedKmh;
    final sprintCount = (report?.summary.sprintCount ?? 0) > 0
        ? report!.summary.sprintCount
        : s.sprintCount;
    final routePoints = report?.routePoints ?? const <TrackerReportPoint>[];
    final heatPoints = report?.heatmapPoints ?? const <TrackerReportPoint>[];
    final lead = movingPlayers.isNotEmpty
        ? movingPlayers.first
        : (reportPlayers.isNotEmpty ? reportPlayers.first : null);
    TrackerPlayerOption? leadRoster;
    if (lead?.playerId != null) {
      for (final p in widget.players) {
        if (p.id == lead!.playerId) {
          leadRoster = p;
          break;
        }
      }
    }
    leadRoster ??= widget.players.isNotEmpty ? widget.players.first : null;

    Widget metric(IconData icon, String title, String value) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
              color: _TD.soft2, borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            Icon(icon, color: _TD.green, size: 17),
            const SizedBox(width: 8),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: _TD.muted,
                          fontSize: 9.2,
                          fontWeight: FontWeight.w700,
                          letterSpacing: .3)),
                  const SizedBox(height: 3),
                  Text(value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: _TD.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                ])),
          ]),
        );

    Widget panel(String title, Widget child, {String? subtitle}) => Container(
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _TD.softLine, width: .8)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: _TD.text,
                            fontSize: 13.8,
                            fontWeight: FontWeight.w700)),
                    if ((subtitle ?? '').isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!,
                          style: const TextStyle(
                              color: _TD.muted,
                              fontSize: 10.8,
                              fontWeight: FontWeight.w600))
                    ],
                  ]),
            ),
            const Divider(height: 1, color: _TD.softLine),
            Expanded(
                child:
                    Padding(padding: const EdgeInsets.all(10), child: child)),
          ]),
        );

    Widget intensityBar() =>
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: Row(children: const [
                Expanded(
                    flex: 17,
                    child: ColoredBox(
                        color: Color(0xFF19B769), child: SizedBox(height: 8))),
                Expanded(
                    flex: 13,
                    child: ColoredBox(
                        color: Color(0xFFF4C542), child: SizedBox(height: 8))),
                Expanded(
                    flex: 22,
                    child: ColoredBox(
                        color: Color(0xFFFF8A34), child: SizedBox(height: 8))),
                Expanded(
                    flex: 48,
                    child: ColoredBox(
                        color: Color(0xFFEF4444), child: SizedBox(height: 8))),
              ])),
          const SizedBox(height: 9),
          Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('Низкая',
                    style: TextStyle(
                        color: _TD.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
                Text('Умеренная',
                    style: TextStyle(
                        color: _TD.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
                Text('Высокая',
                    style: TextStyle(
                        color: _TD.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
                Text('Очень высокая',
                    style: TextStyle(
                        color: _TD.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
              ]),
        ]);

    return _reportBlock(
      title: 'Предпросмотр отчёта · Live-дизайн',
      child: LayoutBuilder(builder: (context, box) {
        final compact = box.maxWidth < 760;
        if (compact) {
          return ListView(padding: const EdgeInsets.all(10), children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _TD.softLine)),
              child: Row(children: [
                _PlayerAvatarDark(
                    url: leadRoster?.avatar ?? '',
                    initials: _playerInitials(lead?.name ?? 'И'),
                    size: 46,
                    active: true),
                const SizedBox(width: 10),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(lead?.name ?? widget.teamName,
                          style: const TextStyle(
                              color: _TD.text,
                              fontSize: 15.5,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text('Сессия #${s.id} · GPS + Polar',
                          style: const TextStyle(
                              color: _TD.muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ])),
              ]),
            ),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              SizedBox(
                  width: (box.maxWidth - 30) / 2,
                  child: metric(
                      Icons.timer_outlined,
                      'Длительность',
                      s.durationSec > 0
                          ? '${(s.durationSec / 60).toStringAsFixed(0)} мин'
                          : '—')),
              SizedBox(
                  width: (box.maxWidth - 30) / 2,
                  child: metric(Icons.route_rounded, 'Дистанция',
                      '${(teamDistanceM / 1000).toStringAsFixed(2)} км')),
              SizedBox(
                  width: (box.maxWidth - 30) / 2,
                  child: metric(Icons.speed_rounded, 'Макс. скорость',
                      '${maxSpeed.toStringAsFixed(1)} км/ч')),
              SizedBox(
                  width: (box.maxWidth - 30) / 2,
                  child: metric(
                      Icons.favorite_rounded,
                      'Пульс',
                      avgHr > 0
                          ? '${avgHr.toStringAsFixed(0)} / ${maxHr.toStringAsFixed(0)}'
                          : '—')),
            ]),
            const SizedBox(height: 10),
            if (_heartRate)
              SizedBox(
                  height: 250,
                  child: panel(
                      'Пульс по времени',
                      CustomPaint(
                          painter:
                              _ReportPulseChartPainter(points: timelineHr)),
                      subtitle: timelineHr.isEmpty
                          ? 'Нет Polar-точек'
                          : '${timelineHr.length} измерений')),
            if (_heartRate) const SizedBox(height: 10),
            if (_maps)
              SizedBox(
                  height: 280,
                  child: panel(
                      'Карта активности',
                      CustomPaint(
                          painter:
                              _ReportMiniPitchPainter(points: routePoints)),
                      subtitle: routePoints.isEmpty
                          ? 'Нет GPS-точек'
                          : '${routePoints.length} GPS-точек')),
            if (_maps) const SizedBox(height: 10),
            if (_heatmap)
              SizedBox(
                  height: 280,
                  child: panel(
                      'Тепловая карта',
                      CustomPaint(
                          painter: _ReportMiniHeatmapPainter(
                              points: heatPoints.isEmpty
                                  ? routePoints
                                  : heatPoints)))),
            if (_zones) ...[
              const SizedBox(height: 10),
              SizedBox(
                  height: 105,
                  child: panel('Зоны интенсивности', intensityBar()))
            ],
          ]);
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _TD.softLine, width: .8)),
              child: Column(children: [
                Row(children: [
                  _PlayerAvatarDark(
                      url: leadRoster?.avatar ?? '',
                      initials: _playerInitials(lead?.name ?? 'И'),
                      size: 48,
                      active: true),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(lead?.name ?? widget.teamName,
                            style: const TextStyle(
                                color: _TD.text,
                                fontSize: 16.5,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 3),
                        Text(
                            '${widget.teamName} · сессия #${s.id} · GPS + Polar',
                            style: const TextStyle(
                                color: _TD.muted,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600)),
                      ])),
                  Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                          color: _TD.greenSoft,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: _TD.greenBorder)),
                      child: const Text('Завершено',
                          style: TextStyle(
                              color: _TD.green,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700))),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                      child: metric(
                          Icons.timer_outlined,
                          'Длительность',
                          s.durationSec > 0
                              ? '${(s.durationSec / 60).toStringAsFixed(0)} мин'
                              : '—')),
                  const SizedBox(width: 8),
                  Expanded(
                      child: metric(Icons.route_rounded, 'Дистанция',
                          '${(teamDistanceM / 1000).toStringAsFixed(2)} км')),
                  const SizedBox(width: 8),
                  Expanded(
                      child: metric(Icons.speed_rounded, 'Макс. скорость',
                          '${maxSpeed.toStringAsFixed(1)} км/ч')),
                  const SizedBox(width: 8),
                  Expanded(
                      child: metric(
                          Icons.favorite_rounded,
                          'Пульс avg/max',
                          avgHr > 0
                              ? '${avgHr.toStringAsFixed(0)} / ${maxHr.toStringAsFixed(0)}'
                              : '—')),
                  const SizedBox(width: 8),
                  Expanded(
                      child: metric(
                          Icons.flash_on_rounded, 'Спринты', '$sprintCount')),
                ]),
              ]),
            ),
            const SizedBox(height: 12),
            if (_heartRate || _maps)
              SizedBox(
                  height: 330,
                  child: Row(children: [
                    if (_heartRate)
                      Expanded(
                          flex: 11,
                          child: panel(
                              'Пульс по времени',
                              CustomPaint(
                                  painter: _ReportPulseChartPainter(
                                      points: timelineHr)),
                              subtitle: timelineHr.isEmpty
                                  ? 'Нет Polar-точек'
                                  : 'Средний ${avgHr.toStringAsFixed(0)} · максимум ${maxHr.toStringAsFixed(0)}')),
                    if (_heartRate && _maps) const SizedBox(width: 12),
                    if (_maps)
                      Expanded(
                          flex: 10,
                          child: panel(
                              'Карта активности',
                              CustomPaint(
                                  painter: _ReportMiniPitchPainter(
                                      points: routePoints)),
                              subtitle: routePoints.isEmpty
                                  ? 'Нет GPS-точек'
                                  : '${routePoints.length} GPS-точек')),
                  ])),
            if (_heartRate || _maps) const SizedBox(height: 12),
            SizedBox(
                height: 145,
                child: Row(children: [
                  if (_zones)
                    Expanded(
                        flex: 12,
                        child: panel('Зоны интенсивности', intensityBar())),
                  if (_zones) const SizedBox(width: 12),
                  if (_speedChart)
                    Expanded(
                        flex: 8,
                        child: panel(
                            'Спринты',
                            Row(children: [
                              Expanded(
                                  child: metric(Icons.flash_on_rounded, 'Всего',
                                      '$sprintCount')),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: metric(
                                      Icons.route_rounded,
                                      'Дистанция',
                                      '${(report?.summary.sprintDistanceM ?? s.sprintDistanceM).toStringAsFixed(0)} м'))
                            ]))),
                  if (_speedChart) const SizedBox(width: 12),
                  Expanded(
                      flex: 8,
                      child: panel(
                          'Состав отчёта',
                          Row(children: [
                            Expanded(
                                child: metric(Icons.groups_rounded, 'Игроки',
                                    '$attachedCount')),
                            const SizedBox(width: 8),
                            Expanded(
                                child: metric(Icons.grid_view_rounded,
                                    'Разделы', '${_sectionsForExport.length}'))
                          ]))),
                ])),
            if (_heatmap) ...[
              const SizedBox(height: 12),
              SizedBox(
                  height: 310,
                  child: panel(
                      'Тепловая карта',
                      CustomPaint(
                          painter: _ReportMiniHeatmapPainter(
                              points: heatPoints.isEmpty
                                  ? routePoints
                                  : heatPoints))))
            ],
          ]),
        );
      }),
    );
  }

  Widget _previewTableRow(String index, String name, String value) {
    return SizedBox(
      height: 20,
      child: Row(children: [
        SizedBox(
            width: 12,
            child: Text(index,
                style: const TextStyle(
                    color: _TD.text,
                    fontSize: 9.6,
                    fontWeight: FontWeight.w700,
                    height: 1))),
        Expanded(
            child: Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: _TD.graphite,
                    fontSize: 9.6,
                    fontWeight: FontWeight.w600,
                    height: 1))),
        Text(value,
            style: const TextStyle(
                color: _TD.text,
                fontSize: 9.6,
                fontWeight: FontWeight.w700,
                height: 1)),
      ]),
    );
  }

  Widget _sessionHeader(TrackerSessionModel s) {
    final duration = s.durationSec <= 0
        ? '—'
        : '${(s.durationSec / 60).toStringAsFixed(0)} мин';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: _TD.greenSoft,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: _TD.greenBorder)),
              child: const Icon(Icons.assignment_rounded,
                  color: _TD.green, size: 19)),
          const SizedBox(width: 8),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Конструктор отчёта #${s.id}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: _TD.text,
                        fontSize: 15.2,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.25)),
                const SizedBox(height: 3),
                Text('${widget.teamName} · ${s.createdAt} · ${_playersLabel()}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: _TD.muted,
                        fontSize: 11.8,
                        fontWeight: FontWeight.w600)),
              ])),
          const SizedBox(width: 8),
          _DarkActionButton(
              icon: Icons.picture_as_pdf_rounded,
              label: 'PDF / печать',
              primary: true,
              onTap: () => _openExport('pdf')),
          const SizedBox(width: 6),
          _DarkActionButton(
              icon: Icons.table_chart_rounded,
              label: 'Excel',
              onTap: () => _openExport('excel')),
        ]),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 560;
            final itemWidth = compact
                ? (constraints.maxWidth - 7) / 2
                : math.max(148.0, (constraints.maxWidth - 28) / 5);
            final metrics = <Widget>[
              _pill(
                  icon: Icons.route_rounded,
                  title: 'Дистанция',
                  value: '${(s.distanceM / 1000).toStringAsFixed(2)} км'),
              _pill(
                  icon: Icons.speed_rounded,
                  title: 'Макс. скорость',
                  value: '${s.maxSpeedKmh.toStringAsFixed(1)} км/ч'),
              _pill(
                  icon: Icons.flash_on_rounded,
                  title: 'Спринты',
                  value:
                      '${s.sprintCount} · ${s.sprintDistanceM.toStringAsFixed(0)} м'),
              _pill(
                  icon: Icons.compare_arrows_rounded,
                  title: 'Уск./торм.',
                  value: '${s.accelCount}/${s.decelCount}'),
              _pill(
                  icon: Icons.timer_rounded,
                  title: 'Длительность',
                  value: duration),
            ];
            return Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final m in metrics) SizedBox(width: itemWidth, child: m)
              ],
            );
          },
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    if (s == null) {
      _attachedPlayerIdsForExport = <int>{};
      return const _DarkCard(
        title: '',
        subtitle: '',
        child: _DarkEmpty(
            icon: Icons.assignment_rounded,
            text:
                'Нажмите «Выбор тренировки» в шапке и выберите день/сессию — здесь появится конструктор отчёта в 3 блока и предпросмотр PDF.'),
      );
    }

    final sortedPlayers = List<TrackerPlayerOption>.from(widget.players)
      ..sort((a, b) => a.name.compareTo(b.name));
    return FutureBuilder<TrackerTrainingReport>(
      future: _reportForSession(s),
      builder: (context, reportSnapshot) {
        final report = reportSnapshot.data;
        final reportPlayers = report == null
            ? const <_ReportPlayerPresence>[]
            : _presenceFromReport(report);
        final loadingPresence =
            reportSnapshot.connectionState == ConnectionState.waiting &&
                !reportSnapshot.hasData;
        final presenceError =
            reportSnapshot.hasError ? '${reportSnapshot.error}' : null;
        return LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 620;
            if (compact) {
              final attachedCount = reportPlayers
                  .where((p) => p.hasAny || (p.playerId ?? 0) > 0)
                  .length;
              final distanceKm = ((report?.summary.totalDistanceM ?? 0) > 0
                      ? report!.summary.totalDistanceM
                      : s.distanceM) /
                  1000;
              final avgHr = (report?.summary.heartRateAvgBpm ?? 0) > 0
                  ? report!.summary.heartRateAvgBpm
                  : 0.0;
              final maxSpeed = (report?.summary.maxSpeedKmh ?? 0) > 0
                  ? report!.summary.maxSpeedKmh
                  : s.maxSpeedKmh;
              final sprintCount = (report?.summary.sprintCount ?? 0) > 0
                  ? report!.summary.sprintCount
                  : s.sprintCount;
              final routePoints =
                  report?.routePoints ?? const <TrackerReportPoint>[];
              final timelineHr = report?.heartRateTimeline
                      .where((p) => p.bpm > 0)
                      .toList(growable: false) ??
                  const <TrackerHeartRatePoint>[];
              final selectedIds = _playerIdsForExport.toSet();
              final fallbackIds = _attachedPlayerIdsForExport.isNotEmpty
                  ? _attachedPlayerIdsForExport
                  : sortedPlayers
                      .map((e) => e.id)
                      .where((id) => id > 0)
                      .toSet();
              final effectiveIds =
                  selectedIds.isNotEmpty ? selectedIds : fallbackIds;
              final previewPlayers = sortedPlayers
                  .where((p) => effectiveIds.contains(p.id))
                  .take(5)
                  .toList(growable: false);

              Widget mobileCard(
                  {required IconData icon,
                  required String title,
                  String? subtitle,
                  Widget? trailing,
                  required Widget child}) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(_TD.mobileInnerRadius),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                        child: Row(children: [
                          Container(
                            width: 34,
                            height: 34,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                                color: _TD.greenSoft,
                                borderRadius: BorderRadius.circular(
                                    _TD.interactiveRadius),
                                border: Border.all(
                                    color: _TD.greenBorder, width: .8)),
                            child: Icon(icon, color: _TD.green, size: 18),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: _TD.text,
                                        fontSize: 14.2,
                                        fontWeight: FontWeight.w700,
                                        height: 1)),
                                if ((subtitle ?? '').trim().isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(subtitle!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: _TD.muted,
                                          fontSize: 11.2,
                                          fontWeight: FontWeight.w700,
                                          height: 1)),
                                ],
                              ])),
                          if (trailing != null) trailing,
                        ]),
                      ),
                      Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          child: child),
                    ],
                  ),
                );
              }

              Widget filterChip(
                  {required IconData icon,
                  required String label,
                  required String value,
                  VoidCallback? onTap}) {
                final chip = Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                      color: _TD.greenSoft,
                      borderRadius:
                          BorderRadius.circular(_TD.mobileInnerRadius),
                      border: Border.all(color: _TD.greenBorder, width: .8)),
                  child: Row(children: [
                    Icon(icon, size: 16, color: _TD.green),
                    const SizedBox(width: 7),
                    Expanded(
                        child: Text(label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: _TD.graphite,
                                fontSize: 11.0,
                                fontWeight: FontWeight.w700))),
                    const Icon(Icons.expand_more_rounded,
                        color: _TD.graphiteSoft, size: 17),
                  ]),
                );
                return onTap == null
                    ? chip
                    : _NoHoverTap(onTap: onTap, child: chip);
              }

              Widget selectedSectionChip(String label) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                  decoration: BoxDecoration(
                      color: _TD.greenSoft,
                      borderRadius:
                          BorderRadius.circular(_TD.interactiveRadius),
                      border: Border.all(color: _TD.greenBorder, width: .8)),
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: _TD.greenDark,
                          fontSize: 11.2,
                          fontWeight: FontWeight.w700)),
                );
              }

              final selectedSectionChips = <Widget>[
                if (_summary) selectedSectionChip('Сводка'),
                if (_maps) selectedSectionChip('Карта'),
                if (_heatmap) selectedSectionChip('Heatmap'),
                if (_speedChart) selectedSectionChip('Скорость'),
                if (_heartRate) selectedSectionChip('Пульс'),
                if (_locomotor) selectedSectionChip('Локомоторика'),
                if (_mechanics) selectedSectionChip('Механика'),
                if (_ai) selectedSectionChip('ИИ'),
              ];

              final summary = report?.summary ?? const TrackerReportSummary();
              final heatPoints =
                  report?.heatmapPoints ?? const <TrackerReportPoint>[];
              final speedZones =
                  report?.speedZones ?? const <TrackerSpeedZone>[];
              final reportRows =
                  report?.players ?? const <TrackerTrainingPlayerRow>[];
              final topRows = List<TrackerTrainingPlayerRow>.from(reportRows)
                ..sort((a, b) => b.distanceM.compareTo(a.distanceM));
              final micro =
                  report?.microcycle ?? const <TrackerMicrocyclePoint>[];

              Widget compactMetric(IconData icon, String value, String label) {
                return Expanded(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    decoration: BoxDecoration(
                      color: _TD.soft2,
                      borderRadius: BorderRadius.zero,
                    ),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(icon, color: _TD.green, size: 16),
                          const SizedBox(height: 6),
                          Text(value,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: _TD.text,
                                  fontSize: 12.2,
                                  fontWeight: FontWeight.w700,
                                  height: 1)),
                          const SizedBox(height: 3),
                          Text(label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: _TD.muted,
                                  fontSize: 11.0,
                                  fontWeight: FontWeight.w700,
                                  height: 1)),
                        ]),
                  ),
                );
              }

              Widget mobileDataRow(String title, String v1, String v2,
                  {String? v3}) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
                  decoration: const BoxDecoration(
                      border: Border(
                          bottom: BorderSide(color: _TD.softLine, width: .7))),
                  child: Row(children: [
                    Expanded(
                        flex: 5,
                        child: Text(title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: _TD.text,
                                fontSize: 11.0,
                                fontWeight: FontWeight.w700,
                                height: 1))),
                    const SizedBox(width: 8),
                    Expanded(
                        flex: 3,
                        child: Text(v1,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                                color: _TD.graphite,
                                fontSize: 11.0,
                                fontWeight: FontWeight.w700,
                                height: 1))),
                    const SizedBox(width: 8),
                    Expanded(
                        flex: 3,
                        child: Text(v2,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                                color: _TD.graphite,
                                fontSize: 11.0,
                                fontWeight: FontWeight.w700,
                                height: 1))),
                    if (v3 != null) ...[
                      const SizedBox(width: 8),
                      Expanded(
                          flex: 3,
                          child: Text(v3,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                  color: _TD.graphite,
                                  fontSize: 11.0,
                                  fontWeight: FontWeight.w700,
                                  height: 1))),
                    ],
                  ]),
                );
              }

              Widget mobileEmpty(String text) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: _TD.muted,
                            fontSize: 11.0,
                            fontWeight: FontWeight.w700,
                            height: 1.2)),
                  );

              final dataPreviewCards = <Widget>[
                if (_summary)
                  mobileCard(
                    icon: Icons.fact_check_rounded,
                    title: 'Сводка команды',
                    subtitle: 'общие показатели выбранной сессии',
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(children: [
                            compactMetric(
                                Icons.route_rounded,
                                '${distanceKm.toStringAsFixed(2)} км',
                                'Дистанция'),
                            const SizedBox(width: 8),
                            compactMetric(Icons.speed_rounded,
                                '${maxSpeed.toStringAsFixed(1)}', 'Макс. км/ч'),
                          ]),
                          const SizedBox(height: 8),
                          Row(children: [
                            compactMetric(Icons.flash_on_rounded,
                                '$sprintCount', 'Спринты'),
                            const SizedBox(width: 8),
                            compactMetric(
                                Icons.fitness_center_rounded,
                                '${summary.playerLoad.toStringAsFixed(0)}',
                                'Нагрузка'),
                          ]),
                        ]),
                  ),
                if (_playersBlock)
                  mobileCard(
                    icon: Icons.groups_rounded,
                    title: 'Таблица игроков',
                    subtitle: topRows.isEmpty
                        ? 'нет строк игроков'
                        : '${topRows.length} игроков в отчёте',
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (topRows.isEmpty)
                            mobileEmpty(
                                'После обработки сессии здесь появятся строки игроков с дистанцией, скоростью и пульсом.')
                          else
                            for (final p in topRows.take(6))
                              mobileDataRow(
                                  p.name,
                                  '${(p.distanceM / 1000).toStringAsFixed(2)} км',
                                  '${p.maxSpeedKmh.toStringAsFixed(1)} км/ч',
                                  v3: p.heartRateAvgBpm > 0
                                      ? '${p.heartRateAvgBpm.toStringAsFixed(0)} уд/мин'
                                      : '—'),
                        ]),
                  ),
                if (_locomotor)
                  mobileCard(
                    icon: Icons.directions_run_rounded,
                    title: 'Локомоторика',
                    subtitle: 'дистанция, HSR и метры в минуту',
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(children: [
                            compactMetric(
                                Icons.route_rounded,
                                '${(summary.totalDistanceM / 1000).toStringAsFixed(2)} км',
                                'Всего'),
                            const SizedBox(width: 8),
                            compactMetric(
                                Icons.speed_rounded,
                                '${summary.distancePerMin.toStringAsFixed(0)}',
                                'м/мин'),
                          ]),
                          const SizedBox(height: 8),
                          Row(children: [
                            compactMetric(
                                Icons.trending_up_rounded,
                                '${summary.v4HsrM.toStringAsFixed(0)} м',
                                'HSR'),
                            const SizedBox(width: 8),
                            compactMetric(
                                Icons.local_fire_department_rounded,
                                '${summary.v5SprintM.toStringAsFixed(0)} м',
                                'Спринт'),
                          ]),
                        ]),
                  ),
                if (_mechanics || _internal)
                  mobileCard(
                    icon: Icons.compare_arrows_rounded,
                    title: _mechanics && _internal
                        ? 'Механика и нагрузка'
                        : (_mechanics ? 'Механика' : 'Внутренняя нагрузка'),
                    subtitle: 'ускорения, торможения и load',
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(children: [
                            compactMetric(Icons.north_east_rounded,
                                '${summary.accelerationCount}', 'Ускорения'),
                            const SizedBox(width: 8),
                            compactMetric(Icons.south_west_rounded,
                                '${summary.decelerationCount}', 'Торможения'),
                          ]),
                          const SizedBox(height: 8),
                          Row(children: [
                            compactMetric(Icons.bolt_rounded,
                                '${summary.explosiveActions}', 'Взрывные'),
                            const SizedBox(width: 8),
                            compactMetric(
                                Icons.fitness_center_rounded,
                                '${summary.playerLoad.toStringAsFixed(0)}',
                                'Нагрузка'),
                          ]),
                        ]),
                  ),
                if (_heartRate)
                  mobileCard(
                    icon: Icons.favorite_rounded,
                    title: 'Пульс Polar',
                    subtitle: timelineHr.isEmpty
                        ? 'нет HR-точек'
                        : '${timelineHr.length} HR-точек',
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                              height: 160,
                              child: CustomPaint(
                                  painter: _ReportPulseChartPainter(
                                      points: timelineHr))),
                          const SizedBox(height: 8),
                          Row(children: [
                            compactMetric(
                                Icons.favorite_rounded,
                                avgHr > 0 ? '${avgHr.toStringAsFixed(0)}' : '—',
                                'Ср. пульс'),
                            const SizedBox(width: 8),
                            compactMetric(
                                Icons.monitor_heart_rounded,
                                summary.heartRateMaxBpm > 0
                                    ? '${summary.heartRateMaxBpm.toStringAsFixed(0)}'
                                    : '—',
                                'Макс. пульс'),
                          ]),
                        ]),
                  ),
                if (_maps)
                  mobileCard(
                    icon: Icons.route_rounded,
                    title: 'Карта перемещений',
                    subtitle: routePoints.isEmpty
                        ? 'нет GPS-точек'
                        : '${routePoints.length} точек',
                    child: SizedBox(
                        height: 220,
                        child: CustomPaint(
                            painter:
                                _ReportMiniPitchPainter(points: routePoints))),
                  ),
                if (_heatmap)
                  mobileCard(
                    icon: Icons.local_fire_department_rounded,
                    title: 'Тепловая карта',
                    subtitle: heatPoints.isEmpty
                        ? 'используются точки маршрута'
                        : '${heatPoints.length} зон активности',
                    child: SizedBox(
                        height: 220,
                        child: CustomPaint(
                            painter: _ReportMiniHeatmapPainter(
                                points: heatPoints.isEmpty
                                    ? routePoints
                                    : heatPoints))),
                  ),
                if (_speedChart || _zones)
                  mobileCard(
                    icon: Icons.speed_rounded,
                    title: 'Скорость, спринты и зоны',
                    subtitle: speedZones.isEmpty
                        ? 'зоны будут рассчитаны сервером'
                        : '${speedZones.length} зон скорости',
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(children: [
                            compactMetric(Icons.speed_rounded,
                                '${maxSpeed.toStringAsFixed(1)}', 'Макс. км/ч'),
                            const SizedBox(width: 8),
                            compactMetric(Icons.flash_on_rounded,
                                '$sprintCount', 'Спринты'),
                          ]),
                          const SizedBox(height: 8),
                          if (speedZones.isEmpty)
                            mobileEmpty(
                                'После обработки сервер покажет дистанцию по зонам скорости.')
                          else
                            for (final z in speedZones.take(5))
                              mobileDataRow(
                                  z.label.isEmpty
                                      ? '${z.fromKmh.toStringAsFixed(0)}–${z.toKmh.toStringAsFixed(0)} км/ч'
                                      : z.label,
                                  '${z.distanceM.toStringAsFixed(0)} м',
                                  '${z.pointsCount} точек'),
                        ]),
                  ),
                if (_microcycle)
                  mobileCard(
                    icon: Icons.calendar_view_week_rounded,
                    title: 'Микроцикл',
                    subtitle: micro.isEmpty
                        ? 'нет данных микроцикла'
                        : '${micro.length} периодов',
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (micro.isEmpty)
                            mobileEmpty(
                                'Здесь появится нагрузка по дням микроцикла, когда сервер вернёт эти данные.')
                          else
                            for (final m in micro.take(5))
                              mobileDataRow(
                                  m.label,
                                  '${(m.distanceM / 1000).toStringAsFixed(2)} км',
                                  '${m.highSpeedRunningM.toStringAsFixed(0)} HSR',
                                  v3: '${m.accDec.toStringAsFixed(1)} acc/dec'),
                        ]),
                  ),
                if (_ai)
                  mobileCard(
                    icon: Icons.auto_awesome_rounded,
                    title: 'ИИ анализ',
                    subtitle: 'заметки по нагрузке и рискам',
                    child: mobileEmpty(
                        'ИИ блок будет показан здесь, когда сервер вернёт анализ по выбранной сессии.'),
                  ),
              ];

              return ListView(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 20),
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(_TD.mobileInnerRadius),
                    ),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(children: [
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text('Отчёт по сессии #${s.id}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: _TD.text,
                                          fontSize: 16.5,
                                          fontWeight: FontWeight.w700,
                                          height: 1)),
                                  const SizedBox(height: 6),
                                  Text('${widget.teamName} · ${s.createdAt}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: _TD.muted,
                                          fontSize: 11.2,
                                          fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 3),
                                  Text(
                                      'Игроки: ${_playersLabel()} · разделы: ${_sectionsForExport.length}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: _TD.green,
                                          fontSize: 11.2,
                                          fontWeight: FontWeight.w700)),
                                ])),
                            if (widget.onPickSession == null)
                              Container(
                                  width: 54,
                                  height: 54,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                      color: _TD.greenSoft,
                                      borderRadius: BorderRadius.circular(
                                          _TD.mobileInnerRadius),
                                      border: Border.all(
                                          color: _TD.greenBorder, width: .9)),
                                  child: const Icon(Icons.assignment_rounded,
                                      color: _TD.green, size: 26))
                            else
                              _NoHoverTap(
                                onTap: widget.onPickSession!,
                                child: Container(
                                  height: 42,
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 8),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                      color: _TD.greenSoft,
                                      borderRadius: BorderRadius.circular(
                                          _TD.interactiveRadius),
                                      border: Border.all(
                                          color: _TD.greenBorder, width: .8)),
                                  child: const Text('Изменить',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          color: _TD.greenDark,
                                          fontSize: 11.2,
                                          fontWeight: FontWeight.w700,
                                          height: 1)),
                                ),
                              ),
                          ]),
                          const SizedBox(height: 8),
                          Row(children: [
                            Expanded(
                                child: _MobileReportMetricTile(
                                    icon: Icons.groups_rounded,
                                    value:
                                        '${attachedCount == 0 ? widget.players.length : attachedCount}',
                                    subtitle: 'Игроки')),
                            Expanded(
                                child: _MobileReportMetricTile(
                                    icon: Icons.route_rounded,
                                    value:
                                        '${distanceKm.toStringAsFixed(2)} км',
                                    subtitle: 'Дист.')),
                            Expanded(
                                child: _MobileReportMetricTile(
                                    icon: Icons.favorite_rounded,
                                    value: avgHr > 0
                                        ? '${avgHr.toStringAsFixed(0)}'
                                        : '—',
                                    subtitle: 'Пульс')),
                            Expanded(
                                child: _MobileReportMetricTile(
                                    icon: Icons.speed_rounded,
                                    value: '${maxSpeed.toStringAsFixed(1)}',
                                    subtitle: 'Макс.')),
                          ]),
                        ]),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                        child: filterChip(
                            icon: Icons.groups_rounded,
                            label: 'Игроки',
                            value: '${effectiveIds.length}',
                            onTap: () => _showPlayersPickerSheet(sortedPlayers,
                                reportPlayers: reportPlayers,
                                loadingPresence: loadingPresence,
                                presenceError: presenceError))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: filterChip(
                            icon: Icons.grid_view_rounded,
                            label: 'Разделы',
                            value: '${_sectionsForExport.length}',
                            onTap: _showSectionsPickerSheet)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: filterChip(
                            icon: Icons.description_outlined,
                            label: 'Экспорт',
                            value: 'PDF / Excel',
                            onTap: _showExportPickerSheet)),
                  ]),
                  const SizedBox(height: 10),
                  mobileCard(
                    icon: Icons.groups_rounded,
                    title: 'Игроки',
                    subtitle: _playersLabel(),
                    trailing: _MobileReportOutlineButton(
                        label: 'Выбрать',
                        onTap: () => _showPlayersPickerSheet(sortedPlayers,
                            reportPlayers: reportPlayers,
                            loadingPresence: loadingPresence,
                            presenceError: presenceError)),
                    child: previewPlayers.isNotEmpty
                        ? SizedBox(
                            height: 82,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: previewPlayers.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (_, i) {
                                final p = previewPlayers[i];
                                return SizedBox(
                                  width: 64,
                                  child: Column(children: [
                                    _PlayerAvatarDark(
                                        url: p.avatar,
                                        initials: _playerInitials(p.name),
                                        size: 42,
                                        active: true),
                                    const SizedBox(height: 6),
                                    Text(p.name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            color: _TD.graphite,
                                            fontSize: 11.0,
                                            fontWeight: FontWeight.w700,
                                            height: 1.05)),
                                  ]),
                                );
                              },
                            ),
                          )
                        : const Text(
                            'По умолчанию выгружаются игроки с данными выбранной сессии.',
                            style: TextStyle(
                                color: _TD.muted,
                                fontSize: 11.2,
                                fontWeight: FontWeight.w700)),
                  ),
                  mobileCard(
                    icon: Icons.dashboard_customize_rounded,
                    title: 'Что включить',
                    subtitle: '${_sectionsForExport.length} разделов',
                    trailing: _MobileReportOutlineButton(
                        label: 'Изменить', onTap: _showSectionsPickerSheet),
                    child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: selectedSectionChips.isEmpty
                            ? [selectedSectionChip('Сводка')]
                            : selectedSectionChips),
                  ),
                  mobileCard(
                    icon: Icons.picture_as_pdf_rounded,
                    title: 'Выгрузка',
                    subtitle: 'Параметры, PDF и Excel',
                    trailing: _MobileReportOutlineButton(
                        label: 'Открыть', onTap: _showExportPickerSheet),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Wrap(spacing: 8, runSpacing: 8, children: [
                            selectedSectionChip(_includeLogo
                                ? 'Логотип клуба'
                                : 'Без логотипа'),
                            selectedSectionChip(
                                _includePhotos ? 'Фото игроков' : 'Без фото'),
                            selectedSectionChip(_playerPages
                                ? 'Листы игроков'
                                : 'Только сводка'),
                          ]),
                          const SizedBox(height: 8),
                          Row(children: [
                            Expanded(
                                child: _DarkActionButton(
                                    icon: Icons.picture_as_pdf_rounded,
                                    label: 'PDF / печать',
                                    primary: true,
                                    onTap: () => _openExport('pdf'))),
                            const SizedBox(width: 8),
                            Expanded(
                                child: _DarkActionButton(
                                    icon: Icons.table_chart_rounded,
                                    label: 'Excel / CSV',
                                    onTap: () => _openExport('excel'))),
                          ]),
                        ]),
                  ),
                  if (dataPreviewCards.isNotEmpty) ...[
                    Container(
                      margin: const EdgeInsets.fromLTRB(2, 2, 2, 10),
                      child: const Text('Данные для просмотра',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: _TD.text,
                              fontSize: 15.0,
                              fontWeight: FontWeight.w700,
                              height: 1)),
                    ),
                    ...dataPreviewCards,
                  ],
                  if (_comparison)
                    mobileCard(
                      icon: Icons.compare_rounded,
                      title: 'Сравнение',
                      subtitle: _mobileCompareTab == 0
                          ? 'Карта активности'
                          : 'Скорость и пульс',
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(children: [
                              Expanded(
                                  child: _NoHoverTap(
                                      onTap: () =>
                                          setState(() => _mobileCompareTab = 0),
                                      child: Container(
                                          height: 40,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                              color: _mobileCompareTab == 0
                                                  ? _TD.greenSoft
                                                  : _TD.soft2,
                                              borderRadius: BorderRadius.circular(
                                                  _TD.interactiveRadius),
                                              border: Border.all(
                                                  color: _mobileCompareTab == 0
                                                      ? _TD.greenBorder
                                                      : _TD.borderStrong,
                                                  width: .8)),
                                          child: Text('Карта активности',
                                              style: TextStyle(
                                                  color: _mobileCompareTab == 0
                                                      ? _TD.greenDark
                                                      : _TD.graphite,
                                                  fontSize: 11.2,
                                                  fontWeight:
                                                      FontWeight.w700))))),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: _NoHoverTap(
                                      onTap: () =>
                                          setState(() => _mobileCompareTab = 1),
                                      child: Container(
                                          height: 40,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                              color: _mobileCompareTab == 1
                                                  ? _TD.greenSoft
                                                  : _TD.soft2,
                                              borderRadius: BorderRadius.circular(
                                                  _TD.interactiveRadius),
                                              border: Border.all(
                                                  color: _mobileCompareTab == 1
                                                      ? _TD.greenBorder
                                                      : _TD.borderStrong,
                                                  width: .8)),
                                          child: Text('Скорость и пульс',
                                              style: TextStyle(
                                                  color: _mobileCompareTab == 1
                                                      ? _TD.greenDark
                                                      : _TD.graphite,
                                                  fontSize: 11.2,
                                                  fontWeight:
                                                      FontWeight.w700))))),
                            ]),
                            const SizedBox(height: 8),
                            if (_mobileCompareTab == 0) ...[
                              SizedBox(
                                  height: 220,
                                  child: CustomPaint(
                                      painter: _ReportMiniPitchPainter(
                                          points: routePoints))),
                              const SizedBox(height: 10),
                              const _ReportMiniHeatLegend(),
                            ] else ...[
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                    color: _TD.soft2,
                                    borderRadius: BorderRadius.circular(
                                        _TD.mobileInnerRadius)),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      SizedBox(
                                          height: 170,
                                          child: CustomPaint(
                                              painter: _ReportPulseChartPainter(
                                                  points: timelineHr))),
                                      const SizedBox(height: 10),
                                      Row(children: [
                                        _previewMetric(
                                            '${maxSpeed.toStringAsFixed(1)} км/ч',
                                            'Скорость'),
                                        _previewMetric(
                                            avgHr > 0
                                                ? '${avgHr.toStringAsFixed(0)} уд/мин'
                                                : '—',
                                            'Ср. пульс'),
                                        _previewMetric(
                                            '$sprintCount', 'Спринты'),
                                      ]),
                                    ]),
                              ),
                            ],
                          ]),
                    ),
                ],
              );
            }
            final tabletReport = constraints.maxWidth < 1800;
            if (tabletReport) {
              final movingPlayers = reportPlayers
                  .where((p) => p.hasAny)
                  .toList(growable: false)
                ..sort((a, b) => b.distanceM.compareTo(a.distanceM));
              final attachedCount = _attachedPlayerIdsForExport.isNotEmpty
                  ? _attachedPlayerIdsForExport.length
                  : math.max(1, movingPlayers.length);
              final teamDistanceM = (report?.summary.totalDistanceM ?? 0) > 0
                  ? report!.summary.totalDistanceM
                  : (s.distanceM > 0
                      ? s.distanceM
                      : movingPlayers.fold<double>(
                          0, (a, p) => a + p.distanceM));
              final avgHrRows = reportPlayers
                  .where((p) => p.heartRateAvgBpm > 0)
                  .toList(growable: false);
              final timelineHr = report?.heartRateTimeline
                      .where((p) => p.bpm > 0)
                      .toList(growable: false) ??
                  const <TrackerHeartRatePoint>[];
              final avgHr = (report?.summary.heartRateAvgBpm ?? 0) > 0
                  ? report!.summary.heartRateAvgBpm
                  : timelineHr.isNotEmpty
                      ? timelineHr.fold<double>(0, (a, p) => a + p.bpm) /
                          timelineHr.length
                      : avgHrRows.isEmpty
                          ? 0.0
                          : avgHrRows.fold<double>(
                                  0, (a, p) => a + p.heartRateAvgBpm) /
                              avgHrRows.length;
              final maxSpeed = (report?.summary.maxSpeedKmh ?? 0) > 0
                  ? report!.summary.maxSpeedKmh
                  : s.maxSpeedKmh;
              final sprintCount = (report?.summary.sprintCount ?? 0) > 0
                  ? report!.summary.sprintCount
                  : s.sprintCount;
              final routePoints =
                  report?.routePoints ?? const <TrackerReportPoint>[];
              final heatPoints =
                  report?.heatmapPoints ?? const <TrackerReportPoint>[];
              final distanceKm = teamDistanceM / 1000;

              Widget tabletCard(
                  {required IconData icon,
                  required String title,
                  String? subtitle,
                  Widget? trailing,
                  required Widget child}) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(_TD.mobileInnerRadius),
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 9, 10, 7),
                          child: Row(children: [
                            Container(
                              width: 30,
                              height: 30,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                  color: _TD.greenSoft,
                                  borderRadius: BorderRadius.circular(
                                      _TD.mobileInnerRadius),
                                  border: Border.all(
                                      color: _TD.greenBorder, width: .9)),
                              child: Icon(icon, color: _TD.green, size: 16),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: _TD.text,
                                          fontSize: 12.8,
                                          fontWeight: FontWeight.w700,
                                          height: 1)),
                                  if ((subtitle ?? '').trim().isNotEmpty) ...[
                                    const SizedBox(height: 5),
                                    Text(subtitle!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            color: _TD.muted,
                                            fontSize: 11.0,
                                            fontWeight: FontWeight.w600,
                                            height: 1)),
                                  ],
                                ])),
                            if (trailing != null) trailing,
                          ]),
                        ),
                        Expanded(
                            child: Padding(
                                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                                child: child)),
                      ]),
                );
              }

              Widget metricCard(IconData icon, String value, String label) {
                return Container(
                  height: 60,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(_TD.mobileCardRadius),
                  ),
                  child: Row(children: [
                    Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            color: _TD.greenSoft,
                            borderRadius:
                                BorderRadius.circular(_TD.interactiveRadius),
                            border:
                                Border.all(color: _TD.greenBorder, width: .8)),
                        child: Icon(icon, color: _TD.green, size: 16)),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                          Text(value,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: _TD.text,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  height: 1)),
                          const SizedBox(height: 6),
                          Text(label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: _TD.muted,
                                  fontSize: 10.4,
                                  fontWeight: FontWeight.w600,
                                  height: 1)),
                        ])),
                  ]),
                );
              }

              Widget previewCard(
                  {required String title,
                  required Widget child,
                  double height = 260}) {
                return Container(
                  height: height,
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(_TD.mobileInnerRadius),
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: _TD.text,
                                fontSize: 14.0,
                                fontWeight: FontWeight.w700,
                                height: 1)),
                        const SizedBox(height: 8),
                        Expanded(child: child),
                      ]),
                );
              }

              final reportActions = Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.end,
                  children: [
                    if (widget.onPickSession != null)
                      _DarkActionButton(
                          icon: Icons.calendar_month_rounded,
                          label: 'Выбор тренировки',
                          onTap: widget.onPickSession!),
                    _DarkActionButton(
                        icon: Icons.picture_as_pdf_rounded,
                        label: 'PDF / печать',
                        primary: true,
                        onTap: () => _openExport('pdf')),
                    _DarkActionButton(
                        icon: Icons.table_chart_rounded,
                        label: 'Excel / CSV',
                        onTap: () => _openExport('excel')),
                  ]);

              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(_TD.mobileInnerRadius),
                    ),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                              width: 50,
                              height: 42,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                  color: _TD.greenSoft,
                                  borderRadius: BorderRadius.circular(
                                      _TD.mobileButtonRadius),
                                  border: Border.all(
                                      color: _TD.greenBorder, width: .9)),
                              child: const Icon(Icons.assignment_rounded,
                                  color: _TD.green, size: 26)),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text('Отчёт по сессии #${s.id}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: _TD.text,
                                        fontSize: 19.0,
                                        fontWeight: FontWeight.w700,
                                        height: 1)),
                                const SizedBox(height: 7),
                                Text('${widget.teamName} · ${s.createdAt}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: _TD.muted,
                                        fontSize: 12.6,
                                        fontWeight: FontWeight.w600,
                                        height: 1)),
                                const SizedBox(height: 5),
                                Text(
                                    'Игроки: ${_playersLabel()} · разделы: ${_sectionsForExport.length}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: _TD.green,
                                        fontSize: 12.0,
                                        fontWeight: FontWeight.w700,
                                        height: 1)),
                              ])),
                          const SizedBox(width: 8),
                          ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 460),
                              child: reportActions),
                        ]),
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                        child: metricCard(Icons.groups_rounded,
                            '$attachedCount', 'Игроки в отчёте')),
                    const SizedBox(width: 8),
                    Expanded(
                        child: metricCard(
                            Icons.route_rounded,
                            '${distanceKm.toStringAsFixed(2)} км',
                            'Командная дистанция')),
                    const SizedBox(width: 8),
                    Expanded(
                        child: metricCard(
                            Icons.favorite_rounded,
                            avgHr > 0
                                ? '${avgHr.toStringAsFixed(0)} уд/мин'
                                : '—',
                            'Средний пульс')),
                    const SizedBox(width: 8),
                    Expanded(
                        child: metricCard(
                            Icons.speed_rounded,
                            '${maxSpeed.toStringAsFixed(1)} км/ч',
                            'Макс. скорость')),
                  ]),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 360,
                    child: Row(children: [
                      Expanded(
                          flex: 11,
                          child: tabletCard(
                              icon: Icons.groups_rounded,
                              title: 'Игроки для выгрузки',
                              subtitle: _playersLabel(),
                              child: _attachedPlayersCard(sortedPlayers,
                                  reportPlayers: reportPlayers,
                                  loadingPresence: loadingPresence,
                                  presenceError: presenceError))),
                      const SizedBox(width: 8),
                      Expanded(
                          flex: 14,
                          child: tabletCard(
                              icon: Icons.dashboard_customize_rounded,
                              title: 'Что включить',
                              subtitle:
                                  '${_sectionsForExport.length} разделов PDF / Excel',
                              child: _sectionsCard())),
                    ]),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 225,
                    child: tabletCard(
                        icon: Icons.tune_rounded,
                        title: 'Параметры выгрузки',
                        subtitle: 'логотип, фото, листы игроков и формат',
                        child: _paramsCard()),
                  ),
                  const SizedBox(height: 10),
                  const Text('Предпросмотр отчёта',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: _TD.text,
                          fontSize: 17.0,
                          fontWeight: FontWeight.w700,
                          height: 1)),
                  const SizedBox(height: 8),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (_summary)
                      Expanded(
                        flex: 6,
                        child: previewCard(
                          title: 'Сводка команды',
                          height: 250,
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(children: [
                                  _previewMetric('$attachedCount', 'Игрока'),
                                  _previewMetric(
                                      '${distanceKm.toStringAsFixed(2)} км',
                                      'Дистанция'),
                                  _previewMetric(
                                      avgHr > 0
                                          ? '${avgHr.toStringAsFixed(0)}'
                                          : '—',
                                      'Ср. пульс'),
                                  _previewMetric(
                                      '${maxSpeed.toStringAsFixed(1)}',
                                      'Макс. скор.'),
                                ]),
                                const Divider(height: 18, color: _TD.softLine),
                                const Text('Топ по дистанции',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color: _TD.text,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        height: 1)),
                                const SizedBox(height: 8),
                                for (var i = 0;
                                    i < math.min(4, movingPlayers.length);
                                    i++)
                                  _previewTableRow(
                                      '${i + 1}',
                                      movingPlayers[i].name,
                                      '${(movingPlayers[i].distanceM / 1000).toStringAsFixed(2)} км'),
                                if (movingPlayers.isEmpty)
                                  _previewTableRow(
                                      '1',
                                      reportPlayers.isNotEmpty
                                          ? reportPlayers.first.name
                                          : 'Игрок',
                                      '${distanceKm.toStringAsFixed(2)} км'),
                              ]),
                        ),
                      ),
                    if (_summary && _maps) const SizedBox(width: 8),
                    if (_maps)
                      Expanded(
                        flex: 7,
                        child: previewCard(
                          title: 'Карта перемещений',
                          height: 250,
                          child: CustomPaint(
                              painter:
                                  _ReportMiniPitchPainter(points: routePoints)),
                        ),
                      ),
                  ]),
                  const SizedBox(height: 8),
                  if (_heatmap || _heartRate || _internal)
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_heatmap)
                            Expanded(
                                child: previewCard(
                                    title: 'Тепловая карта',
                                    child: CustomPaint(
                                        painter: _ReportMiniHeatmapPainter(
                                            points: heatPoints.isEmpty
                                                ? routePoints
                                                : heatPoints)))),
                          if (_heatmap && (_heartRate || _internal))
                            const SizedBox(width: 8),
                          if (_heartRate || _internal)
                            Expanded(
                                child: previewCard(
                                    title:
                                        'Пульс команды${avgHr > 0 ? ' · ${avgHr.toStringAsFixed(0)} уд/мин' : ''}',
                                    child: CustomPaint(
                                        painter: _ReportPulseChartPainter(
                                            points: timelineHr)))),
                        ]),
                  const SizedBox(height: 8),
                  if (_zones || _speedChart || _mechanics || _internal)
                    Row(children: [
                      if (_zones || _speedChart)
                        Expanded(
                            child: previewCard(
                                title: 'Спринты и зоны',
                                height: 170,
                                child: Row(children: [
                                  _previewMetric('$sprintCount', 'Спринты'),
                                  _previewMetric(
                                      '${(report?.summary.sprintDistanceM ?? s.sprintDistanceM).toStringAsFixed(0)} м',
                                      'Спринт'),
                                  _previewMetric(
                                      '${(report?.summary.v4HsrM ?? 0).toStringAsFixed(0)} м',
                                      'HSR')
                                ]))),
                      if ((_zones || _speedChart) && (_mechanics || _internal))
                        const SizedBox(width: 8),
                      if (_mechanics || _internal)
                        Expanded(
                            child: previewCard(
                                title: 'Игровая нагрузка',
                                height: 170,
                                child: Row(children: [
                                  _previewMetric(
                                      '${(report?.summary.playerLoad ?? 0).toStringAsFixed(0)}',
                                      'Нагрузка'),
                                  _previewMetric(
                                      '${(report?.summary.accelerationCount ?? s.accelCount)}',
                                      'Уск.'),
                                  _previewMetric(
                                      '${(report?.summary.decelerationCount ?? s.decelCount)}',
                                      'Торм.')
                                ]))),
                    ]),
                ],
              );
            }
            final topHeight =
                math.max(290.0, math.min(360.0, constraints.maxHeight * .44));
            return SingleChildScrollView(
              padding: EdgeInsets.zero,
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: topHeight,
                        child: Row(children: [
                          Expanded(
                              flex: 12,
                              child: _reportBlock(
                                  title: '2. Игроки для выгрузки',
                                  subtitle: 'прикреплены к сессии',
                                  child: _attachedPlayersCard(sortedPlayers,
                                      reportPlayers: reportPlayers,
                                      loadingPresence: loadingPresence,
                                      presenceError: presenceError))),
                          Expanded(
                              flex: 14,
                              child: _reportBlock(
                                  title: '3. Что включить в отчёт',
                                  child: _sectionsCard())),
                          Expanded(
                              flex: 10,
                              child: _reportBlock(
                                  title: '4. Параметры выгрузки',
                                  child: _paramsCard())),
                        ]),
                      ),
                      SizedBox(
                          height: math.max(
                              312.0, constraints.maxHeight - topHeight),
                          child:
                              _reportPreview(s, reportPlayers, report: report)),
                    ]),
              ),
            );
          },
        );
      },
    );
  }
}

class _ReportMiniPitchPainter extends CustomPainter {
  const _ReportMiniPitchPainter({this.points = const <TrackerReportPoint>[]});

  final List<TrackerReportPoint> points;

  Color _speedColor(double speedKmh) {
    if (speedKmh >= 16) return const Color(0xFFD84C4C);
    if (speedKmh >= 8) return const Color(0xFF41B363);
    return const Color(0xFF3468E8);
  }

  List<TrackerReportPoint> _samplePoints(
      List<TrackerReportPoint> source, int maxPoints) {
    if (source.length <= maxPoints) return source;
    final step = source.length / maxPoints;
    final out = <TrackerReportPoint>[];
    for (var i = 0.0; i < source.length; i += step) {
      out.add(source[i.floor().clamp(0, source.length - 1)]);
    }
    if (out.last != source.last) out.add(source.last);
    return out;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(18)),
        Paint()..color = const Color(0xFF788E74));

    final stripePaint = Paint()..color = const Color(0xFF8A9E85);
    for (var i = 0; i < 12; i++) {
      if (i.isOdd) continue;
      final left = size.width / 12 * i;
      canvas.drawRect(
          Rect.fromLTWH(left, 0, size.width / 12, size.height), stripePaint);
    }

    final field = Rect.fromLTWH(16, 14, size.width - 32, size.height - 28);
    final line = Paint()
      ..color = Colors.white.withOpacity(.82)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7;
    canvas.drawRRect(
        RRect.fromRectAndRadius(field, const Radius.circular(12)), line);
    canvas.drawLine(Offset(field.center.dx, field.top),
        Offset(field.center.dx, field.bottom), line);
    canvas.drawCircle(
        field.center, math.min(field.width, field.height) * .12, line);
    canvas.drawRect(
        Rect.fromLTWH(field.left, field.center.dy - 72, field.width * .16, 144),
        line);
    canvas.drawRect(
        Rect.fromLTWH(field.left, field.center.dy - 40, field.width * .08, 80),
        line);
    canvas.drawRect(
        Rect.fromLTWH(field.right - field.width * .16, field.center.dy - 72,
            field.width * .16, 144),
        line);
    canvas.drawRect(
        Rect.fromLTWH(field.right - field.width * .08, field.center.dy - 40,
            field.width * .08, 80),
        line);
    canvas.drawCircle(Offset(field.left + field.width * .105, field.center.dy),
        5.5, Paint()..color = Colors.white.withOpacity(.70));
    canvas.drawCircle(Offset(field.right - field.width * .105, field.center.dy),
        5.5, Paint()..color = Colors.white.withOpacity(.70));

    final groups = <String, List<TrackerReportPoint>>{};
    for (final p in points) {
      final key = p.playerId != null && p.playerId! > 0
          ? 'id:${p.playerId}'
          : (p.playerName.trim().isNotEmpty
              ? 'name:${p.playerName.trim().toLowerCase()}'
              : 'team');
      groups.putIfAbsent(key, () => <TrackerReportPoint>[]).add(p);
    }
    final pointGroups = groups.isEmpty
        ? <List<TrackerReportPoint>>[]
        : groups.values.toList(growable: false);
    final activeGroups =
        pointGroups.where((g) => g.length >= 2).toList(growable: false);

    if (activeGroups.isEmpty) {
      final demo = [
        Offset(field.left + field.width * .04, field.bottom - 18),
        Offset(field.left + field.width * .14, field.bottom - 28),
        Offset(field.left + field.width * .28, field.bottom - 34),
        Offset(field.left + field.width * .40, field.bottom - 46),
        Offset(field.left + field.width * .55, field.center.dy + 24),
        Offset(field.left + field.width * .68, field.center.dy - 8),
        Offset(field.right - 16, field.top + 24),
      ];
      final linePaint = Paint()
        ..color = const Color(0xFF39AE58)
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < demo.length - 1; i++) {
        canvas.drawLine(demo[i], demo[i + 1], linePaint);
      }
      for (var i = 0; i < demo.length; i++) {
        final color = i < 3
            ? const Color(0xFF3468E8)
            : (i < 5 ? const Color(0xFF41B363) : const Color(0xFFD84C4C));
        canvas.drawCircle(
            demo[i], 4.8, Paint()..color = color.withOpacity(.16));
        canvas.drawCircle(demo[i], 2.4, Paint()..color = color);
      }
      return;
    }

    final labelStyle = TextStyle(
        color: const Color(0xFF2F5EE8).withOpacity(.96),
        fontSize: 11.2,
        fontWeight: FontWeight.w700);
    for (final rawGroup in activeGroups) {
      final group = _samplePoints(rawGroup, 54);
      Offset? lastLabeled;
      for (var i = 0; i < group.length; i++) {
        final p = group[i];
        final current = Offset(
          field.left + p.x.clamp(0.0, 1.0).toDouble() * field.width,
          field.top + p.y.clamp(0.0, 1.0).toDouble() * field.height,
        );
        if (i > 0 && !p.breakBefore) {
          final prev = group[i - 1];
          final prevOffset = Offset(
            field.left + prev.x.clamp(0.0, 1.0).toDouble() * field.width,
            field.top + prev.y.clamp(0.0, 1.0).toDouble() * field.height,
          );
          canvas.drawLine(
              prevOffset,
              current,
              Paint()
                ..color = const Color(0xFF39AE58)
                ..strokeWidth = 2.0
                ..strokeCap = StrokeCap.round);
        }
        final color = _speedColor(p.speedKmh);
        canvas.drawCircle(
            current, 5.2, Paint()..color = color.withOpacity(.14));
        canvas.drawCircle(current, 2.4, Paint()..color = color);
        if (p.speedKmh > 0 &&
            (lastLabeled == null || (current - lastLabeled).distance > 36)) {
          final tp = TextPainter(
              text: TextSpan(
                  text: p.speedKmh.toStringAsFixed(1), style: labelStyle),
              textDirection: TextDirection.ltr);
          tp.layout();
          tp.paint(canvas, Offset(current.dx + 4, current.dy - 18));
          lastLabeled = current;
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ReportMiniPitchPainter oldDelegate) =>
      oldDelegate.points != points;
}

class _ReportMiniHeatmapPainter extends CustomPainter {
  const _ReportMiniHeatmapPainter({this.points = const <TrackerReportPoint>[]});

  final List<TrackerReportPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(18)),
      Paint()..color = const Color(0xFF788E74),
    );

    final stripePaint = Paint()..color = const Color(0xFF8A9E85);
    for (var i = 0; i < 12; i++) {
      if (i.isEven) {
        canvas.drawRect(
            Rect.fromLTWH(size.width / 12 * i, 0, size.width / 12, size.height),
            stripePaint);
      }
    }

    final field = Rect.fromLTWH(16, 14, size.width - 32, size.height - 28);
    final line = Paint()
      ..color = Colors.white.withOpacity(.82)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.7;
    canvas.drawRRect(
        RRect.fromRectAndRadius(field, const Radius.circular(12)), line);
    canvas.drawLine(Offset(field.center.dx, field.top),
        Offset(field.center.dx, field.bottom), line);
    canvas.drawCircle(
        field.center, math.min(field.width, field.height) * .12, line);
    canvas.drawRect(
        Rect.fromLTWH(field.left, field.center.dy - 72, field.width * .16, 144),
        line);
    canvas.drawRect(
        Rect.fromLTWH(field.left, field.center.dy - 40, field.width * .08, 80),
        line);
    canvas.drawRect(
        Rect.fromLTWH(field.right - field.width * .16, field.center.dy - 72,
            field.width * .16, 144),
        line);
    canvas.drawRect(
        Rect.fromLTWH(field.right - field.width * .08, field.center.dy - 40,
            field.width * .08, 80),
        line);
    canvas.drawCircle(Offset(field.left + field.width * .105, field.center.dy),
        5.5, Paint()..color = Colors.white.withOpacity(.70));
    canvas.drawCircle(Offset(field.right - field.width * .105, field.center.dy),
        5.5, Paint()..color = Colors.white.withOpacity(.70));

    final usable = points
        .where((p) => p.x >= 0 && p.x <= 1 && p.y >= 0 && p.y <= 1)
        .toList(growable: false);
    final heat = usable.isEmpty
        ? <TrackerReportPoint>[
            const TrackerReportPoint(x: .18, y: .80, value: 1.0),
            const TrackerReportPoint(x: .24, y: .76, value: .9),
            const TrackerReportPoint(x: .58, y: .48, value: .75),
            const TrackerReportPoint(x: .76, y: .28, value: .65),
          ]
        : usable;
    final maxValue = heat.fold<double>(
        1,
        (m, p) => math.max(
            m, math.max(p.value, p.speedKmh > 0 ? p.speedKmh / 20 : 0.35)));
    final limit = heat.length > 160 ? 160 : heat.length;
    for (var i = 0; i < limit; i++) {
      final p =
          heat[(i * heat.length / limit).floor().clamp(0, heat.length - 1)];
      final center = Offset(
          field.left + p.x.clamp(0.0, 1.0).toDouble() * field.width,
          field.top + p.y.clamp(0.0, 1.0).toDouble() * field.height);
      final strength =
          (math.max(p.value, p.speedKmh > 0 ? p.speedKmh / 20 : 0.45) /
                  maxValue)
              .clamp(.25, 1.0)
              .toDouble();
      final radius = 3.5 + 7.5 * strength;
      final color =
          Color.lerp(_TD.green, const Color(0xFFFFC928), strength * .72) ??
              _TD.green;
      final hotColor = Color.lerp(color, const Color(0xFFE94B4B),
              math.max(0, strength - .72) * 3.0) ??
          color;
      final rect = Rect.fromCircle(center: center, radius: radius);
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            hotColor.withOpacity(.32 * strength),
            color.withOpacity(.10 * strength),
            Colors.transparent,
          ],
          stops: const [0, .42, 1],
        ).createShader(rect);
      canvas.drawCircle(center, radius, paint);
    }
    // Мягкая маска внутри поля, чтобы тепловые пятна не воспринимались как маршрут.
    canvas.drawRRect(
      RRect.fromRectAndRadius(field, const Radius.circular(12)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = Colors.white.withOpacity(.84),
    );
  }

  @override
  bool shouldRepaint(covariant _ReportMiniHeatmapPainter oldDelegate) =>
      oldDelegate.points != points;
}

class _ReportPulseChartPainter extends CustomPainter {
  const _ReportPulseChartPainter(
      {this.points = const <TrackerHeartRatePoint>[]});

  final List<TrackerHeartRatePoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final grid = Paint()
      ..color = _TD.softLine
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final values = points
        .where((p) => p.bpm > 0)
        .map((p) => p.bpm.toDouble())
        .toList(growable: false);
    final path = Path();
    if (values.length >= 2) {
      final minBpm = math.max(
          45.0, values.reduce((a, b) => math.min(a, b).toDouble()) - 8);
      final maxBpm = math.max(
          minBpm + 20, values.reduce((a, b) => math.max(a, b).toDouble()) + 8);
      for (var i = 0; i < values.length; i++) {
        final x = size.width * (i / math.max(1, values.length - 1));
        final ratio = ((values[i] - minBpm) / (maxBpm - minBpm))
            .clamp(0.0, 1.0)
            .toDouble();
        final y = size.height * (1 - ratio);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
    } else {
      for (var i = 0; i <= 48; i++) {
        final x = size.width * i / 48;
        final wave = math.sin(i * .55) * 0.18 + math.sin(i * 1.35) * 0.07;
        final y = size.height * (.48 - wave);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
    }
    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(fill, Paint()..color = _TD.green.withOpacity(.08));
    canvas.drawPath(
        path,
        Paint()
          ..color = _TD.green
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(covariant _ReportPulseChartPainter oldDelegate) =>
      oldDelegate.points != points;
}

class _TrackerCalendarSessionBadge extends StatelessWidget {
  const _TrackerCalendarSessionBadge(
      {required this.count, required this.selected, this.size = 16});

  final int count;
  final bool selected;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = count <= 1
        ? const <Color>[_TD.green]
        : count == 2
            ? const <Color>[_TD.green, _TD.blue]
            : const <Color>[_TD.green, _TD.blue, _TD.cyan];
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _TrackerCalendarSessionBadgePainter(
            colors: colors, borderColor: Colors.white),
        child: count > 1
            ? Center(
                child: Text(
                  count > 9 ? '9+' : '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9.6,
                    fontWeight: FontWeight.w700,
                    height: 1,
                    shadows: [Shadow(color: Color(0x66000000), blurRadius: 4)],
                  ),
                ),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

class _TrackerCalendarSessionBadgePainter extends CustomPainter {
  const _TrackerCalendarSessionBadgePainter(
      {required this.colors, required this.borderColor});

  final List<Color> colors;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final safeColors = colors.isEmpty ? const <Color>[_TD.green] : colors;
    final fill = Paint()..style = PaintingStyle.fill;
    if (safeColors.length == 1) {
      fill.color = safeColors.first;
      canvas.drawOval(rect, fill);
    } else {
      final sweep = (math.pi * 2) / safeColors.length;
      var start = -math.pi / 2;
      for (final color in safeColors) {
        fill.color = color;
        canvas.drawArc(rect, start, sweep, true, fill);
        start += sweep;
      }
    }
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = borderColor;
    canvas.drawOval(rect.deflate(.75), border);
  }

  @override
  bool shouldRepaint(
      covariant _TrackerCalendarSessionBadgePainter oldDelegate) {
    if (oldDelegate.borderColor != borderColor) return true;
    if (oldDelegate.colors.length != colors.length) return true;
    for (var i = 0; i < colors.length; i++) {
      if (oldDelegate.colors[i] != colors[i]) return true;
    }
    return false;
  }
}

class _TD {
  // Та же светлая CMR / Windows 11 схема, что в CMR Team Matches.
  static const bg = Color(0xFFFFFFFF);
  static const rail = Color(0xFFFFFFFF);
  static const panel = Color(0xFFFFFFFF);
  static const glass = Color(0xF8FFFFFF);
  static const card = Color(0xFFFFFFFF);
  static const card2 = Color(0xFFFFFFFF);
  static const soft = Color(0xFFFFFFFF);
  static const soft2 = Color(0xFFFFFFFF);
  static const border = Color(0xFFE9ECEA);
  static const borderStrong = Color(0xFFE1E5E2);
  static const softLine = Color(0xFFE9ECEA);
  static const grid = Color(0xFFDDE2DF);

  static const text = Color(0xFF111512);
  static const graphite = Color(0xFF252B27);
  static const graphiteSoft = Color(0xFF4F5B54);
  static const muted = Color(0xFF374151);
  static const dim = Color(0xFF737B76);

  static const green = Color(0xFF00A750);
  static const greenDark = Color(0xFF067A46);
  static const greenSoft = Color(0xFFF3FAF6);
  static const greenBorder = Color(0xFFD8EDE1);
  static const yellow = Color(0xFFF59E0B);
  static const orange = Color(0xFFF59E0B);
  static const red = Color(0xFFDC2626);
  static const redSoft = Color(0xFFFEF2F2);
  static const blue = Color(0xFF2563EB);
  static const blueSoft = Color(0xFFF4F7FF);
  static const cyan = Color(0xFF06B6D4);
  static const violet = Color(0xFF7C3AED);

  // Строгая геометрия Tracker Workspace.
  // Панели/таблицы — без скруглений; интерактивные элементы — 8 px;
  // внешнее окно — 14 px; диалоги — 16 px; bottom sheet — 18 px.
  static const double mobilePagePadding = 2.0;
  static const double mobileCardRadius = 10.0;
  static const double mobileInnerRadius = 8.0;
  static const double mobileButtonRadius = 10.0;
  static const double tabletCardRadius = 0.0;
  static const double tabletInnerRadius = 8.0;
  static const double interactiveRadius = 8.0;
  static const double windowRadius = 14.0;
  static const double dialogRadius = 16.0;
  static const double sheetRadius = 18.0;

  static List<BoxShadow> get windowShadow => const <BoxShadow>[];

  static List<BoxShadow> get cardShadow => const <BoxShadow>[];

  static BoxDecoration programWindowDecoration({
    double radius = windowRadius,
  }) =>
      BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      );

  static BoxDecoration unifiedWindow({
    double radius = windowRadius,
  }) =>
      BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      );

  static BoxDecoration workspaceBg() => const BoxDecoration(
        color: bg,
      );

  static BoxDecoration seamlessPane({double radius = 0}) => BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
      );

  static BoxDecoration softSurface({double radius = 0, bool active = false}) =>
      BoxDecoration(
        color: active ? greenSoft : Colors.white,
        border: Border(
            bottom: BorderSide(
                color: active ? green : border, width: active ? 2 : .7)),
      );
}

extension _SectionExt on TrackerWorkspaceSection {
  String get title => switch (this) {
        TrackerWorkspaceSection.dashboard => 'Главная',
        TrackerWorkspaceSection.live => 'Live',
        TrackerWorkspaceSection.analytics => 'Аналитика',
        TrackerWorkspaceSection.activity => 'Игроки',
        TrackerWorkspaceSection.sessions => 'Отчёт',
        TrackerWorkspaceSection.devices => 'Трекеры',
        TrackerWorkspaceSection.field => 'Поле',
        TrackerWorkspaceSection.personal => 'Личные',
        TrackerWorkspaceSection.settings => 'Пороги',
        TrackerWorkspaceSection.debug => 'Диагн.',
      };

  IconData get icon => switch (this) {
        TrackerWorkspaceSection.dashboard => Icons.dashboard_customize_rounded,
        TrackerWorkspaceSection.live => Icons.radio_button_checked_rounded,
        TrackerWorkspaceSection.analytics => Icons.analytics_rounded,
        TrackerWorkspaceSection.activity => Icons.monitor_heart_rounded,
        TrackerWorkspaceSection.sessions => Icons.assignment_rounded,
        TrackerWorkspaceSection.devices => Icons.sensors_rounded,
        TrackerWorkspaceSection.field => Icons.map_rounded,
        TrackerWorkspaceSection.personal => Icons.notifications_active_rounded,
        TrackerWorkspaceSection.settings => Icons.tune_rounded,
        TrackerWorkspaceSection.debug => Icons.bug_report_rounded,
      };
}

class _KeepAlivePage extends StatefulWidget {
  const _KeepAlivePage({required this.child});

  final Widget child;

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class _TrackerProgramCollapsedBar extends StatelessWidget {
  const _TrackerProgramCollapsedBar({
    required this.clubName,
    required this.teamName,
    required this.liveRunning,
    required this.connected,
    required this.onRestore,
    required this.onClose,
  });

  final String clubName;
  final String teamName;
  final bool liveRunning;
  final bool connected;
  final VoidCallback onRestore;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        height: 64,
        margin: const EdgeInsets.all(10),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: _TD.panel,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            _MacWindowControls(
              maximized: false,
              onClose: onClose,
              onMinimize: onRestore,
              onToggleMaximize: onRestore,
            ),
            const SizedBox(width: 4),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              child:
                  const Icon(Icons.sensors_rounded, color: _TD.dim, size: 19),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tracker Pro свернут',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: _TD.text,
                        fontSize: 11.2,
                        fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$clubName · $teamName',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: _TD.muted,
                        fontSize: 10.4,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            _TrackerStatusDot(
              color: liveRunning ? _TD.green : _TD.dim,
              label: liveRunning ? 'LIVE' : (connected ? 'ГОТОВО' : 'ВЫКЛ'),
            ),
            const SizedBox(width: 10),
            _DarkActionButton(
              icon: Icons.open_in_full_rounded,
              label: 'Открыть',
              primary: true,
              onTap: onRestore,
            ),
          ],
        ),
      ),
    );
  }
}

class _TrackerMobileHeader extends StatelessWidget {
  const _TrackerMobileHeader({
    required this.teamId,
    required this.clubName,
    required this.teamName,
    required this.selectedPlayer,
    required this.selected,
    required this.sections,
    required this.selectedMobileSection,
    required this.loading,
    required this.liveRunning,
    required this.connected,
    required this.onSelectSection,
    required this.onRefresh,
    required this.onClose,
    required this.onMinimize,
    required this.onOpenDevices,
  });

  final int teamId;
  final String clubName;
  final String teamName;
  final String selectedPlayer;
  final TrackerWorkspaceSection selected;
  final List<TrackerWorkspaceSection> sections;
  final TrackerWorkspaceSection selectedMobileSection;
  final bool loading;
  final bool liveRunning;
  final bool connected;
  final ValueChanged<TrackerWorkspaceSection> onSelectSection;
  final VoidCallback onRefresh;
  final VoidCallback onClose;
  final VoidCallback onMinimize;
  final VoidCallback onOpenDevices;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.fromLTRB(14, 4, 8, 4),
      color: _TD.bg,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: liveRunning
                  ? _TD.green
                  : (connected ? _TD.green.withOpacity(.75) : _TD.dim),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  teamName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _TD.text,
                    fontSize: 12.4,
                    fontWeight: FontWeight.w700,
                    height: 1.02,
                    letterSpacing: -.25,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${selected.title} · $clubName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _TD.muted,
                    fontSize: 11.2,
                    fontWeight: FontWeight.w600,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          _TrackerSmallGhostButton(
            icon: Icons.more_horiz_rounded,
            onTap: () => _openMobileMenu(context),
            tooltip: 'Меню',
            prominent: true,
          ),
        ],
      ),
    );
  }

  Widget _sectionChip(TrackerWorkspaceSection section) {
    final active = section == selectedMobileSection;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(3),
      child: _NoHoverTap(
        borderRadius: BorderRadius.circular(3),
        onTap: () => onSelectSection(section),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          height: 24,
          width: active ? 94 : 66,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: Colors.transparent),
            color: Colors.transparent,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_icon(section),
                  size: 12.5, color: active ? _TD.green : _TD.graphiteSoft),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  _label(section),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: active ? _TD.green : _TD.graphite,
                    fontSize: 9.6,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                    height: 1,
                    letterSpacing: -.02,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _icon(TrackerWorkspaceSection section) => switch (section) {
        TrackerWorkspaceSection.devices => Icons.sensors_rounded,
        TrackerWorkspaceSection.live => Icons.monitor_heart_rounded,
        TrackerWorkspaceSection.analytics => Icons.bar_chart_rounded,
        TrackerWorkspaceSection.sessions => Icons.assignment_rounded,
        TrackerWorkspaceSection.field => Icons.map_rounded,
        TrackerWorkspaceSection.personal => Icons.notifications_active_rounded,
        TrackerWorkspaceSection.settings => Icons.tune_rounded,
        _ => section.icon,
      };

  String _label(TrackerWorkspaceSection section) => switch (section) {
        TrackerWorkspaceSection.devices => 'Датчики',
        TrackerWorkspaceSection.live => 'Live',
        TrackerWorkspaceSection.analytics => 'Аналитика',
        TrackerWorkspaceSection.sessions => 'Отчёт',
        TrackerWorkspaceSection.personal => 'Личные',
        TrackerWorkspaceSection.field => 'Поле',
        TrackerWorkspaceSection.settings => 'Пороги',
        _ => section.title,
      };

  void _openMobileMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      barrierColor: Colors.black.withOpacity(.42),
      shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(_TD.sheetRadius))),
      builder: (sheetContext) {
        final bottom = MediaQuery.of(sheetContext).padding.bottom;
        final maxHeight = math
            .min(MediaQuery.of(sheetContext).size.height * .82, 720.0)
            .toDouble();

        Widget handle() => Center(
              child: Container(
                width: 46,
                height: 5,
                decoration: BoxDecoration(
                    color: const Color(0xFFD4DAE3),
                    borderRadius: BorderRadius.circular(6)),
              ),
            );

        Widget statusBadge() {
          final label = liveRunning ? 'LIVE' : (connected ? 'BLE' : 'OFF');
          final color = liveRunning || connected ? _TD.green : _TD.dim;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
                color: color.withOpacity(.10),
                borderRadius: BorderRadius.circular(999)),
            child: Text(label,
                style: TextStyle(
                    fontSize: 10.4, fontWeight: FontWeight.w700, color: color)),
          );
        }

        Widget sectionTitle(String title) {
          return Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 7),
            child: Text(
              title.toUpperCase(),
              style: const TextStyle(
                  fontSize: 10.4,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF98A2B3),
                  letterSpacing: .45),
            ),
          );
        }

        Widget compactTile({
          required IconData icon,
          required String title,
          required String subtitle,
          required VoidCallback onTap,
          bool danger = false,
          bool locked = false,
          TrackerWorkspaceSection? section,
          Widget? badge,
        }) {
          final active = section != null && section == selectedMobileSection;
          final tileBg = Colors.white;
          final tileBorder = Colors.transparent;
          final iconColor = active
              ? _TD.green
              : (danger ? const Color(0xFFE11D48) : const Color(0xFF252B27));
          final titleColor = active
              ? _TD.green
              : (danger ? const Color(0xFFE11D48) : const Color(0xFF111512));
          final subtitleColor = const Color(0xFF6B746E);

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(_TD.interactiveRadius),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onTap();
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  decoration: BoxDecoration(
                    color: tileBg,
                    borderRadius: BorderRadius.zero,
                    border: Border.all(color: tileBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: active
                              ? _TD.green.withOpacity(.10)
                              : Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, size: 16, color: iconColor),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: titleColor),
                                  ),
                                ),
                                if (locked)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                        color: const Color(0xFFFFF7ED),
                                        borderRadius:
                                            BorderRadius.circular(999)),
                                    child: const Text('PRO',
                                        style: TextStyle(
                                            fontSize: 9.6,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFFEA580C))),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 11.2,
                                  fontWeight: FontWeight.w500,
                                  color: subtitleColor),
                            ),
                          ],
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 6),
                        badge,
                      ],
                      Icon(
                        active
                            ? Icons.check_rounded
                            : Icons.chevron_right_rounded,
                        size: 18,
                        color: active ? _TD.green : const Color(0xFF98A2B3),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        Widget sectionBlock(String title, List<Widget> items) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                sectionTitle(title),
                ...items,
              ],
            ),
          );
        }

        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(14, 10, 14, 14 + bottom),
            child: SizedBox(
              height: maxHeight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  handle(),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(_TD.tabletCardRadius),
                      border: Border.all(color: Colors.transparent),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: _TD.green.withOpacity(.08),
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: _TD.green.withOpacity(.06)),
                          ),
                          child: const Icon(Icons.dashboard_customize_rounded,
                              color: _TD.green, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(teamName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF111512))),
                              const SizedBox(height: 2),
                              Text('$clubName · ${selected.title}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 11.2,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF6B746E))),
                            ],
                          ),
                        ),
                        statusBadge(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Expanded(
                          child: Text('Меню трекера',
                              style: TextStyle(
                                  color: Color(0xFF111512),
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -.22))),
                      Container(
                        width: 31,
                        height: 31,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            color: _TD.green.withOpacity(.06),
                            shape: BoxShape.circle),
                        child: Text('${sections.length}',
                            style: const TextStyle(
                                color: _TD.green,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          sectionBlock('Live', [
                            compactTile(
                                icon: Icons.sensors_rounded,
                                title: 'Датчики',
                                subtitle: 'GPS, Polar и привязка игроков',
                                section: TrackerWorkspaceSection.devices,
                                onTap: () => onSelectSection(
                                    TrackerWorkspaceSection.devices)),
                            compactTile(
                                icon: Icons.monitor_heart_rounded,
                                title: 'Live',
                                subtitle: 'Старт, поле и онлайн-команда',
                                section: TrackerWorkspaceSection.live,
                                onTap: () => onSelectSection(
                                    TrackerWorkspaceSection.live)),
                            compactTile(
                                icon: Icons.bar_chart_rounded,
                                title: 'Аналитика',
                                subtitle: 'Командные графики и сравнение',
                                section: TrackerWorkspaceSection.analytics,
                                onTap: () => onSelectSection(
                                    TrackerWorkspaceSection.analytics)),
                            compactTile(
                                icon: Icons.notifications_active_rounded,
                                title: 'Личные тренировки',
                                subtitle: 'кто сейчас тренируется онлайн',
                                section: TrackerWorkspaceSection.personal,
                                badge: PlayerTrainingOnlineBadge(
                                    teamId: teamId, compact: false),
                                onTap: () => onSelectSection(
                                    TrackerWorkspaceSection.personal)),
                          ]),
                          sectionBlock('Поле и настройки', [
                            compactTile(
                                icon: Icons.map_rounded,
                                title: 'Поле',
                                subtitle: 'Калибровка поля и слои карты',
                                section: TrackerWorkspaceSection.field,
                                onTap: () => onSelectSection(
                                    TrackerWorkspaceSection.field)),
                            compactTile(
                                icon: Icons.tune_rounded,
                                title: 'Пороги',
                                subtitle: 'Скоростные зоны и параметры',
                                section: TrackerWorkspaceSection.settings,
                                onTap: () => onSelectSection(
                                    TrackerWorkspaceSection.settings)),
                          ]),
                          sectionBlock('Окно', [
                            compactTile(
                                icon: loading
                                    ? Icons.hourglass_top_rounded
                                    : Icons.refresh_rounded,
                                title: loading ? 'Обновление' : 'Обновить',
                                subtitle: 'Перезагрузить данные трекера',
                                onTap: loading ? () {} : onRefresh),
                            compactTile(
                                icon: Icons.remove_rounded,
                                title: 'Свернуть',
                                subtitle:
                                    'Убрать окно трекера в компактную строку',
                                onTap: onMinimize),
                            compactTile(
                                icon: Icons.close_rounded,
                                title: 'Закрыть',
                                subtitle: liveRunning
                                    ? 'Сохранить/проверить Live перед выходом'
                                    : 'Закрыть окно трекера',
                                danger: true,
                                onTap: onClose),
                          ]),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  TrackerWorkspaceSection? sectionForLabel(String title) => switch (title) {
        'Датчики' => TrackerWorkspaceSection.devices,
        'Live' => TrackerWorkspaceSection.live,
        'Аналитика' => TrackerWorkspaceSection.analytics,
        'Отчёт' => TrackerWorkspaceSection.sessions,
        'Личные тренировки' => TrackerWorkspaceSection.personal,
        'Личные' => TrackerWorkspaceSection.personal,
        'Поле' => TrackerWorkspaceSection.field,
        'Пороги' => TrackerWorkspaceSection.settings,
        _ => null,
      };
}

class _TrackerMobileTabs extends StatelessWidget {
  const _TrackerMobileTabs(
      {required this.sections, required this.selected, required this.onSelect});

  final List<TrackerWorkspaceSection> sections;
  final TrackerWorkspaceSection selected;
  final ValueChanged<TrackerWorkspaceSection> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            for (var i = 0; i < sections.length; i++) ...[
              if (i > 0) const SizedBox(width: 5),
              _item(sections[i]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _item(TrackerWorkspaceSection section) {
    final active = section == selected;
    return Material(
      color: Colors.transparent,
      child: _NoHoverTap(
        borderRadius: BorderRadius.circular(8),
        onTap: () => onSelect(section),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          height: 30,
          width: active ? 106 : 76,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_icon(section),
                      size: 14, color: active ? _TD.green : _TD.graphiteSoft),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      _label(section),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: active ? _TD.green : _TD.graphite,
                        fontSize: 11.0,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                        height: 1,
                        letterSpacing: -.02,
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                bottom: 0,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: active ? 28 : 0,
                  height: 2,
                  decoration: BoxDecoration(
                      color: _TD.green.withOpacity(.82),
                      borderRadius: BorderRadius.circular(999)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _icon(TrackerWorkspaceSection section) => switch (section) {
        TrackerWorkspaceSection.devices => Icons.sensors_rounded,
        TrackerWorkspaceSection.live => Icons.monitor_heart_rounded,
        TrackerWorkspaceSection.analytics => Icons.bar_chart_rounded,
        TrackerWorkspaceSection.sessions => Icons.assignment_rounded,
        TrackerWorkspaceSection.field => Icons.map_rounded,
        TrackerWorkspaceSection.personal => Icons.notifications_active_rounded,
        TrackerWorkspaceSection.settings => Icons.tune_rounded,
        _ => section.icon,
      };

  String _label(TrackerWorkspaceSection section) => switch (section) {
        TrackerWorkspaceSection.devices => 'Датчики',
        TrackerWorkspaceSection.live => 'Live',
        TrackerWorkspaceSection.analytics => 'Аналитика',
        TrackerWorkspaceSection.sessions => 'Отчёт',
        TrackerWorkspaceSection.personal => 'Личные',
        TrackerWorkspaceSection.field => 'Поле',
        TrackerWorkspaceSection.settings => 'Пороги',
        _ => section.title,
      };
}

class _TrackerMobileBottomNav extends StatelessWidget {
  const _TrackerMobileBottomNav(
      {required this.sections, required this.selected, required this.onSelect});

  final List<TrackerWorkspaceSection> sections;
  final TrackerWorkspaceSection selected;
  final ValueChanged<TrackerWorkspaceSection> onSelect;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: 62,
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
        color: Colors.white,
        child: Row(
          children: [
            for (var i = 0; i < sections.length; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(child: _item(sections[i])),
            ],
          ],
        ),
      ),
    );
  }

  Widget _item(TrackerWorkspaceSection section) {
    final active = section == selected;
    return Material(
      color: active ? _TD.green.withOpacity(.10) : Colors.transparent,
      borderRadius: BorderRadius.circular(_TD.interactiveRadius),
      child: _NoHoverTap(
        borderRadius: BorderRadius.circular(_TD.interactiveRadius),
        onTap: () => onSelect(section),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_TD.interactiveRadius),
            border:
                active ? Border.all(color: _TD.green.withOpacity(.30)) : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(section.icon,
                  size: 18, color: active ? _TD.green : _TD.graphiteSoft),
              const SizedBox(height: 3),
              Text(
                _label(section),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: active ? _TD.green : _TD.graphite,
                  fontSize: 10.4,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w700,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _label(TrackerWorkspaceSection section) => switch (section) {
        TrackerWorkspaceSection.live => 'Live',
        TrackerWorkspaceSection.analytics => 'Аналитика',
        TrackerWorkspaceSection.sessions => 'Отчёт',
        TrackerWorkspaceSection.personal => 'Личные',
        TrackerWorkspaceSection.field => 'Поле',
        TrackerWorkspaceSection.settings => 'Пороги',
        _ => section.title,
      };
}

class _TrackerToolbarScroller extends StatelessWidget {
  const _TrackerToolbarScroller({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 620),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

class _TrackerProgramSidePanel extends StatelessWidget {
  const _TrackerProgramSidePanel({
    required this.teamId,
    required this.clubName,
    required this.teamName,
    required this.selectedPlayer,
    required this.selected,
    required this.loading,
    required this.liveRunning,
    required this.connected,
    required this.compact,
    required this.collapsed,
    required this.onSelect,
    required this.onRefresh,
    required this.onClose,
    required this.onMinimize,
    this.onToggleCollapsed,
  });

  final int teamId;
  final String clubName;
  final String teamName;
  final String selectedPlayer;
  final TrackerWorkspaceSection selected;
  final bool loading;
  final bool liveRunning;
  final bool connected;
  final bool compact;
  final bool collapsed;
  final ValueChanged<TrackerWorkspaceSection> onSelect;
  final VoidCallback onRefresh;
  final VoidCallback onClose;
  final VoidCallback onMinimize;
  final VoidCallback? onToggleCollapsed;

  @override
  Widget build(BuildContext context) {
    final sections = _trackerVisibleSections;

    if (compact) {
      return Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        child: Column(
          children: [
            _TrackerSideIconButton(
              icon: Icons.sensors_rounded,
              active: liveRunning,
              tooltip: liveRunning
                  ? 'Live идёт'
                  : (connected ? 'Трекер готов' : 'Трекер выключен'),
              onTap: onRefresh,
            ),
            if (onToggleCollapsed != null) ...[
              const SizedBox(height: 4),
              _TrackerSideIconButton(
                icon: Icons.keyboard_double_arrow_right_rounded,
                active: false,
                tooltip: 'Развернуть меню',
                onTap: onToggleCollapsed,
              ),
            ],
            const SizedBox(height: 0),
            Container(height: 1, color: _TD.softLine),
            const SizedBox(height: 0),
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: sections.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (_, i) {
                  final section = sections[i];
                  return _TrackerSideIconButton(
                    icon: section.icon,
                    active: section == selected,
                    tooltip: section == TrackerWorkspaceSection.personal
                        ? 'Личные тренировки онлайн'
                        : section.title,
                    badge: section == TrackerWorkspaceSection.personal
                        ? PlayerTrainingOnlineBadge(
                            teamId: teamId, compact: true)
                        : null,
                    onTap: () => onSelect(section),
                  );
                },
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _TD.soft,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Stack(
                  children: [
                    const Center(
                        child: Icon(Icons.sensors_rounded,
                            color: _TD.dim, size: 20)),
                    Positioned(
                      right: 9,
                      bottom: 9,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: liveRunning ? _TD.green : _TD.dim,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      liveRunning
                          ? 'Трекер · LIVE'
                          : (connected ? 'Трекер · готов' : 'Трекер'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: _TD.text,
                          fontSize: 15.2,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -.45),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      teamName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: _TD.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              if (onToggleCollapsed != null) ...[
                const SizedBox(width: 4),
                _TrackerSmallGhostButton(
                  icon: Icons.keyboard_double_arrow_left_rounded,
                  onTap: onToggleCollapsed,
                  tooltip: 'Сузить меню',
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            clubName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: _TD.muted, fontSize: 11.2, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 3),
          Text(
            selectedPlayer,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: _TD.dim, fontSize: 11.2, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: sections.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (_, i) {
                final section = sections[i];
                return _TrackerSideNavItem(
                  section: section,
                  active: section == selected,
                  badge: section == TrackerWorkspaceSection.personal
                      ? PlayerTrainingOnlineBadge(
                          teamId: teamId, compact: false)
                      : null,
                  onTap: () => onSelect(section),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackerSideNavItem extends StatelessWidget {
  const _TrackerSideNavItem(
      {required this.section,
      required this.active,
      required this.onTap,
      this.badge});

  final TrackerWorkspaceSection section;
  final bool active;
  final VoidCallback onTap;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? _TD.greenSoft : Colors.transparent,
      borderRadius: BorderRadius.circular(4),
      child: _NoHoverTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: active
                ? Border.all(color: _TD.green.withOpacity(.08), width: 1)
                : null,
          ),
          child: Row(
            children: [
              Icon(section.icon, color: active ? _TD.green : _TD.dim, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  section.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: active ? _TD.text : _TD.graphite,
                    fontSize: 11.2,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                    letterSpacing: -.12,
                  ),
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 6),
                badge!,
              ] else if (active)
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                      color: _TD.green, shape: BoxShape.circle),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackerSideIconButton extends StatelessWidget {
  const _TrackerSideIconButton(
      {required this.icon,
      required this.active,
      required this.tooltip,
      this.onTap,
      this.badge});

  final IconData icon;
  final bool active;
  final String tooltip;
  final VoidCallback? onTap;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? _TD.greenSoft : _TD.soft,
      borderRadius: BorderRadius.circular(6),
      child: _NoHoverTap(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border:
                active ? Border.all(color: _TD.green.withOpacity(.08)) : null,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                  child: Icon(icon,
                      color: active ? _TD.green : _TD.dim, size: 18)),
              if (badge != null) Positioned(right: -2, top: -2, child: badge!),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackerSmallGhostButton extends StatelessWidget {
  const _TrackerSmallGhostButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.label,
    this.prominent = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String tooltip;
  final String? label;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final isMenu = prominent;
    if (isMenu) {
      return Tooltip(
        message: tooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: _TD.softLine.withOpacity(.85)),
            ),
            child: Icon(icon, color: _TD.text, size: 18),
          ),
        ),
      );
    }
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_TD.interactiveRadius),
        child: _NoHoverTap(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_TD.interactiveRadius),
              border: Border.all(color: _TD.softLine),
            ),
            child: Icon(icon, color: _TD.dim, size: 17),
          ),
        ),
      ),
    );
  }
}

class _TrackerSideFooterAction extends StatelessWidget {
  const _TrackerSideFooterAction(
      {required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _TD.soft,
      borderRadius: BorderRadius.circular(4),
      child: _NoHoverTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: _TD.dim, size: 16),
              const SizedBox(width: 4),
              Text(label,
                  style: const TextStyle(
                      color: _TD.graphite,
                      fontSize: 11.2,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackerWindowCornerButton extends StatelessWidget {
  const _TrackerWindowCornerButton(
      {required this.maximized, required this.onTap});

  final bool maximized;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _TD.soft,
      borderRadius: BorderRadius.circular(4),
      child: _NoHoverTap(
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: _TD.softLine),
          ),
          child: Icon(
              maximized
                  ? Icons.close_fullscreen_rounded
                  : Icons.open_in_full_rounded,
              size: 15,
              color: _TD.dim),
        ),
      ),
    );
  }
}

class _TrackerProgramTabsBar extends StatelessWidget {
  const _TrackerProgramTabsBar({
    required this.clubName,
    required this.teamName,
    required this.selectedPlayer,
    required this.selected,
    required this.loading,
    required this.liveRunning,
    required this.connected,
    required this.maximized,
    required this.onSelect,
    required this.onRefresh,
    required this.onClose,
    required this.onMinimize,
    required this.onToggleMaximize,
  });

  final String clubName;
  final String teamName;
  final String selectedPlayer;
  final TrackerWorkspaceSection selected;
  final bool loading;
  final bool liveRunning;
  final bool connected;
  final bool maximized;
  final ValueChanged<TrackerWorkspaceSection> onSelect;
  final VoidCallback onRefresh;
  final VoidCallback onClose;
  final VoidCallback onMinimize;
  final VoidCallback onToggleMaximize;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final compact = width < 1180;

    return Container(
      height: compact ? 56 : 60,
      padding: EdgeInsets.fromLTRB(compact ? 10 : 14, 5, compact ? 10 : 14, 5),
      decoration: BoxDecoration(
        color: _TD.panel,
        border: Border(
            bottom: BorderSide(color: _TD.softLine.withOpacity(.88), width: 1)),
      ),
      child: Row(
        children: [
          Container(
            width: compact ? 34 : 38,
            height: compact ? 34 : 38,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Stack(
              children: [
                const Center(
                  child: Icon(Icons.sensors_rounded, color: _TD.dim, size: 20),
                ),
                Positioned(
                  right: 7,
                  bottom: 7,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: connected ? _TD.green : _TD.dim,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: compact ? 148 : 198,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Tracker Pro',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _TD.text,
                          fontSize: compact ? 13.5 : 14,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -.15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    _TrackerStatusDot(
                      color: liveRunning ? _TD.green : _TD.dim,
                      label: liveRunning
                          ? 'LIVE'
                          : (connected ? 'ГОТОВО' : 'ВЫКЛ'),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '$clubName · $teamName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _TD.muted,
                    fontSize: 11.2,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.center,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: _trackerVisibleSections.map((section) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _TrackerProgramTab(
                        section: section,
                        active: section == selected,
                        compact: compact,
                        onTap: () => onSelect(section),
                      ),
                    );
                  }).toList(growable: false),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          _TrackerProgramIconButton(
            icon: Icons.refresh_rounded,
            tooltip: 'Обновить данные трекера',
            loading: loading,
            onTap: loading ? null : onRefresh,
          ),
        ],
      ),
    );
  }
}

class _MacWindowControls extends StatelessWidget {
  const _MacWindowControls({
    required this.maximized,
    required this.onClose,
    required this.onMinimize,
    required this.onToggleMaximize,
  });

  final bool maximized;
  final VoidCallback onClose;
  final VoidCallback onMinimize;
  final VoidCallback onToggleMaximize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MacWindowButton(
          icon: Icons.close_rounded,
          tooltip: 'Закрыть окно трекера',
          onTap: onClose,
        ),
        const SizedBox(width: 7),
        _MacWindowButton(
          icon: Icons.remove_rounded,
          tooltip: 'Свернуть',
          onTap: onMinimize,
        ),
        const SizedBox(width: 7),
        _MacWindowButton(
          icon: maximized
              ? Icons.close_fullscreen_rounded
              : Icons.open_in_full_rounded,
          tooltip: maximized ? 'Вернуть размер' : 'Развернуть',
          onTap: onToggleMaximize,
        ),
      ],
    );
  }
}

class _MacWindowButton extends StatelessWidget {
  const _MacWindowButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _TD.soft,
      shape: const CircleBorder(),
      child: _NoHoverTap(
        onTap: onTap,
        child: SizedBox(
          width: 26,
          height: 26,
          child: Icon(icon, size: 12, color: _TD.dim),
        ),
      ),
    );
  }
}

class _TrackerProgramTab extends StatelessWidget {
  const _TrackerProgramTab({
    required this.section,
    required this.active,
    required this.compact,
    required this.onTap,
  });

  final TrackerWorkspaceSection section;
  final bool active;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = active ? Colors.white.withOpacity(.92) : Colors.transparent;
    final fg = active ? _TD.text : _TD.graphiteSoft;
    final iconColor = active ? _TD.green : _TD.dim;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      height: compact ? 34 : 36,
      constraints: BoxConstraints(minWidth: compact ? 42 : 82),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: active
            ? Border.all(color: _TD.greenBorder)
            : Border.all(color: Colors.transparent),
      ),
      child: Material(
        color: Colors.transparent,
        child: _NoHoverTap(
          borderRadius: BorderRadius.circular(6),
          hoverColor: _TD.soft,
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(section.icon, size: 18, color: iconColor),
                if (!compact) ...[
                  const SizedBox(width: 7),
                  Text(
                    section.title,
                    style: TextStyle(
                      color: fg,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -.15,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TrackerStatusDot extends StatelessWidget {
  const _TrackerStatusDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(.07), width: .6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10.4,
              fontWeight: FontWeight.w500,
              letterSpacing: .2,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackerProgramIconButton extends StatelessWidget {
  const _TrackerProgramIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.loading = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(6),
      child: _NoHoverTap(
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
          ),
          child: loading
              ? const SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(icon, size: 20, color: _TD.text),
        ),
      ),
    );
  }
}

class _DarkRail extends StatelessWidget {
  const _DarkRail({
    required this.selected,
    required this.onSelect,
    required this.onBack,
  });

  final TrackerWorkspaceSection selected;
  final ValueChanged<TrackerWorkspaceSection> onSelect;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final items = _trackerVisibleSections;
    return Container(
      width: 68,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: items.length,
              itemBuilder: (context, i) {
                final item = items[i];
                return _RailButton(
                  icon: item.icon,
                  label: item.title,
                  active: item == selected,
                  onTap: () => onSelect(item),
                );
              },
            ),
          ),
          _RailButton(
            icon: Icons.arrow_back_rounded,
            label: 'Назад',
            active: false,
            onTap: onBack,
          ),
        ],
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? _TD.greenSoft : Colors.transparent,
      child: _NoHoverTap(
        onTap: onTap,
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: active ? _TD.green : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: active ? _TD.greenDark : _TD.graphiteSoft,
                size: 17,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: active ? _TD.text : _TD.muted,
                  fontSize: 9.6,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.teamName,
    required this.clubName,
    required this.selectedPlayer,
    required this.selectedSection,
    required this.loading,
    required this.onRefresh,
  });

  final String teamName;
  final String clubName;
  final String selectedPlayer;
  final TrackerWorkspaceSection selectedSection;
  final bool loading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selectedSection.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _TD.text,
                    fontWeight: FontWeight.w700,
                    fontSize: 13.6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$teamName  ·  $clubName  ·  $selectedPlayer',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _TD.muted,
                    fontSize: 11.0,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          _NoHoverTap(
            onTap: loading ? null : onRefresh,
            child: SizedBox(
              width: 34,
              height: 34,
              child: Center(
                child: loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(
                        Icons.refresh_rounded,
                        color: _TD.graphiteSoft,
                        size: 18,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopPill extends StatelessWidget {
  const _TopPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$label: $value',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: _TD.muted,
        fontSize: 10.4,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _WorkspacePaneDivider extends StatelessWidget {
  const _WorkspacePaneDivider.vertical({this.thickness = 1, this.padding = 0})
      : axis = Axis.vertical;
  const _WorkspacePaneDivider.horizontal({this.thickness = 1, this.padding = 0})
      : axis = Axis.horizontal;

  final Axis axis;
  final double thickness;
  final double padding;

  @override
  Widget build(BuildContext context) {
    final line = Container(color: _TD.border.withOpacity(.82));
    if (axis == Axis.vertical) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: padding),
        child: SizedBox(width: thickness, child: line),
      );
    }
    return Padding(
      padding: EdgeInsets.symmetric(vertical: padding),
      child: SizedBox(height: thickness, child: line),
    );
  }
}

class _DarkPage extends StatelessWidget {
  const _DarkPage({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    // Не рисуем второе окно внутри трекера: внешний programWindowDecoration
    // уже является общей рамкой. На телефоне секционная шапка не должна
    // висеть отдельным неподвижным блоком: весь мобильный раздел собирается
    // как roster-лента из горизонтальных действий и карточек.
    final hasToolbar = title.trim().isNotEmpty || trailing != null;
    final mq = MediaQuery.maybeOf(context);
    final mobile = mq != null && mq.size.width < 720;

    if (mobile) {
      return Container(color: Colors.transparent, child: child);
    }

    return Container(
      color: Colors.transparent,
      child: Column(
        children: [
          if (hasToolbar)
            _WorkspaceFlatHeader(
              icon: icon,
              title: title,
              subtitle: subtitle,
              trailing: trailing,
            ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _WorkspaceFlatHeader extends StatelessWidget {
  const _WorkspaceFlatHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;

        if (compact && trailing != null) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _TD.text,
                    fontSize: 13.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle.trim().isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _TD.muted,
                      fontSize: 11.2,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                SizedBox(
                  height: 32,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: trailing!,
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _TD.text,
                        fontSize: 15.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (subtitle.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _TD.muted,
                          fontSize: 11.0,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                Flexible(child: trailing!),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _DarkCard extends StatelessWidget {
  const _DarkCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final tablet = width >= 720 && width < 1180;
    final hasHeader = title.trim().isNotEmpty || subtitle.trim().isNotEmpty;

    return LayoutBuilder(
      builder: (context, constraints) {
        final canExpandBody =
            constraints.maxHeight.isFinite && constraints.maxHeight > 0;
        final body = Padding(
          padding: EdgeInsets.all(tablet ? 8 : 6),
          child: child,
        );

        return Container(
          color: Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (hasHeader)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    tablet ? 10 : 8,
                    tablet ? 8 : 6,
                    tablet ? 10 : 8,
                    4,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _TD.text,
                            fontSize: tablet ? 12.4 : 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (subtitle.trim().isNotEmpty)
                        Flexible(
                          child: Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: _TD.dim,
                              fontSize: tablet ? 9.8 : 8.8,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              if (canExpandBody) Expanded(child: body) else body,
            ],
          ),
        );
      },
    );
  }
}

class _DarkActionButton extends StatelessWidget {
  const _DarkActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final tablet = width >= 720 && width < 1180;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: _NoHoverTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Opacity(
          opacity: onTap == null ? .45 : 1,
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 11),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: primary ? _TD.greenSoft : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: primary ? _TD.greenBorder : Colors.transparent,
                width: .8,
              ),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                icon,
                color: primary ? _TD.green : _TD.muted,
                size: 14,
              ),
              if (label.trim().isNotEmpty) ...[
                const SizedBox(width: 6),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: primary ? _TD.greenDark : _TD.text,
                    fontSize: 11.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (primary) ...[
                const SizedBox(width: 6),
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: _TD.green,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

class _DarkMetricTile extends StatelessWidget {
  const _DarkMetricTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final tablet = width >= 720 && width < 1180;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: tablet ? 10 : 8,
        vertical: tablet ? 8 : 6,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _TD.text,
              fontSize: tablet ? 14 : 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _TD.muted,
              fontSize: tablet ? 10 : 9,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _TD.dim,
              fontSize: tablet ? 9.2 : 8.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _EquipmentMiniBadge extends StatelessWidget {
  const _EquipmentMiniBadge({
    required this.icon,
    required this.label,
    required this.active,
  });

  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: active ? _TD.greenDark : _TD.muted,
        fontSize: 10.4,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _EquipmentAssignmentBox extends StatelessWidget {
  const _EquipmentAssignmentBox({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _TD.text,
              fontSize: 12.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _TD.muted,
              fontSize: 11.0,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 9),
          child,
        ],
      ),
    );
  }
}

class _DarkListTile extends StatelessWidget {
  const _DarkListTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.active = false,
    this.onTap,
    this.avatarUrl,
    this.initials,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? trailing;
  final bool active;
  final VoidCallback? onTap;
  final String? avatarUrl;
  final String? initials;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final tablet = width >= 720 && width < 1180;

    return Material(
      color: active ? _TD.greenSoft : Colors.white,
      child: _NoHoverTap(
        onTap: onTap,
        child: Container(
          constraints: BoxConstraints(minHeight: tablet ? 54 : 44),
          padding: EdgeInsets.symmetric(
            horizontal: tablet ? 10 : 8,
            vertical: tablet ? 7 : 6,
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 3,
                height: tablet ? 36 : 30,
                decoration: BoxDecoration(
                  color: active ? _TD.green : Colors.transparent,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(width: 8),
              if (avatarUrl != null || initials != null)
                _PlayerAvatarDark(
                  url: avatarUrl,
                  initials: initials ?? _playerInitials(title),
                  size: tablet ? 36 : 30,
                  active: active,
                ),
              if (avatarUrl != null || initials != null)
                SizedBox(width: tablet ? 9 : 7),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _TD.text,
                        fontWeight: FontWeight.w700,
                        fontSize: tablet ? 12.2 : 10.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _TD.muted,
                        fontSize: tablet ? 10.2 : 9.2,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null)
                Text(
                  trailing!,
                  style: TextStyle(
                    color: active ? _TD.greenDark : _TD.muted,
                    fontWeight: FontWeight.w700,
                    fontSize: tablet ? 10.4 : 9,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeartRateDeviceDarkTile extends StatelessWidget {
  const _HeartRateDeviceDarkTile({
    required this.device,
    required this.players,
    required this.selectedPlayerId,
    required this.sampleText,
    required this.active,
    required this.selected,
    required this.connecting,
    required this.onSelect,
    required this.onConnect,
    required this.onPlayerChanged,
  });

  final HeartRateBleDevice device;
  final List<TrackerPlayerOption> players;
  final int? selectedPlayerId;
  final String sampleText;
  final bool active;
  final bool selected;
  final bool connecting;
  final VoidCallback onSelect;
  final VoidCallback? onConnect;
  final ValueChanged<int?> onPlayerChanged;

  @override
  Widget build(BuildContext context) {
    final stateColor = active ? _TD.green : (selected ? _TD.green : _TD.muted);
    final validValue =
        selectedPlayerId != null && players.any((p) => p.id == selectedPlayerId)
            ? selectedPlayerId
            : null;
    final status =
        active ? 'подключено' : (device.rawProbe ? 'проверить' : 'подключить');
    return Material(
      color: selected || active ? _TD.greenSoft : _TD.panel,
      child: _NoHoverTap(
        onTap: onSelect,
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: const BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: _TD.borderStrong, width: .7))),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: _TD.soft, borderRadius: BorderRadius.circular(8)),
                  child: Icon(
                      active
                          ? Icons.check_circle_rounded
                          : Icons.monitor_heart_rounded,
                      color: stateColor,
                      size: 16)),
              const SizedBox(width: 8),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(device.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: _TD.text,
                            fontWeight: FontWeight.w700,
                            fontSize: 11.2)),
                    const SizedBox(height: 2),
                    Text(
                        '${device.id} · RSSI ${device.rssi} · $sampleText${device.serviceHit ? ' · Heart Rate 180D' : (device.rawProbe ? ' · BLE-кандидат' : '')}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: _TD.muted,
                            fontSize: 10.4,
                            fontWeight: FontWeight.w600)),
                  ])),
              const SizedBox(width: 8),
              Text(status,
                  style: TextStyle(
                      color: stateColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 10.4)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int?>(
                      value: validValue,
                      isExpanded: true,
                      icon: const Icon(Icons.expand_more_rounded,
                          size: 18, color: _TD.muted),
                      hint: const Text('Назначить игроку',
                          style: TextStyle(
                              color: _TD.muted,
                              fontSize: 11.0,
                              fontWeight: FontWeight.w700)),
                      items: <DropdownMenuItem<int?>>[
                        const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('Игрок не выбран',
                                style: TextStyle(
                                    fontSize: 11.0,
                                    fontWeight: FontWeight.w700))),
                        ...players.map((p) => DropdownMenuItem<int?>(
                            value: p.id,
                            child: Text(p.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 11.0,
                                    fontWeight: FontWeight.w700)))),
                      ],
                      onChanged: onPlayerChanged,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 42,
                child: OutlinedButton.icon(
                  onPressed: connecting ? null : onConnect,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _TD.green,
                    side: const BorderSide(color: _TD.greenBorder),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6)),
                  ),
                  icon: Icon(
                      active
                          ? Icons.touch_app_rounded
                          : Icons.bluetooth_connected_rounded,
                      size: 15),
                  label: Text(active ? 'выбрать' : 'подключить',
                      style: const TextStyle(
                          fontSize: 11.2, fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _SavedDeviceDarkTile extends StatelessWidget {
  const _SavedDeviceDarkTile(
      {required this.device,
      required this.players,
      required this.onBind,
      this.onForget,
      this.aliasCount = 1,
      this.status = 'серверная запись',
      this.statusColor = _TD.muted});
  final TrackerDeviceModel device;
  final List<TrackerPlayerOption> players;
  final ValueChanged<TrackerPlayerOption?> onBind;
  final VoidCallback? onForget;
  final int aliasCount;
  final String status;
  final Color statusColor;
  @override
  Widget build(BuildContext context) {
    final boundPlayers = players.where((p) => p.id == device.playerId).toList();
    final boundPlayer = boundPlayers.isEmpty ? null : boundPlayers.first;

    return Container(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(8),
      decoration: const BoxDecoration(
          color: _TD.panel,
          border:
              Border(bottom: BorderSide(color: _TD.borderStrong, width: .7))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          children: [
            _PlayerAvatarDark(
              url: boundPlayer?.avatar,
              initials: _playerInitials(
                  boundPlayer?.name ?? device.playerName ?? device.deviceName),
              size: 30,
              active: boundPlayer != null,
              fallbackIcon: Icons.sensors_rounded,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(device.deviceName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: _TD.text,
                              fontWeight: FontWeight.w700,
                              fontSize: 11)),
                    ),
                    if (aliasCount > 1) ...[
                      const SizedBox(width: 6),
                      Text('дублей: $aliasCount',
                          style: const TextStyle(
                              color: _TD.muted,
                              fontWeight: FontWeight.w600,
                              fontSize: 11.0)),
                    ],
                  ]),
                  const SizedBox(height: 3),
                  Text(
                    '${device.deviceUuid}${boundPlayer == null && device.playerName == null ? '' : ' · ${boundPlayer?.name ?? device.playerName}'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: _TD.muted,
                        fontSize: 11.0,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(
                        status.contains('TX/RX')
                            ? Icons.bluetooth_connected_rounded
                            : (status.contains('занят')
                                ? Icons.cloud_sync_rounded
                                : Icons.link_rounded),
                        size: 13,
                        color: statusColor),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(status,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: statusColor,
                              fontSize: 11.0,
                              fontWeight: FontWeight.w700)),
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<int?>(
          value: players.any((p) => p.id == device.playerId)
              ? device.playerId
              : null,
          dropdownColor: _TD.card,
          isExpanded: true,
          decoration: InputDecoration(
            isDense: true,
            labelText: 'Игрок',
            labelStyle: const TextStyle(color: _TD.muted),
            filled: true,
            fillColor: _TD.panel,
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: BorderSide.none),
          ),
          style: const TextStyle(
              color: _TD.text, fontWeight: FontWeight.w600, fontSize: 11.2),
          items: [
            const DropdownMenuItem<int?>(
              value: null,
              child: Text('Без игрока'),
            ),
            ...players.map(
              (p) => DropdownMenuItem<int?>(
                value: p.id,
                child: Row(
                  children: [
                    _PlayerAvatarDark(
                      url: p.avatar,
                      initials: _playerInitials(p.name),
                      size: 24,
                      active: true,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        p.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          onChanged: (id) {
            final matches = players.where((p) => p.id == id).toList();
            onBind(matches.isEmpty ? null : matches.first);
          },
        ),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: Text(
              'Не live: это только запись в базе. Для поиска используйте «Поиск GPS» выше.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: _TD.muted,
                  fontSize: 10.4,
                  fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 6),
          _NoHoverTap(
            onTap: onForget,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(mainAxisSize: MainAxisSize.min, children: const [
                Icon(Icons.delete_outline_rounded, size: 14, color: _TD.red),
                SizedBox(width: 3),
                Text('Удалить запись',
                    style: TextStyle(
                        color: _TD.red,
                        fontWeight: FontWeight.w700,
                        fontSize: 10.4)),
              ]),
            ),
          ),
        ]),
      ]),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      color: _TD.muted,
                      fontSize: 11.2,
                      fontWeight: FontWeight.w700))),
          const SizedBox(width: 10),
          Flexible(
              child: Text(value,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: _TD.text,
                      fontSize: 11.2,
                      fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}

class _PlayerAvatarDark extends StatelessWidget {
  const _PlayerAvatarDark({
    required this.url,
    required this.initials,
    this.size = 30,
    this.active = false,
    this.fallbackIcon,
  });

  final String? url;
  final String initials;
  final double size;
  final bool active;
  final IconData? fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final imageUrl = _normalizeAvatarUrl(url);
    final borderColor = active ? _TD.green : _TD.border;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: active
            ? [
                BoxShadow(
                  color: _TD.blue.withOpacity(.10),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: ClipOval(
        child: imageUrl == null
            ? _AvatarFallback(
                initials: initials,
                size: size,
                icon: fallbackIcon,
              )
            : Image.network(
                imageUrl,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _AvatarFallback(
                  initials: initials,
                  size: size,
                  icon: fallbackIcon,
                ),
              ),
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({
    required this.initials,
    required this.size,
    this.icon,
  });

  final String initials;
  final double size;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xFFF2F4F7),
      ),
      child: icon != null
          ? Icon(icon, color: _TD.green, size: size * .48)
          : Text(
              initials,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: TextStyle(
                color: _TD.text,
                fontSize: size * .33,
                fontWeight: FontWeight.w500,
                letterSpacing: -.4,
              ),
            ),
    );
  }
}

String _playerInitials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.trim().isNotEmpty)
      .toList();

  if (parts.isEmpty) return 'И';
  if (parts.length == 1) {
    final s = parts.first;
    return s.length <= 2 ? s.toUpperCase() : s.substring(0, 2).toUpperCase();
  }

  return '${parts[0].substring(0, 1)}${parts[1].substring(0, 1)}'.toUpperCase();
}

String? _normalizeAvatarUrl(String? raw) {
  final value = (raw ?? '').trim();
  if (value.isEmpty || value == 'null') return null;

  if (value.startsWith('http://') || value.startsWith('https://')) {
    return value;
  }

  final cleaned = value.startsWith('/') ? value.substring(1) : value;

  // Основной домен API/загрузок, который используется в проекте.
  return 'https://sportotekaapp.ru/$cleaned';
}

class _DashboardKpiData {
  const _DashboardKpiData(
      {required this.icon,
      required this.title,
      required this.value,
      required this.subtitle});
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
}

class _DashboardKpiStrip extends StatelessWidget {
  const _DashboardKpiStrip({required this.items});

  final List<_DashboardKpiData> items;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return SizedBox(
          width: 142,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 12, 10, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _TD.text,
                    fontSize: 15.2,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.35,
                  ),
                ),
                const Spacer(),
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _TD.muted,
                    fontSize: 11.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _TD.dim,
                    fontSize: 11.2,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ReadinessRow extends StatelessWidget {
  const _ReadinessRow({
    required this.title,
    required this.text,
    required this.ok,
  });

  final String title;
  final String text;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      color: ok ? _TD.greenSoft : Colors.transparent,
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: ok ? _TD.green : _TD.orange,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _TD.text,
                    fontWeight: FontWeight.w700,
                    fontSize: 11.2,
                  ),
                ),
                Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _TD.muted,
                    fontWeight: FontWeight.w500,
                    fontSize: 11.0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScenarioButton extends StatelessWidget {
  const _ScenarioButton(
      {required this.step,
      required this.title,
      required this.text,
      required this.icon,
      required this.onTap});
  final String step;
  final String title;
  final String text;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _TD.panel,
      borderRadius: BorderRadius.circular(0),
      child: _NoHoverTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          decoration: const BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: _TD.borderStrong, width: .7))),
          child: Row(
            children: [
              CircleAvatar(
                  radius: 12,
                  backgroundColor: _TD.green.withOpacity(.06),
                  child: Text(step,
                      style: const TextStyle(
                          color: _TD.green,
                          fontSize: 10.4,
                          fontWeight: FontWeight.w600))),
              const SizedBox(width: 10),
              Icon(icon, color: _TD.graphite, size: 17),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: _TD.text,
                              fontWeight: FontWeight.w700,
                              fontSize: 11.0)),
                      Text(text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: _TD.muted,
                              fontWeight: FontWeight.w600,
                              fontSize: 10.4)),
                    ]),
              ),
              const Icon(Icons.chevron_right_rounded, color: _TD.dim),
            ],
          ),
        ),
      ),
    );
  }
}

class _DarkEmpty extends StatelessWidget {
  const _DarkEmpty({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) {
    return Center(
        child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, size: 30, color: _TD.dim),
              const SizedBox(height: 0),
              Text(text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: _TD.muted, fontWeight: FontWeight.w500)),
            ])));
  }
}

class _DarkError extends StatelessWidget {
  const _DarkError({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Center(
        child: Container(
            constraints: const BoxConstraints(maxWidth: 560),
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
                color: Color(0xFFFFF1F1),
                borderRadius: BorderRadius.circular(6)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.warning_amber_rounded, color: _TD.red),
              const SizedBox(height: 4),
              Text(error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: _TD.red, fontWeight: FontWeight.w500)),
              const SizedBox(height: 0),
              _DarkActionButton(
                  icon: Icons.refresh_rounded,
                  label: 'Повторить',
                  onTap: onRetry),
            ])));
  }
}

class _PresetDarkButton extends StatelessWidget {
  const _PresetDarkButton(
      {required this.title, required this.subtitle, required this.onTap});
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => _DarkListTile(
      icon: Icons.tune_rounded,
      title: title,
      subtitle: subtitle,
      trailing: 'применить',
      onTap: onTap);
}

class _MiniDebugPill extends StatelessWidget {
  const _MiniDebugPill({required this.label, required this.active});
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color:
            active ? _TD.green.withOpacity(.06) : _TD.orange.withOpacity(.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
                color: active ? _TD.green : _TD.orange,
                shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                color: active ? _TD.greenDark : _TD.orange,
                fontSize: 11.0,
                fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _DarkHint extends StatelessWidget {
  const _DarkHint({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(8),
        decoration: const BoxDecoration(
            color: _TD.panel,
            border:
                Border(bottom: BorderSide(color: _TD.borderStrong, width: .7))),
        child: Text(text,
            style: const TextStyle(
                color: _TD.graphiteSoft,
                fontWeight: FontWeight.w600,
                fontSize: 11.0,
                height: 1.22)));
  }
}

class _DarkCornerChip extends StatelessWidget {
  const _DarkCornerChip({
    required this.label,
    required this.value,
    required this.ready,
    this.active = false,
    this.saved = false,
    this.onTap,
  });

  final String label;
  final String value;
  final bool ready;
  final bool active;
  final bool saved;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = ready
        ? _TD.green
        : active
            ? const Color(0xFF2563EB)
            : _TD.dim;
    return _NoHoverTap(
      borderRadius: BorderRadius.circular(6),
      onTap: onTap,
      child: Container(
        width: 230,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: ready
              ? _TD.green.withOpacity(.10)
              : active
                  ? const Color(0xFF2563EB).withOpacity(.10)
                  : _TD.card2,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: color,
            child: ready
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 15)
                : Text(label,
                    style: const TextStyle(
                        color: _TD.bg,
                        fontSize: 10.4,
                        fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Text(value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: _TD.muted,
                      fontSize: 10.4,
                      fontWeight: FontWeight.w600))),
        ]),
      ),
    );
  }
}

class _RemoteTrackerPresence {
  const _RemoteTrackerPresence({
    required this.uuid,
    required this.name,
    required this.message,
    required this.createdAtLabel,
    this.playerName,
    this.teamName,
    this.fieldTitle,
    this.rssi,
    this.liveRunning = false,
    this.fieldCalibrated = false,
    this.hasFreshGps = false,
  });

  final String uuid;
  final String name;
  final String message;
  final String createdAtLabel;
  final String? playerName;
  final String? teamName;
  final String? fieldTitle;
  final int? rssi;
  final bool liveRunning;
  final bool fieldCalibrated;
  final bool hasFreshGps;

  static List<_RemoteTrackerPresence> fromLogs(
      List<Map<String, dynamic>> logs) {
    final byUuid = <String, _RemoteTrackerPresence>{};
    for (final log in logs) {
      final ctx = _decodeContext(log['context_json'] ?? log['context']);
      final rawTime = '${log['created_at'] ?? ctx['client_time'] ?? ''}';
      if (!_isFresh(rawTime, maxAgeSeconds: 65)) continue;

      final txRxReady = _asBool(ctx['ble_command_channel_ready']);
      final liveRunning = _asBool(ctx['live_running']);
      final bleConnected = _asBool(ctx['ble_connected']);
      final message = '${log['message'] ?? ''}'.toLowerCase();
      if (!(txRxReady || liveRunning || bleConnected)) continue;
      if (message.contains('tx/rx не готов') ||
          message.contains('not connected') ||
          message.contains('отключ')) continue;

      final uuid =
          '${ctx['ble_device_uuid'] ?? log['device_uuid'] ?? ''}'.trim();
      if (uuid.isEmpty || byUuid.containsKey(uuid)) continue;

      final name =
          '${ctx['ble_device_name'] ?? log['device_name'] ?? 'BLE ${uuid.length <= 8 ? uuid : uuid.substring(0, 8)}'}'
              .trim();
      final gpsText = '${ctx['last_gps'] ?? ''}'.trim().toLowerCase();
      final hasGps = gpsText.isNotEmpty &&
          !gpsText.contains('нет gps') &&
          !gpsText.contains('no gps');
      byUuid[uuid] = _RemoteTrackerPresence(
        uuid: uuid,
        name: name.isEmpty
            ? 'BLE ${uuid.length <= 8 ? uuid : uuid.substring(0, 8)}'
            : name,
        message: '${log['message'] ?? ''}'.trim(),
        createdAtLabel:
            _timeLabel('${log['created_at'] ?? ctx['client_time'] ?? ''}'),
        playerName: _emptyToNull('${ctx['player_name'] ?? ''}'),
        teamName: _emptyToNull('${ctx['team_name'] ?? ''}'),
        fieldTitle: _emptyToNull('${ctx['field_title'] ?? ''}'),
        rssi: int.tryParse('${ctx['ble_rssi'] ?? ''}'),
        liveRunning: _asBool(ctx['live_running']),
        fieldCalibrated: _asBool(ctx['field_calibrated']),
        hasFreshGps: hasGps,
      );
    }
    return byUuid.values.toList(growable: false);
  }

  static Map<String, dynamic> _decodeContext(Object? raw) {
    if (raw is Map) return Map<String, dynamic>.from(raw);
    final text = '${raw ?? ''}'.trim();
    if (text.isEmpty || text == 'null') return <String, dynamic>{};
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return <String, dynamic>{};
  }

  static bool _asBool(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = '${value ?? ''}'.toLowerCase().trim();
    return text == 'true' || text == '1' || text == 'yes' || text == 'да';
  }

  static String? _emptyToNull(String value) {
    final v = value.trim();
    if (v.isEmpty || v == 'null') return null;
    return v;
  }

  static bool _isFresh(String raw, {required int maxAgeSeconds}) {
    final text = raw.trim();
    if (text.isEmpty) return true;
    DateTime? dt = DateTime.tryParse(text);
    dt ??= DateTime.tryParse(text.replaceFirst(' ', 'T'));
    if (dt == null) return true;
    final diff = DateTime.now().difference(dt);
    if (diff.isNegative) return true;
    return diff.inSeconds <= maxAgeSeconds;
  }

  static String _timeLabel(String raw) {
    final text = raw.trim();
    if (text.length >= 19) return text.substring(11, 19);
    if (text.length >= 8) return text.substring(text.length - 8);
    return 'только что';
  }
}

class _RemoteConnectedTrackersStrip extends StatelessWidget {
  const _RemoteConnectedTrackersStrip(
      {required this.items, required this.onRefresh});

  final List<_RemoteTrackerPresence> items;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _TD.greenSoft,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _TD.greenBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.cloud_done_rounded, color: _TD.green, size: 18),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              'Удалённо подключены: ${items.length}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: _TD.text, fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
          _NoHoverTap(
            onTap: onRefresh,
            borderRadius: BorderRadius.circular(6),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              child: Text('обновить',
                  style: TextStyle(
                      color: _TD.green,
                      fontWeight: FontWeight.w700,
                      fontSize: 11.2)),
            ),
          ),
        ]),
        const SizedBox(height: 4),
        ...items.take(4).map((item) {
          final details = <String>[
            item.uuid,
            if (item.rssi != null) 'RSSI ${item.rssi}',
            if (item.playerName != null) item.playerName!,
            if (item.fieldTitle != null) item.fieldTitle!,
            item.liveRunning ? 'Live идёт' : 'Live нет',
            item.hasFreshGps ? 'GPS OK' : 'GPS нет',
            item.createdAtLabel,
          ];
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(.72),
                borderRadius: BorderRadius.circular(6)),
            child: Row(children: [
              Icon(
                  item.liveRunning
                      ? Icons.sensors_rounded
                      : Icons.bluetooth_connected_rounded,
                  color: item.liveRunning ? _TD.green : _TD.orange,
                  size: 17),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: _TD.text,
                              fontWeight: FontWeight.w700,
                              fontSize: 11.5)),
                      const SizedBox(height: 2),
                      Text(details.join(' · '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: _TD.muted,
                              fontWeight: FontWeight.w600,
                              fontSize: 11.0)),
                    ]),
              ),
              const SizedBox(width: 4),
              Text('занят',
                  style: TextStyle(
                      color: item.liveRunning ? _TD.green : _TD.orange,
                      fontWeight: FontWeight.w700,
                      fontSize: 11.2)),
            ]),
          );
        }),
      ]),
    );
  }
}

class _CalibrationStatusBanner extends StatelessWidget {
  const _CalibrationStatusBanner({
    required this.nextLabel,
    required this.done,
    required this.pointCount,
    this.saved = false,
  });

  final String nextLabel;
  final bool done;
  final int pointCount;
  final bool saved;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: done
            ? _TD.green.withOpacity(.10)
            : const Color(0xFF2563EB).withOpacity(.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(done ? Icons.check_circle_rounded : Icons.gps_fixed_rounded,
              color: done ? _TD.green : const Color(0xFF2563EB)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              saved
                  ? 'Поле уже сохранено. Координаты A/B/C/D показаны ниже.'
                  : (done
                      ? 'Все 4 угла получены. Нажмите «Сохранить».'
                      : 'Следующий угол: $nextLabel · перейдите в угол поля и нажмите GPS $nextLabel'),
              style: TextStyle(
                color: done ? _TD.green : _TD.text,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ),
          Text('$pointCount/4',
              style: const TextStyle(
                  color: _TD.muted, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _DarkHeatmapPainter extends CustomPainter {
  const _DarkHeatmapPainter({required this.points});
  final List<TrackerHeatPoint> points;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = _TD.card2);
    final pitch = _fitPitch(rect.deflate(18));
    _drawPitch(canvas, pitch);
    if (points.isEmpty) {
      _drawText(canvas, size, 'Нет данных теплокарты');
      return;
    }
    final maxValue = points.fold<double>(1, (m, p) => math.max(m, p.value));
    for (final p in points) {
      final x = pitch.left + (p.x.clamp(0, 105) / 105.0) * pitch.width;
      final y = pitch.top + (p.y.clamp(0, 68) / 68.0) * pitch.height;
      final ratio = (p.value / maxValue).clamp(0.0, 1.0);
      final radius = 18 + 42 * ratio;
      final color = ratio > .7
          ? _TD.red
          : ratio > .4
              ? _TD.orange
              : _TD.green;
      canvas.drawCircle(
          Offset(x, y),
          radius,
          Paint()
            ..shader = RadialGradient(colors: [
              color.withOpacity(.38),
              color.withOpacity(.08),
              Colors.transparent
            ]).createShader(
                Rect.fromCircle(center: Offset(x, y), radius: radius)));
    }
  }

  Rect _fitPitch(Rect area) {
    const aspect = 105 / 68;
    var w = area.width;
    var h = w / aspect;
    if (h > area.height) {
      h = area.height;
      w = h * aspect;
    }
    return Rect.fromCenter(center: area.center, width: w, height: h);
  }

  void _drawPitch(Canvas canvas, Rect pitch) {
    canvas.drawRRect(RRect.fromRectAndRadius(pitch, const Radius.circular(8)),
        Paint()..color = const Color(0xFF0A7F39));
    for (var i = 0; i < 12; i++) {
      canvas.drawRect(
          Rect.fromLTWH(pitch.left + pitch.width * i / 12, pitch.top,
              pitch.width / 12, pitch.height),
          Paint()
            ..color = i.isEven
                ? Colors.white.withOpacity(.04)
                : Colors.black.withOpacity(.05));
    }
    final inner = pitch.deflate(12);
    final line = Paint()
      ..color = Colors.white.withOpacity(.85)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawRect(inner, line);
    canvas.drawLine(Offset(inner.center.dx, inner.top),
        Offset(inner.center.dx, inner.bottom), line);
    canvas.drawCircle(inner.center, inner.width * .085, line);
    canvas.drawRect(
        Rect.fromLTWH(inner.left, inner.center.dy - inner.height * .22,
            inner.width * .16, inner.height * .44),
        line);
    canvas.drawRect(
        Rect.fromLTWH(
            inner.right - inner.width * .16,
            inner.center.dy - inner.height * .22,
            inner.width * .16,
            inner.height * .44),
        line);
  }

  void _drawText(Canvas canvas, Size size, String text) {
    final tp = TextPainter(
        text: TextSpan(
            text: text,
            style: const TextStyle(
                color: _TD.muted, fontSize: 11.2, fontWeight: FontWeight.w700)),
        textDirection: TextDirection.ltr)
      ..layout(maxWidth: size.width - 40);
    tp.paint(canvas,
        Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2));
  }

  @override
  bool shouldRepaint(covariant _DarkHeatmapPainter oldDelegate) => true;
}

class _DarkCalibrationPainter extends CustomPainter {
  const _DarkCalibrationPainter(
      {required this.corners, this.activeIndex = -1, this.capturing = false});

  final List<ActionTrackerGpsPoint> corners;
  final int activeIndex;
  final bool capturing;

  @override
  void paint(Canvas canvas, Size size) {
    final area = (Offset.zero & size).deflate(18);
    const aspect = 105 / 68;
    var w = area.width;
    var h = w / aspect;
    if (h > area.height) {
      h = area.height;
      w = h * aspect;
    }
    final pitch = Rect.fromCenter(center: area.center, width: w, height: h);
    _DarkHeatmapPainter(points: const [])._drawPitch(canvas, pitch);

    final cornersPos = [
      pitch.topLeft + const Offset(18, 18),
      pitch.topRight + const Offset(-18, 18),
      pitch.bottomRight + const Offset(-18, -18),
      pitch.bottomLeft + const Offset(18, -18),
    ];

    for (var i = 0; i < 4; i++) {
      final ready = corners.length > i;
      final active = i == activeIndex;
      final p = cornersPos[i];
      final color = ready
          ? _TD.green
          : active
              ? const Color(0xFF2563EB)
              : _TD.dim;
      if (active) {
        canvas.drawCircle(
            p, capturing ? 30 : 25, Paint()..color = color.withOpacity(.13));
        canvas.drawCircle(
            p, capturing ? 23 : 20, Paint()..color = color.withOpacity(.24));
      }
      canvas.drawCircle(p, active ? 18 : 16, Paint()..color = color);
      if (ready) {
        final check = TextPainter(
          text: const TextSpan(
              text: '✓',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5)),
          textDirection: TextDirection.ltr,
        )..layout();
        check.paint(canvas, p - Offset(check.width / 2, check.height / 2));
      } else if (active) {
        final plus = TextPainter(
          text: const TextSpan(
              text: '+',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 20)),
          textDirection: TextDirection.ltr,
        )..layout();
        plus.paint(canvas, p - Offset(plus.width / 2, plus.height / 2 + 1));
      } else {
        final tp = TextPainter(
          text: TextSpan(
              text: ['A', 'B', 'C', 'D'][i],
              style:
                  const TextStyle(color: _TD.bg, fontWeight: FontWeight.w700)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DarkCalibrationPainter oldDelegate) => true;
}

class _DarkTimelinePainter extends CustomPainter {
  const _DarkTimelinePainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _TD.card2);
    final y = size.height * .5;
    canvas.drawLine(
        Offset(30, y),
        Offset(size.width - 30, y),
        Paint()
          ..color = _TD.border
          ..strokeWidth = 2);
    for (var i = 0; i <= 8; i++) {
      final x = 30 + (size.width - 60) * i / 8;
      canvas.drawCircle(
          Offset(x, y), 5, Paint()..color = i.isEven ? _TD.green : _TD.orange);
      final tp = TextPainter(
          text: TextSpan(
              text: '${i * 15}’',
              style: const TextStyle(
                  color: _TD.muted,
                  fontSize: 10.4,
                  fontWeight: FontWeight.w600)),
          textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, y + 14));
    }
  }

  @override
  bool shouldRepaint(covariant _DarkTimelinePainter oldDelegate) => false;
}

class _SheetCloseButton extends StatelessWidget {
  const _SheetCloseButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _NoHoverTap(
      onTap: onTap,
      child: const SizedBox(
        width: 40,
        height: 40,
        child: Center(
            child: Icon(Icons.close_rounded, color: _TD.muted, size: 22)),
      ),
    );
  }
}

class _TinyIconAction extends StatelessWidget {
  const _TinyIconAction({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return _NoHoverTap(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 16, color: _TD.muted),
      ),
    );
  }
}

class _NoHoverTap extends StatelessWidget {
  const _NoHoverTap({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.borderRadius,
    this.hoverColor,
    this.splashColor,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final BorderRadiusGeometry? borderRadius;
  final Color? hoverColor;
  final Color? splashColor;

  void _runAfterPointerSettled(BuildContext context, VoidCallback? callback) {
    if (callback == null) return;
    // Важно: не меняем focus/layout синхронно внутри pointer/mouse update.
    // На мобильной web-раскладке Flutter тоже держит MouseTracker, и если в этот
    // момент закрыть/перестроить вкладку, появляется assertion
    // mouse_tracker.dart: !_debugDuringDeviceUpdate.
    Timer(const Duration(milliseconds: 90), () async {
      if (!context.mounted) return;
      await WidgetsBinding.instance.endOfFrame;
      if (!context.mounted) return;
      await Future<void>.delayed(Duration.zero);
      if (!context.mounted) return;
      FocusManager.instance.primaryFocus?.unfocus();
      await WidgetsBinding.instance.endOfFrame;
      if (!context.mounted) return;
      callback();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap:
          onTap == null ? null : () => _runAfterPointerSettled(context, onTap),
      onLongPress: onLongPress == null
          ? null
          : () => _runAfterPointerSettled(context, onLongPress),
      child: child,
    );
  }
}
