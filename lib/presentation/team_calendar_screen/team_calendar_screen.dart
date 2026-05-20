import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:sportoteka/core/utils/pref_utils.dart';

import 'team_calendar_models.dart';
import 'team_calendar_api.dart';
import 'event_editor_sheet.dart';
import 'calendar_month_grid.dart';
import 'calendar_week_view.dart';
import 'training_event_detail_sheet.dart';

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
static const String apiBase = "https://sportotekaapp.ru/api";

late final TeamCalendarApi api;

bool loading = true;

CalendarMode mode = CalendarMode.month;
DateTime cursor = DateTime.now();
DateTime selectedDay = DateTime.now();

List<TeamEvent> events = [];
Map<DateTime, List<TeamEvent>> eventsByDay = {};

Color get primary => Theme.of(context).colorScheme.primary;

// ✅ права
String _role = "";
bool get canEdit {
final r = _role.toLowerCase().trim();
// игрокам запрещаем
if (r == "player") return false;

// всё остальное — можно (coach/admin/federation/parent etc.)
// если хочешь только coach/admin, сделаем строже:
// return r == "coach" || r == "admin";
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
await _fetch();
}

/// ✅ ВАЖНО: подстрой под свой PrefUtils ОДНОЙ строкой.
/// Самый частый вариант: PrefUtils.getRole() или PrefUtils.getString("role")
Future<String> _loadRoleSafe() async {
try {
  // ====== ВАРИАНТ 1 (если у тебя есть PrefUtils.getRole()) ======
  // final r = await PrefUtils.getRole() ?? "";
  // return r;

  // ====== ВАРИАНТ 2 (если у тебя есть PrefUtils.getString) ======
  // final r = PrefUtils.getString("role") ?? "";
  // return r;

  // ====== ВАРИАНТ 3 (если роль лежит в сохранённых userData) ======
  // final m = await PrefUtils.getUserData(); // Map
  // return (m?["role"] ?? "").toString();

  // ✅ ПО УМОЛЧАНИЮ (чтобы не падало) — считаем что это НЕ игрок
  // и включаем редактирование. Но лучше включи один из вариантов выше.
  return "";
} catch (_) {
  return "";
}
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
  Get.snackbar("Ошибка", e.toString(), snackPosition: SnackPosition.BOTTOM);
}

setState(() => loading = false);
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

Future<void> _openCreate(DateTime day) async {
  if (!canEdit) return;

  final createdBy = await PrefUtils.getUserId() ?? 0;
  final base = DateTime(day.year, day.month, day.day, 18, 0);

  // Показываем bottom sheet с callback
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => EventEditorSheet(
      primary: primary,
      teamId: widget.teamId,
      clubId: 0,
      createdBy: createdBy,
      initialDateTime: base,
      onEventAdded: (event) async {
        // Этот callback вызывается при нажатии "Добавить ещё"
        try {
          await api.add(event: event, createdBy: createdBy);
          await _fetch();
          // Не закрываем окно!
        } catch (e) {
          Get.snackbar("Ошибка", e.toString(), 
              snackPosition: SnackPosition.BOTTOM);
        }
      },
    ),
  ).then((result) async {
    // Этот then вызывается при закрытии окна (кнопка "Добавить" или "Закрыть")
    if (result != null && result is TeamEvent) {
      try {
        await api.add(event: result, createdBy: createdBy);
        await _fetch();
      } catch (e) {
        Get.snackbar("Ошибка", e.toString(), 
            snackPosition: SnackPosition.BOTTOM);
      }
    }
  });
}
Future<void> _openEdit(TeamEvent current) async {
if (!canEdit) return; // ✅ запрет для player

final ev = await showModalBottomSheet<TeamEvent?>(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  builder: (_) => EventEditorSheet(
    primary: primary,
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
  Get.snackbar("Ошибка", e.toString(), snackPosition: SnackPosition.BOTTOM);
}
}

Future<void> _openDetails(TeamEvent e) async {
// ✅ игрокам можно детали показать или нет — реши:
// если НЕ надо детали игроку — раскомментируй:
// if (!canEdit) return;

await showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  builder: (_) => TrainingEventDetailSheet(
    apiBase: apiBase,
    event: e,
  ),
);
}

