import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
    final uri = Uri.parse('https://sportotekaapp.ru/api/get_player_trainings.php?player_id=${widget.playerId}');
    final res = await http.get(uri);

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        setState(() {
          trainings = data['trainings'];
        });
      }
    }

    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return isLoading
        ? const Center(child: CircularProgressIndicator())
        : trainings.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(16),
                child: Text("Нет назначенных тренировок", style: TextStyle(color: Colors.grey)),
              )
            : Column(
                children: trainings.map((training) => _buildCard(training)).toList(),
              );
  }

  Widget _buildCard(Map<String, dynamic> training) {
    final title = training['title'] ?? 'Без названия';
    final date = training['date'] ?? '';
    final type = training['training_type'] ?? '';
    final progress = training['progress_score']?.toString() ?? '-';
    final comment = training['coach_comment'] ?? '';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F9FF),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: const Color(0xFF1E74C4), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔹 Заголовок и дата
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 16, color: Color(0xFF1E74C4)),
              const SizedBox(width: 6),
              Text(date, style: const TextStyle(color: Color(0xFF1E74C4), fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text("Тип: $type", style: const TextStyle(color: Colors.black87)),
          const SizedBox(height: 8),

          // 🔹 Прогресс
          Row(
            children: [
              const Icon(Icons.trending_up, size: 18, color: Colors.blueGrey),
              const SizedBox(width: 6),
              Text("Прогресс: $progress / 10", style: const TextStyle(fontSize: 14)),
            ],
          ),

          // 🔹 Комментарий тренера
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text("Комментарий тренера:", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(comment),
          ]
        ],
      ),
    );
  }
}
