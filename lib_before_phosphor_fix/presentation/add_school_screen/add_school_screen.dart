import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:get/get.dart';

class AddSchoolScreen extends StatefulWidget {
  const AddSchoolScreen({super.key});

  @override
  State<AddSchoolScreen> createState() => _AddSchoolScreenState();
}

class _AddSchoolScreenState extends State<AddSchoolScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String _selectedSport = 'Футбол';
int? trainerId;

  final List<String> _sports = ['Футбол', 'Баскетбол', 'Волейбол', 'Хоккей', 'Теннис'];

  @override
  void initState() {
    super.initState();
    loadTrainerId();
  }

  Future<void> loadTrainerId() async {
    trainerId = await PrefUtils.getUserId();
    setState(() {});
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final address = _addressController.text.trim();
    final description = _descriptionController.text.trim();

    if (trainerId == null || name.isEmpty || address.isEmpty || _selectedSport.isEmpty) {
      Get.snackbar("Ошибка", "Заполните все поля");
      return;
    }

    final uri = Uri.parse("https://sportotekaapp.ru/api/add_school.php");

    try {
      final response = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "name": name,
          "address": address,
          "description": description,
          "sport_type": _selectedSport,
          "trainer_id": trainerId,
        }),
      );

      final result = jsonDecode(response.body);

      if (result["success"] == true) {
        Get.back();
        Get.snackbar("Успех", "Школа добавлена");
      } else {
        Get.snackbar("Ошибка", result["error"] ?? "Не удалось добавить школу");
      }
    } catch (e) {
      Get.snackbar("Ошибка", "Сетевая ошибка: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (trainerId == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FA),
      body: Column(
        children: [
          // Шапка
          Container(
            padding: const EdgeInsets.only(top: 50, left: 20, right: 20, bottom: 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF1E74C4), Color(0xFF007AD9)]),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
            ),
            width: double.infinity,
            child: Row(
              children: const [
                Icon(Icons.school, color: Colors.white, size: 28),
                SizedBox(width: 12),
                Text(
                  'Добавить школу',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          // Форма
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Название школы', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _nameController,
                      decoration: _inputDecoration('Введите название'),
                    ),
                    const SizedBox(height: 16),

                    const Text('Вид спорта', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: _selectedSport,
                      items: _sports.map((sport) {
                        return DropdownMenuItem(value: sport, child: Text(sport));
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => _selectedSport = value);
                      },
                      decoration: _inputDecoration('Выберите вид спорта'),
                    ),
                    const SizedBox(height: 16),

                    const Text('Адрес', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _addressController,
                      decoration: _inputDecoration('Введите адрес'),
                    ),
                    const SizedBox(height: 16),

                    const Text('Описание', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _descriptionController,
                      decoration: _inputDecoration('Краткое описание'),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),

                   SizedBox(
  width: double.infinity,
  child: ElevatedButton.icon(
    onPressed: _submit,
    icon: const Icon(Icons.check_circle_outline),
    label: const Text('Сохранить школу'),
    style: ElevatedButton.styleFrom(
      backgroundColor: const Color(0xFF1E74C4),     // 🔵 фон
      foregroundColor: Colors.white,                // ✅ белый текст и иконка
      padding: const EdgeInsets.symmetric(vertical: 14),
      textStyle: const TextStyle(fontSize: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    ),
  ),
),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: const Color(0xFFF5F8FB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }
}
