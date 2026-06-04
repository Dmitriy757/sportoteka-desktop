import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../models/action_tracker_protocol.dart';
import '../models/tracker_pro_models.dart';
import '../services/action_tracker_ble_service.dart';
import '../services/tracker_permissions.dart';
import '../services/tracker_pro_api.dart';
import '../tracker_live_panel.dart';
import '../widgets/tracker_pro_analytics_panel.dart';

enum TrackerWorkspaceSection { live, analytics, sessions, devices, heatmap, field, video, settings, debug }

class TrackerMatchWorkspaceScreen extends StatefulWidget {
  const TrackerMatchWorkspaceScreen({
    super.key,
    required this.clubId,
    required this.clubName,
    required this.teamId,
    required this.teamName,
    required this.userId,
    this.initialPlayers = const [],
  });

  final int clubId;
  final String clubName;
  final int teamId;
  final String teamName;
  final int userId;
  final List<Map<String, dynamic>> initialPlayers;

  @override
  State<TrackerMatchWorkspaceScreen> createState() => _TrackerMatchWorkspaceScreenState();
}

class _TrackerMatchWorkspaceScreenState extends State<TrackerMatchWorkspaceScreen> {
  late final ActionTrackerBleService _ble;
  late final TrackerProApi _api;

  final List<String> _logs = <String>[];
  final List<ActionTrackerRecord> _records = <ActionTrackerRecord>[];
  final List<ActionTrackerGpsPoint> _points = <ActionTrackerGpsPoint>[];
  final List<ActionTrackerGpsPoint> _calibrationCorners = <ActionTrackerGpsPoint>[];

  List<TrackerPlayerOption> _players = <TrackerPlayerOption>[];
  List<TrackerDeviceModel> _savedDevices = <TrackerDeviceModel>[];
  List<TrackerFieldModel> _fields = <TrackerFieldModel>[];

  TrackerWorkspaceSection _section = TrackerWorkspaceSection.live;
  TrackerPlayerOption? _selectedPlayer;
  TrackerFieldModel? _selectedField;
  ActionTrackerDevice? _connected;
  ActionTrackerBatteryState? _battery;
  ActionTrackerRecord? _selectedRecord;

  StreamSubscription<ActionTrackerParseResult>? _dataSub;
  StreamSubscription<String>? _logSub;

  bool _loading = true;
  bool _scanning = false;
  bool _connecting = false;
  bool _savingRecord = false;
  bool _liveRunning = false;

  @override
  void initState() {
    super.initState();
    _api = TrackerProApi();
    _ble = ActionTrackerBleService();
    _players = widget.initialPlayers.map(TrackerPlayerOption.fromJson).where((p) => p.id > 0).toList();
    _logs.insert(0, '[TEAM] init → ${widget.teamName} (${widget.teamId})');
    _init();
  }


