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
  final void Function(Widget Function(VoidCallback close) builder)?
      onOpenSidePanel;

  const PlayerActivitySection({
    super.key,
    required this.data,
    required this.selectedSession,
    required this.sessionLoading,
    required this.onSelectSession,
    this.onOpenSidePanel,
  });

  @override
  State<PlayerActivitySection> createState() =>
      _PlayerActivitySectionState();
}

class _PlayerActivitySectionState
    extends State<PlayerActivitySection> {
  DateTime? _selectedDay;

  List<PlayerProfileSession> get _allSessions {
    final rows = [...widget.data.sessions];
    rows.sort((a, b) {
      final ad = a.date ?? DateTime(1970);
      final bd = b.date ?? DateTime(1970);
      return bd.compareTo(ad);
    });
    return rows;
  }

  List<DateTime> get _sessionDays {
    final map = <String, DateTime>{};

    for (final session in _allSessions) {
      final date = session.date;
      if (date == null) continue;

      final day = DateTime(
        date.year,
        date.month,
        date.day,
      );

      map[DateFormat('yyyy-MM-dd').format(day)] = day;
    }

    final rows = map.values.toList()
      ..sort((a, b) => b.compareTo(a));

    return rows;
  }

  List<PlayerProfileSession> get _visibleSessions {
    final selectedDay = _selectedDay;

    if (selectedDay == null) {
      return _allSessions;
    }

    return _allSessions.where((session) {
      final date = session.date;
      if (date == null) return false;

      return date.year == selectedDay.year &&
          date.month == selectedDay.month &&
          date.day == selectedDay.day;
    }).toList();
  }

  PlayerProfileSession? get _featuredSession {
    final selected = widget.selectedSession;
    final visible = _visibleSessions;

    if (selected != null &&
        visible.any((row) => row.id == selected.id)) {
      return selected;
    }

    return visible.isEmpty ? null : visible.first;
  }

  @override
  Widget build(BuildContext context) {
    final sessions = _visibleSessions;
    final featured = _featuredSession;

    return Container(
      color: Colors.white,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          16,
          14,
          16,
          28,
        ),
        children: [
          PpSectionTitle(
            title: 'Активность',
            subtitle:
                'Краткая сводка тренировок и трекера. '
                'Полная аналитика открывается по сессии.',
            dotColor: PpColors.greenDark,
            trailing: PpTextAction(
              label: _selectedDay == null
                  ? 'Дата'
                  : DateFormat('dd.MM').format(_selectedDay!),
              onTap: _openCalendar,
              dotColor: PpColors.greenDark,
            ),
          ),
          const SizedBox(height: 12),

          _ActivitySummary(
            sessions: sessions,
          ),

          const PpThinDivider(
            margin: EdgeInsets.symmetric(vertical: 12),
          ),

          if (featured == null)
            const SizedBox(
              height: 210,
              child: PpEmpty(
                title: 'Активности пока нет',
                text:
                    'После загрузки GPS / Polar сессии появятся здесь.',
              ),
            )
          else ...[
            _FeaturedActivity(
              session: featured,
              loading:
                  widget.sessionLoading &&
                  widget.selectedSession?.id == featured.id,
              onDetails: () => _selectAndOpen(featured),
            ),

            if (sessions.length > 1) ...[
              const PpThinDivider(
                margin: EdgeInsets.symmetric(vertical: 12),
              ),
              _RecentActivityList(
                sessions: sessions
                    .where((row) => row.id != featured.id)
                    .take(6)
                    .toList(),
                onOpen: _selectAndOpen,
              ),
            ],
          ],

          if (_selectedDay != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: PpTextAction(
                label: 'Показать все активности',
                onTap: () {
                  setState(() => _selectedDay = null);
                },
                dotColor: PpColors.green,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openCalendar() async {
    final openSidePanel = widget.onOpenSidePanel;

    if (openSidePanel != null) {
      openSidePanel(
        (close) => _ActivityDatePanel(
          initialDate: _selectedDay ??
              (_sessionDays.isNotEmpty
                  ? _sessionDays.first
                  : DateTime.now()),
          sessionDays: _sessionDays,
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
          onClose: close,
        ),
      );
      return;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay ??
          (_sessionDays.isNotEmpty
              ? _sessionDays.first
              : DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(
        const Duration(days: 365),
      ),
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedDay = DateTime(
          picked.year,
          picked.month,
          picked.day,
        );
      });
    }
  }

  void _selectAndOpen(PlayerProfileSession session) {
    widget.onSelectSession(session);
    _openAnalytics(session);
  }

  void _openAnalytics(PlayerProfileSession session) {
    final player = widget.data.player;

    final teamId =
        _int(player['team_id'] ?? player['teamId']);
    final clubId =
        _int(player['club_id'] ?? player['clubId']);
    final userId = _int(
      player['user_id'] ??
          player['userId'] ??
          player['id'],
    );
    final playerId = _int(
      player['id'] ??
          player['player_id'] ??
          player['playerId'],
    );

    final playerName = _text(
      player['full_name'] ??
          player['fullName'] ??
          player['name'],
    );
    final teamName = _text(
      player['team_name'] ?? player['teamName'],
    );
    final clubName = _text(
      player['club_name'] ?? player['clubName'],
    );

    if (teamId <= 0 ||
        playerId <= 0 ||
        session.id <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Не хватает team_id, player_id или session_id '
            'для открытия аналитики.',
          ),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TrackerMatchWorkspaceScreen(
          clubId: clubId,
          clubName:
              clubName.isEmpty ? 'Клуб' : clubName,
          teamId: teamId,
          teamName:
              teamName.isEmpty ? 'Команда' : teamName,
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
          initialSection:
              TrackerWorkspaceSection.analytics,
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

    return int.tryParse(
          '${value ?? ''}'.trim(),
        ) ??
        0;
  }

  String _text(dynamic value) {
    final text = '${value ?? ''}'.trim();
    return text == 'null' ? '' : text;
  }
}

class _ActivitySummary extends StatelessWidget {
  final List<PlayerProfileSession> sessions;

  const _ActivitySummary({
    required this.sessions,
  });

  @override
  Widget build(BuildContext context) {
    final distance = sessions.fold<double>(
      0,
      (sum, row) => sum + row.distanceM,
    );

    final sprints = sessions.fold<int>(
      0,
      (sum, row) => sum + row.sprintCount,
    );

    var maxSpeed = 0.0;
    var duration = 0;

    for (final row in sessions) {
      if (row.maxSpeedKmh > maxSpeed) {
        maxSpeed = row.maxSpeedKmh;
      }
      duration += row.durationSec;
    }

    final values = <_SummaryValue>[
      _SummaryValue(
        'Сессии',
        '${sessions.length}',
      ),
      _SummaryValue(
        'Дистанция',
        distance > 0
            ? '${(distance / 1000).toStringAsFixed(1)} км'
            : '—',
      ),
      _SummaryValue(
        'Макс. скорость',
        maxSpeed > 0
            ? '${maxSpeed.toStringAsFixed(1)} км/ч'
            : '—',
      ),
      _SummaryValue(
        'Время · спринты',
        '${_duration(duration)} · $sprints',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            constraints.maxWidth >= 760 ? 4 : 2;

        final width =
            (constraints.maxWidth -
                    (columns - 1) * 8) /
                columns;

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: values
              .map(
                (item) => SizedBox(
                  width: width,
                  child: PpSurface(
                    color: PpColors.soft,
                    padding:
                        const EdgeInsets.fromLTRB(
                      11,
                      10,
                      11,
                      10,
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.label,
                          style: PpText.caption(),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          item.value,
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style: PpText.value(15),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _SummaryValue {
  final String label;
  final String value;

  const _SummaryValue(
    this.label,
    this.value,
  );
}

class _FeaturedActivity extends StatelessWidget {
  final PlayerProfileSession session;
  final bool loading;
  final VoidCallback onDetails;

  const _FeaturedActivity({
    required this.session,
    required this.loading,
    required this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    final cardio =
        session.avgHr > 0 || session.maxHr > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PpSectionTitle(
          title: 'Последняя активность',
          subtitle: session.date == null
              ? session.title
              : '${session.title} · '
                  '${DateFormat('dd.MM.yyyy · HH:mm').format(session.date!)}',
          dotColor: PpColors.green,
          trailing: PpTextAction(
            label: 'Подробнее',
            onTap: onDetails,
            dotColor: PpColors.greenDark,
            emphasized: true,
          ),
        ),
        const SizedBox(height: 9),

        Material(
          color: PpColors.soft,
          borderRadius: BorderRadius.circular(11),
          child: InkWell(
            onTap: onDetails,
            borderRadius: BorderRadius.circular(11),
            child: Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                12,
                11,
                12,
                11,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _InlineMetric(
                          label: 'Дистанция',
                          value: session.distanceM > 0
                              ? '${(session.distanceM / 1000).toStringAsFixed(2)} км'
                              : '—',
                        ),
                      ),
                      Expanded(
                        child: _InlineMetric(
                          label: 'Скорость',
                          value:
                              session.maxSpeedKmh > 0
                                  ? '${session.maxSpeedKmh.toStringAsFixed(1)} км/ч'
                                  : '—',
                        ),
                      ),
                      Expanded(
                        child: _InlineMetric(
                          label: 'Спринты',
                          value:
                              '${session.sprintCount}',
                        ),
                      ),
                      Expanded(
                        child: _InlineMetric(
                          label: cardio
                              ? 'Пульс'
                              : 'Время',
                          value: cardio
                              ? '${session.avgHr.round()} / ${session.maxHr.round()}'
                              : _duration(
                                  session.durationSec,
                                ),
                        ),
                      ),
                    ],
                  ),
                  if (loading) ...[
                    const SizedBox(height: 9),
                    const LinearProgressIndicator(
                      minHeight: 2,
                      color: PpColors.green,
                      backgroundColor:
                          PpColors.greenSoft,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _InlineMetric extends StatelessWidget {
  final String label;
  final String value;

  const _InlineMetric({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: PpText.caption()),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: PpText.body(
              10.8,
              color: PpColors.text,
              weight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentActivityList extends StatelessWidget {
  final List<PlayerProfileSession> sessions;
  final ValueChanged<PlayerProfileSession> onOpen;

  const _RecentActivityList({
    required this.sessions,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PpSectionTitle(
          title: 'Последние сессии',
          subtitle:
              'Нажмите на строку, чтобы открыть полную аналитику',
          dotColor: PpColors.greenDark,
        ),
        const SizedBox(height: 6),

        ...sessions.asMap().entries.map((entry) {
          final session = entry.value;

          return Column(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onOpen(session),
                  borderRadius:
                      BorderRadius.circular(8),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(
                      vertical: 9,
                      horizontal: 2,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 76,
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                session.date == null
                                    ? '—'
                                    : DateFormat(
                                        'dd.MM',
                                      ).format(
                                        session.date!,
                                      ),
                                style: PpText.body(
                                  10.6,
                                  color: PpColors.text,
                                  weight:
                                      FontWeight.w600,
                                ),
                              ),
                              if (session.date != null)
                                Text(
                                  DateFormat(
                                    'HH:mm',
                                  ).format(
                                    session.date!,
                                  ),
                                  style:
                                      PpText.caption(),
                                ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                session.title,
                                maxLines: 1,
                                overflow:
                                    TextOverflow.ellipsis,
                                style: PpText.body(
                                  10.8,
                                  color: PpColors.text,
                                  weight:
                                      FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _sessionLine(session),
                                maxLines: 1,
                                overflow:
                                    TextOverflow.ellipsis,
                                style:
                                    PpText.body(10),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Подробнее',
                          style: PpText.caption(
                            color:
                                PpColors.greenDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (entry.key !=
                  sessions.length - 1)
                const PpThinDivider(
                  margin: EdgeInsets.zero,
                ),
            ],
          );
        }),
      ],
    );
  }

  String _sessionLine(
    PlayerProfileSession session,
  ) {
    final parts = <String>[];

    if (session.distanceM > 0) {
      parts.add(
        '${(session.distanceM / 1000).toStringAsFixed(1)} км',
      );
    }

    if (session.maxSpeedKmh > 0) {
      parts.add(
        '${session.maxSpeedKmh.toStringAsFixed(1)} км/ч',
      );
    }

    if (session.sprintCount > 0) {
      parts.add(
        '${session.sprintCount} спринт.',
      );
    }

    if (session.avgHr > 0) {
      parts.add(
        '${session.avgHr.round()} уд/мин',
      );
    }

    return parts.isEmpty
        ? 'Данные сессии'
        : parts.join(' · ');
  }
}

class _ActivityDatePanel extends StatefulWidget {
  final DateTime initialDate;
  final List<DateTime> sessionDays;
  final ValueChanged<DateTime> onSelected;
  final VoidCallback onShowAll;
  final VoidCallback onClose;

  const _ActivityDatePanel({
    required this.initialDate,
    required this.sessionDays,
    required this.onSelected,
    required this.onShowAll,
    required this.onClose,
  });

  @override
  State<_ActivityDatePanel> createState() =>
      _ActivityDatePanelState();
}

class _ActivityDatePanelState
    extends State<_ActivityDatePanel> {
  late DateTime _selected;
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    _selected = DateTime(
      widget.initialDate.year,
      widget.initialDate.month,
      widget.initialDate.day,
    );
    _month = DateTime(
      _selected.year,
      _selected.month,
    );
  }

  bool _sameDay(
    DateTime a,
    DateTime b,
  ) =>
      a.year == b.year &&
      a.month == b.month &&
      a.day == b.day;

  bool _hasSession(DateTime date) =>
      widget.sessionDays.any(
        (row) => _sameDay(row, date),
      );

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 10,
      child: SafeArea(
        left: false,
        child: Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                14,
                12,
                10,
                10,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: PpSectionTitle(
                      title: 'Дата активности',
                      subtitle: DateFormat(
                        'dd.MM.yyyy',
                      ).format(_selected),
                      dotColor:
                          PpColors.greenDark,
                    ),
                  ),
                  PpTextAction(
                    label: 'Все',
                    onTap: widget.onShowAll,
                  ),
                  const SizedBox(width: 6),
                  PpTextAction(
                    label: 'Готово',
                    onTap: () =>
                        widget.onSelected(
                      _selected,
                    ),
                    emphasized: true,
                  ),
                  const SizedBox(width: 6),
                  PpTextAction(
                    label: '×',
                    onTap: widget.onClose,
                  ),
                ],
              ),
            ),
            const PpThinDivider(
              margin: EdgeInsets.zero,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.fromLTRB(
                  14,
                  12,
                  14,
                  20,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _monthTitle(_month),
                            style:
                                PpText.title(16),
                          ),
                        ),
                        PpTextAction(
                          label: '‹',
                          onTap: () {
                            setState(() {
                              _month = DateTime(
                                _month.year,
                                _month.month - 1,
                              );
                            });
                          },
                        ),
                        const SizedBox(width: 5),
                        PpTextAction(
                          label: '›',
                          onTap: () {
                            setState(() {
                              _month = DateTime(
                                _month.year,
                                _month.month + 1,
                              );
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    Row(
                      children: const [
                        'Пн',
                        'Вт',
                        'Ср',
                        'Чт',
                        'Пт',
                        'Сб',
                        'Вс',
                      ].map(
                        (label) => Expanded(
                          child: Center(
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight:
                                    FontWeight.w600,
                                color:
                                    PpColors.muted,
                              ),
                            ),
                          ),
                        ),
                      ).toList(),
                    ),
                    const SizedBox(height: 6),

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
    final first = DateTime(
      _month.year,
      _month.month,
      1,
    );
    final leading = first.weekday - 1;
    final start = first.subtract(
      Duration(days: leading),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        return GridView.builder(
          shrinkWrap: true,
          physics:
              const NeverScrollableScrollPhysics(),
          itemCount: 42,
          gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            crossAxisSpacing: 5,
            mainAxisSpacing: 5,
            mainAxisExtent: 44,
          ),
          itemBuilder: (_, index) {
            final date = start.add(
              Duration(days: index),
            );

            final inMonth =
                date.month == _month.month;
            final selected =
                _sameDay(date, _selected);
            final hasSession =
                _hasSession(date);

            return Material(
              color: Colors.transparent,
              borderRadius:
                  BorderRadius.circular(9),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selected = DateTime(
                      date.year,
                      date.month,
                      date.day,
                    );

                    if (!inMonth) {
                      _month = DateTime(
                        date.year,
                        date.month,
                      );
                    }
                  });
                },
                borderRadius:
                    BorderRadius.circular(9),
                child: Container(
                  decoration: BoxDecoration(
                    color: selected
                        ? PpColors.greenSoft
                        : PpColors.soft,
                    borderRadius:
                        BorderRadius.circular(9),
                  ),
                  child: Stack(
                    children: [
                      Center(
                        child: Text(
                          '${date.day}',
                          style: PpText.body(
                            10.6,
                            color: inMonth
                                ? PpColors.text
                                : PpColors.muted2,
                            weight: selected
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                      if (hasSession)
                        const Positioned(
                          right: 6,
                          top: 6,
                          child: SizedBox(
                            width: 5,
                            height: 5,
                            child: DecoratedBox(
                              decoration:
                                  BoxDecoration(
                                color:
                                    PpColors.green,
                                shape:
                                    BoxShape.circle,
                              ),
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
    final raw =
        DateFormat('LLLL yyyy', 'ru').format(value);

    if (raw.isEmpty) {
      return '${value.month}.${value.year}';
    }

    return '${raw[0].toUpperCase()}'
        '${raw.substring(1)}';
  }
}

String _duration(int seconds) {
  if (seconds <= 0) return '—';

  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;

  if (hours > 0) {
    return '${hours}ч ${minutes}м';
  }

  return '${minutes}м';
}
