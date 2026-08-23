import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import '../models/player_profile_models.dart';

class PlayerProfileRepository {
  static const String schoolProfileRecordTitle =
      '__SPORTOTEKA_SCHOOL_PROFILE__';
  static const String _schoolProfilePayloadPrefix =
      '__SPORTOTEKA_SCHOOL_PROFILE_JSON__';
  static const String _documentTitlePrefix = '[Документ] ';
  static const String _documentPayloadPrefix =
      '__SPORTOTEKA_DOCUMENT_JSON__';

  final String apiBase;
  final http.Client _client;
  PlayerProfileRepository({this.apiBase = 'https://sportotekaapp.ru/api', http.Client? client}) : _client = client ?? http.Client();

  int _i(dynamic v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;
  double _d(dynamic v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}'.replaceAll(',', '.')) ?? 0;
  String _s(dynamic v) => '${v ?? ''}'.trim();
  DateTime? _date(dynamic v) => DateTime.tryParse(_s(v).replaceAll(' ', 'T'));

  Future<Map<String, dynamic>> _get(String endpoint, Map<String, String> qp) async {
    final response = await _client.get(Uri.parse('$apiBase/$endpoint').replace(queryParameters: qp)).timeout(const Duration(seconds: 18));
    final body = response.body.trim();
    if (body.isEmpty || body.startsWith('<')) return {};
    final decoded = jsonDecode(body);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return {};
  }

  List<Map<String, dynamic>> _list(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is List) return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      if (value is Map) {
        for (final nested in ['items', 'rows', 'data']) {
          final v = value[nested];
          if (v is List) return v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        }
      }
    }
    return [];
  }


  Future<Map<String, dynamic>> _post(String endpoint, Map<String, dynamic> body) async {
    final response = await _client.post(
      Uri.parse('$apiBase/$endpoint'),
      headers: const {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 18));
    final raw = response.body.trim();
    if (raw.isEmpty || raw.startsWith('<')) throw Exception('Некорректный ответ сервера');
    final decoded = jsonDecode(raw);
    if (decoded is! Map) throw Exception('Некорректный ответ сервера');
    final data = Map<String, dynamic>.from(decoded);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        data['success'] == false ||
        data['status'] == 'error') {
      throw Exception('${data['message'] ?? 'Операция не выполнена'}');
    }
    return data;
  }

  Future<Map<String, dynamic>> _postForm(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final fields = <String, String>{};
    body.forEach((key, value) => fields[key] = _s(value));
    final response = await _client
        .post(Uri.parse('$apiBase/$endpoint'), body: fields)
        .timeout(const Duration(seconds: 18));
    final raw = response.body.trim();
    if (raw.isEmpty || raw.startsWith('<')) {
      throw Exception('Некорректный ответ сервера');
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map) throw Exception('Некорректный ответ сервера');
    final data = Map<String, dynamic>.from(decoded);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        data['success'] == false ||
        data['status'] == 'error') {
      throw Exception('${data['message'] ?? 'Операция не выполнена'}');
    }
    return data;
  }

  Future<Map<String, dynamic>> savePlayerMetrics({
    required int playerId,
    required int userId,
    int clubId = 0,
    int teamId = 0,
    required Map<String, dynamic> values,
  }) async {
    final height = _d(values['height'] ?? values['height_cm']);
    final weight = _d(values['weight'] ?? values['weight_kg']);
    final normalized = <String, dynamic>{
      ...values,
      'height': height > 0 ? height : '',
      'height_cm': height > 0 ? height : '',
      'weight': weight > 0 ? weight : '',
      'weight_kg': weight > 0 ? weight : '',
    };

    final payload = <String, dynamic>{
      'player_id': playerId,
      'user_id': userId,
      if (clubId > 0) 'club_id': clubId,
      if (teamId > 0) 'team_id': teamId,
      ...normalized,
    };
    Map<String, dynamic> response;
    try {
      response = await _post('medical/save_player_metrics.php', payload);
      final confirmed = response['success'] == true ||
          response['status'] == 'success' ||
          response['metrics'] is Map ||
          response['player'] is Map;
      if (!confirmed) {
        throw Exception('Сервер не подтвердил сохранение метрик');
      }
    } catch (_) {
      response = await _postForm('medical/save_player_metrics.php', payload);
    }

    final returned = response['metrics'] is Map
        ? Map<String, dynamic>.from(response['metrics'] as Map)
        : response['player'] is Map
            ? Map<String, dynamic>.from(response['player'] as Map)
            : <String, dynamic>{};
    return <String, dynamic>{...normalized, ...returned};
  }

  Future<void> saveSchoolProfile({
    required int playerId,
    required int userId,
    required Map<String, dynamic> values,
    Map<String, dynamic>? existingRecord,
  }) async {
    final clean = <String, dynamic>{};
    values.forEach((key, value) {
      final text = _s(value);
      if (text.isNotEmpty && text != 'null') clean[key] = value;
    });
    await saveMedicalRecord(
      playerId: playerId,
      userId: userId,
      record: <String, dynamic>{
        ...?existingRecord,
        'title': schoolProfileRecordTitle,
        'note': '$_schoolProfilePayloadPrefix${jsonEncode(clean)}',
        'record_date': DateTime.now().toIso8601String().substring(0, 10),
      },
    );
  }

  Future<void> savePlayerDocument({
    required int playerId,
    required int userId,
    required Map<String, dynamic> document,
    PlatformFile? attachment,
  }) async {
    final name = _s(document['document_title'] ?? document['title']);
    if (name.isEmpty) throw Exception('Укажите наименование документа');
    final metadata = <String, dynamic>{
      'name': name,
      'category': _s(document['document_category']),
      'number': _s(document['document_number']),
      'issuer': _s(document['document_issuer']),
      'issue_date': _s(document['issue_date']),
      'expiry_date': _s(document['expiry_date']),
      'description': _s(document['description'] ?? document['note']),
    };
    await saveMedicalRecord(
      playerId: playerId,
      userId: userId,
      record: <String, dynamic>{
        ...document,
        'title': '$_documentTitlePrefix$name',
        'note': '$_documentPayloadPrefix${jsonEncode(metadata)}',
        'record_date': _s(document['issue_date']).isNotEmpty
            ? _s(document['issue_date'])
            : DateTime.now().toIso8601String().substring(0, 10),
      },
      attachment: attachment,
    );
  }

  Future<void> deletePlayerDocument({
    required int playerId,
    required int userId,
    required Map<String, dynamic> document,
  }) => deleteMedicalRecord(
        playerId: playerId,
        userId: userId,
        record: document,
      );

  Future<void> saveMedicalRecord({
    required int playerId,
    required int userId,
    required Map<String, dynamic> record,
    PlatformFile? attachment,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$apiBase/medical/save_medical_record.php'),
    );
    request.fields.addAll({
      'player_id': '$playerId',
      'user_id': '$userId',
      'created_by': '$userId',
      'record_id': '${_i(record['id'] ?? record['record_id'])}',
      'title': _s(record['title']),
      'note': _s(record['note'] ?? record['comment'] ?? record['description']),
      'record_date': _s(record['record_date'] ?? record['date']),
      'remove_file': record['remove_file'] == true ? '1' : '0',
    });

    if (attachment != null) {
      if (attachment.bytes != null) {
        request.files.add(http.MultipartFile.fromBytes(
          'file',
          attachment.bytes!,
          filename: attachment.name,
        ));
      } else if ((attachment.path ?? '').isNotEmpty) {
        request.files.add(await http.MultipartFile.fromPath(
          'file',
          attachment.path!,
          filename: attachment.name,
        ));
      }
    }

    final streamed = await request.send().timeout(const Duration(seconds: 45));
    final response = await http.Response.fromStream(streamed);
    final raw = response.body.trim();
    if (raw.isEmpty || raw.startsWith('<')) {
      throw Exception('Некорректный ответ сервера');
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map) throw Exception('Некорректный ответ сервера');
    final data = Map<String, dynamic>.from(decoded);
    if (response.statusCode < 200 || response.statusCode >= 300 || data['success'] != true) {
      throw Exception('${data['message'] ?? data['error'] ?? 'Не удалось сохранить медицинскую запись'}');
    }
  }

  Future<void> deleteMedicalRecord({required int playerId, required int userId, required Map<String, dynamic> record}) async {
    await _post('medical/delete_medical_record.php', {
      'player_id': playerId,
      'user_id': userId,
      'record_id': _i(record['id'] ?? record['record_id']),
    });
  }

  bool _isSchoolProfileRecord(Map<String, dynamic> record) =>
      _s(record['title']) == schoolProfileRecordTitle;

  bool _isPlayerDocument(Map<String, dynamic> record) =>
      _s(record['title']).startsWith(_documentTitlePrefix) ||
      _s(record['note']).startsWith(_documentPayloadPrefix);

  Map<String, dynamic> _decodePrefixedJson(dynamic raw, String prefix) {
    final text = _s(raw);
    if (!text.startsWith(prefix)) return <String, dynamic>{};
    try {
      final decoded = jsonDecode(text.substring(prefix.length));
      return decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Map<String, dynamic> _decodeSchoolProfile(
    Map<String, dynamic>? record,
  ) {
    if (record == null) return <String, dynamic>{};
    return _decodePrefixedJson(
      record['note'] ?? record['description'] ?? record['comment'],
      _schoolProfilePayloadPrefix,
    );
  }

  Map<String, dynamic> _normalizePlayerDocument(
    Map<String, dynamic> record,
  ) {
    final rawTitle = _s(record['title']);
    final metadata = _decodePrefixedJson(
      record['note'] ?? record['description'] ?? record['comment'],
      _documentPayloadPrefix,
    );
    final fallbackTitle = rawTitle.startsWith(_documentTitlePrefix)
        ? rawTitle.substring(_documentTitlePrefix.length).trim()
        : rawTitle;
    return <String, dynamic>{
      ...record,
      'document_title': _s(metadata['name']).isNotEmpty
          ? _s(metadata['name'])
          : fallbackTitle,
      'document_category': _s(metadata['category']).isNotEmpty
          ? _s(metadata['category'])
          : 'other',
      'document_number': _s(metadata['number']),
      'document_issuer': _s(metadata['issuer']),
      'issue_date': _s(metadata['issue_date']).isNotEmpty
          ? _s(metadata['issue_date'])
          : _s(record['record_date'] ?? record['date']),
      'expiry_date': _s(metadata['expiry_date']),
      'description': _s(metadata['description']),
      'note': _s(metadata['description']),
      'document_kind': 'school_document',
    };
  }



  Future<void> saveWeekGoal({
    required int clubId,
    required int teamId,
    required int playerId,
    required int authorUserId,
    required String authorRole,
    int goalId = 0,
    required DateTime weekStart,
    String goalText = '',
    int progress = 0,
    bool isDone = false,
  }) async {
    String two(int value) => value.toString().padLeft(2, '0');
    final weekIso =
        '${weekStart.year}-${two(weekStart.month)}-${two(weekStart.day)}';

    await _post('save_player_week_goal.php', {
      'club_id': clubId,
      'team_id': teamId,
      'player_id': playerId,
      'author_user_id': authorUserId,
      'author_role': authorRole,
      'goal_id': goalId,
      'week_start': weekIso,
      'goal_text': goalText.trim(),
      'progress': progress.clamp(0, 100),
      'is_done': isDone ? 1 : 0,
    });
  }

  Future<void> saveDiaryEntry({
    required int clubId,
    required int teamId,
    required int playerId,
    required int authorUserId,
    required String authorRole,
    required DateTime entryDate,
    int eventId = 0,
    int rating = 0,
    int mood = 0,
    int fatigue = 0,
    int sleepQuality = 0,
    int pain = 0,
    int rpe = 0,
    String note = '',
  }) async {
    String two(int v) => v.toString().padLeft(2, '0');
    final dateIso = '${entryDate.year}-${two(entryDate.month)}-${two(entryDate.day)}';
    await _post('save_player_diary_daily.php', {
      'club_id': clubId,
      'team_id': teamId,
      'player_id': playerId,
      'event_id': eventId,
      'entry_date': dateIso,
      'author_user_id': authorUserId,
      'author_role': authorRole,
      'rating': rating,
      'mood': mood,
      'fatigue': fatigue,
      'sleep_quality': sleepQuality,
      'pain': pain,
      'rpe': rpe,
      'note': note.trim(),
    });
  }

  String _stageForPlayer(Map<String, dynamic> player) {
    final direct = _s(player['stage'] ?? player['age_stage']).toUpperCase();
    final directMatch = RegExp(r'U-?(\d{1,2})').firstMatch(direct);
    if (directMatch != null) return 'U${directMatch.group(1)}';

    final team = _s(player['team_name'] ?? player['teamName']).toUpperCase();
    final teamMatch = RegExp(r'U-?(\d{1,2})').firstMatch(team);
    if (teamMatch != null) return 'U${teamMatch.group(1)}';

    final birth = _date(player['birth_date'] ?? player['birthday'] ?? player['date_of_birth']);
    if (birth != null) {
      final now = DateTime.now();
      var age = now.year - birth.year;
      if (now.month < birth.month || (now.month == birth.month && now.day < birth.day)) age--;
      if (age >= 6 && age <= 17) return 'U$age';
    }
    return 'U13';
  }

  String _categoryTitle(String code) {
    switch (code) {
      case 'physical': return 'Физическая подготовка';
      case 'technical': return 'Техническая подготовка';
      case 'tactical': return 'Тактическая подготовка';
      case 'psychological': return 'Психологическая подготовка';
      case 'theory': return 'Теория';
      case 'functional': return 'Функциональное состояние';
      default: return code;
    }
  }

  Future<List<Map<String, dynamic>>> _loadTestingHistory(Map<String, dynamic> player) async {
    final clubId = _i(player['club_id'] ?? player['clubId']);
    final teamId = _i(player['team_id'] ?? player['teamId']);
    final playerId = _i(player['player_id'] ?? player['id'] ?? player['user_id']);
    if (clubId <= 0 || teamId <= 0 || playerId <= 0) return [];

    final stage = _stageForPlayer(player);
    const categories = ['physical', 'technical', 'tactical', 'psychological', 'theory', 'functional'];
    final sessionResponses = await Future.wait(categories.map((category) async {
      final data = await _get('get_testing_sessions.php', {
        'club_id': '$clubId',
        'team_id': '$teamId',
        'category': category,
        'stage': stage,
      }).catchError((_) => <String, dynamic>{});
      return _list(data, ['sessions', 'items', 'rows', 'data']).map((row) => {
        ...row,
        '_category': category,
      }).toList();
    }));

    final sessions = sessionResponses.expand((e) => e).toList();
    sessions.sort((a, b) => (_date(b['test_date'] ?? b['date']) ?? DateTime(1970)).compareTo(_date(a['test_date'] ?? a['date']) ?? DateTime(1970)));
    final selected = sessions.take(30).toList();

    final histories = await Future.wait(selected.map((session) async {
      final category = _s(session['_category']);
      final sessionId = _i(session['id'] ?? session['session_id']);
      final testDate = _s(session['test_date'] ?? session['date']);
      if (sessionId <= 0) return <Map<String, dynamic>>[];

      final matrix = await _get('get_testing_matrix.php', {
        'club_id': '$clubId',
        'team_id': '$teamId',
        'category': category,
        'stage': stage,
        'session_id': '$sessionId',
        if (testDate.isNotEmpty) 'test_date': testDate.substring(0, testDate.length >= 10 ? 10 : testDate.length),
      }).catchError((_) => <String, dynamic>{});

      final tests = _list(matrix, ['tests']);
      final players = _list(matrix, ['players']);
      Map<String, dynamic>? current;
      for (final row in players) {
        if (_i(row['id'] ?? row['player_id'] ?? row['user_id']) == playerId) {
          current = row;
          break;
        }
      }
      if (current == null) return <Map<String, dynamic>>[];
      final rawResults = current['results'];
      if (rawResults is! Map) return <Map<String, dynamic>>[];
      final results = Map<String, dynamic>.from(rawResults);

      final rows = <Map<String, dynamic>>[];
      for (final test in tests) {
        final code = _s(test['code']);
        final raw = results[code];
        if (raw == null) continue;
        final result = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{'value': raw};
        final value = _s(result['value'] ?? result['result']);
        if (value.isEmpty || value == 'null') continue;
        rows.add({
          'session_id': sessionId,
          'date': testDate,
          'test_date': testDate,
          'category': category,
          'category_title': _categoryTitle(category),
          'stage': stage,
          'test_code': code,
          'test_name': _s(test['short_title']).isEmpty ? _s(test['title']) : _s(test['short_title']),
          'unit': code == 'long_jump' ? 'см' : _s(test['unit']),
          'value': value,
          'result': value,
          'rating': _s(result['rating'] ?? result['rating_code']),
          'rating_label': _s(result['label'] ?? result['rating_label'] ?? result['grade']),
          'points': _i(result['points']),
        });
      }
      return rows;
    }));

    final out = histories.expand((e) => e).toList();
    out.sort((a, b) => (_date(b['test_date']) ?? DateTime(1970)).compareTo(_date(a['test_date']) ?? DateTime(1970)));
    return out;
  }

  Future<List<Map<String, dynamic>>> _loadCoachRatings({
    required List<Map<String, dynamic>> trainings,
    required int playerId,
  }) async {
    if (playerId <= 0 || trainings.isEmpty) return [];
    final selected = trainings
        .where((e) => _i(e['id'] ?? e['event_id']) > 0)
        .toList()
      ..sort((a, b) =>
          (_date(b['start_at'] ?? b['date']) ?? DateTime(1970)).compareTo(
            _date(a['start_at'] ?? a['date']) ?? DateTime(1970),
          ));
    if (selected.length > 24) {
      selected.removeRange(24, selected.length);
    }
    final rows = await Future.wait(selected.map((event) async {
      final eventId = _i(event['id'] ?? event['event_id']);
      final data = await _get('get_training_ratings.php', {'event_id': '$eventId'})
          .catchError((_) => <String, dynamic>{});
      final ratings = _list(data, ['ratings', 'items', 'rows', 'data']);
      for (final rating in ratings) {
        if (_i(rating['player_id'] ?? rating['playerId']) != playerId) continue;
        return <String, dynamic>{
          ...rating,
          'event_id': eventId,
          'event_title': _s(event['title']).isEmpty ? 'Тренировка' : _s(event['title']),
          'event_date': _s(event['start_at'] ?? event['date']),
          'event_location': _s(event['location']),
        };
      }
      return <String, dynamic>{};
    }));
    final out = rows.where((e) => e.isNotEmpty && _d(e['rating']) > 0).toList();
    out.sort((a, b) => (_date(b['event_date']) ?? DateTime(1970)).compareTo(_date(a['event_date']) ?? DateTime(1970)));
    return out;
  }

  Future<List<Map<String, dynamic>>> _loadPlayerMediaFeed({
    required Map<String, dynamic> player,
    required int playerId,
    required int userId,
    required int teamId,
  }) async {
    try {
      final uri = Uri.parse('$apiBase/get_posts.php').replace(
        queryParameters: <String, String>{
          if (userId > 0) 'user_id': '$userId',
          if (playerId > 0) 'player_id': '$playerId',
          if (teamId > 0) 'team_id': '$teamId',
        },
      );
      final response = await _client.get(uri).timeout(const Duration(seconds: 18));
      final raw = response.body.trim();
      if (raw.isEmpty || raw.startsWith('<')) return <Map<String, dynamic>>[];
      final decoded = jsonDecode(raw);

      List<Map<String, dynamic>> posts = <Map<String, dynamic>>[];
      if (decoded is List) {
        posts = decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      } else if (decoded is Map) {
        posts = _list(
          Map<String, dynamic>.from(decoded),
          const ['posts', 'items', 'rows', 'data'],
        );
      }
      if (posts.isEmpty) return <Map<String, dynamic>>[];

      String normalizedName(dynamic value) => _s(value)
          .toLowerCase()
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      final first = _s(player['first_name'] ?? player['firstname']);
      final last = _s(player['last_name'] ?? player['lastname']);
      final names = <String>{
        normalizedName(player['full_name']),
        normalizedName(player['fullName']),
        normalizedName(player['name']),
        normalizedName('$first $last'),
        normalizedName('$last $first'),
      }..removeWhere((value) => value.isEmpty || value == 'null');

      bool ownsPost(Map<String, dynamic> post) {
        const idKeys = <String>[
          'user_id', 'userId', 'author_id', 'authorId', 'player_id',
          'playerId', 'owner_id', 'ownerId', 'created_by', 'createdBy',
          'profile_user_id', 'profileUserId',
        ];
        var hasAnyIdentityField = false;
        for (final key in idKeys) {
          if (!post.containsKey(key)) continue;
          final id = _i(post[key]);
          if (id <= 0) continue;
          hasAnyIdentityField = true;
          if ((userId > 0 && id == userId) || (playerId > 0 && id == playerId)) {
            return true;
          }
        }
        if (hasAnyIdentityField) return false;

        final author = normalizedName(
          post['author'] ?? post['author_name'] ?? post['user_name'] ??
              post['player_name'] ?? post['full_name'],
        );
        return author.isNotEmpty && names.contains(author);
      }

      bool isProfilePost(Map<String, dynamic> post) {
        final link = _s(post['link']);
        final source = _s(post['source'] ?? post['post_source']).toLowerCase();
        final parsed = _i(post['is_parsed'] ?? post['parsed']) > 0 ||
            source == 'parsed' || source == 'news';
        // Existing community screen treats records with a link as parsed/news.
        // Keep explicit player-owned records even if a future post type has a link.
        return !parsed && (link.isEmpty || ownsPost(post));
      }

      final out = posts.where((post) => ownsPost(post) && isProfilePost(post)).toList();
      out.sort((a, b) {
        final ad = _date(a['created_at'] ?? a['date'] ?? a['published_at']) ?? DateTime(1970);
        final bd = _date(b['created_at'] ?? b['date'] ?? b['published_at']) ?? DateTime(1970);
        final cmp = bd.compareTo(ad);
        if (cmp != 0) return cmp;
        return _i(b['id']).compareTo(_i(a['id']));
      });
      return out;
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<PlayerProfileSnapshot> loadSnapshot(Map<String, dynamic> player) async {
    final teamId = _i(player['team_id'] ?? player['teamId']);
    final clubId = _i(player['club_id'] ?? player['clubId']);
    final playerId = _i(player['player_id'] ?? player['id'] ?? player['user_id']);
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    final referenceDate = '${now.year}-${two(now.month)}-${two(now.day)}';
    final results = await Future.wait([
      _get('get_team_events.php', {'team_id': '$teamId', 'club_id': '$clubId'}).catchError((_) => <String,dynamic>{}),
      _get('get_player_attendance_log.php', {'team_id': '$teamId', 'player_id': '$playerId'}).catchError((_) => <String,dynamic>{}),
      _get('get_player_matches.php', {'user_id': '${_i(player['user_id'] ?? playerId)}', 'limit': '200'}).catchError((_) => <String,dynamic>{}),
      _loadTestingHistory(player).catchError((_) => <Map<String, dynamic>>[]),
      _get('medical/get_medical_records.php', {
        'player_id': '$playerId',
        'user_id': '${_i(player['user_id'] ?? playerId)}',
      }).catchError((_) => <String,dynamic>{}),
      _get('tracker/get_tracker_sessions.php', {'team_id': '$teamId', 'player_id': '$playerId', 'include_personal': '1', 'limit': '300'}).catchError((_) => <String,dynamic>{}),
      _get('get_my_self_assessments.php', {
        'team_id': '$teamId',
        'player_id': '$playerId',
        'user_id': '${_i(player['user_id'] ?? playerId)}',
      }).catchError((_) => <String,dynamic>{}),
      _get('get_player_diary_daily.php', {
        'team_id': '$teamId',
        'player_id': '$playerId',
        'user_id': '${_i(player['user_id'] ?? playerId)}',
      }).catchError((_) => <String,dynamic>{}),
      _get('get_player_week_goals.php', {'team_id': '$teamId', 'player_id': '$playerId'}).catchError((_) => <String,dynamic>{}),
      _get('tracker/get_tracker_readiness.php', {
        'club_id': '$clubId',
        'team_id': '$teamId',
        'player_id': '$playerId',
        'reference_date': referenceDate,
      }).catchError((_) => <String,dynamic>{}),
      _get('medical/get_player_metrics.php', {
        'player_id': '$playerId',
        'user_id': '${_i(player['user_id'] ?? playerId)}',
      }).catchError((_) => <String,dynamic>{}),
      _loadPlayerMediaFeed(
        player: player,
        playerId: playerId,
        userId: _i(player['user_id'] ?? playerId),
        teamId: teamId,
      ).catchError((_) => <Map<String, dynamic>>[]),
    ]);
    Map<String, dynamic> mapResultAt(int index) {
      final value = results[index];
      if (value is Map<String, dynamic>) return value;
      if (value is Map) return Map<String, dynamic>.from(value);
      return <String, dynamic>{};
    }

    final trainings = _list(mapResultAt(0), ['events','items','rows','data']);
    final attendance = _list(mapResultAt(1), ['items','attendance','rows','data']);
    var matches = _list(mapResultAt(2), ['matches','items','rows','data']);
    if (matches.isEmpty && teamId > 0) {
      final fallbackMatches = await _get('get_team_matches.php', {'team_id': '$teamId'}).catchError((_) => <String, dynamic>{});
      matches = _list(fallbackMatches, ['matches', 'items', 'rows', 'data']);
    }
    final tests = results[3] is List
        ? (results[3] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : <Map<String, dynamic>>[];
    final rawMedical = _list(mapResultAt(4), ['records','items','rows','data']);
    Map<String, dynamic>? schoolProfileRecord;
    for (final record in rawMedical) {
      if (_isSchoolProfileRecord(record)) {
        schoolProfileRecord = record;
        break;
      }
    }
    final schoolProfile = _decodeSchoolProfile(schoolProfileRecord);
    final documents = rawMedical
        .where(_isPlayerDocument)
        .map(_normalizePlayerDocument)
        .toList(growable: false);
    final medical = rawMedical
        .where((record) =>
            !_isSchoolProfileRecord(record) && !_isPlayerDocument(record))
        .toList(growable: false);

    final metricsResponse = mapResultAt(10);
    final metricsSource = metricsResponse['metrics'] is Map
        ? Map<String, dynamic>.from(metricsResponse['metrics'] as Map)
        : metricsResponse['player'] is Map
            ? Map<String, dynamic>.from(metricsResponse['player'] as Map)
            : metricsResponse;
    final serverHeight =
        metricsSource['height'] ?? metricsSource['height_cm'];
    final serverWeight =
        metricsSource['weight'] ?? metricsSource['weight_kg'];
    final mergedPlayer = <String, dynamic>{
      ...player,
      ...schoolProfile,
      if (_d(serverHeight) > 0) 'height': _d(serverHeight),
      if (_d(serverHeight) > 0) 'height_cm': _d(serverHeight),
      if (_d(serverWeight) > 0) 'weight': _d(serverWeight),
      if (_d(serverWeight) > 0) 'weight_kg': _d(serverWeight),
    };
    final sessionsRaw = _list(mapResultAt(5), ['sessions','items','rows','data']);
    final selfAssessments = _list(mapResultAt(6), ['items', 'assessments', 'rows', 'data']);
    final diaryEntries = _list(mapResultAt(7), ['items', 'entries', 'rows', 'data']);
    final weeklyGoals = _list(mapResultAt(8), ['items', 'goals', 'rows', 'data']);
    final mediaFeed = results.length > 11 && results[11] is List
        ? (results[11] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : <Map<String, dynamic>>[];
    final coachRatings = await _loadCoachRatings(trainings: trainings, playerId: playerId);
    final sessions = sessionsRaw.map((e) => PlayerProfileSession(
      id: _i(e['session_id'] ?? e['id']), date: _date(e['started_at'] ?? e['date'] ?? e['created_at']),
      title: _s(e['title']).isEmpty ? 'Сессия трекера' : _s(e['title']), distanceM: _d(e['total_distance_m'] ?? e['distance_m']),
      maxSpeedKmh: _d(e['max_speed_kmh'] ?? e['max_speed']), avgSpeedKmh: _d(e['avg_speed_kmh'] ?? e['avg_speed']),
      durationSec: _i(e['duration_sec'] ?? e['duration_seconds']), sprintCount: _i(e['sprint_count'] ?? e['sprints']),
      hsrDistanceM: _d(e['hsr_distance_m'] ?? e['high_speed_distance_m'] ?? e['hir_distance_m'] ?? e['vhir_distance_m']),
      sprintDistanceM: _d(e['sprint_distance_m']),
      accelCount: _i(e['accel_count'] ?? e['acceleration_count'] ?? e['accelerations']),
      decelCount: _i(e['decel_count'] ?? e['deceleration_count'] ?? e['decelerations']),
      loadScore: _d(e['load_score'] ?? e['tracker_load'] ?? e['hr_load']),
      avgHr: _d(e['heart_rate_avg_bpm'] ?? e['avg_heart_rate_bpm'] ?? e['avg_hr']), maxHr: _d(e['heart_rate_max_bpm'] ?? e['max_heart_rate_bpm'] ?? e['max_hr']),
      minHr: _d(e['heart_rate_min_bpm'] ?? e['min_heart_rate_bpm'] ?? e['min_hr']),
    )).where((e) => e.id > 0).toList()..sort((a,b)=>(b.date ?? DateTime(1970)).compareTo(a.date ?? DateTime(1970)));
    final readiness = _buildReadiness(
      sessions,
      mapResultAt(9),
      DateTime(now.year, now.month, now.day),
      referenceDate,
    );
    final snapshot = PlayerProfileSnapshot(
      player: mergedPlayer,
      trainings: trainings,
      attendance: attendance,
      matches: matches,
      tests: tests,
      coachRatings: coachRatings,
      selfAssessments: selfAssessments,
      diaryEntries: diaryEntries,
      weeklyGoals: weeklyGoals,
      mediaFeed: mediaFeed,
      medical: medical,
      documents: documents,
      schoolProfile: schoolProfile,
      schoolProfileRecord: schoolProfileRecord,
      sessions: sessions,
      readiness: readiness,
    );
    return snapshot.copyWith(timeline: buildTimeline(snapshot));
  }

  double _sessionLoad(PlayerProfileSession session) {
    if (session.loadScore.isFinite && session.loadScore > 0) {
      return session.loadScore;
    }
    return (session.distanceM * .018 +
            session.hsrDistanceM * .10 +
            session.sprintDistanceM * .22 +
            session.accelCount * 3.0 +
            session.decelCount * 2.4 +
            session.maxSpeedKmh * .65)
        .clamp(0.0, 999.0)
        .toDouble();
  }

  PlayerReadinessSummary _buildReadiness(
    List<PlayerProfileSession> sessions,
    Map<String, dynamic> readinessResponse,
    DateTime referenceDay,
    String referenceDate,
  ) {
    final daily = <DateTime, double>{};
    var sessions7 = 0;
    var sessions28 = 0;
    for (final session in sessions) {
      final date = session.date;
      if (date == null) continue;
      final day = DateTime(date.year, date.month, date.day);
      final diff = referenceDay.difference(day).inDays;
      if (diff < 0 || diff > 27) continue;
      final load = _sessionLoad(session);
      if (load <= 0) continue;
      daily[day] = (daily[day] ?? 0.0) + load;
      sessions28++;
      if (diff <= 6) sessions7++;
    }

    double rangeSum(int from, int to) {
      var total = 0.0;
      for (var diff = from; diff <= to; diff++) {
        final date = referenceDay.subtract(Duration(days: diff));
        total += daily[DateTime(date.year, date.month, date.day)] ?? 0.0;
      }
      return total;
    }

    final acute7 = rangeSum(0, 6);
    final previous7 = rangeSum(7, 13);
    final chronicWeek = rangeSum(0, 27) / 4;
    final ratio = chronicWeek <= 0 ? null : acute7 / chronicWeek;
    final daily7 = List<double>.generate(7, (index) {
      final date = referenceDay.subtract(Duration(days: 6 - index));
      return daily[DateTime(date.year, date.month, date.day)] ?? 0.0;
    });
    final mean = daily7.reduce((a, b) => a + b) / 7;
    final variance = daily7.fold<double>(
          0,
          (sum, value) => sum + math.pow(value - mean, 2).toDouble(),
        ) /
        7;
    final deviation = math.sqrt(variance);
    final monotony = acute7 <= 0
        ? 0.0
        : (mean / math.max(1.0, deviation)).clamp(0.0, 5.0).toDouble();

    var objective = sessions28 < 2 ? 68.0 : 92.0;
    if (ratio != null) {
      if (ratio > 1.5) {
        objective -= 35;
      } else if (ratio > 1.3) {
        objective -= 20;
      } else if (ratio < .65) {
        objective -= 8;
      }
    }
    final weekChange = previous7 <= 0 ? null : (acute7 - previous7) / previous7 * 100;
    if (weekChange != null && weekChange > 60) {
      objective -= 18;
    } else if (weekChange != null && weekChange > 35) {
      objective -= 10;
    }
    if (monotony > 2.2) objective -= 10;
    objective = objective.clamp(0.0, 100.0).toDouble();

    final rawCheckin = readinessResponse['checkin'];
    final checkin = rawCheckin is Map
        ? Map<String, dynamic>.from(rawCheckin)
        : <String, dynamic>{};
    final hasCheckin = checkin.isNotEmpty &&
        (checkin['id'] != null || checkin['checkin_date'] != null);
    final sleepHours = _d(checkin['sleep_hours']).clamp(0.0, 16.0).toDouble();
    final effectiveSleep = hasCheckin && sleepHours > 0 ? sleepHours : 8.0;
    final sleepQuality = _i(checkin['sleep_quality']);
    final fatigue = _i(checkin['fatigue']);
    final soreness = _i(checkin['muscle_soreness']);
    final stress = _i(checkin['stress_level']);
    final mood = _i(checkin['mood']);
    final pain = _i(checkin['pain_score']).clamp(0, 10).toInt();
    final rpe = _i(checkin['rpe']).clamp(0, 10).toInt();
    final effectiveSleepQuality = hasCheckin && sleepQuality > 0
        ? sleepQuality.clamp(1, 5).toInt()
        : 3;
    final effectiveFatigue = hasCheckin && fatigue > 0
        ? fatigue.clamp(1, 5).toInt()
        : 3;
    final effectiveSoreness = hasCheckin && soreness > 0
        ? soreness.clamp(1, 5).toInt()
        : 2;
    final effectiveStress = hasCheckin && stress > 0
        ? stress.clamp(1, 5).toInt()
        : 2;
    final effectiveMood = hasCheckin && mood > 0
        ? mood.clamp(1, 5).toInt()
        : 3;
    final sleepDuration =
        (100 - (8.5 - effectiveSleep).abs() * 22).clamp(0.0, 100.0);
    final subjective = (sleepDuration * .20 +
            (effectiveSleepQuality - 1) / 4 * 100 * .15 +
            (5 - effectiveFatigue) / 4 * 100 * .15 +
            (5 - effectiveSoreness) / 4 * 100 * .15 +
            (5 - effectiveStress) / 4 * 100 * .10 +
            (effectiveMood - 1) / 4 * 100 * .10 +
            (10 - pain) / 10 * 100 * .15)
        .clamp(0.0, 100.0)
        .toDouble();
    final score = hasCheckin
        ? (objective * .45 + subjective * .55).clamp(0.0, 100.0).toDouble()
        : objective;
    final label = score >= 80
        ? 'Готов к плановой работе'
        : score >= 60
            ? 'Нужен контроль нагрузки'
            : 'Снизить интенсивность';
    final recommendations = <String>[];
    if (ratio != null && ratio > 1.5) {
      recommendations.add('Нагрузка за 7 дней заметно выше среднего уровня за 28 дней.');
    } else if (ratio != null && ratio > 1.3) {
      recommendations.add('Нагрузка растёт — нужен дополнительный контроль восстановления.');
    }
    if (hasCheckin && pain >= 5) {
      recommendations.add('Игрок отметил боль $pain/10 — нужна очная оценка специалиста.');
    }
    if (hasCheckin && effectiveFatigue >= 4) {
      recommendations.add('Высокая субъективная усталость — уменьшите интенсивную работу.');
    }
    if (hasCheckin && effectiveSleep < 7) {
      recommendations.add('Сон менее 7 часов — учтите это при планировании нагрузки.');
    }
    if (!hasCheckin) {
      recommendations.add('Анкета не заполнена: статус рассчитан только по GPS-нагрузке.');
    }
    if (recommendations.isEmpty) {
      recommendations.add('Критичных отклонений не выявлено; продолжайте обычный контроль.');
    }
    return PlayerReadinessSummary(
      score: score,
      objectiveScore: objective,
      subjectiveScore: subjective,
      label: label,
      hasCheckin: hasCheckin,
      acute7: acute7,
      chronicWeek: chronicWeek,
      ratio: ratio,
      sessions7: sessions7,
      sessions28: sessions28,
      sleepHours: effectiveSleep,
      fatigue: effectiveFatigue,
      pain: pain,
      rpe: rpe,
      recommendations: recommendations,
      referenceDate: referenceDate,
    );
  }

  Future<PlayerProfileSession> loadSessionReport(PlayerProfileSession session, {required int teamId, required int playerId}) async {
    final data = await _get('tracker/get_training_report.php', {
      'session_id': '${session.id}', 'team_id': '$teamId', 'player_id': '$playerId',
      'include_maps': '1', 'include_heatmap': '1', 'include_charts': '1', 'include_hr': '1', 'include_players': '1', 'hr_fallback': '1',
    });
    final root = data['report'] is Map ? Map<String,dynamic>.from(data['report']) : data;
    List<dynamic> pick(List<String> keys) {
      for (final key in keys) { final v = root[key]; if (v is List) return v; }
      for (final group in ['map','charts','player','summary','data']) { final g=root[group]; if (g is Map) { for (final key in keys) { final v=g[key]; if (v is List) return v; } } }
      return const [];
    }
    List<PlayerProfilePoint> points(List<dynamic> raw) => raw.whereType<Map>().map((m) {
      final x = _d(m['x'] ?? m['field_x'] ?? m['lng'] ?? m['longitude']);
      final y = _d(m['y'] ?? m['field_y'] ?? m['lat'] ?? m['latitude']);
      return PlayerProfilePoint(x, y, value: _d(m['value'] ?? m['weight'] ?? m['intensity']));
    }).toList();
    List<double> nums(List<dynamic> raw, List<String> keys) => raw.map((e) {
      if (e is num) return e.toDouble();
      if (e is Map) { for (final k in keys) { final n=_d(e[k]); if (n>0) return n; } }
      return 0.0;
    }).where((e)=>e>0).toList();
    final hrRaw = pick(['heartRateTimeline','heart_rate_timeline','hr_series','heart_rate']);
    final hrValues = <double>[];
    final hrSeconds = <double>[];
    DateTime? firstHrTime;
    for (var index = 0; index < hrRaw.length; index++) {
      final item = hrRaw[index];
      double bpm = 0;
      double sec = index.toDouble();
      if (item is num) {
        bpm = item.toDouble();
      } else if (item is Map) {
        bpm = _d(item['bpm'] ?? item['heart_rate'] ?? item['value']);
        final directSec = _d(item['elapsed_sec'] ?? item['sec'] ?? item['second'] ?? item['seconds']);
        final minute = _d(item['minute']);
        final timeMs = _d(item['time_ms'] ?? item['timestamp_ms']);
        if (directSec > 0) {
          sec = directSec;
        } else if (minute > 0) {
          sec = minute * 60;
        } else if (timeMs > 0) {
          sec = timeMs / 1000;
        } else {
          final rawTime = item['recorded_at'] ?? item['created_at'] ?? item['timestamp'] ?? item['time'];
          final parsed = _date(rawTime);
          if (parsed != null) {
            firstHrTime ??= parsed;
            sec = parsed.difference(firstHrTime!).inMilliseconds / 1000;
          }
        }
      }
      if (bpm > 0) {
        hrValues.add(bpm);
        hrSeconds.add(sec);
      }
    }
    return session.copyWith(
      route: points(pick(['routePoints','route_points','route','gps_points','track_points'])),
      heatmap: points(pick(['heatmapPoints','heatmap_points','heatmap'])),
      speedTimeline: nums(pick(['speedTimeline','speed_timeline','speed_series']), ['speed','speed_kmh','value']),
      heartRateTimeline: hrValues,
      heartRateTimelineSec: hrSeconds,
      trackerReportJson: root,
    );
  }

  List<PlayerTimelineItem> buildTimeline(PlayerProfileSnapshot s) {
    final out = <PlayerTimelineItem>[];
    for (final e in s.trainings) out.add(PlayerTimelineItem(date: _date(e['start_at'] ?? e['date']), type: 'training', title: _s(e['title']).isEmpty ? 'Тренировка' : _s(e['title']), subtitle: _s(e['location']), icon: const IconData(0xe566, fontFamily: 'MaterialIcons')));
    for (final e in s.matches) out.add(PlayerTimelineItem(date: _date(e['match_date'] ?? e['date']), type: 'match', title: _s(e['opponent']).isEmpty ? 'Матч' : 'Матч · ${_s(e['opponent'])}', subtitle: _s(e['score']), icon: const IconData(0xe4dc, fontFamily: 'MaterialIcons')));
    for (final e in s.tests) out.add(PlayerTimelineItem(date: _date(e['date'] ?? e['created_at']), type: 'test', title: _s(e['test_name']).isEmpty ? 'Тестирование' : _s(e['test_name']), subtitle: _s(e['result'] ?? e['value']), icon: const IconData(0xe6e1, fontFamily: 'MaterialIcons')));
    for (final e in s.sessions) out.add(PlayerTimelineItem(date: e.date, type: 'tracker', title: e.title, subtitle: '${(e.distanceM/1000).toStringAsFixed(1)} км · ${e.maxSpeedKmh.toStringAsFixed(1)} км/ч', icon: const IconData(0xe425, fontFamily: 'MaterialIcons')));
    out.sort((a,b)=>(b.date ?? DateTime(1970)).compareTo(a.date ?? DateTime(1970)));
    return out;
  }
}
