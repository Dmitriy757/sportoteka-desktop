import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sportoteka/routes/app_routes.dart';

import 'create_quiz_screen.dart';
import 'game_zone_api.dart';
import 'game_zone_cmr_style.dart';

class TeamQuizzesScreen extends StatefulWidget {
  const TeamQuizzesScreen({super.key});

  @override
  State<TeamQuizzesScreen> createState() => _TeamQuizzesScreenState();
}

class _TeamQuizzesScreenState extends State<TeamQuizzesScreen> {
  late final int teamId;
  late final int userId;
  late final String teamName;

  bool loading = true;
  List<dynamic> allItems = [];
  String filter = 'all';

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
    teamId = _asInt(args['team_id'] ?? args['teamId']);
    userId = _asInt(args['user_id'] ?? args['userId']);
    teamName = (args['team_name'] ?? args['teamName'] ?? '').toString();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => loading = true);
    final res = await GameZoneApi.post('get_team_quizzes.php', {
      'team_id': teamId,
    });
    if (!mounted) return;
    setState(() {
      loading = false;
      allItems = res['items'] ?? [];
    });
  }

  List<Map<String, dynamic>> get filteredItems {
    final items = allItems
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    if (filter == 'active') {
      return items.where((e) => _asInt(e['is_active']) == 1).toList();
    }
    if (filter == 'inactive') {
      return items.where((e) => _asInt(e['is_active']) == 0).toList();
    }
    return items;
  }

  int get activeCount =>
      allItems.where((e) => e is Map && _asInt(e['is_active']) == 1).length;
  int get inactiveCount =>
      allItems.where((e) => e is Map && _asInt(e['is_active']) == 0).length;

  Future<void> _openCreateQuiz() async {
    final result = await Get.to(
      () => const CreateQuizScreen(),
      arguments: {
        'team_id': teamId,
        'user_id': userId,
        'team_name': teamName,
      },
    );
    if (result == true) await _load();
  }

  Future<void> _toggleQuiz(int quizId, bool current) async {
    final res = await GameZoneApi.post('toggle_player_quiz_status.php', {
      'quiz_id': quizId,
      'is_active': current ? 0 : 1,
    });
    Get.snackbar(
      res['success'] == true ? 'Готово' : 'Ошибка',
      '${res['message'] ?? ''}',
      snackPosition: SnackPosition.BOTTOM,
    );
    if (res['success'] == true) await _load();
  }

  Future<void> _deleteQuiz(int quizId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 430),
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
                  Expanded(child: Text('Удалить квиз?', style: GzText.title(16))),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Квиз, вопросы и попытки игроков будут удалены.',
                style: GzText.muted(11.3),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _DialogButton(
                      title: 'Отмена',
                      onTap: () => Navigator.pop(dialogContext, false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _DialogButton(
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

    final res = await GameZoneApi.post('delete_player_quiz.php', {
      'quiz_id': quizId,
    });
    Get.snackbar(
      res['success'] == true ? 'Готово' : 'Ошибка',
      '${res['message'] ?? ''}',
      snackPosition: SnackPosition.BOTTOM,
    );
    if (res['success'] == true) await _load();
  }

  Widget _filterChip(String value, String label) {
    final selected = filter == value;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: () => setState(() => filter = value),
        borderRadius: BorderRadius.circular(9),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? GzColors.greenSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            label,
            style: GzText.action(
              color: selected ? GzColors.greenDark : GzColors.muted2,
            ).copyWith(fontSize: 11.1),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const _QuizDotCluster(),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Квизы команды', style: GzText.title(16.5)),
                  const SizedBox(height: 3),
                  Text(teamName.isEmpty ? 'Команда' : teamName, style: GzText.muted(10.8)),
                ],
              ),
            ),
            Material(
              color: GzColors.soft,
              borderRadius: BorderRadius.circular(9),
              child: InkWell(
                onTap: _openCreateQuiz,
                borderRadius: BorderRadius.circular(9),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
                  child: Text('Новый квиз', style: GzText.action(color: GzColors.greenDark)),
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
              Expanded(child: _MiniMetric(value: '$activeCount', label: 'активных')),
              Expanded(child: _MiniMetric(value: '$inactiveCount', label: 'отключено')),
              Expanded(child: _MiniMetric(value: '${allItems.length}', label: 'всего')),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _filterChip('all', 'Все'),
              const SizedBox(width: 5),
              _filterChip('active', 'Активные'),
              const SizedBox(width: 5),
              _filterChip('inactive', 'Отключённые'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _quizRow(Map<String, dynamic> item) {
    final isActive = _asInt(item['is_active']) == 1;
    final title = '${item['title'] ?? ''}'.trim();
    final description = '${item['description'] ?? ''}'.trim();
    final points = _asInt(item['points_reward']);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: () {
          Get.toNamed(
            AppRoutes.quizDetailScreen,
            arguments: {
              'quiz_id': item['id'],
              'team_id': teamId,
              'team_name': teamName,
            },
          )?.then((_) => _load());
        },
        borderRadius: BorderRadius.circular(9),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 9, 8, 9),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(9)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: _QuizDot(
                  color: isActive ? GzColors.green : GzColors.muted2,
                  size: isActive ? 6.3 : 4.8,
                  opacity: isActive ? 1 : .48,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.isEmpty ? 'Квиз' : title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GzText.value(11.5),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        isActive ? 'Активен' : 'Отключён',
                        if (points > 0) '$points очков',
                        '${item['questions_count'] ?? 0} вопросов',
                        '${item['attempts_count'] ?? 0} попыток',
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GzText.muted(10.2),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GzText.muted(10.3),
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<String>(
                elevation: 0,
                color: Colors.white,
                surfaceTintColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (value) {
                  if (value == 'toggle') _toggleQuiz(_asInt(item['id']), isActive);
                  if (value == 'delete') _deleteQuiz(_asInt(item['id']));
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'toggle',
                    child: Text(isActive ? 'Отключить' : 'Активировать', style: GzText.action()),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Удалить', style: GzText.action(color: GzColors.red)),
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
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = filteredItems;
    return Scaffold(
      backgroundColor: GzColors.bg,
      appBar: GameZoneCmr.appBar(title: const Text('Квизы')),
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
                    const SizedBox(height: 10),
                    if (items.isEmpty)
                      _QuizEmpty(onTap: _openCreateQuiz)
                    else
                      ...items.asMap().entries.map((entry) => Column(
                            children: [
                              _quizRow(entry.value),
                              if (entry.key != items.length - 1)
                                const Divider(height: 1, color: GzColors.line),
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

class _MiniMetric extends StatelessWidget {
  final String value;
  final String label;
  const _MiniMetric({required this.value, required this.label});

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
          boxShadow: opacity > .8
              ? [BoxShadow(color: color.withOpacity(.16), blurRadius: 9)]
              : null,
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

class _DialogButton extends StatelessWidget {
  final String title;
  final VoidCallback onTap;
  final bool danger;
  const _DialogButton({required this.title, required this.onTap, this.danger = false});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: danger ? GzColors.red : GzColors.soft,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: SizedBox(
          height: 40,
          child: Center(
            child: Text(
              title,
              style: GzText.action(color: danger ? Colors.white : GzColors.text),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuizEmpty extends StatelessWidget {
  final VoidCallback onTap;
  const _QuizEmpty({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(color: GzColors.soft, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          const _QuizDotCluster(),
          const SizedBox(height: 12),
          Text('Пока нет квизов', style: GzText.title(15.5)),
          const SizedBox(height: 5),
          Text('Создайте первый квиз для команды.', textAlign: TextAlign.center, style: GzText.muted(11)),
          const SizedBox(height: 12),
          Material(
            color: GzColors.graphite,
            borderRadius: BorderRadius.circular(9),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(9),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                child: Text('Создать квиз', style: GzText.action(color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
