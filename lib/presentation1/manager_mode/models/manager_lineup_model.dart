class ManagerLineupInfo {
  final int id;
  final int teamId;
  final String title;
  final String formation;
  final bool isActive;

  ManagerLineupInfo({
    required this.id,
    required this.teamId,
    required this.title,
    required this.formation,
    required this.isActive,
  });

  factory ManagerLineupInfo.fromJson(Map<String, dynamic> json) {
    return ManagerLineupInfo(
      id: int.tryParse(json['id'].toString()) ?? 0,
      teamId: int.tryParse(json['team_id'].toString()) ?? 0,
      title: (json['title'] ?? '').toString(),
      formation: (json['formation'] ?? '4-3-3').toString(),
      isActive:
          json['is_active'].toString() == '1' || json['is_active'] == true,
    );
  }
}

class ManagerLineupPlayer {
  final int playerId;
  final String fullName;
  final String position;
  final String playerNumber;
  final String birthDate;
  final String roleName;
  final String positionCode;
  final bool isStarting;
  final int formValue;
  final int fatigue;
  final int morale;
  final int readiness;
  final int injuryRisk;
  final int baseSkill;

  ManagerLineupPlayer({
    required this.playerId,
    required this.fullName,
    required this.position,
    required this.playerNumber,
    required this.birthDate,
    required this.roleName,
    required this.positionCode,
    required this.isStarting,
    required this.formValue,
    required this.fatigue,
    required this.morale,
    required this.readiness,
    required this.injuryRisk,
    required this.baseSkill,
  });

  factory ManagerLineupPlayer.fromJson(Map<String, dynamic> json) {
    return ManagerLineupPlayer(
      playerId: int.tryParse(json['player_id'].toString()) ?? 0,
      fullName: (json['full_name'] ?? '').toString(),
      position: (json['position'] ?? '').toString(),
      playerNumber: (json['player_number'] ?? '').toString(),
      birthDate: (json['birth_date'] ?? '').toString(),
      roleName: (json['role_name'] ?? '').toString(),
      positionCode: (json['position_code'] ?? '').toString(),
      isStarting:
          json['is_starting'] == true || json['is_starting'].toString() == '1',
      formValue: int.tryParse(json['form_value'].toString()) ?? 0,
      fatigue: int.tryParse(json['fatigue'].toString()) ?? 0,
      morale: int.tryParse(json['morale'].toString()) ?? 0,
      readiness: int.tryParse(json['readiness'].toString()) ?? 0,
      injuryRisk: int.tryParse(json['injury_risk'].toString()) ?? 0,
      baseSkill: int.tryParse(json['base_skill'].toString()) ?? 0,
    );
  }

  Map<String, dynamic> toJsonForSave() {
    return {
      'player_id': playerId,
      'role_name': roleName,
      'position_code': positionCode,
      'is_starting': isStarting,
    };
  }

  ManagerLineupPlayer copyWith({
    String? roleName,
    String? positionCode,
    bool? isStarting,
  }) {
    return ManagerLineupPlayer(
      playerId: playerId,
      fullName: fullName,
      position: position,
      playerNumber: playerNumber,
      birthDate: birthDate,
      roleName: roleName ?? this.roleName,
      positionCode: positionCode ?? this.positionCode,
      isStarting: isStarting ?? this.isStarting,
      formValue: formValue,
      fatigue: fatigue,
      morale: morale,
      readiness: readiness,
      injuryRisk: injuryRisk,
      baseSkill: baseSkill,
    );
  }
}

class ManagerLineupResponse {
  final ManagerLineupInfo lineup;
  final List<ManagerLineupPlayer> selectedPlayers;
  final List<ManagerLineupPlayer> allPlayers;

  ManagerLineupResponse({
    required this.lineup,
    required this.selectedPlayers,
    required this.allPlayers,
  });

  factory ManagerLineupResponse.fromJson(Map<String, dynamic> json) {
    return ManagerLineupResponse(
      lineup: ManagerLineupInfo.fromJson(
        Map<String, dynamic>.from(json['lineup'] ?? {}),
      ),
      selectedPlayers: (json['selected_players'] as List? ?? [])
          .map((e) => ManagerLineupPlayer.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      allPlayers: (json['all_players'] as List? ?? [])
          .map((e) => ManagerLineupPlayer.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}