import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

class PlayerSelfRatingSheet extends StatefulWidget {
  final String apiBase;
  final int teamId;
  final int eventId;
  final int playerId;
  final String title;

  const PlayerSelfRatingSheet({
    super.key,
    required this.apiBase,
    required this.teamId,
    required this.eventId,
    required this.playerId,
    required this.title,
  });

  @override
  State<PlayerSelfRatingSheet> createState() => _PlayerSelfRatingSheetState();
}

class _PlayerSelfRatingSheetState extends State<PlayerSelfRatingSheet> {
  bool loading = true;
  bool saving = false;
  String? error;

  int rating = 0;
  final noteCtrl = TextEditingController();

  Color get primary => Theme.of(context).colorScheme.primary;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  @override
  void dispose() {
    noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final url = Uri.parse("${widget.apiBase}/get_self_assessment.php?event_id=${widget.eventId}&player_id=${widget.playerId}");
      final r = await http.get(url).timeout(const Duration(seconds: 10));
      final data = jsonDecode(r.body);

      if (data is Map && data["success"] == true && data["exists"] == true) {
        final d = (data["data"] as Map).map((k, v) => MapEntry(k.toString(), v));
        rating = int.tryParse("${d["rating"] ?? 0}") ?? 0;
        noteCtrl.text = (d["note"] ?? "").toString();
      }
    } catch (e) {
      error = e.toString();
    }

    if (mounted) setState(() => loading = false);
  }

  Future<void> _save() async {
    if (saving) return;
    setState(() => saving = true);

    try {
      final payload = {
        "team_id": widget.teamId,
        "event_id": widget.eventId,
        "player_id": widget.playerId,
        "rating": rating.clamp(0, 5),
        "note": noteCtrl.text.trim(),
      };

      final url = Uri.parse("${widget.apiBase}/save_self_assessment.php");
      final r = await http.post(url, headers: {"Content-Type": "application/json"}, body: jsonEncode(payload));
      final data = jsonDecode(r.body);

      if (data is Map && data["success"] == true) {
        Get.snackbar("Самооценка", "Сохранено", snackPosition: SnackPosition.BOTTOM);
        if (mounted) Navigator.pop(context, true); // ✅ вернём true
      } else {
        throw (data["message"] ?? "save error").toString();
      }
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
                  child: Text("Самооценка • ${widget.title}",
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                ),
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Закрыть")),
              ],
            ),
            const SizedBox(height: 10),

            if (loading)
              const Padding(padding: EdgeInsets.all(18), child: Center(child: CircularProgressIndicator()))
            else if (error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w800)),
              )
            else ...[
              _Stars(activeColor: primary, value: rating, onChanged: (v) => setState(() => rating = v)),
              const SizedBox(height: 10),

              TextField(
                controller: noteCtrl,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: "Заметка: почему так оценил, что получилось, что улучшить…",
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
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
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text("Сохранить", style: TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  final Color activeColor;
  final int value;
  final ValueChanged<int> onChanged;

  const _Stars({required this.activeColor, required this.value, required this.onChanged});

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
            size: 30,
          ),
        ),
      );
    }

    return Row(mainAxisSize: MainAxisSize.min, children: [for (int i = 1; i <= 5; i++) star(i)]);
  }
}
