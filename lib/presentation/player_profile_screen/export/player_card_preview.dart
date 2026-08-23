import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/player_profile_models.dart';
import '../widgets/player_profile_ui.dart';

class PlayerCardPreview extends StatelessWidget {
  final PlayerProfileSnapshot data;
  final PlayerProfileSession? session;

  const PlayerCardPreview({
    super.key,
    required this.data,
    this.session,
  });

  String _s(dynamic value) => '${value ?? ''}'.trim();

  String _name() {
    final full = _s(
      data.player['full_name'] ??
          data.player['fullName'] ??
          data.player['name'],
    );
    if (full.isNotEmpty) return full;

    final last = _s(
      data.player['last_name'] ??
          data.player['lastName'] ??
          data.player['surname'],
    );
    final first = _s(
      data.player['first_name'] ??
          data.player['firstName'],
    );
    final value = '$last $first'.trim();
    return value.isEmpty ? 'Игрок' : value;
  }

  String _photo() {
    final raw = _s(
      data.player['photo'] ??
          data.player['photo_url'] ??
          data.player['avatar'] ??
          data.player['avatar_url'],
    );
    if (raw.isEmpty || raw == 'null') return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }
    final clean = raw.startsWith('/') ? raw.substring(1) : raw;
    return 'https://sportotekaapp.ru/$clean';
  }

  String _team() =>
      _s(data.player['team_name'] ?? data.player['teamName']);

  String _position() => _s(
        data.player['position'] ??
            data.player['amplua'] ??
            data.player['player_position'],
      );

  String _number() => _s(
        data.player['number'] ??
            data.player['shirt_number'] ??
            data.player['jersey_number'],
      );

  String _height() {
    final value = _s(data.player['height'] ?? data.player['height_cm']);
    return value.isEmpty ? '—' : '$value см';
  }

  String _weight() {
    final value = _s(data.player['weight'] ?? data.player['weight_kg']);
    return value.isEmpty ? '—' : '$value кг';
  }

  @override
  Widget build(BuildContext context) {
    final facts = <_FactData>[
      _FactData('Амплуа', _position().isEmpty ? '—' : _position(), PpColors.green),
      _FactData('Номер', _number().isEmpty ? '—' : '№ ${_number()}', PpColors.amber),
      _FactData('Рост', _height(), PpColors.greenDark),
      _FactData('Вес', _weight(), PpColors.amber),
      _FactData(
        'Тренер',
        data.coachRatingAverage > 0
            ? data.coachRatingAverage.toStringAsFixed(1)
            : '—',
        PpColors.green,
      ),
      _FactData(
        'Самооценка',
        data.selfRatingAverage > 0
            ? data.selfRatingAverage.toStringAsFixed(1)
            : '—',
        PpColors.greenDark,
      ),
    ];

    final tracker = <_FactData>[
      _FactData(
        'Дистанция',
        session == null
            ? '—'
            : '${(session!.distanceM / 1000).toStringAsFixed(2)} км',
        PpColors.green,
      ),
      _FactData(
        'Макс. скорость',
        session == null || session!.maxSpeedKmh <= 0
            ? '—'
            : '${session!.maxSpeedKmh.toStringAsFixed(1)} км/ч',
        PpColors.red,
      ),
      _FactData(
        'Спринты',
        session == null ? '—' : '${session!.sprintCount}',
        PpColors.amber,
      ),
      _FactData(
        'Средний пульс',
        session == null || session!.avgHr <= 0
            ? '—'
            : '${session!.avgHr.round()} уд/мин',
        PpColors.greenDark,
      ),
      _FactData(
        'HR max',
        data.trackerMaxHrSession == null
            ? '—'
            : '${data.trackerMaxHrSession!.maxHr.round()} уд/мин',
        PpColors.red,
      ),
      _FactData(
        'Пульс покоя',
        data.trackerRestHrSession == null
            ? '—'
            : '${data.trackerRestHrSession!.minHr.round()} уд/мин',
        PpColors.green,
      ),
    ];

    return Column(
      children: [
        _Identity(
          name: _name(),
          photo: _photo(),
          team: _team(),
          position: _position(),
          number: _number(),
          rating: data.compositeRating,
        ),
        const PpThinDivider(
          margin: EdgeInsets.symmetric(vertical: 12),
        ),
        _StatStrip(data: data),
        const PpThinDivider(
          margin: EdgeInsets.symmetric(vertical: 12),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final profile = _FactSection(
              title: 'Профиль',
              subtitle: 'Основные спортивные данные',
              dotColor: PpColors.greenDark,
              rows: facts,
            );
            final form = _FactSection(
              title: 'Форма и трекер',
              subtitle: 'Последняя доступная GPS / Polar сессия',
              dotColor: PpColors.amber,
              rows: tracker,
            );

            if (constraints.maxWidth >= 800) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: profile),
                  const SizedBox(width: 26),
                  Expanded(child: form),
                ],
              );
            }

            return Column(
              children: [
                profile,
                const PpThinDivider(
                  margin: EdgeInsets.symmetric(vertical: 12),
                ),
                form,
              ],
            );
          },
        ),
        const PpThinDivider(
          margin: EdgeInsets.symmetric(vertical: 12),
        ),
        _RecentEvents(data: data),
      ],
    );
  }
}

