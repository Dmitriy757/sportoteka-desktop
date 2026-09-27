import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/esports_profile.dart';
import '../models/player_profile_models.dart';
import '../widgets/player_profile_ui.dart';

class EsportsOverviewSection extends StatelessWidget {
  final PlayerProfileSnapshot data;

  const EsportsOverviewSection({
    super.key,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final player = data.player;
    final matches = _sortedMatches(data.matches);
    final aggregate = EsportsAggregate.fromMatches(matches);
    final nickname = esportsNickname(player);
    final realName = esportsRealName(player);
    final game = esportsGame(player);
    final platform = esportsPlatform(player);
    final mode = esportsMode(player);
    final rating = esportsRating(player);
    final rank = esportsRank(player);
    final region = esportsRegion(player);
    final team = esportsTeam(player);

    final identity = <_InfoValue>[
      _InfoValue('Игра', game),
      _InfoValue('Платформа', platform),
      _InfoValue('Режим', mode),
      _InfoValue('Рейтинг', rating),
      _InfoValue('Ранг / дивизион', rank),
      _InfoValue('Регион', region),
      _InfoValue('Команда', team),
    ].where((item) => item.value.isNotEmpty).toList(growable: false);

    return Container(
      color: Colors.white,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          Row(
            children: [
              const PpDotCluster(color: PpColors.green),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Киберспортивный профиль', style: PpText.title(18)),
                    const SizedBox(height: 3),
                    Text(
                      _joinNonEmpty(<String>[game, platform, mode]),
                      style: PpText.body(10.2),
                    ),
                  ],
                ),
              ),
              _CyberBadge(label: 'CYBER'),
            ],
          ),
          const PpThinDivider(
            margin: EdgeInsets.symmetric(vertical: 12),
          ),
          PpSurface(
            color: PpColors.greenSoft2,
            bordered: true,
            padding: const EdgeInsets.all(14),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 620;
                final title = nickname.isNotEmpty
                    ? nickname
                    : (realName.isNotEmpty ? realName : 'Киберспортсмен');
                final subtitle = nickname.isNotEmpty && realName.isNotEmpty
                    ? realName
                    : _joinNonEmpty(<String>[game, platform]);

                final identityBlock = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.sports_esports_rounded,
                            size: 22,
                            color: PpColors.greenDark,
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: PpText.title(18),
                              ),
                              if (subtitle.isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(
                                  subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: PpText.body(10.6),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (_joinNonEmpty(<String>[mode, rank, region]).isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        _joinNonEmpty(<String>[mode, rank, region]),
                        style: PpText.body(10.4),
                      ),
                    ],
                  ],
                );

                final ratingBlock = PpSurface(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const PpDot(color: PpColors.greenDark, size: 7),
                      const SizedBox(width: 9),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Текущий рейтинг', style: PpText.caption()),
                          const SizedBox(height: 4),
                          Text(
                            rating.isEmpty ? '—' : rating,
                            style: PpText.value(17),
                          ),
                        ],
                      ),
                    ],
                  ),
                );

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      identityBlock,
                      const SizedBox(height: 10),
                      ratingBlock,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: identityBlock),
                    const SizedBox(width: 12),
                    ratingBlock,
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          _MetricGrid(
            metrics: <_MetricValue>[
              _MetricValue(
                'Матчи',
                aggregate.played.toString(),
                'в профиле',
                PpColors.green,
              ),
              _MetricValue(
                'Победы',
                aggregate.played == 0
                    ? '—'
                    : '${aggregate.winRate.toStringAsFixed(0)}%',
                '${aggregate.wins} из ${aggregate.played}',
                PpColors.greenDark,
              ),
              _MetricValue(
                'Голы / матч',
                aggregate.played == 0
                    ? '—'
                    : aggregate.goalsPerMatch.toStringAsFixed(2),
                '${aggregate.goalsFor}:${aggregate.goalsAgainst}',
                PpColors.amber,
              ),
              _MetricValue(
                'Разница',
                aggregate.played == 0
                    ? '—'
                    : _signed(aggregate.goalDifference),
                'голы',
                aggregate.goalDifference >= 0
                    ? PpColors.green
                    : PpColors.red,
              ),
            ],
          ),
          const PpThinDivider(
            margin: EdgeInsets.symmetric(vertical: 12),
          ),
          _FormStrip(matches: matches.take(10).toList(growable: false)),
          if (identity.isNotEmpty) ...[
            const PpThinDivider(
              margin: EdgeInsets.symmetric(vertical: 12),
            ),
            PpSectionTitle(
              title: 'Игровой паспорт',
              subtitle: 'Данные профиля киберспортсмена',
              dotColor: PpColors.greenDark,
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final twoColumns = constraints.maxWidth >= 760;
                final width = twoColumns
                    ? (constraints.maxWidth - 10) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: identity
                      .map(
                        (item) => SizedBox(
                          width: width,
                          child: PpSurface(
                            color: PpColors.soft,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 11,
                            ),
                            child: Row(
                              children: [
                                const PpDot(
                                  color: PpColors.green,
                                  size: 5,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    item.label,
                                    style: PpText.body(10.4),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Flexible(
                                  child: Text(
                                    item.value,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.right,
                                    style: PpText.body(
                                      10.4,
                                      color: PpColors.text,
                                      weight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                      .toList(growable: false),
                );
              },
            ),
          ],
          const PpThinDivider(
            margin: EdgeInsets.symmetric(vertical: 12),
          ),
          PpSectionTitle(
            title: 'Последние матчи',
            subtitle: matches.isEmpty
                ? 'После подключения игрового API здесь появятся результаты'
                : 'Последние результаты и турниры',
            dotColor: PpColors.green,
          ),
          const SizedBox(height: 10),
          if (matches.isEmpty)
            const PpEmpty(
              title: 'Матчей пока нет',
              text:
                  'Экран уже готов принимать результаты EA Sports FC, eFootball и других дисциплин.',
              icon: Icons.sports_esports_rounded,
            )
          else
            ...matches.take(5).map(
                  (match) => Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: _EsportsMatchRow(match: match),
                  ),
                ),
        ],
      ),
    );
  }
}

