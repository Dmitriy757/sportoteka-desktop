import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:sportoteka/core/utils/pref_utils.dart';

class MyProgramsScreen extends StatefulWidget {
  const MyProgramsScreen({super.key});

  @override
  State<MyProgramsScreen> createState() => _MyProgramsScreenState();
}

class _MyProgramsScreenState extends State<MyProgramsScreen> {
  List<Map<String, dynamic>> programs = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadPrograms();
  }

 Future<void> loadPrograms() async {
  final coachId = await PrefUtils.getUserId();
  if (coachId == null) return;

  final response = await http.post(
    Uri.parse('https://sportotekaapp.ru/api/get_training_programs.php'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'coach_id': coachId}),
  );

  final data = jsonDecode(response.body);
  if (data['status'] == 'success') {
    setState(() {
      programs = List<Map<String, dynamic>>.from(data['programs']);
      isLoading = false;
    });
  } else {
    setState(() => isLoading = false);
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Мои программы"),
        backgroundColor: const Color(0xFF005AAB),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : programs.isEmpty
              ? const Center(child: Text("Программы не найдены"))
              : ListView.builder(
                  itemCount: programs.length,
                  itemBuilder: (context, index) {
                    final program = programs[index];
                    return ListTile(
                      title: Text(program['title'] ?? ''),
                      subtitle: Text(program['description'] ?? ''),
                    );
                  },
                ),
    );
  }
}
