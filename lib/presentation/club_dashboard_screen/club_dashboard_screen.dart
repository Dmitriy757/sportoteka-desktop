import 'dart:convert';
import 'dart:io';
import 'package:get/get.dart';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import 'package:sportoteka/core/subscription/premium_bottom_sheet.dart';
import 'package:sportoteka/core/subscription/subscription_access.dart';
import 'package:sportoteka/core/subscription/subscription_service.dart';
import 'package:sportoteka/core/utils/media_utils.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/presentation/club_attendance/attendance_screen.dart';
import 'package:sportoteka/presentation/club_calendar_screen/club_calendar_screen.dart';
import 'package:sportoteka/presentation/club_trainers/team_trainers_screen.dart';
import 'package:sportoteka/presentation/plans/plan_folders_screen.dart';
import 'package:sportoteka/presentation/team_screen/team_dashboard_screen.dart';

class ClubDashboardPalette {
  static const primaryGreen = Color(0xFF00A750);
  static const primaryGreenDark = Color(0xFF008C40);
  static const primaryGreenLight = Color(0xFF00C060);
  static const accentGreen = Color(0xFF7ED321);
  static const lightGreen = Color(0xFFE8F5E9);

  static const white = Color(0xFFFFFFFF);
  static const text = Color(0xFF0F172A);
  static const textMuted = Color(0xFF64748B);
  static const textLight = Color(0xFF94A3B8);
  static const background = Color(0xFFF6F8FB);
  static const card = Color(0xFFFFFFFF);
  static const border = Color(0xFFE5E7EB);
  static const surface = Color(0xFFF8FAFC);

  static const blue = Color(0xFF2563EB);
  static const purple = Color(0xFF7C3AED);
  static const orange = Color(0xFFEA580C);
  static const cyan = Color(0xFF0891B2);
  static const rose = Color(0xFFE11D48);