Future<void> _delete(TeamEvent e) async {
if (!canEdit) return; // ✅ запрет для player

final ok = await showDialog<bool>(
  context: context,
  builder: (_) => AlertDialog(
    title: const Text("Удалить событие?"),
    content: Text("“${e.title}” будет удалено."),
    actions: [
      TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text("Отмена")),
      ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text("Удалить")),
    ],
  ),
);

if (ok != true) return;

try {
  await api.remove(eventId: e.id, teamId: widget.teamId);
  await _fetch();
} catch (err) {
  Get.snackbar("Ошибка", err.toString(), snackPosition: SnackPosition.BOTTOM);
}
}

Future<void> _dayActions(DateTime day) async {
// ✅ игрокам не показываем меню действий вообще
if (!canEdit) return;

final list = (eventsByDay[dateOnly(day)] ?? const <TeamEvent>[])
    .toList()
  ..sort((a, b) => a.startAt.compareTo(b.startAt));

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
// ✅ игрокам не показываем “все события” шторку с действиями
// но можно показать read-only — если надо, скажи, сделаю.
if (!canEdit) return;

await showModalBottomSheet(
  context: context,
  backgroundColor: Colors.transparent,
  isScrollControlled: true,
  builder: (_) => _AllEventsSheet(
    day: day,
    events: list,
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
              color: c, borderRadius: BorderRadius.circular(3))),
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
  decoration:
      BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
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
              color: active ? primary : const Color(0xFFE5E7EB)),
        ),
        child: Center(
          child: Text(
            text,
            maxLines: 1,
            softWrap: false,
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
      IconButton(onPressed: _fetch, icon: const Icon(Icons.refresh)),
    ],
  ),
  body: ListView(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
    children: [
      Container(
        padding: const EdgeInsets.all(12),
        decoration:
            BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
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
            ),
          ],
        ),
      ),

      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(12),
        decoration:
            BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
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

          // ✅ долгий тап — только если можно редактировать
          onDayLongPress: (d) {
            if (!canEdit) return;
            setState(() => selectedDay = d);
            _dayActions(d);
          },
        ),
        const SizedBox(height: 12),

        _SelectedDayAgenda(
          day: selectedDay,
          items: selectedList,

          // ✅ кнопки/действия только если canEdit
          canEdit: canEdit,
          onAdd: () => _openCreate(selectedDay),
          onEdit: _openEdit,
          onDelete: _delete,
          onShowAll: () => _showAllEvents(selectedDay, selectedList),
          onDetails: _openDetails,
        ),
      ] else ...[
        CalendarWeekView(
          weekStartMonday: weekStart,
          eventsByDay: eventsByDay,
          selectedDay: selectedDay,
          onDayTap: (d) => setState(() => selectedDay = d),

          onDayLongPress: (d) {
            if (!canEdit) return;
            setState(() => selectedDay = d);
            _dayActions(d);
          },

          // ✅ редактирование по тапу — только если можно
          onEventTap: (e) {
            if (!canEdit) return;
            _openEdit(e);
          },
          onEventLongPress: (e) {
            if (!canEdit) return;
            _delete(e);
          },
        ),

        const SizedBox(height: 12),

        _SelectedDayAgenda(
          day: selectedDay,
          items: selectedList,
          canEdit: canEdit,
          onAdd: () => _openCreate(selectedDay),
          onEdit: _openEdit,
          onDelete: _delete,
          onShowAll: () => _showAllEvents(selectedDay, selectedList),
          onDetails: _openDetails,
        ),
      ],
    ],
  ),
);
}
}

// ===================== Widgets =====================

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

