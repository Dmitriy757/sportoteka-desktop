// lib/presentation/player_screen/player_dashboard_screen.dart
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/routes/app_routes.dart';
import 'package:sportoteka/presentation/team_roster_screen/team_roster_screen.dart';
import 'package:sportoteka/presentation/team_calendar_screen/player_team_calendar_screen.dart';
import 'package:sportoteka/presentation/player_game_zone/team_rating_screen.dart';
import 'package:sportoteka/presentation/player_game_zone/player_challenges_screen.dart';
import 'package:sportoteka/presentation/player_game_zone/player_battles_screen.dart';
import 'package:sportoteka/presentation/player_game_zone/player_quizzes_screen.dart';
import 'package:sportoteka/presentation/player_game_zone/player_match_games_screen.dart';
import 'package:sportoteka/presentation/player_game_zone/player_highlights_screen.dart';
import 'package:sportoteka/presentation/tracker/player/player_my_trainings_screen.dart';

enum PlayerWorkspaceSection {
  home,
  roster,
  calendar,
  matches,
  trainings,
  selfAssessment,
  rating,
  challenges,
  battles,
  quizzes,
  miniGames,
  highlights,
  chat,
}

class PlayerDashboardScreen extends StatefulWidget {
  final int teamId;
  final String teamName;
  final int userId;
  final String? teamLogo;

  const PlayerDashboardScreen({
    super.key,
    required this.teamId,
    required this.teamName,
    required this.userId,
    this.teamLogo,
  });

  @override
  State<PlayerDashboardScreen> createState() => _PlayerDashboardScreenState();
}

class _PlayerDashboardScreenState extends State<PlayerDashboardScreen> {
  static const String apiBase = 'https://sportotekaapp.ru/api';
  static const String getTeamProfileUrl = '$apiBase/get_team_profile.php';
  static const String getGameZoneSummaryUrl = '$apiBase/get_game_zone_summary.php';

  late String teamName;
  String teamCategory = '';
  String? teamLogoUrl;

  bool profileLoading = false;
  String? profileError;

  bool summaryLoading = true;
  Map<String, dynamic>? summary;
  String? summaryError;

  PlayerWorkspaceSection selectedSection = PlayerWorkspaceSection.home;

  late final List<_PlayerNavGroup> _navGroups = [
    _PlayerNavGroup('Команда', [
      _PlayerNavItem(
        PlayerWorkspaceSection.home,
        Icons.dashboard_customize_rounded,
        'Главная',
        'Кабинет игрока',
      ),
      _PlayerNavItem(
        PlayerWorkspaceSection.roster,
        Icons.groups_2_rounded,
        'Состав',
        'Игроки и профили команды',
      ),
      _PlayerNavItem(
        PlayerWorkspaceSection.calendar,
        Icons.calendar_month_rounded,
        'Календарь',
        'Тренировки, матчи и события',
      ),
      _PlayerNavItem(
        PlayerWorkspaceSection.matches,
        Icons.sports_soccer_rounded,
        'Матчи',
        'Игры команды и личный анализ',
      ),
      _PlayerNavItem(
        PlayerWorkspaceSection.chat,
        Icons.forum_rounded,
        'Чат',
        'Командное общение',
      ),
    ]),
    _PlayerNavGroup('Личное развитие', [
      _PlayerNavItem(
        PlayerWorkspaceSection.trainings,
        Icons.fitness_center_rounded,
        'Мои тренировки',
        'Нагрузка, прогресс и отчёты',
      ),
      _PlayerNavItem(
        PlayerWorkspaceSection.selfAssessment,
        Icons.rate_review_rounded,
        'Самооценка',
        'Оценка тренировки и заметка',
      ),
    ]),
    _PlayerNavGroup('Игровая зона', [
      _PlayerNavItem(
        PlayerWorkspaceSection.rating,
        Icons.emoji_events_rounded,
        'Рейтинг',
        'Очки и место в команде',
      ),
      _PlayerNavItem(
        PlayerWorkspaceSection.challenges,
        Icons.flag_rounded,
        'Челленджи',
        'Ежедневные и недельные задания',
      ),
      _PlayerNavItem(
        PlayerWorkspaceSection.battles,
        Icons.local_fire_department_rounded,
        'Битвы игроков',
        'Соревнования 1 на 1',
      ),
      _PlayerNavItem(
        PlayerWorkspaceSection.quizzes,
        Icons.quiz_rounded,
        'Квизы',
        'Футбольные вопросы и очки',
      ),
      _PlayerNavItem(
        PlayerWorkspaceSection.miniGames,
        Icons.sports_score_rounded,
        'Мини-игры',
        'Прогнозы по матчам',
      ),
      _PlayerNavItem(
        PlayerWorkspaceSection.highlights,
        Icons.ondemand_video_rounded,
        'Моменты',
        'Голы, передачи и видео',
      ),
    ]),
  ];

  List<_PlayerNavItem> get _allItems => [
        for (final group in _navGroups) ...group.items,
      ];

  List<_PlayerNavItem> get _dockItems => [
        _itemFor(PlayerWorkspaceSection.home),
        _itemFor(PlayerWorkspaceSection.roster),
        _itemFor(PlayerWorkspaceSection.matches),
        _itemFor(PlayerWorkspaceSection.calendar),
        _itemFor(PlayerWorkspaceSection.trainings),
        _itemFor(PlayerWorkspaceSection.chat),
      ];

  @override
  void initState() {
    super.initState();
    teamName = widget.teamName.trim().isNotEmpty
        ? widget.teamName.trim()
        : 'Команда #${widget.teamId}';
    teamLogoUrl = _bust(_normalizePhoto(widget.teamLogo));
    _initialLoad();
  }

  Future<void> _initialLoad() async {
    await Future.wait([
      _loadTeamProfileSilent(),
      _loadGameZoneSummary(),
    ]);
  }

  Map<String, dynamic> _decode(http.Response resp) {
    try {
      final body = resp.body.trim();
      if (body.isEmpty) return {'success': false, 'message': 'EMPTY_BODY'};

      final j = json.decode(body);
      if (j is Map<String, dynamic>) return j;
      if (j is Map) return Map<String, dynamic>.from(j);

      return {'success': false, 'message': 'INVALID_JSON_FORMAT'};
    } catch (_) {
      return {'success': false, 'message': 'JSON_DECODE_ERROR'};
    }
  }

  String _asStr(dynamic v) => (v ?? '').toString();

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  String? _normalizePhoto(String? raw) {
    if (raw == null) return null;
    var s = raw.trim();
    if (s.isEmpty || s == 'null') return null;
    s = s.replaceAll('\\', '/').replaceAll('\\/', '/').trim();
    if (s.startsWith('http://sportotekaapp.ru/') ||
        s.startsWith('http://www.sportotekaapp.ru/')) {
      s = s.replaceFirst('http://', 'https://');
    }
    if (s.startsWith('http://') || s.startsWith('https://')) return s;
    while (s.startsWith('../')) {
      s = s.substring(3);
    }
    while (s.startsWith('./')) {
      s = s.substring(2);
    }
    if (s.startsWith('uploads/')) return 'https://sportotekaapp.ru/$s';
    if (!s.startsWith('/')) s = '/$s';
    return 'https://sportotekaapp.ru$s';
  }

