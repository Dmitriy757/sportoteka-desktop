import 'dart:math' as math;

import '../models/manager_player_ttd_profile_model.dart';
import 'manager_match_power_service.dart';

class ManagerEnginePlayerInput {
  final int playerId;
  final String playerName;
  final String position;
  final bool isGoalkeeper;
  final int formValue;
  final int morale;
  final int fatigue;
  final int readiness;
  final int tacticalFit;
  final bool isOnField;

  const ManagerEnginePlayerInput({
    required this.playerId,
    required this.playerName,
    required this.position,
    required this.isGoalkeeper,
    required this.formValue,
    required this.morale,
    required this.fatigue,
    required this.readiness,
    required this.tacticalFit,
    required this.isOnField,
  });
}

class ManagerEngineTacticsInput {
  final String formation;
  final String playStyle;
  final String pressingLevel;
  final String tempo;
  final String defensiveLine;
  final String intensity;

  const ManagerEngineTacticsInput({
    required this.formation,
    required this.playStyle,
    required this.pressingLevel,
    required this.tempo,
    required this.defensiveLine,
    required this.intensity,
  });
}

class ManagerEngineTeamStateInput {
  final int teamForm;
  final int teamMorale;
  final int teamFitness;
  final int tacticalFamiliarity;

  const ManagerEngineTeamStateInput({
    required this.teamForm,
    required this.teamMorale,
    required this.teamFitness,
    required this.tacticalFamiliarity,
  });
}

class ManagerEngineTeamSnapshot {
  final double overallStrength;
  final double attackStrength;
  final double creationStrength;
  final double defenseStrength;
  final double controlStrength;
  final double aerialStrength;
  final double goalkeeperStrength;
  final double averageEnergy;
  final double averageReadiness;
  final double tacticalBonus;
  final double mentalityBonus;
  final List<ManagerMatchPowerBreakdown> playerBreakdowns;

  const ManagerEngineTeamSnapshot({
    required this.overallStrength,
    required this.attackStrength,
    required this.creationStrength,
    required this.defenseStrength,
    required this.controlStrength,
    required this.aerialStrength,
    required this.goalkeeperStrength,
    required this.averageEnergy,
    required this.averageReadiness,
    required this.tacticalBonus,
    required this.mentalityBonus,
    required this.playerBreakdowns,
  });
}

class ManagerEngineStepResult {
  final int homeMomentumDelta;
  final int awayMomentumDelta;
  final int predictedHomePossession;
  final int predictedAwayPossession;

  final double homeShotProbability;
  final double awayShotProbability;

  final double homeShotOnTargetProbability;
  final double awayShotOnTargetProbability;

  final double homeGoalProbability;
  final double awayGoalProbability;

  final double homeDangerIndex;
  final double awayDangerIndex;

  const ManagerEngineStepResult({
    required this.homeMomentumDelta,
    required this.awayMomentumDelta,
    required this.predictedHomePossession,
    required this.predictedAwayPossession,
    required this.homeShotProbability,
    required this.awayShotProbability,
    required this.homeShotOnTargetProbability,
    required this.awayShotOnTargetProbability,
    required this.homeGoalProbability,
    required this.awayGoalProbability,
    required this.homeDangerIndex,
    required this.awayDangerIndex,
  });
}

class ManagerMatchEngineService {
  static double _clamp(double value, double min, double max) {
    if (value.isNaN || value.isInfinite) return min;
    return value.clamp(min, max).toDouble();
  }

  static double _avg(Iterable<double> values) {
    if (values.isEmpty) return 0;
    final list = values.toList();
    return list.reduce((a, b) => a + b) / list.length;
  }

  static double _freshnessFromFatigue(int fatigue) {
    return _clamp(100 - fatigue.toDouble(), 0, 100);
  }

  static String _normalize(String value) => value.trim().toLowerCase();

