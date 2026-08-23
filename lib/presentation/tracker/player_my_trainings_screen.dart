import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/action_tracker_protocol.dart';
import '../models/tracker_live_models.dart';
import '../models/tracker_pro_models.dart';
import '../services/action_tracker_ble_service.dart';
import '../services/player_personal_tracker_api.dart';
import '../services/player_personal_analytics_api.dart';
import '../services/polar_heart_rate_ble_service.dart';
import '../widgets/player_training_calendar_panel.dart';
import '../widgets/tracker_action_analytics_suite.dart';

enum _PlayerTrainingSection { live, analytics }

class PlayerMyTrainingsScreen extends StatefulWidget {
  const PlayerMyTrainingsScreen({
    super.key,
    required this.teamId,
    required this.teamName,
    required this.userId,
    this.playerId,
    this.clubId,
  });

  final int teamId;
  final String teamName;
  final int userId;
  final int? playerId;
  final int? clubId;

  @override
  State<PlayerMyTrainingsScreen> createState() => _PlayerMyTrainingsScreenState();
}

class _PlayerMyTrainingsScreenState extends State<PlayerMyTrainingsScreen> {
  static const double _runThresholdKmh = 7.0;
  static const double _sprintThresholdKmh = 18.0;
  static const _green = Color(0xFF00A750);
  static const _darkGreen = Color(0xFF087846);
  static const _bg = Color(0xFFFFFFFF);
  static const _line = Color(0xFFE1E5E2);
  static const _text = Color(0xFF111512);
  static const _muted = Color(0xFF6B746E);

  final _api = PlayerPersonalTrackerApi();
  late final PlayerPersonalAnalyticsApi _analyticsApi;
  final _polar = HeartRateBleService();
  final _gps = ActionTrackerBleService();

  final _gpsPoints = <ActionTrackerGpsPoint>[];
  final _hrSamples = <HeartRateSample>[];
  final _logs = <String>[];
  final _sessions = <Map<String, dynamic>>[];
  final _polarDevices = <HeartRateBleDevice>[];
  final _gpsDevices = <ActionTrackerDevice>[];

  final _activityLabels = const <String, String>{
    'football_field': 'Поле',
    'outdoor_run': 'Бег',
    'indoor_gym': 'Зал',
    'strength': 'Сила',
    'polar_only': 'Только Polar',
  };

  StreamSubscription<HeartRateSample>? _hrSub;
  StreamSubscription<ActionTrackerParseResult>? _gpsSub;
  StreamSubscription<String>? _polarLogSub;
  StreamSubscription<String>? _gpsLogSub;
  StreamSubscription<List<HeartRateBleDevice>>? _polarDevicesSub;
  StreamSubscription<List<ActionTrackerDevice>>? _gpsDevicesSub;
  Timer? _heartbeatTimer;
  Timer? _gpsPollTimer;
  Timer? _hrUploadTimer;

  String _activityType = 'football_field';
  bool _loading = false;
  bool _scanningPolar = false;
  bool _scanningGps = false;
  int? _liveSessionId;
  int? _finalSessionId;
  String? _error;
  DateTime? _startedAt;
  HeartRateSample? _lastHr;
  final List<HeartRateSample> _pendingHrUploads = <HeartRateSample>[];
  bool _flushingHrUploads = false;
  int _savedHrSamples = 0;
  double _totalDistanceM = 0;
  double _maxSpeedKmh = 0;
  double _avgSpeedKmh = 0;
  int _pointIndex = 0;
  DateTime? _lastEnvironmentSentAt;
  double? _lastEnvironmentLat;
  double? _lastEnvironmentLon;
  bool _environmentSending = false;

  _PlayerTrainingSection _section = _PlayerTrainingSection.live;
  TrackerPlayerOption? _personalPlayer;
  TrackerSessionModel? _selectedAnalyticsSession;
  int _analyticsTabSignal = 0;
  // В личный кабинет clubId иногда приходит пустым из старого маршрута.
  // Сохраняем подтверждённый club_id из персональных сессий и используем его
  // для ИИ/отчётов и новых Live-записей.
  int _resolvedClubId = 0;

  bool get _live => _liveSessionId != null;
  bool get _polarReady => _polar.heartRateReady;
  bool get _gpsReady => _gps.commandChannelReady || _gps.connectedInfo != null || _gps.lastKnownInfo != null;
  bool get _fieldRequired => _activityType == 'football_field';
  int get _playerId => widget.playerId ?? widget.userId;
  int get _effectiveClubId =>
      _resolvedClubId > 0 ? _resolvedClubId : (widget.clubId ?? 0);

  @override
  void initState() {
    super.initState();
    _resolvedClubId = (widget.clubId ?? 0) > 0 ? widget.clubId! : 0;
    _analyticsApi = PlayerPersonalAnalyticsApi(
      ownerUserId: widget.userId,
      playerId: _playerId,
    );
    _bindStreams();
    _initialLoad();
  }

  void _bindStreams() {
    _hrSub = _polar.sampleStream.listen(_onHeartRateSample, onError: (e) => _addLog('Polar: $e'));
    _gpsSub = _gps.dataStream.listen(_onGpsPacket, onError: (e) => _addLog('GPS: $e'));
    _polarLogSub = _polar.logStream.listen((e) => _addLog(e));
    _gpsLogSub = _gps.logStream.listen((e) => _addLog(e));

    // Важно: devicesStream у BLE-сервисов broadcast и не переигрывает последние
    // найденные устройства новому слушателю. Поэтому кешируем список на экране,
    // иначе после завершения scan модальное окно может открыться пустым, хотя в
    // журнале уже видно GPS SCAN CANDIDATES.
    _polarDevicesSub = _polar.devicesStream.listen(
      _cachePolarDevices,
      onError: (e) => _addLog('Polar devices: $e'),
    );
    _gpsDevicesSub = _gps.devicesStream.listen(
      _cacheGpsDevices,
      onError: (e) => _addLog('GPS devices: $e'),
    );
  }

  void _cachePolarDevices(Iterable<HeartRateBleDevice> devices) {
    if (!mounted) return;
    final map = <String, HeartRateBleDevice>{};
    for (final d in _polarDevices) {
      map[d.id] = d;
    }
    for (final d in _polar.connectedInfos) {
      map[d.id] = d;
    }
    for (final d in devices) {
      map[d.id] = d;
    }
    final list = map.values.toList()..sort((a, b) => b.rssi.compareTo(a.rssi));
    setState(() {
      _polarDevices
        ..clear()
        ..addAll(list);
    });
  }

  void _cacheGpsDevices(Iterable<ActionTrackerDevice> devices) {
    if (!mounted) return;
    final map = <String, ActionTrackerDevice>{};
    for (final d in _gpsDevices) {
      map[d.id] = d;
    }
    final connected = _gps.connectedInfo;
    final known = _gps.lastKnownInfo;
    if (connected != null) map[connected.id] = connected;
    if (known != null) map[known.id] = known;
    for (final d in devices) {
      map[d.id] = d;
    }
    final list = map.values.toList()..sort((a, b) => b.rssi.compareTo(a.rssi));
    setState(() {
      _gpsDevices
        ..clear()
        ..addAll(list);
    });
  }

  Future<void> _initialLoad() async {
    await Future.wait([
      _safeInitBle(),
      _loadPersonalIdentity(),
      _loadSessions(),
      _restoreActiveLive(),
    ]);
  }

  Future<void> _loadPersonalIdentity() async {
    try {
      final players = await _analyticsApi.loadPlayers(teamId: widget.teamId);
      TrackerPlayerOption? player;
      for (final item in players) {
        if (item.id == _playerId ||
            item.id == widget.userId ||
            item.identityIds.contains(_playerId) ||
            item.identityIds.contains(widget.userId)) {
          player = item;
          break;
        }
      }
      player ??= players.isNotEmpty ? players.first : null;
      if (!mounted || player == null) return;
      setState(() => _personalPlayer = player);
    } catch (e) {
      _addLog('Профиль для аналитики: $e');
    }
  }

  Future<void> _safeInitBle() async {
    try { await _polar.init(); } catch (e) { _addLog('Polar init: $e'); }
    try { await _gps.init(); } catch (e) { _addLog('GPS init: $e'); }
  }

