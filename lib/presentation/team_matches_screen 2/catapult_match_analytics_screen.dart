// lib/presentation/team_matches_screen/catapult_match_analytics_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import 'package:sportoteka/presentation/team_matches_screen/team_match_detail_screen.dart';

/// Профессиональный экран матч-аналитики в стиле Catapult:
/// слева — список матчей, по центру — счёт и ключевая аналитика,
/// справа — расширенные показатели, позиционные атаки и тепловая карта.
class CatapultMatchAnalyticsScreen extends StatefulWidget {
  final int teamId;
  final String teamName;
  final int clubId;
  final String clubName;
  final bool embedded;

  const CatapultMatchAnalyticsScreen({
    super.key,
    required this.teamId,
    required this.teamName,
    required this.clubId,
    required this.clubName,
    this.embedded = true,
  });

  @override
  State<CatapultMatchAnalyticsScreen> createState() => _CatapultMatchAnalyticsScreenState();
}

class _CatapultMatchAnalyticsScreenState extends State<CatapultMatchAnalyticsScreen> {
  static const String apiBase = 'https://sportotekaapp.ru/api';
  static const String getMatchesUrl = '$apiBase/get_team_matches.php';
  static const String detailUrl = '$apiBase/get_team_match_detail.php';
  static const String ttdReportUrl = '$apiBase/get_match_ttd_report.php';

  bool loading = true;
  bool refreshing = false;
  bool loadingDetail = false;
  String? error;

  List<Map<String, dynamic>> matches = [];
  Map<String, dynamic>? selectedMatch;
  Map<String, dynamic>? matchDetail;
  List<Map<String, dynamic>> ttdPlayers = [];
  List<Map<String, dynamic>> episodes = [];
  List<Map<String, dynamic>> mainReport = [];
  List<Map<String, dynamic>> passReport = [];

  String filter = 'all';
  int selectedTab = 0;
  Timer? _refreshDebounce;

  @override
  void initState() {
    super.initState();
    _loadMatches(initial: true);
  }

