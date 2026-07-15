
// lib/presentation/team_matches_screen/cmr_match_analytics_panel.dart
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/presentation/team_matches_screen/team_match_detail_screen.dart';

class CmrMatchAnalyticsPanel extends StatefulWidget {
  final int teamId;
  final String teamName;
  final int clubId;
  final String clubName;

  const CmrMatchAnalyticsPanel({
    super.key,
    required this.teamId,
    required this.teamName,
    required this.clubId,
    required this.clubName,
  });

  @override
  State<CmrMatchAnalyticsPanel> createState() => _CmrMatchAnalyticsPanelState();
}

class _CmrMatchAnalyticsPanelState extends State<CmrMatchAnalyticsPanel> {
  static const String _apiBase = 'https://sportotekaapp.ru/api';
  static const String _getMatchesUrl = '$_apiBase/get_team_matches.php';

  final TextEditingController _searchCtrl = TextEditingController();

  bool _loading = true;
  bool _refreshing = false;
  String? _error;
  int _selectedIndex = 0;
  String _filter = 'all';

  List<Map<String, dynamic>> _matches = [];

  @override
  void initState() {
    super.initState();
    _loadMatches();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMatches({bool refresh = false}) async {
    if (refresh) {
      setState(() => _refreshing = true);
    } else {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final userId = await PrefUtils.getUserId() ?? 0;
      final response = await http.post(
        Uri.parse(_getMatchesUrl),
        body: {
          'team_id': widget.teamId.toString(),
          'club_id': widget.clubId.toString(),
          'user_id': userId.toString(),
        },
      );

      final decoded = _decodeResponse(response.body);
      final raw = decoded['matches'] ?? decoded['data'] ?? decoded['items'] ?? [];
      final list = raw is List
          ? raw.map((e) => Map<String, dynamic>.from(e as Map)).toList()
          : <Map<String, dynamic>>[];

      list.sort((a, b) => _dateOf(b).compareTo(_dateOf(a)));

      if (!mounted) return;
      setState(() {
        _matches = list;
        _selectedIndex = list.isEmpty ? 0 : math.min(_selectedIndex, list.length - 1);
        _loading = false;
        _refreshing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось загрузить матчи: $e';
        _loading = false;
        _refreshing = false;
      });
    }
  }

  Map<String, dynamic> _decodeResponse(String body) {
    final trimmed = body.trim();
    final start = trimmed.indexOf('{');
    final end = trimmed.lastIndexOf('}');
    final jsonText = start >= 0 && end >= start ? trimmed.substring(start, end + 1) : trimmed;
    final decoded = jsonDecode(jsonText);
    if (decoded is Map<String, dynamic>) return decoded;
    return <String, dynamic>{'data': decoded};
  }

  List<Map<String, dynamic>> get _visibleMatches {
    final q = _searchCtrl.text.trim().toLowerCase();
    return _matches.where((m) {
      final opponent = _s(m, ['opponent', 'opponent_name', 'team2_name', 'away_team', 'rival']).toLowerCase();
      final title = _s(m, ['title', 'name']).toLowerCase();
      final status = _resultStatus(m);
      final byFilter = _filter == 'all' ||
          (_filter == 'win' && status == 'win') ||
          (_filter == 'draw' && status == 'draw') ||
          (_filter == 'loss' && status == 'loss');
      final bySearch = q.isEmpty || opponent.contains(q) || title.contains(q);
      return byFilter && bySearch;
    }).toList();
  }

  Map<String, dynamic>? get _selectedMatch {
    final list = _visibleMatches;
    if (list.isEmpty) return null;
    return list[math.min(_selectedIndex, list.length - 1)];
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: _A.green),
      );
    }

    if (_error != null) {
      return _ErrorState(message: _error!, onRetry: () => _loadMatches());
    }

    return Container(
      decoration: const BoxDecoration(color: _A.canvas),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final mobile = constraints.maxWidth < 640;
          final compact = constraints.maxWidth < 980;

          return Padding(
            padding: EdgeInsets.fromLTRB(
              mobile ? 2 : 10,
              mobile ? 8 : 10,
              mobile ? 2 : 10,
              mobile ? 0 : 12,
            ),
            child: mobile
                ? _buildMobile()
                : _buildWorkspace(compact: compact),
          );
        },
      ),
    );
  }

  Widget _buildWorkspace({required bool compact}) {
    final match = _selectedMatch;
    final listWidth = math.min(
      compact ? 430.0 : 480.0,
      MediaQuery.sizeOf(context).width * (compact ? .43 : .45),
    );

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: _A.workspaceDecoration,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: listWidth,
            child: _MatchesRail(
              teamName: widget.teamName,
              matches: _visibleMatches,
              selectedIndex: math.min(
                _selectedIndex,
                math.max(0, _visibleMatches.length - 1),
              ),
              searchCtrl: _searchCtrl,
              filter: _filter,
              refreshing: _refreshing,
              onFilter: (v) => setState(() {
                _filter = v;
                _selectedIndex = 0;
              }),
              onSearchChanged: (_) => setState(() => _selectedIndex = 0),
              onRefresh: () => _loadMatches(refresh: true),
              onSelect: (i) => setState(() => _selectedIndex = i),
              resultStatus: _resultStatus,
            ),
          ),
          const SizedBox(
            width: 1,
            child: ColoredBox(color: _A.border),
          ),
          Expanded(
            child: match == null
                ? const _EmptyAnalytics()
                : _AnalyticsWorkspace(
                    match: match,
                    teamName: widget.teamName,
                    clubName: widget.clubName,
                    teamId: widget.teamId,
                    clubId: widget.clubId,
                    compact: compact,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobile() {
    final match = _selectedMatch;

    return Column(
      children: [
        SizedBox(
          height: 238,
          child: _MatchesRail(
            horizontal: true,
            teamName: widget.teamName,
            matches: _visibleMatches,
            selectedIndex: math.min(
              _selectedIndex,
              math.max(0, _visibleMatches.length - 1),
            ),
            searchCtrl: _searchCtrl,
            filter: _filter,
            refreshing: _refreshing,
            onFilter: (v) => setState(() {
              _filter = v;
              _selectedIndex = 0;
            }),
            onSearchChanged: (_) => setState(() => _selectedIndex = 0),
            onRefresh: () => _loadMatches(refresh: true),
            onSelect: (i) => setState(() => _selectedIndex = i),
            resultStatus: _resultStatus,
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: _A.mobileWorkspaceDecoration,
            child: match == null
                ? const _EmptyAnalytics()
                : _AnalyticsWorkspace(
                    match: match,
                    teamName: widget.teamName,
                    clubName: widget.clubName,
                    teamId: widget.teamId,
                    clubId: widget.clubId,
                    compact: true,
                  ),
          ),
        ),
      ],
    );
  }

  String _resultStatus(Map<String, dynamic> m) {
    final scored = _toInt(_value(m, ['goals_for', 'score_for', 'home_score', 'team_score', 'goals']));
    final conceded = _toInt(_value(m, ['goals_against', 'score_against', 'away_score', 'opponent_score', 'missed']));
    if (scored > conceded) return 'win';
    if (scored < conceded) return 'loss';
    return 'draw';
  }
}

class _AnalyticsWorkspace extends StatefulWidget {
  final Map<String, dynamic> match;
  final String teamName;
  final String clubName;
  final int teamId;
  final int clubId;
  final bool compact;

  const _AnalyticsWorkspace({
    required this.match,
    required this.teamName,
    required this.clubName,
    required this.teamId,
    required this.clubId,
    this.compact = false,
  });

  @override
  State<_AnalyticsWorkspace> createState() => _AnalyticsWorkspaceState();
}

class _AnalyticsWorkspaceState extends State<_AnalyticsWorkspace> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final match = widget.match;
    final opponent = _opponent(match);
    final scoreFor = _toInt(_value(match, ['goals_for', 'score_for', 'home_score', 'team_score', 'goals']));
    final scoreAgainst = _toInt(_value(match, ['goals_against', 'score_against', 'away_score', 'opponent_score', 'missed']));
    final date = _formatDate(_dateOf(match));
    final result = scoreFor > scoreAgainst ? 'Победа' : scoreFor < scoreAgainst ? 'Поражение' : 'Ничья';
    final resultColor = scoreFor > scoreAgainst
        ? _A.green
        : scoreFor < scoreAgainst
            ? _A.red
            : _A.gray;

    return Column(
      children: [
        _TopMatchHeader(
          teamName: widget.teamName,
          opponent: opponent,
          score: '$scoreFor:$scoreAgainst',
          result: result,
          resultColor: resultColor,
          date: date,
          matchType: _s(match, ['match_type', 'type', 'kind'], fallback: 'Матч'),
          onOpenDetail: () => Get.to(() => TeamMatchDetailScreen(
                matchId: _toInt(_value(match, ['id', 'match_id'])),
                teamId: widget.teamId,
                teamName: widget.teamName,
                clubId: widget.clubId,
                clubName: widget.clubName,
                initialMatch: Map<String, dynamic>.from(match),
              )),
        ),
        _AnalyticsTabs(
          selected: _tab,
          onChanged: (i) => setState(() => _tab = i),
        ),
        Expanded(
          child: IndexedStack(
            index: _tab,
            children: [
              _OverviewTab(match: match, compact: widget.compact),
              _AnalyticsTab(match: match),
              _PlayersTab(match: match),
              _EventsTab(match: match),
              _VideoTab(match: match),
            ],
          ),
        ),
      ],
    );
  }
}

