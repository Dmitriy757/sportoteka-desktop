import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'dart:convert';

class AddVenueScreen extends StatefulWidget {
  final int userId;
  final Map<String, dynamic>? venue; // ДОБАВЛЕНО

  const AddVenueScreen({
    super.key,
    required this.userId,
    this.venue, // ДОБАВЛЕНО
  });

  @override
  State<AddVenueScreen> createState() => _AddVenueScreenState();
}

class _AddVenueScreenState extends State<AddVenueScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _conditionsController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String? _selectedCategory;

  File? _imageFile;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    if (widget.venue != null) {
      _titleController.text = widget.venue!['title'] ?? '';
      _addressController.text = widget.venue!['address'] ?? '';
      _selectedCategory = widget.venue!['category'] ?? '';
      _conditionsController.text = widget.venue!['conditions'] ?? '';
      _descriptionController.text = widget.venue!['description'] ?? '';
    }
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _imageFile = File(picked.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildCustomHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: _buildFormContent(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomHeader() {
    return Container(
      padding: const EdgeInsets.only(top: 50, left: 20, right: 20, bottom: 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E74C4), Color(0xFF007AD9)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.venue != null ? 'Редактировать площадку' : 'Добавить площадку',
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Категории спорта',
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 80,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildCategoryIcon('Футбол', Icons.sports_soccer),
                _buildCategoryIcon('Хоккей', Icons.sports_hockey),
                _buildCategoryIcon('Баскетбол', Icons.sports_basketball),
                _buildCategoryIcon('Волейбол', Icons.sports_volleyball),
                _buildCategoryIcon('Теннис', Icons.sports_tennis),
                _buildCategoryIcon('Прочее', Icons.sports),

              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryIcon(String title, IconData icon) {
    final isSelected = _selectedCategory == title;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedCategory = title);
      },
      child: Container(
        width: 70,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.white24,
          shape: BoxShape.circle,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? const Color(0xFF1E74C4) : Colors.white, size: 28),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? const Color(0xFF1E74C4) : Colors.white,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabeledInput('Название площадки', _titleController),
        const SizedBox(height: 12),
        _buildLabeledInput('Адрес', _addressController),
        const SizedBox(height: 12),
        _buildLabeledInput('Условия бронирования', _conditionsController),
        const SizedBox(height: 12),
        _buildLabeledInput('Описание', _descriptionController, maxLines: 3),
        const SizedBox(height: 20),
        Text(
          'Фотография',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[300]!),
            ),
            alignment: Alignment.center,
            child: _imageFile != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(_imageFile!, fit: BoxFit.cover, width: double.infinity),
                  )
                : widget.venue != null && widget.venue!['image_url'] != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(widget.venue!['image_url'], fit: BoxFit.cover, width: double.infinity),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.cloud_upload_outlined, color: Colors.grey[600], size: 40),
                          const SizedBox(height: 8),
                          Text(
                            'Нажмите, чтобы загрузить фото',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
          ),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _submitForm,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E74C4),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
              elevation: 4,
            ),
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : Text(
                    widget.venue != null ? 'Сохранить изменения' : 'Сохранить площадку',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildLabeledInput(String label, TextEditingController controller, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.grey[100],
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF1E74C4)),
            ),
          ),
          validator: (value) => value == null || value.isEmpty ? 'Поле не может быть пустым' : null,
        ),
      ],
    );
  }
Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
   if (_selectedCategory == null || _selectedCategory!.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Пожалуйста, выберите категорию спорта')),
    );
    return;
  }

    setState(() => _isLoading = true);

    final uri = widget.venue == null
        ? Uri.parse('https://sportotekaapp.ru/api/add_venue.php')
        : Uri.parse('https://sportotekaapp.ru/api/update_venue.php');

    final request = http.MultipartRequest('POST', uri);

    request.fields['user_id'] = widget.userId.toString();
    request.fields['title'] = _titleController.text.trim();
    request.fields['address'] = _addressController.text.trim();
    request.fields['category'] = _selectedCategory ?? '';
    request.fields['conditions'] = _conditionsController.text.trim();
    request.fields['description'] = _descriptionController.text.trim();

    if (widget.venue != null) {
      request.fields['id'] = widget.venue!['id'].toString(); // передаём ID для обновления
    }

    if (_imageFile != null) {
      final imageFile = await http.MultipartFile.fromPath(
        'image',
        _imageFile!.path,
        filename: path.basename(_imageFile!.path),
      );
      request.files.add(imageFile);
    }

    try {
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        if (!mounted) return;
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.venue != null ? 'Изменения сохранены!' : 'Площадка добавлена!')),
        );
      } else {
        throw Exception('Ошибка: $responseBody');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
