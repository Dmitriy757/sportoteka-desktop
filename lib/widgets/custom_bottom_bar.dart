// lib/widgets/custom_bottom_bar.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:sportoteka/presentation/home_page/home_page.dart';
import 'package:sportoteka/presentation/add_personal_training_screen/add_personal_training_screen.dart';
import 'package:sportoteka/presentation/service_screens/calendar_event_screen.dart';
import 'package:sportoteka/presentation/chat_screen/chat_screen.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/presentation/community_screen/sport_community_screen.dart';
import 'package:sportoteka/presentation/community_screen/create_post_editor_screen.dart';

enum BottomBarTab { Home, Community, Add, Booking, Profile }

class CustomBottomBar extends StatefulWidget {
  final BottomBarTab currentTab;
  final ValueChanged<BottomBarTab> onTabSelected;
  final String selectedSport;

  const CustomBottomBar({
    super.key,
    required this.currentTab,
    required this.onTabSelected,
    required this.selectedSport,
  });

  @override
  State<CustomBottomBar> createState() => _CustomBottomBarState();
}

class _CustomBottomBarState extends State<CustomBottomBar>
    with WidgetsBindingObserver {
  static const String _apiBase = 'https://sportotekaapp.ru/api';
  static const String _unreadTotalUrl = '$_apiBase/get_unread_total.php';

  int _unreadChats = 0;

  Timer? _pollTimer;
  bool _pollingEnabled = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _bootstrapUnread();
    _startPolling();
  }

  @override
  void dispose() {
    _stopPolling();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// ✅ Пауза/возобновление опроса (чтобы не спамить в фоне)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _pollingEnabled = true;
      _startPolling();
      _refreshUnreadFromServer();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _pollingEnabled = false;
      _stopPolling();
    }
  }

  Future<void> _bootstrapUnread() async {
    final cached = await PrefUtils.getUnreadChatsCount() ?? 0;
    if (!mounted) return;
    setState(() => _unreadChats = cached);

    await _refreshUnreadFromServer();
  }

  /// ✅ callback от ChatScreen — пришёл новый total
  Future<void> _handleUnreadChanged(int total) async {
    if (!mounted) return;
    if (total != _unreadChats) {
      setState(() => _unreadChats = total);
    }
    // на всякий фиксируем кеш
    await PrefUtils.setUnreadChatsCount(total);
  }

  void _startPolling() {
    if (!_pollingEnabled) return;
    _pollTimer?.cancel();

    _pollTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (_pollingEnabled) {
        _refreshUnreadFromServer();
      }
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _refreshUnreadFromServer() async {
    final uid = await PrefUtils.getUserId() ?? 0;
    if (uid == 0) return;

    try {
      final uri = Uri.parse('$_unreadTotalUrl?user_id=$uid');
      final r = await http.get(uri);
      if (r.statusCode != 200) return;

      final data = jsonDecode(r.body);
      if (data is Map && data['success'] == true) {
        final total = int.tryParse('${data['unread_total'] ?? 0}') ?? 0;

        await PrefUtils.setUnreadChatsCount(total);

        if (!mounted) return;
        if (total != _unreadChats) {
          setState(() => _unreadChats = total);
        }
      }
    } catch (_) {
      // тихо — оставляем текущее значение
    }
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: widget.currentTab.index,
      onTap: (index) async {
        final tab = BottomBarTab.values[index];

        // ✅ меню "+"
        if (tab == BottomBarTab.Add) {
          _showExtendedMenu(context);
          return;
        }

        // ✅ Лента
        if (tab == BottomBarTab.Community) {
          final sport =
              widget.selectedSport.isNotEmpty ? widget.selectedSport : 'Футбол';

          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SportCommunityScreen(sportName: sport),
            ),
          );
          return;
        }

        // ✅ Чат
        if (tab == BottomBarTab.Booking) {
          final uid = await PrefUtils.getUserId() ?? 0;
          if (uid == 0) return;

          _pollingEnabled = false;
          _stopPolling();

          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatScreen(
                userId: uid,
                onUnreadChanged: _handleUnreadChanged, // ✅ (int total)
              ),
            ),
          );

          _pollingEnabled = true;
          _startPolling();
          await _refreshUnreadFromServer();
          return;
        }

        // остальные вкладки — как раньше
        widget.onTabSelected(tab);
      },
      items: [
        const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Главная'),
        const BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Лента'),
        const BottomNavigationBarItem(icon: Icon(Icons.add), label: 'Добавить'),
        BottomNavigationBarItem(
          label: 'Чат',
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.chat),
              _Badge(count: _unreadChats),
            ],
          ),
        ),
        const BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Профиль'),
      ],
    );
  }

  void _navigateToHomePage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HomePage()),
    );
  }

  void _showExtendedMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: Text(
                  'Добавить новый элемент',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 20),
              _buildMenuOption(
                context,
                icon: Icons.fitness_center,
                title: 'Тренировку',
                subtitle: 'Создать новую программу тренировок',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddPersonalTrainingScreen(),
                    ),
                  );
                },
              ),
              _buildMenuOption(
                context,
                icon: Icons.post_add,
                title: 'Пост',
                subtitle: 'Поделиться своими мыслями',
                onTap: () {
                  final sport = widget.selectedSport.isNotEmpty
                      ? widget.selectedSport
                      : 'Футбол';

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreatePostEditorScreen(sportName: sport),
                    ),
                  );
                },
              ),
              _buildMenuOption(
                context,
                icon: Icons.event,
                title: 'Событие',
                subtitle: 'Организовать спортивное мероприятие',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ScheduleScreen(sport: widget.selectedSport),
                    ),
                  );
                },
              ),
              _buildMenuOption(
                context,
                icon: Icons.group_add,
                title: 'Группу',
                subtitle: 'Открыть чаты/группы',
                onTap: () async {
                  final uid = await PrefUtils.getUserId() ?? 0;
                  if (uid == 0) return;

                  _pollingEnabled = false;
                  _stopPolling();

                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        userId: uid,
                        onUnreadChanged: _handleUnreadChanged, // ✅ (int total)
                      ),
                    ),
                  );

                  _pollingEnabled = true;
                  _startPolling();
                  await _refreshUnreadFromServer();
                },
              ),
              const Spacer(),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  side: BorderSide(color: Theme.of(context).primaryColor),
                ),
                child: const Text('Отмена'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMenuOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Theme.of(context).primaryColor),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }
}

class _Badge extends StatelessWidget {
  final int count;
  const _Badge({required this.count});

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();

    return Positioned(
      right: -3,
      top: -3,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white, width: 2),
        ),
        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
        child: Text(
          '$count',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
        ),
      ),
    );
  }
}