import 'dart:convert';
import 'package:http/http.dart' as http;

class MatchPlayersService {
  static const String baseUrl = 'https://sportotekaapp.ru/api';

  static Future<Map<String, dynamic>> saveMatchPlayers({
    required int matchId,
    required int teamId,
    required List<Map<String, dynamic>> players,
  }) async {
    final uri = Uri.parse('$baseUrl/save_match_players.php');

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: jsonEncode({
        'match_id': matchId,
        'team_id': teamId,
        'players': players,
      }),
    );

    final data = jsonDecode(response.body);

    if (data['success'] == true) {
      return Map<String, dynamic>.from(data);
    }

    throw Exception(data['message'] ?? 'Ошибка сохранения состава матча');
  }

  static Future<List<Map<String, dynamic>>> getMatchPlayers({
    required int matchId,
  }) async {
    final uri = Uri.parse('$baseUrl/get_match_players.php?match_id=$matchId');

    final response = await http.get(uri);
    final data = jsonDecode(response.body);

    if (data['success'] == true) {
      return List<Map<String, dynamic>>.from(data['players'] ?? []);
    }

    throw Exception(data['message'] ?? 'Ошибка загрузки состава матча');
  }
}