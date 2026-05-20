import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:sportoteka/core/utils/confirm_dialogs.dart';

class TrainingRatingSheet extends StatefulWidget {
  final String apiBase;
  final int teamId;
  final int eventId;
  final int coachId;
  final String title;

  const TrainingRatingSheet({
    super.key,
    required this.apiBase,
    required this.teamId,
    required this.eventId,
    required this.coachId,
    required this.title,
  });

  @override
  State<TrainingRatingSheet> createState() => _TrainingRatingSheetState();
}

class _TrainingRatingSheetState extends State<TrainingRatingSheet> {
  bool loading = true;
  bool saving = false;
  String? error;

  List<_Player> players = [];
  final Map<int, int> ratingByPlayerId = {};

  Color get primary => Theme.of(context).colorScheme.primary;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      players = await _fetchPlayers(widget.teamId);
      final existing = await _fetchRatings(widget.eventId);

      ratingByPlayerId.clear();
      ratingByPlayerId.addAll(existing);

      for (final p in players) {
        ratingByPlayerId.putIfAbsent(p.id, () => 0);
      }
    } catch (e) {
      error = e.toString();
    }

    if (mounted) setState(() => loading = false);
  }

  // ✅ твой эндпоинт игроков команды
  Future<List<_Player>> _fetchPlayers(int teamId) async {
    final url = Uri.parse("${widget.apiBase}/get_players_by_team.php?team_id=$teamId");
    final r = await http.get(url);
    if (r.statusCode != 200) throw "players http ${r.statusCode}";

    final data = jsonDecode(r.body);

    // ожидаем: { success: true, players: [...] } или { players: [...] }
    final list = (data is Map ? (data["players"] ?? data["data"] ?? []) : []) as List;

    return list.map((x) {
      final m = (x as Map).map((k, v) => MapEntry(k.toString(), v));
      return _Player(
        id: _asInt(m["id"] ?? m["player_id"]),
        firstName: (m["first_name"] ?? m["name"] ?? "").toString(),
        lastName: (m["last_name"] ?? m["surname"] ?? "").toString(),
        position: (m["position"] ?? "").toString(),
        photo: (m["photo_url"] ?? m["photo"] ?? "").toString(),
      );
    }).where((p) => p.id > 0).toList();
  }

  Future<Map<int, int>> _fetchRatings(int eventId) async {
    final url = Uri.parse("${widget.apiBase}/get_training_ratings.php?event_id=$eventId");
    final r = await http.get(url);
    if (r.statusCode != 200) throw "ratings http ${r.statusCode}";

    final data = jsonDecode(r.body);
    if (data is Map && data["success"] == false) {
      throw (data["message"] ?? "ratings error").toString();
    }

    final list = (data is Map ? (data["ratings"] ?? []) : []) as List;
    final out = <int, int>{};

    for (final x in list) {
      final m = (x as Map).map((k, v) => MapEntry(k.toString(), v));
      final pid = _asInt(m["player_id"]);
      final rt = _asInt(m["rating"]).clamp(0, 5);
      if (pid > 0) out[pid] = rt;
    }

    return out;
  }

  Future<void> _save() async {
    if (saving) return;
    setState(() => saving = true);

    try {
      final payload = {
        "team_id": widget.teamId,
        "event_id": widget.eventId,
        "coach_id": widget.coachId,
        "ratings": players.map((p) => {
          "player_id": p.id,
          "rating": (ratingByPlayerId[p.id] ?? 0).clamp(0, 5),
        }).toList(),
      };

      final url = Uri.parse("${widget.apiBase}/save_training_ratings.php");
      final r = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      if (r.statusCode != 200) throw "save http ${r.statusCode}";

      final data = jsonDecode(r.body);
      if (data is Map && data["success"] != true) {
        throw (data["message"] ?? "save error").toString();
      }

      Get.snackbar("Оценка", "Сохранено", snackPosition: SnackPosition.BOTTOM);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      Get.snackbar("Ошибка", e.toString(), snackPosition: SnackPosition.BOTTOM);
    }

    if (mounted) setState(() => saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(14, 14, 14, 14 + pad),
      decoration: const BoxDecoration(
        color: Color(0xFFF3F5F8),
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 44, height: 5, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(99))),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: Text(
                    "Оценка • ${widget.title}",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                ),
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Закрыть")),
              ],
            ),
            const SizedBox(height: 10),

            if (loading)
              const Padding(
                padding: EdgeInsets.all(18),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (error != null)
              _ErrorView(text: error!, onRetry: _load)
            else ...[
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 520),
                child: ListView.builder(
                  itemCount: players.length,
                  itemBuilder: (_, i) {
                    final p = players[i];
                    final r = ratingByPlayerId[p.id] ?? 0;

                    return _PlayerRow(
                      primary: primary,
                      p: p,
                      rating: r,
                      onChanged: (v) => setState(() => ratingByPlayerId[p.id] = v),
                    );
                  },
                ),
              ),

              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
  onPressed: saving
      ? null
      : () async {
          final ok = await showResetConfirmDialog(
            context,
            title: "Сбросить оценки?",
            description:
                "Все оценки игроков за эту тренировку будут обнулены.\nОтменить будет невозможно.",
          );

          if (!ok) return;

          setState(() {
            for (final p in players) {
              ratingByPlayerId[p.id] = 0;
            }
          });

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Оценки сброшены")),
            );
          }
        },
  child: const Text("Сбросить"),
),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text("Сохранить"),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  final Color primary;
  final _Player p;
  final int rating;
  final ValueChanged<int> onChanged;

  const _PlayerRow({
    required this.primary,
    required this.p,
    required this.rating,
    required this.onChanged,
  });

  String fio() {
    final a = [p.firstName.trim(), p.lastName.trim()].where((x) => x.isNotEmpty).toList();
    return a.isEmpty ? "Игрок #${p.id}" : a.join(" ");
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: primary.withOpacity(0.12),
            backgroundImage: p.photo.trim().isNotEmpty ? NetworkImage(p.photo) : null,
            child: p.photo.trim().isEmpty
                ? Text(fio().substring(0, 1).toUpperCase(), style: TextStyle(color: primary, fontWeight: FontWeight.w900))
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fio(), style: const TextStyle(fontWeight: FontWeight.w900)),
                if (p.position.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(p.position, style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w700, fontSize: 12)),
                ],
              ],
            ),
          ),
          _Stars(activeColor: primary, value: rating, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  final Color activeColor;
  final int value; // 0..5
  final ValueChanged<int> onChanged;

  const _Stars({
    required this.activeColor,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    Widget star(int i) {
      final filled = i <= value;
      return InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => onChanged(i),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            filled ? Icons.star_rounded : Icons.star_outline_rounded,
            color: filled ? activeColor : const Color(0xFF9CA3AF),
            size: 26,
          ),
        ),
      );
    }

    return Row(mainAxisSize: MainAxisSize.min, children: [for (int i = 1; i <= 5; i++) star(i)]);
  }
}

class _ErrorView extends StatelessWidget {
  final String text;
  final VoidCallback onRetry;
  const _ErrorView({required this.text, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Text(text, style: const TextStyle(color: Color(0xFFB91C1C), fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          ElevatedButton(onPressed: onRetry, child: const Text("Повторить")),
        ],
      ),
    );
  }
}

class _Player {
  final int id;
  final String firstName;
  final String lastName;
  final String position;
  final String photo;

  _Player({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.position,
    required this.photo,
  });
}

int _asInt(dynamic v) => v is int ? v : int.tryParse((v ?? "").toString()) ?? 0;
