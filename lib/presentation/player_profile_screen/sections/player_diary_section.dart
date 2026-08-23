import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/player_profile_models.dart';
import '../widgets/player_profile_ui.dart';

typedef PlayerDiarySave = Future<void> Function({
  required DateTime entryDate,
  required String authorRole,
  int eventId,
  int rating,
  int mood,
  int fatigue,
  int sleepQuality,
  int pain,
  int rpe,
  String note,
});

typedef PlayerWeekGoalSave = Future<void> Function({
  int goalId,
  required DateTime weekStart,
  String goalText,
  int progress,
  bool isDone,
});

typedef PlayerDiarySidePanel = void Function(
  Widget Function(VoidCallback close) builder,
);

enum _DiaryFilter {
  all,
  training,
  match,
  test,
  health,
  notes,
}

enum _DiaryView { today, feedback, goals, week, calendar, history }

enum _DiaryPeriod { today, week, month, all }

class PlayerDiarySection extends StatefulWidget {
  final PlayerProfileSnapshot data;
  final bool readOnly;
  final int viewerUserId;
  final String viewerRole;
  final bool viewerContextLoading;
  final PlayerDiarySave? onSave;
  final PlayerWeekGoalSave? onSaveGoal;
  final PlayerDiarySidePanel? onOpenSidePanel;

  const PlayerDiarySection({
    super.key,
    required this.data,
    this.readOnly = false,
    this.viewerUserId = 0,
    this.viewerRole = '',
    this.viewerContextLoading = false,
    this.onSave,
    this.onSaveGoal,
    this.onOpenSidePanel,
  });

  @override
  State<PlayerDiarySection> createState() =>
      _PlayerDiarySectionState();
}

class _PlayerDiarySectionState extends State<PlayerDiarySection> {
  final TextEditingController _noteController =
      TextEditingController();

  int _rating = 0;
  int _mood = 0;
  int _fatigue = 0;
  int _sleep = 0;
  int _pain = 0;
  int _rpe = 0;
  bool _saving = false;
  _DiaryFilter _filter = _DiaryFilter.all;
  _DiaryPeriod _historyPeriod = _DiaryPeriod.month;
  _DiaryView _view = _DiaryView.today;

  String _s(dynamic value) => '${value ?? ''}'.trim();

  int _i(dynamic value) =>
      value is num ? value.toInt() : int.tryParse(_s(value)) ?? 0;

  double _d(dynamic value) => value is num
      ? value.toDouble()
      : double.tryParse(_s(value).replaceAll(',', '.')) ?? 0;

  DateTime? _date(dynamic value) =>
      DateTime.tryParse(_s(value).replaceAll(' ', 'T'));

  String get _role {
    final raw = widget.viewerRole.trim().toLowerCase();

    if (raw == 'trainer' || raw == 'тренер') return 'coach';
    if (<String>[
      'club',
      'manager',
      'admin',
      'management',
      'руководитель',
    ].contains(raw)) {
      return 'manager';
    }
    if (<String>[
      'player',
      'user',
      'футболист',
      'игрок',
    ].contains(raw)) {
      return 'player';
    }
    if (raw == 'parent' || raw == 'родитель') return 'parent';

    return raw;
  }

  bool get _isPlayer => _role == 'player';

  bool get _isCoach =>
      _role == 'coach' || _role == 'manager';

  bool get _canEdit =>
      !widget.readOnly &&
      widget.viewerUserId > 0 &&
      (_isPlayer || _isCoach);

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime get _weekStart =>
      _today.subtract(Duration(days: _today.weekday - 1));

  DateTime get _weekEnd =>
      _weekStart.add(const Duration(days: 6));

  bool _sameDay(DateTime? a, DateTime b) =>
      a != null &&
      a.year == b.year &&
      a.month == b.month &&
      a.day == b.day;

  bool _inWeek(DateTime? value) =>
      value != null &&
      !value.isBefore(_weekStart) &&
      value.isBefore(_weekEnd.add(const Duration(days: 1)));

  List<Map<String, dynamic>> get _todayEntries =>
      widget.data.diaryEntries.where((row) {
        return _sameDay(
          _date(
            row['entry_date'] ??
                row['date'] ??
                row['created_at'],
          ),
          _today,
        );
      }).toList();

  Map<String, dynamic>? _todayRoleEntry(String role) {
    for (final row in _todayEntries) {
      final author = _s(row['author_role']).toLowerCase();

      if (role == 'coach') {
        if (author == 'coach' || author == 'manager') {
          return row;
        }
      } else if (author == role) {
        return row;
      }
    }
    return null;
  }

  Map<String, dynamic>? _latestPlayerEntry() {
    final rows = widget.data.diaryEntries.where((row) {
      return _s(row['author_role']).toLowerCase() == 'player';
    }).toList();

    rows.sort((a, b) {
      final aDate = _date(
            a['entry_date'] ?? a['date'] ?? a['created_at'],
          ) ??
          DateTime(1970);
      final bDate = _date(
            b['entry_date'] ?? b['date'] ?? b['created_at'],
          ) ??
          DateTime(1970);
      return bDate.compareTo(aDate);
    });

    return rows.isEmpty ? null : rows.first;
  }

  List<Map<String, dynamic>> get _currentGoals =>
      widget.data.weeklyGoals.where((goal) {
        final start = _date(goal['week_start']);
        return start != null &&
            _sameDay(start, _weekStart) &&
            _i(goal['is_active'] ?? 1) != 0;
      }).toList()
        ..sort(
          (a, b) => _i(a['id']).compareTo(_i(b['id'])),
        );

