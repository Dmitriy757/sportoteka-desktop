import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/tracker_live_models.dart';

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
    });

    return int.tryParse('${json['live_session_id'] ?? json['id'] ?? 0}') ?? 0;
  }

  Future<Map<String, dynamic>> saveLivePoint(TrackerLivePointPayload payload) {
    return _post('$apiBaseUrl/save_tracker_live_point.php', payload.toJson());
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

  Future<void> stopLiveSession({
    required int liveSessionId,
    bool createFinalSession = true,
  }) async {
    await _post('$apiBaseUrl/stop_tracker_live_session.php', {
      'live_session_id': liveSessionId,
      'create_final_session': createFinalSession ? 1 : 0,
    });
  }

  Future<Map<String, dynamic>> saveLiveMetricSnapshot(Map<String, dynamic> payload) {
    return _post('$apiBaseUrl/save_tracker_metric_snapshot.php', payload);
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
  }) async {
    try {
      await _post('$apiBaseUrl/save_tracker_debug_log.php', {
        'team_id': teamId,
        'player_id': playerId,
        'live_session_id': liveSessionId,
        'level': level,
        'source': source,
        'message': message,
        'raw_hex': rawHex,
      });
    } catch (_) {
      // Логи не должны ломать Live.
    }
  }

  Future<Map<String, dynamic>> _get(String url) async {
    final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));
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
