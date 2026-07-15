import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'game_zone_api.dart';
import 'game_zone_cmr_style.dart';

class CreateQuizScreen extends StatefulWidget {
  const CreateQuizScreen({super.key});

  @override
  State<CreateQuizScreen> createState() => _CreateQuizScreenState();
}

class _CreateQuizScreenState extends State<CreateQuizScreen> {
  late final int teamId;
  late final int userId;
  late final String teamName;

  final _quizFormKey = GlobalKey<FormState>();
  final _questionFormKey = GlobalKey<FormState>();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _pointsController =
      TextEditingController(text: '15');

  final TextEditingController _questionController = TextEditingController();
  final TextEditingController _optionAController = TextEditingController();
  final TextEditingController _optionBController = TextEditingController();
  final TextEditingController _optionCController = TextEditingController();
  final TextEditingController _optionDController = TextEditingController();

  String _correctOption = 'A';

  bool _creatingQuiz = false;
  bool _addingQuestion = false;

  int? _quizId;
  final List<Map<String, dynamic>> _localQuestions = [];

  int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  @override
  void initState() {
    super.initState();

    final rawArgs = Get.arguments;
    final args = rawArgs is Map
        ? Map<String, dynamic>.from(rawArgs)
        : <String, dynamic>{};

    teamId = _asInt(args['team_id']);
    userId = _asInt(args['user_id']);
    teamName = (args['team_name'] ?? '').toString();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _pointsController.dispose();
    _questionController.dispose();
    _optionAController.dispose();
    _optionBController.dispose();
    _optionCController.dispose();
    _optionDController.dispose();
    super.dispose();
  }

