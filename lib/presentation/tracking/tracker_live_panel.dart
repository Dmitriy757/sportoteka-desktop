
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'models/action_tracker_protocol.dart';
import 'models/tracker_live_models.dart';
import 'models/tracker_pro_models.dart';
import 'services/action_tracker_ble_service.dart';
import 'services/tracker_live_api.dart';
import 'services/tracker_pro_api.dart';

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
  final VoidCallback? onManageTrackers;
  final ValueChanged<bool>? onLiveRunningChanged;

  @override
  State<TrackerLivePanel> createState() => _TrackerLivePanelState();
}

class _TrackerLivePanelState extends State<TrackerLivePanel>
    with AutomaticKeepAliveClientMixin {
  final TrackerLiveApi _api = TrackerLiveApi();
  final TrackerProApi _sessionApi = TrackerProApi();

  final List<String> _logs = <String>[];
  final Map<String, _RuntimeTrack> _tracks = <String, _RuntimeTrack>{};
  List<TrackerLiveSessionModel> _sessions = <TrackerLiveSessionModel>[];

  Timer? _pollTimer;
  Timer? _phoneTimer;
  Timer? _trackerTimer;
  Timer? _heartbeatTimer;
  StreamSubscription<ActionTrackerParseResult>? _bleSub;

  int? _myLiveSessionId;
  int? _trackerSessionId;
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

  String _lastRx = 'нет пакетов';
  String _lastTx = 'нет команд';
  String _lastGps = 'нет GPS';
  String _lastSave = 'нет сохранения';
  String _lastProblem = 'Ожидание старта онлайна';
  DateTime? _lastGpsAt;
  DateTime? _lastSaveAt;

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
        _trackerSessionId = null;
        _lastProblem = 'Команда изменена: ${widget.teamName}';
        _lastRx = 'нет пакетов';
        _lastTx = 'нет команд';
        _lastGps = 'нет GPS';
        _lastSave = 'нет сохранения';
      });

      _loadLiveState();
      _log('Команда онлайна изменена: ${widget.teamName} (${widget.teamId})');
      return;
    }

    if (oldWidget.selectedField?.id != widget.selectedField?.id) {
      _loadLiveState();
      _log('Изменено поле: ${widget.selectedField?.title ?? 'нет поля'}');
    }

    if (oldWidget.selectedPlayer?.id != widget.selectedPlayer?.id) {
      _log('Изменён игрок онлайна: ${widget.selectedPlayer?.name ?? 'не выбран'}');
      if (!_running) setState(() {});
    }
  }

  void _setLiveRunning(bool value) {
    if (_running == value) return;
    _running = value;
    widget.onLiveRunningChanged?.call(value);
  }

  void _listenBle() {
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
    _log('Онлайн открыт. Команда GPS трекера: 3A → ответ 3B/44.');
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
      setState(() => _sessions = data);
    } catch (e) {
      _lastProblem = 'Ошибка загрузки онлайна: $e';
      _log(_lastProblem);
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
      _toast('Сначала подключите BLE-трекер во вкладке «Подключение»');
      _lastProblem = 'Трекер не подключён';
      setState(() {});
      return;
    }

    final deviceUuid = _mode == TrackerLiveSourceMode.phoneGps
        ? 'PHONE-GPS-${widget.teamId}-${widget.selectedPlayer?.id ?? 0}'
        : device!.id;

    final deviceName = _mode == TrackerLiveSourceMode.phoneGps
        ? 'Телефон GPS'
        : device!.name;

    setState(() {
      _starting = true;
      _lastProblem = 'Старт онлайна...';
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

      try {
        _trackerSessionId = await _sessionApi.createTrackerSession(
          clubId: widget.clubId,
          teamId: widget.teamId,
          fieldId: field.id,
          title: 'Онлайн ${widget.teamName} · ${DateTime.now().toIso8601String().substring(0, 16).replaceFirst('T', ' ')}',
          type: 'training',
          source: _mode == TrackerLiveSourceMode.phoneGps ? 'phone_live' : 'tracker_live',
        );
        _log('Создана сессия отчёта: $_trackerSessionId');
      } catch (e) {
        _trackerSessionId = null;
        _log('Сессия отчёта не создана: $e');
      }

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
      _lastProblem = 'Онлайн активен';

      _trackForCurrentDevice();

      if (_mode == TrackerLiveSourceMode.phoneGps) {
        _startPhoneGpsLoop();
      } else {
        _startTrackerLoop();
      }

      _log('Онлайн стартовал: session=$id');
      _serverLog('Онлайн стартовал: session=$id', source: 'live_start');
      await _loadLiveState();
    } catch (e) {
      _lastProblem = 'Ошибка старта онлайна: $e';
      _log(_lastProblem);
      _toast('Онлайн: $e');
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
          packetType: 'PHONE',
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

    if (stat.distanceDeltaM <= 0.25 && track.points.length > 1) {
      _lastProblem =
          'GPS приходит, но смещение меньше 25 см. Скорость будет около 0.';
    } else if (stat.rawSpeedKmh > 55) {
      _lastProblem =
          'GPS-скачок ${stat.rawSpeedKmh.toStringAsFixed(1)} км/ч. На экране скорость ограничена.';
    } else {
      _lastProblem = 'GPS принят, скорость считается локально';
    }

    if (mounted) setState(() {});

    await _savePoint(
      latitude: latitude,
      longitude: longitude,
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

    setState(() => _savingPoint = true);

    try {
      final result = await _api.saveLivePoint(
        TrackerLivePointPayload(
          liveSessionId: id,
          clubId: widget.clubId,
          teamId: widget.teamId,
          playerId: widget.selectedPlayer?.id,
          deviceUuid: deviceUuid,
          latitude: latitude,
          longitude: longitude,
          timeMs: timeMs,
          batteryPercent: widget.batteryPercent,
        ),
      );

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
      await _savePointToReportSession(
        latitude: latitude,
        longitude: longitude,
        timeMs: timeMs,
        deviceUuid: deviceUuid,
        serverSpeed: double.tryParse('$speed') ?? 0,
        serverDelta: double.tryParse('$delta') ?? 0,
        serverField: field is Map ? Map<String, dynamic>.from(field) : null,
      );
      _log('Точка сохранена: $_lastSave');
      await _serverLog(
        'point saved: $_lastSave · $packetType',
        source: 'save_point',
        rawHex: rawHex,
      );
      await _loadLiveState();
    } catch (e) {
      _lastSave = 'ОШИБКА: $e';
      _lastProblem = 'Сервер не сохранил точку: $e';
      _log('Сохранение точки: $e');
      await _serverLog(
        'save point error: $e',
        level: 'error',
        source: 'save_point',
        rawHex: rawHex,
      );
    } finally {
      if (mounted) setState(() => _savingPoint = false);
    }
  }



  Future<void> _savePointToReportSession({
    required double latitude,
    required double longitude,
    required int timeMs,
    required String deviceUuid,
    required double serverSpeed,
    required double serverDelta,
    Map<String, dynamic>? serverField,
  }) async {
    final sessionId = _trackerSessionId;
    if (sessionId == null) return;
    final track = _trackForCurrentDevice();
    final point = track.points.isEmpty ? null : track.points.last;
    final elapsedSec = track.points.isEmpty ? 0.0 : ((timeMs - track.points.first.timeMs) / 1000.0).clamp(0.0, 999999.0).toDouble();
    double acceleration = 0;
    if (track.points.length >= 2) {
      final prev = track.points[track.points.length - 2];
      final current = track.points.last;
      final dt = math.max(.75, (current.timeMs - prev.timeMs) / 1000.0);
      acceleration = ((current.speedKmh - prev.speedKmh) / 3.6) / dt;
    }
    final speed = point?.speedKmh ?? serverSpeed;
    final delta = point?.distanceDeltaM ?? serverDelta;
    final zone = speed >= 25.2
        ? 'sprint'
        : speed >= 19.8
            ? 'vhir'
            : speed >= 14.4
                ? 'hir'
                : speed >= 3.6
                    ? 'run'
                    : 'walk';
    try {
      await _sessionApi.saveTrackerSessionPoint(
        point: TrackerSessionPointModel(
          id: 0,
          sessionId: sessionId,
          playerId: widget.selectedPlayer?.id,
          deviceUuid: deviceUuid,
          pointTime: DateTime.now(),
          elapsedSec: elapsedSec,
          latitude: latitude,
          longitude: longitude,
          fieldXM: double.tryParse('${serverField?['field_x_m'] ?? serverField?['x_m'] ?? ''}'),
          fieldYM: double.tryParse('${serverField?['field_y_m'] ?? serverField?['y_m'] ?? ''}'),
          speedKmh: speed,
          accelerationMps2: acceleration,
          distanceDeltaM: delta,
          cumulativeDistanceM: track.totalDistanceM,
          intensityZone: zone,
        ),
      );
    } catch (e) {
      _log('Точка отчётной сессии не сохранена: $e');
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
        'device_name': device?.name ?? 'Источник онлайна',
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
        'sprint_distance_m': track.sprintDistanceM,
        'sprint_count': track.sprintCount,
        'accel_count': track.accelCount,
        'decel_count': track.decelCount,
        'work_rest_ratio': track.workRestRatio,
        'recommendation': track.recommendation,
        'analysis_json': track.toJson(),
      });
      _log('Снимок метрик сохранён: нагрузка=${track.loadScore.toStringAsFixed(0)}, усталость=${track.fatigueIndex.toStringAsFixed(0)}%');
      if (manual) _toast('Метрики онлайна сохранены по дате');
    } catch (e) {
      _log('Ошибка снимка метрик: $e');
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
        await _api.stopLiveSession(
          liveSessionId: id,
          createFinalSession: true,
        );
        if (_trackerSessionId != null) {
          try {
            await _sessionApi.finishTrackerSession(sessionId: _trackerSessionId!);
          } catch (e) {
            _log('Отчётная сессия не закрыта: $e');
          }
        }
        _lastProblem = 'Онлайн остановлен и сохранён как сессия';
        _log('Онлайн остановлен: session=$id · report_session=$_trackerSessionId');
      } catch (e) {
        _lastProblem = 'Ошибка остановки онлайна: $e';
        _log(_lastProblem);
      }
    }

    _myLiveSessionId = null;
    _trackerSessionId = null;
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
        ? 'Телефон GPS'
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
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
  @override
  Widget build(BuildContext context) {
    super.build(context);

    final active = _sessions.where((s) => s.status == 'active').toList();
    final online = active.where((s) => s.isOnline).length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        if (width < 720) {
          return _mobileLiveLayout(online, active.length);
        }

        if (width < 1180) {
          return _tabletLiveLayout(online, active.length);
        }

        return _desktopLiveLayout(online, active.length);
      },
    );
  }

  Widget _mobileLiveLayout(int online, int active) {
    return Container(
      color: _C.bg,
      child: ListView(
        padding: const EdgeInsets.all(5),
        children: [
          _mobilePanel(
            title: 'Управление онлайном',
            icon: Icons.tune_rounded,
            builder: () => _statusHeader(online, active),
          ),
          const SizedBox(height: 5),
          _mobilePanel(
            title: 'Поле и движение игрока',
            icon: Icons.map_rounded,
            height: 430,
            builder: _rightPitchCard,
          ),
          const SizedBox(height: 5),
          _mobilePanel(
            title: 'Онлайн обзор KPI',
            icon: Icons.dashboard_rounded,
            height: 104,
            builder: () => _kpiGrid(columns: 3),
          ),
          const SizedBox(height: 5),
          _mobilePanel(
            title: 'Расширенная аналитика',
            icon: Icons.analytics_rounded,
            height: 620,
            builder: () => _proAnalyticsCenter(),
          ),
          const SizedBox(height: 5),
          _mobilePanel(
            title: 'Игроки на поле',
            icon: Icons.groups_rounded,
            height: 320,
            builder: () => _playersCard(),
          ),
          const SizedBox(height: 5),
          _mobilePanel(
            title: 'Диагностика',
            icon: Icons.bug_report_rounded,
            height: 430,
            builder: () => _debugCard(),
          ),
        ],
      ),
    );
  }

  Widget _tabletLiveLayout(int online, int active) {
    return Container(
      color: _C.bg,
      child: ListView(
        padding: const EdgeInsets.all(5),
        children: [
          SizedBox(
            height: 430,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _expandableLiveBlock(
                    title: 'Управление',
                    icon: Icons.tune_rounded,
                    builder: () => _statusHeader(online, active),
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: _expandableLiveBlock(
                    title: 'Поле',
                    icon: Icons.map_rounded,
                    builder: _rightPitchCard,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 5),
          SizedBox(
            height: 590,
            child: _expandableLiveBlock(
              title: 'Аналитика',
              icon: Icons.analytics_rounded,
              builder: () => _proAnalyticsCenter(),
            ),
          ),
          const SizedBox(height: 5),
          SizedBox(
            height: 104,
            child: Row(
              children: [
                Expanded(
                  child: _expandableLiveBlock(
                    title: 'Онлайн обзор KPI',
                    icon: Icons.dashboard_rounded,
                    builder: () => _kpiGrid(columns: 3),
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: _expandableLiveBlock(
                    title: 'Слои поля',
                    icon: Icons.layers_rounded,
                    builder: _fieldLegendCard,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 5),
          SizedBox(
            height: 336,
            child: Row(
              children: [
                Expanded(
                  child: _expandableLiveBlock(
                    title: 'Игроки',
                    icon: Icons.groups_rounded,
                    builder: () => _playersCard(),
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: _expandableLiveBlock(
                    title: 'Диагностика',
                    icon: Icons.bug_report_rounded,
                    builder: () => _debugCard(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopLiveLayout(int online, int active) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final leftW = w >= 1380 ? 360.0 : 320.0;
        final rightW = w >= 1380 ? 650.0 : 560.0;

        return Container(
          color: _C.bg,
          padding: const EdgeInsets.fromLTRB(3, 4, 4, 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: leftW,
                child: _expandableLiveBlock(
                  title: 'Управление и игроки',
                  icon: Icons.tune_rounded,
                  builder: () => _leftLiveColumn(online, active),
                ),
              ),
              const SizedBox(width: 5),
              Expanded(
                flex: 10,
                child: Column(
                  children: [
                    Expanded(
                      child: _expandableLiveBlock(
                        title: 'Расширенная аналитика',
                        icon: Icons.analytics_rounded,
                        builder: _middleAnalyticsColumn,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 5),
              SizedBox(
                width: rightW,
                child: _expandableLiveBlock(
                  title: 'Поле, теплокарта и движение',
                  icon: Icons.map_rounded,
                  builder: _rightPitchColumn,
                ),
              ),
            ],
          ),
        );
      },
    );
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
        if (allowExpand)
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

  Future<void> _openExpandedLiveBlock(
    String title,
    IconData icon,
    Widget Function() builder,
  ) async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(.25),
      builder: (context) {
        final size = MediaQuery.of(context).size;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(
            horizontal: size.width < 720 ? 10 : 28,
            vertical: size.width < 720 ? 14 : 28,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: _C.bg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _C.divider.withOpacity(.82)),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Container(
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: const BoxDecoration(
                    color: _C.soft,
                    border: Border(bottom: BorderSide(color: _C.divider)),
                  ),
                  child: Row(
                    children: [
                      Icon(icon, color: _C.green, size: 21),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _C.text,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -.2,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded, color: _C.text),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(5),
                    child: builder(),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
                          fontSize: 13.2,
                          fontWeight: FontWeight.w900,
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
                          fontWeight: FontWeight.w700,
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
            title: 'Онлайн трекера',
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
          const SizedBox(height: 12),
          SegmentedButton<TrackerLiveSourceMode>(
            style: SegmentedButton.styleFrom(
              backgroundColor: _C.soft,
              foregroundColor: _C.text,
              selectedBackgroundColor: _C.green,
              selectedForegroundColor: _C.bg,
              side: const BorderSide(color: _C.divider),
            ),
            segments: const [
              ButtonSegment(
                value: TrackerLiveSourceMode.phoneGps,
                icon: Icon(Icons.phone_iphone_rounded),
                label: Text('Телефон'),
              ),
              ButtonSegment(
                value: TrackerLiveSourceMode.trackerExperimental,
                icon: Icon(Icons.sensors_rounded),
                label: Text('Трекер'),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: _running
                ? null
                : (v) => setState(() => _mode = v.first),
          ),
          if (_mode == TrackerLiveSourceMode.trackerExperimental) ...[
            const SizedBox(height: 5),
            DropdownButtonFormField<int>(
              value: _candidateCommandIndex,
              decoration: _input('Команда GPS трекера'),
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
                  label: const Text('Старт онлайн'),
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
            label: Text(_testingCommands ? 'Проверка команд...' : 'Диагностика: проверить GPS'),
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
            label: const Text('Диагностика: добавить тестовую точку'),
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

    final items = [
      _KpiData('Скорость', '${_displaySpeedKmh.toStringAsFixed(1)} км/ч', Icons.speed_rounded),
      _KpiData('Темп', '${track?.metersPerMinute.toStringAsFixed(0) ?? '0'} м/мин', Icons.timer_rounded),
      _KpiData('Нагрузка', '${track?.loadScore.toStringAsFixed(0) ?? '0'}', Icons.bolt_rounded),
      _KpiData('Усталость', '${track?.fatigueIndex.toStringAsFixed(0) ?? '0'}%', Icons.battery_alert_rounded),
      _KpiData('HIR/VHIR', '${((track?.hirDistanceM ?? 0) + (track?.vhirDistanceM ?? 0)).toStringAsFixed(0)} м', Icons.local_fire_department_rounded),
      _KpiData('Спринт', '${track?.sprintDistanceM.toStringAsFixed(0) ?? '0'} м', Icons.flash_on_rounded),
      _KpiData('Ускорения', '${track?.accelCount ?? 0}', Icons.keyboard_double_arrow_up_rounded),
      _KpiData('Торможения', '${track?.decelCount ?? 0}', Icons.keyboard_double_arrow_down_rounded),
    ];

    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        height: 96,
        child: _LiveCard(
          padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 2, right: 30, bottom: 6),
                child: _TitleRow(
                  icon: Icons.dashboard_rounded,
                  title: 'Онлайн обзор KPI',
                  subtitle: 'маленькие показатели текущей сессии',
                ),
              ),
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (_, i) => SizedBox(width: 148, child: _KpiCard(data: items[i])),
                ),
              ),
            ],
          ),
        ),
      ),
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
                        'Нет онлайн-данных. Запустите трекер или добавьте тестовую точку в диагностике.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: _C.subtle,
                          fontFamily: 'Roboto',
                          fontSize: 12.8,
                          fontWeight: FontWeight.w700,
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
                          subtitle: 'объём работы за текущую онлайн-сессию',
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
            title: 'Игроки на поле',
            subtitle: 'Локальные данные + серверное состояние',
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _tracks.isEmpty && _sessions.isEmpty
                ? const Center(
                    child: Text(
                      'Запустите онлайн, чтобы увидеть игрока',
                      style: TextStyle(color: _C.subtle, fontWeight: FontWeight.w700),
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
                  title: 'Диагностика устройства',
                  subtitle: 'Показывает, где именно ломается цепочка',
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _showDebug = !_showDebug),
                icon: Icon(_showDebug ? Icons.expand_less_rounded : Icons.expand_more_rounded),
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
                  color: const Color(0xFF0B0F14),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(5),
                child: _logs.isEmpty
                    ? const Center(
                        child: Text(
                          'Логи появятся здесь',
                          style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w700),
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
                              fontWeight: FontWeight.w600,
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
            color: Colors.white.withOpacity(.96),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: _C.divider.withOpacity(.75)),
            ),
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(8),
              child: const SizedBox(
                width: 34,
                height: 34,
                child: Icon(Icons.open_in_full_rounded, color: _C.green, size: 16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RuntimePoint {
  final double lat;
  final double lon;
  final int timeMs;
  final double speedKmh;
  final double rawSpeedKmh;
  final double distanceDeltaM;
  final String packetType;

  const _RuntimePoint({
    required this.lat,
    required this.lon,
    required this.timeMs,
    required this.speedKmh,
    required this.rawSpeedKmh,
    required this.distanceDeltaM,
    required this.packetType,
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
      return 'Высокая доля HIR/спринтов. Следить за восстановлением между сериями.';
    }
    if (accelCount + decelCount >= 10) {
      return 'Много ускорений/торможений. Следить за мышечной нагрузкой.';
    }
    return 'Нагрузка стабильная. Критичного падения скорости нет.';
  }


  double get playerLoadEstimate => loadScore;

  String get playerLoadSourceLabel => 'GPS-нагрузка / ИНС позже';

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
    if (fatigueIndex >= 70) alerts.add('Высокая усталость');
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
    double delta = 0;
    double speed = 0;
    double raw = 0;

    if (points.isNotEmpty) {
      final prev = points.last;
      delta = _haversineM(prev.lat, prev.lon, latitude, longitude);
      final dt = math.max(0.75, (timeMs - prev.timeMs) / 1000.0);
      raw = (delta / dt) * 3.6;
      speed = raw.clamp(0.0, 42.0);

      if (raw <= 55.0) {
        totalDistanceM += delta;
      }

      if (speed >= 20.0 && (points.isEmpty || points.last.speedKmh < 20.0)) {
        sprintCount += 1;
      }
    }

    speedKmh = speed;
    rawSpeedKmh = raw;
    maxSpeedKmh = math.max(maxSpeedKmh, speed);
    lastDeltaM = delta;

    final p = _RuntimePoint(
      lat: latitude,
      lon: longitude,
      timeMs: timeMs,
      speedKmh: speed,
      rawSpeedKmh: raw,
      distanceDeltaM: delta,
      packetType: packetType,
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
          fontWeight: FontWeight.w900,
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
          fontWeight: FontWeight.w900,
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
          fontWeight: FontWeight.w800,
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
          fontWeight: FontWeight.w900,
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
                style: TextStyle(color: _C.green, fontSize: size * .28, fontWeight: FontWeight.w900),
              ),
            )
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Center(
                child: Text(
                  initials,
                  style: TextStyle(color: _C.green, fontSize: size * .28, fontWeight: FontWeight.w900),
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
                Text(track.playerName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _C.text, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(
                  '${track.speedKmh.toStringAsFixed(1)} км/ч · ${(track.totalDistanceM / 1000).toStringAsFixed(2)} км · точек ${track.points.length}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _C.muted, fontSize: 12.2, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          const SizedBox(width: 5),
          Text('ОНЛАЙН', style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 12)),
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
              Text(session.playerName ?? session.deviceName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _C.text, fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text('${session.speedKmh.toStringAsFixed(1)} км/ч · ${(session.totalDistanceM / 1000).toStringAsFixed(2)} км · сервер', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _C.subtle, fontSize: 12.2, fontWeight: FontWeight.w800)),
            ]),
          ),
          Text(session.isOnline ? 'СЕРВЕР' : 'ВЫКЛ', style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 11)),
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
              style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 12, height: 1.25),
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
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
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
                    fontWeight: FontWeight.w600,
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
                fontSize: 16,
                fontWeight: FontWeight.w800,
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
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _C.subtle, fontSize: 10.4, fontWeight: FontWeight.w900, letterSpacing: .05)),
                Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _C.text, fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: -.15, fontFeatures: [FontFeature.tabularFigures()])),
                Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _C.muted, fontSize: 9.2, fontWeight: FontWeight.w800)),
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
              style: TextStyle(color: _C.subtle, fontSize: 9.5, fontWeight: FontWeight.w900),
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
          const Text('Зоны интенсивности', style: TextStyle(color: _C.text, fontWeight: FontWeight.w900, fontSize: 12)),
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
          SizedBox(width: 54, child: Text(label, style: const TextStyle(color: _C.muted, fontSize: 9.5, fontWeight: FontWeight.w800))),
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
          SizedBox(width: 42, child: Text('${value.toStringAsFixed(0)}м', textAlign: TextAlign.right, style: const TextStyle(color: _C.text, fontSize: 9.5, fontWeight: FontWeight.w900))),
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
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
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
                fontWeight: FontWeight.w800,
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
              fontSize: 13,
              fontWeight: FontWeight.w900,
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
                style: const TextStyle(color: _C.greenDark, fontSize: 10, fontWeight: FontWeight.w900, height: 1.25),
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
                fontWeight: FontWeight.w900,
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
          Text(label, style: const TextStyle(color: _C.subtle, fontSize: 8, fontWeight: FontWeight.w900)),
          const SizedBox(width: 4),
          Text(value, style: const TextStyle(color: _C.text, fontSize: 9.4, fontWeight: FontWeight.w900)),
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
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: _C.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _C.divider.withOpacity(.92)),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: _C.greenSoft,
              borderRadius: BorderRadius.circular(8),
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
                  data.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _C.text,
                    fontSize: 12.8,
                    fontWeight: FontWeight.w900,
                    height: 1,
                    letterSpacing: -.15,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  data.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _C.subtle,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    height: 1,
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
          SizedBox(width: 72, child: Text(label, style: const TextStyle(color: _C.subtle, fontSize: 11, fontWeight: FontWeight.w900))),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _C.text, fontSize: 11.2, fontWeight: FontWeight.w800, fontFamily: 'monospace'),
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
              style: TextStyle(color: isBad ? _C.red : _C.text, fontSize: 12, fontWeight: FontWeight.w900, height: 1.25),
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
              style: TextStyle(color: ok ? _C.text : _C.orange, fontSize: 12, fontWeight: FontWeight.w900),
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
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
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
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
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
      decoration: BoxDecoration(
        color: _C.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.divider, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
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
