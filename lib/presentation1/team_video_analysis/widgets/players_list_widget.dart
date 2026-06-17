import 'package:flutter/material.dart';
import 'package:sportoteka/presentation/team_video_analysis/utils/formatters.dart';

class PlayersListWidget extends StatelessWidget {
  final List<Map<String, dynamic>> players;
  final Map<String, dynamic>? selectedPlayer;
  final TextEditingController searchController;
  final Function(Map<String, dynamic>) onPlayerSelected;

  /// Если true — показываем только игроков,
  /// которых допустили к анализу матча
  final bool onlyMatchParticipants;
  
  /// Колбэк для выбора состава матча
  final VoidCallback? onSelectMatchPlayers;

  const PlayersListWidget({
    super.key,
    required this.players,
    required this.selectedPlayer,
    required this.searchController,
    required this.onPlayerSelected,
    this.onlyMatchParticipants = true,
    this.onSelectMatchPlayers, // Добавлен новый параметр
  });

  String _firstName(Map<String, dynamic> p) {
    final first = p["first_name"]?.toString().trim() ?? "";
    final alt = p["name"]?.toString().trim() ?? "";
    return first.isNotEmpty ? first : alt;
  }

  String _lastName(Map<String, dynamic> p) {
    final last = p["last_name"]?.toString().trim() ?? "";
    final alt = p["surname"]?.toString().trim() ?? "";
    return last.isNotEmpty ? last : alt;
  }

  String _photo(Map<String, dynamic> p) {
    final raw = (p["photo"]?.toString() ?? p["image"]?.toString() ?? "").trim();
    return raw;
  }

  String _position(Map<String, dynamic> p) {
    return (p["position"]?.toString().trim().isNotEmpty == true)
        ? p["position"].toString().trim()
        : (p["amplua"]?.toString().trim().isNotEmpty == true)
            ? p["amplua"].toString().trim()
            : "Без амплуа";
  }

  String _number(Map<String, dynamic> p) {
    final value = p["number"]?.toString().trim() ??
        p["player_number"]?.toString().trim() ??
        "";
    return value;
  }

  bool _isMatchParticipant(Map<String, dynamic> p) {
    final raw = p["is_match_participant"];
    if (raw == null) return true;
    final value = raw.toString().toLowerCase().trim();
    return value == "1" || value == "true" || value == "yes";
  }

  @override
  Widget build(BuildContext context) {
    final search = searchController.text.trim().toLowerCase();

    final filteredPlayers = players.where((player) {
      if (onlyMatchParticipants && !_isMatchParticipant(player)) {
        return false;
      }

      final fullName =
          "${_lastName(player)} ${_firstName(player)}".trim().toLowerCase();
      final position = _position(player).toLowerCase();
      final number = _number(player).toLowerCase();

      if (search.isEmpty) return true;

      return fullName.contains(search) ||
          position.contains(search) ||
          number.contains(search);
    }).toList();

    return Container(
      width: 260,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
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
          // ========== ИЗМЕНЕННЫЙ ЗАГОЛОВОК С КНОПКОЙ ==========
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    "Игроки матча",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                // Кнопка выбора состава
                if (onSelectMatchPlayers != null)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onSelectMatchPlayers,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2563EB).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.groups_rounded,
                          size: 18,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // ===================================================
          const SizedBox(height: 8),
          TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: "Поиск игрока",
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              isDense: true,
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: filteredPlayers.isEmpty
                ? const Center(
                    child: Text(
                      "Игроки не найдены",
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: filteredPlayers.length,
                    itemBuilder: (_, i) {
                      final player = filteredPlayers[i];
                      final selected = selectedPlayer != null &&
                          Formatters.safeString(selectedPlayer!["id"]) ==
                              Formatters.safeString(player["id"]);

                      final firstName = _firstName(player);
                      final lastName = _lastName(player);
                      final position = _position(player);
                      final number = _number(player);

                      final photo = Formatters.normalizeUrl(_photo(player));
                      final hasPhoto =
                          photo != null && photo.toString().trim().isNotEmpty;

                      final initials = (lastName.isNotEmpty
                              ? lastName[0]
                              : firstName.isNotEmpty
                                  ? firstName[0]
                                  : "?")
                          .toUpperCase();

                      return InkWell(
                        onTap: () => onPlayerSelected(player),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: selected
                                ? const Color(0xFFEAF2FF)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selected
                                  ? const Color(0xFF2563EB)
                                  : Colors.transparent,
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: const Color(0xFFE5E7EB),
                                backgroundImage:
                                    hasPhoto ? NetworkImage(photo) : null,
                                child: !hasPhoto
                                    ? Text(
                                        initials,
                                        style: const TextStyle(fontSize: 12),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "$lastName $firstName".trim(),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      number.isNotEmpty
                                          ? "$position • №$number"
                                          : position,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}