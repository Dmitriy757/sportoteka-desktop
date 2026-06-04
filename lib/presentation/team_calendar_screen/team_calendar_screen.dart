import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:sportoteka/core/utils/pref_utils.dart';

import 'team_calendar_models.dart';
import 'team_calendar_api.dart';
import 'event_editor_sheet.dart';
import 'calendar_month_grid.dart';
import 'calendar_week_view.dart';
import 'training_event_detail_sheet.dart';

// ==================== Единый стиль CMR / Матчи ====================

class _CalendarColors {
  static const Color panel = Colors.white;
  static const Color page = Colors.white;
  static const Color soft = Color(0xFFF6F8FA);
  static const Color text = Color(0xFF101828);
  static const Color muted = Color(0xFF667085);
  static const Color green = Color(0xFF1F7A4D);
  static const Color greenSoft = Color(0xFFF2F7F4);
  static const Color greenBorder = Color(0xFFD7E8DE);
  static const Color red = Color(0xFFD92D20);
  static const Color redSoft = Color(0xFFFFF1F1);
}

class _CalendarText {
  static TextStyle title(double size) => TextStyle(
        color: _CalendarColors.text,
        fontSize: size,
        fontWeight: FontWeight.w800,
        height: 1.12,
      );

  static TextStyle section() => const TextStyle(
        color: _CalendarColors.text,
        fontSize: 16,
        fontWeight: FontWeight.w800,
        height: 1.18,
      );

  static TextStyle value(double size) => TextStyle(
        color: _CalendarColors.text,
        fontSize: size,
        fontWeight: FontWeight.w700,
        height: 1.35,
      );

  static TextStyle muted(double size) => TextStyle(
        color: _CalendarColors.muted,
        fontSize: size,
        fontWeight: FontWeight.w600,
        height: 1.42,
      );

  static TextStyle caption() => const TextStyle(
        color: _CalendarColors.muted,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        height: 1.15,
      );

  static TextStyle action() => const TextStyle(
        color: _CalendarColors.green,
        fontSize: 13,
        fontWeight: FontWeight.w800,
      );
}

class _CalendarDecor {
  static BoxDecoration panel() => BoxDecoration(
        color: _CalendarColors.panel,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.018),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      );

  static BoxDecoration softCard({double radius = 22}) => BoxDecoration(
        color: _CalendarColors.soft,
        borderRadius: BorderRadius.circular(radius),
      );
}

enum CalendarMode { month, week }

class TeamCalendarScreen extends StatefulWidget {
  final int teamId;
  final String teamName;

  const TeamCalendarScreen({
    super.key,
    required this.teamId,
    required this.teamName,
  });

  @override
  State<TeamCalendarScreen> createState() => _TeamCalendarScreenState();
}

class _TeamCalendarScreenState extends State<TeamCalendarScreen> {
  static const String apiBase = 'https://sportotekaapp.ru/api';

  late final TeamCalendarApi api;

  bool loading = true;
  bool refreshing = false;
  String? error;

  CalendarMode mode = CalendarMode.month;
  DateTime cursor = DateTime.now();
  DateTime selectedDay = DateTime.now();

  List<TeamEvent> events = [];
  Map<DateTime, List<TeamEvent>> eventsByDay = {};

  String _role = '';
  bool get canEdit => _role.toLowerCase().trim() != 'player';

  @override
  void initState() {
    super.initState();
    api = TeamCalendarApi(apiBase: apiBase);
    _init();
  }

  Future<void> _init() async {
    _role = await _loadRoleSafe();
    await _fetch(initial: true);
  }

  Future<String> _loadRoleSafe() async {
    try {
      // Здесь можно подключить фактическое хранение роли проекта.
      // По умолчанию оставляем редактирование доступным не игроку, чтобы экран не падал.
      return '';
    } catch (_) {
      return '';
    }
  }

  Future<void> _fetch({bool initial = false}) async {
    if (!mounted) return;
    setState(() {
      if (initial) {
        loading = true;
      } else {
        refreshing = true;
      }
      error = null;
    });

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
      final map = <DateTime, List<TeamEvent>>{};
      for (final e in list) {
        final k = dateOnly(e.startAt);
        (map[k] ??= <TeamEvent>[]).add(e);
      }
      for (final entry in map.entries) {
        entry.value.sort((a, b) => a.startAt.compareTo(b.startAt));
      }

      if (!mounted) return;
      setState(() {
        events = list;
        eventsByDay = map;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => error = e.toString());
      Get.snackbar('Ошибка', e.toString(), snackPosition: SnackPosition.BOTTOM);
    } finally {
      if (!mounted) return;
      setState(() {
        loading = false;
        refreshing = false;
      });
    }
  }

