import 'dart:convert';
import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:sportoteka/presentation/home_screen/home_customizer_screen.dart';
import 'package:sportoteka/presentation/home_screen/home_screen_design.dart';

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:pool/pool.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/presentation/global_search_screen/global_search_screen.dart';
import 'package:sportoteka/presentation/booking_screen/booking_screen.dart';
import 'package:sportoteka/presentation/booking_screen/venue_booking_screen.dart';
import 'package:sportoteka/presentation/reels_screen/reels_screen.dart';
import 'package:sportoteka/presentation/video_lessons/video_lessons_screen.dart';
import 'package:sportoteka/presentation/video_lessons/video_lessons_authors_screen.dart';
import 'package:sportoteka/presentation/video_lessons/video_lessons_hub_screen.dart';
import 'package:sportoteka/presentation/service_screens/generic_service_screen.dart';
import 'package:sportoteka/presentation/service_screens/calendar_event_screen.dart';
import 'package:sportoteka/presentation/service_screens/event_detail_screen.dart';
import 'package:sportoteka/presentation/community_screen/news_detail_screen.dart';
import 'package:sportoteka/presentation/community_screen/sport_community_screen.dart';
import 'package:sportoteka/presentation/add_personal_training_screen/add_personal_training_screen.dart';
import 'package:sportoteka/presentation/team_screen/team_detail_screen.dart';
import 'package:sportoteka/presentation/catalog/team_list_screen.dart';
import 'package:sportoteka/widgets/sportoteka_ring_banner.dart';
import 'package:sportoteka/presentation/innovation/innovations_section.dart';
import 'package:sportoteka/presentation/tickets/tickets_section.dart';
import 'package:sportoteka/update_checker.dart';
import 'package:sportoteka/presentation/catalog/events_list_screen.dart';
import 'package:sportoteka/presentation/venue/venues_catalog_screen.dart';
import 'package:sportoteka/presentation/service_screens/ring_usage_screen.dart';
import 'package:sportoteka/core/constants/app_colors.dart';
import 'package:sportoteka/presentation/subscription/subscription_screen.dart';

/// ================== API CONFIG ==================
const String apiBaseUrl = 'https://sportotekaapp.ru/api/';
const Duration cacheDuration = Duration(minutes: 10);
const int maxConcurrentRequests = 3;

final dio = Dio()
  ..options.baseUrl = apiBaseUrl
  ..options.connectTimeout = const Duration(seconds: 10)
  ..options.receiveTimeout = const Duration(seconds: 8)
  ..options.headers = {'Connection': 'keep-alive'};

final requestPool = Pool(maxConcurrentRequests);

/// ================== ЦВЕТОВАЯ ПАЛИТРА ==================
class SportPalette {
  static const primaryGreen = Color(0xFF00A750);
  static const primaryGreenDark = Color(0xFF008C40);
  static const primaryGreenLight = Color(0xFF00C060);
  static const accentGreen = Color(0xFF7ED321);
  static const lightGreen = Color(0xFFE8F5E9);
  static const white = Color(0xFFFFFFFF);
  static const text = Color(0xFF1A1A1A);
  static const textMuted = Color(0xFF666666);
  static const textLight = Color(0xFF999999);
  static const slateBg = Color(0xFFF8F9FA);
  static const card = Color(0xFFFFFFFF);
  static const cardSoft = Color(0xFFFFFFFF);
}

/// ================== ТИПОГРАФИЯ ==================
class AppText {
  static const h1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.8,
    color: Colors.white,
    height: 1.1,
  );

  static const h2 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    color: SportPalette.text,
    height: 1.2,
  );

  static const h3 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w900,
    color: SportPalette.text,
    height: 1.3,
    letterSpacing: -0.3,
  );

  static const bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: SportPalette.text,
    height: 1.5,
    letterSpacing: 0.1,
  );

  static const body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: SportPalette.text,
    height: 1.6,
    letterSpacing: 0.05,
  );

  static const bodySmall = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: SportPalette.text,
    height: 1.5,
  );

  static const caption = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: SportPalette.textMuted,
    height: 1.4,
    letterSpacing: 0.1,
  );

  static const sectionTitle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.3,
    color: SportPalette.textMuted,
  );

  static const overline = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: Colors.white70,
    letterSpacing: 0.6,
    height: 1.2,
  );
}

/// ================== ДЕЙСТВИЯ ХЕДЕРА ==================
const List<_HeaderActionItem> _headerActions = [
  _HeaderActionItem(
    keyName: 'Видеоуроки',
    titleRu: 'Видеоуроки',
    icon: Icons.ondemand_video_rounded,
  ),
  _HeaderActionItem(
    keyName: 'Бронь',
    titleRu: 'Площадки',
    icon: Icons.event_available_rounded,
  ),
  _HeaderActionItem(
    keyName: 'Расписание',
    titleRu: 'Календарь',
    icon: Icons.calendar_today_rounded,
  ),
  _HeaderActionItem(
    keyName: 'Видео',
    titleRu: 'Видео',
    icon: Icons.play_circle_fill_rounded,
  ),
];

class _HeaderActionItem {
  final String keyName;
  final String titleRu;
  final IconData icon;
  const _HeaderActionItem({
    required this.keyName,
    required this.titleRu,
    required this.icon,
  });
}

/// ================== ГЛАВНЫЙ ЭКРАН ==================
class HomeScreen extends StatefulWidget {
  final void Function(String)? onSportChanged;
  const HomeScreen({super.key, this.onSportChanged});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

HomeScreenDesign _homeDesign = HomeScreenDesign.defaults();
int? _userId;
bool _designLoaded = false;

class _HomeScreenState extends State<HomeScreen> {
  HomeScreenDesign _homeDesign = HomeScreenDesign.defaults();
  int? _userId;
  bool _designLoaded = false;

  bool isLoading = true;
  bool hasError = false;
  String? errorMessage;

  String? selectedSport = "Футбол";
  List<Map<String, dynamic>> _catalogPreview = [];
  List<Map<String, dynamic>> _ticketsData = [];
  List<Map<String, dynamic>> _reelsData = [];

  final Map<String, dynamic> dataCache = {};
  final Map<String, DateTime> cacheTimestamps = {};
  final Map<String, List<Map<String, dynamic>>> _eventsCache = {};
  final Map<String, DateTime> _eventsCacheTimestamps = {};
  final Map<String, List<Map<String, dynamic>>> _userPostsCache = {};
  final Map<String, DateTime> _userPostsTimestamps = {};

  @override
  void initState() {
    super.initState();
    _initAll();
  }

