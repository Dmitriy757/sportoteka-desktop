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

import 'controller/profile_controller.dart';

class ProfilePalette {
  // Единая CMR-палитра как в club_workspace_screen.dart:
  // светлый фон, чистые карточки и мягкие цветовые акценты по смыслу.
  static const black = Color(0xFF111827);
  static const graphite = Color(0xFF334155);

  static const primaryGreen = Color(0xFF178A45);
  static const primaryGreenDark = Color(0xFF0F6F36);
  static const primaryGreenLight = Color(0xFF22A75A);

  static const blue = Color(0xFF2563EB);
  static const blueSoft = Color(0xFFEFF6FF);
  static const purple = Color(0xFF7C3AED);
  static const purpleSoft = Color(0xFFF3E8FF);
  static const orange = Color(0xFFEA580C);
  static const orangeSoft = Color(0xFFFFF1E8);
  static const teal = Color(0xFF0F766E);
  static const tealSoft = Color(0xFFE6F6F4);
  static const red = Color(0xFFDC2626);
  static const redSoft = Color(0xFFFEE2E2);

  static const active = Color(0xFFF1F5F9);
  static const soft = Color(0xFFF8FAFC);
  static const soft2 = Color(0xFFFAFCFB);

  static const white = Color(0xFFFFFFFF);
  static const text = Color(0xFF0F172A);
  static const textMuted = Color(0xFF64748B);
  static const textLight = Color(0xFF94A3B8);
  static const background = Color(0xFFFBFBFA);
  static const card = Color(0xFFFFFFFF);
  static const border = Color(0xFFE7ECF2);

  static const lightGreen = Color(0xFFEAF5EE);
  static const superLightGreen = Color(0xFFF6FBF8);

  static const cleanShadow = BoxShadow(
    color: Color(0x0A000000),
    blurRadius: 20,
    offset: Offset(0, 10),
  );

  static const greenGradient = LinearGradient(
    colors: [primaryGreen, primaryGreenDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static Color softFor(Color color) {
    if (color == blue) return blueSoft;
    if (color == purple) return purpleSoft;
    if (color == orange) return orangeSoft;
    if (color == teal) return tealSoft;
    if (color == red) return redSoft;
    return lightGreen;
  }

  static Color accentForIcon(IconData icon) {
    if (icon == Icons.person_rounded ||
        icon == Icons.badge_outlined ||
        icon == Icons.edit_outlined ||
        icon == Icons.article_outlined) {
      return blue;
    }
    if (icon == Icons.groups_rounded ||
        icon == Icons.group_outlined ||
        icon == Icons.group_work_outlined ||
        icon == Icons.shield_outlined ||
        icon == Icons.dashboard_outlined ||
        icon == Icons.dashboard_customize_rounded) {
      return primaryGreen;
    }
    if (icon == Icons.stadium_outlined ||
        icon == Icons.calendar_today_outlined ||
        icon == Icons.directions_run_outlined) {
      return orange;
    }
    if (icon == Icons.emoji_events_outlined ||
        icon == Icons.auto_awesome_outlined ||
        icon == Icons.subscriptions_outlined) {
      return purple;
    }
    if (icon == Icons.settings_outlined ||
        icon == Icons.description_outlined ||
        icon == Icons.privacy_tip_outlined) {
      return teal;
    }
    if (icon == Icons.delete_forever_outlined || icon == Icons.logout_rounded) {
      return red;
    }
    return graphite;
  }
}
class ProfileText {
  static const h1 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.7,
    color: ProfilePalette.text,
    height: 1.08,
  );

  static const h2 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.3,
    color: ProfilePalette.text,
    height: 1.2,
  );