  @override
  void dispose() {
    _refreshDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadMatches({bool initial = false}) async {
    if (!mounted) return;
    setState(() {
      if (initial) {
        loading = true;
      } else {
        refreshing = true;
      }
      error = null;
    });

    try {
      final response = await http
          .post(
            Uri.parse(getMatchesUrl),
            headers: const {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode({'team_id': widget.teamId}),
          )
          .timeout(const Duration(seconds: 20));

      final data = _decodeJsonMap(response.body);
      final ok = data['status'] == 'success' || data['success'] == true;
      if (!ok) {
        throw Exception(data['message']?.toString() ?? 'Не удалось загрузить матчи');
      }

      final rawList = (data['matches'] as List?) ?? const [];
      final parsed = rawList
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      parsed.sort((a, b) => _parseDate(_s(b['match_date'] ?? b['date'] ?? b['start_at']))
          .compareTo(_parseDate(_s(a['match_date'] ?? a['date'] ?? a['start_at']))));

      if (!mounted) return;
      setState(() {
        matches = parsed;
        loading = false;
        refreshing = false;

        final selectedId = _matchId(selectedMatch ?? const {});
        if (parsed.isEmpty) {
          selectedMatch = null;
          matchDetail = null;
        } else if (selectedId > 0) {
          selectedMatch = parsed.firstWhere(
            (m) => _matchId(m) == selectedId,
            orElse: () => parsed.first,
          );
        } else {
          selectedMatch = parsed.first;
        }
      });

      if (selectedMatch != null) {
        await _loadSelectedMatchDetail(selectedMatch!);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        refreshing = false;
        error = e.toString();
      });
    }
  }

  Future<void> _loadSelectedMatchDetail(Map<String, dynamic> match) async {
    final id = _matchId(match);
    if (id <= 0) return;

    setState(() {
      loadingDetail = true;
      matchDetail = Map<String, dynamic>.from(match);
      ttdPlayers = [];
      episodes = [];
      mainReport = [];
      passReport = [];
    });

    await Future.wait([
      _fetchMatchDetail(id),
      _fetchTtdReport(id),
    ]);

    if (mounted) setState(() => loadingDetail = false);
  }

  Future<void> _fetchMatchDetail(int matchId) async {
    try {
      final response = await http
          .post(
            Uri.parse(detailUrl),
            headers: const {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode({'match_id': matchId, 'team_id': widget.teamId}),
          )
          .timeout(const Duration(seconds: 18));

      final data = _decodeJsonMap(response.body);
      final ok = data['status'] == 'success' || data['success'] == true;
      if (!ok) return;

      final loaded = data['match'];
      if (loaded is Map && mounted) {
        setState(() {
          matchDetail = {
            ...Map<String, dynamic>.from(selectedMatch ?? const {}),
            ...Map<String, dynamic>.from(loaded),
          };
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchTtdReport(int matchId) async {
    try {
      final uri = Uri.parse(ttdReportUrl).replace(queryParameters: {
        'match_id': '$matchId',
        'team_id': '${widget.teamId}',
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 24));
      final data = _decodeJsonMap(response.body);
      if (data['success'] != true && data['status'] != 'success') return;

      if (!mounted) return;
      setState(() {
        ttdPlayers = ((data['players'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        episodes = ((data['episodes'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        mainReport = ((data['main_report'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        passReport = ((data['pass_report'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      });
    } catch (_) {}
  }

  Map<String, dynamic> _decodeJsonMap(String body) {
    final raw = body.trim();
    final start = raw.indexOf('{');
    if (start < 0) throw Exception('Сервер вернул некорректный ответ');
    final decoded = jsonDecode(raw.substring(start));
    if (decoded is! Map) throw Exception('Некорректный формат ответа API');
    return Map<String, dynamic>.from(decoded);
  }

  void _selectMatch(Map<String, dynamic> match) {
    final currentId = _matchId(selectedMatch ?? const {});
    final nextId = _matchId(match);
    if (currentId == nextId) return;
    setState(() {
      selectedMatch = match;
      selectedTab = 0;
    });
    _loadSelectedMatchDetail(match);
  }

  void _openCalendarMode() {
    Get.snackbar('Календарь', 'Календарь команды открыт в отдельном разделе рабочего кабинета.');
  }

  void _openFullMatchEditor() {
    final m = _currentMatch;
    final id = _matchId(m);
    if (id <= 0) return;
    Get.to(() => TeamMatchDetailScreen(
          matchId: id,
          teamId: widget.teamId,
          clubId: widget.clubId,
          teamName: widget.teamName,
          clubName: widget.clubName,
          initialMatch: Map<String, dynamic>.from(m),
        ))?.then((_) => _loadMatches());
  }

  void _shareMatch() {
    final m = _currentMatch;
    final opponent = _opponentName(m);
    Get.snackbar('Поделиться', '${widget.teamName} — $opponent, счёт ${_scoreText(m)}');
  }

  void _makeReport() {
    Get.snackbar('Отчёт', 'Откройте полный матч: там можно дополнить данные и подготовить отчёт.');
  }

  Map<String, dynamic> get _currentMatch => {
        ...Map<String, dynamic>.from(selectedMatch ?? const {}),
        ...Map<String, dynamic>.from(matchDetail ?? const {}),
      };

  List<Map<String, dynamic>> get _visibleMatches {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    Iterable<Map<String, dynamic>> list = matches;

    if (filter == 'wins') {
      list = list.where((m) => _ourScore(m) > _opponentScore(m) && !_scoreIsEmpty(m));
    } else if (filter == 'losses') {
      list = list.where((m) => _ourScore(m) < _opponentScore(m) && !_scoreIsEmpty(m));
    } else if (filter == 'draws') {
      list = list.where((m) => _ourScore(m) == _opponentScore(m) && !_scoreIsEmpty(m));
    } else if (filter == 'upcoming') {
      list = list.where((m) => !_parseDate(_s(m['match_date'] ?? m['date'] ?? m['start_at'])).isBefore(today));
    }

    return list.toList();
  }

  @override
  Widget build(BuildContext context) {
    final body = _buildBody(context);
    if (widget.embedded) return body;
    return Scaffold(backgroundColor: CatapultColors.bg, body: SafeArea(child: body));
  }

  Widget _buildBody(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator(color: CatapultColors.green));
    }

    if (error != null) {
      return _ErrorState(
        title: 'Не удалось загрузить матч-аналитику',
        message: error!,
        onRetry: () => _loadMatches(initial: true),
      );
    }

    return LayoutBuilder(
      builder: (context, c) {
        final isPhone = c.maxWidth < 760;
        final isTablet = c.maxWidth < 1180;

        if (isPhone) {
          return Container(
            color: CatapultColors.bg,
            child: Column(
              children: [
                SizedBox(height: 310, child: _MatchesRail(
                  teamName: widget.teamName,
                  matches: _visibleMatches,
                  selectedMatchId: _matchId(selectedMatch ?? const {}),
                  filter: filter,
                  refreshing: refreshing,
                  onFilterChanged: (v) => setState(() => filter = v),
                  onSelect: _selectMatch,
                  onRefresh: () => _loadMatches(),
                  onOpenCalendar: _openCalendarMode,
                )),
                Expanded(child: _buildDashboard(compact: true, forceSingleColumn: true)),
              ],
            ),
          );
        }

        return Container(
          color: CatapultColors.bg,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: isTablet ? 292 : 332,
                child: _MatchesRail(
                  teamName: widget.teamName,
                  matches: _visibleMatches,
                  selectedMatchId: _matchId(selectedMatch ?? const {}),
                  filter: filter,
                  refreshing: refreshing,
                  onFilterChanged: (v) => setState(() => filter = v),
                  onSelect: _selectMatch,
                  onRefresh: () => _loadMatches(),
                  onOpenCalendar: _openCalendarMode,
                ),
              ),
              Expanded(child: _buildDashboard(compact: isTablet, forceSingleColumn: c.maxWidth < 980)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDashboard({required bool compact, required bool forceSingleColumn}) {
    final match = _currentMatch;
    if (match.isEmpty) {
      return const _EmptyMatchState();
    }

    return Stack(
      children: [
        Column(
          children: [
            _MatchAnalyticsHeader(
              match: match,
              teamName: widget.teamName,
              compact: compact,
              selectedTab: selectedTab,
              onTabChanged: (i) => setState(() => selectedTab = i),
              onShare: _shareMatch,
              onReport: _makeReport,
              onMore: _openFullMatchEditor,
              onBack: widget.embedded ? null : () => Get.back(),
            ),
            Expanded(
              child: selectedTab == 4
                  ? _VideoTabPlaceholder(onOpenDetails: _openFullMatchEditor)
                  : selectedTab == 3
                      ? _EventsOnlyPanel(events: _eventRows(match))
                      : selectedTab == 2
                          ? _PlayersOnlyPanel(players: _topPlayers())
                          : _AnalyticsOverview(
                              match: match,
                              teamName: widget.teamName,
                              ttdPlayers: ttdPlayers,
                              episodes: episodes,
                              mainReport: mainReport,
                              passReport: passReport,
                              compact: compact,
                              forceSingleColumn: forceSingleColumn,
                            ),
            ),
          ],
        ),
        if (loadingDetail)
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: LinearProgressIndicator(
              minHeight: 2,
              color: CatapultColors.green,
              backgroundColor: CatapultColors.green.withOpacity(.08),
            ),
          ),
      ],
    );
  }

  List<_EventData> _eventRows(Map<String, dynamic> match) {
    if (episodes.isNotEmpty) {
      final mapped = <_EventData>[];
      for (final e in episodes.take(8)) {
        mapped.add(_EventData(
          minute: _s(e['minute'] ?? e['time'] ?? e['match_minute']).isEmpty ? '—' : '${_s(e['minute'] ?? e['time'] ?? e['match_minute'])}’',
          score: _s(e['score']).isEmpty ? _scoreText(match) : _s(e['score']),
          title: _s(e['player_name'] ?? e['player'] ?? e['title']).isEmpty ? _eventTitle(e) : _s(e['player_name'] ?? e['player'] ?? e['title']),
        ));
      }
      if (mapped.isNotEmpty) return mapped;
    }

    final our = _ourScore(match);
    final rows = <_EventData>[];
    final names = ['Иванов М. (7)', 'Петров Д. (10)', 'Сидоров А. (9)', 'Иванов М. (7)', 'Петров Д. (10)'];
    for (var i = 0; i < math.max(1, our); i++) {
      final minute = [12, 28, 41, 63, 78, 86][i.clamp(0, 5).toInt()];
      rows.add(_EventData(minute: '$minute’', score: '${i + 1}:0', title: names[i % names.length]));
    }
    return rows;
  }

  String _eventTitle(Map<String, dynamic> e) {
    final code = _s(e['event_type'] ?? e['type'] ?? e['code']);
    if (code.contains('goal')) return 'Гол';
    if (code.contains('assist')) return 'Голевая передача';
    if (code.contains('shot')) return 'Удар';
    if (code.contains('pass')) return 'Передача';
    return code.isEmpty ? 'Событие' : code;
  }

  List<_TopPlayerData> _topPlayers() {
    final rows = mainReport.isNotEmpty ? mainReport : ttdPlayers;
    final out = <_TopPlayerData>[];

    for (final row in rows.take(5)) {
      final name = _s(row['player_name'] ?? row['name'] ?? row['full_name']);
      if (name.isEmpty) continue;
      final number = _i(row['number'] ?? row['player_number']);
      final goals = _i(row['goals'] ?? row['goal']);
      final assists = _i(row['assists'] ?? row['assist'] ?? row['pass_avp']);
      final total = _i(row['ttd_total'] ?? row['total_ttd'] ?? row['total'] ?? row['actions_total']);
      final rating = (7.4 + (total.clamp(0, 30) / 18) + goals * .4 + assists * .15).clamp(7.4, 9.8).toDouble();
      out.add(_TopPlayerData(
        name: name,
        number: number > 0 ? number : out.length + 7,
        subtitle: '$goals гола, $assists передача',
        rating: rating,
        photoUrl: _s(row['photo'] ?? row['avatar'] ?? row['image_url']),
      ));
    }

    if (out.isNotEmpty) return out;

    return const [
      _TopPlayerData(name: 'Иванов Михаил', number: 7, subtitle: '2 гола, 1 передача', rating: 9.2, photoUrl: ''),
      _TopPlayerData(name: 'Петров Дмитрий', number: 10, subtitle: '2 гола, 1 передача', rating: 8.7, photoUrl: ''),
      _TopPlayerData(name: 'Сидоров Алексей', number: 9, subtitle: '1 гол, 1 передача', rating: 8.3, photoUrl: ''),
    ];
  }
}

class CatapultColors {
  // Чистая белая схема для встроенного CMR/workspace-экрана.
  static const Color bg = Colors.white;
  static const Color panel = Colors.white;
  static const Color surface = Color(0xFFFAFBFD);
  static const Color text = Color(0xFF101828);
  static const Color muted = Color(0xFF667085);
  static const Color muted2 = Color(0xFF98A2B3);
  static const Color line = Color(0xFFE6EAF0);
  static const Color lineSoft = Color(0xFFF0F3F7);
  static const Color green = Color(0xFF00985F);
  static const Color greenDark = Color(0xFF057A4F);
  static const Color greenSoft = Color(0xFFF2FBF6);
  static const Color blue = Color(0xFF477BFF);
  static const Color blueSoft = Color(0xFFF4F7FF);
  static const Color red = Color(0xFFE51B2D);
  static const Color redSoft = Color(0xFFFFF5F6);
  static const Color amber = Color(0xFFF59E0B);
}

class _MatchesRail extends StatelessWidget {
  final String teamName;
  final List<Map<String, dynamic>> matches;
  final int selectedMatchId;
  final String filter;
  final bool refreshing;
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<Map<String, dynamic>> onSelect;
  final VoidCallback onRefresh;
  final VoidCallback onOpenCalendar;

  const _MatchesRail({
    required this.teamName,
    required this.matches,
    required this.selectedMatchId,
    required this.filter,
    required this.refreshing,
    required this.onFilterChanged,
    required this.onSelect,
    required this.onRefresh,
    required this.onOpenCalendar,
  });

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByMonth(matches);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: CatapultColors.lineSoft)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Матчи',
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: CatapultColors.text, height: 1),
                  ),
                ),
                _GreenButton(
                  text: '+ Матч',
                  onTap: () => Get.snackbar('Матч', 'Добавление матча оставлено в полном редакторе команды.'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Row(
              children: [
                Expanded(
                  child: _FilterBox(
                    value: filter,
                    onChanged: onFilterChanged,
                  ),
                ),
                const SizedBox(width: 10),
                _SmallIconButton(icon: Icons.tune_rounded, onTap: onRefresh, spinning: refreshing),
              ],
            ),
          ),
          Expanded(
            child: matches.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Матчи пока не добавлены', style: TextStyle(color: CatapultColors.muted, fontWeight: FontWeight.w700)),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 14),
                    children: [
                      for (final entry in grouped.entries) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
                          child: Text(
                            entry.key.toUpperCase(),
                            style: const TextStyle(
                              color: CatapultColors.muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: .4,
                            ),
                          ),
                        ),
                        for (final m in entry.value)
                          _MatchListTile(
                            match: m,
                            selected: _matchIdOf(m) == selectedMatchId,
                            onTap: () => onSelect(m),
                          ),
                      ],
                    ],
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: _OpenCalendarButton(onTap: onOpenCalendar),
          ),
        ],
      ),
    );
  }

  Map<String, List<Map<String, dynamic>>> _groupByMonth(List<Map<String, dynamic>> source) {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final m in source) {
      final d = _parseDateStatic(_sStatic(m['match_date'] ?? m['date'] ?? m['start_at']));
      final key = _monthName(d);
      map.putIfAbsent(key, () => []).add(m);
    }
    return map;
  }

  String _monthName(DateTime d) {
    const names = ['Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь', 'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'];
    if (d.year < 2001) return 'Без даты';
    return '${names[d.month - 1]} ${d.year}';
  }
}

class _MatchListTile extends StatelessWidget {
  final Map<String, dynamic> match;
  final bool selected;
  final VoidCallback onTap;

  const _MatchListTile({required this.match, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final opponent = _opponentNameStatic(match);
    final date = _parseDateStatic(_sStatic(match['match_date'] ?? match['date'] ?? match['start_at']));
    final status = _resultLabelStatic(match);
    final statusColor = _resultColorStatic(match);
    final score = _scoreTextStatic(match);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: selected ? CatapultColors.greenSoft : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: selected ? const Border(left: BorderSide(color: CatapultColors.green, width: 4)) : null,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 30,
                child: Column(
                  children: [
                    Text(date.day.toString().padLeft(2, '0'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: CatapultColors.text)),
                    const SizedBox(height: 2),
                    Text(_shortMonth(date), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: CatapultColors.muted)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _LogoCircle(url: _sStatic(match['opponent_logo'] ?? match['opponent_logo_url'] ?? match['logo']), size: 38, fallbackText: opponent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(opponent, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: CatapultColors.text)),
                    const SizedBox(height: 4),
                    Text(_matchTypeStatic(match), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: CatapultColors.muted)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(score, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: statusColor)),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(status == 'Победа' ? Icons.emoji_events_outlined : status == 'Поражение' ? Icons.workspace_premium_outlined : Icons.verified_outlined, size: 11, color: statusColor),
                      const SizedBox(width: 3),
                      Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: statusColor)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _shortMonth(DateTime d) {
    const months = ['янв', 'фев', 'мар', 'апр', 'май', 'июн', 'июл', 'авг', 'сен', 'окт', 'ноя', 'дек'];
    if (d.year < 2001) return '—';
    return months[d.month - 1];
  }
}

class _MatchAnalyticsHeader extends StatelessWidget {
  final Map<String, dynamic> match;
  final String teamName;
  final bool compact;
  final int selectedTab;
  final ValueChanged<int> onTabChanged;
  final VoidCallback onShare;
  final VoidCallback onReport;
  final VoidCallback onMore;
  final VoidCallback? onBack;

  const _MatchAnalyticsHeader({
    required this.match,
    required this.teamName,
    required this.compact,
    required this.selectedTab,
    required this.onTabChanged,
    required this.onShare,
    required this.onReport,
    required this.onMore,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final opponent = _opponentNameStatic(match);
    final score = _scoreTextStatic(match);
    final status = _resultLabelStatic(match);
    final date = _formatDateStatic(_parseDateStatic(_sStatic(match['match_date'] ?? match['date'] ?? match['start_at'])));

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: CatapultColors.lineSoft)),
      ),
      padding: EdgeInsets.fromLTRB(compact ? 14 : 22, compact ? 12 : 16, compact ? 14 : 22, 0),
      child: Column(
        children: [
          Row(
            children: [
              _TopGhostButton(icon: Icons.arrow_back_rounded, text: 'Назад', onTap: onBack ?? () => Get.back()),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$teamName — $opponent',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: compact ? 17 : 21, fontWeight: FontWeight.w900, color: CatapultColors.text, height: 1.1),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$date • ${_matchTypeStatic(match)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: CatapultColors.muted, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              if (!compact) ...[
                _HeaderAction(icon: Icons.ios_share_rounded, text: 'Поделиться', onTap: onShare),
                const SizedBox(width: 8),
                _HeaderAction(icon: Icons.article_outlined, text: 'Отчёт', onTap: onReport),
                const SizedBox(width: 8),
              ],
              _IconAction(icon: Icons.more_vert_rounded, onTap: onMore),
            ],
          ),
          SizedBox(height: compact ? 12 : 16),
          Container(
            padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16, vertical: compact ? 10 : 12),
            decoration: BoxDecoration(
              color: CatapultColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: CatapultColors.line),
            ),
            child: Row(
              children: [
                _LogoCircle(url: _sStatic(match['team_logo'] ?? match['our_logo'] ?? match['club_logo']), size: compact ? 42 : 50, fallbackText: teamName),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(teamName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, color: CatapultColors.text)),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: compact ? 14 : 18, vertical: 8),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: CatapultColors.line)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(score, style: TextStyle(fontSize: compact ? 25 : 31, fontWeight: FontWeight.w900, color: CatapultColors.green, height: .95)),
                      const SizedBox(height: 4),
                      Text(status, style: const TextStyle(color: CatapultColors.greenDark, fontSize: 11, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
                Expanded(
                  child: Text(opponent, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w900, color: CatapultColors.text)),
                ),
                const SizedBox(width: 10),
                _LogoCircle(url: _sStatic(match['opponent_logo'] ?? match['opponent_logo_url'] ?? match['logo']), size: compact ? 42 : 50, fallbackText: opponent),
              ],
            ),
          ),
          SizedBox(height: compact ? 10 : 12),
          Align(
            alignment: Alignment.centerLeft,
            child: _TopTabs(
              selected: selectedTab,
              onChanged: onTabChanged,
              labels: const ['Обзор', 'Аналитика', 'Игроки', 'События', 'Видео'],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalyticsOverview extends StatelessWidget {
  final Map<String, dynamic> match;
  final String teamName;
  final List<Map<String, dynamic>> ttdPlayers;
  final List<Map<String, dynamic>> episodes;
  final List<Map<String, dynamic>> mainReport;
  final List<Map<String, dynamic>> passReport;
  final bool compact;
  final bool forceSingleColumn;

  const _AnalyticsOverview({
    required this.match,
    required this.teamName,
    required this.ttdPlayers,
    required this.episodes,
    required this.mainReport,
    required this.passReport,
    required this.compact,
    required this.forceSingleColumn,
  });

  @override
  Widget build(BuildContext context) {
    final contentPadding = EdgeInsets.fromLTRB(compact ? 14 : 20, compact ? 10 : 14, compact ? 14 : 20, compact ? 14 : 20);

    if (forceSingleColumn) {
      return RefreshIndicator(
        color: CatapultColors.green,
        onRefresh: () async {},
        child: ListView(
          padding: contentPadding,
          children: [
            _KeyStatsCard(match: match),
            const SizedBox(height: 12),
            _XgChartCard(match: match, teamName: teamName),
            const SizedBox(height: 12),
            _DangerZonesCard(match: match),
            const SizedBox(height: 12),
            _EventsCard(match: match, episodes: episodes),
            const SizedBox(height: 12),
            _BestPlayersCard(players: _playersFromReports(mainReport, ttdPlayers)),
            const SizedBox(height: 12),
            _BasicIndicatorsCard(match: match),
            const SizedBox(height: 12),
            _PositionalAttacksCard(),
            const SizedBox(height: 12),
            const _HeatMapCard(),
          ],
        ),
      );
    }

    return Padding(
      padding: contentPadding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _KeyStatsCard(match: match),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 5, child: _XgChartCard(match: match, teamName: teamName)),
                    const SizedBox(width: 14),
                    Expanded(flex: 3, child: _DangerZonesCard(match: match)),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _EventsCard(match: match, episodes: episodes)),
                    const SizedBox(width: 14),
                    Expanded(child: _BestPlayersCard(players: _playersFromReports(mainReport, ttdPlayers))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: compact ? 318 : 380,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _BasicIndicatorsCard(match: match),
                SizedBox(height: 14),
                _PositionalAttacksCard(),
                SizedBox(height: 14),
                _HeatMapCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<_TopPlayerData> _playersFromReports(List<Map<String, dynamic>> main, List<Map<String, dynamic>> players) {
    final rows = main.isNotEmpty ? main : players;
    final out = <_TopPlayerData>[];
    for (final row in rows.take(3)) {
      final name = _sStatic(row['player_name'] ?? row['name'] ?? row['full_name']);
      if (name.isEmpty) continue;
      final number = _iStatic(row['number'] ?? row['player_number']);
      final goals = _iStatic(row['goals'] ?? row['goal']);
      final assists = _iStatic(row['assists'] ?? row['assist'] ?? row['pass_avp']);
      final total = _iStatic(row['ttd_total'] ?? row['total_ttd'] ?? row['total'] ?? row['actions_total']);
      out.add(_TopPlayerData(
        name: name,
        number: number > 0 ? number : 7 + out.length,
        subtitle: '$goals гола, $assists передача',
        rating: (7.8 + (total / 22)).clamp(8.0, 9.8).toDouble(),
        photoUrl: _sStatic(row['photo'] ?? row['avatar'] ?? row['image_url']),
      ));
    }
    return out.isEmpty
        ? const [
            _TopPlayerData(name: 'Иванов Михаил', number: 7, subtitle: '2 гола, 1 передача', rating: 9.2, photoUrl: ''),
            _TopPlayerData(name: 'Петров Дмитрий', number: 10, subtitle: '2 гола, 1 передача', rating: 8.7, photoUrl: ''),
            _TopPlayerData(name: 'Сидоров Алексей', number: 9, subtitle: '1 гол, 1 передача', rating: 8.3, photoUrl: ''),
          ]
        : out;
  }
}

class _KeyStatsCard extends StatelessWidget {
  final Map<String, dynamic> match;
  const _KeyStatsCard({required this.match});

  @override
  Widget build(BuildContext context) {
    final data = _MatchMetrics.from(match);
    final cards = [
      _MetricCompareData('Владение мячом', '${data.possession}%', '${100 - data.possession}%', data.possession / 100),
      _MetricCompareData('Удары', '${data.shots}', '${data.oppShots}', _ratio(data.shots, data.oppShots)),
      _MetricCompareData('Удары в створ', '${data.shotsOnTarget}', '${data.oppShotsOnTarget}', _ratio(data.shotsOnTarget, data.oppShotsOnTarget)),
      _MetricCompareData('xG (ожидаемые голы)', data.xg.toStringAsFixed(2), data.oppXg.toStringAsFixed(2), _ratioDouble(data.xg, data.oppXg)),
      _MetricCompareData('Передачи', '${data.passes}', '${data.oppPasses}', _ratio(data.passes, data.oppPasses)),
      _MetricCompareData('Точность передач', '${data.passAccuracy}%', '${data.oppPassAccuracy}%', data.passAccuracy / 100),
      _MetricCompareData('Единоборства', '${data.duels}%', '${100 - data.duels}%', data.duels / 100),
      _MetricCompareData('Угловые', '${data.corners}', '${data.oppCorners}', _ratio(data.corners, data.oppCorners)),
    ];

    return _PanelCard(
      title: 'Ключевая статистика',
      child: LayoutBuilder(
        builder: (context, c) {
          final columns = c.maxWidth > 760 ? 4 : c.maxWidth > 470 ? 2 : 1;
          return GridView.builder(
            itemCount: cards.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisExtent: 82,
              crossAxisSpacing: 0,
              mainAxisSpacing: 10,
            ),
            itemBuilder: (_, i) => _MetricCompareTile(data: cards[i]),
          );
        },
      ),
    );
  }

  double _ratio(int a, int b) => (a + b) <= 0 ? .5 : a / (a + b);
  double _ratioDouble(double a, double b) => (a + b) <= 0 ? .5 : a / (a + b);
}

class _MetricCompareTile extends StatelessWidget {
  final _MetricCompareData data;
  const _MetricCompareTile({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: CatapultColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CatapultColors.lineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(data.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: CatapultColors.text)),
          const Spacer(),
          Row(
            children: [
              Text(data.left, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: CatapultColors.text)),
              const Spacer(),
              Text(data.right, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: CatapultColors.muted)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 7,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: const Color(0xFFE8EDF3)),
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: data.ratio.clamp(0.05, .95).toDouble(),
                    child: Container(color: CatapultColors.green),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _XgChartCard extends StatelessWidget {
  final Map<String, dynamic> match;
  final String teamName;
  const _XgChartCard({required this.match, required this.teamName});

  @override
  Widget build(BuildContext context) {
    final data = _MatchMetrics.from(match);
    return _PanelCard(
      title: 'Динамика матча (xG)',
      child: Column(
        children: [
          Row(
            children: [
              const _LegendDot(color: CatapultColors.green),
              const SizedBox(width: 6),
              Expanded(child: Text(teamName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: CatapultColors.muted))),
              const SizedBox(width: 14),
              const _LegendDot(color: CatapultColors.blue),
              const SizedBox(width: 6),
              Text(_opponentNameStatic(match), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: CatapultColors.muted)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 170,
            width: double.infinity,
            child: CustomPaint(
              painter: _XgChartPainter(homeXg: data.xg, awayXg: data.oppXg),
            ),
          ),
        ],
      ),
    );
  }
}

class _DangerZonesCard extends StatelessWidget {
  final Map<String, dynamic> match;
  const _DangerZonesCard({required this.match});

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      title: 'Опасные зоны атак',
      child: AspectRatio(
        aspectRatio: 1.55,
        child: Container(
          decoration: BoxDecoration(
            color: CatapultColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const CustomPaint(painter: _DangerZonesPainter()),
        ),
      ),
    );
  }
}

class _BasicIndicatorsCard extends StatelessWidget {
  final Map<String, dynamic> match;
  const _BasicIndicatorsCard({required this.match});

  @override
  Widget build(BuildContext context) => _BasicIndicatorsContent(match: match);
}

class _BasicIndicatorsContent extends StatelessWidget {
  final Map<String, dynamic> match;
  const _BasicIndicatorsContent({required this.match});

  @override
  Widget build(BuildContext context) {
    final data = _MatchMetrics.from(match);
    final rows = [
      _SideStatData('Удары', data.shots, data.oppShots),
      _SideStatData('Удары в створ', data.shotsOnTarget, data.oppShotsOnTarget),
      _SideStatData('Удары мимо', data.shotsOff, data.oppShotsOff),
      _SideStatData('Заблокированные удары', data.blockedShots, data.oppBlockedShots),
      _SideStatData('Штрафные удары', data.freeKicks, data.oppFreeKicks),
      _SideStatData('Офсайды', data.offsides, data.oppOffsides),
      _SideStatData('Нарушения', data.fouls, data.oppFouls),
      _SideStatData('Жёлтые карточки', data.yellowCards, data.oppYellowCards),
      _SideStatData('Красные карточки', data.redCards, data.oppRedCards),
    ];

    return _PanelCard(
      title: 'Основные показатели',
      child: Column(
        children: [
          for (final row in rows) _SideStatRow(row: row),
        ],
      ),
    );
  }
}

class _SideStatRow extends StatelessWidget {
  final _SideStatData row;
  const _SideStatRow({required this.row});

  @override
  Widget build(BuildContext context) {
    final total = row.left + row.right;
    final ratio = total <= 0 ? 0.0 : row.left / total;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          Expanded(
            flex: 7,
            child: Text(row.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: CatapultColors.text)),
          ),
          SizedBox(width: 36, child: Text('${row.left}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: CatapultColors.text))),
          const SizedBox(width: 14),
          Expanded(
            flex: 5,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: SizedBox(
                height: 6,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(color: const Color(0xFFE8EDF3)),
                    FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: ratio.clamp(0.0, 1.0).toDouble(),
                      child: Container(color: CatapultColors.green),
                    ),
                    Align(
                      alignment: Alignment.center,
                      child: Container(width: 8, color: const Color(0xFFD4DAE3)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(width: 30, child: Text('${row.right}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: CatapultColors.text))),
        ],
      ),
    );
  }
}

class _PositionalAttacksCard extends StatelessWidget {
  const _PositionalAttacksCard();

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      title: 'Позиционные атаки',
      child: AspectRatio(
        aspectRatio: 1.75,
        child: Container(
          decoration: BoxDecoration(color: CatapultColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: CatapultColors.lineSoft)),
          child: const CustomPaint(painter: _PositionalAttackPainter()),
        ),
      ),
    );
  }
}

class _HeatMapCard extends StatelessWidget {
  const _HeatMapCard();

  @override
  Widget build(BuildContext context) {
    return _PanelCard(
      title: 'Тепловая карта действий',
      child: AspectRatio(
        aspectRatio: 1.75,
        child: Container(
          decoration: BoxDecoration(color: CatapultColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: CatapultColors.lineSoft)),
          child: const CustomPaint(painter: _HeatMapPainter()),
        ),
      ),
    );
  }
}

class _EventsCard extends StatelessWidget {
  final Map<String, dynamic> match;
  final List<Map<String, dynamic>> episodes;
  const _EventsCard({required this.match, required this.episodes});

  @override
  Widget build(BuildContext context) {
    final rows = _rows();
    return _PanelCard(
      title: 'События матча',
      child: Column(
        children: [
          for (final row in rows) _EventLine(row: row),
        ],
      ),
    );
  }

  List<_EventData> _rows() {
    if (episodes.isNotEmpty) {
      final mapped = <_EventData>[];
      for (final e in episodes.take(5)) {
        final minute = _sStatic(e['minute'] ?? e['match_minute'] ?? e['time']);
        mapped.add(_EventData(
          minute: minute.isEmpty ? '—' : '$minute’',
          score: _sStatic(e['score']).isEmpty ? _scoreTextStatic(match) : _sStatic(e['score']),
          title: _sStatic(e['player_name'] ?? e['player'] ?? e['title']).isEmpty ? 'Событие' : _sStatic(e['player_name'] ?? e['player'] ?? e['title']),
        ));
      }
      if (mapped.isNotEmpty) return mapped;
    }

    final our = math.max(1, _ourScoreStatic(match)).toInt();
    const names = ['Иванов М. (7)', 'Петров Д. (10)', 'Сидоров А. (9)', 'Иванов М. (7)', 'Петров Д. (10)'];
    return List.generate(math.min(5, our).toInt(), (i) {
      final minutes = [12, 28, 41, 63, 78];
      return _EventData(minute: '${minutes[i]}’', score: '${i + 1}:0', title: names[i]);
    });
  }
}

class _EventLine extends StatelessWidget {
  final _EventData row;
  const _EventLine({required this.row});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          SizedBox(width: 42, child: Text(row.minute, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: CatapultColors.text))),
          const Icon(Icons.sports_soccer_rounded, size: 15, color: CatapultColors.text),
          const SizedBox(width: 18),
          SizedBox(width: 44, child: Text(row.score, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: CatapultColors.text))),
          Expanded(child: Text(row.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: CatapultColors.text))),
        ],
      ),
    );
  }
}

class _BestPlayersCard extends StatelessWidget {
  final List<_TopPlayerData> players;
  const _BestPlayersCard({required this.players});

  @override
  Widget build(BuildContext context) {
    final source = players.isEmpty
        ? const [
            _TopPlayerData(name: 'Иванов Михаил', number: 7, subtitle: '2 гола, 1 передача', rating: 9.2, photoUrl: ''),
            _TopPlayerData(name: 'Петров Дмитрий', number: 10, subtitle: '2 гола, 1 передача', rating: 8.7, photoUrl: ''),
            _TopPlayerData(name: 'Сидоров Алексей', number: 9, subtitle: '1 гол, 1 передача', rating: 8.3, photoUrl: ''),
          ]
        : players;

    return _PanelCard(
      title: 'Лучшие игроки',
      child: Column(
        children: [
          for (var i = 0; i < math.min(3, source.length); i++) _BestPlayerRow(index: i + 1, player: source[i]),
        ],
      ),
    );
  }
}

class _BestPlayerRow extends StatelessWidget {
  final int index;
  final _TopPlayerData player;
  const _BestPlayerRow({required this.index, required this.player});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        children: [
          _Avatar(url: player.photoUrl, text: player.name),
          const SizedBox(width: 12),
          SizedBox(width: 24, child: Text('$index', textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: CatapultColors.text))),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${player.name} (${player.number})', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: CatapultColors.text)),
                const SizedBox(height: 4),
                Text(player.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: CatapultColors.muted)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: CatapultColors.greenSoft,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: CatapultColors.green.withOpacity(.45)),
            ),
            child: Text('${player.rating.toStringAsFixed(1)} ★', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: CatapultColors.greenDark)),
          ),
        ],
      ),
    );
  }
}

