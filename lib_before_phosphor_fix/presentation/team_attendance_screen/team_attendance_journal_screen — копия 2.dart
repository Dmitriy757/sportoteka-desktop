// lib/presentation/team_attendance_screen/team_attendance_journal_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
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

  bool loading = true;
  bool saving = false;
  String? error;

  DateTime selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  int? selectedEventId; // null = весь месяц, иначе конкретное мероприятие
  String selectedEventTitle = "Все мероприятия";
  List<Map<String, dynamic>> events = [];
  List<Map<String, dynamic>> players = [];
  
  // attendance[eventId][playerId] = {status, note}
  final Map<int, Map<String, Map<String, dynamic>>> attendanceByEvent = {};

  // Для поиска и фильтров
  final TextEditingController searchC = TextEditingController();
  String filter = "all"; // all | present | absent | late | injured | individual | dayoff
  String viewMode = "month"; // month | event

  // Статистика
  Map<String, int> stats = {
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

  String _monthTitle() {
    const ru = [
      "Январь", "Февраль", "Март", "Апрель", "Май", "Июнь",
      "Июль", "Август", "Сентябрь", "Октябрь", "Ноябрь", "Декабрь"
    ];
    return "${ru[selectedMonth.month - 1]} ${selectedMonth.year}";
  }

  int _daysInMonth(DateTime m) {
    final next = DateTime(m.year, m.month + 1, 1);
    return next.subtract(const Duration(days: 1)).day;
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
      setState(() => error = e.toString());
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
      throw Exception(data["message"]?.toString() ?? "Не удалось загрузить игроков");
    }
    
    final list = (data["players"] as List?) ?? [];
    players = list.map((e) => Map<String, dynamic>.from(e)).toList();
    
    // Сортировка по ФИО
    players.sort((a, b) {
      final nameA = (a["fullName"] ?? "${a["first_name"] ?? ""} ${a["last_name"] ?? ""}")
          .toString().toLowerCase();
      final nameB = (b["fullName"] ?? "${b["first_name"] ?? ""} ${b["last_name"] ?? ""}")
          .toString().toLowerCase();
      return nameA.compareTo(nameB);
    });
  }

  Future<void> _fetchEventsForMonth() async {
    final from = "${selectedMonth.year}-${selectedMonth.month.toString().padLeft(2, '0')}-01";
    final lastDay = _daysInMonth(selectedMonth);
    final to = "${selectedMonth.year}-${selectedMonth.month.toString().padLeft(2, '0')}-${lastDay.toString().padLeft(2, '0')}";
    
    final uri = Uri.parse(getTeamEventsUrl).replace(queryParameters: {
      "team_id": widget.teamId.toString(),
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
    
    // Сортировка по дате
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
            attendanceByEvent[eventId] = items.map((k, v) => 
                MapEntry(k.toString(), Map<String, dynamic>.from(v)));
          }
        } catch (_) {}
      }));
    }
  }

  // ===== СТАТУСЫ И ОБРАБОТКА =====
  String statusLabel(String s) {
    switch (s) {
      case "absent": return "Отсутствовал";
      case "late": return "Болел";
      case "injured": return "Травма";
      case "individual": return "Индивид. подготовка";
      case "dayoff": return "Выходной";
      default: return "Присутствовал";
    }
  }

  IconData statusIcon(String s) {
    switch (s) {
      case "absent": return PhosphorIcons.xCircle(PhosphorIconsStyle.bold);
      case "late": return PhosphorIcons.clock(PhosphorIconsStyle.bold);
      case "injured": return PhosphorIcons.firstAid(PhosphorIconsStyle.bold);
      case "individual": return PhosphorIcons.barbell(PhosphorIconsStyle.bold);
      case "dayoff": return PhosphorIcons.sun(PhosphorIconsStyle.bold);
      default: return PhosphorIcons.checkCircle(PhosphorIconsStyle.bold);
    }
  }

  Color statusColor(String s) {
    switch (s) {
      case "absent": return const Color(0xFFEF4444);
      case "late": return const Color(0xFFF59E0B);
      case "injured": return const Color(0xFF8B5CF6);
      case "individual": return const Color(0xFF0EA5E9);
      case "dayoff": return const Color(0xFF9CA3AF);
      default: return const Color(0xFF22C55E);
    }
  }

  String _playerName(Map<String, dynamic> p) {
    final fullName = p["fullName"]?.toString().trim();
    if (fullName?.isNotEmpty == true) return fullName!;
    
    final firstName = p["first_name"]?.toString().trim() ?? "";
    final lastName = p["last_name"]?.toString().trim() ?? "";
    return "$firstName $lastName".trim();
  }

  // Получить статус игрока для конкретного мероприятия
  String _getStatusForEvent(int playerId, int eventId) {
    final eventAttendance = attendanceByEvent[eventId];
    if (eventAttendance == null) return "present";
    
    final playerData = eventAttendance[playerId.toString()];
    return (playerData?["status"] ?? "present").toString();
  }

  // Получить агрегированный статус для месяца (если смотрим весь месяц)
  String _getAggregatedStatus(int playerId) {
    if (events.isEmpty) return "present";
    
    // Если есть хотя бы одно отсутствие - показываем отсутствие
    for (final event in events) {
      final eventId = int.tryParse(event["id"]?.toString() ?? "0") ?? 0;
      final status = _getStatusForEvent(playerId, eventId);
      if (status == "absent") return "absent";
    }
    
    // Иначе показываем первый не-присутствующий статус или присутствие
    for (final event in events) {
      final eventId = int.tryParse(event["id"]?.toString() ?? "0") ?? 0;
      final status = _getStatusForEvent(playerId, eventId);
      if (status != "present") return status;
    }
    
    return "present";
  }

  // ===== УСТАНОВКА СТАТУСА =====
  Future<void> _setStatus(int playerId, String status) async {
    if (selectedEventId == null) {
      // Если смотрим весь месяц - отмечаем для всех мероприятий
      Get.snackbar("Внимание", "Выберите конкретное мероприятие для отметки");
      return;
    }

    final markedBy = await PrefUtils.getUserId() ?? 0;
    
    if (!mounted) return;
    setState(() => saving = true);

    try {
      // Обновляем локально
      attendanceByEvent.putIfAbsent(selectedEventId!, () => {});
      attendanceByEvent[selectedEventId]![playerId.toString()] = {
        "status": status,
        "note": attendanceByEvent[selectedEventId]?[playerId.toString()]?["note"] ?? "",
      };

      // Сохраняем на сервер
      final res = await http.post(
        Uri.parse(setAttendanceUrl),
        body: {
          "team_id": widget.teamId.toString(),
          "event_id": selectedEventId.toString(),
          "player_id": playerId.toString(),
          "status": status,
          "note": (attendanceByEvent[selectedEventId]?[playerId.toString()]?["note"] ?? "").toString(),
          "marked_by": markedBy.toString(),
        }
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

  // ===== РАСЧЕТ СТАТИСТИКИ =====
  void _calculateStats() {
    final newStats = {
      "present": 0,
      "absent": 0,
      "late": 0,
      "injured": 0,
      "individual": 0,
      "dayoff": 0,
      "total": players.length,
    };

    if (selectedEventId == null) {
      // Статистика по месяцу
      for (final player in players) {
        final playerId = int.tryParse(player["id"]?.toString() ?? "0") ?? 0;
        final status = _getAggregatedStatus(playerId);
        newStats[status] = (newStats[status] ?? 0) + 1;
      }
    } else {
      // Статистика по конкретному мероприятию
      for (final player in players) {
        final playerId = int.tryParse(player["id"]?.toString() ?? "0") ?? 0;
        final status = _getStatusForEvent(playerId, selectedEventId!);
        newStats[status] = (newStats[status] ?? 0) + 1;
      }
    }

    setState(() => stats = newStats);
  }

  // ===== ФИЛЬТРАЦИЯ И ПОИСК =====
  List<Map<String, dynamic>> get _filteredPlayers {
    final query = searchC.text.trim().toLowerCase();
    
    return players.where((player) {
      // Фильтр по статусу
      final playerId = int.tryParse(player["id"]?.toString() ?? "0") ?? 0;
      final status = selectedEventId == null 
          ? _getAggregatedStatus(playerId)
          : _getStatusForEvent(playerId, selectedEventId!);
      
      if (filter != "all" && status != filter) return false;
      
      // Поиск
      if (query.isNotEmpty) {
        final name = _playerName(player).toLowerCase();
        final number = (player["number"] ?? "").toString().toLowerCase();
        final position = (player["position"] ?? "").toString().toLowerCase();
        
        if (!name.contains(query) && !number.contains(query) && !position.contains(query)) {
          return false;
        }
      }
      
      return true;
    }).toList();
  }

  // ===== ЭКСПОРТ CSV =====
  String _escapeCsv(String s) {
    final v = s.replaceAll('\r', ' ').replaceAll('\n', ' ').trim();
    final needQuotes = v.contains(',') || v.contains('"') || v.contains(';');
    final escaped = v.replaceAll('"', '""');
    return needQuotes ? '"$escaped"' : escaped;
  }

  Future<void> _exportCsv() async {
    if (players.isEmpty) {
      Get.snackbar("Пусто", "Нет данных для экспорта");
      return;
    }

    try {
      final buffer = StringBuffer();
      buffer.writeln('Команда,Мероприятие,Игрок ID,ФИО,Номер,Позиция,Статус,Дата мероприятия');

      for (final player in players) {
        final playerId = int.tryParse(player["id"]?.toString() ?? "0") ?? 0;
        final name = _playerName(player);
        final number = (player["number"] ?? "").toString();
        final position = (player["position"] ?? "").toString();
        
        String status = "present";
        String eventDate = "";
        
        if (selectedEventId == null) {
          // Месячный отчет
          status = _getAggregatedStatus(playerId);
          eventDate = "${selectedMonth.year}-${selectedMonth.month.toString().padLeft(2, '0')}";
        } else {
          // Отчет по конкретному мероприятию
          status = _getStatusForEvent(playerId, selectedEventId!);
          final event = events.firstWhere(
            (e) => (int.tryParse(e["id"]?.toString() ?? "0") ?? 0) == selectedEventId,
            orElse: () => {},
          );
          eventDate = _prettyDate((event["start_at"] ?? "").toString());
        }

        buffer.writeln([
          _escapeCsv(widget.teamName),
          _escapeCsv(selectedEventTitle),
          playerId,
          _escapeCsv(name),
          _escapeCsv(number),
          _escapeCsv(position),
          _escapeCsv(statusLabel(status)),
          _escapeCsv(eventDate),
        ].join(','));
      }

      final dir = await getTemporaryDirectory();
      final safeTeam = widget.teamName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final safeMonth = "${selectedMonth.year}-${selectedMonth.month}";
      final file = File(
        '${dir.path}/посещаемость_${safeTeam}_${safeMonth}_${DateTime.now().millisecondsSinceEpoch}.csv',
      );
      
      await file.writeAsString(buffer.toString(), flush: true, encoding: utf8);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv')],
        subject: 'Посещаемость — ${widget.teamName}',
        text: 'Экспорт посещаемости за ${_monthTitle()}',
      );
    } catch (_) {
      Get.snackbar("Ошибка", "Не удалось экспортировать CSV");
    }
  }

  // ===== ВИДЖЕТЫ =====
  Widget _buildMonthSelector() {
    return Container(
      padding: const EdgeInsets.all(12),
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
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  _monthTitle(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Мероприятий: ${events.length}",
                  style: const TextStyle(
                    fontSize: 12,
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
                selectedMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 1);
                selectedEventId = null;
                selectedEventTitle = "Все мероприятия";
              });
              _loadAll();
            },
            icon: Icon(PhosphorIcons.caretRight(PhosphorIconsStyle.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildEventSelector() {
    if (events.isEmpty) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8ECF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Мероприятие",
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 14,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              isExpanded: true,
              value: selectedEventId,
              hint: const Text("Все мероприятия"),
              items: [
                DropdownMenuItem<int>(
                  value: null,
                  child: Row(
                    children: [
                      Icon(PhosphorIcons.calendarBlank(PhosphorIconsStyle.bold),
                          size: 20, color: const Color(0xFF6B7280)),
                      const SizedBox(width: 8),
                      const Text("Все мероприятия месяца"),
                    ],
                  ),
                ),
                ...events.map((event) {
                  final eventId = int.tryParse(event["id"]?.toString() ?? "0") ?? 0;
                  final title = _eventTitle(event);
                  final date = _prettyDate((event["start_at"] ?? "").toString());
                  final time = _prettyTime(event);
                  
                  return DropdownMenuItem<int>(
                    value: eventId,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "$date ${time.isNotEmpty ? '· $time' : ''}",
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
              onChanged: (value) {
                setState(() {
                  selectedEventId = value;
                  if (value == null) {
                    selectedEventTitle = "Все мероприятия";
                  } else {
                    final event = events.firstWhere(
                      (e) => (int.tryParse(e["id"]?.toString() ?? "0") ?? 0) == value,
                      orElse: () => {},
                    );
                    selectedEventTitle = _eventTitle(event);
                  }
                  _calculateStats();
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8ECF3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatPill(
                icon: PhosphorIcons.checkCircle(PhosphorIconsStyle.bold),
                count: stats["present"] ?? 0,
                color: const Color(0xFF22C55E),
                label: "Присут.",
              ),
              _buildStatPill(
                icon: PhosphorIcons.xCircle(PhosphorIconsStyle.bold),
                count: stats["absent"] ?? 0,
                color: const Color(0xFFEF4444),
                label: "Отсут.",
              ),
              _buildStatPill(
                icon: PhosphorIcons.clock(PhosphorIconsStyle.bold),
                count: stats["late"] ?? 0,
                color: const Color(0xFFF59E0B),
                label: "Болел",
              ),
              _buildStatPill(
                icon: PhosphorIcons.firstAid(PhosphorIconsStyle.bold),
                count: stats["injured"] ?? 0,
                color: const Color(0xFF8B5CF6),
                label: "Травма",
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatPill(
                icon: PhosphorIcons.barbell(PhosphorIconsStyle.bold),
                count: stats["individual"] ?? 0,
                color: const Color(0xFF0EA5E9),
                label: "ИП",
              ),
              _buildStatPill(
                icon: PhosphorIcons.sun(PhosphorIconsStyle.bold),
                count: stats["dayoff"] ?? 0,
                color: const Color(0xFF9CA3AF),
                label: "Выходн.",
              ),
              _buildStatPill(
                icon: PhosphorIcons.users(PhosphorIconsStyle.bold),
                count: stats["total"] ?? 0,
                color: const Color(0xFF111827),
                label: "Всего",
              ),
              Container(
                width: 80,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F8FC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    "${_filteredPlayers.length} из ${players.length}",
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatPill({
    required IconData icon,
    required int count,
    required Color color,
    required String label,
  }) {
    return Container(
      width: 80,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 4),
          Text(
            "$count",
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
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
            itemBuilder: (_) => const [
              PopupMenuItem(value: "all", child: Text("Все статусы")),
              PopupMenuItem(value: "present", child: Text("Присутствует")),
              PopupMenuItem(value: "absent", child: Text("Отсутствует")),
              PopupMenuItem(value: "late", child: Text("Болел")),
              PopupMenuItem(value: "injured", child: Text("Травма")),
              PopupMenuItem(value: "individual", child: Text("Индивид. подготовка")),
              PopupMenuItem(value: "dayoff", child: Text("Выходной")),
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
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlayerCard(Map<String, dynamic> player) {
    final playerId = int.tryParse(player["id"]?.toString() ?? "0") ?? 0;
    final name = _playerName(player);
    final number = (player["number"] ?? "").toString();
    final position = (player["position"] ?? "").toString();
    final photoUrl = player["photo_url"]?.toString();
    
    final status = selectedEventId == null
        ? _getAggregatedStatus(playerId)
        : _getStatusForEvent(playerId, selectedEventId!);
    
    final statusLabelText = statusLabel(status);
    final statusIconData = statusIcon(status);
    final statusColorValue = statusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8ECF3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Аватар
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      statusColorValue.withOpacity(0.2),
                      statusColorValue.withOpacity(0.05),
                    ],
                  ),
                  border: Border.all(color: statusColorValue.withOpacity(0.3)),
                ),
                child: photoUrl?.isNotEmpty == true
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(
                          photoUrl!,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                            child: Icon(
                              statusIconData,
                              size: 28,
                              color: statusColorValue,
                            ),
                          ),
                        ),
                      )
                    : Center(
                        child: Icon(
                          statusIconData,
                          size: 28,
                          color: statusColorValue,
                        ),
                      ),
              ),
              
              const SizedBox(width: 12),
              
              // Информация
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: Color(0xFF111827),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (position.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              position,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF374151),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (number.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              "№$number",
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF92400E),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColorValue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                statusIconData,
                                size: 12,
                                color: statusColorValue,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                statusLabelText,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: statusColorValue,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Кнопки выбора статуса
          if (selectedEventId != null) ...[
            Text(
              "Выберите статус для мероприятия:",
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildStatusButton(
                  active: status == "present",
                  color: const Color(0xFF22C55E),
                  icon: PhosphorIcons.checkCircle(PhosphorIconsStyle.bold),
                  label: "Присутствует",
                  onTap: () => _setStatus(playerId, "present"),
                ),
                _buildStatusButton(
                  active: status == "absent",
                  color: const Color(0xFFEF4444),
                  icon: PhosphorIcons.xCircle(PhosphorIconsStyle.bold),
                  label: "Отсутствует",
                  onTap: () => _setStatus(playerId, "absent"),
                ),
                _buildStatusButton(
                  active: status == "late",
                  color: const Color(0xFFF59E0B),
                  icon: PhosphorIcons.clock(PhosphorIconsStyle.bold),
                  label: "Опоздал",
                  onTap: () => _setStatus(playerId, "late"),
                ),
                _buildStatusButton(
                  active: status == "injured",
                  color: const Color(0xFF8B5CF6),
                  icon: PhosphorIcons.firstAid(PhosphorIconsStyle.bold),
                  label: "Травма",
                  onTap: () => _setStatus(playerId, "injured"),
                ),
                _buildStatusButton(
                  active: status == "individual",
                  color: const Color(0xFF0EA5E9),
                  icon: PhosphorIcons.barbell(PhosphorIconsStyle.bold),
                  label: "ИП",
                  onTap: () => _setStatus(playerId, "individual"),
                ),
                _buildStatusButton(
                  active: status == "dayoff",
                  color: const Color(0xFF9CA3AF),
                  icon: PhosphorIcons.sun(PhosphorIconsStyle.bold),
                  label: "Выходной",
                  onTap: () => _setStatus(playerId, "dayoff"),
                ),
              ],
            ),
          ] else ...[
            Text(
              "Выберите конкретное мероприятие для отметки посещаемости",
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF6B7280),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusButton({
    required bool active,
    required Color color,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: active ? color : color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active ? color : color.withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: active ? Colors.white : color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: active ? Colors.white : color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF3F5F8),
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
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          PhosphorIcons.warningCircle(PhosphorIconsStyle.bold),
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
                          child: const Text("Повторить"),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildMonthSelector(),
                      const SizedBox(height: 16),
                      _buildEventSelector(),
                      const SizedBox(height: 16),
                      _buildStatsBar(),
                      const SizedBox(height: 16),
                      _buildSearchBar(),
                      const SizedBox(height: 16),
                      
                      if (selectedEventId == null)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFF59E0B).withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                PhosphorIcons.info(PhosphorIconsStyle.bold),
                                color: const Color(0xFFF59E0B),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  "Выберите конкретное мероприятие в списке выше, чтобы отметить посещаемость игроков",
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF92400E),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      
                      const SizedBox(height: 16),
                      
                      Text(
                        "Игроки (${_filteredPlayers.length} из ${players.length})",
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF111827),
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      _filteredPlayers.isEmpty
                          ? Container(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                children: [
                                  Icon(
                                    PhosphorIcons.users(PhosphorIconsStyle.bold),
                                    size: 64,
                                    color: const Color(0xFFD1D5DB),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    "Игроки не найдены",
                                    style: TextStyle(
                                      color: Color(0xFF6B7280),
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "Попробуйте изменить поиск или фильтр",
                                    style: const TextStyle(
                                      color: Color(0xFF9CA3AF),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Column(
                              children: _filteredPlayers.map(_buildPlayerCard).toList(),
                            ),
                      
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
    );
  }
}