  String? _bust(String? url) {
    if (url == null || url.trim().isEmpty) return null;
    final sep = url.contains('?') ? '&' : '?';
    return '$url${sep}v=${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<void> _loadTeamProfileSilent() async {
    if (!mounted) return;
    setState(() {
      profileLoading = true;
      profileError = null;
    });

    try {
      final resp = await http
          .post(
            Uri.parse(getTeamProfileUrl),
            body: {'team_id': widget.teamId.toString()},
          )
          .timeout(const Duration(seconds: 10));

      final data = _decode(resp);
      final ok = (data['success'] == true) || (data['status'] == 'success');

      Map<String, dynamic>? team;
      if (data['team'] is Map) {
        team = Map<String, dynamic>.from(data['team']);
      } else if (data['data'] is Map) {
        team = Map<String, dynamic>.from(data['data']);
      } else if (data.isNotEmpty) {
        team = data;
      }

      if (!mounted) return;

      if (ok && team != null) {
        final serverName = _asStr(team['team_name'] ?? team['name'] ?? team['title']).trim();
        final serverCategory = _asStr(
          team['category'] ?? team['sport_type'] ?? team['sport'] ?? team['type'],
        ).trim();
        final serverLogo = _bust(_normalizePhoto(_asStr(
          team['team_logo'] ??
              team['logo'] ??
              team['logo_url'] ??
              team['image'] ??
              team['photo'],
        )));

        setState(() {
          if (serverName.isNotEmpty) teamName = serverName;
          if (serverCategory.isNotEmpty) teamCategory = serverCategory;
          if (serverLogo != null && serverLogo.isNotEmpty) teamLogoUrl = serverLogo;
          profileLoading = false;
        });
      } else {
        setState(() {
          profileLoading = false;
          profileError = _asStr(data['message']).trim().isEmpty
              ? 'Не удалось загрузить профиль'
              : _asStr(data['message']).trim();
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        profileLoading = false;
        profileError = 'Сетевая ошибка';
      });
    }
  }

  Future<void> _loadGameZoneSummary() async {
    if (!mounted) return;
    setState(() {
      summaryLoading = true;
      summaryError = null;
    });

    try {
      final resp = await http
          .post(
            Uri.parse(getGameZoneSummaryUrl),
            body: {
              'team_id': widget.teamId.toString(),
              'user_id': widget.userId.toString(),
            },
          )
          .timeout(const Duration(seconds: 12));

      final data = _decode(resp);
      if (!mounted) return;

      if (data['success'] == true) {
        setState(() {
          summary = data;
          summaryLoading = false;
        });
      } else {
        setState(() {
          summaryLoading = false;
          summaryError = _asStr(data['message']).trim().isEmpty
              ? 'Не удалось загрузить игровую зону'
              : _asStr(data['message']).trim();
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        summaryLoading = false;
        summaryError = 'Сетевая ошибка';
      });
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _loadTeamProfileSilent(),
      _loadGameZoneSummary(),
    ]);
  }

  bool _isProfessionalLayout(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return size.width >= 700;
  }

  ThemeData _workspaceTheme(BuildContext context) {
    final base = Theme.of(context);
    return base.copyWith(
      scaffoldBackgroundColor: _P.bg,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      colorScheme: base.colorScheme.copyWith(
        primary: _P.primaryGreen,
        secondary: _P.blue,
        surface: _P.card,
      ),
      textTheme: base.textTheme.apply(
        fontFamily: _P.fontFamily,
        bodyColor: _P.text,
        displayColor: _P.text,
      ),
      primaryTextTheme: base.primaryTextTheme.apply(
        fontFamily: _P.fontFamily,
        bodyColor: _P.text,
        displayColor: _P.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final child = _isProfessionalLayout(context)
        ? _buildProfessionalWorkspace()
        : _buildMobileWorkspace();

    return Theme(
      data: _workspaceTheme(context),
      child: child,
    );
  }

  Widget _buildProfessionalWorkspace() {
    return Scaffold(
      backgroundColor: _P.bg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final sidePadding = constraints.maxWidth >= 1100 ? 12.0 : 8.0;
            final contentPadding = EdgeInsets.fromLTRB(
              sidePadding,
              8,
              sidePadding,
              88,
            );

            return Stack(
              children: [
                Positioned.fill(
                  child: _PlayerWorkspaceWallpaper(
                    teamName: teamName,
                    teamLogo: teamLogoUrl,
                  ),
                ),
                Positioned.fill(
                  child: Padding(
                    padding: contentPadding,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeOutCubic,
                      child: _buildContent(key: ValueKey(selectedSection.name)),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 14,
                  child: _PlayerWorkspaceTaskbar(
                    teamName: teamName,
                    teamLogo: teamLogoUrl,
                    selectedSection: selectedSection,
                    items: _dockItems,
                    onStart: _openFullModulesMenu,
                    onSearch: _openCommandMenu,
                    onSelect: _selectSection,
                    onHome: () => _selectSection(PlayerWorkspaceSection.home),
                    onRefresh: _refreshAll,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMobileWorkspace() {
    return Scaffold(
      backgroundColor: _P.bg,
      extendBody: true,
      body: SafeArea(
        top: true,
        bottom: false,
        child: Stack(
          children: [
            Positioned.fill(
              child: _PlayerWorkspaceWallpaper(
                teamName: teamName,
                teamLogo: teamLogoUrl,
                compact: true,
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(2, 4, 2, 82),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeOutCubic,
                  child: _buildContent(key: ValueKey('mobile-${selectedSection.name}')),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildMobileBottomNav(),
    );
  }

  Widget _buildContent({Key? key}) {
    return RefreshIndicator(
      key: key,
      onRefresh: _refreshAll,
      color: _P.primaryGreen,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          _buildTopBar(),
          const SizedBox(height: 12),
          if (selectedSection == PlayerWorkspaceSection.home) ...[
            _buildHeroPanel(),
            const SizedBox(height: 12),
            _buildGameZoneSummaryCard(),
            const SizedBox(height: 12),
            _buildModuleSection(
              title: 'Команда',
              items: _navGroups[0].items.where((e) => e.section != PlayerWorkspaceSection.home).toList(),
            ),
            const SizedBox(height: 12),
            _buildModuleSection(
              title: 'Личное развитие',
              items: _navGroups[1].items,
            ),
            const SizedBox(height: 12),
            _buildModuleSection(
              title: 'Игровая зона',
              items: _navGroups[2].items,
            ),
          ] else ...[
            _buildSectionLanding(selectedSection),
          ],
          const SizedBox(height: 22),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    final item = _itemFor(selectedSection);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
      decoration: _cardDecoration(radius: 16),
      child: Row(
        children: [
          _BackCircleButton(onTap: _handleBack),
          const SizedBox(width: 10),
          _TeamLogoAvatar(
            logoUrl: teamLogoUrl,
            size: 38,
            radius: 12,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _P.title(15.5),
                ),
                const SizedBox(height: 2),
                Text(
                  '$teamName${teamCategory.isNotEmpty ? ' • $teamCategory' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _P.subtle(11),
                ),
              ],
            ),
          ),
          _TopActionButton(
            icon: Icons.search_rounded,
            tooltip: 'Поиск',
            onTap: _openCommandMenu,
          ),
          const SizedBox(width: 6),
          _TopActionButton(
            icon: Icons.view_agenda_rounded,
            tooltip: 'Все модули',
            onTap: _openFullModulesMenu,
          ),
          const SizedBox(width: 6),
          _TopActionButton(
            icon: Icons.refresh_rounded,
            tooltip: 'Обновить',
            onTap: _refreshAll,
          ),
        ],
      ),
    );
  }

  void _handleBack() {
    if (selectedSection != PlayerWorkspaceSection.home) {
      setState(() => selectedSection = PlayerWorkspaceSection.home);
      return;
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Get.back();
    }
  }

  Widget _buildHeroPanel() {
    final width = MediaQuery.of(context).size.width;
    final compact = width < 980;
    final myRank = summary?['my_rank']?.toString() ?? '0';
    final myPoints = summary?['my_points']?.toString() ?? '0';
    final streak = summary?['streak_days']?.toString() ?? '0';

    return Container(
      padding: EdgeInsets.all(compact ? 10 : 12),
      decoration: _cardDecoration(radius: 16),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _heroIdentity(compact: true),
                const SizedBox(height: 14),
                _heroStats(myRank: myRank, myPoints: myPoints, streak: streak),
              ],
            )
          : Row(
              children: [
                Expanded(child: _heroIdentity(compact: false)),
                const SizedBox(width: 18),
                SizedBox(
                  width: math.min(390.0, width * .34),
                  child: _heroStats(myRank: myRank, myPoints: myPoints, streak: streak),
                ),
              ],
            ),
    );
  }

  Widget _heroIdentity({required bool compact}) {
    return Row(
      children: [
        _TeamLogoAvatar(
          logoUrl: teamLogoUrl,
          size: compact ? 48 : 54,
          radius: compact ? 14 : 16,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _P.panel,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: _P.divider.withOpacity(0.0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person_rounded, size: 14, color: _P.primaryGreen),
                    const SizedBox(width: 6),
                    Text(
                      profileLoading
                          ? 'Кабинет игрока • обновление'
                          : profileError != null
                              ? 'Кабинет игрока • offline'
                              : 'Кабинет игрока',
                      style: const TextStyle(
                        color: _P.primaryGreen,
                        fontSize: 10.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 9),
              Text(
                teamName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _P.text,
                  fontSize: compact ? 17 : 19,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.18,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                teamCategory.isNotEmpty ? teamCategory : 'Команда игрока',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _P.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _SmallActionChip(
                    icon: Icons.fitness_center_rounded,
                    label: 'Мои тренировки',
                    onTap: () => _selectSection(PlayerWorkspaceSection.trainings),
                  ),
                  _SmallActionChip(
                    icon: Icons.sports_soccer_rounded,
                    label: 'Матчи',
                    onTap: () => _selectSection(PlayerWorkspaceSection.matches),
                  ),
                  _SmallActionChip(
                    icon: Icons.emoji_events_rounded,
                    label: 'Рейтинг',
                    onTap: () => _selectSection(PlayerWorkspaceSection.rating),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _heroStats({
    required String myRank,
    required String myPoints,
    required String streak,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _P.soft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _P.divider, width: .7),
      ),
      child: Row(
        children: [
          Expanded(child: _statPill('Место', '#$myRank', Icons.leaderboard_rounded)),
          const SizedBox(width: 8),
          Expanded(child: _statPill('Очки', myPoints, Icons.stars_rounded)),
          const SizedBox(width: 8),
          Expanded(child: _statPill('Серия', '$streak дн.', Icons.bolt_rounded)),
        ],
      ),
    );
  }

  Widget _statPill(String title, String value, IconData icon) {
    final compact = MediaQuery.of(context).size.width < 980;
    return Container(
      constraints: BoxConstraints(minHeight: compact ? 46 : 50),
      padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 7, vertical: compact ? 6 : 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _P.divider.withOpacity(.78), width: .7),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: _P.primaryGreen, size: compact ? 14 : 15),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _P.text,
              fontSize: compact ? 13.2 : 14.2,
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _P.muted,
              fontSize: compact ? 9.2 : 9.6,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameZoneSummaryCard() {
    if (summaryLoading) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(radius: 16),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(10),
            child: CircularProgressIndicator(color: _P.primaryGreen),
          ),
        ),
      );
    }

    if (summaryError != null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: _cardDecoration(radius: 16),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: _P.red, size: 19),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                summaryError!,
                style: _P.subtle(11.2).copyWith(color: _P.text),
              ),
            ),
            _TopActionButton(
              icon: Icons.refresh_rounded,
              tooltip: 'Обновить',
              onTap: _loadGameZoneSummary,
            ),
          ],
        ),
      );
    }

    final challenge = _asMap(summary?['challenge_of_day']);
    final quiz = _asMap(summary?['quiz_of_day']);
    final battle = _asMap(summary?['battle_preview']);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _P.greenSoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _P.primaryGreen.withOpacity(.18), width: .7),
                ),
                child: const Icon(Icons.sports_esports_rounded, color: _P.primaryGreen, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Игровая зона', style: _P.title(14.6), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Text(
                      'Задания, очки и активность команды',
                      style: _P.subtle(10.8),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (challenge != null) ...[
            const SizedBox(height: 10),
            _summaryTile(
              icon: Icons.flag_rounded,
              title: 'Челлендж дня',
              subtitle: challenge['title']?.toString() ?? '',
              buttonText: 'Открыть',
              onTap: () => _selectSection(PlayerWorkspaceSection.challenges),
            ),
          ],
          if (quiz != null) ...[
            const SizedBox(height: 8),
            _summaryTile(
              icon: Icons.quiz_rounded,
              title: 'Квиз дня',
              subtitle: quiz['title']?.toString() ?? '',
              buttonText: 'Пройти',
              onTap: () => _selectSection(PlayerWorkspaceSection.quizzes),
            ),
          ],
          if (battle != null) ...[
            const SizedBox(height: 8),
            _summaryTile(
              icon: Icons.local_fire_department_rounded,
              title: 'Ближайшая битва',
              subtitle: battle['title']?.toString() ?? '',
              buttonText: 'Смотреть',
              onTap: () => _selectSection(PlayerWorkspaceSection.battles),
            ),
          ],
          if (challenge == null && quiz == null && battle == null) ...[
            const SizedBox(height: 10),
            _summaryTile(
              icon: Icons.emoji_events_rounded,
              title: 'Рейтинг команды',
              subtitle: 'Открой игровую зону и посмотри текущие очки.',
              buttonText: 'Смотреть',
              onTap: () => _selectSection(PlayerWorkspaceSection.rating),
            ),
          ],
        ],
      ),
    );
  }

  Widget _summaryTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String buttonText,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: _P.soft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _P.divider.withOpacity(.78), width: .85),
      ),
      child: Row(
        children: [
          Icon(icon, color: _P.primaryGreen, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _P.caption(), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(
                  subtitle.isEmpty ? 'Доступно в игровой зоне' : subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _P.title(12.2),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              foregroundColor: _P.primaryGreen,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(buttonText, style: _P.action().copyWith(color: _P.primaryGreen)),
          ),
        ],
      ),
    );
  }

  Widget _buildModuleSection({
    required String title,
    required List<_PlayerNavItem> items,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: _cardDecoration(radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(title: title, right: '${items.length}'),
          const SizedBox(height: 10),
          _ModuleList(
            items: items,
            currentSection: selectedSection,
            onSelect: _selectSection,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLanding(PlayerWorkspaceSection section) {
    final width = MediaQuery.of(context).size.width;
    final compact = width < 980;
    final item = _itemFor(section);
    final accent = _P.accentForSection(section);
    final quickItems = _relatedItemsFor(section);

    return Container(
      padding: EdgeInsets.all(compact ? 10 : 12),
      decoration: _cardDecoration(radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: compact ? 40 : 44,
                height: compact ? 40 : 44,
                decoration: BoxDecoration(
                  color: accent.withOpacity(.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, color: accent, size: compact ? 20 : 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _P.text,
                        fontSize: compact ? 16 : 17,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _P.muted,
                        fontSize: compact ? 10.8 : 11.2,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _sectionPreview(section),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _openRealModule(section),
                  icon: const Icon(Icons.open_in_new_rounded, size: 18),
                  label: Text(_primaryButtonText(section)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _P.text,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: Size.fromHeight(compact ? 44 : 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (quickItems.isNotEmpty) ...[
            const SizedBox(height: 18),
            _SectionHeader(title: 'Рядом', right: '${quickItems.length}'),
            const SizedBox(height: 10),
            _ModuleList(
              items: quickItems,
              currentSection: selectedSection,
              onSelect: _selectSection,
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionPreview(PlayerWorkspaceSection section) {
    final compact = MediaQuery.of(context).size.width < 980;
    if (section == PlayerWorkspaceSection.rating ||
        section == PlayerWorkspaceSection.challenges ||
        section == PlayerWorkspaceSection.battles ||
        section == PlayerWorkspaceSection.quizzes ||
        section == PlayerWorkspaceSection.miniGames ||
        section == PlayerWorkspaceSection.highlights) {
      return _buildGameZoneSummaryCard();
    }

    final chips = <String>[];
    switch (section) {
      case PlayerWorkspaceSection.roster:
        chips.addAll(['состав', 'профили', 'номера']);
        break;
      case PlayerWorkspaceSection.calendar:
        chips.addAll(['тренировки', 'матчи', 'события']);
        break;
      case PlayerWorkspaceSection.matches:
        chips.addAll(['матчи', 'анализ', 'статистика']);
        break;
      case PlayerWorkspaceSection.trainings:
        chips.addAll(['нагрузка', 'прогресс', 'отчёты']);
        break;
      case PlayerWorkspaceSection.selfAssessment:
        chips.addAll(['оценка', 'самочувствие', 'заметка']);
        break;
      case PlayerWorkspaceSection.chat:
        chips.addAll(['команда', 'сообщения', 'обсуждения']);
        break;
      default:
        chips.addAll(['модуль', 'команда', 'спортотека']);
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: BoxDecoration(
        color: _P.soft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _P.divider, width: .7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _previewText(section),
            style: TextStyle(
              color: _P.text,
              fontSize: compact ? 11.5 : 12,
              height: 1.28,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final chip in chips)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: _P.borderSoft),
                  ),
                  child: Text(
                    chip,
                    style: _P.action().copyWith(color: _P.muted),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _previewText(PlayerWorkspaceSection section) {
    switch (section) {
      case PlayerWorkspaceSection.roster:
        return 'Смотри состав команды, номера игроков и карточки профилей. Для игрока это безопасный просмотр без клубного управления.';
      case PlayerWorkspaceSection.calendar:
        return 'Открой расписание команды: тренировки, игры и мероприятия. Удобно проверять ближайшие занятия прямо из кабинета игрока.';
      case PlayerWorkspaceSection.matches:
        return 'Матчи команды и личный анализ игрока. Если роль не игрок, приложение автоматически откроет клубный экран матчей.';
      case PlayerWorkspaceSection.trainings:
        return 'Личные тренировки, динамика нагрузки и прогресс. Этот пункт ведёт в игроковый экран трекера.';
      case PlayerWorkspaceSection.selfAssessment:
        return 'Игрок может быстро оценить тренировку, самочувствие и оставить заметку для тренера.';
      case PlayerWorkspaceSection.chat:
        return 'Командный чат оставлен в меню в таком же стиле, как в Club Workspace. Подключение реального экрана можно сделать следующим шагом.';
      default:
        return 'Модуль игровой зоны открывается из такого же workspace-меню, но с пользовательскими правами и пользовательскими данными.';
    }
  }

  String _primaryButtonText(PlayerWorkspaceSection section) {
    switch (section) {
      case PlayerWorkspaceSection.roster:
        return 'Открыть состав';
      case PlayerWorkspaceSection.calendar:
        return 'Открыть календарь';
      case PlayerWorkspaceSection.matches:
        return 'Открыть матчи';
      case PlayerWorkspaceSection.trainings:
        return 'Открыть тренировки';
      case PlayerWorkspaceSection.selfAssessment:
        return 'Открыть самооценку';
      case PlayerWorkspaceSection.chat:
        return 'Открыть чат';
      case PlayerWorkspaceSection.rating:
        return 'Открыть рейтинг';
      case PlayerWorkspaceSection.challenges:
        return 'Открыть челленджи';
      case PlayerWorkspaceSection.battles:
        return 'Открыть битвы';
      case PlayerWorkspaceSection.quizzes:
        return 'Открыть квизы';
      case PlayerWorkspaceSection.miniGames:
        return 'Открыть мини-игры';
      case PlayerWorkspaceSection.highlights:
        return 'Открыть моменты';
      case PlayerWorkspaceSection.home:
        return 'На главную';
    }
  }

  List<_PlayerNavItem> _relatedItemsFor(PlayerWorkspaceSection section) {
    if (section == PlayerWorkspaceSection.roster ||
        section == PlayerWorkspaceSection.calendar ||
        section == PlayerWorkspaceSection.matches ||
        section == PlayerWorkspaceSection.chat) {
      return _navGroups[0].items
          .where((item) => item.section != PlayerWorkspaceSection.home && item.section != section)
          .take(4)
          .toList();
    }
    if (section == PlayerWorkspaceSection.trainings || section == PlayerWorkspaceSection.selfAssessment) {
      return _navGroups[1].items.where((item) => item.section != section).toList();
    }
    return _navGroups[2].items.where((item) => item.section != section).take(4).toList();
  }

  Widget _buildMobileBottomNav() {
    final bottom = MediaQuery.of(context).padding.bottom;
    final width = MediaQuery.of(context).size.width;
    final horizontal = width < 380 ? 14.0 : 22.0;
    final activeIndex = _mobileBottomMenuIndex();
    final bottomInset = bottom > 0 ? math.max(12.0, math.min(16.0, bottom * .45)) : 10.0;

    Widget dockIcon({
      required int index,
      required IconData icon,
      required VoidCallback onTap,
      int badge = 0,
    }) {
      final active = activeIndex == index;
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 170),
              curve: Curves.easeOutCubic,
              width: active ? 44 : 34,
              height: 36,
              decoration: BoxDecoration(
                color: active ? _P.greenSoft : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Icon(
                    icon,
                    size: active ? 22 : 21,
                    color: active ? _P.primaryGreen : _P.muted,
                  ),
                  if (badge > 0)
                    Positioned(
                      top: 1,
                      right: active ? 6 : 0,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF0050),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white, width: 1.6),
                        ),
                        child: Center(
                          child: Text(
                            badge > 99 ? '99+' : '$badge',
                            style: const TextStyle(
                              fontSize: 8.5,
                              height: 1,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Material(
      type: MaterialType.transparency,
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(horizontal, 0, horizontal, bottomInset),
          child: Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 7),
            decoration: BoxDecoration(
              color: _P.panel,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _P.divider.withOpacity(.78), width: .85),
              boxShadow: _P.cardShadow,
            ),
            child: Row(
              children: [
                dockIcon(index: 0, icon: Icons.home_rounded, onTap: () => _selectSection(PlayerWorkspaceSection.home)),
                dockIcon(index: 1, icon: Icons.groups_2_outlined, onTap: () => _selectSection(PlayerWorkspaceSection.roster)),
                dockIcon(index: 2, icon: Icons.sports_soccer_outlined, onTap: () => _selectSection(PlayerWorkspaceSection.matches)),
                dockIcon(index: 3, icon: Icons.calendar_month_outlined, onTap: () => _selectSection(PlayerWorkspaceSection.calendar)),
                dockIcon(index: 4, icon: Icons.near_me_outlined, badge: 1, onTap: () => _selectSection(PlayerWorkspaceSection.chat)),
                dockIcon(index: 5, icon: Icons.more_horiz_rounded, onTap: _openMobileMoreMenu),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int _mobileBottomMenuIndex() {
    if (selectedSection == PlayerWorkspaceSection.home) return 0;
    if (selectedSection == PlayerWorkspaceSection.roster) return 1;
    if (selectedSection == PlayerWorkspaceSection.matches) return 2;
    if (selectedSection == PlayerWorkspaceSection.calendar) return 3;
    if (selectedSection == PlayerWorkspaceSection.chat) return 4;
    return 5;
  }

  void _selectSection(PlayerWorkspaceSection section) {
    if (!mounted) return;
    setState(() => selectedSection = section);
  }

  _PlayerNavItem _itemFor(PlayerWorkspaceSection section) {
    for (final item in _allItems) {
      if (item.section == section) return item;
    }
    return _PlayerNavItem(section, Icons.widgets_rounded, 'Модуль', 'Кабинет игрока');
  }

  void _openFullModulesMenu() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _PlayerMoreBottomSheet(
          title: 'Меню игрока',
          teamName: teamName,
          teamLogo: teamLogoUrl,
          currentSection: selectedSection,
          groups: _navGroups,
          onSelect: (section) {
            Navigator.of(sheetContext).pop();
            _selectSection(section);
          },
        );
      },
    );
  }

  void _openMobileMoreMenu() => _openFullModulesMenu();

  void _openCommandMenu() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _PlayerCommandSheet(
          teamName: teamName,
          items: _allItems,
          currentSection: selectedSection,
          onSelect: (section) {
            Navigator.of(sheetContext).pop();
            _selectSection(section);
          },
        );
      },
    );
  }

  Future<void> _openRealModule(PlayerWorkspaceSection section) async {
    switch (section) {
      case PlayerWorkspaceSection.home:
        _selectSection(PlayerWorkspaceSection.home);
        return;
      case PlayerWorkspaceSection.roster:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TeamRosterScreen(
              teamId: widget.teamId,
              teamName: teamName,
            ),
          ),
        );
        return;
      case PlayerWorkspaceSection.calendar:
        Get.to(
          () => PlayerTeamCalendarScreen(
            teamId: widget.teamId,
            teamName: teamName,
          ),
        );
        return;
      case PlayerWorkspaceSection.matches:
        await _openMatches();
        return;
      case PlayerWorkspaceSection.trainings:
        Get.to(
          () => PlayerMyTrainingsScreen(
            teamId: widget.teamId,
            teamName: teamName,
            userId: widget.userId,
            playerId: widget.userId,
          ),
        );
        return;
      case PlayerWorkspaceSection.selfAssessment:
        Get.toNamed(
          AppRoutes.playerSelfAssessmentScreen,
          arguments: {
            'team_id': widget.teamId,
            'user_id': widget.userId,
            'team_name': teamName,
          },
        );
        return;
      case PlayerWorkspaceSection.rating:
        Get.to(
          () => const TeamRatingScreen(),
          arguments: {
            'team_id': widget.teamId,
            'user_id': widget.userId,
            'team_name': teamName,
          },
        );
        return;
      case PlayerWorkspaceSection.challenges:
        Get.to(
          () => const PlayerChallengesScreen(),
          arguments: {
            'team_id': widget.teamId,
            'user_id': widget.userId,
            'team_name': teamName,
          },
        );
        return;
      case PlayerWorkspaceSection.battles:
        Get.to(
          () => const PlayerBattlesScreen(),
          arguments: {
            'team_id': widget.teamId,
            'user_id': widget.userId,
            'team_name': teamName,
          },
        );
        return;
      case PlayerWorkspaceSection.quizzes:
        Get.to(
          () => const PlayerQuizzesScreen(),
          arguments: {
            'team_id': widget.teamId,
            'user_id': widget.userId,
            'team_name': teamName,
          },
        );
        return;
      case PlayerWorkspaceSection.miniGames:
        Get.to(
          () => const PlayerMatchGamesScreen(),
          arguments: {
            'team_id': widget.teamId,
            'user_id': widget.userId,
            'team_name': teamName,
          },
        );
        return;
      case PlayerWorkspaceSection.highlights:
        Get.to(
          () => const PlayerHighlightsScreen(),
          arguments: {
            'team_id': widget.teamId,
            'user_id': widget.userId,
            'team_name': teamName,
          },
        );
        return;
      case PlayerWorkspaceSection.chat:
        Get.snackbar('Чат', 'Командный чат подключим следующим этапом');
        return;
    }
  }

  Future<void> _openMatches() async {
    final userId = await PrefUtils.getUserId();

    if (userId == null) {
      Get.snackbar('Ошибка', 'Пользователь не найден');
      return;
    }

    try {
      final res = await http
          .get(Uri.parse('https://sportotekaapp.ru/api/get_user.php?user_id=$userId'))
          .timeout(const Duration(seconds: 10));
      final data = jsonDecode(res.body);
      final role = (data['user']?['role'] ?? '').toString().toLowerCase();

      if (role == 'player') {
        Get.toNamed(
          AppRoutes.playerMatchesScreen,
          arguments: {
            'teamId': widget.teamId,
            'teamName': teamName,
          },
        );
      } else {
        Get.toNamed(
          AppRoutes.teamMatchesScreen,
          arguments: {
            'teamId': widget.teamId,
            'teamName': teamName,
          },
        );
      }
    } catch (_) {
      Get.snackbar('Ошибка', 'Не удалось определить роль');
    }
  }

  BoxDecoration _cardDecoration({double radius = 16}) {
    final r = math.min(radius, 18.0);
    return BoxDecoration(
      color: _P.panel,
      borderRadius: BorderRadius.circular(r),
      border: Border.all(color: _P.divider.withOpacity(.78), width: .85),
      boxShadow: _P.cardShadow,
    );
  }

  BoxDecoration _gradientDecoration() {
    return BoxDecoration(
      color: _P.panel,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _P.divider.withOpacity(.78), width: .85),
      boxShadow: _P.cardShadow,
    );
  }
}
class _P {
  static const String fontFamily = 'Segoe UI';
  static const List<String> fontFallback = <String>[
    'SF Pro Display',
    'SF Pro Text',
    'Inter',
    'Roboto',
    'Arial',
  ];

  static const Color bg = Color(0xFFF3F5F7);
  static const Color panel = Colors.white;
  static const Color card = Colors.white;
  static const Color soft = Color(0xFFFAFCFD);
  static const Color soft2 = Color(0xFFF3F5F7);
  static const Color text = Color(0xFF0B0F14);
  static const Color muted = Color(0xFF374151);
  static const Color subtleColor = Color(0xFF6B7280);
  static const Color lightMuted = Color(0xFF6B7280);
  static const Color divider = Color(0xFFE8EDF2);
  static const Color border = Color(0xFFE8EDF2);
  static const Color borderSoft = Color(0xFFE8EDF2);
  static const Color primaryGreen = Color(0xFF00A750);
  static const Color greenSoft = Color(0xFFF1FBF6);
  static const Color greenDark = Color(0xFF067A46);
  static const Color blue = Color(0xFF2563EB);
  static const Color blueSoft = Color(0xFFF4F7FF);
  static const Color purple = Color(0xFF7C3AED);
  static const Color purpleSoft = Color(0xFFF5F0FF);
  static const Color orange = Color(0xFFEA580C);
  static const Color orangeSoft = Color(0xFFFFF7ED);
  static const Color teal = Color(0xFF06B6D4);
  static const Color tealSoft = Color(0xFFEFFBFF);
  static const Color red = Color(0xFFDC2626);
  static const Color redSoft = Color(0xFFFEF2F2);

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(.015),
          blurRadius: 16,
          spreadRadius: -11,
          offset: const Offset(0, 9),
        ),
      ];

  static TextStyle title(double size) => TextStyle(
        color: text,
        fontFamily: fontFamily,
        fontFamilyFallback: fontFallback,
        fontSize: size,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.18,
        height: 1.08,
      );

  static TextStyle section() => const TextStyle(
        color: text,
        fontFamily: fontFamily,
        fontFamilyFallback: fontFallback,
        fontSize: 11.2,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.08,
        height: 1.12,
      );

  static TextStyle value(double size) => TextStyle(
        color: text,
        fontFamily: fontFamily,
        fontFamilyFallback: fontFallback,
        fontSize: size,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.12,
        fontFeatures: const [FontFeature.tabularFigures()],
        height: 1.08,
      );

  static TextStyle mutedText(double size) => TextStyle(
        color: subtleColor,
        fontFamily: fontFamily,
        fontFamilyFallback: fontFallback,
        fontSize: size,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.02,
        height: 1.28,
      );

  static TextStyle subtle(double size) => TextStyle(
        color: subtleColor,
        fontFamily: fontFamily,
        fontFamilyFallback: fontFallback,
        fontSize: size,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.02,
        height: 1.24,
      );

  static TextStyle caption() => const TextStyle(
        color: subtleColor,
        fontFamily: fontFamily,
        fontFamilyFallback: fontFallback,
        fontSize: 9.2,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.02,
        height: 1.08,
      );

  static TextStyle action() => const TextStyle(
        color: text,
        fontFamily: fontFamily,
        fontFamilyFallback: fontFallback,
        fontSize: 10.4,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.02,
        height: 1.08,
      );

  static Color accentForSection(PlayerWorkspaceSection section) {
    switch (section) {
      case PlayerWorkspaceSection.home:
      case PlayerWorkspaceSection.rating:
      case PlayerWorkspaceSection.challenges:
      case PlayerWorkspaceSection.battles:
      case PlayerWorkspaceSection.quizzes:
      case PlayerWorkspaceSection.miniGames:
      case PlayerWorkspaceSection.highlights:
        return primaryGreen;
      case PlayerWorkspaceSection.roster:
        return blue;
      case PlayerWorkspaceSection.calendar:
        return teal;
      case PlayerWorkspaceSection.matches:
        return orange;
      case PlayerWorkspaceSection.trainings:
      case PlayerWorkspaceSection.selfAssessment:
        return purple;
      case PlayerWorkspaceSection.chat:
        return muted;
    }
  }

  static Color softFor(Color color) {
    if (color == blue) return blueSoft;
    if (color == purple) return purpleSoft;
    if (color == orange) return orangeSoft;
    if (color == teal) return tealSoft;
    if (color == red) return redSoft;
    if (color == primaryGreen) return greenSoft;
    return soft;
  }
}

class _PlayerNavGroup {
  final String title;
  final List<_PlayerNavItem> items;

  const _PlayerNavGroup(this.title, this.items);
}

class _PlayerNavItem {
  final PlayerWorkspaceSection section;
  final IconData icon;
  final String title;
  final String subtitle;

  const _PlayerNavItem(this.section, this.icon, this.title, this.subtitle);
}

class _PlayerWorkspaceWallpaper extends StatelessWidget {
  final String teamName;
  final String? teamLogo;
  final bool compact;

  const _PlayerWorkspaceWallpaper({
    required this.teamName,
    required this.teamLogo,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(color: _P.bg),
    );
  }
}

class _PlayerWallpaperPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(.22)
      ..strokeWidth = 1;

    const step = 42.0;
    for (double x = 0; x < size.width + step; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x - size.height * .45, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TeamLogoAvatar extends StatelessWidget {
  final String? logoUrl;
  final double size;
  final double radius;

  const _TeamLogoAvatar({
    required this.logoUrl,
    required this.size,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _P.panel,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: _P.divider.withOpacity(.78), width: .85),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(math.max(0.0, radius - 2)),
        child: (logoUrl != null && logoUrl!.isNotEmpty)
            ? Image.network(
                logoUrl!,
                key: ValueKey(logoUrl),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallback(),
              )
            : _fallback(),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      color: _P.primaryGreen.withOpacity(.10),
      child: const Icon(
        Icons.sports_soccer_rounded,
        color: _P.primaryGreen,
        size: 30,
      ),
    );
  }
}

class _BackCircleButton extends StatelessWidget {
  final VoidCallback onTap;

  const _BackCircleButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _P.divider, width: .7),
          ),
          child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: _P.text),
        ),
      ),
    );
  }
}

