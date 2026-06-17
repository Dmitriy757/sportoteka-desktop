class ManagerLiveMatchEventModel {
  final int id;
  final int minute;
  final String eventType;
  final String teamSide;
  final int? playerId;
  final String playerName;
  final String description;

  ManagerLiveMatchEventModel({
    required this.id,
    required this.minute,
    required this.eventType,
    required this.teamSide,
    required this.playerId,
    required this.playerName,
    required this.description,
  });

  factory ManagerLiveMatchEventModel.fromJson(Map<String, dynamic> json) {
    return ManagerLiveMatchEventModel(
      id: int.tryParse(json['id'].toString()) ?? 0,
      minute: int.tryParse(json['minute'].toString()) ?? 0,
      eventType: (json['event_type'] ?? '').toString(),
      teamSide: (json['team_side'] ?? '').toString(),
      playerId: json['player_id'] == null
          ? null
          : int.tryParse(json['player_id'].toString()),
      playerName: (json['player_name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
    );
  }
}