  Future<void> _saveToday() async {
    if (!_canEdit ||
        widget.onSave == null ||
        _saving) {
      return;
    }

    if (!_isPlayer &&
        _rating <= 0 &&
        _noteController.text.trim().isEmpty) {
      _message('Добавьте оценку или заметку тренера');
      return;
    }

    if (_isPlayer &&
        _rating <= 0 &&
        _mood <= 0 &&
        _fatigue <= 0 &&
        _sleep <= 0 &&
        _pain <= 0 &&
        _rpe <= 0 &&
        _noteController.text.trim().isEmpty) {
      _message('Добавьте самооценку или обратную связь');
      return;
    }

    setState(() => _saving = true);

    try {
      await widget.onSave!(
        entryDate: _today,
        authorRole: _isPlayer
            ? 'player'
            : (_role == 'manager' ? 'manager' : 'coach'),
        rating: _rating,
        mood: _isPlayer ? _mood : 0,
        fatigue: _isPlayer ? _fatigue : 0,
        sleepQuality: _isPlayer ? _sleep : 0,
        pain: _isPlayer ? _pain : 0,
        rpe: _isPlayer ? _rpe : 0,
        note: _noteController.text.trim(),
      );

      if (!mounted) return;

      _noteController.clear();
      setState(() {
        _rating = 0;
        _mood = 0;
        _fatigue = 0;
        _sleep = 0;
        _pain = 0;
        _rpe = 0;
      });

      _message(
        _isPlayer
            ? 'Самооценка сохранена'
            : 'Запись тренера сохранена',
      );
    } catch (error) {
      if (mounted) {
        _message('Не удалось сохранить: $error');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _openQuickEntryPanel() {
    if (!_canEdit || widget.onSave == null) return;

    final openSidePanel = widget.onOpenSidePanel;
    if (openSidePanel == null) {
      _message('Быстрая запись доступна в рабочей панели профиля');
      return;
    }

    openSidePanel(
      (close) => PlayerDiaryQuickEntryPanel(
        isPlayer: _isPlayer,
        authorRole: _isPlayer
            ? 'player'
            : (_role == 'manager' ? 'manager' : 'coach'),
        onClose: close,
        onSave: widget.onSave!,
      ),
    );
  }

  Future<void> _addGoal() async {
    if (!_isCoach || widget.onSaveGoal == null) return;

    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withOpacity(.28),
      builder: (dialogContext) => PpDialogShell(
        title: 'Цель на неделю',
        subtitle: 'Короткая и понятная задача для игрока',
        dotColor: PpColors.amber,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: PpColors.soft,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Формулировка цели',
                style: PpText.caption(
                  size: 9.5,
                  color: PpColors.greenDark,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: controller,
                autofocus: true,
                minLines: 2,
                maxLines: 4,
                cursorColor: PpColors.greenDark,
                style: PpText.body(
                  11,
                  color: PpColors.text,
                  weight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: 'Например: улучшить работу слабой ногой',
                  hintStyle: PpText.body(10.6, color: PpColors.muted2),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.all(11),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(9),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(9),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(9),
                    borderSide: const BorderSide(
                      color: PpColors.green,
                      width: .8,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          PpDialogButton(
            label: 'Отмена',
            onTap: () => Navigator.pop(dialogContext),
          ),
          PpDialogButton(
            label: 'Добавить',
            primary: true,
            onTap: () => Navigator.pop(
              dialogContext,
              controller.text.trim(),
            ),
          ),
        ],
      ),
    );

    controller.dispose();

    if (result == null || result.trim().isEmpty) return;

    try {
      await widget.onSaveGoal!(
        weekStart: _weekStart,
        goalText: result.trim(),
        progress: 0,
        isDone: false,
      );
      if (mounted) _message('Цель добавлена');
    } catch (error) {
      if (mounted) {
        _message('Не удалось добавить цель: $error');
      }
    }
  }

  Future<void> _updateGoal(
    Map<String, dynamic> goal,
    int progress,
  ) async {
    if (!_canEdit || widget.onSaveGoal == null) return;

    try {
      await widget.onSaveGoal!(
        goalId: _i(goal['id']),
        weekStart:
            _date(goal['week_start']) ?? _weekStart,
        goalText: _s(goal['goal_text']),
        progress: progress.clamp(0, 100),
        isDone: progress >= 100,
      );
    } catch (error) {
      if (mounted) {
        _message('Не удалось обновить цель: $error');
      }
    }
  }

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(value),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final todayPlayer = _todayRoleEntry('player');
    final todayCoach = _todayRoleEntry('coach');
    final attention = _attentionItems();

    return Container(
      color: Colors.white,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          _DiaryIntro(
            data: widget.data,
            weekStart: _weekStart,
            weekEnd: _weekEnd,
          ),
          const PpThinDivider(
            margin: EdgeInsets.symmetric(vertical: 12),
          ),
          _DiaryWorkspaceTabs(
            value: _view,
            onChanged: (value) => setState(() => _view = value),
          ),
          const SizedBox(height: 10),
          if (_view == _DiaryView.today) ...[
            _TodaySection(
              data: widget.data,
              today: _today,
              playerEntry: todayPlayer,
              coachEntry: todayCoach,
              attention: attention,
              canEdit: _canEdit,
              onQuickEntry: _openQuickEntryPanel,
            ),
          ],
          if (_view == _DiaryView.feedback)
            _DiaryFeedbackSection(data: widget.data),
          if (_view == _DiaryView.goals)
            _GoalsSection(
              goals: _currentGoals,
              canAdd: _isCoach && !widget.readOnly,
              canUpdate: _canEdit,
              onAdd: _addGoal,
              onUpdate: _updateGoal,
            ),
          if (_view == _DiaryView.week)
            _WeekSummary(
              data: widget.data,
              weekStart: _weekStart,
              weekEnd: _weekEnd,
            ),
          if (_view == _DiaryView.calendar)
            _DiaryCalendarView(
              data: widget.data,
              filter: _filter,
              onFilterChanged: (value) =>
                  setState(() => _filter = value),
            ),
          if (_view == _DiaryView.history) ...[
            _DiaryPeriodBar(
              value: _historyPeriod,
              onChanged: (value) =>
                  setState(() => _historyPeriod = value),
              onCalendar: () =>
                  setState(() => _view = _DiaryView.calendar),
            ),
            const SizedBox(height: 7),
            _DiaryFilters(
              value: _filter,
              onChanged: (value) => setState(() => _filter = value),
            ),
            const SizedBox(height: 8),
            _History(
              data: widget.data,
              filter: _filter,
              from: _historyFrom(_historyPeriod),
              to: _historyTo(_historyPeriod),
            ),
          ],
        ],
      ),
    );
  }

  DateTime? _historyFrom(_DiaryPeriod period) {
    switch (period) {
      case _DiaryPeriod.today:
        return _today;
      case _DiaryPeriod.week:
        return _today.subtract(const Duration(days: 6));
      case _DiaryPeriod.month:
        return _today.subtract(const Duration(days: 29));
      case _DiaryPeriod.all:
        return null;
    }
  }

  DateTime? _historyTo(_DiaryPeriod period) {
    switch (period) {
      case _DiaryPeriod.today:
      case _DiaryPeriod.week:
      case _DiaryPeriod.month:
        return _today;
      case _DiaryPeriod.all:
        return null;
    }
  }

  List<_AttentionItem> _attentionItems() {
    final items = <_AttentionItem>[];
    final entry = _latestPlayerEntry();

    if (entry != null) {
      final pain = _i(entry['pain']);
      final fatigue = _i(entry['fatigue']);
      final sleep = _i(entry['sleep_quality']);
      final rpe = _i(entry['rpe']);
      final mood = _i(entry['mood']);

      if (pain >= 2) {
        items.add(
          _AttentionItem(
            'Боль / дискомфорт $pain/5',
            PpColors.red,
          ),
        );
      }
      if (fatigue >= 4) {
        items.add(
          _AttentionItem(
            'Высокая усталость $fatigue/5',
            PpColors.amber,
          ),
        );
      }
      if (sleep > 0 && sleep <= 2) {
        items.add(
          _AttentionItem(
            'Низкое качество сна $sleep/5',
            PpColors.amber,
          ),
        );
      }
      if (rpe >= 8) {
        items.add(
          _AttentionItem(
            'Высокая нагрузка RPE $rpe/10',
            PpColors.amber,
          ),
        );
      }
      if (mood > 0 && mood <= 2) {
        items.add(
          _AttentionItem(
            'Низкое настроение $mood/5',
            PpColors.amber,
          ),
        );
      }
    }

    if (items.isEmpty) {
      items.add(
        const _AttentionItem(
          'Критических сигналов нет',
          PpColors.green,
        ),
      );
    }

    return items;
  }
}

class _DiaryWorkspaceTabs extends StatelessWidget {
  final _DiaryView value;
  final ValueChanged<_DiaryView> onChanged;

  const _DiaryWorkspaceTabs({
    required this.value,
    required this.onChanged,
  });

  static const labels = <_DiaryView, String>{
    _DiaryView.today: 'Сегодня',
    _DiaryView.feedback: 'Обратная связь',
    _DiaryView.goals: 'Цели',
    _DiaryView.week: 'Неделя',
    _DiaryView.calendar: 'Календарь',
    _DiaryView.history: 'История',
  };

  Color _color(_DiaryView item) {
    switch (item) {
      case _DiaryView.today:
        return PpColors.green;
      case _DiaryView.feedback:
        return PpColors.greenDark;
      case _DiaryView.goals:
        return PpColors.amber;
      case _DiaryView.week:
        return PpColors.greenDark;
      case _DiaryView.calendar:
        return PpColors.green;
      case _DiaryView.history:
        return PpColors.red;
    }
  }

