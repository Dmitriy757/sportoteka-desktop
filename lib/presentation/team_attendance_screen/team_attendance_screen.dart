// lib/presentation/team_attendance_screen/team_attendance_screen.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';

class TeamAttendanceScreen extends StatefulWidget {
  final int teamId;
  final int eventId;
  final String eventTitle;
  final String teamName;

  const TeamAttendanceScreen({
    super.key,
    required this.teamId,
    required this.eventId,
    required this.eventTitle,
    required this.teamName,
  });

  @override
  State<TeamAttendanceScreen> createState() => _TeamAttendanceScreenState();
}

class _TeamAttendanceScreenState extends State<TeamAttendanceScreen> {
  static const String apiBase = "https://sportotekaapp.ru/api";
  static const String playersUrl = "$apiBase/get_players_by_team.php";
  static const String getAttendanceUrl = "$apiBase/get_team_attendance.php";
  static const String setAttendanceUrl = "$apiBase/set_team_attendance.php";

  bool loading = true;
  bool saving = false;
  List<Map<String, dynamic>> players = [];
  
  /// player_id -> {status, note}
  Map<String, Map<String, dynamic>> attendance = {};

  // ✅ поиск + фильтр
  final TextEditingController searchC = TextEditingController();
  String filter = "all"; // all | present | absent | late | injured | individual | dayoff

  Color get primary => Theme.of(context).colorScheme.primary;

