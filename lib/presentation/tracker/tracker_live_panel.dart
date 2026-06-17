
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import 'models/action_tracker_protocol.dart';
import 'models/tracker_live_models.dart';
import 'models/tracker_pro_models.dart';
import 'services/action_tracker_ble_service.dart';
import 'services/tracker_live_api.dart';

enum TrackerLiveSourceMode {
trackerExperimental,
phoneGps,
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
this.batteryPercent,
this.scanningBluetooth = false,
this.onScanBluetooth,
this.onManageTrackers,
this.onLiveRunningChanged,
});

final int clubId;
final int teamId;
final String teamName;
final List<TrackerPlayerOption> players;
final TrackerPlayerOption? selectedPlayer;
final TrackerFieldModel? selectedField;
final ActionTrackerBleService ble;
final List<TrackerDeviceModel> savedDevices;
final int? batteryPercent;
final bool scanningBluetooth;
final VoidCallback? onScanBluetooth;
final VoidCallback? onManageTrackers;
final ValueChanged<bool>? onLiveRunningChanged;

@override
State<TrackerLivePanel> createState() => _TrackerLivePanelState();
}

class _TrackerLivePanelState extends State<TrackerLivePanel>
with AutomaticKeepAliveClientMixin {
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
int _candidateCommandIndex = 0;

bool _starting = false;
bool _savingPoint = false;
bool _running = false;
bool _testingCommands = false;
bool _showDebug = true;
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
DateTime? _startedAt;

final List<_LivePeriod> _periods = <_LivePeriod>[];

@override
bool get wantKeepAlive => true;

@override
void initState() {
super.initState();
_listenBle();
_startPolling();
}

@override
void dispose() {
if (_running) widget.onLiveRunningChanged?.call(false);
_pollTimer?.cancel();
_phoneTimer?.cancel();
_trackerTimer?.cancel();
_heartbeatTimer?.cancel();
_bleSub?.cancel();
_bleLogSub?.cancel();
super.dispose();
}

@override
void didUpdateWidget(covariant TrackerLivePanel oldWidget) {
super.didUpdateWidget(oldWidget);

if (oldWidget.teamId != widget.teamId || oldWidget.clubId != widget.clubId) {
  _phoneTimer?.cancel();
  _trackerTimer?.cancel();
  _heartbeatTimer?.cancel();
  _setLiveRunning(false);

  setState(() {
    _sessions = <TrackerLiveSessionModel>[];
    _tracks.clear();
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
  if (!_running) setState(() {});
}
}

void _setLiveRunning(bool value) {
if (_running == value) return;
_running = value;
if (value) {
  _startedAt ??= DateTime.now();
} else {
  _startedAt = null;
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

  if (_mode == TrackerLiveSourceMode.trackerExperimental) {
    _log('RX $_lastRx');
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
    if (mounted) setState(() {});
    return;
  }

  final point = chunk.points.last;
  final nowMs = DateTime.now().millisecondsSinceEpoch;

  _lastGpsAt = DateTime.now();
  _lastGps =
      '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)} · $typeHex';

  _log('GPS трекера: $_lastGps');

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
  (_) => _loadLiveState(),
);
}

Future<void> _loadLiveState() async {
try {
  final data = await _api.loadTeamLiveState(
    teamId: widget.teamId,
    fieldId: widget.selectedField?.id,
  );
  if (!mounted) return;

  final activeCount = data.where((s) => s.status == 'active' || s.status == 'online' || s.status == 'live').length;
  _lastLiveState = data.isEmpty
      ? 'sessions=0 active=0 · сервер ничего не вернул'
      : 'sessions=${data.length} active=$activeCount · ${_debugSessionLine(data.first)}';

  setState(() => _sessions = data);
  await _loadLivePeriods();
} catch (e) {
  _lastLiveState = 'ОШИБКА load_state: $e';
  _lastProblem = 'Ошибка загрузки Live: $e';
  _log(_lastProblem);
}
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

Future<void> _startLive() async {
final field = widget.selectedField;
if (field == null || !field.hasCalibration) {
  _toast('Сначала выберите и откалибруйте поле');
  _lastProblem = 'Нет калибровки поля';
  setState(() {});
  return;
}

final device = widget.ble.connectedInfo;
if (_mode == TrackerLiveSourceMode.trackerExperimental && device == null) {
  _toast('Сначала нажмите «Поиск Bluetooth» в Live-окне и подключите трекер');
  _lastProblem = 'Трекер не подключён';
  setState(() {});
  return;
}

final deviceUuid = _mode == TrackerLiveSourceMode.phoneGps
    ? 'PHONE-GPS-${widget.teamId}-${widget.selectedPlayer?.id ?? 0}'
    : device!.id;

final deviceName = _mode == TrackerLiveSourceMode.phoneGps
    ? 'Трекер GPS'
    : device!.name;

setState(() {
  _starting = true;
  _lastProblem = 'Старт Live...';
});

try {
  final id = await _api.startLiveSession(
    clubId: widget.clubId,
    teamId: widget.teamId,
    playerId: widget.selectedPlayer?.id,
    fieldId: field.id,
    deviceUuid: deviceUuid,
    deviceName: deviceName,
    source: _mode == TrackerLiveSourceMode.phoneGps ? 'phone' : 'tracker',
    batteryPercent: widget.batteryPercent,
  );

  if (id <= 0) throw Exception('сервер не вернул live_session_id');

  _myLiveSessionId = id;
  _setLiveRunning(true);
  _lastProblem = 'Live запущен. Таймлайн готов: добавляйте периоды тренировки.';
  await _syncLocalPeriodsToServer();

  if (_mode == TrackerLiveSourceMode.phoneGps) {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw Exception('геолокация выключена');

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('нет разрешения на геолокацию');
    }
  }

  _myLiveSessionId = id;
  _setLiveRunning(true);
  _lastProblem = 'Live активен';

  _trackForCurrentDevice();

  if (_mode == TrackerLiveSourceMode.phoneGps) {
    _startPhoneGpsLoop();
  } else {
    _startTrackerLoop();
  }

  _log('Live стартовал: session=$id');
  _serverLog('Live стартовал: session=$id', source: 'live_start');
  await _loadLiveState();
} catch (e) {
  _lastProblem = 'Ошибка старта Live: $e';
  _log(_lastProblem);
  _toast('Live: $e');
} finally {
  if (mounted) setState(() => _starting = false);
}
}

void _startPhoneGpsLoop() {
_phoneTimer?.cancel();

Future<void> tick() async {
  if (!_running || _savingPoint) return;

  try {
    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.bestForNavigation,
    );

    await _handleGpsPoint(
      latitude: pos.latitude,
      longitude: pos.longitude,
      timeMs: DateTime.now().millisecondsSinceEpoch,
      packetType: 'TRACKER',
      rawHex: null,
    );
  } catch (e) {
    _lastProblem = 'GPS телефона: $e';
    _log(_lastProblem);
  }
}

tick();
_phoneTimer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
}

void _startTrackerLoop() {
_trackerTimer?.cancel();
_heartbeatTimer?.cancel();

Future<void> tick() async {
  if (!_running) return;

  final command =
      ActionTrackerBleProfile.commandCurrentGpsCandidates[_candidateCommandIndex];
  final cmd = command
      .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join(' ');

  try {
    _lastTx = cmd;
    _log('TX current GPS кандидат ${_candidateCommandIndex + 1}: $cmd');
    await widget.ble.sendRawCommand(command);
  } catch (e) {
    _lastProblem = 'TX GPS: $e';
    _log(_lastProblem);
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
  timeMs: DateTime.now().millisecondsSinceEpoch,
  packetType: packetType,
);

_lastGpsAt = DateTime.now();
_lastGps =
    '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)} · $packetType';

_lastLocalMetrics = _debugTrackLine(track);
_lastZeroReason = _debugZeroReason(track, stat);

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
final deviceUuid = _mode == TrackerLiveSourceMode.phoneGps
    ? 'PHONE-GPS-${widget.teamId}-${widget.selectedPlayer?.id ?? 0}'
    : (device?.id ?? 'TRACKER');

final track = _trackForCurrentDevice();
final analysis = track.toJson();

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
    'device_uuid': device?.id ?? 'PHONE-GPS',
    'device_name': device?.name ?? 'Live source',
    'snapshot_date': DateTime.now().toIso8601String().substring(0, 10),
    'snapshot_time': DateTime.now().toIso8601String(),
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
    'analysis_json': track.toJson(),
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
        : 'Live остановлен и сохранён как сессия #$finalId · points=$copied';
    _log('Live остановлен: session=$id · stop=$_lastStop');
  } catch (e) {
    _lastStop = 'ОШИБКА: $e';
    _lastProblem = 'Ошибка остановки Live: $e';
    _log(_lastProblem);
  }
}

_myLiveSessionId = null;
await _loadLiveState();
if (mounted) setState(() {});
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
_lastProblem = 'Debug HIR/VHIR/SPR выполнен. Если метрики появились локально, но не появились в SQL — проблема PHP/API.';
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

  _log('--- Проверка завершена ---');
} finally {
  if (mounted) setState(() => _testingCommands = false);
}
}

