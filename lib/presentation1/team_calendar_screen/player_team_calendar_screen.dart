import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'team_calendar_models.dart';
import 'team_calendar_api.dart';
import 'calendar_month_grid.dart';
import 'calendar_week_view.dart';
import 'training_event_detail_sheet.dart';

enum CalendarMode { month, week }

class PlayerTeamCalendarScreen extends StatefulWidget {
  final int teamId;
  final String teamName;

  const PlayerTeamCalendarScreen({
    super.key,
    required this.teamId,
    required this.teamName,
  });

  @override
  State<PlayerTeamCalendarScreen> createState() =>
      _PlayerTeamCalendarScreenState();
}

class _PlayerTeamCalendarScreenState extends State<PlayerTeamCalendarScreen> {
  static const String apiBase = "https://sportotekaapp.ru/api";
  late final TeamCalendarApi api;

  bool loading = true;

  CalendarMode mode = CalendarMode.month;
  DateTime cursor = DateTime.now();
  DateTime selectedDay = DateTime.now();

  List<TeamEvent> events = [];
  Map<DateTime, List<TeamEvent>> eventsByDay = {};

  Color get primary => Theme.of(context).colorScheme.primary;

  @override
  void initState() {
    super.initState();
    api = TeamCalendarApi(apiBase: apiBase);
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => loading = true);

    DateTime from;
    DateTime to;

    if (mode == CalendarMode.month) {
      from = firstDayOfMonth(cursor);
      to = lastDayOfMonth(cursor);
    } else {
      from = startOfWeekMonday(cursor);
      to = from.add(const Duration(days: 6));
    }

    try {
      final list = await api.fetch(teamId: widget.teamId, from: from, to: to);

      events = list;
      eventsByDay = {};
      for (final e in list) {
        final k = dateOnly(e.startAt);
        (eventsByDay[k] ??= []).add(e);
      }
    } catch (e) {
      Get.snackbar(
        "Ошибка",
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
      );
    }

