import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:get/get.dart';
import 'package:sportoteka/presentation/teams/team_players_screen.dart';

class TeamsTabScreen extends StatefulWidget {
  const TeamsTabScreen({Key? key}) : super(key: key);

  @override
  State<TeamsTabScreen> createState() => _TeamsTabScreenState();
}

class _TeamsTabScreenState extends State<TeamsTabScreen> {
  List<dynamic> teams = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchTeams();
  }

  Future<void> fetchTeams() async {
    try {
      final response = await http.get(Uri.parse('https://sportotekaapp.ru/api/get_teams_by_sport.php'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            teams = data['teams'];
            isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Ошибка при загрузке команд: $e');
    }
  }

  Widget buildTeamCard(dynamic team) {
    return GestureDetector(
      onTap: () {
        Get.to(() => TeamPlayersScreen(teamId: team['id'], teamName: team['name']));
      },
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ListTile(
          leading: CircleAvatar(
            backgroundImage: team['logo_url'] != null && team['logo_url'].toString().isNotEmpty
                ? NetworkImage(team['logo_url'])
                : const AssetImage('assets/images/default_team.png') as ImageProvider,
          ),
          title: Text(team['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(team['sport'] ?? 'Спорт не указан'),
          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Команды')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // Статическая команда "Динамо Минск"
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('Избранная команда', style: Theme.of(context).textTheme.titleMedium),
                ),
                buildTeamCard({
                  'id': 1,
                  'name': 'Динамо Минск',
                  'logo_url': 'https://dinamo-minsk.by/uploads/logo/logo.svg',
                  'sport': 'Футбол',
                }),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('Все команды', style: Theme.of(context).textTheme.titleMedium),
                ),
                ...teams.map(buildTeamCard).toList(),
              ],
            ),
    );
  }
}
