import 'package:flutter/material.dart';
import 'package:sportoteka/core/theme/app_typography.dart';
import 'package:sportoteka/presentation/esports_workspace/esports_cmr_ui.dart';

class EsportsCalendarPanel extends StatelessWidget {
  final List<Map<String, dynamic>> matches;
  final List<Map<String, dynamic>> tournaments;
  final String selectedTeamName;

  const EsportsCalendarPanel({
    super.key,
    required this.matches,
    required this.tournaments,
    required this.selectedTeamName,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <Map<String, dynamic>>[
      ...matches.map((m) => <String, dynamic>{...m, '_kind': 'match'}),
      ...tournaments.map((t) => <String, dynamic>{...t, '_kind': 'tournament'}),
    ];
    rows.sort((a, b) => _date(a).compareTo(_date(b)));

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 108),
      children: [
        EsportsPanelHeader(
          title: 'Календарь',
          subtitle: selectedTeamName.trim().isEmpty
              ? 'Матчи, турниры и прямые эфиры'
              : '$selectedTeamName · матчи и турниры',
        ),
        const SizedBox(height: 14),
        if (rows.isEmpty)
          const EsportsEmptyState(
            icon: Icons.calendar_month_outlined,
            title: 'Календарь пока пуст',
            text: 'После создания матчей и турниров они автоматически появятся здесь.',
          )
        else
          Container(
            padding: const EdgeInsets.all(14),
            decoration: esportsCardDecoration(),
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  _row(rows[i]),
                  if (i != rows.length - 1)
                    const Divider(height: 18, color: EsportsColors.line),
                ],
              ],
            ),
          ),
      ],
    );
  }

  DateTime _date(Map<String, dynamic> row) {
    final raw = esportsText(row['start_at'] ?? row['date'] ?? row['start_date']);
    return DateTime.tryParse(raw.replaceAll(' ', 'T')) ?? DateTime(2100);
  }

  Widget _row(Map<String, dynamic> row) {
    final tournament = row['_kind'] == 'tournament';
    final title = tournament
        ? esportsText(row['name'] ?? row['title'])
        : esportsText(row['title']).isNotEmpty
            ? esportsText(row['title'])
            : [esportsText(row['team_name']), esportsText(row['opponent'])].where((e) => e.isNotEmpty).join(' — ');
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: tournament ? EsportsColors.orangeSoft : EsportsColors.greenSoft,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(
            tournament ? Icons.emoji_events_outlined : Icons.stadium_outlined,
            color: tournament ? EsportsColors.orange : EsportsColors.greenDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title.isEmpty ? (tournament ? 'Турнир' : 'Матч') : title, style: AppTypography.action(color: EsportsColors.text)),
            const SizedBox(height: 3),
            Text([
              esportsText(row['game_title'] ?? row['game']),
              esportsText(row['start_at'] ?? row['date'] ?? row['start_date']),
              esportsText(row['status']),
            ].where((e) => e.isNotEmpty).join(' · '), style: AppTypography.captionMedium(color: EsportsColors.muted)),
          ]),
        ),
      ],
    );
  }
}
