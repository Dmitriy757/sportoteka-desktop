class ManagerLiveMatchLineupModel {
  final int id;
  final int playerId;
  final String playerName;
  final String positionCode;
  final bool isStarting;
  final bool isOnField;
  final int minutesPlayed;
  final int energy;
  final double rating;
  final int goals;
  final int assists;
  final int yellowCards;
  final int redCards;

  ManagerLiveMatchLineupModel({
    required this.id,
    required this.playerId,
    required this.playerName,
    required this.positionCode,
    required this.isStarting,
    required this.isOnField,
    required this.minutesPlayed,
    required this.energy,
    required this.rating,
    required this.goals,
    required this.assists,
    required this.yellowCards,
    required this.redCards,
  });

  factory ManagerLiveMatchLineupModel.fromJson(Map<String, dynamic> json) {
    return ManagerLiveMatchLineupModel(
      id: int.tryParse(json['id'].toString()) ?? 0,
      playerId: int.tryParse(json['player_id'].toString()) ?? 0,
      playerName: (json['player_name'] ?? '').toString(),
      positionCode: (json['position_code'] ?? '').toString(),
      isStarting:
          json['is_starting'] == true || json['is_starting'].toString() == '1',
      isOnField:
          json['is_on_field'] == true || json['is_on_field'].toString() == '1',
      minutesPlayed: int.tryParse(json['minutes_played'].toString()) ?? 0,
      energy: int.tryParse(json['energy'].toString()) ?? 0,
      rating: double.tryParse(json['rating'].toString()) ?? 0,
      goals: int.tryParse(json['goals'].toString()) ?? 0,
      assists: int.tryParse(json['assists'].toString()) ?? 0,
      yellowCards: int.tryParse(json['yellow_cards'].toString()) ?? 0,
      redCards: int.tryParse(json['red_cards'].toString()) ?? 0,
    );
  }
}