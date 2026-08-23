/-шолдх=з-хэimport 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:sportoteka/core/utils/pref_utils.dart';

class MyAttendanceScreen extends StatefulWidget {
  final int teamId;
  final String teamName;

  const MyAttendanceScreen({
    super.key,
    required this.teamId,
    required this.teamName,
  });

  @override
  State<MyAttendanceScreen> createState() => _MyAttendanceScreenState();
}

class _MyAttendanceScreenState extends State<MyAttendanceScreen> {
  static const String apiBase = "https://sportotekaapp.ru/api";
  static const String getPlayerAttendanceUrl = "$apiBase/get_player_attendance.php";

  bool loading = true;
  String? error;

  int playerId = 0;

  DateTime selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  List<Map<String, dynamic>> items = [];

  final TextEditingController searchC = TextEditingController();
  String filter = "all";

  // ===== style (как в твоём AttendanceScreen) =====
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
    searchC.addListener(() => mounted ? setState(() {}) : null);
    _init();
  }

  Future<void> _init() async {
    playerId = await PrefUtils.getUserId() ?? 0; // игрок = залогиненный userId
    await _load();
  }

  @override
  void dispose() {
    searchC.dispose();
    super.dispose();
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
    return "${ru[selectedMonth.month - 1]} ${selectedMonth.year}";
  }

  String _prettyDate(String iso) {
    if (iso.length < 10) return iso;
    final d = iso.substring(8, 10);
    final m = iso.substring(5, 7);
    return "$d.$m";
  }

  String _prettyTime(String iso) {
    if (iso.length < 16) return "";
    return iso.substring(11, 16);
  }

  String _eventTitle(Map<String, dynamic> e) {
    final t = (e["title"] ?? "").toString().trim();
    return t.isNotEmpty ? t : "Мероприятие";
  }

  Color _getStatusColor(String status) {
    switch (status) {
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
      default:
        return const Color(0xFF22C55E);
    }
  }

  String _getStatusSymbol(String status) {
    switch (status) {
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
      default:
        return "П";
    }
  }

  String _getStatusFullText(String status) {
    switch (status) {
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
      default:
        return "Присутствует";
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      loading = true;
      error = null;
      items = [];
    });

    try {
      if (playerId <= 0) {
        throw Exception("Нет playerId (userId). Проверь PrefUtils.getUserId()");
      }

      final from = "${selectedMonth.year}-${selectedMonth.month.toString().padLeft(2, '0')}-01";
      final lastDay = _daysInMonth(selectedMonth);
      final to = "${selectedMonth.year}-${selectedMonth.month.toString().padLeft(2, '0')}-${lastDay.toString().padLeft(2, '0')}";

      final uri = Uri.parse(getPlayerAttendanceUrl).replace(queryParameters: {
        "player_id": playerId.toString(),
        "team_id": widget.teamId.toString(),
        "from": from,
        "to": to,
      });

      final res = await http.get(uri);
      final data = jsonDecode(res.body);

      if (data["success"] != true) {
        throw Exception(data["message"]?.toString() ?? "Не удалось загрузить");
      }

      final list = (data["items"] as List?) ?? [];
      items = list.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      error = e.toString();
    }

    if (!mounted) return;
    setState(() => loading = false);
  }

  List<Map<String, dynamic>> get _filtered {
    final q = searchC.text.trim().toLowerCase();

    return items.where((e) {
      final status = (e["status"] ?? "present").toString();

      if (filter != "all" && status != filter) return false;

      if (q.isNotEmpty) {
        final title = _eventTitle(e).toLowerCase();
        final type = (e["type"] ?? "").toString().toLowerCase();
        final loc = (e["location"] ?? "").toString().toLowerCase();
        if (!title.contains(q) && !type.contains(q) && !loc.contains(q)) return false;
      }

      return true;
    }).toList();
  }

  Future<void> _exportCsv() async {
    if (items.isEmpty) {
      Get.snackbar("Пусто", "Нет данных для экспорта");
      return;
    }

    try {
      final buffer = StringBuffer();
      buffer.writeln("Команда,Событие,Тип,Дата,Время,Статус,Примечание");

      for (final e in items) {
        final iso = (e["start_at"] ?? "").toString();
        final date = _prettyDate(iso);
        final time = _prettyTime(iso);
        final status = (e["status"] ?? "present").toString();

        buffer.writeln([
          _esc(widget.teamName),
          _esc(_eventTitle(e)),
          _esc((e["type"] ?? "").toString()),
          _esc(date),
          _esc(time),
          _esc(_getStatusFullText(status)),
          _esc((e["note"] ?? "").toString()),
        ].join(","));
      }

      final dir = await getTemporaryDirectory();
      final safeTeam = widget.teamName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final file = File("${dir.path}/моя_посещаемость_${safeTeam}_${DateTime.now().millisecondsSinceEpoch}.csv");

      await file.writeAsString(buffer.toString(), flush: true, encoding: utf8);
      await Share.shareXFiles([XFile(file.path, mimeType: "text/csv")], subject: "Моя посещаемость — ${widget.teamName}");
    } catch (_) {
      Get.snackbar("Ошибка", "Не удалось экспортировать CSV");
    }
  }

  String _esc(String s) {
    final v = s.replaceAll('\r', ' ').replaceAll('\n', ' ').trim();
    final needQuotes = v.contains(',') || v.contains('"') || v.contains(';');
    final escaped = v.replaceAll('"', '""');
    return needQuotes ? '"$escaped"' : escaped;
  }

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

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          "Моя посещаемость — ${widget.teamName}",
          style: const TextStyle(fontWeight: FontWeight.w900),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            onPressed: _load,
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
                        Icon(PhosphorIcons.warningCircle(PhosphorIconsStyle.bold), size: 64, color: const Color(0xFFEF4444)),
                        const SizedBox(height: 16),
                        Text(error!, textAlign: TextAlign.center, style: TextStyle(color: _muted, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _load,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF111827),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                      _cardBox(
                        child: Row(
                          children: [
                            Icon(PhosphorIcons.calendar(PhosphorIconsStyle.bold), color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(_monthTitle(), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: _text)),
                            ),
                            IconButton(
                              onPressed: () {
                                setState(() => selectedMonth = DateTime(selectedMonth.year, selectedMonth.month - 1, 1));
                                _load();
                              },
                              icon: Icon(PhosphorIcons.caretLeft(PhosphorIconsStyle.bold)),
                            ),
                            IconButton(
                              onPressed: () {
                                setState(() => selectedMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 1));
                                _load();
                              },
                              icon: Icon(PhosphorIcons.caretRight(PhosphorIconsStyle.bold)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: _card,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: _stroke),
                              ),
                              child: TextField(
                                controller: searchC,
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  hintText: "Поиск по событию/типу/локации...",
                                  prefixIcon: Icon(PhosphorIcons.magnifyingGlass(PhosphorIconsStyle.bold)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          PopupMenuButton<String>(
                            onSelected: (v) => setState(() => filter = v),
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: "all", child: Text("Все статусы")),
                              PopupMenuItem(value: "present", child: Text("Присутствует (П)")),
                              PopupMenuItem(value: "absent", child: Text("Отсутствует (Н)")),
                              PopupMenuItem(value: "late", child: Text("Болен (Б)")),
                              PopupMenuItem(value: "injured", child: Text("Травма (Т)")),
                              PopupMenuItem(value: "individual", child: Text("Индивид. (И)")),
                              PopupMenuItem(value: "dayoff", child: Text("Выходной (В)")),
                            ],
                            child: Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                color: _card,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: _stroke),
                              ),
                              child: Icon(PhosphorIcons.funnel(PhosphorIconsStyle.bold),
                                  color: filter == "all" ? _muted : _getStatusColor(filter)),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      if (filtered.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(30),
                          child: Column(
                            children: [
                              Icon(PhosphorIcons.info(PhosphorIconsStyle.bold), size: 64, color: const Color(0xFFD1D5DB)),
                              const SizedBox(height: 12),
                              Text("Нет событий по фильтру", style: TextStyle(color: _muted, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 6),
                              Text("Попробуй другой месяц или поиск", style: TextStyle(color: _muted2)),
                            ],
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) {
                            final e = filtered[i];
                            final iso = (e["start_at"] ?? "").toString();
                            final date = _prettyDate(iso);
                            final time = _prettyTime(iso);
                            final title = _eventTitle(e);
                            final status = (e["status"] ?? "present").toString();
                            final note = (e["note"] ?? "").toString();
                            final color = _getStatusColor(status);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: _card,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: _stroke),
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 6))],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: color.withOpacity(0.3)),
                                    ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(date, style: TextStyle(fontWeight: FontWeight.w900, color: _text)),
                                        if (time.isNotEmpty)
                                          Text(time, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: _muted)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(title, maxLines: 2, overflow: TextOverflow.ellipsis,
                                            style: TextStyle(fontWeight: FontWeight.w900, color: _text)),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: color.withOpacity(0.10),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: color.withOpacity(0.25)),
                                              ),
                                              child: Row(
                                                children: [
                                                  Text(_getStatusSymbol(status), style: TextStyle(fontWeight: FontWeight.w900, color: color)),
                                                  const SizedBox(width: 6),
                                                  Text(_getStatusFullText(status), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: color)),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            if ((e["type"] ?? "").toString().trim().isNotEmpty)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                decoration: BoxDecoration(color: _chip, borderRadius: BorderRadius.circular(12)),
                                                child: Text((e["type"] ?? "").toString(),
                                                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: _muted)),
                                              ),
                                          ],
                                        ),
                                        if (note.trim().isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Text("Примечание: $note", style: TextStyle(color: _muted, fontWeight: FontWeight.w600)),
                                        ]
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),

                      const SizedBox(height: 30),
                    ],
                  ),
                ),
    );
  }
}
