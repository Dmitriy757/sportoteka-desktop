import 'dart:convert';

import 'package:http/http.dart' as http;

class StaffAccessService {
  static const String _base = 'https://sportotekaapp.ru/api/staff_access';

  static Map<String, dynamic> _decode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return <String, dynamic>{
      'success': false,
      'message': 'Сервер вернул некорректный ответ',
    };
  }

  static Future<Map<String, dynamic>> _post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_base/$endpoint'),
            headers: const {
              'Content-Type': 'application/json; charset=utf-8',
              'Accept': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 18));

      final data = _decode(response.body);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return <String, dynamic>{
          ...data,
          'success': false,
          'http_status': response.statusCode,
        };
      }

      return data;
    } catch (error) {
      return <String, dynamic>{
        'success': false,
        'message': 'Ошибка подключения: $error',
      };
    }
  }

  static Future<Map<String, dynamic>> loadMyStatus(int userId) {
    return _post('my_status.php', <String, dynamic>{
      'user_id': userId,
    });
  }

  static Future<Map<String, dynamic>> activate({
    required int userId,
    required String staffKey,
  }) {
    return _post('activate.php', <String, dynamic>{
      'user_id': userId,
      'staff_key': staffKey,
    });
  }

  static Future<Map<String, dynamic>> lookup({
    required int clubId,
    required int actorUserId,
    required String email,
  }) {
    return _post('lookup.php', <String, dynamic>{
      'club_id': clubId,
      'actor_user_id': actorUserId,
      'email': email,
    });
  }

  static Future<Map<String, dynamic>> invite({
    required int clubId,
    required int actorUserId,
    required String email,
    required String firstName,
    required String lastName,
    required String password,
    required String profile,
    required List<int> teamIds,
  }) {
    return _post('invite.php', <String, dynamic>{
      'club_id': clubId,
      'actor_user_id': actorUserId,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'password': password,
      'profile': profile,
      'team_ids': teamIds,
    });
  }

  static Future<Map<String, dynamic>> loadManagedStatus({
    required int clubId,
    required int staffUserId,
    required int actorUserId,
  }) {
    return _post('status.php', <String, dynamic>{
      'club_id': clubId,
      'user_id': staffUserId,
      'actor_user_id': actorUserId,
    });
  }

  static Future<Map<String, dynamic>> manage({
    required String action,
    required int clubId,
    required int staffUserId,
    required int actorUserId,
    String? profile,
  }) {
    return _post('manage.php', <String, dynamic>{
      'action': action,
      'club_id': clubId,
      'user_id': staffUserId,
      'actor_user_id': actorUserId,
      if (profile != null) 'profile': profile,
    });
  }

  static Future<Map<String, dynamic>> updateScope({
    required int clubId,
    required int staffUserId,
    required int actorUserId,
    required String profile,
    required List<int> teamIds,
  }) {
    return _post('scope.php', <String, dynamic>{
      'club_id': clubId,
      'user_id': staffUserId,
      'actor_user_id': actorUserId,
      'profile': profile,
      'team_ids': teamIds,
    });
  }

  static List<Map<String, dynamic>> accesses(
    Map<String, dynamic> state,
  ) {
    final raw = state['accesses'];
    if (raw is! List) return const <Map<String, dynamic>>[];

    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static Set<int> activeClubIds(Map<String, dynamic> state) {
    final raw = state['active_club_ids'];
    if (raw is! List) return <int>{};

    return raw
        .map((value) => int.tryParse('$value') ?? 0)
        .where((value) => value > 0)
        .toSet();
  }
}