  static double _teamMentalityBonus(ManagerEngineTeamStateInput state) {
    return _clamp(
      (state.teamForm * 0.35) +
          (state.teamMorale * 0.35) +
          (state.teamFitness * 0.15) +
          (state.tacticalFamiliarity * 0.15),
      0,
      100,
    );
  }

  static double _tacticsAttackBonus(ManagerEngineTacticsInput tactics) {
    final style = _normalize(tactics.playStyle);
    final tempo = _normalize(tactics.tempo);
    final intensity = _normalize(tactics.intensity);

    double bonus = 0;

    if (style == 'high_press') bonus += 7;
    if (style == 'possession') bonus += 5;
    if (style == 'counter_attack') bonus += 6;
    if (style == 'balanced') bonus += 3;

    if (tempo == 'high') bonus += 6;
    if (tempo == 'medium') bonus += 3;
    if (tempo == 'low') bonus -= 2;

    if (intensity == 'high') bonus += 5;
    if (intensity == 'medium') bonus += 2;
    if (intensity == 'low') bonus -= 2;

    return _clamp(bonus, -10, 18);
  }

  static double _tacticsControlBonus(ManagerEngineTacticsInput tactics) {
    final style = _normalize(tactics.playStyle);
    final tempo = _normalize(tactics.tempo);
    final line = _normalize(tactics.defensiveLine);

    double bonus = 0;

    if (style == 'possession') bonus += 8;
    if (style == 'balanced') bonus += 4;
    if (style == 'counter_attack') bonus -= 2;

    if (tempo == 'low') bonus += 5;
    if (tempo == 'medium') bonus += 2;
    if (tempo == 'high') bonus -= 2;

    if (line == 'high') bonus += 2;
    if (line == 'medium') bonus += 1;

    return _clamp(bonus, -8, 15);
  }

  static double _tacticsDefenseBonus(ManagerEngineTacticsInput tactics) {
    final pressing = _normalize(tactics.pressingLevel);
    final line = _normalize(tactics.defensiveLine);
    final intensity = _normalize(tactics.intensity);

    double bonus = 0;

    if (pressing == 'high') bonus += 5;
    if (pressing == 'medium') bonus += 2;
    if (pressing == 'low') bonus -= 1;

    if (line == 'low') bonus += 6;
    if (line == 'medium') bonus += 3;
    if (line == 'high') bonus -= 2;

    if (intensity == 'high') bonus += 3;
    if (intensity == 'low') bonus -= 1;

    return _clamp(bonus, -6, 15);
  }

