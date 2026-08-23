// lib/presentation/club_calendar_screen/club_calendar_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';

import 'package:sportoteka/presentation/team_calendar_screen/team_calendar_models.dart';
import 'package:sportoteka/presentation/team_calendar_screen/team_calendar_api.dart';
import 'package:sportoteka/presentation/team_calendar_screen/event_editor_sheet.dart';
import 'package:sportoteka/presentation/team_calendar_screen/calendar_month_grid.dart';
import 'package:sportoteka/presentation/team_calendar_screen/calendar_week_view.dart';

enum CalendarMode { month, week }
enum ClubViewMode { calendar, table }
enum FilterPreset { all, today, week, month }

class ClubCalendarScreen extends StatefulWidget {
  final int clubId;
  final String clubName;
  final List<dynamic> teams;

  const ClubCalendarScreen({
    super.key,
    required this.clubId,
    required this.clubName,
    required this.teams,
  });

  @override
  State<ClubCalendarScreen> createState() => _ClubCalendarScreenState();
}

class _ClubCalendarScreenState extends State<ClubCalendarScreen> {
  static const String apiBase = "https://sportotekaapp.ru/api";
  late final TeamCalendarApi api;

  bool loading = true;
  bool statsExpanded = false;

  CalendarMode mode = CalendarMode.month;
  ClubViewMode viewMode = ClubViewMode.calendar;
  FilterPreset filterPreset = FilterPreset.all;

  DateTime cursor = DateTime.now();
  DateTime selectedDay = DateTime.now();

  List<TeamEvent> events = [];
  Map<DateTime, List<TeamEvent>> eventsByDay = {};
  Map<int, String> teamNamesById = {};
  Map<int, String> teamLogosById = {};

  // filters
  Set<int> selectedTeamIds = {};
  Set<TeamEventType> selectedTypes = {};
  String searchQuery = "";
  DateTime? filterDateFrom;
  DateTime? filterDateTo;

  Color get primary => Theme.of(context).colorScheme.primary;

  @override
  void initState() {
    super.initState();
    api = TeamCalendarApi(apiBase: apiBase);
    _initializeTeams();
    _fetch();
  }

  void _initializeTeams() {
    teamNamesById = {};
    teamLogosById = {};

    for (final raw in widget.teams) {
      if (raw is! Map) continue;
      final m = raw;

      final id = _asInt(m["id"] ?? m["team_id"] ?? m["teamId"]);
      final name = _asStr(m["name"] ?? m["team_name"] ?? m["teamName"]).trim();
      final logo = _asStr(m["logo"] ?? m["team_logo"] ?? m["teamLogo"] ?? m["logo_url"]).trim();

      if (id > 0) {
        teamNamesById[id] = name.isNotEmpty ? name : "Команда #$id";
        if (logo.isNotEmpty) teamLogosById[id] = logo;
      }
    }
  }

  // ================ STATS ================
  Map<String, dynamic> get statistics {
    final filtered = filteredEvents;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = startOfWeekMonday(now);

    return {
      'total': filtered.length,
      'today': filtered.where((e) => dateOnly(e.startAt) == today).length,
      'thisWeek': filtered.where((e) {
        final day = dateOnly(e.startAt);
        return day.isAfter(weekStart.subtract(const Duration(days: 1))) &&
            day.isBefore(weekStart.add(const Duration(days: 7)));
      }).length,
      'byType': Map.fromEntries(TeamEventType.values.map((type) => MapEntry(
            type,
            filtered.where((e) => e.type == type).length,
          ))),
      'byTeam': Map.fromEntries(teamNamesById.entries.map((entry) => MapEntry(
            entry.value,
            filtered.where((e) => e.teamId == entry.key).length,
          ))),
    };
  }