  String _monthTitle(DateTime d) {
    const months = [
      'Январь',
      'Февраль',
      'Март',
      'Апрель',
      'Май',
      'Июнь',
      'Июль',
      'Август',
      'Сентябрь',
      'Октябрь',
      'Ноябрь',
      'Декабрь',
    ];
    return '${months[d.month - 1]} ${d.year}';
  }

  String _weekTitle(DateTime d) {
    final ws = startOfWeekMonday(d);
    final we = ws.add(const Duration(days: 6));
    String f(DateTime x) => '${x.day.toString().padLeft(2, '0')}.${x.month.toString().padLeft(2, '0')}';
    return '${f(ws)}–${f(we)}';
  }

  String _dateFull(DateTime d) => '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  void _prevPeriod() {
    setState(() {
      cursor = mode == CalendarMode.month ? DateTime(cursor.year, cursor.month - 1, 1) : cursor.subtract(const Duration(days: 7));
    });
    _fetch();
  }

  void _nextPeriod() {
    setState(() {
      cursor = mode == CalendarMode.month ? DateTime(cursor.year, cursor.month + 1, 1) : cursor.add(const Duration(days: 7));
    });
    _fetch();
  }

  void _thisPeriod() {
    final now = DateTime.now();
    setState(() {
      cursor = now;
      selectedDay = now;
    });
    _fetch();
  }

  Future<void> _openCreate(DateTime day) async {
    if (!canEdit) return;

    final createdBy = await PrefUtils.getUserId() ?? 0;
    final base = DateTime(day.year, day.month, day.day, 18, 0);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => EventEditorSheet(
        primary: _CalendarColors.green,
        teamId: widget.teamId,
        clubId: 0,
        createdBy: createdBy,
        initialDateTime: base,
        onEventAdded: (event) async {
          try {
            await api.add(event: event, createdBy: createdBy);
            await _fetch();
          } catch (e) {
            Get.snackbar('Ошибка', e.toString(), snackPosition: SnackPosition.BOTTOM);
          }
        },
      ),
    ).then((result) async {
      if (result != null && result is TeamEvent) {
        try {
          await api.add(event: result, createdBy: createdBy);
          await _fetch();
        } catch (e) {
          Get.snackbar('Ошибка', e.toString(), snackPosition: SnackPosition.BOTTOM);
        }
      }
    });
  }

  Future<void> _openEdit(TeamEvent current) async {
    if (!canEdit) return;

    final ev = await showModalBottomSheet<TeamEvent?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EventEditorSheet(
        primary: _CalendarColors.green,
        teamId: widget.teamId,
        clubId: current.clubId,
        createdBy: 0,
        initialDateTime: current.startAt,
        initial: current,
      ),
    );

    if (ev == null) return;

    try {
      await api.update(event: ev);
      await _fetch();
    } catch (e) {
      Get.snackbar('Ошибка', e.toString(), snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> _openDetails(TeamEvent e) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TrainingEventDetailSheet(apiBase: apiBase, event: e),
    );
  }

  Future<void> _delete(TeamEvent e) async {
    if (!canEdit) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteEventDialog(title: e.title),
    );

    if (ok != true) return;

    try {
      await api.remove(eventId: e.id, teamId: widget.teamId);
      await _fetch();
    } catch (err) {
      Get.snackbar('Ошибка', err.toString(), snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> _dayActions(DateTime day) async {
    if (!canEdit) return;

    final list = (eventsByDay[dateOnly(day)] ?? const <TeamEvent>[]).toList()..sort((a, b) => a.startAt.compareTo(b.startAt));

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _DayEventsSheet(
        day: day,
        events: list,
        onAdd: () {
          Navigator.pop(context);
          _openCreate(day);
        },
        onEdit: (e) {
          Navigator.pop(context);
          _openEdit(e);
        },
        onDelete: (e) {
          Navigator.pop(context);
          _delete(e);
        },
        onShowAll: () {
          Navigator.pop(context);
          _showAllEvents(day, list);
        },
        onDetails: (e) {
          Navigator.pop(context);
          _openDetails(e);
        },
      ),
    );
  }

  Future<void> _showAllEvents(DateTime day, List<TeamEvent> list) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AllEventsSheet(
        day: day,
        events: list,
        canEdit: canEdit,
        onEdit: (e) {
          Navigator.pop(context);
          _openEdit(e);
        },
        onDelete: (e) {
          Navigator.pop(context);
          _delete(e);
        },
        onDetails: (e) {
          Navigator.pop(context);
          _openDetails(e);
        },
      ),
    );
  }

  List<TeamEvent> _eventsForSelectedDay() {
    final list = (eventsByDay[dateOnly(selectedDay)] ?? const <TeamEvent>[]).toList();
    list.sort((a, b) => a.startAt.compareTo(b.startAt));
    return list;
  }

  int _countByType(TeamEventType type) => events.where((e) => e.type == type).length;

  @override
  Widget build(BuildContext context) {
    final selectedList = _eventsForSelectedDay();
    final isMonth = mode == CalendarMode.month;
    final periodTitle = isMonth ? _monthTitle(cursor) : 'Неделя • ${_weekTitle(cursor)}';
    final weekStart = startOfWeekMonday(cursor);

    if (loading) {
      return const Scaffold(
        backgroundColor: _CalendarColors.page,
        body: Center(child: CircularProgressIndicator(color: _CalendarColors.green)),
      );
    }

    if (error != null) {
      return Scaffold(
        backgroundColor: _CalendarColors.page,
        body: SafeArea(
          child: _CalendarEmptyState(
            icon: Icons.error_outline_rounded,
            title: 'Не удалось загрузить календарь',
            text: error!,
            actionText: 'Повторить',
            onAction: () => _fetch(initial: true),
          ),
        ),
      );
    }

    Widget calendarWidget() {
      return isMonth
          ? CalendarMonthGrid(
              month: cursor,
              eventsByDay: eventsByDay,
              selectedDay: selectedDay,
              onDayTap: (d) => setState(() => selectedDay = d),
              onDayLongPress: (d) {
                if (!canEdit) return;
                setState(() => selectedDay = d);
                _dayActions(d);
              },
            )
          : CalendarWeekView(
              weekStartMonday: weekStart,
              eventsByDay: eventsByDay,
              selectedDay: selectedDay,
              onDayTap: (d) => setState(() => selectedDay = d),
              onDayLongPress: (d) {
                if (!canEdit) return;
                setState(() => selectedDay = d);
                _dayActions(d);
              },
              onEventTap: (e) => canEdit ? _openEdit(e) : _openDetails(e),
              onEventLongPress: (e) {
                if (!canEdit) return;
                _delete(e);
              },
            );
    }

    Widget hero({required bool compact}) {
      return _CalendarHero(
        teamName: widget.teamName,
        refreshing: refreshing,
        total: events.length,
        trainings: _countByType(TeamEventType.training),
        matches: _countByType(TeamEventType.leagueMatch) + _countByType(TeamEventType.friendlyMatch),
        canEdit: canEdit,
        compact: compact,
        onRefresh: () => _fetch(),
      );
    }

    Widget agenda() {
      return _SelectedDayAgenda(
        day: selectedDay,
        items: selectedList,
        canEdit: canEdit,
        onAdd: () => _openCreate(selectedDay),
        onEdit: _openEdit,
        onDelete: _delete,
        onShowAll: () => _showAllEvents(selectedDay, selectedList),
        onDetails: _openDetails,
      );
    }

    Widget board({required bool compact}) {
      return _CalendarBoard(
        periodTitle: periodTitle,
        mode: mode,
        compact: compact,
        onModeChanged: (m) {
          if (mode == m) return;
          setState(() => mode = m);
          _fetch();
        },
        onToday: _thisPeriod,
        onPrev: _prevPeriod,
        onNext: _nextPeriod,
        legend: _CalendarLegend(compact: compact),
        calendar: calendarWidget(),
      );
    }

    return Scaffold(
      backgroundColor: _CalendarColors.page,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final mobile = constraints.maxWidth < 620;
            final compact = constraints.maxWidth < 900;
            var sideWidth = constraints.maxWidth * .42;
            if (sideWidth > 450) sideWidth = 450;

            final height = constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : MediaQuery.sizeOf(context).height - MediaQuery.paddingOf(context).vertical;

            if (mobile) {
              return SizedBox(
                width: double.infinity,
                height: height,
                child: RefreshIndicator(
                  color: _CalendarColors.green,
                  onRefresh: () => _fetch(),
                  child: ListView(
                    padding: EdgeInsets.zero,
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      hero(compact: true),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: mode == CalendarMode.month ? 650 : 730,
                        child: board(compact: true),
                      ),
                      const SizedBox(height: 10),
                      agenda(),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: sideWidth,
                  child: Column(
                    children: [
                      hero(compact: compact),
                      const SizedBox(height: 12),
                      Expanded(child: agenda()),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: board(compact: compact)),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ===================== Основные блоки =====================

class _CalendarHero extends StatelessWidget {
  final String teamName;
  final bool refreshing;
  final int total;
  final int trainings;
  final int matches;
  final bool canEdit;
  final bool compact;
  final VoidCallback onRefresh;

  const _CalendarHero({
    required this.teamName,
    required this.refreshing,
    required this.total,
    required this.trainings,
    required this.matches,
    required this.canEdit,
    required this.onRefresh,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _CalendarDecor.panel(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(compact ? 14 : 18, compact ? 14 : 18, compact ? 14 : 18, compact ? 12 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CmrIconBox(icon: Icons.calendar_month_rounded, size: compact ? 40 : 46),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            teamName.trim().isEmpty ? 'Команда' : teamName,
                            maxLines: compact ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                            style: _CalendarText.title(compact ? 16.5 : 20),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Календарь тренировок, матчей и событий',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _CalendarText.muted(compact ? 11.5 : 12.5),
                          ),
                        ],
                      ),
                    ),
                    _HeaderIconButton(icon: refreshing ? Icons.sync_rounded : Icons.refresh_rounded, onTap: onRefresh),
                  ],
                ),
                SizedBox(height: compact ? 12 : 16),
                Row(
                  children: [
                    Expanded(child: _HeroStat(value: '$total', title: 'событий', compact: compact)),
                    const SizedBox(width: 8),
                    Expanded(child: _HeroStat(value: '$trainings', title: 'тренировок', compact: compact)),
                    const SizedBox(width: 8),
                    Expanded(child: _HeroStat(value: '$matches', title: 'матчей', compact: compact)),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(compact ? 12 : 14, 0, compact ? 12 : 14, compact ? 12 : 14),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 14, vertical: compact ? 10 : 12),
              decoration: _CalendarDecor.softCard(radius: 20),
              child: Row(
                children: [
                  Icon(
                    canEdit ? Icons.edit_calendar_rounded : Icons.visibility_rounded,
                    color: _CalendarColors.green,
                    size: compact ? 18 : 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      canEdit ? 'Доступно добавление и редактирование событий' : 'Режим просмотра календаря команды',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: _CalendarText.muted(compact ? 11.5 : 12.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarBoard extends StatelessWidget {
  final String periodTitle;
  final CalendarMode mode;
  final ValueChanged<CalendarMode> onModeChanged;
  final VoidCallback onToday;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final Widget legend;
  final Widget calendar;
  final bool compact;

  const _CalendarBoard({
    required this.periodTitle,
    required this.mode,
    required this.onModeChanged,
    required this.onToday,
    required this.onPrev,
    required this.onNext,
    required this.legend,
    required this.calendar,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _CalendarDecor.panel(),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(compact ? 14 : 18),
            decoration: const BoxDecoration(
              color: _CalendarColors.panel,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _CmrIconBox(icon: Icons.event_available_rounded, size: 40),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(periodTitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: _CalendarText.title(18)),
                                const SizedBox(height: 4),
                                Text('Управление расписанием команды', maxLines: 1, overflow: TextOverflow.ellipsis, style: _CalendarText.caption()),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _TopActionButton(icon: Icons.today_rounded, text: 'Сегодня', compact: true, onTap: onToday)),
                          const SizedBox(width: 8),
                          _SquareButton(icon: Icons.chevron_left_rounded, compact: true, onTap: onPrev),
                          const SizedBox(width: 8),
                          _SquareButton(icon: Icons.chevron_right_rounded, compact: true, onTap: onNext),
                        ],
                      ),
                    ],
                  )
                : Row(
                    children: [
                      const _CmrIconBox(icon: Icons.event_available_rounded),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(periodTitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CalendarText.title(22)),
                            const SizedBox(height: 4),
                            Text('План команды, тренировки, матчи и выходные', maxLines: 1, overflow: TextOverflow.ellipsis, style: _CalendarText.muted(12.5)),
                          ],
                        ),
                      ),
                      _TopActionButton(icon: Icons.today_rounded, text: 'Сегодня', onTap: onToday),
                      const SizedBox(width: 8),
                      _SquareButton(icon: Icons.chevron_left_rounded, onTap: onPrev),
                      const SizedBox(width: 8),
                      _SquareButton(icon: Icons.chevron_right_rounded, onTap: onNext),
                    ],
                  ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(compact ? 12 : 14, 0, compact ? 12 : 14, compact ? 10 : 12),
            child: Row(
              children: [
                Expanded(child: _ModeButton(text: 'Месяц', active: mode == CalendarMode.month, compact: compact, onTap: () => onModeChanged(CalendarMode.month))),
                const SizedBox(width: 8),
                Expanded(child: _ModeButton(text: 'Неделя', active: mode == CalendarMode.week, compact: compact, onTap: () => onModeChanged(CalendarMode.week))),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(compact ? 12 : 14, 0, compact ? 12 : 14, compact ? 12 : 14),
            child: legend,
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(compact ? 10 : 14, 0, compact ? 10 : 14, compact ? 10 : 14),
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: _CalendarDecor.softCard(radius: 24),
                child: Padding(
                  padding: EdgeInsets.all(compact ? 8 : 12),
                  child: calendar,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarLegend extends StatelessWidget {
  final bool compact;
  const _CalendarLegend({this.compact = false});

  @override
  Widget build(BuildContext context) {
    Widget item(TeamEventType t) {
      final c = eventTypeColor(t);
      return Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? 9 : 10, vertical: compact ? 7 : 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 6),
            Text(eventTypeLabel(t), style: _CalendarText.caption()),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 8 : 10),
      decoration: _CalendarDecor.softCard(radius: 22),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
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
}

class _SelectedDayAgenda extends StatelessWidget {
  final DateTime day;
  final List<TeamEvent> items;
  final bool canEdit;
  final VoidCallback onAdd;
  final ValueChanged<TeamEvent> onEdit;
  final ValueChanged<TeamEvent> onDelete;
  final VoidCallback onShowAll;
  final ValueChanged<TeamEvent> onDetails;

  const _SelectedDayAgenda({
    required this.day,
    required this.items,
    required this.canEdit,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onShowAll,
    required this.onDetails,
  });

  String _dd(DateTime d) => '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

  @override
  Widget build(BuildContext context) {
    final show = items.take(6).toList();

    return Container(
      decoration: _CalendarDecor.panel(),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                const _CmrIconBox(icon: Icons.list_alt_rounded, size: 38),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('События дня', maxLines: 1, overflow: TextOverflow.ellipsis, style: _CalendarText.section()),
                      const SizedBox(height: 3),
                      Text(_dd(day), maxLines: 1, overflow: TextOverflow.ellipsis, style: _CalendarText.caption()),
                    ],
                  ),
                ),
                if (canEdit) _SmallAddButton(onTap: onAdd),
              ],
            ),
          ),
          if (items.isEmpty)
            const SizedBox(
              height: 190,
              child: _MiniEmpty(text: 'На выбранный день событий нет'),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 620),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                itemCount: show.length + ((items.length > show.length) ? 1 : 0),
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  if (i >= show.length) {
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: onShowAll,
                        child: Text('Показать все (${items.length})', style: _CalendarText.action()),
                      ),
                    );
                  }
                  final e = show[i];
                  return _AgendaTile(
                    e: e,
                    canEdit: canEdit,
                    onEdit: () => onEdit(e),
                    onDelete: () => onDelete(e),
                    onDetails: () => onDetails(e),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _AgendaTile extends StatelessWidget {
  final TeamEvent e;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onDetails;

  const _AgendaTile({
    required this.e,
    required this.canEdit,
    required this.onEdit,
    required this.onDelete,
    required this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    final c = eventTypeColor(e.type);
    final when = e.endAt == null ? hhmm(e.startAt) : '${hhmm(e.startAt)}–${hhmm(e.endAt!)}';

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onDetails,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _CalendarColors.soft,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: c.withOpacity(.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(_eventIcon(e.type), color: c, size: 21),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: _CalendarText.value(13.5)),
                  const SizedBox(height: 4),
                  Text('${eventTypeLabel(e.type)} • $when', maxLines: 1, overflow: TextOverflow.ellipsis, style: _CalendarText.caption()),
                  if (e.location.trim().isNotEmpty) ...[
                    const SizedBox(height: 5),
                    _InlineMeta(icon: Icons.place_outlined, text: e.location),
                  ],
                  if (e.notes.trim().isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(e.notes, maxLines: 2, overflow: TextOverflow.ellipsis, style: _CalendarText.muted(12)),
                  ],
                ],
              ),
            ),
            if (canEdit) ...[
              const SizedBox(width: 4),
              _EventMenu(onDetails: onDetails, onEdit: onEdit, onDelete: onDelete),
            ],
          ],
        ),
      ),
    );
  }
}

