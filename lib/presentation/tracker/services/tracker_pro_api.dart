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
      'club_id': clubId,
      'team_id': teamId,
      'player_id': playerId,
      'device_uuid': deviceUuid,
      'device_name': deviceName,
      'battery_percent': batteryPercent,
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

  Future<TrackerDashboardModel> loadDashboard({required int teamId}) async {
    final json = await _get('$apiBaseUrl/get_tracker_dashboard.php?team_id=$teamId');
    return TrackerDashboardModel.fromJson(json);
  }

  Future<List<TrackerSessionModel>> loadSessions({required int teamId, int? playerId}) async {
    final url = '$apiBaseUrl/get_tracker_sessions.php?team_id=$teamId${playerId == null ? '' : '&player_id=$playerId'}';
    final json = await _get(url);
    final list = (json['sessions'] as List? ?? const []);
    return list.map((e) => TrackerSessionModel.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<List<TrackerHeatPoint>> loadHeatmap({required int teamId, int? playerId, int? sessionId, int? fieldId}) async {
    final url = '$apiBaseUrl/get_tracker_heatmap.php?team_id=$teamId'
        '${playerId == null ? '' : '&player_id=$playerId'}'
        '${sessionId == null ? '' : '&session_id=$sessionId'}'
        '${fieldId == null ? '' : '&field_id=$fieldId'}';
    final json = await _get(url);
    final list = (json['points'] as List? ?? const []);
    return list.map((e) => TrackerHeatPoint.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }



  Future<List<TrackerFieldModel>> loadFields({required int teamId}) async {
    final json = await _get('$apiBaseUrl/get_tracker_fields.php?team_id=$teamId');
    final list = (json['fields'] as List? ?? const []);
    return list.map((e) => TrackerFieldModel.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<void> saveField({
    required int clubId,
    required int teamId,
    required TrackerFieldModel field,
  }) async {
    await _post('$apiBaseUrl/save_tracker_field.php', field.toJson(
      overrideClubId: clubId,
      overrideTeamId: teamId,
    ));
  }

  Future<TrackerSpeedSettings> loadSettings({required int teamId}) async {
    final json = await _get('$apiBaseUrl/get_tracker_settings.php?team_id=$teamId');
    return TrackerSpeedSettings.fromJson(Map<String, dynamic>.from(json['settings'] as Map? ?? const {}));
  }

  Future<void> saveSettings({required int teamId, required TrackerSpeedSettings settings}) async {
    await _post('$apiBaseUrl/save_tracker_settings.php', {
      'team_id': teamId,
      ...settings.toJson(),
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
      throw Exception('Сервер вернул пустой ответ. Проверьте PHP-файл и путь к db.php.');
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
