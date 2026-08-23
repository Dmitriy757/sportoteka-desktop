import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'game_zone_api.dart';
import 'create_challenge_screen.dart';
import 'game_zone_cmr_style.dart';

class TeamChallengesScreen extends StatefulWidget {
  const TeamChallengesScreen({super.key});

  @override
  State<TeamChallengesScreen> createState() => _TeamChallengesScreenState();
}

class _TeamChallengesScreenState extends State<TeamChallengesScreen> {
  late final int teamId;
  late final int userId;
  late final String teamName;

  bool loading = true;
  List<dynamic> allItems = [];
  String filter = 'all';

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

    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);

    final res = await GameZoneApi.post('get_team_challenges.php', {
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
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    if (filter == 'all') return items;
    if (filter == 'active') {
      return items.where((e) => (e['status'] ?? '') == 'active').toList();
    }
    if (filter == 'finished') {
      return items.where((e) => (e['status'] ?? '') == 'finished').toList();
    }
    if (filter == 'daily') {
      return items.where((e) => (e['challenge_type'] ?? '') == 'daily').toList();
    }
    if (filter == 'weekly') {
      return items.where((e) => (e['challenge_type'] ?? '') == 'weekly').toList();
    }
    return items;
  }

  int get activeCount => allItems.where((e) => e['status'] == 'active').length;
  int get finishedCount =>
      allItems.where((e) => e['status'] == 'finished').length;

  Future<void> _openCreateChallenge() async {
    final result = await Get.to(
      () => const CreateChallengeScreen(),
      arguments: {
        'team_id': teamId,
        'user_id': userId,
        'team_name': teamName,
      },
    );

    if (result == true) {
      _load();
    }
  }

  Future<void> _finishChallenge(int challengeId) async {
    final res = await GameZoneApi.post('finish_player_challenge.php', {
      'challenge_id': challengeId,
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

  Future<void> _deleteChallenge(int challengeId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          titleTextStyle: GzText.title(16),
          contentTextStyle: GzText.muted(11.4),
          title: const Text('Удалить челлендж?'),
          content: const Text(
            'Челлендж и связанные отправки игроков будут удалены.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              style: TextButton.styleFrom(
                foregroundColor: GzColors.graphiteSoft,
                textStyle: GzText.action(),
              ),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: GzColors.red,
                foregroundColor: Colors.white,
                elevation: 0,
                textStyle: GzText.action(color: Colors.white),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Удалить'),
            ),
          ],
        );
      },
    );

    if (ok != true) return;

    final res = await GameZoneApi.post('delete_player_challenge.php', {
      'challenge_id': challengeId,
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

  Color _typeColor(String type) {
    switch (type) {
      case 'daily':
        return GzColors.greenSoft;
      case 'weekly':
        return const Color(0xFFEAF2FF);
      default:
        return GzColors.soft2;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active':
        return GzColors.greenSoft;
      case 'finished':
        return GzColors.soft2;
      default:
        return GzColors.soft2;
    }
  }

  Widget _topCard() {
    return GameZoneCmr.header(
      title: 'Задания для команды',
      subtitle: teamName.isEmpty ? 'Команда' : teamName,
      icon: Icons.flag_rounded,
      stats: [
        GameZoneCmr.stat('Активные', '$activeCount'),
        const SizedBox(width: 10),
        GameZoneCmr.stat('Завершённые', '$finishedCount', color: GzColors.blue),
        const SizedBox(width: 10),
        GameZoneCmr.stat('Всего', '${allItems.length}', color: GzColors.amber),
      ],
    );
  }

  Widget _miniStat(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String value, String label) {
    final selected = filter == value;
    return GameZoneCmr.chip(
      label: label,
      selected: selected,
      onTap: () => setState(() => filter = value),
    );
  }

  Widget _filters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _filterChip('all', 'Все'),
          const SizedBox(width: 8),
          _filterChip('active', 'Активные'),
          const SizedBox(width: 8),
          _filterChip('finished', 'Завершённые'),
          const SizedBox(width: 8),
          _filterChip('daily', 'День'),
          const SizedBox(width: 8),
          _filterChip('weekly', 'Неделя'),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
              ),
      child: Column(
        children: [
          const Icon(
            Icons.flag_outlined,
            size: 44,
            color: Color(0xFF00A750),
          ),
          const SizedBox(height: 12),
          const Text(
            'Пока нет созданных челленджей',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Создай первый челлендж для команды, и он появится здесь.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: GzColors.subtle,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _openCreateChallenge,
              icon: const Icon(Icons.add),
              label: const Text('Создать челлендж'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _challengeCard(Map<String, dynamic> item) {
    final status = (item['status'] ?? '').toString();
    final isActive = status == 'active';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _typeColor((item['challenge_type'] ?? '').toString()),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  ((item['challenge_type'] ?? '').toString()).toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 10.2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _statusColor(status),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 10.2,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7D6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '+${item['points_reward']}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            item['title'] ?? '',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item['description'] ?? '',
            style: const TextStyle(
              color: GzColors.subtle,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metaPill('Создан: ${item['created_at'] ?? '-'}'),
              _metaPill('До: ${item['due_date'] ?? '-'}'),
              _metaPill('Отправок: ${item['submissions_count'] ?? 0}'),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              if (isActive)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _finishChallenge(item['id']),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('Завершить'),
                  ),
                ),
              if (isActive) const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _deleteChallenge(item['id']),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Удалить'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metaPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: GzColors.soft,
        borderRadius: BorderRadius.circular(8),
              ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10.8,
          fontWeight: FontWeight.w700,
          color: Color(0xFF4B5563),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = filteredItems;

    return Scaffold(
      backgroundColor: GzColors.bg,
      appBar: GameZoneCmr.appBar(
        title: const Text('Задания'),
        actions: [
          IconButton(
            onPressed: _openCreateChallenge,
            icon: const Icon(Icons.add),
            tooltip: 'Создать задание',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: GzColors.graphite,
        foregroundColor: Colors.white,
        elevation: 0,
        onPressed: _openCreateChallenge,
        icon: const Icon(Icons.add),
        label: const Text('Новое задание'),
      ),
      body: GameZoneCmr.page(
        context,
        child: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: GameZoneCmr.listPadding(context),
                children: [
                  _topCard(),
                  const SizedBox(height: 16),
                  _filters(),
                  const SizedBox(height: 16),
                  if (items.isEmpty)
                    _emptyState()
                  else
                    ...items.map((e) => _challengeCard(e)),
                  const SizedBox(height: 90),
                ],
              ),
            ),
      ),
    );
  }
}
