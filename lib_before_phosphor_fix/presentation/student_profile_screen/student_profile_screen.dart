// 🔄 ПОЛНОСТЬЮ СТИЛИЗОВАННЫЙ student_profile_screen.dart с загрузкой фото и сохранением всей логики

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:sportoteka/presentation/edit_student_screen/edit_student_screen.dart';

class StudentProfileScreen extends StatefulWidget {
  final int studentId;

  const StudentProfileScreen({super.key, required this.studentId});

  @override
  State<StudentProfileScreen> createState() => _StudentProfileScreenState();
}

class _StudentProfileScreenState extends State<StudentProfileScreen> {
  Map<String, dynamic>? student;
  List<dynamic> metrics = [];
  List<dynamic> achievements = [];
  List<dynamic> medicalRecords = [];
  bool isLoading = true;
  String? photoUrl;

  @override
  void initState() {
    super.initState();
    _loadStudentData();
  }

  Future<void> _loadStudentData() async {
    setState(() => isLoading = true);

    final profileRes = await http.get(Uri.parse('https://sportotekaapp.ru/api/get_student_profile.php?id=${widget.studentId}'));
    final medicalRes = await http.get(Uri.parse('https://sportotekaapp.ru/api/student_medical/get_student_medical.php?student_id=${widget.studentId}'));

    if (profileRes.statusCode == 200) {
      final data = json.decode(profileRes.body);
      setState(() {
        student = data['student'];
        metrics = data['metrics'] ?? [];
        achievements = data['achievements'] ?? [];
        photoUrl = student?['photo'];
      });
    }

    if (medicalRes.statusCode == 200) {
      final med = json.decode(medicalRes.body);
      setState(() {
        medicalRecords = med['medical'] ?? [];
      });
    }

    setState(() => isLoading = false);
  }

  Future<void> _pickAndUploadPhoto(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);

    if (pickedFile == null) return;

    final request = http.MultipartRequest('POST', Uri.parse('https://sportotekaapp.ru/api/upload_student_photo.php'));
    request.fields['student_id'] = widget.studentId.toString();
    request.files.add(await http.MultipartFile.fromPath('photo', pickedFile.path));

    final response = await request.send();