// ===================== Sheets =====================

class _DayEventsSheet extends StatelessWidget {
  final DateTime day;
  final List<TeamEvent> events;
  final VoidCallback onAdd;
  final ValueChanged<TeamEvent> onEdit;
  final ValueChanged<TeamEvent> onDelete;
  final VoidCallback onShowAll;
  final ValueChanged<TeamEvent> onDetails;

  const _DayEventsSheet({
    required this.day,
    required this.events,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onShowAll,
    required this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(14, 14, 14, 14 + pad),
      decoration: const BoxDecoration(
        color: _CalendarColors.page,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _SheetGrabber(),
            const SizedBox(height: 12),
            _SheetHeader(
              title: 'События дня',
              subtitle: '${day.day}.${day.month.toString().padLeft(2, '0')}.${day.year}',
              onClose: () => Navigator.pop(context),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: _TopActionButton(icon: Icons.add_rounded, text: 'Добавить событие', onTap: onAdd),
            ),
            const SizedBox(height: 10),
            if (events.isEmpty)
              const Padding(
                padding: EdgeInsets.all(14),
                child: _MiniEmpty(text: 'В этот день событий нет'),
              )
            else ...[
              ...events.take(6).map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _AgendaTile(
                      e: e,
                      canEdit: true,
                      onEdit: () => onEdit(e),
                      onDelete: () => onDelete(e),
                      onDetails: () => onDetails(e),
                    ),
                  )),
              if (events.length > 6)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(onPressed: onShowAll, child: Text('Показать все (${events.length})', style: _CalendarText.action())),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AllEventsSheet extends StatelessWidget {
  final DateTime day;
  final List<TeamEvent> events;
  final bool canEdit;
  final ValueChanged<TeamEvent> onEdit;
  final ValueChanged<TeamEvent> onDelete;
  final ValueChanged<TeamEvent> onDetails;

  const _AllEventsSheet({
    required this.day,
    required this.events,
    required this.canEdit,
    required this.onEdit,
    required this.onDelete,
    required this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(14, 14, 14, 14 + pad),
      decoration: const BoxDecoration(
        color: _CalendarColors.page,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _SheetGrabber(),
            const SizedBox(height: 12),
            _SheetHeader(
              title: 'Все события',
              subtitle: '${day.day}.${day.month.toString().padLeft(2, '0')}.${day.year}',
              onClose: () => Navigator.pop(context),
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 560),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: events.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final e = events[i];
                  return _AgendaTile(
                    e: e,
                    canEdit: canEdit,
                    onEdit: () => onEdit(e),
                    onDelete: () => onDelete(e),
                    onDetails: () => onDetails(e),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===================== Малые UI-компоненты =====================

class _CmrIconBox extends StatelessWidget {
  final IconData icon;
  final double size;

  const _CmrIconBox({required this.icon, this.size = 46});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _CalendarColors.greenSoft,
        borderRadius: BorderRadius.circular(size * .34),
      ),
      child: Icon(icon, color: _CalendarColors.green, size: size * .48),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String value;
  final String title;
  final bool compact;

  const _HeroStat({required this.value, required this.title, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 9 : 11),
      decoration: _CalendarDecor.softCard(radius: compact ? 18 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CalendarText.title(compact ? 15 : 17)),
          const SizedBox(height: 2),
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CalendarText.caption()),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: _CalendarDecor.softCard(radius: 16),
        child: Icon(icon, color: _CalendarColors.green, size: 20),
      ),
    );
  }
}

class _TopActionButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  final bool compact;

  const _TopActionButton({required this.icon, required this.text, required this.onTap, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        height: compact ? 40 : 44,
        padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 14),
        decoration: BoxDecoration(
          color: _CalendarColors.greenSoft,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: _CalendarColors.green, size: compact ? 18 : 20),
            const SizedBox(width: 7),
            Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CalendarText.action())),
          ],
        ),
      ),
    );
  }
}

