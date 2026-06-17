import 'package:flutter/material.dart';
import 'cmr_ui.dart';

class ClubTeamsWorkspacePanel extends StatelessWidget {
  final List<Map<String, dynamic>> teams;
  final int? selectedTeamId;
  final ValueChanged<Map<String, dynamic>> onOpenTeam;
  final VoidCallback onCreateTeam;
  final Future<void> Function()? onRefresh;

  const ClubTeamsWorkspacePanel({
    super.key,
    required this.teams,
    required this.selectedTeamId,
    required this.onOpenTeam,
    required this.onCreateTeam,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 12),
          child: CmrSectionTitle(
            title: 'Команды клуба',
            subtitle: 'Управление командами, составом и рабочими модулями клуба.',
            trailing: Wrap(
              spacing: 10,
              children: [
                CmrGhostButton(
                  label: 'Обновить',
                  icon: Icons.refresh_rounded,
                  onPressed: onRefresh,
                ),
                CmrPrimaryButton(
                  label: 'Добавить команду',
                  icon: Icons.add_rounded,
                  onPressed: onCreateTeam,
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: teams.isEmpty
              ? CmrEmptyState(
                  icon: Icons.groups_2_outlined,
                  title: 'Команды пока не добавлены',
                  subtitle: 'Создайте первую команду клуба, назначьте тренера и добавьте состав.',
                  action: CmrPrimaryButton(
                    label: 'Добавить команду',
                    icon: Icons.add_rounded,
                    onPressed: onCreateTeam,
                  ),
                )
              : RefreshIndicator(
                  onRefresh: onRefresh ?? () async {},
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(22, 8, 22, 22),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 360,
                      mainAxisExtent: 172,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                    ),
                    itemCount: teams.length,
                    itemBuilder: (_, i) {
                      final team = teams[i];
                      final id = cmrInt(team['id'] ?? team['team_id']);
                      final selected = id == selectedTeamId;
                      final name = cmrStr(team['name'] ?? team['team_name'] ?? team['title'], 'Команда');
                      final sport = cmrStr(team['sport'] ?? team['category'] ?? team['type'], 'Футбол');
                      final logo = cmrImage(team['logo_url'] ?? team['logo'] ?? team['image'] ?? team['photo']);
                      final coach = cmrStr(team['coach_name'] ?? team['trainer_name'] ?? team['coach'], 'Тренер не указан');

                      return InkWell(
                        onTap: () => onOpenTeam(team),
                        borderRadius: BorderRadius.circular(24),
                        child: CmrCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 26,
                                    backgroundColor: CmrColors.blue.withOpacity(0.10),
                                    backgroundImage: logo == null ? null : NetworkImage(logo),
                                    child: logo == null
                                        ? const Icon(Icons.shield_outlined, color: CmrColors.blue)
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: CmrColors.text,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          sport,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: CmrColors.muted,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (selected)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: CmrColors.green.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: const Text(
                                        'Открыта',
                                        style: TextStyle(
                                          color: CmrColors.green,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const Spacer(),
                              Row(
                                children: [
                                  _MiniBadge(icon: Icons.person_outline_rounded, text: coach),
                                  const SizedBox(width: 8),
                                  _MiniBadge(icon: Icons.tag_rounded, text: '#$id'),
                                ],
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: CmrPrimaryButton(
                                  label: selected ? 'Открыть рабочую панель' : 'Выбрать команду',
                                  icon: Icons.arrow_forward_rounded,
                                  onPressed: () => onOpenTeam(team),
                                  color: selected ? CmrColors.blueDark : CmrColors.blue,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MiniBadge({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
        decoration: BoxDecoration(
          color: CmrColors.bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: CmrColors.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: CmrColors.muted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: CmrColors.text,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
