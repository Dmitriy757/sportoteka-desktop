import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:sportoteka/core/utils/pref_utils.dart';

class WorkspacePlayerDataBridge {
  WorkspacePlayerDataBridge({
    this.apiBase = 'https://sportotekaapp.ru/api',
  });

  final String apiBase;

  int resolvePlayerId(Map<String, dynamic> player) {
    for (final key in const <String>[
      'player_id',
      'playerId',
      'id',
      'member_id',
      'memberId',
    ]) {
      final parsed = int.tryParse('${player[key] ?? ''}'.trim());
      if (parsed != null && parsed > 0) return parsed;
    }
    return 0;
  }

  int resolveUserId(Map<String, dynamic> player) {
    for (final key in const <String>[
      'user_id',
      'userId',
      'player_user_id',
      'playerUserId',
    ]) {
      final parsed = int.tryParse('${player[key] ?? ''}'.trim());
      if (parsed != null && parsed > 0) return parsed;
    }
    // В части старых API player_id использовался как user_id.
    return resolvePlayerId(player);
  }

  int resolveTeamId(Map<String, dynamic> player, int? fallbackTeamId) {
    for (final value in <dynamic>[
      player['team_id'],
      player['teamId'],
      player['teamID'],
      fallbackTeamId,
    ]) {
      final parsed = int.tryParse('${value ?? ''}'.trim());
      if (parsed != null && parsed > 0) return parsed;
    }
    return 0;
  }

  Future<void> updatePlayerFields({
    required Map<String, dynamic> player,
    required int? teamId,
    required Map<String, String> fields,
  }) async {
    final playerId = resolvePlayerId(player);
    if (playerId <= 0) {
      throw StateError('Не удалось определить player_id');
    }

    final payload = <String, String>{
      'id': '$playerId',
      'player_id': '$playerId',
      if (resolveTeamId(player, teamId) > 0)
        'team_id': '${resolveTeamId(player, teamId)}',
      ...fields,
    };

    final response = await http
        .post(
          Uri.parse('$apiBase/update_player.php'),
          headers: const <String, String>{
            'Content-Type': 'application/x-www-form-urlencoded; charset=utf-8',
          },
          body: payload,
        )
        .timeout(const Duration(seconds: 20));

    final data = _decodeMap(response.body);
    final ok = response.statusCode >= 200 &&
        response.statusCode < 300 &&
        (data.isEmpty ||
            data['success'] == true ||
            data['success'] == 1 ||
            '${data['status'] ?? ''}'.toLowerCase() == 'success');
    if (!ok) {
      throw StateError(
        '${data['message'] ?? data['error'] ?? 'Не удалось сохранить данные игрока'}',
      );
    }
  }

  Future<List<Map<String, dynamic>>> loadMedicalRecords(
    Map<String, dynamic> player,
  ) async {
    final userId = resolveUserId(player);
    final playerId = resolvePlayerId(player);
    if (userId <= 0 && playerId <= 0) return <Map<String, dynamic>>[];

    final query = <String, String>{
      if (playerId > 0) 'player_id': '$playerId',
      if (userId > 0) 'user_id': '$userId',
    };
    final uri = Uri.parse('$apiBase/medical/get_medical_records.php').replace(
      queryParameters: query,
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 20));
    final decoded = _decodeAny(response.body);

    dynamic raw = decoded;
    if (decoded is Map) {
      final map = Map<String, dynamic>.from(decoded);
      final status = '${map['status'] ?? ''}'.toLowerCase();
      final ok = response.statusCode >= 200 &&
          response.statusCode < 300 &&
          (map['success'] == null ||
              map['success'] == true ||
              map['success'] == 1 ||
              status == 'success' ||
              status == 'ok');
      if (!ok) {
        throw StateError(
          '${map['message'] ?? map['error'] ?? 'Не удалось загрузить медкарту'}',
        );
      }
      raw = map['records'] ?? map['items'] ?? map['data'] ?? map['rows'] ?? const [];
    }