class _OverviewTab extends StatelessWidget {
  final Map<String, dynamic> match;
  final bool compact;

  const _OverviewTab({required this.match, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final grid = [
      _StatPair('Владение мячом', '${_num(match, ['possession', 'ball_possession'], 62).round()}%', '${100 - _num(match, ['possession', 'ball_possession'], 62).round()}%', _A.green),
      _StatPair('Удары', '${_num(match, ['shots', 'total_shots'], 18).round()}', '${_num(match, ['opponent_shots'], 6).round()}', _A.green),
      _StatPair('Удары в створ', '${_num(match, ['shots_on_target'], 9).round()}', '${_num(match, ['opponent_shots_on_target'], 2).round()}', _A.green),
      _StatPair('xG', _num(match, ['xg', 'expected_goals'], 2.45).toStringAsFixed(2), _num(match, ['opponent_xg'], .46).toStringAsFixed(2), _A.green),
      _StatPair('Передачи', '${_num(match, ['passes'], 482).round()}', '${_num(match, ['opponent_passes'], 281).round()}', _A.green),
      _StatPair('Точность передач', '${_num(match, ['pass_accuracy'], 87).round()}%', '${_num(match, ['opponent_pass_accuracy'], 76).round()}%', _A.green),
      _StatPair('Единоборства', '${_num(match, ['duels_won'], 56).round()}%', '${_num(match, ['opponent_duels_won'], 44).round()}%', _A.green),
      _StatPair('Угловые', '${_num(match, ['corners'], 7).round()}', '${_num(match, ['opponent_corners'], 2).round()}', _A.green),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
      child: LayoutBuilder(
        builder: (_, c) {
          final rightPanel = c.maxWidth >= 980;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: rightPanel ? 7 : 1,
                child: Column(
                  children: [
                    _Panel(
                      title: 'Ключевая статистика',
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: grid.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: c.maxWidth < 680 ? 2 : 4,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: c.maxWidth < 680 ? 2.45 : 2.75,
                        ),
                        itemBuilder: (_, i) => _StatPairCard(data: grid[i]),
                      ),
                    ),
                    const SizedBox(height: 8),
                    LayoutBuilder(
                      builder: (_, cc) {
                        final two = cc.maxWidth > 760;
                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            SizedBox(width: two ? (cc.maxWidth - 8) / 2 : cc.maxWidth, child: const _XgChart()),
                            SizedBox(width: two ? (cc.maxWidth - 8) / 2 : cc.maxWidth, child: const _PitchZones()),
                            SizedBox(width: two ? (cc.maxWidth - 8) / 2 : cc.maxWidth, child: const _EventsMini()),
                            SizedBox(width: two ? (cc.maxWidth - 8) / 2 : cc.maxWidth, child: const _BestPlayers()),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              if (rightPanel) ...[
                const SizedBox(width: 8),
                SizedBox(
                  width: 360,
                  child: Column(
                    children: [
                      _Panel(
                        title: 'Основные показатели',
                        child: Column(
                          children: [
                            _MetricLine('Удары', 18, 6),
                            _MetricLine('Удары в створ', 9, 2),
                            _MetricLine('Удары мимо', 5, 3),
                            _MetricLine('Заблокированные удары', 4, 1),
                            _MetricLine('Штрафные удары', 12, 11),
                            _MetricLine('Офсайды', 2, 1),
                            _MetricLine('Нарушения', 11, 14),
                            _MetricLine('Жёлтые карточки', 1, 2),
                            _MetricLine('Красные карточки', 0, 0),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      const _PositionAttacks(),
                      const SizedBox(height: 8),
                      const _HeatMap(),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _AnalyticsTab extends StatelessWidget {
  final Map<String, dynamic> match;
  const _AnalyticsTab({required this.match});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: const [
          SizedBox(width: 520, child: _XgChart()),
          SizedBox(width: 520, child: _PitchZones()),
          SizedBox(width: 520, child: _PositionAttacks()),
          SizedBox(width: 520, child: _HeatMap()),
        ],
      ),
    );
  }
}

class _PlayersTab extends StatelessWidget {
  final Map<String, dynamic> match;
  const _PlayersTab({required this.match});

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: _BestPlayers(full: true),
    );
  }
}

class _EventsTab extends StatelessWidget {
  final Map<String, dynamic> match;
  const _EventsTab({required this.match});

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: _EventsMini(full: true),
    );
  }
}

class _VideoTab extends StatelessWidget {
  final Map<String, dynamic> match;
  const _VideoTab({required this.match});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
      child: _Panel(
        title: 'Видео матча',
        child: Container(
          height: 236,
          decoration: BoxDecoration(
            color: _A.cardSoft,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _A.border),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _s(match, ['video_url', 'video', 'match_video']).isEmpty
                      ? Icons.videocam_off_outlined
                      : Icons.play_circle_outline_rounded,
                  color: _A.mutedColor,
                  size: 34,
                ),
                const SizedBox(height: 8),
                Text(
                  _s(match, ['video_url', 'video', 'match_video']).isEmpty
                      ? 'Видео ещё не прикреплено'
                      : 'Открыть видео и разбор эпизодов',
                  style: _A.title(15).copyWith(color: _A.mutedColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MatchesRail extends StatelessWidget {
  final String teamName;
  final List<Map<String, dynamic>> matches;
  final int selectedIndex;
  final TextEditingController searchCtrl;
  final String filter;
  final bool refreshing;
  final bool horizontal;
  final ValueChanged<String> onFilter;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onRefresh;
  final ValueChanged<int> onSelect;
  final String Function(Map<String, dynamic>) resultStatus;

  const _MatchesRail({
    required this.teamName,
    required this.matches,
    required this.selectedIndex,
    required this.searchCtrl,
    required this.filter,
    required this.refreshing,
    required this.onFilter,
    required this.onSearchChanged,
    required this.onRefresh,
    required this.onSelect,
    required this.resultStatus,
    this.horizontal = false,
  });

  @override
  Widget build(BuildContext context) {
    final list = ListView.separated(
      scrollDirection: horizontal ? Axis.horizontal : Axis.vertical,
      padding: EdgeInsets.fromLTRB(horizontal ? 10 : 12, 8, horizontal ? 10 : 12, horizontal ? 16 : 12),
      itemCount: matches.length,
      separatorBuilder: (_, __) => SizedBox(width: horizontal ? 10 : 0, height: horizontal ? 0 : 2),
      itemBuilder: (_, i) => SizedBox(
        width: horizontal ? 248 : null,
        child: _MatchTile(
          match: matches[i],
          selected: i == selectedIndex,
          status: resultStatus(matches[i]),
          onTap: () => onSelect(i),
        ),
      ),
    );

    return DecoratedBox(
      decoration: const BoxDecoration(color: _A.panel),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 58,
            padding: EdgeInsets.fromLTRB(horizontal ? 10 : 12, 9, 10, 9),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _A.border)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _A.accentSoft,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _A.accentBorder),
                  ),
                  child: const Icon(Icons.analytics_outlined, color: _A.green, size: 19),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Аналитика матчей', style: _A.title(16.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(teamName, style: _A.muted(11.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                _CircleIconButton(
                  icon: refreshing ? Icons.sync_rounded : Icons.refresh_rounded,
                  onTap: refreshing ? null : onRefresh,
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(horizontal ? 10 : 12, 8, horizontal ? 10 : 12, 0),
            child: SizedBox(
              height: 46,
              child: TextField(
                controller: searchCtrl,
                onChanged: onSearchChanged,
                style: _A.body(12),
                decoration: InputDecoration(
                  hintText: 'Поиск матча',
                  hintStyle: _A.muted(12),
                  prefixIcon: const Icon(Icons.search_rounded, size: 18),
                  prefixIconConstraints: const BoxConstraints(minWidth: 34),
                  isDense: true,
                  filled: true,
                  fillColor: _A.soft,
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _A.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _A.greenBorder)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 30,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: horizontal ? 10 : 12),
              children: [
                _FilterChip(text: 'Все', selected: filter == 'all', onTap: () => onFilter('all')),
                _FilterChip(text: 'Победы', selected: filter == 'win', onTap: () => onFilter('win')),
                _FilterChip(text: 'Ничьи', selected: filter == 'draw', onTap: () => onFilter('draw')),
                _FilterChip(text: 'Поражения', selected: filter == 'loss', onTap: () => onFilter('loss')),
              ],
            ),
          ),
          Expanded(child: matches.isEmpty ? const _EmptyList() : list),
        ],
      ),
    );
  }
}

class _TopMatchHeader extends StatelessWidget {
  final String teamName;
  final String opponent;
  final String score;
  final String result;
  final Color resultColor;
  final String date;
  final String matchType;
  final VoidCallback onOpenDetail;

  const _TopMatchHeader({
    required this.teamName,
    required this.opponent,
    required this.score,
    required this.result,
    required this.resultColor,
    required this.date,
    required this.matchType,
    required this.onOpenDetail,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _A.border)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
      child: LayoutBuilder(
        builder: (context, c) {
          final narrow = c.maxWidth < 640;
          final tiny = c.maxWidth < 560;
          return Row(
            children: [
              _CircleIconButton(icon: Icons.arrow_back_rounded, onTap: () => Navigator.maybePop(context)),
              const SizedBox(width: 8),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _A.accentSoft,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _A.accentBorder),
                ),
                child: const Icon(Icons.sports_soccer_rounded, color: _A.green, size: 19),
              ),
              const SizedBox(width: 9),
              Expanded(
                flex: 34,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$teamName — $opponent', maxLines: 1, overflow: TextOverflow.ellipsis, style: _A.title(16.0)),
                    const SizedBox(height: 4),
                    Text('$matchType · $date', maxLines: 1, overflow: TextOverflow.ellipsis, style: _A.muted(10.5)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _HeaderInfoCell(label: 'Счёт', value: score, icon: Icons.scoreboard_rounded, color: resultColor),
              if (!tiny) ...[
                const SizedBox(width: 6),
                _HeaderInfoCell(label: 'Итог', value: result, icon: Icons.flag_rounded, color: resultColor),
              ],
              if (!narrow) ...[
                const SizedBox(width: 6),
                _HeaderInfoCell(label: 'Дата', value: date, icon: Icons.event_rounded, color: const Color(0xFF147AD6)),
                const SizedBox(width: 8),
                _HeaderButton(icon: Icons.article_outlined, text: 'Отчёт', onTap: onOpenDetail),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _AnalyticsTabs extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;

  const _AnalyticsTabs({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final tabs = ['Обзор', 'Аналитика', 'Игроки', 'События', 'Видео'];
    return Container(
      height: 42,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _A.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      child: Row(
        children: List.generate(tabs.length, (i) {
          final active = i == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: InkWell(
              onTap: () => onChanged(i),
              borderRadius: BorderRadius.circular(9),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active ? _A.accentSoft : Colors.white,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: active ? _A.accentBorder : _A.border),
                ),
                child: Text(
                  tabs[i],
                  style: TextStyle(
                    color: active ? _A.green : _A.mutedColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 11.5,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final Widget child;

  const _Panel({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _A.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _A.border, width: .7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.centerLeft,
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: _A.border, width: .7)),
            ),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 18,
                  decoration: BoxDecoration(
                    color: _A.green,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    title,
                    style: _A.section(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _StatPair {
  final String title;
  final String left;
  final String right;
  final Color color;
  const _StatPair(this.title, this.left, this.right, this.color);
}

class _StatPairCard extends StatelessWidget {
  final _StatPair data;
  const _StatPairCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final left = double.tryParse(data.left.replaceAll('%', '')) ?? 60;
    final right = double.tryParse(data.right.replaceAll('%', '')) ?? 40;
    final total = math.max(1, left + right);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _A.soft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _A.border, width: .7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(data.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _A.muted(11)),
          const Spacer(),
          Row(
            children: [
              Text(data.left, style: _A.title(19)),
              const Spacer(),
              Text(data.right, style: _A.title(17).copyWith(color: _A.mutedColor)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 7,
              value: left / total,
              backgroundColor: const Color(0xFFE9EEF4),
              valueColor: AlwaysStoppedAnimation<Color>(data.color),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricLine extends StatelessWidget {
  final String title;
  final int left;
  final int right;

  const _MetricLine(this.title, this.left, this.right);

  @override
  Widget build(BuildContext context) {
    final total = math.max(1, left + right);
    return Padding(
      padding: const EdgeInsets.only(bottom: 17),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(title, style: _A.body(12))),
          SizedBox(width: 28, child: Text('$left', textAlign: TextAlign.right, style: _A.body(12))),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                minHeight: 7,
                value: left / total,
                backgroundColor: const Color(0xFFE9EEF4),
                valueColor: const AlwaysStoppedAnimation<Color>(_A.green),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(width: 24, child: Text('$right', style: _A.muted(12))),
        ],
      ),
    );
  }
}

class _XgChart extends StatelessWidget {
  const _XgChart();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Динамика матча (xG)',
      child: SizedBox(height: 190, child: CustomPaint(painter: _LineChartPainter(), child: const SizedBox.expand())),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = const Color(0xFFE6EAF0)
      ..strokeWidth = 1;
    final green = Paint()
      ..color = _A.green
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final blue = Paint()
      ..color = const Color(0xFF4E79FF)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 5; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    Path path1 = Path();
    Path path2 = Path();
    final a = [0, .15, .31, .46, .52, .52, .62, .68, .74, .75, .79, .86, .93, 1.0];
    final b = [0, .02, .03, .12, .12, .12, .12, .12, .17, .21, .21, .21, .21, .22];
    for (int i = 0; i < a.length; i++) {
      final x = size.width * i / (a.length - 1);
      final y1 = size.height - (size.height * a[i] * .86) - 8;
      final y2 = size.height - (size.height * b[i] * .86) - 8;
      if (i == 0) {
        path1.moveTo(x, y1);
        path2.moveTo(x, y2);
      } else {
        path1.lineTo(x, y1);
        path2.lineTo(x, y2);
      }
      canvas.drawCircle(Offset(x, y1), 3.5, Paint()..color = _A.green);
      canvas.drawCircle(Offset(x, y2), 3.5, Paint()..color = const Color(0xFF4E79FF));
    }
    canvas.drawPath(path1, green);
    canvas.drawPath(path2, blue);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PitchZones extends StatelessWidget {
  const _PitchZones();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Опасные зоны атак',
      child: SizedBox(height: 190, child: CustomPaint(painter: _PitchPainter(zones: true), child: const SizedBox.expand())),
    );
  }
}

class _PositionAttacks extends StatelessWidget {
  const _PositionAttacks();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Позиционные атаки',
      child: SizedBox(height: 190, child: CustomPaint(painter: _PitchPainter(labels: true), child: const SizedBox.expand())),
    );
  }
}

class _HeatMap extends StatelessWidget {
  const _HeatMap();

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Тепловая карта действий',
      child: SizedBox(height: 190, child: CustomPaint(painter: _HeatPainter(), child: const SizedBox.expand())),
    );
  }
}

class _PitchPainter extends CustomPainter {
  final bool labels;
  final bool zones;
  const _PitchPainter({this.labels = false, this.zones = false});

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..shader = const LinearGradient(colors: [Color(0xFFDDF7E8), Color(0xFF9BE1B8)]).createShader(Offset.zero & size);
    final line = Paint()
      ..color = Colors.white.withOpacity(.65)
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke;
    final rect = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(14));
    canvas.drawRRect(rect, bg);
    canvas.drawRRect(rect, line);
    canvas.drawLine(Offset(size.width / 2, 0), Offset(size.width / 2, size.height), line);
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 26, line);
    canvas.drawRect(Rect.fromLTWH(0, size.height * .25, size.width * .18, size.height * .5), line);
    canvas.drawRect(Rect.fromLTWH(size.width * .82, size.height * .25, size.width * .18, size.height * .5), line);

    if (zones) {
      _drawText(canvas, '36%', Offset(size.width * .20, size.height * .48), 20, _A.green);
      _drawText(canvas, '44%', Offset(size.width * .49, size.height * .48), 20, _A.green);
      _drawText(canvas, '20%', Offset(size.width * .81, size.height * .48), 20, const Color(0xFF0F172A));
    }
    if (labels) {
      _drawText(canvas, 'Левый фланг\n38%', Offset(size.width * .20, size.height * .42), 14, _A.green);
      _drawText(canvas, 'Центр\n24%', Offset(size.width * .50, size.height * .42), 14, _A.green);
      _drawText(canvas, 'Правый фланг\n38%', Offset(size.width * .80, size.height * .42), 14, _A.green);
    }
  }

  void _drawText(Canvas canvas, String text, Offset center, double size, Color color) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: size, fontWeight: FontWeight.w700, height: 1.25)),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: 110);
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HeatPainter extends CustomPainter {
  const _HeatPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const base = _PitchPainter();
    base.paint(canvas, size);
    final spots = [
      (Offset(size.width * .50, size.height * .46), 52.0, const Color(0xFFFF5C00)),
      (Offset(size.width * .38, size.height * .72), 36.0, const Color(0xFFFF7A00)),
      (Offset(size.width * .60, size.height * .48), 34.0, const Color(0xFFFFC400)),
      (Offset(size.width * .32, size.height * .20), 30.0, const Color(0xFFFFD600)),
      (Offset(size.width * .66, size.height * .20), 28.0, const Color(0xFFFFE45C)),
    ];

    for (final s in spots) {
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [s.$3.withOpacity(.75), s.$3.withOpacity(0)],
        ).createShader(Rect.fromCircle(center: s.$1, radius: s.$2));
      canvas.drawCircle(s.$1, s.$2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _EventsMini extends StatelessWidget {
  final bool full;
  const _EventsMini({this.full = false});

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('12’', '1:0', 'Иванов М. (7)'),
      ('28’', '2:0', 'Петров Д. (10)'),
      ('41’', '3:0', 'Сидоров А. (9)'),
      ('63’', '4:0', 'Иванов М. (7)'),
      ('78’', '5:0', 'Петров Д. (10)'),
    ];
    return _Panel(
      title: 'События матча',
      child: Column(
        children: rows.map((r) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            children: [
              SizedBox(width: 38, child: Text(r.$1, style: _A.muted(12))),
              const Icon(Icons.sports_soccer_rounded, size: 15, color: _A.text),
              const SizedBox(width: 16),
              Text(r.$2, style: _A.title(14)),
              const SizedBox(width: 18),
              Expanded(child: Text(r.$3, style: _A.body(13))),
            ],
          ),
        )).toList(),
      ),
    );
  }
}

class _BestPlayers extends StatelessWidget {
  final bool full;
  const _BestPlayers({this.full = false});

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('1', 'Иванов Михаил (7)', '2 гола, 1 передача', '9.2'),
      ('2', 'Петров Дмитрий (10)', '2 гола, 1 передача', '8.7'),
      ('3', 'Сидоров Алексей (9)', '1 гол, 1 передача', '8.3'),
    ];
    return _Panel(
      title: 'Лучшие игроки',
      child: Column(
        children: rows.map((r) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            children: [
              CircleAvatar(radius: 16, backgroundColor: _A.accentSoft, child: Text(r.$1, style: const TextStyle(color: _A.green, fontWeight: FontWeight.w700))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.$2, style: _A.title(14), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(r.$3, style: _A.muted(12)),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFFEAF7EF), borderRadius: BorderRadius.circular(10), border: Border.all(color: _A.green.withOpacity(.25))),
                child: Text('${r.$4} ★', style: const TextStyle(color: _A.green, fontWeight: FontWeight.w700, fontSize: 12)),
              ),
            ],
          ),
        )).toList(),
      ),
    );
  }
}

class _MatchTile extends StatelessWidget {
  final Map<String, dynamic> match;
  final bool selected;
  final String status;
  final VoidCallback onTap;

  const _MatchTile({
    required this.match,
    required this.selected,
    required this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final opponent = _opponent(match);
    final date = _dateOf(match);
    final scoreFor = _toInt(
      _value(match, ['goals_for', 'score_for', 'home_score', 'team_score', 'goals']),
    );
    final scoreAgainst = _toInt(
      _value(match, ['goals_against', 'score_against', 'away_score', 'opponent_score', 'missed']),
    );
    final resultColor = status == 'win'
        ? _A.green
        : status == 'loss'
            ? _A.red
            : _A.gray;
    final resultText = status == 'win'
        ? 'Победа'
        : status == 'loss'
            ? 'Поражение'
            : 'Ничья';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? _A.greenSoft : _A.panel,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? _A.greenBorder : _A.border,
                width: .8,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: _A.green.withOpacity(.07),
                        blurRadius: 18,
                        spreadRadius: -10,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 3,
                  height: 40,
                  decoration: BoxDecoration(
                    color: selected ? _A.green : Colors.transparent,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(width: 9),
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _A.soft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('${date.day}'.padLeft(2, '0'), style: _A.title(13.5)),
                      const SizedBox(height: 1),
                      Text(_monthShort(date), style: _A.caption()),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        opponent,
                        style: _A.title(13.4),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_s(match, ['match_type', 'type', 'kind'], fallback: 'Матч')}  •  $resultText',
                        style: _A.muted(10.6).copyWith(color: resultColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$scoreFor:$scoreAgainst',
                      style: _A.title(15.5).copyWith(color: resultColor),
                    ),
                    const SizedBox(height: 3),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: selected ? _A.green : _A.mutedColor,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.text, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        selected: selected,
        label: Text(text),
        onSelected: (_) => onTap(),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        selectedColor: _A.accentSoft,
        labelStyle: TextStyle(color: selected ? _A.green : _A.mutedColor, fontWeight: FontWeight.w700, fontSize: 11),
        side: BorderSide(color: selected ? _A.accentBorder : _A.border),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
    );
  }
}


class _HeaderInfoCell extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _HeaderInfoCell({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 112, maxWidth: 150),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          color: _A.cardSoft,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: _A.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: _A.muted(9.5)),
                  const SizedBox(height: 2),
                  Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: _A.title(12.5).copyWith(color: color)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: _A.cardSoft,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: _A.border),
        ),
        child: Icon(icon, size: 18, color: onTap == null ? _A.mutedColor.withOpacity(.45) : _A.text),
      ),
    );
  }
}

