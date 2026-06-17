import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class EditSchoolScreen extends StatefulWidget {
  final Map<String, dynamic> school;

  const EditSchoolScreen({super.key, required this.school});

  @override
  State<EditSchoolScreen> createState() => _EditSchoolScreenState();
}

class _EditSchoolScreenState extends State<EditSchoolScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _descriptionController;
  String _selectedSport = 'Футбол';
  final List<String> _sports = ['Футбол', 'Баскетбол', 'Волейбол', 'Хоккей', 'Теннис'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.school['name']);
    _addressController = TextEditingController(text: widget.school['address'] ?? '');
    _descriptionController = TextEditingController(text: widget.school['description'] ?? '');
    _selectedSport = widget.school['sport_type'] ?? 'Футбол';
  }

  Future<void> _submit() async {
    final response = await http.post(
      Uri.parse('https://sportotekaapp.ru/api/update_school.php'),
      body: {
        'school_id': widget.school['id'].toString(),
        'name': _nameController.text,
        'sport_type': _selectedSport,
        'address': _addressController.text,
        'description': _descriptionController.text,
      },
    );

    if (response.statusCode == 200) {
      final result = json.decode(response.body);
      if (result['success'] == true) {
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Ошибка')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка при обновлении школы')),
      );
    }
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: 'Введите $label'.toLowerCase(),
            filled: true,
            fillColor: Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E74C4),
        title: const Text('Редактировать школу'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildTextField(label: 'Название школы', controller: _nameController),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Вид спорта', style: TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _selectedSport,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: _sports.map((sport) {
                      return DropdownMenuItem(value: sport, child: Text(sport));
                    }).toList(),
                    onChanged: (value) => setState(() => _selectedSport = value!),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildTextField(label: 'Адрес', controller: _addressController),
              _buildTextField(label: 'Описание', controller: _descriptionController, maxLines: 3),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Сохранить школу'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E74C4),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: const TextStyle(fontSize: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _submit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
