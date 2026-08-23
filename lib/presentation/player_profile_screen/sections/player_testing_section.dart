import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/player_profile_models.dart';
import '../widgets/player_profile_ui.dart';

class PlayerTestingSection extends StatefulWidget {
  final PlayerProfileSnapshot data;
  final int? userId;
  final VoidCallback? onBack;
  final void Function(Widget Function(VoidCallback close) builder)? onOpenSidePanel;

  const PlayerTestingSection({
    super.key,
    required this.data,
    this.userId,
    this.onBack,
    this.onOpenSidePanel,
  });

  @override
  State<PlayerTestingSection> createState() => _PlayerTestingSectionState();
}

class _PlayerTestingSectionState extends State<PlayerTestingSection> {
  late DateTime _month;
  DateTime? _from;
  DateTime? _to;
  bool _selectingRangeEnd = false;
  _TestingPreset _preset = _TestingPreset.all;
  StateSetter? _panelSetState;

  void _update(VoidCallback change) {
    if (!mounted) return;
    setState(change);
    _panelSetState?.call(() {});
  }

  String _s(dynamic value) => '${value ?? ''}'.trim();
  int _i(dynamic value) => value is num ? value.toInt() : int.tryParse(_s(value)) ?? 0;

  @override
  void initState() {
    super.initState();
    final latest = _allRows.isEmpty ? DateTime.now() : (_date(_allRows.first) ?? DateTime.now());
    _month = DateTime(latest.year, latest.month);
  }

  List<Map<String, dynamic>> get _allRows {
    final rows = [...widget.data.tests];
    rows.sort((a, b) => (_date(b) ?? DateTime(1970)).compareTo(_date(a) ?? DateTime(1970)));
    return rows;
  }

