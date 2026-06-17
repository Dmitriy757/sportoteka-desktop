// lib/presentation/player_screen/player_profile_screen.dart
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:sportoteka/core/app_export.dart';
import 'package:sportoteka/presentation/player_screen/player_id_resolver.dart';
import 'package:sportoteka/presentation/training_screen/add_training_screen.dart';
import 'package:sportoteka/widgets/training_history_widget.dart';
import 'package:url_launcher/url_launcher.dart';

// Цветовые константы в стиле TeamTrainersScreen
class _AppColors {
  static const Color primaryGreen = Color(0xFF00C853);
  static const Color background = Color(0xFFF5F9FF);
  static const Color card = Colors.white;
  static const Color textPrimary = Color(0xFF1A1F2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color error = Color(0xFFEF4444);
  static const Color white = Colors.white;
}

class PlayerProfileScreen extends StatefulWidget {
  final Map<String, dynamic> player;

  const PlayerProfileScreen({super.key, required this.player});

  @override
  State<PlayerProfileScreen> createState() => _PlayerProfileScreenState();
}

class _PlayerProfileScreenState extends State<PlayerProfileScreen> {
  static const String _apiBase = "https://sportotekaapp.ru/api";

  List<Map<String, dynamic>> medicalRecords = [];
  List<String> metrics = [];
  List<String> mediaLinks = [];
  bool isLoading = true;

  // ✅ Diary (Self-assessment)
  List<Map<String, dynamic>> diaryItems = [];
  bool diaryLoading = false;
  String? diaryError;
  int _resolvedPlayerId = 0;

  int _selectedTabIndex = 0;

  // ✅ Training PRO tabs
  int _trainingSubTab = 0; // 0 события, 1 журнал, 2 индивидуальные

  // ✅ Team events (trainings)
  bool eventsLoading = false;
  String? eventsError;
  List<Map<String, dynamic>> teamEvents = [];

  Map<String, dynamic>? selectedEvent;
  Map<String, dynamic>? selectedEventPlayerInfo;

  // ✅ Attendance log
  bool attendanceLoading = false;
  String? attendanceError;
  List<Map<String, dynamic>> attendanceLog = [];

  // ✅ Matches (Game history)
  bool matchesLoading = false;
  String? matchesError;
  List<Map<String, dynamic>> matches = [];

  // ✅ Events search + date filter
  final TextEditingController _eventSearchC = TextEditingController();
  DateTime? _eventFilterDate; // null = all

  // ✅ NEW: team_events from your new PHP endpoint (get_team_events.php)
  bool calendarLoading = false;
  String? calendarError;
  List<Map<String, dynamic>> calendarEvents = [];
  final TextEditingController _calendarSearchC = TextEditingController();
  DateTime? _calendarFrom;
  DateTime? _calendarTo;
  
  

  final List<_CategoryTab> _categoryTabs = const [
    _CategoryTab(0, "Общие", "Основная информация", Icons.person_outline_rounded),
    _CategoryTab(1, "Метрики", "Спортивные показатели", Icons.show_chart_rounded),
    _CategoryTab(2, "Достижения", "Награды и медиа", Icons.military_tech_rounded),
    _CategoryTab(3, "Медкарта", "Медицинские записи", Icons.medical_information_rounded),
    _CategoryTab(4, "Тренировки", "PRO / История", Icons.sports_soccer_rounded),
    _CategoryTab(5, "Матчи", "Игровая история", Icons.emoji_events_rounded),
    _CategoryTab(6, "Дневник", "Самооценка игрока", Icons.menu_book_rounded),
  ];

  // -------------------------
  // helpers
  int _asInt(dynamic v) => v is int ? v : int.tryParse("${v ?? 0}") ?? 0;
  String _asStr(dynamic v) => (v ?? "").toString();

  // ✅ нормализуем дату из любого поля
  String _anyDateStr(Map<String, dynamic> x) {
    final s = _asStr(x["date"] ?? x["day"] ?? x["start_at"] ?? x["event_date"]).trim();
    if (s.isEmpty) return "";
    final tryIso = DateTime.tryParse(s.replaceAll(' ', 'T'));
    if (tryIso != null) return DateFormat('dd.MM.yyyy').format(tryIso);
    return s;
  }

  @override
  void initState() {
    super.initState();
    _loadMedicalRecords();
    _parseSportData();
    _parseMedia();
  }

  @override
  void dispose() {
    _eventSearchC.dispose();
    _calendarSearchC.dispose();
    super.dispose();
  }

  void _parseSportData() {
    final data = widget.player['sport_data'] ?? '';
    if (data is String && data.isNotEmpty) {
      setState(() {
        metrics = data.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      });
    }
  }

  void _parseMedia() {
    final media = widget.player['media'] ?? '';
    if (media is String && media.isNotEmpty) {
      setState(() {
        mediaLinks = media.split(',').map((e) => e.trim()).where((s) => s.isNotEmpty).toList();
      });
    }
  }