_RuntimeTrack _trackForCurrentDevice() {
final device = widget.ble.connectedInfo;
final key = _mode == TrackerLiveSourceMode.phoneGps
    ? 'PHONE-${widget.selectedPlayer?.id ?? 0}'
    : (device?.id ?? 'TRACKER');

final playerName = widget.selectedPlayer?.name ?? 'Игрок';
final deviceName = _mode == TrackerLiveSourceMode.phoneGps
    ? 'Трекер GPS'
    : (device?.name ?? 'Трекер');

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
await _api.sendDebugLog(
  teamId: widget.teamId,
  playerId: widget.selectedPlayer?.id,
  liveSessionId: _myLiveSessionId,
  level: level,
  source: source,
  message: message,
  rawHex: rawHex,
);
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
    elevation: 8,
    margin: const EdgeInsets.all(14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: _OF.line)),
    duration: const Duration(seconds: 4),
  ),
);
}

_RuntimeTrack? get _mainTrack {
if (_tracks.isEmpty) return null;
if (widget.ble.connectedInfo != null) {
  final key = widget.ble.connectedInfo!.id;
  if (_tracks.containsKey(key)) return _tracks[key];
}
return _tracks.values.first;
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

Widget _ofVerticalDivider() => Container(width: 1, color: _OF.line.withOpacity(.82));
Widget _ofHorizontalDivider() => Container(height: 1, color: _OF.line.withOpacity(.82));

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
return Container(
  color: Colors.transparent,
  child: Column(
    children: [
      _liveControlStrip(online, active, compact: false),
      _ofHorizontalDivider(),
      Expanded(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: 188, child: _activePlayersPanel(online, active)),
            _ofVerticalDivider(),
            Expanded(
              child: Column(
                children: [
                  Expanded(flex: 84, child: _operatorFieldPanel()),
                  _ofHorizontalDivider(),
                  Expanded(flex: 16, child: _wholeTeamTablePanel()),
                ],
              ),
            ),
            _ofVerticalDivider(),
            SizedBox(width: 224, child: _rightOperatorPanel(online, active)),
          ],
        ),
      ),
      _ofHorizontalDivider(),
      _bottomOperatorBar(online, active),
    ],
  ),
);
}

Widget _tabletOpenFieldLayout(int online, int active, double height) {
return Container(
  color: Colors.transparent,
  child: Column(
    children: [
      _liveControlStrip(online, active, compact: true),
      _ofHorizontalDivider(),
      Expanded(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: 158, child: _activePlayersPanel(online, active)),
            _ofVerticalDivider(),
            Expanded(
              child: Column(
                children: [
                  Expanded(flex: 84, child: _operatorFieldPanel()),
                  _ofHorizontalDivider(),
                  Expanded(flex: 16, child: _wholeTeamTablePanel(compact: true)),
                ],
              ),
            ),
          ],
        ),
      ),
      _ofHorizontalDivider(),
      _bottomOperatorBar(online, active),
    ],
  ),
);
}