  @override
  void didUpdateWidget(covariant TrackerMatchWorkspaceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.teamId != widget.teamId || oldWidget.clubId != widget.clubId) {
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
      _savedDevices.clear();
      _fields.clear();
      _selectedPlayer = null;
      _selectedField = null;
      _selectedRecord = null;
      _battery = null;
      _connected = _ble.connectedInfo;
      _liveRunning = false;
      _logs.insert(0, '[TEAM] переключение команды → ${widget.teamName} (${widget.teamId})');
      if (_logs.length > 220) _logs.removeRange(220, _logs.length);
    });
  }

  @override
  void dispose() {
    _dataSub?.cancel();
    _logSub?.cancel();
    _ble.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    _bindBle();
    try {
      await _ble.init();
    } catch (e) {
      _toast('Bluetooth', '$e');
    }
    await _loadServerData();
  }

  void _bindBle() {
    _dataSub = _ble.dataStream.listen((event) {
      if (!mounted) return;
      setState(() {
        if (event.battery != null) _battery = event.battery;
        if (event.records.isNotEmpty) {
          _records
            ..clear()
            ..addAll(event.records);
        }
        if (event.gpsChunk != null) _points.addAll(event.gpsChunk!.points);
      });
    });

    _logSub = _ble.logStream.listen((line) {
      if (!mounted) return;
      setState(() {
        _logs.insert(0, line);
        if (_logs.length > 220) _logs.removeLast();
      });
    });
  }

  Future<void> _loadServerData() async {
    if (mounted) setState(() => _loading = true);
    try {
      final results = await Future.wait<dynamic>([
        if (_players.isEmpty) _api.loadPlayers(teamId: widget.teamId) else Future<List<TrackerPlayerOption>>.value(_players),
        _api.loadDevices(teamId: widget.teamId),
        _api.loadFields(teamId: widget.teamId),
      ]);
      if (!mounted) return;
      setState(() {
        _players = results[0] as List<TrackerPlayerOption>;
        _savedDevices = results[1] as List<TrackerDeviceModel>;
        _fields = results[2] as List<TrackerFieldModel>;
        if (_selectedPlayer == null || !_players.any((p) => p.id == _selectedPlayer!.id)) {
          _selectedPlayer = _players.isNotEmpty ? _players.first : null;
        }

        if (_fields.isEmpty) {
          _selectedField = null;
        } else if (_selectedField == null || !_fields.any((f) => f.id == _selectedField!.id)) {
          _selectedField = _fields.firstWhere((f) => f.isDefault, orElse: () => _fields.first);
        }
      });
    } catch (e) {
      _toast('Трекер', 'Ошибка загрузки: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int? get _batteryPercent {
    final battery = _battery;
    if (battery == null) return null;
    return (battery.voltage * 10).round().clamp(0, 100);
  }

  Future<void> _scan() async {
    setState(() => _scanning = true);
    try {
      await TrackerPermissions.ensureBlePermissions();
      await _ble.scan();
    } catch (e) {
      _toast('Bluetooth', '$e');
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _connect(ActionTrackerDevice device) async {
    setState(() => _connecting = true);
    try {
      await TrackerPermissions.ensureBlePermissions();
      await _ble.connect(device);
      _connected = device;
      await _api.registerOrBindDevice(
        clubId: widget.clubId,
        teamId: widget.teamId,
        playerId: _selectedPlayer?.id,
        deviceUuid: device.id,
        deviceName: device.name,
        batteryPercent: _batteryPercent,
      );
      _toast('Подключено', _selectedPlayer == null ? device.name : '${device.name} → ${_selectedPlayer!.name}');
      await _loadServerData();
    } catch (e) {
      _toast('Подключение', '$e');
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _bindSavedDevice(TrackerDeviceModel device, TrackerPlayerOption? player) async {
    try {
      await _api.registerOrBindDevice(
        clubId: widget.clubId,
        teamId: widget.teamId,
        playerId: player?.id,
        deviceUuid: device.deviceUuid,
        deviceName: device.deviceName,
        batteryPercent: device.batteryPercent,
      );
      _toast('Датчик', player == null ? 'Привязка снята' : '${device.deviceName} → ${player.name}');
      await _loadServerData();
    } catch (e) {
      _toast('Датчик', '$e');
    }
  }

  Future<void> _loadGpsRecord(ActionTrackerRecord record) async {
    setState(() {
      _selectedRecord = record;
      _points.clear();
    });
    try {
      await _ble.requestGpsRecord(record);
      _toast('GPS', 'Загрузка записи началась');
    } catch (e) {
      _toast('GPS', '$e');
    }
  }

  Future<void> _saveRecordAsSession() async {
    final connected = _connected ?? _ble.connectedInfo;
    final record = _selectedRecord;
    final player = _selectedPlayer;
    if (connected == null || record == null || player == null || _points.length < 2) {
      _toast('Сессия', 'Нужно подключить трекер, выбрать запись, игрока и иметь GPS-точки');
      return;
    }
    setState(() => _savingRecord = true);
    try {
      await _api.saveGpsSession(
        clubId: widget.clubId,
        teamId: widget.teamId,
        playerId: player.id,
        deviceUuid: connected.id,
        deviceName: connected.name,
        fieldId: _selectedField?.id,
        record: record,
        points: _points,
      );
      _toast('Сессия', 'Запись сохранена');
      await _loadServerData();
    } catch (e) {
      _toast('Сессия', '$e');
    } finally {
      if (mounted) setState(() => _savingRecord = false);
    }
  }

  Future<void> _captureCalibrationPoint() async {
    if (_points.isEmpty) {
      _toast('Калибровка', 'Нет GPS-точки. Запустите Live или загрузите запись.');
      return;
    }
    setState(() {
      if (_calibrationCorners.length >= 4) _calibrationCorners.clear();
      _calibrationCorners.add(_points.last);
    });
    _toast('Калибровка', 'Точка ${_calibrationCorners.length}/4 сохранена');
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
      await _api.saveField(clubId: widget.clubId, teamId: widget.teamId, field: field);
      _calibrationCorners.clear();
      _toast('Поле', 'Калибровка сохранена');
      await _loadServerData();
    } catch (e) {
      _toast('Поле', '$e');
    }
  }

  Future<void> _saveSettingsPreset(TrackerSpeedSettings settings) async {
    try {
      await _api.saveSettings(teamId: widget.teamId, settings: settings);
      _toast('Настройки', 'Профиль ${settings.preset} сохранён');
      setState(() {});
    } catch (e) {
      _toast('Настройки', '$e');
    }
  }

  Future<bool> _confirmExitTrackerIfNeeded() async {
    if (!_liveRunning) return true;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text(
            'Live-сессия активна',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          content: const Text(
            'Вы точно хотите выйти из окна трекера? Локальное чтение GPS/BLE будет остановлено, поэтому лучше сначала остановить Live, если тренировка завершена.',
            style: TextStyle(height: 1.35, fontWeight: FontWeight.w600),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Остаться'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: _TD.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Выйти'),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  Future<void> _handleBackPressed() async {
    final canClose = await _confirmExitTrackerIfNeeded();
    if (!mounted || !canClose) return;
    Navigator.of(context).maybePop();
  }

  void _toast(String title, String message) {
    if (!mounted) return;
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: const Color(0xFF111827),
      colorText: Colors.white,
      margin: const EdgeInsets.all(14),
      duration: const Duration(seconds: 3),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _confirmExitTrackerIfNeeded,
      child: Scaffold(
        backgroundColor: _TD.bg,
        body: SafeArea(
          child: Row(
            children: [
              _DarkRail(selected: _section, onSelect: (section) => setState(() => _section = section)),
              Expanded(
                child: Column(
                  children: [
                    _TopBar(
                      teamName: widget.teamName,
                      clubName: widget.clubName,
                      selectedPlayer: _selectedPlayer?.name ?? 'Игрок не выбран',
                      selectedSection: _section,
                      loading: _loading,
                      onRefresh: _loadServerData,
                      onBack: _handleBackPressed,
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(0, 6, 10, 8),
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
    );
  }

  Widget _buildSection() {
    final sections = TrackerWorkspaceSection.values;
    return IndexedStack(
      index: sections.indexOf(_section),
      sizing: StackFit.expand,
      children: sections.map(_sectionWidget).toList(growable: false),
    );
  }

  Widget _sectionWidget(TrackerWorkspaceSection section) {
    switch (section) {
      case TrackerWorkspaceSection.live:
        return _live();
      case TrackerWorkspaceSection.analytics:
        return _analytics();
      case TrackerWorkspaceSection.sessions:
        return _sessions();
      case TrackerWorkspaceSection.devices:
        return _devices();
      case TrackerWorkspaceSection.heatmap:
        return _heatmap();
      case TrackerWorkspaceSection.field:
        return _field();
      case TrackerWorkspaceSection.video:
        return _video();
      case TrackerWorkspaceSection.settings:
        return _settings();
      case TrackerWorkspaceSection.debug:
        return _debug();
    }
  }

  Widget _live() {
    return TrackerLivePanel(
      key: ValueKey('live_${widget.clubId}_${widget.teamId}'),
      clubId: widget.clubId,
      teamId: widget.teamId,
      teamName: widget.teamName,
      players: _players,
      selectedPlayer: _selectedPlayer,
      selectedField: _selectedField,
      ble: _ble,
      savedDevices: _savedDevices,
      batteryPercent: _batteryPercent,
      onManageTrackers: () => setState(() => _section = TrackerWorkspaceSection.devices),
      onLiveRunningChanged: (running) {
        if (!mounted || _liveRunning == running) return;
        setState(() => _liveRunning = running);
      },
    );
  }

  Widget _analytics() {
    return FutureBuilder<TrackerDashboardModel>(
      future: _api.loadDashboard(teamId: widget.teamId),
      builder: (context, snapshot) {
        return TrackerProAnalyticsPanel(
          loading: snapshot.connectionState == ConnectionState.waiting && snapshot.data == null,
          error: snapshot.hasError ? '${snapshot.error}' : null,
          dashboard: snapshot.data,
          rosterPlayers: _players,
          selectedPlayer: _selectedPlayer,
          onRetry: () => setState(() {}),
          onSelectPlayer: (id) {
            final matches = _players.where((p) => p.id == id).toList();
            if (matches.isNotEmpty) setState(() => _selectedPlayer = matches.first);
          },
        );
      },
    );
  }

  Widget _sessions() {
    return _DarkPage(
      title: 'Сессии / выгрузка',
      subtitle: 'поиск записей, выгрузка GPS, серверные сессии',
      icon: Icons.download_rounded,
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        _DarkActionButton(icon: Icons.refresh_rounded, label: 'Обновить', onTap: () => setState(() {})),
        const SizedBox(width: 8),
        _DarkActionButton(icon: Icons.cloud_upload_rounded, label: _savingRecord ? 'Сохраняю...' : 'Сохранить', primary: true, onTap: _savingRecord ? null : _saveRecordAsSession),
      ]),
      child: Row(children: [
        Expanded(
          flex: 5,
          child: _DarkCard(
            title: 'GPS-записи',
            subtitle: _selectedRecord == null ? '${_records.length} записей на устройстве' : 'selected ${_selectedRecord!.fileId} · ${_points.length} points',
            child: _records.isEmpty
                ? const _DarkEmpty(icon: Icons.download_rounded, text: 'Подключите трекер и загрузите записи.')
                : ListView(children: _records.map((r) => _DarkListTile(
                      icon: Icons.route_rounded,
                      title: 'Record ${r.fileId}',
                      subtitle: '${r.length} bytes${_selectedRecord?.fileId == r.fileId ? ' · ${_points.length} points' : ''}',
                      active: _selectedRecord?.fileId == r.fileId,
                      trailing: _selectedRecord?.fileId == r.fileId ? 'выбрано' : 'загрузить',
                      onTap: () => _loadGpsRecord(r),
                    )).toList()),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 7,
          child: FutureBuilder<List<TrackerSessionModel>>(
            future: _api.loadSessions(teamId: widget.teamId, playerId: _selectedPlayer?.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && snapshot.data == null) {
                return const _DarkCard(title: 'Сессии на сервере', subtitle: 'загрузка', child: Center(child: CircularProgressIndicator()));
              }
              final sessions = snapshot.data ?? const <TrackerSessionModel>[];
              return _DarkCard(
                title: 'Сессии на сервере',
                subtitle: '${sessions.length} сохранённых сессий',
                child: sessions.isEmpty
                    ? const _DarkEmpty(icon: Icons.storage_rounded, text: 'Сессии появятся после сохранения GPS-записи.')
                    : ListView(children: sessions.map((s) => _DarkListTile(
                          icon: Icons.storage_rounded,
                          title: s.title,
                          subtitle: '${s.playerName ?? 'Игрок'} · ${s.createdAt} · ${(s.distanceM / 1000).toStringAsFixed(2)} km · max ${s.maxSpeedKmh.toStringAsFixed(1)}',
                          trailing: 'обработать',
                          onTap: () async {
                            try {
                              await _api.processSession(sessionId: s.id);
                              _toast('Session', 'Processed');
                              setState(() {});
                            } catch (e) {
                              _toast('Session', '$e');
                            }
                          },
                        )).toList()),
              );
            },
          ),
        ),
      ]),
    );
  }

  Widget _devices() {
    return _DarkPage(
      title: 'Датчики / BLE',
      subtitle: 'поиск, подключение, привязка игроков и датчиков',
      icon: Icons.sensors_rounded,
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        _DarkActionButton(icon: Icons.refresh_rounded, label: 'Обновить', onTap: _loadServerData),
        const SizedBox(width: 8),
        _DarkActionButton(icon: Icons.bluetooth_searching_rounded, label: _scanning ? 'Идёт поиск...' : 'Поиск', primary: true, onTap: _scanning ? null : _scan),
      ]),
      child: Row(children: [
        Expanded(child: _DarkCard(
          title: 'Трекеры рядом',
          subtitle: _connected == null ? 'не подключён' : _connected!.name,
          child: StreamBuilder<List<ActionTrackerDevice>>(
            stream: _ble.devicesStream,
            builder: (context, snapshot) {
              final devices = snapshot.data ?? const <ActionTrackerDevice>[];
              if (_scanning) return const Center(child: CircularProgressIndicator());
              if (devices.isEmpty) return const _DarkEmpty(icon: Icons.bluetooth_disabled_rounded, text: 'Нажмите «Поиск», чтобы найти ActionTracer / GPS.');
              return ListView(children: devices.map((d) {
                final active = _ble.connectedInfo?.id == d.id;
                return _DarkListTile(
                  icon: active ? Icons.check_circle_rounded : Icons.sensors_rounded,
                  title: d.name,
                  subtitle: '${d.id} · RSSI ${d.rssi}',
                  active: active,
                  trailing: active ? 'подключено' : 'подключить',
                  onTap: active || _connecting ? null : () => _connect(d),
                );
              }).toList());
            },
          ),
        )),
        const SizedBox(width: 10),
        Expanded(child: _DarkCard(
          title: 'Сохранённые трекеры',
          subtitle: '${_savedDevices.length} датчиков',
          child: _savedDevices.isEmpty
              ? const _DarkEmpty(icon: Icons.sensors_off_rounded, text: 'После подключения трекер появится здесь.')
              : ListView(children: _savedDevices.map((d) => _SavedDeviceDarkTile(device: d, players: _players, onBind: (p) => _bindSavedDevice(d, p))).toList()),
        )),
        const SizedBox(width: 10),
        Expanded(child: _DarkCard(
          title: 'Привязка состава',
          subtitle: '${_players.length} игроков',
          child: _players.isEmpty
              ? const _DarkEmpty(icon: Icons.groups_rounded, text: 'Игроки не загружены.')
              : ListView(children: _players.map((p) {
                  final device = _savedDevices.where((d) => d.playerId == p.id).toList();
                  return _DarkListTile(
                    icon: Icons.person_rounded,
                    avatarUrl: p.avatar,
                    initials: _playerInitials(p.name),
                    title: p.name,
                    subtitle: device.isEmpty ? 'трекер не привязан' : device.first.deviceName,
                    active: _selectedPlayer?.id == p.id,
                    trailing: p.number == null ? null : '#${p.number}',
                    onTap: () => setState(() => _selectedPlayer = p),
                  );
                }).toList()),
        )),
      ]),
    );
  }

  Widget _heatmap() {
    return _DarkPage(
      title: 'Теплокарта / карта спринтов',
      subtitle: 'зоны активности, HIR/VHIR, интенсивность и карта покрытия',
      icon: Icons.local_fire_department_rounded,
      trailing: _DarkActionButton(icon: Icons.refresh_rounded, label: 'Обновить', onTap: () => setState(() {})),
      child: FutureBuilder<List<TrackerHeatPoint>>(
        future: _api.loadHeatmap(teamId: widget.teamId, playerId: _selectedPlayer?.id, fieldId: _selectedField?.id),
        builder: (context, snapshot) {
          final points = snapshot.data ?? const <TrackerHeatPoint>[];
          if (snapshot.connectionState == ConnectionState.waiting && snapshot.data == null) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError) return _DarkError(error: '${snapshot.error}', onRetry: () => setState(() {}));
          return Row(children: [
            Expanded(flex: 8, child: _DarkCard(title: 'Теплокарта поля', subtitle: points.isEmpty ? 'нет точек' : '${points.length} points', child: CustomPaint(painter: _DarkHeatmapPainter(points: points), child: const SizedBox.expand()))),
            const SizedBox(width: 10),
            Expanded(flex: 3, child: _DarkCard(title: 'Фильтры', subtitle: _selectedPlayer?.name ?? 'team', child: Column(children: [
              _DarkMetricTile(icon: Icons.person_rounded, title: 'Игрок', value: _selectedPlayer?.name ?? 'All', subtitle: 'фильтр'),
              const SizedBox(height: 8),
              _DarkMetricTile(icon: Icons.map_rounded, title: 'Поле', value: _selectedField?.title ?? 'None', subtitle: _selectedField?.hasCalibration == true ? 'откалибровано' : 'нужны углы'),
              const SizedBox(height: 8),
              _DarkMetricTile(icon: Icons.local_fire_department_rounded, title: 'Heat points', value: '${points.length}', subtitle: 'отрисовано'),
              const Spacer(),
              const _DarkHint(text: 'Здесь можно переключать Sprint Map / Acceleration Map / Fatigue Zones / Heatmap.'),
            ]))),
          ]);
        },
      ),
    );
  }

  Widget _field() {
    return _DarkPage(
      title: 'Калибровка поля',
      subtitle: '4 GPS corners, projection 105×68, one field for all trackers',
      icon: Icons.map_rounded,
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        _DarkActionButton(icon: Icons.add_location_alt_rounded, label: 'Точка', primary: true, onTap: _captureCalibrationPoint),
        const SizedBox(width: 8),
        _DarkActionButton(icon: Icons.save_rounded, label: 'Сохранить', onTap: _calibrationCorners.length >= 4 ? _saveCapturedField : null),
      ]),
      child: Row(children: [
        Expanded(flex: 4, child: _DarkCard(
          title: 'Поля команды',
          subtitle: '${_fields.length} fields',
          child: _fields.isEmpty
              ? const _DarkEmpty(icon: Icons.map_rounded, text: 'Создайте поле через 4 угла.')
              : ListView(children: _fields.map((f) => _DarkListTile(
                    icon: f.hasCalibration ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                    title: f.title,
                    subtitle: '${f.lengthM.toStringAsFixed(0)}×${f.widthM.toStringAsFixed(0)} m · ${f.hasCalibration ? 'откалибровано' : 'нужна калибровка'}',
                    active: _selectedField?.id == f.id,
                    trailing: _selectedField?.id == f.id ? 'выбрано' : 'выбрать',
                    onTap: () => setState(() => _selectedField = f),
                  )).toList()),
        )),
        const SizedBox(width: 10),
        Expanded(flex: 8, child: _DarkCard(
          title: 'Калибровка по 4 точкам',
          subtitle: 'go to each corner and press Point',
          child: Column(children: [
            Expanded(child: CustomPaint(painter: _DarkCalibrationPainter(corners: _calibrationCorners), child: const SizedBox.expand())),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: List.generate(4, (i) {
              final ready = _calibrationCorners.length > i;
              return _DarkCornerChip(
                label: ['A', 'B', 'C', 'D'][i],
                value: ready ? '${_calibrationCorners[i].latitude.toStringAsFixed(6)}, ${_calibrationCorners[i].longitude.toStringAsFixed(6)}' : 'не задано',
                ready: ready,
              );
            })),
          ]),
        )),
      ]),
    );
  }

  Widget _video() {
    return const _DarkPage(
      title: 'Синхронизация видео / мастер событий',
      subtitle: 'синхронизация трекера, видео и автоматической нарезки',
      icon: Icons.video_library_rounded,
      child: Row(children: [
        Expanded(flex: 8, child: _DarkCard(title: 'Лента видео', subtitle: 'событий from speed/load alerts', child: CustomPaint(painter: _DarkTimelinePainter(), child: SizedBox.expand()))),
        SizedBox(width: 10),
        Expanded(flex: 4, child: _DarkCard(title: 'Мастер событий', subtitle: 'auto clips', child: Column(children: [
          _DarkHint(text: 'Сценарии: Sprint > 30 км/ч, Fatigue > 70%, Speed Drop > 20%, рывок в штрафной, частые COD.'),
          SizedBox(height: 10),
          _DarkMetricTile(icon: Icons.content_cut_rounded, title: 'Автонарезки', value: '0', subtitle: 'пока не создано'),
          SizedBox(height: 8),
          _DarkMetricTile(icon: Icons.sync_rounded, title: 'Sync', value: 'GPS + видео', subtitle: 'roadmap'),
        ]))),
      ]),
    );
  }

  Widget _settings() {
    return _DarkPage(
      title: 'Пороги / настройки',
      subtitle: 'speed zones, sprint thresholds, acceleration rules',
      icon: Icons.tune_rounded,
      trailing: _DarkActionButton(icon: Icons.refresh_rounded, label: 'Обновить', onTap: () => setState(() {})),
      child: FutureBuilder<TrackerSpeedSettings>(
        future: _api.loadSettings(teamId: widget.teamId),
        builder: (context, snapshot) {
          final settings = snapshot.data ?? const TrackerSpeedSettings();
          return Row(children: [
            Expanded(child: _DarkCard(title: 'Текущие пороги', subtitle: settings.preset, child: GridView.count(crossAxisCount: 2, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 2.25, children: [
              _DarkMetricTile(icon: Icons.directions_walk_rounded, title: 'Jog', value: '${settings.jogRuleMps.toStringAsFixed(1)} m/s', subtitle: 'low zone'),
              _DarkMetricTile(icon: Icons.speed_rounded, title: 'Medium', value: '${settings.mediumRuleMps.toStringAsFixed(1)} m/s', subtitle: 'run zone'),
              _DarkMetricTile(icon: Icons.local_fire_department_rounded, title: 'HIR', value: '${settings.highRuleMps.toStringAsFixed(1)} m/s', subtitle: 'высокая интенсивность'),
              _DarkMetricTile(icon: Icons.flash_on_rounded, title: 'Спринт', value: '${settings.sprintRuleMps.toStringAsFixed(1)} m/s', subtitle: 'sprint'),
              _DarkMetricTile(icon: Icons.timer_rounded, title: 'Sprint time', value: '${settings.sprintTimeSec.toStringAsFixed(1)} s', subtitle: 'minimum'),
              _DarkMetricTile(icon: Icons.compare_arrows_rounded, title: 'Ускор.', value: '${settings.accelerationRuleMps2.toStringAsFixed(1)} m/s²', subtitle: 'IMA'),
            ]))),
            const SizedBox(width: 10),
            Expanded(child: _DarkCard(title: 'Профили', subtitle: 'быстрое применение', child: Column(children: [
              _PresetDarkButton(title: 'U13 / Academy', subtitle: 'мягкие зоны для детского футбола', onTap: () => _saveSettingsPreset(settings.copyWith(preset: 'u13', jogRuleMps: 1.2, mediumRuleMps: 3.0, highRuleMps: 4.0, sprintRuleMps: 5.5, accelerationRuleMps2: 1.8))),
              _PresetDarkButton(title: 'U17 / Semi-pro', subtitle: 'усиленные зоны HIR/VHIR', onTap: () => _saveSettingsPreset(settings.copyWith(preset: 'u17', jogRuleMps: 1.5, mediumRuleMps: 3.5, highRuleMps: 5.0, sprintRuleMps: 6.4, accelerationRuleMps2: 2.0))),
              _PresetDarkButton(title: 'Pro / Elite', subtitle: 'порог спринта выше', onTap: () => _saveSettingsPreset(settings.copyWith(preset: 'pro', jogRuleMps: 1.8, mediumRuleMps: 4.0, highRuleMps: 5.5, sprintRuleMps: 7.0, accelerationRuleMps2: 2.5))),
              const Spacer(),
              const _DarkHint(text: 'Пороги используются для HIR/VHIR/Sprint/Acceleration анализа.'),
            ]))),
          ]);
        },
      ),
    );
  }

  Widget _debug() {
    return _DarkPage(
      title: 'Диагностика устройства / RX-TX',
      subtitle: 'BLE, GPS, API, raw packets прямо на планшете',
      icon: Icons.bug_report_rounded,
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        _DarkActionButton(icon: Icons.delete_outline_rounded, label: 'Очистить', onTap: () => setState(() => _logs.clear())),
        const SizedBox(width: 8),
        _DarkActionButton(icon: Icons.refresh_rounded, label: 'Обновить', primary: true, onTap: _loadServerData),
      ]),
      child: Row(children: [
        Expanded(flex: 8, child: _DarkCard(title: 'BLE-логи', subtitle: '${_logs.length} lines', child: _logs.isEmpty ? const _DarkEmpty(icon: Icons.terminal_rounded, text: 'Логи появятся после поиска, подключения и Live.') : ListView.builder(itemCount: _logs.length, itemBuilder: (_, i) => Padding(padding: const EdgeInsets.only(bottom: 5), child: Text(_logs[i], style: const TextStyle(color: _TD.muted, fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.w700)))))),
        const SizedBox(width: 10),
        Expanded(flex: 4, child: _DarkCard(title: 'Состояние', subtitle: 'быстрая диагностика', child: Column(children: [
          _DarkMetricTile(icon: Icons.bluetooth_rounded, title: 'BLE', value: _ble.connectedInfo?.name ?? 'off', subtitle: _ble.connectedInfo?.id ?? 'не подключён'),
          const SizedBox(height: 8),
          _DarkMetricTile(icon: Icons.person_rounded, title: 'Игрок', value: _selectedPlayer?.name ?? 'none', subtitle: 'active'),
          const SizedBox(height: 8),
          _DarkMetricTile(icon: Icons.map_rounded, title: 'Поле', value: _selectedField?.title ?? 'none', subtitle: _selectedField?.hasCalibration == true ? 'откалибровано' : 'не готово'),
          const SizedBox(height: 8),
          _DarkMetricTile(icon: Icons.route_rounded, title: 'GPS points', value: '${_points.length}', subtitle: 'loaded/current'),
        ]))),
      ]),
    );
  }
}

class _TD {
  // Светлый CMR-холст + чёрное левое меню как в club workspace.
  static const bg = Color(0xFFF4F5F6);
  static const rail = Color(0xFF101214);
  static const panel = Color(0xFFFFFFFF);
  static const card = Color(0xFFFFFFFF);
  static const card2 = Color(0xFFF8F9FA);
  static const border = Color(0xFFE5E7EB);
  static const grid = Color(0xFFD8DEE6);
  static const text = Color(0xFF111827);
  static const muted = Color(0xFF475467);
  static const dim = Color(0xFF6B7280);

  // Минимальный зелёный акцент: точки, маленькие статусы, активные маркеры.
  static const green = Color(0xFF00A750);
  static const yellow = Color(0xFFB7791F);
  static const orange = Color(0xFFB7791F);
  static const red = Color(0xFFD92D20);
  static const blue = Color(0xFF344054);
}

extension _SectionExt on TrackerWorkspaceSection {
  String get title => switch (this) {
        TrackerWorkspaceSection.live => 'Онлайн',
        TrackerWorkspaceSection.analytics => 'Аналитика',
        TrackerWorkspaceSection.sessions => 'Сессии',
        TrackerWorkspaceSection.devices => 'Датчики',
        TrackerWorkspaceSection.heatmap => 'Теплокарта',
        TrackerWorkspaceSection.field => 'Поле',
        TrackerWorkspaceSection.video => 'Видео',
        TrackerWorkspaceSection.settings => 'Настройки',
        TrackerWorkspaceSection.debug => 'Диагн.',
      };

  IconData get icon => switch (this) {
        TrackerWorkspaceSection.live => Icons.radio_button_checked_rounded,
        TrackerWorkspaceSection.analytics => Icons.analytics_rounded,
        TrackerWorkspaceSection.sessions => Icons.download_rounded,
        TrackerWorkspaceSection.devices => Icons.sensors_rounded,
        TrackerWorkspaceSection.heatmap => Icons.local_fire_department_rounded,
        TrackerWorkspaceSection.field => Icons.map_rounded,
        TrackerWorkspaceSection.video => Icons.video_library_rounded,
        TrackerWorkspaceSection.settings => Icons.tune_rounded,
        TrackerWorkspaceSection.debug => Icons.bug_report_rounded,
      };
}

class _DarkRail extends StatelessWidget {
  const _DarkRail({required this.selected, required this.onSelect});
  final TrackerWorkspaceSection selected;
  final ValueChanged<TrackerWorkspaceSection> onSelect;

  @override
  Widget build(BuildContext context) {
    final items = TrackerWorkspaceSection.values;
    return Container(
      width: 78,
      padding: const EdgeInsets.all(8),
      child: Container(
        decoration: BoxDecoration(
          color: _TD.rail,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.14),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 7),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 7),
          itemBuilder: (context, i) {
            final item = items[i];
            return _RailButton(icon: item.icon, label: item.title, active: item == selected, onTap: () => onSelect(item));
          },
        ),
      ),
    );
  }
}

