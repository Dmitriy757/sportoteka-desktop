// lib/presentation/club_workspace/cmr_game_zone_panel.dart
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import 'package:sportoteka/core/theme/app_typography.dart';
import 'package:sportoteka/presentation/player_game_zone/create_challenge_screen.dart';
import 'package:sportoteka/presentation/player_game_zone/create_quiz_screen.dart';
import 'package:sportoteka/presentation/player_game_zone/quiz_detail_screen.dart';
import 'package:sportoteka/presentation/player_game_zone/team_challenges_screen.dart';
import 'package:sportoteka/presentation/player_game_zone/team_quizzes_screen.dart';
import 'package:sportoteka/routes/app_routes.dart';

enum CmrGameZoneMode { all, challenges, quizzes, rating }

enum _ZoneItemKind { challenge, quiz, rating }
enum _GameZonePane { details, createQuiz }

class CmrGameZonePanel extends StatefulWidget {
  final int clubId;
  final String clubName;
  final int teamId;
  final int userId;
  final String teamName;
  final CmrGameZoneMode initialMode;

  const CmrGameZonePanel({
    super.key,
    required this.clubId,
    required this.clubName,
    required this.teamId,
    required this.userId,
    required this.teamName,
    this.initialMode = CmrGameZoneMode.all,
  });

  @override
  State<CmrGameZonePanel> createState() => _CmrGameZonePanelState();
}

class _CmrGameZonePanelState extends State<CmrGameZonePanel> {
  static const String apiBase = 'https://sportotekaapp.ru/api';