Widget _tabletInfoToggleBar(int online, int active) {
  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: () => setState(() => _bottomOperatorExpanded = !_bottomOperatorExpanded),
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            Icon(_bottomOperatorExpanded ? Icons.expand_more_rounded : Icons.chevron_right_rounded, size: 17, color: _OF.graphite),
            const SizedBox(width: 6),
            const Text('Оператор / трекер / debug', style: TextStyle(color: _OF.text, fontSize: 10.8, fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            Text('$online/$active онлайн', style: const TextStyle(color: _OF.muted2, fontSize: 9.6, fontWeight: FontWeight.w600)),
            const Spacer(),
            Text(_bottomOperatorExpanded ? 'Скрыть' : 'Показать', style: const TextStyle(color: _OF.green, fontSize: 9.8, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    ),
  );
}

Widget _phoneOpenFieldLayout(int online, int active) {
return Container(
  color: Colors.transparent,
  child: ListView(
    padding: EdgeInsets.zero,
    children: [
      _liveControlStrip(online, active, compact: true),
      _ofHorizontalDivider(),
      SizedBox(height: 470, child: _operatorFieldPanel()),
      _ofHorizontalDivider(),
      SizedBox(height: 300, child: _activePlayersPanel(online, active)),
      _ofHorizontalDivider(),
      SizedBox(height: 240, child: _wholeTeamTablePanel(compact: true)),
      _ofHorizontalDivider(),
      SizedBox(height: 420, child: _rightOperatorPanel(online, active)),
      _ofHorizontalDivider(),
      _bottomOperatorBar(online, active),
    ],
  ),
);
}

Widget _liveControlStrip(int online, int active, {required bool compact}) {
final fieldReady = widget.selectedField?.hasCalibration == true;
final trackerReady = widget.ble.connectedInfo != null;
final gpsReady = _lastGpsAt != null && DateTime.now().difference(_lastGpsAt!).inSeconds < 8;
final canStart = fieldReady && trackerReady && !_running && !_starting;
final duration = _durationText();

return Container(
  height: compact ? 42 : 44,
  color: Colors.transparent,
  padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12),
  child: Row(
    children: [
      _ofStatusDot(_running ? _OF.green : _OF.orange),
      const SizedBox(width: 8),
      Text(
        _running ? 'Live' : 'Готовность',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: _OF.text, fontSize: 11.6, fontWeight: FontWeight.w700, letterSpacing: -.12),
      ),
      const SizedBox(width: 10),
      _liveMiniChip(Icons.timer_rounded, duration, active: _running),
      if (!compact) ...[
        const SizedBox(width: 6),
        _liveMiniChip(Icons.groups_rounded, '$online/$active', active: online > 0),
        const SizedBox(width: 6),
        _liveMiniChip(Icons.gps_fixed_rounded, gpsReady ? 'GPS' : 'GPS нет', active: gpsReady),
        const SizedBox(width: 6),
        _liveMiniChip(Icons.sensors_rounded, trackerReady ? 'Трекер' : 'Трекер нет', active: trackerReady),
      ],
      const SizedBox(width: 10),
      Expanded(child: _compactLoadTimeline()),
      const SizedBox(width: 10),
      if (!compact)
        SizedBox(
          height: 30,
          child: OutlinedButton.icon(
            onPressed: widget.scanningBluetooth ? null : (widget.onScanBluetooth ?? widget.onManageTrackers),
            style: OutlinedButton.styleFrom(
              foregroundColor: _OF.graphite,
              side: BorderSide.none,
              backgroundColor: _OF.header,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
            ),
            icon: widget.scanningBluetooth
                ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.bluetooth_searching_rounded, size: 14),
            label: Text(widget.scanningBluetooth ? 'Поиск...' : 'Bluetooth', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
          ),
        ),
      const SizedBox(width: 6),
      SizedBox(
        height: 30,
        child: FilledButton.icon(
          onPressed: _starting ? null : (_running ? _stopLive : (canStart ? _startLive : _startLive)),
          style: FilledButton.styleFrom(
            backgroundColor: _running ? _OF.red : _OF.green,
            disabledBackgroundColor: _OF.header,
            disabledForegroundColor: _OF.muted,
            padding: const EdgeInsets.symmetric(horizontal: 11),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
          ),
          icon: Icon(_running ? Icons.stop_rounded : Icons.play_arrow_rounded, size: 14),
          label: Text(_starting ? '...' : (_running ? 'Стоп' : 'Старт'), style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
        ),
      ),
    ],
  ),
);
}

Widget _liveMiniChip(IconData icon, String label, {required bool active}) {
return Container(
  height: 26,
  padding: const EdgeInsets.symmetric(horizontal: 8),
  decoration: BoxDecoration(
    color: active ? _OF.greenSoft : _OF.header,
    borderRadius: BorderRadius.circular(8),
  ),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, color: active ? _OF.green : _OF.muted, size: 13),
      const SizedBox(width: 5),
      Text(label, style: TextStyle(color: active ? _OF.text : _OF.muted, fontSize: 9.4, fontWeight: FontWeight.w700)),
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
final fieldReady = widget.selectedField?.hasCalibration == true;
final trackerReady = widget.ble.connectedInfo != null;
final gpsReady = _lastGpsAt != null && DateTime.now().difference(_lastGpsAt!).inSeconds < 8;
final canStart = fieldReady && trackerReady && !_running && !_starting;
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
          color: _running ? _OF.green.withOpacity(.12) : _OF.orange.withOpacity(.10),
          borderRadius: BorderRadius.circular(6),
          
        ),
        child: Icon(_running ? Icons.radio_button_checked_rounded : Icons.sports_soccer_rounded, color: _running ? _OF.green : _OF.orange, size: 17),
      ),
      const SizedBox(width: 10),
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
                style: const TextStyle(color: _OF.muted, fontSize: 10, fontWeight: FontWeight.w500),
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
        const SizedBox(width: 10),
      ],
      if (!trackerReady && widget.onScanBluetooth != null) ...[
        SizedBox(
          height: 32,
          child: TextButton.icon(
            onPressed: widget.onScanBluetooth,
            style: TextButton.styleFrom(
              foregroundColor: _OF.graphite,
              backgroundColor: const Color(0xFFF1F3F6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
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
        child: OutlinedButton.icon(
          onPressed: _openFullDebugDialog,
          style: OutlinedButton.styleFrom(
            foregroundColor: _OF.graphite,
            side: BorderSide.none,
            backgroundColor: const Color(0xFFF1F3F6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10),
          ),
          icon: const Icon(Icons.bug_report_rounded, size: 15),
          label: Text(compact ? 'DBG' : 'Debug', style: const TextStyle(fontWeight: FontWeight.w500)),
        ),
      ),
      const SizedBox(width: 6),
      SizedBox(
        height: 32,
        child: FilledButton.icon(
          onPressed: _running ? _stopLive : (canStart ? _startLive : null),
          style: FilledButton.styleFrom(
            backgroundColor: _running ? _OF.red : _OF.orange,
            disabledBackgroundColor: const Color(0xFFE2E8F0),
            disabledForegroundColor: _OF.muted,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 14),
          ),
          icon: Icon(_running ? Icons.stop_rounded : Icons.play_arrow_rounded, size: 17),
          label: Text(_running ? 'Стоп' : 'Старт', style: const TextStyle(fontWeight: FontWeight.w500)),
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
return InkWell(
  onTap: onTap,
  child: Container(
    height: double.infinity,
    alignment: Alignment.center,
    padding: const EdgeInsets.symmetric(horizontal: 14),
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
    Text(label, style: TextStyle(color: light ? _OF.muted : Colors.white54, fontSize: 9, fontWeight: FontWeight.w500)),
    const SizedBox(width: 5),
    Text(value, style: TextStyle(color: light ? _OF.text : Colors.white, fontSize: 10, fontWeight: FontWeight.w500)),
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
final sessions = _sessions.isNotEmpty ? _sessions : <TrackerLiveSessionModel>[];
return _ofPanel(
  title: 'Активные игроки',
  subtitle: '$online/$active онлайн',
  actions: _renderingFloatingLiveContent ? const [] : [
    _livePanelWindowButton(
      tooltip: 'Открыть игроков отдельным окном',
      onTap: () => _openExpandedLiveBlock('Активные игроки', Icons.groups_rounded, () => _activePlayersPanel(online, active)),
    ),
  ],
  child: sessions.isEmpty
      ? _playersFallbackList()
      : ListView.builder(
          itemCount: sessions.length,
          itemBuilder: (_, i) {
            final s = sessions[i];
            final isSelected = widget.selectedPlayer?.id == s.playerId;
            final local = _localTrackForPlayer(s.playerId);
            return _ofPlayerRow(
              name: s.playerName ?? 'Игрок ${s.playerId ?? ''}',
              number: '${i + 1}',
              speed: math.max(s.speedKmh, local?.speedKmh ?? 0.0),
              load: math.max(s.loadScore, local?.loadScore ?? 0.0),
              online: s.isOnline || (local?.points.isNotEmpty ?? false),
              selected: isSelected,
            );
          },
        ),
);
}

Widget _playersFallbackList() {
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
      online: false,
      selected: widget.selectedPlayer?.id == p.id,
    );
  },
);
}

Widget _ofPlayerRow({required String name, required String number, required double speed, required double load, required bool online, required bool selected}) {
return Container(
  height: 38,
  margin: const EdgeInsets.only(bottom: 3),
  decoration: BoxDecoration(
    color: selected ? _OF.blueSoft : (online ? _OF.greenSoft : Colors.white),
    border: Border(left: BorderSide(color: online ? _OF.green : _OF.line, width: 4), bottom: const BorderSide(color: _OF.line)),
  ),
  child: Row(children: [
    SizedBox(width: 34, child: Center(child: Text(number, style: const TextStyle(color: _OF.text, fontSize: 10.6, fontWeight: FontWeight.w500)))),
    Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _OF.text, fontSize: 10.6, fontWeight: FontWeight.w500))),
    Text('${speed.toStringAsFixed(1)}', style: const TextStyle(color: _OF.text, fontSize: 10, fontWeight: FontWeight.w500)),
    const SizedBox(width: 8),
    Text(load.toStringAsFixed(0), style: TextStyle(color: load > 70 ? _OF.red : _OF.muted, fontSize: 10, fontWeight: FontWeight.w500)),
    const SizedBox(width: 8),
  ]),
);
}