  Future<void> _initAll() async {
    _ticketsData = _getDefaultTickets();
    _userId = await PrefUtils.getUserId();

    await _loadSavedHomeDesign();
    await _loadInitialData();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AppUpdateService.checkAndShow(context);
    });
  }

  Future<void> _loadSavedHomeDesign() async {
    try {
      final userId = _userId ?? await PrefUtils.getUserId();
      if (userId == null) {
        if (!mounted) return;
        setState(() {
          _homeDesign = HomeScreenDesign.defaults();
          _designLoaded = true;
        });
        return;
      }

      final raw = await PrefUtils.getString('home_design_user_$userId');
      if (raw == null || raw.trim().isEmpty) {
        if (!mounted) return;
        setState(() {
          _homeDesign = HomeScreenDesign.defaults();
          _designLoaded = true;
        });
        return;
      }

      final parsed = HomeScreenDesign.decode(raw);

      if (!mounted) return;
      setState(() {
        _homeDesign = parsed;
        _designLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _homeDesign = HomeScreenDesign.defaults();
        _designLoaded = true;
      });
    }
  }

  Future<void> _saveHomeDesign() async {
    final userId = _userId ?? await PrefUtils.getUserId();
    if (userId == null) return;

    await PrefUtils.setString(
      'home_design_user_$userId',
      _homeDesign.encode(),
    );
  }

  void _openHomeCustomizer() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HomeCustomizerScreen(
          initialDesign: _homeDesign,
          onSave: (design) async {
            if (!mounted) return;
            setState(() {
              _homeDesign = design;
            });
            await _saveHomeDesign();
          },
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getDefaultTickets() {
    return [
      {
        'teams': 'БАТЭ — Молодечно',
        'date': '16 августа 2025, 13:30',
        'venue': 'Борисов-Арена',
        'price': '7–19 BYN',
        'url': 'https://bycard.by/afisha/minsk/sport/4007948',
      },
      {
        'teams': 'Ислочь — БАТЭ',
        'date': '9 августа 2025, 18:00',
        'venue': 'Минск',
        'price': 'от ~8 BYN',
        'url': 'https://www.kvitki.by/',
      },
      {
        'teams': 'КХЛ: открытие недели',
        'date': '6 сентября 2025',
        'venue': 'Москва',
        'price': 'от ~600 ₽',
        'url': 'https://www.khl.ru/tickets/',
      },
    ];
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      hasError = false;
    });

    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        throw Exception('Нет интернет-соединения');
      }

      await Future.wait([
        _loadEvents(selectedSport ?? 'Футбол'),
        _loadCachedData('venues', () => _fetchVenues('Все')),
        _loadCachedData('teams', () => _fetchTeamsBySport(selectedSport ?? 'Футбол')),
        _loadCachedData('catalog_preview', () async {
          final data = await _fetchCatalogPreview();
          _catalogPreview = data;
          return data;
        }),
        _loadUserPosts(selectedSport ?? 'Футбол'),
        _loadReels(),
      ]);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        hasError = true;
        errorMessage = e.toString();
      });
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // ================== API METHODS ==================
  Future<List<Map<String, dynamic>>> _fetchWeeklyEvents(String sport) async {
    try {
      final response = await dio.get('get_week_events.php', queryParameters: {'sport': sport});
      return List<Map<String, dynamic>>.from(response.data);
    } on DioException catch (e) {
      throw Exception('Ошибка загрузки мероприятий: ${e.message}');
    }
  }

  Future<List<Map<String, dynamic>>> _fetchTeamsBySport(String sport) async {
    try {
      final response = await dio.get('get_teams_by_sport.php', queryParameters: {'sport': sport});
      if (response.data['status'] != 'success') {
        throw Exception('Ошибка на сервере: ${response.data['message'] ?? 'неизвестная ошибка'}');
      }
      return List<Map<String, dynamic>>.from(response.data['teams']);
    } on DioException catch (e) {
      throw Exception('Ошибка загрузки команд: ${e.message}');
    }
  }

  Future<List<Map<String, dynamic>>> _fetchVenues(String sport) async {
    try {
      final response = await dio.get('get_venues.php', queryParameters: sport != 'Все' ? {'sport': sport} : null);
      if (response.data['status'] == 'success') {
        return List<Map<String, dynamic>>.from(response.data['venues']);
      }
      throw Exception('Неверный формат данных');
    } on DioException catch (e) {
      throw Exception('Ошибка загрузки площадок: ${e.message}');
    }
  }

  Future<List<Map<String, dynamic>>> _fetchUserPosts(String sport) async {
    try {
      final res = await dio.get('get_posts.php');
      final data = res.data;
      final List raw = data is List ? data : (data is Map ? (data['data'] ?? data['items'] ?? []) as List? ?? [] : []);
      final sportLc = sport.toLowerCase();
      final out = raw.where((e) {
        final m = Map<String, dynamic>.from(e as Map);
        final cat = (m['category'] ?? '').toString().toLowerCase();
        return cat == sportLc;
      }).map<Map<String, dynamic>>((e) {
        final m = Map<String, dynamic>.from(e as Map);
        final first = (m['first_name'] ?? '').toString();
        final last = (m['last_name'] ?? '').toString();
        final full = ('$first $last').trim().isEmpty ? 'Пользователь' : ('$first $last').trim();
        final rawImg = (m['image'] ?? '').toString();
        final imageUrl = rawImg.isEmpty ? '' : (rawImg.startsWith('http') ? rawImg : 'https://sportotekaapp.ru/$rawImg');

        final rawAvatar = (m['photo_url'] ??
            m['photo'] ??
            m['avatar_url'] ??
            m['avatar'] ??
            m['user_avatar'] ??
            m['user_photo'] ??
            '').toString();

        final avatarUrl = _normalizeMediaUrl(rawAvatar);

        return {
          'id': int.tryParse('${m['id']}') ?? 0,
          'title': (m['title'] ?? '').toString(),
          'text': (m['body'] ?? '').toString(),
          'imageUrl': imageUrl,
          'date': DateTime.tryParse((m['created_at'] ?? '').toString()) ?? DateTime.now(),
          'authorAvatar': avatarUrl,
          'authorName': full,
        };
      }).toList();

      out.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
      return out.take(8).toList();
    } on DioException catch (e) {
      throw Exception('Ошибка загрузки постов: ${e.message}');
    }
  }

  Future<List<Map<String, dynamic>>> _fetchCatalogPreview() async {
    try {
      final res = await dio.get('get_schools.php', queryParameters: {
        'limit': 12,
        'offset': 0,
      });
      if (res.data is Map && res.data['items'] is List) {
        return List<Map<String, dynamic>>.from(res.data['items']);
      } else if (res.data is List) {
        return List<Map<String, dynamic>>.from(res.data);
      }
      return const [];
    } catch (e) {
      return const [];
    }
  }

  Future<void> _loadReels() async {
    try {
      final response = await dio.get('get_reels.php');
      final data = response.data;
      List raw;
      if (data is Map) {
        raw = (data['reels'] ?? data['data'] ?? data['items'] ?? data['list'] ?? []) as List? ?? [];
      } else if (data is List) {
        raw = data;
      } else {
        raw = const [];
      }
      final normalized = raw.map<Map<String, dynamic>>((e) {
        final m = Map<String, dynamic>.from(e as Map);
        final video = (m['video_url'] ?? m['video'] ?? m['url'] ?? m['src'] ?? '').toString();
        final thumb = (m['thumbnail'] ?? m['thumb'] ?? m['poster'] ?? m['preview'] ?? '').toString();
        return {
          'video_url': video,
          'thumbnail': thumb,
          'username': (m['username'] ?? m['user'] ?? m['author_name'] ?? '').toString(),
          'user_avatar': (m['user_avatar'] ?? m['avatar'] ?? '').toString(),
          'description': (m['description'] ?? m['title'] ?? m['caption'] ?? '').toString(),
          'likes': m['likes'] ?? m['like_count'] ?? 0,
          'views': m['views'] ?? m['view_count'] ?? 0,
          'comments': m['comments'] ?? m['comment_count'] ?? 0,
        };
      }).where((e) => (e['video_url'] as String).isNotEmpty).toList();

      if (mounted) {
        setState(() {
          _reelsData = normalized.take(6).toList();
        });
      }
    } catch (e) {}
  }

  Future<void> _loadEvents(String sport) async {
    final now = DateTime.now();
    if (_eventsCache.containsKey(sport) &&
        _eventsCacheTimestamps.containsKey(sport) &&
        now.difference(_eventsCacheTimestamps[sport]!) < cacheDuration) {
      return;
    }
    try {
      final events = await _fetchWeeklyEvents(sport);
      if (mounted) {
        setState(() {
          _eventsCache[sport] = events;
          _eventsCacheTimestamps[sport] = now;
        });
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _loadUserPosts(String sport) async {
    final now = DateTime.now();
    if (_userPostsCache.containsKey(sport) &&
        _userPostsTimestamps.containsKey(sport) &&
        now.difference(_userPostsTimestamps[sport]!) < cacheDuration) {
      return;
    }
    try {
      final posts = await _fetchUserPosts(sport);
      if (mounted) {
        setState(() {
          _userPostsCache[sport] = posts;
          _userPostsTimestamps[sport] = now;
        });
      }
    } catch (e) {}
  }

  Future<void> _loadCachedData(String key, Future<dynamic> Function() fetchFunction) async {
    final now = DateTime.now();
    if (dataCache.containsKey(key) &&
        cacheTimestamps.containsKey(key) &&
        now.difference(cacheTimestamps[key]!) < cacheDuration) {
      return;
    }
    try {
      final data = await requestPool.withResource(() => _fetchWithRetry(fetchFunction));
      if (!mounted) return;
      setState(() {
        dataCache[key] = data;
        cacheTimestamps[key] = DateTime.now();
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> _fetchWithRetry(Future<dynamic> Function() fetchFunction, {int maxRetries = 3}) async {
    int attempt = 0;
    while (attempt < maxRetries) {
      try {
        return await fetchFunction();
      } on DioException catch (e) {
        attempt++;
        if (attempt == maxRetries) {
          throw Exception('Не удалось загрузить данные после $maxRetries попыток: ${e.message}');
        }
        await Future.delayed(Duration(seconds: attempt));
      }
    }
    throw Exception('Неизвестная ошибка при выполнении запроса');
  }

  // ================== НАВИГАЦИЯ ==================
  void _openSearch() {
    if (!mounted) return;
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => GlobalSearchScreen(),
        transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
      ),
    );
  }

  void _openScheduleAll() {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScheduleScreen(sport: selectedSport ?? 'Футбол'),
      ),
    );
  }

  Future<void> _openVenuesAll() async {
    final userId = await PrefUtils.getUserId();
    if (!mounted || userId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookingScreen(userId: userId),
      ),
    );
  }

  void _openClubsAll() {
    final teams = (dataCache['teams'] ?? []) as List<Map<String, dynamic>>;
    if (teams.isEmpty || !mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const TeamListScreen(),
      ),
    );
  }

  void _onQuickAction(String key) async {
    if (key == "Бронь") {
      final userId = await PrefUtils.getUserId();
      if (userId == null) return;
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BookingScreen(userId: userId),
        ),
      );
    } else if (key == "Видео") {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReelsScreen(),
        ),
      );
    } else if (key == "Видеоуроки") {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const VideoLessonsHubScreen(),
        ),
      );
    } else if (key == "Расписание") {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ScheduleScreen(sport: selectedSport ?? 'Футбол'),
        ),
      );
    } else {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GenericServiceScreen(
            title: key,
            sport: selectedSport ?? 'Футбол',
          ),
        ),
      );
    }
  }

  // ================== ИКОНКИ СЕКЦИЙ ==================
  IconData _sectionIcon(HomeSectionType type) {
    switch (type) {
      case HomeSectionType.ringBanner:
        return Icons.ring_volume_rounded;
      case HomeSectionType.reels:
        return Icons.play_circle_fill_rounded;
      case HomeSectionType.promo:
        return Icons.workspace_premium_rounded;
      case HomeSectionType.innovations:
        return Icons.auto_awesome_rounded;
      case HomeSectionType.events:
        return Icons.event_rounded;
      case HomeSectionType.venues:
        return Icons.location_on_rounded;
      case HomeSectionType.clubs:
        return Icons.groups_rounded;
      case HomeSectionType.tickets:
        return Icons.confirmation_number_rounded;
      case HomeSectionType.posts:
        return Icons.forum_rounded;
    }
  }

  // ================== ПОСТРОЕНИЕ СЕКЦИЙ ИЗ ДИЗАЙНА ==================
  List<Widget> _buildSectionsFromDesign() {
    final sections = <Widget>[];

    for (final config in _homeDesign.sections.where((s) => s.visible)) {
      switch (config.type) {
        case HomeSectionType.ringBanner:
          sections.add(_buildRingBannerSection(config));
          break;
        case HomeSectionType.reels:
          if (_reelsData.isNotEmpty) {
            sections.add(_buildVideoSection(config));
          }
          break;
        case HomeSectionType.promo:
          if (_homeDesign.showPromoBanner) {
            sections.add(_buildPromoSection(config));
          }
          break;
        case HomeSectionType.innovations:
          sections.add(_buildInnovationsSection(config));
          break;
        case HomeSectionType.events:
          final events = _eventsCache[selectedSport ?? 'Футбол'] ?? [];
          if (events.isNotEmpty) {
            sections.add(_buildEventsSection(config, events));
          }
          break;
        case HomeSectionType.venues:
          final venues = dataCache['venues'] ?? [];
          if (venues.isNotEmpty) {
            sections.add(_buildVenuesSection(config, venues));
          }
          break;
        case HomeSectionType.clubs:
          final teams = dataCache['teams'] ?? [];
          if (teams.isNotEmpty) {
            sections.add(_buildClubsSection(config, teams));
          }
          break;
        case HomeSectionType.tickets:
          sections.add(_buildTicketsSection(config, _ticketsData));
          break;
        case HomeSectionType.posts:
          final posts = _userPostsCache[selectedSport ?? 'Футбол'] ?? [];
          if (posts.isNotEmpty) {
            sections.add(_buildUserPostsSection(config, posts));
          }
          break;
      }

      sections.add(SizedBox(height: _homeDesign.sectionGap));
    }

    if (sections.isNotEmpty) {
      sections.removeLast();
    }

    return sections;
  }

  // ================== УНИВЕРСАЛЬНЫЙ ЗАГОЛОВОК СЕКЦИИ ==================
  Widget _buildSectionHeaderFromDesign({
    required HomeSectionConfig config,
    required String title,
    required String subtitle,
    required VoidCallback? onSeeAll,
  }) {
    final accentColor = config.accentOverride ?? _homeDesign.primaryColor;

    return Row(
      children: [
        if (_homeDesign.showSectionIcons && config.showIcon)
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(_homeDesign.smallRadius),
            ),
            child: Icon(
              _sectionIcon(config.type),
              color: accentColor,
              size: 24,
            ),
          ),
        if (_homeDesign.showSectionIcons && config.showIcon)
          const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: _homeDesign.sectionTitleSize,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                  letterSpacing: -0.3,
                  color: _homeDesign.textColor,
                ),
              ),
              if (config.showSubtitle) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: _homeDesign.sectionSubtitleSize,
                    color: _homeDesign.mutedTextColor,
                    height: 1.2,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (onSeeAll != null)
          GestureDetector(
            onTap: onSeeAll,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(_homeDesign.smallRadius),
              ),
              child: Row(
                children: [
                  Text(
                    'Все',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: accentColor,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.chevron_right_rounded, size: 18, color: accentColor),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ================== УНИВЕРСАЛЬНАЯ КАРТОЧКА ==================
  Widget _buildCard({
    required Widget child,
    required Color? accentOverride,
    VoidCallback? onTap,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
    double? width,
    double? height,
  }) {
    final cardStyle = _homeDesign.cardStyle;
    final accent = accentOverride ?? _homeDesign.primaryColor;

    BoxDecoration decoration;

    switch (cardStyle) {
      case HomeCardStyle.glass:
        decoration = BoxDecoration(
          color: _homeDesign.cardColor.withOpacity(_homeDesign.glassOpacity),
          borderRadius: BorderRadius.circular(_homeDesign.cardRadius),
          border: Border.all(color: _homeDesign.borderColor, width: _homeDesign.borderWidth),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(_homeDesign.shadowOpacity),
              blurRadius: _homeDesign.shadowBlur,
              offset: const Offset(0, 8),
            ),
          ],
        );
        break;
      case HomeCardStyle.outlined:
        decoration = BoxDecoration(
          color: _homeDesign.cardColor,
          borderRadius: BorderRadius.circular(_homeDesign.cardRadius),
          border: Border.all(color: accent, width: _homeDesign.borderWidth),
        );
        break;
      case HomeCardStyle.elevated:
        decoration = BoxDecoration(
          gradient: _homeDesign.useGradientCards
              ? LinearGradient(
                  colors: [
                    _homeDesign.cardColor,
                    accent.withOpacity(0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: _homeDesign.useGradientCards ? null : _homeDesign.cardColor,
          borderRadius: BorderRadius.circular(_homeDesign.cardRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(
                (_homeDesign.shadowOpacity + 0.04).clamp(0, 0.35),
              ),
              blurRadius: (_homeDesign.shadowBlur + 8).clamp(0, 40),
              offset: const Offset(0, 12),
            ),
          ],
        );
        break;
      case HomeCardStyle.soft:
        decoration = BoxDecoration(
          color: _homeDesign.cardColor,
          borderRadius: BorderRadius.circular(_homeDesign.cardRadius),
          border: Border.all(color: _homeDesign.borderColor, width: _homeDesign.borderWidth),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(_homeDesign.shadowOpacity),
              blurRadius: _homeDesign.shadowBlur,
              offset: const Offset(0, 8),
            ),
          ],
        );
        break;
    }

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(_homeDesign.cardRadius),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: width,
          height: height,
          decoration: decoration,
          padding: padding,
          child: child,
        ),
      ),
    );
  }

  // ================== СЕКЦИИ ==================
  Widget _buildRingBannerSection(HomeSectionConfig config) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeaderFromDesign(
          config: config,
          title: 'Sportoteka Ring',
          subtitle: 'Умное спортивное кольцо',
          onSeeAll: null,
        ),
        const SizedBox(height: 16),
        SportotekaRingBanner(
          imageUrl: 'https://sportotekaapp.ru/static/sportoteka_ring.png',
          padding: EdgeInsets.zero,
          onDetails: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RingUsageScreen()),
            );
          },
          onBuy: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Купить')),
            );
          },
        ),
      ],
    );
  }

  Widget _buildVideoSection(HomeSectionConfig config) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeaderFromDesign(
          config: config,
          title: 'Популярные видео',
          subtitle: 'Лучшие ролики сообщества',
          onSeeAll: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ReelsScreen()),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: config.cardHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _reelsData.length > config.itemLimit ? config.itemLimit : _reelsData.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.only(right: index == _reelsData.length - 1 ? 0 : 16),
                child: SizedBox(
                  width: config.cardWidth,
                  child: _buildReelCard(_reelsData[index], config),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReelCard(Map<String, dynamic> reel, HomeSectionConfig config) {
    final thumb = (reel['thumbnail'] ?? '').toString();
    final desc = (reel['description'] ?? 'Видео').toString();

    return _buildCard(
      accentOverride: config.accentOverride,
      padding: EdgeInsets.zero,
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => ReelsScreen()));
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 3,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(_homeDesign.cardRadius),
                  ),
                  child: thumb.isNotEmpty
                      ? Image.network(
                          thumb,
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.medium,
                          errorBuilder: (_, __, ___) => _reelFallback(),
                        )
                      : _reelFallback(),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.22),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(_homeDesign.cardRadius),
                    ),
                  ),
                ),
                Center(
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: (_configAccent(config) ?? _homeDesign.primaryColor).withOpacity(0.92),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    desc,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: _homeDesign.cardTitleSize,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                      color: _homeDesign.textColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _statItem(
                        icon: Icons.remove_red_eye_outlined,
                        value: _formatCount('${reel['views'] ?? 0}'),
                      ),
                      const SizedBox(width: 16),
                      _statItem(
                        icon: Icons.favorite_border_rounded,
                        value: _formatCount('${reel['likes'] ?? 0}'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reelFallback() {
    return Container(
      color: _homeDesign.primaryColor.withOpacity(0.08),
      child: Center(
        child: Icon(Icons.videocam_rounded, color: _homeDesign.primaryColor, size: 48),
      ),
    );
  }

  Widget _buildPromoSection(HomeSectionConfig config) {
    return _HomePromoBanner(
      title: 'Sportoteka PRO',
      subtitle: 'Откройте видеоуроки, видеоанализ, heatmap и профессиональные инструменты.',
      buttonText: 'Подробнее',
      showClose: false,
      onClose: () {},
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const SubscriptionScreen(),
          ),
        );
      },
      design: _homeDesign,
      config: config,
    );
  }

  Widget _buildInnovationsSection(HomeSectionConfig config) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeaderFromDesign(
          config: config,
          title: 'AR функции',
          subtitle: 'Новые технологии для спорта',
          onSeeAll: null,
        ),
        const SizedBox(height: 16),
        const InnovationsSection(),
      ],
    );
  }

  Widget _buildEventsSection(HomeSectionConfig config, List<Map<String, dynamic>> events) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeaderFromDesign(
          config: config,
          title: 'Мероприятия',
          subtitle: 'Предстоящие события',
          onSeeAll: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EventsListScreen(initialSport: selectedSport ?? 'Футбол'),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: config.cardHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: events.length > config.itemLimit ? config.itemLimit : events.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.only(right: index == events.length - 1 ? 0 : 16),
                child: SizedBox(
                  width: config.cardWidth,
                  child: _buildEventCard(events[index], config),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event, HomeSectionConfig config) {
    final title = (event['title'] ?? 'Событие').toString();
    final date = (event['event_date'] ?? '').toString();
    final location = (event['location'] ?? 'Локация не указана').toString();
    final imageUrl = (event['image'] ?? '').toString();
    final hasImage = imageUrl.isNotEmpty;

    return _buildCard(
      accentOverride: config.accentOverride,
      padding: EdgeInsets.zero,
      onTap: () {
        if (!mounted) return;
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => EventDetailScreen(event: event),
            transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasImage)
            Expanded(
              flex: 2,
              child: ClipRRect(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(_homeDesign.cardRadius),
                ),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _eventFallback(),
                ),
              ),
            ),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: _homeDesign.cardTitleSize,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                      color: _homeDesign.textColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (date.isNotEmpty) ...[
                    _metaRow(Icons.calendar_today_rounded, date),
                    const SizedBox(height: 6),
                  ],
                  _metaRow(Icons.location_on_rounded, location),
                  const Spacer(),
                  Row(
                    children: [
                      Text(
                        'Открыть',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: _configAccent(config) ?? _homeDesign.primaryColor,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: _homeDesign.mutedTextColor,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _eventFallback() {
    return Container(
      color: (_homeDesign.secondaryColor).withOpacity(0.10),
      child: Center(
        child: Icon(
          Icons.event_rounded,
          color: _homeDesign.secondaryColor,
          size: 48,
        ),
      ),
    );
  }

  Widget _buildVenuesSection(HomeSectionConfig config, List<dynamic> venues) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeaderFromDesign(
          config: config,
          title: 'Спортивные площадки',
          subtitle: 'Бронирование и информация',
          onSeeAll: venues.isNotEmpty ? _openVenuesAll : null,
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: config.cardHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: venues.length > config.itemLimit ? config.itemLimit : venues.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.only(right: index == venues.length - 1 ? 0 : 16),
                child: SizedBox(
                  width: config.cardWidth,
                  child: _buildVenueCard(venues[index] as Map<String, dynamic>, config),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVenueCard(Map<String, dynamic> venue, HomeSectionConfig config) {
    final imageUrl = (venue['image'] ?? '').toString();
    final hasImage = imageUrl.isNotEmpty;

    return _buildCard(
      accentOverride: config.accentOverride,
      padding: EdgeInsets.zero,
      onTap: () async {
        final userId = await PrefUtils.getUserId();
        if (userId == null || !mounted) return;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VenueBookingScreen(
              venueId: int.parse(venue['id'].toString()),
              venueTitle: (venue['title'] ?? '').toString(),
              userId: userId,
            ),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasImage)
            Expanded(
              flex: 2,
              child: ClipRRect(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(_homeDesign.cardRadius),
                ),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _venueFallback(),
                ),
              ),
            ),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (venue['title'] ?? '').toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: _homeDesign.cardTitleSize,
                      fontWeight: FontWeight.w800,
                      color: _homeDesign.textColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.place_rounded, size: 14, color: _homeDesign.mutedTextColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          (venue['address'] ?? '').toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: _homeDesign.mutedTextColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  if ((venue['price'] ?? '').toString().isNotEmpty)
                    Text(
                      venue['price'].toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _configAccent(config) ?? _homeDesign.secondaryColor,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

 Widget _venueFallback() {
  final color = _homeDesign.secondaryColor; // используем secondaryColor
  return Container(
    color: color.withOpacity(0.08),
    child: Center(
      child: Icon(
        Icons.location_on_rounded,
        color: color,
        size: 48,
      ),
    ),
  );
}
  Widget _buildClubsSection(HomeSectionConfig config, List<Map<String, dynamic>> teams) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeaderFromDesign(
          config: config,
          title: 'Спортивные клубы',
          subtitle: 'Профессиональные команды',
          onSeeAll: teams.isNotEmpty ? _openClubsAll : null,
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: config.cardHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: teams.length > config.itemLimit ? config.itemLimit : teams.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.only(right: index == teams.length - 1 ? 0 : 16),
                child: SizedBox(
                  width: config.cardWidth,
                  child: _buildTeamCard(teams[index], config),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTeamCard(Map<String, dynamic> team, HomeSectionConfig config) {
    final name = (team['name'] ?? 'Клуб').toString();
    final sportText = (team['sport'] ?? selectedSport ?? 'Спорт').toString();
    final city = (team['city'] ?? '').toString();
    final logoUrl = _teamLogoFromAnyKey(team);
    final accent = _teamAccentBySport(sportText, config);

    return _buildCard(
      accentOverride: config.accentOverride,
      padding: EdgeInsets.zero,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TeamDetailScreen(
              teamId: int.parse(team['id'].toString()),
              teamName: name,
            ),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 2,
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        accent.withOpacity(0.95),
                        accent.withOpacity(0.65),
                      ],
                    ),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(_homeDesign.cardRadius),
                    ),
                  ),
                ),
                Center(
                  child: _teamLogoWidget(
                    teamName: name,
                    logoUrl: logoUrl,
                    accent: accent,
                    size: 64,
                  ),
                ),
                Positioned(
                  left: 14,
                  top: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white.withOpacity(0.30)),
                    ),
                    child: Text(
                      sportText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: _homeDesign.cardTitleSize,
                      fontWeight: FontWeight.w800,
                      color: _homeDesign.textColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _metaRow(Icons.sports_rounded, sportText),
                  const SizedBox(height: 6),
                  if (city.isNotEmpty) _metaRow(Icons.place_rounded, city),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketsSection(HomeSectionConfig config, List<Map<String, dynamic>> tickets) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeaderFromDesign(
          config: config,
          title: 'Билеты на матчи',
          subtitle: 'РФ / РБ, 2025',
          onSeeAll: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TicketsSection(
                  selectedClub: null,
                  tickets: _ticketsData,
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: config.cardHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: tickets.length > config.itemLimit ? config.itemLimit : tickets.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.only(right: index == tickets.length - 1 ? 0 : 16),
                child: SizedBox(
                  width: config.cardWidth,
                  child: _buildTicketCard(tickets[index], config),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTicketCard(Map<String, dynamic> ticket, HomeSectionConfig config) {
    final teams = (ticket['teams'] ?? 'Матч').toString();
    final date = (ticket['date'] ?? '').toString();
    final venue = (ticket['venue'] ?? '').toString();
    final price = (ticket['price'] ?? '').toString();

    return _buildCard(
      accentOverride: config.accentOverride,
      padding: EdgeInsets.zero,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TicketsSection(
              selectedClub: null,
              tickets: _ticketsData,
            ),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _configAccent(config) ?? _homeDesign.primaryColor,
                  _homeDesign.primaryColor,
                ],
              ),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(_homeDesign.cardRadius),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.confirmation_number_rounded, color: Colors.white, size: 22),
                const SizedBox(width: 12),
                Text(
                  'БИЛЕТЫ',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: _homeDesign.smallTextSize,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    teams,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: _homeDesign.cardTitleSize,
                      fontWeight: FontWeight.w800,
                      color: _homeDesign.textColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (date.isNotEmpty) _metaRow(Icons.calendar_today_rounded, date),
                  if (venue.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _metaRow(Icons.place_rounded, venue),
                  ],
                  const Spacer(),
                  if (price.isNotEmpty)
                    Text(
                      price,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: _configAccent(config) ?? _homeDesign.primaryColor,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserPostsSection(HomeSectionConfig config, List<Map<String, dynamic>> posts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeaderFromDesign(
          config: config,
          title: 'Новости сообщества',
          subtitle: 'Обновления от пользователей',
          onSeeAll: () {
            final sport = selectedSport ?? 'Футбол';
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SportCommunityScreen(sportName: sport),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: config.cardHeight + 20,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: posts.length > config.itemLimit ? config.itemLimit : posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              final hasImage = (post['imageUrl'] ?? '').toString().isNotEmpty;

              return Padding(
                padding: EdgeInsets.only(right: index == posts.length - 1 ? 0 : 16),
                child: SizedBox(
                  width: hasImage ? config.cardWidth : config.cardWidth - 20,
                  child: _buildUserPostCard(post, config),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildUserPostCard(Map<String, dynamic> post, HomeSectionConfig config) {
    final title = (post['title'] ?? '').toString();
    final text = (post['text'] ?? '').toString();
    final author = (post['authorName'] ?? 'Пользователь').toString();
    final imageUrl = (post['imageUrl'] ?? '').toString();
    final hasImage = imageUrl.isNotEmpty;
    final avatarUrl = (post['authorAvatar'] ?? '').toString();

    return _buildCard(
      accentOverride: config.accentOverride,
      padding: EdgeInsets.zero,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NewsDetailScreen(
              title: title.trim().isNotEmpty ? title : (selectedSport ?? 'Новости'),
              body: text,
              newsId: (post['id'] as int?) ?? 0,
              imageUrl: imageUrl,
            ),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasImage)
            Expanded(
              flex: 2,
              child: ClipRRect(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(_homeDesign.cardRadius),
                ),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: _homeDesign.primaryColor.withOpacity(0.08),
                    child: Center(
                      child: Icon(Icons.image_rounded, color: _homeDesign.primaryColor, size: 48),
                    ),
                  ),
                ),
              ),
            ),
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _authorAvatarWidget(
                        avatarUrl: avatarUrl,
                        author: author,
                        radius: 16,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: _homeDesign.smallTextSize,
                            fontWeight: FontWeight.w800,
                            color: _homeDesign.textColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (title.trim().isNotEmpty) ...[
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: _homeDesign.cardTitleSize,
                        fontWeight: FontWeight.w900,
                        color: _homeDesign.textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
                  Expanded(
                    child: Text(
                      text.isNotEmpty ? text : 'Интересная новость от сообщества',
                      maxLines: hasImage ? 3 : 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: _homeDesign.bodyTextSize,
                        color: _homeDesign.textColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        _formatPostDateHome(post['date'] as DateTime),
                        style: TextStyle(
                          fontSize: _homeDesign.smallTextSize - 1,
                          color: _homeDesign.mutedTextColor,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: _homeDesign.mutedTextColor,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _authorAvatarWidget({
    required String avatarUrl,
    required String author,
    double radius = 16,
  }) {
    final url = _normalizeMediaUrl(avatarUrl);

    return CircleAvatar(
      radius: radius,
      backgroundColor: _homeDesign.primaryColor.withOpacity(0.12),
      backgroundImage: url.isNotEmpty ? NetworkImage(url) : null,
      child: url.isEmpty
          ? Text(
              author.trim().isNotEmpty ? author.trim()[0].toUpperCase() : 'П',
              style: TextStyle(
                color: _homeDesign.primaryColor,
                fontWeight: FontWeight.w900,
                fontSize: radius * 0.8,
              ),
            )
          : null,
    );
  }

  // ================== ХЕЛПЕРЫ ==================
  Color? _configAccent(HomeSectionConfig config) {
    return config.accentOverride;
  }

  Widget _statItem({
    required IconData icon,
    required String value,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: _homeDesign.mutedTextColor,
        ),
        const SizedBox(width: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _homeDesign.mutedTextColor,
          ),
        ),
      ],
    );
  }

  Widget _metaRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: _homeDesign.mutedTextColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: _homeDesign.mutedTextColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingPlaceholder() {
    return Center(
      child: Container(
        decoration: BoxDecoration(
          color: _homeDesign.cardColor,
          borderRadius: BorderRadius.circular(_homeDesign.cardRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(_homeDesign.shadowOpacity),
              blurRadius: _homeDesign.shadowBlur,
            ),
          ],
        ),
        padding: const EdgeInsets.all(40),
        child: CircularProgressIndicator(
          color: _homeDesign.primaryColor,
          strokeWidth: 3,
        ),
      ),
    );
  }

  Widget _buildEmptyPlaceholder({required IconData icon, required String text}) {
    return Center(
      child: Container(
        decoration: BoxDecoration(
          color: _homeDesign.cardColor,
          borderRadius: BorderRadius.circular(_homeDesign.cardRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(_homeDesign.shadowOpacity),
              blurRadius: _homeDesign.shadowBlur,
            ),
          ],
        ),
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 56,
              color: _homeDesign.mutedTextColor,
            ),
            const SizedBox(height: 16),
            Text(
              text,
              style: TextStyle(
                color: _homeDesign.mutedTextColor,
                fontSize: _homeDesign.bodyTextSize,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================== ХЕДЕР ==================
  SliverAppBar _buildAnimatedHeaderSliver() {
    return SliverAppBar(
      pinned: true,
      floating: false,
      snap: false,
      backgroundColor: _homeDesign.primaryColor,
      elevation: 0,
      expandedHeight: _homeDesign.headerExpandedHeight,
      collapsedHeight: kToolbarHeight + _homeDesign.headerCollapsedExtraHeight,
      automaticallyImplyLeading: false,
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final minH = kToolbarHeight + _homeDesign.headerCollapsedExtraHeight;
          final maxH = _homeDesign.headerExpandedHeight;
          final currentH = constraints.biggest.height;

          final t = ((currentH - minH) / (maxH - minH)).clamp(0.0, 1.0);

          final quickScale = lerpDouble(0.78, _homeDesign.quickActionScale, t)!;
          final labelOpacity = lerpDouble(0.0, 1.0, t)!;
          final blockOpacity = lerpDouble(0.85, 1.0, t)!;

          final bodyBg = _homeDesign.backgroundColor;

          final fadeH = lerpDouble(18.0, 56.0, t)!.clamp(18.0, 64.0);
          final fadeMid = lerpDouble(0.30, 0.72, t)!;
          final fadeEnd = lerpDouble(0.68, 1.00, t)!;

          return Stack(
            fit: StackFit.expand,
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _homeDesign.headerStartColor,
                      _homeDesign.headerMidColor,
                      _homeDesign.headerEndColor,
                    ],
                  ),
                ),
              ),

             
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withOpacity(0.00),
                          Colors.white.withOpacity(lerpDouble(0.03, 0.10, t)!),
                          Colors.white.withOpacity(lerpDouble(0.06, 0.16, t)!),
                        ],
                        stops: const [0.45, 0.78, 1.0],
                      ),
                    ),
                  ),
                ),
              ),

              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: fadeH,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          bodyBg.withOpacity(0.0),
                          bodyBg.withOpacity(fadeMid),
                          bodyBg.withOpacity(fadeEnd),
                        ],
                        stops: const [0.0, 0.55, 1.0],
                      ),
                    ),
                  ),
                ),
              ),

              SafeArea(
                bottom: false,
                child: Stack(
                  children: [
                    Positioned(
                      left: _homeDesign.pageHorizontalPadding,
                      top: 14,
                      child: IgnorePointer(
                        ignoring: t < 0.05,
                        child: Opacity(
                          opacity: t,
                          child: Transform.translate(
                            offset: Offset(0, lerpDouble(-10.0, 0.0, t)!),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _homeDesign.customHeaderTitle,
                                  style: AppText.h1.copyWith(
                                    fontSize: _homeDesign.headerTitleSize,
                                  ),
                                ),
                                if (_homeDesign.showHeaderSubtitle) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    _homeDesign.customHeaderSubtitle,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.95),
                                      fontSize: _homeDesign.headerSubtitleSize,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    Positioned(
                      left: 0,
                      right: 0,
                      top: 90,
                      bottom: 16,
                      child: Opacity(
                        opacity: t,
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: _homeDesign.pageHorizontalPadding,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Opacity(
                                opacity: blockOpacity,
                                child: Transform.scale(
                                  scale: quickScale,
                                  alignment: Alignment.topCenter,
                                  child: _buildHeaderQuickActionsPanel(
                                    labelOpacity: labelOpacity,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    Positioned(
                      left: _homeDesign.pageHorizontalPadding,
                      right: _homeDesign.pageHorizontalPadding,
                      bottom: 8,
                      child: Opacity(
                        opacity: (1.0 - t).clamp(0.0, 1.0),
                        child: _CollapsedQuickRow(
                          onSearchTap: _openSearch,
                          onActionTap: (key) => _onQuickAction(key),
                          design: _homeDesign,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeaderQuickActionsPanel({
    required double labelOpacity,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(_homeDesign.glassOpacity + 0.10),
        borderRadius: BorderRadius.circular(_homeDesign.quickActionsCornerRadius),
        border: Border.all(
          color: Colors.white.withOpacity(0.30),
        ),
        boxShadow: [
          if (_homeDesign.premiumGlow)
            BoxShadow(
              color: _homeDesign.primaryColor.withOpacity(0.22),
              blurRadius: 24,
              spreadRadius: 1,
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Быстрые действия",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 15,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 104,
            child: HeaderQuickActionsGrid(
              labelOpacity: labelOpacity,
              onTap: (key) => _onQuickAction(key),
              design: _homeDesign,
            ),
          ),
        ],
      ),
    );
  }

  // ================== BUILD ==================
  @override
  Widget build(BuildContext context) {
    if (hasError) {
      return Scaffold(
        backgroundColor: _homeDesign.backgroundColor,
        body: Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _homeDesign.cardColor,
              borderRadius: BorderRadius.circular(_homeDesign.cardRadius),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(_homeDesign.shadowOpacity),
                  blurRadius: _homeDesign.shadowBlur,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 56, color: Colors.red),
                const SizedBox(height: 20),
                Text(
                  errorMessage ?? 'Произошла ошибка',
                  style: AppText.h3.copyWith(
                    fontSize: 18,
                    color: _homeDesign.textColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _loadInitialData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _homeDesign.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(_homeDesign.smallRadius),
                    ),
                  ),
                  child: const Text('Повторить попытку'),
                ),
              ],
            ),
          ),
        ),
      );
    }

   return Scaffold(
  floatingActionButton: FloatingActionButton(
    backgroundColor: _homeDesign.primaryColor,
    onPressed: _openHomeCustomizer,
    child: const Icon(Icons.tune_rounded, color: Colors.white),
  ),

  backgroundColor: _homeDesign.backgroundColor,
  body: SafeArea(
    child: CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        _buildAnimatedHeaderSliver(),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: _homeDesign.pageHorizontalPadding,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _buildSectionsFromDesign(),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 48)),
          ],
        ),
      ),
    );
  }

  String _formatCount(String count) {
    final numVal = int.tryParse(count) ?? 0;
    if (numVal >= 1000000) return '${(numVal / 1000000).toStringAsFixed(1)}M';
    if (numVal >= 1000) return '${(numVal / 1000).toStringAsFixed(1)}K';
    return count;
  }

  String _formatPostDateHome(DateTime date) {
    final now = DateTime.now();
    final d = now.difference(date);
    if (d.inMinutes < 1) return 'только что';
    if (d.inHours < 1) return '${d.inMinutes} мин назад';
    if (d.inDays < 1) return '${d.inHours} ч назад';
    if (d.inDays < 7) return '${d.inDays} дн назад';
    return '${date.day}.${date.month}.${date.year}';
  }
}

// ================== КОМПОНЕНТЫ ХЕДЕРА ==================
class _CollapsedQuickRow extends StatelessWidget {
  final VoidCallback onSearchTap;
  final void Function(String) onActionTap;
  final HomeScreenDesign design;

  const _CollapsedQuickRow({
    required this.onSearchTap,
    required this.onActionTap,
    required this.design,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: onSearchTap,
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(design.smallRadius),
                border: Border.all(color: Colors.white.withOpacity(0.28)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.search_rounded, color: Colors.white, size: 22),
                  SizedBox(width: 12),
                  Text(
                    "Поиск",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          height: 48,
          width: 220,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _headerActions.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final a = _headerActions[i];
              return _MagnetIcon(
                size: 48,
                color: design.primaryColor,
                icon: a.icon,
                onTap: () => onActionTap(a.keyName),
                design: design,
              );
            },
          ),
        ),
      ],
    );
  }
}

class HeaderQuickActionsGrid extends StatelessWidget {
  final void Function(String) onTap;
  final double labelOpacity;
  final HomeScreenDesign design;

  const HeaderQuickActionsGrid({
    super.key,
    required this.onTap,
    required this.labelOpacity,
    required this.design,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _headerActions.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.9,
      ),
      itemBuilder: (ctx, i) {
        final item = _headerActions[i];
        return Column(
          children: [
            _MagnetIcon(
              size: design.quickActionBubbleSize.clamp(44, 66),
              color: design.primaryColor,
              icon: item.icon,
              onTap: () => onTap(item.keyName),
              design: design,
            ),
            const SizedBox(height: 8),
            Opacity(
              opacity: labelOpacity,
              child: Text(
                item.titleRu,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: design.smallTextSize,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MagnetIcon extends StatefulWidget {
  final double size;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;
  final HomeScreenDesign design;

  const _MagnetIcon({
    required this.size,
    required this.color,
    required this.icon,
    required this.onTap,
    required this.design,
  });

  @override
  State<_MagnetIcon> createState() => _MagnetIconState();
}

class _MagnetIconState extends State<_MagnetIcon> {
  bool _down = false;
  bool _hover = false;

  void _setDown(bool v) => setState(() => _down = v);
  void _setHover(bool v) => setState(() => _hover = v);

  @override
  Widget build(BuildContext context) {
    final scale = _down ? 0.92 : (_hover ? 1.06 : 1.0);
    final y = _down ? 2.0 : (_hover ? -2.0 : 0.0);

    return MouseRegion(
      onEnter: (_) => _setHover(true),
      onExit: (_) => _setHover(false),
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => _setDown(true),
        onTapCancel: () => _setDown(false),
        onTapUp: (_) => _setDown(false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          transform: Matrix4.identity()
            ..translate(0.0, y, 0.0)
            ..scale(scale),
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                widget.color.withOpacity(0.85),
                widget.color,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(_down ? 0.18 : 0.32),
                blurRadius: _down ? 12 : 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: widget.size - 10,
              height: widget.size - 10,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child: Icon(
                widget.icon,
                color: widget.color,
                size: widget.size * 0.42,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ================== SCHEDULE SCREEN ==================
class ScheduleScreen extends StatelessWidget {
  final String sport;

  const ScheduleScreen({super.key, required this.sport});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Расписание: $sport'),
      ),
      body: const Center(
        child: Text('Экран расписания'),
      ),
    );
  }
}

// ================== PROMO BANNER ==================
class _HomePromoBanner extends StatefulWidget {
  final String title;
  final String subtitle;
  final String buttonText;
  final VoidCallback onClose;
  final VoidCallback onTap;
  final bool showClose;
  final HomeScreenDesign design;
  final HomeSectionConfig config;

  const _HomePromoBanner({
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.onClose,
    required this.onTap,
    this.showClose = true,
    required this.design,
    required this.config,
  });

  @override
  State<_HomePromoBanner> createState() => _HomePromoBannerState();
}

class _HomePromoBannerState extends State<_HomePromoBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );

    _opacity = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    _offset = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _close() async {
    await _controller.reverse();
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.config.accentOverride ?? widget.design.primaryColor;

    return SlideTransition(
      position: _offset,
      child: FadeTransition(
        opacity: _opacity,
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.design.bannerRadius),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF0F172A),
                  widget.design.headerStartColor,
                  accent,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(widget.design.shadowOpacity),
                  blurRadius: widget.design.shadowBlur,
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  top: -18,
                  right: -10,
                  child: Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned(
                  bottom: -26,
                  left: -18,
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(widget.design.smallRadius),
                        ),
                        child: Icon(
                          Icons.workspace_premium_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: widget.design.sectionTitleSize + 2,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.subtitle,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.92),
                                fontSize: widget.design.bodyTextSize,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: widget.onTap,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: accent,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(vertical: 13),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          widget.design.smallRadius,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      widget.buttonText,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: widget.design.bodyTextSize,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (widget.showClose)
                        InkWell(
                          onTap: _close,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: 20,
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
      ),
    );
  }
}

// ================== ХЕЛПЕРЫ ДЛЯ КОМАНД ==================
String _normalizeMediaUrl(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return '';
  if (s.startsWith('http://') || s.startsWith('https://')) return s;

  if (s.startsWith('/')) return 'https://sportotekaapp.ru$s';
  return 'https://sportotekaapp.ru/$s';
}

String _teamLogoFromAnyKey(Map<String, dynamic> team) {
  final candidates = [
    team['logo'],
    team['logo_url'],
    team['image'],
    team['image_url'],
    team['emblem'],
    team['badge'],
  ].map((e) => (e ?? '').toString()).toList();

  for (final c in candidates) {
    final url = _normalizeMediaUrl(c);
    if (url.isNotEmpty) return url;
  }
  return '';
}

Color _teamAccentBySport(String sport, HomeSectionConfig config) {
  final s = sport.toLowerCase();
  if (s.contains('фут')) return config.accentOverride ?? SportPalette.primaryGreen;
  if (s.contains('хок')) return config.accentOverride ?? SportPalette.primaryGreenDark;
  if (s.contains('баскет')) return config.accentOverride ?? SportPalette.accentGreen;
  if (s.contains('волей')) return config.accentOverride ?? SportPalette.primaryGreenLight;
  if (s.contains('теннис')) return config.accentOverride ?? SportPalette.accentGreen;
  return config.accentOverride ?? SportPalette.accentGreen;
}

String _teamInitials(String name) {
  final n = name.trim();
  if (n.isEmpty) return 'T';
  final parts = n.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.length == 1) return parts.first.characters.take(2).toString().toUpperCase();
  final a = parts[0].characters.first.toUpperCase();
  final b = parts[1].characters.first.toUpperCase();
  return '$a$b';
}

Widget _teamLogoWidget({
  required String teamName,
  required String logoUrl,
  required Color accent,
  double size = 64,
}) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.14),
          blurRadius: 18,
          offset: const Offset(0, 10),
        ),
      ],
      border: Border.all(color: Colors.white.withOpacity(0.95), width: 3),
    ),
    child: ClipOval(
      child: logoUrl.isNotEmpty
          ? Image.network(
              logoUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _teamFallbackLogo(teamName, accent),
            )
          : _teamFallbackLogo(teamName, accent),
    ),
  );
}

Widget _teamFallbackLogo(String teamName, Color accent) {
  return Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          accent.withOpacity(0.22),
          accent.withOpacity(0.06),
        ],
      ),
    ),
    child: Center(
      child: Text(
        _teamInitials(teamName),
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w900,
          color: accent,
          letterSpacing: 0.5,
        ),
      ),
    ),
  );
}