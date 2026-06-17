// lib/presentation/team_calendar_screen/cmr_calendar_panel.dart
// Windows 11 / Fluent unified window refresh for CMR Calendar.
import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/presentation/team_calendar_screen/calendar_week_view.dart';
import 'package:sportoteka/presentation/team_calendar_screen/event_editor_sheet.dart';
import 'package:sportoteka/presentation/team_calendar_screen/team_calendar_api.dart';
import 'package:sportoteka/presentation/team_calendar_screen/team_calendar_models.dart';
import 'package:sportoteka/presentation/team_calendar_screen/team_calendar_screen.dart';
import 'package:sportoteka/presentation/team_calendar_screen/training_rating_sheet.dart';

enum CmrCalendarMode { month, week }

enum _CalendarWorkPanel { calendar, details, editor }

class CmrCalendarPanel extends StatefulWidget {
  final int teamId;
  final String teamName;
  final int clubId;
  final String clubName;

  const CmrCalendarPanel({
    super.key,
    required this.teamId,
    required this.teamName,
    required this.clubId,
    required this.clubName,
  });

  @override
  State<CmrCalendarPanel> createState() => _CmrCalendarPanelState();
}

class _CmrCalendarPanelState extends State<CmrCalendarPanel> {
  static const String apiBase = 'https://sportotekaapp.ru/api';

  late final TeamCalendarApi api;

  bool loading = true;
  bool refreshing = false;
  String? error;

  CmrCalendarMode mode = CmrCalendarMode.month;
  DateTime cursor = DateTime.now();
  DateTime selectedDay = DateTime.now();

  List<TeamEvent> events = [];
  Map<DateTime, List<TeamEvent>> eventsByDay = {};

  String _role = '';
  _CalendarWorkPanel _workPanel = _CalendarWorkPanel.calendar;
  TeamEvent? _selectedEventForPanel;
  TeamEvent? _editingEventForPanel;
  DateTime? _createDateForPanel;
  int _editorCreatedBy = 0;

  bool get canEdit {
    final r = _role.toLowerCase().trim();
    if (r == 'player') return false;
    return true;
  }

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

    final DateTime from;
    final DateTime to;
    if (mode == CmrCalendarMode.month) {
      from = firstDayOfMonth(cursor);
      to = lastDayOfMonth(cursor);
    } else {
      from = startOfWeekMonday(cursor);
      to = from.add(const Duration(days: 6));
    }

