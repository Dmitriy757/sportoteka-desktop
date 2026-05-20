import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';
import 'models/tracking_models.dart';
import 'services/tracking_ble_service.dart';

const String _apiBaseUrl = 'https://sportotekaapp.ru/api/';

class TrackingDeviceSetupScreen extends StatefulWidget {
  final TrackingMode mode;

  const TrackingDeviceSetupScreen({
    super.key,
    required this.mode,
  });

  @override
  State<TrackingDeviceSetupScreen> createState() =>
      _TrackingDeviceSetupScreenState();
}

class _TrackingDeviceSetupScreenState extends State<TrackingDeviceSetupScreen> {
  static const Color primary = Color(0xFF00A750);
  static const Color primaryDark = Color(0xFF008C40);
  static const Color bg = Color(0xFFF4F7F6);
  static const Color card = Colors.white;
  static const Color text = Color(0xFF102027);
  static const Color muted = Color(0xFF6B7280);
  static const Color border = Color(0xFFE5E7EB);

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: _apiBaseUrl,
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 12),
    ),
  );

  final TrackingBleService _ble = TrackingBleService.instance;
  StreamSubscription<List<TrackingDeviceModel>>? _devicesSub;

  SessionState _state = SessionState.idle;
  bool _loadingAthletes = true;
  bool _startingSession = false;

  int? _userId;
  String? _userRole;
  int? _selectedTeamId;
  TrackingAthleteModel? _selectedAthlete;

  List<Map<String, dynamic>> _teams = [];
  List<TrackingAthleteModel> _athletes = [];
  List<TrackingDeviceModel> _devices = [];
  List<AthleteDeviceBinding> _bindings = [];

  bool get _isCoachLike =>
      _userRole == 'coach' ||
      _userRole == 'trainer' ||
      _userRole == 'club';

  bool get _isPlayerLike =>
      _userRole == 'player' ||
      _userRole == 'athlete';

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _devicesSub?.cancel();
    _ble.stopScan();
    super.dispose();
  }

  Future<void> _init() async {
    _userId = await PrefUtils.getUserId();

  try {
  _userRole = await PrefUtils.getString('user_role');
  _userRole ??= await PrefUtils.getString('role');
} catch (_) {
  _userRole = null;
}
    _devicesSub = _ble.devicesStream.listen((items) async {
      if (!mounted) return;

      setState(() {
        _devices = items;
        if (_state == SessionState.scanning && items.isNotEmpty) {
          _state = SessionState.ready;
        }
      });

      if (_isCoachLike && _selectedTeamId != null && _bindings.isNotEmpty) {
        await _loadTeamBindings(_selectedTeamId!);
      } else if (!_isCoachLike && _selectedAthlete != null) {
        await _loadMyBindings();
      }
    });

    if (widget.mode == TrackingMode.team) {
      if (_isCoachLike) {
        await _loadMyCoachTeams();
      } else {
        await _loadMyPersonalTrackingContext();
        await _loadMyBindings();
      }
    } else {
      await _loadMyPersonalTrackingContext();
      await _loadMyBindings();
    }
  }

  Future<void> _loadMyCoachTeams() async {
    setState(() => _loadingAthletes = true);

    try {
      final res = await _dio.get(
        'get_my_teams.php',
        queryParameters: {
          'user_id': _userId,
        },
      );

      final teams = List<Map<String, dynamic>>.from(
        res.data['teams'] ?? const [],
      );

      _teams = teams;

      if (_teams.isNotEmpty) {
        _selectedTeamId = int.tryParse('${_teams.first['id']}');
        if (_selectedTeamId != null && _selectedTeamId! > 0) {
          await _loadPlayersByTeam(_selectedTeamId!);
          await _loadTeamBindings(_selectedTeamId!);
        }
      }
    } catch (e) {
      _showError('Не удалось загрузить мои команды: $e');
    } finally {
      if (mounted) {
        setState(() => _loadingAthletes = false);
      }
    }
  }

  Future<void> _loadPlayersByTeam(int teamId) async {
    setState(() {
      _loadingAthletes = true;
      _athletes = [];
      _bindings = [];
    });

    try {
      final res = await _dio.get(
        'get_players_by_team.php',
        queryParameters: {'team_id': teamId},
      );

      final raw = res.data is Map
          ? List<Map<String, dynamic>>.from(
              res.data['players'] ?? res.data['data'] ?? const [],
            )
          : <Map<String, dynamic>>[];

      final athletes = raw.map((m) {
        final first = (m['first_name'] ?? '').toString();
        final last = (m['last_name'] ?? '').toString();
        final fullName = ('$first $last').trim().isEmpty
            ? (m['name'] ?? 'Игрок').toString()
            : ('$first $last').trim();

        return TrackingAthleteModel(
          id: int.tryParse('${m['id']}') ?? 0,
          fullName: fullName,
          photo: (m['photo'] ?? m['photo_url'] ?? '').toString(),
          position: (m['position'] ?? '').toString(),
          number: int.tryParse('${m['number'] ?? ''}'),
        );
      }).where((e) => e.id > 0).toList();

      if (!mounted) return;

      setState(() {
        _athletes = athletes;
        _bindings = athletes
            .map(
              (e) => AthleteDeviceBinding(
                athleteId: e.id,
                athleteName: e.fullName,
              ),
            )
            .toList();
      });

      await _loadTeamBindings(teamId);
    } catch (e) {
      _showError('Не удалось загрузить игроков: $e');
    } finally {
      if (mounted) {
        setState(() => _loadingAthletes = false);
      }
    }
  }

  Future<void> _loadMyPersonalTrackingContext() async {
  setState(() => _loadingAthletes = true);

  try {
    final id = _userId ?? 0;

    final res = await _dio.get(
      'get_user.php',
      queryParameters: {'user_id': id},
    );

    final data = Map<String, dynamic>.from(res.data);

    final user = data['user'] is Map
        ? Map<String, dynamic>.from(data['user'])
        : data;

    final first = (user['first_name'] ?? '').toString();
    final last = (user['last_name'] ?? '').toString();
    final fallbackName = (user['full_name'] ?? user['name'] ?? '').toString();

    final fullName = ('$first $last').trim().isNotEmpty
        ? ('$first $last').trim()
        : (fallbackName.isNotEmpty ? fallbackName : 'Мой профиль');

    final athleteId =
        int.tryParse('${user['athlete_id'] ?? user['player_id'] ?? user['id'] ?? id}') ?? id;

    final athlete = TrackingAthleteModel(
      id: athleteId,
      fullName: fullName,
      photo: (user['photo'] ?? user['photo_url'] ?? user['avatar'] ?? '').toString(),
      position: (user['position'] ?? '').toString(),
      number: int.tryParse('${user['number'] ?? ''}'),
    );

    if (!mounted) return;

    setState(() {
      _selectedAthlete = athlete;
      _athletes = [athlete];
    });
  } catch (e) {
    _showError('Не удалось загрузить профиль спортсмена: $e');
  } finally {
    if (mounted) {
      setState(() => _loadingAthletes = false);
    }
  }
}

  Future<void> _loadTeamBindings(int teamId) async {
    try {
      final res = await _dio.get(
        'get_team_device_bindings.php',
        queryParameters: {
          'team_id': teamId,
          'user_id': _userId,
        },
      );

      final rawBindings = List<Map<String, dynamic>>.from(
        res.data['bindings'] ?? const [],
      );

      if (_athletes.isEmpty) return;

      final List<AthleteDeviceBinding> mapped = _athletes.map((athlete) {
        Map<String, dynamic>? row;
        try {
          row = rawBindings.firstWhere(
            (e) => e['athlete_id'].toString() == athlete.id.toString(),
          );
        } catch (_) {
          row = null;
        }

        return AthleteDeviceBinding(
          athleteId: athlete.id,
          athleteName: athlete.fullName,
          vestDevice: row == null
              ? null
              : _findDeviceById('${row['vest_device_id'] ?? ''}'),
          hrDevice: row == null
              ? null
              : _findDeviceById('${row['hr_device_id'] ?? ''}'),
        );
      }).toList();

      if (!mounted) return;

      setState(() {
        _bindings = mapped;
      });
    } catch (e) {
      debugPrint('Не удалось загрузить привязки команды: $e');
    }
  }

  Future<void> _loadMyBindings() async {
    try {
      final res = await _dio.get(
        'get_my_device_bindings.php',
        queryParameters: {
          'user_id': _userId,
        },
      );

      final rawBindings = List<Map<String, dynamic>>.from(
        res.data['bindings'] ?? const [],
      );

      if (_selectedAthlete == null) return;

      Map<String, dynamic>? my;
      try {
        my = rawBindings.firstWhere(
          (e) =>
              e['athlete_id'].toString() == _selectedAthlete!.id.toString() ||
              e['athlete_user_id'].toString() == (_userId?.toString() ?? ''),
        );
      } catch (_) {
        my = null;
      }

      if (!mounted) return;

      setState(() {
        _bindings = [
          AthleteDeviceBinding(
            athleteId: _selectedAthlete!.id,
            athleteName: _selectedAthlete!.fullName,
            vestDevice:
                my == null ? null : _findDeviceById('${my['vest_device_id'] ?? ''}'),
            hrDevice:
                my == null ? null : _findDeviceById('${my['hr_device_id'] ?? ''}'),
          ),
        ];
      });
    } catch (e) {
      debugPrint('Не удалось загрузить мои привязки: $e');
    }
  }

  TrackingDeviceModel? _findDeviceById(String id) {
    if (id.trim().isEmpty) return null;
    try {
      return _devices.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> _scanDevices() async {
    setState(() => _state = SessionState.scanning);
    try {
      await _ble.startScan();
    } catch (e) {
      setState(() => _state = SessionState.error);
      _showError('Ошибка поиска BLE-устройств: $e');
    }
  }

  Future<void> _connectToDevice(TrackingDeviceModel device) async {
    setState(() => _state = SessionState.connecting);
    await _ble.connect(device.id);
    if (mounted) {
      setState(() => _state = SessionState.ready);
    }
  }

  Future<void> _disconnectFromDevice(TrackingDeviceModel device) async {
    await _ble.disconnect(device.id);
    if (mounted) {
      setState(() => _state = SessionState.ready);
    }
  }

  void _bindDevice({
    required int athleteId,
    required bool isHr,
    required TrackingDeviceModel device,
  }) {
    final i = _bindings.indexWhere((e) => e.athleteId == athleteId);
    if (i == -1) return;

    setState(() {
      _bindings[i] = isHr
          ? _bindings[i].copyWith(hrDevice: device)
          : _bindings[i].copyWith(vestDevice: device);
    });
  }

  Future<void> _startTraining() async {
    if (_isCoachLike && widget.mode == TrackingMode.team) {
      final readyCount = _bindings.where((e) => e.isReady).length;
      if (readyCount == 0) {
        _showError('Сначала привяжи хотя бы одно устройство к игроку.');
        return;
      }
    } else {
      final hasConnected = _devices.any((e) => e.isConnected);
      if (!hasConnected) {
        _showError('Сначала подключи устройство.');
        return;
      }
    }

    setState(() => _startingSession = true);

    try {
      final payload = {
        'mode': widget.mode.name,
        'team_id': _selectedTeamId,
        'athlete_id': _selectedAthlete?.id,
        'user_id': _userId,
        'user_role': _userRole,
        'started_at': DateTime.now().toIso8601String(),
        'devices': _devices
            .where((e) => e.isConnected)
            .map((e) => {
                  'device_id': e.id,
                  'name': e.name,
                  'mac_address': e.macAddress,
                  'type': e.type.name,
                  'battery': e.batteryLevel,
                  'rssi': e.rssi,
                })
            .toList(),
        'bindings': _bindings
            .where((e) => e.isReady)
            .map((e) => {
                  'athlete_id': e.athleteId,
                  'athlete_name': e.athleteName,
                  'vest_device_id': e.vestDevice?.id,
                  'hr_device_id': e.hrDevice?.id,
                })
            .toList(),
      };

      await _dio.post('start_tracking_session.php', data: payload);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Сессия создана. Дальше можно открывать live-экран.'),
        ),
      );
    } catch (e) {
      _showError('Не удалось запустить тренировку: $e');
    } finally {
      if (mounted) {
        setState(() => _startingSession = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final connectedCount = _devices.where((e) => e.isConnected).length;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: bg,
        foregroundColor: text,
        title: Text(
          widget.mode == TrackingMode.team && _isCoachLike
              ? 'Командная тренировка'
              : 'Индивидуальная тренировка',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: ElevatedButton(
          onPressed: _startingSession ? null : _startTraining,
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: primary.withOpacity(0.5),
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: _startingSession
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text(
                  'Начать тренировку',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _statusCard(connectedCount),
          const SizedBox(height: 14),
          if (widget.mode == TrackingMode.team && _isCoachLike) _teamSelectorBlock(),
          if (widget.mode == TrackingMode.individual || !_isCoachLike)
            _individualBlock(),
          const SizedBox(height: 14),
          _scanBlock(),
          const SizedBox(height: 14),
          _devicesBlock(),
          const SizedBox(height: 14),
          if (widget.mode == TrackingMode.team && _isCoachLike) _bindingsBlock(),
          if ((widget.mode == TrackingMode.individual || !_isCoachLike) &&
              _bindings.isNotEmpty)
            _myBindingsBlock(),
        ],
      ),
    );
  }

  Widget _statusCard(int connectedCount) {
    final color = trackingStatusColor(_state);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(Icons.bluetooth_searching_rounded, color: color, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  trackingStatusText(_state),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: text,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Подключено устройств: $connectedCount',
                  style: const TextStyle(
                    fontSize: 13,
                    color: muted,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              trackingStatusText(_state),
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _teamSelectorBlock() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Команда и игроки',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: text,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: _selectedTeamId,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              labelText: 'Выбери команду',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
            items: _teams.map((team) {
              final id = int.tryParse('${team['id']}') ?? 0;
              final name = (team['name'] ?? 'Команда').toString();
              return DropdownMenuItem<int>(
                value: id,
                child: Text(name),
              );
            }).toList(),
            onChanged: (value) async {
              if (value == null) return;
              setState(() => _selectedTeamId = value);
              await _loadPlayersByTeam(value);
              await _loadTeamBindings(value);
            },
          ),
          const SizedBox(height: 14),
          if (_loadingAthletes)
            const Center(child: CircularProgressIndicator())
          else if (_athletes.isEmpty)
            const Text(
              'Игроки не найдены',
              style: TextStyle(color: muted),
            )
          else
            Text(
              'Игроков в команде: ${_athletes.length}',
              style: const TextStyle(
                color: muted,
                fontSize: 13,
              ),
            ),
        ],
      ),
    );
  }

  Widget _individualBlock() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
      ),
      child: _loadingAthletes
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Спортсмен',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: text,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: primary.withOpacity(0.12),
                      backgroundImage: (_selectedAthlete?.photo ?? '').isNotEmpty
                          ? NetworkImage(_selectedAthlete!.photo!)
                          : null,
                      child: (_selectedAthlete?.photo ?? '').isEmpty
                          ? const Icon(Icons.person_rounded, color: primary)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _selectedAthlete?.fullName ?? 'Профиль не найден',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: text,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _scanBlock() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _scanDevices,
              icon: const Icon(Icons.search_rounded),
              label: const Text(
                'Найти устройства',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: _ble.stopScan,
            style: OutlinedButton.styleFrom(
              foregroundColor: text,
              side: const BorderSide(color: border),
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Стоп',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _devicesBlock() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Найденные устройства',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: text,
            ),
          ),
          const SizedBox(height: 12),
          if (_devices.isEmpty)
            const Text(
              'Устройства пока не найдены. Нажми "Найти устройства".',
              style: TextStyle(color: muted, height: 1.45),
            )
          else
            ..._devices.map(_deviceTile),
        ],
      ),
    );
  }

  Widget _deviceTile(TrackingDeviceModel device) {
    final color = device.isConnected
        ? primary
        : (device.isConnecting ? const Color(0xFFF59E0B) : const Color(0xFF64748B));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  device.type == DeviceType.heartRateMonitor
                      ? Icons.favorite_rounded
                      : Icons.sensors_rounded,
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${deviceTypeTitle(device.type)} • RSSI ${device.rssi ?? '-'}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: muted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      device.macAddress,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (device.isConnecting)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (device.isConnected)
                ElevatedButton(
                  onPressed: () => _disconnectFromDevice(device),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEFFCF4),
                    foregroundColor: primaryDark,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Отключить'),
                )
              else
                ElevatedButton(
                  onPressed: () => _connectToDevice(device),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Подключить'),
                ),
            ],
          ),
          if (device.batteryLevel != null || device.serviceHint.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (device.batteryLevel != null) ...[
                  const Icon(Icons.battery_std_rounded, size: 16, color: muted),
                  const SizedBox(width: 6),
                  Text(
                    '${device.batteryLevel}%',
                    style: const TextStyle(fontSize: 12.5, color: muted),
                  ),
                ],
                if (device.batteryLevel != null && device.serviceHint.isNotEmpty)
                  const SizedBox(width: 12),
                if (device.serviceHint.isNotEmpty)
                  Expanded(
                    child: Text(
                      device.serviceHint,
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 12, color: muted),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _bindingsBlock() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Привязка устройств к игрокам',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: text,
            ),
          ),
          const SizedBox(height: 12),
          if (_bindings.isEmpty)
            const Text(
              'Сначала выбери команду и дождись загрузки игроков.',
              style: TextStyle(color: muted),
            )
          else
            ..._bindings.map(_bindingTile),
        ],
      ),
    );
  }

  Widget _bindingTile(AthleteDeviceBinding binding) {
    final connectedDevices = _devices.where((e) => e.isConnected).toList();
    final vestCandidates = connectedDevices.where((e) {
      return e.type == DeviceType.vestTracker ||
          e.type == DeviceType.gpsTracker ||
          e.type == DeviceType.unknown;
    }).toList();

    final hrCandidates = connectedDevices.where((e) {
      return e.type == DeviceType.heartRateMonitor || e.type == DeviceType.unknown;
    }).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: primary.withOpacity(0.12),
                child: Text(
                  binding.athleteName.isNotEmpty
                      ? binding.athleteName[0].toUpperCase()
                      : 'И',
                  style: const TextStyle(
                    color: primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  binding.athleteName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: binding.vestDevice?.id,
            decoration: InputDecoration(
              labelText: 'Трекер / жилет',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            items: [
              const DropdownMenuItem<String>(
                value: '',
                child: Text('Не назначено'),
              ),
              ...vestCandidates.map(
                (d) => DropdownMenuItem<String>(
                  value: d.id,
                  child: Text(d.name),
                ),
              ),
            ],
            onChanged: (value) {
              if (value == null || value.isEmpty) return;
              final device = vestCandidates.firstWhere((e) => e.id == value);
              _bindDevice(
                athleteId: binding.athleteId,
                isHr: false,
                device: device,
              );
            },
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: binding.hrDevice?.id,
            decoration: InputDecoration(
              labelText: 'Пульсометр',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
            items: [
              const DropdownMenuItem<String>(
                value: '',
                child: Text('Не назначено'),
              ),
              ...hrCandidates.map(
                (d) => DropdownMenuItem<String>(
                  value: d.id,
                  child: Text(d.name),
                ),
              ),
            ],
            onChanged: (value) {
              if (value == null || value.isEmpty) return;
              final device = hrCandidates.firstWhere((e) => e.id == value);
              _bindDevice(
                athleteId: binding.athleteId,
                isHr: true,
                device: device,
              );
            },
          ),
          if (binding.isReady) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: primary, size: 18),
                const SizedBox(width: 6),
                const Text(
                  'Устройства назначены',
                  style: TextStyle(
                    color: primaryDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _myBindingsBlock() {
    final binding = _bindings.isNotEmpty ? _bindings.first : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Мои привязки устройств',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: text,
            ),
          ),
          const SizedBox(height: 12),
          if (binding == null)
            const Text(
              'Устройства пока не привязаны.',
              style: TextStyle(color: muted),
            )
          else ...[
            _myBindingRow(
              title: 'Трекер',
              value: binding.vestDevice?.name ?? 'Не назначен',
            ),
            const SizedBox(height: 10),
            _myBindingRow(
              title: 'Пульсометр',
              value: binding.hrDevice?.name ?? 'Не назначен',
            ),
          ],
        ],
      ),
    );
  }

  Widget _myBindingRow({
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: text,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                color: muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showError(String textMessage) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(textMessage)),
    );
  }
}