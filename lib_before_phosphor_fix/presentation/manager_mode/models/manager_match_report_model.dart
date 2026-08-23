class ManagerSimulateMatchResponse {
  final bool success;
  final int matchId;
  final int homeScore;
  final int awayScore;
  final String resultLabel;
  final String message;

  ManagerSimulateMatchResponse({
    required this.success,
    required this.matchId,
    required this.homeScore,
    required this.awayScore,
    required this.resultLabel,
    required this.message,
  });

  factory ManagerSimulateMatchResponse.fromJson(Map<String, dynamic> json) {
    final score = Map<String, dynamic>.from(json['score'] ?? {});
    return ManagerSimulateMatchResponse(
      success: json['success'] == true,
      matchId: int.tryParse(json['match_id'].toString()) ?? 0,
      homeScore: int.tryParse(score['home'].toString()) ?? 0,
      awayScore: int.tryParse(score['away'].toString()) ?? 0,
      resultLabel: (json['result_label'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
    );
  }
}

class ManagerMatchEventModel {
  final int id;
  final int minute;
  final String teamSide;
  final String eventType;
  final int? playerId;
  final String playerName;
  final String description;

  ManagerMatchEventModel({
    required this.id,
    required this.minute,
    required this.teamSide,
    required this.eventType,
    required this.playerId,
    required this.playerName,
    required this.description,
  });

  factory ManagerMatchEventModel.fromJson(Map<String, dynamic> json) {
    return ManagerMatchEventModel(
      id: int.tryParse(json['id'].toString()) ?? 0,
      minute: int.tryParse(json['minute'].toString()) ?? 0,
      teamSide: (json['team_side'] ?? '').toString(),
      eventType: (json['event_type'] ?? '').toString(),
      playerId: json['player_id'] == null
          ? null
          : int.tryParse(json['player_id'].toString()),
      playerName: (json['player_name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
    );
  }
}

class ManagerPlayerMatchStatModel {
  final int playerId;
  final String fullName;
  final String position;
  final int minutesPlayed;
  final double rating;
  final int goals;
  final int assists;
  final int shots;
  final int keyPasses;
  final int tackles;
  final int interceptions;
  final int passesCompleted;
  final int passesFailed;
  final int yellowCards;
  final int redCards;

  ManagerPlayerMatchStatModel({
    required this.playerId,
    required this.fullName,
    required this.position,
    required this.minutesPlayed,
    required this.rating,
    required this.goals,
    required this.assists,
    required this.shots,
    required this.keyPasses,
    required this.tackles,
    required this.interceptions,
    required this.passesCompleted,
    required this.passesFailed,
    required this.yellowCards,
    required this.redCards,
  });

  factory ManagerPlayerMatchStatModel.fromJson(Map<String, dynamic> json) {
    return ManagerPlayerMatchStatModel(
      playerId: int.tryParse(json['player_id'].toString()) ?? 0,
      fullName: (json['full_name'] ?? '').toString(),
      position: (json['position'] ?? '').toString(),
      minutesPlayed: int.tryParse(json['minutes_played'].toString()) ?? 0,
      rating: double.tryParse(json['rating'].toString()) ?? 0,
      goals: int.tryParse(json['goals'].toString()) ?? 0,
      assists: int.tryParse(json['assists'].toString()) ?? 0,
      shots: int.tryParse(json['shots'].toString()) ?? 0,
      keyPasses: int.tryParse(json['key_passes'].toString()) ?? 0,
      tackles: int.tryParse(json['tackles'].toString()) ?? 0,
      interceptions: int.tryParse(json['interceptions'].toString()) ?? 0,
      passesCompleted: int.tryParse(json['passes_completed'].toString()) ?? 0,
      passesFailed: int.tryParse(json['passes_failed'].toString()) ?? 0,
      yellowCards: int.tryParse(json['yellow_cards'].toString()) ?? 0,
      redCards: int.tryParse(json['red_cards'].toString()) ?? 0,
    );
  }
}

class ManagerMatchInfoModel {
  final int id;
  final int teamId;
  final String opponentName;
  final String matchDate;
  final String formationUsed;
  final String playStyle;
  final int teamStrength;
  final int opponentStrength;
  final int homeScore;
  final int awayScore;
  final int possessionHome;
  final int possessionAway;
  final int shotsHome;
  final int shotsAway;
  final int shotsOnTargetHome;
  final int shotsOnTargetAway;
  final String resultLabel;

  ManagerMatchInfoModel({
    required this.id,
    required this.teamId,
    required this.opponentName,
    required this.matchDate,
    required this.formationUsed,
    required this.playStyle,
    required this.teamStrength,
    required this.opponentStrength,
    required this.homeScore,
    required this.awayScore,
    required this.possessionHome,
    required this.possessionAway,
    required this.shotsHome,
    required this.shotsAway,
    required this.shotsOnTargetHome,
    required this.shotsOnTargetAway,
    required this.resultLabel,
  });

  factory ManagerMatchInfoModel.fromJson(Map<String, dynamic> json) {
    return ManagerMatchInfoModel(
      id: int.tryParse(json['id'].toString()) ?? 0,
      teamId: int.tryParse(json['team_id'].toString()) ?? 0,
      opponentName: (json['opponent_name'] ?? '').toString(),
      matchDate: (json['match_date'] ?? '').toString(),
      formationUsed: (json['formation_used'] ?? '').toString(),
      playStyle: (json['play_style'] ?? '').toString(),
      teamStrength: int.tryParse(json['team_strength'].toString()) ?? 0,
      opponentStrength: int.tryParse(json['opponent_strength'].toString()) ?? 0,
      homeScore: int.tryParse(json['home_score'].toString()) ?? 0,
      awayScore: int.tryParse(json['away_score'].toString()) ?? 0,
      possessionHome: int.tryParse(json['possession_home'].toString()) ?? 0,
      possessionAway: int.tryParse(json['possession_away'].toString()) ?? 0,
      shotsHome: int.tryParse(json['shots_home'].toString()) ?? 0,
      shotsAway: int.tryParse(json['shots_away'].toString()) ?? 0,
      shotsOnTargetHome:
          int.tryParse(json['shots_on_target_home'].toString()) ?? 0,
      shotsOnTargetAway:
          int.tryParse(json['shots_on_target_away'].toString()) ?? 0,
      resultLabel: (json['result_label'] ?? '').toString(),
    );
  }
}

class ManagerMatchReportModel {
  final ManagerMatchInfoModel match;
  final List<ManagerMatchEventModel> events;
  final List<ManagerPlayerMatchStatModel> playerStats;

  ManagerMatchReportModel({
    required this.match,
    required this.events,
    required this.playerStats,
  });

  factory ManagerMatchReportModel.fromJson(Map<String, dynamic> json) {
    return ManagerMatchReportModel(
      match: ManagerMatchInfoModel.fromJson(
        Map<String, dynamic>.from(json['match'] ?? {}),
      ),
      events: (json['events'] as List? ?? [])
          .map((e) => ManagerMatchEventModel.fromJson(
                Map<String, dynamic>.from(e),
              ))
          .toList(),
      playerStats: (json['player_stats'] as List? ?? [])
          .map((e) => ManagerPlayerMatchStatModel.fromJson(
                Map<String, dynamic>.from(e),
              ))
          .toList(),
    );
  }
}