import 'package:flutter/material.dart';
import 'cmr_ui.dart';

class TeamSimpleWorkspacePanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String description;
  final VoidCallback? onOpenFullModule;
  final List<Widget> children;

  const TeamSimpleWorkspacePanel({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.description,
    this.onOpenFullModule,
    this.children = const [],
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CmrSectionTitle(
            title: title,
            subtitle: subtitle,
            trailing: CmrGhostButton(
              label: 'Открыть полный модуль',
              icon: Icons.open_in_new_rounded,
              onPressed: onOpenFullModule,
            ),
          ),
          const SizedBox(height: 16),
          CmrCard(
            padding: const EdgeInsets.all(22),
            child: Row(
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: CmrColors.blue.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(icon, color: CmrColors.blue, size: 34),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Text(
                    description,
                    style: const TextStyle(
                      color: CmrColors.muted,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (children.isNotEmpty) ...[
            const SizedBox(height: 14),
            ...children,
          ],
        ],
      ),
    );
  }
}

class TeamWorkspaceOverviewPanel extends StatelessWidget {
  final String clubName;
  final String teamName;
  final int playersCount;
  final int matchesCount;
  final VoidCallback? onOpenRoster;
  final VoidCallback? onOpenMatches;
  final VoidCallback? onOpenPlans;
  final VoidCallback? onOpenVideo;

  const TeamWorkspaceOverviewPanel({
    super.key,
    required this.clubName,
    required this.teamName,
    required this.playersCount,
    required this.matchesCount,
    this.onOpenRoster,
    this.onOpenMatches,
    this.onOpenPlans,
    this.onOpenVideo,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CmrSectionTitle(
            title: 'Рабочая панель команды',
            subtitle: '$clubName · $teamName',
          ),
          const SizedBox(height: 16),
          LayoutBuilder(builder: (_, c) {
            final cols = c.maxWidth > 920 ? 4 : 2;
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: cols,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: cols == 4 ? 2.25 : 2.1,
              children: [
                _Stat(icon: Icons.groups_rounded, title: 'Игроки', value: '$playersCount', color: CmrColors.blue),
                _Stat(icon: Icons.sports_soccer_rounded, title: 'Матчи', value: '$matchesCount', color: CmrColors.green),
                _Stat(icon: Icons.assignment_turned_in_outlined, title: 'Планы', value: 'База', color: CmrColors.violet),
                _Stat(icon: Icons.smart_display_outlined, title: 'Видеоанализ', value: 'AI', color: CmrColors.orange),
              ],
            );
          }),
          const SizedBox(height: 14),
          CmrCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Быстрый доступ', style: TextStyle(color: CmrColors.text, fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                LayoutBuilder(builder: (_, c) {
                  final cols = c.maxWidth > 900 ? 4 : 2;
                  return GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: cols,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 2.55,
                    children: [
                      _Action(title: 'Состав', icon: Icons.groups_rounded, onTap: onOpenRoster),
                      _Action(title: 'Матчи', icon: Icons.sports_soccer_rounded, onTap: onOpenMatches),
                      _Action(title: 'Планы', icon: Icons.menu_book_rounded, onTap: onOpenPlans),
                      _Action(title: 'Видеоанализ', icon: Icons.video_camera_back_outlined, onTap: onOpenVideo),
                    ],
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;
  const _Stat({required this.icon, required this.title, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return CmrCard(
      padding: const EdgeInsets.all(15),
      radius: 20,
      child: Row(children: [
        Container(width: 44, height: 44, decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(15)), child: Icon(icon, color: color)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: CmrColors.muted, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 5),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: CmrColors.text, fontSize: 18, fontWeight: FontWeight.w700)),
        ])),
      ]),
    );
  }
}

class _Action extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback? onTap;
  const _Action({required this.title, required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(color: CmrColors.bg, borderRadius: BorderRadius.circular(18), border: Border.all(color: CmrColors.border)),
        child: Row(children: [
          Icon(icon, color: CmrColors.blue, size: 21),
          const SizedBox(width: 10),
          Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: CmrColors.text, fontSize: 13, fontWeight: FontWeight.w700))),
          const Icon(Icons.chevron_right_rounded, color: CmrColors.muted),
        ]),
      ),
    );
  }
}
