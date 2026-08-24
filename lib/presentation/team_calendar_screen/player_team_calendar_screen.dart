import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sportoteka/core/theme/app_typography.dart';

import 'team_calendar_models.dart';
import 'team_calendar_api.dart';
import 'calendar_month_grid.dart';
import 'calendar_week_view.dart';
import 'training_event_detail_sheet.dart';

enum CalendarMode { month, week }

class PlayerTeamCalendarScreen extends StatefulWidget {
  final int teamId;
  final String teamName;
  final bool embedded;

  const PlayerTeamCalendarScreen({
    super.key,
    required this.teamId,
    required this.teamName,
    this.embedded = false,
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
    Widget item(TeamEventType type) {
      final color = eventTypeColor(type);
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _CalDot(
            color: color,
            size: 5.4,
          ),
          const SizedBox(width: 6),
          Text(
            eventTypeLabel(type),
            style: _CalText.body(9),
          ),
        ],
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 7,
      children: <Widget>[
        item(TeamEventType.training),
        item(TeamEventType.leagueMatch),
        item(TeamEventType.friendlyMatch),
        item(TeamEventType.theory),
        item(TeamEventType.gym),
        item(TeamEventType.dayOff),
      ],
    );
  }

  Widget _modeSwitch() {
    Widget pill(
      String text,
      bool active,
      VoidCallback onTap,
    ) {
      return Expanded(
        child: Material(
          color: active
              ? _CalColors.greenSoft
              : _CalColors.soft,
          borderRadius:
              BorderRadius.circular(9),
          child: InkWell(
            onTap: onTap,
            borderRadius:
                BorderRadius.circular(9),
            child: SizedBox(
              height: 34,
              child: Center(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: _CalText.body(
                    9.4,
                    color: active
                        ? _CalColors.greenDark
                        : _CalColors.muted,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: <Widget>[
        pill(
          'Месяц',
          mode == CalendarMode.month,
          () {
            if (mode ==
                CalendarMode.month) {
              return;
            }
            setState(
              () => mode =
                  CalendarMode.month,
            );
            _fetch();
          },
        ),
        const SizedBox(width: 6),
        pill(
          'Неделя',
          mode == CalendarMode.week,
          () {
            if (mode ==
                CalendarMode.week) {
              return;
            }
            setState(
              () => mode =
                  CalendarMode.week,
            );
            _fetch();
          },
        ),
      ],
    );
  }

  Widget _playerBadge() {
    return Text(
      'только просмотр',
      style: _CalText.body(
        8.4,
        color: _CalColors.muted2,
        weight: FontWeight.w600,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final weekStart =
        startOfWeekMonday(cursor);

    final selectedList =
        (eventsByDay[
                    dateOnly(selectedDay)] ??
                const <TeamEvent>[])
            .toList()
          ..sort(
            (a, b) =>
                a.startAt.compareTo(
              b.startAt,
            ),
          );

    Widget navigation() {
      return Row(
        children: <Widget>[
          _CalIconAction(
            icon: Icons
                .chevron_left_rounded,
            onTap: () {
              setState(() {
                cursor =
                    mode ==
                            CalendarMode
                                .month
                        ? DateTime(
                            cursor.year,
                            cursor.month - 1,
                            1,
                          )
                        : cursor.subtract(
                            const Duration(
                              days: 7,
                            ),
                          );
              });
              _fetch();
            },
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  mode ==
                          CalendarMode.month
                      ? _monthTitle(cursor)
                      : 'Неделя ${_weekTitle(cursor)}',
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      _CalText.title(13),
                ),
                const SizedBox(height: 2),
                Text(
                  '${events.length} событий',
                  style:
                      _CalText.body(8.8),
                ),
              ],
            ),
          ),
          _playerBadge(),
          const SizedBox(width: 7),
          _CalIconAction(
            icon: Icons
                .chevron_right_rounded,
            onTap: () {
              setState(() {
                cursor =
                    mode ==
                            CalendarMode
                                .month
                        ? DateTime(
                            cursor.year,
                            cursor.month + 1,
                            1,
                          )
                        : cursor.add(
                            const Duration(
                              days: 7,
                            ),
                          );
              });
              _fetch();
            },
          ),
        ],
      );
    }

    Widget calendarPane() {
      return ListView(
        padding:
            const EdgeInsets.fromLTRB(
          12,
          10,
          12,
          18,
        ),
        children: <Widget>[
          navigation(),
          const SizedBox(height: 9),
          _modeSwitch(),
          const SizedBox(height: 10),
          _legend(),
          const SizedBox(height: 12),
          if (loading)
            const Padding(
              padding:
                  EdgeInsets.only(
                top: 38,
              ),
              child: Center(
                child:
                    CircularProgressIndicator(
                  strokeWidth: 2,
                  color:
                      _CalColors.green,
                ),
              ),
            )
          else if (mode ==
              CalendarMode.month)
            CalendarMonthGrid(
              month: cursor,
              eventsByDay:
                  eventsByDay,
              selectedDay:
                  selectedDay,
              onDayTap: (d) =>
                  setState(
                () =>
                    selectedDay = d,
              ),
              onDayLongPress: (_) {},
            )
          else
            CalendarWeekView(
              weekStartMonday:
                  weekStart,
              eventsByDay:
                  eventsByDay,
              selectedDay:
                  selectedDay,
              onDayTap: (d) =>
                  setState(
                () =>
                    selectedDay = d,
              ),
              onDayLongPress: (_) {},
              onEventTap:
                  _openDetails,
              onEventLongPress:
                  (_) {},
            ),
        ],
      );
    }

    Widget agendaPane() {
      return ListView(
        padding:
            const EdgeInsets.fromLTRB(
          12,
          10,
          12,
          18,
        ),
        children: <Widget>[
          _SelectedDayAgendaPlayer(
            day: selectedDay,
            items: selectedList,
            onDetails:
                _openDetails,
          ),
        ],
      );
    }

    final body = LayoutBuilder(
      builder:
          (context, constraints) {
        if (constraints.maxWidth >=
            760) {
          return Row(
            children: <Widget>[
              Expanded(
                flex: 46,
                child: calendarPane(),
              ),
              Container(
                width: 1,
                color:
                    _CalColors.line,
              ),
              Expanded(
                flex: 54,
                child: agendaPane(),
              ),
            ],
          );
        }

        return ListView(
          padding:
              const EdgeInsets.fromLTRB(
            10,
            10,
            10,
            20,
          ),
          children: <Widget>[
            navigation(),
            const SizedBox(height: 9),
            _modeSwitch(),
            const SizedBox(height: 10),
            _legend(),
            const SizedBox(height: 12),
            if (loading)
              const Padding(
                padding:
                    EdgeInsets.only(
                  top: 38,
                ),
                child: Center(
                  child:
                      CircularProgressIndicator(
                    strokeWidth: 2,
                    color:
                        _CalColors.green,
                  ),
                ),
              )
            else if (mode ==
                CalendarMode.month)
              CalendarMonthGrid(
                month: cursor,
                eventsByDay:
                    eventsByDay,
                selectedDay:
                    selectedDay,
                onDayTap: (d) =>
                    setState(
                  () =>
                      selectedDay = d,
                ),
                onDayLongPress:
                    (_) {},
              )
            else
              CalendarWeekView(
                weekStartMonday:
                    weekStart,
                eventsByDay:
                    eventsByDay,
                selectedDay:
                    selectedDay,
                onDayTap: (d) =>
                    setState(
                  () =>
                      selectedDay = d,
                ),
                onDayLongPress:
                    (_) {},
                onEventTap:
                    _openDetails,
                onEventLongPress:
                    (_) {},
              ),
            const SizedBox(height: 12),
            _SelectedDayAgendaPlayer(
              day: selectedDay,
              items: selectedList,
              onDetails:
                  _openDetails,
            ),
          ],
        );
      },
    );

    return Theme(
      data: Theme.of(context)
          .copyWith(
        scaffoldBackgroundColor:
            Colors.white,
        colorScheme:
            Theme.of(context)
                .colorScheme
                .copyWith(
          primary:
              _CalColors.green,
        ),
      ),
      child: Scaffold(
        backgroundColor:
            Colors.white,
        appBar: widget.embedded
            ? null
            : AppBar(
                toolbarHeight: 56,
                elevation: 0,
                scrolledUnderElevation: 0,
                backgroundColor:
                    Colors.white,
                surfaceTintColor:
                    Colors.transparent,
                titleSpacing: 12,
                title: Row(
                  children: <Widget>[
                    const _CalDots(),
                    const SizedBox(
                      width: 9,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: <Widget>[
                          Text(
                            'Календарь',
                            style:
                                _CalText.title(
                              13.5,
                            ),
                          ),
                          const SizedBox(
                            height: 2,
                          ),
                          Text(
                            widget.teamName,
                            maxLines: 1,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            style:
                                _CalText.body(
                              8.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                actions: <Widget>[
                  _CalTextAction(
                    label: 'Обновить',
                    onTap: _fetch,
                  ),
                  const SizedBox(
                    width: 10,
                  ),
                ],
                bottom:
                    const PreferredSize(
                  preferredSize:
                      Size.fromHeight(1),
                  child: Divider(
                    height: 1,
                    thickness: .6,
                    color:
                        _CalColors.line,
                  ),
                ),
              ),
        body: body,
      ),
    );
  }

}


class _CalColors {
  static const Color green =
      Color(0xFF00A750);
  static const Color greenDark =
      Color(0xFF067A46);
  static const Color greenSoft =
      Color(0xFFF3FAF6);
  static const Color text =
      Color(0xFF0B0F14);
  static const Color muted =
      Color(0xFF667085);
  static const Color muted2 =
      Color(0xFF98A2B3);
  static const Color soft =
      Color(0xFFF7F9F8);
  static const Color line =
      Color(0xFFEDF0EE);
}

class _CalText {
  static TextStyle title(
    double size, {
    Color color =
        _CalColors.text,
  }) =>
      AppTypography.custom(
        size: size,
        weight: FontWeight.w600,
        color: color,
        height: 1.12,
      );

  static TextStyle body(
    double size, {
    Color color =
        _CalColors.muted,
    FontWeight weight =
        FontWeight.w400,
  }) =>
      AppTypography.custom(
        size: size,
        weight: weight,
        color: color,
        height: 1.22,
      );
}

class _CalDot extends StatelessWidget {
  final Color color;
  final double size;
  final double opacity;

  const _CalDot({
    required this.color,
    required this.size,
    this.opacity = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _CalDots extends StatelessWidget {
  final Color color;

  const _CalDots({
    this.color = _CalColors.green,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize:
          MainAxisSize.min,
      children: <Widget>[
        _CalDot(
          color: color,
          size: 3.4,
          opacity: .32,
        ),
        const SizedBox(width: 3),
        _CalDot(
          color: color,
          size: 4.4,
          opacity: .55,
        ),
        const SizedBox(width: 3),
        _CalDot(
          color: color,
          size: 5.4,
          opacity: .78,
        ),
        const SizedBox(width: 3),
        _CalDot(
          color: color,
          size: 6.4,
        ),
      ],
    );
  }
}

class _CalIconAction
    extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CalIconAction({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _CalColors.soft,
      borderRadius:
          BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(9),
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(
            icon,
            size: 17,
            color:
                _CalColors.greenDark,
          ),
        ),
      ),
    );
  }
}

class _CalTextAction
    extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _CalTextAction({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _CalColors.greenSoft,
      borderRadius:
          BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(9),
        child: Container(
          height: 32,
          padding:
              const EdgeInsets.symmetric(
            horizontal: 9,
          ),
          child: Row(
            children: <Widget>[
              const _CalDot(
                color:
                    _CalColors.green,
                size: 5,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: _CalText.body(
                  8.8,
                  color:
                      _CalColors.greenDark,
                  weight:
                      FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
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
      padding: const EdgeInsets.all(0),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "События на ${dd(day)}",
                  style: _CalText.title(12.2),
                ),
              ),
              Text(
                'только просмотр',
                style: _CalText.body(
                  8.5,
                  color: _CalColors.muted2,
                  weight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (items.isEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Нет событий',
                style: _CalText.body(9.3),
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
                    fontWeight: FontWeight.w600,
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
      borderRadius: BorderRadius.circular(10),
      onTap: onDetails,
      child: Container(
        margin: const EdgeInsets.only(bottom: 5),
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 9,
        ),
        decoration: BoxDecoration(
          color: _CalColors.soft,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            _CalDot(
              color: c,
              size: 6,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.title,
                    style: _CalText.title(10.2),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "${eventTypeLabel(e.type)} • $when",
                    style: _CalText.body(
                      8.8,
                      weight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (e.location.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      e.location,
                      style: _CalText.body(8.6),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: _CalColors.muted2,
            ),
          ],
        ),
      ),
    );
  }
}
