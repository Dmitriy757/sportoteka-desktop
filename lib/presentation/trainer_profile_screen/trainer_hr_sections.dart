// lib/presentation/trainer_profile_screen/trainer_hr_sections.dart
//
// Кадровые разделы профиля тренера:
// - посещаемость самого тренера;
// - здоровье / медицинские допуски;
// - документы.
//
// Desktop/tablet:
// добавление, просмотр, редактирование и удаление открываются справа
// в рабочей области, без modal/dialog.
//
// Mobile:
// правый редактор заменяет содержимое раздела до закрытия.

import 'dart:convert';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart' as fp;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'package:sportoteka/core/theme/app_typography.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';

enum TrainerHrSectionKind {
  attendance,
  health,
  documents,
}

class TrainerHrSectionPanel extends StatefulWidget {
  final TrainerHrSectionKind kind;
  final int trainerId;
  final int clubId;
  final String clubName;
  final String trainerName;
  final List<Map<String, dynamic>> teams;
  final List<Map<String, dynamic>> schedule;
  final bool allowEdit;
  final VoidCallback? onChanged;

  const TrainerHrSectionPanel({
    super.key,
    required this.kind,
    required this.trainerId,
    required this.clubId,
    required this.clubName,
    required this.trainerName,
    required this.teams,
    required this.schedule,
    required this.allowEdit,
    this.onChanged,
  });

  @override
  State<TrainerHrSectionPanel> createState() =>
      _TrainerHrSectionPanelState();
}

