import 'package:flutter/material.dart';
import 'package:sportoteka/presentation/team_video_analysis/utils/formatters.dart';
import 'package:sportoteka/presentation/team_video_analysis/models/ttd_models.dart';

class EpisodesListWidget extends StatelessWidget {
  final List<Map<String, dynamic>> episodes;
  final List<Map<String, dynamic>> players;
  final Map<String, dynamic>? selectedEpisode;
  final bool creatingEpisode;
  final bool isVideoFullscreen;
  final Function(Map<String, dynamic>) onEpisodeSelected;
  final Function(int) onEpisodeDeleted;
  final Function(Map<String, dynamic>) onEpisodeEdited;
  final Function(Map<String, dynamic>) onEpisodeDetail;
  final Function() onCreateEpisode;
  final Function() onExitFullscreen;

  const EpisodesListWidget({
    super.key,
    required this.episodes,
    required this.players,
    required this.selectedEpisode,
    required this.creatingEpisode,
    required this.isVideoFullscreen,
    required this.onEpisodeSelected,
    required this.onEpisodeDeleted,
    required this.onEpisodeEdited,
    required this.onEpisodeDetail,
    required this.onCreateEpisode,
    required this.onExitFullscreen,
  });

  String _formatDurationFromSeconds(int seconds) {
    return Formatters.formatDuration(Duration(seconds: seconds));
  }

  String _episodePlayerName(Map<String, dynamic> episode) {
    final playerId = Formatters.safeInt(episode['player_id']);
    if (playerId <= 0) return '';

    final matched = players.where(
      (p) => Formatters.safeInt(p['id']) == playerId,
    );

    if (matched.isEmpty) {
      return 'Игрок #$playerId';
    }

    final player = matched.first;
    final fullName = player['full_name']?.toString() ?? '';
    final firstName =
        player['first_name']?.toString() ?? player['name']?.toString() ?? '';
    final lastName =
        player['last_name']?.toString() ?? player['surname']?.toString() ?? '';

    final result = fullName.isNotEmpty ? fullName : "$lastName $firstName".trim();
    return result.isNotEmpty ? result : 'Игрок #$playerId';
  }

  Widget _buildChildAction(Map<String, dynamic> action) {
    final isPositive = (action['is_positive'] ?? 1) > 0;

    String playerName = 'Неизвестный игрок';

    if (action['player'] != null && action['player'] is Map<String, dynamic>) {
      final playerData = action['player'] as Map<String, dynamic>;
      final firstName =
          playerData['first_name']?.toString() ?? playerData['name']?.toString() ?? '';
      final lastName =
          playerData['last_name']?.toString() ?? playerData['surname']?.toString() ?? '';

      if (playerData['full_name']?.toString().isNotEmpty == true) {
        playerName = playerData['full_name'].toString();
      } else {
        playerName = "$lastName $firstName".trim();
      }

      if (playerName.isEmpty || playerName == " ") {
        if (playerData['jersey_number'] != null) {
          playerName = "Игрок #${playerData['jersey_number']}";
        } else {
          playerName = "Игрок ${playerData['id']}";
        }
      }
    } else {
      final playerId = Formatters.safeInt(action['player_id']);
      if (playerId > 0) {
        final matched = players.where(
          (p) => Formatters.safeInt(p['id']) == playerId,
        );
        if (matched.isNotEmpty) {
          final p = matched.first;
          final fullName = p['full_name']?.toString() ?? '';
          final firstName =
              p['first_name']?.toString() ?? p['name']?.toString() ?? '';
          final lastName =
              p['last_name']?.toString() ?? p['surname']?.toString() ?? '';
          final result =
              fullName.isNotEmpty ? fullName : "$lastName $firstName".trim();
          if (result.isNotEmpty) {
            playerName = result;
          } else {
            playerName = 'Игрок #$playerId';
          }
        } else {
          playerName = 'Игрок #$playerId';
        }
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isPositive ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPositive ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isPositive ? Icons.check_circle : Icons.error,
            size: 18,
            color: isPositive ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action['event_title']?.toString() ??
                      TtdHelpers.getEventTypeTitle(
                        action['event_type']?.toString() ?? 'Действие',
                      ),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  playerName,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (action['rating'] != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                action['rating'].toString(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEpisodeCard(Map<String, dynamic> episode) {
    final isSelected = selectedEpisode != null &&
        Formatters.safeString(selectedEpisode!['id']) ==
            Formatters.safeString(episode['id']);

    final timeSec = Formatters.safeInt(episode['timecode_seconds']);
    final children = episode['children'] as List? ?? [];
    final playerName = _episodePlayerName(episode);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => onEpisodeSelected(episode),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF2563EB).withOpacity(0.06)
                  : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF2563EB)
                    : Colors.grey.shade200,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isSelected ? 0.1 : 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.movie_creation_outlined,
                          color: Color(0xFF2563EB),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              episode['event_title']?.toString() ?? 'Эпизод',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: isSelected
                                    ? const Color(0xFF2563EB)
                                    : Colors.black,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Время: ${_formatDurationFromSeconds(timeSec)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            if (playerName.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                playerName,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: IconButton(
                              onPressed: () => onEpisodeDetail(episode),
                              icon: const Icon(
                                Icons.arrow_forward_rounded,
                                color: Color(0xFF2563EB),
                                size: 20,
                              ),
                              tooltip: 'Подробнее',
                            ),
                          ),
                          const SizedBox(height: 4),
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'delete') {
                                onEpisodeDeleted(Formatters.safeInt(episode['id']));
                              } else if (value == 'edit') {
                                onEpisodeEdited(episode);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit, size: 18),
                                    SizedBox(width: 8),
                                    Text('Редактировать'),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline,
                                        size: 18, color: Colors.red),
                                    SizedBox(width: 8),
                                    Text(
                                      'Удалить',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            icon: const Icon(Icons.more_vert, size: 18),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (children.isNotEmpty) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.account_tree_outlined,
                              size: 14,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Действия (${children.length})',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...children.take(3).map((child) => _buildChildAction(
                              Map<String, dynamic>.from(child),
                            )),
                        if (children.length > 3)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              'и еще ${children.length - 3}...',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade500,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.photo_library,
                    size: 20, color: Color(0xFF2563EB)),
                const SizedBox(width: 8),
                const Text(
                  "Эпизоды матча",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "${episodes.length}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: ElevatedButton.icon(
              onPressed: creatingEpisode
                  ? null
                  : () async {
                      if (isVideoFullscreen) {
                        onExitFullscreen();
                        await Future.delayed(const Duration(milliseconds: 150));
                      }
                      onCreateEpisode();
                    },
              icon: creatingEpisode
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_photo_alternate_outlined),
              label: const Text("Создать эпизод с текущего кадра"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: episodes.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.photo_library_outlined,
                          size: 60,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Нет эпизодов",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Нажми кнопку выше, чтобы создать\nпервый эпизод",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: episodes.length,
                    itemBuilder: (context, index) {
                      final episode = episodes[index];
                      return _buildEpisodeCard(
                        Map<String, dynamic>.from(episode),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}