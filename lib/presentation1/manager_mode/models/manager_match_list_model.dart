class ManagerMatchListItem {
  final int id;
  final int teamId;
  final String opponentName;
  final String matchDate;
  final String formationUsed;
  final String playStyle;
  final String pressingLevel;
  final String tempo;
  final String defensiveLine;
  final String intensity;
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
  final String status;
  final String competitionType;
  final String roundLabel;
  final bool isHome;

  ManagerMatchListItem({
    required this.id,
    required this.teamId,
    required this.opponentName,
    required this.matchDate,
    required this.formationUsed,
    required this.playStyle,
    required this.pressingLevel,
    required this.tempo,
    required this.defensiveLine,
    required this.intensity,
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
    required this.status,
    required this.competitionType,
    required this.roundLabel,
    required this.isHome,
  });

  factory ManagerMatchListItem.fromJson(Map<String, dynamic> json) {
    return ManagerMatchListItem(
      id: int.tryParse(json['id'].toString()) ?? 0,
      teamId: int.tryParse(json['team_id'].toString()) ?? 0,
      opponentName: (json['opponent_name'] ?? '').toString(),
      matchDate: (json['match_date'] ?? '').toString(),
      formationUsed: (json['formation_used'] ?? '').toString(),
      playStyle: (json['play_style'] ?? '').toString(),
      pressingLevel: (json['pressing_level'] ?? '').toString(),
      tempo: (json['tempo'] ?? '').toString(),
      defensiveLine: (json['defensive_line'] ?? '').toString(),
      intensity: (json['intensity'] ?? '').toString(),
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
      status: (json['status'] ?? '').toString(),
      competitionType: (json['competition_type'] ?? '').toString(),
      roundLabel: (json['round_label'] ?? '').toString(),
      isHome: json['is_home'] == true || json['is_home'].toString() == '1',
    );
  }
}