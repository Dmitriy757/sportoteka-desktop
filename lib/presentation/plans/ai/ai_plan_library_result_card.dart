import 'package:flutter/material.dart';

class AiPlanLibraryResultCard extends StatelessWidget {
  final String title;
  final String date;
  final String folderName;
  final VoidCallback onOpen;

  const AiPlanLibraryResultCard({
    super.key,
    required this.title,
    required this.date,
    required this.folderName,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3FBF7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.edit_document,
                  color: Color(0xFF067A46),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [date, folderName]
                          .where((e) => e.trim().isNotEmpty)
                          .join(' · '),
                      style: const TextStyle(
                        color: Color(0xFF667085),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
