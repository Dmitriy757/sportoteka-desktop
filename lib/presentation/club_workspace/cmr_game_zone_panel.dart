// lib/presentation/club_workspace/cmr_game_zone_panel.dart
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import 'package:sportoteka/presentation/player_game_zone/create_challenge_screen.dart';
import 'package:sportoteka/presentation/player_game_zone/create_quiz_screen.dart';
import 'package:sportoteka/presentation/player_game_zone/quiz_detail_screen.dart';
import 'package:sportoteka/presentation/player_game_zone/team_challenges_screen.dart';
import 'package:sportoteka/presentation/player_game_zone/team_quizzes_screen.dart';
import 'package:sportoteka/routes/app_routes.dart';

enum CmrGameZoneMode { all, challenges, quizzes, rating }

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

enum _ZoneItemKind { challenge, quiz, rating }

class _CmrGameZonePanelState extends State<CmrGameZonePanel> {
  static const String apiBase = 'https://sportotekaapp.ru/api';

  final TextEditingController _searchC = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _error;
  int _selectedIndex = 0;
  late CmrGameZoneMode _mode;
  List<Map<String, dynamic>> _challenges = [];
  List<Map<String, dynamic>> _quizzes = [];

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode == CmrGameZoneMode.rating
        ? CmrGameZoneMode.all
        : widget.initialMode;
    _searchC.addListener(() => setState(() {}));
    _load();
    if (widget.initialMode == CmrGameZoneMode.rating) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openFullList(_ZoneItemKind.rating);
      });
    }
  }

  @override
  void didUpdateWidget(covariant CmrGameZonePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.teamId != widget.teamId || oldWidget.clubId != widget.clubId) {
      _selectedIndex = 0;
      _load();
    }
  }

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  Map<String, dynamic> get _args => {
        'team_id': widget.teamId,
        'teamId': widget.teamId,
        'user_id': widget.userId,
        'team_name': widget.teamName,
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
        _challenges = _extractList(results[0]).map((e) => {...e, '_kind': _ZoneItemKind.challenge.name}).toList();
        _quizzes = _extractList(results[1]).map((e) => {...e, '_kind': _ZoneItemKind.quiz.name}).toList();
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

  Future<Map<String, dynamic>> _post(String endpoint, Map<String, dynamic> body) async {
    final resp = await http
        .post(Uri.parse('$apiBase/$endpoint'), body: body.map((k, v) => MapEntry(k, '$v')))
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
    for (final key in const ['items', 'data', 'challenges', 'quizzes', 'rows', 'list']) {
      final raw = data[key];
      if (raw is List) {
        return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
    }
    return [];
  }

  List<Map<String, dynamic>> get _items {
    final q = _searchC.text.trim().toLowerCase();
    final source = <Map<String, dynamic>>[
      if (_mode == CmrGameZoneMode.all || _mode == CmrGameZoneMode.challenges) ..._challenges,
      if (_mode == CmrGameZoneMode.all || _mode == CmrGameZoneMode.quizzes) ..._quizzes,
    ];
    final filtered = source.where((item) {
      final hay = '${_title(item)} ${_subtitle(item)} ${_statusText(item)}'.toLowerCase();
      return q.isEmpty || hay.contains(q);
    }).toList();
    filtered.sort((a, b) => _dateText(b).compareTo(_dateText(a)));
    return filtered;
  }

  int get _activeChallenges => _challenges.where((e) => _s(e['status']) == 'active').length;
  int get _finishedChallenges => _challenges.where((e) => _s(e['status']) == 'finished').length;
  int get _activeQuizzes => _quizzes.where((e) => _i(e['is_active']) == 1 || _s(e['is_active']) == '1').length;
  int get _totalPoints {
    int sum = 0;
    for (final e in [..._challenges, ..._quizzes]) {
      sum += _i(e['points_reward'] ?? e['points'] ?? e['reward']);
    }
    return sum;
  }

  Future<void> _openCreateChallenge() async {
    final result = await Get.to(() => const CreateChallengeScreen(), arguments: _args);
    if (result == true) _load();
  }

  Future<void> _openCreateQuiz() async {
    final result = await Get.to(() => const CreateQuizScreen(), arguments: _args);
    if (result == true) _load();
  }

  Future<void> _openFullList(_ZoneItemKind kind) async {
    if (kind == _ZoneItemKind.challenge) {
      await Get.to(() => const TeamChallengesScreen(), arguments: _args);
    } else if (kind == _ZoneItemKind.quiz) {
      await Get.to(() => const TeamQuizzesScreen(), arguments: _args);
    } else {
      await Get.toNamed(AppRoutes.teamRatingScreen, arguments: _args);
    }
    _load();
  }

  Future<void> _openDetails(Map<String, dynamic> item) async {
    final kind = _kind(item);
    if (kind == _ZoneItemKind.quiz) {
      await Get.to(() => const QuizDetailScreen(), arguments: {
        ..._args,
        'quiz_id': _id(item),
        'id': _id(item),
      });
      _load();
      return;
    }
    await _openFullList(kind);
  }

  Future<void> _finishChallenge(Map<String, dynamic> item) async {
    final id = _id(item);
    if (id <= 0) return;
    setState(() => _saving = true);
    try {
      final res = await _post('finish_player_challenge.php', {'challenge_id': id});
      Get.snackbar(res['success'] == true ? 'Готово' : 'Ошибка', _s(res['message']).isEmpty ? 'Статус обновлён' : _s(res['message']));
      if (res['success'] == true) await _load();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleQuiz(Map<String, dynamic> item) async {
    final id = _id(item);
    if (id <= 0) return;
    final active = _i(item['is_active']) == 1 || _s(item['is_active']) == '1';
    setState(() => _saving = true);
    try {
      final res = await _post('toggle_player_quiz_status.php', {'quiz_id': id, 'is_active': active ? 0 : 1});
      Get.snackbar(res['success'] == true ? 'Готово' : 'Ошибка', _s(res['message']).isEmpty ? 'Статус квиза обновлён' : _s(res['message']));
      if (res['success'] == true) await _load();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 860;
        final items = _items;
        if (_selectedIndex >= items.length && items.isNotEmpty) {
          Future.microtask(() {
            if (mounted) setState(() => _selectedIndex = 0);
          });
        }
        final selected = items.isEmpty ? null : items[_selectedIndex.clamp(0, items.length - 1)];
        if (_loading) return const Center(child: CircularProgressIndicator());
        if (_error != null) return _CmrErrorState(text: _error!, onRetry: _load);

        final list = _buildListPanel(items, compact);
        final details = _buildDetailsPanel(selected, compact);

        if (compact) {
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              SizedBox(height: 620, child: list),
              const SizedBox(height: 12),
              SizedBox(height: 620, child: details),
            ],
          );
        }
        return Row(
          children: [
            SizedBox(width: math.min(460, constraints.maxWidth * .42), child: list),
            const SizedBox(width: 12),
            Expanded(child: details),
          ],
        );
      },
    );
  }

  Widget _buildListPanel(List<Map<String, dynamic>> items, bool compact) {
    return Container(
      padding: EdgeInsets.all(compact ? 14 : 18),
      decoration: _CmrDecor.card(radius: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _CmrRoundIcon(icon: Icons.extension_rounded, color: _CmrColors.black, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Игровая зона', maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrText.title(18)),
                    const SizedBox(height: 4),
                    Text('${widget.teamName.isEmpty ? 'Команда' : widget.teamName} · задания и квизы', maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrText.body(12)),
                  ],
                ),
              ),
              _CmrHelpButton(
                title: 'Как работать с игровой зоной',
                text: 'Здесь тренер быстро создаёт задания и квизы, видит активность команды и открывает подробности без ухода из рабочего пространства.',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _CmrPrimaryButton(icon: Icons.flag_rounded, title: 'Задание', onTap: _saving ? null : _openCreateChallenge)),
              const SizedBox(width: 10),
              Expanded(child: _CmrSecondaryButton(icon: Icons.quiz_rounded, title: 'Квиз', onTap: _saving ? null : _openCreateQuiz)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _CmrStatCard(value: '${_challenges.length}', label: 'заданий', icon: Icons.flag_rounded)),
              const SizedBox(width: 8),
              Expanded(child: _CmrStatCard(value: '${_quizzes.length}', label: 'квизов', icon: Icons.quiz_rounded)),
              const SizedBox(width: 8),
              Expanded(child: _CmrStatCard(value: '${_activeChallenges + _activeQuizzes}', label: 'активно', icon: Icons.play_circle_rounded)),
              const SizedBox(width: 8),
              Expanded(child: _CmrStatCard(value: '$_totalPoints', label: 'очков', icon: Icons.stars_rounded)),
            ],
          ),
          const SizedBox(height: 12),
          _CmrInput(controller: _searchC, hint: 'Поиск по названию, описанию, статусу', icon: Icons.search_rounded),
          const SizedBox(height: 10),
          _buildFilters(),
          const SizedBox(height: 12),
          Expanded(
            child: items.isEmpty
                ? _CmrEmptyState(
                    title: 'Игровая зона пустая',
                    text: 'Создайте первое задание или квиз, чтобы вовлечь игроков в работу между тренировками.',
                    buttonText: 'Создать задание',
                    onTap: _openCreateChallenge,
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    color: _CmrColors.green,
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return _CmrZoneTile(
                          active: index == _selectedIndex,
                          title: _title(item),
                          subtitle: _subtitle(item),
                          badge: _kind(item) == _ZoneItemKind.challenge ? 'Задание' : 'Квиз',
                          status: _statusText(item),
                          icon: _kind(item) == _ZoneItemKind.challenge ? Icons.flag_rounded : Icons.quiz_rounded,
                          color: _kind(item) == _ZoneItemKind.challenge ? _CmrColors.green : _CmrColors.purple,
                          onTap: () => setState(() => _selectedIndex = index),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsPanel(Map<String, dynamic>? item, bool compact) {
    if (item == null) {
      return Container(
        padding: const EdgeInsets.all(22),
        decoration: _CmrDecor.card(radius: 30),
        child: _CmrEmptyState(
          title: 'Выберите элемент',
          text: 'Справа появится карточка задания или квиза: статус, очки, сроки и быстрые действия тренера.',
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

    return Container(
      padding: EdgeInsets.all(compact ? 14 : 18),
      decoration: _CmrDecor.card(radius: 30),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CmrRoundIcon(icon: isChallenge ? Icons.flag_rounded : Icons.quiz_rounded, color: isChallenge ? _CmrColors.green : _CmrColors.purple, size: compact ? 74 : 88),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_title(item), maxLines: 2, overflow: TextOverflow.ellipsis, style: _CmrText.title(compact ? 20 : 24)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          _CmrChip(text: isChallenge ? 'Задание' : 'Квиз', icon: isChallenge ? Icons.flag_rounded : Icons.quiz_rounded, color: isChallenge ? _CmrColors.green : _CmrColors.purple),
                          _CmrChip(text: status, icon: Icons.verified_rounded, color: _isActive(item) ? _CmrColors.green : _CmrColors.muted),
                          if (points > 0) _CmrChip(text: '$points очков', icon: Icons.stars_rounded, color: _CmrColors.orange),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Действия',
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  onSelected: (value) {
                    if (value == 'details') _openDetails(item);
                    if (value == 'full') _openFullList(kind);
                    if (value == 'toggle_quiz') _toggleQuiz(item);
                    if (value == 'finish') _finishChallenge(item);
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'details', child: Text('Открыть подробно')),
                    PopupMenuItem(value: 'full', child: Text(isChallenge ? 'Все задания' : 'Все квизы')),
                    if (isChallenge) const PopupMenuItem(value: 'finish', child: Text('Завершить задание')),
                    if (!isChallenge) const PopupMenuItem(value: 'toggle_quiz', child: Text('Включить / отключить')),
                  ],
                  child: const _CmrRoundIcon(icon: Icons.more_horiz_rounded, color: _CmrColors.black, size: 42),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _CmrPrimaryButton(icon: Icons.open_in_new_rounded, title: 'Открыть', onTap: _saving ? null : () => _openDetails(item))),
                const SizedBox(width: 10),
                Expanded(child: _CmrSecondaryButton(icon: isChallenge ? Icons.flag_rounded : Icons.quiz_rounded, title: isChallenge ? 'Все задания' : 'Все квизы', onTap: _saving ? null : () => _openFullList(kind))),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _CmrInfoCard(icon: Icons.verified_rounded, label: 'Статус', value: status)),
                const SizedBox(width: 10),
                Expanded(child: _CmrInfoCard(icon: Icons.stars_rounded, label: 'Награда', value: points > 0 ? '$points очков' : 'Не указана')),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _CmrInfoCard(icon: Icons.category_rounded, label: 'Тип', value: _typeText(item))),
                const SizedBox(width: 10),
                Expanded(child: _CmrInfoCard(icon: Icons.event_rounded, label: isChallenge ? 'Срок' : 'Создано', value: date.isEmpty ? 'Не указано' : date, maxLines: 2)),
              ],
            ),
            const SizedBox(height: 14),
            _CmrProfileBlock(
              icon: Icons.notes_rounded,
              title: 'Описание',
              text: _subtitle(item).isEmpty ? 'Описание пока не заполнено. Используйте карточку, чтобы быстро понять задачу игрокам.' : _subtitle(item),
            ),
            const SizedBox(height: 14),
            _CmrNotice(
              icon: Icons.tips_and_updates_rounded,
              title: 'Рабочая подсказка',
              text: isChallenge
                  ? 'Задания удобно использовать для домашних активностей, дисциплины и контроля выполнения.'
                  : 'Квизы подходят для проверки правил, тактики и понимания игровых ситуаций.',
            ),
            const SizedBox(height: 14),
            Text('Быстрые действия', style: _CmrText.title(16)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _CmrActionPill(icon: Icons.add_rounded, title: 'Новое задание', onTap: _openCreateChallenge),
                _CmrActionPill(icon: Icons.quiz_rounded, title: 'Новый квиз', onTap: _openCreateQuiz),
                _CmrActionPill(icon: Icons.emoji_events_rounded, title: 'Рейтинг', onTap: () => _openFullList(_ZoneItemKind.rating)),
                if (isChallenge) _CmrActionPill(icon: Icons.done_all_rounded, title: 'Завершить', onTap: () => _finishChallenge(item)),
                if (!isChallenge) _CmrActionPill(icon: Icons.power_settings_new_rounded, title: 'Статус квиза', onTap: () => _toggleQuiz(item)),
              ],
            ),
          ],
        ),
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: items.map((item) {
          final active = _mode == item.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(999),
              onTap: () {
                if (item.$1 == CmrGameZoneMode.rating) {
                  _openFullList(_ZoneItemKind.rating);
                  return;
                }
                setState(() {
                  _mode = item.$1;
                  _selectedIndex = 0;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: active ? _CmrColors.greenSoft : Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: active ? _CmrColors.green.withOpacity(.35) : _CmrColors.border),
                ),
                child: Text(item.$2, style: TextStyle(color: active ? _CmrColors.greenDark : _CmrColors.muted, fontSize: 12, fontWeight: FontWeight.w900)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  _ZoneItemKind _kind(Map<String, dynamic> item) => _s(item['_kind']) == _ZoneItemKind.quiz.name ? _ZoneItemKind.quiz : _ZoneItemKind.challenge;
  int _id(Map<String, dynamic> item) => _i(item['id'] ?? item['challenge_id'] ?? item['quiz_id']);
  bool _isActive(Map<String, dynamic> item) => _kind(item) == _ZoneItemKind.challenge ? _s(item['status']) == 'active' : (_i(item['is_active']) == 1 || _s(item['is_active']) == '1');
  String _title(Map<String, dynamic> item) => _first([item['title'], item['name'], item['question'], 'Без названия']);
  String _subtitle(Map<String, dynamic> item) => _first([item['description'], item['body'], item['text'], '']);
  String _dateText(Map<String, dynamic> item) => _first([item['due_date'], item['created_at'], item['date'], '']);
  String _typeText(Map<String, dynamic> item) {
    if (_kind(item) == _ZoneItemKind.quiz) return 'Викторина';
    final raw = _s(item['challenge_type']).toLowerCase();
    if (raw == 'daily') return 'Ежедневное';
    if (raw == 'weekly') return 'Еженедельное';
    return raw.isEmpty ? 'Задание' : raw;
  }

  String _statusText(Map<String, dynamic> item) {
    if (_kind(item) == _ZoneItemKind.quiz) return _isActive(item) ? 'Активен' : 'Отключён';
    final raw = _s(item['status']).toLowerCase();
    if (raw == 'active') return 'Активно';
    if (raw == 'finished') return 'Завершено';
    return raw.isEmpty ? 'Без статуса' : raw;
  }

  String _first(List<dynamic> values) {
    for (final v in values) {
      final s = _s(v);
      if (s.isNotEmpty) return s;
    }
    return '';
  }

  String _s(dynamic v) => v == null ? '' : '$v'.trim();
  int _i(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(_s(v)) ?? 0;
  }
}

class _CmrColors {
  static const bg = Color(0xFFF6F8FA);
  static const card = Colors.white;
  static const black = Color(0xFF101828);
  static const text = Color(0xFF182230);
  static const muted = Color(0xFF667085);
  static const border = Color(0xFFE6EAF0);
  static const green = Color(0xFF00A750);
  static const greenDark = Color(0xFF087A41);
  static const greenSoft = Color(0xFFEAFBF1);
  static const purple = Color(0xFF7C3AED);
  static const purpleSoft = Color(0xFFF1ECFF);
  static const orange = Color(0xFFF97316);
  static const red = Color(0xFFE53935);
}

class _CmrText {
  static TextStyle title(double size) => TextStyle(fontSize: size, fontWeight: FontWeight.w900, color: _CmrColors.black, height: 1.08);
  static TextStyle body(double size) => TextStyle(fontSize: size, fontWeight: FontWeight.w700, color: _CmrColors.muted, height: 1.25);
}

class _CmrDecor {
  static BoxDecoration card({double radius = 24}) => BoxDecoration(
        color: _CmrColors.card,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: _CmrColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.04), blurRadius: 24, offset: const Offset(0, 10))],
      );
}