@override
Widget build(BuildContext context) {
String dd(DateTime d) =>
    "${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}";
final show = items.take(5).toList();

return Container(
  padding: const EdgeInsets.all(12),
  decoration:
      BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
  child: Column(
    children: [
      Row(
        children: [
          Expanded(
            child: Text("События на ${dd(day)}",
                style:
                    const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
          ),

          // ✅ кнопка “Добавить” только не игрокам
          if (canEdit) TextButton(onPressed: onAdd, child: const Text("Добавить")),
        ],
      ),
      const SizedBox(height: 8),
      if (items.isEmpty)
        const Align(
          alignment: Alignment.centerLeft,
          child: Text("Нет событий",
              style: TextStyle(color: Color(0xFF6B7280))),
        )
      else ...[
        ...show.map((e) => _AgendaTile(
              e: e,
              canEdit: canEdit,
              onEdit: () => onEdit(e),
              onDelete: () => onDelete(e),
              onDetails: () => onDetails(e),
            )),

        // “Показать все” можно оставить всем (оно открывает sheet с действиями)
        // поэтому делаем только тем, кто может редактировать
        if (canEdit && items.length > show.length) ...[
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onShowAll,
              child: Text("Показать все (${items.length})"),
            ),
          )
        ]
      ],
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
final when =
    e.endAt == null ? hhmm(e.startAt) : "${hhmm(e.startAt)}–${hhmm(e.endAt!)}";

return Container(
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
          decoration:
              BoxDecoration(color: c, borderRadius: BorderRadius.circular(6))),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(e.title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text("${eventTypeLabel(e.type)} • $when",
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
            if (e.location.trim().isNotEmpty) ...[
              const SizedBox(height: 2),
              Text("📍 ${e.location}", style: const TextStyle(fontSize: 12)),
            ],
            if (e.notes.trim().isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(e.notes,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF374151))),
            ],
          ],
        ),
      ),

      // ✅ игрокам скрываем все кнопки
      if (canEdit) ...[
        IconButton(
          tooltip: "Подробнее",
          onPressed: onDetails,
          icon: const Icon(Icons.info_outline),
        ),
        IconButton(onPressed: onEdit, icon: const Icon(Icons.edit)),
        IconButton(onPressed: onDelete, icon: const Icon(Icons.delete_outline)),
      ],
    ],
  ),
);
}
}

// ---------- Sheets (они всё равно вызываются только если canEdit = true) ----------

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
    color: Color(0xFFF3F5F8),
    borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
  ),
  child: SafeArea(
    top: false,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 5,
          decoration: BoxDecoration(
              color: Colors.black12, borderRadius: BorderRadius.circular(99)),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                "События • ${day.day}.${day.month.toString().padLeft(2, '0')}.${day.year}",
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ),
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Закрыть")),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text("Добавить"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 10),

        if (events.isEmpty)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text("В этот день событий нет",
                style: TextStyle(color: Color(0xFF6B7280))),
          )
        else ...[
          ...events.take(6).map((e) => _AgendaTile(
                e: e,
                canEdit: true,
                onEdit: () => onEdit(e),
                onDelete: () => onDelete(e),
                onDetails: () => onDetails(e),
              )),
          if (events.length > 6)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onShowAll,
                child: Text("Показать все (${events.length})"),
              ),
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
final ValueChanged<TeamEvent> onEdit;
final ValueChanged<TeamEvent> onDelete;
final ValueChanged<TeamEvent> onDetails;

const _AllEventsSheet({
required this.day,
required this.events,
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
    color: Color(0xFFF3F5F8),
    borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
  ),
  child: SafeArea(
    top: false,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 5,
          decoration: BoxDecoration(
              color: Colors.black12, borderRadius: BorderRadius.circular(99)),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                "Все события • ${day.day}.${day.month.toString().padLeft(2, '0')}.${day.year}",
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ),
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Закрыть")),
          ],
        ),
        const SizedBox(height: 10),

        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 520),
          child: ListView.builder(
            itemCount: events.length,
            itemBuilder: (_, i) {
              final e = events[i];
              return _AgendaTile(
                e: e,
                canEdit: true,
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