    if (raw is! List) return <Map<String, dynamic>>[];
    return raw.whereType<Map>().map((item) {
      final row = Map<String, dynamic>.from(item);
      if (playerId > 0) row['player_id'] ??= playerId;
      if (userId > 0) row['user_id'] ??= userId;
      // Current medical backend uses note/record_date; older UI used
      // value/comment/date/type. Keep aliases so both views show one record.
      row['value'] ??= row['note'];
      row['comment'] ??= row['note'];
      row['date'] ??= row['record_date'];
      if ('${row['type'] ?? ''}'.trim().isEmpty && '${row['file_url'] ?? ''}'.trim().isNotEmpty) {
        row['type'] = 'Документ';
      }
      return row;
    }).toList();
  }

  Future<void> uploadMedicalAttachment({
    required Map<String, dynamic> player,
    required PlatformFile file,
    required String title,
    required String type,
    String value = '',
    String comment = '',
    DateTime? date,
  }) async {
    final userId = resolveUserId(player);
    final playerId = resolvePlayerId(player);
    if (playerId <= 0) {
      throw StateError('Не удалось определить player_id игрока');
    }

    final createdBy = int.tryParse('${player['created_by'] ?? player['actor_user_id'] ?? ''}'.trim()) ?? 0;
    final normalizedTitle = title.trim().isEmpty ? file.name : title.trim();
    final normalizedNote = <String>[value.trim(), comment.trim()]
        .where((e) => e.isNotEmpty)
        .join('\n\n');
    final recordDate = _ymd(date ?? DateTime.now());

    Future<http.Response> sendCurrent() async {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$apiBase/medical/save_medical_record.php'),
      );
      request.fields.addAll(<String, String>{
        'player_id': '$playerId',
        if (userId > 0) 'user_id': '$userId',
        if (createdBy > 0) 'created_by': '$createdBy',
        'title': normalizedTitle,
        'note': normalizedNote,
        'record_date': recordDate,
      });
      await _attachPlatformFile(request, file);
      final streamed = await request.send().timeout(const Duration(seconds: 90));
      return http.Response.fromStream(streamed);
    }

    Future<http.Response> sendLegacy() async {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$apiBase/medical/add_record.php'),
      );
      request.fields.addAll(<String, String>{
        if (userId > 0) 'user_id': '$userId',
        'player_id': '$playerId',
        'type': type.trim().isEmpty ? 'Документ' : type.trim(),
        'title': normalizedTitle,
        'value': value.trim(),
        'date': recordDate,
        'comment': comment.trim(),
      });
      await _attachPlatformFile(request, file);
      final streamed = await request.send().timeout(const Duration(seconds: 90));
      return http.Response.fromStream(streamed);
    }

    final current = await sendCurrent();
    if (_responseOk(current)) return;

    // Compatibility for servers where the new medical endpoint has not yet
    // been deployed. The stored record is still the same real player archive.
    final legacy = await sendLegacy();
    if (_responseOk(legacy)) return;

    final data = _decodeMap(current.body);
    final legacyData = _decodeMap(legacy.body);
    throw StateError(
      '${data['message'] ?? data['error'] ?? legacyData['message'] ?? legacyData['error'] ?? 'Не удалось загрузить файл'}',
    );
  }

  Future<void> updateMedicalRecord({
    required Map<String, dynamic> record,
    Map<String, dynamic>? player,
    required String type,
    required String title,
    required String value,
    required String comment,
    required DateTime date,
  }) async {
    final recordId = int.tryParse('${record['id'] ?? record['record_id'] ?? ''}'.trim()) ?? 0;
    final playerId = int.tryParse('${record['player_id'] ?? record['playerId'] ?? ''}'.trim()) ??
        (player == null ? 0 : resolvePlayerId(player));
    final userId = int.tryParse('${record['user_id'] ?? record['userId'] ?? ''}'.trim()) ??
        (player == null ? 0 : resolveUserId(player));
    if (recordId <= 0) {
      throw StateError('Не удалось определить id медицинской записи');
    }

    Future<http.Response> sendCurrent() async {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$apiBase/medical/save_medical_record.php'),
      );
      request.fields.addAll(<String, String>{
        'record_id': '$recordId',
        'id': '$recordId',
        if (playerId > 0) 'player_id': '$playerId',
        if (userId > 0) 'user_id': '$userId',
        'title': title.trim().isEmpty ? 'Запись' : title.trim(),
        'note': <String>[value.trim(), comment.trim()].where((e) => e.isNotEmpty).join('\n\n'),
        'record_date': _ymd(date),
      });
      final streamed = await request.send().timeout(const Duration(seconds: 30));
      return http.Response.fromStream(streamed);
    }

    Future<http.Response> sendLegacy() async {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$apiBase/medical/update_record.php'),
      );
      request.fields.addAll(<String, String>{
        'id': '$recordId',
        'type': type.trim().isEmpty ? 'Запись' : type.trim(),
        'title': title.trim(),
        'value': value.trim(),
        'date': _ymd(date),
        'comment': comment.trim(),
      });
      final streamed = await request.send().timeout(const Duration(seconds: 30));
      return http.Response.fromStream(streamed);
    }

    final current = await sendCurrent();
    if (_responseOk(current)) return;
    final legacy = await sendLegacy();
    if (_responseOk(legacy)) return;

    final data = _decodeMap(current.body);
    final legacyData = _decodeMap(legacy.body);
    throw StateError(
      '${data['message'] ?? data['error'] ?? legacyData['message'] ?? legacyData['error'] ?? 'Не удалось обновить запись'}',
    );
  }

  Future<void> _attachPlatformFile(
    http.MultipartRequest request,
    PlatformFile file,
  ) async {
    if (file.path != null && file.path!.trim().isNotEmpty && !kIsWeb) {
      request.files.add(
        await http.MultipartFile.fromPath('file', file.path!, filename: file.name),
      );
      return;
    }
    if (file.bytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes('file', file.bytes!, filename: file.name),
      );
      return;
    }
    throw StateError('Не удалось получить содержимое выбранного файла');
  }

  bool _responseOk(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) return false;
    final data = _decodeMap(response.body);
    if (data.isEmpty) return true;
    final status = '${data['status'] ?? ''}'.toLowerCase();
    return data['success'] == true ||
        data['success'] == 1 ||
        status == 'success' ||
        status == 'ok';
  }

  Future<void> updatePlayerMatch({
    required Map<String, dynamic> player,
    required int? teamId,
    required Map<String, dynamic> record,
    required Map<String, String> fields,
  }) async {
    final playerId = resolvePlayerId(player);
    final effectiveTeamId = resolveTeamId(player, teamId);
    final matchId = int.tryParse(
          '${record['match_id'] ?? record['id'] ?? ''}'.trim(),
        ) ??
        0;
    if (playerId <= 0 || effectiveTeamId <= 0 || matchId <= 0) {
      throw StateError('Не удалось определить игрока, команду или матч');
    }

    final response = await http
        .post(
          Uri.parse('$apiBase/update_player_match.php'),
          headers: const <String, String>{
            'Content-Type': 'application/x-www-form-urlencoded; charset=utf-8',
          },
          body: <String, String>{
            'id': '$matchId',
            'match_id': '$matchId',
            'player_id': '$playerId',
            'team_id': '$effectiveTeamId',
            ...fields,
          },
        )
        .timeout(const Duration(seconds: 30));

    final data = _decodeMap(response.body);
    final ok = response.statusCode >= 200 &&
        response.statusCode < 300 &&
        (data.isEmpty ||
            data['success'] == true ||
            data['success'] == 1 ||
            '${data['status'] ?? ''}'.toLowerCase() == 'success');
    if (!ok) {
      throw StateError(
        '${data['message'] ?? data['error'] ?? 'Не удалось обновить матч'}',
      );
    }
  }

  Future<void> savePlayerEventNote({
    required Map<String, dynamic> player,
    required Map<String, dynamic> record,
    required String note,
  }) async {
    final playerId = resolvePlayerId(player);
    final eventId = int.tryParse(
          '${record['event_id'] ?? record['team_event_id'] ?? record['training_id'] ?? ''}'
              .trim(),
        ) ??
        0;
    if (playerId <= 0 || eventId <= 0) {
      throw StateError('У этой записи нет event_id для серверной заметки');
    }

    final response = await http
        .post(
          Uri.parse('$apiBase/save_player_event_note.php'),
          headers: const <String, String>{
            'Content-Type': 'application/x-www-form-urlencoded; charset=utf-8',
          },
          body: <String, String>{
            'event_id': '$eventId',
            'player_id': '$playerId',
            'note': note.trim(),
          },
        )
        .timeout(const Duration(seconds: 20));
    final data = _decodeMap(response.body);
    final ok = response.statusCode >= 200 &&
        response.statusCode < 300 &&
        (data.isEmpty ||
            data['success'] == true ||
            data['success'] == 1 ||
            '${data['status'] ?? ''}'.toLowerCase() == 'success');
    if (!ok) {
      throw StateError(
        '${data['message'] ?? data['error'] ?? 'Не удалось сохранить заметку'}',
      );
    }
  }

  Future<List<Map<String, dynamic>>> loadDiary({
    required Map<String, dynamic> player,
    required int? teamId,
    int? clubId,
  }) async {
    final playerId = resolvePlayerId(player);
    final effectiveTeamId = resolveTeamId(player, teamId);
    if (playerId <= 0 || effectiveTeamId <= 0) {
      return <Map<String, dynamic>>[];
    }

    final merged = <Map<String, dynamic>>[];

    // Canonical legacy diary/self-assessment source used by the classic
    // player profile. Keep it first so existing training ratings stay intact.
    try {
      final uri = Uri.parse('$apiBase/get_player_self_assessments.php').replace(
        queryParameters: <String, String>{
          'team_id': '$effectiveTeamId',
          'player_id': '$playerId',
        },
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 20));
      final data = _decodeMap(response.body);
      final ok = data['success'] == true ||
          data['success'] == 1 ||
          '${data['status'] ?? ''}'.toLowerCase() == 'success';
      if (ok) {
        final raw = data['items'] ?? data['data'] ?? const [];
        if (raw is List) {
          merged.addAll(
            raw.whereType<Map>().map((item) {
              final row = Map<String, dynamic>.from(item);
              row['_workspace_diary_source'] ??= 'self_assessment';
              return row;
            }),
          );
        }
      }
    } catch (_) {
      // The Workspace diary endpoint below is still useful even when an old
      // server does not expose self assessments.
    }

    // On a Phase 25 server the canonical endpoint already projects
    // player_diary_entries into the same read model. Query Workspace directly
    // only as a compatibility fallback for an older canonical endpoint.
    final hasCanonicalDiary = merged.any(
      (row) => '${row['_workspace_diary_source'] ?? ''}' == 'player_diary',
    );
    if (!hasCanonicalDiary) {
      try {
        final effectiveClubId = clubId ??
          int.tryParse('${player['club_id'] ?? player['clubId'] ?? ''}'.trim()) ??
          0;
      final uri = Uri.parse('$apiBase/workspace/player_diary.php').replace(
        queryParameters: <String, String>{
          if (effectiveClubId > 0) 'club_id': '$effectiveClubId',
          'team_id': '$effectiveTeamId',
          'player_id': '$playerId',
          'action': 'list',
        },
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 20));
      final data = _decodeMap(response.body);
      if (_mapOk(data, response.statusCode)) {
        final raw = data['items'] ?? const [];
        if (raw is List) {
          merged.addAll(
            raw.whereType<Map>().map((item) {
              final row = Map<String, dynamic>.from(item);
              row['_workspace_diary_source'] = 'player_diary';
              return row;
            }),
          );
        }
      }
      } catch (_) {
        // Compatibility: Phase 25 server may not be deployed yet.
      }
    }

    final seen = <String>{};
    final out = <Map<String, dynamic>>[];
    for (final row in merged) {
      final source = '${row['_workspace_diary_source'] ?? ''}';
      final rawId = '${row['id'] ?? ''}';
      final diaryId = '${row['diary_entry_id'] ?? ''}'.trim();
      final eventId = '${row['event_id'] ?? ''}';
      final date = '${row['entry_date'] ?? row['start_at'] ?? row['created_at'] ?? ''}';
      final note = '${row['note'] ?? ''}';
      final identity = source == 'player_diary' && diaryId.isNotEmpty ? diaryId : rawId;
      final key = '$source|$identity|$eventId|$date|$note';
      if (seen.add(key)) out.add(row);
    }
    out.sort((a, b) {
      DateTime parse(Map<String, dynamic> row) {
        final raw = '${row['entry_date'] ?? row['start_at'] ?? row['updated_at'] ?? row['created_at'] ?? ''}'
            .trim()
            .replaceAll(' ', 'T');
        return DateTime.tryParse(raw) ?? DateTime.fromMillisecondsSinceEpoch(0);
      }
      return parse(b).compareTo(parse(a));
    });
    return out;
  }

  Future<void> saveDiaryNote({
    required Map<String, dynamic> player,
    required int clubId,
    required int? teamId,
    required String note,
    DateTime? date,
  }) async {
    final playerId = resolvePlayerId(player);
    final effectiveTeamId = resolveTeamId(player, teamId);
    if (playerId <= 0 || effectiveTeamId <= 0) {
      throw StateError('Не удалось определить игрока или команду дневника');
    }
    final actorId = await PrefUtils.getUserId() ?? 0;
    if (actorId <= 0) {
      throw StateError('Не удалось определить пользователя для записи дневника');
    }
    final trimmed = note.trim();
    if (trimmed.isEmpty) {
      throw StateError('Заметка дневника пустая');
    }

    final response = await http
        .post(
          Uri.parse('$apiBase/workspace/player_diary.php'),
          headers: const <String, String>{
            'Content-Type': 'application/x-www-form-urlencoded; charset=utf-8',
          },
          body: <String, String>{
            'action': 'save',
            'club_id': '$clubId',
            'team_id': '$effectiveTeamId',
            'player_id': '$playerId',
            'user_id': '$actorId',
            'author_user_id': '$actorId',
            'author_role': 'coach',
            'entry_type': 'coach_note',
            'entry_date': _ymd(date ?? DateTime.now()),
            'note': trimmed,
          },
        )
        .timeout(const Duration(seconds: 20));
    final data = _decodeMap(response.body);
    if (!_mapOk(data, response.statusCode)) {
      throw StateError(
        '${data['message'] ?? data['error'] ?? 'Не удалось сохранить дневник игрока'}',
      );
    }
  }

  Future<void> updateDiaryEntry({
    required Map<String, dynamic> player,
    required int clubId,
    required int? teamId,
    required int diaryEntryId,
    required String note,
    DateTime? date,
  }) async {
    final playerId = resolvePlayerId(player);
    final effectiveTeamId = resolveTeamId(player, teamId);
    if (playerId <= 0 || effectiveTeamId <= 0 || diaryEntryId <= 0) {
      throw StateError('Не удалось определить запись дневника');
    }
    final actorId = await PrefUtils.getUserId() ?? 0;
    if (actorId <= 0) throw StateError('Не удалось определить пользователя');
    final trimmed = note.trim();
    if (trimmed.isEmpty) throw StateError('Заметка дневника пустая');

    final response = await http.post(
      Uri.parse('$apiBase/workspace/player_diary.php'),
      headers: const <String, String>{
        'Content-Type': 'application/x-www-form-urlencoded; charset=utf-8',
      },
      body: <String, String>{
        'action': 'update',
        'club_id': '$clubId',
        'team_id': '$effectiveTeamId',
        'player_id': '$playerId',
        'user_id': '$actorId',
        'diary_entry_id': '$diaryEntryId',
        'entry_date': _ymd(date ?? DateTime.now()),
        'note': trimmed,
      },
    ).timeout(const Duration(seconds: 20));
    final data = _decodeMap(response.body);
    if (!_mapOk(data, response.statusCode)) {
      throw StateError('${data['message'] ?? data['error'] ?? 'Не удалось обновить дневник игрока'}');
    }
  }

  bool _mapOk(Map<String, dynamic> data, int statusCode) {
    if (statusCode < 200 || statusCode >= 300) return false;
    if (data.isEmpty) return true;
    final status = '${data['status'] ?? ''}'.toLowerCase();
    return data['success'] == true ||
        data['success'] == 1 ||
        data['success'] == '1' ||
        status == 'success' ||
        status == 'ok';
  }

  dynamic _decodeAny(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return null;
    try {
      return jsonDecode(trimmed);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _decodeMap(String body) {
    final decoded = _decodeAny(body);
    return decoded is Map ? Map<String, dynamic>.from(decoded) : <String, dynamic>{};
  }

  String _ymd(DateTime value) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)}';
  }
}