  Future<void> _restoreActiveLive() async {
    try {
      final live = await _api.loadPlayerLiveState(teamId: widget.teamId, userId: widget.userId, playerId: _playerId);
      if (!mounted || live.isEmpty) return;
      final first = live.first;
      setState(() {
        _liveSessionId = first.id;
        _startedAt = DateTime.tryParse('${first.lastSeenAt ?? ''}'.replaceFirst(' ', 'T')) ?? DateTime.now();
        _totalDistanceM = first.totalDistanceM;
        _maxSpeedKmh = first.maxSpeedKmh;
        _avgSpeedKmh = first.avgSpeedKmh;
        _activityType = first.activityType.trim().isNotEmpty
            ? first.activityType
            : (first.source == 'player_polar'
                ? 'polar_only'
                : (first.source.contains('indoor') ? 'indoor_gym' : _activityType));
      });
      _startHeartbeat();
      _startHeartRateUploader();
      _addLog('Восстановлена активная личная Live-сессия #${first.id} · режим ${_activityLabels[_activityType] ?? _activityType}');
    } catch (e) {
      _addLog('Активный Live не восстановлен: $e');
    }
  }

  Future<void> _loadSessions() async {
    if (widget.teamId <= 0) return;
    try {
      final list = await _api.loadSessions(teamId: widget.teamId, userId: widget.userId, playerId: _playerId, limit: 80);
      if (!mounted) return;
      final ownList = list.where(_sessionRowBelongsToMe).toList(growable: false);
      var resolvedClubId = _effectiveClubId;
      if (resolvedClubId <= 0) {
        for (final row in ownList) {
          for (final key in const <String>[
            'club_id',
            'clubId',
            'team_club_id',
            'teamClubId',
          ]) {
            final id = int.tryParse('${row[key] ?? ''}');
            if (id != null && id > 0) {
              resolvedClubId = id;
              break;
            }
          }
          if (resolvedClubId > 0) break;
        }
      }
      final models = ownList
          .map((row) => TrackerSessionModel.fromJson(<String, dynamic>{
                ...row,
                'personal_session': 1,
                'session_kind': 'personal',
              }))
          .where((session) => session.id > 0)
          .toList(growable: false)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      TrackerSessionModel? preferred;
      if (_finalSessionId != null) {
        for (final session in models) {
          if (session.id == _finalSessionId) {
            preferred = session;
            break;
          }
        }
      }
      preferred ??= models.isNotEmpty ? models.first : null;

      TrackerPlayerOption? inferredPlayer = _personalPlayer;
      if (inferredPlayer == null && models.isNotEmpty) {
        final first = models.first;
        final name = (first.playerName ?? '').trim();
        inferredPlayer = TrackerPlayerOption(
          id: first.playerId ?? _playerId,
          name: name.isEmpty ? 'Мой профиль' : name,
          identityIds: <int>{
            _playerId,
            widget.userId,
            if (first.playerId != null && first.playerId! > 0) first.playerId!,
          },
        );
      }

      setState(() {
        _sessions
          ..clear()
          ..addAll(ownList);
        if (resolvedClubId > 0) _resolvedClubId = resolvedClubId;
        _personalPlayer = inferredPlayer ?? _personalPlayer;
        if (_selectedAnalyticsSession == null || preferred?.id == _finalSessionId) {
          _selectedAnalyticsSession = preferred;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  bool _sessionRowBelongsToMe(Map<String, dynamic> row) {
    final ids = <int>{};
    for (final key in const <String>[
      'player_id',
      'playerId',
      'user_id',
      'userId',
      'owner_user_id',
      'ownerUserId',
    ]) {
      final id = int.tryParse('${row[key] ?? ''}');
      if (id != null && id > 0) ids.add(id);
    }
    if (ids.isEmpty) return true;
    return ids.contains(_playerId) || ids.contains(widget.userId);
  }

  Future<void> _scanPolar() async {
    if (_scanningPolar) return;
    setState(() {
      _scanningPolar = true;
      _polarDevices.clear();
    });
    try {
      await _polar.scan(timeout: const Duration(seconds: 8), showAllBleCandidates: true);
      if (!mounted) return;
      _cachePolarDevices(const <HeartRateBleDevice>[]);
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => _PolarPickerSheet(initialItems: List<HeartRateBleDevice>.of(_polarDevices), service: _polar, onPick: (d) async {
          Navigator.pop(context);
          await _polar.connect(d);
          _cachePolarDevices(<HeartRateBleDevice>[d]);
          if (mounted) setState(() {});
        }),
      );
    } catch (e) {
      _showError('Polar не подключился: $e');
    } finally {
      if (mounted) setState(() => _scanningPolar = false);
    }
  }

  Future<void> _scanGps() async {
    if (_scanningGps) return;
    setState(() {
      _scanningGps = true;
      _gpsDevices.clear();
    });
    try {
      await _gps.scan(timeout: const Duration(seconds: 7), expandedFallback: true, universalMode: true);
      if (!mounted) return;
      _cacheGpsDevices(const <ActionTrackerDevice>[]);
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => _GpsPickerSheet(initialItems: List<ActionTrackerDevice>.of(_gpsDevices), service: _gps, onPick: (d) async {
          Navigator.pop(context);
          await _gps.connect(d);
          _cacheGpsDevices(<ActionTrackerDevice>[d]);
          if (mounted) setState(() {});
        }),
      );
    } catch (e) {
      _showError('GPS-трекер не подключился: $e');
    } finally {
      if (mounted) setState(() => _scanningGps = false);
    }
  }

  Future<void> _startLive() async {
    if (_loading || _live) return;
    final polarOnly = _activityType == 'polar_only';
    if (!polarOnly && !_gpsReady && !_polarReady) {
      _showError('Подключите Polar, GPS-трекер или выберите режим «Только Polar».');
      return;
    }
    if (polarOnly && !_polarReady) {
      _showError('Для режима «Только Polar» сначала подключите Polar/H10.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _gpsPoints.clear();
      _hrSamples.clear();
      _totalDistanceM = 0;
      _maxSpeedKmh = 0;
      _avgSpeedKmh = 0;
      _pointIndex = 0;
      _finalSessionId = null;
      _pendingHrUploads.clear();
      _savedHrSamples = 0;
      _lastEnvironmentSentAt = null;
      _lastEnvironmentLat = null;
      _lastEnvironmentLon = null;
      _environmentSending = false;
    });

    try {
      final gpsDevice = _gps.connectedInfo ?? _gps.lastKnownInfo;
      final polarDevice = _polar.connectedInfo ?? _polar.lastKnownInfo;
      final deviceUuid = gpsDevice?.id ?? polarDevice?.id ?? 'player-${widget.userId}-${DateTime.now().millisecondsSinceEpoch}';
      final deviceName = gpsDevice?.name ?? polarDevice?.name ?? 'Личная тренировка';
      final source = gpsDevice != null && polarDevice != null
          ? 'player_gps_polar'
          : gpsDevice != null
              ? 'player_tracker'
              : 'player_polar';

      final id = await _api.startLiveSession(
        teamId: widget.teamId,
        userId: widget.userId,
        clubId: _effectiveClubId > 0 ? _effectiveClubId : null,
        playerId: _playerId,
        deviceUuid: deviceUuid,
        deviceName: deviceName,
        source: source,
        activityType: _activityType,
        fieldRequired: _fieldRequired,
        batteryPercent: _polar.batteryPercent,
      );
      if (id <= 0) throw Exception('Сервер не вернул live_session_id');

      if (!mounted) return;
      setState(() {
        _liveSessionId = id;
        _startedAt = DateTime.now();
      });
      _startHeartbeat();
      _startHeartRateUploader();
      _startGpsPolling();
      _addLog('Личная Live-сессия запущена: #$id · режим ${_activityLabels[_activityType] ?? _activityType}');
    } catch (e) {
      _showError('Не удалось стартовать Live: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _stopLive() async {
    final liveId = _liveSessionId;
    if (_loading || liveId == null) return;
    setState(() => _loading = true);
    try {
      _hrUploadTimer?.cancel();

      // Критично: сначала догружаем всю очередь Polar, и только потом
      // создаём итоговую сессию. Иначе final session создавалась без HR-точек.
      await _flushPendingHeartRate(maxBatch: 5000);
      if (_pendingHrUploads.isNotEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 600));
        await _flushPendingHeartRate(maxBatch: 5000);
      }

      await _sendHeartbeat();

      final json = await _api.stopLiveSession(
        liveSessionId: liveId,
        teamId: widget.teamId,
        userId: widget.userId,
      );
      if (!mounted) return;
      setState(() {
        _liveSessionId = null;
        _finalSessionId = int.tryParse('${json['session_id'] ?? json['final_session_id'] ?? ''}');
      });
      _heartbeatTimer?.cancel();
      _gpsPollTimer?.cancel();

      final savedOnServer = int.tryParse(
            '${json['heart_rate_summary'] is Map ? (json['heart_rate_summary'] as Map)['samples_count'] : ''}',
          ) ??
          _savedHrSamples;

      _addLog(
        'Сессия сохранена: ${_finalSessionId == null ? 'готово' : '#$_finalSessionId'} · '
        'Polar $savedOnServer точек · очередь ${_pendingHrUploads.length}',
      );
      await _loadSessions();
    } catch (e) {
      _startHeartRateUploader();
      _showError('Не удалось завершить тренировку: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    // Live-карточка тренера обновляется каждые две секунды. Более редкий
    // heartbeat оставлял показатели движения замороженными между GPS-точками.
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 5), (_) => _sendHeartbeat());
    _sendHeartbeat();
  }

  Future<void> _sendHeartbeat() async {
    final liveId = _liveSessionId;
    if (liveId == null) return;
    await _flushPendingHeartRate();
    try {
      await _api.heartbeatLiveSession(
        liveSessionId: liveId,
        teamId: widget.teamId,
        userId: widget.userId,
        statusText: _gpsReady
            ? 'personal_live_gps_polar'
            : (_polarReady ? 'personal_live_polar' : 'personal_live_active'),
        snapshot: {
          ..._snapshot(),
          'heart_rate_saved_count': _savedHrSamples,
          'heart_rate_pending_count': _pendingHrUploads.length,
          'heart_rate_samples_count': _savedHrSamples,
          'heart_rate_received_count': _hrSamples.length,
          'activity_type': _activityType,
        },
      );
    } catch (e) {
      _addLog('Heartbeat: $e');
    }
  }

  void _startHeartRateUploader() {
    _hrUploadTimer?.cancel();
    _hrUploadTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _flushPendingHeartRate(),
    );
    _flushPendingHeartRate();
  }

  Future<void> _flushPendingHeartRate({int maxBatch = 20}) async {
    final liveId = _liveSessionId;
    if (liveId == null || _flushingHrUploads || _pendingHrUploads.isEmpty) return;
    _flushingHrUploads = true;
    try {
      var sent = 0;
      while (_pendingHrUploads.isNotEmpty &&
          sent < maxBatch &&
          _liveSessionId == liveId) {
        final sample = _pendingHrUploads.first;
        try {
          await _api.saveHeartRateSample(
            teamId: widget.teamId,
            userId: widget.userId,
            clubId: _effectiveClubId > 0 ? _effectiveClubId : null,
            playerId: _playerId,
            liveSessionId: liveId,
            sample: sample,
            activityType: _activityType,
          );
          _pendingHrUploads.removeAt(0);
          _savedHrSamples++;
          sent++;
        } catch (e) {
          _addLog('Polar upload: $e');
          break;
        }
      }
      if (sent > 0 && mounted) {
        setState(() {});
      }
    } finally {
      _flushingHrUploads = false;
    }
  }

  void _startGpsPolling() {
    _gpsPollTimer?.cancel();
    if (_activityType == 'polar_only') return;
    // Для бега шесть секунд между точками визуально превращали маршрут в одну
    // диагональ и слишком поздно обновляли темп. Три секунды дают плавный Live.
    _gpsPollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!_live || !_gpsReady) return;
      try { await _gps.requestCurrentGpsCandidate(); } catch (e) { _addLog('GPS точка: $e'); }
    });
  }

  Future<void> _onHeartRateSample(HeartRateSample sample) async {
    _lastHr = sample;
    _hrSamples.add(sample);
    if (_hrSamples.length > 1200) {
      _hrSamples.removeRange(0, _hrSamples.length - 1200);
    }

    final liveId = _liveSessionId;
    if (liveId != null) {
      _pendingHrUploads.add(sample);
      if (_pendingHrUploads.length > 3600) {
        _pendingHrUploads.removeRange(0, _pendingHrUploads.length - 3600);
      }
      _flushPendingHeartRate();
    }

    if (mounted) setState(() {});
  }

  Future<void> _onGpsPacket(ActionTrackerParseResult packet) async {
    final chunk = packet.gpsChunk;
    if (chunk == null || chunk.points.isEmpty) return;
    for (final point in chunk.points) {
      await _handleGpsPoint(point, rawHex: packet.rawHex);
    }
  }

  Future<void> _syncSessionEnvironment(ActionTrackerGpsPoint point) async {
    final liveId = _liveSessionId;
    if (liveId == null || _environmentSending) return;
    if (point.latitude.abs() < 0.000001 || point.longitude.abs() < 0.000001) return;

    final now = DateTime.now();
    final lastAt = _lastEnvironmentSentAt;
    final lastLat = _lastEnvironmentLat;
    final lastLon = _lastEnvironmentLon;
    final movedM = lastLat == null || lastLon == null
        ? double.infinity
        : _haversineM(lastLat, lastLon, point.latitude, point.longitude);
    final elapsed = lastAt == null ? const Duration(days: 1) : now.difference(lastAt);
    if (elapsed < const Duration(minutes: 10) && movedM < 300) return;

    _environmentSending = true;
    try {
      await _api.updateSessionEnvironment(
        liveSessionId: liveId,
        latitude: point.latitude,
        longitude: point.longitude,
      );
      _lastEnvironmentSentAt = now;
      _lastEnvironmentLat = point.latitude;
      _lastEnvironmentLon = point.longitude;
      _addLog('Место и погода тренировки обновлены.');
    } catch (e) {
      _addLog('Environment update: $e');
    } finally {
      _environmentSending = false;
    }
  }

  Future<void> _handleGpsPoint(ActionTrackerGpsPoint point, {String? rawHex}) async {
    if (point.latitude.abs() < 0.000001 || point.longitude.abs() < 0.000001) return;
    final last = _gpsPoints.isEmpty ? null : _gpsPoints.last;
    final pointTimeMs = point.timeMs > 0
        ? point.timeMs
        : DateTime.now().millisecondsSinceEpoch;
    final rawDtSec = last == null
        ? 0.0
        : (pointTimeMs - last.timeMs).abs() / 1000.0;
    final dtSec = last == null
        ? 0.0
        : (rawDtSec > 0 && rawDtSec <= 300 ? rawDtSec : 3.0);
    final measuredDistanceDelta = last == null
        ? 0.0
        : _haversineM(
            last.latitude,
            last.longitude,
            point.latitude,
            point.longitude,
          );
    final sensorSpeed = point.speedKmh ?? 0.0;
    final measuredSpeed = dtSec > 0
        ? measuredDistanceDelta / dtSec * 3.6
        : 0.0;
    if (last != null && (sensorSpeed > 36 || measuredSpeed > 36)) {
      _addLog('GPS: пропущена неточная точка маршрута');
      return;
    }
    // Отбрасываем одиночный GPS-скачок, который раньше рисовал диагональ через
    // весь экран и одновременно давал ложный спринт.
    final maxPlausibleDistance = math.max(8.0, dtSec * 36.0 / 3.6);
    final distanceDelta = measuredDistanceDelta
        .clamp(0.0, maxPlausibleDistance)
        .toDouble();
    final calculatedSpeed = dtSec > 0 ? (distanceDelta / dtSec) * 3.6 : 0.0;
    // Часть прошивок передаёт speed=0 даже при изменившихся координатах.
    // Такой ноль нельзя считать ходьбой: восстанавливаем скорость по отрезку.
    final speed = (sensorSpeed > 0.1 ? sensorSpeed : calculatedSpeed)
        .clamp(0.0, 36.0)
        .toDouble();
    _totalDistanceM += distanceDelta.isFinite ? distanceDelta : 0.0;
    _maxSpeedKmh = math.max(_maxSpeedKmh, speed.isFinite ? speed : 0.0);
    final duration = _durationSec;
    _avgSpeedKmh = duration <= 0 ? 0 : (_totalDistanceM / duration) * 3.6;

    final enriched = ActionTrackerGpsPoint(
      timeMs: pointTimeMs,
      latitude: point.latitude,
      longitude: point.longitude,
      speedKmh: speed,
      distanceDeltaM: distanceDelta,
      totalDistanceM: _totalDistanceM,
      pointIndex: _pointIndex++,
      liveSessionId: _liveSessionId,
      playerId: _playerId,
    );
    _gpsPoints.add(enriched);
    if (_gpsPoints.length > 1200) _gpsPoints.removeRange(0, _gpsPoints.length - 1200);
    final movement = _movementSummary;
    if (mounted) setState(() {});

    final liveId = _liveSessionId;
    if (liveId == null) return;

    // Место тренировки и погода сохраняются по реальным координатам трекера.
    // Первый запрос выполняется сразу, затем не чаще одного раза в 10 минут
    // или после перемещения более чем на 300 метров.
    unawaited(_syncSessionEnvironment(enriched));

    try {
      await _api.saveLivePoint(
        userId: widget.userId,
        activityType: _activityType,
        payload: TrackerLivePointPayload(
          liveSessionId: liveId,
          clubId: _effectiveClubId,
          teamId: widget.teamId,
          playerId: _playerId,
          deviceUuid: _gps.connectedInfo?.id ?? _gps.lastKnownInfo?.id ?? 'player-gps-${widget.userId}',
          latitude: enriched.latitude,
          longitude: enriched.longitude,
          timeMs: enriched.timeMs,
          speedKmh: speed,
          rawSpeedKmh: point.speedKmh,
          distanceDeltaM: distanceDelta,
          totalDistanceM: _totalDistanceM,
          maxSpeedKmh: _maxSpeedKmh,
          avgSpeedKmh: _avgSpeedKmh,
          meteragePerMin: duration <= 0 ? 0 : _totalDistanceM / (duration / 60.0),
          loadScore: _loadScore,
          hsrDistanceM: movement.highIntensityDistanceM,
          vhirDistanceM: movement.veryHighIntensityDistanceM,
          sprintDistanceM: movement.sprintDistanceM,
          runDistanceM: movement.runDistanceM,
          walkDistanceM: movement.walkDistanceM,
          runDurationSec: movement.runDurationSec,
          walkDurationSec: movement.walkDurationSec,
          sprintDurationSec: movement.sprintDurationSec,
          runPercent: movement.runPercent,
          walkPercent: movement.walkPercent,
          sprintCount: movement.sprintCount,
          durationSec: duration,
          analysisJson: _snapshot(),
          rawHex: rawHex,
        ),
      );
    } catch (e) {
      _addLog('Point save: $e');
    }
  }

  int get _durationSec {
    final start = _startedAt;
    if (start == null) return 0;
    return math.max(0, DateTime.now().difference(start).inSeconds);
  }

  double get _loadScore {
    final hrPart = _lastHr == null ? 0.0 : ((_lastHr!.bpm - 90).clamp(0, 120) as num).toDouble() / 12.0;
    final gpsPart = _totalDistanceM / 1000.0 + _maxSpeedKmh / 8.0;
    return (hrPart + gpsPart).clamp(0, 99).toDouble();
  }

  _LiveMovementSummary get _movementSummary => _LiveMovementSummary.fromPoints(
        _gpsPoints,
        runThresholdKmh: _runThresholdKmh,
        sprintThresholdKmh: _sprintThresholdKmh,
      );

  Map<String, dynamic> _snapshot() {
    final movement = _movementSummary;
    return <String, dynamic>{
        'distance_m': _totalDistanceM,
        'duration_sec': _durationSec,
        'speed_kmh': _gpsPoints.isEmpty ? 0.0 : (_gpsPoints.last.speedKmh ?? 0.0),
        'max_speed_kmh': _maxSpeedKmh,
        'avg_speed_kmh': _avgSpeedKmh,
        'load_score': _loadScore,
        'heart_rate_bpm': _lastHr?.bpm,
        'heart_rate_samples_count': _hrSamples.length,
        'points_count': _gpsPoints.length,
        'activity_type': _activityType,
        'source': 'player_personal_live',
        'run_distance_m': movement.runDistanceM,
        'run_duration_sec': movement.runDurationSec,
        'run_percent': movement.runPercent,
        'walk_distance_m': movement.walkDistanceM,
        'walk_duration_sec': movement.walkDurationSec,
        'walk_percent': movement.walkPercent,
        'sprint_distance_m': movement.sprintDistanceM,
        'sprint_duration_sec': movement.sprintDurationSec,
        'sprint_count': movement.sprintCount,
        'hsr_distance_m': movement.highIntensityDistanceM,
        'vhir_distance_m': movement.veryHighIntensityDistanceM,
      };
  }

  void _addLog(String message) {
    final text = message.trim();
    if (text.isEmpty) return;
    if (!mounted) return;
    setState(() {
      _logs.insert(0, text);
      if (_logs.length > 80) _logs.removeRange(80, _logs.length);
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() => _error = message);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _gpsPollTimer?.cancel();
    _hrUploadTimer?.cancel();
    _hrSub?.cancel();
    _gpsSub?.cancel();
    _polarLogSub?.cancel();
    _gpsLogSub?.cancel();
    _polarDevicesSub?.cancel();
    _gpsDevicesSub?.cancel();
    _polar.dispose();
    _gps.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Мои тренировки',
                style: TextStyle(
                    color: _text, fontWeight: FontWeight.w900, fontSize: 17)),
            Text(widget.teamName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: _muted,
                    fontWeight: FontWeight.w700,
                    fontSize: 11)),
          ],
        ),
      ),
      body: Column(
        children: [
          _personalNavigation(),
          const Divider(height: 1, color: _line),
          Expanded(child: _sectionBody()),
        ],
      ),
    );
  }

  Widget _personalNavigation() {
    return Container(
      height: 52,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      child: Row(
        children: [
          Expanded(
            child: _navButton(
              section: _PlayerTrainingSection.live,
              icon: Icons.play_circle_outline_rounded,
              label: 'Тренировка',
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _navButton(
              section: _PlayerTrainingSection.analytics,
              icon: Icons.analytics_rounded,
              label: 'Аналитика',
            ),
          ),
        ],
      ),
    );
  }

  Widget _navButton({
    required _PlayerTrainingSection section,
    required IconData icon,
    required String label,
  }) {
    final active = _section == section;
    return InkWell(
      onTap: () => setState(() => _section = section),
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0xFFECF8F1) : const Color(0xFFF7F9F8),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: active ? _green.withOpacity(.30) : Colors.transparent),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 17, color: active ? _darkGreen : _muted),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: active ? _darkGreen : _text,
                  fontSize: 11.2,
                  fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionBody() {
    switch (_section) {
      case _PlayerTrainingSection.live:
        return _liveTrainingBody();
      case _PlayerTrainingSection.analytics:
        return _personalAnalyticsBody();
    }
  }

  Widget _liveTrainingBody() {
    return RefreshIndicator(
      color: _green,
      onRefresh: _loadSessions,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
        children: [
          if (_error != null) _errorPanel(_error!),
          _liveHeader(),
          const SizedBox(height: 8),
          _devicePanel(),
          const SizedBox(height: 8),
          _activityPanel(),
          const SizedBox(height: 8),
          _metricsPanel(),
          const SizedBox(height: 8),
          _mapAndChartPanel(),
          const SizedBox(height: 8),
          _sessionsPanel(),
          if (_logs.isNotEmpty) ...[
            const SizedBox(height: 8),
            _logsPanel(),
          ],
        ],
      ),
    );
  }

  TrackerPlayerOption get _effectivePersonalPlayer {
    final player = _personalPlayer;
    if (player != null) {
      return TrackerPlayerOption(
        id: _playerId,
        name: player.name,
        avatar: player.avatar,
        number: player.number,
        position: player.position,
        identityIds: <int>{
          _playerId,
          widget.userId,
          player.id,
          ...player.identityIds,
        },
      );
    }
    return TrackerPlayerOption(
      id: _playerId,
      name: 'Мой профиль',
      identityIds: <int>{_playerId, widget.userId},
    );
  }

  Widget _personalAnalyticsBody() {
    final player = _effectivePersonalPlayer;
    return Column(
      children: [
        _previousTrainingComparison(),
        Expanded(
          child: TrackerActionAnalyticsSuite(
            api: _analyticsApi,
            clubId: _effectiveClubId,
            userId: widget.userId,
            teamId: widget.teamId,
            teamName: widget.teamName,
            clubName: 'Личные тренировки',
            players: <TrackerPlayerOption>[player],
            selectedPlayer: player,
            playerFilterLabel: player.name,
            fixedPlayerId: player.id,
            lockedSessionKind: PlayerTrainingCalendarMode.personal,
            selectedField: null,
            localPoints: const <ActionTrackerGpsPoint>[],
            selectedSession: _selectedAnalyticsSession,
            onRefresh: () => unawaited(_loadSessions()),
            onSelectPlayer: (_) {},
            onSelectSession: (session) {
              if (!mounted) return;
              setState(() => _selectedAnalyticsSession = session);
            },
            onOpenCalibration: () => _showInfo(
              'Калибровка поля доступна в командном кабинете тренера.',
            ),
            onOpenSessions: _openPersonalSessionPicker,
            onOpenLive: () =>
                setState(() => _section = _PlayerTrainingSection.live),
            onRequestOfflineRecords: () => _showInfo(
              'Офлайн-запись трекера запускается во вкладке «Тренировка».',
            ),
            onSaveOfflineSession: () => _showInfo(
              'Сохранение записи доступно во вкладке «Тренировка».',
            ),
            liveRunning: _live,
            commandChannelReady: _gpsReady,
            offlineRecordsCount: 0,
            localPointsCount: _gpsPoints.length,
            onDebug: (message, context) => _addLog(message),
            initialTab: 0,
            initialTabSignal: _analyticsTabSignal,
            initialCalendarMode: PlayerTrainingCalendarMode.personal,
            personalMode: true,
          ),
        ),
      ],
    );
  }

  Future<void> _openPersonalSessionPicker() async {
    if (!mounted) return;
    final rows = List<Map<String, dynamic>>.from(_sessions);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final bottom = MediaQuery.paddingOf(sheetContext).bottom;
        final height = MediaQuery.sizeOf(sheetContext).height;
        return SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              constraints: BoxConstraints(maxHeight: math.min(height * .78, 620)),
              margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + bottom),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(.14),
                    blurRadius: 30,
                    offset: const Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3E8E5),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _green.withOpacity(.09),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: const Icon(Icons.history_rounded, color: _darkGreen, size: 19),
                      ),
                      const SizedBox(width: 9),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Выбор тренировки', style: TextStyle(color: _text, fontSize: 14, fontWeight: FontWeight.w900)),
                            SizedBox(height: 2),
                            Text('Только мои личные сессии', style: TextStyle(color: _muted, fontSize: 10.5, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close_rounded, color: _text),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Flexible(
                    child: rows.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 28),
                              child: Text('Пока нет сохранённых личных тренировок.', style: TextStyle(color: _muted, fontWeight: FontWeight.w700)),
                            ),
                          )
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const BouncingScrollPhysics(),
                            itemCount: rows.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 7),
                            itemBuilder: (_, index) {
                              final row = rows[index];
                              final session = TrackerSessionModel.fromJson(<String, dynamic>{
                                ...row,
                                'personal_session': 1,
                                'session_kind': 'personal',
                              });
                              final selected = session.id == _selectedAnalyticsSession?.id;
                              final date = '${row['started_at'] ?? row['created_at'] ?? row['date'] ?? ''}'.replaceFirst('T', ' ');
                              return InkWell(
                                onTap: () {
                                  Navigator.pop(sheetContext);
                                  _openCalendarSession(row);
                                },
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                                  decoration: BoxDecoration(
                                    color: selected ? _green.withOpacity(.07) : const Color(0xFFF8FAF9),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: selected ? _green.withOpacity(.45) : _line),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 34,
                                        height: 34,
                                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                                        child: Icon(selected ? Icons.check_rounded : Icons.directions_run_rounded, color: selected ? _green : _muted, size: 18),
                                      ),
                                      const SizedBox(width: 9),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Тренировка #${session.id}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _text, fontSize: 12.3, fontWeight: FontWeight.w900)),
                                            const SizedBox(height: 2),
                                            Text(date.isEmpty ? 'Дата не указана' : date, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _muted, fontSize: 10.2, fontWeight: FontWeight.w700)),
                                          ],
                                        ),
                                      ),
                                      Text(_fmtDistance(session.distanceM), style: const TextStyle(color: _darkGreen, fontSize: 11.4, fontWeight: FontWeight.w900)),
                                    ],
                                  ),
                                ),
                              );
                            },
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

  void _openCalendarSession(Map<String, dynamic> row) {
    final session = TrackerSessionModel.fromJson(<String, dynamic>{
      ...row,
      'personal_session': 1,
      'session_kind': 'personal',
    });
    if (session.id <= 0) return;
    setState(() {
      _selectedAnalyticsSession = session;
      _section = _PlayerTrainingSection.analytics;
      _analyticsTabSignal++;
    });
  }

  void _showInfo(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  List<TrackerSessionModel> get _personalSessionModels {
    final rows = _sessions
        .map((row) => TrackerSessionModel.fromJson(<String, dynamic>{
              ...row,
              'personal_session': 1,
              'session_kind': 'personal',
            }))
        .where((session) => session.id > 0)
        .toList(growable: false)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return rows;
  }

  Widget _previousTrainingComparison() {
    final sessions = _personalSessionModels;
    final current = _selectedAnalyticsSession ??
        (sessions.isNotEmpty ? sessions.first : null);
    TrackerSessionModel? previous;
    if (current != null) {
      final currentIndex = sessions.indexWhere((s) => s.id == current.id);
      if (currentIndex >= 0 && currentIndex + 1 < sessions.length) {
        previous = sessions[currentIndex + 1];
      }
    }

    return Container(
      height: previous == null ? 54 : 82,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.compare_arrows_rounded, color: _green, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  current == null
                      ? 'Нет сохранённых тренировок'
                      : previous == null
                          ? 'Тренировка #${current.id} · нужна ещё одна для сравнения'
                          : 'Тренировка #${current.id} · сравнение с предыдущей',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _text, fontSize: 10.8, fontWeight: FontWeight.w800),
                ),
              ),
              TextButton.icon(
                onPressed: _openPersonalSessionPicker,
                style: TextButton.styleFrom(
                  foregroundColor: _darkGreen,
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  minimumSize: const Size(0, 28),
                ),
                icon: const Icon(Icons.swap_horiz_rounded, size: 15),
                label: const Text('Сессия', style: TextStyle(fontSize: 10.2, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          if (previous != null) ...[
            const SizedBox(height: 3),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _comparisonPill('Дист.', current!.distanceM, previous.distanceM, suffix: 'м')),
                  const SizedBox(width: 5),
                  Expanded(child: _comparisonPill('Скор.', current.maxSpeedKmh, previous.maxSpeedKmh, suffix: 'км/ч', digits: 1)),
                  const SizedBox(width: 5),
                  Expanded(child: _comparisonPill('Спр.', current.sprintCount.toDouble(), previous.sprintCount.toDouble(), suffix: '', digits: 0)),
                  const SizedBox(width: 5),
                  Expanded(child: _comparisonPill('Нагр.', current.loadScore, previous.loadScore, suffix: '', digits: 0)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _comparisonPill(
    String title,
    double current,
    double previous, {
    required String suffix,
    int digits = 0,
  }) {
    final delta = current - previous;
    final sign = delta > 0 ? '+' : '';
    final deltaText = previous.abs() < .0001
        ? '—'
        : '$sign${delta.toStringAsFixed(digits)}${suffix.isEmpty ? '' : ' $suffix'}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9F8),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _muted, fontSize: 8.2, fontWeight: FontWeight.w700)),
          const SizedBox(height: 1),
          Text(deltaText, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: delta >= 0 ? _darkGreen : const Color(0xFFB04A42), fontSize: 9.5, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _liveHeader() {
    final status = _live ? 'Live идёт · #$_liveSessionId' : 'Готов к личной тренировке';
    final subtitle = _live
        ? 'Сервер получает heartbeat, Polar/GPS сохраняются пачками'
        : 'Можно включить Polar, GPS-трекер или оба вместе';
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: _live ? _green : _line)),
              const SizedBox(width: 8),
              Expanded(child: Text(status, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: _text))),
              _pill(_activityLabels[_activityType] ?? _activityType, active: true),
            ],
          ),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _muted)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _loading || _live ? null : _startLive,
                  icon: _loading && !_live ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.play_arrow_rounded),
                  label: const Text('Старт'),
                  style: ElevatedButton.styleFrom(backgroundColor: _green, foregroundColor: Colors.white, elevation: 0, minimumSize: const Size(0, 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _loading || !_live ? null : _stopLive,
                  icon: const Icon(Icons.stop_rounded),
                  label: const Text('Завершить'),
                  style: OutlinedButton.styleFrom(foregroundColor: _text, side: const BorderSide(color: _line), minimumSize: const Size(0, 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _devicePanel() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Устройства', 'Polar для пульса, GPS-трекер для точек и скорости'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _deviceTile(icon: Icons.favorite_rounded, title: _polarReady ? (_polar.connectedInfo?.name ?? 'Polar подключён') : 'Polar / H10', subtitle: _lastHr == null ? (_polarDevices.isEmpty ? 'пульс пока не идёт' : 'найдено ${_polarDevices.length} · нажмите выбрать') : '${_lastHr!.bpm} уд/мин · ${_polar.batteryPercent ?? '—'}%', active: _polarReady, loading: _scanningPolar, onTap: _scanPolar)),
              const SizedBox(width: 10),
              Expanded(child: _deviceTile(icon: Icons.gps_fixed_rounded, title: _gps.connectedInfo?.name ?? _gps.lastKnownInfo?.name ?? 'GPS-трекер', subtitle: _gpsReady ? 'готов к Live' : (_gpsDevices.isEmpty ? 'поиск датчика' : 'найдено ${_gpsDevices.length} · нажмите выбрать'), active: _gpsReady, loading: _scanningGps, onTap: _scanGps)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _activityPanel() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Режим тренировки', 'Выберите до старта. Polar измеряет пульс, а режим сохраняется в сессии на сервере.'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _activityLabels.entries.map((e) {
              final active = _activityType == e.key;
              return ChoiceChip(
                selected: active,
                showCheckmark: false,
                label: Text(e.value),
                onSelected: _live ? null : (_) => setState(() => _activityType = e.key),
                selectedColor: _green.withOpacity(.06),
                backgroundColor: Colors.white,
                side: BorderSide(color: active ? _green : _line),
                labelStyle: TextStyle(color: active ? _darkGreen : _text, fontWeight: FontWeight.w800),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _metricsPanel() {
    final runningMode = _activityType == 'outdoor_run';
    final movement = _movementSummary;
    final currentSpeed = _gpsPoints.isEmpty
        ? _avgSpeedKmh
        : (_gpsPoints.last.speedKmh ?? _avgSpeedKmh);
    final paceSeconds = currentSpeed > .1 ? (3600 / currentSpeed).round() : 0;
    final pace = paceSeconds > 0
        ? '${paceSeconds ~/ 60}:${(paceSeconds % 60).toString().padLeft(2, '0')}'
        : '—';
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            runningMode ? 'Бег · показатели Live' : 'Показатели Live',
            runningMode
                ? 'темп, бег и спринты считаются прямо во время тренировки'
                : 'данные сохраняются на сервер во время тренировки',
          ),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.9,
            children: runningMode
                ? [
                    _metric('Пульс', _lastHr == null ? '—' : '${_lastHr!.bpm}', 'уд/мин'),
                    _metric('Дистанция', _fmtDistance(_totalDistanceM), ''),
                    _metric('Текущий темп', pace, 'мин/км'),
                    _metric('Скорость', currentSpeed.toStringAsFixed(1), 'км/ч'),
                    _metric('Макс. скорость', _maxSpeedKmh.toStringAsFixed(1), 'км/ч'),
                    _metric('Бег', movement.runPercent > 0 ? '${movement.runPercent.round()}' : '0', '%'),
                    _metric('Спринты', '${movement.sprintCount}', 'всего'),
                    _metric('Время', _fmtDuration(_durationSec), ''),
                  ]
                : [
                    _metric('Пульс', _lastHr == null ? '—' : '${_lastHr!.bpm}', 'уд/мин'),
                    _metric('Дистанция', _fmtDistance(_totalDistanceM), ''),
                    _metric('Скорость max', _maxSpeedKmh.toStringAsFixed(1), 'км/ч'),
                    _metric('Нагрузка', _loadScore.toStringAsFixed(1), 'балл'),
                    _metric('Точки', '${_gpsPoints.length}', 'GPS'),
                    _metric('Polar сервер', '$_savedHrSamples', 'HR'),
                    _metric('Polar очередь', '${_pendingHrUploads.length}', 'HR'),
                    _metric('Время', _fmtDuration(_durationSec), ''),
                  ],
          ),
        ],
      ),
    );
  }

  Widget _mapAndChartPanel() {
    final runningMode = _activityType == 'outdoor_run';
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            runningMode ? 'Маршрут бега' : 'Карта и график',
            runningMode
                ? 'старт, текущая позиция и участки маршрута в прямом эфире'
                : 'для Polar-only будет отображаться график ЧСС',
          ),
          const SizedBox(height: 8),
          Container(
            height: 220,
            decoration: BoxDecoration(color: _green, borderRadius: BorderRadius.circular(14)),
            child: CustomPaint(
              painter: _PlayerRoutePainter(
                points: _gpsPoints,
                heartRate: _hrSamples,
                runningMode: runningMode,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sessionsPanel() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: _StaticSectionTitle(title: 'Последние личные тренировки', subtitle: 'нажмите тренировку, чтобы открыть аналитику')),
              TextButton(
                onPressed: _openPersonalSessionPicker,
                child: const Text('Все', style: TextStyle(color: _darkGreen, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_sessions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Пока нет сохранённых личных тренировок.', style: TextStyle(color: _muted, fontWeight: FontWeight.w700)),
            )
          else
            ..._sessions.take(20).map(_sessionTile),
        ],
      ),
    );
  }

  Widget _sessionTile(Map<String, dynamic> row) {
    final date = '${row['started_at'] ?? row['created_at'] ?? row['date'] ?? ''}'.replaceFirst('T', ' ');
    final distance = _asDouble(row['distance_m'] ?? row['total_distance_m']);
    final duration = _asInt(row['duration_sec']);
    final hrAvg = _asInt(row['avg_bpm'] ?? row['heart_rate_avg_bpm']);
    return InkWell(
      onTap: () => _openCalendarSession(row),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: _line)),
        child: Row(
        children: [
          Container(width: 38, height: 38, decoration: BoxDecoration(color: _green.withOpacity(.1), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.directions_run_rounded, color: _darkGreen, size: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${row['title'] ?? 'Личная тренировка'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _text, fontWeight: FontWeight.w900, fontSize: 13)),
              const SizedBox(height: 3),
              Text(date.isEmpty ? 'дата не указана' : date, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _muted, fontWeight: FontWeight.w700, fontSize: 11)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(_fmtDistance(distance), style: const TextStyle(color: _text, fontWeight: FontWeight.w900, fontSize: 12)),
            const SizedBox(height: 3),
            Text('${_fmtDuration(duration)}${hrAvg > 0 ? ' · $hrAvg bpm' : ''}', style: const TextStyle(color: _muted, fontWeight: FontWeight.w700, fontSize: 10)),
          ]),
        ],
        ),
      ),
    );
  }

  Widget _logsPanel() => _card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionTitle('Журнал', 'служебные события BLE и сервера'),
          const SizedBox(height: 8),
          ..._logs.take(8).map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(e, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _muted, fontSize: 10, fontWeight: FontWeight.w600)),
              )),
        ]),
      );

  Widget _errorPanel(String msg) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: const Color(0xFFFFF1F2), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFFECACA))),
        child: Row(children: [const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626)), const SizedBox(width: 10), Expanded(child: Text(msg, style: const TextStyle(color: Color(0xFF991B1B), fontWeight: FontWeight.w700)))]),
      );

  Widget _card({required Widget child}) => Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: _line)),
        child: child,
      );

  Widget _sectionTitle(String title, String subtitle) => _StaticSectionTitle(title: title, subtitle: subtitle);

  Widget _pill(String text, {bool active = false}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: active ? _green.withOpacity(.1) : const Color(0xFFF2F4F7), borderRadius: BorderRadius.circular(999), border: Border.all(color: active ? _green.withOpacity(.25) : _line)),
        child: Text(text, style: TextStyle(color: active ? _darkGreen : _muted, fontSize: 11, fontWeight: FontWeight.w900)),
      );

  Widget _deviceTile({required IconData icon, required String title, required String subtitle, required bool active, required bool loading, required VoidCallback onTap}) {
    return InkWell(
      onTap: loading ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: active ? _green.withOpacity(.08) : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: active ? _green.withOpacity(.35) : _line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(icon, color: active ? _darkGreen : _muted, size: 20), const Spacer(), if (loading) const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: _green)) else Icon(active ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded, size: 18, color: active ? _green : _muted)]),
          const SizedBox(height: 9),
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _text, fontWeight: FontWeight.w900, fontSize: 12)),
          const SizedBox(height: 3),
          Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _muted, fontWeight: FontWeight.w700, fontSize: 10)),
        ]),
      ),
    );
  }

  Widget _metric(String title, String value, String unit) => Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _muted, fontWeight: FontWeight.w800, fontSize: 10)),
          const SizedBox(height: 4),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Flexible(child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _text, fontWeight: FontWeight.w900, fontSize: 18))),
            if (unit.isNotEmpty) ...[const SizedBox(width: 4), Padding(padding: const EdgeInsets.only(bottom: 2), child: Text(unit, style: const TextStyle(color: _muted, fontWeight: FontWeight.w800, fontSize: 10)))],
          ]),
        ]),
      );

  static int _asInt(dynamic v) => int.tryParse('${v ?? ''}') ?? (v is num ? v.toInt() : 0);
  static double _asDouble(dynamic v) => double.tryParse('${v ?? ''}') ?? (v is num ? v.toDouble() : 0);

  static String _fmtDistance(double m) => m >= 1000 ? '${(m / 1000).toStringAsFixed(2)} км' : '${m.round()} м';
  static String _fmtDuration(int sec) {
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    final s = sec % 60;
    if (h > 0) return '${h}ч ${m}м';
    if (m > 0) return '${m}м ${s}с';
    return '${s}с';
  }

  static double _haversineM(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) + math.cos(_rad(lat1)) * math.cos(_rad(lat2)) * math.sin(dLon / 2) * math.sin(dLon / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _rad(double d) => d * math.pi / 180.0;
}

