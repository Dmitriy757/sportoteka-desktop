import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;


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


class PlayerTrainingNotificationsPanel extends StatefulWidget {
  const PlayerTrainingNotificationsPanel({
    super.key,
    required this.teamId,
    this.apiBaseUrl = 'https://sportotekaapp.ru/api/tracker',
    this.onOpenAnalytics,
    this.onOpenReport,
    this.playerDirectory = const <int, Map<String, String>>{},
  });

  final int teamId;
  final String apiBaseUrl;
  final ValueChanged<Map<String, dynamic>>? onOpenAnalytics;
  final ValueChanged<Map<String, dynamic>>? onOpenReport;
  /// Справочник состава: playerId -> {name, avatar}. Используется, когда API
  /// возвращает техническое имя вроде «Игрок 181».
  final Map<int, Map<String, String>> playerDirectory;

  @override
  State<PlayerTrainingNotificationsPanel> createState() => _PlayerTrainingNotificationsPanelState();
}

class _PlayerTrainingNotificationsPanelState extends State<PlayerTrainingNotificationsPanel> {
  static const _green = Color(0xFF00A750);
  static const _greenSoft = Color(0xFFF3FAF6);
  static const _text = Color(0xFF101828);
  static const _muted = Color(0xFF6B746E);
  static const _line = Color(0xFFE1E5E2);
  static const _soft = Color(0xFFF8F9F8);
  static const _red = Color(0xFFDC2626);
  static const _blue = Color(0xFF2563EB);
  static const _orange = Color(0xFFF59E0B);

  Timer? _timer;
  Timer? _clockTimer;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _live = const [];
  List<Map<String, dynamic>> _events = const [];
  Map<int, Map<String, String>> _resolvedDirectory = const <int, Map<String, String>>{};
  // Общая Live-история не сбрасывается при выходе из раздела и возврате.
  static final Map<String, List<_HrPoint>> _liveHrHistory = <String, List<_HrPoint>>{};
  static final Map<String, List<_LoadPoint>> _liveLoadHistory = <String, List<_LoadPoint>>{};
  static final Map<String, List<_GpsPoint>> _liveGpsHistory = <String, List<_GpsPoint>>{};
  final Map<String, GlobalKey> _liveCardKeys = <String, GlobalKey>{};
  int _eventDayOffset = 0;