class _CmrRoundIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  const _CmrRoundIcon({required this.icon, required this.color, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color == _CmrColors.purple ? _CmrColors.purpleSoft : color == _CmrColors.green ? _CmrColors.greenSoft : _CmrColors.bg,
        borderRadius: BorderRadius.circular(size / 2.8),
        border: Border.all(color: _CmrColors.border),
      ),
      child: Icon(icon, color: color, size: size * .44),
    );
  }
}

class _CmrPrimaryButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  final Color color;
  const _CmrPrimaryButton({required this.icon, required this.title, required this.onTap, this.color = _CmrColors.green});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? .55 : 1,
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(18)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Flexible(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13))),
          ]),
        ),
      ),
    );
  }
}

class _CmrSecondaryButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  const _CmrSecondaryButton({required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? .55 : 1,
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(color: _CmrColors.bg, borderRadius: BorderRadius.circular(18), border: Border.all(color: _CmrColors.border)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: _CmrColors.black, size: 18),
            const SizedBox(width: 8),
            Flexible(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _CmrColors.black, fontWeight: FontWeight.w900, fontSize: 13))),
          ]),
        ),
      ),
    );
  }
}

class _CmrStatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  const _CmrStatCard({required this.value, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: _CmrColors.bg, borderRadius: BorderRadius.circular(18), border: Border.all(color: _CmrColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: _CmrColors.greenDark, size: 17),
        const SizedBox(height: 8),
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrText.title(17)),
        const SizedBox(height: 2),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrText.body(10.5)),
      ]),
    );
  }
}

