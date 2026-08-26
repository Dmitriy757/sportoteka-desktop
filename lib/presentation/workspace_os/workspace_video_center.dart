import 'package:flutter/material.dart';
import 'package:sportoteka/core/theme/app_typography.dart';
import 'package:sportoteka/presentation/team_matches_screen/team_match_detail_screen.dart';
import 'package:sportoteka/presentation/video_lessons/video_lessons_screen.dart';
import 'package:sportoteka/presentation/workspace_os/sportoteka_workspace_icons.dart';
import 'package:sportoteka/presentation/workspace_os/workspace_finder_models.dart';
import 'package:sportoteka/presentation/workspace_os/workspace_root_data_bridge.dart';

enum WorkspaceVideoCenterSection { matches, lessons }

class SportotekaWorkspaceVideoCenter extends StatefulWidget {
  const SportotekaWorkspaceVideoCenter({
    super.key,
    required this.clubId,
    required this.clubName,
    required this.teams,
    required this.players,
    required this.trainers,
    required this.currentUserId,
    this.selectedTeamId,
    this.selectedTeamName = '',
    this.initialSection = WorkspaceVideoCenterSection.matches,
  });

  final int clubId;
  final String clubName;
  final List<Map<String, dynamic>> teams;
  final List<Map<String, dynamic>> players;
  final List<Map<String, dynamic>> trainers;
  final int currentUserId;
  final int? selectedTeamId;
  final String selectedTeamName;
  final WorkspaceVideoCenterSection initialSection;

  @override
  State<SportotekaWorkspaceVideoCenter> createState() => _SportotekaWorkspaceVideoCenterState();
}

class _SportotekaWorkspaceVideoCenterState extends State<SportotekaWorkspaceVideoCenter> {
  static const _green = Color(0xFF0B8F55);
  static const _text = Color(0xFF101814);
  static const _muted = Color(0xFF758079);
  static const _line = Color(0xFFE7EAE7);
  static const _soft = Color(0xFFF7F8F7);

  final _search = TextEditingController();
  late WorkspaceVideoCenterSection _section;
  List<WorkspaceFinderNode> _matches = <WorkspaceFinderNode>[];
  WorkspaceFinderNode? _selectedMatch;
  bool _loading = true;
  String? _error;

  WorkspaceRootDataBridge get _bridge => WorkspaceRootDataBridge(
        clubId: widget.clubId,
        teams: widget.teams,
        players: widget.players,
        trainers: widget.trainers,
        selectedTeamId: widget.selectedTeamId,
        selectedTeamName: widget.selectedTeamName,
      );

  @override
  void initState() {
    super.initState();
    _section = widget.initialSection;
    _search.addListener(_changed);
    _loadMatches();
  }

  @override
  void dispose() {
    _search
      ..removeListener(_changed)
      ..dispose();
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _loadMatches() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final rows = await _bridge.loadFolder('matches');
      final matches = rows.where((node) => node.kind == WorkspaceFinderNodeKind.match).toList();
      if (!mounted) return;
      setState(() {
        _matches = matches;
        if (_selectedMatch == null || !matches.any((node) => node.id == _selectedMatch!.id)) {
          _selectedMatch = matches.isEmpty ? null : matches.first;
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Не удалось загрузить матчи: $e';
      });
    }
  }

  List<WorkspaceFinderNode> get _visibleMatches {
    final q = _search.text.trim().toLowerCase();
    if (q.isEmpty) return _matches;
    return _matches.where((node) {
      final row = node.payload ?? const <String, dynamic>{};
      final haystack = <String>[
        node.title,
        node.subtitle,
        '${row['team_name'] ?? ''}',
        '${row['opponent'] ?? row['opponent_name'] ?? ''}',
        '${row['competition_name'] ?? ''}',
        '${row['match_date'] ?? row['date'] ?? ''}',
      ].join(' ').toLowerCase();
      return haystack.contains(q);
    }).toList();
  }

