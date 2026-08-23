import 'dart:convert';
import 'package:http/http.dart' as http;

class AiWorkspaceActionApi {
  static const String actionUrl =
      'https://sportotekaapp.ru/api/ai/v1/assistant/action';

  static Future<Map<String, dynamic>> execute({
    required int clubId,
    required int userId,
    required int? teamId,
    required Map<String, dynamic> action,
    bool confirmed = true,
  }) async {
    final response = await http.post(
      Uri.parse(actionUrl),
      headers: const {
        'Content-Type': 'application/json; charset=utf-8',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'club_id': clubId,
        'user_id': userId,
        if ((teamId ?? 0) > 0) 'team_id': teamId,
        'confirmed': confirmed,
        'action': action,
      }),
    );

    final decoded = jsonDecode(response.body);
    if (response.statusCode != 200 || decoded is! Map) {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }

    return Map<String, dynamic>.from(decoded);
  }
}