  // ================ helpers ================
  int _asInt(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;
  String _asStr(dynamic v) => v?.toString() ?? '';

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

  String _weekdayShort(DateTime d) {
    const w = ["Вс", "Пн", "Вт", "Ср", "Чт", "Пт", "Сб"];
    return w[d.weekday % 7];
  }

  String _formatDate(DateTime d) =>
      "${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}";

  String _pluralize(int n, String one, String two, String five) {
    n %= 100;
    if (n >= 5 && n <= 20) return five;
    n %= 10;
    if (n == 1) return one;
    if (n >= 2 && n <= 4) return two;
    return five;
  }

  String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r"\s+")).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return "T";
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  // ================ filtering ================
  List<TeamEvent> get filteredEvents {
    final q = searchQuery.trim().toLowerCase();

    return events.where((e) {
      final teamOk = selectedTeamIds.isEmpty || selectedTeamIds.contains(e.teamId);
      final typeOk = selectedTypes.isEmpty || selectedTypes.contains(e.type);
      final dateOk = _isEventInDateRange(e);

      final teamName = (teamNamesById[e.teamId] ?? "Команда #${e.teamId}").toLowerCase();
      final searchOk = q.isEmpty ||
          e.title.toLowerCase().contains(q) ||
          e.location.toLowerCase().contains(q) ||
          e.notes.toLowerCase().contains(q) ||
          teamName.contains(q);

      return teamOk && typeOk && dateOk && searchOk;
    }).toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
  }

  // base for badges (ignore selected teams but apply other filters)
  List<TeamEvent> get _eventsForTeamBadges {
    final q = searchQuery.trim().toLowerCase();

    return events.where((e) {
      final typeOk = selectedTypes.isEmpty || selectedTypes.contains(e.type);
      final dateOk = _isEventInDateRange(e);

      final teamName = (teamNamesById[e.teamId] ?? "Команда #${e.teamId}").toLowerCase();
      final searchOk = q.isEmpty ||
          e.title.toLowerCase().contains(q) ||
          e.location.toLowerCase().contains(q) ||
          e.notes.toLowerCase().contains(q) ||
          teamName.contains(q);

      return typeOk && dateOk && searchOk;
    }).toList();
  }

  bool _isEventInDateRange(TeamEvent event) {
    if (filterDateFrom == null && filterDateTo == null) return true;

    final eventDate = dateOnly(event.startAt);

    if (filterDateFrom != null && eventDate.isBefore(dateOnly(filterDateFrom!))) return false;
    if (filterDateTo != null && eventDate.isAfter(dateOnly(filterDateTo!))) return false;

    return true;
  }

  void _applyFilterPreset(FilterPreset preset) {
    setState(() {
      filterPreset = preset;
      final now = DateTime.now();

      switch (preset) {
        case FilterPreset.today:
          filterDateFrom = DateTime(now.year, now.month, now.day);
          filterDateTo = DateTime(now.year, now.month, now.day);
          break;
        case FilterPreset.week:
          filterDateFrom = startOfWeekMonday(now);
          filterDateTo = filterDateFrom!.add(const Duration(days: 6));
          break;
        case FilterPreset.month:
          filterDateFrom = DateTime(now.year, now.month, 1);
          filterDateTo = DateTime(now.year, now.month + 1, 0);
          break;
        case FilterPreset.all:
          filterDateFrom = null;
          filterDateTo = null;
          break;
      }
      _rebuildByDay();
    });
  }

  void _rebuildByDay() {
    eventsByDay = {};
    for (final e in filteredEvents) {
      final k = dateOnly(e.startAt);
      (eventsByDay[k] ??= []).add(e);
    }
  }

  // ================ load ================
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
      final teamIds = teamNamesById.keys.toList()..sort();

      if (teamIds.isEmpty) {
        events = [];
        _rebuildByDay();
        return;
      }

      final futures = teamIds.map((id) => api.fetch(teamId: id, from: from, to: to)).toList();
      final lists = await Future.wait(futures);

      final merged = <TeamEvent>[];
      for (final l in lists) {
        merged.addAll(l);
      }
      merged.sort((a, b) => a.startAt.compareTo(b.startAt));

      events = merged;
      _rebuildByDay();
    } catch (e) {
      Get.snackbar(
        "Ошибка",
        "Не удалось загрузить события: ${e.toString()}",
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  // ================ CRUD ================
  int? _teamIdForCreate() {
    if (selectedTeamIds.isNotEmpty) return selectedTeamIds.first;
    final keys = teamNamesById.keys.toList()..sort();
    if (keys.isEmpty) return null;
    return keys.first;
  }

  Future<void> _openCreate(DateTime day) async {
    final createdBy = await PrefUtils.getUserId() ?? 0;
    final teamId = _teamIdForCreate();

    if (teamId == null) {
      Get.snackbar(
        "Нет команд",
        "В клубе нет команд для добавления события",
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final base = DateTime(day.year, day.month, day.day, 18, 0);
    final ev = await showModalBottomSheet<TeamEvent?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EventEditorSheet(
        primary: primary,
        teamId: teamId,
        clubId: widget.clubId,
        createdBy: createdBy,
        initialDateTime: base,
      ),
    );

    if (ev == null) return;

    try {
      await api.add(event: ev, createdBy: createdBy);
      await _fetch();
      Get.snackbar("Успешно", "Событие добавлено", snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      Get.snackbar(
        "Ошибка",
        "Не удалось добавить событие: ${e.toString()}",
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> _openEdit(TeamEvent current) async {
    final ev = await showModalBottomSheet<TeamEvent?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EventEditorSheet(
        primary: primary,
        teamId: current.teamId,
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
      Get.snackbar("Успешно", "Событие обновлено", snackPosition: SnackPosition.BOTTOM);
    } catch (e) {
      Get.snackbar(
        "Ошибка",
        "Не удалось обновить событие: ${e.toString()}",
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> _delete(TeamEvent e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Удалить событие?"),
        content: Text("Событие «${e.title}» будет удалено без возможности восстановления."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Отмена"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Удалить"),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await api.remove(eventId: e.id, teamId: e.teamId);
      await _fetch();
      Get.snackbar("Успешно", "Событие удалено", snackPosition: SnackPosition.BOTTOM);
    } catch (err) {
      Get.snackbar(
        "Ошибка",
        "Не удалось удалить событие: ${err.toString()}",
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  // ================ UI ================
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFFF3F5F8),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      titleSpacing: 12,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.clubName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          const Text(
            "Календарь клуба",
            style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
        ],
      ),
      actions: [
        IconButton(onPressed: _fetch, icon: const Icon(Icons.refresh), tooltip: "Обновить"),
        IconButton(
          onPressed: () => setState(() => statsExpanded = !statsExpanded),
          icon: Icon(statsExpanded ? Icons.insights : Icons.bar_chart),
          tooltip: "Статистика",
        ),
      ],
    );
  }

  Widget _cardShell({required Widget child, EdgeInsets? margin}) {
    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildStatsPanel() {
    if (!statsExpanded) return const SizedBox.shrink();
    final stats = statistics;

    return _cardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("📊 Сводка", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _StatCard(
                  title: "Всего",
                  value: "${stats['total']}",
                  icon: Icons.event_note,
                  color: primary,
                ),
                const SizedBox(width: 10),
                _StatCard(
                  title: "Сегодня",
                  value: "${stats['today']}",
                  icon: Icons.today,
                  color: Colors.green,
                ),
                const SizedBox(width: 10),
                _StatCard(
                  title: "Неделя",
                  value: "${stats['thisWeek']}",
                  icon: Icons.view_week,
                  color: Colors.blue,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (stats['byType'] is Map) ...[
            const Text("По типам:", style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: (stats['byType'] as Map).entries.map((entry) {
                final type = entry.key as TeamEventType;
                final count = entry.value as int;
                final c = eventTypeColor(type);
                return _Pill(
                  text: "${eventTypeLabel(type)} • $count",
                  color: c,
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNavigationBar() {
    return _cardShell(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
            tooltip: "Предыдущий",
          ),
          Expanded(
            child: Text(
              mode == CalendarMode.month ? _monthTitle(cursor) : "Неделя • ${_weekTitle(cursor)}",
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
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
            tooltip: "Следующий",
          ),
        ],
      ),
    );
  }

  Widget _buildModeSwitcher() {
    return _cardShell(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _buildModePill("Месяц", mode == CalendarMode.month, () {
                    if (mode == CalendarMode.month) return;
                    setState(() => mode = CalendarMode.month);
                    _fetch();
                  }),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildModePill("Неделя", mode == CalendarMode.week, () {
                    if (mode == CalendarMode.week) return;
                    setState(() => mode = CalendarMode.week);
                    _fetch();
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _buildModePill("Календарь", viewMode == ClubViewMode.calendar, () {
                    setState(() => viewMode = ClubViewMode.calendar);
                  }),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildModePill("Таблица", viewMode == ClubViewMode.table, () {
                    setState(() => viewMode = ClubViewMode.table);
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModePill(String text, bool active, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? primary.withOpacity(0.12) : const Color(0xFFF3F5F8),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? primary : const Color(0xFFE5E7EB)),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 13,
              color: active ? primary : const Color(0xFF111827),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickFilters() {
    final presets = FilterPreset.values;

    return _cardShell(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: presets.map((preset) {
          final isSelected = filterPreset == preset;
          return FilterChip(
            label: Text(_getPresetLabel(preset)),
            selected: isSelected,
            onSelected: (_) => _applyFilterPreset(preset),
            backgroundColor: const Color(0xFFF3F5F8),
            selectedColor: primary.withOpacity(0.16),
            checkmarkColor: primary,
            labelStyle: TextStyle(
              color: isSelected ? primary : const Color(0xFF374151),
              fontWeight: FontWeight.w700,
            ),
            side: BorderSide(color: isSelected ? primary : const Color(0xFFE5E7EB)),
          );
        }).toList(),
      ),
    );
  }

  String _getPresetLabel(FilterPreset preset) {
    switch (preset) {
      case FilterPreset.all:
        return "Все";
      case FilterPreset.today:
        return "Сегодня";
      case FilterPreset.week:
        return "Эта неделя";
      case FilterPreset.month:
        return "Этот месяц";
    }
  }

  Widget _buildFilters() {
    return _cardShell(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: "Поиск по событиям, местам, командам...",
              filled: true,
              fillColor: const Color(0xFFF3F5F8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (v) {
              searchQuery = v;
              setState(() => _rebuildByDay());
            },
          ),
          const SizedBox(height: 14),

          _buildSectionHeader(
            title: "Команды",
            subtitle: selectedTeamIds.isEmpty ? "Все команды" : "Выбрано: ${selectedTeamIds.length}",
          ),
          const SizedBox(height: 10),
          _buildTeamsChips(), // ✅ В ОДНУ СТРОКУ (горизонтально)
          const SizedBox(height: 16),

          _buildSectionHeader(
            title: "Типы событий",
            subtitle: selectedTypes.isEmpty ? "Все типы" : "Выбрано: ${selectedTypes.length}",
          ),
          const SizedBox(height: 10),
          _buildTypesFilter(),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({required String title, required String subtitle}) {
    return Row(
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        const Spacer(),
        Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
      ],
    );
  }

  // ✅ Новый выбор команд: горизонтальные "пилюли"
  Widget _buildTeamsChips() {
    final teamIds = teamNamesById.keys.toList()..sort();
    final base = _eventsForTeamBadges;

    int countForTeam(int id) => base.where((e) => e.teamId == id).length;
    final totalCount = base.length;

    final items = <_TeamGridItem>[
      _TeamGridItem(
        id: 0,
        title: "Все команды",
        subtitle: "Показать всё",
        badge: totalCount,
        logoUrl: null,
        selected: selectedTeamIds.isEmpty,
      ),
      ...teamIds.map((id) {
        final name = teamNamesById[id] ?? "Команда #$id";
        final logo = teamLogosById[id];
        return _TeamGridItem(
          id: id,
          title: name,
          subtitle: "События",
          badge: countForTeam(id),
          logoUrl: (logo != null && logo.isNotEmpty) ? logo : null,
          selected: selectedTeamIds.contains(id),
        );
      }),
    ];

    return SizedBox(
      height: 58,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, index) {
          final it = items[index];

          final leading = (it.logoUrl != null)
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    it.logoUrl!,
                    width: 26,
                    height: 26,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _InitialAvatar(text: _initials(it.title)),
                  ),
                )
              : _InitialAvatar(text: _initials(it.title));

          return _TeamChipCard(
            title: it.title,
            badge: it.badge,
            selected: it.selected,
            primary: primary,
            leading: leading,
            onTap: () {
              setState(() {
                if (it.id == 0) {
                  selectedTeamIds.clear();
                } else {
                  if (selectedTeamIds.contains(it.id)) {
                    selectedTeamIds.remove(it.id);
                  } else {
                    selectedTeamIds.add(it.id);
                  }
                }
                _rebuildByDay();
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildTypesFilter() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilterChip(
          label: const Text("Все типы"),
          selected: selectedTypes.isEmpty,
          onSelected: (_) {
            setState(() {
              selectedTypes.clear();
              _rebuildByDay();
            });
          },
          backgroundColor: const Color(0xFFF3F5F8),
          selectedColor: primary.withOpacity(0.16),
          checkmarkColor: primary,
          labelStyle: TextStyle(
            fontWeight: FontWeight.w800,
            color: selectedTypes.isEmpty ? primary : const Color(0xFF374151),
          ),
          side: BorderSide(
            color: selectedTypes.isEmpty ? primary : const Color(0xFFE5E7EB),
          ),
        ),
        ...TeamEventType.values.map((type) {
          final bool selected = selectedTypes.contains(type);
          final Color color = eventTypeColor(type);

          return FilterChip(
            label: Text(eventTypeLabel(type)),
            selected: selected,
            onSelected: (v) {
              setState(() {
                if (v) {
                  selectedTypes.add(type);
                } else {
                  selectedTypes.remove(type);
                }
                _rebuildByDay();
              });
            },
            backgroundColor: const Color(0xFFF3F5F8),
            selectedColor: color.withOpacity(0.16),
            checkmarkColor: color,
            labelStyle: TextStyle(
              fontWeight: FontWeight.w800,
              color: selected ? color : const Color(0xFF374151),
            ),
            side: BorderSide(
              color: selected ? color : const Color(0xFFE5E7EB),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildLegend() {
    return _cardShell(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Легенда событий", style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: TeamEventType.values.map((type) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: eventTypeColor(type),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(eventTypeLabel(type), style: const TextStyle(fontSize: 12)),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ================ Table view ================
  Widget _buildTableView() {
    final list = filteredEvents;

    if (list.isEmpty) {
      return _cardShell(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text(
              "Событий не найдено",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              "Попробуйте изменить фильтры или добавьте новое событие",
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
          ],
        ),
      );
    }

    final map = <DateTime, List<TeamEvent>>{};
    for (final e in list) {
      final k = dateOnly(e.startAt);
      (map[k] ??= []).add(e);
    }

    final days = map.keys.toList()..sort((a, b) => a.compareTo(b));
    for (final d in days) {
      map[d]!.sort((a, b) => a.startAt.compareTo(b.startAt));
    }

    return Column(
      children: days.map((day) {
        final dayList = map[day]!;
        return _cardShell(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: primary.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: primary.withOpacity(0.18)),
                    ),
                    child: Text(
                      "${_weekdayShort(day)} • ${_formatDate(day)}",
                      style: TextStyle(fontWeight: FontWeight.w900, color: primary),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    "${dayList.length} ${_pluralize(dayList.length, 'событие', 'события', 'событий')}",
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ...List.generate(dayList.length, (i) {
                final e = dayList[i];
                final teamName = teamNamesById[e.teamId] ?? "Команда #${e.teamId}";
                return Padding(
                  padding: EdgeInsets.only(bottom: i == dayList.length - 1 ? 0 : 10),
                  child: _ManagerEventRow(
                    event: e,
                    teamName: teamName,
                    onTap: () => _openEdit(e),
                    onLongPress: () => _delete(e),
                  ),
                );
              }),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ================ build ================
  @override
  Widget build(BuildContext context) {
    final selectedList = (eventsByDay[dateOnly(selectedDay)] ?? const <TeamEvent>[])
        .toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));

    return Scaffold(
      backgroundColor: const Color(0xFFF3F5F8),
      appBar: _buildAppBar(),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildStatsPanel(),
                _buildNavigationBar(),
                _buildModeSwitcher(),
                _buildQuickFilters(),
                _buildFilters(),
                _buildLegend(),
                const SizedBox(height: 6),

                if (viewMode == ClubViewMode.table) ...[
                  _buildTableView(),
                  const SizedBox(height: 12),
                ] else if (mode == CalendarMode.month) ...[
                  const SizedBox(height: 6),
                  CalendarMonthGrid(
                    month: cursor,
                    eventsByDay: eventsByDay,
                    selectedDay: selectedDay,
                    onDayTap: (d) => setState(() => selectedDay = d),
                    onDayLongPress: (d) => _showDayActions(d),
                  ),
                  const SizedBox(height: 12),
                  _buildSelectedDayAgenda(selectedDay, selectedList),
                  const SizedBox(height: 12),
                ] else ...[
                  const SizedBox(height: 6),
                  CalendarWeekView(
                    weekStartMonday: startOfWeekMonday(cursor),
                    eventsByDay: eventsByDay,
                    selectedDay: selectedDay,
                    onDayTap: (d) => setState(() => selectedDay = d),
                    onDayLongPress: (d) => _showDayActions(d),
                    onEventTap: _openEdit,
                    onEventLongPress: _delete,
                  ),
                  const SizedBox(height: 12),
                  _buildSelectedDayAgenda(selectedDay, selectedList),
                  const SizedBox(height: 12),
                ],
              ],
            ),
    );
  }

  void _showDayActions(DateTime day) {
    setState(() => selectedDay = day);
    final list = (eventsByDay[dateOnly(day)] ?? const <TeamEvent>[])
        .toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _DayEventsBottomSheet(
        day: day,
        events: list,
        teamNamesById: teamNamesById,
        teamLogosById: teamLogosById,
        onAdd: () {
          Navigator.pop(context);
          _openCreate(day);
        },
        onEdit: _openEdit,
        onDelete: _delete,
      ),
    );
  }

  Widget _buildSelectedDayAgenda(DateTime day, List<TeamEvent> items) {
    return _cardShell(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "События на ${_formatDate(day)}",
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
              if (items.isNotEmpty)
                Text(
                  "${items.length} ${_pluralize(items.length, 'событие', 'события', 'событий')}",
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            _buildEmptyState(
              "На этот день событий нет",
              Icons.event_available,
              "Добавить событие",
              () => _openCreate(day),
            )
          else ...[
            ...items.take(3).map((e) => _EventAgendaTile(
                  event: e,
                  teamName: teamNamesById[e.teamId] ?? "Команда #${e.teamId}",
                  teamLogoUrl: teamLogosById[e.teamId],
                  onEdit: () => _openEdit(e),
                  onDelete: () => _delete(e),
                )),
            if (items.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Center(
                  child: TextButton(
                    onPressed: () => _showAllEvents(day, items),
                    child: Text("Показать все (${items.length})"),
                  ),
                ),
              ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _openCreate(day),
              icon: const Icon(Icons.add),
              label: const Text("Добавить событие"),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
    String text,
    IconData icon,
    String buttonText,
    VoidCallback onPressed,
  ) {
    return Column(
      children: [
        Icon(icon, size: 48, color: Colors.grey[300]),
        const SizedBox(height: 12),
        Text(text, style: const TextStyle(color: Color(0xFF6B7280))),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.add),
            label: Text(buttonText),
            style: ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }

  void _showAllEvents(DateTime day, List<TeamEvent> list) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AllEventsBottomSheet(
        day: day,
        events: list,
        teamNamesById: teamNamesById,
        teamLogosById: teamLogosById,
        onEdit: _openEdit,
        onDelete: _delete,
      ),
    );
  }
}

// =======================
// UI components
// =======================

class _InitialAvatar extends StatelessWidget {
  final String text;
  const _InitialAvatar({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F5F8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
      ),
    );
  }
}

class _TeamChipCard extends StatelessWidget {
  final String title;
  final int badge;
  final bool selected;
  final Color primary;
  final Widget leading;
  final VoidCallback onTap;

  const _TeamChipCard({
    required this.title,
    required this.badge,
    required this.selected,
    required this.primary,
    required this.leading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? primary.withOpacity(0.12) : Colors.white;
    final border = selected ? primary : const Color(0xFFE5E7EB);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minWidth: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              leading,
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.fade, // 👌 выглядит чище, чем ellipsis
                  softWrap: false,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: selected ? primary : const Color(0xFFF3F5F8),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  "$badge",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                    color: selected ? Colors.white : const Color(0xFF111827),
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

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(title, style: const TextStyle(fontSize: 12, color: Color(0xFF374151))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  final Color color;
  const _Pill({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.20)),
      ),
      child: Text(
        text,
        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: color),
      ),
    );
  }
}

// Compact event row for table
class _ManagerEventRow extends StatelessWidget {
  final TeamEvent event;
  final String teamName;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ManagerEventRow({
    required this.event,
    required this.teamName,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final color = eventTypeColor(event.type);
    final time = event.endAt == null
        ? hhmm(event.startAt)
        : "${hhmm(event.startAt)}–${hhmm(event.endAt!)}";

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 6,
              height: 46,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 70,
              child: Text(
                time,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: color.withOpacity(0.20)),
                        ),
                        child: Text(
                          eventTypeLabel(event.type),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: color,
                          ),
                        ),
                      ),
                      Text(
                        teamName,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF374151),
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                  if (event.location.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            event.location,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right, color: Color(0xFFD1D5DB)),
          ],
        ),
      ),
    );
  }
}

class _EventAgendaTile extends StatelessWidget {
  final TeamEvent event;
  final String teamName;
  final String? teamLogoUrl;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _EventAgendaTile({
    required this.event,
    required this.teamName,
    required this.onEdit,
    required this.onDelete,
    this.teamLogoUrl,
  });

  String _initialsLocal(String name) {
    final parts =
        name.trim().split(RegExp(r"\s+")).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return "T";
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final color = eventTypeColor(event.type);
    final time = event.endAt == null
        ? hhmm(event.startAt)
        : "${hhmm(event.startAt)}–${hhmm(event.endAt!)}";

    final logo =
        (teamLogoUrl != null && teamLogoUrl!.trim().isNotEmpty) ? teamLogoUrl!.trim() : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 6,
              height: 74,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 74,
              child: Text(
                time,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F5F8),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: logo != null
                              ? Image.network(
                                  logo,
                                  width: 30,
                                  height: 30,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _TeamMiniAvatar(text: _initialsLocal(teamName)),
                                )
                              : _TeamMiniAvatar(text: _initialsLocal(teamName)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            teamName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: color.withOpacity(0.22)),
                        ),
                        child: Text(
                          eventTypeLabel(event.type),
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      if (event.location.trim().isNotEmpty)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 170),
                              child: Text(
                                event.location,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton(
              icon: const Icon(Icons.more_vert, size: 20),
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 18),
                      SizedBox(width: 8),
                      Text("Редактировать"),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text("Удалить", style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'edit') onEdit();
                if (value == 'delete') onDelete();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamMiniAvatar extends StatelessWidget {
  final String text;
  const _TeamMiniAvatar({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
      ),
    );
  }
}

// =======================
// Bottom sheets
// =======================

class _DayEventsBottomSheet extends StatelessWidget {
  final DateTime day;
  final List<TeamEvent> events;
  final Map<int, String> teamNamesById;
  final Map<int, String> teamLogosById;
  final VoidCallback onAdd;
  final ValueChanged<TeamEvent> onEdit;
  final ValueChanged<TeamEvent> onDelete;

  const _DayEventsBottomSheet({
    required this.day,
    required this.events,
    required this.teamNamesById,
    required this.teamLogosById,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  String _title(DateTime d) =>
      "${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}";

  @override
  Widget build(BuildContext context) {
    final topRadius = const Radius.circular(24);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: topRadius),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 5,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      "События • ${_title(day)}",
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    onAdd();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text("Добавить событие"),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              if (events.isEmpty)
                const _EmptySheetState(
                  title: "Событий нет",
                  subtitle: "Добавьте первое событие на этот день",
                  icon: Icons.event_available,
                )
              else
                Column(
                  children: [
                    ...events.take(8).map((e) {
                      final teamName = teamNamesById[e.teamId] ?? "Команда #${e.teamId}";
                      final logoUrl = teamLogosById[e.teamId];

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _EventSheetTile(
                          event: e,
                          teamName: teamName,
                          teamLogoUrl: logoUrl,
                          onEdit: () => onEdit(e),
                          onDelete: () => onDelete(e),
                        ),
                      );
                    }),
                    if (events.length > 8)
                      TextButton(
                        onPressed: () => _showAllEvents(context),
                        child: Text("Показать все (${events.length})"),
                      ),
                  ],
                ),
              const SizedBox(height: 6),
            ],
          ),
        ),
      ),
    );
  }

  void _showAllEvents(BuildContext context) {
    Navigator.pop(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AllEventsBottomSheet(
        day: day,
        events: events,
        teamNamesById: teamNamesById,
        teamLogosById: teamLogosById,
        onEdit: onEdit,
        onDelete: onDelete,
      ),
    );
  }
}

class _AllEventsBottomSheet extends StatelessWidget {
  final DateTime day;
  final List<TeamEvent> events;
  final Map<int, String> teamNamesById;
  final Map<int, String> teamLogosById;
  final ValueChanged<TeamEvent> onEdit;
  final ValueChanged<TeamEvent> onDelete;

  const _AllEventsBottomSheet({
    required this.day,
    required this.events,
    required this.teamNamesById,
    required this.teamLogosById,
    required this.onEdit,
    required this.onDelete,
  });

  String _title(DateTime d) =>
      "${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}";

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.86,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 5,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      "Все события • ${_title(day)}",
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.separated(
                  itemCount: events.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, index) {
                    final e = events[index];
                    final teamName = teamNamesById[e.teamId] ?? "Команда #${e.teamId}";
                    final logoUrl = teamLogosById[e.teamId];

                    return _EventSheetTile(
                      event: e,
                      teamName: teamName,
                      teamLogoUrl: logoUrl,
                      onEdit: () {
                        Navigator.pop(context);
                        onEdit(e);
                      },
                      onDelete: () {
                        Navigator.pop(context);
                        onDelete(e);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventSheetTile extends StatelessWidget {
  final TeamEvent event;
  final String teamName;
  final String? teamLogoUrl;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _EventSheetTile({
    required this.event,
    required this.teamName,
    required this.onEdit,
    required this.onDelete,
    this.teamLogoUrl,
  });

  String _initialsLocal(String name) {
    final parts =
        name.trim().split(RegExp(r"\s+")).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return "T";
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final color = eventTypeColor(event.type);
    final time = event.endAt == null
        ? hhmm(event.startAt)
        : "${hhmm(event.startAt)}–${hhmm(event.endAt!)}";

    final logo =
        (teamLogoUrl != null && teamLogoUrl!.trim().isNotEmpty) ? teamLogoUrl!.trim() : null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 72,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: color.withOpacity(0.22)),
                      ),
                      child: Text(
                        eventTypeLabel(event.type),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: color,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F5F8),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Text(
                        time,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F5F8),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: logo != null
                            ? Image.network(
                                logo,
                                width: 30,
                                height: 30,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _TeamMiniAvatar(text: _initialsLocal(teamName)),
                              )
                            : _TeamMiniAvatar(text: _initialsLocal(teamName)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          teamName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (event.location.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          event.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            children: [
              _IconActionButton(
                icon: Icons.edit,
                tooltip: "Редактировать",
                onPressed: onEdit,
              ),
              const SizedBox(height: 8),
              _IconActionButton(
                icon: Icons.delete,
                tooltip: "Удалить",
                color: Colors.red,
                onPressed: onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IconActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color? color;

  const _IconActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? const Color(0xFF111827);
    return Material(
      color: const Color(0xFFF3F5F8),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: SizedBox(
          width: 38,
          height: 38,
          child: Tooltip(
            message: tooltip,
            child: Icon(icon, size: 18, color: c),
          ),
        ),
      ),
    );
  }
}

class _EmptySheetState extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _EmptySheetState({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 26),
      child: Column(
        children: [
          Icon(icon, size: 56, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }
}

class _TeamGridItem {
  final int id;
  final String title;
  final String subtitle;
  final int badge;
  final String? logoUrl;
  final bool selected;

  const _TeamGridItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.logoUrl,
    required this.selected,
  });
}
