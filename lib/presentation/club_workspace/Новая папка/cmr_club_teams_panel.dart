// lib/presentation/club_workspace/cmr_club_teams_panel.dart
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../testing/cmr_testing_panel.dart';

class _CmrColors {
  static const Color bg = Color(0xFFFFFFFF);
  static const Color panel = Colors.white;
  static const Color soft = Color(0xFFFAFBFC);
  static const Color soft2 = Color(0xFFF6F7F9);
  static const Color text = Color(0xFF0B0F14);
  static const Color muted = Color(0xFF374151);
  static const Color subtle = Color(0xFF6B7280);
  static const Color divider = Color(0xFFF0F2F4);
  static const Color graphite = Color(0xFF111827);
  static const Color graphite2 = Color(0xFF1F2937);
  static const Color green = Color(0xFF00A750);
  static const Color greenSoft = Color(0xFFF3FBF7);
  static const Color greenSoft2 = Color(0xFFF8FEFA);
  static const Color greenDark = Color(0xFF067A46);
  static const Color orange = Color(0xFFEA580C);
  static const Color orangeSoft = Color(0xFFFFF7ED);
  static const Color red = Color(0xFFDC2626);
  static const Color redSoft = Color(0xFFFEF2F2);
  static const Color blue = Color(0xFF2563EB);
  static const Color blueSoft = Color(0xFFF4F7FF);
}

class _CmrText {
  static TextStyle title(double size) => TextStyle(
        color: _CmrColors.text,
        fontFamily: 'Roboto',
        fontSize: size,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.25,
        height: 1.08,
      );

  static TextStyle section() => const TextStyle(
        color: _CmrColors.text,
        fontFamily: 'Roboto',
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.15,
        height: 1.14,
      );

  static TextStyle value(double size) => TextStyle(
        color: _CmrColors.text,
        fontFamily: 'Roboto',
        fontSize: size,
        fontWeight: FontWeight.w500,
        fontFeatures: const [FontFeature.tabularFigures()],
        height: 1.18,
      );

  static TextStyle muted(double size) => TextStyle(
        color: _CmrColors.muted,
        fontFamily: 'Roboto',
        fontSize: size,
        fontWeight: FontWeight.w500,
        height: 1.32,
      );

  static TextStyle subtle(double size) => TextStyle(
        color: _CmrColors.subtle,
        fontFamily: 'Roboto',
        fontSize: size,
        fontWeight: FontWeight.w500,
        height: 1.28,
      );

  static TextStyle caption() => const TextStyle(
        color: _CmrColors.subtle,
        fontFamily: 'Roboto',
        fontSize: 10.5,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.12,
        height: 1.05,
      );

  static TextStyle action() => const TextStyle(
        color: _CmrColors.text,
        fontFamily: 'Roboto',
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 1.1,
      );
}

class _CmrDecor {
  static BoxDecoration panel({double radius = 22, bool elevated = true}) => BoxDecoration(
        color: _CmrColors.panel,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: elevated
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.045),
                  blurRadius: 34,
                  spreadRadius: -14,
                  offset: const Offset(0, 20),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.025),
                  blurRadius: 10,
                  spreadRadius: -7,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      );

  static BoxDecoration softCard({double radius = 18, bool active = false}) => BoxDecoration(
        color: active ? _CmrColors.panel : _CmrColors.soft,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: active
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.045),
                  blurRadius: 24,
                  spreadRadius: -12,
                  offset: const Offset(0, 14),
                ),
              ]
            : null,
      );
}


class CmrClubTeamsPanel extends StatefulWidget {
  final int clubId;
  final String clubName;
  final List<Map<String, dynamic>> teams;
  final int? selectedTeamId;
  final String selectedTeamName;
  final ValueChanged<Map<String, dynamic>> onOpenTeam;
  /// Выбор команды без перехода на другой раздел.
  /// Нужен, чтобы экран "Команды" оставался активным при клике по карточке.
  final ValueChanged<Map<String, dynamic>>? onSelectTeam;
  final VoidCallback onCreateTeam;
  final Future<void> Function()? onRefresh;
  final VoidCallback? onOpenRoster;
  final VoidCallback? onOpenTrainers;
  final VoidCallback? onOpenCalendar;
  final VoidCallback? onOpenPlans;
  final VoidCallback? onOpenTrainings;
  final VoidCallback? onOpenTesting;
  final VoidCallback? onOpenChats;
  final List<Map<String, dynamic>> events;
  final List<Map<String, dynamic>> latestPlans;
  final List<Map<String, dynamic>> news;
  final List<Map<String, dynamic>> latestTrainings;
  final List<Map<String, dynamic>> latestTests;
  final List<Map<String, dynamic>> players;

  const CmrClubTeamsPanel({
    super.key,
    required this.clubId,
    required this.clubName,
    required this.teams,
    required this.selectedTeamId,
    required this.selectedTeamName,
    required this.onOpenTeam,
    this.onSelectTeam,
    required this.onCreateTeam,
    this.onRefresh,
    this.onOpenRoster,
    this.onOpenTrainers,
    this.onOpenCalendar,
    this.onOpenPlans,
    this.onOpenTrainings,
    this.onOpenTesting,
    this.onOpenChats,
    this.events = const <Map<String, dynamic>>[],
    this.latestPlans = const <Map<String, dynamic>>[],
    this.news = const <Map<String, dynamic>>[],
    this.latestTrainings = const <Map<String, dynamic>>[],
    this.latestTests = const <Map<String, dynamic>>[],
    this.players = const <Map<String, dynamic>>[],
  });

  @override
  State<CmrClubTeamsPanel> createState() => _CmrClubTeamsPanelState();
}

enum _TeamsFilter { all, active, football, emptyLogo }

class _CmrClubTeamsPanelState extends State<CmrClubTeamsPanel> {
  static const String apiBase = 'https://sportotekaapp.ru/api';
  static const String getPlayersUrl = '$apiBase/get_players.php';
  static const String getTeamTrainersUrl = '$apiBase/get_team_trainers.php';

  final TextEditingController _searchC = TextEditingController();
  final ScrollController _listScroll = ScrollController();
  int _selectedIndex = 0;
  int? _localSelectedTeamId;
  _TeamsFilter _filter = _TeamsFilter.all;
  bool _countsLoading = false;
  final Map<int, int> _playersCountByTeam = {};
  final Map<int, int> _trainersCountByTeam = {};

  @override
  void initState() {
    super.initState();
    _searchC.addListener(() => setState(() {}));
    _syncSelectedIndex();
    _loadTeamCounts();
  }

  @override
  void didUpdateWidget(covariant CmrClubTeamsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedTeamId != widget.selectedTeamId ||
        oldWidget.teams.length != widget.teams.length) {
      _syncSelectedIndex();
    }

    final oldIds = oldWidget.teams.map(_teamId).where((id) => id > 0).join(',');
    final newIds = widget.teams.map(_teamId).where((id) => id > 0).join(',');
    if (oldWidget.clubId != widget.clubId || oldIds != newIds) {
      _loadTeamCounts();
    }
  }

  @override
  void dispose() {
    _searchC.dispose();
    _listScroll.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _visibleTeams {
    final q = _searchC.text.trim().toLowerCase();
    return widget.teams.where((team) {
      final haystack = [
        _teamName(team),
        _teamSubtitle(team),
        _s(team['sport']),
        _s(team['category']),
        _s(team['age_group']),
        _s(team['description']),
      ].join(' ').toLowerCase();
      final matchesSearch = q.isEmpty || haystack.contains(q);
      if (!matchesSearch) return false;

      switch (_filter) {
        case _TeamsFilter.all:
          return true;
        case _TeamsFilter.active:
          return _teamId(team) == widget.selectedTeamId;
        case _TeamsFilter.football:
          final raw = '${_teamSubtitle(team)} ${_s(team['sport'])} ${_s(team['category'])}'.toLowerCase();
          return raw.contains('фут') || raw.contains('football') || raw.contains('soccer');
        case _TeamsFilter.emptyLogo:
          return _teamLogo(team).isEmpty;
      }
    }).toList();
  }

  int? get _activeTeamId {
    final localId = _localSelectedTeamId;
    if (localId != null && localId > 0) return localId;
    final widgetId = widget.selectedTeamId;
    if (widgetId != null && widgetId > 0) return widgetId;
    return null;
  }

  Map<String, dynamic>? get _selectedTeam {
    final visible = _visibleTeams;
    if (visible.isEmpty) return null;

    final selectedId = _activeTeamId;
    if (selectedId != null && selectedId > 0) {
      for (final team in visible) {
        if (_teamId(team) == selectedId) return team;
      }
    }

    return visible[_selectedIndex.clamp(0, visible.length - 1)];
  }

  void _syncSelectedIndex() {
    final selectedId = widget.selectedTeamId;
    if (selectedId == null || selectedId <= 0) {
      _localSelectedTeamId = null;
      _selectedIndex = 0;
      return;
    }
    _localSelectedTeamId = selectedId;
    final index = widget.teams.indexWhere((team) => _teamId(team) == selectedId);
    if (index >= 0) _selectedIndex = index;
  }

  void _selectTeam(Map<String, dynamic> team) {
    final teamId = _teamId(team);
    final index = _visibleTeams.indexWhere((item) => _teamId(item) == teamId);
    setState(() {
      _localSelectedTeamId = teamId > 0 ? teamId : null;
      _selectedIndex = math.max(0, index);
    });

    // Важно: обычный клик по карточке команды выбирает её как рабочую.
    // Если родитель передал onSelectTeam — остаёмся в разделе "Команды".
    // Если callback не передан, используем onOpenTeam как безопасный fallback,
    // чтобы выбор команды не "терялся" в старых местах подключения панели.
    final selectCallback = widget.onSelectTeam;
    if (selectCallback != null) {
      selectCallback(team);
    } else {
      widget.onOpenTeam(team);
    }
  }

  void _openTeamOverview(Map<String, dynamic> team) {
    widget.onOpenTeam(team);
  }

  Future<void> _loadTeamCounts() async {
    final teamIds = widget.teams.map(_teamId).where((id) => id > 0).toSet().toList();
    if (teamIds.isEmpty) {
      if (!mounted) return;
      setState(() {
        _playersCountByTeam.clear();
        _trainersCountByTeam.clear();
        _countsLoading = false;
      });
      return;
    }

    if (!mounted) return;
    setState(() => _countsLoading = true);

    final players = <int, int>{};
    final trainers = <int, int>{};

    await Future.wait(teamIds.map((teamId) async {
      final loaded = await Future.wait<int>([
        _loadPlayersCount(teamId),
        _loadTrainersCount(teamId),
      ]);
      players[teamId] = loaded[0];
      trainers[teamId] = loaded[1];
    }));

    if (!mounted) return;
    setState(() {
      _playersCountByTeam
        ..clear()
        ..addAll(players);
      _trainersCountByTeam
        ..clear()
        ..addAll(trainers);
      _countsLoading = false;
    });
  }

  Future<int> _loadPlayersCount(int teamId) async {
    try {
      final resp = await http
          .post(
            Uri.parse(getPlayersUrl),
            headers: const {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode({'team_id': teamId}),
          )
          .timeout(const Duration(seconds: 12));

      final data = _tryDecode(resp.body);
      final list = _extractList(data, const ['players', 'data', 'items', 'members']);
      if (list.isNotEmpty) return list.length;

      final direct = _countFromMap(data, const [
        'players_count',
        'playersCount',
        'members_count',
        'membersCount',
        'count',
        'total',
      ]);
      if (direct > 0) return direct;
    } catch (_) {}

    try {
      final resp = await http
          .post(Uri.parse(getPlayersUrl), body: {'team_id': '$teamId'})
          .timeout(const Duration(seconds: 12));

      final data = _tryDecode(resp.body);
      final list = _extractList(data, const ['players', 'data', 'items', 'members']);
      if (list.isNotEmpty) return list.length;

      return _countFromMap(data, const [
        'players_count',
        'playersCount',
        'members_count',
        'membersCount',
        'count',
        'total',
      ]);
    } catch (_) {
      return 0;
    }
  }

  Future<int> _loadTrainersCount(int teamId) async {
    try {
      final data = await _postJson(getTeamTrainersUrl, {'team_id': teamId});
      final list = _extractList(data, const ['trainers', 'coaches', 'users', 'items', 'data']);
      if (list.isNotEmpty) return _uniquePeopleCount(list);
      final direct = _countFromMap(data, const [
        'trainers_count',
        'trainersCount',
        'coaches_count',
        'coachesCount',
        'count',
        'total',
      ]);
      if (direct > 0) return direct;
    } catch (_) {}

    try {
      final data = await _postForm(getTeamTrainersUrl, {'team_id': '$teamId'});
      final list = _extractList(data, const ['trainers', 'coaches', 'users', 'items', 'data']);
      if (list.isNotEmpty) return _uniquePeopleCount(list);
      return _countFromMap(data, const [
        'trainers_count',
        'trainersCount',
        'coaches_count',
        'coachesCount',
        'count',
        'total',
      ]);
    } catch (_) {
      return 0;
    }
  }

  Future<dynamic> _postJson(String url, Map<String, dynamic> body) async {
    final resp = await http
        .post(
          Uri.parse(url),
          headers: const {'Content-Type': 'application/json; charset=utf-8'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 12));
    return _tryDecode(resp.body);
  }

  Future<dynamic> _postForm(String url, Map<String, String> body) async {
    final resp = await http
        .post(Uri.parse(url), body: body)
        .timeout(const Duration(seconds: 12));
    return _tryDecode(resp.body);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final media = MediaQuery.sizeOf(context);
        final width = constraints.maxWidth.isFinite && constraints.maxWidth > 0
            ? constraints.maxWidth
            : media.width;
        final safeHeight = constraints.maxHeight.isFinite && constraints.maxHeight > 120
            ? constraints.maxHeight
            : math.max(
                620.0,
                media.height - MediaQuery.paddingOf(context).vertical - 24,
              );

        if (widget.teams.isEmpty) {
          return SizedBox(
            width: double.infinity,
            height: safeHeight,
            child: Container(
              color: _CmrColors.bg,
              padding: const EdgeInsets.all(10),
              child: _EmptyTeams(onCreateTeam: widget.onCreateTeam),
            ),
          );
        }

        final visibleTeams = _visibleTeams;
        final mobile = width < 640;
        final compact = width < 880;
        final selected = _selectedTeam;
        final displaySelectedTeamName = selected == null ? widget.selectedTeamName : _teamName(selected);
        final listWidth = mobile ? width : math.min(480.0, math.max(320.0, width * .42));

        Widget detailsForSelected() {
          if (selected == null) {
            return _NoFilteredTeams(
              onReset: () => setState(() {
                _filter = _TeamsFilter.all;
                _searchC.clear();
              }),
            );
          }

          return _TeamDetails(
            team: selected,
            active: _teamId(selected) == _activeTeamId,
            clubName: widget.clubName,
            clubId: widget.clubId,
            playersCount: _playersCountByTeam[_teamId(selected)],
            trainersCount: _trainersCountByTeam[_teamId(selected)],
            countsLoading: _countsLoading,
            onOpenTeam: () => _openTeamOverview(selected),
            onOpenRoster: widget.onOpenRoster,
            onOpenTrainers: widget.onOpenTrainers,
            onOpenCalendar: widget.onOpenCalendar,
            onOpenPlans: widget.onOpenPlans,
            onOpenTrainings: widget.onOpenTrainings,
            onOpenTesting: widget.onOpenTesting,
            onOpenChats: widget.onOpenChats,
            events: widget.events,
            latestPlans: widget.latestPlans,
            news: widget.news,
            latestTrainings: widget.latestTrainings,
            latestTests: widget.latestTests,
            players: widget.players,
          );
        }

        final list = _TeamsList(
          clubName: widget.clubName,
          teamsCount: widget.teams.length,
          visibleCount: visibleTeams.length,
          selectedTeamName: displaySelectedTeamName,
          searchC: _searchC,
          scroll: _listScroll,
          teams: visibleTeams,
          selectedTeamId: _activeTeamId,
          filter: _filter,
          onFilterChanged: (value) => setState(() => _filter = value),
          onSelect: _selectTeam,
          onCreateTeam: widget.onCreateTeam,
          onRefresh: widget.onRefresh,
          compact: compact,
          mobile: mobile,
        );

        final details = detailsForSelected();

        if (mobile) {
          final listHeight = math.min(360.0, math.max(230.0, safeHeight * .42));
          return SizedBox(
            width: double.infinity,
            height: safeHeight,
            child: Container(
              color: _CmrColors.bg,
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  SizedBox(height: listHeight, child: list),
                  const SizedBox(height: 10),
                  Expanded(child: details),
                ],
              ),
            ),
          );
        }

        return SizedBox(
          width: double.infinity,
          height: safeHeight,
          child: Container(
            color: _CmrColors.bg,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: listWidth, child: list),
                const SizedBox(width: 10),
                Expanded(child: details),
              ],
            ),
          ),
        );
      },
    );
  }


}


