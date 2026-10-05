import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:sportoteka/core/utils/pref_utils.dart';

class PersonalModuleService {
  const PersonalModuleService._();

  static const String _base = 'https://sportotekaapp.ru/api/personal_modules';

  static Map<String, dynamic> _decode(http.Response response) {
    try {
      final raw = utf8.decode(response.bodyBytes, allowMalformed: true).trim();
      if (raw.isEmpty) {
        return <String, dynamic>{
          'success': false,
          'message': 'Пустой ответ сервера',
          '_http_status': response.statusCode,
        };
      }
      final value = jsonDecode(raw);
      if (value is Map<String, dynamic>) {
        return <String, dynamic>{...value, '_http_status': response.statusCode};
      }
      if (value is Map) {
        return <String, dynamic>{
          ...Map<String, dynamic>.from(value),
          '_http_status': response.statusCode,
        };
      }
    } catch (e) {
      return <String, dynamic>{
        'success': false,
        'message': 'Не удалось разобрать ответ сервера: $e',
        '_http_status': response.statusCode,
      };
    }
    return <String, dynamic>{
      'success': false,
      'message': 'Некорректный ответ сервера',
      '_http_status': response.statusCode,
    };
  }

  static Future<Map<String, dynamic>> _post(
    String endpoint,
    Map<String, String> body,
  ) async {
    try {
      final response = await http
          .post(Uri.parse('$_base/$endpoint'), body: body)
          .timeout(const Duration(seconds: 15));
      return _decode(response);
    } catch (e) {
      return <String, dynamic>{
        'success': false,
        'message': 'Ошибка соединения: $e',
      };
    }
  }

  static Future<Map<String, dynamic>> status({required int userId}) {
    return _post('status.php', <String, String>{'user_id': '$userId'});
  }

  static Future<Map<String, dynamic>> statusForCurrentUser() async {
    final userId = await PrefUtils.getUserId() ?? 0;
    if (userId <= 0) {
      return <String, dynamic>{
        'success': false,
        'message': 'Не удалось определить пользователя',
      };
    }
    return status(userId: userId);
  }

  static Future<Map<String, dynamic>> request({
    required int userId,
    required String moduleCode,
    String source = 'personal_workspace',
  }) {
    return _post('request.php', <String, String>{
      'user_id': '$userId',
      'module_code': moduleCode,
      'source': source,
    });
  }

  static Future<Map<String, dynamic>> check({
    required int userId,
    required String moduleCode,
  }) {
    return _post('check.php', <String, String>{
      'user_id': '$userId',
      'module_code': moduleCode,
    });
  }

  static Future<bool> hasAccessForCurrentUser(String moduleCode) async {
    final userId = await PrefUtils.getUserId() ?? 0;
    if (userId <= 0) return false;
    final result = await check(userId: userId, moduleCode: moduleCode);
    return result['success'] == true && result['has_access'] == true;
  }

  static Future<Map<String, dynamic>> consume({
    required int userId,
    required String moduleCode,
    int amount = 1,
    String? usageKey,
  }) {
    return _post('consume.php', <String, String>{
      'user_id': '$userId',
      'module_code': moduleCode,
      'amount': '$amount',
      if (usageKey != null && usageKey.trim().isNotEmpty)
        'usage_key': usageKey.trim(),
    });
  }

  static List<Map<String, dynamic>> modules(Map<String, dynamic> status) {
    final raw = status['modules'];
    if (raw is! List) return const <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  static Map<String, dynamic>? module(
    Map<String, dynamic> status,
    String moduleCode,
  ) {
    for (final item in modules(status)) {
      if ('${item['module_code'] ?? ''}' == moduleCode) return item;
    }
    return null;
  }
}