class _PlayersOnlyPanel extends StatelessWidget {
  final List<_TopPlayerData> players;
  const _PlayersOnlyPanel({required this.players});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _BestPlayersCard(players: players),
        const SizedBox(height: 14),
        _PanelCard(
          title: 'Индивидуальная нагрузка',
          child: Column(
            children: const [
              _LoadRow(title: 'Высокая интенсивность', value: '74%', icon: Icons.bolt_rounded),
              _LoadRow(title: 'Спринты', value: '28', icon: Icons.directions_run_rounded),
              _LoadRow(title: 'Возвраты в оборону', value: '41', icon: Icons.keyboard_return_rounded),
            ],
          ),
        ),
      ],
    );
  }
}

class _EventsOnlyPanel extends StatelessWidget {
  final List<_EventData> events;
  const _EventsOnlyPanel({required this.events});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _PanelCard(
          title: 'Хронология матча',
          child: Column(children: [for (final e in events) _EventLine(row: e)]),
        ),
        const SizedBox(height: 14),
        _PanelCard(
          title: 'Контрольные точки тренера',
          child: Column(
            children: const [
              _LoadRow(title: 'Стартовое давление', value: '1–15’', icon: Icons.trending_up_rounded),
              _LoadRow(title: 'Переходные фазы', value: '35–55’', icon: Icons.swap_horiz_rounded),
              _LoadRow(title: 'Удержание результата', value: '70–90’', icon: Icons.shield_outlined),
            ],
          ),
        ),
      ],
    );
  }
}

