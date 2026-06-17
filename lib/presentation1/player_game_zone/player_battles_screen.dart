// lib/presentation/player_game_zone/player_battles_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'game_zone_api.dart';

class PlayerBattlesScreen extends StatefulWidget {
  const PlayerBattlesScreen({super.key});

  @override
  State<PlayerBattlesScreen> createState() => _PlayerBattlesScreenState();
}

class _PlayerBattlesScreenState extends State<PlayerBattlesScreen> {
  late final int teamId;
  late final int userId;
  bool loading = true;
  List<dynamic> items = [];

  @override
  void initState() {
    super.initState();
    final args = Map<String, dynamic>.from(Get.arguments ?? {});
    teamId = args['team_id'] ?? 0;
    userId = args['user_id'] ?? 0;
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);

    final res = await GameZoneApi.post('get_player_battles.php', {
      'team_id': teamId,
      'user_id': userId,
    });

    if (!mounted) return;

    setState(() {
      loading = false;
      items = res['items'] ?? [];
    });
  }

  Future<void> _accept(int battleId) async {
    final res = await GameZoneApi.post('respond_player_battle.php', {
      'battle_id': battleId,
      'team_id': teamId,
      'user_id': userId,
      'action': 'accept',
    });

    Get.snackbar(
      res['success'] == true ? 'Готово' : 'Ошибка',
      res['message'] ?? '',
      snackPosition: SnackPosition.BOTTOM,
    );

    _load();
  }

  Future<void> _submitScore(int battleId) async {
    final ctrl = TextEditingController();

    await Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
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
                controller: ctrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Например: 25',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    Get.back();

                    final res =
                        await GameZoneApi.post('respond_player_battle.php', {
                      'battle_id': battleId,
                      'team_id': teamId,
                      'user_id': userId,
                      'action': 'submit_score',
                      'score': ctrl.text.trim(),
                    });

                    Get.snackbar(
                      res['success'] == true ? 'Готово' : 'Ошибка',
                      res['message'] ?? '',
                      snackPosition: SnackPosition.BOTTOM,
                    );

                    _load();
                  },
                  child: const Text('Сохранить'),
                ),
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _battleUser(String name, int score) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$score',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _battleCard(Map<String, dynamic> b) {
    final isPending = b['status'] == 'pending';
    final isFinished = b['status'] == 'finished';

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
          Text(
            b['title'] ?? '',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            b['description'] ?? '',
            style: const TextStyle(color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _battleUser(
                  b['challenger_name'] ?? 'Игрок 1',
                  b['challenger_score'] ?? 0,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'VS',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
              ),
              Expanded(
                child: _battleUser(
                  b['opponent_name'] ?? 'Игрок 2',
                  b['opponent_score'] ?? 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isFinished)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEAFBF1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                'Победитель определён',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            )
          else
            Row(
              children: [
                if (isPending)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _accept(b['id']),
                      child: const Text('Принять вызов'),
                    ),
                  ),
                if (!isPending)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _submitScore(b['id']),
                      child: const Text('Отправить результат'),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Битва игроков'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ...items.map((e) => _battleCard(Map<String, dynamic>.from(e))),
              ],
            ),
    );
  }
}