class EsportsMatchesSection extends StatelessWidget {
  final PlayerProfileSnapshot data;

  const EsportsMatchesSection({
    super.key,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final matches = _sortedMatches(data.matches);
    final aggregate = EsportsAggregate.fromMatches(matches);

    return Container(
      color: Colors.white,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          PpSectionTitle(
            title: 'Матчи',
            subtitle: matches.isEmpty
                ? 'Результаты киберспортивных матчей'
                : '${matches.length} матчей · ${aggregate.wins} побед · ${aggregate.draws} ничьих · ${aggregate.losses} поражений',
            dotColor: PpColors.green,
          ),
          const SizedBox(height: 10),
          _MetricGrid(
            metrics: <_MetricValue>[
              _MetricValue(
                'Победы',
                aggregate.wins.toString(),
                aggregate.played == 0
                    ? '—'
                    : '${aggregate.winRate.toStringAsFixed(0)}%',
                PpColors.greenDark,
              ),
              _MetricValue(
                'Ничьи',
                aggregate.draws.toString(),
                'из ${aggregate.played}',
                PpColors.amber,
              ),
              _MetricValue(
                'Поражения',
                aggregate.losses.toString(),
                'из ${aggregate.played}',
                PpColors.red,
              ),
              _MetricValue(
                'Голы',
                '${aggregate.goalsFor}:${aggregate.goalsAgainst}',
                'разница ${_signed(aggregate.goalDifference)}',
                PpColors.green,
              ),
            ],
          ),
          const PpThinDivider(
            margin: EdgeInsets.symmetric(vertical: 12),
          ),
          _FormStrip(matches: matches.take(10).toList(growable: false)),
          const SizedBox(height: 12),
          if (matches.isEmpty)
            const PpEmpty(
              title: 'Нет результатов',
              text:
                  'Когда сервер начнёт отдавать киберспортивные матчи, они автоматически появятся на этом экране.',
              icon: Icons.sports_esports_rounded,
            )
          else
            ...matches.map(
              (match) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _EsportsMatchCard(match: match),
              ),
            ),
        ],
      ),
    );
  }
}

class EsportsStatisticsSection extends StatelessWidget {
  final PlayerProfileSnapshot data;

