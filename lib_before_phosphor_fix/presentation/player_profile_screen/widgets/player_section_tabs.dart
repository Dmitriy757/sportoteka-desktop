import 'package:flutter/material.dart';

import '../models/player_profile_models.dart';
import 'player_profile_ui.dart';

class PlayerSectionTabs extends StatelessWidget {
  final PlayerProfileSection value;
  final ValueChanged<PlayerProfileSection> onChanged;

  const PlayerSectionTabs({
    super.key,
    required this.value,
    required this.onChanged,
  });

  static const labels = <PlayerProfileSection, String>{
    PlayerProfileSection.overview: 'Обзор',
    PlayerProfileSection.activity: 'Активность',
    PlayerProfileSection.matches: 'Матчи',
    PlayerProfileSection.testing: 'Тестирование',
    PlayerProfileSection.health: 'Здоровье',
    PlayerProfileSection.card: 'Карточка игрока',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: PpColors.line, width: .7),
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final item = labels.keys.elementAt(i);
          final active = item == value;
          return InkWell(
            onTap: () => onChanged(item),
            borderRadius: BorderRadius.circular(9),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 13),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? PpColors.greenSoft : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                labels[item]!,
                style: PpText.body(
                  11.5,
                  color: active ? PpColors.greenDark : PpColors.text,
                  weight: active ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
