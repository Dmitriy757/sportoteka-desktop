import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:sportoteka/core/app_export.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/presentation/achievements_screen/achievements_screen.dart';
import 'package:sportoteka/presentation/add_personal_training_screen/my_trainings_screen.dart';
import 'package:sportoteka/presentation/booking_screen/bookings_for_my_venues_screen.dart';
import 'package:sportoteka/presentation/innovation/history_screen.dart';
import 'package:sportoteka/widgets/support_button.dart';
import 'package:sportoteka/presentation/profile_screen/help_profile_screen.dart';

import 'controller/profile_controller.dart';

class ProfilePalette {
  static const background = Color(0xFFF6F8FA);
  static const card = Color(0xFFFFFFFF);
  static const text = Color(0xFF111827);
  static const muted = Color(0xFF667085);
  static const lightMuted = Color(0xFF98A2B3);
  static const border = Color(0xFFE4E7EC);
  static const borderSoft = Color(0xFFF0F2F5);

  static const green = Color(0xFF178A45);
  static const greenDark = Color(0xFF0F6F36);
  static const greenSoft = Color(0xFFEAF7EF);

  static const blue = Color(0xFF2563EB);
  static const blueSoft = Color(0xFFEFF6FF);
  static const orange = Color(0xFFEA580C);
  static const orangeSoft = Color(0xFFFFF4ED);
  static const purple = Color(0xFF7C3AED);
  static const purpleSoft = Color(0xFFF4EBFF);
  static const teal = Color(0xFF0F766E);
  static const tealSoft = Color(0xFFE6F6F4);
  static const red = Color(0xFFDC2626);
  static const redSoft = Color(0xFFFFEDED);

  static const shadow = BoxShadow(
    color: Color(0x08000000),
    blurRadius: 18,
    offset: Offset(0, 8),
  );

  static Color softFor(Color color) {
    if (color == blue) return blueSoft;
    if (color == orange) return orangeSoft;
    if (color == purple) return purpleSoft;
    if (color == teal) return tealSoft;
    if (color == red) return redSoft;
    return greenSoft;
  }
}