  Widget _tab(_DiaryView item, {double? width}) {
    final active = item == value;
    return Material(
      color: active ? PpColors.greenSoft : PpColors.soft,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: () => onChanged(item),
        borderRadius: BorderRadius.circular(9),
        child: SizedBox(
          width: width,
          height: 40,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                PpDot(
                  color: _color(item),
                  size: active ? 6 : 4.5,
                  glow: active,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    labels[item]!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PpText.body(
                      10.2,
                      color: active
                          ? PpColors.greenDark
                          : PpColors.text,
                      weight: active
                          ? FontWeight.w600
                          : FontWeight.w500,
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

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 5.0;
        final count = labels.length;

        // На широкой рабочей зоне показываем все 5 пунктов одновременно.
        if (constraints.maxWidth >= 760) {
          final itemWidth =
              (constraints.maxWidth - gap * (count - 1)) / count;
          return Row(
            children: [
              for (var i = 0; i < labels.keys.length; i++) ...[
                _tab(
                  labels.keys.elementAt(i),
                  width: itemWidth,
                ),
                if (i != count - 1)
                  const SizedBox(width: gap),
              ],
            ],
          );
        }

        // На узкой ширине ничего не обрезаем: меню прокручивается горизонтально.
        return SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: count,
            separatorBuilder: (_, __) =>
                const SizedBox(width: gap),
            itemBuilder: (_, index) => _tab(
              labels.keys.elementAt(index),
              width: index == 1 ? 132 : index == 4 ? 116 : 104,
            ),
          ),
        );
      },
    );
  }
}

class _DiaryIntro extends StatelessWidget {
  final PlayerProfileSnapshot data;
  final DateTime weekStart;
  final DateTime weekEnd;

