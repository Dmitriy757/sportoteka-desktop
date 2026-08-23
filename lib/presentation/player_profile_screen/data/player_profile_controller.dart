import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import '../models/player_profile_models.dart';
import 'player_profile_repository.dart';

class PlayerProfileController extends ChangeNotifier {
  final Map<String,dynamic> player;
  final PlayerProfileRepository repository;
  PlayerProfileSection section = PlayerProfileSection.card;
  PlayerProfileSnapshot? snapshot;
  PlayerProfileSession? selectedSession;
  bool loading = false;
  bool sessionLoading = false;
  String? error;
  bool _disposed = false;

  bool get isDisposed => _disposed;

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  PlayerProfileController({
    required Map<String, dynamic> player,
    PlayerProfileRepository? repository,
  })  : player = Map<String, dynamic>.from(player),
        repository = repository ?? PlayerProfileRepository();
  int _i(dynamic v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;
  int get teamId => _i(player['team_id'] ?? player['teamId']);
  int get clubId => _i(player['club_id'] ?? player['clubId']);
  int get playerId => _i(player['player_id'] ?? player['id'] ?? player['user_id']);
  int get userId => _i(player['user_id'] ?? playerId);

  Future<void> load() async {
    if (_disposed) return;
    loading = true;
    error = null;
    _emit();

    try {
      final loaded = await repository.loadSnapshot(player);
      if (_disposed) return;
      snapshot = loaded;

      if (loaded.sessions.isNotEmpty) {
        await selectSession(loaded.sessions.first);
      }
    } catch (e) {
      if (_disposed) return;
      error = e.toString();
    }

    if (_disposed) return;
    loading = false;
    _emit();
  }

  void selectSection(PlayerProfileSection value) {
    if (_disposed) return;
    if (value == PlayerProfileSection.overview) {
      section = PlayerProfileSection.card;
    } else if (value == PlayerProfileSection.analytics) {
      section = PlayerProfileSection.activity;
    } else {
      section = value;
    }
    _emit();
  }

  Future<void> saveMetrics(Map<String, dynamic> values) async {
    Map<String, dynamic> saved = <String, dynamic>{...values};
    try {
      saved = await repository.savePlayerMetrics(
        playerId: playerId,
        userId: userId,
        clubId: clubId,
        teamId: teamId,
        values: values,
      );
    } catch (_) {
      // The school-profile record below is a compatible persistence fallback
      // for installations where the legacy metrics endpoint has another schema.
    }
    final profileValues = <String, dynamic>{
      ...?snapshot?.schoolProfile,
      ...saved,
    };
    await repository.saveSchoolProfile(
      playerId: playerId,
      userId: userId,
      values: profileValues,
      existingRecord: snapshot?.schoolProfileRecord,
    );
    player.addAll(saved);
    await load();
  }

  Future<void> saveSchoolProfile(Map<String, dynamic> values) async {
    final merged = <String, dynamic>{
      ...?snapshot?.schoolProfile,
      ...values,
    };
    await repository.saveSchoolProfile(
      playerId: playerId,
      userId: userId,
      values: merged,
      existingRecord: snapshot?.schoolProfileRecord,
    );
    player.addAll(values);
    await load();
  }

  Future<void> saveMedical(Map<String, dynamic> record, [PlatformFile? attachment]) async {
    await repository.saveMedicalRecord(playerId: playerId, userId: userId, record: record, attachment: attachment);
    await load();
  }

  Future<void> deleteMedical(Map<String, dynamic> record) async {
    await repository.deleteMedicalRecord(playerId: playerId, userId: userId, record: record);
    await load();
  }

  Future<void> saveDocument(
    Map<String, dynamic> document, [
    PlatformFile? attachment,
  ]) async {
    await repository.savePlayerDocument(
      playerId: playerId,
      userId: userId,
      document: document,
      attachment: attachment,
    );
    await load();
  }

  Future<void> deleteDocument(Map<String, dynamic> document) async {
    await repository.deletePlayerDocument(
      playerId: playerId,
      userId: userId,
      document: document,
    );
    await load();
  }


  Future<void> saveDiaryEntry({
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
    await repository.saveDiaryEntry(
      clubId: _i(player['club_id'] ?? player['clubId']),
      teamId: teamId,
      playerId: playerId,
      authorUserId: authorUserId,
      authorRole: authorRole,
      entryDate: entryDate,
      eventId: eventId,
      rating: rating,
      mood: mood,
      fatigue: fatigue,
      sleepQuality: sleepQuality,
      pain: pain,
      rpe: rpe,
      note: note,
    );
    await load();
  }


  Future<void> saveWeekGoal({
    required int authorUserId,
    required String authorRole,
    int goalId = 0,
    required DateTime weekStart,
    String goalText = '',
    int progress = 0,
    bool isDone = false,
  }) async {
    await repository.saveWeekGoal(
      clubId: _i(player['club_id'] ?? player['clubId']),
      teamId: teamId,
      playerId: playerId,
      authorUserId: authorUserId,
      authorRole: authorRole,
      goalId: goalId,
      weekStart: weekStart,
      goalText: goalText,
      progress: progress,
      isDone: isDone,
    );
    await load();
  }

  Future<void> selectSession(PlayerProfileSession session) async {
    if (_disposed) return;
    selectedSession = session;
    sessionLoading = true;
    _emit();

    try {
      final report = await repository.loadSessionReport(
        session,
        teamId: teamId,
        playerId: playerId,
      );
      if (_disposed) return;
      selectedSession = report;
    } catch (_) {
      // Сохраняем базовую сессию, если подробный отчёт не загрузился.
    }

    if (_disposed) return;
    sessionLoading = false;
    _emit();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

}
