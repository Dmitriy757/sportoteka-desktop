// lib/presentation/profile_screen/profile_screen.dart
import 'dart:convert';

import 'package:flutter/material.dart';
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
import 'package:sportoteka/presentation/my_schools_screen/my_schools_screen.dart';
import 'package:sportoteka/presentation/students_by_trainer_screen/students_by_trainer_screen.dart';
import 'package:sportoteka/widgets/support_button.dart';

import 'controller/profile_controller.dart';

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

  String userRole = '';
  String firstName = '';
  String lastName = '';
  String email = '';

  late AnimationController _animationController;

  // ✅ поддержим разные варианты строки роли
  bool get isClub {
    final r = userRole.trim().toLowerCase();
    return r == 'club' || r == 'clubs' || r == 'клуб';
  }

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
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

    if (mounted) setState(() {});
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
    mediaQueryData = MediaQuery.of(context);
    final bg = const Color(0xFFF3F5F8);
    final primary = Theme.of(context).colorScheme.primary;

    final banners = _menuBanners(context);
    final activities = _activitiesForRole(context);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: bg,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 16,
        title: Row(
          children: [
            GestureDetector(
              onTap: _onEditAvatar,
              child: const CircleAvatar(
                radius: 20,
                backgroundImage:
                    AssetImage('assets/images/avatar_placeholder.png'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "$firstName $lastName".trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                  Text(
                    userRole.isEmpty ? "" : userRole.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            onPressed: _loadUserData,
            icon: const Icon(Icons.refresh_rounded, color: Colors.black87),
          ),
          IconButton(
            tooltip: 'Уведомления',
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_rounded,
                color: Colors.black87),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: FadeTransition(
        opacity: CurvedAnimation(
          parent: _animationController,
          curve: Curves.easeInOut,
        ),
        child: RefreshIndicator(
          onRefresh: _loadUserData,
          child: CustomScrollView(
            slivers: [
              // email под хедером
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  child: Center(
                    child: Text(
                      email,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ),
              ),

              // ✅ аккуратный баннер клуба (без "coming soon" мусора)
              if (isClub)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          colors: [
                            primary.withOpacity(0.95),
                            primary.withOpacity(0.60),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 18,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.shield_outlined,
                                color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Режим клуба",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  "Управление командами, тренерами, расписанием и аналитикой — в панели клуба.",
                                  style: TextStyle(
                                    color: Color(0xEFFFFFFF),
                                    fontSize: 12,
                                    height: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              "CLUB",
                              style: TextStyle(
                                color: primary,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // ---------- БАННЕРЫ ПРОФИЛЯ ----------
              SliverPadding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                sliver: SliverGrid(
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.4,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) =>
                        _buildMenuBanner(context, banners[index]),
                    childCount: banners.length,
                  ),
                ),
              ),

              // ---------- МОИ АКТИВНОСТИ ----------
if (activities.isNotEmpty) ...[
  SliverPadding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    sliver: SliverToBoxAdapter(
      child: Text(
        (isClub ? "Панель клуба" : "Мои активности").toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Theme.of(context)
              .colorScheme
              .onBackground
              .withOpacity(0.4),
          letterSpacing: 1.2,
        ),
      ),
    ),
  ),
  SliverPadding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    sliver: SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) =>
            _buildActivityTile(context, activities[index]),
        childCount: activities.length,
      ),
    ),
  ),
],

              // ---------- НАСТРОЙКИ ----------
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    "Настройки".toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context)
                          .colorScheme
                          .onBackground
                          .withOpacity(0.4),
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildSettingsItem(context, index),
                    childCount: 2,
                  ),
                ),
              ),

              // ---------- ЮРИДИЧЕСКАЯ ИНФОРМАЦИЯ ----------
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    "Юридическая информация".toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context)
                          .colorScheme
                          .onBackground
                          .withOpacity(0.4),
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildLegalItem(context, index),
                    childCount: 3,
                  ),
                ),
              ),

              // ---------- ОПАСНАЯ ЗОНА / УДАЛИТЬ АККАУНТ ----------
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                sliver: SliverToBoxAdapter(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.red.shade100),
                    ),
                    child: ListTile(
                      onTap: () => _showDeleteAccountSheet(context),
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.delete_forever_outlined,
                            size: 22, color: Colors.red.shade400),
                      ),
                      title: const Text(
                        "Удалить аккаунт",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.red,
                        ),
                      ),
                      subtitle: const Text(
                        "Навсегда удалить профиль и данные",
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                      trailing: Icon(Icons.chevron_right,
                          size: 20, color: Colors.red.shade300),
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SupportButton()),

              SliverPadding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: Text(
                      "Версия 1.0.0",
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildLogoutButton(context),
    );
  }

  // ============================================================
  // БАННЕРЫ
  // ============================================================

  List<Map<String, dynamic>> _menuBanners(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    if (isClub) {
      return [
        {
          "title": "Панель клуба",
          "icon": Icons.dashboard_outlined,
          "color": Colors.indigo.shade50,
          "iconColor": primary,
          "onTap": () => Get.toNamed(AppRoutes.clubDashboardScreen),
        },
        {
          "title": "Мои посты",
          "icon": Icons.article_outlined,
          "color": Colors.lightBlue.shade50,
          "iconColor": primary,
          "onTap": () => Get.toNamed(AppRoutes.myProfileScreen),
        },
        {
          "title": "Мои площадки",
          "icon": Icons.stadium_outlined,
          "color": Colors.blue.shade50,
          "iconColor": primary,
          "onTap": () => Get.toNamed(AppRoutes.myGroundsScreen),
        },
        {
          "title": "Бронирования",
          "icon": Icons.book_online_outlined,
          "color": Colors.green.shade50,
          "iconColor": primary,
          "onTap": () => Get.to(() => const BookingsForMyVenuesScreen()),
        },
      ];
    }

    return [
      {
        "title": "Мои посты",
        "icon": Icons.article_outlined,
        "color": Colors.lightBlue.shade50,
        "iconColor": Colors.lightBlue.shade700,
        "onTap": () => Get.toNamed(AppRoutes.myProfileScreen),
      },
      {
        "title": "Мои площадки",
        "icon": Icons.stadium_outlined,
        "color": Colors.blue.shade50,
        "iconColor": Colors.blue.shade700,
        "onTap": () => Get.toNamed(AppRoutes.myGroundsScreen),
      },
      {
        "title": "Бронирования",
        "icon": Icons.calendar_today_outlined,
        "color": Colors.green.shade50,
        "iconColor": Colors.green.shade700,
        "onTap": () => Get.toNamed('/myBookingsScreen'),
      },
      {
        "title": "Тренировки",
        "icon": Icons.directions_run_outlined,
        "color": Colors.orange.shade50,
        "iconColor": Colors.orange.shade700,
        "onTap": () => Get.to(() => const MyTrainingsScreen()),
      },
      {
        "title": "Достижения",
        "icon": Icons.emoji_events_outlined,
        "color": Colors.purple.shade50,
        "iconColor": Colors.purple.shade700,
        "onTap": () => Get.to(() => const AchievementsScreen()),
      },
      {
        "title": "AR Тренировки",
        "icon": Icons.auto_awesome_outlined,
        "color": Colors.amber.shade50,
        "iconColor": Colors.amber.shade700,
        "onTap": () => Get.to(() => const InnovationHistoryScreen()),
      },
    ];
  }

  Widget _buildMenuBanner(BuildContext context, Map<String, dynamic> item) {
    return Material(
      color: item['color'],
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: item['onTap'],
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(item['icon'], size: 24, color: item['iconColor']),
                  ),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                item['title'],
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onBackground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // АКТИВНОСТИ
  // ============================================================

  List<Map<String, dynamic>> _activitiesForRole(BuildContext context) {
  if (isClub) {
    // ✅ НЕ дублируем баннеры под ними
    return [];
  }

  return [
    {
      "title": "Бронирования площадок",
      "icon": Icons.book_online_outlined,
      "color": Colors.blue.shade50,
      "onTap": () => Get.to(() => const BookingsForMyVenuesScreen()),
    },
    {
      "title": "Моя команда",
      "icon": Icons.group_outlined,
      "color": Colors.teal.shade50,
      "onTap": () => Get.toNamed("/myTeamScreen"),
    },
    {
      "title": "Создать команду",
      "icon": Icons.add_circle_outlined,
      "color": Colors.cyan.shade50,
      "onTap": () => Get.toNamed(AppRoutes.createTeamScreen),
    },
    {
      "title": "Добавить игрока",
      "icon": Icons.person_add_alt_outlined,
      "color": Colors.indigo.shade50,
      "onTap": () => Get.toNamed(AppRoutes.addPlayerScreen),
    },
    {
      "title": "Мои школы",
      "icon": Icons.school_outlined,
      "color": Colors.deepPurple.shade50,
      "onTap": () => Get.toNamed(AppRoutes.mySchoolsScreen),
    },
    {
      "title": "Ученики по школам",
      "icon": Icons.people_alt_outlined,
      "color": Colors.pink.shade50,
      "onTap": () => Get.to(
        () => StudentsByTrainerScreen(trainerId: controller.currentUserId),
      ),
    },
  ];
}

  Widget _buildActivityTile(BuildContext context, Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: item['color'],
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: item['onTap'],
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            item['icon'],
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(
          item['title'],
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        trailing:
            Icon(Icons.chevron_right, size: 20, color: Colors.grey.shade600),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  // ============================================================
  // НАСТРОЙКИ / ЮРИДИЧЕСКИЕ / ЛОГАУТ / УДАЛЕНИЕ
  // ============================================================

  Widget _buildSettingsItem(BuildContext context, int index) {
    final List<Map<String, dynamic>> settings = [
      {
        "title": "Редактировать профиль",
        "icon": Icons.edit_outlined,
        "color": Colors.grey.shade100,
        "onTap": () =>
            Get.toNamed(AppRoutes.myProfileScreen)?.then((_) => _loadUserData()),
      },
      {
        "title": "Настройки приложения",
        "icon": Icons.settings_outlined,
        "color": Colors.grey.shade100,
        "onTap": () => Get.toNamed(AppRoutes.settingsScreen),
      },
    ];

    final item = settings[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: item['color'],
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: item['onTap'],
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(item['icon'],
              size: 20, color: Theme.of(context).colorScheme.primary),
        ),
        title: Text(
          item['title'],
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        trailing:
            Icon(Icons.chevron_right, size: 20, color: Colors.grey.shade600),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildLegalItem(BuildContext context, int index) {
    final items = [
      {
        "title": "Условия использования (EULA)",
        "icon": Icons.description_outlined,
        "onTap": () => _openUrl(termsUrl),
      },
      {
        "title": "Политика конфиденциальности",
        "icon": Icons.privacy_tip_outlined,
        "onTap": () => _openUrl(privacyUrl),
      },
      {
        "title": "Правила сообщества (нулевая терпимость)",
        "icon": Icons.shield_outlined,
        "onTap": () => _openUrl(rulesUrl),
      },
    ];

    final item = items[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        onTap: item['onTap'] as void Function()?,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            item['icon'] as IconData,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        title: Text(
          item['title'] as String,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        trailing:
            Icon(Icons.chevron_right, size: 20, color: Colors.grey.shade600),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => _showLogoutDialog(context),
      backgroundColor: Colors.white,
      elevation: 2,
      mini: true,
      child: Icon(Icons.logout, size: 20, color: Colors.red.shade400),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
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
                Text(
                  "Выйти из аккаунта?",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onBackground,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Вы уверены, что хотите выйти?",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onBackground
                        .withOpacity(0.6),
                  ),
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
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(
                            color: Theme.of(context).dividerColor,
                          ),
                        ),
                        child: Text(
                          "Отмена",
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onBackground,
                          ),
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
                            borderRadius: BorderRadius.circular(12),
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

  void _showDeleteAccountSheet(BuildContext context) {
    bool agree = false;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                    Icon(Icons.warning_amber_rounded,
                        size: 42, color: Colors.red.shade400),
                    const SizedBox(height: 12),
                    const Text(
                      "Удаление аккаунта",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Это действие необратимо. Ваш профиль, публикации и связанные данные будут удалены навсегда.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
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
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
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
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
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
    final userId = controller.currentUserId;
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
      isDismissible: true,
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
    } catch (e) {
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
}
