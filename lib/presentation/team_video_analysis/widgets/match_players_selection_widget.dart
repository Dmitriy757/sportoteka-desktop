import 'package:flutter/material.dart';
import 'package:sportoteka/presentation/team_video_analysis/utils/formatters.dart';

class MatchPlayersSelectionWidget extends StatefulWidget {
  final List<Map<String, dynamic>> players;
  final List<Map<String, dynamic>> initiallySelectedPlayers;
  final Function(List<Map<String, dynamic>> selectedPlayers) onApply;
  final String title;

  const MatchPlayersSelectionWidget({
    super.key,
    required this.players,
    required this.onApply,
    this.initiallySelectedPlayers = const [],
    this.title = 'Состав на матч',
  });

  @override
  State<MatchPlayersSelectionWidget> createState() =>
      _MatchPlayersSelectionWidgetState();
}

class _MatchPlayersSelectionWidgetState
    extends State<MatchPlayersSelectionWidget> {
  final TextEditingController _searchController = TextEditingController();
  late Map<String, Map<String, dynamic>> _selectionMap;
  String _activeFilter = 'all'; // all, starters, substitutes

  final List<String> _positions = [
    'Вратарь',
    'Защитник',
    'Полузащитник',
    'Нападающий',
  ];

  @override
  void initState() {
    super.initState();
    _initSelectionMap();
    _searchController.addListener(() => setState(() {}));
  }

  void _initSelectionMap() {
    _selectionMap = {};
    for (final p in widget.players) {
      final id = _playerId(p);
      _selectionMap[id] = {
        ...p,
        'is_selected': false,
        'is_starter': false,
        'match_position': _getMainPosition(p),
      };
    }

    for (final selected in widget.initiallySelectedPlayers) {
      final id = _playerId(selected);
      if (_selectionMap.containsKey(id)) {
        _selectionMap[id] = {
          ..._selectionMap[id]!,
          ...selected,
          'is_selected': true,
          'is_starter': _asBool(selected['is_starter']),
          'match_position': (selected['match_position']?.toString().trim().isNotEmpty == true)
              ? selected['match_position'].toString().trim()
              : _getMainPosition(selected),
        };
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _playerId(Map<String, dynamic> p) => Formatters.safeString(p['id']);
  
  String _firstName(Map<String, dynamic> p) => (p["first_name"]?.toString().trim() ?? p["name"]?.toString().trim() ?? "");
  String _lastName(Map<String, dynamic> p) => (p["last_name"]?.toString().trim() ?? p["surname"]?.toString().trim() ?? "");
  String _fullName(Map<String, dynamic> p) => "${_lastName(p)} ${_firstName(p)}".trim();
  
  String _photo(Map<String, dynamic> p) => (p["photo"]?.toString() ?? p["image"]?.toString() ?? "").trim();
  
  String _getMainPosition(Map<String, dynamic> p) {
    final variants = [p["position"], p["amplua"], p["role"], p["player_position"]];
    for (final item in variants) {
      final value = item?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return 'Полевой';
  }
  
  String _number(Map<String, dynamic> p) {
    final variants = [p["number"], p["player_number"], p["game_number"]];
    for (final item in variants) {
      final value = item?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  bool _asBool(dynamic value) {
    if (value == null) return false;
    final raw = value.toString().toLowerCase().trim();
    return raw == '1' || raw == 'true' || raw == 'yes';
  }

  List<Map<String, dynamic>> get _filteredPlayers {
    final query = _searchController.text.trim().toLowerCase();
    
    final list = widget.players.where((player) {
      final id = _playerId(player);
      final item = _selectionMap[id]!;
      
      if (_activeFilter == 'starters' && !_asBool(item['is_starter'])) return false;
      if (_activeFilter == 'substitutes' && _asBool(item['is_starter'])) return false;
      
      if (query.isEmpty) return true;
      
      final name = _fullName(player).toLowerCase();
      final position = (item['match_position'] ?? '').toString().toLowerCase();
      final number = _number(player).toLowerCase();
      
      return name.contains(query) || position.contains(query) || number.contains(query);
    }).toList();
    
    list.sort((a, b) {
      final aSelected = _asBool(_selectionMap[_playerId(a)]?['is_selected']);
      final bSelected = _asBool(_selectionMap[_playerId(b)]?['is_selected']);
      if (aSelected != bSelected) return aSelected ? -1 : 1;
      
      final aStarter = _asBool(_selectionMap[_playerId(a)]?['is_starter']);
      final bStarter = _asBool(_selectionMap[_playerId(b)]?['is_starter']);
      if (aStarter != bStarter) return aStarter ? -1 : 1;
      
      final aNum = int.tryParse(_number(a)) ?? 999;
      final bNum = int.tryParse(_number(b)) ?? 999;
      if (aNum != 999 || bNum != 999) return aNum.compareTo(bNum);
      
      return _fullName(a).compareTo(_fullName(b));
    });
    
    return list;
  }

  int get _selectedCount => _selectionMap.values.where((e) => _asBool(e['is_selected'])).length;
  int get _starterCount => _selectionMap.values.where((e) => _asBool(e['is_selected']) && _asBool(e['is_starter'])).length;

  void _toggleSelected(Map<String, dynamic> player, bool value) {
    final id = _playerId(player);
    setState(() {
      _selectionMap[id] = {
        ..._selectionMap[id]!,
        'is_selected': value,
        if (!value) 'is_starter': false,
      };
    });
  }

  void _toggleStarter(Map<String, dynamic> player, bool value) {
    final id = _playerId(player);
    setState(() {
      _selectionMap[id] = {
        ..._selectionMap[id]!,
        'is_selected': true,
        'is_starter': value,
      };
    });
  }

  void _updatePosition(Map<String, dynamic> player, String value) {
    final id = _playerId(player);
    setState(() {
      _selectionMap[id] = {
        ..._selectionMap[id]!,
        'match_position': value,
      };
    });
  }

  void _apply() {
    final selected = _selectionMap.values
        .where((e) => _asBool(e['is_selected']))
        .map((e) => {
              ...e,
              'is_match_participant': 1,
              'is_selected': 1,
              'is_starter': _asBool(e['is_starter']) ? 1 : 0,
              'match_position': (e['match_position']?.toString().trim().isNotEmpty == true)
                  ? e['match_position'].toString().trim()
                  : _getMainPosition(e),
            })
        .toList();
    widget.onApply(selected);
  }

  @override
  Widget build(BuildContext context) {
    final filteredPlayers = _filteredPlayers;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, const Color(0xFFF8FAFC)],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.group_add_rounded, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Выберите игроков, участвовавших в матче',
                        style: TextStyle(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Stats chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _buildStatChip(
                  icon: Icons.person_add_rounded,
                  label: 'Выбрано',
                  value: _selectedCount,
                  color: const Color(0xFF2563EB),
                ),
                const SizedBox(width: 10),
                _buildStatChip(
                  icon: Icons.star_rounded,
                  label: 'В старте',
                  value: _starterCount,
                  color: const Color(0xFF16A34A),
                ),
                const SizedBox(width: 10),
                _buildStatChip(
                  icon: Icons.people_outline_rounded,
                  label: 'Запас',
                  value: _selectedCount - _starterCount,
                  color: const Color(0xFFF59E0B),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Filter chips
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _buildFilterChip('Все', 'all'),
                const SizedBox(width: 8),
                _buildFilterChip('В старте', 'starters'),
                const SizedBox(width: 8),
                _buildFilterChip('Запас', 'substitutes'),
                const Spacer(),
                // Search field
                Container(
                  width: 180,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Поиск',
                      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF94A3B8)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          
          // Players list
          Expanded(
            child: filteredPlayers.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded, size: 48, color: const Color(0xFFCBD5E1)),
                        const SizedBox(height: 12),
                        Text(
                          'Игроки не найдены',
                          style: TextStyle(
                            fontSize: 14,
                            color: const Color(0xFF94A3B8),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredPlayers.length,
                    itemBuilder: (_, i) {
                      final player = filteredPlayers[i];
                      final id = _playerId(player);
                      final item = _selectionMap[id]!;
                      final isSelected = _asBool(item['is_selected']);
                      final isStarter = _asBool(item['is_starter']);
                      final fullName = _fullName(player);
                      final position = (item['match_position']?.toString().trim().isNotEmpty == true)
                          ? item['match_position'].toString().trim()
                          : _getMainPosition(player);
                      final number = _number(player);
                      final photo = Formatters.normalizeUrl(_photo(player));
                      final hasPhoto = photo != null && photo.toString().trim().isNotEmpty;
                      final initials = fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          gradient: isSelected
                              ? LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    const Color(0xFFEFF6FF),
                                    const Color(0xFFF8FAFC),
                                  ],
                                )
                              : null,
                          color: isSelected ? null : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF2563EB).withOpacity(0.3)
                                : const Color(0xFFE2E8F0),
                            width: isSelected ? 1.5 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _toggleSelected(player, !isSelected),
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      // Avatar with selection indicator
                                      Stack(
                                        children: [
                                          Container(
                                            width: 52,
                                            height: 52,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              gradient: isSelected
                                                  ? const LinearGradient(
                                                      colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                                                    )
                                                  : null,
                                              border: Border.all(
                                                color: isSelected ? Colors.transparent : const Color(0xFFE2E8F0),
                                                width: 2,
                                              ),
                                            ),
                                            child: CircleAvatar(
                                              radius: 24,
                                              backgroundColor: const Color(0xFFF1F5F9),
                                              backgroundImage: hasPhoto ? NetworkImage(photo) : null,
                                              child: !hasPhoto
                                                  ? Text(
                                                      initials,
                                                      style: TextStyle(
                                                        fontSize: 18,
                                                        fontWeight: FontWeight.w700,
                                                        color: isSelected ? Colors.white : const Color(0xFF475569),
                                                      ),
                                                    )
                                                  : null,
                                            ),
                                          ),
                                          if (isSelected)
                                            Positioned(
                                              right: 0,
                                              bottom: 0,
                                              child: Container(
                                                padding: const EdgeInsets.all(2),
                                                decoration: const BoxDecoration(
                                                  color: Colors.white,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.check_circle_rounded,
                                                  size: 16,
                                                  color: Color(0xFF2563EB),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(width: 14),
                                      // Player info
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    fullName,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.w800,
                                                      color: Color(0xFF0F172A),
                                                    ),
                                                  ),
                                                ),
                                                if (number.isNotEmpty) ...[
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFF1F5F9),
                                                      borderRadius: BorderRadius.circular(10),
                                                    ),
                                                    child: Text(
                                                      '#$number',
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.w800,
                                                        color: Color(0xFF475569),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            // Position badge
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: _getPositionColor(position).withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                position,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w700,
                                                  color: _getPositionColor(position),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Starter toggle
                                      if (isSelected)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: isStarter
                                                ? const Color(0xFFDCFCE7)
                                                : const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(30),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                isStarter ? Icons.star_rounded : Icons.event_seat_rounded,
                                                size: 14,
                                                color: isStarter ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                isStarter ? 'Старт' : 'Запас',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                  color: isStarter ? const Color(0xFF166534) : const Color(0xFF475569),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                  // Expanded controls for selected player
                                  if (isSelected) ...[
                                    const SizedBox(height: 12),
                                    Divider(color: const Color(0xFFE2E8F0), height: 1),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        // Position dropdown
                                        Expanded(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF8FAFC),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: const Color(0xFFE2E8F0)),
                                            ),
                                            child: DropdownButtonHideUnderline(
                                              child: DropdownButton<String>(
                                                value: position,
                                                isExpanded: true,
                                                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF0F172A),
                                                ),
                                                items: _positions.map((pos) {
                                                  return DropdownMenuItem(
                                                    value: pos,
                                                    child: Text(pos),
                                                  );
                                                }).toList(),
                                                onChanged: (value) {
                                                  if (value != null) _updatePosition(player, value);
                                                },
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        // Starter switch
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF8FAFC),
                                            borderRadius: BorderRadius.circular(30),
                                            border: Border.all(color: const Color(0xFFE2E8F0)),
                                          ),
                                          child: Row(
                                            children: [
                                              const Text(
                                                'В старте',
                                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                              ),
                                              const SizedBox(width: 8),
                                              Switch(
                                                value: isStarter,
                                                onChanged: (v) => _toggleStarter(player, v),
                                                activeColor: const Color(0xFF16A34A),
                                                activeTrackColor: const Color(0xFFDCFCE7),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          
          // Bottom action buttons
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      child: const Text(
                        'Отмена',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _selectedCount == 0 ? null : _apply,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        _selectedCount == 0 ? 'Выберите игроков' : 'Применить ($_selectedCount)',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required int value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withOpacity(0.12)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _activeFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _activeFilter = value),
      backgroundColor: Colors.white,
      selectedColor: const Color(0xFFEFF6FF),
      checkmarkColor: const Color(0xFF2563EB),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF475569),
      ),
      shape: StadiumBorder(
        side: BorderSide(
          color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
        ),
      ),
    );
  }

  Color _getPositionColor(String position) {
    switch (position) {
      case 'Вратарь': return const Color(0xFF8B5CF6);
      case 'Защитник': return const Color(0xFF3B82F6);
      case 'Полузащитник': return const Color(0xFF10B981);
      case 'Нападающий': return const Color(0xFFF59E0B);
      default: return const Color(0xFF64748B);
    }
  }
}