class _LiveMovementSummary {
  const _LiveMovementSummary({
    required this.runDistanceM,
    required this.walkDistanceM,
    required this.sprintDistanceM,
    required this.highIntensityDistanceM,
    required this.veryHighIntensityDistanceM,
    required this.runDurationSec,
    required this.walkDurationSec,
    required this.sprintDurationSec,
    required this.runPercent,
    required this.walkPercent,
    required this.sprintCount,
  });

  final double runDistanceM;
  final double walkDistanceM;
  final double sprintDistanceM;
  final double highIntensityDistanceM;
  final double veryHighIntensityDistanceM;
  final int runDurationSec;
  final int walkDurationSec;
  final int sprintDurationSec;
  final double runPercent;
  final double walkPercent;
  final int sprintCount;

  factory _LiveMovementSummary.fromPoints(
    List<ActionTrackerGpsPoint> points, {
    required double runThresholdKmh,
    required double sprintThresholdKmh,
  }) {
    var runDistance = 0.0;
    var walkDistance = 0.0;
    var sprintDistance = 0.0;
    var highIntensityDistance = 0.0;
    var veryHighIntensityDistance = 0.0;
    var runSeconds = 0.0;
    var walkSeconds = 0.0;
    var sprintSeconds = 0.0;
    var sprintCount = 0;
    var sprintActive = false;

    for (var i = 1; i < points.length; i++) {
      final previous = points[i - 1];
      final point = points[i];
      var dt = (point.timeMs - previous.timeMs).abs() / 1000.0;
      var distance = point.distanceDeltaM ??
          _distanceM(
            previous.latitude,
            previous.longitude,
            point.latitude,
            point.longitude,
          );
      if (!distance.isFinite || distance < 0) distance = 0;
      distance = distance.clamp(0.0, 2000.0).toDouble();

      var speed = point.speedKmh ?? 0.0;
      if ((!speed.isFinite || speed <= 0.1) && dt > 0 && distance > 0) {
        speed = distance / dt * 3.6;
      }
      if (!speed.isFinite || speed < 0) speed = 0;
      speed = speed > 36.0 ? 0.0 : speed.clamp(0.0, 36.0).toDouble();

      if (!dt.isFinite || dt <= 0 || dt > 300) {
        dt = speed > 0.1 && distance > 0 ? distance / (speed / 3.6) : 0.0;
      }
      dt = dt.clamp(0.0, 300.0).toDouble();

      if (speed >= runThresholdKmh) {
        runDistance += distance;
        runSeconds += dt;
      } else {
        walkDistance += distance;
        walkSeconds += dt;
      }

      if (speed >= 14.0) highIntensityDistance += distance;
      if (speed >= sprintThresholdKmh) {
        sprintDistance += distance;
        veryHighIntensityDistance += distance;
        sprintSeconds += dt;
        if (!sprintActive) sprintCount++;
        sprintActive = true;
      } else if (speed < sprintThresholdKmh * .88) {
        sprintActive = false;
      }
    }

    final movementSeconds = runSeconds + walkSeconds;
    final movementDistance = runDistance + walkDistance;
    final runPercent = movementSeconds > 0
        ? runSeconds / movementSeconds * 100
        : (movementDistance > 0 ? runDistance / movementDistance * 100 : 0.0);
    final walkPercent = movementSeconds > 0
        ? walkSeconds / movementSeconds * 100
        : (movementDistance > 0 ? walkDistance / movementDistance * 100 : 0.0);

    return _LiveMovementSummary(
      runDistanceM: runDistance,
      walkDistanceM: walkDistance,
      sprintDistanceM: sprintDistance,
      highIntensityDistanceM: highIntensityDistance,
      veryHighIntensityDistanceM: veryHighIntensityDistance,
      runDurationSec: runSeconds.round(),
      walkDurationSec: walkSeconds.round(),
      sprintDurationSec: sprintSeconds.round(),
      runPercent: runPercent,
      walkPercent: walkPercent,
      sprintCount: sprintCount,
    );
  }

