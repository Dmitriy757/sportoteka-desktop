import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/presentation/training_screen/models/player_model.dart';

class CreateTrainingProgramScreen extends StatefulWidget {
  const CreateTrainingProgramScreen({super.key});

  @override
  State<CreateTrainingProgramScreen> createState() => _CreateTrainingProgramScreenState();
}

class _CreateTrainingProgramScreenState extends State<CreateTrainingProgramScreen> {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  List<Map<String, dynamic>> coachTeams = [];
  int? selectedTeamId;
  String selectedTeamName = "";

  List<PlayerModel> players = [];
  Set<int> selectedPlayerIds = {};

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadCoachTeams();
  }

  Future<void> loadCoachTeams() async {
    final coachId = await PrefUtils.getUserId();
    if (coachId == null) return;

    final response = await http.post(
      Uri.parse('https://sportotekaapp.ru/api/get_team_by_coach.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'coach_id': coachId}),
    );

    final data = jsonDecode(response.body);
    if (data['status'] == 'success') {
      setState(() {
        coachTeams = List<Map<String, dynamic>>.from(data['teams']);
        if (coachTeams.isNotEmpty) {
          selectedTeamId = coachTeams[0]['id'];
          selectedTeamName = coachTeams[0]['name'];
          loadPlayers();
        }
      });
    }
  }

  Future<void> loadPlayers() async {
    if (selectedTeamId == null) return;

    setState(() => isLoading = true);

    final response = await http.post(
      Uri.parse('https://sportotekaapp.ru/api/get_players.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'team_id': selectedTeamId}),
    );

    final data = jsonDecode(response.body);
    if (data['status'] == 'success') {
      final List<PlayerModel> loaded = (data['players'] as List)
          .map((item) => PlayerModel.fromJson(item))
          .toList();
      setState(() {
        players = loaded;
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
    }
  }

  Future<void> _createProgram() async {
    final title = titleController.text.trim();
    final description = descriptionController.text.trim();

    if (title.isEmpty || selectedPlayerIds.isEmpty || selectedTeamId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните название, выберите команду и игроков')),
      );
      return;
    }

    final response = await http.post(
      Uri.parse('https://sportotekaapp.ru/api/create_training_program.php'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'title': title,
        'description': description,
        'team_id': selectedTeamId,
        'player_ids': selectedPlayerIds.toList(),
      }),
    );

    final data = jsonDecode(response.body);
    if (data['status'] == 'success') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Программа сохранена')),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data['message'] ?? 'Ошибка сохранения')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Создание программы")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(labelText: 'Название программы'),
                  ),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(labelText: 'Описание'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<int>(
                    value: selectedTeamId,
                    hint: const Text('Выберите команду'),
                    items: coachTeams.map((team) {
                      return DropdownMenuItem<int>(
                        value: team['id'],
                        child: Text(team['name']),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedTeamId = value;
                        selectedTeamName = coachTeams.firstWhere((t) => t['id'] == value)['name'];
                        selectedPlayerIds.clear();
                        loadPlayers();
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text("Игроки команды: $selectedTeamName", style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 10),
                  players.isEmpty
                      ? const Text('Нет доступных игроков')
                      : Expanded(
                          child: ListView.builder(
                            itemCount: players.length,
                            itemBuilder: (context, index) {
                              final player = players[index];
                              final isSelected = selectedPlayerIds.contains(player.id);
                              return Card(
                                child: ListTile(
                                  leading: CircleAvatar(child: Text(player.firstName[0])),
                                  title: Text('${player.firstName} ${player.lastName}'),
                                  subtitle: Text(player.nationality),
                                  trailing: Checkbox(
                                    value: isSelected,
                                    onChanged: (value) {
                                      setState(() {
                                        if (value == true) {
                                          selectedPlayerIds.add(player.id);
                                        } else {
                                          selectedPlayerIds.remove(player.id);
                                        }
                                      });
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _createProgram,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      backgroundColor: const Color(0xFF005AAB),
                    ),
                    child: const Text('Сохранить программу', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
    );
  }
}