  Future<void> _loadMedicalRecords() async {
    final userId = widget.player['user_id'];
    if (userId == null) return;

    setState(() => isLoading = true);

    try {
      final uri = Uri.parse('$_apiBase/medical/get_medical_records.php?user_id=$userId');
      final res = await http.get(uri);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map && data['status'] == 'success') {
          setState(() {
            medicalRecords = List<Map<String, dynamic>>.from(data['records']);
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading medical records: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // =============================
  // ✅ Diary: resolve player_id then fetch diary items
  // =============================

  Future<int> _resolvePlayerId() async {
    if (_resolvedPlayerId > 0) return _resolvedPlayerId;

    final direct = _asInt(widget.player["player_id"] ?? widget.player["id"]);
    if (direct > 0) {
      _resolvedPlayerId = direct;
      return _resolvedPlayerId;
    }

    final userId = _asInt(widget.player["user_id"]);
    if (userId <= 0) return 0;

    final pid = await PlayerIdResolver.resolvePlayerId(apiBase: _apiBase, userId: userId);
    _resolvedPlayerId = pid;
    return _resolvedPlayerId;
  }

  Future<void> _loadDiary() async {
    if (diaryLoading) return;

    setState(() {
      diaryLoading = true;
      diaryError = null;
    });

    try {
      final teamId = _asInt(widget.player["team_id"]);
      if (teamId <= 0) throw "teamId is required";

      final playerId = await _resolvePlayerId();
      if (playerId <= 0) throw "Не удалось определить player_id";

      final url = Uri.parse("$_apiBase/get_player_self_assessments.php?team_id=$teamId&player_id=$playerId");
      final res = await http.get(url).timeout(const Duration(seconds: 12));
      final data = jsonDecode(res.body);

      if (data is! Map || data["success"] != true) {
        throw (data is Map ? (data["message"] ?? "Ошибка загрузки дневника") : "Ошибка загрузки дневника").toString();
      }

      final raw = (data["items"] ?? []) as List;
      final list = raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

      if (!mounted) return;
      setState(() {
        diaryItems = list;
        diaryLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        diaryLoading = false;
        diaryError = e.toString();
        diaryItems = [];
      });
    }
  }

  String _diaryTitle(Map<String, dynamic> x) {
    final t = _asStr(x["title"]).trim();
    return t.isNotEmpty ? t : "Тренировка";
  }

  String _diaryDate(Map<String, dynamic> x) {
    final s = _asStr(x["start_at"]).trim();
    final u = _asStr(x["updated_at"]).trim();
    return s.isNotEmpty ? s : u;
  }

  // =============================
  // ✅ Training PRO: history + attendance log
  // =============================

  DateTime? _parseEventDate(Map<String, dynamic> e) {
    final raw = _asStr(e["date"] ?? e["start_at"] ?? e["day"]).trim();
    if (raw.isEmpty) return null;

    final tryIso = DateTime.tryParse(raw.replaceAll(' ', 'T'));
    if (tryIso != null) return tryIso;

    try {
      return DateFormat('dd.MM.yyyy').parse(raw);
    } catch (_) {
      return null;
    }
  }

  String _eventGroupKey(Map<String, dynamic> e) {
    final d = _parseEventDate(e);
    if (d == null) return "unknown";
    return DateFormat('yyyy-MM-dd').format(DateTime(d.year, d.month, d.day));
  }

  String _eventGroupTitle(String key) {
    if (key == "unknown") return "Без даты";
    final d = DateTime.tryParse(key);
    if (d == null) return "Без даты";
    return DateFormat('dd.MM.yyyy').format(d);
  }

  Future<void> _loadPlayerTrainingHistory({bool force = false}) async {
    if (eventsLoading) return;
    if (!force && teamEvents.isNotEmpty) return;

    setState(() {
      eventsLoading = true;
      eventsError = null;
    });

    try {
      final teamId = _asInt(widget.player["team_id"]);
      if (teamId <= 0) throw "team_id is required";

      final playerId = await _resolvePlayerId();
      if (playerId <= 0) throw "Не удалось определить player_id";

      final now = DateTime.now();
      final from = _eventFilterDate != null ? _eventFilterDate! : DateTime(now.year, now.month, 1);
      final to = _eventFilterDate != null ? _eventFilterDate! : DateTime(now.year, now.month + 1, 0);

      final url = Uri.parse(
        "$_apiBase/get_player_training_history.php"
        "?team_id=$teamId"
        "&player_id=$playerId"
        "&from=${DateFormat('yyyy-MM-dd').format(from)}"
        "&to=${DateFormat('yyyy-MM-dd').format(to)}",
      );

      final res = await http.get(url).timeout(const Duration(seconds: 12));
      final data = jsonDecode(res.body);

      if (data is! Map || data["success"] != true) {
        throw (data is Map ? (data["message"] ?? "Ошибка загрузки истории тренировок") : "Ошибка загрузки истории тренировок")
            .toString();
      }

      final raw = (data["items"] ?? []) as List;
      final list = raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

      if (!mounted) return;
      setState(() {
        teamEvents = list;
        eventsLoading = false;

        if (selectedEvent != null) {
          final selId = _asInt(selectedEvent?["event_id"] ?? selectedEvent?["id"]);
          final stillExists = teamEvents.any((x) => _asInt(x["event_id"] ?? x["id"]) == selId);
          if (!stillExists) {
            selectedEvent = null;
            selectedEventPlayerInfo = null;
          }
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        eventsLoading = false;
        eventsError = e.toString();
        teamEvents = [];
        selectedEvent = null;
        selectedEventPlayerInfo = null;
      });
    }
  }

  Future<void> _loadPlayerInfoForEvent(int eventId) async {
    setState(() => selectedEventPlayerInfo = null);

    try {
      final playerId = await _resolvePlayerId();
      if (playerId <= 0) throw "Не удалось определить player_id";

      final url = Uri.parse("$_apiBase/get_player_event_info.php?event_id=$eventId&player_id=$playerId");
      final res = await http.get(url).timeout(const Duration(seconds: 12));
      final data = jsonDecode(res.body);

      if (data is! Map || data["success"] != true) {
        throw (data is Map ? (data["message"] ?? "Ошибка загрузки оценки") : "Ошибка загрузки оценки").toString();
      }

      final info = Map<String, dynamic>.from(data["info"] ?? {});

      final fallbackRating = _asInt((selectedEvent?["player_rating"] ?? selectedEvent?["rating"] ?? 0));
      if ((info["player_rating"] ?? info["rating"]) == null && fallbackRating > 0) {
        info["player_rating"] = fallbackRating;
      }

      if (!mounted) return;
      setState(() => selectedEventPlayerInfo = info);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        selectedEventPlayerInfo = {"error": e.toString()};
      });
    }
  }

 Future<void> _loadAttendanceLog({bool force = false}) async {
  if (attendanceLoading) return;
  if (!force && attendanceLog.isNotEmpty) return;

  setState(() {
    attendanceLoading = true;
    attendanceError = null;
  });

  try {
    final teamId = _asInt(widget.player["team_id"]);
    if (teamId <= 0) throw "team_id is required";

    final userId = _asInt(widget.player["user_id"]); // ✅ всегда есть
    final playerId = await _resolvePlayerId(); // ✅ может быть 0

    final now = DateTime.now();
    final from = DateTime(now.year, now.month, 1);
    final to = DateTime(now.year, now.month + 1, 0);

    // ✅ ВАЖНО: передаём оба идентификатора
    final url = Uri.parse(
      "$_apiBase/get_player_attendance_log.php"
      "?team_id=$teamId"
      "&player_id=$playerId"
      "&user_id=$userId"
      "&from=${DateFormat('yyyy-MM-dd').format(from)}"
      "&to=${DateFormat('yyyy-MM-dd').format(to)}",
    );

    final res = await http.get(url).timeout(const Duration(seconds: 12));

    // ✅ удобный дебаг (можешь временно оставить)
    debugPrint("ATTENDANCE URL: $url");
    debugPrint("ATTENDANCE RAW: ${res.body}");

    final data = jsonDecode(res.body);

    if (data is! Map || data["success"] != true) {
      throw (data is Map ? (data["message"] ?? "Ошибка загрузки посещений") : "Ошибка загрузки посещений").toString();
    }

    final raw = (data["items"] ?? data["events"] ?? []) as List;
    final list = raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

    list.sort((a, b) {
      final da = DateTime.tryParse(_asStr(a["date"] ?? a["start_at"] ?? a["day"]).replaceAll(' ', 'T')) ?? DateTime(1970);
      final db = DateTime.tryParse(_asStr(b["date"] ?? b["start_at"] ?? b["day"]).replaceAll(' ', 'T')) ?? DateTime(1970);
      return db.compareTo(da);
    });

    if (!mounted) return;
    setState(() {
      attendanceLog = list;
      attendanceLoading = false;
    });
  } catch (e) {
    if (!mounted) return;
    setState(() {
      attendanceLoading = false;
      attendanceError = e.toString();
      attendanceLog = [];
    });
  }
}
  // ✅ Save coach note for player on training event
  Future<void> _saveCoachNoteForEvent({
    required int eventId,
    required int playerId,
    required String note,
  }) async {
    final url = Uri.parse("$_apiBase/save_player_event_note.php");

    final res = await http
        .post(
          url,
          headers: {"Content-Type": "application/x-www-form-urlencoded; charset=utf-8"},
          body: {
            "event_id": "$eventId",
            "player_id": "$playerId",
            "note": note.trim(),
          },
        )
        .timeout(const Duration(seconds: 12));

    final data = jsonDecode(res.body);
    if (data is! Map || data["success"] != true) {
      throw (data is Map ? (data["message"] ?? "Не удалось сохранить заметку") : "Не удалось сохранить заметку").toString();
    }
  }

  void _openCoachNoteSheet() async {
    final ev = selectedEvent;
    if (ev == null) return;

    final eventId = _asInt(ev["event_id"] ?? ev["id"]);
    if (eventId <= 0) return;

    final playerId = await _resolvePlayerId();
    if (playerId <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Не удалось определить player_id")),
      );
      return;
    }

    final currentNote = _asStr(selectedEventPlayerInfo?["coach_note"]).trim();
    final c = TextEditingController(text: currentNote);

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: _AppColors.card,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _AppColors.primaryGreen.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.sticky_note_2_rounded, color: _AppColors.primaryGreen),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        "Заметка тренера к тренировке",
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: _AppColors.textPrimary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F5F8),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TextField(
                    controller: c,
                    minLines: 4,
                    maxLines: 10,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: "Например: что улучшить, на что обратить внимание, домашнее задание…",
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        await _saveCoachNoteForEvent(
                          eventId: eventId,
                          playerId: playerId,
                          note: c.text,
                        );

                        if (!mounted) return;
                        Navigator.pop(ctx);

                        setState(() {
                          selectedEventPlayerInfo = {
                            ...(selectedEventPlayerInfo ?? {}),
                            "coach_note": c.text.trim(),
                          };
                        });

                        await _loadPlayerInfoForEvent(eventId);
                        if (!mounted) return;

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Заметка сохранена")),
                        );
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(e.toString())),
                        );
                      }
                    },
                    icon: const Icon(Icons.save_rounded, size: 18),
                    label: const Text("Сохранить", style: TextStyle(fontWeight: FontWeight.w900)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _AppColors.primaryGreen,
                      foregroundColor: _AppColors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        );
      },
    );
  }

  // =============================
  // ✅ NEW: Team calendar events via your PHP get_team_events.php
  // =============================

  String _fmtYmd(DateTime d) => DateFormat('yyyy-MM-dd').format(DateTime(d.year, d.month, d.day));

  Future<void> _loadTeamCalendar({bool force = false}) async {
    if (calendarLoading) return;
    if (!force && calendarEvents.isNotEmpty) return;

    setState(() {
      calendarLoading = true;
      calendarError = null;
    });

    try {
      final teamId = _asInt(widget.player["team_id"]);
      if (teamId <= 0) throw "team_id is required";

      final clubId = _asInt(widget.player["club_id"] ?? widget.player["clubId"] ?? 0);

      final now = DateTime.now();
      final from = _calendarFrom ?? DateTime(now.year, now.month, 1);
      final to = _calendarTo ?? DateTime(now.year, now.month + 1, 0);

      // IMPORTANT: put correct path to your php file:
      // e.g. https://sportotekaapp.ru/api/get_team_events.php
      final url = Uri.parse(
        "$_apiBase/get_team_events.php"
        "?team_id=$teamId"
        "&club_id=$clubId"
        "&from=${_fmtYmd(from)}"
        "&to=${_fmtYmd(to)}",
      );

      final res = await http.get(url).timeout(const Duration(seconds: 12));
      final data = jsonDecode(res.body);

      if (data is! Map || data["success"] != true) {
        throw (data is Map ? (data["message"] ?? "Ошибка загрузки календаря") : "Ошибка загрузки календаря").toString();
      }

      final raw = (data["items"] ?? []) as List;
      final list = raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

      // sort asc by start_at
      list.sort((a, b) {
        final da = DateTime.tryParse(_asStr(a["start_at"]).replaceAll(' ', 'T')) ?? DateTime(1970);
        final db = DateTime.tryParse(_asStr(b["start_at"]).replaceAll(' ', 'T')) ?? DateTime(1970);
        return da.compareTo(db);
      });

      if (!mounted) return;
      setState(() {
        calendarEvents = list;
        calendarLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        calendarLoading = false;
        calendarError = e.toString();
        calendarEvents = [];
      });
    }
  }

  List<Map<String, dynamic>> _filteredCalendarEvents() {
    final q = _calendarSearchC.text.trim().toLowerCase();
    if (q.isEmpty) return calendarEvents;

    return calendarEvents.where((e) {
      final t = _asStr(e["title"]).toLowerCase();
      final ty = _asStr(e["type"]).toLowerCase();
      final loc = _asStr(e["location"]).toLowerCase();
      final dt = _asStr(e["start_at"]).toLowerCase();
      return t.contains(q) || ty.contains(q) || loc.contains(q) || dt.contains(q);
    }).toList();
  }

  Future<void> _pickCalendarRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1),
      initialDateRange: DateTimeRange(
        start: _calendarFrom ?? DateTime(now.year, now.month, 1),
        end: _calendarTo ?? DateTime(now.year, now.month + 1, 0),
      ),
    );

    if (picked == null) return;

    setState(() {
      _calendarFrom = DateTime(picked.start.year, picked.start.month, picked.start.day);
      _calendarTo = DateTime(picked.end.year, picked.end.month, picked.end.day);
    });

    await _loadTeamCalendar(force: true);
  }

  void _clearCalendarRange() async {
    setState(() {
      _calendarFrom = null;
      _calendarTo = null;
    });
    await _loadTeamCalendar(force: true);
  }

  String _calendarRangeText() {
    final from = _calendarFrom;
    final to = _calendarTo;
    if (from == null && to == null) return "Текущий месяц";
    final f = from != null ? DateFormat('dd.MM.yyyy').format(from) : "…";
    final t = to != null ? DateFormat('dd.MM.yyyy').format(to) : "…";
    return "$f — $t";
  }

  String _fmtTime(String raw) {
    if (raw.trim().isEmpty) return "";
    final d = DateTime.tryParse(raw.replaceAll(' ', 'T'));
    if (d == null) return raw;
    return DateFormat('dd.MM.yyyy • HH:mm').format(d);
    // if you want date-only: DateFormat('dd.MM.yyyy').format(d);
  }

  // =============================
  // ✅ Matches: заглушка пока
  // =============================
  Future<void> _loadMatches({bool force = false}) async {
    if (matchesLoading) return;
    if (!force && matches.isNotEmpty) return;

    setState(() {
      matchesLoading = false;
      matchesError = null;
      matches = matches;
    });
  }

  // =============================
  // Image normalizer
  // =============================
  String? _normalizeImage(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    String url = raw.trim();

    if (url.startsWith("http://") || url.startsWith("https://")) return url;
    if (url.startsWith("//")) return "https:$url";
    if (url.startsWith("sportotekaapp.ru/")) return "https://$url";
    if (url.startsWith("www.sportotekaapp.ru/")) return "https://$url";
    if (url.startsWith("/")) return "https://sportotekaapp.ru$url";
    if (url.startsWith("uploads/")) return "https://sportotekaapp.ru/$url";

    return "https://sportotekaapp.ru/uploads/$url";
  }

  Widget _buildCircleNetworkImage({
    String? imageUrl,
    required double size,
    double borderWidth = 2,
    Color borderColor = _AppColors.primaryGreen,
    Color? glow,
    required Widget fallback,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _AppColors.white,
        boxShadow: glow != null
            ? [
                BoxShadow(
                  color: glow,
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
        border: Border.all(color: borderColor.withOpacity(0.2), width: borderWidth),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: (imageUrl == null || imageUrl.isEmpty)
            ? fallback
            : CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 120),
                placeholder: (context, _) => const Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _AppColors.primaryGreen),
                  ),
                ),
                errorWidget: (context, _, __) => fallback,
              ),
      ),
    );
  }

  // =============================
  // HEADER
  // =============================
  Widget _buildHeader() {
    final photo = _normalizeImage(widget.player["photo"]);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _AppColors.primaryGreen.withOpacity(0.18),
              _AppColors.primaryGreen.withOpacity(0.05),
              _AppColors.white,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: _AppColors.primaryGreen.withOpacity(0.12),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
          border: Border.all(color: _AppColors.primaryGreen.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            _buildCircleNetworkImage(
              imageUrl: photo,
              size: 60,
              borderColor: _AppColors.primaryGreen,
              borderWidth: 2,
              glow: _AppColors.primaryGreen.withOpacity(0.25),
              fallback: Container(
                color: _AppColors.primaryGreen.withOpacity(0.1),
                child: const Icon(Icons.person_outline_rounded, color: _AppColors.primaryGreen, size: 28),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    (widget.player["fullName"] ?? widget.player["full_name"] ?? "Игрок").toString(),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: _AppColors.textPrimary,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    (widget.player["position"] ?? "Позиция не указана").toString(),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: _AppColors.primaryGreen.withOpacity(0.9),
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "№${(widget.player["jersey_number"] ?? '-')} • ${(widget.player["club"] ?? "Клуб не указан")}",
                    style: const TextStyle(
                      color: _AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _AppColors.primaryGreen.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: const Icon(Icons.edit_outlined, color: _AppColors.primaryGreen, size: 20),
                onPressed: () => Get.toNamed(AppRoutes.editPlayerScreen, arguments: widget.player),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =============================
  // TOP TABS
  // =============================
  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: SizedBox(
        height: 76,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _categoryTabs.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final tab = _categoryTabs[i];
            final isActive = tab.index == _selectedTabIndex;

            return InkWell(
              onTap: () async {
                setState(() => _selectedTabIndex = tab.index);

                if (tab.index == 6 && diaryItems.isEmpty && !diaryLoading) {
                  await _loadDiary();
                }

                if (tab.index == 4) {
                  // for PRO tab – preload both
                  if (_trainingSubTab == 0) await _loadPlayerTrainingHistory(force: true);
                  if (_trainingSubTab == 1) await _loadAttendanceLog(force: true);
                  // NEW calendar: load too (optional)
                  await _loadTeamCalendar(force: false);
                }

                if (tab.index == 5) {
                  await _loadMatches();
                }
              },
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 110,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: isActive ? _AppColors.primaryGreen.withOpacity(0.14) : _AppColors.card,
                  border: Border.all(
                    color: isActive ? _AppColors.primaryGreen.withOpacity(0.35) : Colors.grey.shade200,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _AppColors.primaryGreen.withOpacity(isActive ? 0.16 : 0.10),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(tab.icon, color: _AppColors.primaryGreen, size: 18),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tab.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: _AppColors.textPrimary,
                        fontSize: 11,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tab.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 8,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedTabIndex) {
      case 0:
        return _buildGeneralTab();
      case 1:
        return _buildMetricsTab();
      case 2:
        return _buildAchievementsTab();
      case 3:
        return _buildMedicalTab();
      case 4:
        return _buildTrainingTab();
      case 5:
        return _buildMatchesTab();
      case 6:
        return _buildDiaryTab();
      default:
        return _buildGeneralTab();
    }
  }

  // =============================
  // ОБЩАЯ ИНФОРМАЦИЯ
  // =============================
  Widget _buildGeneralTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildInfoCard(
          title: "Основная информация",
          icon: Icons.person_outline_rounded,
          children: [
            _buildInfoRow("Возраст", _asStr(widget.player["age"]).isNotEmpty ? _asStr(widget.player["age"]) : "-"),
            _buildInfoRow(
              "Дата рождения",
              _asStr(widget.player["birthDate"]).isNotEmpty ? _asStr(widget.player["birthDate"]) : "-",
            ),
            _buildInfoRow(
              "Гражданство",
              _asStr(widget.player["nationality"]).isNotEmpty ? _asStr(widget.player["nationality"]) : "-",
            ),
            _buildInfoRow("Клуб", _asStr(widget.player["club"]).isNotEmpty ? _asStr(widget.player["club"]) : "-"),
            _buildInfoRow("Позиция", _asStr(widget.player["position"]).isNotEmpty ? _asStr(widget.player["position"]) : "-"),
            _buildInfoRow(
              "Игровой номер",
              _asStr(widget.player["jersey_number"]).isNotEmpty ? _asStr(widget.player["jersey_number"]) : "-",
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildActionButton(
          icon: Icons.fitness_center_rounded,
          text: "Назначить тренировку",
          onPressed: _assignTraining,
        ),
      ],
    );
  }

  // =============================
  // МЕТРИКИ
  // =============================
  Widget _buildMetricsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionBanner(
          title: "Спортивные показатели",
          subtitle: "Текущие метрики игрока",
          icon: Icons.show_chart_rounded,
          count: metrics.length,
        ),
        const SizedBox(height: 16),
        if (metrics.isEmpty)
          _buildEmptyState(
            icon: Icons.analytics_outlined,
            message: "Нет данных о метриках",
          )
        else
          ...metrics
              .map((metric) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _buildMetricCard(metric),
                  ))
              .toList(),
      ],
    );
  }

  Widget _buildMetricCard(String metric) {
    final parts = metric.split(':');
    if (parts.length < 2) return const SizedBox();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _AppColors.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _AppColors.primaryGreen.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              parts[0].trim().toLowerCase().contains('скорость')
                  ? Icons.speed_rounded
                  : parts[0].trim().toLowerCase().contains('сила')
                      ? Icons.fitness_center_rounded
                      : parts[0].trim().toLowerCase().contains('выносливость')
                          ? Icons.timer_rounded
                          : Icons.trending_up_rounded,
              color: _AppColors.primaryGreen,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  parts[0].trim(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: _AppColors.textPrimary,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  parts.sublist(1).join(':').trim(),
                  style: const TextStyle(
                    fontSize: 13,
                    color: _AppColors.textSecondary,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =============================
  // ДОСТИЖЕНИЯ И МЕДИА
  // =============================
  Widget _buildAchievementsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildInfoCard(
          title: "Достижения",
          icon: Icons.military_tech_rounded,
          children: [
            Text(
              _asStr(widget.player["achievements"]).isNotEmpty ? _asStr(widget.player["achievements"]) : "Нет достижений",
              style: const TextStyle(fontSize: 14, color: _AppColors.textSecondary, height: 1.4),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildSectionBanner(
          title: "Медиа",
          subtitle: "Фото и видео материалы",
          icon: Icons.collections_rounded,
          count: mediaLinks.length,
        ),
        const SizedBox(height: 16),
        if (mediaLinks.isEmpty)
          _buildEmptyState(
            icon: Icons.photo_camera_back_rounded,
            message: "Нет медиа материалов",
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: mediaLinks.map(_buildMediaItem).toList(),
          ),
      ],
    );
  }

  Widget _buildMediaItem(String url) {
    final isImage =
        url.toLowerCase().endsWith('.jpg') || url.toLowerCase().endsWith('.jpeg') || url.toLowerCase().endsWith('.png');
    final isVideo = url.toLowerCase().endsWith('.mp4') || url.toLowerCase().endsWith('.mov');

    final norm = _normalizeImage(url) ?? url;

    return GestureDetector(
      onTap: () => launchUrl(Uri.parse(norm), mode: LaunchMode.externalApplication),
      child: Container(
        width: (MediaQuery.of(context).size.width - 48) / 3,
        height: (MediaQuery.of(context).size.width - 48) / 3,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
          image: isImage
              ? DecorationImage(
                  image: NetworkImage(norm),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: isVideo
            ? Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Center(
                  child: Icon(
                    Icons.play_circle_filled_rounded,
                    color: _AppColors.white,
                    size: 32,
                  ),
                ),
              )
            : null,
      ),
    );
  }

  // =============================
  // МЕДКАРТА
  // =============================
  Widget _buildMedicalTab() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator(color: _AppColors.primaryGreen));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildAddButton(),
        ),
        _buildSectionBanner(
          title: "Медицинская карта",
          subtitle: "История записей",
          icon: Icons.medical_information_rounded,
          count: medicalRecords.length,
        ),
        const SizedBox(height: 16),
        if (medicalRecords.isEmpty)
          _buildEmptyState(
            icon: Icons.medical_services_rounded,
            message: "Нет медицинских записей",
            action: TextButton(
              onPressed: _showAddMedicalRecordDialog,
              style: TextButton.styleFrom(foregroundColor: _AppColors.primaryGreen),
              child: const Text("Добавить запись"),
            ),
          )
        else
          ...medicalRecords.map((record) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildMedicalRecordCard(record),
              )),
      ],
    );
  }

  Widget _buildAddButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _showAddMedicalRecordDialog,
        icon: const Icon(Icons.add_rounded, color: _AppColors.white, size: 18),
        label: const Text(
          "Добавить медицинскую запись",
          style: TextStyle(
            color: _AppColors.white,
            fontWeight: FontWeight.w900,
            fontSize: 13,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _AppColors.primaryGreen,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 2,
        ),
      ),
    );
  }

  Widget _buildMedicalRecordCard(Map<String, dynamic> record) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _AppColors.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _AppColors.primaryGreen.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  record['type'] == 'Травма'
                      ? Icons.healing_rounded
                      : record['type'] == 'Осмотр'
                          ? Icons.health_and_safety_rounded
                          : Icons.medical_information_rounded,
                  color: _AppColors.primaryGreen,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      (record['type'] ?? 'Запись').toString(),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: _AppColors.textPrimary,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      (record['title'] ?? 'Без названия').toString(),
                      style: const TextStyle(
                        fontSize: 13,
                        color: _AppColors.textSecondary,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') _showEditMedicalRecordDialog(record);
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 16, color: _AppColors.primaryGreen),
                        SizedBox(width: 6),
                        Text("Редактировать", style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                ],
                child: Container(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.more_vert_rounded, size: 18, color: _AppColors.textSecondary.withOpacity(0.6)),
                ),
              ),
            ],
          ),
          if (record['value'] != null && record['value'].toString().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _AppColors.primaryGreen.withOpacity(0.04),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                record['value'].toString(),
                style: const TextStyle(fontSize: 13, color: _AppColors.textPrimary, height: 1.3),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.calendar_today_rounded, size: 12, color: _AppColors.textTertiary),
              const SizedBox(width: 4),
              Text(
                "Дата: ${(record['date'] ?? 'Не указана').toString()}",
                style: const TextStyle(fontSize: 11, color: _AppColors.textTertiary, height: 1.2),
              ),
            ],
          ),
          if (record['file_url'] != null && record['file_url'].toString().isNotEmpty) ...[
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: () {
                final url = '$_apiBase/../uploads/medical/${record['file_url']}';
                launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
              },
              icon: const Icon(Icons.attach_file_rounded, size: 14),
              label: const Text('Просмотреть вложение', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: _AppColors.primaryGreen,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                backgroundColor: _AppColors.primaryGreen.withOpacity(0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // =============================
  // ✅ ТРЕНИРОВКИ (PRO)
  // =============================
  Widget _buildTrainingTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionBanner(
          title: "Тренировки PRO",
          subtitle: "События, журнал посещения, календарь команды и индивидуальные занятия",
          icon: Icons.sports_soccer_rounded,
          count: 0,
        ),
        const SizedBox(height: 12),
        _buildTrainingSubTabs(),
        const SizedBox(height: 16),
        if (_trainingSubTab == 0) _buildEventsSubTab(),
        if (_trainingSubTab == 1) _buildAttendanceSubTab(),
        if (_trainingSubTab == 2) _buildIndividualSubTab(),
        const SizedBox(height: 14),
if (_trainingSubTab == 0) _buildTeamCalendarBlock(),
      ],
    );
  }

  Widget _buildTrainingSubTabs() {
    Widget tab(String title, String sub, IconData icon, int index) {
      final active = _trainingSubTab == index;

      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            setState(() => _trainingSubTab = index);
            if (index == 0) await _loadPlayerTrainingHistory(force: true);
            if (index == 1) await _loadAttendanceLog(force: true);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: active ? _AppColors.primaryGreen.withOpacity(0.14) : _AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: active ? _AppColors.primaryGreen.withOpacity(0.35) : Colors.grey.shade200,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _AppColors.primaryGreen.withOpacity(active ? 0.18 : 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: _AppColors.primaryGreen, size: 18),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: _AppColors.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        sub,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 10, color: _AppColors.textSecondary),
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

    return Row(
      children: [
        tab("События", "Поиск/дата/оценки", Icons.event_note_rounded, 0),
        const SizedBox(width: 10),
        tab("Журнал", "Посещение/опоздания", Icons.fact_check_rounded, 1),
        const SizedBox(width: 10),
        tab("Индив.", "Личные тренировки", Icons.fitness_center_rounded, 2),
      ],
    );
  }

  // ---------- Events filters ----------
  String _eventDateText() {
    if (_eventFilterDate == null) return "Любая дата";
    return DateFormat('dd.MM.yyyy').format(_eventFilterDate!);
  }

  Future<void> _pickEventDate() async {
    final now = DateTime.now();
    final initial = _eventFilterDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1),
    );
    if (picked == null) return;

    setState(() {
      _eventFilterDate = DateTime(picked.year, picked.month, picked.day);
      selectedEvent = null;
      selectedEventPlayerInfo = null;
    });

    await _loadPlayerTrainingHistory(force: true);
  }

  void _clearEventDate() async {
    setState(() {
      _eventFilterDate = null;
      selectedEvent = null;
      selectedEventPlayerInfo = null;
    });
    await _loadPlayerTrainingHistory(force: true);
  }

  List<Map<String, dynamic>> _filteredEvents() {
    final q = _eventSearchC.text.trim().toLowerCase();
    final dateKey = _eventFilterDate != null ? DateFormat('yyyy-MM-dd').format(_eventFilterDate!) : null;

    return teamEvents.where((e) {
      final title = _asStr(e["title"]).toLowerCase();
      final date = _asStr(e["date"] ?? e["start_at"] ?? e["day"]).toLowerCase();

      final okQ = q.isEmpty ? true : (title.contains(q) || date.contains(q));
      final okD = dateKey == null ? true : date.contains(dateKey);

      return okQ && okD;
    }).toList();
  }

  List<Widget> _buildEventsGroupedByDate(List<Map<String, dynamic>> list) {
    list.sort((a, b) {
      final da = _parseEventDate(a) ?? DateTime(1970);
      final db = _parseEventDate(b) ?? DateTime(1970);
      return db.compareTo(da);
    });

    final groups = <String, List<Map<String, dynamic>>>{};
    for (final e in list) {
      final k = _eventGroupKey(e);
      groups.putIfAbsent(k, () => []).add(e);
    }

    final keys = groups.keys.toList()
      ..sort((a, b) {
        final da = DateTime.tryParse(a) ?? DateTime(1970);
        final db = DateTime.tryParse(b) ?? DateTime(1970);
        return db.compareTo(da);
      });

    final out = <Widget>[];

    for (final k in keys) {
      out.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
          child: Row(
            children: [
              Text(
                _eventGroupTitle(k),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  color: _AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: Divider(color: Colors.grey.shade200, height: 1)),
            ],
          ),
        ),
      );

      for (final e in groups[k]!) {
        final id = _asInt(e["event_id"] ?? e["id"]);
        final dateRaw = _asStr(e["date"] ?? e["start_at"] ?? e["day"]);
        final title = _asStr(e["title"]).isEmpty ? "Тренировка" : _asStr(e["title"]);
        final active = selectedEvent != null && _asInt(selectedEvent?["event_id"] ?? selectedEvent?["id"]) == id;

        final rating = _asInt(e["player_rating"] ?? e["rating"] ?? 0).clamp(0, 5);

        out.add(
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () async {
                setState(() {
                  selectedEvent = e;
                  selectedEventPlayerInfo = null;
                });
                await _loadPlayerInfoForEvent(id);
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: active ? _AppColors.primaryGreen.withOpacity(0.08) : _AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: active ? _AppColors.primaryGreen.withOpacity(0.25) : Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _AppColors.primaryGreen.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.sports_soccer_rounded, color: _AppColors.primaryGreen),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: _AppColors.textPrimary)),
                          const SizedBox(height: 4),
                          Text(
                            dateRaw.isEmpty ? _eventGroupTitle(k) : dateRaw,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: _AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: rating > 0 ? Colors.amber.withOpacity(0.12) : Colors.grey.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: (rating > 0 ? Colors.amber : Colors.grey).withOpacity(0.25)),
                      ),
                      child: Text(
                        rating > 0 ? "★ $rating/5" : "★ -",
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          color: rating > 0 ? Colors.amber.shade800 : _AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right_rounded, color: _AppColors.textSecondary),
                  ],
                ),
              ),
            ),
          ),
        );
      }
    }

    return out;
  }

  Widget _buildEventsSubTab() {
    if (eventsLoading) {
      return const Center(child: CircularProgressIndicator(color: _AppColors.primaryGreen));
    }
    if (eventsError != null) {
      return _buildEmptyState(
        icon: Icons.error_outline_rounded,
        message: eventsError!,
        action: TextButton(
          onPressed: () => _loadPlayerTrainingHistory(force: true),
          style: TextButton.styleFrom(foregroundColor: _AppColors.primaryGreen),
          child: const Text("Повторить"),
        ),
      );
    }

    final list = _filteredEvents();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _pickEventDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: _AppColors.primaryGreen.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: _AppColors.primaryGreen.withOpacity(0.18)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_month_rounded, color: _AppColors.primaryGreen, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _eventDateText(),
                                style: const TextStyle(fontWeight: FontWeight.w900, color: _AppColors.textPrimary, fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_eventFilterDate != null)
                              IconButton(
                                onPressed: _clearEventDate,
                                icon: const Icon(Icons.close_rounded, size: 18),
                                color: _AppColors.textSecondary,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              )
                            else
                              const Icon(Icons.keyboard_arrow_down_rounded, color: _AppColors.textSecondary),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    tooltip: "Обновить",
                    onPressed: () => _loadPlayerTrainingHistory(force: true),
                    icon: const Icon(Icons.refresh_rounded, color: _AppColors.primaryGreen),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F5F8),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextField(
                  controller: _eventSearchC,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    hintText: "Поиск тренировок (название, дата)…",
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (teamEvents.isEmpty)
          _buildEmptyState(
            icon: Icons.event_busy_rounded,
            message: "Тренировок за период нет.",
            action: TextButton(
              onPressed: () => _loadPlayerTrainingHistory(force: true),
              style: TextButton.styleFrom(foregroundColor: _AppColors.primaryGreen),
              child: const Text("Обновить"),
            ),
          )
        else if (list.isEmpty)
          _buildEmptyState(
            icon: Icons.search_off_rounded,
            message: "Ничего не найдено по фильтрам.",
            action: TextButton(
              onPressed: () {
                setState(() {
                  _eventSearchC.clear();
                  _eventFilterDate = null;
                  selectedEvent = null;
                  selectedEventPlayerInfo = null;
                });
                _loadPlayerTrainingHistory(force: true);
              },
              style: TextButton.styleFrom(foregroundColor: _AppColors.primaryGreen),
              child: const Text("Сбросить фильтры"),
            ),
          )
        else
          ..._buildEventsGroupedByDate(list),
        const SizedBox(height: 12),
        if (selectedEvent != null) _buildSelectedEventPlayerInfoCard(),
      ],
    );
  }

  Widget _buildSelectedEventPlayerInfoCard() {
    if (selectedEventPlayerInfo == null) {
      return const Padding(
        padding: EdgeInsets.only(top: 6),
        child: Center(child: CircularProgressIndicator(color: _AppColors.primaryGreen)),
      );
    }

    if (selectedEventPlayerInfo?["error"] != null) {
      return _buildEmptyState(
        icon: Icons.error_outline_rounded,
        message: _asStr(selectedEventPlayerInfo?["error"]),
      );
    }

    final status = _asStr(selectedEventPlayerInfo?["status"]);
    final late = _asInt(selectedEventPlayerInfo?["late_minutes"]);
    final reason = _asStr(selectedEventPlayerInfo?["reason"]).trim();

    final playerRating = selectedEventPlayerInfo?["player_rating"] ?? selectedEventPlayerInfo?["rating"];
    final coachRating = selectedEventPlayerInfo?["coach_rating"];
    final coachComment = _asStr(selectedEventPlayerInfo?["coach_comment"]).trim();
    final coachNote = _asStr(selectedEventPlayerInfo?["coach_note"]).trim();

   final meta = _statusMeta(status, late);
final statusText = meta.text;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _AppColors.primaryGreen.withOpacity(0.12)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  "Тренировка — оценки и комментарий",
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: _AppColors.textPrimary),
                ),
              ),
              TextButton.icon(
                onPressed: _openCoachNoteSheet,
                icon: const Icon(Icons.edit_note_rounded, size: 18),
                label: const Text("Заметка", style: TextStyle(fontWeight: FontWeight.w900)),
                style: TextButton.styleFrom(
                  foregroundColor: _AppColors.primaryGreen,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  backgroundColor: _AppColors.primaryGreen.withOpacity(0.08),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pillInfo(Icons.fact_check_rounded, "Статус", statusText),
              _pillInfo(
                Icons.star_rounded,
                "Оценка игрока",
                playerRating == null ? "-" : "★ ${_asInt(playerRating)}/5",
                color: Colors.amber.shade700,
              ),
              _pillInfo(
                Icons.workspace_premium_rounded,
                "Оценка тренера",
                coachRating == null ? "-" : "★ ${_asInt(coachRating)}/5",
                color: Colors.blue.shade700,
              ),
              if (reason.isNotEmpty) _pillInfo(Icons.info_outline_rounded, "Причина", reason),
            ],
          ),
          if (coachComment.isNotEmpty) ...[
            const SizedBox(height: 12),
            _noteBox(icon: Icons.chat_bubble_outline_rounded, title: "Комментарий тренера", text: coachComment),
          ],
          const SizedBox(height: 12),
          _noteBox(
            icon: Icons.sticky_note_2_outlined,
            title: "Заметка тренера (для себя)",
            text: coachNote.isEmpty ? "Пока нет заметки. Нажмите «Заметка», чтобы добавить." : coachNote,
            subtleWhenEmpty: coachNote.isEmpty,
          ),
        ],
      ),
    );
  }

  ({String text, Color color, IconData icon}) _statusMeta(String st, int lateMinutes) {
  switch (st) {
    case "present":
      return (text: "Присутствовал", color: _AppColors.primaryGreen, icon: Icons.check_circle_rounded);

    case "absent":
      return (text: "Отсутствовал", color: _AppColors.error, icon: Icons.cancel_rounded);

    case "late":
      return (
        text: lateMinutes > 0 ? "Опоздал на $lateMinutes мин" : "Опоздал",
        color: Colors.orange.shade700,
        icon: Icons.timer_rounded
      );

    case "injured":
      return (text: "Травма", color: Colors.purple.shade700, icon: Icons.healing_rounded);

    case "individual":
      return (text: "Индивидуально", color: Colors.blue.shade700, icon: Icons.person_rounded);

    case "dayoff":
      return (text: "Выходной", color: Colors.blueGrey.shade700, icon: Icons.beach_access_rounded);

    default:
      return (text: "Не отмечено", color: Colors.grey.shade600, icon: Icons.help_outline_rounded);
  }
}

  Widget _buildAttendanceSubTab() {
    if (attendanceLoading) {
      return const Center(child: CircularProgressIndicator(color: _AppColors.primaryGreen));
    }
    if (attendanceError != null) {
      return _buildEmptyState(
        icon: Icons.error_outline_rounded,
        message: attendanceError!,
        action: TextButton(
          onPressed: () => _loadAttendanceLog(force: true),
          style: TextButton.styleFrom(foregroundColor: _AppColors.primaryGreen),
          child: const Text("Повторить"),
        ),
      );
    }

    final total = attendanceLog.length;
    final missed = attendanceLog.where((x) => _asStr(x["status"]) == "absent").length;
    final lateCount = attendanceLog.where((x) => _asStr(x["status"]) == "late").length;

    int sumCoach = 0;
    int cntCoach = 0;
    for (final x in attendanceLog) {
      final r = x["coach_rating"];
      if (r != null) {
        sumCoach += _asInt(r);
        cntCoach++;
      }
    }
    final avgCoach = cntCoach == 0 ? 0.0 : (sumCoach / cntCoach);

    int discipline = (100 - (missed * 12 + lateCount * 6));
    if (discipline < 0) discipline = 0;
    if (discipline > 100) discipline = 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoCard(
          title: "Календарь активности PRO",
          icon: Icons.fact_check_rounded,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _pillInfo(Icons.list_alt_rounded, "Тренировок", "$total"),
                _pillInfo(Icons.block_rounded, "Пропуски", "$missed", color: _AppColors.error),
                _pillInfo(Icons.timer_rounded, "Опоздания", "$lateCount", color: Colors.orange.shade700),
                _pillInfo(
                  Icons.workspace_premium_rounded,
                  "Оценка тренера",
                  cntCoach == 0 ? "-" : avgCoach.toStringAsFixed(1),
                  color: Colors.blue.shade700,
                ),
                _pillInfo(Icons.shield_rounded, "Дисциплина", "$discipline/100", color: Colors.blueGrey.shade700),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (attendanceLog.isEmpty)
          _buildEmptyState(
            icon: Icons.event_available_rounded,
            message: "Нет записей посещаемости за период.",
            action: TextButton(
              onPressed: () => _loadAttendanceLog(force: true),
              style: TextButton.styleFrom(foregroundColor: _AppColors.primaryGreen),
              child: const Text("Обновить"),
            ),
          )
        else
          ...attendanceLog.map((x) {
              final eventTitle = _asStr(x["title"] ?? x["event_title"] ?? x["name"]).trim();
            final date = _anyDateStr(x);
            final st = _asStr(x["status"]).trim();
            final lateMin = _asInt(x["late_minutes"]);
            final reason = _asStr(x["reason"]).trim();

            final coachRating = x["coach_rating"];
            final coachComment = _asStr(x["coach_comment"]).trim();

            // ✅ note и coach_note — разные
            final attendanceNote = _asStr(x["note"]).trim();
            final coachNote = _asStr(x["coach_note"]).trim();

            final meta = _statusMeta(st, lateMin);

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
  children: [
    Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: meta.color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(meta.icon, color: meta.color),
    ),
    const SizedBox(width: 10),
    Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            date.isEmpty ? "Дата не указана" : date,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: _AppColors.textPrimary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          if (eventTitle.isNotEmpty)
            Text(
              eventTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: _AppColors.textPrimary,
                fontSize: 12,
              ),
            ),
          const SizedBox(height: 4),
          Text(
            meta.text,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: _AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    ),

    // ✅ вместо рейтинга справа — иконка посещения
    Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: meta.color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: meta.color.withOpacity(0.20)),
      ),
      child: Icon(meta.icon, color: meta.color, size: 18),
    ),
  ],
),
                  if (reason.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _noteBox(icon: Icons.info_outline_rounded, title: "Причина", text: reason),
                  ],
                  if (coachComment.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _noteBox(icon: Icons.chat_bubble_outline_rounded, title: "Комментарий тренера", text: coachComment),
                  ],
                  if (attendanceNote.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _noteBox(icon: Icons.fact_check_outlined, title: "Заметка посещения", text: attendanceNote),
                  ],
                  if (coachNote.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _noteBox(icon: Icons.sticky_note_2_outlined, title: "Заметка тренера", text: coachNote),
                  ],
                ],
              ),
            );
          }).toList(),
      ],
    );
  }

  Widget _buildIndividualSubTab() {
    return Column(
      children: [
        _buildSectionBanner(
          title: "Индивидуальные тренировки",
          subtitle: "Личные занятия игрока",
          icon: Icons.fitness_center_rounded,
          count: 0,
        ),
        const SizedBox(height: 12),
        TrainingHistoryWidget(playerId: _asInt(widget.player["user_id"])),
      ],
    );
  }

  // ✅ NEW: Team calendar block UI
  Widget _buildTeamCalendarBlock() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _AppColors.primaryGreen.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.calendar_month_rounded, color: _AppColors.primaryGreen),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  "Календарь команды",
                  style: TextStyle(fontWeight: FontWeight.w900, color: _AppColors.textPrimary, fontSize: 14),
                ),
              ),
              IconButton(
                tooltip: "Обновить",
                onPressed: () => _loadTeamCalendar(force: true),
                icon: const Icon(Icons.refresh_rounded, color: _AppColors.primaryGreen),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _pickCalendarRange,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: _AppColors.primaryGreen.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _AppColors.primaryGreen.withOpacity(0.18)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.date_range_rounded, color: _AppColors.primaryGreen, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _calendarRangeText(),
                            style: const TextStyle(fontWeight: FontWeight.w900, color: _AppColors.textPrimary, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_calendarFrom != null || _calendarTo != null)
                          IconButton(
                            onPressed: _clearCalendarRange,
                            icon: const Icon(Icons.close_rounded, size: 18),
                            color: _AppColors.textSecondary,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          )
                        else
                          const Icon(Icons.keyboard_arrow_down_rounded, color: _AppColors.textSecondary),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF3F5F8),
              borderRadius: BorderRadius.circular(14),
            ),
            child: TextField(
              controller: _calendarSearchC,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                hintText: "Поиск по календарю (тип, название, место)…",
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (calendarLoading)
            const Center(child: CircularProgressIndicator(color: _AppColors.primaryGreen))
          else if (calendarError != null)
            _buildEmptyState(
              icon: Icons.error_outline_rounded,
              message: calendarError!,
              action: TextButton(
                onPressed: () => _loadTeamCalendar(force: true),
                style: TextButton.styleFrom(foregroundColor: _AppColors.primaryGreen),
                child: const Text("Повторить"),
              ),
            )
          else if (_filteredCalendarEvents().isEmpty)
            _buildEmptyState(
              icon: Icons.event_busy_rounded,
              message: "Событий команды за период нет.",
              action: TextButton(
                onPressed: () => _loadTeamCalendar(force: true),
                style: TextButton.styleFrom(foregroundColor: _AppColors.primaryGreen),
                child: const Text("Обновить"),
              ),
            )
          else
            ..._filteredCalendarEvents().map((e) => _buildCalendarEventCard(e)).toList(),
        ],
      ),
    );
  }

  Widget _buildCalendarEventCard(Map<String, dynamic> e) {
    final type = _asStr(e["type"]).trim();
    final title = _asStr(e["title"]).trim().isEmpty ? "Событие" : _asStr(e["title"]).trim();
    final startAt = _fmtTime(_asStr(e["start_at"]));
    final endAt = _fmtTime(_asStr(e["end_at"]));
    final location = _asStr(e["location"]).trim();
    final notes = _asStr(e["notes"]).trim();

    IconData icon = Icons.event_note_rounded;
    if (type.toLowerCase().contains("train")) icon = Icons.sports_soccer_rounded;
    if (type.toLowerCase().contains("match")) icon = Icons.emoji_events_rounded;
    if (type.toLowerCase().contains("meet")) icon = Icons.groups_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _AppColors.primaryGreen.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: _AppColors.primaryGreen),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: _AppColors.textPrimary)),
                const SizedBox(height: 4),
                Text(
                  endAt.isEmpty ? startAt : "$startAt — $endAt",
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: _AppColors.textSecondary),
                ),
                if (location.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    "Место: $location",
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: _AppColors.textSecondary),
                  ),
                ],
                if (type.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _pillInfo(Icons.category_rounded, "Тип", type),
                ],
                if (notes.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _noteBox(icon: Icons.info_outline_rounded, title: "Заметки", text: notes),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =============================
  // ✅ МАТЧИ
  // =============================
  Widget _buildMatchesTab() {
    if (matchesLoading) {
      return const Center(child: CircularProgressIndicator(color: _AppColors.primaryGreen));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionBanner(
          title: "Игровая история (Матчи)",
          subtitle: "Соперник • турнир • минуты • голы/ассисты • рейтинг • разбор",
          icon: Icons.emoji_events_rounded,
          count: matches.length,
        ),
        const SizedBox(height: 12),
        if (matchesError != null)
          _buildEmptyState(icon: Icons.error_outline_rounded, message: matchesError!)
        else if (matches.isEmpty)
          _buildEmptyState(
            icon: Icons.sports_soccer_rounded,
            message: "Матчей пока нет. (Подключим из базы — и появится история.)",
          )
        else
          ...matches.map((m) => _buildMatchCard(m)).toList(),
      ],
    );
  }

  Widget _buildMatchCard(Map<String, dynamic> m) {
    final opponent = _asStr(m["opponent"]).isEmpty ? "-" : _asStr(m["opponent"]);
    final tournament = _asStr(m["tournament"]).isEmpty ? "-" : _asStr(m["tournament"]);
    final minutes = _asStr(m["minutes"]).isEmpty ? "-" : _asStr(m["minutes"]);
    final ga = _asStr(m["goals_assists"]).isEmpty ? "-" : _asStr(m["goals_assists"]);
    final cards = _asStr(m["cards"]).isEmpty ? "-" : _asStr(m["cards"]);
    final rating = _asStr(m["rating"]).isEmpty ? "-" : _asStr(m["rating"]);
    final video = _asStr(m["video_url"]).trim();
    final coachComment = _asStr(m["coach_comment"]).trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Соперник: $opponent", style: const TextStyle(fontWeight: FontWeight.w900, color: _AppColors.textPrimary)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pillInfo(Icons.emoji_events_rounded, "Турнир", tournament),
              _pillInfo(Icons.timer_rounded, "Время", "$minutes мин"),
              _pillInfo(Icons.sports_soccer_rounded, "Г/А", ga),
              _pillInfo(Icons.warning_amber_rounded, "Карточки", cards, color: Colors.orange.shade700),
              _pillInfo(Icons.star_rounded, "Рейтинг", rating, color: Colors.amber.shade700),
            ],
          ),
          if (coachComment.isNotEmpty) ...[
            const SizedBox(height: 10),
            _noteBox(icon: Icons.chat_bubble_outline_rounded, title: "Комментарий тренера", text: coachComment),
          ],
          if (video.isNotEmpty) ...[
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: () => launchUrl(Uri.parse(video), mode: LaunchMode.externalApplication),
              icon: const Icon(Icons.play_circle_outline_rounded, size: 18),
              label: const Text("Видео разбор", style: TextStyle(fontWeight: FontWeight.w900)),
              style: TextButton.styleFrom(
                foregroundColor: _AppColors.primaryGreen,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                backgroundColor: _AppColors.primaryGreen.withOpacity(0.08),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // =============================
  // ✅ ДНЕВНИК (САМООЦЕНКА)
  // =============================
  Widget _buildDiaryTab() {
    if (diaryLoading) {
      return const Center(child: CircularProgressIndicator(color: _AppColors.primaryGreen));
    }

    if (diaryError != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildEmptyState(
            icon: Icons.error_outline_rounded,
            message: diaryError!,
            action: TextButton(
              onPressed: _loadDiary,
              style: TextButton.styleFrom(foregroundColor: _AppColors.primaryGreen),
              child: const Text("Повторить"),
            ),
          ),
        ],
      );
    }

    if (diaryItems.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionBanner(
            title: "Дневник футболиста",
            subtitle: "Оценки и заметки после тренировок",
            icon: Icons.menu_book_rounded,
            count: 0,
          ),
          const SizedBox(height: 16),
          _buildEmptyState(
            icon: Icons.menu_book_rounded,
            message: "Самооценок пока нет. После тренировок игрок будет оставлять оценки — здесь появится история.",
            action: TextButton(
              onPressed: _loadDiary,
              style: TextButton.styleFrom(foregroundColor: _AppColors.primaryGreen),
              child: const Text("Обновить"),
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionBanner(
          title: "Дневник футболиста",
          subtitle: "Оценки и заметки после тренировок",
          icon: Icons.menu_book_rounded,
          count: diaryItems.length,
        ),
        const SizedBox(height: 16),
        ...diaryItems.map((x) {
          final rating = _asInt(x["rating"]).clamp(0, 5);
          final note = _asStr(x["note"]).trim();
          final title = _diaryTitle(x);
          final date = _diaryDate(x);

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _AppColors.card,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: _AppColors.primaryGreen.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.star_rounded, color: _AppColors.primaryGreen, size: 22),
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
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: _AppColors.textPrimary),
                          ),
                          const SizedBox(height: 4),
                          Text(date,
                              style: const TextStyle(color: _AppColors.textSecondary, fontWeight: FontWeight.w700, fontSize: 12)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _AppColors.primaryGreen.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: _AppColors.primaryGreen.withOpacity(0.25)),
                      ),
                      child: Text(
                        "★ $rating/5",
                        style: const TextStyle(color: _AppColors.primaryGreen, fontWeight: FontWeight.w900, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                if (note.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _AppColors.primaryGreen.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _AppColors.primaryGreen.withOpacity(0.08)),
                    ),
                    child: Text(note, style: const TextStyle(color: _AppColors.textPrimary, fontSize: 13, height: 1.35)),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _loadDiary,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text("Обновить", style: TextStyle(fontWeight: FontWeight.w900)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _AppColors.primaryGreen,
              foregroundColor: _AppColors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  // =============================
  // COMMON UI
  // =============================
  Widget _noteBox({
    required IconData icon,
    required String title,
    required String text,
    bool subtleWhenEmpty = false,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _AppColors.primaryGreen.withOpacity(subtleWhenEmpty ? 0.03 : 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _AppColors.primaryGreen.withOpacity(0.10)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: _AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w900, color: _AppColors.textPrimary, fontSize: 12)),
                const SizedBox(height: 6),
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: subtleWhenEmpty ? _AppColors.textSecondary : _AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pillInfo(IconData icon, String title, String value, {Color? color}) {
    final c = color ?? _AppColors.primaryGreen;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: c.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: c),
          const SizedBox(width: 6),
          Text("$title: ", style: const TextStyle(fontSize: 12, color: _AppColors.textSecondary, fontWeight: FontWeight.w700)),
          Text(value, style: TextStyle(fontSize: 12, color: c, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildSectionBanner({
    required String title,
    required String subtitle,
    required IconData icon,
    required int count,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _AppColors.primaryGreen.withOpacity(0.18),
            _AppColors.primaryGreen.withOpacity(0.06),
            _AppColors.card,
          ],
        ),
        border: Border.all(color: _AppColors.primaryGreen.withOpacity(0.16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _AppColors.primaryGreen.withOpacity(0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: _AppColors.primaryGreen, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: _AppColors.textPrimary, height: 1.2),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _AppColors.textSecondary, height: 1.2),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _AppColors.primaryGreen.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              "$count",
              style: const TextStyle(fontWeight: FontWeight.w900, color: _AppColors.primaryGreen, fontSize: 12, height: 1.2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _AppColors.card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _AppColors.primaryGreen.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: _AppColors.primaryGreen, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _AppColors.textPrimary, height: 1.2),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: 20,
            margin: const EdgeInsets.only(right: 10, top: 2),
            decoration: BoxDecoration(
              color: _AppColors.primaryGreen,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 14, color: _AppColors.textSecondary, height: 1.3),
                children: [
                  TextSpan(text: "$label: ", style: const TextStyle(fontWeight: FontWeight.w900, color: _AppColors.textPrimary)),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required String text, required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: _AppColors.white, size: 18),
        label: Text(text, style: const TextStyle(color: _AppColors.white, fontWeight: FontWeight.w900, fontSize: 14)),
        style: ElevatedButton.styleFrom(
          backgroundColor: _AppColors.primaryGreen,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 2,
        ),
      ),
    );
  }

  Widget _buildEmptyState({required IconData icon, required String message, Widget? action}) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(message,
              style: const TextStyle(color: _AppColors.textSecondary, fontSize: 13, height: 1.3), textAlign: TextAlign.center),
          if (action != null) ...[
            const SizedBox(height: 12),
            action,
          ],
        ],
      ),
    );
  }

  // =============================
  // DIALOGS (medical)
  // =============================
  void _showAddMedicalRecordDialog() {
    final typeController = TextEditingController();
    final titleController = TextEditingController();
    final valueController = TextEditingController();
    final commentController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    XFile? selectedFile;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) => Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(height: 16),
                  const Text('Добавить запись',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _AppColors.textPrimary)),
                  const SizedBox(height: 16),
                  _buildStyledTextField(typeController, 'Тип записи (Травма, Осмотр...)'),
                  const SizedBox(height: 10),
                  _buildStyledTextField(titleController, 'Название'),
                  const SizedBox(height: 10),
                  _buildStyledTextField(valueController, 'Значение / Описание'),
                  const SizedBox(height: 10),
                  _buildStyledTextField(commentController, 'Комментарий'),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFF3F5F8), borderRadius: BorderRadius.circular(10)),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Дата: ${DateFormat('dd.MM.yyyy').format(selectedDate)}',
                            style: const TextStyle(color: _AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.calendar_today_rounded, color: _AppColors.primaryGreen, size: 18),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) setModalState(() => selectedDate = picked);
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final picker = ImagePicker();
                      final file = await picker.pickImage(source: ImageSource.gallery);
                      if (file != null) setModalState(() => selectedFile = file);
                    },
                    icon: const Icon(Icons.attach_file_rounded, size: 16),
                    label: Text(selectedFile != null ? 'Файл выбран' : 'Прикрепить файл', style: const TextStyle(fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _AppColors.primaryGreen.withOpacity(0.08),
                      foregroundColor: _AppColors.primaryGreen,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      minimumSize: const Size(double.infinity, 40),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final uri = Uri.parse('$_apiBase/medical/add_record.php');
                        final request = http.MultipartRequest('POST', uri);

                        request.fields['user_id'] = widget.player['user_id'].toString();
                        request.fields['type'] = typeController.text.trim();
                        request.fields['title'] = titleController.text.trim();
                        request.fields['value'] = valueController.text.trim();
                        request.fields['date'] = DateFormat('yyyy-MM-dd').format(selectedDate);
                        request.fields['comment'] = commentController.text.trim();

                        if (selectedFile != null) {
                          request.files.add(await http.MultipartFile.fromPath('file', selectedFile!.path));
                        }

                        try {
                          final response = await request.send();
                          if (response.statusCode == 200) {
                            if (!mounted) return;
                            Navigator.pop(context);
                            _loadMedicalRecords();
                          }
                        } catch (e) {
                          debugPrint('Error adding medical record: $e');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _AppColors.primaryGreen,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Сохранить',
                          style: TextStyle(color: _AppColors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showEditMedicalRecordDialog(Map<String, dynamic> record) {
    final typeController = TextEditingController(text: record['type']?.toString() ?? '');
    final titleController = TextEditingController(text: record['title']?.toString() ?? '');
    final valueController = TextEditingController(text: record['value']?.toString() ?? '');
    final commentController = TextEditingController(text: record['comment']?.toString() ?? '');
    DateTime selectedDate = DateTime.tryParse(record['date']?.toString() ?? '') ?? DateTime.now();
    XFile? selectedFile;

    final recordId = record['id'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: StatefulBuilder(
          builder: (context, setModalState) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 16,
              right: 16,
              top: 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                const Text('Редактировать',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _AppColors.textPrimary)),
                const SizedBox(height: 16),
                _buildStyledTextField(typeController, 'Тип записи'),
                const SizedBox(height: 10),
                _buildStyledTextField(titleController, 'Название'),
                const SizedBox(height: 10),
                _buildStyledTextField(valueController, 'Значение'),
                const SizedBox(height: 10),
                _buildStyledTextField(commentController, 'Комментарий'),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFF3F5F8), borderRadius: BorderRadius.circular(10)),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Дата: ${DateFormat('dd.MM.yyyy').format(selectedDate)}',
                          style: const TextStyle(color: _AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 13),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.calendar_today_rounded, color: _AppColors.primaryGreen, size: 18),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) setModalState(() => selectedDate = picked);
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: () async {
                    final picker = ImagePicker();
                    final file = await picker.pickImage(source: ImageSource.gallery);
                    if (file != null) setModalState(() => selectedFile = file);
                  },
                  icon: const Icon(Icons.attach_file_rounded, size: 16),
                  label: Text(selectedFile != null ? 'Новый файл выбран' : 'Заменить файл', style: const TextStyle(fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _AppColors.primaryGreen.withOpacity(0.08),
                    foregroundColor: _AppColors.primaryGreen,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    minimumSize: const Size(double.infinity, 40),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final uri = Uri.parse('$_apiBase/medical/update_record.php');
                      final request = http.MultipartRequest('POST', uri);

                      request.fields['id'] = recordId.toString();
                      request.fields['type'] = typeController.text.trim();
                      request.fields['title'] = titleController.text.trim();
                      request.fields['value'] = valueController.text.trim();
                      request.fields['date'] = DateFormat('yyyy-MM-dd').format(selectedDate);
                      request.fields['comment'] = commentController.text.trim();

                      if (selectedFile != null) {
                        request.files.add(await http.MultipartFile.fromPath('file', selectedFile!.path));
                      }

                      try {
                        final response = await request.send();
                        if (response.statusCode == 200) {
                          if (!mounted) return;
                          Navigator.pop(context);
                          _loadMedicalRecords();
                        }
                      } catch (e) {
                        debugPrint('Error updating medical record: $e');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _AppColors.primaryGreen,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Сохранить',
                        style: TextStyle(color: _AppColors.white, fontWeight: FontWeight.w900, fontSize: 14)),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStyledTextField(TextEditingController controller, String hint) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFFF3F5F8), borderRadius: BorderRadius.circular(10)),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: _AppColors.textTertiary, fontSize: 13),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        style: const TextStyle(fontSize: 14),
      ),
    );
  }

  void _assignTraining() {
    final playerId = widget.player['user_id'];
    if (playerId != null) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => AddTrainingScreen(playerId: playerId)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _AppColors.background,
      appBar: AppBar(
        backgroundColor: _AppColors.card,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          color: _AppColors.textPrimary,
          onPressed: () => Get.back(),
        ),
        title: const Text("Профиль игрока", style: TextStyle(fontWeight: FontWeight.w900, color: _AppColors.textPrimary, fontSize: 16)),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: _AppColors.primaryGreen, size: 20),
            onPressed: () async {
              _loadMedicalRecords();
              _parseSportData();
              _parseMedia();

              if (_selectedTabIndex == 6) {
                await _loadDiary();
              }

              if (_selectedTabIndex == 4) {
                if (_trainingSubTab == 0) await _loadPlayerTrainingHistory(force: true);
                if (_trainingSubTab == 1) await _loadAttendanceLog(force: true);
                await _loadTeamCalendar(force: true);
              }

              if (_selectedTabIndex == 5) {
                await _loadMatches(force: true);
              }
            },
            padding: EdgeInsets.zero,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }
}

class _CategoryTab {
  final int index;
  final String title;
  final String subtitle;
  final IconData icon;

  const _CategoryTab(this.index, this.title, this.subtitle, this.icon);
}