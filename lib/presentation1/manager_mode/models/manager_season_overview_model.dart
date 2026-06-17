class ManagerSeasonLeader {
  final int playerId;
  final String fullName;
  final String position;
  final int statValue;

  ManagerSeasonLeader({
    required this.playerId,
    required this.fullName,
    required this.position,
    required this.statValue,
  });

  factory ManagerSeasonLeader.fromJson(Map<String, dynamic> json) {
    return ManagerSeasonLeader(
      playerId: int.tryParse(json['player_id'].toString()) ?? 0,
      fullName: (json['full_name'] ?? '').toString(),
      position: (json['position'] ?? '').toString(),
      statValue: int.tryParse(json['stat_value'].toString()) ?? 0,
    );
  }
}

class ManagerSeasonOverviewModel {
  final int played;
  final int wins;
  final int draws;
  final int losses;
  final int goalsFor;
  final int goalsAgainst;
  final int goalDiff;
  final int points;
  final List<String> recentForm;
  final ManagerSeasonLeader? topScorer;
  final ManagerSeasonLeader? topAssist;

  ManagerSeasonOverviewModel({
    required this.played,
    required this.wins,
    required this.draws,
    required this.losses,
    required this.goalsFor,
    required this.goalsAgainst,
    required this.goalDiff,
    required this.points,
    required this.recentForm,
    required this.topScorer,
    required this.topAssist,
  });

  factory ManagerSeasonOverviewModel.fromJson(Map<String, dynamic> json) {
    final season = Map<String, dynamic>.from(json['season'] ?? {});
    return ManagerSeasonOverviewModel(
      played: int.tryParse(season['played'].toString()) ?? 0,
      wins: int.tryParse(season['wins'].toString()) ?? 0,
      draws: int.tryParse(season['draws'].toString()) ?? 0,
      losses: int.tryParse(season['losses'].toString()) ?? 0,
      goalsFor: int.tryParse(season['goals_for'].toString()) ?? 0,
      goalsAgainst: int.tryParse(season['goals_against'].toString()) ?? 0,
      goalDiff: int.tryParse(season['goal_diff'].toString()) ?? 0,
      points: int.tryParse(season['points'].toString()) ?? 0,
      recentForm: (season['recent_form'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
      topScorer: season['top_scorer'] == null
          ? null
          : ManagerSeasonLeader.fromJson(
              Map<String, dynamic>.from(season['top_scorer']),
            ),
      topAssist: season['top_assist'] == null
          ? null
          : ManagerSeasonLeader.fromJson(
              Map<String, dynamic>.from(season['top_assist']),
            ),
    );
  }
}