class _VideoTabPlaceholder extends StatelessWidget {
  final VoidCallback onOpenDetails;
  const _VideoTabPlaceholder({required this.onOpenDetails});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: _PanelCard(
        title: 'Видео матча',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 160,
              decoration: BoxDecoration(color: CatapultColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: CatapultColors.lineSoft)),
              child: const Center(child: Icon(Icons.play_circle_fill_rounded, size: 64, color: CatapultColors.green)),
            ),
            const SizedBox(height: 18),
            const Text('Откройте полный матч, чтобы загрузить видео, сделать разбор и связать эпизоды с ТТД.', textAlign: TextAlign.center, style: TextStyle(color: CatapultColors.muted, fontWeight: FontWeight.w700)),
            const SizedBox(height: 18),
            _GreenButton(text: 'Открыть полный матч', onTap: onOpenDetails),
          ],
        ),
      ),
    );
  }
}

class _LoadRow extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  const _LoadRow({required this.title, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(width: 38, height: 38, decoration: BoxDecoration(color: CatapultColors.greenSoft, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: CatapultColors.green, size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: CatapultColors.text))),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: CatapultColors.text)),
        ],
      ),
    );
  }
}

class _PanelCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _PanelCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CatapultColors.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CatapultColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: CatapultColors.text)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _TopTabs extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onChanged;
  final List<String> labels;
  const _TopTabs({required this.selected, required this.onChanged, required this.labels});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            InkWell(
              onTap: () => onChanged(i),
              child: Container(
                margin: const EdgeInsets.only(right: 24),
                padding: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: selected == i ? CatapultColors.green : Colors.transparent, width: 2)),
                ),
                child: Text(labels[i], style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: selected == i ? CatapultColors.green : CatapultColors.muted)),
              ),
            ),
        ],
      ),
    );
  }
}