  const EsportsStatisticsSection({
    super.key,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final matches = _sortedMatches(data.matches);
    final aggregate = EsportsAggregate.fromMatches(matches);
    final rating = esportsRating(data.player);
    final rank = esportsRank(data.player);

    return Container(
      color: Colors.white,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          PpSectionTitle(
            title: 'Игровая статистика',
            subtitle:
                'Результативность, владение, удары, передачи и текущий рейтинг',
            dotColor: PpColors.greenDark,
          ),
          const SizedBox(height: 10),
          _MetricGrid(
            metrics: <_MetricValue>[
              _MetricValue(
                'Рейтинг',
                rating.isEmpty ? '—' : rating,
                rank.isEmpty ? 'текущий' : rank,
                PpColors.greenDark,
              ),
              _MetricValue(
                'Win rate',
                aggregate.played == 0
                    ? '—'
                    : '${aggregate.winRate.toStringAsFixed(0)}%',
                '${aggregate.wins} побед',
                PpColors.green,
              ),
              _MetricValue(
                'Голы / матч',
                aggregate.played == 0
                    ? '—'
                    : aggregate.goalsPerMatch.toStringAsFixed(2),
                'пропущено ${aggregate.concededPerMatch.toStringAsFixed(2)}',
                PpColors.amber,
              ),
              _MetricValue(
                'xG / матч',
                aggregate.avgXg <= 0
                    ? '—'
                    : aggregate.avgXg.toStringAsFixed(2),
                'по доступным матчам',
                PpColors.green,
              ),
            ],
          ),
          const PpThinDivider(
            margin: EdgeInsets.symmetric(vertical: 12),
          ),
          PpSectionTitle(
            title: 'Средние показатели',
            subtitle: 'Рассчитываются по сохранённым матчам',
            dotColor: PpColors.amber,
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final twoColumns = constraints.maxWidth >= 720;
              final width = twoColumns
                  ? (constraints.maxWidth - 10) / 2
                  : constraints.maxWidth;
              final rows = <_StatBarData>[
                _StatBarData(
                  'Владение',
                  aggregate.avgPossession,
                  100,
                  aggregate.avgPossession <= 0
                      ? '—'
                      : '${aggregate.avgPossession.toStringAsFixed(1)}%',
                  PpColors.green,
                ),
                _StatBarData(
                  'Точность передач',
                  aggregate.avgPassAccuracy,
                  100,
                  aggregate.avgPassAccuracy <= 0
                      ? '—'
                      : '${aggregate.avgPassAccuracy.toStringAsFixed(1)}%',
                  PpColors.greenDark,
                ),
                _StatBarData(
                  'Удары',
                  aggregate.avgShots,
                  20,
                  aggregate.avgShots <= 0
                      ? '—'
                      : aggregate.avgShots.toStringAsFixed(1),
                  PpColors.amber,
                ),
                _StatBarData(
                  'В створ',
                  aggregate.avgShotsOnTarget,
                  12,
                  aggregate.avgShotsOnTarget <= 0
                      ? '—'
                      : aggregate.avgShotsOnTarget.toStringAsFixed(1),
                  PpColors.green,
                ),
              ];
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: rows
                    .map(
                      (row) => SizedBox(
                        width: width,
                        child: _StatBar(data: row),
                      ),
                    )
                    .toList(growable: false),
              );
            },
          ),
          const PpThinDivider(
            margin: EdgeInsets.symmetric(vertical: 12),
          ),
          _FormStrip(matches: matches.take(10).toList(growable: false)),
          if (matches.isEmpty) ...[
            const SizedBox(height: 12),
            const PpEmpty(
              title: 'Статистика появится после матчей',
              text:
                  'Поддержаны поля possession, shots, shots_on_target, xg и pass_accuracy. До подключения API экран останется аккуратно пустым.',
              icon: Icons.query_stats_rounded,
            ),
          ],
        ],
      ),
    );
  }
}

class EsportsTournamentsSection extends StatelessWidget {
  final PlayerProfileSnapshot data;

