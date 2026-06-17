import 'package:flutter/material.dart';
import 'cmr_ui.dart';

class TeamPlayersWorkspacePanel extends StatelessWidget {
  final List<Map<String, dynamic>> players;
  final Map<String, dynamic>? selectedPlayer;
  final bool loading;
  final ValueChanged<Map<String, dynamic>> onSelectPlayer;
  final VoidCallback? onAddPlayer;
  final Future<void> Function()? onRefresh;

  const TeamPlayersWorkspacePanel({
    super.key,
    required this.players,
    required this.selectedPlayer,
    required this.loading,
    required this.onSelectPlayer,
    this.onAddPlayer,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 12),
          child: CmrSectionTitle(
            title: 'Состав команды',
            subtitle: 'Игроки команды, быстрый просмотр профиля и переход к полному досье.',
            trailing: Wrap(
              spacing: 10,
              children: [
                CmrGhostButton(label: 'Обновить', icon: Icons.refresh_rounded, onPressed: onRefresh),
                if (onAddPlayer != null)
                  CmrPrimaryButton(label: 'Добавить игрока', icon: Icons.person_add_alt_1_rounded, onPressed: onAddPlayer),
              ],
            ),
          ),
        ),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : players.isEmpty
                  ? CmrEmptyState(
                      icon: Icons.groups_outlined,
                      title: 'Состав пока пустой',
                      subtitle: 'Добавьте игроков в команду, чтобы открыть профили, метрики, медкарту и тренировки.',
                      action: onAddPlayer == null
                          ? null
                          : CmrPrimaryButton(
                              label: 'Добавить игрока',
                              icon: Icons.person_add_alt_1_rounded,
                              onPressed: onAddPlayer,
                            ),
                    )
                  : RefreshIndicator(
                      onRefresh: onRefresh ?? () async {},
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(22, 8, 22, 22),
                        itemCount: players.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final p = players[i];
                          final id = cmrInt(p['id'] ?? p['player_id'] ?? p['user_id']);
                          final selectedId = selectedPlayer == null
                              ? 0
                              : cmrInt(selectedPlayer!['id'] ?? selectedPlayer!['player_id'] ?? selectedPlayer!['user_id']);
                          final selected = id == selectedId;
                          final first = cmrStr(p['first_name'] ?? p['firstname']);
                          final last = cmrStr(p['last_name'] ?? p['lastname']);
                          final fallbackName = cmrStr(p['name'] ?? p['full_name'], 'Игрок');
                          final name = ('$first $last').trim().isEmpty ? fallbackName : ('$first $last').trim();
                          final photo = cmrImage(p['photo'] ?? p['avatar'] ?? p['image']);
                          final position = cmrStr(p['position'] ?? p['role'] ?? p['amplua'], 'Амплуа не указано');
                          final number = cmrStr(p['number'] ?? p['player_number']);
                          final age = cmrStr(p['age'] ?? p['birth_date'] ?? p['date_birth']);

                          return InkWell(
                            onTap: () => onSelectPlayer(p),
                            borderRadius: BorderRadius.circular(22),
                            child: CmrCard(
                              padding: const EdgeInsets.all(14),
                              radius: 22,
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 28,
                                    backgroundColor: CmrColors.blue.withOpacity(0.10),
                                    backgroundImage: photo == null ? null : NetworkImage(photo),
                                    child: photo == null
                                        ? const Icon(Icons.person_rounded, color: CmrColors.blue)
                                        : null,
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: CmrColors.text,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            if (number.isNotEmpty)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: CmrColors.blue.withOpacity(0.10),
                                                  borderRadius: BorderRadius.circular(999),
                                                ),
                                                child: Text(
                                                  '№ $number',
                                                  style: const TextStyle(
                                                    color: CmrColors.blue,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 6,
                                          children: [
                                            _Chip(icon: Icons.sports_soccer_rounded, text: position),
                                            if (age.isNotEmpty) _Chip(icon: Icons.calendar_today_rounded, text: age),
                                            _Chip(icon: Icons.badge_outlined, text: 'ID $id'),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: selected ? CmrColors.blue : CmrColors.bg,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: selected ? CmrColors.blue : CmrColors.border),
                                    ),
                                    child: Icon(
                                      selected ? Icons.check_rounded : Icons.chevron_right_rounded,
                                      color: selected ? Colors.white : CmrColors.muted,
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

class _Chip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Chip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: CmrColors.bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: CmrColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: CmrColors.muted),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: CmrColors.text,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
