import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/action_tracker_protocol.dart';
import '../models/tracker_pro_models.dart';

class TrackerProApi {
  TrackerProApi({this.apiBaseUrl = 'https://sportotekaapp.ru/api/tracker'});

  final String apiBaseUrl;

  Future<List<TrackerPlayerOption>> loadPlayers({required int teamId}) async {
    final json = await _get('$apiBaseUrl/get_tracker_players.php?team_id=$teamId');
    final list = (json['players'] as List? ?? json['data'] as List? ?? const []);
    return list.map((e) => TrackerPlayerOption.fromJson(Map<String, dynamic>.from(e as Map))).where((p) => p.id > 0).toList();
  }

  Future<List<TrackerDeviceModel>> loadDevices({required int teamId}) async {
    final json = await _get('$apiBaseUrl/get_tracker_devices.php?team_id=$teamId');
    final list = (json['devices'] as List? ?? const []);
    return list.map((e) => TrackerDeviceModel.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<void> registerOrBindDevice({
    required int clubId,
    required int teamId,
    required String deviceUuid,
    required String deviceName,
    int? playerId,
    int? batteryPercent,
  }) async {
    await _post('$apiBaseUrl/save_tracker_device.php', {
      'action': playerId == null ? 'unbind' : 'bind',
      'club_id': clubId,
      'team_id': teamId,
      'player_id': playerId,
      'device_uuid': deviceUuid,
      'device_name': deviceName,
      'battery_percent': batteryPercent,
    });
  }

  Future<Map<String, dynamic>> forgetServerDevice({
    required int teamId,
    int? deviceId,
    required String deviceUuid,
    required String deviceName,
  }) async {
    return _post('$apiBaseUrl/delete_tracker_device.php', {
      'team_id': teamId,
      'device_id': deviceId,
      'device_uuid': deviceUuid,
      'device_name': deviceName,
      'delete_aliases': true,
    });
  }

  Future<Map<String, dynamic>> saveGpsSession({
    required int clubId,
    required int teamId,
    int? userId,
    int? playerId,
    required String deviceUuid,
    required String deviceName,
    required ActionTrackerRecord record,
    required List<ActionTrackerGpsPoint> points,
    int? fieldId,
  }) async {
    return _post('$apiBaseUrl/save_tracker_session.php', {
      'club_id': clubId,
      'team_id': teamId,
      'user_id': userId,
      'player_id': playerId,
      'device_uuid': deviceUuid,
      'device_name': deviceName,
      'record': record.toJson(),
      'points': points.map((p) => p.toJson()).toList(),
      'field_id': fieldId,
    });
  }


  Future<Map<String, dynamic>> processSession({required int sessionId}) async {
    return _get('$apiBaseUrl/process_tracker_session.php?session_id=$sessionId');
  }

  Future<TrackerDashboardModel> loadDashboard({required int teamId, String? date, String? fromTime, String? toTime}) async {
    final url = '$apiBaseUrl/get_tracker_dashboard.php?team_id=$teamId'
        '${date == null || date.trim().isEmpty ? '' : '&date=${Uri.encodeQueryComponent(date.trim())}'}'
        '${fromTime == null || fromTime.trim().isEmpty ? '' : '&from_time=${Uri.encodeQueryComponent(fromTime.trim())}'}'
        '${toTime == null || toTime.trim().isEmpty ? '' : '&to_time=${Uri.encodeQueryComponent(toTime.trim())}'}';
    try {
      final json = await _get(url);
      return TrackerDashboardModel.fromJson(json);
    } catch (e) {
      // Аналитика не должна падать целым экраном, если новый PHP ещё не загружен
      // или сервер временно вернул пустой ответ. Ошибка останется в debug/console.
      // ignore: avoid_print
      print('[TRACKER_ANALYTICS_API] dashboard fallback: $e');
      return const TrackerDashboardModel(summary: <String, dynamic>{}, players: <TrackerPlayerLoadRow>[], alerts: <Map<String, dynamic>>[]);
    }
  }

  Future<List<TrackerSessionModel>> loadSessions({required int teamId, int? playerId, String? date, String? fromTime, String? toTime, int? limit, String? sessionKind}) async {
    final kind = (sessionKind ?? '').trim().toLowerCase();
    final kindQuery = kind == 'personal'
        ? '&session_kind=personal&personal_session=1&include_personal=1'
        : kind == 'team'
            ? '&session_kind=team&exclude_personal=1'
            : kind == 'all'
                ? '&session_kind=all&include_personal=1&include_player_sessions=1'
                : '';
    final url = '$apiBaseUrl/get_tracker_sessions.php?team_id=$teamId'
        '${playerId == null ? '' : '&player_id=$playerId'}'
        '${date == null || date.trim().isEmpty ? '' : '&date=${Uri.encodeQueryComponent(date.trim())}'}'
        '${fromTime == null || fromTime.trim().isEmpty ? '' : '&from_time=${Uri.encodeQueryComponent(fromTime.trim())}'}'
        '${toTime == null || toTime.trim().isEmpty ? '' : '&to_time=${Uri.encodeQueryComponent(toTime.trim())}'}'
        '${limit == null ? '' : '&limit=$limit'}'
        '$kindQuery';
    try {
      final json = await _get(url);
      final list = (json['sessions'] as List? ?? const []);
      return list.map((e) => TrackerSessionModel.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } catch (e) {
      // ignore: avoid_print
      print('[TRACKER_ANALYTICS_API] sessions fallback: $e');
      return const <TrackerSessionModel>[];
    }
  }

  Future<List<TrackerHeatPoint>> loadHeatmap({required int teamId, int? playerId, int? sessionId, int? fieldId, String? date, String? fromTime, String? toTime}) async {
    final url = '$apiBaseUrl/get_tracker_heatmap.php?team_id=$teamId'
        '${playerId == null ? '' : '&player_id=$playerId'}'
        '${sessionId == null ? '' : '&session_id=$sessionId'}'
        '${fieldId == null ? '' : '&field_id=$fieldId'}'
        '${date == null || date.trim().isEmpty ? '' : '&date=${Uri.encodeQueryComponent(date.trim())}'}'
        '${fromTime == null || fromTime.trim().isEmpty ? '' : '&from_time=${Uri.encodeQueryComponent(fromTime.trim())}'}'
        '${toTime == null || toTime.trim().isEmpty ? '' : '&to_time=${Uri.encodeQueryComponent(toTime.trim())}'}';
    try {
      final json = await _get(url);
      final list = (json['points'] as List? ?? const []);
      return list.map((e) => TrackerHeatPoint.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } catch (e) {
      // ignore: avoid_print
      print('[TRACKER_ANALYTICS_API] heatmap fallback: $e');
      return const <TrackerHeatPoint>[];
    }
  }


  Future<List<ActionTrackerGpsPoint>> loadSessionPoints({
    required int teamId,
    int? playerId,
    int? sessionId,
    String? date,
    String? fromTime,
    String? toTime,
    int limit = 5000,
  }) async {
    final url = '$apiBaseUrl/get_tracker_session_points.php?team_id=$teamId'
        '${playerId == null ? '' : '&player_id=$playerId'}'
        '${sessionId == null ? '' : '&session_id=$sessionId'}'
        '${date == null || date.trim().isEmpty ? '' : '&date=${Uri.encodeQueryComponent(date.trim())}'}'
        '${fromTime == null || fromTime.trim().isEmpty ? '' : '&from_time=${Uri.encodeQueryComponent(fromTime.trim())}'}'
        '${toTime == null || toTime.trim().isEmpty ? '' : '&to_time=${Uri.encodeQueryComponent(toTime.trim())}'}'
        '&limit=$limit';
    try {
      final json = await _get(url);
      final list = (json['points'] as List? ?? const []);
      return list.map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        final time = int.tryParse('${m['time_ms'] ?? m['timestamp_ms'] ?? m['ts'] ?? 0}') ?? 0;
        final lat = double.tryParse('${m['latitude'] ?? m['lat'] ?? 0}') ?? 0;
        final lon = double.tryParse('${m['longitude'] ?? m['lng'] ?? m['lon'] ?? 0}') ?? 0;
        double? dOpt(String key) {
          final v = m[key];
          if (v == null || '$v'.trim().isEmpty || '$v' == 'null') return null;
          return double.tryParse('$v');
        }
        int? iOpt(String key) {
          final v = m[key];
          if (v == null || '$v'.trim().isEmpty || '$v' == 'null') return null;
          return int.tryParse('$v');
        }
        bool bOpt(String key) {
          final v = m[key];
          return v == true || '$v' == '1' || '$v'.toLowerCase() == 'true';
        }
        return ActionTrackerGpsPoint(
          timeMs: time,
          latitude: lat,
          longitude: lon,
          speedKmh: dOpt('speed_kmh'),
          distanceDeltaM: dOpt('distance_delta_m'),
          totalDistanceM: dOpt('total_distance_m'),
          pointIndex: iOpt('point_index'),
          liveSessionId: iOpt('live_session_id'),
          sessionId: iOpt('session_id'),
          playerId: iOpt('player_id'),
          breakBefore: bOpt('break_before'),
        );
      }).where((p) => p.latitude != 0 && p.longitude != 0).toList();
    } catch (e) {
      // ignore: avoid_print
      print('[TRACKER_ANALYTICS_API] session points fallback: $e');
      return const <ActionTrackerGpsPoint>[];
    }
  }

  Future<Map<String, dynamic>> loadHeartRateSummary({
    required int teamId,
    int? playerId,
    int? sessionId,
    List<int>? sessionIds,
    String? date,
    String? fromTime,
    String? toTime,
    String? sessionKind,
  }) async {
    final ids = (sessionIds ?? const <int>[]).where((id) => id > 0).toList(growable: false);
    final url = '$apiBaseUrl/get_tracker_heart_rate_summary.php?team_id=$teamId'
        '${playerId == null ? '' : '&player_id=$playerId'}'
        '${sessionId == null ? '' : '&session_id=$sessionId'}'
        '${ids.isEmpty ? '' : '&session_ids=${Uri.encodeQueryComponent(ids.join(','))}'}'
        '${date == null || date.trim().isEmpty ? '' : '&date=${Uri.encodeQueryComponent(date.trim())}'}'
        '${fromTime == null || fromTime.trim().isEmpty ? '' : '&from_time=${Uri.encodeQueryComponent(fromTime.trim())}'}'
        '${toTime == null || toTime.trim().isEmpty ? '' : '&to_time=${Uri.encodeQueryComponent(toTime.trim())}'}'
        '${sessionKind == null || sessionKind.trim().isEmpty ? '' : '&session_kind=${Uri.encodeQueryComponent(sessionKind.trim())}'}';
    try {
      return await _get(url);
    } catch (e) {
      // ignore: avoid_print
      print('[TRACKER_ANALYTICS_API] heart rate fallback: $e');
      return const <String, dynamic>{'success': true, 'items': <Map<String, dynamic>>[], 'timeline': <Map<String, dynamic>>[], 'summary': <String, dynamic>{}};
    }
  }




  Future<Map<String, dynamic>> loadTrainingReportHeartRate({
    required int teamId,
    required int sessionId,
    int? playerId,
  }) async {
    if (sessionId <= 0) return const <String, dynamic>{};
    try {
      final playerParam = playerId == null || playerId <= 0 ? '' : '&player_id=$playerId';
      final json = await _get('$apiBaseUrl/get_training_report.php?session_id=$sessionId&team_id=$teamId$playerParam&hr_fallback=1&include_hr=1&include_players=1&include_charts=1');
      final report = Map<String, dynamic>.from(json['report'] as Map? ?? json);
      final summary = Map<String, dynamic>.from(report['summary'] as Map? ?? const <String, dynamic>{});
      dynamic nested(Map<String, dynamic> map, String parent, String child) {
        final raw = map[parent];
        return raw is Map ? raw[child] : null;
      }
      dynamic listFrom(dynamic raw) {
        if (raw is Map) return raw['items'] ?? raw['points'] ?? raw['timeline'] ?? raw['players'] ?? const <dynamic>[];
        return raw;
      }
      final rawPlayers = listFrom(report['players'] ?? report['player_summaries'] ?? nested(report, 'heart_rate', 'players') ?? report['diagnostic_players']) as List? ?? const <dynamic>[];
      final rawTimeline = listFrom(report['heart_rate_timeline'] ?? report['hr_timeline'] ?? report['heartRateTimeline'] ?? nested(report, 'heart_rate', 'timeline') ?? nested(report, 'hr', 'timeline') ?? nested(report, 'polar', 'timeline')) as List? ?? const <dynamic>[];
      final selectedPlayerId = playerId == null || playerId <= 0 ? null : playerId;
      bool samePlayer(dynamic row) {
        if (selectedPlayerId == null) return true;
        if (row is! Map) return false;
        final id = int.tryParse('${row['player_id'] ?? row['id'] ?? row['playerId'] ?? ''}');
        return id == selectedPlayerId;
      }
      final players = selectedPlayerId == null ? rawPlayers : rawPlayers.where(samePlayer).toList(growable: false);
      final timeline = selectedPlayerId == null ? rawTimeline : rawTimeline.where(samePlayer).toList(growable: false);
      return <String, dynamic>{
        'success': true,
        'summary': <String, dynamic>{
          ...summary,
          if (summary.containsKey('heart_rate_avg_bpm')) 'avg_bpm': summary['heart_rate_avg_bpm'],
          if (summary.containsKey('heart_rate_max_bpm')) 'max_bpm': summary['heart_rate_max_bpm'],
          if (summary.containsKey('heart_rate_samples_count')) 'samples_count': summary['heart_rate_samples_count'],
        },
        'players': players,
        'timeline': timeline,
        'source': 'training_report_fallback',
      };
    } catch (e) {
      // ignore: avoid_print
      print('[TRACKER_ANALYTICS_API] training report HR fallback failed: $e');
      return const <String, dynamic>{};
    }
  }


  Future<List<TrackerFieldModel>> loadFields({required int teamId}) async {
    final json = await _get('$apiBaseUrl/get_tracker_fields.php?team_id=$teamId');
    final list = (json['fields'] as List? ?? const []);
    return list.map((e) => TrackerFieldModel.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<Map<String, dynamic>> saveField({
    required int clubId,
    required int teamId,
    required TrackerFieldModel field,
  }) {
    return _post('$apiBaseUrl/save_tracker_field.php', field.toJson(
      overrideClubId: clubId,
      overrideTeamId: teamId,
    ));
  }

  Future<TrackerSpeedSettings> loadSettings({required int teamId}) async {
    final json = await _get('$apiBaseUrl/get_tracker_settings.php?team_id=$teamId');
    return TrackerSpeedSettings.fromJson(Map<String, dynamic>.from(json['settings'] as Map? ?? const {}));
  }

  Future<void> saveSettings({required int teamId, required TrackerSpeedSettings settings}) async {
    final payload = settings.toJson();
    // Некоторые старые таблицы имели узкий ENUM/VARCHAR для preset и падали с
    // Warning 1265 Data truncated. Отправляем короткий стабильный код профиля.
    payload['preset'] = TrackerSpeedSettings.normalizePreset(payload['preset']);
    await _post('$apiBaseUrl/save_tracker_settings.php', {
      'team_id': teamId,
      ...payload,
    });
  }

  Future<Map<String, dynamic>> _get(String url) async {
    final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 25));
    return _decode(response.body);
  }

  Future<Map<String, dynamic>> _post(String url, Map<String, dynamic> body) async {
    final response = await http
        .post(Uri.parse(url), headers: {'Content-Type': 'application/json; charset=utf-8'}, body: jsonEncode(body))
        .timeout(const Duration(seconds: 35));
    return _decode(response.body);
  }

  Map<String, dynamic> _decode(String body) {
    final trimmed = body.trim();

    if (trimmed.isEmpty) {
      throw Exception('Сервер вернул пустой ответ: PHP-файл не отдал JSON. Проверьте, что на сервер загружены tracker_debug_bootstrap.php и нужный API-файл из патча v37.');
    }

    final start = trimmed.indexOf('{');
    if (start < 0) {
      throw Exception('Сервер вернул не JSON: $trimmed');
    }

    final decoded = jsonDecode(trimmed.substring(start));
    if (decoded is! Map) {
      throw Exception('Некорректный ответ сервера: $trimmed');
    }

    final map = Map<String, dynamic>.from(decoded);
    if (map['success'] == false || map['status'] == 'error') {
      final message = '${map['message'] ?? 'Ошибка API'}';
      final error = '${map['error'] ?? ''}'.trim();
      throw Exception(error.isEmpty ? message : '$message: $error');
    }
    return map;
  }
}