class _TrainerHrSectionPanelState
    extends State<TrainerHrSectionPanel> {
  static const String _apiBase =
      'https://sportotekaapp.ru/api/trainer_hr';

  bool _loading = true;
  String? _error;
  int _actorUserId = 0;

  List<Map<String, dynamic>> _attendance =
      <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _medical =
      <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _documents =
      <Map<String, dynamic>>[];

  late DateTime _cursor;
  late DateTime _selectedDay;

  Map<String, dynamic>? _selectedRecord;
  Map<String, dynamic>? _selectedAttendanceEvent;
  bool _createNew = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDay = DateTime(now.year, now.month, now.day);
    _cursor = DateTime(now.year, now.month, 1);
    _bootstrap();
  }

  @override
  void didUpdateWidget(
    covariant TrainerHrSectionPanel oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.trainerId != widget.trainerId ||
        oldWidget.clubId != widget.clubId ||
        oldWidget.kind != widget.kind) {
      _selectedRecord = null;
      _selectedAttendanceEvent = null;
      _createNew = false;
      _bootstrap();
    }
  }

  Future<void> _bootstrap() async {
    try {
      _actorUserId = await PrefUtils.getUserId() ?? 0;
    } catch (_) {
      _actorUserId = 0;
    }

    await _load();
  }

  String _s(dynamic value) {
    final text = '${value ?? ''}'.trim();
    return text == 'null' ? '' : text;
  }

  int _i(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(_s(value)) ?? 0;
  }

  dynamic _decode(String body) {
    try {
      final object = body.indexOf('{');
      final list = body.indexOf('[');

      if (object < 0 && list < 0) return null;

      final start = object >= 0 &&
              (list < 0 || object < list)
          ? object
          : list;

      return jsonDecode(body.substring(start));
    } catch (_) {
      return null;
    }
  }

  List<Map<String, dynamic>> _records(dynamic data) {
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }

    if (data is Map) {
      for (final key in const <String>[
        'records',
        'items',
        'rows',
        'data',
      ]) {
        final value = data[key];
        if (value is List) {
          return value
              .whereType<Map>()
              .map(
                (e) => Map<String, dynamic>.from(e),
              )
              .toList();
        }
      }
    }

    return const <Map<String, dynamic>>[];
  }

  DateTime? _date(dynamic value) {
    final raw = _s(value);
    if (raw.isEmpty) return null;
    return DateTime.tryParse(
      raw.replaceFirst(' ', 'T'),
    );
  }

  String _ymd(DateTime value) {
    String two(int x) =>
        x.toString().padLeft(2, '0');

    return '${value.year}-${two(value.month)}-${two(value.day)}';
  }

  String _dateLabel(DateTime? value) {
    if (value == null) return '—';

    String two(int x) =>
        x.toString().padLeft(2, '0');

    return '${two(value.day)}.${two(value.month)}.${value.year}';
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year &&
      a.month == b.month &&
      a.day == b.day;

  int _teamId(Map<String, dynamic> team) => _i(
        team['id'] ??
            team['team_id'] ??
            team['teamId'],
      );

  String _teamName(
    Map<String, dynamic> team,
  ) {
    final value = _s(
      team['name'] ??
          team['team_name'] ??
          team['title'],
    );
    return value.isEmpty ? 'Команда' : value;
  }

  String _eventTitle(
    Map<String, dynamic> event,
  ) {
    final value = _s(event['title']);
    return value.isEmpty ? 'Занятие' : value;
  }

  int _eventId(
    Map<String, dynamic> event,
  ) =>
      _i(
        event['id'] ??
            event['event_id'] ??
            event['calendar_event_id'],
      );

  int _eventTeamId(
    Map<String, dynamic> event,
  ) =>
      _i(
        event['team_id'] ??
            event['teamId'],
      );

  String _eventLocation(
    Map<String, dynamic> event,
  ) =>
      _s(
        event['location'] ??
            event['venue'] ??
            event['address'] ??
            event['place'],
      );

  DateTime? _eventDate(
    Map<String, dynamic> event,
  ) =>
      _date(
        event['start_at'] ??
            event['date'] ??
            event['event_date'],
      );

  Future<void> _load() async {
    if (!mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      switch (widget.kind) {
        case TrainerHrSectionKind.attendance:
          final uri = Uri.parse(
            '$_apiBase/get_trainer_attendance.php',
          ).replace(
            queryParameters: <String, String>{
              'trainer_id': '${widget.trainerId}',
              'club_id': '${widget.clubId}',
            },
          );

          final response = await http
              .get(uri)
              .timeout(
                const Duration(seconds: 15),
              );

          _attendance =
              _records(_decode(response.body));
          break;

        case TrainerHrSectionKind.health:
          final uri = Uri.parse(
            '$_apiBase/get_trainer_medical_records.php',
          ).replace(
            queryParameters: <String, String>{
              'trainer_id': '${widget.trainerId}',
              'club_id': '${widget.clubId}',
            },
          );

          final response = await http
              .get(uri)
              .timeout(
                const Duration(seconds: 15),
              );

          _medical =
              _records(_decode(response.body));
          break;

        case TrainerHrSectionKind.documents:
          final uri = Uri.parse(
            '$_apiBase/get_trainer_documents.php',
          ).replace(
            queryParameters: <String, String>{
              'trainer_id': '${widget.trainerId}',
              'club_id': '${widget.clubId}',
            },
          );

          final response = await http
              .get(uri)
              .timeout(
                const Duration(seconds: 15),
              );

          _documents =
              _records(_decode(response.body));
          break;
      }

      if (!mounted) return;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Не удалось загрузить данные: $e';
      });
    }
  }

  void _closeRightPane() {
    if (!mounted) return;
    setState(() {
      _selectedRecord = null;
      _selectedAttendanceEvent = null;
      _createNew = false;
    });
  }

  Future<void> _afterSaved() async {
    _closeRightPane();
    await _load();
    widget.onChanged?.call();
  }

  Map<String, dynamic>? _attendanceForEvent(
    Map<String, dynamic> event,
  ) {
    final eventId = _eventId(event);
    final eventDate = _eventDate(event);
    final teamId = _eventTeamId(event);
    final title =
        _eventTitle(event).trim().toLowerCase();

    for (final row in _attendance) {
      final rowEventId = _i(row['event_id']);

      if (eventId > 0 &&
          rowEventId > 0 &&
          eventId == rowEventId) {
        return row;
      }

      final rowDate =
          _date(row['attendance_date']);

      if (eventDate != null &&
          rowDate != null &&
          _sameDay(eventDate, rowDate) &&
          _i(row['team_id']) == teamId &&
          _s(row['event_title'])
                  .trim()
                  .toLowerCase() ==
              title) {
        return row;
      }
    }

    return null;
  }

  List<Map<String, dynamic>>
      _scheduledForSelectedDay() {
    return widget.schedule.where((event) {
      final date = _eventDate(event);
      return date != null &&
          _sameDay(date, _selectedDay);
    }).toList()
      ..sort((a, b) {
        final da =
            _eventDate(a) ?? DateTime(2100);
        final db =
            _eventDate(b) ?? DateTime(2100);
        return da.compareTo(db);
      });
  }

  String _attendanceStatus(dynamic raw) {
    switch (_s(raw).toLowerCase()) {
      case 'present':
        return 'Присутствовал';
      case 'absent':
        return 'Отсутствовал';
      case 'late':
        return 'Опоздал';
      case 'replacement':
        return 'Замена';
      case 'cancelled':
        return 'Отменено';
      default:
        return 'Не отмечено';
    }
  }

  Color _attendanceColor(dynamic raw) {
    switch (_s(raw).toLowerCase()) {
      case 'present':
        return _HrColors.green;
      case 'absent':
        return _HrColors.red;
      case 'late':
        return _HrColors.amber;
      case 'replacement':
        return _HrColors.blue;
      case 'cancelled':
        return _HrColors.muted2;
      default:
        return _HrColors.muted2;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const ColoredBox(
        color: Colors.white,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: _HrColors.green,
          ),
        ),
      );
    }

    if (_error != null) {
      return _HrEmpty(
        title: 'Не удалось загрузить раздел',
        text: _error!,
        action: 'Повторить',
        onTap: _load,
      );
    }

    switch (widget.kind) {
      case TrainerHrSectionKind.attendance:
        return _attendanceSection();
      case TrainerHrSectionKind.health:
        return _recordsSection(
          records: _medical,
          isMedical: true,
        );
      case TrainerHrSectionKind.documents:
        return _recordsSection(
          records: _documents,
          isMedical: false,
        );
    }
  }

  Widget _attendanceSection() {
    final selectedEvents =
        _scheduledForSelectedDay();

    final marks = <String, int>{};

    for (final event in widget.schedule) {
      final date = _eventDate(event);
      if (date == null) continue;

      final key = _HrCalendar.key(date);
      marks[key] = (marks[key] ?? 0) + 1;
    }

    for (final row in _attendance) {
      final date =
          _date(row['attendance_date']);
      if (date == null) continue;

      final key = _HrCalendar.key(date);
      marks[key] = math.max(
        marks[key] ?? 0,
        1,
      ).toInt();
    }

    final attendancePane =
        _selectedAttendanceEvent == null
            ? null
            : _HrAttendanceEditor(
                trainerId: widget.trainerId,
                clubId: widget.clubId,
                actorUserId: _actorUserId,
                event:
                    _selectedAttendanceEvent!,
                existing:
                    _attendanceForEvent(
                  _selectedAttendanceEvent!,
                ),
                allowEdit: widget.allowEdit,
                onClose: _closeRightPane,
                onSaved: _afterSaved,
              );

    return LayoutBuilder(
      builder: (context, constraints) {
        final phone =
            constraints.maxWidth < 720;

        if (phone &&
            attendancePane != null) {
          return attendancePane;
        }

        final calendar =
            _HrCalendarPane(
          cursor: _cursor,
          selected: _selectedDay,
          marks: marks,
          subtitle:
              '${selectedEvents.length} ${_HrCalendar.eventWord(selectedEvents.length)}',
          onSelect: (date) {
            setState(() {
              _selectedDay = DateTime(
                date.year,
                date.month,
                date.day,
              );
              _selectedAttendanceEvent = null;

              if (_cursor.year != date.year ||
                  _cursor.month !=
                      date.month) {
                _cursor = DateTime(
                  date.year,
                  date.month,
                  1,
                );
              }
            });
          },
          onShiftMonth: (delta) {
            setState(() {
              _cursor = DateTime(
                _cursor.year,
                _cursor.month + delta,
                1,
              );
            });
          },
          onToday: () {
            final now = DateTime.now();
            setState(() {
              _selectedDay = DateTime(
                now.year,
                now.month,
                now.day,
              );
              _cursor = DateTime(
                now.year,
                now.month,
                1,
              );
            });
          },
        );

        final dayPane =
            _HrAttendanceDayPane(
          selected: _selectedDay,
          events: selectedEvents,
          attendanceForEvent:
              _attendanceForEvent,
          statusLabel:
              _attendanceStatus,
          statusColor:
              _attendanceColor,
          eventTitle: _eventTitle,
          eventDate: _eventDate,
          eventLocation:
              _eventLocation,
          allowEdit: widget.allowEdit,
          onOpen: (event) {
            setState(() {
              _selectedAttendanceEvent =
                  Map<String, dynamic>.from(
                event,
              );
            });
          },
        );

        if (phone) {
          return ListView(
            padding:
                const EdgeInsets.fromLTRB(
              8,
              8,
              8,
              24,
            ),
            children: <Widget>[
              SizedBox(
                height: 410,
                child: calendar,
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: math.max(
                  260.0,
                  160.0 +
                      selectedEvents.length *
                          74.0,
                ).toDouble(),
                child: dayPane,
              ),
            ],
          );
        }

        final right = attendancePane ??
            dayPane;

        return Padding(
          padding:
              const EdgeInsets.fromLTRB(
            8,
            8,
            8,
            8,
          ),
          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
            children: <Widget>[
              SizedBox(
                width: math
                    .min(
                      460.0,
                      math.max(
                        350.0,
                        constraints.maxWidth *
                            .40,
                      ),
                    )
                    .toDouble(),
                child: calendar,
              ),
              const SizedBox(width: 10),
              Expanded(child: right),
            ],
          ),
        );
      },
    );
  }

  Widget _recordsSection({
    required List<Map<String, dynamic>>
        records,
    required bool isMedical,
  }) {
    final editorOpen =
        _createNew || _selectedRecord != null;

    final pane = editorOpen
        ? _HrRecordEditor(
            isMedical: isMedical,
            trainerId: widget.trainerId,
            clubId: widget.clubId,
            actorUserId: _actorUserId,
            record: _createNew
                ? null
                : _selectedRecord,
            allowEdit: widget.allowEdit,
            onClose: _closeRightPane,
            onSaved: _afterSaved,
          )
        : null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final phone =
            constraints.maxWidth < 720;

        if (phone && pane != null) {
          return pane;
        }

        final content =
            _HrRecordsList(
          title: isMedical
              ? 'Здоровье тренера'
              : 'Документы тренера',
          subtitle: isMedical
              ? 'Медосмотры, допуски, ограничения и медицинские файлы'
              : 'Лицензии, дипломы, сертификаты, договоры и кадровые документы',
          records: records,
          isMedical: isMedical,
          allowEdit: widget.allowEdit,
          dateOf: (record) => _date(
            isMedical
                ? record['record_date']
                : record['issue_date'],
          ),
          validUntilOf: (record) =>
              _date(record['valid_until']),
          onAdd: widget.allowEdit
              ? () {
                  setState(() {
                    _createNew = true;
                    _selectedRecord = null;
                  });
                }
              : null,
          onOpen: (record) {
            setState(() {
              _createNew = false;
              _selectedRecord =
                  Map<String, dynamic>.from(
                record,
              );
            });
          },
        );

        if (pane == null || phone) {
          return content;
        }

        return Row(
          children: <Widget>[
            Expanded(child: content),
            Container(
              width: 1,
              color: _HrColors.line,
            ),
            SizedBox(
              width: math.min(
                430.0,
                constraints.maxWidth * .42,
              ).toDouble(),
              child: pane,
            ),
          ],
        );
      },
    );
  }
}

