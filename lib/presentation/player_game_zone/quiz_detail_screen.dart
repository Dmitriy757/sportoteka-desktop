import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'game_zone_api.dart';
import 'game_zone_cmr_style.dart';

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
    if (v is num) return v.toInt();
    return int.tryParse('${v ?? ''}'.trim()) ?? 0;
  }

  @override
  void initState() {
    super.initState();
    final rawArgs = Get.arguments;
    final args = rawArgs is Map
        ? Map<String, dynamic>.from(rawArgs)
        : <String, dynamic>{};
    quizId = _asInt(args['quiz_id'] ?? args['id']);
    teamId = _asInt(args['team_id'] ?? args['teamId']);
    teamName = (args['team_name'] ?? args['teamName'] ?? '').toString();
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
    if (mounted) setState(() => loading = true);
    final res = await GameZoneApi.post('get_quiz_detail.php', {
      'quiz_id': quizId,
    });
    if (!mounted) return;
    setState(() {
      loading = false;
      if (res['success'] == true) {
        quiz = res['quiz'] is Map
            ? Map<String, dynamic>.from(res['quiz'])
            : null;
        stats = res['stats'] is Map
            ? Map<String, dynamic>.from(res['stats'])
            : null;
        questions = res['questions'] ?? [];
      }
    });
  }

  Future<void> _deleteQuestion(int questionId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const _QuizDot(color: GzColors.red, size: 7),
                  const SizedBox(width: 9),
                  Expanded(child: Text('Удалить вопрос?', style: GzText.title(16))),
                ],
              ),
              const SizedBox(height: 9),
              Text('Этот вопрос будет удалён из квиза.', style: GzText.muted(11.3)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      title: 'Отмена',
                      onTap: () => Navigator.pop(dialogContext, false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ActionButton(
                      title: 'Удалить',
                      danger: true,
                      onTap: () => Navigator.pop(dialogContext, true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true) return;

    final res = await GameZoneApi.post('delete_player_quiz_question.php', {
      'question_id': questionId,
    });
    Get.snackbar(
      res['success'] == true ? 'Готово' : 'Ошибка',
      '${res['message'] ?? ''}',
      snackPosition: SnackPosition.BOTTOM,
    );
    if (res['success'] == true) await _load();
  }

  Future<bool> _addQuestion() async {
    if (!(_questionFormKey.currentState?.validate() ?? false)) return false;
    setState(() => _addingQuestion = true);
    try {
      final res = await GameZoneApi.post('add_player_quiz_question.php', {
        'quiz_id': quizId,
        'question': _questionController.text.trim(),
        'option_a': _optionAController.text.trim(),
        'option_b': _optionBController.text.trim(),
        'option_c': _optionCController.text.trim(),
        'option_d': _optionDController.text.trim(),
        'correct_option': _correctOption,
      });
      if (!mounted) return false;

      if (res['success'] == true) {
        _questionController.clear();
        _optionAController.clear();
        _optionBController.clear();
        _optionCController.clear();
        _optionDController.clear();
        setState(() => _correctOption = 'A');
        Get.snackbar(
          'Вопрос добавлен',
          '${res['message'] ?? ''}',
          snackPosition: SnackPosition.BOTTOM,
        );
        await _load();
        return true;
      }

      Get.snackbar(
        'Ошибка',
        '${res['message'] ?? 'Не удалось добавить вопрос'}',
        snackPosition: SnackPosition.BOTTOM,
      );
      return false;
    } finally {
      if (mounted) setState(() => _addingQuestion = false);
    }
  }

  InputDecoration _decoration(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: GzColors.soft,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
      );

  Future<void> _openAddQuestionSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              padding: EdgeInsets.fromLTRB(
                16,
                10,
                16,
                MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: _questionFormKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: GzColors.line,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const _QuizDotCluster(),
                          const SizedBox(width: 10),
                          Expanded(child: Text('Добавить вопрос', style: GzText.title(16.5))),
                          IconButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            icon: const Icon(Icons.close_rounded, size: 18),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _questionController,
                        maxLines: 2,
                        style: GzText.value(12.2),
                        decoration: _decoration('Вопрос'),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Введите вопрос' : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _optionAController,
                        style: GzText.value(12.1),
                        decoration: _decoration('Вариант A'),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Введите вариант A' : null,
                      ),
                      const SizedBox(height: 7),
                      TextFormField(
                        controller: _optionBController,
                        style: GzText.value(12.1),
                        decoration: _decoration('Вариант B'),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Введите вариант B' : null,
                      ),
                      const SizedBox(height: 7),
                      TextFormField(
                        controller: _optionCController,
                        style: GzText.value(12.1),
                        decoration: _decoration('Вариант C'),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Введите вариант C' : null,
                      ),
                      const SizedBox(height: 7),
                      TextFormField(
                        controller: _optionDController,
                        style: GzText.value(12.1),
                        decoration: _decoration('Вариант D'),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Введите вариант D' : null,
                      ),
                      const SizedBox(height: 10),
                      Text('Правильный ответ', style: GzText.caption()),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          for (final option in const ['A', 'B', 'C', 'D']) ...[
                            if (option != 'A') const SizedBox(width: 6),
                            Expanded(
                              child: Material(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(9),
                                child: InkWell(
                                  onTap: () => setSheetState(() => _correctOption = option),
                                  borderRadius: BorderRadius.circular(9),
                                  child: Container(
                                    height: 36,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: _correctOption == option ? GzColors.greenSoft : GzColors.soft,
                                      borderRadius: BorderRadius.circular(9),
                                    ),
                                    child: Text(
                                      option,
                                      style: GzText.action(
                                        color: _correctOption == option ? GzColors.greenDark : GzColors.muted2,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _ActionButton(
                          title: _addingQuestion ? 'Добавляем…' : 'Добавить вопрос',
                          primary: true,
                          enabled: !_addingQuestion,
                          onTap: () async {
                            final ok = await _addQuestion();
                            if (ok && sheetContext.mounted) {
                              Navigator.pop(sheetContext);
                            }
                          },
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

  Widget _header() {
    final q = quiz ?? <String, dynamic>{};
    final st = stats ?? <String, dynamic>{};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: _QuizDot(color: GzColors.green, size: 7),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${q['title'] ?? 'Квиз'}', style: GzText.title(20)),
                  const SizedBox(height: 4),
                  Text(
                    teamName.isEmpty ? 'Командный квиз' : teamName,
                    style: GzText.muted(10.8),
                  ),
                ],
              ),
            ),
            Material(
              color: GzColors.soft,
              borderRadius: BorderRadius.circular(9),
              child: InkWell(
                onTap: _openAddQuestionSheet,
                borderRadius: BorderRadius.circular(9),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                  child: Text('Добавить вопрос', style: GzText.action(color: GzColors.greenDark)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: GzColors.soft, borderRadius: BorderRadius.circular(12)),
          child: Row(
            children: [
              Expanded(child: _Metric(value: '${questions.length}', label: 'вопросов')),
              Expanded(child: _Metric(value: '${st['attempts_count'] ?? 0}', label: 'попыток')),
              Expanded(child: _Metric(value: '${q['points_reward'] ?? 0}', label: 'очков')),
            ],
          ),
        ),
        if ('${q['description'] ?? ''}'.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: GzColors.soft, borderRadius: BorderRadius.circular(12)),
            child: Text('${q['description']}', style: GzText.muted(11.4)),
          ),
        ],
      ],
    );
  }

  Widget _questionRow(Map<String, dynamic> q, int index) {
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 10, 8, 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 5),
                child: _QuizDot(color: GzColors.green, size: 6),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Вопрос ${index + 1}', style: GzText.caption().copyWith(color: GzColors.greenDark)),
                    const SizedBox(height: 3),
                    Text('${q['question'] ?? ''}', style: GzText.value(12)),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                elevation: 0,
                color: Colors.white,
                surfaceTintColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (value) {
                  if (value == 'delete') _deleteQuestion(_asInt(q['id']));
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Удалить вопрос', style: GzText.action(color: GzColors.red)),
                  ),
                ],
                child: Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: GzColors.soft, borderRadius: BorderRadius.circular(9)),
                  child: Text('•••', style: GzText.action(color: GzColors.muted2).copyWith(fontSize: 10.5, letterSpacing: 1.1)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          for (final option in const ['A', 'B', 'C', 'D']) ...[
            _optionTile(option, q['option_${option.toLowerCase()}'], q['correct_option']),
            if (option != 'D') const SizedBox(height: 5),
          ],
        ],
      ),
    );
  }

  Widget _optionTile(String label, dynamic text, dynamic correct) {
    final isCorrect = label == '${correct ?? ''}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isCorrect ? GzColors.greenSoft : GzColors.soft,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        children: [
          _QuizDot(
            color: isCorrect ? GzColors.green : GzColors.muted2,
            size: isCorrect ? 6 : 4.5,
            opacity: isCorrect ? 1 : .45,
          ),
          const SizedBox(width: 8),
          SizedBox(width: 16, child: Text(label, style: GzText.action(color: isCorrect ? GzColors.greenDark : GzColors.muted2))),
          const SizedBox(width: 6),
          Expanded(child: Text('${text ?? ''}', style: GzText.muted(11))),
          if (isCorrect) Text('верный', style: GzText.caption().copyWith(color: GzColors.greenDark)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = '${quiz?['title'] ?? 'Квиз'}';
    return Scaffold(
      backgroundColor: GzColors.bg,
      appBar: GameZoneCmr.appBar(
        title: Text(title),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded), tooltip: 'Обновить'),
        ],
      ),
      body: GameZoneCmr.page(
        context,
        child: loading
            ? const Center(child: CircularProgressIndicator(color: GzColors.green))
            : RefreshIndicator(
                onRefresh: _load,
                color: GzColors.green,
                child: ListView(
                  padding: GameZoneCmr.listPadding(context),
                  children: [
                    _header(),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        const _QuizDot(color: GzColors.green, size: 6),
                        const SizedBox(width: 8),
                        Text('Вопросы квиза', style: GzText.section()),
                      ],
                    ),
                    const SizedBox(height: 9),
                    if (questions.isEmpty)
                      _EmptyQuestions(onTap: _openAddQuestionSheet)
                    else
                      ...questions.asMap().entries.map((entry) => Column(
                            children: [
                              _questionRow(Map<String, dynamic>.from(entry.value as Map), entry.key),
                              if (entry.key != questions.length - 1) const SizedBox(height: 5),
                            ],
                          )),
                    const SizedBox(height: 28),
                  ],
                ),
              ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String value;
  final String label;
  const _Metric({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: GzText.value(13.5)),
          const SizedBox(height: 2),
          Text(label, style: GzText.caption()),
        ],
      ),
    );
  }
}