class _RailButton extends StatefulWidget {
  const _RailButton({required this.icon, required this.label, required this.active, required this.onTap});
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  @override
  State<_RailButton> createState() => _RailButtonState();
}

class _RailButtonState extends State<_RailButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final bg = widget.active ? Colors.white : Colors.transparent;
    final fg = widget.active ? _TD.rail : Colors.white.withOpacity(.84);
    return Listener(
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 110),
        scale: _pressed ? .95 : 1,
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(11),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(11),
            child: Container(
              height: 58,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(11), border: Border.all(color: widget.active ? Colors.white : Colors.white.withOpacity(.08))),
              child: Stack(children: [
                if (widget.active) const Positioned(right: 4, top: 4, child: DecoratedBox(decoration: BoxDecoration(color: _TD.blue, shape: BoxShape.circle), child: SizedBox(width: 5, height: 5))),
                Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(widget.icon, color: fg, size: 20),
                  const SizedBox(height: 5),
                  Text(widget.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: fg, fontSize: 8.4, fontWeight: FontWeight.w900)),
                ])),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.teamName, required this.clubName, required this.selectedPlayer, required this.selectedSection, required this.loading, required this.onRefresh, required this.onBack});
  final String teamName;
  final String clubName;
  final String selectedPlayer;
  final TrackerWorkspaceSection selectedSection;
  final bool loading;
  final VoidCallback onRefresh;
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      margin: const EdgeInsets.fromLTRB(0, 8, 10, 0),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: _TD.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: _TD.border.withOpacity(.85))),
      child: Row(children: [
        IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back_rounded, color: _TD.text)),
        const SizedBox(width: 6),
        Container(width: 34, height: 34, decoration: BoxDecoration(color: _TD.card2, borderRadius: BorderRadius.circular(9)), child: Icon(selectedSection.icon, color: _TD.green, size: 19)),
        const SizedBox(width: 10),
        Expanded(child: Text('Спортотека Трекинг · ${selectedSection.title}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _TD.text, fontWeight: FontWeight.w900, fontSize: 16))),
        _TopPill(label: clubName, value: teamName),
        const SizedBox(width: 8),
        _TopPill(label: 'Игрок', value: selectedPlayer),
        const SizedBox(width: 8),
        IconButton(onPressed: loading ? null : onRefresh, icon: loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh_rounded, color: _TD.text)),
      ]),
    );
  }
}

