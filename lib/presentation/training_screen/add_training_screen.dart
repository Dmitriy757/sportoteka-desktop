import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';

// Цветовые константы в стиле TeamTrainersScreen и PlayerProfileScreen
class _AppColors {
  static const Color primaryGreen = Color(0xFF00C853);
  static const Color background = Color(0xFFF5F9FF);
  static const Color card = Colors.white;
  static const Color textPrimary = Color(0xFF1A1F2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color error = Color(0xFFEF4444);
  static const Color white = Colors.white;
}

class AddTrainingScreen extends StatefulWidget {
  final int playerId;

  const AddTrainingScreen({super.key, required this.playerId});

  @override
  State<AddTrainingScreen> createState() => _AddTrainingScreenState();
}

class _AddTrainingScreenState extends State<AddTrainingScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _goalsController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();
  final TextEditingController _distanceController = TextEditingController();
  final TextEditingController _coachCommentController = TextEditingController();
  final TextEditingController _futureGoalsController = TextEditingController();
  final TextEditingController _progressScoreController = TextEditingController();
  final TextEditingController _successRateController = TextEditingController();
  final TextEditingController _mediaUrlController = TextEditingController();

  List<Map<String, String>> customMetrics = [];

  String _trainingType = 'Индивидуальная';
  DateTime _selectedDate = DateTime.now();
  bool _isSubmitting = false;

  final List<String> _trainingTypes = ['Индивидуальная', 'Командная', 'Восстановительная'];

  Future<void> _submitTraining() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final trainerId = await PrefUtils.getUserId();

    final rawBody = {
      'player_id': widget.playerId.toString(),
      'trainer_id': trainerId.toString(),
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'training_type': _trainingType,
      'goals': _goalsController.text.trim(),
      'date': _selectedDate.toIso8601String().substring(0, 10),
      'duration_minutes': _durationController.text.trim(),
      'distance_km': _distanceController.text.trim(),
      'success_rate': _successRateController.text.trim(),
      'coach_comment': _coachCommentController.text.trim(),
      'future_goals': _futureGoalsController.text.trim(),
      'progress_score': _progressScoreController.text.trim(),
      'media_url': _mediaUrlController.text.trim(),
    };

    // Удаляем пустые поля
    final body = Map.fromEntries(rawBody.entries.where((e) => e.value.toString().isNotEmpty));

    // Добавляем метрики
    if (customMetrics.isNotEmpty) {
      body['custom_metrics'] = jsonEncode(customMetrics);
    }

    final uri = Uri.parse('https://sportotekaapp.ru/api/add_player_training.php');
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    setState(() => _isSubmitting = false);

