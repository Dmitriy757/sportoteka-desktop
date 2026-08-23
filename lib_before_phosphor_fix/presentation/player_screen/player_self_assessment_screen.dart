import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:sportoteka/presentation/player_screen/player_id_resolver.dart';
import 'package:sportoteka/presentation/player_screen/widgets/player_self_rating_sheet.dart';

enum _RateFilter { all, unrated, rated }

class PlayerSelfAssessmentScreen extends StatefulWidget {
  const PlayerSelfAssessmentScreen({super.key});

  @override
  State<PlayerSelfAssessmentScreen> createState() => _PlayerSelfAssessmentScreenState();
}

class _PlayerSelfAssessmentScreenState extends State<PlayerSelfAssessmentScreen> {
  static const apiBase = "https://sportotekaapp.ru/api";

  bool loading = true;
  String? error;

  int teamId = 0;
  int userId = 0;
  int playerId = 0;

  List<Map<String, dynamic>> pastEvents = [];
  final Map<int, Map<String, dynamic>> myByEventId = {}; // event_id -> {rating,note}

  _RateFilter filter = _RateFilter.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  int _asInt(dynamic v) => v is int ? v : int.tryParse("${v ?? 0}") ?? 0;
  String _asStr(dynamic v) => (v ?? "").toString();

  String _eventTitle(Map<String, dynamic> e) {
    final t = _asStr(e["title"]).trim();
    final n = _asStr(e["name"]).trim();
    return t.isNotEmpty ? t : (n.isNotEmpty ? n : "Тренировка");
  }

  String _eventDate(Map<String, dynamic> e) {
    final s1 = _asStr(e["end_at"]).trim();
    final s2 = _asStr(e["start_at"]).trim();
    return s2.isNotEmpty ? s2 : s1;
  }

  String _eventEnd(Map<String, dynamic> e) => _asStr(e["end_at"]).trim();

  DateTime? _parseMySqlDateTime(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return null;

    if (s.contains(".")) s = s.split(".").first;
    s = s.replaceAll("T", " ");

    final parts = s.split(" ");
    if (parts.isEmpty) return null;

    final dp = parts[0].split("-");
    if (dp.length != 3) return null;

    final y = int.tryParse(dp[0]) ?? 0;
    final m = int.tryParse(dp[1]) ?? 0;
    final d = int.tryParse(dp[2]) ?? 0;
    if (y == 0 || m == 0 || d == 0) return null;

    int hh = 0, mm = 0, ss = 0;
    if (parts.length > 1) {
      final tp = parts[1].split(":");
      if (tp.isNotEmpty) hh = int.tryParse(tp[0]) ?? 0;
      if (tp.length > 1) mm = int.tryParse(tp[1]) ?? 0;
      if (tp.length > 2) ss = int.tryParse(tp[2]) ?? 0;
    }

    return DateTime(y, m, d, hh, mm, ss);
  }

  bool _isPast(Map<String, dynamic> e) {
    final endDt = _parseMySqlDateTime(_eventEnd(e));
    final startDt = _parseMySqlDateTime(_asStr(e["start_at"]).trim());
    final now = DateTime.now();

    if (endDt != null) return endDt.isBefore(now);
    if (startDt != null) return startDt.isBefore(now);
    return true;
  }

  Future<void> _init() async {
    final args = ModalRoute.of(context)?.settings.arguments;

    if (args is Map) {
      teamId = _asInt(args["team_id"]);
      userId = _asInt(args["user_id"]);
    } else {
      teamId = 0;
      userId = 0;
    }

    if (teamId <= 0 || userId <= 0) {
      setState(() {
        loading = false;
        error = "team_id/user_id не передан";
      });
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });

    final pid = await PlayerIdResolver.resolvePlayerId(apiBase: apiBase, userId: userId);
    if (!mounted) return;

    if (pid <= 0) {
      setState(() {
        loading = false;
        error = "Не удалось определить player_id";
      });
      return;
    }