class _TopActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _TopActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _P.soft,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _P.divider, width: .7),
          ),
          child: Icon(icon, color: _P.muted, size: 17),
        ),
      ),
    );
  }
}

class _SmallActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SmallActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: _P.panel,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _P.divider.withOpacity(.78), width: .85),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: _P.primaryGreen),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10.4,
                fontWeight: FontWeight.w600,
                color: _P.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String right;

  const _SectionHeader({required this.title, required this.right});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title.toUpperCase(),
            style: _P.caption().copyWith(letterSpacing: .22, fontWeight: FontWeight.w600),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _P.panel,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _P.divider.withOpacity(0.0)),
          ),
          child: Text(
            right,
            style: const TextStyle(
              color: _P.text,
              fontSize: 10.8,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _ModuleList extends StatelessWidget {
  final List<_PlayerNavItem> items;
  final PlayerWorkspaceSection currentSection;
  final ValueChanged<PlayerWorkspaceSection> onSelect;

  const _ModuleList({
    required this.items,
    required this.currentSection,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 980;
        return Column(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              _ModuleListTile(
                item: items[i],
                active: items[i].section == currentSection,
                compact: compact,
                onTap: () => onSelect(items[i].section),
              ),
              if (i != items.length - 1) SizedBox(height: compact ? 6 : 8),
            ],
          ],
        );
      },
    );
  }
}

