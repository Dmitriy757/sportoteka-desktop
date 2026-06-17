import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class EditStudentScreen extends StatefulWidget {
  final int studentId;

  const EditStudentScreen({super.key, required this.studentId});

  @override
  State<EditStudentScreen> createState() => _EditStudentScreenState();
}

class _EditStudentScreenState extends State<EditStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadStudent();
  }

  Future<void> _loadStudent() async {
    final res = await http.get(Uri.parse(
        'https://sportotekaapp.ru/api/get_student_profile.php?id=${widget.studentId}'));
    if (res.statusCode == 200) {
      final data = json.decode(res.body);
      final s = data['student'];
      setState(() {
        _firstNameController.text = s['first_name'] ?? '';
        _lastNameController.text = s['last_name'] ?? '';
        _birthDateController.text = s['birth_date'] ?? '';
        _emailController.text = s['parent_email'] ?? '';
      });
    }
  }

  Future<void> _saveStudent() async {
    final res = await http.post(
      Uri.parse('https://sportotekaapp.ru/api/update_student.php'),
      body: {
        'id': widget.studentId.toString(),
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'birth_date': _birthDateController.text.trim(),
        'parent_email': _emailController.text.trim(),
      },
    );

    if (res.statusCode == 200) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Редактировать ученика")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(controller: _firstNameController, decoration: const InputDecoration(labelText: 'Имя')),
              TextFormField(controller: _lastNameController, decoration: const InputDecoration(labelText: 'Фамилия')),
              TextFormField(controller: _birthDateController, decoration: const InputDecoration(labelText: 'Дата рождения')),
              TextFormField(controller: _emailController, decoration: const InputDecoration(labelText: 'Email родителя')),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: _saveStudent, child: const Text('Сохранить'))
            ],
          ),
        ),
      ),
    );
  }
}