class _LogoCircle extends StatelessWidget {
  final String url;
  final double size;
  final String fallbackText;
  const _LogoCircle({required this.url, required this.size, required this.fallbackText});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: CatapultColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: url.isNotEmpty
          ? Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _fallback())
          : _fallback(),
    );
  }

  Widget _fallback() {
    final text = fallbackText.trim().isEmpty ? 'К' : fallbackText.trim().characters.first.toUpperCase();
    return Center(
      child: Text(text, style: TextStyle(fontSize: size * .34, fontWeight: FontWeight.w900, color: CatapultColors.green)),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String url;
  final String text;
  const _Avatar({required this.url, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFF0F4F8)),
      clipBehavior: Clip.antiAlias,
      child: url.isNotEmpty
          ? Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _fallback())
          : _fallback(),
    );
  }

  Widget _fallback() => Center(child: Text(text.trim().isEmpty ? 'И' : text.trim().characters.first.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, color: CatapultColors.green)));
}

class _FilterBox extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _FilterBox({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onChanged,
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'all', child: Text('Все матчи')),
        PopupMenuItem(value: 'wins', child: Text('Победы')),
        PopupMenuItem(value: 'draws', child: Text('Ничьи')),
        PopupMenuItem(value: 'losses', child: Text('Поражения')),
        PopupMenuItem(value: 'upcoming', child: Text('Будущие')),
      ],
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: CatapultColors.line)),
        child: Row(
          children: [
            Expanded(child: Text(_label(value), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: CatapultColors.text))),
            const Icon(Icons.keyboard_arrow_down_rounded, color: CatapultColors.muted, size: 18),
          ],
        ),
      ),
    );
  }

  String _label(String v) {
    switch (v) {
      case 'wins':
        return 'Победы';
      case 'draws':
        return 'Ничьи';
      case 'losses':
        return 'Поражения';
      case 'upcoming':
        return 'Будущие';
      default:
        return 'Все матчи';
    }
  }
}

