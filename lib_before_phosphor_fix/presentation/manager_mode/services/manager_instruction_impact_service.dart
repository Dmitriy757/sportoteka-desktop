class ManagerInstructionImpactResult {
  final double attackModifier;
  final double defenseModifier;
  final double pressingModifier;
  final double tempoModifier;
  final double moraleModifier;

  const ManagerInstructionImpactResult({
    this.attackModifier = 1.0,
    this.defenseModifier = 1.0,
    this.pressingModifier = 1.0,
    this.tempoModifier = 1.0,
    this.moraleModifier = 1.0,
  });
}

class ManagerInstructionImpactService {
  const ManagerInstructionImpactService();

  ManagerInstructionImpactResult calculateImpact({
    required String? instructionCode,
  }) {
    switch (instructionCode) {
      case 'high_press':
        return const ManagerInstructionImpactResult(
          pressingModifier: 1.2,
          defenseModifier: 1.05,
        );

      case 'park_the_bus':
        return const ManagerInstructionImpactResult(
          defenseModifier: 1.2,
          attackModifier: 0.85,
          tempoModifier: 0.9,
        );

      case 'all_out_attack':
        return const ManagerInstructionImpactResult(
          attackModifier: 1.25,
          defenseModifier: 0.8,
          tempoModifier: 1.15,
        );

      case 'slow_tempo':
        return const ManagerInstructionImpactResult(
          tempoModifier: 0.85,
          defenseModifier: 1.05,
        );

      case 'fast_tempo':
        return const ManagerInstructionImpactResult(
          tempoModifier: 1.2,
          attackModifier: 1.1,
        );

      default:
        return const ManagerInstructionImpactResult();
    }
  }
}