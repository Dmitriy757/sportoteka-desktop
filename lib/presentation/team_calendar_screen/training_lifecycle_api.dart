import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class TrainingActivityEntry {
  final int id;
  final String action;
  final String title;
  final String detail;
  final int actorUserId;
  final String actorName;
  final DateTime? createdAt;

  const TrainingActivityEntry({
    this.id = 0,
    this.action = '',
    this.title = '',
    this.detail = '',
    this.actorUserId = 0,
    this.actorName = '',
    this.createdAt,
  });

  factory TrainingActivityEntry.fromMap(Map raw) {
    int asInt(dynamic value) =>
        value is num ? value.toInt() : int.tryParse('${value ?? ''}') ?? 0;
    DateTime? asDate(dynamic value) {
      final text = '${value ?? ''}'.trim();
      if (text.isEmpty || text == 'null') return null;
      return DateTime.tryParse(text.replaceFirst(' ', 'T'));
    }

    return TrainingActivityEntry(
      id: asInt(raw['id']),
      action: '${raw['action'] ?? ''}'.trim(),
      title: '${raw['title'] ?? ''}'.trim(),
      detail: '${raw['detail'] ?? ''}'.trim(),
      actorUserId: asInt(raw['actor_user_id'] ?? raw['user_id']),
      actorName: '${raw['actor_name'] ?? raw['user_name'] ?? ''}'.trim(),
      createdAt: asDate(raw['created_at']),
    );
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'action': action,
        'title': title,
        'detail': detail,
        'actor_user_id': actorUserId,
        'actor_name': actorName,
        'created_at': createdAt?.toIso8601String(),
      };
}

class TrainingLifecycleState {
  final String status;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final int startedBy;
  final String startedByName;
  final int finishedBy;
  final String finishedByName;
  final String coachNote;
  final int attendancePresent;
  final int attendanceTotal;
  final int ratingsCount;
  final List<TrainingActivityEntry> activities;
  final bool serverBacked;

  const TrainingLifecycleState({
    this.status = 'planned',
    this.startedAt,
    this.finishedAt,
    this.startedBy = 0,
    this.startedByName = '',
    this.finishedBy = 0,
    this.finishedByName = '',
    this.coachNote = '',
    this.attendancePresent = 0,
    this.attendanceTotal = 0,
    this.ratingsCount = 0,
    this.activities = const <TrainingActivityEntry>[],
    this.serverBacked = false,
  });

  bool get started => status == 'started' || status == 'finished';
  bool get finished => status == 'finished';

  String get startedByLabel => startedByName.trim().isNotEmpty
      ? startedByName.trim()
      : (startedBy > 0 ? 'Тренер #$startedBy' : 'Тренер');

  String get finishedByLabel => finishedByName.trim().isNotEmpty
      ? finishedByName.trim()
      : (finishedBy > 0 ? 'Тренер #$finishedBy' : 'Тренер');

  TrainingLifecycleState copyWith({
    String? status,
    DateTime? startedAt,
    DateTime? finishedAt,
    int? startedBy,
    String? startedByName,
    int? finishedBy,
    String? finishedByName,
    String? coachNote,
    int? attendancePresent,
    int? attendanceTotal,
    int? ratingsCount,
    List<TrainingActivityEntry>? activities,
    bool? serverBacked,
  }) {
    return TrainingLifecycleState(
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      startedBy: startedBy ?? this.startedBy,
      startedByName: startedByName ?? this.startedByName,
      finishedBy: finishedBy ?? this.finishedBy,
      finishedByName: finishedByName ?? this.finishedByName,
      coachNote: coachNote ?? this.coachNote,
      attendancePresent: attendancePresent ?? this.attendancePresent,
      attendanceTotal: attendanceTotal ?? this.attendanceTotal,
      ratingsCount: ratingsCount ?? this.ratingsCount,
      activities: activities ?? this.activities,
      serverBacked: serverBacked ?? this.serverBacked,
    );
  }
}

class TrainingLifecycleException implements Exception {
  final String message;
  const TrainingLifecycleException(this.message);

  @override
  String toString() => message;
}

/// Единый жизненный цикл календарной тренировки.
///
/// Сервер хранит автора и время старта/окончания, посещаемость, количество
/// оценок и журнал действий. Push клубным администраторам отправляет сам
/// training_lifecycle.php, чтобы уведомление не зависело от состояния клиента.
class TrainingLifecycleApi {
  final String apiBase;
  final int clubId;
  final int teamId;
  final int eventId;

  const TrainingLifecycleApi({
    required this.apiBase,
    required this.clubId,
    required this.teamId,
    required this.eventId,
  });

  String get _localKey => 'sportoteka_training_lifecycle_v2_$eventId';

