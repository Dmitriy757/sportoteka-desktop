import 'package:flutter/material.dart';

class AiMatchStatsModel {
  final int goals;
  final int shots;
  final int shotsOnGoal;
  final int freekicks;
  final int corners;
  final double possessionPercent;
  final double possessionMinutes;
  final int possessionWon;
  final int passesCompleted;
  final int passesTotal;
  final int interceptions;
  final int recoveries;

  const AiMatchStatsModel({
    required this.goals,
    required this.shots,
    required this.shotsOnGoal,
    required this.freekicks,
    required this.corners,
    required this.possessionPercent,
    required this.possessionMinutes,
    required this.possessionWon,
    required this.passesCompleted,
    required this.passesTotal,
    required this.interceptions,
    required this.recoveries,
  });

  factory AiMatchStatsModel.empty() {
    return const AiMatchStatsModel(
      goals: 0,
      shots: 0,
      shotsOnGoal: 0,
      freekicks: 0,
      corners: 0,
      possessionPercent: 0,
      possessionMinutes: 0,
      possessionWon: 0,
      passesCompleted: 0,
      passesTotal: 0,
      interceptions: 0,
      recoveries: 0,
    );
  }
}

class AiTimelineEvent {
  final String id;
  final String type;
  final String title;
  final int timeMs;
  final String? team;
  final String? playerName;
  final bool? success;
  final double confidence;

  const AiTimelineEvent({
    required this.id,
    required this.type,
    required this.title,
    required this.timeMs,
    this.team,
    this.playerName,
    this.success,
    this.confidence = 0,
  });
}

class AiPanelPlayerStats {
  final int? playerId;
  final String playerName;
  final int passesCompleted;
  final int passesTotal;
  final int shots;
  final int interceptions;
  final int recoveries;
  final int duelsWon;
  final int involvement;
  final double confidence;

  const AiPanelPlayerStats({
    required this.playerId,
    required this.playerName,
    required this.passesCompleted,
    required this.passesTotal,
    required this.shots,
    required this.interceptions,
    required this.recoveries,
    required this.duelsWon,
    required this.involvement,
    required this.confidence,
  });
}

class AiMatchAnalysisPanelWidget extends StatelessWidget {
  final bool isRunning;
  final bool loading;
  final String statusText;
  final AiMatchStatsModel homeStats;
  final AiMatchStatsModel awayStats;
  final List<AiPanelPlayerStats> playerStats;
  final List<AiTimelineEvent> timelineEvents;
  final VoidCallback onToggleAi;
  final VoidCallback onExport;
  final Function(int) onJumpToTime;
  final Function(AiTimelineEvent)? onApproveEvent;

  const AiMatchAnalysisPanelWidget({
    super.key,
    required this.isRunning,
    required this.loading,
    required this.statusText,
    required this.homeStats,
    required this.awayStats,
    required this.playerStats,
    required this.timelineEvents,
    required this.onToggleAi,
    required this.onExport,
    required this.onJumpToTime,
    this.onApproveEvent,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 16),
        _buildStats(),
        const SizedBox(height: 16),
        _buildPlayers(),
        const SizedBox(height: 16),
        _buildTimeline(),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_graph_rounded, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Анализ матча',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Авто-ТТД и match stats',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: isRunning,
            onChanged: (_) => onToggleAi(),
            activeColor: Colors.white,
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          _vsRow('Goals', homeStats.goals.toString(), awayStats.goals.toString()),
          _vsRow('Shots', homeStats.shots.toString(), awayStats.shots.toString()),
          _vsRow('Shots on goal', homeStats.shotsOnGoal.toString(), awayStats.shotsOnGoal.toString()),
          _vsRow('Freekicks', homeStats.freekicks.toString(), awayStats.freekicks.toString()),
          _vsRow('Corners', homeStats.corners.toString(), awayStats.corners.toString()),
          _vsRow('Possession %', '${homeStats.possessionPercent.toStringAsFixed(1)}%', '${awayStats.possessionPercent.toStringAsFixed(1)}%'),
          _vsRow('Possession won', homeStats.possessionWon.toString(), awayStats.possessionWon.toString()),
          _vsRow('Passes completed', homeStats.passesCompleted.toString(), awayStats.passesCompleted.toString()),
        ],
      ),
    );
  }

  Widget _vsRow(String label, String left, String right) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Text(
              left,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF475569),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(
            width: 48,
            child: Text(
              right,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayers() {
    if (playerStats.isEmpty) {
      return _empty('Нет AI-статистики по игрокам');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Игроки',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 10),
        ...playerStats.map((e) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  e.playerName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _chip('Пасы', '${e.passesCompleted}/${e.passesTotal}'),
                    _chip('Удары', '${e.shots}'),
                    _chip('Перехваты', '${e.interceptions}'),
                    _chip('Подборы', '${e.recoveries}'),
                    _chip('Вовлеч.', '${e.involvement}'),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _chip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildTimeline() {
    if (timelineEvents.isEmpty) {
      return _empty('Нет AI-событий');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'AI Таймлайн',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 10),
        ...timelineEvents.map((e) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_formatTime(e.timeMs)}'
                        '${e.playerName != null ? ' · ${e.playerName}' : ''}'
                        '${e.team != null ? ' · ${e.team}' : ''}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => onJumpToTime(e.timeMs),
                  icon: const Icon(Icons.play_circle_outline_rounded),
                ),
                if (onApproveEvent != null)
                  IconButton(
                    onPressed: () => onApproveEvent!(e),
                    icon: const Icon(Icons.check_circle_outline_rounded),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _empty(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF64748B),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _formatTime(int ms) {
    final totalSeconds = ms ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}