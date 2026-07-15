// lib/presentation/player_game_zone/player_highlights_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'game_zone_api.dart';
import 'game_zone_cmr_style.dart';

class PlayerHighlightsScreen extends StatefulWidget {
  const PlayerHighlightsScreen({super.key});

  @override
  State<PlayerHighlightsScreen> createState() => _PlayerHighlightsScreenState();
}

class _PlayerHighlightsScreenState extends State<PlayerHighlightsScreen> {
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

    final res = await GameZoneApi.post('get_player_highlights.php', {
      'team_id': teamId,
    });

    if (!mounted) return;

    setState(() {
      loading = false;
      items = res['items'] ?? [];
    });
  }

  Future<void> _addHighlight() async {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final mediaCtrl = TextEditingController();

    await Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              children: [
                const Text(
                  'Добавить лучший момент',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: 'Название'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Описание'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: mediaCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Ссылка на фото/видео',
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      Get.back();

                      final res =
                          await GameZoneApi.post('add_player_highlight.php', {
                        'team_id': teamId,
                        'user_id': userId,
                        'title': titleCtrl.text.trim(),
                        'description': descCtrl.text.trim(),
                        'media_url': mediaCtrl.text.trim(),
                      });

                      Get.snackbar(
                        res['success'] == true ? 'Готово' : 'Ошибка',
                        res['message'] ?? '',
                        snackPosition: SnackPosition.BOTTOM,
                      );

                      if (res['success'] == true) {
                        _load();
                      }
                    },
                    child: const Text('Добавить'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      isScrollControlled: true,
    );
  }

  Future<void> _like(int id) async {
    final res = await GameZoneApi.post('like_player_highlight.php', {
      'highlight_id': id,
    });

    if (res['success'] == true) {
      _load();
    }
  }

  Widget _highlightCard(Map<String, dynamic> h) {
    final mediaUrl = (h['media_url'] ?? '').toString();

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
          Text(
            h['title'] ?? '',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            h['description'] ?? '',
            style: const TextStyle(
              color: GzColors.subtle,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Автор: ${h['author_name'] ?? 'Игрок'}',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF9CA3AF),
            ),
          ),
          if (mediaUrl.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              mediaUrl,
              style: const TextStyle(
                color: Color(0xFF2563EB),
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => _like(h['id']),
                icon: const Icon(Icons.favorite_border),
                label: Text('Лайк (${h['likes_count'] ?? 0})'),
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
      backgroundColor: GzColors.bg,
      appBar: GameZoneCmr.appBar(
        title: const Text('Мои лучшие моменты'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: GzColors.graphite,
        foregroundColor: Colors.white,
        elevation: 0,
        onPressed: _addHighlight,
        icon: const Icon(Icons.add),
        label: const Text('Добавить'),
      ),
      body: GameZoneCmr.page(
        context,
        child: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: GameZoneCmr.listPadding(context),
              children: [
                ...items.map((e) => _highlightCard(Map<String, dynamic>.from(e))),
              ],
            ),
      ),
    );
  }
}
