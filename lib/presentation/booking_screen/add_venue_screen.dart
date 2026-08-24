import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

import 'package:sportoteka/core/theme/app_typography.dart';

class AddVenueScreen extends StatefulWidget {
  final int userId;
  final Map<String, dynamic>? venue;

  const AddVenueScreen({
    super.key,
    required this.userId,
    this.venue,
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

  static const List<String> _categories = <String>[
    'Футбол',
    'Хоккей',
    'Баскетбол',
    'Волейбол',
    'Теннис',
    'Прочее',
  ];

  @override
  void initState() {
    super.initState();

    final venue = widget.venue;
    if (venue != null) {
      _titleController.text = '${venue['title'] ?? ''}';
      _addressController.text = '${venue['address'] ?? ''}';
      _selectedCategory = '${venue['category'] ?? ''}'.trim();
      _conditionsController.text = '${venue['conditions'] ?? ''}';
      _descriptionController.text = '${venue['description'] ?? ''}';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _addressController.dispose();
    _conditionsController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  TextStyle _t(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color color = _BookingUi.text,
    double height = 1.25,
  }) {
    return AppTypography.custom(
      size: size,
      weight: weight,
      color: color,
      height: height,
      letterSpacing: 0,
    );
  }

  Widget _dot(
    Color color, {
    double size = 5,
    bool glow = false,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: glow
            ? <BoxShadow>[
                BoxShadow(
                  color: color.withOpacity(.18),
                  blurRadius: size * 2,
                ),
              ]
            : null,
      ),
    );
  }

  Widget _brandDots({
    Color color = _BookingUi.green,
  }) {
    const values = <List<double>>[
      <double>[3.5, .34],
      <double>[4.5, .48],
      <double>[5.5, .68],
      <double>[6.5, 1],
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        for (int i = 0; i < values.length; i++) ...<Widget>[
          Container(
            width: values[i][0],
            height: values[i][0],
            decoration: BoxDecoration(
              color: color.withOpacity(values[i][1]),
              shape: BoxShape.circle,
            ),
          ),
          if (i != values.length - 1)
            const SizedBox(width: 3),
        ],
      ],
    );
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );

    if (picked != null && mounted) {
      setState(() => _imageFile = File(picked.path));
    }
  }

  String? _existingImage() {
    final raw = '${widget.venue?['image_url'] ?? widget.venue?['image_path'] ?? ''}'.trim();
    if (raw.isEmpty || raw.toLowerCase() == 'null') return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    final clean = raw.startsWith('/') ? raw.substring(1) : raw;
    return 'https://sportotekaapp.ru/$clean';
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);