  static const greenGradient = LinearGradient(
    colors: [primaryGreen, primaryGreenDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const heroGradient = LinearGradient(
    colors: [
      Color(0xFF081A12),
      Color(0xFF0A5B36),
      Color(0xFF00A750),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

enum ClubModuleType {
  clubInfo,
  trainers,
  calendar,
  attendance,
  clubChat,
  trainingEditor,
  plansBase,
  videoAnalysis,
  heatmap,
  clubNews,
}

class ClubDashboardScreen extends StatefulWidget {
  const ClubDashboardScreen({super.key});

  @override
  State<ClubDashboardScreen> createState() => _ClubDashboardScreenState();
}

class _ClubDashboardScreenState extends State<ClubDashboardScreen>
    with SingleTickerProviderStateMixin {
  static const String apiBase = 'https://sportotekaapp.ru/api';

  static const String getClubTeamsUrl = '$apiBase/get_club_teams.php';
  static const String getClubTrainersUrl = '$apiBase/get_club_trainers.php';
  static const String getClubEventsUrl = '$apiBase/get_club_events.php';
  static const String createTeamUrl = '$apiBase/club_create_team.php';
  static const String getClubProfileUrl = '$apiBase/get_club_profile.php';
  static const String updateClubProfileUrl = '$apiBase/update_club_profile.php';
  static const String getTrainingPlansUrl = '$apiBase/get_training_plans.php';
  static const String linkEventPlanUrl = '$apiBase/link_event_plan.php';
  static const String searchTrainerByEmailUrl =
      '$apiBase/search_trainer_by_email.php';

  static const String getUserClubPrefsUrl =
      '$apiBase/get_user_club_dashboard_prefs.php';
  static const String saveUserClubPrefsUrl =
      '$apiBase/save_user_club_dashboard_prefs.php';

  int clubId = 0;
  bool loading = true;
  String? error;

  List<dynamic> teams = [];
  List<dynamic> trainers = [];
  List<dynamic> events = [];
  List<dynamic> plans = [];

  int? selectedTeamId;
  String selectedTeamName = 'Выберите команду';

  SubscriptionAccess _subscription = SubscriptionAccess.free();

  bool _editLayoutMode = false;
  Color _dashboardBgColor = ClubDashboardPalette.background;

  List<Map<String, dynamic>> _moduleItems = [];
  Map<String, dynamic> _moduleStyles = {};

  Map<int, dynamic> _teamStyles = {};
  List<dynamic> _orderedTeams = [];

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
    Color(0xFFFF6B6B),
    Color(0xFF00B8D4),
    Color(0xFF222222),
    Color(0xFF666666),
  ];

  String clubName = 'Название клуба';
  String? clubLogoPath;
  File? clubLogoFile;
  bool isEditingClubInfo = false;
  final TextEditingController clubNameController = TextEditingController();
  final TextEditingController clubDescriptionController =
      TextEditingController();
  XFile? newLogoFile;

  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();

    _moduleItems = List<Map<String, dynamic>>.from(_clubModuleBanners());
    _boot();
  }

  @override
  void dispose() {
    _animationController.dispose();
    clubNameController.dispose();
    clubDescriptionController.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    clubId = await PrefUtils.getUserId() ?? 0;
    await _reloadAll();
  }

  Future<void> _reloadAll() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      await Future.wait([
        _loadTeams(),
        _loadTrainers(),
        _loadEvents(),
        _loadPlansSafe(),
        _loadClubProfile(),
      ]);

      _subscription = await SubscriptionService.getUserSubscription(
        userId: clubId,
        role: 'club',
      );

      await _loadUserPrefs();

      if (_orderedTeams.isEmpty) {
        _orderedTeams = List<dynamic>.from(teams);
      }

      if (selectedTeamId == null && _orderedTeams.isNotEmpty) {
        final t0 = _orderedTeams.first as Map<String, dynamic>;
        selectedTeamId = _asInt(t0['id']);
        selectedTeamName = _asString(t0['name']) ?? 'Команда';
      }

      if (mounted) {
        setState(() => loading = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'Ошибка загрузки данных клуба.';
      });
    }
  }

  Future<void> _loadClubProfile() async {
    try {
      final resp = await http.post(
        Uri.parse(getClubProfileUrl),
        body: {'club_id': clubId.toString()},
      );

      final data = _decode(resp);

      if (!mounted) return;

      setState(() {
        if (data['success'] == true && data['club'] is Map) {
          final clubData = data['club'] as Map<String, dynamic>;

          clubName =
              _asString(clubData['club_name'])?.trim() ?? 'Название клуба';

          final normalized =
              MediaUtils.normalizeUrl(_asString(clubData['photo']));
          clubLogoPath = _cacheBust(normalized);
          clubLogoFile = null;

          clubNameController.text = clubName;
          clubDescriptionController.text =
              _asString(clubData['club_description']) ?? '';
        } else {
          clubName = 'Название клуба';
          clubNameController.text = clubName;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        clubName = 'Название клуба';
        clubNameController.text = clubName;
      });
    }
  }

  Future<void> _updateClubProfile() async {
    if (clubNameController.text.trim().isEmpty) {
      Get.snackbar('Ошибка', 'Введите название клуба');
      return;
    }

    Get.snackbar('Обновление', 'Сохраняем изменения...');

    try {
      final uri = Uri.parse(updateClubProfileUrl);
      final req = http.MultipartRequest('POST', uri);

      req.fields['club_id'] = clubId.toString();
      req.fields['club_name'] = clubNameController.text.trim();
      req.fields['club_description'] = clubDescriptionController.text.trim();

      final picked = newLogoFile;

      if (picked != null) {
        req.files.add(
          await http.MultipartFile.fromPath('club_logo', picked.path),
        );
      }

      final streamed = await req.send();
      final resp = await http.Response.fromStream(streamed);
      final data = _decode(resp);

      if (data['success'] == true) {
        Get.snackbar('Готово', 'Данные клуба обновлены');

        if (!mounted) return;
        setState(() {
          clubName = clubNameController.text.trim();

          final clubMap = data['club'] is Map
              ? Map<String, dynamic>.from(data['club'])
              : null;

          final newPhoto = clubMap?['photo']?.toString();
          final normalized = MediaUtils.normalizeUrl(newPhoto);

          if (normalized != null && normalized.isNotEmpty) {
            clubLogoPath = normalized;
          }

          if (picked != null) {
            clubLogoFile = File(picked.path);
          }

          isEditingClubInfo = false;
          newLogoFile = null;
        });
      } else {
        Get.snackbar(
          'Ошибка',
          _asString(data['message']) ?? 'Не удалось обновить профиль',
        );
      }
    } catch (e) {
      Get.snackbar('Сеть', 'Ошибка соединения: $e');
    }
  }

  Future<void> _loadTeams() async {
    final resp = await http.post(
      Uri.parse(getClubTeamsUrl),
      body: {'club_id': clubId.toString()},
    );

    final data = _decode(resp);

    if (data['success'] == true) {
      teams = (data['teams'] as List?) ?? [];
    } else {
      teams = [];
    }
  }

  Future<void> _loadTrainers() async {
    final resp = await http.post(
      Uri.parse(getClubTrainersUrl),
      body: {'club_id': clubId.toString()},
    );

    final data = _decode(resp);

    if (data['success'] == true) {
      trainers = (data['trainers'] as List?) ?? [];
    } else {
      trainers = [];
    }
  }

  Future<void> _loadEvents() async {
    final resp = await http.post(
      Uri.parse(getClubEventsUrl),
      body: {'club_id': clubId.toString()},
    );

    final data = _decode(resp);

    if (data['success'] == true) {
      events = (data['events'] as List?) ?? [];
    } else {
      events = [];
    }
  }

  Future<void> _loadPlansSafe() async {
    try {
      final resp = await http.post(
        Uri.parse(getTrainingPlansUrl),
        body: {'club_id': clubId.toString()},
      );

      final data = _decode(resp);

      if (data['success'] == true) {
        plans = (data['plans'] as List?) ?? [];
      } else {
        plans = [];
      }
    } catch (_) {
      plans = [];
    }
  }

  Future<void> _loadUserPrefs() async {
    try {
      final resp = await http.post(
        Uri.parse(getUserClubPrefsUrl),
        body: {
          'user_id': clubId.toString(),
          'club_id': clubId.toString(),
        },
      );

      final data = _decode(resp);

      if (data['success'] == true && data['prefs'] != null) {
        final prefs = Map<String, dynamic>.from(data['prefs']);

        final bgColorHex = _asString(prefs['bg_color']);
        if (bgColorHex != null && bgColorHex.isNotEmpty) {
          _dashboardBgColor = _colorFromHex(bgColorHex);
        } else {
          _dashboardBgColor = ClubDashboardPalette.background;
        }

        final currentModules =
            List<Map<String, dynamic>>.from(_clubModuleBanners());

        final moduleOrderRaw = _asString(prefs['module_order']);
        if (moduleOrderRaw != null && moduleOrderRaw.isNotEmpty) {
          final ids = List<String>.from(json.decode(moduleOrderRaw));
          _moduleItems = [];

          for (final id in ids) {
            for (final item in currentModules) {
              if (item['type'].toString() == id) {
                _moduleItems.add(item);
                break;
              }
            }
          }

          for (final item in currentModules) {
            final exists =
                _moduleItems.any((e) => e['type'] == item['type']);
            if (!exists) _moduleItems.add(item);
          }
        } else {
          _moduleItems = currentModules;
        }

        final moduleStylesRaw = _asString(prefs['module_styles']);
        if (moduleStylesRaw != null && moduleStylesRaw.isNotEmpty) {
          _moduleStyles =
              Map<String, dynamic>.from(json.decode(moduleStylesRaw));
        } else {
          _moduleStyles = {};
        }

        final teamOrderRaw = _asString(prefs['team_order']);
        if (teamOrderRaw != null && teamOrderRaw.isNotEmpty) {
          final ids = List<int>.from(json.decode(teamOrderRaw));
          _orderedTeams = _sortByIdList(teams, ids);
        } else {
          _orderedTeams = List<dynamic>.from(teams);
        }

        final teamStylesRaw = _asString(prefs['team_styles']);
        if (teamStylesRaw != null && teamStylesRaw.isNotEmpty) {
          final raw = Map<String, dynamic>.from(json.decode(teamStylesRaw));
          _teamStyles = raw.map((k, v) => MapEntry(int.tryParse(k) ?? 0, v));
        } else {
          _teamStyles = {};
        }
      } else {
        _orderedTeams = List<dynamic>.from(teams);
        _moduleItems = List<Map<String, dynamic>>.from(_clubModuleBanners());
        _moduleStyles = {};
        _teamStyles = {};
        _dashboardBgColor = ClubDashboardPalette.background;
      }
    } catch (_) {
      _orderedTeams = List<dynamic>.from(teams);
      _moduleItems = List<Map<String, dynamic>>.from(_clubModuleBanners());
      _moduleStyles = {};
      _teamStyles = {};
      _dashboardBgColor = ClubDashboardPalette.background;
    }
  }

  Future<void> _saveUserPrefs() async {
    try {
      final moduleOrder =
          _moduleItems.map((e) => e['type'].toString()).toList();

      final teamOrder = _orderedTeams
          .map((e) => _asInt((e as Map<String, dynamic>)['id']))
          .toList();

      await http.post(
        Uri.parse(saveUserClubPrefsUrl),
        body: {
          'user_id': clubId.toString(),
          'club_id': clubId.toString(),
          'bg_color': _colorToHex(_dashboardBgColor),
          'module_order': json.encode(moduleOrder),
          'module_styles': json.encode(_moduleStyles),
          'team_order': json.encode(teamOrder),
          'team_styles': json.encode(
            _teamStyles.map((k, v) => MapEntry(k.toString(), v)),
          ),
          'folder_order': json.encode([]),
          'folder_styles': json.encode({}),
        },
      );
    } catch (_) {}
  }

  Future<bool> _ensureFeature(
    String featureCode, {
    required String title,
    required String description,
  }) async {
    if (_subscription.has(featureCode)) return true;

    final activated = await showPremiumBottomSheet(
      context,
      title: title,
      description: description,
    );

    if (activated) {
      try {
        _subscription = await SubscriptionService.getUserSubscription(
          userId: clubId,
          role: 'club',
        );

        if (mounted) {
          setState(() {});
        }
      } catch (_) {}
    }

    return _subscription.has(featureCode);
  }

  String _mapClubModuleToFeature(ClubModuleType type) {
    switch (type) {
      case ClubModuleType.trainingEditor:
        return 'club_training_editor';
      case ClubModuleType.videoAnalysis:
        return 'club_video_analysis';
      case ClubModuleType.plansBase:
        return 'club_plans';
      case ClubModuleType.heatmap:
        return 'club_heatmap';
      default:
        return '';
    }
  }

  bool _isPremiumClubModule(ClubModuleType type) {
    return type == ClubModuleType.trainingEditor ||
        type == ClubModuleType.videoAnalysis ||
        type == ClubModuleType.plansBase ||
        type == ClubModuleType.heatmap;
  }

  void _openModule(ClubModuleType type) async {
    if (type == ClubModuleType.trainingEditor) {
      final ok = await _ensureFeature(
        'club_training_editor',
        title: 'Графический редактор',
        description:
            'Профессиональный графический редактор доступен только по подписке клуба.',
      );
      if (!ok) return;
    }

    if (type == ClubModuleType.videoAnalysis) {
      final ok = await _ensureFeature(
        'club_video_analysis',
        title: 'Видеоанализ',
        description:
            'Инструменты видеоанализа доступны только по платному тарифу.',
      );
      if (!ok) return;
    }

    if (type == ClubModuleType.plansBase) {
      final ok = await _ensureFeature(
        'club_plans',
        title: 'Планы и конспекты',
        description:
            'База планов и конспектов доступна только по подписке клуба.',
      );
      if (!ok) return;

      final tid = selectedTeamId ?? 0;
      if (tid <= 0) {
        Get.snackbar('Команда', 'Сначала выберите команду');
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlanFoldersScreen(
            clubId: clubId,
            clubName: clubName,
            teamId: tid,
          ),
        ),
      );
      return;
    }

    if (type == ClubModuleType.heatmap) {
      final ok = await _ensureFeature(
        'club_heatmap',
        title: 'Heatmap',
        description:
            'Тепловые карты и аналитика доступны только на PRO-тарифе.',
      );
      if (!ok) return;
    }

    if (type == ClubModuleType.trainers) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TeamTrainersScreen(
            clubId: clubId,
            clubName: clubName,
            teams: teams,
          ),
        ),
      );
      return;
    }

    if (type == ClubModuleType.calendar) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ClubCalendarScreen(
            clubId: clubId,
            clubName: clubName,
            teams: teams,
          ),
        ),
      );
      return;
    }

    if (type == ClubModuleType.attendance) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AttendanceScreen(
            clubId: clubId,
            clubName: clubName,
            teams: teams,
          ),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClubModuleScreen(
          clubId: clubId,
          type: type,
          loadBundle: _loadAllClubBundle,
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _clubModuleBanners() {
    return [
      {
        'type': ClubModuleType.clubInfo,
        'title': 'Профиль клуба',
        'subtitle': 'Описание, адрес, команды',
        'icon': Icons.shield_outlined,
        'color': ClubDashboardPalette.lightGreen,
        'iconColor': ClubDashboardPalette.primaryGreen,
      },
      {
        'type': ClubModuleType.trainers,
        'title': 'Тренеры',
        'subtitle': 'Список тренеров клуба',
        'icon': Icons.people_outline,
        'color': const Color(0xFFE8F2FF),
        'iconColor': const Color(0xFF0066CC),
      },
      {
        'type': ClubModuleType.calendar,
        'title': 'Календарь',
        'subtitle': 'События всех команд',
        'icon': Icons.calendar_month_outlined,
        'color': const Color(0xFFE8F8E8),
        'iconColor': ClubDashboardPalette.primaryGreen,
      },
      {
        'type': ClubModuleType.attendance,
        'title': 'Посещаемость',
        'subtitle': 'Журнал отметок',
        'icon': Icons.fact_check_outlined,
        'color': const Color(0xFFE6F7FF),
        'iconColor': const Color(0xFF007AFF),
      },
      {
        'type': ClubModuleType.clubChat,
        'title': 'Чат клуба',
        'subtitle': 'Тренеры + админ',
        'icon': Icons.forum_outlined,
        'color': const Color(0xFFF0F2FF),
        'iconColor': const Color(0xFF7E3AED),
      },
      {
        'type': ClubModuleType.plansBase,
        'title': 'Планы',
        'subtitle': 'Конспекты и шаблоны',
        'icon': Icons.menu_book_outlined,
        'color': const Color(0xFFFFF4E6),
        'iconColor': const Color(0xFFFF9500),
      },
      {
        'type': ClubModuleType.trainingEditor,
        'title': 'Редактор',
        'subtitle': 'Схемы и упражнения',
        'icon': Icons.draw_outlined,
        'color': const Color(0xFFF3E8FF),
        'iconColor': const Color(0xFF7E3AED),
      },
      {
        'type': ClubModuleType.videoAnalysis,
        'title': 'Видеоанализ',
        'subtitle': 'Разбор матчей',
        'icon': Icons.video_camera_back_outlined,
        'color': const Color(0xFFFFF9E6),
        'iconColor': const Color(0xFFFFCC00),
      },
      {
        'type': ClubModuleType.heatmap,
        'title': 'Heatmap',
        'subtitle': 'Тепловая карта',
        'icon': Icons.grid_view_rounded,
        'color': const Color(0xFFE8F5FF),
        'iconColor': const Color(0xFF00B8D4),
      },
      {
        'type': ClubModuleType.clubNews,
        'title': 'Новости',
        'subtitle': 'Лента клуба',
        'icon': Icons.newspaper_outlined,
        'color': const Color(0xFFFFF0F0),
        'iconColor': const Color(0xFFFF6B6B),
      },
    ];
  }

  String? _cacheBust(String? url) {
    if (url == null || url.isEmpty) return null;
    final ts = DateTime.now().millisecondsSinceEpoch;
    return url.contains('?') ? '$url&v=$ts' : '$url?v=$ts';
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

  List<dynamic> _sortByIdList(List<dynamic> source, List<int> ids) {
    final map = <int, dynamic>{};
    for (final item in source) {
      final m = item as Map<String, dynamic>;
      map[_asInt(m['id'])] = item;
    }

    final result = <dynamic>[];
    for (final id in ids) {
      if (map.containsKey(id)) {
        result.add(map[id]);
      }
    }

    for (final item in source) {
      if (!result.contains(item)) {
        result.add(item);
      }
    }

    return result;
  }

  int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  String? _asString(dynamic v) {
    if (v == null) return null;
    if (v is String) return v;
    return v.toString();
  }
  
  Future<Map<String, dynamic>> _loadAllClubBundle() async {
    List<dynamic> localTeams = teams;
    List<dynamic> localTrainers = trainers;
    List<dynamic> localEvents = events;

    Map<String, dynamic>? clubProfile;

    try {
      final resp = await http.post(
        Uri.parse(getClubProfileUrl),
        body: {'club_id': clubId.toString()},
      );
      final data = _decode(resp);
      if (data['success'] == true && data['club'] is Map) {
        clubProfile = Map<String, dynamic>.from(data['club']);
      }
    } catch (_) {}

    try {
      if (localTeams.isEmpty) {
        final resp = await http.post(
          Uri.parse(getClubTeamsUrl),
          body: {'club_id': clubId.toString()},
        );
        final data = _decode(resp);
        if (data['success'] == true) {
          localTeams = (data['teams'] as List?) ?? [];
        }
      }

      if (localTrainers.isEmpty) {
        final resp = await http.post(
          Uri.parse(getClubTrainersUrl),
          body: {'club_id': clubId.toString()},
        );
        final data = _decode(resp);
        if (data['success'] == true) {
          localTrainers = (data['trainers'] as List?) ?? [];
        }
      }

      if (localEvents.isEmpty) {
        final resp = await http.post(
          Uri.parse(getClubEventsUrl),
          body: {'club_id': clubId.toString()},
        );
        final data = _decode(resp);
        if (data['success'] == true) {
          localEvents = (data['events'] as List?) ?? [];
        }
      }
    } catch (_) {}

    return {
      'club_id': clubId,
      'club': clubProfile,
      'teams': localTeams,
      'trainers': localTrainers,
      'events': localEvents,
    };
  }

  Future<void> _openDashboardBgPicker() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _presetColors.map((c) {
                final isSelected = _dashboardBgColor.value == c.value;
                return GestureDetector(
                  onTap: () async {
                    setState(() => _dashboardBgColor = c);
                    Navigator.pop(context);
                    await _saveUserPrefs();
                  },
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.black : Colors.grey.shade300,
                        width: isSelected ? 3 : 1,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openModuleStyleSheet(String typeKey) async {
    final current = Map<String, dynamic>.from(_moduleStyles[typeKey] ?? {});

    String? bgColor = current['bgColor'];
    String? textColor = current['textColor'];
    String? iconColor = current['iconColor'];
    String? iconBgColor = current['iconBgColor'];

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setSB) {
            Widget colorPickerRow(
              String title,
              String? selected,
              Function(String) onPick,
            ) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _presetColors.map((c) {
                      final hex = _colorToHex(c);
                      final isSelected = selected == hex;
                      return GestureDetector(
                        onTap: () => setSB(() => onPick(hex)),
                        child: Container(
                          width: 34,
                          height: 34,
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

            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                16 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  colorPickerRow('Цвет фона', bgColor, (v) => bgColor = v),
                  const SizedBox(height: 16),
                  colorPickerRow('Цвет текста', textColor, (v) => textColor = v),
                  const SizedBox(height: 16),
                  colorPickerRow('Цвет иконки', iconColor, (v) => iconColor = v),
                  const SizedBox(height: 16),
                  colorPickerRow(
                    'Фон иконки',
                    iconBgColor,
                    (v) => iconBgColor = v,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        setState(() {
                          _moduleStyles[typeKey] = {
                            'bgColor': bgColor,
                            'textColor': textColor,
                            'iconColor': iconColor,
                            'iconBgColor': iconBgColor,
                          };
                        });
                        Navigator.pop(context);
                        await _saveUserPrefs();
                      },
                      child: const Text('Сохранить'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _searchTrainerByEmail(
    String email, {
    bool debug = false,
  }) async {
    try {
      final clean = email.trim();
      if (clean.isEmpty) return [];

      final uri = Uri.parse(searchTrainerByEmailUrl).replace(
        queryParameters: {
          if (debug) 'debug': '1',
        },
      );

      final resp = await http.post(
        uri,
        body: {'email': clean},
      );

      final data = _decode(resp);

      if (debug) {
        Get.snackbar(
          'DEBUG search_trainer_by_email.php',
          resp.body.length > 600 ? resp.body.substring(0, 600) : resp.body,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(12),
          duration: const Duration(seconds: 6),
        );
      }

      if (data['success'] == true && data['trainers'] is List) {
        final list = (data['trainers'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        return list;
      }

      return [];
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> _pickTrainerByEmailSheet() async {
    final emailCtrl = TextEditingController();
    List<Map<String, dynamic>> results = [];
    bool searching = false;

    return await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setSB) {
            Future<void> doSearch({bool debug = false}) async {
              final q = emailCtrl.text.trim();
              if (q.isEmpty) {
                setSB(() => results = []);
                return;
              }

              setSB(() => searching = true);
              final r = await _searchTrainerByEmail(q, debug: debug);

              setSB(() {
                searching = false;
                results = r;
              });

              if (!debug && r.isEmpty) {
                Get.snackbar(
                  'Не найдено',
                  'Тренер с таким email не найден.\nПроверь точный email и что role = coach.',
                  snackPosition: SnackPosition.BOTTOM,
                  margin: const EdgeInsets.all(12),
                );
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 14,
                bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Поиск тренера по email (role=coach)',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => doSearch(),
                      decoration: InputDecoration(
                        labelText: 'Точный email тренера',
                        hintText: 'trainer@email.com',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: () => doSearch(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => doSearch(),
                            icon: const Icon(Icons.search),
                            label: const Text('Найти'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => doSearch(debug: true),
                            icon: const Icon(Icons.bug_report_outlined),
                            label: const Text('DEBUG'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (searching)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      )
                    else if (results.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Text(
                          'Введите точный email и нажмите «Найти».',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF6B7280)),
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: results.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final t = results[i];
                            final id = _asInt(t['id']);
                            final email = (t['email'] ?? '').toString();
                            final fn = (t['first_name'] ?? '').toString();
                            final ln = (t['last_name'] ?? '').toString();
                            final name = ('$fn $ln').trim();

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    ClubDashboardPalette.lightGreen,
                                child: Icon(
                                  Icons.person_outline,
                                  color: ClubDashboardPalette.primaryGreen,
                                ),
                              ),
                              title: Text(
                                name.isEmpty ? 'Тренер #$id' : name,
                              ),
                              subtitle: Text(email),
                              onTap: () => Navigator.pop(context, {
                                'id': id,
                                'name': name.isEmpty ? 'Тренер #$id' : name,
                                'email': email,
                              }),
                            );
                          },
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

  Future<void> _pickTeam() async {
    final source = _orderedTeams.isNotEmpty ? _orderedTeams : teams;

    if (source.isEmpty) {
      Get.snackbar('Команды', 'Список команд пуст');
      return;
    }

    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return SafeArea(
          top: false,
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
            itemBuilder: (context, i) {
              final t = source[i] as Map<String, dynamic>;
              final id = _asInt(t['id']);
              final name = _asString(t['name']) ?? 'Команда #$id';
              final cat = _asString(t['category']) ?? '';
              final isSelected = selectedTeamId == id;

              return ListTile(
                onTap: () => Navigator.pop(context, t),
                leading: CircleAvatar(
                  backgroundColor: ClubDashboardPalette.lightGreen,
                  child: Icon(
                    Icons.group_outlined,
                    color: ClubDashboardPalette.primaryGreen,
                  ),
                ),
                title: Text(
                  name,
                  style: TextStyle(
                    fontWeight:
                        isSelected ? FontWeight.w900 : FontWeight.w700,
                  ),
                ),
                subtitle: cat.isEmpty ? null : Text(cat),
                trailing: isSelected
                    ? Icon(
                        Icons.check_circle,
                        color: ClubDashboardPalette.primaryGreen,
                      )
                    : const Icon(Icons.chevron_right),
              );
            },
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemCount: source.length,
          ),
        );
      },
    );

    if (picked != null) {
      setState(() {
        selectedTeamId = _asInt(picked['id']);
        selectedTeamName = _asString(picked['name']) ?? 'Команда';
      });
    }
  }

  void _openSelectedTeam() {
    final tid = selectedTeamId ?? 0;
    if (tid <= 0) {
      Get.snackbar('Команда', 'Сначала выберите команду');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TeamDashboardScreen(
          teamId: tid,
          teamName: selectedTeamName,
          clubId: clubId,
          clubName: clubName,
        ),
      ),
    );
  }

  Future<void> _createTeamDialog() async {
    final nameCtrl = TextEditingController();
    final categoryCtrl = TextEditingController(text: 'Футбол');
    XFile? pickedLogo;
    final ImagePicker picker = ImagePicker();

    int? selectedCoachId;
    String selectedCoachName = 'Не выбран';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 14,
            bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SafeArea(
            top: false,
            child: StatefulBuilder(
              builder: (context, setSB) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Создать команду',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Название команды',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: categoryCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Категория (вид спорта)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () async {
                        final picked = await _pickTrainerByEmailSheet();
                        if (picked != null) {
                          setSB(() {
                            selectedCoachId = _asInt(picked['id']);
                            selectedCoachName =
                                _asString(picked['name']) ??
                                    'Тренер #$selectedCoachId';
                          });
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor:
                                  ClubDashboardPalette.lightGreen,
                              child: Icon(
                                selectedCoachId == null
                                    ? Icons.person_search_outlined
                                    : Icons.person_outline,
                                color: ClubDashboardPalette.primaryGreen,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Тренер',
                                    style: TextStyle(
                                      color:
                                          ClubDashboardPalette.textMuted,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    selectedCoachName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              onPressed: () async {
                                final picked = await _pickTrainerByEmailSheet();
                                if (picked != null) {
                                  setSB(() {
                                    selectedCoachId = _asInt(picked['id']);
                                    selectedCoachName =
                                        _asString(picked['name']) ??
                                            'Тренер #$selectedCoachId';
                                  });
                                }
                              },
                              child: const Text('Выбрать'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () async {
                        final x = await picker.pickImage(
                          source: ImageSource.gallery,
                          imageQuality: 85,
                          maxWidth: 1200,
                        );
                        if (x != null) {
                          setSB(() => pickedLogo = x);
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 22,
                              backgroundColor:
                                  ClubDashboardPalette.lightGreen,
                              backgroundImage: pickedLogo != null
                                  ? FileImage(File(pickedLogo!.path))
                                  : null,
                              child: pickedLogo == null
                                  ? Icon(
                                      Icons.image_outlined,
                                      color:
                                          ClubDashboardPalette.primaryGreen,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                pickedLogo == null
                                    ? 'Выбрать логотип команды (необязательно)'
                                    : 'Логотип выбран ✅',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          if (nameCtrl.text.trim().isEmpty) {
                            Get.snackbar(
                              'Ошибка',
                              'Введите название команды',
                            );
                            return;
                          }

                          if (selectedCoachId == null ||
                              selectedCoachId == 0) {
                            Get.snackbar(
                              'Ошибка',
                              'Выберите тренера (coach)',
                            );
                            return;
                          }

                          Navigator.pop(context);

                          await _createTeam(
                            name: nameCtrl.text.trim(),
                            category: categoryCtrl.text.trim(),
                            coachId: selectedCoachId!,
                            logo: pickedLogo,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              ClubDashboardPalette.primaryGreen,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text(
                          'Создать',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _createTeam({
    required String name,
    required String category,
    required int coachId,
    XFile? logo,
  }) async {
    Get.snackbar('Команда', 'Создаю...');

    try {
      final uri = Uri.parse(createTeamUrl);
      final req = http.MultipartRequest('POST', uri);

      req.fields['club_id'] = clubId.toString();
      req.fields['coach_id'] = coachId.toString();
      req.fields['name'] = name;
      req.fields['category'] = category.isEmpty ? 'Футбол' : category;

      if (logo != null) {
        req.files.add(await http.MultipartFile.fromPath('logo', logo.path));
      }

      final streamed = await req.send();
      final resp = await http.Response.fromStream(streamed);
      final data = _decode(resp);

      if (data['success'] == true) {
        Get.snackbar('Готово', 'Команда создана');
        await _reloadAll();
      } else {
        Get.snackbar(
          'Ошибка',
          _asString(data['message']) ?? 'Не удалось создать команду',
        );
      }
    } catch (e) {
      Get.snackbar('Сеть', 'Ошибка соединения: $e');
    }
  }

  Future<void> _linkEventPlan({
    required int eventId,
    required int planId,
  }) async {
    try {
      final resp = await http.post(
        Uri.parse(linkEventPlanUrl),
        body: {
          'event_id': eventId.toString(),
          'plan_id': planId.toString(),
        },
      );

      final data = _decode(resp);

      if (data['success'] == true) {
        Get.snackbar('Готово', 'План привязан к событию');
      } else {
        Get.snackbar(
          'Ошибка',
          _asString(data['message']) ?? 'Не удалось привязать план',
        );
      }
    } catch (_) {
      Get.snackbar('Сеть', 'Ошибка соединения');
    }
  }

  Future<int?> _pickPlanId(BuildContext context) async {
    if (plans.isEmpty) return null;

    return await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return SafeArea(
          top: false,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
            itemBuilder: (context, i) {
              final p = plans[i] as Map<String, dynamic>;
              final id = _asInt(p['id']);
              final title = _asString(p['title']) ??
                  _asString(p['name']) ??
                  'План #$id';

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: ClubDashboardPalette.lightGreen,
                  child: Icon(
                    Icons.menu_book,
                    color: ClubDashboardPalette.primaryGreen,
                  ),
                ),
                title: Text(title),
                onTap: () => Navigator.pop(context, id),
              );
            },
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemCount: plans.length,
          ),
        );
      },
    );
  }

  Map<String, dynamic> _decode(http.Response resp) {
    final body = utf8.decode(resp.bodyBytes, allowMalformed: true).trim();

    if (body.startsWith('<!DOCTYPE') ||
        body.startsWith('<html') ||
        body.startsWith('<')) {
      return {
        'success': false,
        'message': 'Server returned HTML вместо JSON',
        '_status': resp.statusCode,
        '_raw_head': body.substring(0, body.length > 400 ? 400 : body.length),
      };
    }

    try {
      final j = json.decode(body);
      if (j is Map<String, dynamic>) return j;

      return {
        'success': false,
        'message': 'Invalid JSON structure',
        '_status': resp.statusCode,
        '_raw_head': body.substring(0, body.length > 400 ? 400 : body.length),
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'JSON parse error: $e',
        '_status': resp.statusCode,
        '_raw_head': body.substring(0, body.length > 400 ? 400 : body.length),
      };
    }
  }

  Future<void> _openTeamStyleSheet(int teamId) async {
    final current = Map<String, dynamic>.from(_teamStyles[teamId] ?? {});

    String? bgColor = current['bgColor'];
    String? textColor = current['textColor'];
    String? subTextColor = current['subTextColor'];
    String? iconBgColor = current['iconBgColor'];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        final maxHeight = MediaQuery.of(context).size.height * 0.82;

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
                          'Настройка карточки команды',
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
                            colorRow('Фон карточки', bgColor, (v) => bgColor = v),
                            const SizedBox(height: 20),
                            colorRow(
                              'Цвет названия',
                              textColor,
                              (v) => textColor = v,
                            ),
                            const SizedBox(height: 20),
                            colorRow(
                              'Цвет подписи',
                              subTextColor,
                              (v) => subTextColor = v,
                            ),
                            const SizedBox(height: 20),
                            colorRow(
                              'Фон иконки',
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
                              _teamStyles[teamId] = {
                                'bgColor': bgColor,
                                'textColor': textColor,
                                'subTextColor': subTextColor,
                                'iconBgColor': iconBgColor,
                              };
                            });
                            Navigator.pop(context);
                            await _saveUserPrefs();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ClubDashboardPalette.primaryGreen,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'Сохранить',
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

  Future<void> _pickClubLogo() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 800,
    );

    if (pickedFile != null) {
      setState(() {
        newLogoFile = pickedFile;
        clubLogoFile = File(pickedFile.path);
      });
    }
  }

  Widget _buildClubHero() {
    final isTablet = MediaQuery.of(context).size.width > 700;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: ClubDashboardPalette.heroGradient,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
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
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: isEditingClubInfo ? _pickClubLogo : null,
                      child: Container(
                        width: isTablet ? 84 : 74,
                        height: isTablet ? 84 : 74,
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
                              child: clubLogoFile != null
                                  ? Image.file(
                                      clubLogoFile!,
                                      fit: BoxFit.cover,
                                    )
                                  : (clubLogoPath != null &&
                                          clubLogoPath!.isNotEmpty)
                                      ? Image.network(
                                          clubLogoPath!,
                                          key: ValueKey(clubLogoPath),
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              _buildDefaultLogo(),
                                        )
                                      : _buildDefaultLogo(),
                            ),
                            if (isEditingClubInfo)
                              Positioned(
                                right: 2,
                                bottom: 2,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: ClubDashboardPalette.primaryGreen,
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
                      child: isEditingClubInfo
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TextField(
                                  controller: clubNameController,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Введите название клуба',
                                    hintStyle: TextStyle(
                                      color: Colors.white.withOpacity(0.70),
                                    ),
                                    enabledBorder: UnderlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Colors.white.withOpacity(0.20),
                                      ),
                                    ),
                                    focusedBorder: const UnderlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: clubDescriptionController,
                                  maxLines: 2,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Краткое описание клуба',
                                    hintStyle: TextStyle(
                                      color: Colors.white.withOpacity(0.65),
                                    ),
                                    enabledBorder: UnderlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Colors.white.withOpacity(0.20),
                                      ),
                                    ),
                                    focusedBorder: const UnderlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  clubName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: isTablet ? 26 : 22,
                                    fontWeight: FontWeight.w900,
                                    height: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  clubDescriptionController.text.trim().isEmpty
                                      ? 'Панель управления клубом, командами и внутренними модулями'
                                      : clubDescriptionController.text.trim(),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.82),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                    height: 1.25,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                GestureDetector(
                                  onLongPress: () {
                                    setState(() {
                                      isEditingClubInfo = true;
                                      clubNameController.text = clubName;
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 7,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.10),
                                      ),
                                    ),
                                    child: const Text(
                                      'Удерживайте для редактирования',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildHeroStat(
                        title: 'Команды',
                        value: '${teams.length}',
                        icon: Icons.groups_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildHeroStat(
                        title: 'Тренеры',
                        value: '${trainers.length}',
                        icon: Icons.person_outline_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildHeroStat(
                        title: 'События',
                        value: '${events.length}',
                        icon: Icons.calendar_month_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _heroActionButton(
                        label: 'Создать команду',
                        icon: Icons.add_rounded,
                        filled: true,
                        onTap: _createTeamDialog,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _heroActionButton(
                        label: 'Выбрать фон',
                        icon: Icons.palette_outlined,
                        filled: false,
                        onTap: _openDashboardBgPicker,
                      ),
                    ),
                  ],
                ),
                if (isEditingClubInfo) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              isEditingClubInfo = false;
                              clubNameController.text = clubName;
                              newLogoFile = null;
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
                          onPressed: _updateClubProfile,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: ClubDashboardPalette.primaryGreen,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text('Сохранить'),
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

  Widget _buildHeroStat({
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

  Widget _heroActionButton({
    required String label,
    required IconData icon,
    required bool filled,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: filled ? Colors.white : Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: filled
              ? null
              : Border.all(
                  color: Colors.white.withOpacity(0.14),
                ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: filled
                  ? ClubDashboardPalette.primaryGreen
                  : Colors.white,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: filled
                      ? ClubDashboardPalette.primaryGreen
                      : Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 12.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultLogo() {
    return Container(
      decoration: BoxDecoration(
        color: ClubDashboardPalette.primaryGreen.withOpacity(0.10),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Icon(
          Icons.sports_soccer_outlined,
          size: 32,
          color: ClubDashboardPalette.primaryGreen,
        ),
      ),
    );
  }

  Widget _buildSelectedTeamCard() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ClubDashboardPalette.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: ClubDashboardPalette.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: ClubDashboardPalette.primaryGreen.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.sports_soccer_outlined,
                  color: ClubDashboardPalette.primaryGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Выбранная команда',
                      style: TextStyle(
                        color: ClubDashboardPalette.textMuted,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      selectedTeamName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                        color: ClubDashboardPalette.text,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _pickTeam,
                icon: const Icon(Icons.swap_horiz_rounded),
                label: const Text('Сменить'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: ClubDashboardPalette.primaryGreen,
                  side: BorderSide(
                    color: ClubDashboardPalette.primaryGreen.withOpacity(0.35),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _openSelectedTeam,
              icon: const Icon(
                Icons.open_in_new_rounded,
                color: Colors.white,
              ),
              label: const Text(
                'Открыть панель команды',
                style: TextStyle(color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: ClubDashboardPalette.primaryGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
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
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ClubDashboardPalette.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: ClubDashboardPalette.border),
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
            right: rightText,
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildTeamsSection() {
    if (_orderedTeams.isEmpty) {
      return _buildSectionShell(
        title: 'Команды клуба',
        rightText: 'всего: 0',
        child: const _EmptyHint(
          text: 'Команд пока нет. Нажмите + чтобы создать.',
        ),
      );
    }

    return _buildSectionShell(
      title: 'Команды клуба',
      rightText: 'всего: ${_orderedTeams.length}',
      child: _editLayoutMode
          ? ReorderableListView.builder(
              shrinkWrap: true,
              buildDefaultDragHandles: false,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _orderedTeams.length,
              itemBuilder: (context, index) {
                final team = _orderedTeams[index] as Map<String, dynamic>;
                final teamId = _asInt(team['id']);

                return Container(
                  key: ValueKey('team_$teamId'),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      ReorderableDragStartListener(
                        index: index,
                        child: Container(
                          width: 36,
                          height: 74,
                          alignment: Alignment.center,
                          child: const Icon(Icons.drag_handle),
                        ),
                      ),
                      Expanded(
                        child: _TeamTile(
                          team: team,
                          selectedId: selectedTeamId,
                          styleData: _teamStyles[teamId],
                          onCustomize: () => _openTeamStyleSheet(teamId),
                          onTap: () {
                            setState(() {
                              selectedTeamId = _asInt(team['id']);
                              selectedTeamName =
                                  _asString(team['name']) ?? 'Команда';
                            });
                            _openSelectedTeam();
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
              onReorder: (oldIndex, newIndex) async {
                if (newIndex > oldIndex) newIndex -= 1;
                setState(() {
                  final item = _orderedTeams.removeAt(oldIndex);
                  _orderedTeams.insert(newIndex, item);
                });
                await _saveUserPrefs();
              },
            )
          : Column(
              children: List.generate(_orderedTeams.length, (index) {
                final team = _orderedTeams[index] as Map<String, dynamic>;
                final teamId = _asInt(team['id']);
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == _orderedTeams.length - 1 ? 0 : 8,
                  ),
                  child: _TeamTile(
                    team: team,
                    selectedId: selectedTeamId,
                    styleData: _teamStyles[teamId],
                    onTap: () {
                      setState(() {
                        selectedTeamId = _asInt(team['id']);
                        selectedTeamName =
                            _asString(team['name']) ?? 'Команда';
                      });
                      _openSelectedTeam();
                    },
                  ),
                );
              }),
            ),
    );
  }

  Widget _buildModulesSection() {
    final isTablet = MediaQuery.of(context).size.width > 700;

    return _buildSectionShell(
      title: 'Модули клуба',
      rightText: '${_moduleItems.length} модулей',
      child: _editLayoutMode
          ? ReorderableListView.builder(
              shrinkWrap: true,
              buildDefaultDragHandles: false,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _moduleItems.length,
              itemBuilder: (context, index) {
                final item = _moduleItems[index];
                final typeKey = item['type'].toString();

                return Container(
                  key: ValueKey('module_$typeKey'),
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ReorderableDragStartListener(
                        index: index,
                        child: Container(
                          width: 36,
                          height: isTablet ? 150 : 138,
                          alignment: Alignment.center,
                          child: const Icon(Icons.drag_handle),
                        ),
                      ),
                      Expanded(
                        child: SizedBox(
                          height: isTablet ? 150 : 138,
                          child: _buildModuleBanner(
                            item,
                            styleData: _moduleStyles[typeKey] is Map<String, dynamic>
                                ? _moduleStyles[typeKey]
                                : (_moduleStyles[typeKey] is Map
                                    ? Map<String, dynamic>.from(
                                        _moduleStyles[typeKey],
                                      )
                                    : null),
                            editMode: true,
                            onCustomize: () => _openModuleStyleSheet(typeKey),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
              onReorder: (oldIndex, newIndex) async {
                if (newIndex > oldIndex) newIndex -= 1;
                setState(() {
                  final item = _moduleItems.removeAt(oldIndex);
                  _moduleItems.insert(newIndex, item);
                });
                await _saveUserPrefs();
              },
            )
          : GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _moduleItems.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isTablet ? 3 : 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: isTablet ? 1.20 : 1.08,
              ),
              itemBuilder: (context, index) {
                final item = _moduleItems[index];
                final typeKey = item['type'].toString();

                return _buildModuleBanner(
                  item,
                  styleData: _moduleStyles[typeKey] is Map<String, dynamic>
                      ? _moduleStyles[typeKey]
                      : (_moduleStyles[typeKey] is Map
                          ? Map<String, dynamic>.from(_moduleStyles[typeKey])
                          : null),
                );
              },
            ),
    );
  }

  Widget _buildQuickDataSection() {
    return _buildSectionShell(
      title: 'Обзор клуба',
      rightText: 'live',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _overviewMetricCard(
                  title: 'Ближайшее событие',
                  value: events.isNotEmpty
                      ? _asString(
                            (events.first as Map<String, dynamic>)['title'],
                          ) ??
                          'Событие'
                      : 'Нет событий',
                  icon: Icons.event_rounded,
                  color: ClubDashboardPalette.blue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _overviewMetricCard(
                  title: 'Активный план',
                  value: plans.isNotEmpty ? '${plans.length} шт.' : 'Нет',
                  icon: Icons.menu_book_rounded,
                  color: ClubDashboardPalette.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _overviewMetricCard(
                  title: 'Тренеры онлайн',
                  value: trainers.isEmpty ? '0' : '${trainers.length}',
                  icon: Icons.support_agent_rounded,
                  color: ClubDashboardPalette.orange,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _overviewMetricCard(
                  title: 'Статус PRO',
                  value: _subscription.features.isNotEmpty ? 'Активно' : 'Free',
                  icon: Icons.workspace_premium_rounded,
                  color: ClubDashboardPalette.rose,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _overviewMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ClubDashboardPalette.surface,
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
                    color: ClubDashboardPalette.textMuted,
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
                    color: ClubDashboardPalette.text,
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

  Widget _buildModuleBanner(
    Map<String, dynamic> item, {
    Map<String, dynamic>? styleData,
    bool editMode = false,
    VoidCallback? onCustomize,
  }) {
    final bgColor = styleData?['bgColor'] != null
        ? _colorFromHex(styleData!['bgColor'])
        : item['color'] as Color;

    final iconColor = styleData?['iconColor'] != null
        ? _colorFromHex(styleData!['iconColor'])
        : item['iconColor'] as Color;

    final textColor = styleData?['textColor'] != null
        ? _colorFromHex(styleData!['textColor'])
        : ClubDashboardPalette.text;

    final iconBgColor = styleData?['iconBgColor'] != null
        ? _colorFromHex(styleData!['iconBgColor'])
        : Colors.white;

    final moduleType = item['type'] as ClubModuleType;
    final featureCode = _mapClubModuleToFeature(moduleType);
    final showProBadge =
        _isPremiumClubModule(moduleType) && !_subscription.has(featureCode);

    return Stack(
      children: [
        Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: editMode ? null : () => _openModule(moduleType),
            child: Container(
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: ClubDashboardPalette.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: iconBgColor,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            item['icon'] as IconData,
                            size: 22,
                            color: iconColor,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.arrow_outward_rounded,
                          color: textColor.withOpacity(0.60),
                          size: 18,
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      item['title'] as String,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: textColor,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item['subtitle'] as String,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: textColor.withOpacity(0.75),
                        height: 1.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (showProBadge)
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'PRO',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        if (editMode)
          Positioned(
            top: 8,
            right: 8,
            child: InkWell(
              onTap: onCustomize,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: ClubDashboardPalette.border),
                ),
                child: const Icon(
                  Icons.palette_outlined,
                  size: 16,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCreateTeamButton() {
    return FloatingActionButton.extended(
      onPressed: _createTeamDialog,
      backgroundColor: ClubDashboardPalette.primaryGreen,
      foregroundColor: Colors.white,
      elevation: 4,
      icon: const Icon(Icons.add),
      label: const Text(
        'Команда',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
    );
  }

  Widget _buildQuickActionsStrip() {
    final actions = [
      {
        'title': 'Создать команду',
        'subtitle': 'Новая команда клуба',
        'icon': Icons.add_circle_outline_rounded,
        'color': ClubDashboardPalette.primaryGreen,
        'onTap': _createTeamDialog,
      },
      {
        'title': 'Выбрать команду',
        'subtitle': 'Открыть нужную панель',
        'icon': Icons.swap_horiz_rounded,
        'color': ClubDashboardPalette.blue,
        'onTap': _pickTeam,
      },
      {
        'title': 'Тренеры',
        'subtitle': 'Состав штаба клуба',
        'icon': Icons.people_outline_rounded,
        'color': ClubDashboardPalette.purple,
        'onTap': () => _openModule(ClubModuleType.trainers),
      },
      {
        'title': 'Календарь',
        'subtitle': 'События и матчи',
        'icon': Icons.calendar_month_rounded,
        'color': ClubDashboardPalette.orange,
        'onTap': () => _openModule(ClubModuleType.calendar),
      },
      {
        'title': 'Посещаемость',
        'subtitle': 'Журнал отметок',
        'icon': Icons.fact_check_outlined,
        'color': ClubDashboardPalette.cyan,
        'onTap': () => _openModule(ClubModuleType.attendance),
      },
      {
        'title': 'Планы',
        'subtitle': 'Конспекты и база',
        'icon': Icons.menu_book_rounded,
        'color': ClubDashboardPalette.rose,
        'onTap': () => _openModule(ClubModuleType.plansBase),
      },
    ];

    return _buildSectionShell(
      title: 'Быстрые действия',
      rightText: 'доступ',
      child: SizedBox(
        height: 126,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: actions.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, index) {
            final item = actions[index];
            final color = item['color'] as Color;

            return InkWell(
              onTap: item['onTap'] as VoidCallback,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 188,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: ClubDashboardPalette.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE7ECF2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        item['icon'] as IconData,
                        color: color,
                        size: 21,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      item['title'] as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: ClubDashboardPalette.text,
                        fontWeight: FontWeight.w900,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item['subtitle'] as String,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: ClubDashboardPalette.textMuted,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEventsCarouselSection() {
    return _buildSectionShell(
      title: 'События клуба',
      rightText: '${events.length}',
      child: events.isEmpty
          ? const _EmptyHint(
              text: 'Пока нет событий клуба.',
            )
          : SizedBox(
              height: 172,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: events.length > 8 ? 8 : events.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final event = Map<String, dynamic>.from(
                    events[index] as Map,
                  );
                  return _buildClubEventCard(event);
                },
              ),
            ),
    );
  }

  Widget _buildClubEventCard(Map<String, dynamic> event) {
    final title = (_asString(event['title'])?.trim().isNotEmpty == true)
        ? _asString(event['title'])!.trim()
        : ((_asString(event['name'])?.trim().isNotEmpty == true)
            ? _asString(event['name'])!.trim()
            : 'Событие');

    final date = (_asString(event['event_date']) ?? _asString(event['date']) ?? '')
        .trim();
    final teamName = (_asString(event['team_name']) ?? '').trim();
    final location = (_asString(event['location']) ?? '').trim();

    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: ClubDashboardPalette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE7ECF2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: ClubDashboardPalette.primaryGreen.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.event_rounded,
                color: ClubDashboardPalette.primaryGreen,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 14,
                color: ClubDashboardPalette.text,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 8),
            if (date.isNotEmpty)
              _miniMetaRow(
                Icons.calendar_today_rounded,
                date,
              ),
            if (teamName.isNotEmpty) ...[
              const SizedBox(height: 6),
              _miniMetaRow(
                Icons.groups_rounded,
                teamName,
              ),
            ],
            if (location.isNotEmpty) ...[
              const SizedBox(height: 6),
              _miniMetaRow(
                Icons.place_rounded,
                location,
              ),
            ],
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: plans.isEmpty
                        ? null
                        : () async {
                            final planId = await _pickPlanId(context);
                            if (planId != null) {
                              final eventId = _asInt(event['id']);
                              if (eventId > 0) {
                                await _linkEventPlan(
                                  eventId: eventId,
                                  planId: planId,
                                );
                              }
                            }
                          },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ClubDashboardPalette.primaryGreen,
                      side: BorderSide(
                        color: ClubDashboardPalette.primaryGreen.withOpacity(0.30),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'План',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrainersCarouselSection() {
    return _buildSectionShell(
      title: 'Тренерский штаб',
      rightText: '${trainers.length}',
      child: trainers.isEmpty
          ? const _EmptyHint(
              text: 'Тренеры клуба пока не найдены.',
            )
          : SizedBox(
              height: 146,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: trainers.length > 10 ? 10 : trainers.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final trainer = Map<String, dynamic>.from(
                    trainers[index] as Map,
                  );
                  return _buildTrainerCard(trainer);
                },
              ),
            ),
    );
  }

  Widget _buildTrainerCard(Map<String, dynamic> trainer) {
    final firstName = (_asString(trainer['first_name']) ?? '').trim();
    final lastName = (_asString(trainer['last_name']) ?? '').trim();
    final email = (_asString(trainer['email']) ?? '').trim();
    final fullName = ('$firstName $lastName').trim().isEmpty
        ? 'Тренер'
        : ('$firstName $lastName').trim();

    final avatarUrl = MediaUtils.normalizeUrl(
      _asString(trainer['photo']) ?? _asString(trainer['photo_url']),
    );

    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: ClubDashboardPalette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE7ECF2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: ClubDashboardPalette.lightGreen,
              backgroundImage:
                  avatarUrl != null && avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
              child: (avatarUrl == null || avatarUrl.isEmpty)
                  ? Text(
                      fullName.isNotEmpty ? fullName[0].toUpperCase() : 'Т',
                      style: const TextStyle(
                        color: ClubDashboardPalette.primaryGreen,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fullName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ClubDashboardPalette.text,
                      fontWeight: FontWeight.w900,
                      fontSize: 13.5,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    email.isEmpty ? 'Email не указан' : email,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ClubDashboardPalette.textMuted,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                      height: 1.2,
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

  Widget _miniMetaRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: ClubDashboardPalette.textMuted,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: ClubDashboardPalette.textMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _dashboardBgColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: ClubDashboardPalette.white,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Панель клуба',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: ClubDashboardPalette.text,
            fontSize: 16,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
       actions: [
  IconButton(
    tooltip: 'CMR-панель',
    onPressed: () {
      Get.toNamed('/club-workspace');
    },
    icon: const Icon(
      Icons.dashboard_customize_outlined,
      color: Colors.black87,
    ),
  ),

  IconButton(
    tooltip: 'Фон панели',
    onPressed: _openDashboardBgPicker,
    icon: const Icon(
      Icons.format_color_fill_outlined,
      color: Colors.black87,
    ),
  ),
            IconButton(
            tooltip: _editLayoutMode ? 'Готово' : 'Редактировать панель',
            onPressed: () async {
              setState(() => _editLayoutMode = !_editLayoutMode);
              if (!_editLayoutMode) {
                await _saveUserPrefs();
              }
            },
            icon: Icon(
              _editLayoutMode ? Icons.check : Icons.edit_outlined,
              color: Colors.black87,
            ),
          ),
          IconButton(
            tooltip: 'Обновить',
            onPressed: _reloadAll,
            icon: const Icon(
              Icons.refresh_rounded,
              color: Colors.black87,
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      floatingActionButton: _buildCreateTeamButton(),
      body: FadeTransition(
        opacity: CurvedAnimation(
          parent: _animationController,
          curve: Curves.easeInOut,
        ),
        child: loading
            ? const Center(
                child: CircularProgressIndicator(
                  color: ClubDashboardPalette.primaryGreen,
                ),
              )
            : error != null
                ? _ErrorView(text: error!, onRetry: _reloadAll)
                : RefreshIndicator(
                    onRefresh: _reloadAll,
                    color: ClubDashboardPalette.primaryGreen,
                    child: ListView(
                      children: [
                        const SizedBox(height: 10),
                        _buildClubHero(),
                        _buildQuickActionsStrip(),
                        _buildQuickDataSection(),
                        _buildSelectedTeamCard(),
                        _buildEventsCarouselSection(),
                        _buildTrainersCarouselSection(),
                        _buildTeamsSection(),
                        _buildModulesSection(),
                        const SizedBox(height: 90),
                      ],
                    ),
                  ),
      ),
    );
  }
}

class ClubModuleScreen extends StatefulWidget {
  final int clubId;
  final ClubModuleType type;
  final Future<Map<String, dynamic>> Function() loadBundle;

  const ClubModuleScreen({
    super.key,
    required this.clubId,
    required this.type,
    required this.loadBundle,
  });

  @override
  State<ClubModuleScreen> createState() => _ClubModuleScreenState();
}

class _ClubModuleScreenState extends State<ClubModuleScreen>
    with SingleTickerProviderStateMixin {
  bool loading = true;
  String? error;
  Map<String, dynamic>? bundle;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _load();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
      bundle = null;
    });

    try {
      final b = await widget.loadBundle();
      if (!mounted) return;
      setState(() {
        bundle = b;
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'Не удалось загрузить данные модуля.';
      });
    }
  }

  String _title() {
    switch (widget.type) {
      case ClubModuleType.clubInfo:
        return 'Профиль клуба';
      case ClubModuleType.trainers:
        return 'Тренеры клуба';
      case ClubModuleType.calendar:
        return 'Календарь клуба';
      case ClubModuleType.attendance:
        return 'Журнал посещений';
      case ClubModuleType.clubChat:
        return 'Общий чат клуба';
      case ClubModuleType.trainingEditor:
        return 'Графический редактор';
      case ClubModuleType.plansBase:
        return 'Планы / конспекты';
      case ClubModuleType.videoAnalysis:
        return 'Видеоанализ';
      case ClubModuleType.heatmap:
        return 'Тепловая карта';
      case ClubModuleType.clubNews:
        return 'Лента новостей клуба';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ClubDashboardPalette.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: ClubDashboardPalette.white,
        surfaceTintColor: Colors.transparent,
        title: Text(
          _title(),
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            color: ClubDashboardPalette.text,
            fontSize: 16,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, color: Colors.black87),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: FadeTransition(
        opacity: CurvedAnimation(
          parent: _animationController,
          curve: Curves.easeInOut,
        ),
        child: loading
            ? const Center(
                child: CircularProgressIndicator(
                  color: ClubDashboardPalette.primaryGreen,
                ),
              )
            : error != null
                ? _ErrorView(text: error!, onRetry: _load)
                : _ClubModuleBody(
                    type: widget.type,
                    bundle: bundle ?? const {},
                  ),
      ),
    );
  }
}

class _ClubModuleBody extends StatelessWidget {
  final ClubModuleType type;
  final Map<String, dynamic> bundle;

  const _ClubModuleBody({
    required this.type,
    required this.bundle,
  });

  int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  String _asStr(dynamic v) => (v ?? '').toString();

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;
    final club =
        bundle['club'] is Map ? Map<String, dynamic>.from(bundle['club']) : null;
    final teams = (bundle['teams'] as List?) ?? [];
    final trainers = (bundle['trainers'] as List?) ?? [];
    final events = (bundle['events'] as List?) ?? [];

    Widget header = Container(
      margin: EdgeInsets.fromLTRB(
        isTablet ? 24 : 16,
        12,
        isTablet ? 24 : 16,
        12,
      ),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ClubDashboardPalette.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ClubDashboardPalette.border),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: ClubDashboardPalette.primaryGreen.withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: ClubDashboardPalette.primaryGreen,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _titleForType(type),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Команд: ${teams.length} • Тренеров: ${trainers.length} • Событий: ${events.length}',
                  style: const TextStyle(
                    color: ClubDashboardPalette.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    Widget body;
    switch (type) {
      case ClubModuleType.clubInfo:
        body = _clubInfoView(club, teams);
        break;
      case ClubModuleType.trainers:
        body = _trainersView(trainers);
        break;
      case ClubModuleType.calendar:
        body = _calendarView(events);
        break;
      case ClubModuleType.attendance:
        body = _stubView('Журнал посещений', '');
        break;
      case ClubModuleType.clubChat:
        body = _stubView('Общий чат', '');
        break;
      case ClubModuleType.trainingEditor:
        body = _stubView('Графический редактор', '');
        break;
      case ClubModuleType.plansBase:
        body = _stubView('База планов-конспектов', '');
        break;
      case ClubModuleType.videoAnalysis:
        body = _stubView('Видеоанализ', '');
        break;
      case ClubModuleType.heatmap:
        body = _stubView('Тепловая карта игры', '');
        break;
      case ClubModuleType.clubNews:
        body = _stubView('Лента новостей клуба', '');
        break;
    }

    return ListView(
      children: [
        header,
        Padding(
          padding: EdgeInsets.fromLTRB(
            isTablet ? 24 : 16,
            0,
            isTablet ? 24 : 16,
            24,
          ),
          child: body,
        ),
      ],
    );
  }

  static String _titleForType(ClubModuleType type) {
    switch (type) {
      case ClubModuleType.clubInfo:
        return 'Профиль клуба';
      case ClubModuleType.trainers:
        return 'Тренеры клуба';
      case ClubModuleType.calendar:
        return 'Календарь клуба';
      case ClubModuleType.attendance:
        return 'Журнал посещений';
      case ClubModuleType.clubChat:
        return 'Общий чат клуба';
      case ClubModuleType.trainingEditor:
        return 'Графический редактор';
      case ClubModuleType.plansBase:
        return 'Планы / конспекты';
      case ClubModuleType.videoAnalysis:
        return 'Видеоанализ';
      case ClubModuleType.heatmap:
        return 'Тепловая карта';
      case ClubModuleType.clubNews:
        return 'Новости клуба';
    }
  }

  Widget _clubInfoView(Map<String, dynamic>? club, List<dynamic> teams) {
    final clubName = club == null ? 'Клуб' : _asStr(club['club_name']).trim();
    final desc = club == null ? '' : _asStr(club['club_description']).trim();
    final address = club == null ? '' : _asStr(club['club_address']).trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _whiteCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                clubName.isEmpty ? 'Клуб' : clubName,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              if (desc.isNotEmpty)
                Text(
                  desc,
                  style: const TextStyle(
                    color: ClubDashboardPalette.text,
                    height: 1.25,
                  ),
                )
              else
                const Text(
                  'Описание клуба пока недоступно',
                  style: TextStyle(
                    color: ClubDashboardPalette.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              if (address.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        address,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        _whiteCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Состав клуба (команды)',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              if (teams.isEmpty)
                const Text(
                  'Команд нет.',
                  style: TextStyle(color: ClubDashboardPalette.textMuted),
                )
              else
                ...teams.take(20).map((e) {
                  final t = e as Map<String, dynamic>;
                  final id = _asInt(t['id']);
                  final name = _asStr(t['name']);
                  final cat = _asStr(t['category']);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.group_outlined,
                          size: 18,
                          color: ClubDashboardPalette.primaryGreen,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            name.isEmpty ? 'Команда #$id' : name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (cat.isNotEmpty)
                          Text(
                            cat,
                            style: const TextStyle(
                              color: ClubDashboardPalette.textMuted,
                            ),
                          ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  Widget _trainersView(List<dynamic> trainers) {
    return _whiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Тренеры',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          if (trainers.isEmpty)
            const Text(
              'Тренеры не найдены.',
              style: TextStyle(color: ClubDashboardPalette.textMuted),
            )
          else
            ...trainers.map((e) {
              final t = e as Map<String, dynamic>;
              final fn = _asStr(t['first_name']);
              final ln = _asStr(t['last_name']);
              final email = _asStr(t['email']);
              final name = ('$fn $ln').trim();
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: ClubDashboardPalette.lightGreen,
                  child: Icon(
                    Icons.person_outline,
                    color: ClubDashboardPalette.primaryGreen,
                  ),
                ),
                title: Text(
                  name.isEmpty ? 'Тренер' : name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: email.isEmpty ? null : Text(email),
              );
            }),
        ],
      ),
    );
  }

  Widget _calendarView(List<dynamic> events) {
    return _whiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'События всех команд',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          if (events.isEmpty)
            const Text(
              'Событий нет.',
              style: TextStyle(color: ClubDashboardPalette.textMuted),
            )
          else
            ...events.take(30).map((e) {
              final ev = e as Map<String, dynamic>;
              final title = _asStr(ev['title']).isNotEmpty
                  ? _asStr(ev['title'])
                  : _asStr(ev['name']);
              final date = _asStr(ev['event_date']).isNotEmpty
                  ? _asStr(ev['event_date'])
                  : _asStr(ev['date']);
              final team = _asStr(ev['team_name']);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.calendar_month_outlined,
                      size: 18,
                      color: ClubDashboardPalette.primaryGreen,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title.isEmpty ? 'Событие' : title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            [
                              if (date.isNotEmpty) date,
                              if (team.isNotEmpty) team,
                            ].join(' • '),
                            style: const TextStyle(
                              color: ClubDashboardPalette.textMuted,
                              fontWeight: FontWeight.w600,
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

  Widget _stubView(String title, String text) {
    return _whiteCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          Text(
            text,
            style: const TextStyle(
              color: ClubDashboardPalette.text,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }

  Widget _whiteCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ClubDashboardPalette.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ClubDashboardPalette.border),
      ),
      child: child,
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String text;
  final VoidCallback onRetry;

  const _ErrorView({
    required this.text,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 44,
              color: ClubDashboardPalette.primaryGreen,
            ),
            const SizedBox(height: 10),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: ClubDashboardPalette.primaryGreen,
              ),
              child: const Text(
                'Повторить',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;

  const _EmptyHint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ClubDashboardPalette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ClubDashboardPalette.border),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: ClubDashboardPalette.textMuted,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? right;

  const _SectionTitle({
    required this.title,
    this.right,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: ClubDashboardPalette.text,
            ),
          ),
        ),
        if (right != null)
          Text(
            right!,
            style: const TextStyle(
              color: ClubDashboardPalette.textMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }
}

class _TeamTile extends StatelessWidget {
  final Map<String, dynamic> team;
  final int? selectedId;
  final VoidCallback onTap;
  final dynamic styleData;
  final VoidCallback? onCustomize;

  const _TeamTile({
    required this.team,
    required this.selectedId,
    required this.onTap,
    this.styleData,
    this.onCustomize,
  });

  int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  String _asStr(dynamic v) => (v ?? '').toString();

  Color _colorFromHex(String hex) {
    final buffer = StringBuffer();
    String value = hex.replaceAll('#', '');
    if (value.length == 6) buffer.write('ff');
    buffer.write(value);
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final id = _asInt(team['id']);
    final name = _asStr(team['name']).trim();
    final cat = _asStr(team['category']).trim();
    final city = _asStr(team['city']).trim();
    final isSelected = selectedId == id;

    final logoUrl = MediaUtils.normalizeUrl(team['logo']?.toString());

    final Map<String, dynamic> s = styleData is Map<String, dynamic>
        ? styleData as Map<String, dynamic>
        : (styleData is Map ? Map<String, dynamic>.from(styleData) : {});

    final bgColor = s['bgColor'] != null
        ? _colorFromHex(s['bgColor'])
        : ClubDashboardPalette.white;

    final textColor = s['textColor'] != null
        ? _colorFromHex(s['textColor'])
        : ClubDashboardPalette.text;

    final subTextColor = s['subTextColor'] != null
        ? _colorFromHex(s['subTextColor'])
        : ClubDashboardPalette.textMuted;

    final iconBgColor = s['iconBgColor'] != null
        ? _colorFromHex(s['iconBgColor'])
        : ClubDashboardPalette.lightGreen;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(18),
            border: isSelected
                ? Border.all(
                    color: ClubDashboardPalette.primaryGreen.withOpacity(0.35),
                    width: 2,
                  )
                : Border.all(color: ClubDashboardPalette.border),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: ClubDashboardPalette.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: logoUrl != null
                    ? Image.network(
                        logoUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.group_outlined,
                          size: 20,
                          color: ClubDashboardPalette.primaryGreen,
                        ),
                      )
                    : Icon(
                        Icons.group_outlined,
                        size: 20,
                        color: ClubDashboardPalette.primaryGreen,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? 'Команда #$id' : name,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (cat.isNotEmpty) cat,
                        if (city.isNotEmpty) city,
                      ].join(' • '),
                      style: TextStyle(
                        color: subTextColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (onCustomize != null)
                InkWell(
                  onTap: onCustomize,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 34,
                    height: 34,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: ClubDashboardPalette.border),
                    ),
                    child: const Icon(Icons.palette_outlined, size: 16),
                  ),
                ),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: ClubDashboardPalette.border),
                ),
                child: Icon(
                  isSelected ? Icons.check_circle : Icons.chevron_right,
                  size: 18,
                  color: isSelected
                      ? ClubDashboardPalette.primaryGreen
                      : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}