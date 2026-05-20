// lib/presentation/team_screen/team_dashboard_screen.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'package:sportoteka/core/constants/app_colors.dart';
import 'package:sportoteka/core/subscription/premium_bottom_sheet.dart';
import 'package:sportoteka/core/subscription/subscription_access.dart';
import 'package:sportoteka/core/subscription/subscription_service.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/presentation/manager_mode/screens/manager_dashboard_screen.dart';
import 'package:sportoteka/presentation/plans/plan_folders_screen.dart';
import 'package:sportoteka/presentation/player_game_zone/create_challenge_screen.dart';
import 'package:sportoteka/presentation/player_game_zone/create_quiz_screen.dart';
import 'package:sportoteka/presentation/player_game_zone/team_challenges_screen.dart';
import 'package:sportoteka/presentation/player_game_zone/team_quizzes_screen.dart';
import 'package:sportoteka/presentation/team_attendance_screen/team_attendance_journal_screen.dart';
import 'package:sportoteka/presentation/team_calendar_screen/team_calendar_screen.dart';
import 'package:sportoteka/presentation/team_roster_screen/team_roster_screen.dart';
import 'package:sportoteka/presentation/team_video_analysis/team_video_analysis_screen.dart';
import 'package:sportoteka/presentation/training_graphics/training_graphics_screen.dart';
import 'package:sportoteka/routes/app_routes.dart';

class TeamDashboardScreen extends StatefulWidget {
  final int teamId;
  final String teamName;
  final int clubId;
  final String clubName;

  const TeamDashboardScreen({
    super.key,
    required this.teamId,
    required this.teamName,
    required this.clubId,
    required this.clubName,
  });

  @override
  State<TeamDashboardScreen> createState() => _TeamDashboardScreenState();
}

class _TeamDashboardScreenState extends State<TeamDashboardScreen> {
  static const String apiBase = "https://sportotekaapp.ru/api";
  static const String getTeamProfileUrl = "$apiBase/get_team_profile.php";
  static const String updateTeamProfileUrl = "$apiBase/update_team_profile.php";
  static const String deleteTeamUrl = "$apiBase/delete_team.php";

  static const String getTeamDashboardPrefsUrl =
      "$apiBase/get_team_dashboard_prefs.php";
  static const String saveTeamDashboardPrefsUrl =
      "$apiBase/save_team_dashboard_prefs.php";

  late String teamName;
  String teamCategory = "";
  String? teamLogoUrl;
  File? teamLogoFile;

  bool isEditing = false;
  bool isSaving = false;
  bool isDeleting = false;

  bool profileLoading = false;
  String? profileError;

  bool _loadingModuleOrder = true;
  int _userId = 0;
  bool _editMode = false;

  Color _teamDashboardBgColor = AppColors.background;

  SubscriptionAccess _subscription = SubscriptionAccess.free();

  final TextEditingController teamNameCtrl = TextEditingController();
  final TextEditingController teamCategoryCtrl = TextEditingController();
  XFile? newLogoX;

  Map<String, dynamic> _mainStyles = {};
  Map<String, dynamic> _proStyles = {};

  final List<Color> _presetColors = const [
    Color(0xFFFFFFFF),
    Color(0xFFF8F9FA),
    Color(0xFFE8F5E9),
    Color(0xFFDFF3FF),
    Color(0xFFFFF4E6),
    Color(0xFFF3E8FF),
    Color(0xFFFFEEF2),
    Color(0xFFEFFAF0),
    Color(0xFF1F2937),
    Color(0xFF111827),
    Color(0xFF00A750),
    Color(0xFF0066CC),
    Color(0xFF7E3AED),
    Color(0xFFFF9500),
    Color(0xFFFF5A5F),
    Color(0xFF06B6D4),
    Color(0xFF222222),
    Color(0xFF666666),
  ];