class _TopPill extends StatelessWidget {
  const _TopPill({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      constraints: const BoxConstraints(maxWidth: 230),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: _TD.card, border: Border.all(color: _TD.border), borderRadius: BorderRadius.circular(9)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: _TD.dim, fontSize: 8.5, fontWeight: FontWeight.w900)),
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _TD.text, fontSize: 11, fontWeight: FontWeight.w900)),
      ]),
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
    return Container(
      color: _TD.bg,
      child: Column(
        children: [
          _WorkspaceFlatHeader(
            icon: icon,
            title: title,
            subtitle: subtitle,
            trailing: trailing,
          ),
          const SizedBox(height: 10),
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
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: _TD.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _TD.border.withOpacity(.9)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _TD.card2,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: _TD.green, size: 19),
          ),
          const SizedBox(width: 10),
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
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.25,
                  ),
                ),
                if (subtitle.trim().isNotEmpty)
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _TD.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
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
    final hasHeader = title.trim().isNotEmpty || subtitle.trim().isNotEmpty;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _TD.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _TD.border.withOpacity(.94), width: 1),
      ),
      child: Column(
        children: [
          if (hasHeader)
            Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: _TD.card2,
                border: Border(
                  bottom: BorderSide(color: _TD.border.withOpacity(.9)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _TD.text,
                        fontSize: 12.6,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.08,
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
                        style: const TextStyle(
                          color: _TD.muted,
                          fontSize: 9.8,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _DarkActionButton extends StatefulWidget {
  const _DarkActionButton({required this.icon, required this.label, required this.onTap, this.primary = false});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool primary;
  @override
  State<_DarkActionButton> createState() => _DarkActionButtonState();
}

class _DarkActionButtonState extends State<_DarkActionButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return Listener(
      onPointerDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onPointerUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onPointerCancel: enabled ? (_) => setState(() => _pressed = false) : null,
      child: AnimatedScale(
        scale: _pressed ? .96 : 1,
        duration: const Duration(milliseconds: 110),
        child: Material(
          color: widget.primary ? _TD.green : _TD.card,
          borderRadius: BorderRadius.circular(9),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(9),
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 11),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(9), border: Border.all(color: widget.primary ? _TD.green : _TD.border)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(widget.icon, color: widget.primary ? _TD.bg : _TD.text, size: 17),
                const SizedBox(width: 6),
                Text(widget.label, style: TextStyle(color: widget.primary ? _TD.bg : _TD.text, fontSize: 11, fontWeight: FontWeight.w900)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _DarkMetricTile extends StatelessWidget {
  const _DarkMetricTile({required this.icon, required this.title, required this.value, required this.subtitle});
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: _TD.card2, borderRadius: BorderRadius.circular(10), border: Border.all(color: _TD.border)),
      padding: const EdgeInsets.all(10),
      child: Row(children: [
        Icon(icon, color: _TD.green),
        const SizedBox(width: 9),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _TD.muted, fontSize: 10, fontWeight: FontWeight.w800)),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _TD.text, fontSize: 16, fontWeight: FontWeight.w900)),
          Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _TD.dim, fontSize: 9, fontWeight: FontWeight.w700)),
        ])),
      ]),
    );
  }
}