  static double _distanceM(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earth = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLon = (lon2 - lon1) * math.pi / 180.0;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) *
            math.cos(lat2 * math.pi / 180.0) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return earth * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }
}

class _StaticSectionTitle extends StatelessWidget {
  const _StaticSectionTitle({required this.title, required this.subtitle});
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: _PlayerMyTrainingsScreenState._text, fontWeight: FontWeight.w900, fontSize: 14)),
      const SizedBox(height: 2),
      Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _PlayerMyTrainingsScreenState._muted, fontWeight: FontWeight.w700, fontSize: 11)),
    ]);
  }
}

class _PolarPickerSheet extends StatelessWidget {
  const _PolarPickerSheet({required this.initialItems, required this.service, required this.onPick});
  final List<HeartRateBleDevice> initialItems;
  final HeartRateBleService service;
  final Future<void> Function(HeartRateBleDevice device) onPick;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: StreamBuilder<List<HeartRateBleDevice>>(
        stream: service.devicesStream,
        initialData: initialItems.isEmpty ? service.connectedInfos : initialItems,
        builder: (context, snap) {
          final items = snap.data ?? const <HeartRateBleDevice>[];
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Выберите Polar / пульсометр', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              const SizedBox(height: 8),
              if (items.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('Пульсометры пока не найдены. Проверьте Bluetooth и наденьте датчик.')),
              ...items.map((d) => ListTile(
                    leading: const Icon(Icons.favorite_rounded, color: _PlayerMyTrainingsScreenState._green),
                    title: Text(d.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text('${d.id} · RSSI ${d.rssi}'),
                    onTap: () => onPick(d),
                  )),
            ]),
          );
        },
      ),
    );
  }
}

