import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import '../models/player_profile_models.dart';

class PlayerProfileRepository {
  final String apiBase;
  final http.Client _client;
  PlayerProfileRepository({this.apiBase = 'https://sportotekaapp.ru/api', http.Client? client}) : _client = client ?? http.Client();

  int _i(dynamic v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;
  double _d(dynamic v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}'.replaceAll(',', '.')) ?? 0;
  String _s(dynamic v) => '${v ?? ''}'.trim();
  DateTime? _date(dynamic v) => DateTime.tryParse(_s(v).replaceAll(' ', 'T'));

  Future<Map<String, dynamic>> _get(String endpoint, Map<String, String> qp) async {
    final response = await _client.get(Uri.parse('$apiBase/$endpoint').replace(queryParameters: qp)).timeout(const Duration(seconds: 18));
    final body = response.body.trim();
    if (body.isEmpty || body.startsWith('<')) return {};
    final decoded = jsonDecode(body);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return {};
  }

  List<Map<String, dynamic>> _list(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is List) return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      if (value is Map) {
        for (final nested in ['items', 'rows', 'data']) {
          final v = value[nested];
          if (v is List) return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        }
      }
    }
    return [];
  }


  Future<Map<String, dynamic>> _post(String endpoint, Map<String, dynamic> body) async {
    final response = await _client.post(
      Uri.parse('$apiBase/$endpoint'),
      headers: const {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 18));
    final raw = response.body.trim();
    if (raw.isEmpty || raw.startsWith('<')) throw Exception('Некорректный ответ сервера');
    final decoded = jsonDecode(raw);
    if (decoded is! Map) throw Exception('Некорректный ответ сервера');
    final data = Map<String, dynamic>.from(decoded);
    if (data['success'] == false || data['status'] == 'error') {
      throw Exception('${data['message'] ?? 'Операция не выполнена'}');
    }
    return data;
  }

  Future<void> savePlayerMetrics({required int playerId, required int userId, required Map<String, dynamic> values}) async {
    await _post('medical/save_player_metrics.php', {
      'player_id': playerId,
      'user_id': userId,
      ...values,
    });
  }

  Future<void> saveMedicalRecord({
    required int playerId,
    required int userId,
    required Map<String, dynamic> record,
    PlatformFile? attachment,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$apiBase/medical/save_medical_record.php'),
    );
    request.fields.addAll({
      'player_id': '$playerId',
      'user_id': '$userId',
      'created_by': '$userId',
      'record_id': '${_i(record['id'] ?? record['record_id'])}',
      'title': _s(record['title']),
      'note': _s(record['note'] ?? record['comment'] ?? record['description']),
      'record_date': _s(record['record_date'] ?? record['date']),
      'remove_file': record['remove_file'] == true ? '1' : '0',
    });

    if (attachment != null) {
      if (attachment.bytes != null) {
        request.files.add(http.MultipartFile.fromBytes(
          'file',
          attachment.bytes!,
          filename: attachment.name,
        ));
      } else if ((attachment.path ?? '').isNotEmpty) {
        request.files.add(await http.MultipartFile.fromPath(
          'file',
          attachment.path!,
          filename: attachment.name,
        ));
      }
    }

    final streamed = await request.send().timeout(const Duration(seconds: 45));
    final response = await http.Response.fromStream(streamed);
    final raw = response.body.trim();
    if (raw.isEmpty || raw.startsWith('<')) {
      throw Exception('Некорректный ответ сервера');
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map) throw Exception('Некорректный ответ сервера');
    final data = Map<String, dynamic>.from(decoded);
    if (response.statusCode < 200 || response.statusCode >= 300 || data['success'] != true) {
      throw Exception('${data['message'] ?? data['error'] ?? 'Не удалось сохранить медицинскую запись'}');
    }
  }

  Future<void> deleteMedicalRecord({required int playerId, required int userId, required Map<String, dynamic> record}) async {
    await _post('medical/delete_medical_record.php', {
      'player_id': playerId,
      'user_id': userId,
      'record_id': _i(record['id'] ?? record['record_id']),
    });
  }

  String _stageForPlayer(Map<String, dynamic> player) {
    final direct = _s(player['stage'] ?? player['age_stage']).toUpperCase();
    final directMatch = RegExp(r'U-?(\d{1,2})').firstMatch(direct);
    if (directMatch != null) return 'U${directMatch.group(1)}';

    final team = _s(player['team_name'] ?? player['teamName']).toUpperCase();
    final teamMatch = RegExp(r'U-?(\d{1,2})').firstMatch(team);
    if (teamMatch != null) return 'U${teamMatch.group(1)}';

    final birth = _date(player['birth_date'] ?? player['birthday'] ?? player['date_of_birth']);
    if (birth != null) {
      final now = DateTime.now();
      var age = now.year - birth.year;
      if (now.month < birth.month || (now.month == birth.month && now.day < birth.day)) age--;
      if (age >= 6 && age <= 17) return 'U$age';
    }
    return 'U13';
  }

  String _categoryTitle(String code) {
    switch (code) {
      case 'physical': return 'Физическая подготовка';
      case 'technical': return 'Техническая подготовка';
      case 'tactical': return 'Тактическая подготовка';
      case 'psychological': return 'Психологическая подготовка';
      case 'theory': return 'Теория';
      case 'functional': return 'Функциональное состояние';
      default: return code;
    }
  }

  Future<List<Map<String, dynamic>>> _loadTestingHistory(Map<String, dynamic> player) async {
    final clubId = _i(player['club_id'] ?? player['clubId']);
    final teamId = _i(player['team_id'] ?? player['teamId']);
    final playerId = _i(player['player_id'] ?? player['id'] ?? player['user_id']);
    if (clubId <= 0 || teamId <= 0 || playerId <= 0) return [];

    final stage = _stageForPlayer(player);
    const categories = ['physical', 'technical', 'tactical', 'psychological', 'theory', 'functional'];
    final sessionResponses = await Future.wait(categories.map((category) async {
      final data = await _get('get_testing_sessions.php', {
        'club_id': '$clubId',
        'team_id': '$teamId',
        'category': category,
        'stage': stage,
      }).catchError((_) => <String, dynamic>{});
      return _list(data, ['sessions', 'items', 'rows', 'data']).map((row) => {
        ...row,
        '_category': category,
      }).toList();
    }));

    final sessions = sessionResponses.expand((e) => e).toList();
    sessions.sort((a, b) => (_date(b['test_date'] ?? b['date']) ?? DateTime(1970)).compareTo(_date(a['test_date'] ?? a['date']) ?? DateTime(1970)));
    final selected = sessions.take(30).toList();

    final histories = await Future.wait(selected.map((session) async {
      final category = _s(session['_category']);
      final sessionId = _i(session['id'] ?? session['session_id']);
      final testDate = _s(session['test_date'] ?? session['date']);
      if (sessionId <= 0) return <Map<String, dynamic>>[];

      final matrix = await _get('get_testing_matrix.php', {
        'club_id': '$clubId',
        'team_id': '$teamId',
        'category': category,
        'stage': stage,
        'session_id': '$sessionId',
        if (testDate.isNotEmpty) 'test_date': testDate.substring(0, testDate.length >= 10 ? 10 : testDate.length),
      }).catchError((_) => <String, dynamic>{});

      final tests = _list(matrix, ['tests']);
      final players = _list(matrix, ['players']);
      Map<String, dynamic>? current;
      for (final row in players) {
        if (_i(row['id'] ?? row['player_id'] ?? row['user_id']) == playerId) {
          current = row;
          break;
        }
      }
      if (current == null) return <Map<String, dynamic>>[];
      final rawResults = current['results'];
      if (rawResults is! Map) return <Map<String, dynamic>>[];
      final results = Map<String, dynamic>.from(rawResults);

      final rows = <Map<String, dynamic>>[];
      for (final test in tests) {
        final code = _s(test['code']);
        final raw = results[code];
        if (raw == null) continue;
        final result = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{'value': raw};
        final value = _s(result['value'] ?? result['result']);
        if (value.isEmpty || value == 'null') continue;
        rows.add({
          'session_id': sessionId,
          'date': testDate,
          'test_date': testDate,
          'category': category,
          'category_title': _categoryTitle(category),
          'stage': stage,
          'test_code': code,
          'test_name': _s(test['short_title']).isEmpty ? _s(test['title']) : _s(test['short_title']),
          'unit': code == 'long_jump' ? 'см' : _s(test['unit']),
          'value': value,
          'result': value,
          'rating': _s(result['rating'] ?? result['rating_code']),
          'rating_label': _s(result['label'] ?? result['rating_label'] ?? result['grade']),
          'points': _i(result['points']),
        });
      }
      return rows;
    }));

    final out = histories.expand((e) => e).toList();
    out.sort((a, b) => (_date(b['test_date']) ?? DateTime(1970)).compareTo(_date(a['test_date']) ?? DateTime(1970)));
    return out;
  }

  Future<PlayerProfileSnapshot> loadSnapshot(Map<String, dynamic> player) async {
    final teamId = _i(player['team_id'] ?? player['teamId']);
    final clubId = _i(player['club_id'] ?? player['clubId']);
    final playerId = _i(player['player_id'] ?? player['id'] ?? player['user_id']);
    final results = await Future.wait([
      _get('get_team_events.php', {'team_id': '$teamId', 'club_id': '$clubId'}).catchError((_) => <String,dynamic>{}),
      _get('get_player_attendance_log.php', {'team_id': '$teamId', 'player_id': '$playerId'}).catchError((_) => <String,dynamic>{}),
      _get('get_team_matches.php', {'team_id': '$teamId'}).catchError((_) => <String,dynamic>{}),
      _loadTestingHistory(player).catchError((_) => <Map<String, dynamic>>[]),
      _get('medical/get_medical_records.php', {
        'player_id': '$playerId',
        'user_id': '${_i(player['user_id'] ?? playerId)}',
      }).catchError((_) => <String,dynamic>{}),
      _get('tracker/get_tracker_sessions.php', {'team_id': '$teamId', 'player_id': '$playerId', 'include_personal': '1', 'limit': '300'}).catchError((_) => <String,dynamic>{}),
    ]);
    Map<String, dynamic> mapResultAt(int index) {
      final value = results[index];
      if (value is Map<String, dynamic>) return value;
      if (value is Map) return Map<String, dynamic>.from(value);
      return <String, dynamic>{};
    }

    final trainings = _list(mapResultAt(0), ['events','items','rows','data']);
    final attendance = _list(mapResultAt(1), ['items','attendance','rows','data']);
    final matches = _list(mapResultAt(2), ['matches','items','rows','data']);
    final tests = results[3] is List
        ? (results[3] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : <Map<String, dynamic>>[];
    final medical = _list(mapResultAt(4), ['records','items','rows','data']);
    final sessionsRaw = _list(mapResultAt(5), ['sessions','items','rows','data']);
    final sessions = sessionsRaw.map((e) => PlayerProfileSession(
      id: _i(e['session_id'] ?? e['id']), date: _date(e['started_at'] ?? e['date'] ?? e['created_at']),
      title: _s(e['title']).isEmpty ? 'Сессия трекера' : _s(e['title']), distanceM: _d(e['total_distance_m'] ?? e['distance_m']),
      maxSpeedKmh: _d(e['max_speed_kmh'] ?? e['max_speed']), avgSpeedKmh: _d(e['avg_speed_kmh'] ?? e['avg_speed']),
      durationSec: _i(e['duration_sec'] ?? e['duration_seconds']), sprintCount: _i(e['sprint_count'] ?? e['sprints']),
      avgHr: _d(e['heart_rate_avg_bpm'] ?? e['avg_heart_rate_bpm'] ?? e['avg_hr']), maxHr: _d(e['heart_rate_max_bpm'] ?? e['max_heart_rate_bpm'] ?? e['max_hr']),
      minHr: _d(e['heart_rate_min_bpm'] ?? e['min_heart_rate_bpm'] ?? e['min_hr']),
    )).where((e) => e.id > 0).toList()..sort((a,b)=>(b.date ?? DateTime(1970)).compareTo(a.date ?? DateTime(1970)));
    final snapshot = PlayerProfileSnapshot(player: player, trainings: trainings, attendance: attendance, matches: matches, tests: tests, medical: medical, sessions: sessions);
    return snapshot.copyWith(timeline: buildTimeline(snapshot));
  }

  Future<PlayerProfileSession> loadSessionReport(PlayerProfileSession session, {required int teamId, required int playerId}) async {
    final data = await _get('tracker/get_training_report.php', {
      'session_id': '${session.id}', 'team_id': '$teamId', 'player_id': '$playerId',
      'include_maps': '1', 'include_heatmap': '1', 'include_charts': '1', 'include_hr': '1', 'include_players': '1', 'hr_fallback': '1',
    });
    final root = data['report'] is Map ? Map<String,dynamic>.from(data['report']) : data;
    List<dynamic> pick(List<String> keys) {
      for (final key in keys) { final v = root[key]; if (v is List) return v; }
      for (final group in ['map','charts','player','summary','data']) { final g=root[group]; if (g is Map) { for (final key in keys) { final v=g[key]; if (v is List) return v; } } }
      return const [];
    }
    List<PlayerProfilePoint> points(List<dynamic> raw) => raw.whereType<Map>().map((m) {
      final x = _d(m['x'] ?? m['field_x'] ?? m['lng'] ?? m['longitude']);
      final y = _d(m['y'] ?? m['field_y'] ?? m['lat'] ?? m['latitude']);
      return PlayerProfilePoint(x, y, value: _d(m['value'] ?? m['weight'] ?? m['intensity']));
    }).toList();
    List<double> nums(List<dynamic> raw, List<String> keys) => raw.map((e) {
      if (e is num) return e.toDouble();
      if (e is Map) { for (final k in keys) { final n=_d(e[k]); if (n>0) return n; } }
      return 0.0;
    }).where((e)=>e>0).toList();
    final hrRaw = pick(['heartRateTimeline','heart_rate_timeline','hr_series','heart_rate']);
    final hrValues = <double>[];
    final hrSeconds = <double>[];
    DateTime? firstHrTime;
    for (var index = 0; index < hrRaw.length; index++) {
      final item = hrRaw[index];
      double bpm = 0;
      double sec = index.toDouble();
      if (item is num) {
        bpm = item.toDouble();
      } else if (item is Map) {
        bpm = _d(item['bpm'] ?? item['heart_rate'] ?? item['value']);
        final directSec = _d(item['elapsed_sec'] ?? item['sec'] ?? item['second'] ?? item['seconds']);
        final minute = _d(item['minute']);
        final timeMs = _d(item['time_ms'] ?? item['timestamp_ms']);
        if (directSec > 0) {
          sec = directSec;
        } else if (minute > 0) {
          sec = minute * 60;
        } else if (timeMs > 0) {
          sec = timeMs / 1000;
        } else {
          final rawTime = item['recorded_at'] ?? item['created_at'] ?? item['timestamp'] ?? item['time'];
          final parsed = _date(rawTime);
          if (parsed != null) {
            firstHrTime ??= parsed;
            sec = parsed.difference(firstHrTime!).inMilliseconds / 1000;
          }
        }
      }
      if (bpm > 0) {
        hrValues.add(bpm);
        hrSeconds.add(sec);
      }
    }
    return session.copyWith(
      route: points(pick(['routePoints','route_points','route','gps_points','track_points'])),
      heatmap: points(pick(['heatmapPoints','heatmap_points','heatmap'])),
      speedTimeline: nums(pick(['speedTimeline','speed_timeline','speed_series']), ['speed','speed_kmh','value']),
      heartRateTimeline: hrValues,
      heartRateTimelineSec: hrSeconds,
      trackerReportJson: root,
    );
  }

  List<PlayerTimelineItem> buildTimeline(PlayerProfileSnapshot s) {
    final out = <PlayerTimelineItem>[];
    for (final e in s.trainings) out.add(PlayerTimelineItem(date: _date(e['start_at'] ?? e['date']), type: 'training', title: _s(e['title']).isEmpty ? 'Тренировка' : _s(e['title']), subtitle: _s(e['location']), icon: const IconData(0xe566, fontFamily: 'MaterialIcons')));
    for (final e in s.matches) out.add(PlayerTimelineItem(date: _date(e['match_date'] ?? e['date']), type: 'match', title: _s(e['opponent']).isEmpty ? 'Матч' : 'Матч · ${_s(e['opponent'])}', subtitle: _s(e['score']), icon: const IconData(0xe4dc, fontFamily: 'MaterialIcons')));
    for (final e in s.tests) out.add(PlayerTimelineItem(date: _date(e['date'] ?? e['created_at']), type: 'test', title: _s(e['test_name']).isEmpty ? 'Тестирование' : _s(e['test_name']), subtitle: _s(e['result'] ?? e['value']), icon: const IconData(0xe6e1, fontFamily: 'MaterialIcons')));
    for (final e in s.sessions) out.add(PlayerTimelineItem(date: e.date, type: 'tracker', title: e.title, subtitle: '${(e.distanceM/1000).toStringAsFixed(1)} км · ${e.maxSpeedKmh.toStringAsFixed(1)} км/ч', icon: const IconData(0xe425, fontFamily: 'MaterialIcons')));
    out.sort((a,b)=>(b.date ?? DateTime(1970)).compareTo(a.date ?? DateTime(1970)));
    return out;
  }
}
