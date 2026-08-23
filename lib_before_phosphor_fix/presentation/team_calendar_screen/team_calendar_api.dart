import 'dart:convert';
import 'package:http/http.dart' as http;

import 'team_calendar_models.dart';

class TeamCalendarApi {
  final String apiBase;

  TeamCalendarApi({required this.apiBase});

  String get _getUrl => "$apiBase/get_team_events.php";
  String get _addUrl => "$apiBase/add_team_event.php";
  String get _updateUrl => "$apiBase/update_team_event.php";
  String get _deleteUrl => "$apiBase/delete_team_event.php";

  Future<List<TeamEvent>> fetch({
    required int teamId,
    required DateTime from,
    required DateTime to,
  }) async {
    final uri = Uri.parse(_getUrl).replace(queryParameters: {
      "team_id": teamId.toString(),
      "from": formatDateSql(from),
      "to": formatDateSql(to),
    });

    final res = await http.get(uri);
    final data = jsonDecode(res.body);

    if (data is Map && data["success"] == true && data["items"] is List) {
      final list = (data["items"] as List)
          .whereType<Map>()
          .map((e) => TeamEvent.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      return list;
    }

    final msg = (data is Map ? (data["message"] ?? "Не удалось загрузить календарь") : "Не удалось загрузить календарь");
    throw Exception(msg.toString());
  }

  Future<void> add({
    required TeamEvent event,
    required int createdBy,
  }) async {
    final body = {
      "team_id": event.teamId.toString(),
      "club_id": event.clubId.toString(),
      "type": eventTypeToDb(event.type), // ✅ ВАЖНО
      "title": event.title,
      "start_at": formatSqlDateTime(event.startAt),
      "end_at": event.endAt == null ? "" : formatSqlDateTime(event.endAt!),
      "location": event.location,
      "notes": event.notes,
      "created_by": createdBy.toString(),
    };

    final res = await http.post(Uri.parse(_addUrl), body: body);
    final data = jsonDecode(res.body);

    if (data is Map && data["success"] == true) return;

    final msg = (data is Map ? (data["message"] ?? "Не удалось добавить") : "Не удалось добавить");
    throw Exception(msg.toString());
  }

  Future<void> update({
    required TeamEvent event,
  }) async {
    final body = {
      "id": event.id.toString(),
      "team_id": event.teamId.toString(),
      "club_id": event.clubId.toString(),
      "type": eventTypeToDb(event.type), // ✅ ВАЖНО
      "title": event.title,
      "start_at": formatSqlDateTime(event.startAt),
      "end_at": event.endAt == null ? "" : formatSqlDateTime(event.endAt!),
      "location": event.location,
      "notes": event.notes,
    };

    final res = await http.post(Uri.parse(_updateUrl), body: body);
    final data = jsonDecode(res.body);

    if (data is Map && data["success"] == true) return;

    final msg = (data is Map ? (data["message"] ?? "Не удалось обновить") : "Не удалось обновить");
    throw Exception(msg.toString());
  }

  Future<void> remove({
    required int eventId,
    required int teamId,
  }) async {
    final res = await http.post(Uri.parse(_deleteUrl), body: {
      "id": eventId.toString(),
      "team_id": teamId.toString(),
    });

    final data = jsonDecode(res.body);

    if (data is Map && data["success"] == true) return;

    final msg = (data is Map ? (data["message"] ?? "Не удалось удалить") : "Не удалось удалить");
    throw Exception(msg.toString());
  }
}
