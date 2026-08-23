import 'package:flutter/material.dart';
import 'package:sportoteka/core/services/api_service.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';



class AddClassScreen extends StatefulWidget {
  final int schoolId;
  const AddClassScreen({super.key, required this.schoolId});

  @override
  State<AddClassScreen> createState() => _AddClassScreenState();
}

class _AddClassScreenState extends State<AddClassScreen> {
  final TextEditingController _nameController = TextEditingController();
  String _selectedSport = 'Футбол';
  final List<String> _sports = ['Футбол', 'Баскетбол', 'Волейбол', 'Хоккей', 'Теннис'];
  bool _isSubmitting = false;

  Future<void> _submit() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите название класса')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final trainerId = await PrefUtils.getUserId();
    print('🟦 Отправка данных:');
    print('Класс: $name');
    print('Вид спорта: $_selectedSport');
    print('Школа: ${widget.schoolId}');
    print('Тренер: $trainerId');
    

    final success = await ApiService.addClass(
      name: name,
      sportType: _selectedSport,
      schoolId: widget.schoolId,
      trainerId: trainerId ?? 0,
    );

    setState(() => _isSubmitting = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Класс успешно добавлен')),
      );
      Navigator.pop(context); // Закрыть экран
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка при добавлении класса')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Добавить класс')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Название класса'),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedSport,
              items: _sports.map((sport) {
                return DropdownMenuItem(
                  value: sport,
                  child: Text(sport),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedSport = value!;
                });
              },
              decoration: const InputDecoration(labelText: 'Вид спорта'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const CircularProgressIndicator()
                  : const Text('Добавить класс'),
            ),
          ],
        ),
      ),
    );
  }
}
