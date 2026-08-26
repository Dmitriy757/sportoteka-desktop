import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:sportoteka/core/utils/pref_utils.dart';

class WorkspaceEntityDataBridge {
  static const String apiBase = 'https://sportotekaapp.ru/api';

  int asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}'.trim()) ?? 0;
  }

  String asString(dynamic value) {
    final s = '${value ?? ''}'.trim();
    return s == 'null' ? '' : s;
  }

  dynamic decode(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  List<Map<String, dynamic>> list(dynamic data, [List<String> keys = const <String>[]]) {
    dynamic raw = data;
    if (raw is Map) {
      for (final key in keys) {
        final candidate = raw[key];
        if (candidate is List) {
          raw = candidate;
          break;
        }
      }
      if (raw is Map) {
        for (final key in const <String>['items', 'data', 'rows', 'result', 'records']) {
          final candidate = raw[key];
          if (candidate is List) {
            raw = candidate;
            break;
          }
        }
      }
    }
    if (raw is! List) return <Map<String, dynamic>>[];
    return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Map<String, dynamic> map(dynamic data, [List<String> keys = const <String>[]]) {
    if (data is Map) {
      final converted = Map<String, dynamic>.from(data);
      for (final key in keys) {
        final candidate = converted[key];
        if (candidate is Map) return Map<String, dynamic>.from(candidate);
      }
      return converted;
    }
    return <String, dynamic>{};
  }

  int trainerId(Map<String, dynamic> trainer) => asInt(
        trainer['trainer_id'] ?? trainer['trainerId'] ?? trainer['user_id'] ?? trainer['id'],
      );

  int teamId(Map<String, dynamic> team) => asInt(team['team_id'] ?? team['teamId'] ?? team['id']);

  String teamName(Map<String, dynamic> team) {
    final name = asString(team['team_name'] ?? team['teamName'] ?? team['name'] ?? team['title']);
    return name.isEmpty ? 'Команда' : name;
  }

  List<Map<String, dynamic>> trainerTeams(
    Map<String, dynamic> trainer,
    List<Map<String, dynamic>> allTeams,
  ) {
    final raw = trainer['teams'];
    if (raw is List) {
      final rows = raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      if (rows.isNotEmpty) return rows;
    }

    final ids = <int>{};
    for (final key in const <String>['team_id', 'teamId']) {
      final id = asInt(trainer[key]);
      if (id > 0) ids.add(id);
    }
    final rawIds = trainer['team_ids'] ?? trainer['teamIds'];
    if (rawIds is List) {
      for (final value in rawIds) {
        final id = asInt(value);
        if (id > 0) ids.add(id);
      }
    }
    if (ids.isNotEmpty) {
      final selected = allTeams.where((t) => ids.contains(teamId(t))).toList();
      if (selected.isNotEmpty) return selected;
    }
    return <Map<String, dynamic>>[];
  }

  Future<Map<String, dynamic>> loadTrainerProfile(Map<String, dynamic> trainer) async {
    final id = trainerId(trainer);
    if (id <= 0) return Map<String, dynamic>.from(trainer);
    try {
      final response = await http
          .post(
            Uri.parse('$apiBase/get_trainer_profile.php'),
            headers: const <String, String>{'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode(<String, dynamic>{'trainer_id': id}),
          )
          .timeout(const Duration(seconds: 15));
      final loaded = map(decode(response.body), const <String>['profile', 'trainer', 'user', 'data']);
      return <String, dynamic>{...trainer, ...loaded};
    } catch (_) {
      return Map<String, dynamic>.from(trainer);
    }
  }

  Future<bool> saveTrainerProfile({
    required Map<String, dynamic> trainer,
    required Map<String, String> fields,
  }) async {
    final id = trainerId(trainer);
    if (id <= 0) return false;
    final actorUserId = await PrefUtils.getUserId() ?? 0;
    final actorRole = (await PrefUtils.getRole()).trim().toLowerCase();
    final payload = <String, dynamic>{
      'trainer_id': id,
      'actor_user_id': actorUserId,
      'actor_role': actorRole,
      ...fields,
    };
    final response = await http
        .post(
          Uri.parse('$apiBase/update_trainer_profile.php'),
          headers: const <String, String>{'Content-Type': 'application/json; charset=utf-8'},
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 20));
    final data = decode(response.body);
    return data is Map && (data['success'] == true || data['status'] == 'success' || data['status'] == 'ok');
  }

  Future<List<Map<String, dynamic>>> loadTrainerSchedule({
    required Map<String, dynamic> trainer,
    required List<Map<String, dynamic>> allTeams,
  }) async {
    final teams = trainerTeams(trainer, allTeams);
    final rows = <Map<String, dynamic>>[];
    for (final team in teams) {
      final id = teamId(team);
      if (id <= 0) continue;
      try {
        final uri = Uri.parse('$apiBase/get_team_events.php').replace(queryParameters: <String, String>{'team_id': '$id'});
        final response = await http.get(uri).timeout(const Duration(seconds: 12));
        final events = list(decode(response.body), const <String>['events', 'items', 'rows', 'data']);
        for (final event in events) {
          rows.add(<String, dynamic>{...event, 'team_id': id, 'team_name': teamName(team)});
        }
      } catch (_) {}
    }
    return rows;
  }

  Future<List<Map<String, dynamic>>> loadTrainerAttendance({required int trainerId, required int clubId}) =>
      _getRows('get_trainer_attendance.php', <String, String>{'trainer_id': '$trainerId', 'club_id': '$clubId'});

  Future<List<Map<String, dynamic>>> loadTrainerHealth({required int trainerId, required int clubId}) =>
      _getRows('get_trainer_medical_records.php', <String, String>{'trainer_id': '$trainerId', 'club_id': '$clubId'});

  Future<List<Map<String, dynamic>>> loadTrainerDocuments({required int trainerId, required int clubId}) =>
      _getRows('get_trainer_documents.php', <String, String>{'trainer_id': '$trainerId', 'club_id': '$clubId'});

  Future<void> updateTrainerDocument({
    required int trainerId,
    required int clubId,
    required Map<String, dynamic> record,
    required String title,
    required String documentType,
    required String note,
    required String documentNumber,
    required String issuedBy,
    required String issueDate,
    required String validUntil,
  }) async {
    final recordId = asInt(record['id'] ?? record['record_id'] ?? record['document_id']);
    if (trainerId <= 0 || clubId <= 0 || recordId <= 0) {
      throw StateError('Не удалось определить документ тренера');
    }
    final actorUserId = await PrefUtils.getUserId() ?? 0;
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$apiBase/trainer_hr/save_trainer_document.php'),
    );
    request.fields.addAll(<String, String>{
      'record_id': '$recordId',
      'trainer_id': '$trainerId',
      'club_id': '$clubId',
      if (actorUserId > 0) 'created_by': '$actorUserId',
      'title': title.trim().isEmpty ? 'Документ' : title.trim(),
      'valid_until': validUntil.trim(),
      'note': note.trim(),
      'remove_file': '0',
      'document_type': documentType.trim(),
      'document_number': documentNumber.trim(),
      'issued_by': issuedBy.trim(),
      'issue_date': issueDate.trim(),
    });
    final streamed = await request.send().timeout(const Duration(seconds: 45));
    final response = await http.Response.fromStream(streamed);
    final data = decode(response.body);
    final ok = response.statusCode >= 200 && response.statusCode < 300 &&
        data is Map && (data['success'] == true || data['status'] == 'success' || data['status'] == 'ok');
    if (!ok) {
      throw StateError(data is Map
          ? '${data['message'] ?? data['error'] ?? 'Не удалось обновить документ тренера'}'
          : 'Не удалось обновить документ тренера');
    }
  }

  Future<void> uploadTrainerDocuments({
    required int trainerId,
    required int clubId,
    required List<String> filePaths,
  }) async {
    if (trainerId <= 0 || clubId <= 0 || filePaths.isEmpty) return;
    final actorUserId = await PrefUtils.getUserId() ?? 0;
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    final issueDate = '${now.year}-${two(now.month)}-${two(now.day)}';

    for (final path in filePaths) {
      final normalized = path.trim();
      if (normalized.isEmpty) continue;
      final fileName = normalized.split(RegExp(r'[\\/]')).last;
      final title = fileName.replaceFirst(RegExp(r'\.[^.]+$'), '');
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$apiBase/trainer_hr/save_trainer_document.php'),
      );
      request.fields.addAll(<String, String>{
        'record_id': '0',
        'trainer_id': '$trainerId',
        'club_id': '$clubId',
        if (actorUserId > 0) 'created_by': '$actorUserId',
        'title': title.isEmpty ? fileName : title,
        'valid_until': '',
        'note': '',
        'remove_file': '0',
        'document_type': 'Файл',
        'document_number': '',
        'issued_by': '',
        'issue_date': issueDate,
      });
      request.files.add(await http.MultipartFile.fromPath('file', normalized, filename: fileName));
      final streamed = await request.send().timeout(const Duration(seconds: 90));
      final response = await http.Response.fromStream(streamed);
      final data = decode(response.body);
      final ok = response.statusCode >= 200 && response.statusCode < 300 &&
          data is Map && (data['success'] == true || data['status'] == 'success' || data['status'] == 'ok');
      if (!ok) {
        throw StateError(data is Map
            ? '${data['message'] ?? data['error'] ?? 'Не удалось загрузить документ тренера'}'
            : 'Не удалось загрузить документ тренера');
      }
    }
  }

  Future<List<Map<String, dynamic>>> loadTrainerPlans({required int trainerId, required int clubId}) async {
    if (trainerId <= 0) return <Map<String, dynamic>>[];
    try {
      final uri = Uri.parse('$apiBase/get_latest_training_plans.php').replace(queryParameters: <String, String>{
        'club_id': '$clubId',
        'trainer_id': '$trainerId',
        'limit': '500',
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      return list(decode(response.body), const <String>['plans', 'items', 'data', 'result', 'rows']);
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<List<Map<String, dynamic>>> loadTrainerTesting({
    required Map<String, dynamic> trainer,
    required List<Map<String, dynamic>> allTeams,
    required int clubId,
  }) async {
    final rows = <Map<String, dynamic>>[];
    for (final team in trainerTeams(trainer, allTeams)) {
      final id = teamId(team);
      if (id <= 0) continue;
      try {
        final uri = Uri.parse('$apiBase/get_testing_sessions.php').replace(queryParameters: <String, String>{
          'club_id': '$clubId',
          'team_id': '$id',
          'category': 'physical',
        });
        final response = await http.get(uri).timeout(const Duration(seconds: 12));
        final sessions = list(decode(response.body), const <String>['sessions', 'items', 'data', 'rows']);
        for (final session in sessions) {
          rows.add(<String, dynamic>{...session, 'team_id': id, 'team_name': teamName(team)});
        }
      } catch (_) {}
    }
    return rows;
  }

  Future<List<Map<String, dynamic>>> loadTeamRoster({
    required Map<String, dynamic> team,
    required List<Map<String, dynamic>> knownPlayers,
  }) async {
    final id = teamId(team);
    final local = knownPlayers.where((p) {
      final pid = asInt(p['team_id'] ?? p['teamId']);
      return id > 0 && pid == id;
    }).map((e) => Map<String, dynamic>.from(e)).toList();
    if (local.isNotEmpty) return local;
    if (id <= 0) return <Map<String, dynamic>>[];
    try {
      final uri = Uri.parse('$apiBase/get_players_by_team.php').replace(queryParameters: <String, String>{'team_id': '$id'});
      final response = await http.get(uri).timeout(const Duration(seconds: 12));
      return list(decode(response.body), const <String>['players', 'data', 'items', 'members']);
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<List<Map<String, dynamic>>> loadTeamMatches(int teamId) =>
      _getRows('get_team_matches.php', <String, String>{'team_id': '$teamId'}, const <String>['matches', 'data', 'items']);

  Future<List<Map<String, dynamic>>> loadTeamEvents(int teamId) =>
      _getRows('get_team_events.php', <String, String>{'team_id': '$teamId'}, const <String>['events', 'items', 'rows', 'data']);

  Future<List<Map<String, dynamic>>> loadTeamPlans({required int teamId, required int clubId}) =>
      _getRows(
        'get_latest_training_plans.php',
        <String, String>{'team_id': '$teamId', 'club_id': '$clubId', 'limit': '500'},
        const <String>['plans', 'items', 'data', 'result', 'rows'],
      );

  Future<List<Map<String, dynamic>>> loadTeamTesting({required int teamId, required int clubId}) =>
      _getRows(
        'get_testing_sessions.php',
        <String, String>{'team_id': '$teamId', 'club_id': '$clubId', 'category': 'physical'},
        const <String>['sessions', 'items', 'data', 'rows'],
      );

  Future<bool> saveTeamProfile({
    required Map<String, dynamic> team,
    required String name,
    required String category,
  }) async {
    final id = teamId(team);
    if (id <= 0 || name.trim().isEmpty) return false;
    final request = http.MultipartRequest('POST', Uri.parse('$apiBase/update_team_profile.php'));
    request.fields.addAll(<String, String>{
      'team_id': '$id',
      'team_name': name.trim(),
      'name': name.trim(),
      'category': category.trim().isEmpty ? 'Футбол' : category.trim(),
    });
    final streamed = await request.send().timeout(const Duration(seconds: 20));
    final response = await http.Response.fromStream(streamed);
    final data = decode(response.body);
    return data is Map && (data['success'] == true || data['status'] == 'success' || data['status'] == 'ok');
  }

  Future<List<Map<String, dynamic>>> _getRows(
    String endpoint,
    Map<String, String> query, [
    List<String> keys = const <String>[],
  ]) async {
    try {
      final uri = Uri.parse('$apiBase/$endpoint').replace(queryParameters: query);
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      return list(decode(response.body), keys);
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }
}