class _SquareButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool compact;

  const _SquareButton({required this.icon, required this.onTap, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: compact ? 40 : 44,
        height: compact ? 40 : 44,
        decoration: _CalendarDecor.softCard(radius: 16),
        child: Icon(icon, color: _CalendarColors.text, size: compact ? 21 : 23),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String text;
  final bool active;
  final bool compact;
  final VoidCallback onTap;

  const _ModeButton({required this.text, required this.active, required this.onTap, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        height: compact ? 40 : 42,
        decoration: BoxDecoration(
          color: active ? _CalendarColors.greenSoft : _CalendarColors.soft,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Center(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: active ? _CalendarColors.green : _CalendarColors.text,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _SmallAddButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SmallAddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: _CalendarColors.greenSoft,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_rounded, color: _CalendarColors.green, size: 18),
            const SizedBox(width: 5),
            Text('Добавить', style: _CalendarText.action()),
          ],
        ),
      ),
    );
  }
}

class _InlineMeta extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InlineMeta({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: _CalendarColors.muted),
        const SizedBox(width: 4),
        Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CalendarText.muted(12))),
      ],
    );
  }
}

class _EventMenu extends StatelessWidget {
  final VoidCallback onDetails;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _EventMenu({required this.onDetails, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Действия',
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      color: Colors.white,
      elevation: 8,
      icon: const Icon(Icons.more_horiz_rounded, color: _CalendarColors.muted),
      onSelected: (v) {
        if (v == 'details') onDetails();
        if (v == 'edit') onEdit();
        if (v == 'delete') onDelete();
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'details', child: Text('Подробнее')),
        PopupMenuItem(value: 'edit', child: Text('Редактировать')),
        PopupMenuItem(value: 'delete', child: Text('Удалить')),
      ],
    );
  }
}

