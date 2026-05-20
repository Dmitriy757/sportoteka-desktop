import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/presentation/team_calendar_screen/calendar_month_grid.dart';
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

    DateTime from;
    DateTime to;

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
        final k = dateOnly(e.startAt);
        (grouped[k] ??= []).add(e);
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

  Future<void> _openCreate(DateTime day) async {
    if (!canEdit) return;

    final createdBy = await PrefUtils.getUserId() ?? 0;
    if (!mounted) return;

    setState(() {
      selectedDay = day;
      _editorCreatedBy = createdBy;
      _createDateForPanel = day;
      _editingEventForPanel = null;
      _selectedEventForPanel = null;
      _workPanel = _CalendarWorkPanel.editor;
    });
  }

  Future<void> _openEdit(TeamEvent current) async {
    if (!canEdit) return;

    final createdBy = await PrefUtils.getUserId() ?? 0;
    if (!mounted) return;

    setState(() {
      selectedDay = current.startAt;
      _editorCreatedBy = createdBy;
      _editingEventForPanel = current;
      _createDateForPanel = current.startAt;
      _selectedEventForPanel = current;
      _workPanel = _CalendarWorkPanel.editor;
    });
  }

  Future<void> _openDetails(TeamEvent e) async {
    if (!mounted) return;

    setState(() {
      selectedDay = e.startAt;
      _selectedEventForPanel = e;
      _editingEventForPanel = null;
      _createDateForPanel = null;
      _workPanel = _CalendarWorkPanel.details;
    });
  }

  void _closeWorkPanel() {
    if (!mounted) return;
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

  Future<void> _delete(TeamEvent e) async {
    if (!canEdit) return;

    final ok = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Удалить событие?'),
        content: Text('«${e.title}» будет удалено из календаря.'),
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
      await api.remove(eventId: e.id, teamId: widget.teamId);
      await _fetch();
      if (mounted && _selectedEventForPanel?.id == e.id) {
        _closeWorkPanel();
      }
      Get.snackbar('Готово', 'Событие удалено');
    } catch (err) {
      Get.snackbar('Ошибка', err.toString(), snackPosition: SnackPosition.BOTTOM);
    }
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
    });
    _fetch();
  }

  void _today() {
    final now = DateTime.now();
    setState(() {
      cursor = now;
      selectedDay = now;
    });
    _fetch();
  }

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: cursor,
      firstDate: DateTime(now.year - 5, 1, 1),
      lastDate: DateTime(now.year + 5, 12, 31),
      helpText: 'Выберите месяц календаря',
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
      cursor = DateTime(picked.year, picked.month, 1);
      selectedDay = DateTime(picked.year, picked.month, picked.day);
      mode = CmrCalendarMode.month;
    });
    _fetch();
  }

  void _selectCalendarDay(DateTime day) {
    final nextCursor = mode == CmrCalendarMode.month
        ? DateTime(day.year, day.month, 1)
        : startOfWeekMonday(day);

    final needReload = mode == CmrCalendarMode.month
        ? (nextCursor.year != cursor.year || nextCursor.month != cursor.month)
        : dateOnly(nextCursor) != dateOnly(startOfWeekMonday(cursor));

    setState(() {
      selectedDay = day;
      if (needReload) cursor = nextCursor;
    });

    if (needReload) _fetch();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 700;

    if (loading) {
      return Container(
        decoration: _C.cardDecoration,
        child: const Center(
          child: CircularProgressIndicator(color: _C.green),
        ),
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

    final selectedList = (eventsByDay[dateOnly(selectedDay)] ?? const <TeamEvent>[])
        .toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));

    final weekStart = startOfWeekMonday(cursor);

    if (isMobile) {
      return _buildMobileLayout(selectedList, weekStart);
    }

    return Row(
      children: [
        SizedBox(
          width: size.width >= 1100 ? 390 : 340,
          child: _buildAgendaColumn(selectedList),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _workPanel == _CalendarWorkPanel.calendar
              ? _buildCalendarArea(weekStart)
              : _buildWorkPanel(),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(List<TeamEvent> selectedList, DateTime weekStart) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          _buildMobileHeader(selectedList),
          Expanded(
            child: RefreshIndicator(
              color: _C.green,
              onRefresh: () => _fetch(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
                children: [
                  if (_workPanel == _CalendarWorkPanel.calendar) ...[
                    _buildCalendarArea(weekStart),
                    const SizedBox(height: 12),
                    _SelectedDayHeader(
                      title: _dateTitle(selectedDay),
                      canEdit: canEdit,
                      onAdd: () => _openCreate(selectedDay),
                    ),
                    const SizedBox(height: 10),
                    if (selectedList.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: _C.cardDecoration.copyWith(
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: [],
                        ),
                        child: const Text(
                          'На выбранный день событий нет',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _C.muted,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      )
                    else
                      ...selectedList.map(
                        (event) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _CmrEventTile(
                            event: event,
                            canEdit: canEdit,
                            onDetails: () => _openDetails(event),
                            onEdit: () => _openEdit(event),
                            onDelete: () => _delete(event),
                          ),
                        ),
                      ),
                  ] else
                    SizedBox(
                      height: MediaQuery.of(context).size.height * .76,
                      child: _buildWorkPanel(),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileHeader(List<TeamEvent> selectedList) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _CmrIconBox(icon: Icons.calendar_month_rounded, dark: true),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.teamName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _C.title.copyWith(fontSize: 18),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      mode == CmrCalendarMode.month
                          ? _monthTitle(cursor)
                          : 'Неделя ${_weekTitle(cursor)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _C.muted,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              _HeaderIconButton(
                icon: refreshing ? Icons.sync_rounded : Icons.refresh_rounded,
                onTap: _fetch,
              ),
              const SizedBox(width: 8),
              _HeaderIconButton(
                icon: Icons.open_in_full_rounded,
                onTap: _openFullCalendar,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _HeroStat(value: '${events.length}', title: 'событий')),
              const SizedBox(width: 8),
              Expanded(child: _HeroStat(value: '${selectedList.length}', title: 'на день')),
              const SizedBox(width: 8),
              Expanded(child: _HeroStat(value: canEdit ? 'Да' : 'Нет', title: 'редакт.')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAgendaColumn(List<TeamEvent> selectedList) {
    return Container(
      decoration: _C.cardDecoration,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const _CmrIconBox(icon: Icons.calendar_month_rounded, dark: true),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.teamName, maxLines: 1, overflow: TextOverflow.ellipsis, style: _C.title.copyWith(fontSize: 19)),
                          const SizedBox(height: 4),
                          Text(
                            'Календарь команды',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: _C.muted, fontWeight: FontWeight.w700, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    _HeaderIconButton(icon: refreshing ? Icons.sync_rounded : Icons.refresh_rounded, onTap: _fetch),
                    const SizedBox(width: 8),
                    _HeaderIconButton(icon: Icons.open_in_full_rounded, onTap: _openFullCalendar),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _HeroStat(value: '${events.length}', title: 'событий')),
                    const SizedBox(width: 8),
                    Expanded(child: _HeroStat(value: '${selectedList.length}', title: 'на день')),
                    const SizedBox(width: 8),
                    Expanded(child: _HeroStat(value: canEdit ? 'Да' : 'Нет', title: 'редакт.')),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: _ModeButton(
                    text: 'Месяц',
                    active: mode == CmrCalendarMode.month,
                    onTap: () {
                      if (mode == CmrCalendarMode.month) return;
                      setState(() => mode = CmrCalendarMode.month);
                      _fetch();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ModeButton(
                    text: 'Неделя',
                    active: mode == CmrCalendarMode.week,
                    onTap: () {
                      if (mode == CmrCalendarMode.week) return;
                      setState(() => mode = CmrCalendarMode.week);
                      _fetch();
                    },
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: _SelectedDayHeader(
              title: _dateTitle(selectedDay),
              canEdit: canEdit,
              onAdd: () => _openCreate(selectedDay),
            ),
          ),
          Expanded(
            child: selectedList.isEmpty
                ? const _MiniEmpty(text: 'На выбранный день событий нет')
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    itemCount: selectedList.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, index) {
                      final event = selectedList[index];
                      return _CmrEventTile(
                        event: event,
                        canEdit: canEdit,
                        onDetails: () => _openDetails(event),
                        onEdit: () => _openEdit(event),
                        onDelete: () => _delete(event),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkPanel() {
    if (_workPanel == _CalendarWorkPanel.details && _selectedEventForPanel != null) {
      final event = _selectedEventForPanel!;
      return _InlineEventDetailsPanel(
        event: event,
        teamName: widget.teamName,
        canEdit: canEdit,
        onClose: _closeWorkPanel,
        onBackToCalendar: _closeWorkPanel,
        onEdit: () => _openEdit(event),
        onDelete: () => _delete(event),
      );
    }

    if (_workPanel == _CalendarWorkPanel.editor) {
      final editing = _editingEventForPanel;
      final day = _createDateForPanel ?? selectedDay;
      final base = editing?.startAt ?? DateTime(day.year, day.month, day.day, 18, 0);
      return _InlineEventEditorPanel(
        title: editing == null ? 'Добавить событие' : 'Редактировать событие',
        subtitle: editing == null
            ? 'Выбранная дата: ${_dateTitle(day)}'
            : 'Измените данные события и сохраните обновления',
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

    return const SizedBox.shrink();
  }

  Widget _buildCalendarArea(DateTime weekStart) {
    return Container(
      decoration: _C.cardDecoration,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: LayoutBuilder(
              builder: (context, c) {
                final compact = c.maxWidth < 620;
                final title = mode == CmrCalendarMode.month
                    ? _monthTitle(cursor)
                    : 'Неделя • ${_weekTitle(cursor)}';

                final titleBlock = Row(
                  children: [
                    const _CmrIconBox(icon: Icons.event_available_rounded),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _C.title.copyWith(fontSize: compact ? 18 : 22),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Выбранный день: ${_dateTitle(selectedDay)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _C.muted,
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );

                final actions = Row(
                  mainAxisSize: compact ? MainAxisSize.max : MainAxisSize.min,
                  children: compact
                      ? [
                          Expanded(
                            child: _TopActionButton(
                              icon: Icons.calendar_month_rounded,
                              text: 'Выбрать',
                              onTap: _pickMonth,
                              compact: true,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _TopActionButton(
                              icon: Icons.today_rounded,
                              text: 'Сегодня',
                              onTap: _today,
                              compact: true,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _SquareButton(icon: Icons.open_in_full_rounded, onTap: _openFullCalendar),
                          const SizedBox(width: 8),
                          _SquareButton(icon: Icons.chevron_left_rounded, onTap: _previousPeriod),
                          const SizedBox(width: 8),
                          _SquareButton(icon: Icons.chevron_right_rounded, onTap: _nextPeriod),
                        ]
                      : [
                          _TopActionButton(
                            icon: Icons.calendar_month_rounded,
                            text: 'Выбрать',
                            onTap: _pickMonth,
                          ),
                          const SizedBox(width: 8),
                          _TopActionButton(
                            icon: Icons.today_rounded,
                            text: 'Сегодня',
                            onTap: _today,
                          ),
                          const SizedBox(width: 8),
                          _TopActionButton(
                            icon: Icons.open_in_full_rounded,
                            text: 'На весь экран',
                            onTap: _openFullCalendar,
                          ),
                          const SizedBox(width: 8),
                          _SquareButton(icon: Icons.chevron_left_rounded, onTap: _previousPeriod),
                          const SizedBox(width: 8),
                          _SquareButton(icon: Icons.chevron_right_rounded, onTap: _nextPeriod),
                        ],
                );

                if (compact) {
                  return Column(
                    children: [
                      titleBlock,
                      const SizedBox(height: 12),
                      actions,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: titleBlock),
                    const SizedBox(width: 12),
                    actions,
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 1),
          Padding(
            padding: const EdgeInsets.all(14),
            child: _legend(),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: LayoutBuilder(
              builder: (context, c) {
                final isNarrow = MediaQuery.of(context).size.width < 700;
                final child = mode == CmrCalendarMode.month
                    ? CalendarMonthGrid(
                        month: cursor,
                        eventsByDay: eventsByDay,
                        selectedDay: selectedDay,
                        onDayTap: _selectCalendarDay,
                        onDayLongPress: (d) {
                          if (!canEdit) return;
                          _selectCalendarDay(d);
                          _openCreate(d);
                        },
                      )
                    : CalendarWeekView(
                        weekStartMonday: weekStart,
                        eventsByDay: eventsByDay,
                        selectedDay: selectedDay,
                        onDayTap: _selectCalendarDay,
                        onDayLongPress: (d) {
                          if (!canEdit) return;
                          _selectCalendarDay(d);
                          _openCreate(d);
                        },
                        onEventTap: (e) => _openDetails(e),
                        onEventLongPress: (e) {
                          if (!canEdit) return;
                          _openEdit(e);
                        },
                      );

                if (isNarrow) {
                  return SizedBox(
                    height: mode == CmrCalendarMode.month ? 430 : 520,
                    child: child,
                  );
                }

                return SizedBox(
                  height: (c.maxHeight.isFinite ? c.maxHeight : 620.0)
    .clamp(430.0, 720.0)
    .toDouble(),
                  child: child,
                );
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: _C.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 9, height: 9, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 7),
            Text(eventTypeLabel(t), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _C.text)),
          ],
        ),
      );
    }

    return Wrap(
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

  const _InlineEventEditorPanel({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.child,
    required this.onClose,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _C.cardDecoration.copyWith(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.025),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _InlinePanelHeader(
            title: title,
            subtitle: subtitle,
            icon: icon,
            accent: accent,
            onClose: onClose,
            leading: _SmallPanelButton(
              icon: Icons.calendar_month_rounded,
              text: 'Календарь',
              onTap: onClose,
            ),
          ),
          Expanded(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Navigator(
                  pages: [
                    MaterialPage<void>(
                      key: ValueKey('calendar-event-editor-$title-$subtitle'),
                      child: child,
                    ),
                  ],
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

/// EventEditorSheet из основного календаря сделан как bottom-sheet:
/// у него внутри есть серый фон, ручка перетаскивания и собственная шапка.
/// Когда мы вставляем его внутрь CMR-панели, эта верхняя часть выглядит как
/// «сползшее» окно. Адаптер аккуратно прячет bottom-sheet-обвязку и оставляет
/// саму форму с кнопками «Добавить», «Добавить ещё» и штатной логикой.
class _InlineEditorAdapter extends StatelessWidget {
  final Widget child;

  const _InlineEditorAdapter({required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final compact = c.maxWidth < 760;
        final cutTop = compact ? 72.0 : 84.0;

        return Container(
          color: Colors.white,
          child: ClipRect(
            child: Transform.translate(
              offset: Offset(0, -cutTop),
              child: SizedBox(
                width: double.infinity,
                height: c.maxHeight + cutTop,
                child: MediaQuery.removePadding(
                  context: context,
                  removeTop: true,
                  removeBottom: true,
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      scaffoldBackgroundColor: Colors.white,
                      canvasColor: Colors.white,
                      cardColor: Colors.white,
                    ),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        );
      },
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

  const _InlineEventDetailsPanel({
    required this.event,
    required this.teamName,
    required this.canEdit,
    required this.onClose,
    required this.onBackToCalendar,
    required this.onEdit,
    required this.onDelete,
  });

  String get _dateText => '${event.startAt.day.toString().padLeft(2, '0')}.${event.startAt.month.toString().padLeft(2, '0')}.${event.startAt.year}';

  String get _timeText {
    if (event.endAt == null) return hhmm(event.startAt);
    return '${hhmm(event.startAt)}–${hhmm(event.endAt!)}';
  }

  bool get _isTrainingLike => event.type == TeamEventType.training || event.type == TeamEventType.gym;

  @override
  Widget build(BuildContext context) {
    final typeColor = eventTypeColor(event.type);
    final notes = event.notes.trim();
    final location = event.location.trim();

    return Container(
      decoration: _C.cardDecoration,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _InlinePanelHeader(
            title: event.title.trim().isEmpty ? 'Событие календаря' : event.title,
            subtitle: '${eventTypeLabel(event.type)} • $_dateText • $_timeText',
            icon: Icons.event_note_rounded,
            accent: typeColor,
            onClose: onClose,
            leading: _SmallPanelButton(
              icon: Icons.calendar_month_rounded,
              text: 'Календарь',
              onTap: onBackToCalendar,
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) {
                final compact = c.maxWidth < 760;
                final info = Column(
                  children: [
                    _eventInfoGrid(typeColor, location),
                    const SizedBox(height: 12),
                    _notesBlock(typeColor, notes),
                  ],
                );
                final actions = _actionsBlock(context, typeColor);

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: compact
                      ? Column(
                          children: [
                            info,
                            const SizedBox(height: 12),
                            actions,
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 6, child: info),
                            const SizedBox(width: 14),
                            Expanded(flex: 4, child: actions),
                          ],
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _eventInfoGrid(Color typeColor, String location) {
    final items = [
      _DetailMetric(icon: Icons.schedule_rounded, title: 'Время', value: _timeText, accent: typeColor),
      _DetailMetric(icon: Icons.calendar_month_rounded, title: 'Дата', value: _dateText, accent: typeColor),
      _DetailMetric(icon: Icons.category_rounded, title: 'Тип', value: eventTypeLabel(event.type), accent: typeColor),
      _DetailMetric(icon: Icons.location_on_outlined, title: 'Место', value: location.isEmpty ? 'Не указано' : location, accent: typeColor),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        final twoCols = c.maxWidth >= 460;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items
              .map((item) => SizedBox(
                    width: twoCols ? (c.maxWidth - 8) / 2 : c.maxWidth,
                    child: item,
                  ))
              .toList(),
        );
      },
    );
  }

  Widget _notesBlock(Color typeColor, String notes) {
    return _SimplePanel(
      icon: Icons.notes_rounded,
      iconColor: typeColor,
      title: 'Описание',
      child: Text(
        notes.isEmpty ? 'Описание не добавлено.' : notes,
        style: const TextStyle(color: _C.muted, fontSize: 13, fontWeight: FontWeight.w700, height: 1.35),
      ),
    );
  }

  Widget _actionsBlock(BuildContext context, Color typeColor) {
    return _SimplePanel(
      icon: Icons.tune_rounded,
      iconColor: typeColor,
      title: 'Действия',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (canEdit) ...[
            OutlinedButton.icon(
              onPressed: () {
                Get.snackbar(
                  'Планы / конспекты',
                  'Подключим выбор планов и схем из рабочего раздела.',
                  snackPosition: SnackPosition.BOTTOM,
                );
              },
              icon: const Icon(Icons.folder_open_rounded, size: 18),
              label: const Text('Планы / конспекты'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _C.greenDark,
                side: const BorderSide(color: _C.accentBorder),
                padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 8),
            if (_isTrainingLike)
              ElevatedButton.icon(
                onPressed: () async {
                  final coachId = await PrefUtils.getUserId() ?? 0;
                  if (coachId <= 0) {
                    Get.snackbar('Оценка', 'Не найден userId', snackPosition: SnackPosition.BOTTOM);
                    return;
                  }
                  await showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => TrainingRatingSheet(
                      apiBase: _CmrCalendarPanelState.apiBase,
                      teamId: event.teamId,
                      eventId: event.id,
                      coachId: coachId,
                      title: event.title,
                    ),
                  );
                },
                icon: const Icon(Icons.star_rate_rounded),
                label: const Text('Оценка тренировки игроков'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.green,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              )
            else
              const _MutedHintCompact('Оценка доступна только для тренировок и ОФП.'),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: _SheetActionButton(
                  icon: Icons.close_rounded,
                  text: 'Закрыть',
                  onTap: onClose,
                  secondary: true,
                ),
              ),
              if (canEdit) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _SheetActionButton(
                    icon: Icons.edit_rounded,
                    text: 'Изменить',
                    onTap: onEdit,
                  ),
                ),
                const SizedBox(width: 8),
                _SheetIconButton(icon: Icons.delete_outline_rounded, onTap: onDelete),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _InlinePanelHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onClose;
  final Widget? leading;

  const _InlinePanelHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onClose,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _C.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withOpacity(.10),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: accent, size: 22),
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
                  style: const TextStyle(color: _C.text, fontSize: 17, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _C.muted, fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          if (leading != null) ...[
            const SizedBox(width: 8),
            leading!,
          ],
          const SizedBox(width: 4),
          IconButton(
            onPressed: onClose,
            tooltip: 'Закрыть',
            icon: const Icon(Icons.close_rounded, color: _C.muted),
          ),
        ],
      ),
    );
  }
}

class _SmallPanelButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  const _SmallPanelButton({required this.icon, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: _C.soft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _C.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _C.greenDark, size: 17),
            const SizedBox(width: 6),
            Text(text, style: const TextStyle(color: _C.text, fontSize: 12.5, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

class _C {
  static const Color green = Color(0xFF1F7A4D);
  static const Color greenDark = Color(0xFF176B3A);
  static const Color darkGreen = Color(0xFF10251C);
  static const Color card = Colors.white;
  static const Color soft = Color(0xFFF7FAF8);
  static const Color accentSoft = Color(0xFFF2F7F4);
  static const Color accentBorder = Color(0xFFD7E8DE);
  static const Color text = Color(0xFF111827);
  static const Color muted = Color(0xFF667085);
  static const Color border = Color(0xFFE5E7EB);
  static const Color red = Color(0xFFDC2626);

  static BoxDecoration get cardDecoration => BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.035), blurRadius: 22, offset: const Offset(0, 10))],
      );

  static const TextStyle title = TextStyle(color: text, fontSize: 18, fontWeight: FontWeight.w900, height: 1.15);
  static const TextStyle darkTitle = TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, height: 1.05);
}

class _CmrIconBox extends StatelessWidget {
  final IconData icon;
  final bool dark;
  const _CmrIconBox({required this.icon, this.dark = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: _C.soft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.border),
      ),
      child: Icon(icon, color: _C.greenDark, size: 26),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String value;
  final String title;
  const _HeroStat({required this.value, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
      decoration: BoxDecoration(color: const Color(0xFFF7FAF8), borderRadius: BorderRadius.circular(18)),
      child: Column(
        children: [
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _C.text, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _C.muted, fontSize: 10.5, fontWeight: FontWeight.w700)),
        ],
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
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: active ? _C.darkGreen : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: active ? _C.darkGreen : _C.border),
        ),
        child: Center(
          child: Text(text, style: TextStyle(color: active ? Colors.white : _C.text, fontSize: 13, fontWeight: FontWeight.w900)),
        ),
      ),
    );
  }
}

class _SelectedDayHeader extends StatelessWidget {
  final String title;
  final bool canEdit;
  final VoidCallback onAdd;
  const _SelectedDayHeader({required this.title, required this.canEdit, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          const Icon(Icons.event_note_rounded, color: _C.greenDark, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Выбранный день', style: TextStyle(color: _C.muted, fontSize: 11.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(title, style: const TextStyle(color: _C.text, fontSize: 15, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
          if (canEdit) ...[
            _CompactAddEventButton(onTap: onAdd),
          ],
        ],
      ),
    );
  }
}


class _CmrEventEditorHost extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  const _CmrEventEditorHost({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 720;

    return SafeArea(
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.fromLTRB(10, 10, 10, 10 + bottom),
        child: Align(
          alignment: Alignment.center,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isMobile ? size.width - 20 : 1120,
              maxHeight: size.height * .93,
            ),
            child: Material(
              color: Colors.white,
              elevation: 12,
              shadowColor: Colors.black.withOpacity(.12),
              borderRadius: BorderRadius.circular(22),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PlainModalHeader(
                    title: title,
                    subtitle: subtitle,
                    icon: icon,
                    onClose: () => Navigator.pop(context),
                  ),
                  Flexible(
                    child: Container(
                      width: double.infinity,
                      color: Colors.white,
                      child: child,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CmrEventDetailsSheet extends StatelessWidget {
  final TeamEvent event;
  final String teamName;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CmrEventDetailsSheet({
    required this.event,
    required this.teamName,
    required this.canEdit,
    required this.onEdit,
    required this.onDelete,
  });

  String get _dateText => '${event.startAt.day.toString().padLeft(2, '0')}.${event.startAt.month.toString().padLeft(2, '0')}.${event.startAt.year}';

  String get _timeText {
    if (event.endAt == null) return hhmm(event.startAt);
    return '${hhmm(event.startAt)}–${hhmm(event.endAt!)}';
  }

  bool get _isTrainingLike => event.type == TeamEventType.training || event.type == TeamEventType.gym;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 760;
    final typeColor = eventTypeColor(event.type);
    final notes = event.notes.trim();
    final location = event.location.trim();

    return SafeArea(
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.fromLTRB(10, 10, 10, 10 + bottom),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isMobile ? size.width - 20 : 1040,
              maxHeight: size.height * .90,
            ),
            child: Material(
              color: Colors.white,
              elevation: 12,
              shadowColor: Colors.black.withOpacity(.12),
              borderRadius: BorderRadius.circular(22),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PlainModalHeader(
                    title: event.title.trim().isEmpty ? 'Событие календаря' : event.title,
                    subtitle: '${eventTypeLabel(event.type)} • $_dateText • $_timeText',
                    icon: Icons.event_note_rounded,
                    accent: typeColor,
                    onClose: () => Navigator.pop(context),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                      child: isMobile
                          ? Column(
                              children: [
                                _eventInfoGrid(typeColor, location),
                                const SizedBox(height: 12),
                                _notesBlock(typeColor, notes),
                                const SizedBox(height: 12),
                                _actionsBlock(context, typeColor),
                              ],
                            )
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 6,
                                  child: Column(
                                    children: [
                                      _eventInfoGrid(typeColor, location),
                                      const SizedBox(height: 12),
                                      _notesBlock(typeColor, notes),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  flex: 4,
                                  child: _actionsBlock(context, typeColor),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _eventInfoGrid(Color typeColor, String location) {
    final items = [
      _DetailMetric(icon: Icons.schedule_rounded, title: 'Время', value: _timeText, accent: typeColor),
      _DetailMetric(icon: Icons.calendar_month_rounded, title: 'Дата', value: _dateText, accent: typeColor),
      _DetailMetric(icon: Icons.category_rounded, title: 'Тип', value: eventTypeLabel(event.type), accent: typeColor),
      _DetailMetric(icon: Icons.location_on_outlined, title: 'Место', value: location.isEmpty ? 'Не указано' : location, accent: typeColor),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        final twoCols = c.maxWidth >= 460;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items
              .map((item) => SizedBox(
                    width: twoCols ? (c.maxWidth - 8) / 2 : c.maxWidth,
                    child: item,
                  ))
              .toList(),
        );
      },
    );
  }

  Widget _notesBlock(Color typeColor, String notes) {
    return _SimplePanel(
      icon: Icons.notes_rounded,
      iconColor: typeColor,
      title: 'Описание',
      child: Text(
        notes.isEmpty ? 'Описание не добавлено.' : notes,
        style: const TextStyle(color: _C.muted, fontSize: 13, fontWeight: FontWeight.w700, height: 1.35),
      ),
    );
  }

  Widget _actionsBlock(BuildContext context, Color typeColor) {
    return _SimplePanel(
      icon: Icons.tune_rounded,
      iconColor: typeColor,
      title: 'Действия',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (canEdit) ...[
            OutlinedButton.icon(
              onPressed: () {
                Get.snackbar(
                  'Планы / конспекты',
                  'Подключим выбор планов и схем из рабочего раздела.',
                  snackPosition: SnackPosition.BOTTOM,
                );
              },
              icon: const Icon(Icons.folder_open_rounded, size: 18),
              label: const Text('Планы / конспекты'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _C.greenDark,
                side: const BorderSide(color: _C.accentBorder),
                padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 8),
            if (_isTrainingLike)
              ElevatedButton.icon(
                onPressed: () async {
                  final coachId = await PrefUtils.getUserId() ?? 0;
                  if (coachId <= 0) {
                    Get.snackbar('Оценка', 'Не найден userId', snackPosition: SnackPosition.BOTTOM);
                    return;
                  }
                  Navigator.pop(context);
                  await showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => TrainingRatingSheet(
                      apiBase: _CmrCalendarPanelState.apiBase,
                      teamId: event.teamId,
                      eventId: event.id,
                      coachId: coachId,
                      title: event.title,
                    ),
                  );
                },
                icon: const Icon(Icons.star_rate_rounded),
                label: const Text('Оценка тренировки игроков'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.green,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              )
            else
              const _MutedHintCompact('Оценка доступна только для тренировок и ОФП.'),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: _SheetActionButton(
                  icon: Icons.close_rounded,
                  text: 'Закрыть',
                  onTap: () => Navigator.pop(context),
                  secondary: true,
                ),
              ),
              if (canEdit) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: _SheetActionButton(
                    icon: Icons.edit_rounded,
                    text: 'Изменить',
                    onTap: onEdit,
                  ),
                ),
                const SizedBox(width: 8),
                _SheetIconButton(icon: Icons.delete_outline_rounded, onTap: onDelete),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _SoftInfoBlock extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String text;
  final Widget? action;

  const _SoftInfoBlock({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.text,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: _C.border),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _C.text, fontSize: 14.5, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            text,
            style: const TextStyle(color: _C.muted, fontSize: 12.5, fontWeight: FontWeight.w700, height: 1.35),
          ),
          if (action != null) ...[
            const SizedBox(height: 10),
            SizedBox(width: double.infinity, child: action!),
          ],
        ],
      ),
    );
  }
}

class _MutedHintCompact extends StatelessWidget {
  final String text;
  const _MutedHintCompact(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border),
      ),
      child: Text(
        text,
        style: const TextStyle(color: _C.muted, fontSize: 12.5, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _PlainModalHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color? accent;
  final VoidCallback onClose;

  const _PlainModalHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onClose,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final c = accent ?? _C.green;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _C.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: c.withOpacity(.10),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: c, size: 22),
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
                  style: const TextStyle(color: _C.text, fontSize: 17, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _C.muted, fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            tooltip: 'Закрыть',
            icon: const Icon(Icons.close_rounded, color: _C.muted),
          ),
        ],
      ),
    );
  }
}

class _SimplePanel extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget child;

  const _SimplePanel({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 19),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _C.text, fontSize: 14, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _CmrModalHero extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String teamName;
  final String dateText;
  final Color? accent;
  final VoidCallback onClose;
  final bool compact;

  const _CmrModalHero({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.teamName,
    required this.dateText,
    required this.onClose,
    this.accent,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final a = accent ?? _C.green;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(18, compact ? 14 : 16, 14, compact ? 14 : 16),
      decoration: BoxDecoration(
        color: _C.darkGreen,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [const Color(0xFF153529), Color.lerp(const Color(0xFF153529), a, .42) ?? _C.green],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -22,
            top: -28,
            child: Container(
              width: 118,
              height: 118,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(.08)),
            ),
          ),
          Positioned(
            right: 60,
            bottom: -42,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(.08), width: 18)),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.14),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(.16)),
                ),
                child: Icon(icon, color: Colors.white, size: 27),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22, height: 1.08),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white.withOpacity(.80), fontWeight: FontWeight.w700, fontSize: 12.5, height: 1.25),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _HeroPill(icon: Icons.groups_rounded, text: teamName.trim().isEmpty ? 'Команда' : teamName),
                        _HeroPill(icon: Icons.calendar_today_rounded, text: dateText),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: onClose,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(.14)),
                  ),
                  child: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _HeroPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(.13)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w900),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.accentSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.accentBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: _C.accentBorder)),
            child: Icon(icon, color: accent, size: 21),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _C.muted, fontSize: 11.5, fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(value, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _C.text, fontSize: 14.5, fontWeight: FontWeight.w900, height: 1.15)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetActionButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  final bool secondary;

  const _SheetActionButton({required this.icon, required this.text, required this.onTap, this.secondary = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 19),
        label: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: secondary ? _C.soft : _C.green,
          foregroundColor: secondary ? _C.text : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}

class _SheetIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _SheetIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(color: const Color(0xFFFFF1F2), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFFECACA))),
        child: const Icon(Icons.delete_outline_rounded, color: _C.red),
      ),
    );
  }
}

class _CmrEventTile extends StatelessWidget {
  final TeamEvent event;
  final bool canEdit;
  final VoidCallback onDetails;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CmrEventTile({
    required this.event,
    required this.canEdit,
    required this.onDetails,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final c = eventTypeColor(event.type);
    final when = event.endAt == null ? hhmm(event.startAt) : '${hhmm(event.startAt)}–${hhmm(event.endAt!)}';

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onDetails,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _C.accentSoft,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _C.accentBorder),
          boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 14, offset: Offset(0, 6))],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 7, height: 58, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(99))),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _C.text, fontWeight: FontWeight.w900, fontSize: 14.5, height: 1.15)),
                  const SizedBox(height: 5),
                  Text('${eventTypeLabel(event.type)} • $when', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: _C.muted, fontWeight: FontWeight.w700)),
                  if (event.location.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('📍 ${event.location}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: _C.text, fontWeight: FontWeight.w600)),
                  ],
                ],
              ),
            ),
            if (canEdit)
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'details') onDetails();
                  if (value == 'edit') onEdit();
                  if (value == 'delete') onDelete();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'details', child: Text('Подробнее')),
                  PopupMenuItem(value: 'edit', child: Text('Редактировать')),
                  PopupMenuItem(value: 'delete', child: Text('Удалить')),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _CompactAddEventButton extends StatelessWidget {
  final VoidCallback onTap;
  const _CompactAddEventButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: _C.green,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: _C.green.withOpacity(.18), blurRadius: 12, offset: const Offset(0, 6))],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, color: Colors.white, size: 19),
            SizedBox(width: 6),
            Text('Добавить', style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w900)),
          ],
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
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: _C.green, borderRadius: BorderRadius.circular(14)),
        child: const Icon(Icons.add_rounded, color: Colors.white),
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
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: const Color(0xFFF7FAF8), borderRadius: BorderRadius.circular(16)),
        child: Icon(icon, color: _C.greenDark),
      ),
    );
  }
}

class _SquareButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _SquareButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: _C.soft, borderRadius: BorderRadius.circular(16)),
        child: Icon(icon, color: _C.greenDark),
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
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 13, vertical: 12),
        decoration: BoxDecoration(color: _C.soft, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Icon(icon, color: _C.greenDark, size: 18),
            const SizedBox(width: 7),
            Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _C.text, fontSize: 12.5, fontWeight: FontWeight.w900))),
          ],
        ),
      ),
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
              Icon(icon, color: _C.greenDark, size: 54),
              const SizedBox(height: 14),
              Text(title, textAlign: TextAlign.center, style: _C.title.copyWith(fontSize: 22)),
              const SizedBox(height: 8),
              Text(text, textAlign: TextAlign.center, style: const TextStyle(color: _C.muted, height: 1.45, fontWeight: FontWeight.w600)),
              if (actionText != null && onAction != null) ...[
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: onAction,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(actionText!),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _C.green,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