class _Identity extends StatelessWidget {
  final String name;
  final String photo;
  final String team;
  final String position;
  final String number;
  final int rating;

  const _Identity({
    required this.name,
    required this.photo,
    required this.team,
    required this.position,
    required this.number,
    required this.rating,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        final size = compact ? 58.0 : 68.0;

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: size,
              height: size,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: PpColors.soft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: photo.isEmpty
                  ? Center(
                      child: Text(
                        _initials(name),
                        style: PpText.title(16),
                      ),
                    )
                  : Image.network(
                      photo,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Center(
                        child: Text(
                          _initials(name),
                          style: PpText.title(16),
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PpText.title(18),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    <String>[
                      if (team.isNotEmpty) team,
                      if (position.isNotEmpty) position,
                      if (number.isNotEmpty) '№ $number',
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PpText.body(10.6),
                  ),
                  const SizedBox(height: 7),
                  const PpDotCluster(),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 9,
              ),
              decoration: BoxDecoration(
                color: PpColors.greenSoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    rating > 0 ? '$rating' : '—',
                    style: PpText.value(17),
                  ),
                  const SizedBox(width: 5),
                  Text('/100', style: PpText.caption()),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatStrip extends StatelessWidget {
  final PlayerProfileSnapshot data;

  const _StatStrip({required this.data});

  @override
  Widget build(BuildContext context) {
    final values = <_StatData>[
      _StatData(
        'Рейтинг',
        data.compositeRating > 0 ? '${data.compositeRating}' : '—',
        PpColors.green,
      ),
      _StatData(
        'Посещаемость',
        '${data.attendancePercent}%',
        PpColors.greenDark,
      ),
      _StatData('Матчи', '${data.matches.length}', PpColors.amber),
      _StatData('Тесты', '${data.tests.length}', PpColors.red),
      _StatData('GPS', '${data.sessions.length}', PpColors.green),
      _StatData('Документы', '${data.documents.length}', PpColors.greenDark),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 6
            : constraints.maxWidth >= 600
                ? 3
                : 2;
        final width =
            (constraints.maxWidth - (columns - 1) * 8) / columns;

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
    );
  }
}

class _StatData {
  final String label;
  final String value;
  final Color color;

  const _StatData(this.label, this.value, this.color);
}

class _FactData {
  final String label;
  final String value;
  final Color color;

  const _FactData(this.label, this.value, this.color);
}

class _FactSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color dotColor;
  final List<_FactData> rows;

  const _FactSection({
    required this.title,
    required this.subtitle,
    required this.dotColor,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PpSectionTitle(
          title: title,
          subtitle: subtitle,
          dotColor: dotColor,
        ),
        const SizedBox(height: 7),
        ...rows.asMap().entries.map((entry) {
          final row = entry.value;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Row(
                  children: [
                    PpDot(color: row.color, size: 5.5),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        row.label,
                        style: PpText.body(10.6),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        row.value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PpText.body(
                          10.6,
                          color: PpColors.text,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (entry.key != rows.length - 1)
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

class _RecentEvents extends StatelessWidget {
  final PlayerProfileSnapshot data;

  const _RecentEvents({required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PpSectionTitle(
          title: 'Последние события',
          subtitle: 'Тренировки, матчи, тесты и трекер',
          dotColor: PpColors.green,
        ),
        const SizedBox(height: 7),
        if (data.timeline.isEmpty)
          const SizedBox(
            height: 130,
            child: PpEmpty(
              title: 'Событий пока нет',
              text: 'История заполнится автоматически',
            ),
          )
        else
          ...data.timeline.take(8).toList().asMap().entries.map(
                (entry) => Column(
                  children: [
                    _EventRow(item: entry.value),
                    if (entry.key !=
                        data.timeline.take(8).length - 1)
                      const PpThinDivider(
                        margin: EdgeInsets.zero,
                      ),
                  ],
                ),
              ),
      ],
    );
  }
}

class _EventRow extends StatelessWidget {
  final PlayerTimelineItem item;

  const _EventRow({required this.item});

  Color get color {
    final raw =
        '${item.type} ${item.title} ${item.subtitle}'.toLowerCase();
    if (raw.contains('мед') || raw.contains('травм')) {
      return PpColors.red;
    }
    if (raw.contains('тест')) return PpColors.amber;
    if (raw.contains('tracker')) return PpColors.greenDark;
    return PpColors.green;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: PpDot(color: color, size: 7),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: PpText.body(
                    11,
                    color: PpColors.text,
                    weight: FontWeight.w600,
                  ),
                ),
                if (item.subtitle.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(item.subtitle, style: PpText.body(10.2)),
                ],
              ],
            ),
          ),
          if (item.date != null) ...[
            const SizedBox(width: 8),
            Text(
              DateFormat('dd.MM').format(item.date!),
              style: PpText.caption(),
            ),
          ],
        ],
      ),
    );
  }
}

String _initials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((item) => item.isNotEmpty)
      .toList();
  if (parts.isEmpty) return 'И';
  if (parts.length == 1) {
    return parts.first.substring(0, 1).toUpperCase();
  }
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}
