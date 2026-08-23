import 'package:flutter/material.dart';

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final List<Map<String, String>> achievements = [
      {
        'title': 'Победа в турнире',
        'description': 'Кубок Минска, 2024 год',
      },
      {
        'title': 'Лучший игрок месяца',
        'description': 'Февраль 2025',
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Достижения'),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        itemCount: achievements.length,
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) {
          final achievement = achievements[index];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              title: Text(achievement['title']!, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(achievement['description']!),
              leading: const Icon(Icons.emoji_events_outlined),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            ),
          );
        },
      ),
    );
  }
}
