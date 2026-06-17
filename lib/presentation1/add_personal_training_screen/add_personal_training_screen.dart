import 'dart:convert';

import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/presentation/add_personal_training_screen/exercise_selector_screen.dart';

class AddPersonalTrainingScreen extends StatefulWidget {
  final Map<String, dynamic>? training;

  const AddPersonalTrainingScreen({
    super.key,
    this.training,
  });

  @override
  State<AddPersonalTrainingScreen> createState() =>
      _AddPersonalTrainingScreenState();
}

class _AddPersonalTrainingScreenState extends State<AddPersonalTrainingScreen> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedSport;
  String? _trainingType;
  DateTime _selectedDate = DateTime.now();
  String? _duration;
  String? _goal;
  bool _isReminderSet = false;
  double _rating = 3.0;
  bool _isLoading = false;
  List<Map<String, dynamic>> _selectedExercises = [];

  final List<Map<String, dynamic>> sports = const [
    {
      'title': 'Футбол',
      'icon': Icons.sports_soccer,
      'color': Color(0xFF00B894),
    },
    {
      'title': 'Фитнес',
      'icon': Icons.fitness_center,
      'color': Color(0xFF6C5CE7),
    },
    {
      'title': 'Бег',
      'icon': Icons.directions_run,
      'color': Color(0xFFFD79A8),
    },
    {
      'title': 'Баскетбол',
      'icon': Icons.sports_basketball,
      'color': Color(0xFFE17055),
    },
    {
      'title': 'Теннис',
      'icon': Icons.sports_tennis,
      'color': Color(0xFF00CEFF),
    },
    {
      'title': 'Хоккей',
      'icon': Icons.sports_hockey,
      'color': Color(0xFF0984E3),
    },
    {
      'title': 'Йога',
      'icon': Icons.self_improvement,
      'color': Color(0xFFA29BFE),
    },
    {
      'title': 'Силовая',
      'icon': Icons.fitness_center,
      'color': Color(0xFFFDCB6E),
    },
  ];

  @override
  void initState() {
    super.initState();

    if (widget.training != null) {
      final t = widget.training!;
      _selectedSport = t['sport'];
      _trainingType = t['type'];
      _duration = t['duration'];
      _goal = t['goal'];
      _selectedDate = DateTime.tryParse(t['date'] ?? '') ?? DateTime.now();

      final reminderRaw = '${t['reminder'] ?? '0'}';
      _isReminderSet =
          reminderRaw == '1' || reminderRaw.toLowerCase() == 'true';

      final parsedRating = double.tryParse('${t['rating'] ?? '3.0'}');
      _rating = (parsedRating ?? 3.0).clamp(1.0, 5.0);

      final exercisesRaw = t['selected_exercises'];
      if (exercisesRaw != null) {
        try {
          if (exercisesRaw is String && exercisesRaw.isNotEmpty) {
            final decoded = jsonDecode(exercisesRaw);
            if (decoded is List) {
              _selectedExercises = decoded
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList();
            }
          } else if (exercisesRaw is List) {
            _selectedExercises = exercisesRaw
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
          }
        } catch (_) {}
      }
    }
  }

  Future<void> _submitTraining() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedSport == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите вид спорта')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = await PrefUtils.getUserId();

      final uri = widget.training != null
          ? Uri.parse('https://sportotekaapp.ru/api/update_personal_training.php')
          : Uri.parse('https://sportotekaapp.ru/api/add_personal_training.php');

      final body = <String, String>{
        'user_id': userId.toString(),
        'sport': _selectedSport ?? '',
        'type': _trainingType ?? '',
        'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
        'duration': _duration ?? '',
        'goal': _goal ?? '',
        'reminder': _isReminderSet ? '1' : '0',
        'rating': _rating.toStringAsFixed(1),
        'selected_exercises': jsonEncode(_selectedExercises),
      };

      if (widget.training != null) {
        body['id'] = widget.training!['id'].toString();
      }

      final response = await http.post(uri, body: body);

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('Ошибка: ${data['message'] ?? 'Не удалось сохранить'}'),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка сервера: ${response.statusCode}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Сетевая ошибка: $e')),
      );
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      locale: const Locale('ru'),
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _openExerciseSelector() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExerciseSelectorScreen(
          onSelected: (exercises) {
            setState(() => _selectedExercises = exercises);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
    String label, {
    Widget? prefixIcon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefixIcon,
      labelStyle: const TextStyle(
        color: FeedPalette.textMuted,
        fontWeight: FontWeight.w700,
      ),
      hintStyle: const TextStyle(
        color: FeedPalette.textLight,
        fontWeight: FontWeight.w600,
      ),
      filled: true,
      fillColor: FeedPalette.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: FeedPalette.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: FeedPalette.primaryGreen,
          width: 1.4,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Colors.redAccent,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Colors.redAccent,
          width: 1.4,
        ),
      ),
    );
  }

  Widget _whiteCard({required Widget child, EdgeInsets? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FeedPalette.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: FeedPalette.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, {String? action}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: FeedPalette.superLightGreen,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: FeedPalette.primaryGreen, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: FeedPalette.text,
              ),
            ),
          ),
          if (action != null)
            Text(
              action,
              style: const TextStyle(
                color: FeedPalette.textMuted,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            FeedPalette.primaryGreen.withOpacity(0.12),
            FeedPalette.superLightGreen,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: FeedPalette.border),
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: FeedPalette.greenGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.all(10),
            child: Icon(
              widget.training != null ? Icons.edit_rounded : Icons.add_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.training != null
                      ? 'Редактирование тренировки'
                      : 'Новая тренировка',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: FeedPalette.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.training != null
                      ? 'Обновите данные и упражнения'
                      : 'Заполните данные тренировки',
                  style: const TextStyle(
                    color: FeedPalette.textMuted,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: FeedPalette.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: FeedPalette.border),
            ),
            child: Text(
              DateFormat('dd.MM.yyyy').format(_selectedDate),
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 12,
                color: FeedPalette.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sportTile(Map<String, dynamic> sport) {
    final isSelected = _selectedSport == sport['title'];
    final Color tone = sport['color'];

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => setState(() => _selectedSport = sport['title']),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: isSelected ? tone.withOpacity(0.12) : FeedPalette.background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? tone : FeedPalette.border,
            width: isSelected ? 1.6 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: tone.withOpacity(0.14),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isSelected ? tone.withOpacity(0.16) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  sport['icon'],
                  size: 21,
                  color: isSelected ? tone : Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                sport['title'],
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.2,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                  color: FeedPalette.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSportsSection() {
    return _whiteCard(
      padding: const EdgeInsets.all(12),
      child: GridView.count(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 1,
        children: [for (final s in sports) _sportTile(s)],
      ),
    );
  }

  Widget _buildFormSection() {
    return _whiteCard(
      child: Column(
        children: [
          TextFormField(
            initialValue: _trainingType,
            decoration: _inputDecoration(
              'Название / тип тренировки',
              prefixIcon: const Icon(Icons.title_rounded),
            ),
            onChanged: (val) => _trainingType = val,
            validator: (val) =>
                (val == null || val.trim().isEmpty) ? 'Введите тип' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            initialValue: _duration,
            decoration: _inputDecoration(
              'Продолжительность (мин)',
              prefixIcon: const Icon(Icons.timer_rounded),
            ),
            keyboardType: TextInputType.number,
            onChanged: (val) => _duration = val,
            validator: (val) => (val == null || val.trim().isEmpty)
                ? 'Введите длительность'
                : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            initialValue: _goal,
            maxLines: 3,
            decoration: _inputDecoration(
              'Цель тренировки',
              prefixIcon: const Icon(Icons.flag_rounded),
            ),
            onChanged: (val) => _goal = val,
            validator: (val) =>
                (val == null || val.trim().isEmpty) ? 'Опишите цель' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildDateSection() {
    return _whiteCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: FeedPalette.superLightGreen,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.calendar_today_rounded,
            color: FeedPalette.primaryGreen,
            size: 20,
          ),
        ),
        title: Text(
          DateFormat('dd.MM.yyyy').format(_selectedDate),
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: FeedPalette.text,
          ),
        ),
        subtitle: const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Text(
            'Дата тренировки',
            style: TextStyle(
              color: FeedPalette.textMuted,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          size: 16,
          color: FeedPalette.textMuted,
        ),
        onTap: _pickDate,
      ),
    );
  }

  Widget _buildRatingSection() {
    return _whiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.star_rate_rounded,
                size: 18,
                color: FeedPalette.primaryGreen,
              ),
              SizedBox(width: 8),
              Text(
                'Оценка тренировки',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: FeedPalette.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: FeedPalette.greenGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    _rating.toStringAsFixed(1),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: FeedPalette.primaryGreen,
                        inactiveTrackColor: FeedPalette.lightGreen,
                        thumbColor: FeedPalette.primaryGreen,
                        overlayColor:
                            FeedPalette.primaryGreen.withOpacity(0.12),
                        trackHeight: 6,
                      ),
                      child: Slider(
                        value: _rating,
                        min: 1,
                        max: 5,
                        divisions: 4,
                        label: _rating.toStringAsFixed(1),
                        onChanged: (val) => setState(() => _rating = val),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('1'),
                          Text('2'),
                          Text('3'),
                          Text('4'),
                          Text('5'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReminderSection() {
    return _whiteCard(
      padding: EdgeInsets.zero,
      child: SwitchListTile.adaptive(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        title: const Text(
          'Напоминание о тренировке',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: FeedPalette.text,
          ),
        ),
        subtitle: const Text(
          'Сохранить параметр напоминания',
          style: TextStyle(
            color: FeedPalette.textMuted,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        value: _isReminderSet,
        activeColor: FeedPalette.primaryGreen,
        onChanged: (val) => setState(() => _isReminderSet = val),
      ),
    );
  }

  Widget _buildExerciseBanner() {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: _openExerciseSelector,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              FeedPalette.primaryGreen.withOpacity(0.12),
              FeedPalette.superLightGreen,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: FeedPalette.border),
        ),
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: FeedPalette.greenGradient,
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.all(10),
              child: const Icon(
                Icons.video_library_rounded,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Программа упражнений',
                    style: TextStyle(
                      color: FeedPalette.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _selectedExercises.isEmpty
                        ? 'Добавить упражнения'
                        : 'Изменить упражнения (${_selectedExercises.length})',
                    style: const TextStyle(
                      color: FeedPalette.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: FeedPalette.textMuted,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExercisesPreview() {
    if (_selectedExercises.isEmpty) {
      return _whiteCard(
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: FeedPalette.superLightGreen,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.fitness_center_rounded,
                color: FeedPalette.primaryGreen,
                size: 28,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Упражнения пока не выбраны',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 15,
                color: FeedPalette.text,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Добавьте упражнения, чтобы собрать полноценную тренировочную программу.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: FeedPalette.textMuted,
                height: 1.45,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _openExerciseSelector,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Добавить упражнения'),
              style: OutlinedButton.styleFrom(
                foregroundColor: FeedPalette.primaryGreen,
                side: const BorderSide(color: FeedPalette.primaryGreen),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return _whiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.fitness_center_rounded,
                size: 18,
                color: FeedPalette.primaryGreen,
              ),
              const SizedBox(width: 8),
              const Text(
                'Выбранные упражнения',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  color: FeedPalette.text,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _openExerciseSelector,
                child: const Text(
                  'Изменить',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ..._selectedExercises.map((ex) {
            final title = '${ex['title'] ?? ''}';
            final sets = '${ex['sets'] ?? '-'}';
            final reps = '${ex['reps'] ?? '-'}';
            final weight = ex['weight'];

            return Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: FeedPalette.background,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: FeedPalette.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: FeedPalette.superLightGreen,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: FeedPalette.primaryGreen,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: FeedPalette.text,
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${sets}x$reps',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: FeedPalette.text,
                        ),
                      ),
                      if (weight != null &&
                          weight.toString().isNotEmpty &&
                          weight.toString() != '0')
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '$weight кг',
                            style: const TextStyle(
                              color: FeedPalette.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSaveBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        decoration: BoxDecoration(
          color: FeedPalette.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 14,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SizedBox(
          width: double.infinity,
          child: Container(
            decoration: BoxDecoration(
              gradient: FeedPalette.greenGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitTraining,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(vertical: 15),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      widget.training != null
                          ? 'ОБНОВИТЬ ТРЕНИРОВКУ'
                          : 'СОЗДАТЬ ТРЕНИРОВКУ',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.2,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FeedPalette.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: FeedPalette.white,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Text(
          widget.training != null ? 'Редактирование' : 'Новая тренировка',
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: FeedPalette.text,
            fontSize: 16,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 8),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FadeInUp(
                      duration: const Duration(milliseconds: 180),
                      child: _buildTopCard(),
                    ),
                    FadeInUp(
                      duration: const Duration(milliseconds: 220),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle(
                            'Вид спорта',
                            Icons.sports_rounded,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: _buildSportsSection(),
                          ),
                        ],
                      ),
                    ),
                    FadeInUp(
                      duration: const Duration(milliseconds: 260),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle(
                            'Основные данные',
                            Icons.edit_note_rounded,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: _buildFormSection(),
                          ),
                        ],
                      ),
                    ),
                    FadeInUp(
                      duration: const Duration(milliseconds: 300),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle(
                            'Параметры',
                            Icons.tune_rounded,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              children: [
                                _buildDateSection(),
                                const SizedBox(height: 12),
                                _buildRatingSection(),
                                const SizedBox(height: 12),
                                _buildReminderSection(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    FadeInUp(
                      duration: const Duration(milliseconds: 340),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle(
                            'Программа упражнений',
                            Icons.video_library_rounded,
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              children: [
                                _buildExerciseBanner(),
                                const SizedBox(height: 14),
                                _buildExercisesPreview(),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 90),
                  ],
                ),
              ),
            ),
          ),
          _buildSaveBar(),
        ],
      ),
    );
  }
}

class FeedPalette {
  static const primaryGreen = Color(0xFF00A750);
  static const primaryGreenDark = Color(0xFF008C40);
  static const primaryGreenLight = Color(0xFF00C060);

  static const lightGreen = Color(0xFFE8F5E9);
  static const superLightGreen = Color(0xFFF2FFF5);

  static const white = Color(0xFFFFFFFF);
  static const text = Color(0xFF1A1A1A);
  static const textMuted = Color(0xFF666666);
  static const textLight = Color(0xFF9CA3AF);

  static const background = Color(0xFFF8F9FA);
  static const border = Color(0xFFE5E7EB);

  static const greenGradient = LinearGradient(
    colors: [primaryGreen, primaryGreenDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}