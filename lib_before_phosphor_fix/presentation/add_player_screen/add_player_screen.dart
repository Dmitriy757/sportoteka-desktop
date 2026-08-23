// lib/presentation/team_screen/add_player_screen.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class AddPlayerScreen extends StatefulWidget {
  final int teamId;
  final String teamName;

  const AddPlayerScreen({
    super.key,
    required this.teamId,
    required this.teamName,
  });

  @override
  State<AddPlayerScreen> createState() => _AddPlayerScreenState();
}

class _AddPlayerScreenState extends State<AddPlayerScreen> {
  static const String apiBase = "https://sportotekaapp.ru/api";
  static const String uploadPhotoUrl = "$apiBase/upload_player_photo.php";
  static const String addPlayerUrl = "$apiBase/add_player.php";

  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController birthDateController = TextEditingController();
  final TextEditingController nationalityController = TextEditingController();
  final TextEditingController statValueController = TextEditingController();
  final TextEditingController positionController = TextEditingController();
  final TextEditingController jerseyNumberController = TextEditingController();

  final List<String> sportMetrics = const [
    'Игры',
    'Время на поле',
    'Вышел на замену',
    'Был заменен',
    'Пропущенные голы',
    'Игры на "ноль"',
    'Голы',
    'Голевые передачи',
    'Желтые карточки',
    'Две желтые карточки',
    'Красные карточки',
    'Рост',
    'Вес',
    'Достижения',
  ];