Widget _operatorFieldPanel() {
return _ofPanel(
  title: 'Поле / тактическая карта',
  subtitle: widget.selectedField?.title ?? 'Поле не выбрано',
  actions: [
    _layerButton('Trace', _showTrace, () => setState(() => _showTrace = !_showTrace)),
    _layerButton('Heat', _showHeatmap, () => setState(() => _showHeatmap = !_showHeatmap)),
    _layerButton('Tag', _showLabels, () => setState(() => _showLabels = !_showLabels)),
    if (!_renderingFloatingLiveContent)
      _livePanelWindowButton(
        tooltip: 'Открыть поле отдельным окном',
        onTap: () => _openExpandedLiveBlock('Поле / тактическая карта', Icons.map_rounded, () => _fieldCard()),
      ),
  ],
  child: _fieldCard(),
);
}

Widget _layerButton(String label, bool active, VoidCallback onTap) {
return Padding(
  padding: const EdgeInsets.only(left: 4),
  child: InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(color: active ? _OF.greenSoft : Colors.white, border: Border.all(color: active ? _OF.greenBorder : _OF.line), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: active ? _OF.green : _OF.text, fontSize: 9, fontWeight: FontWeight.w600)),
    ),
  ),
);
}

Widget _livePanelWindowButton({required String tooltip, required VoidCallback onTap}) {
return Padding(
  padding: const EdgeInsets.only(left: 6),
  child: Tooltip(
    message: tooltip,
    waitDuration: const Duration(milliseconds: 350),
    child: Material(
      color: const Color(0xFFF4F6F8),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _OF.lineStrong.withOpacity(.85)),
          ),
          child: const Icon(Icons.open_in_full_rounded, size: 15, color: Color(0xFF8B95A3)),
        ),
      ),
    ),
  ),
);
}

Widget _wholeTeamTablePanel({bool compact = false}) {
final rows = _sessions.isNotEmpty ? _sessions : <TrackerLiveSessionModel>[];
return _ofPanel(
  title: 'Командная таблица',
  subtitle: _running ? 'Live' : 'Готово',
  actions: _renderingFloatingLiveContent ? const [] : [
    _livePanelWindowButton(
      tooltip: 'Открыть таблицу отдельным окном',
      onTap: () => _openExpandedLiveBlock('Командная таблица', Icons.table_chart_rounded, () => _wholeTeamTablePanel(compact: false)),
    ),
  ],
  child: Column(children: [
    _teamTableHeader(compact: compact),
    Expanded(
      child: rows.isEmpty ? _teamTableFallback(compact: compact) : ListView.builder(
        itemCount: rows.length,
        itemBuilder: (_, i) => _teamTableRowFromSession(rows[i], i, compact: compact),
      ),
    ),
  ]),
);
}

Widget _teamTableHeader({required bool compact}) {
final cells = compact
    ? const ['№', 'ИГРОК', 'ДИСТ.', 'М/МИН', 'MAX']
    : const ['№', 'ИГРОК', 'ДИСТ.', 'М/МИН', 'MAX', 'HIR', 'VHIR', 'SPR', 'ACC', 'DEC', 'COD'];
return Container(
  height: 32,
  color: _OF.header,
  child: Row(children: cells.map((c) => Expanded(flex: c == 'ИГРОК' ? 3 : 1, child: Center(child: Text(c, style: const TextStyle(color: _OF.text, fontSize: 10, fontWeight: FontWeight.w500))))).toList()),
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
      compact: compact,
      highlight: widget.selectedPlayer?.id == p.id,
    );
  },
);
}

Widget _teamTableRowFromSession(TrackerLiveSessionModel s, int i, {required bool compact}) {
final local = _localTrackForPlayer(s.playerId);
return _teamTableRow(
  number: '${i + 1}',
  name: s.playerName ?? 'Игрок ${s.playerId ?? ''}',
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
  compact: compact,
  highlight: widget.selectedPlayer?.id == s.playerId,
);
}

Widget _teamTableRow({required String number, required String name, required double distance, required double metersPerMin, required double load, required double max, required double hir, required double vhir, required double sprint, required num accel, required num decel, required num cod, required bool compact, required bool highlight}) {
final values = compact
    ? <String>[number, name, distance.toStringAsFixed(0), metersPerMin.toStringAsFixed(1), max.toStringAsFixed(1)]
    : <String>[number, name, distance.toStringAsFixed(0), metersPerMin.toStringAsFixed(1), max.toStringAsFixed(1), hir.toStringAsFixed(0), vhir.toStringAsFixed(0), sprint.toStringAsFixed(0), accel.toStringAsFixed(0), decel.toStringAsFixed(0), cod.toStringAsFixed(0)];
return Container(
  height: 34,
  color: highlight ? const Color(0xFFFFE7D1) : Colors.white,
  child: Row(children: [
    for (var i = 0; i < values.length; i++)
      Expanded(
        flex: i == 1 ? 3 : 1,
        child: Container(
          alignment: i == 1 ? Alignment.centerLeft : Alignment.center,
          padding: EdgeInsets.only(left: i == 1 ? 8 : 0),
          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _OF.line), right: BorderSide(color: _OF.line))),
          child: Text(values[i], maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _OF.text, fontSize: 10, fontWeight: FontWeight.w500)),
        ),
      ),
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
      const SizedBox(height: 8),
      _debugLiveChainPanel(),
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
  _ofVerticalDivider(),
  Expanded(flex: 2, child: _debugLiveChainPanel()),
]);
}

Widget _pipGroupPanel(int online, int active) {
final ids = widget.players.take(12).map((p) => '${p.number ?? p.id}').toList();
return _miniOfCard('Группа PIP', 'Group ($active)', Wrap(spacing: 5, runSpacing: 5, children: ids.isEmpty ? [const Text('Нет игроков', style: TextStyle(color: _OF.muted, fontWeight: FontWeight.w500))] : ids.map((id) => Container(
  width: 42,
  height: 26,
  alignment: Alignment.center,
  decoration: BoxDecoration(color: _OF.pip, border: Border.all(color: _OF.green.withOpacity(.28)), borderRadius: BorderRadius.circular(4)),
  child: Text(id, style: const TextStyle(color: _OF.text, fontSize: 10.6, fontWeight: FontWeight.w500)),
)).toList()));
}

