import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'game_zone_api.dart';
import 'game_zone_cmr_style.dart';

class CreateQuizScreen extends StatefulWidget {
  final bool embedded;
  final int? teamId;
  final int? userId;
  final String? teamName;
  final VoidCallback? onClose;
  final Future<void> Function()? onChanged;

  const CreateQuizScreen({
    super.key,
    this.embedded = false,
    this.teamId,
    this.userId,
    this.teamName,
    this.onClose,
    this.onChanged,
  });

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

    teamId = widget.teamId ?? _asInt(args['team_id'] ?? args['teamId']);
    userId = widget.userId ?? _asInt(args['user_id'] ?? args['userId']);
    teamName = (widget.teamName ?? args['team_name'] ?? args['teamName'] ?? '')
        .toString()
        .trim();
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

  Future<void> _notifyChanged() async {
    final callback = widget.onChanged;
    if (callback != null) await callback();
  }

  Future<void> _createQuiz() async {
    if (!(_quizFormKey.currentState?.validate() ?? false)) return;

    setState(() => _creatingQuiz = true);
    try {
      final res = await GameZoneApi.post('create_player_quiz.php', {
        'team_id': teamId,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'points_reward': _pointsController.text.trim(),
        'created_by': userId,
      });

      if (!mounted) return;

      if (res['success'] == true) {
        final createdId = _asInt(res['quiz_id']);
        setState(() => _quizId = createdId > 0 ? createdId : _quizId);
        await _notifyChanged();
        if (!mounted) return;
        Get.snackbar(
          'Квиз создан',
          (res['message'] ?? 'Теперь добавьте вопросы').toString(),
          snackPosition: SnackPosition.BOTTOM,
        );
      } else {
        Get.snackbar(
          'Не удалось создать квиз',
          (res['message'] ?? 'Проверьте данные и повторите').toString(),
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } finally {
      if (mounted) setState(() => _creatingQuiz = false);
    }
  }

  Future<void> _addQuestion() async {
    if (_quizId == null || _quizId! <= 0) {
      Get.snackbar(
        'Сначала создайте квиз',
        'После сохранения основной информации станет доступно добавление вопросов.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    if (!(_questionFormKey.currentState?.validate() ?? false)) return;

    setState(() => _addingQuestion = true);
    try {
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

      if (res['success'] == true) {
        final savedQuestion = <String, dynamic>{
          'question': _questionController.text.trim(),
          'option_a': _optionAController.text.trim(),
          'option_b': _optionBController.text.trim(),
          'option_c': _optionCController.text.trim(),
          'option_d': _optionDController.text.trim(),
          'correct_option': _correctOption,
        };
        setState(() {
          _localQuestions.add(savedQuestion);
          _questionController.clear();
          _optionAController.clear();
          _optionBController.clear();
          _optionCController.clear();
          _optionDController.clear();
          _correctOption = 'A';
        });
        await _notifyChanged();
        if (!mounted) return;
        Get.snackbar(
          'Вопрос добавлен',
          (res['message'] ?? 'Можно добавить следующий вопрос').toString(),
          snackPosition: SnackPosition.BOTTOM,
        );
      } else {
        Get.snackbar(
          'Не удалось добавить вопрос',
          (res['message'] ?? 'Проверьте варианты ответа').toString(),
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } finally {
      if (mounted) setState(() => _addingQuestion = false);
    }
  }

  InputDecoration _fieldDecoration({
    required String label,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: GzColors.soft,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: GzColors.red.withOpacity(.22), width: .8),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: GzColors.red.withOpacity(.32), width: .8),
      ),
    );
  }

  Widget _dot({double size = 6, double opacity = 1}) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: GzColors.green,
          shape: BoxShape.circle,
          boxShadow: opacity > .8
              ? [
                  BoxShadow(
                    color: GzColors.green.withOpacity(.16),
                    blurRadius: 10,
                    spreadRadius: .2,
                  ),
                ]
              : null,
        ),
      ),
    );
  }

  Widget _dotCluster() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _dot(size: 3.5, opacity: .25),
        const SizedBox(width: 3),
        _dot(size: 4.5, opacity: .45),
        const SizedBox(width: 3),
        _dot(size: 5.5, opacity: .7),
        const SizedBox(width: 3),
        _dot(size: 6.5),
      ],
    );
  }

  Widget _embeddedHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 15, 12, 13),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: GzColors.line, width: .55)),
      ),
      child: Row(
        children: [
          _dotCluster(),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Новый квиз', style: GzText.title(16.5)),
                const SizedBox(height: 3),
                Text(
                  teamName.isEmpty ? 'Командная игровая зона' : teamName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GzText.muted(10.8),
                ),
              ],
            ),
          ),
          if (widget.onClose != null)
            Material(
              color: GzColors.soft,
              borderRadius: BorderRadius.circular(9),
              child: InkWell(
                onTap: widget.onClose,
                borderRadius: BorderRadius.circular(9),
                child: const SizedBox(
                  width: 34,
                  height: 34,
                  child: Icon(Icons.close_rounded, size: 17, color: GzColors.muted2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, String subtitle, {bool active = true}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 5),
          child: _dot(size: active ? 6.2 : 4.8, opacity: active ? 1 : .4),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GzText.section()),
              const SizedBox(height: 2),
              Text(subtitle, style: GzText.muted(10.4)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _quizSection() {
    final locked = _quizId != null;
    return Form(
      key: _quizFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle(
            'Основная информация',
            locked
                ? 'Квиз сохранён · теперь добавляйте вопросы'
                : 'Название, описание и награда для игроков',
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _titleController,
            enabled: !locked,
            style: GzText.value(12.2),
            decoration: _fieldDecoration(
              label: 'Название квиза',
              hint: 'Например: Правила футбола',
            ),
            validator: (v) => v == null || v.trim().isEmpty
                ? 'Введите название квиза'
                : null,
          ),
          const SizedBox(height: 9),
          TextFormField(
            controller: _descriptionController,
            enabled: !locked,
            maxLines: 3,
            style: GzText.value(12.2),
            decoration: _fieldDecoration(
              label: 'Описание',
              hint: 'Коротко опишите тему и цель',
            ),
            validator: (v) => v == null || v.trim().isEmpty
                ? 'Введите описание'
                : null,
          ),
          const SizedBox(height: 9),
          TextFormField(
            controller: _pointsController,
            enabled: !locked,
            keyboardType: TextInputType.number,
            style: GzText.value(12.2),
            decoration: _fieldDecoration(label: 'Награда в очках'),
            validator: (v) {
              final n = int.tryParse('${v ?? ''}'.trim());
              if (n == null || n <= 0) return 'Введите корректное число';
              return null;
            },
          ),
          const SizedBox(height: 11),
          Align(
            alignment: Alignment.centerLeft,
            child: _ActionButton(
              title: locked
                  ? 'Квиз создан'
                  : (_creatingQuiz ? 'Создаём…' : 'Создать квиз'),
              primary: true,
              enabled: !locked && !_creatingQuiz,
              onTap: _createQuiz,
            ),
          ),
        ],
      ),
    );
  }

  Widget _correctOptionPicker() {
    const options = ['A', 'B', 'C', 'D'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Правильный ответ', style: GzText.caption()),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 0; i < options.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  child: InkWell(
                    onTap: () => setState(() => _correctOption = options[i]),
                    borderRadius: BorderRadius.circular(9),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _correctOption == options[i]
                            ? GzColors.greenSoft
                            : GzColors.soft,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(
                        options[i],
                        style: GzText.action(
                          color: _correctOption == options[i]
                              ? GzColors.greenDark
                              : GzColors.muted2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _questionSection() {
    final enabled = _quizId != null && _quizId! > 0;
    return Opacity(
      opacity: enabled ? 1 : .52,
      child: IgnorePointer(
        ignoring: !enabled,
        child: Form(
          key: _questionFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _sectionTitle(
                'Вопросы квиза',
                enabled
                    ? 'Добавляйте вопросы по одному и отмечайте правильный вариант'
                    : 'Сначала сохраните основную информацию',
                active: enabled,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _questionController,
                maxLines: 2,
                style: GzText.value(12.2),
                decoration: _fieldDecoration(
                  label: 'Вопрос',
                  hint: 'Например: Сколько игроков одной команды на поле?',
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Введите вопрос'
                    : null,
              ),
              const SizedBox(height: 9),
              _AnswerField(label: 'A', controller: _optionAController, decoration: _fieldDecoration(label: 'Вариант A')),
              const SizedBox(height: 7),
              _AnswerField(label: 'B', controller: _optionBController, decoration: _fieldDecoration(label: 'Вариант B')),
              const SizedBox(height: 7),
              _AnswerField(label: 'C', controller: _optionCController, decoration: _fieldDecoration(label: 'Вариант C')),
              const SizedBox(height: 7),
              _AnswerField(label: 'D', controller: _optionDController, decoration: _fieldDecoration(label: 'Вариант D')),
              const SizedBox(height: 11),
              _correctOptionPicker(),
              const SizedBox(height: 11),
              Align(
                alignment: Alignment.centerLeft,
                child: _ActionButton(
                  title: _addingQuestion ? 'Добавляем…' : 'Добавить вопрос',
                  primary: true,
                  enabled: enabled && !_addingQuestion,
                  onTap: _addQuestion,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _questionsList() {
    if (_localQuestions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: GzColors.soft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          _quizId == null
              ? 'Добавленные вопросы появятся здесь после создания квиза.'
              : 'Пока нет добавленных вопросов.',
          style: GzText.muted(11.2),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(
          'Добавленные вопросы',
          '${_localQuestions.length} ${_questionWord(_localQuestions.length)} в текущем квизе',
        ),
        const SizedBox(height: 9),
        for (var i = 0; i < _localQuestions.length; i++) ...[
          _QuestionPreview(question: _localQuestions[i], index: i),
          if (i != _localQuestions.length - 1) const SizedBox(height: 5),
        ],
      ],
    );
  }

  String _questionWord(int count) {
    final mod100 = count % 100;
    final mod10 = count % 10;
    if (mod100 >= 11 && mod100 <= 14) return 'вопросов';
    if (mod10 == 1) return 'вопрос';
    if (mod10 >= 2 && mod10 <= 4) return 'вопроса';
    return 'вопросов';
  }

  Widget _content() {
    final validTeam = teamId > 0;
    if (!validTeam) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Не удалось определить команду для создания квиза',
            textAlign: TextAlign.center,
            style: GzText.muted(12),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.embedded) _embeddedHeader(),
        Expanded(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              widget.embedded ? 18 : 14,
              widget.embedded ? 16 : 14,
              widget.embedded ? 18 : 14,
              28,
            ),
            children: [
              if (!widget.embedded) ...[
                GameZoneCmr.header(
                  title: 'Новый квиз для команды',
                  subtitle: teamName.isEmpty ? 'Командный квиз' : teamName,
                  icon: Icons.quiz_rounded,
                ),
                const SizedBox(height: 14),
              ],
              _quizSection(),
              const SizedBox(height: 22),
              _questionSection(),
              const SizedBox(height: 22),
              _questionsList(),
              if (widget.embedded && _quizId != null) ...[
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _ActionButton(
                    title: 'Готово',
                    enabled: widget.onClose != null,
                    onTap: widget.onClose ?? () {},
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return GameZoneCmr.surface(
        context,
        child: ColoredBox(
          color: Colors.white,
          child: _content(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: GzColors.bg,
      appBar: GameZoneCmr.appBar(title: const Text('Создать квиз')),
      body: GameZoneCmr.page(context, child: _content()),
    );
  }
}

class _AnswerField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final InputDecoration decoration;

  const _AnswerField({
    required this.label,
    required this.controller,
    required this.decoration,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      style: GzText.value(12.1),
      decoration: decoration,
      validator: (v) => v == null || v.trim().isEmpty
          ? 'Введите вариант $label'
          : null,
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String title;
  final bool primary;
  final bool enabled;
  final VoidCallback onTap;

  const _ActionButton({
    required this.title,
    this.primary = false,
    this.enabled = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(9),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          constraints: const BoxConstraints(minHeight: 38),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            color: primary
                ? (enabled ? GzColors.graphite : GzColors.soft2)
                : GzColors.soft,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            title,
            style: GzText.action(
              color: primary && enabled ? Colors.white : GzColors.muted2,
            ),
          ),
        ),
      ),
    );
  }
}

class _QuestionPreview extends StatelessWidget {
  final Map<String, dynamic> question;
  final int index;

  const _QuestionPreview({required this.question, required this.index});

  @override
  Widget build(BuildContext context) {
    final correct = '${question['correct_option'] ?? ''}'.trim();
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
      decoration: BoxDecoration(
        color: GzColors.soft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 5),
            decoration: const BoxDecoration(
              color: GzColors.green,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Вопрос ${index + 1}',
                  style: GzText.caption().copyWith(color: GzColors.greenDark),
                ),
                const SizedBox(height: 3),
                Text(
                  '${question['question'] ?? ''}',
                  style: GzText.value(11.8),
                ),
                const SizedBox(height: 5),
                Text(
                  'Правильный ответ: $correct',
                  style: GzText.muted(10.2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