class _GpsPickerSheet extends StatelessWidget {
  const _GpsPickerSheet({required this.initialItems, required this.service, required this.onPick});
  final List<ActionTrackerDevice> initialItems;
  final ActionTrackerBleService service;
  final Future<void> Function(ActionTrackerDevice device) onPick;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: StreamBuilder<List<ActionTrackerDevice>>(
        stream: service.devicesStream,
        initialData: initialItems,
        builder: (context, snap) {
          final items = snap.data ?? const <ActionTrackerDevice>[];
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Выберите GPS-трекер', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              const SizedBox(height: 8),
              if (items.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('GPS-трекеры пока не найдены в списке выбора. Если в журнале сверху видны BLE PROBE/GPS TRACKER, закройте окно и нажмите GPS-трекер ещё раз — список берётся из кеша поиска.')),
              ...items.map((d) => ListTile(
                    leading: const Icon(Icons.gps_fixed_rounded, color: _PlayerMyTrainingsScreenState._green),
                    title: Text(d.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text('${d.id} · RSSI ${d.rssi}'),
                    onTap: () => onPick(d),
                  )),
            ]),
          );
        },
      ),
    );
  }
}

class _PlayerRoutePainter extends CustomPainter {
  _PlayerRoutePainter({
    required this.points,
    required this.heartRate,
    required this.runningMode,
  });

