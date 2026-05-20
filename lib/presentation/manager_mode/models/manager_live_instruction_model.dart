class ManagerLiveInstructionModel {
  final String code;
  final String title;
  final String description;

  const ManagerLiveInstructionModel({
    required this.code,
    required this.title,
    required this.description,
  });
}

class ManagerLiveInstructionsCatalog {
  static const attackMore = ManagerLiveInstructionModel(
    code: 'attack_more',
    title: 'Атаковать',
    description: 'Больше риска и давления впереди',
  );

  static const protectLead = ManagerLiveInstructionModel(
    code: 'protect_lead',
    title: 'Удерживать счёт',
    description: 'Снижаем риск и усиливаем оборону',
  );

  static const highPress = ManagerLiveInstructionModel(
    code: 'high_press',
    title: 'Высокий прессинг',
    description: 'Больше давления без мяча, но выше усталость',
  );

  static const slowTempo = ManagerLiveInstructionModel(
    code: 'slow_tempo',
    title: 'Снизить темп',
    description: 'Больше контроля, меньше хаоса',
  );

  static const allOutAttack = ManagerLiveInstructionModel(
    code: 'all_out_attack',
    title: 'Ва-банк',
    description: 'Максимум атаки, минимум осторожности',
  );

  static const List<ManagerLiveInstructionModel> all = [
    attackMore,
    protectLead,
    highPress,
    slowTempo,
    allOutAttack,
  ];
}