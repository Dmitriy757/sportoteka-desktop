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
import '../tracker_player_activity_screen.dart';
import '../widgets/tracker_pro_analytics_panel.dart';
import '../reports/tracker_training_report_screen.dart';

enum TrackerWorkspaceSection { dashboard, live, activity, sessions, devices, field, settings, debug }

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

  TrackerWorkspaceSection _section = TrackerWorkspaceSection.dashboard;
  TrackerPlayerOption? _selectedPlayer;
  TrackerFieldModel? _selectedField;
  ActionTrackerDevice? _connected;
  ActionTrackerBatteryState? _battery;
  ActionTrackerRecord? _selectedRecord;
  TrackerSessionModel? _selectedReportSession;

  StreamSubscription<ActionTrackerParseResult>? _dataSub;
  StreamSubscription<String>? _logSub;

  bool _loading = true;
  bool _scanning = false;
  bool _connecting = false;
  bool _savingRecord = false;
  bool _liveRunning = false;
  bool _trackerWindowMinimized = false;
  bool _trackerWindowMaximized = false;
  bool _trackerSideCollapsed = false;

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
      _selectedReportSession = null;
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

  String _friendlyBleError(Object error) {
    final raw = '$error';
    final lower = raw.toLowerCase();
    if (raw.contains('CBManagerStateUnsupported')) {
      return 'Bluetooth недоступен в текущей среде. На macOS запустите именно desktop-приложение, включите Bluetooth и проверьте разрешения для приложения.';
    }
    if (lower.contains('bluetooth must be turned on')) {
      return 'Bluetooth выключен. Включите Bluetooth на Mac и повторите поиск трекера.';
    }
    if (lower.contains('permission') || lower.contains('unauthorized')) {
      return 'Нет разрешения на Bluetooth. Откройте Системные настройки macOS → Конфиденциальность и безопасность → Bluetooth и разрешите доступ приложению.';
    }
    return raw;
  }

  Future<void> _scan() async {
    setState(() => _scanning = true);
    try {
      await TrackerPermissions.ensureBlePermissions();
      await _ble.scan();
    } catch (e) {
      _toast('Bluetooth', _friendlyBleError(e));
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
    _toast('Поле', 'Создано новое поле. Пройдите углы A → B → C → D и нажмите «Сохранить».');
  }

  void _resetCalibrationCorners() {
    setState(() => _calibrationCorners.clear());
    _toast('Калибровка', 'Точки A/B/C/D сброшены.');
  }

  Future<void> _handleCornerTap(int index) async {
    if (index != _calibrationCorners.length) {
      final labels = const ['A', 'B', 'C', 'D'];
      _toast('Калибровка', 'Сейчас нужна точка ${labels[_calibrationCorners.length.clamp(0, 3)]}. Идите по порядку A → B → C → D.');
      return;
    }
    await _captureCalibrationPoint();
  }

  Future<void> _captureCalibrationPoint() async {
    final labels = const ['A', 'B', 'C', 'D'];
    if (_calibrationCorners.length >= 4) {
      _toast('Калибровка', 'Все 4 точки уже получены. Нажмите «Сохранить» или «Сбросить».');
      return;
    }

    if (_points.isEmpty) {
      _toast('Калибровка', 'Нет GPS-точки от трекера. Подключите датчик и дождитесь GPS-пакета.');
      return;
    }

    final nextIndex = _calibrationCorners.length;
    final point = _points.last;

    setState(() {
      _calibrationCorners.add(point);
    });

    _toast(
      'Калибровка',
      'Точка ${labels[nextIndex]} сохранена (${_calibrationCorners.length}/4).',
    );
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
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          content: const Text(
            'Вы точно хотите выйти из окна трекера? Локальное чтение GPS/BLE будет остановлено, поэтому лучше сначала остановить Live, если тренировка завершена.',
            style: TextStyle(height: 1.35, fontWeight: FontWeight.w500),
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
      margin: const EdgeInsets.all(14),
      duration: const Duration(seconds: 4),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embeddedInClubWorkspace) {
      return WillPopScope(
        onWillPop: () async => false,
        child: _buildEmbeddedTrackerProgram(),
      );
    }

    return WillPopScope(
      onWillPop: _confirmExitTrackerIfNeeded,
      child: Scaffold(
        backgroundColor: _TD.bg,
        body: SafeArea(
          child: Row(
            children: [
              _DarkRail(
                selected: _section,
                onSelect: (section) => setState(() => _section = section),
                onBack: _handleBackPressed,
              ),
              Expanded(
                child: Column(
                  children: [
                    if (_section != TrackerWorkspaceSection.live)
                      _TopBar(
                        teamName: widget.teamName,
                        clubName: widget.clubName,
                        selectedPlayer: _selectedPlayer?.name ?? 'Игрок не выбран',
                        selectedSection: _section,
                        loading: _loading,
                        onRefresh: _loadServerData,
                      ),
                    Expanded(
                      child: Padding(
                        padding: _section == TrackerWorkspaceSection.live
                            ? EdgeInsets.zero
                            : const EdgeInsets.fromLTRB(0, 6, 6, 6),
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

  Widget _buildEmbeddedTrackerProgram() {
    if (_trackerWindowMinimized) {
      return _TrackerProgramCollapsedBar(
        clubName: widget.clubName,
        teamName: widget.teamName,
        liveRunning: _liveRunning,
        connected: _connected != null,
        onRestore: () => setState(() => _trackerWindowMinimized = false),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compactNav = constraints.maxWidth < 1180;
        final mobile = constraints.maxWidth < 720;
        // На ПК меню трекера теперь открыто по умолчанию и не схлопывается
        // автоматически из-за ширины окна. На телефоне оставляем компактную
        // иконную панель, чтобы не съедать рабочую область.
        final forceIconNav = mobile || _trackerSideCollapsed;
        final navWidth = mobile ? 48.0 : (forceIconNav ? 54.0 : 156.0);

        final window = Container(
          clipBehavior: Clip.antiAlias,
          decoration: _TD.unifiedWindow(radius: _trackerWindowMaximized ? 16 : 24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: navWidth,
                child: _TrackerProgramSidePanel(
                  clubName: widget.clubName,
                  teamName: widget.teamName,
                  selectedPlayer: _selectedPlayer?.name ?? 'Игрок не выбран',
                  selected: _section,
                  loading: _loading,
                  liveRunning: _liveRunning,
                  connected: _connected != null,
                  compact: forceIconNav,
                  collapsed: forceIconNav,
                  onSelect: (section) => setState(() => _section = section),
                  onRefresh: _loadServerData,
                  onMinimize: () => setState(() => _trackerWindowMinimized = true),
                  onToggleCollapsed: (compactNav || mobile) ? null : () => setState(() => _trackerSideCollapsed = !_trackerSideCollapsed),
                ),
              ),
              Container(width: 1, color: _TD.softLine),
              Expanded(child: _buildSection()),
            ],
          ),
        );

        return Container(
          decoration: _TD.workspaceBg(),
          padding: EdgeInsets.all(_trackerWindowMaximized ? 0 : 10),
          child: Stack(
            children: [
              Positioned.fill(child: window),
              Positioned(
                right: _trackerWindowMaximized ? 8 : 18,
                bottom: _trackerWindowMaximized ? 8 : 18,
                child: _TrackerWindowCornerButton(
                  maximized: _trackerWindowMaximized,
                  onTap: () => setState(() => _trackerWindowMaximized = !_trackerWindowMaximized),
                ),
              ),
            ],
          ),
        );
      },
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
      case TrackerWorkspaceSection.dashboard:
        return _dashboard();
      case TrackerWorkspaceSection.live:
        return _live();
      case TrackerWorkspaceSection.activity:
        return _activity();
      case TrackerWorkspaceSection.sessions:
        return _sessions();
      case TrackerWorkspaceSection.devices:
        return _devices();
      case TrackerWorkspaceSection.field:
        return _field();
      case TrackerWorkspaceSection.settings:
        return _settings();
      case TrackerWorkspaceSection.debug:
        return _debug();
    }
  }

  Widget _dashboard() {
    return FutureBuilder<TrackerDashboardModel>(
      future: _api.loadDashboard(teamId: widget.teamId),
      builder: (context, snapshot) {
        final dashboard = snapshot.data;
        final summary = dashboard?.summary ?? const <String, dynamic>{};
        final rows = dashboard?.players ?? const <TrackerPlayerLoadRow>[];
        final connected = _savedDevices.where((d) => d.playerId != null).length;
        final readyFields = _fields.where((f) => f.hasCalibration).length;
        final gpsReady = _points.isNotEmpty || _connected != null;

        return _DarkPage(
          title: 'Tracker Pro',
          subtitle: 'Catapult-режим: подключение, Live, команда, отчёты и поле в одном рабочем сценарии',
          icon: Icons.dashboard_customize_rounded,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DarkActionButton(
                icon: Icons.play_arrow_rounded,
                label: 'Открыть Live',
                primary: true,
                onTap: () => setState(() => _section = TrackerWorkspaceSection.live),
              ),
              const SizedBox(width: 8),
              _DarkActionButton(
                icon: Icons.sensors_rounded,
                label: 'Трекеры',
                onTap: () => setState(() => _section = TrackerWorkspaceSection.devices),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, c) {
              final compact = c.maxWidth < 920;
              final kpi = _dashboardKpis(summary, rows.length, connected, readyFields);
              final left = _DarkCard(
                title: 'Готовность команды',
                subtitle: '$connected/${_players.length} трекеров',
                child: Column(
                  children: [
                    _ReadinessRow(title: 'Игроки', text: _players.isEmpty ? 'Состав не загружен' : '${_players.length} игроков', ok: _players.isNotEmpty),
                    const SizedBox(height: 8),
                    _ReadinessRow(title: 'Трекеры', text: connected == 0 ? 'Подключите датчики' : '$connected подключено', ok: connected > 0),
                    const SizedBox(height: 8),
                    _ReadinessRow(title: 'Поле', text: readyFields == 0 ? 'Нужна калибровка' : '$readyFields готово', ok: readyFields > 0),
                    const SizedBox(height: 8),
                    _ReadinessRow(title: 'GPS', text: gpsReady ? 'Сигнал есть' : 'Ожидаем пакет', ok: gpsReady),
                    const Spacer(),
                    _DarkActionButton(
                      icon: Icons.sensors_rounded,
                      label: connected == 0 ? 'Подключить трекеры' : 'Управлять трекерами',
                      primary: connected == 0,
                      onTap: () => setState(() => _section = TrackerWorkspaceSection.devices),
                    ),
                    const SizedBox(height: 8),
                    _DarkActionButton(
                      icon: Icons.map_rounded,
                      label: readyFields == 0 ? 'Настроить поле' : 'Проверить поле',
                      onTap: () => setState(() => _section = TrackerWorkspaceSection.field),
                    ),
                  ],
                ),
              );

              final center = _DarkCard(
                title: 'Команда онлайн',
                subtitle: snapshot.connectionState == ConnectionState.waiting && dashboard == null ? 'загрузка' : '${rows.length} игроков в аналитике',
                child: rows.isEmpty
                    ? const _DarkEmpty(icon: Icons.groups_rounded, text: 'После подключения трекеров и запуска Live здесь появится таблица игроков.')
                    : ListView(
                        children: rows.take(12).map((p) {
                          return _DarkListTile(
                            icon: Icons.person_rounded,
                            avatarUrl: p.avatar,
                            initials: _playerInitials(p.playerName),
                            title: p.playerName,
                            subtitle: '${(p.distanceM / 1000).toStringAsFixed(2)} км · max ${p.maxSpeedKmh.toStringAsFixed(1)} км/ч · спринты ${p.sprintCount}',
                            trailing: 'анализ',
                            active: _selectedPlayer?.id == p.playerId,
                            onTap: () {
                              final matches = _players.where((x) => x.id == p.playerId).toList();
                              setState(() {
                                if (matches.isNotEmpty) _selectedPlayer = matches.first;
                                _section = TrackerWorkspaceSection.activity;
                              });
                            },
                          );
                        }).toList(),
                      ),
              );

              final right = _DarkCard(
                title: 'Рабочий сценарий',
                subtitle: 'как в Catapult',
                child: Column(
                  children: [
                    _ScenarioButton(step: '1', title: 'Подключить трекеры', text: 'Датчики и привязка к игрокам', icon: Icons.sensors_rounded, onTap: () => setState(() => _section = TrackerWorkspaceSection.devices)),
                    const SizedBox(height: 8),
                    _ScenarioButton(step: '2', title: 'Проверить поле', text: 'Калибровка A/B/C/D', icon: Icons.map_rounded, onTap: () => setState(() => _section = TrackerWorkspaceSection.field)),
                    const SizedBox(height: 8),
                    _ScenarioButton(step: '3', title: 'Начать Live', text: 'Поле, точки, зоны, сигналы', icon: Icons.play_arrow_rounded, onTap: () => setState(() => _section = TrackerWorkspaceSection.live)),
                    const SizedBox(height: 8),
                    _ScenarioButton(step: '4', title: 'Открыть отчёты', text: 'Сессии, таблицы, экспорт', icon: Icons.table_chart_rounded, onTap: () => setState(() => _section = TrackerWorkspaceSection.sessions)),
                    const Spacer(),
                    const _DarkHint(text: 'Главная показывает команду и готовность. Live — только рабочий мониторинг. Активность — графики игрока. Сессии — отчёты и экспорт.'),
                  ],
                ),
              );

              final content = compact
                  ? ListView(
                      children: [
                        SizedBox(height: 140, child: _DashboardKpiStrip(items: kpi)),
                        const SizedBox(height: 10),
                        SizedBox(height: 360, child: center),
                        const SizedBox(height: 10),
                        SizedBox(height: 310, child: left),
                        const SizedBox(height: 10),
                        SizedBox(height: 360, child: right),
                      ],
                    )
                  : Column(
                      children: [
                        SizedBox(height: 118, child: _DashboardKpiStrip(items: kpi)),
                        const SizedBox(height: 10),
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

  List<_DashboardKpiData> _dashboardKpis(Map<String, dynamic> summary, int analyticPlayers, int connected, int readyFields) {
    double d(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;
    int i(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
    return [
      _DashboardKpiData(icon: Icons.groups_rounded, title: 'Игроки онлайн', value: '$connected/${_players.length}', subtitle: 'трекеры'),
      _DashboardKpiData(icon: Icons.route_rounded, title: 'Дистанция', value: '${(d(summary['total_distance_m']) / 1000).toStringAsFixed(2)} км', subtitle: 'команда'),
      _DashboardKpiData(icon: Icons.speed_rounded, title: 'Макс. скорость', value: '${d(summary['max_speed_kmh']).toStringAsFixed(1)}', subtitle: 'км/ч'),
      _DashboardKpiData(icon: Icons.local_fire_department_rounded, title: 'Спринты', value: '${i(summary['sprint_count'])}', subtitle: 'команда'),
      _DashboardKpiData(icon: Icons.monitor_heart_rounded, title: 'Нагрузка', value: d(summary['avg_load_score']).toStringAsFixed(1), subtitle: 'средняя'),
      _DashboardKpiData(icon: Icons.map_rounded, title: 'Поля', value: '$readyFields/${_fields.length}', subtitle: 'калибровка'),
    ];
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
      scanningBluetooth: _scanning,
      onScanBluetooth: _scanning ? null : _scan,
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

  Widget _activity() {
    return TrackerPlayerActivityScreen(
      key: ValueKey('activity_${widget.clubId}_${widget.teamId}_${_selectedPlayer?.id ?? 0}_${_selectedField?.id ?? 0}'),
      teamId: widget.teamId,
      teamName: widget.teamName,
      rosterPlayers: _players,
      selectedPlayer: _selectedPlayer,
      fieldId: _selectedField?.id,
    );
  }

  Widget _sessions() {
    return _DarkPage(
      title: 'Отчёты / сессии',
      subtitle: 'календарь тренировок, расшифровка, PDF и Excel',
      icon: Icons.table_chart_rounded,
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        _DarkActionButton(icon: Icons.refresh_rounded, label: 'Обновить', onTap: () => setState(() {})),
        const SizedBox(width: 8),
        _DarkActionButton(
          icon: Icons.cloud_upload_rounded,
          label: _savingRecord ? 'Сохраняю...' : 'Сохранить GPS',
          primary: true,
          onTap: _savingRecord ? null : _saveRecordAsSession,
        ),
      ]),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 980;
          final sessionsList = _SessionsListPane(
            api: _api,
            teamId: widget.teamId,
            playerId: _selectedPlayer?.id,
            selectedSession: _selectedReportSession,
            onSelect: (session) => setState(() => _selectedReportSession = session),
            onProcess: (session) async {
              try {
                await _api.processSession(sessionId: session.id);
                _toast('Сессия', 'Обработка запущена');
                setState(() {});
              } catch (e) {
                _toast('Сессия', '$e');
              }
            },
          );
          final gpsRecords = _GpsRecordsPane(
            records: _records,
            selectedRecord: _selectedRecord,
            pointsCount: _points.length,
            onLoad: _loadGpsRecord,
          );
          final report = _SelectedTrainingReportPane(
            session: _selectedReportSession,
            teamId: widget.teamId,
            teamName: widget.teamName,
          );

          if (compact) {
            return Column(children: [
              SizedBox(height: 210, child: sessionsList),
              const SizedBox(height: 10),
              SizedBox(height: 150, child: gpsRecords),
              const SizedBox(height: 10),
              Expanded(child: report),
            ]);
          }

          return Row(children: [
            Expanded(flex: 3, child: sessionsList),
            const _WorkspacePaneDivider.vertical(),
            Expanded(flex: 3, child: gpsRecords),
            const _WorkspacePaneDivider.vertical(),
            Expanded(flex: 8, child: report),
          ]);
        },
      ),
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
        const _WorkspacePaneDivider.vertical(),
        Expanded(child: _DarkCard(
          title: 'Сохранённые трекеры',
          subtitle: '${_savedDevices.length} датчиков',
          child: _savedDevices.isEmpty
              ? const _DarkEmpty(icon: Icons.sensors_off_rounded, text: 'После подключения трекер появится здесь.')
              : ListView(children: _savedDevices.map((d) => _SavedDeviceDarkTile(device: d, players: _players, onBind: (p) => _bindSavedDevice(d, p))).toList()),
        )),
        const _WorkspacePaneDivider.vertical(),
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
    final labels = const ['A', 'B', 'C', 'D'];
    final nextIndex = _calibrationCorners.length >= 4 ? -1 : _calibrationCorners.length;
    final nextLabel = nextIndex < 0 ? 'готово' : labels[nextIndex];

    return _DarkPage(
      title: 'Калибровка поля',
      subtitle: 'создайте поле и пройдите углы GPS-трекером: A верхний левый → B верхний правый → C нижний правый → D нижний левый',
      icon: Icons.map_rounded,
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        _DarkActionButton(icon: Icons.add_rounded, label: 'Новое поле', onTap: _createNewFieldDraft),
        const SizedBox(width: 8),
        _DarkActionButton(
          icon: Icons.gps_fixed_rounded,
          label: nextIndex < 0 ? 'GPS готов' : 'GPS $nextLabel',
          primary: true,
          onTap: nextIndex < 0 ? null : _captureCalibrationPoint,
        ),
        const SizedBox(width: 8),
        _DarkActionButton(
          icon: Icons.restart_alt_rounded,
          label: 'Сбросить',
          onTap: _calibrationCorners.isEmpty ? null : _resetCalibrationCorners,
        ),
        const SizedBox(width: 8),
        _DarkActionButton(icon: Icons.save_rounded, label: 'Сохранить', onTap: _calibrationCorners.length >= 4 ? _saveCapturedField : null),
      ]),
      child: Row(children: [
        Expanded(
          flex: 4,
          child: _DarkCard(
            title: 'Поля команды',
            subtitle: '${_fields.length} полей',
            child: ListView(children: [
              _DarkActionButton(icon: Icons.add_rounded, label: 'Новое поле', onTap: _createNewFieldDraft),
              const SizedBox(height: 10),
              if (_selectedField?.id == null && _selectedField != null)
                _DarkListTile(
                  icon: Icons.add_location_alt_rounded,
                  title: _selectedField!.title,
                  subtitle: '${_selectedField!.lengthM.toStringAsFixed(0)}×${_selectedField!.widthM.toStringAsFixed(0)} м · черновик, нужны 4 точки',
                  active: true,
                  trailing: 'новое',
                  onTap: () {},
                ),
              if (_fields.isEmpty && _selectedField == null)
                const _DarkEmpty(icon: Icons.map_rounded, text: 'Нажмите «Новое поле», затем поставьте 4 угла GPS-трекером.'),
              ..._fields.map((f) => _DarkListTile(
                    icon: f.hasCalibration ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                    title: f.title,
                    subtitle: '${f.lengthM.toStringAsFixed(0)}×${f.widthM.toStringAsFixed(0)} м · ${f.hasCalibration ? 'откалибровано' : 'нужна калибровка'}',
                    active: _selectedField?.id == f.id,
                    trailing: _selectedField?.id == f.id ? 'выбрано' : 'выбрать',
                    onTap: () => setState(() {
                      _selectedField = f;
                      _calibrationCorners.clear();
                    }),
                  )),
            ]),
          ),
        ),
        const _WorkspacePaneDivider.vertical(),
        Expanded(
          flex: 8,
          child: _DarkCard(
            title: 'Калибровка по 4 точкам',
            subtitle: nextIndex < 0 ? 'все точки получены' : 'следующая точка: $nextLabel',
            child: Column(children: [
              _CalibrationStatusBanner(
                nextLabel: nextLabel,
                done: nextIndex < 0,
                pointCount: _calibrationCorners.length,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: CustomPaint(
                  painter: _DarkCalibrationPainter(corners: _calibrationCorners, activeIndex: nextIndex),
                  child: const SizedBox.expand(),
                ),
              ),
              const SizedBox(height: 8),
              _DarkHint(
                text: _points.isEmpty
                    ? 'GPS-точек пока нет. Подключите трекер, выйдите на поле и дождитесь координат.'
                    : 'Последняя GPS-точка готова. Нажмите ${nextIndex < 0 ? '«Сохранить»' : '«GPS $nextLabel»'}.',
              ),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: List.generate(4, (i) {
                final ready = _calibrationCorners.length > i;
                final active = !ready && i == _calibrationCorners.length && _calibrationCorners.length < 4;
                return _DarkCornerChip(
                  label: labels[i],
                  value: ready
                      ? '${_calibrationCorners[i].latitude.toStringAsFixed(6)}\n${_calibrationCorners[i].longitude.toStringAsFixed(6)}'
                      : active
                          ? 'ожидает GPS'
                          : 'после предыдущей',
                  ready: ready,
                  active: active,
                  onTap: () => _handleCornerTap(i),
                );
              })),
            ]),
          ),
        ),
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
            const _WorkspacePaneDivider.vertical(),
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
        Expanded(flex: 8, child: _DarkCard(title: 'BLE-логи', subtitle: '${_logs.length} lines', child: _logs.isEmpty ? const _DarkEmpty(icon: Icons.terminal_rounded, text: 'Логи появятся после поиска, подключения и Live.') : ListView.builder(itemCount: _logs.length, itemBuilder: (_, i) => Padding(padding: const EdgeInsets.only(bottom: 5), child: Text(_logs[i], style: const TextStyle(color: _TD.muted, fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.w500)))))),
        const _WorkspacePaneDivider.vertical(),
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


class _SessionsListPane extends StatelessWidget {
  const _SessionsListPane({
    required this.api,
    required this.teamId,
    required this.playerId,
    required this.selectedSession,
    required this.onSelect,
    required this.onProcess,
  });

  final TrackerProApi api;
  final int teamId;
  final int? playerId;
  final TrackerSessionModel? selectedSession;
  final ValueChanged<TrackerSessionModel> onSelect;
  final ValueChanged<TrackerSessionModel> onProcess;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<TrackerSessionModel>>(
      future: api.loadSessions(teamId: teamId, playerId: playerId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && snapshot.data == null) {
          return const _DarkCard(title: 'Сессии', subtitle: 'загрузка', child: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return _DarkCard(
            title: 'Сессии',
            subtitle: 'ошибка',
            child: _DarkError(error: '${snapshot.error}', onRetry: () {}),
          );
        }
        final sessions = snapshot.data ?? const <TrackerSessionModel>[];
        return _DarkCard(
          title: 'Сессии',
          subtitle: '${sessions.length} тренировок',
          child: sessions.isEmpty
              ? const _DarkEmpty(icon: Icons.storage_rounded, text: 'Сессии появятся после Live или сохранения GPS-записи.')
              : ListView.builder(
                  itemCount: sessions.length,
                  itemBuilder: (context, index) {
                    final s = sessions[index];
                    final active = selectedSession?.id == s.id || (selectedSession == null && index == 0);
                    return _DarkListTile(
                      icon: Icons.assignment_rounded,
                      title: s.title,
                      subtitle: '${s.playerName ?? 'Команда'} · ${s.createdAt} · ${(s.distanceM / 1000).toStringAsFixed(2)} км · max ${s.maxSpeedKmh.toStringAsFixed(1)}',
                      active: active,
                      trailing: active ? 'отчёт' : 'открыть',
                      onTap: () => onSelect(s),
                    );
                  },
                ),
        );
      },
    );
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
      subtitle: selectedRecord == null ? '${records.length} записей' : 'Record ${selectedRecord!.fileId} · $pointsCount точек',
      child: records.isEmpty
          ? const _DarkEmpty(icon: Icons.download_rounded, text: 'Подключите трекер и загрузите записи.')
          : ListView(
              children: records
                  .map((r) => _DarkListTile(
                        icon: Icons.route_rounded,
                        title: 'Record ${r.fileId}',
                        subtitle: '${r.length} bytes${selectedRecord?.fileId == r.fileId ? ' · $pointsCount точек' : ''}',
                        active: selectedRecord?.fileId == r.fileId,
                        trailing: selectedRecord?.fileId == r.fileId ? 'выбрано' : 'загрузить',
                        onTap: () => onLoad(r),
                      ))
                  .toList(),
            ),
    );
  }
}

class _SelectedTrainingReportPane extends StatelessWidget {
  const _SelectedTrainingReportPane({
    required this.session,
    required this.teamId,
    required this.teamName,
  });

  final TrackerSessionModel? session;
  final int teamId;
  final String teamName;

  @override
  Widget build(BuildContext context) {
    final s = session;
    if (s == null) {
      return const _DarkCard(
        title: 'Отчёт тренировки',
        subtitle: 'выберите сессию слева',
        child: _DarkEmpty(icon: Icons.analytics_rounded, text: 'Выберите тренировку в списке «Сессии», чтобы открыть сводку, локомоторную, механическую и внутреннюю нагрузку.'),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: TrackerTrainingReportScreen(
        key: ValueKey('training_report_${s.id}'),
        sessionId: s.id,
        teamId: teamId,
        teamName: teamName,
        embedded: true,
      ),
    );
  }
}

class _TD {
  // Та же светлая CMR / Windows 11 схема, что в CMR Team Matches.
  static const bg = Color(0xFFF6F7F9);
  static const rail = Color(0xFFFFFFFF);
  static const panel = Color(0xFFFFFFFF);
  static const glass = Color(0xF8FFFFFF);
  static const card = Color(0xFFFFFFFF);
  static const card2 = Color(0xFFFAFBFC);
  static const soft = Color(0xFFF6F7F9);
  static const soft2 = Color(0xFFF5F7FB);
  static const border = Color(0xFFF0F2F4);
  static const borderStrong = Color(0xFFE5E7EB);
  static const softLine = Color(0xFFF0F2F4);
  static const grid = Color(0xFFD8DEE6);

  static const text = Color(0xFF0B0F14);
  static const graphite = Color(0xFF344054);
  static const graphiteSoft = Color(0xFF475467);
  static const muted = Color(0xFF374151);
  static const dim = Color(0xFF6B7280);

  static const green = Color(0xFF00A750);
  static const greenDark = Color(0xFF067A46);
  static const greenSoft = Color(0xFFF3FBF7);
  static const greenBorder = Color(0xFFDCEFE5);
  static const yellow = Color(0xFFF59E0B);
  static const orange = Color(0xFFF59E0B);
  static const red = Color(0xFFDC2626);
  static const redSoft = Color(0xFFFEF2F2);
  static const blue = Color(0xFF2563EB);
  static const blueSoft = Color(0xFFF4F7FF);
  static const cyan = Color(0xFF06B6D4);
  static const violet = Color(0xFF7C3AED);

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

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(.025),
          blurRadius: 14,
          spreadRadius: -10,
          offset: const Offset(0, 8),
        ),
      ];

  static BoxDecoration programWindowDecoration({double radius = 22}) => BoxDecoration(
        color: glass,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withOpacity(.86), width: 1),
        boxShadow: windowShadow,
      );

  static BoxDecoration unifiedWindow({double radius = 20}) => BoxDecoration(
        color: glass,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withOpacity(.86), width: 1),
        boxShadow: windowShadow,
      );


  static BoxDecoration workspaceBg() => const BoxDecoration(
        color: bg,
      );

  static BoxDecoration seamlessPane({double radius = 0}) => BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
      );

  static BoxDecoration softSurface({double radius = 12, bool active = false}) => BoxDecoration(
        color: active ? Colors.white.withOpacity(.96) : card2,
        borderRadius: BorderRadius.circular(radius),
        border: active ? Border.all(color: greenBorder, width: 1) : null,
      );
}


extension _SectionExt on TrackerWorkspaceSection {
  String get title => switch (this) {
        TrackerWorkspaceSection.dashboard => 'Главная',
        TrackerWorkspaceSection.live => 'Live',
        TrackerWorkspaceSection.activity => 'Игроки',
        TrackerWorkspaceSection.sessions => 'Отчёты',
        TrackerWorkspaceSection.devices => 'Трекеры',
        TrackerWorkspaceSection.field => 'Поле',
        TrackerWorkspaceSection.settings => 'Пороги',
        TrackerWorkspaceSection.debug => 'Диагн.',
      };

  IconData get icon => switch (this) {
        TrackerWorkspaceSection.dashboard => Icons.dashboard_customize_rounded,
        TrackerWorkspaceSection.live => Icons.radio_button_checked_rounded,
        TrackerWorkspaceSection.activity => Icons.monitor_heart_rounded,
        TrackerWorkspaceSection.sessions => Icons.table_chart_rounded,
        TrackerWorkspaceSection.devices => Icons.sensors_rounded,
        TrackerWorkspaceSection.field => Icons.map_rounded,
        TrackerWorkspaceSection.settings => Icons.tune_rounded,
        TrackerWorkspaceSection.debug => Icons.bug_report_rounded,
      };
}


class _TrackerProgramCollapsedBar extends StatelessWidget {
  const _TrackerProgramCollapsedBar({
    required this.clubName,
    required this.teamName,
    required this.liveRunning,
    required this.connected,
    required this.onRestore,
  });

  final String clubName;
  final String teamName;
  final bool liveRunning;
  final bool connected;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        height: 64,
        margin: const EdgeInsets.all(10),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: _TD.panel,
          borderRadius: BorderRadius.circular(18),
          boxShadow: _TD.windowShadow,
        ),
        child: Row(
          children: [
            _MacWindowControls(
              maximized: false,
              onClose: onRestore,
              onMinimize: onRestore,
              onToggleMaximize: onRestore,
            ),
            const SizedBox(width: 8),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _TD.card2,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.sensors_rounded, color: _TD.dim, size: 19),
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
                    style: TextStyle(color: _TD.text, fontSize: 10.8, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$clubName · $teamName',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _TD.muted, fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            _TrackerStatusDot(
              color: liveRunning ? _TD.green : _TD.dim,
              label: liveRunning ? 'LIVE' : (connected ? 'READY' : 'OFF'),
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


class _TrackerProgramSidePanel extends StatelessWidget {
  const _TrackerProgramSidePanel({
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
    required this.onMinimize,
    this.onToggleCollapsed,
  });

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
  final VoidCallback onMinimize;
  final VoidCallback? onToggleCollapsed;

  @override
  Widget build(BuildContext context) {
    final sections = TrackerWorkspaceSection.values;

    if (compact) {
      return Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        child: Column(
          children: [
            _TrackerSideIconButton(
              icon: Icons.sensors_rounded,
              active: liveRunning,
              tooltip: liveRunning ? 'Live идёт' : (connected ? 'Трекер готов' : 'Трекер выключен'),
              onTap: onRefresh,
            ),
            if (onToggleCollapsed != null) ...[
              const SizedBox(height: 8),
              _TrackerSideIconButton(
                icon: Icons.keyboard_double_arrow_right_rounded,
                active: false,
                tooltip: 'Развернуть меню',
                onTap: onToggleCollapsed,
              ),
            ],
            const SizedBox(height: 10),
            Container(height: 1, color: _TD.softLine),
            const SizedBox(height: 10),
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
                    tooltip: section.title,
                    onTap: () => onSelect(section),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            _TrackerSideIconButton(
              icon: loading ? Icons.hourglass_top_rounded : Icons.refresh_rounded,
              active: false,
              tooltip: 'Обновить',
              onTap: loading ? null : onRefresh,
            ),
          ],
        ),
      );
    }

    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.fromLTRB(9, 12, 8, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F5F8),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Stack(
                  children: [
                    const Center(child: Icon(Icons.sensors_rounded, color: _TD.dim, size: 20)),
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
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Flexible(
                          child: Text(
                            'Трекер',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: _TD.text, fontSize: 15.5, fontWeight: FontWeight.w700, letterSpacing: -.45),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _TrackerStatusDot(
                          color: liveRunning ? _TD.green : _TD.dim,
                          label: liveRunning ? 'LIVE' : (connected ? 'READY' : 'OFF'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      teamName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _TD.muted, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              _TrackerSmallGhostButton(
                icon: loading ? Icons.hourglass_top_rounded : Icons.refresh_rounded,
                onTap: loading ? null : onRefresh,
                tooltip: 'Обновить',
              ),
              if (onToggleCollapsed != null) ...[
                const SizedBox(width: 6),
                _TrackerSmallGhostButton(
                  icon: Icons.keyboard_double_arrow_left_rounded,
                  onTap: onToggleCollapsed,
                  tooltip: 'Сузить меню',
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            clubName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _TD.muted, fontSize: 10.8, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 3),
          Text(
            selectedPlayer,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _TD.dim, fontSize: 10.5, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
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
  const _TrackerSideNavItem({required this.section, required this.active, required this.onTap});

  final TrackerWorkspaceSection section;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? _TD.greenSoft : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: active ? Border.all(color: _TD.green.withOpacity(.16), width: 1) : null,
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
                    fontSize: 10.8,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                    letterSpacing: -.12,
                  ),
                ),
              ),
              if (active)
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(color: _TD.green, shape: BoxShape.circle),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackerSideIconButton extends StatelessWidget {
  const _TrackerSideIconButton({required this.icon, required this.active, required this.tooltip, this.onTap});

  final IconData icon;
  final bool active;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active ? _TD.greenSoft : _TD.soft,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: active ? Border.all(color: _TD.green.withOpacity(.16)) : null,
            ),
            child: Icon(icon, color: active ? _TD.green : _TD.dim, size: 18),
          ),
        ),
      ),
    );
  }
}

class _TrackerSmallGhostButton extends StatelessWidget {
  const _TrackerSmallGhostButton({required this.icon, required this.onTap, required this.tooltip});

  final IconData icon;
  final VoidCallback? onTap;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: _TD.soft,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 34,
            height: 34,
            child: Icon(icon, color: _TD.dim, size: 18),
          ),
        ),
      ),
    );
  }
}

class _TrackerSideFooterAction extends StatelessWidget {
  const _TrackerSideFooterAction({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _TD.soft,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: _TD.dim, size: 16),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: _TD.graphite, fontSize: 10.8, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackerWindowCornerButton extends StatelessWidget {
  const _TrackerWindowCornerButton({required this.maximized, required this.onTap});

  final bool maximized;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: maximized ? 'Свернуть окно' : 'Развернуть окно',
      child: Material(
        color: const Color(0xFFF3F5F8),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _TD.softLine),
              boxShadow: _TD.cardShadow,
            ),
            child: Icon(maximized ? Icons.close_fullscreen_rounded : Icons.open_in_full_rounded, size: 15, color: _TD.dim),
          ),
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
        border: Border(bottom: BorderSide(color: _TD.softLine.withOpacity(.88), width: 1)),
      ),
      child: Row(
        children: [
          Container(
            width: compact ? 34 : 38,
            height: compact ? 34 : 38,
            decoration: BoxDecoration(
              color: _TD.card2,
              borderRadius: BorderRadius.circular(14),
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
                      label: liveRunning ? 'LIVE' : (connected ? 'READY' : 'OFF'),
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
                    fontSize: 10.5,
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
                  children: TrackerWorkspaceSection.values.map((section) {
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
          const SizedBox(width: 8),
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
          icon: maximized ? Icons.close_fullscreen_rounded : Icons.open_in_full_rounded,
          tooltip: maximized ? 'Вернуть размер' : 'Развернуть',
          onTap: onToggleMaximize,
        ),
      ],
    );
  }
}

class _MacWindowButton extends StatefulWidget {
  const _MacWindowButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  State<_MacWindowButton> createState() => _MacWindowButtonState();
}

class _MacWindowButtonState extends State<_MacWindowButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 450),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Material(
          color: _hovered ? const Color(0xFFE9EDF2) : const Color(0xFFF3F5F8),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: widget.onTap,
            child: SizedBox(
              width: 22,
              height: 22,
              child: Icon(widget.icon, size: 12, color: _TD.dim),
            ),
          ),
        ),
      ),
    );
  }
}

class _TrackerProgramTab extends StatefulWidget {
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
  State<_TrackerProgramTab> createState() => _TrackerProgramTabState();
}

class _TrackerProgramTabState extends State<_TrackerProgramTab> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    final bg = active ? Colors.white.withOpacity(.92) : (_hovered ? _TD.soft : Colors.transparent);
    final fg = active ? _TD.text : _TD.graphiteSoft;
    final iconColor = active ? _TD.green : _TD.dim;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: widget.compact ? 34 : 36,
        constraints: BoxConstraints(minWidth: widget.compact ? 42 : 82),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(13),
          border: active ? Border.all(color: _TD.greenBorder) : Border.all(color: Colors.transparent),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(13),
            onTap: widget.onTap,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: widget.compact ? 10 : 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(widget.section.icon, size: 18, color: iconColor),
                  if (!widget.compact) ...[
                    const SizedBox(width: 7),
                    Text(
                      widget.section.title,
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
        borderRadius: BorderRadius.circular(99),
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
              fontSize: 9,
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
    return Tooltip(
      message: tooltip,
      child: Material(
        color: _TD.card2,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
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
    final items = TrackerWorkspaceSection.values;
    return Container(
      width: 72,
      padding: const EdgeInsets.fromLTRB(6, 6, 4, 6),
      child: Container(
        decoration: BoxDecoration(
          color: _TD.rail,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.045),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 5),
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
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: SizedBox(height: 10),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
              child: _RailButton(
                icon: Icons.arrow_back_rounded,
                label: 'Назад',
                active: false,
                onTap: onBack,
              ),
            ),
          ],
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
    final bg = widget.active ? _TD.green.withOpacity(.10) : Colors.transparent;
    final fg = widget.active ? _TD.green : _TD.text;
    final subFg = widget.active ? _TD.green : _TD.muted;
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
              height: 50,
              padding: const EdgeInsets.fromLTRB(4, 5, 4, 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(widget.icon, color: fg, size: 18),
                        const SizedBox(height: 4),
                        Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: subFg,
                            fontSize: 8.3,
                            fontWeight: FontWeight.w500,
                            letterSpacing: -.15,
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
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.teamName, required this.clubName, required this.selectedPlayer, required this.selectedSection, required this.loading, required this.onRefresh});
  final String teamName;
  final String clubName;
  final String selectedPlayer;
  final TrackerWorkspaceSection selectedSection;
  final bool loading;
  final VoidCallback onRefresh;
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      margin: const EdgeInsets.fromLTRB(0, 8, 8, 0),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: const BoxDecoration(color: Colors.transparent, border: Border(bottom: BorderSide(color: _TD.softLine))),
      child: Row(children: [
        Container(width: 34, height: 34, decoration: _TD.softSurface(radius: 12), child: Icon(selectedSection.icon, color: _TD.dim, size: 18)),
        const SizedBox(width: 10),
        Expanded(child: Text('Спортотека Трекинг · ${selectedSection.title}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _TD.text, fontWeight: FontWeight.w500, fontSize: 12.5))),
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
      decoration: _TD.softSurface(radius: 12),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(color: _TD.dim, fontSize: 8.5, fontWeight: FontWeight.w500)),
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _TD.text, fontSize: 11, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

class _WorkspacePaneDivider extends StatelessWidget {
  const _WorkspacePaneDivider.vertical({this.thickness = 1, this.padding = 0}) : axis = Axis.vertical;
  const _WorkspacePaneDivider.horizontal({this.thickness = 1, this.padding = 0}) : axis = Axis.horizontal;

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
    // уже является общей рамкой. Здесь только плоская рабочая область и
    // тонкие разделители, как в CMR Trainers / CMR Team Matches.
    final hasToolbar = title.trim().isNotEmpty || trailing != null;

    return Container(
      color: Colors.transparent,
      child: Column(
        children: [
          if (hasToolbar) ...[
            _WorkspaceFlatHeader(
              icon: icon,
              title: title,
              subtitle: subtitle,
              trailing: trailing,
            ),
            const _WorkspacePaneDivider.horizontal(),
          ],
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
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      color: Colors.transparent,
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _TD.greenSoft,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _TD.green.withOpacity(.12)),
            ),
            child: Icon(icon, color: _TD.green, size: 17),
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
                    fontSize: 12.2,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.28,
                  ),
                ),
                if (subtitle.trim().isNotEmpty)
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _TD.muted,
                      fontSize: 9.4,
                      fontWeight: FontWeight.w600,
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
      decoration: _TD.seamlessPane(),
      child: Column(
        children: [
          if (hasHeader) ...[
            Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              color: Colors.transparent,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _TD.text,
                        fontSize: 11.8,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -.18,
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
                          color: _TD.dim,
                          fontSize: 9.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const _WorkspacePaneDivider.horizontal(),
          ],
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
          color: widget.primary ? _TD.greenSoft : _TD.soft,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 11),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(widget.icon, color: widget.primary ? _TD.green : _TD.graphite, size: 16),
                const SizedBox(width: 6),
                Text(widget.label, style: TextStyle(color: widget.primary ? _TD.green : _TD.graphite, fontSize: 10.5, fontWeight: FontWeight.w500)),
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
      decoration: _TD.softSurface(radius: 12),
      padding: const EdgeInsets.all(10),
      child: Row(children: [
        Icon(icon, color: _TD.graphite),
        const SizedBox(width: 9),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _TD.muted, fontSize: 10, fontWeight: FontWeight.w500)),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _TD.text, fontSize: 10.8, fontWeight: FontWeight.w500)),
          Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _TD.dim, fontSize: 9, fontWeight: FontWeight.w500)),
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
      decoration: BoxDecoration(
        color: active ? _TD.greenSoft : _TD.soft,
        borderRadius: BorderRadius.circular(12),
        border: active ? Border.all(color: _TD.greenBorder) : null,
      ),
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
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _TD.text, fontWeight: FontWeight.w500)),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _TD.muted, fontSize: 11, fontWeight: FontWeight.w500)),
        trailing: trailing == null ? null : Text(trailing!, style: TextStyle(color: color, fontWeight: FontWeight.w500, fontSize: 11)),
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
      decoration: _TD.softSurface(radius: 12),
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
                  Text(device.deviceName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _TD.text, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 3),
                  Text(
                    '${device.deviceUuid}${boundPlayer == null && device.playerName == null ? '' : ' · ${boundPlayer?.name ?? device.playerName}'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _TD.muted, fontSize: 11, fontWeight: FontWeight.w500),
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
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: BorderSide.none),
          ),
          style: const TextStyle(color: _TD.text, fontWeight: FontWeight.w500),
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
  const _DashboardKpiData({required this.icon, required this.title, required this.value, required this.subtitle});
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
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(width: 10),
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          width: 176,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _TD.card,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(color: _TD.green.withOpacity(.10), borderRadius: BorderRadius.circular(9)),
                    child: Icon(item.icon, color: _TD.graphite, size: 18),
                  ),
                  const Spacer(),
                  Text(item.subtitle, style: const TextStyle(color: _TD.dim, fontSize: 9.5, fontWeight: FontWeight.w500)),
                ],
              ),
              const Spacer(),
              Text(item.value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _TD.text, fontSize: 15, fontWeight: FontWeight.w500, letterSpacing: -.4)),
              const SizedBox(height: 2),
              Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _TD.muted, fontSize: 11, fontWeight: FontWeight.w500)),
            ],
          ),
        );
      },
    );
  }
}

