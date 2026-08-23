import 'manager_match_engine_service.dart';

class ManagerInstructionAdjustedStepResult {
  final ManagerEngineStepResult step;
  final int teamEnergyDelta;
  final String? appliedInstructionCode;

  const ManagerInstructionAdjustedStepResult({
    required this.step,
    required this.teamEnergyDelta,
    required this.appliedInstructionCode,
  });
}

class ManagerInstructionImpactService {
  static double _clamp(double value, double min, double max) {
    if (value.isNaN || value.isInfinite) return min;
    return value.clamp(min, max).toDouble();
  }

  static ManagerEngineStepResult _copyStep(
    ManagerEngineStepResult step, {
    int? homeMomentumDelta,
    int? awayMomentumDelta,
    int? predictedHomePossession,
    int? predictedAwayPossession,
    double? homeShotProbability,
    double? awayShotProbability,
    double? homeShotOnTargetProbability,
    double? awayShotOnTargetProbability,
    double? homeGoalProbability,
    double? awayGoalProbability,
    double? homeDangerIndex,
    double? awayDangerIndex,
  }) {
    return ManagerEngineStepResult(
      homeMomentumDelta: homeMomentumDelta ?? step.homeMomentumDelta,
      awayMomentumDelta: awayMomentumDelta ?? step.awayMomentumDelta,
      predictedHomePossession:
          predictedHomePossession ?? step.predictedHomePossession,
      predictedAwayPossession:
          predictedAwayPossession ?? step.predictedAwayPossession,
      homeShotProbability: homeShotProbability ?? step.homeShotProbability,
      awayShotProbability: awayShotProbability ?? step.awayShotProbability,
      homeShotOnTargetProbability:
          homeShotOnTargetProbability ?? step.homeShotOnTargetProbability,
      awayShotOnTargetProbability:
          awayShotOnTargetProbability ?? step.awayShotOnTargetProbability,
      homeGoalProbability: homeGoalProbability ?? step.homeGoalProbability,
      awayGoalProbability: awayGoalProbability ?? step.awayGoalProbability,
      homeDangerIndex: homeDangerIndex ?? step.homeDangerIndex,
      awayDangerIndex: awayDangerIndex ?? step.awayDangerIndex,
    );
  }

  static ManagerInstructionAdjustedStepResult applyInstruction({
    required ManagerEngineStepResult step,
    String? instructionCode,
  }) {
    if (instructionCode == null || instructionCode.isEmpty) {
      return ManagerInstructionAdjustedStepResult(
        step: step,
        teamEnergyDelta: 0,
        appliedInstructionCode: null,
      );
    }

    switch (instructionCode) {
      case 'attack_more':
        return ManagerInstructionAdjustedStepResult(
          appliedInstructionCode: instructionCode,
          teamEnergyDelta: -4,
          step: _copyStep(
            step,
            homeMomentumDelta: step.homeMomentumDelta + 3,
            predictedHomePossession:
                (step.predictedHomePossession + 2).clamp(35, 65),
            predictedAwayPossession:
                (step.predictedAwayPossession - 2).clamp(35, 65),
            homeShotProbability:
                _clamp(step.homeShotProbability + 0.08, 0.05, 0.90),
            homeShotOnTargetProbability:
                _clamp(step.homeShotOnTargetProbability + 0.05, 0.05, 0.90),
            homeGoalProbability:
                _clamp(step.homeGoalProbability + 0.04, 0.03, 0.60),
            awayShotProbability:
                _clamp(step.awayShotProbability + 0.03, 0.05, 0.90),
            homeDangerIndex:
                _clamp(step.homeDangerIndex + 6, 1, 100),
          ),
        );

      case 'protect_lead':
        return ManagerInstructionAdjustedStepResult(
          appliedInstructionCode: instructionCode,
          teamEnergyDelta: -1,
          step: _copyStep(
            step,
            homeMomentumDelta: step.homeMomentumDelta - 2,
            predictedHomePossession:
                (step.predictedHomePossession - 1).clamp(35, 65),
            predictedAwayPossession:
                (step.predictedAwayPossession + 1).clamp(35, 65),
            homeShotProbability:
                _clamp(step.homeShotProbability - 0.05, 0.05, 0.90),
            homeGoalProbability:
                _clamp(step.homeGoalProbability - 0.03, 0.03, 0.60),
            awayShotProbability:
                _clamp(step.awayShotProbability - 0.04, 0.05, 0.90),
            awayGoalProbability:
                _clamp(step.awayGoalProbability - 0.04, 0.03, 0.60),
            homeDangerIndex:
                _clamp(step.homeDangerIndex - 3, 1, 100),
            awayDangerIndex:
                _clamp(step.awayDangerIndex - 6, 1, 100),
          ),
        );

      case 'high_press':
        return ManagerInstructionAdjustedStepResult(
          appliedInstructionCode: instructionCode,
          teamEnergyDelta: -6,
          step: _copyStep(
            step,
            homeMomentumDelta: step.homeMomentumDelta + 4,
            homeShotProbability:
                _clamp(step.homeShotProbability + 0.05, 0.05, 0.90),
            awayShotProbability:
                _clamp(step.awayShotProbability - 0.03, 0.05, 0.90),
            homeDangerIndex:
                _clamp(step.homeDangerIndex + 4, 1, 100),
            awayDangerIndex:
                _clamp(step.awayDangerIndex - 3, 1, 100),
          ),
        );

      case 'slow_tempo':
        return ManagerInstructionAdjustedStepResult(
          appliedInstructionCode: instructionCode,
          teamEnergyDelta: 2,
          step: _copyStep(
            step,
            homeMomentumDelta: step.homeMomentumDelta - 1,
            predictedHomePossession:
                (step.predictedHomePossession + 3).clamp(35, 65),
            predictedAwayPossession:
                (step.predictedAwayPossession - 3).clamp(35, 65),
            homeShotProbability:
                _clamp(step.homeShotProbability - 0.03, 0.05, 0.90),
            homeShotOnTargetProbability:
                _clamp(step.homeShotOnTargetProbability + 0.02, 0.05, 0.90),
            homeDangerIndex:
                _clamp(step.homeDangerIndex + 1, 1, 100),
          ),
        );

      case 'all_out_attack':
        return ManagerInstructionAdjustedStepResult(
          appliedInstructionCode: instructionCode,
          teamEnergyDelta: -8,
          step: _copyStep(
            step,
            homeMomentumDelta: step.homeMomentumDelta + 6,
            predictedHomePossession:
                (step.predictedHomePossession + 3).clamp(35, 65),
            predictedAwayPossession:
                (step.predictedAwayPossession - 3).clamp(35, 65),
            homeShotProbability:
                _clamp(step.homeShotProbability + 0.12, 0.05, 0.95),
            homeShotOnTargetProbability:
                _clamp(step.homeShotOnTargetProbability + 0.08, 0.05, 0.95),
            homeGoalProbability:
                _clamp(step.homeGoalProbability + 0.06, 0.03, 0.70),
            awayShotProbability:
                _clamp(step.awayShotProbability + 0.07, 0.05, 0.95),
            awayGoalProbability:
                _clamp(step.awayGoalProbability + 0.04, 0.03, 0.70),
            homeDangerIndex:
                _clamp(step.homeDangerIndex + 10, 1, 100),
            awayDangerIndex:
                _clamp(step.awayDangerIndex + 4, 1, 100),
          ),
        );

      default:
        return ManagerInstructionAdjustedStepResult(
          step: step,
          teamEnergyDelta: 0,
          appliedInstructionCode: null,
        );
    }
  }
}