    try {
      final list = await api.fetch(teamId: widget.teamId, from: from, to: to);
      final grouped = <DateTime, List<TeamEvent>>{};
      for (final e in list) {
        final key = dateOnly(e.startAt);
        (grouped[key] ??= <TeamEvent>[]).add(e);
      }
      for (final entry in grouped.entries) {
        entry.value.sort((a, b) => a.startAt.compareTo(b.startAt));
      }
      if (!mounted) return;
      setState(() {
        events = list;
        eventsByDay = grouped;
        loading = false;
        refreshing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        refreshing = false;
        error = '$e';
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
    String f(DateTime x) =>
        '${x.day.toString().padLeft(2, '0')}.${x.month.toString().padLeft(2, '0')}';
    return '${f(ws)}–${f(we)}';
  }

  String _dateTitle(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
  }

  String _pluralEvent(int count) {
    final mod10 = count % 10;
    final mod100 = count % 100;
    if (mod10 == 1 && mod100 != 11) return 'событие';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
      return 'события';
    }
    return 'событий';
  }

  void _previousPeriod() {
    setState(() {
      if (mode == CmrCalendarMode.month) {
        cursor = DateTime(cursor.year, cursor.month - 1, 1);
        selectedDay = DateTime(cursor.year, cursor.month, 1);
      } else {
        cursor = cursor.subtract(const Duration(days: 7));
        selectedDay = cursor;
      }
      _workPanel = _CalendarWorkPanel.calendar;
      _selectedEventForPanel = null;
    });
    _fetch();
  }

  void _nextPeriod() {
    setState(() {
      if (mode == CmrCalendarMode.month) {
        cursor = DateTime(cursor.year, cursor.month + 1, 1);
        selectedDay = DateTime(cursor.year, cursor.month, 1);
      } else {
        cursor = cursor.add(const Duration(days: 7));
        selectedDay = cursor;
      }
      _workPanel = _CalendarWorkPanel.calendar;
      _selectedEventForPanel = null;
    });
    _fetch();
  }

  void _today() {
    final now = DateTime.now();
    setState(() {
      cursor = now;
      selectedDay = now;
      _workPanel = _CalendarWorkPanel.calendar;
      _selectedEventForPanel = null;
    });
    _fetch();
  }

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDay,
      firstDate: DateTime(now.year - 5, 1, 1),
      lastDate: DateTime(now.year + 5, 12, 31),
      helpText: 'Выберите дату календаря',
      cancelText: 'Отмена',
      confirmText: 'Выбрать',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: _C.green,
                  secondary: _C.greenDark,
                ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked == null) return;
    setState(() {
      cursor = mode == CmrCalendarMode.month
          ? DateTime(picked.year, picked.month, 1)
          : startOfWeekMonday(picked);
      selectedDay = DateTime(picked.year, picked.month, picked.day);
      _workPanel = _CalendarWorkPanel.calendar;
      _selectedEventForPanel = null;
    });
    _fetch();
  }

  void _openFullCalendar() {
    Get.to(
      () => TeamCalendarScreen(
        teamId: widget.teamId,
        teamName: widget.teamName,
      ),
      transition: Transition.fadeIn,
      duration: const Duration(milliseconds: 220),
    );
  }

  void _selectCalendarDay(DateTime day) {
    final nextCursor = mode == CmrCalendarMode.month
        ? DateTime(day.year, day.month, 1)
        : startOfWeekMonday(day);
    final needReload = mode == CmrCalendarMode.month
        ? nextCursor.year != cursor.year || nextCursor.month != cursor.month
        : dateOnly(nextCursor) != dateOnly(startOfWeekMonday(cursor));

    setState(() {
      selectedDay = day;
      if (needReload) cursor = nextCursor;
    });

    if (needReload) _fetch();
  }

  void _selectCalendarDayAndSyncPane(DateTime day) {
    _selectCalendarDay(day);
    final dayEvents = (eventsByDay[dateOnly(day)] ?? const <TeamEvent>[]).toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
    setState(() {
      _editingEventForPanel = null;
      _createDateForPanel = null;
      _selectedEventForPanel = dayEvents.isEmpty ? null : dayEvents.first;
      _workPanel = dayEvents.isEmpty ? _CalendarWorkPanel.calendar : _CalendarWorkPanel.details;
    });
  }

  Future<void> _openCreate(DateTime day) async {
    if (!canEdit) return;
    final createdBy = await PrefUtils.getUserId() ?? 0;
    if (!mounted) return;

    final base = DateTime(day.year, day.month, day.day, 18, 0);
    setState(() {
      selectedDay = day;
      _editorCreatedBy = createdBy;
      _createDateForPanel = day;
      _editingEventForPanel = null;
      _selectedEventForPanel = null;
      _workPanel = _CalendarWorkPanel.calendar;
    });

    final event = await showEventEditorWindow(
      context,
      primary: _C.green,
      teamId: widget.teamId,
      clubId: widget.clubId,
      createdBy: createdBy,
      initialDateTime: base,
      onEventAdded: _handleAddMoreFromEditor,
    );

    if (event != null) {
      await _handleEditorSubmit(event);
    }
  }

  Future<void> _openEdit(TeamEvent event) async {
    if (!canEdit) return;
    final createdBy = await PrefUtils.getUserId() ?? 0;
    if (!mounted) return;

    setState(() {
      selectedDay = event.startAt;
      _editorCreatedBy = createdBy;
      _createDateForPanel = event.startAt;
      _editingEventForPanel = event;
      _selectedEventForPanel = event;
      _workPanel = _CalendarWorkPanel.details;
    });

    final updated = await showEventEditorWindow(
      context,
      primary: eventTypeColor(event.type),
      teamId: event.teamId,
      clubId: event.clubId,
      createdBy: createdBy,
      initialDateTime: event.startAt,
      initial: event,
    );

    if (updated != null) {
      await _handleEditorSubmit(updated);
    }
  }

  void _openDetails(TeamEvent event) {
    setState(() {
      selectedDay = event.startAt;
      _selectedEventForPanel = event;
      _editingEventForPanel = null;
      _createDateForPanel = null;
      _workPanel = _CalendarWorkPanel.details;
    });
  }

  bool _canRateEvent(TeamEvent event) {
    return event.type == TeamEventType.training || event.type == TeamEventType.gym;
  }

  Future<void> _openTrainingRatings(TeamEvent event) async {
    if (!canEdit) return;

    if (!_canRateEvent(event)) {
      Get.snackbar(
        'Оценка',
        'Оценка доступна только для тренировок и ОФП.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final coachId = await PrefUtils.getUserId() ?? 0;
    if (coachId <= 0) {
      Get.snackbar(
        'Оценка',
        'Не найден userId тренера.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    if (!mounted) return;

    await showTrainingRatingWindow(
      context,
      apiBase: apiBase,
      teamId: event.teamId,
      eventId: event.id,
      coachId: coachId,
      title: event.title,
    );

    if (mounted) {
      await _fetch();
    }
  }

  void _closeWorkPanel() {
    setState(() {
      _workPanel = _CalendarWorkPanel.calendar;
      _selectedEventForPanel = null;
      _editingEventForPanel = null;
      _createDateForPanel = null;
    });
  }

  Future<void> _handleEditorSubmit(TeamEvent event) async {
    if (!canEdit) return;
    try {
      if (_editingEventForPanel == null) {
        await api.add(event: event, createdBy: _editorCreatedBy);
        Get.snackbar('Готово', 'Событие добавлено', snackPosition: SnackPosition.BOTTOM);
      } else {
        await api.update(event: event);
        Get.snackbar('Готово', 'Событие обновлено', snackPosition: SnackPosition.BOTTOM);
      }
      await _fetch();
      if (!mounted) return;
      setState(() {
        selectedDay = event.startAt;
        _workPanel = _CalendarWorkPanel.calendar;
        _selectedEventForPanel = null;
        _editingEventForPanel = null;
        _createDateForPanel = null;
      });
    } catch (e) {
      Get.snackbar('Ошибка', e.toString(), snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> _handleAddMoreFromEditor(TeamEvent event) async {
    if (!canEdit) return;
    try {
      await api.add(event: event, createdBy: _editorCreatedBy);
      await _fetch();
      if (!mounted) return;
      setState(() {
        selectedDay = event.startAt;
        _createDateForPanel = event.startAt;
      });
      Get.snackbar('Готово', 'Событие добавлено', snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      Get.snackbar('Ошибка', e.toString(), snackPosition: SnackPosition.BOTTOM);
    }
  }

  Future<void> _delete(TeamEvent event) async {
    if (!canEdit) return;
    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Удалить событие?'),
        content: Text('«${event.title}» будет удалено из календаря.'),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Get.back(result: true),
            style: TextButton.styleFrom(foregroundColor: _C.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await api.remove(eventId: event.id, teamId: widget.teamId);
      await _fetch();
      if (mounted && _selectedEventForPanel?.id == event.id) {
        _closeWorkPanel();
      }
      Get.snackbar('Готово', 'Событие удалено', snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      Get.snackbar('Ошибка', e.toString(), snackPosition: SnackPosition.BOTTOM);
    }
  }

  TeamEvent? _eventForRightPane(List<TeamEvent> selectedList) {
    if (_workPanel == _CalendarWorkPanel.details && _selectedEventForPanel != null) {
      final current = _selectedEventForPanel!;
      if (events.any((e) => e.id == current.id)) return current;
    }
    if (selectedList.isNotEmpty) return selectedList.first;
    return null;
  }

  TeamEvent? _nextUpcomingEvent() {
    final now = DateTime.now();
    final future = events.where((e) => e.startAt.isAfter(now)).toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
    if (future.isNotEmpty) return future.first;
    final sorted = events.toList()..sort((a, b) => a.startAt.compareTo(b.startAt));
    return sorted.isEmpty ? null : sorted.first;
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Container(
        width: double.infinity,
        decoration: _C.cardDecoration,
        child: const Center(child: CircularProgressIndicator(color: _C.green)),
      );
    }

    if (error != null) {
      return _CmrEmptyState(
        icon: Icons.error_outline_rounded,
        title: 'Не удалось загрузить календарь',
        text: error!,
        actionText: 'Повторить',
        onAction: () => _fetch(initial: true),
      );
    }

    final selectedList = (eventsByDay[dateOnly(selectedDay)] ?? const <TeamEvent>[]).toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
    final weekStart = startOfWeekMonday(cursor);

    return DefaultTextStyle.merge(
      style: const TextStyle(
        fontFamily: _C.font,
        fontFamilyFallback: _C.fallback,
        color: _C.text,
        height: 1.18,
        letterSpacing: -0.08,
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final isPhone = c.maxWidth < 640;
          if (isPhone) {
            return _buildMobileLayout(selectedList, weekStart, c);
          }

          final selectedForDetails = _eventForRightPane(selectedList);

          // Как в CMR-матчах: календарь остаётся слева, а список/детали/редактор
          // всегда живут в правой колонке. Без нижнего дублирующего блока.
          return _buildTabletKpiWorkspace(
            selectedList: selectedList,
            weekStart: weekStart,
            selectedForDetails: selectedForDetails,
            constraints: c,
          );
        },
      ),
    );
  }

  double _calendarColumnWidth(BoxConstraints constraints) {
    // Геометрия как в CMR Team Matches: слева стабильная календарная колонка,
    // на узких десктопных окнах не сжимается ниже комфортного размера.
    final width = constraints.maxWidth.isFinite ? constraints.maxWidth : 1180.0;
    return math.min(480.0, math.max(320.0, width * .42));
  }

  Widget _buildTabletKpiWorkspace({
    required List<TeamEvent> selectedList,
    required DateTime weekStart,
    required TeamEvent? selectedForDetails,
    required BoxConstraints constraints,
  }) {
    final height = constraints.maxHeight.isFinite ? constraints.maxHeight : 780.0;
    final showWorkPane = _workPanel == _CalendarWorkPanel.editor ||
        (_workPanel == _CalendarWorkPanel.details && selectedForDetails != null);
    final calendarWidth = _calendarColumnWidth(constraints);

    return SizedBox(
      width: double.infinity,
      height: height,
      child: Container(
        decoration: const BoxDecoration(color: _C.soft),
        padding: const EdgeInsets.all(10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Container(
            decoration: _C.workspaceDecoration,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: calendarWidth,
                  child: _buildStrictCalendarWindow(weekStart, selectedList),
                ),
                Container(width: 1, color: _C.border.withOpacity(.78)),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: KeyedSubtree(
                      key: ValueKey<String>('calendar-pane-${_workPanel.name}-${selectedForDetails?.id ?? 0}'),
                      child: showWorkPane
                          ? _buildCalendarDetailsPane(selectedForDetails, selectedList, compact: true)
                          : _buildCalendarRightOverviewPanel(selectedList),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarMatchHeader(List<TeamEvent> selectedList) {
    final next = _nextUpcomingEvent();
    final period = mode == CmrCalendarMode.month ? _monthTitle(cursor) : _weekTitle(cursor);
    final selectedText = _dateTitle(selectedDay);
    final selectedCountText = '${selectedList.length} ${_pluralEvent(selectedList.length)}';

    return Container(
      height: 58,
      decoration: _C.panelDecoration(radius: 22),
      padding: const EdgeInsets.fromLTRB(10, 7, 8, 7),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _C.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.transparent),
            ),
            child: Stack(
              children: const [
                Center(child: Icon(Icons.calendar_month_rounded, color: _C.text, size: 17)),
                Positioned(left: 0, top: 9, bottom: 9, child: _BrandAccentLine(height: 16)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 34,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.teamName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _C.text, fontSize: 13.65, fontWeight: FontWeight.w700, height: 1),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.clubName.trim().isEmpty ? 'Команда' : widget.clubName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _C.muted, fontSize: 10.05, fontWeight: FontWeight.w600, height: 1),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 28,
            child: _CalendarTopLine(
              label: mode == CmrCalendarMode.month ? 'Месяц' : 'Неделя',
              value: period,
              subvalue: '$selectedText · $selectedCountText',
              icon: Icons.date_range_rounded,
              color: _C.green,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 26,
            child: _CalendarTopLine(
              label: 'Ближайшее',
              value: next == null ? 'Нет событий' : next.title,
              subvalue: next == null ? 'Добавьте событие на день' : '${_dateTitle(next.startAt)} · ${hhmm(next.startAt)}',
              icon: next == null ? Icons.event_busy_rounded : Icons.event_available_rounded,
              color: next == null ? const Color(0xFF64748B) : eventTypeColor(next.type),
            ),
          ),
          const SizedBox(width: 8),
          _ProfileRoundButton(icon: Icons.today_rounded, onTap: _today),
          const SizedBox(width: 5),
          _ProfileRoundButton(icon: refreshing ? Icons.sync_rounded : Icons.refresh_rounded, onTap: () => _fetch()),
          if (canEdit) ...[
            const SizedBox(width: 5),
            _ProfileRoundButton(icon: Icons.add_rounded, onTap: () => _openCreate(selectedDay)),
          ],
        ],
      ),
    );
  }

  Widget _buildTabletDefaultGrid({
    required List<TeamEvent> selectedList,
    required DateTime weekStart,
    required TeamEvent? selectedForDetails,
    required double gap,
  }) {
    return LayoutBuilder(
      builder: (context, c) {
        final calendarWidth = _calendarColumnWidth(c);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: calendarWidth, child: _buildStrictCalendarWindow(weekStart, selectedList)),
            SizedBox(width: gap),
            Expanded(
              child: _buildCalendarRightOverviewPanel(selectedList),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTabletWorkModeGrid({
    required List<TeamEvent> selectedList,
    required DateTime weekStart,
    required TeamEvent? selectedForDetails,
    required double gap,
  }) {
    return LayoutBuilder(
      builder: (context, c) {
        final calendarWidth = _calendarColumnWidth(c);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: calendarWidth, child: _buildStrictCalendarWindow(weekStart, selectedList)),
            SizedBox(width: gap),
            Expanded(
              child: _buildCalendarDetailsPane(selectedForDetails, selectedList),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCalendarRightOverviewPanel(List<TeamEvent> selectedList) {
    final matchCount = events
        .where((e) => e.type == TeamEventType.leagueMatch || e.type == TeamEventType.friendlyMatch)
        .length;
    final trainingCount = events.where((e) => e.type == TeamEventType.training || e.type == TeamEventType.gym).length;
    final theoryCount = events.where((e) => e.type == TeamEventType.theory).length;
    final dayOffCount = events.where((e) => e.type == TeamEventType.dayOff).length;
    final next = _nextUpcomingEvent();
    final selectedTitle = _dateTitle(selectedDay);

    return _StrictWorkspaceCard(
      icon: Icons.view_agenda_rounded,
      title: 'События дня',
      subtitle: '$selectedTitle · ${selectedList.length} ${_pluralEvent(selectedList.length)}',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ProfileRoundButton(icon: refreshing ? Icons.sync_rounded : Icons.refresh_rounded, onTap: () => _fetch()),
          if (canEdit) ...[
            const SizedBox(width: 7),
            _ProfileRoundButton(icon: Icons.add_rounded, onTap: () => _openCreate(selectedDay)),
          ],
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _CalendarSideKpi(
                  icon: Icons.today_rounded,
                  label: 'День',
                  value: '${selectedList.length}',
                  hint: 'на дату',
                  color: _C.green,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CalendarSideKpi(
                  icon: Icons.fitness_center_rounded,
                  label: 'Тренировки',
                  value: '$trainingCount',
                  hint: 'в периоде',
                  color: _C.cyan,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CalendarSideKpi(
                  icon: Icons.sports_soccer_rounded,
                  label: 'Матчи',
                  value: '$matchCount',
                  hint: 'в периоде',
                  color: _C.blue,
                ),
              ),
            ],
          ),
          if (next != null) ...[
            const SizedBox(height: 10),
            _CalendarNextEventStrip(event: next, title: next.title.trim().isEmpty ? 'Ближайшее событие' : next.title),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _CalendarSideKpi(
                  icon: Icons.psychology_alt_outlined,
                  label: 'Теория',
                  value: '$theoryCount',
                  hint: 'разборы',
                  color: const Color(0xFFB7791F),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CalendarSideKpi(
                  icon: Icons.beach_access_rounded,
                  label: 'Выходные',
                  value: '$dayOffCount',
                  hint: 'в периоде',
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 12, 0, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Список событий',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _C.section(),
                  ),
                ),
                Text(
                  selectedTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _C.muted, fontSize: 10.75, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Expanded(
            child: selectedList.isEmpty
                ? const _MiniEmpty(text: 'На выбранный день событий нет')
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: selectedList.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 7),
                    itemBuilder: (_, index) {
                      final event = selectedList[index];
                      return _CmrEventTile(
                        event: event,
                        canEdit: canEdit,
                        onDetails: () => _openDetails(event),
                        onEdit: () => _openEdit(event),
                        onDelete: () => _delete(event),
                        onRating: () => _openTrainingRatings(event),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodStructureCompact() {
    final rows = [
      _CalendarTypeData(TeamEventType.training, 'Тренировки'),
      _CalendarTypeData(TeamEventType.leagueMatch, 'Матчи'),
      _CalendarTypeData(TeamEventType.friendlyMatch, 'Товарищ.'),
      _CalendarTypeData(TeamEventType.theory, 'Теория'),
      _CalendarTypeData(TeamEventType.gym, 'Зал'),
      _CalendarTypeData(TeamEventType.dayOff, 'Выходные'),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.transparent),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          const gap = 6.0;
          final columns = c.maxWidth >= 420 ? 3 : 2;
          final width = (c.maxWidth - gap * (columns - 1)) / columns;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.query_stats_rounded, color: _C.greenDark, size: 15),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Структура периода',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _C.title.copyWith(fontSize: 12.55, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    mode == CmrCalendarMode.month ? _monthTitle(cursor) : _weekTitle(cursor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _C.muted, fontSize: 10.25, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final row in rows)
                    SizedBox(
                      width: width,
                      child: _CalendarTypeTile(
                        label: row.label,
                        value: '${events.where((e) => e.type == row.type).length}',
                        color: eventTypeColor(row.type),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCalendarInfoRows(List<TeamEvent> selectedList) {
    final matchCount = events.where((e) => e.type == TeamEventType.leagueMatch || e.type == TeamEventType.friendlyMatch).length;
    final trainingCount = events.where((e) => e.type == TeamEventType.training || e.type == TeamEventType.gym).length;
    final theoryCount = events.where((e) => e.type == TeamEventType.theory).length;
    final dayOffCount = events.where((e) => e.type == TeamEventType.dayOff).length;
    final next = _nextUpcomingEvent();

    final items = [
      _CalendarKpiData(label: 'Период', value: '${events.length}', icon: Icons.dashboard_customize_rounded, color: _C.green, hint: mode == CmrCalendarMode.month ? _monthTitle(cursor) : _weekTitle(cursor)),
      _CalendarKpiData(label: 'День', value: '${selectedList.length}', icon: Icons.today_rounded, color: _C.cyan, hint: _dateTitle(selectedDay)),
      _CalendarKpiData(label: 'Тренировки', value: '$trainingCount', icon: Icons.fitness_center_rounded, color: _C.green, hint: 'поле + зал'),
      _CalendarKpiData(label: 'Матчи', value: '$matchCount', icon: Icons.sports_soccer_rounded, color: _C.blue, hint: 'игры'),
      _CalendarKpiData(label: 'Теория', value: '$theoryCount', icon: Icons.psychology_alt_outlined, color: const Color(0xFFB7791F), hint: dayOffCount > 0 ? 'выходных: $dayOffCount' : 'разбор'),
      _CalendarKpiData(label: 'Следующее', value: next == null ? '—' : hhmm(next.startAt), icon: Icons.play_arrow_rounded, color: next == null ? _C.slate : eventTypeColor(next.type), hint: next == null ? 'нет' : next.title),
    ];

    return SizedBox(
      height: 42,
      child: LayoutBuilder(
        builder: (context, c) {
          const gap = 5.0;
          final wide = c.maxWidth >= 1040;
          if (wide) {
            return Row(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  Expanded(child: _CalendarInfoCell(item: items[i])),
                  if (i != items.length - 1) const SizedBox(width: gap),
                ],
              ],
            );
          }

          return ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (_, index) => SizedBox(width: 156, child: _CalendarInfoCell(item: items[index])),
            separatorBuilder: (_, __) => const SizedBox(width: gap),
            itemCount: items.length,
          );
        },
      ),
    );
  }

  Widget _buildStrictCalendarWindow(DateTime weekStart, List<TeamEvent> selectedList) {
    final title = mode == CmrCalendarMode.month ? _monthTitle(cursor) : 'Неделя • ${_weekTitle(cursor)}';

    return _StrictWorkspaceCard(
      icon: Icons.calendar_month_rounded,
      title: title,
      subtitle: '${widget.teamName} · ${_dateTitle(selectedDay)} · ${events.length} ${_pluralEvent(events.length)}',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ProfileRoundButton(icon: Icons.chevron_left_rounded, onTap: _previousPeriod),
          const SizedBox(width: 6),
          _ProfileRoundButton(icon: Icons.chevron_right_rounded, onTap: _nextPeriod),
          const SizedBox(width: 6),
          _ProfileRoundButton(icon: Icons.today_rounded, onTap: _today),
          const SizedBox(width: 6),
          _ProfileRoundButton(icon: refreshing ? Icons.sync_rounded : Icons.refresh_rounded, onTap: () => _fetch()),
        ],
      ),
      child: Column(
        children: [
          _buildCalendarInfoRows(selectedList),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(width: 250, child: _buildModeSelector()),
              const SizedBox(width: 8),
              Expanded(child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: _legend())),
              const SizedBox(width: 8),
              if (canEdit) _ProfileActionButton(icon: Icons.add_rounded, text: 'Событие', onTap: () => _openCreate(selectedDay)),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.70),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(.72), width: 1),
                ),
                padding: const EdgeInsets.all(8),
                child: LayoutBuilder(
                  builder: (context, calendarBox) {
                    return mode == CmrCalendarMode.month
                        ? _buildInlineMonthCalendar(maxHeight: calendarBox.maxHeight)
                        : CalendarWeekView(
                            weekStartMonday: weekStart,
                            eventsByDay: eventsByDay,
                            selectedDay: selectedDay,
                            onDayTap: _selectCalendarDayAndSyncPane,
                            onDayLongPress: (d) {
                              if (!canEdit) return;
                              _selectCalendarDayAndSyncPane(d);
                              _openCreate(d);
                            },
                            onEventTap: _openDetails,
                            onEventLongPress: (e) {
                              if (!canEdit) return;
                              _openEdit(e);
                            },
                          );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedDayEventsWindow(List<TeamEvent> selectedList) {
    return _StrictWorkspaceCard(
      icon: Icons.view_agenda_rounded,
      title: 'События дня',
      subtitle: _dateTitle(selectedDay),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ProfileRoundButton(icon: refreshing ? Icons.sync_rounded : Icons.refresh_rounded, onTap: () => _fetch()),
          if (canEdit) ...[
            const SizedBox(width: 6),
            _ProfileRoundButton(icon: Icons.add_rounded, onTap: () => _openCreate(selectedDay)),
          ],
        ],
      ),
      child: selectedList.isEmpty
          ? const _MiniEmpty(text: 'На выбранный день событий нет')
          : ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: selectedList.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (_, index) {
                final event = selectedList[index];
                return _CmrEventTile(
                  event: event,
                  canEdit: canEdit,
                  onDetails: () => _openDetails(event),
                  onEdit: () => _openEdit(event),
                  onDelete: () => _delete(event),
                  onRating: () => _openTrainingRatings(event),
                );
              },
            ),
    );
  }

  Widget _buildPeriodTypeWindow() {
    final rows = [
      _CalendarTypeData(TeamEventType.training, 'Тренировки'),
      _CalendarTypeData(TeamEventType.leagueMatch, 'Матчи'),
      _CalendarTypeData(TeamEventType.friendlyMatch, 'Товарищ.'),
      _CalendarTypeData(TeamEventType.theory, 'Теория'),
      _CalendarTypeData(TeamEventType.gym, 'Зал'),
      _CalendarTypeData(TeamEventType.dayOff, 'Выходные'),
    ];

    return _StrictWorkspaceCard(
      icon: Icons.query_stats_rounded,
      title: 'Структура периода',
      subtitle: mode == CmrCalendarMode.month ? _monthTitle(cursor) : _weekTitle(cursor),
      dense: true,
      child: LayoutBuilder(
        builder: (context, c) {
          const gap = 6.0;
          final columns = c.maxWidth >= 430 ? 3 : 2;
          final width = (c.maxWidth - gap * (columns - 1)) / columns;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final row in rows)
                SizedBox(
                  width: width,
                  child: _CalendarTypeTile(
                    label: row.label,
                    value: '${events.where((e) => e.type == row.type).length}',
                    color: eventTypeColor(row.type),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProfileCalendarCenter({
    required List<TeamEvent> selectedList,
    required DateTime weekStart,
    required double maxWidth,
  }) {
    return RefreshIndicator(
      color: _C.green,
      onRefresh: () => _fetch(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 18),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _buildSlimCalendarBlock(weekStart),
          const SizedBox(height: 10),
          _buildModeSelector(),
          const SizedBox(height: 10),
          _legend(),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  'События за ${_dateTitle(selectedDay)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _C.title.copyWith(fontSize: 16.75, fontWeight: FontWeight.w700),
                ),
              ),
              if (canEdit) _ProfileActionButton(icon: Icons.add_rounded, text: 'Событие', onTap: () => _openCreate(selectedDay)),
              const SizedBox(width: 6),
              _ProfileRoundButton(icon: refreshing ? Icons.sync_rounded : Icons.refresh_rounded, onTap: () => _fetch()),
            ],
          ),
          const SizedBox(height: 10),
          if (selectedList.isEmpty)
            const _MiniEmpty(text: 'На выбранный день событий нет')
          else
            _buildProfileEventCardsList(selectedList),
        ],
      ),
    );
  }

  Widget _buildSlimCalendarBlock(DateTime weekStart) {
    final title = mode == CmrCalendarMode.month ? _monthTitle(cursor) : 'Неделя • ${_weekTitle(cursor)}';

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.transparent),
        boxShadow: _C.panelShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              _ProfileCalendarArrow(icon: Icons.chevron_left_rounded, onTap: _previousPeriod),
              Expanded(
                child: Center(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: _pickMonth,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                      child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _C.title.copyWith(fontSize: 15.05, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ),
              _ProfileCalendarArrow(icon: Icons.chevron_right_rounded, onTap: _nextPeriod),
              const SizedBox(width: 6),
              _ProfileRoundButton(icon: Icons.today_rounded, onTap: _today),
              const SizedBox(width: 6),
              _ProfileRoundButton(icon: Icons.open_in_full_rounded, onTap: _openFullCalendar),
            ],
          ),
          const SizedBox(height: 8),
          if (mode == CmrCalendarMode.month)
            _buildInlineMonthCalendar()
          else
            SizedBox(
              height: 380,
              child: CalendarWeekView(
                weekStartMonday: weekStart,
                eventsByDay: eventsByDay,
                selectedDay: selectedDay,
                onDayTap: _selectCalendarDayAndSyncPane,
                onDayLongPress: (d) {
                  if (!canEdit) return;
                  _selectCalendarDayAndSyncPane(d);
                  _openCreate(d);
                },
                onEventTap: _openDetails,
                onEventLongPress: (e) {
                  if (!canEdit) return;
                  _openEdit(e);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInlineMonthCalendar({double? maxHeight}) {
    const weekdays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    final first = DateTime(cursor.year, cursor.month, 1);
    final daysInMonth = DateTime(cursor.year, cursor.month + 1, 0).day;
    final prevMonthDays = DateTime(cursor.year, cursor.month, 0).day;
    final leading = first.weekday - 1;
    final total = ((leading + daysInMonth + 6) ~/ 7) * 7;
    final rowsCount = total ~/ 7;

    return Column(
      children: [
        Row(
          children: weekdays
              .map(
                (d) => Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: const TextStyle(color: _C.muted, fontSize: 10.55, fontWeight: FontWeight.w700, height: 1.15),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 5),
        LayoutBuilder(
          builder: (context, gridBox) {
            const gap = 5.0;
            final availableWidth = gridBox.maxWidth.isFinite ? gridBox.maxWidth : MediaQuery.sizeOf(context).width;
            final maxGridHeight = maxHeight != null && maxHeight!.isFinite ? math.max(180.0, maxHeight! - 20.0) : null;
            final cellWidth = (availableWidth - gap * 6) / 7;
            final naturalCellHeight = cellWidth / 1.22;
            final fittedCellHeight = maxGridHeight == null
                ? naturalCellHeight
                : (maxGridHeight - gap * (rowsCount - 1)) / rowsCount;
            final cellHeight = maxGridHeight == null
                ? naturalCellHeight
                : math.max(36.0, math.min(naturalCellHeight, fittedCellHeight));
            final ratio = math.max(.82, math.min(2.75, cellWidth / cellHeight));

            return GridView.builder(
              key: ValueKey('cmr-calendar-${cursor.year}-${cursor.month}-${selectedDay.toIso8601String()}'),
              itemCount: total,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: gap,
                crossAxisSpacing: gap,
                childAspectRatio: ratio,
              ),
              itemBuilder: (_, index) {
                final dayNumber = index - leading + 1;
                late DateTime day;
                var inMonth = true;
                if (dayNumber < 1) {
                  day = DateTime(cursor.year, cursor.month - 1, prevMonthDays + dayNumber);
                  inMonth = false;
                } else if (dayNumber > daysInMonth) {
                  day = DateTime(cursor.year, cursor.month + 1, dayNumber - daysInMonth);
                  inMonth = false;
                } else {
                  day = DateTime(cursor.year, cursor.month, dayNumber);
                }

                final list = eventsByDay[dateOnly(day)] ?? const <TeamEvent>[];
                final has = list.isNotEmpty;
                final eventAccent = has ? eventTypeColor(list.first.type) : _C.slate;
                final now = DateTime.now();
                final today = dateOnly(day) == dateOnly(now);
                final selected = dateOnly(day) == dateOnly(selectedDay);

                return Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _selectCalendarDayAndSyncPane(day),
                    onLongPress: () {
                      if (!canEdit) return;
                      _selectCalendarDayAndSyncPane(day);
                      _openCreate(day);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                      decoration: BoxDecoration(
                        gradient: null,
                        color: selected
                            ? Colors.white.withOpacity(.96)
                            : has
                                ? _C.softTint(eventAccent, opacity: .045)
                                : _C.soft,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: selected ? _C.microShadow : null,
                        border: selected
                            ? Border.all(color: _C.green.withOpacity(.28), width: 1.05)
                            : today
                                ? Border.all(color: _C.greenBorder)
                                : has
                                    ? Border.all(color: eventAccent.withOpacity(.12))
                                    : Border.all(color: Colors.transparent),
                      ),
                      child: Stack(
                        children: [
                          Center(
                            child: Text(
                              '${day.day}',
                              style: TextStyle(
                                color: selected
                                    ? _C.greenDark
                                    : inMonth
                                        ? (today ? _C.greenDark : _C.text)
                                        : _C.muted.withOpacity(.64),
                                fontSize: maxHeight == null ? 13 : 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (has)
                            Positioned(
                              top: 2,
                              right: 3,
                              child: _SegmentedEventBadge(events: list, selected: selected, size: maxHeight == null ? 16 : 15),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildProfileEventCardsList(List<TeamEvent> rows) {
    return Column(
      children: rows
          .map(
            (event) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _CmrEventTile(
                event: event,
                canEdit: canEdit,
                onDetails: () => _openDetails(event),
                onEdit: () => _openEdit(event),
                onDelete: () => _delete(event),
                onRating: () => _openTrainingRatings(event),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildCalendarDetailsPane(TeamEvent? event, List<TeamEvent> selectedList, {bool compact = false}) {
    if (_workPanel == _CalendarWorkPanel.editor) {
      final editing = _editingEventForPanel;
      final day = _createDateForPanel ?? selectedDay;
      final base = editing?.startAt ?? DateTime(day.year, day.month, day.day, 18, 0);
      return _InlineEventEditorPanel(
        title: editing == null ? 'Добавить событие' : 'Редактировать событие',
        subtitle: editing == null ? 'Выбранная дата: ${_dateTitle(day)}' : 'Измените данные события и сохраните обновления',
        icon: editing == null ? Icons.add_rounded : Icons.edit_calendar_rounded,
        accent: editing == null ? _C.green : eventTypeColor(editing.type),
        onClose: _closeWorkPanel,
        child: EventEditorSheet(
          primary: _C.green,
          teamId: widget.teamId,
          clubId: editing?.clubId ?? widget.clubId,
          createdBy: _editorCreatedBy,
          initialDateTime: base,
          initial: editing,
          onEventAdded: editing == null ? _handleAddMoreFromEditor : null,
          embedded: true,
        ),
        onSubmit: _handleEditorSubmit,
      );
    }

    if (_workPanel == _CalendarWorkPanel.details && event != null) {
      return _InlineEventDetailsPanel(
        event: event,
        teamName: widget.teamName,
        canEdit: canEdit,
        onClose: _closeWorkPanel,
        onBackToCalendar: _closeWorkPanel,
        onEdit: () => _openEdit(event),
        onDelete: () => _delete(event),
        onOpenRating: () => _openTrainingRatings(event),
      );
    }

    return _CalendarDetailsPlaceholder(
      teamName: widget.teamName,
      selectedDate: _dateTitle(selectedDay),
      eventsCount: selectedList.length,
      canEdit: canEdit,
      onAdd: () => _openCreate(selectedDay),
      onRefresh: () => _fetch(),
    );
  }

  Widget _buildMobileLayout(List<TeamEvent> selectedList, DateTime weekStart, BoxConstraints constraints) {
    final height = constraints.maxHeight.isFinite ? constraints.maxHeight : MediaQuery.sizeOf(context).height * .84;
    return SizedBox(
      width: double.infinity,
      height: height,
      child: Container(
        decoration: _C.cardDecoration,
        padding: const EdgeInsets.all(10),
        child: RefreshIndicator(
          color: _C.green,
          onRefresh: () => _fetch(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              _buildMobileHeader(selectedList),
              const SizedBox(height: 10),
              _buildModeSelector(),
              const SizedBox(height: 10),
              _buildSlimCalendarBlock(weekStart),
              const SizedBox(height: 10),
              _buildSelectedDayEventsWindow(selectedList),
              if (_workPanel == _CalendarWorkPanel.editor || _workPanel == _CalendarWorkPanel.details) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: _workPanel == _CalendarWorkPanel.editor ? 560 : 360,
                  child: _buildCalendarDetailsPane(_eventForRightPane(selectedList), selectedList, compact: true),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileHeader(List<TeamEvent> selectedList) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _C.cardDecoration,
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: _C.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.transparent)),
            child: const Icon(Icons.calendar_month_rounded, color: _C.text, size: 19),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_monthTitle(cursor), maxLines: 1, overflow: TextOverflow.ellipsis, style: _C.title.copyWith(fontSize: 15.25, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text('${_dateTitle(selectedDay)} · ${selectedList.length} ${_pluralEvent(selectedList.length)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _C.muted, fontSize: 11.05, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          if (canEdit) _ProfileRoundButton(icon: Icons.add_rounded, onTap: () => _openCreate(selectedDay)),
        ],
      ),
    );
  }

  Widget _buildModeSelector() {
    return Container(
      height: 34,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: _C.soft, borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.transparent)),
      child: Row(
        children: [
          Expanded(
            child: _ModeButton(
              text: 'Месяц',
              active: mode == CmrCalendarMode.month,
              onTap: () {
                if (mode == CmrCalendarMode.month) return;
                setState(() {
                  mode = CmrCalendarMode.month;
                  cursor = DateTime(selectedDay.year, selectedDay.month, 1);
                  _workPanel = _CalendarWorkPanel.calendar;
                  _selectedEventForPanel = null;
                });
                _fetch();
              },
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _ModeButton(
              text: 'Неделя',
              active: mode == CmrCalendarMode.week,
              onTap: () {
                if (mode == CmrCalendarMode.week) return;
                setState(() {
                  mode = CmrCalendarMode.week;
                  cursor = startOfWeekMonday(selectedDay);
                  _workPanel = _CalendarWorkPanel.calendar;
                  _selectedEventForPanel = null;
                });
                _fetch();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _legend() {
    Widget item(TeamEventType t) {
      final c = eventTypeColor(t);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(color: _C.soft, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.transparent)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 7, height: 7, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 6),
            Text(eventTypeLabel(t), style: const TextStyle(fontSize: 10.75, fontWeight: FontWeight.w700, color: _C.text, height: 1)),
          ],
        ),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        item(TeamEventType.training),
        item(TeamEventType.leagueMatch),
        item(TeamEventType.friendlyMatch),
        item(TeamEventType.theory),
        item(TeamEventType.gym),
        item(TeamEventType.dayOff),
      ],
    );
  }
}

class _C {
  // Windows 11 / Fluent Premium для календаря:
  // белая база, мягкий glass, графитовый текст и спокойные спортивные акценты.
  static const String font = 'Segoe UI';
  static const List<String> fallback = <String>[
    'SF Pro Display',
    'SF Pro Text',
    'Inter',
    'Roboto',
    'Arial',
  ];

  static const Color ink = Color(0xFF0B0F14);
  static const Color ink2 = Color(0xFF111827);
  static const Color inkSoft = Color(0xFF1F2937);

  static const Color bg = Color(0xFFF8FAFC);
  static const Color workspace = Color(0xFFFFFFFF);
  static const Color panel = Color(0xF8FFFFFF);
  static const Color card = Colors.white;
  static const Color surface = Color(0xFFFAFBFC);
  static const Color soft = Color(0xFFF6F7F9);
  static const Color soft2 = Color(0xFFF5F7FB);
  static const Color glass = Color(0xF8FFFFFF);
  static const Color border = Color(0xFFF0F2F4);
  static const Color borderStrong = Color(0xFFE5E7EB);

  static const Color text = Color(0xFF0B0F14);
  static const Color text2 = Color(0xFF111827);
  static const Color muted = Color(0xFF374151);
  static const Color muted2 = Color(0xFF6B7280);

  static const Color green = Color(0xFF0E9F5B);
  static const Color greenDark = Color(0xFF067A46);
  static const Color darkGreen = Color(0xFF067A46);
  static const Color accentSoft = Color(0xFFF3FBF7);
  static const Color greenSoft = Color(0xFFF3FBF7);
  static const Color greenSoft2 = Color(0xFFF8FEFA);
  static const Color accentBorder = Color(0xFFDCEFE5);
  static const Color greenBorder = Color(0xFFDCEFE5);

  static const Color blue = Color(0xFF2563EB);
  static const Color blueSoft = Color(0xFFF5F8FF);
  static const Color cyan = Color(0xFF0891B2);
  static const Color cyanSoft = Color(0xFFF0FDFF);
  static const Color slate = Color(0xFF475569);
  static const Color slateSoft = Color(0xFFF8FAFC);
  static const Color amber = Color(0xFFD97706);
  static const Color amberSoft = Color(0xFFFFFBEB);
  static const Color red = Color(0xFFD92D20);
  static const Color redSoft = Color(0xFFFEF2F2);
  static const Color winBlue = Color(0xFF2563EB);
  static const Color winCyan = Color(0xFF0891B2);
  static const Color winMint = Color(0xFF0F766E);
  static const Color winPurple = Color(0xFF475569);

  static Color softTint(Color color, {double opacity = .085}) => Color.alphaBlend(color.withOpacity(opacity), Colors.white);

  static Color accentByIndex(int index) {
    const colors = <Color>[green, blue, cyan, slate, amber];
    return colors[index.abs() % colors.length];
  }

  static Color accentSoftByIndex(int index) {
    const colors = <Color>[greenSoft, blueSoft, cyanSoft, slateSoft, amberSoft];
    return colors[index.abs() % colors.length];
  }

  static TextStyle _base({
    required double size,
    required FontWeight weight,
    required Color color,
    double height = 1.18,
    double letterSpacing = -0.10,
    List<FontFeature>? features,
  }) {
    return TextStyle(
      fontFamily: font,
      fontFamilyFallback: fallback,
      color: color,
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: letterSpacing,
      fontFeatures: features,
    );
  }

  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(.045),
          blurRadius: 34,
          spreadRadius: -14,
          offset: const Offset(0, 20),
        ),
        BoxShadow(
          color: Colors.black.withOpacity(.025),
          blurRadius: 10,
          spreadRadius: -7,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get microShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(.040),
          blurRadius: 20,
          spreadRadius: -12,
          offset: const Offset(0, 12),
        ),
      ];

  static List<BoxShadow> get panelShadow => softShadow;

  static BoxDecoration get workspaceDecoration => BoxDecoration(
        color: glass,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(.86), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.055),
            blurRadius: 38,
            spreadRadius: -18,
            offset: const Offset(0, 22),
          ),
          BoxShadow(
            color: blue.withOpacity(.035),
            blurRadius: 24,
            spreadRadius: -18,
            offset: const Offset(0, 10),
          ),
        ],
      );

  static BoxDecoration get cardDecoration => BoxDecoration(
        color: glass,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(.86), width: 1),
        boxShadow: softShadow,
      );

  static BoxDecoration panelDecoration({double radius = 22}) => BoxDecoration(
        color: Colors.white.withOpacity(.62),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withOpacity(.70), width: 1),
      );

  static BoxDecoration seamlessPaneDecoration({double radius = 22}) => BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(radius),
      );

  static BoxDecoration fluentSurface({double radius = 16, bool active = false, Color? accent, bool elevated = true}) => BoxDecoration(
        color: active ? Colors.white.withOpacity(.96) : Colors.white.withOpacity(.82),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: active && accent != null ? Color.alphaBlend(accent.withOpacity(.18), Colors.white) : Colors.white.withOpacity(.78),
          width: 1,
        ),
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(active ? .040 : .025),
                  blurRadius: active ? 20 : 14,
                  spreadRadius: -12,
                  offset: Offset(0, active ? 12 : 8),
                ),
              ]
            : null,
      );

  static BoxDecoration softCard({double radius = 18, Color? tint}) => BoxDecoration(
        color: tint ?? Colors.white.withOpacity(.76),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withOpacity(.70), width: 1),
      );

  static BoxDecoration accentCard({required Color color, double radius = 18}) => BoxDecoration(
        color: Color.alphaBlend(color.withOpacity(.060), Colors.white),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: color.withOpacity(.16), width: 1),
        boxShadow: microShadow,
      );

  static TextStyle get title => _base(
        size: 17.2,
        weight: FontWeight.w700,
        color: text,
        height: 1.10,
        letterSpacing: -0.34,
      );

  static TextStyle section() => _base(
        size: 13.4,
        weight: FontWeight.w700,
        color: text,
        height: 1.12,
        letterSpacing: -0.22,
      );

  static TextStyle value(double size) => _base(
        size: size,
        weight: FontWeight.w700,
        color: text,
        height: 1.08,
        letterSpacing: -0.25,
        features: const [FontFeature.tabularFigures()],
      );

  static TextStyle mutedStyle(double size, {FontWeight weight = FontWeight.w500}) => _base(
        size: size,
        weight: weight,
        color: muted,
        height: 1.34,
        letterSpacing: -0.05,
      );

  static TextStyle caption() => _base(
        size: 10.6,
        weight: FontWeight.w600,
        color: muted2,
        height: 1.10,
        letterSpacing: .08,
      );

  static TextStyle tab({bool active = false}) => _base(
        size: 11.8,
        weight: FontWeight.w700,
        color: active ? greenDark : text,
        height: 1,
      );

  static TextStyle tabSelected() => tab(active: true);

  static TextStyle action() => _base(
        size: 11.8,
        weight: FontWeight.w700,
        color: text,
        height: 1.05,
      );

  static TextStyle danger() => _base(
        size: 11.8,
        weight: FontWeight.w700,
        color: red,
        height: 1,
      );
}

String? _calendarRatingText(dynamic value) {
  if (value == null) return null;
  if (value is num) {
    if (!value.isFinite || value <= 0) return null;
    return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
  }

  final text = '$value'.trim();
  if (text.isEmpty) return null;
  final lower = text.toLowerCase();
  if (lower == 'null' || lower == '—' || lower == '-' || lower == '0') return null;
  return text;
}

String? _readCalendarRating(List<dynamic Function()> readers) {
  for (final read in readers) {
    try {
      final value = _calendarRatingText(read());
      if (value != null) return value;
    } catch (_) {
      // Поле может отсутствовать в TeamEvent после разных версий модели.
    }
  }
  return null;
}

String? _eventCoachRatingText(TeamEvent event) {
  final dynamic e = event;
  return _readCalendarRating([
    () => e.coachRating,
    () => e.trainerRating,
    () => e.coachScore,
    () => e.trainerScore,
    () => e.coachMark,
    () => e.trainerMark,
    () => e.coachEvaluation,
    () => e.trainerEvaluation,
    () => e.coachAssessment,
    () => e.trainerAssessment,
    () => e.coach_rating,
    () => e.trainer_rating,
    () => e.coach_score,
    () => e.trainer_score,
  ]);
}


class _BrandAccentLine extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const _BrandAccentLine({this.width = 3, this.height = 18, this.radius = 99});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: _C.green,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _CalendarKpiData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String hint;

  const _CalendarKpiData({required this.label, required this.value, required this.icon, required this.color, required this.hint});
}

class _CalendarHeaderSide extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String metric;
  final String metricLabel;
  final Color accent;
  final bool alignEnd;

  const _CalendarHeaderSide({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.metric,
    required this.metricLabel,
    required this.accent,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: alignEnd ? TextAlign.right : TextAlign.left, style: const TextStyle(color: _C.text, fontSize: 14.05, fontWeight: FontWeight.w700, height: 1.0)),
        const SizedBox(height: 5),
        Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: alignEnd ? TextAlign.right : TextAlign.left, style: const TextStyle(color: _C.muted, fontSize: 10.25, fontWeight: FontWeight.w600, height: 1.0)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(color: Color.alphaBlend(accent.withOpacity(.08), Colors.white), borderRadius: BorderRadius.circular(6), border: Border.all(color: Colors.transparent)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(metric, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: accent, fontSize: 11.15, fontWeight: FontWeight.w700, height: 1)),
              const SizedBox(width: 6),
              Text(metricLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _C.muted, fontSize: 9.25, fontWeight: FontWeight.w600, height: 1)),
            ],
          ),
        ),
      ],
    );

    final badge = Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: Colors.transparent)),
      child: Icon(icon, color: accent == _C.green ? _C.greenDark : accent, size: 18),
    );

    return Row(
      mainAxisAlignment: alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: alignEnd ? [Expanded(child: content), const SizedBox(width: 6), badge] : [badge, const SizedBox(width: 6), Expanded(child: content)],
    );
  }
}

class _CalendarHeaderCenter extends StatelessWidget {
  final String title;
  final String subtitle;
  final String status;
  final String count;

  const _CalendarHeaderCenter({required this.title, required this.subtitle, required this.status, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(color: _C.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.transparent)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(color: _C.text, fontSize: 15.95, fontWeight: FontWeight.w700, height: 1.05)),
          const SizedBox(height: 5),
          Text(status, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _C.greenDark, fontSize: 9.65, fontWeight: FontWeight.w700, letterSpacing: .25, height: 1)),
          const SizedBox(height: 5),
          Text('$subtitle · $count', maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(color: _C.muted, fontSize: 9.65, fontWeight: FontWeight.w600, height: 1.1)),
        ],
      ),
    );
  }
}

class _CalendarTopLine extends StatelessWidget {
  final String label;
  final String value;
  final String subvalue;
  final IconData icon;
  final Color color;

  const _CalendarTopLine({required this.label, required this.value, required this.subvalue, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(color: Color.alphaBlend(color.withOpacity(.045), Colors.white), borderRadius: BorderRadius.circular(12), boxShadow: _C.microShadow),
      child: Row(
        children: [
          Container(width: 4, height: 22, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(99))),
          const SizedBox(width: 7),
          Container(width: 27, height: 27, decoration: BoxDecoration(color: color.withOpacity(.08), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: color, size: 13)),
          const SizedBox(width: 7),
          Expanded(
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: _C.caption().copyWith(fontSize: 9.05)),
              const SizedBox(height: 3),
              Row(children: [
                Flexible(child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: _C.action().copyWith(fontSize: 10.75))),
                const SizedBox(width: 5),
                Flexible(child: Text(subvalue, maxLines: 1, overflow: TextOverflow.ellipsis, style: _C.caption().copyWith(fontSize: 9.05))),
              ]),
            ]),
          ),
        ],
      ),
    );
  }
}

class _CalendarRightHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? trailing;

  const _CalendarRightHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 60),
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      color: Colors.white,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _C.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.transparent),
            ),
            child: Icon(icon, color: _C.text, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _C.title.copyWith(fontSize: 14.95)),
                const SizedBox(height: 3),
                Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: _C.mutedStyle(11.4)),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class _CalendarSideKpi extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String hint;
  final Color color;

  const _CalendarSideKpi({required this.icon, required this.label, required this.value, required this.hint, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: Color.alphaBlend(color.withOpacity(.045), Colors.white),
        borderRadius: BorderRadius.circular(14),
        boxShadow: _C.microShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(color: Color.alphaBlend(color.withOpacity(.08), Colors.white), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 11.5),
              ),
              const Spacer(),
              Flexible(
                child: Text(value, maxLines: 1, textAlign: TextAlign.right, overflow: TextOverflow.ellipsis, style: _C.value(14.8)),
              ),
            ],
          ),
          const Spacer(),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: _C.caption().copyWith(color: _C.text, fontSize: 9.25)),
          const SizedBox(height: 1),
          Text(hint, maxLines: 1, overflow: TextOverflow.ellipsis, style: _C.caption().copyWith(fontSize: 8.35)),
        ],
      ),
    );
  }
}

