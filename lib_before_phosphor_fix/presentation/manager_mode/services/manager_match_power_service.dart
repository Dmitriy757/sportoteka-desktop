import '../models/manager_player_ttd_profile_model.dart';

class ManagerMatchPowerBreakdown {
  final double overallPower;
  final double attackImpact;
  final double creationImpact;
  final double defenseImpact;
  final double controlImpact;
  final double aerialImpact;
  final double goalkeeperImpact;

  const ManagerMatchPowerBreakdown({
    required this.overallPower,
    required this.attackImpact,
    required this.creationImpact,
    required this.defenseImpact,
    required this.controlImpact,
    required this.aerialImpact,
    required this.goalkeeperImpact,
  });
}

class ManagerMatchPowerService {
  static double _clamp100(double value) {
    if (value.isNaN || value.isInfinite) return 0;
    return value.clamp(0, 100).toDouble();
  }

  static String normalizeRole(String raw) {
    final value = raw.trim().toLowerCase();

    if (value.isEmpty) return 'unknown';

    if (value.contains('gk') ||
        value.contains('goal') ||
        value.contains('keeper') ||
        value.contains('врат')) {
      return 'gk';
    }

    if (value.contains('def') ||
        value.contains('cb') ||
        value.contains('lb') ||
        value.contains('rb') ||
        value.contains('back') ||
        value.contains('защ')) {
      return 'def';
    }

    if (value.contains('mid') ||
        value.contains('cm') ||
        value.contains('dm') ||
        value.contains('am') ||
        value.contains('wing') ||
        value.contains('пол')) {
      return 'mid';
    }

    if (value.contains('fwd') ||
        value.contains('fw') ||
        value.contains('st') ||
        value.contains('striker') ||
        value.contains('forward') ||
        value.contains('нап')) {
      return 'fwd';
    }

    return value;
  }

  static double _freshnessFromFatigue(int fatigue) {
    return _clamp100(100 - fatigue.toDouble());
  }

  static double _mentalFactor({
    required int form,
    required int morale,
    required int fatigue,
  }) {
    final freshness = _freshnessFromFatigue(fatigue);

    return _clamp100(
      (form * 0.45) +
          (morale * 0.30) +
          (freshness * 0.25),
    );
  }

  static double _baseContextBoost({
    required int form,
    required int morale,
    required int fatigue,
    required int readiness,
    required int tacticalFit,
  }) {
    final freshness = _freshnessFromFatigue(fatigue);

    return _clamp100(
      (form * 0.22) +
          (morale * 0.14) +
          (freshness * 0.18) +
          (readiness * 0.28) +
          (tacticalFit * 0.18),
    );
  }