Widget _selectedAthletePanel() {
return _miniOfCard('Выбран игрок', widget.selectedPlayer?.name ?? 'не выбран', Row(children: [
  CircleAvatar(radius: 18, backgroundColor: _OF.green, child: Text(_playerInitials(widget.selectedPlayer?.name ?? 'И'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500))),
  const SizedBox(width: 8),
  Expanded(child: Text(widget.selectedPlayer?.name ?? 'Выберите игрока слева', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _OF.text, fontSize: 10.6, fontWeight: FontWeight.w500))),
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
    SizedBox(width: 42, child: Text(label, style: const TextStyle(color: _OF.text, fontSize: 10, fontWeight: FontWeight.w500))),
    Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(2), child: LinearProgressIndicator(value: (value / max).clamp(0, 1), minHeight: 8, backgroundColor: _OF.line, valueColor: AlwaysStoppedAnimation<Color>(color)))),
    const SizedBox(width: 8),
    SizedBox(width: 42, child: Text('${value.toStringAsFixed(0)} м', textAlign: TextAlign.right, style: const TextStyle(color: _OF.text, fontSize: 9, fontWeight: FontWeight.w500))),
  ]),
);
}

Widget _trackerDevicePanel() {
final device = widget.ble.connectedInfo;
return _miniOfCard('Трекер', device?.name ?? 'Не подключён', Row(children: [
  Container(
    width: 72,
    height: 60,
    decoration: BoxDecoration(color: _OF.black, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.black12)),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.asset('assets/images/sportoteka_tracker_kit.png', fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.sensors_rounded, color: Colors.white, size: 30)),
    ),
  ),
  const SizedBox(width: 10),
  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
    Text(device == null ? 'SPORTOTEKA GPS PRO' : device.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _OF.text, fontSize: 10.6, fontWeight: FontWeight.w500)),
    const SizedBox(height: 3),
    Row(children: [_ofStatusDot(device == null ? _OF.red : _OF.green), const SizedBox(width: 5), Text(device == null ? 'Офлайн' : 'Подключён', style: const TextStyle(color: _OF.text, fontSize: 10, fontWeight: FontWeight.w500))]),
    const SizedBox(height: 5),
    SizedBox(
      height: 28,
      child: OutlinedButton.icon(
        onPressed: widget.scanningBluetooth
            ? null
            : (device == null ? (widget.onScanBluetooth ?? widget.onManageTrackers) : widget.onManageTrackers),
        icon: widget.scanningBluetooth
            ? const SizedBox(width: 13, height: 13, child: CircularProgressIndicator(strokeWidth: 2))
            : Icon(device == null ? Icons.bluetooth_searching_rounded : Icons.sensors_rounded, size: 14),
        label: Text(widget.scanningBluetooth ? 'Поиск...' : (device == null ? 'Поиск Bluetooth' : 'Сменить')),
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
    borderRadius: BorderRadius.circular(10),
  ),
  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _OF.text, fontSize: 11.4, fontWeight: FontWeight.w700))),
      Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _OF.muted2, fontSize: 9.2, fontWeight: FontWeight.w600)),
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
        if (subtitle.isNotEmpty) Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _OF.muted2, fontSize: 9.4, fontWeight: FontWeight.w600)),
        ...actions,
      ]),
    ),
    Expanded(child: child),
  ]),
);
}


Widget _debugLiveChainPanel() {
return _miniOfCard(
  'Debug Live',
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
          label: const Text('Полный debug', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
        ),
      ),
      const SizedBox(height: 6),
      _DebugLine(label: 'LOCAL', value: _lastLocalMetrics),
      _DebugLine(label: 'GPS', value: _lastZeroReason),
      if (_running) _DebugLine(label: 'STATE', value: _lastLiveState),
    ],
  ),
);
}

_RuntimeTrack? _localTrackForPlayer(int? playerId) {
if (playerId == null) return null;
if (widget.selectedPlayer?.id == playerId) return _mainTrack;
return null;
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
if (track.speedKmh < 14.4) return 'скорость ${track.speedKmh.toStringAsFixed(1)} км/ч ниже HIR 14.4';
if (track.speedKmh < 19.8) return 'должен расти HIR, VHIR/SPR ещё нет';
if (track.speedKmh < 25.2) return 'должен расти VHIR, SPR ещё нет';
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
  'running=$_running starting=$_starting saving_point=$_savingPoint mode=${_mode.name}',
  'field_id=${field?.id} field_title=${field?.title} calibrated=${field?.hasCalibration}',
  'device_id=${device?.id} device_name=${device?.name} scanning=${widget.scanningBluetooth} battery=${widget.batteryPercent}',
  '',
  'LOCAL=$_lastLocalMetrics',
  'ZERO=$_lastZeroReason',
  'PAYLOAD=$_lastPayload',
  'SERVER=$_lastServer',
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
_toast('Debug скопирован. Можно прислать сюда текст из буфера.');
}