    return Theme(
      data: base.copyWith(
        textTheme: base.textTheme.apply(
          fontFamily: AppTypography.fontFamily,
          bodyColor: _BookingUi.text,
          displayColor: _BookingUi.text,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: <Widget>[
              _header(),
              const Divider(
                height: 1,
                thickness: .6,
                color: _BookingUi.line,
              ),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                    children: <Widget>[
                      _section(
                        title: 'Категория',
                        subtitle: 'Выберите основной вид спорта',
                        color: _BookingUi.green,
                        child: _categoryGrid(),
                      ),
                      const SizedBox(height: 8),
                      _section(
                        title: 'Основная информация',
                        subtitle: 'Название, адрес и условия площадки',
                        color: _BookingUi.greenDark,
                        child: Column(
                          children: <Widget>[
                            _field(
                              'Название площадки',
                              _titleController,
                            ),
                            const SizedBox(height: 8),
                            _field(
                              'Адрес',
                              _addressController,
                            ),
                            const SizedBox(height: 8),
                            _field(
                              'Условия бронирования',
                              _conditionsController,
                              maxLines: 2,
                            ),
                            const SizedBox(height: 8),
                            _field(
                              'Описание',
                              _descriptionController,
                              maxLines: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      _section(
                        title: 'Фотография',
                        subtitle: 'Фото используется в каталоге площадок',
                        color: _BookingUi.amber,
                        child: _photoBlock(),
                      ),
                      const SizedBox(height: 12),
                      _saveButton(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      constraints: const BoxConstraints(minHeight: 62),
      padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
      child: Row(
        children: <Widget>[
          Material(
            color: _BookingUi.soft,
            borderRadius: BorderRadius.circular(9),
            child: InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(9),
              child: const SizedBox(
                width: 36,
                height: 36,
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 15,
                  color: _BookingUi.text,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          _brandDots(),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  widget.venue != null
                      ? 'Редактирование площадки'
                      : 'Новая площадка',
                  style: _t(
                    14.5,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Заполните карточку спортивного объекта',
                  style: _t(
                    9.6,
                    color: _BookingUi.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section({
    required String title,
    required String subtitle,
    required Color color,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: _BookingUi.soft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: _dot(
                  color,
                  size: 6,
                  glow: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: _t(
                        11.5,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: _t(
                        9.4,
                        color: _BookingUi.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _categoryGrid() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: _categories.map((category) {
        final selected = _selectedCategory == category;

        return Material(
          color: selected ? _BookingUi.greenSoft : Colors.white,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: () => setState(
              () => _selectedCategory = category,
            ),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _dot(
                    selected
                        ? _BookingUi.green
                        : _BookingUi.muted2,
                    size: selected ? 5 : 4,
                    glow: selected,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    category,
                    style: _t(
                      9.7,
                      weight:
                          selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected
                          ? _BookingUi.greenDark
                          : _BookingUi.text,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: _t(
        10.4,
        color: _BookingUi.text,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: _t(
          9.8,
          color: _BookingUi.muted,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 11,
          vertical: 11,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: BorderSide.none,
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Поле не может быть пустым';
        }
        return null;
      },
    );
  }

  Widget _photoBlock() {
    final existing = _existingImage();

    Widget preview;
    if (_imageFile != null) {
      preview = Image.file(
        _imageFile!,
        width: double.infinity,
        height: 180,
        fit: BoxFit.cover,
      );
    } else if (existing != null) {
      preview = Image.network(
        existing,
        width: double.infinity,
        height: 180,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _photoPlaceholder(),
      );
    } else {
      preview = _photoPlaceholder();
    }

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(9),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _pickImage,
        child: Column(
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: preview,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              child: Row(
                children: <Widget>[
                  _dot(
                    _imageFile != null || existing != null
                        ? _BookingUi.amber
                        : _BookingUi.muted2,
                    size: 4.5,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      _imageFile != null || existing != null
                          ? 'Нажмите, чтобы заменить фото'
                          : 'Добавить фотографию',
                      style: _t(
                        9.6,
                        weight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoPlaceholder() {
    return Container(
      height: 180,
      color: const Color(0xFFF0F4F1),
      alignment: Alignment.center,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _brandDots(color: _BookingUi.amber),
          const SizedBox(width: 9),
          Text(
            'Фотография площадки',
            style: _t(
              10.2,
              color: _BookingUi.muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _saveButton() {
    return Align(
      alignment: Alignment.centerRight,
      child: FilledButton(
        onPressed: _isLoading ? null : _submitForm,
        style: FilledButton.styleFrom(
          elevation: 0,
          backgroundColor: _BookingUi.green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 11,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(9),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                widget.venue != null
                    ? 'Сохранить изменения'
                    : 'Сохранить площадку',
                style: _t(
                  10.2,
                  weight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategory == null ||
        _selectedCategory!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Пожалуйста, выберите категорию спорта'),
        ),
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
      request.fields['id'] = '${widget.venue!['id']}';
    }

    if (_imageFile != null) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'image',
          _imageFile!.path,
          filename: path.basename(_imageFile!.path),
        ),
      );
    }

    try {
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        if (!mounted) return;
        Navigator.pop(context, true);
        return;
      }

      throw Exception('Ошибка: $responseBody');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}


class _BookingUi {
  static const Color green = Color(0xFF00A750);
  static const Color greenDark = Color(0xFF067A46);
  static const Color greenSoft = Color(0xFFF3FAF6);
  static const Color amber = Color(0xFFF59E0B);
  static const Color amberSoft = Color(0xFFFFF7E8);
  static const Color red = Color(0xFFD92D20);
  static const Color redSoft = Color(0xFFFFF1F1);
  static const Color text = Color(0xFF0B0F14);
  static const Color muted = Color(0xFF667085);
  static const Color muted2 = Color(0xFF98A2B3);
  static const Color soft = Color(0xFFF7F9F8);
  static const Color line = Color(0xFFEEF1EF);
}