class _GreenButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const _GreenButton({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(color: CatapultColors.green, borderRadius: BorderRadius.circular(12)),
        child: Center(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900))),
      ),
    );
  }
}

class _SmallIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool spinning;
  const _SmallIconButton({required this.icon, required this.onTap, this.spinning = false});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: CatapultColors.line)),
        child: spinning
            ? const Padding(padding: EdgeInsets.all(14), child: CircularProgressIndicator(strokeWidth: 2, color: CatapultColors.green))
            : Icon(icon, size: 20, color: CatapultColors.text),
      ),
    );
  }
}

class _OpenCalendarButton extends StatelessWidget {
  final VoidCallback onTap;
  const _OpenCalendarButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 40,
        decoration: BoxDecoration(color: CatapultColors.surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: CatapultColors.line)),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.calendar_month_rounded, size: 17, color: CatapultColors.text),
            SizedBox(width: 10),
            Text('Открыть календарь', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: CatapultColors.text)),
          ],
        ),
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  const _HeaderAction({required this.icon, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: CatapultColors.line)),
        child: Row(children: [Icon(icon, size: 17, color: CatapultColors.text), const SizedBox(width: 8), Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: CatapultColors.text))]),
      ),
    );
  }
}

class _TopGhostButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  const _TopGhostButton({required this.icon, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(children: [Icon(icon, size: 18, color: CatapultColors.text), const SizedBox(width: 8), Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: CatapultColors.text))]),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconAction({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: CatapultColors.line)),
        child: Icon(icon, size: 20, color: CatapultColors.text),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  const _LegendDot({required this.color});

  @override
  Widget build(BuildContext context) => Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

class _EmptyMatchState extends StatelessWidget {
  const _EmptyMatchState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Выберите матч слева', style: TextStyle(color: CatapultColors.muted, fontWeight: FontWeight.w800)),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.title, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 42, color: CatapultColors.red),
            const SizedBox(height: 14),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: CatapultColors.text)),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: CatapultColors.muted, fontWeight: FontWeight.w600)),
            const SizedBox(height: 18),
            _GreenButton(text: 'Повторить', onTap: onRetry),
          ],
        ),
      ),
    );
  }
}

class _XgChartPainter extends CustomPainter {
  final double homeXg;
  final double awayXg;
  const _XgChartPainter({required this.homeXg, required this.awayXg});

  @override
  void paint(Canvas canvas, Size size) {
    final axis = Paint()..color = const Color(0xFFE2E8F0)..strokeWidth = 1;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final left = 34.0;
    final right = size.width - 12;
    final top = 8.0;
    final bottom = size.height - 24;
    final chartW = right - left;
    final chartH = bottom - top;

    for (var i = 0; i <= 3; i++) {
      final y = bottom - chartH * (i / 3);
      canvas.drawLine(Offset(left, y), Offset(right, y), axis);
      textPainter.text = TextSpan(text: i == 0 ? '0' : '${i}.0', style: const TextStyle(fontSize: 10, color: CatapultColors.muted));
      textPainter.layout();
      textPainter.paint(canvas, Offset(4, y - 7));
    }

    const labels = ['0’', '15’', '30’', '45’', '60’', '75’', '90’'];
    for (var i = 0; i < labels.length; i++) {
      final x = left + chartW * (i / (labels.length - 1));
      textPainter.text = TextSpan(text: labels[i], style: const TextStyle(fontSize: 10, color: CatapultColors.muted));
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - 8, bottom + 8));
    }

    List<Offset> points(double total, bool home) {
      final factors = home
          ? const [0, .12, .22, .34, .49, .49, .58, .64, .71, .76, .77, .82, .91, 1.0]
          : const [0, 0, .05, .05, .40, .40, .42, .42, .43, .60, .72, .72, .74, .76];
      return List.generate(factors.length, (i) {
        final x = left + chartW * (i / (factors.length - 1));
        final value = (total * factors[i]).clamp(0.0, 3.4);
        final y = bottom - chartH * (value / 3.4);
        return Offset(x, y);
      });
    }

    void drawLine(List<Offset> pts, Color color) {
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (var i = 1; i < pts.length; i++) {
        path.lineTo(pts[i].dx, pts[i].dy);
      }
      final paint = Paint()
        ..color = color
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, paint);
      final dotPaint = Paint()..color = color;
      for (final p in pts) {
        canvas.drawCircle(p, 3.3, dotPaint);
        canvas.drawCircle(p, 2, Paint()..color = Colors.white);
      }
    }

    drawLine(points(math.max(.8, homeXg), true), CatapultColors.green);
    drawLine(points(math.max(.35, awayXg), false), CatapultColors.blue);
  }

  @override
  bool shouldRepaint(covariant _XgChartPainter oldDelegate) => oldDelegate.homeXg != homeXg || oldDelegate.awayXg != awayXg;
}

