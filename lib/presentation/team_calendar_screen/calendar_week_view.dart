import 'package:flutter/material.dart';
import 'team_calendar_models.dart';

class CalendarWeekView extends StatefulWidget {
  final DateTime weekStartMonday;
  final Map<DateTime, List<TeamEvent>> eventsByDay;

  final DateTime selectedDay;
  final ValueChanged<DateTime> onDayTap;
  final ValueChanged<DateTime> onDayLongPress;

  final ValueChanged<TeamEvent> onEventTap;
  final ValueChanged<TeamEvent> onEventLongPress;

  const CalendarWeekView({
    super.key,
    required this.weekStartMonday,
    required this.eventsByDay,
    required this.selectedDay,
    required this.onDayTap,
    required this.onDayLongPress,
    required this.onEventTap,
    required this.onEventLongPress,
  });

  @override
  State<CalendarWeekView> createState() => _CalendarWeekViewState();
}

class _CalendarWeekViewState extends State<CalendarWeekView> {
  final Map<DateTime, GlobalKey> _daySectionKeys = {};

  List<TeamEvent> _eventsFor(DateTime day) {
    final list = (widget.eventsByDay[dateOnly(day)] ?? const <TeamEvent>[])
        .toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
    return list;
  }

  Future<void> _scrollToDay(DateTime day) async {
    final key = _daySectionKeys[dateOnly(day)];
    final ctx = key?.currentContext;
    if (ctx == null) return;

    await Future<void>.delayed(const Duration(milliseconds: 10));
    if (!mounted) return;

    final ctx2 = key?.currentContext;
    if (ctx2 == null) return;

    await Scrollable.ensureVisible(
      ctx2,
      alignment: 0.05,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final days =
        List.generate(7, (i) => widget.weekStartMonday.add(Duration(days: i)));
    const dayNames = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"];
    final primary = Theme.of(context).colorScheme.primary;

    for (final d in days) {
      _daySectionKeys.putIfAbsent(dateOnly(d), () => GlobalKey());
    }

    return Column(
      children: [
        // ✅ верхний селектор: горизонтальный скролл (ничего не сжимается)
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF6F7F9),
            borderRadius: BorderRadius.circular(14),
          ),
          child: LayoutBuilder(
            builder: (context, c) {
              // Минимальная ширина карточки дня
              final minItemW = (c.maxWidth / 7).clamp(56.0, 72.0);
              const gap = 6.0;

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: List.generate(7, (i) {
                    final d = days[i];
                    final isSel = dateOnly(d) == dateOnly(widget.selectedDay);
                    final list = _eventsFor(d);

                    return Padding(
                      padding: EdgeInsets.only(right: i == 6 ? 0 : gap),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () async {
                          widget.onDayTap(d);
                          await _scrollToDay(d);
                        },
                        onLongPress: () => widget.onDayLongPress(d),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: minItemW,
                              padding: const EdgeInsets.symmetric(
                                vertical: 8,
                                horizontal: 7,
                              ),
                              decoration: BoxDecoration(
                                color: isSel
                                    ? Colors.white
                                    : const Color(0xFFFAFBFC),
                                borderRadius: BorderRadius.circular(13),
                                border: Border.all(
                                  color: isSel
                                      ? primary.withOpacity(0.28)
                                      : Colors.transparent,
                                  width: 1.0,
                                ),
                                boxShadow: isSel
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.035),
                                          blurRadius: 18,
                                          spreadRadius: -12,
                                          offset: const Offset(0, 10),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    dayNames[i],
                                    style: const TextStyle(
                                      fontSize: 10.2,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF6B7280),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "${d.day}",
                                    style: const TextStyle(
                                      fontSize: 13.2,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  _DotsMini(events: list),
                                ],
                              ),
                            ),

                            // ✅ бейдж количества событий — на угол (не давит соседей)
                            if (list.isNotEmpty)
                              Positioned(
                                right: -4,
                                top: -4,
                                child: _CountCircleBadge(
                                  count: list.length,
                                  filled: isSel,
                                  primary: primary,
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

        const SizedBox(height: 12),

        // ✅ список по дням
        ...days.map((d) {
          final list = _eventsFor(d);

          return Padding(
            key: _daySectionKeys[dateOnly(d)],
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFBFC),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        "${dayNames[d.weekday - 1]} • ${d.day}.${d.month.toString().padLeft(2, '0')}",
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.2, letterSpacing: -0.12),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => widget.onDayLongPress(d),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF067A46),
                          textStyle: const TextStyle(fontSize: 10.8, fontWeight: FontWeight.w700),
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text("Добавить"),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (list.isEmpty)
                    const Text(
                      "Нет событий",
                      style: TextStyle(color: Color(0xFF6B7280)),
                    )
                  else
                    ...list.map(
                      (e) => _WeekEventTile(
                        e: e,
                        onTap: () => widget.onEventTap(e),
                        onLongPress: () => widget.onEventLongPress(e),
                      ),
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }
}

class _DotsMini extends StatelessWidget {
  final List<TeamEvent> events;
  const _DotsMini({required this.events});

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const SizedBox(height: 8);

    final types = <TeamEventType>{};
    for (final e in events) types.add(e.type);

    final ordered = [
      TeamEventType.training,
      TeamEventType.leagueMatch,
      TeamEventType.friendlyMatch,
      TeamEventType.theory,
      TeamEventType.gym,
      TeamEventType.dayOff,
    ].where(types.contains).toList();

    final shown = ordered.take(3).toList();
    final hidden = types.length - shown.length;

    return SizedBox(
      height: 10,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final t in shown) ...[
            Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: eventTypeColor(t),
                shape: BoxShape.circle,
              ),
            ),
          ],
          if (hidden > 0) ...[
            const SizedBox(width: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFF111827).withOpacity(0.85),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                "+$hidden",
                style: const TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.0,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CountCircleBadge extends StatelessWidget {
  final int count;
  final bool filled;
  final Color primary;

  const _CountCircleBadge({
    required this.count,
    required this.filled,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    final text = count > 99 ? "99+" : "$count";

    final bg = filled ? primary : Colors.white;
    final fg = filled ? Colors.white : const Color(0xFF111827);
    final border = filled ? Colors.transparent : const Color(0xFFE5E7EB);

    return Container(
      width: 18,
      height: 18,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(color: border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w900,
            height: 1.0,
            letterSpacing: -0.2,
            color: fg,
          ),
        ),
      ),
    );
  }
}

class _WeekEventTile extends StatelessWidget {
  final TeamEvent e;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _WeekEventTile({
    required this.e,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final c = eventTypeColor(e.type);
    final when =
        e.endAt == null ? hhmm(e.startAt) : "${hhmm(e.startAt)}–${hhmm(e.endAt!)}";

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: Color.alphaBlend(c.withOpacity(0.045), Colors.white),
          borderRadius: BorderRadius.circular(13),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.025),
              blurRadius: 14,
              spreadRadius: -12,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 44,
              decoration: BoxDecoration(
                color: c,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.4, letterSpacing: -0.12)),
                  const SizedBox(height: 2),
                  Text(
                    "${eventTypeLabel(e.type)} • $when",
                    style: const TextStyle(fontSize: 10.8, fontWeight: FontWeight.w600, color: Color(0xFF6B7280)),
                  ),
                  if (e.location.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text("📍 ${e.location}", maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.8, fontWeight: FontWeight.w600)),
                  ],
                  if (e.notes.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      e.notes,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10.8, fontWeight: FontWeight.w500, color: Color(0xFF374151)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