    playerId = pid;
    await _loadEventsAndMy();
  }

  Future<void> _loadEventsAndMy() async {
    if (!mounted) return;

    setState(() {
      loading = true;
      error = null;
    });

    try {
      final r1 = await http
          .get(Uri.parse("$apiBase/get_team_events.php?team_id=$teamId"))
          .timeout(const Duration(seconds: 12));

      final d1 = jsonDecode(r1.body);
      if (d1 is Map && d1["success"] != true && d1["status"] != "success") {
        throw (d1["message"] ?? "Не удалось загрузить тренировки").toString();
      }

      final list = (d1 is Map ? (d1["items"] ?? d1["events"] ?? []) : []) as List;
      final events = list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

      final r2 = await http
          .get(Uri.parse("$apiBase/get_my_self_assessments.php?team_id=$teamId&player_id=$playerId"))
          .timeout(const Duration(seconds: 12));

      final d2 = jsonDecode(r2.body);

      myByEventId.clear();
      if (d2 is Map && (d2["success"] == true || d2["status"] == "success")) {
        final items2 = (d2["items"] ?? d2["data"] ?? []) as List;
        for (final x in items2) {
          if (x is Map) {
            final m = Map<String, dynamic>.from(x);
            final eid = _asInt(m["event_id"]);
            if (eid > 0) myByEventId[eid] = m;
          }
        }
      }

      final past = events.where(_isPast).toList();
      past.sort((a, b) => _asStr(b["start_at"]).compareTo(_asStr(a["start_at"])));

      if (!mounted) return;
      setState(() {
        pastEvents = past;
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = e.toString();
        pastEvents = [];
      });
    }
  }

  Future<void> _openEvent(Map<String, dynamic> e) async {
    final eventId = _asInt(e["id"]);
    if (eventId <= 0) return;

    final title = "${_eventTitle(e)} • ${_eventDate(e)}";

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PlayerSelfRatingSheet(
        apiBase: apiBase,
        teamId: teamId,
        eventId: eventId,
        playerId: playerId,
        title: title,
      ),
    );

    if (saved == true) {
      await _loadEventsAndMy();
    }
  }

  // ===================== UI (как TeamCalendarScreen) =====================

  static const Color _bg = Color(0xFFF3F5F8);

  Widget _card({required Widget child, EdgeInsets padding = const EdgeInsets.all(12)}) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }

  Widget _pill(String text, bool active, VoidCallback onTap, {required Color primary}) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? primary.withOpacity(0.14) : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: active ? primary : const Color(0xFFE5E7EB)),
          ),
          child: Center(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: active ? primary : const Color(0xFF111827),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _filteredList() {
    if (filter == _RateFilter.all) return pastEvents;

    return pastEvents.where((e) {
      final eid = _asInt(e["id"]);
      final rated = myByEventId.containsKey(eid);
      if (filter == _RateFilter.rated) return rated;
      return !rated;
    }).toList();
  }

  Future<void> _openActionsSheet(Map<String, dynamic> e) async {
    final pad = MediaQuery.of(context).viewInsets.bottom;
    final primary = Theme.of(context).colorScheme.primary;

    final eid = _asInt(e["id"]);
    final mine = myByEventId[eid];
    final rated = mine != null;
    final rt = rated ? _asInt(mine["rating"]) : 0;
    final note = rated ? _asStr(mine["note"]).trim() : "";

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return Container(
          padding: EdgeInsets.fromLTRB(14, 14, 14, 14 + pad),
          decoration: const BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _eventTitle(e),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Закрыть"),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _eventDate(e),
                    style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 12),

                if (rated) ...[
                  _card(
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.star_rounded, color: primary),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Моя оценка: ★ $rt/5", style: const TextStyle(fontWeight: FontWeight.w900)),
                              if (note.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(note, style: const TextStyle(color: Color(0xFF374151), fontSize: 12)),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _openEvent(e);
                    },
                    icon: Icon(rated ? Icons.edit : Icons.check_circle_outline),
                    label: Text(rated ? "Изменить оценку" : "Оценить"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    final filtered = _filteredList();
    final show = filtered.take(6).toList();

    int countRated() {
      int n = 0;
      for (final e in pastEvents) {
        if (myByEventId.containsKey(_asInt(e["id"]))) n++;
      }
      return n;
    }

    final ratedCount = countRated();
    final totalCount = pastEvents.length;
    final unratedCount = (totalCount - ratedCount).clamp(0, totalCount);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text("Самооценка", style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(onPressed: _loadEventsAndMy, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : (error != null)
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: _card(
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            error!,
                            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    // Header card
                    _card(
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(Icons.stars_rounded, color: primary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("Прошедшие тренировки",
                                    style: TextStyle(fontWeight: FontWeight.w900)),
                                const SizedBox(height: 2),
                                Text(
                                  "Оценено: $ratedCount • Не оценено: $unratedCount",
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF6B7280),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Filter pills (как в календаре)
                    _card(
                      child: Row(
                        children: [
                          _pill("Все ($totalCount)", filter == _RateFilter.all, () {
                            if (filter == _RateFilter.all) return;
                            setState(() => filter = _RateFilter.all);
                          }, primary: primary),
                          const SizedBox(width: 10),
                          _pill("Не оценено ($unratedCount)", filter == _RateFilter.unrated, () {
                            if (filter == _RateFilter.unrated) return;
                            setState(() => filter = _RateFilter.unrated);
                          }, primary: primary),
                          const SizedBox(width: 10),
                          _pill("Оценено ($ratedCount)", filter == _RateFilter.rated, () {
                            if (filter == _RateFilter.rated) return;
                            setState(() => filter = _RateFilter.rated);
                          }, primary: primary),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    if (filtered.isEmpty)
                      _card(
                        child: const Row(
                          children: [
                            Icon(Icons.inbox_outlined, color: Color(0xFF6B7280)),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "Ничего не найдено по выбранному фильтру",
                                style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w700),
                              ),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      ...show.map((e) {
                        final eid = _asInt(e["id"]);
                        final title = _eventTitle(e);
                        final date = _eventDate(e);

                        final mine = myByEventId[eid];
                        final rated = mine != null;
                        final rt = rated ? _asInt(mine["rating"]) : 0;

                        return InkWell(
                          onTap: () => _openEvent(e),
                          onLongPress: () => _openActionsSheet(e),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: rated ? primary.withOpacity(0.12) : const Color(0xFFEEF2FF),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    rated ? Icons.check_circle_outline_rounded : Icons.fitness_center_outlined,
                                    color: rated ? primary : const Color(0xFF4F46E5),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF111827),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        date,
                                        style: const TextStyle(
                                          color: Color(0xFF6B7280),
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                if (rated)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: primary.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(color: primary.withOpacity(0.35)),
                                    ),
                                    child: Text(
                                      "★ $rt/5",
                                      style: TextStyle(color: primary, fontWeight: FontWeight.w900, fontSize: 12),
                                    ),
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: primary,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: const Text(
                                      "Оценить",
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }),

                      if (filtered.length > show.length) ...[
                        const SizedBox(height: 2),
                        _card(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: () => _showAllSheet(filtered),
                              child: Text("Показать все (${filtered.length})"),
                            ),
                          ),
                        ),
                      ]
                    ],
                  ],
                ),
    );
  }

  Future<void> _showAllSheet(List<Map<String, dynamic>> list) async {
    final pad = MediaQuery.of(context).viewInsets.bottom;
    final primary = Theme.of(context).colorScheme.primary;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return Container(
          padding: EdgeInsets.fromLTRB(14, 14, 14, 14 + pad),
          decoration: const BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(99)),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Все тренировки (${list.length})",
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                    ),
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text("Закрыть")),
                  ],
                ),
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 560),
                  child: ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final e = list[i];
                      final eid = _asInt(e["id"]);
                      final title = _eventTitle(e);
                      final date = _eventDate(e);
                      final mine = myByEventId[eid];
                      final rated = mine != null;
                      final rt = rated ? _asInt(mine["rating"]) : 0;

                      return InkWell(
                        onTap: () async {
                          Navigator.pop(context);
                          await _openEvent(e);
                        },
                        onLongPress: () => _openActionsSheet(e),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: rated ? primary.withOpacity(0.12) : const Color(0xFFEEF2FF),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  rated ? Icons.check_circle_outline_rounded : Icons.fitness_center_outlined,
                                  color: rated ? primary : const Color(0xFF4F46E5),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF111827))),
                                    const SizedBox(height: 4),
                                    Text(date,
                                        style: const TextStyle(
                                          color: Color(0xFF6B7280),
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        )),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              if (rated)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: primary.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(color: primary.withOpacity(0.35)),
                                  ),
                                  child: Text("★ $rt/5",
                                      style: TextStyle(color: primary, fontWeight: FontWeight.w900, fontSize: 12)),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(999)),
                                  child: const Text("Оценить",
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