  @override
  void initState() {
    super.initState();
    loadAll();
    searchC.addListener(() {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    searchC.dispose();
    super.dispose();
  }

  Future<void> loadAll() async {
    if (!mounted) return;
    setState(() => loading = true);
    
    try {
      await Future.wait([fetchPlayers(), fetchAttendance()]);
    } catch (_) {}
    
    if (!mounted) return;
    setState(() => loading = false);
  }

  Future<void> fetchPlayers() async {
    final uri = Uri.parse(playersUrl).replace(queryParameters: {
      "team_id": widget.teamId.toString(),
    });
    final res = await http.get(uri);
    final data = jsonDecode(res.body);
    
    if (data["status"] != "success") {
      Get.snackbar("Ошибка", data["message"]?.toString() ?? "Не удалось загрузить игроков");
      throw Exception("players error");
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

  Future<void> fetchAttendance() async {
    final uri = Uri.parse(getAttendanceUrl).replace(queryParameters: {
      "event_id": widget.eventId.toString(),
    });
    final res = await http.get(uri);
    final data = jsonDecode(res.body);
    
    if (data["success"] != true) {
      Get.snackbar("Ошибка", data["message"]?.toString() ?? "Не удалось загрузить посещаемость");
      throw Exception("attendance error");
    }
    
    final items = (data["items"] as Map?) ?? {};
    attendance = items.map((k, v) => MapEntry(k.toString(), Map<String, dynamic>.from(v)));
  }

  String statusOfPlayer(int playerId) {
    final key = playerId.toString();
    return (attendance[key]?["status"] ?? "present").toString();
  }

  // ✅ Используем существующие иконки из PhosphorIcons
  IconData statusIcon(String s) {
    switch (s) {
      case "absent": return PhosphorIcons.xCircle;
      case "late": return PhosphorIcons.clock;
      case "injured": return PhosphorIcons.firstAid;
      case "individual": return PhosphorIcons.barbell; // Используем barbell вместо dumbbell
      case "dayoff": return PhosphorIcons.sun; // Используем sun вместо palmTree
      default: return PhosphorIcons.checkCircle;
    }
  }

  String statusLabel(String s) {
    switch (s) {
      case "absent": return "Отсутствовал";
      case "late": return "Опоздал";
      case "injured": return "Травма";
      case "individual": return "Индивид. подготовка";
      case "dayoff": return "Выходной";
      default: return "Присутствовал";
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

  Future<void> setStatus(int playerId, String status) async {
    final markedBy = await PrefUtils.getUserId() ?? 0;
    
    if (!mounted) return;
    setState(() {
      attendance[playerId.toString()] = {
        "status": status,
        "note": attendance[playerId.toString()]?["note"] ?? "",
      };
      saving = true;
    });
    
    try {
      final res = await http.post(
        Uri.parse(setAttendanceUrl),
        body: {
          "team_id": widget.teamId.toString(),
          "event_id": widget.eventId.toString(),
          "player_id": playerId.toString(),
          "status": status,
          "note": (attendance[playerId.toString()]?["note"] ?? "").toString(),
          "marked_by": markedBy.toString(),
        }
      );
      
      final data = jsonDecode(res.body);
      if (data["success"] != true) {
        Get.snackbar("Ошибка", data["message"]?.toString() ?? "Не удалось сохранить");
      }
    } catch (_) {
      Get.snackbar("Ошибка сети", "Не удалось сохранить статус");
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> editNote(int playerId) async {
    final key = playerId.toString();
    final c = TextEditingController(text: (attendance[key]?["note"] ?? "").toString());
    
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Комментарий"),
        content: TextField(
          controller: c,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: "Например: заболел, семейные причины…",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Отмена")
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Сохранить")
          ),
        ],
      ),
    );
    
    if (ok != true) return;
    
    if (!mounted) return;
    setState(() {
      attendance[key] = {
        "status": attendance[key]?["status"] ?? "present",
        "note": c.text.trim(),
      };
    });
    
    await setStatus(playerId, statusOfPlayer(playerId));
  }

  Map<String, int> _calcStats() {
    int present = 0, absent = 0, late = 0, injured = 0, individual = 0, dayoff = 0;
    
    for (final p in players) {
      final pid = int.tryParse(p["id"].toString()) ?? 0;
      final st = statusOfPlayer(pid);
      
      switch (st) {
        case "absent": absent++; break;
        case "late": late++; break;
        case "injured": injured++; break;
        case "individual": individual++; break;
        case "dayoff": dayoff++; break;
        default: present++;
      }
    }
    
    return {
      "present": present,
      "absent": absent,
      "late": late,
      "injured": injured,
      "individual": individual,
      "dayoff": dayoff,
    };
  }

  List<Map<String, dynamic>> get _filteredPlayers {
    final q = searchC.text.trim().toLowerCase();
    
    return players.where((p) {
      final pid = int.tryParse(p["id"].toString()) ?? 0;
      final st = statusOfPlayer(pid);
      
      if (filter != "all" && st != filter) return false;
      
      if (q.isNotEmpty) {
        final fullName = (p["fullName"] ?? "${p["first_name"] ?? ""} ${p["last_name"] ?? ""}")
          .toString().toLowerCase();
        final number = (p["number"] ?? "").toString().toLowerCase();
        final position = (p["position"] ?? "").toString().toLowerCase();
        
        if (!fullName.contains(q) && !number.contains(q) && !position.contains(q)) {
          return false;
        }
      }
      
      return true;
    }).toList();
  }

  // ✅ отметить всех присутствуют
  Future<void> markAllPresent() async {
    if (players.isEmpty) return;
    
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Отметить всех?"),
        content: const Text("Поставим всем игрокам статус «Присутствует»."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Отмена")
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Отметить")
          ),
        ],
      ),
    );
    
    if (ok != true) return;
    
    final markedBy = await PrefUtils.getUserId() ?? 0;
    if (!mounted) return;
    setState(() => saving = true);
    
    try {
      for (final p in players) {
        final pid = int.tryParse(p["id"].toString()) ?? 0;
        attendance[pid.toString()] = {
          "status": "present",
          "note": attendance[pid.toString()]?["note"] ?? "",
        };
      }
      
      if (mounted) setState(() {});
      
      for (final p in players) {
        final pid = int.tryParse(p["id"].toString()) ?? 0;
        final note = (attendance[pid.toString()]?["note"] ?? "").toString();
        
        final res = await http.post(
          Uri.parse(setAttendanceUrl),
          body: {
            "team_id": widget.teamId.toString(),
            "event_id": widget.eventId.toString(),
            "player_id": pid.toString(),
            "status": "present",
            "note": note,
            "marked_by": markedBy.toString(),
          }
        );
        
        final data = jsonDecode(res.body);
        if (data["success"] != true) {
          Get.snackbar("Внимание", "Не у всех сохранилось. Игрок ID=$pid");
        }
      }
      
      Get.snackbar("Готово", "Все отмечены как присутствующие");
    } catch (_) {
      Get.snackbar("Ошибка сети", "Не удалось отметить всех");
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  // ✅ CSV export
  String _escapeCsv(String s) {
    final v = s.replaceAll('\r', ' ').replaceAll('\n', ' ').trim();
    final needQuotes = v.contains(',') || v.contains('"') || v.contains(';');
    final escaped = v.replaceAll('"', '""');
    return needQuotes ? '"$escaped"' : escaped;
  }

  String buildCsv() {
    final buffer = StringBuffer();
    
    // Заголовки с русскими названиями
    buffer.writeln('Команда,Мероприятие,Игрок ID,ФИО,Номер,Позиция,Статус,Комментарий');
    
    for (final p in players) {
      final pid = int.tryParse(p["id"].toString()) ?? 0;
      final fullName = (p["fullName"] ?? "${p["first_name"] ?? ""} ${p["last_name"] ?? ""}").toString();
      final number = (p["number"] ?? "").toString();
      final position = (p["position"] ?? "").toString();
      final st = statusOfPlayer(pid);
      final note = (attendance[pid.toString()]?["note"] ?? "").toString();
      
      // Русские названия статусов для отчета
      String statusLabel;
      switch (st) {
        case "present": statusLabel = "Присутствовал";
        case "absent": statusLabel = "Отсутствовал";
        case "late": statusLabel = "Опоздал";
        case "injured": statusLabel = "Травма";
        case "individual": statusLabel = "Индивид. подготовка";
        case "dayoff": statusLabel = "Выходной";
        default: statusLabel = st;
      }
      
      buffer.writeln([
        _escapeCsv(widget.teamName),
        _escapeCsv(widget.eventTitle),
        pid,
        _escapeCsv(fullName),
        _escapeCsv(number),
        _escapeCsv(position),
        _escapeCsv(statusLabel),
        _escapeCsv(note),
      ].join(','));
    }
    
    return buffer.toString();
  }

  Future<void> exportCsv() async {
    if (players.isEmpty) {
      Get.snackbar("Пусто", "Нет игроков для экспорта");
      return;
    }
    
    final csv = buildCsv();
    
    try {
      final dir = await getTemporaryDirectory();
      final safeTeam = widget.teamName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final safeTitle = widget.eventTitle.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final file = File(
        '${dir.path}/посещаемость_${safeTeam}_${safeTitle}_${DateTime.now().millisecondsSinceEpoch}.csv',
      );
      
      await file.writeAsString(csv, flush: true, encoding: utf8);
      
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv')],
        subject: 'Посещаемость CSV — ${widget.teamName}',
        text: 'Экспорт посещаемости: ${widget.teamName} / ${widget.eventTitle}',
      );
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: csv));
      Get.snackbar("CSV скопирован", "Файл сохранен в буфер обмена");
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = const Color(0xFFF3F5F8);
    final stats = _calcStats();
    final filtered = _filteredPlayers;
    
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          "Посещаемость — ${widget.teamName}",
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          if (saving)
            const Padding(
              padding: EdgeInsets.only(right: 10),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2)
                ),
              ),
            ),
          IconButton(
            tooltip: "Отметить всех присутствуют",
            onPressed: saving ? null : markAllPresent,
            icon: Icon(PhosphorIcons.userCheck),
          ),
          IconButton(
            tooltip: "Экспорт в CSV",
            onPressed: saving ? null : exportCsv,
            icon: Icon(PhosphorIcons.fileCsv),
          ),
          IconButton(
            tooltip: "Обновить",
            onPressed: saving ? null : loadAll,
            icon: Icon(PhosphorIcons.arrowClockwise),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.eventTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF111827),
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _StatsBar(
                        present: stats["present"] ?? 0,
                        absent: stats["absent"] ?? 0,
                        late: stats["late"] ?? 0,
                        injured: stats["injured"] ?? 0,
                        individual: stats["individual"] ?? 0,
                        dayoff: stats["dayoff"] ?? 0,
                        selected: filter,
                        onTap: (val) => setState(() => filter = val),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: _SearchField(controller: searchC)),
                          const SizedBox(width: 10),
                          _FilterButton(
                            primary: primary,
                            value: filter,
                            onChanged: (v) => setState(() => filter = v),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Показано: ${filtered.length} / ${players.length}",
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w700,
                          fontSize: 12
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(
                          child: Text(
                            "Ничего не найдено",
                            style: TextStyle(color: Color(0xFF6B7280)),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final p = filtered[i];
                            final pid = int.tryParse(p["id"].toString()) ?? 0;
                            final fullName = (p["fullName"] ?? "${p["first_name"] ?? ""} ${p["last_name"] ?? ""}")
                                .toString();
                            final pos = (p["position"] ?? "").toString();
                            final number = (p["number"] ?? "").toString();
                            final photoUrl = p["photo_url"]?.toString();
                            
                            final st = statusOfPlayer(pid);
                            final note = (attendance[pid.toString()]?["note"] ?? "").toString();
                            
                            return _PlayerAttendanceCard(
                              statusColor: statusColor(st),
                              status: st,
                              title: fullName,
                              subtitleParts: [
                                if (pos.isNotEmpty) pos,
                                if (number.isNotEmpty) "№$number",
                                statusLabel(st),
                              ],
                              photoUrl: photoUrl,
                              note: note,
                              onEditNote: () => editNote(pid),
                              onSetPresent: () => setStatus(pid, "present"),
                              onSetAbsent: () => setStatus(pid, "absent"),
                              onSetLate: () => setStatus(pid, "late"),
                              onSetInjured: () => setStatus(pid, "injured"),
                              onSetIndividual: () => setStatus(pid, "individual"),
                              onSetDayOff: () => setStatus(pid, "dayoff"),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  
  const _SearchField({required this.controller});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8ECF3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 18,
            offset: const Offset(0, 10)
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: "Поиск игрока…",
          prefixIcon: Icon(PhosphorIcons.magnifyingGlass),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  final Color primary;
  final String value;
  final ValueChanged<String> onChanged;
  
  const _FilterButton({
    required this.primary,
    required this.value,
    required this.onChanged,
  });
  
  String _label(String v) {
    switch (v) {
      case "present": return "Есть";
      case "absent": return "Нет";
      case "late": return "Опозд.";
      case "injured": return "Травма";
      case "individual": return "ИП";
      case "dayoff": return "Выходн.";
      default: return "Все";
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: PopupMenuButton<String>(
        onSelected: onChanged,
        itemBuilder: (_) => const [
          PopupMenuItem(value: "all", child: Text("Все")),
          PopupMenuItem(value: "present", child: Text("Присутствует")),
          PopupMenuItem(value: "absent", child: Text("Отсутствует")),
          PopupMenuItem(value: "late", child: Text("Опоздал")),
          PopupMenuItem(value: "injured", child: Text("Травма")),
          PopupMenuItem(value: "individual", child: Text("Индивид. подготовка")),
          PopupMenuItem(value: "dayoff", child: Text("Выходной")),
        ],
        child: Ink(
          width: 56,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE8ECF3)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 18,
                offset: const Offset(0, 10)
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                PhosphorIcons.funnel,
                color: primary,
              ),
              const SizedBox(height: 2),
              Text(
                _label(value),
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
                maxLines: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsBar extends StatelessWidget {
  final int present;
  final int absent;
  final int late;
  final int injured;
  final int individual;
  final int dayoff;
  final String selected;
  final ValueChanged<String> onTap;
  
  const _StatsBar({
    required this.present,
    required this.absent,
    required this.late,
    required this.injured,
    required this.individual,
    required this.dayoff,
    required this.selected,
    required this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    Widget pill(String key, IconData icon, String text, Color border) {
      final active = selected == key;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => onTap(key),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: active ? border.withOpacity(0.10) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: active ? border.withOpacity(0.35) : const Color(0xFFE8ECF3),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 18,
                  offset: const Offset(0, 10)
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: border),
                const SizedBox(width: 6),
                Text(
                  text,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    return Row(
      children: [
        pill("all", PhosphorIcons.stack, "Все", const Color(0xFF111827)),
        const SizedBox(width: 8),
        pill("present", PhosphorIcons.checkCircle, "$present", const Color(0xFF22C55E)),
        const SizedBox(width: 8),
        pill("absent", PhosphorIcons.xCircle, "$absent", const Color(0xFFEF4444)),
        const SizedBox(width: 8),
        pill("late", PhosphorIcons.clock, "$late", const Color(0xFFF59E0B)),
        const SizedBox(width: 8),
        pill("injured", PhosphorIcons.firstAid, "$injured", const Color(0xFF8B5CF6)),
        const SizedBox(width: 8),
        pill("individual", PhosphorIcons.barbell, "$individual", const Color(0xFF0EA5E9)),
        const SizedBox(width: 8),
        pill("dayoff", PhosphorIcons.sun, "$dayoff", const Color(0xFF9CA3AF)),
      ],
    );
  }
}

class _PlayerAttendanceCard extends StatelessWidget {
  final Color statusColor;
  final String status;
  final String title;
  final List<String> subtitleParts;
  final String? photoUrl;
  final String note;
  final VoidCallback onEditNote;
  final VoidCallback onSetPresent;
  final VoidCallback onSetAbsent;
  final VoidCallback onSetLate;
  final VoidCallback onSetInjured;
  final VoidCallback onSetIndividual;
  final VoidCallback onSetDayOff;
  
  const _PlayerAttendanceCard({
    required this.statusColor,
    required this.status,
    required this.title,
    required this.subtitleParts,
    this.photoUrl,
    required this.note,
    required this.onEditNote,
    required this.onSetPresent,
    required this.onSetAbsent,
    required this.onSetLate,
    required this.onSetInjured,
    required this.onSetIndividual,
    required this.onSetDayOff,
  });
  
  IconData _statusIcon(String s) {
    switch (s) {
      case "absent": return PhosphorIcons.xCircle;
      case "late": return PhosphorIcons.clock;
      case "injured": return PhosphorIcons.firstAid;
      case "individual": return PhosphorIcons.barbell;
      case "dayoff": return PhosphorIcons.sun;
      default: return PhosphorIcons.checkCircle;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final subtitle = subtitleParts.where((e) => e.trim().isNotEmpty).join(" • ");
    
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8ECF3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 22,
            offset: const Offset(0, 12)
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Аватар игрока
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      statusColor.withOpacity(0.22),
                      statusColor.withOpacity(0.06),
                    ],
                  ),
                  border: Border.all(
                    color: statusColor.withOpacity(0.22),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withOpacity(0.12),
                      blurRadius: 18,
                      offset: const Offset(0, 10)
                    ),
                  ],
                ),
                child: Center(
                  child: photoUrl != null && photoUrl!.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            photoUrl!,
                            width: 38,
                            height: 38,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(
                              _statusIcon(status),
                              color: statusColor,
                              size: 22,
                            ),
                          ),
                        )
                      : Icon(
                          _statusIcon(status),
                          color: statusColor,
                          size: 22,
                        ),
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
                        fontSize: 14
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w700
                      ),
                    ),
                  ],
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: onEditNote,
                  child: Ink(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6F8FC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE8ECF3)),
                    ),
                    child: Icon(
                      PhosphorIcons.chatTeardropDots,
                      size: 20,
                      color: const Color(0xFF111827),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (note.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF6F8FC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE8ECF3)),
              ),
              child: Text(
                note,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.25,
                  color: Color(0xFF374151),
                  fontWeight: FontWeight.w600
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatusChip(
                  active: status == "present",
                  color: const Color(0xFF22C55E),
                  icon: PhosphorIcons.checkCircle,
                  text: "Есть",
                  onTap: onSetPresent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatusChip(
                  active: status == "absent",
                  color: const Color(0xFFEF4444),
                  icon: PhosphorIcons.xCircle,
                  text: "Нет",
                  onTap: onSetAbsent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatusChip(
                  active: status == "late",
                  color: const Color(0xFFF59E0B),
                  icon: PhosphorIcons.clock,
                  text: "Опозд.",
                  onTap: onSetLate,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatusChip(
                  active: status == "injured",
                  color: const Color(0xFF8B5CF6),
                  icon: PhosphorIcons.firstAid,
                  text: "Травма",
                  onTap: onSetInjured,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatusChip(
                  active: status == "individual",
                  color: const Color(0xFF0EA5E9),
                  icon: PhosphorIcons.barbell,
                  text: "ИП",
                  onTap: onSetIndividual,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatusChip(
                  active: status == "dayoff",
                  color: const Color(0xFF9CA3AF),
                  icon: PhosphorIcons.sun,
                  text: "Выходн.",
                  onTap: onSetDayOff,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool active;
  final Color color;
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  
  const _StatusChip({
    required this.active,
    required this.color,
    required this.icon,
    required this.text,
    required this.onTap,
  });
  
  @override
  Widget build(BuildContext context) {
    final bg = active ? color : color.withOpacity(0.10);
    final fg = active ? Colors.white : color;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(active ? 0.0 : 0.25)),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 10)
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 6),
              Text(
                text,
                style: TextStyle(
                  color: fg,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}