  final TextEditingController _searchC = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _error;
  int _selectedIndex = 0;
  late CmrGameZoneMode _mode;
  _GameZonePane _pane = _GameZonePane.details;
  List<Map<String, dynamic>> _challenges = [];
  List<Map<String, dynamic>> _quizzes = [];

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode == CmrGameZoneMode.rating
        ? CmrGameZoneMode.all
        : widget.initialMode;
    _searchC.addListener(_onSearchChanged);
    _load();
    if (widget.initialMode == CmrGameZoneMode.rating) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openFullList(_ZoneItemKind.rating);
      });
    }
  }

  void _onSearchChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant CmrGameZonePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.teamId != widget.teamId || oldWidget.clubId != widget.clubId) {
      _selectedIndex = 0;
      _pane = _GameZonePane.details;
      _load();
    }
  }

  @override
  void dispose() {
    _searchC.removeListener(_onSearchChanged);
    _searchC.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _args => {
        'team_id': widget.teamId,
        'teamId': widget.teamId,
        'user_id': widget.userId,
        'userId': widget.userId,
        'team_name': widget.teamName,
        'teamName': widget.teamName,
      };

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _post('get_team_challenges.php', {'team_id': widget.teamId}),
        _post('get_team_quizzes.php', {'team_id': widget.teamId}),
      ]);
      if (!mounted) return;
      setState(() {
        _challenges = _extractList(results[0])
            .map((e) => {...e, '_kind': _ZoneItemKind.challenge.name})
            .toList();
        _quizzes = _extractList(results[1])
            .map((e) => {...e, '_kind': _ZoneItemKind.quiz.name})
            .toList();
        _selectedIndex = 0;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Не удалось загрузить игровую зону: $e';
      });
    }
  }

  Future<Map<String, dynamic>> _post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final resp = await http
        .post(
          Uri.parse('$apiBase/$endpoint'),
          body: body.map((k, v) => MapEntry(k, '$v')),
        )
        .timeout(const Duration(seconds: 12));
    final data = _decode(resp.body);
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }

  dynamic _decode(String body) {
    final raw = body.trim();
    if (raw.isEmpty) return {};
    try {
      return jsonDecode(raw);
    } catch (_) {
      final start = raw.indexOf('{');
      final end = raw.lastIndexOf('}');
      if (start >= 0 && end > start) {
        try {
          return jsonDecode(raw.substring(start, end + 1));
        } catch (_) {}
      }
    }
    return {};
  }

  List<Map<String, dynamic>> _extractList(Map<String, dynamic> data) {
    for (final key
        in const ['items', 'data', 'challenges', 'quizzes', 'rows', 'list']) {
      final raw = data[key];
      if (raw is List) {
        return raw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }
    return [];
  }

  List<Map<String, dynamic>> get _items {
    final q = _searchC.text.trim().toLowerCase();
    final source = <Map<String, dynamic>>[
      if (_mode == CmrGameZoneMode.all ||
          _mode == CmrGameZoneMode.challenges)
        ..._challenges,
      if (_mode == CmrGameZoneMode.all || _mode == CmrGameZoneMode.quizzes)
        ..._quizzes,
    ];

    final filtered = source.where((item) {
      final hay =
          '${_title(item)} ${_subtitle(item)} ${_statusText(item)}'.toLowerCase();
      return q.isEmpty || hay.contains(q);
    }).toList();
    filtered.sort((a, b) => _dateText(b).compareTo(_dateText(a)));
    return filtered;
  }

  int get _activeChallenges =>
      _challenges.where((e) => _s(e['status']) == 'active').length;

  int get _activeQuizzes => _quizzes
      .where((e) => _i(e['is_active']) == 1 || _s(e['is_active']) == '1')
      .length;

  int get _totalPoints {
    var sum = 0;
    for (final e in [..._challenges, ..._quizzes]) {
      sum += _i(e['points_reward'] ?? e['points'] ?? e['reward']);
    }
    return sum;
  }

  Future<void> _openCreateChallenge() async {
    final result = await Get.to(
      () => const CreateChallengeScreen(),
      arguments: _args,
    );
    if (result == true) await _load();
  }

  void _openCreateQuiz() {
    if (!mounted) return;
    setState(() => _pane = _GameZonePane.createQuiz);
  }

  Future<void> _closeCreateQuiz() async {
    if (!mounted) return;
    setState(() => _pane = _GameZonePane.details);
    await _load();
  }

  Future<void> _refreshFromQuizEditor() async {
    final results = await Future.wait([
      _post('get_team_challenges.php', {'team_id': widget.teamId}),
      _post('get_team_quizzes.php', {'team_id': widget.teamId}),
    ]);
    if (!mounted) return;
    setState(() {
      _challenges = _extractList(results[0])
          .map((e) => {...e, '_kind': _ZoneItemKind.challenge.name})
          .toList();
      _quizzes = _extractList(results[1])
          .map((e) => {...e, '_kind': _ZoneItemKind.quiz.name})
          .toList();
    });
  }

  Future<void> _openFullList(_ZoneItemKind kind) async {
    if (kind == _ZoneItemKind.challenge) {
      await Get.to(() => const TeamChallengesScreen(), arguments: _args);
    } else if (kind == _ZoneItemKind.quiz) {
      await Get.to(() => const TeamQuizzesScreen(), arguments: _args);
    } else {
      await Get.toNamed(AppRoutes.teamRatingScreen, arguments: _args);
    }
    await _load();
  }

  Future<void> _openDetails(Map<String, dynamic> item) async {
    final kind = _kind(item);
    if (kind == _ZoneItemKind.quiz) {
      await Get.to(
        () => const QuizDetailScreen(),
        arguments: {
          ..._args,
          'quiz_id': _id(item),
          'id': _id(item),
        },
      );
      await _load();
      return;
    }
    await _openFullList(kind);
  }

  Future<void> _finishChallenge(Map<String, dynamic> item) async {
    final id = _id(item);
    if (id <= 0) return;
    setState(() => _saving = true);
    try {
      final res =
          await _post('finish_player_challenge.php', {'challenge_id': id});
      Get.snackbar(
        res['success'] == true ? 'Готово' : 'Ошибка',
        _s(res['message']).isEmpty ? 'Статус обновлён' : _s(res['message']),
        snackPosition: SnackPosition.BOTTOM,
      );
      if (res['success'] == true) await _load();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleQuiz(Map<String, dynamic> item) async {
    final id = _id(item);
    if (id <= 0) return;
    final active =
        _i(item['is_active']) == 1 || _s(item['is_active']) == '1';
    setState(() => _saving = true);
    try {
      final res = await _post('toggle_player_quiz_status.php', {
        'quiz_id': id,
        'is_active': active ? 0 : 1,
      });
      Get.snackbar(
        res['success'] == true ? 'Готово' : 'Ошибка',
        _s(res['message']).isEmpty
            ? 'Статус квиза обновлён'
            : _s(res['message']),
        snackPosition: SnackPosition.BOTTOM,
      );
      if (res['success'] == true) await _load();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: _CmrColors.green),
      );
    }
    if (_error != null) {
      return _CmrErrorState(text: _error!, onRetry: _load);
    }

    return Container(
      color: _CmrColors.workspace,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final mobile = constraints.maxWidth < 640;
          final compact = constraints.maxWidth < 980;
          final items = _items;

          if (_selectedIndex >= items.length && items.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _selectedIndex = 0);
            });
          }

          final selected = items.isEmpty
              ? null
              : items[_selectedIndex.clamp(0, items.length - 1)];

          final list = _buildListPanel(items, compact, mobile);
          final right = _pane == _GameZonePane.createQuiz
              ? CreateQuizScreen(
                  embedded: true,
                  teamId: widget.teamId,
                  userId: widget.userId,
                  teamName: widget.teamName,
                  onClose: () {
                    _closeCreateQuiz();
                  },
                  onChanged: _refreshFromQuizEditor,
                )
              : _buildDetailsPanel(selected, compact);

          if (mobile || compact) {
            final child = _pane == _GameZonePane.createQuiz ? right : list;
            return Container(
              width: double.infinity,
              color: _CmrColors.workspace,
              padding: EdgeInsets.all(mobile ? 6 : 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  color: Colors.white,
                  child: child,
                ),
              ),
            );
          }

          final listWidth = math.min(
            constraints.maxWidth >= 1440 ? 480.0 : 440.0,
            constraints.maxWidth * .44,
          );

          return Container(
            width: double.infinity,
            color: _CmrColors.workspace,
            padding: const EdgeInsets.all(10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: _CmrDecor.windowShadow,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: listWidth, child: list),
                    const SizedBox(
                      width: 1,
                      child: ColoredBox(color: _CmrColors.line),
                    ),
                    Expanded(child: right),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildListPanel(
    List<Map<String, dynamic>> items,
    bool compact,
    bool mobile,
  ) {
    return ColoredBox(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(
              mobile ? 10 : 12,
              10,
              mobile ? 10 : 12,
              10,
            ),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: _CmrColors.line, width: .55),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Игровая зона',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _CmrText.title(mobile ? 15.5 : 16.5),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.teamName.isEmpty ? 'Команда' : widget.teamName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _CmrText.muted(mobile ? 11 : 11.5),
                      ),
                    ],
                  ),
                ),
                _CmrHelpButton(
                  title: 'Игровая зона',
                  text:
                      'Создавайте задания и квизы, отслеживайте активность команды и открывайте подробности справа без выхода из рабочего пространства.',
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              mobile ? 10 : 12,
              9,
              mobile ? 10 : 12,
              0,
            ),
            child: Row(
              children: [
                Expanded(
                  child: _CmrToolbarButton(
                    title: 'Задание',
                    onTap: _saving ? null : _openCreateChallenge,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _CmrToolbarButton(
                    title: 'Квиз',
                    active: _pane == _GameZonePane.createQuiz,
                    onTap: _saving ? null : _openCreateQuiz,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              mobile ? 10 : 12,
              9,
              mobile ? 10 : 12,
              0,
            ),
            child: _CmrMetricsStrip(
              items: [
                ('${_challenges.length}', 'заданий'),
                ('${_quizzes.length}', 'квизов'),
                ('${_activeChallenges + _activeQuizzes}', 'активно'),
                ('$_totalPoints', 'очков'),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              mobile ? 10 : 12,
              9,
              mobile ? 10 : 12,
              0,
            ),
            child: _CmrSearch(controller: _searchC),
          ),
          SizedBox(
            height: 44,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                mobile ? 10 : 12,
                5,
                mobile ? 10 : 12,
                4,
              ),
              child: _buildFilters(),
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? _CmrEmptyState(
                    title: 'Игровая зона пустая',
                    text:
                        'Создайте первое задание или квиз — новые элементы появятся в этом списке.',
                    buttonText: 'Создать квиз',
                    onTap: _openCreateQuiz,
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    color: _CmrColors.green,
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        10,
                        4,
                        10,
                        mobile ? 120 : 12,
                      ),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 4),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final active = index == _selectedIndex &&
                            _pane == _GameZonePane.details;
                        return _CmrZoneTile(
                          active: active,
                          title: _title(item),
                          subtitle: _subtitle(item),
                          badge: _kind(item) == _ZoneItemKind.challenge
                              ? 'Задание'
                              : 'Квиз',
                          status: _statusText(item),
                          onTap: () {
                            setState(() {
                              _selectedIndex = index;
                              _pane = _GameZonePane.details;
                            });
                            if (compact) _openZoneDetailsSheet(item);
                          },
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _openZoneDetailsSheet(Map<String, dynamic> item) async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: .90,
          minChildSize: .52,
          maxChildSize: .96,
          builder: (context, scrollController) {
            return Container(
              margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: _CmrColors.line,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _buildDetailsPanel(
                      item,
                      true,
                      scrollController: scrollController,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailsPanel(
    Map<String, dynamic>? item,
    bool compact, {
    ScrollController? scrollController,
  }) {
    if (item == null) {
      return Container(
        color: Colors.white,
        padding: const EdgeInsets.all(18),
        child: _CmrEmptyState(
          title: 'Выберите элемент',
          text:
              'Справа появятся статус, очки, сроки и действия по выбранному заданию или квизу.',
          buttonText: 'Создать квиз',
          onTap: _openCreateQuiz,
        ),
      );
    }

    final kind = _kind(item);
    final isChallenge = kind == _ZoneItemKind.challenge;
    final points = _i(item['points_reward'] ?? item['points'] ?? item['reward']);
    final status = _statusText(item);
    final date = _dateText(item);

    return ColoredBox(
      color: Colors.white,
      child: ListView(
        controller: scrollController,
        padding: EdgeInsets.fromLTRB(18, compact ? 14 : 18, 18, 24),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: _CmrGlowDot(
                  color: _CmrColors.green,
                  size: 7,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _title(item),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _CmrText.title(compact ? 18 : 22),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      [
                        isChallenge ? 'Задание' : 'Квиз',
                        status,
                        if (points > 0) '$points очков',
                      ].join(' · '),
                      style: _CmrText.muted(11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _CmrItemMenu(
                isChallenge: isChallenge,
                onDetails: () => _openDetails(item),
                onAll: () => _openFullList(kind),
                onToggle: isChallenge
                    ? () => _finishChallenge(item)
                    : () => _toggleQuiz(item),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _CmrActionGroup(
            actions: [
              _CmrAction(
                title: 'Открыть подробно',
                subtitle: isChallenge
                    ? 'Полный экран задания'
                    : 'Вопросы, ответы и результаты квиза',
                accent: true,
                onTap: _saving ? null : () => _openDetails(item),
              ),
              _CmrAction(
                title: isChallenge ? 'Все задания' : 'Все квизы',
                subtitle: 'Открыть полный список команды',
                onTap: _saving ? null : () => _openFullList(kind),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _CmrMetricsStrip(
            items: [
              (status, 'статус'),
              (points > 0 ? '$points' : '—', 'очки'),
              (_typeText(item), 'тип'),
              (date.isEmpty ? '—' : date, isChallenge ? 'срок' : 'создано'),
            ],
            rightPane: true,
          ),
          const SizedBox(height: 18),
          _CmrSection(
            title: 'Описание',
            child: Text(
              _subtitle(item).isEmpty
                  ? 'Описание пока не заполнено.'
                  : _subtitle(item),
              style: _CmrText.muted(11.5),
            ),
          ),
          const SizedBox(height: 16),
          _CmrNotice(
            title: 'Рабочая подсказка',
            text: isChallenge
                ? 'Используйте задания для домашних активностей, дисциплины и контроля выполнения.'
                : 'Квизы подходят для проверки правил, тактики и понимания игровых ситуаций.',
          ),
          const SizedBox(height: 18),
          _CmrActionGroup(
            title: 'Быстрые действия',
            actions: [
              _CmrAction(
                title: 'Новый квиз',
                subtitle: 'Откроется справа без ухода из раздела',
                accent: true,
                onTap: _openCreateQuiz,
              ),
              _CmrAction(
                title: 'Новое задание',
                subtitle: 'Создать игровое задание',
                onTap: _openCreateChallenge,
              ),
              _CmrAction(
                title: 'Рейтинг команды',
                subtitle: 'Очки и активность игроков',
                onTap: () => _openFullList(_ZoneItemKind.rating),
              ),
              _CmrAction(
                title: isChallenge ? 'Завершить задание' : 'Изменить статус',
                subtitle: isChallenge
                    ? 'Перевести задание в завершённые'
                    : 'Включить или отключить квиз',
                onTap: _saving
                    ? null
                    : (isChallenge
                        ? () => _finishChallenge(item)
                        : () => _toggleQuiz(item)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    final items = [
      (CmrGameZoneMode.all, 'Все'),
      (CmrGameZoneMode.challenges, 'Задания'),
      (CmrGameZoneMode.quizzes, 'Квизы'),
      (CmrGameZoneMode.rating, 'Рейтинг'),
    ];

    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(width: 6),
      itemBuilder: (_, index) {
        final item = items[index];
        final active = _mode == item.$1;
        return Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          child: InkWell(
            borderRadius: BorderRadius.circular(9),
            onTap: () {
              if (item.$1 == CmrGameZoneMode.rating) {
                _openFullList(_ZoneItemKind.rating);
                return;
              }
              setState(() {
                _mode = item.$1;
                _selectedIndex = 0;
                _pane = _GameZonePane.details;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: active ? _CmrColors.greenSoft : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                item.$2,
                style: _CmrText.action().copyWith(
                  color: active ? _CmrColors.greenDark : _CmrColors.muted2,
                  fontSize: 11.1,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  _ZoneItemKind _kind(Map<String, dynamic> item) =>
      _s(item['_kind']) == _ZoneItemKind.quiz.name
          ? _ZoneItemKind.quiz
          : _ZoneItemKind.challenge;

  int _id(Map<String, dynamic> item) =>
      _i(item['id'] ?? item['challenge_id'] ?? item['quiz_id']);

  bool _isActive(Map<String, dynamic> item) =>
      _kind(item) == _ZoneItemKind.challenge
          ? _s(item['status']) == 'active'
          : (_i(item['is_active']) == 1 || _s(item['is_active']) == '1');

  String _title(Map<String, dynamic> item) =>
      _first([item['title'], item['name'], item['question'], 'Без названия']);

  String _subtitle(Map<String, dynamic> item) =>
      _first([item['description'], item['body'], item['text'], '']);

  String _dateText(Map<String, dynamic> item) =>
      _first([item['due_date'], item['created_at'], item['date'], '']);

  String _typeText(Map<String, dynamic> item) {
    if (_kind(item) == _ZoneItemKind.quiz) return 'Викторина';
    final raw = _s(item['challenge_type']).toLowerCase();
    if (raw == 'daily') return 'Ежедневное';
    if (raw == 'weekly') return 'Еженедельное';
    return raw.isEmpty ? 'Задание' : raw;
  }

  String _statusText(Map<String, dynamic> item) {
    if (_kind(item) == _ZoneItemKind.quiz) {
      return _isActive(item) ? 'Активен' : 'Отключён';
    }
    final raw = _s(item['status']).toLowerCase();
    if (raw == 'active') return 'Активно';
    if (raw == 'finished') return 'Завершено';
    return raw.isEmpty ? 'Без статуса' : raw;
  }

  String _first(List<dynamic> values) {
    for (final value in values) {
      final text = _s(value);
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  String _s(dynamic value) => value == null ? '' : '$value'.trim();

  int _i(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(_s(value)) ?? 0;
  }
}

class _CmrColors {
  static const Color workspace = Color(0xFFF6F7F6);
  static const Color bg = Colors.white;
  static const Color panel = Colors.white;
  static const Color soft = Color(0xFFF7F8F7);
  static const Color soft2 = Color(0xFFF2F4F2);
  static const Color text = Color(0xFF0B0F14);
  static const Color muted = Color(0xFF374151);
  static const Color muted2 = Color(0xFF5F6670);
  static const Color subtle = Color(0xFF8A9099);
  static const Color line = Color(0xFFE9ECEA);
  static const Color graphite = Color(0xFF111827);
  static const Color graphiteSoft = Color(0xFF4B5563);
  static const Color green = Color(0xFF00A750);
  static const Color greenDark = Color(0xFF067A46);
  static const Color greenSoft = Color(0xFFF3FAF6);
  static const Color greenBorder = Color(0xFFD7F0E2);
  static const Color red = Color(0xFFD92D20);
}

class _CmrText {
  static TextStyle title(double size) => AppTypography.custom(
        size: size,
        weight: FontWeight.w600,
        color: _CmrColors.text,
        height: 1.18,
        letterSpacing: 0,
        features: const <FontFeature>[FontFeature.tabularFigures()],
      );

  static TextStyle value(double size) => AppTypography.custom(
        size: size,
        weight: FontWeight.w600,
        color: _CmrColors.text,
        height: 1.18,
        letterSpacing: 0,
        features: const <FontFeature>[FontFeature.tabularFigures()],
      );

  static TextStyle section() => AppTypography.custom(
        size: 12.2,
        weight: FontWeight.w600,
        color: _CmrColors.text,
        height: 1.20,
        letterSpacing: 0,
      );

  static TextStyle muted(double size) => AppTypography.custom(
        size: size,
        weight: FontWeight.w400,
        color: _CmrColors.muted2,
        height: 1.32,
        letterSpacing: 0,
      );

  static TextStyle caption() => AppTypography.custom(
        size: 10.8,
        weight: FontWeight.w500,
        color: _CmrColors.subtle,
        height: 1.18,
        letterSpacing: 0,
      );

  static TextStyle action() => AppTypography.custom(
        size: 11.8,
        weight: FontWeight.w600,
        color: _CmrColors.text,
        letterSpacing: 0,
      );

  static TextStyle navLabel({required bool active}) => AppTypography.custom(
        size: 11.0,
        weight: active ? FontWeight.w600 : FontWeight.w500,
        color: active ? _CmrColors.greenDark : _CmrColors.text,
        height: 1.30,
        letterSpacing: 0,
      );

  static TextStyle navSubtitle({required bool active}) => AppTypography.custom(
        size: 10.2,
        weight: FontWeight.w400,
        color: active
            ? _CmrColors.greenDark.withOpacity(.68)
            : _CmrColors.muted2,
        height: 1.30,
        letterSpacing: 0,
      );
}

class _CmrDecor {
  static List<BoxShadow> get windowShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(.035),
          blurRadius: 28,
          spreadRadius: -18,
          offset: const Offset(0, 16),
        ),
      ];
}

class _CmrGlowDot extends StatelessWidget {
  final Color color;
  final double size;
  final double opacity;
  final bool halo;

  const _CmrGlowDot({
    required this.color,
    this.size = 6,
    this.opacity = 1,
    this.halo = true,
  });

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
          boxShadow: halo
              ? [
                  BoxShadow(
                    color: color.withOpacity(.18),
                    blurRadius: size * 1.9,
                    spreadRadius: .2,
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}

class _CmrDotCluster extends StatelessWidget {
  const _CmrDotCluster();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CmrGlowDot(color: _CmrColors.green, size: 3.5, opacity: .25, halo: false),
        SizedBox(width: 3),
        _CmrGlowDot(color: _CmrColors.green, size: 4.5, opacity: .48, halo: false),
        SizedBox(width: 3),
        _CmrGlowDot(color: _CmrColors.green, size: 5.5, opacity: .72, halo: false),
        SizedBox(width: 3),
        _CmrGlowDot(color: _CmrColors.green, size: 6.5),
      ],
    );
  }
}

class _CmrToolbarButton extends StatelessWidget {
  final String title;
  final VoidCallback? onTap;
  final bool active;

  const _CmrToolbarButton({
    required this.title,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: active ? _CmrColors.greenSoft : _CmrColors.soft,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _CmrGlowDot(
                color: active ? _CmrColors.green : _CmrColors.muted2,
                size: active ? 6 : 4.5,
                opacity: active ? 1 : .48,
                halo: active,
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _CmrText.action().copyWith(
                    color: active
                        ? _CmrColors.greenDark
                        : _CmrColors.graphiteSoft,
                    fontSize: 10.8,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CmrMetricsStrip extends StatelessWidget {
  final List<(String, String)> items;
  final bool rightPane;

  const _CmrMetricsStrip({required this.items, this.rightPane = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: _CmrColors.soft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 470;
          return Wrap(
            runSpacing: 10,
            children: [
              for (var i = 0; i < items.length; i++)
                SizedBox(
                  width: compact
                      ? constraints.maxWidth / 2
                      : constraints.maxWidth / items.length,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: i == 0 ? 2 : 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          items[i].$1,
                          maxLines: rightPane ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                          style: _CmrText.value(rightPane ? 12.5 : 13.5),
                        ),
                        const SizedBox(height: 3),
                        Text(items[i].$2, style: _CmrText.caption()),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _CmrSearch extends StatelessWidget {
  final TextEditingController controller;
  const _CmrSearch({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: _CmrColors.soft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 16, color: _CmrColors.muted2),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              style: _CmrText.value(12.5),
              decoration: const InputDecoration(
                hintText: 'Поиск по названию или статусу...',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          if (controller.text.trim().isNotEmpty)
            InkWell(
              borderRadius: BorderRadius.circular(99),
              onTap: controller.clear,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close_rounded, size: 16, color: _CmrColors.muted2),
              ),
            ),
        ],
      ),
    );
  }
}

class _CmrZoneTile extends StatelessWidget {
  final bool active;
  final String title;
  final String subtitle;
  final String badge;
  final String status;
  final VoidCallback onTap;

  const _CmrZoneTile({
    required this.active,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          constraints: const BoxConstraints(minHeight: 58),
          padding: const EdgeInsets.fromLTRB(10, 7, 9, 7),
          decoration: BoxDecoration(
            color: active ? _CmrColors.greenSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Row(
            children: [
              _CmrGlowDot(
                color: active ? _CmrColors.green : _CmrColors.muted2,
                size: active ? 6.4 : 4.8,
                opacity: active ? 1 : .48,
                halo: active,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _CmrText.navLabel(active: active),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle.isEmpty
                          ? '$badge · $status'
                          : '$badge · $status · $subtitle',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _CmrText.navSubtitle(active: active),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 5),
              Icon(
                Icons.chevron_right_rounded,
                size: 17,
                color: active ? _CmrColors.green : _CmrColors.subtle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CmrSection extends StatelessWidget {
  final String title;
  final Widget child;
  const _CmrSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 0, 2, 9),
          child: Text(title, style: _CmrText.section()),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _CmrColors.soft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: child,
        ),
      ],
    );
  }
}

class _CmrNotice extends StatelessWidget {
  final String title;
  final String text;
  const _CmrNotice({required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color: _CmrColors.greenSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 5),
            child: _CmrGlowDot(color: _CmrColors.green, size: 6),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _CmrText.section()),
                const SizedBox(height: 3),
                Text(text, style: _CmrText.muted(10.8)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CmrAction {
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool accent;

  const _CmrAction({
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.accent = false,
  });
}

class _CmrActionGroup extends StatelessWidget {
  final String? title;
  final List<_CmrAction> actions;

  const _CmrActionGroup({this.title, required this.actions});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 0, 2, 9),
            child: Text(title!, style: _CmrText.section()),
          ),
        ],
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: _CmrColors.soft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                _CmrActionRow(action: actions[i]),
                if (i != actions.length - 1)
                  const Padding(
                    padding: EdgeInsets.only(left: 42),
                    child: Divider(
                      height: 1,
                      thickness: .55,
                      color: _CmrColors.line,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _CmrActionRow extends StatelessWidget {
  final _CmrAction action;
  const _CmrActionRow({required this.action});

  @override
  Widget build(BuildContext context) {
    final enabled = action.onTap != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: action.onTap,
        child: Opacity(
          opacity: enabled ? 1 : .45,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                _CmrGlowDot(
                  color: action.accent ? _CmrColors.green : _CmrColors.muted2,
                  size: action.accent ? 6 : 4.8,
                  opacity: action.accent ? 1 : .5,
                  halo: action.accent,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(action.title, style: _CmrText.action()),
                      const SizedBox(height: 2),
                      Text(action.subtitle, style: _CmrText.muted(10.6)),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 17,
                  color: _CmrColors.subtle,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CmrItemMenu extends StatelessWidget {
  final bool isChallenge;
  final VoidCallback onDetails;
  final VoidCallback onAll;
  final VoidCallback onToggle;

  const _CmrItemMenu({
    required this.isChallenge,
    required this.onDetails,
    required this.onAll,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Действия',
      elevation: 0,
      color: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      position: PopupMenuPosition.under,
      offset: const Offset(0, 7),
      onSelected: (value) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (value == 'details') onDetails();
          if (value == 'all') onAll();
          if (value == 'toggle') onToggle();
        });
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'details',
          child: Text('Открыть подробно', style: _CmrText.action()),
        ),
        PopupMenuItem(
          value: 'all',
          child: Text(
            isChallenge ? 'Все задания' : 'Все квизы',
            style: _CmrText.action(),
          ),
        ),
        PopupMenuItem(
          value: 'toggle',
          child: Text(
            isChallenge ? 'Завершить' : 'Включить / отключить',
            style: _CmrText.action(),
          ),
        ),
      ],
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _CmrColors.soft,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          '•••',
          style: _CmrText.action().copyWith(
            color: _CmrColors.muted2,
            fontSize: 11.5,
            letterSpacing: 1.1,
          ),
        ),
      ),
    );
  }
}

class _CmrEmptyState extends StatelessWidget {
  final String title;
  final String text;
  final String buttonText;
  final VoidCallback onTap;

  const _CmrEmptyState({
    required this.title,
    required this.text,
    required this.buttonText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _CmrDotCluster(),
            const SizedBox(height: 14),
            Text(title, textAlign: TextAlign.center, style: _CmrText.title(17)),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: _CmrText.muted(11.5),
              ),
            ),
            const SizedBox(height: 14),
            Material(
              color: _CmrColors.graphite,
              borderRadius: BorderRadius.circular(9),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(9),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 10,
                  ),
                  child: Text(
                    buttonText,
                    style: _CmrText.action().copyWith(color: Colors.white),
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

class _CmrErrorState extends StatelessWidget {
  final String text;
  final VoidCallback onRetry;
  const _CmrErrorState({required this.text, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _CmrColors.workspace,
      padding: const EdgeInsets.all(10),
      child: Container(
        color: Colors.white,
        child: _CmrEmptyState(
          title: 'Ошибка загрузки',
          text: text,
          buttonText: 'Повторить',
          onTap: onRetry,
        ),
      ),
    );
  }
}

class _CmrHelpButton extends StatelessWidget {
  final String title;
  final String text;
  const _CmrHelpButton({required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Справка',
      elevation: 0,
      color: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          enabled: false,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _CmrText.section()),
                const SizedBox(height: 5),
                Text(text, style: _CmrText.muted(10.8)),
              ],
            ),
          ),
        ),
      ],
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _CmrColors.soft,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          '•••',
          style: _CmrText.action().copyWith(
            color: _CmrColors.muted2,
            fontSize: 11.5,
            letterSpacing: 1.1,
          ),
        ),
      ),
    );
  }
}
