import 'package:flutter/material.dart';

import '../models/player_profile_models.dart';
import 'player_profile_ui.dart';

class PlayerSectionTabs extends StatelessWidget {
  final PlayerProfileSection value;
  final ValueChanged<PlayerProfileSection> onChanged;
  final Set<PlayerProfileSection>? allowedSections;
  final bool mediaActive;
  final VoidCallback? onMedia;

  const PlayerSectionTabs({
    super.key,
    required this.value,
    required this.onChanged,
    this.allowedSections,
    this.mediaActive = false,
    this.onMedia,
  });

  static const order = <PlayerProfileSection>[
    PlayerProfileSection.card,
    PlayerProfileSection.diary,
    PlayerProfileSection.readiness,
    PlayerProfileSection.activity,
    PlayerProfileSection.matches,
    PlayerProfileSection.testing,
    PlayerProfileSection.health,
    PlayerProfileSection.documents,
  ];

  static const labels = <PlayerProfileSection, String>{
    PlayerProfileSection.card: 'Карточка игрока',
    PlayerProfileSection.diary: 'Дневник',
    PlayerProfileSection.readiness: 'Готовность',
    PlayerProfileSection.activity: 'Активность',
    PlayerProfileSection.matches: 'Матчи',
    PlayerProfileSection.testing: 'Тестирование',
    PlayerProfileSection.health: 'Здоровье',
    PlayerProfileSection.documents: 'Документы',
  };

  Color _dotColor(PlayerProfileSection section) {
    switch (section) {
      case PlayerProfileSection.card:
        return PpColors.green;
      case PlayerProfileSection.diary:
        return PpColors.greenDark;
      case PlayerProfileSection.readiness:
        return PpColors.red;
      case PlayerProfileSection.activity:
        return PpColors.amber;
      case PlayerProfileSection.matches:
        return PpColors.green;
      case PlayerProfileSection.analytics:
        return PpColors.greenDark;
      case PlayerProfileSection.testing:
        return PpColors.amber;
      case PlayerProfileSection.health:
        return PpColors.red;
      case PlayerProfileSection.documents:
        return PpColors.greenDark;
      case PlayerProfileSection.overview:
        return PpColors.green;
    }
  }

  Widget _sectionTile(
    PlayerProfileSection item, {
    required bool active,
  }) {
    final color = _dotColor(item);
    return Material(
      color: active ? PpColors.greenSoft : Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: () => onChanged(item),
        borderRadius: BorderRadius.circular(9),
        child: SizedBox(
          height: 38,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PpDot(
                  color: color,
                  size: active ? 6 : 4.5,
                  opacity: active ? 1 : .7,
                ),
                const SizedBox(width: 6),
                Text(
                  labels[item]!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PpText.body(
                    10.4,
                    color: active
                        ? PpColors.greenDark
                        : PpColors.text,
                    weight: active
                        ? FontWeight.w600
                        : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _mediaTile() {
    final active = mediaActive;
    return Material(
      color: active ? PpColors.greenSoft : Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onMedia,
        borderRadius: BorderRadius.circular(9),
        child: SizedBox(
          height: 38,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PpDot(
                  color: PpColors.green,
                  size: active ? 6 : 4.5,
                  opacity: active ? 1 : .7,
                ),
                const SizedBox(width: 6),
                Text(
                  'Медиа',
                  style: PpText.body(
                    10.4,
                    color: active
                        ? PpColors.greenDark
                        : PpColors.text,
                    weight: active
                        ? FontWeight.w600
                        : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = order.where((section) {
      if (allowedSections == null) return true;
      if (allowedSections!.contains(section)) return true;

      if (section == PlayerProfileSection.activity &&
          allowedSections!.contains(PlayerProfileSection.analytics)) {
        return true;
      }

      return section == PlayerProfileSection.card &&
          allowedSections!.contains(PlayerProfileSection.overview);
    }).toList(growable: false);

    final selected = value == PlayerProfileSection.overview
        ? PlayerProfileSection.card
        : value == PlayerProfileSection.analytics
            ? PlayerProfileSection.activity
            : value;

    final showMedia = onMedia != null &&
        (allowedSections == null ||
            allowedSections!.contains(PlayerProfileSection.card) ||
            allowedSections!.contains(PlayerProfileSection.overview));

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: PpColors.line,
            width: .65,
          ),
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: visible.length + (showMedia ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(width: 4),
        itemBuilder: (_, index) {
          // Media sits after Matches so it is visible as a real profile section.
          final matchesIndex =
              visible.indexOf(PlayerProfileSection.matches);
          final mediaIndex =
              showMedia ? (matchesIndex >= 0 ? matchesIndex + 1 : visible.length) : -1;

          if (showMedia && index == mediaIndex) {
            return _mediaTile();
          }

          var sectionIndex = index;
          if (showMedia && index > mediaIndex) {
            sectionIndex -= 1;
          }

          final item = visible[sectionIndex];
          return _sectionTile(
            item,
            active: !mediaActive && item == selected,
          );
        },
      ),
    );
  }
}
