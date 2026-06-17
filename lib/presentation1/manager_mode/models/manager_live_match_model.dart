class ManagerLiveMatchModel {
  final int id;
  final int teamId;
  final int userId;
  final String opponentName;
  final int opponentStrength;
  final String formationUsed;
  final String playStyle;
  final String pressingLevel;
  final String tempo;
  final String defensiveLine;
  final String intensity;
  final int minuteCurrent;
  final String periodLabel;
  final int homeScore;
  final int awayScore;
  final int possessionHome;
  final int possessionAway;
  final int shotsHome;
  final int shotsAway;
  final int shotsOnTargetHome;
  final int shotsOnTargetAway;
  final int momentumHome;
  final int momentumAway;
  final int teamEnergy;
  final int opponentEnergy;
  final String status;

  ManagerLiveMatchModel({
    required this.id,
    required this.teamId,
    required this.userId,
    required this.opponentName,
    required this.opponentStrength,
    required this.formationUsed,
    required this.playStyle,
    required this.pressingLevel,
    required this.tempo,
    required this.defensiveLine,
    required this.intensity,
    required this.minuteCurrent,
    required this.periodLabel,
    required this.homeScore,
    required this.awayScore,
    required this.possessionHome,
    required this.possessionAway,
    required this.shotsHome,
    required this.shotsAway,
    required this.shotsOnTargetHome,
    required this.shotsOnTargetAway,
    required this.momentumHome,
    required this.momentumAway,
    required this.teamEnergy,
    required this.opponentEnergy,
    required this.status,
  });

  factory ManagerLiveMatchModel.fromJson(Map<String, dynamic> json) {
    return ManagerLiveMatchModel(
      id: int.tryParse(json['id'].toString()) ?? 0,
      teamId: int.tryParse(json['team_id'].toString()) ?? 0,
      userId: int.tryParse(json['user_id'].toString()) ?? 0,
      opponentName: (json['opponent_name'] ?? '').toString(),
      opponentStrength: int.tryParse(json['opponent_strength'].toString()) ?? 0,
      formationUsed: (json['formation_used'] ?? '').toString(),
      playStyle: (json['play_style'] ?? '').toString(),
      pressingLevel: (json['pressing_level'] ?? '').toString(),
      tempo: (json['tempo'] ?? '').toString(),
      defensiveLine: (json['defensive_line'] ?? '').toString(),
      intensity: (json['intensity'] ?? '').toString(),
      minuteCurrent: int.tryParse(json['minute_current'].toString()) ?? 0,
      periodLabel: (json['period_label'] ?? '').toString(),
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
      momentumHome: int.tryParse(json['momentum_home'].toString()) ?? 0,
      momentumAway: int.tryParse(json['momentum_away'].toString()) ?? 0,
      teamEnergy: int.tryParse(json['team_energy'].toString()) ?? 0,
      opponentEnergy: int.tryParse(json['opponent_energy'].toString()) ?? 0,
      status: (json['status'] ?? '').toString(),
    );
  }
}