class _CalendarNextEventStrip extends StatelessWidget {
  final TeamEvent event;
  final String title;

  const _CalendarNextEventStrip({required this.event, required this.title});

  @override
  Widget build(BuildContext context) {
    final color = eventTypeColor(event.type);
    final date = '${event.startAt.day.toString().padLeft(2, '0')}.${event.startAt.month.toString().padLeft(2, '0')}.${event.startAt.year}';
    final time = event.endAt == null ? hhmm(event.startAt) : '${hhmm(event.startAt)}–${hhmm(event.endAt!)}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(color: Color.alphaBlend(color.withOpacity(.045), Colors.white), borderRadius: BorderRadius.circular(16), boxShadow: _C.microShadow),
      child: Row(
        children: [
          Container(width: 4, height: 38, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(99))),
          const SizedBox(width: 9),
          Container(width: 34, height: 34, decoration: BoxDecoration(color: Color.alphaBlend(color.withOpacity(.08), Colors.white), borderRadius: BorderRadius.circular(11)), child: Icon(Icons.event_available_rounded, color: color, size: 16)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _C.title.copyWith(fontSize: 13.8)),
              const SizedBox(height: 3),
              Text('$date · $time', maxLines: 1, overflow: TextOverflow.ellipsis, style: _C.mutedStyle(10.8)),
            ]),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: _C.fluentSurface(radius: 999, active: true, accent: color, elevated: false),
            child: Text(eventTypeLabel(event.type), maxLines: 1, overflow: TextOverflow.ellipsis, style: _C.action().copyWith(color: color, fontSize: 10.5)),
          ),
        ],
      ),
    );
  }
}