  List<Map<String, dynamic>> get _filteredRows {
    return _allRows.where((row) {
      final date = _date(row);
      if (date == null) return _from == null && _to == null;
      final day = DateTime(date.year, date.month, date.day);
      if (_from != null && day.isBefore(_from!)) return false;
      if (_to != null && day.isAfter(_to!)) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredRows;
    return ListView(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 24),
      children: [
        _testingToolbar(filtered.length),
        const SizedBox(height: 12),
        _resultsHeader(filtered.length),
        const SizedBox(height: 8),
        if (filtered.isEmpty)
          const SizedBox(
            height: 220,
            child: PpEmpty(
              icon: Icons.fact_check_outlined,
              title: 'Результаты не найдены',
              text: 'Выберите другой период или добавьте результаты в общем модуле тестирования.',
            ),
          )
        else
          ..._grouped(filtered),
      ],
    );
  }

  void _openCalendarPanel() {
    final open = widget.onOpenSidePanel;
    if (open == null) return;
    open((close) {
      final all = _allRows;
      final monthRows = all.where((e) {
        final d = _date(e);
        return d != null && d.year == _month.year && d.month == _month.month;
      }).toList();
      return StatefulBuilder(
        builder: (context, panelSetState) {
          _panelSetState = panelSetState;
          return Material(
            color: Colors.white,
            child: SafeArea(
          left: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: PpColors.greenSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: PpDotCluster(color: PpColors.amber),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Период тестирования', style: PpText.title(15.5)),
                          const SizedBox(height: 2),
                          Text(_rangeSubtitle(), maxLines: 1, overflow: TextOverflow.ellipsis, style: PpText.body(10.5)),
                        ],
                      ),
                    ),
                    _CalendarAction(icon: Icons.close_rounded, tooltip: 'Закрыть', onTap: () { _panelSetState = null; close(); }),
                    const SizedBox(width: 5),
                    _CalendarAction(icon: Icons.check_rounded, tooltip: 'Применить', onTap: () { _panelSetState = null; close(); }),
                  ],
                ),
              ),
              const Divider(height: 1, color: PpColors.line),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 18),
                  child: _calendarWorkspace(monthRows, all),
                ),
              ),
            ],
          ),
        ),
      );
        },
      );
    });
  }

  Widget _testingToolbar(int count) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Тестирование игрока', style: PpText.title(16)),
              const SizedBox(height: 2),
              Text('Результаты по датам и оценкам', style: PpText.body(10.5)),
            ],
          ),
        ),
        Material(
          color: PpColors.greenSoft,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: _openCalendarPanel,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const PpDot.amber(size: 6),
                  const SizedBox(width: 7),
                  Text(_preset == _TestingPreset.all ? 'Выбрать дату' : _rangeLabel(), style: PpText.body(11, color: PpColors.greenDark, weight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _calendarWorkspace(
    List<Map<String, dynamic>> monthRows,
    List<Map<String, dynamic>> all,
  ) {
    final selectedDays = _daysWithResults(all);
    final latestDate = all.isEmpty ? null : _date(all.first);

    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 680;
                return compact
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _calendarTitle(),
                          const SizedBox(height: 8),
                          _calendarActions(),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(child: _calendarTitle()),
                          _calendarActions(),
                        ],
                      );
              },
            ),
          ),
          _summaryRow(monthRows, latestDate),
          const SizedBox(height: 8),
          _presetFilters(),
          const SizedBox(height: 10),
          _monthGrid(selectedDays),
        ],
      ),
    );
  }

  Widget _calendarTitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_monthTitle(_month), style: PpText.title(18)),
        const SizedBox(height: 2),
        Text(
          _rangeSubtitle(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: PpText.body(10.5),
        ),
      ],
    );
  }

  Widget _calendarActions() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CalendarAction(
          icon: Icons.chevron_left_rounded,
          tooltip: 'Предыдущий месяц',
          onTap: () => _update(() => _month = DateTime(_month.year, _month.month - 1)),
        ),
        const SizedBox(width: 4),
        _CalendarAction(
          icon: Icons.chevron_right_rounded,
          tooltip: 'Следующий месяц',
          onTap: () => _update(() => _month = DateTime(_month.year, _month.month + 1)),
        ),
        const SizedBox(width: 4),
        _CalendarAction(
          icon: Icons.calendar_today_rounded,
          tooltip: 'Текущий месяц',
          onTap: () {
            final now = DateTime.now();
            _update(() => _month = DateTime(now.year, now.month));
          },
        ),
        const SizedBox(width: 4),
        _CalendarAction(
          icon: Icons.refresh_rounded,
          tooltip: 'Сбросить период',
          onTap: () => _update(() {
            _from = null;
            _to = null;
            _selectingRangeEnd = false;
            _preset = _TestingPreset.all;
          }),
        ),
      ],
    );
  }

  Widget _summaryRow(List<Map<String, dynamic>> monthRows, DateTime? latestDate) {
    final uniqueDays = monthRows.map(_date).whereType<DateTime>().map(_dayKey).toSet().length;
    final categories = monthRows
        .map((e) => _s(e['category_title'] ?? e['category']))
        .where((e) => e.isNotEmpty)
        .toSet()
        .length;

    final cells = <_SummaryData>[
      _SummaryData('Результатов', '${monthRows.length}', _monthTitle(_month)),
      _SummaryData('Дней тестов', '$uniqueDays', uniqueDays == 0 ? 'нет данных' : 'в выбранном месяце'),
      _SummaryData('Категорий', '$categories', categories == 0 ? 'не определены' : 'виды подготовки'),
      _SummaryData('Последний тест', latestDate == null ? '—' : DateFormat('dd.MM').format(latestDate), latestDate == null ? 'данных нет' : DateFormat('yyyy').format(latestDate)),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 720) {
          return SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: cells.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) => SizedBox(width: 150, child: _SummaryCell(data: cells[i])),
            ),
          );
        }
        return Row(
          children: [
            for (var i = 0; i < cells.length; i++) ...[
              Expanded(child: _SummaryCell(data: cells[i])),
              if (i != cells.length - 1) const SizedBox(width: 6),
            ],
          ],
        );
      },
    );
  }

  Widget _presetFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _PresetButton(
            label: 'Все',
            active: _preset == _TestingPreset.all,
            onTap: () => _setPreset(_TestingPreset.all),
          ),
          const SizedBox(width: 4),
          _PresetButton(
            label: '30 дней',
            active: _preset == _TestingPreset.days30,
            onTap: () => _setPreset(_TestingPreset.days30),
          ),
          const SizedBox(width: 4),
          _PresetButton(
            label: '3 месяца',
            active: _preset == _TestingPreset.months3,
            onTap: () => _setPreset(_TestingPreset.months3),
          ),
          const SizedBox(width: 4),
          _PresetButton(
            label: 'Год',
            active: _preset == _TestingPreset.year,
            onTap: () => _setPreset(_TestingPreset.year),
          ),
          const SizedBox(width: 8),
          _PresetButton(
            icon: Icons.calendar_month_rounded,
            label: _preset == _TestingPreset.range ? _rangeLabel() : 'Период',
            active: _preset == _TestingPreset.range,
            onTap: () => _update(() {
              _preset = _TestingPreset.range;
              _from = null;
              _to = null;
              _selectingRangeEnd = false;
            }),
          ),
        ],
      ),
    );
  }

  Widget _monthGrid(Set<String> resultDays) {
    final first = DateTime(_month.year, _month.month, 1);
    final leading = first.weekday - 1;
    final gridStart = first.subtract(Duration(days: leading));
    final totalCells = 42;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс']
                .map(
                  (e) => Expanded(
                    child: Center(
                      child: Text(
                        e,
                        style: PpText.body(10, weight: FontWeight.w600),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, constraints) {
            final cellHeight = constraints.maxWidth < 520 ? 45.0 : 48.0;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 5,
                crossAxisSpacing: 5,
                mainAxisExtent: cellHeight,
              ),
              itemCount: totalCells,
              itemBuilder: (_, index) {
                final day = gridStart.add(Duration(days: index));
                final currentMonth = day.month == _month.month;
                final hasResult = resultDays.contains(_dayKey(day));
                final isToday = _sameDay(day, DateTime.now());
                final inRange = _isInRange(day);
                final rangeEdge = _isRangeEdge(day);

                return Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _onDayTap(day),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: rangeEdge
                            ? PpColors.greenSoft
                            : inRange
                                ? const Color(0xFFF7FBF8)
                                : const Color(0xFFF7F8F7),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: rangeEdge
                              ? PpColors.greenBorder
                              : isToday
                                  ? PpColors.greenBorder
                                  : Colors.transparent,
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
                                weight: rangeEdge || isToday ? FontWeight.w700 : FontWeight.w600,
                              ),
                            ),
                          ),
                          if (hasResult)
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
        ),
      ],
    );
  }

  void _onDayTap(DateTime day) {
    final clean = DateTime(day.year, day.month, day.day);
    _update(() {
      if (day.month != _month.month) {
        _month = DateTime(day.year, day.month);
      }

      if (_preset != _TestingPreset.range) {
        _preset = _TestingPreset.range;
        _from = clean;
        _to = clean;
        _selectingRangeEnd = true;
        return;
      }

      if (!_selectingRangeEnd || _from == null) {
        _from = clean;
        _to = clean;
        _selectingRangeEnd = true;
        return;
      }

      if (clean.isBefore(_from!)) {
        _to = _from;
        _from = clean;
      } else {
        _to = clean;
      }
      _selectingRangeEnd = false;
    });
  }

  void _setPreset(_TestingPreset preset) {
    final today = DateTime.now();
    final end = DateTime(today.year, today.month, today.day);
    _update(() {
      _preset = preset;
      _selectingRangeEnd = false;
      switch (preset) {
        case _TestingPreset.all:
          _from = null;
          _to = null;
          break;
        case _TestingPreset.days30:
          _to = end;
          _from = end.subtract(const Duration(days: 29));
          break;
        case _TestingPreset.months3:
          _to = end;
          _from = DateTime(end.year, end.month - 3, end.day).add(const Duration(days: 1));
          break;
        case _TestingPreset.year:
          _to = end;
          _from = DateTime(end.year - 1, end.month, end.day).add(const Duration(days: 1));
          break;
        case _TestingPreset.range:
          break;
      }
    });
  }

  Widget _resultsHeader(int count) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('История тестирования', style: PpText.title(14.5)),
              const SizedBox(height: 2),
              Text(_rangeSubtitle(), style: PpText.body(10.5)),
            ],
          ),
        ),
        Text('$count', style: PpText.value(14)),
      ],
    );
  }

  List<Widget> _grouped(List<Map<String, dynamic>> rows) {
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final row in rows) {
      groups.putIfAbsent(_dayKey(_date(row)), () => []).add(row);
    }

    return groups.entries.map((entry) {
      final date = _date(entry.value.first);
      final categories = entry.value
          .map((e) => _s(e['category_title'] ?? e['category']))
          .where((e) => e.isNotEmpty)
          .toSet()
          .join(' · ');
      final finalRating = _finalRating(entry.value);

      return Padding(
        padding: const EdgeInsets.only(bottom: 15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  date == null ? 'Дата не указана' : DateFormat('dd.MM.yyyy').format(date),
                  style: PpText.title(13),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    categories.isEmpty ? 'Тестирование' : categories,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PpText.body(10.2),
                  ),
                ),
                _FinalRatingBadge(rating: finalRating),
                const SizedBox(width: 8),
                Text(
                  '${entry.value.length}',
                  style: PpText.body(10.2, color: PpColors.greenDark, weight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Divider(height: 1, color: PpColors.line),
            ...entry.value.map(_testRow),
          ],
        ),
      );
    }).toList();
  }

  Widget _testRow(Map<String, dynamic> row) {
    final name = _s(row['test_name']).isEmpty ? 'Тест' : _s(row['test_name']);
    final value = _s(row['value'] ?? row['result']);
    final unit = _s(row['unit']);
    final rating = _ratingLabel(row);
    final ratingColor = _ratingColor(row);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: PpText.body(11.2, color: PpColors.text, weight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            value.isEmpty ? '—' : '$value${unit.isEmpty ? '' : ' $unit'}',
            style: PpText.value(12),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 108,
            child: Text(
              rating,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: PpText.body(10, color: ratingColor, weight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Set<String> _daysWithResults(List<Map<String, dynamic>> rows) {
    return rows.map(_date).whereType<DateTime>().map(_dayKey).toSet();
  }

  bool _isInRange(DateTime date) {
    if (_from == null || _to == null) return false;
    final d = DateTime(date.year, date.month, date.day);
    return !d.isBefore(_from!) && !d.isAfter(_to!);
  }

  bool _isRangeEdge(DateTime date) {
    return (_from != null && _sameDay(date, _from!)) || (_to != null && _sameDay(date, _to!));
  }

  _FinalRating _finalRating(List<Map<String, dynamic>> rows) {
    final points = rows.map(_ratingPoints).where((value) => value > 0).toList();
    if (points.isEmpty) {
      return const _FinalRating('Без оценки', PpColors.muted, 0);
    }

    final average = points.reduce((a, b) => a + b) / points.length;
    if (average >= 3.6) {
      return _FinalRating('Отлично', PpColors.greenDark, average);
    }
    if (average >= 2.6) {
      return const _FinalRating('Хорошо', Color(0xFF947000), 3);
    }
    if (average >= 1.6) {
      return const _FinalRating('Удовлетворительно', Color(0xFFB45309), 2);
    }
    return _FinalRating('Ниже нормы', PpColors.red, average);
  }

  int _ratingPoints(Map<String, dynamic> row) {
    final direct = _i(row['points'] ?? row['rating_points'] ?? row['score_points']);
    if (direct >= 1 && direct <= 4) return direct;

    final code = _s(row['rating']).toLowerCase();
    switch (code) {
      case 'excellent':
        return 4;
      case 'good':
        return 3;
      case 'satisfactory':
        return 2;
      case 'poor':
        return 1;
    }

    final label = _ratingLabel(row).toLowerCase();
    if (label.contains('отлич')) return 4;
    if (label.contains('хорош')) return 3;
    if (label.contains('удов')) return 2;
    if (label.contains('ниже') || label.contains('неуд')) return 1;
    return 0;
  }

  String _ratingLabel(Map<String, dynamic> row) {
    final direct = _s(row['rating_label'] ?? row['label'] ?? row['grade']);
    if (direct.isNotEmpty) return direct;
    final code = _s(row['rating']).toLowerCase();
    switch (code) {
      case 'excellent':
        return 'Отлично';
      case 'good':
        return 'Хорошо';
      case 'satisfactory':
        return 'Удовлетворительно';
      case 'poor':
        return 'Ниже нормы';
    }
    final points = _i(row['points']);
    if (points >= 4) return 'Отлично';
    if (points == 3) return 'Хорошо';
    if (points == 2) return 'Удовлетворительно';
    if (points == 1) return 'Ниже нормы';
    return 'Без оценки';
  }

  Color _ratingColor(Map<String, dynamic> row) {
    final code = _s(row['rating']).toLowerCase();
    final label = _ratingLabel(row).toLowerCase();
    if (code == 'excellent' || label.contains('отлич')) return PpColors.greenDark;
    if (code == 'good' || label.contains('хорош')) return const Color(0xFF947000);
    if (code == 'satisfactory' || label.contains('удов')) return const Color(0xFFB45309);
    if (code == 'poor' || label.contains('ниже')) return PpColors.red;
    return PpColors.muted;
  }

  DateTime? _date(Map<String, dynamic> row) {
    return DateTime.tryParse(
      _s(row['test_date'] ?? row['date'] ?? row['created_at']).replaceAll(' ', 'T'),
    );
  }

  String _monthTitle(DateTime value) {
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
    return '${months[value.month - 1]} ${value.year}';
  }

  String _rangeSubtitle() {
    if (_from == null || _to == null) return 'Все сохранённые результаты игрока';
    return '${DateFormat('dd.MM.yyyy').format(_from!)} — ${DateFormat('dd.MM.yyyy').format(_to!)}';
  }

  String _rangeLabel() {
    if (_from == null || _to == null) return 'Период';
    return '${DateFormat('dd.MM').format(_from!)}–${DateFormat('dd.MM').format(_to!)}';
  }

  String _dayKey(DateTime? value) {
    if (value == null) return 'unknown';
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _FinalRating {
  final String label;
  final Color color;
  final double average;

  const _FinalRating(this.label, this.color, this.average);
}

class _FinalRatingBadge extends StatelessWidget {
  final _FinalRating rating;

  const _FinalRatingBadge({required this.rating});

  @override
  Widget build(BuildContext context) {
    final hasRating = rating.average > 0;
    return Container(
      constraints: const BoxConstraints(maxWidth: 142),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: hasRating ? rating.color.withOpacity(.08) : const Color(0xFFF7F8F7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: hasRating ? rating.color : PpColors.muted,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              rating.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: PpText.body(
                9.8,
                color: rating.color,
                weight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _TestingPreset { all, days30, months3, year, range }

class _CalendarAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _CalendarAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: PpColors.soft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: PpColors.text),
          ),
        ),
      ),
    );
  }
}

class _SummaryData {
  final String label;
  final String value;
  final String hint;

  const _SummaryData(this.label, this.value, this.hint);
}

class _SummaryCell extends StatelessWidget {
  final _SummaryData data;

  const _SummaryCell({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8F7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Text(data.value, style: PpText.value(13)),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  data.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PpText.body(9.5, color: PpColors.text, weight: FontWeight.w600),
                ),
                Text(
                  data.hint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PpText.body(8.7),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PresetButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  final IconData? icon;

  const _PresetButton({
    required this.label,
    required this.active,
    required this.onTap,
    this.icon,
  });

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
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: active ? PpColors.greenSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                PpDot(
                  size: active ? 6 : 5,
                  color: active ? PpColors.greenDark : PpColors.muted2,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: PpText.body(
                  10.5,
                  color: active ? PpColors.greenDark : PpColors.muted,
                  weight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
