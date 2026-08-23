import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/player_profile_models.dart';
import '../widgets/player_profile_ui.dart';

class PlayerOverviewSection extends StatelessWidget {
  final PlayerProfileSnapshot data;
  final PlayerProfileSession? session;

  const PlayerOverviewSection({
    super.key,
    required this.data,
    this.session,
  });

  int get attendancePercent {
    if (data.attendance.isEmpty) return 0;
    final present = data.attendance.where((row) {
      final status = '${row['status'] ?? ''}'.toLowerCase();
      return status.contains('present') || status.contains('прис');
    }).length;
    return (present / data.attendance.length * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
        children: [
          _OverviewHero(
            rating: data.compositeRating,
            readiness: _readiness(),
            attendance: attendancePercent,
            load: _loadLabel(),
          ),
          const SizedBox(height: 10),
          const PpThinDivider(margin: EdgeInsets.only(bottom: 10)),
          _PhysicalMetrics(data: data),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final latest = _LatestActivity(session: session);
              final status = _StatusPanel(data: data);

              if (constraints.maxWidth >= 820) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: latest),
                    const SizedBox(width: 12),
                    Expanded(child: status),
                  ],
                );
              }

              return Column(
                children: [
                  latest,
                  const SizedBox(height: 10),
                  status,
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          const PpThinDivider(margin: EdgeInsets.only(bottom: 10)),
          _Timeline(data: data),
        ],
      ),
    );
  }

  int _readiness() {
    if (session == null) return 60;
    return ((session!.maxSpeedKmh > 0 ? 75 : 55) +
            (session!.avgHr > 0 ? 10 : 0))
        .clamp(0, 100);
  }

  String _loadLabel() {
    if (session == null) return 'Нет данных';
    if (session!.distanceM > 5000) return 'Высокая';
    if (session!.distanceM > 2500) return 'Средняя';
    return 'Низкая';
  }
}

class _OverviewHero extends StatelessWidget {
  final int rating;
  final int readiness;
  final int attendance;
  final String load;

  const _OverviewHero({
    required this.rating,
    required this.readiness,
    required this.attendance,
    required this.load,
  });