class _ReadinessRow extends StatelessWidget {
  const _ReadinessRow({required this.title, required this.text, required this.ok});
  final String title;
  final String text;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: ok ? _TD.green.withOpacity(.08) : _TD.card2, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Icon(ok ? Icons.check_circle_rounded : Icons.warning_amber_rounded, color: ok ? _TD.green : _TD.orange, size: 19),
          const SizedBox(width: 9),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _TD.text, fontWeight: FontWeight.w500, fontSize: 12)),
              Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _TD.muted, fontWeight: FontWeight.w500, fontSize: 10.5)),
            ]),
          ),
        ],
      ),
    );
  }
}

class _ScenarioButton extends StatelessWidget {
  const _ScenarioButton({required this.step, required this.title, required this.text, required this.icon, required this.onTap});
  final String step;
  final String title;
  final String text;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _TD.card2,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              CircleAvatar(radius: 15, backgroundColor: _TD.green.withOpacity(.12), child: Text(step, style: const TextStyle(color: _TD.green, fontSize: 11, fontWeight: FontWeight.w500))),
              const SizedBox(width: 10),
              Icon(icon, color: _TD.graphite, size: 18),
              const SizedBox(width: 9),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _TD.text, fontWeight: FontWeight.w500, fontSize: 11.8)),
                  Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _TD.muted, fontWeight: FontWeight.w500, fontSize: 10.2)),
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
    return Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 360), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, size: 38, color: _TD.dim),
      const SizedBox(height: 10),
      Text(text, textAlign: TextAlign.center, style: const TextStyle(color: _TD.muted, fontWeight: FontWeight.w500)),
    ])));
  }
}

