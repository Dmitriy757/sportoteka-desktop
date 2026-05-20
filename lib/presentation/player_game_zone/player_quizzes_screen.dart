import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'game_zone_api.dart';

class PlayerQuizzesScreen extends StatefulWidget {
  const PlayerQuizzesScreen({super.key});

  @override
  State<PlayerQuizzesScreen> createState() => _PlayerQuizzesScreenState();
}

class _PlayerQuizzesScreenState extends State<PlayerQuizzesScreen> {
  late final int teamId;
  late final int userId;
  bool loading = true;
  List<dynamic> items = [];

  Color get primary => const Color(0xFF00C853);
  Color get bg => const Color(0xFFF3F5F8);
  Color get cardBg => Colors.white;
  Color get textPrimary => const Color(0xFF1E293B);
  Color get textSecondary => const Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    final args = Map<String, dynamic>.from(Get.arguments ?? {});
    teamId = args['team_id'] ?? 0;
    userId = args['user_id'] ?? 0;
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);

    final res = await GameZoneApi.post('get_player_quizzes.php', {
      'team_id': teamId,
    });

    if (!mounted) return;

    setState(() {
      loading = false;
      items = res['items'] ?? [];
    });
  }

  Widget _matteSurface({required Widget child, VoidCallback? onTap}) {
    final content = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: content,
        ),
      );
    }
    return content;
  }

  Widget _quizCard(Map<String, dynamic> quiz) {
   final questions = _parseQuestions(quiz['questions']);
final pointsReward = quiz['points_reward'] ?? 0;

    return _matteSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.quiz_rounded, color: primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      quiz['title'] ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      quiz['description'] ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
             _infoChip(
  icon: Icons.help_outline_rounded,
  label: "${questions.length} вопросов",
),
              const SizedBox(width: 8),
              _infoChip(
                icon: Icons.star_rounded,
                label: "$pointsReward очков",
                color: Colors.amber.shade700,
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _startQuiz(Map<String, dynamic>.from(quiz)),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                "Начать квиз",
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  List<Map<String, dynamic>> _parseQuestions(dynamic raw) {
  if (raw == null) return [];

  try {
    if (raw is List) {
      return raw
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }

    if (raw is String && raw.trim().isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
    }
  } catch (_) {}

  return [];
}

  Widget _infoChip({required IconData icon, required String label, Color? color}) {
    final c = color ?? primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: c),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: c,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startQuiz(Map<String, dynamic> quiz) async {
    final questions = List<Map<String, dynamic>>.from(quiz['questions'] ?? []);
    final answers = <String, String>{};
    final quizTitle = quiz['title'] ?? 'Квиз';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _QuizBottomSheet(
        primary: primary,
        quizTitle: quizTitle,
        quizDescription: quiz['description'] ?? '',
        questions: questions,
        onSubmit: (answersMap) async {
          final res = await GameZoneApi.post('submit_player_quiz.php', {
            'quiz_id': quiz['id'],
            'team_id': teamId,
            'user_id': userId,
            'answers': jsonEncode(answersMap),
          });

          if (context.mounted) {
            Get.snackbar(
              res['success'] == true ? '🎉 Результат' : '❌ Ошибка',
              res['success'] == true
                  ? 'Правильных: ${res['correct_answers']}/${res['total_questions']}\nБаллы: ${res['score']}% • Очков: +${res['awarded_points']}'
                  : (res['message'] ?? 'Что-то пошло не так'),
              snackPosition: SnackPosition.BOTTOM,
              duration: const Duration(seconds: 4),
              backgroundColor: res['success'] == true ? primary : Colors.red.shade600,
              colorText: Colors.white,
            );
          }

          return res['success'] == true;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          "Футбольные квизы",
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        actions: [
          IconButton(
            tooltip: "Обновить",
            onPressed: loading ? null : _load,
            icon: Icon(Icons.refresh_rounded, color: primary),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: primary,
        child: loading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: primary),
                    const SizedBox(height: 12),
                    Text(
                      "Загрузка квизов...",
                      style: TextStyle(
                        color: textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )
            : items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            Icons.quiz_outlined,
                            size: 40,
                            color: primary.withOpacity(0.5),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Нет доступных квизов",
                          style: TextStyle(
                            color: textSecondary,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Проверьте позже или обратитесь к тренеру",
                          style: TextStyle(
                            color: textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      ...items.map((e) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _quizCard(Map<String, dynamic>.from(e)),
                          )),
                    ],
                  ),
      ),
    );
  }
}

// Отдельный виджет для bottom sheet с квизом
// Отдельный виджет для bottom sheet с квизом
class _QuizBottomSheet extends StatefulWidget {
  final Color primary;
  final String quizTitle;
  final String quizDescription;
  final List<Map<String, dynamic>> questions;
  final Future<bool> Function(Map<String, String> answers) onSubmit;

  const _QuizBottomSheet({
    required this.primary,
    required this.quizTitle,
    required this.quizDescription,
    required this.questions,
    required this.onSubmit,
  });

  @override
  State<_QuizBottomSheet> createState() => _QuizBottomSheetState();
}

class _QuizBottomSheetState extends State<_QuizBottomSheet> {
  final Map<String, String> _answers = {};
  bool _isSubmitting = false;

  String _getOptionLetter(int index) {
    return String.fromCharCode(65 + index); // A, B, C, D...
  }

  @override
  Widget build(BuildContext context) {
    final answeredCount = _answers.keys.length;
    final totalCount = widget.questions.length;
    final canSubmit = answeredCount == totalCount && !_isSubmitting;

    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.9,
        margin: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 24,
              offset: Offset(0, 10),
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: const Color(0xFFE5E7EB), width: 1),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: widget.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.quiz_rounded,
                      color: widget.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.quizTitle,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.quizDescription,
                          style: TextStyle(
                            color: const Color(0xFF64748B),
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            // Progress
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: widget.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "Прогресс: $answeredCount/$totalCount",
                      style: TextStyle(
                        color: widget.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: answeredCount / totalCount,
                        backgroundColor: const Color(0xFFE5E7EB),
                        color: widget.primary,
                        minHeight: 6,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Questions list
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: widget.questions.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final q = entry.value;
                    final qid = '${q['id']}';
                    final opts = Map<String, dynamic>.from(q['options'] ?? {});
                    final selected = _answers[qid];
                    final optionEntries = opts.entries.toList();
                    final isAnswered = selected != null;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: isAnswered 
                            ? widget.primary.withOpacity(0.02)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isAnswered 
                              ? widget.primary.withOpacity(0.3)
                              : const Color(0xFFE5E7EB),
                          width: isAnswered ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Вопрос
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: widget.primary.withOpacity(0.05),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(15),
                                topRight: Radius.circular(15),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: widget.primary,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Text(
                                      "${idx + 1}",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    q['question'] ?? '',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                      height: 1.3,
                                    ),
                                    softWrap: true,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Варианты ответов
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              children: optionEntries.asMap().entries.map((optEntry) {
                                final optIdx = optEntry.key;
                                final opt = optEntry.value;
                                final letter = _getOptionLetter(optIdx);
                                final isSelected = selected == opt.key;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: _isSubmitting
                                          ? null
                                          : () {
                                              setState(() {
                                                _answers[qid] = opt.key;
                                              });
                                            },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? widget.primary.withOpacity(0.08)
                                              : const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: isSelected
                                                ? widget.primary
                                                : const Color(0xFFE5E7EB),
                                            width: isSelected ? 1.5 : 1,
                                          ),
                                        ),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            Container(
                                              width: 30,
                                              height: 30,
                                              decoration: BoxDecoration(
                                                color: isSelected
                                                    ? widget.primary
                                                    : Colors.white,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: isSelected
                                                      ? widget.primary
                                                      : const Color(0xFFCBD5E1),
                                                ),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  letter,
                                                  style: TextStyle(
                                                    color: isSelected
                                                        ? Colors.white
                                                        : const Color(0xFF64748B),
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                '${opt.value}',
                                                style: TextStyle(
                                                  color: isSelected
                                                      ? widget.primary
                                                      : const Color(0xFF334155),
                                                  fontWeight: isSelected
                                                      ? FontWeight.w800
                                                      : FontWeight.w600,
                                                  fontSize: 14,
                                                  height: 1.3,
                                                ),
                                                softWrap: true,
                                              ),
                                            ),
                                            if (isSelected)
                                              Icon(
                                                Icons.check_circle_rounded,
                                                color: widget.primary,
                                                size: 22,
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            // Submit button
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: const Color(0xFFE5E7EB), width: 1),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: canSubmit
                      ? () async {
                          setState(() => _isSubmitting = true);
                          final success = await widget.onSubmit(_answers);
                          if (success && mounted) {
                            Navigator.pop(context);
                          }
                          if (mounted && !success) {
                            setState(() => _isSubmitting = false);
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                    disabledBackgroundColor: const Color(0xFFE5E7EB),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          answeredCount == totalCount
                              ? "✅ Завершить квиз"
                              : "📝 Ответьте на все вопросы (${totalCount - answeredCount} осталось)",
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}