import 'package:flutter/material.dart';

import 'package:sportoteka/core/theme/app_typography.dart';

class TrainerCabinetPanel extends StatelessWidget {
  final String clubName;
  final List<Map<String, dynamic>> teams;
  final List<Map<String, dynamic>> events;
  final List<Map<String, dynamic>> latestPlans;
  final List<Map<String, dynamic>> players;

  final VoidCallback onOpenProfile;
  final VoidCallback onOpenTrainers;
  final VoidCallback onOpenTeams;
  final VoidCallback onOpenCalendar;
  final VoidCallback onOpenPlans;
  final VoidCallback onOpenTesting;
  final VoidCallback onOpenChats;
  final VoidCallback onOpenReports;

  const TrainerCabinetPanel({
    super.key,
    required this.clubName,
    required this.teams,
    required this.events,
    required this.latestPlans,
    required this.players,
    required this.onOpenProfile,
    required this.onOpenTrainers,
    required this.onOpenTeams,
    required this.onOpenCalendar,
    required this.onOpenPlans,
    required this.onOpenTesting,
    required this.onOpenChats,
    required this.onOpenReports,
  });

  static const Color _green =
      Color(0xFF00A750);
  static const Color _greenDark =
      Color(0xFF067A46);
  static const Color _greenSoft =
      Color(0xFFF3FAF6);
  static const Color _soft =
      Color(0xFFF7F9F8);
  static const Color _text =
      Color(0xFF0B0F14);
  static const Color _muted =
      Color(0xFF667085);
  static const Color _muted2 =
      Color(0xFF98A2B3);
  static const Color _amber =
      Color(0xFFF59E0B);

  String _s(dynamic value) =>
      '${value ?? ''}'.trim();

  DateTime? _date(dynamic value) {
    final raw = _s(value);
    if (raw.isEmpty) return null;
    return DateTime.tryParse(
      raw.replaceFirst(' ', 'T'),
    );
  }

  String _teamName(
    Map<String, dynamic> team,
  ) {
    final value = _s(
      team['name'] ??
          team['team_name'] ??
          team['title'],
    );
    return value.isEmpty
        ? 'Команда'
        : value;
  }

  String _eventTitle(
    Map<String, dynamic> event,
  ) {
    final value =
        _s(event['title']);
    return value.isEmpty
        ? 'Занятие'
        : value;
  }

  String _eventLocation(
    Map<String, dynamic> event,
  ) =>
      _s(
        event['location'] ??
            event['venue'] ??
            event['address'] ??
            event['place'],
      );

  String _two(int value) =>
      value.toString().padLeft(2, '0');

  String _time(DateTime? date) {
    if (date == null) return '—';
    return '${_two(date.hour)}:${_two(date.minute)}';
  }

  List<Map<String, dynamic>>
      get _todayEvents {
    final now = DateTime.now();

    return events.where((event) {
      final date = _date(
        event['start_at'] ??
            event['date'] ??
            event['event_date'],
      );

      return date != null &&
          date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
    }).toList()
      ..sort((a, b) {
        final da = _date(
              a['start_at'] ??
                  a['date'] ??
                  a['event_date'],
            ) ??
            DateTime(2100);
        final db = _date(
              b['start_at'] ??
                  b['date'] ??
                  b['event_date'],
            ) ??
            DateTime(2100);
        return da.compareTo(db);
      });
  }

  TextStyle _title(
    double legacySize, {
    Color color = _text,
  }) {
    if (legacySize >= 16) {
      return AppTypography.screenTitle(color: color);
    }
    if (legacySize >= 14) {
      return AppTypography.sectionTitle(color: color);
    }
    if (legacySize >= 11.5) {
      return AppTypography.itemTitle(color: color);
    }
    return AppTypography.menuTitle(color: color);
  }

  TextStyle _body(
    double legacySize, {
    Color color = _muted,
    FontWeight weight = FontWeight.w400,
  }) {
    final base = legacySize >= 9.2
        ? AppTypography.secondary(color: color)
        : AppTypography.caption(color: color);
    return base.copyWith(fontWeight: weight);
  }