class _DarkListTile extends StatelessWidget {
  const _DarkListTile({required this.icon, required this.title, required this.subtitle, this.trailing, this.active = false, this.onTap, this.avatarUrl, this.initials});
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
    final color = active ? _TD.green : _TD.muted;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: active ? _TD.green.withOpacity(.10) : _TD.card2, borderRadius: BorderRadius.circular(9), border: Border.all(color: active ? _TD.green.withOpacity(.4) : _TD.border)),
      child: ListTile(
        dense: true,
        onTap: onTap,
        leading: avatarUrl == null && initials == null
            ? Icon(icon, color: color)
            : _PlayerAvatarDark(
                url: avatarUrl,
                initials: initials ?? _playerInitials(title),
                size: 38,
                active: active,
              ),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _TD.text, fontWeight: FontWeight.w900)),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _TD.muted, fontSize: 11, fontWeight: FontWeight.w700)),
        trailing: trailing == null ? null : Text(trailing!, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 11)),
      ),
    );
  }
}

class _SavedDeviceDarkTile extends StatelessWidget {
  const _SavedDeviceDarkTile({required this.device, required this.players, required this.onBind});
  final TrackerDeviceModel device;
  final List<TrackerPlayerOption> players;
  final ValueChanged<TrackerPlayerOption?> onBind;
  @override
  Widget build(BuildContext context) {
    final boundPlayers = players.where((p) => p.id == device.playerId).toList();
    final boundPlayer = boundPlayers.isEmpty ? null : boundPlayers.first;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: _TD.card2, borderRadius: BorderRadius.circular(9), border: Border.all(color: _TD.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          children: [
            _PlayerAvatarDark(
              url: boundPlayer?.avatar,
              initials: _playerInitials(boundPlayer?.name ?? device.playerName ?? device.deviceName),
              size: 38,
              active: boundPlayer != null,
              fallbackIcon: Icons.sensors_rounded,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(device.deviceName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _TD.text, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 3),
                  Text(
                    '${device.deviceUuid}${boundPlayer == null && device.playerName == null ? '' : ' · ${boundPlayer?.name ?? device.playerName}'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _TD.muted, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<int?>(
          value: device.playerId,
          dropdownColor: _TD.card,
          isExpanded: true,
          decoration: InputDecoration(
            isDense: true,
            labelText: 'Игрок',
            labelStyle: const TextStyle(color: _TD.muted),
            filled: true,
            fillColor: _TD.panel,
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: _TD.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: _TD.green)),
          ),
          style: const TextStyle(color: _TD.text, fontWeight: FontWeight.w800),
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
                      size: 26,
                      active: true,
                    ),
                    const SizedBox(width: 8),
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
      ]),
    );
  }
}


