import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sportoteka/core/app_export.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/presentation/achievements_screen/achievements_screen.dart';
import '../log_out_dialogue/log_out_dialogue.dart';
import 'controller/profile_controller.dart';
import 'package:sportoteka/presentation/booking_screen/bookings_for_my_venues_screen.dart';
import 'package:sportoteka/presentation/my_schools_screen/my_schools_screen.dart';
import 'package:sportoteka/presentation/students_by_trainer_screen/students_by_trainer_screen.dart';
import 'package:sportoteka/presentation/add_personal_training_screen/my_trainings_screen.dart';
import 'package:sportoteka/presentation/innovation/history_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final ProfileController controller = Get.put(ProfileController());

  String userRole = '';
  String firstName = '';
  String lastName = '';
  String email = '';

  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  Future<void> _loadUserData() async {
    controller.currentUserId = await PrefUtils.getUserId() ?? 0;

    final pref = PrefUtils();
    userRole = await pref.getUserRole() ?? '';
    firstName = await pref.getUserFirstName() ?? '';
    lastName = await pref.getUserLastName() ?? '';
    email = await pref.getUserEmail() ?? '';

    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onEditAvatar() {
    // Можешь заменить на bottom sheet выбора фото — сейчас просто переход
    Get.toNamed(AppRoutes.myProfileScreen);
  }

  @override
  Widget build(BuildContext context) {
    // если используешь где-то mediaQueryData из app_export
    mediaQueryData = MediaQuery.of(context);

    final bg = const Color(0xFFF3F5F8); // матовый фон как в каталоге школ

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
                backgroundImage: AssetImage('assets/images/avatar_placeholder.png'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "$firstName $lastName",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.black,
                    ),
                  ),
                  Text(
                    userRole.toUpperCase(),
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
            tooltip: 'Уведомления',
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_rounded, color: Colors.black87),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: FadeTransition(
        opacity: CurvedAnimation(
          parent: _animationController,
          curve: Curves.easeInOut,
        ),
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

            // ---------- БАННЕРЫ ПРОФИЛЯ ----------
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.4,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildMenuBanner(context, index),
                  childCount: _menuBanners().length,
                ),
              ),
            ),

            // ---------- МОИ АКТИВНОСТИ ----------
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              sliver: SliverToBoxAdapter(
                child: Text(
                  "Мои активности".toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onBackground.withOpacity(0.4),
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildActivityItem(context, index),
                  childCount: 6,
                ),
              ),
            ),

            // ---------- НАСТРОЙКИ ----------
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              sliver: SliverToBoxAdapter(
                child: Text(
                  "Настройки".toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onBackground.withOpacity(0.4),
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

            const SliverPadding(
              padding: EdgeInsets.symmetric(vertical: 24),
              sliver: SliverToBoxAdapter(
                child: Center(
                  child: Text(
                    "Версия 1.0.0",
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildLogoutButton(context),
    );
  }

  // ---------- ДАННЫЕ ДЛЯ БАННЕРОВ ----------

  List<Map<String, dynamic>> _menuBanners() {
    return [
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
        "title": "Инновации",
        "icon": Icons.auto_awesome_outlined,
        "color": Colors.amber.shade50,
        "iconColor": Colors.amber.shade700,
        "onTap": () => Get.to(() => const InnovationHistoryScreen()),
      },
    ];
  }

  Widget _buildMenuBanner(BuildContext context, int index) {
    final item = _menuBanners()[index];
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
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item['icon'], size: 24, color: item['iconColor']),
              ),
              const SizedBox(height: 8),
              Text(
                item['title'],
                style: TextStyle(
                  fontWeight: FontWeight.w700,
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

  // ---------- СПИСКИ/АКТИВНОСТИ/НАСТРОЙКИ ----------

  Widget _buildActivityItem(BuildContext context, int index) {
    final List<Map<String, dynamic>> activities = [
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
        "onTap": () =>
            Get.to(() => StudentsByTrainerScreen(trainerId: controller.currentUserId)),
      },
    ];

    final item = activities[index];
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
          child: Icon(item['icon'], size: 20, color: Theme.of(context).primaryColor),
        ),
        title: Text(
          item['title'],
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        trailing: Icon(Icons.chevron_right, size: 20, color: Colors.grey.shade600),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildSettingsItem(BuildContext context, int index) {
    final List<Map<String, dynamic>> settings = [
      {
        "title": "Редактировать профиль",
        "icon": Icons.edit_outlined,
        "color": Colors.grey.shade100,
        "onTap": () => Get.toNamed(AppRoutes.myProfileScreen),
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
          child: Icon(item['icon'], size: 20, color: Theme.of(context).primaryColor),
        ),
        title: Text(
          item['title'],
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        trailing: Icon(Icons.chevron_right, size: 20, color: Colors.grey.shade600),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  // ---------- ЛОГАУТ ----------

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
                    color: Theme.of(context).colorScheme.onBackground.withOpacity(0.6),
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
                        onPressed: () => Get.offAllNamed(AppRoutes.loginScreen),
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
}