    if (res.statusCode == 200) {
      final result = json.decode(res.body);
      if (result['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Тренировка успешно назначена'),
              backgroundColor: _AppColors.primaryGreen,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
          Navigator.pop(context);
        }
      } else {
        _showError(result['message'] ?? 'Ошибка при сохранении');
      }
    } else {
      _showError('Ошибка соединения с сервером');
    }
  }

  void _showAddMetricDialog() {
    final nameController = TextEditingController();
    final valueController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: _AppColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Добавить показатель',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: _AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              _buildStyledTextField(
                nameController,
                'Название показателя',
                icon: Icons.speed_rounded,
              ),
              const SizedBox(height: 10),
              _buildStyledTextField(
                valueController,
                'Значение',
                icon: Icons.numbers_rounded,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: _AppColors.textSecondary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Отмена',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (nameController.text.trim().isNotEmpty && 
                            valueController.text.trim().isNotEmpty) {
                          setState(() {
                            customMetrics.add({
                              'title': nameController.text.trim(),
                              'value': valueController.text.trim(),
                            });
                          });
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _AppColors.primaryGreen,
                        foregroundColor: _AppColors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Добавить',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showDeleteMetricDialog(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Удалить показатель',
          style: TextStyle(fontWeight: FontWeight.w900, color: _AppColors.textPrimary),
        ),
        content: const Text(
          'Вы уверены, что хотите удалить этот показатель?',
          style: TextStyle(color: _AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: _AppColors.textSecondary,
            ),
            child: const Text('Отмена', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                customMetrics.removeAt(index);
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _AppColors.error,
              foregroundColor: _AppColors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('Удалить', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _AppColors.background,
      appBar: AppBar(
        backgroundColor: _AppColors.card,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          color: _AppColors.textPrimary,
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Назначить тренировку',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: _AppColors.textPrimary,
            fontSize: 16,
          ),
        ),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Основная информация
              _buildSectionCard(
                title: 'Основная информация',
                icon: Icons.info_outline_rounded,
                children: [
                  _buildTextField(_titleController, 'Название тренировки', required: true),
                  const SizedBox(height: 12),
                  _buildDropdown(),
                  const SizedBox(height: 12),
                  _buildDatePicker(),
                ],
              ),

              const SizedBox(height: 16),

              // Детали тренировки
              _buildSectionCard(
                title: 'Детали тренировки',
                icon: Icons.fitness_center_rounded,
                children: [
                  _buildTextField(_descriptionController, 'Описание', maxLines: 3),
                  const SizedBox(height: 12),
                  _buildTextField(_goalsController, 'Цели тренировки'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(_durationController, 'Длительность (мин)'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(_distanceController, 'Дистанция (км)'),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Оценки и прогресс
              _buildSectionCard(
                title: 'Оценки и прогресс',
                icon: Icons.analytics_rounded,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(_successRateController, 'Успешность (%)'),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTextField(_progressScoreController, 'Прогресс (1–10)'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(_coachCommentController, 'Комментарий тренера', maxLines: 2),
                  const SizedBox(height: 12),
                  _buildTextField(_futureGoalsController, 'Цели на будущее'),
                ],
              ),

              const SizedBox(height: 16),

              // Медиа
              _buildSectionCard(
                title: 'Медиа',
                icon: Icons.photo_library_rounded,
                children: [
                  _buildTextField(_mediaUrlController, 'Ссылка на фото/видео'),
                ],
              ),

              const SizedBox(height: 16),

              // Дополнительные показатели
              _buildSectionCard(
                title: 'Дополнительные показатели',
                icon: Icons.show_chart_rounded,
                children: [
                  if (customMetrics.isEmpty)
                    _buildEmptyMetrics()
                  else
                    ...customMetrics.asMap().entries.map((entry) => _buildMetricTile(entry.key, entry.value)),
                  const SizedBox(height: 8),
                  _buildAddMetricButton(),
                ],
              ),

              const SizedBox(height: 24),

              // Кнопка сохранения
              _buildSubmitButton(),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _AppColors.card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _AppColors.primaryGreen.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: _AppColors.primaryGreen, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: _AppColors.textPrimary,
                  height: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {int maxLines = 1, bool required = false}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF3F5F8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(
          hintText: label,
          hintStyle: const TextStyle(color: _AppColors.textTertiary, fontSize: 14),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        maxLines: maxLines,
        style: const TextStyle(fontSize: 14, color: _AppColors.textPrimary),
        validator: (value) {
          if (required && (value == null || value.isEmpty)) {
            return 'Обязательное поле';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildStyledTextField(TextEditingController controller, String hint, {IconData? icon}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF3F5F8),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: _AppColors.textTertiary, fontSize: 13),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          prefixIcon: icon != null ? Icon(icon, size: 18, color: _AppColors.textSecondary) : null,
        ),
        style: const TextStyle(fontSize: 14, color: _AppColors.textPrimary),
      ),
    );
  }

  Widget _buildDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF3F5F8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonFormField<String>(
        value: _trainingType,
        items: _trainingTypes.map((type) => DropdownMenuItem(
          value: type,
          child: Text(type, style: const TextStyle(color: _AppColors.textPrimary)),
        )).toList(),
        onChanged: (value) => setState(() => _trainingType = value!),
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        ),
        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _AppColors.textSecondary),
        dropdownColor: _AppColors.card,
        style: const TextStyle(fontSize: 14, color: _AppColors.textPrimary),
      ),
    );
  }

  Widget _buildDatePicker() {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(
                  primary: _AppColors.primaryGreen,
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) {
          setState(() => _selectedDate = picked);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F5F8),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded, size: 16, color: _AppColors.primaryGreen),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Дата тренировки: ${DateFormat('dd.MM.yyyy').format(_selectedDate)}',
                style: const TextStyle(
                  fontSize: 14,
                  color: _AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded, color: _AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile(int index, Map<String, String> metric) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _AppColors.primaryGreen.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _AppColors.primaryGreen.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _AppColors.primaryGreen.withOpacity(0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.bolt, color: _AppColors.primaryGreen, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metric['title'] ?? '',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: _AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  metric['value'] ?? '',
                  style: const TextStyle(
                    fontSize: 13,
                    color: _AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _showDeleteMetricDialog(index),
            icon: const Icon(Icons.close_rounded, size: 20),
            color: _AppColors.error,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildAddMetricButton() {
    return InkWell(
      onTap: _showAddMetricDialog,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: _AppColors.primaryGreen.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _AppColors.primaryGreen.withOpacity(0.25), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, color: _AppColors.primaryGreen, size: 20),
            const SizedBox(width: 8),
            Text(
              'Добавить показатель',
              style: TextStyle(
                color: _AppColors.primaryGreen,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyMetrics() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F5F8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(Icons.analytics_outlined, size: 32, color: _AppColors.textTertiary),
          const SizedBox(height: 8),
          Text(
            'Нет дополнительных показателей',
            style: TextStyle(
              color: _AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isSubmitting ? null : _submitTraining,
        icon: _isSubmitting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: _AppColors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.check_circle_rounded, size: 18),
        label: Text(
          _isSubmitting ? 'Сохранение...' : 'Сохранить тренировку',
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _AppColors.primaryGreen,
          foregroundColor: _AppColors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 2,
          disabledBackgroundColor: _AppColors.primaryGreen.withOpacity(0.5),
        ),
      ),
    );
  }
}