class _CalendarInfoCell extends StatelessWidget {
  final _CalendarKpiData item;

  const _CalendarInfoCell({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Color.alphaBlend(item.color.withOpacity(.045), Colors.white),
        borderRadius: BorderRadius.circular(13),
        boxShadow: _C.microShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 22,
            decoration: BoxDecoration(color: item.color, borderRadius: BorderRadius.circular(99)),
          ),
          const SizedBox(width: 7),
          Container(
            width: 25,
            height: 25,
            decoration: BoxDecoration(color: item.color.withOpacity(.075), borderRadius: BorderRadius.circular(8)),
            child: Icon(item.icon, color: item.color, size: 13),
          ),
          const SizedBox(width: 7),
          Text(item.value, maxLines: 1, overflow: TextOverflow.ellipsis, style: _C.value(13.8)),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: _C.caption().copyWith(color: _C.text, fontSize: 9.35)),
                const SizedBox(height: 2),
                Text(item.hint, maxLines: 1, overflow: TextOverflow.ellipsis, style: _C.caption().copyWith(fontSize: 8.8)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarKpiTile extends StatelessWidget {
  final _CalendarKpiData item;

  const _CalendarKpiTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.80),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(.72), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.88),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: item.color.withOpacity(.16), width: 1),
            ),
            child: Icon(item.icon, color: item.color, size: 15),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _C.muted, fontSize: 9.45, fontWeight: FontWeight.w700, height: 1)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(item.value, maxLines: 1, style: const TextStyle(color: _C.text, fontSize: 14.55, fontWeight: FontWeight.w700, height: 1)),
                    const SizedBox(width: 6),
                    Expanded(child: Text(item.hint, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _C.muted, fontSize: 8.95, fontWeight: FontWeight.w600, height: 1))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StrictWorkspaceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;
  final bool dense;

  const _StrictWorkspaceCard({required this.icon, required this.title, required this.subtitle, required this.child, this.trailing, this.dense = false});

  @override
  Widget build(BuildContext context) {
    final accent = _C.accentByIndex(icon.codePoint);
    final outerPadding = dense ? 10.0 : 12.0;
    final iconSize = dense ? 36.0 : 40.0;

    final header = Row(
      children: [
        Container(width: iconSize, height: iconSize, decoration: _C.fluentSurface(radius: dense ? 13 : 14, accent: accent, elevated: false), child: Icon(icon, color: accent, size: dense ? 17 : 19)),
        SizedBox(width: dense ? 8 : 10),
        Expanded(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _C.title.copyWith(fontSize: dense ? 14.0 : 16.0)),
            const SizedBox(height: 4),
            Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: _C.mutedStyle(dense ? 10.4 : 11.3)),
          ]),
        ),
        if (trailing != null) ...[SizedBox(width: dense ? 6 : 8), trailing!],
      ],
    );

    return Container(
      decoration: _C.seamlessPaneDecoration(),
      padding: EdgeInsets.all(outerPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          SizedBox(height: dense ? 10 : 12),
          if (dense) child else Expanded(child: child),
        ],
      ),
    );
  }
}