class _DarkError extends StatelessWidget {
  const _DarkError({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Center(child: Container(constraints: const BoxConstraints(maxWidth: 560), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Color(0xFFFFF1F1), borderRadius: BorderRadius.circular(10)), child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.warning_amber_rounded, color: _TD.red),
      const SizedBox(height: 8),
      Text(error, textAlign: TextAlign.center, style: const TextStyle(color: _TD.red, fontWeight: FontWeight.w500)),
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
    return Container(padding: const EdgeInsets.all(12), decoration: _TD.softSurface(radius: 12), child: Text(text, style: const TextStyle(color: _TD.graphiteSoft, fontWeight: FontWeight.w500, fontSize: 11.2, height: 1.25)));
  }
}

class _DarkCornerChip extends StatelessWidget {
  const _DarkCornerChip({
    required this.label,
    required this.value,
    required this.ready,
    this.active = false,
    this.onTap,
  });

  final String label;
  final String value;
  final bool ready;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = ready ? _TD.green : active ? const Color(0xFF2563EB) : _TD.dim;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
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
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: color,
            child: ready
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 15)
                : Text(label, style: const TextStyle(color: _TD.bg, fontSize: 11, fontWeight: FontWeight.w500)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(value, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _TD.muted, fontSize: 10, fontWeight: FontWeight.w500))),
        ]),
      ),
    );
  }
}