class _HrColors {
  static const Color text =
      Color(0xFF0B0F14);
  static const Color muted =
      Color(0xFF667085);
  static const Color muted2 =
      Color(0xFF98A2B3);
  static const Color line =
      Color(0xFFEEF1EF);
  static const Color soft =
      Color(0xFFF7F9F8);
  static const Color green =
      Color(0xFF00A750);
  static const Color greenDark =
      Color(0xFF067A46);
  static const Color greenSoft =
      Color(0xFFF3FAF6);
  static const Color amber =
      Color(0xFFF59E0B);
  static const Color red =
      Color(0xFFD92D20);
  static const Color blue =
      Color(0xFF2563EB);
}

class _HrText {
  static TextStyle title(
    double size, {
    Color color = _HrColors.text,
    FontWeight weight = FontWeight.w600,
  }) =>
      AppTypography.custom(
        size: size,
        weight: weight,
        color: color,
        height: 1.18,
        letterSpacing: 0,
      );

  static TextStyle body(
    double size, {
    Color color = _HrColors.text,
    FontWeight weight = FontWeight.w400,
    double height = 1.28,
  }) =>
      AppTypography.custom(
        size: size,
        weight: weight,
        color: color,
        height: height,
        letterSpacing: 0,
      );
}

class _HrDot extends StatelessWidget {
  final Color color;
  final double size;
  final double opacity;