  static ManagerMatchPowerBreakdown calculateForRole({
    required ManagerPlayerTtdProfileModel profile,
    required String roleOrPosition,
    required int form,
    required int morale,
    required int fatigue,
    required int readiness,
    required int tacticalFit,
  }) {
    final role = normalizeRole(roleOrPosition);
    final context = _baseContextBoost(
      form: form,
      morale: morale,
      fatigue: fatigue,
      readiness: readiness,
      tacticalFit: tacticalFit,
    );

    final mental = _mentalFactor(
      form: form,
      morale: morale,
      fatigue: fatigue,
    );

    double attackImpact = 0;
    double creationImpact = 0;
    double defenseImpact = 0;
    double controlImpact = 0;
    double aerialImpact = 0;
    double goalkeeperImpact = 0;
    double overall = 0;

    if (role == 'gk' || profile.groupKey == 'gk') {
      goalkeeperImpact = _clamp100(
        (profile.goalkeeperShotStopping * 0.55) +
            (profile.goalkeeperDistribution * 0.25) +
            (profile.goalkeeperSweeper * 0.20),
      );

      controlImpact = _clamp100(
        (profile.goalkeeperDistribution * 0.50) +
            (profile.efficiencyRating * 0.25) +
            (mental * 0.25),
      );

      defenseImpact = _clamp100(
        (profile.goalkeeperShotStopping * 0.60) +
            (profile.goalkeeperSweeper * 0.25) +
            (mental * 0.15),
      );

      overall = _clamp100(
        (goalkeeperImpact * 0.52) +
            (defenseImpact * 0.20) +
            (controlImpact * 0.08) +
            (context * 0.20),
      );
    } else if (role == 'def') {
      defenseImpact = _clamp100(
        (profile.defenseRating * 0.48) +
            (profile.aerialRating * 0.18) +
            (profile.activityRating * 0.12) +
            (profile.efficiencyRating * 0.10) +
            (mental * 0.12),
      );

      controlImpact = _clamp100(
        (profile.passingRating * 0.42) +
            (profile.sidePassBias * 0.10) +
            (profile.backPassBias * 0.12) +
            (profile.efficiencyRating * 0.12) +
            (mental * 0.24),
      );

      creationImpact = _clamp100(
        (profile.passingRating * 0.40) +
            (profile.forwardPassBias * 0.18) +
            (profile.mediumPassRating * 0.18) +
            (mental * 0.24),
      );

      aerialImpact = _clamp100(
        (profile.aerialRating * 0.75) +
            (profile.activityRating * 0.10) +
            (mental * 0.15),
      );

      attackImpact = _clamp100(
        (profile.attackRating * 0.25) +
            (profile.aerialRating * 0.25) +
            (profile.passingRating * 0.20) +
            (mental * 0.30),
      );

      overall = _clamp100(
        (defenseImpact * 0.38) +
            (controlImpact * 0.18) +
            (creationImpact * 0.14) +
            (aerialImpact * 0.12) +
            (attackImpact * 0.04) +
            (context * 0.14),
      );
    } else if (role == 'mid') {
      creationImpact = _clamp100(
        (profile.passingRating * 0.40) +
            (profile.forwardPassBias * 0.16) +
            (profile.mediumPassRating * 0.14) +
            (profile.efficiencyRating * 0.10) +
            (mental * 0.20),
      );

      controlImpact = _clamp100(
        (profile.passingRating * 0.34) +
            (profile.sidePassBias * 0.14) +
            (profile.shortPassRating * 0.16) +
            (profile.activityRating * 0.12) +
            (mental * 0.24),
      );

      defenseImpact = _clamp100(
        (profile.defenseRating * 0.34) +
            (profile.activityRating * 0.18) +
            (profile.efficiencyRating * 0.12) +
            (mental * 0.18) +
            (profile.aerialRating * 0.18),
      );

      attackImpact = _clamp100(
        (profile.attackRating * 0.34) +
            (profile.passingRating * 0.20) +
            (profile.efficiencyRating * 0.12) +
            (mental * 0.20) +
            (profile.activityRating * 0.14),
      );

      aerialImpact = _clamp100(
        (profile.aerialRating * 0.70) +
            (mental * 0.15) +
            (profile.activityRating * 0.15),
      );

      overall = _clamp100(
        (creationImpact * 0.24) +
            (controlImpact * 0.24) +
            (defenseImpact * 0.18) +
            (attackImpact * 0.16) +
            (aerialImpact * 0.04) +
            (context * 0.14),
      );
    } else {
      attackImpact = _clamp100(
        (profile.attackRating * 0.44) +
            (profile.efficiencyRating * 0.12) +
            (profile.activityRating * 0.12) +
            (profile.aerialRating * 0.12) +
            (mental * 0.20),
      );

      creationImpact = _clamp100(
        (profile.passingRating * 0.28) +
            (profile.forwardPassBias * 0.18) +
            (profile.mediumPassRating * 0.10) +
            (profile.attackRating * 0.18) +
            (mental * 0.26),
      );

      controlImpact = _clamp100(
        (profile.passingRating * 0.30) +
            (profile.shortPassRating * 0.16) +
            (profile.activityRating * 0.18) +
            (mental * 0.20) +
            (profile.efficiencyRating * 0.16),
      );

      defenseImpact = _clamp100(
        (profile.defenseRating * 0.32) +
            (profile.activityRating * 0.18) +
            (mental * 0.18) +
            (profile.aerialRating * 0.16) +
            (profile.efficiencyRating * 0.16),
      );

      aerialImpact = _clamp100(
        (profile.aerialRating * 0.78) +
            (mental * 0.12) +
            (profile.attackRating * 0.10),
      );

      overall = _clamp100(
        (attackImpact * 0.34) +
            (creationImpact * 0.18) +
            (controlImpact * 0.14) +
            (defenseImpact * 0.10) +
            (aerialImpact * 0.08) +
            (context * 0.16),
      );
    }

    return ManagerMatchPowerBreakdown(
      overallPower: overall,
      attackImpact: attackImpact,
      creationImpact: creationImpact,
      defenseImpact: defenseImpact,
      controlImpact: controlImpact,
      aerialImpact: aerialImpact,
      goalkeeperImpact: goalkeeperImpact,
    );
  }