  const EsportsTournamentsSection({
    super.key,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final matches = _sortedMatches(data.matches);
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final match in matches) {
      final name = esportsCompetition(match).isEmpty
          ? 'Без турнира'
          : esportsCompetition(match);
      groups.putIfAbsent(name, () => <Map<String, dynamic>>[]).add(match);
    }

    final entries = groups.entries.toList(growable: false)
      ..sort((a, b) {
        final ad = a.value.map(esportsMatchDate).whereType<DateTime>().toList();
        final bd = b.value.map(esportsMatchDate).whereType<DateTime>().toList();
        final aDate = ad.isEmpty
            ? DateTime.fromMillisecondsSinceEpoch(0)
            : ad.reduce((x, y) => x.isAfter(y) ? x : y);
        final bDate = bd.isEmpty
            ? DateTime.fromMillisecondsSinceEpoch(0)
            : bd.reduce((x, y) => x.isAfter(y) ? x : y);
        return bDate.compareTo(aDate);
      });

    return Container(
      color: Colors.white,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          PpSectionTitle(
            title: 'Турниры',
            subtitle:
                'Киберлиги, кубки и серии матчей автоматически группируются по названию турнира',
            dotColor: PpColors.amber,
          ),
          const SizedBox(height: 10),
          if (entries.isEmpty)
            const PpEmpty(
              title: 'Турниров пока нет',
              text:
                  'Когда у матчей появится tournament, competition или league, Спортотека соберёт их в турнирные карточки автоматически.',
              icon: Icons.emoji_events_outlined,
            )
          else
            ...entries.map((entry) {
              final aggregate = EsportsAggregate.fromMatches(entry.value);
              final dated = entry.value
                  .map(esportsMatchDate)
                  .whereType<DateTime>()
                  .toList(growable: false);
              final lastDate = dated.isEmpty
                  ? null
                  : dated.reduce((a, b) => a.isAfter(b) ? a : b);

              return Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: PpSurface(
                  color: PpColors.soft,
                  padding: const EdgeInsets.all(13),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: PpColors.amberSoft,
                              borderRadius: BorderRadius.circular(9),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.emoji_events_outlined,
                              size: 18,
                              color: PpColors.amber,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.key,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: PpText.title(14),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  lastDate == null
                                      ? '${aggregate.played} матчей'
                                      : '${aggregate.played} матчей · ${_dateLabel(lastDate)}',
                                  style: PpText.body(10.2),
                                ),
                              ],
                            ),
                          ),
                          _CyberBadge(
                            label: '${aggregate.wins}-${aggregate.draws}-${aggregate.losses}',
                            compact: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          _SmallValue(
                            label: 'Win rate',
                            value: aggregate.played == 0
                                ? '—'
                                : '${aggregate.winRate.toStringAsFixed(0)}%',
                          ),
                          _SmallValue(
                            label: 'Голы',
                            value:
                                '${aggregate.goalsFor}:${aggregate.goalsAgainst}',
                          ),
                          _SmallValue(
                            label: 'Разница',
                            value: _signed(aggregate.goalDifference),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _EsportsMatchCard extends StatelessWidget {
  final Map<String, dynamic> match;

  const _EsportsMatchCard({required this.match});

  @override
  Widget build(BuildContext context) {
    final outcome = esportsOutcome(match);
    final opponent = esportsOpponent(match);
    final competition = esportsCompetition(match);
    final date = esportsMatchDate(match);
    final possession = esportsPercent(
      match['possession'] ??
          match['possession_percent'] ??
          match['ball_possession'],
    );
    final passAccuracy = esportsPercent(
      match['pass_accuracy'] ??
          match['passes_accuracy'] ??
          match['pass_accuracy_percent'],
    );
    final shots = esportsMetric(match, const [
      'shots',
      'shots_total',
      'total_shots',
    ]);
    final xg = esportsMetric(match, const ['xg', 'expected_goals']);

    return PpSurface(
      color: PpColors.soft,
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _OutcomeBadge(outcome: outcome),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      opponent.isEmpty ? 'Соперник' : opponent,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PpText.title(14),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _joinNonEmpty(<String>[
                        competition,
                        if (date != null) _dateLabel(date),
                      ]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PpText.body(10.2),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(esportsScore(match), style: PpText.value(17)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              if (possession != '—')
                _SmallValue(label: 'Владение', value: possession),
              if (shots != '—') _SmallValue(label: 'Удары', value: shots),
              if (xg != '—') _SmallValue(label: 'xG', value: xg),
              if (passAccuracy != '—')
                _SmallValue(label: 'Передачи', value: passAccuracy),
              if (possession == '—' &&
                  shots == '—' &&
                  xg == '—' &&
                  passAccuracy == '—')
                const _SmallValue(
                  label: 'Аналитика',
                  value: 'нет данных',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EsportsMatchRow extends StatelessWidget {
  final Map<String, dynamic> match;

  const _EsportsMatchRow({required this.match});

  @override
  Widget build(BuildContext context) {
    final outcome = esportsOutcome(match);
    final opponent = esportsOpponent(match);
    final date = esportsMatchDate(match);
    return PpSurface(
      color: PpColors.soft,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      child: Row(
        children: [
          _OutcomeBadge(outcome: outcome, compact: true),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  opponent.isEmpty ? 'Соперник' : opponent,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PpText.body(
                    10.6,
                    color: PpColors.text,
                    weight: FontWeight.w600,
                  ),
                ),
                if (date != null || esportsCompetition(match).isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    _joinNonEmpty(<String>[
                      esportsCompetition(match),
                      if (date != null) _dateLabel(date),
                    ]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PpText.caption(),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(esportsScore(match), style: PpText.value(14)),
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  final List<_MetricValue> metrics;

  const _MetricGrid({required this.metrics});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900
            ? 4
            : constraints.maxWidth >= 560
                ? 2
                : 1;
        final width = (constraints.maxWidth - ((columns - 1) * 10)) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: metrics
              .map(
                (metric) => SizedBox(
                  width: width,
                  child: PpMetric(
                    label: metric.label,
                    value: metric.value,
                    note: metric.note,
                    dotColor: metric.color,
                  ),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _FormStrip extends StatelessWidget {
  final List<Map<String, dynamic>> matches;

  const _FormStrip({required this.matches});

  @override
  Widget build(BuildContext context) {
    return PpSurface(
      color: PpColors.soft,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final label = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Последняя форма', style: PpText.body(10.2)),
              const SizedBox(height: 3),
              Text(
                matches.isEmpty
                    ? 'Матчей пока нет'
                    : 'Последние ${matches.length} матчей',
                style: PpText.caption(),
              ),
            ],
          );

          final form = matches.isEmpty
              ? Text('—', style: PpText.value(15))
              : Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: matches
                      .map(
                        (match) => _OutcomeBadge(
                          outcome: esportsOutcome(match),
                          compact: true,
                        ),
                      )
                      .toList(growable: false),
                );

          if (constraints.maxWidth < 520) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                label,
                const SizedBox(height: 9),
                form,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: label),
              const SizedBox(width: 10),
              Flexible(child: form),
            ],
          );
        },
      ),
    );
  }
}

class _OutcomeBadge extends StatelessWidget {
  final EsportsMatchOutcome outcome;
  final bool compact;

  const _OutcomeBadge({
    required this.outcome,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = _outcomeColor(outcome);
    final label = esportsOutcomeLetter(outcome);
    return Container(
      width: compact ? 27 : 34,
      height: compact ? 27 : 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Color.alphaBlend(color.withOpacity(.08), Colors.white),
        borderRadius: BorderRadius.circular(compact ? 8 : 9),
      ),
      child: Text(
        label,
        style: PpText.body(
          compact ? 10.2 : 11,
          color: color,
          weight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CyberBadge extends StatelessWidget {
  final String label;
  final bool compact;

  const _CyberBadge({
    required this.label,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 5 : 6,
      ),
      decoration: BoxDecoration(
        color: PpColors.greenSoft,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: PpText.caption(
          size: compact ? 9.5 : 10.2,
          color: PpColors.greenDark,
        ).copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _SmallValue extends StatelessWidget {
  final String label;
  final String value;

  const _SmallValue({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: PpText.caption()),
          Text(
            value,
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

class _StatBar extends StatelessWidget {
  final _StatBarData data;

  const _StatBar({required this.data});

  @override
  Widget build(BuildContext context) {
    final progress = data.max <= 0
        ? 0.0
        : (data.value / data.max).clamp(0.0, 1.0).toDouble();
    return PpSurface(
      color: PpColors.soft,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PpDot(color: data.color, size: 5),
              const SizedBox(width: 7),
              Expanded(child: Text(data.label, style: PpText.body(10.4))),
              Text(data.display, style: PpText.value(14)),
            ],
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: Colors.white,
              valueColor: AlwaysStoppedAnimation<Color>(data.color),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricValue {
  final String label;
  final String value;
  final String note;
  final Color color;

  const _MetricValue(this.label, this.value, this.note, this.color);
}

class _InfoValue {
  final String label;
  final String value;

  const _InfoValue(this.label, this.value);
}

class _StatBarData {
  final String label;
  final double value;
  final double max;
  final String display;
  final Color color;

  const _StatBarData(
    this.label,
    this.value,
    this.max,
    this.display,
    this.color,
  );
}

List<Map<String, dynamic>> _sortedMatches(List<Map<String, dynamic>> input) {
  final out = input.map((item) => Map<String, dynamic>.from(item)).toList();
  out.sort((a, b) {
    final ad = esportsMatchDate(a);
    final bd = esportsMatchDate(b);
    if (ad == null && bd == null) return 0;
    if (ad == null) return 1;
    if (bd == null) return -1;
    return bd.compareTo(ad);
  });
  return out;
}

String _joinNonEmpty(List<String> values) => values
    .map((value) => value.trim())
    .where((value) => value.isNotEmpty)
    .join(' · ');

String _signed(int value) => value > 0 ? '+$value' : '$value';

String _dateLabel(DateTime date) => DateFormat('dd.MM.yyyy').format(date);

Color _outcomeColor(EsportsMatchOutcome outcome) {
  switch (outcome) {
    case EsportsMatchOutcome.win:
      return PpColors.greenDark;
    case EsportsMatchOutcome.draw:
      return PpColors.amber;
    case EsportsMatchOutcome.loss:
      return PpColors.red;
    case EsportsMatchOutcome.unknown:
      return PpColors.muted2;
  }
}