class _CalendarTypeData {
  final TeamEventType type;
  final String label;

  const _CalendarTypeData(this.type, this.label);
}

class _CalendarTypeTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _CalendarTypeTile({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: _C.softTint(color, opacity: .075),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(.10)),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: _C.softTint(color, opacity: .12),
              borderRadius: BorderRadius.circular(9),
            ),
            alignment: Alignment.center,
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 11.2,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _C.text,
                fontSize: 10.4,
                fontWeight: FontWeight.w700,
                height: 1.05,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCalendarArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ProfileCalendarArrow({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: _C.microShadow,
        ),
        child: Icon(icon, color: _C.inkSoft, size: 18),
      ),
    );
  }
}

class _ProfileRoundButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ProfileRoundButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final emphasized = icon == Icons.add_rounded;
    final radius = BorderRadius.circular(13);
    final accent = emphasized ? _C.green : _C.slate;
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: _C.fluentSurface(radius: 13, accent: emphasized ? _C.green : _C.blue, active: emphasized, elevated: false),
          child: Icon(icon, color: accent, size: 18),
        ),
      ),
    );
  }
}

class _ProfileActionButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  const _ProfileActionButton({required this.icon, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: _C.fluentSurface(radius: 999, active: true, accent: _C.green, elevated: false),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: _C.green),
            const SizedBox(width: 7),
            Text(text, style: _C.action().copyWith(color: _C.greenDark, fontSize: 11.2)),
          ]),
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String text;
  final bool active;
  final VoidCallback onTap;

  const _ModeButton({required this.text, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 32,
          decoration: _C.fluentSurface(radius: 999, active: active, accent: _C.green, elevated: false),
          alignment: Alignment.center,
          child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: _C.action().copyWith(color: active ? _C.greenDark : _C.text.withOpacity(.78), fontSize: 11.2)),
        ),
      ),
    );
  }
}

