import 'package:flutter/material.dart';
import 'package:sportoteka/core/theme/app_typography.dart';
import 'package:sportoteka/presentation/esports_workspace/esports_cmr_ui.dart';

class EsportsAnalyticsPanel extends StatelessWidget {
  final List<Map<String, dynamic>> matches;
  final List<Map<String, dynamic>> athletes;
  final String selectedTeamName;

  const EsportsAnalyticsPanel({
    super.key,
    required this.matches,
    required this.athletes,
    required this.selectedTeamName,
  });

  @override
  Widget build(BuildContext context) {
    int wins = 0, draws = 0, losses = 0;
    double ratingSum = 0;
    int ratingCount = 0;
    for (final m in matches) {
      final result = esportsText(m['result']).toUpperCase();
      if (result == 'W' || result == 'WIN') wins++;
      if (result == 'D' || result == 'DRAW') draws++;
      if (result == 'L' || result == 'LOSS') losses++;
    }
    for (final a in athletes) {
      final r = esportsInt(a['rating']);
      if (r > 0) {
        ratingSum += r;
        ratingCount++;
      }
    }
    final completed = wins + draws + losses;
    final winRate = completed == 0 ? 0 : (wins / completed * 100).round();
    final avgRating = ratingCount == 0 ? 0 : (ratingSum / ratingCount).round();

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 108),
      children: [
        EsportsPanelHeader(
          title: 'Аналитика',
          subtitle: selectedTeamName.trim().isEmpty
              ? 'Игровые показатели без футбольных GPS-метрик'
              : '$selectedTeamName · игровая аналитика',
        ),
        const SizedBox(height: 14),
        LayoutBuilder(builder: (context, c) {
          final cards = [
            EsportsMetricCard(icon: Icons.percent_rounded, value: '$winRate%', label: 'Win Rate'),
            EsportsMetricCard(icon: Icons.trending_up_rounded, value: avgRating == 0 ? '—' : '$avgRating', label: 'Средний рейтинг'),
            EsportsMetricCard(icon: Icons.check_circle_outline_rounded, value: '$wins', label: 'Победы'),
            EsportsMetricCard(icon: Icons.stadium_outlined, value: '$completed', label: 'Завершено матчей'),
          ];
          if (c.maxWidth < 760) {
            return Wrap(spacing: 10, runSpacing: 10, children: cards.map((e) => SizedBox(width: (c.maxWidth - 10) / 2, child: e)).toList());
          }
          return Row(children: [for (var i = 0; i < cards.length; i++) ...[Expanded(child: cards[i]), if (i != cards.length - 1) const SizedBox(width: 10)]]);
        }),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: esportsCardDecoration(),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Показатели Esports', style: AppTypography.subsectionTitle(color: EsportsColors.text)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: const [
              _MetricChip('W / D / L'),
              _MetricChip('Голы / матч'),
              _MetricChip('xG'),
              _MetricChip('Владение'),
              _MetricChip('Удары'),
              _MetricChip('Точность передач'),
              _MetricChip('Формации'),
              _MetricChip('Серии'),
              _MetricChip('Рейтинг'),
            ]),
          ]),
        ),
      ],
    );
  }
}

class _MetricChip extends StatelessWidget {
  final String text;
  const _MetricChip(this.text);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(color: EsportsColors.soft, borderRadius: BorderRadius.circular(99)),
        child: Text(text, style: AppTypography.captionMedium(color: EsportsColors.text)),
      );
}