  @override
  void initState() {
    super.initState();
    _resolvedDirectory = Map<int, Map<String, String>>.from(widget.playerDirectory);
    _load();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _load(silent: true));
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _live.isNotEmpty) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant PlayerTrainingNotificationsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playerDirectory != widget.playerDirectory) {
      _resolvedDirectory = <int, Map<String, String>>{..._resolvedDirectory, ...widget.playerDirectory};
    }
    if (oldWidget.teamId != widget.teamId || oldWidget.apiBaseUrl != widget.apiBaseUrl) _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (widget.teamId <= 0) return;
    if (!silent && mounted) setState(() { _loading = true; _error = null; });

    try {
      final liveUri = Uri.parse('${widget.apiBaseUrl}/player_get_live_state.php').replace(queryParameters: {
        'team_id': '${widget.teamId}', 'personal_session': '1', 'active_only': '1', 'limit': '50',
      });
      final eventsUri = Uri.parse('${widget.apiBaseUrl}/player_get_training_notifications.php').replace(queryParameters: {
        'team_id': '${widget.teamId}', 'limit': '100', 'days': '7',
      });
      final playersUri = Uri.parse('${widget.apiBaseUrl}/get_tracker_players.php').replace(queryParameters: {
        'team_id': '${widget.teamId}',
      });

      // Live — главный запрос. Ошибки вспомогательных endpoint больше не
      // уничтожают весь экран и не выводят красную ClientException сверху.
      final liveResponse = await http.get(liveUri).timeout(const Duration(seconds: 10));
      final liveJson = _decode(liveResponse.body);
      if (liveResponse.statusCode < 200 || liveResponse.statusCode >= 300 || liveJson['success'] == false) {
        throw Exception(liveJson['message'] ?? 'Ошибка Live API');
      }

      Map<String, dynamic> eventJson = const <String, dynamic>{};
      Map<String, dynamic> playersJson = const <String, dynamic>{};
      try {
        final response = await http.get(eventsUri).timeout(const Duration(seconds: 7));
        if (response.statusCode >= 200 && response.statusCode < 300) eventJson = _decode(response.body);
      } catch (_) {
        // Сохраняем уже показанные уведомления при временном обрыве соединения.
      }
      try {
        final response = await http.get(playersUri).timeout(const Duration(seconds: 7));
        if (response.statusCode >= 200 && response.statusCode < 300) playersJson = _decode(response.body);
      } catch (_) {
        // Имена и аватары остаются из предыдущего успешного обновления.
      }

      final directory = <int, Map<String, String>>{..._resolvedDirectory, ...widget.playerDirectory};
      final playersRaw = playersJson['players'] as List? ?? playersJson['items'] as List? ?? const [];
      for (final raw in playersRaw.whereType<Map>()) {
        final item = Map<String, dynamic>.from(raw);
        final id = _parsePositiveInt(item['id'] ?? item['player_id']);
        final userId = _parsePositiveInt(item['user_id'] ?? item['owner_user_id']);
        final name = _readText(item, const ['player_name', 'full_name', 'name'], fallback: '');
        final first = _readText(item, const ['first_name', 'player_first_name'], fallback: '');
        final last = _readText(item, const ['last_name', 'surname', 'player_last_name'], fallback: '');
        final resolvedName = (last.isNotEmpty || first.isNotEmpty) ? '$last $first'.trim() : name;
        final avatar = _readText(item, const ['avatar_url', 'avatar', 'photo_url', 'user_photo', 'photo'], fallback: '');
        final value = <String, String>{'name': resolvedName, 'avatar': avatar};
        if (id != null) directory[id] = value;
        if (userId != null) directory[userId] = value;
      }

      final liveRaw = liveJson['sessions'] as List? ??
          liveJson['live_sessions'] as List? ??
          liveJson['active_sessions'] as List? ??
          liveJson['items'] as List? ?? const [];
      final eventsRaw = eventJson['notifications'] as List? ?? eventJson['items'] as List? ?? const [];
      final baseLive = liveRaw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).where(_isActivePersonalLive).toList();
      final live = await Future.wait(baseLive.map((source) async {
        final row = await _enrichLiveRow(source);
        await _enrichGpsRow(row);
        _rememberLiveTelemetry(row);
        return row;
      }));
      final events = eventsRaw.isEmpty
          ? _events
          : eventsRaw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

      if (!mounted) return;
      setState(() {
        _resolvedDirectory = directory;
        _live = live;
        _events = events;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      // Фоновое обновление не должно мигать ошибкой и убирать уже загруженные данные.
      if (silent) return;
      setState(() { _loading = false; _error = 'Не удалось обновить Live. Проверьте соединение.'; });
    }
  }



  Map<String, dynamic> _flattenLivePayload(Map<String, dynamic> source) {
    final row = Map<String, dynamic>.from(source);

    void mergeDynamic(dynamic raw) {
      if (raw == null) return;
      dynamic value = raw;
      if (value is String && value.trim().isNotEmpty) {
        try {
          value = jsonDecode(value);
        } catch (_) {
          return;
        }
      }
      if (value is Map) {
        final map = Map<String, dynamic>.from(value);
        for (final entry in map.entries) {
          final current = row[entry.key];
          if (current == null || '$current'.trim().isEmpty || '$current' == '0') {
            row[entry.key] = entry.value;
          }
        }
        for (final nestedKey in const ['snapshot', 'metrics', 'heart_rate', 'polar', 'latest', 'live']) {
          mergeDynamic(map[nestedKey]);
        }
      }
    }

    for (final key in const [
      'snapshot',
      'snapshot_json',
      'analysis',
      'analysis_json',
      'metrics',
      'metrics_json',
      'live_data',
      'latest_data',
    ]) {
      mergeDynamic(row[key]);
    }

    // Серверные версии используют разные названия текущего HR.
    row['last_heart_rate_bpm'] ??= row['current_hr'];
    row['last_heart_rate_bpm'] ??= row['heart_rate'];
    row['last_heart_rate_bpm'] ??= row['last_hr'];
    row['last_heart_rate_bpm'] ??= row['polar_bpm'];
    row['heart_rate_samples'] ??= row['hr_history'];
    row['heart_rate_samples'] ??= row['polar_history'];
    row['heart_rate_samples'] ??= row['samples'];

    return row;
  }

  Future<Map<String, dynamic>> _enrichLiveRow(Map<String, dynamic> source) async {
    final row = _flattenLivePayload(source);
    final existing = _heartRateSamples(row);
    final currentHr = _int(row, const [
      'last_heart_rate_bpm',
      'heart_rate_bpm',
      'bpm',
      'current_bpm',
      'latest_bpm',
      'hr',
    ]);
    if (existing.isNotEmpty && currentHr > 0) return row;

    final liveId = _int(row, const ['live_session_id', 'id', 'tracker_live_session_id']);
    final sessionId = _int(row, const ['session_id', 'final_session_id', 'tracker_session_id']);
    if (liveId <= 0 && sessionId <= 0) return row;

    try {
      final query = <String, String>{
        'team_id': '${widget.teamId}',
        if (liveId > 0) 'live_session_id': '$liveId',
        if (sessionId > 0) 'session_id': '$sessionId',
        // Не кэшировать Live-график CDN/браузером.
        '_ts': '${DateTime.now().millisecondsSinceEpoch}',
      };
      final uri = Uri.parse('${widget.apiBaseUrl}/player_get_session_heart_rate.php')
          .replace(queryParameters: query);
      final response = await http.get(
        uri,
        headers: const {'Cache-Control': 'no-cache'},
      ).timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) return row;

      final json = _decode(response.body);
      if (json['success'] == false) return row;

      final samples = json['samples'] ??
          json['heart_rate_samples'] ??
          json['hr_samples'] ??
          json['points'] ??
          (json['data'] is Map ? (json['data'] as Map)['samples'] : null);
      if (samples is List && samples.isNotEmpty) {
        row['heart_rate_samples'] = samples;
      }

      final summary = json['summary'] is Map
          ? Map<String, dynamic>.from(json['summary'] as Map)
          : <String, dynamic>{};
      final latest = json['last_bpm'] ??
          json['current_bpm'] ??
          json['latest_bpm'] ??
          summary['last_bpm'] ??
          summary['max_bpm'];
      if (_parsePositiveInt(latest) != null) {
        row['last_heart_rate_bpm'] = latest;
      } else if (samples is List && samples.isNotEmpty) {
        final last = samples.last;
        if (last is Map) {
          row['last_heart_rate_bpm'] =
              last['bpm'] ?? last['heart_rate_bpm'] ?? last['value'];
        }
      }

      row['avg_heart_rate_bpm'] =
          json['avg_bpm'] ?? summary['avg_bpm'] ?? row['avg_heart_rate_bpm'];
      row['max_heart_rate_bpm'] =
          json['max_bpm'] ?? summary['max_bpm'] ?? row['max_heart_rate_bpm'];
      row['min_heart_rate_bpm'] =
          json['min_bpm'] ?? summary['min_bpm'] ?? row['min_heart_rate_bpm'];
      row['heart_rate_samples_count'] =
          json['samples_count'] ?? summary['samples_count'] ?? (samples is List ? samples.length : 0);

      if (_heartRateSamples(row).isEmpty && liveId > 0) {
        await _tryLiveHeartRateFallback(row, liveId);
      }
      return row;
    } catch (_) {
      if (liveId > 0) {
        await _tryLiveHeartRateFallback(row, liveId);
      }
      // Live-карточка всё равно должна остаться видимой, даже если endpoint
      // истории Polar временно недоступен.
      return row;
    }
  }

  Future<void> _tryLiveHeartRateFallback(Map<String, dynamic> row, int liveId) async {
    for (final endpoint in const [
      'player_check_session_heart_rate.php',
      'player_get_live_heart_rate.php',
    ]) {
      try {
        final uri = Uri.parse('${widget.apiBaseUrl}/$endpoint').replace(
          queryParameters: {
            'live_session_id': '$liveId',
            'team_id': '${widget.teamId}',
            '_ts': '${DateTime.now().millisecondsSinceEpoch}',
          },
        );
        final response = await http.get(
          uri,
          headers: const {'Cache-Control': 'no-cache'},
        ).timeout(const Duration(seconds: 5));
        if (response.statusCode < 200 || response.statusCode >= 300) continue;
        final json = _decode(response.body);
        final hr = json['heart_rate'] is Map
            ? Map<String, dynamic>.from(json['heart_rate'] as Map)
            : <String, dynamic>{};
        final samples = json['samples'] ?? json['points'] ?? hr['samples'];
        if (samples is List && samples.isNotEmpty) {
          row['heart_rate_samples'] = samples;
        }
        row['last_heart_rate_bpm'] ??=
            json['last_bpm'] ?? hr['last_bpm'] ?? hr['max_bpm'];
        row['avg_heart_rate_bpm'] ??= json['avg_bpm'] ?? hr['avg_bpm'];
        row['max_heart_rate_bpm'] ??= json['max_bpm'] ?? hr['max_bpm'];
        row['heart_rate_samples_count'] ??=
            json['samples_count'] ?? hr['samples_count'];
        if (_int(row, const ['last_heart_rate_bpm', 'current_bpm', 'bpm']) > 0 ||
            _heartRateSamples(row).isNotEmpty) {
          return;
        }
      } catch (_) {}
    }
  }


  String _liveKey(Map<String, dynamic> row) {
    final liveId = _int(row, const ['live_session_id', 'id', 'tracker_live_session_id']);
    if (liveId > 0) return 'live:$liveId';
    final sessionId = _int(row, const ['session_id', 'final_session_id', 'tracker_session_id']);
    if (sessionId > 0) return 'session:$sessionId';
    final playerId = _int(row, const ['player_id', 'owner_user_id', 'user_id']);
    return 'player:$playerId';
  }

  void _rememberLiveTelemetry(Map<String, dynamic> row) {
    final key = _liveKey(row);
    final incomingHr = _heartRateSamples(row);
    final history = _liveHrHistory.putIfAbsent(key, () => <_HrPoint>[]);
    for (final point in incomingHr) {
      final duplicate = history.any((old) =>
          (old.sec - point.sec).abs() < .2 && (old.bpm - point.bpm).abs() < .1);
      if (!duplicate) history.add(point);
    }
    final current = _int(row, const [
      'last_heart_rate_bpm', 'heart_rate_bpm', 'bpm', 'current_bpm', 'latest_bpm', 'hr',
    ]);
    if (current > 0) {
      final sec = math.max(
        _sessionDuration(row).toDouble(),
        history.isEmpty ? 0.0 : history.last.sec + 1.0,
      );
      final last = history.isEmpty ? null : history.last;
      if (last == null || (last.bpm - current).abs() > .1 || sec - last.sec >= .8) {
        history.add(_HrPoint(sec: sec, bpm: current.toDouble()));
      }
    }
    history.sort((a, b) => a.sec.compareTo(b.sec));
    if (history.length > 7200) history.removeRange(0, history.length - 7200);
    if (history.isNotEmpty) {
      row['heart_rate_samples'] = history
          .map((p) => <String, dynamic>{'elapsed_sec': p.sec, 'bpm': p.bpm})
          .toList(growable: false);
    }

    final loadValue = _num(row, const ['player_load', 'load', 'total_load', 'mechanical_load']);
    if (loadValue > 0) {
      final loadHistory = _liveLoadHistory.putIfAbsent(key, () => <_LoadPoint>[]);
      final sec = history.isNotEmpty ? history.last.sec : _sessionDuration(row).toDouble();
      final lastLoad = loadHistory.isEmpty ? null : loadHistory.last;
      if (lastLoad == null || (lastLoad.value - loadValue).abs() >= 0.5) {
        loadHistory.add(_LoadPoint(sec: sec, value: loadValue));
      }
      if (loadHistory.length > 2000) loadHistory.removeRange(0, loadHistory.length - 2000);
      row['load_samples'] = loadHistory
          .map((e) => <String, dynamic>{'sec': e.sec, 'value': e.value})
          .toList(growable: false);
    }

    final gps = _gpsSamples(row);
    if (gps.isNotEmpty) {
      final gpsHistory = _liveGpsHistory.putIfAbsent(key, () => <_GpsPoint>[]);
      for (final point in gps) {
        final duplicate = gpsHistory.any((old) =>
            (old.lat - point.lat).abs() < 0.0000001 &&
            (old.lon - point.lon).abs() < 0.0000001);
        if (!duplicate) gpsHistory.add(point);
      }
      if (gpsHistory.length > 3000) gpsHistory.removeRange(0, gpsHistory.length - 3000);
      row['gps_points'] = gpsHistory
          .map((p) => <String, dynamic>{'latitude': p.lat, 'longitude': p.lon})
          .toList(growable: false);
    }
  }

  Future<void> _enrichArchivedAnalytics(Map<String, dynamic> row) async {
    final sessionId = _int(row, const ['session_id', 'final_session_id', 'tracker_session_id', 'id']);
    final playerId = _int(row, const ['player_id', 'owner_user_id', 'user_id']);
    if (sessionId <= 0 && playerId <= 0) return;
    try {
      final uri = Uri.parse('${widget.apiBaseUrl}/player_get_sessions.php').replace(
        queryParameters: <String, String>{
          'team_id': '${widget.teamId}',
          if (playerId > 0) 'player_id': '$playerId',
          if (playerId > 0) 'owner_user_id': '$playerId',
          if (sessionId > 0) 'session_id': '$sessionId',
          'limit': '200',
          '_ts': '${DateTime.now().millisecondsSinceEpoch}',
        },
      );
      final response = await http.get(uri, headers: const {'Cache-Control': 'no-cache'})
          .timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) return;
      final json = _decode(response.body);
      dynamic raw = json['sessions'] ?? json['items'] ?? json['data'];
      if (raw is Map) raw = raw['sessions'] ?? raw['items'] ?? raw['data'];
      if (raw is! List) return;
      Map<String, dynamic>? match;
      for (final item in raw.whereType<Map>()) {
        final candidate = Map<String, dynamic>.from(item);
        final candidateId = _int(candidate, const ['session_id', 'id', 'tracker_session_id']);
        if (sessionId > 0 && candidateId == sessionId) {
          match = candidate;
          break;
        }
      }
      match ??= raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).cast<Map<String, dynamic>?>().firstWhere(
        (e) => e != null,
        orElse: () => null,
      );
      if (match == null) return;
      final flattened = _flattenLivePayload(match);
      for (final entry in flattened.entries) {
        final current = row[entry.key];
        if (current == null || '$current'.trim().isEmpty || '$current' == '0' || '$current' == '0.0') {
          row[entry.key] = entry.value;
        }
      }
    } catch (_) {
      // Окно последнего события остаётся доступным даже при временной ошибке API.
    }
  }

  Future<void> _enrichGpsRow(Map<String, dynamic> row) async {
    final liveId = _int(row, const ['live_session_id', 'id', 'tracker_live_session_id']);
    final sessionId = _int(row, const ['session_id', 'final_session_id', 'tracker_session_id']);
    final playerId = _int(row, const ['player_id', 'owner_user_id', 'user_id']);
    if (liveId <= 0 && sessionId <= 0 && playerId <= 0) return;
    try {
      final uri = Uri.parse('${widget.apiBaseUrl}/player_get_session_points.php').replace(
        queryParameters: <String, String>{
          'team_id': '${widget.teamId}',
          if (liveId > 0) 'live_session_id': '$liveId',
          if (sessionId > 0) 'session_id': '$sessionId',
          if (playerId > 0) 'player_id': '$playerId',
          if (playerId > 0) 'owner_user_id': '$playerId',
          'limit': '3000',
          '_ts': '${DateTime.now().millisecondsSinceEpoch}',
        },
      );
      final response = await http.get(
        uri,
        headers: const {'Cache-Control': 'no-cache'},
      ).timeout(const Duration(seconds: 7));
      if (response.statusCode < 200 || response.statusCode >= 300) return;
      final json = _decode(response.body);
      final points = json['points'] ?? json['gps_points'] ?? json['items'] ??
          (json['data'] is Map ? (json['data'] as Map)['points'] : null);
      if (points is List && points.isNotEmpty) {
        row['gps_points'] = points;
        _applyMovementAnalyticsFromPoints(row, points);
      }
      for (final source in <dynamic>[json['summary'], json['metrics'], json['analytics'], json['data']]) {
        if (source is! Map) continue;
        final flat = _flattenLivePayload(Map<String, dynamic>.from(source));
        for (final entry in flat.entries) {
          final current = row[entry.key];
          if (current == null || '$current'.trim().isEmpty || '$current' == '0' || '$current' == '0.0') {
            row[entry.key] = entry.value;
          }
        }
      }
    } catch (_) {
      // Карточка Live продолжает работать даже при временной ошибке GPS endpoint.
    }
  }

  void _applyMovementAnalyticsFromPoints(Map<String, dynamic> row, List<dynamic> rawPoints) {
    if (rawPoints.length < 2) return;
    var walkDistance = 0.0;
    var runDistance = 0.0;
    var sprintDistance = 0.0;
    var walkSec = 0.0;
    var runSec = 0.0;
    var sprintSec = 0.0;
    var sprintCount = 0;
    var inSprint = false;
    var totalDistance = 0.0;

    double value(Map m, List<String> keys) {
      for (final key in keys) {
        final raw = m[key];
        final parsed = raw is num ? raw.toDouble() : double.tryParse('${raw ?? ''}');
        if (parsed != null && parsed.isFinite) return parsed;
      }
      return 0;
    }
    double haversine(double lat1, double lon1, double lat2, double lon2) {
      const earth = 6371000.0;
      final p1 = lat1 * math.pi / 180;
      final p2 = lat2 * math.pi / 180;
      final dp = (lat2 - lat1) * math.pi / 180;
      final dl = (lon2 - lon1) * math.pi / 180;
      final a = math.sin(dp / 2) * math.sin(dp / 2) +
          math.cos(p1) * math.cos(p2) * math.sin(dl / 2) * math.sin(dl / 2);
      return earth * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    }

    Map<String, dynamic>? previous;
    for (final raw in rawPoints) {
      if (raw is! Map) continue;
      final point = Map<String, dynamic>.from(raw);
      final lat = value(point, const ['latitude', 'lat']);
      final lon = value(point, const ['longitude', 'lng', 'lon']);
      final speed = value(point, const ['speed_kmh', 'speed', 'current_speed_kmh']);
      var delta = value(point, const ['distance_delta_m', 'delta_distance_m', 'segment_distance_m']);
      var dt = value(point, const ['delta_time_sec', 'duration_sec']);
      if (previous != null) {
        if (delta <= 0 && lat.abs() > .000001 && lon.abs() > .000001) {
          final prevLat = value(previous, const ['latitude', 'lat']);
          final prevLon = value(previous, const ['longitude', 'lng', 'lon']);
          if (prevLat.abs() > .000001 && prevLon.abs() > .000001) {
            delta = haversine(prevLat, prevLon, lat, lon).clamp(0, 80).toDouble();
          }
        }
        if (dt <= 0) {
          final t = value(point, const ['time_ms', 'timestamp_ms', 'measured_at_ms', 'elapsed_ms']);
          final pt = value(previous, const ['time_ms', 'timestamp_ms', 'measured_at_ms', 'elapsed_ms']);
          if (t > pt && pt > 0) dt = ((t - pt) / 1000).clamp(.2, 10).toDouble();
        }
      }
      if (dt <= 0 && speed > 0 && delta > 0) dt = delta / (speed / 3.6);
      dt = dt.clamp(0, 10).toDouble();
      totalDistance += delta;
      if (speed >= 20) {
        sprintDistance += delta;
        sprintSec += dt;
        if (!inSprint) sprintCount++;
        inSprint = true;
      } else if (speed >= 6) {
        runDistance += delta;
        runSec += dt;
        inSprint = false;
      } else {
        walkDistance += delta;
        walkSec += dt;
        inSprint = false;
      }
      previous = point;
    }
    final totalSec = walkSec + runSec + sprintSec;
    if (_num(row, const ['total_distance_m', 'distance_m', 'distance']) <= 0 && totalDistance > 0) {
      row['total_distance_m'] = totalDistance;
    }
    void setIfEmpty(String key, num value) {
      final current = row[key];
      final parsed = current is num ? current.toDouble() : double.tryParse('${current ?? ''}') ?? 0;
      if (parsed <= 0 && value > 0) row[key] = value;
    }
    setIfEmpty('walk_distance_m', walkDistance);
    setIfEmpty('walk_duration_sec', walkSec.round());
    setIfEmpty('run_distance_m', runDistance + sprintDistance);
    setIfEmpty('run_duration_sec', (runSec + sprintSec).round());
    setIfEmpty('sprint_distance_m', sprintDistance);
    setIfEmpty('sprint_duration_sec', sprintSec.round());
    setIfEmpty('sprint_count', sprintCount);
    if (totalSec > 0) {
      setIfEmpty('walk_percent', walkSec / totalSec * 100);
      setIfEmpty('run_percent', (runSec + sprintSec) / totalSec * 100);
    }
  }

  List<_LoadPoint> _loadSamples(Map<String, dynamic> row) {
    final raw = row['load_samples'];
    if (raw is! List) return const <_LoadPoint>[];
    final result = <_LoadPoint>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final m = Map<String, dynamic>.from(item);
      final sec = double.tryParse('${m['sec'] ?? m['time_sec'] ?? 0}') ?? 0;
      final value = double.tryParse('${m['value'] ?? m['load'] ?? 0}') ?? 0;
      if (value > 0) result.add(_LoadPoint(sec: sec, value: value));
    }
    result.sort((a, b) => a.sec.compareTo(b.sec));
    return result;
  }

  String _deviceBattery(Map<String, dynamic> row, List<String> keys) {
    final value = _int(row, keys);
    return value > 0 ? '$value%' : '—';
  }

  String _deviceSignal(Map<String, dynamic> row, List<String> keys) {
    final value = _int(row, keys);
    if (value == 0) return '—';
    if (value > 0 && value <= 4) return List.filled(value, '▮').join();
    return '$value dBm';
  }

  List<_GpsPoint> _gpsSamples(Map<String, dynamic> row) {
    dynamic raw = row['gps_points'] ?? row['route_points'] ?? row['track_points'] ?? row['points'];
    if (raw is String && raw.trim().isNotEmpty) {
      try { raw = jsonDecode(raw); } catch (_) {}
    }
    if (raw is Map) raw = raw['points'] ?? raw['items'] ?? raw['data'];
    final out = <_GpsPoint>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is! Map) continue;
        final lat = double.tryParse('${item['latitude'] ?? item['lat'] ?? item['field_y_m'] ?? item['y_m'] ?? item['y'] ?? ''}');
        final lon = double.tryParse('${item['longitude'] ?? item['lng'] ?? item['lon'] ?? item['field_x_m'] ?? item['x_m'] ?? item['x'] ?? ''}');
        if (lat == null || lon == null || !lat.isFinite || !lon.isFinite) continue;
        if (lat.abs() < .000001 || lon.abs() < .000001) continue;
        out.add(_GpsPoint(
          lat: lat,
          lon: lon,
          speedKmh: double.tryParse('${item['speed_kmh'] ?? item['speed'] ?? 0}') ?? 0,
          elapsedSec: double.tryParse('${item['elapsed_sec'] ?? item['time_sec'] ?? 0}') ?? 0,
        ));
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final count = _live.length;
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_loading)
            const LinearProgressIndicator(color: _green, minHeight: 2),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
              child: _errorBox(_error!),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
            child: _summaryStrip(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 2, 10, 6),
            child: Container(
              constraints: const BoxConstraints(minHeight: 32),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              color: count > 0 ? _green.withOpacity(.055) : _soft,
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: count > 0 ? _green : _muted,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      count > 0
                          ? 'Live сейчас: $count игрок${_plural(count)}'
                          : 'Сейчас активных личных тренировок нет',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _text,
                        fontWeight: FontWeight.w600,
                        fontSize: 10.4,
                      ),
                    ),
                  ),
                  Text(
                    _lastUpdatedLabel(),
                    style: const TextStyle(
                      color: _muted,
                      fontWeight: FontWeight.w500,
                      fontSize: 9.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!_loading && _error == null && _live.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: _emptyState(),
            ),
          if (_live.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 2, 10, 0),
              child: _liveStrip(_live),
            ),
          if (_events.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: _recentEvents(_events),
            ),
        ],
      ),
    );
  }

  Widget _liveStrip(List<Map<String, dynamic>> rows) {
    for (final row in rows) {
      _liveCardKeys.putIfAbsent(_liveKey(row), () => GlobalKey());
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 66,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 2),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final row = rows[index];
              final name = _playerName(row);
              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  final target = _liveCardKeys[_liveKey(row)]?.currentContext;
                  if (target != null) {
                    Scrollable.ensureVisible(
                      target,
                      duration: const Duration(milliseconds: 420),
                      curve: Curves.easeOutCubic,
                      alignment: .05,
                    );
                  }
                },
                child: Container(
                  width: 94,
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                  decoration: BoxDecoration(
                    color: _greenSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          _avatar(_avatarUrl(row), size: 34),
                          const Positioned(
                            right: -1,
                            bottom: -1,
                            child: DecoratedBox(
                              decoration: BoxDecoration(color: _green, shape: BoxShape.circle, border: Border.fromBorderSide(BorderSide(color: Colors.white, width: 2))),
                              child: SizedBox(width: 10, height: 10),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: _text, fontWeight: FontWeight.w700, fontSize: 9.4),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: rows.length,
          separatorBuilder: (_, __) => const Divider(height: 18, thickness: 1, color: _line),
          itemBuilder: (context, index) {
            final row = rows[index];
            return KeyedSubtree(
              key: _liveCardKeys[_liveKey(row)],
              child: SizedBox(
                width: double.infinity,
                child: _liveCard(row),
              ),
            );
          },
        ),
      ],
    );
  }


  Widget _trackerMiniInfo({
    required IconData icon,
    required String value,
    required String tooltip,
  }) {
    final hasValue = value.trim().isNotEmpty && value.trim() != '—';
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.86),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: const Color(0xFFD8EEE2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: hasValue ? _green : _muted),
            const SizedBox(width: 3),
            Text(
              hasValue ? value : '—',
              style: TextStyle(
                color: hasValue ? _text : _muted,
                fontWeight: FontWeight.w800,
                fontSize: 8.8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _liveCard(Map<String, dynamic> row, {bool archived = false}) {
    final name = _playerName(row);
    final avatar = _avatarUrl(row);
    final hr = _int(row, const [
      'last_heart_rate_bpm',
      'heart_rate_bpm',
      'bpm',
      'current_bpm',
    ]);
    final serverDuration = _int(row, const [
      'duration_sec',
      'duration_seconds',
      'elapsed_sec',
      'live_duration_sec',
    ]);
    final duration = _displayDurationSeconds(
      row,
      serverDuration: serverDuration,
      archived: archived,
    );
    final distance = _num(row, const [
      'total_distance_m',
      'distance_m',
      'distance',
      'session_distance_m',
    ]);
    final speed = _num(row, const [
      'speed_kmh',
      'last_speed_kmh',
      'current_speed_kmh',
    ]);
    final maxSpeed = _num(row, const [
      'max_speed_kmh',
      'top_speed_kmh',
      'max_speed',
    ]);
    final load = _num(row, const ['load_score', 'player_load', 'load']);
    final aiLoad = _num(row, const ['ai_load', 'ai_load_score']);
    final samples = _heartRateSamples(row);
    final sprintCount = _int(row, const ['sprint_count', 'sprints', 'spr']);
    final gpsPoints = _gpsSamples(row);
    final hasGps = gpsPoints.isNotEmpty ||
        _sourceLabel(row).toLowerCase().contains('gps') ||
        distance > 0;
    final trackerSignal = _deviceSignal(
      row,
      const ['gps_rssi', 'tracker_rssi', 'signal_dbm', 'rssi'],
    );
    final trackerBattery = _deviceBattery(
      row,
      const ['gps_battery', 'tracker_battery', 'battery_percent', 'battery'],
    );

    final averageHr = samples.isEmpty
        ? hr.toDouble()
        : samples.fold<double>(0, (sum, point) => sum + point.bpm) / samples.length;
    final calculatedAiLoad = _calculateAiLoadIndex(
      load: load,
      averageHr: averageHr,
      maxSpeed: math.max(speed, maxSpeed),
      sprintCount: sprintCount,
      durationSec: duration,
      distanceM: distance,
    );
    final displayAiLoad = aiLoad > 0
        ? aiLoad.clamp(0, 100).toDouble()
        : calculatedAiLoad;
    final locationLabel = _readText(
      row,
      const ['location_name', 'venue_name', 'field_name', 'place_name', 'city'],
      fallback: '',
    );
    final airTemperature = _num(
      row,
      const ['air_temperature_c', 'temperature_c', 'weather_temperature_c', 'temperature'],
    );

    final loadLow = _percentage(row, const ['load_low_percent', 'load_zone_1_percent', 'low_load_percent']);
    final loadModerate = _percentage(row, const ['load_moderate_percent', 'load_zone_2_percent', 'moderate_load_percent']);
    final loadHigh = _percentage(row, const ['load_high_percent', 'load_zone_3_percent', 'high_load_percent']);
    var loadVeryHigh = _percentage(row, const ['load_very_high_percent', 'load_zone_4_percent', 'very_high_load_percent']);
    var resolvedLoadLow = loadLow;
    var resolvedLoadModerate = loadModerate;
    var resolvedLoadHigh = loadHigh;
    var resolvedLoadVeryHigh = loadVeryHigh;
    if (resolvedLoadLow + resolvedLoadModerate + resolvedLoadHigh + resolvedLoadVeryHigh <= 0 && samples.isNotEmpty) {
      final zones = _deriveIntensityZones(samples);
      resolvedLoadLow = zones[0];
      resolvedLoadModerate = zones[1];
      resolvedLoadHigh = zones[2];
      resolvedLoadVeryHigh = zones[3];
    }

    final sprintDistance = _num(row, const ['sprint_distance_m', 'sprints_distance_m']);
    final sprintDuration = _int(row, const ['sprint_duration_sec', 'sprint_time_sec']);
    final runPercent = _percentage(row, const ['run_percent', 'running_percent']);
    final runDistance = _num(row, const ['run_distance_m', 'running_distance_m']);
    final runDuration = _int(row, const ['run_duration_sec', 'running_time_sec']);
    final walkPercent = _percentage(row, const ['walk_percent', 'walking_percent']);
    final walkDistance = _num(row, const ['walk_distance_m', 'walking_distance_m']);
    final walkDuration = _int(row, const ['walk_duration_sec', 'walking_time_sec']);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final sideBySide = constraints.maxWidth >= 360;
          final compact = constraints.maxWidth < 560;
          final metricColumns = constraints.maxWidth >= 900 ? 7 : (constraints.maxWidth >= 560 ? 4 : 3);
          final metricWidth = (constraints.maxWidth - ((metricColumns - 1) * 8)) / metricColumns;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!compact)
                Row(
                  children: [
                    _avatar(avatar, size: 48),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _text,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            archived ? _archiveStatusChip() : _liveDot(),
                            const SizedBox(width: 8),
                            Flexible(
                              child: _headerMetaChip(
                                Icons.place_outlined,
                                locationLabel.isNotEmpty ? locationLabel : 'Место определяется',
                              ),
                            ),
                            const SizedBox(width: 6),
                            _headerMetaChip(
                              Icons.device_thermostat_rounded,
                              airTemperature != 0
                                  ? '${airTemperature.toStringAsFixed(airTemperature == airTemperature.roundToDouble() ? 0 : 1)} °C'
                                  : 'Погода —',
                            ),

                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${_activityLabel(row)} · ${_sourceLabel(row)}',
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (hasGps)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1FBF5),
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: const Color(0xFFCDEEDA)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.sensors_rounded, size: 17, color: _green),
                          const SizedBox(width: 6),
                          Text(archived ? 'Трекер подключался' : 'Трекер онлайн', style: const TextStyle(color: _green, fontWeight: FontWeight.w600, fontSize: 11)),
                          const SizedBox(width: 12),
                          _trackerMiniInfo(icon: Icons.network_cell_rounded, value: trackerSignal, tooltip: 'Сигнал трекера'),
                          const SizedBox(width: 6),
                          _trackerMiniInfo(icon: Icons.battery_5_bar_rounded, value: trackerBattery, tooltip: 'Заряд трекера'),
                        ],
                      ),
                    ),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        _avatar(avatar, size: 42),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _text, fontWeight: FontWeight.w600, fontSize: 14)),
                                  ),
                                  const SizedBox(width: 6),
                                  archived ? _archiveStatusChip() : _liveDot(),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_activityLabel(row)} · ${_sourceLabel(row)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: _muted, fontSize: 9.5, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  _headerMetaChip(
                                    Icons.place_outlined,
                                    locationLabel.isNotEmpty ? locationLabel : 'Место определяется',
                                    compact: true,
                                  ),
                                  _headerMetaChip(
                                    Icons.device_thermostat_rounded,
                                    airTemperature != 0
                                        ? '${airTemperature.toStringAsFixed(airTemperature == airTemperature.roundToDouble() ? 0 : 1)} °C'
                                        : 'Погода —',
                                    compact: true,
                                  ),

                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (hasGps) ...[
                      const SizedBox(height: 7),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                        decoration: BoxDecoration(color: const Color(0xFFF1FBF5), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFCDEEDA))),
                        child: Row(
                          children: [
                            const Icon(Icons.sensors_rounded, size: 15, color: _green),
                            const SizedBox(width: 5),
                            Expanded(child: Text(archived ? 'Трекер подключался' : 'Трекер онлайн', style: const TextStyle(color: _green, fontWeight: FontWeight.w600, fontSize: 10.2))),
                            _trackerMiniInfo(icon: Icons.network_cell_rounded, value: trackerSignal, tooltip: 'Сигнал трекера'),
                            const SizedBox(width: 5),
                            _trackerMiniInfo(icon: Icons.battery_5_bar_rounded, value: trackerBattery, tooltip: 'Заряд трекера'),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _topMetricCard('Начало', _startTime(row), Icons.schedule_rounded, width: metricWidth, compact: compact),
                  _topMetricCard('Длительность', _duration(duration), Icons.timer_outlined, width: metricWidth, compact: compact),
                  _topMetricCard('Дистанция', _meters(distance), Icons.location_on_outlined, width: metricWidth, compact: compact),
                  _topMetricCard('Скорость', '${speed.toStringAsFixed(1)} км/ч', Icons.speed_rounded, width: metricWidth, compact: compact),
                  _topMetricCard('Макс. скорость', '${math.max(speed, maxSpeed).toStringAsFixed(1)} км/ч', Icons.speed_rounded, width: metricWidth, compact: compact),
                  _loadMetricCard(
                    title: 'Нагрузка',
                    value: load,
                    width: metricWidth,
                    compact: compact,
                    description: 'Суммарная внешняя нагрузка трекера. Используется для сравнения тренировок одного игрока между собой.',
                  ),
                  _loadMetricCard(
                    title: 'AI индекс',
                    value: displayAiLoad,
                    width: metricWidth,
                    compact: compact,
                    isAi: true,
                    description: 'Индекс 0–100 рассчитан по фактическим данным: длительности, дистанции, скорости, пульсу, спринтам и нагрузке трекера. Это спортивный ориентир, а не медицинская оценка.',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: sideBySide ? (compact ? 245 : 320) : (compact ? 500 : 620),
                child: sideBySide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: _pulseLivePanel(hr: hr, samples: samples)),
                          const SizedBox(width: 10),
                          Expanded(child: _mapLivePanel(points: gpsPoints)),
                        ],
                      )
                    : Column(
                        children: [
                          Expanded(child: _pulseLivePanel(hr: hr, samples: samples)),
                          const SizedBox(height: 10),
                          Expanded(child: _mapLivePanel(points: gpsPoints)),
                        ],
                      ),
              ),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, bottomConstraints) {
                  final twoColumns = bottomConstraints.maxWidth < 720;
                  const gap = 8.0;
                  final cardWidth = twoColumns
                      ? (bottomConstraints.maxWidth - gap) / 2
                      : (bottomConstraints.maxWidth - gap * 3) / 4;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      SizedBox(
                        width: cardWidth,
                        child: _loadZonesCard(
                          resolvedLoadLow,
                          resolvedLoadModerate,
                          resolvedLoadHigh,
                          resolvedLoadVeryHigh,
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _sprintsCard(
                          sprintCount,
                          sprintDuration,
                          sprintDistance,
                          math.max(speed, maxSpeed),
                          duration,
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _movementCard(
                          'Бег',
                          runPercent,
                          runDistance,
                          runDuration,
                          const Color(0xFF1677D2),
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _movementCard(
                          'Ходьба',
                          walkPercent,
                          walkDistance,
                          walkDuration,
                          const Color(0xFF7B8794),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _archiveStatusChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F7),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: const Color(0xFFE1E5E2)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, size: 11, color: _green),
          SizedBox(width: 4),
          Text('Завершено', style: TextStyle(color: _green, fontWeight: FontWeight.w900, fontSize: 9.5)),
        ],
      ),
    );
  }

  double _percentage(Map<String, dynamic> row, List<String> keys) {
    final value = _num(row, keys);
    if (!value.isFinite || value <= 0) return 0;
    return value.clamp(0, 100).toDouble();
  }


  double _calculateAiLoadIndex({
    required double load,
    required double averageHr,
    required double maxSpeed,
    required int sprintCount,
    required int durationSec,
    required double distanceM,
  }) {
    final safeLoad = load.isFinite ? math.max(0.0, load) : 0.0;
    final safeHr = averageHr.isFinite ? math.max(0.0, averageHr) : 0.0;
    final safeSpeed = maxSpeed.isFinite ? math.max(0.0, maxSpeed) : 0.0;
    final safeDistance = distanceM.isFinite ? math.max(0.0, distanceM) : 0.0;
    final safeSprints = math.max(0, sprintCount);
    final safeDuration = math.max(0, durationSec);
    if (safeLoad <= 0 && safeHr <= 0 && safeSpeed <= 0 && safeDistance <= 0) return 0;
    final durationMinutes = math.max(1.0, safeDuration / 60.0);
    final intensityMPerMin = safeDistance / durationMinutes;
    final loadPart = (safeLoad / 180.0).clamp(0.0, 1.0).toDouble() * 30.0;
    final hrPart = ((safeHr - 70.0) / 110.0).clamp(0.0, 1.0).toDouble() * 25.0;
    final speedPart = (safeSpeed / 30.0).clamp(0.0, 1.0).toDouble() * 15.0;
    final sprintPart = (safeSprints / 12.0).clamp(0.0, 1.0).toDouble() * 15.0;
    final densityPart = (intensityMPerMin / 130.0).clamp(0.0, 1.0).toDouble() * 15.0;
    final result = loadPart + hrPart + speedPart + sprintPart + densityPart;
    return result.isFinite ? result.clamp(0.0, 100.0).toDouble() : 0.0;
  }

  List<double> _deriveIntensityZones(List<_HrPoint> samples) {
    if (samples.isEmpty) return const [0, 0, 0, 0];
    final maxObserved = samples.map((e) => e.bpm).reduce(math.max);
    if (maxObserved <= 0) return const [0, 0, 0, 0];
    final counts = <int>[0, 0, 0, 0];
    for (final point in samples) {
      final ratio = point.bpm / maxObserved;
      if (ratio < .65) {
        counts[0]++;
      } else if (ratio < .78) {
        counts[1]++;
      } else if (ratio < .90) {
        counts[2]++;
      } else {
        counts[3]++;
      }
    }
    final total = math.max(1, counts.fold<int>(0, (a, b) => a + b));
    return counts.map((e) => e * 100.0 / total).toList();
  }

  String _loadLevel(double value) {
    if (value <= 0) return 'Нет данных';
    if (value < 40) return 'Низкая';
    if (value < 100) return 'Умеренная';
    if (value < 160) return 'Высокая';
    return 'Очень высокая';
  }

  Color _loadLevelColor(double value) {
    if (value <= 0) return const Color(0xFF98A2B3);
    if (value < 40) return const Color(0xFF22C55E);
    if (value < 100) return const Color(0xFF84CC16);
    if (value < 160) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  Widget _sessionMetaItem(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: _green),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            color: _muted,
            fontSize: 9.8,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _headerMetaChip(
    IconData icon,
    String text, {
    bool compact = false,
  }) {
    return Container(
      constraints: BoxConstraints(maxWidth: compact ? 210 : 260),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF1FBF5),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 11 : 12, color: _green),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _green,
                fontSize: compact ? 8.8 : 9.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _loadMetricCard({
    required String title,
    required double value,
    required double width,
    required bool compact,
    required String description,
    bool isAi = false,
  }) {
    final level = isAi
        ? (value <= 0 ? 'Нет данных' : value < 35 ? 'Низкий' : value < 65 ? 'Рабочий' : value < 85 ? 'Высокий' : 'Пиковый')
        : _loadLevel(value);
    final accent = isAi
        ? (value <= 0 ? const Color(0xFF98A2B3) : value < 65 ? const Color(0xFF22C55E) : value < 85 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444))
        : _loadLevelColor(value);
    final progress = isAi
        ? (value / 100.0).clamp(0.0, 1.0)
        : (value / 200.0).clamp(0.0, 1.0);
    return InkWell(
      borderRadius: BorderRadius.circular(9),
      onTap: () => showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(description),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Понятно'),
            ),
          ],
        ),
      ),
      child: Container(
        width: width,
        height: compact ? 48 : 54,
        padding: EdgeInsets.symmetric(horizontal: compact ? 7 : 10, vertical: compact ? 6 : 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFBFA),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(isAi ? Icons.psychology_alt_outlined : Icons.monitor_heart_outlined, size: compact ? 14 : 17, color: accent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: _muted, fontSize: compact ? 6.8 : 7.8, fontWeight: FontWeight.w700),
                  ),
                ),
                const Icon(Icons.info_outline_rounded, size: 11, color: Color(0xFF98A2B3)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value > 0 ? (isAi ? '${value.round()} / 100' : '${value.toStringAsFixed(0)} · $level') : '—',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: _text, fontSize: compact ? 9.5 : 11, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                minHeight: 4,
                value: progress.toDouble(),
                backgroundColor: accent.withOpacity(.13),
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topMetricCard(String title, String value, IconData icon, {double? width, bool compact = false}) {
    return Container(
      width: width ?? 138,
      height: compact ? 48 : 54,
      padding: EdgeInsets.symmetric(horizontal: compact ? 7 : 10, vertical: compact ? 6 : 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFA),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: [
          Icon(icon, size: compact ? 14 : 17, color: _green),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _muted, fontSize: compact ? 6.8 : 7.8, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _text, fontSize: compact ? 9.8 : 11.5, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pulseLivePanel({required int hr, required List<_HrPoint> samples}) {
    final sortedSamples = List<_HrPoint>.from(samples)..sort((a, b) => a.sec.compareTo(b.sec));
    final firstSec = sortedSamples.isEmpty ? 0.0 : sortedSamples.first.sec;
    final chartSamples = firstSec > 0
        ? sortedSamples.map((e) => _HrPoint(sec: math.max(0.0, e.sec - firstSec), bpm: e.bpm)).toList()
        : sortedSamples;
    final avg = chartSamples.isEmpty ? 0 : (chartSamples.fold<double>(0, (s, e) => s + e.bpm) / chartSamples.length).round();
    final maxHr = chartSamples.isEmpty ? 0 : chartSamples.map((e) => e.bpm).reduce(math.max).round();
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, headerConstraints) {
              final tiny = headerConstraints.maxWidth < 300;
              return Row(
                children: [
                  Icon(Icons.favorite_rounded, color: _red, size: tiny ? 17 : 20),
                  SizedBox(width: tiny ? 5 : 7),
                  Text('Пульс', style: TextStyle(color: _text, fontWeight: FontWeight.w700, fontSize: tiny ? 11 : 13)),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(hr > 0 ? '$hr уд/мин' : '—', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _red, fontWeight: FontWeight.w700, fontSize: tiny ? 10.5 : 13)),
                  ),
                  if (!tiny) ...[
                    const Spacer(),
                    Text('Средний ${avg > 0 ? avg : '—'}', style: const TextStyle(color: _muted, fontSize: 9, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 10),
                    Text('Макс. ${maxHr > 0 ? maxHr : '—'}', style: const TextStyle(color: _muted, fontSize: 9, fontWeight: FontWeight.w700)),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 5),
          Expanded(child: _HrChart(values: chartSamples, compact: true)),
        ],
      ),
    );
  }

  Widget _mapLivePanel({required List<_GpsPoint> points}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F8F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.map_outlined, color: _green, size: 17),
              SizedBox(width: 6),
              Text('Карта активности', style: TextStyle(color: _text, fontWeight: FontWeight.w700, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(child: _PersonalGpsMap(points: points, showWaitingState: false)),
        ],
      ),
    );
  }

  Widget _loadZonesCard(double low, double moderate, double high, double veryHigh) {
    final sum = low + moderate + high + veryHigh;
    final values = sum > 0 ? [low, moderate, high, veryHigh] : [0.0, 0.0, 0.0, 0.0];
    return InkWell(
      borderRadius: BorderRadius.circular(11),
      onTap: () => showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Зоны интенсивности'),
          content: const Text(
            'Показывают, какую долю тренировки игрок провёл при низкой, умеренной, высокой и очень высокой интенсивности. '
            'При наличии серверных зон используются они; иначе распределение рассчитывается по фактической истории пульса.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Понятно'),
            ),
          ],
        ),
      ),
      child: _bottomInfoCard(
      title: 'Зоны интенсивности',
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: Row(
              children: [
                for (var i = 0; i < 4; i++)
                  Expanded(
                    flex: math.max(1, values[i].round()),
                    child: Container(height: 9, color: <Color>[const Color(0xFF22C55E), const Color(0xFF84CC16), const Color(0xFFFBBF24), const Color(0xFFEF4444)][i]),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _zoneValue(values[0], 'Низкая', const Color(0xFF16A34A)),
              _zoneValue(values[1], 'Умеренная', const Color(0xFF65A30D)),
              _zoneValue(values[2], 'Высокая', const Color(0xFFF59E0B)),
              _zoneValue(values[3], 'Очень высокая', const Color(0xFFDC2626)),
            ],
          ),
        ],
      ),
    ),
    );
  }

  Widget _zoneValue(double value, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value > 0 ? '${value.round()}%' : '—', style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
          const SizedBox(height: 2),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(color: _muted, fontSize: 7.2, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _sprintsCard(
    int count,
    int seconds,
    double distance,
    double maxSpeed,
    int totalDurationSec,
  ) {
    final sprintPercent = totalDurationSec > 0
        ? ((seconds / totalDurationSec) * 100).clamp(0.0, 100.0)
        : 0.0;
    const accent = Color(0xFF7C3AED);
    return _bottomInfoCard(
      title: 'Спринты',
      child: Column(
        children: [
          Row(
            children: [
              Text(
                count > 0 ? '$count' : '0',
                style: const TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w700,
                  fontSize: 19,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                'всего',
                style: TextStyle(
                  color: _muted,
                  fontSize: 7.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              _smallStat(distance > 0 ? _meters(distance) : '—', 'дистанция'),
              const SizedBox(width: 10),
              _smallStat(seconds > 0 ? _duration(seconds) : '—', 'время'),
              const SizedBox(width: 10),
              _smallStat(maxSpeed > 0 ? '${maxSpeed.toStringAsFixed(1)}' : '—', 'км/ч'),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: sprintPercent / 100.0,
              backgroundColor: accent.withOpacity(.14),
              valueColor: const AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _movementCard(String title, double percent, double distance, int seconds, Color accent) {
    return _bottomInfoCard(
      title: title,
      child: Column(
        children: [
          Row(
            children: [
              Text(percent > 0 ? '${percent.round()}%' : '—', style: TextStyle(color: accent, fontWeight: FontWeight.w700, fontSize: 19)),
              const Spacer(),
              _smallStat(distance > 0 ? _meters(distance) : '—', 'дистанция'),
              const SizedBox(width: 10),
              _smallStat(seconds > 0 ? _duration(seconds) : '—', 'время'),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: (percent / 100).clamp(0, 1).toDouble(),
              backgroundColor: accent.withOpacity(.14),
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomInfoCard({required String title, required Widget child}) {
    return Container(
      constraints: const BoxConstraints(minHeight: 92),
      padding: const EdgeInsets.fromLTRB(9, 8, 9, 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9F8),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _text,
              fontSize: 9.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          child,
          const SizedBox(height: 2),
        ],
      ),
    );
  }

  Widget _smallStat(String value, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _text, fontWeight: FontWeight.w900, fontSize: 11)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: _muted, fontSize: 7.5, fontWeight: FontWeight.w600)),
      ],
    );
  }


  Future<Map<String, dynamic>> _loadLatestDetailRow(
    Map<String, dynamic> source,
  ) async {
    final liveId = _int(
      source,
      const ['live_session_id', 'id', 'tracker_live_session_id'],
    );
    if (liveId <= 0) return source;

    try {
      final liveUri = Uri.parse(
        '${widget.apiBaseUrl}/player_get_live_state.php',
      ).replace(queryParameters: {
        'team_id': '${widget.teamId}',
        'live_session_id': '$liveId',
        'active_only': '0',
        'include_finished': '1',
        '_ts': '${DateTime.now().millisecondsSinceEpoch}',
      });
      final response = await http.get(
        liveUri,
        headers: const {'Cache-Control': 'no-cache'},
      ).timeout(const Duration(seconds: 6));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final json = _decode(response.body);
        final rows = json['sessions'] as List? ??
            json['items'] as List? ??
            const <dynamic>[];
        if (rows.isNotEmpty && rows.first is Map) {
          final merged = <String, dynamic>{
            ...source,
            ...Map<String, dynamic>.from(rows.first as Map),
          };
          final enriched = await _enrichLiveRow(merged);
          await _enrichGpsRow(enriched);
          _rememberLiveTelemetry(enriched);
          return enriched;
        }
      }
    } catch (_) {}

    final enriched = await _enrichLiveRow(source);
    await _enrichGpsRow(enriched);
    _rememberLiveTelemetry(enriched);
    final finalSessionId = _int(
      enriched,
      const ['final_session_id', 'session_id', 'tracker_session_id'],
    );
    if (finalSessionId > 0) {
      enriched['status'] = 'finished';
      enriched['is_live'] = false;
    }
    return enriched;
  }

  Future<void> _showPlayerDetails(Map<String, dynamic> row) async {
    final notifier = ValueNotifier<Map<String, dynamic>>(
      await _loadLatestDetailRow(row),
    );
    Timer? detailTimer;

    Future<void> refreshDetail() async {
      final latest = await _loadLatestDetailRow(notifier.value);
      if (notifier.value != latest) notifier.value = latest;
    }

    detailTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => refreshDetail(),
    );

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return ValueListenableBuilder<Map<String, dynamic>>(
            valueListenable: notifier,
            builder: (context, current, _) {
              final name = _playerName(current);
              final avatar = _avatarUrl(current);
              final hr = _int(current, const [
                'last_heart_rate_bpm',
                'heart_rate_bpm',
                'bpm',
                'current_bpm',
              ]);
              final samples = _heartRateSamples(current);
              final gpsPoints = _gpsSamples(current);
              final loadSamples = _loadSamples(current);
              final hasGpsDevice = _sourceLabel(current).toLowerCase().contains('gps') ||
                  _readText(current, const ['gps_device_name', 'tracker_name', 'device_name'], fallback: '').isNotEmpty;
              final running = _isRowRunning(current);

              return Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: EdgeInsets.zero,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(dialogContext).size.width,
                    maxHeight: MediaQuery.of(dialogContext).size.height,
                  ),
                  child: Container(
                    width: MediaQuery.of(dialogContext).size.width,
                    height: MediaQuery.of(dialogContext).size.height,
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.zero,
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x24000000),
                          blurRadius: 16,
                          offset: Offset(0, 12),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(children: [
                          _avatar(avatar, size: 54),
                          const SizedBox(width: 13),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  Flexible(
                                    child: Text(
                                      name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: _text,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: running ? _greenSoft : _soft,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: running
                                            ? const Color(0xFFB8E8CF)
                                            : _line,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: BoxDecoration(
                                            color: running ? _green : _muted,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          running ? 'LIVE' : 'ЗАВЕРШЕНА',
                                          style: TextStyle(
                                            color: running ? _green : _muted,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 9.6,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ]),
                                const SizedBox(height: 3),
                                Text(
                                  '${_activityLabel(current)} · ${_sourceLabel(current)}',
                                  style: const TextStyle(
                                    color: _muted,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: _soft,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(),
                              icon: const Icon(
                                Icons.close_rounded,
                                size: 20,
                                color: _text,
                              ),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 10),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final metricWidth = constraints.maxWidth < 620
                                ? (constraints.maxWidth - 8) / 2
                                : (constraints.maxWidth - 24) / 4;
                            return Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                SizedBox(
                                  width: metricWidth,
                                  child: _detailMetric(
                                    'Вид',
                                    _activityLabel(current),
                                  ),
                                ),
                                SizedBox(
                                  width: metricWidth,
                                  child: _detailMetric(
                                    'Начало',
                                    _startTime(current),
                                  ),
                                ),
                                SizedBox(
                                  width: metricWidth,
                                  child: _detailMetric(
                                    'Окончание',
                                    _isRowRunning(current)
                                        ? _endTime(current)
                                        : (_endTime(current) == 'идёт сейчас'
                                            ? 'завершена'
                                            : _endTime(current)),
                                  ),
                                ),
                                SizedBox(
                                  width: metricWidth,
                                  child: _detailMetric(
                                    'Длительность',
                                    _duration(_sessionDuration(current)),
                                  ),
                                ),
                                SizedBox(
                                  width: metricWidth,
                                  child: _detailMetric(
                                    'Дистанция',
                                    _meters(
                                      _num(current, const [
                                        'total_distance_m',
                                        'distance_m',
                                        'distance',
                                      ]),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: metricWidth,
                                  child: _detailMetric(
                                    'Скорость',
                                    '${_num(current, const ['speed_kmh', 'last_speed_kmh']).toStringAsFixed(1)} км/ч',
                                  ),
                                ),
                                SizedBox(
                                  width: metricWidth,
                                  child: _detailMetric(
                                    running ? 'Текущий пульс' : 'Последний пульс',
                                    hr > 0 ? '$hr уд/мин' : '—',
                                  ),
                                ),
                                SizedBox(
                                  width: metricWidth,
                                  child: _detailMetric(
                                    'Мин./макс. пульс',
                                    _hrExtremesText(samples),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _deviceStatusChip(
                              icon: Icons.favorite_rounded,
                              title: 'Polar',
                              connected: _sourceLabel(current).toLowerCase().contains('polar'),
                              signal: _deviceSignal(current, const ['polar_rssi', 'hr_rssi', 'heart_rate_rssi']),
                              battery: _deviceBattery(current, const ['polar_battery', 'hr_battery', 'heart_rate_battery']),
                            ),
                            _deviceStatusChip(
                              icon: Icons.satellite_alt_rounded,
                              title: 'GPS',
                              connected: hasGpsDevice,
                              signal: _deviceSignal(current, const ['gps_rssi', 'tracker_rssi', 'signal_dbm', 'rssi']),
                              battery: _deviceBattery(current, const ['gps_battery', 'tracker_battery', 'battery_percent', 'battery']),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final showMap = hasGpsDevice || gpsPoints.isNotEmpty;
                            final split = showMap && constraints.maxWidth >= 680;
                            final pulse = Container(
                              height: 240,
                              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFFAFA),
                                border: Border.all(color: const Color(0xFFFFE1E1)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFECEC),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.favorite_rounded, color: _red, size: 16),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Пульс', style: TextStyle(color: _text, fontWeight: FontWeight.w700, fontSize: 12)),
                                          Text(
                                            'Шкала 0–${_durationMinutes(_sessionDuration(current))} мин',
                                            style: const TextStyle(color: _muted, fontWeight: FontWeight.w600, fontSize: 9.6),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Обновить',
                                      onPressed: refreshDetail,
                                      icon: const Icon(Icons.refresh_rounded, color: _red, size: 18),
                                    ),
                                  ]),
                                  const SizedBox(height: 8),
                                  Expanded(child: _HrChart(values: samples, compact: false, loadPoints: loadSamples)),
                                ],
                              ),
                            );
                            final map = Container(
                              height: 240,
                              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF6FBF8),
                                border: Border.all(color: const Color(0xFFD8EEE2)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(children: [
                                    const Icon(Icons.satellite_alt_rounded, color: _green, size: 18),
                                    const SizedBox(width: 7),
                                    const Expanded(child: Text('Трекер онлайн', style: TextStyle(color: _text, fontWeight: FontWeight.w700, fontSize: 12))),
                                  ]),
                                  const SizedBox(height: 8),
                                  Expanded(child: _PersonalGpsMap(points: gpsPoints, showWaitingState: false)),
                                ],
                              ),
                            );
                            if (!showMap) return pulse;
                            if (split) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [Expanded(child: pulse), const SizedBox(width: 10), Expanded(child: map)],
                              );
                            }
                            return Column(children: [pulse, const SizedBox(height: 10), map]);
                          },
                        ),
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(
                            child: SizedBox(
                              height: 44,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _green,
                                  side: const BorderSide(
                                    color: _green,
                                    width: 1.4,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(11),
                                  ),
                                  textStyle: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.of(dialogContext).pop();
                                  widget.onOpenReport?.call(current);
                                },
                                icon: const Icon(
                                  Icons.description_rounded,
                                  size: 18,
                                ),
                                label: const Text('Открыть отчёт'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SizedBox(
                              height: 44,
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: _green,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(11),
                                  ),
                                  textStyle: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.of(dialogContext).pop();
                                  widget.onOpenAnalytics?.call(current);
                                },
                                icon: const Icon(
                                  Icons.analytics_rounded,
                                  size: 18,
                                ),
                                label: const Text('Аналитика игрока'),
                              ),
                            ),
                          ),
                        ]),
                      ],
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
      detailTimer.cancel();
      notifier.dispose();
    }
  }

  Widget _deviceStatusChip({
    required IconData icon,
    required String title,
    required bool connected,
    required String signal,
    required String battery,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: connected ? const Color(0xFFF1FBF5) : const Color(0xFFF7F8F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: connected ? const Color(0xFFCDEEDA) : _line),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: connected ? _green : _muted),
        const SizedBox(width: 7),
        Text('$title ${connected ? 'подключён' : 'не подключён'}', style: TextStyle(color: connected ? _text : _muted, fontWeight: FontWeight.w800, fontSize: 10.5)),
        const SizedBox(width: 10),
        const Icon(Icons.signal_cellular_alt_rounded, size: 14, color: _muted),
        const SizedBox(width: 3),
        Text(signal, style: const TextStyle(color: _muted, fontWeight: FontWeight.w700, fontSize: 9.8)),
        const SizedBox(width: 8),
        const Icon(Icons.battery_5_bar_rounded, size: 14, color: _muted),
        const SizedBox(width: 3),
        Text(battery, style: const TextStyle(color: _muted, fontWeight: FontWeight.w700, fontSize: 9.8)),
      ]),
    );
  }

  Widget _recentEvents(List<Map<String, dynamic>> events) {
    final now = DateTime.now();

    DateTime dayForOffset(int offset) =>
        DateTime(now.year, now.month, now.day).subtract(Duration(days: offset));

    bool sameDate(DateTime? a, DateTime b) =>
        a != null &&
        a.year == b.year &&
        a.month == b.month &&
        a.day == b.day;

    DateTime? eventDate(Map<String, dynamic> event) => _parseDate(
          event['ended_at'] ??
              event['stopped_at'] ??
              event['created_at'] ??
              event['event_at'] ??
              event['started_at'],
        );

    final selectedDay = dayForOffset(_eventDayOffset);
    final filtered = events
        .where((event) => sameDate(eventDate(event), selectedDay))
        .toList()
      ..sort(
        (a, b) => (eventDate(b) ?? DateTime(1970))
            .compareTo(eventDate(a) ?? DateTime(1970)),
      );

    String dayLabel(int offset) {
      if (offset == 0) return 'Сегодня';
      if (offset == 1) return 'Вчера';

      final day = dayForOffset(offset);
      const months = [
        'янв',
        'фев',
        'мар',
        'апр',
        'мая',
        'июн',
        'июл',
        'авг',
        'сен',
        'окт',
        'ноя',
        'дек',
      ];
      return '${day.day} ${months[day.month - 1]}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Последние события',
                style: TextStyle(
                  color: _text,
                  fontWeight: FontWeight.w700,
                  fontSize: 12.4,
                ),
              ),
            ),
            Text(
              '${filtered.length} за день',
              style: const TextStyle(
                color: _muted,
                fontWeight: FontWeight.w500,
                fontSize: 10.4,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 34,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: 7,
            separatorBuilder: (_, __) => const SizedBox(width: 4),
            itemBuilder: (_, offset) {
              final selected = offset == _eventDayOffset;
              final count = events
                  .where(
                    (event) =>
                        sameDate(eventDate(event), dayForOffset(offset)),
                  )
                  .length;

              return InkWell(
                onTap: () => setState(() => _eventDayOffset = offset),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: selected ? _green : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        dayLabel(offset),
                        style: TextStyle(
                          color: selected ? _text : _muted,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 10.4,
                        ),
                      ),
                      if (count > 0) ...[
                        const SizedBox(width: 5),
                        Text(
                          '$count',
                          style: TextStyle(
                            color: selected ? _green : _muted,
                            fontWeight: FontWeight.w700,
                            fontSize: 9.6,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        if (filtered.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'За выбранный день личных тренировок нет.',
              style: TextStyle(
                color: _muted,
                fontWeight: FontWeight.w500,
                fontSize: 11.2,
              ),
            ),
          )
        else
          Column(
            children: [
              for (var index = 0; index < filtered.length; index++) ...[
                _recentEventRow(filtered[index]),
                if (index != filtered.length - 1)
                  const Divider(
                    height: 1,
                    thickness: .7,
                    color: _line,
                  ),
              ],
            ],
          ),
      ],
    );
  }

  Future<void> _showRecentEventDetails(Map<String, dynamic> event) async {
    final row = await _enrichLiveRow(Map<String, dynamic>.from(event));
    await _enrichArchivedAnalytics(row);
    await _enrichGpsRow(row);
    if (!mounted) return;

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Закрыть последнее событие',
      barrierColor: Colors.black.withOpacity(.34),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final screen = MediaQuery.sizeOf(dialogContext);
        final phone = screen.width < 560;
        final horizontalMargin = phone ? 6.0 : 14.0;
        final verticalMargin = phone ? 6.0 : 18.0;
        final dialogWidth = math.min(
          screen.width - horizontalMargin * 2,
          1580.0,
        );
        final dialogHeight = math.min(
          screen.height - verticalMargin * 2,
          phone ? 940.0 : 980.0,
        );

        return SafeArea(
          minimum: EdgeInsets.symmetric(
            horizontal: horizontalMargin,
            vertical: verticalMargin,
          ),
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: dialogWidth,
                height: dialogHeight,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAF9),
                  borderRadius: BorderRadius.circular(phone ? 18 : 24),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 34,
                      spreadRadius: 2,
                      offset: Offset(0, 14),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        phone ? 14 : 20,
                        phone ? 10 : 12,
                        phone ? 8 : 12,
                        8,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 5,
                            height: 22,
                            decoration: BoxDecoration(
                              color: _green,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'Последнее событие игрока',
                            style: TextStyle(
                              color: _text,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () {
                              Navigator.of(dialogContext).pop();
                              widget.onOpenAnalytics?.call(row);
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: _green,
                              padding: EdgeInsets.symmetric(
                                horizontal: phone ? 8 : 12,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            icon: const Icon(Icons.analytics_outlined, size: 17),
                            label: Text(
                              phone ? 'Аналитика' : 'Подробнее в аналитике',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 11.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            tooltip: 'Закрыть',
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            icon: const Icon(Icons.close_rounded, color: _text),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, thickness: .7, color: _line),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          phone ? 6 : 12,
                          8,
                          phone ? 6 : 12,
                          phone ? 6 : 12,
                        ),
                        child: LayoutBuilder(
                          builder: (_, constraints) => Scrollbar(
                            thumbVisibility: phone,
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(
                                parent: AlwaysScrollableScrollPhysics(),
                              ),
                              padding: const EdgeInsets.only(bottom: 20),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minWidth: constraints.maxWidth,
                                ),
                                child: _liveCard(row, archived: true),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: .975, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  Widget _recentEventRow(Map<String, dynamic> event) {
    final finished = '${event['event_type'] ?? event['type'] ?? ''}'
        .toLowerCase()
        .contains('finish');

    final name = _playerName(event);
    final avatar = _avatarUrl(event);
    final duration = _sessionDuration(event);
    final distance = _num(
      event,
      const [
        'total_distance_m',
        'distance_m',
        'distance',
        'session_distance_m',
      ],
    );
    final avgHr = _int(
      event,
      const [
        'avg_heart_rate_bpm',
        'average_heart_rate_bpm',
        'avg_bpm',
        'heart_rate_avg',
      ],
    );
    final maxHr = _int(
      event,
      const [
        'max_heart_rate_bpm',
        'max_bpm',
        'heart_rate_max',
      ],
    );
    final speed = _num(
      event,
      const [
        'avg_speed_kmh',
        'speed_kmh',
        'average_speed_kmh',
      ],
    );

    final metrics = <String>[
      _duration(duration),
      if (distance > 0) _meters(distance),
      if (speed > 0) '${speed.toStringAsFixed(1)} км/ч',
      if (avgHr > 0) 'ср. $avgHr bpm',
      if (maxHr > 0) 'макс. $maxHr bpm',
    ];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showRecentEventDetails(event),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 38,
                decoration: BoxDecoration(
                  color: finished ? _green : _orange,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(width: 8),
              _avatar(avatar, size: 34),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _text,
                        fontWeight: FontWeight.w700,
                        fontSize: 11.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${finished ? 'Завершил' : 'Начал'} · ${_activityLabel(event)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _muted,
                        fontWeight: FontWeight.w500,
                        fontSize: 10.4,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      metrics.join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _muted,
                        fontWeight: FontWeight.w500,
                        fontSize: 9.6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _shortDate(
                      '${event['created_at'] ?? event['event_at'] ?? event['ended_at'] ?? ''}',
                    ),
                    style: const TextStyle(
                      color: _muted,
                      fontWeight: FontWeight.w500,
                      fontSize: 9.6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Открыть',
                    style: const TextStyle(
                      color: _green,
                      fontWeight: FontWeight.w700,
                      fontSize: 10.4,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _eventMetric(IconData icon, String value, {Color accent = _muted}) => Container(
    margin: const EdgeInsets.only(right: 5),
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
    decoration: BoxDecoration(color: _soft, borderRadius: BorderRadius.circular(8), border: Border.all(color: _line)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: accent, size: 12),
      const SizedBox(width: 4),
      Text(value, style: TextStyle(color: accent == _muted ? _text : accent, fontWeight: FontWeight.w900, fontSize: 9.6)),
    ]),
  );

  Widget _compactMetric(String label, String value, {Color valueColor = _text}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: valueColor, fontSize: 11.8, fontWeight: FontWeight.w700)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(color: _muted, fontSize: 9.6, fontWeight: FontWeight.w500)),
    ]),
  );

  Widget _detailMetric(String label, String value) => Container(
    width: 150, padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: _soft, borderRadius: BorderRadius.circular(12), border: Border.all(color: _line)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: _muted, fontSize: 10.4, fontWeight: FontWeight.w800)),
      const SizedBox(height: 3), Text(value, style: const TextStyle(color: _text, fontSize: 12, fontWeight: FontWeight.w900)),
    ]),
  );

  String _lastUpdatedLabel() {
    final now = DateTime.now();
    return 'обновлено ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  Widget _liveStatusText(int count) {
    final active = count > 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: active ? _green : _muted,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          active ? 'LIVE $count' : 'OFFLINE',
          style: TextStyle(
            color: active ? _green : _muted,
            fontSize: 10.4,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _liveIcon(int count) => Container(width: 38, height: 38, decoration: BoxDecoration(color: _greenSoft, borderRadius: BorderRadius.circular(13)), child: Stack(clipBehavior: Clip.none, children: [
    const Center(child: Icon(Icons.notifications_active_rounded, color: _green, size: 20)),
    if (count > 0) Positioned(right: -4, top: -5, child: _smallBadge(count)),
  ]));

  Widget _countPill(int count) { final active = count > 0; return Container(height: 28, padding: const EdgeInsets.symmetric(horizontal: 9), alignment: Alignment.center, decoration: BoxDecoration(color: active ? _green : _soft, borderRadius: BorderRadius.circular(999), border: Border.all(color: active ? _green : _line)), child: Text('$count онлайн', style: TextStyle(color: active ? Colors.white : _muted, fontSize: 11.2, fontWeight: FontWeight.w900))); }
  Widget _smallBadge(int count) => Container(constraints: const BoxConstraints(minWidth: 18, minHeight: 18), padding: const EdgeInsets.symmetric(horizontal: 4), alignment: Alignment.center, decoration: BoxDecoration(color: _green, borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white, width: 2)), child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 9.6, fontWeight: FontWeight.w900)));
  Widget _liveDot() => Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4), decoration: BoxDecoration(color: _greenSoft, borderRadius: BorderRadius.circular(999), border: Border.all(color: _green.withOpacity(.25))), child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.circle, size: 6, color: _green), SizedBox(width: 4), Text('LIVE', style: TextStyle(color: _green, fontSize: 9.6, fontWeight: FontWeight.w900))]));

  Widget _avatar(String url, {double size = 42}) {
    if (url.trim().isNotEmpty) return ClipRRect(borderRadius: BorderRadius.circular(size * .3), child: Image.network(url, width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _avatarFallback(size)));
    return _avatarFallback(size);
  }
  Widget _avatarFallback(double size) => Container(width: size, height: size, decoration: BoxDecoration(color: _greenSoft, borderRadius: BorderRadius.circular(size * .3)), child: Icon(Icons.person_rounded, color: _green, size: size * .52));
  Widget _errorBox(String error) => Text(
    error,
    style: const TextStyle(color: _red, fontWeight: FontWeight.w600, fontSize: 11.2),
  );
  Widget _emptyState() => const Padding(
    padding: EdgeInsets.symmetric(vertical: 12),
    child: Text(
      'Сейчас никто из игроков не ведёт личную тренировку.',
      style: TextStyle(color: _muted, fontWeight: FontWeight.w500, fontSize: 11.2),
    ),
  );

  List<_HrPoint> _heartRateSamples(Map<String, dynamic> row) {
    dynamic raw = row['heart_rate_samples'] ??
        row['hr_samples'] ??
        row['polar_samples'] ??
        row['bpm_history'] ??
        row['heart_rate_history'] ??
        row['points'];

    if (raw is Map) {
      raw = raw['samples'] ?? raw['points'] ?? raw['items'] ?? raw['data'];
    }
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        raw = jsonDecode(raw);
        if (raw is Map) {
          raw = raw['samples'] ?? raw['points'] ?? raw['items'] ?? raw['data'];
        }
      } catch (_) {}
    }

    final out = <_HrPoint>[];
    DateTime? firstMeasured;
    if (raw is List) {
      for (var i = 0; i < raw.length; i++) {
        final item = raw[i];
        final bpmValue = item is Map
            ? (item['bpm'] ?? item['heart_rate_bpm'] ?? item['heart_rate'] ?? item['hr'] ?? item['value'])
            : item;
        final bpm = double.tryParse('$bpmValue');
        if (bpm == null || bpm <= 0 || bpm >= 260) continue;

        double sec = i.toDouble();
        if (item is Map) {
          final value = item['elapsed_sec'] ??
              item['offset_sec'] ??
              item['time_sec'] ??
              item['seconds_from_start'] ??
              item['elapsed_seconds'] ??
              item['relative_sec'];
          final parsed = double.tryParse('$value');
          if (parsed != null) {
            sec = parsed;
          } else {
            final measuredRaw = '${item['measured_at'] ?? item['created_at'] ?? item['timestamp'] ?? ''}'.trim();
            final measured = measuredRaw.isEmpty
                ? null
                : _parseServerDate(measuredRaw);
            if (measured != null) {
              firstMeasured ??= measured;
              sec = measured.difference(firstMeasured!).inMilliseconds / 1000.0;
            }
          }
        }
        out.add(_HrPoint(sec: sec < 0 ? 0 : sec, bpm: bpm));
      }
    }

    // Даже один текущий BPM должен быть виден в Live-карточке.
    if (out.isEmpty) {
      final current = _int(row, const [
        'last_heart_rate_bpm',
        'heart_rate_bpm',
        'bpm',
        'current_bpm',
        'latest_bpm',
        'hr',
      ]);
      if (current > 0) {
        out.add(_HrPoint(sec: 0, bpm: current.toDouble()));
      }
    }
    out.sort((a, b) => a.sec.compareTo(b.sec));
    return out;
  }

  Widget _summaryStrip() {
    final today = DateTime.now();
    bool sameDay(DateTime? d) => d != null && d.year == today.year && d.month == today.month && d.day == today.day;
    final completed = _events.where((e) => '${e['event_type'] ?? e['type'] ?? ''}'.toLowerCase().contains('finish')).toList();
    final todayCount = completed.where((e) => sameDay(_parseDate(e['ended_at'] ?? e['created_at'] ?? e['event_at']))).length;
    final weekCount = completed.where((e) { final d = _parseDate(e['ended_at'] ?? e['created_at'] ?? e['event_at']); return d != null && today.difference(d).inDays < 7; }).length;
    return Wrap(spacing: 8, runSpacing: 8, children: [
      _summaryMetric('Всего', '${completed.length}', Icons.fitness_center_rounded),
      _summaryMetric('Сегодня', '$todayCount', Icons.today_rounded),
      _summaryMetric('7 дней', '$weekCount', Icons.date_range_rounded),
      _summaryMetric('Онлайн', '${_live.length}', Icons.notifications_active_rounded),
    ]);
  }

  Widget _summaryMetric(String label, String value, IconData icon) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, style: const TextStyle(color: _text, fontWeight: FontWeight.w700, fontSize: 15.2)),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(color: _muted, fontWeight: FontWeight.w500, fontSize: 9.6)),
    ]),
  );

  String _activityLabel(Map<String, dynamic> row) {
    final raw = _readText(row, const ['activity_type', 'training_type', 'workout_type', 'mode'], fallback: '').toLowerCase();
    if (raw.contains('run') || raw.contains('бег')) return 'Бег';
    if (raw.contains('gym') || raw.contains('зал')) return 'Зал';
    if (raw.contains('strength') || raw.contains('сил')) return 'Силовая';
    if (raw.contains('field') || raw.contains('football') || raw.contains('поле')) return 'Поле';
    return 'Личная';
  }

  int _sessionDuration(Map<String, dynamic> row) {
    final direct = _int(row, const ['duration_sec', 'duration_seconds', 'elapsed_sec', 'live_duration_sec']);
    if (direct > 0) return direct;
    final a = _parseDate(row['started_at'] ?? row['start_time'] ?? row['created_at']);
    final b = _parseDate(row['ended_at'] ?? row['end_time'] ?? row['finished_at']) ?? DateTime.now();
    return a == null ? 0 : b.difference(a).inSeconds.clamp(0, 86400).toInt();
  }

  String _startTime(Map<String, dynamic> row) =>
      _formatTime(_parseServerDate(row['started_at'] ?? row['start_time'] ?? row['created_at']));

  String _endTime(Map<String, dynamic> row) {
    final d = _parseServerDate(
      row['stopped_at'] ??
          row['ended_at'] ??
          row['end_time'] ??
          row['finished_at'],
    );
    return d == null ? 'идёт сейчас' : _formatTime(d);
  }

  bool _isRowRunning(Map<String, dynamic> row) {
    // Наличие итоговой сессии однозначно означает, что Live уже завершён,
    // даже если старый API продолжает возвращать status=active.
    final finalSessionId = _int(
      row,
      const ['final_session_id', 'session_id', 'tracker_session_id'],
    );
    if (finalSessionId > 0) return false;

    final status = '${row['status'] ?? row['state'] ?? row['live_status'] ?? ''}'
        .trim()
        .toLowerCase();
    final explicitlyFinished = status.contains('finish') ||
        status.contains('stop') ||
        status.contains('closed') ||
        status.contains('cancel') ||
        status.contains('autosaved') ||
        status.contains('completed');
    if (explicitlyFinished) return false;

    final ended = row['stopped_at'] ??
        row['ended_at'] ??
        row['end_time'] ??
        row['finished_at'];
    if (_parseServerDate(ended) != null) return false;

    // Если heartbeat давно не обновлялся, такую строку нельзя показывать LIVE.
    final lastSeenInstant = _trackerParseServerInstant(
      row['last_seen_at'] ?? row['updated_at'] ?? row['heartbeat_at'],
    );
    if (lastSeenInstant != null &&
        DateTime.now().toUtc().difference(lastSeenInstant).abs() >
            const Duration(minutes: 2)) {
      return false;
    }

    return status.isEmpty ||
        status == 'active' ||
        status == 'online' ||
        status == 'live' ||
        status.contains('active');
  }

  String _formatTime(DateTime? d) => d == null
      ? '—'
      : '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  /// Серверные строки без timezone считаются UTC и отображаются
  /// строго по московскому времени (UTC+3), независимо от timezone устройства.
  DateTime? _parseServerDate(dynamic value) => _trackerMoscowDateTime(value);

  DateTime? _parseDate(dynamic value) => _parseServerDate(value);
  int _durationMinutes(int sec) => sec <= 0 ? 0 : (sec / 60).ceil();
  String _hrExtremesText(List<_HrPoint> values) {
    if (values.isEmpty) return 'Нет данных';
    final minP = values.reduce((a,b) => a.bpm <= b.bpm ? a : b);
    final maxP = values.reduce((a,b) => a.bpm >= b.bpm ? a : b);
    return '${minP.bpm.round()} (${(minP.sec/60).floor()} мин) / ${maxP.bpm.round()} (${(maxP.sec/60).floor()} мин)';
  }

  int? _parsePositiveInt(dynamic value) {
    final parsed = value is num ? value.toInt() : int.tryParse('${value ?? ''}');
    return parsed != null && parsed > 0 ? parsed : null;
  }

  int? _rowPlayerId(Map<String, dynamic> row) {
    for (final key in const ['player_id', 'playerId', 'resolved_player_id', 'owner_user_id', 'user_id', 'userId', 'resolved_user_id', 'athlete_id']) {
      final value = row[key];
      final parsed = value is num ? value.toInt() : int.tryParse('${value ?? ''}');
      if (parsed != null && parsed > 0 && _resolvedDirectory.containsKey(parsed)) return parsed;
    }
    final direct = _readText(row, const ['player_name', 'full_name', 'name', 'athlete_name'], fallback: '');
    final technical = RegExp(r'^(?:Игрок|Player)\s*#?\s*(\d+)$', caseSensitive: false).firstMatch(direct);
    final parsed = technical == null ? null : int.tryParse(technical.group(1) ?? '');
    return parsed != null && _resolvedDirectory.containsKey(parsed) ? parsed : null;
  }

  String _playerName(Map<String, dynamic> row) {
    // Сначала используем раздельные поля — это единственный надёжный способ
    // гарантировать формат «Фамилия И.» независимо от порядка full_name.
    final first = _readText(
      row,
      const ['first_name', 'player_first_name', 'user_first_name'],
      fallback: '',
    );
    final last = _readText(
      row,
      const ['last_name', 'surname', 'player_last_name', 'user_last_name'],
      fallback: '',
    );
    if (last.isNotEmpty || first.isNotEmpty) {
      return _surnameWithInitial(last: last, first: first);
    }

    final directoryId = _rowPlayerId(row);
    final directoryName = directoryId == null
        ? ''
        : (_resolvedDirectory[directoryId]?['name'] ?? '').trim();
    if (directoryName.isNotEmpty) return _shortSurnameFirst(directoryName);

    final direct = _readText(
      row,
      const ['player_short_name', 'short_name', 'player_name', 'full_name', 'name', 'athlete_name'],
      fallback: '',
    );
    final technical = RegExp(
      r'^(?:Игрок|Player)\s*#?\s*\d+$',
      caseSensitive: false,
    ).hasMatch(direct);
    if (direct.isNotEmpty && !technical) {
      return _shortSurnameFirst(direct, assumeFirstNameFirst: true);
    }
    return directoryId == null ? 'Игрок' : 'Игрок #$directoryId';
  }

  String _surnameWithInitial({required String last, required String first}) {
    final surname = last.trim();
    final given = first.trim();
    if (surname.isEmpty) return given;
    if (given.isEmpty) return surname;
    return '$surname ${given.substring(0, 1).toUpperCase()}.';
  }

  String _shortSurnameFirst(
    String value, {
    bool assumeFirstNameFirst = false,
  }) {
    final cleaned = value.trim();
    final parts = cleaned
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.length < 2) return cleaned;

    // Если строка уже сокращена («Красновский С.»), оставляем как есть.
    if (parts[1].endsWith('.') && parts[1].length <= 3) {
      return '${parts.first} ${parts[1].substring(0, 1).toUpperCase()}.';
    }

    final surname = assumeFirstNameFirst ? parts.last : parts.first;
    final firstName = assumeFirstNameFirst ? parts.first : parts[1];
    return '$surname ${firstName.substring(0, 1).toUpperCase()}.';
  }
  String _avatarUrl(Map<String, dynamic> row) {
    final direct = _readText(row, const ['avatar_url', 'avatar', 'photo_url', 'photo', 'player_avatar'], fallback: '');
    if (direct.isNotEmpty) return direct;
    final id = _rowPlayerId(row);
    return id == null ? '' : (_resolvedDirectory[id]?['avatar'] ?? '').trim();
  }
  String _shortDate(String value) {
    final parsed = _parseServerDate(value);
    if (parsed == null) return value;
    return _formatTime(parsed);
  }
  IconData _iconFor(String type) => type.toLowerCase().contains('finish') ? Icons.check_circle_rounded : type.toLowerCase().contains('start') ? Icons.play_circle_fill_rounded : Icons.info_rounded;
  String _plural(int count) { final n10 = count % 10, n100 = count % 100; if (n10 == 1 && n100 != 11) return ''; if (n10 >= 2 && n10 <= 4 && (n100 < 12 || n100 > 14)) return 'а'; return 'ов'; }

  bool _isActivePersonalLive(Map<String, dynamic> s) {
    final status = '${s['status'] ?? s['state'] ?? s['live_status'] ?? 'active'}'.toLowerCase();
    if (status.contains('finish') || status.contains('stop') || status.contains('closed') || status.contains('cancel')) return false;
    final personalRaw = '${s['personal_session'] ?? s['is_personal'] ?? s['personal'] ?? ''}'.toLowerCase().trim();
    final kind = '${s['session_kind'] ?? s['source'] ?? s['started_by_role'] ?? ''}'.toLowerCase();
    return personalRaw == '1' || personalRaw == 'true' || kind.contains('personal') || kind.contains('player') || kind.contains('polar') || !s.containsKey('personal_session');
  }

  Map<String, dynamic> _decode(String body) { final text = body.trim(); final start = text.indexOf('{'); final decoded = jsonDecode(start >= 0 ? text.substring(start) : text); return decoded is Map ? Map<String, dynamic>.from(decoded) : {'success': false, 'message': 'Некорректный ответ API'}; }
  String _sourceLabel(Map<String, dynamic> row) { final source = _readText(row, const ['source', 'device_source', 'activity_source'], fallback: '').toLowerCase(); final device = _readText(row, const ['device_name', 'tracker_name'], fallback: '').toLowerCase(); final hasHr = _int(row, const ['last_heart_rate_bpm', 'heart_rate_bpm', 'bpm', 'avg_heart_rate_bpm']) > 0 || source.contains('polar') || device.contains('polar'); final hasGps = _num(row, const ['total_distance_m', 'distance_m', 'last_field_x_m', 'field_x_m', 'latitude', 'lat']) > 0 || source.contains('gps') || source.contains('tracker'); if (hasHr && hasGps) return 'Polar + GPS'; if (hasHr) return 'Polar'; if (hasGps) return 'GPS-трекер'; return 'личная сессия'; }
  String _readText(Map<String, dynamic> row, List<String> keys, {required String fallback}) { for (final key in keys) { final value = row[key]; if (value == null) continue; final text = '$value'.trim(); if (text.isNotEmpty && text != 'null') return text; } return fallback; }
  int _int(Map<String, dynamic> row, List<String> keys) { for (final key in keys) { final value = row[key]; if (value == null) continue; final parsed = int.tryParse('$value') ?? (value is num ? value.toInt() : null); if (parsed != null) return parsed; } return 0; }
  double _num(Map<String, dynamic> row, List<String> keys) { for (final key in keys) { final value = row[key]; if (value == null) continue; final parsed = double.tryParse('$value') ?? (value is num ? value.toDouble() : null); if (parsed != null && parsed.isFinite) return parsed; } return 0; }
  int _displayDurationSeconds(
    Map<String, dynamic> row, {
    required int serverDuration,
    required bool archived,
  }) {
    final safeServerDuration = math.max(0, serverDuration);
    if (archived) return safeServerDuration;

    final raw = _readText(
      row,
      const ['started_at', 'start_at', 'start_time_iso', 'live_started_at'],
      fallback: '',
    ).trim();
    if (raw.isEmpty) return safeServerDuration;

    final normalized = raw.contains('T') ? raw : raw.replaceFirst(' ', 'T');
    DateTime? started = DateTime.tryParse(normalized);
    if (started == null) return safeServerDuration;

    final hasExplicitTimezone =
        normalized.endsWith('Z') ||
        RegExp(r'[+-]\\d{2}:?\\d{2}$').hasMatch(normalized);

    if (hasExplicitTimezone) {
      started = started.toLocal();
    } else {
      // PHP/MySQL usually returns DATETIME without timezone.
      // Treat it as local wall-clock time instead of UTC.
      started = DateTime(
        started.year,
        started.month,
        started.day,
        started.hour,
        started.minute,
        started.second,
        started.millisecond,
        started.microsecond,
      );
    }

    final localElapsed = DateTime.now().difference(started).inSeconds;
    if (localElapsed < 0) return safeServerDuration;

    // A newly started session must never jump several hours because of
    // a timezone mismatch or a stale started_at value.
    if (safeServerDuration <= 5 * 60 && localElapsed > 30 * 60) {
      return safeServerDuration;
    }

    // Prefer the server duration whenever the two clocks differ materially.
    // The local calculation is used only to make the counter tick smoothly
    // between successful Live API refreshes.
    if ((localElapsed - safeServerDuration).abs() > 5 * 60) {
      return safeServerDuration;
    }

    return math.max(safeServerDuration, localElapsed);
  }

  String _duration(int sec) { if (sec <= 0) return '0:00'; final h = sec ~/ 3600, m = (sec % 3600) ~/ 60, s = sec % 60; return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}' : '$m:${s.toString().padLeft(2, '0')}'; }
  String _meters(double value) => value >= 1000 ? '${(value / 1000).toStringAsFixed(2)} км' : '${value.toStringAsFixed(0)} м';
}