  Future<TrainingLifecycleState> load() async {
    final local = await _loadLocal();
    if (eventId <= 0) return local;

    try {
      final uri = Uri.parse('$apiBase/training_lifecycle.php').replace(
        queryParameters: <String, String>{
          'event_id': '$eventId',
          if (teamId > 0) 'team_id': '$teamId',
          if (clubId > 0) 'club_id': '$clubId',
        },
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) return local;

      final decoded = _decode(response.body);
      if (decoded is! Map || decoded['success'] == false) return local;

      final state = _stateFromResponse(decoded, serverBacked: true);
      await _saveLocal(state);
      return state;
    } catch (_) {
      return local;
    }
  }

  Future<TrainingLifecycleState> start({
    required int userId,
    int attendancePresent = 0,
    int attendanceTotal = 0,
  }) async {
    if (eventId <= 0 || teamId <= 0 || userId <= 0) {
      throw const TrainingLifecycleException('Некорректные данные тренировки');
    }

    final state = await _postAction(
      <String, String>{
        'action': 'start',
        'event_id': '$eventId',
        'team_id': '$teamId',
        'club_id': '$clubId',
        'user_id': '$userId',
        'started_by': '$userId',
        'attendance_present': '$attendancePresent',
        'attendance_total': '$attendanceTotal',
      },
    );

    // Существующий push участникам остаётся отдельным. Он вызывается только
    // после подтверждённого сервером старта, а не при каждой отметке журнала.
    try {
      await http.post(
        Uri.parse('$apiBase/notify_training_started.php'),
        body: <String, String>{
          'club_id': '$clubId',
          'team_id': '$teamId',
          'event_id': '$eventId',
          'started_by': '$userId',
          'attendance_status': '$attendancePresent/$attendanceTotal',
        },
      ).timeout(const Duration(seconds: 8));
    } catch (_) {}

    return state;
  }

  Future<TrainingLifecycleState> recordAttendanceOpened({
    required int userId,
  }) {
    return _postAction(
      <String, String>{
        'action': 'attendance_opened',
        'event_id': '$eventId',
        'team_id': '$teamId',
        'club_id': '$clubId',
        'user_id': '$userId',
      },
    );
  }

  Future<TrainingLifecycleState> recordAttendanceReady({
    required int userId,
    required int attendancePresent,
    required int attendanceTotal,
  }) {
    return _postAction(
      <String, String>{
        'action': 'attendance_ready',
        'event_id': '$eventId',
        'team_id': '$teamId',
        'club_id': '$clubId',
        'user_id': '$userId',
        'attendance_present': '$attendancePresent',
        'attendance_total': '$attendanceTotal',
      },
    );
  }

  Future<TrainingLifecycleState> markRatingsSaved({
    required int userId,
  }) {
    return _postAction(
      <String, String>{
        'action': 'ratings_saved',
        'event_id': '$eventId',
        'team_id': '$teamId',
        'club_id': '$clubId',
        'user_id': '$userId',
      },
    );
  }

  Future<TrainingLifecycleState> recordPlanLinked({
    required int userId,
    required int planId,
    String planTitle = '',
  }) {
    return _postAction(
      <String, String>{
        'action': 'plan_linked',
        'event_id': '$eventId',
        'team_id': '$teamId',
        'club_id': '$clubId',
        'user_id': '$userId',
        'plan_id': '$planId',
        if (planTitle.trim().isNotEmpty) 'plan_title': planTitle.trim(),
      },
    );
  }

  Future<TrainingLifecycleState> recordDocumentAdded({
    required int userId,
    required String fileName,
  }) {
    return _postAction(
      <String, String>{
        'action': 'document_added',
        'event_id': '$eventId',
        'team_id': '$teamId',
        'club_id': '$clubId',
        'user_id': '$userId',
        'file_name': fileName.trim(),
      },
    );
  }

  Future<TrainingLifecycleState> finish({
    required int userId,
    required String coachNote,
  }) async {
    if (eventId <= 0 || teamId <= 0 || userId <= 0) {
      throw const TrainingLifecycleException('Некорректные данные тренировки');
    }

    // Push клубному администратору и запись в журнал делаются на сервере.
    // Не имитируем завершение локально, если сервер его не подтвердил.
    return _postAction(
      <String, String>{
        'action': 'finish',
        'event_id': '$eventId',
        'team_id': '$teamId',
        'club_id': '$clubId',
        'user_id': '$userId',
        'finished_by': '$userId',
        'coach_note': coachNote.trim(),
      },
    );
  }

