import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:get/get.dart';

class TeamPlayersScreen extends StatefulWidget {
  final int teamId;
  final String teamName;

  const TeamPlayersScreen({super.key, required this.teamId, required this.teamName});

  @override
  State<TeamPlayersScreen> createState() => _TeamPlayersScreenState();
}

class _TeamPlayersScreenState extends State<TeamPlayersScreen> {
  List<dynamic> players = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchPlayers();
  }

  Future<void> fetchPlayers() async {
    final url = 'https://sportotekaapp.ru/api/get_players_by_team.php?team_id=${widget.teamId}';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            players = data['players'];
            loading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Ошибка загрузки игроков: $e');
    }
  }

  Widget buildPlayerCard(dynamic player) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          radius: 24,
          backgroundImage: player['photo'] != null && player['photo'].toString().isNotEmpty
              ? NetworkImage(player['photo'])
              : const AssetImage('assets/images/default_player.png') as ImageProvider,
        ),
        title: Text('${player['first_name']} ${player['last_name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(player['position'] ?? 'Позиция не указана'),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          // Тут можешь открыть профиль игрока
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: Text('${player['first_name']} ${player['last_name']}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Позиция: ${player['position'] ?? '-'}'),
                  Text('Номер: ${player['number'] ?? '-'}'),
                  Text('Гражданство: ${player['nationality'] ?? '-'}'),
                  Text('Дата рождения: ${player['birthDate'] ?? '-'}'),
                  const SizedBox(height: 12),
                  Text('Достижения: ${player['achievements'] ?? 'Нет данных'}'),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Закрыть')),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.teamName)),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : players.isEmpty
              ? const Center(child: Text('Игроки не найдены'))
              : ListView(
                  children: players.map(buildPlayerCard).toList(),
                ),
    );
  }
}
