import 'package:flutter/material.dart';
import 'package:sportoteka/core/theme/app_typography.dart';
import 'package:sportoteka/presentation/esports_workspace/esports_cmr_ui.dart';

class EsportsWorkspaceOsPanel extends StatefulWidget {
  final String clubName;
  final List<Map<String, dynamic>> teams;
  final List<Map<String, dynamic>> athletes;
  final List<Map<String, dynamic>> matches;
  final List<Map<String, dynamic>> recordings;
  final List<Map<String, dynamic>> reports;

  const EsportsWorkspaceOsPanel({
    super.key,
    required this.clubName,
    required this.teams,
    required this.athletes,
    required this.matches,
    required this.recordings,
    required this.reports,
  });

  @override
  State<EsportsWorkspaceOsPanel> createState() => _EsportsWorkspaceOsPanelState();
}

class _EsportsWorkspaceOsPanelState extends State<EsportsWorkspaceOsPanel> {
  String? _openedFolder;

  @override
  Widget build(BuildContext context) {
    final folders = <_FolderData>[
      _FolderData('teams', 'Команды', Icons.groups_2_outlined, widget.teams.length),
      _FolderData('athletes', 'Киберспортсмены', Icons.sports_esports_rounded, widget.athletes.length),
      _FolderData('matches', 'Матчи', Icons.stadium_outlined, widget.matches.length),
      _FolderData('video', 'Видео', Icons.video_library_outlined, widget.recordings.length),
      _FolderData('ai', 'ИИ-анализ', Icons.auto_awesome_rounded, widget.reports.length),
      const _FolderData('docs', 'Документы', Icons.description_outlined, 0),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 108),
      children: [
        EsportsPanelHeader(
          title: 'Sportoteka OS · Esports',
          subtitle: '${widget.clubName} · отдельное файловое пространство киберспорта',
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: esportsCardDecoration(),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              const Icon(Icons.folder_open_rounded, color: EsportsColors.greenDark),
              const SizedBox(width: 8),
              Expanded(child: Text(_openedFolder == null ? 'Киберспорт' : 'Киберспорт / ${folders.firstWhere((f) => f.id == _openedFolder).title}', style: AppTypography.action(color: EsportsColors.text))),
              if (_openedFolder != null) IconButton(onPressed: () => setState(() => _openedFolder = null), icon: const Icon(Icons.arrow_upward_rounded, size: 18)),
            ]),
            const Divider(height: 18, color: EsportsColors.line),
            if (_openedFolder == null)
              LayoutBuilder(builder: (context, c) {
                final columns = c.maxWidth < 520 ? 2 : c.maxWidth < 900 ? 3 : 5;
                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: columns,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.12,
                  children: folders.map((f) => _folderTile(f)).toList(),
                );
              })
            else
              _folderContent(_openedFolder!),
          ]),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(color: EsportsColors.soft, borderRadius: BorderRadius.circular(12)),
          child: Text(
            'После подключения серверного Workspace OS каждый матч автоматически создаёт папку: Видео → ключевые моменты → статистика → AI Match Report → документы.',
            style: AppTypography.custom(size: 11, weight: FontWeight.w400, color: EsportsColors.muted, height: 1.4),
          ),
        ),
      ],
    );
  }

  Widget _folderTile(_FolderData f) => InkWell(
        onTap: () => setState(() => _openedFolder = f.id),
        borderRadius: BorderRadius.circular(13),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: EsportsColors.soft, borderRadius: BorderRadius.circular(13), border: Border.all(color: EsportsColors.line)),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(f.icon, color: EsportsColors.greenDark, size: 27),
            const SizedBox(height: 9),
            Text(f.title, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTypography.action(color: EsportsColors.text)),
            const SizedBox(height: 3),
            Text('${f.count} объектов', style: AppTypography.captionMedium(color: EsportsColors.muted)),
          ]),
        ),
      );

  Widget _folderContent(String id) {
    final items = switch (id) {
      'teams' => widget.teams,
      'athletes' => widget.athletes,
      'matches' => widget.matches,
      'video' => widget.recordings,
      'ai' => widget.reports,
      _ => const <Map<String, dynamic>>[],
    };
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: Text('Папка пока пустая')),
      );
    }
    return Column(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          Row(children: [
            const Icon(Icons.insert_drive_file_outlined, size: 20, color: EsportsColors.muted),
            const SizedBox(width: 9),
            Expanded(child: Text(_itemTitle(items[i]), style: AppTypography.action(color: EsportsColors.text))),
            Text(_itemMeta(items[i]), style: AppTypography.captionMedium(color: EsportsColors.muted)),
          ]),
          if (i != items.length - 1) const Divider(height: 18, color: EsportsColors.line),
        ],
      ],
    );
  }

  String _itemTitle(Map<String, dynamic> m) {
    for (final key in const ['name', 'team_name', 'gamer_tag', 'title', 'match_title', 'opponent']) {
      final v = esportsText(m[key]);
      if (v.isNotEmpty) return v;
    }
    return 'Объект Sportoteka';
  }

  String _itemMeta(Map<String, dynamic> m) {
    return [
      esportsText(m['game_title'] ?? m['game']),
      esportsText(m['date'] ?? m['created_at'] ?? m['status']),
    ].where((e) => e.isNotEmpty).join(' · ');
  }
}

class _FolderData {
  final String id;
  final String title;
  final IconData icon;
  final int count;
  const _FolderData(this.id, this.title, this.icon, this.count);
}