class _CalibrationStatusBanner extends StatelessWidget {
  const _CalibrationStatusBanner({
    required this.nextLabel,
    required this.done,
    required this.pointCount,
  });

  final String nextLabel;
  final bool done;
  final int pointCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: done ? _TD.green.withOpacity(.10) : const Color(0xFF2563EB).withOpacity(.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(done ? Icons.check_circle_rounded : Icons.gps_fixed_rounded, color: done ? _TD.green : const Color(0xFF2563EB)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              done
                  ? 'Все 4 угла получены. Нажмите «Сохранить».'
                  : 'Следующий угол: $nextLabel · перейдите в угол поля и нажмите GPS $nextLabel',
              style: TextStyle(
                color: done ? _TD.green : _TD.text,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ),
          Text('$pointCount/4', style: const TextStyle(color: _TD.muted, fontWeight: FontWeight.w500)),
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
    final tp = TextPainter(text: TextSpan(text: text, style: const TextStyle(color: _TD.muted, fontSize: 10.8, fontWeight: FontWeight.w500)), textDirection: TextDirection.ltr)..layout(maxWidth: size.width - 40);
    tp.paint(canvas, Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2));
  }

  @override
  bool shouldRepaint(covariant _DarkHeatmapPainter oldDelegate) => true;
}

class _DarkCalibrationPainter extends CustomPainter {
  const _DarkCalibrationPainter({required this.corners, this.activeIndex = -1});