class _TeamBadge extends StatelessWidget {
  final String title;
  final bool away;
  const _TeamBadge({required this.title, this.away = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Column(
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: away ? const Color(0xFFEFF4FF) : const Color(0xFFEAF7EF),
            child: Icon(away ? Icons.shield_rounded : Icons.sports_soccer_rounded, color: away ? const Color(0xFF2459B8) : _A.green, size: 32),
          ),
          const SizedBox(height: 10),
          Text(title, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: _A.title(13)),
        ],
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  const _HeaderButton({required this.icon, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(text),
      style: OutlinedButton.styleFrom(
        foregroundColor: _A.text,
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        side: const BorderSide(color: _A.border),
        minimumSize: const Size(0, 34),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
    );
  }
}

class _EmptyAnalytics extends StatelessWidget {
  const _EmptyAnalytics();

  @override
  Widget build(BuildContext context) {
    return Center(child: Text('Выберите матч для аналитики', style: _A.muted(13)));
  }
}

class _EmptyList extends StatelessWidget {
  const _EmptyList();

  @override
  Widget build(BuildContext context) {
    return Center(child: Text('Матчи не найдены', style: _A.muted(12)));
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: onRetry, child: const Text('Повторить')),
      ]),
    );
  }
}

class _A {
  static const String family = 'Segoe UI';
  static const List<String> fallback = <String>[
    'SF Pro Display',
    'SF Pro Text',
    'Inter',
    'Roboto',
    'Arial',
  ];

