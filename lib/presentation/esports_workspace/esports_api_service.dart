import 'dart:convert';

import 'package:http/http.dart' as http;

/// Client contract for the dedicated Sportoteka Esports server layer.
///
/// Football endpoints are intentionally not used here. The server can keep
/// esports tables and permissions fully isolated while reusing the same user
/// accounts and Staff Key activation flow.
class EsportsApiService {
  static const String base = 'https://sportotekaapp.ru/api/esports';

  static Map<String, dynamic> _decode(String body) {
    if (body.trim().isEmpty) {
      return <String, dynamic>{'success': false, 'message': 'Пустой ответ сервера'};
    }
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      if (decoded is List) {
        return <String, dynamic>{'success': true, 'items': decoded};
      }
    } catch (_) {}
    return <String, dynamic>{
      'success': false,
      'message': 'Сервер вернул некорректный ответ',
    };
  }

  static Future<Map<String, dynamic>> get(
    String endpoint, {
    Map<String, dynamic> query = const <String, dynamic>{},
    Duration timeout = const Duration(seconds: 12),
  }) async {
    try {
      final uri = Uri.parse('$base/$endpoint').replace(
        queryParameters: query.map((key, value) => MapEntry(key, '$value')),
      );
      final response = await http.get(uri, headers: const {
        'Accept': 'application/json',
      }).timeout(timeout);
      final data = _decode(utf8.decode(response.bodyBytes));
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

  static Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 18),
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$base/$endpoint'),
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json; charset=utf-8',
            },
            body: jsonEncode(body),
          )
          .timeout(timeout);
      final data = _decode(utf8.decode(response.bodyBytes));
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

  static List<Map<String, dynamic>> listFrom(
    Map<String, dynamic> data, {
    List<String> keys = const <String>['items', 'data'],
  }) {
    dynamic raw;
    for (final key in keys) {
      if (data[key] is List) {
        raw = data[key];
        break;
      }
    }
    raw ??= data['items'];
    if (raw is! List) return const <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
  }

  static Future<List<Map<String, dynamic>>> teams({
    required int clubId,
    int userId = 0,
  }) async {
    final data = await get('teams/list.php', query: {
      'club_id': clubId,
      if (userId > 0) 'user_id': userId,
    });
    if (data['success'] == false) throw Exception(data['message'] ?? 'Не удалось загрузить команды');
    return listFrom(data, keys: const ['teams', 'items', 'data']);
  }

  static Future<List<Map<String, dynamic>>> athletes({
    required int clubId,
    int? teamId,
    int userId = 0,
  }) async {
    final data = await get('players/list.php', query: {
      'club_id': clubId,
      if ((teamId ?? 0) > 0) 'team_id': teamId,
      if (userId > 0) 'user_id': userId,
    });
    if (data['success'] == false) throw Exception(data['message'] ?? 'Не удалось загрузить состав');
    return listFrom(data, keys: const ['players', 'athletes', 'items', 'data']);
  }

  static Future<List<Map<String, dynamic>>> matches({
    required int clubId,
    int? teamId,
  }) async {
    final data = await get('matches/list.php', query: {
      'club_id': clubId,
      if ((teamId ?? 0) > 0) 'team_id': teamId,
    });
    if (data['success'] == false) throw Exception(data['message'] ?? 'Не удалось загрузить матчи');
    return listFrom(data, keys: const ['matches', 'items', 'data']);
  }

  static Future<List<Map<String, dynamic>>> tournaments({
    required int clubId,
    int? teamId,
  }) async {
    final data = await get('tournaments/list.php', query: {
      'club_id': clubId,
      if ((teamId ?? 0) > 0) 'team_id': teamId,
    });
    if (data['success'] == false) throw Exception(data['message'] ?? 'Не удалось загрузить турниры');
    return listFrom(data, keys: const ['tournaments', 'items', 'data']);
  }

  static Future<List<Map<String, dynamic>>> streams({
    required int clubId,
    int? teamId,
  }) async {
    final data = await get('streams/list.php', query: {
      'club_id': clubId,
      if ((teamId ?? 0) > 0) 'team_id': teamId,
    });
    if (data['success'] == false) return const [];
    return listFrom(data, keys: const ['streams', 'items', 'data']);
  }

  static Future<List<Map<String, dynamic>>> recordings({
    required int clubId,
    int? teamId,
  }) async {
    final data = await get('recordings/list.php', query: {
      'club_id': clubId,
      if ((teamId ?? 0) > 0) 'team_id': teamId,
    });
    if (data['success'] == false) return const [];
    return listFrom(data, keys: const ['recordings', 'videos', 'items', 'data']);
  }

  static Future<List<Map<String, dynamic>>> aiReports({
    required int clubId,
    int? teamId,
  }) async {
    final data = await get('ai/reports.php', query: {
      'club_id': clubId,
      if ((teamId ?? 0) > 0) 'team_id': teamId,
    });
    if (data['success'] == false) return const [];
    return listFrom(data, keys: const ['reports', 'items', 'data']);
  }

  static Future<Map<String, dynamic>> createTeam(Map<String, dynamic> payload) =>
      post('teams/create.php', payload);

  static Future<Map<String, dynamic>> updateTeam(Map<String, dynamic> payload) =>
      post('teams/update.php', payload);

  static Future<Map<String, dynamic>> createAthlete(Map<String, dynamic> payload) =>
      post('players/create.php', payload);

  static Future<Map<String, dynamic>> updateAthlete(Map<String, dynamic> payload) =>
      post('players/update.php', payload);

  static Future<Map<String, dynamic>> createMatch(Map<String, dynamic> payload) =>
      post('matches/create.php', payload);

  static Future<Map<String, dynamic>> createTournament(Map<String, dynamic> payload) =>
      post('tournaments/create.php', payload);

  static Future<Map<String, dynamic>> prepareStream(Map<String, dynamic> payload) =>
      post('streams/prepare.php', payload);

  static Future<Map<String, dynamic>> startStream(Map<String, dynamic> payload) =>
      post('streams/start.php', payload);

  static Future<Map<String, dynamic>> stopStream(Map<String, dynamic> payload) =>
      post('streams/stop.php', payload, timeout: const Duration(seconds: 30));

  static Future<Map<String, dynamic>> streamStatus(int streamId) =>
      get('streams/status.php', query: {'stream_id': streamId});

  static Future<List<Map<String, dynamic>>> liveAiEvents(int streamId) async {
    final data = await get('streams/events.php', query: {'stream_id': streamId});
    if (data['success'] == false) return const [];
    return listFrom(data, keys: const ['events', 'items', 'data']);
  }

  static Future<Map<String, dynamic>> generateAiReport({
    required int clubId,
    required int matchId,
    int? streamId,
  }) =>
      post('ai/generate.php', {
        'club_id': clubId,
        'match_id': matchId,
        if ((streamId ?? 0) > 0) 'stream_id': streamId,
      }, timeout: const Duration(seconds: 45));

  // ---------------- Staff Access for Esports ----------------
  // These endpoints issue the SAME Staff Key format used by the general
  // activation screen. The access row must return workspace_type=esports.

  static Future<List<Map<String, dynamic>>> staffList({
    required int clubId,
    required int actorUserId,
  }) async {
    final data = await get('staff_access/list.php', query: {
      'club_id': clubId,
      'actor_user_id': actorUserId,
    });
    if (data['success'] == false) return const [];
    return listFrom(data, keys: const ['staff', 'accesses', 'items', 'data']);
  }

  static Future<Map<String, dynamic>> staffLookup({
    required int clubId,
    required int actorUserId,
    required String email,
  }) =>
      post('staff_access/lookup.php', {
        'club_id': clubId,
        'actor_user_id': actorUserId,
        'email': email,
        'workspace_type': 'esports',
      });

  static Future<Map<String, dynamic>> staffInvite({
    required int clubId,
    required int actorUserId,
    required String email,
    required String firstName,
    required String lastName,
    required String password,
    required String profile,
    required List<int> teamIds,
    required List<int> athleteIds,
  }) =>
      post('staff_access/invite.php', {
        'club_id': clubId,
        'actor_user_id': actorUserId,
        'email': email,
        'first_name': firstName,
        'last_name': lastName,
        'password': password,
        'profile': profile,
        'workspace_type': 'esports',
        'team_ids': teamIds,
        'player_ids': athleteIds,
      });

  static Future<Map<String, dynamic>> staffUpdateScope({
    required int clubId,
    required int actorUserId,
    required int staffUserId,
    required String profile,
    required List<int> teamIds,
    required List<int> athleteIds,
  }) =>
      post('staff_access/scope.php', {
        'club_id': clubId,
        'actor_user_id': actorUserId,
        'user_id': staffUserId,
        'profile': profile,
        'workspace_type': 'esports',
        'team_ids': teamIds,
        'player_ids': athleteIds,
      });

  static Future<Map<String, dynamic>> staffReissue({
    required int clubId,
    required int actorUserId,
    required int staffUserId,
  }) =>
      post('staff_access/reissue.php', {
        'club_id': clubId,
        'actor_user_id': actorUserId,
        'user_id': staffUserId,
        'workspace_type': 'esports',
      });

  static Future<Map<String, dynamic>> staffRevoke({
    required int clubId,
    required int actorUserId,
    required int staffUserId,
  }) =>
      post('staff_access/revoke.php', {
        'club_id': clubId,
        'actor_user_id': actorUserId,
        'user_id': staffUserId,
        'workspace_type': 'esports',
      });
}
