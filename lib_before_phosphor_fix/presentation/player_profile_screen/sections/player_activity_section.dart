import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:sportoteka/presentation/tracker/screens/tracker_match_workspace_screen.dart';

import '../models/player_profile_models.dart';
import '../widgets/player_profile_ui.dart';

class PlayerActivitySection extends StatefulWidget {
  final PlayerProfileSnapshot data;
  final PlayerProfileSession? selectedSession;
  final bool sessionLoading;
  final ValueChanged<PlayerProfileSession> onSelectSession;
  final void Function(Widget Function(VoidCallback close) builder)? onOpenSidePanel;

  const PlayerActivitySection({
    super.key,
    required this.data,
    required this.selectedSession,
    required this.sessionLoading,
    required this.onSelectSession,
    this.onOpenSidePanel,
  });

  @override
  State<PlayerActivitySection> createState() => _PlayerActivitySectionState();
}

class _PlayerActivitySectionState extends State<PlayerActivitySection> {
  DateTime? _selectedDay;

  List<DateTime> get _days {
    final keys = <String, DateTime>{};
    for (final session in widget.data.sessions) {
      final d = session.date;
      if (d == null) continue;
      final day = DateTime(d.year, d.month, d.day);
      keys[DateFormat('yyyy-MM-dd').format(day)] = day;
    }
    final result = keys.values.toList()..sort((a, b) => b.compareTo(a));
    return result;
  }

