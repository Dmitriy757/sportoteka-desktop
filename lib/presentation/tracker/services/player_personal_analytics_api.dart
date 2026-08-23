import '../models/action_tracker_protocol.dart';
import '../models/tracker_pro_models.dart';
import 'player_personal_tracker_api.dart';
import 'tracker_pro_api.dart';

/// Read-only analytics adapter for the player's own personal trainings.
///
/// The coach analytics UI can reuse TrackerActionAnalyticsSuite, but every
/// query made through this adapter is hard-scoped to one owner/player. This
/// prevents a cleared UI filter from exposing another player's personal data.
class PlayerPersonalAnalyticsApi extends TrackerProApi {
  PlayerPersonalAnalyticsApi({
    required this.ownerUserId,
    required this.playerId,
    String apiBaseUrl = 'https://sportotekaapp.ru/api/tracker',
  })  : _personal = PlayerPersonalTrackerApi(apiBaseUrl: apiBaseUrl),
        super(apiBaseUrl: apiBaseUrl);

  final int ownerUserId;
  final int playerId;
  final PlayerPersonalTrackerApi _personal;

  @override
  Future<TrackerDashboardModel> loadDashboard({
    required int teamId,
    String? date,
    String? fromTime,
    String? toTime,
  }) async {
    // Personal analytics is built from the player's own sessions, never from
    // the team dashboard aggregate.
    return const TrackerDashboardModel(
      summary: <String, dynamic>{},
      players: <TrackerPlayerLoadRow>[],
      alerts: <Map<String, dynamic>>[],
    );
  }

  @override
  Future<List<TrackerPlayerOption>> loadPlayers({required int teamId}) async {
    final roster = await super.loadPlayers(teamId: teamId);
    final matches = roster.where((player) {
      if (player.id == playerId || player.id == ownerUserId) return true;
      return player.identityIds.contains(playerId) ||
          player.identityIds.contains(ownerUserId);
    }).toList(growable: false);
    return matches;
  }

  @override
  Future<List<TrackerSessionModel>> loadSessions({
    required int teamId,
    int? playerId,
    String? date,
    String? fromTime,
    String? toTime,
    int? limit,
    String? sessionKind,
  }) async {
    final rows = await _personal.loadSessions(
      teamId: teamId,
      userId: ownerUserId,
      playerId: this.playerId,
      date: date,
      limit: (limit ?? 500).clamp(1, 500).toInt(),
    );

    final sessions = rows
        .where(_rowBelongsToPersonalPlayer)
        .map((row) => TrackerSessionModel.fromJson(<String, dynamic>{
              ...row,
              'personal_session': 1,
              'session_kind': 'personal',
              'participants_count': 1,
              'participant_ids': <int>[this.playerId],
            }))
        .where((session) => session.id > 0)
        .where((session) => _matchesTime(session.createdAt, fromTime, toTime))
        .toList(growable: false)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sessions;
  }

  @override
  Future<List<ActionTrackerGpsPoint>> loadSessionPoints({
    required int teamId,
    int? playerId,
    int? sessionId,
    String? date,
    String? fromTime,
    String? toTime,
    int limit = 5000,
  }) async {
    if (sessionId != null && sessionId > 0) {
      final points = await _personal.loadSessionPoints(
        teamId: teamId,
        userId: ownerUserId,
        sessionId: sessionId,
        limit: limit,
      );
      return points.where(_pointBelongsToPersonalPlayer).toList(growable: false);
    }

    // The personal endpoint is intentionally session based. Resolve the
    // relevant own sessions first and merge their points for day/period views.
    final sessions = await loadSessions(
      teamId: teamId,
      date: date,
      fromTime: fromTime,
      toTime: toTime,
      limit: 120,
      sessionKind: 'personal',
    );
    if (sessions.isEmpty) return const <ActionTrackerGpsPoint>[];

    final chunks = await Future.wait(
      sessions.take(12).map(
            (session) => _personal.loadSessionPoints(
              teamId: teamId,
              userId: ownerUserId,
              sessionId: session.id,
              limit: limit,
            ),
          ),
    );
    final out = chunks
        .expand((e) => e)
        .where(_pointBelongsToPersonalPlayer)
        .toList(growable: false)
      ..sort((a, b) => a.timeMs.compareTo(b.timeMs));
    return out;
  }

  @override
  Future<List<TrackerHeatPoint>> loadHeatmap({
    required int teamId,
    int? playerId,
    int? sessionId,
    int? fieldId,
    String? date,
    String? fromTime,
    String? toTime,
  }) async {
    // Personal heatmap is always built from player_get_session_points.php.
    // Never fall back to the team heatmap endpoint: an old server can return
    // points of teammates even when player_id is supplied.
    return const <TrackerHeatPoint>[];
  }

  @override
  Future<Map<String, dynamic>> loadHeartRateSummary({
    required int teamId,
    int? playerId,
    int? sessionId,
    List<int>? sessionIds,
    String? date,
    String? fromTime,
    String? toTime,
    String? sessionKind,
  }) {
    return super.loadHeartRateSummary(
      teamId: teamId,
      playerId: this.playerId,
      sessionId: sessionId,
      sessionIds: sessionIds,
      date: date,
      fromTime: fromTime,
      toTime: toTime,
      sessionKind: 'personal',
    );
  }

  @override
  Future<Map<String, dynamic>> loadTrainingReportHeartRate({
    required int teamId,
    required int sessionId,
    int? playerId,
  }) {
    return super.loadTrainingReportHeartRate(
      teamId: teamId,
      sessionId: sessionId,
      playerId: this.playerId,
    );
  }

  bool _pointBelongsToPersonalPlayer(ActionTrackerGpsPoint point) {
    final id = point.playerId;
    return id == null || id <= 0 || id == playerId || id == ownerUserId;
  }

  bool _rowBelongsToPersonalPlayer(Map<String, dynamic> row) {
    final ids = <int>{};
    for (final key in const <String>[
      'player_id',
      'playerId',
      'user_id',
      'userId',
      'owner_user_id',
      'ownerUserId',
    ]) {
      final value = int.tryParse('${row[key] ?? ''}');
      if (value != null && value > 0) ids.add(value);
    }
    // Older personal endpoint versions did not return owner/player ids at all.
    // In that case the server query itself is the only scope and the row is kept.
    if (ids.isEmpty) return true;
    return ids.contains(playerId) || ids.contains(ownerUserId);
  }

  bool _matchesTime(String createdAt, String? fromTime, String? toTime) {
    if ((fromTime == null || fromTime.trim().isEmpty) &&
        (toTime == null || toTime.trim().isEmpty)) {
      return true;
    }
    final dt = DateTime.tryParse(createdAt.replaceFirst(' ', 'T'));
    if (dt == null) return true;
    final minute = dt.hour * 60 + dt.minute;
    final from = _clockMinutes(fromTime);
    final to = _clockMinutes(toTime);
    if (from != null && minute < from) return false;
    if (to != null && minute > to) return false;
    return true;
  }

  int? _clockMinutes(String? value) {
    final text = '${value ?? ''}'.trim();
    if (text.isEmpty) return null;
    final parts = text.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }
}