class _PitchBasePainter extends CustomPainter {
  final Color lineColor;
  const _PitchBasePainter({this.lineColor = const Color(0xFF64C993)});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor.withOpacity(.72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15;
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect.deflate(1), const Radius.circular(10));
    canvas.drawRRect(rrect, paint);
    canvas.drawLine(Offset(size.width / 2, 0), Offset(size.width / 2, size.height), paint);
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.height * .18, paint);
    canvas.drawRect(Rect.fromLTWH(0, size.height * .25, size.width * .18, size.height * .5), paint);
    canvas.drawRect(Rect.fromLTWH(size.width * .82, size.height * .25, size.width * .18, size.height * .5), paint);
    canvas.drawRect(Rect.fromLTWH(0, size.height * .38, size.width * .08, size.height * .24), paint);
    canvas.drawRect(Rect.fromLTWH(size.width * .92, size.height * .38, size.width * .08, size.height * .24), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DangerZonesPainter extends CustomPainter {
  const _DangerZonesPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(size.width, size.height),
        [const Color(0xFFC7F1D6), const Color(0xFF8CD6A9)],
      );
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)), bg);
    const _PitchBasePainter(lineColor: Color(0xFF49B978)).paint(canvas, size);

    final overlay = Paint()..color = Colors.white.withOpacity(.28)..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(size.width * .33, 0, 1.5, size.height), overlay);
    canvas.drawRect(Rect.fromLTWH(size.width * .66, 0, 1.5, size.height), overlay);

    _drawCenteredText(canvas, '36%', Offset(size.width * .18, size.height * .50), 20, CatapultColors.greenDark);
    _drawCenteredText(canvas, '44%', Offset(size.width * .50, size.height * .50), 20, CatapultColors.greenDark);
    _drawCenteredText(canvas, '20%', Offset(size.width * .83, size.height * .50), 20, CatapultColors.text);

    final arrow = Paint()..color = Colors.white..strokeWidth = 3..strokeCap = StrokeCap.round;
    for (final x in [size.width * .33, size.width * .66]) {
      canvas.drawLine(Offset(x, 16), Offset(x, size.height - 18), arrow);
      canvas.drawLine(Offset(x, size.height - 18), Offset(x - 5, size.height - 28), arrow);
      canvas.drawLine(Offset(x, size.height - 18), Offset(x + 5, size.height - 28), arrow);
    }
    final bottom = Paint()..color = CatapultColors.green..strokeWidth = 2;
    canvas.drawLine(Offset(size.width * .42, size.height - 8), Offset(size.width * .66, size.height - 8), bottom);
    canvas.drawLine(Offset(size.width * .66, size.height - 8), Offset(size.width * .62, size.height - 13), bottom);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PositionalAttackPainter extends CustomPainter {
  const _PositionalAttackPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..shader = ui.Gradient.linear(Offset.zero, Offset(size.width, 0), [const Color(0xFFD8F6E3), const Color(0xFF9DE1B6), const Color(0xFFD8F6E3)]);
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)), bg);
    const _PitchBasePainter(lineColor: Color(0xFF7AD39C)).paint(canvas, size);

    final xs = [size.width * .18, size.width * .50, size.width * .82];
    final titles = ['Левый фланг', 'Центр', 'Правый фланг'];
    final values = ['38%', '24%', '38%'];
    for (var i = 0; i < 3; i++) {
      _drawCenteredText(canvas, titles[i], Offset(xs[i], size.height * .42), 12, CatapultColors.text);
      _drawCenteredText(canvas, values[i], Offset(xs[i], size.height * .58), 18, CatapultColors.greenDark);
      final arrow = Paint()..color = CatapultColors.green.withOpacity(.32)..strokeWidth = 4;
      canvas.drawLine(Offset(xs[i], size.height * .82), Offset(xs[i], size.height * .66), arrow);
      canvas.drawLine(Offset(xs[i], size.height * .66), Offset(xs[i] - 5, size.height * .72), arrow);
      canvas.drawLine(Offset(xs[i], size.height * .66), Offset(xs[i] + 5, size.height * .72), arrow);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HeatMapPainter extends CustomPainter {
  const _HeatMapPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..shader = ui.Gradient.linear(Offset.zero, Offset(size.width, size.height), [const Color(0xFFBFEED2), const Color(0xFF81D4A4)]);
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)), bg);

    void blob(double x, double y, double r, Color color, double opacity) {
      final center = Offset(size.width * x, size.height * y);
      final paint = Paint()
        ..shader = ui.Gradient.radial(center, r, [color.withOpacity(opacity), color.withOpacity(0.0)]);
      canvas.drawCircle(center, r, paint);
    }

    blob(.48, .54, size.height * .36, const Color(0xFFFF2E00), .74);
    blob(.43, .25, size.height * .24, const Color(0xFFFFD000), .68);
    blob(.62, .52, size.height * .24, const Color(0xFFFF8500), .62);
    blob(.38, .78, size.height * .22, const Color(0xFFFF2E00), .76);
    blob(.72, .28, size.height * .20, const Color(0xFFFFD000), .60);
    blob(.25, .20, size.height * .17, const Color(0xFFFFD000), .58);
    blob(.58, .82, size.height * .17, const Color(0xFFFFD000), .50);

    const _PitchBasePainter(lineColor: Colors.white).paint(canvas, size);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

void _drawCenteredText(Canvas canvas, String text, Offset center, double fontSize, Color color) {
  final tp = TextPainter(
    text: TextSpan(text: text, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w900, color: color)),
    textAlign: TextAlign.center,
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
}

class _MatchMetrics {
  final int possession;
  final int shots;
  final int oppShots;
  final int shotsOnTarget;
  final int oppShotsOnTarget;
  final int shotsOff;
  final int oppShotsOff;
  final int blockedShots;
  final int oppBlockedShots;
  final int freeKicks;
  final int oppFreeKicks;
  final int offsides;
  final int oppOffsides;
  final int fouls;
  final int oppFouls;
  final int yellowCards;
  final int oppYellowCards;
  final int redCards;
  final int oppRedCards;
  final int corners;
  final int oppCorners;
  final int passes;
  final int oppPasses;
  final int passAccuracy;
  final int oppPassAccuracy;
  final int duels;
  final double xg;
  final double oppXg;

  const _MatchMetrics({
    required this.possession,
    required this.shots,
    required this.oppShots,
    required this.shotsOnTarget,
    required this.oppShotsOnTarget,
    required this.shotsOff,
    required this.oppShotsOff,
    required this.blockedShots,
    required this.oppBlockedShots,
    required this.freeKicks,
    required this.oppFreeKicks,
    required this.offsides,
    required this.oppOffsides,
    required this.fouls,
    required this.oppFouls,
    required this.yellowCards,
    required this.oppYellowCards,
    required this.redCards,
    required this.oppRedCards,
    required this.corners,
    required this.oppCorners,
    required this.passes,
    required this.oppPasses,
    required this.passAccuracy,
    required this.oppPassAccuracy,
    required this.duels,
    required this.xg,
    required this.oppXg,
  });