class _QuizDot extends StatelessWidget {
  final Color color;
  final double size;
  final double opacity;
  const _QuizDot({required this.color, this.size = 6, this.opacity = 1});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: opacity > .8 ? [BoxShadow(color: color.withOpacity(.16), blurRadius: 9)] : null,
        ),
      ),
    );
  }
}

class _QuizDotCluster extends StatelessWidget {
  const _QuizDotCluster();
  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _QuizDot(color: GzColors.green, size: 3.5, opacity: .25),
        SizedBox(width: 3),
        _QuizDot(color: GzColors.green, size: 4.5, opacity: .48),
        SizedBox(width: 3),
        _QuizDot(color: GzColors.green, size: 5.5, opacity: .72),
        SizedBox(width: 3),
        _QuizDot(color: GzColors.green, size: 6.5),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String title;
  final VoidCallback onTap;
  final bool primary;
  final bool danger;
  final bool enabled;

  const _ActionButton({
    required this.title,
    required this.onTap,
    this.primary = false,
    this.danger = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final background = danger
        ? GzColors.red
        : primary
            ? GzColors.graphite
            : GzColors.soft;
    final foreground = danger || primary ? Colors.white : GzColors.text;
    return Material(
      color: enabled ? background : GzColors.soft2,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(9),
        child: SizedBox(
          height: 40,
          child: Center(
            child: Text(
              title,
              style: GzText.action(color: enabled ? foreground : GzColors.muted2),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyQuestions extends StatelessWidget {
  final VoidCallback onTap;
  const _EmptyQuestions({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(color: GzColors.soft, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          const _QuizDotCluster(),
          const SizedBox(height: 11),
          Text('Пока нет вопросов', style: GzText.title(15)),
          const SizedBox(height: 4),
          Text('Добавьте первый вопрос в этот квиз.', style: GzText.muted(11)),
          const SizedBox(height: 12),
          Material(
            color: GzColors.graphite,
            borderRadius: BorderRadius.circular(9),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(9),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                child: Text('Добавить вопрос', style: GzText.action(color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
