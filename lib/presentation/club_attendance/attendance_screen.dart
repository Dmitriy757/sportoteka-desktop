// lib/presentation/club_attendance/attendance_screen.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';

class AttendanceScreen extends StatefulWidget {
  final int clubId;
  final String clubName;
  final List<dynamic> teams;

  const AttendanceScreen({
    super.key,
    required this.clubId,
    required this.clubName,
    required this.teams,
  });

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  static const String apiBase = "https://sportotekaapp.ru/api";
  static const String playersUrl = "$apiBase/get_players_by_team.php";
  static const String getTeamEventsUrl = "$apiBase/get_team_events.php";
  static const String getAttendanceUrl = "$apiBase/get_team_attendance.php";
  static const String setAttendanceUrl = "$apiBase/set_team_attendance.php";

  // ✅ пустая ячейка (не отмечено) — как в TeamAttendanceJournalScreen
  static const String kStatusUnset = "unset";

  bool loading = true;
  bool saving = false;
  String? error;

  int userId = 0;

  int? teamId;
  String teamName = "Выберите команду";

  DateTime selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);

  int? selectedEventId;
  String selectedEventTitle = "Все мероприятия";

  List<Map<String, dynamic>> events = [];
  List<Map<String, dynamic>> players = [];

  /// eventId -> (playerIdStr -> {status,note})
  final Map<int, Map<String, Map<String, dynamic>>> attendanceByEvent = {};

  final TextEditingController searchC = TextEditingController();
  String filter = "all";

  /// list | grid | table
  String viewMode = "list";

  Map<String, int> stats = {
    "unset": 0,
    "present": 0,
    "absent": 0,
    "late": 0,
    "injured": 0,
    "individual": 0,
    "dayoff": 0,
    "total": 0,
  };

  // ===== table constants (как в TeamAttendanceJournalScreen) =====
  static const double _tableLeftWidth = 240;
  static const double _tableCellW = 64;
  static const double _tableHeaderH = 56;
  static const double _tableRowH = 76;

  // ===== style =====
  Color get _bg => const Color(0xFFF3F5F8);
  Color get _card => Colors.white;
  Color get _stroke => const Color(0xFFE8ECF3);
  Color get _text => const Color(0xFF111827);
  Color get _muted => const Color(0xFF6B7280);
  Color get _muted2 => const Color(0xFF9CA3AF);
  Color get _chip => const Color(0xFFF3F4F6);

  @override
  void initState() {
    super.initState();
    _initUser();

    searchC.addListener(() {
      if (!mounted) return;
      setState(() {});
    });

    _initDefaultTeam();
    _loadAll();
  }

  Future<void> _initUser() async {
    userId = await PrefUtils.getUserId() ?? 0;
  }

  void _initDefaultTeam() {
    if (widget.teams.isEmpty) return;
    final t0 = Map<String, dynamic>.from(widget.teams.first as Map);
    final id0 = int.tryParse((t0["id"] ?? "0").toString()) ?? 0;
    if (id0 > 0) {
      teamId = id0;
      teamName = (t0["name"] ?? t0["title"] ?? "Команда").toString();
    }
  }

  @override
  void dispose() {
    searchC.dispose();
    super.dispose();
  }

  // ===== helpers =====
  int _daysInMonth(DateTime m) {
    final next = DateTime(m.year, m.month + 1, 1);
    return next.subtract(const Duration(days: 1)).day;
  }

  String _monthTitle() {
    const ru = [
      "Январь",
      "Февраль",
      "Март",
      "Апрель",
      "Май",
      "Июнь",
      "Июль",
      "Август",
      "Сентябрь",
      "Октябрь",
      "Ноябрь",
      "Декабрь"
    ];
    return "${ru[selectedMonth.month - 1]} ${selectedMonth.year}";
  }

  String _eventTitle(Map<String, dynamic> e) {
    final t = (e["title"] ?? "").toString().trim();
    final n = (e["name"] ?? "").toString().trim();
    return t.isNotEmpty ? t : (n.isNotEmpty ? n : "Мероприятие");
  }

  String _prettyDate(String iso) {
    if (iso.length < 10) return iso;
    final d = iso.substring(8, 10);
    final m = iso.substring(5, 7);
    return "$d.$m";
  }

  String _prettyTime(Map<String, dynamic> e) {
    final s = (e["start_at"] ?? e["event_date"] ?? "").toString().trim();
    if (s.length < 16) return "";
    return s.substring(11, 16);
  }

  String _eventDateLabel(Map<String, dynamic> e) {
    final iso = (e["start_at"] ?? e["event_date"] ?? "").toString();
    final d = _prettyDate(iso);
    final t = _prettyTime(e);
    return t.isNotEmpty ? "$d\n$t" : d;
  }

  String? _getPhotoUrl(Map<String, dynamic> player) {
    final photoUrl = (player["photo"] ?? player["photo_url"] ?? player["avatar"] ?? "").toString();
    if (photoUrl.isEmpty) return null;

    if (photoUrl.startsWith('http')) return photoUrl;
    if (photoUrl.startsWith('/')) return "https://sportotekaapp.ru${photoUrl.replaceAll('//', '/')}";

    return "https://sportotekaapp.ru/uploads/$photoUrl";
  }

  void _preloadImage(String url) {
    if (!mounted) return;
    precacheImage(NetworkImage(url), context).catchError((_) {});
  }

  String _playerName(Map<String, dynamic> p) {
    final fullName = p["fullName"]?.toString().trim();
    if (fullName?.isNotEmpty == true) return fullName!;

    final firstName = p["first_name"]?.toString().trim() ?? "";
    final lastName = p["last_name"]?.toString().trim() ?? "";
    final merged = "$lastName $firstName".trim();
    return merged.isEmpty ? "Игрок" : merged;
  }

  // ===== загрузка =====
  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      saving = false;
      error = null;

      players = [];
      events = [];
      attendanceByEvent.clear();

      selectedEventId = null;
      selectedEventTitle = "Все мероприятия";
    });

    try {
      if (teamId == null || (teamId ?? 0) <= 0) {
        throw Exception("Выберите команду");
      }

      await Future.wait([
        _fetchPlayers(),
        _fetchEventsForMonth(),
      ]);

      await _fetchAttendanceForEvents();
      _calculateStats();
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    }

    if (!mounted) return;
    setState(() => loading = false);
  }

  Future<void> _fetchPlayers() async {
    final uri = Uri.parse(playersUrl).replace(queryParameters: {
      "team_id": teamId.toString(),
    });
    final res = await http.get(uri);
    final data = jsonDecode(res.body);

    if (data["status"] != "success") {
      throw Exception(data["message"]?.toString() ?? "Не удалось загрузить игроков");
    }

    final list = (data["players"] as List?) ?? [];
    players = list.map((e) => Map<String, dynamic>.from(e)).toList();

    players.sort((a, b) => _playerName(a).toLowerCase().compareTo(_playerName(b).toLowerCase()));

    for (final p in players) {
      final url = _getPhotoUrl(p);
      if (url != null) _preloadImage(url);
    }
  }

  Future<void> _fetchEventsForMonth() async {
    final from = "${selectedMonth.year}-${selectedMonth.month.toString().padLeft(2, '0')}-01";
    final lastDay = _daysInMonth(selectedMonth);
    final to = "${selectedMonth.year}-${selectedMonth.month.toString().padLeft(2, '0')}-${lastDay.toString().padLeft(2, '0')}";

    final uri = Uri.parse(getTeamEventsUrl).replace(queryParameters: {
      "team_id": teamId.toString(),
      "from": from,
      "to": to,
    });

    final res = await http.get(uri);
    final data = jsonDecode(res.body);

    if (data["success"] != true && data["status"] != "success") {
      throw Exception(data["message"]?.toString() ?? "Не удалось загрузить мероприятия");
    }

    final list = (data["items"] as List? ?? data["events"] as List? ?? []);
    events = list.map((e) => Map<String, dynamic>.from(e)).toList();
    events.sort((a, b) => (a["start_at"] ?? "").compareTo(b["start_at"] ?? ""));
  }

  Future<void> _fetchAttendanceForEvents() async {
    if (events.isEmpty) return;

    const batchSize = 5;
    for (int i = 0; i < events.length; i += batchSize) {
      final batch = events.skip(i).take(batchSize).toList();
      await Future.wait(batch.map((e) async {
        final eventId = int.tryParse(e["id"]?.toString() ?? "0") ?? 0;
        if (eventId <= 0) return;

        try {
          final uri = Uri.parse(getAttendanceUrl).replace(queryParameters: {
            "event_id": eventId.toString(),
          });
          final res = await http.get(uri);
          final data = jsonDecode(res.body);

          if (data["success"] == true) {
            final items = (data["items"] as Map?) ?? {};
            attendanceByEvent[eventId] =
                items.map((k, v) => MapEntry(k.toString(), Map<String, dynamic>.from(v)));
          }
        } catch (_) {}
      }));
    }
  }

  // ===== статусы (как в TeamAttendanceJournalScreen) =====
  String _getStatusSymbol(String status) {
    switch (status) {
      case kStatusUnset:
        return "";
      case "absent":
        return "Н";
      case "late":
        return "Б";
      case "injured":
        return "Т";
      case "individual":
        return "И";
      case "dayoff":
        return "В";
      case "present":
        return "П";
      default:
        return "";
    }
  }

  String _getStatusFullText(String status) {
    switch (status) {
      case kStatusUnset:
        return "";
      case "absent":
        return "Отсутствует";
      case "late":
        return "Болен";
      case "injured":
        return "Травма";
      case "individual":
        return "Индивид.";
      case "dayoff":
        return "Выходной";
      case "present":
        return "Присутствует";
      default:
        return "";
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case kStatusUnset:
        return const Color(0xFFCBD5E1);
      case "absent":
        return const Color(0xFFEF4444);
      case "late":
        return const Color(0xFFF59E0B);
      case "injured":
        return const Color(0xFF8B5CF6);
      case "individual":
        return const Color(0xFF0EA5E9);
      case "dayoff":
        return const Color(0xFF9CA3AF);
      case "present":
        return const Color(0xFF22C55E);
      default:
        return const Color(0xFFCBD5E1);
    }
  }

  String _getStatusForEvent(int playerId, int eventId) {
    final eventAttendance = attendanceByEvent[eventId];
    if (eventAttendance == null) return kStatusUnset;

    final playerData = eventAttendance[playerId.toString()];
    if (playerData == null) return kStatusUnset;

    final raw = (playerData["status"] ?? "").toString().trim();
    if (raw.isEmpty) return kStatusUnset;

    return raw;
  }

  String _getAggregatedStatus(int playerId) {
  if (events.isEmpty) return kStatusUnset;

  bool hasAnyMark = false;

  // 1) самый жёсткий приоритет
  for (final event in events) {
    final eventId = int.tryParse(event["id"]?.toString() ?? "0") ?? 0;
    final status = _getStatusForEvent(playerId, eventId);
    if (status != kStatusUnset) hasAnyMark = true;
    if (status == "absent") return "absent";
  }

  // 2) потом особые статусы (кроме present)
  for (final event in events) {
    final eventId = int.tryParse(event["id"]?.toString() ?? "0") ?? 0;
    final status = _getStatusForEvent(playerId, eventId);
    if (status != kStatusUnset) hasAnyMark = true;
    if (status != kStatusUnset && status != "present") return status;
  }

  // 3) если вообще где-то был present — present
  for (final event in events) {
    final eventId = int.tryParse(event["id"]?.toString() ?? "0") ?? 0;
    final status = _getStatusForEvent(playerId, eventId);
    if (status == "present") return "present";
  }

  // 4) иначе либо ничего, либо есть отметки, но все "unset" (редко)
  return hasAnyMark ? kStatusUnset : kStatusUnset;
}

  // ===== сохранение статуса =====
  Future<void> _setStatusForEvent(int eventId, int playerId, String status) async {
    final markedBy = await PrefUtils.getUserId() ?? 0;

    if (!mounted) return;
    setState(() => saving = true);

    // на сервер отправляем "" чтобы очистить
    final sendStatus = (status == kStatusUnset) ? "" : status;

    try {
      attendanceByEvent.putIfAbsent(eventId, () => {});

      // локально тоже чистим/ставим как в журнале
      if (status == kStatusUnset) {
        attendanceByEvent[eventId]!.remove(playerId.toString());
      } else {
        attendanceByEvent[eventId]![playerId.toString()] = {
          "status": status,
          "note": attendanceByEvent[eventId]?[playerId.toString()]?["note"] ?? "",
        };
      }

      final res = await http.post(
        Uri.parse(setAttendanceUrl),
        body: {
          "team_id": teamId.toString(),
          "event_id": eventId.toString(),
          "player_id": playerId.toString(),
          "status": sendStatus,
          "note": (attendanceByEvent[eventId]?[playerId.toString()]?["note"] ?? "").toString(),
          "marked_by": markedBy.toString(),
        },
      );

      final data = jsonDecode(res.body);
      if (data["success"] != true) {
        Get.snackbar("Ошибка", data["message"]?.toString() ?? "Не удалось сохранить");
      }

      _calculateStats();
    } catch (_) {
      Get.snackbar("Ошибка сети", "Не удалось сохранить статус");
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _setStatus(int playerId, String status) async {
    if (selectedEventId == null) {
      Get.snackbar("Внимание", "Выберите конкретное мероприятие для отметки");
      return;
    }
    await _setStatusForEvent(selectedEventId!, playerId, status);
    final t = _getStatusFullText(status);
    Get.snackbar("Готово", t.isEmpty ? "Статус очищен" : "Статус обновлён: $t");
  }

  void _calculateStats() {
    final newStats = {
      "unset": 0,
      "present": 0,
      "absent": 0,
      "late": 0,
      "injured": 0,
      "individual": 0,
      "dayoff": 0,
      "total": players.length,
    };

    if (selectedEventId == null) {
      for (final player in players) {
        final playerId = int.tryParse(player["id"]?.toString() ?? "0") ?? 0;
        final status = _getAggregatedStatus(playerId);
        newStats[status] = (newStats[status] ?? 0) + 1;
      }
    } else {
      for (final player in players) {
        final playerId = int.tryParse(player["id"]?.toString() ?? "0") ?? 0;
        final status = _getStatusForEvent(playerId, selectedEventId!);
        newStats[status] = (newStats[status] ?? 0) + 1;
      }
    }

    if (!mounted) return;
    setState(() => stats = newStats);
  }

  List<Map<String, dynamic>> get _filteredPlayers {
    final query = searchC.text.trim().toLowerCase();

    return players.where((player) {
      final playerId = int.tryParse(player["id"]?.toString() ?? "0") ?? 0;
      final status = selectedEventId == null
          ? _getAggregatedStatus(playerId)
          : _getStatusForEvent(playerId, selectedEventId!);

      if (filter != "all" && status != filter) return false;

      if (query.isNotEmpty) {
        final name = _playerName(player).toLowerCase();
        final number = (player["number"] ?? "").toString().toLowerCase();
        final position = (player["position"] ?? "").toString().toLowerCase();
        if (!name.contains(query) && !number.contains(query) && !position.contains(query)) return false;
      }

      return true;
    }).toList();
  }

  // ===== экспорт CSV =====
  Future<void> _exportCsv() async {
    if (players.isEmpty) {
      Get.snackbar("Пусто", "Нет данных для экспорта");
      return;
    }

    try {
      final buffer = StringBuffer();
      buffer.writeln('Клуб,Команда,Мероприятие,Игрок ID,ФИО,Номер,Позиция,Статус,Дата');

      for (final player in players) {
        final playerId = int.tryParse(player["id"]?.toString() ?? "0") ?? 0;
        final name = _playerName(player);
        final number = (player["number"] ?? "").toString();
        final position = (player["position"] ?? "").toString();

        String status = kStatusUnset;
        String eventDate = "";

        if (selectedEventId == null) {
          status = _getAggregatedStatus(playerId);
          eventDate = "${selectedMonth.year}-${selectedMonth.month.toString().padLeft(2, '0')}";
        } else {
          status = _getStatusForEvent(playerId, selectedEventId!);
          final event = events.firstWhere(
            (e) => (int.tryParse(e["id"]?.toString() ?? "0") ?? 0) == selectedEventId,
            orElse: () => {},
          );
          eventDate = (event["start_at"] ?? event["event_date"] ?? "").toString();
        }

        buffer.writeln([
          _escapeCsv(widget.clubName),
          _escapeCsv(teamName),
          _escapeCsv(selectedEventTitle),
          playerId,
          _escapeCsv(name),
          _escapeCsv(number),
          _escapeCsv(position),
          _escapeCsv(status == kStatusUnset ? "Не отмечено" : _getStatusFullText(status)),
          _escapeCsv(eventDate),
        ].join(','));
      }

      final dir = await getTemporaryDirectory();
      final safeClub = widget.clubName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final safeTeam = teamName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final file = File('${dir.path}/посещаемость_${safeClub}_${safeTeam}_${DateTime.now().millisecondsSinceEpoch}.csv');

      await file.writeAsString(buffer.toString(), flush: true, encoding: utf8);
      await Share.shareXFiles([XFile(file.path, mimeType: 'text/csv')], subject: 'Посещаемость — $safeTeam');
    } catch (_) {
      Get.snackbar("Ошибка", "Не удалось экспортировать CSV");
    }
  }

  String _escapeCsv(String s) {
    final v = s.replaceAll('\r', ' ').replaceAll('\n', ' ').trim();
    final needQuotes = v.contains(',') || v.contains('"') || v.contains(';');
    final escaped = v.replaceAll('"', '""');
    return needQuotes ? '"$escaped"' : escaped;
  }

  // ===== выбор статуса =====
  Future<void> _showStatusSelector(
    BuildContext context,
    int playerId,
    String currentStatus, {
    int? overrideEventId,
  }) async {
    final statuses = [
      {
        "code": kStatusUnset,
        "label": "Очистить",
        "symbol": "—",
        "color": const Color(0xFF64748B),
      },
      {"code": "present", "label": "Присутствует", "symbol": "П", "color": const Color(0xFF22C55E)},
      {"code": "absent", "label": "Отсутствует", "symbol": "Н", "color": const Color(0xFFEF4444)},
      {"code": "late", "label": "Болен", "symbol": "Б", "color": const Color(0xFFF59E0B)},
      {"code": "injured", "label": "Травма", "symbol": "Т", "color": const Color(0xFF8B5CF6)},
      {"code": "individual", "label": "Индивид.", "symbol": "И", "color": const Color(0xFF0EA5E9)},
      {"code": "dayoff", "label": "Выходной", "symbol": "В", "color": const Color(0xFF9CA3AF)},
    ];

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 16),
                const Text(
                  "Выберите статус",
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF111827)),
                ),
                const SizedBox(height: 16),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.2,
                  ),
                  itemCount: statuses.length,
                  itemBuilder: (context, index) {
                    final s = statuses[index];
                    final isActive = s["code"] == currentStatus;
                    final color = s["color"] as Color;

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () async {
                          Navigator.pop(context);
                          final code = s["code"] as String;

                          if (overrideEventId != null) {
                            await _setStatusForEvent(overrideEventId, playerId, code);
                            final t = _getStatusFullText(code);
                            Get.snackbar("Готово", t.isEmpty ? "Статус очищен" : "Статус обновлён: $t");
                          } else {
                            await _setStatus(playerId, code);
                          }
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: isActive ? color.withOpacity(0.15) : color.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isActive ? color : color.withOpacity(0.3), width: isActive ? 2 : 1),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(color: isActive ? color : color.withOpacity(0.10), shape: BoxShape.circle),
                                child: Center(
                                  child: Text(
                                    s["symbol"] as String,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                      color: isActive ? Colors.white : color,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                s["label"] as String,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: color),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  // ===== UI atoms =====
  Widget _cardBox({required Widget child, EdgeInsets padding = const EdgeInsets.all(16)}) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _stroke),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 8))],
      ),
      child: child,
    );
  }

  Widget _avatarWithNumber({
    required String? photoUrl,
    required String number,
    required Color accent,
    double size = 48,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(size * 0.34),
              border: Border.all(color: accent.withOpacity(0.25), width: 2),
              color: accent.withOpacity(0.10),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(size * 0.30),
              child: photoUrl != null
                  ? Image.network(
                      photoUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Center(child: Icon(PhosphorIcons.user(PhosphorIconsStyle.bold), size: size * 0.45, color: accent)),
                    )
                  : Center(child: Icon(PhosphorIcons.user(PhosphorIconsStyle.bold), size: size * 0.45, color: accent)),
            ),
          ),
          if (number.isNotEmpty)
            Positioned(
              right: -6,
              bottom: -6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Text(
                  "№$number",
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ===== selectors =====
  Widget _buildTeamSelector() {
    final canSelect = widget.teams.isNotEmpty;

    return _cardBox(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.18)),
            ),
            child: Icon(PhosphorIcons.usersThree(PhosphorIconsStyle.bold), color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Команда", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: _muted)),
                const SizedBox(height: 6),
                Text(
                  teamName,
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: _text),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (!canSelect)
            Text("Нет команд", style: TextStyle(color: _muted2, fontWeight: FontWeight.w700))
          else
            IconButton(
              onPressed: _openTeamPicker,
              icon: Icon(PhosphorIcons.caretDown(PhosphorIconsStyle.bold)),
              style: IconButton.styleFrom(
                backgroundColor: _chip,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
        ],
      ),
    );
  }

  void _openTeamPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                const Text("Выберите команду", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF111827))),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView.builder(
                    itemCount: widget.teams.length,
                    itemBuilder: (context, index) {
                      final t = Map<String, dynamic>.from(widget.teams[index] as Map);
                      final id = int.tryParse((t["id"] ?? "0").toString()) ?? 0;
                      final name = (t["name"] ?? t["title"] ?? "Команда").toString();
                      final isSel = id == teamId;

                      return ListTile(
                        title: Text(
                          name,
                          style: TextStyle(fontWeight: FontWeight.w800, color: isSel ? Theme.of(context).colorScheme.primary : _text),
                        ),
                        trailing: isSel ? Icon(PhosphorIcons.check(PhosphorIconsStyle.bold), color: Theme.of(context).colorScheme.primary) : null,
                        onTap: () {
                          Navigator.pop(context);
                          if (id <= 0) return;

                          setState(() {
                            teamId = id;
                            teamName = name;
                            selectedEventId = null;
                            selectedEventTitle = "Все мероприятия";
                          });

                          _loadAll();
                        },
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

  Widget _buildMonthSelector() {
    return _cardBox(
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              setState(() {
                selectedMonth = DateTime(selectedMonth.year, selectedMonth.month - 1, 1);
                selectedEventId = null;
                selectedEventTitle = "Все мероприятия";
              });
              _loadAll();
            },
            icon: Icon(PhosphorIcons.caretLeft(PhosphorIconsStyle.bold)),
            style: IconButton.styleFrom(
              backgroundColor: _chip,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Text(_monthTitle(), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: _text)),
                const SizedBox(height: 6),
                Text("${events.length} мероприятий", style: TextStyle(fontSize: 13, color: _muted, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                selectedMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 1);
                selectedEventId = null;
                selectedEventTitle = "Все мероприятия";
              });
              _loadAll();
            },
            icon: Icon(PhosphorIcons.caretRight(PhosphorIconsStyle.bold)),
            style: IconButton.styleFrom(
              backgroundColor: _chip,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventSelector() {
    if (events.isEmpty) return const SizedBox();

    final eventColor = selectedEventId == null ? _muted : Theme.of(context).colorScheme.primary;

    return _cardBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(PhosphorIcons.calendar(PhosphorIconsStyle.bold), size: 20, color: eventColor),
              const SizedBox(width: 8),
              Text("Мероприятие", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: eventColor)),
            ],
          ),
          const SizedBox(height: 12),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _openEventPicker,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Row(
                  children: [
                    Icon(
                      selectedEventId == null
                          ? PhosphorIcons.calendarBlank(PhosphorIconsStyle.bold)
                          : PhosphorIcons.calendarCheck(PhosphorIconsStyle.bold),
                      color: eventColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selectedEventTitle,
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: eventColor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (selectedEventId != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              "Выбрано для отметки",
                              style: TextStyle(fontSize: 12, color: eventColor.withOpacity(0.7), fontWeight: FontWeight.w700),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Icon(PhosphorIcons.caretDown(PhosphorIconsStyle.bold), color: eventColor),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openEventPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                const Text("Выберите мероприятие", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Color(0xFF111827))),
                const SizedBox(height: 16),
                ListTile(
                  leading: Icon(
                    PhosphorIcons.calendarBlank(PhosphorIconsStyle.bold),
                    color: selectedEventId == null ? Theme.of(context).colorScheme.primary : _muted,
                  ),
                  title: const Text("Все мероприятия месяца", style: TextStyle(fontWeight: FontWeight.w800)),
                  trailing: selectedEventId == null
                      ? Icon(PhosphorIcons.check(PhosphorIconsStyle.bold), color: Theme.of(context).colorScheme.primary)
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      selectedEventId = null;
                      selectedEventTitle = "Все мероприятия";
                      _calculateStats();
                    });
                  },
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    itemCount: events.length,
                    itemBuilder: (context, index) {
                      final event = events[index];
                      final id = int.tryParse(event["id"]?.toString() ?? "0") ?? 0;
                      final title = _eventTitle(event);
                      final date = _prettyDate((event["start_at"] ?? event["event_date"] ?? "").toString());
                      final time = _prettyTime(event);
                      final isSel = selectedEventId == id;

                      return ListTile(
                        leading: Icon(
                          PhosphorIcons.calendarCheck(PhosphorIconsStyle.bold),
                          color: isSel ? Theme.of(context).colorScheme.primary : _muted,
                        ),
                        title: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: FontWeight.w800, color: isSel ? Theme.of(context).colorScheme.primary : _text),
                        ),
                        subtitle: Text("$date ${time.isNotEmpty ? '· $time' : ''}", style: TextStyle(fontWeight: FontWeight.w700, color: _muted)),
                        trailing: isSel ? Icon(PhosphorIcons.check(PhosphorIconsStyle.bold), color: Theme.of(context).colorScheme.primary) : null,
                        onTap: () {
                          Navigator.pop(context);
                          setState(() {
                            selectedEventId = id;
                            selectedEventTitle = title;
                            _calculateStats();
                          });
                        },
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

  // ===== stats =====
  Widget _buildStatsBar() {
    return _cardBox(
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.1,
        children: [
          _buildStatBadge(count: stats["unset"] ?? 0, color: const Color(0xFF64748B), label: "Не отм.", symbol: "—"),
          _buildStatBadge(count: stats["present"] ?? 0, color: const Color(0xFF22C55E), label: "Присут.", symbol: "П"),
          _buildStatBadge(count: stats["absent"] ?? 0, color: const Color(0xFFEF4444), label: "Отсут.", symbol: "Н"),
          _buildStatBadge(count: stats["late"] ?? 0, color: const Color(0xFFF59E0B), label: "Болен", symbol: "Б"),
          _buildStatBadge(count: stats["injured"] ?? 0, color: const Color(0xFF8B5CF6), label: "Травма", symbol: "Т"),
          _buildStatBadge(count: stats["individual"] ?? 0, color: const Color(0xFF0EA5E9), label: "Инд.", symbol: "И"),
          _buildStatBadge(count: stats["dayoff"] ?? 0, color: const Color(0xFF9CA3AF), label: "Выходн.", symbol: "В"),
          _buildStatBadge(count: _filteredPlayers.length, color: _text, label: "Показано", symbol: "👥", isPlayers: true),
          _buildStatBadge(count: players.length, color: _text, label: "Всего", symbol: "Σ", isTotal: true),
        ],
      ),
    );
  }

  Widget _buildStatBadge({
    required int count,
    required Color color,
    required String label,
    required String symbol,
    bool isPlayers = false,
    bool isTotal = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
            child: Center(
              child: Text(
                isPlayers || isTotal ? "$count" : symbol,
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: (isPlayers || isTotal) ? 14 : 15, color: color),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color)),
        ],
      ),
    );
  }

  // ===== search/filters/view =====
  Widget _buildSearchAndFilters() {
    IconData viewIcon;
    if (viewMode == "list") {
      viewIcon = PhosphorIcons.squaresFour(PhosphorIconsStyle.bold);
    } else if (viewMode == "grid") {
      viewIcon = PhosphorIcons.table(PhosphorIconsStyle.bold);
    } else {
      viewIcon = PhosphorIcons.list(PhosphorIconsStyle.bold);
    }

    return Row(
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _stroke),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 6))],
            ),
            child: TextField(
              controller: searchC,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: "Поиск игрока...",
                prefixIcon: Icon(PhosphorIcons.magnifyingGlass(PhosphorIconsStyle.bold)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Material(
          color: Colors.transparent,
          child: PopupMenuButton<String>(
            onSelected: (value) => setState(() => filter = value),
            itemBuilder: (_) => [
              const PopupMenuItem(value: "all", child: Text("Все статусы")),
              PopupMenuItem(value: kStatusUnset, child: const Text("Не отмечено (—)")),
              const PopupMenuItem(value: "present", child: Text("Присутствует (П)")),
              const PopupMenuItem(value: "absent", child: Text("Отсутствует (Н)")),
              const PopupMenuItem(value: "late", child: Text("Болен (Б)")),
              const PopupMenuItem(value: "injured", child: Text("Травма (Т)")),
              const PopupMenuItem(value: "individual", child: Text("Индивид. (И)")),
              const PopupMenuItem(value: "dayoff", child: Text("Выходной (В)")),
            ],
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _stroke),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 6))],
              ),
              child: Icon(
                PhosphorIcons.funnel(PhosphorIconsStyle.bold),
                color: filter == "all" ? _muted : _getStatusColor(filter),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              setState(() {
                if (viewMode == "list") {
                  viewMode = "grid";
                } else if (viewMode == "grid") {
                  viewMode = "table";
                } else {
                  viewMode = "list";
                }
              });
            },
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _stroke),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 6))],
              ),
              child: Icon(viewIcon, color: Theme.of(context).colorScheme.primary),
            ),
          ),
        ),
      ],
    );
  }

  // ===== players UI =====
  Widget _buildPlayerList() {
    final filtered = _filteredPlayers;

    if (filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(PhosphorIcons.users(PhosphorIconsStyle.bold), size: 72, color: const Color(0xFFD1D5DB)),
            const SizedBox(height: 16),
            Text("Игроки не найдены", style: TextStyle(color: _muted, fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 8),
            Text("Попробуйте изменить поиск или фильтр", style: TextStyle(color: _muted2, fontSize: 14), textAlign: TextAlign.center),
          ],
        ),
      );
    }

    if (viewMode == "table") return _buildAttendanceTable(filtered);
    if (viewMode == "grid") return _buildPlayerGrid(filtered);
    return _buildPlayerListView(filtered);
  }

  Widget _buildPlayerListView(List<Map<String, dynamic>> filteredPlayers) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filteredPlayers.length,
      itemBuilder: (context, index) => _buildPlayerCardList(filteredPlayers[index]),
    );
  }

  Widget _buildPlayerCardList(Map<String, dynamic> player) {
    final playerId = int.tryParse(player["id"]?.toString() ?? "0") ?? 0;
    final name = _playerName(player);
    final number = (player["number"] ?? "").toString();
    final position = (player["position"] ?? "").toString();
    final photoUrl = _getPhotoUrl(player);

    final status = selectedEventId == null ? _getAggregatedStatus(playerId) : _getStatusForEvent(playerId, selectedEventId!);
    final statusSymbol = _getStatusSymbol(status);
    final statusColor = _getStatusColor(status);
    final statusFullText = _getStatusFullText(status);

    const double rightColW = 92;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _stroke),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 8))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: selectedEventId != null ? () => _showStatusSelector(context, playerId, status) : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _avatarWithNumber(photoUrl: photoUrl, number: number, accent: statusColor, size: 58),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: _text),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      if (position.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: _chip, borderRadius: BorderRadius.circular(12)),
                          child: Text(
                            position,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF374151)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        )
                      else
                        const SizedBox(height: 28),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: rightColW,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (status != kStatusUnset) ...[
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.12),
                            shape: BoxShape.circle,
                            border: Border.all(color: statusColor, width: 2),
                          ),
                          child: Center(
                            child: Text(
                              statusSymbol,
                              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: statusColor),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          statusFullText,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: statusColor),
                        ),
                      ] else ...[
                        // ✅ пустой круг — чтобы был виден полностью
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFCBD5E1), width: 2),
                            color: Colors.transparent,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===== GRID =====
  Widget _buildPlayerGrid(List<Map<String, dynamic>> filteredPlayers) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: filteredPlayers.length,
      itemBuilder: (context, index) => _buildPlayerCardGrid(filteredPlayers[index]),
    );
  }

  Widget _buildPlayerCardGrid(Map<String, dynamic> player) {
    final playerId = int.tryParse(player["id"]?.toString() ?? "0") ?? 0;
    final name = _playerName(player);
    final number = (player["number"] ?? "").toString();
    final position = (player["position"] ?? "").toString();
    final photoUrl = _getPhotoUrl(player);

    final status = selectedEventId == null ? _getAggregatedStatus(playerId) : _getStatusForEvent(playerId, selectedEventId!);
    final statusSymbol = _getStatusSymbol(status);
    final statusColor = _getStatusColor(status);
    final statusFullText = _getStatusFullText(status);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: selectedEventId != null ? () => _showStatusSelector(context, playerId, status) : null,
        child: Container(
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _stroke),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 6))],
          ),
          child: Column(
            children: [
              Stack(
                children: [
                  Container(
                    height: 120,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          statusColor.withOpacity(0.10),
                          statusColor.withOpacity(0.04),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: _avatarWithNumber(photoUrl: photoUrl, number: number, accent: statusColor, size: 82),
                      ),
                    ),
                  ),
                  if (status != kStatusUnset)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 8, offset: const Offset(0, 4))],
                        ),
                        child: Center(
                          child: Text(statusSymbol, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.white)),
                        ),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: _text, height: 1.2),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    if (position.isNotEmpty)
                      Text(
                        position,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _muted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 6),
                    if (status != kStatusUnset)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: statusColor.withOpacity(0.10), borderRadius: BorderRadius.circular(10)),
                        child: Text(statusFullText, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: statusColor)),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFCBD5E1), width: 1),
                        ),
                        child: const Text(
                          "Не отмечено",
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B)),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===== TABLE =====
  Widget _buildAttendanceTable(List<Map<String, dynamic>> filteredPlayers) {
    if (events.isEmpty) {
      return _cardBox(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(PhosphorIcons.info(PhosphorIconsStyle.bold), color: _muted),
            const SizedBox(width: 10),
            Expanded(
              child: Text("В этом месяце нет мероприятий — таблица пустая.", style: TextStyle(color: _muted, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
    }

    final right = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: events.length * _tableCellW,
        child: Column(
          children: [
            _buildTableHeaderRight(),
            ...filteredPlayers.map(_buildTableRowRight).toList(),
          ],
        ),
      ),
    );

    final left = SizedBox(
      width: _tableLeftWidth,
      child: Column(
        children: [
          _buildTableHeaderLeft(),
          ...filteredPlayers.map(_buildTableRowLeft).toList(),
        ],
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _stroke),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 8))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SingleChildScrollView(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              left,
              const VerticalDivider(width: 1, thickness: 1, color: Color(0xFFE8ECF3)),
              Expanded(child: right),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTableHeaderLeft() {
    return Container(
      height: _tableHeaderH,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF9FAFB),
        border: Border(bottom: BorderSide(color: Color(0xFFE8ECF3))),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text("Игрок", style: TextStyle(fontWeight: FontWeight.w900, color: _text)),
      ),
    );
  }

  Widget _buildTableHeaderRight() {
    return Container(
      height: _tableHeaderH,
      decoration: const BoxDecoration(
        color: Color(0xFFF9FAFB),
        border: Border(bottom: BorderSide(color: Color(0xFFE8ECF3))),
      ),
      child: Row(
        children: List.generate(events.length, (i) {
          final e = events[i];
          final id = int.tryParse(e["id"]?.toString() ?? "0") ?? 0;
          final isSel = selectedEventId == id;

          return InkWell(
            onTap: () {
              setState(() {
                selectedEventId = id;
                selectedEventTitle = _eventTitle(e);
                _calculateStats();
              });
            },
            child: Container(
              width: _tableCellW,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
              decoration: BoxDecoration(
                color: isSel ? Theme.of(context).colorScheme.primary.withOpacity(0.08) : Colors.transparent,
                border: Border(right: BorderSide(color: _stroke.withOpacity(0.9))),
              ),
              child: Center(
                child: Text(
                  _eventDateLabel(e),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: isSel ? Theme.of(context).colorScheme.primary : _text,
                    height: 1.05,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildTableRowLeft(Map<String, dynamic> player) {
    final playerId = int.tryParse(player["id"]?.toString() ?? "0") ?? 0;
    final name = _playerName(player);
    final number = (player["number"] ?? "").toString();
    final position = (player["position"] ?? "").toString();
    final photoUrl = _getPhotoUrl(player);

    final aggStatus = _getAggregatedStatus(playerId);
    final aggColor = _getStatusColor(aggStatus);

    return Container(
      height: _tableRowH,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE8ECF3)))),
      child: Row(
        children: [
          _avatarWithNumber(photoUrl: photoUrl, number: number, accent: aggColor, size: 48),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: _text),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (position.isNotEmpty)
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: _chip, borderRadius: BorderRadius.circular(12)),
                          child: Text(
                            position,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF374151)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                    else
                      const SizedBox(height: 26),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableRowRight(Map<String, dynamic> player) {
    final playerId = int.tryParse(player["id"]?.toString() ?? "0") ?? 0;

    return Container(
      height: _tableRowH,
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFE8ECF3)))),
      child: Row(
        children: List.generate(events.length, (i) {
          final e = events[i];
          final eventId = int.tryParse(e["id"]?.toString() ?? "0") ?? 0;

          final status = _getStatusForEvent(playerId, eventId);
          final symbol = _getStatusSymbol(status);
          final color = _getStatusColor(status);
          final isUnset = status == kStatusUnset;

          return InkWell(
            onTap: () => _showStatusSelector(context, playerId, status, overrideEventId: eventId),
            child: Container(
              width: _tableCellW,
              decoration: BoxDecoration(border: Border(right: BorderSide(color: _stroke.withOpacity(0.9)))),
              child: Center(
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: isUnset ? Colors.transparent : color.withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isUnset ? const Color(0xFFCBD5E1) : color.withOpacity(0.65),
                    ),
                  ),
                  child: Center(
                    child: isUnset
                        ? const SizedBox()
                        : Text(symbol, style: TextStyle(fontWeight: FontWeight.w900, color: color)),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ===== build =====
  @override
  Widget build(BuildContext context) {
    final viewLabel = viewMode == "list" ? "Список" : viewMode == "grid" ? "Сетка" : "Таблица";

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          "Журнал посещений — ${widget.clubName}",
          style: const TextStyle(fontWeight: FontWeight.w900),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (saving)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            ),
          IconButton(
            onPressed: _loadAll,
            icon: Icon(PhosphorIcons.arrowClockwise(PhosphorIconsStyle.bold)),
            tooltip: "Обновить",
          ),
          IconButton(
            onPressed: _exportCsv,
            icon: Icon(PhosphorIcons.fileCsv(PhosphorIconsStyle.bold)),
            tooltip: "Экспорт CSV",
          ),
        ],
      ),
      body: loading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text("Загрузка данных...", style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w700)),
                ],
              ),
            )
          : error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(PhosphorIcons.warningCircle(PhosphorIconsStyle.bold), size: 64, color: const Color(0xFFEF4444)),
                        const SizedBox(height: 16),
                        Text(error!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w700)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadAll,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF111827),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                          child: const Text("Повторить", style: TextStyle(fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildTeamSelector(),
                      const SizedBox(height: 16),
                      _buildMonthSelector(),
                      const SizedBox(height: 16),
                      _buildEventSelector(),
                      const SizedBox(height: 16),
                      _buildStatsBar(),
                      const SizedBox(height: 16),
                      _buildSearchAndFilters(),
                      const SizedBox(height: 20),
                      if (selectedEventId == null && viewMode != "table")
                        Container(
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(PhosphorIcons.info(PhosphorIconsStyle.bold), color: const Color(0xFFF59E0B)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("Выберите мероприятие",
                                        style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF92400E))),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Для отметки посещаемости выберите конкретное мероприятие выше (или включите Таблица — там отмечается по ячейкам).",
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: const Color(0xFF92400E).withOpacity(0.8),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Игроки (${_filteredPlayers.length})",
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _text)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: _chip, borderRadius: BorderRadius.circular(20)),
                            child: Row(
                              children: [
                                Icon(
                                  viewMode == "list"
                                      ? PhosphorIcons.list(PhosphorIconsStyle.bold)
                                      : viewMode == "grid"
                                          ? PhosphorIcons.squaresFour(PhosphorIconsStyle.bold)
                                          : PhosphorIcons.table(PhosphorIconsStyle.bold),
                                  size: 14,
                                  color: _muted,
                                ),
                                const SizedBox(width: 6),
                                Text(viewLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _muted)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildPlayerList(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
    );
  }
}
