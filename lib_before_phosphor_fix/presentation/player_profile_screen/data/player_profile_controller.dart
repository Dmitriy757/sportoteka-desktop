import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import '../models/player_profile_models.dart';
import 'player_profile_repository.dart';

class PlayerProfileController extends ChangeNotifier {
  final Map<String,dynamic> player;
  final PlayerProfileRepository repository;
  PlayerProfileSection section = PlayerProfileSection.overview;
  PlayerProfileSnapshot? snapshot;
  PlayerProfileSession? selectedSession;
  bool loading = false;
  bool sessionLoading = false;
  String? error;

  PlayerProfileController({required this.player, PlayerProfileRepository? repository}) : repository = repository ?? PlayerProfileRepository();
  int _i(dynamic v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;
  int get teamId => _i(player['team_id'] ?? player['teamId']);
  int get playerId => _i(player['player_id'] ?? player['id'] ?? player['user_id']);
  int get userId => _i(player['user_id'] ?? playerId);

  Future<void> load() async {
    loading = true; error = null; notifyListeners();
    try {
      snapshot = await repository.loadSnapshot(player);
      if (snapshot!.sessions.isNotEmpty) await selectSession(snapshot!.sessions.first);
    } catch (e) { error = e.toString(); }
    loading = false; notifyListeners();
  }

  void selectSection(PlayerProfileSection value) { section = value; notifyListeners(); }

  Future<void> saveMetrics(Map<String, dynamic> values) async {
    await repository.savePlayerMetrics(playerId: playerId, userId: userId, values: values);
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

  Future<void> selectSession(PlayerProfileSession session) async {
    selectedSession = session; sessionLoading = true; notifyListeners();
    try { selectedSession = await repository.loadSessionReport(session, teamId: teamId, playerId: playerId); } catch (_) {}
    sessionLoading = false; notifyListeners();
  }
}