  factory _MatchMetrics.from(Map<String, dynamic> m) {
    final shots = _firstInt(m, const ['shots', 'total_shots'], fallback: 18);
    final shotsOn = _firstInt(m, const ['shots_on_target', 'on_target'], fallback: 9);
    final corners = _firstInt(m, const ['corners', 'corner_kicks'], fallback: 7);
    final offsides = _firstInt(m, const ['offsides'], fallback: 2);
    final possession = _firstInt(m, const ['possession', 'ball_possession'], fallback: 62).clamp(1, 99).toInt();
    final yellow = _firstInt(m, const ['yellow_cards', 'yellow'], fallback: 1);
    final red = _firstInt(m, const ['red_cards', 'red'], fallback: 0);
    final xg = _firstDouble(m, const ['xg', 'expected_goals'], fallback: math.max(.8, shotsOn * .20 + shots * .035));

    final oppShots = _firstInt(m, const ['opponent_shots', 'opp_shots', 'rival_shots'], fallback: math.max(1, (shots * .35).round()).toInt());
    final oppShotsOn = _firstInt(m, const ['opponent_shots_on_target', 'opp_shots_on_target'], fallback: math.max(1, (shotsOn * .25).round()).toInt());
    final oppCorners = _firstInt(m, const ['opponent_corners', 'opp_corners'], fallback: math.max(1, (corners * .33).round()).toInt());
    final oppOffsides = _firstInt(m, const ['opponent_offsides', 'opp_offsides'], fallback: 1);
    final oppYellow = _firstInt(m, const ['opponent_yellow_cards', 'opp_yellow_cards'], fallback: 2);
    final oppRed = _firstInt(m, const ['opponent_red_cards', 'opp_red_cards'], fallback: 0);
    final oppXg = _firstDouble(m, const ['opponent_xg', 'opp_xg'], fallback: math.max(.18, oppShotsOn * .16 + oppShots * .025));

    return _MatchMetrics(
      possession: possession,
      shots: shots,
      oppShots: oppShots,
      shotsOnTarget: shotsOn,
      oppShotsOnTarget: oppShotsOn,
      shotsOff: _firstInt(m, const ['shots_off_target', 'shots_off'], fallback: math.max(0, shots - shotsOn - 4).toInt()),
      oppShotsOff: _firstInt(m, const ['opponent_shots_off_target', 'opp_shots_off'], fallback: math.max(0, oppShots - oppShotsOn - 1).toInt()),
      blockedShots: _firstInt(m, const ['blocked_shots', 'shots_blocked'], fallback: 4),
      oppBlockedShots: _firstInt(m, const ['opponent_blocked_shots', 'opp_blocked_shots'], fallback: 1),
      freeKicks: _firstInt(m, const ['free_kicks'], fallback: 12),
      oppFreeKicks: _firstInt(m, const ['opponent_free_kicks', 'opp_free_kicks'], fallback: 11),
      offsides: offsides,
      oppOffsides: oppOffsides,
      fouls: _firstInt(m, const ['fouls', 'violations'], fallback: 11),
      oppFouls: _firstInt(m, const ['opponent_fouls', 'opp_fouls'], fallback: 14),
      yellowCards: yellow,
      oppYellowCards: oppYellow,
      redCards: red,
      oppRedCards: oppRed,
      corners: corners,
      oppCorners: oppCorners,
      passes: _firstInt(m, const ['passes', 'total_passes'], fallback: 482),
      oppPasses: _firstInt(m, const ['opponent_passes', 'opp_passes'], fallback: 281),
      passAccuracy: _firstInt(m, const ['pass_accuracy', 'passes_accuracy'], fallback: 87),
      oppPassAccuracy: _firstInt(m, const ['opponent_pass_accuracy', 'opp_pass_accuracy'], fallback: 76),
      duels: _firstInt(m, const ['duels_won_percent', 'duels_percent'], fallback: 56),
      xg: xg,
      oppXg: oppXg,
    );
  }
}

class _MetricCompareData {
  final String title;
  final String left;
  final String right;
  final double ratio;
  const _MetricCompareData(this.title, this.left, this.right, this.ratio);
}

class _SideStatData {
  final String title;
  final int left;
  final int right;
  const _SideStatData(this.title, this.left, this.right);
}

class _EventData {
  final String minute;
  final String score;
  final String title;
  const _EventData({required this.minute, required this.score, required this.title});
}

class _TopPlayerData {
  final String name;
  final int number;
  final String subtitle;
  final double rating;
  final String photoUrl;
  const _TopPlayerData({required this.name, required this.number, required this.subtitle, required this.rating, required this.photoUrl});
}

String _sStatic(dynamic v) => (v ?? '').toString().trim();
int _iStatic(dynamic v) => int.tryParse(_sStatic(v)) ?? (double.tryParse(_sStatic(v))?.round() ?? 0);
double _dStatic(dynamic v) => double.tryParse(_sStatic(v).replaceAll(',', '.')) ?? 0;

int _firstInt(Map<String, dynamic> m, List<String> keys, {required int fallback}) {
  for (final key in keys) {
    final v = _iStatic(m[key]);
    if (_sStatic(m[key]).isNotEmpty) return v;
  }
  return fallback;
}

double _firstDouble(Map<String, dynamic> m, List<String> keys, {required double fallback}) {
  for (final key in keys) {
    final raw = _sStatic(m[key]);
    if (raw.isNotEmpty) return _dStatic(raw);
  }
  return fallback;
}

int _matchIdOf(Map<String, dynamic> m) => _iStatic(m['match_id'] ?? m['id']);
int _matchId(Map<String, dynamic> m) => _matchIdOf(m);
String _s(dynamic v) => _sStatic(v);
int _i(dynamic v) => _iStatic(v);
int _ourScore(Map<String, dynamic> m) => _ourScoreStatic(m);
int _opponentScore(Map<String, dynamic> m) => _opponentScoreStatic(m);
bool _scoreIsEmpty(Map<String, dynamic> m) => _scoreTextStatic(m) == '–:–';
String _scoreText(Map<String, dynamic> m) => _scoreTextStatic(m);
String _opponentName(Map<String, dynamic> m) => _opponentNameStatic(m);

DateTime _parseDateStatic(String s) {
  try {
    final value = s.trim();
    if (value.contains('.')) {
      final p = value.split('.');
      if (p.length == 3) return DateTime(int.tryParse(p[2]) ?? 2000, int.tryParse(p[1]) ?? 1, int.tryParse(p[0]) ?? 1);
    }
    final d = DateTime.tryParse(value);
    if (d != null) return DateTime(d.year, d.month, d.day);
  } catch (_) {}
  return DateTime(2000, 1, 1);
}

DateTime _parseDate(String s) => _parseDateStatic(s);

String _formatDateStatic(DateTime d) {
  if (d.year < 2001) return 'Дата не указана';
  return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}

String _opponentNameStatic(Map<String, dynamic> m) {
  final v = _sStatic(m['opponent'] ?? m['opponent_name'] ?? m['away_team']);
  return v.isEmpty ? 'Соперник' : v;
}

int _ourScoreStatic(Map<String, dynamic> m) => _iStatic(m['our_score'] ?? m['home_score'] ?? m['team_score']);
int _opponentScoreStatic(Map<String, dynamic> m) => _iStatic(m['opponent_score'] ?? m['away_score'] ?? m['rival_score']);

String _scoreTextStatic(Map<String, dynamic> m) {
  final ourRaw = _sStatic(m['our_score'] ?? m['home_score'] ?? m['team_score']);
  final oppRaw = _sStatic(m['opponent_score'] ?? m['away_score'] ?? m['rival_score']);
  if (ourRaw.isEmpty && oppRaw.isEmpty) return '–:–';
  return '${_iStatic(ourRaw)}:${_iStatic(oppRaw)}';
}

String _resultLabelStatic(Map<String, dynamic> m) {
  if (_scoreTextStatic(m) == '–:–') return 'Не сыгран';
  final our = _ourScoreStatic(m);
  final opp = _opponentScoreStatic(m);
  if (our > opp) return 'Победа';
  if (our < opp) return 'Поражение';
  return 'Ничья';
}

Color _resultColorStatic(Map<String, dynamic> m) {
  final label = _resultLabelStatic(m);
  if (label == 'Победа') return CatapultColors.green;
  if (label == 'Поражение') return CatapultColors.red;
  if (label == 'Ничья') return CatapultColors.amber;
  return CatapultColors.muted;
}

String _matchTypeStatic(Map<String, dynamic> m) {
  final raw = _sStatic(m['event_type'] ?? m['competition_name'] ?? m['tournament']);
  final low = raw.toLowerCase();
  if (low.contains('friendly') || low.contains('товарищ')) return 'Товарищеский матч';
  if (low.contains('championship') || low.contains('чемпион')) return 'Чемпионат';
  if (raw.isNotEmpty) return raw;
  return 'Товарищеский матч';
}
