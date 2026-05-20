import 'package:flutter/material.dart';

import '../services/manager_mode_service.dart';

class ManagerTacticsScreen extends StatefulWidget {
  final int teamId;
  final int userId;

  const ManagerTacticsScreen({
    super.key,
    required this.teamId,
    required this.userId,
  });

  @override
  State<ManagerTacticsScreen> createState() => _ManagerTacticsScreenState();
}

class _ManagerTacticsScreenState extends State<ManagerTacticsScreen> {
  bool _loading = true;
  bool _saving = false;

  String _formation = '4-3-3';
  String _playStyle = 'balanced';
  String _pressing = 'medium';
  String _tempo = 'medium';
  String _defensiveLine = 'medium';
  String _intensity = 'medium';

  final _formations = ['4-3-3', '4-4-2', '3-5-2', '4-2-3-1', '5-3-2'];
  final _playStyles = [
    'balanced',
    'possession',
    'counter_attack',
    'defensive',
    'high_press',
  ];
  final _levels = ['low', 'medium', 'high'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _labelPlayStyle(String value) {
    switch (value) {
      case 'possession':
        return 'Владение';
      case 'counter_attack':
        return 'Контратаки';
      case 'defensive':
        return 'Оборонительный';
      case 'high_press':
        return 'Высокий прессинг';
      default:
        return 'Сбалансированный';
    }
  }

  String _labelLevel(String value) {
    switch (value) {
      case 'low':
        return 'Низкий';
      case 'high':
        return 'Высокий';
      default:
        return 'Средний';
    }
  }

  Future<void> _load() async {
    try {
      final overview = await ManagerModeService.getTeamOverview(
        teamId: widget.teamId,
        userId: widget.userId,
      );

      final tactics = overview.tactics;

      setState(() {
        _formation = tactics.formation;
        _playStyle = tactics.playStyle;
        _pressing = tactics.pressingLevel;
        _tempo = tactics.tempo;
        _defensiveLine = tactics.defensiveLine;
        _intensity = tactics.intensity;
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    try {
      await ManagerModeService.saveTactics(
        teamId: widget.teamId,
        userId: widget.userId,
        formation: _formation,
        playStyle: _playStyle,
        pressingLevel: _pressing,
        tempo: _tempo,
        defensiveLine: _defensiveLine,
        intensity: _intensity,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Тактика сохранена')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _buildDropdown({
    required String title,
    required String value,
    required List<String> values,
    required String Function(String) labelBuilder,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(
          border: InputBorder.none,
          labelText: title,
        ),
        items: values
            .map(
              (e) => DropdownMenuItem(
                value: e,
                child: Text(labelBuilder(e)),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildTacticsPreview() {
    final items = [
      'Схема: $_formation',
      'Стиль: ${_labelPlayStyle(_playStyle)}',
      'Прессинг: ${_labelLevel(_pressing)}',
      'Темп: ${_labelLevel(_tempo)}',
      'Линия обороны: ${_labelLevel(_defensiveLine)}',
      'Интенсивность: ${_labelLevel(_intensity)}',
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Текущая модель игры',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Тактический профиль',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          ...items.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '• $e',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Тактика команды'),
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        foregroundColor: const Color(0xFF111827),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildTacticsPreview(),
                const SizedBox(height: 16),
                _buildDropdown(
                  title: 'Схема',
                  value: _formation,
                  values: _formations,
                  labelBuilder: (v) => v,
                  onChanged: (v) => setState(() => _formation = v ?? '4-3-3'),
                ),
                _buildDropdown(
                  title: 'Стиль игры',
                  value: _playStyle,
                  values: _playStyles,
                  labelBuilder: _labelPlayStyle,
                  onChanged: (v) => setState(() => _playStyle = v ?? 'balanced'),
                ),
                _buildDropdown(
                  title: 'Прессинг',
                  value: _pressing,
                  values: _levels,
                  labelBuilder: _labelLevel,
                  onChanged: (v) => setState(() => _pressing = v ?? 'medium'),
                ),
                _buildDropdown(
                  title: 'Темп',
                  value: _tempo,
                  values: _levels,
                  labelBuilder: _labelLevel,
                  onChanged: (v) => setState(() => _tempo = v ?? 'medium'),
                ),
                _buildDropdown(
                  title: 'Линия обороны',
                  value: _defensiveLine,
                  values: _levels,
                  labelBuilder: _labelLevel,
                  onChanged: (v) =>
                      setState(() => _defensiveLine = v ?? 'medium'),
                ),
                _buildDropdown(
                  title: 'Интенсивность',
                  value: _intensity,
                  values: _levels,
                  labelBuilder: _labelLevel,
                  onChanged: (v) => setState(() => _intensity = v ?? 'medium'),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 52,
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
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Сохранить тактику',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
              ],
            ),
    );
  }
}