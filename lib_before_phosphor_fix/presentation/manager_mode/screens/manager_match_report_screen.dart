import 'package:flutter/material.dart';

import '../models/manager_match_report_model.dart';
import '../services/manager_mode_service.dart';

class ManagerMatchReportScreen extends StatefulWidget {
  final int matchId;
  final String teamName;

  const ManagerMatchReportScreen({
    super.key,
    required this.matchId,
    required this.teamName,
  });

  @override
  State<ManagerMatchReportScreen> createState() =>
      _ManagerMatchReportScreenState();
}

class _ManagerMatchReportScreenState extends State<ManagerMatchReportScreen> {
  late Future<ManagerMatchReportModel> _future;

  @override
  void initState() {
    super.initState();
    _future = ManagerModeService.getMatchReport(matchId: widget.matchId);
  }

  Color _resultColor(String result) {
    if (result == 'W') return const Color(0xFF16A34A);
    if (result == 'L') return const Color(0xFFDC2626);
    return const Color(0xFFF59E0B);
  }

  IconData _eventIcon(String type) {
    switch (type) {
      case 'goal':
        return Icons.sports_soccer;
      case 'yellow_card':
        return Icons.crop_portrait;
      case 'injury':
        return Icons.healing;
      default:
        return Icons.flash_on;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Отчёт по матчу'),
        backgroundColor: const Color(0xFFF8FAFC),
        elevation: 0,
        foregroundColor: const Color(0xFF111827),
      ),
      body: FutureBuilder<ManagerMatchReportModel>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Ошибка: ${snapshot.error}'),
            );
          }

          final report = snapshot.data!;
          final match = report.match;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _resultColor(match.resultLabel),
                      _resultColor(match.resultLabel).withOpacity(0.82),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    Text(
                      widget.teamName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${match.homeScore} : ${match.awayScore}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 42,
                      ),
                    ),
                    Text(
                      match.opponentName,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Тактика: ${match.formationUsed} • ${match.playStyle}',
                      style: const TextStyle(color: Colors.white),
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
                  _statCard('Владение', '${match.possessionHome}%'),
                  _statCard('Удары', '${match.shotsHome}'),
                  _statCard('В створ', '${match.shotsOnTargetHome}'),
                  _statCard('Сила команды', '${match.teamStrength}'),
                ],
              ),
              const SizedBox(height: 16),
              _sectionTitle('Ключевые события'),
              ...report.events.map(
                (e) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        backgroundColor: const Color(0xFFEFF6FF),
                        child: Icon(
                          _eventIcon(e.eventType),
                          color: const Color(0xFF2563EB),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          e.description,
                          style: const TextStyle(
                            color: Color(0xFF111827),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _sectionTitle('Оценки игроков'),
              ...report.playerStats.map(
                (p) => Container(
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
                          Expanded(
                            child: Text(
                              p.fullName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF111827),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDBEAFE),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              p.rating.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Color(0xFF1D4ED8),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _miniChip('Голы ${p.goals}'),
                          _miniChip('Пасы ${p.passesCompleted}'),
                          _miniChip('Удары ${p.shots}'),
                          _miniChip('Ассисты ${p.assists}'),
                          _miniChip('Отборы ${p.tackles}'),
                          _miniChip('Перехваты ${p.interceptions}'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: Color(0xFF111827),
        ),
      ),
    );
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
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF374151),
        ),
      ),
    );
  }
}