class _CmrInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  const _CmrInput({required this.controller, required this.hint, required this.icon});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: _CmrColors.text),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: _CmrColors.muted, size: 20),
        hintText: hint,
        hintStyle: const TextStyle(color: _CmrColors.muted, fontWeight: FontWeight.w700, fontSize: 12.5),
        filled: true,
        fillColor: _CmrColors.bg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: _CmrColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: _CmrColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: _CmrColors.green, width: 1.4)),
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
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _CmrZoneTile({required this.active, required this.title, required this.subtitle, required this.badge, required this.status, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: active ? _CmrColors.greenSoft : _CmrColors.bg,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: active ? _CmrColors.green.withOpacity(.45) : _CmrColors.border, width: active ? 1.4 : 1),
        ),
        child: Row(children: [
          _CmrRoundIcon(icon: icon, color: color, size: 44),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrText.title(14))),
                const SizedBox(width: 7),
                if (active) const Icon(Icons.check_circle_rounded, size: 17, color: _CmrColors.green),
              ]),
              const SizedBox(height: 5),
              Text(subtitle.isEmpty ? status : subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrText.body(11.5)),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                _CmrTinyChip(text: badge),
                _CmrTinyChip(text: status),
              ]),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded, color: _CmrColors.muted),
        ]),
      ),
    );
  }
}

