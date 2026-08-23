import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/action_tracker_protocol.dart';
import '../models/tracker_live_models.dart';
import 'polar_heart_rate_ble_service.dart';

class PlayerPersonalTrackerApi {
  PlayerPersonalTrackerApi({this.apiBaseUrl = 'https://sportotekaapp.ru/api/tracker'});

  final String apiBaseUrl;

  Future<int> startLiveSession({
    required int teamId,
    required int userId,
    int? clubId,
    int? playerId,
    int? fieldId,
    required String deviceUuid,
    required String deviceName,
    required String source,
    required String activityType,
    bool fieldRequired = false,
    int? batteryPercent,
  }) async {
    final json = await _post('$apiBaseUrl/player_start_live_session.php', <String, dynamic>{
      'club_id': clubId,
      'team_id': teamId,
      'user_id': userId,
      'owner_user_id': userId,
      'player_id': playerId,
      'field_id': fieldId,
      'device_uuid': deviceUuid,
      'device_name': deviceName,
      'source': source,
      'activity_type': activityType,
      'field_required': fieldRequired ? 1 : 0,
      'battery_percent': batteryPercent,
      'personal_session': 1,
      'started_by_role': 'player',
      'notify_coach': 1,
    });
    return int.tryParse('${json['live_session_id'] ?? json['id'] ?? 0}') ?? 0;
  }

  Future<void> heartbeatLiveSession({
    required int liveSessionId,
    required int teamId,
    required int userId,
    String statusText = 'active',
    Map<String, dynamic>? snapshot,
  }) async {
    await _post('$apiBaseUrl/player_heartbeat_live_session.php', <String, dynamic>{
      'live_session_id': liveSessionId,
      'team_id': teamId,
      'owner_user_id': userId,
      'status_text': statusText,
      'snapshot': snapshot,
    });
  }

  Future<Map<String, dynamic>> stopLiveSession({
    required int liveSessionId,
    required int teamId,
    required int userId,
    bool createFinalSession = true,
  }) {
    return _post('$apiBaseUrl/player_stop_live_session.php', <String, dynamic>{
      'live_session_id': liveSessionId,
      'team_id': teamId,
      'owner_user_id': userId,
      'create_final_session': createFinalSession ? 1 : 0,
      'notify_coach': 1,
    });
  }

  Future<Map<String, dynamic>> updateSessionEnvironment({
    required int liveSessionId,
    required double latitude,
    required double longitude,
    double? accuracyM,
  }) {
    return _post('$apiBaseUrl/player_update_session_environment.php', <String, dynamic>{
      'live_session_id': liveSessionId,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy_m': accuracyM,
    });
  }

  Future<Map<String, dynamic>> saveHeartRateSample({
    required int teamId,
    required int userId,
    int? clubId,
    int? playerId,
    int? liveSessionId,
    int? sessionId,
    required HeartRateSample sample,
    String? activityType,
  }) {
    return _post('$apiBaseUrl/player_save_heart_rate_sample.php', <String, dynamic>{
      'club_id': clubId,
      'team_id': teamId,
      'owner_user_id': userId,
      'player_id': playerId ?? userId,
      'live_session_id': liveSessionId,
      'session_id': sessionId,
      'device_uuid': sample.deviceId,
      'device_name': sample.deviceName,
      'bpm': sample.bpm,
      'battery_percent': sample.batteryPercent,
      'sensor_contact': sample.sensorContactDetected == null ? null : (sample.sensorContactDetected! ? 1 : 0),
      'rr_intervals_ms': sample.rrIntervalsMs,
      'measured_at': sample.measuredAt.toIso8601String(),
      'personal_session': 1,
      if (activityType != null && activityType.trim().isNotEmpty) 'activity_type': activityType.trim(),
    });
  }

  Future<Map<String, dynamic>> saveLivePoint({
    required TrackerLivePointPayload payload,
    required int userId,
    int? fieldId,
    String? activityType,
  }) {
    final body = payload.toJson();
    body['owner_user_id'] = userId;
    body['personal_session'] = 1;
    if (fieldId != null) body['field_id'] = fieldId;
    if (activityType != null) body['activity_type'] = activityType;
    return _post('$apiBaseUrl/player_save_live_point.php', body);
  }

  Future<List<Map<String, dynamic>>> loadSessions({
    required int teamId,
    required int userId,
    int? playerId,
    String? date,
    String? dateFrom,
    String? dateTo,
    int limit = 120,
  }) async {
    final query = <String, String>{
      'team_id': '$teamId',
      'owner_user_id': '$userId',
      'player_id': '${playerId ?? userId}',
      'limit': '${limit.clamp(1, 500)}',
    };
    if (date != null && date.trim().isNotEmpty) query['date'] = date.trim();
    if (dateFrom != null && dateFrom.trim().isNotEmpty) query['date_from'] = dateFrom.trim();
    if (dateTo != null && dateTo.trim().isNotEmpty) query['date_to'] = dateTo.trim();
    final json = await _get(Uri.parse('$apiBaseUrl/player_get_sessions.php').replace(queryParameters: query).toString());
    final list = (json['sessions'] as List? ?? json['items'] as List? ?? const <dynamic>[]);
    return list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList(growable: false);
  }