  final List<ActionTrackerGpsPoint> corners;
  final int activeIndex;

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
      final color = ready ? _TD.green : active ? const Color(0xFF2563EB) : _TD.dim;
      canvas.drawCircle(p, active ? 19 : 16, Paint()..color = color);
      if (ready) {
        final check = TextPainter(
          text: const TextSpan(text: '✓', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 12.5)),
          textDirection: TextDirection.ltr,
        )..layout();
        check.paint(canvas, p - Offset(check.width / 2, check.height / 2));
      } else {
        final tp = TextPainter(
          text: TextSpan(text: ['A', 'B', 'C', 'D'][i], style: const TextStyle(color: _TD.bg, fontWeight: FontWeight.w500)),
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
    canvas.drawLine(Offset(30, y), Offset(size.width - 30, y), Paint()..color = _TD.border..strokeWidth = 2);
    for (var i = 0; i <= 8; i++) {
      final x = 30 + (size.width - 60) * i / 8;
      canvas.drawCircle(Offset(x, y), 5, Paint()..color = i.isEven ? _TD.green : _TD.orange);
      final tp = TextPainter(text: TextSpan(text: '${i * 15}’', style: const TextStyle(color: _TD.muted, fontSize: 10, fontWeight: FontWeight.w500)), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, y + 14));
    }
  }
  @override
  bool shouldRepaint(covariant _DarkTimelinePainter oldDelegate) => false;
}