class _CmrTinyChip extends StatelessWidget {
  final String text;
  const _CmrTinyChip({required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999), border: Border.all(color: _CmrColors.border)),
        child: Text(text, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: _CmrColors.muted)),
      );
}

class _CmrChip extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;
  const _CmrChip({required this.text, required this.icon, this.color = _CmrColors.muted});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(color: _CmrColors.bg, borderRadius: BorderRadius.circular(999), border: Border.all(color: _CmrColors.border)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(fontSize: 11.5, color: color, fontWeight: FontWeight.w900)),
        ]),
      );
}

class _CmrInfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final int maxLines;
  const _CmrInfoCard({required this.icon, required this.label, required this.value, this.maxLines = 1});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: _CmrColors.bg, borderRadius: BorderRadius.circular(20), border: Border.all(color: _CmrColors.border)),
        child: Row(children: [
          _CmrRoundIcon(icon: icon, color: _CmrColors.green, size: 38),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrText.body(11)),
            const SizedBox(height: 3),
            Text(value, maxLines: maxLines, overflow: TextOverflow.ellipsis, style: _CmrText.title(13.5)),
          ])),
        ]),
      );
}

class _CmrProfileBlock extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  const _CmrProfileBlock({required this.icon, required this.title, required this.text});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _CmrColors.bg, borderRadius: BorderRadius.circular(22), border: Border.all(color: _CmrColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(icon, color: _CmrColors.greenDark, size: 18), const SizedBox(width: 8), Text(title, style: _CmrText.title(15))]),
          const SizedBox(height: 8),
          Text(text, style: _CmrText.body(12.5)),
        ]),
      );
}

