import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:sportoteka/presentation/home_screen/home_screen.dart';
import 'package:sportoteka/presentation/community_screen/community_screen.dart';
import 'package:sportoteka/presentation/profile_screen/profile_screen.dart';
import 'package:sportoteka/widgets/custom_bottom_bar.dart';
import 'package:sportoteka/presentation/chat_screen/chat_screen.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';

class HomeContainerScreen extends StatefulWidget {
  const HomeContainerScreen({Key? key}) : super(key: key);

  @override
  _HomeContainerScreenState createState() => _HomeContainerScreenState();
}

class _HomeContainerScreenState extends State<HomeContainerScreen> {
  BottomBarTab _currentTab = BottomBarTab.Home;
  String selectedSport = 'Футбол';
  int currentUserId = 0;

  @override
  void initState() {
    super.initState();

    // ✅ применяем вкладку из аргументов навигации (если передали)
    _applyInitialTabFromArgs();

    // ✅ грузим userId как раньше
    _loadUserId();
  }

  // =========================
  // ✅ Читаем Get.arguments
  // =========================
  void _applyInitialTabFromArgs() {
    final args = Get.arguments;

    int tabIndex = 0;
    if (args is Map && args["tab"] != null) {
      tabIndex = int.tryParse(args["tab"].toString()) ?? 0;
    }

    // setState здесь безопасен, initState
    _currentTab = _tabFromIndex(tabIndex);
  }

  BottomBarTab _tabFromIndex(int i) {
    switch (i) {
      case 0:
        return BottomBarTab.Home;
      case 1:
        return BottomBarTab.Community;
      case 2:
        return BottomBarTab.Add;
      case 3:
        return BottomBarTab.Booking;
      case 4:
        return BottomBarTab.Profile;
      default:
        return BottomBarTab.Home;
    }
  }

  void _loadUserId() async {
    final id = await PrefUtils.getUserId();
    if (!mounted) return;
    setState(() {
      currentUserId = id ?? 0;
    });
  }

  Widget _getCurrentPage(BottomBarTab tab) {
    switch (tab) {
      case BottomBarTab.Home:
        return HomeScreen(
          onSportChanged: (sport) {
            setState(() {
              selectedSport = sport;
            });
          },
        );
      case BottomBarTab.Community:
        return const CommunityScreen();
      case BottomBarTab.Add:
        return const Center(child: Text('Добавить'));
      case BottomBarTab.Booking:
        return ChatScreen(userId: currentUserId);
      case BottomBarTab.Profile:
        return const ProfileScreen();
      default:
        return const HomeScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _getCurrentPage(_currentTab),
      bottomNavigationBar: CustomBottomBar(
        currentTab: _currentTab,
        onTabSelected: (tab) {
          setState(() {
            _currentTab = tab;
          });
        },
        selectedSport: selectedSport,
      ),
    );
  }
}