class _SheetGrabber extends StatelessWidget {
  const _SheetGrabber();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 5,
      decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(99)),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onClose;

  const _SheetHeader({required this.title, required this.subtitle, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const _CmrIconBox(icon: Icons.event_note_rounded, size: 40),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CalendarText.section()),
              const SizedBox(height: 3),
              Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CalendarText.caption()),
            ],
          ),
        ),
        TextButton(onPressed: onClose, child: Text('Закрыть', style: _CalendarText.action())),
      ],
    );
  }
}

class _MiniEmpty extends StatelessWidget {
  final String text;
  const _MiniEmpty({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: _CalendarDecor.softCard(radius: 20),
              child: const Icon(Icons.event_busy_rounded, color: _CalendarColors.green),
            ),
            const SizedBox(height: 10),
            Text(text, textAlign: TextAlign.center, style: _CalendarText.muted(12.5)),
          ],
        ),
      ),
    );
  }
}

class _CalendarEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  final String actionText;
  final VoidCallback onAction;

  const _CalendarEmptyState({required this.icon, required this.title, required this.text, required this.actionText, required this.onAction});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(18),
        padding: const EdgeInsets.all(18),
        decoration: _CalendarDecor.panel(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CmrIconBox(icon: icon, size: 54),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center, style: _CalendarText.title(18)),
            const SizedBox(height: 8),
            Text(text, textAlign: TextAlign.center, style: _CalendarText.muted(13)),
            const SizedBox(height: 14),
            _TopActionButton(icon: Icons.refresh_rounded, text: actionText, onTap: onAction),
          ],
        ),
      ),
    );
  }
}

class _DeleteEventDialog extends StatelessWidget {
  final String title;
  const _DeleteEventDialog({required this.title});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text('Удалить событие?', style: _CalendarText.title(18)),
      content: Text('«$title» будет удалено из календаря команды.', style: _CalendarText.muted(13)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Удалить', style: TextStyle(color: _CalendarColors.red, fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }
}

IconData _eventIcon(TeamEventType type) {
  switch (type) {
    case TeamEventType.training:
      return Icons.fitness_center_rounded;
    case TeamEventType.leagueMatch:
      return Icons.emoji_events_rounded;
    case TeamEventType.friendlyMatch:
      return Icons.sports_soccer_rounded;
    case TeamEventType.theory:
      return Icons.menu_book_rounded;
    case TeamEventType.gym:
      return Icons.monitor_heart_rounded;
    case TeamEventType.dayOff:
      return Icons.beach_access_rounded;
  }
}