  late List<Map<String, dynamic>> _mainItems = [
    {
      "id": "roster",
      "t": "Состав команды",
      "s": "Игроки, добавление, профили",
      "i": Icons.groups_2_outlined,
      "theme": ModuleThemes.basic,
      "onTap": (BuildContext context, int teamId, String teamName) =>
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TeamRosterScreen(
                teamId: teamId,
                teamName: teamName,
              ),
            ),
          ),
    },
    {
      "id": "calendar",
      "t": "Календарь",
      "s": "Тренировки, игры, мероприятия",
      "i": Icons.calendar_month_outlined,
      "theme": ModuleThemes.calendar,
      "onTap": (BuildContext context, int teamId, String teamName) => Get.to(
            () => TeamCalendarScreen(
              teamId: teamId,
              teamName: teamName,
            ),
          ),
    },
    {
      "id": "attendance",
      "t": "Журнал посещаемости",
      "s": "Даты и мероприятия из календаря",
      "i": Icons.fact_check_outlined,
      "theme": ModuleThemes.attendance,
      "onTap": (BuildContext context, int teamId, String teamName) => Get.to(
            () => TeamAttendanceJournalScreen(
              teamId: teamId,
              teamName: teamName,
            ),
          ),
    },
    {
      "id": "matches",
      "t": "Матчи",
      "s": "Список матчей и результаты",
      "i": Icons.sports_soccer_outlined,
      "theme": ModuleThemes.basic,
      "onTap": (BuildContext context, int teamId, String teamName) =>
          Get.toNamed(
            AppRoutes.teamMatchesScreen,
            arguments: teamId,
          ),
    },
    {
      "id": "manager_mode",
      "t": "Менеджер команды",
      "s": "Тактика, состав, симуляция матчей",
      "i": Icons.psychology_alt_outlined,
      "theme": ModuleThemes.analytics,
      "onTap": (BuildContext context, int teamId, String teamName) =>
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ManagerDashboardScreen(
                teamId: teamId,
                userId: _userId,
                teamName: teamName,
              ),
            ),
          ),
    },
    {
      "id": "chat",
      "t": "Командный чат",
      "s": "Общий чат внутри команды",
      "i": Icons.forum_outlined,
      "theme": ModuleThemes.chat,
      "onTap": (BuildContext context, int teamId, String teamName) =>
          Get.snackbar("Модуль", "Чат подключим следующим этапом"),
    },
    {
      "id": "card",
      "t": "Визитная карточка",
      "s": "Информация о команде",
      "i": Icons.info_outline,
      "theme": ModuleThemes.basic,
      "onTap": (BuildContext context, int teamId, String teamName) =>
          Get.toNamed(
            AppRoutes.teamDescriptionScreen,
            arguments: teamId,
          ),
    },
  ];

  late List<Map<String, dynamic>> _gameZoneItems = [
    {
      "id": "create_challenge",
      "t": "Создать задание",
      "s": "Ежедневное или недельное задание для игроков",
      "i": Icons.flag_outlined,
      "theme": ModuleThemes.challenge,
      "onTap": (BuildContext context, int teamId, String teamName) => Get.to(
            () => const CreateChallengeScreen(),
            arguments: {
              "team_id": teamId,
              "user_id": _userId,
              "team_name": teamName,
            },
          ),
    },
    {
      "id": "manage_challenges",
      "t": "Управление заданиями",
      "s": "Список созданных заданий и результаты игроков",
      "i": Icons.view_list_outlined,
      "theme": ModuleThemes.challenge,
      "onTap": (BuildContext context, int teamId, String teamName) => Get.to(
            () => const TeamChallengesScreen(),
            arguments: {
              "team_id": teamId,
              "user_id": _userId,
              "team_name": teamName,
            },
          ),
    },
    {
      "id": "team_rating",
      "t": "Рейтинг команды",
      "s": "Очки, активность и лидерборд игроков",
      "i": Icons.emoji_events_outlined,
      "theme": ModuleThemes.rating,
      "onTap": (BuildContext context, int teamId, String teamName) =>
          Get.toNamed(
            AppRoutes.teamRatingScreen,
            arguments: {
              "team_id": teamId,
              "user_id": _userId,
              "team_name": teamName,
            },
          ),
    },
    {
      "id": "create_quiz",
      "t": "Создать квиз",
      "s": "Добавить вопросы и викторину для команды",
      "i": Icons.quiz_outlined,
      "theme": ModuleThemes.quiz,
      "onTap": (BuildContext context, int teamId, String teamName) => Get.to(
            () => const CreateQuizScreen(),
            arguments: {
              "team_id": teamId,
              "user_id": _userId,
              "team_name": teamName,
            },
          ),
    },
    {
      "id": "manage_quizzes",
      "t": "Мои квизы",
      "s": "Список квизов, вопросов и попыток игроков",
      "i": Icons.view_list_outlined,
      "theme": ModuleThemes.quiz,
      "onTap": (BuildContext context, int teamId, String teamName) => Get.to(
            () => const TeamQuizzesScreen(),
            arguments: {
              "team_id": teamId,
              "user_id": _userId,
              "team_name": teamName,
            },
          ),
    },
    {
      "id": "create_battle",
      "t": "Создать битву",
      "s": "Организовать дуэль 1 на 1 между игроками",
      "i": Icons.local_fire_department_outlined,
      "theme": ModuleThemes.battle,
      "onTap": (BuildContext context, int teamId, String teamName) =>
          Get.snackbar(
            "Модуль",
            "Экран создания битвы подключим следующим этапом",
          ),
    },
    {
      "id": "match_games_admin",
      "t": "Мини-игры к матчам",
      "s": "Подготовка прогнозов и активностей к матчам",
      "i": Icons.sports_score_outlined,
      "theme": ModuleThemes.matchGames,
      "onTap": (BuildContext context, int teamId, String teamName) =>
          Get.snackbar(
            "Модуль",
            "Настройку мини-игр к матчам подключим следующим этапом",
          ),
    },
  ];

  late List<Map<String, dynamic>> _proItems = [
    {
      "id": "graphics",
      "t": "Графический редактор",
      "s": "Построение тренировок",
      "i": Icons.draw_outlined,
      "theme": ModuleThemes.editor,
      "onTap": (BuildContext context, int teamId, String teamName) =>
          _openProModule('graphics'),
    },
    {
      "id": "plans",
      "t": "Планы-конспекты",
      "s": "База хранения планов",
      "i": Icons.menu_book_outlined,
      "theme": ModuleThemes.plans,
      "onTap": (BuildContext context, int teamId, String teamName) =>
          _openProModule('plans'),
    },
    {
      "id": "videoanalysis",
      "t": "Видеоанализ",
      "s": "Разбор игр и тренировок",
      "i": Icons.video_camera_back_outlined,
      "theme": ModuleThemes.video,
      "onTap": (BuildContext context, int teamId, String teamName) =>
          _openProModule('videoanalysis'),
    },
    {
      "id": "heatmap",
      "t": "Тепловая карта",
      "s": "Тепловые зоны активности",
      "i": Icons.map_outlined,
      "theme": ModuleThemes.analytics,
      "onTap": (BuildContext context, int teamId, String teamName) =>
          _openProModule('heatmap'),
    },
    {
      "id": "testing",
      "t": "Тестирование",
      "s": "Тесты и анализ результатов",
      "i": Icons.quiz_outlined,
      "theme": ModuleThemes.basic,
      "onTap": (BuildContext context, int teamId, String teamName) =>
          _openProModule('testing'),
    },
    {
      "id": "aitechnique",
      "t": "AI-анализ техники",
      "s": "AI разбор техники игрока",
      "i": Icons.auto_awesome_outlined,
      "theme": ModuleThemes.analytics,
      "onTap": (BuildContext context, int teamId, String teamName) =>
          _openProModule('aitechnique'),
    },
    {
      "id": "arpaint",
      "t": "AR-Paint цели",
      "s": "Цели на поле в AR",
      "i": Icons.center_focus_strong_outlined,
      "theme": ModuleThemes.editor,
      "onTap": (BuildContext context, int teamId, String teamName) =>
          _openProModule('arpaint'),
    },
    {
      "id": "aiplan",
      "t": "AI-план тренировок",
      "s": "Генерация плана тренировок",
      "i": Icons.psychology_alt_outlined,
      "theme": ModuleThemes.analytics,
      "onTap": (BuildContext context, int teamId, String teamName) =>
          _openProModule('aiplan'),
    },
    {
      "id": "onering",
      "t": "One Ring",
      "s": "Занесение результатов в программу",
      "i": Icons.ring_volume_outlined,
      "theme": ModuleThemes.basic,
      "onTap": (BuildContext context, int teamId, String teamName) =>
          _openProModule('onering'),
    },
    {
      "id": "files",
      "t": "Файлообменник",
      "s": "Материалы и документы команды",
      "i": Icons.folder_shared_outlined,
      "theme": ModuleThemes.basic,
      "onTap": (BuildContext context, int teamId, String teamName) =>
          _openProModule('files'),
    },
    {
      "id": "news",
      "t": "Новости команды",
      "s": "Лента новостей команды",
      "i": Icons.feed_outlined,
      "theme": ModuleThemes.news,
      "onTap": (BuildContext context, int teamId, String teamName) =>
          _openProModule('news'),
    },
  ];

  @override
  void initState() {
    super.initState();
    teamName = widget.teamName;
    teamNameCtrl.text = teamName;
    teamCategoryCtrl.text = teamCategory;
    _initScreen();
  }

  @override
  void dispose() {
    teamNameCtrl.dispose();
    teamCategoryCtrl.dispose();
    super.dispose();
  }

  Future<void> _initScreen() async {
    final uid = await PrefUtils.getUserId();
    _userId = uid ?? 0;

    try {
      _subscription = await SubscriptionService.getUserSubscription(
        userId: _userId,
        role: 'club',
      );
      debugPrint('TEAM SUB plan=${_subscription.planCode}');
      debugPrint('TEAM SUB active=${_subscription.isActive}');
      debugPrint('TEAM SUB premium=${_subscription.isPremium}');
      debugPrint('TEAM SUB features=${_subscription.features}');
    } catch (e) {
      debugPrint('TEAM subscription load error: $e');
      _subscription = SubscriptionAccess.free();
    }

    await Future.wait([
      _loadTeamProfileSilent(),
      _loadModulePrefs(),
      _loadGameZonePrefs(),
    ]);

    if (mounted) {
      setState(() {
        _loadingModuleOrder = false;
      });
    }
  }

  Future<void> _refreshAll() async {
    final uid = await PrefUtils.getUserId();
    _userId = uid ?? _userId;

    try {
      _subscription = await SubscriptionService.getUserSubscription(
        userId: _userId,
        role: 'club',
      );
    } catch (_) {}

    await Future.wait([
      _loadTeamProfileSilent(),
      _loadModulePrefs(),
      _loadGameZonePrefs(),
    ]);

    if (mounted) {
      setState(() {});
    }
  }

  Future<bool> _ensureFeature(
    String featureCode, {
    required String title,
    required String description,
  }) async {
    debugPrint('CHECK FEATURE: $featureCode');
    debugPrint('USER FEATURES BEFORE: ${_subscription.features}');

    if (_subscription.has(featureCode)) return true;

    final activated = await showPremiumBottomSheet(
      context,
      title: title,
      description: description,
    );

    if (activated) {
      try {
        _subscription = await SubscriptionService.getUserSubscription(
          userId: _userId,
          role: 'coach',
        );
        debugPrint('USER FEATURES AFTER: ${_subscription.features}');
        if (mounted) setState(() {});
      } catch (e) {
        debugPrint('REFRESH SUBSCRIPTION ERROR: $e');
      }
    }

    return _subscription.has(featureCode);
  }

  String _mapTeamModuleToFeature(String moduleId) {
    switch (moduleId) {
      case 'graphics':
        return 'team_training_editor';
      case 'plans':
        return 'team_plans';
      case 'videoanalysis':
        return 'team_video_analysis';
      case 'heatmap':
        return 'team_heatmap';
      case 'testing':
        return 'advanced_analytics';
      case 'aitechnique':
        return 'advanced_analytics';
      case 'arpaint':
        return 'team_training_editor';
      case 'aiplan':
        return 'advanced_analytics';
      default:
        return '';
    }
  }

  bool _isPremiumTeamModule(String moduleId) {
    return [
      'graphics',
      'plans',
      'videoanalysis',
      'heatmap',
      'testing',
      'aitechnique',
      'arpaint',
      'aiplan',
    ].contains(moduleId);
  }

  Future<void> _openProModule(String moduleId) async {
    if (moduleId == 'graphics') {
      final ok = await _ensureFeature(
        'team_training_editor',
        title: 'Графический редактор',
        description:
            'Графический редактор команды доступен только по подписке.',
      );
      if (!ok) return;

      Get.to(
        () => TrainingGraphicsScreen(
          clubId: widget.clubId,
          clubName: widget.clubName,
          teamId: widget.teamId,
          teamName: teamName,
        ),
      );
      return;
    }

    if (moduleId == 'plans') {
      final ok = await _ensureFeature(
        'team_plans',
        title: 'Планы-конспекты',
        description: 'База планов команды доступна только по подписке.',
      );
      if (!ok) return;

      Get.to(
        () => PlanFoldersScreen(
          clubId: widget.clubId,
          clubName: widget.clubName,
          teamId: widget.teamId,
          selectMode: false,
          browsePlansMode: false,
        ),
      );
      return;
    }

    if (moduleId == 'videoanalysis') {
      final ok = await _ensureFeature(
        'team_video_analysis',
        title: 'Видеоанализ',
        description: 'Видеоанализ команды доступен только на платном тарифе.',
      );
      if (!ok) return;

      Get.to(
        () => TeamVideoAnalysisScreen(
          teamId: widget.teamId,
          teamName: teamName,
          clubId: widget.clubId,
          clubName: widget.clubName,
        ),
      );
      return;
    }

    if (moduleId == 'heatmap') {
      final ok = await _ensureFeature(
        'team_heatmap',
        title: 'Тепловая карта',
        description: 'Тепловые карты команды доступны только по подписке.',
      );
      if (!ok) return;

      Get.snackbar("Модуль", "Тепловую карту подключим следующим этапом");
      return;
    }

    if (moduleId == 'testing') {
      final ok = await _ensureFeature(
        'advanced_analytics',
        title: 'Тестирование',
        description: 'Модуль тестирования доступен только на PRO-тарифе.',
      );
      if (!ok) return;

      Get.snackbar("Модуль", "Тестирование подключим следующим этапом");
      return;
    }

    if (moduleId == 'aitechnique') {
      final ok = await _ensureFeature(
        'advanced_analytics',
        title: 'AI-анализ техники',
        description: 'AI-анализ техники доступен только на PRO-тарифе.',
      );
      if (!ok) return;

      Get.snackbar("Модуль", "AI-технику подключим следующим этапом");
      return;
    }

    if (moduleId == 'arpaint') {
      final ok = await _ensureFeature(
        'team_training_editor',
        title: 'AR-Paint цели',
        description: 'AR-инструменты доступны только по подписке.',
      );
      if (!ok) return;

      Get.snackbar("Модуль", "AR-Paint подключим следующим этапом");
      return;
    }

    if (moduleId == 'aiplan') {
      final ok = await _ensureFeature(
        'advanced_analytics',
        title: 'AI-план тренировок',
        description: 'AI-план тренировок доступен только по подписке.',
      );
      if (!ok) return;

      Get.snackbar("Модуль", "AI-план подключим следующим этапом");
      return;
    }

    if (moduleId == 'onering') {
      Get.snackbar("Модуль", "One Ring подключим следующим этапом");
      return;
    }

    if (moduleId == 'files') {
      Get.snackbar("Модуль", "Файлообмен подключим следующим этапом");
      return;
    }

    if (moduleId == 'news') {
      Get.snackbar("Модуль", "Новости подключим следующим этапом");
      return;
    }
  }

  Map<String, dynamic> _decode(http.Response resp) {
    try {
      final body = utf8.decode(resp.bodyBytes, allowMalformed: true).trim();
      final j = json.decode(body);
      if (j is Map<String, dynamic>) return j;
      return {"success": false};
    } catch (_) {
      return {"success": false};
    }
  }

  String _asStr(dynamic v) => (v ?? "").toString();

  String? _normalizePhoto(String? raw) {
    if (raw == null) return null;
    var s = raw.trim();
    if (s.isEmpty) return null;

    if (s.startsWith("http://") || s.startsWith("https://")) return s;

    if (!s.startsWith("/")) s = "/$s";
    return "https://sportotekaapp.ru$s";
  }

  String? _bust(String? url) {
    if (url == null) return null;
    final u = url.trim();
    if (u.isEmpty) return null;
    final sep = u.contains("?") ? "&" : "?";
    return "$u${sep}v=${DateTime.now().millisecondsSinceEpoch}";
  }

  List<Map<String, dynamic>> _applySavedOrder(
    List<Map<String, dynamic>> source,
    List<dynamic> savedIds,
  ) {
    if (savedIds.isEmpty) return List<Map<String, dynamic>>.from(source);

    final map = <String, Map<String, dynamic>>{};
    for (final item in source) {
      final id = (item["id"] ?? "").toString();
      if (id.isNotEmpty) {
        map[id] = item;
      }
    }

    final result = <Map<String, dynamic>>[];

    for (final rawId in savedIds) {
      final id = rawId.toString();
      if (map.containsKey(id)) {
        result.add(map[id]!);
        map.remove(id);
      }
    }

    result.addAll(map.values);
    return result;
  }

  Color _colorFromHex(String hex) {
    final buffer = StringBuffer();
    String value = hex.replaceAll('#', '');
    if (value.length == 6) buffer.write('ff');
    buffer.write(value);
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).padLeft(8, '0').substring(2)}';
  }

  Future<void> _pickTeamLogo() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1200,
    );
    if (x != null) {
      setState(() {
        newLogoX = x;
        teamLogoFile = File(x.path);
      });
    }
  }

  Future<void> _loadModulePrefs() async {
    if (_userId <= 0) return;

    try {
      final mainResp = await http.post(
        Uri.parse(getTeamDashboardPrefsUrl),
        body: {
          "user_id": _userId.toString(),
          "team_id": widget.teamId.toString(),
          "section_key": "main",
        },
      ).timeout(const Duration(seconds: 10));

      final proResp = await http.post(
        Uri.parse(getTeamDashboardPrefsUrl),
        body: {
          "user_id": _userId.toString(),
          "team_id": widget.teamId.toString(),
          "section_key": "pro",
        },
      ).timeout(const Duration(seconds: 10));

      final mainData = _decode(mainResp);
      final proData = _decode(proResp);

      final mainOrder = (mainData["order"] is List)
          ? List<dynamic>.from(mainData["order"])
          : <dynamic>[];

      final proOrder = (proData["order"] is List)
          ? List<dynamic>.from(proData["order"])
          : <dynamic>[];

      final mainStyles = (mainData["styles"] is Map)
          ? Map<String, dynamic>.from(mainData["styles"])
          : <String, dynamic>{};

      final proStyles = (proData["styles"] is Map)
          ? Map<String, dynamic>.from(proData["styles"])
          : <String, dynamic>{};

      if (mainStyles["__dashboard_bg__"] != null) {
        final bgHex = mainStyles["__dashboard_bg__"].toString();
        if (bgHex.isNotEmpty) {
          _teamDashboardBgColor = _colorFromHex(bgHex);
        }
      }

      if (!mounted) return;

      setState(() {
        _mainItems = _applySavedOrder(_mainItems, mainOrder);
        _proItems = _applySavedOrder(_proItems, proOrder);
        _mainStyles = mainStyles;
        _proStyles = proStyles;
      });
    } catch (e) {
      debugPrint("LOAD PREFS ERROR: $e");
    }
  }

  Future<void> _loadGameZonePrefs() async {
    if (_userId <= 0) return;

    try {
      final resp = await http.post(
        Uri.parse(getTeamDashboardPrefsUrl),
        body: {
          "user_id": _userId.toString(),
          "team_id": widget.teamId.toString(),
          "section_key": "game_zone",
        },
      ).timeout(const Duration(seconds: 10));

      final data = _decode(resp);

      final order = (data["order"] is List)
          ? List<dynamic>.from(data["order"])
          : <dynamic>[];

      if (!mounted) return;

      setState(() {
        _gameZoneItems = _applySavedOrder(_gameZoneItems, order);
      });
    } catch (e) {
      debugPrint("LOAD GAME ZONE PREFS ERROR: $e");
    }
  }

  Future<void> _saveModulePrefs({
    required String sectionKey,
    required List<Map<String, dynamic>> items,
    required Map<String, dynamic> styles,
  }) async {
    if (_userId <= 0) return;

    final orderIds = items
        .map((e) => (e["id"] ?? "").toString())
        .where((e) => e.isNotEmpty)
        .toList();

    try {
      final resp = await http.post(
        Uri.parse(saveTeamDashboardPrefsUrl),
        body: {
          "user_id": _userId.toString(),
          "team_id": widget.teamId.toString(),
          "section_key": sectionKey,
          "order_json": jsonEncode(orderIds),
          "styles_json": jsonEncode(styles),
        },
      ).timeout(const Duration(seconds: 10));

      final data = _decode(resp);
      final ok = data["success"] == true || data["status"] == "success";

      if (!ok) {
        Get.snackbar(
          "Ошибка",
          (data["message"] ?? "Не удалось сохранить настройки").toString(),
        );
      }
    } catch (e) {
      debugPrint("SAVE PREFS ERROR: $e");
      Get.snackbar("Ошибка", "Не удалось сохранить настройки модулей");
    }
  }

  void _moveMainItem(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;
    if (oldIndex < 0 || oldIndex >= _mainItems.length) return;
    if (newIndex < 0 || newIndex >= _mainItems.length) return;

    setState(() {
      final item = _mainItems.removeAt(oldIndex);
      _mainItems.insert(newIndex, item);
    });

    _saveModulePrefs(
      sectionKey: "main",
      items: _mainItems,
      styles: _mainStyles,
    );
  }

  void _moveGameZoneItem(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;
    if (oldIndex < 0 || oldIndex >= _gameZoneItems.length) return;
    if (newIndex < 0 || newIndex >= _gameZoneItems.length) return;

    setState(() {
      final item = _gameZoneItems.removeAt(oldIndex);
      _gameZoneItems.insert(newIndex, item);
    });

    _saveModulePrefs(
      sectionKey: "game_zone",
      items: _gameZoneItems,
      styles: const {},
    );
  }

  void _moveProItem(int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;
    if (oldIndex < 0 || oldIndex >= _proItems.length) return;
    if (newIndex < 0 || newIndex >= _proItems.length) return;

    setState(() {
      final item = _proItems.removeAt(oldIndex);
      _proItems.insert(newIndex, item);
    });

    _saveModulePrefs(
      sectionKey: "pro",
      items: _proItems,
      styles: _proStyles,
    );
  }

  Future<void> _openDashboardBgPicker() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        final maxHeight = MediaQuery.of(context).size.height * 0.55;

        return SafeArea(
          top: false,
          child: SizedBox(
            height: maxHeight,
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 14),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "Фон панели команды",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _presetColors.map((c) {
                        final isSelected = _teamDashboardBgColor.value == c.value;

                        return GestureDetector(
                          onTap: () async {
                            setState(() {
                              _teamDashboardBgColor = c;
                              _mainStyles["__dashboard_bg__"] = _colorToHex(c);
                            });

                            Navigator.pop(context);

                            await _saveModulePrefs(
                              sectionKey: "main",
                              items: _mainItems,
                              styles: _mainStyles,
                            );
                          },
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? Colors.black
                                    : Colors.grey.shade300,
                                width: isSelected ? 3 : 1,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () async {
                        setState(() {
                          _teamDashboardBgColor = AppColors.background;
                          _mainStyles.remove("__dashboard_bg__");
                        });

                        Navigator.pop(context);

                        await _saveModulePrefs(
                          sectionKey: "main",
                          items: _mainItems,
                          styles: _mainStyles,
                        );
                      },
                      child: const Text("Сбросить фон"),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openModuleStyleSheet({
    required String sectionKey,
    required String itemId,
  }) async {
    final stylesMap = sectionKey == "main" ? _mainStyles : _proStyles;
    final current = Map<String, dynamic>.from(stylesMap[itemId] ?? {});

    String? bgColor = current["bgColor"];
    String? titleColor = current["titleColor"];
    String? subtitleColor = current["subtitleColor"];
    String? iconColor = current["iconColor"];
    String? iconBgColor = current["iconBgColor"];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        final maxHeight = MediaQuery.of(context).size.height * 0.84;

        return SafeArea(
          top: false,
          child: SizedBox(
            height: maxHeight,
            child: StatefulBuilder(
              builder: (context, setSB) {
                Widget colorRow(
                  String title,
                  String? selected,
                  Function(String) onPick,
                ) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: _presetColors.map((c) {
                          final hex = _colorToHex(c);
                          final isSelected = selected == hex;

                          return GestureDetector(
                            onTap: () => setSB(() => onPick(hex)),
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? Colors.black
                                      : Colors.grey.shade300,
                                  width: isSelected ? 3 : 1,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  );
                }

                return Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 42,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Настройка модуля",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            colorRow("Фон карточки", bgColor, (v) => bgColor = v),
                            const SizedBox(height: 20),
                            colorRow(
                              "Цвет заголовка",
                              titleColor,
                              (v) => titleColor = v,
                            ),
                            const SizedBox(height: 20),
                            colorRow(
                              "Цвет подписи",
                              subtitleColor,
                              (v) => subtitleColor = v,
                            ),
                            const SizedBox(height: 20),
                            colorRow("Цвет иконки", iconColor, (v) => iconColor = v),
                            const SizedBox(height: 20),
                            colorRow(
                              "Фон иконки",
                              iconBgColor,
                              (v) => iconBgColor = v,
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            setState(() {
                              final targetMap =
                                  sectionKey == "main" ? _mainStyles : _proStyles;
                              targetMap[itemId] = {
                                "bgColor": bgColor,
                                "titleColor": titleColor,
                                "subtitleColor": subtitleColor,
                                "iconColor": iconColor,
                                "iconBgColor": iconBgColor,
                              };
                            });

                            Navigator.pop(context);

                            await _saveModulePrefs(
                              sectionKey: sectionKey,
                              items: sectionKey == "main"
                                  ? _mainItems
                                  : _proItems,
                              styles: sectionKey == "main"
                                  ? _mainStyles
                                  : _proStyles,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            "Сохранить",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
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
            body: {"team_id": widget.teamId.toString()},
          )
          .timeout(const Duration(seconds: 10));

      final data = _decode(resp);
      if (!mounted) return;

      final ok = (data["success"] == true) || (data["status"] == "success");
      final team =
          (data["team"] is Map) ? Map<String, dynamic>.from(data["team"]) : null;

      if (ok && team != null) {
        final serverName = _asStr(team["name"]).trim();
        final serverCat = _asStr(team["category"]).trim();
        final serverLogoRaw = _normalizePhoto(_asStr(team["logo"]));
        final serverLogo = _bust(serverLogoRaw);

        setState(() {
          if (serverName.isNotEmpty) teamName = serverName;
          teamCategory = serverCat;
          teamLogoUrl = serverLogo;
          profileLoading = false;

          if (!isEditing) {
            teamNameCtrl.text = teamName;
            teamCategoryCtrl.text = teamCategory;
          }
        });
      } else {
        setState(() {
          profileLoading = false;
          final msg = _asStr(data["message"]).trim();
          profileError = msg.isNotEmpty ? msg : "Не удалось загрузить профиль";
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        profileLoading = false;
        profileError = "Сетевая ошибка";
      });
    }
  }

  Future<void> _updateTeamProfile() async {
    final name = teamNameCtrl.text.trim();
    final cat = teamCategoryCtrl.text.trim();

    if (name.isEmpty) {
      Get.snackbar("Ошибка", "Введите название команды");
      return;
    }

    if (!mounted) return;
    setState(() => isSaving = true);

    try {
      final uri = Uri.parse(updateTeamProfileUrl);
      final req = http.MultipartRequest("POST", uri);

      req.fields["team_id"] = widget.teamId.toString();
      req.fields["team_name"] = name;
      req.fields["name"] = name;
      req.fields["category"] = cat;

      if (newLogoX != null) {
        req.files.add(await http.MultipartFile.fromPath("logo", newLogoX!.path));
      }

      final streamed = await req.send().timeout(const Duration(seconds: 20));
      final resp = await http.Response.fromStream(streamed);

      final data = _decode(resp);
      if (!mounted) return;

      final ok = (data["success"] == true) || (data["status"] == "success");
      if (ok) {
        setState(() {
          isEditing = false;
          newLogoX = null;
          teamLogoFile = null;
        });

        await _loadTeamProfileSilent();

        if (mounted) {
          setState(() {
            teamLogoUrl = _bust(teamLogoUrl);
          });
        }

        Get.snackbar("Готово", "Команда обновлена");
      } else {
        final msg = _asStr(data["message"]).trim();
        final err = _asStr(data["error"]).trim();
        Get.snackbar(
          "Ошибка",
          (msg.isNotEmpty ? msg : "Не удалось обновить") +
              (err.isNotEmpty ? "\n$err" : ""),
        );
      }
    } catch (_) {
      Get.snackbar("Сеть", "Ошибка соединения");
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  Future<void> _deleteTeam() async {
    if (isDeleting) return;

    final confirmCtrl = TextEditingController();
    bool acknowledged = false;
    bool canDelete = false;

    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setD) {
            void recompute() {
              final wordOk = confirmCtrl.text.trim().toLowerCase() == "удалить";
              final next = acknowledged && wordOk;
              if (next != canDelete) {
                setD(() => canDelete = next);
              } else {
                setD(() {});
              }
            }

            return AlertDialog(
              title: const Text("Удалить команду навсегда?"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Это действие необратимо.\n\n"
                    "1) Поставьте галочку.\n"
                    "2) Введите слово подтверждения: «Удалить».",
                    style: TextStyle(height: 1.25),
                  ),
                  const SizedBox(height: 10),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: acknowledged,
                    onChanged: (v) {
                      acknowledged = v == true;
                      recompute();
                    },
                    title: const Text(
                      "Я понимаю, что команда будет удалена без восстановления",
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: confirmCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: "Введите: Удалить",
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => recompute(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text("Отмена"),
                ),
                ElevatedButton(
                  onPressed: canDelete ? () => Navigator.pop(ctx, true) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: AppColors.white,
                  ),
                  child: const Text("Удалить"),
                ),
              ],
            );
          },
        );
      },
    );

    confirmCtrl.dispose();
    if (ok != true) return;

    if (!mounted) return;
    setState(() => isDeleting = true);

    try {
      final resp = await http
          .post(
            Uri.parse(deleteTeamUrl),
            body: {"team_id": widget.teamId.toString()},
          )
          .timeout(const Duration(seconds: 10));

      final data = _decode(resp);
      final okResp = (data["success"] == true) || (data["status"] == "success");

      if (okResp) {
        Get.snackbar("Готово", "Команда удалена");
        if (mounted) Navigator.pop(context, true);
      } else {
        final msg = _asStr(data["message"]).trim();
        Get.snackbar("Ошибка", msg.isNotEmpty ? msg : "Не удалось удалить");
      }
    } catch (_) {
      Get.snackbar("Сеть", "Ошибка соединения");
    } finally {
      if (mounted) setState(() => isDeleting = false);
    }
  }

  Widget _buildDefaultLogo() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withOpacity(0.12),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(
          Icons.sports_soccer_outlined,
          size: 30,
          color: AppColors.primaryGreen,
        ),
      ),
    );
  }

  void _runItemTapById(List<Map<String, dynamic>> items, String id) {
    final index = items.indexWhere((e) => (e["id"] ?? "").toString() == id);
    if (index == -1) return;

    final fn = items[index]["onTap"];
    if (fn is Function) {
      fn(context, widget.teamId, teamName);
    }
  }

  Widget _buildTeamHeroCard() {
    final isTablet = MediaQuery.of(context).size.width > 700;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF081A12),
            Color(0xFF0A5B36),
            AppColors.primaryGreen,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.14),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -24,
            right: -10,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -32,
            left: -16,
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(isTablet ? 20 : 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: isEditing ? _pickTeamLogo : null,
                      child: Container(
                        width: isTablet ? 90 : 76,
                        height: isTablet ? 90 : 76,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.92),
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.10),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: (teamLogoFile != null)
                                  ? Image.file(teamLogoFile!, fit: BoxFit.cover)
                                  : (teamLogoUrl != null &&
                                          teamLogoUrl!.isNotEmpty)
                                      ? Image.network(
                                          teamLogoUrl!,
                                          key: ValueKey(teamLogoUrl),
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              _buildDefaultLogo(),
                                        )
                                      : _buildDefaultLogo(),
                            ),
                            if (isEditing)
                              Positioned(
                                right: 2,
                                bottom: 2,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: AppColors.primaryGreen,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.edit,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: isEditing
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextField(
                                  controller: teamNameCtrl,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Название команды',
                                    hintStyle: TextStyle(
                                      color: Colors.white.withOpacity(0.70),
                                    ),
                                    enabledBorder: UnderlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Colors.white.withOpacity(0.20),
                                      ),
                                    ),
                                    focusedBorder: const UnderlineInputBorder(
                                      borderSide: BorderSide(color: Colors.white),
                                    ),
                                    counterText: '',
                                  ),
                                  maxLength: 50,
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: teamCategoryCtrl,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Категория / вид спорта',
                                    hintStyle: TextStyle(
                                      color: Colors.white.withOpacity(0.65),
                                    ),
                                    enabledBorder: UnderlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Colors.white.withOpacity(0.20),
                                      ),
                                    ),
                                    focusedBorder: const UnderlineInputBorder(
                                      borderSide: BorderSide(color: Colors.white),
                                    ),
                                    counterText: '',
                                  ),
                                  maxLength: 30,
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  teamName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: isTablet ? 28 : 22,
                                    fontWeight: FontWeight.w900,
                                    height: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  teamCategory.isNotEmpty
                                      ? teamCategory
                                      : 'Категория не указана',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.82),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          isEditing = true;
                                          teamNameCtrl.text = teamName;
                                          teamCategoryCtrl.text = teamCategory;
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 7,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.12),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                          border: Border.all(
                                            color:
                                                Colors.white.withOpacity(0.10),
                                          ),
                                        ),
                                        child: const Text(
                                          'Редактировать',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (profileLoading)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 7,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              Colors.white.withOpacity(0.10),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        child: const Text(
                                          'обновление...',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      )
                                    else if (profileError != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 7,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              Colors.white.withOpacity(0.10),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        child: const Text(
                                          'offline',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final isVeryWide = width >= 760;

                    if (isVeryWide) {
                      return Row(
                        children: [
                          Expanded(
                            child: _buildHeroStatCard(
                              title: 'Основные',
                              value: '${_mainItems.length}',
                              icon: Icons.dashboard_customize_outlined,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildHeroStatCard(
                              title: 'Игровая зона',
                              value: '${_gameZoneItems.length}',
                              icon: Icons.sports_esports_outlined,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildHeroStatCard(
                              title: 'PRO',
                              value: '${_proItems.length}',
                              icon: Icons.workspace_premium_outlined,
                            ),
                          ),
                        ],
                      );
                    }

                    return Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildHeroStatCard(
                                title: 'Основные',
                                value: '${_mainItems.length}',
                                icon: Icons.dashboard_customize_outlined,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildHeroStatCard(
                                title: 'Игровая зона',
                                value: '${_gameZoneItems.length}',
                                icon: Icons.sports_esports_outlined,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _buildHeroStatCard(
                          title: 'PRO',
                          value: '${_proItems.length}',
                          icon: Icons.workspace_premium_outlined,
                        ),
                      ],
                    );
                  },
                ),
                if (isEditing) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: isSaving
                              ? null
                              : () {
                                  setState(() {
                                    isEditing = false;
                                    teamNameCtrl.text = teamName;
                                    teamCategoryCtrl.text = teamCategory;
                                    newLogoX = null;
                                    teamLogoFile = null;
                                  });
                                },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: Colors.white.withOpacity(0.35),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text('Отмена'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isSaving ? null : _updateTeamProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.primaryGreen,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Сохранить'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStatCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withOpacity(0.10),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 17,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.82),
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickTeamActions({
    EdgeInsetsGeometry margin = const EdgeInsets.fromLTRB(16, 0, 16, 14),
  }) {
    final actions = [
      {
        "title": "Состав",
        "subtitle": "Игроки и профили",
        "icon": Icons.groups_2_outlined,
        "color": const Color(0xFF2563EB),
        "onTap": () => _runItemTapById(_mainItems, "roster"),
      },
      {
        "title": "Календарь",
        "subtitle": "Матчи и тренировки",
        "icon": Icons.calendar_month_outlined,
        "color": const Color(0xFF16A34A),
        "onTap": () => _runItemTapById(_mainItems, "calendar"),
      },
      {
        "title": "Посещаемость",
        "subtitle": "Журнал команды",
        "icon": Icons.fact_check_outlined,
        "color": const Color(0xFF0891B2),
        "onTap": () => _runItemTapById(_mainItems, "attendance"),
      },
      {
        "title": "Матчи",
        "subtitle": "Результаты и список",
        "icon": Icons.sports_soccer_outlined,
        "color": const Color(0xFFEA580C),
        "onTap": () => _runItemTapById(_mainItems, "matches"),
      },
      {
        "title": "Менеджер",
        "subtitle": "Тактика и симуляция",
        "icon": Icons.psychology_alt_outlined,
        "color": const Color(0xFF7C3AED),
        "onTap": () => _runItemTapById(_mainItems, "manager_mode"),
      },
      {
        "title": "Планы",
        "subtitle": "Конспекты и база",
        "icon": Icons.menu_book_outlined,
        "color": const Color(0xFFE11D48),
        "onTap": () => _openProModule("plans"),
      },
    ];

    return _buildSectionShell(
      title: 'Быстрые действия',
      rightText: 'доступ',
      margin: margin,
      child: _QuickActionsGrid(actions: actions),
    );
  }

  Widget _buildTeamOverviewCards({
    EdgeInsetsGeometry margin = const EdgeInsets.fromLTRB(16, 0, 16, 14),
  }) {
    return _buildSectionShell(
      title: 'Обзор команды',
      rightText: 'live',
      margin: margin,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildOverviewMiniCard(
                  title: 'Клуб',
                  value: widget.clubName,
                  icon: Icons.shield_outlined,
                  color: const Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildOverviewMiniCard(
                  title: 'Категория',
                  value: teamCategory.isNotEmpty ? teamCategory : 'Не указана',
                  icon: Icons.category_outlined,
                  color: const Color(0xFF7C3AED),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildOverviewMiniCard(
                  title: 'Статус профиля',
                  value: profileLoading
                      ? 'Обновление'
                      : (profileError == null ? 'Активен' : 'Offline'),
                  icon: Icons.sync_outlined,
                  color: const Color(0xFFEA580C),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildOverviewMiniCard(
                  title: 'Тариф',
                  value: _subscription.isPremium ||
                          _subscription.features.isNotEmpty
                      ? 'PRO'
                      : 'Free',
                  icon: Icons.workspace_premium_outlined,
                  color: const Color(0xFFE11D48),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewMiniCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE7ECF2)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 18),
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
                    color: AppColors.textSecondary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionShell({
    required String title,
    String? rightText,
    required Widget child,
    EdgeInsetsGeometry margin = const EdgeInsets.fromLTRB(16, 0, 16, 14),
  }) {
    return Container(
      margin: margin,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            title: title,
            right: rightText ?? '',
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildMainModulesSection({
    EdgeInsetsGeometry margin = const EdgeInsets.fromLTRB(16, 0, 16, 14),
  }) {
    return _buildSectionShell(
      title: "Основные модули",
      rightText: "всего: ${_mainItems.length}",
      margin: margin,
      child: _ReorderableModulesWrap(
        items: _mainItems,
        teamId: widget.teamId,
        teamName: teamName,
        onReorder: _moveMainItem,
        editMode: _editMode,
        stylesMap: _mainStyles,
        onCustomize: (itemId) => _openModuleStyleSheet(
          sectionKey: "main",
          itemId: itemId,
        ),
      ),
    );
  }

  Widget _buildGameZoneSection({
    EdgeInsetsGeometry margin = const EdgeInsets.fromLTRB(16, 0, 16, 14),
  }) {
    return _buildSectionShell(
      title: "Игровая зона команды",
      rightText: "всего: ${_gameZoneItems.length}",
      margin: margin,
      child: _ReorderableModulesWrap(
        items: _gameZoneItems,
        teamId: widget.teamId,
        teamName: teamName,
        onReorder: _moveGameZoneItem,
        editMode: _editMode,
        stylesMap: const {},
      ),
    );
  }

  Widget _buildProModulesSection({
    EdgeInsetsGeometry margin = const EdgeInsets.fromLTRB(16, 0, 16, 14),
  }) {
    return _buildSectionShell(
      title: "Профессиональные инструменты",
      rightText: "всего: ${_proItems.length}",
      margin: margin,
      child: _ReorderableModulesWrap(
        items: _proItems,
        teamId: widget.teamId,
        teamName: teamName,
        onReorder: _moveProItem,
        editMode: _editMode,
        stylesMap: _proStyles,
        onCustomize: (itemId) => _openModuleStyleSheet(
          sectionKey: "pro",
          itemId: itemId,
        ),
        isPremiumChecker: _isPremiumTeamModule,
        featureMapper: _mapTeamModuleToFeature,
        hasFeatureChecker: (featureCode) {
          if (featureCode.isEmpty) return true;
          return _subscription.has(featureCode);
        },
      ),
    );
  }

  Widget _buildDangerSection({
    EdgeInsetsGeometry margin = const EdgeInsets.fromLTRB(16, 0, 16, 14),
  }) {
    return _buildSectionShell(
      title: "Опасная зона",
      rightText: '',
      margin: margin,
      child: _UnsafeDeleteCard(
        isDeleting: isDeleting,
        onDelete: _deleteTeam,
      ),
    );
  }

List<Widget> _buildResponsiveContent(double width) {
  final isHugeTablet = width >= 1360;
  final isWideTablet = width >= 1040;
  final isTablet = width >= 760;

  if (isHugeTablet) {
    return [
      _buildTeamHeroCard(),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 9,
              child: Column(
                children: [
                  _buildQuickTeamActions(
                    margin: const EdgeInsets.only(bottom: 12),
                  ),
                  _buildMainModulesSection(
                    margin: const EdgeInsets.only(bottom: 12),
                  ),
                  _buildProModulesSection(
                    margin: const EdgeInsets.only(bottom: 12),
                  ),
                  _buildGameZoneSection(
                    margin: const EdgeInsets.only(bottom: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 4,
              child: Column(
                children: [
                  _buildTeamOverviewCards(
                    margin: const EdgeInsets.only(bottom: 12),
                  ),
                  _buildDangerSection(
                    margin: const EdgeInsets.only(bottom: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 72),
    ];
  }

  if (isWideTablet) {
    return [
      _buildTeamHeroCard(),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 7,
              child: Column(
                children: [
                  _buildQuickTeamActions(
                    margin: const EdgeInsets.only(bottom: 12),
                  ),
                  _buildMainModulesSection(
                    margin: const EdgeInsets.only(bottom: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 4,
              child: Column(
                children: [
                  _buildTeamOverviewCards(
                    margin: const EdgeInsets.only(bottom: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      _buildProModulesSection(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      ),
      _buildGameZoneSection(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      ),
      _buildDangerSection(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      ),
      const SizedBox(height: 72),
    ];
  }

  if (isTablet) {
    return [
      _buildTeamHeroCard(),
      _buildQuickTeamActions(),
      _buildTeamOverviewCards(),
      _buildMainModulesSection(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      ),
      _buildProModulesSection(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      ),
      _buildGameZoneSection(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      ),
      _buildDangerSection(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      ),
      const SizedBox(height: 72),
    ];
  }

  return [
    _buildTeamHeroCard(),
    _buildQuickTeamActions(),
    _buildTeamOverviewCards(),
    _buildMainModulesSection(),
    _buildProModulesSection(),
    _buildGameZoneSection(),
    _buildDangerSection(),
    const SizedBox(height: 90),
  ];
}

  @override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: _teamDashboardBgColor,
    appBar: AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      iconTheme: const IconThemeData(color: AppColors.textPrimary),
      title: Text(
        teamName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          color: AppColors.textPrimary,
        ),
      ),
      actions: [
        IconButton(
          tooltip: "Фон панели",
          onPressed: _openDashboardBgPicker,
          icon: const Icon(
            Icons.format_color_fill_outlined,
            color: AppColors.textPrimary,
          ),
        ),
        IconButton(
          tooltip: _editMode ? "Готово" : "Редактировать модули",
          onPressed: () {
            setState(() {
              _editMode = !_editMode;
            });
          },
          icon: Icon(
            _editMode ? Icons.check : Icons.edit_outlined,
            color: AppColors.textPrimary,
          ),
        ),
        IconButton(
          tooltip: "Обновить профиль",
          onPressed: _refreshAll,
          icon: const Icon(
            Icons.refresh_rounded,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 6),
      ],
    ),
    body: _loadingModuleOrder
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _refreshAll,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;

                final maxWidth = width >= 1700
                    ? 1600.0
                    : width >= 1460
                        ? 1500.0
                        : width >= 1240
                            ? 1420.0
                            : width;

                return Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: const EdgeInsets.fromLTRB(0, 0, 0, 20),
                      children: _buildResponsiveContent(maxWidth),
                    ),
                  ),
                );
              },
            ),
          ),
  );
}
}

class _QuickActionsGrid extends StatelessWidget {
  final List<Map<String, dynamic>> actions;

  const _QuickActionsGrid({
    super.key,
    required this.actions,
  });

  int _columnsForWidth(double width) {
    if (width >= 1500) return 7;
    if (width >= 1240) return 6;
    if (width >= 980) return 5;
    if (width >= 760) return 4;
    if (width >= 520) return 3;
    if (width >= 340) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = _columnsForWidth(width);
        final spacing = width >= 980 ? 8.0 : 10.0;

        final itemWidth = columns == 1
            ? width
            : (width - spacing * (columns - 1)) / columns;

        final compact = columns >= 5;
        final veryCompact = columns >= 6;

        final cardHeight = veryCompact
            ? 84.0
            : compact
                ? 90.0
                : 102.0;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: actions.map((item) {
            return SizedBox(
              width: itemWidth,
              child: _QuickActionGridCard(
                title: item["title"] as String,
                subtitle: item["subtitle"] as String,
                icon: item["icon"] as IconData,
                color: item["color"] as Color,
                height: cardHeight,
                onTap: item["onTap"] as VoidCallback,
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _QuickActionGridCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final double height;
  final VoidCallback onTap;

  const _QuickActionGridCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.height,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final compact = height <= 90;
    final veryCompact = height <= 84;
    final iconBox = veryCompact ? 32.0 : (compact ? 34.0 : 40.0);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: height,
        padding: EdgeInsets.all(veryCompact ? 10 : (compact ? 11 : 13)),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE7ECF2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: iconBox,
                  height: iconBox,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: veryCompact ? 16 : (compact ? 17 : 20),
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_outward_rounded,
                  size: veryCompact ? 14 : 16,
                  color: AppColors.textSecondary.withOpacity(0.7),
                ),
              ],
            ),
            const Spacer(),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w900,
                fontSize: veryCompact ? 11.0 : (compact ? 11.5 : 13.0),
                height: 1.0,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              maxLines: veryCompact ? 1 : 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: veryCompact ? 9.2 : (compact ? 9.8 : 11.0),
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReorderableModulesWrap extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final int teamId;
  final String teamName;
  final void Function(int oldIndex, int newIndex) onReorder;
  final bool editMode;
  final Map<String, dynamic> stylesMap;
  final void Function(String itemId)? onCustomize;

  final bool Function(String itemId)? isPremiumChecker;
  final bool Function(String featureCode)? hasFeatureChecker;
  final String Function(String itemId)? featureMapper;

  const _ReorderableModulesWrap({
    required this.items,
    required this.teamId,
    required this.teamName,
    required this.onReorder,
    required this.editMode,
    required this.stylesMap,
    this.onCustomize,
    this.isPremiumChecker,
    this.hasFeatureChecker,
    this.featureMapper,
  });

  @override
  State<_ReorderableModulesWrap> createState() => _ReorderableModulesWrapState();
}

class _ReorderableModulesWrapState extends State<_ReorderableModulesWrap> {
  int? _draggingIndex;
  int? _hoverIndex;

  int _columnsForWidth(double width) {
  if (width >= 1500) return 7;
  if (width >= 1240) return 6;
  if (width >= 980) return 5;
  if (width >= 760) return 4;
  if (width >= 520) return 3;
  if (width >= 340) return 2;
  return 1;
}
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = _columnsForWidth(width);
       final spacing = width >= 980 ? 8.0 : 10.0;
        final itemWidth = columns == 1
            ? width
            : (width - spacing * (columns - 1)) / columns;

final tablet = width >= 760;
final compact = columns >= 5;
final veryCompact = columns >= 6;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: List.generate(widget.items.length, (index) {
            final item = widget.items[index];
            final itemId = (item["id"] ?? "").toString();
            final isDragging = _draggingIndex == index;
            final isHover = _hoverIndex == index && _draggingIndex != index;

            final isPremium = widget.isPremiumChecker?.call(itemId) ?? false;
            final featureCode = widget.featureMapper?.call(itemId) ?? '';
            final hasFeature =
                widget.hasFeatureChecker?.call(featureCode) ?? true;
            final isProLocked = isPremium && !hasFeature;

            return DragTarget<int>(
              onWillAcceptWithDetails: (details) {
                if (!widget.editMode) return false;
                final accept = details.data != index;
                if (accept && mounted) {
                  setState(() {
                    _hoverIndex = index;
                  });
                }
                return accept;
              },
              onLeave: (_) {
                if (_hoverIndex == index && mounted) {
                  setState(() {
                    _hoverIndex = null;
                  });
                }
              },
              onAcceptWithDetails: (details) {
                if (!widget.editMode) return;

                final from = details.data;
                final to = index;

                if (mounted) {
                  setState(() {
                    _hoverIndex = null;
                    _draggingIndex = null;
                  });
                }

                widget.onReorder(from, to);
              },
              builder: (context, candidateData, rejectedData) {
                final tile = _ModuleTile(
                  item: item,
                  teamId: widget.teamId,
                  teamName: widget.teamName,
                  tablet: tablet,
                  compact: compact,
                  veryCompact: veryCompact,
                  showDragHandle: widget.editMode,
                  styleData: widget.stylesMap[itemId],
                  onCustomize: widget.editMode && widget.onCustomize != null
                      ? () => widget.onCustomize!(itemId)
                      : null,
                  isProLocked: isProLocked,
                  tapEnabled: !widget.editMode,
                );

                return SizedBox(
                  width: itemWidth,
                  child: widget.editMode
                      ? LongPressDraggable<int>(
                          data: index,
                          dragAnchorStrategy: pointerDragAnchorStrategy,
                          onDragStarted: () {
                            if (!mounted) return;
                            setState(() {
                              _draggingIndex = index;
                            });
                          },
                          onDraggableCanceled: (_, __) {
                            if (!mounted) return;
                            setState(() {
                              _draggingIndex = null;
                              _hoverIndex = null;
                            });
                          },
                          onDragEnd: (_) {
                            if (!mounted) return;
                            setState(() {
                              _draggingIndex = null;
                              _hoverIndex = null;
                            });
                          },
                          feedback: Material(
                            color: Colors.transparent,
                            child: SizedBox(
                              width: itemWidth,
                              child: Opacity(
                                opacity: 0.94,
                                child: Transform.scale(
                                  scale: 1.02,
                                  child: tile,
                                ),
                              ),
                            ),
                          ),
                          childWhenDragging: _ModulePlaceholder(
                            tablet: tablet,
                            compact: compact,
                            veryCompact: veryCompact,
                          ),
                          child: AnimatedScale(
                            duration: const Duration(milliseconds: 140),
                            scale: isHover ? 1.01 : 1.0,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 140),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(
                                  compact ? 16 : 18,
                                ),
                                border: isHover
                                    ? Border.all(
                                        color: AppColors.primaryGreen
                                            .withOpacity(0.55),
                                        width: 1.4,
                                      )
                                    : null,
                              ),
                              child: Opacity(
                                opacity: isDragging ? 0.65 : 1,
                                child: tile,
                              ),
                            ),
                          ),
                        )
                      : tile,
                );
              },
            );
          }),
        );
      },
    );
  }
}

class _ModuleTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final int teamId;
  final String teamName;
  final bool tablet;
  final bool compact;
  final bool veryCompact;
  final bool showDragHandle;
  final dynamic styleData;
  final VoidCallback? onCustomize;
  final bool isProLocked;
  final bool tapEnabled;

  const _ModuleTile({
    required this.item,
    required this.teamId,
    required this.teamName,
    required this.tablet,
    required this.compact,
    required this.veryCompact,
    this.showDragHandle = false,
    this.styleData,
    this.onCustomize,
    this.isProLocked = false,
    this.tapEnabled = true,
  });

  Color _colorFromHex(String hex) {
    final buffer = StringBuffer();
    String value = hex.replaceAll('#', '');
    if (value.length == 6) buffer.write('ff');
    buffer.write(value);
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final theme = (item["theme"] as ModuleTheme?) ?? ModuleThemes.basic;
    final title = (item["t"] ?? "").toString();
    final subtitle = (item["s"] ?? "").toString();
    final icon = (item["i"] as IconData?) ?? Icons.widgets_outlined;

    final Map<String, dynamic> s = styleData is Map<String, dynamic>
        ? styleData as Map<String, dynamic>
        : (styleData is Map ? Map<String, dynamic>.from(styleData) : {});

    final bgColor =
        s["bgColor"] != null ? _colorFromHex(s["bgColor"]) : AppColors.card;

    final titleColor = s["titleColor"] != null
        ? _colorFromHex(s["titleColor"])
        : AppColors.textPrimary;

    final subtitleColor = s["subtitleColor"] != null
        ? _colorFromHex(s["subtitleColor"])
        : AppColors.textSecondary;

    final iconColor = s["iconColor"] != null
        ? _colorFromHex(s["iconColor"])
        : theme.iconColor;

    final cardHeight = veryCompact
        ? 84.0
        : compact
            ? 90.0
            : 102.0;

    final padding = veryCompact ? 10.0 : (compact ? 11.0 : 13.0);
    final iconBox = veryCompact ? 32.0 : (compact ? 34.0 : 40.0);
    final radius = 16.0;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: !tapEnabled
            ? null
            : () {
                final fn = item["onTap"];
                if (fn is Function) {
                  fn(context, teamId, teamName);
                }
              },
        child: Container(
          height: cardHeight,
          padding: EdgeInsets.all(padding),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: const Color(0xFFE7ECF2)),
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: iconBox,
                        height: iconBox,
                        decoration: BoxDecoration(
                          color: iconColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          icon,
                          color: iconColor,
                          size: veryCompact ? 16 : (compact ? 17 : 20),
                        ),
                      ),
                      const Spacer(),
                      if (showDragHandle)
                        Icon(
                          Icons.drag_indicator_rounded,
                          size: veryCompact ? 14 : 16,
                          color: AppColors.textSecondary.withOpacity(0.7),
                        )
                      else
                        Icon(
                          Icons.arrow_outward_rounded,
                          size: veryCompact ? 14 : 16,
                          color: titleColor.withOpacity(0.7),
                        ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: titleColor,
                      fontWeight: FontWeight.w900,
                      fontSize: veryCompact ? 11.0 : (compact ? 11.5 : 13.0),
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: veryCompact ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: subtitleColor,
                      fontWeight: FontWeight.w600,
                      fontSize: veryCompact ? 9.2 : (compact ? 9.8 : 11.0),
                      height: 1.1,
                    ),
                  ),
                ],
              ),
              if (isProLocked)
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'PRO',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              if (onCustomize != null)
                Positioned(
                  top: 0,
                  right: showDragHandle ? 22 : 0,
                  child: InkWell(
                    onTap: onCustomize,
                    borderRadius: BorderRadius.circular(9),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: const Color(0xFFE7ECF2)),
                      ),
                      child: const Icon(
                        Icons.palette_outlined,
                        size: 14,
                        color: AppColors.textPrimary,
                      ),
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

class _ModulePlaceholder extends StatelessWidget {
  final bool tablet;
  final bool compact;
  final bool veryCompact;

  const _ModulePlaceholder({
    required this.tablet,
    required this.compact,
    required this.veryCompact,
  });

  @override
  Widget build(BuildContext context) {
    final cardHeight = veryCompact
        ? 84.0
        : compact
            ? 90.0
            : 102.0;

    return Container(
      height: cardHeight,
      decoration: BoxDecoration(
        color: AppColors.white.withOpacity(0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.textTertiary.withOpacity(0.22),
          width: 1.2,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String right;

  const _SectionTitle({
    required this.title,
    required this.right,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        if (right.isNotEmpty)
          Text(
            right,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
      ],
    );
  }
}

class _UnsafeDeleteCard extends StatelessWidget {
  final bool isDeleting;
  final VoidCallback onDelete;

  const _UnsafeDeleteCard({
    required this.isDeleting,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Container(
      padding: EdgeInsets.all(isTablet ? 16 : 14),
      decoration: BoxDecoration(
        color: ModuleThemes.danger.color,
        borderRadius: BorderRadius.circular(isTablet ? 20 : 18),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: isTablet ? 24 : 22,
                color: ModuleThemes.danger.iconColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Удаление команды",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: isTablet ? 16 : 14,
                    color: ModuleThemes.danger.iconColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Команда будет удалена без возможности восстановления.\n"
            "Для подтверждения нужно ввести слово «Удалить» в диалоге.",
            style: TextStyle(
              fontSize: isTablet ? 13 : 12,
              height: 1.25,
              color: ModuleThemes.danger.iconColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: isDeleting ? null : onDelete,
              icon: isDeleting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      Icons.delete_outline,
                      size: isTablet ? 20 : 18,
                      color: ModuleThemes.danger.iconColor,
                    ),
              label: Text(
                "Удалить команду",
                style: TextStyle(
                  fontSize: isTablet ? 15 : 13,
                  color: ModuleThemes.danger.iconColor,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: ModuleThemes.danger.iconColor,
                side: BorderSide(
                  color: ModuleThemes.danger.iconColor.withOpacity(0.3),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(isTablet ? 16 : 14),
                ),
                padding: EdgeInsets.symmetric(vertical: isTablet ? 14 : 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ModuleTheme {
  final Color color;
  final Color iconColor;

  const ModuleTheme({
    required this.color,
    required this.iconColor,
  });
}

class ModuleThemes {
  static const basic = ModuleTheme(
    color: Color(0xFFF3F4F6),
    iconColor: AppColors.textPrimary,
  );

  static const calendar = ModuleTheme(
    color: Color(0xFFEFF6FF),
    iconColor: Color(0xFF2563EB),
  );

  static const attendance = ModuleTheme(
    color: Color(0xFFF0FDF4),
    iconColor: Color(0xFF16A34A),
  );

  static const chat = ModuleTheme(
    color: Color(0xFFFFF7ED),
    iconColor: Color(0xFFEA580C),
  );

  static const editor = ModuleTheme(
    color: Color(0xFFF5F3FF),
    iconColor: Color(0xFF7C3AED),
  );

  static const plans = ModuleTheme(
    color: Color(0xFFFDF2F8),
    iconColor: Color(0xFFDB2777),
  );

  static const video = ModuleTheme(
    color: Color(0xFFFEE2E2),
    iconColor: Color(0xFFDC2626),
  );

  static const analytics = ModuleTheme(
    color: Color(0xFFECFEFF),
    iconColor: Color(0xFF0891B2),
  );

  static const news = ModuleTheme(
    color: Color(0xFFFAFAF9),
    iconColor: Color(0xFF0F172A),
  );

  static const challenge = ModuleTheme(
    color: Color(0xFFEAFBF1),
    iconColor: Color(0xFF16A34A),
  );

  static const quiz = ModuleTheme(
    color: Color(0xFFF6EEFF),
    iconColor: Color(0xFF7C3AED),
  );

  static const battle = ModuleTheme(
    color: Color(0xFFFFEAEA),
    iconColor: Color(0xFFDC2626),
  );

  static const rating = ModuleTheme(
    color: Color(0xFFFFF7D6),
    iconColor: Color(0xFFEAB308),
  );

  static const matchGames = ModuleTheme(
    color: Color(0xFFEAF2FF),
    iconColor: Color(0xFF2563EB),
  );

  static const danger = ModuleTheme(
    color: Color(0xFFFFEBEE),
    iconColor: Color(0xFFB91C1C),
  );
}
 
