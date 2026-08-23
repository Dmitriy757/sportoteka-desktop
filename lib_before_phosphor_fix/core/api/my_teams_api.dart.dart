import 'dart:convert';
import 'package:http/http.dart' as http;

class MyTeamsApi {
  static const String apiBase = "https://sportotekaapp.ru/api";
  static const String getMyTeamsUrl = "$apiBase/get_my_teams.php";

  static Map<String, dynamic> _decode(http.Response r) {
    try {
      final j = json.decode(r.body);
      if (j is Map<String, dynamic>) return j;
    } catch (_) {}
    return {"success": false, "message": "bad json"};
  }

  static Future<List<Map<String, dynamic>>> fetchMyAssignedTeams(int userId) async {
    final resp = await http.post(
      Uri.parse(getMyTeamsUrl),
      body: {"user_id": userId.toString()},
    );

    final data = _decode(resp);

    if (data["success"] == true && data["teams"] is List) {
      return (data["teams"] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }
}
