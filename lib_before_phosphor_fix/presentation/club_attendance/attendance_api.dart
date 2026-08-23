// lib/presentation/club_attendance/attendance_api.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class AttendanceApi {
  AttendanceApi({required this.apiBase});
  final String apiBase;

  String get _checkAccess => "$apiBase/check_attendance_access.php";
  String get _getEvents => "$apiBase/get_team_events_for_month.php";
  String get _getPlayers => "$apiBase/get_players_by_team.php";
  String get _getMatrix => "$apiBase/get_attendance_matrix.php";
  String get _setMark => "$apiBase/set_attendance_mark.php";

  Map<String, dynamic> _decode(http.Response r) {
    try {
      final j = json.decode(r.body);
      if (j is Map<String, dynamic>) return j;
      return {"success": false};
    } catch (_) {
      return {"success": false};
    }
  }

  Future<bool> checkAccess({
    required int userId,
    required int clubId,
    required int teamId,
  }) async {
    final resp = await http.post(
      Uri.parse(_checkAccess),
      body: {
        "user_id": userId.toString(),
        "club_id": clubId.toString(),
        "team_id": teamId.toString(),
      },
    );
    final data = _decode(resp);
    return data["success"] == true && data["allowed"] == true;
  }

  Future<List<Map<String, dynamic>>> getEventsForMonth({
    required int teamId,
    required int year,
    required int month,
  }) async {
    final resp = await http.post(
      Uri.parse(_getEvents),
      body: {
        "team_id": teamId.toString(),
        "year": year.toString(),
        "month": month.toString(),
      },
    );
    final data = _decode(resp);
    if (data["success"] == true && data["events"] is List) {
      return (data["events"] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getPlayersByTeam(int teamId) async {
    final resp = await http.post(
      Uri.parse(_getPlayers),
      body: {"team_id": teamId.toString()},
    );
    final data = _decode(resp);
    if (data["success"] == true && data["players"] is List) {
      return (data["players"] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }

  Future<Map<String, String>> getAttendanceMatrix({
    required int teamId,
    required int year,
    required int month,
  }) async {
    // возвращаем map: "playerId|eventId" -> mark
    final resp = await http.post(
      Uri.parse(_getMatrix),
      body: {
        "team_id": teamId.toString(),
        "year": year.toString(),
        "month": month.toString(),
      },
    );
    final data = _decode(resp);
    final out = <String, String>{};

    if (data["success"] == true && data["marks"] is List) {
      for (final item in (data["marks"] as List)) {
        if (item is! Map) continue;
        final p = (item["player_id"] ?? "").toString();
        final e = (item["event_id"] ?? "").toString();
        final m = (item["mark"] ?? "").toString();
        if (p.isNotEmpty && e.isNotEmpty) {
          out["$p|$e"] = m;
        }
      }
    }
    return out;
  }

  Future<bool> setMark({
    required int teamId,
    required int eventId,
    required int playerId,
    required String mark,
    required int userId,
  }) async {
    final resp = await http.post(
      Uri.parse(_setMark),
      body: {
        "team_id": teamId.toString(),
        "event_id": eventId.toString(),
        "player_id": playerId.toString(),
        "mark": mark,
        "user_id": userId.toString(),
      },
    );
    final data = _decode(resp);
    return data["success"] == true;
  }
}