class _SegmentedEventBadge extends StatelessWidget {
  final List<TeamEvent> events;
  final bool selected;
  final double size;

  const _SegmentedEventBadge({required this.events, required this.selected, this.size = 18});

  @override
  Widget build(BuildContext context) {
    final colors = events.map((event) => eventTypeColor(event.type)).take(3).toList(growable: false);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _SegmentedEventBadgePainter(colors: colors, borderColor: Colors.white),
        child: events.length > 1
            ? Center(
                child: Text(events.length > 9 ? '9+' : '${events.length}', style: const TextStyle(color: Colors.white, fontSize: 8.4, fontWeight: FontWeight.w700, height: 1, shadows: [Shadow(color: Color(0x66000000), blurRadius: 4)])),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}

class _SegmentedEventBadgePainter extends CustomPainter {
  final List<Color> colors;
  final Color borderColor;

  const _SegmentedEventBadgePainter({required this.colors, required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final safeColors = colors.isEmpty ? const [Color(0xFF008F62)] : colors;
    final fill = Paint()..style = PaintingStyle.fill;
    if (safeColors.length == 1) {
      fill.color = safeColors.first;
      canvas.drawOval(rect, fill);
    } else {
      final sweep = (math.pi * 2) / safeColors.length;
      var start = -math.pi / 2;
      for (final color in safeColors) {
        fill.color = color;
        canvas.drawArc(rect, start, sweep, true, fill);
        start += sweep;
      }
    }
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = borderColor;
    canvas.drawOval(rect.deflate(.75), border);
  }

  @override
  bool shouldRepaint(covariant _SegmentedEventBadgePainter oldDelegate) {
    if (oldDelegate.borderColor != borderColor) return true;
    if (oldDelegate.colors.length != colors.length) return true;
    for (var i = 0; i < colors.length; i++) {
      if (oldDelegate.colors[i] != colors[i]) return true;
    }
    return false;
  }
}

class _CmrEventTile extends StatelessWidget {
  final TeamEvent event;
  final bool canEdit;
  final VoidCallback onDetails;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onRating;

  const _CmrEventTile({required this.event, required this.canEdit, required this.onDetails, required this.onEdit, required this.onDelete, this.onRating});

  String get _timeText {
    if (event.endAt == null) return hhmm(event.startAt);
    return '${hhmm(event.startAt)}–${hhmm(event.endAt!)}';
  }

  @override
  Widget build(BuildContext context) {
    final c = eventTypeColor(event.type);
    final location = event.location.trim();
    final coachRating = _eventCoachRatingText(event);
    final hasRatings = coachRating != null;
    final isTrainingLike = event.type == TeamEventType.training || event.type == TeamEventType.gym;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: onDetails,
        child: Container(
          decoration: BoxDecoration(
            color: _C.softTint(c, opacity: .040),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(.62)),
            boxShadow: _C.microShadow,
          ),
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Container(width: 4, height: hasRatings ? 68 : 46, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(5))),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(event.title.trim().isEmpty ? 'Событие календаря' : event.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _C.text, fontSize: 12.85, fontWeight: FontWeight.w700))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(color: Color.alphaBlend(c.withOpacity(.10), Colors.white), borderRadius: BorderRadius.circular(5), border: Border.all(color: Colors.transparent)),
                          child: Text(eventTypeLabel(event.type), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: c, fontSize: 8.95, fontWeight: FontWeight.w700, height: 1)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded, color: c, size: 14),
                        const SizedBox(width: 5),
                        Text(_timeText, style: const TextStyle(color: _C.text, fontSize: 11.55, fontWeight: FontWeight.w600)),
                        if (location.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.location_on_outlined, color: _C.muted, size: 13),
                          const SizedBox(width: 4),
                          Expanded(child: Text(location, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _C.muted, fontSize: 11.05, fontWeight: FontWeight.w700))),
                        ],
                      ],
                    ),
                    if (hasRatings) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 5,
                        runSpacing: 4,
                        children: [
                          if (coachRating != null)
                            _CalendarRatingChip(icon: Icons.workspace_premium_rounded, label: 'Тренер', value: coachRating, color: _C.greenDark),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (canEdit) ...[
                const SizedBox(width: 6),
                if (isTrainingLike && onRating != null) ...[
                  _MiniIconButton(icon: Icons.star_rate_rounded, onTap: onRating!),
                  const SizedBox(width: 5),
                ],
                _MiniIconButton(icon: Icons.edit_rounded, onTap: onEdit),
                const SizedBox(width: 5),
                _MiniIconButton(icon: Icons.delete_outline_rounded, onTap: onDelete, danger: true),
              ],
            ],
          ),
        ),
      ),
    );
  }
}


