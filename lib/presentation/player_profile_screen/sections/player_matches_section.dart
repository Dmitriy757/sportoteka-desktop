import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/player_profile_models.dart';
import '../widgets/player_profile_ui.dart';

typedef PlayerMatchesSidePanel = void Function(
  Widget Function(VoidCallback close) builder,
);

class PlayerMatchesSection extends StatefulWidget {
  final PlayerProfileSnapshot data;
  final PlayerMatchesSidePanel? onOpenSidePanel;

  const PlayerMatchesSection({
    super.key,
    required this.data,
    this.onOpenSidePanel,
  });

  @override
  State<PlayerMatchesSection> createState() => _PlayerMatchesSectionState();
}

class _PlayerMatchesSectionState extends State<PlayerMatchesSection> {
  late DateTime _month;
  DateTime? _selectedDate;
  _MatchPeriod _period = _MatchPeriod.all;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  String _s(dynamic value) => '${value ?? ''}'.trim();

  int _i(dynamic value) =>
      value is int ? value : int.tryParse(_s(value)) ?? 0;

  double _n(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(_s(value).replaceAll(',', '.')) ?? 0;
  }

  DateTime? _d(dynamic value) {
    final raw = _s(value);
    if (raw.isEmpty || raw.toLowerCase() == 'null') return null;
    return DateTime.tryParse(raw.replaceAll(' ', 'T'));
  }

  DateTime? _matchDate(Map<String, dynamic> match) => _d(
        match['match_date'] ??
            match['date'] ??
            match['event_date'] ??
            match['start_at'] ??
            match['created_at'],
      );

  int _matchId(Map<String, dynamic> match) => _i(
        match['match_id'] ??
            match['id'] ??
            match['event_id'] ??
            match['calendar_event_id'],
      );

  int _eventId(Map<String, dynamic> match) => _i(
        match['event_id'] ??
            match['calendar_event_id'] ??
            match['match_event_id'],
      );

  String _opponent(Map<String, dynamic> match) {
    for (final key in const [
      'opponent',
      'opponent_name',
      'away_team',
      'away_team_name',
      'rival',
      'title',
    ]) {
      final value = _s(match[key]);
      if (value.isNotEmpty) return value;
    }
    return 'Матч';
  }

  String _competition(Map<String, dynamic> match) {
    for (final key in const [
      'competition_name',
      'competition',
      'tournament',
      'league',
      'event_type',
    ]) {
      final value = _s(match[key]);
      if (value.isNotEmpty) return value;
    }
    return 'Матч';
  }

  String _score(Map<String, dynamic> match) {
    final direct = _s(
      match['score'] ??
          match['result'] ??
          match['match_score'],
    );
    if (direct.isNotEmpty) return direct;

    final our = _s(
      match['our_score'] ??
          match['home_score'] ??
          match['team_score'],
    );
    final opponent = _s(
      match['opponent_score'] ??
          match['away_score'] ??
          match['rival_score'],
    );
    if (our.isNotEmpty || opponent.isNotEmpty) {
      return '${our.isEmpty ? '0' : our}:${opponent.isEmpty ? '0' : opponent}';
    }
    return '—';
  }

  String _minutes(Map<String, dynamic> match) {
    for (final key in const [
      'minutes',
      'minutes_played',
      'played_minutes',
      'play_time',
      'duration_min',
    ]) {
      final value = _n(match[key]);
      if (value > 0) return '${value.round()} мин';
    }
    return '—';
  }

  String _ttd(Map<String, dynamic> match) {
    for (final key in const [
      'ttd_total',
      'total_ttd',
      'actions_total',
      'total_actions',
      'ttd',
    ]) {
      final value = _n(match[key]);
      if (value > 0) return value.round().toString();
    }
    return '—';
  }

  String _efficiency(Map<String, dynamic> match) {
    for (final key in const [
      'effect_percent',
      'efficiency',
      'efficiency_percent',
      'success_percent',
    ]) {
      final value = _n(match[key]);
      if (value > 0) return '${value.toStringAsFixed(value % 1 == 0 ? 0 : 1)}%';
    }
    return '—';
  }

  bool _sameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _rowLooksLikeMatch(Map<String, dynamic> row) {
    final type = _s(
      row['event_type'] ??
          row['type'] ??
          row['source_type'] ??
          row['entity_type'],
    ).toLowerCase();
    return type.contains('match') ||
        type.contains('game') ||
        type.contains('матч') ||
        type.contains('игр');
  }

