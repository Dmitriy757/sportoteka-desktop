import 'package:flutter/material.dart';

import 'package:sportoteka/core/theme/app_typography.dart';

class AiMatchWorkspaceCard extends StatelessWidget {
  final String opponent;
  final String date;
  final String status;
  final VoidCallback? onOpenMatch;
  final VoidCallback? onRunAi;
  final VoidCallback? onOpenStatistics;

  const AiMatchWorkspaceCard({
    super.key,
    required this.opponent,
    required this.date,
    required this.status,
    this.onOpenMatch,
    this.onRunAi,
    this.onOpenStatistics,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6ECE8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sports_soccer_rounded, color: Color(0xFF078548)),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Матч против $opponent',
                      style: AppTypography.sectionTitle(),
                    ),
                    Text(
                      '$date · $status',
                      style: AppTypography.secondary(color: const Color(0xFF667085)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: onOpenMatch,
                icon: const Icon(Icons.open_in_new_rounded, size: 17),
                label: const Text('Открыть матч'),
              ),
              OutlinedButton.icon(
                onPressed: onOpenStatistics,
                icon: const Icon(Icons.analytics_outlined, size: 17),
                label: const Text('Статистика'),
              ),
              OutlinedButton.icon(
                onPressed: onRunAi,
                icon: const Icon(Icons.auto_awesome_rounded, size: 17),
                label: const Text('ИИ-анализ'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