  static const Color green = Color(0xFF00A750);
  static const Color greenDark = Color(0xFF067A46);
  static const Color greenSoft = Color(0xFFF3FAF6);
  static const Color greenBorder = Color(0xFFD7F0E2);

  static const Color red = Color(0xFFD92D20);
  static const Color gray = Color(0xFF6B7280);
  static const Color text = Color(0xFF0B0F14);
  static const Color mutedColor = Color(0xFF6B7280);

  static const Color canvas = Color(0xFFF6F7F6);
  static const Color panel = Colors.white;
  static const Color soft = Color(0xFFFAFBFA);
  static const Color cardSoft = Color(0xFFFAFBFA);
  static const Color border = Color(0xFFE9ECEA);
  static const Color accentSoft = greenSoft;
  static const Color accentBorder = greenBorder;

  static BoxDecoration get workspaceDecoration => BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.transparent, width: 0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.035),
            blurRadius: 28,
            spreadRadius: -18,
            offset: const Offset(0, 16),
          ),
        ],
      );

  static BoxDecoration get mobileWorkspaceDecoration => BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border, width: .7),
      );

  static TextStyle title(double size) => TextStyle(
        fontFamily: family,
        fontFamilyFallback: fallback,
        fontSize: size,
        fontWeight: FontWeight.w600,
        color: text,
        height: 1.08,
        letterSpacing: -.16,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle body(double size) => TextStyle(
        fontFamily: family,
        fontFamilyFallback: fallback,
        fontSize: size,
        fontWeight: FontWeight.w500,
        color: text,
        height: 1.24,
      );

  static TextStyle muted(double size) => TextStyle(
        fontFamily: family,
        fontFamilyFallback: fallback,
        fontSize: size,
        fontWeight: FontWeight.w500,
        color: mutedColor,
        height: 1.26,
      );

  static TextStyle caption() => const TextStyle(
        fontFamily: family,
        fontFamilyFallback: fallback,
        fontSize: 9.2,
        fontWeight: FontWeight.w500,
        color: mutedColor,
        height: 1.08,
      );

  static TextStyle section() => const TextStyle(
        fontFamily: family,
        fontFamilyFallback: fallback,
        fontSize: 11.2,
        fontWeight: FontWeight.w600,
        color: text,
        height: 1.12,
        letterSpacing: -.08,
      );
}

