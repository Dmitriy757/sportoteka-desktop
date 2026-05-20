// lib/presentation/team_screen/edit_player_screen.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class EditPlayerScreen extends StatefulWidget {
  const EditPlayerScreen({super.key});

  @override
  State<EditPlayerScreen> createState() => _EditPlayerScreenState();
}

class _EditPlayerScreenState extends State<EditPlayerScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController birthDateController = TextEditingController();
  final TextEditingController nationalityController = TextEditingController();
  final TextEditingController positionController = TextEditingController();
  final TextEditingController jerseyNumberController = TextEditingController();
  final TextEditingController statValueController = TextEditingController();

  final Map<String, String> playerStats = {};
  String? selectedMetric;

  File? selectedImage;
  String? uploadedPhotoUrl;

  late Map<String, dynamic> player;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  bool saving = false;

  final List<String> availableMetrics = const [
    'Рост (см)',
    'Вес (кг)',
    'Игры',
    'Голы',
    'Голевые передачи',
    'Жёлтые карточки',
    'Красные карточки',
    'Минуты на поле',
    'Скорость (км/ч)',
    'Выносливость',
    'Сила удара',
    'Точность передач',
  ];

  @override
  void initState() {
    super.initState();

    player = Map<String, dynamic>.from(Get.arguments ?? {});

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _animationController.forward();

    _fillFields();
  }

  void _fillFields() {
    if (player.containsKey('first_name') || player.containsKey('last_name')) {
      firstNameController.text = '${player['first_name'] ?? ''}';
      lastNameController.text = '${player['last_name'] ?? ''}';
    } else if (player.containsKey('fullName')) {
      final parts = '${player['fullName']}'.trim().split(' ');
      firstNameController.text = parts.isNotEmpty ? parts.first : '';
      lastNameController.text =
          parts.length > 1 ? parts.sublist(1).join(' ') : '';
    }

    birthDateController.text =
        '${player['birth_date'] ?? player['birthDate'] ?? ''}';
    nationalityController.text = '${player['nationality'] ?? ''}';
    positionController.text = '${player['position'] ?? ''}';
    jerseyNumberController.text =
        '${player['jersey_number'] ?? player['number'] ?? ''}';

    uploadedPhotoUrl = '${player['photo'] ?? player['photo_url'] ?? ''}';

    final rawSportData = '${player['sport_data'] ?? ''}'.trim();
    if (rawSportData.isNotEmpty && rawSportData != 'null') {
      final parts = rawSportData.split(',');
      for (final p in parts) {
        final split = p.split(':');
        if (split.length >= 2) {
          playerStats[split[0].trim()] = split.sublist(1).join(':').trim();
        }
      }
    }
  }

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    birthDateController.dispose();
    nationalityController.dispose();
    positionController.dispose();
    jerseyNumberController.dispose();
    statValueController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  int _playerId() {
    return int.tryParse(
          '${player['player_id'] ?? player['id'] ?? player['user_id'] ?? 0}',
        ) ??
        0;
  }

  String _fullName() {
    final full = '${firstNameController.text.trim()} ${lastNameController.text.trim()}'
        .trim();
    return full.isEmpty ? 'Игрок' : full;
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() => selectedImage = File(picked.path));
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2007),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _C.blue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: _C.text,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: _C.blue),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        birthDateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  void _addStat() {
    if (selectedMetric != null && statValueController.text.trim().isNotEmpty) {
      setState(() {
        playerStats[selectedMetric!] = statValueController.text.trim();
        selectedMetric = null;
        statValueController.clear();
      });
    } else {
      Get.snackbar(
        'Внимание',
        'Выберите метрику и введите значение',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: _C.orange,
        colorText: Colors.white,
      );
    }
  }

  void _removeStat(String key) {
    setState(() => playerStats.remove(key));
  }

  Future<void> _savePlayer() async {
    final firstName = firstNameController.text.trim();
    final lastName = lastNameController.text.trim();
    final birthDate = birthDateController.text.trim();
    final nationality = nationalityController.text.trim();
    final position = positionController.text.trim();
    final jerseyNumber = int.tryParse(jerseyNumberController.text.trim()) ?? 0;
    final sportData =
        playerStats.entries.map((e) => "${e.key}: ${e.value}").join(", ");
    final playerId = _playerId();

    if (playerId <= 0) {
      Get.snackbar(
        'Ошибка',
        'Не удалось определить ID игрока',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: _C.red,
        colorText: Colors.white,
      );
      return;
    }

    if ([firstName, lastName, birthDate, nationality].any((e) => e.isEmpty)) {
      Get.snackbar(
        'Ошибка',
        'Заполните все обязательные поля',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: _C.red,
        colorText: Colors.white,
      );
      return;
    }

    setState(() => saving = true);

    try {
      if (selectedImage != null) {
        final request = http.MultipartRequest(
          'POST',
          Uri.parse('https://sportotekaapp.ru/api/upload_player_photo.php'),
        );

        request.files.add(
          await http.MultipartFile.fromPath('photo', selectedImage!.path),
        );

        final response = await request.send();
        final body = await response.stream.bytesToString();
        final jsonResp = jsonDecode(body);

        if (jsonResp['status'] == 'success') {
          uploadedPhotoUrl = jsonResp['url'];
        }
      }

      final response = await http.post(
        Uri.parse('https://sportotekaapp.ru/api/update_player.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'player_id': playerId,
          'first_name': firstName,
          'last_name': lastName,
          'birth_date': birthDate,
          'nationality': nationality,
          'sport_data': sportData,
          'position': position,
          'jersey_number': jerseyNumber,
          'photo_url': uploadedPhotoUrl ?? '',
        }),
      );

      final json = jsonDecode(response.body);

      if (json['status'] == 'success') {
        Get.snackbar(
          'Успех',
          'Данные игрока обновлены',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: _C.primaryGreen,
          colorText: Colors.white,
        );

        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) Get.back(result: true);
      } else {
        Get.snackbar(
          'Ошибка',
          json['message'] ?? 'Не удалось обновить игрока',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: _C.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Ошибка',
        'Произошла ошибка: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: _C.red,
        colorText: Colors.white,
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        foregroundColor: _C.text,
        title: const Text(
          'Редактировать игрока',
          style: TextStyle(
            color: _C.text,
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: _IconButtonBox(
              icon: Icons.photo_camera_rounded,
              color: _C.blue,
              onTap: _pickImage,
            ),
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 360, child: _buildSideCard()),
                      const SizedBox(width: 16),
                      Expanded(child: _buildFormContent()),
                    ],
                  )
                : Column(
                    children: [
                      _buildSideCard(),
                      const SizedBox(height: 16),
                      _buildFormContent(),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildSideCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(radius: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPhoto(),
          const SizedBox(height: 18),
          Text(
            _fullName(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _C.text,
              fontSize: 24,
              height: 1.05,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            positionController.text.trim().isEmpty
                ? 'Амплуа не указано'
                : positionController.text.trim(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _C.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          _InfoTile(
            icon: Icons.badge_rounded,
            title: 'ID игрока',
            value: '${_playerId()}',
            color: _C.blue,
          ),
          const SizedBox(height: 10),
          _InfoTile(
            icon: Icons.analytics_rounded,
            title: 'Метрики',
            value: '${playerStats.length} добавлено',
            color: _C.orange,
          ),
          const SizedBox(height: 10),
          _InfoTile(
            icon: Icons.save_rounded,
            title: 'Сохранение',
            value: 'Обновление через API',
            color: _C.primaryGreen,
          ),
        ],
      ),
    );
  }

  Widget _buildPhoto() {
    return Center(
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Container(
            width: 124,
            height: 124,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: _C.blueSoft,
              borderRadius: BorderRadius.circular(42),
              border: Border.all(color: _C.blue.withOpacity(.16), width: 1.2),
            ),
            child: selectedImage != null
                ? Image.file(selectedImage!, fit: BoxFit.cover)
                : (uploadedPhotoUrl != null &&
                        uploadedPhotoUrl!.trim().isNotEmpty &&
                        uploadedPhotoUrl != 'null'
                    ? Image.network(
                        uploadedPhotoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.person_rounded,
                          color: _C.blue,
                          size: 48,
                        ),
                      )
                    : const Icon(
                        Icons.person_rounded,
                        color: _C.blue,
                        size: 48,
                      )),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: _pickImage,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _C.primaryGreen,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: _C.primaryGreen.withOpacity(.24),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.camera_alt_rounded,
                size: 19,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormContent() {
    return Column(
      children: [
        _FormSection(
          title: 'Основная информация',
          subtitle: 'ФИО, дата рождения и гражданство',
          icon: Icons.person_outline_rounded,
          color: _C.blue,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: firstNameController,
                      label: 'Имя',
                      icon: Icons.person_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      controller: lastNameController,
                      label: 'Фамилия',
                      icon: Icons.person_rounded,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      controller: birthDateController,
                      label: 'Дата рождения',
                      icon: Icons.cake_rounded,
                      readOnly: true,
                      onTap: _selectDate,
                      suffixIcon: Icons.calendar_today_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      controller: nationalityController,
                      label: 'Гражданство',
                      icon: Icons.flag_rounded,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _FormSection(
          title: 'Игровая информация',
          subtitle: 'Амплуа и игровой номер',
          icon: Icons.sports_soccer_rounded,
          color: _C.primaryGreen,
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildTextField(
                  controller: positionController,
                  label: 'Позиция на поле',
                  icon: Icons.sports_soccer_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  controller: jerseyNumberController,
                  label: 'Игровой номер',
                  icon: Icons.tag_rounded,
                  isNumber: true,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _FormSection(
          title: 'Спортивные метрики',
          subtitle: 'Добавьте или удалите показатели игрока',
          icon: Icons.analytics_rounded,
          color: _C.orange,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      value: selectedMetric,
                      isExpanded: true,
                      decoration: _inputDecoration(
                        'Выберите метрику',
                        icon: Icons.tune_rounded,
                      ),
                      items: availableMetrics
                          .map(
                            (m) => DropdownMenuItem(
                              value: m,
                              child: Text(m),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => selectedMetric = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      controller: statValueController,
                      label: 'Значение',
                      icon: Icons.edit_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  _CompactButton(
                    icon: Icons.add_rounded,
                    text: 'Добавить',
                    color: _C.orange,
                    onTap: _addStat,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (playerStats.isEmpty)
                const _EmptyMetrics()
              else
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: playerStats.entries
                        .map((e) => _MetricChip(
                              title: e.key,
                              value: e.value,
                              icon: _getMetricIcon(e.key),
                              onRemove: () => _removeStat(e.key),
                            ))
                        .toList(),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.centerRight,
          child: _PrimarySubmitButton(
            onTap: _savePlayer,
            loading: saving,
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool readOnly = false,
    VoidCallback? onTap,
    bool isNumber = false,
    IconData? suffixIcon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        onTap: onTap,
        onChanged: (_) => setState(() {}),
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        style: const TextStyle(
          color: _C.text,
          fontWeight: FontWeight.w800,
        ),
        decoration: _inputDecoration(label, icon: icon, suffixIcon: suffixIcon),
      ),
    );
  }

  InputDecoration _inputDecoration(
    String label, {
    IconData? icon,
    IconData? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon == null ? null : Icon(icon, color: _C.muted, size: 20),
      suffixIcon:
          suffixIcon == null ? null : Icon(suffixIcon, color: _C.blue, size: 18),
      filled: true,
      fillColor: _C.soft2,
      labelStyle: const TextStyle(
        color: _C.muted,
        fontWeight: FontWeight.w700,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _C.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _C.blue, width: 1.4),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: _C.border),
      ),
    );
  }

  IconData _getMetricIcon(String metric) {
    if (metric.contains('Рост')) return Icons.height_rounded;
    if (metric.contains('Вес')) return Icons.monitor_weight_rounded;
    if (metric.contains('Гол')) return Icons.sports_soccer_rounded;
    if (metric.contains('Скорость')) return Icons.speed_rounded;
    if (metric.contains('Выносливость')) return Icons.timer_rounded;
    if (metric.contains('Сила')) return Icons.fitness_center_rounded;
    if (metric.contains('Точность')) return Icons.track_changes_rounded;
    if (metric.contains('карточ')) return Icons.warning_rounded;
    return Icons.trending_up_rounded;
  }
}

class _C {
  static const Color bg = Color(0xFFFBFBFA);
  static const Color text = Color(0xFF0F172A);
  static const Color muted = Color(0xFF64748B);
  static const Color border = Color(0xFFE7ECF2);
  static const Color soft = Color(0xFFF8FAFC);
  static const Color soft2 = Color(0xFFFAFCFB);

  static const Color primaryGreen = Color(0xFF00A750);
  static const Color footballGreenSoft = Color(0xFFEAF5EE);

  static const Color blue = Color(0xFF2563EB);
  static const Color blueSoft = Color(0xFFEFF6FF);

  static const Color orange = Color(0xFFEA580C);
  static const Color orangeSoft = Color(0xFFFFF1E8);

  static const Color red = Color(0xFFDC2626);
  static const Color redSoft = Color(0xFFFEE2E2);

  static Color softFor(Color color) {
    if (color == blue) return blueSoft;
    if (color == orange) return orangeSoft;
    if (color == red) return redSoft;
    return footballGreenSoft;
  }
}

BoxDecoration _cardDecoration({double radius = 28}) {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: _C.border),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(.035),
        blurRadius: 22,
        offset: const Offset(0, 12),
      ),
    ],
  );
}

class _FormSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final Widget child;

  const _FormSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(radius: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconBox(icon: icon, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _C.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _C.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _IconBox({
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: _C.softFor(color),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(.16)),
      ),
      child: Icon(icon, color: color, size: 23),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _InfoTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _C.softFor(color),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(.14)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _C.text,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _C.muted,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IconButtonBox extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _IconButtonBox({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: _C.softFor(color),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(.14)),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}

class _CompactButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final VoidCallback onTap;

  const _CompactButton({
    required this.icon,
    required this.text,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(.18),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrimarySubmitButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool loading;

  const _PrimarySubmitButton({
    required this.onTap,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: loading ? null : onTap,
      child: Container(
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          color: _C.primaryGreen,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: _C.primaryGreen.withOpacity(.24),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            else
              const Icon(Icons.save_rounded, color: Colors.white),
            const SizedBox(width: 10),
            const Text(
              'Сохранить изменения',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final VoidCallback onRemove;

  const _MetricChip({
    required this.title,
    required this.value,
    required this.icon,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 10, right: 6, top: 7, bottom: 7),
      decoration: BoxDecoration(
        color: _C.orangeSoft,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: _C.orange.withOpacity(.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _C.orange, size: 16),
          const SizedBox(width: 6),
          Text(
            '$title: $value',
            style: const TextStyle(
              color: _C.text,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            borderRadius: BorderRadius.circular(99),
            onTap: onRemove,
            child: const Padding(
              padding: EdgeInsets.all(3),
              child: Icon(Icons.close_rounded, size: 16, color: _C.red),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyMetrics extends StatelessWidget {
  const _EmptyMetrics();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _C.soft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.border),
      ),
      child: const Column(
        children: [
          Icon(Icons.analytics_outlined, size: 40, color: _C.muted),
          SizedBox(height: 8),
          Text(
            'Нет добавленных метрик',
            style: TextStyle(
              color: _C.muted,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}