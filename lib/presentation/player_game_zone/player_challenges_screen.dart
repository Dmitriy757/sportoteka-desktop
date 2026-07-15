import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'game_zone_api.dart';
import 'create_challenge_screen.dart';
import 'game_zone_cmr_style.dart';

class PlayerChallengesScreen extends StatefulWidget {
  const PlayerChallengesScreen({super.key});

  @override
  State<PlayerChallengesScreen> createState() => _PlayerChallengesScreenState();
}

class _PlayerChallengesScreenState extends State<PlayerChallengesScreen> {
  late final int teamId;
  late final int userId;
  late final String teamName;

  bool loading = true;
  List<dynamic> items = [];

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

    final res = await GameZoneApi.post('get_player_challenges.php', {
      'team_id': teamId,
      'user_id': userId,
    });

    if (!mounted) return;

    setState(() {
      loading = false;
      items = res['items'] ?? [];
    });
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

  Future<void> _submitChallenge(int challengeId) async {
    final noteCtrl = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Отправить результат',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText:
                      'Напиши, как выполнил задание: количество повторов, время, результат...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);

                    final res = await GameZoneApi.post(
                      'submit_player_challenge.php',
                      {
                        'challenge_id': challengeId,
                        'team_id': teamId,
                        'user_id': userId,
                        'note': noteCtrl.text.trim(),
                      },
                    );

                    Get.snackbar(
                      res['success'] == true ? 'Готово' : 'Ошибка',
                      res['message'] ?? '',
                      snackPosition: SnackPosition.BOTTOM,
                    );

                    if (res['success'] == true) {
                      _load();
                    }
                  },
                  child: const Text('Сдать челлендж'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

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

  Widget _header() {
    return GameZoneCmr.header(
      title: 'Задания дня и недели',
      subtitle: 'Выполняй задания, отправляй результат и набирай очки для рейтинга команды.',
      icon: Icons.flag_rounded,
    );
  }

  Widget _emptyState() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: GzColors.divider),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.flag_outlined,
            size: 42,
            color: Color(0xFF00A750),
          ),
          const SizedBox(height: 12),
          const Text(
            'Пока нет активных челленджей',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Создай первый челлендж для команды, чтобы игроки начали соревноваться.',
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
    final done = (item['my_status'] ?? '') == 'approved';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      border: Border.all(color: GzColors.divider),
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
                  ((item['challenge_type'] ?? 'challenge').toString())
                      .toUpperCase(),
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
                  style: const TextStyle(fontWeight: FontWeight.w900),
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
              color: GzColors.subtle,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'До: ${item['due_date'] ?? '-'}',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF9CA3AF),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: done ? null : () => _submitChallenge(item['id']),
              child: Text(done ? 'Уже выполнено' : 'Выполнить'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canCreate = userId > 0;

    return Scaffold(
      backgroundColor: GzColors.bg,
      appBar: GameZoneCmr.appBar(
        title: const Text('Челленджи'),
        actions: [
          if (canCreate)
            IconButton(
              onPressed: _openCreateChallenge,
              icon: const Icon(Icons.add),
              tooltip: 'Создать челлендж',
            ),
        ],
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
                  _header(),
                  const SizedBox(height: 16),
                  if (items.isEmpty)
                    _emptyState()
                  else
                    ...items.map(
                      (e) => _challengeCard(Map<String, dynamic>.from(e)),
                    ),
                ],
              ),
            ),
      ),
    );
  }
}