class _ModuleListTile extends StatelessWidget {
  final _PlayerNavItem item;
  final bool active;
  final bool compact;
  final VoidCallback onTap;

  const _ModuleListTile({
    required this.item,
    required this.active,
    required this.compact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _P.accentForSection(item.section);
    final radius = compact ? 18.0 : 12.0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 2 : 4, vertical: compact ? 3 : 4),
      child: Material(
        color: active ? _P.greenSoft : _P.panel,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: Container(
            constraints: BoxConstraints(minHeight: compact ? 62 : 64),
            padding: EdgeInsets.symmetric(horizontal: compact ? 9 : 11, vertical: compact ? 8 : 9),
            decoration: BoxDecoration(
              color: active ? _P.greenSoft : _P.panel,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: active ? _P.primaryGreen.withOpacity(.22) : _P.divider.withOpacity(.78),
                width: .85,
              ),
              boxShadow: _P.cardShadow,
            ),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: compact ? 38 : 40,
                  decoration: BoxDecoration(
                    color: active ? _P.primaryGreen : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: compact ? 38 : 40,
                  height: compact ? 38 : 40,
                  decoration: BoxDecoration(
                    color: active ? _P.panel : _P.soft,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _P.divider.withOpacity(.78), width: .7),
                  ),
                  child: Icon(item.icon, color: active ? _P.primaryGreen : accent, size: compact ? 18 : 19),
                ),
                SizedBox(width: compact ? 9 : 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _P.title(compact ? 13.2 : 13.8),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _P.mutedText(compact ? 10.4 : 10.8),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  active ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
                  color: active ? _P.primaryGreen : _P.lightMuted,
                  size: compact ? 18 : 19,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayerWorkspaceTaskbar extends StatelessWidget {
  final String teamName;
  final String? teamLogo;
  final PlayerWorkspaceSection selectedSection;
  final List<_PlayerNavItem> items;
  final VoidCallback onStart;
  final VoidCallback onSearch;
  final ValueChanged<PlayerWorkspaceSection> onSelect;
  final VoidCallback onHome;
  final VoidCallback onRefresh;

  const _PlayerWorkspaceTaskbar({
    required this.teamName,
    required this.teamLogo,
    required this.selectedSection,
    required this.items,
    required this.onStart,
    required this.onSearch,
    required this.onSelect,
    required this.onHome,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final compact = width < 1120;
    final veryCompact = width < 900;
    final maxWidth = math.min(1040.0, math.max(360.0, width - 32));

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          height: veryCompact ? 58 : 62,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          padding: EdgeInsets.symmetric(horizontal: compact ? 7 : 10, vertical: 7),
          decoration: BoxDecoration(
            color: _P.panel,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _P.divider.withOpacity(.78), width: .85),
            boxShadow: _P.cardShadow,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _TaskbarSystemButton(
                icon: Icons.grid_view_rounded,
                tooltip: 'Все модули',
                onTap: onStart,
              ),
              const SizedBox(width: 8),
              _TaskbarSearchButton(compact: veryCompact, onTap: onSearch),
              if (!veryCompact) ...[
                const SizedBox(width: 8),
                _TaskbarDivider(height: 30),
                const SizedBox(width: 7),
              ],
              Flexible(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      for (final item in items) ...[
                        _TaskbarAppButton(
                          item: item,
                          active: item.section == selectedSection,
                          onTap: () => onSelect(item.section),
                        ),
                        const SizedBox(width: 4),
                      ],
                    ],
                  ),
                ),
              ),
              if (!compact) ...[
                const SizedBox(width: 8),
                _TaskbarDivider(height: 30),
                const SizedBox(width: 8),
                _TaskbarTeamPill(
                  teamName: teamName,
                  teamLogo: teamLogo,
                  onTap: onHome,
                ),
              ],
              const SizedBox(width: 8),
              _TaskbarSystemButton(
                icon: Icons.refresh_rounded,
                tooltip: 'Обновить',
                onTap: onRefresh,
              ),
              const SizedBox(width: 6),
              _TaskbarSystemButton(
                icon: Icons.home_rounded,
                tooltip: 'На главную',
                onTap: onHome,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskbarDivider extends StatelessWidget {
  final double height;
  const _TaskbarDivider({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: height, color: _P.borderSoft);
  }
}

class _TaskbarSystemButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _TaskbarSystemButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_TaskbarSystemButton> createState() => _TaskbarSystemButtonState();
}

class _TaskbarSystemButtonState extends State<_TaskbarSystemButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Tooltip(
        message: widget.tooltip,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _hovered ? _P.soft2 : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(widget.icon, color: _P.muted, size: 19),
          ),
        ),
      ),
    );
  }
}