Future<void> _openFullDebugDialog() async {
if (!mounted) return;
await showDialog<void>(
  context: context,
  builder: (context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.all(18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980, maxHeight: 760),
        child: Column(
          children: [
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: const BoxDecoration(
                color: _OF.header,
                border: Border(bottom: BorderSide(color: _OF.line)),
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(color: _OF.graphite.withOpacity(.09), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.bug_report_rounded, color: _OF.graphite, size: 18),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Полный Debug Live', style: TextStyle(color: _OF.text, fontSize: 14, fontWeight: FontWeight.w600)),
                        Text('Реальные данные: BLE → GPS → LOCAL → PAYLOAD → SERVER → STATE → STOP', style: TextStyle(color: _OF.muted, fontSize: 10.5, fontWeight: FontWeight.w500)),
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
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _FullDebugLine(label: 'LOCAL', value: _lastLocalMetrics),
                    _FullDebugLine(label: 'ZERO?', value: _lastZeroReason),
                    _FullDebugLine(label: 'PAYLOAD', value: _lastPayload),
                    _FullDebugLine(label: 'SERVER', value: _lastServer),
                    _FullDebugLine(label: 'STATE', value: _lastLiveState),
                    _FullDebugLine(label: 'SAVE', value: _lastSave),
                    _FullDebugLine(label: 'STOP', value: _lastStop),
                    _FullDebugLine(label: 'PROBLEM', value: _lastProblem),
                    const SizedBox(height: 10),
                    _FullDebugLine(label: 'TX', value: _lastTx),
                    _FullDebugLine(label: 'RX', value: _lastRx),
                    _FullDebugLine(label: 'GPS', value: _lastGps),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFF0B0F14), borderRadius: BorderRadius.circular(12)),
                      child: SelectableText(
                        _debugDumpText(),
                        style: const TextStyle(color: Colors.white70, fontSize: 10.6, height: 1.35, fontFamily: 'monospace'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFED7AA))),
                      child: const Text(
                        'Важно: кнопки тестовых точек ниже создают искусственные данные. Для проверки реального трекера не нажимай их — смотри LOCAL/PAYLOAD/SERVER/STATE после движения с подключённым устройством.',
                        style: TextStyle(color: _OF.text, fontSize: 10.6, fontWeight: FontWeight.w500),
                      ),
                    ),
                    const SizedBox(height: 10),
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
return Container(
  height: 28,
  decoration: const BoxDecoration(color: Colors.white),
  padding: const EdgeInsets.symmetric(horizontal: 10),
  child: Row(children: [
    _ofStatusDot(_running ? _OF.green : _OF.red),
    const SizedBox(width: 6),
    Text(_running ? 'LIVE' : 'READY', style: TextStyle(color: _running ? _OF.green : _OF.text, fontSize: 9.4, fontWeight: FontWeight.w700)),
    const SizedBox(width: 12),
    Text('Время ${_durationText()}', style: const TextStyle(color: _OF.muted, fontSize: 9.3, fontWeight: FontWeight.w600)),
    const SizedBox(width: 12),
    Text('Игроки $online/$active', style: const TextStyle(color: _OF.muted, fontSize: 9.3, fontWeight: FontWeight.w600)),
    const SizedBox(width: 12),
    Text('Дистанция ${(_displayDistanceM / 1000).toStringAsFixed(2)} км', style: const TextStyle(color: _OF.muted, fontSize: 9.3, fontWeight: FontWeight.w600)),
    const SizedBox(width: 12),
    Text('Макс. ${(_mainTrack?.maxSpeedKmh ?? 0).toStringAsFixed(1)}', style: const TextStyle(color: _OF.muted, fontSize: 9.3, fontWeight: FontWeight.w600)),
    const SizedBox(width: 12),
    Text(_lastGpsAt == null ? 'GPS нет' : 'GPS ${DateTime.now().difference(_lastGpsAt!).inSeconds}с', style: const TextStyle(color: _OF.muted, fontSize: 9.3, fontWeight: FontWeight.w600)),
    const SizedBox(width: 12),
    SizedBox(
      height: 24,
      child: TextButton.icon(
        onPressed: _openFullDebugDialog,
        style: TextButton.styleFrom(
          foregroundColor: _OF.graphite,
          backgroundColor: _OF.header,
          padding: const EdgeInsets.symmetric(horizontal: 7),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: const Icon(Icons.bug_report_rounded, size: 12),
        label: const Text('DEBUG', style: TextStyle(fontSize: 9.4, fontWeight: FontWeight.w700)),
      ),
    ),
    const SizedBox(width: 6),
    SizedBox(
      height: 24,
      child: TextButton.icon(
        onPressed: () => _openExpandedLiveBlock('Оператор / трекер / debug', Icons.tune_rounded, () => _tabletBottomInfoPanel(online, active)),
        style: TextButton.styleFrom(
          foregroundColor: _OF.graphite,
          backgroundColor: _OF.header,
          padding: const EdgeInsets.symmetric(horizontal: 7),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: const Icon(Icons.tune_rounded, size: 12),
        label: const Text('ОПЕРАТОР', style: TextStyle(fontSize: 9.2, fontWeight: FontWeight.w700)),
      ),
    ),
    const Spacer(),
    Text(_lastProblem, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _OF.muted2, fontSize: 9.3, fontWeight: FontWeight.w600)),
  ]),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: const Text('Добавить период', style: TextStyle(fontWeight: FontWeight.w500)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Период попадёт в таймлайн и будет использоваться в отчётах по сессии.',
            style: TextStyle(color: _OF.muted, fontWeight: FontWeight.w500, height: 1.3),
          ),
          const SizedBox(height: 12),
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
          const SizedBox(height: 12),
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

Widget _mobilePanel({
required String title,
required IconData icon,
required Widget Function() builder,
double? height,
}) {
final content = _expandableLiveBlock(
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
  child: InkWell(
    onTap: () => setState(() => _floatingLiveMinimized = false),
    borderRadius: BorderRadius.circular(14),
    child: Container(
      height: 38,
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 340),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.96),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _OF.line),
        boxShadow: const [BoxShadow(color: Color(0x16000000), blurRadius: 20, offset: Offset(0, 10))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_floatingLiveIcon, color: _OF.muted2, size: 16),
          const SizedBox(width: 8),
          Flexible(child: Text(_floatingLiveTitle ?? 'Окно', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _OF.text, fontSize: 11.2, fontWeight: FontWeight.w700))),
          const SizedBox(width: 8),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Закрыть окно',
            onPressed: _closeFloatingLiveWindow,
            icon: const Icon(Icons.close_rounded, size: 16, color: _OF.muted),
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
    final compact = c.maxWidth < 760;
    final margin = compact ? 8.0 : 14.0;
    final windowWidth = _floatingLiveMaximized
        ? c.maxWidth - margin * 2
        : math.min(c.maxWidth - margin * 2, compact ? c.maxWidth - margin * 2 : 980.0);
    final windowHeight = _floatingLiveMaximized
        ? c.maxHeight - margin * 2
        : math.min(c.maxHeight - margin * 2, compact ? c.maxHeight - margin * 2 : 660.0);

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
                borderRadius: BorderRadius.circular(_floatingLiveMaximized ? 18 : 24),
                border: Border.all(color: _OF.lineStrong.withOpacity(.85)),
                boxShadow: const [BoxShadow(color: Color(0x1A344054), blurRadius: 32, spreadRadius: -12, offset: Offset(0, 18))],
              ),
              child: Column(
                children: [
                  MouseRegion(
                    cursor: _floatingLiveMaximized ? SystemMouseCursors.basic : SystemMouseCursors.move,
                    child: GestureDetector(
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
                            const SizedBox(width: 12),
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F5F8),
                                shape: BoxShape.circle,
                                border: Border.all(color: _OF.lineStrong.withOpacity(.75)),
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
return Tooltip(
  message: tooltip,
  child: Material(
    color: const Color(0xFFF4F6F8),
    shape: const CircleBorder(),
    child: InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: _OF.lineStrong.withOpacity(.8)),
        ),
        child: Icon(icon, size: 13, color: const Color(0xFF8B95A3)),
      ),
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
    _debugCard(height: 350),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: _ProblemBox(text: _lastProblem),
    ),
  ],
);
}

Widget _rightPitchColumn() {
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
        padding: const EdgeInsets.symmetric(horizontal: 12),
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
                border: Border.all(color: _C.green.withOpacity(.14)),
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
                      fontFamily: 'Roboto',
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
                      fontFamily: 'Roboto',
                      color: _C.subtle,
                      fontSize: 9.8,
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
      const _TitleRow(
        icon: Icons.layers_rounded,
        title: 'Слои поля',
        subtitle: 'быстрое включение данных',
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
final fieldReady = widget.selectedField?.hasCalibration == true;

return _LiveCard(
  padding: const EdgeInsets.all(14),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _TitleRow(
        icon: Icons.radio_button_checked_rounded,
        title: 'Live трекера',
        subtitle: '${widget.teamName} · онлайн-координаты и нагрузка',
      ),
      const SizedBox(height: 12),
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
            icon: Icons.map_rounded,
            label: fieldReady ? widget.selectedField!.title : 'Поле не готово',
            ok: fieldReady,
          ),
        ],
      ),
      const SizedBox(height: 10),
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
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: _starting || _running ? null : _startLive,
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
              label: const Text('Старт Live'),
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
      const SizedBox(height: 5),
      OutlinedButton.icon(
        onPressed: _running || _testingCommands ? null : _testGpsCommands,
        style: OutlinedButton.styleFrom(
          foregroundColor: _C.green,
          side: const BorderSide(color: _C.green),
          minimumSize: const Size(double.infinity, 42),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: _testingCommands
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.bug_report_rounded),
        label: Text(_testingCommands ? 'Проверка команд...' : 'Debug: проверить команды GPS'),
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: _addDebugLocalPoint,
        style: OutlinedButton.styleFrom(
          foregroundColor: _C.orange,
          side: const BorderSide(color: _C.orange),
          minimumSize: const Size(double.infinity, 42),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: const Icon(Icons.playlist_add_rounded),
        label: const Text('Debug: добавить тестовую точку'),
      ),
      const SizedBox(height: 12),
      _ProblemBox(text: _lastProblem),
    ],
  ),
);
}

