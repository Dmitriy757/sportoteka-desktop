class ManagerTopPlayer {
  final int id;
  final String fullName;
  final String position;
  final int formValue;
  final int fatigue;
  final int morale;
  final int readiness;
  final int injuryRisk;
  final int baseSkill;

  ManagerTopPlayer({
    required this.id,
    required this.fullName,
    required this.position,
    required this.formValue,
    required this.fatigue,
    required this.morale,
    required this.readiness,
    required this.injuryRisk,
    required this.baseSkill,
  });

  factory ManagerTopPlayer.fromJson(Map<String, dynamic> json) {
    return ManagerTopPlayer(
      id: int.tryParse(json['id'].toString()) ?? 0,
      fullName: (json['full_name'] ?? '').toString(),
      position: (json['position'] ?? '').toString(),
      formValue: int.tryParse(json['form_value'].toString()) ?? 0,
      fatigue: int.tryParse(json['fatigue'].toString()) ?? 0,
      morale: int.tryParse(json['morale'].toString()) ?? 0,
      readiness: int.tryParse(json['readiness'].toString()) ?? 0,
      injuryRisk: int.tryParse(json['injury_risk'].toString()) ?? 0,
      baseSkill: int.tryParse(json['base_skill'].toString()) ?? 0,
    );
  }
}

class ManagerTeamState {
  final int teamForm;
  final int teamMorale;
  final int teamFitness;
  final int tacticalFamiliarity;
  final int injuriesCount;
  final String? nextMatchOpponent;
  final String? nextMatchDate;

  ManagerTeamState({
    required this.teamForm,
    required this.teamMorale,
    required this.teamFitness,
    required this.tacticalFamiliarity,
    required this.injuriesCount,
    this.nextMatchOpponent,
    this.nextMatchDate,
  });

  factory ManagerTeamState.fromJson(Map<String, dynamic> json) {
    return ManagerTeamState(
      teamForm: int.tryParse(json['team_form'].toString()) ?? 50,
      teamMorale: int.tryParse(json['team_morale'].toString()) ?? 50,
      teamFitness: int.tryParse(json['team_fitness'].toString()) ?? 50,
      tacticalFamiliarity:
          int.tryParse(json['tactical_familiarity'].toString()) ?? 50,
      injuriesCount: int.tryParse(json['injuries_count'].toString()) ?? 0,
      nextMatchOpponent: json['next_match_opponent']?.toString(),
      nextMatchDate: json['next_match_date']?.toString(),
    );
  }
}

class ManagerTactics {
  final String formation;
  final String playStyle;
  final String pressingLevel;
  final String tempo;
  final String defensiveLine;
  final String intensity;

  ManagerTactics({
    required this.formation,
    required this.playStyle,
    required this.pressingLevel,
    required this.tempo,
    required this.defensiveLine,
    required this.intensity,
  });

  factory ManagerTactics.fromJson(Map<String, dynamic> json) {
    return ManagerTactics(
      formation: (json['formation'] ?? '4-3-3').toString(),
      playStyle: (json['play_style'] ?? 'balanced').toString(),
      pressingLevel: (json['pressing_level'] ?? 'medium').toString(),
      tempo: (json['tempo'] ?? 'medium').toString(),
      defensiveLine: (json['defensive_line'] ?? 'medium').toString(),
      intensity: (json['intensity'] ?? 'medium').toString(),
    );
  }
}

class ManagerTeamOverviewModel {
  final ManagerTeamState teamState;
  final ManagerTactics tactics;
  final List<ManagerTopPlayer> topPlayers;

  ManagerTeamOverviewModel({
    required this.teamState,
    required this.tactics,
    required this.topPlayers,
  });

  factory ManagerTeamOverviewModel.fromJson(Map<String, dynamic> json) {
    return ManagerTeamOverviewModel(
      teamState: ManagerTeamState.fromJson(
        Map<String, dynamic>.from(json['team_state'] ?? {}),
      ),
      tactics: ManagerTactics.fromJson(
        Map<String, dynamic>.from(json['tactics'] ?? {}),
      ),
      topPlayers: (json['top_players'] as List? ?? [])
          .map((e) => ManagerTopPlayer.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}