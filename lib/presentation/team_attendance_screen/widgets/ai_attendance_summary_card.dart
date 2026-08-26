import 'package:flutter/material.dart';
import 'package:sportoteka/core/theme/app_typography.dart';

class AiAttendanceSummaryCard extends StatelessWidget {
  final int present;
  final int absent;
  final int late;
  final int injured;
  final VoidCallback? onOpenJournal;

  const AiAttendanceSummaryCard({
    super.key,
    required this.present,
    required this.absent,
    required this.late,
    required this.injured,
    this.onOpenJournal,
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
              const Icon(Icons.fact_check_rounded, color: Color(0xFF078548)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Посещение мероприятия',
                  style: AppTypography.sectionTitle().copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: onOpenJournal,
                child: const Text('Открыть'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Chip(label: 'Были', value: present, color: const Color(0xFF16A34A)),
              _Chip(label: 'Не были', value: absent, color: const Color(0xFFEF4444)),
              _Chip(label: 'Опоздали', value: late, color: const Color(0xFFF59E0B)),
              _Chip(label: 'Травма', value: injured, color: const Color(0xFF7C3AED)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _Chip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(.09),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$label · $value',
        style: AppTypography.chip(color: color, active: true).copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}
