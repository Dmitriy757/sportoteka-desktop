// lib/presentation/player_game_zone/player_match_games_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'game_zone_api.dart';

class PlayerMatchGamesScreen extends StatefulWidget {
  const PlayerMatchGamesScreen({super.key});

  @override
  State<PlayerMatchGamesScreen> createState() => _PlayerMatchGamesScreenState();
}

class _PlayerMatchGamesScreenState extends State<PlayerMatchGamesScreen> {
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

    final res = await GameZoneApi.post('get_player_match_games.php', {
      'team_id': teamId,
      'user_id': userId,
    });

    if (!mounted) return;

    setState(() {
      loading = false;
      items = res['items'] ?? [];
    });
  }

  Future<void> _predict(Map<String, dynamic> match) async {
    final homeCtrl =
        TextEditingController(text: '${match['predicted_home'] ?? ''}');
    final awayCtrl =
        TextEditingController(text: '${match['predicted_away'] ?? ''}');
    final mvpCtrl =
        TextEditingController(text: '${match['predicted_mvp'] ?? ''}');

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
              Text(
                match['title'] ?? '',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: homeCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Голы 1-й команды',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: awayCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Голы 2-й команды',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: mvpCtrl,
                decoration: const InputDecoration(
                  labelText: 'Кто станет MVP',
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    Get.back();

                    final res = await GameZoneApi.post(
                      'submit_player_match_prediction.php',
                      {
                        'team_id': teamId,
                        'user_id': userId,
                        'match_id': match['match_id'],
                        'predicted_home': homeCtrl.text.trim(),
                        'predicted_away': awayCtrl.text.trim(),
                        'predicted_mvp': mvpCtrl.text.trim(),
                      },
                    );

                    Get.snackbar(
                      res['success'] == true ? 'Готово' : 'Ошибка',
                      res['message'] ?? '',
                      snackPosition: SnackPosition.BOTTOM,
                    );

                    _load();
                  },
                  child: const Text('Сохранить прогноз'),
                ),
              ),
            ],
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  Widget _matchCard(Map<String, dynamic> m) {
    final hasPrediction =
        m['predicted_home'] != null && m['predicted_away'] != null;

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
            m['title'] ?? '',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Дата: ${m['match_date'] ?? '-'}',
            style: const TextStyle(color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 12),
          if (hasPrediction)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEAFBF1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'Твой прогноз: ${m['predicted_home']} : ${m['predicted_away']} • MVP: ${m['predicted_mvp'] ?? '-'}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _predict(Map<String, dynamic>.from(m)),
              child: Text(hasPrediction ? 'Изменить прогноз' : 'Сделать прогноз'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Мини-игры к матчам'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ...items.map((e) => _matchCard(Map<String, dynamic>.from(e))),
              ],
            ),
    );
  }
}