import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'game_zone_api.dart';

class QuizDetailScreen extends StatefulWidget {
  const QuizDetailScreen({super.key});

  @override
  State<QuizDetailScreen> createState() => _QuizDetailScreenState();
}

class _QuizDetailScreenState extends State<QuizDetailScreen> {
  late final int quizId;
  late final int teamId;
  late final String teamName;

  bool loading = true;
  Map<String, dynamic>? quiz;
  Map<String, dynamic>? stats;
  List<dynamic> questions = [];

  final _questionFormKey = GlobalKey<FormState>();
  final TextEditingController _questionController = TextEditingController();
  final TextEditingController _optionAController = TextEditingController();
  final TextEditingController _optionBController = TextEditingController();
  final TextEditingController _optionCController = TextEditingController();
  final TextEditingController _optionDController = TextEditingController();
  String _correctOption = 'A';
  bool _addingQuestion = false;

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

    quizId = _asInt(args['quiz_id']);
    teamId = _asInt(args['team_id']);
    teamName = (args['team_name'] ?? '').toString();

    _load();
  }

  @override
  void dispose() {
    _questionController.dispose();
    _optionAController.dispose();
    _optionBController.dispose();
    _optionCController.dispose();
    _optionDController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => loading = true);

    final res = await GameZoneApi.post('get_quiz_detail.php', {
      'quiz_id': quizId,
    });

    if (!mounted) return;

    setState(() {
      loading = false;
      if (res['success'] == true) {
        quiz = res['quiz'] is Map ? Map<String, dynamic>.from(res['quiz']) : null;
        stats = res['stats'] is Map ? Map<String, dynamic>.from(res['stats']) : null;
        questions = res['questions'] ?? [];
      }
    });
  }

  Future<void> _deleteQuestion(int questionId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Удалить вопрос?'),
          content: const Text('Этот вопрос будет удалён из квиза.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Удалить'),
            ),
          ],
        );
      },
    );

    if (ok != true) return;

    final res = await GameZoneApi.post('delete_player_quiz_question.php', {
      'question_id': questionId,
    });

    Get.snackbar(
      res['success'] == true ? 'Готово' : 'Ошибка',
      res['message'] ?? '',
      snackPosition: SnackPosition.BOTTOM,
    );

    if (res['success'] == true) {
      _load();
    }
  }

  Future<void> _addQuestion() async {
    if (!_questionFormKey.currentState!.validate()) return;

    setState(() => _addingQuestion = true);

    final res = await GameZoneApi.post('add_player_quiz_question.php', {
      'quiz_id': quizId,
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
      _questionController.clear();
      _optionAController.clear();
      _optionBController.clear();
      _optionCController.clear();
      _optionDController.clear();
      _correctOption = 'A';

      Get.back();

      Get.snackbar(
        'Готово',
        res['message'] ?? 'Вопрос добавлен',
        snackPosition: SnackPosition.BOTTOM,
      );

      _load();
    } else {
      Get.snackbar(
        'Ошибка',
        res['message'] ?? 'Не удалось добавить вопрос',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> _openAddQuestionSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Form(
                key: _questionFormKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Добавить вопрос',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _questionController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Вопрос',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Введите вопрос' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _optionAController,
                        decoration: InputDecoration(
                          labelText: 'Вариант A',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Введите вариант A' : null,
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
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Введите вариант B' : null,
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
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Введите вариант C' : null,
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
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Введите вариант D' : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _correctOption,
                        decoration: InputDecoration(
                          labelText: 'Правильный ответ',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'A', child: Text('A')),
                          DropdownMenuItem(value: 'B', child: Text('B')),
                          DropdownMenuItem(value: 'C', child: Text('C')),
                          DropdownMenuItem(value: 'D', child: Text('D')),
                        ],
                        onChanged: (v) {
                          setModalState(() {
                            _correctOption = v ?? 'A';
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _addingQuestion ? null : _addQuestion,
                          icon: _addingQuestion
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.add),
                          label: Text(_addingQuestion ? 'Добавляем...' : 'Добавить вопрос'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _heroCard() {
    final q = quiz ?? {};
    final st = stats ?? {};

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFF9F67FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            (q['title'] ?? 'Квиз').toString(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            (q['description'] ?? '').toString(),
            style: const TextStyle(
              color: Colors.white70,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _statCard('Вопросов', '${questions.length}')),
              const SizedBox(width: 10),
              Expanded(child: _statCard('Попыток', '${st['attempts_count'] ?? 0}')),
              const SizedBox(width: 10),
              Expanded(child: _statCard('Средний %', '${st['average_score'] ?? 0}')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statCard(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _questionCard(Map<String, dynamic> q, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Вопрос ${index + 1}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF7C3AED),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _deleteQuestion(_asInt(q['id'])),
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Удалить вопрос',
              ),
            ],
          ),
          Text(
            (q['question'] ?? '').toString(),
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          _optionTile('A', q['option_a'], q['correct_option']),
          const SizedBox(height: 8),
          _optionTile('B', q['option_b'], q['correct_option']),
          const SizedBox(height: 8),
          _optionTile('C', q['option_c'], q['correct_option']),
          const SizedBox(height: 8),
          _optionTile('D', q['option_d'], q['correct_option']),
        ],
      ),
    );
  }

  Widget _optionTile(String label, dynamic text, dynamic correct) {
    final isCorrect = label == (correct ?? '').toString();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isCorrect ? const Color(0xFFF6EEFF) : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCorrect ? const Color(0xFF7C3AED) : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: isCorrect ? const Color(0xFF7C3AED) : const Color(0xFFE5E7EB),
            child: Text(
              label,
              style: TextStyle(
                color: isCorrect ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w900,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text((text ?? '').toString()),
          ),
          if (isCorrect)
            const Icon(
              Icons.check_circle,
              color: Color(0xFF7C3AED),
              size: 18,
            ),
        ],
      ),
    );
  }

  Widget _emptyQuestions() {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.quiz_outlined,
            size: 44,
            color: Color(0xFF7C3AED),
          ),
          const SizedBox(height: 12),
          const Text(
            'Пока нет вопросов',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Добавь первый вопрос в этот квиз.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF6B7280),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _openAddQuestionSheet,
              icon: const Icon(Icons.add),
              label: const Text('Добавить вопрос'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = (quiz?['title'] ?? 'Детали квиза').toString();

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            onPressed: _openAddQuestionSheet,
            icon: const Icon(Icons.add),
            tooltip: 'Добавить вопрос',
          ),
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            tooltip: 'Обновить',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddQuestionSheet,
        icon: const Icon(Icons.add),
        label: const Text('Новый вопрос'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _heroCard(),
                  const SizedBox(height: 18),
                  const Text(
                    'Вопросы квиза',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (questions.isEmpty)
                    _emptyQuestions()
                  else
                    ...questions.asMap().entries.map(
                          (entry) => _questionCard(
                            Map<String, dynamic>.from(entry.value),
                            entry.key,
                          ),
                        ),
                  const SizedBox(height: 90),
                ],
              ),
            ),
    );
  }
}