class _CmrNotice extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  const _CmrNotice({required this.icon, required this.title, required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _CmrColors.greenSoft, borderRadius: BorderRadius.circular(22), border: Border.all(color: _CmrColors.green.withOpacity(.22))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: _CmrColors.greenDark, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: _CmrText.title(14)),
            const SizedBox(height: 4),
            Text(text, style: _CmrText.body(12)),
          ])),
        ]),
      );
}

class _CmrActionPill extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const _CmrActionPill({required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(color: _CmrColors.bg, borderRadius: BorderRadius.circular(999), border: Border.all(color: _CmrColors.border)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 16, color: _CmrColors.greenDark), const SizedBox(width: 7), Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: _CmrColors.black))]),
        ),
      );
}

class _CmrEmptyState extends StatelessWidget {
  final String title;
  final String text;
  final String buttonText;
  final VoidCallback onTap;
  const _CmrEmptyState({required this.title, required this.text, required this.buttonText, required this.onTap});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const _CmrRoundIcon(icon: Icons.extension_off_rounded, color: _CmrColors.muted, size: 64),
            const SizedBox(height: 14),
            Text(title, textAlign: TextAlign.center, style: _CmrText.title(18)),
            const SizedBox(height: 8),
            Text(text, textAlign: TextAlign.center, style: _CmrText.body(12.5)),
            const SizedBox(height: 16),
            SizedBox(width: 210, child: _CmrPrimaryButton(icon: Icons.add_rounded, title: buttonText, onTap: onTap)),
          ]),
        ),
      );
}

class _CmrErrorState extends StatelessWidget {
  final String text;
  final VoidCallback onRetry;
  const _CmrErrorState({required this.text, required this.onRetry});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(22),
        decoration: _CmrDecor.card(radius: 30),
        child: _CmrEmptyState(title: 'Ошибка загрузки', text: text, buttonText: 'Повторить', onTap: onRetry),
      );
}

class _CmrHelpButton extends StatelessWidget {
  final String title;
  final String text;
  const _CmrHelpButton({required this.title, required this.text});

  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Text(title, style: _CmrText.title(18)),
            content: Text(text, style: _CmrText.body(13)),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Понятно'))],
          ),
        ),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(color: _CmrColors.bg, shape: BoxShape.circle, border: Border.all(color: _CmrColors.border)),
          child: const Icon(Icons.question_mark_rounded, color: _CmrColors.greenDark, size: 18),
        ),
      );
}
