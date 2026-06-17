import 'package:flutter/material.dart';
import 'cmr_ui.dart';

class PlayerProfileWorkspacePanel extends StatelessWidget {
  final Map<String, dynamic>? player;
  final VoidCallback? onOpenFullProfile;
  final VoidCallback? onBackToRoster;

  const PlayerProfileWorkspacePanel({
    super.key,
    required this.player,
    this.onOpenFullProfile,
    this.onBackToRoster,
  });

  @override
  Widget build(BuildContext context) {
    if (player == null) {
      return CmrEmptyState(
        icon: Icons.person_search_rounded,
        title: 'Игрок не выбран',
        subtitle: 'Выберите игрока в разделе “Состав”, чтобы открыть профиль внутри CMR.',
        action: onBackToRoster == null
            ? null
            : CmrPrimaryButton(label: 'Перейти к составу', icon: Icons.groups_rounded, onPressed: onBackToRoster),
      );
    }

    final p = player!;
    final first = cmrStr(p['first_name'] ?? p['firstname']);
    final last = cmrStr(p['last_name'] ?? p['lastname']);
    final fallbackName = cmrStr(p['name'] ?? p['full_name'], 'Игрок');
    final name = ('$first $last').trim().isEmpty ? fallbackName : ('$first $last').trim();
    final photo = cmrImage(p['photo'] ?? p['avatar'] ?? p['image']);
    final position = cmrStr(p['position'] ?? p['role'] ?? p['amplua'], 'Амплуа не указано');
    final number = cmrStr(p['number'] ?? p['player_number']);
    final club = cmrStr(p['club'] ?? p['club_name']);
    final team = cmrStr(p['team'] ?? p['team_name']);
    final birth = cmrStr(p['birth_date'] ?? p['date_birth'] ?? p['age']);
    final height = cmrStr(p['height']);
    final weight = cmrStr(p['weight']);
    final nationality = cmrStr(p['nationality'] ?? p['country'] ?? p['citizenship']);
    final sportData = cmrStr(p['sport_data'] ?? p['metrics']);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CmrSectionTitle(
            title: 'Профиль игрока',
            subtitle: 'Краткое досье внутри CMR без выхода из рабочего кабинета.',
            trailing: Wrap(
              spacing: 10,
              children: [
                if (onBackToRoster != null)
                  CmrGhostButton(label: 'К составу', icon: Icons.arrow_back_rounded, onPressed: onBackToRoster),
                CmrPrimaryButton(label: 'Полный профиль', icon: Icons.open_in_new_rounded, onPressed: onOpenFullProfile),
              ],
            ),
          ),
          const SizedBox(height: 16),
          CmrCard(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 52,
                  backgroundColor: CmrColors.blue.withOpacity(0.10),
                  backgroundImage: photo == null ? null : NetworkImage(photo),
                  child: photo == null ? const Icon(Icons.person_rounded, color: CmrColors.blue, size: 46) : null,
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: CmrColors.text,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _InfoPill(icon: Icons.sports_soccer_rounded, label: position, color: CmrColors.blue),
                          if (number.isNotEmpty) _InfoPill(icon: Icons.tag_rounded, label: '№ $number', color: CmrColors.green),
                          if (team.isNotEmpty) _InfoPill(icon: Icons.groups_2_outlined, label: team, color: CmrColors.violet),
                          if (club.isNotEmpty) _InfoPill(icon: Icons.shield_outlined, label: club, color: CmrColors.orange),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (_, c) {
              final wide = c.maxWidth > 900;
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: wide ? 4 : 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: wide ? 2.55 : 2.2,
                children: [
                  _MetricCard(icon: Icons.cake_outlined, title: 'Возраст / дата', value: birth.isEmpty ? 'Не указано' : birth),
                  _MetricCard(icon: Icons.height_rounded, title: 'Рост', value: height.isEmpty ? 'Не указано' : '$height см'),
                  _MetricCard(icon: Icons.monitor_weight_outlined, title: 'Вес', value: weight.isEmpty ? 'Не указано' : '$weight кг'),
                  _MetricCard(icon: Icons.flag_outlined, title: 'Гражданство', value: nationality.isEmpty ? 'Не указано' : nationality),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: CmrCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Спортивные данные', style: TextStyle(color: CmrColors.text, fontSize: 17, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 10),
                      Text(
                        sportData.isEmpty ? 'Метрики пока не заполнены. Откройте полный профиль, чтобы добавить показатели игрока.' : sportData,
                        style: const TextStyle(color: CmrColors.muted, fontSize: 13.5, fontWeight: FontWeight.w600, height: 1.35),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: CmrCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Быстрые действия', style: TextStyle(color: CmrColors.text, fontSize: 17, fontWeight: FontWeight.w900)),
                      SizedBox(height: 10),
                      Text(
                        'Назначить тренировку, открыть медкарту, посмотреть достижения и дневник можно через полный профиль или следующие CMR-панели.',
                        style: TextStyle(color: CmrColors.muted, fontSize: 13.5, fontWeight: FontWeight.w600, height: 1.35),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoPill({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 15, color: color), const SizedBox(width: 6), Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w900))],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _MetricCard({required this.icon, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return CmrCard(
      padding: const EdgeInsets.all(14),
      radius: 20,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: CmrColors.blue.withOpacity(0.10), borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: CmrColors.blue, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: CmrColors.muted, fontSize: 11, fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: CmrColors.text, fontSize: 15, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