dynamic _value(Map<String, dynamic> m, List<String> keys) {
  for (final k in keys) {
    if (m.containsKey(k) && m[k] != null && '${m[k]}'.trim().isNotEmpty) return m[k];
  }
  return null;
}

String _s(Map<String, dynamic> m, List<String> keys, {String fallback = ''}) {
  final v = _value(m, keys);
  if (v == null) return fallback;
  final text = '$v'.trim();
  return text.isEmpty ? fallback : text;
}

String _opponent(Map<String, dynamic> m) {
  return _s(m, ['opponent', 'opponent_name', 'team2_name', 'away_team', 'rival'], fallback: 'Соперник');
}

int _toInt(dynamic v) {
  if (v is int) return v;
  if (v is double) return v.round();
  if (v == null) return 0;
  return int.tryParse('$v'.replaceAll(RegExp(r'[^0-9\-]'), '')) ?? 0;
}

double _num(Map<String, dynamic> m, List<String> keys, double fallback) {
  final v = _value(m, keys);
  if (v is num) return v.toDouble();
  return double.tryParse('$v'.replaceAll(',', '.')) ?? fallback;
}

DateTime _dateOf(Map<String, dynamic> m) {
  final raw = _s(m, ['match_date', 'date', 'created_at', 'start_at']);
  return DateTime.tryParse(raw) ?? DateTime.now();
}

String _formatDate(DateTime d) {
  return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}

String _monthShort(DateTime d) {
  const months = ['янв', 'фев', 'мар', 'апр', 'май', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
  return months[d.month - 1];
}