  List<PlayerProfileSession> get _visibleSessions {
    if (_selectedDay == null) return widget.data.sessions;
    return widget.data.sessions.where((session) {
      final d = session.date;
      return d != null &&
          d.year == _selectedDay!.year &&
          d.month == _selectedDay!.month &&
          d.day == _selectedDay!.day;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: PpSectionTitle(
                  title: 'Активность игрока',
                  subtitle: 'Выберите дату и сессию. Поле, скорость и пульс открываются отдельным окном.',
                ),
              ),
              const SizedBox(width: 10),
              _CalendarOpenButton(
                selectedDay: _selectedDay,
                onTap: _openCalendarPanel,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _dayPicker(),
          const SizedBox(height: 14),
          _summaryStrip(),
          const SizedBox(height: 14),
          _sessionGrid(),
        ],
      ),
    );
  }

  void _openCalendarPanel() {
    final open = widget.onOpenSidePanel;
    if (open == null) return;
    open((close) => _ActivityDateCalendar(
      initialDate: _selectedDay ?? (_days.isNotEmpty ? _days.first : DateTime.now()),
      sessionDays: _days,
      onCancel: close,
      onShowAll: () {
        if (mounted) {
          setState(() => _selectedDay = null);
        }
        close();
      },
      onSelected: (date) {
        if (mounted) {
          setState(() => _selectedDay = date);
        }
        close();
      },
    ));
  }

  Widget _dayPicker() {
    final days = _days;
    if (days.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 68,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          if (index == 0) {
            final active = _selectedDay == null;
            return _DayTile(
              top: 'Все',
              bottom: '${widget.data.sessions.length} сессий',
              active: active,
              onTap: () => setState(() => _selectedDay = null),
            );
          }
          final day = days[index - 1];
          final count = widget.data.sessions.where((s) {
            final d = s.date;
            return d != null && d.year == day.year && d.month == day.month && d.day == day.day;
          }).length;
          final active = _selectedDay != null &&
              _selectedDay!.year == day.year &&
              _selectedDay!.month == day.month &&
              _selectedDay!.day == day.day;
          return _DayTile(
            top: DateFormat('dd MMM', 'ru').format(day),
            bottom: '$count ${count == 1 ? 'сессия' : 'сессии'}',
            active: active,
            onTap: () => setState(() => _selectedDay = day),
          );
        },
      ),
    );
  }

  Widget _summaryStrip() {
    final sessions = _visibleSessions;
    final distance = sessions.fold<double>(0, (sum, s) => sum + s.distanceM);
    final duration = sessions.fold<int>(0, (sum, s) => sum + s.durationSec);
    final sprints = sessions.fold<int>(0, (sum, s) => sum + s.sprintCount);
    final maxSpeed = sessions.fold<double>(0, (max, s) => s.maxSpeedKmh > max ? s.maxSpeedKmh : max);

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 780 ? 4 : 2;
        final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
        final items = [
          ('Сессии', '${sessions.length}'),
          ('Дистанция', distance <= 0 ? '—' : '${(distance / 1000).toStringAsFixed(1)} км'),
          ('Макс. скорость', maxSpeed <= 0 ? '—' : '${maxSpeed.toStringAsFixed(1)} км/ч'),
          ('Время / спринты', '${_duration(duration)} · $sprints'),
        ];
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: items
              .map((item) => SizedBox(
                    width: width,
                    child: PpSurface(
                      color: PpColors.soft,
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.$1, style: PpText.body(10.5)),
                          const SizedBox(height: 5),
                          Text(item.$2, style: PpText.title(15)),
                        ],
                      ),
                    ),
                  ))
              .toList(),
        );
      },
    );
  }

  Widget _sessionGrid() {
    final sessions = _visibleSessions;
    if (sessions.isEmpty) {
      return const PpEmpty(
        title: 'Активности нет',
        text: 'За выбранную дату сессии трекера не найдены.',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final count = constraints.maxWidth >= 560
            ? 4
            : constraints.maxWidth >= 360
                ? 2
                : 1;
        // Фиксированная высота не позволяет GridView растягивать карточки
        // на всю доступную высоту при четырёх колонках.
        final cardHeight = count >= 2 ? 146.0 : 172.0;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: count,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            mainAxisExtent: cardHeight,
          ),
          itemCount: sessions.length,
          itemBuilder: (_, index) {
            final session = sessions[index];
            final active = widget.selectedSession?.id == session.id;
            return _SessionCard(
              session: session,
              active: active,
              loading: active && widget.sessionLoading,
              onSelect: () => widget.onSelectSession(session),
              compact: count >= 2,
              onAnalytics: () {
                widget.onSelectSession(session);
                if (!mounted) return;
                _openAnalytics(session);
              },
            );
          },
        );
      },
    );
  }

  void _openAnalytics(PlayerProfileSession session) {

    final player = widget.data.player;
    final teamId = _int(player['team_id'] ?? player['teamId']);
    final clubId = _int(player['club_id'] ?? player['clubId']);
    final userId = _int(player['user_id'] ?? player['userId'] ?? player['id']);
    final playerId = _int(player['id'] ?? player['player_id'] ?? player['playerId']);
    final playerName = _text(player['full_name'] ?? player['fullName'] ?? player['name']);
    final teamName = _text(player['team_name'] ?? player['teamName']);
    final clubName = _text(player['club_name'] ?? player['clubName']);

    if (teamId <= 0 || playerId <= 0 || session.id <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не хватает team_id, player_id или session_id для открытия трекера.')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TrackerMatchWorkspaceScreen(
          clubId: clubId,
          clubName: clubName.isEmpty ? 'Клуб' : clubName,
          teamId: teamId,
          teamName: teamName.isEmpty ? 'Команда' : teamName,
          userId: userId,
          initialPlayers: <Map<String, dynamic>>[
            <String, dynamic>{
              ...player,
              'id': playerId,
              'player_id': playerId,
              'name': playerName,
              'full_name': playerName,
            },
          ],
          analyticsOnly: true,
          initialSection: TrackerWorkspaceSection.analytics,
          initialPlayerId: playerId,
          initialSessionId: session.id,
          initialAnalyticsTab: 1,
        ),
      ),
    );
  }

  int _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? ''}'.trim()) ?? 0;
  }

  String _text(dynamic value) {
    final text = '${value ?? ''}'.trim();
    return text == 'null' ? '' : text;
  }

  String _duration(int seconds) {
    if (seconds <= 0) return '—';
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    return h > 0 ? '${h}ч ${m}м' : '${m}м';
  }
}

