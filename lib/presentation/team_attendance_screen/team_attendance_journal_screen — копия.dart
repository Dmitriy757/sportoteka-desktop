// lib/presentation/team_attendance_screen/team_attendance_journal_screen.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import 'team_attendance_screen.dart';

class TeamAttendanceJournalScreen extends StatefulWidget {
  final int teamId;
  final String teamName;

  const TeamAttendanceJournalScreen({
    super.key,
    required this.teamId,
    required this.teamName,
  });

  @override
  State<TeamAttendanceJournalScreen> createState() =>
      _TeamAttendanceJournalScreenState();
}

class _TeamAttendanceJournalScreenState extends State<TeamAttendanceJournalScreen> {
  static const String apiBase = "https://sportotekaapp.ru/api";
  static const String playersUrl = "$apiBase/get_players_by_team.php";
  static const String getTeamEventsUrl = "$apiBase/get_team_events.php";
  static const String getAttendanceUrl = "$apiBase/get_team_attendance.php";

  bool loading = true;
  String? error;

  DateTime month = DateTime(DateTime.now().year, DateTime.now().month, 1);

  List<Map<String, dynamic>> players = [];
  List<Map<String, dynamic>> events = [];

  // YYYY-MM-DD -> events[]
  final Map<String, List<Map<String, dynamic>>> eventsByDate = {};

  // attendanceByEvent[eventId][playerId] = {status, note}
  final Map<int, Map<String, Map<String, dynamic>>> attendanceByEvent = {};

  Map<String, dynamic> _decodeBody(String body) {
    final j = jsonDecode(body);
    if (j is Map<String, dynamic>) return j;
    return {"success": false, "message": "Bad JSON format"};
  }

  int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  String _asStr(dynamic v) => (v ?? "").toString();

  String _playerName(Map<String, dynamic> p) {
    final fn = _asStr(p["fullName"]).trim();
    if (fn.isNotEmpty) return fn;
    final a = _asStr(p["first_name"]).trim();
    final b = _asStr(p["last_name"]).trim();
    final s = "$a $b".trim();
    return s.isNotEmpty ? s : "Игрок";
  }

  int _daysInMonth(DateTime m) {
    final next = DateTime(m.year, m.month + 1, 1);
    return next.subtract(const Duration(days: 1)).day;
  }

  String _monthTitle() {
    const ru = [
      "Январь","Февраль","Март","Апрель","Май","Июнь",
      "Июль","Август","Сентябрь","Октябрь","Ноябрь","Декабрь"
    ];
    return "${ru[month.month - 1]} ${month.year}";
  }

  String _dateKey(int day) {
    final d = DateTime(month.year, month.month, day);
    final y = d.year.toString().padLeft(4, "0");
    final m = d.month.toString().padLeft(2, "0");
    final dd = d.day.toString().padLeft(2, "0");
    return "$y-$m-$dd";
  }

  String _dateOnlyFromStartAt(Map<String, dynamic> e) {
    final s = _asStr(e["start_at"]).trim(); // "2026-01-30 18:00:00"
    if (s.isEmpty) return "";
    return s.length >= 10 ? s.substring(0, 10) : s;
  }

  String _eventTitle(Map<String, dynamic> e) {
    final t = _asStr(e["title"]).trim();
    final n = _asStr(e["name"]).trim();
    return t.isNotEmpty ? t : (n.isNotEmpty ? n : "Мероприятие");
  }

