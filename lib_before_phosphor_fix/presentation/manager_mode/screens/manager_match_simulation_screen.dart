import 'package:flutter/material.dart';

import '../services/manager_mode_service.dart';
import 'manager_live_match_screen.dart';
import 'manager_match_report_screen.dart';

class ManagerMatchSimulationScreen extends StatefulWidget {
  final int teamId;
  final int userId;
  final String teamName;

  const ManagerMatchSimulationScreen({
    super.key,
    required this.teamId,
    required this.userId,
    required this.teamName,
  });

  @override
  State<ManagerMatchSimulationScreen> createState() =>
      _ManagerMatchSimulationScreenState();
}

class _ManagerMatchSimulationScreenState
    extends State<ManagerMatchSimulationScreen> {
  final TextEditingController _opponentController =
      TextEditingController(text: 'Соперник');
  final TextEditingController _strengthController =
      TextEditingController(text: '68');

  bool _simulating = false;
  bool _startingLive = false;

  @override
  void dispose() {
    _opponentController.dispose();
    _strengthController.dispose();
    super.dispose();
  }

  Future<void> _simulateClassic() async {
    final opponentName = _opponentController.text.trim();
    final opponentStrength =
        int.tryParse(_strengthController.text.trim()) ?? 68;

    if (opponentName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите название соперника')),
      );
      return;
    }

    setState(() => _simulating = true);

    try {
      final result = await ManagerModeService.simulateMatch(
        teamId: widget.teamId,
        userId: widget.userId,
        opponentName: opponentName,
        opponentStrength: opponentStrength,
      );

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ManagerMatchReportScreen(
            matchId: result.matchId,
            teamName: widget.teamName,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    } finally {
      if (mounted) setState(() => _simulating = false);
    }
  }

  Future<void> _startLiveMatch() async {
    final opponentName = _opponentController.text.trim();
    final opponentStrength =
        int.tryParse(_strengthController.text.trim()) ?? 68;

    if (opponentName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите название соперника')),
      );
      return;
    }

    setState(() => _startingLive = true);

    try {
      final liveMatchId = await ManagerModeService.startLiveMatch(
        teamId: widget.teamId,
        userId: widget.userId,
        opponentName: opponentName,
        opponentStrength: opponentStrength,
      );

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ManagerLiveMatchScreen(
            liveMatchId: liveMatchId,
            teamId: widget.teamId,
            userId: widget.userId,
            teamName: widget.teamName,
            profiles: const [],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка live матча: $e')),
      );
    } finally {
      if (mounted) setState(() => _startingLive = false);
    }
  }

  Widget _buildModeCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Симуляция матча'),
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        foregroundColor: const Color(0xFF111827),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Подготовка к матчу',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.teamName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Выбери соперника и формат матча',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _opponentController,
            decoration: InputDecoration(
              labelText: 'Соперник',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _strengthController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Сила соперника (пример: 60–80)',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 18),
          _buildModeCard(
            title: 'Обычная симуляция',
            subtitle: 'Сразу рассчитывает итог матча и открывает отчёт',
            icon: Icons.sports_score,
            color: const Color(0xFF2563EB),
          ),
          const SizedBox(height: 12),
          _buildModeCard(
            title: 'Live Match Center',
            subtitle: 'Матч идёт по 5 минут с событиями, momentum и игроками',
            icon: Icons.live_tv_rounded,
            color: const Color(0xFF111827),
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _simulating ? null : _simulateClassic,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: _simulating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.sports_score),
              label: Text(
                _simulating ? 'Симуляция...' : 'Обычная симуляция',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _startingLive ? null : _startLiveMatch,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF111827),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: _startingLive
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.live_tv_rounded),
              label: Text(
                _startingLive ? 'Запуск...' : 'Live Match Center',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}