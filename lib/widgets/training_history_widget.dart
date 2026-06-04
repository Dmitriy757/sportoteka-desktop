import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class TrainingHistoryWidget extends StatefulWidget {
  final int playerId;

  const TrainingHistoryWidget({super.key, required this.playerId});

  @override
  State<TrainingHistoryWidget> createState() => _TrainingHistoryWidgetState();
}

class _TrainingHistoryWidgetState extends State<TrainingHistoryWidget> {
  List<dynamic> trainings = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTrainings();
  }

  Future<void> _fetchTrainings() async {
    try {
      final uri = Uri.parse(
        'https://sportotekaapp.ru/api/get_player_trainings.php?player_id=${widget.playerId}',
      );
      final res = await http.get(uri);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          setState(() => trainings = data['trainings'] ?? []);
        }
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(22),
          child: CircularProgressIndicator(color: _CmrColors.green),
        ),
      );
    }

    if (trainings.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: _CmrDecor.softCard(),
        child: const Row(
          children: [
            _CmrIconBadge(icon: Icons.fitness_center_rounded),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Нет назначенных тренировок',
                style: TextStyle(
                  color: _CmrColors.muted,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: trainings
          .whereType<Map>()
          .map((training) => _buildCard(Map<String, dynamic>.from(training)))
          .toList(),
    );
  }

  Widget _buildCard(Map<String, dynamic> training) {
    final title = '${training['title'] ?? 'Без названия'}';
    final date = '${training['date'] ?? ''}'.trim();
    final type = '${training['training_type'] ?? ''}'.trim();
    final progress = training['progress_score']?.toString() ?? '-';
    final comment = '${training['coach_comment'] ?? ''}'.trim();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: _CmrDecor.panel(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _CmrIconBadge(icon: Icons.fitness_center_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _CmrColors.text,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        height: 1.18,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (date.isNotEmpty) _pill(Icons.calendar_today_rounded, date),
                        if (type.isNotEmpty) _pill(Icons.category_rounded, type),
                        _pill(Icons.trending_up_rounded, 'Прогресс: $progress / 10'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: _CmrDecor.softCard(radius: 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.chat_bubble_outline_rounded, color: _CmrColors.green, size: 19),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      comment,
                      style: const TextStyle(
                        color: _CmrColors.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _pill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: _CmrColors.greenSoft,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: _CmrColors.green),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: _CmrColors.green,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _CmrColors {
  static const Color panel = Colors.white;
  static const Color soft = Color(0xFFF6F8FA);
  static const Color text = Color(0xFF101828);
  static const Color muted = Color(0xFF667085);
  static const Color green = Color(0xFF1F7A4D);
  static const Color greenSoft = Color(0xFFF2F7F4);
}

class _CmrDecor {
  static BoxDecoration panel({double radius = 28}) => BoxDecoration(
        color: _CmrColors.panel,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.018),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      );

  static BoxDecoration softCard({double radius = 22}) => BoxDecoration(
        color: _CmrColors.soft,
        borderRadius: BorderRadius.circular(radius),
      );
}

class _CmrIconBadge extends StatelessWidget {
  final IconData icon;

  const _CmrIconBadge({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: _CmrColors.greenSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(icon, color: _CmrColors.green, size: 22),
    );
  }
}
