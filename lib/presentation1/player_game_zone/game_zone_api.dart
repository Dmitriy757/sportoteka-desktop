import 'dart:convert';
import 'package:http/http.dart' as http;

class GameZoneApi {
  static const String base = 'https://sportotekaapp.ru/api';

  static Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$base/$endpoint'),
        body: body.map((k, v) => MapEntry(k, v.toString())),
      );

      final decoded = json.decode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);

      return {
        "success": false,
        "message": "Некорректный ответ сервера",
      };
    } catch (e) {
      return {
        "success": false,
        "message": "Ошибка сети: $e",
      };
    }
  }
}