class _CalendarRatingChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _CalendarRatingChip({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Color.alphaBlend(color.withOpacity(.08), Colors.white),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.transparent),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _C.muted, fontSize: 9.25, fontWeight: FontWeight.w600, height: 1)),
          const SizedBox(width: 4),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontSize: 10.05, fontWeight: FontWeight.w700, height: 1)),
        ],
      ),
    );
  }
}

class _MiniIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool danger;

  const _MiniIconButton({required this.icon, required this.onTap, this.danger = false});

  @override
  Widget build(BuildContext context) {
    final c = danger ? _C.red : _C.text;
    return InkWell(
      borderRadius: BorderRadius.circular(5),
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(color: Color.alphaBlend(c.withOpacity(.08), Colors.white), borderRadius: BorderRadius.circular(5), border: Border.all(color: Colors.transparent)),
        child: Icon(icon, color: c, size: 13),
      ),
    );
  }
}

class _CalendarDetailsPlaceholder extends StatelessWidget {
  final String teamName;
  final String selectedDate;
  final int eventsCount;
  final bool canEdit;
  final VoidCallback onAdd;
  final VoidCallback onRefresh;

  const _CalendarDetailsPlaceholder({required this.teamName, required this.selectedDate, required this.eventsCount, required this.canEdit, required this.onAdd, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return _StrictWorkspaceCard(
      icon: Icons.fact_check_outlined,
      title: 'Детали дня',
      subtitle: teamName,
      trailing: _ProfileRoundButton(icon: Icons.refresh_rounded, onTap: onRefresh),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoBox(icon: Icons.calendar_today_rounded, title: selectedDate, text: eventsCount == 0 ? 'На выбранный день событий пока нет. Можно добавить тренировку, матч, теорию или другой пункт расписания.' : 'Выберите событие в ленте дня, чтобы открыть подробности справа.'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _HeroStat(value: '$eventsCount', title: 'на день')),
                const SizedBox(width: 6),
                Expanded(child: _HeroStat(value: canEdit ? 'Да' : 'Нет', title: 'редакт.')),
              ],
            ),
            const SizedBox(height: 12),
            if (canEdit)
              _SheetActionButton(icon: Icons.add_rounded, text: 'Добавить событие', onTap: onAdd)
            else
              const _MutedHint('Для роли игрока редактирование календаря отключено.'),
          ],
        ),
      ),
    );
  }
}

