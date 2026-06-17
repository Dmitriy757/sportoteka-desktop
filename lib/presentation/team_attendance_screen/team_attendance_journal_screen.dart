// lib/presentation/team_attendance_screen/team_attendance_journal_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';

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

class _TeamAttendanceJournalScreenState
    extends State<TeamAttendanceJournalScreen> {
  static const String apiBase = "https://sportotekaapp.ru/api";
  static const String playersUrl = "$apiBase/get_players_by_team.php";
  static const String getTeamEventsUrl = "$apiBase/get_team_events.php";
  static const String getAttendanceUrl = "$apiBase/get_team_attendance.php";
  static const String setAttendanceUrl = "$apiBase/set_team_attendance.php";

  /// ✅ пустая ячейка (не отмечено)
  static const String kStatusUnset = "unset";

  bool loading = true;
  bool saving = false;
  String? error;

  DateTime selectedMonth =
      DateTime(DateTime.now().year, DateTime.now().month, 1);

  int? selectedEventId;
  String selectedEventTitle = "Все мероприятия";

  List<Map<String, dynamic>> events = [];
  List<Map<String, dynamic>> players = [];

  /// eventId -> playerId(str) -> {status, note, ...}
  final Map<int, Map<String, Map<String, dynamic>>> attendanceByEvent = {};

  final TextEditingController searchC = TextEditingController();
  String filter = "all";
  String viewMode = "list"; // list | grid | table

  int? editingPlayerId;
  int? editingEventId;
  Map<String, dynamic>? editingPlayer;
  Map<String, dynamic>? editingEvent;
  String editingStatus = kStatusUnset;

  // Таблица
  static const double _tableLeftWidth = 240;
  static const double _tableCellW = 64;
  static const double _tableHeaderH = 56;
  static const double _tableRowH = 76;

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

  @override
  void initState() {
    super.initState();
    searchC.addListener(() {
      if (!mounted) return;
      setState(() {});
    });
    _loadAll();
  }

  @override
  void dispose() {
    searchC.dispose();
    super.dispose();
  }

  // ===== ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ =====
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
    final s = (e["start_at"] ?? "").toString().trim();
    if (s.length < 16) return "";
    return s.substring(11, 16);
  }

  String _eventDateLabel(Map<String, dynamic> e) {
    final iso = (e["start_at"] ?? e["event_date"] ?? "").toString();
    final d = _prettyDate(iso);
    final t = _prettyTime(e);
    return t.isNotEmpty ? "$d\n$t" : d;
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

  int _daysInMonth(DateTime m) {
    final next = DateTime(m.year, m.month + 1, 1);
    return next.subtract(const Duration(days: 1)).day;
  }

  // Получить фото URL (обработка относительных путей)
  String? _getPhotoUrl(Map<String, dynamic> player) {
    final photoUrl = (player["photo"] ?? player["photo_url"] ?? "").toString();
    if (photoUrl.isEmpty) return null;

    if (photoUrl.startsWith('http')) {
      return photoUrl;
    } else if (photoUrl.startsWith('/')) {
      return "https://sportotekaapp.ru${photoUrl.replaceAll('//', '/')}";
    } else {
      return "https://sportotekaapp.ru/uploads/$photoUrl";
    }
  }

  void _preloadImage(String url) {
    if (!mounted) return;
    precacheImage(NetworkImage(url), context).catchError((_) {});
  }

  // ===== ЗАГРУЗКА ДАННЫХ =====
  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      error = null;
      players = [];
      events = [];
      attendanceByEvent.clear();
      selectedEventId = null;
      selectedEventTitle = "Все мероприятия";
    });

    try {
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
      "team_id": widget.teamId.toString(),
    });

    final res = await http.get(uri);
    final data = jsonDecode(res.body);

    if (data["status"] != "success") {
      throw Exception(
          data["message"]?.toString() ?? "Не удалось загрузить игроков");
    }

    final list = (data["players"] as List?) ?? [];
    players = list.map((e) => Map<String, dynamic>.from(e)).toList();

    players.sort((a, b) {
      final nameA =
          (a["fullName"] ?? "${a["first_name"] ?? ""} ${a["last_name"] ?? ""}")
              .toString()
              .toLowerCase();
      final nameB =
          (b["fullName"] ?? "${b["first_name"] ?? ""} ${b["last_name"] ?? ""}")
              .toString()
              .toLowerCase();
      return nameA.compareTo(nameB);
    });

    for (final p in players) {
      final u = _getPhotoUrl(p);
      if (u != null) _preloadImage(u);
    }
  }

  Future<void> _fetchEventsForMonth() async {
    final from =
        "${selectedMonth.year}-${selectedMonth.month.toString().padLeft(2, '0')}-01";
    final lastDay = _daysInMonth(selectedMonth);
    final to =
        "${selectedMonth.year}-${selectedMonth.month.toString().padLeft(2, '0')}-${lastDay.toString().padLeft(2, '0')}";

    final uri = Uri.parse(getTeamEventsUrl).replace(queryParameters: {
      "team_id": widget.teamId.toString(),
      "from": from,
      "to": to,
    });

    final res = await http.get(uri);
    final data = jsonDecode(res.body);

    if (data["success"] != true && data["status"] != "success") {
      throw Exception(
          data["message"]?.toString() ?? "Не удалось загрузить мероприятия");
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
            attendanceByEvent[eventId] = items.map(
              (k, v) => MapEntry(
                k.toString(),
                Map<String, dynamic>.from(v),
              ),
            );
          }
        } catch (_) {}
      }));
    }
  }

  Future<void> _reloadAttendanceForEvent(int eventId) async {
    if (eventId <= 0) return;

    try {
      final uri = Uri.parse(getAttendanceUrl).replace(queryParameters: {
        "event_id": eventId.toString(),
      });

      final res = await http.get(uri);
      final data = jsonDecode(res.body);

      if (data["success"] == true) {
        final items = (data["items"] as Map?) ?? {};
        final mapped = items.map(
          (k, v) => MapEntry(k.toString(), Map<String, dynamic>.from(v)),
        );

        if (!mounted) return;
        setState(() {
          attendanceByEvent[eventId] = mapped;
        });
      }
    } catch (_) {}
  }

  // ===== СТАТУСЫ =====
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

  String _playerName(Map<String, dynamic> p) {
    final fullName = p["fullName"]?.toString().trim();
    if (fullName?.isNotEmpty == true) return fullName!;

    final firstName = p["first_name"]?.toString().trim() ?? "";
    final lastName = p["last_name"]?.toString().trim() ?? "";
    return "$firstName $lastName".trim();
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

    bool hasAny = false;
    bool hasPresent = false;

    bool hasLate = false;
    bool hasInjured = false;
    bool hasIndividual = false;
    bool hasDayOff = false;

    for (final event in events) {
      final eventId = int.tryParse(event["id"]?.toString() ?? "0") ?? 0;
      if (eventId <= 0) continue;

      final s = _getStatusForEvent(playerId, eventId);
      if (s == kStatusUnset) continue;

      hasAny = true;

      if (s == "absent") return "absent"; // самый высокий приоритет
      if (s == "late") hasLate = true;
      else if (s == "injured") hasInjured = true;
      else if (s == "individual") hasIndividual = true;
      else if (s == "dayoff") hasDayOff = true;
      else if (s == "present") hasPresent = true;
    }

    if (!hasAny) return kStatusUnset;
    if (hasLate) return "late";
    if (hasInjured) return "injured";
    if (hasIndividual) return "individual";
    if (hasDayOff) return "dayoff";
    if (hasPresent) return "present";

    return kStatusUnset;
  }

  // ===== УСТАНОВКА СТАТУСА =====
  Future<void> _setStatus(int playerId, String status) async {
    if (selectedEventId == null) {
      Get.snackbar("Внимание", "Выберите конкретное мероприятие для отметки");
      return;
    }
    await _setStatusForEvent(selectedEventId!, playerId, status);
    Get.snackbar("Готово", "Статус обновлён: ${_getStatusFullText(status)}");
  }

  Future<void> _setStatusForEvent(
    int eventId,
    int playerId,
    String status,
  ) async {
    final markedBy = await PrefUtils.getUserId() ?? 0;

    if (!mounted) return;
    setState(() => saving = true);

    final sendStatus = (status == kStatusUnset) ? "" : status;

    // ✅ оптимистично обновляем UI
    attendanceByEvent.putIfAbsent(eventId, () => {});
    if (mounted) {
      setState(() {
        if (status == kStatusUnset) {
          attendanceByEvent[eventId]!.remove(playerId.toString());
        } else {
          attendanceByEvent[eventId]![playerId.toString()] = {
            "status": status,
            "note": attendanceByEvent[eventId]?[playerId.toString()]?["note"] ??
                "",
          };
        }
      });
    }

    try {
      final res = await http.post(
        Uri.parse(setAttendanceUrl),
        body: {
          "team_id": widget.teamId.toString(),
          "event_id": eventId.toString(),
          "player_id": playerId.toString(),
          "status": sendStatus,
          "note": (attendanceByEvent[eventId]?[playerId.toString()]?["note"] ??
                  "")
              .toString(),
          "marked_by": markedBy.toString(),
        },
      );

      final data = jsonDecode(res.body);

      if (data["success"] != true) {
        Get.snackbar("Ошибка", data["message"]?.toString() ?? "Не удалось сохранить");
      } else {
        await _reloadAttendanceForEvent(eventId); // ✅ синхронизируем с сервером
      }

      _calculateStats();
    } catch (_) {
      Get.snackbar("Ошибка сети", "Не удалось сохранить статус");
    } finally {
      if (mounted) setState(() => saving = false);
    }
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

  // ===== ФИЛЬТРАЦИЯ И ПОИСК =====
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

        if (!name.contains(query) &&
            !number.contains(query) &&
            !position.contains(query)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  // ===== ЭКСПОРТ CSV =====
  Future<void> _exportCsv() async {
    if (players.isEmpty) {
      Get.snackbar("Пусто", "Нет данных для экспорта");
      return;
    }

    try {
      final buffer = StringBuffer();
      buffer.writeln('Команда,Мероприятие,Игрок ID,ФИО,Номер,Позиция,Статус,Дата');

      for (final player in players) {
        final playerId = int.tryParse(player["id"]?.toString() ?? "0") ?? 0;
        final name = _playerName(player);
        final number = (player["number"] ?? "").toString();
        final position = (player["position"] ?? "").toString();

        String status = kStatusUnset;
        String eventDate = "";

        if (selectedEventId == null) {
          status = _getAggregatedStatus(playerId);
          eventDate =
              "${selectedMonth.year}-${selectedMonth.month.toString().padLeft(2, '0')}";
        } else {
          status = _getStatusForEvent(playerId, selectedEventId!);
          final event = events.firstWhere(
            (e) =>
                (int.tryParse(e["id"]?.toString() ?? "0") ?? 0) ==
                selectedEventId,
            orElse: () => {},
          );
          eventDate = (event["start_at"] ?? "").toString();
        }

        buffer.writeln([
          _escapeCsv(widget.teamName),
          _escapeCsv(selectedEventTitle),
          playerId,
          _escapeCsv(name),
          _escapeCsv(number),
          _escapeCsv(position),
          _escapeCsv(_getStatusFullText(status)),
          _escapeCsv(eventDate),
        ].join(','));
      }

      final dir = await getTemporaryDirectory();
      final safeTeam =
          widget.teamName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final file = File(
        '${dir.path}/посещаемость_${safeTeam}_${DateTime.now().millisecondsSinceEpoch}.csv',
      );

      await file.writeAsString(buffer.toString(), flush: true, encoding: utf8);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv')],
        subject: 'Посещаемость — ${widget.teamName}',
      );
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

  // ===== ВЫБОР СТАТУСА (БОКОВОЙ РЕДАКТОР) =====
  Map<String, dynamic>? _playerById(int playerId) {
    for (final p in players) {
      if ((int.tryParse(p["id"]?.toString() ?? "0") ?? 0) == playerId) return p;
    }
    return null;
  }

  Map<String, dynamic>? _eventById(int eventId) {
    for (final e in events) {
      if ((int.tryParse(e["id"]?.toString() ?? "0") ?? 0) == eventId) return e;
    }
    return null;
  }

  Future<void> _showStatusSelector(
    BuildContext context,
    int playerId,
    String currentStatus, {
    int? overrideEventId,
  }) async {
    final eventId = overrideEventId ?? selectedEventId;
    if (eventId == null) {
      Get.snackbar("Внимание", "Выберите конкретное мероприятие для отметки");
      return;
    }

    final event = _eventById(eventId);
    final player = _playerById(playerId);
    if (!mounted) return;
    setState(() {
      editingEventId = eventId;
      editingPlayerId = playerId;
      editingEvent = event;
      editingPlayer = player;
      editingStatus = currentStatus;
      selectedEventId = eventId;
      selectedEventTitle = event == null ? "Мероприятие" : _eventTitle(event);
    });
    _calculateStats();
  }

  void _closeStatusEditor() {
    setState(() {
      editingEventId = null;
      editingPlayerId = null;
      editingEvent = null;
      editingPlayer = null;
      editingStatus = kStatusUnset;
    });
  }

  Future<void> _applyEditorStatus(String status) async {
    final playerId = editingPlayerId;
    final eventId = editingEventId;
    if (playerId == null || eventId == null) return;
    setState(() => editingStatus = status);
    await _setStatusForEvent(eventId, playerId, status);
    if (!mounted) return;
    setState(() => editingStatus = _getStatusForEvent(playerId, eventId));
  }

  Widget _buildJournalWorkspace({required Widget child}) {
    final hasEditor = editingPlayerId != null && editingEventId != null;
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 1120;
        if (!desktop) {
          return Container(
            decoration: const BoxDecoration(gradient: _J.bgGradient),
            child: Stack(
              children: [
                Positioned.fill(child: child),
                if (hasEditor)
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: SizedBox(
                      height: 292,
                      child: _buildSideStatusEditor(compact: true),
                    ),
                  ),
              ],
            ),
          );
        }

        return Container(
          decoration: const BoxDecoration(gradient: _J.bgGradient),
          child: Row(
            children: [
              Expanded(child: child),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                child: hasEditor
                    ? Padding(
                        key: const ValueKey('attendance-journal-editor'),
                        padding: const EdgeInsets.fromLTRB(0, 16, 16, 16),
                        child: SizedBox(
                          width: 366,
                          child: _buildSideStatusEditor(),
                        ),
                      )
                    : const SizedBox.shrink(key: ValueKey('attendance-journal-editor-empty')),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSideStatusEditor({bool compact = false}) {
    final player = editingPlayer;
    final event = editingEvent;
    if (player == null || event == null || editingPlayerId == null || editingEventId == null) {
      return Container(
        decoration: _J.glassCard,
        alignment: Alignment.center,
        child: const Text(
          "Выберите игрока для отметки",
          style: TextStyle(fontSize: 11.55, fontWeight: FontWeight.w700, color: _J.muted),
        ),
      );
    }

    final playerId = editingPlayerId!;
    final photoUrl = _getPhotoUrl(player);
    final name = _playerName(player);
    final number = (player["number"] ?? "").toString();
    final position = (player["position"] ?? "").toString();
    final current = editingStatus;
    final currentColor = _getStatusColor(current);

    final statuses = [
      [kStatusUnset, "Очистить", "—", const Color(0xFF64748B)],
      ["present", "Присутствует", "П", const Color(0xFF22C55E)],
      ["absent", "Отсутствует", "Н", const Color(0xFFEF4444)],
      ["late", "Болен", "Б", const Color(0xFFF59E0B)],
      ["injured", "Травма", "Т", const Color(0xFF8B5CF6)],
      ["individual", "Индивид.", "И", const Color(0xFF0EA5E9)],
      ["dayoff", "Выходной", "В", const Color(0xFF9CA3AF)],
    ];

    return Container(
      decoration: _J.glassCard,
      padding: EdgeInsets.all(compact ? 14 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: _J.accentGradient,
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: [
                    BoxShadow(color: _J.green.withOpacity(.22), blurRadius: 18, offset: const Offset(0, 8)),
                  ],
                ),
                child: const Icon(Icons.edit_calendar_rounded, color: Colors.white, size: 17),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  "Редактирование отметки",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13.55, fontWeight: FontWeight.w800, color: _J.text, letterSpacing: -.2),
                ),
              ),
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _closeStatusEditor,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(color: _J.soft, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.close_rounded, size: 16, color: _J.muted),
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 10 : 16),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [currentColor.withOpacity(.15), Colors.white]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                _avatarWithNumber(
                  photoUrl: photoUrl,
                  number: number,
                  accent: currentColor,
                  size: compact ? 48 : 56,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.85, fontWeight: FontWeight.w900, color: _J.text)),
                      const SizedBox(height: 4),
                      Text(position.isEmpty ? "Игрок команды" : position, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.05, fontWeight: FontWeight.w700, color: _J.muted)),
                      const SizedBox(height: 7),
                      Text(
                        "${_eventDateLabel(event).replaceAll('\n', ' · ')} · ${_eventTitle(event)}",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10.35, fontWeight: FontWeight.w800, color: currentColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: compact ? 10 : 16),
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.zero,
              itemCount: statuses.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: compact ? 4 : 2,
                crossAxisSpacing: 9,
                mainAxisSpacing: 9,
                childAspectRatio: compact ? 1.82 : 2.4,
              ),
              itemBuilder: (context, index) {
                final row = statuses[index];
                final code = row[0] as String;
                final label = row[1] as String;
                final symbol = row[2] as String;
                final color = row[3] as Color;
                return _buildEditorStatusTile(
                  code: code,
                  label: label,
                  symbol: symbol,
                  color: color,
                  active: code == current,
                  onTap: () => _applyEditorStatus(code),
                );
              },
            ),
          ),
          if (saving) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: const LinearProgressIndicator(minHeight: 4, color: _J.green, backgroundColor: _J.softGreen),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEditorStatusTile({
    required String code,
    required String label,
    required String symbol,
    required Color color,
    required bool active,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: active ? color.withOpacity(.15) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: active ? color.withOpacity(.82) : color.withOpacity(.16), width: active ? 1.4 : 1),
            boxShadow: active ? [BoxShadow(color: color.withOpacity(.18), blurRadius: 18, offset: const Offset(0, 8))] : null,
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: code == kStatusUnset ? Colors.white : color.withOpacity(active ? 1 : .12),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: code == kStatusUnset
                    ? Icon(Icons.remove_rounded, size: 15, color: color)
                    : Text(symbol, style: TextStyle(fontSize: 11.55, fontWeight: FontWeight.w900, color: active ? Colors.white : color)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.75, fontWeight: FontWeight.w800, color: active ? color : _J.text)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===== UI блоки =====
  Widget _buildMonthSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8ECF3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              setState(() {
                selectedMonth =
                    DateTime(selectedMonth.year, selectedMonth.month - 1, 1);
                selectedEventId = null;
                selectedEventTitle = "Все мероприятия";
              });
              _loadAll();
            },
            icon: Icon(PhosphorIcons.caretLeft(PhosphorIconsStyle.bold)),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFF3F4F6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  _monthTitle(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15.75,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "${events.length} мероприятий",
                  style: const TextStyle(
                    fontSize: 12.35,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                selectedMonth =
                    DateTime(selectedMonth.year, selectedMonth.month + 1, 1);
                selectedEventId = null;
                selectedEventTitle = "Все мероприятия";
              });
              _loadAll();
            },
            icon: Icon(PhosphorIcons.caretRight(PhosphorIconsStyle.bold)),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFFF3F4F6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventSelector() {
    if (events.isEmpty) return const SizedBox();

    final eventColor = selectedEventId == null
        ? const Color(0xFF6B7280)
        : Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8ECF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(PhosphorIcons.calendar(PhosphorIconsStyle.bold),
                  size: 20, color: eventColor),
              const SizedBox(width: 8),
              Text(
                "Мероприятие",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14.05,
                  color: eventColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  builder: (context) {
                    return Container(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE5E7EB),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "Выберите мероприятие",
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16.75,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Все мероприятия месяца
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                Navigator.pop(context);
                                setState(() {
                                  selectedEventId = null;
                                  selectedEventTitle = "Все мероприятия";
                                  _calculateStats();
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: selectedEventId == null
                                      ? const Color(0xFFF3F4F6)
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: selectedEventId == null
                                        ? Theme.of(context)
                                            .colorScheme
                                            .primary
                                        : const Color(0xFFE8ECF3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      PhosphorIcons.calendarBlank(
                                          PhosphorIconsStyle.bold),
                                      color: selectedEventId == null
                                          ? Theme.of(context)
                                              .colorScheme
                                              .primary
                                          : const Color(0xFF6B7280),
                                    ),
                                    const SizedBox(width: 12),
                                    const Expanded(
                                      child: Text(
                                        "Все мероприятия месяца",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14.05,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          Expanded(
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: events.length,
                              itemBuilder: (context, index) {
                                final event = events[index];
                                final eventId =
                                    int.tryParse(event["id"]?.toString() ?? "0") ??
                                        0;
                                final title = _eventTitle(event);
                                final date = _prettyDate(
                                    (event["start_at"] ?? "").toString());
                                final time = _prettyTime(event);
                                final isSelected = selectedEventId == eventId;

                                return Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () {
                                      Navigator.pop(context);
                                      setState(() {
                                        selectedEventId = eventId;
                                        selectedEventTitle = title;
                                        _calculateStats();
                                      });
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                                .withOpacity(0.08)
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: isSelected
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                              : const Color(0xFFE8ECF3),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(
                                                PhosphorIcons.calendarCheck(
                                                    PhosphorIconsStyle.bold),
                                                size: 18,
                                                color: isSelected
                                                    ? Theme.of(context)
                                                        .colorScheme
                                                        .primary
                                                    : const Color(0xFF6B7280),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  title,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 14.05,
                                                    color: isSelected
                                                        ? Theme.of(context)
                                                            .colorScheme
                                                            .primary
                                                        : const Color(0xFF111827),
                                                  ),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Icon(
                                                PhosphorIcons.clock(
                                                    PhosphorIconsStyle.bold),
                                                size: 14,
                                                color: const Color(0xFF9CA3AF),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                "$date ${time.isNotEmpty ? '· $time' : ''}",
                                                style: const TextStyle(
                                                  fontSize: 12.35,
                                                  color: Color(0xFF6B7280),
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    );
                  },
                );
              },
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
                          ? PhosphorIcons.calendarBlank(
                              PhosphorIconsStyle.bold)
                          : PhosphorIcons.calendarCheck(
                              PhosphorIconsStyle.bold),
                      color: eventColor,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selectedEventTitle,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14.05,
                              color: eventColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (selectedEventId != null) const SizedBox(height: 4),
                          if (selectedEventId != null)
                            Text(
                              "Выбрано для отметки",
                              style: TextStyle(
                                fontSize: 11.55,
                                color: eventColor.withOpacity(0.7),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Icon(
                      PhosphorIcons.caretDown(PhosphorIconsStyle.bold),
                      color: eventColor,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8ECF3)),
      ),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1.1,
        children: [
          _buildStatBadge(
            count: stats["unset"] ?? 0,
            color: const Color(0xFF64748B),
            label: "Не отм.",
            symbol: "—",
          ),
          _buildStatBadge(
            count: stats["present"] ?? 0,
            color: const Color(0xFF22C55E),
            label: "Присут.",
            symbol: "П",
          ),
          _buildStatBadge(
            count: stats["absent"] ?? 0,
            color: const Color(0xFFEF4444),
            label: "Отсут.",
            symbol: "Н",
          ),
          _buildStatBadge(
            count: stats["late"] ?? 0,
            color: const Color(0xFFF59E0B),
            label: "Болен",
            symbol: "Б",
          ),
          _buildStatBadge(
            count: stats["injured"] ?? 0,
            color: const Color(0xFF8B5CF6),
            label: "Травма",
            symbol: "Т",
          ),
          _buildStatBadge(
            count: stats["individual"] ?? 0,
            color: const Color(0xFF0EA5E9),
            label: "Инд.",
            symbol: "И",
          ),
          _buildStatBadge(
            count: stats["dayoff"] ?? 0,
            color: const Color(0xFF9CA3AF),
            label: "Выходн.",
            symbol: "В",
          ),
          _buildStatBadge(
            count: _filteredPlayers.length,
            color: const Color(0xFF111827),
            label: "Показано",
            symbol: "👥",
            isPlayers: true,
          ),
          _buildStatBadge(
            count: players.length,
            color: const Color(0xFF111827),
            label: "Всего",
            symbol: "Σ",
            isTotal: true,
          ),
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
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                isPlayers || isTotal ? "$count" : symbol,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: isPlayers || isTotal ? 14 : 15,
                  color: color,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 9.85,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

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
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE8ECF3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: TextField(
              controller: searchC,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: "Поиск игрока...",
                prefixIcon: Icon(
                    PhosphorIcons.magnifyingGlass(PhosphorIconsStyle.bold)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
              PopupMenuItem(
                  value: kStatusUnset, child: const Text("Не отмечено (—)")),
              const PopupMenuItem(
                  value: "present", child: Text("Присутствует (П)")),
              const PopupMenuItem(
                  value: "absent", child: Text("Отсутствует (Н)")),
              const PopupMenuItem(value: "late", child: Text("Болен (Б)")),
              const PopupMenuItem(value: "injured", child: Text("Травма (Т)")),
              const PopupMenuItem(
                  value: "individual", child: Text("Индивид. (И)")),
              const PopupMenuItem(
                  value: "dayoff", child: Text("Выходной (В)")),
            ],
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE8ECF3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(
                PhosphorIcons.funnel(PhosphorIconsStyle.bold),
                color: filter == "all"
                    ? const Color(0xFF6B7280)
                    : _getStatusColor(filter),
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE8ECF3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(
                viewIcon,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ===== “ДОРОГОЙ” АВАТАР С НОМЕРОМ =====
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
                      errorBuilder: (_, __, ___) => Center(
                        child: Icon(
                          PhosphorIcons.user(PhosphorIconsStyle.bold),
                          size: size * 0.45,
                          color: accent,
                        ),
                      ),
                    )
                  : Center(
                      child: Icon(
                        PhosphorIcons.user(PhosphorIconsStyle.bold),
                        size: size * 0.45,
                        color: accent,
                      ),
                    ),
            ),
          ),
          if (number.isNotEmpty)
            Positioned(
              right: -6,
              bottom: -6,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF111827),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Text(
                  "№$number",
                  style: const TextStyle(
                    fontSize: 9.85,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ===== ВИДЖЕТЫ ИГРОКОВ =====
  Widget _buildPlayerList() {
    final filtered = _filteredPlayers;

    if (filtered.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(
              PhosphorIcons.users(PhosphorIconsStyle.bold),
              size: 72,
              color: const Color(0xFFD1D5DB),
            ),
            const SizedBox(height: 16),
            const Text(
              "Игроки не найдены",
              style: TextStyle(
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w800,
                fontSize: 15.05,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Попробуйте изменить поиск или фильтр",
              style: TextStyle(
                color: Color(0xFF9CA3AF),
                fontSize: 13.05,
              ),
              textAlign: TextAlign.center,
            ),
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
      itemBuilder: (context, index) {
        final player = filteredPlayers[index];
        return _buildPlayerCardList(player);
      },
    );
  }

  Widget _buildPlayerCardList(Map<String, dynamic> player) {
    final playerId = int.tryParse(player["id"]?.toString() ?? "0") ?? 0;
    final name = _playerName(player);
    final number = (player["number"] ?? "").toString();
    final position = (player["position"] ?? "").toString();
    final photoUrl = _getPhotoUrl(player);

    final status = selectedEventId == null
        ? _getAggregatedStatus(playerId)
        : _getStatusForEvent(playerId, selectedEventId!);

    final statusSymbol = _getStatusSymbol(status);
    final statusColor = _getStatusColor(status);
    final statusFullText = _getStatusFullText(status);

    const double rightColW = 92;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8ECF3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: selectedEventId != null
              ? () => _showStatusSelector(context, playerId, status)
              : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _avatarWithNumber(
                  photoUrl: photoUrl,
                  number: number,
                  accent: statusColor,
                  size: 58,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15.05,
                          color: Color(0xFF111827),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      if (position.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            position,
                            style: const TextStyle(
                              fontSize: 11.55,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF374151),
                            ),
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
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 15.05,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          statusFullText,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.55,
                            fontWeight: FontWeight.w800,
                            color: statusColor,
                          ),
                        ),
                      ] else ...[
                        // ✅ пустой кружок (видимый)
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFCBD5E1),
                              width: 2,
                            ),
                            color: const Color(0xFFF8FAFC),
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
      itemBuilder: (context, index) {
        final player = filteredPlayers[index];
        return _buildPlayerCardGrid(player);
      },
    );
  }

  Widget _buildPlayerCardGrid(Map<String, dynamic> player) {
    final playerId = int.tryParse(player["id"]?.toString() ?? "0") ?? 0;
    final name = _playerName(player);
    final number = (player["number"] ?? "").toString();
    final position = (player["position"] ?? "").toString();
    final photoUrl = _getPhotoUrl(player);

    final status = selectedEventId == null
        ? _getAggregatedStatus(playerId)
        : _getStatusForEvent(playerId, selectedEventId!);

    final statusSymbol = _getStatusSymbol(status);
    final statusColor = _getStatusColor(status);
    final statusFullText = _getStatusFullText(status);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: selectedEventId != null
            ? () => _showStatusSelector(context, playerId, status)
            : null,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE8ECF3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              Stack(
                children: [
                  Container(
                    height: 120,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
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
                        child: _avatarWithNumber(
                          photoUrl: photoUrl,
                          number: number,
                          accent: statusColor,
                          size: 82,
                        ),
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
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.10),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            statusSymbol,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 13.05,
                              color: Colors.white,
                            ),
                          ),
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
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13.05,
                        color: Color(0xFF111827),
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    if (position.isNotEmpty)
                      Text(
                        position,
                        style: const TextStyle(
                          fontSize: 11.55,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6B7280),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 6),
                    if (status != kStatusUnset)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          statusFullText,
                          style: TextStyle(
                            fontSize: 10.55,
                            fontWeight: FontWeight.w800,
                            color: statusColor,
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFCBD5E1).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: const Color(0xFFCBD5E1), width: 1),
                        ),
                        child: const Text(
                          "Не отмечено",
                          style: TextStyle(
                            fontSize: 10.55,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF64748B),
                          ),
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

  // ===== TABLE MODE =====
  Widget _buildAttendanceTable(List<Map<String, dynamic>> filteredPlayers) {
    if (events.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE8ECF3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline, color: Color(0xFF6B7280)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                "В этом месяце нет мероприятий — таблица пустая.",
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w700,
                ),
              ),
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
            ...filteredPlayers.map((p) => _buildTableRowRight(p)).toList(),
          ],
        ),
      ),
    );

    final left = SizedBox(
      width: _tableLeftWidth,
      child: Column(
        children: [
          _buildTableHeaderLeft(),
          ...filteredPlayers.map((p) => _buildTableRowLeft(p)).toList(),
        ],
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8ECF3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SingleChildScrollView(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              left,
              const VerticalDivider(
                width: 1,
                thickness: 1,
                color: Color(0xFFE8ECF3),
              ),
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
      child: const Align(
        alignment: Alignment.centerLeft,
        child: Text(
          "Игрок",
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: Color(0xFF111827),
          ),
        ),
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
                color: isSel
                    ? Theme.of(context).colorScheme.primary.withOpacity(0.08)
                    : Colors.transparent,
                border: Border(
                  right: BorderSide(
                    color: const Color(0xFFE8ECF3).withOpacity(0.9),
                  ),
                ),
              ),
              child: Center(
                child: Text(
                  _eventDateLabel(e),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.55,
                    fontWeight: FontWeight.w900,
                    color: isSel
                        ? Theme.of(context).colorScheme.primary
                        : const Color(0xFF111827),
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
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE8ECF3))),
      ),
      child: Row(
        children: [
          _avatarWithNumber(
            photoUrl: photoUrl,
            number: number,
            accent: aggColor,
            size: 48,
          ),
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
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13.05,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 8),
                if (position.isNotEmpty)
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        position,
                        style: const TextStyle(
                          fontSize: 11.55,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF374151),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 26),
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
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE8ECF3))),
      ),
      child: Row(
        children: List.generate(events.length, (i) {
          final e = events[i];
          final eventId = int.tryParse(e["id"]?.toString() ?? "0") ?? 0;

          final status = _getStatusForEvent(playerId, eventId);
          final symbol = _getStatusSymbol(status);
          final color = _getStatusColor(status);
          final isUnset = status == kStatusUnset;

          return InkWell(
            onTap: () {
              _showStatusSelector(
                context,
                playerId,
                status,
                overrideEventId: eventId,
              );
            },
            child: Container(
              width: _tableCellW,
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(
                    color: const Color(0xFFE8ECF3).withOpacity(0.9),
                  ),
                ),
              ),
              child: Center(
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    // ✅ пустые кружки всегда видимые
                    color: isUnset ? const Color(0xFFF8FAFC) : color.withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isUnset
                          ? const Color(0xFFCBD5E1)
                          : color.withOpacity(0.65),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: isUnset
                        ? const SizedBox()
                        : Text(
                            symbol,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: color,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ===== ГЛАВНЫЙ ВИДЖЕТ =====
  @override
  Widget build(BuildContext context) {
    String viewLabel;
    IconData viewBadgeIcon;
    if (viewMode == "list") {
      viewLabel = "Список";
      viewBadgeIcon = PhosphorIcons.list(PhosphorIconsStyle.bold);
    } else if (viewMode == "grid") {
      viewLabel = "Сетка";
      viewBadgeIcon = PhosphorIcons.squaresFour(PhosphorIconsStyle.bold);
    } else {
      viewLabel = "Таблица";
      viewBadgeIcon = PhosphorIcons.table(PhosphorIconsStyle.bold);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F8FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          "Посещаемость — ${widget.teamName}",
          style: const TextStyle(fontWeight: FontWeight.w900),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (saving)
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
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
                  Text(
                    "Загрузка данных...",
                    style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
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
                        Icon(
                          PhosphorIcons.warningCircle(
                              PhosphorIconsStyle.bold),
                          size: 64,
                          color: const Color(0xFFEF4444),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadAll,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF111827),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                          child: const Text(
                            "Повторить",
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildJournalWorkspace(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
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
                            border: Border.all(
                              color: const Color(0xFFF59E0B).withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                PhosphorIcons.info(PhosphorIconsStyle.bold),
                                color: const Color(0xFFF59E0B),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Выберите мероприятие",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF92400E),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Для отметки посещаемости выберите конкретное мероприятие в списке выше",
                                      style: TextStyle(
                                        fontSize: 12.35,
                                        color: const Color(0xFF92400E)
                                            .withOpacity(0.8),
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
                          Text(
                            "Игроки (${_filteredPlayers.length})",
                            style: const TextStyle(
                              fontSize: 14.05,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF111827),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  viewBadgeIcon,
                                  size: 14,
                                  color: const Color(0xFF6B7280),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  viewLabel,
                                  style: const TextStyle(
                                    fontSize: 11.55,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF6B7280),
                                  ),
                                ),
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
              ),
    );
  }
}


class _J {
  static const Color bg = Color(0xFFF5F8FB);
  static const Color text = Color(0xFF14211B);
  static const Color muted = Color(0xFF66736C);
  static const Color soft = Color(0xFFF2F6F8);
  static const Color softGreen = Color(0xFFEAF7EF);
  static const Color green = Color(0xFF18864B);
  static const Color blue = Color(0xFF2563EB);
  static const Color cyan = Color(0xFF06B6D4);

  static const LinearGradient bgGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF7FBFF), Color(0xFFF3FAF6), Color(0xFFFFFFFF)],
  );

  static LinearGradient get accentGradient => const LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0F5F36), Color(0xFF18864B), Color(0xFF06B6D4)],
  );

  static BoxDecoration get glassCard => BoxDecoration(
    color: Colors.white.withOpacity(.92),
    borderRadius: BorderRadius.circular(24),
    border: Border.all(color: Colors.white.withOpacity(.72)),
    boxShadow: [
      BoxShadow(color: const Color(0xFF0F172A).withOpacity(.08), blurRadius: 30, offset: const Offset(0, 18)),
    ],
  );
}
