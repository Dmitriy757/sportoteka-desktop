import 'package:flutter/material.dart';
import 'package:sportoteka/core/theme/app_typography.dart';
import 'package:sportoteka/presentation/esports_workspace/esports_api_service.dart';
import 'package:sportoteka/presentation/esports_workspace/esports_cmr_ui.dart';

class EsportsAiPanel extends StatefulWidget {
  final int clubId;
  final List<Map<String, dynamic>> matches;
  final List<Map<String, dynamic>> reports;
  final String selectedTeamName;
  final Future<void> Function() onRefresh;

  const EsportsAiPanel({
    super.key,
    required this.clubId,
    required this.matches,
    required this.reports,
    required this.selectedTeamName,
    required this.onRefresh,
  });

  @override
  State<EsportsAiPanel> createState() => _EsportsAiPanelState();
}

class _EsportsAiPanelState extends State<EsportsAiPanel> {
  bool _working = false;
  String? _message;

  Future<void> _generate(Map<String, dynamic> match) async {
    final id = esportsInt(match['id'] ?? match['match_id']);
    if (id <= 0) return;
    setState(() {
      _working = true;
      _message = null;
    });
    final result = await EsportsApiService.generateAiReport(clubId: widget.clubId, matchId: id);
    if (!mounted) return;
    setState(() {
      _working = false;
      _message = result['success'] == true
          ? 'AI-анализ запущен.'
          : (esportsText(result['message']).isEmpty ? 'Не удалось запустить AI-анализ.' : esportsText(result['message']));
    });
    if (result['success'] == true) await widget.onRefresh();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 108),
      children: [
        EsportsPanelHeader(
          title: 'ИИ Esports',
          subtitle: 'Live AI во время эфира и полный AI Match Report после матча',
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: esportsCardDecoration(),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Два режима анализа', style: AppTypography.subsectionTitle(color: EsportsColors.text)),
            const SizedBox(height: 12),
            _feature(Icons.sensors_rounded, 'LIVE AI', 'События, игровые паттерны и подсказки прямо во время прямого эфира.'),
            const Divider(height: 20, color: EsportsColors.line),
            _feature(Icons.auto_awesome_rounded, 'AI Match Report', 'Таймлайн, ключевые эпизоды, статистика, ошибки, сильные стороны и рекомендации после эфира.'),
          ]),
        ),
        const SizedBox(height: 14),
        if (_message != null) ...[
          Container(padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: EsportsColors.soft, borderRadius: BorderRadius.circular(11)), child: Text(_message!, style: AppTypography.captionMedium(color: EsportsColors.muted))),
          const SizedBox(height: 10),
        ],
        if (widget.reports.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: esportsCardDecoration(),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Готовые отчёты', style: AppTypography.subsectionTitle(color: EsportsColors.text)),
              const SizedBox(height: 10),
              for (var i = 0; i < widget.reports.length; i++) ...[
                _reportRow(widget.reports[i]),
                if (i != widget.reports.length - 1) const Divider(height: 18, color: EsportsColors.line),
              ],
            ]),
          )
        else if (widget.matches.isEmpty)
          const EsportsEmptyState(icon: Icons.auto_awesome_rounded, title: 'Для ИИ нужен матч', text: 'После первого матча или эфира здесь появится полный AI Match Report.')
        else
          Container(
            padding: const EdgeInsets.all(14),
            decoration: esportsCardDecoration(),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Запустить анализ', style: AppTypography.subsectionTitle(color: EsportsColors.text)),
              const SizedBox(height: 10),
              for (final match in widget.matches.take(6)) _matchRow(match),
            ]),
          ),
      ],
    );
  }

  Widget _feature(IconData icon, String title, String text) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 38, height: 38, decoration: BoxDecoration(color: EsportsColors.greenSoft, borderRadius: BorderRadius.circular(11)), child: Icon(icon, color: EsportsColors.greenDark, size: 19)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: AppTypography.action(color: EsportsColors.text)), const SizedBox(height: 3), Text(text, style: AppTypography.custom(size: 11, weight: FontWeight.w400, color: EsportsColors.muted, height: 1.35))])),
      ]);

  Widget _reportRow(Map<String, dynamic> r) => Row(children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(color: EsportsColors.greenSoft, borderRadius: BorderRadius.circular(11)), child: const Icon(Icons.description_outlined, color: EsportsColors.greenDark)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(esportsText(r['title']).isEmpty ? 'AI Match Report' : esportsText(r['title']), style: AppTypography.action(color: EsportsColors.text)),
          const SizedBox(height: 3),
          Text([esportsText(r['match_title']), esportsText(r['created_at']), esportsText(r['status'])].where((e) => e.isNotEmpty).join(' · '), style: AppTypography.captionMedium(color: EsportsColors.muted)),
        ])),
        const EsportsStatusPill(label: 'AI', active: true),
      ]);

  Widget _matchRow(Map<String, dynamic> m) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Expanded(child: Text(esportsText(m['title'] ?? m['opponent']).isEmpty ? 'Матч' : esportsText(m['title'] ?? m['opponent']), style: AppTypography.action(color: EsportsColors.text))),
          EsportsActionButton(icon: Icons.auto_awesome_rounded, label: _working ? 'Анализ…' : 'Анализ', onTap: _working ? null : () => _generate(m), primary: false),
        ]),
      );
}