extension WorkspacePlayerDataBrowserBridge on WorkspacePlayerDataBridge {
  Future<List<Map<String, dynamic>>> loadTeamMatches({
    required Map<String, dynamic> player,
    required int? teamId,
  }) async {
    final playerId = resolvePlayerId(player);
    final effectiveTeamId = resolveTeamId(player, teamId);
    if (effectiveTeamId <= 0) return <Map<String, dynamic>>[];

    // Совпадает с актуальной логикой CMR-профиля: сначала персональные
    // endpoints, затем командная история с фильтрацией по составу.
    if (playerId > 0) {
      final params = <String, String>{
        'team_id': '$effectiveTeamId',
        'player_id': '$playerId',
        'user_id': '$playerId',
      };
      for (final endpoint in const <String>[
        'get_player_matches.php',
        'get_player_match_history.php',
        'get_matches_by_player.php',
      ]) {
        try {
          final uri = Uri.parse('$apiBase/$endpoint').replace(queryParameters: params);
          final response = await http.get(uri).timeout(const Duration(seconds: 12));
          final data = _browserDecodeMap(response.body);
          final raw = data['matches'] ?? data['items'] ?? data['rows'] ?? data['data'];
          if (raw is! List) continue;
          final rows = raw
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .where((e) => _browserMatchBelongsToPlayer(e, playerId))
              .toList();
          _sortBrowserRows(rows);
          return rows;
        } catch (_) {
          // Пробуем следующий персональный endpoint.
        }
      }
    }

    final uri = Uri.parse('$apiBase/get_team_matches.php').replace(
      queryParameters: <String, String>{
        'team_id': '$effectiveTeamId',
        if (playerId > 0) 'player_id': '$playerId',
      },
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 20));
    final data = _browserDecodeMap(response.body);
    final raw = data['matches'] ?? data['items'] ?? data['rows'] ?? data['data'] ?? const [];
    if (raw is! List) return <Map<String, dynamic>>[];
    final rows = raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where((e) => _browserMatchBelongsToPlayer(e, playerId))
        .toList();
    _sortBrowserRows(rows);
    return rows;
  }

  Future<List<Map<String, dynamic>>> loadPlayerActivity({
    required Map<String, dynamic> player,
    required int? teamId,
    int days = 365,
  }) async {
    final playerId = resolvePlayerId(player);
    final effectiveTeamId = resolveTeamId(player, teamId);
    if (playerId <= 0 || effectiveTeamId <= 0) return <Map<String, dynamic>>[];
    final now = DateTime.now();
    final from = now.subtract(Duration(days: days));
    final to = now.add(const Duration(days: 1));

    // Основной источник совпадает с актуальным профилем игрока.
    try {
      final historyUri = Uri.parse('$apiBase/get_player_training_history.php').replace(
        queryParameters: <String, String>{
          'team_id': '$effectiveTeamId',
          'player_id': '$playerId',
          'from': _browserYmd(from),
          'to': _browserYmd(to),
        },
      );
      final response = await http.get(historyUri).timeout(const Duration(seconds: 20));
      final data = _browserDecodeMap(response.body);
      final raw = data['items'] ?? data['events'] ?? data['data'] ?? data['rows'] ?? const [];
      if (raw is List) {
        final rows = raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        if (rows.isNotEmpty) {
          _sortBrowserRows(rows);
          return rows;
        }
      }
    } catch (_) {
      // Ниже — резерв через журнал посещаемости/событий игрока.
    }

    final uri = Uri.parse('$apiBase/get_player_attendance_log.php').replace(
      queryParameters: <String, String>{
        'team_id': '$effectiveTeamId',
        'player_id': '$playerId',
        'from': _browserYmd(from),
        'to': _browserYmd(to),
      },
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 20));
    final decoded = _browserDecodeAny(response.body);
    dynamic raw = decoded;
    if (decoded is Map) {
      final map = Map<String, dynamic>.from(decoded);
      raw = map['items'] ?? map['attendance'] ?? map['data'] ?? map['rows'] ?? const [];
    }
    final rows = <Map<String, dynamic>>[];
    if (raw is List) {
      rows.addAll(raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)));
    } else if (raw is Map) {
      for (final entry in raw.entries) {
        final value = entry.value is Map
            ? Map<String, dynamic>.from(entry.value as Map)
            : <String, dynamic>{};
        rows.add(<String, dynamic>{'event_id': value['event_id'] ?? entry.key, ...value});
      }
    }
    _sortBrowserRows(rows);
    return rows;
  }

  Future<List<Map<String, dynamic>>> loadTestingSessions({
    required Map<String, dynamic> player,
    required int clubId,
    required int? teamId,
  }) async {
    final effectiveTeamId = resolveTeamId(player, teamId);
    if (effectiveTeamId <= 0) return <Map<String, dynamic>>[];
    final resolvedClubId = int.tryParse('${player['club_id'] ?? player['clubId'] ?? clubId}') ?? clubId;
    final stage = _browserStage(player);
    final rows = <Map<String, dynamic>>[];
    for (final category in const <String>['physical', 'technical', 'tactical']) {
      final uri = Uri.parse('$apiBase/get_testing_sessions.php').replace(
        queryParameters: <String, String>{
          'club_id': '$resolvedClubId',
          'team_id': '$effectiveTeamId',
          'category': category,
          'stage': stage,
        },
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 20));
      final data = _browserDecodeMap(response.body);
      final raw = data['sessions'] ?? data['items'] ?? data['data'] ?? const [];
      if (raw is List) {
        rows.addAll(raw.whereType<Map>().map((e) => <String, dynamic>{
              ...Map<String, dynamic>.from(e),
              'category': category,
              'stage': stage,
            }));
      }
    }
    _sortBrowserRows(rows);
    return rows;
  }

  Future<Map<String, dynamic>> enrichTestingSessionForPlayer({
    required Map<String, dynamic> player,
    required int clubId,
    required int? teamId,
    required Map<String, dynamic> session,
  }) async {
    final playerId = resolvePlayerId(player);
    final effectiveTeamId = resolveTeamId(player, teamId);
    if (playerId <= 0 || effectiveTeamId <= 0) return Map<String, dynamic>.from(session);

    final resolvedClubId = int.tryParse(
          '${player['club_id'] ?? player['clubId'] ?? clubId}'.trim(),
        ) ??
        clubId;
    final category = '${session['category'] ?? session['category_code'] ?? 'physical'}'.trim();
    final stage = '${session['stage'] ?? session['stage_code'] ?? _browserStage(player)}'.trim();
    final date = '${session['test_date'] ?? session['date'] ?? ''}'.trim();
    final sessionId = int.tryParse('${session['session_id'] ?? session['id'] ?? ''}'.trim()) ?? 0;

    final params = <String, String>{
      'club_id': '$resolvedClubId',
      'team_id': '$effectiveTeamId',
      'category': category.isEmpty ? 'physical' : category,
      'stage': stage.isEmpty ? _browserStage(player) : stage,
      if (date.isNotEmpty) 'test_date': date.length >= 10 ? date.substring(0, 10) : date,
      if (sessionId > 0) 'session_id': '$sessionId',
    };

    try {
      final uri = Uri.parse('$apiBase/get_testing_matrix.php').replace(queryParameters: params);
      final response = await http.get(uri).timeout(const Duration(seconds: 20));
      final data = _browserDecodeMap(response.body);
      final testsRaw = data['tests'];
      final playersRaw = data['players'];
      final tests = testsRaw is List
          ? testsRaw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];
      final players = playersRaw is List
          ? playersRaw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];

      Map<String, dynamic>? playerRow;
      for (final row in players) {
        final pid = int.tryParse(
              '${row['player_id'] ?? row['id'] ?? row['user_id'] ?? ''}'.trim(),
            ) ??
            0;
        if (pid == playerId) {
          playerRow = row;
          break;
        }
      }

      final metrics = <Map<String, dynamic>>[];
      final results = playerRow?['results'];
      if (results is Map) {
        for (final entry in results.entries) {
          final code = '${entry.key}';
          final rawValue = entry.value;
          final test = tests.cast<Map<String, dynamic>>().firstWhere(
                (t) => '${t['code'] ?? ''}' == code,
                orElse: () => <String, dynamic>{},
              );
          dynamic value = rawValue;
          String rating = '';
          String points = '';
          String status = '';
          if (rawValue is Map) {
            value = rawValue['value'] ?? rawValue['result'] ?? rawValue['score'] ?? '';
            rating = '${rawValue['rating'] ?? rawValue['rating_code'] ?? ''}'.trim();
            points = '${rawValue['points'] ?? rawValue['score_points'] ?? ''}'.trim();
            status = '${rawValue['status'] ?? rawValue['grade'] ?? rawValue['level'] ?? ''}'.trim();
          }
          final valueText = '${value ?? ''}'.trim();
          if (valueText.isEmpty || valueText == 'null') continue;
          metrics.add(<String, dynamic>{
            'code': code,
            'title': '${test['title'] ?? test['name'] ?? code}',
            'value': valueText,
            'unit': '${test['unit'] ?? ''}',
            'rating': rating,
            'points': points,
            'status': status,
          });
        }
      }

      return <String, dynamic>{
        ...session,
        'workspace_results': metrics,
        if (playerRow != null) 'workspace_player_row': playerRow,
      };
    } catch (_) {
      return Map<String, dynamic>.from(session);
    }
  }

  bool _browserMatchBelongsToPlayer(Map<String, dynamic> match, int playerId) {
    if (playerId <= 0) return true;

    final directIds = <int>{};
    for (final key in const <String>[
      'player_id', 'footballer_id', 'athlete_id', 'user_id', 'playerId',
    ]) {
      final id = int.tryParse('${match[key] ?? ''}'.trim()) ?? 0;
      if (id > 0) directIds.add(id);
    }
    if (directIds.isNotEmpty) return directIds.contains(playerId);

    var hasExplicitRoster = false;
    for (final raw in <dynamic>[
      match['players'],
      match['participants'],
      match['lineup'],
      match['squad'],
      match['player_ids'],
      match['participant_ids'],
    ]) {
      if (raw is List) {
        hasExplicitRoster = true;
        for (final item in raw) {
          if (item is Map) {
            final id = int.tryParse(
                  '${item['player_id'] ?? item['id'] ?? item['user_id'] ?? item['athlete_id'] ?? ''}'
                      .trim(),
                ) ??
                0;
            if (id == playerId) return true;
          } else if ((int.tryParse('$item') ?? 0) == playerId) {
            return true;
          }
        }
      } else if (raw is String && raw.trim().isNotEmpty) {
        hasExplicitRoster = true;
        final ids = RegExp(r'\d+')
            .allMatches(raw)
            .map((m) => int.tryParse(m.group(0) ?? '') ?? 0);
        if (ids.contains(playerId)) return true;
      }
    }
    return !hasExplicitRoster;
  }

  dynamic _browserDecodeAny(String body) {
    var value = body.trim();
    if (value.isEmpty) return null;
    final firstBrace = value.indexOf('{');
    final firstBracket = value.indexOf('[');
    if (firstBrace > 0 && (firstBracket < 0 || firstBrace < firstBracket)) {
      value = value.substring(firstBrace);
    } else if (firstBracket > 0) {
      value = value.substring(firstBracket);
    }
    try {
      return jsonDecode(value);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _browserDecodeMap(String body) {
    final decoded = _browserDecodeAny(body);
    return decoded is Map ? Map<String, dynamic>.from(decoded) : <String, dynamic>{};
  }

  String _browserYmd(DateTime value) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)}';
  }

  DateTime _browserRowDate(Map<String, dynamic> row) {
    for (final key in const <String>[
      'test_date', 'match_date', 'event_date', 'start_at', 'date',
      'created_at', 'updated_at', 'uploaded_at', 'record_date',
    ]) {
      final raw = '${row[key] ?? ''}'.trim();
      if (raw.isEmpty) continue;
      final parsed = DateTime.tryParse(raw.replaceFirst(' ', 'T'));
      if (parsed != null) return parsed;
    }
    return DateTime(1970);
  }

  void _sortBrowserRows(List<Map<String, dynamic>> rows) {
    rows.sort((a, b) => _browserRowDate(b).compareTo(_browserRowDate(a)));
  }

  String _browserStage(Map<String, dynamic> player) {
    final values = <String>[
      '${player['stage'] ?? ''}',
      '${player['stage_code'] ?? ''}',
      '${player['category_code'] ?? ''}',
      '${player['age_group'] ?? ''}',
      '${player['team_stage'] ?? ''}',
      '${player['team_name'] ?? player['teamName'] ?? ''}',
    ];
    for (final value in values) {
      final match = RegExp(r'U\d{1,2}', caseSensitive: false).firstMatch(value.toUpperCase());
      if (match != null) return match.group(0)!;
    }
    return 'U13';
  }
}
