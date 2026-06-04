import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';

// ==================== CMR-стиль профиля игрока ====================

class _CmrColors {
  static const Color panel = Colors.white;
  static const Color soft = Color(0xFFF6F8FA);
  static const Color page = Colors.white;
  static const Color text = Color(0xFF101828);
  static const Color muted = Color(0xFF667085);
  static const Color faint = Color(0xFF98A2B3);
  static const Color green = Color(0xFF1F7A4D);
  static const Color greenSoft = Color(0xFFF2F7F4);
  static const Color greenSoftStrong = Color(0xFFE8F3ED);
  static const Color red = Color(0xFFD92D20);
  static const Color redSoft = Color(0xFFFFF1F0);
}

class _CmrText {
  static TextStyle heroTitle(bool compact) => TextStyle(
        color: _CmrColors.text,
        fontSize: compact ? 22 : 28,
        fontWeight: FontWeight.w800,
        height: 1.08,
      );

  static TextStyle heroSubtitle(bool compact) => TextStyle(
        color: _CmrColors.muted,
        fontSize: compact ? 15 : 16,
        fontWeight: FontWeight.w600,
        height: 1.38,
      );

  static TextStyle section(bool compact) => TextStyle(
        color: _CmrColors.text,
        fontSize: compact ? 17 : 18,
        fontWeight: FontWeight.w800,
        height: 1.15,
      );

  static TextStyle value(bool compact) => TextStyle(
        color: _CmrColors.text,
        fontSize: compact ? 15.5 : 16,
        fontWeight: FontWeight.w700,
        height: 1.35,
      );

  static TextStyle muted(bool compact) => TextStyle(
        color: _CmrColors.muted,
        fontSize: compact ? 14.5 : 15,
        fontWeight: FontWeight.w600,
        height: 1.42,
      );

  static TextStyle caption(bool compact) => TextStyle(
        color: _CmrColors.muted,
        fontSize: compact ? 13.5 : 14,
        fontWeight: FontWeight.w700,
        height: 1.18,
      );

  static TextStyle button(bool compact, {Color color = _CmrColors.green}) => TextStyle(
        color: color,
        fontSize: compact ? 15 : 15.5,
        fontWeight: FontWeight.w800,
        height: 1.1,
      );
}

