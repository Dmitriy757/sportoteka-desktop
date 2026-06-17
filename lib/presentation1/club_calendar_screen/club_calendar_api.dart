// lib/data/api/club_calendar_api.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class ClubCalendarApi {
  final String apiBase;

  ClubCalendarApi({required this.apiBase});

  String get _getClubEventsUrl => "$apiBase/get_club_events.php";
  String get _getClubTeamsUrl => "$apiBase/get_club_teams.php";

  Future<Map<String, dynamic>> loadClubCalendarData({
    required int clubId,
    DateTime? from,
    DateTime? to,
  }) async {
    try {
      // Загружаем события клуба
      final eventsResp = await http.post(
        Uri.parse(_getClubEventsUrl),
        body: {"club_id": clubId.toString()},
      );
      
      // Загружаем команды клуба
      final teamsResp = await http.post(
        Uri.parse(_getClubTeamsUrl),
        body: {"club_id": clubId.toString()},
      );

      final eventsData = jsonDecode(eventsResp.body);
      final teamsData = jsonDecode(teamsResp.body);

      List<dynamic> events = [];
      List<dynamic> teams = [];

      if (eventsData is Map && eventsData["success"] == true) {
        events = (eventsData["events"] as List?) ?? [];
      }

      if (teamsData is Map && teamsData["success"] == true) {
        teams = (teamsData["teams"] as List?) ?? [];
      }

      return {
        "events": events,
        "teams": teams,
        "success": true,
      };
    } catch (e) {
      return {
        "events": [],
        "teams": [],
        "success": false,
        "message": "Ошибка загрузки: $e",
      };
    }
  }
}