  final List<ActionTrackerGpsPoint> points;
  final List<HeartRateSample> heartRate;
  final bool runningMode;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final bg = Paint()
      ..shader = LinearGradient(
        colors: runningMode
            ? const [Color(0xFFEAF7F0), Color(0xFFDDF1E6)]
            : const [Color(0xFF0B3324), Color(0xFF0F5132)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(18)), bg);

    final mapArea = Rect.fromLTWH(16, 16, size.width - 32, size.height - 32);
    if (runningMode) {
      _drawRunningBackground(canvas, mapArea);
    } else {
      final line = Paint()
        ..color = Colors.white.withOpacity(.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(mapArea, const Radius.circular(14)),
        line,
      );
      canvas.drawLine(
        Offset(mapArea.center.dx, mapArea.top),
        Offset(mapArea.center.dx, mapArea.bottom),
        line,
      );
      canvas.drawCircle(
        mapArea.center,
        math.min(mapArea.width, mapArea.height) * .13,
        line,
      );
    }

    if (points.isNotEmpty) {
      final positions = _routePositions(points, mapArea.deflate(13));
      if (positions.length >= 2) {
        final shadow = Paint()
          ..color = runningMode
              ? const Color(0xFF087846).withOpacity(.16)
              : Colors.black.withOpacity(.18)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round;
        for (var i = 1; i < positions.length; i++) {
          canvas.drawLine(positions[i - 1], positions[i], shadow);
        }
        for (var i = 1; i < positions.length; i++) {
          final speed = points[i].speedKmh ?? 0.0;
          final color = speed >= 18
              ? const Color(0xFFF97316)
              : speed >= 7
                  ? const Color(0xFF00A750)
                  : runningMode
                      ? const Color(0xFF4F8FCC)
                      : Colors.white.withOpacity(.92);
          canvas.drawLine(
            positions[i - 1],
            positions[i],
            Paint()
              ..color = color
              ..style = PaintingStyle.stroke
              ..strokeWidth = runningMode ? 3.8 : 2.8
              ..strokeCap = StrokeCap.round,
          );
        }
      }

      final start = positions.first;
      canvas.drawCircle(start, 6.5, Paint()..color = Colors.white);
      canvas.drawCircle(start, 3.8, Paint()..color = const Color(0xFF087846));

      final last = positions.last;
      canvas.drawCircle(
        last,
        13,
        Paint()..color = const Color(0xFF00A750).withOpacity(.16),
      );
      canvas.drawCircle(last, 8, Paint()..color = Colors.white);
      canvas.drawCircle(last, 5.3, Paint()..color = const Color(0xFF00A750));
      return;
    }