  @override
  Widget build(BuildContext context) {
    final items = <({String label, String value, String note, Color color})>[
      (
        label: 'Рейтинг',
        value: rating > 0 ? '$rating' : '—',
        note: 'общий индекс',
        color: PpColors.green,
      ),
      (
        label: 'Готовность',
        value: '$readiness%',
        note: 'на сегодня',
        color: PpColors.amber,
      ),
      (
        label: 'Посещаемость',
        value: '$attendance%',
        note: 'за период',
        color: PpColors.greenDark,
      ),
      (
        label: 'Нагрузка',
        value: load,
        note: 'GPS + Polar',
        color: load == 'Высокая'
            ? PpColors.red
            : load == 'Средняя'
                ? PpColors.amber
                : PpColors.green,
      ),
    ];

    return PpSurface(
      elevated: true,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Обзор игрока', style: PpText.title(18)),
          const SizedBox(height: 4),
          Text(
            'Ключевые показатели, состояние и последняя активность',
            style: PpText.body(10.8),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 760 ? 4 : 2;
              final width =
                  (constraints.maxWidth - (columns - 1) * 8) / columns;

              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: items
                    .map(
                      (item) => SizedBox(
                        width: width,
                        child: PpMetric(
                          label: item.label,
                          value: item.value,
                          note: item.note,
                          dotColor: item.color,
                          dotSize: 5.5,
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LatestActivity extends StatelessWidget {
  final PlayerProfileSession? session;

  const _LatestActivity({this.session});

  @override
  Widget build(BuildContext context) {
    return PpSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PpSectionTitle(
            title: 'Последняя активность',
            subtitle: 'Последняя доступная сессия игрока',
            dotColor: PpColors.green,
          ),
          const SizedBox(height: 12),
          if (session == null)
            const SizedBox(
              height: 145,
              child: PpEmpty(
                title: 'Нет сессий',
                text: 'После тренировки здесь появятся показатели.',
              ),
            )
          else ...[
            Text(
              session!.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: PpText.title(14.5),
            ),
            const SizedBox(height: 4),
            Text(
              session!.date == null
                  ? 'Без даты'
                  : DateFormat('dd.MM.yyyy · HH:mm').format(session!.date!),
              style: PpText.body(10.4),
            ),
            const PpThinDivider(),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Value('Дистанция', '${(session!.distanceM / 1000).toStringAsFixed(1)} км', PpColors.green),
                _Value('Макс. скорость', '${session!.maxSpeedKmh.toStringAsFixed(1)} км/ч', PpColors.red),
                _Value('Спринты', '${session!.sprintCount}', PpColors.amber),
                _Value('Пульс', session!.avgHr > 0 ? '${session!.avgHr.round()} / ${session!.maxHr.round()}' : '—', PpColors.greenDark),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Value extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _Value(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 128,
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      decoration: BoxDecoration(
        color: PpColors.soft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PpDot(color: color, size: 5.5),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PpText.caption(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: PpText.value(13.5)),
        ],
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  final PlayerProfileSnapshot data;

  const _StatusPanel({required this.data});

  @override
  Widget build(BuildContext context) {
    final rows = <({String label, String value, Color color})>[
      (
        label: 'GPS / BLE',
        value: data.sessions.isEmpty ? 'Нет данных' : 'Есть данные',
        color: data.sessions.isEmpty ? PpColors.muted2 : PpColors.green,
      ),
      (
        label: 'Polar',
        value: data.sessions.any((item) => item.avgHr > 0)
            ? 'Есть данные'
            : 'Нет данных',
        color: data.sessions.any((item) => item.avgHr > 0)
            ? PpColors.green
            : PpColors.muted2,
      ),
      (
        label: 'Медицинские записи',
        value: data.medical.isEmpty ? 'Нет' : '${data.medical.length}',
        color: data.medical.isEmpty ? PpColors.muted2 : PpColors.amber,
      ),
      (
        label: 'Матчи',
        value: '${data.matches.length}',
        color: data.matches.isEmpty ? PpColors.muted2 : PpColors.greenDark,
      ),
    ];

    return PpSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PpSectionTitle(
            title: 'Состояние игрока',
            subtitle: 'Доступность данных профиля',
            dotColor: PpColors.amber,
          ),
          const SizedBox(height: 7),
          ...rows.asMap().entries.map((entry) {
            final index = entry.key;
            final row = entry.value;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    children: [
                      PpDot(color: row.color, size: 6),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          row.label,
                          style: PpText.body(
                            10.8,
                            color: PpColors.text,
                            weight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        row.value,
                        style: PpText.body(
                          10.8,
                          color: PpColors.text,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (index != rows.length - 1)
                  const PpThinDivider(margin: EdgeInsets.zero),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _PhysicalMetrics extends StatelessWidget {
  final PlayerProfileSnapshot data;

  const _PhysicalMetrics({required this.data});

  String _s(dynamic value) => '${value ?? ''}'.trim();

  String _value(dynamic value, String unit) {
    final text = _s(value);
    return text.isEmpty || text == 'null' ? '—' : '$text $unit';
  }

  @override
  Widget build(BuildContext context) {
    final player = data.player;
    final height =
        double.tryParse(_s(player['height']).replaceAll(',', '.')) ?? 0;
    final weight =
        double.tryParse(_s(player['weight']).replaceAll(',', '.')) ?? 0;
    final bmi = height > 0 && weight > 0
        ? (weight / ((height / 100) * (height / 100))).toStringAsFixed(1)
        : '—';
    final maxSession = data.trackerMaxHrSession;
    final restSession = data.trackerRestHrSession;

    final values = <({String label, String value, Color color})>[
      (label: 'Рост', value: _value(player['height'], 'см'), color: PpColors.green),
      (label: 'Вес', value: _value(player['weight'], 'кг'), color: PpColors.amber),
      (label: 'ИМТ', value: bmi, color: PpColors.greenDark),
      (
        label: 'Пульс покоя',
        value: restSession == null ? '—' : '${restSession.minHr.round()} уд/мин',
        color: PpColors.muted2,
      ),
      (
        label: 'HR max',
        value: maxSession == null ? '—' : '${maxSession.maxHr.round()} уд/мин',
        color: PpColors.red,
      ),
    ];

    return PpSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PpSectionTitle(
            title: 'Физические метрики',
            subtitle: 'Антропометрия и показатели Polar / трекера',
            dotColor: PpColors.greenDark,
          ),
          const SizedBox(height: 11),
          LayoutBuilder(
            builder: (context, constraints) {
              final count = constraints.maxWidth >= 900
                  ? 5
                  : constraints.maxWidth >= 600
                      ? 3
                      : 2;
              final width =
                  (constraints.maxWidth - (count - 1) * 8) / count;

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
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  final PlayerProfileSnapshot data;

  const _Timeline({required this.data});

  @override
  Widget build(BuildContext context) {
    return PpSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PpSectionTitle(
            title: 'История игрока',
            subtitle: 'Тренировки, матчи, трекер и тестирование в одной ленте',
            dotColor: PpColors.green,
          ),
          const SizedBox(height: 8),
          if (data.timeline.isEmpty)
            const SizedBox(
              height: 155,
              child: PpEmpty(
                title: 'История пока пуста',
                text: 'Записи появятся после тренировок, матчей и тестов.',
              ),
            )
          else
            ...data.timeline.take(12).toList().asMap().entries.map((entry) {
              final idx = entry.key;
              final item = entry.value;
              return Column(
                children: [
                  _TimelineRow(item: item),
                  if (idx != data.timeline.take(12).length - 1)
                    const PpThinDivider(margin: EdgeInsets.only(top: 4, bottom: 4)),
                ],
              );
            }),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final PlayerTimelineItem item;

  const _TimelineRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: PpDot(color: _accentForItem(item), size: 7),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: PpText.body(
                    11.2,
                    color: PpColors.text,
                    weight: FontWeight.w600,
                  ),
                ),
                if (item.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(item.subtitle, style: PpText.body(10.1)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            item.date == null ? '—' : DateFormat('dd.MM').format(item.date!),
            style: PpText.caption(),
          ),
        ],
      ),
    );
  }

  Color _accentForItem(PlayerTimelineItem item) {
    final text = '${item.title} ${item.subtitle}'.toLowerCase();
    if (text.contains('травм') || text.contains('мед')) return PpColors.red;
    if (text.contains('тест')) return PpColors.amber;
    return PpColors.green;
  }
}