  @override
  Widget build(BuildContext context) {
    final today = _todayEvents;

    return LayoutBuilder(
      builder: (context, constraints) {
        final phone =
            constraints.maxWidth < 720;

        final shortcuts =
            <_CabinetShortcut>[
          _CabinetShortcut(
            'Мой профиль тренера',
            'Карточка · документы · здоровье',
            _greenDark,
            onOpenProfile,
          ),
          _CabinetShortcut(
            'Тренеры',
            'Коллеги · профили · чат',
            _green,
            onOpenTrainers,
          ),
          _CabinetShortcut(
            'Расписание',
            'Занятия и события',
            _green,
            onOpenCalendar,
          ),
          _CabinetShortcut(
            'Планы-конспекты',
            'Мои планы команд',
            _greenDark,
            onOpenPlans,
          ),
          _CabinetShortcut(
            'Тестирование',
            'Сессии и игроки',
            _amber,
            onOpenTesting,
          ),
          _CabinetShortcut(
            'Команды и локации',
            'Мои назначения',
            _greenDark,
            onOpenTeams,
          ),
          _CabinetShortcut(
            'Чаты',
            'Игроки · родители · тренеры',
            _green,
            onOpenChats,
          ),
          _CabinetShortcut(
            'Отчёты',
            'Сессии и аналитика',
            _amber,
            onOpenReports,
          ),
        ];

        return ListView(
          padding: EdgeInsets.fromLTRB(
            phone ? 10 : 16,
            phone ? 10 : 14,
            phone ? 10 : 16,
            28,
          ),
          children: <Widget>[
            Row(
              children: <Widget>[
                _Dots(color: _green),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Мой кабинет тренера',
                        style: AppTypography.screenTitle(
                          color: _text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        clubName,
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,
                        style:
                            _body(9.2),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _MetricStrip(
              items: <_CabinetMetric>[
                _CabinetMetric(
                  '${teams.length}',
                  'Команды',
                  _green,
                ),
                _CabinetMetric(
                  '${today.length}',
                  'Сегодня',
                  _greenDark,
                ),
                _CabinetMetric(
                  '${latestPlans.length}',
                  'Планы',
                  _amber,
                ),
                _CabinetMetric(
                  '${players.length}',
                  'Игроки',
                  _green,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Рабочие разделы',
              style: _title(11.7),
            ),
            const SizedBox(height: 7),
            GridView.builder(
              shrinkWrap: true,
              physics:
                  const NeverScrollableScrollPhysics(),
              gridDelegate:
                  SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount:
                    phone ? 2 : 3,
                crossAxisSpacing: 7,
                mainAxisSpacing: 7,
                childAspectRatio:
                    phone ? 1.75 : 2.45,
              ),
              itemCount:
                  shortcuts.length,
              itemBuilder:
                  (context, index) =>
                      _ShortcutCard(
                item: shortcuts[index],
                titleStyle: _title,
                bodyStyle: _body,
              ),
            ),
            const SizedBox(height: 14),
            if (!phone)
              Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: _TodayPanel(
                      events: today,
                      eventTitle:
                          _eventTitle,
                      eventDate: (event) =>
                          _date(
                        event['start_at'] ??
                            event['date'] ??
                            event[
                                'event_date'],
                      ),
                      eventLocation:
                          _eventLocation,
                      timeLabel: _time,
                      titleStyle: _title,
                      bodyStyle: _body,
                      onOpen:
                          onOpenCalendar,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: _TeamsPanel(
                      teams: teams,
                      teamName:
                          _teamName,
                      titleStyle: _title,
                      bodyStyle: _body,
                      onOpen: onOpenTeams,
                    ),
                  ),
                ],
              )
            else ...<Widget>[
              _TodayPanel(
                events: today,
                eventTitle:
                    _eventTitle,
                eventDate: (event) =>
                    _date(
                  event['start_at'] ??
                      event['date'] ??
                      event[
                          'event_date'],
                ),
                eventLocation:
                    _eventLocation,
                timeLabel: _time,
                titleStyle: _title,
                bodyStyle: _body,
                onOpen: onOpenCalendar,
              ),
              const SizedBox(height: 8),
              _TeamsPanel(
                teams: teams,
                teamName: _teamName,
                titleStyle: _title,
                bodyStyle: _body,
                onOpen: onOpenTeams,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _CabinetMetric {
  final String value;
  final String label;
  final Color color;

  const _CabinetMetric(
    this.value,
    this.label,
    this.color,
  );
}

class _CabinetShortcut {
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _CabinetShortcut(
    this.title,
    this.subtitle,
    this.color,
    this.onTap,
  );
}

class _Dots extends StatelessWidget {
  final Color color;

  const _Dots({
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize:
          MainAxisSize.min,
      children: <Widget>[
        _Dot(
          color: color,
          size: 3.2,
          opacity: .32,
        ),
        const SizedBox(width: 3),
        _Dot(
          color: color,
          size: 4.2,
          opacity: .55,
        ),
        const SizedBox(width: 3),
        _Dot(
          color: color,
          size: 5.2,
          opacity: .78,
        ),
        const SizedBox(width: 3),
        _Dot(
          color: color,
          size: 6.2,
          opacity: 1,
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  final double size;
  final double opacity;

  const _Dot({
    required this.color,
    required this.size,
    required this.opacity,
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

class _MetricStrip extends StatelessWidget {
  final List<_CabinetMetric> items;

  const _MetricStrip({
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 53,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 5,
      ),
      decoration: BoxDecoration(
        color: TrainerCabinetPanel._soft,
        borderRadius:
            BorderRadius.circular(9),
      ),
      child: Row(
        children: <Widget>[
          for (int i = 0;
              i < items.length;
              i++) ...<Widget>[
            Expanded(
              child: Column(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    items[i].value,
                    style: AppTypography.itemTitle(
                      color: TrainerCabinetPanel._text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    items[i].label,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style: AppTypography.commentMeta(
                      color: TrainerCabinetPanel._muted2,
                    ).copyWith(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            if (i !=
                items.length - 1)
              Container(
                width: 1,
                height: 22,
                color:
                    Colors.white,
              ),
          ],
        ],
      ),
    );
  }
}

class _ShortcutCard extends StatelessWidget {
  final _CabinetShortcut item;
  final TextStyle Function(
    double size, {
    Color color,
  }) titleStyle;
  final TextStyle Function(
    double size, {
    Color color,
    FontWeight weight,
  }) bodyStyle;

  const _ShortcutCard({
    required this.item,
    required this.titleStyle,
    required this.bodyStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: TrainerCabinetPanel._soft,
      borderRadius:
          BorderRadius.circular(9),
      child: InkWell(
        onTap: item.onTap,
        borderRadius:
            BorderRadius.circular(9),
        child: Padding(
          padding:
              const EdgeInsets.all(9),
          child: Row(
            children: <Widget>[
              _Dot(
                color: item.color,
                size: 6,
                opacity: 1,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment
                          .center,
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: <Widget>[
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style:
                          titleStyle(9.8),
                    ),
                    const SizedBox(
                      height: 2,
                    ),
                    Text(
                      item.subtitle,
                      maxLines: 1,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style:
                          bodyStyle(7.9),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodayPanel extends StatelessWidget {
  final List<Map<String, dynamic>>
      events;
  final String Function(
    Map<String, dynamic>,
  ) eventTitle;
  final DateTime? Function(
    Map<String, dynamic>,
  ) eventDate;
  final String Function(
    Map<String, dynamic>,
  ) eventLocation;
  final String Function(DateTime?)
      timeLabel;
  final TextStyle Function(
    double size, {
    Color color,
  }) titleStyle;
  final TextStyle Function(
    double size, {
    Color color,
    FontWeight weight,
  }) bodyStyle;
  final VoidCallback onOpen;

  const _TodayPanel({
    required this.events,
    required this.eventTitle,
    required this.eventDate,
    required this.eventLocation,
    required this.timeLabel,
    required this.titleStyle,
    required this.bodyStyle,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                'Сегодня',
                style: titleStyle(11.5),
              ),
              const Spacer(),
              InkWell(
                onTap: onOpen,
                child: Text(
                  'Расписание',
                  style: bodyStyle(
                    8.5,
                    color:
                        TrainerCabinetPanel
                            ._greenDark,
                    weight:
                        FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (events.isEmpty)
            Container(
              height: 72,
              alignment:
                  Alignment.centerLeft,
              padding:
                  const EdgeInsets
                      .symmetric(
                horizontal: 10,
              ),
              decoration:
                  BoxDecoration(
                color:
                    TrainerCabinetPanel
                        ._soft,
                borderRadius:
                    BorderRadius.circular(
                  9,
                ),
              ),
              child: Text(
                'На сегодня занятий нет',
                style:
                    bodyStyle(9),
              ),
            )
          else
            ...events.take(4).map(
              (event) => Container(
                margin:
                    const EdgeInsets.only(
                  bottom: 5,
                ),
                padding:
                    const EdgeInsets.all(
                  9,
                ),
                decoration:
                    BoxDecoration(
                  color:
                      TrainerCabinetPanel
                          ._soft,
                  borderRadius:
                      BorderRadius.circular(
                    9,
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    SizedBox(
                      width: 38,
                      child: Text(
                        timeLabel(
                          eventDate(event),
                        ),
                        style:
                            titleStyle(9.4),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const _Dot(
                      color:
                          TrainerCabinetPanel
                              ._green,
                      size: 5,
                      opacity: 1,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: <Widget>[
                          Text(
                            eventTitle(event),
                            maxLines: 1,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            style:
                                titleStyle(9.3),
                          ),
                          if (eventLocation(
                                  event)
                              .isNotEmpty) ...<
                              Widget>[
                            const SizedBox(
                              height: 2,
                            ),
                            Text(
                              eventLocation(
                                event,
                              ),
                              maxLines: 1,
                              overflow:
                                  TextOverflow
                                      .ellipsis,
                              style:
                                  bodyStyle(
                                7.8,
                              ),
                            ),
                          ],
                        ],
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

class _TeamsPanel extends StatelessWidget {
  final List<Map<String, dynamic>>
      teams;
  final String Function(
    Map<String, dynamic>,
  ) teamName;
  final TextStyle Function(
    double size, {
    Color color,
  }) titleStyle;
  final TextStyle Function(
    double size, {
    Color color,
    FontWeight weight,
  }) bodyStyle;
  final VoidCallback onOpen;

  const _TeamsPanel({
    required this.teams,
    required this.teamName,
    required this.titleStyle,
    required this.bodyStyle,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                'Мои команды и локации',
                style: titleStyle(11.5),
              ),
              const Spacer(),
              InkWell(
                onTap: onOpen,
                child: Text(
                  'Открыть',
                  style: bodyStyle(
                    8.5,
                    color:
                        TrainerCabinetPanel
                            ._greenDark,
                    weight:
                        FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (teams.isEmpty)
            Container(
              height: 72,
              alignment:
                  Alignment.centerLeft,
              padding:
                  const EdgeInsets
                      .symmetric(
                horizontal: 10,
              ),
              decoration:
                  BoxDecoration(
                color:
                    TrainerCabinetPanel
                        ._soft,
                borderRadius:
                    BorderRadius.circular(
                  9,
                ),
              ),
              child: Text(
                'Команды пока не назначены',
                style:
                    bodyStyle(9),
              ),
            )
          else
            ...teams.take(5).map(
              (team) => Container(
                margin:
                    const EdgeInsets.only(
                  bottom: 5,
                ),
                height: 43,
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 9,
                ),
                decoration:
                    BoxDecoration(
                  color:
                      TrainerCabinetPanel
                          ._soft,
                  borderRadius:
                      BorderRadius.circular(
                    9,
                  ),
                ),
                child: Row(
                  children: <Widget>[
                    const _Dot(
                      color:
                          TrainerCabinetPanel
                              ._greenDark,
                      size: 5,
                      opacity: 1,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        teamName(team),
                        maxLines: 1,
                        overflow:
                            TextOverflow
                                .ellipsis,
                        style:
                            titleStyle(9.3),
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
