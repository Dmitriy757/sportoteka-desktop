import 'dart:convert';
import 'package:http/http.dart' as http;

class AiPlanTemplateApi {
  static const String base =
      'https://sportotekaapp.ru/api/ai/v1/plans/ai';

  static Future<List<Map<String, dynamic>>> list({
    required int clubId,
    int? teamId,
    String search = '',
  }) async {
    final uri = Uri.parse('$base/templates').replace(
      queryParameters: {
        'club_id': '$clubId',
        if (teamId != null && teamId > 0) 'team_id': '$teamId',
        if (search.trim().isNotEmpty) 'search': search.trim(),
      },
    );

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    final raw = data is Map && data['items'] is List
        ? data['items'] as List
        : const [];

    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  static Future<Map<String, dynamic>> get(int templateId) async {
    final response = await http.get(
      Uri.parse('$base/templates/$templateId'),
    );
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  static Future<Map<String, dynamic>> clone({
    required int templateId,
    required int clubId,
    required int userId,
    int? teamId,
    String? title,
    String? targetDate,
    Map<String, dynamic> overrides = const {},
  }) async {
    final response = await http.post(
      Uri.parse('$base/templates/$templateId/clone'),
      headers: const {
        'Content-Type': 'application/json; charset=utf-8',
      },
      body: jsonEncode({
        'club_id': clubId,
        'user_id': userId,
        if (teamId != null) 'team_id': teamId,
        if (title != null) 'title': title,
        if (targetDate != null) 'target_date': targetDate,
        'overrides': overrides,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }

    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }
}