class _InlineEventDetailsPanel extends StatelessWidget {
  final TeamEvent event;
  final String teamName;
  final bool canEdit;
  final VoidCallback onClose;
  final VoidCallback onBackToCalendar;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onOpenRating;

  const _InlineEventDetailsPanel({required this.event, required this.teamName, required this.canEdit, required this.onClose, required this.onBackToCalendar, required this.onEdit, required this.onDelete, required this.onOpenRating});

  String get _dateText => '${event.startAt.day.toString().padLeft(2, '0')}.${event.startAt.month.toString().padLeft(2, '0')}.${event.startAt.year}';
  String get _timeText => event.endAt == null ? hhmm(event.startAt) : '${hhmm(event.startAt)}–${hhmm(event.endAt!)}';

  @override
  Widget build(BuildContext context) {
    final c = eventTypeColor(event.type);
    final notes = event.notes.trim();
    final location = event.location.trim();
    final coachRating = _eventCoachRatingText(event);
    final isTrainingLike = event.type == TeamEventType.training || event.type == TeamEventType.gym;
    return _StrictWorkspaceCard(
      icon: Icons.event_note_rounded,
      title: event.title.trim().isEmpty ? 'Событие календаря' : event.title,
      subtitle: '${eventTypeLabel(event.type)} · $_dateText · $_timeText',
      trailing: _ProfileRoundButton(icon: Icons.close_rounded, onTap: onClose),
      child: SingleChildScrollView(
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: _DetailMetric(icon: Icons.schedule_rounded, title: 'Время', value: _timeText, accent: c)),
                const SizedBox(width: 6),
                Expanded(child: _DetailMetric(icon: Icons.category_rounded, title: 'Тип', value: eventTypeLabel(event.type), accent: c)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _DetailMetric(icon: Icons.calendar_month_rounded, title: 'Дата', value: _dateText, accent: c)),
                const SizedBox(width: 6),
                Expanded(child: _DetailMetric(icon: Icons.location_on_outlined, title: 'Место', value: location.isEmpty ? 'Не указано' : location, accent: c)),
              ],
            ),
            if (coachRating != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _DetailMetric(
                      icon: Icons.workspace_premium_rounded,
                      title: 'Оценка тренера',
                      value: coachRating,
                      accent: _C.greenDark,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            _InfoBox(icon: Icons.notes_rounded, title: 'Заметки', text: notes.isEmpty ? 'Заметки не добавлены.' : notes),
            const SizedBox(height: 10),
            if (canEdit && isTrainingLike) ...[
              _SheetActionButton(
                icon: Icons.star_rate_rounded,
                text: 'Оценка игроков',
                onTap: onOpenRating,
              ),
              const SizedBox(height: 8),
            ] else if (canEdit) ...[
              const _MutedHint('Оценка доступна только для тренировок и ОФП.'),
              const SizedBox(height: 8),
            ],
            if (canEdit)
              Row(
                children: [
                  Expanded(child: _SheetActionButton(icon: Icons.edit_rounded, text: 'Редактировать', onTap: onEdit)),
                  const SizedBox(width: 6),
                  Expanded(child: _SheetActionButton(icon: Icons.delete_outline_rounded, text: 'Удалить', onTap: onDelete, danger: true)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _InlineEventEditorPanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final Widget child;
  final VoidCallback onClose;
  final Future<void> Function(TeamEvent event) onSubmit;

  const _InlineEventEditorPanel({required this.title, required this.subtitle, required this.icon, required this.accent, required this.child, required this.onClose, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _C.panelDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            constraints: const BoxConstraints(minHeight: 54),
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            decoration: const BoxDecoration(color: Colors.transparent),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.88),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: accent.withOpacity(.16), width: 1),
                    boxShadow: _C.microShadow,
                  ),
                  child: Icon(icon, color: accent, size: 15),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _C.text, fontSize: 13.45, fontWeight: FontWeight.w700, height: 1.05)),
                      const SizedBox(height: 3),
                      Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _C.muted, fontSize: 10.05, fontWeight: FontWeight.w600, height: 1.05)),
                    ],
                  ),
                ),
                _ProfileRoundButton(icon: Icons.close_rounded, onTap: onClose),
              ],
            ),
          ),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(color: Colors.transparent),
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Navigator(
                  pages: [MaterialPage<void>(key: ValueKey('calendar-event-editor-$title-$subtitle'), child: child)],
                  onPopPage: (route, result) {
                    if (!route.didPop(result)) return false;
                    if (result is TeamEvent) {
                      onSubmit(result);
                    } else {
                      onClose();
                    }
                    return true;
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailMetric extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color accent;

  const _DetailMetric({required this.icon, required this.title, required this.value, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.80),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(.72), width: 1),
      ),
      child: Row(
        children: [
          Container(width: 30, height: 30, decoration: BoxDecoration(color: Color.alphaBlend(accent.withOpacity(.10), Colors.white), borderRadius: BorderRadius.circular(6)), child: Icon(icon, color: accent, size: 15)),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _C.muted, fontSize: 10.35, fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _C.text, fontSize: 11.85, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _InfoBox({required this.icon, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(color: _C.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.transparent)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _C.greenDark, size: 15),
              const SizedBox(width: 7),
              Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _C.text, fontSize: 11.85, fontWeight: FontWeight.w700))),
            ],
          ),
          const SizedBox(height: 5),
          Text(text, style: const TextStyle(color: _C.muted, fontSize: 11.55, fontWeight: FontWeight.w700, height: 1.35)),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String value;
  final String title;
  final Color accent;

  const _HeroStat({
    required this.value,
    required this.title,
    this.accent = _C.blue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.80),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(.72), width: 1),
      ),
      child: Column(
        children: [
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _C.text, fontSize: 16.75, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _C.muted, fontSize: 10.35, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _SheetActionButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  final bool danger;

  const _SheetActionButton({required this.icon, required this.text, required this.onTap, this.danger = false});

  @override
  Widget build(BuildContext context) {
    final color = danger ? _C.red : _C.greenDark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.92),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(.18), width: 1),
            boxShadow: _C.microShadow,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 7),
              Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w700))),
            ],
          ),
        ),
      ),
    );
  }
}

class _MutedHint extends StatelessWidget {
  final String text;

  const _MutedHint(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(color: _C.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.transparent)),
      child: Text(text, style: const TextStyle(color: _C.muted, fontSize: 11.55, fontWeight: FontWeight.w600)),
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
        padding: const EdgeInsets.all(24),
        child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: _C.muted, fontWeight: FontWeight.w700, height: 1.4)),
      ),
    );
  }
}

class _CmrEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  final String? actionText;
  final VoidCallback? onAction;

  const _CmrEmptyState({required this.icon, required this.title, required this.text, this.actionText, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _C.cardDecoration,
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: _C.greenDark, size: 48),
              const SizedBox(height: 14),
              Text(title, textAlign: TextAlign.center, style: _C.title.copyWith(fontSize: 20.4)),
              const SizedBox(height: 8),
              Text(text, textAlign: TextAlign.center, style: const TextStyle(color: _C.muted, height: 1.45, fontWeight: FontWeight.w600)),
              if (actionText != null && onAction != null) ...[
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(actionText!),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: _C.greenDark, elevation: 0, side: BorderSide(color: _C.green.withOpacity(.18)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
