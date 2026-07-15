
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models/action_tracker_protocol.dart';
import 'models/tracker_live_models.dart';
import 'models/tracker_pro_models.dart';
import 'services/action_tracker_ble_service.dart';
import 'services/polar_heart_rate_ble_service.dart';
import 'services/tracker_live_api.dart';


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


enum TrackerLiveSourceMode {
trackerExperimental,
heartRateOnly,
}

enum TrackerTrainingActivity {
  footballField,
  outdoorRun,
  indoorStrength,
}

enum _LiveSessionExitAction { stay, pause, exitWithoutSaving, stopAndSave }
enum _LiveMobileSheetTab { team, players, field, operator }

extension TrackerTrainingActivityUi on TrackerTrainingActivity {
  String get code {
    switch (this) {
      case TrackerTrainingActivity.footballField:
        return 'football_field';
      case TrackerTrainingActivity.outdoorRun:
        return 'outdoor_run';
      case TrackerTrainingActivity.indoorStrength:
        return 'indoor_strength';
    }
  }

  String get title {
    switch (this) {
      case TrackerTrainingActivity.footballField:
        return 'Футбол / поле';
      case TrackerTrainingActivity.outdoorRun:
        return 'Кросс / улица';
      case TrackerTrainingActivity.indoorStrength:
        return 'Зал / силовая';
    }
  }

  String get shortTitle {
    switch (this) {
      case TrackerTrainingActivity.footballField:
        return 'Поле';
      case TrackerTrainingActivity.outdoorRun:
        return 'Кросс';
      case TrackerTrainingActivity.indoorStrength:
        return 'Зал';
    }
  }

  String get subtitle {
    switch (this) {
      case TrackerTrainingActivity.footballField:
        return 'карта поля, тепловая карта, зоны и координаты';
      case TrackerTrainingActivity.outdoorRun:
        return 'маршрут, дистанция, темп, скорость без калибровки поля';
      case TrackerTrainingActivity.indoorStrength:
        return 'таймер, нагрузка и заметки; GPS в помещении не обязателен';
    }
  }

  bool get requiresField => this == TrackerTrainingActivity.footballField;

  IconData get icon {
    switch (this) {
      case TrackerTrainingActivity.footballField:
        return Icons.sports_soccer_rounded;
      case TrackerTrainingActivity.outdoorRun:
        return Icons.directions_run_rounded;
      case TrackerTrainingActivity.indoorStrength:
        return Icons.fitness_center_rounded;
    }
  }
}

class TrackerLivePanel extends StatefulWidget {
const TrackerLivePanel({
super.key,
required this.clubId,
required this.teamId,
required this.teamName,
required this.players,
required this.selectedPlayer,
required this.selectedField,
required this.ble,
this.savedDevices = const [],
this.heartRateByPlayerId = const <int, HeartRateSample>{},
this.heartRateConnectedCount = 0,
this.batteryPercent,
this.scanningBluetooth = false,
this.onScanBluetooth,
this.onManageTrackers,
this.onSelectPlayer,
this.onLiveRunningChanged,
this.onLiveSessionIdChanged,
this.startRequestSignal = 0,
this.pauseRequestSignal = 0,
this.stopRequestSignal = 0,
this.exitWithoutSaveRequestSignal = 0,
});

final int clubId;
final int teamId;
final String teamName;
final List<TrackerPlayerOption> players;
final TrackerPlayerOption? selectedPlayer;
final TrackerFieldModel? selectedField;
final ActionTrackerBleService ble;
final List<TrackerDeviceModel> savedDevices;
final Map<int, HeartRateSample> heartRateByPlayerId;
final int heartRateConnectedCount;
final int? batteryPercent;
final bool scanningBluetooth;
final VoidCallback? onScanBluetooth;
final VoidCallback? onManageTrackers;
final ValueChanged<TrackerPlayerOption>? onSelectPlayer;
final ValueChanged<bool>? onLiveRunningChanged;
final ValueChanged<int?>? onLiveSessionIdChanged;
final int startRequestSignal;
final int pauseRequestSignal;
final int stopRequestSignal;
final int exitWithoutSaveRequestSignal;

@override
State<TrackerLivePanel> createState() => _TrackerLivePanelState();
}

class _TrackerLivePanelState extends State<TrackerLivePanel>
with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
static const int _maxMonitorPlayers = 12;
static const int _monitorPlayersPerPageWide = 8;
final TrackerLiveApi _api = TrackerLiveApi();

final List<String> _logs = <String>[];
final Map<String, _RuntimeTrack> _tracks = <String, _RuntimeTrack>{};
List<TrackerLiveSessionModel> _sessions = <TrackerLiveSessionModel>[];

Timer? _pollTimer;
Timer? _phoneTimer;
Timer? _trackerTimer;
Timer? _heartbeatTimer;
StreamSubscription<ActionTrackerParseResult>? _bleSub;
StreamSubscription<String>? _bleLogSub;

int? _myLiveSessionId;
TrackerLiveSourceMode _mode = TrackerLiveSourceMode.trackerExperimental;
TrackerTrainingActivity _activity = TrackerTrainingActivity.footballField;
int _candidateCommandIndex = 0;

bool _starting = false;
bool _savingPoint = false;
bool _running = false;
bool _paused = false;
int _handledStartRequestSignal = 0;
int _handledPauseRequestSignal = 0;
int _handledStopRequestSignal = 0;
int _handledExitWithoutSaveRequestSignal = 0;
bool _testingCommands = false;
bool _trackerTxInFlight = false;
bool _liveStateRequestInFlight = false;
int _liveStateTimeouts = 0;
bool _showDebug = false;
bool _showTrace = true;
bool _showVectors = true;
bool _showHeatmap = true;
bool _showLabels = true;
  bool _bottomOperatorExpanded = false;
String? _floatingLiveTitle;
IconData _floatingLiveIcon = Icons.open_in_full_rounded;
Widget Function()? _floatingLiveBuilder;
bool _floatingLiveMinimized = false;
bool _floatingLiveMaximized = false;
Offset? _floatingLiveOffset;
bool _renderingFloatingLiveContent = false;
bool _phoneLiveSheetVisible = false;
// Когда тренер просто открывает карточку игрока/анализ, не поднимаем старую server Live-сессию автоматически.
// Live должен становиться активным только после явного Старт или внешнего startRequestSignal.
bool _blockServerAutoRestoreAfterPlayerPick = false;
final List<_TeamLoadSample> _teamLoadHistory = <_TeamLoadSample>[];
final Set<int> _monitorPlayerIds = <int>{};
final Set<int> _monitorMapPlayerIds = <int>{};
bool _monitorManualSelectionTouched = false;
bool _teamFieldPanelExpanded = false;
String _liveSidePanelMode = 'map'; // map / hr / sprint / signal
bool _showLoadHotPoints = true;
final Map<int, List<_LiveHrPoint>> _liveHrHistoryByPlayer = <int, List<_LiveHrPoint>>{};

String _lastRx = 'нет пакетов';
String _lastTx = 'нет команд';
String _lastGps = 'нет GPS';
String _lastSave = 'нет сохранения';
String _lastStop = 'нет остановки';
String _lastPayload = 'нет payload';
String _lastServer = 'нет ответа';
String _lastLiveState = 'не загружено';
String _lastLocalMetrics = 'нет локальных метрик';
String _lastZeroReason = 'ожидаем GPS';
String _lastProblem = 'Ожидание старта Live';
DateTime? _lastGpsAt;
DateTime? _lastSaveAt;
DateTime? _lastRemoteLiveRxLogAt;
DateTime? _startedAt;
DateTime? _lastTrackerTxAt;
DateTime? _lastBatteryKeepAliveAt;
DateTime? _lastGpsProbeAt;
DateTime? _bleOfflineSince;
DateTime? _nextBleReconnectAttemptAt;
DateTime? _lastBleOfflineLogAt;
DateTime? _lastPostReconnectSyncAt;
String _offlineRecorderStatus = 'запись на трекере не проверялась';
int _gpsMissesForCandidate = 0;
int? _lastGpsCandidateWithFix;
String _lastRemoteDebug = 'debug ещё не отправлялся';

final List<_LivePeriod> _periods = <_LivePeriod>[];

@override
bool get wantKeepAlive => true;

@override
void initState() {
super.initState();
WidgetsBinding.instance.addObserver(this);
_listenBle();
_startPolling();
if (widget.startRequestSignal > 0) {
  _handledStartRequestSignal = widget.startRequestSignal;
  Future.microtask(_handleExternalStartLiveRequest);
}
}

@override
void dispose() {
final liveId = _myLiveSessionId;
if (_running && liveId != null) {
  // v81: dispose больше не останавливает Live автоматически.
  // Виджет может пересоздаться из-за смены вкладки/размера окна/ключа, и раньше это
  // закрывало тренировку примерно через 30 минут или при перестроении экрана.
  // Закрытие/сохранение теперь делается только явной кнопкой Стоп или диалогом выхода.
  unawaited(_api.heartbeatLiveSession(liveSessionId: liveId, statusText: 'widget_dispose_keep_alive').catchError((_) => <String, dynamic>{}));
  unawaited(_saveMetricSnapshot(manual: false));
  widget.onLiveRunningChanged?.call(true);
  widget.onLiveSessionIdChanged?.call(liveId);
} else {
  widget.onLiveRunningChanged?.call(false);
  widget.onLiveSessionIdChanged?.call(null);
}
WidgetsBinding.instance.removeObserver(this);
_pollTimer?.cancel();
_phoneTimer?.cancel();
_trackerTimer?.cancel();
_heartbeatTimer?.cancel();
_bleSub?.cancel();
_bleLogSub?.cancel();
super.dispose();
}


@override
void didChangeAppLifecycleState(AppLifecycleState state) {
  super.didChangeAppLifecycleState(state);
  final liveId = _myLiveSessionId;
  if (!_running || liveId == null) return;

  // v80: страховка от случайного выхода/сворачивания приложения.
  // На pause/inactive не останавливаем Live, чтобы запись могла продолжиться,
  // но отправляем heartbeat и локальный snapshot метрик на сервер.
  if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
    unawaited(_api.heartbeatLiveSession(liveSessionId: liveId, statusText: 'app_${state.name}_autosave').catchError((_) {}));
    unawaited(_saveMetricSnapshot(manual: false));
    _log('APP ${state.name}: Live #$liveId не остановлен, отправлен heartbeat/snapshot');
    return;
  }

  // Если приложение реально уничтожают, успеваем best-effort сохранить финальную сессию.
  if (state == AppLifecycleState.detached) {
    unawaited(_autoSaveLiveAfterParentDecision());
  }
}

@override
void didUpdateWidget(covariant TrackerLivePanel oldWidget) {
super.didUpdateWidget(oldWidget);
_captureHeartRateSamples();

if (oldWidget.startRequestSignal != widget.startRequestSignal &&
    widget.startRequestSignal != _handledStartRequestSignal) {
  _handledStartRequestSignal = widget.startRequestSignal;
  Future.microtask(_handleExternalStartLiveRequest);
}

if (oldWidget.pauseRequestSignal != widget.pauseRequestSignal &&
    widget.pauseRequestSignal != _handledPauseRequestSignal) {
  _handledPauseRequestSignal = widget.pauseRequestSignal;
  Future.microtask(_pauseLiveCollection);
}
if (oldWidget.stopRequestSignal != widget.stopRequestSignal &&
    widget.stopRequestSignal != _handledStopRequestSignal) {
  _handledStopRequestSignal = widget.stopRequestSignal;
  Future.microtask(_autoSaveLiveAfterParentDecision);
}
if (oldWidget.exitWithoutSaveRequestSignal != widget.exitWithoutSaveRequestSignal &&
    widget.exitWithoutSaveRequestSignal != _handledExitWithoutSaveRequestSignal) {
  _handledExitWithoutSaveRequestSignal = widget.exitWithoutSaveRequestSignal;
  Future.microtask(_autoSaveLiveAfterParentDecision);
}

if (oldWidget.teamId != widget.teamId || oldWidget.clubId != widget.clubId) {
  _phoneTimer?.cancel();
  _trackerTimer?.cancel();
  _heartbeatTimer?.cancel();
  _setLiveRunning(false);
  _paused = false;

  setState(() {
    _sessions = <TrackerLiveSessionModel>[];
    _tracks.clear();
    _teamLoadHistory.clear();
    _myLiveSessionId = null;
    _lastProblem = 'Команда изменена: ${widget.teamName}';
    _lastRx = 'нет пакетов';
    _lastTx = 'нет команд';
    _lastGps = 'нет GPS';
    _lastSave = 'нет сохранения';
    _lastStop = 'нет остановки';
    _lastPayload = 'нет payload';
    _lastServer = 'нет ответа';
    _lastLiveState = 'не загружено';
    _lastLocalMetrics = 'нет локальных метрик';
    _lastZeroReason = 'ожидаем GPS';
  });

  _loadLiveState();
  _log('Команда Live изменена: ${widget.teamName} (${widget.teamId})');
  return;
}

if (oldWidget.selectedField?.id != widget.selectedField?.id) {
  _loadLiveState();
  _log('Изменено поле: ${widget.selectedField?.title ?? 'нет поля'}');
}

if (oldWidget.selectedPlayer?.id != widget.selectedPlayer?.id) {
  _log('Изменён игрок Live: ${widget.selectedPlayer?.name ?? 'не выбран'}');
  if (_running) {
    _lastProblem = 'Live уже запущен. Чтобы перепривязать трекер к другому игроку, сначала остановите и сохраните текущую сессию.';
    setState(() {});
  } else {
    setState(() {
      _tracks.clear();
      _sessions = <TrackerLiveSessionModel>[];
      _teamLoadHistory.clear();
      _myLiveSessionId = null;
      _blockServerAutoRestoreAfterPlayerPick = true;
      _lastLocalMetrics = 'игрок изменён — локальный трек очищен';
      _lastProblem = 'Выбран ${widget.selectedPlayer?.name ?? 'новый игрок'}. Live не запущен — нажмите Старт вручную.';
    });
    Future.microtask(() => _loadLiveState(restoreRunning: false));
  }
}
}

Future<void> _handleExternalStartLiveRequest() async {
_blockServerAutoRestoreAfterPlayerPick = false;
_log('LIVE LINK: внешний запуск Live из аналитики / signal=${widget.startRequestSignal}');
if (_paused) {
  _resumeLiveCollection();
  return;
}
if (_running || _starting) {
  _lastProblem = 'Live уже активен: аналитика подключена к текущей сессии.';
  if (mounted) setState(() {});
  return;
}
await _startLive();
}

void _setLiveRunning(bool value) {
if (_running == value) return;
_running = value;
if (value) {
  _startedAt ??= DateTime.now();
} else {
  _startedAt = null;
  _paused = false;
}
widget.onLiveRunningChanged?.call(value);
}

void _listenBle() {
_bleLogSub?.cancel();
_bleLogSub = widget.ble.logStream.listen((line) {
  _log('BLE $line');
  if (mounted) setState(() {});
});

_bleSub = widget.ble.dataStream.listen((event) async {
  final typeHex = '0x${event.packetType.toRadixString(16).toUpperCase()}';
  _lastRx = '${event.rawHex} · $typeHex';

  final rxNow = DateTime.now();
  final shouldRemoteRx = _running &&
      (_lastRemoteLiveRxLogAt == null || rxNow.difference(_lastRemoteLiveRxLogAt!).inSeconds >= 5);
  if (shouldRemoteRx) {
    _lastRemoteLiveRxLogAt = rxNow;
    unawaited(_serverLog(
      'Live RX: $_lastRx · running=$_running paused=$_paused mode=${_mode.name}',
      source: 'live_rx',
      rawHex: event.rawHex,
    ));
  }

  if (_mode == TrackerLiveSourceMode.trackerExperimental) {
    _log('RX $_lastRx');
  }

  if (event.records.isNotEmpty) {
    _offlineRecorderStatus = _formatRecorderStatus(event.records);
    _log('Записи на трекере: $_offlineRecorderStatus');
  }

  if (event.transferFinished || event.gpsChunk?.finished == true) {
    _offlineRecorderStatus = 'загрузка офлайн-записи завершена';
    _log(_offlineRecorderStatus);
  }

  if (!_running || _mode != TrackerLiveSourceMode.trackerExperimental) {
    if (mounted) setState(() {});
    return;
  }

  if (event.battery != null) {
    _log(
      'Батарея/GPS: ${event.battery!.voltage.toStringAsFixed(2)} В · '
      'GPS ${event.battery!.gpsReady ? 'готов' : 'не готов'} · это не координата',
    );
  }

  final chunk = event.gpsChunk;
  if (chunk == null || chunk.points.isEmpty) {
    final zeroGps = event.rawHex.contains('3B 00 00 00 00 00 00 00 00') ||
        event.rawHex.contains('44 00 00 00 00 00 00 00');
    _lastProblem = zeroGps
        ? 'Трекер отвечает нулевой GPS-точкой 0,0. Это не ошибка UI: нет актуальной координаты. Выйдите на улицу, дождитесь спутников или включите запись на трекере.'
        : 'Пакет $typeHex получен, но координат в нём нет';
    _lastGps = zeroGps ? '0.000000, 0.000000 · $typeHex · нет фиксации' : _lastGps;
    await _serverLog(
      _lastProblem,
      level: zeroGps ? 'warning' : 'info',
      source: zeroGps ? 'live_rx_zero_gps' : 'live_rx_no_points',
      rawHex: event.rawHex,
    );
    if (mounted) setState(() {});
    return;
  }

  final point = chunk.points.last;
  final nowMs = DateTime.now().millisecondsSinceEpoch;

  _lastGpsAt = DateTime.now();
  _lastGps =
      '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)} · $typeHex';
  _gpsMissesForCandidate = 0;
  _lastGpsProbeAt = null;
  _lastGpsCandidateWithFix = _candidateCommandIndex;

  _log('GPS трекера: $_lastGps · working_command_index=${_candidateCommandIndex + 1}');

  await _handleGpsPoint(
    latitude: point.latitude,
    longitude: point.longitude,
    timeMs: nowMs,
    packetType: typeHex,
    rawHex: event.rawHex,
  );
});
}

void _startPolling() {
_log('Live открыт. Команда Live GPS: 3A → ответ 3B/44.');
_loadLiveState();
_pollTimer?.cancel();
_pollTimer = Timer.periodic(
  const Duration(seconds: 3),
  (_) => _loadLiveState(restoreRunning: !_blockServerAutoRestoreAfterPlayerPick),
);
}

Future<void> _loadLiveState({bool restoreRunning = true}) async {
// Не запускаем новый HTTP-запрос, пока предыдущий ещё выполняется.
// Раньше polling каждые 3 секунды создавал несколько параллельных запросов,
// а зависший PHP отвечал TimeoutException спустя 20 секунд.
if (_liveStateRequestInFlight) return;
_liveStateRequestInFlight = true;
try {
  final data = await _api.loadTeamLiveState(
    teamId: widget.teamId,
    fieldId: _activity.requiresField ? widget.selectedField?.id : null,
  );
  if (!mounted) return;

  final activeCount = data.where((s) => s.status == 'active' || s.status == 'online' || s.status == 'live').length;
  _lastLiveState = data.isEmpty
      ? 'sessions=0 active=0 · сервер ничего не вернул'
      : 'sessions=${data.length} active=$activeCount · ${_debugSessionLine(data.first)}';

  final nextSessions = _mergeLiveSessionsKeepRunning(data);
  if (restoreRunning && !_blockServerAutoRestoreAfterPlayerPick) {
    _restoreRunningLiveIfNeeded(nextSessions);
  }
  setState(() {
    _sessions = nextSessions;
    _recordTeamLoadSnapshot();
  });
  _liveStateTimeouts = 0;
  await _loadLivePeriods();
} on TimeoutException catch (e) {
  _liveStateTimeouts += 1;
  _lastLiveState = 'таймаут сервера ($_liveStateTimeouts)';
  // Не затираем рабочий Live и не показываем это как фатальную ошибку.
  // Следующий polling сам попробует снова.
  if (_liveStateTimeouts == 1 || _liveStateTimeouts % 5 == 0) {
    _log('Live API временно не ответил: $e');
  }
} catch (e) {
  _lastLiveState = 'ОШИБКА load_state: $e';
  _lastProblem = 'Ошибка загрузки Live: $e';
  _log(_lastProblem);
} finally {
  _liveStateRequestInFlight = false;
}
}

bool _isActiveLiveStatus(String status) {
  final normalized = status.trim().toLowerCase();
  return normalized == 'active' || normalized == 'online' || normalized == 'live';
}

String _liveSessionMergeKey(TrackerLiveSessionModel session) {
  if (session.id > 0) return 'id:${session.id}';
  final playerId = _resolvedPlayerIdForSession(session) ?? session.playerId;
  if (playerId != null && playerId > 0) return 'player:$playerId';
  final uuid = session.deviceUuid.trim().toLowerCase();
  if (uuid.isNotEmpty) return 'device:$uuid';
  return 'row:${session.deviceName.trim().toLowerCase()}';
}

double _liveSessionDataScore(TrackerLiveSessionModel session) {
  return session.totalDistanceM +
      session.maxSpeedKmh * 10 +
      session.speedKmh * 5 +
      session.loadScore +
      session.durationSec / 10 +
      session.sprintDistanceM +
      session.hirDistanceM +
      session.vhirDistanceM;
}

TrackerLiveSessionModel _bestLiveSessionSnapshot(TrackerLiveSessionModel current, TrackerLiveSessionModel incoming) {
  final incomingActive = _isActiveLiveStatus(incoming.status);
  final currentActive = _isActiveLiveStatus(current.status);
  if (!incomingActive && currentActive && _running) return current;

  final incomingScore = _liveSessionDataScore(incoming);
  final currentScore = _liveSessionDataScore(current);
  if (incomingScore <= 0 && currentScore > 0 && _running) return current;
  if (incoming.durationSec <= 0 && current.durationSec > 0 && _running) return current;
  return incomingScore >= currentScore || incoming.isOnline ? incoming : current;
}

List<TrackerLiveSessionModel> _mergeLiveSessionsKeepRunning(List<TrackerLiveSessionModel> incoming) {
  if (!_running || _sessions.isEmpty) return incoming;
  if (incoming.isEmpty) {
    _lastLiveState = 'server returned 0, keep ${_sessions.length} active live rows until Stop';
    return List<TrackerLiveSessionModel>.from(_sessions);
  }

  final merged = <String, TrackerLiveSessionModel>{};
  for (final session in _sessions) {
    if (_isActiveLiveStatus(session.status)) merged[_liveSessionMergeKey(session)] = session;
  }
  for (final session in incoming) {
    final key = _liveSessionMergeKey(session);
    final current = merged[key];
    merged[key] = current == null ? session : _bestLiveSessionSnapshot(current, session);
  }

  final ordered = merged.values.toList(growable: false);
  ordered.sort((a, b) {
    final aOnline = a.isOnline ? 1 : 0;
    final bOnline = b.isOnline ? 1 : 0;
    if (aOnline != bOnline) return bOnline.compareTo(aOnline);
    return _liveSessionDataScore(b).compareTo(_liveSessionDataScore(a));
  });
  return ordered;
}

void _restoreRunningLiveIfNeeded(List<TrackerLiveSessionModel> sessions) {
  if (_blockServerAutoRestoreAfterPlayerPick) return;
  if (_running || _starting || _myLiveSessionId != null) return;
  final selectedId = widget.selectedPlayer?.id;
  if (selectedId == null || selectedId <= 0) return;

  TrackerLiveSessionModel? active;
  for (final session in sessions) {
    if (!_isActiveLiveStatus(session.status)) continue;
    final playerId = _resolvedPlayerIdForSession(session) ?? session.playerId;
    if (playerId == selectedId) {
      active = session;
      break;
    }
  }
  if (active == null || active.id <= 0) return;

  _myLiveSessionId = active.id;
  _startedAt = DateTime.now().subtract(Duration(seconds: math.max(0, active.durationSec)));
  widget.onLiveSessionIdChanged?.call(active.id);
  _setLiveRunning(true);
  _lastProblem = 'Live-сессия #${active.id} восстановлена: запись продолжается до явной кнопки Стоп.';
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted || !_running || _myLiveSessionId != active?.id) return;
    if (_effectiveStartMode() == TrackerLiveSourceMode.heartRateOnly) {
      _startHeartRateOnlyLoop();
    } else {
      _startTrackerLoop();
    }
  });
}

Future<void> _loadLivePeriods() async {
final id = _myLiveSessionId;
if (id == null || id <= 0) return;
try {
  final serverPeriods = await _api.loadLivePeriods(liveSessionId: id);
  if (!mounted || serverPeriods.isEmpty) return;
  setState(() {
    _periods
      ..clear()
      ..addAll(serverPeriods.map(_LivePeriod.fromJson));
  });
} catch (e) {
  _log('Periods load skipped: $e');
}
}


String _liveSourceTitle(TrackerLiveSourceMode mode) {
  switch (mode) {
    case TrackerLiveSourceMode.trackerExperimental:
      return 'GPS-трекер';
    case TrackerLiveSourceMode.heartRateOnly:
      return 'Polar H10 команда';
  }
}

IconData _liveSourceIcon(TrackerLiveSourceMode mode) {
  switch (mode) {
    case TrackerLiveSourceMode.trackerExperimental:
      return Icons.sensors_rounded;
    case TrackerLiveSourceMode.heartRateOnly:
      return Icons.monitor_heart_rounded;
  }
}

bool get _hasTeamHeartRateOnline => widget.heartRateByPlayerId.values.any((sample) => DateTime.now().difference(sample.measuredAt).inSeconds <= 25);

TrackerLiveSourceMode _effectiveStartMode() {
  if (_mode != TrackerLiveSourceMode.trackerExperimental) return _mode;
  final hasTracker = widget.ble.commandChannelReady || widget.ble.connectedInfo != null;
  if (!hasTracker && (widget.heartRateByPlayerId.isNotEmpty || widget.heartRateConnectedCount > 0)) return TrackerLiveSourceMode.heartRateOnly;
  return _mode;
}

Future<void> _startLive() async {
_blockServerAutoRestoreAfterPlayerPick = false;
if (_running && _paused) {
  _resumeLiveCollection();
  return;
}

final field = widget.selectedField;
final beforeDevice = widget.ble.connectedInfo;
final beforeLastKnown = widget.ble.lastKnownInfo;
final beforeChannel = widget.ble.commandChannelReady;
int? startedSessionId;

_log('START CHECK #1: running=$_running paused=$_paused starting=$_starting mode=${_mode.name} activity=${_activity.code} '
    'field=${field?.id}/${field?.hasCalibration} channel=$beforeChannel '
    'device=${beforeDevice?.name}/${beforeDevice?.id} lastKnown=${beforeLastKnown?.name}/${beforeLastKnown?.id}');
unawaited(_serverLog(
  'START CHECK #1: running=$_running paused=$_paused starting=$_starting mode=${_mode.name} activity=${_activity.code} '
  'field=${field?.id}/${field?.hasCalibration} channel=$beforeChannel '
  'device=${beforeDevice?.name}/${beforeDevice?.id} lastKnown=${beforeLastKnown?.name}/${beforeLastKnown?.id}',
  source: 'live_start_check_1',
));

final fieldMissing = _activity.requiresField && (field == null || !field.hasCalibration);
final effectiveField = fieldMissing ? null : field;
if (fieldMissing) {
  _toast('Поле не откалибровано. Live запущу без проекции на карту: GPS/скорость/нагрузка будут сохраняться, поле можно откалибровать позже.');
  _lastProblem = 'START WARNING: нет калибровки поля для режима «${_activity.title}». Стартую без field_id, чтобы не терять тренировку.';
  _log(_lastProblem);
  unawaited(_serverLog(_lastProblem, level: 'warning', source: 'live_start_no_field_fallback'));
  if (mounted) setState(() {});
}

setState(() {
  _starting = true;
  _lastProblem = 'Проверяю BLE TX/RX перед стартом Live...';
});

var device = widget.ble.connectedInfo;
final startMode = _effectiveStartMode();
try {
  if (startMode == TrackerLiveSourceMode.heartRateOnly) {
    _lastProblem = 'Старт Live без GPS-трекера: активен командный Polar H10.';
    _log(_lastProblem);
    unawaited(_serverLog(_lastProblem, level: 'info', source: 'live_start_polar_only'));
  }
  if (startMode == TrackerLiveSourceMode.trackerExperimental) {
    _log('START CHECK #2: вызываю ensureCommandChannel()');
    unawaited(_serverLog(
      'START CHECK #2: ensureCommandChannel begin · command_channel_before=${widget.ble.commandChannelReady} · connected=${widget.ble.connectedInfo?.id} · lastKnown=${widget.ble.lastKnownInfo?.id}',
      source: 'live_start_ble_ensure_begin',
    ));

    final ready = await widget.ble.ensureCommandChannel();
    device = widget.ble.connectedInfo;

    _log('START CHECK #3: ensureCommandChannel result=$ready channel=${widget.ble.commandChannelReady} device=${device?.name}/${device?.id} lastKnown=${widget.ble.lastKnownInfo?.name}/${widget.ble.lastKnownInfo?.id}');
    await _serverLog(
      'START CHECK #3: ensure result=$ready · command_channel_after=${widget.ble.commandChannelReady} · device=${device?.name}/${device?.id} · lastKnown=${widget.ble.lastKnownInfo?.name}/${widget.ble.lastKnownInfo?.id}',
      level: ready ? 'info' : 'error',
      source: 'live_start_ble_ensure_result',
    );

    if (!ready || device == null) {
      _toast('Трекер выбран, но TX/RX канал не подключён. Нажмите «Поиск Bluetooth» и подключите датчик заново.');
      _lastProblem = 'START BLOCKED: BLE TX/RX не готов. Live-сессию на сервере не создаю.';
      _log(_lastProblem);
      unawaited(_serverLog(_lastProblem, level: 'error', source: 'live_start_blocked_no_ble_channel'));
      return;
    }
  }

  final deviceUuid = startMode == TrackerLiveSourceMode.heartRateOnly
      ? 'POLAR-H10-TEAM-${widget.teamId}'
      : device!.id;

  final deviceName = startMode == TrackerLiveSourceMode.heartRateOnly
      ? 'Polar H10 команда'
      : device!.name;

  final livePlayerId = startMode == TrackerLiveSourceMode.heartRateOnly ? null : widget.selectedPlayer?.id;

  _lastProblem = 'Создаю Live-сессию на сервере...';
  setState(() {});

  _log('START CHECK #4: API startLiveSession player=$livePlayerId field=${_activity.requiresField ? effectiveField?.id : null} device=$deviceName/$deviceUuid');
  await _serverLog(
    'START CHECK #4: API startLiveSession · player=$livePlayerId · field=${_activity.requiresField ? effectiveField?.id : null} · device=$deviceName/$deviceUuid · activity=${_activity.code}',
    source: 'live_start_api_begin',
  );

  final id = await _api.startLiveSession(
    clubId: widget.clubId,
    teamId: widget.teamId,
    playerId: livePlayerId,
    fieldId: _activity.requiresField ? effectiveField?.id : null,
    deviceUuid: deviceUuid,
    deviceName: deviceName,
    source: startMode == TrackerLiveSourceMode.heartRateOnly ? 'heart_rate' : 'tracker',
    batteryPercent: widget.batteryPercent,
    activityType: _activity.code,
    fieldRequired: _activity.requiresField && effectiveField != null,
  );
  startedSessionId = id;

  _log('START CHECK #5: API returned live_session_id=$id');
  await _serverLog(
    'START CHECK #5: API returned live_session_id=$id',
    level: id > 0 ? 'info' : 'error',
    source: 'live_start_api_result',
  );

  if (id <= 0) throw Exception('сервер не вернул live_session_id');

  _myLiveSessionId = id;
  widget.onLiveSessionIdChanged?.call(id);
  _setLiveRunning(true);
  _lastProblem = 'Live запущен. Таймлайн готов: добавляйте периоды тренировки.';
  await _syncLocalPeriodsToServer();


  _myLiveSessionId = id;
  widget.onLiveSessionIdChanged?.call(id);
  _setLiveRunning(true);
  _blockServerAutoRestoreAfterPlayerPick = false;
  _teamLoadHistory.clear();
  _recordTeamLoadSnapshot(force: true);
  _lastProblem = 'Live активен · режим: ${_activity.title}';
  // Не отправляем battery keep-alive первым пакетом: первым должен уйти именно GPS-запрос.
  _lastBatteryKeepAliveAt = DateTime.now();
  _lastTrackerTxAt = null;
  _lastGpsProbeAt = null;
  _bleOfflineSince = null;
  _nextBleReconnectAttemptAt = null;
  _lastBleOfflineLogAt = null;
  _offlineRecorderStatus = 'проверяю запись на трекере';

  _trackForCurrentDevice();

  if (startMode == TrackerLiveSourceMode.trackerExperimental) {
    unawaited(_syncTrackerRecorderStateAfterReconnect(source: 'live_start_record_probe'));
    _candidateCommandIndex = _lastGpsCandidateWithFix ?? 0;
    _gpsMissesForCandidate = 0;
    _lastGpsProbeAt = null;
  }

  _log('START CHECK #6: запускаю loop=${startMode == TrackerLiveSourceMode.heartRateOnly ? 'heartRateOnly' : 'trackerGps'} session=$id');
  unawaited(_serverLog(
    'START CHECK #6: loop started · mode=${startMode.name} · session=$id · command_channel=${widget.ble.commandChannelReady}',
    source: 'live_start_loop_begin',
  ));

  if (startMode == TrackerLiveSourceMode.heartRateOnly) {
    _startHeartRateOnlyLoop();
  } else {
    _startTrackerLoop();
  }

  _log('Live стартовал: session=$id');
  _serverLog('Live стартовал: session=$id', source: 'live_start');
  await _loadLiveState();
} catch (e) {
  final idToClose = startedSessionId ?? _myLiveSessionId;
  _lastProblem = 'Ошибка старта Live: $e';
  _log(_lastProblem);
  if (idToClose != null && idToClose > 0) {
    unawaited(_api.stopLiveSession(liveSessionId: idToClose, createFinalSession: false).catchError((_) => <String, dynamic>{}));
  }
  _phoneTimer?.cancel();
  _trackerTimer?.cancel();
  _heartbeatTimer?.cancel();
  _myLiveSessionId = null;
  widget.onLiveSessionIdChanged?.call(null);
  _setLiveRunning(false);
  unawaited(_serverLog(_lastProblem, level: 'error', source: 'live_start_exception'));
  _toast('Live: $e');
} finally {
  if (mounted) setState(() => _starting = false);
}
}


void _startHeartRateOnlyLoop() {
  _phoneTimer?.cancel();
  _trackerTimer?.cancel();
  _heartbeatTimer?.cancel();

  Future<void> tick() async {
    final id = _myLiveSessionId;
    if (!_running || id == null) return;
    try {
      await _api.heartbeatLiveSession(liveSessionId: id, statusText: 'heart_rate_only');
      await _loadLiveState();
      _lastProblem = widget.heartRateByPlayerId.isEmpty
          ? 'Live идёт без GPS: ожидаю online bpm от Polar H10.'
          : 'Live идёт по Polar H10: ${widget.heartRateByPlayerId.length} игрок(ов) с ЧСС online. GPS-трекер не обязателен.';
      if (mounted) setState(() {});
    } catch (e) {
      _log('Polar-only heartbeat: $e');
    }
  }

  tick();
  _heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (_) => tick());
}

String _formatRecorderStatus(List<ActionTrackerRecord> records) {
  if (records.isEmpty) return 'на датчике нет записей';
  final recording = records.where((r) => r.state == ActionTrackerRecordState.recording).toList();
  if (recording.isNotEmpty) {
    final r = recording.first;
    return 'идёт запись на трекере · file ${r.fileId} · ${r.length} байт';
  }
  final finished = records.where((r) => r.state == ActionTrackerRecordState.finished || r.length > 0).toList()
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

Future<void> _syncTrackerRecorderStateAfterReconnect({String source = 'live_record_probe'}) async {
  final now = DateTime.now();
  if (_lastPostReconnectSyncAt != null && now.difference(_lastPostReconnectSyncAt!).inSeconds < 10) return;
  if (!widget.ble.commandChannelReady) return;
  _lastPostReconnectSyncAt = now;
  try {
    _offlineRecorderStatus = 'запрашиваю состояние записи на трекере';
    if (mounted) setState(() {});
    await widget.ble.requestBatteryAndGpsState();
    await Future<void>.delayed(const Duration(milliseconds: 450));
    await widget.ble.requestRecordList();
    await _serverLog('Запрошен список записей после восстановления BLE', source: source);
  } catch (e) {
    _offlineRecorderStatus = 'не удалось проверить запись на трекере: $e';
    _log(_offlineRecorderStatus);
    unawaited(_serverLog(_offlineRecorderStatus, level: 'warning', source: '${source}_error'));
  } finally {
    if (mounted) setState(() {});
  }
}

void _startTrackerLoop() {
_trackerTimer?.cancel();
_heartbeatTimer?.cancel();

Future<void> tick() async {
  if (!_running || _paused || _trackerTxInFlight) return;
  final now = DateTime.now();
  if (_lastTrackerTxAt != null && now.difference(_lastTrackerTxAt!).inMilliseconds < 2200) return;

  final commands = ActionTrackerBleProfile.commandCurrentGpsCandidates.toList(growable: false);
  if (commands.isEmpty) return;

  // Критично: раньше смена GPS-команды почти никогда не срабатывала, потому что
  // _lastTrackerTxAt обновлялся при каждом TX и условие "6 секунд без TX" не наступало.
  // Поэтому Live фактически снова слал только первый кандидат 3A, а сессия жила
  // только heartbeat-ом: duration рос, но save_tracker_live_point.php не получал точек.
  final gpsFresh = _lastGpsAt != null && now.difference(_lastGpsAt!).inSeconds <= 4;
  var commandIndex = _candidateCommandIndex.clamp(0, commands.length - 1).toInt();
  var command = commands[commandIndex];
  var txReason = 'GPS candidate ${commandIndex + 1}/${commands.length}';
  // Keep-alive раз в 25 секунд: не подменяем им первый GPS-запрос и не считаем его
  // неудачной GPS-попыткой. Это только удержание BLE/GPS готовности.
  if (_lastBatteryKeepAliveAt != null && now.difference(_lastBatteryKeepAliveAt!).inSeconds >= 25) {
    command = ActionTrackerBleProfile.commandReadBatteryAndGps;
    txReason = 'battery/GPS keep-alive';
    _lastBatteryKeepAliveAt = now;
  } else if (!gpsFresh) {
    final probeGapOk = _lastGpsProbeAt == null || now.difference(_lastGpsProbeAt!).inMilliseconds >= 1800;
    if (probeGapOk) {
      _gpsMissesForCandidate++;
      _lastGpsProbeAt = now;
      if (_gpsMissesForCandidate >= 3) {
        _candidateCommandIndex = (_candidateCommandIndex + 1) % commands.length;
        _gpsMissesForCandidate = 0;
        commandIndex = _candidateCommandIndex.clamp(0, commands.length - 1).toInt();
        command = commands[commandIndex];
        txReason = 'GPS candidate ${commandIndex + 1}/${commands.length}';
        _lastProblem = 'GPS не пришёл — переключаю Live-команду на #${commandIndex + 1}/${commands.length}';
        _log(_lastProblem);
        unawaited(_serverLog(_lastProblem, level: 'warning', source: 'live_gps_command_fallback'));
      } else {
        _lastProblem = 'GPS пока не пришёл, повторяю Live-команду #${commandIndex + 1} · попытка $_gpsMissesForCandidate/3';
        _log(_lastProblem);
      }
    }
  } else {
    _gpsMissesForCandidate = 0;
  }

  final cmd = command
      .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join(' ');

  // v80: если за время Live датчик уснул/отвалился, не бросаем сессию — пробуем
  // восстановить TX/RX перед следующей командой. Серверная сессия при этом остаётся active.
  if (!widget.ble.commandChannelReady) {
    _bleOfflineSince ??= now;
    final waitActive = _nextBleReconnectAttemptAt != null && now.isBefore(_nextBleReconnectAttemptAt!);
    if (waitActive) {
      final shouldLog = _lastBleOfflineLogAt == null || now.difference(_lastBleOfflineLogAt!).inSeconds >= 15;
      _lastProblem = 'Трекер вне зоны BLE. Live-сессия #${_myLiveSessionId ?? 0} продолжается на сервере, запись на самом трекере не трогаю.';
      if (shouldLog) {
        _lastBleOfflineLogAt = now;
        _log(_lastProblem);
        unawaited(_serverLog(_lastProblem, level: 'warning', source: 'live_ble_out_of_range_wait'));
      }
      if (mounted) setState(() {});
      return;
    }

    _nextBleReconnectAttemptAt = now.add(const Duration(seconds: 8));
    _lastProblem = 'Проверяю возврат трекера в зону BLE...';
    if (mounted) setState(() {});
    final ready = await widget.ble.ensureCommandChannel();
    if (!ready) {
      final offlineSec = _bleOfflineSince == null ? 0 : DateTime.now().difference(_bleOfflineSince!).inSeconds;
      _lastProblem = 'Трекер пока вне зоны BLE · ${offlineSec}s. Серверная Live-сессия продолжается, после возврата запрошу записи с датчика.';
      _log(_lastProblem);
      unawaited(_serverLog(_lastProblem, level: 'warning', source: 'live_ble_reconnect_wait'));
      if (mounted) setState(() {});
      return;
    }

    final offlineSec = _bleOfflineSince == null ? 0 : DateTime.now().difference(_bleOfflineSince!).inSeconds;
    _bleOfflineSince = null;
    _nextBleReconnectAttemptAt = null;
    _lastBleOfflineLogAt = null;
    _lastProblem = 'BLE восстановлен после ${offlineSec}s. Запрашиваю батарею и список записей, затем продолжу Live.';
    _log(_lastProblem);
    await _serverLog(_lastProblem, level: 'info', source: 'live_ble_reconnected_sync');
    await _syncTrackerRecorderStateAfterReconnect(source: 'live_reconnect');
    _lastTrackerTxAt = DateTime.now();
    if (mounted) setState(() {});
    return;
  }

  _trackerTxInFlight = true;
  try {
    _lastTx = cmd;
    _lastTrackerTxAt = DateTime.now();
    _log('TX $txReason: $cmd');
    await widget.ble.sendRawCommand(command);
  } catch (e) {
    _lastProblem = 'TX GPS: $e · Live не остановлен, пробую восстановить BLE';
    _log(_lastProblem);
    unawaited(_serverLog(_lastProblem, level: 'error', source: 'live_tx_error_keep_session'));
  } finally {
    _trackerTxInFlight = false;
  }
}

tick();
_trackerTimer = Timer.periodic(const Duration(seconds: 1), (_) => tick());

_heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
  final id = _myLiveSessionId;
  if (!_running || id == null) return;
  try {
    await _api.heartbeatLiveSession(liveSessionId: id);
    await _loadLiveState();
  } catch (e) {
    _log('Heartbeat: $e');
  }
});
}

Future<void> _handleGpsPoint({
required double latitude,
required double longitude,
required int timeMs,
required String packetType,
String? rawHex,
}) async {
final track = _trackForCurrentDevice();
final stat = track.addPoint(
  latitude: latitude,
  longitude: longitude,
  timeMs: timeMs > 0 ? timeMs : DateTime.now().millisecondsSinceEpoch,
  packetType: packetType,
);

_lastGpsAt = DateTime.now();
_lastGps =
    '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)} · $packetType';

_lastLocalMetrics = _debugTrackLine(track);
_lastZeroReason = _debugZeroReason(track, stat);
_recordTeamLoadSnapshot();

if (!stat.acceptedForMetrics) {
  _lastProblem = stat.rejectReason ?? 'GPS-шум отфильтрован. Скорость и дистанция не засчитаны.';
} else if (stat.distanceDeltaM <= 0.25 && track.points.length > 1) {
  _lastProblem =
      'GPS приходит, но смещение меньше 25 см. Скорость будет около 0.';
} else {
  _lastProblem = 'GPS принят, скорость считается локально';
}

_log('LOCAL ${_lastLocalMetrics}; reason=$_lastZeroReason');
if (mounted) setState(() {});

await _savePoint(
  latitude: stat.lat,
  longitude: stat.lon,
  timeMs: timeMs,
  packetType: packetType,
  rawHex: rawHex,
);

if (_myLiveSessionId != null && track.points.length >= 10 && track.points.length % 30 == 0) {
  await _saveMetricSnapshot(manual: false);
}
}

Future<void> _savePoint({
required double latitude,
required double longitude,
required int timeMs,
required String packetType,
String? rawHex,
}) async {
final id = _myLiveSessionId;
if (id == null || _savingPoint) return;

final device = widget.ble.connectedInfo;
final deviceUuid = device?.id ?? 'TRACKER';

final track = _trackForCurrentDevice();
final analysis = _trackAnalysisWithHeartRate(track);

final payload = TrackerLivePointPayload(
  liveSessionId: id,
  clubId: widget.clubId,
  teamId: widget.teamId,
  playerId: widget.selectedPlayer?.id,
  deviceUuid: deviceUuid,
  latitude: latitude,
  longitude: longitude,
  timeMs: timeMs,
  batteryPercent: widget.batteryPercent,
  speedKmh: track.speedKmh,
  rawSpeedKmh: track.rawSpeedKmh,
  distanceDeltaM: track.lastDeltaM,
  totalDistanceM: track.totalDistanceM,
  maxSpeedKmh: track.maxSpeedKmh,
  avgSpeedKmh: track.avgSpeedKmh,
  meteragePerMin: track.metersPerMinute,
  loadScore: track.loadScore,
  loadPerMin: track.loadPerMinute,
  fatigueIndex: track.fatigueIndex,
  speedDropPercent: track.speedDropPercent,
  hsrDistanceM: track.hsrDistanceM,
  hirDistanceM: track.hirDistanceM,
  vhirDistanceM: track.vhirDistanceM,
  sprintDistanceM: track.sprintDistanceM,
  sprintCount: track.sprintCount,
  accelCount: track.accelCount,
  decelCount: track.decelCount,
  changeOfDirectionCount: track.changeOfDirectionCount,
  footballMovementScore: track.footballMovementScore,
  metabolicPowerProxy: track.metabolicPowerProxy,
  durationSec: track.durationSec,
  analysisJson: analysis,
  rawHex: rawHex,
);

final payloadJson = payload.toJson();
_lastPayload = _debugPayloadLine(payloadJson);
_lastLocalMetrics = _debugTrackLine(track);

setState(() => _savingPoint = true);

try {
  _log('PAYLOAD $_lastPayload');

  final result = await _api.saveLivePoint(payload);

  _lastServer = _debugServerLine(result);
  _lastSaveAt = DateTime.now();
  final speed = result['speed_kmh'] ?? 0;
  final delta = result['distance_delta_m'] ?? 0;
  final field = result['field'];
  final fieldWarning = field is Map ? field['field_warning'] : null;

  if (fieldWarning != null) {
    _lastProblem =
        'Сервер сохранил GPS, но координата поля вне диапазона. Проверьте калибровку.';
  } else {
    _lastProblem = 'Точка сохранена на сервере';
  }

  _lastSave = 'OK · $speed км/ч · +$delta м';
  _log('SERVER $_lastServer');
  _log('Точка сохранена: $_lastSave');
  await _serverLog(
    'point saved: $_lastSave · payload=$_lastPayload · server=$_lastServer · $packetType',
    source: 'save_point',
    rawHex: rawHex,
  );
  await _loadLiveState();
} catch (e) {
  _lastSave = 'ОШИБКА: $e';
  _lastServer = 'ОШИБКА: $e';
  _lastProblem = 'Сервер не сохранил точку: $e';
  _log('Сохранение точки: $e');
  await _serverLog(
    'save point error: $e · payload=$_lastPayload',
    level: 'error',
    source: 'save_point',
    rawHex: rawHex,
  );
} finally {
  if (mounted) setState(() => _savingPoint = false);
}
}


Future<void> _saveMetricSnapshot({required bool manual}) async {
final track = _mainTrack;
final liveId = _myLiveSessionId;
if (track == null || track.points.length < 2 || liveId == null) {
  if (manual) _toast('Недостаточно данных для сохранения метрик');
  return;
}

final device = widget.ble.connectedInfo;
try {
  await _api.saveLiveMetricSnapshot({
    'club_id': widget.clubId,
    'team_id': widget.teamId,
    'player_id': widget.selectedPlayer?.id,
    'live_session_id': liveId,
    'device_uuid': device?.id ?? 'TRACKER',
    'device_name': device?.name ?? 'Источник Live',
    'snapshot_date': DateTime.now().toIso8601String().substring(0, 10),
    'snapshot_time': DateTime.now().toIso8601String(),
    'activity_type': _activity.code,
    'activity_title': _activity.title,
    'field_required': _activity.requiresField ? 1 : 0,
    'duration_sec': track.durationSec,
    'speed_kmh': track.speedKmh,
    'max_speed_kmh': track.maxSpeedKmh,
    'avg_speed_kmh': track.avgSpeedKmh,
    'distance_m': track.totalDistanceM,
    'meterage_per_min': track.metersPerMinute,
    'pace_min_km': track.paceMinKm,
    'load_score': track.loadScore,
    'load_per_min': track.loadPerMinute,
    'fatigue_index': track.fatigueIndex,
    'speed_drop_percent': track.speedDropPercent,
    'hsr_distance_m': track.hsrDistanceM,
    'hir_distance_m': track.hirDistanceM,
    'vhir_distance_m': track.vhirDistanceM,
    'sprint_distance_m': track.sprintDistanceM,
    'sprint_count': track.sprintCount,
    'accel_count': track.accelCount,
    'decel_count': track.decelCount,
    'change_of_direction_count': track.changeOfDirectionCount,
    'football_movement_score': track.footballMovementScore,
    'metabolic_power_proxy': track.metabolicPowerProxy,
    'work_rest_ratio': track.workRestRatio,
    'recommendation': track.recommendation,
    if (_selectedHeartRateSample != null) 'heart_rate_bpm': _selectedHeartRateSample!.bpm,
    if (_selectedHeartRateSample?.batteryPercent != null) 'heart_rate_battery_percent': _selectedHeartRateSample!.batteryPercent,
    if (_selectedHeartRateSample != null) 'heart_rate_device_uuid': _selectedHeartRateSample!.deviceId,
    if (_selectedHeartRateSample != null) 'heart_rate_device_name': _selectedHeartRateSample!.deviceName,
    'analysis_json': _trackAnalysisWithHeartRate(track),
  });
  _log('Metric snapshot сохранён: load=${track.loadScore.toStringAsFixed(0)}, fatigue=${track.fatigueIndex.toStringAsFixed(0)}%');
  if (manual) _toast('Метрики Live сохранены по дате');
} catch (e) {
  _log('Metric snapshot error: $e');
  if (manual) _toast('Ошибка сохранения метрик: $e');
}
}

Future<void> _stopLive() async {
_setLiveRunning(false);
_paused = false;
_phoneTimer?.cancel();
_trackerTimer?.cancel();
_heartbeatTimer?.cancel();

final id = _myLiveSessionId;
if (id != null) {
  try {
    final result = await _api.stopLiveSession(
      liveSessionId: id,
      createFinalSession: true,
    );
    _lastStop = _shortJson(result, max: 1200);
    final finalId = result['final_session_id'] ?? result['session_id'] ?? result['tracker_session_id'];
    final copied = result['copied_session_points'] ?? result['points_count'] ?? result['copied_points'];
    _lastProblem = finalId == null
        ? 'Live остановлен. Сервер ответил без final_session_id — проверь stop_tracker_live_session.php'
        : 'Live остановлен и сохранён как сессия #$finalId · точек=$copied';
    _log('Live остановлен: session=$id · stop=$_lastStop');
    unawaited(_serverLog(
      'Live STOP SAVE: session=$id · final_session=${finalId ?? 'нет'} · copied_points=${copied ?? 'нет'} · status=${finalId == null ? 'проверь stop_tracker_live_session.php' : 'ok'}',
      level: finalId == null ? 'warning' : 'info',
      source: 'live_stop_save_result',
    ));
    // Сохраняем финальный локальный snapshot метрик даже если серверная финализация вернула только live id.
    unawaited(_saveMetricSnapshot(manual: false));
  } catch (e) {
    _lastStop = 'ОШИБКА: $e';
    _lastProblem = 'Ошибка остановки Live: $e';
    _log(_lastProblem);
  }
}

_myLiveSessionId = null;
_blockServerAutoRestoreAfterPlayerPick = true;
widget.onLiveSessionIdChanged?.call(null);
await _loadLiveState(restoreRunning: false);
if (mounted) setState(() {});
}


Future<void> _autoSaveLiveAfterParentDecision() async {
if (!_running && _myLiveSessionId == null) return;
_phoneTimer?.cancel();
_trackerTimer?.cancel();
_heartbeatTimer?.cancel();
_paused = false;
final id = _myLiveSessionId;
_setLiveRunning(false);
if (id != null) {
  try {
    final result = await _api.stopLiveSession(liveSessionId: id, createFinalSession: true);
    _lastStop = _shortJson(result, max: 1200);
    final finalId = result['final_session_id'] ?? result['session_id'] ?? result['tracker_session_id'];
    _lastProblem = finalId == null
        ? 'Live закрыт, сервер не вернул final_session_id. Проверьте stop_tracker_live_session.php.'
        : 'Live автоматически сохранён при выходе как сессия #$finalId';
    _log("Live auto-save при закрытии: live=$id · final=${finalId ?? 'нет'}");
    unawaited(_serverLog("Live auto-save on close: live=$id · final=${finalId ?? 'нет'} · result=$_lastStop", source: 'live_auto_save_on_close'));
  } catch (e) {
    _lastStop = 'ОШИБКА autosave: $e';
    _lastProblem = 'Ошибка автосохранения Live при выходе: $e';
    _log(_lastProblem);
  }
}
_myLiveSessionId = null;
_blockServerAutoRestoreAfterPlayerPick = true;
widget.onLiveSessionIdChanged?.call(null);
await _loadLiveState(restoreRunning: false);
if (mounted) setState(() {});
}


void _pauseLiveCollection() {
if (!_running) return;
if (_paused) return;
_phoneTimer?.cancel();
_trackerTimer?.cancel();
_paused = true;
_lastProblem = 'Live приостановлен. Сессия не завершена, данные уже отправленные на сервер сохранены. Нажмите «Продолжить», чтобы снова писать точки.';
_log('Live приостановлен пользователем');
if (mounted) setState(() {});
}

void _resumeLiveCollection() {
if (!_running || !_paused) return;
_paused = false;
_lastProblem = 'Live продолжен. Запись точек снова активна.';
if (_effectiveStartMode() == TrackerLiveSourceMode.heartRateOnly) {
  _startHeartRateOnlyLoop();
} else {
  _startTrackerLoop();
}
_log('Live продолжен после паузы');
if (mounted) setState(() {});
}

Future<void> _exitLiveWithoutSaving() async {
// По требованию: даже случайный выход/закрытие сохраняет тренировку.
// Кнопка старого «без сохранения» теперь работает как безопасное автосохранение.
await _autoSaveLiveAfterParentDecision();
}


Future<void> _addDebugLocalPoint() async {
final startLat = 55.973505;
final startLon = 37.399388;
final track = _trackForCurrentDevice();

final index = track.points.length;
final lat = startLat + index * 0.000006;
final lon = startLon + index * 0.000010;

await _handleGpsPoint(
  latitude: lat,
  longitude: lon,
  timeMs: DateTime.now().millisecondsSinceEpoch,
  packetType: 'LOCAL-TEST',
  rawHex: null,
);

_lastProblem = 'Добавлена тестовая точка на устройстве. Если она двигается — UI работает, проблема в GPS/сервере.';
if (mounted) setState(() {});
}


Future<void> _addDebugIntensitySequence() async {
// Диагностический тест: искусственно создаёт HIR/VHIR/SPR/ACC/DEC/COD.
// Нужен, чтобы быстро понять: UI/Flutter/сервер умеют показывать метрики или нет.
final now = DateTime.now().millisecondsSinceEpoch;
final last = _mainTrack?.points.isNotEmpty == true ? _mainTrack!.points.last : null;
double lat = last?.lat ?? 55.973505;
double lon = last?.lon ?? 37.399388;
int t = last?.timeMs ?? now;

final steps = <_DebugStep>[
  const _DebugStep(northM: 0, eastM: 0, dtMs: 1000, label: 'DEBUG-START'),
  const _DebugStep(northM: 4.2, eastM: 0, dtMs: 1000, label: 'DEBUG-HIR'),
  const _DebugStep(northM: 5.8, eastM: 0, dtMs: 1000, label: 'DEBUG-VHIR'),
  const _DebugStep(northM: 7.4, eastM: 0, dtMs: 1000, label: 'DEBUG-SPR'),
  const _DebugStep(northM: 0.5, eastM: 0, dtMs: 1000, label: 'DEBUG-DEC'),
  const _DebugStep(northM: 0, eastM: 5.5, dtMs: 1000, label: 'DEBUG-COD'),
  const _DebugStep(northM: 0, eastM: 7.2, dtMs: 1000, label: 'DEBUG-SPR2'),
];

_log('--- DEBUG intensity sequence start ---');
for (final step in steps) {
  t += step.dtMs;
  lat += _latOffsetByMeters(step.northM);
  lon += _lonOffsetByMeters(step.eastM, lat);
  await _handleGpsPoint(
    latitude: lat,
    longitude: lon,
    timeMs: t,
    packetType: step.label,
    rawHex: null,
  );
  await Future<void>.delayed(const Duration(milliseconds: 120));
}
_lastProblem = 'Отладочный тест HIR/VHIR/SPR выполнен. Если метрики появились локально, но не появились в SQL — проблема PHP/API.';
_log('--- DEBUG intensity sequence done: ${_debugTrackLine(_mainTrack)} ---');
if (mounted) setState(() {});
}

Future<void> _testGpsCommands() async {
if (_testingCommands) return;

final device = widget.ble.connectedInfo;
if (device == null) {
  _toast('Сначала подключите BLE-трекер');
  return;
}

setState(() => _testingCommands = true);

try {
  _log('--- Проверка команд GPS ---');
  final commands = ActionTrackerBleProfile.commandCurrentGpsCandidates;

  for (var i = 0; i < commands.length; i++) {
    if (!mounted) break;

    final cmd = commands[i]
        .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(' ');

    setState(() => _candidateCommandIndex = i);
    _log('TEST TX ${i + 1}/${commands.length}: $cmd');

    try {
      await widget.ble.sendRawCommand(commands[i]);
    } catch (e) {
      _log('TEST ERROR: $e');
    }

    await Future<void>.delayed(const Duration(milliseconds: 700));
  }

  _candidateCommandIndex = _lastGpsCandidateWithFix ?? 0;
  _gpsMissesForCandidate = 0;
  _log('--- Проверка завершена. Рабочая команда: кандидат ${_candidateCommandIndex + 1} ---');
} finally {
  if (mounted) setState(() => _testingCommands = false);
}
}

String _runtimeTrackKey(ActionTrackerDevice? device) {
final playerPart = 'P${widget.selectedPlayer?.id ?? 0}';
return '${device?.id ?? 'TRACKER'}-$playerPart';
}

_RuntimeTrack _trackForCurrentDevice() {
final device = widget.ble.connectedInfo;
final key = _runtimeTrackKey(device);

final playerName = widget.selectedPlayer?.name ?? 'Игрок';
final deviceName = device?.name ?? 'Трекер';

return _tracks.putIfAbsent(
  key,
  () => _RuntimeTrack(
    key: key,
    playerName: playerName,
    deviceName: deviceName,
    avatar: widget.selectedPlayer?.avatar,
  ),
);
}

Future<void> _serverLog(
String message, {
String level = 'info',
String source = 'live',
String? rawHex,
}) async {
try {
  await _api.sendDebugLog(
    teamId: widget.teamId,
    playerId: widget.selectedPlayer?.id,
    liveSessionId: _myLiveSessionId,
    level: level,
    source: source,
    message: message,
    rawHex: rawHex,
  );
  _lastRemoteDebug = 'OK · $source · ${DateTime.now().toIso8601String()}';
} catch (e) {
  // Удалённый debug не должен останавливать BLE/GPS-поток.
  // Если PHP-файл не загружен или таблица не создана, Live всё равно продолжает принимать GPS.
  _lastRemoteDebug = 'ОШИБКА debug endpoint: $e';
  _log('REMOTE DEBUG ERROR: $e');
}
}

void _log(String text) {
final line = '[${DateTime.now().toIso8601String()}] $text';
// ignore: avoid_print
print('[TRACKER_LIVE] $line');

if (!mounted) return;
setState(() {
  _logs.insert(0, line);
  if (_logs.length > 220) _logs.removeLast();
});
}

void _toast(String text) {
if (!mounted) return;
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text(text, style: const TextStyle(color: _OF.text, fontSize: 11.5, fontWeight: FontWeight.w500)),
    backgroundColor: Colors.white,
    behavior: SnackBarBehavior.floating,
    elevation: 0,
    margin: const EdgeInsets.all(9),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
    duration: const Duration(seconds: 4),
  ),
);
}

_RuntimeTrack? get _mainTrack {
if (_tracks.isEmpty) return null;
final key = _runtimeTrackKey(widget.ble.connectedInfo);
if (_tracks.containsKey(key)) return _tracks[key];
final selectedSuffix = '-P${widget.selectedPlayer?.id ?? 0}';
for (final entry in _tracks.entries) {
  if (entry.key.endsWith(selectedSuffix)) return entry.value;
}
return widget.selectedPlayer == null ? _tracks.values.first : null;
}

double get _displaySpeedKmh {
final local = _mainTrack?.speedKmh ?? 0;
if (local > 0) return local;

final server = _sessions.isEmpty ? 0.0 : _sessions.first.speedKmh;
return server;
}

double get _displayDistanceM {
final local = _mainTrack?.totalDistanceM ?? 0;
if (local > 0) return local;

final server = _sessions.isEmpty ? 0.0 : _sessions.first.totalDistanceM;
return server;
}

int get _displayPoints => _tracks.values.fold<int>(0, (s, t) => s + t.points.length);

Widget _ofVerticalDivider() => const SizedBox(width: 6);
Widget _ofHorizontalDivider() => const SizedBox(height: 6);

@override
Widget build(BuildContext context) {
super.build(context);

final active = _sessions.where((s) => s.status == 'active').toList();
final online = active.where((s) => s.isOnline).length;

return LayoutBuilder(
  builder: (context, constraints) {
    final width = constraints.maxWidth;
    final height = constraints.maxHeight;
    late final Widget base;

    if (width < 720) {
      base = _phoneOpenFieldLayout(online, active.length);
    } else if (width < 1120) {
      base = _tabletOpenFieldLayout(online, active.length, height);
    } else {
      base = _desktopOpenFieldLayout(online, active.length);
    }

    return _withFloatingLiveWindow(base);
  },
);
}

Widget _desktopOpenFieldLayout(int online, int active) {
return LayoutBuilder(
  builder: (context, c) {
    return Container(
      color: Colors.transparent,
      child: Column(
        children: [
          _liveControlStrip(online, active, compact: false),
          _ofHorizontalDivider(),
          SizedBox(height: 88, child: _tabletMonitorPlayersStrip(compact: false)),
          _ofHorizontalDivider(),
          Expanded(
            child: _teamFieldPanelExpanded
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 1,
                        child: _tabletMonitoringGridPanel(compact: false),
                      ),
                      _ofVerticalDivider(),
                      Expanded(
                        flex: 1,
                        child: _operatorFieldPanel(),
                      ),
                    ],
                  )
                : _tabletMonitoringGridPanel(compact: false),
          ),
          _ofHorizontalDivider(),
          _bottomOperatorBar(online, active),
        ],
      ),
    );
  },
);
}

Widget _tabletOpenFieldLayout(int online, int active, double height) {
return LayoutBuilder(
  builder: (context, c) {
    final compactTablet = c.maxWidth < 980 || c.maxHeight < 680;
    if (compactTablet) {
      return _smallTabletLiveDashboard(online, active);
    }
    return Container(
      color: Colors.transparent,
      child: Column(
        children: [
          _liveControlStrip(online, active, compact: true),
          _ofHorizontalDivider(),
          SizedBox(height: 86, child: _tabletMonitorPlayersStrip(compact: false)),
          _ofHorizontalDivider(),
          Expanded(
            child: _teamFieldPanelExpanded
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 1,
                        child: _tabletMonitoringGridPanel(compact: false),
                      ),
                      _ofVerticalDivider(),
                      Expanded(
                        flex: 1,
                        child: _operatorFieldPanel(),
                      ),
                    ],
                  )
                : _tabletMonitoringGridPanel(compact: false),
          ),
          _ofHorizontalDivider(),
          _bottomOperatorBar(online, active),
        ],
      ),
    );
  },
);
}

Widget _smallTabletLiveDashboard(int online, int active) {
return LayoutBuilder(
  builder: (context, c) {
    final showMiniField = c.maxWidth >= 700;
    return Container(
      color: Colors.transparent,
      child: Column(
        children: [
          _liveControlStrip(online, active, compact: true),
          _ofHorizontalDivider(),
          SizedBox(height: 78, child: _tabletMonitorPlayersStrip(compact: true)),
          _ofHorizontalDivider(),
          Expanded(
            child: _teamFieldPanelExpanded && showMiniField
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 1, child: _tabletMonitoringGridPanel(compact: true)),
                      _ofVerticalDivider(),
                      Expanded(flex: 1, child: _operatorFieldPanel()),
                    ],
                  )
                : _tabletMonitoringGridPanel(compact: true, showFieldAction: true),
          ),
          _ofHorizontalDivider(),
          _bottomOperatorBar(online, active),
        ],
      ),
    );
  },
);
}


List<TrackerPlayerOption> _monitorCandidatePlayers() {
final connected = _connectedPlayerOptions();
final base = connected.isNotEmpty ? connected : _livePlayerOptions();
final sorted = List<TrackerPlayerOption>.from(base);
sorted.sort((a, b) {
  final aSelected = _monitorPlayerIds.contains(a.id) ? 1 : 0;
  final bSelected = _monitorPlayerIds.contains(b.id) ? 1 : 0;
  if (aSelected != bSelected) return bSelected.compareTo(aSelected);
  final aOnline = _isPlayerOnlineLive(a.id) ? 1 : 0;
  final bOnline = _isPlayerOnlineLive(b.id) ? 1 : 0;
  if (aOnline != bOnline) return bOnline.compareTo(aOnline);
  final loadCompare = _loadForPlayerId(b.id).compareTo(_loadForPlayerId(a.id));
  if (loadCompare != 0) return loadCompare;
  return (int.tryParse(a.number ?? '') ?? 9999).compareTo(int.tryParse(b.number ?? '') ?? 9999);
});
return sorted;
}

List<TrackerPlayerOption> _monitorPlayersForGrid() {
final candidates = _monitorCandidatePlayers();
if (candidates.isEmpty) return const <TrackerPlayerOption>[];
final byId = <int, TrackerPlayerOption>{for (final p in candidates) p.id: p};
final manual = _monitorPlayerIds.where((id) => byId.containsKey(id)).map((id) => byId[id]!).toList(growable: false);
if (_monitorManualSelectionTouched) return manual.take(_maxMonitorPlayers).toList(growable: false);
if (manual.isNotEmpty) return manual.take(_maxMonitorPlayers).toList(growable: false);
final connected = candidates.where((p) => _isPlayerOnlineLive(p.id) || _heartRateForPlayerId(p.id) != null || (_localTrackForPlayer(p.id)?.points.isNotEmpty ?? false)).take(_maxMonitorPlayers).toList(growable: false);
if (connected.isNotEmpty) return connected;
if (widget.selectedPlayer != null && byId.containsKey(widget.selectedPlayer!.id)) return <TrackerPlayerOption>[widget.selectedPlayer!];
return candidates.take(_maxMonitorPlayers).toList(growable: false);
}

void _toggleMonitorPlayer(TrackerPlayerOption player) {
if (player.id <= 0) return;
final currentGridIds = _monitorPlayersForGrid().map((p) => p.id).toList(growable: false);
setState(() {
  if (!_monitorManualSelectionTouched && currentGridIds.isNotEmpty) {
    _monitorPlayerIds
      ..clear()
      ..addAll(currentGridIds.take(_maxMonitorPlayers));
  }
  _monitorManualSelectionTouched = true;
  if (_monitorPlayerIds.contains(player.id)) {
    _monitorPlayerIds.remove(player.id);
    _monitorMapPlayerIds.remove(player.id);
    return;
  }
  if (_monitorPlayerIds.length >= _maxMonitorPlayers) {
    final first = _monitorPlayerIds.first;
    _monitorPlayerIds.remove(first);
    _monitorMapPlayerIds.remove(first);
  }
  _monitorPlayerIds.add(player.id);
});
}

void _removeMonitorPlayer(TrackerPlayerOption player) {
if (player.id <= 0) return;
final currentGridIds = _monitorPlayersForGrid().map((p) => p.id).toList(growable: false);
setState(() {
  if (!_monitorManualSelectionTouched && currentGridIds.isNotEmpty) {
    _monitorPlayerIds
      ..clear()
      ..addAll(currentGridIds.take(_maxMonitorPlayers));
  }
  _monitorManualSelectionTouched = true;
  _monitorPlayerIds.remove(player.id);
  _monitorMapPlayerIds.remove(player.id);
});
}

void _toggleMonitorPlayerMap(TrackerPlayerOption player) {
  _openPlayerOnSidePanel(player, mode: _liveSidePanelMode == 'map' ? 'map' : _liveSidePanelMode);
}

void _clearMonitorPlayers() {
setState(() {
  _monitorManualSelectionTouched = true;
  _monitorPlayerIds.clear();
  _monitorMapPlayerIds.clear();
});
}

bool _isPlayerInMonitorGrid(int? playerId) {
if (playerId == null || playerId <= 0) return false;
return _monitorPlayersForGrid().any((p) => p.id == playerId);
}

List<TrackerPlayerOption> _sidePanelPlayers() {
  final grid = _monitorPlayersForGrid();
  final byId = <int, TrackerPlayerOption>{for (final p in _monitorCandidatePlayers()) p.id: p};
  final selected = _monitorMapPlayerIds
      .where((id) => byId.containsKey(id))
      .map((id) => byId[id]!)
      .toList(growable: false);
  if (selected.isNotEmpty) return selected.take(_maxMonitorPlayers).toList(growable: false);
  return grid.take(_maxMonitorPlayers).toList(growable: false);
}

List<_RuntimeTrack> _sidePanelTracks() {
  final players = _sidePanelPlayers();
  final tracks = <_RuntimeTrack>[];
  for (final player in players) {
    final track = _displayTrackForPlayer(player);
    if (track != null && track.points.isNotEmpty) tracks.add(track);
  }
  if (tracks.isNotEmpty) return tracks;
  if (_monitorMapPlayerIds.isNotEmpty) return const <_RuntimeTrack>[];
  return _tracks.values.where((track) => track.points.isNotEmpty).toList(growable: false);
}

String _sidePanelSelectionLabel() {
  final players = _sidePanelPlayers();
  if (_monitorMapPlayerIds.isEmpty) return 'общая команда';
  if (players.length == 1) return _compactPlayerName(players.first.name);
  return '${players.length} игрок.';
}

void _openPlayerOnSidePanel(TrackerPlayerOption player, {String mode = 'map'}) {
  if (player.id <= 0) return;
  final currentGridIds = _monitorPlayersForGrid().map((p) => p.id).toList(growable: false);
  setState(() {
    if (!_monitorManualSelectionTouched && currentGridIds.isNotEmpty) {
      _monitorPlayerIds
        ..clear()
        ..addAll(currentGridIds.take(_maxMonitorPlayers));
    }
    _monitorManualSelectionTouched = true;
    if (!_monitorPlayerIds.contains(player.id)) {
      if (_monitorPlayerIds.length >= _maxMonitorPlayers) {
        final first = _monitorPlayerIds.first;
        _monitorPlayerIds.remove(first);
        _monitorMapPlayerIds.remove(first);
      }
      _monitorPlayerIds.add(player.id);
    }
    _monitorMapPlayerIds.add(player.id);
    _teamFieldPanelExpanded = true;
    _liveSidePanelMode = mode;
  });
}

void _togglePlayerOnSidePanel(TrackerPlayerOption player, {String mode = 'map'}) {
  if (player.id <= 0) return;
  final currentGridIds = _monitorPlayersForGrid().map((p) => p.id).toList(growable: false);
  setState(() {
    if (!_monitorManualSelectionTouched && currentGridIds.isNotEmpty) {
      _monitorPlayerIds
        ..clear()
        ..addAll(currentGridIds.take(_maxMonitorPlayers));
    }
    _monitorManualSelectionTouched = true;
    if (!_monitorPlayerIds.contains(player.id)) {
      if (_monitorPlayerIds.length >= _maxMonitorPlayers) {
        final first = _monitorPlayerIds.first;
        _monitorPlayerIds.remove(first);
        _monitorMapPlayerIds.remove(first);
      }
      _monitorPlayerIds.add(player.id);
    }
    if (_monitorMapPlayerIds.contains(player.id)) {
      _monitorMapPlayerIds.remove(player.id);
    } else {
      _monitorMapPlayerIds.add(player.id);
    }
    _teamFieldPanelExpanded = true;
    _liveSidePanelMode = mode;
  });
}

void _captureHeartRateSamples() {
  if (widget.heartRateByPlayerId.isEmpty) return;
  for (final entry in widget.heartRateByPlayerId.entries) {
    final sample = entry.value;
    final list = _liveHrHistoryByPlayer.putIfAbsent(entry.key, () => <_LiveHrPoint>[]);
    final ms = sample.measuredAt.millisecondsSinceEpoch;
    if (list.isNotEmpty && list.last.timeMs == ms && list.last.bpm == sample.bpm) continue;
    list.add(_LiveHrPoint(timeMs: ms, bpm: sample.bpm));
    if (list.length > 360) list.removeRange(0, list.length - 360);
  }
}

int? _playerBleRssi(TrackerPlayerOption player) {
  final info = widget.ble.connectedInfo;
  if (info == null) return null;
  final linked = _deviceForPlayer(player.id);
  if (linked == null) return info.rssi == 0 ? null : info.rssi;
  final uuid = linked.deviceUuid.toLowerCase();
  final name = linked.deviceName.toLowerCase();
  final infoId = info.id.toLowerCase();
  final infoName = info.name.toLowerCase();
  if (uuid.isNotEmpty && infoId.contains(uuid)) return info.rssi == 0 ? null : info.rssi;
  if (name.isNotEmpty && infoName.contains(name)) return info.rssi == 0 ? null : info.rssi;
  return null;
}

TrackerDeviceModel? _deviceForPlayer(int? playerId) {
  if (playerId == null) return null;
  for (final d in widget.savedDevices) {
    if (d.playerId == playerId) return d;
  }
  return null;
}

String _signalLabelForPlayer(TrackerPlayerOption player) {
  final rssi = _playerBleRssi(player);
  if (rssi != null) {
    if (rssi >= -65) return 'сигнал высокий';
    if (rssi >= -82) return 'сигнал норм';
    return 'слабый сигнал';
  }
  final device = _deviceForPlayer(player.id);
  if (device?.isNearby == true) return 'рядом';
  if (_isPlayerOnlineLive(player.id) || _heartRateForPlayerId(player.id) != null) return 'online';
  return 'offline';
}

Color _signalColorForPlayer(TrackerPlayerOption player) {
  final label = _signalLabelForPlayer(player);
  if (label.contains('высок') || label.contains('норм') || label == 'online' || label == 'рядом') return _OF.green;
  if (label.contains('слаб')) return _OF.orange;
  return _OF.muted2;
}

Widget _tabletMonitorPlayersStrip({required bool compact}) {
final players = _monitorCandidatePlayers();
final selected = _monitorPlayersForGrid();
final selectedIds = selected.map((p) => p.id).toSet();
final connectedCount = players.where((p) => _isPlayerOnlineLive(p.id) || _heartRateForPlayerId(p.id) != null || (_localTrackForPlayer(p.id)?.points.isNotEmpty ?? false)).length;
if (players.isEmpty) {
  return Container(
    color: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 8),
    alignment: Alignment.centerLeft,
    child: const Text('Подключите трекеры или Polar — здесь появится лента игроков для Live-мониторинга.', style: TextStyle(color: _OF.muted2, fontSize: 11, fontWeight: FontWeight.w700)),
  );
}
return Container(
  color: Colors.white,
  padding: EdgeInsets.fromLTRB(compact ? 8 : 10, compact ? 7 : 8, compact ? 8 : 10, compact ? 7 : 8),
  child: Row(
    children: [
      SizedBox(
        width: compact ? 104 : 126,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Live',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _OF.text,
                fontSize: compact ? 11.2 : 12.0,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${selected.length}/$_maxMonitorPlayers · $connectedCount online',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _OF.green,
                fontSize: compact ? 8.9 : 9.6,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: players.length,
          separatorBuilder: (_, __) => const SizedBox(width: 7),
          itemBuilder: (_, i) => _tabletMonitorPlayerChip(players[i], i, selected: selectedIds.contains(players[i].id), compact: compact),
        ),
      ),
      const SizedBox(width: 8),
      _NoHoverTap(
        onTap: _clearMonitorPlayers,
        borderRadius: BorderRadius.circular(_OF.tabletInnerRadius),
        child: Container(
          height: compact ? 42 : 48,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(_OF.tabletInnerRadius)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.close_rounded, color: _OF.muted2, size: 16),
              if (!compact) ...[
                const SizedBox(width: 5),
                const Text('Снять', style: TextStyle(color: _OF.muted2, fontSize: 11.2, fontWeight: FontWeight.w800)),
              ],
            ],
          ),
        ),
      ),
    ],
  ),
);
}

Widget _tabletMonitorPlayerChip(TrackerPlayerOption player, int index, {required bool selected, required bool compact}) {
final online = _isPlayerOnlineLive(player.id);
final heartRate = _heartRateForPlayerId(player.id);
final load = _loadForPlayerId(player.id);
final hasTrack = _localTrackForPlayer(player.id)?.points.isNotEmpty ?? false;
final active = online || heartRate != null || hasTrack;
final number = player.number ?? '${index + 1}';
return Material(
  color: Colors.transparent,
  borderRadius: BorderRadius.circular(_OF.tabletInnerRadius),
  child: _NoHoverTap(
    onTap: () => _toggleMonitorPlayer(player),
    onLongPress: () => _selectPlayerForAnalytics(player),
    borderRadius: BorderRadius.circular(_OF.tabletInnerRadius),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: compact ? 154 : 178,
      padding: EdgeInsets.fromLTRB(compact ? 7 : 8, 6, compact ? 7 : 8, 6),
      decoration: BoxDecoration(
        color: selected ? _OF.greenSoft : Colors.white,
        border: Border(
          left: BorderSide(
            color: selected ? _OF.green : Colors.transparent,
            width: 3,
          ),
        ),
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              _playerAvatarCircle(player: player, radius: compact ? 17 : 19, online: active || selected),
              Positioned(
                right: -4,
                bottom: -4,
                child: Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: selected ? _OF.green : Colors.white, shape: BoxShape.circle, border: Border.all(color: selected ? _OF.green : _OF.line)),
                  child: Text(number, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: selected ? Colors.white : _OF.graphite, fontSize: 9.6, fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_compactPlayerName(player.name), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: selected ? _OF.green : _OF.text, fontSize: compact ? 10.1 : 10.7, fontWeight: FontWeight.w800, letterSpacing: -.08)),
                const SizedBox(height: 3),
                Row(children: [
                  _monitorTinySignal(Icons.sensors_rounded, active: active, color: _OF.green),
                  const SizedBox(width: 4),
                  _monitorTinySignal(Icons.favorite_rounded, active: heartRate != null, color: _OF.red),
                  const SizedBox(width: 5),
                  Expanded(child: Text(heartRate == null ? 'HR —' : '${heartRate.bpm} bpm', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _OF.muted2, fontSize: 9.6, fontWeight: FontWeight.w800))),
                  Text(load <= 0 ? '0' : load.toStringAsFixed(0), style: TextStyle(color: load > 0 ? _loadMarkColor(load, heartRateBpm: heartRate?.bpm) : _OF.muted2, fontSize: 9.6, fontWeight: FontWeight.w900)),
                ]),
              ],
            ),
          ),
        ],
      ),
    ),
  ),
);
}

Widget _monitorTinySignal(IconData icon, {required bool active, required Color color}) {
return Icon(icon, size: 11, color: active ? color : _OF.muted2.withOpacity(.55));
}

Widget _tabletMonitoringGridPanel({bool compact = false, bool showFieldAction = false}) {
final players = _monitorPlayersForGrid();
final title = compact ? 'Live-мониторинг' : 'Live-мониторинг игроков';
final subtitle = players.isEmpty ? 'выберите игроков сверху' : '${players.length}/$_maxMonitorPlayers окон · свайп влево/вправо для остальных';
return _ofPanel(
  title: title,
  subtitle: subtitle,
  actions: [
    if (_activity.requiresField)
      _fieldPanelToggleButton(compact: compact),
    if (showFieldAction)
      _livePanelWindowButton(
        label: 'Поле',
        tooltip: 'Открыть поле отдельным окном',
        onTap: () => _openExpandedLiveBlock('Поле / тактическая карта', Icons.map_rounded, () => _fieldCard()),
      ),
  ],
  child: players.isEmpty
      ? _monitorEmptyState()
      : LayoutBuilder(
          builder: (context, c) {
            final columns = c.maxWidth >= 1060 ? 4 : (c.maxWidth >= 700 ? 3 : 2);
            final perPage = math.max(1, math.min(_maxMonitorPlayers, columns * 2));
            final aspect = columns >= 4
                ? (compact ? 2.18 : 2.30)
                : (columns == 3 ? (compact ? 1.92 : 2.05) : (compact ? 1.62 : 1.75));
            Widget gridFor(List<TrackerPlayerOption> pagePlayers) => GridView.builder(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              padding: EdgeInsets.all(compact ? 7 : 9),
              itemCount: pagePlayers.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: compact ? 8 : 10,
                crossAxisSpacing: compact ? 8 : 10,
                childAspectRatio: aspect,
              ),
              itemBuilder: (_, i) => _tabletLiveMonitorCard(pagePlayers[i], i, compact: compact),
            );

            if (players.length <= perPage) return gridFor(players);
            final pages = <List<TrackerPlayerOption>>[];
            for (var i = 0; i < players.length; i += perPage) {
              pages.add(players.sublist(i, math.min(players.length, i + perPage)));
            }
            return Stack(
              children: [
                PageView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: pages.length,
                  itemBuilder: (_, page) => gridFor(pages[page]),
                ),
                Positioned(
                  right: 10,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(.92), borderRadius: BorderRadius.circular(_OF.tabletInnerRadius)),
                    child: Text('${pages.length} стр.', style: const TextStyle(color: _OF.muted2, fontSize: 9.6, fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            );
          },
        ),
);
}

Widget _monitorEmptyState() {
return Center(
  child: Container(
    width: 360,
    padding: const EdgeInsets.all(10),
    decoration: const BoxDecoration(color: Colors.white),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: const [
        Icon(Icons.touch_app_rounded, color: _OF.green, size: 32),
        SizedBox(height: 10),
        Text('Выберите игроков в верхней ленте', textAlign: TextAlign.center, style: TextStyle(color: _OF.text, fontSize: 13, fontWeight: FontWeight.w800)),
        SizedBox(height: 5),
        Text('Можно открыть до 12 live-окон одновременно: GPS, скорость, пульс и нагрузка будут обновляться в каждой карточке.', textAlign: TextAlign.center, style: TextStyle(color: _OF.muted2, fontSize: 11.0, fontWeight: FontWeight.w700, height: 1.25)),
      ],
    ),
  ),
);
}

Widget _tabletLiveMonitorCard(TrackerPlayerOption player, int index, {required bool compact}) {
final local = _localTrackForPlayer(player.id);
final session = _sessionForPlayer(player.id);
final heartRate = _heartRateForPlayerId(player.id);
final distance = math.max(session?.totalDistanceM ?? 0.0, local?.totalDistanceM ?? 0.0);
final speed = math.max(session?.speedKmh ?? 0.0, local?.speedKmh ?? 0.0);
final maxSpeed = math.max(session?.maxSpeedKmh ?? 0.0, local?.maxSpeedKmh ?? 0.0);
final load = math.max(session?.loadScore ?? 0.0, local?.loadScore ?? 0.0);
final sprint = math.max(session?.sprintDistanceM ?? 0.0, local?.sprintDistanceM ?? 0.0);
final points = local?.points.length ?? (session?.latitude != null && session?.longitude != null ? 1 : 0);
final online = _isPlayerOnlineLive(player.id) || session?.isOnline == true || heartRate != null || points > 0;
final mapActive = _monitorMapPlayerIds.contains(player.id);
final signalLabel = _signalLabelForPlayer(player);
final signalColor = _signalColorForPlayer(player);
return Material(
  color: Colors.transparent,
  borderRadius: BorderRadius.circular(_OF.tabletCardRadius),
  child: _NoHoverTap(
    onTap: () => _openPlayerOnSidePanel(player, mode: 'map'),
    onLongPress: () => _selectPlayerForAnalytics(player),
    borderRadius: BorderRadius.circular(_OF.tabletCardRadius),
    child: Container(
      padding: EdgeInsets.all(compact ? 7 : 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_OF.tabletCardRadius),
        border: Border.all(color: online ? _OF.greenBorder : _OF.line, width: online ? 1.15 : 1),
        
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _playerAvatarCircle(player: player, radius: compact ? 16 : 19, online: online),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_compactPlayerName(player.name), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _OF.text, fontSize: compact ? 9.8 : 10.5, fontWeight: FontWeight.w900, letterSpacing: -.12)),
                    const SizedBox(height: 2),
                    Text('№${player.number ?? index + 1} · ${mapActive ? 'открыт справа' : (online ? 'online' : (_running ? 'ждём данные' : 'готов'))}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: mapActive ? _OF.green : (online ? _OF.green : _OF.muted2), fontSize: compact ? 7.8 : 8.4, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              _NoHoverTap(
                onTap: () => _openPlayerOnSidePanel(player, mode: 'map'),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  width: compact ? 24 : 26,
                  height: compact ? 24 : 26,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: Colors.transparent),
                  child: Icon(mapActive ? Icons.map_rounded : Icons.map_outlined, color: mapActive ? _OF.green : _OF.muted2, size: 14),
                ),
              ),
              const SizedBox(width: 5),
              _NoHoverTap(
                onTap: () => _removeMonitorPlayer(player),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  width: compact ? 24 : 26,
                  height: compact ? 24 : 26,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: Colors.transparent),
                  child: const Icon(Icons.close_rounded, color: _OF.muted2, size: 14),
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 5 : 6),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _playerMonitorStatsBody(
                distance: distance,
                speed: speed,
                maxSpeed: maxSpeed,
                load: load,
                sprint: sprint,
                heartRate: heartRate,
                points: points,
                signalLabel: signalLabel,
                signalColor: signalColor,
                compact: compact,
              ),
            ),
          ),
        ],
      ),
    ),
  ),
);
}

Widget _playerMonitorStatsBody({required double distance, required double speed, required double maxSpeed, required double load, required double sprint, required HeartRateSample? heartRate, required int points, required String signalLabel, required Color signalColor, required bool compact}) {
final mark = _loadMarkLabel(load, heartRateBpm: heartRate?.bpm);
final markColor = _loadMarkColor(load, heartRateBpm: heartRate?.bpm);
return Column(
  key: const ValueKey<String>('monitor_stats'),
  children: [
    Row(
      children: [
        Expanded(child: _monitorMetricTile('Дист.', '${distance.toStringAsFixed(0)} м', active: distance > 0, compact: compact)),
        const SizedBox(width: 5),
        Expanded(child: _monitorMetricTile('Скор.', speed.toStringAsFixed(1), active: speed > 0, compact: compact)),
        const SizedBox(width: 5),
        Expanded(child: _monitorMetricTile('HR', heartRate == null ? '—' : '${heartRate.bpm}', active: heartRate != null, compact: compact)),
      ],
    ),
    SizedBox(height: compact ? 5 : 6),
    Row(
      children: [
        Expanded(child: _monitorMetricTile('Load', load.toStringAsFixed(0), active: load > 0, compact: compact)),
        const SizedBox(width: 5),
        Expanded(child: _monitorMetricTile('Max', maxSpeed.toStringAsFixed(1), active: maxSpeed > 0, compact: compact)),
        const SizedBox(width: 5),
        Expanded(child: _monitorMetricTile('SPR', sprint.toStringAsFixed(0), active: sprint > 0, compact: compact)),
      ],
    ),
    SizedBox(height: compact ? 5 : 6),
    Row(
      children: [
        Expanded(
          flex: 3,
          child: Container(
            height: compact ? 20 : 22,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(color: markColor.withOpacity(.08), borderRadius: BorderRadius.circular(_OF.tabletInnerRadius), border: Border.all(color: markColor.withOpacity(.08))),
            alignment: Alignment.centerLeft,
            child: Text(mark, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: markColor, fontSize: compact ? 7.4 : 8.0, fontWeight: FontWeight.w900)),
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          flex: 2,
          child: Container(
            height: compact ? 20 : 22,
            padding: const EdgeInsets.symmetric(horizontal: 5),
            decoration: BoxDecoration(color: signalColor.withOpacity(.07), borderRadius: BorderRadius.circular(_OF.tabletInnerRadius), border: Border.all(color: signalColor.withOpacity(.08))),
            alignment: Alignment.center,
            child: Text(signalLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: signalColor, fontSize: compact ? 7.1 : 7.6, fontWeight: FontWeight.w900)),
          ),
        ),
        const SizedBox(width: 5),
        Container(
          height: compact ? 20 : 22,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(_OF.tabletInnerRadius)),
          alignment: Alignment.center,
          child: Text('$points тчк', style: TextStyle(color: _OF.muted2, fontSize: compact ? 7.3 : 7.8, fontWeight: FontWeight.w800)),
        ),
      ],
    ),
  ],
);
}

Widget _playerMonitorMapBody({required TrackerPlayerOption player, required _RuntimeTrack? track, required double distance, required double speed, required double load, required HeartRateSample? heartRate, required int points, required bool compact}) {
final hasTrack = track != null && track.points.isNotEmpty;
final tracks = hasTrack ? <_RuntimeTrack>[track] : const <_RuntimeTrack>[];
final markColor = _loadMarkColor(load, heartRateBpm: heartRate?.bpm);
return Column(
  key: ValueKey<String>('monitor_map_${player.id}'),
  children: [
    SizedBox(
      height: compact ? 23 : 25,
      child: Row(
        children: [
          Expanded(child: _monitorTinyPill(Icons.route_rounded, '${distance.toStringAsFixed(0)} м', active: distance > 0, compact: compact)),
          const SizedBox(width: 5),
          Expanded(child: _monitorTinyPill(Icons.speed_rounded, speed.toStringAsFixed(1), active: speed > 0, compact: compact)),
          const SizedBox(width: 5),
          Expanded(child: _monitorTinyPill(Icons.bolt_rounded, load.toStringAsFixed(0), active: load > 0, color: markColor, compact: compact)),
          const SizedBox(width: 5),
          Expanded(child: _monitorTinyPill(Icons.location_on_rounded, '$points', active: points > 0, compact: compact)),
        ],
      ),
    ),
    const SizedBox(height: 6),
    Expanded(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_OF.tabletInnerRadius),
        child: DecoratedBox(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(_OF.tabletInnerRadius)),
          child: CustomPaint(
            painter: _RuntimeFieldPainter(
              field: widget.selectedField,
              tracks: tracks,
              showVectors: false,
              showHeatmap: true,
              showTrace: true,
              showLabels: false,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    ),
  ],
);
}

Widget _monitorTinyPill(IconData icon, String value, {required bool active, required bool compact, Color? color}) {
final c = color ?? _OF.green;
return Container(
  height: compact ? 22 : 24,
  padding: EdgeInsets.symmetric(horizontal: compact ? 5 : 6),
  decoration: const BoxDecoration(color: Colors.transparent),
  child: Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(icon, size: compact ? 10 : 11, color: active ? c : _OF.muted2),
      const SizedBox(width: 3),
      Flexible(child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: active ? _OF.text : _OF.muted2, fontSize: compact ? 7.8 : 8.4, fontWeight: FontWeight.w900))),
    ],
  ),
);
}

Widget _monitorMetricTile(String label, String value, {required bool active, required bool compact}) {
return Container(
  padding: EdgeInsets.symmetric(horizontal: compact ? 5 : 6, vertical: compact ? 4 : 5),
  decoration: const BoxDecoration(color: Colors.transparent),
  child: Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _OF.muted2, fontSize: compact ? 7.2 : 7.8, fontWeight: FontWeight.w800, height: 1.0)),
      const SizedBox(height: 1),
      Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: active ? _OF.text : _OF.muted2, fontSize: compact ? 9.5 : 10.4, fontWeight: FontWeight.w900, height: 1.0)),
    ],
  ),
);
}

Widget _tabletPlayersDataPanel(int online, int active) {
return Column(
  children: [
    _tabletActivityBanner(dense: true),
    _ofHorizontalDivider(),
    SizedBox(
      height: 190,
      child: LayoutBuilder(
        builder: (context, c) => _teamLiveCommandCenter(compact: c.maxWidth < 620),
      ),
    ),
    _ofHorizontalDivider(),
    Expanded(
      child: LayoutBuilder(
        builder: (context, c) => _wholeTeamTablePanel(compact: c.maxWidth < 560),
      ),
    ),
  ],
);
}

Widget _tabletInfoToggleBar(int online, int active) {
  return Material(
    color: Colors.transparent,
    child: _NoHoverTap(
      onTap: () => setState(() => _bottomOperatorExpanded = !_bottomOperatorExpanded),
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            Icon(_bottomOperatorExpanded ? Icons.expand_more_rounded : Icons.chevron_right_rounded, size: 17, color: _OF.graphite),
            const SizedBox(width: 6),
            const Text('Оператор / трекер', style: TextStyle(color: _OF.text, fontSize: 11.2, fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            Text('$online/$active онлайн', style: const TextStyle(color: _OF.muted2, fontSize: 10.4, fontWeight: FontWeight.w600)),
            const Spacer(),
            Text(_bottomOperatorExpanded ? 'Скрыть' : 'Показать', style: const TextStyle(color: _OF.green, fontSize: 9.6, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    ),
  );
}

Widget _phoneOpenFieldLayout(int online, int active) {
final mediaPadding = MediaQuery.of(context).padding;
final topGap = mediaPadding.top > 0 ? 8.0 : 6.0;
final bottomDockSpace = 118.0 + mediaPadding.bottom;
return Container(
  // На мобильном Live фон должен совпадать с фоном рабочей области,
  // иначе белый экран выглядит как отдельный прямоугольник внутри CMR.
  color: _OF.bg,
  child: ListView(
    physics: const BouncingScrollPhysics(),
    padding: EdgeInsets.fromLTRB(
      _OF.mobilePagePadding,
      topGap,
      _OF.mobilePagePadding,
      bottomDockSpace,
    ),
    children: [
      _phoneLiveHeroCard(online, active),
      const SizedBox(height: 8),
      _phoneSelectedPlayerLiveCard(online, active),
      const SizedBox(height: 8),
      _phoneLiveModalDock(online, active),
      const SizedBox(height: 8),
      _phoneFieldPreviewCard(online, active),
      const SizedBox(height: 8),
      _phoneLiveLoadPreviewCard(),
      const SizedBox(height: 8),
      _phonePlayersCompactSection(online, active),
    ],
  ),
);
}

Widget _phoneLiveHeroCard(int online, int active) {
final trackerReady = widget.ble.commandChannelReady || widget.ble.connectedInfo != null;
final hasPolar = widget.heartRateConnectedCount > 0 || _hasTeamHeartRateOnline;
final gpsReady = _lastGpsAt != null && DateTime.now().difference(_lastGpsAt!).inSeconds < 8;
final fieldReady = !_activity.requiresField || widget.selectedField?.hasCalibration == true;
final fieldLabel = _activity.requiresField ? (widget.selectedField?.title ?? 'Поле не выбрано') : _activity.shortTitle;
final statusText = _paused ? 'Пауза' : (_running ? 'Live идёт' : 'Готово к старту');
final canStart = !_starting && !_running && fieldReady && (trackerReady || hasPolar || _mode == TrackerLiveSourceMode.heartRateOnly);
return Container(
  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
  decoration: _phoneLiveCardDecoration(radius: _OF.mobileCardRadius),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: _paused ? _OF.orange : (_running ? _OF.green : _OF.muted2), shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text('$statusText · ${widget.teamName}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _OF.text, fontSize: 11.7, fontWeight: FontWeight.w600, letterSpacing: -.12)),
          ),
          _phoneIconOnlyButton(Icons.more_horiz_rounded, () => _openPhoneMoreActionsSheet(online, active)),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            flex: 5,
            child: SizedBox(
              height: 56,
              child: FilledButton.icon(
                onPressed: _starting ? null : (_paused ? _resumeLiveCollection : (_running ? _stopLive : _startLive)),
                style: FilledButton.styleFrom(
                  backgroundColor: _paused ? _OF.green : (_running ? _OF.red : _OF.green),
                  disabledBackgroundColor: canStart ? _OF.green.withOpacity(.45) : _OF.header,
                  foregroundColor: Colors.white,
                  disabledForegroundColor: _OF.muted2,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                ),
                icon: Icon(_paused ? Icons.play_arrow_rounded : (_running ? Icons.stop_rounded : Icons.play_arrow_rounded), size: 22),
                label: Text(_starting ? 'Запуск...' : (_paused ? 'Продолжить' : (_running ? 'Стоп Live' : 'Старт Live')), style: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.w700, letterSpacing: 0)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: _phoneHeroStatusTile(icon: _activity.icon, label: fieldLabel, active: fieldReady, onTap: _openActivityChooser),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(child: _phoneHeroMiniStat(Icons.timer_rounded, _durationText(), _running && !_paused)),
          const SizedBox(width: 7),
          Expanded(child: _phoneHeroMiniStat(Icons.groups_rounded, '$online/$active', online > 0)),
          const SizedBox(width: 7),
          Expanded(child: _phoneHeroMiniStat(Icons.gps_fixed_rounded, gpsReady ? 'GPS' : 'GPS —', gpsReady)),
          const SizedBox(width: 7),
          Expanded(child: _phoneHeroMiniStat(Icons.monitor_heart_rounded, hasPolar ? 'HR ${widget.heartRateConnectedCount}' : 'HR —', hasPolar)),
        ],
      ),
    ],
  ),
);
}

Widget _phoneSelectedPlayerLiveCard(int online, int active) {
final player = widget.selectedPlayer;
final local = player == null ? null : _localTrackForPlayer(player.id);
final session = player == null ? null : _sessionForPlayer(player.id);
final heartRate = player == null ? null : _heartRateForPlayerId(player.id);
final distance = math.max(session?.totalDistanceM ?? 0.0, local?.totalDistanceM ?? 0.0);
final speed = math.max(session?.speedKmh ?? 0.0, local?.speedKmh ?? 0.0);
final maxSpeed = math.max(session?.maxSpeedKmh ?? 0.0, local?.maxSpeedKmh ?? 0.0);
final load = math.max(session?.loadScore ?? 0.0, local?.loadScore ?? 0.0);
final onlinePlayer = player != null && (_isPlayerOnlineLive(player.id) || heartRate != null || (local?.points.isNotEmpty ?? false));
final fieldLabel = _activity.requiresField ? (widget.selectedField?.title ?? 'Поле не выбрано') : _activity.shortTitle;
return Container(
  padding: const EdgeInsets.fromLTRB(12, 12, 12, 11),
  decoration: _phoneLiveCardDecoration(radius: _OF.mobileCardRadius),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          _playerAvatarCircle(player: player, radius: 24, online: onlinePlayer),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(player?.name ?? 'Выберите игрока', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _OF.text, fontSize: 13.6, fontWeight: FontWeight.w700, letterSpacing: -.25)),
                const SizedBox(height: 2),
                Text(player == null ? 'откройте список игроков для контроля Live' : '№${player.number ?? '—'} · $fieldLabel · ${onlinePlayer ? 'online' : (_running ? 'ждём данные' : 'готов к старту')}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: onlinePlayer ? _OF.green : _OF.muted2, fontSize: 11.0, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          _phoneStatusPill(onlinePlayer ? 'ON' : (_running ? 'WAIT' : 'OFF'), onlinePlayer ? _OF.green : (_running ? _OF.orange : _OF.muted2)),
          const SizedBox(width: 6),
          _phoneIconOnlyButton(Icons.chevron_right_rounded, player == null ? () => _openPhoneLiveSheet(_LiveMobileSheetTab.players, online, active) : () => _selectPlayerForAnalytics(player)),
        ],
      ),
      const SizedBox(height: 11),
      Row(
        children: [
          Expanded(child: _phoneMetricBox('Дистанция', '${distance.toStringAsFixed(0)} м')),
          const SizedBox(width: 7),
          Expanded(child: _phoneMetricBox('Скорость', '${speed.toStringAsFixed(1)}')),
          const SizedBox(width: 7),
          Expanded(child: _phoneMetricBox('Пульс', heartRate == null ? '—' : '${heartRate.bpm}')),
          const SizedBox(width: 7),
          Expanded(child: _phoneMetricBox('Load', load.toStringAsFixed(0))),
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(child: _phoneSmallInfoLine(Icons.trending_up_rounded, 'Max ${maxSpeed.toStringAsFixed(1)} км/ч')),
          const SizedBox(width: 8),
          Expanded(child: _phoneSmallInfoLine(Icons.sensors_rounded, widget.ble.commandChannelReady ? 'Трекер online' : 'Трекер offline')),
        ],
      ),
    ],
  ),
);
}

Widget _phoneLiveModalDock(int online, int active) {
return Row(
  children: [
    Expanded(child: _phoneQuickModalButton(icon: Icons.groups_rounded, title: 'Игроки', subtitle: '$online/$active online', onTap: () => _openPhoneLiveSheet(_LiveMobileSheetTab.players, online, active))),
    const SizedBox(width: 8),
    Expanded(child: _phoneQuickModalButton(icon: Icons.map_rounded, title: 'Карта', subtitle: _displayPoints > 0 ? '$_displayPoints точек' : 'ждём GPS', onTap: () => _openPhoneLiveSheet(_LiveMobileSheetTab.field, online, active))),
    const SizedBox(width: 8),
    Expanded(child: _phoneQuickModalButton(icon: Icons.bar_chart_rounded, title: 'Анализ', subtitle: 'сводка', onTap: _openPhoneTeamAnalysisSheet, accent: true)),
  ],
);
}

Widget _phoneLiveLoadPreviewCard() {
final samples = _teamLoadTimelineForPaint();
final hasData = samples.any((v) => v.avgLoad > 0 || v.maxLoad > 0);
final maxLoad = hasData ? math.max(1.0, samples.map((s) => s.maxLoad).fold<double>(0, (m, v) => math.max(m, v).toDouble())).toDouble() : 1.0;
final maxElapsed = math.max(60, samples.map((s) => s.elapsedSec).fold<int>(0, (m, v) => math.max(m, v).toInt())).toInt();
return _NoHoverTap(
  onTap: _openPhoneTeamAnalysisSheet,
  borderRadius: BorderRadius.circular(_OF.mobileCardRadius),
  child: Container(
    padding: const EdgeInsets.fromLTRB(12, 11, 12, 10),
    decoration: _phoneLiveCardDecoration(radius: _OF.mobileCardRadius),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: Text('Нагрузка команды', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _OF.text, fontSize: 13.2, fontWeight: FontWeight.w700, letterSpacing: -.24))),
            _phoneStatusPill('max ${maxLoad.toStringAsFixed(maxLoad < 10 ? 1 : 0)}', _OF.green),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded, color: _OF.muted2, size: 20),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 74,
          child: hasData
              ? CustomPaint(painter: _TeamLoadTimePainter(samples: samples, maxValue: maxLoad, maxElapsedSec: maxElapsed, showAxis: false), child: const SizedBox.expand())
              : Center(child: Text(_running ? 'Ждём первые значения нагрузки' : 'После старта появится график нагрузки', textAlign: TextAlign.center, style: const TextStyle(color: _OF.muted2, fontSize: 11.0, fontWeight: FontWeight.w700))),
        ),
      ],
    ),
  ),
);
}

BoxDecoration _phoneLiveCardDecoration({double radius = 18}) {
return BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(radius),
  
);
}

Widget _phoneHeroStatusTile({
required IconData icon,
required String label,
required bool active,
required VoidCallback onTap,
}) {
return _NoHoverTap(
  onTap: onTap,
  borderRadius: BorderRadius.circular(8),
  child: Container(
    height: 46,
    padding: const EdgeInsets.symmetric(horizontal: 8),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      border: Border(
        bottom: BorderSide(
          color: active ? _OF.green : _OF.orange,
          width: 2,
        ),
      ),
    ),
    child: Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: active ? _OF.green : _OF.orange,
        fontSize: 11.6,
        fontWeight: FontWeight.w700,
      ),
    ),
  ),
);
}

Widget _phoneHeroMiniStat(IconData icon, String label, bool active) {
return Container(
  height: 34,
  padding: const EdgeInsets.symmetric(horizontal: 4),
  alignment: Alignment.center,
  child: Text(
    label,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(
      color: active ? _OF.text : _OF.muted2,
      fontSize: 10.4,
      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
    ),
  ),
);
}

Widget _phoneQuickModalButton({
required IconData icon,
required String title,
required String subtitle,
required VoidCallback onTap,
bool accent = false,
}) {
return _NoHoverTap(
  onTap: onTap,
  borderRadius: BorderRadius.circular(8),
  child: Container(
    height: 58,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
    decoration: BoxDecoration(
      color: accent ? _OF.greenSoft : Colors.transparent,
      border: Border(
        bottom: BorderSide(
          color: accent ? _OF.green : Colors.transparent,
          width: 2,
        ),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: accent ? _OF.green : _OF.text,
            fontSize: 11.4,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _OF.muted2,
            fontSize: 11.0,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  ),
);
}

Widget _phoneIconOnlyButton(IconData icon, VoidCallback onTap) {
return _NoHoverTap(
  onTap: onTap,
  borderRadius: BorderRadius.circular(999),
  child: Container(
    width: 34,
    height: 34,
    alignment: Alignment.center,
    decoration: const BoxDecoration(color: Colors.transparent),
    child: Icon(icon, color: _OF.graphite, size: 18),
  ),
);
}

Widget _phoneSmallInfoLine(IconData icon, String text) {
return Container(
  height: 30,
  padding: const EdgeInsets.symmetric(horizontal: 8),
  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(_OF.mobileChipRadius)),
  child: Row(
    children: [
      Icon(icon, color: _OF.muted2, size: 14),
      const SizedBox(width: 5),
      Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _OF.muted2, fontSize: 11.2, fontWeight: FontWeight.w700))),
    ],
  ),
);
}

Widget _phoneFieldPreviewCard(int online, int active) {
final isFieldMode = _activity.requiresField;
final fieldTitle = isFieldMode ? (widget.selectedField?.title ?? 'Поле не выбрано') : _activity.shortTitle;
final hasPoints = _displayPoints > 0;
final previewHeight = isFieldMode ? 232.0 : 206.0;
return Container(
  padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
  decoration: _phoneLiveCardDecoration(radius: _OF.mobileCardRadius),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isFieldMode ? 'Мини-карта' : 'Активность', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _OF.text, fontSize: 13.4, fontWeight: FontWeight.w700, letterSpacing: -.25)),
                const SizedBox(height: 1),
                Text('$fieldTitle · ${hasPoints ? 'точек $_displayPoints' : 'ждём GPS'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _OF.muted2, fontSize: 11.2, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          _phoneIconOnlyButton(Icons.open_in_full_rounded, () => _openPhoneLiveSheet(_LiveMobileSheetTab.field, online, active)),
        ],
      ),
      const SizedBox(height: 8),
      SizedBox(height: previewHeight, child: _phoneMiniFieldCanvas()),
      if (isFieldMode) ...[
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _phoneLayerToggle('Трек', _showTrace, () => setState(() => _showTrace = !_showTrace))),
            Expanded(child: _phoneLayerToggle('Тепло', _showHeatmap, () => setState(() => _showHeatmap = !_showHeatmap))),
            Expanded(child: _phoneLayerToggle('Метки', _showLabels, () => setState(() => _showLabels = !_showLabels))),
          ],
        ),
      ],
    ],
  ),
);
}

Widget _phoneMiniFieldCanvas() {
if (!_activity.requiresField) return _fieldCard();
return ClipRRect(
  borderRadius: BorderRadius.circular(_OF.mobileInnerRadius),
  child: DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(_OF.mobileInnerRadius),
      
    ),
    child: CustomPaint(
      painter: _RuntimeFieldPainter(
        field: widget.selectedField,
        tracks: _tracks.values.toList(),
        showVectors: _showVectors,
        showHeatmap: _showHeatmap,
        showTrace: _showTrace,
        showLabels: _showLabels,
      ),
      child: const SizedBox.expand(),
    ),
  ),
);
}

Widget _phoneLayerToggle(String label, bool active, VoidCallback onTap) {
return _NoHoverTap(
  onTap: onTap,
  borderRadius: BorderRadius.circular(8),
  child: SizedBox(
    height: 36,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: active ? 5 : 0,
          height: active ? 5 : 0,
          margin: EdgeInsets.only(right: active ? 6 : 0),
          decoration: const BoxDecoration(color: _OF.green, shape: BoxShape.circle),
        ),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: active ? _OF.green : _OF.muted2, fontSize: 12.0, fontWeight: FontWeight.w700, letterSpacing: -.04)),
      ],
    ),
  ),
);
}

Widget _phoneTinyActionButton({required String label, required IconData icon, required VoidCallback onTap}) {
return Tooltip(
  message: label,
  child: Material(
    color: Colors.white,
    shape: const CircleBorder(),
    child: _NoHoverTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          
        ),
        child: Icon(icon, size: 15, color: _OF.graphite),
      ),
    ),
  ),
);
}

Widget _phoneSelectPlayerPrompt(int online, int active) {
return Material(
  color: Colors.white,
  borderRadius: BorderRadius.circular(14),
  child: _NoHoverTap(
    onTap: () => _openPhoneLiveSheet(_LiveMobileSheetTab.players, online, active),
    borderRadius: BorderRadius.circular(14),
    child: Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: _OF.greenSoft, borderRadius: BorderRadius.circular(11), border: Border.all(color: _OF.greenBorder)),
            child: const Icon(Icons.person_search_rounded, color: _OF.green, size: 19),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Выберите игрока', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _OF.text, fontSize: 13.0, fontWeight: FontWeight.w700)),
                SizedBox(height: 2),
                Text('после выбора откроется анализ и live-метрики', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _OF.muted2, fontSize: 11.0, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: _OF.muted2, size: 22),
        ],
      ),
    ),
  ),
);
}

Widget _phoneLiveSummaryCard(int online, int active) {
final track = _mainTrack;
final playerName = widget.selectedPlayer?.name ?? 'Игрок не выбран';
final trackerReady = widget.ble.commandChannelReady;
final gpsReady = _lastGpsAt != null || (track?.points.isNotEmpty ?? false);
final fieldLabel = _activity.requiresField ? (widget.selectedField?.title ?? 'поле не выбрано') : 'без поля';
final liveLine = _running ? 'Live · $online/$active онлайн' : 'Старт · $online/$active онлайн';
final selectedLocal = widget.selectedPlayer == null ? null : _localTrackForPlayer(widget.selectedPlayer!.id);
final selectedSession = widget.selectedPlayer == null ? null : _sessionForPlayer(widget.selectedPlayer!.id);
final selectedLoad = math.max(selectedSession?.loadScore ?? 0.0, selectedLocal?.loadScore ?? 0.0);
final selectedHeartRate = widget.selectedPlayer == null ? null : _heartRateForPlayerId(widget.selectedPlayer!.id);
return Container(
  padding: const EdgeInsets.all(7),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(4),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          _playerAvatarCircle(player: widget.selectedPlayer, radius: 13, online: true),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(playerName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _OF.text, fontSize: 11.8, fontWeight: FontWeight.w700)),
                Text('${_activity.shortTitle} · $fieldLabel · $liveLine', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _OF.muted2, fontSize: 10.4, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          _phoneStatusPill(trackerReady ? 'BLE' : 'OFF', trackerReady ? _OF.green : _OF.red),
          const SizedBox(width: 6),
          _phoneStatusPill(gpsReady ? 'GPS' : 'GPS —', gpsReady ? _OF.green : _OF.orange),
        ],
      ),
      const SizedBox(height: 6),
      Row(
        children: [
          Expanded(child: _phoneMetricBox('Дист.', '${_displayDistanceM.toStringAsFixed(0)} м')),
          const SizedBox(width: 6),
          Expanded(child: _phoneMetricBox('Скор.', '${_displaySpeedKmh.toStringAsFixed(1)}')),
          const SizedBox(width: 6),
          Expanded(child: _phoneMetricBox('Пульс', selectedHeartRate == null ? '—' : '${selectedHeartRate.bpm}')),
          const SizedBox(width: 6),
          Expanded(child: _phoneMetricBox('Load', selectedLoad.toStringAsFixed(0))),
        ],
      ),
    ],
  ),
);
}


Widget _phoneSelectedPlayerAnalysisPanel(TrackerPlayerOption player) {
final local = _localTrackForPlayer(player.id);
final session = _sessionForPlayer(player.id);
final distance = math.max(session?.totalDistanceM ?? 0.0, local?.totalDistanceM ?? 0.0);
final speed = math.max(session?.speedKmh ?? 0.0, local?.speedKmh ?? 0.0);
final load = math.max(session?.loadScore ?? 0.0, local?.loadScore ?? 0.0);
final heartRate = _heartRateForPlayerId(player.id);
return Material(
  color: Colors.white,
  borderRadius: BorderRadius.circular(14),
  child: _NoHoverTap(
    onTap: () => _selectPlayerForAnalytics(player),
    borderRadius: BorderRadius.circular(14),
    child: Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.zero,
        
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: _OF.greenSoft, borderRadius: BorderRadius.circular(11), border: Border.all(color: _OF.greenBorder)),
                child: const Icon(Icons.analytics_rounded, color: _OF.green, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Анализ игрока', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _OF.text, fontSize: 12.0, fontWeight: FontWeight.w700, letterSpacing: -.15)),
                    const SizedBox(height: 2),
                    Text(player.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _OF.muted2, fontSize: 11.0, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message: 'Открыть анализ игрока',
                child: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _OF.green,
                    shape: BoxShape.circle,
                    boxShadow: null,
                  ),
                  child: const Icon(Icons.analytics_rounded, size: 17, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _phoneAnalysisMetric('Дист.', '${distance.toStringAsFixed(0)} м')),
              const SizedBox(width: 6),
              Expanded(child: _phoneAnalysisMetric('Скор.', '${speed.toStringAsFixed(1)}')),
              const SizedBox(width: 6),
              Expanded(child: _phoneAnalysisMetric('Пульс', heartRate == null ? '—' : '${heartRate.bpm}')),
              const SizedBox(width: 6),
              Expanded(child: _phoneAnalysisMetric('Load', load.toStringAsFixed(0))),
            ],
          ),
        ],
      ),
    ),
  ),
);
}

Future<void> _openPhonePlayerAnalysisSheet(TrackerPlayerOption player) async {
if (!mounted) return;
await showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  barrierColor: Colors.black.withOpacity(.26),
  builder: (sheetContext) {
    return DraggableScrollableSheet(
      initialChildSize: .56,
      minChildSize: .36,
      maxChildSize: .88,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: ClipRRect(
            borderRadius: BorderRadius.vertical(top: Radius.circular(_OF.sheetRadius)),
            child: Material(
              color: Colors.white,
              child: SafeArea(
                top: false,
                child: _phonePlayerAnalysisSheetContent(player, scrollController, () => Navigator.of(sheetContext).pop()),
              ),
            ),
          ),
        );
      },
    );
  },
);
}

Widget _phonePlayerAnalysisSheetContent(TrackerPlayerOption player, ScrollController scrollController, VoidCallback onClose) {
final local = _localTrackForPlayer(player.id);
final session = _sessionForPlayer(player.id);
final distance = math.max(session?.totalDistanceM ?? 0.0, local?.totalDistanceM ?? 0.0);
final speed = math.max(session?.speedKmh ?? 0.0, local?.speedKmh ?? 0.0);
final maxSpeed = math.max(session?.maxSpeedKmh ?? 0.0, local?.maxSpeedKmh ?? 0.0);
final load = math.max(session?.loadScore ?? 0.0, local?.loadScore ?? 0.0);
final hir = math.max(session?.hirDistanceM ?? 0.0, local?.hirDistanceM ?? 0.0);
final vhir = math.max(session?.vhirDistanceM ?? 0.0, local?.vhirDistanceM ?? 0.0);
final sprint = math.max(session?.sprintDistanceM ?? 0.0, local?.sprintDistanceM ?? 0.0);
final heartRate = _heartRateForPlayerId(player.id);
final maxBand = math.max(1.0, math.max(hir, math.max(vhir, sprint)));
final hasData = distance > 0 || speed > 0 || load > 0 || heartRate != null;
final liveState = _isPlayerOnlineLive(player.id) ? 'online' : (_running ? 'ждём данные' : 'готов к старту');
return ListView(
  controller: scrollController,
  physics: const BouncingScrollPhysics(),
  padding: const EdgeInsets.fromLTRB(16, 10, 16, 22),
  children: [
    Center(
      child: Container(
        width: 46,
        height: 4,
        decoration: BoxDecoration(color: _OF.lineStrong, borderRadius: BorderRadius.circular(999)),
      ),
    ),
    const SizedBox(height: 8),
    Row(
      children: [
        _playerAvatarCircle(player: player, radius: 24, online: _isPlayerOnlineLive(player.id)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(player.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _OF.text, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -.35)),
              const SizedBox(height: 3),
              Text('${_activity.shortTitle} · $liveState · ${_lastGpsAt == null ? 'GPS —' : 'GPS активен'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _OF.muted2, fontSize: 11.2, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        _phoneSheetCloseButton(onClose),
      ],
    ),
    const SizedBox(height: 8),
    GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 2.45,
      children: [
        _phoneAnalysisMetric('Дистанция', '${distance.toStringAsFixed(0)} м'),
        _phoneAnalysisMetric('Скорость', '${speed.toStringAsFixed(1)} км/ч'),
        _phoneAnalysisMetric('Макс. скорость', '${maxSpeed.toStringAsFixed(1)} км/ч'),
        _phoneAnalysisMetric('Пульс', heartRate == null ? '—' : '${heartRate.bpm} bpm'),
        _phoneAnalysisMetric('Load', load.toStringAsFixed(0)),
        _phoneAnalysisMetric('Точки', '${local?.points.length ?? 0}'),
      ],
    ),
    const SizedBox(height: 8),
    _phoneAnalysisSection(
      title: 'Зоны скорости',
      icon: Icons.speed_rounded,
      child: hasData
          ? Column(
              children: [
                _phoneAnalysisBand('HIR', hir, maxBand, _OF.orange),
                const SizedBox(height: 8),
                _phoneAnalysisBand('VHIR', vhir, maxBand, _OF.cyan),
                const SizedBox(height: 8),
                _phoneAnalysisBand('SPR', sprint, maxBand, _OF.red),
              ],
            )
          : _phoneAnalysisEmpty('После GPS здесь появятся HIR/VHIR/SPR, спринты и нагрузка.'),
    ),
    const SizedBox(height: 8),
    _phoneAnalysisSection(
      title: 'Нагрузка и рекомендация',
      icon: Icons.bolt_rounded,
      child: Text(
        _combinedLiveRecommendation(track: local, sample: heartRate),
        style: const TextStyle(color: _OF.muted, fontSize: 11.2, fontWeight: FontWeight.w700, height: 1.35),
      ),
    ),
    const SizedBox(height: 8),
    SizedBox(
      height: 48,
      child: FilledButton.icon(
        onPressed: () {
          onClose();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) unawaited(_openPlayerLiveDetails(player));
          });
        },
        style: FilledButton.styleFrom(
          backgroundColor: _OF.green,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_OF.mobileButtonRadius)),
        ),
        icon: const Icon(Icons.analytics_rounded, size: 18),
        label: const Text('Открыть полный анализ', style: TextStyle(fontSize: 11.4, fontWeight: FontWeight.w700)),
      ),
    ),
  ],
);
}

Widget _phoneAnalysisSection({required String title, required IconData icon, required Widget child}) {
return Container(
  padding: const EdgeInsets.all(8),
  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(icon, color: _OF.green, size: 16),
          const SizedBox(width: 7),
          Text(title, style: const TextStyle(color: _OF.text, fontSize: 11.4, fontWeight: FontWeight.w700)),
        ],
      ),
      const SizedBox(height: 8),
      child,
    ],
  ),
);
}

Widget _phoneAnalysisEmpty(String text) {
return Container(
  width: double.infinity,
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
  child: Text(text, style: const TextStyle(color: _OF.muted2, fontSize: 10.4, fontWeight: FontWeight.w600, height: 1.3)),
);
}

Widget _phoneAnalysisMetric(String label, String value) {
return Container(
  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _OF.muted2, fontSize: 9.6, fontWeight: FontWeight.w700)),
      const SizedBox(height: 2),
      Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _OF.text, fontSize: 11.0, fontWeight: FontWeight.w700)),
    ],
  ),
);
}

Widget _phoneAnalysisBand(String label, double value, double max, Color color) {
return Row(
  children: [
    SizedBox(width: 34, child: Text(label, style: const TextStyle(color: _OF.text, fontSize: 9.6, fontWeight: FontWeight.w700))),
    Expanded(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: LinearProgressIndicator(
          value: (value / max).clamp(0.0, 1.0).toDouble(),
          minHeight: 6,
          backgroundColor: _OF.line,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ),
    ),
    const SizedBox(width: 6),
    SizedBox(width: 40, child: Text('${value.toStringAsFixed(0)} м', textAlign: TextAlign.right, style: const TextStyle(color: _OF.muted2, fontSize: 9.6, fontWeight: FontWeight.w700))),
  ],
);
}

Widget _phoneStatusPill(String label, Color color) {
return Container(
  height: 21,
  padding: const EdgeInsets.symmetric(horizontal: 6),
  alignment: Alignment.center,
  decoration: BoxDecoration(color: color.withOpacity(.08), borderRadius: BorderRadius.circular(4), border: Border.all(color: color.withOpacity(.22))),
  child: Text(label, style: TextStyle(color: color, fontSize: 10.4, fontWeight: FontWeight.w700)),
);
}

Widget _phoneMetricBox(String label, String value) {
return Padding(
  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: _OF.text,
          fontSize: 12.2,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: _OF.muted2,
          fontSize: 10.4,
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  ),
);
}


Widget _phoneLiveQuickActions(int online, int active) {
final playersCount = _livePlayerOptions().length;
final subtitle = _running
    ? '$online/$active онлайн · live-метрики обновляются'
    : '$playersCount игроков · нажмите развернуть для деталей';
return _NoHoverTap(
  onTap: () => _openPhoneLiveSheet(_LiveMobileSheetTab.players, online, active),
  borderRadius: BorderRadius.circular(14),
  child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
    child: Row(
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: _OF.greenSoft, shape: BoxShape.circle, border: Border.all(color: _OF.greenBorder)),
          child: const Icon(Icons.groups_rounded, size: 15, color: _OF.green),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Игроки и live-данные', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _OF.text, fontSize: 14.5, fontWeight: FontWeight.w700, letterSpacing: -.18)),
              const SizedBox(height: 2),
              Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _OF.muted2, fontSize: 11.2, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _phoneTextAction(
          icon: Icons.open_in_full_rounded,
          label: 'Развернуть',
          color: _OF.green,
          onTap: () => _openPhoneLiveSheet(_LiveMobileSheetTab.players, online, active),
        ),
      ],
    ),
  ),
);
}

Widget _phoneMenuDivider() {
return Container(width: 1, height: 18, margin: const EdgeInsets.symmetric(horizontal: 8), color: _OF.lineStrong);
}

Widget _phoneLiveActionChip({required IconData icon, required String title, required String subtitle, required VoidCallback onTap, double width = 0, bool primary = false}) {
return Material(
  color: Colors.transparent,
  child: _NoHoverTap(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: primary ? _OF.green : _OF.graphite),
          const SizedBox(width: 6),
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: primary ? _OF.green : _OF.text, fontSize: 11.0, fontWeight: FontWeight.w700, letterSpacing: -.12)),
          const SizedBox(width: 4),
          Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _OF.muted2, fontSize: 11.0, fontWeight: FontWeight.w700)),
        ],
      ),
    ),
  ),
);
}

Widget _phoneBottomLiveBar(int online, int active) {
final gpsReady = _lastGpsAt != null || (_mainTrack?.points.isNotEmpty ?? false);
return Container(
  height: 44,
  color: Colors.white,
  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
  child: Row(
    children: [
      Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: _running ? _OF.greenSoft : const Color(0xFFFDF2F2),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: _running ? _OF.greenBorder : _OF.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ofStatusDot(_running ? _OF.green : _OF.red),
            const SizedBox(width: 5),
            Text(_running ? 'LIVE' : 'ГОТОВО', style: TextStyle(color: _running ? _OF.green : _OF.text, fontSize: 9.6, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
      const SizedBox(width: 6),
      Expanded(child: _liveMiniChip(Icons.timer_rounded, _durationText(), active: _running && !_paused, tight: true)),
      const SizedBox(width: 5),
      SizedBox(width: 54, child: _liveMiniChip(Icons.groups_rounded, '$online/$active', active: online > 0, tight: true)),
      const SizedBox(width: 5),
      SizedBox(width: 54, child: _liveMiniChip(Icons.gps_fixed_rounded, gpsReady ? 'GPS' : 'GPS —', active: gpsReady, tight: true)),
    ],
  ),
);
}

Widget _phoneBottomIconButton(IconData icon, VoidCallback onTap) {
return Material(
  color: Colors.white,
  borderRadius: BorderRadius.circular(4),
  child: _NoHoverTap(
    onTap: onTap,
    borderRadius: BorderRadius.circular(4),
    child: Container(
      width: 34,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(4)),
      child: Icon(icon, size: 15, color: _OF.graphite),
    ),
  ),
);
}


Future<void> _openPhoneMoreActionsSheet(int online, int active) async {
if (!mounted) return;
await showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  barrierColor: Colors.black.withOpacity(.24),
  builder: (sheetContext) {
    final bottom = MediaQuery.of(sheetContext).padding.bottom;

    void closeThen(VoidCallback action) {
      Navigator.of(sheetContext).pop();
      Future<void>.delayed(const Duration(milliseconds: 120), () {
        if (!mounted) return;
        action();
      });
    }

    Widget item({
      required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap,
      bool primary = false,
      bool danger = false,
    }) {
      final color = danger ? _OF.red : (primary ? _OF.green : _OF.graphite);
      return _NoHoverTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 9, 9, 9),
          decoration: BoxDecoration(
            color: primary ? _OF.greenSoft : Colors.white,
            borderRadius: BorderRadius.zero,
            border: Border.all(color: primary ? _OF.greenBorder : _OF.line),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: color.withOpacity(.09), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: danger ? _OF.red : _OF.text, fontSize: 12.6, fontWeight: FontWeight.w700, letterSpacing: -.08)),
                    const SizedBox(height: 2),
                    Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _OF.muted2, fontSize: 10.4, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: primary ? _OF.green : _OF.muted2, size: 20),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(8, 8, 8, 8 + bottom),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_OF.sheetRadius),
          child: Material(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(width: 42, height: 4, decoration: BoxDecoration(color: _OF.lineStrong, borderRadius: BorderRadius.circular(999))),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(color: _OF.greenSoft, shape: BoxShape.circle, border: Border.all(color: _OF.greenBorder)),
                        child: const Icon(Icons.more_horiz_rounded, color: _OF.green, size: 19),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Меню Live', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _OF.text, fontSize: 14.0, fontWeight: FontWeight.w700, letterSpacing: -.12)),
                            SizedBox(height: 2),
                            Text('быстрые окна без перегруза экрана', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _OF.muted2, fontSize: 11.2, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      _phoneSheetCloseButton(() => Navigator.of(sheetContext).pop()),
                    ],
                  ),
                  const SizedBox(height: 8),
                  item(icon: Icons.groups_rounded, title: 'Игроки и live-данные', subtitle: '$online/$active онлайн · список и метрики', primary: true, onTap: () => closeThen(() => unawaited(_openPhoneLiveSheet(_LiveMobileSheetTab.players, online, active)))),
                  const SizedBox(height: 8),
                  item(icon: Icons.map_rounded, title: 'Мини-карта', subtitle: _displayPoints > 0 ? 'GPS-точек: $_displayPoints' : 'ожидаем GPS от трекера', onTap: () => closeThen(() => unawaited(_openPhoneLiveSheet(_LiveMobileSheetTab.field, online, active)))),
                  const SizedBox(height: 8),
                  item(icon: Icons.bar_chart_rounded, title: 'Анализ команды', subtitle: 'нагрузка, скорость, сводка', onTap: () => closeThen(() => unawaited(_openPhoneTeamAnalysisSheet()))),
                  const SizedBox(height: 8),
                  item(icon: Icons.sensors_rounded, title: 'Устройства и запись', subtitle: 'GPS, Polar, статус трекера', onTap: () => closeThen(() => unawaited(_openPhoneLiveSheet(_LiveMobileSheetTab.operator, online, active)))),
                  const SizedBox(height: 8),
                  item(icon: _activity.icon, title: 'Тип и поле тренировки', subtitle: _running ? 'смена доступна после остановки Live' : 'поле / кросс / зал', onTap: () => closeThen(() => unawaited(_openActivityChooser()))),
                  const SizedBox(height: 8),
                  item(icon: Icons.save_alt_rounded, title: 'Сохранить метрики', subtitle: 'ручной snapshot текущего Live', onTap: () => closeThen(() => unawaited(_saveMetricSnapshot(manual: true)))),
                  if (_running) ...[
                    const SizedBox(height: 8),
                    item(icon: Icons.stop_rounded, title: 'Остановить Live', subtitle: 'завершить запись и сохранить сессию', danger: true, onTap: () => closeThen(() => unawaited(_stopLive()))),
                  ],
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

Future<void> _openPhoneLiveSheet(_LiveMobileSheetTab initialTab, int online, int active) async {
if (!mounted) return;
var tab = initialTab;
_phoneLiveSheetVisible = true;
try {
await showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  builder: (sheetContext) {
    return StatefulBuilder(
      builder: (context, setSheetState) {
        return FractionallySizedBox(
          heightFactor: .74,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
              child: Material(
                color: Colors.white,
                child: SafeArea(
                  top: false,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 6, 8),
                        child: Row(
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(color: _OF.greenSoft, shape: BoxShape.circle, border: Border.all(color: _OF.greenBorder)),
                              child: Icon(_phoneSheetIcon(tab), color: _OF.green, size: 15),
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_phoneSheetTitle(tab), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _OF.text, fontSize: 13.4, fontWeight: FontWeight.w700, letterSpacing: -.18)),
                                  Text(_phoneSheetSubtitle(tab, online, active), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _OF.muted2, fontSize: 11.2, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                            _phoneSheetCloseButton(() => Navigator.of(sheetContext).pop()),
                          ],
                        ),
                      ),
                      _ofHorizontalDivider(),
                      Expanded(child: _phoneLiveSheetBody(tab, online, active, setSheetState)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  },
);
} finally {
  _phoneLiveSheetVisible = false;
}
}

Widget _phoneSheetTabs(_LiveMobileSheetTab selected, ValueChanged<_LiveMobileSheetTab> onSelect) {
return SizedBox(
  height: 40,
  child: Row(
    children: [
      Expanded(child: _phoneSheetTabButton('Команда', _LiveMobileSheetTab.team, selected, onSelect)),
      Expanded(child: _phoneSheetTabButton('Игроки', _LiveMobileSheetTab.players, selected, onSelect)),
      Expanded(child: _phoneSheetTabButton('Карта', _LiveMobileSheetTab.field, selected, onSelect)),
      Expanded(child: _phoneSheetTabButton('Связь', _LiveMobileSheetTab.operator, selected, onSelect)),
    ],
  ),
);
}

Widget _phoneSheetTabButton(String label, _LiveMobileSheetTab tab, _LiveMobileSheetTab selected, ValueChanged<_LiveMobileSheetTab> onSelect) {
final active = tab == selected;
return _NoHoverTap(
  onTap: () => onSelect(tab),
  borderRadius: BorderRadius.circular(8),
  child: Stack(
    alignment: Alignment.center,
    children: [
      Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: active ? _OF.green : _OF.muted2, fontSize: 11.3, fontWeight: FontWeight.w700, letterSpacing: -.02)),
      Positioned(
        bottom: 3,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: active ? 30 : 0,
          height: 2,
          decoration: BoxDecoration(color: _OF.green.withOpacity(.82), borderRadius: BorderRadius.circular(999)),
        ),
      ),
    ],
  ),
);
}

Widget _phoneLiveSheetBody(_LiveMobileSheetTab tab, int online, int active, StateSetter setSheetState) {
switch (tab) {
  case _LiveMobileSheetTab.team:
    return Column(
      children: [
        SizedBox(height: 142, child: _teamLiveCommandCenter(compact: true, phone: true)),
        _ofHorizontalDivider(),
        Expanded(child: _wholeTeamTablePanel(compact: true, phoneCards: true)),
      ],
    );
  case _LiveMobileSheetTab.players:
    return _wholeTeamTablePanel(compact: true, phoneCards: true);
  case _LiveMobileSheetTab.field:
    return Column(
      children: [
        _phoneFieldLayerBar(setSheetState),
        _ofHorizontalDivider(),
        Expanded(child: _fieldCard()),
      ],
    );
  case _LiveMobileSheetTab.operator:
    return _phoneOperatorSheetContent(online, active);
}
return const SizedBox.shrink();
}

Widget _phoneFieldLayerBar(StateSetter setSheetState) {
Widget chip(String label, bool active, VoidCallback toggle) {
  return Expanded(
    child: _NoHoverTap(
      onTap: () {
        toggle();
        setSheetState(() {});
      },
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 36,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: active ? 5 : 0,
              height: active ? 5 : 0,
              margin: EdgeInsets.only(right: active ? 6 : 0),
              decoration: const BoxDecoration(color: _OF.green, shape: BoxShape.circle),
            ),
            Text(label, style: TextStyle(color: active ? _OF.green : _OF.graphite, fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    ),
  );
}
return Padding(
  padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
  child: Row(
    children: [
      chip('Трек', _showTrace, () => setState(() => _showTrace = !_showTrace)),
      chip('Тепло', _showHeatmap, () => setState(() => _showHeatmap = !_showHeatmap)),
      chip('Метки', _showLabels, () => setState(() => _showLabels = !_showLabels)),
    ],
  ),
);
}

Widget _phoneOperatorSheetContent(int online, int active) {
return ListView(
  physics: const ClampingScrollPhysics(),
  padding: const EdgeInsets.all(9),
  children: [
    _pipGroupPanel(online, active),
    const SizedBox(height: 8),
    _velocityBandsPanel(),
    const SizedBox(height: 8),
    _trackerDevicePanel(),
  ],
);
}

Widget _phoneSheetCloseButton(VoidCallback onTap) {
return _NoHoverTap(
  onTap: onTap,
  borderRadius: BorderRadius.circular(999),
  child: Container(
    width: 34,
    height: 34,
    alignment: Alignment.center,
    decoration: const BoxDecoration(color: Colors.transparent),
    child: const Icon(Icons.close_rounded, color: _OF.graphite, size: 18),
  ),
);
}

IconData _phoneSheetIcon(_LiveMobileSheetTab tab) {
switch (tab) {
  case _LiveMobileSheetTab.team:
    return Icons.dashboard_customize_rounded;
  case _LiveMobileSheetTab.players:
    return Icons.groups_rounded;
  case _LiveMobileSheetTab.field:
    return Icons.map_rounded;
  case _LiveMobileSheetTab.operator:
    return Icons.tune_rounded;
}
return Icons.dashboard_customize_rounded;
}

String _phoneSheetTitle(_LiveMobileSheetTab tab) {
switch (tab) {
  case _LiveMobileSheetTab.team:
    return 'Live центр команды';
  case _LiveMobileSheetTab.players:
    return 'Игроки и live-данные';
  case _LiveMobileSheetTab.field:
    return _activity.requiresField ? 'Поле / тактическая карта' : 'Маршрут активности';
  case _LiveMobileSheetTab.operator:
    return 'Устройства и запись';
}
return 'Live центр';
}

String _phoneSheetSubtitle(_LiveMobileSheetTab tab, int online, int active) {
switch (tab) {
  case _LiveMobileSheetTab.team:
    return '$online/$active онлайн · ${_durationText()}';
  case _LiveMobileSheetTab.players:
    return '${_livePlayerOptions().length} игроков · нажмите на игрока для деталей';
  case _LiveMobileSheetTab.field:
    return _activity.requiresField ? (widget.selectedField?.title ?? 'поле не выбрано') : '${_activity.title} · без поля';
  case _LiveMobileSheetTab.operator:
    return _running ? 'идёт запись · трекер, Polar, связь' : 'готово к старту · трекер, Polar, связь';
}
return '';
}

Future<void> _openMobileLiveBlockSheet(String title, IconData icon, Widget Function() builder) async {
if (!mounted) return;
await showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  builder: (sheetContext) {
    return FractionallySizedBox(
      heightFactor: .74,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          child: Material(
            color: Colors.white,
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  Container(
                    height: 52,
                    padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
                    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _OF.line))),
                    child: Row(
                      children: [
                        Container(width: 32, height: 32, decoration: BoxDecoration(color: _OF.greenSoft, borderRadius: BorderRadius.circular(6), border: Border.all(color: _OF.greenBorder)), child: Icon(icon, color: _OF.green, size: 17)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _OF.text, fontSize: 15, fontWeight: FontWeight.w700))),
                        _phoneSheetCloseButton(() => Navigator.of(sheetContext).pop()),
                      ],
                    ),
                  ),
                  Expanded(child: _buildMobileBlockSheetContent(builder)),
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

Widget _buildMobileBlockSheetContent(Widget Function() builder) {
_renderingFloatingLiveContent = true;
try {
  return builder();
} finally {
  _renderingFloatingLiveContent = false;
}
}

Widget _teamLiveCommandCenter({required bool compact, bool phone = false}) {
final loads = _teamLoadValues();
final totalLoad = loads.fold<double>(0.0, (sum, v) => sum + v);
final avgLoad = loads.isEmpty ? 0.0 : totalLoad / loads.length;
final freshHeart = widget.heartRateByPlayerId.values.where((sample) => DateTime.now().difference(sample.measuredAt).inSeconds <= 35).toList();
final avgHeart = freshHeart.isEmpty ? 0 : (freshHeart.fold<int>(0, (sum, sample) => sum + sample.bpm) / freshHeart.length).round();
final livePlayers = _livePlayerOptions();
final connectedPlayers = livePlayers.where((p) => _isPlayerOnlineLive(p.id) || _heartRateForPlayerId(p.id) != null).length;

return Container(
  color: Colors.white,
  padding: EdgeInsets.fromLTRB(phone ? 6 : 8, phone ? 6 : 7, phone ? 6 : 8, phone ? 6 : 7),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(child: _liveCommandKpi(icon: Icons.groups_rounded, label: 'Подключены', value: '$connectedPlayers/${livePlayers.length}', active: connectedPlayers > 0)),
          const SizedBox(width: 5),
          Expanded(child: _liveCommandKpi(icon: Icons.monitor_heart_rounded, label: 'Пульс ср.', value: avgHeart <= 0 ? '—' : '$avgHeart', active: avgHeart > 0)),
          const SizedBox(width: 5),
          Expanded(child: _liveCommandKpi(icon: Icons.local_fire_department_rounded, label: 'Нагрузка', value: avgLoad.toStringAsFixed(0), active: avgLoad > 0)),
        ],
      ),
      const SizedBox(height: 6),
      SizedBox(height: phone ? 44 : 52, child: _quickPlayerSelector(phone: phone, compact: compact)),
      const SizedBox(height: 6),
      Expanded(child: _teamLoadDotsChart(compact: compact)),
    ],
  ),
);
}

Widget _liveCommandKpi({required IconData icon, required String label, required String value, required bool active}) {
return Container(
  height: 32,
  padding: const EdgeInsets.symmetric(horizontal: 6),
  decoration: BoxDecoration(
    color: active ? _OF.greenSoft : _OF.header,
    borderRadius: BorderRadius.circular(4),
    border: Border.all(color: active ? _OF.greenBorder : _OF.line),
  ),
  child: Row(
    children: [
      Icon(icon, size: 12, color: active ? _OF.green : _OF.muted2),
      const SizedBox(width: 6),
      Expanded(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _OF.muted2, fontSize: 10.4, fontWeight: FontWeight.w700)),
            const SizedBox(height: 1),
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: active ? _OF.text : _OF.muted2, fontSize: 11.2, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    ],
  ),
);
}

Widget _quickPlayerSelector({required bool phone, required bool compact}) {
final players = _monitorCandidatePlayers();
if (players.isEmpty) {
  return Container(
    alignment: Alignment.center,
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
    child: const Text('Игроки появятся после загрузки состава', style: TextStyle(color: _OF.muted2, fontSize: 11.2, fontWeight: FontWeight.w700)),
  );
}
return ListView.separated(
  scrollDirection: Axis.horizontal,
  physics: const BouncingScrollPhysics(),
  itemCount: players.length,
  separatorBuilder: (_, __) => const SizedBox(width: 5),
  itemBuilder: (_, i) => _quickPlayerChip(players[i], i, phone: phone, compact: compact),
);
}

Widget _quickPlayerChip(TrackerPlayerOption player, int index, {required bool phone, required bool compact}) {
final selected = _isPlayerInMonitorGrid(player.id);
final focused = widget.selectedPlayer?.id == player.id;
final online = _isPlayerOnlineLive(player.id);
final load = _loadForPlayerId(player.id);
final bpm = _heartRateForPlayerId(player.id)?.bpm;
final mark = _loadMarkLabel(load, heartRateBpm: bpm);
final markColor = _loadMarkColor(load, heartRateBpm: bpm);
final avatar = _trackerAbsolutePhotoUrl(player.avatar ?? _sessionForPlayer(player.id)?.avatarUrl);
final number = player.number ?? '${index + 1}';
return Material(
  color: selected ? _OF.greenSoft : (online ? _OF.greenSoft : _OF.header),
  borderRadius: BorderRadius.circular(4),
  child: _NoHoverTap(
    onTap: () => _toggleMonitorPlayer(player),
    onLongPress: () => _selectPlayerForAnalytics(player),
    borderRadius: BorderRadius.circular(4),
    child: Container(
      width: phone ? 150 : (compact ? 170 : 190),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: selected ? _OF.green : (focused ? _OF.orange.withOpacity(.38) : (online ? _OF.greenBorder : _OF.line))),
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: phone ? 12 : 14,
                backgroundColor: selected ? _OF.green : (focused ? _OF.orange : (online ? _OF.green : Colors.white)),
                backgroundImage: avatar.isNotEmpty ? NetworkImage(avatar) : null,
                child: avatar.isEmpty ? Text(_playerInitials(player.name), style: TextStyle(color: online || selected || focused ? Colors.white : _OF.graphite, fontSize: 11.2, fontWeight: FontWeight.w700)) : null,
              ),
              Positioned(
                right: -3,
                bottom: -3,
                child: Container(
                  width: 13,
                  height: 13,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: online ? _OF.green : _OF.line)),
                  child: Text(number, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: online ? _OF.green : _OF.muted2, fontSize: 9.6, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_compactPlayerName(player.name), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: selected ? _OF.green : (focused ? _OF.orange : _OF.text), fontSize: phone ? 9.4 : 10.2, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    _miniValuePill(icon: Icons.favorite_rounded, text: bpm == null ? '—' : '$bpm', active: bpm != null, color: _OF.red),
                    const SizedBox(width: 4),
                    _miniValuePill(icon: Icons.local_fire_department_rounded, text: load.toStringAsFixed(0), active: load > 0, color: markColor),
                    const SizedBox(width: 4),
                    Flexible(child: Text(mark, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: markColor, fontSize: 9.6, fontWeight: FontWeight.w700))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          _NoHoverTap(
            onTap: () => _toggleMonitorPlayer(player),
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(color: selected ? _OF.green : Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: selected ? _OF.green : _OF.greenBorder)),
              child: Icon(selected ? Icons.check_rounded : Icons.add_rounded, size: 13, color: selected ? Colors.white : _OF.green),
            ),
          ),
        ],
      ),
    ),
  ),
);
}

Widget _miniValuePill({required IconData icon, required String text, required bool active, required Color color}) {
return Container(
  height: 16,
  padding: const EdgeInsets.symmetric(horizontal: 4),
  decoration: BoxDecoration(color: active ? color.withOpacity(.08) : Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: active ? color.withOpacity(.08) : _OF.line)),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 8, color: active ? color : _OF.muted2),
      const SizedBox(width: 3),
      Text(text, style: TextStyle(color: active ? _OF.text : _OF.muted2, fontSize: 9.6, fontWeight: FontWeight.w700)),
    ],
  ),
);
}

Widget _teamLoadDotsChart({required bool compact}) {
final samples = _teamLoadTimelineForPaint();
if (samples.isEmpty || samples.every((v) => v.avgLoad <= 0 && v.maxLoad <= 0)) {
  return Container(
    alignment: Alignment.centerLeft,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
    child: const Text('График нагрузки появится после первых live-пакетов', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _OF.muted2, fontSize: 10.4, fontWeight: FontWeight.w600)),
  );
}
final maxLoad = math.max(1.0, samples.map((s) => s.maxLoad).fold<double>(0, (m, v) => math.max(m, v).toDouble())).toDouble();
final maxElapsed = math.max(60, samples.map((s) => s.elapsedSec).fold<int>(0, (m, v) => math.max(m, v).toInt())).toInt();
return Container(
  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
  child: CustomPaint(
    painter: _TeamLoadTimePainter(samples: samples, maxValue: maxLoad, maxElapsedSec: maxElapsed, showAxis: !compact),
    child: Stack(
      children: [
        Positioned(
          left: 10,
          top: 7,
          child: Text('нагрузка команды · по времени', style: TextStyle(color: _OF.muted2.withOpacity(.92), fontSize: compact ? 8.4 : 9.4, fontWeight: FontWeight.w700)),
        ),
        Positioned(
          right: 10,
          top: 7,
          child: Text('max ${maxLoad.toStringAsFixed(maxLoad < 10 ? 1 : 0)}', style: TextStyle(color: _OF.green, fontSize: compact ? 8.4 : 9.4, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  ),
);
}

Widget _phoneTeamLoadCard() {
final samples = _teamLoadTimelineForPaint();
final hasData = samples.any((v) => v.avgLoad > 0 || v.maxLoad > 0);
final maxLoad = hasData ? math.max(1.0, samples.map((s) => s.maxLoad).fold<double>(0, (m, v) => math.max(m, v).toDouble())).toDouble() : 1.0;
final maxElapsed = math.max(60, samples.map((s) => s.elapsedSec).fold<int>(0, (m, v) => math.max(m, v).toInt())).toInt();
return Container(
  padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(_OF.mobileCardRadius),
    
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Нагрузка команды', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _OF.text, fontSize: 14.2, fontWeight: FontWeight.w700, letterSpacing: -.35)),
                SizedBox(height: 2),
                Text('нагрузка команды · по времени', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _OF.muted2, fontSize: 11.0, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: _OF.greenSoft, borderRadius: BorderRadius.circular(999), border: Border.all(color: _OF.greenBorder)),
            child: Text('max ${maxLoad.toStringAsFixed(maxLoad < 10 ? 1 : 0)}', style: const TextStyle(color: _OF.green, fontSize: 11.0, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      const SizedBox(height: 8),
      SizedBox(
        height: 164,
        child: hasData
            ? CustomPaint(painter: _TeamLoadTimePainter(samples: samples, maxValue: maxLoad, maxElapsedSec: maxElapsed, showAxis: true), child: const SizedBox.expand())
            : _phoneAnalysisEmpty('После старта Live здесь появится реальная динамика нагрузки по времени.'),
      ),
    ],
  ),
);
}

Widget _phonePlayersCompactSection(int online, int active) {
final players = _livePlayerOptions();
final sorted = List<TrackerPlayerOption>.from(players);
sorted.sort((a, b) {
  final aOnline = _isPlayerOnlineLive(a.id) ? 1 : 0;
  final bOnline = _isPlayerOnlineLive(b.id) ? 1 : 0;
  if (aOnline != bOnline) return bOnline.compareTo(aOnline);
  return _loadForPlayerId(b.id).compareTo(_loadForPlayerId(a.id));
});
final visible = sorted.take(5).toList(growable: false);
return Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Row(
      children: [
        const Expanded(child: Text('Все игроки команды', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _OF.text, fontSize: 14.0, fontWeight: FontWeight.w700, letterSpacing: -.35))),
        _phoneTextAction(icon: Icons.filter_list_rounded, label: 'Фильтры', color: _OF.graphite, onTap: () => _openPhoneLiveSheet(_LiveMobileSheetTab.players, online, active)),
        Container(width: 1, height: 18, margin: const EdgeInsets.symmetric(horizontal: 8), color: _OF.lineStrong),
        _phoneTextAction(icon: Icons.bar_chart_rounded, label: 'Анализ', color: _OF.green, onTap: _openPhoneTeamAnalysisSheet),
      ],
    ),
    const SizedBox(height: 8),
    if (visible.isEmpty)
      _phoneSelectPlayerPrompt(online, active)
    else
      Container(
        decoration: const BoxDecoration(color: Colors.white),
        child: Column(
          children: [
            for (var i = 0; i < visible.length; i++) ...[
              _phonePlayerListRow(visible[i], i),
              
            ],
          ],
        ),
      ),
  ],
);
}

Widget _phoneTextAction({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
return _NoHoverTap(
  onTap: onTap,
  borderRadius: BorderRadius.circular(10),
  child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(color: color, fontSize: 11.2, fontWeight: FontWeight.w600, letterSpacing: -.02)),
      ],
    ),
  ),
);
}

Widget _phonePlayerListRow(TrackerPlayerOption player, int index) {
final load = _loadForPlayerId(player.id);
final heart = _heartRateForPlayerId(player.id);
final online = _isPlayerOnlineLive(player.id);
final number = player.number ?? '${index + 1}';
return _NoHoverTap(
  onTap: () => _selectPlayerForAnalytics(player),
  borderRadius: BorderRadius.circular(14),
  child: Padding(
    padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
    child: Row(
      children: [
        _playerAvatarCircle(player: player, radius: 22, online: online),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(player.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _OF.text, fontSize: 12.0, fontWeight: FontWeight.w700, letterSpacing: -.18)),
              const SizedBox(height: 2),
              Text('№$number · ${_activity.shortTitle} · ${heart == null ? (online ? 'online' : 'ждём данные') : '${heart.bpm} bpm'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: online ? _OF.green : _OF.muted2, fontSize: 10.4, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        Text(load > 0 ? load.toStringAsFixed(load < 10 ? 1 : 0) : '—', style: TextStyle(color: load > 0 ? _OF.green : _OF.muted2, fontSize: 13.4, fontWeight: FontWeight.w700)),
        const SizedBox(width: 6),
        const Icon(Icons.chevron_right_rounded, size: 20, color: _OF.muted2),
      ],
    ),
  ),
);
}

Future<void> _openPhoneTeamAnalysisSheet() async {
if (!mounted) return;
await showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  barrierColor: Colors.black.withOpacity(.22),
  builder: (sheetContext) {
    return DraggableScrollableSheet(
      initialChildSize: .42,
      minChildSize: .32,
      maxChildSize: .78,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: ClipRRect(
            borderRadius: BorderRadius.vertical(top: Radius.circular(_OF.sheetRadius)),
            child: Material(
              color: Colors.white,
              child: SafeArea(
                top: false,
                child: _phoneTeamAnalysisSheetContent(scrollController, () => Navigator.of(sheetContext).pop()),
              ),
            ),
          ),
        );
      },
    );
  },
);
}


Widget _phoneTeamAnalysisDock(int online, int active) {
final samples = _teamLoadTimelineForPaint();
final avg = samples.isEmpty ? 0.0 : samples.last.avgLoad;
final maxLoad = samples.isEmpty ? 0.0 : samples.map((s) => s.maxLoad).fold<double>(0, (m, v) => math.max(m, v).toDouble());
final highMin = _teamHighLoadSeconds() / 60.0;
final distanceKm = _teamDistanceKm();
final totalPlayers = math.max(1, _livePlayerOptions().length);
return _NoHoverTap(
  onTap: _openPhoneTeamAnalysisSheet,
  borderRadius: BorderRadius.circular(_OF.mobileCardRadius),
  child: Container(
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(_OF.mobileCardRadius),
      
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: Text('Анализ команды', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _OF.text, fontSize: 15.2, fontWeight: FontWeight.w700, letterSpacing: -.22))),
            _phoneStatusPill(_durationText(), _OF.graphite),
            const SizedBox(width: 6),
            _phoneStatusPill('$online/$totalPlayers', _OF.green),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _phoneTeamAnalysisMiniMetric(Icons.timeline_rounded, 'Средняя', avg.toStringAsFixed(avg < 10 ? 1 : 0))),
            const SizedBox(width: 7),
            Expanded(child: _phoneTeamAnalysisMiniMetric(Icons.trending_up_rounded, 'Пик', maxLoad.toStringAsFixed(maxLoad < 10 ? 1 : 0))),
            const SizedBox(width: 7),
            Expanded(child: _phoneTeamAnalysisMiniMetric(Icons.timer_rounded, 'Высокая', highMin.toStringAsFixed(1))),
            const SizedBox(width: 7),
            Expanded(child: _phoneTeamAnalysisMiniMetric(Icons.directions_run_rounded, 'Км', distanceKm.toStringAsFixed(2))),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(color: _OF.greenSoft.withOpacity(.62), borderRadius: BorderRadius.circular(_OF.mobileInnerRadius), border: Border.all(color: _OF.greenBorder)),
          child: const Row(
            children: [
              Icon(Icons.bar_chart_rounded, color: _OF.green, size: 17),
              SizedBox(width: 8),
              Expanded(child: Text('Подробный анализ', style: TextStyle(color: _OF.green, fontSize: 12.0, fontWeight: FontWeight.w700))),
              Icon(Icons.expand_less_rounded, color: _OF.green, size: 18),
            ],
          ),
        ),
      ],
    ),
  ),
);
}

Widget _phoneTeamAnalysisMiniMetric(IconData icon, String label, String value) {
return Container(
  height: 58,
  padding: const EdgeInsets.fromLTRB(7, 7, 7, 6),
  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(_OF.mobileInnerRadius)),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(icon, size: 12, color: _OF.green),
          const SizedBox(width: 4),
          Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _OF.muted2, fontSize: 9.6, fontWeight: FontWeight.w700))),
        ],
      ),
      const Spacer(),
      Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _OF.text, fontSize: 15.0, fontWeight: FontWeight.w700, letterSpacing: -.25)),
    ],
  ),
);
}

Widget _phoneTeamAnalysisSheetContent(ScrollController scrollController, VoidCallback onClose) {
final samples = _teamLoadTimelineForPaint();
final avg = samples.isEmpty ? 0.0 : samples.last.avgLoad;
final maxLoad = samples.isEmpty ? 0.0 : samples.map((s) => s.maxLoad).fold<double>(0, (m, v) => math.max(m, v).toDouble());
final highMin = _teamHighLoadSeconds() / 60.0;
final distanceKm = _teamDistanceKm();
final onlinePlayers = _connectedPlayerOptions().where((p) => _isPlayerOnlineLive(p.id)).length;
final totalPlayers = math.max(1, _livePlayerOptions().length);
return ListView(
  controller: scrollController,
  physics: const BouncingScrollPhysics(),
  padding: const EdgeInsets.fromLTRB(16, 10, 16, 22),
  children: [
    Center(child: Container(width: 46, height: 4, decoration: BoxDecoration(color: _OF.lineStrong, borderRadius: BorderRadius.circular(999)))),
    const SizedBox(height: 8),
    Row(
      children: [
        const Expanded(child: Text('Анализ команды', style: TextStyle(color: _OF.text, fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -.25))),
        _phoneStatusPill(_durationText(), _OF.graphite),
        const SizedBox(width: 6),
        _phoneStatusPill('$onlinePlayers/$totalPlayers', _OF.green),
        const SizedBox(width: 6),
        _phoneSheetCloseButton(onClose),
      ],
    ),
    const SizedBox(height: 8),
    GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 2.35,
      children: [
        _phoneTeamAnalysisMetric(Icons.timeline_rounded, 'Средняя нагрузка', avg.toStringAsFixed(avg < 10 ? 1 : 0), 'усл. ед.'),
        _phoneTeamAnalysisMetric(Icons.trending_up_rounded, 'Пиковая нагрузка', maxLoad.toStringAsFixed(maxLoad < 10 ? 1 : 0), 'усл. ед.'),
        _phoneTeamAnalysisMetric(Icons.timer_rounded, 'Высокая нагрузка', highMin.toStringAsFixed(1), 'мин'),
        _phoneTeamAnalysisMetric(Icons.directions_run_rounded, 'Дистанция', distanceKm.toStringAsFixed(2), 'км'),
      ],
    ),
    const SizedBox(height: 8),
    _NoHoverTap(
      onTap: () {
        onClose();
        _openPhoneLiveSheet(_LiveMobileSheetTab.team, _sessions.where((s) => s.isOnline).length, activeSessionCount);
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
        child: const Row(
          children: [
            Icon(Icons.bar_chart_rounded, color: _OF.green, size: 18),
            SizedBox(width: 10),
            Expanded(child: Text('Подробный анализ', style: TextStyle(color: _OF.text, fontSize: 12.4, fontWeight: FontWeight.w700))),
            Icon(Icons.chevron_right_rounded, color: _OF.muted2),
          ],
        ),
      ),
    ),
  ],
);
}

Widget _phoneTeamAnalysisMetric(IconData icon, String label, String value, String unit) {
return Container(
  padding: const EdgeInsets.all(10),
  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), ),
  child: Row(
    children: [
      Container(width: 28, height: 28, decoration: BoxDecoration(color: _OF.greenSoft, borderRadius: BorderRadius.circular(9)), child: Icon(icon, size: 16, color: _OF.green)),
      const SizedBox(width: 9),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _OF.muted2, fontSize: 10.4, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            RichText(text: TextSpan(children: [
              TextSpan(text: value, style: const TextStyle(color: _OF.text, fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -.4)),
              TextSpan(text: ' $unit', style: const TextStyle(color: _OF.muted2, fontSize: 11.2, fontWeight: FontWeight.w700)),
            ])),
          ],
        ),
      ),
    ],
  ),
);
}

List<_TeamLoadSample> _teamLoadTimelineForPaint() {
if (_teamLoadHistory.isNotEmpty) return List<_TeamLoadSample>.from(_teamLoadHistory);
final snap = _currentTeamLoadSnapshot();
return <_TeamLoadSample>[_TeamLoadSample(elapsedSec: snap.elapsedSec, avgLoad: snap.avgLoad, maxLoad: snap.maxLoad, connectedPlayers: snap.connectedPlayers)];
}

void _recordTeamLoadSnapshot({bool force = false}) {
final snap = _currentTeamLoadSnapshot();
if (!force && !_running && snap.maxLoad <= 0) return;
if (!force && snap.maxLoad <= 0 && _teamLoadHistory.isEmpty) return;
if (_teamLoadHistory.isNotEmpty) {
  final last = _teamLoadHistory.last;
  final tooSoon = (snap.elapsedSec - last.elapsedSec).abs() < 5;
  if (tooSoon) {
    _teamLoadHistory[_teamLoadHistory.length - 1] = _TeamLoadSample(
      elapsedSec: math.max(last.elapsedSec, snap.elapsedSec).toInt(),
      avgLoad: snap.avgLoad,
      maxLoad: snap.maxLoad,
      connectedPlayers: snap.connectedPlayers,
    );
    return;
  }
}
_teamLoadHistory.add(_TeamLoadSample(elapsedSec: snap.elapsedSec, avgLoad: snap.avgLoad, maxLoad: snap.maxLoad, connectedPlayers: snap.connectedPlayers));
if (_teamLoadHistory.length > 240) {
  _teamLoadHistory.removeRange(0, _teamLoadHistory.length - 240);
}
}

_TeamLoadSnapshot _currentTeamLoadSnapshot() {
final players = _connectedPlayerOptions();
final sourcePlayers = players.isNotEmpty ? players : _livePlayerOptions();
var values = sourcePlayers.map((p) => _loadForPlayerId(p.id)).where((v) => v.isFinite && v >= 0).toList(growable: false);
if (values.isEmpty) {
  values = _sessions.map((s) => math.max(s.loadScore, _localTrackForPlayer(_resolvedPlayerIdForSession(s))?.loadScore ?? 0.0)).where((v) => v.isFinite && v >= 0).toList(growable: false);
}
final maxLoad = values.isEmpty ? 0.0 : values.fold<double>(0, (m, v) => math.max(m, v).toDouble());
final avgLoad = values.isEmpty ? 0.0 : values.fold<double>(0, (sum, v) => sum + v) / math.max(1, values.length);
final elapsed = _startedAt == null ? 0 : math.max(0, DateTime.now().difference(_startedAt!).inSeconds);
return _TeamLoadSnapshot(elapsedSec: elapsed, avgLoad: avgLoad, maxLoad: maxLoad, connectedPlayers: values.where((v) => v > 0).length);
}

double _teamHighLoadSeconds() {
if (_teamLoadHistory.length < 2) return 0;
var seconds = 0.0;
for (var i = 1; i < _teamLoadHistory.length; i++) {
  final prev = _teamLoadHistory[i - 1];
  final cur = _teamLoadHistory[i];
  final segmentMax = math.max(prev.maxLoad, cur.maxLoad).toDouble();
  final segmentAvg = math.max(prev.avgLoad, cur.avgLoad).toDouble();
  // load_score в Live приходит в шкале примерно 0..3, поэтому 45/15 здесь никогда не срабатывали.
  // Для детско-юношеской футбольной сессии считаем высокой нагрузкой участок от 2.4+ или среднюю 1.8+.
  if (segmentMax >= 2.4 || segmentAvg >= 1.8) {
    seconds += math.max(0, cur.elapsedSec - prev.elapsedSec).toDouble();
  }
}
return seconds;
}

double _teamDistanceKm() {
var meters = 0.0;
final ids = <int>{};
for (final p in _livePlayerOptions()) {
  if (!ids.add(p.id)) continue;
  final local = _localTrackForPlayer(p.id);
  final session = _sessionForPlayer(p.id);
  meters += math.max(local?.totalDistanceM ?? 0.0, session?.totalDistanceM ?? 0.0);
}
if (meters <= 0) {
  for (final s in _sessions) {
    meters += math.max(s.totalDistanceM, _localTrackForPlayer(_resolvedPlayerIdForSession(s))?.totalDistanceM ?? 0.0);
  }
}
return meters / 1000.0;
}

List<TrackerPlayerOption> _livePlayerOptions() {
final result = <TrackerPlayerOption>[];
final seen = <int>{};
for (final p in widget.players) {
  if (p.id > 0 && seen.add(p.id)) result.add(p);
}
for (var i = 0; i < _sessions.length; i++) {
  final s = _sessions[i];
  final resolved = _playerForSession(s);
  if (resolved != null && resolved.id > 0) {
    if (seen.add(resolved.id)) result.add(resolved);
    continue;
  }

  final id = s.playerId ?? (1000000 + s.id);
  if (id <= 0 || !seen.add(id)) continue;
  result.add(TrackerPlayerOption(
    id: id,
    name: _sessionDisplayName(s),
    avatar: s.avatarUrl,
    number: _sessionDisplayNumber(s, i),
  ));
}
return result;
}

List<TrackerPlayerOption> _connectedPlayerOptions() {
final players = List<TrackerPlayerOption>.from(_livePlayerOptions());
players.retainWhere((p) {
  final hasHeart = _heartRateForPlayerId(p.id) != null;
  final hasTrack = (_localTrackForPlayer(p.id)?.points.isNotEmpty ?? false);
  final hasLiveLoad = _running && _loadForPlayerId(p.id) > 0;
  return _isPlayerOnlineLive(p.id) || hasHeart || hasTrack || hasLiveLoad;
});
players.sort((a, b) {
  final aSelected = widget.selectedPlayer?.id == a.id ? 1 : 0;
  final bSelected = widget.selectedPlayer?.id == b.id ? 1 : 0;
  if (aSelected != bSelected) return bSelected.compareTo(aSelected);
  final aOnline = _isPlayerOnlineLive(a.id) ? 1 : 0;
  final bOnline = _isPlayerOnlineLive(b.id) ? 1 : 0;
  if (aOnline != bOnline) return bOnline.compareTo(aOnline);
  final loadCompare = _loadForPlayerId(b.id).compareTo(_loadForPlayerId(a.id));
  if (loadCompare != 0) return loadCompare;
  return (int.tryParse(a.number ?? '') ?? 9999).compareTo(int.tryParse(b.number ?? '') ?? 9999);
});
return players;
}

TrackerPlayerOption? _playerById(int? id) {
if (id == null || id <= 0) return null;
for (final p in widget.players) {
  if (p.id == id) return p;
}
return null;
}

TrackerDeviceModel? _deviceForSession(TrackerLiveSessionModel session) {
final uuid = session.deviceUuid.trim().toLowerCase();
final deviceName = session.deviceName.trim().toLowerCase();
for (final d in widget.savedDevices) {
  final dUuid = d.deviceUuid.trim().toLowerCase();
  final dName = d.deviceName.trim().toLowerCase();
  if (uuid.isNotEmpty && dUuid.isNotEmpty && uuid == dUuid) return d;
  if (deviceName.isNotEmpty && dName.isNotEmpty && deviceName == dName) return d;
}
if (session.playerId != null) {
  for (final d in widget.savedDevices) {
    if (d.playerId == session.playerId) return d;
  }
}
return null;
}

int? _resolvedPlayerIdForSession(TrackerLiveSessionModel session) {
final direct = _playerById(session.playerId);
if (direct != null) return direct.id;
final device = _deviceForSession(session);
final fromDevice = _playerById(device?.playerId);
if (fromDevice != null) return fromDevice.id;
return session.playerId;
}

TrackerPlayerOption? _playerForSession(TrackerLiveSessionModel session) {
final direct = _playerById(session.playerId);
if (direct != null) return direct;
final device = _deviceForSession(session);
final fromDevice = _playerById(device?.playerId);
if (fromDevice != null) return fromDevice;
final sessionName = session.playerName?.trim();
if (!_looksLikeGeneratedPlayerName(sessionName)) {
  for (final p in widget.players) {
    if (p.name.trim().toLowerCase() == sessionName!.toLowerCase()) return p;
  }
}
return null;
}

bool _looksLikeGeneratedPlayerName(String? value) {
final v = (value ?? '').trim();
if (v.isEmpty) return true;
final lower = v.toLowerCase();
if (RegExp(r'^(игрок|player)\s*#?\s*\d+$').hasMatch(lower)) return true;
if (RegExp(r'^#?\d+$').hasMatch(lower)) return true;
return false;
}

String _sessionDisplayName(TrackerLiveSessionModel session) {
final player = _playerForSession(session);
if (player != null) return player.name;
final device = _deviceForSession(session);
final devicePlayerName = device?.playerName?.trim();
if (!_looksLikeGeneratedPlayerName(devicePlayerName)) return devicePlayerName!;
final sessionName = session.playerName?.trim();
if (!_looksLikeGeneratedPlayerName(sessionName)) return sessionName!;
final deviceName = session.deviceName.trim();
if (deviceName.isNotEmpty && deviceName.toLowerCase() != 'трекер') return deviceName;
return 'Подключённый игрок';
}

String _sessionDisplayNumber(TrackerLiveSessionModel session, int index) {
final player = _playerForSession(session);
if ((player?.number ?? '').trim().isNotEmpty) return player!.number!;
final device = _deviceForSession(session);
final devicePlayer = _playerById(device?.playerId);
if ((devicePlayer?.number ?? '').trim().isNotEmpty) return devicePlayer!.number!;
return '${index + 1}';
}

List<double> _teamLoadValues() {
final connected = _connectedPlayerOptions();
final players = connected.isNotEmpty ? connected : _livePlayerOptions();
if (players.isNotEmpty) return players.map((p) => _loadForPlayerId(p.id)).toList(growable: false);
return _sessions.map((s) => math.max(s.loadScore, _localTrackForPlayer(_resolvedPlayerIdForSession(s))?.loadScore ?? 0.0)).toList(growable: false);
}

double _loadForPlayerId(int? playerId) {
final session = _sessionForPlayer(playerId);
final local = _localTrackForPlayer(playerId);
return math.max(session?.loadScore ?? 0.0, local?.loadScore ?? 0.0);
}

bool _isPlayerOnlineLive(int? playerId) {
final session = _sessionForPlayer(playerId);
final local = _localTrackForPlayer(playerId);
final heart = _heartRateForPlayerId(playerId);
final freshHeart = heart != null && DateTime.now().difference(heart.measuredAt).inSeconds <= 35;
return session?.isOnline == true || (local != null && local.points.isNotEmpty && _running) || freshHeart;
}

String _loadMarkLabel(double load, {int? heartRateBpm}) {
if (load <= 0 && heartRateBpm == null) return '—';
if (load >= 80 || (heartRateBpm ?? 0) >= 180) return 'ПИК';
if (load >= 45 || (heartRateBpm ?? 0) >= 160) return 'ВЫСОКАЯ';
if (load >= 15 || (heartRateBpm ?? 0) >= 135) return 'РАБОЧАЯ';
return 'ЛЁГКАЯ';
}

Color _loadMarkColor(double load, {int? heartRateBpm}) {
if (load >= 80 || (heartRateBpm ?? 0) >= 180) return _OF.red;
if (load >= 45 || (heartRateBpm ?? 0) >= 160) return _OF.orange;
if (load >= 15 || (heartRateBpm ?? 0) >= 135) return _OF.green;
return _OF.cyan;
}

Widget _phoneDebugDisclosure(int online, int active) {
return Material(
  color: Colors.white,
  child: Column(
    children: [
      _NoHoverTap(
        onTap: () => setState(() => _bottomOperatorExpanded = !_bottomOperatorExpanded),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(color: _OF.greenSoft, borderRadius: BorderRadius.circular(6)),
                child: const Icon(Icons.tune_rounded, color: _OF.green, size: 17),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Оператор / диагностика', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _OF.text, fontSize: 11.7, fontWeight: FontWeight.w700)),
                    Text(_bottomOperatorExpanded ? 'Скрыть технические данные' : 'Свернуто, чтобы не мешать Live', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _OF.muted2, fontSize: 9.6, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              Icon(_bottomOperatorExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: _OF.muted2),
            ],
          ),
        ),
      ),
      if (_bottomOperatorExpanded) ...[
        _ofHorizontalDivider(),
        SizedBox(height: 360, child: _rightOperatorPanel(online, active)),
      ],
    ],
  ),
);
}

Widget _tabletActivityBanner({bool dense = false}) {
final fieldReady = !_activity.requiresField || widget.selectedField?.hasCalibration == true;
final fieldText = _activity.requiresField
    ? (fieldReady ? widget.selectedField!.title : 'Поле не выбрано / не откалибровано')
    : 'Поле не требуется';

return Material(
  color: Colors.white,
  child: _NoHoverTap(
    onTap: _openActivityChooser,
    child: Container(
      constraints: BoxConstraints(minHeight: dense ? 38 : 46),
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 8 : 10,
        vertical: dense ? 5 : 7,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _activity.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _OF.text,
                    fontSize: dense ? 11.0 : 12.0,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  fieldText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: fieldReady ? _OF.green : _OF.orange,
                    fontSize: dense ? 9.6 : 10.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            'Изменить',
            style: TextStyle(
              color: _running ? _OF.muted2 : _OF.green,
              fontSize: dense ? 9.6 : 10.4,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  ),
);
}

Future<void> _openActivityChooser() async {
if (_running) {
  _toast('Сначала остановите Live, затем смените тип тренировки');
  return;
}
final selected = await showDialog<TrackerTrainingActivity>(
  context: context,
  barrierColor: const Color(0x66000000),
  builder: (context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(9),
      backgroundColor: Colors.transparent,
      child: LayoutBuilder(
        builder: (context, c) {
          final phone = c.maxWidth < 620;
          final maxWidth = phone ? c.maxWidth : math.min(c.maxWidth, 820.0);
          return Center(
            child: Container(
              width: maxWidth,
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: null,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(color: _OF.greenSoft, borderRadius: BorderRadius.circular(6)),
                        child: const Icon(Icons.tune_rounded, color: _OF.green, size: 19),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Выберите тип трекинга', style: TextStyle(color: _OF.text, fontSize: 13, fontWeight: FontWeight.w700)),
                            SizedBox(height: 2),
                            Text('Поле требуется только для футбола. Кросс и зал запускаются без field_id.', style: TextStyle(color: _OF.muted, fontSize: 11.2, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                      _NoHoverTap(
                        onTap: () => Navigator.of(context).pop(),
                        child: const SizedBox(width: 32, height: 32, child: Icon(Icons.close_rounded, color: _OF.muted, size: 18)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (phone) ...[
                    _ActivityModeCard(activity: TrackerTrainingActivity.footballField, selected: _activity == TrackerTrainingActivity.footballField),
                    const SizedBox(height: 8),
                    _ActivityModeCard(activity: TrackerTrainingActivity.outdoorRun, selected: _activity == TrackerTrainingActivity.outdoorRun),
                    const SizedBox(height: 8),
                    _ActivityModeCard(activity: TrackerTrainingActivity.indoorStrength, selected: _activity == TrackerTrainingActivity.indoorStrength),
                  ] else
                    Row(
                      children: [
                        Expanded(child: _ActivityModeCard(activity: TrackerTrainingActivity.footballField, selected: _activity == TrackerTrainingActivity.footballField, vertical: true)),
                        const SizedBox(width: 8),
                        Expanded(child: _ActivityModeCard(activity: TrackerTrainingActivity.outdoorRun, selected: _activity == TrackerTrainingActivity.outdoorRun, vertical: true)),
                        const SizedBox(width: 8),
                        Expanded(child: _ActivityModeCard(activity: TrackerTrainingActivity.indoorStrength, selected: _activity == TrackerTrainingActivity.indoorStrength, vertical: true)),
                      ],
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  },
);
if (!mounted || selected == null) return;
setState(() {
  _activity = selected;
  _tracks.clear();
  _sessions = <TrackerLiveSessionModel>[];
  _teamLoadHistory.clear();
  _lastProblem = selected.requiresField
      ? 'Выбран режим «${selected.title}»: нужно откалиброванное поле.'
      : 'Выбран режим «${selected.title}»: поле не требуется, сессия будет сохранена без field_id.';
});
await _loadLiveState();
}

Widget _liveControlStrip(int online, int active, {required bool compact}) {
final trackerReady = widget.ble.commandChannelReady || widget.ble.connectedInfo != null;
final hasPolar = widget.heartRateConnectedCount > 0 || _hasTeamHeartRateOnline;
final gpsReady = _lastGpsAt != null && DateTime.now().difference(_lastGpsAt!).inSeconds < 8;
final duration = _durationText();

Widget primaryLiveButton({required bool phone}) {
  final text = _starting
      ? '...'
      : (_paused ? 'Продолжить' : (_running ? 'Стоп' : (phone ? 'Старт Live' : 'Старт')));
  return SizedBox(
    height: 38,
    child: FilledButton.icon(
      onPressed: _starting ? null : (_paused ? _resumeLiveCollection : (_running ? _stopLive : _startLive)),
      style: FilledButton.styleFrom(
        backgroundColor: _paused ? _OF.green : (_running ? _OF.red : _OF.green),
        disabledBackgroundColor: _OF.header,
        disabledForegroundColor: _OF.muted,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(horizontal: phone ? 14 : 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
      ),
      icon: Icon(_paused ? Icons.play_arrow_rounded : (_running ? Icons.stop_rounded : Icons.play_arrow_rounded), size: phone ? 18 : 17),
      label: Text(text, style: TextStyle(fontSize: 11.4, fontWeight: FontWeight.w600)),
    ),
  );
}

if (compact) {
  return Container(
    height: 54,
    color: Colors.transparent,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
    child: Row(
      children: [
        SizedBox(width: 132, child: primaryLiveButton(phone: true)),
        const SizedBox(width: 5),
        _activitySelectorChip(compact: true),
        const SizedBox(width: 5),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                SizedBox(width: 94, child: _liveMiniChip(Icons.timer_rounded, duration, active: _running && !_paused, tight: true)),
                const SizedBox(width: 5),
                SizedBox(width: 60, child: _liveMiniChip(Icons.groups_rounded, '$online/$active', active: online > 0, tight: true)),
                const SizedBox(width: 5),
                SizedBox(width: 66, child: _liveMiniChip(Icons.gps_fixed_rounded, gpsReady ? 'GPS' : 'GPS —', active: gpsReady, tight: true)),
                const SizedBox(width: 5),
                SizedBox(width: 72, child: _liveMiniChip(Icons.favorite_rounded, hasPolar ? 'Polar' : 'Polar —', active: hasPolar, tight: true)),
                const SizedBox(width: 5),
                SizedBox(width: 72, child: _liveMiniChip(Icons.sensors_rounded, trackerReady ? 'BLE' : 'BLE —', active: trackerReady, tight: true)),
                if (_running) ...[
                  const SizedBox(width: 5),
                  _liveExitButton(compact: true),
                ] else if (!trackerReady && widget.onScanBluetooth != null) ...[
                  const SizedBox(width: 5),
                  SizedBox(
                    width: 38,
                    height: 32,
                    child: TextButton(
                      onPressed: widget.scanningBluetooth ? null : widget.onScanBluetooth,
                      style: TextButton.styleFrom(
                        foregroundColor: _OF.graphite,
                        backgroundColor: const Color(0xFFF1F3F6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        padding: EdgeInsets.zero,
                      ),
                      child: widget.scanningBluetooth
                          ? const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.bluetooth_searching_rounded, size: 15),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

return Container(
  height: 44,
  color: Colors.transparent,
  padding: const EdgeInsets.symmetric(horizontal: 8),
  child: Row(
    children: [
      _ofStatusDot(_paused ? _OF.orange : (_running ? _OF.green : _OF.orange)),
      const SizedBox(width: 8),
      Text(
        _paused ? 'Пауза' : (_running ? 'Live' : 'Готовность'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: _OF.text, fontSize: 11.6, fontWeight: FontWeight.w700, letterSpacing: -.12),
      ),
      const SizedBox(width: 8),
      _liveMiniChip(Icons.timer_rounded, duration, active: _running && !_paused),
      const SizedBox(width: 6),
      _activitySelectorChip(compact: false),
      const SizedBox(width: 6),
      _liveMiniChip(Icons.groups_rounded, '$online/$active', active: online > 0),
      const SizedBox(width: 6),
      _liveMiniChip(Icons.monitor_heart_rounded, hasPolar ? 'Polar ${widget.heartRateConnectedCount}' : 'Polar —', active: hasPolar),
      const SizedBox(width: 6),
      _liveMiniChip(Icons.gps_fixed_rounded, gpsReady ? 'GPS' : 'GPS нет', active: gpsReady),
      const SizedBox(width: 6),
      _liveMiniChip(Icons.sensors_rounded, trackerReady ? 'Трекер' : 'Трекер нет', active: trackerReady),
      if (_running) ...[
        const SizedBox(width: 6),
        _liveExitButton(compact: false),
      ],
      const SizedBox(width: 8),
      Expanded(child: _compactLoadTimeline()),
      const SizedBox(width: 8),
      if (!trackerReady && widget.onScanBluetooth != null) ...[
        SizedBox(
          height: 30,
          child: OutlinedButton.icon(
            onPressed: widget.scanningBluetooth ? null : (widget.onScanBluetooth ?? widget.onManageTrackers),
            style: OutlinedButton.styleFrom(
              foregroundColor: _OF.graphite,
              side: BorderSide.none,
              backgroundColor: _OF.header,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            icon: widget.scanningBluetooth
                ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.bluetooth_searching_rounded, size: 14),
            label: Text(widget.scanningBluetooth ? 'Поиск...' : 'Bluetooth', style: const TextStyle(fontSize: 11.2, fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(width: 6),
      ],
      primaryLiveButton(phone: false),
    ],
  ),
);
}

Widget _liveExitButton({required bool compact}) {
return SizedBox(
  height: compact ? 27 : 28,
  child: FilledButton.icon(
    onPressed: _openLiveSessionExitDialog,
    style: FilledButton.styleFrom(
      backgroundColor: _OF.orange,
      foregroundColor: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: compact ? 7 : 9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      elevation: 0,
    ),
    icon: Icon(Icons.logout_rounded, size: compact ? 12 : 13),
    label: Text(compact ? 'Выход' : 'Выход из Live', style: TextStyle(fontSize: compact ? 9.6 : 10.2, fontWeight: FontWeight.w700)),
  ),
);
}

Future<void> _openLiveSessionExitDialog() async {
if (!_running) return;
final action = await showDialog<_LiveSessionExitAction>(
  context: context,
  barrierDismissible: false,
  builder: (context) => AlertDialog(
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    title: const Text('Live-сессия активна', style: TextStyle(fontWeight: FontWeight.w700)),
    content: const Text(
      'Выберите действие: продолжить работу, приостановить запись точек, сохранить тренировку или выйти без сохранения.',
      style: TextStyle(height: 1.35, fontWeight: FontWeight.w600),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(_LiveSessionExitAction.stay),
        child: const Text('Остаться в Live'),
      ),
      TextButton(
        onPressed: () => Navigator.of(context).pop(_LiveSessionExitAction.pause),
        child: const Text('Приостановить'),
      ),
      TextButton(
        onPressed: () => Navigator.of(context).pop(_LiveSessionExitAction.exitWithoutSaving),
        child: const Text('Выйти без сохранения'),
      ),
      FilledButton.icon(
        onPressed: () => Navigator.of(context).pop(_LiveSessionExitAction.stopAndSave),
        style: FilledButton.styleFrom(backgroundColor: _OF.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
        icon: const Icon(Icons.save_rounded, size: 16),
        label: const Text('Сохранить и выйти'),
      ),
    ],
  ),
);
if (action == _LiveSessionExitAction.pause) {
  _pauseLiveCollection();
}
if (action == _LiveSessionExitAction.exitWithoutSaving) {
  await _exitLiveWithoutSaving();
}
if (action == _LiveSessionExitAction.stopAndSave) {
  await _stopLive();
}
}

Widget _activitySelectorChip({required bool compact}) {
return Material(
  color: Colors.transparent,
  child: _NoHoverTap(
    onTap: _openActivityChooser,
    borderRadius: BorderRadius.circular(4),
    child: Container(
      height: 28,
      padding: EdgeInsets.symmetric(horizontal: compact ? 7 : 9),
      decoration: BoxDecoration(
        color: _OF.greenSoft,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _OF.greenBorder.withOpacity(.95)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_activity.icon, color: _OF.green, size: 14),
          const SizedBox(width: 5),
          Text(
            compact ? _activity.shortTitle : _activity.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _OF.green, fontSize: 11.2, fontWeight: FontWeight.w700),
          ),
          if (!compact) ...[
            const SizedBox(width: 4),
            const Icon(Icons.keyboard_arrow_down_rounded, color: _OF.green, size: 14),
          ],
        ],
      ),
    ),
  ),
);
}

Widget _liveMiniChip(IconData icon, String label, {required bool active, bool tight = false}) {
return Container(
  height: tight ? 32 : 22,
  padding: EdgeInsets.symmetric(horizontal: tight ? 4 : 6),
  alignment: Alignment.center,
  decoration: BoxDecoration(
    color: active ? _OF.greenSoft : _OF.header,
    borderRadius: BorderRadius.circular(4),
    border: Border.all(color: active ? _OF.greenBorder : _OF.line),
  ),
  child: Row(
    mainAxisSize: tight ? MainAxisSize.max : MainAxisSize.min,
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(icon, color: active ? _OF.green : _OF.muted, size: tight ? 12 : 13),
      SizedBox(width: tight ? 3 : 5),
      Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: active ? _OF.text : _OF.muted, fontSize: tight ? 8.6 : 9.4, fontWeight: FontWeight.w700))),
    ],
  ),
);
}

Widget _compactLoadTimeline() {
final points = _mainTrack?.points ?? const <_RuntimePoint>[];
return SizedBox(
  height: 22,
  child: CustomPaint(
    painter: _OpenFieldTimelinePainter(
      points: points,
      running: _running,
      progressRatio: _timelineProgressRatio(),
    ),
    child: const SizedBox.expand(),
  ),
);
}

Widget _operatorSessionHeader(int online, int active, {required bool compact}) {
final fieldReady = !_activity.requiresField || widget.selectedField?.hasCalibration == true;
final trackerReady = widget.ble.commandChannelReady || widget.ble.connectedInfo != null;
final hasPolar = widget.heartRateConnectedCount > 0 || _hasTeamHeartRateOnline;
final gpsReady = _lastGpsAt != null && DateTime.now().difference(_lastGpsAt!).inSeconds < 8;
final canStart = fieldReady && (trackerReady || hasPolar || _mode == TrackerLiveSourceMode.heartRateOnly) && !_running && !_starting;
final duration = _startedAt == null ? '00:00:00' : _formatDuration(DateTime.now().difference(_startedAt!));

return Container(
  height: compact ? 44 : 48,
  decoration: const BoxDecoration(
    color: Colors.white,
    border: Border(bottom: BorderSide(color: _OF.line, width: 1)),
  ),
  padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12),
  child: Row(
    children: [
      Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _running ? _OF.green.withOpacity(.06) : _OF.orange.withOpacity(.10),
          borderRadius: BorderRadius.circular(6),
          
        ),
        child: Icon(_running ? Icons.radio_button_checked_rounded : Icons.sports_soccer_rounded, color: _running ? _OF.green : _OF.orange, size: 17),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.teamName}  •  ${_running ? 'LIVE' : 'готово к запуску'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _OF.text, fontSize: 11.4, fontWeight: FontWeight.w500, letterSpacing: -.1),
            ),
            if (!compact)
              Text(
                'Время $duration   ·   Игроки $online/$active   ·   GPS ${gpsReady ? 'есть' : 'нет'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _OF.muted, fontSize: 11.2, fontWeight: FontWeight.w500),
              ),
          ],
        ),
      ),
      if (!compact) ...[
        _operatorMiniStatus('Игроки', '$online/$active', light: true),
        const SizedBox(width: 6),
        _operatorMiniStatus('GPS', gpsReady ? 'есть' : 'нет', light: true),
        const SizedBox(width: 6),
        _operatorMiniStatus('Трекер', trackerReady ? 'онлайн' : 'нет', light: true),
        const SizedBox(width: 8),
      ],
      if (!trackerReady && widget.onScanBluetooth != null) ...[
        SizedBox(
          height: 32,
          child: TextButton.icon(
            onPressed: widget.onScanBluetooth,
            style: TextButton.styleFrom(
              foregroundColor: _OF.graphite,
              backgroundColor: const Color(0xFFF1F3F6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 11),
            ),
            icon: widget.scanningBluetooth
                ? const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.bluetooth_searching_rounded, size: 15),
            label: Text(widget.scanningBluetooth ? 'Поиск...' : (compact ? 'BLE' : 'Поиск Bluetooth')),
          ),
        ),
        const SizedBox(width: 6),
      ],
      SizedBox(
        height: 32,
        child: FilledButton.icon(
          onPressed: _paused ? _resumeLiveCollection : (_running ? _stopLive : (canStart ? _startLive : null)),
          style: FilledButton.styleFrom(
            backgroundColor: _paused ? _OF.green : (_running ? _OF.red : _OF.orange),
            disabledBackgroundColor: const Color(0xFFE2E8F0),
            disabledForegroundColor: _OF.muted,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14),
          ),
          icon: Icon(_paused ? Icons.play_arrow_rounded : (_running ? Icons.stop_rounded : Icons.play_arrow_rounded), size: 17),
          label: Text(_paused ? 'Продолжить' : (_running ? 'Стоп' : 'Старт'), style: const TextStyle(fontWeight: FontWeight.w500)),
        ),
      ),
      const SizedBox(width: 6),
      SizedBox(
        height: 32,
        child: OutlinedButton.icon(
          onPressed: _addPeriod,
          style: OutlinedButton.styleFrom(
            foregroundColor: _OF.text,
            side: BorderSide.none,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12),
          ),
          icon: const Icon(Icons.add_rounded, size: 16),
          label: Text(compact ? 'Период' : '+ Период', style: const TextStyle(fontWeight: FontWeight.w500)),
        ),
      ),
    ],
  ),
);
}

Widget _operatorTab(String text, {required bool active, VoidCallback? onTap}) {
return _NoHoverTap(
  onTap: onTap,
  child: Container(
    height: double.infinity,
    alignment: Alignment.center,
    padding: const EdgeInsets.symmetric(horizontal: 9),
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: active ? _OF.green : Colors.transparent, width: 3)),
    ),
    child: Text(text, style: TextStyle(color: active ? _OF.green : _OF.muted, fontSize: 11.5, fontWeight: FontWeight.w600)),
  ),
);
}

Widget _operatorMiniStatus(String label, String value, {bool light = false}) {
return Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
  decoration: BoxDecoration(
    color: light ? Colors.white : Colors.white.withOpacity(.08),
    borderRadius: BorderRadius.circular(4),
    border: Border.all(color: light ? _OF.line : Colors.white12),
  ),
  child: Row(children: [
    Text(label, style: TextStyle(color: light ? _OF.muted : Colors.white54, fontSize: 10.4, fontWeight: FontWeight.w500)),
    const SizedBox(width: 5),
    Text(value, style: TextStyle(color: light ? _OF.text : Colors.white, fontSize: 11.2, fontWeight: FontWeight.w500)),
  ]),
);
}

Widget _sessionTimeline({required double height}) {
return SizedBox(
  height: math.min(height, 28),
  child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    child: _compactLoadTimeline(),
  ),
);
}

Widget _activePlayersPanel(int online, int active) {
final connectedPlayers = _connectedPlayerOptions();
final totalPlayers = _livePlayerOptions().length;
return _ofPanel(
  title: 'Подключённые игроки',
  subtitle: connectedPlayers.isEmpty ? '$online/$active онлайн · ждём данные' : '${connectedPlayers.length}/$totalPlayers в списке · $online онлайн',
  actions: _renderingFloatingLiveContent ? const [] : [
    _livePanelWindowButton(
      tooltip: 'Открыть подключённых игроков отдельным окном',
      onTap: () => _openExpandedLiveBlock('Подключённые игроки', Icons.groups_rounded, () => _activePlayersPanel(online, active)),
    ),
  ],
  child: connectedPlayers.isEmpty
      ? _playersFallbackList(connectedOnly: true)
      : ListView.builder(
          itemCount: connectedPlayers.length,
          itemBuilder: (_, i) {
            final p = connectedPlayers[i];
            final session = _sessionForPlayer(p.id);
            final local = _localTrackForPlayer(p.id);
            final isSelected = widget.selectedPlayer?.id == p.id;
            return _ofPlayerRow(
              name: p.name,
              number: '${p.number ?? i + 1}',
              speed: math.max(session?.speedKmh ?? 0.0, local?.speedKmh ?? 0.0),
              load: math.max(session?.loadScore ?? 0.0, local?.loadScore ?? 0.0),
              heartRateBpm: _heartRateForPlayerId(p.id)?.bpm,
              online: _isPlayerOnlineLive(p.id),
              selected: isSelected,
              onTap: () => _selectPlayerAndOpenDetails(p),
            );
          },
        ),
);
}

Widget _playersFallbackList({bool connectedOnly = false}) {
if (connectedOnly) {
  return const Center(
    child: Padding(
      padding: EdgeInsets.symmetric(horizontal: 14),
      child: Text(
        'Подключённые GPS/Polar игроки появятся здесь сразу после первых live-данных.',
        textAlign: TextAlign.center,
        style: TextStyle(color: _OF.muted, fontSize: 11.2, fontWeight: FontWeight.w700),
      ),
    ),
  );
}
if (widget.players.isEmpty) {
  return const Center(child: Text('Нет игроков команды', style: TextStyle(color: _OF.muted, fontWeight: FontWeight.w500)));
}
return ListView.builder(
  itemCount: widget.players.length,
  itemBuilder: (_, i) {
    final p = widget.players[i];
    return _ofPlayerRow(
      name: p.name,
      number: '${p.number ?? i + 1}',
      speed: 0,
      load: 0,
      heartRateBpm: _heartRateForPlayerId(p.id)?.bpm,
      online: false,
      selected: widget.selectedPlayer?.id == p.id,
      onTap: () => _selectPlayerAndOpenDetails(p),
    );
  },
);
}

Widget _ofPlayerRow({required String name, required String number, required double speed, required double load, required int? heartRateBpm, required bool online, required bool selected, VoidCallback? onTap}) {
return LayoutBuilder(
  builder: (context, c) {
    final showStats = c.maxWidth >= 190;
    final displayName = name.trim().isEmpty ? 'Игрок' : name.trim();
    return Material(
      color: Colors.transparent,
      child: _NoHoverTap(
        onTap: onTap,
        child: Container(
      height: 42,
      margin: const EdgeInsets.only(bottom: 3),
      decoration: BoxDecoration(
        color: selected ? _OF.blueSoft : (online ? _OF.greenSoft : Colors.white),
        border: Border(left: BorderSide(color: online ? _OF.green : _OF.line, width: 4), bottom: const BorderSide(color: _OF.line)),
      ),
      child: Row(children: [
        SizedBox(width: 32, child: Center(child: Text(number, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _OF.text, fontSize: 11.2, fontWeight: FontWeight.w700)))),
        Expanded(child: Text(displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _OF.text, fontSize: 11.0, fontWeight: FontWeight.w700))),
        if (showStats) ...[
          const SizedBox(width: 6),
          SizedBox(width: 32, child: Text(speed.toStringAsFixed(1), textAlign: TextAlign.right, style: const TextStyle(color: _OF.text, fontSize: 9.6, fontWeight: FontWeight.w700))),
          const SizedBox(width: 6),
          SizedBox(width: 30, child: Text(heartRateBpm == null ? '—' : '$heartRateBpm', textAlign: TextAlign.right, style: TextStyle(color: heartRateBpm == null ? _OF.muted2 : _OF.red, fontSize: 10.4, fontWeight: FontWeight.w700))),
          const SizedBox(width: 6),
          SizedBox(width: 24, child: Text(load.toStringAsFixed(0), textAlign: TextAlign.right, style: TextStyle(color: load > 70 ? _OF.red : _OF.muted, fontSize: 9.6, fontWeight: FontWeight.w700))),
          const SizedBox(width: 6),
        ] else
          const SizedBox(width: 8),
      ]),
        ),
      ),
    );
  },
);
}

String _compactPlayerName(String raw) {
final parts = raw.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
if (parts.length < 2) return raw.trim();
final surname = parts.last;
final initials = parts.take(parts.length - 1).where((p) => p.isNotEmpty).map((p) => '${p.substring(0, 1)}.').join(' ');
return initials.isEmpty ? surname : '$surname $initials';
}

Widget _fieldPanelToggleButton({required bool compact}) {
final expanded = _teamFieldPanelExpanded;
return Padding(
  padding: const EdgeInsets.only(left: 6),
  child: _NoHoverTap(
    onTap: () => setState(() {
      _teamFieldPanelExpanded = !_teamFieldPanelExpanded;
      if (_teamFieldPanelExpanded) _liveSidePanelMode = 'map';
    }),
    borderRadius: BorderRadius.circular(_OF.tabletInnerRadius),
    child: Container(
      height: compact ? 26 : 28,
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10),
      decoration: BoxDecoration(
        color: expanded ? _OF.greenSoft : Colors.white,
        borderRadius: BorderRadius.circular(_OF.tabletInnerRadius),
        border: Border.all(color: expanded ? _OF.greenBorder : _OF.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(expanded ? Icons.visibility_off_rounded : Icons.map_rounded, size: compact ? 13 : 14, color: expanded ? _OF.green : _OF.muted2),
          const SizedBox(width: 5),
          Text(expanded ? 'Скрыть поле' : 'Показать поле', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: expanded ? _OF.green : _OF.graphite, fontSize: compact ? 8.7 : 9.2, fontWeight: FontWeight.w800)),
        ],
      ),
    ),
  ),
);
}

Widget _operatorFieldPanel() {
final isFieldMode = _activity.requiresField;
final mq = MediaQuery.maybeOf(context);
final width = mq?.size.width ?? 9999;
final isTabletOrPhone = width < 1180;
final selection = _sidePanelSelectionLabel();
final title = _liveSidePanelMode == 'hr'
    ? 'Пульс Live'
    : _liveSidePanelMode == 'sprint'
        ? 'Скорость / спринты'
        : _liveSidePanelMode == 'signal'
            ? 'Сигнал устройств'
            : (isFieldMode ? 'Карта Live' : 'Активность / маршрут');
return _ofPanel(
  title: title,
  subtitle: isFieldMode ? selection : '${_activity.title} · $selection',
  actions: [
    _fieldPanelToggleButton(compact: true),
    _sideModeButton('Карта', Icons.map_rounded, 'map'),
    _sideModeButton('Пульс', Icons.favorite_rounded, 'hr'),
    _sideModeButton('Спринты', Icons.speed_rounded, 'sprint'),
    _sideModeButton('Сигнал', Icons.network_check_rounded, 'signal'),
    if (_liveSidePanelMode == 'map') ...[
      _layerButton('Трек', _showTrace, () => setState(() => _showTrace = !_showTrace)),
      _layerButton('Тепло', _showHeatmap, () => setState(() => _showHeatmap = !_showHeatmap)),
      _layerButton('Нагрузка', _showLoadHotPoints, () => setState(() => _showLoadHotPoints = !_showLoadHotPoints)),
    ],
    if (!_renderingFloatingLiveContent)
      _livePanelWindowButton(
        label: 'На весь экран',
        tooltip: _liveSidePanelMode == 'map' ? 'Развернуть live-карту по выбранным игрокам' : 'Открыть панель отдельным окном',
        onTap: () => _openExpandedLiveBlock(title, _liveSidePanelMode == 'map' ? Icons.map_rounded : Icons.open_in_full_rounded, () => _operatorSideContent()),
      ),
  ],
  child: _operatorSideContent(),
);
}

Widget _operatorSideContent() {
  switch (_liveSidePanelMode) {
    case 'hr':
      return _liveHeartRateSidePanel();
    case 'sprint':
      return _liveSprintSidePanel();
    case 'signal':
      return _liveSignalSidePanel();
    case 'map':
    default:
      return _fieldCard();
  }
}

Widget _sideModeButton(String label, IconData icon, String mode) {
  final active = _liveSidePanelMode == mode;
  return Padding(
    padding: const EdgeInsets.only(left: 4),
    child: _NoHoverTap(
      onTap: () => setState(() {
        _liveSidePanelMode = mode;
        _teamFieldPanelExpanded = true;
      }),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 24,
        padding: const EdgeInsets.symmetric(horizontal: 7),
        decoration: BoxDecoration(
          color: active ? _OF.greenSoft : Colors.white,
          border: Border.all(color: active ? _OF.greenBorder : _OF.line),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: active ? _OF.green : _OF.muted2),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: active ? _OF.green : _OF.text, fontSize: 9.6, fontWeight: FontWeight.w800)),
        ]),
      ),
    ),
  );
}

Widget _layerButton(String label, bool active, VoidCallback onTap) {
return Padding(
  padding: const EdgeInsets.only(left: 4),
  child: _NoHoverTap(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(color: active ? _OF.greenSoft : Colors.white, border: Border.all(color: active ? _OF.greenBorder : _OF.line), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: active ? _OF.green : _OF.text, fontSize: 10.4, fontWeight: FontWeight.w600)),
    ),
  ),
);
}

Widget _livePanelWindowButton({required String tooltip, required VoidCallback onTap, String label = 'Открыть'}) {
return Padding(
  padding: const EdgeInsets.only(left: 6),
  child: Tooltip(
    message: tooltip,
    child: Material(
      color: Colors.white,
      shape: const CircleBorder(),
      child: _NoHoverTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _OF.greenBorder),
            
          ),
          child: const Icon(Icons.open_in_full_rounded, size: 15, color: _OF.green),
        ),
      ),
    ),
  ),
);
}

Widget _wholeTeamTablePanel({bool compact = false, bool phoneCards = false}) {
final width = MediaQuery.maybeOf(context)?.size.width ?? 9999;
final hideWindowAction = width < 1180;
final players = widget.players;
final rows = _sessions.isNotEmpty ? _sessions : <TrackerLiveSessionModel>[];
final onlineCount = rows.where((s) => s.isOnline).length;
return _ofPanel(
  title: phoneCards ? 'Все игроки команды' : 'Игроки / live-данные',
  subtitle: _running ? '$onlineCount/$activeSessionCount онлайн · подключённые сверху' : 'Командная сводка · Анализ',
  actions: (_renderingFloatingLiveContent || phoneCards || hideWindowAction) ? const [] : [
    _livePanelWindowButton(
      label: 'На весь экран',
      tooltip: 'Открыть таблицу отдельным окном',
      onTap: () => _openExpandedLiveBlock('Игроки / live-данные', Icons.table_chart_rounded, () => _wholeTeamTablePanel(compact: false)),
    ),
  ],
  child: phoneCards
      ? _phonePlayersCardsList(players, rows)
      : Column(children: [
          _teamTableHeader(compact: compact),
          Expanded(
            child: players.isNotEmpty
                ? ListView.builder(
                    itemCount: players.length,
                    itemBuilder: (_, i) => _teamTableRowFromPlayer(players[i], i, compact: compact),
                  )
                : (rows.isEmpty
                    ? _teamTableFallback(compact: compact)
                    : ListView.builder(
                        itemCount: rows.length,
                        itemBuilder: (_, i) => _teamTableRowFromSession(rows[i], i, compact: compact),
                      )),
          ),
        ]),
);
}

Widget _phonePlayersCardsList(List<TrackerPlayerOption> players, List<TrackerLiveSessionModel> rows) {
if (players.isEmpty && rows.isEmpty) {
  return const Center(child: Text('Игроки и live-данные появятся после старта мониторинга.', textAlign: TextAlign.center, style: TextStyle(color: _OF.muted, fontSize: 11, fontWeight: FontWeight.w700)));
}
final sortedPlayers = List<TrackerPlayerOption>.from(players);
sortedPlayers.sort((a, b) {
  final aOnline = _isPlayerOnlineLive(a.id) ? 1 : 0;
  final bOnline = _isPlayerOnlineLive(b.id) ? 1 : 0;
  if (aOnline != bOnline) return bOnline.compareTo(aOnline);
  final aSelected = widget.selectedPlayer?.id == a.id ? 1 : 0;
  final bSelected = widget.selectedPlayer?.id == b.id ? 1 : 0;
  if (aSelected != bSelected) return bSelected.compareTo(aSelected);
  return (int.tryParse(a.number ?? '') ?? 9999).compareTo(int.tryParse(b.number ?? '') ?? 9999);
});
final sortedRows = List<TrackerLiveSessionModel>.from(rows);
sortedRows.sort((a, b) {
  final aOnline = a.isOnline ? 1 : 0;
  final bOnline = b.isOnline ? 1 : 0;
  if (aOnline != bOnline) return bOnline.compareTo(aOnline);
  return b.loadScore.compareTo(a.loadScore);
});
final itemCount = sortedPlayers.isNotEmpty ? sortedPlayers.length : sortedRows.length;
return ListView.separated(
  padding: const EdgeInsets.fromLTRB(6, 5, 6, 8),
  itemCount: itemCount,
  separatorBuilder: (_, __) => const SizedBox(height: 4),
  itemBuilder: (_, i) {
    if (sortedPlayers.isNotEmpty) return _phonePlayerCardFromPlayer(sortedPlayers[i], i);
    return _phonePlayerCardFromSession(sortedRows[i], i);
  },
);
}

Widget _phonePlayerCardFromPlayer(TrackerPlayerOption p, int i) {
final session = _sessionForPlayer(p.id);
final local = _localTrackForPlayer(p.id);
final selected = widget.selectedPlayer?.id == p.id;
return _phonePlayerCard(
  player: p,
  number: '${p.number ?? i + 1}',
  name: p.name,
  online: _isPlayerOnlineLive(p.id) || session?.isOnline == true || (selected && (_mainTrack?.points.isNotEmpty ?? false)),
  distance: math.max(session?.totalDistanceM ?? 0.0, local?.totalDistanceM ?? 0.0),
  metersPerMin: math.max(session?.metersPerMinute ?? 0.0, local?.metersPerMinute ?? 0.0),
  load: math.max(session?.loadScore ?? 0.0, local?.loadScore ?? 0.0),
  max: math.max(session?.maxSpeedKmh ?? 0.0, local?.maxSpeedKmh ?? 0.0),
  sprint: math.max(session?.sprintDistanceM ?? 0.0, local?.sprintDistanceM ?? 0.0),
  heartRateBpm: _heartRateForPlayerId(p.id)?.bpm,
  highlight: selected,
  monitoring: _isPlayerInMonitorGrid(p.id),
  onTap: () => _selectPlayerAndOpenDetails(p),
  onAnalyzeTap: () => _toggleMonitorPlayer(p),
);
}

Widget _phonePlayerCardFromSession(TrackerLiveSessionModel s, int i) {
final playerId = _resolvedPlayerIdForSession(s);
final local = _localTrackForPlayer(playerId);
final player = _playerForSession(s);
final option = player ?? TrackerPlayerOption(id: playerId ?? 0, name: _sessionDisplayName(s), avatar: s.avatarUrl, number: _sessionDisplayNumber(s, i));
return _phonePlayerCard(
  player: option,
  number: _sessionDisplayNumber(s, i),
  name: option.name,
  online: s.isOnline || _isPlayerOnlineLive(option.id),
  distance: math.max(s.totalDistanceM, local?.totalDistanceM ?? 0.0),
  metersPerMin: math.max(s.metersPerMinute, local?.metersPerMinute ?? 0.0),
  load: math.max(s.loadScore, local?.loadScore ?? 0.0),
  max: math.max(s.maxSpeedKmh, local?.maxSpeedKmh ?? 0.0),
  sprint: math.max(s.sprintDistanceM, local?.sprintDistanceM ?? 0.0),
  heartRateBpm: _heartRateForPlayerId(option.id)?.bpm,
  highlight: widget.selectedPlayer?.id == option.id,
  monitoring: _isPlayerInMonitorGrid(option.id),
  onTap: () => _selectPlayerAndOpenDetails(option),
  onAnalyzeTap: () => _toggleMonitorPlayer(option),
);
}

Widget _phonePlayerCard({
  required TrackerPlayerOption? player,
  required String number,
  required String name,
  required bool online,
  required double distance,
  required double metersPerMin,
  required double load,
  required double max,
  required double sprint,
  required int? heartRateBpm,
  required bool highlight,
  required bool monitoring,
  required VoidCallback? onTap,
  required VoidCallback? onAnalyzeTap,
}) {
final mark = _loadMarkLabel(load, heartRateBpm: heartRateBpm);
return Material(
  color: Colors.transparent,
  borderRadius: BorderRadius.circular(4),
  child: _NoHoverTap(
    onTap: onTap,
    borderRadius: BorderRadius.circular(4),
    child: Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: highlight ? const Color(0xFFFFF8F1) : Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: highlight ? _OF.orange.withOpacity(.34) : _OF.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _playerAvatarCircle(player: player, radius: 18, online: online || highlight),
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: Container(
                      width: 18,
                      height: 18,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: highlight ? _OF.orange : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: online ? _OF.greenBorder : _OF.line),
                      ),
                      child: Text(number, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: highlight ? Colors.white : _OF.green, fontSize: 9.6, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _OF.text, fontSize: 11.0, fontWeight: FontWeight.w700)),
                    Text(online ? 'онлайн · данные обновляются' : 'ожидаем данные трекера', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: online ? _OF.green : _OF.muted2, fontSize: 9.6, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              _analysisRowButton(compact: true, highlighted: monitoring, onTap: onAnalyzeTap),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              _phoneStatChip('Дист.', '${distance.toStringAsFixed(0)} м'),
              _phoneStatChip('м/мин', metersPerMin.toStringAsFixed(1)),
              _phoneStatChip('Max', '${max.toStringAsFixed(1)} км/ч'),
              _phoneStatChip('Пульс', heartRateBpm == null ? '—' : '$heartRateBpm'),
              _phoneStatChip('Нагр.', load.toStringAsFixed(0)),
              _phoneStatChip('Метка', mark),
              _phoneStatChip('SPR', sprint.toStringAsFixed(0)),
            ],
          ),
        ],
      ),
    ),
  ),
);
}

Widget _phoneStatChip(String label, String value) {
return Container(
  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text('$label ', style: const TextStyle(color: _OF.muted2, fontSize: 9.6, fontWeight: FontWeight.w700)),
      Text(value, style: const TextStyle(color: _OF.text, fontSize: 9.6, fontWeight: FontWeight.w700)),
    ],
  ),
);
}

int get activeSessionCount => _sessions.where((s) => s.status == 'active').length;

Widget _teamTableHeader({required bool compact}) {
final cells = compact
    ? const ['№', 'ИГРОК', 'ДИСТ.', 'ПУЛЬС', 'НАГР.', 'МЕТКА']
    : const ['№', 'ИГРОК', 'ДИСТ.', 'М/МИН', 'MAX', 'ПУЛЬС', 'НАГР.', 'МЕТКА', 'HIR', 'SPR', 'ACC', 'DEC'];
return Container(
  height: compact ? 30 : 32,
  color: Colors.white,
  child: Row(children: [
    ...cells.map((c) => Expanded(flex: c == 'ИГРОК' ? (compact ? 5 : 4) : (c == 'МЕТКА' ? 2 : 1), child: Center(child: Text(c, style: const TextStyle(color: _OF.text, fontSize: 11.2, fontWeight: FontWeight.w700))))),
    SizedBox(width: compact ? 78 : 84, child: const Center(child: Text('ОКНА', style: TextStyle(color: _OF.green, fontSize: 10.4, fontWeight: FontWeight.w700)))),
  ]),
);
}

Widget _teamTableFallback({required bool compact}) {
final players = widget.players;
if (players.isEmpty) return const Center(child: Text('Live-данные появятся после старта мониторинга', style: TextStyle(color: _OF.muted, fontWeight: FontWeight.w500)));
return ListView.builder(
  itemCount: players.length,
  itemBuilder: (_, i) {
    final p = players[i];
    return _teamTableRow(
      number: '${p.number ?? i + 1}',
      name: p.name,
      distance: widget.selectedPlayer?.id == p.id ? _displayDistanceM : 0,
      metersPerMin: widget.selectedPlayer?.id == p.id ? (_mainTrack?.metersPerMinute ?? 0) : 0,
      load: widget.selectedPlayer?.id == p.id ? (_mainTrack?.loadScore ?? 0) : 0,
      max: widget.selectedPlayer?.id == p.id ? (_mainTrack?.maxSpeedKmh ?? 0) : 0,
      hir: widget.selectedPlayer?.id == p.id ? (_mainTrack?.hirDistanceM ?? 0) : 0,
      vhir: widget.selectedPlayer?.id == p.id ? (_mainTrack?.vhirDistanceM ?? 0) : 0,
      sprint: widget.selectedPlayer?.id == p.id ? (_mainTrack?.sprintDistanceM ?? 0) : 0,
      accel: widget.selectedPlayer?.id == p.id ? (_mainTrack?.accelCount ?? 0) : 0,
      decel: widget.selectedPlayer?.id == p.id ? (_mainTrack?.decelCount ?? 0) : 0,
      cod: widget.selectedPlayer?.id == p.id ? (_mainTrack?.changeOfDirectionCount ?? 0) : 0,
      heartRateBpm: _heartRateForPlayerId(p.id)?.bpm,
      compact: compact,
      highlight: widget.selectedPlayer?.id == p.id,
      monitoring: _isPlayerInMonitorGrid(p.id),
      onTap: () => _selectPlayerAndOpenDetails(p),
      onAnalyzeTap: () => _toggleMonitorPlayer(p),
    );
  },
);
}

Widget _teamTableRowFromPlayer(TrackerPlayerOption p, int i, {required bool compact}) {
TrackerLiveSessionModel? session;
for (final s in _sessions) {
  if (s.playerId == p.id) {
    session = s;
    break;
  }
}
final local = _localTrackForPlayer(p.id);
final selected = widget.selectedPlayer?.id == p.id;
return _teamTableRow(
  number: '${p.number ?? i + 1}',
  name: p.name,
  distance: math.max(session?.totalDistanceM ?? 0.0, local?.totalDistanceM ?? 0.0),
  metersPerMin: math.max(session?.metersPerMinute ?? 0.0, local?.metersPerMinute ?? 0.0),
  load: math.max(session?.loadScore ?? 0.0, local?.loadScore ?? 0.0),
  max: math.max(session?.maxSpeedKmh ?? 0.0, local?.maxSpeedKmh ?? 0.0),
  hir: math.max(session?.hirDistanceM ?? 0.0, local?.hirDistanceM ?? 0.0),
  vhir: math.max(session?.vhirDistanceM ?? 0.0, local?.vhirDistanceM ?? 0.0),
  sprint: math.max(session?.sprintDistanceM ?? 0.0, local?.sprintDistanceM ?? 0.0),
  accel: math.max(session?.accelCount ?? 0, local?.accelCount ?? 0),
  decel: math.max(session?.decelCount ?? 0, local?.decelCount ?? 0),
  cod: math.max(session?.changeOfDirectionCount ?? 0, local?.changeOfDirectionCount ?? 0),
  heartRateBpm: _heartRateForPlayerId(p.id)?.bpm,
  compact: compact,
  highlight: selected,
  monitoring: _isPlayerInMonitorGrid(p.id),
  onTap: () => _selectPlayerAndOpenDetails(p),
  onAnalyzeTap: () => _toggleMonitorPlayer(p),
);
}

Widget _teamTableRowFromSession(TrackerLiveSessionModel s, int i, {required bool compact}) {
final playerId = _resolvedPlayerIdForSession(s);
final local = _localTrackForPlayer(playerId);
final player = _playerForSession(s);
final option = player ?? TrackerPlayerOption(id: playerId ?? 0, name: _sessionDisplayName(s), avatar: s.avatarUrl, number: _sessionDisplayNumber(s, i));
return _teamTableRow(
  number: _sessionDisplayNumber(s, i),
  name: option.name,
  distance: math.max(s.totalDistanceM, local?.totalDistanceM ?? 0.0),
  metersPerMin: math.max(s.metersPerMinute, local?.metersPerMinute ?? 0.0),
  load: math.max(s.loadScore, local?.loadScore ?? 0.0),
  max: math.max(s.maxSpeedKmh, local?.maxSpeedKmh ?? 0.0),
  hir: math.max(s.hirDistanceM, local?.hirDistanceM ?? 0.0),
  vhir: math.max(s.vhirDistanceM, local?.vhirDistanceM ?? 0.0),
  sprint: math.max(s.sprintDistanceM, local?.sprintDistanceM ?? 0.0),
  accel: math.max(s.accelCount, local?.accelCount ?? 0),
  decel: math.max(s.decelCount, local?.decelCount ?? 0),
  cod: math.max(s.changeOfDirectionCount, local?.changeOfDirectionCount ?? 0),
  heartRateBpm: _heartRateForPlayerId(option.id)?.bpm,
  compact: compact,
  highlight: widget.selectedPlayer?.id == option.id,
  monitoring: _isPlayerInMonitorGrid(option.id),
  onTap: () => _selectPlayerAndOpenDetails(option),
  onAnalyzeTap: () => _toggleMonitorPlayer(option),
);
}

Widget _teamTableRow({required String number, required String name, required double distance, required double metersPerMin, required double load, required double max, required double hir, required double vhir, required double sprint, required num accel, required num decel, required num cod, required int? heartRateBpm, required bool compact, required bool highlight, required bool monitoring, VoidCallback? onTap, VoidCallback? onAnalyzeTap}) {
final displayName = compact ? _compactPlayerName(name) : name;
final mark = _loadMarkLabel(load, heartRateBpm: heartRateBpm);
final values = compact
    ? <String>[number, displayName, distance.toStringAsFixed(0), heartRateBpm == null ? '—' : '$heartRateBpm', load.toStringAsFixed(0), mark]
    : <String>[number, displayName, distance.toStringAsFixed(0), metersPerMin.toStringAsFixed(1), max.toStringAsFixed(1), heartRateBpm == null ? '—' : '$heartRateBpm', load.toStringAsFixed(0), mark, hir.toStringAsFixed(0), sprint.toStringAsFixed(0), accel.toStringAsFixed(0), decel.toStringAsFixed(0)];
final row = Container(
  height: compact ? 42 : 40,
  color: highlight ? const Color(0xFFFFE7D1) : Colors.white,
  child: Row(children: [
    for (var i = 0; i < values.length; i++)
      Expanded(
        flex: i == 1 ? (compact ? 5 : 4) : ((compact ? i == 5 : i == 7) ? 2 : 1),
        child: Container(
          alignment: i == 1 ? Alignment.centerLeft : Alignment.center,
          padding: EdgeInsets.only(left: i == 1 ? 8 : 0),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _OF.line), right: BorderSide(color: _OF.line))),
          child: Text(
            values[i],
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: (compact ? i == 5 : i == 7)
                  ? _loadMarkColor(load, heartRateBpm: heartRateBpm)
                  : (highlight && i == 1 ? _OF.orange : _OF.text),
              fontSize: compact ? 9.8 : 9.4,
              fontWeight: (highlight && i == 1) || (compact ? i == 5 : i == 7) ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
      ),
    Container(
      width: compact ? 64 : 72,
      height: double.infinity,
      alignment: Alignment.center,
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _OF.line))),
      child: _analysisRowButton(compact: compact, highlighted: monitoring, onTap: onAnalyzeTap ?? onTap),
    ),
  ]),
);
return Material(color: Colors.transparent, child: _NoHoverTap(onTap: onTap, hoverColor: _OF.greenSoft.withOpacity(.45), splashColor: _OF.greenSoft, child: row));
}

Widget _analysisRowButton({required bool compact, required bool highlighted, VoidCallback? onTap}) {
if (compact) {
  return Tooltip(
    message: highlighted ? 'Убрать live-окно' : 'Добавить live-окно',
    child: Material(
      color: highlighted ? _OF.green : _OF.greenSoft,
      shape: const CircleBorder(),
      child: _NoHoverTap(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: highlighted ? _OF.green : _OF.greenBorder)),
          child: Icon(highlighted ? Icons.check_rounded : Icons.add_rounded, size: 15, color: highlighted ? Colors.white : _OF.green),
        ),
      ),
    ),
  );
}
return Material(
  color: highlighted ? _OF.green : _OF.greenSoft,
  borderRadius: BorderRadius.circular(999),
  child: _NoHoverTap(
    onTap: onTap,
    borderRadius: BorderRadius.circular(999),
    child: Container(
      height: 27,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(highlighted ? Icons.check_rounded : Icons.add_rounded, size: 12, color: highlighted ? Colors.white : _OF.green),
          const SizedBox(width: 4),
          Text(highlighted ? 'Окно' : 'Добавить', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: highlighted ? Colors.white : _OF.green, fontSize: 11.2, fontWeight: FontWeight.w700)),
        ],
      ),
    ),
  ),
);
}


void _selectPlayerAndOpenDetails(TrackerPlayerOption player) {
if (!_running) _blockServerAutoRestoreAfterPlayerPick = true;
widget.onSelectPlayer?.call(player);
if (_phoneLiveSheetVisible) {
  Navigator.of(context).maybePop();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) unawaited(_openPlayerLiveDetails(player));
  });
  return;
}
unawaited(_openPlayerLiveDetails(player));
}

void _selectPlayerForAnalytics(TrackerPlayerOption player) {
final isPhone = (MediaQuery.maybeOf(context)?.size.width ?? 9999) < 720;
if (_phoneLiveSheetVisible) {
  Navigator.of(context).maybePop();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    if (isPhone) {
      unawaited(_openPhonePlayerAnalysisSheet(player));
    } else {
      unawaited(_openPlayerLiveDetails(player));
    }
  });
  return;
}
if (isPhone) {
  unawaited(_openPhonePlayerAnalysisSheet(player));
} else {
  unawaited(_openPlayerLiveDetails(player));
}
}

Future<void> _openPlayerLiveDetails(TrackerPlayerOption player) async {
Timer? refreshTimer;
var dialogOpen = true;

await showGeneralDialog<void>(
  context: context,
  barrierDismissible: true,
  barrierLabel: 'Закрыть',
  barrierColor: Colors.black.withOpacity(.20),
  transitionDuration: const Duration(milliseconds: 180),
  pageBuilder: (dialogContext, animation, secondaryAnimation) {
    return StatefulBuilder(
      builder: (context, setSheetState) {
        refreshTimer ??= Timer.periodic(const Duration(milliseconds: 900), (_) {
          if (dialogOpen && mounted) setSheetState(() {});
        });
        final size = MediaQuery.of(context).size;
        final bool phone = size.width < 720;
        final bool tablet = size.width >= 760 && size.width < 1280;
        final double width = phone ? size.width : (tablet ? math.min(880.0, size.width * .82) : math.min(1040.0, size.width * .92));
        final double height = phone ? size.height : (tablet ? math.min(660.0, size.height * .86) : math.min(720.0, size.height * .88));
        return SafeArea(
          bottom: !phone,
          child: Align(
            alignment: phone ? Alignment.center : (tablet ? Alignment.centerRight : Alignment.center),
            child: Padding(
              padding: phone ? EdgeInsets.zero : EdgeInsets.only(left: tablet ? 14 : 18, right: tablet ? 18 : 18, top: 18, bottom: 18),
              child: Material(
                color: Colors.white,
                elevation: phone ? 0 : 18,
                shadowColor: Colors.black.withOpacity(.07),
                borderRadius: BorderRadius.circular(phone ? 0 : 24),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(phone ? 0 : 24),
                  child: SizedBox(
                    width: width,
                    height: height,
                    child: _playerLiveDetailsContent(player, onClose: () => Navigator.of(dialogContext).pop()),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  },
  transitionBuilder: (context, animation, secondaryAnimation, child) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    return FadeTransition(opacity: curved, child: SlideTransition(position: Tween<Offset>(begin: const Offset(.06, 0), end: Offset.zero).animate(curved), child: child));
  },
).whenComplete(() {
  dialogOpen = false;
  refreshTimer?.cancel();
});
}

Widget _playerLiveDetailsContent(TrackerPlayerOption player, {required VoidCallback onClose}) {
final local = _localTrackForPlayer(player.id);
final session = _sessionForPlayer(player.id);
final displayTrack = _displayTrackForPlayer(player);
final online = session?.isOnline == true || (local != null && local.points.isNotEmpty && _running);
final speed = math.max(session?.speedKmh ?? 0.0, local?.speedKmh ?? 0.0);
final distance = math.max(session?.totalDistanceM ?? 0.0, local?.totalDistanceM ?? 0.0);
final mpm = math.max(session?.metersPerMinute ?? 0.0, local?.metersPerMinute ?? 0.0);
final maxSpeed = math.max(session?.maxSpeedKmh ?? 0.0, local?.maxSpeedKmh ?? 0.0);
final load = math.max(session?.loadScore ?? 0.0, local?.loadScore ?? 0.0);
final hir = math.max(session?.hirDistanceM ?? 0.0, local?.hirDistanceM ?? 0.0);
final vhir = math.max(session?.vhirDistanceM ?? 0.0, local?.vhirDistanceM ?? 0.0);
final sprint = math.max(session?.sprintDistanceM ?? 0.0, local?.sprintDistanceM ?? 0.0);
final accel = math.max(session?.accelCount ?? 0, local?.accelCount ?? 0);
final decel = math.max(session?.decelCount ?? 0, local?.decelCount ?? 0);
final cod = math.max(session?.changeOfDirectionCount ?? 0, local?.changeOfDirectionCount ?? 0);
final durationSec = math.max(session?.durationSec ?? 0, local?.durationSec ?? 0);
final deviceName = session?.deviceName ?? local?.deviceName ?? widget.ble.connectedInfo?.name ?? 'Трекер не подключён';
final heartRate = _heartRateForPlayerId(player.id);
final heartRateStatus = _heartRateValueLabel(heartRate);
final heartRateZone = _heartRateZoneLabelForSample(heartRate);
final phone = MediaQuery.of(context).size.width < 720;

return Column(
  children: [
    Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: _OF.line))),
      child: Row(
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: online ? _OF.green : _OF.header,
            backgroundImage: (player.avatar ?? '').isNotEmpty ? NetworkImage(player.avatar!) : null,
            child: (player.avatar ?? '').isEmpty ? Text(_playerInitials(player.name), style: TextStyle(color: online ? Colors.white : _OF.graphite, fontWeight: FontWeight.w700, fontSize: 11)) : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(player.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _OF.text, fontSize: 14.5, fontWeight: FontWeight.w700, letterSpacing: -.2)),
                const SizedBox(height: 3),
                Row(children: [
                  _ofStatusDot(online ? _OF.green : _OF.orange),
                  const SizedBox(width: 6),
                  Flexible(child: Text(online ? 'онлайн · $deviceName${heartRate == null ? '' : ' · $heartRateStatus'}' : 'ожидание Live · $deviceName${heartRate == null ? '' : ' · $heartRateStatus'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _OF.muted, fontSize: 11.2, fontWeight: FontWeight.w600))),
                ]),
              ],
            ),
          ),
          if (!phone) ...[
            _LiveDetailHeaderChip(icon: Icons.timer_rounded, label: durationSec <= 0 ? _durationText() : _formatDuration(Duration(seconds: durationSec))),
            const SizedBox(width: 8),
            _LiveDetailHeaderChip(icon: Icons.speed_rounded, label: '${speed.toStringAsFixed(1)} км/ч'),
            const SizedBox(width: 8),
            _LiveDetailHeaderChip(icon: Icons.monitor_heart_rounded, label: heartRate == null ? 'пульс —' : '$heartRateStatus · $heartRateZone'),
            const SizedBox(width: 8),
          ],
          _NoHoverTap(onTap: onClose, child: Container(width: 34, height: 34, alignment: Alignment.center, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)), child: const Icon(Icons.close_rounded, color: _OF.graphite, size: 20))),
        ],
      ),
    ),
    Expanded(
      child: LayoutBuilder(
        builder: (context, c) {
          final vertical = c.maxWidth < 760;
          final dataPanel = _playerLiveMetricPanel(speed: speed, distance: distance, metersPerMin: mpm, maxSpeed: maxSpeed, load: load, hir: hir, vhir: vhir, sprint: sprint, accel: accel, decel: decel, cod: cod, track: displayTrack, heartRate: heartRate);
          final fieldPanel = _playerLiveFieldPanel(player: player, track: displayTrack);
          if (vertical) {
            return Column(children: [Expanded(flex: 7, child: fieldPanel), _ofHorizontalDivider(), Expanded(flex: 6, child: dataPanel)]);
          }
          return Row(children: [Expanded(flex: 45, child: dataPanel), _ofVerticalDivider(), Expanded(flex: 55, child: fieldPanel)]);
        },
      ),
    ),
  ],
);
}

Widget _playerLiveMetricPanel({required double speed, required double distance, required double metersPerMin, required double maxSpeed, required double load, required double hir, required double vhir, required double sprint, required num accel, required num decel, required num cod, required _RuntimeTrack? track, required HeartRateSample? heartRate}) {
return Container(
  color: Colors.white,
  child: ListView(
    padding: const EdgeInsets.all(9),
    children: [
      const Text('Онлайн-показ данных', style: TextStyle(color: _OF.text, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: -.1)),
      const SizedBox(height: 4),
      const Text('Показатели обновляются во время Live-сессии', style: TextStyle(color: _OF.muted, fontSize: 10.4, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 2.45,
        children: [
          _PlayerMetricTile(icon: Icons.route_rounded, label: 'Дистанция', value: '${(distance / 1000).toStringAsFixed(2)} км'),
          _PlayerMetricTile(icon: Icons.speed_rounded, label: 'Скорость', value: speed.toStringAsFixed(1)),
          _PlayerMetricTile(icon: Icons.bolt_rounded, label: 'Макс.', value: maxSpeed.toStringAsFixed(1)),
          _PlayerMetricTile(icon: Icons.trending_up_rounded, label: 'М/мин', value: metersPerMin.toStringAsFixed(0)),
          _PlayerMetricTile(icon: Icons.monitor_heart_rounded, label: 'Пульс', value: _heartRateValueLabel(heartRate)),
          _PlayerMetricTile(icon: Icons.favorite_rounded, label: 'Зона ЧСС', value: _heartRateZoneLabelForSample(heartRate)),
          _PlayerMetricTile(icon: Icons.local_fire_department_rounded, label: 'Нагрузка', value: load.toStringAsFixed(0)),
          _PlayerMetricTile(icon: Icons.timeline_rounded, label: 'Точки', value: '${track?.points.length ?? 0}'),
        ],
      ),
      const SizedBox(height: 8),
      _loadMarkBanner(load: load, heartRate: heartRate),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Интенсивность', style: TextStyle(color: _OF.text, fontSize: 11.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _detailBandRow('HIR', hir, math.max(1.0, math.max(hir, math.max(vhir, sprint))), _OF.orange),
          _detailBandRow('VHIR', vhir, math.max(1.0, math.max(hir, math.max(vhir, sprint))), _OF.cyan),
          _detailBandRow('SPR', sprint, math.max(1.0, math.max(hir, math.max(vhir, sprint))), _OF.red),
        ]),
      ),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _SmallEventCounter(label: 'ACC', value: accel.toStringAsFixed(0))),
        const SizedBox(width: 8),
        Expanded(child: _SmallEventCounter(label: 'DEC', value: decel.toStringAsFixed(0))),
        const SizedBox(width: 8),
        Expanded(child: _SmallEventCounter(label: 'COD', value: cod.toStringAsFixed(0))),
      ]),
      const SizedBox(height: 8),
      _HeartRateLiveCard(
        sample: heartRate,
        teamOnlineCount: widget.heartRateByPlayerId.length,
        recommendation: _heartRateLiveRecommendation(track: track, sample: heartRate),
      ),
      const SizedBox(height: 8),
      _TeamHeartRateOnlineCard(
        players: widget.players,
        samples: widget.heartRateByPlayerId,
      ),
      const SizedBox(height: 8),
      _ProblemBox(text: _combinedLiveRecommendation(track: track, sample: heartRate)),
    ],
  ),
);
}


Widget _loadMarkBanner({required double load, required HeartRateSample? heartRate}) {
final mark = _loadMarkLabel(load, heartRateBpm: heartRate?.bpm);
final color = _loadMarkColor(load, heartRateBpm: heartRate?.bpm);
return Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
  decoration: BoxDecoration(color: color.withOpacity(.08), borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withOpacity(.22))),
  child: Row(
    children: [
      Container(width: 30, height: 30, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)), child: Icon(Icons.flag_rounded, size: 16, color: color)),
      const SizedBox(width: 8),
      Expanded(child: Text('Метка нагрузки: $mark', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w700))),
      Text(heartRate == null ? 'пульс —' : '${heartRate.bpm} bpm', style: const TextStyle(color: _OF.text, fontSize: 11.2, fontWeight: FontWeight.w700)),
    ],
  ),
);
}

Widget _playerLiveFieldPanel({required TrackerPlayerOption player, required _RuntimeTrack? track}) {
final hasTrack = track != null && track.points.isNotEmpty;
return Container(
  color: const Color(0xFFF8F9FA),
  padding: const EdgeInsets.all(8),
  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      Container(width: 34, height: 34, decoration: BoxDecoration(color: _OF.greenSoft, borderRadius: BorderRadius.circular(6)), child: Icon(_activity.requiresField ? Icons.map_rounded : Icons.route_rounded, color: _OF.green, size: 18)),
      const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_activity.requiresField ? 'Точка и траектория на поле' : 'Маршрут активности', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _OF.text, fontSize: 12.5, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(hasTrack ? 'движение игрока отображается отдельно от команды' : 'ожидаем GPS-точки игрока', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _OF.muted, fontSize: 11.2, fontWeight: FontWeight.w700)),
      ])),
      if (_activity.requiresField) ...[
        _LayerChip(label: 'Трек', active: _showTrace, onTap: () => setState(() => _showTrace = !_showTrace)),
        const SizedBox(width: 6),
        _LayerChip(label: 'Тепло', active: _showHeatmap, onTap: () => setState(() => _showHeatmap = !_showHeatmap)),
      ],
    ]),
    const SizedBox(height: 8),
    Expanded(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
          child: _activity.requiresField
              ? CustomPaint(
                  painter: _RuntimeFieldPainter(field: widget.selectedField, tracks: hasTrack ? <_RuntimeTrack>[track] : const <_RuntimeTrack>[], showVectors: _showVectors, showHeatmap: _showHeatmap, showTrace: _showTrace, showLabels: true),
                  child: const SizedBox.expand(),
                )
              : CustomPaint(
                  painter: _OpenFieldTimelinePainter(points: track?.points ?? const <_RuntimePoint>[], running: _running, progressRatio: _timelineProgressRatio()),
                  child: Center(child: Text(hasTrack ? 'Активность без привязки к полю' : 'Ожидание движения игрока', style: const TextStyle(color: _OF.muted, fontSize: 11, fontWeight: FontWeight.w700))),
                ),
        ),
      ),
    ),
  ]),
);
}

Widget _detailBandRow(String label, double value, double max, Color color) {
return Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: Row(children: [
    SizedBox(width: 42, child: Text(label, style: const TextStyle(color: _OF.text, fontSize: 10.4, fontWeight: FontWeight.w600))),
    Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(999), child: LinearProgressIndicator(value: (value / max).clamp(0.0, 1.0).toDouble(), minHeight: 8, backgroundColor: Colors.white, valueColor: AlwaysStoppedAnimation<Color>(color)))),
    const SizedBox(width: 8),
    SizedBox(width: 48, child: Text('${value.toStringAsFixed(0)} м', textAlign: TextAlign.right, style: const TextStyle(color: _OF.text, fontSize: 11.2, fontWeight: FontWeight.w700))),
  ]),
);
}

Widget _rightOperatorPanel(int online, int active) {
return _ofPanel(
  title: 'Оператор',
  subtitle: 'группа / игрок / трекер',
  child: ListView(
    padding: const EdgeInsets.all(8),
    children: [
      _pipGroupPanel(online, active),
      const SizedBox(height: 8),
      _selectedAthletePanel(),
      const SizedBox(height: 8),
      _velocityBandsPanel(),
      const SizedBox(height: 8),
      _trackerDevicePanel(),
      const SizedBox(height: 8),
      _ProblemBox(text: _lastProblem),
    ],
  ),
);
}

Widget _tabletBottomInfoPanel(int online, int active) {
// Debug виден прямо в нижнем ряду планшетного/оконного layout.
// На скрине пользователя открывался именно этот layout, поэтому правый блок "Оператор" не отображался.
return Row(children: [
  Expanded(child: _pipGroupPanel(online, active)),
  _ofVerticalDivider(),
  Expanded(child: _velocityBandsPanel()),
  _ofVerticalDivider(),
  Expanded(child: _trackerDevicePanel()),
]);
}

Widget _pipGroupPanel(int online, int active) {
final ids = widget.players.take(12).map((p) => '${p.number ?? p.id}').toList();
return _miniOfCard('Группа PIP', 'Group ($active)', Wrap(spacing: 5, runSpacing: 5, children: ids.isEmpty ? [const Text('Нет игроков', style: TextStyle(color: _OF.muted, fontWeight: FontWeight.w500))] : ids.map((id) => Container(
  width: 42,
  height: 26,
  alignment: Alignment.center,
  decoration: BoxDecoration(color: _OF.pip, border: Border.all(color: _OF.green.withOpacity(.28)), borderRadius: BorderRadius.circular(4)),
  child: Text(id, style: const TextStyle(color: _OF.text, fontSize: 11.2, fontWeight: FontWeight.w500)),
)).toList()));
}

Widget _selectedAthletePanel() {
final player = widget.selectedPlayer;
return _miniOfCard('Выбран игрок', player?.name ?? 'не выбран', Row(children: [
  _playerAvatarCircle(player: player, radius: 18, online: player != null),
  const SizedBox(width: 8),
  Expanded(child: Text(player?.name ?? 'Выберите игрока слева', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _OF.text, fontSize: 11.2, fontWeight: FontWeight.w700))),
  if (player != null) ...[
    const SizedBox(width: 6),
    SizedBox(
      height: 28,
      child: FilledButton.icon(
        onPressed: () => _selectPlayerForAnalytics(player),
        style: FilledButton.styleFrom(
          backgroundColor: _OF.green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          elevation: 0,
        ),
        icon: const Icon(Icons.analytics_rounded, size: 13),
        label: const Text('Анализ', style: TextStyle(fontSize: 10.4, fontWeight: FontWeight.w700)),
      ),
    ),
  ],
]));
}

Widget _velocityBandsPanel() {
final track = _mainTrack;
final double hir = (track?.hirDistanceM ?? 0).toDouble();
final double vhir = (track?.vhirDistanceM ?? 0).toDouble();
final double sprint = (track?.sprintDistanceM ?? 0).toDouble();
final double run = math.max(0.0, (track?.totalDistanceM ?? 0).toDouble() - hir - vhir - sprint).toDouble();
final double maxVal = math.max(1.0, math.max(run, math.max(hir, math.max(vhir, sprint)))).toDouble();
return _miniOfCard('Зоны скорости', 'бег / HIR / VHIR / спринт', Column(children: [
  _bandRow('Run', run, maxVal, _OF.green),
  _bandRow('HIR', hir, maxVal, _OF.orange),
  _bandRow('VHIR', vhir, maxVal, _OF.cyan),
  _bandRow('SPR', sprint, maxVal, _OF.red),
]));
}

Widget _bandRow(String label, double value, double max, Color color) {
return Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: Row(children: [
    SizedBox(width: 42, child: Text(label, style: const TextStyle(color: _OF.text, fontSize: 11.2, fontWeight: FontWeight.w500))),
    Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(2), child: LinearProgressIndicator(value: (value / max).clamp(0, 1), minHeight: 8, backgroundColor: _OF.line, valueColor: AlwaysStoppedAnimation<Color>(color)))),
    const SizedBox(width: 8),
    SizedBox(width: 42, child: Text('${value.toStringAsFixed(0)} м', textAlign: TextAlign.right, style: const TextStyle(color: _OF.text, fontSize: 10.4, fontWeight: FontWeight.w500))),
  ]),
);
}

Widget _trackerDevicePanel() {
final device = widget.ble.connectedInfo ?? widget.ble.lastKnownInfo;
final ready = widget.ble.commandChannelReady;
final title = ready ? (device?.name ?? 'Подключён') : (device == null ? 'Не подключён' : '${device.name} · вне зоны');
return _miniOfCard('Трекер', title, Row(children: [
  Container(
    width: 72,
    height: 60,
    decoration: BoxDecoration(color: _OF.black, borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.black12)),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.asset('assets/images/sportoteka_tracker_kit.png', fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.sensors_rounded, color: Colors.white, size: 30)),
    ),
  ),
  const SizedBox(width: 8),
  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
    Text(device == null ? 'SPORTOTEKA GPS PRO' : device.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _OF.text, fontSize: 11.2, fontWeight: FontWeight.w500)),
    const SizedBox(height: 3),
    Row(children: [_ofStatusDot(ready ? _OF.green : (device == null ? _OF.red : _OF.orange)), const SizedBox(width: 5), Expanded(child: Text(ready ? 'TX/RX готов' : (device == null ? 'Офлайн' : 'Вне зоны · автопоиск'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _OF.text, fontSize: 11.2, fontWeight: FontWeight.w500)))]),
    const SizedBox(height: 3),
    Text(_offlineRecorderStatus, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _OF.muted2, fontSize: 11.0, fontWeight: FontWeight.w600)),
    const SizedBox(height: 5),
    SizedBox(
      height: 28,
      child: OutlinedButton.icon(
        onPressed: widget.scanningBluetooth
            ? null
            : (!ready ? (widget.onScanBluetooth ?? widget.onManageTrackers) : widget.onManageTrackers),
        icon: widget.scanningBluetooth
            ? const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 2))
            : Icon(!ready ? Icons.bluetooth_searching_rounded : Icons.sensors_rounded, size: 14),
        label: Text(widget.scanningBluetooth ? 'Поиск...' : (!ready ? 'Найти в зоне' : 'Сменить')),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          foregroundColor: _OF.graphite,
          side: BorderSide.none,
          backgroundColor: const Color(0xFFF1F3F6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    ),
  ])),
]));
}

Widget _miniOfCard(String title, String subtitle, Widget child) {
return Container(
  padding: const EdgeInsets.all(9),
  decoration: BoxDecoration(
    color: Colors.white.withOpacity(.64),
    borderRadius: BorderRadius.circular(6),
  ),
  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _OF.text, fontSize: 11.4, fontWeight: FontWeight.w700))),
      Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _OF.muted2, fontSize: 11.0, fontWeight: FontWeight.w600)),
    ]),
    const SizedBox(height: 8),
    child,
  ]),
);
}

Widget _ofPanel({required String title, required String subtitle, required Widget child, List<Widget> actions = const []}) {
return Container(
  decoration: const BoxDecoration(color: Colors.transparent),
  clipBehavior: Clip.antiAlias,
  child: Column(children: [
    Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: const BoxDecoration(color: Colors.transparent, border: Border(bottom: BorderSide(color: _OF.line))),
      child: Row(children: [
        Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _OF.text, fontSize: 11.7, fontWeight: FontWeight.w700, letterSpacing: -.14))),
        if (subtitle.isNotEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _OF.muted2, fontSize: 10.4, fontWeight: FontWeight.w600)),
            ),
          ),
        if (actions.isNotEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: Row(mainAxisSize: MainAxisSize.min, children: actions),
            ),
          ),
      ]),
    ),
    Expanded(child: child),
  ]),
);
}


Widget _debugLiveChainPanel() {
return _miniOfCard(
  'Отладка Live',
  _running ? 'запись' : 'готово',
  Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SizedBox(
        height: 30,
        child: OutlinedButton.icon(
          onPressed: _openFullDebugDialog,
          style: OutlinedButton.styleFrom(
            foregroundColor: _OF.graphite,
            side: BorderSide.none,
            backgroundColor: const Color(0xFFF1F3F6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          icon: const Icon(Icons.open_in_full_rounded, size: 14, color: Color(0xFF8B95A3)),
          label: const Text('Полная отладка', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.2, fontWeight: FontWeight.w700)),
        ),
      ),
      const SizedBox(height: 6),
      _DebugLine(label: 'LOCAL', value: _lastLocalMetrics),
      _DebugLine(label: 'GPS', value: _lastZeroReason),
      _DebugLine(label: 'DEBUG', value: _lastRemoteDebug),
      if (_running) _DebugLine(label: 'STATE', value: _lastLiveState),
    ],
  ),
);
}

_RuntimeTrack? _localTrackForPlayer(int? playerId) {
if (playerId == null) return null;

final suffixA = '-P$playerId';
final suffixB = 'P$playerId';
for (final entry in _tracks.entries) {
  if (entry.key.endsWith(suffixA) || entry.key.endsWith(suffixB)) return entry.value;
}

if (widget.selectedPlayer?.id == playerId) return _mainTrack;
return null;
}

TrackerLiveSessionModel? _sessionForPlayer(int? playerId) {
if (playerId == null) return null;
for (final s in _sessions) {
  if (s.playerId == playerId || _resolvedPlayerIdForSession(s) == playerId) return s;
}
return null;
}

_RuntimeTrack? _displayTrackForPlayer(TrackerPlayerOption player) {
final local = _localTrackForPlayer(player.id);
if (local != null && local.points.isNotEmpty) return local;

final session = _sessionForPlayer(player.id);
if (session?.latitude != null && session?.longitude != null) {
  final track = _RuntimeTrack(
    key: 'SESSION-${session!.id}-P${player.id}',
    playerName: player.name,
    deviceName: session.deviceName,
    avatar: player.avatar ?? session.avatarUrl,
  );
  track.points.add(_RuntimePoint(
    lat: session.latitude!,
    lon: session.longitude!,
    timeMs: DateTime.now().millisecondsSinceEpoch,
    speedKmh: session.speedKmh,
    rawSpeedKmh: session.speedKmh,
    distanceDeltaM: 0,
    packetType: 'server-live',
  ));
  track.speedKmh = session.speedKmh;
  track.rawSpeedKmh = session.speedKmh;
  track.totalDistanceM = session.totalDistanceM;
  track.maxSpeedKmh = session.maxSpeedKmh;
  return track;
}

return local;
}

String _debugTrackLine(_RuntimeTrack? track) {
if (track == null) return 'local=null';
return 'pts=${track.points.length} sp=${track.speedKmh.toStringAsFixed(1)} raw=${track.rawSpeedKmh.toStringAsFixed(1)} '
    'd=${track.totalDistanceM.toStringAsFixed(1)} +${track.lastDeltaM.toStringAsFixed(2)} '
    'm/min=${track.metersPerMinute.toStringAsFixed(1)} max=${track.maxSpeedKmh.toStringAsFixed(1)} '
    'HIR=${track.hirDistanceM.toStringAsFixed(1)} VHIR=${track.vhirDistanceM.toStringAsFixed(1)} '
    'SPR=${track.sprintDistanceM.toStringAsFixed(1)} ACC=${track.accelCount} DEC=${track.decelCount} COD=${track.changeOfDirectionCount} '
    'dur=${track.durationSec}s';
}

String _debugSessionLine(TrackerLiveSessionModel s) {
return 'id=${s.id} st=${s.status} sp=${s.speedKmh.toStringAsFixed(1)} '
    'd=${s.totalDistanceM.toStringAsFixed(1)} m/min=${s.metersPerMinute.toStringAsFixed(1)} '
    'max=${s.maxSpeedKmh.toStringAsFixed(1)} HIR=${s.hirDistanceM.toStringAsFixed(1)} '
    'VHIR=${s.vhirDistanceM.toStringAsFixed(1)} SPR=${s.sprintDistanceM.toStringAsFixed(1)} '
    'ACC=${s.accelCount} DEC=${s.decelCount} COD=${s.changeOfDirectionCount} dur=${s.durationSec}s';
}

String _debugPayloadLine(Map<String, dynamic> payload) {
return 'keys=${payload.keys.length} '
    'session=${payload['live_session_id']} sp=${_fmt(payload['speed_kmh'])} raw=${_fmt(payload['raw_speed_kmh'])} '
    '+d=${_fmt(payload['distance_delta_m'])} total=${_fmt(payload['total_distance_m'])} '
    'm/min=${_fmt(payload['meterage_per_min'])} HIR=${_fmt(payload['hir_distance_m'])} '
    'VHIR=${_fmt(payload['vhir_distance_m'])} SPR=${_fmt(payload['sprint_distance_m'])} '
    'ACC=${payload['accel_count'] ?? 0} DEC=${payload['decel_count'] ?? 0} COD=${payload['change_of_direction_count'] ?? 0} '
    'analysis=${payload['analysis_json'] == null ? 'NULL' : 'YES'}';
}

String _debugServerLine(Map<String, dynamic> result) {
return 'point=${result['point_id'] ?? '-'} idx=${result['point_index'] ?? '-'} '
    'sp=${_fmt(result['speed_kmh'])} +d=${_fmt(result['distance_delta_m'])} zone=${result['speed_zone'] ?? '-'} '
    'HIR+${_fmt(result['hir_delta_m'])} VHIR+${_fmt(result['vhir_delta_m'])} SPR+${_fmt(result['sprint_delta_m'])} '
    'ACC=${result['accel_event'] ?? '-'} DEC=${result['decel_event'] ?? '-'} COD=${result['cod_event'] ?? '-'}';
}

String _debugZeroReason(_RuntimeTrack track, _RuntimePoint stat) {
if (track.points.length < 2) return 'нужны минимум 2 точки для скорости';
if (!stat.acceptedForMetrics) return stat.rejectReason ?? 'GPS-шум отфильтрован';
if (stat.distanceDeltaM <= 0.25) return 'смещение ${stat.distanceDeltaM.toStringAsFixed(2)} м — мало для скорости';
if (track.speedKmh < 11.5) return 'скорость ${track.speedKmh.toStringAsFixed(1)} км/ч ниже HIR 11.5';
if (track.speedKmh < 14.0) return 'должен расти HIR, VHIR/SPR ещё нет';
if (track.speedKmh < 18.0) return 'должен расти VHIR, SPR ещё нет';
return 'должен расти SPR; если SQL ноль — не доходит payload/PHP';
}

String _fmt(dynamic value) {
final n = value is num ? value.toDouble() : double.tryParse('$value');
if (n == null || n.isNaN || n.isInfinite) return '$value';
return n.toStringAsFixed(n.abs() >= 100 ? 0 : 2);
}

String _shortJson(Map<String, dynamic> value, {int max = 900}) {
final text = jsonEncode(value);
return text.length <= max ? text : '${text.substring(0, max)}...';
}

double _latOffsetByMeters(double meters) => meters / 111111.0;

double _lonOffsetByMeters(double meters, double latitude) {
final c = math.cos(_deg(latitude)).abs().clamp(0.2, 1.0).toDouble();
return meters / (111111.0 * c);
}

String _debugDumpText() {
final device = widget.ble.connectedInfo;
final field = widget.selectedField;
final track = _mainTrack;
final firstSession = _sessions.isNotEmpty ? _sessions.first : null;
final encoder = const JsonEncoder.withIndent('  ');
String jsonPretty(dynamic value) {
  try {
    return encoder.convert(value);
  } catch (_) {
    return '$value';
  }
}

return <String>[
  'SPORTOTEKA TRACKER LIVE DEBUG',
  'time=${DateTime.now().toIso8601String()}',
  'club_id=${widget.clubId}',
  'team_id=${widget.teamId}',
  'team_name=${widget.teamName}',
  'player_id=${widget.selectedPlayer?.id}',
  'player_name=${widget.selectedPlayer?.name}',
  'live_session_id=$_myLiveSessionId',
  'running=$_running starting=$_starting saving_point=$_savingPoint mode=${_mode.name} activity=${_activity.code}',
  'field_id=${field?.id} field_title=${field?.title} calibrated=${field?.hasCalibration} required=${_activity.requiresField}',
  'device_id=${device?.id} device_name=${device?.name} scanning=${widget.scanningBluetooth} battery=${widget.batteryPercent}',
  '',
  'LOCAL=$_lastLocalMetrics',
  'ZERO=$_lastZeroReason',
  'PAYLOAD=$_lastPayload',
  'SERVER=$_lastServer',
  'REMOTE_DEBUG=$_lastRemoteDebug',
  'STATE=$_lastLiveState',
  'SAVE=$_lastSave',
  'STOP=$_lastStop',
  'PROBLEM=$_lastProblem',
  '',
  'TX=$_lastTx',
  'RX=$_lastRx',
  'GPS=$_lastGps',
  'gps_age=${_lastGpsAt == null ? 'нет' : '${DateTime.now().difference(_lastGpsAt!).inSeconds}s'}',
  'save_age=${_lastSaveAt == null ? 'нет' : '${DateTime.now().difference(_lastSaveAt!).inSeconds}s'}',
  '',
  'LOCAL_TRACK_JSON:',
  track == null ? 'null' : jsonPretty(track.toJson()),
  '',
  'FIRST_SERVER_SESSION:',
  firstSession == null ? 'null' : _debugSessionLine(firstSession),
  '',
  'LAST_LOGS:',
  ..._logs.take(90),
].join('\n');
}

Future<void> _copyDebugDump() async {
await Clipboard.setData(ClipboardData(text: _debugDumpText()));
_toast('Отладка скопирована. Можно прислать сюда текст из буфера.');
}

Future<void> _openFullDebugDialog() async {
if (!mounted) return;
await showDialog<void>(
  context: context,
  builder: (context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980, maxHeight: 760),
        child: Column(
          children: [
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: _OF.line)),
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(color: _OF.graphite.withOpacity(.09), borderRadius: BorderRadius.circular(6)),
                    child: const Icon(Icons.bug_report_rounded, color: _OF.graphite, size: 18),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Полная отладка Live', style: TextStyle(color: _OF.text, fontSize: 14, fontWeight: FontWeight.w600)),
                        Text('Реальные данные: BLE → GPS → локально → запрос → сервер → состояние → стоп', style: TextStyle(color: _OF.muted, fontSize: 11.2, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _copyDebugDump,
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Скопировать'),
                    style: TextButton.styleFrom(foregroundColor: _OF.graphite),
                  ),
                  _floatingWindowControl(Icons.close_rounded, () => Navigator.of(context).pop(), 'Закрыть'),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(9),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _FullDebugLine(label: 'Локально', value: _lastLocalMetrics),
                    _FullDebugLine(label: 'Причина нуля', value: _lastZeroReason),
                    _FullDebugLine(label: 'Запрос', value: _lastPayload),
                    _FullDebugLine(label: 'Сервер', value: _lastServer),
                    _FullDebugLine(label: 'Debug сервер', value: _lastRemoteDebug),
                    _FullDebugLine(label: 'Состояние', value: _lastLiveState),
                    _FullDebugLine(label: 'Сохранение', value: _lastSave),
                    _FullDebugLine(label: 'Стоп', value: _lastStop),
                    _FullDebugLine(label: 'Проблема', value: _lastProblem),
                    const SizedBox(height: 8),
                    _FullDebugLine(label: 'TX', value: _lastTx),
                    _FullDebugLine(label: 'RX', value: _lastRx),
                    _FullDebugLine(label: 'GPS', value: _lastGps),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: const Color(0xFF111512), borderRadius: BorderRadius.circular(6)),
                      child: SelectableText(
                        _debugDumpText(),
                        style: const TextStyle(color: Colors.white70, fontSize: 11.2, height: 1.35, fontFamily: 'monospace'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFFFED7AA))),
                      child: const Text(
                        'Важно: кнопки тестовых точек ниже создают искусственные данные. Для проверки реального трекера не нажимай их — смотри LOCAL/PAYLOAD/SERVER/STATE после движения с подключённым устройством.',
                        style: TextStyle(color: _OF.text, fontSize: 11.2, fontWeight: FontWeight.w500),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _addDebugLocalPoint,
                            icon: const Icon(Icons.add_location_alt_rounded, size: 16),
                            label: const Text('Тест: точка (не трекер)'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _addDebugIntensitySequence,
                            icon: const Icon(Icons.flash_on_rounded, size: 16),
                            label: const Text('Тест: HIR/VHIR/SPR (не трекер)'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  },
);
}

Widget _bottomOperatorBar(int online, int active) {
final metrics = <Widget>[
  _bottomMetricChip('Время', _durationText()),
  _bottomMetricChip('Игроки', '$online/$active'),
  _bottomMetricChip('Дист.', '${(_displayDistanceM / 1000).toStringAsFixed(2)} км'),
  _bottomMetricChip('Макс.', '${(_mainTrack?.maxSpeedKmh ?? 0).toStringAsFixed(1)}'),
  _bottomMetricChip('GPS', _lastGpsAt == null ? 'нет' : '${DateTime.now().difference(_lastGpsAt!).inSeconds}с'),
  _bottomMetricChip('Режим', _activity.shortTitle),
];

return Container(
  height: 42,
  decoration: const BoxDecoration(color: Colors.white),
  padding: const EdgeInsets.symmetric(horizontal: 8),
  child: Row(
    children: [
      Container(
        height: 26,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(color: _running ? _OF.greenSoft : const Color(0xFFFDF2F2), borderRadius: BorderRadius.circular(6)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ofStatusDot(_running ? _OF.green : _OF.red),
            const SizedBox(width: 6),
            Text(_running ? 'LIVE' : 'ГОТОВО', style: TextStyle(color: _running ? _OF.green : _OF.text, fontSize: 10.4, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(children: metrics),
        ),
      ),
      const SizedBox(width: 8),
      SizedBox(
        height: 28,
        child: TextButton.icon(
          onPressed: () => _openExpandedLiveBlock('Оператор / трекер', Icons.tune_rounded, () => _tabletBottomInfoPanel(online, active)),
          style: TextButton.styleFrom(
            foregroundColor: _OF.graphite,
            backgroundColor: _OF.header,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
          icon: const Icon(Icons.tune_rounded, size: 12),
          label: const Text('ОПЕРАТОР', style: TextStyle(fontSize: 9.6, fontWeight: FontWeight.w700)),
        ),
      ),
    ],
  ),
);
}

Widget _bottomMetricChip(String label, String value) {
return Container(
  height: 28,
  margin: const EdgeInsets.only(right: 6),
  padding: const EdgeInsets.symmetric(horizontal: 9),
  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label, style: const TextStyle(color: _OF.muted2, fontSize: 11.2, fontWeight: FontWeight.w700)),
      const SizedBox(width: 5),
      Text(value, style: const TextStyle(color: _OF.text, fontSize: 10.4, fontWeight: FontWeight.w700)),
    ],
  ),
);
}

Widget _ofStatusDot(Color color) => Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle));

Future<void> _addPeriod() async {
final title = await _showPeriodTitleDialog();
if (title == null || title.trim().isEmpty) return;

final now = DateTime.now();
final startRatio = _timelineProgressRatio(now);
final previous = _periods.isNotEmpty ? _periods.last : null;

setState(() {
  if (previous != null && previous.endTime == null) {
    final idx = _periods.length - 1;
    _periods[idx] = previous.copyWith(
      endTime: now,
      endRatio: math.max(previous.startRatio + .03, startRatio),
    );
  }

  final safeStart = _periods.isEmpty
      ? math.max(.02, startRatio)
      : math.max(startRatio, math.min(.92, _periods.last.endRatio + .015));

  _periods.add(
    _LivePeriod(
      title: title.trim().toUpperCase(),
      startRatio: safeStart.clamp(0.02, 0.94).toDouble(),
      endRatio: math.min(.97, safeStart + .12).toDouble(),
      color: _periodColor(_periods.length),
      startTime: now,
    ),
  );
});

await _saveLastPeriodToServer();
_toast('Период добавлен: ${title.trim()} сохранён в таймлайне Live');
}

Future<String?> _showPeriodTitleDialog() async {
const presets = <String>[
  'Разминка',
  'SMG',
  'Владение',
  'Удары',
  'Игра 5x5',
  'Спринты',
  'Тактика',
  'Заминка',
];

final controller = TextEditingController();

return showDialog<String>(
  context: context,
  builder: (context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      title: const Text('Добавить период', style: TextStyle(fontWeight: FontWeight.w500)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Период попадёт в таймлайн и будет использоваться в отчётах по сессии.',
            style: TextStyle(color: _OF.muted, fontWeight: FontWeight.w500, height: 1.3),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: presets.map((p) {
              return ActionChip(
                label: Text(p, style: const TextStyle(fontWeight: FontWeight.w500)),
                onPressed: () => Navigator.of(context).pop(p),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Свой период',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (v) => Navigator.of(context).pop(v),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Отмена')),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: const Text('Добавить'),
        ),
      ],
    );
  },
);
}

double _timelineProgressRatio([DateTime? at]) {
final started = _startedAt;
if (started == null) {
  if (_periods.isEmpty) return .03;
  return math.min(.92, _periods.last.endRatio + .025).toDouble();
}

final now = at ?? DateTime.now();
final elapsed = now.difference(started).inSeconds;
const plannedSessionSec = 90 * 60;
return (elapsed / plannedSessionSec).clamp(.02, .96).toDouble();
}

Color _periodColor(int index) {
const colors = <Color>[
  _OF.cyan,
  Color(0xFF7DD3FC),
  Color(0xFFA7F3D0),
  Color(0xFFFDE68A),
  Color(0xFFFBCFE8),
  Color(0xFFC4B5FD),
];
return colors[index % colors.length];
}

Future<void> _saveLastPeriodToServer() async {
final id = _myLiveSessionId;
if (id == null || _periods.isEmpty) return;

try {
  await _api.saveLivePeriod(
    liveSessionId: id,
    teamId: widget.teamId,
    period: _periods.last.toJson(),
  );
  _log('Период сохранён на сервере: ${_periods.last.title}');
} catch (e) {
  _log('Период сохранён локально, сервер недоступен: $e');
}
}

Future<void> _syncLocalPeriodsToServer() async {
final id = _myLiveSessionId;
if (id == null || _periods.isEmpty) return;
for (final p in _periods) {
  try {
    await _api.saveLivePeriod(
      liveSessionId: id,
      teamId: widget.teamId,
      period: p.toJson(),
    );
  } catch (_) {
    break;
  }
}
}


String _currentPeriodLabel() {
if (_periods.isEmpty) return '';
final active = _periods.where((p) => p.endTime == null && p.startTime != null).toList();
if (active.isNotEmpty) return 'Текущий период: ${active.last.title}';
return 'Периодов: ${_periods.length}';
}

String _todayLabel() {
final d = DateTime.now();
String two(int v) => v.toString().padLeft(2, '0');
return '${two(d.day)}.${two(d.month)}.${d.year}';
}

String _durationText() {
if (!_running || _startedAt == null) return '00:00:00';
return _formatDuration(DateTime.now().difference(_startedAt!));
}

String _formatDuration(Duration d) {
final h = d.inHours.toString().padLeft(2, '0');
final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
return '$h:$m:$s';
}

String _playerInitials(String name) {
final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
if (parts.isEmpty) return 'И';
if (parts.length == 1) return parts.first.substring(0, math.min(2, parts.first.length)).toUpperCase();
return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}

ImageProvider? _playerAvatarProvider(TrackerPlayerOption? player) {
  var avatar = player?.avatar?.trim() ?? '';
  if (avatar.isEmpty && player != null) {
    avatar = (_sessionForPlayer(player.id)?.avatarUrl ?? '').trim();
  }
  avatar = _trackerAbsolutePhotoUrl(avatar);
  if (avatar.isEmpty) return null;
  return NetworkImage(avatar);
}

Widget _playerAvatarCircle({
  required TrackerPlayerOption? player,
  required double radius,
  bool online = false,
}) {
  final provider = _playerAvatarProvider(player);
  final name = player?.name ?? 'Игрок';
  return CircleAvatar(
    radius: radius,
    backgroundColor: online ? _OF.green : _OF.header,
    backgroundImage: provider,
    child: provider == null
        ? Text(
            _playerInitials(name),
            style: TextStyle(
              color: online ? Colors.white : _OF.graphite,
              fontWeight: FontWeight.w700,
              fontSize: math.max(9, radius * .68),
            ),
          )
        : null,
  );
}

Widget _mobilePanel({
required String title,
required IconData icon,
required Widget Function() builder,
double? height,
}) {
final mobile = MediaQuery.of(context).size.width < 720;
final content = mobile
    ? builder()
    : _expandableLiveBlock(
        title: title,
        icon: icon,
        builder: builder,
        allowExpand: true,
      );

return height == null ? content : SizedBox(height: height, child: content);
}

Widget _expandableLiveBlock({
required String title,
required IconData icon,
required Widget Function() builder,
bool allowExpand = true,
}) {
return Stack(
  children: [
    Positioned.fill(child: builder()),
    if (allowExpand && !_renderingFloatingLiveContent)
      Positioned(
        top: 8,
        right: 8,
        child: _LiveExpandButton(
          tooltip: 'Развернуть блок',
          onTap: () => _openExpandedLiveBlock(title, icon, builder),
        ),
      ),
  ],
);
}

Widget _buildFloatingLiveContent() {
_renderingFloatingLiveContent = true;
final content = _floatingLiveBuilder?.call() ?? const SizedBox.shrink();
_renderingFloatingLiveContent = false;
return content;
}

Widget _withFloatingLiveWindow(Widget child) {
return Stack(
  children: [
    Positioned.fill(child: child),
    if (_floatingLiveBuilder != null && _floatingLiveMinimized)
      Positioned(
        left: 12,
        bottom: 34,
        child: _floatingLiveMinimizedBar(),
      ),
    if (_floatingLiveBuilder != null && !_floatingLiveMinimized)
      Positioned.fill(child: _floatingLiveWindowLayer()),
  ],
);
}

Widget _floatingLiveMinimizedBar() {
return Material(
  color: Colors.transparent,
  child: _NoHoverTap(
    onTap: () => setState(() => _floatingLiveMinimized = false),
    borderRadius: BorderRadius.circular(6),
    child: Container(
      height: 38,
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 340),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.96),
        borderRadius: BorderRadius.circular(6),
        boxShadow: null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_floatingLiveIcon, color: _OF.muted2, size: 16),
          const SizedBox(width: 8),
          Flexible(child: Text(_floatingLiveTitle ?? 'Окно', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _OF.text, fontSize: 11.2, fontWeight: FontWeight.w700))),
          const SizedBox(width: 8),
          _NoHoverTap(
            onTap: _closeFloatingLiveWindow,
            child: const SizedBox(width: 32, height: 32, child: Icon(Icons.close_rounded, size: 16, color: _OF.muted)),
          ),
        ],
      ),
    ),
  ),
);
}

Widget _floatingLiveWindowLayer() {
return LayoutBuilder(
  builder: (context, c) {
    if (c.maxWidth < 720) {
      return Material(
        color: _OF.bg,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
                Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: const BoxDecoration(color: _OF.bg, border: Border(bottom: BorderSide(color: _OF.line))),
                  child: Row(
                    children: [
                      _NoHoverTap(
                        onTap: _closeFloatingLiveWindow,
                        child: const SizedBox(width: 36, height: 36, child: Icon(Icons.arrow_back_rounded, color: _OF.graphite)),
                      ),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(color: _OF.greenSoft, borderRadius: BorderRadius.circular(6), border: Border.all(color: _OF.green.withOpacity(.07))),
                        child: Icon(_floatingLiveIcon, color: _OF.green, size: 17),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _floatingLiveTitle ?? 'Окно',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: _OF.text, fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: -.2),
                        ),
                      ),
                      _NoHoverTap(
                        onTap: _closeFloatingLiveWindow,
                        child: const SizedBox(width: 36, height: 36, child: Icon(Icons.close_rounded, color: _OF.muted2)),
                      ),
                    ],
                  ),
                ),
              Expanded(child: _buildFloatingLiveContent()),
            ],
          ),
        ),
      );
    }

    final compact = c.maxWidth < 1180;
    final margin = compact ? 6.0 : 14.0;
    // На планшете всплывающие окна сразу почти во весь экран: не нужно
    // ловить маленькое окно и листать внутренний контент. На ПК оставляем
    // привычный плавающий размер.
    final windowWidth = _floatingLiveMaximized || compact
        ? c.maxWidth - margin * 2
        : math.min(c.maxWidth - margin * 2, 980.0);
    final windowHeight = _floatingLiveMaximized || compact
        ? c.maxHeight - margin * 2
        : math.min(c.maxHeight - margin * 2, 660.0);

    final defaultLeft = (c.maxWidth - windowWidth) / 2;
    final defaultTop = math.max(margin, (c.maxHeight - windowHeight) / 2);
    final maxLeft = math.max(margin, c.maxWidth - windowWidth - margin);
    final maxTop = math.max(margin, c.maxHeight - windowHeight - margin);
    final raw = _floatingLiveOffset ?? Offset(defaultLeft, defaultTop);
    final left = _floatingLiveMaximized ? margin : raw.dx.clamp(margin, maxLeft).toDouble();
    final top = _floatingLiveMaximized ? margin : raw.dy.clamp(margin, maxTop).toDouble();

    void dragWindow(DragUpdateDetails details) {
      if (_floatingLiveMaximized) return;
      final current = _floatingLiveOffset ?? Offset(left, top);
      final next = Offset(
        (current.dx + details.delta.dx).clamp(margin, maxLeft).toDouble(),
        (current.dy + details.delta.dy).clamp(margin, maxTop).toDouble(),
      );
      setState(() => _floatingLiveOffset = next);
    }

    return Stack(
      children: [
        Positioned(
          left: left,
          top: top,
          width: windowWidth,
          height: windowHeight,
          child: Material(
            color: Colors.transparent,
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.98),
                borderRadius: BorderRadius.circular(_floatingLiveMaximized ? 6 : 8),
                boxShadow: null,
              ),
              child: Column(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanUpdate: dragWindow,
                    child: Container(
                        height: 46,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _OF.line))),
                        child: Row(
                          children: [
                            _floatingWindowControl(Icons.close_rounded, _closeFloatingLiveWindow, 'Закрыть'),
                            const SizedBox(width: 6),
                            _floatingWindowControl(Icons.remove_rounded, () => setState(() => _floatingLiveMinimized = true), 'Свернуть'),
                            const SizedBox(width: 6),
                            _floatingWindowControl(_floatingLiveMaximized ? Icons.close_fullscreen_rounded : Icons.open_in_full_rounded, () => setState(() => _floatingLiveMaximized = !_floatingLiveMaximized), _floatingLiveMaximized ? 'Вернуть размер' : 'Развернуть'),
                            const SizedBox(width: 8),
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Icon(_floatingLiveIcon, color: _OF.muted2, size: 17),
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                _floatingLiveTitle ?? 'Окно',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: _OF.text, fontSize: 12.8, fontWeight: FontWeight.w700, letterSpacing: -.2),
                              ),
                            ),
                          ],
                        ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(1),
                      child: _buildFloatingLiveContent(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  },
);
}

Widget _floatingWindowControl(IconData icon, VoidCallback onTap, String tooltip) {
return Material(
  color: Colors.white,
  borderRadius: BorderRadius.circular(4),
  child: _NoHoverTap(
    onTap: onTap,
    child: Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(icon, size: 12, color: const Color(0xFF8B95A3)),
    ),
  ),
);
}

void _closeFloatingLiveWindow() {
setState(() {
  _floatingLiveTitle = null;
  _floatingLiveBuilder = null;
  _floatingLiveMinimized = false;
  _floatingLiveMaximized = false;
  _floatingLiveOffset = null;
});
}

Future<void> _openExpandedLiveBlock(
String title,
IconData icon,
Widget Function() builder,
) async {
final width = MediaQuery.maybeOf(context)?.size.width ?? 999;
if (width < 720) {
  await _openMobileLiveBlockSheet(title, icon, builder);
  return;
}
setState(() {
  _floatingLiveTitle = title;
  _floatingLiveIcon = icon;
  _floatingLiveBuilder = builder;
  _floatingLiveMinimized = false;
  _floatingLiveMaximized = false;
  _floatingLiveOffset = null;
});
}




Widget _leftLiveColumn(int online, int active) {
return ListView(
  padding: EdgeInsets.zero,
  children: [
    _statusHeader(online, active),
    const SizedBox(height: 8),
    _playersCard(height: 300),
    const SizedBox(height: 8),
    _TeamHeartRateOnlineCard(
      players: widget.players,
      samples: widget.heartRateByPlayerId,
    ),
  ],
);
}

Widget _middleAnalyticsColumn() {
// В центральном окне Live больше нет нижней сетки KPI:
// на узкой ширине она давала BOTTOM OVERFLOWED.
// Все показатели теперь идут внутри блока «Расширенная аналитика» строками вниз.
return Column(
  children: [
    Expanded(child: _proAnalyticsCenter()),
    const SizedBox(height: 6),
    _LiveCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: _ProblemBox(text: _lastProblem),
    ),
  ],
);
}

Widget _rightPitchColumn() {
if (!_activity.requiresField) {
  return _fieldCard();
}
return Column(
  children: [
    Expanded(child: _rightPitchCard()),
    const SizedBox(height: 8),
    _fieldLegendCard(),
  ],
);
}

Widget _rightPitchCard() {
return _LiveCard(
  padding: EdgeInsets.zero,
  child: Column(
    children: [
      Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: const BoxDecoration(
          color: _C.soft,
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          border: Border(bottom: BorderSide(color: _C.divider)),
        ),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: _C.greenSoft,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _C.green.withOpacity(.07)),
              ),
              child: const Icon(Icons.map_rounded, color: _C.green, size: 17),
            ),
            const SizedBox(width: 5),
            const Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Поле / теплокарта',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: _C.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '105×68 · трек · векторы · тепловые зоны',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      color: _C.subtle,
                      fontSize: 11.2,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            _TinyMetric(label: 'GPS', value: _lastGpsAt == null ? 'нет' : '${DateTime.now().difference(_lastGpsAt!).inSeconds}с'),
          ],
        ),
      ),
      Expanded(
        child: Container(
          color: const Color(0xFFF8F9FA),
          child: LayoutBuilder(
            builder: (context, c) {
              const aspect = 105.0 / 68.0;
              final maxW = c.maxWidth.isFinite ? c.maxWidth : 420.0;
              final maxH = c.maxHeight.isFinite ? c.maxHeight : 420.0;
              var w = maxW - 8;
              var h = w / aspect;
              if (h > maxH - 8) {
                h = maxH - 8;
                w = h * aspect;
              }

              return Align(
                alignment: Alignment.center,
                child: SizedBox(
                  width: w,
                  height: h,
                  child: CustomPaint(
                    painter: _RuntimeFieldPainter(
                      field: widget.selectedField,
                      tracks: _tracks.values.toList(),
                      showVectors: _showVectors,
                      showHeatmap: _showHeatmap,
                      showTrace: _showTrace,
                      showLabels: _showLabels,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ],
  ),
);
}

Widget _fieldLegendCard() {
return _LiveCard(
  padding: const EdgeInsets.all(5),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _TitleRow(
        icon: Icons.layers_rounded,
        title: _activity.requiresField ? 'Слои поля' : 'Слои активности',
        subtitle: _activity.requiresField ? 'быстрое включение данных' : 'маршрут, темп и нагрузка без поля',
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          _LayerChip(label: 'Трек', active: _showTrace, onTap: () => setState(() => _showTrace = !_showTrace)),
          _LayerChip(label: 'Векторы', active: _showVectors, onTap: () => setState(() => _showVectors = !_showVectors)),
          _LayerChip(label: 'Тепло', active: _showHeatmap, onTap: () => setState(() => _showHeatmap = !_showHeatmap)),
          _LayerChip(label: 'Метки', active: _showLabels, onTap: () => setState(() => _showLabels = !_showLabels)),
        ],
      ),
    ],
  ),
);
}



Widget _statusHeader(int online, int active) {
final device = widget.ble.connectedInfo;
final fieldReady = !_activity.requiresField || widget.selectedField?.hasCalibration == true;

return _LiveCard(
  padding: const EdgeInsets.all(9),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _TitleRow(
        icon: Icons.radio_button_checked_rounded,
        title: 'Live трекера',
        subtitle: '${widget.teamName} · онлайн-координаты и нагрузка',
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _StatePill(
            icon: Icons.person_rounded,
            label: widget.selectedPlayer?.name ?? 'Игрок не выбран',
            ok: widget.selectedPlayer != null,
          ),
          _StatePill(
            icon: Icons.bluetooth_connected_rounded,
            label: device == null ? 'Трекер не подключён' : '${device.name}',
            ok: device != null,
          ),
          _StatePill(
            icon: Icons.monitor_heart_rounded,
            label: widget.heartRateConnectedCount > 0 ? 'Polar ${widget.heartRateConnectedCount}' : 'Polar нет',
            ok: widget.heartRateConnectedCount > 0 || widget.heartRateByPlayerId.isNotEmpty,
          ),
          _StatePill(
            icon: _activity.icon,
            label: _activity.title,
            ok: true,
          ),
          _StatePill(
            icon: Icons.map_rounded,
            label: _activity.requiresField
                ? (fieldReady ? widget.selectedField!.title : 'Поле не готово')
                : 'Поле не требуется',
            ok: fieldReady,
          ),
        ],
      ),
      const SizedBox(height: 8),
      _LiveSourceSelector(
        value: _mode,
        running: _running,
        heartRateOnline: widget.heartRateByPlayerId.isNotEmpty || widget.heartRateConnectedCount > 0,
        onChanged: (mode) => setState(() => _mode = mode),
        titleOf: _liveSourceTitle,
        iconOf: _liveSourceIcon,
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: _running ? null : _openActivityChooser,
        style: OutlinedButton.styleFrom(
          foregroundColor: _OF.graphite,
          side: BorderSide.none,
          backgroundColor: _OF.header,
          minimumSize: const Size(double.infinity, 40),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        icon: Icon(_activity.icon, size: 15),
        label: Text('Режим: ${_activity.title}', style: const TextStyle(fontSize: 11.2, fontWeight: FontWeight.w700)),
      ),
      const SizedBox(height: 8),
      if (_mode == TrackerLiveSourceMode.trackerExperimental) ...[
        const SizedBox(height: 5),
        DropdownButtonFormField<int>(
          value: _candidateCommandIndex,
          decoration: _input('Команда Live GPS'),
          items: List.generate(
            ActionTrackerBleProfile.commandCurrentGpsCandidates.length,
            (i) {
              final cmd = ActionTrackerBleProfile.commandCurrentGpsCandidates[i]
                  .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
                  .join(' ');
              return DropdownMenuItem(value: i, child: Text('Кандидат ${i + 1}: $cmd'));
            },
          ),
          onChanged: _running ? null : (v) => setState(() => _candidateCommandIndex = v ?? 0),
        ),
      ],
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: _starting || (_running && !_paused) ? null : (_paused ? _resumeLiveCollection : _startLive),
              style: FilledButton.styleFrom(
                backgroundColor: _C.green,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: _starting
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.play_arrow_rounded),
              label: Text(_paused ? 'Продолжить Live' : 'Старт Live'),
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _running ? _stopLive : null,
              style: OutlinedButton.styleFrom(
                foregroundColor: _C.red,
                side: const BorderSide(color: _C.green),
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.stop_rounded),
              label: const Text('Стоп'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      _ProblemBox(text: _lastProblem),
    ],
  ),
);
}


HeartRateSample? get _selectedHeartRateSample {
  return _heartRateForPlayerId(widget.selectedPlayer?.id);
}

HeartRateSample? _heartRateForPlayerId(int? playerId) {
  if (playerId == null) return null;
  return widget.heartRateByPlayerId[playerId];
}

Map<String, dynamic> _trackAnalysisWithHeartRate(_RuntimeTrack track) {
  final sample = _selectedHeartRateSample;
  final data = <String, dynamic>{...track.toJson()};
  if (sample != null) {
    data.addAll(sample.toJson());
    data['internal_load_note'] = 'внешняя нагрузка GPS + пульс Polar/Heart Rate BLE';
  }
  return data;
}

String get _heartRateKpiLabel => _heartRateValueLabel(_selectedHeartRateSample);

String get _heartRateZoneLabel => _heartRateZoneLabelForSample(_selectedHeartRateSample);

String _heartRateValueLabel(HeartRateSample? sample) {
  if (sample == null) return '—';
  final age = DateTime.now().difference(sample.measuredAt).inSeconds;
  if (age > 20) return '${sample.bpm} bpm*';
  return '${sample.bpm} bpm';
}

String _heartRateZoneLabelForSample(HeartRateSample? sample) {
  final bpm = sample?.bpm ?? 0;
  if (bpm <= 0) return '—';
  if (bpm < 120) return 'Z1';
  if (bpm < 145) return 'Z2';
  if (bpm < 165) return 'Z3';
  if (bpm < 180) return 'Z4';
  return 'Z5';
}

String _heartRateLiveRecommendation({required _RuntimeTrack? track, required HeartRateSample? sample}) {
  if (sample == null) {
    return 'Polar H10 не привязан к этому игроку или ещё не отдаёт online bpm.';
  }
  final bpm = sample.bpm;
  final ageSec = DateTime.now().difference(sample.measuredAt).inSeconds;
  if (ageSec > 20) {
    return 'Пульс устарел: последние данные были ${ageSec} сек. назад. Проверьте контакт ремня и BLE-связь.';
  }
  final speed = track?.speedKmh ?? 0;
  final load = track?.loadScore ?? 0;
  if (bpm >= 180) return 'Высокая ЧСС Z5: снизить интенсивность и контролировать восстановление игрока.';
  if (bpm >= 165 && speed < 7) return 'Пульс высокий при низкой скорости: возможная усталость, стресс или плохой контакт ремня.';
  if (bpm >= 165) return 'Интенсивная работа Z4: держать под контролем длительность отрезка и паузы.';
  if (bpm < 120 && load > 20) return 'Внешняя нагрузка растёт, а пульс низкий: проверьте посадку Polar H10 и контакт электродов.';
  if (bpm < 120) return 'Низкая зона ЧСС: разминка/восстановление, критичных признаков нет.';
  return 'Пульс соответствует рабочей зоне, нагрузка контролируемая.';
}

String _combinedLiveRecommendation({required _RuntimeTrack? track, required HeartRateSample? sample}) {
  final base = track?.recommendation ?? 'Live-данные появятся после подключения трекера и старта сессии.';
  if (sample == null) return base;
  return '$base\nПульс: ${_heartRateLiveRecommendation(track: track, sample: sample)}';
}

Widget _liveHeartRateSidePanel() {
  final players = _sidePanelPlayers();
  final series = <_LiveMetricSeries>[];
  for (var i = 0; i < players.length; i++) {
    final p = players[i];
    final history = List<_LiveMetricPoint>.from(
      (_liveHrHistoryByPlayer[p.id] ?? const <_LiveHrPoint>[])
          .map((e) => _LiveMetricPoint(timeMs: e.timeMs, value: e.bpm.toDouble())),
    );
    final current = _heartRateForPlayerId(p.id);
    if (history.isEmpty && current != null) {
      history.add(_LiveMetricPoint(timeMs: current.measuredAt.millisecondsSinceEpoch, value: current.bpm.toDouble()));
    }
    if (history.isNotEmpty) {
      series.add(_LiveMetricSeries(label: _compactPlayerName(p.name), color: _chartColor(i), points: history));
    }
  }
  final fresh = players.where((p) => _heartRateForPlayerId(p.id) != null).length;
  return _LiveCard(
    padding: const EdgeInsets.all(10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sidePanelSummaryRow(
          icon: Icons.favorite_rounded,
          title: 'Online ЧСС выбранных игроков',
          value: series.isEmpty ? 'нет данных Polar' : '$fresh/${players.length} online',
          color: _OF.red,
        ),
        const SizedBox(height: 8),
        Expanded(
          child: series.isEmpty
              ? _sideEmptyState(Icons.monitor_heart_rounded, 'Нет live-пульса', 'Назначьте Polar игрокам или выберите игроков, у которых сейчас есть ЧСС.')
              : ClipRRect(
                  borderRadius: BorderRadius.circular(_OF.tabletInnerRadius),
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(_OF.tabletInnerRadius)),
                    child: CustomPaint(
                      painter: _LiveLineChartPainter(
                        series: series,
                        minY: 80,
                        maxY: 205,
                        valueSuffix: ' bpm',
                        thresholds: const <_LiveChartThreshold>[
                          _LiveChartThreshold(value: 145, label: 'Z3'),
                          _LiveChartThreshold(value: 165, label: 'Z4'),
                          _LiveChartThreshold(value: 180, label: 'Z5'),
                        ],
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 8),
        _sideLegend(series),
      ],
    ),
  );
}

Widget _liveSprintSidePanel() {
  final players = _sidePanelPlayers();
  final tracks = <_RuntimeTrack>[];
  for (final p in players) {
    final track = _displayTrackForPlayer(p);
    if (track != null && track.points.isNotEmpty) tracks.add(track);
  }
  final series = <_LiveMetricSeries>[];
  for (var i = 0; i < tracks.length; i++) {
    final track = tracks[i];
    series.add(_LiveMetricSeries(
      label: _compactPlayerName(track.playerName),
      color: _chartColor(i),
      points: track.points.map((p) => _LiveMetricPoint(timeMs: p.timeMs, value: p.speedKmh)).toList(growable: false),
    ));
  }
  final sprintDistance = tracks.fold<double>(0, (sum, t) => sum + t.sprintDistanceM);
  final hsrDistance = tracks.fold<double>(0, (sum, t) => sum + t.hsrDistanceM);
  final accel = tracks.fold<int>(0, (sum, t) => sum + t.accelCount);
  final decel = tracks.fold<int>(0, (sum, t) => sum + t.decelCount);
  return _LiveCard(
    padding: const EdgeInsets.all(10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sidePanelSummaryRow(
          icon: Icons.speed_rounded,
          title: 'Скорость, HIR и спринты',
          value: tracks.isEmpty ? 'нет GPS-точек' : '${tracks.length} трек(ов)',
          color: _OF.green,
        ),
        const SizedBox(height: 8),
        Expanded(
          child: series.isEmpty
              ? _sideEmptyState(Icons.speed_rounded, 'Нет GPS-скорости', 'После первых пакетов трекера здесь появятся скорость, HIR, спринты, ускорения и торможения.')
              : ClipRRect(
                  borderRadius: BorderRadius.circular(_OF.tabletInnerRadius),
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(_OF.tabletInnerRadius)),
                    child: CustomPaint(
                      painter: _LiveLineChartPainter(
                        series: series,
                        minY: 0,
                        maxY: math.max(22.0, series.expand((s) => s.points).fold<double>(0, (m, p) => math.max(m, p.value)) + 3),
                        valueSuffix: ' км/ч',
                        thresholds: const <_LiveChartThreshold>[
                          _LiveChartThreshold(value: 14, label: 'HIR'),
                          _LiveChartThreshold(value: 18, label: 'SPR'),
                        ],
                        highlightAbove: 18,
                      ),
                      child: const SizedBox.expand(),
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _sideMetricChip('HIR', '${hsrDistance.toStringAsFixed(0)} м', _OF.orange)),
          const SizedBox(width: 6),
          Expanded(child: _sideMetricChip('SPR', '${sprintDistance.toStringAsFixed(0)} м', _OF.red)),
          const SizedBox(width: 6),
          Expanded(child: _sideMetricChip('ACC', '$accel', _OF.green)),
          const SizedBox(width: 6),
          Expanded(child: _sideMetricChip('DEC', '$decel', _OF.blue)),
        ]),
        const SizedBox(height: 7),
        _sideLegend(series),
      ],
    ),
  );
}

Widget _liveSignalSidePanel() {
  final players = _sidePanelPlayers();
  return _LiveCard(
    padding: const EdgeInsets.all(10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sidePanelSummaryRow(
          icon: Icons.network_check_rounded,
          title: 'Уровень сигнала BLE / Polar',
          value: players.isEmpty ? 'нет игроков' : '${players.length} выбран.',
          color: _OF.green,
        ),
        const SizedBox(height: 8),
        Expanded(
          child: players.isEmpty
              ? _sideEmptyState(Icons.network_check_rounded, 'Нет выбранных игроков', 'Выберите игроков в Live-мониторинге, чтобы видеть сигнал трекера и Polar.')
              : ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: players.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 7),
                  itemBuilder: (_, i) => _liveSignalPlayerRow(players[i]),
                ),
        ),
      ],
    ),
  );
}

Widget _liveSignalPlayerRow(TrackerPlayerOption player) {
  final rssi = _playerBleRssi(player);
  final device = _deviceForPlayer(player.id);
  final hr = _heartRateForPlayerId(player.id);
  final hrAge = hr == null ? null : DateTime.now().difference(hr.measuredAt).inSeconds;
  final color = _signalColorForPlayer(player);
  final level = rssi == null
      ? (device?.isNearby == true || hr != null ? .64 : .14)
      : ((rssi + 100) / 45).clamp(.08, 1.0).toDouble();
  final battery = device?.batteryPercent ?? hr?.batteryPercent ?? (widget.selectedPlayer?.id == player.id ? widget.batteryPercent : null);
  return Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(_OF.tabletInnerRadius)),
    child: Row(children: [
      _playerAvatarCircle(player: player, radius: 17, online: color == _OF.green),
      const SizedBox(width: 8),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_compactPlayerName(player.name), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _OF.text, fontSize: 11.2, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Row(children: [
            Expanded(child: _signalBar(level, color)),
            const SizedBox(width: 7),
            Text(rssi == null ? _signalLabelForPlayer(player) : '$rssi dBm', style: TextStyle(color: color, fontSize: 9.6, fontWeight: FontWeight.w900)),
          ]),
        ]),
      ),
      const SizedBox(width: 8),
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(battery == null ? 'бат. —' : 'бат. $battery%', style: const TextStyle(color: _OF.muted2, fontSize: 9.6, fontWeight: FontWeight.w800)),
        const SizedBox(height: 5),
        Text(hr == null ? 'HR —' : '${hr.bpm} bpm${hrAge != null && hrAge > 25 ? ' · ${hrAge}s' : ''}', style: TextStyle(color: hr == null ? _OF.muted2 : _OF.red, fontSize: 9.6, fontWeight: FontWeight.w900)),
      ]),
    ]),
  );
}

Widget _sidePanelSummaryRow({required IconData icon, required String title, required String value, required Color color}) {
  return Row(children: [
    Container(width: 30, height: 30, alignment: Alignment.center, decoration: BoxDecoration(color: color.withOpacity(.08), borderRadius: BorderRadius.circular(_OF.tabletInnerRadius), border: Border.all(color: color.withOpacity(.07))), child: Icon(icon, color: color, size: 16)),
    const SizedBox(width: 8),
    Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _OF.text, fontSize: 11, fontWeight: FontWeight.w900))),
    Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _OF.muted2, fontSize: 10.4, fontWeight: FontWeight.w800)),
  ]);
}

Widget _sideEmptyState(IconData icon, String title, String text) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: _OF.muted2, size: 30),
        const SizedBox(height: 9),
        Text(title, textAlign: TextAlign.center, style: const TextStyle(color: _OF.text, fontSize: 11, fontWeight: FontWeight.w900)),
        const SizedBox(height: 5),
        Text(text, textAlign: TextAlign.center, style: const TextStyle(color: _OF.muted2, fontSize: 11.0, fontWeight: FontWeight.w700, height: 1.25)),
      ]),
    ),
  );
}

Widget _sideMetricChip(String label, String value, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
    decoration: BoxDecoration(color: color.withOpacity(.07), borderRadius: BorderRadius.circular(_OF.tabletInnerRadius), border: Border.all(color: color.withOpacity(.07))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontSize: 10.4, fontWeight: FontWeight.w900)),
      const SizedBox(height: 2),
      Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _OF.text, fontSize: 11.2, fontWeight: FontWeight.w900)),
    ]),
  );
}

Widget _signalBar(double value, Color color) {
  return ClipRRect(
    borderRadius: BorderRadius.circular(999),
    child: Container(
      height: 7,
      color: _OF.line,
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: value.clamp(.04, 1.0).toDouble(),
        child: Container(color: color),
      ),
    ),
  );
}

Widget _sideLegend(List<_LiveMetricSeries> series) {
  if (series.isEmpty) return const SizedBox.shrink();
  return SizedBox(
    height: 23,
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: series.length,
      separatorBuilder: (_, __) => const SizedBox(width: 6),
      itemBuilder: (_, i) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(color: series[i].color.withOpacity(.07), borderRadius: BorderRadius.circular(999), border: Border.all(color: series[i].color.withOpacity(.15))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: series[i].color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(series[i].label, style: const TextStyle(color: _OF.text, fontSize: 9.6, fontWeight: FontWeight.w800)),
        ]),
      ),
    ),
  );
}

Color _chartColor(int index) {
  const colors = <Color>[_OF.green, _OF.blue, _OF.orange, _OF.red, _OF.cyan, Color(0xFF7C3AED), Color(0xFF0F766E), Color(0xFFDB2777), Color(0xFF475569), Color(0xFFCA8A04), Color(0xFF0891B2), Color(0xFF16A34A)];
  return colors[index % colors.length];
}

Widget _fieldCard() {
if (!_activity.requiresField) {
  final track = _mainTrack;
  return _LiveCard(
    padding: const EdgeInsets.all(10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(color: _OF.greenSoft, borderRadius: BorderRadius.circular(6)),
              child: Icon(_activity.icon, color: _OF.green, size: 21),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_activity.title, style: const TextStyle(color: _OF.text, fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(_activity.subtitle, style: const TextStyle(color: _OF.muted, fontSize: 11.2, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
        const Spacer(),
        Row(
          children: [
            Expanded(child: _NoFieldMetricTile(label: 'Дистанция', value: '${((track?.totalDistanceM ?? 0) / 1000).toStringAsFixed(2)} км')),
            const SizedBox(width: 8),
            Expanded(child: _NoFieldMetricTile(label: 'Темп', value: '${track?.metersPerMinute.toStringAsFixed(0) ?? '0'} м/мин')),
            const SizedBox(width: 8),
            Expanded(child: _NoFieldMetricTile(label: 'Нагрузка', value: '${track?.loadScore.toStringAsFixed(0) ?? '0'}')),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 88,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
          child: CustomPaint(
            painter: _OpenFieldTimelinePainter(
              points: track?.points ?? const <_RuntimePoint>[],
              running: _running,
              progressRatio: _timelineProgressRatio(),
            ),
            child: Center(
              child: Text(
                track == null || track.points.length < 2 ? 'Ожидание данных трекера' : 'Активность записывается без привязки к полю',
                style: const TextStyle(color: _OF.muted, fontSize: 11.2, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
return _LiveCard(
  padding: const EdgeInsets.all(10),
  child: LayoutBuilder(
    builder: (context, c) {
      return Center(
        child: AspectRatio(
          aspectRatio: 105 / 68,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CustomPaint(
              painter: _RuntimeFieldPainter(
                field: widget.selectedField,
                tracks: _sidePanelTracks(),
                showVectors: _showVectors,
                showHeatmap: _showHeatmap,
                showTrace: _showTrace,
                showLabels: _showLabels,
                showLoadHotPoints: _showLoadHotPoints,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );
    },
  ),
);
}

Widget _kpiGrid({required int columns}) {
final track = _mainTrack;
final lastDelta = track?.lastDeltaM ?? 0;

final items = [
  _KpiData('Скорость', '${_displaySpeedKmh.toStringAsFixed(1)} км/ч', Icons.speed_rounded),
  _KpiData('Темп', '${track?.metersPerMinute.toStringAsFixed(0) ?? '0'} м/мин', Icons.timer_rounded),
  _KpiData('Пульс', _heartRateKpiLabel, Icons.monitor_heart_rounded),
  _KpiData('Зона ЧСС', _heartRateZoneLabel, Icons.favorite_rounded),
  _KpiData('Нагрузка', '${track?.loadScore.toStringAsFixed(0) ?? '0'}', Icons.bolt_rounded),
  _KpiData('Усталость', '${track?.fatigueIndex.toStringAsFixed(0) ?? '0'}%', Icons.battery_alert_rounded),
  _KpiData('HSR', '${track?.hsrDistanceM.toStringAsFixed(0) ?? '0'} м', Icons.speed_rounded),
  _KpiData('Спринт', '${track?.sprintDistanceM.toStringAsFixed(0) ?? '0'} м', Icons.flash_on_rounded),
];

return GridView.builder(
  physics: const NeverScrollableScrollPhysics(),
  padding: EdgeInsets.zero,
  itemCount: items.length,
  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: columns,
    crossAxisSpacing: 6,
    mainAxisSpacing: 6,
    childAspectRatio: columns == 2 ? 2.85 : (columns == 3 ? 3.15 : 2.15),
  ),
  itemBuilder: (_, i) => _KpiCard(data: items[i]),
);
}

Widget _proAnalyticsCenter({double? height}) {
final track = _mainTrack;
final content = _LiveCard(
  padding: const EdgeInsets.all(8),
  child: track == null || track.points.length < 2
      ? Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _TitleRow(
              icon: Icons.analytics_rounded,
              title: 'Расширенная аналитика',
              subtitle: 'нагрузка, HIR/VHIR, метаболика',
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    'Нет live-данных. Запустите трекер или добавьте тестовую точку в отладке.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _C.subtle,
                      fontFamily: 'Inter',
                      fontSize: 11.4,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
                ),
              ),
            ),
          ],
        )
      : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: _TitleRow(
                    icon: Icons.analytics_rounded,
                    title: 'Расширенная аналитика',
                    subtitle: 'нагрузка, HIR/VHIR, метаболика',
                  ),
                ),
                const SizedBox(width: 5),
                OutlinedButton.icon(
                  onPressed: () => _saveMetricSnapshot(manual: true),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _C.green,
                    side: const BorderSide(color: _C.green),
                    minimumSize: const Size(0, 36),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.save_rounded, size: 16),
                  label: const Text('Сохранить'),
                ),
              ],
            ),
            const SizedBox(height: 5),
            _CoachAlert(track: track),
            const SizedBox(height: 5),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(top: 2, bottom: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ProMetricRow(
                      title: 'Нагрузка игрока',
                      value: track.playerLoadEstimate.toStringAsFixed(0),
                      subtitle: track.playerLoadSourceLabel,
                      icon: Icons.bolt_rounded,
                      accent: _C.green,
                    ),
                    const SizedBox(height: 6),
                    _ProMetricRow(
                      title: 'Общая дистанция',
                      value: '${track.totalDistanceM.toStringAsFixed(0)} м',
                      subtitle: 'объём работы за текущую Live-сессию',
                      icon: Icons.route_rounded,
                    ),
                    const SizedBox(height: 6),
                    _ProMetricRow(
                      title: 'Темп',
                      value: '${track.metersPerMinute.toStringAsFixed(0)} м/мин',
                      subtitle: 'скорость накопления дистанции',
                      icon: Icons.timer_rounded,
                    ),
                    const SizedBox(height: 6),
                    _ProMetricRow(
                      title: 'Макс. скорость',
                      value: '${track.maxSpeedKmh.toStringAsFixed(1)} км/ч',
                      subtitle: 'пиковая скорость игрока',
                      icon: Icons.speed_rounded,
                    ),
                    const SizedBox(height: 6),
                    _ProMetricRow(
                      title: 'HIR',
                      value: '${track.hirDistanceM.toStringAsFixed(0)} м',
                      subtitle: 'высокоинтенсивный бег ≥ 4.0 м/с',
                      icon: Icons.directions_run_rounded,
                      accent: _C.orange,
                    ),
                    const SizedBox(height: 6),
                    _ProMetricRow(
                      title: 'VHIR',
                      value: '${track.vhirDistanceM.toStringAsFixed(0)} м',
                      subtitle: 'очень высокая интенсивность ≥ 5.5 м/с',
                      icon: Icons.flash_on_rounded,
                      accent: _C.orange,
                    ),
                    const SizedBox(height: 6),
                    _ProMetricRow(
                      title: 'Спринт',
                      value: '${track.sprintDistanceM.toStringAsFixed(0)} м',
                      subtitle: '${track.sprintCount} рывк. · зона максимальной скорости',
                      icon: Icons.bolt_rounded,
                      accent: _C.red,
                    ),
                    const SizedBox(height: 6),
                    _ProMetricRow(
                      title: 'Метаболика',
                      value: track.metabolicPowerProxy.toStringAsFixed(1),
                      subtitle: 'оценка мощности нагрузки W/кг',
                      icon: Icons.local_fire_department_rounded,
                    ),
                    const SizedBox(height: 6),
                    _ProMetricRow(
                      title: 'Профиль движений',
                      value: '${track.footballMovementScore}',
                      subtitle: 'рывки, ускорения, торможения, смены направления',
                      icon: Icons.hub_rounded,
                    ),
                    const SizedBox(height: 6),
                    _ProMetricRow(
                      title: 'Ускорения / торможения',
                      value: '${track.accelCount}/${track.decelCount}',
                      subtitle: 'интенсивные механические события',
                      icon: Icons.compare_arrows_rounded,
                    ),
                    const SizedBox(height: 6),
                    _ProMetricRow(
                      title: 'Смена направления',
                      value: '${track.changeOfDirectionCount}',
                      subtitle: 'повороты и перестроения под нагрузкой',
                      icon: Icons.sync_alt_rounded,
                    ),
                    const SizedBox(height: 6),
                    _ProMetricRow(
                      title: 'Усталость',
                      value: '${track.fatigueIndex.toStringAsFixed(0)}%',
                      subtitle: track.fatigueLabel,
                      icon: Icons.battery_alert_rounded,
                      accent: track.fatigueIndex > 70 ? _C.red : _C.green,
                    ),
                    const SizedBox(height: 8),
                    _SpeedLoadChart(track: track),
                    const SizedBox(height: 8),
                    _ZoneDistribution(track: track),
                    const SizedBox(height: 8),
                    _FootballMovementProfileBox(track: track),
                    const SizedBox(height: 8),
                    _RecommendationBox(track: track),
                  ],
                ),
              ),
            ),
          ],
        ),
);

return height == null ? content : SizedBox(height: height, child: content);
}



Widget _playersCard({double? height}) {
final content = _LiveCard(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _TitleRow(
        icon: Icons.groups_rounded,
        title: 'Игроки онлайн',
        subtitle: 'Локальные данные + серверное состояние',
      ),
      const SizedBox(height: 8),
      Expanded(
        child: _tracks.isEmpty && _sessions.isEmpty
            ? const Center(
                child: Text(
                  'Запустите Live, чтобы увидеть игрока',
                  style: TextStyle(color: _C.subtle, fontWeight: FontWeight.w500),
                ),
              )
            : ListView(
                children: [
                  ..._tracks.values.map((track) => _RuntimePlayerTile(track: track)),
                  if (_sessions.isNotEmpty && _tracks.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(height: 1),
                    ),
                  ..._sessions.map((s) => _ServerPlayerTile(session: s)),
                ],
              ),
      ),
    ],
  ),
);

return height == null ? content : SizedBox(height: height, child: content);
}

Widget _debugCard({double? height}) {
final content = _LiveCard(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Expanded(
            child: _TitleRow(
              icon: Icons.bug_report_rounded,
              title: 'Отладка на устройстве',
              subtitle: 'Показывает, где именно ломается цепочка',
            ),
          ),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(4),
            child: _NoHoverTap(
              borderRadius: BorderRadius.circular(4),
              onTap: () => setState(() => _showDebug = !_showDebug),
              child: SizedBox(
                width: 30,
                height: 30,
                child: Icon(_showDebug ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 16, color: const Color(0xFF8B95A3)),
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 5),
      _DebugLine(label: 'TX', value: _lastTx),
      _DebugLine(label: 'RX', value: _lastRx),
      _DebugLine(label: 'GPS', value: _lastGps),
      _DebugLine(label: 'Сохранение', value: _lastSave),
      _DebugLine(
        label: 'Возраст GPS',
        value: _lastGpsAt == null
            ? 'нет'
            : '${DateTime.now().difference(_lastGpsAt!).inSeconds} сек назад',
      ),
      _DebugLine(
        label: 'Возраст сохранения',
        value: _lastSaveAt == null
            ? 'нет'
            : '${DateTime.now().difference(_lastSaveAt!).inSeconds} сек назад',
      ),
      const SizedBox(height: 5),
      if (_showDebug)
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF111512),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(5),
            child: _logs.isEmpty
                ? const Center(
                    child: Text(
                      'Логи появятся здесь',
                      style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w500),
                    ),
                  )
                : ListView.builder(
                    itemCount: _logs.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        _logs[i],
                        style: const TextStyle(
                          color: Color(0xFFE1E5E2),
                          fontSize: 11.2,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'monospace',
                          height: 1.25,
                        ),
                      ),
                    ),
                  ),
          ),
        ),
    ],
  ),
);

return height == null ? content : SizedBox(height: height, child: content);
}
}


class _LiveExpandButton extends StatelessWidget {
const _LiveExpandButton({
required this.tooltip,
required this.onTap,
});

final String tooltip;
final VoidCallback onTap;

@override
Widget build(BuildContext context) {
return Tooltip(
  message: tooltip,
  child: Material(
    color: Colors.white,
    shape: const CircleBorder(),
    child: _NoHoverTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: _OF.greenBorder),
          boxShadow: null,
        ),
        child: const Icon(Icons.open_in_full_rounded, color: _OF.green, size: 16),
      ),
    ),
  ),
);
}
}

class _DebugStep {
const _DebugStep({required this.northM, required this.eastM, required this.dtMs, required this.label});
final double northM;
final double eastM;
final int dtMs;
final String label;
}

class _LiveHrPoint {
  const _LiveHrPoint({required this.timeMs, required this.bpm});
  final int timeMs;
  final int bpm;
}

class _LiveMetricPoint {
  const _LiveMetricPoint({required this.timeMs, required this.value});
  final int timeMs;
  final double value;
}

class _LiveMetricSeries {
  const _LiveMetricSeries({required this.label, required this.color, required this.points});
  final String label;
  final Color color;
  final List<_LiveMetricPoint> points;
}

class _LiveChartThreshold {
  const _LiveChartThreshold({required this.value, required this.label});
  final double value;
  final String label;
}

class _LiveLineChartPainter extends CustomPainter {
  const _LiveLineChartPainter({
    required this.series,
    required this.minY,
    required this.maxY,
    this.thresholds = const <_LiveChartThreshold>[],
    this.valueSuffix = '',
    this.highlightAbove,
  });

  final List<_LiveMetricSeries> series;
  final double minY;
  final double maxY;
  final List<_LiveChartThreshold> thresholds;
  final String valueSuffix;
  final double? highlightAbove;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final chart = Rect.fromLTWH(rect.left + 34, rect.top + 14, math.max(1.0, rect.width - 46), math.max(1.0, rect.height - 34));
    final all = series.expand((s) => s.points).toList(growable: false);
    if (all.isEmpty) return;
    final minTime = all.map((p) => p.timeMs).reduce((a, b) => a < b ? a : b);
    final maxTime = all.map((p) => p.timeMs).reduce((a, b) => a > b ? a : b);
    final spanTime = math.max(1.0, (maxTime - minTime).toDouble());
    final yMin = minY;
    final yMax = math.max(maxY, yMin + 1);

    final grid = Paint()..color = _OF.lineStrong.withOpacity(.8)..strokeWidth = 1;
    final textStyle = TextStyle(color: _OF.muted2.withOpacity(.86), fontSize: 10.4, fontWeight: FontWeight.w700);
    for (var i = 0; i <= 4; i++) {
      final y = chart.bottom - chart.height * (i / 4.0);
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), grid);
      final value = yMin + (yMax - yMin) * (i / 4.0);
      final tp = TextPainter(text: TextSpan(text: value.toStringAsFixed(0), style: textStyle), textDirection: TextDirection.ltr)..layout(maxWidth: 30);
      tp.paint(canvas, Offset(rect.left + 2, y - tp.height / 2));
    }

    for (final threshold in thresholds) {
      if (threshold.value < yMin || threshold.value > yMax) continue;
      final y = chart.bottom - ((threshold.value - yMin) / (yMax - yMin)) * chart.height;
      final paint = Paint()
        ..color = (threshold.value >= 18 || threshold.label == 'Z5' ? _OF.red : _OF.orange).withOpacity(.52)
        ..strokeWidth = 1.2;
      canvas.drawLine(Offset(chart.left, y), Offset(chart.right, y), paint);
      final tp = TextPainter(
        text: TextSpan(text: '${threshold.label} ${threshold.value.toStringAsFixed(0)}', style: TextStyle(color: paint.color.withOpacity(.95), fontSize: 9.6, fontWeight: FontWeight.w900)),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 64);
      tp.paint(canvas, Offset(chart.right - tp.width - 4, y - tp.height - 2));
    }

    double xOf(_LiveMetricPoint p) => chart.left + ((p.timeMs - minTime) / spanTime) * chart.width;
    double yOf(_LiveMetricPoint p) => chart.bottom - ((p.value.clamp(yMin, yMax).toDouble() - yMin) / (yMax - yMin)) * chart.height;

    for (final item in series) {
      final pts = item.points;
      if (pts.isEmpty) continue;
      final path = Path();
      for (var i = 0; i < pts.length; i++) {
        final o = Offset(xOf(pts[i]), yOf(pts[i]));
        if (i == 0) {
          path.moveTo(o.dx, o.dy);
        } else {
          path.lineTo(o.dx, o.dy);
        }
      }
      canvas.drawPath(path, Paint()..color = item.color.withOpacity(.20)..strokeWidth = 5.4..style = PaintingStyle.stroke..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
      canvas.drawPath(path, Paint()..color = item.color.withOpacity(.88)..strokeWidth = 2.1..style = PaintingStyle.stroke..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
      for (final p in pts) {
        if (highlightAbove == null || p.value < highlightAbove!) continue;
        final o = Offset(xOf(p), yOf(p));
        canvas.drawCircle(o, 4.8, Paint()..color = _OF.red.withOpacity(.08));
        canvas.drawCircle(o, 2.7, Paint()..color = _OF.red.withOpacity(.9));
      }
      final last = pts.last;
      final lo = Offset(xOf(last), yOf(last));
      canvas.drawCircle(lo, 5.2, Paint()..color = Colors.white.withOpacity(.95));
      canvas.drawCircle(lo, 3.4, Paint()..color = item.color);
    }

    final footerStyle = TextStyle(color: _OF.muted2.withOpacity(.72), fontSize: 9.6, fontWeight: FontWeight.w700);
    final rightText = '${all.last.value.toStringAsFixed(0)}$valueSuffix';
    final tp = TextPainter(text: TextSpan(text: rightText, style: footerStyle), textDirection: TextDirection.ltr)..layout(maxWidth: 90);
    tp.paint(canvas, Offset(chart.right - tp.width, chart.bottom + 7));
  }

  @override
  bool shouldRepaint(covariant _LiveLineChartPainter oldDelegate) => true;
}

class _RuntimePoint {
final double lat;
final double lon;
final int timeMs;
final double speedKmh;
final double rawSpeedKmh;
final double distanceDeltaM;
final String packetType;
final bool acceptedForMetrics;
final String? rejectReason;

const _RuntimePoint({
required this.lat,
required this.lon,
required this.timeMs,
required this.speedKmh,
required this.rawSpeedKmh,
required this.distanceDeltaM,
required this.packetType,
this.acceptedForMetrics = true,
this.rejectReason,
});
}

class _RuntimeTrack {
_RuntimeTrack({
required this.key,
required this.playerName,
required this.deviceName,
this.avatar,
});

final String key;
final String playerName;
final String deviceName;
final String? avatar;
final List<_RuntimePoint> points = <_RuntimePoint>[];

// Live GPS can jump while the tracker is лежит на столе or has weak satellite lock.
// Do not turn those jumps into 42 км/ч sprints. Keep raw speed only for debug,
// but send 0 speed / 0 distance to analytics and server for rejected points.
static const double _maxAcceptedSpeedKmh = 42.0;
static const double _hardGpsSpikeKmh = 48.0;
static const double _maxAccelerationMps2 = 7.0;
static const double _minMovementM = 0.55;
static const double _maxSingleDeltaM = 12.0;

double speedKmh = 0;
double rawSpeedKmh = 0;
double totalDistanceM = 0;
double maxSpeedKmh = 0;
double lastDeltaM = 0;
int sprintCount = 0;


double get headingDeg {
if (points.length < 2 || lastDeltaM <= 0.25) return 0;
final a = points[points.length - 2];
final b = points.last;
return _bearingDeg(a.lat, a.lon, b.lat, b.lon);
}

String get directionLabel {
if (points.length < 2 || lastDeltaM <= 0.25) return 'нет движения';
return '${headingDeg.round()}°';
}

int get durationSec {
if (points.length < 2) return 0;
return math.max(1, ((points.last.timeMs - points.first.timeMs) / 1000).round());
}

double get avgSpeedKmh {
if (durationSec <= 0) return 0;
return (totalDistanceM / durationSec) * 3.6;
}

double get metersPerMinute {
if (durationSec <= 0) return 0;
return totalDistanceM / (durationSec / 60.0);
}

double get paceMinKm {
if (totalDistanceM <= 1 || durationSec <= 0) return 0;
return (durationSec / 60.0) / (totalDistanceM / 1000.0);
}

String get paceLabel {
if (paceMinKm <= 0 || paceMinKm.isInfinite) return '—';
final min = paceMinKm.floor();
final sec = ((paceMinKm - min) * 60).round().clamp(0, 59);
return '$min:${sec.toString().padLeft(2, '0')}';
}

double get hsrDistanceM => points
  .where((p) => p.speedKmh >= 14.0 && p.speedKmh < 18.0)
  .fold<double>(0, (sum, p) => sum + p.distanceDeltaM);

double get sprintDistanceM => points
  .where((p) => p.speedKmh >= 18.0)
  .fold<double>(0, (sum, p) => sum + p.distanceDeltaM);

int get accelCount {
var count = 0;
for (var i = 1; i < points.length; i++) {
  final dt = math.max(.75, (points[i].timeMs - points[i - 1].timeMs) / 1000.0);
  final acc = ((points[i].speedKmh - points[i - 1].speedKmh) / 3.6) / dt;
  if (acc >= 1.0) count++;
}
return count;
}

int get decelCount {
var count = 0;
for (var i = 1; i < points.length; i++) {
  final dt = math.max(.75, (points[i].timeMs - points[i - 1].timeMs) / 1000.0);
  final acc = ((points[i].speedKmh - points[i - 1].speedKmh) / 3.6) / dt;
  if (acc <= -1.0) count++;
}
return count;
}

double get movingTimeSec => points.where((p) => p.speedKmh >= 4).length.toDouble();

double get restTimeSec => math.max(0, points.length - movingTimeSec).toDouble();

double get workRestRatio => restTimeSec <= 0 ? movingTimeSec : movingTimeSec / restTimeSec;

double get firstPhaseAvgSpeed {
final moving = points.where((p) => p.speedKmh >= 2).toList();
if (moving.length < 5) return avgSpeedKmh;
final n = math.max(3, (moving.length * .33).floor());
return moving.take(n).fold<double>(0, (sum, p) => sum + p.speedKmh) / n;
}

double get recentAvgSpeed {
if (points.isEmpty) return 0;
final end = points.last.timeMs;
final recent = points.where((p) => end - p.timeMs <= 60000 && p.speedKmh >= 2).toList();
if (recent.isEmpty) return speedKmh;
return recent.fold<double>(0, (sum, p) => sum + p.speedKmh) / recent.length;
}

double get speedDropPercent {
final base = firstPhaseAvgSpeed;
if (base <= 1) return 0;
return (((base - recentAvgSpeed) / base) * 100).clamp(0.0, 100.0).toDouble();
}

double get loadScore {
final value = totalDistanceM * .018 +
    hsrDistanceM * .10 +
    sprintDistanceM * .22 +
    accelCount * 3.0 +
    decelCount * 2.4 +
    maxSpeedKmh * .65;
return value.clamp(0.0, 999.0).toDouble();
}

double get loadPerMinute {
if (durationSec <= 0) return 0;
return loadScore / (durationSec / 60.0);
}

double get highIntensityShare {
if (totalDistanceM <= 0) return 0;
return ((hsrDistanceM + sprintDistanceM) / totalDistanceM).clamp(0.0, 1.0).toDouble();
}

double get fatigueIndex {
final value = speedDropPercent * 1.55 +
    highIntensityShare * 42.0 +
    decelCount * 1.4 +
    sprintDistanceM / 20.0;
return value.clamp(0.0, 100.0).toDouble();
}

String get fatigueLabel {
if (fatigueIndex >= 72) return 'риск';
if (fatigueIndex >= 48) return 'контроль';
return 'норма';
}

String get recommendation {
if (speedDropPercent >= 24) {
  return 'Темп заметно падает. Уменьшить рывковую работу или дать восстановление 2–3 минуты.';
}
if (fatigueIndex >= 72) {
  return 'Высокая усталость. Контроль самочувствия и снижение интенсивности.';
}
if (highIntensityShare >= .25) {
  return 'Высокая доля HSR/Sprint. Следить за восстановлением между сериями.';
}
if (accelCount + decelCount >= 10) {
  return 'Много ускорений/торможений. Следить за мышечной нагрузкой.';
}
return 'Нагрузка стабильная. Критичного падения скорости нет.';
}


double get playerLoadEstimate => loadScore;

String get playerLoadSourceLabel => 'внешняя нагрузка по GPS: дистанция, скорость, HIR, спринты, ускорения и торможения';

double get hirDistanceM => points
  .where((p) => p.speedKmh >= 11.5 && p.speedKmh < 14.0)
  .fold<double>(0, (sum, p) => sum + p.distanceDeltaM);

double get vhirDistanceM => points
  .where((p) => p.speedKmh >= 14.0 && p.speedKmh < 18.0)
  .fold<double>(0, (sum, p) => sum + p.distanceDeltaM);

int get highIntensityBurstCount {
var count = 0;
for (var i = 1; i < points.length; i++) {
  if (points[i].speedKmh >= 11.5 && points[i - 1].speedKmh < 11.5) count++;
}
return count;
}

int get changeOfDirectionCount {
if (points.length < 3) return 0;
var count = 0;
for (var i = 2; i < points.length; i++) {
  final a = _bearingDeg(points[i - 2].lat, points[i - 2].lon, points[i - 1].lat, points[i - 1].lon);
  final b = _bearingDeg(points[i - 1].lat, points[i - 1].lon, points[i].lat, points[i].lon);
  var diff = (b - a).abs();
  if (diff > 180) diff = 360 - diff;
  if (diff >= 45 && points[i].speedKmh >= 3.0 && points[i].distanceDeltaM >= 0.7) {
    count++;
  }
}
return count;
}

int get lowSpeedHighLoadCount {
var count = 0;
for (var i = 1; i < points.length; i++) {
  final dt = math.max(.75, (points[i].timeMs - points[i - 1].timeMs) / 1000.0);
  final acc = (((points[i].speedKmh - points[i - 1].speedKmh) / 3.6) / dt).abs();
  if (points[i].speedKmh < 12.0 && acc >= 1.8) count++;
}
return count;
}

int get footballMovementScore =>
  highIntensityBurstCount + accelCount + decelCount + changeOfDirectionCount + lowSpeedHighLoadCount + sprintCount;

double get metabolicPowerProxy {
if (durationSec <= 0) return 0;
final highIntensityM = hirDistanceM + vhirDistanceM + sprintDistanceM;
final mechanical = (accelCount * 1.45) + (decelCount * 1.2) + (changeOfDirectionCount * 1.1);
return ((metersPerMinute * 0.11) + (highIntensityM / durationSec * 2.7) + mechanical / math.max(1, durationSec / 60.0))
    .clamp(0.0, 99.0)
    .toDouble();
}

Map<String, int> get footballMovementProfile => {
    'bursts': highIntensityBurstCount,
    'accelerations': accelCount,
    'decelerations': decelCount,
    'change_of_direction': changeOfDirectionCount,
    'low_speed_high_load': lowSpeedHighLoadCount,
    'sprints': sprintCount,
  };

List<String> get alertCandidates {
final alerts = <String>[];
if (maxSpeedKmh >= 30) alerts.add('Спринт > 30 км/ч');
if (speedDropPercent >= 20) alerts.add('Падение темпа > 20%');
if (fatigueIndex >= 70) alerts.add('Высокий fatigue');
if (changeOfDirectionCount >= 6) alerts.add('Много смен направления');
if (lowSpeedHighLoadCount >= 8) alerts.add('Низкая скорость, высокая механика');
return alerts;
}

Map<String, dynamic> toJson() => {
    'duration_sec': durationSec,
    'distance_m': totalDistanceM,
    'speed_kmh': speedKmh,
    'max_speed_kmh': maxSpeedKmh,
    'avg_speed_kmh': avgSpeedKmh,
    'meterage_per_min': metersPerMinute,
    'pace_min_km': paceMinKm,
    'load_score': loadScore,
    'player_load_estimate': playerLoadEstimate,
    'player_load_source': playerLoadSourceLabel,
    'load_per_min': loadPerMinute,
    'fatigue_index': fatigueIndex,
    'speed_drop_percent': speedDropPercent,
    'hsr_distance_m': hsrDistanceM,
    'hir_distance_m': hirDistanceM,
    'vhir_distance_m': vhirDistanceM,
    'sprint_distance_m': sprintDistanceM,
    'sprint_count': sprintCount,
    'accel_count': accelCount,
    'change_of_direction_count': changeOfDirectionCount,
    'low_speed_high_load_count': lowSpeedHighLoadCount,
    'football_movement_score': footballMovementScore,
    'metabolic_power_proxy': metabolicPowerProxy,
    'football_movement_profile': footballMovementProfile,
    'alert_candidates': alertCandidates,
    'decel_count': decelCount,
    'work_rest_ratio': workRestRatio,
    'recommendation': recommendation,
  };

_RuntimePoint addPoint({
required double latitude,
required double longitude,
required int timeMs,
required String packetType,
}) {
double rawDelta = 0;
double acceptedDelta = 0;
double speed = 0;
double raw = 0;
bool accepted = true;
String? rejectReason;

if (points.isNotEmpty) {
  final prev = points.last;
  rawDelta = _haversineM(prev.lat, prev.lon, latitude, longitude);
  final dt = math.max(0.75, (timeMs - prev.timeMs) / 1000.0);
  raw = (rawDelta / dt) * 3.6;

  final acceleration = ((raw - prev.speedKmh) / 3.6) / dt;
  final allowedDelta = math.max(_maxSingleDeltaM, dt * (_maxAcceptedSpeedKmh / 3.6));
  final recentRest = points.reversed
      .take(4)
      .where((p) => p.speedKmh <= 1.2 && p.distanceDeltaM <= _minMovementM)
      .length;

  if (rawDelta <= _minMovementM) {
    acceptedDelta = 0;
    speed = 0;
  } else if (raw > _hardGpsSpikeKmh) {
    accepted = false;
    rejectReason = 'GPS-шум: raw ${raw.toStringAsFixed(1)} км/ч выше лимита';
  } else if (rawDelta > allowedDelta) {
    accepted = false;
    rejectReason = 'GPS-шум: скачок ${rawDelta.toStringAsFixed(1)} м за ${dt.toStringAsFixed(1)} c';
  } else if (acceleration.abs() > _maxAccelerationMps2 && raw >= 16.0) {
    accepted = false;
    rejectReason = 'GPS-шум: ускорение ${acceleration.toStringAsFixed(1)} м/с²';
  } else if (recentRest >= 3 && raw >= 12.0 && rawDelta >= 3.0) {
    accepted = false;
    rejectReason = 'GPS-шум после покоя: ${rawDelta.toStringAsFixed(1)} м';
  } else {
    acceptedDelta = rawDelta;
    speed = raw.clamp(0.0, _maxAcceptedSpeedKmh).toDouble();
  }

  if (accepted) {
    totalDistanceM += acceptedDelta;
    if (speed >= 20.0 && points.last.speedKmh < 20.0) {
      sprintCount += 1;
    }
  } else {
    acceptedDelta = 0;
    speed = 0;
  }
}

speedKmh = speed;
rawSpeedKmh = raw;
if (accepted) {
  maxSpeedKmh = math.max(maxSpeedKmh, speed);
}
lastDeltaM = acceptedDelta;

final prev = points.isNotEmpty ? points.last : null;
final p = _RuntimePoint(
  lat: accepted || prev == null ? latitude : prev.lat,
  lon: accepted || prev == null ? longitude : prev.lon,
  timeMs: timeMs,
  speedKmh: speed,
  rawSpeedKmh: raw,
  distanceDeltaM: acceptedDelta,
  packetType: packetType,
  acceptedForMetrics: accepted,
  rejectReason: rejectReason,
);

points.add(p);
if (points.length > 900) {
  points.removeAt(0);
}

return p;
}
}

double _haversineM(double lat1, double lon1, double lat2, double lon2) {
const r = 6371000.0;
final dLat = _deg(lat2 - lat1);
final dLon = _deg(lon2 - lon1);
final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
  math.cos(_deg(lat1)) *
      math.cos(_deg(lat2)) *
      math.sin(dLon / 2) *
      math.sin(dLon / 2);
return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double _deg(double v) => v * math.pi / 180.0;

double _bearingDeg(double lat1, double lon1, double lat2, double lon2) {
final p1 = _deg(lat1);
final p2 = _deg(lat2);
final dLon = _deg(lon2 - lon1);
final y = math.sin(dLon) * math.cos(p2);
final x = math.cos(p1) * math.sin(p2) -
  math.sin(p1) * math.cos(p2) * math.cos(dLon);
final brng = math.atan2(y, x) * 180 / math.pi;
return (brng + 360) % 360;
}



class _RuntimeFieldPainter extends CustomPainter {
_RuntimeFieldPainter({
required this.field,
required this.tracks,
this.showVectors = true,
this.showHeatmap = true,
this.showTrace = true,
this.showLabels = true,
this.showLoadHotPoints = false,
});

final TrackerFieldModel? field;
final List<_RuntimeTrack> tracks;
final bool showVectors;
final bool showHeatmap;
final bool showTrace;
final bool showLabels;
final bool showLoadHotPoints;

@override
void paint(Canvas canvas, Size size) {
final full = Offset.zero & size;
_drawBackground(canvas, full);

final pitch = _fitPitch(full.deflate(12));
_drawRealPitch(canvas, pitch);

final allPoints = tracks.expand((t) => t.points).toList();
if (allPoints.isEmpty) {
  _drawCenterText(
    canvas,
    full,
    field?.hasCalibration == true
        ? 'Ждём GPS от трекера'
        : 'Откалибруйте поле по 4 углам',
  );
  return;
}

final bounds = _mapBounds(allPoints);

if (showHeatmap) {
  _drawHeatLayer(canvas, pitch, allPoints, bounds);
}

for (final track in tracks) {
  if (track.points.isEmpty) continue;
  if (showTrace) _drawTrace(canvas, pitch, track, bounds);
  if (showLoadHotPoints) _drawLoadHotPoints(canvas, pitch, track, bounds);
  if (showVectors) _drawVector(canvas, pitch, track, bounds);
  _drawPlayer(canvas, pitch, track, bounds);
  if (showLabels) _drawPlayerLabel(canvas, pitch, track, bounds);
}

_drawPitchMeta(canvas, pitch);
}

void _drawBackground(Canvas canvas, Rect full) {
// Светлая CMR-подложка без чёрного фона вокруг поля.
canvas.drawRRect(
  RRect.fromRectAndRadius(full, const Radius.circular(8)),
  Paint()..color = const Color(0xFFF8F9FA),
);

final grid = Paint()
  ..color = const Color(0xFFE1E5E2).withOpacity(.34)
  ..strokeWidth = .6;

const step = 32.0;
for (double x = 0; x <= full.width; x += step) {
  canvas.drawLine(
    Offset(full.left + x, full.top),
    Offset(full.left + x, full.bottom),
    grid,
  );
}
for (double y = 0; y <= full.height; y += step) {
  canvas.drawLine(
    Offset(full.left, full.top + y),
    Offset(full.right, full.top + y),
    grid,
  );
}
}

Rect _fitPitch(Rect area) {
final length = field?.lengthM ?? 105.0;
final width = field?.widthM ?? 68.0;
final aspect = length / width;

var w = area.width;
var h = w / aspect;
if (h > area.height) {
  h = area.height;
  w = h * aspect;
}

return Rect.fromCenter(center: area.center, width: w, height: h);
}

void _drawRealPitch(Canvas canvas, Rect pitch) {
final outer = RRect.fromRectAndRadius(pitch, const Radius.circular(8));

canvas.drawRRect(
  outer,
  Paint()
    ..shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF6F8F73), Color(0xFF56765C)],
    ).createShader(pitch),
);

final stripePaint = Paint();
final stripeCount = 14;
final stripeW = pitch.width / stripeCount;
for (var i = 0; i < stripeCount; i++) {
  stripePaint.color =
      i.isEven ? Colors.white.withOpacity(.035) : Colors.black.withOpacity(.045);
  canvas.drawRect(
    Rect.fromLTWH(pitch.left + i * stripeW, pitch.top, stripeW, pitch.height),
    stripePaint,
  );
}

final inner = pitch.deflate(math.min(pitch.width, pitch.height) * .028);
final line = Paint()
  ..color = Colors.white.withOpacity(.82)
  ..strokeWidth = math.max(1.4, pitch.width * .0034)
  ..style = PaintingStyle.stroke;
final thin = Paint()
  ..color = Colors.white.withOpacity(.70)
  ..strokeWidth = math.max(1.0, pitch.width * .0023)
  ..style = PaintingStyle.stroke;

canvas.drawRRect(
  RRect.fromRectAndRadius(inner, const Radius.circular(4)),
  line,
);

final centerX = inner.center.dx;
canvas.drawLine(Offset(centerX, inner.top), Offset(centerX, inner.bottom), thin);
canvas.drawCircle(inner.center, inner.height * .135, thin);
canvas.drawCircle(inner.center, math.max(2.3, inner.width * .004), Paint()..color = Colors.white.withOpacity(.82));

final penaltyW = inner.width * .165;
final penaltyH = inner.height * .54;
final boxW = inner.width * .058;
final boxH = inner.height * .24;

final leftPenalty = Rect.fromLTWH(inner.left, inner.center.dy - penaltyH / 2, penaltyW, penaltyH);
final rightPenalty = Rect.fromLTWH(inner.right - penaltyW, inner.center.dy - penaltyH / 2, penaltyW, penaltyH);
final leftBox = Rect.fromLTWH(inner.left, inner.center.dy - boxH / 2, boxW, boxH);
final rightBox = Rect.fromLTWH(inner.right - boxW, inner.center.dy - boxH / 2, boxW, boxH);

canvas.drawRect(leftPenalty, thin);
canvas.drawRect(rightPenalty, thin);
canvas.drawRect(leftBox, thin);
canvas.drawRect(rightBox, thin);

final spotOffset = inner.width * .108;
canvas.drawCircle(Offset(inner.left + spotOffset, inner.center.dy), 2.2, Paint()..color = Colors.white.withOpacity(.82));
canvas.drawCircle(Offset(inner.right - spotOffset, inner.center.dy), 2.2, Paint()..color = Colors.white.withOpacity(.82));

final goalDepth = math.max(6.0, inner.width * .018);
final goalH = inner.height * .14;
final goalPaint = Paint()
  ..color = Colors.white.withOpacity(.82)
  ..strokeWidth = math.max(1.2, pitch.width * .002)
  ..style = PaintingStyle.stroke;
canvas.drawRect(Rect.fromLTWH(inner.left - goalDepth, inner.center.dy - goalH / 2, goalDepth, goalH), goalPaint);
canvas.drawRect(Rect.fromLTWH(inner.right, inner.center.dy - goalH / 2, goalDepth, goalH), goalPaint);

final cornerR = inner.height * .035;
final cornerPaint = thin;
canvas.drawArc(Rect.fromCircle(center: inner.topLeft, radius: cornerR), 0, math.pi / 2, false, cornerPaint);
canvas.drawArc(Rect.fromCircle(center: inner.topRight, radius: cornerR), math.pi / 2, math.pi / 2, false, cornerPaint);
canvas.drawArc(Rect.fromCircle(center: inner.bottomRight, radius: cornerR), math.pi, math.pi / 2, false, cornerPaint);
canvas.drawArc(Rect.fromCircle(center: inner.bottomLeft, radius: cornerR), -math.pi / 2, math.pi / 2, false, cornerPaint);

// Боковые технические зоны — визуально похоже на реальное поле в аналитических программах.
final benchPaint = Paint()
  ..color = Colors.black.withOpacity(.13)
  ..style = PaintingStyle.fill;
canvas.drawRRect(
  RRect.fromRectAndRadius(
    Rect.fromLTWH(inner.left + inner.width * .31, inner.top - pitch.height * .035, inner.width * .14, pitch.height * .025),
    const Radius.circular(3),
  ),
  benchPaint,
);
canvas.drawRRect(
  RRect.fromRectAndRadius(
    Rect.fromLTWH(inner.left + inner.width * .55, inner.top - pitch.height * .035, inner.width * .14, pitch.height * .025),
    const Radius.circular(3),
  ),
  benchPaint,
);
}

_MapBounds _mapBounds(List<_RuntimePoint> allPoints) {
final latValues = <double>[];
final lonValues = <double>[];

final selectedField = field;
if (selectedField?.hasCalibration == true) {
  final cornersLat = <double?>[
    selectedField!.cornerALat,
    selectedField.cornerBLat,
    selectedField.cornerCLat,
    selectedField.cornerDLat,
  ];
  final cornersLon = <double?>[
    selectedField.cornerALng,
    selectedField.cornerBLng,
    selectedField.cornerCLng,
    selectedField.cornerDLng,
  ];
  latValues.addAll(cornersLat.whereType<double>());
  lonValues.addAll(cornersLon.whereType<double>());
}

for (final p in allPoints) {
  if (p.lat.isFinite && p.lon.isFinite) {
    latValues.add(p.lat);
    lonValues.add(p.lon);
  }
}

if (latValues.isEmpty || lonValues.isEmpty) {
  // Нет ни GPS-точек, ни валидных углов поля: рисуем стабильный пустой диапазон,
  // а не падаем на reduce()/null-check при первом открытии мобильного Live.
  return const _MapBounds(minLat: -0.00005, maxLat: 0.00005, minLon: -0.00005, maxLon: 0.00005);
}

var minLat = latValues.reduce(math.min);
var maxLat = latValues.reduce(math.max);
var minLon = lonValues.reduce(math.min);
var maxLon = lonValues.reduce(math.max);

// Если GPS-точки почти не сдвинулись, добавляем небольшой диапазон,
// чтобы точка не прыгала по всему полю.
if ((maxLat - minLat).abs() < 0.00001) {
  minLat -= 0.00005;
  maxLat += 0.00005;
}
if ((maxLon - minLon).abs() < 0.00001) {
  minLon -= 0.00005;
  maxLon += 0.00005;
}

return _MapBounds(minLat: minLat, maxLat: maxLat, minLon: minLon, maxLon: maxLon);
}

void _drawHeatLayer(Canvas canvas, Rect pitch, List<_RuntimePoint> points, _MapBounds bounds) {
final lastPoints = points.length > 160 ? points.sublist(points.length - 160) : points;
for (final p in lastPoints) {
  final pos = _project(p, pitch, bounds);
  final intensity = (p.speedKmh / 28).clamp(.12, .9).toDouble();
  final color = p.speedKmh >= 25
      ? _C.red
      : p.speedKmh >= 14.0
          ? _C.orange
          : _C.greenDark;

  final radius = 12 + 18 * intensity;
  canvas.drawCircle(
    pos,
    radius,
    Paint()
      ..shader = RadialGradient(
        colors: [
          color.withOpacity(.13 * intensity),
          color.withOpacity(.035 * intensity),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: pos, radius: radius)),
  );
}
}

void _drawTrace(Canvas canvas, Rect pitch, _RuntimeTrack track, _MapBounds bounds) {
if (track.points.length < 2) return;

final path = Path();
for (var i = 0; i < track.points.length; i++) {
  final p = _project(track.points[i], pitch, bounds);
  if (i == 0) {
    path.moveTo(p.dx, p.dy);
  } else {
    path.lineTo(p.dx, p.dy);
  }
}

canvas.drawPath(
  path,
  Paint()
    ..color = Colors.black.withOpacity(.08)
    ..strokeWidth = 5.5
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round,
);

canvas.drawPath(
  path,
  Paint()
    ..color = _C.greenDark.withOpacity(.72)
    ..strokeWidth = 2.2
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round,
);
}

void _drawLoadHotPoints(Canvas canvas, Rect pitch, _RuntimeTrack track, _MapBounds bounds) {
  if (track.points.isEmpty) return;
  for (final point in track.points) {
    final hot = point.speedKmh >= 18.0 || point.distanceDeltaM >= 5.0;
    final mid = point.speedKmh >= 14.0 || point.distanceDeltaM >= 3.0;
    if (!hot && !mid) continue;
    final pos = _project(point, pitch, bounds);
    final color = hot ? _C.red : _C.orange;
    final radius = hot ? 6.2 : 4.6;
    canvas.drawCircle(pos, radius + 4, Paint()..color = color.withOpacity(.13));
    canvas.drawCircle(pos, radius, Paint()..color = color.withOpacity(hot ? .88 : .76));
    canvas.drawCircle(
      pos,
      radius + 1.6,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withOpacity(.72),
    );
  }
}

void _drawVector(Canvas canvas, Rect pitch, _RuntimeTrack track, _MapBounds bounds) {
if (track.points.length < 2 || track.lastDeltaM <= 0.25) return;

final last = track.points.last;
final pos = _project(last, pitch, bounds);
final angle = track.headingDeg * math.pi / 180.0;
final length = (24 + track.speedKmh * 1.4).clamp(24.0, 62.0);
final end = Offset(
  pos.dx + math.sin(angle) * length,
  pos.dy - math.cos(angle) * length,
);

final paint = Paint()
  ..color = track.speedKmh >= 20 ? _C.orange.withOpacity(.82) : _C.greenDark.withOpacity(.78)
  ..strokeWidth = 2.4
  ..strokeCap = StrokeCap.round;
canvas.drawLine(pos, end, paint);

final head1 = angle + math.pi * .78;
final head2 = angle - math.pi * .78;
final h = 10.0;
canvas.drawLine(end, Offset(end.dx + math.sin(head1) * h, end.dy - math.cos(head1) * h), paint);
canvas.drawLine(end, Offset(end.dx + math.sin(head2) * h, end.dy - math.cos(head2) * h), paint);
}

void _drawPlayer(Canvas canvas, Rect pitch, _RuntimeTrack track, _MapBounds bounds) {
final last = track.points.last;
final pos = _project(last, pitch, bounds);
final color = track.speedKmh >= 25
    ? _C.red
    : track.speedKmh >= 14.0
        ? _C.orange
        : _C.greenLight;

canvas.drawCircle(
  pos,
  15,
  Paint()
    ..color = color.withOpacity(.08)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
);
canvas.drawCircle(pos, 9, Paint()..color = color);
canvas.drawCircle(
  pos,
  12,
  Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.8
    ..color = Colors.white.withOpacity(.82),
);

final tp = TextPainter(
  text: TextSpan(
    text: track.speedKmh.toStringAsFixed(1),
    style: const TextStyle(
      color: Color(0xFFF4F5F6),
      fontSize: 11.0,
      fontWeight: FontWeight.w500,
      fontFeatures: [FontFeature.tabularFigures()],
    ),
  ),
  textDirection: TextDirection.ltr,
)..layout(maxWidth: 36);
tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
}

void _drawPlayerLabel(Canvas canvas, Rect pitch, _RuntimeTrack track, _MapBounds bounds) {
final pos = _project(track.points.last, pitch, bounds);
final label = '${track.playerName} · ${track.speedKmh.toStringAsFixed(1)} км/ч';

final tp = TextPainter(
  text: TextSpan(
    text: label.length > 30 ? '${label.substring(0, 30)}…' : label,
    style: const TextStyle(
      color: Colors.white,
      fontSize: 11.4,
      fontWeight: FontWeight.w500,
      letterSpacing: -.1,
      shadows: [Shadow(color: Colors.black87, blurRadius: 7)],
    ),
  ),
  textDirection: TextDirection.ltr,
)..layout(maxWidth: math.min(210, pitch.width * .56));

final left = (pos.dx + 14).clamp(pitch.left + 6, pitch.right - tp.width - 20).toDouble();
final top = (pos.dy - 34).clamp(pitch.top + 6, pitch.bottom - 28).toDouble();

final bg = RRect.fromRectAndRadius(
  Rect.fromLTWH(left, top, tp.width + 18, 25),
  const Radius.circular(8),
);

canvas.drawRRect(bg, Paint()..color = Colors.black.withOpacity(.34));
canvas.drawRRect(
  bg,
  Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1
    ..color = Colors.white.withOpacity(.07),
);
tp.paint(canvas, Offset(bg.left + 9, bg.top + 5));
}

void _drawPitchMeta(Canvas canvas, Rect pitch) {
final text = field?.hasCalibration == true
    ? '${field!.title} · ${field!.lengthM.toStringAsFixed(0)}×${field!.widthM.toStringAsFixed(0)} м'
    : 'Поле 105×68 · калибровка не задана';

final tp = TextPainter(
  text: TextSpan(
    text: text,
    style: TextStyle(
      color: Colors.white.withOpacity(.78),
      fontSize: 11.2,
      fontWeight: FontWeight.w500,
    ),
  ),
  textDirection: TextDirection.ltr,
)..layout(maxWidth: pitch.width - 24);

final bg = RRect.fromRectAndRadius(
  Rect.fromLTWH(pitch.left + 10, pitch.bottom - 30, tp.width + 18, 22),
  const Radius.circular(7),
);
canvas.drawRRect(bg, Paint()..color = Colors.black.withOpacity(.24));
tp.paint(canvas, Offset(bg.left + 9, bg.top + 4));
}

Offset _project(_RuntimePoint p, Rect pitch, _MapBounds bounds) {
final lonRange = (bounds.maxLon - bounds.minLon).abs();
final latRange = (bounds.maxLat - bounds.minLat).abs();

final nx = lonRange < 0.000001
    ? 0.5
    : ((p.lon - bounds.minLon) / lonRange).clamp(0.035, 0.965).toDouble();
final ny = latRange < 0.000001
    ? 0.5
    : ((p.lat - bounds.minLat) / latRange).clamp(0.035, 0.965).toDouble();

return Offset(
  pitch.left + nx * pitch.width,
  pitch.bottom - ny * pitch.height,
);
}

void _drawCenterText(Canvas canvas, Rect full, String text) {
final tp = TextPainter(
  text: TextSpan(
    text: text,
    style: TextStyle(
      color: Colors.white.withOpacity(.86),
      fontSize: full.width < 360 ? 12.5 : 14.5,
      fontWeight: FontWeight.w500,
      letterSpacing: -.15,
    ),
  ),
  textDirection: TextDirection.ltr,
  textAlign: TextAlign.center,
)..layout(maxWidth: full.width - 48);

tp.paint(
  canvas,
  Offset(
    (full.width - tp.width) / 2,
    (full.height - tp.height) / 2,
  ),
);
}

@override
bool shouldRepaint(covariant _RuntimeFieldPainter oldDelegate) => true;
}

class _MapBounds {
const _MapBounds({
required this.minLat,
required this.maxLat,
required this.minLon,
required this.maxLon,
});

final double minLat;
final double maxLat;
final double minLon;
final double maxLon;
}



class _TrackerPlayerAvatarDark extends StatelessWidget {
const _TrackerPlayerAvatarDark({
required this.photo,
required this.name,
required this.size,
required this.borderColor,
});

final String? photo;
final String name;
final double size;
final Color borderColor;

@override
Widget build(BuildContext context) {
final url = _trackerAbsolutePhotoUrl(photo);
final initials = _trackerInitials(name);
return Container(
  width: size,
  height: size,
  decoration: BoxDecoration(
    color: _C.greenSoft,
    borderRadius: BorderRadius.circular(4),
    border: Border.all(color: borderColor.withOpacity(.55), width: 1.1),
  ),
  clipBehavior: Clip.antiAlias,
  child: url.isEmpty
      ? Center(
          child: Text(
            initials,
            style: TextStyle(color: _C.green, fontSize: size * .28, fontWeight: FontWeight.w500),
          ),
        )
      : Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Center(
            child: Text(
              initials,
              style: TextStyle(color: _C.green, fontSize: size * .28, fontWeight: FontWeight.w500),
            ),
          ),
        ),
);
}
}

String _trackerAbsolutePhotoUrl(String? raw) {
final value = '${raw ?? ''}'.trim();
if (value.isEmpty || value == 'null') return '';
if (value.startsWith('http://') || value.startsWith('https://')) return value;
final cleaned = value.startsWith('/') ? value.substring(1) : value;
return 'https://sportotekaapp.ru/$cleaned';
}

String _trackerInitials(String name) {
final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
if (parts.isEmpty) return 'И';
if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
return '${parts[0].substring(0, 1)}${parts[1].substring(0, 1)}'.toUpperCase();
}

class _RuntimePlayerTile extends StatelessWidget {
const _RuntimePlayerTile({required this.track});

final _RuntimeTrack track;

@override
Widget build(BuildContext context) {
final color = track.speedKmh >= 20 ? _C.orange : _C.green;
return Container(
  margin: const EdgeInsets.only(bottom: 8),
  padding: const EdgeInsets.all(8),
  decoration: BoxDecoration(
    color: _C.greenSoft,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: _C.greenSoft),
  ),
  child: Row(
    children: [
      _TrackerPlayerAvatarDark(photo: track.avatar, name: track.playerName, size: 38, borderColor: color),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(track.playerName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _C.text, fontWeight: FontWeight.w500)),
            const SizedBox(height: 3),
            Text(
              '${track.speedKmh.toStringAsFixed(1)} км/ч · ${(track.totalDistanceM / 1000).toStringAsFixed(2)} км · точек ${track.points.length}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _C.muted, fontSize: 11.7, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
      const SizedBox(width: 5),
      Text('LIVE', style: TextStyle(color: color, fontWeight: FontWeight.w500, fontSize: 12)),
    ],
  ),
);
}
}

class _ServerPlayerTile extends StatelessWidget {
const _ServerPlayerTile({required this.session});

final TrackerLiveSessionModel session;

@override
Widget build(BuildContext context) {
final color = !session.isOnline ? _C.subtle : session.speedKmh >= 20 ? _C.orange : _C.green;
return Container(
  margin: const EdgeInsets.only(bottom: 8),
  padding: const EdgeInsets.all(8),
  decoration: BoxDecoration(
    color: session.isOnline ? _C.soft : _C.panel,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: _C.divider),
  ),
  child: Row(
    children: [
      _TrackerPlayerAvatarDark(photo: session.avatarUrl, name: session.playerName ?? session.deviceName, size: 38, borderColor: color),
      const SizedBox(width: 8),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(session.playerName ?? session.deviceName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _C.text, fontWeight: FontWeight.w500)),
          const SizedBox(height: 3),
          Text('${session.speedKmh.toStringAsFixed(1)} км/ч · ${(session.totalDistanceM / 1000).toStringAsFixed(2)} км · сервер', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _C.subtle, fontSize: 11.7, fontWeight: FontWeight.w500)),
        ]),
      ),
      Text(session.isOnline ? 'СЕРВЕР' : 'ВЫКЛ', style: TextStyle(color: color, fontWeight: FontWeight.w500, fontSize: 11)),
    ],
  ),
);
}
}

class _CoachAlert extends StatelessWidget {
const _CoachAlert({required this.track});
final _RuntimeTrack track;

@override
Widget build(BuildContext context) {
final danger = track.fatigueIndex >= 72 || track.speedDropPercent >= 24;
final warn = !danger && (track.fatigueIndex >= 48 || track.speedDropPercent >= 14);
final color = danger ? _C.red : warn ? _C.orange : _C.green;

return Container(
  padding: const EdgeInsets.all(5),
  decoration: BoxDecoration(
    color: color.withOpacity(.08),
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: color.withOpacity(.08)),
  ),
  child: Row(
    children: [
      Icon(danger ? Icons.warning_amber_rounded : Icons.insights_rounded, color: color),
      const SizedBox(width: 9),
      Expanded(
        child: Text(
          track.recommendation,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: color, fontWeight: FontWeight.w500, fontSize: 11.5, height: 1.25),
        ),
      ),
    ],
  ),
);
}
}

class _ProMetricRow extends StatelessWidget {
const _ProMetricRow({
required this.title,
required this.value,
required this.subtitle,
required this.icon,
this.accent = _C.green,
});

final String title;
final String value;
final String subtitle;
final IconData icon;
final Color accent;

@override
Widget build(BuildContext context) {
return Container(
  constraints: const BoxConstraints(minHeight: 58),
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
  decoration: BoxDecoration(
    color: _C.panel,
    borderRadius: BorderRadius.circular(6),
    border: Border.all(color: _C.divider, width: 1),
    boxShadow: null,
  ),
  child: Row(
    children: [
      Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: accent == _C.red
              ? _C.redSoft
              : accent == _C.orange
                  ? _C.orangeSoft
                  : _C.greenSoft,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: accent.withOpacity(.06)),
        ),
        child: Icon(icon, color: accent, size: 18),
      ),
      const SizedBox(width: 9),
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
                color: _C.text,
                fontFamily: 'Inter',
                fontSize: 11.4,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.15,
                height: 1.12,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _C.subtle,
                fontFamily: 'Inter',
                fontSize: 11.2,
                fontWeight: FontWeight.w500,
                height: 1.18,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(width: 8),
      ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 64, maxWidth: 112),
        child: Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.right,
          style: const TextStyle(
            color: _C.text,
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.w500,
            height: 1.1,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ),
    ],
  ),
);
}
}

class _ProTile extends StatelessWidget {
const _ProTile({
required this.title,
required this.value,
required this.subtitle,
required this.icon,
});

final String title;
final String value;
final String subtitle;
final IconData icon;

@override
Widget build(BuildContext context) {
return _LiveCard(
  padding: const EdgeInsets.all(9),
  child: Row(
    children: [
      Container(
        width: 31,
        height: 31,
        decoration: BoxDecoration(
          color: _C.greenSoft,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: _C.green, size: 17),
      ),
      const SizedBox(width: 5),
      Expanded(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _C.subtle, fontSize: 11.2, fontWeight: FontWeight.w500, letterSpacing: .05)),
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _C.text, fontSize: 15, fontWeight: FontWeight.w500, letterSpacing: -.15, fontFeatures: [FontFeature.tabularFigures()])),
            Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _C.muted, fontSize: 11.0, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    ],
  ),
);
}
}

class _SpeedLoadChart extends StatelessWidget {
const _SpeedLoadChart({required this.track});
final _RuntimeTrack track;

@override
Widget build(BuildContext context) {
return Container(
  height: 58,
  decoration: BoxDecoration(
    color: _C.soft,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: _C.divider),
  ),
  padding: const EdgeInsets.all(5),
  child: Row(
    children: [
      const SizedBox(
        width: 92,
        child: Text(
          'Скорость / темп',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: _C.subtle, fontSize: 11.2, fontWeight: FontWeight.w500),
        ),
      ),
      Expanded(
        child: CustomPaint(
          painter: _SpeedSparklinePainter(points: track.points),
          child: const SizedBox.expand(),
        ),
      ),
    ],
  ),
);
}
}

class _ZoneDistribution extends StatelessWidget {
const _ZoneDistribution({required this.track});
final _RuntimeTrack track;

@override
Widget build(BuildContext context) {
final walk = track.points.where((p) => p.speedKmh < 7).fold<double>(0, (s, p) => s + p.distanceDeltaM);
final jog = track.points.where((p) => p.speedKmh >= 7 && p.speedKmh < 11.5).fold<double>(0, (s, p) => s + p.distanceDeltaM);
final hir = track.hirDistanceM;
final vhir = track.vhirDistanceM;
final sprint = track.sprintDistanceM;
final total = math.max(1.0, walk + jog + hir + vhir + sprint);

return _LiveCard(
  padding: const EdgeInsets.all(5),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text('Зоны интенсивности', style: TextStyle(color: _C.text, fontWeight: FontWeight.w500, fontSize: 12)),
      const SizedBox(height: 8),
      _ZoneLine(label: 'Ходьба', value: walk, total: total, color: _C.subtle),
      _ZoneLine(label: 'Бег', value: jog, total: total, color: _C.green),
      _ZoneLine(label: 'HIR', value: hir, total: total, color: _C.orange),
      _ZoneLine(label: 'VHIR', value: vhir, total: total, color: const Color(0xFFEAB308)),
      _ZoneLine(label: 'Спринт', value: sprint, total: total, color: _C.red),
    ],
  ),
);
}
}

class _ZoneLine extends StatelessWidget {
const _ZoneLine({
required this.label,
required this.value,
required this.total,
required this.color,
});

final String label;
final double value;
final double total;
final Color color;

@override
Widget build(BuildContext context) {
final p = (value / total).clamp(0.0, 1.0).toDouble();
return Padding(
  padding: const EdgeInsets.only(bottom: 7),
  child: Row(
    children: [
      SizedBox(width: 54, child: Text(label, style: const TextStyle(color: _C.muted, fontSize: 11.2, fontWeight: FontWeight.w500))),
      Expanded(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LinearProgressIndicator(
            minHeight: 7,
            value: p,
            backgroundColor: _C.divider,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ),
      const SizedBox(width: 5),
      SizedBox(width: 42, child: Text('${value.toStringAsFixed(0)}м', textAlign: TextAlign.right, style: const TextStyle(color: _C.text, fontSize: 11.2, fontWeight: FontWeight.w500))),
    ],
  ),
);
}
}


class _FootballMovementProfileBox extends StatelessWidget {
const _FootballMovementProfileBox({required this.track});

final _RuntimeTrack track;

@override
Widget build(BuildContext context) {
final profile = track.footballMovementProfile;
final items = <_FmpItem>[
  _FmpItem('Рывок', profile['bursts'] ?? 0),
  _FmpItem('Ускор.', profile['accelerations'] ?? 0),
  _FmpItem('Торм.', profile['decelerations'] ?? 0),
  _FmpItem('Смена напр.', profile['change_of_direction'] ?? 0),
  _FmpItem('Низк. ск. / выс. нагр.', profile['low_speed_high_load'] ?? 0),
  _FmpItem('Спринт', profile['sprints'] ?? 0),
];

return _LiveCard(
  padding: const EdgeInsets.all(10),
  child: LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth < 360 ? 2 : 3;
      final gap = 6.0;
      final itemWidth = (constraints.maxWidth - gap * (columns - 1)) / columns;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Профиль футбольных движений',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _C.text,
              fontFamily: 'Inter',
              fontSize: 11.4,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.15,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final item in items)
                SizedBox(
                  width: itemWidth,
                  child: _MiniFmpTile(label: item.label, value: item.value),
                ),
            ],
          ),
        ],
      );
    },
  ),
);
}
}

class _FmpItem {
const _FmpItem(this.label, this.value);
final String label;
final int value;
}


class _MiniFmpTile extends StatelessWidget {
const _MiniFmpTile({
required this.label,
required this.value,
});

final String label;
final int value;

@override
Widget build(BuildContext context) {
return Container(
  height: 42,
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
  decoration: BoxDecoration(
    color: _C.soft,
    borderRadius: BorderRadius.circular(6),
    border: Border.all(color: _C.divider),
  ),
  child: Row(
    children: [
      Expanded(
        child: Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _C.subtle,
            fontFamily: 'Inter',
            fontSize: 11.0,
            fontWeight: FontWeight.w500,
            height: 1.05,
          ),
        ),
      ),
      const SizedBox(width: 5),
      Text(
        '$value',
        style: const TextStyle(
          color: _C.text,
          fontFamily: 'Inter',
          fontSize: 11.4,
          fontWeight: FontWeight.w500,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    ],
  ),
);
}
}


class _RecommendationBox extends StatelessWidget {
const _RecommendationBox({required this.track});
final _RuntimeTrack track;

@override
Widget build(BuildContext context) {
return _LiveCard(
  padding: const EdgeInsets.all(8),
  child: Row(
      children: [
        const Icon(Icons.psychology_alt_rounded, color: _C.green, size: 22),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            track.recommendation,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _C.greenDark, fontSize: 11.2, fontWeight: FontWeight.w500, height: 1.25),
          ),
        ),
      ],
    ),
  );
}
}



class _LiveDetailHeaderChip extends StatelessWidget {
const _LiveDetailHeaderChip({required this.icon, required this.label});
final IconData icon;
final String label;

@override
Widget build(BuildContext context) {
return Container(
  height: 30,
  padding: const EdgeInsets.symmetric(horizontal: 9),
  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
  child: Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 12, color: _OF.green),
    const SizedBox(width: 5),
    Text(label, style: const TextStyle(color: _OF.text, fontSize: 10.4, fontWeight: FontWeight.w600)),
  ]),
);
}
}

class _PlayerMetricTile extends StatelessWidget {
const _PlayerMetricTile({required this.icon, required this.label, required this.value});
final IconData icon;
final String label;
final String value;

@override
Widget build(BuildContext context) {
return Container(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
  decoration: BoxDecoration(color: _OF.greenSoft, borderRadius: BorderRadius.circular(6), border: Border.all(color: _OF.greenBorder.withOpacity(.7))),
  child: Row(children: [
    Container(width: 30, height: 30, decoration: BoxDecoration(color: Colors.white.withOpacity(.88), borderRadius: BorderRadius.circular(6)), child: Icon(icon, color: _OF.green, size: 16)),
    const SizedBox(width: 8),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _OF.text, fontSize: 12.8, fontWeight: FontWeight.w700, letterSpacing: -.15)),
      const SizedBox(height: 2),
      Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _OF.muted, fontSize: 11.0, fontWeight: FontWeight.w700)),
    ])),
  ]),
);
}
}



class _LiveSourceSelector extends StatelessWidget {
  const _LiveSourceSelector({
    required this.value,
    required this.running,
    required this.heartRateOnline,
    required this.onChanged,
    required this.titleOf,
    required this.iconOf,
  });

  final TrackerLiveSourceMode value;
  final bool running;
  final bool heartRateOnline;
  final ValueChanged<TrackerLiveSourceMode> onChanged;
  final String Function(TrackerLiveSourceMode mode) titleOf;
  final IconData Function(TrackerLiveSourceMode mode) iconOf;

  @override
  Widget build(BuildContext context) {
    final modes = const <TrackerLiveSourceMode>[
      TrackerLiveSourceMode.trackerExperimental,
      TrackerLiveSourceMode.heartRateOnly,
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Источник Live', style: TextStyle(color: _OF.text, fontSize: 11.2, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: modes.map((mode) {
          final active = value == mode;
          final disabled = running;
          final hint = mode == TrackerLiveSourceMode.heartRateOnly && !heartRateOnline ? ' · ждёт bpm' : '';
          return _NoHoverTap(
            onTap: disabled ? null : () => onChanged(mode),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: active ? _OF.greenSoft : _OF.header,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: active ? _OF.greenBorder : _OF.line),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(iconOf(mode), size: 15, color: active ? _OF.green : _OF.graphite),
                const SizedBox(width: 6),
                Text('${titleOf(mode)}$hint', style: TextStyle(color: active ? _OF.green : _OF.graphite, fontSize: 11.0, fontWeight: FontWeight.w700)),
              ]),
            ),
          );
        }).toList(),
      ),
      if (value == TrackerLiveSourceMode.heartRateOnly) ...[
        const SizedBox(height: 6),
        const Text('Этот режим запускает Live без GPS-трекера: online bpm от всех привязанных Polar H10 сохраняется в live_session_id и затем попадает в отчёт.', style: TextStyle(color: _OF.muted, fontSize: 10.4, fontWeight: FontWeight.w700)),
      ],
    ]);
  }
}

class _TeamHeartRateOnlineCard extends StatelessWidget {
  const _TeamHeartRateOnlineCard({required this.players, required this.samples});

  final List<TrackerPlayerOption> players;
  final Map<int, HeartRateSample> samples;

  TrackerPlayerOption? _player(int id) {
    final found = players.where((p) => p.id == id).toList();
    return found.isEmpty ? null : found.first;
  }

  String _zone(int bpm) {
    if (bpm <= 0) return '—';
    if (bpm < 120) return 'Z1';
    if (bpm < 145) return 'Z2';
    if (bpm < 165) return 'Z3';
    if (bpm < 180) return 'Z4';
    return 'Z5';
  }

  @override
  Widget build(BuildContext context) {
    final entries = samples.entries.toList()
      ..sort((a, b) => b.value.measuredAt.compareTo(a.value.measuredAt));
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 30, height: 30, alignment: Alignment.center, decoration: BoxDecoration(color: _OF.greenSoft, borderRadius: BorderRadius.circular(6)), child: const Icon(Icons.groups_2_rounded, color: _OF.green, size: 16)),
          const SizedBox(width: 8),
          Expanded(child: Text('Команда Polar H10 online', style: const TextStyle(color: _OF.text, fontSize: 11.5, fontWeight: FontWeight.w700))),
          Text('${entries.length} игрок.', style: const TextStyle(color: _OF.muted, fontSize: 11.2, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 8),
        if (entries.isEmpty)
          const Text('Нет назначенных Polar H10.', style: TextStyle(color: _OF.muted, fontSize: 10.4, fontWeight: FontWeight.w700))
        else
          ...entries.take(12).map((entry) {
            final p = _player(entry.key);
            final sample = entry.value;
            final age = DateTime.now().difference(sample.measuredAt).inSeconds;
            final fresh = age <= 25;
            return Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(children: [
                Icon(Icons.favorite_rounded, size: 15, color: fresh ? _OF.red : _OF.muted),
                const SizedBox(width: 5),
                Expanded(child: Text(p?.name ?? 'Игрок ${entry.key}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _OF.text, fontSize: 11.2, fontWeight: FontWeight.w700))),
                Text('${sample.bpm} bpm · ${_zone(sample.bpm)}${fresh ? '' : ' · ${age}s'}', style: TextStyle(color: fresh ? _OF.text : _OF.muted, fontSize: 11.2, fontWeight: FontWeight.w700)),
              ]),
            );
          }),
      ]),
    );
  }
}

class _HeartRateLiveCard extends StatelessWidget {
const _HeartRateLiveCard({
  required this.sample,
  required this.teamOnlineCount,
  required this.recommendation,
});

final HeartRateSample? sample;
final int teamOnlineCount;
final String recommendation;

@override
Widget build(BuildContext context) {
  final ageSec = sample == null ? null : DateTime.now().difference(sample!.measuredAt).inSeconds;
  final fresh = sample != null && (ageSec ?? 999) <= 20;
  final bpmText = sample == null ? '—' : '${sample!.bpm} bpm${fresh ? '' : '*'}';
  final zoneText = sample == null
      ? 'нет Polar'
      : sample!.bpm < 120
          ? 'Z1'
          : sample!.bpm < 145
              ? 'Z2'
              : sample!.bpm < 165
                  ? 'Z3'
                  : sample!.bpm < 180
                      ? 'Z4'
                      : 'Z5';
  final battery = sample?.batteryPercent == null ? '—' : '${sample!.batteryPercent}%';

  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(color: _OF.greenSoft, borderRadius: BorderRadius.circular(6)),
              child: const Icon(Icons.monitor_heart_rounded, color: _OF.green, size: 17),
            ),
            const SizedBox(width: 9),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Polar H10 online', style: TextStyle(color: _OF.text, fontSize: 11.8, fontWeight: FontWeight.w700)),
                  SizedBox(height: 2),
                  Text('пульс игрока + командный контроль', style: TextStyle(color: _OF.muted, fontSize: 11.2, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(color: _OF.greenSoft, borderRadius: BorderRadius.circular(99), border: Border.all(color: _OF.greenBorder)),
              child: Text('online $teamOnlineCount', style: const TextStyle(color: _OF.green, fontSize: 10.4, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _SmallEventCounter(label: 'ПУЛЬС', value: bpmText)),
            const SizedBox(width: 8),
            Expanded(child: _SmallEventCounter(label: 'ЗОНА', value: zoneText)),
            const SizedBox(width: 8),
            Expanded(child: _SmallEventCounter(label: 'БАТ.', value: battery)),
          ],
        ),
        const SizedBox(height: 9),
        Text(
          recommendation,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: _OF.text, fontSize: 11.2, fontWeight: FontWeight.w600, height: 1.25),
        ),
      ],
    ),
  );
}
}

class _SmallEventCounter extends StatelessWidget {
const _SmallEventCounter({required this.label, required this.value});
final String label;
final String value;

@override
Widget build(BuildContext context) {
return Container(
  height: 58,
  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Text(value, style: const TextStyle(color: _OF.text, fontSize: 15, fontWeight: FontWeight.w700)),
    const SizedBox(height: 2),
    Text(label, style: const TextStyle(color: _OF.muted, fontSize: 11.2, fontWeight: FontWeight.w700)),
  ]),
);
}
}

class _ActivityModeCard extends StatelessWidget {
const _ActivityModeCard({required this.activity, required this.selected, this.vertical = false});

final TrackerTrainingActivity activity;
final bool selected;
final bool vertical;

@override
Widget build(BuildContext context) {
final iconBox = Container(
  width: vertical ? 46 : 40,
  height: vertical ? 46 : 40,
  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
  child: Icon(activity.icon, color: selected ? _OF.green : _OF.graphite, size: vertical ? 22 : 20),
);

final titleBlock = Column(
  crossAxisAlignment: vertical ? CrossAxisAlignment.center : CrossAxisAlignment.start,
  children: [
    Text(
      activity.title,
      textAlign: vertical ? TextAlign.center : TextAlign.start,
      style: const TextStyle(color: _OF.text, fontSize: 11.6, fontWeight: FontWeight.w700),
    ),
    const SizedBox(height: 3),
    Text(
      activity.subtitle,
      textAlign: vertical ? TextAlign.center : TextAlign.start,
      maxLines: vertical ? 3 : 2,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(color: _OF.muted, fontSize: 11.2, fontWeight: FontWeight.w600, height: 1.25),
    ),
  ],
);

return Material(
  color: selected ? _OF.greenSoft : _OF.header,
  borderRadius: BorderRadius.circular(6),
  child: _NoHoverTap(
    onTap: () => Navigator.of(context).pop(activity),
    borderRadius: BorderRadius.circular(6),
    child: Container(
      constraints: vertical ? const BoxConstraints(minHeight: 150) : null,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: selected ? _OF.greenBorder : _OF.line),
      ),
      child: vertical
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(alignment: Alignment.topRight, child: Icon(selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: selected ? _OF.green : _OF.muted, size: 18)),
                const SizedBox(height: 6),
                iconBox,
                const SizedBox(height: 8),
                titleBlock,
              ],
            )
          : Row(
              children: [
                iconBox,
                const SizedBox(width: 8),
                Expanded(child: titleBlock),
                const SizedBox(width: 8),
                Icon(selected ? Icons.check_circle_rounded : Icons.chevron_right_rounded, color: selected ? _OF.green : _OF.muted, size: 19),
              ],
            ),
    ),
  ),
);
}
}

class _NoFieldMetricTile extends StatelessWidget {
const _NoFieldMetricTile({required this.label, required this.value});

final String label;
final String value;

@override
Widget build(BuildContext context) {
return Container(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _OF.muted, fontSize: 10.4, fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _OF.text, fontSize: 12, fontWeight: FontWeight.w700)),
    ],
  ),
);
}
}

class _LayerChip extends StatelessWidget {
const _LayerChip({required this.label, required this.active, required this.onTap});
final String label;
final bool active;
final VoidCallback onTap;

@override
Widget build(BuildContext context) {
return _NoHoverTap(
  onTap: onTap,
  borderRadius: BorderRadius.circular(7),
  child: Container(
    height: 28,
    padding: const EdgeInsets.symmetric(horizontal: 9),
    decoration: BoxDecoration(
      color: active ? _C.greenSoft : _C.soft,
      borderRadius: BorderRadius.circular(7),
      border: Border.all(
        color: active ? _C.green.withOpacity(.22) : _C.divider,
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            color: active ? _C.green : _C.subtle.withOpacity(.35),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: active ? _C.greenDark : _C.muted,
            fontSize: 11.2,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  ),
);
}
}

class _TinyMetric extends StatelessWidget {
const _TinyMetric({required this.label, required this.value});
final String label;
final String value;

@override
Widget build(BuildContext context) {
return Container(
  height: 28,
  constraints: const BoxConstraints(minWidth: 48),
  padding: const EdgeInsets.symmetric(horizontal: 7),
  decoration: BoxDecoration(
    color: _C.soft,
    borderRadius: BorderRadius.circular(7),
    border: Border.all(color: _C.divider),
  ),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label, style: const TextStyle(color: _C.subtle, fontSize: 9.6, fontWeight: FontWeight.w500)),
      const SizedBox(width: 4),
      Text(value, style: const TextStyle(color: _C.text, fontSize: 10.4, fontWeight: FontWeight.w500)),
    ],
  ),
);
}
}

class _SpeedSparklinePainter extends CustomPainter {
const _SpeedSparklinePainter({required this.points});
final List<_RuntimePoint> points;

@override
void paint(Canvas canvas, Size size) {
final grid = Paint()..color = _C.divider.withOpacity(.65)..strokeWidth = 1;
for (var i = 1; i < 4; i++) {
  final y = size.height * i / 4;
  canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
}

if (points.length < 2) return;
final src = points.length > 45 ? points.sublist(points.length - 45) : points;
final maxSpeed = math.max(8.0, src.map((p) => p.speedKmh).fold<double>(0, (m, v) => math.max(m, v).toDouble()));
final path = Path();

for (var i = 0; i < src.length; i++) {
  final x = src.length == 1 ? 0.0 : size.width * i / (src.length - 1);
  final y = size.height - (src[i].speedKmh / maxSpeed).clamp(0.0, 1.0) * size.height;
  if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
}

canvas.drawPath(
  path,
  Paint()
    ..color = _C.green
    ..strokeWidth = 2.4
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round,
);
}

@override
bool shouldRepaint(covariant _SpeedSparklinePainter oldDelegate) => true;
}




class _LivePeriod {
const _LivePeriod({
  required this.title,
  required this.startRatio,
  required this.endRatio,
  required this.color,
  this.startTime,
  this.endTime,
  this.id,
});

final int? id;
final String title;
final double startRatio;
final double endRatio;
final Color color;
final DateTime? startTime;
final DateTime? endTime;

_LivePeriod copyWith({
  int? id,
  String? title,
  double? startRatio,
  double? endRatio,
  Color? color,
  DateTime? startTime,
  DateTime? endTime,
}) {
  return _LivePeriod(
    id: id ?? this.id,
    title: title ?? this.title,
    startRatio: startRatio ?? this.startRatio,
    endRatio: endRatio ?? this.endRatio,
    color: color ?? this.color,
    startTime: startTime ?? this.startTime,
    endTime: endTime ?? this.endTime,
  );
}

factory _LivePeriod.fromJson(Map<String, dynamic> json) {
  double toDouble(dynamic v, double fallback) {
    if (v is num) return v.toDouble();
    return double.tryParse('$v') ?? fallback;
  }

  DateTime? toDate(dynamic v) {
    final s = '$v'.trim();
    if (s.isEmpty || s == 'null') return null;
    return _trackerMoscowDateTime(s);
  }

  final colorValue = int.tryParse('${json['color_value'] ?? json['color'] ?? ''}');
  return _LivePeriod(
    id: int.tryParse('${json['id'] ?? ''}'),
    title: '${json['title'] ?? json['name'] ?? 'ПЕРИОД'}',
    startRatio: toDouble(json['start_ratio'], .05),
    endRatio: toDouble(json['end_ratio'], .18),
    color: colorValue == null ? _OF.cyan : Color(colorValue),
    startTime: toDate(json['started_at'] ?? json['start_time']),
    endTime: toDate(json['ended_at'] ?? json['end_time']),
  );
}

Map<String, dynamic> toJson() {
  String? dt(DateTime? value) => value?.toIso8601String();
  return {
    'id': id,
    'title': title,
    'start_ratio': startRatio,
    'end_ratio': endRatio,
    'color_value': color.value,
    'started_at': dt(startTime),
    'ended_at': dt(endTime),
  };
}
}

class _OpenFieldTimelinePainter extends CustomPainter {
const _OpenFieldTimelinePainter({required this.points, required this.running, required this.progressRatio});
final List<_RuntimePoint> points;
final bool running;
final double progressRatio;

@override
void paint(Canvas canvas, Size size) {
final baselineY = size.height / 2;
final linePaint = Paint()
  ..color = _OF.lineStrong
  ..strokeWidth = 2
  ..strokeCap = StrokeCap.round;
canvas.drawLine(Offset(4, baselineY), Offset(size.width - 4, baselineY), linePaint);

final src = points.length > 160 ? points.sublist(points.length - 160) : points;
if (src.length >= 2) {
  final start = src.first.timeMs;
  final span = math.max(1, src.last.timeMs - start);
  for (var i = 1; i < src.length; i++) {
    final p = src[i];
    final prev = src[i - 1];
    final ratio = ((p.timeMs - start) / span).clamp(0.0, 1.0).toDouble();
    final x = 4 + (size.width - 8) * ratio;
    final dt = math.max(0.2, (p.timeMs - prev.timeMs) / 1000.0);
    final accel = ((p.speedKmh - prev.speedKmh) / 3.6) / dt;
    Color? color;
    double radius = 2.0;
    if (p.speedKmh >= 18.0) {
      color = _OF.red;
      radius = 3.4;
    } else if (p.speedKmh >= 14.0) {
      color = _OF.cyan;
      radius = 3.0;
    } else if (p.speedKmh >= 11.5) {
      color = _OF.orange;
      radius = 2.7;
    } else if (accel >= 2.0) {
      color = _OF.green;
      radius = 2.4;
    } else if (accel <= -2.0) {
      color = _OF.blue;
      radius = 2.4;
    }
    if (color != null) {
      canvas.drawCircle(Offset(x, baselineY), radius + 2, Paint()..color = color.withOpacity(.06));
      canvas.drawCircle(Offset(x, baselineY), radius, Paint()..color = color);
    }
  }
}

if (running) {
  final x = 4 + (size.width - 8) * progressRatio.clamp(0.0, 1.0);
  canvas.drawLine(Offset(x, baselineY - 9), Offset(x, baselineY + 9), Paint()..color = _OF.green..strokeWidth = 2);
  canvas.drawCircle(Offset(x, baselineY), 4, Paint()..color = Colors.white);
  canvas.drawCircle(Offset(x, baselineY), 3, Paint()..color = _OF.green);
}
}

@override
bool shouldRepaint(covariant _OpenFieldTimelinePainter oldDelegate) => true;
}


class _TeamLoadSnapshot {
const _TeamLoadSnapshot({required this.elapsedSec, required this.avgLoad, required this.maxLoad, required this.connectedPlayers});
final int elapsedSec;
final double avgLoad;
final double maxLoad;
final int connectedPlayers;
}

class _TeamLoadSample {
const _TeamLoadSample({required this.elapsedSec, required this.avgLoad, required this.maxLoad, required this.connectedPlayers});
final int elapsedSec;
final double avgLoad;
final double maxLoad;
final int connectedPlayers;
}

class _TeamLoadTimePainter extends CustomPainter {
const _TeamLoadTimePainter({required this.samples, required this.maxValue, required this.maxElapsedSec, required this.showAxis});

final List<_TeamLoadSample> samples;
final double maxValue;
final int maxElapsedSec;
final bool showAxis;

@override
void paint(Canvas canvas, Size size) {
if (samples.isEmpty || size.width <= 0 || size.height <= 0) return;
final leftPad = showAxis ? 32.0 : 6.0;
final rightPad = 6.0;
final topPad = showAxis ? 10.0 : 22.0;
final bottomPad = showAxis ? 28.0 : 8.0;
final chartW = math.max(1.0, size.width - leftPad - rightPad);
final chartH = math.max(1.0, size.height - topPad - bottomPad);
final origin = Offset(leftPad, topPad + chartH);
final safeMax = math.max(1.0, maxValue);
final safeElapsed = math.max(1, maxElapsedSec);

final gridPaint = Paint()..color = _OF.lineStrong.withOpacity(.65)..strokeWidth = 1;
for (var i = 0; i <= 3; i++) {
  final y = topPad + chartH * i / 3;
  canvas.drawLine(Offset(leftPad, y), Offset(size.width - rightPad, y), gridPaint);
  if (showAxis) {
    final value = safeMax * (3 - i) / 3;
    _drawText(canvas, value.toStringAsFixed(value < 10 ? 1 : 0), Offset(0, y - 7), _OF.muted2, 10, FontWeight.w700);
  }
}

Offset pointFor(_TeamLoadSample sample, double value) {
  final x = leftPad + chartW * (sample.elapsedSec / safeElapsed).clamp(0.0, 1.0);
  final y = origin.dy - chartH * (value / safeMax).clamp(0.0, 1.0);
  return Offset(x, y);
}

final points = <Offset>[];
for (final sample in samples) {
  points.add(pointFor(sample, sample.avgLoad));
}
if (points.length == 1) {
  points.add(Offset(points.first.dx + 0.01, points.first.dy));
}

final path = Path()..moveTo(points.first.dx, points.first.dy);
for (var i = 1; i < points.length; i++) {
  final prev = points[i - 1];
  final cur = points[i];
  final midX = (prev.dx + cur.dx) / 2;
  path.cubicTo(midX, prev.dy, midX, cur.dy, cur.dx, cur.dy);
}
final area = Path.from(path)
  ..lineTo(points.last.dx, origin.dy)
  ..lineTo(points.first.dx, origin.dy)
  ..close();
final gradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [_OF.green.withOpacity(.20), _OF.green.withOpacity(.02)],
).createShader(Rect.fromLTWH(leftPad, topPad, chartW, chartH));
canvas.drawPath(area, Paint()..shader = gradient..style = PaintingStyle.fill);
canvas.drawPath(path, Paint()..color = _OF.green..strokeWidth = showAxis ? 2.2 : 1.9..style = PaintingStyle.stroke..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);

if (showAxis) {
  for (var i = 0; i <= 4; i++) {
    final sec = (safeElapsed * i / 4).round();
    final x = leftPad + chartW * i / 4;
    _drawText(canvas, _formatAxisTime(sec), Offset(x - 12, size.height - 18), _OF.muted2, 10, FontWeight.w700);
  }
}

if (samples.isNotEmpty) {
  var peak = samples.first;
  for (final sample in samples) {
    if (sample.maxLoad > peak.maxLoad) peak = sample;
  }
  final peakPoint = pointFor(peak, peak.avgLoad);
  canvas.drawLine(Offset(peakPoint.dx, topPad), Offset(peakPoint.dx, origin.dy), Paint()..color = _OF.green.withOpacity(.22)..strokeWidth = 1);
  canvas.drawCircle(peakPoint, 5, Paint()..color = Colors.white);
  canvas.drawCircle(peakPoint, 3.8, Paint()..color = _OF.green);
  if (showAxis) {
    final label = peak.maxLoad.toStringAsFixed(peak.maxLoad < 10 ? 1 : 0);
    final rect = RRect.fromRectAndRadius(Rect.fromCenter(center: peakPoint.translate(0, -22), width: 46, height: 24), const Radius.circular(12));
    canvas.drawRRect(rect, Paint()..color = _OF.green);
    _drawText(canvas, label, Offset(rect.left + 9, rect.top + 5), Colors.white, 10, FontWeight.w700);
  }
}
}

String _formatAxisTime(int sec) {
if (sec < 60) return '${sec}s';
final min = (sec / 60).round();
return "${min.toString().padLeft(2, '0')}’";
}

void _drawText(Canvas canvas, String text, Offset offset, Color color, double size, FontWeight weight) {
final tp = TextPainter(
  text: TextSpan(text: text, style: TextStyle(fontFamily: 'Inter', color: color, fontSize: size, fontWeight: weight)),
  maxLines: 1,
  textDirection: TextDirection.ltr,
)..layout();
tp.paint(canvas, offset);
}

@override
bool shouldRepaint(covariant _TeamLoadTimePainter oldDelegate) {
return oldDelegate.samples.length != samples.length ||
    oldDelegate.maxValue != maxValue ||
    oldDelegate.maxElapsedSec != maxElapsedSec ||
    oldDelegate.showAxis != showAxis;
}
}

class _TeamLoadDotsPainter extends CustomPainter {
const _TeamLoadDotsPainter({required this.values, required this.maxValue});

final List<double> values;
final double maxValue;

@override
void paint(Canvas canvas, Size size) {
if (values.isEmpty || size.width <= 0 || size.height <= 0) return;
final gridPaint = Paint()
  ..color = _OF.lineStrong.withOpacity(.58)
  ..strokeWidth = 1;
for (var i = 1; i <= 2; i++) {
  final y = size.height * i / 3;
  canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
}
final safeMax = math.max(1.0, maxValue);
final gap = values.length <= 1 ? 0.0 : size.width / (values.length - 1);
final points = <Offset>[];
for (var i = 0; i < values.length; i++) {
  final x = values.length <= 1 ? size.width / 2 : gap * i;
  final normalized = (values[i] / safeMax).clamp(0.0, 1.0).toDouble();
  final y = size.height - normalized * (size.height - 7) - 3;
  points.add(Offset(x, y));
}
if (points.length >= 2) {
  final path = Path()..moveTo(points.first.dx, points.first.dy);
  for (final p in points.skip(1)) {
    path.lineTo(p.dx, p.dy);
  }
  canvas.drawPath(path, Paint()
    ..color = _OF.green.withOpacity(.58)
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..strokeWidth = 2.2);
}
for (var i = 0; i < points.length; i++) {
  final value = values[i];
  final color = value >= 80 ? _OF.red : (value >= 45 ? _OF.orange : (value >= 15 ? _OF.green : _OF.cyan));
  canvas.drawCircle(points[i], value > 0 ? 4.0 : 2.6, Paint()..color = Colors.white);
  canvas.drawCircle(points[i], value > 0 ? 3.1 : 2.1, Paint()..color = color);
}
}

@override
bool shouldRepaint(covariant _TeamLoadDotsPainter oldDelegate) {
return oldDelegate.maxValue != maxValue || oldDelegate.values.length != values.length || oldDelegate.values.join(',') != values.join(',');
}
}

class _OF {
static const Color black = Color(0xFF252B27);
static const Color bg = Color(0xFFFFFFFF);
static const Color header = Color(0xFFFFFFFF);
static const Color line = Color(0xFFE9ECEA);
static const Color lineStrong = Color(0xFFE1E5E2);
static const Color glass = Color(0xF8FFFFFF);
static const Color text = Color(0xFF111512);
static const Color muted = Color(0xFF374151);
static const Color muted2 = Color(0xFF737B76);
static const Color graphite = Color(0xFF252B27);
static const Color orange = Color(0xFFF59E0B);
static const Color green = Color(0xFF00A750);
static const Color greenSoft = Color(0xFFF3FAF6);
static const Color greenBorder = Color(0xFFD8EDE1);
static const Color pip = Color(0xFFF8FEFA);
static const Color cyan = Color(0xFF06B6D4);
static const Color cyanSoft = Color(0xFFEFFBFF);
static const Color blue = Color(0xFF2563EB);
static const Color blueSoft = Color(0xFFF4F7FF);
static const Color red = Color(0xFFDC2626);
static const Color redSoft = Color(0xFFFEF2F2);

// Единая плотная геометрия Tracker Pro для телефона и планшета.
// Меньше «пухлости», больше рабочей площади под Live, игроков, карту и анализ.
static const double mobilePagePadding = 8.0;
static const double mobileCardRadius = 0.0;
static const double mobileInnerRadius = 0.0;
static const double mobileChipRadius = 10.0;
static const double mobileButtonRadius = 12.0;
static const double tabletCardRadius = 0.0;
static const double tabletInnerRadius = 0.0;
static const double sheetRadius = 16.0;

static List<BoxShadow> get windowShadow => const <BoxShadow>[];

static BoxDecoration unifiedWindow({double radius = 0}) =>
    const BoxDecoration(color: Colors.white);
}


class _KpiData {
const _KpiData(this.title, this.value, this.icon);
final String title;
final String value;
final IconData icon;
}

class _KpiCard extends StatelessWidget {
const _KpiCard({required this.data});
final _KpiData data;

@override
Widget build(BuildContext context) {
return Container(
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
  decoration: BoxDecoration(
    color: _C.panel,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: _C.divider.withOpacity(.92)),
  ),
  child: Row(
    children: [
      Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: _C.greenSoft,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: _C.green.withOpacity(.06)),
        ),
        child: Icon(data.icon, color: _C.green, size: 15),
      ),
      const SizedBox(width: 5),
      Expanded(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              data.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _C.subtle,
                fontSize: 10.4,
                fontWeight: FontWeight.w500,
                height: 1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              data.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _C.text,
                fontSize: 15,
                fontWeight: FontWeight.w500,
                height: 1,
                letterSpacing: -.15,
                fontFeatures: [FontFeature.tabularFigures()],
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

class _DebugLine extends StatelessWidget {
const _DebugLine({required this.label, required this.value});
final String label;
final String value;

@override
Widget build(BuildContext context) {
return Container(
  margin: const EdgeInsets.only(bottom: 7),
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
  decoration: BoxDecoration(color: _C.soft, borderRadius: BorderRadius.circular(8), border: Border.all(color: _C.divider)),
  child: Row(
    children: [
      SizedBox(width: 72, child: Text(label, style: const TextStyle(color: _C.subtle, fontSize: 11.2, fontWeight: FontWeight.w500))),
      Expanded(
        child: Text(
          value,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: _C.text, fontSize: 11.2, fontWeight: FontWeight.w500, fontFamily: 'monospace'),
        ),
      ),
    ],
  ),
);
}
}


class _FullDebugLine extends StatelessWidget {
const _FullDebugLine({required this.label, required this.value});
final String label;
final String value;

@override
Widget build(BuildContext context) {
return Container(
  margin: const EdgeInsets.only(bottom: 8),
  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
  decoration: BoxDecoration(color: _C.soft, borderRadius: BorderRadius.circular(6), border: Border.all(color: _C.divider)),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(width: 82, child: Text(label, style: const TextStyle(color: _C.subtle, fontSize: 11.2, fontWeight: FontWeight.w600))),
      Expanded(
        child: SelectableText(
          value,
          style: const TextStyle(color: _C.text, fontSize: 11.2, fontWeight: FontWeight.w500, fontFamily: 'monospace', height: 1.25),
        ),
      ),
    ],
  ),
);
}
}

class _ProblemBox extends StatelessWidget {
const _ProblemBox({required this.text});
final String text;

@override
Widget build(BuildContext context) {
final isBad = text.toLowerCase().contains('ошибка') || text.toLowerCase().contains('нет ');
final color = isBad ? _C.red : _C.green;
return Container(
  width: double.infinity,
  padding: const EdgeInsets.all(8),
  decoration: BoxDecoration(
    color: isBad ? _C.redSoft : Colors.white,
    borderRadius: BorderRadius.circular(6),
    border: Border.all(color: isBad ? _C.red.withOpacity(.08) : _C.divider),
  ),
  child: Row(
    children: [
      Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: isBad ? _C.redSoft : _C.greenSoft,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(.06)),
        ),
        child: Icon(isBad ? Icons.warning_amber_rounded : Icons.check_rounded, color: color, size: 18),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: isBad ? _C.red : _C.text, fontSize: 11.5, fontWeight: FontWeight.w500, height: 1.25),
        ),
      ),
    ],
  ),
);
}
}

class _StatePill extends StatelessWidget {
const _StatePill({required this.icon, required this.label, required this.ok});
final IconData icon;
final String label;
final bool ok;

@override
Widget build(BuildContext context) {
final color = ok ? _C.green : _C.orange;
return Container(
  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(6),
    border: Border.all(color: ok ? _C.divider : _C.orange.withOpacity(.22)),
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
      Icon(icon, color: color, size: 15),
      const SizedBox(width: 5),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 230),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: ok ? _C.text : _C.orange, fontSize: 11.5, fontWeight: FontWeight.w500),
        ),
      ),
    ],
  ),
);
}
}

class _TitleRow extends StatelessWidget {
const _TitleRow({required this.icon, required this.title, required this.subtitle});
final IconData icon;
final String title;
final String subtitle;

@override
Widget build(BuildContext context) {
return Row(
  children: [
    Container(
      width: 38,
      height: 36,
      decoration: BoxDecoration(
        color: _C.greenSoft,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _C.green.withOpacity(.10)),
      ),
      child: Icon(icon, color: _C.green, size: 19),
    ),
    const SizedBox(width: 9),
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
              color: _C.text,
              fontFamily: 'Inter',
              fontSize: 15,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.25,
              height: 1.08,
            ),
          ),
          if (subtitle.trim().isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _C.subtle,
                fontFamily: 'Inter',
                fontSize: 11.2,
                fontWeight: FontWeight.w500,
                height: 1.28,
              ),
            ),
          ],
        ],
      ),
    ),
  ],
);
}
}

class _LiveCard extends StatelessWidget {
const _LiveCard({
required this.child,
this.padding = const EdgeInsets.all(10),
});

final Widget child;
final EdgeInsetsGeometry padding;

@override
Widget build(BuildContext context) {
return Container(
  padding: padding,
  decoration: const BoxDecoration(
    color: Colors.transparent,
  ),
  child: child,
);
}
}

InputDecoration _input(String label) => InputDecoration(
  labelText: label,
  filled: true,
  fillColor: _C.soft,
  isDense: true,
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
);

class _C {
static const Color bg = Color(0xFFFFFFFF);
static const Color panel = Color(0xFFFFFFFF);
static const Color soft = Color(0xFFFFFFFF);
static const Color soft2 = Color(0xFFF4F5F4);
static const Color text = Color(0xFF111512);
static const Color muted = Color(0xFF374151);
static const Color subtle = Color(0xFF737B76);
static const Color divider = Color(0xFFE9ECEA);

// CMR-акцент: приглушённый зелёный только для статусов и точек.
static const Color green = Color(0xFF067A46);
static const Color greenLight = Color(0xFF2F6B4F);
static const Color greenSoft = Color(0xFFF3FAF6);
static const Color greenSoft2 = Color(0xFFFAFFFC);
static const Color greenDark = Color(0xFF065F46);

static const Color orange = Color(0xFFB45309);
static const Color orangeSoft = Color(0xFFFFF7ED);
static const Color red = Color(0xFFDC2626);
static const Color redSoft = Color(0xFFFEF2F2);
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
      onTap: onTap == null ? null : () => _runAfterPointerSettled(context, onTap),
      onLongPress: onLongPress == null ? null : () => _runAfterPointerSettled(context, onLongPress),
      child: child,
    );
  }
}