class _DayTile extends StatelessWidget {
  final String top;
  final String bottom;
  final bool active;
  final VoidCallback onTap;

  const _DayTile({
    required this.top,
    required this.bottom,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 104,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: active ? PpColors.greenSoft : Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(top, style: PpText.body(11.6, color: PpColors.text, weight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(bottom, style: PpText.body(9.8)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final PlayerProfileSession session;
  final bool active;
  final bool loading;
  final VoidCallback onSelect;
  final VoidCallback onAnalytics;
  final bool compact;

  const _SessionCard({
    required this.session,
    required this.active,
    required this.loading,
    required this.onSelect,
    required this.onAnalytics,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: EdgeInsets.all(compact ? 10 : 13),
          decoration: BoxDecoration(
            color: active ? PpColors.greenSoft : PpColors.soft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: compact ? _compactContent() : _fullContent(),
        ),
      ),
    );
  }

  Widget _compactContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                session.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: PpText.body(11.2, color: PpColors.text, weight: FontWeight.w600),
              ),
            ),
            if (loading) ...[
              const SizedBox(width: 8),
              const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.8, color: PpColors.green)),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(session.date == null ? 'Без даты' : DateFormat('dd.MM · HH:mm').format(session.date!), maxLines: 1, style: PpText.body(9.2)),
        const SizedBox(height: 6),
        _sourceBadge(),
        const SizedBox(height: 9),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${(session.distanceM / 1000).toStringAsFixed(1)} км', style: PpText.title(13)),
                  const SizedBox(height: 2),
                  Text(
                    '${session.maxSpeedKmh.toStringAsFixed(1)} км/ч · ${session.sprintCount} сп.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PpText.body(8.8),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            InkWell(
              onTap: onAnalytics,
              borderRadius: BorderRadius.circular(9),
              child: Container(
                width: 31,
                height: 31,
                decoration: BoxDecoration(
                  color: active ? Colors.white : PpColors.soft2,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.insights_rounded, size: 16, color: PpColors.greenDark),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _fullContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(session.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: PpText.body(12, color: PpColors.text, weight: FontWeight.w600))),
            if (loading) const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 1.8, color: PpColors.green)),
          ],
        ),
        const SizedBox(height: 4),
        Text(session.date == null ? 'Без даты' : DateFormat('dd.MM.yyyy · HH:mm').format(session.date!), style: PpText.body(10)),
        const SizedBox(height: 8),
        _sourceBadge(),
        const Spacer(),
        Wrap(
          spacing: 12,
          runSpacing: 5,
          children: [
            _smallMetric('${(session.distanceM / 1000).toStringAsFixed(1)} км', 'дистанция'),
            _smallMetric('${session.maxSpeedKmh.toStringAsFixed(1)}', 'км/ч'),
            _smallMetric('${session.sprintCount}', 'спринты'),
          ],
        ),
        const Spacer(),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: onAnalytics,
            style: TextButton.styleFrom(
              foregroundColor: PpColors.greenDark,
              backgroundColor: active ? Colors.white.withOpacity(.78) : PpColors.soft2,
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
            ),
            child: Text('Показать аналитику', style: PpText.body(10.8, color: PpColors.greenDark, weight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }


  Widget _sourceBadge() {
    final hasGps = session.route.isNotEmpty ||
        session.heatmap.isNotEmpty ||
        session.distanceM > 0 ||
        session.maxSpeedKmh > 0 ||
        session.speedTimeline.isNotEmpty;
    final hasCardio = session.avgHr > 0 ||
        session.maxHr > 0 ||
        session.minHr > 0 ||
        session.heartRateTimeline.isNotEmpty;

    final label = hasGps && hasCardio
        ? 'GPS • Кардио'
        : hasCardio
            ? 'Кардио'
            : hasGps
                ? 'GPS'
                : 'Без датчиков';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: active ? Colors.white.withOpacity(.86) : Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: PpText.body(
          9.2,
          color: hasGps || hasCardio ? PpColors.greenDark : PpColors.muted,
          weight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _smallMetric(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: PpText.body(11.3, color: PpColors.text, weight: FontWeight.w600)),
        Text(label, style: PpText.body(9.2)),
      ],
    );
  }
}


