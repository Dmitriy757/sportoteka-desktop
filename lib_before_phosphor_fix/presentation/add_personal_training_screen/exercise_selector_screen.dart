import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/presentation/add_personal_training_screen/exercise_detail_screen.dart';

class ExerciseSelectorScreen extends StatefulWidget {
  final Function(List<Map<String, dynamic>>) onSelected;

  const ExerciseSelectorScreen({
    super.key,
    required this.onSelected,
  });

  @override
  State<ExerciseSelectorScreen> createState() => _ExerciseSelectorScreenState();
}

class _ExerciseSelectorScreenState extends State<ExerciseSelectorScreen> {
  List<dynamic> exercises = [];
  List<Map<String, dynamic>> selectedExercises = [];
  bool isLoading = true;
  String selectedCategory = 'Все';
  String searchQuery = '';
  int? trainerId;

  final List<String> categories = const [
    'Все',
    'Грудь',
    'Спина',
    'Ноги',
    'Плечи',
    'Руки',
    'Пресс',
    'Кардио',
    'Функциональные',
    'Растяжка',
  ];

  @override
  void initState() {
    super.initState();
    _loadTrainerId();
    _fetchExercises();
  }

  Future<void> _loadTrainerId() async {
    trainerId = await PrefUtils.getUserId();
    if (mounted) setState(() {});
  }

