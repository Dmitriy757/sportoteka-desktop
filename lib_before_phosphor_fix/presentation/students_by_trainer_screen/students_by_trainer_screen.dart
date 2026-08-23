import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:sportoteka/presentation/student_profile_screen/student_profile_screen.dart';

class StudentsByTrainerScreen extends StatefulWidget {
  final int trainerId;

  const StudentsByTrainerScreen({super.key, required this.trainerId});

  @override
  State<StudentsByTrainerScreen> createState() => _StudentsByTrainerScreenState();
}

class _StudentsByTrainerScreenState extends State<StudentsByTrainerScreen> {
  bool isLoading = true;
  List<dynamic> data = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final url = Uri.parse(
        'https://sportotekaapp.ru/api/get_students_by_trainer.php?trainer_id=${widget.trainerId}');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      setState(() {
        data = json.decode(response.body);
        isLoading = false;
      });
    } else {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // ✅ Красивая шапка
          Container(
            padding: const EdgeInsets.only(top: 50, left: 20, right: 20, bottom: 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF1E74C4), Color(0xFF007AD9)]),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    height: 40,
                    width: 40,
                    margin: const EdgeInsets.only(right: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                ),
                const Expanded(
                  child: Text(
                    'Ученики по классам',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // ✅ Основной контент
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : data.isEmpty
                    ? const Center(child: Text("Нет данных"))
                    : ListView.builder(
                        itemCount: data.length,
                        itemBuilder: (context, index) {
                          final classItem = data[index];
                          return ExpansionTile(
                            title: Text(
                              "Класс: ${classItem['class_name']} • ${classItem['sport_type']}",
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text("Школа: ${classItem['school_name'] ?? 'Неизвестно'}"),
                            children: (classItem['students'] as List).map((student) {
                              return ListTile(
                                leading: const Icon(Icons.person_outline),
                                title: Text("${student['first_name']} ${student['last_name']}"),
                                subtitle: Text("Email родителя: ${student['parent_email']}"),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => StudentProfileScreen(
                                        studentId: int.parse(student['id'].toString()),
                                      ),
                                    ),
                                  );
                                },
                              );
                            }).toList(),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