  static double calculateOverallPower({
    required ManagerPlayerTtdProfileModel profile,
    required String roleOrPosition,
    required int form,
    required int morale,
    required int fatigue,
    required int readiness,
    required int tacticalFit,
  }) {
    return calculateForRole(
      profile: profile,
      roleOrPosition: roleOrPosition,
      form: form,
      morale: morale,
      fatigue: fatigue,
      readiness: readiness,
      tacticalFit: tacticalFit,
    ).overallPower;
  }

  static double calculateAttackPotential({
    required ManagerPlayerTtdProfileModel profile,
    required String roleOrPosition,
    required int form,
    required int morale,
    required int fatigue,
    required int readiness,
    required int tacticalFit,
  }) {
    return calculateForRole(
      profile: profile,
      roleOrPosition: roleOrPosition,
      form: form,
      morale: morale,
      fatigue: fatigue,
      readiness: readiness,
      tacticalFit: tacticalFit,
    ).attackImpact;
  }

  static double calculateCreationPotential({
    required ManagerPlayerTtdProfileModel profile,
    required String roleOrPosition,
    required int form,
    required int morale,
    required int fatigue,
    required int readiness,
    required int tacticalFit,
  }) {
    return calculateForRole(
      profile: profile,
      roleOrPosition: roleOrPosition,
      form: form,
      morale: morale,
      fatigue: fatigue,
      readiness: readiness,
      tacticalFit: tacticalFit,
    ).creationImpact;
  }

  static double calculateDefensePotential({
    required ManagerPlayerTtdProfileModel profile,
    required String roleOrPosition,
    required int form,
    required int morale,
    required int fatigue,
    required int readiness,
    required int tacticalFit,
  }) {
    return calculateForRole(
      profile: profile,
      roleOrPosition: roleOrPosition,
      form: form,
      morale: morale,
      fatigue: fatigue,
      readiness: readiness,
      tacticalFit: tacticalFit,
    ).defenseImpact;
  }

  static double calculateControlPotential({
    required ManagerPlayerTtdProfileModel profile,
    required String roleOrPosition,
    required int form,
    required int morale,
    required int fatigue,
    required int readiness,
    required int tacticalFit,
  }) {
    return calculateForRole(
      profile: profile,
      roleOrPosition: roleOrPosition,
      form: form,
      morale: morale,
      fatigue: fatigue,
      readiness: readiness,
      tacticalFit: tacticalFit,
    ).controlImpact;
  }

  static double calculateGoalkeeperPotential({
    required ManagerPlayerTtdProfileModel profile,
    required int form,
    required int morale,
    required int fatigue,
    required int readiness,
    required int tacticalFit,
  }) {
    return calculateForRole(
      profile: profile,
      roleOrPosition: 'gk',
      form: form,
      morale: morale,
      fatigue: fatigue,
      readiness: readiness,
      tacticalFit: tacticalFit,
    ).goalkeeperImpact;
  }

  static double calculateTeamUnitStrength({
    required List<ManagerMatchPowerBreakdown> players,
    required String unit,
  }) {
    if (players.isEmpty) return 0;

    double sum = 0;

    for (final p in players) {
      switch (unit) {
        case 'attack':
          sum += p.attackImpact;
          break;
        case 'creation':
          sum += p.creationImpact;
          break;
        case 'defense':
          sum += p.defenseImpact;
          break;
        case 'control':
          sum += p.controlImpact;
          break;
        case 'aerial':
          sum += p.aerialImpact;
          break;
        case 'goalkeeper':
          sum += p.goalkeeperImpact;
          break;
        default:
          sum += p.overallPower;
      }
    }

    return _clamp100(sum / players.length);
  }
}