  // ВАЖНО: показываем реальную ошибку (код + кусок ответа)
  void _fail(String where, http.Response? resp, Object? e) {
    final code = resp?.statusCode;
    final body = resp?.body ?? "";
    final snippet = body.isEmpty
        ? ""
        : (body.length > 300 ? body.substring(0, 300) : body);

    setState(() {
      error = [
        "Ошибка в $where",
        if (widget.teamId <= 0) "teamId=0 (проверь передачу teamId при навигации!)",
        if (code != null) "HTTP $code",
        if (snippet.isNotEmpty) "Ответ: $snippet",
        if (e != null) "Exception: $e",
      ].join("\n");
      loading = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    if (!mounted) return;

    if (widget.teamId <= 0) {
      setState(() {
        loading = false;
        error = "teamId=0 — экран журнала открыт без teamId.\n"
            "Проверь: TeamDashboardScreen -> TeamAttendanceJournalScreen(teamId: widget.teamId).";
      });
      return;
    }

    setState(() {
      loading = true;
      error = null;
      players = [];
      events = [];
      eventsByDate.clear();
      attendanceByEvent.clear();
    });

    try {
      await _fetchPlayers();          // если упадёт — покажем причину
      await _fetchEventsForMonth();   // может быть пусто — это НЕ ошибка
      await _fetchAttendanceForEvents(); // может частично не загрузиться — не валим весь журнал

      if (!mounted) return;
      setState(() => loading = false);
    } catch (e) {
      // на всякий (обычно сюда уже не попадём, т.к. _fail выставит error)
      if (!mounted) return;
      setState(() {
        loading = false;
        error = "Исключение: $e";
      });
    }
  }

  Future<void> _fetchPlayers() async {
    http.Response? resp;
    try {
      final uri = Uri.parse(playersUrl).replace(queryParameters: {
        "team_id": widget.teamId.toString(),
      });

      resp = await http.get(uri).timeout(const Duration(seconds: 12));
      final data = _decodeBody(resp.body);

      if (data["status"] != "success") {
        final msg = _asStr(data["message"]).trim();
        _fail("get_players_by_team.php", resp, msg.isNotEmpty ? msg : "status != success");
        throw Exception("players error");
      }

      final list = (data["players"] as List?) ?? [];
      players = list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      players.sort((a, b) => _playerName(a).toLowerCase().compareTo(_playerName(b).toLowerCase()));
    } on FormatException catch (e) {
      _fail("players JSON decode", resp, e);
      rethrow;
    } on TimeoutException catch (e) {
      _fail("players timeout", resp, e);
      rethrow;
    } catch (e) {
      if (error == null) _fail("players", resp, e);
      rethrow;
    }
  }

  Future<void> _fetchEventsForMonth() async {
    http.Response? resp;
    try {
      final from = "${month.year.toString().padLeft(4, "0")}-${month.month.toString().padLeft(2, "0")}-01";
      final lastDay = _daysInMonth(month);
      final to = "${month.year.toString().padLeft(4, "0")}-${month.month.toString().padLeft(2, "0")}-${lastDay.toString().padLeft(2, "0")}";

      final uri = Uri.parse(getTeamEventsUrl).replace(queryParameters: {
        "team_id": widget.teamId.toString(),
        "from": from,
        "to": to,
      });

      resp = await http.get(uri).timeout(const Duration(seconds: 12));
      final data = _decodeBody(resp.body);

      final ok = (data["success"] == true) || (data["status"] == "success");
      if (!ok) {
        final msg = _asStr(data["message"]).trim();
        _fail("get_team_events.php", resp, msg.isNotEmpty ? msg : "success=false");
        throw Exception("events error");
      }

      final listRaw = (data["items"] is List)
          ? (data["items"] as List)
          : (data["events"] is List)
              ? (data["events"] as List)
              : const [];

      events = listRaw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      events.sort((a, b) => _dateOnlyFromStartAt(a).compareTo(_dateOnlyFromStartAt(b)));

      eventsByDate.clear();
      for (final e in events) {
        final dk = _dateOnlyFromStartAt(e);
        if (dk.isEmpty) continue;
        eventsByDate.putIfAbsent(dk, () => []);
        eventsByDate[dk]!.add(e);
      }
    } on FormatException catch (e) {
      _fail("events JSON decode", resp, e);
      rethrow;
    } catch (e) {
      if (error == null) _fail("events", resp, e);
      rethrow;
    }
  }

  Future<void> _fetchAttendanceForEvents() async {
    if (events.isEmpty) return;

    // грузим пачками, но если где-то ошибка — просто пропускаем, журнал всё равно покажем
    const batchSize = 6;
    int i = 0;

    while (i < events.length) {
      final batch = events.skip(i).take(batchSize).toList();
      i += batch.length;

      await Future.wait(batch.map((e) async {
        final eventId = _asInt(e["id"]);
        if (eventId <= 0) return;

        try {
          final uri = Uri.parse(getAttendanceUrl).replace(queryParameters: {
            "event_id": eventId.toString(),
          });

          final resp = await http.get(uri).timeout(const Duration(seconds: 12));
          final data = _decodeBody(resp.body);

          if (data["success"] != true) return;

          final items = (data["items"] as Map?) ?? {};
          final map = <String, Map<String, dynamic>>{};

          items.forEach((k, v) {
            if (v is Map) {
              map[k.toString()] = Map<String, dynamic>.from(v);
            }
          });

          attendanceByEvent[eventId] = map;
        } catch (_) {
          // тихо игнорируем (по одному event_id могло не загрузиться)
        }
      }));
    }
  }

  Future<void> _prevMonth() async {
    setState(() => month = DateTime(month.year, month.month - 1, 1));
    await _loadAll();
  }

  Future<void> _nextMonth() async {
    setState(() => month = DateTime(month.year, month.month + 1, 1));
    await _loadAll();
  }

  // символы как в твоей таблице
  String _symbolForStatus(String status) {
    switch (status) {
      case "present":
        return "*";
      case "absent":
        return "н";
      case "late":
        return "о";
      case "injured":
        return "т";
      case "individual":
        return "ип";
      case "dayoff":
        return "в";
      default:
        return "*";
    }
  }

  String _statusForCell(int playerId, int eventId) {
    final ev = attendanceByEvent[eventId];
    if (ev == null) return "present";
    final row = ev[playerId.toString()];
    return (row?["status"] ?? "present").toString();
  }

  Future<void> _openCell(int playerId, int day) async {
    final dk = _dateKey(day);
    final list = eventsByDate[dk] ?? const [];
    if (list.isEmpty) return;

    if (list.length == 1) {
      final e = list.first;
      final id = _asInt(e["id"]);
      if (id <= 0) return;
      Get.to(() => TeamAttendanceScreen(
            teamId: widget.teamId,
            teamName: widget.teamName,
            eventId: id,
            eventTitle: _eventTitle(e),
          ));
      return;
    }

    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        top: false,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
          itemCount: list.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final e = list[i];
            return ListTile(
              leading: const CircleAvatar(child: Icon(Icons.event_note_outlined)),
              title: Text(_eventTitle(e), style: const TextStyle(fontWeight: FontWeight.w900)),
              subtitle: Text(dk),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pop(context, e),
            );
          },
        ),
      ),
    );

    if (picked == null) return;
    final id = _asInt(picked["id"]);
    if (id <= 0) return;

    Get.to(() => TeamAttendanceScreen(
          teamId: widget.teamId,
          teamName: widget.teamName,
          eventId: id,
          eventTitle: _eventTitle(picked),
        ));
  }

  @override
  Widget build(BuildContext context) {
    final bg = const Color(0xFFF3F5F8);
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          "Журнал — ${widget.teamName}",
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: "Обновить",
            onPressed: _loadAll,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : (error != null)
              ? SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    error!,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                )
              : _JournalTableSimple(
                  primary: primary,
                  monthTitle: _monthTitle(),
                  onPrev: _prevMonth,
                  onNext: _nextMonth,
                  daysInMonth: _daysInMonth(month),
                  players: players,
                  playerName: _playerName,
                  dateKey: _dateKey,
                  eventsByDate: eventsByDate,
                  statusForCell: _statusForCell,
                  symbolForStatus: _symbolForStatus,
                  onOpenCell: _openCell,
                ),
    );
  }
}