class _CalendarOpenButton extends StatelessWidget {
  final DateTime? selectedDay;
  final VoidCallback onTap;

  const _CalendarOpenButton({required this.selectedDay, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(color: PpColors.greenSoft, borderRadius: BorderRadius.circular(10)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_month_rounded, size: 18, color: PpColors.greenDark),
              const SizedBox(width: 7),
              Text(selectedDay == null ? 'Календарь' : DateFormat('dd.MM.yyyy').format(selectedDay!), style: PpText.body(10.8, color: PpColors.greenDark, weight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityDateCalendar extends StatefulWidget {
  final DateTime initialDate;
  final List<DateTime> sessionDays;
  final ValueChanged<DateTime> onSelected;
  final VoidCallback onShowAll;
  final VoidCallback onCancel;

  const _ActivityDateCalendar({required this.initialDate, required this.sessionDays, required this.onSelected, required this.onShowAll, required this.onCancel});

  @override
  State<_ActivityDateCalendar> createState() => _ActivityDateCalendarState();
}

class _ActivityDateCalendarState extends State<_ActivityDateCalendar> {
  late DateTime month;
  late DateTime selected;

  @override
  void initState() {
    super.initState();
    selected = DateTime(widget.initialDate.year, widget.initialDate.month, widget.initialDate.day);
    month = DateTime(selected.year, selected.month);
  }

  bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
  bool _hasSession(DateTime date) => widget.sessionDays.any((d) => _sameDay(d, date));

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 14,
      child: SafeArea(
        left: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
              child: Row(
                children: [
                  Container(width: 38, height: 38, decoration: BoxDecoration(color: PpColors.greenSoft, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.calendar_month_rounded, color: PpColors.green, size: 19)),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Дата активности', style: PpText.title(15.5)), const SizedBox(height: 2), Text(DateFormat('dd.MM.yyyy').format(selected), style: PpText.body(10.5))])),
                  _CalendarAction(icon: Icons.close_rounded, tooltip: 'Закрыть', onTap: widget.onCancel),
                  const SizedBox(width: 5),
                  _CalendarAction(icon: Icons.check_rounded, tooltip: 'Выбрать дату', onTap: () => widget.onSelected(selected)),
                ],
              ),
            ),
            const Divider(height: 1, color: PpColors.line),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_monthTitle(month), style: PpText.title(18)), const SizedBox(height: 2), Text('Выберите день сессии', style: PpText.body(10.5))])),
                      _CalendarAction(icon: Icons.chevron_left_rounded, tooltip: 'Предыдущий месяц', onTap: () => setState(() => month = DateTime(month.year, month.month - 1))),
                      const SizedBox(width: 4),
                      _CalendarAction(icon: Icons.chevron_right_rounded, tooltip: 'Следующий месяц', onTap: () => setState(() => month = DateTime(month.year, month.month + 1))),
                      const SizedBox(width: 4),
                      _CalendarAction(icon: Icons.calendar_today_rounded, tooltip: 'Сегодня', onTap: () { final now = DateTime.now(); setState(() { selected = DateTime(now.year, now.month, now.day); month = DateTime(now.year, now.month); }); }),
                      const SizedBox(width: 4),
                      _CalendarAction(icon: Icons.apps_rounded, tooltip: 'Показать все даты', onTap: widget.onShowAll),
                    ]),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: _CalendarSummary(value: '${selected.day}', label: 'День', hint: DateFormat('EEEE', 'ru').format(selected))),
                      const SizedBox(width: 6),
                      Expanded(child: _CalendarSummary(value: '${selected.month}', label: 'Месяц', hint: DateFormat('MMMM', 'ru').format(selected))),
                      const SizedBox(width: 6),
                      Expanded(child: _CalendarSummary(value: '${selected.year}', label: 'Год', hint: 'сессия')),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: ['Пн','Вт','Ср','Чт','Пт','Сб','Вс'].map((e) => Expanded(child: Center(child: Text(e, style: PpText.body(10, weight: FontWeight.w600))))).toList()),
                    const SizedBox(height: 5),
                    _monthGrid(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _monthGrid() {
    final first = DateTime(month.year, month.month, 1);
    final leading = first.weekday - 1;
    final start = first.subtract(Duration(days: leading));
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellHeight = constraints.maxWidth < 520 ? 45.0 : 48.0;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            crossAxisSpacing: 5,
            mainAxisSpacing: 5,
            mainAxisExtent: cellHeight,
          ),
          itemCount: 42,
          itemBuilder: (_, index) {
            final day = start.add(Duration(days: index));
            final currentMonth = day.month == month.month;
            final active = _sameDay(day, selected);
            final today = _sameDay(day, DateTime.now());
            final hasSession = _hasSession(day);
            return Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: () => setState(() {
                  selected = DateTime(day.year, day.month, day.day);
                  if (!currentMonth) month = DateTime(day.year, day.month);
                }),
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: active ? PpColors.greenSoft : const Color(0xFFF7F8F7),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: active || today ? PpColors.greenBorder : Colors.transparent,
                    ),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Text(
                          '${day.day}',
                          style: PpText.body(
                            11.2,
                            color: currentMonth ? PpColors.text : const Color(0xFFB3B8C0),
                            weight: active || today ? FontWeight.w700 : FontWeight.w600,
                          ),
                        ),
                      ),
                      if (hasSession)
                        Positioned(
                          right: 7,
                          top: 7,
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: PpColors.amber,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _monthTitle(DateTime value) {
    final raw = DateFormat('LLLL yyyy', 'ru').format(value);
    return raw.isEmpty ? '${value.month}.${value.year}' : '${raw[0].toUpperCase()}${raw.substring(1)}';
  }
}