class _MobileTeamsHeader extends StatelessWidget {
  final String clubName;
  final int teamsCount;
  final String selectedTeamName;
  final VoidCallback onCreateTeam;
  final Future<void> Function()? onRefresh;

  const _MobileTeamsHeader({
    required this.clubName,
    required this.teamsCount,
    required this.selectedTeamName,
    required this.onCreateTeam,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final active = selectedTeamName.trim().isEmpty ? 'не выбрана' : selectedTeamName.trim();

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
      decoration: _CmrDecor.panel(radius: 18),
      child: Row(
        children: [
          const _IconBadge(icon: Icons.account_tree_rounded, size: 38, iconSize: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Команды', style: _CmrText.title(15.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(width: 8),
                    _TinyStatus(text: '$teamsCount'),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '$clubName • активная: $active',
                  style: _CmrText.subtle(11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          if (onRefresh != null) ...[
            _MobileIconAction(icon: Icons.refresh_rounded, onTap: () { onRefresh?.call(); }),
            const SizedBox(width: 6),
          ],
          _MobileIconAction(icon: Icons.add_rounded, onTap: onCreateTeam, filled: true),
        ],
      ),
    );
  }
}

class _TinyStatus extends StatelessWidget {
  final String text;
  const _TinyStatus({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _CmrColors.panel,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _CmrColors.divider.withOpacity(0.0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: _CmrColors.green,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: _CmrColors.text,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileIconAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  const _MobileIconAction({
    required this.icon,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? _CmrColors.graphite : _CmrColors.panel,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: filled ? _CmrColors.graphite : _CmrColors.divider),
          ),
          child: Icon(
            icon,
            color: filled ? _CmrColors.green : _CmrColors.text,
            size: 18,
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String clubName;
  final int teamsCount;
  final String selectedTeamName;
  final VoidCallback onCreateTeam;
  final Future<void> Function()? onRefresh;
  final bool compact;

  const _Header({
    required this.clubName,
    required this.teamsCount,
    required this.selectedTeamName,
    required this.onCreateTeam,
    required this.onRefresh,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: _CmrDecor.panel(),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _titleBlock(),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _Metric(label: 'Команды', value: '$teamsCount')),
                    const SizedBox(width: 8),
                    Expanded(child: _Metric(label: 'Активная', value: selectedTeamName, compact: true)),
                  ],
                ),
                const SizedBox(height: 10),
                _ActionButton(icon: Icons.add_rounded, text: 'Добавить команду', onTap: onCreateTeam),
              ],
            )
          : Row(
              children: [
                Expanded(child: _titleBlock()),
                const SizedBox(width: 12),
                _Metric(label: 'Команды', value: '$teamsCount'),
                const SizedBox(width: 10),
                SizedBox(width: 210, child: _Metric(label: 'Активная', value: selectedTeamName, compact: true)),
                const SizedBox(width: 12),
                if (onRefresh != null)
                  _IconAction(icon: Icons.refresh_rounded, onTap: () { onRefresh?.call(); }),
                const SizedBox(width: 8),
                _ActionButton(icon: Icons.add_rounded, text: 'Добавить команду', onTap: onCreateTeam),
              ],
            ),
    );
  }

  Widget _titleBlock() {
    return Row(
      children: [
        const _IconBadge(icon: Icons.account_tree_rounded, size: 44, iconSize: 21),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Команды клуба', style: _CmrText.title(compact ? 16.5 : 18), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              Text(clubName, style: _CmrText.subtle(11), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }
}

class _TeamsList extends StatelessWidget {
  final String clubName;
  final int teamsCount;
  final int visibleCount;
  final String selectedTeamName;
  final TextEditingController searchC;
  final ScrollController? scroll;
  final List<Map<String, dynamic>> teams;
  final int? selectedTeamId;
  final _TeamsFilter filter;
  final ValueChanged<_TeamsFilter> onFilterChanged;
  final ValueChanged<Map<String, dynamic>> onSelect;
  final VoidCallback onCreateTeam;
  final Future<void> Function()? onRefresh;
  final bool compact;
  final bool mobile;

  const _TeamsList({
    required this.clubName,
    required this.teamsCount,
    required this.visibleCount,
    required this.selectedTeamName,
    required this.searchC,
    required this.scroll,
    required this.teams,
    required this.selectedTeamId,
    required this.filter,
    required this.onFilterChanged,
    required this.onSelect,
    required this.onCreateTeam,
    required this.onRefresh,
    required this.compact,
    required this.mobile,
  });

  @override
  Widget build(BuildContext context) {
    final outerPadding = mobile ? 8.0 : (compact ? 10.0 : 12.0);
    final gap = mobile ? 8.0 : 10.0;

    return Container(
      width: double.infinity,
      decoration: _CmrDecor.panel(),
      padding: EdgeInsets.all(outerPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TeamsListHeader(
            clubName: clubName,
            teamsCount: teamsCount,
            visibleCount: visibleCount,
            selectedTeamName: selectedTeamName,
            onCreateTeam: onCreateTeam,
            onRefresh: onRefresh,
            compact: compact,
            mobile: mobile,
          ),
          SizedBox(height: gap),
          _SearchField(controller: searchC, mobile: mobile),
          const SizedBox(height: 10),
          _TeamsFilterBar(value: filter, onChanged: onFilterChanged, mobile: mobile),
          SizedBox(height: gap),
          Expanded(
            child: teams.isEmpty
                ? const _MiniEmpty(text: 'Команды не найдены')
                : RefreshIndicator(
                    color: _CmrColors.green,
                    onRefresh: onRefresh ?? () async {},
                    child: ListView.separated(
                      controller: scroll,
                      padding: EdgeInsets.only(bottom: mobile ? 20 : 8),
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: teams.length,
                      separatorBuilder: (_, __) => SizedBox(height: mobile ? 6 : 7),
                      itemBuilder: (_, index) {
                        final team = teams[index];
                        return _TeamTile(
                          team: team,
                          active: _teamId(team) == selectedTeamId,
                          onTap: () => onSelect(team),
                          mobile: mobile,
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _TeamsListHeader extends StatelessWidget {
  final String clubName;
  final int teamsCount;
  final int visibleCount;
  final String selectedTeamName;
  final VoidCallback onCreateTeam;
  final Future<void> Function()? onRefresh;
  final bool compact;
  final bool mobile;

  const _TeamsListHeader({
    required this.clubName,
    required this.teamsCount,
    required this.visibleCount,
    required this.selectedTeamName,
    required this.onCreateTeam,
    required this.onRefresh,
    required this.compact,
    required this.mobile,
  });

  @override
  Widget build(BuildContext context) {
    final iconSize = mobile ? 38.0 : 42.0;
    final titleSize = mobile ? 15.5 : 16.5;
    final active = selectedTeamName.trim().isEmpty ? 'не выбрана' : selectedTeamName.trim();
    final subtitle = '$clubName · $teamsCount команд${visibleCount == teamsCount ? '' : ' · найдено $visibleCount'}';

    return Row(
      children: [
        _IconBadge(
          icon: Icons.account_tree_rounded,
          size: iconSize,
          iconSize: mobile ? 21 : 23,
        ),
        SizedBox(width: mobile ? 8 : 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Команды клуба',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _CmrText.title(titleSize),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: mobile ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                style: _CmrText.subtle(mobile ? 11 : 11.5),
              ),
              if (!mobile) ...[
                const SizedBox(height: 4),
                Text(
                  'Активная: $active',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _CmrText.subtle(11),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (onRefresh != null && !mobile) ...[
          _IconAction(icon: Icons.refresh_rounded, onTap: () { onRefresh?.call(); }),
          const SizedBox(width: 8),
        ],
        _TeamsIconButton(
          icon: Icons.add_rounded,
          tooltip: 'Добавить команду',
          onTap: onCreateTeam,
          emphasized: true,
          compact: mobile,
        ),
      ],
    );
  }
}

class _TeamsFilterBar extends StatelessWidget {
  final _TeamsFilter value;
  final ValueChanged<_TeamsFilter> onChanged;
  final bool mobile;

  const _TeamsFilterBar({
    required this.value,
    required this.onChanged,
    required this.mobile,
  });

  @override
  Widget build(BuildContext context) {
    final items = <_TeamsFilter, String>{
      _TeamsFilter.all: 'Все',
      _TeamsFilter.active: 'Активная',
      _TeamsFilter.football: 'Футбол',
      _TeamsFilter.emptyLogo: 'Без логотипа',
    };

    return SizedBox(
      height: mobile ? 32 : 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => SizedBox(width: mobile ? 6 : 8),
        itemBuilder: (_, index) {
          final filterItem = items.keys.elementAt(index);
          return _FilterChip(
            label: items[filterItem] ?? '',
            selected: filterItem == value,
            onTap: () => onChanged(filterItem),
            dense: mobile,
          );
        },
      ),
    );
  }
}

class _TeamsIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool emphasized;
  final bool compact;

  const _TeamsIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.emphasized = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(compact ? 12 : 13);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: emphasized ? _CmrColors.graphite : _CmrColors.panel,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            width: compact ? 36 : 38,
            height: compact ? 36 : 38,
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: emphasized ? _CmrColors.graphite : _CmrColors.divider),
            ),
            child: Icon(
              icon,
              color: emphasized ? _CmrColors.green : _CmrColors.text,
              size: compact ? 18 : 18,
            ),
          ),
        ),
      ),
    );
  }
}


class _TeamTile extends StatelessWidget {
  final Map<String, dynamic> team;
  final bool active;
  final VoidCallback onTap;
  final bool mobile;

  const _TeamTile({
    required this.team,
    required this.active,
    required this.onTap,
    required this.mobile,
  });

  @override
  Widget build(BuildContext context) {
    final name = _teamName(team);
    final subtitle = _teamSubtitle(team).isEmpty ? 'Команда клуба' : _teamSubtitle(team);
    final logo = _teamLogo(team);
    final sport = _s(team['sport']).isEmpty ? 'Футбол' : _s(team['sport']);
    final players = _teamPlayersCount(team);
    final trainers = _teamTrainersCount(team);
    final meta = [sport, subtitle].where((e) => e.trim().isNotEmpty).join('  •  ');

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          padding: EdgeInsets.symmetric(horizontal: mobile ? 9 : 10, vertical: mobile ? 8 : 9),
          decoration: BoxDecoration(
            color: _CmrColors.panel,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: active ? _CmrColors.graphite.withOpacity(.16) : _CmrColors.divider.withOpacity(0.0)),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(.035),
                      blurRadius: 12,
                      offset: const Offset(0, 7),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 170),
                width: 3,
                height: mobile ? 42 : 46,
                decoration: BoxDecoration(
                  color: active ? _CmrColors.green : Colors.transparent,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              SizedBox(width: active ? 8 : 6),
              _TeamLogo(url: logo, name: name, size: mobile ? 40 : 44, active: active),
              SizedBox(width: mobile ? 9 : 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _CmrText.title(mobile ? 13.4 : 14.2),
                          ),
                        ),
                        if (active) ...[
                          const SizedBox(width: 6),
                          const _ActiveDot(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      meta.isEmpty ? 'Данные команды не заполнены' : meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _CmrText.muted(mobile ? 10.8 : 11.2),
                    ),
                  ],
                ),
              ),
              if (!mobile) ...[
                const SizedBox(width: 8),
                _TeamInlineMetric(label: 'Игроки', value: players == 0 ? '—' : '$players'),
                const SizedBox(width: 6),
                _TeamInlineMetric(label: 'Тренеры', value: trainers == 0 ? '—' : '$trainers'),
                const SizedBox(width: 8),
                _ChevronBadge(active: active),
              ] else ...[
                const SizedBox(width: 8),
                _TeamCountStack(players: players, trainers: trainers, compact: true),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveDot extends StatelessWidget {
  const _ActiveDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: const BoxDecoration(color: _CmrColors.green, shape: BoxShape.circle),
    );
  }
}

class _TeamInlineMetric extends StatelessWidget {
  final String label;
  final String value;

  const _TeamInlineMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 54),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: _CmrColors.soft,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: _CmrColors.divider.withOpacity(0.0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrText.caption().copyWith(fontSize: 9.3)),
          const SizedBox(height: 2),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrText.value(12.3)),
        ],
      ),
    );
  }
}



class _ChevronBadge extends StatelessWidget {
  final bool active;

  const _ChevronBadge({required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: active ? _CmrColors.graphite : _CmrColors.soft,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: active ? _CmrColors.graphite : _CmrColors.divider),
      ),
      child: Icon(
        Icons.chevron_right_rounded,
        size: 18,
        color: active ? Colors.white : _CmrColors.subtle,
      ),
    );
  }
}



class _TeamTileText extends StatelessWidget {
  final String name;
  final String subtitle;
  final String sport;
  final bool active;
  final bool mobile;

  const _TeamTileText({
    required this.name,
    required this.subtitle,
    required this.sport,
    required this.active,
    this.mobile = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (active) ...[
              Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(color: _CmrColors.green, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                name,
                maxLines: mobile ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: _CmrText.value(mobile ? 12.5 : 13.5),
              ),
            ),
          ],
        ),
        SizedBox(height: mobile ? 3 : 5),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _CmrText.subtle(mobile ? 10.5 : 11),
        ),
        if (!mobile) ...[
          const SizedBox(height: 7),
          Text(
            sport.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _CmrText.caption().copyWith(color: _CmrColors.text, letterSpacing: .4),
          ),
        ],
      ],
    );
  }
}