  Future<List<ActionTrackerGpsPoint>> loadSessionPoints({
    required int teamId,
    required int userId,
    int? sessionId,
    int limit = 5000,
  }) async {
    final query = <String, String>{
      'team_id': '$teamId',
      'owner_user_id': '$userId',
      if (sessionId != null && sessionId > 0) 'session_id': '$sessionId',
      'limit': '${limit.clamp(50, 15000)}',
    };
    final json = await _get(Uri.parse('$apiBaseUrl/player_get_session_points.php').replace(queryParameters: query).toString());
    final list = (json['points'] as List? ?? const <dynamic>[]);
    return list.whereType<Map>().map((row) {
      final m = Map<String, dynamic>.from(row);
      return ActionTrackerGpsPoint(
        timeMs: _i(m['time_ms'] ?? m['timestamp_ms']),
        latitude: _d(m['latitude'] ?? m['lat']),
        longitude: _d(m['longitude'] ?? m['lng'] ?? m['lon']),
        speedKmh: _dn(m['speed_kmh']),
        distanceDeltaM: _dn(m['distance_delta_m']),
        totalDistanceM: _dn(m['total_distance_m']),
        pointIndex: _in(m['point_index']),
        liveSessionId: _in(m['live_session_id']),
        sessionId: _in(m['session_id']),
        playerId: _in(m['player_id']),
      );
    }).where((p) => p.latitude.abs() > 0.000001 && p.longitude.abs() > 0.000001).toList(growable: false);
  }

  Future<List<TrackerLiveSessionModel>> loadPlayerLiveState({
    required int teamId,
    int? userId,
    int? playerId,
  }) async {
    final query = <String, String>{
      'team_id': '$teamId',
      if (userId != null) 'owner_user_id': '$userId',
      if (playerId != null) 'player_id': '$playerId',
    };
    final json = await _get(Uri.parse('$apiBaseUrl/player_get_live_state.php').replace(queryParameters: query).toString());
    final list = (json['sessions'] as List? ?? const <dynamic>[]);
    return list.whereType<Map>().map((e) => TrackerLiveSessionModel.fromJson(Map<String, dynamic>.from(e))).toList(growable: false);
  }

  Future<Map<String, dynamic>> loadCalendar({
    required int teamId,
    required int userId,
    int? playerId,
    String? month,
  }) {
    final query = <String, String>{
      'team_id': '$teamId',
      'owner_user_id': '$userId',
      if (playerId != null) 'player_id': '$playerId',
      if (month != null && month.trim().isNotEmpty) 'month': month.trim(),
    };
    return _get(Uri.parse('$apiBaseUrl/player_get_calendar.php').replace(queryParameters: query).toString());
  }

  Future<Map<String, dynamic>> _get(String url) async {
    final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 25));
    return _decode(response.body);
  }

  Future<Map<String, dynamic>> _post(String url, Map<String, dynamic> body) async {
    final response = await http
        .post(
          Uri.parse(url),
          headers: const {'Content-Type': 'application/json; charset=utf-8'},
          body: jsonEncode(_withoutNulls(body)),
        )
        .timeout(const Duration(seconds: 30));
    return _decode(response.body);
  }

  Map<String, dynamic> _decode(String body) {
    final text = body.trim();
    if (text.isEmpty) throw Exception('Сервер вернул пустой ответ');
    final start = text.indexOf('{');
    if (start < 0) throw Exception('Сервер вернул не JSON: $text');
    final decoded = jsonDecode(text.substring(start));
    if (decoded is! Map) throw Exception('Некорректный ответ сервера');
    final map = Map<String, dynamic>.from(decoded);
    if (map['success'] == false || map['status'] == 'error') {
      final msg = '${map['message'] ?? 'Ошибка API'}';
      final err = '${map['error'] ?? ''}'.trim();
      throw Exception(err.isEmpty ? msg : '$msg: $err');
    }
    return map;
  }

  Map<String, dynamic> _withoutNulls(Map<String, dynamic> input) {
    final out = <String, dynamic>{};
    input.forEach((key, value) {
      if (value != null) out[key] = value;
    });
    return out;
  }

  static int _i(dynamic value) => int.tryParse('$value') ?? (value is num ? value.toInt() : 0);
  static int? _in(dynamic value) {
    final text = '${value ?? ''}'.trim();
    if (text.isEmpty || text == 'null') return null;
    return int.tryParse(text) ?? (value is num ? value.toInt() : null);
  }

  static double _d(dynamic value) => double.tryParse('$value') ?? (value is num ? value.toDouble() : 0);
  static double? _dn(dynamic value) {
    final text = '${value ?? ''}'.trim();
    if (text.isEmpty || text == 'null') return null;
    return double.tryParse(text) ?? (value is num ? value.toDouble() : null);
  }
}
