import 'dart:convert';

import 'package:http/http.dart' as http;

class SubscriptionRequestService {
  static const String _base = 'https://sportotekaapp.ru/api/subscriptions';
  static const String _requestUrl = '$_base/request.php';
  static const String _statusUrl = '$_base/status.php';

  static Map<String, dynamic> _decode(http.Response response) {
    try {
      final body = utf8.decode(response.bodyBytes, allowMalformed: true).trim();
      if (body.isEmpty) {
        return <String, dynamic>{
          'success': false,
          'message': 'Пустой ответ сервера',
        };
      }

      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);

      return <String, dynamic>{
        'success': false,
        'message': 'Некорректный ответ сервера',
      };
    } catch (e) {
      return <String, dynamic>{
        'success': false,
        'message': 'Не удалось разобрать ответ сервера: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> submit({
    required int userId,
    required String planCode,
    String billingPeriod = 'yearly',
    String source = 'subscription_screen',
  }) async {
    if (userId <= 0) {
      return <String, dynamic>{
        'success': false,
        'message': 'Не удалось определить пользователя',
      };
    }

    try {
      final response = await http.post(
        Uri.parse(_requestUrl),
        body: <String, String>{
          'user_id': '$userId',
          'plan_code': planCode,
          'billing_period': billingPeriod,
          'source': source,
        },
      ).timeout(const Duration(seconds: 15));

      final data = _decode(response);
      data['_http_status'] = response.statusCode;
      return data;
    } catch (e) {
      return <String, dynamic>{
        'success': false,
        'message': 'Ошибка соединения: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> status({
    required int userId,
  }) async {
    if (userId <= 0) {
      return <String, dynamic>{
        'success': false,
        'message': 'Не удалось определить пользователя',
      };
    }

    try {
      final response = await http.post(
        Uri.parse(_statusUrl),
        body: <String, String>{'user_id': '$userId'},
      ).timeout(const Duration(seconds: 12));

      final data = _decode(response);
      data['_http_status'] = response.statusCode;
      return data;
    } catch (e) {
      return <String, dynamic>{
        'success': false,
        'message': 'Ошибка соединения: $e',
      };
    }
  }
}