class _CalendarAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _CalendarAction({required this.icon, required this.tooltip, required this.onTap});
  @override
  Widget build(BuildContext context) => Tooltip(message: tooltip, child: Material(color: Colors.transparent, borderRadius: BorderRadius.circular(10), child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(10), child: Container(width: 36, height: 36, decoration: BoxDecoration(color: PpColors.soft2, borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 18, color: PpColors.text)))));
}

class _CalendarSummary extends StatelessWidget {
  final String value;
  final String label;
  final String hint;
  const _CalendarSummary({required this.value, required this.label, required this.hint});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9), decoration: BoxDecoration(color: PpColors.soft, borderRadius: BorderRadius.circular(10)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(value, style: PpText.title(14)), const SizedBox(height: 2), Text(label, style: PpText.body(9.2)), Text(hint, maxLines: 1, overflow: TextOverflow.ellipsis, style: PpText.body(8.4))]));
}

class _AnalyticsHeader extends StatelessWidget {
  final PlayerProfileSession session;
  final VoidCallback onClose;

  const _AnalyticsHeader({required this.session, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: PpColors.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(session.title, style: PpText.title(16)),
                const SizedBox(height: 3),
                Text(
                  session.date == null ? 'Аналитика сессии' : DateFormat('dd.MM.yyyy · HH:mm').format(session.date!),
                  style: PpText.body(10.5),
                ),
              ],
            ),
          ),
          IconButton(onPressed: onClose, icon: const Icon(Icons.close_rounded, size: 20)),
        ],
      ),
    );
  }
}