class _TaskbarSearchButton extends StatelessWidget {
  final bool compact;
  final VoidCallback onTap;

  const _TaskbarSearchButton({required this.compact, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        height: 38,
        width: compact ? 38 : 154,
        padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 12),
        decoration: BoxDecoration(
          color: _P.soft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _P.divider.withOpacity(.78), width: .7),
        ),
        child: compact
            ? const Icon(Icons.search_rounded, color: _P.muted, size: 19)
            : const Row(
                children: [
                  Icon(Icons.search_rounded, color: _P.lightMuted, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Поиск',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _P.lightMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _TaskbarAppButton extends StatefulWidget {
  final _PlayerNavItem item;
  final bool active;
  final VoidCallback onTap;

  const _TaskbarAppButton({
    required this.item,
    required this.active,
    required this.onTap,
  });

  @override
  State<_TaskbarAppButton> createState() => _TaskbarAppButtonState();
}

class _TaskbarAppButtonState extends State<_TaskbarAppButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bg = widget.active
        ? _P.greenSoft
        : _hovered
            ? _P.soft2
            : Colors.transparent;
    final accent = _P.accentForSection(widget.item.section);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Tooltip(
        message: widget.item.title,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(17),
          child: SizedBox(
            width: widget.active ? 46 : 40,
            height: 45,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: widget.active ? 46 : 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: widget.active ? _P.primaryGreen.withOpacity(.18) : Colors.transparent,
                    ),
                  ),
                  child: Icon(
                    widget.item.icon,
                    color: widget.active ? _P.primaryGreen : _P.muted,
                    size: 21,
                  ),
                ),
                if (widget.active)
                  Positioned(
                    bottom: 0,
                    child: Container(
                      width: 6,
                      height: 4,
                      decoration: BoxDecoration(
                        color: _P.primaryGreen,
                        borderRadius: BorderRadius.circular(999),
                      ),
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

class _TaskbarTeamPill extends StatelessWidget {
  final String teamName;
  final String? teamLogo;
  final VoidCallback onTap;

  const _TaskbarTeamPill({
    required this.teamName,
    required this.teamLogo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 38,
        constraints: const BoxConstraints(maxWidth: 210),
        padding: const EdgeInsets.fromLTRB(7, 5, 10, 5),
        decoration: BoxDecoration(
          color: _P.soft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _P.divider.withOpacity(.78), width: .7),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TeamLogoAvatar(logoUrl: teamLogo, size: 28, radius: 10),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                teamName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _P.title(12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerMoreBottomSheet extends StatelessWidget {
  final String title;
  final String teamName;
  final String? teamLogo;
  final PlayerWorkspaceSection currentSection;
  final List<_PlayerNavGroup> groups;
  final ValueChanged<PlayerWorkspaceSection> onSelect;

  const _PlayerMoreBottomSheet({
    required this.title,
    required this.teamName,
    required this.teamLogo,
    required this.currentSection,
    required this.groups,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    final bottom = MediaQuery.of(context).padding.bottom;
    final totalItems = groups.fold<int>(0, (sum, group) => sum + group.items.length);

    return Container(
      constraints: BoxConstraints(maxHeight: h * .88),
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      padding: EdgeInsets.fromLTRB(14, 10, 14, 14 + bottom),
      decoration: BoxDecoration(
        color: _P.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _P.divider.withOpacity(.78), width: .85),
        boxShadow: _P.cardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 5,
            decoration: BoxDecoration(
              color: _P.divider,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 12),
          _MobileMoreHeaderCard(
            teamName: teamName,
            teamLogo: teamLogo,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: _P.title(15.5),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _P.panel,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: _P.divider.withOpacity(0.0)),
                ),
                child: Text(
                  '$totalItems',
                  style: const TextStyle(
                    color: _P.text,
                    fontSize: 10.8,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              physics: const BouncingScrollPhysics(),
              children: [
                for (final group in groups) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(2, 10, 2, 6),
                    child: Text(
                      group.title.toUpperCase(),
                      style: _P.caption().copyWith(letterSpacing: .22, fontWeight: FontWeight.w600),
                    ),
                  ),
                  for (final item in group.items)
                    _MobileMoreTile(
                      item: item,
                      active: item.section == currentSection,
                      onTap: () => onSelect(item.section),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileMoreHeaderCard extends StatelessWidget {
  final String teamName;
  final String? teamLogo;

  const _MobileMoreHeaderCard({
    required this.teamName,
    required this.teamLogo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _P.soft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _P.divider.withOpacity(.78), width: .7),
      ),
      child: Row(
        children: [
          _TeamLogoAvatar(logoUrl: teamLogo, size: 44, radius: 15),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Кабинет игрока', style: _P.subtle(10.8)),
                const SizedBox(height: 2),
                Text(
                  teamName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _P.title(13.8),
                ),
              ],
            ),
          ),
          const Icon(Icons.keyboard_arrow_down_rounded, color: _P.lightMuted),
        ],
      ),
    );
  }
}

class _MobileMoreTile extends StatelessWidget {
  final _PlayerNavItem item;
  final bool active;
  final VoidCallback onTap;

  const _MobileMoreTile({
    required this.item,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = active ? _P.primaryGreen : _P.accentForSection(item.section);
    final bgColor = active ? accent.withOpacity(.08) : Colors.transparent;
    final iconBgColor = active ? accent.withOpacity(.12) : _P.soft;
    final iconColor = active ? accent : _P.muted;
    final titleColor = active ? accent : _P.text;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 50),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: active ? accent.withOpacity(.18) : _P.borderSoft),
                  ),
                  child: Icon(item.icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _P.title(13.2).copyWith(color: titleColor),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _P.mutedText(10.8),
                      ),
                    ],
                  ),
                ),
                Icon(
                  active ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
                  color: active ? accent : _P.lightMuted,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayerCommandSheet extends StatefulWidget {
  final String teamName;
  final List<_PlayerNavItem> items;
  final PlayerWorkspaceSection currentSection;
  final ValueChanged<PlayerWorkspaceSection> onSelect;

  const _PlayerCommandSheet({
    required this.teamName,
    required this.items,
    required this.currentSection,
    required this.onSelect,
  });

  @override
  State<_PlayerCommandSheet> createState() => _PlayerCommandSheetState();
}

class _PlayerCommandSheetState extends State<_PlayerCommandSheet> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    final filtered = widget.items.where((item) {
      final q = _query.trim().toLowerCase();
      if (q.isEmpty) return true;
      return item.title.toLowerCase().contains(q) || item.subtitle.toLowerCase().contains(q);
    }).toList();

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: EdgeInsets.fromLTRB(14, 12, 14, 14 + bottom),
      decoration: BoxDecoration(
        color: _P.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _P.divider.withOpacity(.78), width: .85),
        boxShadow: _P.cardShadow,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .76),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: _P.divider,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'Найти модуль игрока',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: _P.soft,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
            const SizedBox(height: 10),
            Flexible(
              child: filtered.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(28),
                      child: Text(
                        'Ничего не найдено',
                        style: TextStyle(color: _P.muted, fontWeight: FontWeight.w700),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const BouncingScrollPhysics(),
                      itemCount: filtered.length,
                      itemBuilder: (_, index) {
                        final item = filtered[index];
                        return _MobileMoreTile(
                          item: item,
                          active: item.section == widget.currentSection,
                          onTap: () => widget.onSelect(item.section),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