class _TeamStateChip extends StatelessWidget {
  final bool active;
  const _TeamStateChip({required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: _CmrColors.panel,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: active ? _CmrColors.graphite.withOpacity(.16) : _CmrColors.divider.withOpacity(0.0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: active ? _CmrColors.green : _CmrColors.subtle,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(active ? 'Выбрана' : 'Команда', style: _CmrText.action().copyWith(fontSize: 10.5)),
        ],
      ),
    );
  }
}

class _TeamMiniStat extends StatelessWidget {
  final String label;
  final String value;
  const _TeamMiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: _CmrColors.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _CmrColors.divider.withOpacity(0.0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: _CmrText.caption(), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 3),
          Text(value, style: _CmrText.value(13), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _TeamCountStack extends StatelessWidget {
  final int players;
  final int trainers;
  final bool compact;
  const _TeamCountStack({required this.players, required this.trainers, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: _CmrColors.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _CmrColors.divider.withOpacity(0.0)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(players == 0 ? '—' : '$players', style: _CmrText.value(13)),
          Text('игр.', style: _CmrText.caption()),
        ],
      ),
    );
  }
}



class _TeamDetails extends StatelessWidget {
  final Map<String, dynamic> team;
  final bool active;
  final String clubName;
  final int clubId;
  final int? playersCount;
  final int? trainersCount;
  final bool countsLoading;
  final VoidCallback onOpenTeam;
  final VoidCallback? onOpenRoster;
  final VoidCallback? onOpenTrainers;
  final VoidCallback? onOpenCalendar;
  final VoidCallback? onOpenPlans;
  final VoidCallback? onOpenTrainings;
  final VoidCallback? onOpenTesting;
  final VoidCallback? onOpenChats;
  final List<Map<String, dynamic>> events;
  final List<Map<String, dynamic>> latestPlans;
  final List<Map<String, dynamic>> news;
  final List<Map<String, dynamic>> latestTrainings;
  final List<Map<String, dynamic>> latestTests;
  final List<Map<String, dynamic>> players;

  const _TeamDetails({
    required this.team,
    required this.active,
    required this.clubName,
    required this.clubId,
    required this.playersCount,
    required this.trainersCount,
    required this.countsLoading,
    required this.onOpenTeam,
    required this.onOpenRoster,
    required this.onOpenTrainers,
    required this.onOpenCalendar,
    required this.onOpenPlans,
    required this.onOpenTrainings,
    required this.onOpenTesting,
    required this.onOpenChats,
    required this.events,
    required this.latestPlans,
    required this.news,
    required this.latestTrainings,
    required this.latestTests,
    required this.players,
  });

  @override
  Widget build(BuildContext context) {
    final name = _teamName(team);
    final subtitle = _teamSubtitle(team);
    final logo = _teamLogo(team);
    final sport = _teamSport(team);
    final description = _teamLongDescription(team);
    final resolvedPlayersCount = playersCount ?? _teamPlayersCount(team);
    final resolvedTrainersCount = trainersCount ?? _teamTrainersCount(team);
    final loadingPlayers = countsLoading && playersCount == null && _teamPlayersCount(team) == 0;
    final loadingTrainers = countsLoading && trainersCount == null && _teamTrainersCount(team) == 0;

    final safeEvents = events.take(3).toList();
    final safeTrainings = latestTrainings.take(3).toList();
    final safePlans = latestPlans.take(3).toList();
    final safeNews = news.take(3).toList();
    final safePlayers = players.take(8).toList();
    final testsCount = latestTests.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 640;
        final radius = compact ? 18.0 : 20.0;
        final contentPadding = compact ? 10.0 : 12.0;

        return Container(
          width: double.infinity,
          decoration: _CmrDecor.panel(radius: radius),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: EdgeInsets.all(contentPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _safeHero(
                    name: name,
                    clubName: clubName,
                    subtitle: subtitle,
                    sport: sport,
                    logo: logo,
                    active: active,
                    compact: compact,
                  ),
                  const SizedBox(height: 12),
                  _safeKpiGrid(
                    context,
                    compact: compact,
                    items: [
                      _TeamKpiData(
                        icon: Icons.groups_2_rounded,
                        value: loadingPlayers ? '...' : '$resolvedPlayersCount',
                        label: 'Игроки',
                        hint: resolvedPlayersCount > 0 ? 'состав команды' : 'состав пустой',
                      ),
                      _TeamKpiData(
                        icon: Icons.badge_rounded,
                        value: loadingTrainers ? '...' : '$resolvedTrainersCount',
                        label: 'Тренеры',
                        hint: resolvedTrainersCount > 0 ? 'назначены' : 'не назначены',
                      ),
                      _TeamKpiData(
                        icon: Icons.event_available_rounded,
                        value: '${safeEvents.length}',
                        label: 'Календарь',
                        hint: 'ближайшие события',
                      ),
                      _TeamKpiData(
                        icon: Icons.warning_amber_rounded,
                        value: '$testsCount',
                        label: 'Тестирование',
                        hint: testsCount > 0 ? 'есть данные' : 'нет данных',
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _safeActions(compact: compact),
                  const SizedBox(height: 12),
                  _safeNotice(
                    title: 'Сводка выбранной команды',
                    text: 'Здесь показывается обзор команды: состав, календарь, тренировки, планы, новости и контроль проблем по тестированию.',
                  ),
                  const SizedBox(height: 12),
                  _TeamRecentTestingBlock(
                    clubId: clubId,
                    teamId: _teamId(team),
                    clubName: clubName,
                    teamName: name,
                    players: players,
                    latestTests: latestTests,
                    fallbackTestsCount: testsCount,
                    fallbackPlayersCount: resolvedPlayersCount,
                    onOpenTesting: onOpenTesting,
                  ),
                  const SizedBox(height: 12),
                  _safeFeedSection(
                    icon: Icons.calendar_month_rounded,
                    title: 'Календарь и события',
                    emptyTitle: 'Событий пока нет',
                    items: safeEvents,
                    onTap: onOpenCalendar,
                  ),
                  const SizedBox(height: 10),
                  _safeFeedSection(
                    icon: Icons.fitness_center_rounded,
                    title: 'Тренировки',
                    emptyTitle: 'Тренировок пока нет',
                    items: safeTrainings,
                    onTap: onOpenTrainings ?? onOpenCalendar,
                  ),
                  const SizedBox(height: 10),
                  _safeFeedSection(
                    icon: Icons.assignment_turned_in_rounded,
                    title: 'Планы и задания',
                    emptyTitle: 'Планов пока нет',
                    items: safePlans,
                    onTap: onOpenPlans,
                  ),
                  const SizedBox(height: 10),
                  _safeFeedSection(
                    icon: Icons.campaign_rounded,
                    title: 'Лента и новости',
                    emptyTitle: 'Лента пока пустая',
                    items: safeNews,
                    onTap: onOpenChats,
                  ),
                  const SizedBox(height: 12),
                  _safePlayersBlock(players: safePlayers, fallbackCount: resolvedPlayersCount),
                  const SizedBox(height: 12),
                  _safePassport(
                    name: name,
                    clubName: clubName,
                    sport: sport,
                    subtitle: subtitle,
                    description: description,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _safeHero({
    required String name,
    required String clubName,
    required String subtitle,
    required String sport,
    required String logo,
    required bool active,
    required bool compact,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: BoxDecoration(
        color: _CmrColors.soft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _CmrColors.divider.withOpacity(0.0)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _TeamLogo(url: logo, name: name, size: compact ? 54 : 62, active: active),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: compact ? 360 : 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(active ? 'АКТИВНАЯ КОМАНДА' : 'КОМАНДА КЛУБА', style: _CmrText.caption().copyWith(color: _CmrColors.graphite2)),
                const SizedBox(height: 6),
                Text(name, maxLines: compact ? 2 : 1, overflow: TextOverflow.ellipsis, style: _CmrText.title(compact ? 20 : 24)),
                const SizedBox(height: 6),
                Text('$clubName · ${sport.trim().isEmpty ? 'Вид спорта не указан' : sport} · ${subtitle.trim().isEmpty ? 'Группа не указана' : subtitle}',
                    maxLines: 2, overflow: TextOverflow.ellipsis, style: _CmrText.muted(11.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _safeKpiGrid(BuildContext context, {required bool compact, required List<_TeamKpiData> items}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite ? constraints.maxWidth : 520.0;
        final gap = compact ? 8.0 : 10.0;
        final columns = width >= 760 ? 4 : (width >= 430 ? 2 : 1);
        final itemWidth = math.max(140.0, (width - gap * (columns - 1)) / columns);
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: items.map((item) {
            return SizedBox(
              width: itemWidth,
              child: Container(
                padding: EdgeInsets.all(compact ? 10 : 12),
                decoration: BoxDecoration(
                  color: _CmrColors.panel,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _CmrColors.divider.withOpacity(0.0)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(item.icon, color: _CmrColors.graphite2, size: 18),
                    const SizedBox(height: 9),
                    Text(item.value.trim().isEmpty ? '—' : item.value, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrText.value(compact ? 16 : 18)),
                    const SizedBox(height: 2),
                    Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrText.caption()),
                    const SizedBox(height: 3),
                    Text(item.hint, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrText.subtle(10.5)),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _safeActions({required bool compact}) {
    final actions = <_SafeActionData>[
      _SafeActionData(Icons.open_in_new_rounded, 'Открыть обзор', onOpenTeam),
      _SafeActionData(Icons.groups_2_rounded, 'Состав', onOpenRoster),
      _SafeActionData(Icons.badge_rounded, 'Тренеры', onOpenTrainers),
      _SafeActionData(Icons.calendar_month_rounded, 'Календарь', onOpenCalendar),
      _SafeActionData(Icons.assignment_rounded, 'Планы', onOpenPlans),
      _SafeActionData(Icons.fitness_center_rounded, 'Тренировки', onOpenTrainings),
      _SafeActionData(Icons.fact_check_rounded, 'Тестирование', onOpenTesting),
      _SafeActionData(Icons.chat_bubble_outline_rounded, 'Чат', onOpenChats),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: actions.map((action) {
        return InkWell(
          onTap: action.onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: compact ? 10 : 12, vertical: 10),
            decoration: BoxDecoration(
              color: action.onTap == null ? _CmrColors.soft : _CmrColors.panel,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _CmrColors.divider.withOpacity(0.0)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(action.icon, color: action.onTap == null ? _CmrColors.subtle : _CmrColors.graphite2, size: 16),
                const SizedBox(width: 7),
                Text(action.title, style: _CmrText.action()),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _safeNotice({required String title, required String text}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _CmrColors.greenSoft2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _CmrColors.green.withOpacity(.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: _CmrText.section()),
          const SizedBox(height: 5),
          Text(text, style: _CmrText.muted(11.5)),
        ],
      ),
    );
  }

  Widget _safeTestingBlock({required int testsCount, required int playersCount}) {
    final hasTests = testsCount > 0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hasTests ? _CmrColors.orangeSoft : _CmrColors.greenSoft2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: hasTests ? _CmrColors.orange.withOpacity(.22) : _CmrColors.green.withOpacity(.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Заметки по тестированию', style: _CmrText.section()),
          const SizedBox(height: 5),
          Text(
            hasTests
                ? 'Есть данные по тестированию. Откройте раздел, чтобы проверить игроков со слабыми показателями и добавить тренерские заметки.'
                : (playersCount > 0 ? 'Данные тестирования пока не загружены.' : 'Сначала добавьте игроков в состав команды.'),
            style: _CmrText.muted(11.5),
          ),
          if (onOpenTesting != null) ...[
            const SizedBox(height: 10),
            _safeSmallButton('Открыть тестирование', onOpenTesting),
          ],
        ],
      ),
    );
  }

  Widget _safeFeedSection({
    required IconData icon,
    required String title,
    required String emptyTitle,
    required List<Map<String, dynamic>> items,
    required VoidCallback? onTap,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _CmrColors.soft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _CmrColors.divider.withOpacity(0.0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(icon, color: _CmrColors.graphite2, size: 17),
              Text(title, style: _CmrText.section()),
              if (onTap != null) _safeTextButton('Открыть', onTap),
            ],
          ),
          const SizedBox(height: 9),
          if (items.isEmpty)
            Text(emptyTitle, style: _CmrText.subtle(11.2))
          else
            ...items.map((item) => _safeFeedTile(item, onTap)),
        ],
      ),
    );
  }

  Widget _safeFeedTile(Map<String, dynamic> item, VoidCallback? onTap) {
    final title = _itemTitle(item);
    final meta = _teamDateText(item);
    final subtitle = _s(item['description'] ?? item['body'] ?? item['text'] ?? item['comment'] ?? item['place'] ?? item['location']);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        margin: const EdgeInsets.only(bottom: 7),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: _CmrColors.divider.withOpacity(0.0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _CmrText.value(11.8)),
            const SizedBox(height: 3),
            Text(subtitle.isEmpty ? meta : '$meta · $subtitle', maxLines: 2, overflow: TextOverflow.ellipsis, style: _CmrText.subtle(10)),
          ],
        ),
      ),
    );
  }

  Widget _safePlayersBlock({required List<Map<String, dynamic>> players, required int fallbackCount}) {
    final count = players.isNotEmpty ? players.length : fallbackCount;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _CmrColors.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _CmrColors.divider.withOpacity(0.0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Игроки команды', style: _CmrText.section()),
          const SizedBox(height: 4),
          Text(count == 0 ? 'Состав пока не заполнен' : '$count игроков в рабочей группе', style: _CmrText.muted(11.5)),
          if (players.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: players.map((player) => _TeamSmallAvatar(url: _playerPhoto(player), name: _playerName(player), size: 38)).toList(),
            ),
          ],
          if (onOpenRoster != null) ...[
            const SizedBox(height: 10),
            _safeSmallButton('Открыть состав', onOpenRoster),
          ],
        ],
      ),
    );
  }

  Widget _safePassport({
    required String name,
    required String clubName,
    required String sport,
    required String subtitle,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _CmrColors.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _CmrColors.divider.withOpacity(0.0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Паспорт команды', style: _CmrText.section()),
          const SizedBox(height: 8),
          Text('Команда: $name', style: _CmrText.muted(11.5)),
          Text('Клуб: $clubName', style: _CmrText.muted(11.5)),
          Text('Вид спорта: ${sport.trim().isEmpty ? 'не указан' : sport}', style: _CmrText.muted(11.5)),
          Text('Группа: ${subtitle.trim().isEmpty ? 'не указана' : subtitle}', style: _CmrText.muted(11.5)),
          const SizedBox(height: 8),
          Text(description.isEmpty ? 'Описание пока не заполнено.' : description, style: _CmrText.muted(11.5)),
          const SizedBox(height: 10),
          _safeSmallButton('Редактировать', onOpenTeam),
        ],
      ),
    );
  }

  Widget _safeSmallButton(String text, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: _CmrColors.soft,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _CmrColors.divider.withOpacity(0.0)),
        ),
        child: Text(text, style: _CmrText.action().copyWith(fontSize: 10.5)),
      ),
    );
  }

  Widget _safeTextButton(String text, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        child: Text(text, style: _CmrText.action().copyWith(fontSize: 10.5)),
      ),
    );
  }
}