  bool _rowLinkedToMatch(
    Map<String, dynamic> row,
    Map<String, dynamic> match,
  ) {
    final matchId = _matchId(match);
    final eventId = _eventId(match);

    final rowMatchId = _i(
      row['match_id'] ??
          row['game_id'] ??
          row['entity_id'],
    );
    if (matchId > 0 && rowMatchId > 0 && matchId == rowMatchId) {
      return true;
    }

    final rowEventId = _i(
      row['event_id'] ??
          row['calendar_event_id'] ??
          row['match_event_id'],
    );
    if (eventId > 0 && rowEventId > 0 && eventId == rowEventId) {
      return true;
    }

    // Date fallback is intentionally conservative: only rows explicitly
    // marked as match/game are allowed to join by date.
    if (_rowLooksLikeMatch(row)) {
      return _sameDay(
        _matchDate(match),
        _d(row['entry_date'] ?? row['date'] ?? row['created_at']),
      );
    }

    return false;
  }

  double _average(List<double> values) {
    final clean = values.where((e) => e > 0).toList();
    if (clean.isEmpty) return 0;
    return clean.reduce((a, b) => a + b) / clean.length;
  }

  double _coachRating(Map<String, dynamic> match) {
    for (final key in const [
      'coach_rating',
      'trainer_rating',
      'rating_coach',
      'match_rating',
      'rating',
    ]) {
      final value = _n(match[key]);
      if (value > 0) return value;
    }

    final linked = <double>[];

    for (final row in widget.data.coachRatings) {
      if (_rowLinkedToMatch(row, match)) {
        final value = _n(row['rating']);
        if (value > 0) linked.add(value);
      }
    }

    for (final row in widget.data.diaryEntries) {
      final role = _s(row['author_role']).toLowerCase();
      if ((role == 'coach' || role == 'manager') &&
          _rowLinkedToMatch(row, match)) {
        final value = _n(row['rating']);
        if (value > 0) linked.add(value);
      }
    }

    return _average(linked);
  }

  double _selfRating(Map<String, dynamic> match) {
    for (final key in const [
      'self_rating',
      'player_rating',
      'self_assessment',
      'rating_self',
    ]) {
      final value = _n(match[key]);
      if (value > 0) return value;
    }

    final linked = <double>[];

    for (final row in widget.data.selfAssessments) {
      if (_rowLinkedToMatch(row, match)) {
        final value = _n(
          row['rating'] ??
              row['self_rating'] ??
              row['score'],
        );
        if (value > 0) linked.add(value);
      }
    }

    for (final row in widget.data.diaryEntries) {
      final role = _s(row['author_role']).toLowerCase();
      if (role == 'player' && _rowLinkedToMatch(row, match)) {
        final value = _n(row['rating']);
        if (value > 0) linked.add(value);
      }
    }

    return _average(linked);
  }

  String _noteForMatch(
    Map<String, dynamic> match, {
    required bool player,
  }) {
    final directKeys = player
        ? const [
            'player_note',
            'self_note',
            'player_comment',
          ]
        : const [
            'coach_note',
            'trainer_note',
            'coach_comment',
            'comment',
          ];

    for (final key in directKeys) {
      final value = _s(match[key]);
      if (value.isNotEmpty) return value;
    }

    for (final row in widget.data.diaryEntries.reversed) {
      final role = _s(row['author_role']).toLowerCase();
      final roleOk = player
          ? role == 'player'
          : role == 'coach' || role == 'manager';
      if (!roleOk || !_rowLinkedToMatch(row, match)) continue;

      final note = _s(
        row['note'] ??
            row['comment'] ??
            row['text'],
      );
      if (note.isNotEmpty) return note;
    }

    return '';
  }

  _MatchOutcome _outcome(Map<String, dynamic> match) {
    final raw = _s(
      match['result_type'] ??
          match['outcome'] ??
          match['status'],
    ).toLowerCase();

    if (raw.contains('win') || raw.contains('поб')) {
      return _MatchOutcome.win;
    }
    if (raw.contains('loss') ||
        raw.contains('lose') ||
        raw.contains('пор')) {
      return _MatchOutcome.loss;
    }
    if (raw.contains('draw') || raw.contains('нич')) {
      return _MatchOutcome.draw;
    }

    final score = _score(match);
    final parts = RegExp(r'(\d+)\s*[:\-]\s*(\d+)').firstMatch(score);
    if (parts != null) {
      final a = int.tryParse(parts.group(1) ?? '');
      final b = int.tryParse(parts.group(2) ?? '');
      if (a != null && b != null) {
        if (a > b) return _MatchOutcome.win;
        if (a < b) return _MatchOutcome.loss;
        return _MatchOutcome.draw;
      }
    }

    return _MatchOutcome.unknown;
  }

