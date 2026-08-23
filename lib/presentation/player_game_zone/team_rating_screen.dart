// lib/presentation/player_game_zone/team_rating_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'game_zone_api.dart';
import 'game_zone_cmr_style.dart';

class TeamRatingScreen extends StatefulWidget {
  const TeamRatingScreen({super.key});

  @override
  State<TeamRatingScreen> createState() => _TeamRatingScreenState();
}

class _TeamRatingScreenState extends State<TeamRatingScreen> {
  late final int teamId;
  late final int userId;
  late final String teamName;

  bool loading = true;
  int myRank = 0;
  int myPoints = 0;
  List<dynamic> players = [];

  @override
  void initState() {
    super.initState();
    final args = Map<String, dynamic>.from(Get.arguments ?? {});
    teamId = args['team_id'] ?? 0;
    userId = args['user_id'] ?? 0;
    teamName = args['team_name'] ?? '';
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);

    final res = await GameZoneApi.post('get_team_rating.php', {
      'team_id': teamId,
      'user_id': userId,
    });

    if (!mounted) return;

    setState(() {
      loading = false;
      if (res['success'] == true) {
        myRank = res['my_rank'] ?? 0;
        myPoints = res['my_points'] ?? 0;
        players = res['players'] ?? [];
      }
    });
  }

  Widget _topCard() {
    return GameZoneCmr.header(
      title: 'Твоё место в рейтинге',
      subtitle: teamName.isEmpty ? 'Команда' : teamName,
      icon: Icons.leaderboard_rounded,
      stats: [
        GameZoneCmr.stat('Место', '#$myRank'),
        const SizedBox(width: 10),
        GameZoneCmr.stat('Очки', '$myPoints', color: GzColors.amber),
      ],
    );
  }

  Widget _miniStat(String title, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.14),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              value,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _playerTile(Map<String, dynamic> p) {
    final isMe = (p['user_id'] ?? 0) == userId;
    final rank = p['rank'] ?? 0;
    final name = (p['name'] ?? 'Игрок').toString();
    final points = p['points'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isMe ? GzColors.greenSoft : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor:
                isMe ? GzColors.green : GzColors.soft2,
            child: Text(
              '$rank',
              style: TextStyle(
                color: isMe ? Colors.white : GzColors.text,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7D6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$points очк.',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF8A6400),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GzColors.bg,
      appBar: GameZoneCmr.appBar(
        title: const Text('Рейтинг команды'),
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
                  const SizedBox(height: 18),
                  const Text(
                    'Лидеры команды',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...players.map((e) => _playerTile(Map<String, dynamic>.from(e))),
                ],
              ),
            ),
      ),
    );
  }
}
