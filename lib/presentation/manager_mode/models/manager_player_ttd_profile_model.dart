class ManagerPlayerTtdProfileModel {
  final int playerId;
  final String playerName;
  final String groupKey;

  final double attackRating;
  final double passingRating;
  final double defenseRating;
  final double aerialRating;
  final double activityRating;
  final double efficiencyRating;

  final double shortPassRating;
  final double mediumPassRating;
  final double longPassRating;

  final double forwardPassBias;
  final double sidePassBias;
  final double backPassBias;

  final double goalkeeperShotStopping;
  final double goalkeeperDistribution;
  final double goalkeeperSweeper;

  const ManagerPlayerTtdProfileModel({
    required this.playerId,
    required this.playerName,
    required this.groupKey,
    required this.attackRating,
    required this.passingRating,
    required this.defenseRating,
    required this.aerialRating,
    required this.activityRating,
    required this.efficiencyRating,
    required this.shortPassRating,
    required this.mediumPassRating,
    required this.longPassRating,
    required this.forwardPassBias,
    required this.sidePassBias,
    required this.backPassBias,
    required this.goalkeeperShotStopping,
    required this.goalkeeperDistribution,
    required this.goalkeeperSweeper,
  });

  double get overallRating {
    if (groupKey == 'gk') {
      return ((goalkeeperShotStopping * 0.45) +
              (goalkeeperDistribution * 0.30) +
              (goalkeeperSweeper * 0.25))
          .clamp(1, 100);
    }

    return ((attackRating * 0.22) +
            (passingRating * 0.22) +
            (defenseRating * 0.22) +
            (aerialRating * 0.10) +
            (activityRating * 0.12) +
            (efficiencyRating * 0.12))
        .clamp(1, 100);
  }

  Map<String, dynamic> toJson() {
    return {
      'player_id': playerId,
      'player_name': playerName,
      'group_key': groupKey,
      'attack_rating': attackRating,
      'passing_rating': passingRating,
      'defense_rating': defenseRating,
      'aerial_rating': aerialRating,
      'activity_rating': activityRating,
      'efficiency_rating': efficiencyRating,
      'short_pass_rating': shortPassRating,
      'medium_pass_rating': mediumPassRating,
      'long_pass_rating': longPassRating,
      'forward_pass_bias': forwardPassBias,
      'side_pass_bias': sidePassBias,
      'back_pass_bias': backPassBias,
      'goalkeeper_shot_stopping': goalkeeperShotStopping,
      'goalkeeper_distribution': goalkeeperDistribution,
      'goalkeeper_sweeper': goalkeeperSweeper,
      'overall_rating': overallRating,
    };
  }
}