Widget _fieldCard() {
return _LiveCard(
  padding: EdgeInsets.zero,
  child: ClipRRect(
    borderRadius: BorderRadius.circular(8),
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

Widget _kpiGrid({required int columns}) {
final track = _mainTrack;
final lastDelta = track?.lastDeltaM ?? 0;

final items = [
  _KpiData('Скорость', '${_displaySpeedKmh.toStringAsFixed(1)} км/ч', Icons.speed_rounded),
  _KpiData('Темп', '${track?.metersPerMinute.toStringAsFixed(0) ?? '0'} м/мин', Icons.timer_rounded),
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
  padding: const EdgeInsets.all(12),
  child: track == null || track.points.length < 2
      ? Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _TitleRow(
              icon: Icons.analytics_rounded,
              title: 'Расширенная аналитика',
              subtitle: 'нагрузка, HIR/VHIR, метаболика',
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Text(
                    'Нет live-данных. Запустите трекер или добавьте тестовую точку в Debug.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _C.subtle,
                      fontFamily: 'Roboto',
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
      const SizedBox(height: 12),
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
              title: 'Debug на устройстве',
              subtitle: 'Показывает, где именно ломается цепочка',
            ),
          ),
          Material(
            color: const Color(0xFFF4F6F8),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
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
      _DebugLine(label: 'SAVE', value: _lastSave),
      _DebugLine(
        label: 'GPS age',
        value: _lastGpsAt == null
            ? 'нет'
            : '${DateTime.now().difference(_lastGpsAt!).inSeconds} сек назад',
      ),
      _DebugLine(
        label: 'Save age',
        value: _lastSaveAt == null
            ? 'нет'
            : '${DateTime.now().difference(_lastSaveAt!).inSeconds} сек назад',
      ),
      const SizedBox(height: 5),
      if (_showDebug)
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0B0F14),
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
                          color: Color(0xFFE5E7EB),
                          fontSize: 10.8,
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


class _LiveExpandButton extends StatefulWidget {
const _LiveExpandButton({
required this.tooltip,
required this.onTap,
});

final String tooltip;
final VoidCallback onTap;

@override
State<_LiveExpandButton> createState() => _LiveExpandButtonState();
}

class _LiveExpandButtonState extends State<_LiveExpandButton> {
bool _pressed = false;

@override
Widget build(BuildContext context) {
return Tooltip(
  message: widget.tooltip,
  child: Listener(
    onPointerDown: (_) => setState(() => _pressed = true),
    onPointerUp: (_) => setState(() => _pressed = false),
    onPointerCancel: (_) => setState(() => _pressed = false),
    child: AnimatedScale(
      scale: _pressed ? .94 : 1,
      duration: const Duration(milliseconds: 100),
      child: Material(
        color: const Color(0xFFF4F6F8),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: widget.onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _OF.lineStrong.withOpacity(.85)),
            ),
            child: const Icon(Icons.open_in_full_rounded, color: Color(0xFF8B95A3), size: 15),
          ),
        ),
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
  .where((p) => p.speedKmh >= 19.8 && p.speedKmh < 25.2)
  .fold<double>(0, (sum, p) => sum + p.distanceDeltaM);

double get sprintDistanceM => points
  .where((p) => p.speedKmh >= 25.2)
  .fold<double>(0, (sum, p) => sum + p.distanceDeltaM);

int get accelCount {
var count = 0;
for (var i = 1; i < points.length; i++) {
  final dt = math.max(.75, (points[i].timeMs - points[i - 1].timeMs) / 1000.0);
  final acc = ((points[i].speedKmh - points[i - 1].speedKmh) / 3.6) / dt;
  if (acc >= 2.0) count++;
}
return count;
}

int get decelCount {
var count = 0;
for (var i = 1; i < points.length; i++) {
  final dt = math.max(.75, (points[i].timeMs - points[i - 1].timeMs) / 1000.0);
  final acc = ((points[i].speedKmh - points[i - 1].speedKmh) / 3.6) / dt;
  if (acc <= -2.0) count++;
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

String get playerLoadSourceLabel => 'GPS-load / IMU позже';

double get hirDistanceM => points
  .where((p) => p.speedKmh >= 14.4 && p.speedKmh < 19.8)
  .fold<double>(0, (sum, p) => sum + p.distanceDeltaM);

double get vhirDistanceM => points
  .where((p) => p.speedKmh >= 19.8 && p.speedKmh < 25.2)
  .fold<double>(0, (sum, p) => sum + p.distanceDeltaM);

int get highIntensityBurstCount {
var count = 0;
for (var i = 1; i < points.length; i++) {
  if (points[i].speedKmh >= 14.4 && points[i - 1].speedKmh < 14.4) count++;
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
});

final TrackerFieldModel? field;
final List<_RuntimeTrack> tracks;
final bool showVectors;
final bool showHeatmap;
final bool showTrace;
final bool showLabels;

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
  ..color = const Color(0xFFE5E7EB).withOpacity(.34)
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

if (field?.hasCalibration == true) {
  latValues.addAll([
    field!.cornerALat!,
    field!.cornerBLat!,
    field!.cornerCLat!,
    field!.cornerDLat!,
  ]);
  lonValues.addAll([
    field!.cornerALng!,
    field!.cornerBLng!,
    field!.cornerCLng!,
    field!.cornerDLng!,
  ]);
}

for (final p in allPoints) {
  latValues.add(p.lat);
  lonValues.add(p.lon);
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
      : p.speedKmh >= 19.8
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
    ..color = Colors.black.withOpacity(.16)
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
    : track.speedKmh >= 19.8
        ? _C.orange
        : _C.greenLight;

canvas.drawCircle(
  pos,
  15,
  Paint()
    ..color = color.withOpacity(.16)
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
      fontSize: 9.2,
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
    ..color = Colors.white.withOpacity(.14),
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
      fontSize: 10,
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
    shape: BoxShape.circle,
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
  padding: const EdgeInsets.all(12),
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
  padding: const EdgeInsets.all(12),
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
      Text(session.isOnline ? 'SERVER' : 'OFF', style: TextStyle(color: color, fontWeight: FontWeight.w500, fontSize: 11)),
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
    border: Border.all(color: color.withOpacity(.18)),
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
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: _C.divider, width: 1),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.025),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ],
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
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: accent.withOpacity(.12)),
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
                fontFamily: 'Roboto',
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
                fontFamily: 'Roboto',
                fontSize: 10.5,
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
            fontFamily: 'Roboto',
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
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _C.subtle, fontSize: 10.4, fontWeight: FontWeight.w500, letterSpacing: .05)),
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _C.text, fontSize: 15, fontWeight: FontWeight.w500, letterSpacing: -.15, fontFeatures: [FontFeature.tabularFigures()])),
            Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _C.muted, fontSize: 9.2, fontWeight: FontWeight.w500)),
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
          style: TextStyle(color: _C.subtle, fontSize: 9.5, fontWeight: FontWeight.w500),
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
final jog = track.points.where((p) => p.speedKmh >= 7 && p.speedKmh < 14.4).fold<double>(0, (s, p) => s + p.distanceDeltaM);
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
      SizedBox(width: 54, child: Text(label, style: const TextStyle(color: _C.muted, fontSize: 9.5, fontWeight: FontWeight.w500))),
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
      const SizedBox(width: 7),
      SizedBox(width: 42, child: Text('${value.toStringAsFixed(0)}м', textAlign: TextAlign.right, style: const TextStyle(color: _C.text, fontSize: 9.5, fontWeight: FontWeight.w500))),
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
              fontFamily: 'Roboto',
              fontSize: 11.4,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.15,
            ),
          ),
          const SizedBox(height: 8),
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
    borderRadius: BorderRadius.circular(10),
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
            fontFamily: 'Roboto',
            fontSize: 10.2,
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
          fontFamily: 'Roboto',
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
            style: const TextStyle(color: _C.greenDark, fontSize: 10, fontWeight: FontWeight.w500, height: 1.25),
          ),
        ),
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
return InkWell(
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
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            color: active ? _C.greenDark : _C.muted,
            fontSize: 10,
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
      Text(label, style: const TextStyle(color: _C.subtle, fontSize: 8, fontWeight: FontWeight.w500)),
      const SizedBox(width: 4),
      Text(value, style: const TextStyle(color: _C.text, fontSize: 9.4, fontWeight: FontWeight.w500)),
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
final maxSpeed = math.max(8.0, src.map((p) => p.speedKmh).fold<double>(0, math.max));
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
    return DateTime.tryParse(s.replaceFirst(' ', 'T'));
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
    if (p.speedKmh >= 25.2) {
      color = _OF.red;
      radius = 3.4;
    } else if (p.speedKmh >= 19.8) {
      color = _OF.cyan;
      radius = 3.0;
    } else if (p.speedKmh >= 14.4) {
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
      canvas.drawCircle(Offset(x, baselineY), radius + 2, Paint()..color = color.withOpacity(.12));
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

class _OF {
static const Color black = Color(0xFF344054);
static const Color bg = Color(0xFFF6F7F9);
static const Color header = Color(0xFFFAFBFC);
static const Color line = Color(0xFFF0F2F4);
static const Color lineStrong = Color(0xFFE5E7EB);
static const Color glass = Color(0xF8FFFFFF);
static const Color text = Color(0xFF0B0F14);
static const Color muted = Color(0xFF374151);
static const Color muted2 = Color(0xFF6B7280);
static const Color graphite = Color(0xFF344054);
static const Color orange = Color(0xFFF59E0B);
static const Color green = Color(0xFF00A750);
static const Color greenSoft = Color(0xFFF3FBF7);
static const Color greenBorder = Color(0xFFDCEFE5);
static const Color pip = Color(0xFFF8FEFA);
static const Color cyan = Color(0xFF06B6D4);
static const Color cyanSoft = Color(0xFFEFFBFF);
static const Color blue = Color(0xFF2563EB);
static const Color blueSoft = Color(0xFFF4F7FF);
static const Color red = Color(0xFFDC2626);
static const Color redSoft = Color(0xFFFEF2F2);

static List<BoxShadow> get windowShadow => [
  BoxShadow(
    color: Colors.black.withOpacity(.055),
    blurRadius: 38,
    spreadRadius: -18,
    offset: const Offset(0, 22),
  ),
  BoxShadow(
    color: blue.withOpacity(.035),
    blurRadius: 24,
    spreadRadius: -18,
    offset: const Offset(0, 10),
  ),
];

static BoxDecoration unifiedWindow({double radius = 20}) => BoxDecoration(
  color: glass,
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: Colors.white.withOpacity(.86), width: 1),
  boxShadow: windowShadow,
);
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
  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
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
          border: Border.all(color: _C.green.withOpacity(.12)),
        ),
        child: Icon(data.icon, color: _C.green, size: 15),
      ),
      const SizedBox(width: 7),
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
                fontSize: 9.4,
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
      SizedBox(width: 72, child: Text(label, style: const TextStyle(color: _C.subtle, fontSize: 10.6, fontWeight: FontWeight.w500))),
      Expanded(
        child: Text(
          value,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: _C.text, fontSize: 10.4, fontWeight: FontWeight.w500, fontFamily: 'monospace'),
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
  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  decoration: BoxDecoration(color: _C.soft, borderRadius: BorderRadius.circular(10), border: Border.all(color: _C.divider)),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(width: 82, child: Text(label, style: const TextStyle(color: _C.subtle, fontSize: 10.6, fontWeight: FontWeight.w600))),
      Expanded(
        child: SelectableText(
          value,
          style: const TextStyle(color: _C.text, fontSize: 10.6, fontWeight: FontWeight.w500, fontFamily: 'monospace', height: 1.25),
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
  padding: const EdgeInsets.all(12),
  decoration: BoxDecoration(
    color: isBad ? _C.redSoft : Colors.white,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: isBad ? _C.red.withOpacity(.18) : _C.divider),
  ),
  child: Row(
    children: [
      Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: isBad ? _C.redSoft : _C.greenSoft,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(.12)),
        ),
        child: Icon(isBad ? Icons.warning_amber_rounded : Icons.check_rounded, color: color, size: 18),
      ),
      const SizedBox(width: 10),
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
    borderRadius: BorderRadius.circular(12),
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
      const SizedBox(width: 7),
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
        borderRadius: BorderRadius.circular(10),
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
              fontFamily: 'Roboto',
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
                fontFamily: 'Roboto',
                fontSize: 10.6,
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
static const Color bg = Color(0xFFF5F6F7);
static const Color panel = Color(0xFFFFFFFF);
static const Color soft = Color(0xFFF8F9FA);
static const Color soft2 = Color(0xFFF1F3F5);
static const Color text = Color(0xFF0B0F14);
static const Color muted = Color(0xFF374151);
static const Color subtle = Color(0xFF6B7280);
static const Color divider = Color(0xFFE5E7EB);

// CMR-акцент: приглушённый зелёный только для статусов и точек.
static const Color green = Color(0xFF067A46);
static const Color greenLight = Color(0xFF2F6B4F);
static const Color greenSoft = Color(0xFFF6FCF8);
static const Color greenSoft2 = Color(0xFFFAFFFC);
static const Color greenDark = Color(0xFF065F46);

static const Color orange = Color(0xFFB45309);
static const Color orangeSoft = Color(0xFFFFF7ED);
static const Color red = Color(0xFFDC2626);
static const Color redSoft = Color(0xFFFEF2F2);
}