class _PlayerAvatarDark extends StatelessWidget {
  const _PlayerAvatarDark({
    required this.url,
    required this.initials,
    this.size = 38,
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
        border: Border.all(color: borderColor, width: active ? 2 : 1),
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
                fontWeight: FontWeight.w900,
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


class _DarkEmpty extends StatelessWidget {
  const _DarkEmpty({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) {
    return Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 360), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, size: 38, color: _TD.dim),
      const SizedBox(height: 10),
      Text(text, textAlign: TextAlign.center, style: const TextStyle(color: _TD.muted, fontWeight: FontWeight.w800)),
    ])));
  }
}

class _DarkError extends StatelessWidget {
  const _DarkError({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Center(child: Container(constraints: const BoxConstraints(maxWidth: 560), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Color(0xFFFFF1F1), borderRadius: BorderRadius.circular(10), border: Border.all(color: Color(0xFFF7C8C4))), child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.warning_amber_rounded, color: _TD.red),
      const SizedBox(height: 8),
      Text(error, textAlign: TextAlign.center, style: const TextStyle(color: _TD.red, fontWeight: FontWeight.w800)),
      const SizedBox(height: 10),
      _DarkActionButton(icon: Icons.refresh_rounded, label: 'Повторить', onTap: onRetry),
    ])));
  }
}