class _GpsPoint {
  const _GpsPoint({required this.lat, required this.lon, this.speedKmh = 0, this.elapsedSec = 0});
  final double lat;
  final double lon;
  final double speedKmh;
  final double elapsedSec;
}

class _PersonalGpsMap extends StatelessWidget {
  const _PersonalGpsMap({
    required this.points,
    this.showWaitingState = false,
  });

  final List<_GpsPoint> points;
  final bool showWaitingState;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _PersonalGpsMapPainter(points),
            size: Size.infinite,
          ),
          if (false && showWaitingState && points.isEmpty)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.94),
                    borderRadius: BorderRadius.circular(99),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(.10),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.8,
                          color: Color(0xFF00A750),
                        ),
                      ),
                      SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Color(0xFF101828),
                            fontWeight: FontWeight.w700,
                            fontSize: 9.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PersonalGpsMapPainter extends CustomPainter {
  const _PersonalGpsMapPainter(this.points);

  final List<_GpsPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    final area = (Offset.zero & size).deflate(8);
    final pitch = _fitPitch(area);
    _drawAnalyticsPitch(canvas, pitch);

    if (points.isEmpty) return;

    var minLat = points.first.lat;
    var maxLat = points.first.lat;
    var minLon = points.first.lon;
    var maxLon = points.first.lon;
    for (final p in points) {
      minLat = math.min(minLat, p.lat);
      maxLat = math.max(maxLat, p.lat);
      minLon = math.min(minLon, p.lon);
      maxLon = math.max(maxLon, p.lon);
    }

    final latSpan = math.max(0.000001, maxLat - minLat);
    final lonSpan = math.max(0.000001, maxLon - minLon);
    final routeArea = pitch.deflate(14);

    Offset position(_GpsPoint p) => Offset(
          routeArea.left + ((p.lon - minLon) / lonSpan) * routeArea.width,
          routeArea.bottom - ((p.lat - minLat) / latSpan) * routeArea.height,
        );

    final route = Path();
    for (var i = 0; i < points.length; i++) {
      final point = position(points[i]);
      if (i == 0) {
        route.moveTo(point.dx, point.dy);
      } else {
        route.lineTo(point.dx, point.dy);
      }
    }

    canvas.drawPath(
      route,
      Paint()
        ..color = Colors.white.withOpacity(.95)
        ..strokeWidth = 2.4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final pointPaint = Paint()..color = const Color(0xFFBFF5CE);
    for (final p in points) {
      canvas.drawCircle(position(p), 2.1, pointPaint);
    }

    canvas.drawCircle(
      position(points.last),
      5.4,
      Paint()..color = const Color(0xFFFFD84D),
    );
    canvas.drawCircle(
      position(points.last),
      7.5,
      Paint()
        ..color = Colors.white.withOpacity(.90)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  Rect _fitPitch(Rect area) {
    const aspectRatio = 105 / 68;
    var width = area.width;
    var height = width / aspectRatio;
    if (height > area.height) {
      height = area.height;
      width = height * aspectRatio;
    }
    return Rect.fromCenter(
      center: area.center,
      width: width,
      height: height,
    );
  }

  void _drawAnalyticsPitch(Canvas canvas, Rect pitch) {
    final roundedPitch = RRect.fromRectAndRadius(
      pitch,
      const Radius.circular(12),
    );
    canvas.drawRRect(
      roundedPitch,
      Paint()..color = const Color(0xFF78977F),
    );

    canvas.save();
    canvas.clipRRect(roundedPitch);
    const stripeCount = 12;
    for (var i = 0; i < stripeCount; i++) {
      canvas.drawRect(
        Rect.fromLTWH(
          pitch.left + pitch.width * i / stripeCount,
          pitch.top,
          pitch.width / stripeCount,
          pitch.height,
        ),
        Paint()
          ..color = i.isEven
              ? Colors.white.withOpacity(.055)
              : Colors.black.withOpacity(.045),
      );
    }
    canvas.restore();

    final inner = pitch.deflate(math.max(8.0, pitch.width * .016));
    final line = Paint()
      ..color = Colors.white.withOpacity(.82)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.15, pitch.width * .0024);

    canvas.drawRRect(
      RRect.fromRectAndRadius(inner, const Radius.circular(8)),
      line,
    );
    canvas.drawLine(
      Offset(inner.center.dx, inner.top),
      Offset(inner.center.dx, inner.bottom),
      line,
    );
    canvas.drawCircle(
      inner.center,
      inner.height * .125,
      line,
    );

    final penaltyWidth = inner.width * .175;
    final penaltyHeight = inner.height * .46;
    final goalWidth = inner.width * .078;
    final goalHeight = inner.height * .23;

    canvas.drawRect(
      Rect.fromLTWH(
        inner.left,
        inner.center.dy - penaltyHeight / 2,
        penaltyWidth,
        penaltyHeight,
      ),
      line,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        inner.right - penaltyWidth,
        inner.center.dy - penaltyHeight / 2,
        penaltyWidth,
        penaltyHeight,
      ),
      line,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        inner.left,
        inner.center.dy - goalHeight / 2,
        goalWidth,
        goalHeight,
      ),
      line,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        inner.right - goalWidth,
        inner.center.dy - goalHeight / 2,
        goalWidth,
        goalHeight,
      ),
      line,
    );

    final spotPaint = Paint()..color = Colors.white.withOpacity(.82);
    canvas.drawCircle(
      Offset(inner.left + inner.width * .115, inner.center.dy),
      math.max(1.8, inner.width * .0045),
      spotPaint,
    );
    canvas.drawCircle(
      Offset(inner.right - inner.width * .115, inner.center.dy),
      math.max(1.8, inner.width * .0045),
      spotPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _PersonalGpsMapPainter oldDelegate) =>
      oldDelegate.points != points;
}