    if (response.statusCode == 200) {
      _loadStudentData();
    }
  }

  void _editStudent() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditStudentScreen(studentId: widget.studentId)),
    );
    if (result == true) _loadStudentData();
  }

  void _showAddMetricDialog() {
    final titleController = TextEditingController();
    final valueController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Добавить метрику'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Название')),
            TextField(controller: valueController, decoration: const InputDecoration(labelText: 'Значение')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () async {
              await http.post(Uri.parse('https://sportotekaapp.ru/api/add_student_metric.php'), body: {
                'student_id': widget.studentId.toString(),
                'title': titleController.text,
                'value': valueController.text,
              });
              Navigator.pop(context);
              _loadStudentData();
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _showEditMetricDialog(Map<String, dynamic> metric) {
    final titleController = TextEditingController(text: metric['title']);
    final valueController = TextEditingController(text: metric['value']);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Редактировать метрику'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Название')),
            TextField(controller: valueController, decoration: const InputDecoration(labelText: 'Значение')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () async {
              await http.post(Uri.parse('https://sportotekaapp.ru/api/update_student_metric.php'), body: {
                'id': metric['id'].toString(),
                'title': titleController.text,
                'value': valueController.text,
              });
              Navigator.pop(context);
              _loadStudentData();
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _deleteMetric(int id) async {
    await http.post(Uri.parse('https://sportotekaapp.ru/api/delete_student_metric.php'), body: {'id': id.toString()});
    _loadStudentData();
  }

  void _showAddMedicalDialog() {
    final typeController = TextEditingController();
    final titleController = TextEditingController();
    final valueController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Добавить запись'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: typeController, decoration: const InputDecoration(labelText: 'Тип')),
            TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Заголовок')),
            TextField(controller: valueController, decoration: const InputDecoration(labelText: 'Значение')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () async {
              await http.post(Uri.parse('https://sportotekaapp.ru/api/student_medical/add_student_medical.php'), body: {
                'student_id': widget.studentId.toString(),
                'title': titleController.text,
                'value': valueController.text,
              });
              Navigator.pop(context);
              _loadStudentData();
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _showEditMedicalDialog(Map<String, dynamic> record) {
    final titleController = TextEditingController(text: record['title']);
    final valueController = TextEditingController(text: record['value']);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Редактировать запись'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Заголовок')),
            TextField(controller: valueController, decoration: const InputDecoration(labelText: 'Значение')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
          ElevatedButton(
            onPressed: () async {
              await http.post(Uri.parse('https://sportotekaapp.ru/api/student_medical/update_student_medical.php'), body: {
                'id': record['id'].toString(),
                'title': titleController.text,
                'value': valueController.text,
              });
              Navigator.pop(context);
              _loadStudentData();
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _deleteMedicalRecord(int id) async {
    await http.post(Uri.parse('https://sportotekaapp.ru/api/student_medical/delete_student_medical.php'), body: {'id': id.toString()});
    _loadStudentData();
  }

  Widget _buildRow(String title, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 4, height: 20, color: const Color(0xFF005AAB), margin: const EdgeInsets.only(right: 12)),
            Expanded(child: RichText(text: TextSpan(style: const TextStyle(fontSize: 16, color: Colors.black), children: [TextSpan(text: "$title: ", style: const TextStyle(fontWeight: FontWeight.bold)), TextSpan(text: value)])))
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (isLoading || student == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            Container(
              padding: const EdgeInsets.only(top: 50, left: 20, right: 20, bottom: 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFF1E74C4), Color(0xFF007AD9)]),
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Профиль ученика', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.edit, color: Colors.white), onPressed: _editStudent),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const TabBar(
                    indicatorColor: Colors.white,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white70,
                    tabs: [
                      Tab(text: 'Общие'),
                      Tab(text: 'Метрики'),
                      Tab(text: 'Достижения'),
                      Tab(text: 'Медкарта'),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      GestureDetector(
                        onTap: () => _pickAndUploadPhoto(ImageSource.gallery),
                        onLongPress: () => _pickAndUploadPhoto(ImageSource.camera),
                        child: CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.grey.shade200,
                          backgroundImage: photoUrl != null ? NetworkImage(photoUrl!) : null,
                          child: photoUrl == null ? const Icon(Icons.person, size: 40, color: Colors.blue) : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF1E74C4), Color(0xFF005AAB)]),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Text("«Лучший игрок — это тот, кто никогда не сдаётся»", style: TextStyle(color: Colors.white, fontSize: 16, fontStyle: FontStyle.italic)),
                      ),
                      _buildRow("ФИО", "${student!['first_name']} ${student!['last_name']}"),
                      _buildRow("Дата рождения", student!['birth_date'] ?? '-'),
                      _buildRow("Email родителя", student!['parent_email'] ?? '-')
                    ],
                  ),
                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text("Метрики", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          ),
                          IconButton(icon: const Icon(Icons.add), onPressed: _showAddMetricDialog),
                        ],
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: metrics.length,
                          itemBuilder: (context, index) {
                            final m = metrics[index];
                            return ListTile(
                              title: Text("${m['title']}: ${m['value']}"),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(icon: const Icon(Icons.edit), onPressed: () => _showEditMetricDialog(m)),
                                  IconButton(icon: const Icon(Icons.delete), onPressed: () => _deleteMetric(m['id'])),
                                ],
                              ),
                            );
                          },
                        ),
                      )
                    ],
                  ),
                  ListView(
                    padding: const EdgeInsets.all(16),
                    children: achievements.isEmpty
                        ? [const Text("Нет достижений")]
                        : achievements.map((a) => _buildRow(a['title'] ?? '-', a['description'] ?? '-')).toList(),
                  ),
                  ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Медицинские записи", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          IconButton(icon: const Icon(Icons.add), onPressed: _showAddMedicalDialog),
                        ],
                      ),
                      ...medicalRecords.map((m) => ListTile(
                            title: Text("${m['type']}: ${m['title']}"),
                            subtitle: Text(m['value'] ?? ''),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blue),
                                  onPressed: () => _showEditMedicalDialog(m),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _deleteMedicalRecord(m['id']),
                                )
                              ],
                            ),
                          ))
                    ],
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