class _PresetDarkButton extends StatelessWidget {
  const _PresetDarkButton({required this.title, required this.subtitle, required this.onTap});
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => _DarkListTile(icon: Icons.tune_rounded, title: title, subtitle: subtitle, trailing: 'применить', onTap: onTap);
}

class _DarkHint extends StatelessWidget {
  const _DarkHint({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: _TD.card2, borderRadius: BorderRadius.circular(10), border: Border.all(color: _TD.border)), child: Text(text, style: const TextStyle(color: _TD.green, fontWeight: FontWeight.w800, fontSize: 11.5, height: 1.25)));
  }
}

class _DarkCornerChip extends StatelessWidget {
  const _DarkCornerChip({required this.label, required this.value, required this.ready});
  final String label;
  final String value;
  final bool ready;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 230,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: ready ? _TD.green.withOpacity(.10) : _TD.card2, borderRadius: BorderRadius.circular(9), border: Border.all(color: ready ? _TD.green.withOpacity(.35) : _TD.border)),
      child: Row(children: [
        CircleAvatar(radius: 13, backgroundColor: ready ? _TD.green : _TD.dim, child: Text(label, style: const TextStyle(color: _TD.bg, fontSize: 11, fontWeight: FontWeight.w900))),
        const SizedBox(width: 8),
        Expanded(child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _TD.muted, fontSize: 10, fontWeight: FontWeight.w800))),
      ]),
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
      final color = ratio > .7 ? _TD.red : ratio > .4 ? _TD.orange : _TD.green;
      canvas.drawCircle(Offset(x, y), radius, Paint()..shader = RadialGradient(colors: [color.withOpacity(.38), color.withOpacity(.08), Colors.transparent]).createShader(Rect.fromCircle(center: Offset(x, y), radius: radius)));
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
    canvas.drawRRect(RRect.fromRectAndRadius(pitch, const Radius.circular(8)), Paint()..color = const Color(0xFF0A7F39));
    for (var i = 0; i < 12; i++) {
      canvas.drawRect(Rect.fromLTWH(pitch.left + pitch.width * i / 12, pitch.top, pitch.width / 12, pitch.height), Paint()..color = i.isEven ? Colors.white.withOpacity(.04) : Colors.black.withOpacity(.05));
    }
    final inner = pitch.deflate(12);
    final line = Paint()
      ..color = Colors.white.withOpacity(.85)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawRect(inner, line);
    canvas.drawLine(Offset(inner.center.dx, inner.top), Offset(inner.center.dx, inner.bottom), line);
    canvas.drawCircle(inner.center, inner.width * .085, line);
    canvas.drawRect(Rect.fromLTWH(inner.left, inner.center.dy - inner.height * .22, inner.width * .16, inner.height * .44), line);
    canvas.drawRect(Rect.fromLTWH(inner.right - inner.width * .16, inner.center.dy - inner.height * .22, inner.width * .16, inner.height * .44), line);
  }

  void _drawText(Canvas canvas, Size size, String text) {
    final tp = TextPainter(text: TextSpan(text: text, style: const TextStyle(color: _TD.muted, fontSize: 18, fontWeight: FontWeight.w900)), textDirection: TextDirection.ltr)..layout(maxWidth: size.width - 40);
    tp.paint(canvas, Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2));
  }

  @override
  bool shouldRepaint(covariant _DarkHeatmapPainter oldDelegate) => true;
}