  int _int(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final raw = row[key];
      if (raw is int && raw > 0) return raw;
      final parsed = int.tryParse('${raw ?? ''}');
      if (parsed != null && parsed > 0) return parsed;
    }
    return 0;
  }

  String _string(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = '${row[key] ?? ''}'.trim();
      if (value.isNotEmpty && value.toLowerCase() != 'null') return value;
    }
    return '';
  }

  String _matchMeta(WorkspaceFinderNode node) {
    final row = node.payload ?? const <String, dynamic>{};
    final values = <String>[
      _string(row, const <String>['match_date', 'info_date', 'date']),
      _string(row, const <String>['competition_name', 'event_type']),
      _string(row, const <String>['team_name']),
    ].where((value) => value.isNotEmpty).toList();
    return values.isEmpty ? node.subtitle : values.join(' · ');
  }

  Widget _sectionButton({
    required WorkspaceVideoCenterSection section,
    required SportotekaWorkspaceIconKind icon,
    required String title,
    required String subtitle,
  }) {
    final active = _section == section;
    return Material(
      color: active ? const Color(0xFFEAF5EF) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _section = section),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              SportotekaWorkspaceIcon(kind: icon, size: 22, color: active ? _green : _muted),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.menuTitle(color: active ? _text : _muted)),
                    const SizedBox(height: 2),
                    Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.caption(color: _muted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMatchList({required bool compact}) {
    final visible = _visibleMatches;
    return ColoredBox(
      color: Colors.white,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: SizedBox(
              height: 38,
              child: TextField(
                controller: _search,
                style: AppTypography.formText(color: _text),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Поиск матча…',
                  hintStyle: AppTypography.formHint(color: _muted),
                  prefixIcon: const Padding(
                    padding: EdgeInsets.all(10),
                    child: SportotekaWorkspaceIcon(kind: SportotekaWorkspaceIconKind.search, size: 17),
                  ),
                  filled: true,
                  fillColor: _soft,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 2, 10, 8),
            child: Row(
              children: [
                Text('${visible.length} матчей', style: AppTypography.caption(color: _muted)),
                const Spacer(),
                IconButton(
                  tooltip: 'Обновить',
                  onPressed: _loading ? null : _loadMatches,
                  icon: const SportotekaWorkspaceIcon(kind: SportotekaWorkspaceIconKind.refresh, size: 18),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _line),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : _error != null
                    ? Center(child: Padding(padding: const EdgeInsets.all(18), child: Text(_error!, textAlign: TextAlign.center, style: AppTypography.secondary(color: const Color(0xFFB42318)))))
                    : visible.isEmpty
                        ? Center(child: Text('Матчи не найдены', style: AppTypography.secondary(color: _muted)))
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(8, 6, 8, 14),
                            itemCount: visible.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 3),
                            itemBuilder: (_, index) {
                              final node = visible[index];
                              final active = node.id == _selectedMatch?.id;
                              return Material(
                                color: active ? const Color(0xFFEAF5EF) : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => setState(() => _selectedMatch = node),
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: compact ? 9 : 10),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 36,
                                          height: 36,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(color: active ? Colors.white : _soft, borderRadius: BorderRadius.circular(11)),
                                          child: SportotekaWorkspaceIcon(kind: SportotekaWorkspaceIconKind.video, size: 20, color: active ? _green : _muted),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(node.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.itemTitle(color: _text)),
                                              const SizedBox(height: 2),
                                              Text(_matchMeta(node), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.caption(color: _muted)),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 5),
                                        const SportotekaWorkspaceIcon(kind: SportotekaWorkspaceIconKind.chevronRight, size: 15, color: _muted),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedMatch() {
    final selected = _selectedMatch;
    if (selected == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SportotekaWorkspaceIcon(kind: SportotekaWorkspaceIconKind.video, size: 42, color: _muted),
            const SizedBox(height: 10),
            Text('Выберите матч слева', style: AppTypography.sectionTitle(color: _text)),
            const SizedBox(height: 4),
            Text('Справа откроются видео, загрузка, удаление и анализ.', style: AppTypography.secondary(color: _muted)),
          ],
        ),
      );
    }
    final row = Map<String, dynamic>.from(selected.payload ?? const <String, dynamic>{});
    final matchId = _int(row, const <String>['match_id', 'id', '_workspace_entity_id']);
    final teamId = _int(row, const <String>['team_id', 'teamId']);
    final teamName = _string(row, const <String>['team_name', 'teamName']);
    return Column(
      children: [
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: _line))),
          child: Row(
            children: [
              const SportotekaWorkspaceIcon(kind: SportotekaWorkspaceIconKind.video, size: 23, color: _green),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(selected.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.sectionTitle(color: _text)),
                    const SizedBox(height: 2),
                    Text(_matchMeta(selected), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.caption(color: _muted)),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: TeamMatchDetailScreen(
            key: ValueKey('workspace-video-match-$matchId-$teamId'),
            matchId: matchId,
            teamId: teamId,
            clubId: widget.clubId,
            teamName: teamName.isEmpty ? widget.selectedTeamName : teamName,
            clubName: widget.clubName,
            initialMatch: row,
            embedded: true,
            initialTabIndex: TeamMatchDetailScreen.videoTabIndex,
            videoOnly: true,
          ),
        ),
      ],
    );
  }

  Widget _buildMatchVideos({required bool compact}) {
    if (compact) {
      return Column(
        children: [
          SizedBox(height: 250, child: _buildMatchList(compact: true)),
          const Divider(height: 1, color: _line),
          Expanded(child: _buildSelectedMatch()),
        ],
      );
    }
    return Row(
      children: [
        SizedBox(width: 310, child: _buildMatchList(compact: false)),
        const VerticalDivider(width: 1, color: _line),
        Expanded(child: _buildSelectedMatch()),
      ],
    );
  }

  Widget _buildLessons() {
    final ownerUserId = widget.currentUserId > 0 ? widget.currentUserId : widget.clubId;
    return VideoLessonsScreen(
      ownerUserId: ownerUserId,
      ownerName: widget.clubName,
      isMyMode: true,
      embedded: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 860;
        return ColoredBox(
          color: Colors.white,
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.fromLTRB(compact ? 10 : 14, 10, compact ? 10 : 14, 10),
                decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: _line))),
                child: Row(
                  children: [
                    Expanded(
                      child: _sectionButton(
                        section: WorkspaceVideoCenterSection.matches,
                        icon: SportotekaWorkspaceIconKind.video,
                        title: 'Видео матчей',
                        subtitle: 'загрузка, удаление, просмотр и AI-анализ',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _sectionButton(
                        section: WorkspaceVideoCenterSection.lessons,
                        icon: SportotekaWorkspaceIconKind.documents,
                        title: 'Видеоуроки',
                        subtitle: 'методическая видеотека клуба',
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  child: KeyedSubtree(
                    key: ValueKey(_section.name),
                    child: _section == WorkspaceVideoCenterSection.matches
                        ? _buildMatchVideos(compact: compact)
                        : _buildLessons(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
