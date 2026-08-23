import 'package:flutter/material.dart';

import '../models/manager_lineup_model.dart';
import '../services/manager_mode_service.dart';

class ManagerLineupScreen extends StatefulWidget {
  final int teamId;
  final int userId;

  const ManagerLineupScreen({
    super.key,
    required this.teamId,
    required this.userId,
  });

  @override
  State<ManagerLineupScreen> createState() => _ManagerLineupScreenState();
}

class _ManagerLineupScreenState extends State<ManagerLineupScreen> {
  bool _loading = true;
  bool _saving = false;

  late TextEditingController _titleController;

  String _title = 'Основной состав';
  String _formation = '4-3-3';

  List<ManagerLineupPlayer> _allPlayers = [];
  List<ManagerLineupPlayer> _selectedPlayers = [];

  final List<String> _formations = [
    '4-3-3',
    '4-4-2',
    '4-2-3-1',
    '3-5-2',
    '5-3-2',
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _load();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await ManagerModeService.getLineup(
        teamId: widget.teamId,
        userId: widget.userId,
      );

      setState(() {
        _title = data.lineup.title;
        _titleController.text = data.lineup.title;
        _formation = data.lineup.formation;
        _allPlayers = data.allPlayers;
        _selectedPlayers = data.selectedPlayers;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  bool _isSelected(int playerId) {
    return _selectedPlayers.any((e) => e.playerId == playerId);
  }

  void _togglePlayer(ManagerLineupPlayer player) {
    if (!_isSelected(player.playerId) && _selectedPlayers.length >= 18) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Максимум 18 игроков в заявке')),
      );
      return;
    }

    setState(() {
      if (_isSelected(player.playerId)) {
        _selectedPlayers.removeWhere((e) => e.playerId == player.playerId);
      } else {
        final startersCount =
            _selectedPlayers.where((e) => e.isStarting).length;

        _selectedPlayers.add(
          player.copyWith(
            isStarting: startersCount < 11,
            roleName: startersCount < 11 ? 'starter' : 'bench',
            positionCode: startersCount < 11
                ? _normalizePosition(player.position)
                : 'SUB',
          ),
        );
      }
    });
  }

  void _toggleStarter(ManagerLineupPlayer player) {
    final startersCount = _selectedPlayers.where((e) => e.isStarting).length;
    final index =
        _selectedPlayers.indexWhere((e) => e.playerId == player.playerId);
    if (index == -1) return;

    final current = _selectedPlayers[index];

    if (!current.isStarting && startersCount >= 11) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('В основе может быть только 11 игроков')),
      );
      return;
    }

    setState(() {
      final becomingStarter = !current.isStarting;
      _selectedPlayers[index] = current.copyWith(
        isStarting: becomingStarter,
        roleName: becomingStarter ? 'starter' : 'bench',
        positionCode: becomingStarter
            ? (current.positionCode == 'SUB'
                ? _normalizePosition(current.position)
                : current.positionCode)
            : 'SUB',
      );
    });
  }

  void _changePosition(ManagerLineupPlayer player, String value) {
    final index =
        _selectedPlayers.indexWhere((e) => e.playerId == player.playerId);
    if (index == -1) return;

    if (_selectedPlayers[index].isStarting && value == 'SUB') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Игрок основы не может иметь позицию SUB')),
      );
      return;
    }

    setState(() {
      _selectedPlayers[index] = _selectedPlayers[index].copyWith(
        positionCode: value,
      );
    });
  }

  String _normalizePosition(String raw) {
    final p = raw.toLowerCase();

    if (p.contains('врат') || p.contains('goal')) return 'GK';
    if (p.contains('защ') || p.contains('def')) return 'CB';
    if (p.contains('пол') || p.contains('mid')) return 'CM';
    if (p.contains('нап') || p.contains('for')) return 'ST';

    return 'CM';
  }

  Future<void> _save() async {
    final startersCount = _selectedPlayers.where((e) => e.isStarting).length;

    if (startersCount != 11) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Нужно выбрать ровно 11 игроков в основу. Сейчас: $startersCount',
          ),
        ),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      await ManagerModeService.saveLineup(
        teamId: widget.teamId,
        userId: widget.userId,
        title: _title,
        formation: _formation,
        players: _selectedPlayers,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Состав сохранён')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Color _readinessColor(int value) {
    if (value >= 75) return const Color(0xFF16A34A);
    if (value >= 50) return const Color(0xFFF59E0B);
    return const Color(0xFFDC2626);
  }

  Widget _buildSelectedPlayerCard(ManagerLineupPlayer player) {
    final positions = [
      'GK',
      'RB',
      'LB',
      'CB',
      'DM',
      'CM',
      'AM',
      'RW',
      'LW',
      'ST',
      'CF',
      'SUB',
    ];

    final isInjuryRisk = player.injuryRisk >= 70;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFDBEAFE),
                child: Text(
                  player.fullName.isNotEmpty
                      ? player.fullName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: Color(0xFF1D4ED8),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      player.fullName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${player.position} • Готовность ${player.readiness}',
                      style: TextStyle(
                        color: _readinessColor(player.readiness),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (isInjuryRisk) ...[
                      const SizedBox(height: 4),
                      const Text(
                        'Высокий риск травмы',
                        style: TextStyle(
                          color: Color(0xFFDC2626),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Switch(
                value: player.isStarting,
                onChanged: (_) => _toggleStarter(player),
              )
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: positions.contains(player.positionCode)
                      ? player.positionCode
                      : 'SUB',
                  decoration: InputDecoration(
                    labelText: 'Позиция',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                  ),
                  items: positions
                      .map(
                        (e) => DropdownMenuItem(
                          value: e,
                          child: Text(e),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) _changePosition(player, v);
                  },
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                onPressed: () => _togglePlayer(player),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Color(0xFFFCA5A5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('Убрать'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAllPlayerTile(ManagerLineupPlayer player) {
    final selected = _isSelected(player.playerId);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFEFF6FF) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected ? const Color(0xFF60A5FA) : const Color(0xFFE5E7EB),
        ),
      ),
      child: ListTile(
        onTap: () => _togglePlayer(player),
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFDBEAFE),
          child: Text(
            player.fullName.isNotEmpty ? player.fullName[0].toUpperCase() : '?',
            style: const TextStyle(
              color: Color(0xFF1D4ED8),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          player.fullName,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: Color(0xFF111827),
          ),
        ),
        subtitle: Text(
          '${player.position} • №${player.playerNumber} • готовность ${player.readiness}',
        ),
        trailing: Icon(
          selected ? Icons.check_circle : Icons.add_circle_outline,
          color: selected ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final startersCount = _selectedPlayers.where((e) => e.isStarting).length;
    final benchCount = _selectedPlayers.where((e) => !e.isStarting).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Стартовый состав'),
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        foregroundColor: const Color(0xFF111827),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                    ),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Управление составом',
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _titleController,
                        onChanged: (v) => _title = v,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Название состава',
                          hintStyle: TextStyle(color: Colors.white60),
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButton<String>(
                        value: _formation,
                        dropdownColor: const Color(0xFF1E3A8A),
                        underline: const SizedBox.shrink(),
                        iconEnabledColor: Colors.white,
                        style: const TextStyle(color: Colors.white),
                        items: _formations
                            .map(
                              (e) => DropdownMenuItem(
                                value: e,
                                child: Text(e),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _formation = v);
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Основа: $startersCount / 11 • Запас: $benchCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Выбранные игроки',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 12),
                ..._selectedPlayers.map(_buildSelectedPlayerCard),
                const SizedBox(height: 16),
                const Text(
                  'Все игроки команды',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 12),
                ..._allPlayers.map(_buildAllPlayerTile),
                const SizedBox(height: 20),
                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Сохранить состав',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),
              ],
            ),
    );
  }
}