  static ManagerEngineTeamSnapshot buildTeamSnapshot({
    required List<ManagerEnginePlayerInput> players,
    required List<ManagerPlayerTtdProfileModel> profiles,
    required ManagerEngineTacticsInput tactics,
    required ManagerEngineTeamStateInput teamState,
  }) {
    final onField = players.where((p) => p.isOnField).toList();

    final breakdowns = <ManagerMatchPowerBreakdown>[];
    final energies = <double>[];
    final readinessValues = <double>[];

    for (final player in onField) {
      final profile = profiles.cast<ManagerPlayerTtdProfileModel?>().firstWhere(
            (p) => p?.playerId == player.playerId,
            orElse: () => null,
          );

      if (profile == null) continue;

      final breakdown = ManagerMatchPowerService.calculateForRole(
        profile: profile,
        roleOrPosition: player.position,
        form: player.formValue,
        morale: player.morale,
        fatigue: player.fatigue,
        readiness: player.readiness,
        tacticalFit: player.tacticalFit,
      );

      breakdowns.add(breakdown);
      energies.add(_freshnessFromFatigue(player.fatigue));
      readinessValues.add(player.readiness.toDouble());
    }

    final tacticalBonus = _clamp(
      _tacticsAttackBonus(tactics) * 0.35 +
          _tacticsControlBonus(tactics) * 0.30 +
          _tacticsDefenseBonus(tactics) * 0.35,
      -10,
      16,
    );

    final mentalityBonus = _teamMentalityBonus(teamState);

    final attackStrength = _clamp(
      ManagerMatchPowerService.calculateTeamUnitStrength(
            players: breakdowns,
            unit: 'attack',
          ) +
          _tacticsAttackBonus(tactics) +
          ((teamState.teamForm - 50) * 0.12),
      1,
      100,
    );

    final creationStrength = _clamp(
      ManagerMatchPowerService.calculateTeamUnitStrength(
            players: breakdowns,
            unit: 'creation',
          ) +
          _tacticsControlBonus(tactics) * 0.45 +
          ((teamState.tacticalFamiliarity - 50) * 0.16),
      1,
      100,
    );

    final defenseStrength = _clamp(
      ManagerMatchPowerService.calculateTeamUnitStrength(
            players: breakdowns,
            unit: 'defense',
          ) +
          _tacticsDefenseBonus(tactics) +
          ((teamState.teamFitness - 50) * 0.10),
      1,
      100,
    );

    final controlStrength = _clamp(
      ManagerMatchPowerService.calculateTeamUnitStrength(
            players: breakdowns,
            unit: 'control',
          ) +
          _tacticsControlBonus(tactics) +
          ((teamState.tacticalFamiliarity - 50) * 0.14),
      1,
      100,
    );

    final aerialStrength = _clamp(
      ManagerMatchPowerService.calculateTeamUnitStrength(
        players: breakdowns,
        unit: 'aerial',
      ),
      1,
      100,
    );

    final goalkeeperStrength = _clamp(
      ManagerMatchPowerService.calculateTeamUnitStrength(
            players: breakdowns,
            unit: 'goalkeeper',
          ) +
          ((teamState.teamMorale - 50) * 0.05),
      1,
      100,
    );

    final averageEnergy = _avg(energies);
    final averageReadiness = _avg(readinessValues);

    final overallStrength = _clamp(
      (attackStrength * 0.22) +
          (creationStrength * 0.18) +
          (defenseStrength * 0.24) +
          (controlStrength * 0.16) +
          (goalkeeperStrength * 0.12) +
          (averageEnergy * 0.04) +
          (averageReadiness * 0.04),
      1,
      100,
    );

    return ManagerEngineTeamSnapshot(
      overallStrength: overallStrength,
      attackStrength: attackStrength,
      creationStrength: creationStrength,
      defenseStrength: defenseStrength,
      controlStrength: controlStrength,
      aerialStrength: aerialStrength,
      goalkeeperStrength: goalkeeperStrength,
      averageEnergy: averageEnergy,
      averageReadiness: averageReadiness,
      tacticalBonus: tacticalBonus,
      mentalityBonus: mentalityBonus,
      playerBreakdowns: breakdowns,
    );
  }