    if (heartRate.length >= 2) {
      final graph = mapArea.deflate(10);
      final maxBpm = heartRate.map((e) => e.bpm).reduce(math.max).clamp(120, 210);
      final minBpm = heartRate.map((e) => e.bpm).reduce(math.min).clamp(40, maxBpm - 1);
      final path = Path();
      for (var i = 0; i < heartRate.length; i++) {
        final x = graph.left + (graph.width * i / math.max(1, heartRate.length - 1));
        final y = graph.bottom - (graph.height * (heartRate[i].bpm - minBpm) / math.max(1, maxBpm - minBpm));
        if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
      }
      canvas.drawPath(path, Paint()
        ..color = const Color(0xFFFF4D67)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round);
      return;
    }

    final tp = TextPainter(
      text: TextSpan(
        text: runningMode
            ? 'Определяем старт маршрута…'
            : 'После старта здесь появятся точки GPS или график ЧСС',
        style: TextStyle(
          color: runningMode
              ? const Color(0xFF087846)
              : Colors.white70,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: size.width - 48);
    tp.paint(canvas, Offset((size.width - tp.width) / 2, (size.height - tp.height) / 2));
  }

  void _drawRunningBackground(Canvas canvas, Rect area) {
    final minor = Paint()
      ..color = const Color(0xFF8EC7A8).withOpacity(.18)
      ..strokeWidth = 1;
    for (var x = area.left; x <= area.right; x += 34) {
      canvas.drawLine(Offset(x, area.top), Offset(x, area.bottom), minor);
    }
    for (var y = area.top; y <= area.bottom; y += 34) {
      canvas.drawLine(Offset(area.left, y), Offset(area.right, y), minor);
    }

    final road = Paint()
      ..color = Colors.white.withOpacity(.68)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;
    final roadEdge = Paint()
      ..color = const Color(0xFFB5DCC6).withOpacity(.62)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    final pathA = Path()
      ..moveTo(area.left - 8, area.top + area.height * .86)
      ..cubicTo(
        area.left + area.width * .26,
        area.top + area.height * .72,
        area.left + area.width * .62,
        area.top + area.height * .32,
        area.right + 8,
        area.top + area.height * .22,
      );
    canvas.drawPath(pathA, roadEdge);
    canvas.drawPath(pathA, road);

    final pathB = Path()
      ..moveTo(area.left + area.width * .18, area.top - 8)
      ..cubicTo(
        area.left + area.width * .28,
        area.top + area.height * .28,
        area.left + area.width * .72,
        area.top + area.height * .64,
        area.right - area.width * .08,
        area.bottom + 8,
      );
    canvas.drawPath(pathB, roadEdge);
    canvas.drawPath(pathB, road);
  }

  List<Offset> _routePositions(
    List<ActionTrackerGpsPoint> source,
    Rect area,
  ) {
    final meanLat = source.fold<double>(0, (sum, p) => sum + p.latitude) /
        math.max(1, source.length);
    final metersPerLon = 111320.0 *
        math.cos(meanLat * math.pi / 180).abs().clamp(.2, 1.0).toDouble();
    const metersPerLat = 111320.0;
    final origin = source.first;
    final projected = source
        .map(
          (p) => Offset(
            (p.longitude - origin.longitude) * metersPerLon,
            (p.latitude - origin.latitude) * metersPerLat,
          ),
        )
        .toList(growable: false);

    var minX = projected.first.dx;
    var maxX = projected.first.dx;
    var minY = projected.first.dy;
    var maxY = projected.first.dy;
    for (final p in projected) {
      minX = math.min(minX, p.dx);
      maxX = math.max(maxX, p.dx);
      minY = math.min(minY, p.dy);
      maxY = math.max(maxY, p.dy);
    }
    final spanX = math.max(55.0, maxX - minX);
    final spanY = math.max(55.0, maxY - minY);
    final scale = math.min(area.width / spanX, area.height / spanY);
    final centerX = (minX + maxX) / 2;
    final centerY = (minY + maxY) / 2;
    return projected
        .map(
          (p) => Offset(
            area.center.dx + (p.dx - centerX) * scale,
            area.center.dy - (p.dy - centerY) * scale,
          ),
        )
        .toList(growable: false);
  }

  @override
  bool shouldRepaint(covariant _PlayerRoutePainter oldDelegate) => true;
}
