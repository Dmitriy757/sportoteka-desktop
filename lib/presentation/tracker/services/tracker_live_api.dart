import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/tracker_live_models.dart';
import 'polar_heart_rate_ble_service.dart';

class TrackerLiveApi {
  TrackerLiveApi({this.apiBaseUrl = 'https://sportotekaapp.ru/api/tracker'});

  final String apiBaseUrl;

  Future<int> startLiveSession({
    required int clubId,
    required int teamId,
    int? playerId,
    int? fieldId,
    required String deviceUuid,
    required String deviceName,
    String source = 'tracker',
    int? batteryPercent,
    String? activityType,
    bool? fieldRequired,
  }) async {
    final json = await _post('$apiBaseUrl/start_tracker_live_session.php', {
      'club_id': clubId,
      'team_id': teamId,
      'player_id': playerId,
      'field_id': fieldId,
      'device_uuid': deviceUuid,
      'device_name': deviceName,
      'source': source,
      'battery_percent': batteryPercent,
      'activity_type': activityType,
      'field_required': fieldRequired == null ? null : (fieldRequired ? 1 : 0),
    });

    return int.tryParse('${json['live_session_id'] ?? json['id'] ?? 0}') ?? 0;
  }

  Future<Map<String, dynamic>> saveLivePoint(TrackerLivePointPayload payload) {
    return _post('$apiBaseUrl/save_tracker_live_point.php', payload.toJson());
  }

  Future<Map<String, dynamic>> saveHeartRateSample({
    required int clubId,
    required int teamId,
    required int playerId,
    int? liveSessionId,
    int? sessionId,
    required HeartRateSample sample,
  }) {
    return _post('$apiBaseUrl/save_tracker_heart_rate_sample.php', {
      'club_id': clubId,
      'team_id': teamId,
      'player_id': playerId,
      'live_session_id': liveSessionId,
      'session_id': sessionId,
      'device_uuid': sample.deviceId,
      'device_name': sample.deviceName,
      'bpm': sample.bpm,
      'battery_percent': sample.batteryPercent,
      'sensor_contact': sample.sensorContactDetected == null ? null : (sample.sensorContactDetected! ? 1 : 0),
      'rr_intervals_ms': sample.rrIntervalsMs,
      'measured_at': sample.measuredAt.toIso8601String(),
    });
  }

