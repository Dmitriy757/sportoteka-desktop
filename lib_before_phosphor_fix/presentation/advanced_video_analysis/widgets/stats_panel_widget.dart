// lib/presentation/advanced_video_analysis/widgets/stats_panel_widget.dart

import 'package:flutter/material.dart';

class StatsPanelWidget extends StatelessWidget {
  final Map<String, dynamic> stats;

  const StatsPanelWidget({
    super.key,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    final shots = _num(stats['shots']);
    final shotsOnTarget = _num(stats['shots_on_target']);
    final passes = _num(stats['passes']);
    final sprints = _num(stats['sprints']);
    final possession = _num(stats['possession'], fallback: 50);
    final players = _num(stats['players_count']);

    return Positioned(
      left: 12,
      right: 12,
      bottom: 12,
      child: IgnorePointer(
        ignoring: true,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Container(
            constraints: const BoxConstraints(maxHeight: 58),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.68),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StatItem(icon: '👥', label: 'Игроки', value: players.toStringAsFixed(0)),
                const SizedBox(width: 14),
                _StatItem(icon: '⚽', label: 'Удары', value: shots.toStringAsFixed(0)),
                const SizedBox(width: 14),
                _StatItem(icon: '🎯', label: 'В створ', value: shotsOnTarget.toStringAsFixed(0)),
                const SizedBox(width: 14),
                _StatItem(icon: '🔄', label: 'Передачи', value: passes.toStringAsFixed(0)),
                const SizedBox(width: 14),
                _StatItem(icon: '🏃', label: 'Спринты', value: sprints.toStringAsFixed(0)),
                const SizedBox(width: 14),
                _StatItem(icon: '📊', label: 'Владение', value: '${possession.toStringAsFixed(0)}%'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  num _num(dynamic value, {num fallback = 0}) {
    if (value is num) return value;
    if (value is String) return num.tryParse(value) ?? fallback;
    return fallback;
  }
}

class _StatItem extends StatelessWidget {
  final String icon;
  final String label;
  final String value;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            '$icon $label',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            style: const TextStyle(
              color: Color(0xFF00A750),
              fontSize: 14,
              height: 1.0,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
