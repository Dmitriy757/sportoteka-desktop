import 'package:flutter/material.dart';
import 'package:sportoteka/core/theme/app_typography.dart';
import 'package:sportoteka/presentation/esports_workspace/esports_cmr_ui.dart';

class EsportsVideoPanel extends StatelessWidget {
  final List<Map<String, dynamic>> recordings;
  final List<Map<String, dynamic>> streams;
  final String selectedTeamName;
  final VoidCallback onOpenLive;

  const EsportsVideoPanel({
    super.key,
    required this.recordings,
    required this.streams,
    required this.selectedTeamName,
    required this.onOpenLive,
  });

  @override
  Widget build(BuildContext context) {
    final live = streams.where((s) {
      final status = esportsText(s['status']).toLowerCase();
      return status == 'live' || status == 'on_air';
    }).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 108),
      children: [
        EsportsPanelHeader(
          title: 'Видеоцентр Esports',
          subtitle: selectedTeamName.trim().isEmpty
              ? 'Прямые эфиры, VOD, клипы и AI-моменты'
              : '$selectedTeamName · эфиры и записи',
          trailing: EsportsActionButton(
            icon: Icons.sensors_rounded,
            label: 'Live',
            onTap: onOpenLive,
          ),
        ),
        const SizedBox(height: 14),
        if (live.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: esportsCardDecoration(),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Сейчас в эфире', style: AppTypography.subsectionTitle(color: EsportsColors.text)),
              const SizedBox(height: 10),
              for (final stream in live) _videoRow(stream, live: true),
            ]),
          ),
          const SizedBox(height: 14),
        ],
        if (recordings.isEmpty)
          const EsportsEmptyState(
            icon: Icons.video_library_outlined,
            title: 'Записей пока нет',
            text: 'После завершения прямого эфира VOD автоматически появится здесь вместе с AI-моментами и полным отчётом.',
          )
        else
          Container(
            padding: const EdgeInsets.all(14),
            decoration: esportsCardDecoration(),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Записи матчей', style: AppTypography.subsectionTitle(color: EsportsColors.text)),
              const SizedBox(height: 10),
              for (var i = 0; i < recordings.length; i++) ...[
                _videoRow(recordings[i], live: false),
                if (i != recordings.length - 1) const Divider(height: 18, color: EsportsColors.line),
              ],
            ]),
          ),
      ],
    );
  }

  Widget _videoRow(Map<String, dynamic> item, {required bool live}) {
    final title = esportsText(item['title'] ?? item['match_title']);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Container(
          width: 52,
          height: 42,
          decoration: BoxDecoration(color: live ? EsportsColors.redSoft : EsportsColors.soft, borderRadius: BorderRadius.circular(10)),
          child: Icon(live ? Icons.sensors_rounded : Icons.play_arrow_rounded, color: live ? EsportsColors.red : EsportsColors.greenDark),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title.isEmpty ? 'Запись киберспортивного матча' : title, style: AppTypography.action(color: EsportsColors.text)),
          const SizedBox(height: 3),
          Text([
            esportsText(item['game_title'] ?? item['game']),
            esportsText(item['created_at'] ?? item['started_at'] ?? item['date']),
            if (esportsBool(item['ai_ready'])) 'AI готов',
          ].where((e) => e.isNotEmpty).join(' · '), style: AppTypography.captionMedium(color: EsportsColors.muted)),
        ])),
        EsportsStatusPill(label: live ? 'LIVE' : 'VOD', active: !live, danger: live),
      ]),
    );
  }
}