class _LoadPoint {
  const _LoadPoint({required this.sec, required this.value});
  final double sec;
  final double value;
}

class _HrPoint {
  const _HrPoint({required this.sec, required this.bpm});
  final double sec;
  final double bpm;
}

class _HrChart extends StatefulWidget {
  const _HrChart({required this.values, required this.compact, this.loadPoints = const <_LoadPoint>[]});
  final List<_HrPoint> values;
  final bool compact;
  final List<_LoadPoint> loadPoints;
  @override
  State<_HrChart> createState() => _HrChartState();
}

class _HrChartState extends State<_HrChart> {
  int? selected;
  bool followLive = true;
  double windowSec = 180;
  double? viewEndSec;

  double get _maxSec => widget.values.isEmpty ? 1 : math.max(1.0, widget.values.last.sec);
  double get _endSec => followLive ? _maxSec : (viewEndSec ?? _maxSec).clamp(windowSec, _maxSec).toDouble();
  double get _startSec => math.max(0, _endSec - windowSec);

  void _shift(double seconds) {
    setState(() {
      followLive = false;
      viewEndSec = (_endSec + seconds).clamp(windowSec, _maxSec).toDouble();
    });
  }

  void _select(Offset p, Size size) {
    if (widget.values.isEmpty || size.width <= 0) return;
    final target = _startSec + (p.dx.clamp(0.0, size.width) / size.width) * math.max(1.0, _endSec - _startSec);
    var best = 0;
    var delta = double.infinity;
    for (var i=0;i<widget.values.length;i++) { final d=(widget.values[i].sec-target).abs(); if(d<delta){delta=d;best=i;} }
    setState(() => selected = best);
  }