  Future<List<TrackerLiveSessionModel>> loadTeamLiveState({
    required int teamId,
    int? fieldId,
  }) async {
    final json = await _get(
      '$apiBaseUrl/get_tracker_live_state.php?team_id=$teamId${fieldId == null ? '' : '&field_id=$fieldId'}',
    );

    final list = (json['sessions'] as List? ?? const []);
    return list
        .map((e) => TrackerLiveSessionModel.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> heartbeatLiveSession({
    required int liveSessionId,
    String statusText = 'waiting_gps',
  }) async {
    await _post('$apiBaseUrl/heartbeat_tracker_live_session.php', {
      'live_session_id': liveSessionId,
      'status_text': statusText,
    });
  }

  Future<Map<String, dynamic>> stopLiveSession({
    required int liveSessionId,
    bool createFinalSession = true,
  }) async {
    return _post('$apiBaseUrl/stop_tracker_live_session.php', {
      'live_session_id': liveSessionId,
      'create_final_session': createFinalSession ? 1 : 0,
    });
  }

  Future<Map<String, dynamic>> saveLiveMetricSnapshot(Map<String, dynamic> payload) {
    return _post('$apiBaseUrl/save_tracker_metric_snapshot.php', payload);
  }


  Future<Map<String, dynamic>> saveLiveAsTrackerSession({
    required int clubId,
    required int teamId,
    int? playerId,
    int? fieldId,
    required String deviceUuid,
    required String deviceName,
    required Map<String, dynamic> record,
    required List<Map<String, dynamic>> points,
    Map<String, dynamic>? analysisJson,
  }) {
    return _post('$apiBaseUrl/save_tracker_session.php', {
      'club_id': clubId,
      'team_id': teamId,
      'player_id': playerId,
      'field_id': fieldId,
      'device_uuid': deviceUuid,
      'device_name': deviceName,
      'record': record,
      'points': points,
      'analysis_json': analysisJson,
      'source': 'live',
    });
  }


  Future<List<Map<String, dynamic>>> loadMetricSnapshotsByDate({
    required int teamId,
    required String date,
    int? playerId,
  }) async {
    final json = await _get(
      '$apiBaseUrl/get_tracker_metric_snapshots.php?team_id=$teamId&date=$date${playerId == null ? '' : '&player_id=$playerId'}',
    );
    final list = (json['items'] as List? ?? const []);
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> sendDebugLog({
    required int teamId,
    int? playerId,
    int? liveSessionId,
    required String level,
    required String source,
    required String message,
    String? rawHex,
    String? platform,
    String? appVersion,
    String? deviceUuid,
    String? deviceName,
    Map<String, dynamic>? context,
  }) async {
    await _post('$apiBaseUrl/save_tracker_debug_log.php', {
      'team_id': teamId,
      'player_id': playerId,
      'live_session_id': liveSessionId,
      'level': level,
      'source': source,
      'platform': platform ?? 'flutter',
      'app_version': appVersion,
      'device_uuid': deviceUuid,
      'device_name': deviceName,
      'message': message,
      'raw_hex': rawHex,
      'context': context,
    });
  }

  Future<List<Map<String, dynamic>>> loadDebugLogs({
    required int teamId,
    int? liveSessionId,
    String? source,
    int limit = 150,
  }) async {
    final safeLimit = limit.clamp(20, 500);
    final url = '$apiBaseUrl/get_tracker_debug_logs.php?team_id=$teamId'
        '${liveSessionId == null ? '' : '&live_session_id=$liveSessionId'}'
        '${source == null || source.trim().isEmpty ? '' : '&source=${Uri.encodeQueryComponent(source.trim())}'}'
        '&limit=$safeLimit';
    final json = await _get(url);
    final list = (json['logs'] as List? ?? const []);
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }


  Future<List<Map<String, dynamic>>> loadLivePeriods({
    required int liveSessionId,
  }) async {
    try {
      final json = await _get('$apiBaseUrl/get_tracker_session_periods.php?live_session_id=$liveSessionId&mode=live');
      final list = (json['periods'] as List? ?? json['items'] as List? ?? const []);
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (e) {
      // Старый PHP падал с Unknown column live_session_id. Периоды не должны ломать Live.
      final text = e.toString();
      if (text.contains('live_session_id') || text.contains('get_tracker_session_periods')) {
        return const <Map<String, dynamic>>[];
      }
      rethrow;
    }
  }

  Future<void> saveLivePeriod({
    required int liveSessionId,
    required int teamId,
    required Map<String, dynamic> period,
  }) async {
    await _post('$apiBaseUrl/save_tracker_session_period.php', {
      'live_session_id': liveSessionId,
      'team_id': teamId,
      ...period,
    });
  }

  Future<Map<String, dynamic>> _get(String url) async {
    final response = await http.get(
      Uri.parse(url),
      headers: const {
        'Cache-Control': 'no-cache, no-store, must-revalidate',
        'Pragma': 'no-cache',
      },
    ).timeout(const Duration(seconds: 8));
    return _decode(response.body);
  }

  Future<Map<String, dynamic>> _post(String url, Map<String, dynamic> body) async {
    final response = await http
        .post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json; charset=utf-8'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 25));
    return _decode(response.body);
  }

  Map<String, dynamic> _decode(String body) {
    final trimmed = body.trim();

    if (trimmed.isEmpty) {
      throw Exception('Сервер вернул пустой ответ. Проверьте PHP-файл и подключение db.php.');
    }

    final start = trimmed.indexOf('{');
    if (start < 0) {
      throw Exception('Сервер вернул не JSON: $trimmed');
    }

    final decoded = jsonDecode(trimmed.substring(start));
    if (decoded is! Map) {
      throw Exception('Некорректный ответ сервера');
    }

    final map = Map<String, dynamic>.from(decoded);
    if (map['success'] == false || map['status'] == 'error') {
      final msg = '${map['message'] ?? 'Ошибка API'}';
      final err = '${map['error'] ?? ''}'.trim();
      throw Exception(err.isEmpty ? msg : '$msg: $err');
    }

    return map;
  }
}