  Future<void> _fetchExercises() async {
    try {
      final response = await http.get(
        Uri.parse('https://sportotekaapp.ru/api/get_exercises.php'),
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body);
        setState(() {
          exercises = decoded is List ? decoded : [];
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (_) {
      setState(() => isLoading = false);
    }
  }

  List<dynamic> get filteredExercises {
    return exercises.where((ex) {
      final matchesCategory =
          selectedCategory == 'Все' || ex['category'] == selectedCategory;
      final title = ex['title']?.toString().toLowerCase() ?? '';
      final matchesSearch = title.contains(searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();
  }

  bool _isExerciseSelected(Map<String, dynamic> exercise) {
    final id = int.tryParse('${exercise['id']}');
    return selectedExercises.any((e) => e['exercise_id'] == id);
  }

  void _removeFromSelection(Map<String, dynamic> exercise) {
    final id = int.tryParse('${exercise['id']}');
    setState(() {
      selectedExercises.removeWhere((e) => e['exercise_id'] == id);
    });
  }

  void _confirmSelection() {
    widget.onSelected(selectedExercises);
  }

  void _addToSelection(Map<String, dynamic> exercise) {
    int sets = 3;
    int reps = 10;
    double weight = 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: FeedPalette.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, modalSetState) {
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 46,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            gradient: FeedPalette.greenGradient,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.fitness_center_rounded,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            exercise['title']?.toString() ?? 'Упражнение',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              color: FeedPalette.text,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Укажите параметры, с которыми упражнение попадёт в тренировочную программу.',
                      style: TextStyle(
                        color: FeedPalette.textMuted,
                        fontSize: 13,
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInputField(
                            label: 'Подходы',
                            initialValue: '$sets',
                            onChanged: (val) =>
                                sets = int.tryParse(val) ?? 0,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildInputField(
                            label: 'Повторения',
                            initialValue: '$reps',
                            onChanged: (val) =>
                                reps = int.tryParse(val) ?? 0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInputField(
                      label: 'Вес (кг)',
                      initialValue: '$weight',
                      onChanged: (val) => weight = double.tryParse(val) ?? 0,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: FeedPalette.greenGradient,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              selectedExercises.add({
                                'exercise_id': int.tryParse('${exercise['id']}'),
                                'title': exercise['title'],
                                'sets': sets,
                                'reps': reps,
                                'weight': weight,
                              });
                            });
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.add_rounded, color: Colors.white),
                          label: const Text(
                            'Добавить упражнение',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInputField({
    required String label,
    required Function(String) onChanged,
    String? initialValue,
  }) {
    return TextFormField(
      initialValue: initialValue,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: FeedPalette.textMuted,
          fontWeight: FontWeight.w700,
        ),
        filled: true,
        fillColor: FeedPalette.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: FeedPalette.border),
        ),
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
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: onChanged,
    );
  }

  void _openDetails(Map<String, dynamic> exercise) {
    if (trainerId == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExerciseDetailScreen(
          exerciseId: int.tryParse('${exercise['id']}') ?? 0,
          title: exercise['title']?.toString() ?? 'Упражнение',
          image: '',
          description: exercise['description']?.toString() ?? '',
          trainerId: trainerId!,
        ),
      ),
    );
  }

  Widget _whiteCard({required Widget child, EdgeInsets? padding}) {
    return Container(
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
      padding: padding ?? const EdgeInsets.all(14),
      child: child,
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
            child: const Icon(Icons.fitness_center_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Выбор упражнений',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: FeedPalette.text,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Добавьте упражнения в тренировочную программу',
                  style: TextStyle(
                    color: FeedPalette.textMuted,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: _confirmSelection,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: FeedPalette.greenGradient,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    '${selectedExercises.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBanner() {
    return _whiteCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: FeedPalette.superLightGreen,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              color: FeedPalette.primaryGreen,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Откройте упражнение, чтобы посмотреть описание и видео от пользователей, затем добавьте его в свою тренировку.',
              style: TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: FeedPalette.text,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return _whiteCard(
      padding: EdgeInsets.zero,
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Поиск упражнений…',
          hintStyle: const TextStyle(
            color: FeedPalette.textMuted,
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: const Icon(Icons.search, color: FeedPalette.textMuted),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
        onChanged: (val) => setState(() => searchQuery = val),
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 42,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final cat = categories[index];
          final selected = selectedCategory == cat;

          return Padding(
            padding: EdgeInsets.only(
              right: index == categories.length - 1 ? 0 : 8,
            ),
            child: ChoiceChip(
              label: Text(cat),
              selected: selected,
              onSelected: (_) => setState(() => selectedCategory = cat),
              selectedColor: FeedPalette.primaryGreen,
              backgroundColor: FeedPalette.white,
              side: BorderSide(
                color: selected
                    ? FeedPalette.primaryGreen
                    : FeedPalette.border,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              labelStyle: TextStyle(
                color: selected ? Colors.white : FeedPalette.text,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSelectedPreview() {
    if (selectedExercises.isEmpty) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            FeedPalette.primaryGreen.withOpacity(0.10),
            FeedPalette.superLightGreen,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: FeedPalette.lightGreen),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.task_alt_rounded,
                color: FeedPalette.primaryGreen,
              ),
              const SizedBox(width: 8),
              Text(
                'Выбрано упражнений: ${selectedExercises.length}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  color: FeedPalette.text,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: selectedExercises.take(6).map((e) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: FeedPalette.border),
                ),
                child: Text(
                  '${e['title']}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: FeedPalette.text,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseCard(Map<String, dynamic> exercise) {
    final int videoCount =
        int.tryParse('${exercise['video_count'] ?? '0'}') ?? 0;
    final double rating =
        double.tryParse('${exercise['rating'] ?? '0'}') ?? 0.0;
    final String title = exercise['title']?.toString() ?? 'Упражнение';
    final String category = exercise['category']?.toString() ?? '';
    final bool isSelected = _isExerciseSelected(exercise);

    return Container(
      decoration: BoxDecoration(
        color: FeedPalette.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected
              ? FeedPalette.primaryGreen.withOpacity(0.35)
              : FeedPalette.border,
          width: isSelected ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.045),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _openDetails(exercise),
                    borderRadius: BorderRadius.circular(8),
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: FeedPalette.primaryGreen,
                        height: 1.3,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (isSelected)
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: FeedPalette.superLightGreen,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: FeedPalette.primaryGreen,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: FeedPalette.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                category.isEmpty ? 'Без категории' : category,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: FeedPalette.textMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: List.generate(5, (index) {
                final filled = rating >= index + 1;
                final half = rating > index && rating < index + 1;
                return Icon(
                  filled
                      ? Icons.star_rounded
                      : half
                          ? Icons.star_half_rounded
                          : Icons.star_border_rounded,
                  size: 16,
                  color: const Color(0xFFFFC83D),
                );
              }),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F7FA),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.videocam_rounded,
                    size: 18,
                    color: FeedPalette.primaryGreen,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$videoCount',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: FeedPalette.primaryGreen,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _openDetails(exercise),
                    child: const Text(
                      'Смотреть',
                      style: TextStyle(
                        color: FeedPalette.primaryGreen,
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 42,
              width: double.infinity,
              child: Container(
                decoration: BoxDecoration(
                  gradient: isSelected ? null : FeedPalette.greenGradient,
                  color: isSelected ? const Color(0xFF6B7280) : null,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ElevatedButton.icon(
                  onPressed: isSelected
                      ? () => _removeFromSelection(exercise)
                      : () => _addToSelection(exercise),
                  icon: Icon(
                    isSelected ? Icons.remove_rounded : Icons.add_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                  label: Text(
                    isSelected ? 'Убрать' : 'Добавить',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: FeedPalette.superLightGreen,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 42,
                color: FeedPalette.primaryGreen,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Упражнения не найдены',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: FeedPalette.text,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Попробуйте изменить категорию или текст поиска.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: FeedPalette.textMuted,
                height: 1.4,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomPanel() {
    return Container(
      color: FeedPalette.background,
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 14,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoBanner(),
              const SizedBox(height: 12),
              _buildSearch(),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: _buildCategoryChips(),
              ),
              if (selectedExercises.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildSelectedPreview(),
              ],
            ],
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
        title: const Text(
          'Выбор упражнений',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: FeedPalette.text,
            fontSize: 16,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Подтвердить выбор',
            onPressed: _confirmSelection,
            icon: Container(
              decoration: BoxDecoration(
                gradient: FeedPalette.greenGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(8),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.check, color: Colors.white, size: 18),
                  if (selectedExercises.isNotEmpty)
                    Positioned(
                      right: -6,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${selectedExercises.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Column(
        children: [
          _buildTopCard(),
          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: FeedPalette.primaryGreen,
                    ),
                  )
                : filteredExercises.isEmpty
                    ? _buildEmptyState()
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.78,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                        ),
                        itemCount: filteredExercises.length,
                        itemBuilder: (context, index) {
                          final ex =
                              filteredExercises[index] as Map<String, dynamic>;
                          return _buildExerciseCard(ex);
                        },
                      ),
          ),
        ],
      ),
      bottomSheet: isLoading ? null : _buildBottomPanel(),
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