    if (mounted) setState(() => loading = false);
  }

  String _monthTitle(DateTime d) {
    const months = [
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
    return "${months[d.month - 1]} ${d.year}";
  }

  String _weekTitle(DateTime d) {
    final ws = startOfWeekMonday(d);
    final we = ws.add(const Duration(days: 6));
    String f(DateTime x) =>
        "${x.day.toString().padLeft(2, '0')}.${x.month.toString().padLeft(2, '0')}";
    return "${f(ws)}–${f(we)}";
  }

  Future<void> _openDetails(TeamEvent e) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TrainingEventDetailSheet(
        apiBase: apiBase,
        event: e,
         playerView: true,
      ),
    );
  }

  Widget _legend() {
    Widget item(TeamEventType t) {
      final c = eventTypeColor(t);
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            eventTypeLabel(t),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF374151),
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Wrap(
        spacing: 14,
        runSpacing: 10,
        children: [
          item(TeamEventType.training),
          item(TeamEventType.leagueMatch),
          item(TeamEventType.friendlyMatch),
          item(TeamEventType.theory),
          item(TeamEventType.gym),
          item(TeamEventType.dayOff),
        ],
      ),
    );
  }

  Widget _modeSwitch() {
    Widget pill(String text, bool active, VoidCallback onTap) {
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: active ? primary.withOpacity(0.14) : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: active ? primary : const Color(0xFFE5E7EB),
              ),
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

    return Row(
      children: [
        pill("Месяц", mode == CalendarMode.month, () {
          if (mode == CalendarMode.month) return;
          setState(() => mode = CalendarMode.month);
          _fetch();
        }),
        const SizedBox(width: 10),
        pill("Неделя", mode == CalendarMode.week, () {
          if (mode == CalendarMode.week) return;
          setState(() => mode = CalendarMode.week);
          _fetch();
        }),
      ],
    );
  }

  Widget _playerBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: primary.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: primary.withOpacity(0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline, size: 14, color: primary),
          const SizedBox(width: 6),
          Text(
            "Режим игрока • VIEW",
            style: TextStyle(
              color: primary,
              fontWeight: FontWeight.w900,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bg = const Color(0xFFF3F5F8);
    final weekStart = startOfWeekMonday(cursor);

    final selectedList =
        (eventsByDay[dateOnly(selectedDay)] ?? const <TeamEvent>[])
            .toList()
          ..sort((a, b) => a.startAt.compareTo(b.startAt));

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          "Календарь — ${widget.teamName}",
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            onPressed: _fetch,
            icon: const Icon(Icons.refresh),
            tooltip: "Обновить",
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // ✅ красивый верхний блок (read-only)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    "Только просмотр",
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
                _playerBadge(),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // ✅ навигация по месяцу/неделе
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      cursor = mode == CalendarMode.month
                          ? DateTime(cursor.year, cursor.month - 1, 1)
                          : cursor.subtract(const Duration(days: 7));
                    });
                    _fetch();
                  },
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    mode == CalendarMode.month
                        ? _monthTitle(cursor)
                        : "Неделя • ${_weekTitle(cursor)}",
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      cursor = mode == CalendarMode.month
                          ? DateTime(cursor.year, cursor.month + 1, 1)
                          : cursor.add(const Duration(days: 7));
                    });
                    _fetch();
                  },
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: _modeSwitch(),
          ),

          const SizedBox(height: 12),
          _legend(),
          const SizedBox(height: 12),

          if (loading)
            const Padding(
              padding: EdgeInsets.only(top: 28),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (mode == CalendarMode.month) ...[
            CalendarMonthGrid(
              month: cursor,
              eventsByDay: eventsByDay,
              selectedDay: selectedDay,
              onDayTap: (d) => setState(() => selectedDay = d),

              // ✅ у игрока long-press отключён
              onDayLongPress: (_) {},
            ),
            const SizedBox(height: 12),
            _SelectedDayAgendaPlayer(
              day: selectedDay,
              items: selectedList,
              onDetails: _openDetails,
            ),
          ] else ...[
            CalendarWeekView(
              weekStartMonday: weekStart,
              eventsByDay: eventsByDay,
              selectedDay: selectedDay,
              onDayTap: (d) => setState(() => selectedDay = d),

              // ✅ у игрока long-press отключён
              onDayLongPress: (_) {},

              // ✅ тап по событию = детали
              onEventTap: (e) => _openDetails(e),

              // ✅ long press по событию = ничего
              onEventLongPress: (_) {},
            ),
            const SizedBox(height: 12),
            _SelectedDayAgendaPlayer(
              day: selectedDay,
              items: selectedList,
              onDetails: _openDetails,
            ),
          ],
        ],
      ),
    );
  }
}

// ===================== Player agenda widgets =====================

class _SelectedDayAgendaPlayer extends StatelessWidget {
  final DateTime day;
  final List<TeamEvent> items;
  final ValueChanged<TeamEvent> onDetails;

  const _SelectedDayAgendaPlayer({
    required this.day,
    required this.items,
    required this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    String dd(DateTime d) =>
        "${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}";
    final show = items.take(6).toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "События на ${dd(day)}",
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text(
                  "только просмотр",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Нет событий",
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
            )
          else ...[
            ...show.map((e) => _AgendaTilePlayer(
                  e: e,
                  onDetails: () => onDetails(e),
                )),
            if (items.length > show.length) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Ещё: ${items.length - show.length}",
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),
            ]
          ],
        ],
      ),
    );
  }
}

class _AgendaTilePlayer extends StatelessWidget {
  final TeamEvent e;
  final VoidCallback onDetails;

  const _AgendaTilePlayer({
    required this.e,
    required this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    final c = eventTypeColor(e.type);
    final when =
        e.endAt == null ? hhmm(e.startAt) : "${hhmm(e.startAt)}–${hhmm(e.endAt!)}";

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onDetails,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.withOpacity(0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.withOpacity(0.28)),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 46,
              decoration: BoxDecoration(
                color: c,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "${eventTypeLabel(e.type)} • $when",
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (e.location.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      "📍 ${e.location}",
                      style: const TextStyle(fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }
}