  Future<void> _createQuiz() async {
    if (!_quizFormKey.currentState!.validate()) return;

    setState(() => _creatingQuiz = true);

    final res = await GameZoneApi.post('create_player_quiz.php', {
      'team_id': teamId,
      'title': _titleController.text.trim(),
      'description': _descriptionController.text.trim(),
      'points_reward': _pointsController.text.trim(),
      'created_by': userId,
    });

    if (!mounted) return;

    setState(() => _creatingQuiz = false);

    if (res['success'] == true) {
      setState(() {
        _quizId = _asInt(res['quiz_id']);
      });

      Get.snackbar(
        'Готово',
        res['message'] ?? 'Квиз создан',
        snackPosition: SnackPosition.BOTTOM,
      );
    } else {
      Get.snackbar(
        'Ошибка',
        res['message'] ?? 'Не удалось создать квиз',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> _addQuestion() async {
    if (_quizId == null || _quizId! <= 0) {
      Get.snackbar(
        'Ошибка',
        'Сначала создай квиз',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    if (!_questionFormKey.currentState!.validate()) return;

    setState(() => _addingQuestion = true);

    final res = await GameZoneApi.post('add_player_quiz_question.php', {
      'quiz_id': _quizId!,
      'question': _questionController.text.trim(),
      'option_a': _optionAController.text.trim(),
      'option_b': _optionBController.text.trim(),
      'option_c': _optionCController.text.trim(),
      'option_d': _optionDController.text.trim(),
      'correct_option': _correctOption,
    });

    if (!mounted) return;

    setState(() => _addingQuestion = false);

    if (res['success'] == true) {
      setState(() {
        _localQuestions.add({
          'question': _questionController.text.trim(),
          'option_a': _optionAController.text.trim(),
          'option_b': _optionBController.text.trim(),
          'option_c': _optionCController.text.trim(),
          'option_d': _optionDController.text.trim(),
          'correct_option': _correctOption,
        });
      });

      _questionController.clear();
      _optionAController.clear();
      _optionBController.clear();
      _optionCController.clear();
      _optionDController.clear();
      _correctOption = 'A';

      Get.snackbar(
        'Готово',
        res['message'] ?? 'Вопрос добавлен',
        snackPosition: SnackPosition.BOTTOM,
      );

      setState(() {});
    } else {
      Get.snackbar(
        'Ошибка',
        res['message'] ?? 'Не удалось добавить вопрос',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Widget _headerCard() {
    return GameZoneCmr.header(
      title: 'Новый квиз для команды',
      subtitle: '${teamName.isEmpty ? 'Командный квиз' : teamName}\nСоздай викторину, добавь вопросы и правильные ответы. Игроки смогут проходить её в игровой зоне.',
      icon: Icons.quiz_rounded,
    );
  }

  Widget _quizCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      border: Border.all(color: GzColors.divider),
      ),
      child: Form(
        key: _quizFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Шаг 1. Основная информация',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Название квиза',
                hintText: 'Например: Правила футбола',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Введите название квиза';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Описание',
                hintText: 'Коротко опиши тему квиза',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Введите описание';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _pointsController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Награда в очках',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                prefixIcon: const Icon(Icons.emoji_events_outlined),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Введите количество очков';
                }
                final n = int.tryParse(v.trim());
                if (n == null || n <= 0) {
                  return 'Введите корректное число';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _creatingQuiz || _quizId != null ? null : _createQuiz,
                icon: _creatingQuiz
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.quiz_outlined),
                label: Text(
                  _quizId != null
                      ? 'Квиз уже создан'
                      : (_creatingQuiz ? 'Создаём...' : 'Создать квиз'),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: GzColors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _correctOptionPicker() {
    final options = ['A', 'B', 'C', 'D'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Правильный ответ',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: options.map((opt) {
            final selected = _correctOption == opt;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _correctOption = opt;
                  });
                },
                child: Container(
                  margin: EdgeInsets.only(
                    right: opt != 'D' ? 8 : 0,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: selected
                        ? GzColors.greenSoft
                        : GzColors.soft,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected
                          ? GzColors.green
                          : GzColors.divider,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      opt,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: selected
                            ? GzColors.green
                            : GzColors.text,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _questionCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      border: Border.all(color: GzColors.divider),
      ),
      child: Form(
        key: _questionFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Шаг 2. Добавь вопросы',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _questionController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Вопрос',
                hintText: 'Например: Сколько игроков одной команды на поле?',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Введите вопрос';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _optionAController,
              decoration: InputDecoration(
                labelText: 'Вариант A',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Введите вариант A';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _optionBController,
              decoration: InputDecoration(
                labelText: 'Вариант B',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Введите вариант B';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _optionCController,
              decoration: InputDecoration(
                labelText: 'Вариант C',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Введите вариант C';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _optionDController,
              decoration: InputDecoration(
                labelText: 'Вариант D',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Введите вариант D';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            _correctOptionPicker(),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed:
                    _quizId == null || _addingQuestion ? null : _addQuestion,
                icon: _addingQuestion
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_task_outlined),
                label: Text(
                  _quizId == null
                      ? 'Сначала создай квиз'
                      : (_addingQuestion ? 'Добавляем...' : 'Добавить вопрос'),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: GzColors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _questionPreviewCard(Map<String, dynamic> q, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: GzColors.soft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: GzColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Вопрос ${index + 1}',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: GzColors.green,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            q['question'] ?? '',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 10),
          Text('A: ${q['option_a']}'),
          Text('B: ${q['option_b']}'),
          Text('C: ${q['option_c']}'),
          Text('D: ${q['option_d']}'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: GzColors.greenSoft,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Правильный ответ: ${q['correct_option']}',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: GzColors.green,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _questionsList() {
    if (_localQuestions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: GzColors.soft,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: GzColors.divider),
        ),
        child: const Center(
          child: Text(
            'Пока нет добавленных вопросов',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: GzColors.subtle,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Добавленные вопросы',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 12),
        ..._localQuestions.asMap().entries.map(
              (entry) => _questionPreviewCard(entry.value, entry.key),
            ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final validTeam = teamId > 0;

    return Scaffold(
      backgroundColor: GzColors.bg,
      appBar: GameZoneCmr.appBar(
        title: const Text('Создать квиз'),
      ),
      body: GameZoneCmr.page(
        context,
        child: !validTeam
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Не удалось определить команду для создания квиза',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            )
          : ListView(
              padding: GameZoneCmr.listPadding(context),
              children: [
                _headerCard(),
                const SizedBox(height: 16),
                _quizCard(),
                const SizedBox(height: 16),
                _questionCard(),
                const SizedBox(height: 20),
                _questionsList(),
                const SizedBox(height: 30),
              ],
            ),
      ),
    );
  }
}