class _SafeActionData {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;

  const _SafeActionData(this.icon, this.title, this.onTap);
}

class _TeamPremiumHero extends StatelessWidget {
  final String name;
  final String clubName;
  final String subtitle;
  final String sport;
  final String logo;
  final bool active;
  final bool compact;
  final VoidCallback onOpenTeam;

  const _TeamPremiumHero({
    required this.name,
    required this.clubName,
    required this.subtitle,
    required this.sport,
    required this.logo,
    required this.active,
    required this.compact,
    required this.onOpenTeam,
  });

  @override
  Widget build(BuildContext context) {
    final safeSubtitle = subtitle.trim().isEmpty ? 'Группа не указана' : subtitle.trim();

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: _CmrColors.panel,
        border: Border(bottom: BorderSide(color: _CmrColors.divider)),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -36,
            top: -46,
            child: Container(
              width: compact ? 120 : 160,
              height: compact ? 120 : 160,
              decoration: BoxDecoration(
                color: _CmrColors.greenSoft,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Positioned(
            right: compact ? 40 : 72,
            bottom: -58,
            child: Container(
              width: compact ? 100 : 138,
              height: compact ? 100 : 138,
              decoration: BoxDecoration(
                color: _CmrColors.soft,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(compact ? 12 : 14, compact ? 12 : 14, compact ? 12 : 14, compact ? 12 : 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    _TeamLogo(url: logo, name: name, size: compact ? 56 : 66, active: active),
                    Positioned(
                      right: -3,
                      bottom: -3,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: _CmrColors.panel,
                          shape: BoxShape.circle,
                          border: Border.all(color: _CmrColors.panel, width: 3),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: active ? _CmrColors.green : _CmrColors.subtle,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(width: compact ? 11 : 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 20,
                            decoration: BoxDecoration(
                              color: _CmrColors.green,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              active ? 'АКТИВНАЯ КОМАНДА' : 'КОМАНДА КЛУБА',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _CmrText.caption().copyWith(
                                color: _CmrColors.text,
                                fontSize: 10.8,
                                letterSpacing: .75,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        name,
                        maxLines: compact ? 2 : 1,
                        overflow: TextOverflow.ellipsis,
                        style: _CmrText.title(compact ? 20 : 24),
                      ),
                      const SizedBox(height: 9),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          _TeamLightPill(icon: Icons.verified_rounded, text: active ? 'Выбрана' : 'Предпросмотр', active: active),
                          _TeamLightPill(icon: Icons.apartment_rounded, text: clubName),
                          _TeamLightPill(icon: Icons.sports_soccer_rounded, text: sport),
                          _TeamLightPill(icon: Icons.category_rounded, text: safeSubtitle),
                        ],
                      ),
                    ],
                  ),
                ),
                if (!compact) ...[
                  const SizedBox(width: 12),
                  _TeamHeroButton(onTap: onOpenTeam),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamHeroButton extends StatelessWidget {
  final VoidCallback onTap;
  const _TeamHeroButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _CmrColors.graphite,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _CmrColors.graphite),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.open_in_new_rounded, color: _CmrColors.green, size: 17),
              SizedBox(width: 8),
              Text(
                'Открыть обзор',
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeamLightPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool active;

  const _TeamLightPill({required this.icon, required this.text, this.active = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: active ? _CmrColors.greenSoft2 : _CmrColors.panel,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: active ? _CmrColors.graphite.withOpacity(.16) : _CmrColors.divider.withOpacity(0.0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: active ? _CmrColors.green : _CmrColors.subtle,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Icon(icon, color: active ? _CmrColors.graphite2 : _CmrColors.text, size: 12),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: Text(
              text.trim().isEmpty ? 'Не указано' : text.trim(),
              style: TextStyle(
                color: active ? _CmrColors.graphite2 : _CmrColors.text,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                height: 1.05,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamKpiData {
  final IconData icon;
  final String value;
  final String label;
  final String hint;

  const _TeamKpiData({
    required this.icon,
    required this.value,
    required this.label,
    required this.hint,
  });
}

class _TeamKpiGrid extends StatelessWidget {
  final List<_TeamKpiData> items;
  final bool compact;

  const _TeamKpiGrid({required this.items, required this.compact});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = compact ? 8.0 : 10.0;
        final available = constraints.maxWidth.isFinite ? constraints.maxWidth : 720.0;
        final columns = available >= 760 ? 4 : (available >= 430 ? 2 : 1);
        final width = (available - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: items
              .map((item) => SizedBox(
                    width: width,
                    child: _TeamKpiCard(data: item, compact: compact),
                  ))
              .toList(),
        );
      },
    );
  }
}

class _TeamKpiCard extends StatelessWidget {
  final _TeamKpiData data;
  final bool compact;

  const _TeamKpiCard({required this.data, required this.compact});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 78),
      padding: EdgeInsets.all(compact ? 10 : 12),
      decoration: BoxDecoration(
        color: _CmrColors.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _CmrColors.divider.withOpacity(0.0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.025),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _CmrColors.greenSoft,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: _CmrColors.green.withOpacity(.14)),
            ),
            child: Icon(data.icon, color: _CmrColors.graphite2, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data.label, style: _CmrText.caption(), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(data.value.trim().isEmpty ? '—' : data.value, style: _CmrText.value(compact ? 15 : 16.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(data.hint, style: _CmrText.subtle(10.5), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamOverviewNotice extends StatelessWidget {
  final String title;
  final String text;

  const _TeamOverviewNotice({required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _CmrColors.greenSoft2,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _CmrColors.green.withOpacity(.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: _CmrColors.panel,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: _CmrColors.green.withOpacity(.18)),
            ),
            child: const Icon(Icons.space_dashboard_rounded, color: _CmrColors.graphite2, size: 18),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _CmrText.section(), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 5),
                Text(text, style: _CmrText.muted(11.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamPassportBlock extends StatelessWidget {
  final Map<String, dynamic> team;
  final String clubName;
  final String name;
  final String sport;
  final String subtitle;
  final String description;
  final VoidCallback onOpenTeam;

  const _TeamPassportBlock({
    required this.team,
    required this.clubName,
    required this.name,
    required this.sport,
    required this.subtitle,
    required this.description,
    required this.onOpenTeam,
  });

  @override
  Widget build(BuildContext context) {
    final season = _teamSeason(team);
    final city = _teamCity(team);
    final coach = _teamCoach(team);
    final status = _teamStatus(team);

    return _TeamPremiumBlock(
      icon: Icons.badge_rounded,
      title: 'Паспорт команды',
      actionText: 'Редактировать',
      onAction: onOpenTeam,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TeamInfoRow(icon: Icons.shield_rounded, label: 'Команда', value: name),
          _TeamInfoRow(icon: Icons.apartment_rounded, label: 'Клуб', value: clubName),
          _TeamInfoRow(icon: Icons.sports_soccer_rounded, label: 'Вид спорта', value: sport),
          _TeamInfoRow(icon: Icons.category_rounded, label: 'Группа', value: subtitle),
          _TeamInfoRow(icon: Icons.calendar_today_rounded, label: 'Сезон', value: season),
          _TeamInfoRow(icon: Icons.location_on_rounded, label: 'Локация', value: city),
          _TeamInfoRow(icon: Icons.person_rounded, label: 'Главный тренер', value: coach),
          _TeamInfoRow(icon: Icons.verified_rounded, label: 'Статус', value: status),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _CmrColors.soft,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _CmrColors.divider.withOpacity(0.0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Описание', style: _CmrText.caption().copyWith(color: _CmrColors.text)),
                const SizedBox(height: 6),
                Text(
                  description.isEmpty
                      ? 'Описание пока не заполнено. Здесь можно указать возрастную группу, цели сезона, игровую модель и особенности тренировочного процесса.'
                      : description,
                  style: _CmrText.muted(11.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _TeamInfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final text = value.trim().isEmpty ? 'Не указано' : value.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _CmrColors.soft,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _CmrColors.divider.withOpacity(0.0)),
            ),
            child: Icon(icon, color: _CmrColors.graphite2, size: 15),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: _CmrText.caption(), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(text, style: _CmrText.value(12.5), maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamWorkBlock extends StatelessWidget {
  final VoidCallback onOpenTeam;
  final VoidCallback? onOpenRoster;
  final VoidCallback? onOpenTrainers;

  const _TeamWorkBlock({
    required this.onOpenTeam,
    required this.onOpenRoster,
    required this.onOpenTrainers,
  });

  @override
  Widget build(BuildContext context) {
    return _TeamPremiumBlock(
      icon: Icons.dashboard_customize_rounded,
      title: 'Рабочая область',
      actionText: 'Открыть',
      onAction: onOpenTeam,
      child: Column(
        children: [
          _TeamWorkAction(
            icon: Icons.space_dashboard_rounded,
            title: 'Обзор команды',
            subtitle: 'Общая сводка, матчи, календарь и планы',
            onTap: onOpenTeam,
            primary: true,
          ),
          const SizedBox(height: 9),
          _TeamWorkAction(
            icon: Icons.groups_2_rounded,
            title: 'Состав',
            subtitle: 'Игроки, карточки, метрики и профили',
            onTap: onOpenRoster,
          ),
          const SizedBox(height: 9),
          _TeamWorkAction(
            icon: Icons.badge_rounded,
            title: 'Тренеры',
            subtitle: 'Назначения, роли и рабочий доступ',
            onTap: onOpenTrainers,
          ),
          const SizedBox(height: 9),
          _TeamWorkAction(
            icon: Icons.tune_rounded,
            title: 'Настройки команды',
            subtitle: 'Паспорт, логотип, описание и параметры',
            onTap: onOpenTeam,
          ),
        ],
      ),
    );
  }
}

class _TeamWorkAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool primary;

  const _TeamWorkAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: primary ? _CmrColors.graphite : _CmrColors.panel,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: primary ? _CmrColors.graphite : _CmrColors.divider),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: primary ? Colors.white.withOpacity(.08) : _CmrColors.greenSoft,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: primary ? Colors.white.withOpacity(.12) : _CmrColors.green.withOpacity(.14)),
                ),
                child: Icon(icon, color: primary ? _CmrColors.green : _CmrColors.graphite2, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: _CmrText.value(12.8).copyWith(color: primary ? Colors.white : _CmrColors.text),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      enabled ? subtitle : 'Раздел будет доступен после подключения обработчика',
                      style: _CmrText.subtle(10.5).copyWith(color: primary ? Colors.white.withOpacity(.72) : _CmrColors.subtle),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                enabled ? Icons.chevron_right_rounded : Icons.lock_outline_rounded,
                color: primary ? Colors.white : _CmrColors.muted,
                size: 19,
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _RecentTestingProblem {
  final int playerId;
  final String playerName;
  final String photo;
  final String dateIso;
  final String category;
  final String stage;
  final String title;
  final String message;
  final int weakCount;
  final bool critical;

  const _RecentTestingProblem({
    required this.playerId,
    required this.playerName,
    required this.photo,
    required this.dateIso,
    required this.category,
    required this.stage,
    required this.title,
    required this.message,
    required this.weakCount,
    required this.critical,
  });
}

class _TeamRecentTestingBlock extends StatefulWidget {
  final int clubId;
  final int teamId;
  final String clubName;
  final String teamName;
  final List<Map<String, dynamic>> players;
  final List<Map<String, dynamic>> latestTests;
  final int fallbackTestsCount;
  final int fallbackPlayersCount;
  final VoidCallback? onOpenTesting;

  const _TeamRecentTestingBlock({
    required this.clubId,
    required this.teamId,
    required this.clubName,
    required this.teamName,
    required this.players,
    required this.latestTests,
    required this.fallbackTestsCount,
    required this.fallbackPlayersCount,
    required this.onOpenTesting,
  });

  @override
  State<_TeamRecentTestingBlock> createState() => _TeamRecentTestingBlockState();
}

class _TeamRecentTestingBlockState extends State<_TeamRecentTestingBlock> {
  Future<List<_RecentTestingProblem>>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant _TeamRecentTestingBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.teamId != widget.teamId ||
        oldWidget.latestTests.length != widget.latestTests.length ||
        oldWidget.players.length != widget.players.length) {
      _future = _load();
    }
  }

  Future<List<_RecentTestingProblem>> _load() async {
    if (widget.teamId <= 0) return <_RecentTestingProblem>[];

    final local = _problemsFromLocalTests(widget.latestTests);
    final remote = await _loadRemoteProblems();
    return _dedupeProblems([...local, ...remote]).take(8).toList();
  }

  Future<List<_RecentTestingProblem>> _loadRemoteProblems() async {
    final out = <_RecentTestingProblem>[];
    final stage = _testingStageFromTeamName(widget.teamName);
    final categories = <String>['physical', 'technical', 'tactical', 'functional'];
    final from = _dateIso(DateTime.now().subtract(const Duration(days: 14)));
    final to = _dateIso(DateTime.now());

    for (final category in categories) {
      final sessions = await _fetchTestingSessions(category: category, stage: stage, from: from, to: to);
      for (final session in sessions.take(3)) {
        final dateIso = _testingDateIso(session);
        if (dateIso.isEmpty || !_isWithinLastTwoWeeks(dateIso)) continue;
        final matrix = await _fetchTestingMatrix(
          category: category,
          stage: stage,
          dateIso: dateIso,
          sessionId: _intFromAny(session['id'] ?? session['session_id']),
        );
        out.addAll(_problemsFromMatrix(matrix, category: category, stage: stage, dateIso: dateIso));
      }
    }

    // Фолбэк: если endpoint сессий не вернул список, пробуем получить последние данные напрямую.
    if (out.isEmpty) {
      for (final category in categories.take(2)) {
        final matrix = await _fetchTestingMatrix(category: category, stage: stage, dateIso: '', sessionId: 0, from: from, to: to);
        out.addAll(_problemsFromMatrix(matrix, category: category, stage: stage, dateIso: to));
      }
    }

    return out;
  }

  Future<List<Map<String, dynamic>>> _fetchTestingSessions({
    required String category,
    required String stage,
    required String from,
    required String to,
  }) async {
    try {
      final uri = Uri.parse('https://sportotekaapp.ru/api/get_testing_sessions.php').replace(queryParameters: {
        'club_id': '${widget.clubId}',
        'team_id': '${widget.teamId}',
        'category': category,
        'stage': stage,
        'date_from': from,
        'from_date': from,
        'date_to': to,
        'to_date': to,
      });
      final r = await http.get(uri).timeout(const Duration(seconds: 10));
      final list = _extractList(_tryDecode(r.body), const ['sessions', 'data', 'items', 'result']);
      final filtered = list.where((s) {
        final iso = _testingDateIso(s);
        return iso.isNotEmpty && _isWithinLastTwoWeeks(iso);
      }).toList();
      filtered.sort((a, b) => _testingDateIso(b).compareTo(_testingDateIso(a)));
      return filtered;
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<Map<String, dynamic>> _fetchTestingMatrix({
    required String category,
    required String stage,
    required String dateIso,
    required int sessionId,
    String? from,
    String? to,
  }) async {
    try {
      final params = <String, String>{
        'club_id': '${widget.clubId}',
        'team_id': '${widget.teamId}',
        'category': category,
        'stage': stage,
        if (dateIso.isNotEmpty) 'test_date': dateIso,
        if (sessionId > 0) 'session_id': '$sessionId',
        if (from != null) 'date_from': from,
        if (from != null) 'from_date': from,
        if (to != null) 'date_to': to,
        if (to != null) 'to_date': to,
      };
      final uri = Uri.parse('https://sportotekaapp.ru/api/get_testing_matrix.php').replace(queryParameters: params);
      final r = await http.get(uri).timeout(const Duration(seconds: 12));
      final decoded = _tryDecode(r.body);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  List<_RecentTestingProblem> _problemsFromLocalTests(List<Map<String, dynamic>> tests) {
    final out = <_RecentTestingProblem>[];
    for (final test in tests) {
      final dateIso = _testingDateIso(test);
      if (dateIso.isNotEmpty && !_isWithinLastTwoWeeks(dateIso)) continue;

      final badCount = _intFromAny(test['poor_count'] ?? test['warnings_count'] ?? test['bad_count'] ?? test['weak_count']);
      final status = _s(test['status'] ?? test['rating'] ?? test['rating_code'] ?? test['label']).toLowerCase();
      final badByStatus = _looksBadStatus(status);
      if (badCount <= 0 && !badByStatus) continue;

      final playerId = _intFromAny(test['player_id'] ?? test['playerId'] ?? test['athlete_id'] ?? test['student_id']);
      final name = _s(test['player_name'] ?? test['full_name'] ?? test['name']).isEmpty
          ? 'Игрок команды'
          : _s(test['player_name'] ?? test['full_name'] ?? test['name']);
      out.add(_RecentTestingProblem(
        playerId: playerId,
        playerName: name,
        photo: _normalizeImage(_s(test['photo'] ?? test['photo_url'] ?? test['avatar'] ?? test['avatar_url'])),
        dateIso: dateIso.isEmpty ? _dateIso(DateTime.now()) : dateIso,
        category: _s(test['category'] ?? test['category_code']).isEmpty ? 'physical' : _s(test['category'] ?? test['category_code']),
        stage: _s(test['stage']).isEmpty ? _testingStageFromTeamName(widget.teamName) : _s(test['stage']),
        title: _s(test['title'] ?? test['test_title'] ?? test['category_title']).isEmpty
            ? 'Тестирование'
            : _s(test['title'] ?? test['test_title'] ?? test['category_title']),
        message: badCount > 0 ? 'Слабых показателей: $badCount' : 'Низкая оценка по тестированию',
        weakCount: badCount > 0 ? badCount : 1,
        critical: badCount >= 3 || status.contains('critical') || status.contains('крит'),
      ));
    }
    return out;
  }

  List<_RecentTestingProblem> _problemsFromMatrix(
    Map<String, dynamic> matrix, {
    required String category,
    required String stage,
    required String dateIso,
  }) {
    final players = _extractList(matrix, const ['players', 'data', 'items']);
    final tests = _extractList(matrix, const ['tests', 'test_items', 'columns']);
    final normatives = _extractList(matrix, const ['normatives', 'norms', 'standards']);
    final out = <_RecentTestingProblem>[];

    for (final rawPlayer in players) {
      final player = Map<String, dynamic>.from(rawPlayer);
      final weak = _weakTestingTitles(player, tests: tests, normatives: normatives);
      final explicitBad = _intFromAny(player['poor_count'] ?? player['warnings_count'] ?? player['bad_count'] ?? player['weak_count']);
      if (weak.isEmpty && explicitBad <= 0) continue;

      final playerId = _playerId(player);
      final fallback = _playerById(playerId);
      final weakCount = weak.isNotEmpty ? weak.length : explicitBad;
      final weakText = weak.isEmpty ? 'несколько показателей' : weak.take(3).join(', ');
      final extra = weak.length > 3 ? ' и ещё ${weak.length - 3}' : '';

      out.add(_RecentTestingProblem(
        playerId: playerId,
        playerName: _playerName(player) == 'Игрок' && fallback != null ? _playerName(fallback) : _playerName(player),
        photo: _playerPhoto(player).isNotEmpty ? _playerPhoto(player) : (fallback == null ? '' : _playerPhoto(fallback)),
        dateIso: dateIso.isEmpty ? _dateIso(DateTime.now()) : dateIso,
        category: category,
        stage: stage,
        title: _testingCategoryTitle(category),
        message: 'Плохо: $weakText$extra',
        weakCount: weakCount,
        critical: weakCount >= 3,
      ));
    }
    return out;
  }

  List<String> _weakTestingTitles(
    Map<String, dynamic> player, {
    required List<Map<String, dynamic>> tests,
    required List<Map<String, dynamic>> normatives,
  }) {
    final weak = <String>[];
    final rawResults = player['results'] ?? player['tests'] ?? player['matrix'] ?? player['items'];

    void checkValue(String code, dynamic raw, String fallbackTitle) {
      final result = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{'value': raw};
      final ratingText = _s(result['rating'] ?? result['rating_code'] ?? result['status'] ?? result['label'] ?? result['rating_label']).toLowerCase();
      final points = _intFromAny(result['points'] ?? result['score'] ?? result['rating_points']);
      final title = _testTitleByCode(code, tests, fallbackTitle);

      if (_looksBadStatus(ratingText) || (points > 0 && points <= 1)) {
        weak.add(title);
        return;
      }

      final value = _doubleFromAny(result['value'] ?? result['result']);
      if (value == null) return;
      final resolved = _ratingFromNormatives(code, value, tests: tests, normatives: normatives);
      if (resolved != null && _looksBadStatus(resolved)) weak.add(title);
    }

    if (rawResults is Map) {
      rawResults.forEach((key, value) => checkValue('$key', value, '$key'));
    } else if (rawResults is List) {
      for (final value in rawResults) {
        if (value is Map) {
          final code = _s(value['test_code'] ?? value['code'] ?? value['test'] ?? value['id']);
          checkValue(code, value, _s(value['title'] ?? value['name']).isEmpty ? 'показатель' : _s(value['title'] ?? value['name']));
        } else {
          checkValue('', value, 'показатель');
        }
      }
    }

    return weak.toSet().toList();
  }

  String? _ratingFromNormatives(
    String code,
    double value, {
    required List<Map<String, dynamic>> tests,
    required List<Map<String, dynamic>> normatives,
  }) {
    if (code.isEmpty || normatives.isEmpty) return null;
    final lower = _intFromAny(_testByCode(code, tests)['lower_is_better']) == 1;
    final normalizedValue = (code == 'long_jump' && value > 0 && value < 20) ? value * 100 : value;

    for (final n in normatives) {
      if (_s(n['test_code'] ?? n['code']) != code) continue;
      final min = _doubleFromAny(n['min_value'] ?? n['min']);
      final max = _doubleFromAny(n['max_value'] ?? n['max']);
      var hit = false;
      if (lower) {
        hit = (max == null || normalizedValue <= max) && (min == null || normalizedValue >= min);
      } else {
        hit = (min == null || normalizedValue >= min) && (max == null || normalizedValue <= max);
      }
      if (hit) return _s(n['rating'] ?? n['label'] ?? n['rating_label'] ?? n['status']).toLowerCase();
    }
    return null;
  }

  Map<String, dynamic> _testByCode(String code, List<Map<String, dynamic>> tests) {
    for (final t in tests) {
      if (_s(t['code'] ?? t['test_code']) == code) return t;
    }
    return <String, dynamic>{};
  }

  String _testTitleByCode(String code, List<Map<String, dynamic>> tests, String fallback) {
    final test = _testByCode(code, tests);
    final title = _s(test['short_title'] ?? test['title'] ?? test['name']);
    return title.isEmpty ? (fallback.isEmpty ? 'показатель' : fallback) : title;
  }

  Map<String, dynamic>? _playerById(int playerId) {
    if (playerId <= 0) return null;
    for (final player in widget.players) {
      if (_playerId(player) == playerId) return player;
    }
    return null;
  }

  List<_RecentTestingProblem> _dedupeProblems(List<_RecentTestingProblem> source) {
    final seen = <String>{};
    final out = <_RecentTestingProblem>[];
    for (final item in source) {
      final key = '${item.playerId}|${item.playerName.toLowerCase()}|${item.dateIso}|${item.category}|${item.message.toLowerCase()}';
      if (seen.add(key)) out.add(item);
    }
    out.sort((a, b) {
      final c = (b.critical ? 1 : 0).compareTo(a.critical ? 1 : 0);
      if (c != 0) return c;
      final w = b.weakCount.compareTo(a.weakCount);
      if (w != 0) return w;
      return b.dateIso.compareTo(a.dateIso);
    });
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<_RecentTestingProblem>>(
      future: _future,
      builder: (context, snapshot) {
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final problems = snapshot.data ?? const <_RecentTestingProblem>[];
        final hasProblems = problems.isNotEmpty;
        final bg = hasProblems ? _CmrColors.redSoft : _CmrColors.greenSoft2;
        final border = hasProblems ? _CmrColors.red.withOpacity(.22) : _CmrColors.green.withOpacity(.18);
        final iconColor = hasProblems ? _CmrColors.red : _CmrColors.graphite2;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: iconColor.withOpacity(.16)),
                    ),
                    child: Icon(hasProblems ? Icons.priority_high_rounded : Icons.verified_rounded, color: iconColor, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Тестирование за 14 дней', style: _CmrText.section(), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 3),
                        Text(
                          loading
                              ? 'Проверяю последние сессии тестирования команды...'
                              : hasProblems
                                  ? 'Есть игроки с плохими результатами. Нажмите на карточку игрока, чтобы открыть его тестирование.'
                                  : (widget.fallbackPlayersCount > 0
                                      ? 'Плохих результатов за последние две недели не найдено.'
                                      : 'Сначала добавьте игроков в состав команды.'),
                          style: _CmrText.muted(11),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (loading) ...[
                    const SizedBox(width: 8),
                    const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: _CmrColors.green)),
                  ] else if (widget.onOpenTesting != null) ...[
                    const SizedBox(width: 8),
                    _TeamSmallRoundButton(text: 'Все тесты', onTap: widget.onOpenTesting),
                  ],
                ],
              ),
              if (hasProblems) ...[
                const SizedBox(height: 10),
                ...problems.take(4).map((problem) => _RecentTestingProblemTile(
                      problem: problem,
                      onTap: () => _openPlayerTesting(context, problem),
                    )),
              ] else if (!loading && widget.fallbackTestsCount <= 0) ...[
                const SizedBox(height: 10),
                Text('Нет сохранённых тестов за выбранный период. Когда тренер внесёт результаты, здесь появится контроль по игрокам.', style: _CmrText.subtle(10.8)),
              ],
            ],
          ),
        );
      },
    );
  }

  void _openPlayerTesting(BuildContext context, _RecentTestingProblem problem) {
    if (problem.playerId <= 0) {
      widget.onOpenTesting?.call();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (routeContext) => Scaffold(
          backgroundColor: _CmrColors.bg,
          body: SafeArea(
            child: CmrTestingPanel(
              clubId: widget.clubId,
              teamId: widget.teamId,
              clubName: widget.clubName,
              teamName: widget.teamName,
              initialStage: problem.stage.isEmpty ? _testingStageFromTeamName(widget.teamName) : problem.stage,
              initialCategory: problem.category.isEmpty ? 'physical' : problem.category,
              initialDate: problem.dateIso,
              initialPlayerId: problem.playerId,
              initialPlayerName: problem.playerName,
              onBackToMenu: () => Navigator.of(routeContext).pop(),
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentTestingProblemTile extends StatelessWidget {
  final _RecentTestingProblem problem;
  final VoidCallback onTap;

  const _RecentTestingProblemTile({required this.problem, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final badgeColor = problem.critical ? _CmrColors.red : _CmrColors.orange;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: badgeColor.withOpacity(.24)),
            ),
            child: Row(
              children: [
                _TeamSmallAvatar(url: problem.photo, name: problem.playerName, size: 38),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(problem.playerName, style: _CmrText.value(12.6), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: badgeColor.withOpacity(.10),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: badgeColor.withOpacity(.18)),
                            ),
                            child: Text(
                              problem.critical ? 'КРАСНАЯ ЗОНА' : 'ПЛОХО',
                              style: TextStyle(color: badgeColor, fontSize: 8.5, fontWeight: FontWeight.w600, letterSpacing: .2),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text('${_dateHuman(problem.dateIso)} · ${problem.title}', style: _CmrText.caption(), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(problem.message, style: _CmrText.subtle(10.5), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.chevron_right_rounded, color: badgeColor, size: 19),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


class _TeamSnapshotData {
  final List<Map<String, dynamic>> players;
  final List<Map<String, dynamic>> events;
  final List<Map<String, dynamic>> matches;
  final List<Map<String, dynamic>> trainings;
  final List<Map<String, dynamic>> plans;
  final List<Map<String, dynamic>> news;
  final List<Map<String, dynamic>> tests;
  final List<_TeamPlayerWarning> warnings;

  const _TeamSnapshotData({
    this.players = const <Map<String, dynamic>>[],
    this.events = const <Map<String, dynamic>>[],
    this.matches = const <Map<String, dynamic>>[],
    this.trainings = const <Map<String, dynamic>>[],
    this.plans = const <Map<String, dynamic>>[],
    this.news = const <Map<String, dynamic>>[],
    this.tests = const <Map<String, dynamic>>[],
    this.warnings = const <_TeamPlayerWarning>[],
  });
}

class _TeamPlayerWarning {
  final int playerId;
  final String playerName;
  final String title;
  final String message;
  final String photo;
  final String severity;

  const _TeamPlayerWarning({
    this.playerId = 0,
    required this.playerName,
    required this.title,
    required this.message,
    this.photo = '',
    this.severity = 'warning',
  });
}

class _TeamLiveOverviewBlock extends StatefulWidget {
  final int clubId;
  final int fallbackClubId;
  final int teamId;
  final String teamName;
  final int playersCount;
  final List<Map<String, dynamic>> events;
  final List<Map<String, dynamic>> latestPlans;
  final List<Map<String, dynamic>> news;
  final List<Map<String, dynamic>> latestTrainings;
  final List<Map<String, dynamic>> latestTests;
  final List<Map<String, dynamic>> players;
  final VoidCallback? onOpenRoster;
  final VoidCallback? onOpenCalendar;
  final VoidCallback? onOpenPlans;
  final VoidCallback? onOpenTrainings;
  final VoidCallback? onOpenTesting;
  final VoidCallback? onOpenChats;

  const _TeamLiveOverviewBlock({
    required this.clubId,
    required this.fallbackClubId,
    required this.teamId,
    required this.teamName,
    required this.playersCount,
    required this.events,
    required this.latestPlans,
    required this.news,
    required this.latestTrainings,
    required this.latestTests,
    required this.players,
    required this.onOpenRoster,
    required this.onOpenCalendar,
    required this.onOpenPlans,
    required this.onOpenTrainings,
    required this.onOpenTesting,
    required this.onOpenChats,
  });

  @override
  State<_TeamLiveOverviewBlock> createState() => _TeamLiveOverviewBlockState();
}

class _TeamLiveOverviewBlockState extends State<_TeamLiveOverviewBlock> {
  Future<_TeamSnapshotData>? _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant _TeamLiveOverviewBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.teamId != widget.teamId ||
        oldWidget.players.length != widget.players.length ||
        oldWidget.events.length != widget.events.length ||
        oldWidget.latestPlans.length != widget.latestPlans.length ||
        oldWidget.latestTests.length != widget.latestTests.length) {
      _future = _load();
    }
  }

  Future<_TeamSnapshotData> _load() async {
    if (widget.teamId <= 0) return const _TeamSnapshotData();

    var players = _scoped(widget.players);
    var events = _scoped(widget.events);
    var plans = _scoped(widget.latestPlans);
    var tests = _scoped(widget.latestTests);
    var news = _scoped(widget.news);
    var trainings = _scoped(widget.latestTrainings);

    if (players.isEmpty) players = await _fetchPlayers();
    if (events.isEmpty) events = await _fetchEvents();
    if (plans.isEmpty) plans = await _fetchPlans();

    if (trainings.isEmpty) {
      trainings = events.where(_looksLikeTraining).toList();
    }
    if (news.isEmpty) {
      news = events.where(_looksLikeNews).toList();
    }

    final matches = events.where(_looksLikeMatch).toList();
    _sortByDate(events);
    _sortByDate(matches);
    _sortByDate(trainings);
    _sortByDate(plans);
    _sortByDate(news);
    _sortByDate(tests);

    final localWarnings = _warningsFromTests(tests);
    final matrixWarnings = await _fetchTestingWarnings();
    final warnings = _dedupeWarnings([...localWarnings, ...matrixWarnings]);

    return _TeamSnapshotData(
      players: players,
      events: events.take(8).toList(),
      matches: matches.take(6).toList(),
      trainings: trainings.take(6).toList(),
      plans: plans.take(6).toList(),
      news: news.take(6).toList(),
      tests: tests.take(6).toList(),
      warnings: warnings.take(8).toList(),
    );
  }

  List<Map<String, dynamic>> _scoped(List<Map<String, dynamic>> source) {
    if (source.isEmpty || widget.teamId <= 0) return <Map<String, dynamic>>[];
    return source.where((item) => _belongsToSelectedTeam(item)).map((e) => Map<String, dynamic>.from(e)).toList();
  }

  bool _belongsToSelectedTeam(Map<String, dynamic> item) {
    final id = _itemTeamId(item);
    if (id > 0) return id == widget.teamId;

    final teamName = _s(
      item['team_name'] ??
          item['teamName'] ??
          item['club_team_name'] ??
          item['team_title'] ??
          item['group_name'],
    ).toLowerCase().trim();
    if (teamName.isNotEmpty) return teamName == widget.teamName.toLowerCase().trim();

    // Если родитель уже загрузил данные после выбора команды, в них иногда нет team_id.
    // Тогда оставляем их как локальные для текущей правой панели.
    return true;
  }

  Future<List<Map<String, dynamic>>> _fetchPlayers() async {
    try {
      final resp = await http
          .post(
            Uri.parse('https://sportotekaapp.ru/api/get_players.php'),
            headers: const {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode({'team_id': widget.teamId}),
          )
          .timeout(const Duration(seconds: 10));
      final data = _tryDecode(resp.body);
      final list = _extractList(data, const ['players', 'data', 'items', 'members']);
      return list.map((player) {
        final item = Map<String, dynamic>.from(player);
        item['team_id'] = widget.teamId;
        item['team_name'] = widget.teamName;
        return item;
      }).toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchEvents() async {
    try {
      final params = <String, String>{
        'team_id': '${widget.teamId}',
        if (widget.clubId > 0 || widget.fallbackClubId > 0) 'club_id': '${widget.clubId > 0 ? widget.clubId : widget.fallbackClubId}',
      };
      final uri = Uri.parse('https://sportotekaapp.ru/api/get_club_events.php').replace(queryParameters: params);
      final resp = await http.get(uri).timeout(const Duration(seconds: 10));
      final list = _extractList(_tryDecode(resp.body), const ['events', 'data', 'items']);
      return list.where(_belongsToSelectedTeam).toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<List<Map<String, dynamic>>> _fetchPlans() async {
    try {
      final params = <String, String>{
        'team_id': '${widget.teamId}',
        'limit': '6',
        if (widget.clubId > 0 || widget.fallbackClubId > 0) 'club_id': '${widget.clubId > 0 ? widget.clubId : widget.fallbackClubId}',
      };
      final uri = Uri.parse('https://sportotekaapp.ru/api/get_latest_training_plans.php').replace(queryParameters: params);
      final resp = await http.get(uri).timeout(const Duration(seconds: 10));
      final list = _extractList(_tryDecode(resp.body), const ['plans', 'items', 'data', 'result']);
      return list.where(_belongsToSelectedTeam).toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<List<_TeamPlayerWarning>> _fetchTestingWarnings() async {
    try {
      final params = <String, String>{
        'team_id': '${widget.teamId}',
        if (widget.clubId > 0 || widget.fallbackClubId > 0) 'club_id': '${widget.clubId > 0 ? widget.clubId : widget.fallbackClubId}',
      };
      final uri = Uri.parse('https://sportotekaapp.ru/api/get_testing_matrix.php').replace(queryParameters: params);
      final resp = await http.get(uri).timeout(const Duration(seconds: 10));
      final decoded = _tryDecode(resp.body);
      final rawPlayers = decoded is Map ? decoded['players'] : null;
      final players = rawPlayers is List
          ? rawPlayers.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
          : <Map<String, dynamic>>[];
      return _warningsFromMatrixPlayers(players, 'Физическое тестирование');
    } catch (_) {
      return <_TeamPlayerWarning>[];
    }
  }

  List<_TeamPlayerWarning> _warningsFromTests(List<Map<String, dynamic>> tests) {
    final warnings = <_TeamPlayerWarning>[];
    for (final test in tests) {
      final badCount = _intFromAny(test['poor_count'] ?? test['warnings_count'] ?? test['bad_count'] ?? test['weak_count']);
      if (badCount <= 0) continue;
      warnings.add(_TeamPlayerWarning(
        playerId: _intFromAny(test['player_id'] ?? test['playerId'] ?? test['athlete_id']),
        playerName: _s(test['player_name'] ?? test['full_name'] ?? test['name']).isEmpty
            ? 'Игроки команды'
            : _s(test['player_name'] ?? test['full_name'] ?? test['name']),
        title: _s(test['title'] ?? test['name'] ?? test['category_title']).isEmpty
            ? 'Тестирование'
            : _s(test['title'] ?? test['name'] ?? test['category_title']),
        message: 'Есть слабые показатели: $badCount. Нужна корректировка нагрузки и индивидуальная заметка тренера.',
        photo: _normalizeImage(_s(test['photo'] ?? test['photo_url'] ?? test['avatar'] ?? test['avatar_url'])),
        severity: badCount >= 3 ? 'critical' : 'warning',
      ));
    }
    return warnings;
  }

  List<_TeamPlayerWarning> _warningsFromMatrixPlayers(List<Map<String, dynamic>> players, String testTitle) {
    final warnings = <_TeamPlayerWarning>[];
    for (final player in players) {
      final weak = <String>[];
      final rawResults = player['results'] ?? player['tests'] ?? player['matrix'] ?? player['items'];

      void checkValue(dynamic raw, String fallbackTitle) {
        if (raw is Map) {
          final rating = _s(raw['rating'] ?? raw['rating_code'] ?? raw['code'] ?? raw['status']).toLowerCase();
          final label = _s(raw['label'] ?? raw['rating_label'] ?? raw['status_label'] ?? raw['note']).toLowerCase();
          final points = _intFromAny(raw['points'] ?? raw['score'] ?? raw['rating_points']);
          final title = _s(raw['short_title'] ?? raw['test_title'] ?? raw['title'] ?? raw['name']);
          final bad = rating.contains('poor') ||
              rating.contains('bad') ||
              rating.contains('low') ||
              rating.contains('critical') ||
              label.contains('неуд') ||
              label.contains('слаб') ||
              label.contains('ниже') ||
              label.contains('крит') ||
              (points > 0 && points <= 1);
          if (bad) weak.add(title.isEmpty ? fallbackTitle : title);
        } else {
          final text = _s(raw).toLowerCase();
          if (text.contains('poor') || text.contains('bad') || text.contains('слаб') || text.contains('неуд')) {
            weak.add(fallbackTitle);
          }
        }
      }

      if (rawResults is Map) {
        rawResults.forEach((key, value) => checkValue(value, '$key'));
      } else if (rawResults is List) {
        for (final value in rawResults) {
          checkValue(value, 'показатель');
        }
      }

      final explicitBad = _intFromAny(player['poor_count'] ?? player['warnings_count'] ?? player['bad_count'] ?? player['weak_count']);
      if (weak.isEmpty && explicitBad > 0) weak.add('несколько показателей');
      if (weak.isEmpty) continue;

      final weakText = weak.take(3).join(', ');
      final extra = weak.length > 3 ? ' и ещё ${weak.length - 3}' : '';
      warnings.add(_TeamPlayerWarning(
        playerId: _playerId(player),
        playerName: _playerName(player),
        title: testTitle,
        message: 'Проблема по тестам: $weakText$extra. Добавьте заметку и проверьте индивидуальную нагрузку.',
        photo: _playerPhoto(player),
        severity: weak.length >= 3 ? 'critical' : 'warning',
      ));
    }
    return warnings;
  }

  List<_TeamPlayerWarning> _dedupeWarnings(List<_TeamPlayerWarning> source) {
    final seen = <String>{};
    final out = <_TeamPlayerWarning>[];
    for (final item in source) {
      final key = '${item.playerId}|${item.playerName.toLowerCase()}|${item.title.toLowerCase()}|${item.message.toLowerCase()}';
      if (seen.add(key)) out.add(item);
    }
    out.sort((a, b) {
      final ac = a.severity == 'critical' ? 1 : 0;
      final bc = b.severity == 'critical' ? 1 : 0;
      return bc.compareTo(ac);
    });
    return out;
  }

  bool _looksLikeTraining(Map<String, dynamic> item) {
    final text = _typeTitle(item);
    return text.contains('training') || text.contains('трен') || text.contains('занят');
  }

  bool _looksLikeNews(Map<String, dynamic> item) {
    final text = _typeTitle(item);
    return text.contains('news') || text.contains('нов') || text.contains('post') || text.contains('пост') || text.contains('лента');
  }

  bool _looksLikeMatch(Map<String, dynamic> item) {
    final text = _typeTitle(item);
    return text.contains('match') ||
        text.contains('game') ||
        text.contains('матч') ||
        text.contains('игра') ||
        text.contains('турнир') ||
        text.contains('кубок') ||
        text.contains('чемпионат');
  }

  String _typeTitle(Map<String, dynamic> item) {
    return '${_s(item['type'] ?? item['event_type'] ?? item['category'] ?? item['kind'])} '
            '${_s(item['title'] ?? item['name'] ?? item['event_title'] ?? item['caption'])}'
        .toLowerCase();
  }

  void _sortByDate(List<Map<String, dynamic>> items) {
    items.sort((a, b) {
      final ad = _dateOf(a);
      final bd = _dateOf(b);
      if (ad == null && bd == null) return 0;
      if (ad == null) return 1;
      if (bd == null) return -1;
      return ad.compareTo(bd);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_TeamSnapshotData>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data ?? const _TeamSnapshotData();
        final loading = snapshot.connectionState == ConnectionState.waiting && snapshot.data == null;
        return _TeamPremiumBlock(
          icon: Icons.space_dashboard_rounded,
          title: 'Обзор выбранной команды',
          actionText: 'Обновить',
          onAction: () => setState(() => _future = _load()),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (loading) ...[
                const LinearProgressIndicator(minHeight: 3, color: _CmrColors.green),
                const SizedBox(height: 12),
              ],
              _TeamSnapshotMetrics(
                players: data.players.isNotEmpty ? data.players.length : widget.playersCount,
                events: data.events.length,
                trainings: data.trainings.length,
                plans: data.plans.length,
                warnings: data.warnings.length,
                onOpenRoster: widget.onOpenRoster,
                onOpenCalendar: widget.onOpenCalendar,
                onOpenTrainings: widget.onOpenTrainings,
                onOpenPlans: widget.onOpenPlans,
                onOpenTesting: widget.onOpenTesting,
              ),
              const SizedBox(height: 12),
              _TeamTestingWarningsBlock(
                warnings: data.warnings,
                testsCount: data.tests.length,
                onOpenTesting: widget.onOpenTesting,
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, c) {
                  final two = c.maxWidth >= 720;
                  final left = Column(
                    children: [
                      _TeamCompactFeedBlock(
                        icon: Icons.calendar_month_rounded,
                        title: 'Календарь и события',
                        emptyTitle: 'Событий пока нет',
                        items: data.matches.isNotEmpty ? data.matches : data.events,
                        onTap: widget.onOpenCalendar,
                      ),
                      const SizedBox(height: 10),
                      _TeamCompactFeedBlock(
                        icon: Icons.fitness_center_rounded,
                        title: 'Тренировки',
                        emptyTitle: 'Тренировок пока нет',
                        items: data.trainings,
                        onTap: widget.onOpenTrainings,
                      ),
                    ],
                  );
                  final right = Column(
                    children: [
                      _TeamCompactFeedBlock(
                        icon: Icons.assignment_turned_in_rounded,
                        title: 'Планы и задания',
                        emptyTitle: 'Планов пока нет',
                        items: data.plans,
                        onTap: widget.onOpenPlans,
                      ),
                      const SizedBox(height: 10),
                      _TeamCompactFeedBlock(
                        icon: Icons.campaign_rounded,
                        title: 'Лента и новости',
                        emptyTitle: 'Лента пока пустая',
                        items: data.news,
                        onTap: widget.onOpenChats,
                      ),
                    ],
                  );
                  if (!two) {
                    return Column(children: [left, const SizedBox(height: 10), right]);
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: left),
                      const SizedBox(width: 10),
                      Expanded(child: right),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              _TeamPlayersPreviewBlock(
                players: data.players,
                fallbackCount: widget.playersCount,
                onOpenRoster: widget.onOpenRoster,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TeamSnapshotMetrics extends StatelessWidget {
  final int players;
  final int events;
  final int trainings;
  final int plans;
  final int warnings;
  final VoidCallback? onOpenRoster;
  final VoidCallback? onOpenCalendar;
  final VoidCallback? onOpenTrainings;
  final VoidCallback? onOpenPlans;
  final VoidCallback? onOpenTesting;

  const _TeamSnapshotMetrics({
    required this.players,
    required this.events,
    required this.trainings,
    required this.plans,
    required this.warnings,
    required this.onOpenRoster,
    required this.onOpenCalendar,
    required this.onOpenTrainings,
    required this.onOpenPlans,
    required this.onOpenTesting,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = 8.0;
        final columns = constraints.maxWidth >= 760 ? 5 : (constraints.maxWidth >= 500 ? 3 : 2);
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        final items = [
          _TeamMetricData(Icons.groups_2_rounded, '$players', 'игроков', onOpenRoster),
          _TeamMetricData(Icons.event_available_rounded, '$events', 'событий', onOpenCalendar),
          _TeamMetricData(Icons.fitness_center_rounded, '$trainings', 'тренировок', onOpenTrainings),
          _TeamMetricData(Icons.assignment_rounded, '$plans', 'планов', onOpenPlans),
          _TeamMetricData(Icons.warning_amber_rounded, '$warnings', 'заметок', onOpenTesting, danger: warnings > 0),
        ];
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: items.map((item) => SizedBox(width: width, child: _TeamSnapshotMetricCard(data: item))).toList(),
        );
      },
    );
  }
}

class _TeamMetricData {
  final IconData icon;
  final String value;
  final String label;
  final VoidCallback? onTap;
  final bool danger;
  const _TeamMetricData(this.icon, this.value, this.label, this.onTap, {this.danger = false});
}

class _TeamSnapshotMetricCard extends StatelessWidget {
  final _TeamMetricData data;
  const _TeamSnapshotMetricCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: data.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: data.danger ? _CmrColors.orangeSoft : _CmrColors.soft,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: data.danger ? _CmrColors.orange.withOpacity(.22) : _CmrColors.divider),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(data.icon, color: data.danger ? _CmrColors.orange : _CmrColors.graphite2, size: 17),
                  const SizedBox(width: 6),
                  const Expanded(child: SizedBox()),
                  Icon(Icons.chevron_right_rounded, color: _CmrColors.subtle, size: 16),
                ],
              ),
              const SizedBox(height: 10),
              Text(data.value, style: _CmrText.value(18), maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(data.label, style: _CmrText.caption(), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeamTestingWarningsBlock extends StatelessWidget {
  final List<_TeamPlayerWarning> warnings;
  final int testsCount;
  final VoidCallback? onOpenTesting;

  const _TeamTestingWarningsBlock({
    required this.warnings,
    required this.testsCount,
    required this.onOpenTesting,
  });

  @override
  Widget build(BuildContext context) {
    final hasWarnings = warnings.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hasWarnings ? _CmrColors.orangeSoft : _CmrColors.greenSoft2,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: hasWarnings ? _CmrColors.orange.withOpacity(.22) : _CmrColors.green.withOpacity(.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: hasWarnings ? _CmrColors.orange.withOpacity(.18) : _CmrColors.green.withOpacity(.18)),
                ),
                child: Icon(
                  hasWarnings ? Icons.warning_amber_rounded : Icons.verified_rounded,
                  color: hasWarnings ? _CmrColors.orange : _CmrColors.graphite2,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Заметки по тестированию', style: _CmrText.section(), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Text(
                      hasWarnings
                          ? 'Игроки, у которых есть слабые показатели и нужна реакция тренера.'
                          : (testsCount > 0 ? 'Критичных проблем по последним тестам не найдено.' : 'Данные тестирования пока не загружены.'),
                      style: _CmrText.muted(11),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (onOpenTesting != null) ...[
                const SizedBox(width: 8),
                _TeamSmallRoundButton(text: 'Открыть', onTap: onOpenTesting),
              ],
            ],
          ),
          if (hasWarnings) ...[
            const SizedBox(height: 10),
            ...warnings.take(3).map((warning) => _TeamWarningTile(warning: warning, onTap: onOpenTesting)),
          ],
        ],
      ),
    );
  }
}

class _TeamWarningTile extends StatelessWidget {
  final _TeamPlayerWarning warning;
  final VoidCallback? onTap;

  const _TeamWarningTile({required this.warning, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final critical = warning.severity == 'critical';
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: critical ? _CmrColors.orange.withOpacity(.22) : _CmrColors.divider),
            ),
            child: Row(
              children: [
                _TeamSmallAvatar(url: warning.photo, name: warning.playerName, size: 34),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(warning.playerName, style: _CmrText.value(12.6), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text('${warning.title} · ${warning.message}', style: _CmrText.subtle(10.5), maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.chevron_right_rounded, color: critical ? _CmrColors.orange : _CmrColors.subtle, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TeamCompactFeedBlock extends StatelessWidget {
  final IconData icon;
  final String title;
  final String emptyTitle;
  final List<Map<String, dynamic>> items;
  final VoidCallback? onTap;

  const _TeamCompactFeedBlock({
    required this.icon,
    required this.title,
    required this.emptyTitle,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: _CmrColors.soft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _CmrColors.divider.withOpacity(0.0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _CmrColors.graphite2, size: 17),
              const SizedBox(width: 7),
              Expanded(child: Text(title, style: _CmrText.value(12.8), maxLines: 1, overflow: TextOverflow.ellipsis)),
              if (onTap != null)
                InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(999),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
                    child: Text('Открыть', style: _CmrText.action().copyWith(fontSize: 10.5)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 9),
          if (items.isEmpty)
            _TeamInlineEmptyState(text: emptyTitle)
          else
            ...items.take(3).map((item) => _TeamFeedTile(item: item, onTap: onTap)),
        ],
      ),
    );
  }
}

class _TeamFeedTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback? onTap;

  const _TeamFeedTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final title = _itemTitle(item);
    final meta = _teamDateText(item);
    final subtitle = _s(item['description'] ?? item['body'] ?? item['text'] ?? item['comment'] ?? item['place'] ?? item['location']);
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _CmrColors.divider.withOpacity(0.0)),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _CmrColors.green,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: _CmrText.value(11.8), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(
                        subtitle.isEmpty ? meta : '$meta · $subtitle',
                        style: _CmrText.subtle(9.8),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TeamPlayersPreviewBlock extends StatelessWidget {
  final List<Map<String, dynamic>> players;
  final int fallbackCount;
  final VoidCallback? onOpenRoster;

  const _TeamPlayersPreviewBlock({
    required this.players,
    required this.fallbackCount,
    required this.onOpenRoster,
  });

  @override
  Widget build(BuildContext context) {
    final count = players.isNotEmpty ? players.length : fallbackCount;
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: _CmrColors.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _CmrColors.divider.withOpacity(0.0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Игроки команды', style: _CmrText.section(), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(
                  count == 0 ? 'Состав пока не заполнен' : '$count игроков в рабочей группе',
                  style: _CmrText.muted(11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (players.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 42,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: players.take(8).length,
                      separatorBuilder: (_, __) => const SizedBox(width: 7),
                      itemBuilder: (context, index) {
                        final player = players[index];
                        return _TeamSmallAvatar(url: _playerPhoto(player), name: _playerName(player), size: 38);
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          _TeamMiniButton(icon: Icons.groups_2_rounded, text: 'Состав', onTap: onOpenRoster),
        ],
      ),
    );
  }
}

class _TeamSmallAvatar extends StatelessWidget {
  final String url;
  final String name;
  final double size;

  const _TeamSmallAvatar({required this.url, required this.name, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _CmrColors.greenSoft,
        borderRadius: BorderRadius.circular(size * .38),
        border: Border.all(color: _CmrColors.green.withOpacity(.16)),
      ),
      clipBehavior: Clip.antiAlias,
      child: url.isEmpty
          ? Center(child: Text(_initials(name), style: _CmrText.value(size * .26).copyWith(color: _CmrColors.graphite2)))
          : Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) {
              return Center(child: Text(_initials(name), style: _CmrText.value(size * .26).copyWith(color: _CmrColors.graphite2)));
            }),
    );
  }
}

class _TeamSmallRoundButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;

  const _TeamSmallRoundButton({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _CmrColors.graphite,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}

class _TeamInlineEmptyState extends StatelessWidget {
  final String text;
  const _TeamInlineEmptyState({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _CmrColors.divider.withOpacity(0.0)),
      ),
      child: Text(text, style: _CmrText.subtle(10.5), textAlign: TextAlign.center),
    );
  }
}

int _itemTeamId(Map<String, dynamic> item) => _intFromAny(
      item['team_id'] ??
          item['teamId'] ??
          item['team'] ??
          item['club_team_id'] ??
          item['owner_team_id'],
    );

int _playerId(Map<String, dynamic> player) => _intFromAny(
      player['id'] ?? player['player_id'] ?? player['playerId'] ?? player['athlete_id'] ?? player['student_id'],
    );

String _playerName(Map<String, dynamic> player) {
  final full = _s(player['full_name'] ?? player['fullName'] ?? player['player_name'] ?? player['playerName'] ?? player['fio'] ?? player['name']);
  if (full.isNotEmpty) return full;
  final last = _s(player['last_name'] ?? player['lastName'] ?? player['surname']);
  final first = _s(player['first_name'] ?? player['firstName']);
  final name = [last, first].where((e) => e.trim().isNotEmpty).join(' ').trim();
  return name.isEmpty ? 'Игрок' : name;
}

String _playerPhoto(Map<String, dynamic> player) => _normalizeImage(
      _s(player['photo'] ?? player['photo_url'] ?? player['avatar'] ?? player['avatar_url'] ?? player['image'] ?? player['image_url']),
    );

String _itemTitle(Map<String, dynamic> item) {
  final text = _s(item['title'] ?? item['name'] ?? item['event_title'] ?? item['training_title'] ?? item['plan_title'] ?? item['caption']);
  return text.isEmpty ? 'Запись команды' : text;
}

DateTime? _dateOf(Map<String, dynamic> item) {
  final raw = _s(item['date'] ?? item['event_date'] ?? item['training_date'] ?? item['start_date'] ?? item['start_at'] ?? item['startAt'] ?? item['start'] ?? item['match_date'] ?? item['created_at']);
  if (raw.isEmpty) return null;
  return DateTime.tryParse(raw.replaceAll(' ', 'T'));
}

String _teamDateText(Map<String, dynamic> item) {
  final raw = _s(item['date'] ?? item['event_date'] ?? item['training_date'] ?? item['start_date'] ?? item['start_at'] ?? item['startAt'] ?? item['start'] ?? item['match_date'] ?? item['created_at']);
  if (raw.isEmpty) return 'Дата не указана';
  final parsed = DateTime.tryParse(raw.replaceAll(' ', 'T'));
  if (parsed == null) return raw.length > 16 ? raw.substring(0, 16) : raw;
  final d = parsed.day.toString().padLeft(2, '0');
  final m = parsed.month.toString().padLeft(2, '0');
  final hh = parsed.hour.toString().padLeft(2, '0');
  final mm = parsed.minute.toString().padLeft(2, '0');
  final hasTime = parsed.hour != 0 || parsed.minute != 0;
  return hasTime ? '$d.$m • $hh:$mm' : '$d.$m.${parsed.year}';
}


String _testingDateIso(Map<String, dynamic> item) {
  final raw = _s(item['test_date'] ?? item['testing_date'] ?? item['session_date'] ?? item['date'] ?? item['created_at'] ?? item['updated_at']);
  if (raw.isEmpty) return '';
  final parsed = DateTime.tryParse(raw.replaceAll(' ', 'T'));
  if (parsed == null) return raw.length >= 10 ? raw.substring(0, 10) : raw;
  return _dateIso(parsed);
}

String _dateIso(DateTime date) {
  final d = date.day.toString().padLeft(2, '0');
  final m = date.month.toString().padLeft(2, '0');
  return '${date.year}-$m-$d';
}

bool _isWithinLastTwoWeeks(String iso) {
  final parsed = DateTime.tryParse(iso.replaceAll(' ', 'T'));
  if (parsed == null) return true;
  final today = DateTime.now();
  final start = DateTime(today.year, today.month, today.day).subtract(const Duration(days: 14));
  final end = DateTime(today.year, today.month, today.day).add(const Duration(days: 1));
  return !parsed.isBefore(start) && parsed.isBefore(end);
}

String _dateHuman(String iso) {
  final parsed = DateTime.tryParse(iso.replaceAll(' ', 'T'));
  if (parsed == null) return iso.isEmpty ? 'дата не указана' : iso;
  final d = parsed.day.toString().padLeft(2, '0');
  final m = parsed.month.toString().padLeft(2, '0');
  return '$d.$m.${parsed.year}';
}

String _testingStageFromTeamName(String teamName) {
  final t = teamName.toUpperCase().replaceAll(' ', '');
  final direct = RegExp(r'U-?([0-9]{1,2})').firstMatch(t);
  if (direct != null) {
    final n = int.tryParse(direct.group(1) ?? '');
    if (n != null && n >= 6 && n <= 17) return 'U$n';
  }
  final age = RegExp(r'(^|[^0-9])([6-9]|1[0-7])([^0-9]|$)').firstMatch(t);
  if (age != null) {
    final n = int.tryParse(age.group(2) ?? '');
    if (n != null && n >= 6 && n <= 17) return 'U$n';
  }
  return 'U13';
}

String _testingCategoryTitle(String code) {
  switch (code) {
    case 'physical':
      return 'Физическая подготовка';
    case 'technical':
      return 'Техническая подготовка';
    case 'tactical':
      return 'Тактическая подготовка';
    case 'functional':
    case 'medical':
      return 'Функциональное состояние';
    default:
      return 'Тестирование';
  }
}

bool _looksBadStatus(String raw) {
  final t = raw.toLowerCase();
  return t.contains('poor') ||
      t.contains('bad') ||
      t.contains('low') ||
      t.contains('weak') ||
      t.contains('critical') ||
      t.contains('неуд') ||
      t.contains('плох') ||
      t.contains('слаб') ||
      t.contains('ниже') ||
      t.contains('крит');
}

double? _doubleFromAny(dynamic raw) {
  final text = _s(raw).replaceAll(',', '.').replaceAll(RegExp(r'[^0-9.\-]'), '');
  if (text.isEmpty || text == '-' || text == '.') return null;
  return double.tryParse(text);
}

class _TeamCompletionData {
  final String title;
  final bool done;
  final String emptyText;

  const _TeamCompletionData({required this.title, required this.done, required this.emptyText});
}

class _TeamCompletionBlock extends StatelessWidget {
  final List<_TeamCompletionData> items;
  final VoidCallback? onOpenRoster;
  final VoidCallback? onOpenTrainers;
  final VoidCallback onOpenTeam;

  const _TeamCompletionBlock({
    required this.items,
    required this.onOpenRoster,
    required this.onOpenTrainers,
    required this.onOpenTeam,
  });

  @override
  Widget build(BuildContext context) {
    final done = items.where((item) => item.done).length;
    final percent = items.isEmpty ? 0.0 : done / items.length;
    final missing = items.where((item) => !item.done).map((item) => item.emptyText).take(3).join(' • ');

    return _TeamPremiumBlock(
      icon: Icons.fact_check_rounded,
      title: 'Готовность карточки',
      actionText: 'Дополнить',
      onAction: onOpenTeam,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('${(percent * 100).round()}%', style: _CmrText.title(24)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  missing.isEmpty ? 'Паспорт команды выглядит заполненным' : missing,
                  style: _CmrText.muted(11.5),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 7,
              value: percent,
              backgroundColor: _CmrColors.soft2,
              valueColor: const AlwaysStoppedAnimation<Color>(_CmrColors.green),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items
                .map((item) => _TeamCompletionChip(title: item.title, done: item.done))
                .toList(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _TeamMiniButton(
                  icon: Icons.groups_2_rounded,
                  text: 'Состав',
                  onTap: onOpenRoster,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _TeamMiniButton(
                  icon: Icons.badge_rounded,
                  text: 'Тренеры',
                  onTap: onOpenTrainers,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TeamCompletionChip extends StatelessWidget {
  final String title;
  final bool done;

  const _TeamCompletionChip({required this.title, required this.done});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: done ? _CmrColors.greenSoft2 : _CmrColors.soft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: done ? _CmrColors.green.withOpacity(.25) : _CmrColors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(done ? Icons.check_rounded : Icons.add_rounded, color: done ? _CmrColors.graphite2 : _CmrColors.muted, size: 14),
          const SizedBox(width: 6),
          Text(title, style: _CmrText.action().copyWith(fontSize: 10.5)),
        ],
      ),
    );
  }
}

class _TeamMiniButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  const _TeamMiniButton({required this.icon, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _CmrColors.panel,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _CmrColors.divider.withOpacity(0.0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: _CmrColors.graphite2, size: 16),
              const SizedBox(width: 7),
              Text(text, style: _CmrText.action(), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeamPremiumBlock extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? actionText;
  final VoidCallback? onAction;
  final Widget child;

  const _TeamPremiumBlock({
    required this.icon,
    required this.title,
    required this.child,
    this.actionText,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _CmrColors.panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _CmrColors.divider.withOpacity(0.0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.022),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _CmrColors.soft,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: _CmrColors.divider.withOpacity(0.0)),
                ),
                child: Icon(icon, color: _CmrColors.graphite2, size: 17),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title, style: _CmrText.section(), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              if (actionText != null && onAction != null)
                InkWell(
                  onTap: onAction,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                    decoration: BoxDecoration(
                      color: _CmrColors.soft,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: _CmrColors.divider.withOpacity(0.0)),
                    ),
                    child: Text(actionText ?? '', style: _CmrText.action().copyWith(fontSize: 10.5)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

String _teamSport(Map<String, dynamic> team) {
  final value = _s(team['sport'] ?? team['sport_name'] ?? team['sportName'] ?? team['category']);
  return value.isEmpty ? 'Футбол' : value;
}

String _teamLongDescription(Map<String, dynamic> team) {
  return _s(team['description'] ?? team['about'] ?? team['team_description'] ?? team['teamDescription'] ?? team['info']);
}

String _teamSeason(Map<String, dynamic> team) {
  final value = _s(team['season'] ?? team['season_title'] ?? team['seasonTitle'] ?? team['year'] ?? team['period']);
  return value.isEmpty ? 'Не указан' : value;
}

String _teamCity(Map<String, dynamic> team) {
  final value = _s(team['city'] ?? team['location'] ?? team['region'] ?? team['stadium'] ?? team['base']);
  return value.isEmpty ? 'Не указана' : value;
}

String _teamCoach(Map<String, dynamic> team) {
  final value = _s(team['head_coach'] ?? team['headCoach'] ?? team['coach'] ?? team['trainer_name'] ?? team['trainerName']);
  return value.isEmpty ? 'Не назначен' : value;
}

String _teamStatus(Map<String, dynamic> team) {
  final explicit = _s(team['status'] ?? team['team_status'] ?? team['state']);
  if (explicit.isNotEmpty) return explicit;
  final activeRaw = _s(team['is_active'] ?? team['active'] ?? team['enabled']).toLowerCase();
  if (activeRaw == '1' || activeRaw == 'true' || activeRaw == 'yes') return 'Активна';
  if (activeRaw == '0' || activeRaw == 'false' || activeRaw == 'no') return 'Неактивна';
  return 'Рабочая';
}



class _EmptyTeams extends StatelessWidget {
  final VoidCallback onCreateTeam;
  const _EmptyTeams({required this.onCreateTeam});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: _CmrDecor.panel(),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _IconBadge(icon: Icons.account_tree_rounded, size: 60, iconSize: 28),
          const SizedBox(height: 18),
          Text('Команды ещё не добавлены', style: _CmrText.title(18), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text('Создайте первую команду клуба, чтобы перейти к составу, матчам, календарю и рабочим модулям.', style: _CmrText.muted(12.5), textAlign: TextAlign.center),
          const SizedBox(height: 18),
          _ActionButton(icon: Icons.add_rounded, text: 'Создать команду', onTap: onCreateTeam),
        ],
      ),
    );
  }
}

class _NoFilteredTeams extends StatelessWidget {
  final VoidCallback onReset;
  const _NoFilteredTeams({required this.onReset});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: _CmrDecor.panel(),
      padding: const EdgeInsets.all(18),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _IconBadge(icon: Icons.search_off_rounded, size: 52, iconSize: 25),
          const SizedBox(height: 14),
          Text('По фильтрам ничего нет', style: _CmrText.section()),
          const SizedBox(height: 8),
          Text('Очистите поиск или верните фильтр «Все».', style: _CmrText.subtle(11), textAlign: TextAlign.center),
          const SizedBox(height: 14),
          _ActionButton(icon: Icons.restart_alt_rounded, text: 'Сбросить', onTap: onReset),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final bool mobile;

  const _SearchField({required this.controller, required this.mobile});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: mobile ? 40 : 42,
      decoration: _CmrDecor.softCard(radius: mobile ? 16 : 18),
      padding: EdgeInsets.symmetric(horizontal: mobile ? 10 : 12),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: _CmrColors.muted, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Поиск по команде, спорту или возрасту',
                border: InputBorder.none,
                isDense: true,
              ),
              style: _CmrText.value(mobile ? 12.2 : 12.8),
            ),
          ),
          if (controller.text.trim().isNotEmpty)
            InkWell(
              borderRadius: BorderRadius.circular(99),
              onTap: controller.clear,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close_rounded, color: _CmrColors.muted, size: 18),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool dense;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: EdgeInsets.symmetric(
            horizontal: dense ? 10 : 12,
            vertical: dense ? 6 : 7,
          ),
          decoration: BoxDecoration(
            color: selected ? _CmrColors.panel : _CmrColors.soft,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? _CmrColors.graphite : _CmrColors.divider,
              width: selected ? 1.1 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: _CmrColors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected ? _CmrColors.text : _CmrColors.muted,
                  fontSize: dense ? 11 : 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  const _ActionButton({required this.icon, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _CmrColors.graphite,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _CmrColors.graphite),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: _CmrColors.green, size: 17),
              const SizedBox(width: 8),
              Text(
                text,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
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
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: _CmrColors.panel,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _CmrColors.divider.withOpacity(0.0)),
        ),
        child: Icon(icon, color: _CmrColors.text, size: 18),
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  final IconData icon;
  final double size;
  final double iconSize;
  const _IconBadge({required this.icon, this.size = 48, this.iconSize = 22});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _CmrColors.panel,
        borderRadius: BorderRadius.circular(size * .28),
        border: Border.all(color: _CmrColors.divider.withOpacity(0.0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Icon(icon, color: _CmrColors.green, size: iconSize),
    );
  }
}

class _TeamLogo extends StatelessWidget {
  final String url;
  final String name;
  final double size;
  final bool active;
  const _TeamLogo({required this.url, required this.name, required this.size, required this.active});

  @override
  Widget build(BuildContext context) {
    final image = url.isNotEmpty ? NetworkImage(url) : null;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _CmrColors.panel,
        borderRadius: BorderRadius.circular(size * .3),
        border: Border.all(
          color: active ? _CmrColors.green.withOpacity(0.42) : _CmrColors.divider,
          width: active ? 1.2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: image == null
          ? Center(
              child: Text(
                _initials(name),
                style: TextStyle(color: _CmrColors.text, fontSize: size * .28, fontWeight: FontWeight.w700),
              ),
            )
          : Image(
              image: image,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Center(
                child: Text(
                  _initials(name),
                  style: TextStyle(color: _CmrColors.text, fontSize: size * .28, fontWeight: FontWeight.w700),
                ),
              ),
            ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final bool compact;
  const _Metric({required this.label, required this.value, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: _CmrDecor.softCard(radius: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: _CmrText.caption(), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(value, style: _CmrText.value(compact ? 12 : 16), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _BigMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _BigMetric({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    // Компактная метрика без ощущения широкого баннера.
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: 92,
        maxWidth: 118,
        minHeight: 38,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
        decoration: BoxDecoration(
          color: _CmrColors.panel,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: _CmrColors.divider.withOpacity(0.0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: _CmrColors.soft,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: _CmrColors.divider.withOpacity(0.0)),
              ),
              child: Icon(icon, color: _CmrColors.graphite2, size: 11.5),
            ),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 150),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: _CmrText.caption().copyWith(fontSize: 8.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 1),
                  Text(value, style: _CmrText.value(11.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String text;
  const _InfoCard({required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: _CmrDecor.softCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: _CmrText.section()),
          const SizedBox(height: 8),
          Text(text, style: _CmrText.subtle(11)),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: _CmrDecor.softCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: _CmrText.section()),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}


class _DetailAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  const _DetailAction({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Короткое действие вместо широкого баннера.
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 108, maxWidth: 142, minHeight: 38),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
          decoration: BoxDecoration(
            color: _CmrColors.panel,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: _CmrColors.divider.withOpacity(0.0)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              Container(
                width: 21,
                height: 21,
                decoration: BoxDecoration(
                  color: _CmrColors.soft,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: _CmrColors.divider.withOpacity(0.0)),
                ),
                child: Icon(icon, color: _CmrColors.graphite2, size: 12),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: _CmrText.value(10.7), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 1),
                    Text(subtitle, style: _CmrText.subtle(8.8), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 2),
              const Icon(Icons.chevron_right_rounded, color: _CmrColors.muted, size: 13),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Pill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: _CmrColors.panel,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _CmrColors.divider.withOpacity(0.0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: _CmrColors.green,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Icon(icon, color: _CmrColors.text, size: 14),
          const SizedBox(width: 6),
          Text(text, style: _CmrText.action(), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _MiniEmpty extends StatelessWidget {
  final String text;
  const _MiniEmpty({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(text, style: _CmrText.subtle(11), textAlign: TextAlign.center));
  }
}

int _teamPlayersCount(Map<String, dynamic> team) {
  final fromKeys = _countFromMap(team, const [
    'players_count',
    'playersCount',
    'player_count',
    'playerCount',
    'members_count',
    'membersCount',
    'roster_count',
    'rosterCount',
  ]);
  if (fromKeys > 0) return fromKeys;

  final list = team['players'] ?? team['members'] ?? team['roster'];
  if (list is List) return list.length;

  return 0;
}

int _teamTrainersCount(Map<String, dynamic> team) {
  final fromKeys = _countFromMap(team, const [
    'trainers_count',
    'trainersCount',
    'trainer_count',
    'trainerCount',
    'coaches_count',
    'coachesCount',
    'staff_count',
    'staffCount',
  ]);
  if (fromKeys > 0) return fromKeys;

  final list = team['trainers'] ?? team['coaches'] ?? team['staff'];
  if (list is List) return _uniquePeopleCount(List<Map<String, dynamic>>.from(
    list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
  ));

  return 0;
}

int _countFromMap(dynamic source, List<String> keys) {
  if (source is! Map) return 0;
  for (final key in keys) {
    final value = source[key];
    final parsed = _intFromAny(value);
    if (parsed > 0) return parsed;
  }
  return 0;
}

List<Map<String, dynamic>> _extractList(dynamic data, List<String> keys) {
  if (data is List) {
    return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  if (data is Map) {
    for (final key in keys) {
      final value = data[key];
      if (value is List) {
        return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
      if (value is Map) {
        final nested = _extractList(value, keys);
        if (nested.isNotEmpty) return nested;
      }
    }
  }

  return [];
}

int _uniquePeopleCount(List<Map<String, dynamic>> list) {
  final seen = <String>{};
  for (final item in list) {
    final id = _intFromAny(
      item['trainer_id'] ??
          item['trainerId'] ??
          item['coach_id'] ??
          item['coachId'] ??
          item['user_id'] ??
          item['userId'] ??
          item['id'],
    );
    if (id > 0) {
      seen.add('id:$id');
      continue;
    }

    final email = _s(item['email']).toLowerCase();
    if (email.isNotEmpty) {
      seen.add('email:$email');
      continue;
    }

    final name = [
      _s(item['name']),
      _s(item['full_name']),
      _s(item['first_name']),
      _s(item['last_name']),
    ].where((value) => value.isNotEmpty).join('|').toLowerCase();

    seen.add(name.isEmpty ? 'raw:${seen.length}' : 'name:$name');
  }
  return seen.length;
}

dynamic _tryDecode(String body) {
  final clean = body.trim();
  if (clean.isEmpty) return null;

  try {
    return jsonDecode(clean);
  } catch (_) {
    final start = clean.indexOf('{');
    final end = clean.lastIndexOf('}');
    if (start >= 0 && end > start) {
      try {
        return jsonDecode(clean.substring(start, end + 1));
      } catch (_) {}
    }

    final listStart = clean.indexOf('[');
    final listEnd = clean.lastIndexOf(']');
    if (listStart >= 0 && listEnd > listStart) {
      try {
        return jsonDecode(clean.substring(listStart, listEnd + 1));
      } catch (_) {}
    }
  }

  return null;
}

String _teamName(Map<String, dynamic> team) {
  final value = _s(team['name'] ?? team['team_name'] ?? team['teamName'] ?? team['title']);
  return value.isEmpty ? 'Команда' : value;
}

String _teamSubtitle(Map<String, dynamic> team) {
  final value = _s(team['age_group'] ?? team['ageGroup'] ?? team['category'] ?? team['sport'] ?? team['stage']);
  return value.isEmpty ? 'Футбол' : value;
}

String _teamLogo(Map<String, dynamic> team) {
  return _normalizeImage(_s(team['logo'] ?? team['logo_url'] ?? team['team_logo'] ?? team['photo'] ?? team['avatar']));
}

int _teamId(Map<String, dynamic> team) => _intFromAny(team['id'] ?? team['team_id'] ?? team['teamId'] ?? team['teamID']);

int _intFromAny(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.round();
  return int.tryParse('$value'.trim()) ?? 0;
}

String _s(dynamic value) {
  if (value == null) return '';
  final text = '$value'.trim();
  return text == 'null' ? '' : text;
}

String _normalizeImage(String value) {
  final v = value.trim();
  if (v.isEmpty || v == 'null') return '';
  if (v.startsWith('http://') || v.startsWith('https://')) return v;
  if (v.startsWith('/')) return 'https://sportotekaapp.ru$v';
  return 'https://sportotekaapp.ru/$v';
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return 'К';
  if (parts.length == 1) return parts.first.characters.take(2).toString().toUpperCase();
  return '${parts.first.characters.first}${parts.last.characters.first}'.toUpperCase();
}