  static const h3 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w900,
    color: ProfilePalette.text,
    height: 1.2,
    letterSpacing: -0.2,
  );

  static const body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: ProfilePalette.text,
    height: 1.45,
  );

  static const caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: ProfilePalette.textMuted,
    height: 1.3,
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

  static const String apiBase = "https://sportotekaapp.ru/api";
  static const String getMyCoachTeamUrl = "$apiBase/get_my_team_by_coach.php";
  static const String getAssignedCoachTeamUrl = "$apiBase/get_trainer_team.php";
  static const String getPlayerTeamUrl = "$apiBase/get_player_team.php";
  static const String getClubTeamsUrl = "$apiBase/get_club_teams.php";

  String userRole = '';
  String firstName = '';
  String lastName = '';
  String email = '';
  String avatarUrl = '';

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

  bool myTeamLoading = false;
  bool clubTeamsLoading = false;
  int myTeamId = 0;
  int clubTeamsCount = 0;
  String myTeamName = "";
  String myTeamLogo = "";
  String myTeamCategory = "";

  bool assignedTeamLoading = false;
  int assignedTeamId = 0;
  String assignedTeamName = "";
  String assignedTeamLogo = "";
  String assignedTeamCategory = "";

  bool playerTeamLoading = false;
  int playerTeamId = 0;
  String playerTeamName = "";
  String playerTeamLogo = "";
  String playerTeamCategory = "";

  int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  Map<String, dynamic> _decode(http.Response r) {
    try {
      final body = r.body.trim();
      if (body.isEmpty) {
        return {"status": "error", "message": "EMPTY_BODY"};
      }
      final j = json.decode(body);
      if (j is Map<String, dynamic>) return j;
      if (j is Map) return Map<String, dynamic>.from(j);
    } catch (_) {}
    return {"status": "error"};
  }

  String _normalizeFileUrl(String raw) {
    var s = raw.trim();
    if (s.isEmpty || s == 'null') return "";
    if (s.startsWith("http://") || s.startsWith("https://")) return s;
    if (!s.startsWith("/")) s = "/$s";
    return "https://sportotekaapp.ru$s";
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

  bool _isTablet(double width) => width >= 700;

  int _bannerColumns(double width) {
    if (width >= 1280) return 4;
    if (width >= 900) return 3;
    if (width >= 700) return 2;
    return 2;
  }

  double _bannerAspectRatio(double width) {
    if (width >= 1280) return 1.28;
    if (width >= 900) return 1.18;
    if (width >= 700) return 1.10;
    return 1.18;
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _loadUserData();
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

    if (isClub) {
    await _loadClubTeamsCount();
    }

    if (isCoach) {
      await _loadMyCoachTeam();
      await _loadAssignedCoachTeam();
    }
    if (isPlayer) {
      await _loadPlayerTeam();
    }
  }
  
  
  Future<void> _loadClubTeamsCount() async {
  final userId = controller.currentUserId;
  if (userId == 0) return;

  if (mounted) setState(() => clubTeamsLoading = true);

  try {
    final resp = await http.post(
      Uri.parse(getClubTeamsUrl),
      body: {
        "club_id": userId.toString(),
      },
    ).timeout(const Duration(seconds: 12));

    final data = _decode(resp);

    final raw = data["teams"] ?? data["data"] ?? data["items"];

    int count = 0;

    if (raw is List) {
      count = raw.length;
    } else {
      count = _asInt(
        data["teams_count"] ??
            data["count"] ??
            data["total"] ??
            data["total_teams"],
      );
    }

    if (mounted) {
      setState(() {
        clubTeamsCount = count;
        clubTeamsLoading = false;
      });
    }
  } catch (e) {
    debugPrint("PROFILE _loadClubTeamsCount error: $e");
    if (mounted) {
      setState(() => clubTeamsLoading = false);
    }
  }
}

  Future<void> _loadMyCoachTeam() async {
    final userId = controller.currentUserId;
    if (userId == 0) return;
    if (mounted) setState(() => myTeamLoading = true);

    try {
      final resp = await http.post(
        Uri.parse(getMyCoachTeamUrl),
        body: {"trainer_id": userId.toString()},
      );
      Map<String, dynamic> j;
      try {
        j = json.decode(resp.body) as Map<String, dynamic>;
      } catch (_) {
        j = {"success": false};
      }
      if (j["success"] == true && j["team"] is Map) {
        final team = Map<String, dynamic>.from(j["team"]);
        myTeamId = _asInt(team["id"]);
        myTeamName = (team["name"] ?? "").toString();
        myTeamCategory = (team["category"] ?? "").toString();
        myTeamLogo = _normalizeFileUrl((team["logo"] ?? "").toString());
      } else {
        myTeamId = 0;
        myTeamName = "";
        myTeamCategory = "";
        myTeamLogo = "";
      }
    } catch (_) {
      //
    } finally {
      if (mounted) setState(() => myTeamLoading = false);
    }
  }

  Future<void> _loadAssignedCoachTeam() async {
    final userId = controller.currentUserId;
    if (userId == 0) return;
    if (mounted) setState(() => assignedTeamLoading = true);

    try {
      final resp = await http.post(
        Uri.parse(getAssignedCoachTeamUrl),
        body: {"trainer_id": userId.toString()},
      );
      Map<String, dynamic> j;
      try {
        j = json.decode(resp.body) as Map<String, dynamic>;
      } catch (_) {
        j = {"success": false};
      }
      if (j["success"] == true && j["team"] is Map) {
        final team = Map<String, dynamic>.from(j["team"]);
        assignedTeamId = _asInt(team["id"]);
        assignedTeamName = (team["name"] ?? "").toString();
        assignedTeamCategory = (team["category"] ?? "").toString();
        assignedTeamLogo = _normalizeFileUrl((team["logo"] ?? "").toString());
      } else {
        assignedTeamId = 0;
        assignedTeamName = "";
        assignedTeamCategory = "";
        assignedTeamLogo = "";
      }
    } catch (_) {
      //
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
          .get(Uri.parse("$getPlayerTeamUrl?user_id=$userId"))
          .timeout(const Duration(seconds: 12));

      debugPrint("PROFILE PLAYER TEAM RESPONSE: ${resp.body}");

      final data = _decode(resp);
      final ok = data["success"] == true || data["status"] == "success";

      if (!ok || data["team"] is! Map) {
        if (mounted) {
          setState(() {
            playerTeamId = 0;
            playerTeamName = "";
            playerTeamCategory = "";
            playerTeamLogo = "";
            playerTeamLoading = false;
          });
        }
        return;
      }

      final team = Map<String, dynamic>.from(data["team"]);

      if (mounted) {
        setState(() {
          playerTeamId = _asInt(team["team_id"] ?? team["id"]);
          playerTeamName = (team["team_name"] ?? team["name"] ?? "").toString();
          playerTeamCategory =
              (team["category"] ?? team["sport_type"] ?? "").toString();
          playerTeamLogo = _normalizeFileUrl(
            (team["team_logo"] ?? team["logo"] ?? "").toString(),
          );
          playerTeamLoading = false;
        });
      }
    } catch (e) {
      debugPrint("PROFILE _loadPlayerTeam error: $e");
      if (mounted) {
        setState(() {
          playerTeamId = 0;
          playerTeamName = "";
          playerTeamCategory = "";
          playerTeamLogo = "";
          playerTeamLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onEditAvatar() {
    Get.toNamed(AppRoutes.myProfileScreen)?.then((_) => _loadUserData());
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      Get.snackbar("Ошибка", "Не удалось открыть ссылку");
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final tablet = _isTablet(width);

    final banners = _getMenuBanners();
    final settingsItems = _getSettingsItems();
    final legalItems = _getLegalItems();

    return Scaffold(
      backgroundColor: ProfilePalette.background,
      appBar: _buildAppBar(tablet: tablet),
      body: FadeTransition(
        opacity: CurvedAnimation(
          parent: _animationController,
          curve: Curves.easeInOut,
        ),
        child: RefreshIndicator(
          onRefresh: _loadUserData,
          color: ProfilePalette.primaryGreen,
          child: tablet
              ? _buildTabletBody(width, banners, settingsItems, legalItems)
              : _buildPhoneBody(width, banners, settingsItems, legalItems),
        ),
      ),
      floatingActionButton: tablet ? null : _buildLogoutButton(),
    );
  }

  PreferredSizeWidget _buildAppBar({required bool tablet}) {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleSpacing: tablet ? 24 : 16,
      toolbarHeight: tablet ? 72 : kToolbarHeight,
      title: Row(
        children: [
          if (tablet) ...[
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: ProfilePalette.blueSoft,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: ProfilePalette.blue.withOpacity(.16)),
              ),
              child: const Icon(
                Icons.person_rounded,
                color: ProfilePalette.blue,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Text(
            tablet ? "Профиль CMR" : "Профиль",
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: ProfilePalette.text,
              fontSize: 18,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
      actions: [
        _SmallTopButton(
          icon: Icons.refresh_rounded,
          tooltip: 'Обновить',
          onTap: _loadUserData,
        ),
        if (tablet) ...[
          const SizedBox(width: 8),
          _SmallTopButton(
            icon: Icons.logout_rounded,
            tooltip: 'Выйти',
            danger: true,
            onTap: _showLogoutDialog,
          ),
        ],
        SizedBox(width: tablet ? 18 : 8),
      ],
    );
  }

  Widget _buildPhoneBody(
    double width,
    List<Map<String, dynamic>> banners,
    List<Map<String, dynamic>> settingsItems,
    List<Map<String, dynamic>> legalItems,
  ) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            children: [
              _buildTopProfileCard(tablet: false),
              const SizedBox(height: 16),
              _buildTeamsDashboardCard(tablet: false),
              if (isClub) ...[
                const SizedBox(height: 16),
                _buildClubBanner(),
              ],
              const SizedBox(height: 24),
              _buildSectionTitle("Быстрые действия"),
              const SizedBox(height: 12),
              _buildBannerGrid(width, banners),
              const SizedBox(height: 24),
              _buildSectionTitle("Настройки"),
              const SizedBox(height: 12),
              ...settingsItems.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildSettingsTile(item),
                ),
              ),
              const SizedBox(height: 24),
              _buildSectionTitle("Юридическая информация"),
              const SizedBox(height: 12),
              ...legalItems.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildLegalTile(item),
                ),
              ),
              const SizedBox(height: 24),
              _buildDeleteCard(),
              const SizedBox(height: 24),
              const SupportButton(),
              const SizedBox(height: 16),
              _buildVersionText(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabletBody(
    double width,
    List<Map<String, dynamic>> banners,
    List<Map<String, dynamic>> settingsItems,
    List<Map<String, dynamic>> legalItems,
  ) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1260),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: min(410, width * 0.36),
                child: Column(
                  children: [
                    _buildTopProfileCard(tablet: true),
                    const SizedBox(height: 14),
                    _buildTeamsDashboardCard(tablet: true),
                    if (isClub) ...[
                      const SizedBox(height: 14),
                      _buildClubBanner(),
                    ],
                    const SizedBox(height: 14),
                    _buildDeleteCard(compact: true),
                    const SizedBox(height: 14),
                    const SupportButton(),
                    const SizedBox(height: 12),
                    _buildVersionText(),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCmrOverviewStrip(),
                    const SizedBox(height: 14),
                    _buildSectionTitle("Быстрые действия"),
                    const SizedBox(height: 12),
                    _buildBannerGrid(width, banners),
                    const SizedBox(height: 18),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _buildSettingsBlock(
                            title: 'Настройки',
                            items: settingsItems,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _buildSettingsBlock(
                            title: 'Юридическая информация',
                            items: legalItems,
                            legal: true,
                          ),
                        ),
                      ],
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

  Widget _buildCmrOverviewStrip() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cleanDecoration(radius: 28),
      child: Row(
        children: [
          _iconBox(Icons.dashboard_customize_rounded),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Единый профиль пользователя',
                  style: TextStyle(
                    color: ProfilePalette.text,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Аккаунт, команды, быстрые модули, настройки и безопасность в одном CMR-экране.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: ProfileText.caption.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _buildStatusPill('Активен', green: true),
        ],
      ),
    );
  }

  Widget _buildBannerGrid(double width, List<Map<String, dynamic>> banners) {
    return GridView.builder(
      itemCount: banners.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: _bannerColumns(width),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: _bannerAspectRatio(width),
      ),
      itemBuilder: (context, index) => _buildMenuBanner(banners[index]),
    );
  }

  Widget _buildSettingsBlock({
    required String title,
    required List<Map<String, dynamic>> items,
    bool legal = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cleanDecoration(radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(title),
          const SizedBox(height: 12),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: legal ? _buildLegalTile(item) : _buildSettingsTile(item),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopProfileCard({required bool tablet}) {
    final fullName = "$firstName $lastName".trim().isEmpty
        ? "Пользователь"
        : "$firstName $lastName".trim();

    return Container(
      padding: EdgeInsets.all(tablet ? 18 : 16),
      decoration: _cleanDecoration(radius: 28),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: _onEditAvatar,
                child: _buildAvatar(radius: tablet ? 38 : 32, withBorder: true),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: ProfileText.h2.copyWith(
                        fontSize: tablet ? 22 : 18,
                        height: 1.08,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      email.isEmpty ? "Email не указан" : email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ProfileText.caption.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildRoleChip(_roleLabelRu(userRole)),
                        if (isPlayer && playerTeamName.isNotEmpty)
                          _buildInfoChip(Icons.group_outlined, playerTeamName),
                        if (isCoach && myTeamName.isNotEmpty)
                          _buildInfoChip(Icons.group_outlined, myTeamName),
                        if (isCoach &&
                            assignedTeamId > 0 &&
                            assignedTeamName.isNotEmpty &&
                            assignedTeamId != myTeamId)
                          _buildInfoChip(Icons.shield_outlined, assignedTeamName),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _buildStatChip(
                icon: Icons.badge_outlined,
                title: 'Роль',
                value: _roleLabelRu(userRole),
              ),
              const SizedBox(width: 10),
             _buildStatChip(
  icon: Icons.group_work_outlined,
  title: 'Команд',
  value: isClub
      ? (clubTeamsLoading ? '...' : '$clubTeamsCount')
      : isCoach
          ? '${(myTeamId > 0 ? 1 : 0) + (assignedTeamId > 0 && assignedTeamId != myTeamId ? 1 : 0)}'
          : isPlayer
              ? '${playerTeamId > 0 ? 1 : 0}'
              : '—',
),
              const SizedBox(width: 10),
              _buildStatChip(
                icon: Icons.verified_user_outlined,
                title: 'Статус',
                value: 'Активен',
                green: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String title,
    required String value,
    bool green = false,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: ProfilePalette.soft,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: ProfilePalette.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _smallIconBox(icon, green: green),
            const SizedBox(height: 10),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: ProfilePalette.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: ProfilePalette.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleChip(String text) {
    const accent = ProfilePalette.blue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: ProfilePalette.blueSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withOpacity(.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.badge_outlined,
            size: 14,
            color: accent,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 12,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 210),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: ProfilePalette.soft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ProfilePalette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: ProfilePalette.textMuted),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: ProfilePalette.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamsDashboardCard({required bool tablet}) {
    if (!isCoach && !isPlayer) return const SizedBox();

    final hasMyTeam = myTeamId > 0;
    final hasAssignedTeam = assignedTeamId > 0 && assignedTeamId != myTeamId;
    final hasPlayerTeam = playerTeamId > 0;

    final loading = (isCoach && (myTeamLoading || assignedTeamLoading)) ||
        (isPlayer && playerTeamLoading);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cleanDecoration(radius: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconBox(Icons.groups_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isPlayer ? 'Моя команда' : 'Мои команды',
                      style: ProfileText.h3.copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isPlayer
                          ? 'Команда, к которой привязан игрок'
                          : 'Управление личной и назначенной командой',
                      style: ProfileText.caption.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _buildStatusPill(
                isPlayer
                    ? '${hasPlayerTeam ? 1 : 0}'
                    : '${(hasMyTeam ? 1 : 0) + (hasAssignedTeam ? 1 : 0)}',
                green: true,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (loading)
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: ProfilePalette.soft,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: ProfilePalette.border),
              ),
              child: const Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: ProfilePalette.primaryGreen,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Загрузка информации о командах...',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: ProfilePalette.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            if (isCoach) ...[
              _buildTeamTile(
                title: 'Моя команда',
                subtitle: myTeamCategory.isEmpty ? 'Команда тренера' : myTeamCategory,
                teamName: myTeamName,
                logoUrl: myTeamLogo,
                badgeText: 'Моя',
                hasTeam: hasMyTeam,
                onTap: hasMyTeam
                    ? () => Get.toNamed(
                          "/myTeamScreen",
                          arguments: {"team_id": myTeamId, "mode": "coach_my"},
                        )
                    : () => Get.toNamed(AppRoutes.createTeamScreen),
                onCreateText: 'Создать команду',
              ),
              if (hasAssignedTeam) ...[
                const SizedBox(height: 10),
                _buildTeamTile(
                  title: 'Команда клуба',
                  subtitle: assignedTeamCategory.isEmpty
                      ? 'Назначена клубом'
                      : assignedTeamCategory,
                  teamName: assignedTeamName,
                  logoUrl: assignedTeamLogo,
                  badgeText: 'Club',
                  hasTeam: true,
                  onTap: () => Get.toNamed(
                    "/myTeamScreen",
                    arguments: {"team_id": assignedTeamId, "mode": "club_assigned"},
                  ),
                ),
              ],
            ],
            if (isPlayer)
              _buildTeamTile(
                title: 'Назначенная команда',
                subtitle:
                    playerTeamCategory.isEmpty ? 'Команда игрока' : playerTeamCategory,
                teamName: playerTeamName,
                logoUrl: playerTeamLogo,
                badgeText: 'Игрок',
                hasTeam: hasPlayerTeam,
                onTap: hasPlayerTeam
                    ? () => Get.toNamed(
                          "/myTeamScreen",
                          arguments: {"team_id": playerTeamId, "mode": "player_team"},
                        )
                    : null,
                onCreateText: 'Команда не назначена',
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildTeamTile({
    required String title,
    required String subtitle,
    required String teamName,
    required String logoUrl,
    required String badgeText,
    required bool hasTeam,
    required VoidCallback? onTap,
    String? onCreateText,
  }) {
    final hasLogo = logoUrl.trim().isNotEmpty;
    final accent = hasTeam ? ProfilePalette.primaryGreen : ProfilePalette.orange;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: ProfilePalette.soft2,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: accent.withOpacity(hasTeam ? .14 : .20)),
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: ProfilePalette.softFor(accent),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: accent.withOpacity(.16)),
                ),
                child: hasLogo
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Image.network(
                          logoUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.shield_outlined,
                            color: accent,
                            size: 28,
                          ),
                        ),
                      )
                    : Icon(
                        Icons.shield_outlined,
                        color: accent,
                        size: 28,
                      ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: ProfilePalette.textMuted,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: accent,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      hasTeam ? teamName : (onCreateText ?? '—'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: ProfilePalette.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: ProfilePalette.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: ProfilePalette.softFor(accent),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: accent.withOpacity(.16)),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: accent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: ProfilePalette.border),
                    ),
                    child: const Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: ProfilePalette.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClubBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ProfilePalette.blueSoft,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: ProfilePalette.blue.withOpacity(.16)),
        boxShadow: const [ProfilePalette.cleanShadow],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ProfilePalette.blue.withOpacity(.14)),
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: ProfilePalette.blue,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Режим клуба",
                  style: TextStyle(
                    color: ProfilePalette.text,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  "Управление командами, тренерами, расписанием и аналитикой.",
                  style: TextStyle(
                    color: ProfilePalette.textMuted,
                    fontSize: 12,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: ProfilePalette.blue.withOpacity(.14)),
            ),
            child: const Text(
              "CLUB",
              style: TextStyle(
                color: ProfilePalette.blue,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar({required double radius, bool withBorder = false}) {
    final size = radius * 2;
    final hasAvatar = avatarUrl.trim().isNotEmpty;

    Widget avatarContent = Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: ProfilePalette.active,
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
                  size: radius,
                  color: ProfilePalette.primaryGreen,
                ),
              ),
            )
          : Icon(
              Icons.person_rounded,
              size: radius,
              color: ProfilePalette.primaryGreen,
            ),
    );

    if (!withBorder) return avatarContent;

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: ProfilePalette.primaryGreen.withOpacity(.22),
        shape: BoxShape.circle,
      ),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: avatarContent,
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: ProfilePalette.textMuted,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getMenuBanners() {
    final List<Map<String, dynamic>> items = [
      _createMenuItem(
        title: "Мои посты",
        icon: Icons.article_outlined,
        accent: ProfilePalette.blue,
        onTap: () => Get.toNamed(AppRoutes.myProfileScreen),
      ),
      _createMenuItem(
        title: "Мои площадки",
        icon: Icons.stadium_outlined,
        accent: ProfilePalette.orange,
        onTap: () => Get.toNamed(AppRoutes.myGroundsScreen),
      ),
      _createMenuItem(
        title: "Бронирования",
        icon: Icons.calendar_today_outlined,
        accent: ProfilePalette.teal,
        onTap: () => Get.to(() => const BookingsForMyVenuesScreen()),
      ),
    ];

    if (isClub) {
      items.insert(
        0,
        _createMenuItem(
          title: "Панель клуба",
          icon: Icons.dashboard_outlined,
          accent: ProfilePalette.blue,
          onTap: () => Get.toNamed(AppRoutes.clubDashboardScreen),
        ),
      );
      return items;
    }

    items.addAll([
      _createMenuItem(
        title: "Тренировки",
        icon: Icons.directions_run_outlined,
        accent: ProfilePalette.orange,
        onTap: () => Get.to(() => const MyTrainingsScreen()),
      ),
      _createMenuItem(
        title: "Достижения",
        icon: Icons.emoji_events_outlined,
        accent: ProfilePalette.purple,
        onTap: () => Get.to(() => const AchievementsScreen()),
      ),
      _createMenuItem(
        title: "AR Тренировки",
        icon: Icons.auto_awesome_outlined,
        accent: ProfilePalette.purple,
        onTap: () => Get.to(() => const InnovationHistoryScreen()),
      ),
    ]);

    return items;
  }

  Map<String, dynamic> _createMenuItem({
    required String title,
    required IconData icon,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return {
      "title": title,
      "icon": icon,
      "accent": accent,
      "onTap": onTap,
    };
  }

  Widget _buildMenuBanner(Map<String, dynamic> item) {
    final accent = item['accent'] as Color;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: item['onTap'] as VoidCallback,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: ProfilePalette.border),
            boxShadow: const [ProfilePalette.cleanShadow],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: ProfilePalette.softFor(accent),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: accent.withOpacity(.14)),
                    ),
                    child: Icon(item['icon'] as IconData, size: 23, color: accent),
                  ),
                  const Spacer(),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: ProfilePalette.soft,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: ProfilePalette.border),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      color: ProfilePalette.textMuted,
                      size: 16,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                item['title'] as String,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  color: ProfilePalette.text,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getSettingsItems() {
    return [
      {
        "title": "Редактировать профиль",
        "icon": Icons.edit_outlined,
        "onTap": () =>
            Get.toNamed(AppRoutes.myProfileScreen)?.then((_) => _loadUserData()),
      },
      {
        "title": "Настройки приложения",
        "icon": Icons.settings_outlined,
        "onTap": () => Get.toNamed(AppRoutes.settingsScreen),
      },
      {
        "title": "Мои подписки",
        "icon": Icons.subscriptions_outlined,
        "onTap": () => Get.toNamed(AppRoutes.subscriptionsScreen),
      },
    ];
  }

  Widget _buildSettingsTile(Map<String, dynamic> item) {
    return _buildActionTile(
      title: item['title'] as String,
      icon: item['icon'] as IconData,
      onTap: item['onTap'] as VoidCallback,
    );
  }

  List<Map<String, dynamic>> _getLegalItems() {
    return [
      {
        "title": "Условия использования",
        "icon": Icons.description_outlined,
        "onTap": () => _openUrl(termsUrl),
      },
      {
        "title": "Политика конфиденциальности",
        "icon": Icons.privacy_tip_outlined,
        "onTap": () => _openUrl(privacyUrl),
      },
      {
        "title": "Правила сообщества",
        "icon": Icons.shield_outlined,
        "onTap": () => _openUrl(rulesUrl),
      },
    ];
  }

  Widget _buildLegalTile(Map<String, dynamic> item) {
    return _buildActionTile(
      title: item['title'] as String,
      icon: item['icon'] as IconData,
      onTap: item['onTap'] as VoidCallback,
    );
  }

  Widget _buildActionTile({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: ProfilePalette.border),
          ),
          child: Row(
            children: [
              _smallIconBox(icon),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: ProfilePalette.text,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 19,
                color: ProfilePalette.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteCard({bool compact = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: ListTile(
        onTap: () => _showDeleteAccountSheet(),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            Icons.delete_forever_outlined,
            size: 22,
            color: Colors.red.shade400,
          ),
        ),
        title: const Text(
          "Удалить аккаунт",
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: Colors.red,
          ),
        ),
        subtitle: compact
            ? null
            : const Text(
                "Навсегда удалить профиль и данные",
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF9CA3AF),
                  fontWeight: FontWeight.w600,
                ),
              ),
        trailing: Icon(
          Icons.chevron_right,
          size: 20,
          color: Colors.red.shade300,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [ProfilePalette.cleanShadow],
      ),
      child: FloatingActionButton(
        onPressed: _showLogoutDialog,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.red,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.logout, size: 22),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          insetPadding: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.logout, size: 36, color: Colors.red.shade400),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Выйти из аккаунта?",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Вы уверены, что хотите выйти?",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          side: const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        child: const Text(
                          "Отмена",
                          style: TextStyle(color: Colors.black),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          await _clearLocalAuth();
                          Get.offAllNamed(AppRoutes.loginScreen);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade400,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          "Выйти",
                          style: TextStyle(color: Colors.white),
                        ),
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
          builder: (context, setStateSB) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
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
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5E7EB),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 48,
                      color: Colors.red.shade400,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "Удаление аккаунта",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "Это действие необратимо. Ваш профиль, публикации и связанные данные будут удалены навсегда.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: agree,
                          onChanged: (v) =>
                              setStateSB(() => agree = v ?? false),
                          activeColor: Colors.red,
                        ),
                        const Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: Text(
                              "Я понимаю последствия и хочу удалить аккаунт навсегда.",
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              side: const BorderSide(color: Color(0xFFE5E7EB)),
                            ),
                            child: const Text("Отмена"),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: agree
                                ? () async {
                                    Navigator.pop(context);
                                    await _deleteAccount();
                                  }
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              disabledBackgroundColor: Colors.red.shade200,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              "Удалить навсегда",
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
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
        "Ошибка",
        "Не найден идентификатор пользователя.",
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
      );
      return;
    }

    Get.snackbar(
      "Удаление...",
      "Пожалуйста, подождите",
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(12),
      duration: const Duration(seconds: 2),
    );

    try {
      final resp = await http.post(
        Uri.parse(deleteAccountUrl),
        body: {'user_id': userId.toString()},
      );

      if (resp.statusCode == 200) {
        bool ok = false;
        String message = 'Аккаунт удалён.';

        try {
          final jsonBody = json.decode(resp.body);
          ok = jsonBody['success'] == true;
          if (jsonBody['message'] is String) {
            message = jsonBody['message'];
          }
        } catch (_) {
          ok = true;
        }

        if (ok) {
          await _clearLocalAuth();
          Get.snackbar(
            "Готово",
            message,
            snackPosition: SnackPosition.BOTTOM,
            margin: const EdgeInsets.all(12),
            duration: const Duration(seconds: 3),
          );
          Get.offAllNamed(AppRoutes.loginScreen);
        } else {
          Get.snackbar(
            "Ошибка",
            message,
            snackPosition: SnackPosition.BOTTOM,
            margin: const EdgeInsets.all(12),
          );
        }
      } else {
        Get.snackbar(
          "Ошибка",
          "Сервер вернул статус ${resp.statusCode}.",
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(12),
        );
      }
    } catch (_) {
      Get.snackbar(
        "Сеть недоступна",
        "Не удалось связаться с сервером. Повторите позже.",
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
        return 'Игрок';
      case 'coach':
      case 'trainer':
        return 'Тренер';
      case 'club':
        return 'Клуб';
      case 'parent':
        return 'Родитель';
      case 'federation':
        return 'Федерация';
      case 'school':
        return 'Школа';
      case 'student':
        return 'Ученик';
      default:
        return role.isEmpty ? 'Пользователь' : role;
    }
  }

  Widget _iconBox(
    IconData icon, {
    bool dark = false,
    bool green = false,
  }) {
    final accent = dark ? ProfilePalette.black : ProfilePalette.accentForIcon(icon);
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: dark ? ProfilePalette.black : ProfilePalette.softFor(accent),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: dark ? ProfilePalette.black : accent.withOpacity(.16),
        ),
      ),
      child: Icon(
        icon,
        size: 23,
        color: dark ? Colors.white : accent,
      ),
    );
  }

  Widget _smallIconBox(IconData icon, {bool green = false}) {
    final accent = green ? ProfilePalette.primaryGreen : ProfilePalette.accentForIcon(icon);
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: ProfilePalette.softFor(accent),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withOpacity(.16)),
      ),
      child: Icon(
        icon,
        size: 18,
        color: accent,
      ),
    );
  }

  Widget _buildStatusPill(String text, {bool green = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: green ? ProfilePalette.lightGreen : ProfilePalette.soft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: green
              ? ProfilePalette.primaryGreen.withOpacity(.16)
              : ProfilePalette.border,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: green ? ProfilePalette.primaryGreenDark : ProfilePalette.text,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }

  BoxDecoration _cleanDecoration({double radius = 24}) {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: ProfilePalette.border),
      boxShadow: const [ProfilePalette.cleanShadow],
    );
  }

  Widget _buildVersionText() {
    return Center(
      child: Text(
        "Версия 1.0.0",
        style: ProfileText.caption.copyWith(
          color: Colors.grey.shade500,
        ),
      ),
    );
  }
}

class _SmallTopButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool danger;

  const _SmallTopButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: danger ? Colors.red.shade50 : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: danger ? Colors.red.shade100 : ProfilePalette.border,
            ),
          ),
          child: Icon(
            icon,
            color: danger ? Colors.red : ProfilePalette.black,
            size: 21,
          ),
        ),
      ),
    );
  }
}
