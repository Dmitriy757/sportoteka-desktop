import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

class AddStudentScreen extends StatefulWidget {
  final int schoolId;
  final int classId;

  const AddStudentScreen({
    super.key,
    required this.schoolId,
    required this.classId,
  });

  @override
  State<AddStudentScreen> createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends State<AddStudentScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _parentEmailController = TextEditingController();
  final _studentEmailController = TextEditingController(); // ← Новое поле

  Future<void> _selectDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime(2010),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (pickedDate != null) {
      _birthDateController.text =
          "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
    }
  }

  Future<void> _submit() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final birthDate = _birthDateController.text.trim();
    final parentEmail = _parentEmailController.text.trim();
    final studentEmail = _studentEmailController.text.trim();
    final schoolId = widget.schoolId;
    final classId = widget.classId;

    if ([firstName, lastName, birthDate, parentEmail, studentEmail].any((e) => e.isEmpty)) {
      Get.snackbar("Ошибка", "Заполните все поля");
      return;
    }

    final response = await http.post(
      Uri.parse("https://sportotekaapp.ru/api/add_student.php"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "first_name": firstName,
        "last_name": lastName,
        "birth_date": birthDate,
        "parent_email": parentEmail,
        "student_email": studentEmail,
        "school_id": schoolId,
        "class_id": classId,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data["status"] == "success") {
        Get.snackbar("Успех", "Ученик добавлен");
        Navigator.pop(context);
      } else {
        Get.snackbar("Ошибка", data["message"] ?? "Не удалось добавить ученика");
      }
    } else {
      Get.snackbar("Ошибка", "Ошибка сервера: ${response.statusCode}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF005AAB),
        title: const Text("Добавить ученика", style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildTextField(_firstNameController, 'Имя ученика'),
              _buildTextField(_lastNameController, 'Фамилия ученика'),
              _buildTextField(_birthDateController, 'Дата рождения', readOnly: true, onTap: _selectDate),
              _buildTextField(_parentEmailController, 'Email родителя'),
              _buildTextField(_studentEmailController, 'Email ученика (логин)'), // ← Новое поле
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF005AAB),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Отправить заявку", style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {bool isNumber = false, bool readOnly = false, VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        readOnly: readOnly,
        onTap: onTap,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          fillColor: Colors.white,
          filled: true,
        ),
      ),
    );
  }
}