class _JournalTableSimple extends StatelessWidget {
  final Color primary;
  final String monthTitle;
  final Future<void> Function() onPrev;
  final Future<void> Function() onNext;

  final int daysInMonth;
  final List<Map<String, dynamic>> players;
  final String Function(Map<String, dynamic>) playerName;

  final String Function(int day) dateKey;
  final Map<String, List<Map<String, dynamic>>> eventsByDate;

  final String Function(int playerId, int eventId) statusForCell;
  final String Function(String status) symbolForStatus;

  final Future<void> Function(int playerId, int day) onOpenCell;

  const _JournalTableSimple({
    required this.primary,
    required this.monthTitle,
    required this.onPrev,
    required this.onNext,
    required this.daysInMonth,
    required this.players,
    required this.playerName,
    required this.dateKey,
    required this.eventsByDate,
    required this.statusForCell,
    required this.symbolForStatus,
    required this.onOpenCell,
  });

  int _pid(Map<String, dynamic> p) => int.tryParse(p["id"].toString()) ?? 0;
  bool _hasMultipleEvents(String dk) => (eventsByDate[dk]?.length ?? 0) > 1;

  String _cellSymbol(int playerId, String dk) {
    final list = eventsByDate[dk] ?? const [];
    if (list.isEmpty) return "";
    final firstId = int.tryParse(list.first["id"].toString()) ?? 0;
    if (firstId <= 0) return "";
    final st = statusForCell(playerId, firstId);
    return symbolForStatus(st);
  }

