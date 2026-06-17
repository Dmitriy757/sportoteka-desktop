import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'game_zone_api.dart';
import 'create_challenge_screen.dart';

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
          title: const Text('Удалить челлендж?'),
          content: const Text(
            'Челлендж и связанные отправки игроков будут удалены.',
          ),
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
        return const Color(0xFFEAFBF1);
      case 'weekly':
        return const Color(0xFFEAF2FF);
      default:
        return const Color(0xFFF3F4F6);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'active':
        return const Color(0xFFEAFBF1);
      case 'finished':
        return const Color(0xFFF3F4F6);
      default:
        return const Color(0xFFF3F4F6);
    }
  }

  Widget _topCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF00A750), Color(0xFF2BC56B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Задания для команды',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            teamName.isEmpty ? 'Команда' : teamName,
            style: const TextStyle(
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _miniStat('Активные', '$activeCount')),
              const SizedBox(width: 10),
              Expanded(child: _miniStat('Завершённые', '$finishedCount')),
              const SizedBox(width: 10),
              Expanded(child: _miniStat('Всего', '${allItems.length}')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String title, String value) {
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

  Widget _filterChip(String value, String label) {
    final selected = filter == value;

    return GestureDetector(
      onTap: () => setState(() => filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF00A750) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? const Color(0xFF00A750) : const Color(0xFFE5E7EB),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : Colors.black87,
          ),
        ),
      ),
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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
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
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Создай первый челлендж для команды, и он появится здесь.',
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
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _typeColor((item['challenge_type'] ?? '').toString()),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  ((item['challenge_type'] ?? '').toString()).toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _statusColor(status),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7D6),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '+${item['points_reward']}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            item['title'] ?? '',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item['description'] ?? '',
            style: const TextStyle(
              color: Color(0xFF6B7280),
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
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
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
      appBar: AppBar(
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
        onPressed: _openCreateChallenge,
        icon: const Icon(Icons.add),
        label: const Text('Новое задание'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
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
    );
  }
}