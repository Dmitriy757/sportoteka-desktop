// lib/presentation/club_workspace/club_workspace_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'package:sportoteka/core/theme/app_typography.dart';

import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/presentation/chat_screen/chat_screen.dart';
import 'package:sportoteka/presentation/player_game_zone/create_challenge_screen.dart';
import 'package:sportoteka/presentation/player_game_zone/create_quiz_screen.dart';
import 'package:sportoteka/presentation/manager_mode/screens/manager_dashboard_screen.dart';
import 'package:sportoteka/presentation/plans/plan_folders_screen.dart';
import 'package:sportoteka/presentation/team_calendar_screen/team_calendar_screen.dart';
import 'package:sportoteka/presentation/team_description_screen/team_description_screen.dart';
import 'package:sportoteka/presentation/team_matches_screen/team_matches_screen.dart';
import 'package:sportoteka/presentation/team_roster_screen/team_roster_screen.dart';
import 'package:sportoteka/presentation/team_screen/team_dashboard_screen.dart';
import 'package:sportoteka/presentation/team_video_analysis/team_video_analysis_screen.dart';
import 'package:sportoteka/presentation/training_graphics/training_graphics_screen.dart';
import 'package:sportoteka/presentation/video_lessons/video_lessons_screen.dart';
import 'package:sportoteka/routes/app_routes.dart';
import 'package:sportoteka/presentation/player_profile_screen/cmr_player_profile_screen.dart';
import 'package:sportoteka/presentation/my_profile_screen/my_profile_screen.dart';
import 'package:sportoteka/presentation/workspace_hub/workspace_hub_screen.dart';
import 'package:sportoteka/presentation/plans/cmr_plans_panel.dart';
import 'package:sportoteka/presentation/team_calendar_screen/cmr_calendar_panel.dart';
import 'package:sportoteka/presentation/team_video_analysis/cmr_video_analysis_panel.dart';
import 'package:sportoteka/presentation/team_attendance_screen/cmr_attendance_panel.dart';
import 'package:sportoteka/presentation/team_matches_screen/cmr_team_matches_panel.dart';
import 'package:sportoteka/presentation/testing/cmr_testing_panel.dart';
import 'package:sportoteka/presentation/trainer_profile_screen/trainer_cabinet_panel.dart';
import 'package:sportoteka/presentation/trainer_profile_screen/trainer_self_profile_panel.dart';
import 'package:sportoteka/presentation/club_workspace/cmr_club_trainers_panel.dart';
import 'package:sportoteka/presentation/club_workspace/cmr_club_teams_panel.dart';
import 'package:sportoteka/presentation/club_workspace/cmr_club_roster_panel.dart';
import 'package:sportoteka/presentation/club_workspace/cmr_chats_panel.dart';
import 'package:sportoteka/presentation/club_workspace/cmr_game_zone_panel.dart';
import 'package:sportoteka/presentation/club_workspace/cmr_club_overview_panel.dart';
import 'package:sportoteka/presentation/club_workspace/cmr_club_parents_panel.dart';
import 'package:sportoteka/presentation/club_workspace/cmr_medical_cabinet_panel.dart';
import 'package:sportoteka/presentation/club_workspace/cmr_context_ai_layer.dart';
import 'package:sportoteka/presentation/tracker/screens/tracker_match_workspace_screen.dart';
import 'package:sportoteka/presentation/workspace_os/workspace_finder_panel.dart';
import 'package:sportoteka/presentation/workspace_os/workspace_finder_models.dart';

enum ClubSection {
  coachDashboard,
  overview,
  finder,
  teams,
  teamDashboard,
  roster,
  trainers,
  teamTrainers,
  playerProfile,
  matches,
  calendar,
  trainings,
  plans,
  graphics,
  tracker,
  videoAnalysis,
  description,
  chat,
  videoLessons,
  attendance,
  testing,
  challenges,
  challengeCreate,
  quizzes,
  quizCreate,
  rating,
  manager,
  miniGames,
  medical,
  parents,
  settings,
}

enum _WorkspaceDockSize { compact, normal, large }

enum _WorkspaceWallpaperStyle { sportoteka, clean, club, pitch, graphite }

class _WorkspaceWindowState {
  final String id;
  final ClubSection section;
  final String? entityKey;
  final String? titleOverride;
  final String? subtitleOverride;
  final IconData? iconOverride;
  final Map<String, dynamic>? playerPayload;
  Offset position;
  Size size;
  bool minimized;
  bool maximized;
  int zIndex;

  _WorkspaceWindowState({
    required this.id,
    required this.section,
    required this.position,
    required this.size,
    required this.zIndex,
    this.entityKey,
    this.titleOverride,
    this.subtitleOverride,
    this.iconOverride,
    this.playerPayload,
    this.minimized = false,
    this.maximized = false,
  });
}

String _sportotekaWebImageProxy(String url) {
  final clean = url.trim();
  if (clean.isEmpty || clean.startsWith('data:image/')) return clean;

  // Только Flutter Web отправляем через прокси. Мобильные iOS/Android остаются как были.
  if (!kIsWeb || clean.contains('/api/image_proxy.php')) return clean;

  return 'https://sportotekaapp.ru/api/image_proxy.php?url=${Uri.encodeComponent(clean)}';
}

String _normalizeSportotekaMediaUrl(dynamic value) {
  var raw = '${value ?? ''}'.trim();
  if (raw.isEmpty || raw == 'null') return '';

  final lower = raw.toLowerCase();
  if (lower.contains('setstate') ||
      lower.contains('markneedsbuild') ||
      lower.contains('exception') ||
      lower.contains('<html') ||
      lower.contains('<br')) {
    return '';
  }

  raw = raw.replaceAll('\\', '/').replaceAll('\\/', '/').trim();
  raw = raw.replaceAll(' ', '%20');

  if (raw.startsWith('data:image/')) return raw;

  if (raw.startsWith('http://sportotekaapp.ru/') ||
      raw.startsWith('http://www.sportotekaapp.ru/') ||
      raw.startsWith('http://sportoteka.by/') ||
      raw.startsWith('http://www.sportoteka.by/')) {
    raw = raw.replaceFirst('http://', 'https://');
  }

  if (raw.startsWith('https://') || raw.startsWith('http://')) {
    return _sportotekaWebImageProxy(raw);
  }

  while (raw.startsWith('../')) {
    raw = raw.substring(3);
  }
  while (raw.startsWith('./')) {
    raw = raw.substring(2);
  }
  while (raw.startsWith('/')) {
    raw = raw.substring(1);
  }
  if (raw.startsWith('api/')) {
    raw = raw.substring(4);
  }

  if (raw.isEmpty) return '';
  return _sportotekaWebImageProxy('https://sportotekaapp.ru/$raw');
}

String _firstSportotekaMediaUrl(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final normalized = _normalizeSportotekaMediaUrl(map[key]);
    if (normalized.isNotEmpty) return normalized;
  }
  return '';
}

class ClubWorkspaceScreen extends StatefulWidget {
  const ClubWorkspaceScreen({super.key});

  @override
  State<ClubWorkspaceScreen> createState() => _ClubWorkspaceScreenState();
}

class _ClubWorkspaceScreenState extends State<ClubWorkspaceScreen>
    with SingleTickerProviderStateMixin {
  static const String apiBase = 'https://sportotekaapp.ru/api';
  static const String getClubProfileUrl = '$apiBase/get_club_profile.php';
  static const String getMySubscriptionUrl = '$apiBase/get_my_subscription.php';
  static const String getClubTeamsUrl = '$apiBase/get_club_teams.php';
  static const String getClubTrainersUrl = '$apiBase/get_club_trainers.php';
  static const String getTeamTrainersUrl = '$apiBase/get_team_trainers.php';
  static const String getTrainerTeamsUrl = '$apiBase/get_team_by_coach.php';
  static const String getClubEventsUrl = '$apiBase/get_club_events.php';
  static const String getLatestTrainingPlansUrl =
      '$apiBase/get_latest_training_plans.php';
  static const String getPlayersUrl = '$apiBase/get_players.php';
  static const String deletePlayerUrl = '$apiBase/delete_player.php';
  static const String updateClubProfileUrl = '$apiBase/update_club_profile.php';
  static const String updateTeamProfileUrl = '$apiBase/update_team_profile.php';

  int currentUserId = 0;
  int clubId = 0;
  int trainerWorkspaceId = 0;
  String trainerWorkspaceName = '';
  bool trainerAssignedMode = false;
  bool _showOwnTrainerProfile = false;

  bool loading = true;
  bool refreshing = false;
  bool loadingPlayers = false;
  bool panelLoading = false;
  String? error;

  String clubName = 'Клуб';
  String? clubLogo;
  String clubDescription = '';
  bool savingProfile = false;
  bool hasActiveSubscription = false;
  String subscriptionPlanCode = '';

  bool get _isClubBasic =>
      subscriptionPlanCode.trim().toLowerCase() == 'club_basic';

  List<Map<String, dynamic>> teams = [];
  List<Map<String, dynamic>> trainers = [];
  List<Map<String, dynamic>> events = [];
  List<Map<String, dynamic>> latestPlans = [];
  List<Map<String, dynamic>> players = [];

  int? selectedTeamId;
  int? initialTeamId;
  String selectedTeamName = 'Команда не выбрана';
  Map<String, dynamic>? selectedTeam;
  Map<String, dynamic>? selectedPlayer;

  ClubSection selectedSection = ClubSection.teams;

  bool _showDesktopIcons = true;
  _WorkspaceDockSize _workspaceDockSize = _WorkspaceDockSize.normal;
  _WorkspaceWallpaperStyle _workspaceWallpaperStyle =
      _WorkspaceWallpaperStyle.sportoteka;
  final List<_WorkspaceWindowState> _openWorkspaceWindows =
      <_WorkspaceWindowState>[];
  int _workspaceWindowZCounter = 0;
  int _chatPanelRevision = 0;
  int _chatUnreadCount = 0;
  Timer? _chatUnreadTimer;
  bool _openCreateTeamInline = false;
  bool? _contextAiExpanded;
  int _contextAiRevision = 0;

  final Set<ClubSection> _desktopIconSections = <ClubSection>{
    ClubSection.finder,
    ClubSection.teams,
    ClubSection.roster,
    ClubSection.trainers,
    ClubSection.matches,
    ClubSection.calendar,
    ClubSection.plans,
    ClubSection.testing,
    ClubSection.tracker,
    ClubSection.chat,
    ClubSection.parents,
  };

  final Set<ClubSection> _dockSections = <ClubSection>{
    ClubSection.finder,
    ClubSection.teams,
    ClubSection.roster,
    ClubSection.trainers,
    ClubSection.matches,
    ClubSection.calendar,
    ClubSection.plans,
    ClubSection.testing,
    ClubSection.tracker,
    ClubSection.chat,
    ClubSection.parents,
  };

  final Map<ClubSection, Offset> _desktopIconPositions =
      <ClubSection, Offset>{};

  late final AnimationController _introController;
  bool _introStarted = true;
  bool _introFinished = true;
  bool _mobileGestureHintShown = false;

  static const List<ClubSection> _mobileSwipeSections = <ClubSection>[
    ClubSection.teams,
    ClubSection.roster,
    ClubSection.calendar,
    ClubSection.trainers,
    ClubSection.matches,
    ClubSection.plans,
    ClubSection.attendance,
    ClubSection.testing,
    ClubSection.tracker,
    ClubSection.chat,
    ClubSection.parents,
    ClubSection.graphics,
    ClubSection.manager,
  ];

  @override
  void initState() {
    super.initState();

    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2650),
    )..value = 1;

    _introController.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _introFinished = true);
      }
    });

    _boot();
  }

  @override
  void dispose() {
    _chatUnreadTimer?.cancel();
    _introController.dispose();
    super.dispose();
  }

  void _startChatUnreadPolling() {
    _chatUnreadTimer?.cancel();
    unawaited(_refreshChatUnreadCount());
    _chatUnreadTimer = Timer.periodic(
      const Duration(seconds: 6),
      (_) => unawaited(_refreshChatUnreadCount()),
    );
  }

  int _workspaceUnreadFromRows(dynamic raw) {
    if (raw is! List) return 0;
    var total = 0;
    for (final entry in raw.whereType<Map>()) {
      final count = int.tryParse('${entry['unread_count'] ?? 0}') ?? 0;
      if (count > 0) total += count;
    }
    return total;
  }

  bool _workspacePrivateChat(Map<dynamic, dynamic> chat) {
    final type =
        '${chat['type'] ?? chat['chat_type'] ?? ''}'.trim().toLowerCase();
    if (type == 'private' || type == 'personal' || type == 'direct') {
      return true;
    }
    final flag = chat['is_private'];
    return flag == 1 || flag == '1' || flag == true;
  }

  bool _workspaceGroupMember(Map<dynamic, dynamic> group) {
    final flag = group['i_am_member'];
    return flag == null || flag == 1 || flag == '1' || flag == true;
  }

  Future<int> _loadWorkspaceRealUnread(int userId) async {
    var total = 0;

    try {
      final response = await http
          .get(Uri.parse('$apiBase/get_user_chats.php?user_id=$userId'))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final decoded = _decode(response.body);
        if (decoded is List) {
          total += _workspaceUnreadFromRows(
            decoded.whereType<Map>().where(_workspacePrivateChat).toList(),
          );
        }
      }
    } catch (_) {}

    try {
      final response = await http
          .get(Uri.parse('$apiBase/get_groups_feed.php?user_id=$userId'))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final decoded = _decode(response.body);
        if (decoded is Map && decoded['success'] == true) {
          final raw = decoded['groups'];
          if (raw is List) {
            total += _workspaceUnreadFromRows(
              raw.whereType<Map>().where(_workspaceGroupMember).toList(),
            );
          }
        }
      }
    } catch (_) {}

    return total.clamp(0, 9999);
  }

  Future<void> _refreshChatUnreadCount() async {
    final userId = currentUserId > 0 ? currentUserId : clubId;
    if (userId <= 0) {
      if (mounted && _chatUnreadCount != 0) {
        setState(() => _chatUnreadCount = 0);
      }
      return;
    }

    final value = await _loadWorkspaceRealUnread(userId);

    if (!mounted || value == _chatUnreadCount) return;
    setState(() => _chatUnreadCount = value);
  }

  Future<void> _boot() async {
    currentUserId = await PrefUtils.getUserId() ?? 0;
    _startChatUnreadPolling();

    final trainerFirstName = (await PrefUtils.getUserFirstName()).trim();
    final trainerLastName = (await PrefUtils.getUserLastName()).trim();

    trainerWorkspaceName = '$trainerFirstName $trainerLastName'.trim();

    final args = Get.arguments;
    if (args is Map) {
      final mode =
          '${args['mode'] ?? args['workspace_mode'] ?? ''}'.toLowerCase();
      trainerAssignedMode =
          mode == 'trainer_assigned' || mode == 'trainer_workspace';
      trainerWorkspaceId = _asInt(args['trainer_id'] ??
          args['trainerId'] ??
          args['coach_id'] ??
          args['coachId']);
      clubId = _asInt(args['club_id'] ?? args['clubId']);
      final targetTeamId = _asInt(args['initial_team_id'] ??
          args['selected_team_id'] ??
          args['team_id'] ??
          args['teamId']);
      if (targetTeamId > 0) initialTeamId = targetTeamId;
    }

    final pref = PrefUtils();
    await pref.init();
    final role = pref.getUserRole().trim().toLowerCase();
    if (!trainerAssignedMode &&
        (role == 'coach' || role == 'trainer' || role == 'тренер')) {
      trainerAssignedMode = true;
    }

    if (trainerWorkspaceId <= 0) trainerWorkspaceId = currentUserId;

    // Сам тренер входит сразу в персональный обзор,
    // а не в общий список команд клуба.
    if (trainerAssignedMode) {
      selectedSection = ClubSection.overview;
    }

    // Для клуба clubId = userId, для тренера clubId берём из первой назначенной команды.
    if (!trainerAssignedMode && clubId <= 0) clubId = currentUserId;

    await _loadAll(initial: true);

    // Для клуба стартовый экран — выбор команд, а не Спортотека OS.
    // Тренерский кабинет сохраняет персональный Overview.
    if (!trainerAssignedMode && mounted) {
      setState(() => selectedSection = ClubSection.teams);

      // На macOS/Windows рабочая область построена как OS с отдельными окнами.
      // Поэтому недостаточно только выбрать section: сразу открываем окно
      // «Команды», чтобы пользователь видел выбор команд при входе.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_isDesktopWide(context)) return;
        _openModuleWindow(ClubSection.teams);
      });
    }
  }

  Future<void> _loadAll({bool initial = false}) async {
    if (!mounted) return;
    setState(() {
      if (initial) loading = true;
      refreshing = !initial;
      error = null;
    });

    final subscriptionFuture = _safeLoad(_loadSubscriptionPlan);

    if (trainerAssignedMode) {
      // В режиме тренера сначала нужны команды: из первой назначенной команды
      // workspace может восстановить clubId.
      await _safeLoad(_loadTeams);
      await _safeLoad(_loadClubProfile);
    } else {
      // Для клуба профиль и команды не зависят друг от друга, поэтому грузим
      // параллельно и не держим стартовый экран лишние секунды.
      await Future.wait<void>([
        _safeLoad(_loadClubProfile),
        _safeLoad(_loadTeams),
      ]);
    }

    await subscriptionFuture;

    final targetTeamId = initialTeamId ?? selectedTeamId;
    Map<String, dynamic>? teamToSelect;

    if (targetTeamId != null && targetTeamId > 0) {
      for (final team in teams) {
        final id = _asInt(team['id'] ?? team['team_id'] ?? team['teamId']);
        if (id == targetTeamId) {
          teamToSelect = team;
          break;
        }
      }
    }

    teamToSelect ??= teams.isNotEmpty ? teams.first : null;

    if (teamToSelect != null) {
      await _selectTeam(teamToSelect, openTeam: false);
    } else {
      await Future.wait<void>([
        _safeLoad(_loadEvents),
        _safeLoad(_loadLatestPlans),
      ]);
    }

    if (!mounted) return;
    setState(() {
      loading = false;
      refreshing = false;
    });

    // Тренеры — самый тяжёлый fallback: при 404/HTML endpoint'а клуба он
    // обходит все команды. Не ждём его на стартовом экране, иначе loader
    // визуально «зависает» на 94%.
    Future<void>(() async {
      await _safeLoad(_loadTrainers);
      if (!mounted) return;
      setState(() {});
    });
  }

  Future<void> _safeLoad(Future<void> Function() loader) async {
    try {
      await loader();
    } catch (_) {}
  }

  Future<void> _loadSubscriptionPlan() async {
    if (currentUserId <= 0) return;
    try {
      final response = await http.post(
        Uri.parse(getMySubscriptionUrl),
        body: {'user_id': '$currentUserId'},
      ).timeout(const Duration(seconds: 10));
      final data = _decode(response.body);
      if (data is! Map || data['success'] != true) return;
      final raw = data['subscription'];
      if (raw is! Map) return;
      final plan = _asString(raw['plan_code']) ?? '';
      final status = (_asString(raw['status']) ?? '').toLowerCase().trim();
      if (!mounted) return;
      subscriptionPlanCode = plan;

      // У базового тарифа календарь/расписание и остальные базовые модули
      // должны открываться даже если backend вернул status=paid/current/trial
      // вместо старого строго `active`. Явно закрываем только реально
      // неактивные состояния.
      final normalizedPlan = plan.trim().toLowerCase();
      final explicitlyInactive = <String>{
        'inactive',
        'expired',
        'cancelled',
        'canceled',
        'blocked',
        'disabled',
      }.contains(status);
      final knownActive = <String>{
        'active',
        'paid',
        'current',
        'trial',
        'trialing',
        'enabled',
      }.contains(status);

      if (knownActive ||
          (normalizedPlan == 'club_basic' && !explicitlyInactive)) {
        hasActiveSubscription = true;
      }
    } catch (_) {}
  }

  Future<void> _loadClubProfile() async {
    // Важно: этот экран должен работать с тем же club_id, что и старый
    // ClubDashboardScreen. Поэтому профиль клуба грузим через POST club_id
    // и НЕ перезаписываем clubId из ответа: в некоторых ответах поле id
    // может быть id записи/пользователя, из-за чего тренеры считались как 0.
    final response = await http.post(Uri.parse(getClubProfileUrl), body: {
      'club_id': clubId.toString()
    }).timeout(const Duration(seconds: 10));

    final data = _decode(response.body);
    if (data is Map && data['success'] == true) {
      final raw = data['club'] ?? data['data'] ?? data;
      if (raw is Map) {
        clubName = _asString(raw['club_name']) ??
            _asString(raw['name']) ??
            _asString(raw['title']) ??
            clubName;

        clubLogo = _asString(raw['photo']) ??
            _asString(raw['logo']) ??
            _asString(raw['logo_url']) ??
            _asString(raw['avatar']) ??
            clubLogo;

        clubDescription = _asString(raw['club_description']) ??
            _asString(raw['description']) ??
            _asString(raw['about']) ??
            clubDescription;

        hasActiveSubscription = _asBool(
          raw['subscription_active'] ??
              raw['has_subscription'] ??
              raw['is_pro'] ??
              raw['pro_active'] ??
              raw['premium_active'] ??
              raw['tariff_active'] ??
              raw['subscription_status'] ??
              raw['tariff_status'],
        );
      }
    }
  }

  Future<void> _loadTeams() async {
    if (trainerAssignedMode) {
      await _loadAssignedTeamsForTrainer();
      return;
    }

    final response = await http.post(Uri.parse(getClubTeamsUrl), body: {
      'club_id': clubId.toString()
    }).timeout(const Duration(seconds: 10));

    final data = _decode(response.body);

    if (data is Map && data['success'] == true && data['teams'] is List) {
      teams = List<Map<String, dynamic>>.from(
        (data['teams'] as List).map((e) => Map<String, dynamic>.from(e)),
      );
    } else {
      teams = _extractList(data, keys: const ['teams', 'data', 'items']);
    }
  }

  Future<void> _loadAssignedTeamsForTrainer() async {
    teams = [];
    if (trainerWorkspaceId <= 0) return;

    final response = await http.post(
      Uri.parse(
          '$getTrainerTeamsUrl?coach_id=$trainerWorkspaceId&trainer_id=$trainerWorkspaceId'),
      body: {
        'coach_id': trainerWorkspaceId.toString(),
        'trainer_id': trainerWorkspaceId.toString(),
      },
    ).timeout(const Duration(seconds: 12));

    final data = _decode(response.body);
    debugPrint(
        'Club workspace assigned teams response trainer=$trainerWorkspaceId status=${response.statusCode}: ${_shortBody(response.body)}');
    final raw = _extractList(
      data,
      keys: const ['teams', 'assigned_teams', 'data', 'items', 'result'],
    );

    final seen = <int>{};
    final normalized = <Map<String, dynamic>>[];

    for (final item in raw) {
      final team = Map<String, dynamic>.from(item);
      final id = _asInt(team['id'] ?? team['team_id'] ?? team['teamId']);
      if (id <= 0 || seen.contains(id)) continue;
      seen.add(id);
      team['id'] = id;
      team['team_id'] = id;
      team['name'] = _asString(team['name'] ??
              team['team_name'] ??
              team['teamName'] ??
              team['title']) ??
          'Команда #$id';
      team['team_name'] = team['name'];
      team['logo'] = _asString(team['logo'] ??
              team['logo_url'] ??
              team['team_logo'] ??
              team['teamLogo']) ??
          '';
      normalized.add(team);
    }

    teams = normalized;

    if (clubId <= 0 && teams.isNotEmpty) {
      clubId = _asInt(teams.first['club_id'] ?? teams.first['clubId']);
    }
    if ((clubName.trim().isEmpty || clubName == 'Клуб') && teams.isNotEmpty) {
      clubName =
          _asString(teams.first['club_name'] ?? teams.first['clubName']) ??
              'Панель тренера';
    }
  }

  Future<void> _loadTrainers() async {
    // 1) Сначала пробуем прямой список тренеров клуба, как в ClubTrainersScreen.
    // 2) Если сервер вместо JSON отдаёт HTML/404, берём тренеров из рабочих
    //    экранов состава: get_team_trainers.php по каждой команде клуба.
    trainers = [];

    if (clubId <= 0) {
      debugPrint('Club workspace trainers skipped: club_id is empty');
      return;
    }

    try {
      final resp = await http.post(
        Uri.parse(getClubTrainersUrl),
        body: {'club_id': clubId.toString()},
      ).timeout(const Duration(seconds: 5));

      final data = _tryDecodeJson(resp.body);
      if (data != null) {
        final list = _extractTrainersList(data);
        if (list.isNotEmpty) {
          trainers = _uniqueTrainers(list);
          debugPrint(
            'Club workspace trainers loaded from club endpoint '
            'club_id=$clubId count=${trainers.length}',
          );
          return;
        }
      } else {
        debugPrint(
          'Club workspace trainers club endpoint returned non-json '
          'club_id=$clubId status=${resp.statusCode}: ${_shortBody(resp.body)}',
        );
      }
    } catch (e) {
      debugPrint(
          'Club workspace trainers club endpoint error club_id=$clubId: $e');
    }

    // Fallback: в team_roster_screen.dart тренеры команды грузятся именно так:
    // POST get_team_trainers.php { team_id: ... } -> trainers[]
    final byTeams = await _loadTrainersFromTeams();
    trainers = _uniqueTrainers(byTeams);
    debugPrint(
      'Club workspace trainers loaded from teams fallback '
      'club_id=$clubId teams=${teams.length} count=${trainers.length}',
    );
  }

  Future<List<Map<String, dynamic>>> _loadTrainersFromTeams() async {
    if (teams.isEmpty) return [];

    Future<List<Map<String, dynamic>>> loadForTeam(
        Map<String, dynamic> team) async {
      final teamId = _asInt(team['id'] ?? team['team_id'] ?? team['teamId']);
      if (teamId <= 0) return [];

      dynamic data;

      try {
        // В PHP-скриптах проекта чаще используется обычный form body,
        // поэтому сначала пробуем его, а JSON оставляем fallback'ом.
        final formResp = await http.post(
          Uri.parse(getTeamTrainersUrl),
          body: {'team_id': teamId.toString()},
        ).timeout(const Duration(seconds: 5));

        data = _tryDecodeJson(formResp.body);
        if (data == null) {
          debugPrint(
            'Club workspace team trainers form non-json '
            'team_id=$teamId status=${formResp.statusCode}: ${_shortBody(formResp.body)}',
          );
        }
      } catch (e) {
        debugPrint(
            'Club workspace team trainers form error team_id=$teamId: $e');
      }

      if (data == null || _extractTrainersList(data).isEmpty) {
        try {
          final jsonResp = await http
              .post(
                Uri.parse(getTeamTrainersUrl),
                headers: const {
                  'Content-Type': 'application/json; charset=utf-8'
                },
                body: jsonEncode({'team_id': teamId}),
              )
              .timeout(const Duration(seconds: 5));

          data = _tryDecodeJson(jsonResp.body);
          if (data == null) {
            debugPrint(
              'Club workspace team trainers json non-json '
              'team_id=$teamId status=${jsonResp.statusCode}: ${_shortBody(jsonResp.body)}',
            );
          }
        } catch (e) {
          debugPrint(
              'Club workspace team trainers json error team_id=$teamId: $e');
        }
      }

      final list = _extractTrainersList(data);
      final result = <Map<String, dynamic>>[];
      for (final t in list) {
        final item = Map<String, dynamic>.from(t);
        item['team_id'] = item['team_id'] ?? teamId;
        item['teamId'] = item['teamId'] ?? teamId;
        item['team_name'] = item['team_name'] ??
            item['teamName'] ??
            _asString(team['name']) ??
            _asString(team['team_name']) ??
            _asString(team['title']) ??
            'Команда';
        result.add(item);
      }
      return result;
    }

    final chunks = await Future.wait<List<Map<String, dynamic>>>(
      teams.map(loadForTeam),
    );

    return chunks.expand((chunk) => chunk).toList();
  }

  List<Map<String, dynamic>> _uniqueTrainers(List<Map<String, dynamic>> list) {
    final seen = <String>{};
    final out = <Map<String, dynamic>>[];

    for (final raw in list) {
      final item = Map<String, dynamic>.from(raw);
      final key = _trainerUniqueKey(item);
      if (seen.add(key)) out.add(item);
    }

    return out;
  }

  String _trainerUniqueKey(Map<String, dynamic> t) {
    final id = _asInt(
      t['trainer_id'] ??
          t['trainerId'] ??
          t['coach_id'] ??
          t['coachId'] ??
          t['user_id'] ??
          t['userId'] ??
          t['id'],
    );
    if (id > 0) return 'id:$id';

    final email = (_asString(t['email']) ?? '').trim().toLowerCase();
    if (email.isNotEmpty) return 'email:$email';

    final name = [
      _asString(t['first_name']),
      _asString(t['last_name']),
      _asString(t['name']),
      _asString(t['full_name']),
    ].whereType<String>().join('|').trim().toLowerCase();
    return name.isNotEmpty ? 'name:$name' : 'raw:${jsonEncode(t)}';
  }

  Future<void> _loadEvents() async {
    final params = <String, String>{
      if (clubId > 0) 'club_id': clubId.toString(),
      if (selectedTeamId != null && selectedTeamId! > 0)
        'team_id': selectedTeamId.toString(),
    };

    final uri = Uri.parse(getClubEventsUrl).replace(queryParameters: params);
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    events = _extractList(
      _decode(response.body),
      keys: const ['events', 'data', 'items'],
    );
  }

  Future<void> _loadLatestPlans() async {
    latestPlans = [];
    final params = <String, String>{
      'limit': '5',
      if (clubId > 0) 'club_id': clubId.toString(),
      if (selectedTeamId != null && selectedTeamId! > 0)
        'team_id': selectedTeamId.toString(),
      if (trainerAssignedMode && trainerWorkspaceId > 0)
        'trainer_id': trainerWorkspaceId.toString(),
      if (trainerAssignedMode && trainerWorkspaceName.trim().isNotEmpty)
        'trainer_name': trainerWorkspaceName.trim(),
    };

    if (!params.containsKey('club_id') && !params.containsKey('team_id')) {
      return;
    }

    final uri =
        Uri.parse(getLatestTrainingPlansUrl).replace(queryParameters: params);
    final response = await http.get(uri).timeout(const Duration(seconds: 10));
    final decoded = _decode(response.body);
    latestPlans = _extractList(
      decoded,
      keys: const ['plans', 'items', 'data', 'result'],
    );
  }

  Future<void> _loadPlayersForTeam(int teamId) async {
    if (!mounted) return;

    setState(() {
      loadingPlayers = true;
      players = [];
      selectedPlayer = null;
    });

    try {
      final response = await http
          .post(
            Uri.parse(getPlayersUrl),
            headers: const {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode({'team_id': teamId}),
          )
          .timeout(const Duration(seconds: 12));

      debugPrint('Club workspace get_players JSON team_id=$teamId');
      debugPrint('Club workspace get_players response=${response.body}');

      final data = jsonDecode(response.body);
      final ok = data is Map &&
          (data['status'] == 'success' || data['success'] == true);
      final loaded = ok
          ? List<Map<String, dynamic>>.from(data['players'] ?? []).map((p) {
              p['team_id'] = teamId;
              p['teamId'] = teamId;
              p['club_id'] = clubId;
              p['clubId'] = clubId;
              p['team_name'] = selectedTeamName;
              p['teamName'] = selectedTeamName;
              return p;
            }).toList()
          : <Map<String, dynamic>>[];

      if (!mounted) return;
      setState(() {
        players = loaded;
        selectedPlayer = loaded.isNotEmpty ? loaded.first : null;
        loadingPlayers = false;
      });

      // Если игроков нет, не показываем всплывающие окна — пустое состояние есть в списке.
    } catch (e) {
      if (!mounted) return;
      setState(() {
        players = [];
        selectedPlayer = null;
        loadingPlayers = false;
      });
      debugPrint('Club workspace players load error: $e');
    }
  }

  Future<void> _deletePlayerFromRoster(Map<String, dynamic> player) async {
    final playerId = _asInt(
      player['id'] ??
          player['player_id'] ??
          player['playerId'] ??
          player['playerID'],
    );

    final teamId = _asInt(
      player['team_id'] ?? player['teamId'] ?? selectedTeamId,
    );

    if (playerId <= 0) {
      throw Exception('Не найден id игрока из таблицы players');
    }

    if (teamId <= 0) {
      throw Exception('Не найдена команда игрока');
    }

    final response = await http
        .post(
          Uri.parse(deletePlayerUrl),
          headers: const {'Content-Type': 'application/json; charset=utf-8'},
          body: jsonEncode({
            'player_id': playerId,
            'team_id': teamId,
          }),
        )
        .timeout(const Duration(seconds: 12));

    final data = _decode(response.body);
    final success =
        data is Map && (data['success'] == true || data['status'] == 'success');

    if (!success) {
      final message = data is Map
          ? (_asString(data['message']) ??
              _asString(data['error']) ??
              'Сервер не подтвердил удаление игрока')
          : 'Сервер вернул некорректный ответ';
      throw Exception(message);
    }

    if (!mounted) return;

    setState(() {
      players = players.where((item) {
        final itemId = _asInt(
          item['id'] ??
              item['player_id'] ??
              item['playerId'] ??
              item['playerID'],
        );
        return itemId != playerId;
      }).toList();

      final selectedId = _asInt(
        selectedPlayer?['id'] ??
            selectedPlayer?['player_id'] ??
            selectedPlayer?['playerId'] ??
            selectedPlayer?['playerID'],
      );

      if (selectedId == playerId) {
        selectedPlayer = players.isNotEmpty ? players.first : null;
      }
    });
  }

  Future<void> _selectTeam(Map<String, dynamic> team,
      {bool openTeam = false}) async {
    final id = _asInt(
        team['id'] ?? team['team_id'] ?? team['teamId'] ?? team['teamID']);

    if (!mounted) return;

    setState(() {
      panelLoading = true;
      selectedTeam = team;
      selectedTeamId = id;
      selectedTeamName = _asString(team['name']) ??
          _asString(team['team_name']) ??
          _asString(team['title']) ??
          'Команда';

      // После выбора активной команды автоматически возвращаемся
      // в основную панель клуба. Если где-то явно нужен полный экран
      // команды, передавай openTeam: true.
      selectedSection =
          openTeam ? ClubSection.teamDashboard : ClubSection.teams;
    });

    if (id > 0) {
      await _loadPlayersForTeam(id);
      await _safeLoad(_loadEvents);
      await _safeLoad(_loadLatestPlans);
    } else {
      Get.snackbar('Команда', 'У выбранной команды нет корректного ID');
    }

    if (mounted) {
      setState(() => panelLoading = false);
    }
  }

  String _selectedTeamStage() {
    return _stageFromTeam(selectedTeam, fallbackName: selectedTeamName) ??
        'U13';
  }

  String? _stageFromTeam(Map<String, dynamic>? team, {String? fallbackName}) {
    final values = <String>[];
    if (team != null) {
      for (final key in const [
        'stage',
        'stage_code',
        'stageCode',
        'age_group',
        'ageGroup',
        'age',
        'team_age',
        'teamAge',
        'category',
        'sport_category',
        'name',
        'team_name',
        'title',
      ]) {
        final v = _asString(team[key]);
        if (v != null && v.trim().isNotEmpty) values.add(v);
      }
    }
    if (fallbackName != null && fallbackName.trim().isNotEmpty)
      values.add(fallbackName);

    for (final raw in values) {
      final stage = _normalizeStage(raw);
      if (stage != null) return stage;
    }
    return null;
  }

  String? _normalizeStage(String raw) {
    final t = raw.trim().toUpperCase().replaceAll(' ', '');
    final u = RegExp(r'U-?([0-9]{1,2})').firstMatch(t);
    if (u != null) {
      final n = int.tryParse(u.group(1)!);
      if (n != null && n >= 6 && n <= 17) return 'U$n';
    }

    final years = RegExp(r'(^|[^0-9])([6-9]|1[0-7])([^0-9]|$)').firstMatch(t);
    if (years != null) {
      final n = int.tryParse(years.group(2)!);
      if (n != null && n >= 6 && n <= 17) return 'U$n';
    }

    switch (t) {
      case 'МЯЧ':
        return 'U6';
      case 'МЯЧ+ВОРОТА':
      case 'М+ВОРОТА':
      case 'МВ':
        return 'U7';
      case 'МЯЧ+ВОРОТА+СОПЕРНИК':
      case 'М+В+СОПЕРНИК':
      case 'МВС':
        return 'U8';
      case 'МЯЧ+ВОРОТА+СОПЕРНИК+ПАРТНЕР':
      case 'МЯЧ+ВОРОТА+СОПЕРНИК+ПАРТНЁР':
      case 'М+В+С+ПАРТНЕР':
      case 'М+В+С+ПАРТНЁР':
      case 'МВСП':
        return 'U9';
    }
    return null;
  }

  Map<String, dynamic> _playerArgs(Map<String, dynamic> player) {
    final mp = Map<String, dynamic>.from(player);

    mp['team_id'] = selectedTeamId ?? mp['team_id'] ?? mp['teamId'];
    mp['teamId'] = selectedTeamId ?? mp['teamId'] ?? mp['team_id'];
    mp['club_id'] = clubId;
    mp['clubId'] = clubId;
    mp['team_name'] = selectedTeamName;
    mp['teamName'] = selectedTeamName;

    return mp;
  }

  String _playerWindowIdentity(Map<String, dynamic>? player) {
    if (player == null) return '';

    const idKeys = [
      'id',
      'player_id',
      'playerId',
      'user_id',
      'userId',
      'member_id',
      'memberId',
    ];

    for (final key in idKeys) {
      final value = '${player[key] ?? ''}'.trim();
      if (value.isNotEmpty && value != 'null' && value != '0') {
        return '$key:$value';
      }
    }

    final first = '${player['first_name'] ?? player['firstname'] ?? ''}'.trim();
    final last = '${player['last_name'] ?? player['lastname'] ?? ''}'.trim();
    final full =
        '${player['fullName'] ?? player['full_name'] ?? player['name'] ?? ''}'
            .trim();
    final birth =
        '${player['birth_date'] ?? player['birthDate'] ?? player['birthday'] ?? ''}'
            .trim();

    final fallback = [first, last, full, birth]
        .where((value) => value.isNotEmpty && value != 'null')
        .join('|');

    return fallback.isEmpty
        ? 'player:${DateTime.now().microsecondsSinceEpoch}'
        : 'fallback:$fallback';
  }

  String _playerWindowTitle(Map<String, dynamic> player) {
    final first = '${player['first_name'] ?? player['firstname'] ?? ''}'.trim();
    final last = '${player['last_name'] ?? player['lastname'] ?? ''}'.trim();
    final full =
        '${player['fullName'] ?? player['full_name'] ?? player['name'] ?? ''}'
            .trim();
    final name = [last, first]
        .where((value) => value.isNotEmpty && value != 'null')
        .join(' ');
    final result = name.trim().isNotEmpty ? name.trim() : full.trim();
    return result.isEmpty || result == 'null' ? 'Профиль игрока' : result;
  }

  _WorkspaceWindowState? _playerProfileWorkspaceWindow(String entityKey) {
    for (final window in _openWorkspaceWindows) {
      if (window.section == ClubSection.playerProfile &&
          window.entityKey == entityKey) {
        return window;
      }
    }
    return null;
  }

  void _openPlayer(Map<String, dynamic> player) {
    final mp = _playerArgs(player);

    setState(() {
      selectedPlayer = mp;
      selectedSection = ClubSection.roster;
    });
  }

  void _openPlayerProfile(Map<String, dynamic> player) {
    _openPlayerProfileWindow(player);
  }

  void _openPlayerProfileWindow(Map<String, dynamic> player) {
    final mp = _playerArgs(player);

    setState(() {
      selectedPlayer = mp;
    });

    final width = MediaQuery.maybeOf(context)?.size.width ?? 0;
    final desktopLike = width >= 900;

    if (!desktopLike) {
      Get.to(() => CmrPlayerProfileScreen(player: mp));
      return;
    }

    final entityKey = 'player:${_playerWindowIdentity(mp)}';
    final existing = _playerProfileWorkspaceWindow(entityKey);

    setState(() {
      selectedSection = ClubSection.roster;
      panelLoading = false;

      if (existing != null) {
        existing.minimized = false;
        existing.zIndex = ++_workspaceWindowZCounter;
        return;
      }

      final offset = (_openWorkspaceWindows.length % 6) * 32.0;
      _openWorkspaceWindows.add(
        _WorkspaceWindowState(
          id: 'window_player_${DateTime.now().microsecondsSinceEpoch}',
          section: ClubSection.playerProfile,
          entityKey: entityKey,
          titleOverride: _playerWindowTitle(mp),
          subtitleOverride: selectedTeamName,
          iconOverride: Icons.person_rounded,
          playerPayload: mp,
          position: Offset(96 + offset, 58 + offset),
          size: const Size(1180, 720),
          zIndex: ++_workspaceWindowZCounter,
        ),
      );
    });
  }

  Future<void> _openEditClubDialog() async {
    final nameCtrl = TextEditingController(text: clubName);
    final descCtrl = TextEditingController(text: clubDescription);
    XFile? pickedLogo;
    final picker = ImagePicker();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 18,
                  right: 18,
                  top: 14,
                  bottom: 18 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 46,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Редактирование клуба',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: _C.text,
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final x = await picker.pickImage(
                          source: ImageSource.gallery,
                          imageQuality: 85,
                          maxWidth: 1400,
                        );
                        if (x != null) setSheetState(() => pickedLogo = x);
                      },
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _C.soft,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: _C.border),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: Colors.white,
                              backgroundImage: pickedLogo != null
                                  ? FileImage(File(pickedLogo!.path))
                                  : (clubLogo != null && clubLogo!.isNotEmpty
                                      ? NetworkImage(clubLogo!) as ImageProvider
                                      : null),
                              child: pickedLogo == null &&
                                      (clubLogo == null || clubLogo!.isEmpty)
                                  ? const Icon(Icons.shield_rounded,
                                      color: _C.primaryGreen)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Логотип клуба',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: _C.text)),
                                  SizedBox(height: 3),
                                  Text('Нажмите, чтобы заменить изображение',
                                      style: TextStyle(
                                          color: _C.muted,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12)),
                                ],
                              ),
                            ),
                            const Icon(Icons.edit_rounded,
                                color: _C.primaryGreen),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Название клуба',
                        filled: true,
                        fillColor: _C.soft,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Описание клуба',
                        filled: true,
                        fillColor: _C.soft,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: savingProfile
                          ? null
                          : () async {
                              await _saveClubProfile(
                                name: nameCtrl.text.trim(),
                                description: descCtrl.text.trim(),
                                logo: pickedLogo,
                              );
                              if (mounted) Navigator.pop(context);
                            },
                      icon: const Icon(Icons.save_rounded, color: Colors.white),
                      label: const Text('Сохранить',
                          style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _C.primaryGreen,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _saveClubProfile({
    required String name,
    required String description,
    XFile? logo,
  }) async {
    if (name.isEmpty) {
      Get.snackbar('Клуб', 'Введите название клуба');
      return;
    }
    if (!mounted) return;
    setState(() => savingProfile = true);
    try {
      final req =
          http.MultipartRequest('POST', Uri.parse(updateClubProfileUrl));
      req.fields['club_id'] = clubId.toString();
      req.fields['club_name'] = name;
      req.fields['name'] = name;
      req.fields['club_description'] = description;
      req.fields['description'] = description;
      if (logo != null) {
        req.files
            .add(await http.MultipartFile.fromPath('club_logo', logo.path));
      }
      final streamed = await req.send().timeout(const Duration(seconds: 20));
      final resp = await http.Response.fromStream(streamed);
      final data = _decode(resp.body);
      final ok = data is Map &&
          (data['success'] == true || data['status'] == 'success');
      if (ok) {
        final raw = data is Map ? (data['club'] ?? data['data']) : null;
        setState(() {
          clubName = name;
          clubDescription = description;
          if (raw is Map) {
            clubLogo = _asString(raw['logo']) ??
                _asString(raw['logo_url']) ??
                _asString(raw['photo']) ??
                _asString(raw['avatar']) ??
                clubLogo;
          }
        });
        await _loadClubProfile();
        Get.snackbar('Готово', 'Данные клуба обновлены');
      } else {
        Get.snackbar(
            'Ошибка',
            data is Map
                ? '${data['message'] ?? data['error'] ?? 'Не удалось сохранить'}'
                : 'Не удалось сохранить');
      }
    } catch (e) {
      Get.snackbar('Сеть', 'Ошибка сохранения: $e');
    } finally {
      if (mounted) setState(() => savingProfile = false);
    }
  }

  Future<void> _openEditTeamDialog() async {
    if (!_hasTeam || selectedTeam == null) {
      Get.snackbar('Команда', 'Сначала выберите команду');
      return;
    }

    final nameCtrl = TextEditingController(text: selectedTeamName);
    final categoryCtrl = TextEditingController(
      text: _asString(selectedTeam?['category'] ??
              selectedTeam?['sport'] ??
              selectedTeam?['age_group']) ??
          'Футбол',
    );
    final oldLogo = _asString(selectedTeam?['logo'] ??
        selectedTeam?['logo_url'] ??
        selectedTeam?['photo']);
    XFile? pickedLogo;
    final picker = ImagePicker();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 18,
                  right: 18,
                  top: 14,
                  bottom: 18 + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 46,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: const [
                        _IconBadge(
                            icon: Icons.tune_rounded, size: 46, iconSize: 23),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Редактирование команды',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: _C.text)),
                              SizedBox(height: 3),
                              Text('Название, категория и логотип команды',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: _C.muted)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    InkWell(
                      onTap: () async {
                        final x = await picker.pickImage(
                          source: ImageSource.gallery,
                          imageQuality: 85,
                          maxWidth: 1400,
                        );
                        if (x != null) setSheetState(() => pickedLogo = x);
                      },
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _C.soft,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: _C.border),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: Colors.white,
                              backgroundImage: pickedLogo != null
                                  ? FileImage(File(pickedLogo!.path))
                                  : (oldLogo != null && oldLogo.isNotEmpty
                                      ? NetworkImage(oldLogo) as ImageProvider
                                      : null),
                              child: pickedLogo == null &&
                                      (oldLogo == null || oldLogo.isEmpty)
                                  ? const Icon(Icons.groups_2_rounded,
                                      color: _C.primaryGreen)
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Логотип команды',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: _C.text)),
                                  SizedBox(height: 3),
                                  Text('Нажмите, чтобы заменить изображение',
                                      style: TextStyle(
                                          color: _C.muted,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12)),
                                ],
                              ),
                            ),
                            const Icon(Icons.edit_rounded,
                                color: _C.primaryGreen),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: nameCtrl,
                      decoration: InputDecoration(
                        labelText: 'Название команды',
                        filled: true,
                        fillColor: _C.soft,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: categoryCtrl,
                      decoration: InputDecoration(
                        labelText: 'Категория / вид спорта',
                        filled: true,
                        fillColor: _C.soft,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: savingProfile
                          ? null
                          : () async {
                              await _saveSelectedTeamProfile(
                                name: nameCtrl.text.trim(),
                                category: categoryCtrl.text.trim(),
                                logo: pickedLogo,
                              );
                              if (mounted) Navigator.pop(context);
                            },
                      icon: const Icon(Icons.save_rounded, color: Colors.white),
                      label: const Text('Сохранить',
                          style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _C.primaryGreen,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _saveSelectedTeamProfile({
    required String name,
    required String category,
    XFile? logo,
  }) async {
    if (!_hasTeam) return;
    if (name.isEmpty) {
      Get.snackbar('Команда', 'Введите название команды');
      return;
    }
    if (!mounted) return;
    setState(() => savingProfile = true);
    try {
      final req =
          http.MultipartRequest('POST', Uri.parse(updateTeamProfileUrl));
      req.fields['team_id'] = selectedTeamId.toString();
      req.fields['team_name'] = name;
      req.fields['name'] = name;
      req.fields['category'] = category.isEmpty ? 'Футбол' : category;
      if (logo != null) {
        req.files.add(await http.MultipartFile.fromPath('logo', logo.path));
      }
      final streamed = await req.send().timeout(const Duration(seconds: 20));
      final resp = await http.Response.fromStream(streamed);
      final data = _decode(resp.body);
      final ok = data is Map &&
          (data['success'] == true || data['status'] == 'success');
      if (ok) {
        setState(() {
          selectedTeamName = name;
          selectedTeam = {
            ...?selectedTeam,
            'name': name,
            'team_name': name,
            'category': category.isEmpty ? 'Футбол' : category,
          };
        });
        await _loadTeams();
        if (selectedTeamId != null && selectedTeamId! > 0) {
          await _loadPlayersForTeam(selectedTeamId!);
        }
        Get.snackbar('Готово', 'Данные команды обновлены');
      } else {
        Get.snackbar(
            'Ошибка',
            data is Map
                ? '${data['message'] ?? data['error'] ?? 'Не удалось сохранить'}'
                : 'Не удалось сохранить');
      }
    } catch (e) {
      Get.snackbar('Сеть', 'Ошибка сохранения: $e');
    } finally {
      if (mounted) setState(() => savingProfile = false);
    }
  }

  void _openGameModule(ClubSection section) {
    final isGameSection = section == ClubSection.challengeCreate ||
        section == ClubSection.challenges ||
        section == ClubSection.quizCreate ||
        section == ClubSection.quizzes ||
        section == ClubSection.rating ||
        section == ClubSection.miniGames ||
        section == ClubSection.manager;

    if (isGameSection && !_hasTeam) {
      Get.snackbar('Команда', 'Сначала выберите команду');
      return;
    }

    final args = {
      'team_id': selectedTeamId,
      'teamId': selectedTeamId,
      'user_id': currentUserId,
      'team_name': selectedTeamName,
    };

    switch (section) {
      case ClubSection.tracker:
        _selectWorkspaceSection(ClubSection.tracker);
        break;
      case ClubSection.challengeCreate:
        Get.to(() => const CreateChallengeScreen(), arguments: args);
        break;
      case ClubSection.quizCreate:
        Get.to(() => const CreateQuizScreen(), arguments: args);
        break;
      case ClubSection.manager:
        final activeTeamId = _activeTeamIdOrNull;
        if (activeTeamId == null) {
          Get.snackbar('Команда', 'Сначала выберите команду');
          return;
        }
        Get.to(() => ManagerDashboardScreen(
              teamId: activeTeamId,
              userId: currentUserId,
              teamName: selectedTeamName,
            ));
        break;
      case ClubSection.challenges:
      case ClubSection.quizzes:
      case ClubSection.rating:
      case ClubSection.miniGames:
        setState(() => selectedSection = section);
        break;
      default:
        setState(() => selectedSection = section);
    }
  }

  void _openCreateTeam() {
    if (_isClubBasic && teams.length >= 20) {
      Get.snackbar(
        'Лимит базовой подписки',
        'В базовом тарифе доступно до 20 команд.',
      );
      return;
    }

    // Создание команды открывается прямо справа в CMR.
    setState(() {
      selectedSection = ClubSection.teams;
      panelLoading = false;
      _openCreateTeamInline = true;
    });
  }

  void _openFullTeamDashboard() {
    final activeTeamId = _activeTeamIdOrNull;
    if (activeTeamId == null) {
      Get.snackbar('Команда', 'Сначала выберите команду');
      return;
    }
    Get.to(() => TeamDashboardScreen(
          teamId: activeTeamId,
          teamName: selectedTeamName,
          clubId: clubId,
          clubName: clubName,
        ));
  }

  Future<void> _openFullModulesMenu() async {
    final section = await showGeneralDialog<ClubSection>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Закрыть меню',
      barrierColor: Colors.black.withOpacity(.28),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _FullModulesMenuOverlay(
          clubName: clubName,
          clubLogo: clubLogo,
          selectedTeamName: selectedTeamName,
          selectedSection: selectedSection,
          hasActiveSubscription: hasActiveSubscription,
          items: _fullMenuItems,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: Transform.translate(
            offset: Offset(0, 26 * (1 - curved.value)),
            child: Transform.scale(
              alignment: Alignment.bottomCenter,
              scale: .965 + (.035 * curved.value),
              child: child,
            ),
          ),
        );
      },
    );

    if (section == null || !mounted) return;

    if (section == ClubSection.challengeCreate ||
        section == ClubSection.quizCreate) {
      _openGameModule(section);
      return;
    }

    _selectWorkspaceSection(section);
  }

  Future<void> _openDesktopCommandMenu() async {
    final section = await showGeneralDialog<ClubSection>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Поиск модуля',
      barrierColor: Colors.black.withOpacity(.22),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, animation, secondaryAnimation) {
        return _DesktopCommandMenuOverlay(
          clubName: clubName,
          clubLogo: clubLogo,
          selectedTeamName: selectedTeamName,
          selectedSection: selectedSection,
          hasActiveSubscription: hasActiveSubscription,
          items: _fullMenuItems,
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - curved.value)),
            child: child,
          ),
        );
      },
    );

    if (section == null || !mounted) return;

    if (section == ClubSection.challengeCreate ||
        section == ClubSection.quizCreate) {
      _openGameModule(section);
      return;
    }

    _selectWorkspaceSection(section);
  }

  List<_FullMenuItem> get _fullMenuItems => [
        const _FullMenuItem(
          ClubSection.finder,
          Icons.folder_open_rounded,
          'Спортотека OS',
          'Единое пространство клуба',
        ),
        const _FullMenuItem(
          ClubSection.teams,
          Icons.account_tree_rounded,
          'Команды',
          'Список команд клуба',
        ),
        _FullMenuItem(
          ClubSection.trainers,
          Icons.badge_rounded,
          'Тренеры',
          trainerAssignedMode
              ? 'Коллеги · просмотр профилей · чат'
              : 'Специалисты и назначения',
        ),
        _FullMenuItem(ClubSection.roster, Icons.groups_2_rounded, 'Состав',
            'Игроки и профили'),
        _FullMenuItem(ClubSection.matches, Icons.sports_soccer_rounded, 'Матчи',
            'Игры, счет и календарь'),
        // Календарь/расписание входит в базовую подписку: без PRO-замка.
        _FullMenuItem(ClubSection.calendar, Icons.calendar_month_rounded,
            'Календарь', 'Тренировки и события'),
        _FullMenuItem(ClubSection.plans, Icons.folder_copy_rounded,
            'Планы-конспекты', 'Материалы тренера',
            pro: true),
        _FullMenuItem(ClubSection.graphics, Icons.draw_rounded, 'Редактор схем',
            'Упражнения и разметка',
            pro: true),
        _FullMenuItem(ClubSection.attendance, Icons.fact_check_rounded,
            'Посещаемость', 'Журнал занятий',
            pro: true),
        _FullMenuItem(ClubSection.testing, Icons.science_rounded,
            'Тестирование', 'Физика, техника, тактика',
            pro: true),
        _FullMenuItem(ClubSection.medical, Icons.medical_information_rounded,
            'Медкарта', 'Состояние игроков'),
        _FullMenuItem(ClubSection.tracker, Icons.sensors_rounded, 'Трекер',
            'GPS, нагрузка и тепловые карты',
            pro: true),
        _FullMenuItem(ClubSection.manager, Icons.psychology_alt_rounded,
            'Менеджер команды', 'Тактика и состав',
            pro: true),
        _FullMenuItem(
            ClubSection.chat, Icons.forum_rounded, 'Чаты', 'Общение команды'),
        _FullMenuItem(ClubSection.parents, Icons.family_restroom_rounded,
            'Родители', 'Доступы и связь'),
        _FullMenuItem(ClubSection.miniGames, Icons.videogame_asset_rounded,
            'Игровая зона', 'Задания, квизы, рейтинг'),
        _FullMenuItem(ClubSection.settings, Icons.tune_rounded, 'Настройки',
            'Права и модули'),
      ];

  void _openFullRosterScreen() {
    final activeTeamId = _activeTeamIdOrNull;
    if (activeTeamId == null) {
      Get.snackbar('Команда', 'Сначала выберите команду');
      return;
    }
    Get.to(() =>
        TeamRosterScreen(teamId: activeTeamId, teamName: selectedTeamName));
  }

  void _openFullMatches() {
    if (!_hasTeam) return;
    Get.to(() => const TeamMatchesScreen(), arguments: {
      'teamId': selectedTeamId,
      'teamName': selectedTeamName,
    });
  }

  void _openFullCalendar() {
    final activeTeamId = _activeTeamIdOrNull;
    if (activeTeamId == null) {
      Get.snackbar('Календарь', 'Сначала выберите команду');
      return;
    }
    Get.to(() =>
        TeamCalendarScreen(teamId: activeTeamId, teamName: selectedTeamName));
  }

  void _openFullPlans() {
    Get.to(() => PlanFoldersScreen(
          clubId: clubId,
          clubName: clubName,
          teamId: selectedTeamId,
          selectMode: false,
          browsePlansMode: false,
        ));
  }

  void _openFullGraphics() {
    Get.to(() => TrainingGraphicsScreen(
          teamId: selectedTeamId,
          teamName: selectedTeamName,
          clubId: clubId,
          clubName: clubName,
        ));
  }

  void _openFullVideoAnalysis() {
    final activeTeamId = _activeTeamIdOrNull;
    if (activeTeamId == null) {
      Get.snackbar('Команда', 'Сначала выберите команду');
      return;
    }
    Get.to(() => TeamVideoAnalysisScreen(
          teamId: activeTeamId,
          teamName: selectedTeamName,
          clubId: clubId,
          clubName: clubName,
        ));
  }

  void _openFullTracker() {
    final activeTeamId = _asInt(
      selectedTeam?['id'] ??
          selectedTeam?['team_id'] ??
          selectedTeam?['teamId'] ??
          selectedTeam?['teamID'] ??
          selectedTeamId,
    );

    if (activeTeamId <= 0) {
      Get.snackbar('Команда', 'Сначала выберите команду');
      return;
    }

    _selectWorkspaceSection(ClubSection.tracker);
  }

  void _openFullTeamDescription() {
    if (!_hasTeam) return;
    Get.to(() => const TeamDescriptionScreen(), arguments: selectedTeamId);
  }

  void _openFullChat() {
    final userId = currentUserId > 0 ? currentUserId : clubId;
    Get.to(() => ChatScreen(userId: userId));
  }

  void _openFullVideoLessons() {
    final userId = currentUserId > 0 ? currentUserId : clubId;
    Get.to(() => VideoLessonsScreen(
          ownerUserId: userId,
          ownerName: clubName,
          isMyMode: true,
          embedded: false,
        ));
  }

  int? get _activeTeamIdOrNull {
    final id = selectedTeamId;
    if (id == null || id <= 0) return null;
    return id;
  }

  bool get _hasTeam => _activeTeamIdOrNull != null;

  dynamic _decode(String body) {
    final data = _tryDecodeJson(body);
    if (data != null) return data;
    return <String, dynamic>{};
  }

  dynamic _tryDecodeJson(String body) {
    final raw = body.trim();
    if (raw.isEmpty) return null;

    // Быстрый отсев HTML-ответов: 404, PHP warning page, редирект и т.п.
    final lower = raw.length > 80
        ? raw.substring(0, 80).toLowerCase()
        : raw.toLowerCase();
    if (lower.startsWith('<!doctype') || lower.startsWith('<html')) {
      return null;
    }

    try {
      return jsonDecode(raw);
    } catch (_) {
      // Иногда сервер добавляет warning/notice до или после JSON.
      final startObj = raw.indexOf('{');
      final startArr = raw.indexOf('[');
      final starts = [startObj, startArr].where((e) => e >= 0).toList();
      if (starts.isEmpty) return null;

      final start = starts.reduce(math.min);
      final startedWithObject = start == startObj || startArr < 0;
      final end =
          startedWithObject ? raw.lastIndexOf('}') : raw.lastIndexOf(']');
      if (end <= start) return null;

      final sliced = raw.substring(start, end + 1).trim();
      try {
        return jsonDecode(sliced);
      } catch (_) {
        return null;
      }
    }
  }

  String _shortBody(String body, {int max = 180}) {
    final oneLine = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (oneLine.length <= max) return oneLine;
    return '${oneLine.substring(0, max)}…';
  }

  List<Map<String, dynamic>> _extractList(dynamic data,
      {required List<String> keys}) {
    dynamic raw = data;
    if (data is Map) {
      for (final key in keys) {
        if (data[key] is List) {
          raw = data[key];
          break;
        }
      }
    }
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  List<Map<String, dynamic>> _extractTrainersList(dynamic data) {
    // Основной рабочий формат: { success: true, trainers: [...] }
    final direct = _extractList(
      data,
      keys: const ['trainers', 'coaches', 'users', 'items', 'data', 'result'],
    );
    if (direct.isNotEmpty) return direct;

    // Частые вложенные форматы: { data: { trainers: [...] } }
    if (data is Map) {
      for (final key in const ['data', 'result', 'response', 'payload']) {
        final nested = data[key];
        if (nested is Map) {
          final list = _extractList(
            nested,
            keys: const ['trainers', 'coaches', 'users', 'items', 'data'],
          );
          if (list.isNotEmpty) return list;
        }
      }
    }

    return [];
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.round();
    return int.tryParse('${value ?? 0}') ?? 0;
  }

  String? _asString(dynamic value) {
    final text = '${value ?? ''}'.trim();
    return text.isEmpty || text == 'null' ? null : text;
  }

  bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value > 0;
    final text = '${value ?? ''}'.trim().toLowerCase();
    return text == '1' ||
        text == 'true' ||
        text == 'yes' ||
        text == 'active' ||
        text == 'paid' ||
        text == 'pro' ||
        text == 'premium' ||
        text == 'активна';
  }

  bool _isDesktopPlatform() {
    final platform = defaultTargetPlatform;

    if (kIsWeb) {
      return platform == TargetPlatform.macOS ||
          platform == TargetPlatform.windows ||
          platform == TargetPlatform.linux;
    }

    return Platform.isMacOS || Platform.isWindows || Platform.isLinux;
  }

  bool _isTabletPlatform() {
    final platform = defaultTargetPlatform;
    return platform == TargetPlatform.android ||
        platform == TargetPlatform.iOS ||
        platform == TargetPlatform.fuchsia;
  }

  bool _useProfessionalWorkspace(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final shortestSide = math.min(size.width, size.height);

    // Планшеты остаются в CMR-shell, но не получают ПК-режим с рабочим столом и окнами.
    if (_isTabletPlatform()) {
      return shortestSide >= 600 || (size.width >= 700 && shortestSide >= 500);
    }

    // Настоящий ПК/macOS/Windows/Linux.
    if (_isDesktopPlatform()) {
      return size.width >= 900;
    }

    // Остальные случаи: телефон в landscape не превращаем в ПК.
    return shortestSide >= 600 || (size.width >= 700 && shortestSide >= 500);
  }

  bool _isDesktopWide(BuildContext context) {
    if (!_isDesktopPlatform()) return false;

    final size = MediaQuery.of(context).size;
    final shortestSide = math.min(size.width, size.height);
    return size.width >= 1180 && shortestSide >= 650;
  }

  double _getResponsiveFontSize(BuildContext context, double baseSize) {
    final width = MediaQuery.of(context).size.width;
    if (width < 360) return baseSize * 0.7;
    if (width < 400) return baseSize * 0.8;
    if (width < 600) return baseSize * 0.9;
    if (width < 900) return baseSize * 0.95;
    return baseSize;
  }

  double _getResponsivePadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 360) return 6.0;
    if (width < 400) return 7.0;
    if (width < 600) return 8.0;
    return 14.0;
  }

  void _handleWorkspaceBack() {
    if (selectedSection != ClubSection.teams) {
      setState(() => selectedSection = ClubSection.teams);
      return;
    }

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Get.back();
    }
  }

  Future<void> _goHomeFromWorkspace() async {
    // Главная страница приложения теперь — MyProfileScreen.
    // Нельзя делать popUntil(route.isFirst): первым route после логина/обновления
    // часто остаётся устаревший HomeScreen, из-за этого Workspace возвращал не туда.
    final profileUserId = await PrefUtils.getUserId();
    if (!mounted) return;

    Get.offAll<void>(() => const WorkspaceHubScreen());
  }

  void _selectWorkspaceSection(ClubSection section) {
    if (section == ClubSection.trainers ||
        section == ClubSection.teamTrainers) {
      _showOwnTrainerProfile = false;
    }

    if (section != ClubSection.teams && _openCreateTeamInline) {
      _openCreateTeamInline = false;
    }
    if (section == ClubSection.chat) {
      _chatPanelRevision++;
    }

    // Только настоящий ПК открывает модули отдельными окнами.
    // На Android/iPad планшетах разделы переключаются внутри планшетного shell.
    if (_isDesktopWide(context)) {
      _openModuleWindow(section);
      return;
    }

    _activateInlineSection(section);
  }

  void _activateInlineSection(ClubSection section) {
    if (!_canOpenWorkspaceSection(section)) return;

    // Повторное нажатие на «Чаты» всегда возвращает к общему списку.
    if (selectedSection == section) {
      if (section == ClubSection.chat) {
        setState(() {
          _chatPanelRevision++;
          panelLoading = false;
        });
      }
      return;
    }

    setState(() {
      selectedSection = section;
      panelLoading = true;
    });

    Future<void>.delayed(const Duration(milliseconds: 260), () {
      if (!mounted) return;
      setState(() => panelLoading = false);
    });
  }

  bool _canOpenWorkspaceSection(ClubSection section) {
    // Календарь = рабочее расписание клуба/команды и входит в club_basic.
    // Держим явное правило, чтобы никакой старый PRO-флаг в меню не
    // мог закрыть переход на CmrCalendarPanel.
    if (_isClubBasic && section == ClubSection.calendar) {
      return true;
    }

    if (_isClubBasic) {
      const excludedFromBasic = <ClubSection>{
        ClubSection.coachDashboard,
        ClubSection.tracker,
        ClubSection.videoAnalysis,
        ClubSection.videoLessons,
        ClubSection.manager,
      };
      if (excludedFromBasic.contains(section)) {
        Get.snackbar(
          'Базовая подписка',
          'Раздел «${_titleFor(section)}» не входит в базовый тариф.',
        );
        return false;
      }
    }

    if (section == ClubSection.tracker && !_hasTeam) {
      Get.snackbar('Команда', 'Сначала выберите команду');
      return false;
    }
    return true;
  }

  List<_FullMenuItem> get _workspaceDesktopModules => _fullMenuItems
      .where((item) => item.section != ClubSection.settings)
      .toList(growable: false);

  List<_FullMenuItem> get _workspaceDesktopIcons => _workspaceDesktopModules
      .where((item) => _desktopIconSections.contains(item.section))
      .toList(growable: false);

  List<_FullMenuItem> get _workspaceDockItems => _workspaceDesktopModules
      .where((item) => _dockSections.contains(item.section))
      .toList(growable: false);

  _FullMenuItem _workspaceItemFor(ClubSection section) {
    for (final item in _fullMenuItems) {
      if (item.section == section) return item;
    }
    return _FullMenuItem(section, Icons.widgets_rounded, _titleFor(section),
        _subtitleFor(section));
  }

  _WorkspaceWindowState? _workspaceWindowFor(
    ClubSection section, {
    String? entityKey,
  }) {
    for (final window in _openWorkspaceWindows) {
      if (window.section != section) continue;
      if (entityKey == null && window.entityKey != null) continue;
      if (entityKey != null && window.entityKey != entityKey) continue;
      return window;
    }
    return null;
  }

  void _openModuleWindow(ClubSection section) {
    if (section == ClubSection.settings) {
      _openWorkspaceSettings();
      return;
    }

    if (!_canOpenWorkspaceSection(section)) return;

    final existing = _workspaceWindowFor(section);
    setState(() {
      selectedSection = section;
      panelLoading = false;

      if (existing != null) {
        existing.minimized = false;
        existing.zIndex = ++_workspaceWindowZCounter;
        return;
      }

      final offset = (_openWorkspaceWindows.length % 6) * 34.0;
      _openWorkspaceWindows.add(
        _WorkspaceWindowState(
          id: 'window_${section.name}_${DateTime.now().microsecondsSinceEpoch}',
          section: section,
          position: Offset(72 + offset, 52 + offset),
          size: const Size(1040, 680),
          zIndex: ++_workspaceWindowZCounter,
        ),
      );
    });
  }

  void _bringWorkspaceWindowToFront(_WorkspaceWindowState window) {
    setState(() {
      selectedSection = window.section;
      window.zIndex = ++_workspaceWindowZCounter;
    });
  }

  void _closeWorkspaceWindow(_WorkspaceWindowState window) {
    setState(() {
      _openWorkspaceWindows.removeWhere((item) => item.id == window.id);
      if (_openWorkspaceWindows.isNotEmpty) {
        final sorted = [..._openWorkspaceWindows]
          ..sort((a, b) => b.zIndex.compareTo(a.zIndex));
        selectedSection = sorted.first.section;
      }
    });
  }

  void _minimizeWorkspaceWindow(_WorkspaceWindowState window) {
    setState(() {
      window.minimized = true;
    });
  }

  void _toggleMaximizeWorkspaceWindow(_WorkspaceWindowState window) {
    setState(() {
      selectedSection = window.section;
      window.maximized = !window.maximized;
      window.minimized = false;
      window.zIndex = ++_workspaceWindowZCounter;
    });
  }

  void _moveWorkspaceWindow(
      _WorkspaceWindowState window, Offset delta, Size desktopSize) {
    setState(() {
      window.maximized = false;
      final maxX = math.max(8.0, desktopSize.width - window.size.width - 8);
      final maxY = math.max(8.0, desktopSize.height - window.size.height - 100);
      window.position = Offset(
        (window.position.dx + delta.dx).clamp(8.0, maxX).toDouble(),
        (window.position.dy + delta.dy).clamp(8.0, maxY).toDouble(),
      );
    });
  }

  void _resizeWorkspaceWindow(
      _WorkspaceWindowState window, Offset delta, Size desktopSize) {
    setState(() {
      window.maximized = false;
      final maxWidth =
          math.max(520.0, desktopSize.width - window.position.dx - 12);
      final maxHeight =
          math.max(420.0, desktopSize.height - window.position.dy - 102);
      window.size = Size(
        (window.size.width + delta.dx).clamp(520.0, maxWidth).toDouble(),
        (window.size.height + delta.dy).clamp(420.0, maxHeight).toDouble(),
      );
    });
  }

  void _setDesktopIconPosition(
      ClubSection section, Offset position, Size desktopSize) {
    setState(() {
      _desktopIconPositions[section] = Offset(
        position.dx
            .clamp(12.0, math.max(12.0, desktopSize.width - 112))
            .toDouble(),
        position.dy
            .clamp(12.0, math.max(12.0, desktopSize.height - 190))
            .toDouble(),
      );
    });
  }

  void _openWorkspaceSettings() {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(.18),
      builder: (dialogContext) {
        return _MacWorkspaceSettingsDialog(
          modules: _workspaceDesktopModules,
          dockSections: Set<ClubSection>.of(_dockSections),
          desktopSections: Set<ClubSection>.of(_desktopIconSections),
          showDesktopIcons: _showDesktopIcons,
          dockSize: _workspaceDockSize,
          wallpaperStyle: _workspaceWallpaperStyle,
          onShowDesktopIconsChanged: (value) {
            if (!mounted) return;
            setState(() => _showDesktopIcons = value);
          },
          onDockSizeChanged: (value) {
            if (!mounted) return;
            setState(() => _workspaceDockSize = value);
          },
          onWallpaperChanged: (value) {
            if (!mounted) return;
            setState(() => _workspaceWallpaperStyle = value);
          },
          onDockSectionsChanged: (value) {
            if (!mounted) return;
            setState(() {
              _dockSections
                ..clear()
                ..addAll(value);
            });
          },
          onDesktopSectionsChanged: (value) {
            if (!mounted) return;
            setState(() {
              _desktopIconSections
                ..clear()
                ..addAll(value);
            });
          },
        );
      },
    );
  }

  ThemeData _workspaceTheme(BuildContext context) {
    final base = Theme.of(context);
    final professional = _useProfessionalWorkspace(context);
    return base.copyWith(
      scaffoldBackgroundColor: _C.bg,
      visualDensity:
          professional ? VisualDensity.compact : VisualDensity.standard,
      materialTapTargetSize: professional
          ? MaterialTapTargetSize.shrinkWrap
          : MaterialTapTargetSize.padded,
      colorScheme: base.colorScheme.copyWith(
        primary: _C.primaryGreen,
        secondary: _C.blue,
        surface: _C.card,
      ),
      textTheme: base.textTheme
          .apply(
            fontFamily: AppTypography.fontFamily,
            bodyColor: _C.text,
            displayColor: _C.text,
          )
          .copyWith(
            titleLarge: _WorkspaceText.title,
            titleMedium: _WorkspaceText.section,
            bodyLarge: _WorkspaceText.rowTitle,
            bodyMedium: _WorkspaceText.caption.copyWith(fontSize: 13),
            bodySmall: _WorkspaceText.caption,
          ),
      primaryTextTheme: base.primaryTextTheme.apply(
        fontFamily: AppTypography.fontFamily,
        bodyColor: _C.text,
        displayColor: _C.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget child;
    if (loading) {
      child = const _WorkspaceLoadingScreen();
    } else if (_useProfessionalWorkspace(context)) {
      child = _buildWorkspace();
    } else {
      child = _buildMobileVersion();
    }

    return Theme(
      data: _workspaceTheme(context),
      child: child,
    );
  }

  Widget _buildMobileVersion() {
    _scheduleMobileGestureHint();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F6),
      extendBody: true,
      body: ColoredBox(
        color: const Color(0xFFF6F7F6),
        child: SafeArea(
          top: true,
          bottom: false,
          child: _buildMobileSwipeShell(),
        ),
      ),
      bottomNavigationBar: _buildMobileBottomNav(),
    );
  }

  Widget _buildMobileSwipeShell() {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity.abs() < 260) return;

        if (velocity < 0) {
          _goToNextMobileSection();
        } else {
          _goToPreviousMobileSection();
        }
      },
      child: _buildMobileContent(),
    );
  }

  void _goToNextMobileSection() {
    final index = _mobileSwipeSections.indexOf(selectedSection);
    if (index < 0) {
      setState(() => selectedSection = ClubSection.teams);
      return;
    }

    final nextIndex =
        (index + 1).clamp(0, _mobileSwipeSections.length - 1).toInt();
    if (nextIndex == index) return;
    setState(() => selectedSection = _mobileSwipeSections[nextIndex]);
  }

  void _goToPreviousMobileSection() {
    final index = _mobileSwipeSections.indexOf(selectedSection);
    if (index < 0) {
      setState(() => selectedSection = ClubSection.teams);
      return;
    }

    final previousIndex =
        (index - 1).clamp(0, _mobileSwipeSections.length - 1).toInt();
    if (previousIndex == index) return;
    setState(() => selectedSection = _mobileSwipeSections[previousIndex]);
  }

  void _scheduleMobileGestureHint() {
    if (_mobileGestureHintShown) return;
    _mobileGestureHintShown = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _useProfessionalWorkspace(context)) return;
      _showMobileGestureHint();
    });
  }

  void _showMobileGestureHint() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _MobileGestureHintSheet(),
    );
  }

  PreferredSizeWidget _buildMobileAppBar() {
    final fontSize = _getResponsiveFontSize(context, 18);
    return AppBar(
      automaticallyImplyLeading: false,
      leadingWidth: 58,
      leading: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Center(
          child: _BackCircleButton(onTap: _handleWorkspaceBack),
        ),
      ),
      title: Text(
        trainerAssignedMode ? 'Мой кабинет тренера' : 'Кабинет клуба',
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
        ),
      ),
      backgroundColor: Colors.white,
      foregroundColor: _C.text,
      elevation: 0,
      actions: [
        IconButton(
          onPressed: () => _loadAll(),
          icon: Icon(Icons.refresh_rounded,
              size: _getResponsiveFontSize(context, 24)),
          tooltip: 'Обновить',
        ),
      ],
    );
  }

  Widget _buildCmrGameZone({CmrGameZoneMode mode = CmrGameZoneMode.all}) {
    final activeTeamId = _activeTeamIdOrNull;
    if (activeTeamId == null) return const _NeedTeam();
    return CmrGameZonePanel(
      clubId: clubId,
      clubName: clubName,
      teamId: activeTeamId,
      teamName: selectedTeamName,
      userId: currentUserId,
      initialMode: mode,
    );
  }

  Widget _buildMobileContent() {
    // Контент остаётся на всю высоту и проходит под плавающим Dock.
    // Дополнительный запас прокрутки должен задаваться внутри списков панелей,
    // а не сплошной подложкой под нижним меню.
    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeOutCubic,
            child: Padding(
              key: ValueKey(
                  'mobile-${selectedSection.name}-${selectedTeamId ?? 0}'),
              padding: const EdgeInsets.fromLTRB(0, 4, 0, 6),
              child: _buildContent(),
            ),
          ),
        ),
        if (panelLoading || refreshing)
          const Positioned.fill(
            child: _WorkspacePanelLoadingOverlay(),
          ),
      ],
    );
  }

  Widget _MobileOverview({required double padding, required double fontSize}) {
    return RefreshIndicator(
      onRefresh: () => _loadAll(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildMobileBanner(fontSize),
            SizedBox(height: padding),
            _buildMobileStatsRow(fontSize),
            SizedBox(height: padding),
            _buildMobileCompletenessCard(fontSize),
            SizedBox(height: padding),
            _buildMobileTeamInfo(fontSize),
            SizedBox(height: padding),
            _buildMobileQuickActions(fontSize),
            SizedBox(height: padding),
            _buildMobileEvents(fontSize),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileBanner(double fontSize) {
    return Container(
      padding: EdgeInsets.all(fontSize * 1.2),
      decoration: _mobileCardDecoration(radius: 20),
      child: Column(
        children: [
          if (clubLogo != null && clubLogo!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                clubLogo!,
                height: 72,
                width: 72,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 72,
                  width: 72,
                  decoration: BoxDecoration(
                    color: _C.primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.shield_rounded,
                    color: _C.primaryGreen,
                    size: 36,
                  ),
                ),
              ),
            ),
          SizedBox(height: fontSize * 0.8),
          Text(
            clubName,
            style: TextStyle(
              fontSize: fontSize * 1.4,
              fontWeight: FontWeight.w700,
              color: _C.text,
              height: 1.1,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: fontSize * 0.4),
          Text(
            'Рабочий кабинет клуба',
            style: TextStyle(
              fontSize: fontSize * 0.85,
              color: _C.muted,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          if (clubDescription.trim().isNotEmpty) ...[
            SizedBox(height: fontSize * 0.45),
            Text(
              clubDescription.trim(),
              style: TextStyle(
                fontSize: fontSize * 0.78,
                color: _C.muted,
                height: 1.32,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          SizedBox(height: fontSize * 0.8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _SmallActionChip(
                icon: Icons.edit_rounded,
                label: 'Редактировать клуб',
                onTap: _openEditClubDialog,
              ),
              _SmallActionChip(
                icon: Icons.image_rounded,
                label: 'Логотип',
                onTap: _openEditClubDialog,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileCompletenessCard(double fontSize) {
    final items = <String>[];

    if (clubDescription.trim().isEmpty) items.add('Описание клуба');
    if (clubLogo == null || clubLogo!.trim().isEmpty)
      items.add('Логотип клуба');
    if (teams.isEmpty) items.add('Команды');
    if (trainers.isEmpty) items.add('Тренеры');
    if (selectedTeamId == null || selectedTeamId! <= 0)
      items.add('Активная команда');
    if (players.isEmpty) items.add('Игроки активной команды');
    if (events.isEmpty) items.add('События клуба');

    return Container(
      padding: EdgeInsets.all(fontSize),
      decoration: _mobileCardDecoration(radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  color: _C.primaryGreen, size: 22),
              SizedBox(width: fontSize * 0.5),
              Expanded(
                child: Text(
                  items.isEmpty
                      ? 'Профиль клуба заполнен'
                      : 'Что желательно заполнить',
                  style: TextStyle(
                    fontSize: fontSize * 1.02,
                    fontWeight: FontWeight.w700,
                    color: _C.text,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: fontSize * 0.55),
          Text(
            items.isEmpty
                ? 'Основные данные выглядят аккуратно. Можно переходить к работе с командой.'
                : 'Эти пункты помогут сделать экран клуба понятнее для тренеров, игроков и родителей.',
            style: TextStyle(
              color: _C.muted,
              fontSize: fontSize * 0.78,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: fontSize * 0.7),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: (items.isEmpty ? ['Готово'] : items).map((item) {
              return Container(
                padding: EdgeInsets.symmetric(
                  horizontal: fontSize * 0.65,
                  vertical: fontSize * 0.42,
                ),
                decoration: BoxDecoration(
                  color: items.isEmpty
                      ? _C.primaryGreen.withOpacity(0.1)
                      : _C.soft2,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: items.isEmpty
                        ? _C.primaryGreen.withOpacity(0.25)
                        : _C.border,
                  ),
                ),
                child: Text(
                  item,
                  style: TextStyle(
                    color: items.isEmpty ? _C.primaryGreen : _C.text,
                    fontSize: fontSize * 0.72,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileStatsRow(double fontSize) {
    return Container(
      padding: EdgeInsets.all(fontSize * 0.8),
      decoration: _mobileCardDecoration(radius: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Expanded(
              child: _buildMobileStat(
            value: '${teams.length}',
            label: 'Команды',
            icon: Icons.account_tree_rounded,
            color: _C.blue,
            fontSize: fontSize,
          )),
          Expanded(
              child: _buildMobileStat(
            value: '${players.length}',
            label: 'Игроки',
            icon: Icons.groups_2_rounded,
            color: _C.primaryGreen,
            fontSize: fontSize,
          )),
          Expanded(
              child: _buildMobileStat(
            value: '${trainers.length}',
            label: 'Тренеры',
            icon: Icons.badge_rounded,
            color: _C.purple,
            fontSize: fontSize,
          )),
          Expanded(
              child: _buildMobileStat(
            value: '${events.length}',
            label: 'События',
            icon: Icons.event_available_rounded,
            color: _C.orange,
            fontSize: fontSize,
          )),
        ],
      ),
    );
  }

  Widget _buildMobileStat({
    required String value,
    required String label,
    required IconData icon,
    required Color color,
    required double fontSize,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        SizedBox(height: fontSize * 0.3),
        Text(
          value,
          style: TextStyle(
            fontSize: fontSize * 1.2,
            fontWeight: FontWeight.w700,
            color: _C.text,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize * 0.7,
            color: _C.muted,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildMobileTeamInfo(double fontSize) {
    return Container(
      padding: EdgeInsets.all(fontSize),
      decoration: _mobileCardDecoration(radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_rounded,
                  color: _C.footballGreen, size: 22),
              SizedBox(width: fontSize * 0.5),
              Text(
                'Активная команда',
                style: TextStyle(
                  fontSize: fontSize * 1.1,
                  fontWeight: FontWeight.w700,
                  color: _C.text,
                ),
              ),
            ],
          ),
          SizedBox(height: fontSize * 0.6),
          Container(
            padding: EdgeInsets.all(fontSize * 0.6),
            decoration: BoxDecoration(
              color: _C.footballGreenSoft,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _C.footballGreen.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    selectedTeamName,
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w600,
                      color: _C.text,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: fontSize * 0.5),
                Text(
                  '${players.length} игроков',
                  style: TextStyle(
                    fontSize: fontSize * 0.8,
                    color: _C.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: fontSize * 0.8),
          Row(
            children: [
              Expanded(
                child: _MobileActionButton(
                  icon: Icons.swap_horiz_rounded,
                  label: 'Сменить',
                  onTap: () =>
                      setState(() => selectedSection = ClubSection.teams),
                  fontSize: fontSize,
                ),
              ),
              SizedBox(width: fontSize * 0.5),
              Expanded(
                child: _MobileActionButton(
                  icon: Icons.groups_2_rounded,
                  label: 'Состав',
                  onTap: () =>
                      setState(() => selectedSection = ClubSection.roster),
                  fontSize: fontSize,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _MobileActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required double fontSize,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: fontSize * 0.55,
          horizontal: fontSize * 0.65,
        ),
        decoration: BoxDecoration(
          color: _C.primaryGreen,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF374151), size: fontSize),
            SizedBox(width: fontSize * 0.25),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: fontSize * 0.78,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileQuickActions(double fontSize) {
    final actions = [
      {
        'icon': Icons.badge_rounded,
        'label': 'Тренеры',
        'section': ClubSection.trainers,
        'color': _C.purple,
      },
      {
        'icon': Icons.sports_soccer_rounded,
        'label': 'Матчи',
        'section': ClubSection.matches,
        'color': _C.orange,
      },
      {
        'icon': Icons.calendar_month_rounded,
        'label': 'Календарь',
        'section': ClubSection.calendar,
        'color': _C.teal,
      },
      {
        'icon': Icons.folder_copy_rounded,
        'label': 'Планы',
        'section': ClubSection.plans,
        'color': _C.blue,
      },
      {
        'icon': Icons.science_rounded,
        'label': 'Тестирование',
        'section': ClubSection.testing,
        'color': _C.greenDark,
      },
      {
        'icon': Icons.sensors_rounded,
        'label': 'Трекер',
        'section': ClubSection.tracker,
        'color': _C.greenDark,
      },
      {
        'icon': Icons.forum_rounded,
        'label': 'Чаты',
        'section': ClubSection.chat,
        'color': _C.greenDark,
      },
      {
        'icon': Icons.psychology_alt_rounded,
        'label': 'Менеджер',
        'section': ClubSection.manager,
        'color': _C.teal,
      },
    ];

    return Container(
      padding: EdgeInsets.all(fontSize),
      decoration: _mobileCardDecoration(radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Быстрые действия',
            style: TextStyle(
              fontSize: fontSize * 1.1,
              fontWeight: FontWeight.w700,
              color: _C.text,
            ),
          ),
          SizedBox(height: fontSize * 0.8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: fontSize * 0.5,
              crossAxisSpacing: fontSize * 0.5,
              childAspectRatio: 1.18,
            ),
            itemCount: actions.length,
            itemBuilder: (context, index) {
              final action = actions[index];
              return _buildQuickActionCard(
                icon: action['icon'] as IconData,
                label: action['label'] as String,
                section: action['section'] as ClubSection,
                color: action['color'] as Color,
                fontSize: fontSize,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String label,
    required ClubSection section,
    required Color color,
    required double fontSize,
  }) {
    return InkWell(
      onTap: () => _openGameModule(section),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: fontSize * 1.5),
            SizedBox(height: fontSize * 0.3),
            Text(
              label,
              style: TextStyle(
                fontSize: fontSize * 0.61,
                fontWeight: FontWeight.w600,
                color: _C.text,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileEvents(double fontSize) {
    if (events.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(fontSize),
      decoration: _mobileCardDecoration(radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ближайшие события',
            style: TextStyle(
              fontSize: fontSize * 1.1,
              fontWeight: FontWeight.w700,
              color: _C.text,
            ),
          ),
          SizedBox(height: fontSize * 0.6),
          ...events.take(3).map((event) {
            final title =
                _asString(event['title'] ?? event['name']) ?? 'Событие';
            final date = _asString(event['date'] ??
                    event['event_date'] ??
                    event['start_date']) ??
                'Дата не указана';
            return Container(
              margin: EdgeInsets.only(bottom: fontSize * 0.5),
              padding: EdgeInsets.all(fontSize * 0.6),
              decoration: BoxDecoration(
                color: _C.soft2,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _C.teal,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: fontSize * 0.5),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: fontSize * 0.9,
                            fontWeight: FontWeight.w700,
                            color: _C.text,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          date,
                          style: TextStyle(
                            fontSize: fontSize * 0.75,
                            color: _C.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _MobileTeams({required double padding, required double fontSize}) {
    return Column(
      children: [
        Container(
          margin: EdgeInsets.all(padding),
          padding: EdgeInsets.all(fontSize * 0.8),
          decoration: _mobileCardDecoration(radius: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Команды клуба',
                  style: TextStyle(
                    fontSize: fontSize * 1.2,
                    fontWeight: FontWeight.w700,
                    color: _C.text,
                  ),
                ),
              ),
              IconButton(
                onPressed: _openCreateTeam,
                icon: Icon(Icons.add_circle_rounded,
                    color: _C.primaryGreen, size: fontSize * 1.8),
              ),
            ],
          ),
        ),
        Expanded(
          child: teams.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.account_tree_rounded,
                          size: fontSize * 3, color: _C.muted),
                      SizedBox(height: padding),
                      Text(
                        'Нет команд',
                        style: TextStyle(fontSize: fontSize, color: _C.muted),
                      ),
                      SizedBox(height: padding),
                      ElevatedButton.icon(
                        onPressed: _openCreateTeam,
                        icon: const Icon(Icons.add),
                        label: const Text('Создать команду'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _C.primaryGreen,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: padding * 1.5,
                            vertical: padding,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _loadAll(),
                  child: ListView.builder(
                    padding: EdgeInsets.all(padding),
                    itemCount: teams.length,
                    itemBuilder: (context, index) {
                      final team = teams[index];
                      final id = _asInt(team['id'] ?? team['team_id']);
                      final name = _asString(team['name']) ?? 'Команда';
                      final subtitle = _asString(team['age_group']) ?? 'Футбол';
                      final logo = _asString(team['logo']);
                      final isActive = id == selectedTeamId;

                      return Card(
                        margin: EdgeInsets.only(bottom: padding * 0.75),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: isActive
                                ? _C.primaryGreen.withOpacity(0.3)
                                : _C.border,
                            width: isActive ? 1.5 : 1,
                          ),
                        ),
                        elevation: isActive ? 4 : 1,
                        child: ListTile(
                          contentPadding: EdgeInsets.all(padding * 0.75),
                          leading: CircleAvatar(
                            radius: 28,
                            backgroundColor: _C.soft,
                            backgroundImage: logo != null && logo.isNotEmpty
                                ? NetworkImage(logo)
                                : null,
                            child: logo == null || logo.isEmpty
                                ? Icon(Icons.shield_rounded,
                                    color: _C.primaryGreen, size: 28)
                                : null,
                          ),
                          title: Text(
                            name,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: fontSize,
                              color: isActive ? _C.primaryGreen : _C.text,
                            ),
                          ),
                          subtitle: Text(
                            subtitle,
                            style: TextStyle(fontSize: fontSize * 0.8),
                          ),
                          trailing: isActive
                              ? Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: padding * 0.5,
                                    vertical: padding * 0.25,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _C.primaryGreen.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    'Активна',
                                    style: TextStyle(
                                      color: _C.primaryGreen,
                                      fontSize: fontSize * 0.7,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                )
                              : null,
                          onTap: () => _selectTeam(team),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _MobileRoster({required double padding, required double fontSize}) {
    if (!_hasTeam) return const _NeedTeam();

    if (loadingPlayers) {
      return const Center(
          child: CircularProgressIndicator(color: _C.primaryGreen));
    }

    return Column(
      children: [
        Container(
          margin: EdgeInsets.all(padding),
          padding: EdgeInsets.all(fontSize * 0.8),
          decoration: _mobileCardDecoration(radius: 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Состав команды',
                      style: TextStyle(
                        fontSize: fontSize * 1.1,
                        fontWeight: FontWeight.w700,
                        color: _C.text,
                      ),
                    ),
                    SizedBox(height: fontSize * 0.2),
                    Text(
                      selectedTeamName,
                      style: TextStyle(
                        fontSize: fontSize * 0.85,
                        color: _C.muted,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () {
                      if (selectedTeamId != null && selectedTeamId! > 0) {
                        Get.toNamed(
                          AppRoutes.addPlayerScreen,
                          arguments: {
                            'team_id': selectedTeamId,
                            'teamId': selectedTeamId,
                            'club_id': clubId,
                            'clubId': clubId,
                            'team_name': selectedTeamName,
                            'teamName': selectedTeamName,
                          },
                        )?.then((_) {
                          if (selectedTeamId != null) {
                            _loadPlayersForTeam(selectedTeamId!);
                          }
                        });
                      } else {
                        Get.snackbar('Команда', 'Сначала выберите команду');
                      }
                    },
                    icon: Icon(Icons.person_add_alt_1_rounded,
                        color: _C.primaryGreen, size: fontSize * 1.4),
                  ),
                  SizedBox(width: padding * 0.25),
                  IconButton(
                    onPressed: _openFullRosterScreen,
                    icon: Icon(Icons.open_in_new_rounded,
                        color: _C.primaryGreen, size: fontSize * 1.4),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: players.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_search_rounded,
                          size: fontSize * 3, color: _C.muted),
                      SizedBox(height: padding),
                      Text(
                        'Игроки не найдены',
                        style: TextStyle(fontSize: fontSize, color: _C.muted),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => selectedTeamId != null
                      ? _loadPlayersForTeam(selectedTeamId!)
                      : Future.value(),
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: padding),
                    itemCount: players.length,
                    itemBuilder: (context, index) {
                      final player = players[index];
                      final first = _asString(player['first_name']) ?? '';
                      final last = _asString(player['last_name']) ?? '';
                      final name = '$first $last'.trim().isEmpty
                          ? 'Игрок'
                          : '$first $last';
                      final position =
                          _asString(player['position']) ?? 'Амплуа';
                      final photo = _asString(player['photo']);
                      final isActive = selectedPlayer?['id'] == player['id'];

                      return Card(
                        margin: EdgeInsets.only(bottom: padding * 0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color:
                                isActive ? _C.blue.withOpacity(0.3) : _C.border,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: padding * 0.75,
                            vertical: padding * 0.3,
                          ),
                          leading: CircleAvatar(
                            radius: 22,
                            backgroundColor: _C.soft,
                            backgroundImage: photo != null && photo.isNotEmpty
                                ? NetworkImage(photo)
                                : null,
                            child: photo == null || photo.isEmpty
                                ? Icon(Icons.person, color: _C.muted, size: 22)
                                : null,
                          ),
                          title: Text(
                            name,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: fontSize * 0.95,
                              color: isActive ? _C.blue : _C.text,
                            ),
                          ),
                          subtitle: Text(
                            position,
                            style: TextStyle(fontSize: fontSize * 0.8),
                          ),
                          trailing: isActive
                              ? const Icon(
                                  Icons.check_circle,
                                  color: _C.blue,
                                  size: 20,
                                )
                              : const Icon(
                                  Icons.chevron_right,
                                  color: _C.muted,
                                  size: 20,
                                ),
                          onTap: () => _openPlayerProfile(player),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _MobileTrainings({required double padding, required double fontSize}) {
    if (!_hasTeam) return const _NeedTeam();

    final modules = [
      {
        'icon': Icons.folder_copy_rounded,
        'title': 'Планы-конспекты',
        'section': ClubSection.plans,
        'color': _C.blue,
      },
      {
        'icon': Icons.draw_rounded,
        'title': 'Графика',
        'section': ClubSection.graphics,
        'color': _C.purple,
      },
      {
        'icon': Icons.calendar_month_rounded,
        'title': 'Календарь',
        'section': ClubSection.calendar,
        'color': _C.teal,
      },
      {
        'icon': Icons.fact_check_rounded,
        'title': 'Посещаемость',
        'section': ClubSection.attendance,
        'color': _C.orange,
      },
      {
        'icon': Icons.science_rounded,
        'title': 'Тестирование',
        'section': ClubSection.testing,
        'color': _C.greenDark,
      },
      {
        'icon': Icons.psychology_alt_rounded,
        'title': 'Менеджер',
        'section': ClubSection.manager,
        'color': _C.teal,
      },
      {
        'icon': Icons.videogame_asset_rounded,
        'title': 'Игровая зона',
        'section': ClubSection.miniGames,
        'color': _C.teal,
      },
      {
        'icon': Icons.badge_rounded,
        'title': 'Тренеры клуба',
        'section': ClubSection.trainers,
        'color': _C.purple,
      },
    ];

    return GridView.builder(
      padding: EdgeInsets.all(padding),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: padding,
        crossAxisSpacing: padding,
        childAspectRatio: 1.3,
      ),
      itemCount: modules.length,
      itemBuilder: (context, index) {
        final module = modules[index];
        return _buildMobileModuleCard(
          icon: module['icon'] as IconData,
          title: module['title'] as String,
          section: module['section'] as ClubSection,
          color: module['color'] as Color,
          fontSize: fontSize,
        );
      },
    );
  }

  Widget _buildMobileModuleCard({
    required IconData icon,
    required String title,
    required ClubSection section,
    required Color color,
    required double fontSize,
  }) {
    return InkWell(
      onTap: () => setState(() => selectedSection = section),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: _mobileCardDecoration(radius: 18),
        padding: EdgeInsets.all(fontSize * 0.7),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: fontSize * 3.2,
              height: fontSize * 3.2,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: fontSize * 1.8),
            ),
            SizedBox(height: fontSize * 0.6),
            Text(
              title,
              style: TextStyle(
                fontSize: fontSize * 0.85,
                fontWeight: FontWeight.w700,
                color: _C.text,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  double _mobileBottomDockInset(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return bottom > 0 ? math.max(12.0, math.min(16.0, bottom * .45)) : 10.0;
  }

  double _mobileBottomDockReservedHeight(BuildContext context) {
    const dockHeight = 56.0;
    const breathingRoom = 10.0;
    return dockHeight + _mobileBottomDockInset(context) + breathingRoom;
  }

  Widget _buildMobileBottomNav() {
    final width = MediaQuery.of(context).size.width;
    final horizontal = width < 380 ? 14.0 : 22.0;
    final activeIndex = _mobileBottomMenuIndex();

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
                color: active ? const Color(0xB8EAF8F0) : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Icon(
                    icon,
                    size: active ? 22 : 21,
                    color: active
                        ? const Color(0xFF111827)
                        : const Color(0xFF344054),
                  ),
                  if (badge > 0)
                    Positioned(
                      top: 1,
                      right: active ? 6 : 0,
                      child: Container(
                        constraints:
                            const BoxConstraints(minWidth: 16, minHeight: 16),
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

    // В Workspace панель должна быть чуть выше края, иначе выглядит прилипшей к низу.
    // Держим её ниже, чем старый вариант, но выше текущего слишком низкого положения.
    final bottomInset = _mobileBottomDockInset(context);

    return SafeArea(
      top: false,
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(horizontal, 0, horizontal, bottomInset),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 7),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.72),
                borderRadius: BorderRadius.circular(30),
                border:
                    Border.all(color: Colors.white.withOpacity(.92), width: .9),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(.10),
                    blurRadius: 30,
                    spreadRadius: -12,
                    offset: const Offset(0, 14),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(.04),
                    blurRadius: 8,
                    spreadRadius: -5,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  dockIcon(
                      index: 0,
                      icon: Icons.home_rounded,
                      onTap: () => _activateInlineSection(ClubSection.teams)),
                  dockIcon(
                      index: 1,
                      icon: Icons.groups_2_outlined,
                      onTap: () => _activateInlineSection(ClubSection.roster)),
                  dockIcon(
                      index: 2,
                      icon: Icons.sports_soccer_outlined,
                      onTap: () => _activateInlineSection(ClubSection.matches)),
                  dockIcon(
                      index: 3,
                      icon: Icons.calendar_month_outlined,
                      onTap: () =>
                          _activateInlineSection(ClubSection.calendar)),
                  dockIcon(
                      index: 4,
                      icon: Icons.forum_outlined,
                      badge: _chatUnreadCount,
                      onTap: () => _activateInlineSection(ClubSection.chat)),
                  dockIcon(
                      index: 5,
                      icon: Icons.more_horiz_rounded,
                      onTap: _openMobileMoreMenu),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  int _mobileBottomMenuIndex() {
    if (selectedSection == ClubSection.teams ||
        selectedSection == ClubSection.teamDashboard ||
        selectedSection == ClubSection.overview) {
      return 0;
    }

    if (selectedSection == ClubSection.roster ||
        selectedSection == ClubSection.playerProfile) {
      return 1;
    }

    if (selectedSection == ClubSection.matches ||
        selectedSection == ClubSection.videoAnalysis) {
      return 2;
    }

    if (selectedSection == ClubSection.calendar ||
        selectedSection == ClubSection.attendance ||
        selectedSection == ClubSection.testing) {
      return 3;
    }

    if (selectedSection == ClubSection.chat) return 4;

    return 5;
  }

  void _handleMobileBottomTap(int index) {
    switch (index) {
      case 0:
        _activateInlineSection(ClubSection.teams);
        return;
      case 1:
        _activateInlineSection(ClubSection.roster);
        return;
      case 2:
        _activateInlineSection(ClubSection.matches);
        return;
      case 3:
        _activateInlineSection(ClubSection.calendar);
        return;
      case 4:
        _activateInlineSection(ClubSection.chat);
        return;
      case 5:
        _openMobileMoreMenu();
        return;
    }
  }

  void _openMobileMoreMenu() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _MobileMoreBottomSheet(
          clubName: clubName,
          clubLogo: clubLogo,
          selectedTeamName: selectedTeamName,
          trainerMode: trainerAssignedMode,
          hasTeam: _hasTeam,
          currentSection: selectedSection,
          groups: _clubWorkspaceNavGroups,
          hasActiveSubscription: hasActiveSubscription,
          onSportotekaOs: () {
            Navigator.of(sheetContext).pop();
            Future<void>.delayed(
              const Duration(milliseconds: 80),
              () => _activateInlineSection(ClubSection.finder),
            );
          },
          onWorkspace: () {
            Navigator.of(sheetContext).pop();
            Future<void>.delayed(
              const Duration(milliseconds: 80),
              _goHomeFromWorkspace,
            );
          },
          onSelect: (section) {
            Navigator.of(sheetContext).pop();
            _openGameModule(section);
          },
        );
      },
    );
  }

  Widget _buildMoreNavItem({required double fontSize}) {
    final moreSections = <ClubSection>{
      for (final group in _clubWorkspaceNavGroups)
        for (final item in group.items) item.section,
      ClubSection.teamTrainers,
      ClubSection.playerProfile,
    };
    final isActive = moreSections.contains(selectedSection);

    return Expanded(
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: _openMobileMoreMenu,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 38,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isActive
                        ? _C.primaryGreen.withOpacity(.10)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    Icons.grid_view_rounded,
                    size: 21,
                    color: isActive ? _C.primaryGreen : _C.muted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Ещё',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: fontSize,
                    height: 1.0,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w600,
                    color: isActive ? _C.primaryGreen : _C.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _isSectionVisibleActive(ClubSection section) {
    if (selectedSection == section) return true;

    if (section == ClubSection.roster &&
        selectedSection == ClubSection.playerProfile) {
      return true;
    }

    if (section == ClubSection.trainers &&
        selectedSection == ClubSection.teamTrainers) {
      return true;
    }

    return false;
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required ClubSection section,
    required double fontSize,
  }) {
    final isActive = _isSectionVisibleActive(section);
    return Expanded(
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => setState(() => selectedSection = section),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 38,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isActive
                        ? _C.primaryGreen.withOpacity(.10)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    icon,
                    size: 21,
                    color: isActive ? _C.primaryGreen : _C.muted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: fontSize,
                    height: 1.0,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w600,
                    color: isActive ? _C.primaryGreen : _C.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration _mobileCardDecoration({double radius = 16}) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  bool _clubContextAiSupported(ClubSection section) {
    if (clubId <= 0 || currentUserId <= 0) return false;
    return section != ClubSection.chat &&
        section != ClubSection.tracker &&
        section != ClubSection.settings &&
        section != ClubSection.coachDashboard;
  }

  int? _contextAiPlayerId() {
    final raw = selectedPlayer?['id'] ??
        selectedPlayer?['player_id'] ??
        selectedPlayer?['playerId'];
    final value = raw is int ? raw : int.tryParse('${raw ?? ''}');
    return value != null && value > 0 ? value : null;
  }

  String? _contextAiPlayerName() {
    final value =
        '${selectedPlayer?['name'] ?? selectedPlayer?['full_name'] ?? selectedPlayer?['player_name'] ?? ''}'
            .trim();
    return value.isEmpty ? null : value;
  }

  String _clubContextAiPrompt(ClubSection section) {
    final playerName = _contextAiPlayerName();
    final sectionName = _titleFor(section);
    switch (section) {
      case ClubSection.overview:
        return 'Сделай ИИ-сводку дня по клубу «$clubName» и команде «$selectedTeamName». '
            'Покажи три блока: «Что происходит», «Почему это важно» и «Что сделать тренеру сегодня». '
            'Учитывай календарь, матчи, тренировки, состав, тестирование и GPS/Polar. Используй только проверенные данные.';
      case ClubSection.teams:
      case ClubSection.teamDashboard:
        return 'Проанализируй текущую команду «$selectedTeamName»: готовность, динамику нагрузки, ближайшие события и риски. '
            'Дай три приоритетных действия тренеру и объясни каждое только по проверенным данным.';
      case ClubSection.roster:
      case ClubSection.playerProfile:
        return playerName == null
            ? 'Проанализируй состав команды «$selectedTeamName». Выдели игроков с риском перегрузки, недостатком данных или отрицательной динамикой и предложи действия тренеру.'
            : 'Сделай контекстный ИИ-профиль игрока $playerName: текущая динамика, нагрузка, восстановление, риски и конкретная рекомендация тренеру. Используй только данные этого игрока.';
      case ClubSection.matches:
      case ClubSection.videoAnalysis:
        return 'Проанализируй контекст раздела «$sectionName» команды «$selectedTeamName»: последние результаты, нагрузку, доступные ТТД/видео и подготовку к следующему матчу. Дай наблюдения, причины и действия.';
      case ClubSection.calendar:
      case ClubSection.trainings:
      case ClubSection.attendance:
        return 'Проанализируй расписание и тренировочный контекст команды «$selectedTeamName». Найди конфликты нагрузки, посещаемости и восстановления, затем предложи безопасные действия. Ничего не изменяй без отдельного подтверждения.';
      case ClubSection.testing:
        return 'Проанализируй тестирование команды «$selectedTeamName»: динамику, лидеров, отстающих и связь результатов с последними тренировками. Дай конкретные рекомендации тренеру.';
      case ClubSection.plans:
      case ClubSection.graphics:
        return 'Предложи следующий тренировочный план для команды «$selectedTeamName» с учётом проверенных данных нагрузки, календаря и выявленных рисков. Объясни цель каждого блока.';
      default:
        return 'Проанализируй текущий раздел «$sectionName» команды «$selectedTeamName». Дай три коротких блока: «Что происходит», «Почему» и «Что делать тренеру». Используй только проверенные данные.';
    }
  }

  Map<String, dynamic> _clubContextAiPayload(ClubSection section) {
    final playerId = _contextAiPlayerId();
    final playerName = _contextAiPlayerName();
    final playerFocused = playerId != null &&
        (section == ClubSection.roster || section == ClubSection.playerProfile);
    return <String, dynamic>{
      'source': 'club_workspace_context_layer',
      'workspace_section': section.name,
      'workspace_section_title': _titleFor(section),
      'club_id': clubId,
      'club_name': clubName,
      if ((selectedTeamId ?? 0) > 0) 'team_id': selectedTeamId,
      'team_name': selectedTeamName,
      if (playerFocused) 'player_id': playerId,
      if (playerFocused && playerName != null) 'player_name': playerName,
      'selection_mode': playerFocused ? 'single_player' : 'team',
      'visible_counts': <String, dynamic>{
        'teams': teams.length,
        'players': players.length,
        'trainers': trainers.length,
        'events': events.length,
        'plans': latestPlans.length,
      },
      'response_contract': const <String>[
        'what_happens',
        'why',
        'coach_action',
      ],
    };
  }

  Widget _withClubContextAiLayer(
    Widget child, {
    required double bottomInset,
  }) {
    final section = selectedSection;
    if (!_clubContextAiSupported(section)) return child;

    final expanded = _contextAiExpanded ?? false;
    final playerId = _contextAiPlayerId();
    final playerName = _contextAiPlayerName();
    final playerOnly = playerId != null &&
        (section == ClubSection.roster || section == ClubSection.playerProfile);

    return CmrContextAiLayer(
      child: child,
      expanded: expanded,
      onToggle: () {
        setState(() {
          final next = !expanded;
          _contextAiExpanded = next;
          if (next) _contextAiRevision++;
        });
      },
      clubId: clubId,
      userId: currentUserId,
      teamId: selectedTeamId,
      clubName: clubName,
      teamName: selectedTeamName,
      contextTitle: _titleFor(section),
      contextSubtitle:
          playerOnly && playerName != null ? playerName : selectedTeamName,
      initialPrompt: _clubContextAiPrompt(section),
      initialPayload: _clubContextAiPayload(section),
      panelKey: ValueKey<String>(
        'club_context_ai_${section.name}_${selectedTeamId ?? 0}_${playerId ?? 0}_$_contextAiRevision',
      ),
      bottomInset: bottomInset,
      playerOnlyMode: playerOnly,
      playerId: playerOnly ? playerId : null,
      playerName: playerOnly ? playerName : null,
      onNavigate: _handleAiNavigate,
      onOpenPdf: _handleAiOpenDocument,
    );
  }

  Widget _buildWorkspace() {
    return Scaffold(
      backgroundColor: _C.bg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = _isDesktopWide(context);
            final sidePadding = wide ? 14.0 : 10.0;
            final contentPadding = EdgeInsets.fromLTRB(
              sidePadding,
              wide ? 12 : 8,
              sidePadding,
              wide ? 98 : 92,
            );
            final desktopSize =
                Size(constraints.maxWidth, constraints.maxHeight);

            return AnimatedBuilder(
              animation: _introController,
              builder: (context, _) {
                final appValue = CurvedAnimation(
                  parent: _introController,
                  curve: const Interval(.64, 1, curve: Curves.easeOutCubic),
                ).value;

                return Stack(
                  children: [
                    Opacity(
                      opacity: appValue,
                      child: Transform.scale(
                        scale: .982 + (.018 * appValue),
                        child: Transform.translate(
                          offset: Offset(0, 14 * (1 - appValue)),
                          child: wide
                              ? _buildDesktopWindowWorkspace(desktopSize)
                              : _buildInlineWorkspace(contentPadding, wide),
                        ),
                      ),
                    ),
                    if (!_introFinished)
                      Positioned.fill(
                        child: _ClubIntroSplash(animation: _introController),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildInlineWorkspace(EdgeInsets contentPadding, bool wide) {
    return _withClubContextAiLayer(
      Stack(
        children: [
          Positioned.fill(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Padding(
                key: ValueKey(selectedSection.name),
                padding: contentPadding,
                child: _buildContent(),
              ),
            ),
          ),
          if (panelLoading || refreshing)
            const Positioned.fill(
              bottom: 84,
              child: _WorkspacePanelLoadingOverlay(),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: wide ? 14 : 10,
            child: _DesktopWorkspaceTaskbar(
              clubName: clubName,
              clubLogo: clubLogo,
              selectedTeamName: selectedTeamName,
              selectedSection: selectedSection,
              hasActiveSubscription: hasActiveSubscription,
              onStart: _openFullModulesMenu,
              onSearch: _openDesktopCommandMenu,
              onSelect: _activateInlineSection,
              onHome: _goHomeFromWorkspace,
              onRefresh: () => _loadAll(),
            ),
          ),
        ],
      ),
      bottomInset: wide ? 94 : 82,
    );
  }

  Widget _buildDesktopWindowWorkspace(Size desktopSize) {
    final visibleWindows = _openWorkspaceWindows
        .where((window) => !window.minimized)
        .toList(growable: false)
      ..sort((a, b) => a.zIndex.compareTo(b.zIndex));

    return _withClubContextAiLayer(
      Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: _WorkspaceWallpaper(
              style: _workspaceWallpaperStyle,
              clubName: clubName,
              clubLogo: clubLogo,
            ),
          ),
          if (_showDesktopIcons)
            Positioned.fill(
              child: _WorkspaceDesktopIconsLayer(
                desktopSize: desktopSize,
                items: _workspaceDesktopIcons,
                iconPositions: _desktopIconPositions,
                onOpen: _openModuleWindow,
                onMoved: _setDesktopIconPosition,
              ),
            ),
          for (final window in visibleWindows)
            _buildPositionedWorkspaceWindow(window, desktopSize),
          if (panelLoading || refreshing)
            const Positioned.fill(
              bottom: 84,
              child: _WorkspacePanelLoadingOverlay(),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 14,
            child: _WorkspaceDock(
              clubName: clubName,
              clubLogo: clubLogo,
              selectedTeamName: selectedTeamName,
              dockSize: _workspaceDockSize,
              pinnedItems: _workspaceDockItems,
              openWindows: _openWorkspaceWindows,
              activeSection: selectedSection,
              onOpenStart: _openFullModulesMenu,
              onOpenSearch: _openDesktopCommandMenu,
              onOpenSettings: _openWorkspaceSettings,
              onOpenHome: _goHomeFromWorkspace,
              onRefresh: () => _loadAll(),
              onOpenSection: _openModuleWindow,
            ),
          ),
        ],
      ),
      bottomInset: 94,
    );
  }

  Widget _buildWorkspaceWindowContent(_WorkspaceWindowState window) {
    if (window.section == ClubSection.playerProfile &&
        window.playerPayload != null) {
      return CmrPlayerProfileScreen(
        player: window.playerPayload!,
        embeddedInWorkspace: true,
      );
    }

    return _buildSectionContent(window.section);
  }

  Widget _buildPositionedWorkspaceWindow(
    _WorkspaceWindowState window,
    Size desktopSize,
  ) {
    final active = selectedSection == window.section;
    final minWidth = math.min(520.0, math.max(360.0, desktopSize.width - 24));
    final minHeight =
        math.min(420.0, math.max(300.0, desktopSize.height - 112));
    final safeWidth = window.size.width
        .clamp(minWidth, math.max(minWidth, desktopSize.width - 24))
        .toDouble();
    final safeHeight = window.size.height
        .clamp(minHeight, math.max(minHeight, desktopSize.height - 106))
        .toDouble();
    final maxLeft = math.max(8.0, desktopSize.width - safeWidth - 8);
    final maxTop = math.max(8.0, desktopSize.height - safeHeight - 96);
    final left = window.position.dx.clamp(8.0, maxLeft).toDouble();
    final top = window.position.dy.clamp(8.0, maxTop).toDouble();
    final item = _workspaceItemFor(window.section);
    final windowTitle = window.titleOverride ?? item.title;
    final windowSubtitle = window.subtitleOverride ?? selectedTeamName;
    final windowIcon = window.iconOverride ?? item.icon;

    final windowWidget = _WorkspaceFloatingWindow(
      title: windowTitle,
      subtitle: windowSubtitle,
      icon: windowIcon,
      active: active,
      maximized: window.maximized,
      onTap: () => _bringWorkspaceWindowToFront(window),
      onClose: () => _closeWorkspaceWindow(window),
      onMinimize: () => _minimizeWorkspaceWindow(window),
      onMaximize: () => _toggleMaximizeWorkspaceWindow(window),
      onDragUpdate: (delta) => _moveWorkspaceWindow(window, delta, desktopSize),
      onResizeUpdate: (delta) =>
          _resizeWorkspaceWindow(window, delta, desktopSize),
      child: _buildWorkspaceWindowContent(window),
    );

    if (window.maximized) {
      return Positioned(
        left: 12,
        top: 12,
        right: 12,
        bottom: 92,
        child: windowWidget,
      );
    }

    return Positioned(
      left: left,
      top: top,
      width: safeWidth,
      height: safeHeight,
      child: windowWidget,
    );
  }

  String _titleFor(ClubSection section) {
    switch (section) {
      case ClubSection.coachDashboard:
        return 'Панель трекера';
      case ClubSection.overview:
        return 'Рабочий кабинет клуба';
      case ClubSection.finder:
        return 'Спортотека OS';
      case ClubSection.teams:
        return 'Команды клуба';
      case ClubSection.teamDashboard:
        return selectedTeamName;
      case ClubSection.roster:
        return 'Состав команды';
      case ClubSection.trainers:
        return 'Тренеры клуба';
      case ClubSection.teamTrainers:
        return 'Тренеры команды';
      case ClubSection.playerProfile:
        return 'Профиль игрока';
      case ClubSection.matches:
        return 'Матчи';
      case ClubSection.calendar:
        return 'Календарь';
      case ClubSection.trainings:
        return 'Тренировки';
      case ClubSection.plans:
        return 'Планы-конспекты';
      case ClubSection.graphics:
        return 'Графический редактор';
      case ClubSection.tracker:
        return 'Трекер команды';
      case ClubSection.videoAnalysis:
        return 'Видеоанализ';
      case ClubSection.description:
        return 'Визитка команды';
      case ClubSection.chat:
        return 'Чаты';
      case ClubSection.videoLessons:
        return 'Видеоуроки';
      case ClubSection.attendance:
        return 'Посещаемость';
      case ClubSection.testing:
        return 'Тестирование';
      case ClubSection.challenges:
        return 'Задания команды';
      case ClubSection.challengeCreate:
        return 'Создать задание';
      case ClubSection.quizzes:
        return 'Игровая зона';
      case ClubSection.quizCreate:
        return 'Создать квиз';
      case ClubSection.rating:
        return 'Рейтинг команды';
      case ClubSection.manager:
        return 'Менеджер команды';
      case ClubSection.miniGames:
        return 'Игровая зона';
      case ClubSection.medical:
        return 'Медкарта';
      case ClubSection.parents:
        return 'Родители';
      case ClubSection.settings:
        return 'Настройки';
    }
  }

  String _subtitleFor(ClubSection section) {
    switch (section) {
      case ClubSection.coachDashboard:
        return 'Главная панель GPS-комплекса: готовность команды, онлайн, отчёты и трекеры';
      case ClubSection.overview:
        return 'Команды, игроки, матчи, тренировки и аналитика в одном экране';
      case ClubSection.finder:
        return 'Папки, заметки, игроки, тренеры, команды и рабочие модули клуба';
      case ClubSection.teams:
        return 'Крупные карточки команд и быстрое создание новой команды';
      case ClubSection.teamDashboard:
        return 'Единая панель выбранной команды';
      case ClubSection.roster:
        return 'Игроки, карточки, профиль и быстрые действия';
      case ClubSection.trainers:
        return 'Тренеры, специалисты и доступы клуба';
      case ClubSection.teamTrainers:
        return 'Назначение тренеров и специалистов к выбранной команде';
      case ClubSection.playerProfile:
        return 'Профиль игрока без выхода из рабочего кабинета';
      case ClubSection.matches:
        return 'Игры, результаты, календарь матчей и отчёты';
      case ClubSection.calendar:
        return 'Тренировки, матчи, события и расписание';
      case ClubSection.trainings:
        return 'Планы, графика, посещаемость и оценка тренировок';
      case ClubSection.plans:
        return 'База планов и конспектов тренера';
      case ClubSection.graphics:
        return 'Тактические схемы и упражнения';
      case ClubSection.tracker:
        return 'GPS-трекинг, привязка устройств, тепловые карты, цели и нагрузка';
      case ClubSection.videoAnalysis:
        return 'AI-анализ, видео, ТТД и статистика матча';
      case ClubSection.description:
        return 'Описание команды, информация и публичная карточка';
      case ClubSection.chat:
        return 'Командное и клубное общение';
      case ClubSection.videoLessons:
        return 'Обучающие материалы, папки и видео тренеров';
      case ClubSection.attendance:
        return 'Журнал посещаемости, события и оценка тренировок';
      case ClubSection.testing:
        return 'Оценка физической, технической и тактической подготовленности игроков';
      case ClubSection.challenges:
        return 'Задания для игроков и контроль выполнения';
      case ClubSection.challengeCreate:
        return 'Новое задание для активной команды';
      case ClubSection.quizzes:
        return 'Вопросы, задания и активность игроков';
      case ClubSection.quizCreate:
        return 'Создание нового квиза для команды';
      case ClubSection.rating:
        return 'Очки, активность и лидерборд команды';
      case ClubSection.manager:
        return 'Тактика, состав и игровые сценарии';
      case ClubSection.miniGames:
        return 'Игровые механики команды: задания, квизы и рейтинги';
      case ClubSection.medical:
        return 'Контроль состояния, травм и документов';
      case ClubSection.parents:
        return 'Доступы родителей и коммуникация';
      case ClubSection.settings:
        return 'Настройка модулей и прав доступа';
    }
  }

  Widget _buildContent() => _buildSectionContent(selectedSection);

  void _handleAiNavigate(
    String target,
    Map<String, dynamic> payload,
  ) {
    final normalized = target.trim().toLowerCase();

    switch (normalized) {
      case 'player_profile':
      case 'player':
        final rawId =
            payload['player_id'] ?? payload['id'] ?? payload['playerId'];
        final playerId = rawId is int ? rawId : int.tryParse('$rawId');

        Map<String, dynamic>? player;
        if (playerId != null) {
          for (final item in players) {
            final map = Map<String, dynamic>.from(item);
            final id = map['id'] ?? map['player_id'] ?? map['playerId'];
            if ('$id' == '$playerId') {
              player = map;
              break;
            }
          }
        }

        player ??= Map<String, dynamic>.from(payload);

        if ((player['id'] == null && player['player_id'] == null) &&
            playerId != null) {
          player['id'] = playerId;
          player['player_id'] = playerId;
        }

        _openPlayerProfileWindow(player);
        return;

      case 'tracker':
      case 'session':
      case 'analytics':
        setState(() {
          selectedSection = ClubSection.tracker;
        });
        return;

      case 'report':
      case 'reports':
        // Отчёты по сессиям находятся внутри модуля трекера.
        setState(() {
          selectedSection = ClubSection.tracker;
        });
        return;

      case 'training_graphics':
      case 'graphics':
      case 'tactical_board':
        setState(() {
          selectedSection = ClubSection.graphics;
        });
        return;

      case 'calendar':
      case 'training':
      case 'event':
        setState(() {
          selectedSection = ClubSection.calendar;
        });
        return;

      case 'match':
      case 'matches':
        setState(() {
          selectedSection = ClubSection.matches;
        });
        return;

      case 'attendance':
        setState(() {
          selectedSection = ClubSection.attendance;
        });
        return;

      case 'testing':
      case 'tests':
        setState(() {
          selectedSection = ClubSection.testing;
        });
        return;

      case 'plans':
      case 'plan':
        setState(() {
          selectedSection = ClubSection.plans;
        });
        return;

      case 'roster':
      case 'players':
        setState(() {
          selectedSection = ClubSection.roster;
        });
        return;

      case 'teams':
        setState(() {
          selectedSection = ClubSection.teams;
        });
        return;

      default:
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Переход «$target» пока не подключён.',
            ),
          ),
        );
    }
  }

  Future<void> _handleAiOpenDocument(String url) async {
    await Clipboard.setData(
      ClipboardData(text: url),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Ссылка на документ скопирована.',
        ),
      ),
    );
  }

  void _openFinderModule(String key) {
    switch (key) {
      case 'teams':
        _selectWorkspaceSection(ClubSection.teams);
        break;
      case 'players':
        _selectWorkspaceSection(ClubSection.roster);
        break;
      case 'trainers':
        _selectWorkspaceSection(ClubSection.trainers);
        break;
      case 'matches':
        _selectWorkspaceSection(ClubSection.matches);
        break;
      case 'trainings':
        _selectWorkspaceSection(ClubSection.calendar);
        break;
      case 'plans':
        _selectWorkspaceSection(ClubSection.plans);
        break;
      case 'tracker':
      case 'reports':
        _selectWorkspaceSection(ClubSection.tracker);
        break;
      case 'testing':
        _selectWorkspaceSection(ClubSection.testing);
        break;
      case 'calendar':
        _selectWorkspaceSection(ClubSection.calendar);
        break;
      case 'video':
      case 'videoAnalysis':
        _selectWorkspaceSection(ClubSection.videoAnalysis);
        break;
      case 'videoLessons':
        _selectWorkspaceSection(ClubSection.videoLessons);
        break;
      case 'attendance':
        _selectWorkspaceSection(ClubSection.attendance);
        break;
      case 'medical':
        _selectWorkspaceSection(ClubSection.medical);
        break;
      case 'chat':
        _selectWorkspaceSection(ClubSection.chat);
        break;
      case 'parents':
        _selectWorkspaceSection(ClubSection.parents);
        break;
      case 'documents':
        Get.snackbar(
          'Документы',
          'Документы открываются из карточек игроков, тренеров и медицинского кабинета.',
        );
        break;
      default:
        Get.snackbar(
            'Спортотека OS', 'Раздел пока не подключён к пространству клуба.');
    }
  }

  Future<bool> _handleFinderMove(
    WorkspaceFinderNode source,
    WorkspaceFinderNode target,
  ) async {
    // Системное перетаскивание здесь специально проходит через единый bridge.
    // Когда для сущности есть безопасный API раздела, операция подключается здесь,
    // а оболочка OS остаётся неизменной. Локальные папки и ярлыки она обрабатывает сама.
    if (source.kind == WorkspaceFinderNodeKind.player &&
        target.kind == WorkspaceFinderNodeKind.team &&
        target.payload != null) {
      Get.snackbar(
        'Перевод игрока',
        'Перенос игрока между командами требует подтверждения. Откройте карточку команды — Спортотека OS уже передала выбранную команду.',
      );
      await _selectTeam(target.payload!, openTeam: false);
      return false;
    }
    return false;
  }

  Widget _buildSectionContent(ClubSection section) {
    switch (section) {
      case ClubSection.coachDashboard:
        return _TeamModulePanel(
          hasTeam: _hasTeam,
          title: 'Панель трекера',
          subtitle:
              'Откройте центр GPS-трекинга команды: онлайн, подключение трекеров, активность и отчёты.',
          icon: Icons.sensors_rounded,
          primaryText: 'Открыть центр трекинга',
          onPrimary: _openFullTracker,
          quickActions: [
            _ModuleQuickAction(
              'Команды',
              Icons.groups_2_rounded,
              () => setState(() => selectedSection = ClubSection.teams),
            ),
            _ModuleQuickAction(
              'Сессии',
              Icons.assignment_rounded,
              _openFullTracker,
            ),
          ],
        );
      case ClubSection.overview:
        if (trainerAssignedMode) {
          return TrainerCabinetPanel(
            clubName: clubName,
            teams: teams,
            events: events,
            latestPlans: latestPlans,
            players: players,
            onOpenProfile: () {
              if (!mounted) return;
              setState(() {
                _showOwnTrainerProfile = true;
                selectedSection = ClubSection.trainers;
              });
            },
            onOpenTrainers: () {
              if (!mounted) return;
              setState(() {
                _showOwnTrainerProfile = false;
                selectedSection = ClubSection.trainers;
              });
            },
            onOpenTeams: () =>
                setState(() => selectedSection = ClubSection.teams),
            onOpenCalendar: () =>
                setState(() => selectedSection = ClubSection.calendar),
            onOpenPlans: () =>
                setState(() => selectedSection = ClubSection.plans),
            onOpenTesting: () =>
                setState(() => selectedSection = ClubSection.testing),
            onOpenChats: () =>
                setState(() => selectedSection = ClubSection.chat),
            onOpenReports: () =>
                setState(() => selectedSection = ClubSection.tracker),
          );
        }

        return CmrClubOverviewPanel(
          clubId: clubId,
          clubName: clubName,
          clubLogo: clubLogo,
          clubDescription: clubDescription,
          teams: teams,
          trainers: trainers,
          events: events,
          latestPlans: latestPlans,
          playersCount: players.length,
          selectedTeamName: selectedTeamName,
          selectedTeamId: selectedTeamId,
          trainerAssignedMode: trainerAssignedMode,
          trainerWorkspaceId: trainerWorkspaceId,
          onTeamChanged: (team) => _selectTeam(team),
          onRefresh: () => _loadAll(),
          onCreateTeam: _openCreateTeam,
          onEditClub: _openEditClubDialog,
          onEditTeam: _openEditTeamDialog,
          onOpenTeams: () =>
              setState(() => selectedSection = ClubSection.teams),
          onOpenRoster: () =>
              setState(() => selectedSection = ClubSection.roster),
          onOpenTrainers: () =>
              setState(() => selectedSection = ClubSection.trainers),
          onOpenMatches: () =>
              setState(() => selectedSection = ClubSection.matches),
          onOpenCalendar: () =>
              setState(() => selectedSection = ClubSection.calendar),
          onOpenPlans: () =>
              setState(() => selectedSection = ClubSection.plans),
          onOpenChats: () => setState(() => selectedSection = ClubSection.chat),
        );
      case ClubSection.finder:
        return SportotekaWorkspaceFinderPanel(
          clubId: clubId,
          clubName: clubName,
          teams: teams,
          players: players,
          trainers: trainers,
          selectedTeamId: selectedTeamId,
          selectedTeamName: selectedTeamName,
          onRefresh: () => _loadAll(),
          onOpenModule: _openFinderModule,
          onOpenPlayer: _openPlayerProfileWindow,
          onOpenTeam: (team) => _selectTeam(team, openTeam: false),
          onOpenTrainer: (_) => _selectWorkspaceSection(ClubSection.trainers),
          onMoveEntity: _handleFinderMove,
        );
      case ClubSection.teams:
        return CmrClubTeamsPanel(
          clubId: clubId,
          clubName: clubName,
          currentUserId: currentUserId,
          openCreateTeam: _openCreateTeamInline,
          onCreateModeChanged: (open) {
            if (!mounted || _openCreateTeamInline == open) return;
            setState(() => _openCreateTeamInline = open);
          },
          teams: teams,
          selectedTeamId: selectedTeamId,
          selectedTeamName: selectedTeamName,
          maxTeams: _isClubBasic ? 20 : null,
          maxPlayersPerTeam: _isClubBasic ? 20 : null,
          onSelectTeam: (team) {
            if (_openCreateTeamInline) {
              setState(() => _openCreateTeamInline = false);
            }
            _selectTeam(team, openTeam: false);
          },

          // «Обзор» больше не ведёт в старый TeamDashboardScreen:
          // остаёмся в CMR и показываем описание/новости справа.
          onOpenTeam: (team) {
            if (_openCreateTeamInline) {
              setState(() => _openCreateTeamInline = false);
            }
            _selectTeam(team, openTeam: false);
          },
          onCreateTeam: _openCreateTeam,
          onRefresh: () => _loadAll(),
          onOpenRoster: () => _selectWorkspaceSection(ClubSection.roster),
          onOpenTrainers: () => _selectWorkspaceSection(ClubSection.trainers),
          onOpenCalendar: () => _selectWorkspaceSection(ClubSection.calendar),
          onOpenPlans: () => _selectWorkspaceSection(ClubSection.plans),
          onOpenTrainings: () => _selectWorkspaceSection(ClubSection.calendar),
          onOpenTesting: () => _selectWorkspaceSection(ClubSection.testing),
          onOpenChats: null,
          events: events,
          latestPlans: latestPlans,
          players: players,
        );
      case ClubSection.teamDashboard:
        return _TeamModulePanel(
          hasTeam: _hasTeam,
          title: 'Панель команды',
          subtitle:
              'Откройте полный рабочий экран команды или используйте модули слева.',
          icon: Icons.dashboard_customize_rounded,
          primaryText: 'Открыть панель команды',
          onPrimary: _openFullTeamDashboard,
          quickActions: [
            _ModuleQuickAction('Состав', Icons.groups_2_rounded,
                () => setState(() => selectedSection = ClubSection.roster)),
            _ModuleQuickAction('Матчи', Icons.sports_soccer_rounded,
                () => setState(() => selectedSection = ClubSection.matches)),
            _ModuleQuickAction('Календарь', Icons.calendar_month_rounded,
                () => setState(() => selectedSection = ClubSection.calendar)),
          ],
        );
      case ClubSection.roster:
        return _TeamGuard(
          hasTeam: _hasTeam,
          child: CmrClubRosterPanel(
            teamName: selectedTeamName,
            selectedTeamId: selectedTeamId,
            clubId: clubId,
            players: players,
            loading: loadingPlayers,
            selectedPlayer: selectedPlayer,
            maxPlayers: _isClubBasic ? 20 : null,
            onRefresh: selectedTeamId == null
                ? null
                : () => _loadPlayersForTeam(selectedTeamId!),
            onOpenPlayer: _openPlayer,
            onOpenFullPlayer: _openPlayerProfileWindow,
            onOpenFullRoster: _openFullRosterScreen,
            onDeletePlayer: _deletePlayerFromRoster,
            onAddPlayer: () {
              if (selectedTeamId == null || selectedTeamId! <= 0) {
                Get.snackbar('Команда', 'Сначала выберите команду');
                return;
              }

              Get.toNamed(
                AppRoutes.addPlayerScreen,
                arguments: {
                  'team_id': selectedTeamId,
                  'teamId': selectedTeamId,
                  'club_id': clubId,
                  'clubId': clubId,
                  'team_name': selectedTeamName,
                  'teamName': selectedTeamName,
                },
              )?.then((_) {
                if (selectedTeamId != null) {
                  _loadPlayersForTeam(selectedTeamId!);
                }
              });
            },
          ),
        );
      case ClubSection.trainers:
      case ClubSection.teamTrainers:
        if (trainerAssignedMode && _showOwnTrainerProfile) {
          return TrainerSelfProfilePanel(
            trainerId:
                trainerWorkspaceId > 0 ? trainerWorkspaceId : currentUserId,
            clubId: clubId,
            clubName: clubName,
            teams: teams,
            onBackToList: () {
              if (!mounted) return;
              setState(() {
                _showOwnTrainerProfile = false;
                selectedSection = ClubSection.trainers;
              });
            },
            onChanged: () async {
              await _safeLoad(_loadTeams);
              if (mounted) setState(() {});
            },
          );
        }

        return CmrClubTrainersPanel(
          clubId: clubId,
          clubName: clubName,
          teams: teams,
          selectedTeamId: selectedTeamId,
          selectedTeamName: selectedTeamName,
          onChanged: () async {
            await _safeLoad(_loadTrainers);
            if (mounted) setState(() {});
          },
          onOpenTeams: () =>
              setState(() => selectedSection = ClubSection.teams),
          onOpenRoster: () =>
              setState(() => selectedSection = ClubSection.roster),
        );
      case ClubSection.playerProfile:
        return _TeamGuard(
          hasTeam: _hasTeam,
          child: _PlayerPanel(
            player: selectedPlayer,
            teamName: selectedTeamName,
            onBack: () => setState(() => selectedSection = ClubSection.roster),
            onOpenFull: selectedPlayer == null
                ? null
                : () {
                    final mp = Map<String, dynamic>.from(selectedPlayer!);

                    mp['team_id'] = selectedTeamId;
                    mp['teamId'] = selectedTeamId;
                    mp['club_id'] = clubId;
                    mp['clubId'] = clubId;
                    mp['team_name'] = selectedTeamName;
                    mp['teamName'] = selectedTeamName;

                    _openPlayerProfileWindow(mp);
                  },
          ),
        );
      case ClubSection.matches:
        {
          final matchesTeamId = _activeTeamIdOrNull;
          if (matchesTeamId == null) return const _NeedTeam();
          return CmrTeamMatchesPanel(
            teamId: matchesTeamId,
            teamName: selectedTeamName,
            clubId: clubId,
            clubName: clubName,
          );
        }
      case ClubSection.calendar:
        {
          final calendarTeamId = _activeTeamIdOrNull;
          if (calendarTeamId == null) return const _NeedTeam();
          return CmrCalendarPanel(
            teamId: calendarTeamId,
            teamName: selectedTeamName,
            clubId: clubId,
            clubName: clubName,
          );
        }
      case ClubSection.trainings:
        return _TrainingsPanel(
          hasTeam: _hasTeam,
          onOpenPlans: () =>
              setState(() => selectedSection = ClubSection.plans),
          onOpenGraphics: () =>
              setState(() => selectedSection = ClubSection.graphics),
          onOpenCalendar: () =>
              setState(() => selectedSection = ClubSection.calendar),
          onOpenFullTeam: _openFullTeamDashboard,
        );
      case ClubSection.plans:
        return _TeamGuard(
            hasTeam: _hasTeam,
            child: CmrPlansPanel(
              clubId: clubId,
              clubName: clubName,
              teamId: selectedTeamId,
              teamName: selectedTeamName,
              trainerId: trainerAssignedMode ? trainerWorkspaceId : 0,
              trainerName: trainerAssignedMode ? trainerWorkspaceName : '',
            ));
      case ClubSection.graphics:
        return _TeamModulePanel(
          hasTeam: _hasTeam,
          title: 'Графический редактор',
          subtitle: 'Тактические схемы, упражнения и визуальные конспекты.',
          icon: Icons.draw_rounded,
          primaryText: 'Открыть редактор',
          onPrimary: _openFullGraphics,
          quickActions: [
            _ModuleQuickAction('Планы', Icons.folder_copy_rounded,
                () => setState(() => selectedSection = ClubSection.plans)),
          ],
        );
      case ClubSection.tracker:
        if (!_hasTeam || selectedTeamId == null || selectedTeamId! <= 0) {
          return const _NeedTeam();
        }

        final activeTeamId = _asInt(
          selectedTeam?['id'] ??
              selectedTeam?['team_id'] ??
              selectedTeam?['teamId'] ??
              selectedTeam?['teamID'] ??
              selectedTeamId,
        );

        final activeTeamName = _asString(selectedTeam?['name']) ??
            _asString(selectedTeam?['team_name']) ??
            _asString(selectedTeam?['teamName']) ??
            _asString(selectedTeam?['title']) ??
            selectedTeamName;

        final teamPlayers = players.where((player) {
          final playerTeamId = _asInt(
            player['team_id'] ??
                player['teamId'] ??
                player['teamID'] ??
                selectedTeamId,
          );

          return playerTeamId <= 0 || playerTeamId == activeTeamId;
        }).toList();

        return TrackerMatchWorkspaceScreen(
          key: ValueKey('tracker_program_${clubId}_$activeTeamId'),
          clubId: clubId,
          clubName: clubName,
          teamId: activeTeamId,
          teamName: activeTeamName,
          userId: currentUserId,
          initialPlayers: teamPlayers,
          embeddedInClubWorkspace: true,
        );
      case ClubSection.videoAnalysis:
        {
          final videoTeamId = _activeTeamIdOrNull;
          if (videoTeamId == null) return const _NeedTeam();
          return CmrVideoAnalysisPanel(
            teamId: videoTeamId,
            teamName: selectedTeamName,
            clubId: clubId,
            clubName: clubName,
          );
        }
      case ClubSection.description:
        return _TeamModulePanel(
          hasTeam: _hasTeam,
          title: 'Визитка команды',
          subtitle:
              'Описание команды, публичная информация, история и контакты.',
          icon: Icons.article_rounded,
          primaryText: 'Открыть визитку',
          onPrimary: _openFullTeamDescription,
          quickActions: [
            _ModuleQuickAction('Состав', Icons.groups_2_rounded,
                () => setState(() => selectedSection = ClubSection.roster)),
            _ModuleQuickAction('Матчи', Icons.sports_soccer_rounded,
                () => setState(() => selectedSection = ClubSection.matches)),
          ],
        );
      case ClubSection.chat:
        final userId = currentUserId > 0 ? currentUserId : clubId;

        return CmrChatsPanel(
          key: ValueKey('cmr-chats-$_chatPanelRevision'),
          userId: userId,
          clubId: clubId,
          clubName: clubName,
          teamId: selectedTeamId,
          teamName: selectedTeamName,
          onUnreadChanged: (value) {
            if (!mounted) return;
            setState(() => _chatUnreadCount = value);
          },
          onAiNavigate: _handleAiNavigate,
          onAiOpenPdf: _handleAiOpenDocument,
        );
      case ClubSection.videoLessons:
        return _TeamModulePanel(
          hasTeam: true,
          title: 'Видеоуроки клуба',
          subtitle:
              'Папки с обучающими материалами, видео тренеров и методическая база для игроков.',
          icon: Icons.video_library_rounded,
          primaryText: 'Открыть видеоуроки',
          onPrimary: _openFullVideoLessons,
          quickActions: [
            _ModuleQuickAction('Планы', Icons.folder_copy_rounded,
                () => setState(() => selectedSection = ClubSection.plans)),
            _ModuleQuickAction('Графика', Icons.draw_rounded,
                () => setState(() => selectedSection = ClubSection.graphics)),
            _ModuleQuickAction('Состав', Icons.groups_2_rounded,
                () => setState(() => selectedSection = ClubSection.roster)),
          ],
        );
      case ClubSection.attendance:
        {
          final attendanceTeamId = _activeTeamIdOrNull;
          if (attendanceTeamId == null) return const _NeedTeam();
          return CmrAttendancePanel(
            teamId: attendanceTeamId,
            teamName: selectedTeamName,
            clubId: clubId,
            clubName: clubName,
          );
        }
      case ClubSection.testing:
        {
          final testingTeamId = _activeTeamIdOrNull;
          if (testingTeamId == null) return const _NeedTeam();
          return CmrTestingPanel(
            clubId: clubId,
            teamId: testingTeamId,
            clubName: clubName,
            teamName: selectedTeamName,
            initialStage: _selectedTeamStage(),
            userId: currentUserId,
          );
        }

      case ClubSection.challenges:
        return _buildCmrGameZone(mode: CmrGameZoneMode.challenges);
      case ClubSection.challengeCreate:
        _openGameModule(ClubSection.challengeCreate);
        return const _NeedTeam();
      case ClubSection.quizzes:
        return _buildCmrGameZone(mode: CmrGameZoneMode.quizzes);
      case ClubSection.quizCreate:
        _openGameModule(ClubSection.quizCreate);
        return const _NeedTeam();
      case ClubSection.rating:
        return _buildCmrGameZone(mode: CmrGameZoneMode.rating);
      case ClubSection.manager:
        return _TeamModulePanel(
          hasTeam: _hasTeam,
          title: 'Менеджер команды',
          subtitle: 'Тактика, состав, игровые сценарии и симуляция матчей.',
          icon: Icons.psychology_alt_rounded,
          primaryText: 'Открыть менеджер',
          onPrimary: () => _openGameModule(ClubSection.manager),
        );
      case ClubSection.miniGames:
        return _buildCmrGameZone();
      case ClubSection.medical:
        {
          final medicalTeamId = _activeTeamIdOrNull;
          if (medicalTeamId == null) return const _NeedTeam();
          return CmrMedicalCabinetPanel(
            clubId: clubId,
            clubName: clubName,
            teamId: medicalTeamId,
            teamName: selectedTeamName,
            players: players,
          );
        }
      case ClubSection.parents:
        {
          final parentsTeamId = _activeTeamIdOrNull;
          if (parentsTeamId == null) return const _NeedTeam();
          return CmrClubParentsPanel(
            clubId: clubId,
            clubName: clubName,
            selectedTeamId: parentsTeamId,
            selectedTeamName: selectedTeamName,
            players: players,
            currentUserId: currentUserId,
            maxParents: _isClubBasic ? 20 : null,
            onOpenPlayer: (player) => _openPlayerProfileWindow(player),
          );
        }
      case ClubSection.settings:
        return const _SolidPlaceholder(
            icon: Icons.tune_rounded,
            title: 'Настройки рабочего кабинета',
            subtitle:
                'Следующим шагом сюда можно добавить порядок модулей, видимость разделов и права ролей.',
            chips: ['Меню', 'Роли', 'Виджеты', 'Оформление']);
    }
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
          color: _C.primaryGreen.withOpacity(.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: _C.primaryGreen.withOpacity(.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: _C.primaryGreen),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _C.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceGlassGlow extends StatelessWidget {
  final double size;
  final Color color;

  const _WorkspaceGlassGlow({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 34, sigmaY: 34),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
      ),
    );
  }
}

class _C {
  // Единая палитра с profile_screen.dart
  static const Color bg = Color(0xFFF7F9F8);
  static const Color card = Color(0xFFFFFFFF);
  static const Color text = Color(0xFF111827);
  static const Color muted = Color(0xFF667085);
  static const Color lightMuted = Color(0xFF98A2B3);
  static const Color border = Color(0xFFE5E7EB);
  static const Color borderSoft = Color(0xFFEFF2F5);

  static const Color black = Color(0xFF111315);
  static const Color graphite = Color(0xFF252A31);
  static const Color active = Color(0xFFE9ECEF);
  static const Color soft = Color(0xFFF7F9F8);
  static const Color soft2 = Color(0xFFFFFFFF);
  static const Color accent = Color(0xFF6B7280);

  // Меню клуба синхронизировано с home_screen.dart:
  // белая рейка, мягкая подложка, графитовый активный пункт.
  static const Color rail = Color(0xFFFFFFFF);
  static const Color railPanel = Color(0xFFF7F9F8);
  static const Color railHover = Color(0xFFF1F6F3);
  static const Color railText = Color(0xFF344054);
  static const Color railMuted = Color(0xFF667085);

  // Акцент точки в левом rail — как в home_screen.dart.
  static const Color menuGreen = Color(0xFF178A45);

  static const Color primaryGreen = Color(0xFF00A750);
  static const Color greenDark = Color(0xFF087A3A);
  static const Color footballGreen = Color(0xFF00A750);
  static const Color footballGreenSoft = Color(0xFFE8F7EF);
  static const Color greenSoft = Color(0xFFE8F7EF);

  static const Color blue = Color(0xFF2563EB);
  static const Color blueSoft = Color(0xFFEFF6FF);
  static const Color purple = Color(0xFF7C3AED);
  static const Color purpleSoft = Color(0xFFF4EBFF);
  static const Color orange = Color(0xFFEA580C);
  static const Color orangeSoft = Color(0xFFFFF4ED);
  static const Color teal = Color(0xFF0F766E);
  static const Color tealSoft = Color(0xFFE6F6F4);
  static const Color red = Color(0xFFDC2626);
  static const Color redSoft = Color(0xFFFFEDED);

  static const BoxShadow shadow = BoxShadow(
    color: Color(0x0A000000),
    blurRadius: 18,
    offset: Offset(0, 8),
  );

  static Color accentForSection(ClubSection section) {
    switch (section) {
      case ClubSection.coachDashboard:
        return purple;
      case ClubSection.overview:
      case ClubSection.finder:
        return primaryGreen;
      case ClubSection.teams:
      case ClubSection.trainers:
      case ClubSection.teamTrainers:
      case ClubSection.teamDashboard:
      case ClubSection.roster:
      case ClubSection.playerProfile:
        return blue;
      case ClubSection.matches:
        return orange;
      case ClubSection.calendar:
      case ClubSection.attendance:
        return teal;
      case ClubSection.videoAnalysis:
      case ClubSection.graphics:
      case ClubSection.testing:
      case ClubSection.tracker:
        return purple;
      case ClubSection.trainings:
      case ClubSection.plans:
      case ClubSection.videoLessons:
        return footballGreen;
      case ClubSection.medical:
        return red;
      case ClubSection.chat:
      case ClubSection.parents:
      case ClubSection.description:
      case ClubSection.settings:
        return graphite;
      case ClubSection.challenges:
      case ClubSection.challengeCreate:
      case ClubSection.quizzes:
      case ClubSection.quizCreate:
      case ClubSection.rating:
      case ClubSection.manager:
      case ClubSection.miniGames:
        return purple;
    }
  }

  static Color softFor(Color color) {
    if (color == blue) return blueSoft;
    if (color == purple) return purpleSoft;
    if (color == orange) return orangeSoft;
    if (color == teal) return tealSoft;
    if (color == red) return redSoft;
    if (color == footballGreen || color == primaryGreen || color == greenDark)
      return footballGreenSoft;
    return soft;
  }

  static Color accentForIcon(IconData icon) {
    if (icon == Icons.groups_2_rounded ||
        icon == Icons.account_tree_rounded ||
        icon == Icons.dashboard_customize_rounded ||
        icon == Icons.person_search_rounded) return blue;
    if (icon == Icons.sports_soccer_rounded ||
        icon == Icons.sports_score_rounded) return orange;
    if (icon == Icons.calendar_month_rounded ||
        icon == Icons.event_available_rounded ||
        icon == Icons.event_note_outlined ||
        icon == Icons.fact_check_rounded) return teal;
    if (icon == Icons.analytics_rounded || icon == Icons.draw_rounded)
      return purple;
    if (icon == Icons.medical_information_rounded ||
        icon == Icons.health_and_safety_rounded) return red;
    if (icon == Icons.folder_copy_rounded ||
        icon == Icons.fitness_center_rounded ||
        icon == Icons.video_library_rounded) return footballGreen;
    return primaryGreen;
  }
}

class _WorkspaceText {
  static const List<String> fallback = <String>[
    'SF Pro Text',
    'SF Pro Display',
    'Roboto',
    'Segoe UI',
    'Arial',
  ];

  static const TextStyle title = TextStyle(
    fontFamily: 'Inter',
    fontFamilyFallback: fallback,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.18,
    color: _C.text,
  );

  static const TextStyle section = TextStyle(
    fontFamily: 'Inter',
    fontFamilyFallback: fallback,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.18,
    color: _C.text,
  );

  static const TextStyle rowTitle = TextStyle(
    fontFamily: 'Inter',
    fontFamilyFallback: fallback,
    fontSize: 13.6,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    color: _C.text,
    height: 1.20,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: 'Inter',
    fontFamilyFallback: fallback,
    fontSize: 11.6,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    color: _C.muted,
    height: 1.30,
  );
}

class _WorkspaceLoadingScreen extends StatefulWidget {
  const _WorkspaceLoadingScreen();

  @override
  State<_WorkspaceLoadingScreen> createState() =>
      _WorkspaceLoadingScreenState();
}

class _WorkspaceLoadingScreenState extends State<_WorkspaceLoadingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2100),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: Center(
        child: Container(
          width: 390,
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _C.border),
            boxShadow: const [_C.shadow],
          ),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final eased = Curves.easeOutCubic.transform(_controller.value);
              final progress =
                  (0.08 + eased * 0.86).clamp(0.0, 0.94).toDouble();

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      color: _C.primaryGreen.withOpacity(.10),
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: _C.primaryGreen.withOpacity(.20)),
                    ),
                    child: const Icon(
                      Icons.dashboard_customize_rounded,
                      color: _C.primaryGreen,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Загружаем кабинет клуба',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _C.text,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 7),
                  const Text(
                    'Спортотека. Вперед к победам!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _C.muted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 22),
                  _WorkspaceProgressBar(progress: progress),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _WorkspaceProgressBar extends StatelessWidget {
  final double progress;
  final double height;
  final double radius;
  final bool largePercent;

  const _WorkspaceProgressBar({
    required this.progress,
    this.height = 10,
    this.radius = 99,
    this.largePercent = false,
  });

  @override
  Widget build(BuildContext context) {
    final safeProgress = progress.clamp(0.0, 1.0).toDouble();
    final percent = (safeProgress * 100).round().clamp(0, 100).toInt();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Подготовка данных',
                style: TextStyle(
                  color: _C.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '$percent%',
              style: TextStyle(
                color: _C.text,
                fontSize: largePercent ? 16 : 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: height,
          decoration: BoxDecoration(
            color: _C.bg,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: _C.border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: safeProgress,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius),
                    gradient: LinearGradient(
                      colors: [
                        _C.primaryGreen,
                        _C.primaryGreen.withOpacity(.86),
                        _C.blue.withOpacity(.92),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _C.primaryGreen.withOpacity(.20),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WorkspacePanelLoadingOverlay extends StatelessWidget {
  const _WorkspacePanelLoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        margin: const EdgeInsets.fromLTRB(0, 8, 0, 8),
        decoration: BoxDecoration(
          color: _C.bg.withOpacity(.72),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.96),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [_C.shadow],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: _C.primaryGreen,
                    strokeWidth: 2.6,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  'Загружаем панель',
                  style: TextStyle(
                    color: _C.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
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

const List<_NavGroup> _clubWorkspaceNavGroups = [
  _NavGroup('Клуб', [
    _NavItem(
      ClubSection.teams,
      Icons.account_tree_rounded,
      'Команды',
      subtitle: 'Список команд клуба',
    ),
    _NavItem(
      ClubSection.trainers,
      Icons.badge_rounded,
      'Тренеры',
      subtitle: 'Специалисты и назначения',
    ),
  ]),
  _NavGroup('Команда', [
    _NavItem(
      ClubSection.roster,
      Icons.groups_2_rounded,
      'Состав',
      subtitle: 'Игроки и профили',
    ),
    _NavItem(
      ClubSection.matches,
      Icons.sports_soccer_rounded,
      'Матчи',
      subtitle: 'Игры, счет и календарь',
    ),
    _NavItem(
      ClubSection.calendar,
      Icons.calendar_month_rounded,
      'Календарь',
      subtitle: 'Тренировки и события',
    ),
  ]),
  _NavGroup('Тренировки', [
    _NavItem(
      ClubSection.plans,
      Icons.folder_copy_rounded,
      'Планы-конспекты',
      subtitle: 'Материалы тренера',
      pro: true,
    ),
    _NavItem(
      ClubSection.graphics,
      Icons.draw_rounded,
      'Редактор схем',
      subtitle: 'Упражнения и разметка',
      pro: true,
    ),
  ]),
  _NavGroup('Контроль', [
    _NavItem(
      ClubSection.attendance,
      Icons.fact_check_rounded,
      'Посещаемость',
      subtitle: 'Журнал занятий',
      pro: true,
    ),
    _NavItem(
      ClubSection.testing,
      Icons.science_rounded,
      'Тестирование',
      subtitle: 'Физика, техника, тактика',
      pro: true,
    ),
    _NavItem(
      ClubSection.coachDashboard,
      Icons.dashboard_customize_rounded,
      'GPS-панель',
      subtitle: 'Готовность, онлайн и отчёты',
      pro: true,
    ),
    _NavItem(
      ClubSection.tracker,
      Icons.sensors_rounded,
      'Трекер',
      subtitle: 'GPS, нагрузка и тепловые карты',
      pro: true,
    ),
    _NavItem(
      ClubSection.medical,
      Icons.medical_information_rounded,
      'Медкарта',
      subtitle: 'Состояние игроков',
    ),
  ]),
  _NavGroup('Аналитика и связь', [
    _NavItem(
      ClubSection.manager,
      Icons.psychology_alt_rounded,
      'Менеджер команды',
      subtitle: 'Тактика и состав',
      pro: true,
    ),
    _NavItem(
      ClubSection.chat,
      Icons.forum_rounded,
      'Чаты',
      subtitle: 'Общение команды',
    ),
    _NavItem(
      ClubSection.parents,
      Icons.family_restroom_rounded,
      'Родители',
      subtitle: 'Доступы и связь',
    ),
  ]),
  _NavGroup('Дополнительно', [
    _NavItem(
      ClubSection.miniGames,
      Icons.videogame_asset_rounded,
      'Игровая зона',
      subtitle: 'Задания, квизы, рейтинг',
    ),
    _NavItem(
      ClubSection.settings,
      Icons.tune_rounded,
      'Настройки',
      subtitle: 'Права и модули',
    ),
  ]),
];

class _DesktopWorkspaceTaskbar extends StatelessWidget {
  final String clubName;
  final String? clubLogo;
  final String selectedTeamName;
  final ClubSection selectedSection;
  final bool hasActiveSubscription;
  final VoidCallback onStart;
  final VoidCallback onSearch;
  final ValueChanged<ClubSection> onSelect;
  final VoidCallback onHome;
  final VoidCallback onRefresh;

  const _DesktopWorkspaceTaskbar({
    required this.clubName,
    required this.clubLogo,
    required this.selectedTeamName,
    required this.selectedSection,
    required this.hasActiveSubscription,
    required this.onStart,
    required this.onSearch,
    required this.onSelect,
    required this.onHome,
    required this.onRefresh,
  });

  static const List<_NavItem> _taskbarItems = [
    _NavItem(ClubSection.teams, Icons.account_tree_rounded, 'Команды',
        subtitle: 'Команды клуба'),
    _NavItem(ClubSection.roster, Icons.groups_2_rounded, 'Состав',
        subtitle: 'Игроки команды'),
    _NavItem(ClubSection.trainers, Icons.badge_rounded, 'Тренеры',
        subtitle: 'Тренеры клуба'),
    _NavItem(ClubSection.matches, Icons.sports_soccer_rounded, 'Матчи',
        subtitle: 'Матчи и отчёты'),
    _NavItem(ClubSection.calendar, Icons.calendar_month_rounded, 'Календарь',
        subtitle: 'Расписание'),
    _NavItem(ClubSection.plans, Icons.folder_copy_rounded, 'Планы',
        subtitle: 'Планы-конспекты', pro: true),
    _NavItem(ClubSection.testing, Icons.science_rounded, 'Тесты',
        subtitle: 'Тестирование', pro: true),
    _NavItem(ClubSection.tracker, Icons.sensors_rounded, 'Трекер',
        subtitle: 'GPS-трекинг', pro: true),
    _NavItem(ClubSection.chat, Icons.forum_rounded, 'Чаты',
        subtitle: 'Командное общение'),
    _NavItem(ClubSection.manager, Icons.psychology_alt_rounded, 'Тактика',
        subtitle: 'Менеджер команды', pro: true),
  ];

  bool _isActive(ClubSection section) {
    if (selectedSection == section) return true;
    if (section == ClubSection.teams &&
        selectedSection == ClubSection.teamDashboard) return true;
    if (section == ClubSection.roster &&
        selectedSection == ClubSection.playerProfile) return true;
    if (section == ClubSection.trainers &&
        selectedSection == ClubSection.teamTrainers) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final compact = width < 1120;
    final veryCompact = width < 900;
    final maxWidth = math.min(1040.0, math.max(360.0, width - 32));

    return IgnorePointer(
      ignoring: false,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Container(
            height: veryCompact ? 58 : 62,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding:
                EdgeInsets.symmetric(horizontal: compact ? 7 : 10, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.97),
              borderRadius: BorderRadius.circular(21),
              border: Border.all(color: Colors.white.withOpacity(.82)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.11),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
                BoxShadow(
                  color: Colors.white.withOpacity(.72),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
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
                _TaskbarSearchButton(
                  compact: veryCompact,
                  onTap: onSearch,
                ),
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
                        for (final item in _taskbarItems) ...[
                          _TaskbarAppButton(
                            item: item,
                            active: _isActive(item.section),
                            proLocked: item.pro && !hasActiveSubscription,
                            showLabel: false,
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
                    clubName: clubName,
                    clubLogo: clubLogo,
                    selectedTeamName: selectedTeamName,
                    onTap: () => onSelect(ClubSection.teams),
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
      ),
    );
  }
}

class _TaskbarDivider extends StatelessWidget {
  final double height;
  const _TaskbarDivider({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: height,
      color: _C.borderSoft,
    );
  }
}

class _TaskbarSearchButton extends StatelessWidget {
  final bool compact;
  final VoidCallback onTap;

  const _TaskbarSearchButton({required this.compact, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Поиск по модулям',
      waitDuration: const Duration(milliseconds: 240),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 44,
            width: compact ? 44 : 132,
            padding: EdgeInsets.symmetric(horizontal: compact ? 0 : 12),
            decoration: BoxDecoration(
              color: _C.railPanel,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _C.borderSoft),
            ),
            child: Row(
              mainAxisAlignment:
                  compact ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                const Icon(Icons.search_rounded, color: _C.railText, size: 21),
                if (!compact) ...[
                  const SizedBox(width: 9),
                  const Expanded(
                    child: Text(
                      'Поиск',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _C.railMuted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
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
        waitDuration: const Duration(milliseconds: 240),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _hovered ? _C.railHover : _C.railPanel,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _C.borderSoft),
              ),
              child: Icon(widget.icon, color: _C.railText, size: 21),
            ),
          ),
        ),
      ),
    );
  }
}

class _TaskbarAppButton extends StatefulWidget {
  final _NavItem item;
  final bool active;
  final bool proLocked;
  final bool showLabel;
  final VoidCallback onTap;

  const _TaskbarAppButton({
    required this.item,
    required this.active,
    required this.proLocked,
    required this.showLabel,
    required this.onTap,
  });

  @override
  State<_TaskbarAppButton> createState() => _TaskbarAppButtonState();
}

class _TaskbarAppButtonState extends State<_TaskbarAppButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final accent = _C.railText;
    final bg = widget.active
        ? _C.railText
        : _hovered
            ? _C.railHover
            : Colors.transparent;
    final iconColor = widget.active ? Colors.white : _C.railText;
    final textColor = widget.active ? Colors.white : _C.railMuted;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Tooltip(
        message: '${widget.item.label} — ${widget.item.subtitle}',
        waitDuration: const Duration(milliseconds: 240),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              width: widget.showLabel ? 58 : 42,
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(16),
                boxShadow: widget.active
                    ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(.11),
                          blurRadius: 16,
                          offset: const Offset(0, 7),
                        ),
                      ]
                    : const [],
              ),
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(widget.item.icon,
                          color: iconColor, size: widget.showLabel ? 20 : 22),
                      if (widget.showLabel) ...[
                        const SizedBox(height: 4),
                        Text(
                          widget.item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 10.2,
                            height: 1,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (widget.active)
                    Positioned(
                      bottom: -3,
                      child: Container(
                        width: 20,
                        height: 3,
                        decoration: BoxDecoration(
                          color: _C.railText,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                  if (widget.proLocked)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: _C.orangeSoft,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: const Icon(
                          Icons.lock_rounded,
                          color: _C.orange,
                          size: 9,
                        ),
                      ),
                    ),
                  if (_hovered && !widget.active)
                    Positioned(
                      bottom: -3,
                      child: Container(
                        width: 16,
                        height: 2,
                        decoration: BoxDecoration(
                          color: accent.withOpacity(.55),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TaskbarTeamPill extends StatelessWidget {
  final String clubName;
  final String? clubLogo;
  final String selectedTeamName;
  final VoidCallback onTap;

  const _TaskbarTeamPill({
    required this.clubName,
    required this.clubLogo,
    required this.selectedTeamName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final safeTeam = selectedTeamName.trim().isEmpty
        ? 'Команда не выбрана'
        : selectedTeamName.trim();

    return Tooltip(
      message: 'Активная команда: $safeTeam',
      waitDuration: const Duration(milliseconds: 240),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 44,
            constraints: const BoxConstraints(maxWidth: 190),
            padding: const EdgeInsets.only(left: 8, right: 11),
            decoration: BoxDecoration(
              color: _C.railPanel,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _C.borderSoft),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _LogoBox(url: clubLogo, size: 28, bgColor: Colors.white),
                const SizedBox(width: 8),
                Flexible(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        clubName.trim().isEmpty ? 'Клуб' : clubName.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _C.railMuted,
                          fontSize: 9.8,
                          height: 1,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        safeTeam,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _C.railText,
                          fontSize: 10.8,
                          height: 1,
                          fontWeight: FontWeight.w600,
                        ),
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

class _DesktopCommandMenuOverlay extends StatefulWidget {
  final String clubName;
  final String? clubLogo;
  final String selectedTeamName;
  final ClubSection selectedSection;
  final bool hasActiveSubscription;
  final List<_FullMenuItem> items;

  const _DesktopCommandMenuOverlay({
    required this.clubName,
    required this.clubLogo,
    required this.selectedTeamName,
    required this.selectedSection,
    required this.hasActiveSubscription,
    required this.items,
  });

  @override
  State<_DesktopCommandMenuOverlay> createState() =>
      _DesktopCommandMenuOverlayState();
}

class _DesktopCommandMenuOverlayState
    extends State<_DesktopCommandMenuOverlay> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _query = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool _isActive(ClubSection section) {
    if (widget.selectedSection == section) return true;
    if (section == ClubSection.teams &&
        widget.selectedSection == ClubSection.teamDashboard) return true;
    if (section == ClubSection.roster &&
        widget.selectedSection == ClubSection.playerProfile) return true;
    if (section == ClubSection.trainers &&
        widget.selectedSection == ClubSection.teamTrainers) return true;
    return false;
  }

  List<_FullMenuItem> get _filteredItems {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.items;
    return widget.items.where((item) {
      final haystack = '${item.title} ${item.subtitle}'.toLowerCase();
      return haystack.contains(q);
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final compact = width < 720;
    final items = _filteredItems;

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Center(
          child: Container(
            width: math.min(760.0, width - 24),
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * .78),
            padding: EdgeInsets.all(compact ? 12 : 14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.98),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withOpacity(.86)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.16),
                  blurRadius: 42,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    _LogoBox(
                        url: widget.clubLogo, size: 42, bgColor: _C.railPanel),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.clubName.trim().isEmpty
                                ? 'Кабинет клуба'
                                : widget.clubName.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _C.text,
                              fontSize: 16,
                              height: 1,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            widget.selectedTeamName.trim().isEmpty
                                ? 'Команда не выбрана'
                                : widget.selectedTeamName.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _C.muted,
                              fontSize: 12,
                              height: 1,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, color: _C.railText),
                      tooltip: 'Закрыть',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  onChanged: (value) => setState(() => _query = value),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Найти модуль: матчи, календарь, тестирование…',
                    prefixIcon:
                        const Icon(Icons.search_rounded, color: _C.railMuted),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _controller.clear();
                              setState(() => _query = '');
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                    filled: true,
                    fillColor: _C.railPanel,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 15),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  style: const TextStyle(
                    color: _C.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: items.isEmpty
                      ? const _CommandMenuEmptyState()
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const BouncingScrollPhysics(),
                          itemCount: items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return _CommandMenuTile(
                              item: item,
                              active: _isActive(item.section),
                              proLocked:
                                  item.pro && !widget.hasActiveSubscription,
                              onTap: () =>
                                  Navigator.of(context).pop(item.section),
                            );
                          },
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

class _CommandMenuTile extends StatelessWidget {
  final _FullMenuItem item;
  final bool active;
  final bool proLocked;
  final VoidCallback onTap;

  const _CommandMenuTile({
    required this.item,
    required this.active,
    required this.proLocked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _C.accentForSection(item.section);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: active ? _C.softFor(accent) : _C.railPanel,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: active ? accent.withOpacity(.22) : _C.borderSoft),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: active ? accent : Colors.white,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(item.icon,
                    color: active ? Colors.white : accent, size: 21),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _C.text,
                              fontSize: 13.5,
                              height: 1,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (proLocked)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: _C.orangeSoft,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'PRO',
                              style: TextStyle(
                                color: _C.orange,
                                fontSize: 9.5,
                                height: 1,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _C.muted,
                        fontSize: 12,
                        height: 1,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                active ? Icons.check_circle_rounded : Icons.north_east_rounded,
                color: active ? accent : _C.lightMuted,
                size: 19,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommandMenuEmptyState extends StatelessWidget {
  const _CommandMenuEmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
      decoration: BoxDecoration(
        color: _C.railPanel,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded, color: _C.lightMuted, size: 30),
          SizedBox(height: 8),
          Text(
            'Ничего не найдено',
            style: TextStyle(
              color: _C.text,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 5),
          Text(
            'Попробуйте другое название модуля',
            style: TextStyle(
              color: _C.muted,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final String clubName;
  final String? clubLogo;
  final String clubDescription;
  final String selectedTeamName;
  final int? selectedTeamId;
  final List<Map<String, dynamic>> teams;
  final int teamsCount;
  final int playersCount;
  final int trainersCount;
  final ClubSection selectedSection;
  final bool hasActiveSubscription;
  final ValueChanged<ClubSection> onSelect;
  final ValueChanged<Map<String, dynamic>> onTeamSelected;
  final VoidCallback onOpenFullMenu;
  final VoidCallback onGoHome;

  const _Sidebar({
    required this.clubName,
    required this.clubLogo,
    required this.clubDescription,
    required this.selectedTeamName,
    required this.selectedTeamId,
    required this.teams,
    required this.teamsCount,
    required this.playersCount,
    required this.trainersCount,
    required this.selectedSection,
    required this.hasActiveSubscription,
    required this.onSelect,
    required this.onTeamSelected,
    required this.onOpenFullMenu,
    required this.onGoHome,
  });

  List<_NavItem> get _flatNavItems => <_NavItem>[
        for (final group in _clubWorkspaceNavGroups) ...group.items,
      ];

  String _railLabel(_NavItem item) {
    switch (item.section) {
      case ClubSection.overview:
        return 'Обзор';
      case ClubSection.finder:
        return 'OS';
      case ClubSection.teams:
        return 'Команды';
      case ClubSection.trainers:
        return 'Тренеры';
      case ClubSection.roster:
        return 'Состав';
      case ClubSection.matches:
        return 'Матчи';
      case ClubSection.calendar:
        return 'Кален.';
      case ClubSection.plans:
        return 'Планы';
      case ClubSection.graphics:
        return 'Схемы';
      case ClubSection.videoLessons:
        return 'Уроки';
      case ClubSection.attendance:
        return 'Журнал';
      case ClubSection.testing:
        return 'Тесты';
      case ClubSection.coachDashboard:
        return 'GPS';
      case ClubSection.tracker:
        return 'Трекер';
      case ClubSection.medical:
        return 'Мед.';
      case ClubSection.videoAnalysis:
        return 'Видео';
      case ClubSection.manager:
        return 'Менедж.';
      case ClubSection.chat:
        return 'Чаты';
      case ClubSection.parents:
        return 'Родит.';
      case ClubSection.miniGames:
        return 'Игры';
      case ClubSection.settings:
        return 'Настр.';
      default:
        final words = item.label.trim().split(RegExp(r'\s+'));
        return words.isEmpty ? item.label : words.first;
    }
  }

  bool _sectionIsActive(ClubSection itemSection) {
    if (itemSection == selectedSection) return true;

    if (itemSection == ClubSection.roster &&
        selectedSection == ClubSection.playerProfile) {
      return true;
    }

    if (itemSection == ClubSection.trainers &&
        selectedSection == ClubSection.teamTrainers) {
      return true;
    }

    if (itemSection == ClubSection.teams &&
        selectedSection == ClubSection.teamDashboard) {
      return true;
    }

    return false;
  }

  int _teamId(Map<String, dynamic> team) {
    final raw =
        team['id'] ?? team['team_id'] ?? team['teamId'] ?? team['teamID'];
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }

  String _teamName(Map<String, dynamic> team) {
    final raw =
        team['name'] ?? team['team_name'] ?? team['teamName'] ?? team['title'];
    final value = raw?.toString().trim() ?? '';
    return value.isEmpty || value == 'null' ? 'Команда' : value;
  }

  String _teamSubtitle(Map<String, dynamic> team) {
    final raw = team['age_group'] ??
        team['team_age'] ??
        team['sport'] ??
        team['category'];
    final value = raw?.toString().trim() ?? '';
    return value.isEmpty || value == 'null' ? 'Команда клуба' : value;
  }

  String? _teamLogo(Map<String, dynamic> team) {
    final raw = team['logo'] ??
        team['logo_url'] ??
        team['team_logo'] ??
        team['teamLogo'] ??
        team['photo'] ??
        team['image'];
    final value = raw?.toString().trim() ?? '';
    return value.isEmpty || value == 'null' ? null : value;
  }

  Map<String, dynamic>? _activeTeam() {
    for (final team in teams) {
      if (_teamId(team) == selectedTeamId) return team;
    }
    return null;
  }

  Future<void> _openTeamPicker(BuildContext context) async {
    if (teams.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Команды пока не созданы')),
      );
      return;
    }

    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final size = MediaQuery.of(sheetContext).size;
        final isWide = size.width >= 760;

        return Padding(
          padding:
              EdgeInsets.fromLTRB(isWide ? 24 : 12, 0, isWide ? 24 : 12, 14),
          child: Center(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: isWide ? 760 : double.infinity,
                maxHeight: size.height * .82,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(.14),
                    blurRadius: 38,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 5,
                    width: 54,
                    margin: const EdgeInsets.only(top: 12, bottom: 10),
                    decoration: BoxDecoration(
                      color: _C.active,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 14, 14),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: _C.primaryGreen.withOpacity(.10),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(
                            Icons.account_tree_rounded,
                            color: _C.primaryGreen,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Выбор команды',
                                style: TextStyle(
                                  color: _C.text,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${teams.length} команд · выберите активную команду',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _C.muted,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                      itemCount: teams.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, index) {
                        final team = teams[index];
                        final id = _teamId(team);
                        final active = id > 0 && id == selectedTeamId;

                        return _TeamPickerTile(
                          name: _teamName(team),
                          subtitle: _teamSubtitle(team),
                          logo: _teamLogo(team),
                          active: active,
                          onTap: () => Navigator.pop(sheetContext, team),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (selected != null) onTeamSelected(selected);
  }

  String _clubInitial(String value) {
    final safe = value.trim().isEmpty ? 'К' : value.trim();
    return safe.characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final safeClubName = clubName.trim().isEmpty ? 'Клуб' : clubName.trim();
    final activeTeam = _activeTeam();
    final safeTeamName = activeTeam == null
        ? (selectedTeamName.trim().isEmpty
            ? 'Команда'
            : selectedTeamName.trim())
        : _teamName(activeTeam);
    final teamLogo = activeTeam == null ? null : _teamLogo(activeTeam);
    final navItems = _flatNavItems;
    final screenWidth = MediaQuery.of(context).size.width;
    final railWidth = screenWidth >= 1280 ? 88.0 : 78.0;
    final railRadius = screenWidth >= 1280 ? 18.0 : 15.0;

    return Container(
      width: railWidth,
      margin: EdgeInsets.fromLTRB(screenWidth >= 1280 ? 10 : 6, 6, 0, 6),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _C.rail,
        borderRadius: BorderRadius.circular(railRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.045),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Tooltip(
            message: safeClubName,
            waitDuration: const Duration(milliseconds: 250),
            preferBelow: false,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onSelect(ClubSection.teams),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: screenWidth >= 1280 ? 62 : 56,
                height: screenWidth >= 1280 ? 56 : 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _C.railPanel,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Transform.scale(
                  scale: screenWidth >= 1280 ? .82 : .78,
                  child: _LogoBox(
                    url: clubLogo,
                    size: 34,
                    bgColor: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          _ClubRailUtilityButton(
            icon: Icons.account_tree_rounded,
            label: 'Команда',
            tooltip: safeTeamName,
            imageUrl: teamLogo,
            active: selectedSection == ClubSection.teamDashboard,
            onTap: () => _openTeamPicker(context),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.symmetric(
                  horizontal: screenWidth >= 1280 ? 10 : 8, vertical: 8),
              physics: const BouncingScrollPhysics(),
              itemCount: navItems.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final item = navItems[index];
                final active = _sectionIsActive(item.section);

                return _ClubSideRailButton(
                  item: item,
                  label: _railLabel(item),
                  active: active,
                  accent: _C.primaryGreen,
                  proLocked: item.pro && !hasActiveSubscription,
                  onTap: () => onSelect(item.section),
                );
              },
            ),
          ),
          Padding(
            padding:
                EdgeInsets.symmetric(horizontal: screenWidth >= 1280 ? 10 : 8),
            child: Column(
              children: [
                _ClubRailUtilityButton(
                  icon: Icons.home_rounded,
                  label: 'Главная',
                  tooltip: 'На главную',
                  active: false,
                  onTap: onGoHome,
                ),
                const SizedBox(height: 6),
                _ClubRailUtilityButton(
                  icon: Icons.apps_rounded,
                  label: 'Меню',
                  tooltip: 'Полное меню',
                  active: false,
                  onTap: onOpenFullMenu,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _WorkspaceMiniPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _WorkspaceMiniPill({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: _C.muted),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _C.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarClubAvatar extends StatelessWidget {
  final String? clubLogo;
  final String clubName;
  final bool active;
  final bool proLocked;
  final VoidCallback onTap;

  const _SidebarClubAvatar({
    required this.clubLogo,
    required this.clubName,
    required this.active,
    this.proLocked = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final safeClubName = clubName.trim().isEmpty ? 'Клуб' : clubName.trim();
    final firstLetter = safeClubName.characters.first.toUpperCase();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 58),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: active ? _C.primaryGreen.withOpacity(.08) : _C.soft2,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: active ? _C.primaryGreen.withOpacity(.18) : _C.border,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _C.border.withOpacity(.75)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: (clubLogo != null && clubLogo!.trim().isNotEmpty)
                      ? Image.network(
                          clubLogo!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                            child: Text(
                              firstLetter,
                              style: const TextStyle(
                                color: _C.primaryGreen,
                                fontWeight: FontWeight.w600,
                                fontSize: 17,
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            firstLetter,
                            style: const TextStyle(
                              color: _C.primaryGreen,
                              fontWeight: FontWeight.w600,
                              fontSize: 17,
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        safeClubName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _C.text,
                          fontSize: 13.2,
                          height: 1.08,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Обзор клуба',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _C.muted,
                          fontSize: 10.8,
                          fontWeight: FontWeight.w600,
                        ),
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

class _SidebarSectionTitle extends StatelessWidget {
  final String title;

  const _SidebarSectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: _C.lightMuted,
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          letterSpacing: .7,
          height: 1.1,
        ),
      ),
    );
  }
}

class _CompactSidebarActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  const _CompactSidebarActionButton({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });

  @override
  State<_CompactSidebarActionButton> createState() =>
      _CompactSidebarActionButtonState();
}

class _CompactSidebarActionButtonState
    extends State<_CompactSidebarActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bgColor =
        _hovered ? widget.accent.withOpacity(.06) : Colors.transparent;
    final borderColor =
        _hovered ? widget.accent.withOpacity(.10) : Colors.transparent;
    final iconBgColor = _hovered ? Colors.white : _C.soft2;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Tooltip(
        message: widget.label == 'Меню' ? 'Полное меню' : 'На главную',
        waitDuration: const Duration(milliseconds: 250),
        preferBelow: false,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 9),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: iconBgColor,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: widget.accent.withOpacity(.08)),
                      boxShadow: _hovered
                          ? [
                              BoxShadow(
                                color: widget.accent.withOpacity(.08),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : const [],
                    ),
                    child: Icon(widget.icon, size: 17, color: widget.accent),
                  ),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      widget.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _C.graphite,
                        fontSize: 11.8,
                        fontWeight: FontWeight.w600,
                        height: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ClubRailUtilityButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final String tooltip;
  final String? imageUrl;
  final bool active;
  final VoidCallback onTap;

  const _ClubRailUtilityButton({
    required this.icon,
    required this.label,
    required this.tooltip,
    this.imageUrl,
    required this.active,
    required this.onTap,
  });

  @override
  State<_ClubRailUtilityButton> createState() => _ClubRailUtilityButtonState();
}

class _ClubRailUtilityButtonState extends State<_ClubRailUtilityButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.active;
    final bgColor = selected
        ? _C.railText
        : _hovered
            ? _C.railHover
            : Colors.transparent;
    final iconColor = selected ? Colors.white : _C.railText;
    final textColor = selected ? Colors.white : _C.railMuted;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Tooltip(
        message: widget.tooltip,
        waitDuration: const Duration(milliseconds: 250),
        preferBelow: false,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 58,
            padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(.10),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : const [],
            ),
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Center(
                          child: widget.imageUrl != null &&
                                  widget.imageUrl!.trim().isNotEmpty
                              ? _LogoBox(
                                  url: widget.imageUrl,
                                  size: 24,
                                  bgColor: Colors.white)
                              : Icon(widget.icon, color: iconColor, size: 21),
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: double.infinity,
                        child: Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 9.1,
                            height: 1.0,
                            fontWeight:
                                selected ? FontWeight.w600 : FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Positioned(
                    left: 0,
                    top: 8,
                    bottom: 8,
                    child: Container(
                      width: 3,
                      decoration: BoxDecoration(
                        color: _C.railText,
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

class _ClubSideRailButton extends StatefulWidget {
  final _NavItem item;
  final String label;
  final bool active;
  final Color accent;
  final bool proLocked;
  final VoidCallback onTap;

  const _ClubSideRailButton({
    required this.item,
    required this.label,
    required this.active,
    required this.accent,
    this.proLocked = false,
    required this.onTap,
  });

  @override
  State<_ClubSideRailButton> createState() => _ClubSideRailButtonState();
}

class _ClubSideRailButtonState extends State<_ClubSideRailButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.active
        ? _C.railText
        : _hovered
            ? _C.railHover
            : Colors.transparent;
    final fg = widget.active ? Colors.white : _C.railText;
    final textColor = widget.active ? Colors.white : _C.railMuted;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Tooltip(
        message: '${widget.item.label} — ${widget.item.subtitle}',
        waitDuration: const Duration(milliseconds: 250),
        preferBelow: false,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
              boxShadow: widget.active
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(.10),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : const [],
            ),
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Center(
                          child: Icon(widget.item.icon, color: fg, size: 21),
                        ),
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: double.infinity,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Text(
                            widget.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 9.05,
                              height: 1.0,
                              fontWeight: widget.active
                                  ? FontWeight.w600
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.active)
                  Positioned(
                    left: 0,
                    top: 8,
                    bottom: 8,
                    child: Container(
                      width: 3,
                      decoration: BoxDecoration(
                        color: _C.railText,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                if (widget.proLocked)
                  Positioned(
                    right: 1,
                    bottom: 1,
                    child: Container(
                      width: 15,
                      height: 15,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFF7ED),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_rounded,
                        color: Color(0xFFB45309),
                        size: 9,
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

class _ClubSideRailActionButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool active;
  final Color accent;
  final VoidCallback onTap;

  const _ClubSideRailActionButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.accent,
    required this.onTap,
  });

  @override
  State<_ClubSideRailActionButton> createState() =>
      _ClubSideRailActionButtonState();
}

class _ClubSideRailActionButtonState extends State<_ClubSideRailActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    const showLabel = true;
    final effectiveAccent = widget.active ? _C.railText : widget.accent;
    final bgColor = widget.active
        ? effectiveAccent.withOpacity(.08)
        : _hovered
            ? _C.active.withOpacity(.72)
            : Colors.transparent;
    final borderColor = widget.active
        ? effectiveAccent.withOpacity(.16)
        : _hovered
            ? _C.railText.withOpacity(.10)
            : Colors.transparent;
    final iconBgColor = widget.active
        ? effectiveAccent.withOpacity(.12)
        : _hovered
            ? Colors.white
            : _C.soft2;
    final iconColor = widget.active ? effectiveAccent : _C.muted;
    final labelColor = widget.active ? effectiveAccent : _C.graphite;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Tooltip(
        message: widget.label,
        waitDuration: const Duration(milliseconds: 250),
        preferBelow: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              width: double.infinity,
              height: 42,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: borderColor),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(15),
                  onTap: widget.onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: iconBgColor,
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(
                              color: widget.active
                                  ? effectiveAccent.withOpacity(.14)
                                  : _C.borderSoft,
                            ),
                            boxShadow: widget.active || _hovered
                                ? [
                                    BoxShadow(
                                      color: effectiveAccent.withOpacity(
                                          widget.active ? .10 : .055),
                                      blurRadius: widget.active ? 12 : 9,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : const [],
                          ),
                          child: Icon(widget.icon, size: 18, color: iconColor),
                        ),
                        if (showLabel)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 10),
                              child: Text(
                                widget.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.4,
                                  height: 1.05,
                                  fontWeight: widget.active
                                      ? FontWeight.w600
                                      : FontWeight.w600,
                                  color: labelColor,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarTeamPickerButton extends StatelessWidget {
  final List<Map<String, dynamic>> teams;
  final int? selectedTeamId;
  final String selectedTeamName;
  final ValueChanged<Map<String, dynamic>> onTeamSelected;

  const _SidebarTeamPickerButton({
    required this.teams,
    required this.selectedTeamId,
    required this.selectedTeamName,
    required this.onTeamSelected,
  });

  int _teamId(Map<String, dynamic> team) {
    final raw =
        team['id'] ?? team['team_id'] ?? team['teamId'] ?? team['teamID'];
    if (raw is int) return raw;
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }

  String _teamName(Map<String, dynamic> team) {
    final raw =
        team['name'] ?? team['team_name'] ?? team['teamName'] ?? team['title'];
    final value = raw?.toString().trim() ?? '';
    return value.isEmpty || value == 'null' ? 'Команда' : value;
  }

  String _teamSubtitle(Map<String, dynamic> team) {
    final raw = team['age_group'] ??
        team['team_age'] ??
        team['sport'] ??
        team['category'];
    final value = raw?.toString().trim() ?? '';
    return value.isEmpty || value == 'null' ? 'Команда клуба' : value;
  }

  String? _teamLogo(Map<String, dynamic> team) {
    final raw = team['logo'] ??
        team['logo_url'] ??
        team['team_logo'] ??
        team['teamLogo'] ??
        team['photo'] ??
        team['image'];
    final value = raw?.toString().trim() ?? '';
    return value.isEmpty || value == 'null' ? null : value;
  }

  Map<String, dynamic>? _activeTeam() {
    for (final team in teams) {
      if (_teamId(team) == selectedTeamId) return team;
    }
    return null;
  }

  Future<void> _openTeamPicker(BuildContext context) async {
    if (teams.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Команды пока не созданы')),
      );
      return;
    }

    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final size = MediaQuery.of(sheetContext).size;
        final isWide = size.width >= 760;

        return Padding(
          padding:
              EdgeInsets.fromLTRB(isWide ? 24 : 12, 0, isWide ? 24 : 12, 14),
          child: Center(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: isWide ? 760 : double.infinity,
                maxHeight: size.height * .82,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(.14),
                    blurRadius: 38,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 5,
                    width: 54,
                    margin: const EdgeInsets.only(top: 12, bottom: 10),
                    decoration: BoxDecoration(
                      color: _C.border,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 14, 14),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: _C.primaryGreen.withOpacity(.10),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                                color: _C.primaryGreen.withOpacity(.16)),
                          ),
                          child: const Icon(
                            Icons.account_tree_rounded,
                            color: _C.primaryGreen,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Выбор команды',
                                style: TextStyle(
                                  color: _C.text,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${teams.length} команд · выберите активную для рабочего меню',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _C.muted,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                      itemCount: teams.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, index) {
                        final team = teams[index];
                        final id = _teamId(team);
                        final active = id > 0 && id == selectedTeamId;

                        return _TeamPickerTile(
                          name: _teamName(team),
                          subtitle: _teamSubtitle(team),
                          logo: _teamLogo(team),
                          active: active,
                          onTap: () => Navigator.pop(sheetContext, team),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (selected != null) onTeamSelected(selected);
  }

  @override
  Widget build(BuildContext context) {
    final activeTeam = _activeTeam();
    final logo = activeTeam == null ? null : _teamLogo(activeTeam);
    final teamName = activeTeam == null
        ? (selectedTeamName.trim().isEmpty
            ? 'Выбрать команду'
            : selectedTeamName.trim())
        : _teamName(activeTeam);
    final subtitle =
        activeTeam == null ? 'Команды клуба' : _teamSubtitle(activeTeam);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _openTeamPicker(context),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 54),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: teams.isEmpty
                    ? _C.border
                    : _C.footballGreen.withOpacity(.22),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.035),
                  blurRadius: 14,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Row(
              children: [
                _LogoBox(url: logo, size: 36, bgColor: _C.soft2),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        teamName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _C.text,
                          fontSize: 12.0,
                          height: 1.05,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _C.muted,
                          fontSize: 10.2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: _C.footballGreenSoft,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: _C.footballGreen,
                    size: 20,
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

class _SidebarHomeButton extends StatelessWidget {
  final VoidCallback onTap;

  const _SidebarHomeButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _C.border),
          ),
          child: const Row(
            children: [
              Icon(Icons.home_rounded, color: _C.primaryGreen, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'На главную',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _C.text,
                    fontSize: 12.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, color: _C.muted, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarFullMenuButton extends StatelessWidget {
  final VoidCallback onTap;

  const _SidebarFullMenuButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF6B7280),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.10),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Row(
            children: [
              Icon(Icons.apps_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Полное меню',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.open_in_full_rounded, color: Colors.white, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _FullMenuItem {
  final ClubSection section;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool pro;

  const _FullMenuItem(this.section, this.icon, this.title, this.subtitle,
      {this.pro = false});
}

class _FullModulesMenuOverlay extends StatelessWidget {
  final String clubName;
  final String? clubLogo;
  final String selectedTeamName;
  final ClubSection selectedSection;
  final bool hasActiveSubscription;
  final List<_FullMenuItem> items;

  const _FullModulesMenuOverlay({
    required this.clubName,
    required this.clubLogo,
    required this.selectedTeamName,
    required this.selectedSection,
    required this.hasActiveSubscription,
    required this.items,
  });

  bool _sectionIsActive(ClubSection itemSection) {
    if (itemSection == selectedSection) return true;
    if (itemSection == ClubSection.teams &&
        selectedSection == ClubSection.teamDashboard) return true;
    if (itemSection == ClubSection.roster &&
        selectedSection == ClubSection.playerProfile) return true;
    if (itemSection == ClubSection.trainers &&
        selectedSection == ClubSection.teamTrainers) return true;
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final width = media.size.width;
    final height = media.size.height;
    final compact = width < 720;
    final columns = compact
        ? 4
        : width >= 1180
            ? 7
            : 6;
    final menuWidth = math.min(compact ? width - 22 : 760.0, width - 32);
    final maxHeight =
        math.max(320.0, math.min(height - 118, compact ? 560.0 : 600.0));
    final safeTeam = selectedTeamName.trim().isEmpty
        ? 'Команда не выбрана'
        : selectedTeamName.trim();

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.fromLTRB(12, 12, 12, compact ? 78 : 88),
            child: Container(
              width: menuWidth,
              constraints: BoxConstraints(maxHeight: maxHeight),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.985),
                borderRadius: BorderRadius.circular(compact ? 24 : 30),
                border: Border.all(color: Colors.white.withOpacity(.88)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(.18),
                    blurRadius: 46,
                    offset: const Offset(0, 22),
                  ),
                  BoxShadow(
                    color: Colors.white.withOpacity(.72),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(compact ? 24 : 30),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(compact ? 14 : 18,
                          compact ? 13 : 16, compact ? 10 : 14, 10),
                      child: Row(
                        children: [
                          _LogoBox(
                              url: clubLogo,
                              size: compact ? 38 : 44,
                              bgColor: _C.railPanel),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  clubName.trim().isEmpty
                                      ? 'Панель клуба'
                                      : clubName.trim(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _C.text,
                                    fontSize: 15.5,
                                    height: 1,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  safeTeam,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _C.muted,
                                    fontSize: 11.5,
                                    height: 1,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 7),
                            decoration: BoxDecoration(
                              color: _C.railPanel,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: _C.borderSoft),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.apps_rounded,
                                    color: _C.railText,
                                    size: compact ? 16 : 17),
                                const SizedBox(width: 4),
                                Text(
                                  '${items.length} разделов',
                                  style: const TextStyle(
                                    color: _C.railMuted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded,
                                color: _C.railText),
                            tooltip: 'Закрыть',
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: compact ? 14 : 18),
                      child: Container(
                        height: 1,
                        color: _C.borderSoft,
                      ),
                    ),
                    Flexible(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(compact ? 12 : 16, 14,
                            compact ? 12 : 16, compact ? 12 : 16),
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const BouncingScrollPhysics(),
                          itemCount: items.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            mainAxisSpacing: compact ? 8 : 10,
                            crossAxisSpacing: compact ? 6 : 8,
                            childAspectRatio: compact ? .88 : .92,
                          ),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return _FullModuleTile(
                              item: item,
                              active: _sectionIsActive(item.section),
                              proLocked: item.pro && !hasActiveSubscription,
                              onTap: () =>
                                  Navigator.of(context).pop(item.section),
                            );
                          },
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(compact ? 14 : 18, 0,
                          compact ? 14 : 18, compact ? 12 : 14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 9),
                        decoration: BoxDecoration(
                          color: _C.railPanel,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: _C.borderSoft),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.search_rounded,
                                color: _C.railMuted, size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Для быстрого поиска нажмите кнопку «Поиск» рядом с меню',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _C.railMuted,
                                  fontSize: 11.2,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FullModuleTile extends StatefulWidget {
  final _FullMenuItem item;
  final bool active;
  final bool proLocked;
  final VoidCallback onTap;

  const _FullModuleTile({
    required this.item,
    required this.active,
    this.proLocked = false,
    required this.onTap,
  });

  @override
  State<_FullModuleTile> createState() => _FullModuleTileState();
}

class _FullModuleTileState extends State<_FullModuleTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final accent = _C.railText;
    final bg = widget.active
        ? _C.softFor(accent)
        : _hovered
            ? _C.railHover
            : Colors.transparent;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Tooltip(
        message: '${widget.item.title} — ${widget.item.subtitle}',
        waitDuration: const Duration(milliseconds: 240),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: widget.active
                      ? accent.withOpacity(.20)
                      : Colors.transparent,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: widget.active
                              ? accent.withOpacity(.13)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(17),
                          border: Border.all(
                            color: widget.active
                                ? accent.withOpacity(.20)
                                : _C.borderSoft,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black
                                  .withOpacity(widget.active ? .075 : .045),
                              blurRadius: widget.active ? 16 : 10,
                              offset: const Offset(0, 7),
                            ),
                          ],
                        ),
                        child: Icon(
                          widget.item.icon,
                          color: widget.active ? accent : _C.railText,
                          size: 24,
                        ),
                      ),
                      if (widget.item.pro)
                        Positioned(
                          right: -4,
                          top: -4,
                          child: Container(
                            width: 17,
                            height: 17,
                            decoration: BoxDecoration(
                              color: widget.proLocked
                                  ? _C.orangeSoft
                                  : _C.softFor(_C.primaryGreen),
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: Colors.white, width: 1.6),
                            ),
                            child: Icon(
                              widget.proLocked
                                  ? Icons.lock_rounded
                                  : Icons.workspace_premium_rounded,
                              color: widget.proLocked
                                  ? _C.orange
                                  : _C.primaryGreen,
                              size: 10,
                            ),
                          ),
                        ),
                      if (widget.active)
                        Positioned(
                          left: 15,
                          right: 15,
                          bottom: -6,
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              color: accent,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Text(
                    widget.item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: widget.active ? _C.text : _C.railText,
                      fontSize: 11.2,
                      height: 1.08,
                      fontWeight:
                          widget.active ? FontWeight.w600 : FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniCountPill extends StatelessWidget {
  final String value;
  final String label;

  const _MiniCountPill({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _C.border),
      ),
      child: RichText(
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(
          children: [
            TextSpan(
              text: value,
              style: const TextStyle(
                color: _C.text,
                fontSize: 10.8,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: ' $label',
              style: const TextStyle(
                color: _C.muted,
                fontSize: 9.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileGestureHintSheet extends StatelessWidget {
  const _MobileGestureHintSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _C.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.12),
                blurRadius: 26,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(left: 4, bottom: 16),
                decoration: BoxDecoration(
                  color: _C.border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: _C.primaryGreen.withOpacity(.10),
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: _C.primaryGreen.withOpacity(.16)),
                    ),
                    child: const Icon(
                      Icons.swipe_rounded,
                      color: _C.primaryGreen,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Управление жестами',
                          style: TextStyle(
                            color: _C.text,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            height: 1.05,
                          ),
                        ),
                        SizedBox(height: 7),
                        Text(
                          'Шапку убрали, чтобы на телефоне было больше места для клуба и команды.',
                          style: TextStyle(
                            color: _C.muted,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const _GestureTipRow(
                icon: Icons.keyboard_arrow_left_rounded,
                title: 'Листайте экран влево или вправо',
                text:
                    'Так можно быстро переходить между разделами панели клуба.',
              ),
              const SizedBox(height: 10),
              const _GestureTipRow(
                icon: Icons.keyboard_arrow_down_rounded,
                title: 'Потяните экран вниз',
                text:
                    'Так обновляются данные клуба, команд, событий и состава.',
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _C.primaryGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  child: const Text('Понятно'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GestureTipRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _GestureTipRow({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _C.soft,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.border),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _C.border),
            ),
            child: Icon(icon, color: _C.primaryGreen, size: 25),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _C.text,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  text,
                  style: const TextStyle(
                    color: _C.muted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final ClubSection section;
  final IconData icon;
  final String label;
  final String subtitle;
  final bool pro;

  const _NavItem(
    this.section,
    this.icon,
    this.label, {
    required this.subtitle,
    this.pro = false,
  });
}

class _NavGroup {
  final String title;
  final List<_NavItem> items;

  const _NavGroup(this.title, this.items);
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
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _C.soft,
            border: Border.all(color: _C.border),
          ),
          child: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: _C.text,
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String title;
  final String subtitle;
  final ClubSection selectedSection;
  final String selectedTeamName;
  final int? selectedTeamId;
  final List<Map<String, dynamic>> teams;
  final ValueChanged<Map<String, dynamic>> onTeamChanged;
  final VoidCallback onBack;
  final VoidCallback onRefresh;
  final VoidCallback onCreateTeam;
  final VoidCallback onEditClub;
  final VoidCallback onEditTeam;
  final bool refreshing;

  const _TopBar({
    required this.title,
    required this.subtitle,
    required this.selectedSection,
    required this.selectedTeamName,
    required this.selectedTeamId,
    required this.teams,
    required this.onTeamChanged,
    required this.onBack,
    required this.onRefresh,
    required this.onCreateTeam,
    required this.onEditClub,
    required this.onEditTeam,
    required this.refreshing,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _C.accentForSection(selectedSection);
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 10, 10, 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.96),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(.045),
              blurRadius: 24,
              offset: const Offset(0, 12))
        ],
      ),
      child: Row(children: [
        _BackCircleButton(onTap: onBack),
        const SizedBox(width: 10),
        Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: _C.softFor(accent),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: accent.withOpacity(.18))),
            child: Icon(Icons.dashboard_customize_rounded,
                color: accent, size: 22)),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 16,
                  height: 1.05,
                  fontWeight: FontWeight.w600,
                  color: _C.text)),
          const SizedBox(height: 3),
          Text(subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: _C.muted,
                  height: 1.15,
                  fontSize: 10.8,
                  fontWeight: FontWeight.w600)),
        ])),
        const SizedBox(width: 12),
        _TeamChooser(
            teams: teams,
            selectedTeamName: selectedTeamName,
            selectedTeamId: selectedTeamId,
            onTeamChanged: onTeamChanged),
        const SizedBox(width: 8),
        _TopToolButton(
            icon: Icons.edit_rounded, text: 'Клуб', onTap: onEditClub),
        const SizedBox(width: 8),
        _TopToolButton(
            icon: Icons.tune_rounded, text: 'Команда', onTap: onEditTeam),
        const SizedBox(width: 8),
        _TopToolButton(
            icon: Icons.add_rounded, text: 'Новая', onTap: onCreateTeam),
        const SizedBox(width: 8),
        _IconCircleButton(
            icon: refreshing ? Icons.sync_rounded : Icons.refresh_rounded,
            onTap: onRefresh),
      ]),
    );
  }
}

class _TopToolButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  const _TopToolButton({
    required this.icon,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          color: _C.soft2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _C.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: _C.primaryGreen, size: 17),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: _C.text,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ]),
      ),
    );
  }
}

class _TeamChooser extends StatelessWidget {
  final List<Map<String, dynamic>> teams;
  final String selectedTeamName;
  final int? selectedTeamId;
  final ValueChanged<Map<String, dynamic>> onTeamChanged;

  const _TeamChooser({
    required this.teams,
    required this.selectedTeamName,
    required this.selectedTeamId,
    required this.onTeamChanged,
  });

  String _teamName(Map<String, dynamic> team) {
    return '${team['name'] ?? team['team_name'] ?? team['title'] ?? 'Команда'}';
  }

  String _teamSubtitle(Map<String, dynamic> team) {
    final value =
        '${team['age_group'] ?? team['category'] ?? team['sport'] ?? ''}'
            .trim();
    return value.isEmpty ? 'Рабочая команда клуба' : value;
  }

  String? _teamLogo(Map<String, dynamic> team) {
    final value =
        '${team['logo'] ?? team['logo_url'] ?? team['photo'] ?? ''}'.trim();
    return value.isEmpty ? null : value;
  }

  int _teamId(Map<String, dynamic> team) {
    return int.tryParse('${team['id'] ?? team['team_id'] ?? 0}') ?? 0;
  }

  Map<String, dynamic>? _selectedTeam() {
    for (final team in teams) {
      if (_teamId(team) == selectedTeamId) return team;
    }
    return null;
  }

  Future<void> _openTeamPicker(BuildContext context) async {
    if (teams.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала создайте команду')),
      );
      return;
    }

    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final width = MediaQuery.of(sheetContext).size.width;
        final isWide = width >= 760;

        return Padding(
          padding: EdgeInsets.fromLTRB(
            isWide ? 24 : 12,
            0,
            isWide ? 24 : 12,
            12,
          ),
          child: Center(
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(sheetContext).size.height * .82,
                maxWidth: 980,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(.14),
                    blurRadius: 38,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 5,
                    width: 54,
                    margin: const EdgeInsets.only(top: 12, bottom: 10),
                    decoration: BoxDecoration(
                      color: _C.border,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 14, 14),
                    child: Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                _C.greenSoft,
                                _C.primaryGreen.withOpacity(.16),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(
                            Icons.account_tree_rounded,
                            color: _C.primaryGreen,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Выбор команды',
                                style: TextStyle(
                                  color: _C.text,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'Выберите команду для работы в обзоре клуба',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _C.muted,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: GridView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: isWide ? 2 : 1,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: isWide ? 4.9 : 4.35,
                      ),
                      itemCount: teams.length,
                      itemBuilder: (_, index) {
                        final team = teams[index];
                        final id = _teamId(team);
                        final active = id == selectedTeamId;
                        return _TeamPickerTile(
                          name: _teamName(team),
                          subtitle: _teamSubtitle(team),
                          logo: _teamLogo(team),
                          active: active,
                          onTap: () => Navigator.pop(sheetContext, team),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (selected != null) onTeamChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    final team = _selectedTeam();
    final subtitle = team == null ? 'Команда не выбрана' : _teamSubtitle(team);
    final logo = team == null ? null : _teamLogo(team);

    return InkWell(
      borderRadius: BorderRadius.circular(28),
      onTap: () => _openTeamPicker(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              _C.greenSoft.withOpacity(.50),
              _C.soft2.withOpacity(.82),
            ],
          ),
        ),
        child: Row(
          children: [
            _LogoBox(url: logo, size: 54, bgColor: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Активная команда',
                    style: TextStyle(
                      color: _C.muted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    selectedTeamName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _C.text,
                      fontSize: 16,
                      height: 1.05,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _C.muted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Сменить',
                    style: TextStyle(
                      color: _C.primaryGreen,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: _C.primaryGreen,
                    size: 20,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamPickerTile extends StatelessWidget {
  final String name;
  final String subtitle;
  final String? logo;
  final bool active;
  final VoidCallback onTap;

  const _TeamPickerTile({
    required this.name,
    required this.subtitle,
    required this.logo,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? _C.greenSoft : _C.soft2,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _LogoBox(url: logo, size: 44, bgColor: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _C.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _C.muted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(
                active
                    ? Icons.check_circle_rounded
                    : Icons.chevron_right_rounded,
                color: active ? _C.primaryGreen : _C.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverviewControlCenter extends StatelessWidget {
  final List<Map<String, dynamic>> teams;
  final String selectedTeamName;
  final int? selectedTeamId;
  final ValueChanged<Map<String, dynamic>> onTeamChanged;
  final VoidCallback onCreateTeam;
  final VoidCallback onEditClub;
  final VoidCallback onEditTeam;

  const _OverviewControlCenter({
    required this.teams,
    required this.selectedTeamName,
    required this.selectedTeamId,
    required this.onTeamChanged,
    required this.onCreateTeam,
    required this.onEditClub,
    required this.onEditTeam,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(radius: 30),
      child: LayoutBuilder(
        builder: (context, c) {
          final compact = c.maxWidth < 680;
          final actions = [
            _OverviewActionButton(
              icon: Icons.edit_note_rounded,
              title: 'Редактор клуба',
              subtitle: 'Название, логотип, описание',
              onTap: onEditClub,
            ),
            _OverviewActionButton(
              icon: Icons.tune_rounded,
              title: 'Редактор команды',
              subtitle: 'Данные активной команды',
              onTap: onEditTeam,
            ),
            _OverviewActionButton(
              icon: Icons.add_rounded,
              title: 'Новая команда',
              subtitle: 'Создать структуру клуба',
              filled: true,
              onTap: onCreateTeam,
            ),
          ];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _OverviewControlTitle(),
              const SizedBox(height: 16),
              _TeamChooser(
                teams: teams,
                selectedTeamName: selectedTeamName,
                selectedTeamId: selectedTeamId,
                onTeamChanged: onTeamChanged,
              ),
              const SizedBox(height: 14),
              if (compact)
                Column(
                  children: [
                    for (int i = 0; i < actions.length; i++) ...[
                      actions[i],
                      if (i != actions.length - 1) const SizedBox(height: 10),
                    ],
                  ],
                )
              else
                Row(
                  children: [
                    for (int i = 0; i < actions.length; i++) ...[
                      Expanded(child: actions[i]),
                      if (i != actions.length - 1) const SizedBox(width: 10),
                    ],
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

class _OverviewControlTitle extends StatelessWidget {
  const _OverviewControlTitle();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: _C.greenSoft,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: _C.primaryGreen.withOpacity(.16)),
          ),
          child: const Icon(
            Icons.space_dashboard_rounded,
            color: _C.primaryGreen,
            size: 23,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Рабочий обзор клуба',
                style: TextStyle(
                  color: _C.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Активная команда, действия и состояние клуба в одном месте',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _C.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        const _HelpCircle(
          title: 'Как работать с обзором клуба',
          text:
              'Обзор — это стартовый рабочий экран. Здесь выбирается активная команда, проверяется состояние клуба и выполняются быстрые действия без лишних переходов.',
          steps: [
            'Сначала выберите активную команду — от неё зависят состав, тренеры, матчи и календарь.',
            'Через быстрые действия добавляйте игроков, открывайте тренеров, матчи и видеоанализ.',
            'В правой колонке следите за подсказками: что заполнить и что проверить перед работой.',
            'Если данных мало, обзор подскажет, с чего лучше начать.',
          ],
        ),
      ],
    );
  }
}

class _OverviewActionButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool filled;
  final VoidCallback onTap;

  const _OverviewActionButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = filled ? _C.primaryGreen : Colors.white;
    final fg = filled ? Colors.white : _C.text;
    final sub = filled ? Colors.white.withOpacity(.82) : _C.muted;
    final iconBg = filled ? Colors.white.withOpacity(.16) : _C.greenSoft;
    final iconColor = filled ? Colors.white : _C.primaryGreen;

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        constraints: const BoxConstraints(minHeight: 78),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: filled ? _C.primaryGreen.withOpacity(.25) : _C.border,
          ),
          boxShadow: [
            BoxShadow(
              color: filled
                  ? _C.primaryGreen.withOpacity(.15)
                  : Colors.black.withOpacity(.025),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon, size: 21, color: iconColor),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: fg,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: sub,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewPanel extends StatelessWidget {
  final String clubName;
  final String? clubLogo;
  final String clubDescription;
  final String selectedTeamName;
  final List<Map<String, dynamic>> teams;
  final List<Map<String, dynamic>> trainers;
  final List<Map<String, dynamic>> events;
  final List<Map<String, dynamic>> latestPlans;
  final int playersCount;
  final int? selectedTeamId;
  final ValueChanged<Map<String, dynamic>> onTeamChanged;
  final VoidCallback onCreateTeam;
  final VoidCallback onEditClub;
  final VoidCallback onEditTeam;
  final VoidCallback onOpenTeams;
  final VoidCallback onOpenRoster;
  final VoidCallback onOpenTrainers;
  final VoidCallback onOpenTeamTrainers;
  final VoidCallback onOpenMatches;
  final VoidCallback onOpenPlans;
  final VoidCallback onOpenVideo;

  const _OverviewPanel({
    required this.clubName,
    required this.clubLogo,
    required this.clubDescription,
    required this.selectedTeamName,
    required this.teams,
    required this.trainers,
    required this.events,
    required this.latestPlans,
    required this.playersCount,
    required this.selectedTeamId,
    required this.onTeamChanged,
    required this.onCreateTeam,
    required this.onEditClub,
    required this.onEditTeam,
    required this.onOpenTeams,
    required this.onOpenRoster,
    required this.onOpenTrainers,
    required this.onOpenTeamTrainers,
    required this.onOpenMatches,
    required this.onOpenPlans,
    required this.onOpenVideo,
  });

  String _clean(Object? value, String fallback) {
    final text = '${value ?? ''}'.trim();
    if (text.isEmpty || text == 'null') return fallback;
    return text;
  }

  int _teamId(Map<String, dynamic> team) {
    return int.tryParse('${team['id'] ?? team['team_id'] ?? 0}') ?? 0;
  }

  String _teamName(Map<String, dynamic> team) {
    return _clean(
        team['name'] ?? team['team_name'] ?? team['title'], 'Команда');
  }

  String _teamSubtitle(Map<String, dynamic> team) {
    return _clean(
        team['age_group'] ?? team['category'] ?? team['sport'], 'Футбол');
  }

  String? _teamLogo(Map<String, dynamic>? team) {
    if (team == null) return null;
    final raw =
        '${team['logo'] ?? team['logo_url'] ?? team['photo'] ?? ''}'.trim();
    return raw.isEmpty || raw == 'null' ? null : raw;
  }

  bool _isSelectedTeam(Map<String, dynamic> team) {
    final id = _teamId(team);
    return selectedTeamId != null &&
        selectedTeamId! > 0 &&
        id == selectedTeamId;
  }

  Map<String, dynamic>? _activeTeam() {
    for (final team in teams) {
      if (_isSelectedTeam(team)) return team;
    }
    return teams.isNotEmpty ? teams.first : null;
  }

  @override
  Widget build(BuildContext context) {
    final activeTeam = _activeTeam();
    final title = clubName.trim().isEmpty ? 'Клуб' : clubName.trim();
    final activeTeamName = activeTeam == null
        ? (selectedTeamName.trim().isEmpty
            ? 'Команда не выбрана'
            : selectedTeamName.trim())
        : _teamName(activeTeam);
    final recentEvents = events.take(3).toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final medium = constraints.maxWidth >= 620;

        return ListView(
          padding: const EdgeInsets.only(right: 2, bottom: 24),
          children: [
            _clubHero(
              title: title,
              activeTeamName: activeTeamName,
              activeTeam: activeTeam,
              wide: wide,
            ),
            const SizedBox(height: 14),
            _statsGrid(columns: wide ? 4 : (medium ? 2 : 1)),
            const SizedBox(height: 14),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: _teamBlock(activeTeam, activeTeamName),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 7,
                    child: _workBlock(recentEvents),
                  ),
                ],
              )
            else ...[
              _teamBlock(activeTeam, activeTeamName),
              const SizedBox(height: 14),
              _workBlock(recentEvents),
            ],
          ],
        );
      },
    );
  }

  Widget _clubHero({
    required String title,
    required String activeTeamName,
    required Map<String, dynamic>? activeTeam,
    required bool wide,
  }) {
    return Container(
      padding: EdgeInsets.all(wide ? 20 : 16),
      decoration: _overviewCard(radius: 30),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LogoBox(
            url: clubLogo,
            size: wide ? 72 : 60,
            bgColor: _C.greenSoft,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _softBadge(Icons.space_dashboard_rounded, 'Обзор клуба'),
                    if (selectedTeamId != null && selectedTeamId! > 0)
                      _softBadge(Icons.check_circle_rounded, 'Команда выбрана'),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _C.text,
                    fontSize: wide ? 25 : 21,
                    height: 1.05,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  activeTeamName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _C.muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _circleAction(
            icon: Icons.edit_rounded,
            tooltip: 'Редактировать клуб',
            onTap: onEditClub,
          ),
        ],
      ),
    );
  }

  Widget _statsGrid({required int columns}) {
    final items = [
      _OverviewMetricData(
        title: 'Команды',
        value: '${teams.length}',
        icon: Icons.account_tree_rounded,
        onTap: onOpenTeams,
      ),
      _OverviewMetricData(
        title: 'Игроки',
        value: '$playersCount',
        icon: Icons.groups_2_rounded,
        onTap: onOpenRoster,
      ),
      _OverviewMetricData(
        title: 'Тренеры',
        value: '${trainers.length}',
        icon: Icons.badge_rounded,
        onTap: onOpenTrainers,
      ),
      _OverviewMetricData(
        title: 'События',
        value: '${events.length}',
        icon: Icons.event_available_rounded,
        onTap: onOpenMatches,
      ),
    ];

    return LayoutBuilder(
      builder: (context, c) {
        final spacing = 10.0;
        final width = (c.maxWidth - (columns - 1) * spacing) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items
              .map(
                (item) => SizedBox(
                  width: width,
                  child: _metricCard(item),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _metricCard(_OverviewMetricData item) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: _C.greenSoft,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x08000000),
                    blurRadius: 14,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(item.icon, color: _C.primaryGreen, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _C.primaryGreen,
                      fontSize: 22,
                      height: 1,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _C.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: _C.primaryGreen, size: 21),
          ],
        ),
      ),
    );
  }

  Widget _teamBlock(Map<String, dynamic>? activeTeam, String activeTeamName) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _overviewCard(radius: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            icon: Icons.shield_rounded,
            title: 'Активная команда',
            actionText: 'Выбрать',
            onTap: null,
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _C.bg,
              borderRadius: BorderRadius.circular(21),
            ),
            child: Row(
              children: [
                _LogoBox(
                  url: _teamLogo(activeTeam),
                  size: 54,
                  bgColor: Colors.white,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activeTeamName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _C.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        activeTeam == null
                            ? 'Выберите команду для работы'
                            : _teamSubtitle(activeTeam),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _C.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _teamPickerButton(),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _quickAction(
            icon: Icons.add_rounded,
            title: 'Создать команду',
            onTap: onCreateTeam,
          ),
          const SizedBox(height: 8),
          _quickAction(
            icon: Icons.tune_rounded,
            title: 'Редактировать команду',
            onTap: onEditTeam,
          ),
          const SizedBox(height: 8),
          _quickAction(
            icon: Icons.groups_2_rounded,
            title: 'Открыть состав',
            onTap: onOpenRoster,
          ),
        ],
      ),
    );
  }

  Widget _teamPickerButton() {
    return PopupMenuButton<Map<String, dynamic>>(
      tooltip: 'Выбрать команду',
      onSelected: onTeamChanged,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      itemBuilder: (context) {
        if (teams.isEmpty) {
          return const [
            PopupMenuItem<Map<String, dynamic>>(
              enabled: false,
              child: Text('Команд пока нет'),
            ),
          ];
        }

        return teams.map((team) {
          final active = _isSelectedTeam(team);
          return PopupMenuItem<Map<String, dynamic>>(
            value: team,
            child: Row(
              children: [
                Icon(
                  active ? Icons.check_circle_rounded : Icons.circle_outlined,
                  color: active ? _C.primaryGreen : _C.muted,
                  size: 19,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _teamName(team),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          );
        }).toList();
      },
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: _C.primaryGreen,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _C.primaryGreen.withOpacity(.20),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Icon(Icons.keyboard_arrow_down_rounded,
            color: Colors.white, size: 24),
      ),
    );
  }

  Widget _workBlock(List<Map<String, dynamic>> recentEvents) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _overviewCard(radius: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            icon: Icons.dashboard_customize_rounded,
            title: 'Рабочие разделы',
            actionText: '',
            onTap: null,
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, c) {
              final compact = c.maxWidth < 560;
              final modules = [
                _moduleCard(
                    Icons.sports_soccer_rounded, 'Матчи', onOpenMatches),
                _moduleCard(Icons.badge_rounded, 'Тренеры', onOpenTeamTrainers),
                _moduleCard(Icons.folder_copy_rounded, 'Планы', onOpenPlans),
                _moduleCard(Icons.play_circle_rounded, 'Видео', onOpenVideo),
              ];

              if (compact) {
                return Column(
                  children: [
                    for (int i = 0; i < modules.length; i++) ...[
                      modules[i],
                      if (i != modules.length - 1) const SizedBox(height: 8),
                    ],
                  ],
                );
              }

              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: modules
                    .map((item) =>
                        SizedBox(width: (c.maxWidth - 10) / 2, child: item))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 16),
          _sectionTitle(
            icon: Icons.event_note_rounded,
            title: 'Ближайшее',
            actionText: 'Открыть',
            onTap: onOpenMatches,
          ),
          const SizedBox(height: 10),
          if (recentEvents.isEmpty)
            _emptyLine('Пока нет ближайших событий.')
          else
            for (int i = 0; i < recentEvents.length; i++) ...[
              _eventTile(recentEvents[i]),
              if (i != recentEvents.length - 1) const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }

  Widget _moduleCard(IconData icon, String title, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _C.bg,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _C.greenSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: _C.primaryGreen, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _C.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: _C.muted, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _quickAction({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x07000000),
              blurRadius: 14,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: _C.greenSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: _C.primaryGreen, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _C.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: _C.muted, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle({
    required IconData icon,
    required String title,
    required String actionText,
    required VoidCallback? onTap,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _C.greenSoft,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: _C.primaryGreen, size: 19),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _C.text,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (actionText.isNotEmpty && onTap != null)
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Text(
                actionText,
                style: const TextStyle(
                  color: _C.primaryGreen,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _eventTile(Map<String, dynamic> event) {
    final title = _clean(
        event['title'] ?? event['name'] ?? event['event_title'], 'Событие');
    final date =
        _clean(event['date'] ?? event['event_date'] ?? event['start_at'], '');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _C.bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.event_rounded,
                color: _C.primaryGreen, size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _C.text,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (date.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    date,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _C.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyLine(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: _C.muted,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _softBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _C.greenSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _C.primaryGreen, size: 15),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: _C.primaryGreen,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 42,
          height: 42,
          decoration: const BoxDecoration(
            color: _C.greenSoft,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: _C.primaryGreen, size: 20),
        ),
      ),
    );
  }

  BoxDecoration _overviewCard({double radius = 28}) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: const [
        BoxShadow(
          color: Color(0x08000000),
          blurRadius: 22,
          offset: Offset(0, 10),
        ),
      ],
    );
  }
}

class _OverviewMetricData {
  final String title;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  const _OverviewMetricData({
    required this.title,
    required this.value,
    required this.icon,
    required this.onTap,
  });
}

class _OverviewCheckItem {
  final String title;
  final bool done;
  const _OverviewCheckItem(this.title, this.done);
}

class _OverviewWorkHero extends StatelessWidget {
  final String clubName;
  final String? clubLogo;
  final String clubDescription;
  final String selectedTeamName;
  final int percent;
  final VoidCallback onEditClub;

  const _OverviewWorkHero({
    required this.clubName,
    required this.clubLogo,
    required this.clubDescription,
    required this.selectedTeamName,
    required this.percent,
    required this.onEditClub,
  });

  @override
  Widget build(BuildContext context) {
    final description = clubDescription.trim().isEmpty
        ? 'Добавьте описание клуба, чтобы тренерам и родителям было проще понимать структуру и задачи.'
        : clubDescription.trim();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.03),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final compact = c.maxWidth < 620;
          final top = Row(
            children: [
              _LogoBox(
                url: clubLogo,
                size: compact ? 66 : 78,
                bgColor: _C.greenSoft,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: _C.greenSoft,
                            borderRadius: BorderRadius.circular(99),
                            border: Border.all(
                                color: _C.primaryGreen.withOpacity(.18)),
                          ),
                          child: const Text(
                            'Рабочий центр',
                            style: TextStyle(
                              color: _C.primaryGreen,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            selectedTeamName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _C.muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      clubName.trim().isEmpty ? 'Клуб' : clubName,
                      maxLines: compact ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _C.text,
                        fontSize: compact ? 22 : 27,
                        height: 1.02,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      maxLines: compact ? 3 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _C.muted,
                        fontSize: 13,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (!compact) ...[
                const SizedBox(width: 16),
                _OverviewProgressBadge(percent: percent),
                const SizedBox(width: 10),
                _RosterHeaderAction(
                  icon: Icons.edit_rounded,
                  tooltip: 'Редактировать клуб',
                  onTap: onEditClub,
                ),
              ],
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                top,
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(child: _OverviewProgressBadge(percent: percent)),
                    const SizedBox(width: 10),
                    _RosterHeaderAction(
                      icon: Icons.edit_rounded,
                      tooltip: 'Редактировать клуб',
                      onTap: onEditClub,
                    ),
                  ],
                ),
              ],
            );
          }

          return top;
        },
      ),
    );
  }
}

class _OverviewProgressBadge extends StatelessWidget {
  final int percent;
  const _OverviewProgressBadge({required this.percent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _C.greenSoft,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _C.primaryGreen.withOpacity(.18)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$percent%',
            style: const TextStyle(
              color: _C.primaryGreen,
              fontSize: 21,
              height: 1,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'готовность',
            style: TextStyle(
              color: _C.muted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewStatsStrip extends StatelessWidget {
  final int teamsCount;
  final int playersCount;
  final int trainersCount;
  final int eventsCount;
  final VoidCallback onOpenTeams;
  final VoidCallback onOpenRoster;
  final VoidCallback onOpenTrainers;

  const _OverviewStatsStrip({
    required this.teamsCount,
    required this.playersCount,
    required this.trainersCount,
    required this.eventsCount,
    required this.onOpenTeams,
    required this.onOpenRoster,
    required this.onOpenTrainers,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final columns = c.maxWidth >= 820 ? 4 : (c.maxWidth >= 520 ? 2 : 1);
        final itemWidth = (c.maxWidth - (columns - 1) * 10) / columns;
        final items = [
          _OverviewStatCard(
            icon: Icons.account_tree_rounded,
            title: 'Команды',
            value: '$teamsCount',
            subtitle: 'структура клуба',
            onTap: onOpenTeams,
          ),
          _OverviewStatCard(
            icon: Icons.groups_2_rounded,
            title: 'Игроки',
            value: '$playersCount',
            subtitle: 'в активной команде',
            onTap: onOpenRoster,
          ),
          _OverviewStatCard(
            icon: Icons.badge_rounded,
            title: 'Тренеры',
            value: '$trainersCount',
            subtitle: 'штаб клуба',
            onTap: onOpenTrainers,
          ),
          _OverviewStatCard(
            icon: Icons.event_available_rounded,
            title: 'События',
            value: '$eventsCount',
            subtitle: 'календарь клуба',
            onTap: () {},
          ),
        ];

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: items
              .map((item) => SizedBox(width: itemWidth, child: item))
              .toList(),
        );
      },
    );
  }
}

class _OverviewStatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final VoidCallback onTap;

  const _OverviewStatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(radius: 24),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _C.greenSoft,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: _C.primaryGreen, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _C.text,
                      fontSize: 22,
                      height: 1,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _C.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _C.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewQuickActionsGrid extends StatelessWidget {
  final VoidCallback onOpenRoster;
  final VoidCallback onOpenTrainers;
  final VoidCallback onOpenTeamTrainers;
  final VoidCallback onOpenMatches;
  final VoidCallback onOpenPlans;
  final VoidCallback onOpenVideo;
  final VoidCallback onCreateTeam;

  const _OverviewQuickActionsGrid({
    required this.onOpenRoster,
    required this.onOpenTrainers,
    required this.onOpenTeamTrainers,
    required this.onOpenMatches,
    required this.onOpenPlans,
    required this.onOpenVideo,
    required this.onCreateTeam,
  });
  @override
  Widget build(BuildContext context) {
    final actions = [
      _OverviewModuleCard(
        icon: Icons.groups_2_rounded,
        title: 'Состав',
        subtitle: 'игроки и карточки',
        active: true,
        onTap: onOpenRoster,
      ),
      _OverviewModuleCard(
        icon: Icons.badge_rounded,
        title: 'Тренеры',
        subtitle: 'штаб и назначения',
        active: true,
        onTap: onOpenTrainers,
      ),
      _OverviewModuleCard(
        icon: Icons.manage_accounts_rounded,
        title: 'Тренеры команды',
        subtitle: 'привязка к составу',
        onTap: onOpenTeamTrainers,
      ),
      _OverviewModuleCard(
        icon: Icons.sports_soccer_rounded,
        title: 'Матчи',
        subtitle: 'расписание и результаты',
        onTap: onOpenMatches,
      ),
      _OverviewModuleCard(
        icon: Icons.video_camera_back_rounded,
        title: 'Видеоанализ',
        subtitle: 'матчи и разбор',
        onTap: onOpenVideo,
      ),
      _OverviewModuleCard(
        icon: Icons.add_rounded,
        title: 'Новая команда',
        subtitle: 'добавить в клуб',
        onTap: onCreateTeam,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(radius: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Expanded(
                child: Text(
                  'Быстрые действия',
                  style: TextStyle(
                    color: _C.text,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _HelpCircle(
                title: 'Быстрые действия',
                text:
                    'Это рабочие карточки для быстрых переходов. Они не дублируют левое меню, а помогают тренеру сразу открыть нужное действие из обзора.',
                steps: [
                  'Откройте состав, если нужно быстро проверить игрока.',
                  'Откройте тренеров, если нужно посмотреть штаб или назначение.',
                  'Матчи и видеоанализ размещены рядом, потому что обычно используются вместе.',
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, c) {
              final columns =
                  c.maxWidth >= 760 ? 3 : (c.maxWidth >= 500 ? 2 : 1);
              final itemWidth = (c.maxWidth - (columns - 1) * 10) / columns;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: actions
                    .map((item) => SizedBox(width: itemWidth, child: item))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _OverviewModuleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool active;
  final VoidCallback onTap;

  const _OverviewModuleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        constraints: const BoxConstraints(minHeight: 92),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: active ? _C.greenSoft : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: active ? _C.primaryGreen.withOpacity(.24) : _C.border,
            width: active ? 1.3 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: active
                  ? _C.primaryGreen.withOpacity(.10)
                  : Colors.black.withOpacity(.025),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: active ? Colors.white : _C.soft2,
                borderRadius: BorderRadius.circular(17),
                border: Border.all(
                    color:
                        active ? _C.primaryGreen.withOpacity(.16) : _C.border),
              ),
              child: Icon(icon,
                  color: active ? _C.primaryGreen : _C.black, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _C.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _C.muted,
                      fontSize: 11,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: active ? _C.primaryGreen : _C.soft2,
                shape: BoxShape.circle,
                border: Border.all(color: active ? _C.primaryGreen : _C.border),
              ),
              child: Icon(
                active ? Icons.check_rounded : Icons.chevron_right_rounded,
                color: active ? Colors.white : _C.muted,
                size: 19,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewEventsCard extends StatelessWidget {
  final List<Map<String, dynamic>> events;
  const _OverviewEventsCard({required this.events});

  @override
  Widget build(BuildContext context) {
    return _SolidCard(
      title: 'Ближайшие события',
      helpText:
          'Здесь отображаются ближайшие события клуба. Блок помогает быстро понять, что запланировано по клубу и командам.',
      helpSteps: const [
        'Добавляйте события в календаре клуба или команды.',
        'Проверяйте дату и название события перед тренировкой или матчем.',
        'Если событий нет, блок покажет пустое состояние без ошибки.',
      ],
      child: events.isEmpty
          ? const _EmptyText('Пока нет событий для отображения.')
          : Column(
              children: events.map((event) {
                final title = '${event['title'] ?? event['name'] ?? 'Событие'}';
                final date =
                    '${event['date'] ?? event['event_date'] ?? event['start_date'] ?? ''}';
                return _EventRow(title: title, date: date);
              }).toList(),
            ),
    );
  }
}

class _OverviewReadinessCard extends StatelessWidget {
  final int percent;
  final List<_OverviewCheckItem> items;

  const _OverviewReadinessCard({
    required this.percent,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(radius: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _C.greenSoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.verified_rounded,
                    color: _C.primaryGreen, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Готовность клуба',
                      style: TextStyle(
                        color: _C.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$percent% заполнено',
                      style: const TextStyle(
                        color: _C.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: percent / 100,
              minHeight: 9,
              backgroundColor: _C.soft2,
              color: _C.primaryGreen,
            ),
          ),
          const SizedBox(height: 14),
          Column(
            children: items.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: Row(
                  children: [
                    Icon(
                      item.done
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: item.done ? _C.primaryGreen : _C.muted,
                      size: 18,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: item.done ? _C.text : _C.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _OverviewAdvicePanel extends StatelessWidget {
  final int playersCount;
  final int trainersCount;
  final int eventsCount;
  final String selectedTeamName;
  final VoidCallback onOpenRoster;
  final VoidCallback onOpenTrainers;
  final VoidCallback onOpenMatches;

  const _OverviewAdvicePanel({
    required this.playersCount,
    required this.trainersCount,
    required this.eventsCount,
    required this.selectedTeamName,
    required this.onOpenRoster,
    required this.onOpenTrainers,
    required this.onOpenMatches,
  });

  @override
  Widget build(BuildContext context) {
    final tips = <_OverviewTipData>[];
    if (playersCount <= 0) {
      tips.add(_OverviewTipData(
        icon: Icons.person_add_alt_1_rounded,
        title: 'Добавьте игроков',
        text:
            'Состав пустой — начните с добавления игроков в активную команду.',
        onTap: onOpenRoster,
      ));
    }
    if (trainersCount <= 0) {
      tips.add(_OverviewTipData(
        icon: Icons.badge_rounded,
        title: 'Добавьте тренеров',
        text:
            'Штаб клуба пока пустой. Добавьте тренера и назначьте его в команду.',
        onTap: onOpenTrainers,
      ));
    }
    if (eventsCount <= 0) {
      tips.add(_OverviewTipData(
        icon: Icons.event_available_rounded,
        title: 'Запланируйте событие',
        text:
            'Добавьте тренировку или матч, чтобы обзор стал рабочим календарём.',
        onTap: onOpenMatches,
      ));
    }
    if (tips.isEmpty) {
      tips.add(_OverviewTipData(
        icon: Icons.task_alt_rounded,
        title: 'Можно работать',
        text:
            'Основные данные заполнены. Проверьте состав, тренеров и ближайшие матчи.',
        onTap: onOpenRoster,
      ));
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFDE68A)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.022),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.lightbulb_rounded, color: Color(0xFFF59E0B), size: 22),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Подсказки для работы',
                  style: TextStyle(
                    color: _C.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < tips.length; i++) ...[
            _OverviewTipCard(data: tips[i]),
            if (i != tips.length - 1) const SizedBox(height: 9),
          ],
        ],
      ),
    );
  }
}

class _OverviewTipData {
  final IconData icon;
  final String title;
  final String text;
  final VoidCallback onTap;

  const _OverviewTipData({
    required this.icon,
    required this.title,
    required this.text,
    required this.onTap,
  });
}

class _OverviewTipCard extends StatelessWidget {
  final _OverviewTipData data;
  const _OverviewTipCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: data.onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.72),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(data.icon, color: const Color(0xFFF59E0B), size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _C.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    data.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _C.muted,
                      fontSize: 11,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: _C.muted, size: 20),
          ],
        ),
      ),
    );
  }
}

class _OverviewLiveFeedCard extends StatelessWidget {
  final String clubName;
  final String selectedTeamName;
  final List<Map<String, dynamic>> events;
  final List<Map<String, dynamic>> teams;
  final List<Map<String, dynamic>> trainers;
  final int playersCount;
  final VoidCallback onOpenRoster;
  final VoidCallback onOpenTrainers;
  final VoidCallback onOpenMatches;
  final VoidCallback onOpenTeams;

  const _OverviewLiveFeedCard({
    required this.clubName,
    required this.selectedTeamName,
    required this.events,
    required this.teams,
    required this.trainers,
    required this.playersCount,
    required this.onOpenRoster,
    required this.onOpenTrainers,
    required this.onOpenMatches,
    required this.onOpenTeams,
  });

  String _value(Map<String, dynamic> source, List<String> keys,
      [String fallback = '']) {
    for (final key in keys) {
      final value = '${source[key] ?? ''}'.trim();
      if (value.isNotEmpty && value != 'null') return value;
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final items = <_OverviewFeedItem>[];

    for (final event in events.take(4)) {
      final title = _value(
          event, const ['title', 'name', 'event_title'], 'Событие клуба');
      final date = _value(
          event,
          const ['date', 'event_date', 'start_date', 'created_at'],
          'Дата не указана');
      items.add(_OverviewFeedItem(
        icon: Icons.event_available_rounded,
        title: title,
        subtitle: date,
        label: 'Событие',
        tint: _C.blueSoft,
        color: _C.blue,
        onTap: onOpenMatches,
      ));
    }

    for (final trainer in trainers.take(3)) {
      final first = _value(trainer, const ['first_name', 'firstname'], '');
      final last = _value(trainer, const ['last_name', 'lastname'], '');
      final full = _value(
              trainer, const ['full_name', 'fullName', 'name'], '$first $last')
          .trim();
      items.add(_OverviewFeedItem(
        icon: Icons.badge_rounded,
        title: full.isEmpty ? 'Тренерский штаб' : full,
        subtitle: _value(trainer, const ['role', 'position', 'specialization'],
            'Тренер клуба'),
        label: 'Тренер',
        tint: _C.greenSoft,
        color: _C.primaryGreen,
        onTap: onOpenTrainers,
      ));
    }

    for (final team in teams.take(3)) {
      final title =
          _value(team, const ['name', 'title', 'team_name'], 'Команда клуба');
      items.add(_OverviewFeedItem(
        icon: Icons.groups_2_rounded,
        title: title,
        subtitle:
            title == selectedTeamName ? 'Активная команда' : 'Команда клуба',
        label: title == selectedTeamName ? 'Активна' : 'Команда',
        tint: _C.bg,
        color: _C.black,
        onTap: onOpenTeams,
      ));
    }

    if (items.isEmpty) {
      items.addAll([
        _OverviewFeedItem(
          icon: Icons.groups_2_rounded,
          title: selectedTeamName,
          subtitle: playersCount > 0
              ? '$playersCount игроков в активной команде'
              : 'Добавьте игроков в состав',
          label: 'Состав',
          tint: _C.greenSoft,
          color: _C.primaryGreen,
          onTap: onOpenRoster,
        ),
        _OverviewFeedItem(
          icon: Icons.chat_bubble_outline_rounded,
          title: 'Чаты и сообщения',
          subtitle:
              'После подключения API здесь появятся последние сообщения команды',
          label: 'Чат',
          tint: const Color(0xFFF3E8FF),
          color: _C.purple,
          onTap: onOpenTeams,
        ),
      ]);
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(radius: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _C.greenSoft,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _C.primaryGreen.withOpacity(.16)),
                ),
                child: const Icon(Icons.dynamic_feed_rounded,
                    color: _C.primaryGreen, size: 23),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Живая лента',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _C.text,
                        fontSize: 17,
                        height: 1.05,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'События, команды, тренеры и рабочая активность',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _C.muted,
                        fontSize: 12,
                        height: 1.18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const _HelpCircle(
                title: 'Живая лента обзора',
                text:
                    'Правая колонка не заменяет выбор команды. Она показывает последние рабочие действия клуба: события, тренеров, команды, а после подключения API — сообщения чатов, медкарту и аналитику.',
                steps: [
                  'Выбор команды остаётся в центральном блоке обзора.',
                  'В ленте справа отображается то, что уже есть в базе и относится к клубу.',
                  'Нажмите на строку ленты, чтобы быстро перейти к нужному модулю.',
                  'Когда добавим API активности, сюда попадут сообщения чатов и старые записи из базы.',
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _C.bg,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _C.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: _C.primaryGreen,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$clubName · $selectedTeamName',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _C.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < items.take(8).length; i++) ...[
            _OverviewFeedTile(item: items[i], active: i == 0),
            if (i != items.take(8).length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _OverviewFeedItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final String label;
  final Color tint;
  final Color color;
  final VoidCallback onTap;

  const _OverviewFeedItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.label,
    required this.tint,
    required this.color,
    required this.onTap,
  });
}

class _OverviewFeedTile extends StatelessWidget {
  final _OverviewFeedItem item;
  final bool active;

  const _OverviewFeedTile({required this.item, required this.active});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: active ? _C.greenSoft : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: active ? const Color(0xFF86E1A6) : _C.border,
            width: active ? 1.4 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: active
                  ? const Color(0x2200C853)
                  : Colors.black.withOpacity(.025),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: item.tint,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: item.color.withOpacity(.10)),
              ),
              child: Icon(item.icon, color: item.color, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _C.text,
                            fontSize: 13,
                            height: 1.12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: active ? Colors.white : _C.bg,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                              color:
                                  active ? const Color(0xFFBBF7D0) : _C.border),
                        ),
                        child: Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: active ? _C.primaryGreen : _C.muted,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    item.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _C.muted,
                      fontSize: 11,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: active ? _C.primaryGreen : _C.bg,
                shape: BoxShape.circle,
                border: Border.all(color: active ? _C.primaryGreen : _C.border),
              ),
              child: Icon(
                active ? Icons.check_rounded : Icons.chevron_right_rounded,
                color: active ? Colors.white : _C.muted,
                size: 19,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewActivityCard extends StatelessWidget {
  final int teamsCount;
  final int playersCount;
  final int trainersCount;
  final int eventsCount;

  const _OverviewActivityCard({
    required this.teamsCount,
    required this.playersCount,
    required this.trainersCount,
    required this.eventsCount,
  });

  @override
  Widget build(BuildContext context) {
    final rows = [
      _OverviewActivityRowData(
          Icons.account_tree_rounded, 'Структура клуба', '$teamsCount команд'),
      _OverviewActivityRowData(
          Icons.groups_2_rounded, 'Активный состав', '$playersCount игроков'),
      _OverviewActivityRowData(
          Icons.badge_rounded, 'Тренерский штаб', '$trainersCount тренеров'),
      _OverviewActivityRowData(
          Icons.event_note_rounded, 'Планирование', '$eventsCount событий'),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(radius: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Сводка активности',
            style: TextStyle(
              color: _C.text,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < rows.length; i++) ...[
            _OverviewActivityRow(data: rows[i]),
            if (i != rows.length - 1) const SizedBox(height: 9),
          ],
        ],
      ),
    );
  }
}

class _OverviewActivityRowData {
  final IconData icon;
  final String title;
  final String value;
  const _OverviewActivityRowData(this.icon, this.title, this.value);
}

class _OverviewActivityRow extends StatelessWidget {
  final _OverviewActivityRowData data;
  const _OverviewActivityRow({required this.data});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _C.soft2,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(data.icon, color: _C.black, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            data.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _C.text,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          data.value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _C.muted,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _CompletionInfoCard extends StatelessWidget {
  final String clubDescription;
  final String? clubLogo;
  final int teamsCount;
  final int trainersCount;
  final int playersCount;
  final int eventsCount;
  final String selectedTeamName;

  const _CompletionInfoCard({
    required this.clubDescription,
    required this.clubLogo,
    required this.teamsCount,
    required this.trainersCount,
    required this.playersCount,
    required this.eventsCount,
    required this.selectedTeamName,
  });

  @override
  Widget build(BuildContext context) {
    final missing = <String>[];

    if (clubDescription.trim().isEmpty) missing.add('Описание клуба');
    if (clubLogo == null || clubLogo!.trim().isEmpty)
      missing.add('Логотип клуба');
    if (teamsCount <= 0) missing.add('Команды');
    if (trainersCount <= 0) missing.add('Тренеры');
    if (selectedTeamName.trim().isEmpty ||
        selectedTeamName == 'Команда не выбрана') {
      missing.add('Активная команда');
    }
    if (playersCount <= 0) missing.add('Игроки активной команды');
    if (eventsCount <= 0) missing.add('События клуба');

    final complete = missing.isEmpty;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(radius: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                complete ? Icons.verified_rounded : Icons.info_outline_rounded,
                color: _C.primaryGreen,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  complete
                      ? 'Профиль клуба заполнен'
                      : 'Что желательно заполнить',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _C.text,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            complete
                ? 'Основные данные клуба выглядят аккуратно. Можно переходить к работе с командой.'
                : 'Эти пункты помогут сделать экран клуба понятнее для тренеров, игроков и родителей.',
            style: const TextStyle(
              color: _C.muted,
              fontSize: 13,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: (complete ? ['Готово'] : missing).map((item) {
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: complete ? _C.primaryGreen.withOpacity(0.1) : _C.soft2,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color: complete
                        ? _C.primaryGreen.withOpacity(0.25)
                        : _C.border,
                  ),
                ),
                child: Text(
                  item,
                  style: TextStyle(
                    color: complete ? _C.primaryGreen : _C.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _TeamsPanel extends StatelessWidget {
  final List<Map<String, dynamic>> teams;
  final int? selectedTeamId;
  final ValueChanged<Map<String, dynamic>> onOpenTeam;
  final VoidCallback onCreateTeam;

  const _TeamsPanel(
      {required this.teams,
      required this.selectedTeamId,
      required this.onOpenTeam,
      required this.onCreateTeam});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      _TeamsHeader(onCreateTeam: onCreateTeam),
      const SizedBox(height: 12),
      Expanded(
        child: teams.isEmpty
            ? _EmptyTeams(onCreateTeam: onCreateTeam)
            : GridView.builder(
                padding: const EdgeInsets.only(bottom: 20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 1.35),
                itemCount: teams.length,
                itemBuilder: (_, index) {
                  final team = teams[index];
                  final id =
                      int.tryParse('${team['id'] ?? team['team_id'] ?? 0}') ??
                          0;
                  final name =
                      '${team['name'] ?? team['team_name'] ?? 'Команда'}';
                  final subtitle =
                      '${team['age_group'] ?? team['category'] ?? team['sport'] ?? 'Футбол'}';
                  final logo =
                      '${team['logo'] ?? team['logo_url'] ?? team['photo'] ?? ''}';
                  return _TeamCard(
                      name: name,
                      subtitle: subtitle,
                      logo: logo.isEmpty ? null : logo,
                      active: id == selectedTeamId,
                      onTap: () => onOpenTeam(team));
                },
              ),
      ),
    ]);
  }
}

class _TeamsHeader extends StatelessWidget {
  final VoidCallback onCreateTeam;
  const _TeamsHeader({required this.onCreateTeam});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(radius: 28),
      child: Row(children: [
        const _IconBadge(icon: Icons.account_tree_rounded, size: 54),
        const SizedBox(width: 10),
        const Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Команды клуба',
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w600, color: _C.text)),
          SizedBox(height: 4),
          Text(
              'Создавайте команды, выбирайте активную и переходите к рабочим модулям.',
              style: TextStyle(color: _C.muted, fontWeight: FontWeight.w600)),
        ])),
        _GreenButton(
            icon: Icons.add_rounded,
            text: 'Добавить команду',
            onTap: onCreateTeam,
            large: true),
      ]),
    );
  }
}

class _TeamCard extends StatelessWidget {
  final String name;
  final String subtitle;
  final String? logo;
  final bool active;
  final VoidCallback onTap;

  const _TeamCard(
      {required this.name,
      required this.subtitle,
      required this.logo,
      required this.active,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: active ? _C.blueSoft : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: active ? _C.blue.withOpacity(.28) : _C.border,
              width: active ? 1.4 : 1),
          boxShadow: [
            BoxShadow(
                color: active
                    ? _C.blue.withOpacity(.12)
                    : Colors.black.withOpacity(.035),
                blurRadius: 22,
                offset: const Offset(0, 12))
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _LogoBox(
                url: logo, size: 58, bgColor: active ? Colors.white : _C.soft),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                  color: active ? Colors.white : _C.soft2,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                      color: active ? _C.blue.withOpacity(.18) : _C.border)),
              child: Text(active ? 'Активна' : 'Открыть',
                  style: TextStyle(
                      color: active ? _C.blue : _C.black,
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ),
          ]),
          const Spacer(),
          Text(name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 19,
                  height: 1.1,
                  fontWeight: FontWeight.w600,
                  color: active ? _C.blue : _C.text)),
          const SizedBox(height: 7),
          Text(subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: _C.muted, fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

class _RosterPanel extends StatelessWidget {
  final String teamName;
  final int? selectedTeamId;
  final int clubId;
  final List<Map<String, dynamic>> players;
  final bool loading;
  final Map<String, dynamic>? selectedPlayer;
  final Future<void> Function()? onRefresh;
  final ValueChanged<Map<String, dynamic>> onOpenPlayer;
  final ValueChanged<Map<String, dynamic>> onOpenFullPlayer;
  final VoidCallback onOpenFullRoster;
  final VoidCallback onAddPlayer;

  const _RosterPanel({
    required this.teamName,
    required this.selectedTeamId,
    required this.clubId,
    required this.players,
    required this.loading,
    required this.selectedPlayer,
    required this.onRefresh,
    required this.onOpenPlayer,
    required this.onOpenFullPlayer,
    required this.onOpenFullRoster,
    required this.onAddPlayer,
  });

  String _playerIdentity(Map<String, dynamic>? player) {
    if (player == null) return '';

    const idKeys = [
      'id',
      'player_id',
      'playerId',
      'user_id',
      'userId',
      'member_id',
      'memberId',
    ];

    for (final key in idKeys) {
      final value = '${player[key] ?? ''}'.trim();
      if (value.isNotEmpty && value != 'null' && value != '0') {
        return '$key:$value';
      }
    }

    final first = '${player['first_name'] ?? player['firstname'] ?? ''}'.trim();
    final last = '${player['last_name'] ?? player['lastname'] ?? ''}'.trim();
    final full =
        '${player['fullName'] ?? player['full_name'] ?? player['name'] ?? ''}'
            .trim();
    final birth =
        '${player['birth_date'] ?? player['birthDate'] ?? player['birthday'] ?? ''}'
            .trim();

    final fallback = [first, last, full, birth]
        .where((value) => value.isNotEmpty && value != 'null')
        .join('|');

    return fallback.isEmpty ? '' : 'fallback:$fallback';
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: CircularProgressIndicator(color: _C.primaryGreen),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 900;
        final listWidth = math.min(430.0, constraints.maxWidth * .42);

        final rosterList = Container(
          padding: const EdgeInsets.all(18),
          decoration: _cardDecoration(radius: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: const Icon(
                      Icons.groups_2_rounded,
                      color: _C.black,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Состав команды',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _C.text,
                            fontSize: 16,
                            height: 1.05,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$teamName · ${players.length} игроков',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _C.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _HelpCircle(
                    title: 'Как работать с составом',
                    text:
                        'Состав — рабочая зона тренера. Здесь удобно быстро открыть карточку игрока, проверить данные и перейти в полный профиль.',
                    steps: const [
                      'Нажмите на игрока в списке, чтобы открыть подробности справа.',
                      'Добавляйте игроков через кнопку с плюсом — они будут привязаны к выбранной команде.',
                      'Используйте полный состав, когда нужно работать с большим списком и расширенными действиями.',
                    ],
                    icon: Icons.tips_and_updates_rounded,
                    size: 38,
                  ),
                  const SizedBox(width: 8),
                  _RosterHeaderAction(
                    icon: Icons.person_add_alt_1_rounded,
                    tooltip: 'Добавить игрока',
                    onTap: onAddPlayer,
                  ),
                  const SizedBox(width: 8),
                  _RosterHeaderAction(
                    icon: Icons.open_in_full_rounded,
                    tooltip: 'Открыть полный состав',
                    onTap: onOpenFullRoster,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _RosterAdviceCard(
                icon: Icons.lightbulb_outline_rounded,
                title: 'Совет тренеру',
                text:
                    'Заполните амплуа, номер, рост и вес — карточки состава станут информативнее и удобнее для анализа.',
              ),
              const SizedBox(height: 14),
              Expanded(
                child: players.isEmpty
                    ? const Center(
                        child: _EmptyText('Игроки пока не найдены.'),
                      )
                    : RefreshIndicator(
                        color: _C.primaryGreen,
                        onRefresh: onRefresh ?? () async {},
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: players.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, index) {
                            final player = players[index];
                            final playerKey = _playerIdentity(player);
                            final selectedKey = _playerIdentity(selectedPlayer);
                            final active = selectedPlayer != null &&
                                playerKey.isNotEmpty &&
                                playerKey == selectedKey;

                            return _PlayerTile(
                              player: player,
                              active: active,
                              index: index,
                              onTap: () => onOpenPlayer(player),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        );

        final details = _PlayerPanel(
          player: selectedPlayer,
          teamName: teamName,
          onBack: null,
          onOpenFull: selectedPlayer == null
              ? null
              : () => onOpenFullPlayer(selectedPlayer!),
        );

        if (compact) {
          return Column(
            children: [
              SizedBox(height: 460, child: rosterList),
              const SizedBox(height: 12),
              Expanded(child: details),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: listWidth, child: rosterList),
            const SizedBox(width: 12),
            Expanded(child: details),
          ],
        );
      },
    );
  }
}

class _RosterHeaderAction extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _RosterHeaderAction({
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
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _C.border),
            boxShadow: const [
              BoxShadow(
                  color: Color(0x08000000),
                  blurRadius: 10,
                  offset: Offset(0, 4)),
            ],
          ),
          child: Icon(icon, color: _C.black, size: 20),
        ),
      ),
    );
  }
}

class _RosterAdviceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _RosterAdviceCard({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF2D98A)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x08000000), blurRadius: 14, offset: Offset(0, 6)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: const Color(0xFF92400E), size: 19),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _C.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  text,
                  style: const TextStyle(
                    color: _C.muted,
                    fontSize: 12.5,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayerTile extends StatelessWidget {
  final Map<String, dynamic> player;
  final bool active;
  final int index;
  final VoidCallback onTap;

  const _PlayerTile({
    required this.player,
    required this.active,
    required this.index,
    required this.onTap,
  });

  String _field(List<String> keys, [String fallback = '']) {
    for (final key in keys) {
      final value = '${player[key] ?? ''}'.trim();
      if (value.isNotEmpty && value != 'null') return value;
    }
    return fallback;
  }

  String _photoUrl(String raw) => _normalizeSportotekaMediaUrl(raw);

  @override
  Widget build(BuildContext context) {
    final first = _field(const ['first_name', 'firstname']);
    final last = _field(const ['last_name', 'lastname']);
    final name = ('$first $last').trim().isEmpty
        ? _field(const ['fullName', 'full_name', 'name'], 'Игрок')
        : ('$first $last').trim();
    final position = _field(const ['position', 'role'], 'Амплуа');
    final rawPhoto =
        _field(const ['photo_url', 'avatar_url', 'photo', 'avatar', 'image']);
    final photo = _photoUrl(rawPhoto);
    final number = _field(
      const ['number', 'player_number', 'shirt_number'],
      '${index + 1}',
    );
    final height = _field(const ['height']);
    final weight = _field(const ['weight']);
    final metrics = <String>[
      if (height.isNotEmpty) '$height см',
      if (weight.isNotEmpty) '$weight кг',
    ].join(' · ');

    final badgeBg = active ? _C.primaryGreen : _C.bg;
    final borderColor =
        active ? _C.primaryGreen.withOpacity(.34) : Colors.transparent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: active ? _C.greenSoft : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: borderColor, width: active ? 1.2 : 1),
            boxShadow: [
              BoxShadow(
                color: active
                    ? _C.primaryGreen.withOpacity(.10)
                    : Colors.black.withOpacity(.025),
                blurRadius: active ? 18 : 12,
                offset: Offset(0, active ? 8 : 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _TrainerAvatar(photo: photo, name: name, size: 50),
                  Positioned(
                    right: -3,
                    bottom: -3,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: badgeBg,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          number,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: active ? Colors.white : _C.muted,
                            fontSize: number.length > 2 ? 8 : 9.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _C.text,
                        fontSize: 14.5,
                        height: 1.05,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _RosterInfoPill(
                          text: position,
                          color: _C.graphite,
                          bg: const Color(0xFFF7F7F8),
                        ),
                        _RosterInfoPill(
                          text: metrics.isEmpty ? 'Данные игрока' : metrics,
                          color: _C.graphite,
                          bg: const Color(0xFFF1F5F9),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: active ? _C.primaryGreen : _C.bg,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: active ? _C.primaryGreen : _C.border,
                  ),
                ),
                child: Icon(
                  active ? Icons.check_rounded : Icons.chevron_right_rounded,
                  color: active ? Colors.white : _C.muted,
                  size: active ? 17 : 19,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RosterInfoPill extends StatelessWidget {
  final String text;
  final Color color;
  final Color bg;

  const _RosterInfoPill({
    required this.text,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: _C.border.withOpacity(.75)),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PlayerPanel extends StatelessWidget {
  final Map<String, dynamic>? player;
  final String teamName;
  final VoidCallback? onBack;
  final VoidCallback? onOpenFull;

  const _PlayerPanel({
    required this.player,
    required this.teamName,
    required this.onBack,
    required this.onOpenFull,
  });

  String _text(String key, [String fallback = '—']) {
    final value = player?[key];
    final text = '${value ?? ''}'.trim();
    return text.isEmpty || text == 'null' ? fallback : text;
  }

  String _firstNonEmpty(List<String> keys, [String fallback = '—']) {
    for (final key in keys) {
      final value = _text(key, '');
      if (value.isNotEmpty) return value;
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    if (player == null) {
      return const _SolidPlaceholder(
        icon: Icons.person_search_rounded,
        title: 'Выберите игрока',
        subtitle: 'Нажмите на игрока в составе, чтобы открыть его карточку.',
        chips: ['Профиль', 'Метрики', 'Медкарта'],
      );
    }

    final first = _text('first_name', '');
    final last = _text('last_name', '');
    final fullName =
        _firstNonEmpty(const ['fullName', 'full_name'], '$first $last').trim();
    final name = fullName.isEmpty ? _text('name', 'Игрок') : fullName;
    final photo = _firstNonEmpty(const ['photo', 'avatar', 'image'], '');
    final position =
        _firstNonEmpty(const ['position', 'role'], 'Амплуа не указано');
    final number =
        _firstNonEmpty(const ['number', 'player_number', 'shirt_number']);
    final birth = _firstNonEmpty(const ['birthDate', 'birth_date', 'birthday']);
    final email = _text('email');
    final nationality =
        _firstNonEmpty(const ['nationality', 'citizenship', 'nationa']);
    final height = _text('height');
    final weight = _text('weight');
    final sportData = _firstNonEmpty(const ['sport_data', 'sportData'], '');

    return Container(
      decoration: _cardDecoration(radius: 30),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Row(
              children: [
                if (onBack != null) ...[
                  _RosterHeaderAction(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'Назад',
                    onTap: onBack!,
                  ),
                  const SizedBox(width: 12),
                ],
                _LogoBox(
                  url: photo.isEmpty ? null : photo,
                  size: 88,
                  bgColor: _C.bg,
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _C.text,
                          fontSize: 25,
                          height: 1.06,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _RosterInfoPill(
                              text: position,
                              color: _C.graphite,
                              bg: const Color(0xFFF7F7F8)),
                          _RosterInfoPill(
                              text: '№ $number',
                              color: _C.graphite,
                              bg: const Color(0xFFF1F5F9)),
                          _RosterInfoPill(
                              text: teamName, color: _C.graphite, bg: _C.bg),
                        ],
                      ),
                    ],
                  ),
                ),
                if (onOpenFull != null) ...[
                  const SizedBox(width: 12),
                  _RosterFullProfileButton(onTap: onOpenFull!),
                ],
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _RosterMetricCard(
                        title: 'Дата рождения',
                        value: birth,
                        icon: Icons.cake_rounded,
                        bg: _C.orangeSoft,
                        iconColor: _C.orange,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _RosterMetricCard(
                        title: 'Амплуа',
                        value: position,
                        icon: Icons.sports_soccer_rounded,
                        bg: const Color(0xFFEAF7EE),
                        iconColor: const Color(0xFF166534),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _RosterMetricCard(
                        title: 'Номер',
                        value: number,
                        icon: Icons.tag_rounded,
                        bg: const Color(0xFFF1F5F9),
                        iconColor: _C.graphite,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _RosterMetricCard(
                        title: 'Рост',
                        value: height,
                        icon: Icons.height_rounded,
                        bg: const Color(0xFFF1F5F9),
                        iconColor: _C.graphite,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _RosterMetricCard(
                        title: 'Вес',
                        value: weight,
                        icon: Icons.monitor_weight_outlined,
                        bg: const Color(0xFFF1F5F9),
                        iconColor: _C.graphite,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _RosterMetricCard(
                        title: 'Гражданство',
                        value: nationality,
                        icon: Icons.flag_rounded,
                        bg: const Color(0xFFFFFBEB),
                        iconColor: const Color(0xFF92400E),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _SolidCard(
                  title: 'Контакты',
                  helpText:
                      'Контактные данные нужны для связи с игроком или родителем. Если email пустой — проверьте карточку игрока.',
                  helpSteps: const [
                    'Откройте полный профиль игрока.',
                    'Проверьте email и дополнительные контакты.',
                    'После правки вернитесь в состав и обновите список.',
                  ],
                  child: _ProfileLine(
                    icon: Icons.email_outlined,
                    title: 'Email',
                    value: email,
                  ),
                ),
                const SizedBox(height: 12),
                _SolidCard(
                  title: 'Спортивные данные',
                  helpText:
                      'Этот блок можно использовать для краткой характеристики игрока: ведущая нога, сильные стороны, текущие показатели и заметки тренера.',
                  helpSteps: const [
                    'Заполните ключевые спортивные данные в профиле игрока.',
                    'Не перегружайте текст — оставьте только полезное для тренера.',
                    'Для подробной аналитики используйте отдельные метрики и дневник тренировок.',
                  ],
                  child: Text(
                    sportData.isEmpty
                        ? 'Спортивные данные пока не заполнены.'
                        : sportData,
                    style: const TextStyle(
                      color: _C.text,
                      fontSize: 14,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RosterFullProfileButton extends StatelessWidget {
  final VoidCallback onTap;

  const _RosterFullProfileButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _C.primaryGreen,
                _C.greenDark,
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Colors.white.withOpacity(0.55),
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: _C.primaryGreen.withOpacity(0.22),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.account_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'Полный профиль',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  letterSpacing: -0.1,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(width: 7),
              Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _RosterMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color bg;
  final Color iconColor;

  const _RosterMetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.bg,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: iconColor.withOpacity(.12)),
                ),
                child: Icon(icon, color: iconColor, size: 14),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _C.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _C.text,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrainingsPanel extends StatelessWidget {
  final bool hasTeam;
  final VoidCallback onOpenPlans;
  final VoidCallback onOpenGraphics;
  final VoidCallback onOpenCalendar;
  final VoidCallback onOpenFullTeam;

  const _TrainingsPanel(
      {required this.hasTeam,
      required this.onOpenPlans,
      required this.onOpenGraphics,
      required this.onOpenCalendar,
      required this.onOpenFullTeam});

  @override
  Widget build(BuildContext context) {
    if (!hasTeam) return const _NeedTeam();
    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.1,
      children: [
        _ModuleCard(
            icon: Icons.folder_copy_rounded,
            title: 'Планы-конспекты',
            subtitle: 'Папки, программы, вложения',
            onTap: onOpenPlans),
        _ModuleCard(
            icon: Icons.draw_rounded,
            title: 'Графический редактор',
            subtitle: 'Схемы и упражнения',
            onTap: onOpenGraphics),
        _ModuleCard(
            icon: Icons.calendar_month_rounded,
            title: 'Календарь тренировок',
            subtitle: 'Расписание и события',
            onTap: onOpenCalendar),
        _ModuleCard(
            icon: Icons.assignment_turned_in_rounded,
            title: 'Посещаемость и оценка',
            subtitle: 'Журнал и рейтинг тренировки',
            onTap: onOpenFullTeam),
      ],
    );
  }
}

class _MobileMoreBottomSheet extends StatelessWidget {
  final String clubName;
  final String? clubLogo;
  final String selectedTeamName;
  final bool trainerMode;
  final bool hasTeam;
  final ClubSection currentSection;
  final List<_NavGroup> groups;
  final bool hasActiveSubscription;
  final VoidCallback onSportotekaOs;
  final VoidCallback onWorkspace;
  final ValueChanged<ClubSection> onSelect;

  const _MobileMoreBottomSheet({
    required this.clubName,
    required this.clubLogo,
    required this.selectedTeamName,
    required this.trainerMode,
    required this.hasTeam,
    required this.currentSection,
    required this.groups,
    required this.hasActiveSubscription,
    required this.onSportotekaOs,
    required this.onWorkspace,
    required this.onSelect,
  });

  bool _sectionIsActive(ClubSection itemSection) {
    if (itemSection == currentSection) return true;

    if (itemSection == ClubSection.roster &&
        currentSection == ClubSection.playerProfile) {
      return true;
    }

    if (itemSection == ClubSection.trainers &&
        currentSection == ClubSection.teamTrainers) {
      return true;
    }

    if (itemSection == ClubSection.teams &&
        currentSection == ClubSection.teamDashboard) {
      return true;
    }

    return false;
  }

  bool _needsTeam(ClubSection section) {
    return section == ClubSection.roster ||
        section == ClubSection.matches ||
        section == ClubSection.calendar ||
        section == ClubSection.plans ||
        section == ClubSection.videoAnalysis ||
        section == ClubSection.attendance ||
        section == ClubSection.testing ||
        section == ClubSection.medical ||
        section == ClubSection.graphics ||
        section == ClubSection.description ||
        section == ClubSection.challenges ||
        section == ClubSection.challengeCreate ||
        section == ClubSection.quizzes ||
        section == ClubSection.quizCreate ||
        section == ClubSection.rating ||
        section == ClubSection.manager ||
        section == ClubSection.miniGames;
  }

  String get _safeClubName {
    final value = clubName.trim();
    return value.isEmpty ? 'SPORTOTEKA' : value;
  }

  String get _contextLine {
    final team = selectedTeamName.trim();

    if (trainerMode) {
      if (hasTeam && team.isNotEmpty && team != 'Команда не выбрана') {
        return 'Вы вошли как тренер · $team';
      }
      return 'Вы вошли как тренер';
    }

    return 'Вы вошли как клуб';
  }

  String get _roleLabel => trainerMode ? 'ТРЕНЕР' : 'КЛУБ';

  TextStyle _titleStyle({
    required bool active,
  }) {
    return AppTypography.menuTitle(
      color: active ? const Color(0xFF067A46) : const Color(0xFF111827),
    );
  }

  TextStyle _subtitleStyle({
    required bool active,
    required bool disabled,
  }) {
    return AppTypography.menuSubtitle(
      color: disabled
          ? const Color(0xFF98A2B3)
          : active
              ? const Color(0xFF667085)
              : const Color(0xFF667085),
    );
  }

  Widget _workspaceTile() {
    const accent = Color(0xFF067A46);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onSportotekaOs,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(
            minHeight: 50,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 9,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFF3FAF6),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF8F0),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.folder_open_rounded,
                  size: 18,
                  color: accent,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Спортотека OS',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.menuTitle(
                        color: accent,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'файлы, окна и рабочее пространство клуба',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.menuSubtitle(
                        color: const Color(0xFF667085),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: Color(0xFF98A2B3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _backToWorkspaceTile() {
    const textColor = Color(0xFF344054);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: onWorkspace,
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 50),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F9F8),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.dashboard_customize_rounded,
                  size: 18,
                  color: textColor,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'К выбору Workspace',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.menuTitle(color: textColor),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'сменить рабочее пространство',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.menuSubtitle(
                        color: const Color(0xFF667085),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.arrow_outward_rounded,
                size: 17,
                color: Color(0xFF98A2B3),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _moduleTile(_NavItem item) {
    final active = _sectionIsActive(item.section);
    final needsTeam = _needsTeam(item.section) && !hasTeam;
    final locked = item.pro && !hasActiveSubscription;

    final opacity = needsTeam ? .48 : 1.0;
    final accent = active ? const Color(0xFF067A46) : const Color(0xFF344054);

    return Opacity(
      opacity: opacity,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(15),
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: () {
            if (needsTeam) {
              Get.snackbar(
                'Команда',
                'Сначала выберите активную команду',
              );
              return;
            }
            onSelect(item.section);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 170),
            width: double.infinity,
            constraints: const BoxConstraints(
              minHeight: 50,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 9,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: active ? const Color(0xFFF3FAF6) : Colors.transparent,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: active
                        ? const Color(0xFFEAF8F0)
                        : const Color(0xFFF7F9F8),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    item.icon,
                    size: 18,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              item.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _titleStyle(
                                active: active,
                              ),
                            ),
                          ),
                          if (item.pro) ...<Widget>[
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: locked
                                    ? const Color(0xFFFFF7ED)
                                    : const Color(0xFFECFDF3),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'PRO',
                                style: AppTypography.badge(
                                  color: locked
                                      ? const Color(
                                          0xFFEA580C,
                                        )
                                      : const Color(
                                          0xFF00A750,
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        needsTeam ? 'Сначала выберите команду' : item.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _subtitleStyle(
                          active: active,
                          disabled: needsTeam,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: Color(0xFF98A2B3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        9,
        5,
        9,
        5,
      ),
      child: Text(
        title.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.menuGroup(
          color: const Color(0xFF98A2B3),
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        4,
        2,
        4,
        10,
      ),
      child: Row(
        children: <Widget>[
          _LogoBox(
            url: clubLogo,
            size: 40,
            bgColor: const Color(0xFFF7F9F8),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _safeClubName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.custom(
                    size: 12.6,
                    weight: FontWeight.w600,
                    color: const Color(0xFF111827),
                    height: 1.15,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _contextLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.custom(
                    size: 9.8,
                    weight: FontWeight.w400,
                    color: const Color(0xFF667085),
                    height: 1.15,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF3),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              _roleLabel,
              style: AppTypography.custom(
                size: 8.6,
                weight: FontWeight.w600,
                color: const Color(0xFF00A750),
                height: 1,
                letterSpacing: .15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    final bottom = MediaQuery.of(context).padding.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: height * .88,
      ),
      margin: const EdgeInsets.fromLTRB(
        10,
        0,
        10,
        10,
      ),
      padding: EdgeInsets.fromLTRB(
        14,
        10,
        14,
        14 + bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withOpacity(.16),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 42,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFD0D5DD),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 12),
          _header(),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Меню',
                  style: AppTypography.custom(
                    size: 13.2,
                    weight: FontWeight.w600,
                    color: const Color(0xFF111827),
                    height: 1.1,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: const BouncingScrollPhysics(),
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(
                    bottom: 10,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _sectionTitle('Навигация'),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: _workspaceTile(),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: _backToWorkspaceTile(),
                      ),
                    ],
                  ),
                ),
                for (final group in groups)
                  Padding(
                    padding: const EdgeInsets.only(
                      bottom: 10,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _sectionTitle(group.title),
                        ...group.items.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: 3,
                            ),
                            child: _moduleTile(item),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrainersModuleContent extends StatefulWidget {
  final List<Map<String, dynamic>> trainers;
  final int teamsCount;
  final int playersCount;
  final String selectedTeamName;
  final bool proActive;
  final VoidCallback onOpenTrainers;
  final VoidCallback onOpenTeams;
  final VoidCallback onOpenRoster;

  const _TrainersModuleContent({
    required this.trainers,
    required this.teamsCount,
    required this.playersCount,
    required this.selectedTeamName,
    required this.proActive,
    required this.onOpenTrainers,
    required this.onOpenTeams,
    required this.onOpenRoster,
  });

  @override
  State<_TrainersModuleContent> createState() => _TrainersModuleContentState();
}

class _TrainersModuleContentState extends State<_TrainersModuleContent> {
  int selectedIndex = 0;

  String _s(dynamic value) {
    final text = '${value ?? ''}'.trim();
    return text == 'null' ? '' : text;
  }

  int _i(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? 0}') ?? 0;
  }

  String _trainerName(Map<String, dynamic> trainer) {
    final full = _s(trainer['full_name']).isNotEmpty
        ? _s(trainer['full_name'])
        : _s(trainer['fullName']).isNotEmpty
            ? _s(trainer['fullName'])
            : _s(trainer['name']).isNotEmpty
                ? _s(trainer['name'])
                : '${_s(trainer['first_name'])} ${_s(trainer['last_name'])}'
                    .trim();
    return full.isEmpty ? 'Тренер' : full;
  }

  String _trainerRole(Map<String, dynamic> trainer) {
    final raw = (_s(trainer['role']).isNotEmpty
            ? _s(trainer['role'])
            : _s(trainer['position']).isNotEmpty
                ? _s(trainer['position'])
                : _s(trainer['specialization']))
        .trim();
    if (raw.isEmpty) return 'Тренер';
    final lower = raw.toLowerCase();
    if (lower == 'coach' || lower == 'trainer') return 'Тренер';
    if (lower == 'head coach') return 'Главный тренер';
    if (lower == 'assistant coach') return 'Ассистент тренера';
    if (lower == 'manager') return 'Менеджер';
    if (lower == 'admin' || lower == 'administrator') return 'Администратор';
    return raw;
  }

  String _trainerTeam(Map<String, dynamic> trainer) {
    final teamName = _s(trainer['team_name'] ?? trainer['teamName']);
    if (teamName.isNotEmpty) return teamName;
    final teamId = _i(trainer['team_id'] ?? trainer['teamId']);
    if (teamId > 0) return 'Команда #$teamId';
    return 'Команда не назначена';
  }

  String _trainerPhone(Map<String, dynamic> trainer) =>
      _s(trainer['phone'] ?? trainer['phone_number'] ?? trainer['mobile']);

  String _trainerEmail(Map<String, dynamic> trainer) => _s(trainer['email']);

  String _trainerPhoto(Map<String, dynamic> trainer) {
    return _firstSportotekaMediaUrl(trainer, const [
      'photo_url',
      'avatar_url',
      'photo',
      'avatar',
      'image',
      'logo',
      'logo_url',
    ]);
  }

  bool _hasActiveTeam() {
    return widget.selectedTeamName.trim().isNotEmpty &&
        widget.selectedTeamName != 'Команда не выбрана';
  }

  int _assignedCount() {
    return widget.trainers.where((trainer) {
      final teamId = _i(trainer['team_id'] ?? trainer['teamId']);
      final teamName = _s(trainer['team_name'] ?? trainer['teamName']);
      return teamId > 0 || teamName.isNotEmpty;
    }).length;
  }

  @override
  void didUpdateWidget(covariant _TrainersModuleContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (selectedIndex >= widget.trainers.length) selectedIndex = 0;
  }

  @override
  Widget build(BuildContext context) {
    final trainers = widget.trainers;
    final selectedTrainer = trainers.isEmpty
        ? null
        : trainers[selectedIndex.clamp(0, trainers.length - 1)];

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 900;
        final listWidth = math.min(430.0, constraints.maxWidth * .42);

        final trainersList = Container(
          padding: const EdgeInsets.all(18),
          decoration: _cardDecoration(radius: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: const Icon(
                      Icons.badge_rounded,
                      color: _C.black,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Тренеры клуба',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _C.text,
                            fontSize: 16,
                            height: 1.05,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${widget.selectedTeamName} · ${trainers.length} тренеров',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _C.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const _HelpCircle(
                    title: 'Как работать с тренерами',
                    text:
                        'Тренеры — рабочая зона управления специалистами клуба. Здесь удобно выбрать тренера, проверить роль, команду и контакты.',
                    steps: [
                      'Нажмите на тренера в списке, чтобы открыть подробности справа.',
                      'Проверяйте привязку к команде, роль, телефон и email в карточке справа.',
                      'Используйте кнопку редактирования, чтобы перейти к управлению тренерами клуба.',
                    ],
                    icon: Icons.tips_and_updates_rounded,
                    size: 38,
                  ),
                  const SizedBox(width: 8),
                  _RosterHeaderAction(
                    icon: Icons.manage_accounts_rounded,
                    tooltip: 'Управление тренерами',
                    onTap: widget.onOpenTrainers,
                  ),
                  const SizedBox(width: 8),
                  _RosterHeaderAction(
                    icon: Icons.groups_2_rounded,
                    tooltip: 'Открыть состав',
                    onTap: widget.onOpenRoster,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _RosterAdviceCard(
                icon: Icons.lightbulb_outline_rounded,
                title: 'Совет по штабу',
                text:
                    'Заполните роль, контакты и команду тренера — так в рабочем окне сразу видно, кто за что отвечает.',
              ),
              const SizedBox(height: 14),
              Expanded(
                child: trainers.isEmpty
                    ? Center(
                        child: _TrainerEmptyInline(
                            onOpenTrainers: widget.onOpenTrainers),
                      )
                    : RefreshIndicator(
                        color: _C.primaryGreen,
                        onRefresh: () async {},
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          itemCount: trainers.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, index) {
                            final trainer = trainers[index];
                            return _TrainerWorkTile(
                              trainer: trainer,
                              active: index == selectedIndex,
                              index: index,
                              name: _trainerName(trainer),
                              role: _trainerRole(trainer),
                              team: _trainerTeam(trainer),
                              photo: _trainerPhoto(trainer),
                              onTap: () =>
                                  setState(() => selectedIndex = index),
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        );

        final details = _TrainerPanelCard(
          trainer: selectedTrainer,
          trainerName: _trainerName,
          trainerRole: _trainerRole,
          trainerTeam: _trainerTeam,
          trainerPhone: _trainerPhone,
          trainerEmail: _trainerEmail,
          trainerPhoto: _trainerPhoto,
          onEdit: widget.onOpenTrainers,
          onOpenRoster: widget.onOpenRoster,
        );

        if (compact) {
          return Column(
            children: [
              SizedBox(height: 460, child: trainersList),
              const SizedBox(height: 12),
              Expanded(child: details),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: listWidth, child: trainersList),
            const SizedBox(width: 12),
            Expanded(child: details),
          ],
        );
      },
    );
  }
}

class _TrainerWorkTile extends StatelessWidget {
  final Map<String, dynamic> trainer;
  final bool active;
  final int index;
  final String name;
  final String role;
  final String team;
  final String photo;
  final VoidCallback onTap;

  const _TrainerWorkTile({
    required this.trainer,
    required this.active,
    required this.index,
    required this.name,
    required this.role,
    required this.team,
    required this.photo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final initialsBg = active ? _C.primaryGreen : _C.bg;
    final borderColor =
        active ? _C.primaryGreen.withOpacity(.34) : Colors.transparent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: active ? _C.greenSoft : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: borderColor, width: active ? 1.2 : 1),
            boxShadow: [
              BoxShadow(
                color: active
                    ? _C.primaryGreen.withOpacity(.10)
                    : Colors.black.withOpacity(.025),
                blurRadius: active ? 18 : 12,
                offset: Offset(0, active ? 8 : 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _TrainerAvatar(photo: photo, name: name, size: 50),
                  Positioned(
                    right: -3,
                    bottom: -3,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: initialsBg,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: active ? Colors.white : _C.muted,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _C.text,
                        fontSize: 14.5,
                        height: 1.05,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _RosterInfoPill(
                          text: role,
                          color: _C.graphite,
                          bg: const Color(0xFFF7F7F8),
                        ),
                        _RosterInfoPill(
                          text: team,
                          color: _C.graphite,
                          bg: const Color(0xFFF1F5F9),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: active ? _C.primaryGreen : _C.bg,
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: active ? _C.primaryGreen : _C.border),
                ),
                child: Icon(
                  active ? Icons.check_rounded : Icons.chevron_right_rounded,
                  color: active ? Colors.white : _C.muted,
                  size: active ? 17 : 19,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrainerPanelCard extends StatelessWidget {
  final Map<String, dynamic>? trainer;
  final String Function(Map<String, dynamic>) trainerName;
  final String Function(Map<String, dynamic>) trainerRole;
  final String Function(Map<String, dynamic>) trainerTeam;
  final String Function(Map<String, dynamic>) trainerPhone;
  final String Function(Map<String, dynamic>) trainerEmail;
  final String Function(Map<String, dynamic>) trainerPhoto;
  final VoidCallback onEdit;
  final VoidCallback onOpenRoster;

  const _TrainerPanelCard({
    required this.trainer,
    required this.trainerName,
    required this.trainerRole,
    required this.trainerTeam,
    required this.trainerPhone,
    required this.trainerEmail,
    required this.trainerPhoto,
    required this.onEdit,
    required this.onOpenRoster,
  });

  @override
  Widget build(BuildContext context) {
    if (trainer == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: _cardDecoration(radius: 30),
        child: const Center(
          child: _EmptyText('Выберите тренера слева.'),
        ),
      );
    }

    final t = trainer!;
    final name = trainerName(t);
    final role = trainerRole(t);
    final team = trainerTeam(t);
    final phone = trainerPhone(t);
    final email = trainerEmail(t);
    final photo = trainerPhoto(t);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(radius: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TrainerAvatar(photo: photo, name: name, size: 86),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _C.text,
                        fontSize: 22,
                        height: 1.05,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        _RosterInfoPill(
                          text: role,
                          color: _C.graphite,
                          bg: const Color(0xFFF7F7F8),
                        ),
                        _RosterInfoPill(
                          text: team,
                          color: _C.graphite,
                          bg: const Color(0xFFF1F5F9),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _HelpCircle(
                title: 'Карточка тренера',
                text:
                    'Здесь отображается краткая информация по выбранному специалисту: роль, команда и контакты.',
                steps: const [
                  'Проверьте, назначен ли тренер к нужной команде.',
                  'Заполните телефон и email, чтобы быстро связаться со специалистом.',
                  'Через редактирование можно обновить данные тренера.',
                ],
                icon: Icons.info_outline_rounded,
                size: 38,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _RosterMetricCard(
                  icon: Icons.badge_rounded,
                  title: 'Роль',
                  value: role,
                  bg: const Color(0xFFF7F7F8),
                  iconColor: _C.graphite,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _RosterMetricCard(
                  icon: Icons.groups_2_rounded,
                  title: 'Команда',
                  value: team,
                  bg: const Color(0xFFF1F5F9),
                  iconColor: _C.graphite,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _TrainerContactTile(
            kind: _TrainerGlyphKind.phone,
            title: 'Телефон',
            value: phone.isEmpty ? 'Не указан' : phone,
          ),
          const SizedBox(height: 8),
          _TrainerContactTile(
            kind: _TrainerGlyphKind.mail,
            title: 'Email',
            value: email.isEmpty ? 'Не указан' : email,
          ),
          const SizedBox(height: 14),
          _RosterAdviceCard(
            icon: Icons.assignment_turned_in_rounded,
            title: 'Подсказка',
            text:
                'Для рабочего процесса лучше назначать каждому тренеру конкретную команду и роль: главный тренер, ассистент, тренер вратарей или администратор.',
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: _TrainerPanelButton(
                  icon: Icons.manage_accounts_rounded,
                  title: 'Редактировать',
                  onTap: onEdit,
                  filled: true,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TrainerPanelButton(
                  icon: Icons.groups_2_rounded,
                  title: 'Состав',
                  onTap: onOpenRoster,
                  filled: false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrainerPanelButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool filled;

  const _TrainerPanelButton({
    required this.icon,
    required this.title,
    required this.onTap,
    required this.filled,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: filled ? _C.primaryGreen : _C.bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: filled ? _C.primaryGreen : _C.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: filled ? Colors.white : _C.text, size: 19),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: filled ? Colors.white : _C.text,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrainerEmptyInline extends StatelessWidget {
  final VoidCallback onOpenTrainers;
  const _TrainerEmptyInline({required this.onOpenTrainers});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.badge_rounded, color: _C.black, size: 28),
        ),
        const SizedBox(height: 12),
        const Text(
          'Тренеры пока не добавлены',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: _C.text, fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        const Text(
          'Добавьте тренера или назначьте специалиста к команде.',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: _C.muted,
              fontSize: 12.5,
              height: 1.35,
              fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 14),
        _TrainerPanelButton(
          icon: Icons.manage_accounts_rounded,
          title: 'Управление тренерами',
          onTap: onOpenTrainers,
          filled: true,
        ),
      ],
    );
  }
}

class _TrainerTopStrip extends StatelessWidget {
  final int trainersCount;
  final int assignedCount;
  final String selectedTeamName;
  final bool hasActiveTeam;
  final bool proActive;
  final VoidCallback onEdit;

  const _TrainerTopStrip({
    required this.trainersCount,
    required this.assignedCount,
    required this.selectedTeamName,
    required this.hasActiveTeam,
    required this.proActive,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 680;
    final teamText = hasActiveTeam ? selectedTeamName : 'Команда не выбрана';

    return Container(
      padding:
          EdgeInsets.symmetric(horizontal: isMobile ? 14 : 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            _C.greenSoft.withOpacity(.30),
            _C.soft2.withOpacity(.72),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.022),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _TrainerSmallStat(
                        value: '$trainersCount', label: 'тренеров'),
                    const SizedBox(width: 8),
                    _TrainerSmallStat(
                        value: '$assignedCount', label: 'назначено'),
                    const Spacer(),
                    _ProStatusPill(active: proActive),
                    const SizedBox(width: 8),
                    const _HelpCircle(
                      title: 'Как работать с тренерами',
                      text:
                          'Раздел тренеров показывает специалистов клуба и помогает быстро открыть карточку тренера, проверить контакты и назначение к команде.',
                      steps: [
                        'Выберите тренера в списке слева или сверху на телефоне.',
                        'Справа откроется подробная карточка с фото, ролью, командой и контактами.',
                        'Нажмите «Редактировать», чтобы перейти к управлению тренерами клуба.',
                      ],
                      size: 32,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _TrainerTeamLine(teamText: teamText),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: _TrainerEditButton(onTap: onEdit),
                ),
              ],
            )
          : Row(
              children: [
                _TrainerSmallStat(value: '$trainersCount', label: 'тренеров'),
                const SizedBox(width: 8),
                _TrainerSmallStat(value: '$assignedCount', label: 'назначено'),
                const SizedBox(width: 12),
                Expanded(child: _TrainerTeamLine(teamText: teamText)),
                const SizedBox(width: 10),
                _ProStatusPill(active: proActive),
                const SizedBox(width: 8),
                const _HelpCircle(
                  title: 'Как работать с тренерами',
                  text:
                      'Раздел тренеров показывает специалистов клуба и помогает быстро открыть карточку тренера, проверить контакты и назначение к команде.',
                  steps: [
                    'Выберите тренера в списке слева.',
                    'Справа откроется подробная карточка с фото, ролью, командой и контактами.',
                    'Нажмите «Редактировать», чтобы перейти к управлению тренерами клуба.',
                  ],
                  size: 32,
                ),
                const SizedBox(width: 10),
                _TrainerEditButton(onTap: onEdit),
              ],
            ),
    );
  }
}

class _TrainerSmallStat extends StatelessWidget {
  final String value;
  final String label;
  const _TrainerSmallStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _C.greenSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: const TextStyle(
                  color: _C.primaryGreen,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(
                  color: _C.muted, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _TrainerTeamLine extends StatelessWidget {
  final String teamText;
  const _TrainerTeamLine({required this.teamText});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
              color: _C.primaryGreen, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            teamText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _C.text,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _TrainerEditButton extends StatelessWidget {
  final VoidCallback onTap;
  const _TrainerEditButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
        decoration: BoxDecoration(
          color: _C.primaryGreen,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _C.primaryGreen.withOpacity(.14),
              blurRadius: 14,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _TrainerGlyph(
                kind: _TrainerGlyphKind.clipboard,
                color: Colors.white,
                size: 18),
            SizedBox(width: 7),
            Text(
              'Редактировать',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrainerCompactList extends StatelessWidget {
  final List<Map<String, dynamic>> trainers;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final String Function(Map<String, dynamic>) trainerName;
  final String Function(Map<String, dynamic>) trainerRole;
  final String Function(Map<String, dynamic>) trainerTeam;
  final String Function(Map<String, dynamic>) trainerPhoto;
  final bool isMobile;

  const _TrainerCompactList({
    required this.trainers,
    required this.selectedIndex,
    required this.onSelect,
    required this.trainerName,
    required this.trainerRole,
    required this.trainerTeam,
    required this.trainerPhoto,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(radius: 26),
      padding: const EdgeInsets.all(10),
      child: Column(
        children: List.generate(trainers.length, (index) {
          final trainer = trainers[index];
          final selected = index == selectedIndex;
          return Padding(
            padding:
                EdgeInsets.only(bottom: index == trainers.length - 1 ? 0 : 8),
            child: _TrainerCompactRow(
              trainer: trainer,
              selected: selected,
              onTap: () => onSelect(index),
              name: trainerName(trainer),
              role: trainerRole(trainer),
              team: trainerTeam(trainer),
              photo: trainerPhoto(trainer),
              isMobile: isMobile,
            ),
          );
        }),
      ),
    );
  }
}

class _TrainerCompactRow extends StatelessWidget {
  final Map<String, dynamic> trainer;
  final bool selected;
  final VoidCallback onTap;
  final String name;
  final String role;
  final String team;
  final String photo;
  final bool isMobile;

  const _TrainerCompactRow({
    required this.trainer,
    required this.selected,
    required this.onTap,
    required this.name,
    required this.role,
    required this.team,
    required this.photo,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.all(isMobile ? 10 : 12),
        decoration: BoxDecoration(
          color: selected ? _C.greenSoft : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected
                  ? _C.primaryGreen.withOpacity(.22)
                  : Colors.transparent),
        ),
        child: Row(
          children: [
            _TrainerAvatar(photo: photo, name: name, size: isMobile ? 42 : 46),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _C.text,
                      fontSize: isMobile ? 13.2 : 14.2,
                      height: 1.05,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 6,
                    runSpacing: 5,
                    children: [
                      _TrainerMicroChip(text: role, color: _C.primaryGreen),
                      _TrainerMicroChip(text: team, color: _C.blue),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            _TrainerSelectionMark(selected: selected),
          ],
        ),
      ),
    );
  }
}

class _TrainerDetailWorkCard extends StatelessWidget {
  final Map<String, dynamic> trainer;
  final String Function(Map<String, dynamic>) trainerName;
  final String Function(Map<String, dynamic>) trainerRole;
  final String Function(Map<String, dynamic>) trainerTeam;
  final String Function(Map<String, dynamic>) trainerPhone;
  final String Function(Map<String, dynamic>) trainerEmail;
  final String Function(Map<String, dynamic>) trainerPhoto;
  final VoidCallback onEdit;
  final bool compact;

  const _TrainerDetailWorkCard({
    required this.trainer,
    required this.trainerName,
    required this.trainerRole,
    required this.trainerTeam,
    required this.trainerPhone,
    required this.trainerEmail,
    required this.trainerPhoto,
    required this.onEdit,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final name = trainerName(trainer);
    final role = trainerRole(trainer);
    final team = trainerTeam(trainer);
    final phone = trainerPhone(trainer);
    final email = trainerEmail(trainer);
    final photo = trainerPhoto(trainer);

    return Container(
      padding: EdgeInsets.all(compact ? 16 : 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            _C.greenSoft.withOpacity(.32),
            _C.soft2.withOpacity(.70),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.022),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TrainerAvatar(photo: photo, name: name, size: compact ? 70 : 84),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _C.text,
                        fontSize: compact ? 17 : 19,
                        height: 1.05,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        _TrainerMicroChip(text: role, color: _C.primaryGreen),
                        _TrainerMicroChip(text: team, color: _C.blue),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _TrainerContactTile(
            kind: _TrainerGlyphKind.phone,
            title: 'Телефон',
            value: phone.isEmpty ? 'Не указан' : phone,
          ),
          const SizedBox(height: 8),
          _TrainerContactTile(
            kind: _TrainerGlyphKind.mail,
            title: 'Email',
            value: email.isEmpty ? 'Не указан' : email,
          ),
          const SizedBox(height: 8),
          _TrainerContactTile(
            kind: _TrainerGlyphKind.team,
            title: 'Команда',
            value: team,
          ),
          const SizedBox(height: 14),
          SizedBox(
              width: double.infinity, child: _TrainerEditButton(onTap: onEdit)),
        ],
      ),
    );
  }
}

class _SafeNetworkMedia extends StatelessWidget {
  final String url;
  final BoxFit fit;
  final Widget fallback;

  const _SafeNetworkMedia({
    required this.url,
    required this.fit,
    required this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final safeUrl = _normalizeSportotekaMediaUrl(url);
    final uri = Uri.tryParse(safeUrl);
    final isValid = safeUrl.startsWith('data:image/') ||
        (safeUrl.isNotEmpty &&
            uri != null &&
            (uri.scheme == 'https' || uri.scheme == 'http') &&
            uri.host.isNotEmpty);

    if (!isValid) return fallback;

    return Image.network(
      safeUrl,
      fit: fit,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => fallback,
    );
  }
}

class _TrainerAvatar extends StatelessWidget {
  final String photo;
  final String name;
  final double size;
  const _TrainerAvatar(
      {required this.photo, required this.name, required this.size});

  String get _initials {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return 'Т';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return '${parts.first.characters.first}${parts.last.characters.first}'
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final normalizedUrl = _normalizeSportotekaMediaUrl(photo);
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _C.greenSoft,
        borderRadius: BorderRadius.circular(size * .36),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.026),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: _SafeNetworkMedia(
        url: normalizedUrl,
        fit: BoxFit.cover,
        fallback: _InitialsBadge(initials: _initials),
      ),
    );
  }
}

class _InitialsBadge extends StatelessWidget {
  final String initials;
  const _InitialsBadge({required this.initials});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initials,
        style: const TextStyle(
          color: _C.primaryGreen,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TrainerMicroChip extends StatelessWidget {
  final String text;
  final Color color;
  const _TrainerMicroChip({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 180),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: _C.softFor(color),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          height: 1.05,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

enum _TrainerGlyphKind {
  staff,
  whistle,
  clipboard,
  phone,
  mail,
  team,
  check,
  arrow
}

class _TrainerGlyphBadge extends StatelessWidget {
  final _TrainerGlyphKind kind;
  final double size;
  const _TrainerGlyphBadge({required this.kind, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _C.greenSoft,
        borderRadius: BorderRadius.circular(size * .34),
        border: Border.all(color: _C.primaryGreen.withOpacity(.10)),
      ),
      child: Center(
        child:
            _TrainerGlyph(kind: kind, color: _C.primaryGreen, size: size * .48),
      ),
    );
  }
}

class _TrainerSelectionMark extends StatelessWidget {
  final bool selected;
  const _TrainerSelectionMark({required this.selected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: selected ? 24 : 22,
      height: selected ? 24 : 22,
      decoration: BoxDecoration(
        color: selected ? _C.primaryGreen : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: selected ? _C.primaryGreen : _C.border),
      ),
      child: Center(
        child: _TrainerGlyph(
          kind: selected ? _TrainerGlyphKind.check : _TrainerGlyphKind.arrow,
          color: selected ? Colors.white : _C.muted,
          size: selected ? 14 : 13,
        ),
      ),
    );
  }
}

class _TrainerGlyph extends StatelessWidget {
  final _TrainerGlyphKind kind;
  final Color color;
  final double size;
  const _TrainerGlyph(
      {required this.kind, required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _TrainerGlyphPainter(kind: kind, color: color),
      ),
    );
  }
}

class _TrainerGlyphPainter extends CustomPainter {
  final _TrainerGlyphKind kind;
  final Color color;
  const _TrainerGlyphPainter({required this.kind, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = (w * .105).clamp(1.4, 2.4)
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    switch (kind) {
      case _TrainerGlyphKind.staff:
        canvas.drawCircle(Offset(w * .36, h * .30), w * .13, p);
        canvas.drawCircle(Offset(w * .64, h * .30), w * .13, p);
        canvas.drawArc(Rect.fromLTWH(w * .15, h * .48, w * .42, h * .34),
            math.pi, math.pi, false, p);
        canvas.drawArc(Rect.fromLTWH(w * .43, h * .48, w * .42, h * .34),
            math.pi, math.pi, false, p);
        canvas.drawLine(Offset(w * .50, h * .16), Offset(w * .50, h * .86),
            p..strokeWidth = (w * .07).clamp(1.2, 2.0));
        break;
      case _TrainerGlyphKind.whistle:
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(w * .18, h * .34, w * .54, h * .36),
                Radius.circular(w * .16)),
            p);
        canvas.drawCircle(Offset(w * .42, h * .52), w * .07, p);
        canvas.drawPath(
            Path()
              ..moveTo(w * .72, h * .42)
              ..lineTo(w * .92, h * .34)
              ..lineTo(w * .82, h * .54),
            p);
        break;
      case _TrainerGlyphKind.clipboard:
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(w * .22, h * .16, w * .56, h * .70),
                Radius.circular(w * .10)),
            p);
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(w * .36, h * .10, w * .28, h * .16),
                Radius.circular(w * .06)),
            p);
        canvas.drawLine(Offset(w * .36, h * .42), Offset(w * .64, h * .42), p);
        canvas.drawLine(Offset(w * .36, h * .58), Offset(w * .60, h * .58), p);
        break;
      case _TrainerGlyphKind.phone:
        canvas.drawPath(
            Path()
              ..moveTo(w * .30, h * .18)
              ..cubicTo(w * .20, h * .26, w * .24, h * .48, w * .42, h * .66)
              ..cubicTo(w * .58, h * .82, w * .78, h * .84, w * .86, h * .72),
            p);
        canvas.drawLine(Offset(w * .30, h * .18), Offset(w * .42, h * .30), p);
        canvas.drawLine(Offset(w * .70, h * .62), Offset(w * .86, h * .72), p);
        break;
      case _TrainerGlyphKind.mail:
        final r = Rect.fromLTWH(w * .14, h * .24, w * .72, h * .52);
        canvas.drawRRect(
            RRect.fromRectAndRadius(r, Radius.circular(w * .09)), p);
        canvas.drawPath(
            Path()
              ..moveTo(w * .18, h * .30)
              ..lineTo(w * .50, h * .55)
              ..lineTo(w * .82, h * .30),
            p);
        break;
      case _TrainerGlyphKind.team:
        canvas.drawCircle(Offset(w * .34, h * .34), w * .11, p);
        canvas.drawCircle(Offset(w * .66, h * .34), w * .11, p);
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromLTWH(w * .18, h * .56, w * .64, h * .24),
                Radius.circular(w * .12)),
            p);
        break;
      case _TrainerGlyphKind.check:
        canvas.drawPath(
            Path()
              ..moveTo(w * .24, h * .52)
              ..lineTo(w * .43, h * .70)
              ..lineTo(w * .78, h * .30),
            p);
        break;
      case _TrainerGlyphKind.arrow:
        canvas.drawPath(
            Path()
              ..moveTo(w * .36, h * .22)
              ..lineTo(w * .64, h * .50)
              ..lineTo(w * .36, h * .78),
            p);
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _TrainerGlyphPainter oldDelegate) {
    return oldDelegate.kind != kind || oldDelegate.color != color;
  }
}

class _TrainerContactTile extends StatelessWidget {
  final _TrainerGlyphKind kind;
  final String title;
  final String value;
  const _TrainerContactTile(
      {required this.kind, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _C.bg,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          _TrainerGlyph(kind: kind, color: _C.primaryGreen, size: 18),
          const SizedBox(width: 9),
          SizedBox(
            width: 72,
            child: Text(
              title,
              style: const TextStyle(
                  color: _C.muted, fontSize: 11.5, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: _C.text, fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrainerEmptyWorkarea extends StatelessWidget {
  final VoidCallback onOpenTrainers;
  const _TrainerEmptyWorkarea({required this.onOpenTrainers});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: _cardDecoration(radius: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _TrainerGlyphBadge(kind: _TrainerGlyphKind.staff, size: 62),
          const SizedBox(height: 12),
          const Text(
            'Тренеры пока не добавлены',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: _C.text, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          const Text(
            'Добавьте тренера или назначьте специалиста к команде.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: _C.muted,
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          _TrainerEditButton(onTap: onOpenTrainers),
        ],
      ),
    );
  }
}

class _TrainerMobileSummaryCard extends StatelessWidget {
  final bool proActive;
  final int percent;
  final String selectedTeamName;
  final bool hasActiveTeam;
  final int trainersCount;
  final int assignedCount;
  final int infoPercent;
  final String adminName;
  final VoidCallback onOpenTrainers;

  const _TrainerMobileSummaryCard({
    required this.proActive,
    required this.percent,
    required this.selectedTeamName,
    required this.hasActiveTeam,
    required this.trainersCount,
    required this.assignedCount,
    required this.infoPercent,
    required this.adminName,
    required this.onOpenTrainers,
  });

  @override
  Widget build(BuildContext context) {
    final teamText = hasActiveTeam ? selectedTeamName : 'Команда не выбрана';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: _C.blueSoft,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _C.border),
                ),
                child: const Icon(
                  Icons.supervisor_account_rounded,
                  color: _C.blue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Тренеры клуба',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _C.text,
                    fontSize: 16,
                    height: 1.05,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _ProStatusPill(active: proActive),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Команда: $teamText',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _C.muted,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _MobileTrainerNumber(value: '$trainersCount', label: 'тренеров'),
              const SizedBox(width: 8),
              _MobileTrainerNumber(value: '$assignedCount', label: 'назначено'),
              const SizedBox(width: 8),
              _MobileTrainerNumber(value: '$infoPercent%', label: 'данные'),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$percent%',
                style: const TextStyle(
                  color: _C.text,
                  fontSize: 28,
                  height: 1,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: 3),
                  child: Text(
                    'заполненность раздела',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _C.muted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: percent.clamp(0, 100) / 100,
              minHeight: 8,
              backgroundColor: _C.soft,
              color: _C.primaryGreen,
            ),
          ),
          if (adminName.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Ответственный: $adminName',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _C.text,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MobileTrainerNumber extends StatelessWidget {
  final String value;
  final String label;

  const _MobileTrainerNumber({
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
        decoration: BoxDecoration(
          color: _C.soft2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _C.border),
        ),
        child: Column(
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _C.text,
                fontSize: 16,
                height: 1,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _C.muted,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrainerHeroPanel extends StatelessWidget {
  final bool isMobile;
  final bool proActive;
  final int percent;
  final String selectedTeamName;
  final bool hasActiveTeam;
  final int trainersCount;
  final int assignedCount;
  final int infoPercent;
  final String adminName;

  const _TrainerHeroPanel({
    required this.isMobile,
    required this.proActive,
    required this.percent,
    required this.selectedTeamName,
    required this.hasActiveTeam,
    required this.trainersCount,
    required this.assignedCount,
    required this.infoPercent,
    required this.adminName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: _C.black,
        borderRadius: BorderRadius.circular(isMobile ? 24 : 30),
        boxShadow: [
          BoxShadow(
            color: _C.black.withOpacity(.16),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: isMobile ? 50 : 60,
                height: isMobile ? 50 : 60,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(.14)),
                ),
                child: const Icon(Icons.supervisor_account_rounded,
                    color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Тренерский штаб',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              height: 1.05,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        _ProStatusPill(active: proActive, dark: true),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      hasActiveTeam
                          ? 'Активная команда: $selectedTeamName. Раздел показывает назначения, заполненность профилей и готовность тренерского блока.'
                          : 'Выберите активную команду, чтобы управлять назначениями и видеть точную заполненность.',
                      maxLines: isMobile ? 4 : 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(.72),
                        fontSize: isMobile ? 12 : 13,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$percent%',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isMobile ? 34 : 42,
                  height: 1,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    'готовность раздела',
                    style: TextStyle(
                      color: Colors.white.withOpacity(.68),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: percent.clamp(0, 100) / 100,
              minHeight: 9,
              backgroundColor: Colors.white.withOpacity(.12),
              color: _C.primaryGreen,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _TrainerDarkChip(text: '$trainersCount тренеров'),
              _TrainerDarkChip(text: '$assignedCount назначено'),
              _TrainerDarkChip(text: 'информация $infoPercent%'),
              if (adminName.isNotEmpty)
                _TrainerDarkChip(text: 'ответственный: $adminName'),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrainerStatusPanel extends StatelessWidget {
  final bool isMobile;
  final int percent;
  final List<String> missing;
  final int trainersCount;
  final int assignedCount;
  final int filledProfiles;
  final int infoPercent;
  final VoidCallback onOpenTrainers;

  const _TrainerStatusPanel({
    required this.isMobile,
    required this.percent,
    required this.missing,
    required this.trainersCount,
    required this.assignedCount,
    required this.filledProfiles,
    required this.infoPercent,
    required this.onOpenTrainers,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 15 : 18),
      decoration: _cardDecoration(radius: isMobile ? 22 : 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.fact_check_rounded, color: _C.primaryGreen, size: 21),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Заполненность данных тренеров',
                  style: TextStyle(
                    color: _C.text,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _TrainerChecklistRow(
              title: 'Тренеры добавлены', done: trainersCount > 0),
          _TrainerChecklistRow(
              title: 'Есть назначения к командам', done: assignedCount > 0),
          _TrainerChecklistRow(
              title: 'Профили заполнены', done: filledProfiles > 0),
          _TrainerChecklistRow(
              title: 'Контакты, роли и фото заполнены',
              done: infoPercent >= 70),
          const SizedBox(height: 12),
          if (missing.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  missing.map((item) => _TrainerHintChip(text: item)).toList(),
            )
          else
            const Text(
              'Раздел выглядит хорошо: тренеры добавлены, назначения и основные данные заполнены.',
              style: TextStyle(
                color: _C.muted,
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}

class _TrainerListPreview extends StatelessWidget {
  final List<Map<String, dynamic>> trainers;
  final bool isMobile;
  final String Function(Map<String, dynamic>) trainerName;
  final String Function(Map<String, dynamic>) trainerRole;
  final int Function(Map<String, dynamic>) fillPercent;

  const _TrainerListPreview({
    required this.trainers,
    required this.isMobile,
    required this.trainerName,
    required this.trainerRole,
    required this.fillPercent,
  });

  String _s(dynamic value) {
    final text = '${value ?? ''}'.trim();
    return text == 'null' ? '' : text;
  }

  @override
  Widget build(BuildContext context) {
    final visible = trainers.take(isMobile ? 3 : 4).toList();
    return Container(
      padding: EdgeInsets.all(isMobile ? 15 : 18),
      decoration: _cardDecoration(radius: isMobile ? 22 : 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Краткая информация по тренерам',
            style: TextStyle(
              color: _C.text,
              fontSize: 15.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ...visible.map((trainer) {
            final name =
                trainerName(trainer).isEmpty ? 'Тренер' : trainerName(trainer);
            final role = trainerRole(trainer).isEmpty
                ? 'Роль не указана'
                : trainerRole(trainer);
            final team = _s(trainer['team_name'] ?? trainer['teamName']);
            final percent = fillPercent(trainer);

            return Container(
              margin: const EdgeInsets.only(bottom: 9),
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: _C.soft2,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _C.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _C.blueSoft,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _C.border),
                    ),
                    child: const Icon(Icons.person_rounded,
                        color: _C.blue, size: 21),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _C.text,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          team.isEmpty ? role : '$role • $team',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _C.muted,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _TrainerPercentBadge(percent: percent),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _TrainerDarkChip extends StatelessWidget {
  final String text;
  const _TrainerDarkChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.1),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white.withOpacity(.12)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TrainerChecklistRow extends StatelessWidget {
  final String title;
  final bool done;

  const _TrainerChecklistRow({required this.title, required this.done});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          Icon(
            done
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: done ? _C.primaryGreen : _C.muted,
            size: 18,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: done ? _C.text : _C.muted,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrainerPercentBadge extends StatelessWidget {
  final int percent;

  const _TrainerPercentBadge({required this.percent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: _C.primaryGreen.withOpacity(.1),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: _C.primaryGreen.withOpacity(.22)),
      ),
      child: Text(
        '$percent%',
        style: const TextStyle(
          color: _C.primaryGreen,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TrainerMiniMetric extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _TrainerMiniMetric({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.025),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: _C.blue, size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _C.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _C.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrainerHintChip extends StatelessWidget {
  final String text;

  const _TrainerHintChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _C.soft2,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: _C.border),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: _C.text,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _TrainerActionButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;

  const _TrainerActionButton({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: _C.soft2,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _C.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: _C.blue, size: 19),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _C.text,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProCornerBadge extends StatelessWidget {
  final bool active;

  const _ProCornerBadge({required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: active ? _C.primaryGreen : Colors.black87,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(.85), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.10),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!active) ...[
            const Icon(Icons.lock_rounded, size: 8, color: Colors.white),
            const SizedBox(width: 2),
          ],
          const Text(
            'PRO',
            style: TextStyle(
              color: Colors.white,
              fontSize: 7.5,
              fontWeight: FontWeight.w600,
              height: 1,
              letterSpacing: .15,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProStatusPill extends StatelessWidget {
  final bool active;
  final bool dark;

  const _ProStatusPill({required this.active, this.dark = false});

  @override
  Widget build(BuildContext context) {
    // Такой же компактный бейдж, как в старом меню:
    // активная подписка — просто PRO, нет доступа — замок + PRO.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.10),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!active) ...[
            const Icon(
              Icons.lock_rounded,
              size: 11,
              color: Colors.white,
            ),
            const SizedBox(width: 4),
          ],
          const Text(
            'PRO',
            style: TextStyle(
              color: Colors.white,
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              letterSpacing: .2,
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamModulePanel extends StatelessWidget {
  final bool hasTeam;
  final String title;
  final String subtitle;
  final IconData icon;
  final String primaryText;
  final VoidCallback onPrimary;
  final Widget? customContent;
  final List<_ModuleQuickAction> quickActions;
  final bool proActive;
  final bool showFullModuleCard;

  const _TeamModulePanel(
      {required this.hasTeam,
      required this.title,
      required this.subtitle,
      required this.icon,
      required this.primaryText,
      required this.onPrimary,
      this.customContent,
      this.quickActions = const [],
      this.proActive = false,
      this.showFullModuleCard = true});

  @override
  Widget build(BuildContext context) {
    if (!hasTeam) return const _NeedTeam();

    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 700;
    final columns = isMobile ? 2 : (width < 1180 ? 2 : 3);
    final headerPadding = isMobile ? 16.0 : 20.0;
    final iconSize = isMobile ? 52.0 : 60.0;
    final titleSize = isMobile ? 16.2 : 18.2;
    final subtitleSize = isMobile ? 11.4 : 12.2;

    final internalCards = <_ModuleQuickAction>[
      ...quickActions,
      if (showFullModuleCard)
        _ModuleQuickAction(
            'Полный модуль', Icons.open_in_new_rounded, onPrimary),
    ];

    return ListView(
      padding: EdgeInsets.only(right: isMobile ? 0 : 2, bottom: 24),
      children: [
        Container(
          padding: EdgeInsets.all(headerPadding),
          decoration: _cardDecoration(radius: isMobile ? 24 : 30),
          child: isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _IconBadge(icon: icon, size: iconSize, iconSize: 27),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: isMobile ? 2 : 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: titleSize,
                                  height: 1.05,
                                  fontWeight: FontWeight.w600,
                                  color: _C.text,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                subtitle,
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _C.muted,
                                  height: 1.25,
                                  fontSize: subtitleSize,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _ProStatusPill(active: proActive),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: _GreenButton(
                        icon: Icons.open_in_new_rounded,
                        text: primaryText,
                        onTap: onPrimary,
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    _IconBadge(icon: icon, size: iconSize, iconSize: 31),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: titleSize,
                              height: 1.05,
                              fontWeight: FontWeight.w600,
                              color: _C.text,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _C.muted,
                              height: 1.28,
                              fontSize: subtitleSize,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _ProStatusPill(active: proActive),
                    const SizedBox(width: 10),
                    Flexible(
                      flex: 0,
                      child: _GreenButton(
                        icon: Icons.open_in_new_rounded,
                        text: primaryText,
                        onTap: onPrimary,
                        large: width > 1120,
                      ),
                    ),
                  ],
                ),
        ),
        if (customContent != null) ...[
          const SizedBox(height: 12),
          customContent!,
        ],
        if (internalCards.isNotEmpty) ...[
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: isMobile ? 1.55 : 2.25,
            ),
            itemCount: internalCards.length,
            itemBuilder: (_, index) {
              final action = internalCards[index];
              return _ModuleCard(
                icon: action.icon,
                title: action.text,
                subtitle: index == internalCards.length - 1
                    ? 'Открыть рабочий экран'
                    : 'Быстрое действие',
                onTap: action.onTap,
              );
            },
          ),
        ],
      ],
    );
  }
}

class _ModuleQuickAction {
  final String text;
  final IconData icon;
  final VoidCallback onTap;
  const _ModuleQuickAction(this.text, this.icon, this.onTap);
}

class _TeamGuard extends StatelessWidget {
  final bool hasTeam;
  final Widget child;
  const _TeamGuard({required this.hasTeam, required this.child});
  @override
  Widget build(BuildContext context) => hasTeam ? child : const _NeedTeam();
}

class _NeedTeam extends StatelessWidget {
  const _NeedTeam();
  @override
  Widget build(BuildContext context) => const _SolidPlaceholder(
      icon: Icons.info_rounded,
      title: 'Сначала выберите команду',
      subtitle:
          'Откройте раздел «Команды клуба» и выберите команду для работы.',
      chips: ['Команды', 'Состав', 'Матчи']);
}

class _SolidPlaceholder extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<String> chips;
  const _SolidPlaceholder(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.chips});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 650),
        padding: const EdgeInsets.all(28),
        decoration: _cardDecoration(radius: 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _IconBadge(icon: icon, size: 76, iconSize: 38),
          const SizedBox(height: 16),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 24, fontWeight: FontWeight.w600, color: _C.text)),
          const SizedBox(height: 8),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _C.muted, height: 1.45)),
          const SizedBox(height: 18),
          Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: chips.map((e) => _LightChip(text: e)).toList()),
        ]),
      ),
    );
  }
}

class _SolidCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  final String? helpText;
  final List<String> helpSteps;
  const _SolidCard({
    required this.title,
    required this.child,
    this.trailing,
    this.helpText,
    this.helpSteps = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(radius: 28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _C.text))),
          if (helpText != null) ...[
            const SizedBox(width: 8),
            _HelpCircle(
              title: title,
              text: helpText!,
              steps: helpSteps,
              size: 32,
            ),
          ],
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ]),
        const SizedBox(height: 14),
        child,
      ]),
    );
  }
}

class _ClubHeroCard extends StatelessWidget {
  final String clubName;
  final String? clubLogo;
  final String clubDescription;

  const _ClubHeroCard({
    required this.clubName,
    required this.clubLogo,
    required this.clubDescription,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final compact = width < 1120;
    final description = clubDescription.trim().isEmpty
        ? 'Единый рабочий кабинет клуба: команды, составы, тренеры, события и аналитика.'
        : clubDescription.trim();

    return Container(
      padding: EdgeInsets.all(compact ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            _C.greenSoft.withOpacity(.34),
            _C.soft2.withOpacity(.76),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.022),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LogoBox(
              url: clubLogo, size: compact ? 58 : 70, bgColor: Colors.white),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  clubName,
                  maxLines: compact ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _C.text,
                    fontSize: compact ? 18 : 21,
                    height: 1.06,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  maxLines: compact ? 3 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _C.muted,
                    fontSize: compact ? 12.2 : 13.2,
                    height: 1.36,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  final String value;
  final String title;
  final Color color;
  const _HeroStat(
      {required this.value, required this.title, this.color = _C.primaryGreen});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
          color: _C.softFor(color),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(.16))),
      child: Column(children: [
        Text(value,
            style: TextStyle(
                color: color, fontSize: 22, fontWeight: FontWeight.w600)),
        const SizedBox(height: 1),
        Text(title,
            style: const TextStyle(
                color: _C.muted, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;
  const _MetricCard(
      {required this.icon,
      required this.title,
      required this.value,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: _cardDecoration(radius: 22),
        child: Row(
          children: [
            _IconBadge(icon: icon, size: 38, iconSize: 20),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _C.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w600,
                  color: _C.accentForIcon(icon),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ModuleCard(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = _C.accentForIcon(icon);
    final width = MediaQuery.of(context).size.width;
    final mobile = width < 700;
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(mobile ? 13 : 16),
        decoration: _cardDecoration(radius: 24),
        child: Row(
          children: [
            _IconBadge(
                icon: icon, size: mobile ? 40 : 46, iconSize: mobile ? 20 : 23),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: mobile ? 12.2 : 14.2,
                      height: 1.08,
                      fontWeight: FontWeight.w600,
                      color: _C.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: mobile ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _C.muted,
                      fontSize: mobile ? 10.4 : 11.2,
                      height: 1.15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded,
                color: accent, size: mobile ? 20 : 24),
          ],
        ),
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback? onTap;
  const _ActionPill({required this.icon, required this.text, this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = _C.accentForIcon(icon);
    return InkWell(
      borderRadius: BorderRadius.circular(99),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 210),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: _C.softFor(accent),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: accent.withOpacity(.14)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: accent, size: 17),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w600,
                  fontSize: 11.8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GreenButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  final bool large;
  const _GreenButton(
      {required this.icon,
      required this.text,
      required this.onTap,
      this.large = false});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        padding: EdgeInsets.symmetric(
          horizontal: large ? 18 : 13,
          vertical: large ? 14 : 11,
        ),
        decoration: BoxDecoration(
          color: _C.primaryGreen,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: _C.primaryGreen.withOpacity(.22),
              blurRadius: 18,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: large ? 21 : 18),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: large ? 12.2 : 11.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WhiteButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  const _WhiteButton(
      {required this.icon, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(18)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: _C.black, size: 19),
          const SizedBox(width: 8),
          Text(text,
              style: const TextStyle(
                  color: _C.black, fontWeight: FontWeight.w600, fontSize: 13)),
        ]),
      ),
    );
  }
}

class _IconCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconCircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
              color: _C.soft2,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _C.border)),
          child: Icon(icon, color: _C.primaryGreen)),
    );
  }
}

class _SmallIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _SmallIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
              color: _C.soft2,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _C.border)),
          child: Icon(icon, color: _C.primaryGreen, size: 20)),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String title;
  final String value;
  final IconData? icon;
  const _MiniStat({required this.title, required this.value, this.icon});

  @override
  Widget build(BuildContext context) {
    final accent = icon == null ? _C.primaryGreen : _C.accentForIcon(icon!);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: _C.softFor(accent),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent.withOpacity(.12))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (icon != null) Icon(icon, color: accent, size: 15),
          if (icon != null) const SizedBox(width: 6),
          Expanded(
              child: Text(title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: _C.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)))
        ]),
        const SizedBox(height: 5),
        Text(value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style:
                const TextStyle(color: _C.text, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _DarkChip extends StatelessWidget {
  final String text;
  const _DarkChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(.12),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: Colors.white.withOpacity(.06))),
      child: Text(text,
          style: const TextStyle(
              color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class _LightChip extends StatelessWidget {
  final String text;
  const _LightChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
          color: Colors.white.withOpacity(.86),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: _C.border)),
      child: Text(text,
          style: const TextStyle(color: _C.black, fontWeight: FontWeight.w600)),
    );
  }
}

class _EventRow extends StatelessWidget {
  final String title;
  final String date;
  const _EventRow({required this.title, required this.date});

  @override
  Widget build(BuildContext context) {
    const accent = _C.teal;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: _C.tealSoft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withOpacity(.16))),
      child: Row(children: [
        Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(.9),
                borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.event_available_rounded,
                color: accent, size: 18)),
        const SizedBox(width: 10),
        Expanded(
            child: Text(title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, color: _C.text))),
        const SizedBox(width: 10),
        Text(date,
            style: const TextStyle(
                color: _C.muted, fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _EmptyText extends StatelessWidget {
  final String text;
  const _EmptyText(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      textAlign: TextAlign.center,
      style: const TextStyle(color: _C.muted, height: 1.4));
}

class _EmptyTeams extends StatelessWidget {
  final VoidCallback onCreateTeam;
  const _EmptyTeams({required this.onCreateTeam});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: _SolidPlaceholder(
        icon: Icons.account_tree_rounded,
        title: 'Команды ещё не добавлены',
        subtitle:
            'Создайте первую команду клуба, чтобы открыть состав, матчи и тренировочный процесс.',
        chips: const ['Команда', 'Состав', 'Матчи'],
      ),
    );
  }
}

class _LargeActionButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _LargeActionButton(
      {required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: _cardDecoration(radius: 24),
        child: Row(children: [
          _IconBadge(icon: icon, size: 50, iconSize: 28),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: _C.text)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: _C.muted)),
              ])),
          Icon(Icons.chevron_right_rounded, color: _C.accentForIcon(icon)),
        ]),
      ),
    );
  }
}

class _LogoBox extends StatelessWidget {
  final String? url;
  final double size;
  final Color? bgColor;
  const _LogoBox({required this.url, required this.size, this.bgColor});

  @override
  Widget build(BuildContext context) {
    final normalizedUrl = _normalizeSportotekaMediaUrl(url);
    final fallback = Icon(
      Icons.shield_rounded,
      color: _C.primaryGreen,
      size: size * .48,
    );

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: bgColor ?? _C.soft,
        borderRadius: BorderRadius.circular(size * .34),
        border: Border.all(color: Colors.black.withOpacity(.045)),
      ),
      child: _SafeNetworkMedia(
        url: normalizedUrl,
        fit: BoxFit.cover,
        fallback: fallback,
      ),
    );
  }
}

class _RotateTabletHint extends StatelessWidget {
  final String clubName;
  final String? clubLogo;
  const _RotateTabletHint({required this.clubName, required this.clubLogo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      body: Center(
        child: Container(
          width: 520,
          padding: const EdgeInsets.all(30),
          decoration: _cardDecoration(radius: 34),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _LogoBox(url: clubLogo, size: 78, bgColor: _C.soft),
            const SizedBox(height: 20),
            Text(clubName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w600, color: _C.text)),
            const SizedBox(height: 8),
            const Text(
                'Для полноценного рабочий кабинет-кабинета поверните планшет горизонтально.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _C.muted, height: 1.45)),
            const SizedBox(height: 22),
            const Icon(Icons.screen_rotation_alt_rounded,
                color: _C.primaryGreen, size: 58),
          ]),
        ),
      ),
    );
  }
}

class _ProfileLine extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  const _ProfileLine(
      {required this.icon, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, color: _C.accentForIcon(icon), size: 22),
      const SizedBox(width: 12),
      Text('$title:',
          style: const TextStyle(color: _C.muted, fontWeight: FontWeight.w600)),
      const SizedBox(width: 8),
      Expanded(
          child: Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: _C.text, fontWeight: FontWeight.w600))),
    ]);
  }
}

class _HelpCircle extends StatelessWidget {
  final String title;
  final String text;
  final List<String> steps;
  final IconData icon;
  final double size;

  const _HelpCircle({
    required this.title,
    required this.text,
    this.steps = const [],
    this.icon = Icons.help_outline_rounded,
    this.size = 34,
  });

  void _open(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 620),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(.10),
                    blurRadius: 30,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: _C.greenSoft,
                          borderRadius: BorderRadius.circular(17),
                        ),
                        child: Icon(icon, color: _C.primaryGreen, size: 23),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _C.text,
                            fontSize: 16,
                            height: 1.08,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded, color: _C.muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    text,
                    style: const TextStyle(
                      color: _C.muted,
                      fontSize: 13.5,
                      height: 1.42,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (steps.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    ...List.generate(steps.length, (index) {
                      return Padding(
                        padding: EdgeInsets.only(
                            bottom: index == steps.length - 1 ? 0 : 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                color: _C.greenSoft,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: _C.primaryGreen,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                steps[index],
                                style: const TextStyle(
                                  color: _C.text,
                                  fontSize: 13,
                                  height: 1.35,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Помощь',
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: () => _open(context),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.92),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.035),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Icon(icon, color: _C.primaryGreen, size: size * .55),
        ),
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  final IconData icon;
  final double size;
  final double iconSize;
  final Color? color;
  const _IconBadge(
      {required this.icon, this.size = 58, this.iconSize = 30, this.color});

  @override
  Widget build(BuildContext context) {
    final accent = color ?? _C.accentForIcon(icon);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
          color: _C.softFor(accent),
          borderRadius: BorderRadius.circular(size * .34),
          border: Border.all(color: accent.withOpacity(.08)),
          boxShadow: [
            BoxShadow(
              color: accent.withOpacity(.055),
              blurRadius: size * .22,
              offset: Offset(0, size * .07),
            ),
          ]),
      child: Icon(icon, color: accent, size: iconSize),
    );
  }
}

BoxDecoration _cardDecoration({double radius = 28}) {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: _C.border),
    boxShadow: const [
      BoxShadow(
        color: Color(0x0F000000),
        blurRadius: 22,
        offset: Offset(0, 10),
      ),
    ],
  );
}

class _ClubChatPanel extends StatelessWidget {
  final int userId;
  final VoidCallback onOpenFullChat;

  const _ClubChatPanel({
    required this.userId,
    required this.onOpenFullChat,
  });

  @override
  Widget build(BuildContext context) {
    if (userId <= 0) {
      return const _SolidPlaceholder(
        icon: Icons.forum_rounded,
        title: 'Чаты недоступны',
        subtitle: 'Не удалось определить пользователя для загрузки чатов.',
        chips: ['Личные', 'Группы', 'Команда'],
      );
    }

    return Container(
      decoration: _cardDecoration(radius: 30),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
            decoration: const BoxDecoration(
              color: _C.purpleSoft,
            ),
            child: Row(
              children: [
                const _IconBadge(
                  icon: Icons.forum_rounded,
                  size: 48,
                  iconSize: 24,
                  color: _C.purple,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Чаты клуба',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _C.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Личные диалоги, группы и командное общение внутри рабочий кабинет',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _C.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                _SmallIconButton(
                  icon: Icons.open_in_new_rounded,
                  onTap: onOpenFullChat,
                ),
              ],
            ),
          ),
          Expanded(
            child: ClipRect(
              child: ChatScreen(
                userId: userId,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClubIntroSplash extends StatelessWidget {
  final Animation<double> animation;
  const _ClubIntroSplash({required this.animation});

  @override
  Widget build(BuildContext context) {
    final ballValue = CurvedAnimation(
      parent: animation,
      curve: const Interval(0, .42, curve: Curves.easeOutBack),
    ).value;
    final titleValue = CurvedAnimation(
      parent: animation,
      curve: const Interval(.12, .52, curve: Curves.easeOutCubic),
    ).value;
    final progressValue = CurvedAnimation(
      parent: animation,
      curve: const Interval(.10, .76, curve: Curves.easeOutCubic),
    ).value;
    final fadeOut = CurvedAnimation(
      parent: animation,
      curve: const Interval(.76, 1, curve: Curves.easeInOut),
    ).value;

    return IgnorePointer(
      child: Opacity(
        opacity: 1 - fadeOut,
        child: Container(
          color: _C.bg,
          child: Stack(
            children: [
              Positioned(
                top: -120,
                right: -80,
                child: Container(
                  width: 320,
                  height: 320,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _C.primaryGreen.withOpacity(.055),
                  ),
                ),
              ),
              Positioned(
                bottom: -140,
                left: -90,
                child: Container(
                  width: 360,
                  height: 360,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _C.blue.withOpacity(.055),
                  ),
                ),
              ),
              Center(
                child: Container(
                  width: 430,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 32),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.92),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: _C.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(.055),
                        blurRadius: 30,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Transform.scale(
                        scale: .76 + (.24 * ballValue),
                        child: Container(
                          width: 92,
                          height: 92,
                          decoration: BoxDecoration(
                            color: _C.primaryGreen,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: _C.primaryGreen.withOpacity(.26),
                                blurRadius: 34,
                                offset: const Offset(0, 18),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.sports_soccer_rounded,
                            color: Colors.white,
                            size: 48,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Opacity(
                        opacity: titleValue,
                        child: Transform.translate(
                          offset: Offset(0, 18 * (1 - titleValue)),
                          child: const Text(
                            'СПОРТОТЕКА',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _C.text,
                              fontSize: 42,
                              height: 1,
                              letterSpacing: 4.2,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Загружаем кабинет клуба',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _C.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -.1,
                        ),
                      ),
                      const SizedBox(height: 22),
                      _WorkspaceProgressBar(
                        progress: progressValue,
                        height: 12,
                        largePercent: true,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkspaceWallpaper extends StatelessWidget {
  final _WorkspaceWallpaperStyle style;
  final String clubName;
  final String? clubLogo;

  const _WorkspaceWallpaper({
    required this.style,
    required this.clubName,
    required this.clubLogo,
  });

  @override
  Widget build(BuildContext context) {
    // Sportoteka Pro 2.0: нейтральный однотонный холст без градиентов,
    // сетки, свечения и декоративных логотипов за рабочими окнами.
    final dark = style == _WorkspaceWallpaperStyle.graphite;
    return ColoredBox(
      color: dark ? const Color(0xFF15181C) : const Color(0xFFF6F7F6),
    );
  }

  LinearGradient _gradientForStyle(_WorkspaceWallpaperStyle style) {
    switch (style) {
      case _WorkspaceWallpaperStyle.clean:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF8FAFC), Color(0xFFEFF3F6), Color(0xFFFFFFFF)],
        );
      case _WorkspaceWallpaperStyle.club:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF7FBF8), Color(0xFFE8F7EF), Color(0xFFFFFFFF)],
        );
      case _WorkspaceWallpaperStyle.pitch:
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFEAF8F0), Color(0xFFDDF2E6), Color(0xFFF8FAFC)],
        );
      case _WorkspaceWallpaperStyle.graphite:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF111315), Color(0xFF20242A), Color(0xFF0F1512)],
        );
      case _WorkspaceWallpaperStyle.sportoteka:
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF7FBF8), Color(0xFFEAF8F0), Color(0xFFF5F7FA)],
        );
    }
  }
}

class _WorkspaceWallpaperPatternPainter extends CustomPainter {
  final bool dark;
  final bool pitch;

  const _WorkspaceWallpaperPatternPainter(
      {required this.dark, required this.pitch});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color =
          (dark ? Colors.white : _C.primaryGreen).withOpacity(dark ? .035 : .04)
      ..strokeWidth = 1;

    for (double x = 0; x < size.width; x += 56) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += 56) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          (dark ? _C.primaryGreen : _C.primaryGreen)
              .withOpacity(dark ? .22 : .12),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(
          center: Offset(size.width * .78, size.height * .20), radius: 360));
    canvas.drawCircle(
        Offset(size.width * .78, size.height * .20), 360, glowPaint);

    if (!pitch) return;

    final fieldPaint = Paint()
      ..color = _C.primaryGreen.withOpacity(.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final rect = Rect.fromLTWH(size.width * .58, size.height * .18,
        size.width * .30, size.height * .50);
    canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(18)), fieldPaint);
    canvas.drawLine(Offset(rect.left, rect.center.dy),
        Offset(rect.right, rect.center.dy), fieldPaint);
    canvas.drawCircle(
        rect.center, math.min(rect.width, rect.height) * .12, fieldPaint);
  }

  @override
  bool shouldRepaint(covariant _WorkspaceWallpaperPatternPainter oldDelegate) {
    return oldDelegate.dark != dark || oldDelegate.pitch != pitch;
  }
}

class _WorkspaceDesktopIconsLayer extends StatelessWidget {
  final Size desktopSize;
  final List<_FullMenuItem> items;
  final Map<ClubSection, Offset> iconPositions;
  final ValueChanged<ClubSection> onOpen;
  final void Function(ClubSection section, Offset position, Size desktopSize)
      onMoved;

  const _WorkspaceDesktopIconsLayer({
    required this.desktopSize,
    required this.items,
    required this.iconPositions,
    required this.onOpen,
    required this.onMoved,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        for (int index = 0; index < items.length; index++)
          _buildIcon(items[index], index),
      ],
    );
  }

  Widget _buildIcon(_FullMenuItem item, int index) {
    final defaultPosition = Offset(
      28 + (index ~/ 6) * 112.0,
      26 + (index % 6) * 106.0,
    );
    final position = iconPositions[item.section] ?? defaultPosition;

    return Positioned(
      left: position.dx,
      top: position.dy,
      child: _WorkspaceDesktopIcon(
        item: item,
        onTap: () => onOpen(item.section),
        onDragUpdate: (delta) =>
            onMoved(item.section, position + delta, desktopSize),
      ),
    );
  }
}

class _WorkspaceDesktopIcon extends StatefulWidget {
  final _FullMenuItem item;
  final VoidCallback onTap;
  final ValueChanged<Offset> onDragUpdate;

  const _WorkspaceDesktopIcon({
    required this.item,
    required this.onTap,
    required this.onDragUpdate,
  });

  @override
  State<_WorkspaceDesktopIcon> createState() => _WorkspaceDesktopIconState();
}

class _WorkspaceDesktopIconState extends State<_WorkspaceDesktopIcon> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onPanUpdate: (details) => widget.onDragUpdate(details.delta),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 92,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          decoration: BoxDecoration(
            color: _hovered
                ? Colors.white.withOpacity(.74)
                : Colors.white.withOpacity(.42),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: Colors.white.withOpacity(_hovered ? .80 : .42)),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(.08),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : const [],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.96),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(.08),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(widget.item.icon, color: _C.railText, size: 27),
              ),
              const SizedBox(height: 7),
              Text(
                widget.item.title,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _C.text,
                  fontSize: 11.5,
                  height: 1.05,
                  fontWeight: FontWeight.w600,
                  shadows: [
                    Shadow(color: Colors.white, blurRadius: 8),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkspaceFloatingWindow extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool active;
  final bool maximized;
  final VoidCallback onTap;
  final VoidCallback onClose;
  final VoidCallback onMinimize;
  final VoidCallback onMaximize;
  final ValueChanged<Offset> onDragUpdate;
  final ValueChanged<Offset> onResizeUpdate;
  final Widget child;

  const _WorkspaceFloatingWindow({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.active,
    required this.maximized,
    required this.onTap,
    required this.onClose,
    required this.onMinimize,
    required this.onMaximize,
    required this.onDragUpdate,
    required this.onResizeUpdate,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(maximized ? 22 : 24),
          border: Border.all(color: Colors.transparent, width: 0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(active ? .14 : .09),
              blurRadius: active ? 42 : 28,
              offset: Offset(0, active ? 22 : 14),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(maximized ? 22 : 24),
          child: Column(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate:
                    maximized ? null : (details) => onDragUpdate(details.delta),
                onDoubleTap: onMaximize,
                child: _WorkspaceWindowTitleBar(
                  title: title,
                  subtitle: subtitle,
                  icon: icon,
                  active: active,
                  maximized: maximized,
                  onClose: onClose,
                  onMinimize: onMinimize,
                  onMaximize: onMaximize,
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ColoredBox(
                        color: _C.bg,
                        child: ClipRect(child: child),
                      ),
                    ),
                    if (!maximized)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onPanUpdate: (details) =>
                              onResizeUpdate(details.delta),
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: Align(
                              alignment: Alignment.bottomRight,
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: Icon(Icons.open_in_full_rounded,
                                    size: 13,
                                    color: _C.lightMuted.withOpacity(.80)),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkspaceWindowTitleBar extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool active;
  final bool maximized;
  final VoidCallback onClose;
  final VoidCallback onMinimize;
  final VoidCallback onMaximize;

  const _WorkspaceWindowTitleBar({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.active,
    required this.maximized,
    required this.onClose,
    required this.onMinimize,
    required this.onMaximize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: active ? Colors.white : const Color(0xFFF8F9FA),
        border: const Border(
            bottom: BorderSide(color: Color(0x00FFFFFF), width: 0)),
      ),
      child: Row(
        children: [
          Row(
            children: [
              _MacWindowDot(
                  icon: Icons.close_rounded,
                  color: const Color(0xFFE9ECEF),
                  iconColor: const Color(0xFF6B7280),
                  onTap: onClose,
                  tooltip: 'Закрыть'),
              const SizedBox(width: 7),
              _MacWindowDot(
                  icon: Icons.remove_rounded,
                  color: const Color(0xFFF1F3F5),
                  iconColor: const Color(0xFF6B7280),
                  onTap: onMinimize,
                  tooltip: 'Свернуть'),
              const SizedBox(width: 7),
              _MacWindowDot(
                  icon: maximized
                      ? Icons.fullscreen_exit_rounded
                      : Icons.open_in_full_rounded,
                  color: const Color(0xFFF1F3F5),
                  iconColor: const Color(0xFF667085),
                  onTap: onMaximize,
                  tooltip: maximized ? 'Вернуть размер' : 'Развернуть'),
            ],
          ),
          const SizedBox(width: 14),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _C.railPanel,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: _C.borderSoft),
            ),
            child: Icon(icon, color: _C.railText, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _C.text,
                    fontSize: 13.5,
                    height: 1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle.trim().isEmpty
                      ? 'Sportoteka Workspace'
                      : subtitle.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _C.muted,
                    fontSize: 11.5,
                    height: 1,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MacWindowDot extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color iconColor;
  final VoidCallback onTap;
  final String tooltip;

  const _MacWindowDot({
    required this.icon,
    required this.color,
    required this.iconColor,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 17,
          height: 17,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(color: _C.borderSoft),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.035),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, color: iconColor, size: 10),
        ),
      ),
    );
  }
}

class _WorkspaceDock extends StatelessWidget {
  final String clubName;
  final String? clubLogo;
  final String selectedTeamName;
  final _WorkspaceDockSize dockSize;
  final List<_FullMenuItem> pinnedItems;
  final List<_WorkspaceWindowState> openWindows;
  final ClubSection activeSection;
  final VoidCallback onOpenStart;
  final VoidCallback onOpenSearch;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenHome;
  final VoidCallback onRefresh;
  final ValueChanged<ClubSection> onOpenSection;

  const _WorkspaceDock({
    required this.clubName,
    required this.clubLogo,
    required this.selectedTeamName,
    required this.dockSize,
    required this.pinnedItems,
    required this.openWindows,
    required this.activeSection,
    required this.onOpenStart,
    required this.onOpenSearch,
    required this.onOpenSettings,
    required this.onOpenHome,
    required this.onRefresh,
    required this.onOpenSection,
  });

  double get _buttonSize {
    switch (dockSize) {
      case _WorkspaceDockSize.compact:
        return 36;
      case _WorkspaceDockSize.large:
        return 46;
      case _WorkspaceDockSize.normal:
        return 40;
    }
  }

  double get _dockHeight {
    switch (dockSize) {
      case _WorkspaceDockSize.compact:
        return 52;
      case _WorkspaceDockSize.large:
        return 62;
      case _WorkspaceDockSize.normal:
        return 56;
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final maxWidth = math.min(width - 28, 1040.0);
    final runningSections = openWindows.map((window) => window.section).toSet();
    final visibleItems = <_FullMenuItem>[
      ...pinnedItems,
      for (final window in openWindows)
        if (!pinnedItems.any((item) => item.section == window.section))
          _FullMenuItem(window.section, Icons.widgets_rounded,
              window.section.name, 'Запущено'),
    ];

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          height: _dockHeight,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.96),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: const Color(0xFFE3E8EF), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.12),
                blurRadius: 24,
                spreadRadius: -10,
                offset: const Offset(0, 12),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(.04),
                blurRadius: 8,
                spreadRadius: -5,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _WorkspaceDockButton(
                icon: Icons.grid_view_rounded,
                tooltip: 'Все модули',
                size: _buttonSize,
                active: false,
                running: false,
                onTap: onOpenStart,
              ),
              const SizedBox(width: 7),
              _WorkspaceDockButton(
                icon: Icons.search_rounded,
                tooltip: 'Поиск',
                size: _buttonSize,
                active: false,
                running: false,
                onTap: onOpenSearch,
              ),
              const SizedBox(width: 8),
              _WorkspaceDockDivider(height: _buttonSize - 12),
              const SizedBox(width: 8),
              Flexible(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      for (final item in visibleItems) ...[
                        _WorkspaceDockButton(
                          icon: item.icon,
                          tooltip: item.title,
                          size: _buttonSize,
                          active: activeSection == item.section,
                          running: runningSections.contains(item.section),
                          minimized: openWindows.any(
                              (w) => w.section == item.section && w.minimized),
                          onTap: () => onOpenSection(item.section),
                        ),
                        const SizedBox(width: 5),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _WorkspaceDockDivider(height: _buttonSize - 12),
              const SizedBox(width: 8),
              _WorkspaceDockButton(
                icon: Icons.tune_rounded,
                tooltip: 'Настройки рабочего стола',
                size: _buttonSize,
                active: false,
                running: false,
                onTap: onOpenSettings,
              ),
              const SizedBox(width: 5),
              _WorkspaceDockButton(
                icon: Icons.refresh_rounded,
                tooltip: 'Обновить',
                size: _buttonSize,
                active: false,
                running: false,
                onTap: onRefresh,
              ),
              const SizedBox(width: 5),
              _WorkspaceDockButton(
                icon: Icons.home_rounded,
                tooltip: 'На главную',
                size: _buttonSize,
                active: false,
                running: false,
                onTap: onOpenHome,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkspaceDockDivider extends StatelessWidget {
  final double height;
  const _WorkspaceDockDivider({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
        width: 1, height: height, color: _C.border.withOpacity(.75));
  }
}

class _WorkspaceDockButton extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final double size;
  final bool active;
  final bool running;
  final bool minimized;
  final VoidCallback onTap;

  const _WorkspaceDockButton({
    required this.icon,
    required this.tooltip,
    required this.size,
    required this.active,
    required this.running,
    required this.onTap,
    this.minimized = false,
  });

  @override
  State<_WorkspaceDockButton> createState() => _WorkspaceDockButtonState();
}

class _WorkspaceDockButtonState extends State<_WorkspaceDockButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bg = widget.active
        ? const Color(0xFFF0F2F5)
        : _hovered
            ? const Color(0xFFF3F5F7)
            : Colors.transparent;
    final iconColor =
        widget.active ? const Color(0xFF111827) : const Color(0xFF344054);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Tooltip(
        message: widget.tooltip,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(17),
          child: SizedBox(
            width: widget.active ? widget.size + 6 : widget.size,
            height: widget.size + 5,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: widget.active ? widget.size + 6 : widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                        color: widget.active
                            ? const Color(0xFFE3E8EF)
                            : Colors.transparent),
                  ),
                  child: Icon(widget.icon,
                      color: iconColor, size: widget.size >= 44 ? 23 : 21),
                ),
                if (widget.running)
                  Positioned(
                    bottom: 0,
                    child: Container(
                      width: widget.minimized ? 12 : 6,
                      height: 4,
                      decoration: BoxDecoration(
                        color: widget.minimized
                            ? _C.lightMuted
                            : const Color(0xFF111827),
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

class _MacWorkspaceSettingsDialog extends StatefulWidget {
  final List<_FullMenuItem> modules;
  final Set<ClubSection> dockSections;
  final Set<ClubSection> desktopSections;
  final bool showDesktopIcons;
  final _WorkspaceDockSize dockSize;
  final _WorkspaceWallpaperStyle wallpaperStyle;
  final ValueChanged<bool> onShowDesktopIconsChanged;
  final ValueChanged<_WorkspaceDockSize> onDockSizeChanged;
  final ValueChanged<_WorkspaceWallpaperStyle> onWallpaperChanged;
  final ValueChanged<Set<ClubSection>> onDockSectionsChanged;
  final ValueChanged<Set<ClubSection>> onDesktopSectionsChanged;

  const _MacWorkspaceSettingsDialog({
    required this.modules,
    required this.dockSections,
    required this.desktopSections,
    required this.showDesktopIcons,
    required this.dockSize,
    required this.wallpaperStyle,
    required this.onShowDesktopIconsChanged,
    required this.onDockSizeChanged,
    required this.onWallpaperChanged,
    required this.onDockSectionsChanged,
    required this.onDesktopSectionsChanged,
  });

  @override
  State<_MacWorkspaceSettingsDialog> createState() =>
      _MacWorkspaceSettingsDialogState();
}

class _MacWorkspaceSettingsDialogState
    extends State<_MacWorkspaceSettingsDialog> {
  int _tab = 0;
  late bool _showIcons;
  late _WorkspaceDockSize _dockSize;
  late _WorkspaceWallpaperStyle _wallpaper;
  late Set<ClubSection> _dockSections;
  late Set<ClubSection> _desktopSections;

  @override
  void initState() {
    super.initState();
    _showIcons = widget.showDesktopIcons;
    _dockSize = widget.dockSize;
    _wallpaper = widget.wallpaperStyle;
    _dockSections = Set<ClubSection>.of(widget.dockSections);
    _desktopSections = Set<ClubSection>.of(widget.desktopSections);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final dialogWidth = math.min(920.0, size.width - 32);
    final dialogHeight = math.min(640.0, size.height - 52);

    return Dialog(
      elevation: 0,
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: Colors.transparent,
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F6F8),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withOpacity(.82)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.20),
              blurRadius: 50,
              offset: const Offset(0, 24),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Row(
            children: [
              SizedBox(
                width: 250,
                child: _buildSidebar(context),
              ),
              Expanded(
                child: Container(
                  color: Colors.white.withOpacity(.72),
                  padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _titleForTab(),
                              style: const TextStyle(
                                color: _C.text,
                                fontSize: 24,
                                height: 1,
                                letterSpacing: -0.8,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded,
                                color: _C.railText),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Expanded(child: _buildTabContent()),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    final tabs = const [
      _SettingsTabData(Icons.desktop_mac_rounded, 'Основные'),
      _SettingsTabData(Icons.wallpaper_rounded, 'Обои'),
      _SettingsTabData(Icons.dock_rounded, 'Dock'),
      _SettingsTabData(Icons.widgets_rounded, 'Модули'),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFEDEFF2).withOpacity(.92),
        border: const Border(right: BorderSide(color: _C.borderSoft)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _MacWindowDot(
                  icon: Icons.close_rounded,
                  color: const Color(0xFFE9ECEF),
                  iconColor: const Color(0xFF6B7280),
                  onTap: () => Navigator.of(context).pop(),
                  tooltip: 'Закрыть'),
              const SizedBox(width: 7),
              _MacWindowDot(
                  icon: Icons.remove_rounded,
                  color: const Color(0xFFF1F3F5),
                  iconColor: const Color(0xFF6B7280),
                  onTap: () {},
                  tooltip: 'Свернуть'),
              const SizedBox(width: 7),
              _MacWindowDot(
                  icon: Icons.open_in_full_rounded,
                  color: const Color(0xFFF1F3F5),
                  iconColor: const Color(0xFF667085),
                  onTap: () {},
                  tooltip: 'Развернуть'),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.75),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _C.borderSoft),
            ),
            child: const Row(
              children: [
                Icon(Icons.search_rounded, color: _C.railMuted, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Поиск',
                    style: TextStyle(
                        color: _C.railMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          for (int i = 0; i < tabs.length; i++)
            _SettingsSidebarTile(
              icon: tabs[i].icon,
              title: tabs[i].title,
              active: _tab == i,
              onTap: () => setState(() => _tab = i),
            ),
          const Spacer(),
          const Text(
            'Sportoteka Workspace',
            style: TextStyle(
                color: _C.railMuted, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  String _titleForTab() {
    switch (_tab) {
      case 1:
        return 'Обои';
      case 2:
        return 'Dock';
      case 3:
        return 'Модули';
      case 0:
      default:
        return 'Основные';
    }
  }

  Widget _buildTabContent() {
    switch (_tab) {
      case 1:
        return _buildWallpaperTab();
      case 2:
        return _buildDockTab();
      case 3:
        return _buildModulesTab();
      case 0:
      default:
        return _buildGeneralTab();
    }
  }

  Widget _buildGeneralTab() {
    return ListView(
      children: [
        _MacSettingsCard(
          title: 'Рабочий стол',
          subtitle:
              'Чистое пространство клуба: обои, иконки, окна модулей и нижний Dock.',
          child: SwitchListTile.adaptive(
            value: _showIcons,
            onChanged: (value) {
              setState(() => _showIcons = value);
              widget.onShowDesktopIconsChanged(value);
            },
            activeColor: _C.primaryGreen,
            contentPadding: EdgeInsets.zero,
            title: const Text('Показывать иконки на рабочем столе',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 12),
        _MacSettingsCard(
          title: 'Стиль',
          subtitle:
              'Цвета оставлены строгими: белый, графит, мягкий серый и фирменный зелёный акцент.',
          child: const Row(
            children: [
              _AccentPreviewDot(color: Colors.white, border: _C.border),
              SizedBox(width: 8),
              _AccentPreviewDot(color: _C.primaryGreen),
              SizedBox(width: 8),
              _AccentPreviewDot(color: _C.graphite),
              SizedBox(width: 8),
              _AccentPreviewDot(color: _C.railPanel, border: _C.border),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWallpaperTab() {
    final wallpapers = const [
      _WallpaperOption(_WorkspaceWallpaperStyle.sportoteka, 'Sportoteka',
          'Светлый зелёный градиент'),
      _WallpaperOption(
          _WorkspaceWallpaperStyle.clean, 'Чистый', 'Белый и серый'),
      _WallpaperOption(
          _WorkspaceWallpaperStyle.club, 'Клубный', 'Лёгкий фон с логотипом'),
      _WallpaperOption(
          _WorkspaceWallpaperStyle.pitch, 'Поле', 'Едва заметная разметка'),
      _WallpaperOption(
          _WorkspaceWallpaperStyle.graphite, 'Графит', 'Тёмный строгий фон'),
    ];

    return GridView.count(
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.45,
      children: [
        for (final option in wallpapers)
          _WallpaperPickerTile(
            option: option,
            selected: _wallpaper == option.style,
            onTap: () {
              setState(() => _wallpaper = option.style);
              widget.onWallpaperChanged(option.style);
            },
          ),
      ],
    );
  }

  Widget _buildDockTab() {
    return ListView(
      children: [
        _MacSettingsCard(
          title: 'Размер Dock',
          subtitle:
              'Можно сделать нижнюю панель компактнее или крупнее для ПК-монитора.',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SettingsSegment(
                title: 'Компактный',
                selected: _dockSize == _WorkspaceDockSize.compact,
                onTap: () => _setDockSize(_WorkspaceDockSize.compact),
              ),
              _SettingsSegment(
                title: 'Обычный',
                selected: _dockSize == _WorkspaceDockSize.normal,
                onTap: () => _setDockSize(_WorkspaceDockSize.normal),
              ),
              _SettingsSegment(
                title: 'Большой',
                selected: _dockSize == _WorkspaceDockSize.large,
                onTap: () => _setDockSize(_WorkspaceDockSize.large),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _MacSettingsCard(
          title: 'Иконки в Dock',
          subtitle: 'Выберите модули, которые всегда видны снизу.',
          child: _buildModuleChecklist(target: _dockSections, dock: true),
        ),
      ],
    );
  }

  Widget _buildModulesTab() {
    return ListView(
      children: [
        _MacSettingsCard(
          title: 'Иконки рабочего стола',
          subtitle:
              'Выберите модули, которые отображаются на фоне и открываются как окна.',
          child: _buildModuleChecklist(target: _desktopSections, dock: false),
        ),
      ],
    );
  }

  Widget _buildModuleChecklist(
      {required Set<ClubSection> target, required bool dock}) {
    return Column(
      children: [
        for (final module in widget.modules)
          CheckboxListTile(
            value: target.contains(module.section),
            activeColor: _C.primaryGreen,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            secondary: Icon(module.icon, color: _C.primaryGreen),
            title: Text(module.title,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(module.subtitle,
                maxLines: 1, overflow: TextOverflow.ellipsis),
            onChanged: (checked) {
              setState(() {
                if (checked == true) {
                  target.add(module.section);
                } else {
                  target.remove(module.section);
                }
              });
              if (dock) {
                widget.onDockSectionsChanged(Set<ClubSection>.of(target));
              } else {
                widget.onDesktopSectionsChanged(Set<ClubSection>.of(target));
              }
            },
          ),
      ],
    );
  }

  void _setDockSize(_WorkspaceDockSize value) {
    setState(() => _dockSize = value);
    widget.onDockSizeChanged(value);
  }
}

class _SettingsTabData {
  final IconData icon;
  final String title;
  const _SettingsTabData(this.icon, this.title);
}

class _SettingsSidebarTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool active;
  final VoidCallback onTap;

  const _SettingsSidebarTile(
      {required this.icon,
      required this.title,
      required this.active,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: active ? Colors.white.withOpacity(.92) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon,
                  color: active ? _C.primaryGreen : _C.railText, size: 18),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: active ? _C.text : _C.railText,
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MacSettingsCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _MacSettingsCard(
      {required this.title, required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _C.borderSoft),
        boxShadow: const [_C.shadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: _C.text, fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 5),
          Text(subtitle,
              style: const TextStyle(
                  color: _C.muted,
                  fontSize: 12.5,
                  height: 1.35,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _SettingsSegment extends StatelessWidget {
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const _SettingsSegment(
      {required this.title, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? _C.primaryGreen : _C.railPanel,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? _C.primaryGreen : _C.borderSoft),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: selected ? Colors.white : _C.railText,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _AccentPreviewDot extends StatelessWidget {
  final Color color;
  final Color? border;
  const _AccentPreviewDot({required this.color, this.border});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: border ?? color),
      ),
    );
  }
}

class _WallpaperOption {
  final _WorkspaceWallpaperStyle style;
  final String title;
  final String subtitle;
  const _WallpaperOption(this.style, this.title, this.subtitle);
}

class _WallpaperPickerTile extends StatelessWidget {
  final _WallpaperOption option;
  final bool selected;
  final VoidCallback onTap;

  const _WallpaperPickerTile(
      {required this.option, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color:
                  selected ? _C.primaryGreen.withOpacity(.55) : _C.borderSoft,
              width: selected ? 1.5 : 1),
          boxShadow: const [_C.shadow],
        ),
        child: Row(
          children: [
            Container(
              width: 74,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: _previewGradient(option.style),
                border: Border.all(color: _C.borderSoft),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(option.title,
                      style: const TextStyle(
                          color: _C.text,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 5),
                  Text(option.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: _C.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded,
                  color: _C.primaryGreen, size: 21),
          ],
        ),
      ),
    );
  }

  LinearGradient _previewGradient(_WorkspaceWallpaperStyle style) {
    switch (style) {
      case _WorkspaceWallpaperStyle.clean:
        return const LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFEFF3F6)]);
      case _WorkspaceWallpaperStyle.club:
        return const LinearGradient(
            colors: [Color(0xFFE8F7EF), Color(0xFFFFFFFF)]);
      case _WorkspaceWallpaperStyle.pitch:
        return const LinearGradient(
            colors: [Color(0xFFDDF2E6), Color(0xFFF8FAFC)]);
      case _WorkspaceWallpaperStyle.graphite:
        return const LinearGradient(
            colors: [Color(0xFF111315), Color(0xFF252A31)]);
      case _WorkspaceWallpaperStyle.sportoteka:
        return const LinearGradient(
            colors: [Color(0xFFF7FBF8), Color(0xFFEAF8F0)]);
    }
  }
}