class ProfileText {
  static const title = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.6,
    height: 1.08,
    color: ProfilePalette.text,
  );

  static const section = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.2,
    color: ProfilePalette.text,
  );

  static const rowTitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w800,
    color: ProfilePalette.text,
    height: 1.15,
  );

  static const caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: ProfilePalette.muted,
    height: 1.25,
  );
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final ProfileController controller = Get.put(ProfileController());

  static const String deleteAccountUrl =
      'https://sportoteka.by/api/delete_account.php';
  static const String termsUrl = 'https://sportoteka.by/terms';
  static const String privacyUrl = 'https://sportoteka.by/privacy';
  static const String rulesUrl = 'https://sportoteka.by/community-rules';

  static const String apiBase = 'https://sportotekaapp.ru/api';
  static const String getMyCoachTeamUrl = '$apiBase/get_my_team_by_coach.php';
  static const String getAssignedCoachTeamUrl = '$apiBase/get_trainer_team.php';
  static const String getAssignedCoachTeamsUrl = '$apiBase/get_team_by_coach.php';
  static const String getPlayerTeamUrl = '$apiBase/get_player_team.php';
  static const String getClubTeamsUrl = '$apiBase/get_club_teams.php';

  String userRole = '';
  String firstName = '';
  String lastName = '';
  String email = '';
  String avatarUrl = '';

  bool myTeamLoading = false;
  bool clubTeamsLoading = false;
  int myTeamId = 0;
  int clubTeamsCount = 0;
  String myTeamName = '';
  String myTeamLogo = '';
  String myTeamCategory = '';

  bool assignedTeamLoading = false;

  // Назначенные клубом команды тренера.
  // Старые поля ниже оставлены как совместимость, если сервер пока отдаёт только одну team.
  final List<Map<String, dynamic>> assignedTeams = [];
  int assignedTeamId = 0;
  String assignedTeamName = '';
  String assignedTeamLogo = '';
  String assignedTeamCategory = '';

  bool playerTeamLoading = false;
  int playerTeamId = 0;
  String playerTeamName = '';
  String playerTeamLogo = '';
  String playerTeamCategory = '';

  late AnimationController _animationController;

  bool get isClub {
    final r = userRole.trim().toLowerCase();
    return r == 'club' || r == 'clubs' || r == 'клуб';
  }

  bool get isCoach {
    final r = userRole.trim().toLowerCase();
    return r == 'coach' || r == 'trainer' || r == 'тренер' || r == 'coaches';
  }

  bool get isPlayer {
    final r = userRole.trim().toLowerCase();
    return r == 'player' || r == 'игрок';
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    )..forward();
    _loadUserData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  Map<String, dynamic> _decode(http.Response r) {
    try {
      final body = r.body.trim();
      if (body.isEmpty) return {'status': 'error', 'message': 'EMPTY_BODY'};
      final j = json.decode(body);
      if (j is Map<String, dynamic>) return j;
      if (j is Map) return Map<String, dynamic>.from(j);
    } catch (_) {}
    return {'status': 'error'};
  }


  bool _isOkResponse(Map<String, dynamic> data) {
    final status = (data['status'] ?? '').toString().toLowerCase();
    return data['success'] == true || status == 'success' || status == 'ok';
  }

  List<Map<String, dynamic>> _extractListFromResponse(
    Map<String, dynamic> data,
    List<String> keys,
  ) {
    for (final key in keys) {
      final raw = data[key];
      if (raw is List) {
        return raw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      if (raw is Map) {
        final nested = _extractListFromResponse(
          Map<String, dynamic>.from(raw),
          keys,
        );
        if (nested.isNotEmpty) return nested;
      }
    }
    return <Map<String, dynamic>>[];
  }

  Map<String, dynamic> _normalizeAssignedTeam(Map<String, dynamic> raw) {
    final id = _asInt(raw['id'] ?? raw['team_id'] ?? raw['teamId']);
    final name = (raw['name'] ?? raw['team_name'] ?? raw['teamName'] ?? raw['title'] ?? '').toString();
    final category = (raw['category'] ?? raw['sport_type'] ?? raw['sport'] ?? raw['team_category'] ?? '').toString();
    final logo = _normalizeFileUrl((raw['logo'] ?? raw['logo_url'] ?? raw['team_logo'] ?? raw['teamLogo'] ?? '').toString());
    final clubId = _asInt(raw['club_id'] ?? raw['clubId']);
    final clubName = (raw['club_name'] ?? raw['clubName'] ?? '').toString();
    return {
      ...raw,
      'id': id,
      'team_id': id,
      'name': name,
      'team_name': name,
      'category': category,
      'logo': logo,
      'club_id': clubId,
      'club_name': clubName,
    };
  }

  List<Map<String, dynamic>> _uniqueAssignedTeams(List<Map<String, dynamic>> list) {
    final seen = <String>{};
    final out = <Map<String, dynamic>>[];
    for (final raw in list) {
      final item = _normalizeAssignedTeam(raw);
      final id = _asInt(item['id'] ?? item['team_id']);
      final name = (item['name'] ?? item['team_name'] ?? '').toString().trim().toLowerCase();
      final key = id > 0 ? 'id:$id' : 'name:$name';
      if (key == 'name:' || seen.contains(key)) continue;
      seen.add(key);
      out.add(item);
    }
    return out;
  }

  Map<String, dynamic>? _firstAssignedTeam() {
    if (assignedTeams.isNotEmpty) return assignedTeams.first;
    if (assignedTeamId > 0) {
      return {
        'id': assignedTeamId,
        'team_id': assignedTeamId,
        'name': assignedTeamName,
        'team_name': assignedTeamName,
        'category': assignedTeamCategory,
        'logo': assignedTeamLogo,
      };
    }
    return null;
  }

  VoidCallback _openAssignedTeam(Map<String, dynamic> team) {
    final teamId = _asInt(team['id'] ?? team['team_id']);
    final clubId = _asInt(team['club_id'] ?? team['clubId']);
    return () => Get.toNamed(
          '/myTeamScreen',
          arguments: {
            'team_id': teamId,
            'club_id': clubId,
            'mode': 'club_assigned',
          },
        );
  }

  VoidCallback _openTrainerWorkspace() {
    return () => Get.toNamed(
          AppRoutes.clubDashboardScreen,
          arguments: {
            'mode': 'trainer_assigned',
            'trainer_id': controller.currentUserId,
          },
        );
  }

  int _assignedTeamsCountExcludingMyTeam() {
    final ids = <int>{};
    for (final team in assignedTeams) {
      final id = _asInt(team['id'] ?? team['team_id']);
      if (id > 0 && id != myTeamId) ids.add(id);
    }
    if (ids.isEmpty && assignedTeamId > 0 && assignedTeamId != myTeamId) return 1;
    return ids.length;
  }

  String _normalizeFileUrl(String raw) {
    var s = raw.trim();
    if (s.isEmpty || s == 'null') return '';
    if (s.startsWith('http://') || s.startsWith('https://')) return s;
    if (!s.startsWith('/')) s = '/$s';
    return 'https://sportotekaapp.ru$s';
  }

  Future<String> _loadSavedAvatarUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final candidates = <String?>[
      prefs.getString('photo'),
      prefs.getString('photo_url'),
      prefs.getString('avatar'),
      prefs.getString('image'),
      prefs.getString('user_photo'),
      prefs.getString('user_avatar'),
      prefs.getString('profile_photo'),
      prefs.getString('profile_image'),
    ];

    for (final raw in candidates) {
      final normalized = _normalizeFileUrl(raw ?? '');
      if (normalized.isNotEmpty) return normalized;
    }
    return '';
  }

  Future<void> _loadUserData() async {
    controller.currentUserId = await PrefUtils.getUserId() ?? 0;

    final pref = PrefUtils();
    await pref.init();

    userRole = pref.getUserRole();
    firstName = pref.getUserFirstName();
    lastName = pref.getUserLastName();
    email = pref.getUserEmail();
    avatarUrl = await _loadSavedAvatarUrl();

    if (mounted) setState(() {});

    if (isClub) await _loadClubTeamsCount();
    if (isCoach) {
      await _loadMyCoachTeam();
      await _loadAssignedCoachTeam();
    }
    if (isPlayer) await _loadPlayerTeam();
  }

  Future<void> _loadClubTeamsCount() async {
    final userId = controller.currentUserId;
    if (userId == 0) return;
    if (mounted) setState(() => clubTeamsLoading = true);

    try {
      final resp = await http.post(
        Uri.parse(getClubTeamsUrl),
        body: {'club_id': userId.toString()},
      ).timeout(const Duration(seconds: 12));

      final data = _decode(resp);
      final raw = data['teams'] ?? data['data'] ?? data['items'];
      int count = 0;

      if (raw is List) {
        count = raw.length;
      } else {
        count = _asInt(
          data['teams_count'] ??
              data['count'] ??
              data['total'] ??
              data['total_teams'],
        );
      }

      if (mounted) {
        setState(() {
          clubTeamsCount = count;
          clubTeamsLoading = false;
        });
      }
    } catch (e) {
      debugPrint('PROFILE _loadClubTeamsCount error: $e');
      if (mounted) setState(() => clubTeamsLoading = false);
    }
  }

  Future<void> _loadMyCoachTeam() async {
    final userId = controller.currentUserId;
    if (userId == 0) return;
    if (mounted) setState(() => myTeamLoading = true);

    try {
      final resp = await http.post(
        Uri.parse(getMyCoachTeamUrl),
        body: {'trainer_id': userId.toString()},
      ).timeout(const Duration(seconds: 12));

      final j = _decode(resp);
      if (j['success'] == true && j['team'] is Map) {
        final team = Map<String, dynamic>.from(j['team']);
        myTeamId = _asInt(team['id']);
        myTeamName = (team['name'] ?? '').toString();
        myTeamCategory = (team['category'] ?? '').toString();
        myTeamLogo = _normalizeFileUrl((team['logo'] ?? '').toString());
      } else {
        myTeamId = 0;
        myTeamName = '';
        myTeamCategory = '';
        myTeamLogo = '';
      }
    } catch (e) {
      debugPrint('PROFILE _loadMyCoachTeam error: $e');
    } finally {
      if (mounted) setState(() => myTeamLoading = false);
    }
  }

  Future<void> _loadAssignedCoachTeam() async {
    final userId = controller.currentUserId;
    if (userId == 0) return;
    if (mounted) setState(() => assignedTeamLoading = true);

    try {
      Map<String, dynamic> data = {};

      // ВАЖНО: используем endpoint, который читает team_trainers
      // и возвращает все команды тренера, а не только созданную им команду.
      final multiResp = await http.post(
        Uri.parse('$getAssignedCoachTeamsUrl?coach_id=$userId&trainer_id=$userId'),
        body: {
          'coach_id': userId.toString(),
          'trainer_id': userId.toString(),
        },
      ).timeout(const Duration(seconds: 12));
      data = _decode(multiResp);
      debugPrint('PROFILE assigned teams response user=$userId status=${multiResp.statusCode} data=$data');

      var list = _extractListFromResponse(
        data,
        const ['teams', 'assigned_teams', 'data', 'items', 'result'],
      );
      if (list.isEmpty && _isOkResponse(data) && data['team'] is Map) {
        list = [Map<String, dynamic>.from(data['team'] as Map)];
      }

      // Совместимость со старым endpoint, если get_trainer_teams.php ещё не создан.
      if (list.isEmpty) {
        final singleResp = await http.post(
          Uri.parse(getAssignedCoachTeamUrl),
          body: {'trainer_id': userId.toString()},
        ).timeout(const Duration(seconds: 12));
        data = _decode(singleResp);
        list = _extractListFromResponse(
          data,
          const ['teams', 'assigned_teams', 'data', 'items', 'result'],
        );
        if (list.isEmpty && _isOkResponse(data) && data['team'] is Map) {
          list = [Map<String, dynamic>.from(data['team'] as Map)];
        }
      }

      final normalized = _uniqueAssignedTeams(list);

      assignedTeams
        ..clear()
        ..addAll(normalized);

      if (normalized.isNotEmpty) {
        final first = normalized.first;
        assignedTeamId = _asInt(first['id'] ?? first['team_id']);
        assignedTeamName = (first['name'] ?? first['team_name'] ?? '').toString();
        assignedTeamCategory = (first['category'] ?? '').toString();
        assignedTeamLogo = (first['logo'] ?? '').toString();
      } else {
        assignedTeamId = 0;
        assignedTeamName = '';
        assignedTeamCategory = '';
        assignedTeamLogo = '';
      }
    } catch (e) {
      debugPrint('PROFILE _loadAssignedCoachTeam error: $e');
      assignedTeams.clear();
      assignedTeamId = 0;
      assignedTeamName = '';
      assignedTeamCategory = '';
      assignedTeamLogo = '';
    } finally {
      if (mounted) setState(() => assignedTeamLoading = false);
    }
  }

  Future<void> _loadPlayerTeam() async {
    final userId = await PrefUtils.getUserId();
    if (userId == null || userId == 0) return;
    if (mounted) setState(() => playerTeamLoading = true);

    try {
      final resp = await http
          .get(Uri.parse('$getPlayerTeamUrl?user_id=$userId'))
          .timeout(const Duration(seconds: 12));

      final data = _decode(resp);
      final ok = data['success'] == true || data['status'] == 'success';

      if (!ok || data['team'] is! Map) {
        if (mounted) {
          setState(() {
            playerTeamId = 0;
            playerTeamName = '';
            playerTeamCategory = '';
            playerTeamLogo = '';
            playerTeamLoading = false;
          });
        }
        return;
      }

      final team = Map<String, dynamic>.from(data['team']);
      if (mounted) {
        setState(() {
          playerTeamId = _asInt(team['team_id'] ?? team['id']);
          playerTeamName = (team['team_name'] ?? team['name'] ?? '').toString();
          playerTeamCategory =
              (team['category'] ?? team['sport_type'] ?? '').toString();
          playerTeamLogo = _normalizeFileUrl(
            (team['team_logo'] ?? team['logo'] ?? '').toString(),
          );
          playerTeamLoading = false;
        });
      }
    } catch (e) {
      debugPrint('PROFILE _loadPlayerTeam error: $e');
      if (mounted) {
        setState(() {
          playerTeamId = 0;
          playerTeamName = '';
          playerTeamCategory = '';
          playerTeamLogo = '';
          playerTeamLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWideLayout = width >= 720;

    return Scaffold(
      backgroundColor: ProfilePalette.background,
      body: FadeTransition(
        opacity: CurvedAnimation(
          parent: _animationController,
          curve: Curves.easeOut,
        ),
        child: isWideLayout
            ? _desktopBody(width)
            : RefreshIndicator(
                color: ProfilePalette.green,
                onRefresh: _loadUserData,
                child: _mobileBody(),
              ),
      ),
    );
  }

  Widget _desktopBody(double width) {
    final isTablet = width < 1100;
    final leftWidth = isTablet ? 292.0 : 330.0;

    return SafeArea(
      top: false,
      bottom: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              isTablet ? 12 : 18,
              12,
              isTablet ? 12 : 18,
              12,
            ),
            child: SizedBox(
              height: constraints.maxHeight,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: leftWidth,
                    child: Column(
                      children: [
                        _accountCard(compact: true),
                        const SizedBox(height: 12),
                        _workspacePrimaryTile(compact: isTablet),
                        const SizedBox(height: 12),
                        Expanded(child: _desktopMiniInfoPanel()),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _desktopProfileMenuBoard(isTablet: isTablet),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _desktopProfileMenuBoard({required bool isTablet}) {
    final personalItems = _serviceItems()
        .where((item) => !item.title.toLowerCase().contains('панель'))
        .toList();

    return _plainCard(
      padding: EdgeInsets.fromLTRB(
        isTablet ? 14 : 18,
        isTablet ? 14 : 18,
        isTablet ? 14 : 18,
        isTablet ? 12 : 16,
      ),
      child: isTablet
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _desktopBoardTitle(
                  title: 'Меню профиля',
                  subtitle: 'Личные разделы отдельно, настройки вынесены в отдельный экран',
                  icon: Icons.tune_rounded,
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _desktopMenuSection(
                    title: 'Личные разделы',
                    rightLabel: '${personalItems.length}',
                    children: personalItems.map(_desktopMenuRow).toList(),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 86,
                  child: _desktopMenuSection(
                    title: 'Дополнительно',
                    compact: true,
                    children: [_desktopMenuRow(_profileHelpItem())],
                  ),
                ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 7,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _desktopBoardTitle(
                        title: 'Меню профиля',
                        subtitle: 'Посты, бронирования, тренировки и достижения в одном месте',
                        icon: Icons.tune_rounded,
                      ),
                      const SizedBox(height: 14),
                      Expanded(
                        child: _desktopMenuSection(
                          title: 'Личные разделы',
                          rightLabel: '${personalItems.length}',
                          children: personalItems.map(_desktopMenuRow).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                SizedBox(
                  width: 340,
                  child: _desktopSettingsPortalCard(),
                ),
              ],
            ),
    );
  }

  ProfileMenuItem _profileHelpItem() {
    return ProfileMenuItem(
      title: 'Настройки профиля',
      subtitle: 'Настройки, документы, поддержка и безопасность',
      icon: Icons.manage_accounts_outlined,
      accent: ProfilePalette.blue,
      onTap: _openProfileHelp,
    );
  }

  void _openProfileHelp() {
    Get.to(() => const HelpProfileScreen())?.then((_) => _loadUserData());
  }

  Widget _desktopSettingsPortalCard() {
    return _plainCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconBadge(Icons.manage_accounts_outlined, ProfilePalette.blue),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Настройки профиля', style: ProfileText.section),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Все служебные разделы вынесены отдельно: профиль, документы, поддержка и безопасность.',
            style: ProfileText.caption,
          ),
          const Spacer(),
          Material(
            color: ProfilePalette.blue,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _openProfileHelp,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                child: const Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Открыть настройки',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _workspacePrimaryTile({required bool compact}) {
    final title = isClub
        ? 'Панель клуба'
        : isCoach
            ? 'Панель команд'
            : isPlayer
                ? 'Панель игрока'
                : 'Рабочая панель';

    final subtitle = _workspaceSubtitle();
    VoidCallback? onTap = _workspaceOpenAction();

    return Material(
      color: ProfilePalette.green,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          height: compact ? 104 : 116,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              colors: [ProfilePalette.green, ProfilePalette.greenDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: compact ? 48 : 54,
                height: compact ? 48 : 54,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.16),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(.18)),
                ),
                child: Icon(
                  isClub ? Icons.apartment_rounded : Icons.dashboard_customize_outlined,
                  color: Colors.white,
                  size: compact ? 24 : 27,
                ),
              ),
              const SizedBox(width: 14),
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
                        color: Colors.white,
                        fontSize: compact ? 18 : 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.4,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(.84),
                        fontSize: 12,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white.withOpacity(.92),
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }

  VoidCallback? _workspaceOpenAction() {
    if (isClub) {
      return () => Get.toNamed(AppRoutes.clubDashboardScreen);
    }
    if (isCoach && (assignedTeams.isNotEmpty || assignedTeamId > 0)) {
      // В рабочей панели тренер увидит только назначенные ему команды.
      return _openTrainerWorkspace();
    }
    if (isCoach && myTeamId > 0) {
      return () => Get.toNamed('/myTeamScreen', arguments: {'team_id': myTeamId, 'mode': 'coach_my'});
    }
    if (isPlayer && playerTeamId > 0) {
      return () => Get.toNamed('/myTeamScreen', arguments: {'team_id': playerTeamId, 'mode': 'player_team'});
    }
    if (isCoach) {
      return () => Get.toNamed(AppRoutes.createTeamScreen);
    }
    return null;
  }

  String _workspaceSubtitle() {
    if (isClub) {
      return clubTeamsLoading ? 'Загрузка команд клуба...' : 'Команды, тренеры и управление клубом';
    }
    if (isCoach && myTeamName.trim().isNotEmpty) {
      return myTeamName.trim();
    }
    if (isCoach && assignedTeams.length > 1) {
      return 'Назначено команд: ${assignedTeams.length}';
    }
    if (isCoach && assignedTeamName.trim().isNotEmpty) {
      return assignedTeamName.trim();
    }
    if (isCoach) {
      return 'Команда ещё не назначена';
    }
    if (isPlayer && playerTeamName.trim().isNotEmpty) {
      return playerTeamName.trim();
    }
    return 'Главная рабочая зона аккаунта';
  }

  Widget _desktopMiniInfoPanel() {
    final rows = _workspaceRows();

    return _plainCard(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Доступ', style: ProfileText.section),
          const SizedBox(height: 8),
          Expanded(
            child: rows.isEmpty
                ? _emptyMiniRow(
                    isCoach ? 'Команда ещё не создана' : 'Панель не назначена',
                    isCoach ? 'Создать' : null,
                    isCoach ? () => Get.toNamed(AppRoutes.createTeamScreen) : null,
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: rows.length > 3 ? 3 : rows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, index) => rows[index],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _desktopBoardTitle({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Row(
      children: [
        _iconBadge(icon, ProfilePalette.green),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: ProfileText.title),
              const SizedBox(height: 3),
              Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: ProfileText.caption),
            ],
          ),
        ),
      ],
    );
  }

  Widget _desktopMenuSection({
    required String title,
    required List<Widget> children,
    String? rightLabel,
    bool compact = false,
  }) {
    return Container(
      padding: EdgeInsets.fromLTRB(12, compact ? 10 : 12, 12, compact ? 8 : 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ProfilePalette.borderSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: ProfileText.section)),
              if (rightLabel != null)
                Text(
                  rightLabel,
                  style: ProfileText.caption.copyWith(
                    color: ProfilePalette.lightMuted,
                    fontWeight: FontWeight.w900,
                  ),
                ),
            ],
          ),
          SizedBox(height: compact ? 4 : 6),
          Expanded(
            child: children.isEmpty
                ? _emptyMiniRow('Разделы пока недоступны', null, null)
                : Column(
                    children: [
                      for (int i = 0; i < children.length; i++) ...[
                        Expanded(child: children[i]),
                        if (i != children.length - 1)
                          const Divider(height: 1, color: ProfilePalette.borderSoft),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _desktopMenuRow(ProfileMenuItem item) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Row(
            children: [
              _smallIconBadge(item.icon, item.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ProfileText.rowTitle.copyWith(fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ProfileText.caption.copyWith(fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: ProfilePalette.lightMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _smallIconBadge(IconData icon, Color color) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: ProfilePalette.softFor(color),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  Widget _workspaceAccessPanel({required bool compact}) {
    final rows = _workspaceRows();

    return _plainCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconBadge(Icons.account_tree_outlined, ProfilePalette.green),
              const SizedBox(width: 10),
              const Expanded(child: Text('Рабочая зона', style: ProfileText.section)),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: rows.isEmpty
                ? _emptyMiniRow(
                    isCoach ? 'Команда ещё не создана' : 'Рабочая панель пока не назначена',
                    isCoach ? 'Создать' : null,
                    isCoach ? () => Get.toNamed(AppRoutes.createTeamScreen) : null,
                  )
                : ListView.separated(
                    padding: EdgeInsets.zero,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, index) => rows[index],
                  ),
          ),
        ],
      ),
    );
  }

  List<Widget> _workspaceRows() {
    final rows = <Widget>[];

    if (isClub) {
      rows.add(
        _teamLine(
          title: 'Панель клуба',
          subtitle: clubTeamsLoading ? 'Загрузка команд...' : 'Команды: $clubTeamsCount',
          logoUrl: '',
          icon: Icons.apartment_rounded,
          onTap: () => Get.toNamed(AppRoutes.clubDashboardScreen),
        ),
      );
    }

    if (isCoach) {
      rows.add(
        _teamLine(
          title: 'Панель команд',
          subtitle: assignedTeamLoading || myTeamLoading
              ? 'Загрузка команд...'
              : _workspaceSubtitle(),
          logoUrl: '',
          icon: Icons.dashboard_customize_outlined,
          onTap: _workspaceOpenAction() ?? () {},
        ),
      );

      if (myTeamId > 0) {
        rows.add(const SizedBox(height: 8));
        rows.add(
          _teamLine(
            title: myTeamName.isEmpty ? 'Панель команды' : myTeamName,
            subtitle: myTeamCategory.isEmpty ? 'Команда тренера' : myTeamCategory,
            logoUrl: myTeamLogo,
            icon: Icons.shield_outlined,
            onTap: () => Get.toNamed(
              '/myTeamScreen',
              arguments: {'team_id': myTeamId, 'mode': 'coach_my'},
            ),
          ),
        );
      }

      final assigned = assignedTeams.isNotEmpty
          ? assignedTeams
          : (_firstAssignedTeam() == null ? <Map<String, dynamic>>[] : <Map<String, dynamic>>[_firstAssignedTeam()!]);
      for (final team in assigned) {
        final teamId = _asInt(team['id'] ?? team['team_id']);
        if (teamId <= 0 || teamId == myTeamId) continue;
        rows.add(
          _teamLine(
            title: (team['name'] ?? team['team_name'] ?? 'Команда клуба').toString(),
            subtitle: (team['category'] ?? '').toString().trim().isEmpty
                ? 'Назначена клубом'
                : (team['category'] ?? '').toString(),
            logoUrl: (team['logo'] ?? team['team_logo'] ?? '').toString(),
            icon: Icons.group_work_outlined,
            onTap: null,
            showArrow: false,
          ),
        );
      }
    }

    if (isPlayer && playerTeamId > 0) {
      rows.add(
        _teamLine(
          title: playerTeamName.isEmpty ? 'Моя команда' : playerTeamName,
          subtitle: playerTeamCategory.isEmpty ? 'Команда игрока' : playerTeamCategory,
          logoUrl: playerTeamLogo,
          icon: Icons.shield_outlined,
          onTap: () => Get.toNamed(
            '/myTeamScreen',
            arguments: {'team_id': playerTeamId, 'mode': 'player_team'},
          ),
        ),
      );
    }

    return rows;
  }

  Widget _workspaceHeroButton() {
    final title = isClub
        ? 'Открыть панель клуба'
        : isCoach
            ? 'Открыть панель команд'
            : isPlayer
                ? 'Открыть мою команду'
                : 'Открыть рабочую панель';

    VoidCallback? onTap;
    if (isClub) {
      onTap = () => Get.toNamed(AppRoutes.clubDashboardScreen);
    } else if (isCoach && (assignedTeams.isNotEmpty || assignedTeamId > 0)) {
      onTap = _openTrainerWorkspace();
    } else if (isCoach && myTeamId > 0) {
      onTap = () => Get.toNamed('/myTeamScreen', arguments: {'team_id': myTeamId, 'mode': 'coach_my'});
    } else if (isPlayer && playerTeamId > 0) {
      onTap = () => Get.toNamed('/myTeamScreen', arguments: {'team_id': playerTeamId, 'mode': 'player_team'});
    } else if (isCoach) {
      onTap = () => Get.toNamed(AppRoutes.createTeamScreen);
    }

    return Material(
      color: ProfilePalette.green,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              colors: [ProfilePalette.green, ProfilePalette.greenDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.16),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(.18)),
                ),
                child: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _mainTeamLabel().isEmpty ? 'Команды, сервисы и управление' : _mainTeamLabel(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(.82),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
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

  Widget _desktopActionTile(ProfileMenuItem item) {
    return Material(
      color: ProfilePalette.softFor(item.accent),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: item.accent.withOpacity(.12)),
          ),
          child: Row(
            children: [
              _iconBadge(item.icon, item.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ProfileText.rowTitle,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: ProfileText.caption,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 20, color: ProfilePalette.lightMuted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _compactSettingsBlock() {
    final items = _settingsItems().take(2).toList();

    return _plainCard(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Настройки', style: ProfileText.section),
          const SizedBox(height: 6),
          Expanded(
            child: Column(
              children: [
                for (int i = 0; i < items.length; i++) ...[
                  Expanded(child: _profileRow(items[i])),
                  if (i != items.length - 1) const Divider(height: 1, color: ProfilePalette.borderSoft),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobileBody() {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _accountCard(compact: true),
              const SizedBox(height: 12),
              _teamSummaryCard(),
              const SizedBox(height: 12),
              _sectionCard(
                title: 'Сервисы',
                children: _serviceItems().map(_profileRow).toList(),
              ),
              const SizedBox(height: 12),
              _sectionCard(
                title: 'Настройки профиля',
                children: [_profileRow(_profileHelpItem())],
              ),
              const SizedBox(height: 16),
              _versionText(),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _accountCard({required bool compact}) {
    final fullName = '$firstName $lastName'.trim().isEmpty
        ? 'Пользователь'
        : '$firstName $lastName'.trim();

    return _plainCard(
      padding: EdgeInsets.all(compact ? 16 : 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: _openEditProfile,
                child: _avatar(size: compact ? 62 : 72),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: ProfileText.title.copyWith(
                        fontSize: compact ? 20 : 23,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      email.isEmpty ? 'Email не указан' : email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ProfileText.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pill(_roleLabelRu(userRole), Icons.badge_outlined),
              _pill('Активен', Icons.verified_user_outlined, green: true),
              if (_mainTeamLabel().isNotEmpty)
                _pill(_mainTeamLabel(), Icons.groups_outlined),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _primaryButton(
                  text: 'Редактировать',
                  icon: Icons.edit_outlined,
                  onTap: _openEditProfile,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _secondaryButton(
                  text: 'Настройки',
                  icon: Icons.settings_outlined,
                  onTap: _openProfileHelp,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _teamSummaryCard() {
    final loading = clubTeamsLoading || myTeamLoading || assignedTeamLoading || playerTeamLoading;
    final teamRows = _teamRows();

    return _plainCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconBadge(Icons.groups_rounded, ProfilePalette.green),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isClub ? 'Клуб' : 'Команда',
                  style: ProfileText.section,
                ),
              ),
              _smallCounter(_teamCountText()),
            ],
          ),
          const SizedBox(height: 12),
          if (loading)
            _loadingRow('Обновляем данные...')
          else if (teamRows.isEmpty)
            _emptyMiniRow(
              isCoach ? 'Команда не назначена' : 'Команда не назначена',
              isCoach ? 'Обновить' : null,
              isCoach ? _loadUserData : null,
            )
          else
            ...teamRows,
        ],
      ),
    );
  }

  List<Widget> _teamRows() {
    final rows = <Widget>[];

    if (isClub) {
      rows.add(
        _teamLine(
          title: 'Панель клуба',
          subtitle: clubTeamsLoading ? 'Загрузка...' : 'Команд: $clubTeamsCount',
          logoUrl: '',
          icon: Icons.dashboard_outlined,
          onTap: () => Get.toNamed(AppRoutes.clubDashboardScreen),
        ),
      );
      return rows;
    }

    if (isCoach) {
      rows.add(
        _teamLine(
          title: 'Панель команд',
          subtitle: assignedTeamLoading || myTeamLoading
              ? 'Загрузка команд...'
              : _workspaceSubtitle(),
          logoUrl: '',
          icon: Icons.dashboard_customize_outlined,
          onTap: _workspaceOpenAction() ?? () {},
        ),
      );

      if (myTeamId > 0) {
        rows.add(const SizedBox(height: 8));
        rows.add(
          _teamLine(
            title: myTeamName.isEmpty ? 'Моя команда' : myTeamName,
            subtitle: myTeamCategory.isEmpty ? 'Команда тренера' : myTeamCategory,
            logoUrl: myTeamLogo,
            icon: Icons.shield_outlined,
            onTap: () => Get.toNamed(
              '/myTeamScreen',
              arguments: {'team_id': myTeamId, 'mode': 'coach_my'},
            ),
          ),
        );
      }

      final assigned = assignedTeams.isNotEmpty
          ? assignedTeams
          : (_firstAssignedTeam() == null ? <Map<String, dynamic>>[] : <Map<String, dynamic>>[_firstAssignedTeam()!]);
      for (final team in assigned) {
        final teamId = _asInt(team['id'] ?? team['team_id']);
        if (teamId <= 0 || teamId == myTeamId) continue;
        if (rows.isNotEmpty) rows.add(const SizedBox(height: 8));
        rows.add(
          _teamLine(
            title: (team['name'] ?? team['team_name'] ?? 'Команда клуба').toString(),
            subtitle: (team['category'] ?? '').toString().trim().isEmpty
                ? 'Назначена клубом'
                : (team['category'] ?? '').toString(),
            logoUrl: (team['logo'] ?? team['team_logo'] ?? '').toString(),
            icon: Icons.group_work_outlined,
            onTap: null,
            showArrow: false,
          ),
        );
      }
    }

    if (isPlayer && playerTeamId > 0) {
      rows.add(
        _teamLine(
          title: playerTeamName.isEmpty ? 'Моя команда' : playerTeamName,
          subtitle: playerTeamCategory.isEmpty ? 'Команда игрока' : playerTeamCategory,
          logoUrl: playerTeamLogo,
          icon: Icons.shield_outlined,
          onTap: () => Get.toNamed(
            '/myTeamScreen',
            arguments: {'team_id': playerTeamId, 'mode': 'player_team'},
          ),
        ),
      );
    }

    return rows;
  }

  Widget _teamLine({
    required String title,
    required String subtitle,
    required String logoUrl,
    required IconData icon,
    VoidCallback? onTap,
    bool showArrow = true,
  }) {
    final content = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ProfilePalette.borderSoft),
      ),
      child: Row(
        children: [
          _teamAvatar(logoUrl, icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ProfileText.rowTitle,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ProfileText.caption,
                ),
              ],
            ),
          ),
          if (showArrow && onTap != null) ...[
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              size: 22,
              color: ProfilePalette.lightMuted,
            ),
          ],
        ],
      ),
    );

    return Material(
      color: const Color(0xFFFAFBFC),
      borderRadius: BorderRadius.circular(16),
      child: onTap == null
          ? content
          : InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onTap,
              child: content,
            ),
    );
  }

  Widget _teamAvatar(String logoUrl, IconData fallbackIcon) {
    final hasLogo = logoUrl.trim().isNotEmpty;
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: ProfilePalette.greenSoft,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: ProfilePalette.green.withOpacity(.12)),
      ),
      child: hasLogo
          ? ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                logoUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(
                  fallbackIcon,
                  color: ProfilePalette.green,
                  size: 22,
                ),
              ),
            )
          : Icon(fallbackIcon, color: ProfilePalette.green, size: 22),
    );
  }

  Widget _sectionCard({
    required String title,
    String? subtitle,
    required List<Widget> children,
  }) {
    return _plainCard(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: ProfileText.section)),
              if (children.isNotEmpty) _smallCounter('${children.length}'),
            ],
          ),
          if (subtitle != null && subtitle.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(subtitle, style: ProfileText.caption),
          ],
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _profileRow(ProfileMenuItem item) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: item.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              _iconBadge(item.icon, item.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ProfileText.rowTitle,
                    ),
                    if (item.subtitle.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        item.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ProfileText.caption,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: ProfilePalette.lightMuted,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<ProfileMenuItem> _serviceItems() {
    final items = <ProfileMenuItem>[];

    if (isClub) {
      items.add(
        ProfileMenuItem(
          title: 'Панель клуба',
          subtitle: 'Команды, тренеры и управление клубом',
          icon: Icons.dashboard_outlined,
          accent: ProfilePalette.green,
          onTap: () => Get.toNamed(AppRoutes.clubDashboardScreen),
        ),
      );
    }

    if (isCoach) {
      items.add(
        ProfileMenuItem(
          title: 'Панель команд',
          subtitle: assignedTeamLoading || myTeamLoading
              ? 'Загрузка команд...'
              : _workspaceSubtitle(),
          icon: Icons.dashboard_customize_outlined,
          accent: ProfilePalette.green,
          onTap: _workspaceOpenAction() ?? () {},
        ),
      );
    }

    items.addAll([
      ProfileMenuItem(
        title: 'Мои посты',
        subtitle: 'Публикации и личная страница',
        icon: Icons.article_outlined,
        accent: ProfilePalette.blue,
        onTap: () => Get.toNamed(AppRoutes.myProfileScreen),
      ),
      ProfileMenuItem(
        title: 'Мои площадки',
        subtitle: 'Созданные спортивные объекты',
        icon: Icons.stadium_outlined,
        accent: ProfilePalette.orange,
        onTap: () => Get.toNamed(AppRoutes.myGroundsScreen),
      ),
      ProfileMenuItem(
        title: 'Бронирования',
        subtitle: 'Заявки по моим площадкам',
        icon: Icons.calendar_today_outlined,
        accent: ProfilePalette.teal,
        onTap: () => Get.to(() => const BookingsForMyVenuesScreen()),
      ),
    ]);

    if (!isClub) {
      items.addAll([
        ProfileMenuItem(
          title: 'Тренировки',
          subtitle: 'Личные тренировки и история',
          icon: Icons.directions_run_outlined,
          accent: ProfilePalette.orange,
          onTap: () => Get.to(() => const MyTrainingsScreen()),
        ),
        ProfileMenuItem(
          title: 'Достижения',
          subtitle: 'Награды, результаты и прогресс',
          icon: Icons.emoji_events_outlined,
          accent: ProfilePalette.purple,
          onTap: () => Get.to(() => const AchievementsScreen()),
        ),
        ProfileMenuItem(
          title: 'AR тренировки',
          subtitle: 'История инновационных тренировок',
          icon: Icons.auto_awesome_outlined,
          accent: ProfilePalette.purple,
          onTap: () => Get.to(() => const InnovationHistoryScreen()),
        ),
      ]);
    }

    return items;
  }

  List<ProfileMenuItem> _settingsItems() {
    return [
      ProfileMenuItem(
        title: 'Редактировать профиль',
        subtitle: 'Фото, имя и данные аккаунта',
        icon: Icons.edit_outlined,
        accent: ProfilePalette.blue,
        onTap: _openEditProfile,
      ),
      ProfileMenuItem(
        title: 'Настройки приложения',
        subtitle: 'Уведомления и параметры',
        icon: Icons.settings_outlined,
        accent: ProfilePalette.teal,
        onTap: () => Get.toNamed(AppRoutes.settingsScreen),
      ),
      ProfileMenuItem(
        title: 'Мои подписки',
        subtitle: 'Тарифы и доступ к функциям',
        icon: Icons.subscriptions_outlined,
        accent: ProfilePalette.purple,
        onTap: () => Get.toNamed(AppRoutes.subscriptionsScreen),
      ),
    ];
  }

  List<ProfileMenuItem> _legalItems() {
    return [
      ProfileMenuItem(
        title: 'Условия использования',
        subtitle: 'Правила работы сервиса',
        icon: Icons.description_outlined,
        accent: ProfilePalette.teal,
        onTap: () => _openUrl(termsUrl),
      ),
      ProfileMenuItem(
        title: 'Политика конфиденциальности',
        subtitle: 'Как обрабатываются данные',
        icon: Icons.privacy_tip_outlined,
        accent: ProfilePalette.blue,
        onTap: () => _openUrl(privacyUrl),
      ),
      ProfileMenuItem(
        title: 'Правила сообщества',
        subtitle: 'Поведение и публикации',
        icon: Icons.shield_outlined,
        accent: ProfilePalette.green,
        onTap: () => _openUrl(rulesUrl),
      ),
    ];
  }

  Widget _supportCompactCard() {
    return _plainCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconBadge(Icons.support_agent_rounded, ProfilePalette.green),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Поддержка', style: ProfileText.section),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const SupportButton(),
        ],
      ),
    );
  }

  Widget _dangerSection() {
    return _plainCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Безопасность', style: ProfileText.section),
          const SizedBox(height: 8),
          _dangerRow(
            title: 'Выйти из аккаунта',
            subtitle: 'Завершить текущий сеанс',
            icon: Icons.logout_rounded,
            onTap: _showLogoutDialog,
          ),
          const Divider(height: 16, color: ProfilePalette.borderSoft),
          _dangerRow(
            title: 'Удалить аккаунт',
            subtitle: 'Навсегда удалить профиль и данные',
            icon: Icons.delete_forever_outlined,
            onTap: _showDeleteAccountSheet,
          ),
        ],
      ),
    );
  }

  Widget _dangerRow({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              _iconBadge(icon, ProfilePalette.red),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: ProfileText.rowTitle.copyWith(color: ProfilePalette.red),
                    ),
                    const SizedBox(height: 3),
                    Text(subtitle, style: ProfileText.caption),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: ProfilePalette.lightMuted,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _plainCard({required Widget child, EdgeInsets? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ProfilePalette.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: ProfilePalette.border),
        boxShadow: const [ProfilePalette.shadow],
      ),
      child: child,
    );
  }

  Widget _avatar({required double size}) {
    final hasAvatar = avatarUrl.trim().isNotEmpty;
    return Stack(
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: ProfilePalette.greenSoft,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [ProfilePalette.shadow],
          ),
          child: hasAvatar
              ? ClipOval(
                  child: Image.network(
                    avatarUrl,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.person_rounded,
                      size: size * .48,
                      color: ProfilePalette.green,
                    ),
                  ),
                )
              : Icon(
                  Icons.person_rounded,
                  size: size * .48,
                  color: ProfilePalette.green,
                ),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: ProfilePalette.green,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: const Icon(Icons.edit_rounded, size: 12, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _iconBadge(IconData icon, Color accent) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: ProfilePalette.softFor(accent),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: accent.withOpacity(.12)),
      ),
      child: Icon(icon, size: 20, color: accent),
    );
  }

  Widget _pill(String text, IconData icon, {bool green = false}) {
    final accent = green ? ProfilePalette.green : ProfilePalette.blue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: ProfilePalette.softFor(accent),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withOpacity(.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: accent),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 190),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: accent,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallCounter(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ProfilePalette.borderSoft),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: ProfilePalette.muted,
        ),
      ),
    );
  }

  Widget _loadingRow(String text) {
    return Row(
      children: [
        const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: ProfilePalette.green,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: ProfileText.caption)),
      ],
    );
  }

  Widget _emptyMiniRow(String text, String? actionText, VoidCallback? onTap) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFBFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ProfilePalette.borderSoft),
      ),
      child: Row(
        children: [
          Expanded(child: Text(text, style: ProfileText.caption)),
          if (actionText != null && onTap != null)
            TextButton(
              onPressed: onTap,
              style: TextButton.styleFrom(
                foregroundColor: ProfilePalette.green,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                actionText,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
        ],
      ),
    );
  }

  Widget _primaryButton({
    required String text,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: ProfilePalette.green,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
      ),
    );
  }

  Widget _secondaryButton({
    required String text,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        foregroundColor: ProfilePalette.text,
        side: const BorderSide(color: ProfilePalette.border),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
      ),
    );
  }

  Widget _versionText() {
    return Center(
      child: Text(
        'Версия 1.0.0',
        style: ProfileText.caption.copyWith(color: ProfilePalette.lightMuted),
      ),
    );
  }

  String _teamCountText() {
    if (isClub) return clubTeamsLoading ? '...' : '$clubTeamsCount';
    if (isCoach) {
      final count = (myTeamId > 0 ? 1 : 0) + _assignedTeamsCountExcludingMyTeam();
      return '$count';
    }
    if (isPlayer) return playerTeamId > 0 ? '1' : '0';
    return '0';
  }

  String _mainTeamLabel() {
    if (isClub) return clubTeamsLoading ? '' : 'Команд: $clubTeamsCount';
    if (isCoach && myTeamName.trim().isNotEmpty) return myTeamName.trim();
    if (isCoach && assignedTeams.length > 1) return 'Назначено команд: ${assignedTeams.length}';
    if (isCoach && assignedTeamName.trim().isNotEmpty) return assignedTeamName.trim();
    if (isPlayer && playerTeamName.trim().isNotEmpty) return playerTeamName.trim();
    return '';
  }

  void _openEditProfile() {
    Get.toNamed(AppRoutes.myProfileScreen)?.then((_) => _loadUserData());
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      Get.snackbar('Ошибка', 'Не удалось открыть ссылку');
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.all(24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _iconBadge(Icons.logout_rounded, ProfilePalette.red),
                const SizedBox(height: 14),
                const Text(
                  'Выйти из аккаунта?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: ProfilePalette.text,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'После выхода потребуется снова войти в приложение.',
                  textAlign: TextAlign.center,
                  style: ProfileText.caption,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          side: const BorderSide(color: ProfilePalette.border),
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
                        onPressed: () async {
                          await _clearLocalAuth();
                          Get.offAllNamed(AppRoutes.loginScreen);
                        },
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: ProfilePalette.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Выйти'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDeleteAccountSheet() {
    bool agree = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 12,
                bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 42,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 18),
                      decoration: BoxDecoration(
                        color: ProfilePalette.border,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    _iconBadge(Icons.warning_amber_rounded, ProfilePalette.red),
                    const SizedBox(height: 14),
                    const Text(
                      'Удалить аккаунт?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: ProfilePalette.text,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Это действие необратимо. Профиль и связанные данные будут удалены навсегда.',
                      textAlign: TextAlign.center,
                      style: ProfileText.caption,
                    ),
                    const SizedBox(height: 14),
                    Material(
                      color: const Color(0xFFFAFBFC),
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => setSheetState(() => agree = !agree),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: ProfilePalette.borderSoft),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Checkbox(
                                value: agree,
                                activeColor: ProfilePalette.red,
                                onChanged: (v) => setSheetState(() => agree = v ?? false),
                              ),
                              const Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(top: 10),
                                  child: Text(
                                    'Я понимаю последствия и хочу удалить аккаунт навсегда.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: ProfilePalette.text,
                                      height: 1.25,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: const BorderSide(color: ProfilePalette.border),
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
                            onPressed: agree
                                ? () async {
                                    Navigator.pop(context);
                                    await _deleteAccount();
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              elevation: 0,
                              backgroundColor: ProfilePalette.red,
                              disabledBackgroundColor: ProfilePalette.red.withOpacity(.35),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text('Удалить'),
                          ),
                        ),
                      ],
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

  Future<void> _deleteAccount() async {
    final userId = await PrefUtils.getUserId();

    if (userId == 0) {
      Get.snackbar(
        'Ошибка',
        'Не найден идентификатор пользователя.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
      );
      return;
    }

    Get.snackbar(
      'Удаление...',
      'Пожалуйста, подождите',
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(12),
      duration: const Duration(seconds: 2),
    );

    try {
      final resp = await http.post(
        Uri.parse(deleteAccountUrl),
        body: {'user_id': userId.toString()},
      ).timeout(const Duration(seconds: 12));

      if (resp.statusCode == 200) {
        bool ok = false;
        String message = 'Аккаунт удалён.';

        try {
          final jsonBody = json.decode(resp.body);
          ok = jsonBody['success'] == true;
          if (jsonBody['message'] is String) message = jsonBody['message'];
        } catch (_) {
          ok = true;
        }

        if (ok) {
          await _clearLocalAuth();
          Get.snackbar(
            'Готово',
            message,
            snackPosition: SnackPosition.BOTTOM,
            margin: const EdgeInsets.all(12),
            duration: const Duration(seconds: 3),
          );
          Get.offAllNamed(AppRoutes.loginScreen);
        } else {
          Get.snackbar(
            'Ошибка',
            message,
            snackPosition: SnackPosition.BOTTOM,
            margin: const EdgeInsets.all(12),
          );
        }
      } else {
        Get.snackbar(
          'Ошибка',
          'Сервер вернул статус ${resp.statusCode}.',
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(12),
        );
      }
    } catch (_) {
      Get.snackbar(
        'Сеть недоступна',
        'Не удалось связаться с сервером. Повторите позже.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
      );
    }
  }

  Future<void> _clearLocalAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(PrefUtils.userIdKey);
    await prefs.remove(PrefUtils.teamIdKey);
    await prefs.remove(PrefUtils.userRole);
    await prefs.remove(PrefUtils.userFirstName);
    await prefs.remove(PrefUtils.userLastName);
    await prefs.remove(PrefUtils.userEmail);
    await prefs.remove(PrefUtils.signIn);
  }

  String _roleLabelRu(String role) {
    final r = role.trim().toLowerCase();
    switch (r) {
      case 'player':
      case 'игрок':
        return 'Игрок';
      case 'coach':
      case 'trainer':
      case 'тренер':
        return 'Тренер';
      case 'club':
      case 'клуб':
        return 'Клуб';
      case 'parent':
      case 'родитель':
        return 'Родитель';
      case 'federation':
      case 'федерация':
        return 'Федерация';
      case 'school':
      case 'школа':
        return 'Школа';
      case 'student':
      case 'ученик':
        return 'Ученик';
      default:
        return role.isEmpty ? 'Пользователь' : role;
    }
  }
}

class ProfileMenuItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  const ProfileMenuItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
  });
}

class _TopIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool danger;

  const _TopIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? ProfilePalette.red : ProfilePalette.text;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: danger ? ProfilePalette.red.withOpacity(.18) : ProfilePalette.border,
              ),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
        ),
      ),
    );
  }
}