  static ManagerEngineStepResult evaluateStep({
    required ManagerEngineTeamSnapshot home,
    required ManagerEngineTeamSnapshot away,
    required int currentMomentumHome,
    required int currentMomentumAway,
    required int currentPossessionHome,
    required int currentPossessionAway,
  }) {
    final homePressureIndex = _clamp(
      (home.attackStrength * 0.34) +
          (home.creationStrength * 0.24) +
          (home.controlStrength * 0.16) +
          (home.tacticalBonus * 0.14) +
          (home.averageEnergy * 0.06) +
          (home.mentalityBonus * 0.06),
      1,
      100,
    );

    final awayResistanceIndex = _clamp(
      (away.defenseStrength * 0.42) +
          (away.goalkeeperStrength * 0.22) +
          (away.controlStrength * 0.14) +
          (away.tacticalBonus * 0.10) +
          (away.averageEnergy * 0.06) +
          (away.mentalityBonus * 0.06),
      1,
      100,
    );

    final awayPressureIndex = _clamp(
      (away.attackStrength * 0.34) +
          (away.creationStrength * 0.24) +
          (away.controlStrength * 0.16) +
          (away.tacticalBonus * 0.14) +
          (away.averageEnergy * 0.06) +
          (away.mentalityBonus * 0.06),
      1,
      100,
    );

    final homeResistanceIndex = _clamp(
      (home.defenseStrength * 0.42) +
          (home.goalkeeperStrength * 0.22) +
          (home.controlStrength * 0.14) +
          (home.tacticalBonus * 0.10) +
          (home.averageEnergy * 0.06) +
          (home.mentalityBonus * 0.06),
      1,
      100,
    );

    final homeDangerIndex = _clamp(
      homePressureIndex - (awayResistanceIndex * 0.72) + 36,
      1,
      100,
    );

    final awayDangerIndex = _clamp(
      awayPressureIndex - (homeResistanceIndex * 0.72) + 36,
      1,
      100,
    );

    final homeMomentumDelta = _clamp(
      ((home.controlStrength - away.controlStrength) * 0.18) +
          ((home.attackStrength - away.defenseStrength) * 0.12) +
          ((currentMomentumHome - currentMomentumAway) * 0.06),
      -12,
      12,
    ).round();

    final awayMomentumDelta = -homeMomentumDelta;

    final predictedHomePossession = _clamp(
      currentPossessionHome +
          ((home.controlStrength - away.controlStrength) * 0.16) +
          ((home.creationStrength - away.creationStrength) * 0.08),
      35,
      65,
    ).round();

    final predictedAwayPossession = 100 - predictedHomePossession;

    final homeShotProbability = _clamp(
      0.08 +
          (homeDangerIndex / 100 * 0.42) +
          (predictedHomePossession / 100 * 0.10),
      0.05,
      0.72,
    );

    final awayShotProbability = _clamp(
      0.08 +
          (awayDangerIndex / 100 * 0.42) +
          (predictedAwayPossession / 100 * 0.10),
      0.05,
      0.72,
    );

    final homeShotOnTargetProbability = _clamp(
      0.18 +
          (home.attackStrength / 100 * 0.24) +
          (home.creationStrength / 100 * 0.12) -
          (away.goalkeeperStrength / 100 * 0.10),
      0.12,
      0.70,
    );

    final awayShotOnTargetProbability = _clamp(
      0.18 +
          (away.attackStrength / 100 * 0.24) +
          (away.creationStrength / 100 * 0.12) -
          (home.goalkeeperStrength / 100 * 0.10),
      0.12,
      0.70,
    );

    final homeGoalProbability = _clamp(
      0.06 +
          (home.attackStrength / 100 * 0.18) +
          (home.creationStrength / 100 * 0.08) +
          (home.aerialStrength / 100 * 0.04) -
          (away.goalkeeperStrength / 100 * 0.10) -
          (away.defenseStrength / 100 * 0.08),
      0.03,
      0.42,
    );

    final awayGoalProbability = _clamp(
      0.06 +
          (away.attackStrength / 100 * 0.18) +
          (away.creationStrength / 100 * 0.08) +
          (away.aerialStrength / 100 * 0.04) -
          (home.goalkeeperStrength / 100 * 0.10) -
          (home.defenseStrength / 100 * 0.08),
      0.03,
      0.42,
    );

    return ManagerEngineStepResult(
      homeMomentumDelta: homeMomentumDelta,
      awayMomentumDelta: awayMomentumDelta,
      predictedHomePossession: predictedHomePossession,
      predictedAwayPossession: predictedAwayPossession,
      homeShotProbability: homeShotProbability,
      awayShotProbability: awayShotProbability,
      homeShotOnTargetProbability: homeShotOnTargetProbability,
      awayShotOnTargetProbability: awayShotOnTargetProbability,
      homeGoalProbability: homeGoalProbability,
      awayGoalProbability: awayGoalProbability,
      homeDangerIndex: homeDangerIndex,
      awayDangerIndex: awayDangerIndex,
    );
  }

  static bool roll(math.Random random, double probability) {
    final p = _clamp(probability, 0, 1);
    return random.nextDouble() <= p;
  }

  static int rollRange(math.Random random, int min, int max) {
    if (max <= min) return min;
    return min + random.nextInt((max - min) + 1);
  }
}