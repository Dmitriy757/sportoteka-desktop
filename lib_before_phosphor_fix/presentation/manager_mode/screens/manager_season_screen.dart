import 'package:flutter/material.dart';

import '../models/manager_season_overview_model.dart';
import '../services/manager_mode_service.dart';

class ManagerSeasonScreen extends StatefulWidget {
  final int teamId;
  final String teamName;

  const ManagerSeasonScreen({
    super.key,
    required this.teamId,
    required this.teamName,
  });

  @override
  State<ManagerSeasonScreen> createState() => _ManagerSeasonScreenState();
}

class _ManagerSeasonScreenState extends State<ManagerSeasonScreen> {
  late Future<ManagerSeasonOverviewModel> _future;

  @override
  void initState() {
    super.initState();
    _future = ManagerModeService.getSeasonOverview(teamId: widget.teamId);
  }

  Color _formColor(String value) {
    if (value == 'W') return const Color(0xFF16A34A);
    if (value == 'L') return const Color(0xFFDC2626);
    return const Color(0xFFF59E0B);
  }

  Widget _statCard(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Color(0xFF6B7280))),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }

  Widget _leaderCard(String title, ManagerSeasonLeader? leader) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: leader == null
          ? Text(
              '$title: пока нет данных',
              style: const TextStyle(color: Color(0xFF6B7280)),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  leader.fullName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${leader.position} • ${leader.statValue}',
                  style: const TextStyle(
                    color: Color(0xFF2563EB),
                    fontWeight: FontWeight.w700,
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
        title: const Text('Сезон'),
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        foregroundColor: const Color(0xFF111827),
      ),
      body: FutureBuilder<ManagerSeasonOverviewModel>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Ошибка: ${snapshot.error}'));
          }

          final season = snapshot.data!;

          return ListView(
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
                      'Обзор сезона',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.teamName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Очки: ${season.points} • Разница: ${season.goalDiff >= 0 ? '+' : ''}${season.goalDiff}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                crossAxisCount: 2,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.2,
                children: [
                  _statCard('Сыграно', '${season.played}'),
                  _statCard('Победы', '${season.wins}'),
                  _statCard('Ничьи', '${season.draws}'),
                  _statCard('Поражения', '${season.losses}'),
                  _statCard('Голы', '${season.goalsFor}:${season.goalsAgainst}'),
                  _statCard('Очки', '${season.points}'),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Последняя форма',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: season.recentForm
                    .map(
                      (f) => Container(
                        width: 42,
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _formColor(f).withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          f,
                          style: TextStyle(
                            color: _formColor(f),
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 16),
              _leaderCard('Лучший бомбардир', season.topScorer),
              const SizedBox(height: 12),
              _leaderCard('Лучший ассистент', season.topAssist),
            ],
          );
        },
      ),
    );
  }
}