  @override
  Widget build(BuildContext context) {
    final chart = LayoutBuilder(builder: (_, c) {
      final size = Size(c.maxWidth, c.maxHeight);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) => _select(d.localPosition, size),
        onPanStart: (_) {
          if (widget.values.length > 1) {
            setState(() => followLive = false);
          }
        },
        onPanUpdate: (d) {
          if (d.delta.dx.abs() > 0.2) {
            _shift(-d.delta.dx / math.max(1.0, size.width) * windowSec);
          } else {
            _select(d.localPosition, size);
          }
        },
        child: CustomPaint(
          painter: _HrChartPainter(widget.values, detailed: !widget.compact, selected: selected, minSec: widget.compact ? 0 : _startSec, maxSec: widget.compact ? _maxSec : _endSec, loadPoints: widget.loadPoints),
          size: Size.infinite,
        ),
      );
    });
    if (widget.compact) {
      final historyAvailable = _maxSec > windowSec + 5;
      final progress = !historyAvailable
          ? 1.0
          : ((_endSec - windowSec) / math.max(1.0, _maxSec - windowSec))
              .clamp(0.0, 1.0)
              .toDouble();
      return Column(
        children: [
          Expanded(child: chart),
          const SizedBox(height: 4),
          LayoutBuilder(
            builder: (_, c) {
              final thumbWidth = historyAvailable
                  ? math.max(34.0, c.maxWidth * .24)
                  : c.maxWidth;
              final left = (c.maxWidth - thumbWidth) * progress;
              return SizedBox(
                height: 7,
                child: Stack(
                  children: [
                    Positioned.fill(
                      top: 2.5,
                      bottom: 2.5,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE1E1),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    Positioned(
                      left: left,
                      top: 0,
                      width: thumbWidth,
                      height: 7,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: historyAvailable
                              ? const Color(0xFFEF4444)
                              : const Color(0xFFFCA5A5),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              const Icon(
                Icons.swipe_rounded,
                size: 13,
                color: Color(0xFF98A2B3),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  historyAvailable
                      ? 'Листайте график влево и вправо'
                      : 'История пульса накапливается',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF98A2B3),
                    fontSize: 8.8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  minimumSize: const Size(0, 26),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: followLive
                    ? null
                    : () => setState(() {
                          followLive = true;
                          viewEndSec = null;
                        }),
                icon: Icon(
                  Icons.radio_button_checked_rounded,
                  size: 13,
                  color: followLive
                      ? const Color(0xFF00A750)
                      : const Color(0xFFDC2626),
                ),
                label: Text(
                  followLive ? 'Прямой эфир' : 'Продолжить эфир',
                  style: TextStyle(
                    color: followLive
                        ? const Color(0xFF00A750)
                        : const Color(0xFFDC2626),
                    fontWeight: FontWeight.w900,
                    fontSize: 9,
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }
    return Column(children: [
      Expanded(child: chart),
      const SizedBox(height: 4),
      Row(children: [
        IconButton(onPressed: () => _shift(-windowSec * .65), icon: const Icon(Icons.chevron_left_rounded, size: 19), tooltip: 'Раньше'),
        Expanded(child: Text('Интервал ${(_startSec/60).floor()}–${(_endSec/60).ceil()} мин', textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF98A2B3), fontSize: 9.6, fontWeight: FontWeight.w700))),
        IconButton(onPressed: () => _shift(windowSec * .65), icon: const Icon(Icons.chevron_right_rounded, size: 19), tooltip: 'Позже'),
        TextButton.icon(
          onPressed: () => setState(() { followLive = true; viewEndSec = null; }),
          icon: Icon(Icons.radio_button_checked_rounded, size: 15, color: followLive ? const Color(0xFF00A750) : const Color(0xFF98A2B3)),
          label: Text(followLive ? 'В прямом эфире' : 'Продолжить прямой эфир'),
        ),
      ]),
    ]);
  }
}

class _HrChartPainter extends CustomPainter {
  const _HrChartPainter(this.values, {this.detailed = false, this.selected, this.minSec = 0, this.maxSec, this.loadPoints = const <_LoadPoint>[]});
  final List<_HrPoint> values;
  final bool detailed;
  final int? selected;
  final double minSec;
  final double? maxSec;
  final List<_LoadPoint> loadPoints;
  @override
  void paint(Canvas canvas, Size size) {
    final labelHeight = 15.0;
    final chartHeight = math.max(24.0, size.height - labelHeight);
    final grid = Paint()
      ..color = const Color(0xFFFFE4E4)
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      final y = chartHeight * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    if (values.isEmpty) {
      final tp = TextPainter(
        text: const TextSpan(
          text: 'Нет данных Polar',
          style: TextStyle(
            color: Color(0xFF98A2B3),
            fontSize: 11.2,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset((size.width - tp.width) / 2, (chartHeight - tp.height) / 2),
      );
      return;
    }

    final endSec = maxSec ?? values.last.sec;
    final visible =
        values.where((p) => p.sec >= minSec && p.sec <= endSec).toList();
    final plotValues = visible.isEmpty ? values : visible;
    final rangeSec = math.max(1.0, endSec - minSec);

    void drawTimeLabels() {
      for (var i = 0; i <= 4; i++) {
        final sec = minSec + rangeSec * i / 4;
        final totalSeconds = sec.round();
        final minutes = totalSeconds ~/ 60;
        final seconds = totalSeconds % 60;
        final label = seconds == 0
            ? '$minutes мин'
            : '$minutes:${seconds.toString().padLeft(2, '0')}';
        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: const TextStyle(
              color: Color(0xFF98A2B3),
              fontSize: 8.6,
              fontWeight: FontWeight.w600,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(
          canvas,
          Offset(
            (size.width * i / 4 - tp.width / 2)
                .clamp(0.0, size.width - tp.width),
            chartHeight + 2,
          ),
        );
      }
    }

    if (plotValues.length == 1) {
      final p = plotValues.first;
      final y = chartHeight * .5;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()
          ..color = const Color(0xFFDC2626).withOpacity(.35)
          ..strokeWidth = 1.5,
      );
      canvas.drawCircle(
        Offset(size.width * .5, y),
        5,
        Paint()..color = const Color(0xFFDC2626),
      );
      final tp = TextPainter(
        text: TextSpan(
          text: '${p.bpm.round()} bpm',
          style: const TextStyle(
            color: Color(0xFFDC2626),
            fontSize: 11.2,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset((size.width - tp.width) / 2, math.max(0, y - 22)),
      );
      drawTimeLabels();
      return;
    }

    final minPoint =
        plotValues.reduce((a, b) => a.bpm <= b.bpm ? a : b);
    final maxPoint =
        plotValues.reduce((a, b) => a.bpm >= b.bpm ? a : b);
    final minV = math.max(40.0, minPoint.bpm - 10);
    final maxV = math.min(220.0, maxPoint.bpm + 10);
    final span = math.max(1.0, maxV - minV);

    Offset pos(_HrPoint p) => Offset(
          size.width *
              ((p.sec - minSec) / rangeSec).clamp(0.0, 1.0),
          chartHeight -
              ((p.bpm - minV) / span).clamp(0.0, 1.0) * chartHeight,
        );

    final path = Path();
    final first = pos(plotValues.first);
    path.moveTo(first.dx, first.dy);
    for (var i = 1; i < plotValues.length; i++) {
      final previous = pos(plotValues[i - 1]);
      final current = pos(plotValues[i]);
      final mid = Offset(
        (previous.dx + current.dx) / 2,
        (previous.dy + current.dy) / 2,
      );
      path.quadraticBezierTo(previous.dx, previous.dy, mid.dx, mid.dy);
      if (i == plotValues.length - 1) {
        path.quadraticBezierTo(
          current.dx,
          current.dy,
          current.dx,
          current.dy,
        );
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFDC2626)
        ..strokeWidth = detailed ? 2.4 : 1.8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    void marker(_HrPoint p, Color color, String text) {
      final o = pos(p);
      canvas.drawCircle(o, detailed ? 4 : 3, Paint()..color = color);
      if (detailed) {
        final tp = TextPainter(
          text: TextSpan(
            text: text,
            style: TextStyle(
              color: color,
              fontSize: 10.4,
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(
          canvas,
          Offset(
            (o.dx - tp.width / 2).clamp(0.0, size.width - tp.width),
            (o.dy - 18).clamp(0.0, chartHeight - tp.height),
          ),
        );
      }
    }

    marker(
      minPoint,
      const Color(0xFF2563EB),
      'мин ${minPoint.bpm.round()} · ${(minPoint.sec / 60).floor()} мин',
    );
    marker(
      maxPoint,
      const Color(0xFFDC2626),
      'макс ${maxPoint.bpm.round()} · ${(maxPoint.sec / 60).floor()} мин',
    );

    if (detailed && loadPoints.isNotEmpty) {
      final loadPaint = Paint()..color = const Color(0xFF00A750);
      for (final lp
          in loadPoints.where((p) => p.sec >= minSec && p.sec <= endSec)) {
        final x = size.width *
            ((lp.sec - minSec) / rangeSec).clamp(0.0, 1.0);
        canvas.drawCircle(Offset(x, chartHeight - 8), 3.2, loadPaint);
      }
    }

    if (selected != null &&
        selected! >= 0 &&
        selected! < values.length) {
      final point = values[selected!];
      final o = pos(point);
      canvas.drawLine(
        Offset(o.dx, 0),
        Offset(o.dx, chartHeight),
        Paint()
          ..color = const Color(0xFF6B746E)
          ..strokeWidth = 1,
      );
      marker(
        point,
        const Color(0xFF101828),
        '${point.bpm.round()} · ${(point.sec / 60).floor()}:${((point.sec % 60).round()).toString().padLeft(2, '0')}',
      );
    }
    drawTimeLabels();
  }
  @override
  bool shouldRepaint(covariant _HrChartPainter oldDelegate)=>oldDelegate.values!=values||oldDelegate.detailed!=detailed||oldDelegate.selected!=selected||oldDelegate.minSec!=minSec||oldDelegate.maxSec!=maxSec||oldDelegate.loadPoints!=loadPoints;
}

class PlayerTrainingOnlineBadge extends StatefulWidget {
  const PlayerTrainingOnlineBadge({
    super.key,
    required this.teamId,
    this.compact = true,
    this.apiBaseUrl = 'https://sportotekaapp.ru/api/tracker',
  });

  final int teamId;
  final bool compact;
  final String apiBaseUrl;

  @override
  State<PlayerTrainingOnlineBadge> createState() => _PlayerTrainingOnlineBadgeState();
}

class _PlayerTrainingOnlineBadgeState extends State<PlayerTrainingOnlineBadge> {
  Timer? _timer;
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _load());
  }

  @override
  void didUpdateWidget(covariant PlayerTrainingOnlineBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.teamId != widget.teamId || oldWidget.apiBaseUrl != widget.apiBaseUrl) {
      _load();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (widget.teamId <= 0) return;
    try {
      final uri = Uri.parse('${widget.apiBaseUrl}/player_get_live_state.php').replace(
        queryParameters: <String, String>{
          'team_id': '${widget.teamId}',
          'personal_session': '1',
          'active_only': '1',
          'limit': '50',
        },
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      final text = response.body.trim();
      final start = text.indexOf('{');
      final decoded = jsonDecode(start >= 0 ? text.substring(start) : text);
      if (decoded is! Map) return;
      final data = Map<String, dynamic>.from(decoded);
      final raw = data['sessions'] as List? ?? data['items'] as List? ?? const [];
      final count = raw.whereType<Map>().where((item) {
        final row = Map<String, dynamic>.from(item);
        final status = '${row['status'] ?? row['state'] ?? row['live_status'] ?? 'active'}'.toLowerCase();
        return !status.contains('finish') &&
            !status.contains('stop') &&
            !status.contains('closed') &&
            !status.contains('cancel');
      }).length;
      if (mounted && count != _count) setState(() => _count = count);
    } catch (_) {
      // Бейдж не должен ломать навигацию при временной ошибке сети.
    }
  }


  @override
  Widget build(BuildContext context) {
    final active = _count > 0;
    final size = widget.compact ? 20.0 : 24.0;
    return Container(
      constraints: BoxConstraints(minWidth: size, minHeight: size),
      padding: EdgeInsets.symmetric(horizontal: widget.compact ? 5 : 7, vertical: 2),
      decoration: BoxDecoration(
        color: active ? const Color(0xFF00A750) : const Color(0xFFF2F4F7),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: active ? const Color(0xFF00A750) : const Color(0xFFE4E7EC)),
      ),
      alignment: Alignment.center,
      child: Text(
        '$_count',
        style: TextStyle(
          color: active ? Colors.white : const Color(0xFF6B746E),
          fontSize: widget.compact ? 9 : 10,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}
