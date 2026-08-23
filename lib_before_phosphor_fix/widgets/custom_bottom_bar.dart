// lib/widgets/custom_bottom_bar.dart
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/presentation/chat_screen/chat_screen.dart';

// Оставляем старые значения enum, чтобы не ломать home_container_screen.dart.
// Важно: на HomeScreen мобильное меню теперь встроено прямо в home_screen.dart.
// Там переходы полностью совпадают с боковым меню планшета/ПК.
// Поэтому для home-вкладок этот внешний бар скрывается, чтобы не было двух меню.
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

  static const List<BottomBarTab> _tabs = [
    BottomBarTab.Home,
    BottomBarTab.Booking,
    BottomBarTab.Add,
    BottomBarTab.Profile,
  ];

  int get _currentVisualIndex {
    final i = _tabs.indexOf(widget.currentTab);
    if (i >= 0) return i;
    return 0;
  }

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

  Future<void> _handleUnreadChanged(int total) async {
    if (!mounted) return;
    if (total != _unreadChats) {
      setState(() => _unreadChats = total);
    }
    await PrefUtils.setUnreadChatsCount(total);
  }

  void _startPolling() {
    if (!_pollingEnabled) return;
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (_pollingEnabled) _refreshUnreadFromServer();
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
      final r = await http.get(Uri.parse('$_unreadTotalUrl?user_id=$uid'));
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
    } catch (_) {}
  }

  Future<void> _onTap(int visualIndex) async {
    final tab = _tabs[visualIndex];

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
            onUnreadChanged: _handleUnreadChanged,
          ),
        ),
      );

      _pollingEnabled = true;
      _startPolling();
      await _refreshUnreadFromServer();
      return;
    }

    // ВАЖНО: BottomBarTab.Add теперь НЕ открывает меню добавления.
    // Это вкладка "Сервисы". Контейнер должен показать HomeScreen(initialHomeModeIndex: 2).
    widget.onTabSelected(tab);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final width = media.size.width;

    // На ПК и планшетах основная навигация находится слева.
    // На мобильном HomeScreen нижнее меню встроено прямо в home_screen.dart.
    // Поэтому для home-вкладок скрываем внешний бар, чтобы не было дубля.
    if (width >= 720 ||
        widget.currentTab == BottomBarTab.Home ||
        widget.currentTab == BottomBarTab.Community ||
        widget.currentTab == BottomBarTab.Add) {
      return const SizedBox.shrink();
    }

    final bottomInset = media.padding.bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset > 0 ? 8 : 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFE7EDF5)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _RoundNavButton(
                  label: 'Новости',
                  icon: Icons.article_rounded,
                  selected: _currentVisualIndex == 0,
                  onTap: () => _onTap(0),
                ),
                _RoundNavButton(
                  label: 'Чат',
                  icon: Icons.chat_bubble_rounded,
                  selected: _currentVisualIndex == 1,
                  badgeCount: _unreadChats,
                  onTap: () => _onTap(1),
                ),
                _RoundNavButton(
                  label: 'Сервисы',
                  icon: Icons.apps_rounded,
                  selected: _currentVisualIndex == 2,
                  onTap: () => _onTap(2),
                ),
                _RoundNavButton(
                  label: 'Профиль',
                  icon: Icons.person_rounded,
                  selected: _currentVisualIndex == 3,
                  onTap: () => _onTap(3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundNavButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final int badgeCount;
  final VoidCallback onTap;

  const _RoundNavButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    const active = Color(0xFF0877FF);
    const inactive = Color(0xFF6B7280);

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? active : const Color(0xFFF3F6FA),
                    border: Border.all(
                      color: selected ? active : const Color(0xFFE3EAF3),
                    ),
                    boxShadow: selected
                        ? [
                            BoxShadow(
                              color: active.withOpacity(0.24),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    icon,
                    color: selected ? Colors.white : inactive,
                    size: 22,
                  ),
                ),
                if (badgeCount > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 18),
                      height: 18,
                      padding: const EdgeInsets.symmetric(horizontal: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE53935),
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        badgeCount > 99 ? '99+' : '$badgeCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? active : inactive,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
