import 'package:flutter/material.dart';

class AiPlanPreviewCard extends StatelessWidget {
  final String title;
  final Map<String, dynamic> templateJson;
  final VoidCallback onOpen;

  const AiPlanPreviewCard({
    super.key,
    required this.title,
    required this.templateJson,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final raw = templateJson['exercises'];
    final exercises = raw is List
        ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : <Map<String, dynamic>>[];

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9ECEF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.edit_document, color: Color(0xFF067A46)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${templateJson['duration_minutes'] ?? 0} мин',
                style: const TextStyle(
                  color: Color(0xFF667085),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < exercises.length && i < 6; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3FBF7),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        color: Color(0xFF067A46),
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${exercises[i]['title'] ?? 'Упражнение'}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    '${exercises[i]['duration_minutes'] ?? 0} мин',
                    style: const TextStyle(
                      color: Color(0xFF667085),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 7),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.edit_rounded, size: 16),
              label: const Text('Открыть и изменить'),
            ),
          ),
        ],
      ),
    );
  }
}