  String? selectedMetric;
  final Map<String, String> playerStats = {};
  File? selectedImage;
  bool isLoading = false;

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    birthDateController.dispose();
    nationalityController.dispose();
    statValueController.dispose();
    positionController.dispose();
    jerseyNumberController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      setState(() => selectedImage = File(pickedFile.path));
    }
  }

  Future<void> _selectDate() async {
    final pickedDate = await showDatePicker(
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

    if (pickedDate != null) {
      birthDateController.text = DateFormat('yyyy-MM-dd').format(pickedDate);
    }
  }

  void _addStat() {
    if (selectedMetric != null && statValueController.text.trim().isNotEmpty) {
      setState(() {
        playerStats[selectedMetric!] = statValueController.text.trim();
        statValueController.clear();
        selectedMetric = null;
      });
    } else {
      Get.snackbar(
        'Ошибка',
        'Выберите метрику и введите значение',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        borderRadius: 14,
      );
    }
  }

  Future<String> _uploadPhotoIfNeeded() async {
    if (selectedImage == null) return '';

    final request = http.MultipartRequest('POST', Uri.parse(uploadPhotoUrl));
    request.files.add(
      await http.MultipartFile.fromPath('photo', selectedImage!.path),
    );

    final response = await request.send();
    final body = await response.stream.bytesToString();
    final jsonResp = jsonDecode(body);

    if (jsonResp['status'] == 'success') {
      return (jsonResp['url'] ?? '').toString();
    }

    throw Exception(jsonResp['message'] ?? 'Не удалось загрузить фото');
  }

  Future<void> _submitPlayer() async {
    final firstName = firstNameController.text.trim();
    final lastName = lastNameController.text.trim();
    final email = emailController.text.trim();
    final dob = birthDateController.text.trim();
    final nationality = nationalityController.text.trim();
    final position = positionController.text.trim();
    final jerseyNumber = int.tryParse(jerseyNumberController.text.trim()) ?? 0;

    final sportData = playerStats.entries
        .map((e) => "${e.key}: ${e.value}")
        .join(", ");

    if ([firstName, lastName, email, dob, nationality].any((e) => e.isEmpty)) {
      Get.snackbar(
        'Ошибка',
        'Заполните все обязательные поля',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        borderRadius: 14,
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final uploadedPhotoUrl = await _uploadPhotoIfNeeded();

      debugPrint(
        "ADD PLAYER => team_id=${widget.teamId}, teamName=${widget.teamName}, email=$email",
      );

      final response = await http.post(
        Uri.parse(addPlayerUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'first_name': firstName,
          'last_name': lastName,
          'email': email,
          'birth_date': dob,
          'nationality': nationality,
          'sport_data': sportData,
          'team_id': widget.teamId,
          'position': position,
          'jersey_number': jerseyNumber,
          'photo_url': uploadedPhotoUrl,
        }),
      );

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final data = jsonDecode(response.body);

        if (data['status'] == 'success') {
          Get.snackbar(
            'Успех',
            'Игрок успешно добавлен в команду «${widget.teamName}»',
            snackPosition: SnackPosition.BOTTOM,
            margin: const EdgeInsets.all(16),
            borderRadius: 14,
            colorText: Colors.white,
            backgroundColor: _C.primaryGreen,
          );
          Navigator.pop(context, true);
        } else {
          throw Exception(data['message'] ?? 'Не удалось добавить игрока');
        }
      } else {
        throw Exception('Пустой ответ от сервера');
      }
    } catch (e) {
      Get.snackbar(
        'Ошибка',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
        borderRadius: 14,
        colorText: Colors.white,
        backgroundColor: _C.red,
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: _C.bg,
      appBar: AppBar(
        title: const Text(
          'Добавить игрока',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: _C.text,
        surfaceTintColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: _C.primaryGreen))
          : SafeArea(
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
    );
  }

  Widget _buildSideCard() {
    final fullName =
        '${firstNameController.text.trim()} ${lastNameController.text.trim()}'
            .trim();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(radius: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAvatarSection(),
          const SizedBox(height: 18),
          Text(
            fullName.isEmpty ? 'Новый игрок' : fullName,
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
            widget.teamName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _C.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          _InfoTile(
            icon: Icons.verified_rounded,
            title: 'Привязка к команде',
            value: 'team_id: ${widget.teamId}',
            color: _C.blue,
          ),
          const SizedBox(height: 10),
          _InfoTile(
            icon: Icons.person_add_alt_1_rounded,
            title: 'Создание аккаунта',
            value: 'Игрок будет добавлен через API',
            color: _C.primaryGreen,
          ),
          const SizedBox(height: 10),
          _InfoTile(
            icon: Icons.analytics_rounded,
            title: 'Метрики',
            value: '${playerStats.length} добавлено',
            color: _C.orange,
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
          subtitle: 'ФИО, email, дата рождения и гражданство игрока',
          icon: Icons.info_outline_rounded,
          color: _C.blue,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _buildTextField(firstNameController, 'Имя')),
                  const SizedBox(width: 12),
                  Expanded(child: _buildTextField(lastNameController, 'Фамилия')),
                ],
              ),
              _buildTextField(emailController, 'Email'),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(
                      birthDateController,
                      'Дата рождения',
                      readOnly: true,
                      onTap: _selectDate,
                      icon: Icons.calendar_month_rounded,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      nationalityController,
                      'Гражданство',
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
          title: 'Спортивная информация',
          subtitle: 'Амплуа, игровой номер и базовые данные',
          icon: Icons.sports_soccer_rounded,
          color: _C.primaryGreen,
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildTextField(
                  positionController,
                  'Позиция',
                  icon: Icons.sports_soccer_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  jerseyNumberController,
                  'Номер',
                  isNumber: true,
                  icon: Icons.tag_rounded,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _FormSection(
          title: 'Статистика игрока',
          subtitle: 'Добавьте показатели: рост, вес, голы, игры и достижения',
          icon: Icons.analytics_rounded,
          color: _C.orange,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      decoration: _inputDecoration(
                        'Метрика',
                        icon: Icons.tune_rounded,
                      ),
                      value: selectedMetric,
                      isExpanded: true,
                      items: sportMetrics
                          .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                          .toList(),
                      onChanged: (value) => setState(() => selectedMetric = value),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(
                      statValueController,
                      'Значение',
                      isNumber: false,
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
              if (playerStats.isNotEmpty) ...[
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: playerStats.entries
                        .map((e) => _buildMetricChip(e.key, e.value))
                        .toList(),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.centerRight,
          child: _PrimarySubmitButton(
            onTap: _submitPlayer,
            loading: isLoading,
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildAvatarSection() {
    return Center(
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Container(
            width: 124,
            height: 124,
            decoration: BoxDecoration(
              color: _C.blueSoft,
              borderRadius: BorderRadius.circular(42),
              border: Border.all(color: _C.blue.withOpacity(.16), width: 1.2),
            ),
            clipBehavior: Clip.antiAlias,
            child: selectedImage != null
                ? Image.file(selectedImage!, fit: BoxFit.cover)
                : const Icon(
                    Icons.person_outline_rounded,
                    size: 48,
                    color: _C.blue,
                  ),
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

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    bool isNumber = false,
    bool readOnly = false,
    VoidCallback? onTap,
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        readOnly: readOnly,
        onTap: onTap,
        onChanged: (_) => setState(() {}),
        style: const TextStyle(
          color: _C.text,
          fontWeight: FontWeight.w800,
        ),
        decoration: _inputDecoration(label, icon: icon),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon == null ? null : Icon(icon, color: _C.muted, size: 20),
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

  Widget _buildMetricChip(String metric, String value) {
    return Container(
      padding: const EdgeInsets.only(left: 12, right: 6, top: 7, bottom: 7),
      decoration: BoxDecoration(
        color: _C.orangeSoft,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: _C.orange.withOpacity(.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$metric: $value',
            style: const TextStyle(
              color: _C.text,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            borderRadius: BorderRadius.circular(99),
            onTap: () => setState(() => playerStats.remove(metric)),
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

class _C {
  static const Color bg = Color(0xFFFBFBFA);
  static const Color card = Color(0xFFFFFFFF);
  static const Color text = Color(0xFF0F172A);
  static const Color muted = Color(0xFF64748B);
  static const Color border = Color(0xFFE7ECF2);
  static const Color soft = Color(0xFFF8FAFC);
  static const Color soft2 = Color(0xFFFAFCFB);

  static const Color primaryGreen = Color(0xFF00A750);
  static const Color footballGreen = Color(0xFF178A45);
  static const Color footballGreenSoft = Color(0xFFEAF5EE);

  static const Color blue = Color(0xFF2563EB);
  static const Color blueSoft = Color(0xFFEFF6FF);

  static const Color purple = Color(0xFF7C3AED);
  static const Color purpleSoft = Color(0xFFF3E8FF);

  static const Color orange = Color(0xFFEA580C);
  static const Color orangeSoft = Color(0xFFFFF1E8);

  static const Color teal = Color(0xFF0F766E);
  static const Color tealSoft = Color(0xFFE6F6F4);

  static const Color red = Color(0xFFDC2626);
  static const Color redSoft = Color(0xFFFEE2E2);

  static Color softFor(Color color) {
    if (color == blue) return blueSoft;
    if (color == purple) return purpleSoft;
    if (color == orange) return orangeSoft;
    if (color == teal) return tealSoft;
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
              const Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
            const SizedBox(width: 10),
            const Text(
              'Добавить игрока',
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