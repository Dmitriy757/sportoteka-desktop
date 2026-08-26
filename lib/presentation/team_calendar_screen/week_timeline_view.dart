import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:sportoteka/core/theme/app_typography.dart';
import 'team_calendar_models.dart';

class WeekTimelineView extends StatefulWidget {
  final DateTime weekStartMonday;
  final Map<DateTime, List<TeamEvent>> eventsByDay;

  final ValueChanged<DateTime> onTapSlot;
  final ValueChanged<DateTime> onLongPressDay;
  final ValueChanged<TeamEvent> onTapEvent;

  final int startHour;
  final int endHour;
  final int minuteSnap;

  const WeekTimelineView({
    super.key,
    required this.weekStartMonday,
    required this.eventsByDay,
    required this.onTapSlot,
    required this.onLongPressDay,
    required this.onTapEvent,
    this.startHour = 6,
    this.endHour = 23,
    this.minuteSnap = 5,
  });

  @override
  State<WeekTimelineView> createState() => _WeekTimelineViewState();
}

class _WeekTimelineViewState extends State<WeekTimelineView> {
  static const double _hourHeight = 64.0;
  static const double _timeGutter = 54.0;
  static const double _dayHeaderHeight = 42.0;

  late final ScrollController _scroll;

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();
    _scroll = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoScrollToNow());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _autoScrollToNow() {
    final now = DateTime.now();
    final start = widget.weekStartMonday;
    final end = start.add(const Duration(days: 7));
    if (now.isBefore(start) || !now.isBefore(end)) return;

    final hour = now.hour + now.minute / 60.0;
    final target = hour.clamp(widget.startHour.toDouble(), widget.endHour.toDouble());
    final offset = ((target - widget.startHour) * _hourHeight) - 140;
    if (_scroll.hasClients) {
      _scroll.jumpTo(offset.clamp(0, _scroll.position.maxScrollExtent));
    }
  }

  int _snapMinute(int m) {
    final s = widget.minuteSnap;
    return ((m / s).round() * s).clamp(0, 59);
  }

  DateTime _dtFromTap(DateTime day, double dy) {
    final minutesFromStart = (dy / _hourHeight) * 60.0;
    final totalMin = (widget.startHour * 60 + minutesFromStart).round();
    final hh = (totalMin ~/ 60).clamp(0, 23);
    final mm = (totalMin % 60).clamp(0, 59);
    return DateTime(day.year, day.month, day.day, hh, _snapMinute(mm));
  }

  bool _dayHasType(DateTime day, TeamEventType t) {
    final list = widget.eventsByDay[_dateOnly(day)] ?? const <TeamEvent>[];
    return list.any((e) => e.type == t);
  }

  Color _dayBg(DateTime day) {
    if (_dayHasType(day, TeamEventType.dayOff)) return const Color(0xFF9CA3AF).withOpacity(0.10);
    if (_dayHasType(day, TeamEventType.leagueMatch)) return const Color(0xFFEF4444).withOpacity(0.06);
    if (_dayHasType(day, TeamEventType.friendlyMatch)) return const Color(0xFF0EA5E9).withOpacity(0.05);
    return Colors.transparent;
  }

  String _dowShort(int weekday) {
    const names = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"];
    return names[weekday - 1];
  }

  bool _isToday(DateTime d) {
    final n = DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  @override
  Widget build(BuildContext context) {
    final bg = const Color(0xFFF3F5F8);
    final card = Colors.white;

    final weekDays = List.generate(7, (i) => _dateOnly(widget.weekStartMonday.add(Duration(days: i))));

    final totalHours = (widget.endHour - widget.startHour + 1).clamp(1, 24);
    final gridHeight = totalHours * _hourHeight;

    return Container(
      decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          // Header
          SizedBox(
            height: _dayHeaderHeight,
            child: Row(
              children: [
                const SizedBox(width: _timeGutter),
                Expanded(
                  child: Row(
                    children: weekDays.map((d) {
                      final active = _isToday(d);
                      return Expanded(
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: active ? Theme.of(context).colorScheme.primary.withOpacity(0.12) : Colors.transparent,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              "${_dowShort(d.weekday)} ${d.day}",
                              style: AppTypography.menuTitle(
                                color: active ? Theme.of(context).colorScheme.primary : const Color(0xFF111827),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // Grid
          Expanded(
            child: Container(
              color: bg,
              child: SingleChildScrollView(
                controller: _scroll,
                child: SizedBox(
                  height: gridHeight,
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final w = c.maxWidth;
                      final dayAreaWidth = w - _timeGutter;
                      final dayWidth = dayAreaWidth / 7;

                      List<Widget> hourLines = [];
                      for (int h = widget.startHour; h <= widget.endHour; h++) {
                        final top = (h - widget.startHour) * _hourHeight;
                        hourLines.add(Positioned(left: 0, right: 0, top: top, child: Container(height: 1, color: const Color(0xFFE5E7EB))));
                        hourLines.add(Positioned(
                          left: 0,
                          top: top - 8,
                          width: _timeGutter,
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: Text(
                              "${h.toString().padLeft(2, '0')}:00",
                              style: AppTypography.captionMedium(color: const Color(0xFF6B7280)),
                            ),
                          ),
                        ));
                      }

                      List<Widget> dayDividers = [];
                      for (int i = 0; i <= 7; i++) {
                        dayDividers.add(Positioned(
                          left: _timeGutter + dayWidth * i,
                          top: 0,
                          bottom: 0,
                          child: Container(width: 1, color: const Color(0xFFE5E7EB)),
                        ));
                      }

                      List<Widget> dayBackgrounds = [];
                      for (int i = 0; i < 7; i++) {
                        final d = weekDays[i];
                        final tint = _dayBg(d);
                        if (tint.opacity > 0) {
                          dayBackgrounds.add(Positioned(
                            left: _timeGutter + dayWidth * i,
                            top: 0,
                            width: dayWidth,
                            height: gridHeight,
                            child: Container(color: tint),
                          ));
                        }
                      }

                      // now line
                      final now = DateTime.now();
                      final inWeek = !now.isBefore(widget.weekStartMonday) &&
                          now.isBefore(widget.weekStartMonday.add(const Duration(days: 7)));
                      Widget? nowLine;
                      if (inWeek) {
                        final todayIndex = weekDays.indexWhere((d) => _isToday(d));
                        if (todayIndex != -1) {
                          final minutes = now.hour * 60 + now.minute;
                          final startMin = widget.startHour * 60;
                          final endMin = (widget.endHour + 1) * 60;
                          if (minutes >= startMin && minutes <= endMin) {
                            final dy = ((minutes - startMin) / 60.0) * _hourHeight;
                            final x = _timeGutter + dayWidth * todayIndex;
                            nowLine = Positioned(
                              left: x,
                              right: 0,
                              top: dy,
                              child: Row(
                                children: [
                                  Container(width: 7, height: 7, decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle)),
                                  Expanded(child: Container(height: 2, color: const Color(0xFFEF4444))),
                                ],
                              ),
                            );
                          }
                        }
                      }

                      // day columns
                      List<Widget> dayColumns = [];
                      for (int i = 0; i < 7; i++) {
                        final day = weekDays[i];
                        final events = (widget.eventsByDay[day] ?? const <TeamEvent>[]).toList()
                          ..sort((a, b) => a.startAt.compareTo(b.startAt));

                        dayColumns.add(Positioned(
                          left: _timeGutter + dayWidth * i,
                          top: 0,
                          width: dayWidth,
                          height: gridHeight,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTapDown: (d) {
                              final dt = _dtFromTap(day, d.localPosition.dy);
                              widget.onTapSlot(dt);
                            },
                            onLongPress: () => widget.onLongPressDay(day),
                            child: Stack(
                              children: _layoutEvents(day: day, events: events, dayWidth: dayWidth),
                            ),
                          ),
                        ));
                      }

                      return Stack(
                        children: [
                          ...dayBackgrounds,
                          ...hourLines,
                          ...dayDividers,
                          ...dayColumns,
                          if (nowLine != null) nowLine,
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _layoutEvents({
    required DateTime day,
    required List<TeamEvent> events,
    required double dayWidth,
  }) {
    final startMinVisible = widget.startHour * 60;
    final endMinVisible = (widget.endHour + 1) * 60;

    int toMin(DateTime dt) => dt.hour * 60 + dt.minute;

    final visible = <TeamEvent>[];
    for (final e in events) {
      if (e.startAt.year != day.year || e.startAt.month != day.month || e.startAt.day != day.day) continue;
      final s = toMin(e.startAt);
      final rawEnd = e.endAt ?? e.startAt.add(const Duration(minutes: 60));
      final em = toMin(rawEnd);
      if (em <= startMinVisible || s >= endMinVisible) continue;
      visible.add(e);
    }

    // группировка (упрощённо)
    final groups = <List<TeamEvent>>[];
    for (final e in visible) {
      bool placed = false;
      for (final g in groups) {
        final last = g.last;
        final lastEnd = last.endAt ?? last.startAt.add(const Duration(minutes: 60));
        if (!e.startAt.isBefore(lastEnd)) {
          g.add(e);
          placed = true;
          break;
        }
      }
      if (!placed) groups.add([e]);
    }

    List<Widget> out = [];
    for (final g in groups) {
      final cols = math.min(2, g.length); // достаточно на старте
      for (int i = 0; i < g.length; i++) {
        final e = g[i];
        final sMin = toMin(e.startAt);
        final rawEnd = e.endAt ?? e.startAt.add(const Duration(minutes: 60));
        final eMin = toMin(rawEnd);

        final top = ((sMin - startMinVisible) / 60.0) * _hourHeight;
        final height = (((eMin - sMin).clamp(20, 24 * 60)) / 60.0) * _hourHeight;

        final col = (i % cols);
        final w = (dayWidth - 8) / cols;
        final left = 4 + w * col;

        out.add(Positioned(
          left: left,
          top: top + 2,
          width: w - 4,
          height: math.max(30, height - 4),
          child: _EventBlockCompact(
            color: eventTypeColor(e.type),
            event: e,
            onTap: () => widget.onTapEvent(e),
          ),
        ));
      }
    }

    return out;
  }
}

class _EventBlockCompact extends StatelessWidget {
  final Color color;
  final TeamEvent event;
  final VoidCallback onTap;

  const _EventBlockCompact({
    required this.color,
    required this.event,
    required this.onTap,
  });

  String _hhmm(DateTime d) => "${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}";

  @override
  Widget build(BuildContext context) {
    final time = event.endAt == null
        ? _hhmm(event.startAt)
        : "${_hhmm(event.startAt)}-${_hhmm(event.endAt!)}";

    return Material(
      color: color.withOpacity(0.18),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.55)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✅ Название одной строкой, без переносов "столбиком"
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    event.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.itemTitle(color: const Color(0xFF111827)),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              // ✅ Время одной строкой, если места мало — ужмём
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  time,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    color: color.withOpacity(0.95),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