  @override
  Widget build(BuildContext context) {
    const nameColW = 210.0;
    const cellW = 44.0;
    const headerH = 44.0;
    const rowH = 44.0;

    Widget headerDay(String t) => Container(
          width: cellW,
          height: headerH,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE8ECF3)),
          ),
          child: Text(
            t,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
          ),
        );

    Widget leftHeader() => Container(
          width: nameColW,
          height: headerH,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE8ECF3)),
          ),
          child: const Text(
            "ФИО",
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
          ),
        );

    Widget leftCell(String t) => Container(
          width: nameColW,
          height: rowH,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE8ECF3)),
          ),
          child: Text(
            t,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
          ),
        );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE8ECF3)),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => onPrev(),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      monthTitle,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => onNext(),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
        ),

        // ✅ Таблица: строго ограничиваем высоту через Expanded на верхнем уровне,
        // а не внутри horizontal scroll
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                // ===== LEFT (ФИО) =====
                SizedBox(
                  width: nameColW,
                  child: Column(
                    children: [
                      leftHeader(),
                      Expanded(
                        child: ListView.builder(
                          itemCount: players.length,
                          itemBuilder: (_, i) => leftCell(playerName(players[i])),
                        ),
                      ),
                    ],
                  ),
                ),

                // ===== RIGHT (ДНИ) =====
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final tableW = cellW * daysInMonth;

                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: tableW,
                          height: constraints.maxHeight, // ✅ ключ: даём высоту!
                          child: Column(
                            children: [
                              // header row
                              SizedBox(
                                height: headerH,
                                child: Row(
                                  children: List.generate(
                                    daysInMonth,
                                    (i) => headerDay("${i + 1}"),
                                  ),
                                ),
                              ),

                              // body
                              Expanded(
                                child: ListView.builder(
                                  itemCount: players.length,
                                  itemBuilder: (_, r) {
                                    final pid = _pid(players[r]);

                                    return SizedBox(
                                      height: rowH,
                                      child: Row(
                                        children: List.generate(daysInMonth, (i) {
                                          final day = i + 1;
                                          final dk = dateKey(day);
                                          final hasAny = (eventsByDate[dk]?.isNotEmpty ?? false);
                                          final multi = _hasMultipleEvents(dk);
                                          final sym = _cellSymbol(pid, dk);

                                          return InkWell(
                                            onTap: hasAny ? () => onOpenCell(pid, day) : null,
                                            child: Container(
                                              width: cellW,
                                              height: rowH,
                                              alignment: Alignment.center,
                                              decoration: BoxDecoration(
                                                color: hasAny ? Colors.white : const Color(0xFFF7F8FB),
                                                border: Border.all(color: const Color(0xFFE8ECF3)),
                                              ),
                                              child: Stack(
                                                alignment: Alignment.center,
                                                children: [
                                                  Text(
                                                    sym,
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.w900,
                                                      fontSize: sym == "ип" ? 11 : 14,
                                                      color: hasAny
                                                          ? const Color(0xFF111827)
                                                          : const Color(0xFF9CA3AF),
                                                    ),
                                                  ),
                                                  if (multi)
                                                    Positioned(
                                                      right: 6,
                                                      top: 6,
                                                      child: Container(
                                                        width: 7,
                                                        height: 7,
                                                        decoration: BoxDecoration(
                                                          color: primary,
                                                          borderRadius: BorderRadius.circular(20),
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          );
                                        }),
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
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
