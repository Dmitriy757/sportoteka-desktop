// medical_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:sportoteka/core/utils/pref_utils.dart';

class MedicalScreen extends StatefulWidget {
  final int userId;
  const MedicalScreen({super.key, required this.userId});

  @override
  State<MedicalScreen> createState() => _MedicalScreenState();
}

class _MedicalScreenState extends State<MedicalScreen> {
  List<Map<String, dynamic>> records = [];
  List<Map<String, dynamic>> teams = [];
  List<Map<String, dynamic>> players = [];
  Map<int, String> playerNames = {}; // id -> full name
  int? selectedTeamId;
  int? selectedPlayerId;
  bool isLoading = true;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _valueController = TextEditingController();
  String _selectedType = 'осмотр';

  @override
  void initState() {
    super.initState();
    _loadRecords();
    _loadTeams();
  }

 Future<void> _loadRecords() async {
  if (selectedTeamId == null) return;

  final uri = Uri.parse('https://sportotekaapp.ru/api/medical/get_medical_records.php?team_id=$selectedTeamId');
  final res = await http.get(uri);

  if (res.statusCode == 200) {
    final data = json.decode(res.body);
    setState(() {
      records = List<Map<String, dynamic>>.from(data['records'] ?? []);
      isLoading = false;
    });
  } else {
    setState(() => isLoading = false);
  }
}
  Future<void> _loadTeams() async {
    final res = await http.post(
      Uri.parse('https://sportotekaapp.ru/api/get_team_by_coach.php'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({"coach_id": widget.userId}),
    );
    final data = json.decode(res.body);
    if (data['status'] == 'success') {
      setState(() => teams = List<Map<String, dynamic>>.from(data['teams']));
    }
  }

  Future<void> _loadPlayers(int teamId) async {
    final res = await http.get(Uri.parse('https://sportotekaapp.ru/api/get_players_by_team.php?team_id=$teamId'));
    final data = json.decode(res.body);
    if (data['status'] == 'success') {
      final playerList = List<Map<String, dynamic>>.from(data['players']);
      setState(() {
        players = playerList;
        for (var p in playerList) {
          playerNames[p['id']] = "${p['first_name']} ${p['last_name']}";
        }
      });
    }
  }

  Future<void> _addRecord() async {
    if (selectedPlayerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите игрока')),
      );
      return;
    }

    final uri = Uri.parse('https://sportotekaapp.ru/api/medical/add_medical_record.php');
    final res = await http.post(uri, body: {
      'user_id': selectedPlayerId.toString(),
      'type': _selectedType,
      'title': _titleController.text.trim(),
      'value': _valueController.text.trim(),
    });

    final data = json.decode(res.body);
    if (data['success'] == true) {
      _titleController.clear();
      _valueController.clear();
      _loadRecords();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data['error'] ?? 'Ошибка добавления записи')),
      );
    }
  }

  Future<void> _deleteRecord(String id) async {
    final uri = Uri.parse('https://sportotekaapp.ru/api/medical/delete_medical_record.php');
    final res = await http.post(uri, body: { 'id': id });
    final data = json.decode(res.body);
    if (data['success'] == true) {
      _loadRecords();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data['error'] ?? 'Ошибка удаления')),
      );
    }
  }

  void _editRecordDialog(Map<String, dynamic> record) {
    _titleController.text = record['title'] ?? '';
    _valueController.text = record['value'] ?? '';
    _selectedType = record['type'] ?? 'осмотр';
    selectedPlayerId = int.tryParse(record['user_id'].toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Редактировать запись'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Заголовок'),
            ),
            TextField(
              controller: _valueController,
              decoration: const InputDecoration(labelText: 'Описание'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              final uri = Uri.parse('https://sportotekaapp.ru/api/medical/update_medical_record.php');
              final res = await http.post(uri, body: {
                'id': record['id'].toString(),
                'title': _titleController.text.trim(),
                'value': _valueController.text.trim(),
              });
              final data = json.decode(res.body);
              if (data['success'] == true) {
                Navigator.pop(context);
                _loadRecords();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(data['error'] ?? 'Ошибка обновления')),
                );
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  String _getPlayerName(int userId) {
    return playerNames[userId] ?? 'Игрок';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Медкарта'),
        backgroundColor: const Color(0xFF005AAB),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: _selectedType,
                  items: const [
                    DropdownMenuItem(value: 'осмотр', child: Text('Осмотр')),
                    DropdownMenuItem(value: 'вакцинация', child: Text('Вакцинация')),
                    DropdownMenuItem(value: 'травма', child: Text('Травма')),
                    DropdownMenuItem(value: 'замер', child: Text('Замер')),
                    DropdownMenuItem(value: 'документ', child: Text('Документ')),
                  ],
                  onChanged: (value) => setState(() => _selectedType = value!),
                  decoration: const InputDecoration(labelText: 'Тип записи'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: selectedTeamId,
                  items: teams
                      .map((t) => DropdownMenuItem<int>(
                            value: t['id'],
                            child: Text(t['name']),
                          ))
                      .toList(),
                  onChanged: (id) {
                    setState(() {
                      selectedTeamId = id;
                      selectedPlayerId = null;
                      players = [];
                    });
                    if (id != null) _loadPlayers(id);
                        _loadRecords(); // добавим сюда
                  },
                  decoration: const InputDecoration(labelText: 'Выберите команду'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: selectedPlayerId,
                  items: players
                      .map((p) => DropdownMenuItem<int>(
                            value: p['id'],
                            child: Text("${p['first_name']} ${p['last_name']}"),
                          ))
                      .toList(),
                  onChanged: (id) => setState(() => selectedPlayerId = id),
                  decoration: const InputDecoration(labelText: 'Выберите игрока'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Заголовок'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _valueController,
                  decoration: const InputDecoration(labelText: 'Описание / значение'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _addRecord,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF005AAB)),
                  child: const Text('Добавить запись'),
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: records.length,
                    itemBuilder: (context, index) {
                      final record = records[index];
                      final userId = int.tryParse(record['user_id'].toString()) ?? 0;
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          title: Text(record['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_getPlayerName(userId), style: const TextStyle(color: Colors.blueAccent)),
                              Text(record['type'] ?? '', style: const TextStyle(color: Colors.black54)),
                              const SizedBox(height: 4),
                              Text(record['value'] ?? ''),
                              if ((record['file_url'] ?? '').isNotEmpty)
                                TextButton(
                                  onPressed: () {},
                                  child: const Text('Открыть вложение'),
                                ),
                              Text('Дата: ${record['date']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') _editRecordDialog(record);
                              if (value == 'delete') _deleteRecord(record['id'].toString());
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(value: 'edit', child: Text('Редактировать')),
                              const PopupMenuItem(value: 'delete', child: Text('Удалить')),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