  Color _outcomeColor(_MatchOutcome outcome) {
    switch (outcome) {
      case _MatchOutcome.win:
        return PpColors.green;
      case _MatchOutcome.loss:
        return PpColors.red;
      case _MatchOutcome.draw:
        return PpColors.amber;
      case _MatchOutcome.unknown:
        return PpColors.muted2;
    }
  }

  List<Map<String, dynamic>> get _allMatches {
    final rows = widget.data.matches
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    rows.sort((a, b) {
      final ad = _matchDate(a);
      final bd = _matchDate(b);
      if (ad == null && bd == null) return 0;
      if (ad == null) return 1;
      if (bd == null) return -1;
      return bd.compareTo(ad);
    });

    return rows;
  }

  List<Map<String, dynamic>> get _visibleMatches {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return _allMatches.where((match) {
      final date = _matchDate(match);
      if (_selectedDate != null && !_sameDay(date, _selectedDate)) {
        return false;
      }

      if (date == null || _period == _MatchPeriod.all) return true;

      final day = DateTime(date.year, date.month, date.day);
      switch (_period) {
        case _MatchPeriod.all:
          return true;
        case _MatchPeriod.month:
          return !day.isBefore(today.subtract(const Duration(days: 29)));
        case _MatchPeriod.quarter:
          return !day.isBefore(today.subtract(const Duration(days: 89)));
        case _MatchPeriod.year:
          return day.year == today.year;
      }
    }).toList();
  }

  Set<String> _monthMatchDays() {
    return _allMatches
        .map(_matchDate)
        .whereType<DateTime>()
        .where(
          (date) =>
              date.year == _month.year && date.month == _month.month,
        )
        .map(
          (date) =>
              '${date.year}-${date.month}-${date.day}',
        )
        .toSet();
  }

  Color _calendarDayColor(DateTime date) {
    final matches = _allMatches
        .where((match) => _sameDay(_matchDate(match), date))
        .toList();
    if (matches.any((m) => _outcome(m) == _MatchOutcome.win)) {
      return PpColors.green;
    }
    if (matches.any((m) => _outcome(m) == _MatchOutcome.loss)) {
      return PpColors.red;
    }
    if (matches.any((m) => _outcome(m) == _MatchOutcome.draw)) {
      return PpColors.amber;
    }
    return PpColors.greenDark;
  }