  const _HrDot({
    required this.color,
    this.size = 5,
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

class _HrDots extends StatelessWidget {
  final Color color;

  const _HrDots({
    this.color = _HrColors.green,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _HrDot(
          color: color,
          size: 3.2,
          opacity: .32,
        ),
        const SizedBox(width: 3),
        _HrDot(
          color: color,
          size: 4.2,
          opacity: .55,
        ),
        const SizedBox(width: 3),
        _HrDot(
          color: color,
          size: 5.5,
          opacity: .78,
        ),
        const SizedBox(width: 3),
        _HrDot(
          color: color,
          size: 6.2,
        ),
      ],
    );
  }
}

class _HrAction extends StatelessWidget {
  final String title;
  final Color color;
  final VoidCallback? onTap;
  final bool filled;

  const _HrAction({
    required this.title,
    required this.color,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled
          ? color
          : color.withOpacity(.07),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Opacity(
          opacity: onTap == null ? .45 : 1,
          child: Container(
            height: 34,
            padding:
                const EdgeInsets.symmetric(
              horizontal: 10,
            ),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: <Widget>[
                _HrDot(
                  color: filled
                      ? Colors.white
                      : color,
                  size: 4.4,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style: _HrText.body(
                      9.2,
                      color: filled
                          ? Colors.white
                          : color,
                      weight: FontWeight.w600,
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
}

class _HrCalendar {
  static String key(DateTime date) =>
      '${date.year}-${date.month}-${date.day}';

  static String monthTitle(DateTime date) {
    const months = <String>[
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

    return '${months[date.month - 1]} ${date.year}';
  }

  static String dateLabel(DateTime date) {
    const months = <String>[
      'янв',
      'фев',
      'мар',
      'апр',
      'май',
      'июн',
      'июл',
      'авг',
      'сен',
      'окт',
      'ноя',
      'дек',
    ];

    return '${date.day} ${months[date.month - 1]}';
  }

  static String eventWord(int count) {
    final mod10 = count % 10;
    final mod100 = count % 100;

    if (mod10 == 1 && mod100 != 11) {
      return 'событие';
    }

    if (mod10 >= 2 &&
        mod10 <= 4 &&
        (mod100 < 10 || mod100 >= 20)) {
      return 'события';
    }

    return 'событий';
  }
}

class _HrCalendarPane extends StatelessWidget {
  final DateTime cursor;
  final DateTime selected;
  final Map<String, int> marks;
  final String subtitle;
  final ValueChanged<DateTime> onSelect;
  final ValueChanged<int> onShiftMonth;
  final VoidCallback onToday;

  const _HrCalendarPane({
    required this.cursor,
    required this.selected,
    required this.marks,
    required this.subtitle,
    required this.onSelect,
    required this.onShiftMonth,
    required this.onToday,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: Column(
        children: <Widget>[
          SizedBox(
            height: 58,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 11,
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _HrColors.soft,
                      borderRadius:
                          BorderRadius.circular(11),
                    ),
                    child: const Center(
                      child: _HrDots(),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          _HrCalendar.monthTitle(
                            cursor,
                          ),
                          style: _HrText.title(14),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${_HrCalendar.dateLabel(selected)} · $subtitle',
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style: _HrText.body(
                            9.4,
                            color:
                                _HrColors.muted,
                            weight:
                                FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _HrSquareButton(
                    icon:
                        Icons.chevron_left_rounded,
                    onTap: () =>
                        onShiftMonth(-1),
                  ),
                  const SizedBox(width: 4),
                  _HrSquareButton(
                    icon:
                        Icons.chevron_right_rounded,
                    onTap: () =>
                        onShiftMonth(1),
                  ),
                  const SizedBox(width: 4),
                  _HrSquareButton(
                    icon: Icons.today_rounded,
                    onTap: onToday,
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                10,
                8,
                10,
                12,
              ),
              child: _HrMonthGrid(
                cursor: cursor,
                selected: selected,
                marks: marks,
                onSelect: onSelect,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HrSquareButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HrSquareButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _HrColors.soft,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 29,
          height: 29,
          child: Icon(
            icon,
            size: 15,
            color: _HrColors.greenDark,
          ),
        ),
      ),
    );
  }
}

class _HrMonthGrid extends StatelessWidget {
  final DateTime cursor;
  final DateTime selected;
  final Map<String, int> marks;
  final ValueChanged<DateTime> onSelect;

  const _HrMonthGrid({
    required this.cursor,
    required this.selected,
    required this.marks,
    required this.onSelect,
  });

  bool _same(DateTime a, DateTime b) =>
      a.year == b.year &&
      a.month == b.month &&
      a.day == b.day;

  @override
  Widget build(BuildContext context) {
    const weekdays = <String>[
      'Пн',
      'Вт',
      'Ср',
      'Чт',
      'Пт',
      'Сб',
      'Вс',
    ];

    final first =
        DateTime(cursor.year, cursor.month, 1);

    final count =
        DateTime(
          cursor.year,
          cursor.month + 1,
          0,
        ).day;

    final previousCount =
        DateTime(
          cursor.year,
          cursor.month,
          0,
        ).day;

    final leading = first.weekday - 1;
    final total =
        ((leading + count + 6) ~/ 7) * 7;
    final rows = total ~/ 7;

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 6.0;

        final header = Row(
          children: weekdays
              .map(
                (label) => Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: _HrText.body(
                        8.8,
                        color: _HrColors.muted2,
                        weight:
                            FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        );

        final available =
            constraints.maxHeight - 28;
        final cellHeight = math.max(
          34.0,
          math.min(
            56.0,
            (available -
                    gap * (rows - 1)) /
                rows,
          ),
        );

        final gridRows = <Widget>[];

        for (int row = 0;
            row < rows;
            row++) {
          final cells = <Widget>[];

          for (int col = 0;
              col < 7;
              col++) {
            final index = row * 7 + col;
            final n =
                index - leading + 1;

            late DateTime date;
            var inMonth = true;

            if (n < 1) {
              date = DateTime(
                cursor.year,
                cursor.month - 1,
                previousCount + n,
              );
              inMonth = false;
            } else if (n > count) {
              date = DateTime(
                cursor.year,
                cursor.month + 1,
                n - count,
              );
              inMonth = false;
            } else {
              date = DateTime(
                cursor.year,
                cursor.month,
                n,
              );
            }

            final mark =
                marks[_HrCalendar.key(date)] ?? 0;

            cells.add(
              Expanded(
                child: SizedBox(
                  height:
                      cellHeight.toDouble(),
                  child: _HrDayCell(
                    date: date,
                    inMonth: inMonth,
                    selected:
                        _same(date, selected),
                    today: _same(
                      date,
                      DateTime.now(),
                    ),
                    count: mark,
                    onTap: () =>
                        onSelect(date),
                  ),
                ),
              ),
            );

            if (col != 6) {
              cells.add(
                const SizedBox(width: gap),
              );
            }
          }

          gridRows.add(
            Row(children: cells),
          );

          if (row != rows - 1) {
            gridRows.add(
              const SizedBox(height: gap),
            );
          }
        }

        return Column(
          children: <Widget>[
            header,
            const SizedBox(height: 8),
            Expanded(
              child: Column(
                mainAxisAlignment:
                    MainAxisAlignment.start,
                children: gridRows,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HrDayCell extends StatelessWidget {
  final DateTime date;
  final bool inMonth;
  final bool selected;
  final bool today;
  final int count;
  final VoidCallback onTap;

  const _HrDayCell({
    required this.date,
    required this.inMonth,
    required this.selected,
    required this.today,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? _HrColors.greenSoft
          : inMonth
              ? _HrColors.soft
              : Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          children: <Widget>[
            Center(
              child: Text(
                '${date.day}',
                style: _HrText.body(
                  10.2,
                  color: selected
                      ? _HrColors.greenDark
                      : inMonth
                          ? today
                              ? _HrColors.green
                              : _HrColors.text
                          : _HrColors.muted2,
                  weight: FontWeight.w600,
                ),
              ),
            ),
            if (count > 0)
              Positioned(
                top: 3,
                right: 3,
                child: Container(
                  constraints:
                      const BoxConstraints(
                    minWidth: 14,
                  ),
                  height: 14,
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _HrColors.green,
                    borderRadius:
                        BorderRadius.circular(99),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$count',
                    style: _HrText.body(
                      7.5,
                      color: Colors.white,
                      weight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                ),
              ),
            if (selected)
              const Positioned(
                left: 0,
                right: 0,
                bottom: 4,
                child: Center(
                  child: _HrDot(
                    color: _HrColors.green,
                    size: 5,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _HrAttendanceDayPane
    extends StatelessWidget {
  final DateTime selected;
  final List<Map<String, dynamic>> events;
  final Map<String, dynamic>? Function(
    Map<String, dynamic>,
  ) attendanceForEvent;
  final String Function(dynamic) statusLabel;
  final Color Function(dynamic) statusColor;
  final String Function(
    Map<String, dynamic>,
  ) eventTitle;
  final DateTime? Function(
    Map<String, dynamic>,
  ) eventDate;
  final String Function(
    Map<String, dynamic>,
  ) eventLocation;
  final bool allowEdit;
  final ValueChanged<Map<String, dynamic>>
      onOpen;

  const _HrAttendanceDayPane({
    required this.selected,
    required this.events,
    required this.attendanceForEvent,
    required this.statusLabel,
    required this.statusColor,
    required this.eventTitle,
    required this.eventDate,
    required this.eventLocation,
    required this.allowEdit,
    required this.onOpen,
  });

  String _time(DateTime? value) {
    if (value == null) return '—';
    String two(int x) =>
        x.toString().padLeft(2, '0');
    return '${two(value.hour)}:${two(value.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: Column(
        children: <Widget>[
          SizedBox(
            height: 54,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 11,
              ),
              child: Row(
                children: <Widget>[
                  const _HrDots(
                    color:
                        _HrColors.greenDark,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Посещаемость · ${_HrCalendar.dateLabel(selected)}',
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style: _HrText.title(12.8),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: events.isEmpty
                ? const _HrEmpty(
                    title:
                        'Занятий в этот день нет',
                    text:
                        'Когда в расписании появится событие, здесь можно будет отметить присутствие тренера.',
                  )
                : ListView.separated(
                    padding:
                        const EdgeInsets.fromLTRB(
                      10,
                      4,
                      10,
                      12,
                    ),
                    itemCount: events.length,
                    separatorBuilder:
                        (_, __) =>
                            const SizedBox(
                      height: 5,
                    ),
                    itemBuilder:
                        (context, index) {
                      final event =
                          events[index];
                      final attendance =
                          attendanceForEvent(
                        event,
                      );
                      final status =
                          (attendance == null ? null : attendance['status']) ??
                              'not_marked';
                      final color =
                          statusColor(status);
                      final location =
                          eventLocation(event);

                      return Material(
                        color: _HrColors.soft,
                        borderRadius:
                            BorderRadius.circular(
                          9,
                        ),
                        child: InkWell(
                          onTap: allowEdit
                              ? () =>
                                  onOpen(event)
                              : null,
                          borderRadius:
                              BorderRadius.circular(
                            9,
                          ),
                          child: Padding(
                            padding:
                                const EdgeInsets
                                    .all(10),
                            child: Row(
                              children: <Widget>[
                                SizedBox(
                                  width: 42,
                                  child: Text(
                                    _time(
                                      eventDate(
                                        event,
                                      ),
                                    ),
                                    style:
                                        _HrText.title(
                                      10.4,
                                    ),
                                  ),
                                ),
                                const SizedBox(
                                  width: 6,
                                ),
                                _HrDot(
                                  color: color,
                                  size: 6,
                                ),
                                const SizedBox(
                                  width: 8,
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment
                                            .start,
                                    children: <Widget>[
                                      Text(
                                        eventTitle(
                                          event,
                                        ),
                                        maxLines: 1,
                                        overflow:
                                            TextOverflow
                                                .ellipsis,
                                        style:
                                            _HrText.title(
                                          10.5,
                                        ),
                                      ),
                                      const SizedBox(
                                        height: 3,
                                      ),
                                      Text(
                                        [
                                          if (location
                                              .isNotEmpty)
                                            location,
                                          statusLabel(
                                            status,
                                          ),
                                        ].join(
                                          ' · ',
                                        ),
                                        maxLines: 1,
                                        overflow:
                                            TextOverflow
                                                .ellipsis,
                                        style:
                                            _HrText.body(
                                          8.9,
                                          color:
                                              _HrColors
                                                  .muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (allowEdit)
                                  Text(
                                    attendance == null
                                        ? 'Отметить'
                                        : 'Изменить',
                                    style:
                                        _HrText.body(
                                      8.8,
                                      color: _HrColors
                                          .greenDark,
                                      weight:
                                          FontWeight
                                              .w600,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _HrAttendanceEditor
    extends StatefulWidget {
  final int trainerId;
  final int clubId;
  final int actorUserId;
  final Map<String, dynamic> event;
  final Map<String, dynamic>? existing;
  final bool allowEdit;
  final VoidCallback onClose;
  final Future<void> Function() onSaved;

  const _HrAttendanceEditor({
    required this.trainerId,
    required this.clubId,
    required this.actorUserId,
    required this.event,
    required this.existing,
    required this.allowEdit,
    required this.onClose,
    required this.onSaved,
  });

  @override
  State<_HrAttendanceEditor> createState() =>
      _HrAttendanceEditorState();
}

class _HrAttendanceEditorState
    extends State<_HrAttendanceEditor> {
  static const String _url =
      'https://sportotekaapp.ru/api/trainer_hr/save_trainer_attendance.php';

  late String _status;
  late final TextEditingController _lateC;
  late final TextEditingController _noteC;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _status =
        '${(widget.existing == null ? null : widget.existing!['status']) ?? 'present'}';

    _lateC = TextEditingController(
      text:
          '${(widget.existing == null ? null : widget.existing!['minutes_late']) ?? 0}',
    );
    _noteC = TextEditingController(
      text:
          '${(widget.existing == null ? null : widget.existing!['note']) ?? ''}',
    );
  }

  @override
  void dispose() {
    _lateC.dispose();
    _noteC.dispose();
    super.dispose();
  }

  int _i(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(
          '${value ?? ''}'.trim(),
        ) ??
        0;
  }

  String _s(dynamic value) =>
      '${value ?? ''}'.trim();

  DateTime? _date(dynamic value) {
    final raw = _s(value);
    if (raw.isEmpty) return null;
    return DateTime.tryParse(
      raw.replaceFirst(' ', 'T'),
    );
  }

  String _ymd(DateTime value) {
    String two(int x) =>
        x.toString().padLeft(2, '0');
    return '${value.year}-${two(value.month)}-${two(value.day)}';
  }

  Future<void> _save() async {
    if (_saving || !widget.allowEdit) return;

    final date = _date(
      widget.event['start_at'] ??
          widget.event['date'] ??
          widget.event['event_date'],
    );

    if (date == null) return;

    setState(() => _saving = true);

    try {
      final response = await http.post(
        Uri.parse(_url),
        headers: const <String, String>{
          'Content-Type':
              'application/json; charset=utf-8',
        },
        body: jsonEncode(
          <String, dynamic>{
            'record_id':
                _i((widget.existing == null ? null : widget.existing!['id'])),
            'trainer_id': widget.trainerId,
            'club_id': widget.clubId,
            'team_id': _i(
              widget.event['team_id'] ??
                  widget.event['teamId'],
            ),
            'event_id': _i(
              widget.event['id'] ??
                  widget.event['event_id'],
            ),
            'attendance_date':
                _ymd(date),
            'event_title': _s(
              widget.event['title'],
            ).isEmpty
                ? 'Занятие'
                : _s(
                    widget.event['title'],
                  ),
            'location': _s(
              widget.event['location'] ??
                  widget.event['venue'] ??
                  widget.event['address'],
            ),
            'status': _status,
            'minutes_late':
                int.tryParse(_lateC.text) ??
                    0,
            'note': _noteC.text.trim(),
            'created_by':
                widget.actorUserId,
          },
        ),
      );

      final data =
          jsonDecode(response.body);

      if (data is! Map ||
          data['success'] != true) {
        throw Exception(
          data is Map
              ? '${data['message'] ?? 'Ошибка сохранения'}'
              : 'Ошибка сохранения',
        );
      }

      await widget.onSaved();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Не удалось сохранить: $e',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const variants = <(String, String, Color)>[
      (
        'present',
        'Присутствовал',
        _HrColors.green,
      ),
      (
        'absent',
        'Отсутствовал',
        _HrColors.red,
      ),
      (
        'late',
        'Опоздал',
        _HrColors.amber,
      ),
      (
        'replacement',
        'Замена',
        _HrColors.blue,
      ),
      (
        'cancelled',
        'Отменено',
        _HrColors.muted2,
      ),
    ];

    return ColoredBox(
      color: Colors.white,
      child: Column(
        children: <Widget>[
          _HrEditorHeader(
            title: 'Посещение тренера',
            subtitle:
                _s(widget.event['title'])
                        .isEmpty
                    ? 'Занятие'
                    : _s(
                        widget.event['title'],
                      ),
            color: _HrColors.green,
            onClose: widget.onClose,
          ),
          Expanded(
            child: ListView(
              padding:
                  const EdgeInsets.fromLTRB(
                12,
                12,
                12,
                16,
              ),
              children: <Widget>[
                Text(
                  'Статус',
                  style: _HrText.body(
                    9,
                    color: _HrColors.muted,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: variants
                      .map(
                        (item) =>
                            _HrChoiceChip(
                          label: item.$2,
                          color: item.$3,
                          active:
                              _status ==
                              item.$1,
                          onTap: () =>
                              setState(
                            () =>
                                _status =
                                    item.$1,
                          ),
                        ),
                      )
                      .toList(),
                ),
                if (_status == 'late') ...<
                    Widget>[
                  const SizedBox(height: 12),
                  _HrField(
                    controller: _lateC,
                    label:
                        'Опоздание, минут',
                  ),
                ],
                const SizedBox(height: 12),
                _HrField(
                  controller: _noteC,
                  label: 'Комментарий',
                  maxLines: 5,
                ),
              ],
            ),
          ),
          _HrEditorFooter(
            saving: _saving,
            allowEdit: widget.allowEdit,
            onClose: widget.onClose,
            onSave: _save,
          ),
        ],
      ),
    );
  }
}

class _HrChoiceChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool active;
  final VoidCallback onTap;

  const _HrChoiceChip({
    required this.label,
    required this.color,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active
          ? color.withOpacity(.09)
          : _HrColors.soft,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 7,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _HrDot(
                color: color,
                size: active ? 5.5 : 4.2,
                opacity: active ? 1 : .65,
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: _HrText.body(
                  8.8,
                  color: active
                      ? color
                      : _HrColors.muted,
                  weight: active
                      ? FontWeight.w600
                      : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HrRecordsList extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Map<String, dynamic>> records;
  final bool isMedical;
  final bool allowEdit;
  final DateTime? Function(
    Map<String, dynamic>,
  ) dateOf;
  final DateTime? Function(
    Map<String, dynamic>,
  ) validUntilOf;
  final VoidCallback? onAdd;
  final ValueChanged<Map<String, dynamic>>
      onOpen;

  const _HrRecordsList({
    required this.title,
    required this.subtitle,
    required this.records,
    required this.isMedical,
    required this.allowEdit,
    required this.dateOf,
    required this.validUntilOf,
    required this.onAdd,
    required this.onOpen,
  });

  String _s(dynamic value) =>
      '${value ?? ''}'.trim();

  String _date(DateTime? value) {
    if (value == null) return '—';
    String two(int x) =>
        x.toString().padLeft(2, '0');

    return '${two(value.day)}.${two(value.month)}.${value.year}';
  }

  Color _expiryColor(
    DateTime? value,
  ) {
    if (value == null) {
      return _HrColors.muted2;
    }

    final now = DateTime.now();
    final today =
        DateTime(now.year, now.month, now.day);
    final limit = DateTime(
      value.year,
      value.month,
      value.day,
    );

    final days =
        limit.difference(today).inDays;

    if (days < 0) return _HrColors.red;
    if (days <= 30) return _HrColors.amber;
    return _HrColors.green;
  }

  @override
  Widget build(BuildContext context) {
    final expiring = records.where((record) {
      final date = validUntilOf(record);
      if (date == null) return false;

      final days =
          date.difference(DateTime.now()).inDays;

      return days >= 0 && days <= 30;
    }).length;

    final expired = records.where((record) {
      final date = validUntilOf(record);
      return date != null &&
          date.isBefore(DateTime.now());
    }).length;

    final withFile = records.where(
      (record) =>
          _s(record['file_url']).isNotEmpty,
    ).length;

    return ColoredBox(
      color: Colors.white,
      child: Column(
        children: <Widget>[
          Padding(
            padding:
                const EdgeInsets.fromLTRB(
              12,
              10,
              12,
              8,
            ),
            child: Row(
              children: <Widget>[
                _HrDots(
                  color: isMedical
                      ? _HrColors.red
                      : _HrColors.greenDark,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style:
                            _HrText.title(13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,
                        style: _HrText.body(
                          8.9,
                          color:
                              _HrColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (allowEdit)
                  _HrAction(
                    title: isMedical
                        ? 'Добавить запись'
                        : 'Добавить документ',
                    color: _HrColors.green,
                    onTap: onAdd,
                  ),
              ],
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.fromLTRB(
              12,
              2,
              12,
              9,
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: _HrMetric(
                    value:
                        '${records.length}',
                    label: 'Всего',
                    color:
                        _HrColors.green,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _HrMetric(
                    value: '$withFile',
                    label: 'С файлом',
                    color:
                        _HrColors.greenDark,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _HrMetric(
                    value: '$expiring',
                    label: 'Истекают',
                    color:
                        _HrColors.amber,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _HrMetric(
                    value: '$expired',
                    label: 'Просрочено',
                    color: _HrColors.red,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: records.isEmpty
                ? _HrEmpty(
                    title: isMedical
                        ? 'Медицинских записей пока нет'
                        : 'Документов пока нет',
                    text: isMedical
                        ? 'Добавьте медосмотр, допуск, ограничение или медицинскую справку.'
                        : 'Добавьте лицензию, диплом, сертификат, договор или другой документ тренера.',
                  )
                : ListView.separated(
                    padding:
                        const EdgeInsets.fromLTRB(
                      12,
                      2,
                      12,
                      18,
                    ),
                    itemCount: records.length,
                    separatorBuilder:
                        (_, __) =>
                            const SizedBox(
                      height: 4,
                    ),
                    itemBuilder:
                        (context, index) {
                      final record =
                          records[index];
                      final type = _s(
                        isMedical
                            ? record[
                                'record_type']
                            : record[
                                'document_type'],
                      );
                      final title =
                          _s(record['title']);
                      final valid =
                          validUntilOf(record);
                      final color =
                          _expiryColor(valid);

                      return Material(
                        color: _HrColors.soft,
                        borderRadius:
                            BorderRadius.circular(
                          9,
                        ),
                        child: InkWell(
                          onTap: () =>
                              onOpen(record),
                          borderRadius:
                              BorderRadius.circular(
                            9,
                          ),
                          child: Padding(
                            padding:
                                const EdgeInsets
                                    .fromLTRB(
                              10,
                              9,
                              9,
                              9,
                            ),
                            child: Row(
                              children: <Widget>[
                                _HrDot(
                                  color: color,
                                  size: 6,
                                ),
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
                                        title.isEmpty
                                            ? (type
                                                    .isEmpty
                                                ? 'Запись'
                                                : type)
                                            : title,
                                        maxLines: 1,
                                        overflow:
                                            TextOverflow
                                                .ellipsis,
                                        style:
                                            _HrText.title(
                                          10.5,
                                        ),
                                      ),
                                      const SizedBox(
                                        height: 3,
                                      ),
                                      Text(
                                        [
                                          if (type
                                              .isNotEmpty)
                                            type,
                                          _date(
                                            dateOf(
                                              record,
                                            ),
                                          ),
                                          if (valid !=
                                              null)
                                            'до ${_date(valid)}',
                                        ].join(
                                          ' · ',
                                        ),
                                        maxLines: 1,
                                        overflow:
                                            TextOverflow
                                                .ellipsis,
                                        style:
                                            _HrText.body(
                                          8.8,
                                          color:
                                              _HrColors
                                                  .muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (_s(record[
                                        'file_url'])
                                    .isNotEmpty) ...<
                                    Widget>[
                                  const SizedBox(
                                    width: 6,
                                  ),
                                  const _HrDot(
                                    color:
                                        _HrColors
                                            .greenDark,
                                    size: 4,
                                    opacity: .7,
                                  ),
                                ],
                                const SizedBox(
                                  width: 7,
                                ),
                                const Icon(
                                  Icons
                                      .chevron_right_rounded,
                                  size: 16,
                                  color:
                                      _HrColors
                                          .muted2,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _HrMetric extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _HrMetric({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 45,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 8,
      ),
      decoration: BoxDecoration(
        color: _HrColors.soft,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: <Widget>[
          _HrDot(
            color: color,
            size: 5,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  value,
                  style: _HrText.title(10.7),
                ),
                const SizedBox(height: 1),
                Text(
                  label,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: _HrText.body(
                    8,
                    color:
                        _HrColors.muted2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HrRecordEditor extends StatefulWidget {
  final bool isMedical;
  final int trainerId;
  final int clubId;
  final int actorUserId;
  final Map<String, dynamic>? record;
  final bool allowEdit;
  final VoidCallback onClose;
  final Future<void> Function() onSaved;

  const _HrRecordEditor({
    required this.isMedical,
    required this.trainerId,
    required this.clubId,
    required this.actorUserId,
    required this.record,
    required this.allowEdit,
    required this.onClose,
    required this.onSaved,
  });

  @override
  State<_HrRecordEditor> createState() =>
      _HrRecordEditorState();
}

class _HrRecordEditorState
    extends State<_HrRecordEditor> {
  static const String _base =
      'https://sportotekaapp.ru/api/trainer_hr';

  late final TextEditingController _typeC;
  late final TextEditingController _titleC;
  late final TextEditingController _numberC;
  late final TextEditingController _issuedByC;
  late final TextEditingController _dateC;
  late final TextEditingController _validUntilC;
  late final TextEditingController _statusC;
  late final TextEditingController _noteC;

  fp.PlatformFile? _pickedFile;
  bool _saving = false;
  bool _deleting = false;
  bool _deleteArmed = false;
  bool _editing = false;
  bool _removeFile = false;

  bool get _isNew => widget.record == null;

  String _s(dynamic value) =>
      '${value ?? ''}'.trim();

  int _i(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(_s(value)) ?? 0;
  }

  @override
  void initState() {
    super.initState();

    final row = widget.record;

    _typeC = TextEditingController(
      text: _s(
        widget.isMedical
            ? (row == null ? null : row['record_type'])
            : (row == null ? null : row['document_type']),
      ),
    );

    _titleC = TextEditingController(
      text: _s((row == null ? null : row['title'])),
    );

    _numberC = TextEditingController(
      text: _s((row == null ? null : row['document_number'])),
    );

    _issuedByC = TextEditingController(
      text: _s((row == null ? null : row['issued_by'])),
    );

    _dateC = TextEditingController(
      text: _s(
        widget.isMedical
            ? (row == null ? null : row['record_date'])
            : (row == null ? null : row['issue_date']),
      ),
    );

    _validUntilC = TextEditingController(
      text: _s((row == null ? null : row['valid_until'])),
    );

    _statusC = TextEditingController(
      text: _s((row == null ? null : row['status'])),
    );

    _noteC = TextEditingController(
      text: _s((row == null ? null : row['note'])),
    );

    if (_isNew) {
      final now = DateTime.now();
      String two(int value) => value.toString().padLeft(2, '0');
      _dateC.text = '${now.year}-${two(now.month)}-${two(now.day)}';
      if (_typeC.text.trim().isEmpty) {
        _typeC.text = widget.isMedical ? 'Осмотр' : 'Документ';
      }
      if (widget.isMedical && _statusC.text.trim().isEmpty) {
        _statusC.text = 'Действует';
      }
    }

    _editing = _isNew;
  }

  @override
  void dispose() {
    _typeC.dispose();
    _titleC.dispose();
    _numberC.dispose();
    _issuedByC.dispose();
    _dateC.dispose();
    _validUntilC.dispose();
    _statusC.dispose();
    _noteC.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    if (!_editing) return;

    final result =
        await fp.FilePicker.pickFiles(
      type: fp.FileType.custom,
      allowedExtensions: const <String>[
        'pdf',
        'doc',
        'docx',
        'xls',
        'xlsx',
        'ppt',
        'pptx',
        'jpg',
        'jpeg',
        'png',
        'webp',
        'heic',
      ],
      allowMultiple: false,
      withData: false,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final picked = result.files.first;

    if (!mounted) return;

    setState(() {
      _pickedFile = picked;
      _removeFile = false;
    });
  }

  Future<http.MultipartFile?>
      _multipartFile() async {
    final picked = _pickedFile;
    if (picked == null) return null;

    if (picked.path != null &&
        picked.path!.isNotEmpty) {
      return http.MultipartFile.fromPath(
        'file',
        picked.path!,
        filename: picked.name,
      );
    }

    final bytes = picked.bytes;
    if (bytes != null && bytes.isNotEmpty) {
      return http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: picked.name,
      );
    }

    // На macOS/iOS FilePicker обычно возвращает path.
    // Если конкретная платформа не вернула ни path, ни bytes,
    // не отправляем пустой MultipartFile.
    return null;
  }

  Future<void> _save() async {
    if (_saving ||
        !_editing ||
        !widget.allowEdit) {
      return;
    }

    if (_titleC.text.trim().isEmpty) {
      _snack('Укажите название');
      return;
    }

    setState(() => _saving = true);

    try {
      final endpoint = widget.isMedical
          ? 'save_trainer_medical_record.php'
          : 'save_trainer_document.php';

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_base/$endpoint'),
      );

      request.fields.addAll(
        <String, String>{
          'record_id':
              '${_i((widget.record == null ? null : widget.record!['id']))}',
          'trainer_id':
              '${widget.trainerId}',
          'club_id': '${widget.clubId}',
          'created_by':
              '${widget.actorUserId}',
          'title': _titleC.text.trim(),
          'valid_until':
              _validUntilC.text.trim(),
          'note': _noteC.text.trim(),
          'remove_file':
              _removeFile ? '1' : '0',
          if (widget.isMedical) ...<
              String, String>{
            'record_type':
                _typeC.text.trim(),
            'record_date':
                _dateC.text.trim(),
            'status':
                _statusC.text.trim(),
          } else ...<String, String>{
            'document_type':
                _typeC.text.trim(),
            'document_number':
                _numberC.text.trim(),
            'issued_by':
                _issuedByC.text.trim(),
            'issue_date':
                _dateC.text.trim(),
          },
        },
      );

      final file =
          await _multipartFile();
      if (file != null) {
        request.files.add(file);
      }

      final streamed =
          await request.send();

      final body =
          await streamed.stream
              .bytesToString();

      final data = jsonDecode(body);

      if (data is! Map ||
          data['success'] != true) {
        throw Exception(
          data is Map
              ? '${data['message'] ?? 'Ошибка сохранения'}'
              : 'Ошибка сохранения',
        );
      }

      await widget.onSaved();
    } catch (e) {
      _snack('Не удалось сохранить: $e');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _delete() async {
    if (_deleting ||
        _isNew ||
        !widget.allowEdit) {
      return;
    }

    // Удаление подтверждается прямо в правой панели:
    // первый клик включает подтверждение, второй выполняет удаление.
    if (!_deleteArmed) {
      setState(() => _deleteArmed = true);
      return;
    }

    setState(() => _deleting = true);

    try {
      final endpoint = widget.isMedical
          ? 'delete_trainer_medical_record.php'
          : 'delete_trainer_document.php';

      final response = await http.post(
        Uri.parse('$_base/$endpoint'),
        headers: const <String, String>{
          'Content-Type':
              'application/json; charset=utf-8',
        },
        body: jsonEncode(
          <String, dynamic>{
            'record_id':
                _i((widget.record == null ? null : widget.record!['id'])),
            'trainer_id':
                widget.trainerId,
          },
        ),
      );

      final data =
          jsonDecode(response.body);

      if (data is! Map ||
          data['success'] != true) {
        throw Exception(
          data is Map
              ? '${data['message'] ?? 'Ошибка удаления'}'
              : 'Ошибка удаления',
        );
      }

      await widget.onSaved();
    } catch (e) {
      _snack('Не удалось удалить: $e');
      if (mounted) {
        setState(() => _deleteArmed = false);
      }
    } finally {
      if (mounted) {
        setState(
          () => _deleting = false,
        );
      }
    }
  }

  Future<void> _openFile() async {
    final url =
        _s((widget.record == null ? null : widget.record!['file_url']));

    if (url.isEmpty) {
      _snack('Файл не прикреплён');
      return;
    }

    try {
      final response = await http.post(
        Uri.parse(
          '$_base/preview_trainer_file.php',
        ),
        headers: const <String, String>{
          'Content-Type':
              'application/json; charset=utf-8',
        },
        body: jsonEncode(
          <String, dynamic>{
            'kind': widget.isMedical
                ? 'medical'
                : 'document',
            'record_id':
                _i((widget.record == null ? null : widget.record!['id'])),
            'trainer_id':
                widget.trainerId,
          },
        ),
      );

      final data =
          jsonDecode(response.body);

      final preview = data is Map
          ? _s(data['preview_url'])
          : '';

      final target =
          preview.isNotEmpty
              ? preview
              : url;

      final uri = Uri.tryParse(target);
      if (uri == null) {
        throw Exception(
          'Некорректная ссылка',
        );
      }

      final ok = await launchUrl(
        uri,
        mode:
            LaunchMode.externalApplication,
      );

      if (!ok) {
        throw Exception(
          'Не удалось открыть файл',
        );
      }
    } catch (e) {
      _snack('$e');
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(content: Text(text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fileUrl =
        _s((widget.record == null ? null : widget.record!['file_url']));
    final fileName =
        _pickedFile?.name ??
            _s((widget.record == null ? null : widget.record!['file_name']));

    return ColoredBox(
      color: Colors.white,
      child: Column(
        children: <Widget>[
          _HrEditorHeader(
            title: widget.isMedical
                ? (_isNew
                    ? 'Новая медицинская запись'
                    : 'Медицинская запись')
                : (_isNew
                    ? 'Новый документ'
                    : 'Документ тренера'),
            subtitle: _titleC.text.trim().isEmpty
                ? (_typeC.text.trim().isEmpty
                    ? 'Профиль тренера'
                    : _typeC.text.trim())
                : _titleC.text.trim(),
            color: widget.isMedical
                ? _HrColors.red
                : _HrColors.greenDark,
            onClose: widget.onClose,
          ),
          Expanded(
            child: ListView(
              padding:
                  const EdgeInsets.fromLTRB(
                12,
                10,
                12,
                18,
              ),
              children: <Widget>[
                if (!_isNew &&
                    !_editing) ...<Widget>[
                  _HrReadRow(
                    label: 'Тип',
                    value:
                        _typeC.text.trim(),
                  ),
                  _HrReadRow(
                    label: 'Название',
                    value:
                        _titleC.text.trim(),
                  ),
                  if (!widget.isMedical) ...<
                      Widget>[
                    _HrReadRow(
                      label: 'Номер',
                      value:
                          _numberC.text.trim(),
                    ),
                    _HrReadRow(
                      label: 'Кем выдан',
                      value:
                          _issuedByC.text.trim(),
                    ),
                  ],
                  _HrReadRow(
                    label: widget.isMedical
                        ? 'Дата записи'
                        : 'Дата выдачи',
                    value:
                        _dateC.text.trim(),
                  ),
                  _HrReadRow(
                    label:
                        'Действует до',
                    value:
                        _validUntilC.text
                                .trim()
                                .isEmpty
                            ? 'Без срока'
                            : _validUntilC.text
                                .trim(),
                  ),
                  if (widget.isMedical)
                    _HrReadRow(
                      label: 'Статус',
                      value:
                          _statusC.text.trim(),
                    ),
                  const SizedBox(height: 12),
                  Text(
                    'Комментарий',
                    style: _HrText.body(
                      8.8,
                      color:
                          _HrColors.muted2,
                      weight:
                          FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _noteC.text.trim().isEmpty
                        ? 'Комментарий не указан.'
                        : _noteC.text.trim(),
                    style: _HrText.body(
                      10,
                      color:
                          _HrColors.muted,
                    ),
                  ),
                  if (fileUrl.isNotEmpty) ...<
                      Widget>[
                    const SizedBox(height: 14),
                    _HrAction(
                      title: fileName.isEmpty
                          ? 'Открыть файл'
                          : 'Открыть $fileName',
                      color:
                          _HrColors.green,
                      onTap: _openFile,
                    ),
                  ],
                ] else ...<Widget>[
                  _HrField(
                    controller: _typeC,
                    label: widget.isMedical
                        ? 'Тип записи'
                        : 'Тип документа',
                    hint: widget.isMedical
                        ? 'Осмотр / допуск / справка'
                        : 'Лицензия / диплом / сертификат',
                  ),
                  _HrField(
                    controller: _titleC,
                    label: 'Название',
                  ),
                  if (!widget.isMedical) ...<
                      Widget>[
                    _HrField(
                      controller: _numberC,
                      label:
                          'Номер документа',
                    ),
                    _HrField(
                      controller:
                          _issuedByC,
                      label: 'Кем выдан',
                    ),
                  ],
                  _HrField(
                    controller: _dateC,
                    label: widget.isMedical
                        ? 'Дата записи'
                        : 'Дата выдачи',
                    hint: 'YYYY-MM-DD',
                  ),
                  _HrField(
                    controller:
                        _validUntilC,
                    label: 'Действует до',
                    hint:
                        'YYYY-MM-DD или пусто',
                  ),
                  if (widget.isMedical)
                    _HrField(
                      controller:
                          _statusC,
                      label: 'Статус',
                      hint:
                          'Допущен / ограничен / контроль',
                    ),
                  _HrField(
                    controller: _noteC,
                    label: 'Комментарий',
                    maxLines: 5,
                  ),
                  const SizedBox(height: 4),
                  Material(
                    color: _HrColors.soft,
                    borderRadius:
                        BorderRadius.circular(9),
                    child: InkWell(
                      onTap: _pickFile,
                      borderRadius:
                          BorderRadius.circular(
                        9,
                      ),
                      child: Padding(
                        padding:
                            const EdgeInsets
                                .all(10),
                        child: Row(
                          children: <Widget>[
                            const _HrDot(
                              color:
                                  _HrColors
                                      .green,
                              size: 5.5,
                            ),
                            const SizedBox(
                              width: 8,
                            ),
                            Expanded(
                              child: Text(
                                fileName.isEmpty
                                    ? 'Прикрепить файл'
                                    : fileName,
                                maxLines: 1,
                                overflow:
                                    TextOverflow
                                        .ellipsis,
                                style:
                                    _HrText.body(
                                  9.5,
                                  weight:
                                      FontWeight
                                          .w600,
                                ),
                              ),
                            ),
                            Text(
                              _pickedFile == null
                                  ? 'Выбрать'
                                  : 'Заменить',
                              style:
                                  _HrText.body(
                                8.7,
                                color:
                                    _HrColors
                                        .greenDark,
                                weight:
                                    FontWeight
                                        .w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (fileUrl.isNotEmpty &&
                      _pickedFile == null) ...<
                      Widget>[
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () =>
                          setState(
                        () => _removeFile =
                            !_removeFile,
                      ),
                      child: Padding(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          vertical: 5,
                        ),
                        child: Row(
                          children: <Widget>[
                            _HrDot(
                              color: _removeFile
                                  ? _HrColors
                                      .red
                                  : _HrColors
                                      .muted2,
                              size: 4.5,
                            ),
                            const SizedBox(
                              width: 6,
                            ),
                            Text(
                              _removeFile
                                  ? 'Файл будет удалён'
                                  : 'Удалить текущий файл',
                              style:
                                  _HrText.body(
                                8.6,
                                color:
                                    _removeFile
                                        ? _HrColors
                                            .red
                                        : _HrColors
                                            .muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
          if (!_isNew &&
              !_editing &&
              widget.allowEdit)
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                12,
                8,
                12,
                10,
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: _HrAction(
                      title: _deleteArmed
                          ? 'Подтвердить удаление'
                          : 'Удалить',
                      color: _HrColors.red,
                      onTap:
                          _deleting ? null : _delete,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: _HrAction(
                      title: 'Редактировать',
                      color:
                          _HrColors.green,
                      filled: true,
                      onTap: () => setState(
                        () {
                          _deleteArmed = false;
                          _editing = true;
                        },
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            _HrEditorFooter(
              saving: _saving,
              allowEdit:
                  widget.allowEdit,
              onClose: _editing &&
                      !_isNew
                  ? () => setState(
                        () => _editing = false,
                      )
                  : widget.onClose,
              onSave: _save,
            ),
        ],
      ),
    );
  }
}

class _HrEditorHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onClose;

  const _HrEditorHeader({
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: Padding(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 11,
        ),
        child: Row(
          children: <Widget>[
            _HrDots(color: color),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style: _HrText.title(12.8),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style: _HrText.body(
                      8.8,
                      color: _HrColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            Material(
              color: _HrColors.soft,
              borderRadius:
                  BorderRadius.circular(8),
              child: InkWell(
                onTap: onClose,
                borderRadius:
                    BorderRadius.circular(8),
                child: const SizedBox(
                  width: 30,
                  height: 30,
                  child: Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: _HrColors.muted,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HrEditorFooter extends StatelessWidget {
  final bool saving;
  final bool allowEdit;
  final VoidCallback onClose;
  final VoidCallback onSave;

  const _HrEditorFooter({
    required this.saving,
    required this.allowEdit,
    required this.onClose,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        12,
        8,
        12,
        10,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _HrAction(
              title: 'Закрыть',
              color: _HrColors.muted,
              onTap:
                  saving ? null : onClose,
            ),
          ),
          if (allowEdit) ...<Widget>[
            const SizedBox(width: 7),
            Expanded(
              child: _HrAction(
                title: saving
                    ? 'Сохранение...'
                    : 'Сохранить',
                color: _HrColors.green,
                filled: true,
                onTap:
                    saving ? null : onSave,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HrField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final int maxLines;

  const _HrField({
    required this.controller,
    required this.label,
    this.hint,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.only(bottom: 9),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: _HrText.body(
              8.8,
              color: _HrColors.muted,
              weight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          TextField(
            controller: controller,
            maxLines: maxLines,
            style: _HrText.body(10),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: _HrText.body(
                9.5,
                color: _HrColors.muted2,
              ),
              filled: true,
              fillColor: _HrColors.soft,
              contentPadding:
                  const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 9,
              ),
              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              enabledBorder:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              focusedBorder:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HrReadRow extends StatelessWidget {
  final String label;
  final String value;

  const _HrReadRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints:
          const BoxConstraints(
        minHeight: 41,
      ),
      padding:
          const EdgeInsets.symmetric(
        vertical: 7,
      ),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: _HrColors.line,
            width: .55,
          ),
        ),
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 105,
            child: Text(
              label,
              style: _HrText.body(
                8.7,
                color:
                    _HrColors.muted2,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value.trim().isEmpty
                  ? 'Не указано'
                  : value,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow:
                  TextOverflow.ellipsis,
              style: _HrText.body(
                9.7,
                weight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HrEmpty extends StatelessWidget {
  final String title;
  final String text;
  final String? action;
  final VoidCallback? onTap;

  const _HrEmpty({
    required this.title,
    required this.text,
    this.action,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: Center(
        child: Padding(
          padding:
              const EdgeInsets.all(20),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: <Widget>[
              const _HrDots(
                color: _HrColors.muted2,
              ),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: _HrText.title(11),
              ),
              const SizedBox(height: 4),
              Text(
                text,
                textAlign: TextAlign.center,
                style: _HrText.body(
                  9.2,
                  color: _HrColors.muted,
                ),
              ),
              if (action != null &&
                  onTap != null) ...<Widget>[
                const SizedBox(height: 10),
                _HrAction(
                  title: action!,
                  color: _HrColors.green,
                  onTap: onTap,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
