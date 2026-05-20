import 'package:flutter/material.dart';

import '../models/manager_team_overview_model.dart';
import '../services/manager_mode_service.dart';
import 'manager_lineup_screen.dart';
import 'manager_match_simulation_screen.dart';
import 'manager_tactics_screen.dart';
import 'manager_matches_screen.dart';
import 'manager_season_screen.dart';

class ManagerDashboardScreen extends StatefulWidget {
  final int teamId;
  final int userId;
  final String teamName;

  const ManagerDashboardScreen({
    super.key,
    required this.teamId,
    required this.userId,
    required this.teamName,
  });



  @override
  State<ManagerDashboardScreen> createState() =>
      _ManagerDashboardScreenState();
}

class _ManagerDashboardScreenState extends State<ManagerDashboardScreen> {
  late Future<ManagerTeamOverviewModel> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<ManagerTeamOverviewModel> _load() {
    return ManagerModeService.getTeamOverview(
      teamId: widget.teamId,
      userId: widget.userId,
    );
  }

  Future<void> _refresh() async {
    final future = _load();
    setState(() => _future = future);
    await future;
  }

  Color _progressColor(int value) {
    if (value >= 75) return const Color(0xFF16A34A);
    if (value >= 50) return const Color(0xFFF59E0B);
    return const Color(0xFFDC2626);
  }

  Widget _buildMetricCard({
    required String title,
    required int value,
    required IconData icon,
  }) {
    final color = _progressColor(value);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$value',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: value / 100,
              minHeight: 7,
              backgroundColor: const Color(0xFFE5E7EB),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopPlayerCard(ManagerTopPlayer player) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFFDBEAFE),
            child: Text(
              player.fullName.isNotEmpty ? player.fullName[0].toUpperCase() : '?',
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
                    fontSize: 15,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  player.position,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Готовность ${player.readiness}',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Форма ${player.formValue}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

 Widget _buildHeader() {
  return Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Менеджер команды',
          style: TextStyle(
            fontSize: 13,
            color: Colors.white70,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          widget.teamName,
          style: const TextStyle(
            fontSize: 24,
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ManagerTacticsScreen(
                        teamId: widget.teamId,
                        userId: widget.userId,
                      ),
                    ),
                  );
                  _refresh();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF1D4ED8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.sports_soccer),
                label: const Text('Тактика'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ManagerLineupScreen(
                        teamId: widget.teamId,
                        userId: widget.userId,
                      ),
                    ),
                  );
                  _refresh();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDBEAFE),
                  foregroundColor: const Color(0xFF1D4ED8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.groups_2),
                label: const Text('Состав'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ManagerMatchSimulationScreen(
                    teamId: widget.teamId,
                    userId: widget.userId,
                    teamName: widget.teamName,
                  ),
                ),
              );
              _refresh();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDCFCE7),
              foregroundColor: const Color(0xFF166534),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.play_circle_fill_rounded),
            label: const Text('Матч'),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ManagerMatchesScreen(
                        teamId: widget.teamId,
                        teamName: widget.teamName,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEFF6FF),
                  foregroundColor: const Color(0xFF1D4ED8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.sports_soccer),
                label: const Text('Матчи'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ManagerSeasonScreen(
                        teamId: widget.teamId,
                        teamName: widget.teamName,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEEF2FF),
                  foregroundColor: const Color(0xFF4338CA),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.emoji_events_outlined),
                label: const Text('Сезон'),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
  Widget _buildRecommendations(ManagerTeamOverviewModel model) {
    final teamState = model.teamState;
    final recommendations = <String>[];

    if (teamState.teamFitness < 50) {
      recommendations.add('У команды низкая свежесть. Нужен восстановительный цикл.');
    }
    if (teamState.teamMorale < 50) {
      recommendations.add('Мораль команды просела. Нужны игровые минуты и позитивный результат.');
    }
    if (teamState.injuriesCount > 0) {
      recommendations.add('Есть игроки с высоким риском травмы. Лучше снизить нагрузку.');
    }
    if (recommendations.isEmpty) {
      recommendations.add('Команда в хорошем состоянии. Можно усиливать тактическую подготовку.');
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Рекомендации штаба',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),
          ...recommendations.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Icon(Icons.circle, size: 8, color: Color(0xFF2563EB)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      e,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF334155),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFF8FAFC),
        foregroundColor: const Color(0xFF111827),
        title: const Text('Тренерский штаб'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<ManagerTeamOverviewModel>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const SizedBox(height: 40),
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  Text(
                    'Ошибка: ${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ],
              );
            }

            final model = snapshot.data!;
            final state = model.teamState;

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                _buildHeader(),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.08,
                  children: [
                    _buildMetricCard(
                      title: 'Форма команды',
                      value: state.teamForm,
                      icon: Icons.trending_up,
                    ),
                    _buildMetricCard(
                      title: 'Мораль',
                      value: state.teamMorale,
                      icon: Icons.emoji_events,
                    ),
                    _buildMetricCard(
                      title: 'Свежесть',
                      value: state.teamFitness,
                      icon: Icons.favorite,
                    ),
                    _buildMetricCard(
                      title: 'Сыгранность',
                      value: state.tacticalFamiliarity,
                      icon: Icons.hub,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildRecommendations(model),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Лучшие игроки по готовности',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...model.topPlayers.map(_buildTopPlayerCard),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}