  void _openMatch(Map<String, dynamic> match) {
    final open = widget.onOpenSidePanel;
    if (open == null) return;

    open(
      (close) => _PlayerMatchDetailPanel(
        match: match,
        date: _matchDate(match),
        opponent: _opponent(match),
        competition: _competition(match),
        score: _score(match),
        minutes: _minutes(match),
        coachRating: _coachRating(match),
        selfRating: _selfRating(match),
        ttd: _ttd(match),
        efficiency: _efficiency(match),
        coachNote: _noteForMatch(match, player: false),
        playerNote: _noteForMatch(match, player: true),
        outcomeColor: _outcomeColor(_outcome(match)),
        onClose: close,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final matches = _visibleMatches;
    final all = _allMatches;

    final coachValues =
        all.map(_coachRating).where((e) => e > 0).toList();
    final selfValues =
        all.map(_selfRating).where((e) => e > 0).toList();

    final wins =
        all.where((m) => _outcome(m) == _MatchOutcome.win).length;

    return Container(
      color: Colors.white,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 28),
        children: [
          Row(
            children: [
              const PpDotCluster(color: PpColors.green),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Матчи', style: PpText.title(18)),
                    const SizedBox(height: 3),
                    Text(
                      'Календарь, результаты, участие и оценки игрока',
                      style: PpText.body(10.2),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _summaryStrip(
            total: all.length,
            wins: wins,
            coach: _average(coachValues),
            self: _average(selfValues),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 920) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 292,
                      child: _calendar(),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _matchesWorkspace(matches),
                    ),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _calendar(),
                  const SizedBox(height: 10),
                  _matchesWorkspace(matches),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _summaryStrip({
    required int total,
    required int wins,
    required double coach,
    required double self,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final items = <Widget>[
          _summaryMetric(
            'Матчи',
            '$total',
            PpColors.green,
          ),
          _summaryMetric(
            'Победы',
            '$wins',
            PpColors.greenDark,
          ),
          _summaryMetric(
            'Оценка тренера',
            coach > 0 ? coach.toStringAsFixed(1) : '—',
            PpColors.amber,
          ),
          _summaryMetric(
            'Самооценка',
            self > 0 ? self.toStringAsFixed(1) : '—',
            PpColors.green,
          ),
        ];

        if (constraints.maxWidth >= 680) {
          return Row(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                Expanded(child: items[i]),
                if (i != items.length - 1)
                  const SizedBox(width: 6),
              ],
            ],
          );
        }

        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: items
              .map(
                (item) => SizedBox(
                  width: (constraints.maxWidth - 6) / 2,
                  child: item,
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _summaryMetric(
    String label,
    String value,
    Color color,
  ) {
    return PpSurface(
      color: Color.alphaBlend(
        color.withOpacity(.035),
        PpColors.soft,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 11,
        vertical: 9,
      ),
      child: Row(
        children: [
          PpDot(color: color, size: 6),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: PpText.body(9.8),
            ),
          ),
          const SizedBox(width: 8),
          Text(value, style: PpText.value(14)),
        ],
      ),
    );
  }

  Widget _calendar() {
    final first = DateTime(_month.year, _month.month, 1);
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    final leading = first.weekday - 1;
    final count = ((leading + days) / 7).ceil() * 7;
    final busy = _monthMatchDays();

    return PpSurface(
      color: PpColors.soft,
      padding: const EdgeInsets.all(11),
      child: Column(
        children: [
          Row(
            children: [
              const PpDotCluster(color: PpColors.greenDark),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  DateFormat('LLLL yyyy', 'ru')
                      .format(_month)
                      .replaceFirstMapped(
                        RegExp(r'^.'),
                        (m) => m.group(0)!.toUpperCase(),
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PpText.title(14),
                ),
              ),
              _calendarButton(
                Icons.chevron_left_rounded,
                () => setState(
                  () => _month =
                      DateTime(_month.year, _month.month - 1),
                ),
              ),
              const SizedBox(width: 4),
              _calendarButton(
                Icons.chevron_right_rounded,
                () => setState(
                  () => _month =
                      DateTime(_month.year, _month.month + 1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Row(
            children: [
              _MatchWeekday('ПН'),
              _MatchWeekday('ВТ'),
              _MatchWeekday('СР'),
              _MatchWeekday('ЧТ'),
              _MatchWeekday('ПТ'),
              _MatchWeekday('СБ'),
              _MatchWeekday('ВС'),
            ],
          ),
          const SizedBox(height: 5),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: count,
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 1,
            ),
            itemBuilder: (_, index) {
              final day = index - leading + 1;
              if (day < 1 || day > days) {
                return const SizedBox.shrink();
              }

              final date =
                  DateTime(_month.year, _month.month, day);
              final key = '${date.year}-${date.month}-${date.day}';
              final hasMatch = busy.contains(key);
              final selected = _sameDay(_selectedDate, date);
              final today = _sameDay(DateTime.now(), date);

              return Material(
                color: selected
                    ? PpColors.greenSoft
                    : Colors.white,
                borderRadius: BorderRadius.circular(7),
                child: InkWell(
                  onTap: hasMatch
                      ? () => setState(
                            () => _selectedDate =
                                selected ? null : date,
                          )
                      : null,
                  borderRadius: BorderRadius.circular(7),
                  child: Stack(
                    children: [
                      Center(
                        child: Text(
                          '$day',
                          style: PpText.body(
                            9.6,
                            color: selected
                                ? PpColors.greenDark
                                : hasMatch
                                    ? PpColors.text
                                    : PpColors.muted2,
                            weight:
                                selected || today || hasMatch
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                          ),
                        ),
                      ),
                      if (hasMatch)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 4,
                          child: Center(
                            child: PpDot(
                              color: _calendarDayColor(date),
                              size: selected ? 5.5 : 4,
                              glow: selected,
                            ),
                          ),
                        ),
                      if (today && !hasMatch)
                        const Positioned(
                          right: 4,
                          top: 4,
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
          if (_selectedDate != null) ...[
            const SizedBox(height: 8),
            Material(
              color: PpColors.greenSoft,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: () =>
                    setState(() => _selectedDate = null),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 7,
                  ),
                  child: Row(
                    children: [
                      const PpDot(
                        color: PpColors.green,
                        size: 5.5,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          DateFormat(
                            'd MMMM yyyy',
                            'ru',
                          ).format(_selectedDate!),
                          style: PpText.body(
                            10.2,
                            color: PpColors.greenDark,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Icon(
                        Icons.close_rounded,
                        size: 14,
                        color: PpColors.greenDark,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _calendarButton(
    IconData icon,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(7),
        child: SizedBox(
          width: 29,
          height: 29,
          child: Icon(
            icon,
            size: 16,
            color: PpColors.greenDark,
          ),
        ),
      ),
    );
  }

  Widget _matchesWorkspace(
    List<Map<String, dynamic>> matches,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _periodBar(),
        const SizedBox(height: 8),
        if (matches.isEmpty)
          const SizedBox(
            height: 260,
            child: PpSurface(
              color: PpColors.soft,
              child: PpEmpty(
                title: 'Матчей нет',
                text: 'Для выбранной даты или периода матчей нет',
              ),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1050
                  ? 3
                  : constraints.maxWidth >= 610
                      ? 2
                      : 1;
              final gap = 8.0;
              final width =
                  (constraints.maxWidth - gap * (columns - 1)) /
                      columns;

              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: matches
                    .map(
                      (match) => SizedBox(
                        width: width,
                        child: _matchCard(match),
                      ),
                    )
                    .toList(),
              );
            },
          ),
      ],
    );
  }

  Widget _periodBar() {
    const labels = <_MatchPeriod, String>{
      _MatchPeriod.all: 'Все',
      _MatchPeriod.month: '30 дней',
      _MatchPeriod.quarter: '90 дней',
      _MatchPeriod.year: 'Этот год',
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: labels.entries.map((entry) {
          final active = entry.key == _period;
          return Padding(
            padding: const EdgeInsets.only(right: 5),
            child: Material(
              color: active
                  ? PpColors.greenSoft
                  : PpColors.soft,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: () =>
                    setState(() => _period = entry.key),
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
                        size: active ? 5.5 : 4,
                        glow: active,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        entry.value,
                        style: PpText.body(
                          10.1,
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

  Widget _matchCard(Map<String, dynamic> match) {
    final date = _matchDate(match);
    final outcome = _outcome(match);
    final color = _outcomeColor(outcome);
    final coach = _coachRating(match);
    final self = _selfRating(match);
    final minutes = _minutes(match);
    final ttd = _ttd(match);
    final efficiency = _efficiency(match);

    return Material(
      color: PpColors.soft,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () => _openMatch(match),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  PpDot(
                    color: color,
                    size: 7,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      date == null
                          ? 'Без даты'
                          : DateFormat('dd.MM.yyyy').format(date),
                      style: PpText.caption(),
                    ),
                  ),
                  Text(
                    _score(match),
                    style: PpText.value(15),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Text(
                _opponent(match),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: PpText.title(14),
              ),
              const SizedBox(height: 3),
              Text(
                _competition(match),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: PpText.body(10),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _cardMetric(
                      'Минуты',
                      minutes,
                      PpColors.greenDark,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: _cardMetric(
                      'ТТД',
                      ttd,
                      PpColors.green,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: _cardMetric(
                      'Эффект',
                      efficiency,
                      PpColors.amber,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: _ratingPill(
                      'Тренер',
                      coach,
                      PpColors.greenDark,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: _ratingPill(
                      'Игрок',
                      self,
                      PpColors.amber,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  const PpDotCluster(color: PpColors.green),
                  const Spacer(),
                  Text(
                    'Подробнее',
                    style: PpText.body(
                      9.8,
                      color: PpColors.greenDark,
                      weight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 3),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 15,
                    color: PpColors.greenDark,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cardMetric(
    String label,
    String value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PpDot(
            color: color,
            size: 4,
            glow: false,
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: PpText.value(13),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: PpText.caption(size: 9.2),
          ),
        ],
      ),
    );
  }

  Widget _ratingPill(
    String label,
    double value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          color.withOpacity(.045),
          Colors.white,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          PpDot(
            color: color,
            size: 4.5,
            glow: value > 0,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: PpText.caption(size: 9.2),
            ),
          ),
          Text(
            value > 0 ? value.toStringAsFixed(1) : '—',
            style: PpText.body(
              10.2,
              color: PpColors.text,
              weight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerMatchDetailPanel extends StatelessWidget {
  final Map<String, dynamic> match;
  final DateTime? date;
  final String opponent;
  final String competition;
  final String score;
  final String minutes;
  final double coachRating;
  final double selfRating;
  final String ttd;
  final String efficiency;
  final String coachNote;
  final String playerNote;
  final Color outcomeColor;
  final VoidCallback onClose;

  const _PlayerMatchDetailPanel({
    required this.match,
    required this.date,
    required this.opponent,
    required this.competition,
    required this.score,
    required this.minutes,
    required this.coachRating,
    required this.selfRating,
    required this.ttd,
    required this.efficiency,
    required this.coachNote,
    required this.playerNote,
    required this.outcomeColor,
    required this.onClose,
  });

  String _s(dynamic value) => '${value ?? ''}'.trim();

  @override
  Widget build(BuildContext context) {
    final stadium = _s(
      match['stadium'] ??
          match['location'] ??
          match['venue'],
    );
    final position = _s(
      match['position'] ??
          match['player_position'] ??
          match['role'],
    );

    return Material(
      color: Colors.white,
      child: SafeArea(
        left: false,
        child: Column(
          children: [
            _header(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
                children: [
                  PpSurface(
                    color: PpColors.soft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            PpDot(
                              color: outcomeColor,
                              size: 8,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                opponent,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: PpText.title(16),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              score,
                              style: PpText.value(17),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          [
                            if (date != null)
                              DateFormat('dd.MM.yyyy').format(date!),
                            if (competition.isNotEmpty) competition,
                          ].join(' · '),
                          style: PpText.body(10.2),
                        ),
                        if (stadium.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            stadium,
                            style: PpText.caption(),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _section(
                    'Участие игрока',
                    PpColors.green,
                    [
                      _detailRow('Минуты', minutes),
                      if (position.isNotEmpty)
                        _detailRow('Позиция', position),
                      _detailRow('ТТД', ttd),
                      _detailRow('Эффективность', efficiency),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _section(
                    'Оценки',
                    PpColors.amber,
                    [
                      _ratingRow(
                        'Оценка тренера',
                        coachRating,
                        PpColors.greenDark,
                      ),
                      _ratingRow(
                        'Самооценка игрока',
                        selfRating,
                        PpColors.amber,
                      ),
                    ],
                  ),
                  if (coachNote.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _noteBlock(
                      'Комментарий тренера',
                      coachNote,
                      PpColors.greenDark,
                    ),
                  ],
                  if (playerNote.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _noteBlock(
                      'Заметка игрока',
                      playerNote,
                      PpColors.amber,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Container(
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
                        const PpDotCluster(color: PpColors.green),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            'Подробность открыта в правой рабочей колонке — основной список матчей остаётся на месте.',
                            style: PpText.body(
                              10.1,
                              color: PpColors.greenDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 8),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: PpColors.greenSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.sports_soccer_rounded,
              size: 19,
              color: PpColors.greenDark,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Матч игрока', style: PpText.title(16)),
                const SizedBox(height: 2),
                Text(
                  'результат, участие и оценки',
                  style: PpText.body(10.5),
                ),
              ],
            ),
          ),
          Material(
            color: PpColors.soft,
            borderRadius: BorderRadius.circular(9),
            child: InkWell(
              onTap: onClose,
              borderRadius: BorderRadius.circular(9),
              child: const SizedBox(
                width: 36,
                height: 36,
                child: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: PpColors.text,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(
    String title,
    Color color,
    List<Widget> children,
  ) {
    return PpSurface(
      color: PpColors.soft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PpSectionTitle(
            title: title,
            dotColor: color,
          ),
          const SizedBox(height: 9),
          ...children,
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: PpText.body(10.2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value.isEmpty ? '—' : value,
            style: PpText.body(
              10.6,
              color: PpColors.text,
              weight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _ratingRow(
    String label,
    double value,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          PpDot(
            color: color,
            size: 5,
            glow: value > 0,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              label,
              style: PpText.body(
                10.2,
                color: PpColors.text,
              ),
            ),
          ),
          Text(
            value > 0 ? value.toStringAsFixed(1) : '—',
            style: PpText.value(14),
          ),
        ],
      ),
    );
  }

  Widget _noteBlock(
    String title,
    String text,
    Color color,
  ) {
    return PpSurface(
      color: Color.alphaBlend(
        color.withOpacity(.035),
        PpColors.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PpSectionTitle(
            title: title,
            dotColor: color,
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: PpText.body(
              10.7,
              color: PpColors.text,
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchWeekday extends StatelessWidget {
  final String label;

  const _MatchWeekday(this.label);

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

enum _MatchPeriod {
  all,
  month,
  quarter,
  year,
}

enum _MatchOutcome {
  win,
  draw,
  loss,
  unknown,
}