class _DarkCalibrationPainter extends CustomPainter {
  const _DarkCalibrationPainter({required this.corners});
  final List<ActionTrackerGpsPoint> corners;
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
    final cornersPos = [pitch.topLeft + const Offset(18, 18), pitch.topRight + const Offset(-18, 18), pitch.bottomRight + const Offset(-18, -18), pitch.bottomLeft + const Offset(18, -18)];
    for (var i = 0; i < 4; i++) {
      final ready = corners.length > i;
      final p = cornersPos[i];
      canvas.drawCircle(p, 16, Paint()..color = ready ? _TD.green : _TD.dim);
      final tp = TextPainter(text: TextSpan(text: ['A', 'B', 'C', 'D'][i], style: const TextStyle(color: _TD.bg, fontWeight: FontWeight.w900)), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
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
    canvas.drawLine(Offset(30, y), Offset(size.width - 30, y), Paint()..color = _TD.border..strokeWidth = 2);
    for (var i = 0; i <= 8; i++) {
      final x = 30 + (size.width - 60) * i / 8;
      canvas.drawCircle(Offset(x, y), 5, Paint()..color = i.isEven ? _TD.green : _TD.orange);
      final tp = TextPainter(text: TextSpan(text: '${i * 15}’', style: const TextStyle(color: _TD.muted, fontSize: 10, fontWeight: FontWeight.w800)), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, y + 14));
    }
  }
  @override
  bool shouldRepaint(covariant _DarkTimelinePainter oldDelegate) => false;
}