  const _DiaryIntro({
    required this.data,
    required this.weekStart,
    required this.weekEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const PpDot.green(size: 7),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Дневник футболиста',
                    style: PpText.title(18),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${DateFormat('dd.MM').format(weekStart)}–'
                    '${DateFormat('dd.MM').format(weekEnd)} · '
                    'состояние, цели и история',
                    style: PpText.body(10.2),
                  ),
                ],
              ),
            ),
            const PpDotCluster(),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final columns = width >= 760 ? 4 : 2;
            final itemWidth =
                (width - (columns - 1) * 8) / columns;

            final values = <_Metric>[
              _Metric(
                'Рейтинг',
                data.compositeRating > 0
                    ? '${data.compositeRating}'
                    : '—',
                PpColors.green,
              ),
              _Metric(
                'Посещаемость',
                '${data.attendancePercent}%',
                PpColors.greenDark,
              ),
              _Metric(
                'Тренер',
                data.coachRatingAverage > 0
                    ? data.coachRatingAverage.toStringAsFixed(1)
                    : '—',
                PpColors.amber,
              ),
              _Metric(
                'Игрок',
                data.selfRatingAverage > 0
                    ? data.selfRatingAverage.toStringAsFixed(1)
                    : '—',
                PpColors.green,
              ),
            ];

            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: values
                  .map(
                    (item) => SizedBox(
                      width: itemWidth,
                      child: PpMetric(
                        label: item.label,
                        value: item.value,
                        dotColor: item.color,
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class _Metric {
  final String label;
  final String value;
  final Color color;

  const _Metric(this.label, this.value, this.color);
}

class _TodaySection extends StatelessWidget {
  final PlayerProfileSnapshot data;
  final DateTime today;
  final Map<String, dynamic>? playerEntry;
  final Map<String, dynamic>? coachEntry;
  final List<_AttentionItem> attention;
  final bool canEdit;
  final VoidCallback onQuickEntry;

  const _TodaySection({
    required this.data,
    required this.today,
    required this.playerEntry,
    required this.coachEntry,
    required this.attention,
    required this.canEdit,
    required this.onQuickEntry,
  });

  String _s(dynamic value) => '${value ?? ''}'.trim();

  int _i(dynamic value) =>
      value is num ? value.toInt() : int.tryParse(_s(value)) ?? 0;

  DateTime? _date(dynamic value) =>
      DateTime.tryParse(_s(value).replaceAll(' ', 'T'));

  bool _sameDay(DateTime? a) =>
      a != null &&
      a.year == today.year &&
      a.month == today.month &&
      a.day == today.day;

  @override
  Widget build(BuildContext context) {
    final trainings = data.trainings.where((row) {
      return _sameDay(
        _date(
          row['start_at'] ??
              row['event_date'] ??
              row['date'],
        ),
      );
    }).toList();

    final sessions = data.sessions
        .where((session) => _sameDay(session.date))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PpSectionTitle(
          title: 'Сегодня · ${DateFormat('dd MMMM', 'ru').format(today)}',
          subtitle:
              'Сразу видно, что происходит с игроком сегодня',
          dotColor: PpColors.greenDark,
          trailing: canEdit
              ? PpTextAction(
                  label: 'Быстрая запись',
                  onTap: onQuickEntry,
                  dotColor: PpColors.greenDark,
                  emphasized: true,
                )
              : null,
        ),
        const SizedBox(height: 8),
        if (trainings.isEmpty &&
            sessions.isEmpty &&
            playerEntry == null &&
            coachEntry == null)
          const _TodayRow(
            color: PpColors.muted2,
            title: 'Событий на сегодня пока нет',
            value: '—',
          )
        else ...[
          for (final training in trainings)
            _TodayRow(
              color: PpColors.green,
              title:
                  '${training['title'] ?? 'Тренировка'}',
              value: _time(
                _date(
                  training['start_at'] ??
                      training['event_date'] ??
                      training['date'],
                ),
              ),
            ),
          for (final session in sessions.take(2))
            _TodayRow(
              color: PpColors.greenDark,
              title: 'Трекер',
              value:
                  '${(session.distanceM / 1000).toStringAsFixed(1)} км · '
                  '${session.maxSpeedKmh.toStringAsFixed(1)} км/ч',
            ),
          if (playerEntry != null)
            _TodayRow(
              color: PpColors.amber,
              title: 'Самооценка игрока',
              value:
                  '${_i(playerEntry!['rating']) > 0 ? '${_i(playerEntry!['rating'])}/5' : 'без оценки'}'
                  '${_i(playerEntry!['rpe']) > 0 ? ' · RPE ${_i(playerEntry!['rpe'])}/10' : ''}',
            ),
          if (coachEntry != null)
            _TodayRow(
              color: PpColors.green,
              title: 'Оценка тренера',
              value: _i(coachEntry!['rating']) > 0
                  ? '${_i(coachEntry!['rating'])}/5'
                  : 'есть заметка',
            ),
        ],
        const SizedBox(height: 10),
        Text(
          'Требует внимания',
          style: PpText.body(
            10.6,
            color: PpColors.text,
            weight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        ...attention.map(
          (item) => _TodayRow(
            color: item.color,
            title: item.text,
            value: '',
          ),
        ),
      ],
    );
  }

  static String _time(DateTime? value) {
    if (value == null) return 'время не указано';
    return DateFormat('HH:mm').format(value);
  }
}

class _AttentionItem {
  final String text;
  final Color color;

  const _AttentionItem(this.text, this.color);
}

class _TodayRow extends StatelessWidget {
  final Color color;
  final String title;
  final String value;

  const _TodayRow({
    required this.color,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 38),
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: PpColors.line,
            width: .55,
          ),
        ),
      ),
      child: Row(
        children: [
          PpDot(color: color, size: 6),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: PpText.body(
                10.6,
                color: PpColors.text,
                weight: FontWeight.w500,
              ),
            ),
          ),
          if (value.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(
              value,
              style: PpText.body(
                10.2,
                color: PpColors.text,
                weight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}


class PlayerDiaryQuickEntryPanel extends StatefulWidget {
  final bool isPlayer;
  final String authorRole;
  final PlayerDiarySave onSave;
  final VoidCallback onClose;

  const PlayerDiaryQuickEntryPanel({
    super.key,
    required this.isPlayer,
    required this.authorRole,
    required this.onSave,
    required this.onClose,
  });

  @override
  State<PlayerDiaryQuickEntryPanel> createState() =>
      _PlayerDiaryQuickEntryPanelState();
}

class _PlayerDiaryQuickEntryPanelState
    extends State<PlayerDiaryQuickEntryPanel> {
  final TextEditingController _note = TextEditingController();

  int _rating = 0;
  int _mood = 0;
  int _fatigue = 0;
  int _sleep = 0;
  int _pain = 0;
  int _rpe = 0;
  bool _saving = false;

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  bool get _empty {
    if (widget.isPlayer) {
      return _rating <= 0 &&
          _mood <= 0 &&
          _fatigue <= 0 &&
          _sleep <= 0 &&
          _pain <= 0 &&
          _rpe <= 0 &&
          _note.text.trim().isEmpty;
    }

    return _rating <= 0 && _note.text.trim().isEmpty;
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          text,
          style: PpText.body(
            10.8,
            color: Colors.white,
            weight: FontWeight.w600,
          ),
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: PpColors.text,
      ),
    );
  }

  Future<void> _save() async {
    if (_saving) return;

    if (_empty) {
      _message(
        widget.isPlayer
            ? 'Добавьте самооценку или заметку'
            : 'Добавьте оценку или заметку тренера',
      );
      return;
    }

    setState(() => _saving = true);

    try {
      await widget.onSave(
        entryDate: _today,
        authorRole: widget.authorRole,
        rating: _rating,
        mood: widget.isPlayer ? _mood : 0,
        fatigue: widget.isPlayer ? _fatigue : 0,
        sleepQuality: widget.isPlayer ? _sleep : 0,
        pain: widget.isPlayer ? _pain : 0,
        rpe: widget.isPlayer ? _rpe : 0,
        note: _note.text.trim(),
      );

      if (!mounted) return;
      widget.onClose();
    } catch (error) {
      if (!mounted) return;
      _message('Не удалось сохранить: $error');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: SafeArea(
        left: false,
        child: Column(
          children: [
            _header(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PpSurface(
                      color: PpColors.soft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          PpSectionTitle(
                            title: widget.isPlayer
                                ? 'Самооценка игрока'
                                : 'Запись тренера',
                            subtitle: widget.isPlayer
                                ? 'Состояние, нагрузка и короткая заметка за сегодня'
                                : 'Оценка и короткий комментарий по игроку',
                            dotColor: widget.isPlayer
                                ? PpColors.amber
                                : PpColors.greenDark,
                          ),
                          const SizedBox(height: 12),
                          _ScaleRow(
                            label: widget.isPlayer
                                ? 'Самооценка'
                                : 'Оценка',
                            value: _rating,
                            max: 5,
                            color: PpColors.green,
                            onChanged: (value) =>
                                setState(() => _rating = value),
                          ),
                          if (widget.isPlayer) ...[
                            const SizedBox(height: 10),
                            _ScaleRow(
                              label: 'Настроение',
                              value: _mood,
                              max: 5,
                              color: PpColors.green,
                              onChanged: (value) =>
                                  setState(() => _mood = value),
                            ),
                            const SizedBox(height: 10),
                            _ScaleRow(
                              label: 'Усталость',
                              value: _fatigue,
                              max: 5,
                              color: PpColors.amber,
                              onChanged: (value) =>
                                  setState(() => _fatigue = value),
                            ),
                            const SizedBox(height: 10),
                            _ScaleRow(
                              label: 'Сон',
                              value: _sleep,
                              max: 5,
                              color: PpColors.greenDark,
                              onChanged: (value) =>
                                  setState(() => _sleep = value),
                            ),
                            const SizedBox(height: 10),
                            _ScaleRow(
                              label: 'Боль',
                              value: _pain,
                              max: 5,
                              color: PpColors.red,
                              onChanged: (value) =>
                                  setState(() => _pain = value),
                            ),
                            const SizedBox(height: 10),
                            _ScaleRow(
                              label: 'RPE',
                              value: _rpe,
                              max: 10,
                              color: PpColors.amber,
                              onChanged: (value) =>
                                  setState(() => _rpe = value),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    PpSurface(
                      color: PpColors.soft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          PpSectionTitle(
                            title: widget.isPlayer
                                ? 'Заметка игрока'
                                : 'Комментарий тренера',
                            subtitle: widget.isPlayer
                                ? 'Что получилось, что было сложно, как себя чувствуете'
                                : 'Короткая обратная связь без перехода на другой экран',
                            dotColor: PpColors.green,
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _note,
                            minLines: 5,
                            maxLines: 9,
                            style: PpText.body(
                              10.8,
                              color: PpColors.text,
                            ),
                            decoration: InputDecoration(
                              hintText: widget.isPlayer
                                  ? 'Напишите заметку о тренировке или своём состоянии...'
                                  : 'Что отметить по игроку сегодня?',
                              hintStyle: PpText.body(
                                10.5,
                                color: PpColors.muted2,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding:
                                  const EdgeInsets.all(12),
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(9),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(9),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(9),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: PpColors.greenSoft,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Row(
                        children: [
                          const PpDotCluster(
                            color: PpColors.green,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              'После сохранения запись сразу появится в «Сегодня» и «Обратной связи».',
                              style: PpText.body(
                                10.2,
                                color: PpColors.greenDark,
                                weight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: widget.isPlayer
                  ? const Color(0xFFFFF7E8)
                  : PpColors.greenSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              widget.isPlayer
                  ? Icons.self_improvement_rounded
                  : Icons.edit_note_rounded,
              color: widget.isPlayer
                  ? PpColors.amber
                  : PpColors.greenDark,
              size: 19,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Быстрая запись', style: PpText.title(16)),
                const SizedBox(height: 2),
                Text(
                  widget.isPlayer
                      ? 'Дневник игрока · сегодня'
                      : 'Дневник игрока · запись тренера',
                  style: PpText.body(10.8),
                ),
              ],
            ),
          ),
          _panelAction(
            Icons.close_rounded,
            'Закрыть',
            _saving ? null : widget.onClose,
          ),
          const SizedBox(width: 7),
          _panelAction(
            Icons.save_rounded,
            'Сохранить',
            _saving ? null : _save,
            primary: true,
          ),
        ],
      ),
    );
  }

  Widget _panelAction(
    IconData icon,
    String tooltip,
    VoidCallback? onTap, {
    bool primary = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: primary
            ? PpColors.green
            : PpColors.soft,
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(9),
          child: SizedBox(
            width: 36,
            height: 36,
            child: _saving && primary
                ? const Padding(
                    padding: EdgeInsets.all(10),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    icon,
                    size: 18,
                    color: primary
                        ? Colors.white
                        : PpColors.text,
                  ),
          ),
        ),
      ),
    );
  }
}

class _QuickEditor extends StatelessWidget {
  final bool isPlayer;
  final int rating;
  final ValueChanged<int> onRating;
  final int mood;
  final ValueChanged<int> onMood;
  final int fatigue;
  final ValueChanged<int> onFatigue;
  final int sleep;
  final ValueChanged<int> onSleep;
  final int pain;
  final ValueChanged<int> onPain;
  final int rpe;
  final ValueChanged<int> onRpe;
  final TextEditingController noteController;
  final bool saving;
  final VoidCallback onSave;

  const _QuickEditor({
    required this.isPlayer,
    required this.rating,
    required this.onRating,
    required this.mood,
    required this.onMood,
    required this.fatigue,
    required this.onFatigue,
    required this.sleep,
    required this.onSleep,
    required this.pain,
    required this.onPain,
    required this.rpe,
    required this.onRpe,
    required this.noteController,
    required this.saving,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: PpColors.soft,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PpSectionTitle(
            title: isPlayer
                ? 'Моя быстрая отметка'
                : 'Быстрая запись тренера',
            subtitle: isPlayer
                ? '30 секунд после тренировки'
                : 'Оценка и короткая заметка',
            dotColor: isPlayer
                ? PpColors.amber
                : PpColors.green,
          ),
          const SizedBox(height: 10),
          _ScaleRow(
            label: 'Оценка',
            value: rating,
            max: 5,
            color: PpColors.green,
            onChanged: onRating,
          ),
          if (isPlayer) ...[
            const SizedBox(height: 8),
            _ScaleRow(
              label: 'Настроение',
              value: mood,
              max: 5,
              color: PpColors.green,
              onChanged: onMood,
            ),
            const SizedBox(height: 8),
            _ScaleRow(
              label: 'Усталость',
              value: fatigue,
              max: 5,
              color: PpColors.amber,
              onChanged: onFatigue,
            ),
            const SizedBox(height: 8),
            _ScaleRow(
              label: 'Сон',
              value: sleep,
              max: 5,
              color: PpColors.greenDark,
              onChanged: onSleep,
            ),
            const SizedBox(height: 8),
            _ScaleRow(
              label: 'Боль',
              value: pain,
              max: 5,
              color: PpColors.red,
              onChanged: onPain,
            ),
            const SizedBox(height: 8),
            _ScaleRow(
              label: 'RPE',
              value: rpe,
              max: 10,
              color: PpColors.amber,
              onChanged: onRpe,
            ),
          ],
          const SizedBox(height: 10),
          TextField(
            controller: noteController,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: isPlayer
                  ? 'Что получилось? Что было сложно?'
                  : 'Что отметить по игроку?',
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.all(11),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: BorderSide.none,
              ),
            ),
            style: PpText.body(
              10.6,
              color: PpColors.text,
            ),
          ),
          const SizedBox(height: 9),
          Align(
            alignment: Alignment.centerRight,
            child: PpTextAction(
              label: saving ? 'Сохранение...' : 'Сохранить',
              onTap: saving ? null : onSave,
              emphasized: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScaleRow extends StatelessWidget {
  final String label;
  final int value;
  final int max;
  final Color color;
  final ValueChanged<int> onChanged;

  const _ScaleRow({
    required this.label,
    required this.value,
    required this.max,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 92,
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              children: [
                PpDot(color: color, size: 5),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: PpText.body(
                      10.2,
                      color: PpColors.text,
                      weight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Wrap(
            spacing: 4,
            runSpacing: 4,
            children: List.generate(max, (index) {
              final current = index + 1;
              final active = current == value;

              return Material(
                color: active ? PpColors.greenSoft : Colors.white,
                borderRadius: BorderRadius.circular(7),
                child: InkWell(
                  onTap: () => onChanged(current),
                  borderRadius: BorderRadius.circular(7),
                  child: SizedBox(
                    width: max > 5 ? 29 : 34,
                    height: 28,
                    child: Center(
                      child: Text(
                        '$current',
                        style: PpText.body(
                          9.5,
                          color: active
                              ? PpColors.greenDark
                              : PpColors.muted,
                          weight: active
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _GoalsSection extends StatelessWidget {
  final List<Map<String, dynamic>> goals;
  final bool canAdd;
  final bool canUpdate;
  final VoidCallback onAdd;
  final Future<void> Function(
    Map<String, dynamic>,
    int,
  ) onUpdate;

  const _GoalsSection({
    required this.goals,
    required this.canAdd,
    required this.canUpdate,
    required this.onAdd,
    required this.onUpdate,
  });

  int _i(dynamic value) =>
      value is num
          ? value.toInt()
          : int.tryParse('${value ?? ''}') ?? 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PpSectionTitle(
          title: 'Цели на неделю',
          subtitle:
              '1–3 понятные задачи вместо длинного плана',
          dotColor: PpColors.amber,
          trailing: canAdd
              ? PpTextAction(
                  label: 'Добавить',
                  onTap: onAdd,
                  dotColor: PpColors.amber,
                )
              : null,
        ),
        const SizedBox(height: 7),
        if (goals.isEmpty)
          const _TodayRow(
            color: PpColors.muted2,
            title: 'Цели на эту неделю не заданы',
            value: '',
          )
        else
          ...goals.asMap().entries.map((entry) {
            final goal = entry.value;
            final progress =
                _i(goal['progress']).clamp(0, 100);
            final color = progress >= 100
                ? PpColors.green
                : progress >= 50
                    ? PpColors.amber
                    : PpColors.greenDark;

            return Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding:
                            const EdgeInsets.only(top: 5),
                        child: PpDot(
                          color: color,
                          size: 7,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${goal['goal_text'] ?? 'Цель'}',
                              style: PpText.body(
                                10.8,
                                color: PpColors.text,
                                weight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 5,
                              runSpacing: 5,
                              children: <int>[
                                0,
                                25,
                                50,
                                75,
                                100,
                              ].map((value) {
                                final active =
                                    value == progress;

                                return Material(
                                  color: active
                                      ? PpColors.greenSoft
                                      : PpColors.soft,
                                  borderRadius:
                                      BorderRadius.circular(7),
                                  child: InkWell(
                                    onTap: canUpdate
                                        ? () => onUpdate(
                                              goal,
                                              value,
                                            )
                                        : null,
                                    borderRadius:
                                        BorderRadius.circular(7),
                                    child: Padding(
                                      padding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 5,
                                      ),
                                      child: Text(
                                        value == 100
                                            ? 'Готово'
                                            : '$value%',
                                        style: PpText.caption(
                                          size: 9.5,
                                          color: active
                                              ? PpColors.greenDark
                                              : PpColors.muted2,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (entry.key != goals.length - 1)
                  const PpThinDivider(
                    margin: EdgeInsets.zero,
                  ),
              ],
            );
          }),
      ],
    );
  }
}

class _WeekSummary extends StatelessWidget {
  final PlayerProfileSnapshot data;
  final DateTime weekStart;
  final DateTime weekEnd;

  const _WeekSummary({
    required this.data,
    required this.weekStart,
    required this.weekEnd,
  });

  String _s(dynamic value) => '${value ?? ''}'.trim();

  int _i(dynamic value) =>
      value is num ? value.toInt() : int.tryParse(_s(value)) ?? 0;

  DateTime? _date(dynamic value) =>
      DateTime.tryParse(_s(value).replaceAll(' ', 'T'));

  bool _inWeek(DateTime? value) =>
      value != null &&
      !value.isBefore(weekStart) &&
      value.isBefore(weekEnd.add(const Duration(days: 1)));

  @override
  Widget build(BuildContext context) {
    final trainings = data.trainings.where((row) {
      return _inWeek(
        _date(
          row['start_at'] ??
              row['event_date'] ??
              row['date'],
        ),
      );
    }).length;

    final sessions =
        data.sessions.where((row) => _inWeek(row.date)).toList();

    final distance = sessions.fold<double>(
      0,
      (sum, row) => sum + row.distanceM,
    );

    final sprints = sessions.fold<int>(
      0,
      (sum, row) => sum + row.sprintCount,
    );

    final playerRows = data.diaryEntries.where((row) {
      return _s(row['author_role']).toLowerCase() ==
              'player' &&
          _inWeek(
            _date(
              row['entry_date'] ??
                  row['date'] ??
                  row['created_at'],
            ),
          );
    }).toList();

    final rpeValues = playerRows
        .map((row) => _i(row['rpe']))
        .where((value) => value > 0)
        .toList();

    final avgRpe = rpeValues.isEmpty
        ? 0
        : rpeValues.reduce((a, b) => a + b) /
            rpeValues.length;

    final values = <_Metric>[
      _Metric('Тренировки', '$trainings', PpColors.green),
      _Metric(
        'GPS дистанция',
        distance > 0
            ? '${(distance / 1000).toStringAsFixed(1)} км'
            : '—',
        PpColors.greenDark,
      ),
      _Metric('Спринты', '$sprints', PpColors.amber),
      _Metric(
        'Средний RPE',
        avgRpe > 0 ? avgRpe.toStringAsFixed(1) : '—',
        PpColors.amber,
      ),
      _Metric(
        'Посещаемость',
        '${data.attendancePercent}%',
        PpColors.green,
      ),
      _Metric(
        'Рейтинг',
        data.compositeRating > 0
            ? '${data.compositeRating}'
            : '—',
        PpColors.greenDark,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PpSectionTitle(
          title: 'Неделя в цифрах',
          subtitle:
              'Короткая сводка для тренера, игрока и родителя',
          dotColor: PpColors.greenDark,
        ),
        const SizedBox(height: 9),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns =
                constraints.maxWidth >= 760 ? 3 : 2;
            final width =
                (constraints.maxWidth - (columns - 1) * 8) /
                    columns;

            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: values
                  .map(
                    (item) => SizedBox(
                      width: width,
                      child: PpMetric(
                        label: item.label,
                        value: item.value,
                        dotColor: item.color,
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}


class _DiaryFeedbackSection extends StatelessWidget {
  final PlayerProfileSnapshot data;

  const _DiaryFeedbackSection({required this.data});

  String _s(dynamic value) => '${value ?? ''}'.trim();
  int _i(dynamic value) =>
      value is num ? value.toInt() : int.tryParse(_s(value)) ?? 0;
  double _d(dynamic value) => value is num
      ? value.toDouble()
      : double.tryParse(_s(value).replaceAll(',', '.')) ?? 0;
  DateTime? _date(dynamic value) =>
      DateTime.tryParse(_s(value).replaceAll(' ', 'T'));

  String _first(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = _s(row[key]);
      if (value.isNotEmpty && value != 'null') return value;
    }
    return '';
  }

  List<_DiaryFeedbackItem> _items() {
    final items = <_DiaryFeedbackItem>[];

    for (final row in data.coachRatings) {
      final rating = _d(row['rating']);
      final note = _first(row, const [
        'comment', 'note', 'notes', 'coach_comment', 'feedback', 'text',
      ]);
      items.add(
        _DiaryFeedbackItem(
          date: _date(row['event_date'] ?? row['date'] ?? row['created_at']),
          title: _first(row, const ['event_title', 'training_title', 'title']).isEmpty
              ? 'Оценка тренера после тренировки'
              : _first(row, const ['event_title', 'training_title', 'title']),
          subtitle: 'Тренер · календарь тренировок',
          rating: rating,
          note: note,
          color: PpColors.greenDark,
          kind: 'coach-calendar',
        ),
      );
    }

    for (final row in data.selfAssessments) {
      final note = _first(row, const [
        'note', 'notes', 'comment', 'feedback', 'text', 'description',
      ]);
      items.add(
        _DiaryFeedbackItem(
          date: _date(row['assessment_date'] ?? row['entry_date'] ?? row['date'] ?? row['created_at']),
          title: 'Самооценка игрока',
          subtitle: _subjectiveLine(row),
          rating: _d(row['rating'] ?? row['self_rating'] ?? row['score']),
          note: note,
          color: PpColors.amber,
          kind: 'player-self',
        ),
      );
    }

    for (final row in data.diaryEntries) {
      final role = _s(row['author_role']).toLowerCase();
      final isPlayer = role == 'player';
      final isCoach = role == 'coach' || role == 'manager';
      if (!isPlayer && !isCoach) continue;
      final note = _first(row, const [
        'note', 'notes', 'comment', 'feedback', 'text', 'description',
      ]);
      final rating = _d(row['rating']);
      if (rating <= 0 && note.isEmpty && !isPlayer) continue;
      items.add(
        _DiaryFeedbackItem(
          date: _date(row['entry_date'] ?? row['date'] ?? row['created_at']),
          title: isPlayer ? 'Запись игрока' : 'Заметка тренера',
          subtitle: isPlayer ? _subjectiveLine(row) : 'Тренер · дневник',
          rating: rating,
          note: note,
          color: isPlayer ? PpColors.amber : PpColors.greenDark,
          kind: isPlayer ? 'player-diary' : 'coach-diary',
        ),
      );
    }

    // Remove obvious duplicates when the same self-assessment is returned by
    // both legacy and daily diary endpoints.
    final unique = <String, _DiaryFeedbackItem>{};
    for (final item in items) {
      final day = item.date == null
          ? ''
          : '${item.date!.year}-${item.date!.month}-${item.date!.day}';
      final key = '$day|${item.kind.startsWith('player') ? 'player' : 'coach'}|'
          '${item.rating.toStringAsFixed(1)}|${item.note.trim().toLowerCase()}';
      unique.putIfAbsent(key, () => item);
    }
    final out = unique.values.toList()
      ..sort((a, b) => (b.date ?? DateTime(1970))
          .compareTo(a.date ?? DateTime(1970)));
    return out;
  }

  String _subjectiveLine(Map<String, dynamic> row) {
    final values = <String>[];
    void add(String label, dynamic raw) {
      final value = _i(raw);
      if (value > 0) values.add('$label $value');
    }
    add('настроение', row['mood']);
    add('усталость', row['fatigue']);
    add('сон', row['sleep_quality'] ?? row['sleep']);
    add('боль', row['pain']);
    add('RPE', row['rpe']);
    return values.isEmpty ? 'Игрок · самооценка' : 'Игрок · ${values.join(' · ')}';
  }

  @override
  Widget build(BuildContext context) {
    final items = _items();
    final playerNotes = items.where((e) =>
        e.kind.startsWith('player') && e.note.trim().isNotEmpty).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const PpDotCluster(color: PpColors.greenDark),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Оценки и обратная связь', style: PpText.title(16)),
                  const SizedBox(height: 3),
                  Text(
                    'Оценки из календаря, самооценка и заметки самого игрока',
                    style: PpText.body(10.2),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth >= 660
                ? (constraints.maxWidth - 16) / 3
                : constraints.maxWidth;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: width,
                  child: PpMetric(
                    label: 'Оценка тренера',
                    value: data.coachRatingAverage > 0
                        ? data.coachRatingAverage.toStringAsFixed(1)
                        : '—',
                    note: 'из календаря и дневника',
                    dotColor: PpColors.greenDark,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: PpMetric(
                    label: 'Самооценка игрока',
                    value: data.selfRatingAverage > 0
                        ? data.selfRatingAverage.toStringAsFixed(1)
                        : '—',
                    note: 'что чувствует сам игрок',
                    dotColor: PpColors.amber,
                  ),
                ),
                SizedBox(
                  width: width,
                  child: PpMetric(
                    label: 'Заметки игрока',
                    value: '$playerNotes',
                    note: 'текстовая обратная связь',
                    dotColor: PpColors.green,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          PpSurface(
            color: PpColors.soft,
            child: Row(
              children: [
                const PpDot(color: PpColors.muted2, size: 6, glow: false),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Пока нет оценок или записей игрока.',
                    style: PpText.body(10.6),
                  ),
                ),
              ],
            ),
          )
        else
          ...items.take(40).map((item) => _DiaryFeedbackTile(item: item)),
      ],
    );
  }
}

class _DiaryFeedbackTile extends StatelessWidget {
  final _DiaryFeedbackItem item;

  const _DiaryFeedbackTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final date = item.date == null
        ? 'Дата не указана'
        : DateFormat('dd.MM.yyyy').format(item.date!);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: PpSurface(
        color: Color.alphaBlend(item.color.withOpacity(.028), PpColors.soft),
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: PpDot(color: item.color, size: 7),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: PpText.body(
                            11,
                            color: PpColors.text,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (item.rating > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: item.color.withOpacity(.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${item.rating % 1 == 0 ? item.rating.toInt() : item.rating.toStringAsFixed(1)}/5',
                            style: PpText.caption(color: item.color),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('$date · ${item.subtitle}', style: PpText.caption()),
                  if (item.note.trim().isNotEmpty) ...[
                    const SizedBox(height: 7),
                    Text(
                      item.note.trim(),
                      style: PpText.body(10.6, color: PpColors.text),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiaryFeedbackItem {
  final DateTime? date;
  final String title;
  final String subtitle;
  final double rating;
  final String note;
  final Color color;
  final String kind;

  const _DiaryFeedbackItem({
    required this.date,
    required this.title,
    required this.subtitle,
    required this.rating,
    required this.note,
    required this.color,
    required this.kind,
  });
}


class _DiaryPeriodBar extends StatelessWidget {
  final _DiaryPeriod value;
  final ValueChanged<_DiaryPeriod> onChanged;
  final VoidCallback onCalendar;

  const _DiaryPeriodBar({
    required this.value,
    required this.onChanged,
    required this.onCalendar,
  });

  static const labels = <_DiaryPeriod, String>{
    _DiaryPeriod.today: 'Сегодня',
    _DiaryPeriod.week: '7 дней',
    _DiaryPeriod.month: '30 дней',
    _DiaryPeriod.all: 'Всё',
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: labels.entries.map((entry) {
                final active = entry.key == value;
                return Padding(
                  padding: const EdgeInsets.only(right: 5),
                  child: Material(
                    color: active
                        ? PpColors.greenSoft
                        : PpColors.soft,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: () => onChanged(entry.key),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 7,
                        ),
                        child: Row(
                          children: [
                            PpDot(
                              color: active
                                  ? PpColors.green
                                  : PpColors.muted2,
                              size: active ? 6 : 4.5,
                              glow: active,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              entry.value,
                              style: PpText.body(
                                10.2,
                                color: active
                                    ? PpColors.greenDark
                                    : PpColors.text,
                                weight: active
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(growable: false),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Material(
          color: PpColors.greenSoft,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: onCalendar,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 9,
                vertical: 7,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.calendar_month_outlined,
                    size: 15,
                    color: PpColors.greenDark,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Календарь',
                    style: PpText.body(
                      10.2,
                      color: PpColors.greenDark,
                      weight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DiaryCalendarView extends StatefulWidget {
  final PlayerProfileSnapshot data;
  final _DiaryFilter filter;
  final ValueChanged<_DiaryFilter> onFilterChanged;

  const _DiaryCalendarView({
    required this.data,
    required this.filter,
    required this.onFilterChanged,
  });

  @override
  State<_DiaryCalendarView> createState() =>
      _DiaryCalendarViewState();
}

class _DiaryCalendarViewState extends State<_DiaryCalendarView> {
  late DateTime _month;
  DateTime? _selectedDate;

  String _s(dynamic value) => '${value ?? ''}'.trim();

  DateTime? _date(dynamic value) =>
      DateTime.tryParse(_s(value).replaceAll(' ', 'T'));

  String _key(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  Set<String> _busyDays() {
    final result = <String>{};

    void add(DateTime? date) {
      if (date == null) return;
      result.add(_key(DateTime(date.year, date.month, date.day)));
    }

    for (final row in widget.data.trainings) {
      add(_date(row['start_at'] ?? row['event_date'] ?? row['date']));
    }
    for (final row in widget.data.sessions) {
      add(row.date);
    }
    for (final row in widget.data.matches) {
      add(_date(row['match_date'] ?? row['date']));
    }
    for (final row in widget.data.tests) {
      add(_date(row['test_date'] ?? row['date'] ?? row['created_at']));
    }
    for (final row in widget.data.diaryEntries) {
      add(_date(row['entry_date'] ?? row['date'] ?? row['created_at']));
    }
    for (final row in widget.data.medical) {
      add(_date(row['record_date'] ?? row['date'] ?? row['created_at']));
    }

    return result;
  }

  void _changeMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _selectedDate = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final busyDays = _busyDays();
    final first = DateTime(_month.year, _month.month, 1);
    final daysInMonth =
        DateTime(_month.year, _month.month + 1, 0).day;
    final leading = first.weekday - 1;
    final cells = leading + daysInMonth;
    final rows = (cells / 7).ceil();
    final totalCells = rows * 7;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PpSurface(
          color: PpColors.soft,
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  const PpDotCluster(color: PpColors.green),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('LLLL yyyy', 'ru')
                              .format(_month)
                              .replaceFirstMapped(
                                RegExp(r'^.'),
                                (m) => m.group(0)!.toUpperCase(),
                              ),
                          style: PpText.title(15),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Выберите день — ниже останутся только записи этой даты',
                          style: PpText.body(10.2),
                        ),
                      ],
                    ),
                  ),
                  _monthButton(
                    Icons.chevron_left_rounded,
                    () => _changeMonth(-1),
                  ),
                  const SizedBox(width: 5),
                  _monthButton(
                    Icons.today_outlined,
                    () {
                      final now = DateTime.now();
                      setState(() {
                        _month = DateTime(now.year, now.month);
                        _selectedDate =
                            DateTime(now.year, now.month, now.day);
                      });
                    },
                  ),
                  const SizedBox(width: 5),
                  _monthButton(
                    Icons.chevron_right_rounded,
                    () => _changeMonth(1),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: const [
                  _DiaryWeekday('ПН'),
                  _DiaryWeekday('ВТ'),
                  _DiaryWeekday('СР'),
                  _DiaryWeekday('ЧТ'),
                  _DiaryWeekday('ПТ'),
                  _DiaryWeekday('СБ'),
                  _DiaryWeekday('ВС'),
                ],
              ),
              const SizedBox(height: 5),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: totalCells,
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 5,
                  crossAxisSpacing: 5,
                  childAspectRatio: 1.12,
                ),
                itemBuilder: (_, index) {
                  final dayNumber = index - leading + 1;
                  if (dayNumber < 1 || dayNumber > daysInMonth) {
                    return const SizedBox.shrink();
                  }

                  final date =
                      DateTime(_month.year, _month.month, dayNumber);
                  final selected = _selectedDate != null &&
                      _key(_selectedDate!) == _key(date);
                  final busy = busyDays.contains(_key(date));
                  final today = _key(DateTime.now()) == _key(date);

                  return Material(
                    color: selected
                        ? PpColors.greenSoft
                        : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: () =>
                          setState(() => _selectedDate = date),
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(
                        children: [
                          Center(
                            child: Text(
                              '$dayNumber',
                              style: PpText.body(
                                10.4,
                                color: selected
                                    ? PpColors.greenDark
                                    : PpColors.text,
                                weight: selected || today
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                          if (busy)
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 5,
                              child: Center(
                                child: PpDot(
                                  color: selected
                                      ? PpColors.green
                                      : PpColors.greenDark,
                                  size: selected ? 5.5 : 4,
                                  glow: selected,
                                ),
                              ),
                            ),
                          if (today && !selected)
                            Positioned(
                              top: 5,
                              right: 5,
                              child: PpDot(
                                color: PpColors.amber,
                                size: 3.5,
                                glow: false,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _DiaryFilters(
          value: widget.filter,
          onChanged: widget.onFilterChanged,
        ),
        const SizedBox(height: 8),
        if (_selectedDate == null)
          PpSurface(
            color: PpColors.soft,
            child: Row(
              children: [
                const Icon(
                  Icons.touch_app_outlined,
                  size: 17,
                  color: PpColors.greenDark,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Выберите дату в календаре',
                    style: PpText.body(10.6),
                  ),
                ),
              ],
            ),
          )
        else ...[
          Row(
            children: [
              const PpDotCluster(color: PpColors.greenDark),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  DateFormat('d MMMM yyyy, EEEE', 'ru')
                      .format(_selectedDate!),
                  style: PpText.title(13.5),
                ),
              ),
              Material(
                color: PpColors.soft,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: () => setState(() => _selectedDate = null),
                  borderRadius: BorderRadius.circular(8),
                  child: const SizedBox(
                    width: 31,
                    height: 31,
                    child: Icon(
                      Icons.close_rounded,
                      size: 16,
                      color: PpColors.muted,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _History(
            data: widget.data,
            filter: widget.filter,
            from: _selectedDate,
            to: _selectedDate,
            compactTitle: true,
          ),
        ],
      ],
    );
  }

  Widget _monthButton(IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(
            icon,
            size: 16,
            color: PpColors.greenDark,
          ),
        ),
      ),
    );
  }
}

class _DiaryWeekday extends StatelessWidget {
  final String label;

  const _DiaryWeekday(this.label);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          label,
          style: PpText.caption(
            size: 8.8,
            color: PpColors.muted2,
          ),
        ),
      ),
    );
  }
}

class _DiaryFilters extends StatelessWidget {
  final _DiaryFilter value;
  final ValueChanged<_DiaryFilter> onChanged;

  const _DiaryFilters({
    required this.value,
    required this.onChanged,
  });

  static const labels = <_DiaryFilter, String>{
    _DiaryFilter.all: 'Все',
    _DiaryFilter.training: 'Тренировки',
    _DiaryFilter.match: 'Матчи',
    _DiaryFilter.test: 'Тесты',
    _DiaryFilter.health: 'Здоровье',
    _DiaryFilter.notes: 'Заметки',
  };

  Color _color(_DiaryFilter filter) {
    switch (filter) {
      case _DiaryFilter.all:
      case _DiaryFilter.training:
        return PpColors.green;
      case _DiaryFilter.match:
        return PpColors.greenDark;
      case _DiaryFilter.test:
        return PpColors.amber;
      case _DiaryFilter.health:
        return PpColors.red;
      case _DiaryFilter.notes:
        return PpColors.greenDark;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: labels.entries.map((entry) {
          final active = entry.key == value;

          return Padding(
            padding: const EdgeInsets.only(right: 5),
            child: Material(
              color:
                  active ? PpColors.greenSoft : PpColors.soft,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: () => onChanged(entry.key),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 7,
                  ),
                  child: Row(
                    children: [
                      PpDot(
                        color: _color(entry.key),
                        size: active ? 6 : 4.5,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        entry.value,
                        style: PpText.body(
                          10.2,
                          color: active
                              ? PpColors.greenDark
                              : PpColors.text,
                          weight: active
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _History extends StatelessWidget {
  final PlayerProfileSnapshot data;
  final _DiaryFilter filter;
  final DateTime? from;
  final DateTime? to;
  final bool compactTitle;

  const _History({
    required this.data,
    required this.filter,
    this.from,
    this.to,
    this.compactTitle = false,
  });

  String _s(dynamic value) => '${value ?? ''}'.trim();

  int _i(dynamic value) =>
      value is num ? value.toInt() : int.tryParse(_s(value)) ?? 0;

  DateTime? _date(dynamic value) =>
      DateTime.tryParse(_s(value).replaceAll(' ', 'T'));

  String _key(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  bool _show(String type) {
    switch (filter) {
      case _DiaryFilter.all:
        return true;
      case _DiaryFilter.training:
        return type == 'training' || type == 'tracker';
      case _DiaryFilter.match:
        return type == 'match';
      case _DiaryFilter.test:
        return type == 'test';
      case _DiaryFilter.health:
        return type == 'health';
      case _DiaryFilter.notes:
        return type == 'note';
    }
  }

  @override
  Widget build(BuildContext context) {
    final days = <String, _HistoryDay>{};

    void add(
      DateTime? rawDate,
      _HistoryItem item,
    ) {
      if (rawDate == null || !_show(item.type)) return;
      final date =
          DateTime(rawDate.year, rawDate.month, rawDate.day);
      final fromDay = from == null
          ? null
          : DateTime(from!.year, from!.month, from!.day);
      final toDay = to == null
          ? null
          : DateTime(to!.year, to!.month, to!.day);
      if (fromDay != null && date.isBefore(fromDay)) return;
      if (toDay != null && date.isAfter(toDay)) return;
      final key = _key(date);
      days.putIfAbsent(key, () => _HistoryDay(date));
      days[key]!.items.add(item);
    }

    for (final row in data.trainings) {
      final date = _date(
        row['start_at'] ??
            row['event_date'] ??
            row['date'],
      );
      add(
        date,
        _HistoryItem(
          'training',
          PpColors.green,
          _s(row['title']).isEmpty
              ? 'Тренировка'
              : _s(row['title']),
          _s(row['location']),
        ),
      );
    }

    for (final row in data.sessions) {
      add(
        row.date,
        _HistoryItem(
          'tracker',
          PpColors.greenDark,
          'Трекер',
          '${(row.distanceM / 1000).toStringAsFixed(1)} км · '
              '${row.maxSpeedKmh.toStringAsFixed(1)} км/ч · '
              '${row.sprintCount} спринт.',
        ),
      );
    }

    for (final row in data.matches) {
      add(
        _date(row['match_date'] ?? row['date']),
        _HistoryItem(
          'match',
          PpColors.greenDark,
          _s(row['opponent']).isEmpty
              ? 'Матч'
              : 'Матч · ${_s(row['opponent'])}',
          _s(row['score'] ?? row['result']),
        ),
      );
    }

    for (final row in data.tests) {
      add(
        _date(
          row['test_date'] ??
              row['date'] ??
              row['created_at'],
        ),
        _HistoryItem(
          'test',
          PpColors.amber,
          _s(row['test_name']).isEmpty
              ? 'Тестирование'
              : _s(row['test_name']),
          '${_s(row['result'] ?? row['value'])}'
          '${_s(row['unit']).isEmpty ? '' : ' ${_s(row['unit'])}'}',
        ),
      );
    }

    for (final row in data.diaryEntries) {
      final author = _s(row['author_role']).toLowerCase();
      final rating = _i(row['rating']);
      final rpe = _i(row['rpe']);
      final note = _s(row['note']);

      add(
        _date(
          row['entry_date'] ??
              row['date'] ??
              row['created_at'],
        ),
        _HistoryItem(
          'note',
          author == 'player'
              ? PpColors.amber
              : PpColors.green,
          author == 'player'
              ? 'Самооценка игрока'
              : 'Запись тренера',
          <String>[
            if (rating > 0) '$rating/5',
            if (rpe > 0) 'RPE $rpe/10',
            if (note.isNotEmpty) note,
          ].join(' · '),
        ),
      );
    }

    for (final row in data.medical) {
      add(
        _date(
          row['record_date'] ??
              row['date'] ??
              row['created_at'],
        ),
        _HistoryItem(
          'health',
          PpColors.red,
          _s(row['title']).isEmpty
              ? 'Медицинская запись'
              : _s(row['title']),
          _s(
            row['note'] ??
                row['description'] ??
                row['comment'],
          ),
        ),
      );
    }

    final list = days.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!compactTitle) ...[
          const PpSectionTitle(
            title: 'История',
            subtitle:
                'Один день объединяет события, трекер и обратную связь',
            dotColor: PpColors.green,
          ),
          const SizedBox(height: 8),
        ],
        if (list.isEmpty)
          const SizedBox(
            height: 160,
            child: PpEmpty(
              title: 'Нет записей',
              text: 'Для выбранного фильтра история пуста',
            ),
          )
        else
          ...list.take(60).map(
                (day) => _HistoryDayView(day: day),
              ),
      ],
    );
  }
}

class _HistoryDay {
  final DateTime date;
  final List<_HistoryItem> items = [];

  _HistoryDay(this.date);
}

class _HistoryItem {
  final String type;
  final Color color;
  final String title;
  final String subtitle;

  const _HistoryItem(
    this.type,
    this.color,
    this.title,
    this.subtitle,
  );
}

class _HistoryDayView extends StatelessWidget {
  final _HistoryDay day;

  const _HistoryDayView({required this.day});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const PpThinDivider(
          margin: EdgeInsets.only(top: 4, bottom: 8),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 66,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('dd.MM').format(day.date),
                    style: PpText.value(14),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('EEE', 'ru')
                        .format(day.date)
                        .toUpperCase(),
                    style: PpText.caption(size: 9.5),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                children: day.items
                    .asMap()
                    .entries
                    .map(
                      (entry) => Column(
                        children: [
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(
                              vertical: 7,
                            ),
                            child: Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding:
                                      const EdgeInsets.only(
                                    top: 5,
                                  ),
                                  child: PpDot(
                                    color:
                                        entry.value.color,
                                    size: 7,
                                  ),
                                ),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        entry.value.title,
                                        style: PpText.body(
                                          10.8,
                                          color:
                                              PpColors.text,
                                          weight:
                                              FontWeight.w600,
                                        ),
                                      ),
                                      if (entry.value.subtitle
                                          .trim()
                                          .isNotEmpty) ...[
                                        const SizedBox(
                                          height: 2,
                                        ),
                                        Text(
                                          entry
                                              .value.subtitle,
                                          style:
                                              PpText.body(
                                            10.2,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (entry.key !=
                              day.items.length - 1)
                            const PpThinDivider(
                              margin: EdgeInsets.zero,
                            ),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
