import 'package:flutter/material.dart';

class PlayerDetailScreen extends StatelessWidget {
  final Map<String, dynamic> player;

  const PlayerDetailScreen({super.key, required this.player});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(player['fullName'] ?? 'Игрок'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 60,
              backgroundImage: player['photo'] != null
                  ? NetworkImage(player['photo'])
                  : null,
              child: player['photo'] == null
                  ? const Icon(Icons.person, size: 60)
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              player['fullName'] ?? '',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (player['position'] != null || player['number'] != null)
              Text(
                '${player['position'] ?? ''} ${player['number'] != null ? '№${player['number']}' : ''}',
                style: const TextStyle(fontSize: 18),
              ),
            const SizedBox(height: 24),
            
            // Детальная информация
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildInfoRow('Дата рождения', player['birthDate']),
                    _buildInfoRow('Национальность', player['nationality']),
                    _buildInfoRow('Клуб', player['club']),
                    if (player['achievements'] != null && player['achievements'].isNotEmpty)
                      _buildInfoRow('Достижения', player['achievements']),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value ?? 'Не указано',
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}