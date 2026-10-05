import 'package:flutter/material.dart';
import 'package:sportoteka/core/theme/app_typography.dart';
import 'package:sportoteka/presentation/esports_workspace/esports_cmr_ui.dart';

class EsportsOverviewPanel extends StatelessWidget {
  final String clubName;
  final List<Map<String, dynamic>> teams;
  final List<Map<String, dynamic>> athletes;
  final List<Map<String, dynamic>> matches;
  final List<Map<String, dynamic>> tournaments;
  final List<Map<String, dynamic>> streams;
  final VoidCallback onOpenTeams;
  final VoidCallback onOpenRoster;
  final VoidCallback onOpenMatches;
  final VoidCallback onOpenLive;

  const EsportsOverviewPanel({
    super.key,
    required this.clubName,
    required this.teams,
    required this.athletes,
    required this.matches,
    required this.tournaments,
    required this.streams,
    required this.onOpenTeams,
    required this.onOpenRoster,
    required this.onOpenMatches,
    required this.onOpenLive,
  });

  @override
  Widget build(BuildContext context) {
    final live = streams.where((s) {
      final status = esportsText(s['status']).toLowerCase();
      return status == 'live' || status == 'on_air';
    }).length;
    final upcoming = matches.where((m) {
      final status = esportsText(m['status']).toLowerCase();
      return status == 'scheduled' || status == 'upcoming' || status == 'planned';
    }).take(5).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 108),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EsportsPanelHeader(
            title: 'Sportoteka Esports',
            subtitle: clubName.trim().isEmpty
                ? 'Футбольное киберспортивное направление'
                : '$clubName · футбольное киберспортивное направление',
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, c) {
              final cards = <Widget>[
                EsportsMetricCard(
                  icon: Icons.groups_2_outlined,
                  value: '${teams.length}',
                  label: 'Команды',
                ),
                EsportsMetricCard(
                  icon: Icons.sports_esports_rounded,
                  value: '${athletes.length}',
                  label: 'Киберспортсмены',
                ),
                EsportsMetricCard(
                  icon: Icons.stadium_outlined,
                  value: '${matches.length}',
                  label: 'Матчи',
                ),
                EsportsMetricCard(
                  icon: Icons.sensors_rounded,
                  value: '$live',
                  label: 'Сейчас в эфире',
                ),
              ];
              if (c.maxWidth < 760) {
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: cards
                      .map((e) => SizedBox(width: (c.maxWidth - 10) / 2, child: e))
                      .toList(),
                );
              }
              return Row(
                children: [
                  for (var i = 0; i < cards.length; i++) ...[
                    Expanded(child: cards[i]),
                    if (i != cards.length - 1) const SizedBox(width: 10),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: esportsCardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Быстрые действия',
                  style: AppTypography.subsectionTitle(color: EsportsColors.text),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    EsportsActionButton(
                      icon: Icons.groups_2_outlined,
                      label: 'Команды',
                      onTap: onOpenTeams,
                    ),
                    EsportsActionButton(
                      icon: Icons.sports_esports_rounded,
                      label: 'Состав',
                      onTap: onOpenRoster,
                      primary: false,
                    ),
                    EsportsActionButton(
                      icon: Icons.stadium_outlined,
                      label: 'Матчи',
                      onTap: onOpenMatches,
                      primary: false,
                    ),
                    EsportsActionButton(
                      icon: Icons.sensors_rounded,
                      label: 'Live + AI',
                      onTap: onOpenLive,
                      primary: false,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: esportsCardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Ближайшие матчи',
                        style: AppTypography.subsectionTitle(color: EsportsColors.text),
                      ),
                    ),
                    Text(
                      '${tournaments.length} турниров',
                      style: AppTypography.captionMedium(color: EsportsColors.muted),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (upcoming.isEmpty)
                  Text(
                    'Запланированных матчей пока нет.',
                    style: AppTypography.captionMedium(color: EsportsColors.muted),
                  )
                else
                  for (var i = 0; i < upcoming.length; i++) ...[
                    _matchRow(upcoming[i]),
                    if (i != upcoming.length - 1)
                      const Divider(height: 18, color: EsportsColors.line),
                  ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: esportsCardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Направление',
                  style: AppTypography.subsectionTitle(color: EsportsColors.text),
                ),
                const SizedBox(height: 10),
                _discipline('EA Sports FC', '1×1 · 2×2 · Clubs · Ultimate Team'),
                const Divider(height: 16, color: EsportsColors.line),
                _discipline('eFootball', 'Матчи · рейтинги · турниры'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _matchRow(Map<String, dynamic> match) {
    final home = esportsText(match['home_name'] ?? match['team_name'] ?? match['team']);
    final away = esportsText(match['away_name'] ?? match['opponent']);
    final title = esportsText(match['title']).isNotEmpty
        ? esportsText(match['title'])
        : [home, away].where((e) => e.isNotEmpty).join(' — ');
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: EsportsColors.greenSoft,
            borderRadius: BorderRadius.circular(11),
          ),
          child: const Icon(Icons.stadium_outlined, size: 18, color: EsportsColors.greenDark),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.isEmpty ? 'Киберспортивный матч' : title,
                style: AppTypography.action(color: EsportsColors.text),
              ),
              const SizedBox(height: 2),
              Text(
                [
                  esportsText(match['game_title'] ?? match['game']),
                  esportsText(match['start_at'] ?? match['date']),
                ].where((e) => e.isNotEmpty).join(' · '),
                style: AppTypography.captionMedium(color: EsportsColors.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _discipline(String title, String subtitle) => Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: EsportsColors.green,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(child: Text(title, style: AppTypography.action(color: EsportsColors.text))),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              subtitle,
              textAlign: TextAlign.right,
              style: AppTypography.captionMedium(color: EsportsColors.muted),
            ),
          ),
        ],
      );
}
