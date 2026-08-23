class ManagerPlayerStateModel {
  final int playerId;
  final String fullName;
  final String position;
  final String playerNumber;
  final String birthDate;
  final String height;
  final String weight;
  final int formValue;
  final int fatigue;
  final int morale;
  final int readiness;
  final int injuryRisk;
  final int developmentProgress;
  final int matchSharpness;
  final int tacticalFit;
  final int baseSkill;

  ManagerPlayerStateModel({
    required this.playerId,
    required this.fullName,
    required this.position,
    required this.playerNumber,
    required this.birthDate,
    required this.height,
    required this.weight,
    required this.formValue,
    required this.fatigue,
    required this.morale,
    required this.readiness,
    required this.injuryRisk,
    required this.developmentProgress,
    required this.matchSharpness,
    required this.tacticalFit,
    required this.baseSkill,
  });

  factory ManagerPlayerStateModel.fromJson(Map<String, dynamic> json) {
    return ManagerPlayerStateModel(
      playerId: int.tryParse(json['player_id'].toString()) ?? 0,
      fullName: (json['full_name'] ?? '').toString(),
      position: (json['position'] ?? '').toString(),
      playerNumber: (json['player_number'] ?? '').toString(),
      birthDate: (json['birth_date'] ?? '').toString(),
      height: (json['height'] ?? '').toString(),
      weight: (json['weight'] ?? '').toString(),
      formValue: int.tryParse(json['form_value'].toString()) ?? 0,
      fatigue: int.tryParse(json['fatigue'].toString()) ?? 0,
      morale: int.tryParse(json['morale'].toString()) ?? 0,
      readiness: int.tryParse(json['readiness'].toString()) ?? 0,
      injuryRisk: int.tryParse(json['injury_risk'].toString()) ?? 0,
      developmentProgress:
          int.tryParse(json['development_progress'].toString()) ?? 0,
      matchSharpness: int.tryParse(json['match_sharpness'].toString()) ?? 0,
      tacticalFit: int.tryParse(json['tactical_fit'].toString()) ?? 0,
      baseSkill: int.tryParse(json['base_skill'].toString()) ?? 0,
    );
  }
}