  Future<TrainingLifecycleState> _postAction(Map<String, String> body) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBase/training_lifecycle.php'),
        body: body,
      ).timeout(const Duration(seconds: 12));

      final decoded = _decode(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final message = decoded is Map
            ? '${decoded['message'] ?? 'HTTP ${response.statusCode}'}'
            : 'HTTP ${response.statusCode}';
        throw TrainingLifecycleException(message.replaceFirst('Exception: ', ''));
      }
      if (decoded is! Map || decoded['success'] == false) {
        final message = decoded is Map
            ? '${decoded['message'] ?? 'Сервер не подтвердил действие'}'
            : 'Некорректный ответ сервера';
        throw TrainingLifecycleException(message);
      }

      final state = _stateFromResponse(decoded, serverBacked: true);
      await _saveLocal(state);
      return state;
    } on TrainingLifecycleException {
      rethrow;
    } catch (e) {
      throw TrainingLifecycleException('Нет связи с сервером: $e');
    }
  }

  TrainingLifecycleState _stateFromResponse(
    Map decoded, {
    required bool serverBacked,
  }) {
    final rawState = decoded['state'] is Map ? decoded['state'] as Map : decoded;
    final rawActivities = decoded['activities'];
    final activities = <TrainingActivityEntry>[];
    if (rawActivities is List) {
      for (final raw in rawActivities.whereType<Map>()) {
        activities.add(TrainingActivityEntry.fromMap(raw));
      }
    }
    return _stateFromMap(
      rawState,
      serverBacked: serverBacked,
      activities: activities,
    );
  }

  dynamic _decode(String body) {
    final text = body.trim();
    if (text.isEmpty) return <String, dynamic>{};
    try {
      return jsonDecode(text);
    } catch (_) {
      final obj = text.indexOf('{');
      final arr = text.indexOf('[');
      final starts = <int>[if (obj >= 0) obj, if (arr >= 0) arr];
      if (starts.isNotEmpty) {
        starts.sort();
        try {
          return jsonDecode(text.substring(starts.first));
        } catch (_) {}
      }
      return <String, dynamic>{};
    }
  }

  TrainingLifecycleState _stateFromMap(
    Map raw, {
    required bool serverBacked,
    List<TrainingActivityEntry>? activities,
  }) {
    int asInt(dynamic value) =>
        value is num ? value.toInt() : int.tryParse('${value ?? ''}') ?? 0;

    final status = '${raw['status'] ?? raw['training_status'] ?? raw['lifecycle_status'] ?? 'planned'}'
        .trim()
        .toLowerCase();
    final startedAt = _date(raw['started_at'] ?? raw['training_started_at']);
    final finishedAt = _date(raw['finished_at'] ?? raw['training_finished_at']);

    final rawActivities = raw['activities'];
    final parsedActivities = activities ?? <TrainingActivityEntry>[];
    if (parsedActivities.isEmpty && rawActivities is List) {
      for (final item in rawActivities.whereType<Map>()) {
        parsedActivities.add(TrainingActivityEntry.fromMap(item));
      }
    }

    return TrainingLifecycleState(
      status: status == 'finished' || finishedAt != null
          ? 'finished'
          : (status == 'started' || startedAt != null ? 'started' : 'planned'),
      startedAt: startedAt,
      finishedAt: finishedAt,
      startedBy: asInt(raw['started_by']),
      startedByName: '${raw['started_by_name'] ?? ''}'.trim(),
      finishedBy: asInt(raw['finished_by']),
      finishedByName: '${raw['finished_by_name'] ?? ''}'.trim(),
      coachNote: '${raw['coach_note'] ?? raw['finish_note'] ?? ''}'.trim(),
      attendancePresent: asInt(raw['attendance_present']),
      attendanceTotal: asInt(raw['attendance_total']),
      ratingsCount: asInt(raw['ratings_count']),
      activities: List<TrainingActivityEntry>.unmodifiable(parsedActivities),
      serverBacked: serverBacked,
    );
  }

  DateTime? _date(dynamic raw) {
    final text = '${raw ?? ''}'.trim();
    if (text.isEmpty || text == 'null') return null;
    return DateTime.tryParse(text.replaceFirst(' ', 'T'));
  }

  Future<TrainingLifecycleState> _loadLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_localKey);
      if (raw == null || raw.trim().isEmpty) {
        return const TrainingLifecycleState();
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const TrainingLifecycleState();
      return _stateFromMap(decoded, serverBacked: false);
    } catch (_) {
      return const TrainingLifecycleState();
    }
  }

  Future<void> _saveLocal(TrainingLifecycleState state) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _localKey,
        jsonEncode(<String, dynamic>{
          'status': state.status,
          'started_at': state.startedAt?.toIso8601String(),
          'finished_at': state.finishedAt?.toIso8601String(),
          'started_by': state.startedBy,
          'started_by_name': state.startedByName,
          'finished_by': state.finishedBy,
          'finished_by_name': state.finishedByName,
          'coach_note': state.coachNote,
          'attendance_present': state.attendancePresent,
          'attendance_total': state.attendanceTotal,
          'ratings_count': state.ratingsCount,
          'activities': state.activities.map((item) => item.toMap()).toList(),
        }),
      );
    } catch (_) {}
  }
}