class _CmrDecor {
  static BoxDecoration panel({double radius = 28}) => BoxDecoration(
        color: _CmrColors.panel,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.025),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      );

  static BoxDecoration softCard({double radius = 22}) => BoxDecoration(
        color: _CmrColors.soft,
        borderRadius: BorderRadius.circular(radius),
      );

  static BoxDecoration greenCard({double radius = 22}) => BoxDecoration(
        color: _CmrColors.greenSoft,
        borderRadius: BorderRadius.circular(radius),
      );
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

  final List<Map<String, String>> customMetrics = [];

  String _trainingType = 'Индивидуальная';
  DateTime _selectedDate = DateTime.now();
  bool _isSubmitting = false;

  final List<String> _trainingTypes = const [
    'Индивидуальная',
    'Командная',
    'Восстановительная',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _goalsController.dispose();
    _durationController.dispose();
    _distanceController.dispose();
    _coachCommentController.dispose();
    _futureGoalsController.dispose();
    _progressScoreController.dispose();
    _successRateController.dispose();
    _mediaUrlController.dispose();
    super.dispose();
  }

  Future<void> _submitTraining() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final trainerId = await PrefUtils.getUserId();

      final rawBody = <String, String>{
        'player_id': widget.playerId.toString(),
        'trainer_id': trainerId?.toString() ?? '',
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

      final body = Map<String, dynamic>.fromEntries(
        rawBody.entries.where((entry) => entry.value.trim().isNotEmpty),
      );

      if (customMetrics.isNotEmpty) {
        body['custom_metrics'] = jsonEncode(customMetrics);
      }

      final uri = Uri.parse('https://sportotekaapp.ru/api/add_player_training.php');
      final res = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      if (res.statusCode == 200) {
        final result = json.decode(res.body);
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Тренировка успешно назначена',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              backgroundColor: _CmrColors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
          );
          Navigator.pop(context);
        } else {
          _showError(result['message'] ?? 'Ошибка при сохранении');
        }
      } else {
        _showError('Ошибка соединения с сервером');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showError('Не удалось сохранить тренировку');
    }
  }

  void _showAddMetricDialog() {
    final nameController = TextEditingController();
    final valueController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final width = MediaQuery.of(context).size.width;
        final compact = width < 620;

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: compact ? 8 : 20),
              decoration: const BoxDecoration(
                color: _CmrColors.panel,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                  left: compact ? 16 : 24,
                  right: compact ? 16 : 24,
                  top: 12,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 46,
                        height: 5,
                        decoration: BoxDecoration(
                          color: _CmrColors.greenSoftStrong,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        _buildIconBadge(Icons.show_chart_rounded, compact: compact),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Добавить показатель',
                            style: _CmrText.section(compact),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _buildStyledTextField(
                      nameController,
                      'Название показателя',
                      icon: Icons.speed_rounded,
                      compact: compact,
                    ),
                    const SizedBox(height: 12),
                    _buildStyledTextField(
                      valueController,
                      'Значение',
                      icon: Icons.numbers_rounded,
                      compact: compact,
                    ),
                    const SizedBox(height: 20),
                    _buildDialogActions(
                      compact: compact,
                      cancelTitle: 'Отмена',
                      actionTitle: 'Добавить',
                      onCancel: () => Navigator.pop(context),
                      onAction: () {
                        final title = nameController.text.trim();
                        final value = valueController.text.trim();
                        if (title.isEmpty || value.isEmpty) return;

                        setState(() {
                          customMetrics.add({'title': title, 'value': value});
                        });
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: _CmrColors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }

  void _showDeleteMetricDialog(int index) {
    final width = MediaQuery.of(context).size.width;
    final compact = width < 620;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: EdgeInsets.symmetric(horizontal: compact ? 18 : 32),
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Container(
            padding: EdgeInsets.all(compact ? 18 : 24),
            decoration: _CmrDecor.panel(radius: 30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: compact ? 42 : 46,
                      height: compact ? 42 : 46,
                      decoration: BoxDecoration(
                        color: _CmrColors.redSoft,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.delete_outline_rounded, color: _CmrColors.red),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('Удалить показатель', style: _CmrText.section(compact)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Вы уверены, что хотите удалить этот показатель из тренировки?',
                  style: _CmrText.muted(compact),
                ),
                const SizedBox(height: 22),
                _buildDialogActions(
                  compact: compact,
                  cancelTitle: 'Отмена',
                  actionTitle: 'Удалить',
                  actionColor: _CmrColors.red,
                  onCancel: () => Navigator.pop(context),
                  onAction: () {
                    setState(() => customMetrics.removeAt(index));
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 680;
        final tablet = constraints.maxWidth >= 680 && constraints.maxWidth < 1100;
        final horizontalPadding = compact ? 10.0 : (tablet ? 18.0 : 28.0);

        return Scaffold(
          backgroundColor: _CmrColors.page,
          appBar: AppBar(
            backgroundColor: _CmrColors.panel,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            leadingWidth: compact ? 46 : 56,
            leading: Padding(
              padding: EdgeInsets.only(left: compact ? 8 : 14),
              child: _RoundIconButton(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: () => Navigator.pop(context),
                compact: compact,
              ),
            ),
            titleSpacing: compact ? 4 : 8,
            title: Text(
              'Назначить тренировку',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: _CmrColors.text,
                fontSize: compact ? 18 : 21,
                height: 1.1,
              ),
            ),
          ),
          body: SafeArea(
            top: false,
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(horizontalPadding, 10, horizontalPadding, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: compact ? double.infinity : 1040),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeroCard(compact: compact),
                        SizedBox(height: compact ? 12 : 16),
                        _buildSectionCard(
                          title: 'Основная информация',
                          subtitle: 'Название, формат и дата проведения тренировки.',
                          icon: Icons.info_outline_rounded,
                          compact: compact,
                          children: [
                            _buildTextField(
                              _titleController,
                              'Название тренировки',
                              requiredField: true,
                              compact: compact,
                            ),
                            const SizedBox(height: 12),
                            _buildAdaptiveFields(
                              compact: compact,
                              children: [
                                _buildDropdown(compact: compact),
                                _buildDatePicker(compact: compact),
                              ],
                            ),
                          ],
                        ),
                        SizedBox(height: compact ? 12 : 16),
                        _buildSectionCard(
                          title: 'Детали тренировки',
                          subtitle: 'Описание занятия, задачи и основные числовые показатели.',
                          icon: Icons.fitness_center_rounded,
                          compact: compact,
                          children: [
                            _buildTextField(
                              _descriptionController,
                              'Описание',
                              maxLines: compact ? 4 : 3,
                              compact: compact,
                            ),
                            const SizedBox(height: 12),
                            _buildTextField(_goalsController, 'Цели тренировки', compact: compact),
                            const SizedBox(height: 12),
                            _buildAdaptiveFields(
                              compact: compact,
                              children: [
                                _buildTextField(_durationController, 'Длительность, мин', compact: compact),
                                _buildTextField(_distanceController, 'Дистанция, км', compact: compact),
                              ],
                            ),
                          ],
                        ),
                        SizedBox(height: compact ? 12 : 16),
                        _buildSectionCard(
                          title: 'Оценки и прогресс',
                          subtitle: 'Фиксация выполнения, прогресса и комментария тренера.',
                          icon: Icons.analytics_rounded,
                          compact: compact,
                          children: [
                            _buildAdaptiveFields(
                              compact: compact,
                              children: [
                                _buildTextField(_successRateController, 'Успешность, %', compact: compact),
                                _buildTextField(_progressScoreController, 'Прогресс 1–10', compact: compact),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildTextField(
                              _coachCommentController,
                              'Комментарий тренера',
                              maxLines: compact ? 4 : 3,
                              compact: compact,
                            ),
                            const SizedBox(height: 12),
                            _buildTextField(_futureGoalsController, 'Цели на будущее', compact: compact),
                          ],
                        ),
                        SizedBox(height: compact ? 12 : 16),
                        _buildTwoColumnArea(compact: compact),
                        SizedBox(height: compact ? 16 : 22),
                        _buildSubmitButton(compact: compact),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeroCard({required bool compact}) {
    return Container(
      padding: EdgeInsets.all(compact ? 18 : 24),
      decoration: _CmrDecor.panel(radius: compact ? 26 : 32),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _heroChildren(compact),
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _heroChildren(compact),
                  ),
                ),
                const SizedBox(width: 20),
                _buildHeroStatus(compact: compact),
              ],
            ),
    );
  }

  List<Widget> _heroChildren(bool compact) {
    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildIconBadge(Icons.assignment_turned_in_rounded, compact: compact, large: true),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Новая тренировка', style: _CmrText.heroTitle(compact)),
                const SizedBox(height: 6),
                Text(
                  'Заполните карточку занятия: цели, нагрузка, оценка выполнения и дополнительные показатели игрока.',
                  style: _CmrText.heroSubtitle(compact),
                ),
              ],
            ),
          ),
        ],
      ),
      if (compact) ...[
        const SizedBox(height: 16),
        _buildHeroStatus(compact: compact),
      ],
    ];
  }

  Widget _buildHeroStatus({required bool compact}) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildInfoPill(
          icon: Icons.person_outline_rounded,
          text: 'Игрок ${widget.playerId}',
          compact: compact,
        ),
        _buildInfoPill(
          icon: Icons.calendar_today_rounded,
          text: DateFormat('dd.MM.yyyy').format(_selectedDate),
          compact: compact,
        ),
      ],
    );
  }

  Widget _buildTwoColumnArea({required bool compact}) {
    final mediaSection = _buildSectionCard(
      title: 'Медиа',
      subtitle: 'Ссылка на фото или видео по тренировке.',
      icon: Icons.photo_library_rounded,
      compact: compact,
      children: [
        _buildTextField(_mediaUrlController, 'Ссылка на фото/видео', compact: compact),
      ],
    );

    final metricsSection = _buildSectionCard(
      title: 'Дополнительные показатели',
      subtitle: 'Произвольные метрики тренера для этой тренировки.',
      icon: Icons.show_chart_rounded,
      compact: compact,
      children: [
        if (customMetrics.isEmpty)
          _buildEmptyMetrics(compact: compact)
        else
          ...customMetrics.asMap().entries.map(
                (entry) => _buildMetricTile(entry.key, entry.value, compact: compact),
              ),
        const SizedBox(height: 10),
        _buildAddMetricButton(compact: compact),
      ],
    );

    if (compact) {
      return Column(
        children: [
          mediaSection,
          const SizedBox(height: 12),
          metricsSection,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: mediaSection),
        const SizedBox(width: 16),
        Expanded(child: metricsSection),
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
    required bool compact,
    String? subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 16 : 22),
      decoration: _CmrDecor.panel(radius: compact ? 24 : 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildIconBadge(icon, compact: compact),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: _CmrText.section(compact)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(subtitle, style: _CmrText.caption(compact)),
                    ],
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 16 : 18),
          ...children,
        ],
      ),
    );
  }

  Widget _buildAdaptiveFields({required bool compact, required List<Widget> children}) {
    if (compact) {
      return Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            children[i],
          ],
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 14),
          Expanded(child: children[i]),
        ],
      ],
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    bool requiredField = false,
    required bool compact,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      minLines: maxLines > 1 ? 2 : 1,
      cursorColor: _CmrColors.green,
      decoration: _inputDecoration(label, compact: compact),
      style: _CmrText.value(compact),
      validator: (value) {
        if (requiredField && (value == null || value.trim().isEmpty)) {
          return 'Обязательное поле';
        }
        return null;
      },
    );
  }

  Widget _buildStyledTextField(
    TextEditingController controller,
    String hint, {
    IconData? icon,
    required bool compact,
  }) {
    return TextField(
      controller: controller,
      cursorColor: _CmrColors.green,
      decoration: _inputDecoration(hint, compact: compact, icon: icon),
      style: _CmrText.value(compact),
    );
  }

  InputDecoration _inputDecoration(String hint, {required bool compact, IconData? icon}) {
    final radius = BorderRadius.circular(compact ? 18 : 20);

    return InputDecoration(
      hintText: hint,
      hintStyle: _CmrText.muted(compact).copyWith(color: _CmrColors.faint),
      filled: true,
      fillColor: _CmrColors.soft,
      contentPadding: EdgeInsets.symmetric(
        horizontal: compact ? 16 : 18,
        vertical: compact ? 15 : 17,
      ),
      prefixIcon: icon != null
          ? Icon(icon, size: compact ? 21 : 22, color: _CmrColors.green)
          : null,
      border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
      errorBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
      focusedErrorBorder: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
      errorStyle: TextStyle(
        color: _CmrColors.red,
        fontSize: compact ? 13 : 13.5,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildDropdown({required bool compact}) {
    return DropdownButtonFormField<String>(
      value: _trainingType,
      items: _trainingTypes
          .map(
            (type) => DropdownMenuItem(
              value: type,
              child: Text(type, style: _CmrText.value(compact)),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value == null) return;
        setState(() => _trainingType = value);
      },
      decoration: _inputDecoration('Тип тренировки', compact: compact, icon: Icons.category_rounded),
      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _CmrColors.muted),
      dropdownColor: _CmrColors.panel,
      borderRadius: BorderRadius.circular(22),
      style: _CmrText.value(compact),
    );
  }

  Widget _buildDatePicker({required bool compact}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: _selectedDate,
            firstDate: DateTime(2020),
            lastDate: DateTime(2100),
            builder: (context, child) {
              return Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: const ColorScheme.light(primary: _CmrColors.green),
                ),
                child: child!,
              );
            },
          );
          if (picked != null) {
            setState(() => _selectedDate = picked);
          }
        },
        borderRadius: BorderRadius.circular(compact ? 18 : 20),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 16 : 18,
            vertical: compact ? 15 : 17,
          ),
          decoration: _CmrDecor.softCard(radius: compact ? 18 : 20),
          child: Row(
            children: [
              const Icon(Icons.calendar_today_rounded, size: 21, color: _CmrColors.green),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Дата: ${DateFormat('dd.MM.yyyy').format(_selectedDate)}',
                  style: _CmrText.value(compact),
                ),
              ),
              const Icon(Icons.keyboard_arrow_down_rounded, color: _CmrColors.muted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricTile(int index, Map<String, String> metric, {required bool compact}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: _CmrDecor.greenCard(radius: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: compact ? 42 : 46,
            height: compact ? 42 : 46,
            decoration: BoxDecoration(
              color: _CmrColors.greenSoftStrong,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.bolt_rounded, color: _CmrColors.green, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metric['title'] ?? '',
                  style: _CmrText.value(compact),
                ),
                const SizedBox(height: 3),
                Text(
                  metric['value'] ?? '',
                  style: _CmrText.muted(compact),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showDeleteMetricDialog(index),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: compact ? 38 : 40,
                height: compact ? 38 : 40,
                decoration: BoxDecoration(
                  color: _CmrColors.panel.withOpacity(.74),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.close_rounded, size: 21, color: _CmrColors.red),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddMetricButton({required bool compact}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _showAddMetricDialog,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: compact ? 15 : 16, horizontal: 16),
          decoration: _CmrDecor.greenCard(radius: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add_rounded, color: _CmrColors.green, size: 24),
              const SizedBox(width: 8),
              Text('Добавить показатель', style: _CmrText.button(compact)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyMetrics({required bool compact}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 16 : 20,
        vertical: compact ? 20 : 24,
      ),
      decoration: _CmrDecor.softCard(radius: 22),
      child: Column(
        children: [
          Container(
            width: compact ? 52 : 58,
            height: compact ? 52 : 58,
            decoration: _CmrDecor.greenCard(radius: 18),
            child: const Icon(Icons.analytics_outlined, size: 28, color: _CmrColors.green),
          ),
          const SizedBox(height: 12),
          Text(
            'Показателей пока нет',
            style: _CmrText.value(compact),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Добавьте свои метрики для тренировки.',
            style: _CmrText.caption(compact),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton({required bool compact}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isSubmitting ? null : _submitTraining,
        icon: _isSubmitting
            ? const SizedBox(
                width: 21,
                height: 21,
                child: CircularProgressIndicator(
                  color: _CmrColors.panel,
                  strokeWidth: 2.4,
                ),
              )
            : const Icon(Icons.check_circle_rounded, size: 22),
        label: Text(
          _isSubmitting ? 'Сохранение...' : 'Сохранить тренировку',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: compact ? 16 : 17,
            height: 1.1,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _CmrColors.green,
          foregroundColor: _CmrColors.panel,
          disabledBackgroundColor: _CmrColors.green.withOpacity(.48),
          disabledForegroundColor: _CmrColors.panel,
          padding: EdgeInsets.symmetric(vertical: compact ? 17 : 19, horizontal: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _buildDialogActions({
    required bool compact,
    required String cancelTitle,
    required String actionTitle,
    required VoidCallback onCancel,
    required VoidCallback onAction,
    Color actionColor = _CmrColors.green,
  }) {
    if (compact) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: actionColor,
                foregroundColor: _CmrColors.panel,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                elevation: 0,
              ),
              child: Text(actionTitle, style: _CmrText.button(compact, color: _CmrColors.panel)),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: onCancel,
              style: TextButton.styleFrom(
                foregroundColor: _CmrColors.muted,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              child: Text(cancelTitle, style: _CmrText.button(compact, color: _CmrColors.muted)),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: TextButton(
            onPressed: onCancel,
            style: TextButton.styleFrom(
              foregroundColor: _CmrColors.muted,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            child: Text(cancelTitle, style: _CmrText.button(compact, color: _CmrColors.muted)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: onAction,
            style: ElevatedButton.styleFrom(
              backgroundColor: actionColor,
              foregroundColor: _CmrColors.panel,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              elevation: 0,
            ),
            child: Text(actionTitle, style: _CmrText.button(compact, color: _CmrColors.panel)),
          ),
        ),
      ],
    );
  }

  Widget _buildIconBadge(IconData icon, {required bool compact, bool large = false}) {
    final size = large ? (compact ? 48.0 : 56.0) : (compact ? 42.0 : 46.0);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _CmrColors.greenSoft,
        borderRadius: BorderRadius.circular(large ? 18 : 16),
      ),
      child: Icon(icon, color: _CmrColors.green, size: large ? 27 : 23),
    );
  }

  Widget _buildInfoPill({
    required IconData icon,
    required String text,
    required bool compact,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 14,
        vertical: compact ? 10 : 11,
      ),
      decoration: _CmrDecor.greenCard(radius: 18),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _CmrColors.green, size: compact ? 18 : 19),
          const SizedBox(width: 7),
          Text(text, style: _CmrText.caption(compact).copyWith(color: _CmrColors.green)),
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool compact;

  const _RoundIconButton({
    required this.icon,
    required this.onTap,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: compact ? 36 : 40,
          height: compact ? 36 : 40,
          decoration: BoxDecoration(
            color: _CmrColors.soft,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: _CmrColors.text, size: compact ? 18 : 19),
        ),
      ),
    );
  }
}
