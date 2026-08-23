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
//import 'package:sportoteka/presentation/catalog/schools_catalog_screen.dart';
//import 'package:sportoteka/presentation/catalog/school_list_screen.dart';
//import 'package:sportoteka/presentation/school_detail_screen/school_detail_screen.dart';
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

// Dio client
final dio = Dio()
  ..options.baseUrl = apiBaseUrl
  ..options.connectTimeout = const Duration(seconds: 10)
  ..options.receiveTimeout = const Duration(seconds: 8)
  ..options.headers = {'Connection': 'keep-alive'};

final requestPool = Pool(maxConcurrentRequests);

/// ================== ЗЕЛЕНАЯ ЦВЕТОВАЯ ПАЛИТРА ==================
class SportPalette {
  // Основной зеленый цвет (#00a750)
  static const primaryGreen = Color(0xFF00A750);
  static const primaryGreenDark = Color(0xFF008C40);
  static const primaryGreenLight = Color(0xFF00C060);
  static const accentGreen = Color(0xFF7ED321);
  static const lightGreen = Color(0xFFE8F5E9);

  // Дополнительные цвета
  static const white = Color(0xFFFFFFFF);
  static const text = Color(0xFF1A1A1A);
  static const textMuted = Color(0xFF666666);
  static const textLight = Color(0xFF999999);

  // Старые цвета для совместимости
  static const blue = Color(0xFF00A750);
  static const blueDeep = Color(0xFF008C40);
  static const sky = Color(0xFF00C060);
  static const teal = Color(0xFF10B981);
  static const amber = Color(0xFFF59E0B);
  static const grape = Color(0xFF7C3AED);
  static const coral = Color(0xFFE4002B);

  static const slateBg = Color(0xFFF8F9FA);
  static const card = Color(0xFFFFFFFF);
  static const cardSoft = Color(0xFFFFFFFF);
}




/// ================== IMPROVED TYPOGRAPHY ==================
class AppText {
  // HEADERS
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

  // BODY TEXT
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

  // CAPTIONS & LABELS
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

/// ================== UI CONSTANTS ==================
const double kPageHPad = 20;
const double kSectionGap = 28;
const double kCardHeight = 224;
const double kRadius = 20;
const double kSmallRadius = 14;
const double kCardPadding = 16;

BoxDecoration softCardDecoration({Color? borderColor}) {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(kRadius),
    border: Border.all(color: borderColor ?? const Color(0xFFE9EEF5)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.05),
        blurRadius: 26,
        offset: const Offset(0, 14),
      ),
    ],
  );
}

/// ================== HEADER ACTIONS ==================
const List<_HeaderActionItem> _headerActions = [
_HeaderActionItem(
    keyName: 'Видеоуроки',
    titleRu: 'Видеоуроки',
    icon: Icons.ondemand_video_rounded,
  ),
  //_HeaderActionItem(keyName: 'Тренировки', titleRu: 'Тренировки', icon: Icons.fitness_center_rounded),
  _HeaderActionItem(keyName: 'Бронь', titleRu: 'Площадки', icon: Icons.event_available_rounded),
  _HeaderActionItem(keyName: 'Расписание', titleRu: 'Календарь', icon: Icons.calendar_today_rounded),
  _HeaderActionItem(keyName: 'Видео', titleRu: 'Видео', icon: Icons.play_circle_fill_rounded),
];

class _HeaderActionItem {
  final String keyName;
  final String titleRu;
  final IconData icon;
  const _HeaderActionItem({required this.keyName, required this.titleRu, required this.icon});
}

/// ================== MAIN SCREEN ==================
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
  bool isLoading = true;
  bool hasError = false;
  String? errorMessage;

  String? selectedSport = "Футбол";
  List<Map<String, dynamic>> _catalogPreview = [];
  List<Map<String, dynamic>> _ticketsData = [];
  List<Map<String, dynamic>> _reelsData = [];

  // Cache
  final Map<String, dynamic> dataCache = {};
  final Map<String, DateTime> cacheTimestamps = {};
  final Map<String, List<Map<String, dynamic>>> _eventsCache = {};
  final Map<String, DateTime> _eventsCacheTimestamps = {};
  final Map<String, List<Map<String, dynamic>>> _userPostsCache = {};
  final Map<String, DateTime> _userPostsTimestamps = {};

  @override
  void initState() {
    super.initState();

    _ticketsData = _getDefaultTickets();
    _loadInitialData();
   

    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppUpdateService.checkAndShow(context);
      // ❌ Старый чекер НЕ запускаем:
      // UpdateChecker.checkForUpdate(context, silent: true);
    });
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
        //_loadCachedData('schools', () => _fetchSchoolsBySport(selectedSport ?? 'Футбол')),
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

  void _openEventsAll() {
    final sport = selectedSport ?? 'Футбол';
    final events = _eventsCache[sport] ?? <Map<String, dynamic>>[];

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: SportPalette.slateBg,
          appBar: AppBar(
            title: const Text('Мероприятия'),
            backgroundColor: SportPalette.primaryGreen,
          ),
          body: events.isEmpty
              ? const Center(child: Text('Мероприятий пока нет'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: events.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    return SizedBox(
                      height: kCardHeight,
                      child: _buildEventCard(events[index]),
                    );
                  },
                ),
        ),
      ),
    );
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

  Future<List<Map<String, dynamic>>> _fetchSchoolsBySport(String sport) async {
    try {
      final response = await dio.get('get_schools_by_sport.php', queryParameters: {'sport': sport});
      return List<Map<String, dynamic>>.from(response.data);
    } on DioException catch (e) {
      throw Exception('Ошибка загрузки школ: ${e.message}');
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
  'title': (m['title'] ?? '').toString(), // ✅ ДОБАВИЛИ
  'text': (m['body'] ?? '').toString(),
  'imageUrl': imageUrl,
  'date': DateTime.tryParse((m['created_at'] ?? '').toString()) ?? DateTime.now(),
   'authorAvatar': avatarUrl,
  'authorName': full,
};      }).toList();

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
    } catch (e) {
      // Игнорируем ошибки загрузки видео
    }
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
    } catch (e) {
      // Игнорируем ошибки постов
    }
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

  // ================== NAVIGATION ==================
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
  //} else if (key == "Тренировки") {
  //  _showTrainingMenu(context);
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

  void _showTrainingMenu(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const AddPersonalTrainingScreen(),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  // ================== BUILD ==================
  @override
  Widget build(BuildContext context) {
    if (hasError) {
      return Scaffold(
        backgroundColor: SportPalette.slateBg,
        body: Center(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
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
                  style: AppText.h3.copyWith(fontSize: 18),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _loadInitialData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SportPalette.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
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
  backgroundColor: SportPalette.lightGreen,
  body: SafeArea(
    child: CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        _buildAnimatedHeaderSliver(),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: kPageHPad),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                const SizedBox(height: 32),

                if (_reelsData.isNotEmpty) ...[
                  _buildVideoSection(),
                  const SizedBox(height: 24),

                  _HomePromoBanner(
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
                  ),

                  const SizedBox(height: 24),
                ],

                _buildInnovationsSection(),
                const SizedBox(height: 24),

                _buildEventsSection(),
                const SizedBox(height: 32),

                _buildVenuesSection(),
                const SizedBox(height: 24),

                if (dataCache['teams'] != null &&
                    (dataCache['teams'] as List).isNotEmpty) ...[
                  _buildClubsSection(),
                  const SizedBox(height: 24),
                ],

                _buildTicketsSection(),
                const SizedBox(height: 24),

                _buildUserPostsSection(),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ],
    ),
  ),
);
}


  // ================== SECTION WIDGETS ==================
  Widget _buildVideoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: 'Популярные видео',
          subtitle: 'Лучшие ролики сообщества',
          icon: Icons.play_circle_fill_rounded,
          color: SportPalette.primaryGreen,
          onSeeAll: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ReelsScreen()),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _reelsData.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.only(right: index == _reelsData.length - 1 ? 0 : 16),
                child: SizedBox(
                  width: 180,
                  child: _buildReelCard(_reelsData[index]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReelCard(Map<String, dynamic> reel) {
    final thumb = (reel['thumbnail'] ?? '').toString();
    final desc = (reel['description'] ?? 'Видео').toString();
    final views = _formatCount((reel['views'] ?? 0).toString());

    return sportCard(
      topHeight: 132,
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => ReelsScreen()));
      },
      top: Stack(
        fit: StackFit.expand,
        children: [
          // preview
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(kRadius)),
            child: thumb.isNotEmpty
                ? Image.network(
                    thumb,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (_, __, ___) => _reelFallback(),
                  )
                : _reelFallback(),
          ),

          // overlay
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.22),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(kRadius)),
            ),
          ),

          // play button
          Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: SportPalette.primaryGreen.withOpacity(0.92),
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
     body: Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(
      desc,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w800,
        height: 1.15,
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
        const SizedBox(width: 16),
        _statItem(
          icon: Icons.chat_bubble_outline_rounded,
          value: _formatCount('${reel['comments'] ?? 0}'),
        ),
      ],
    ),

    const Spacer(),
  ],
),

    );
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
        color: SportPalette.textMuted,
      ),
      const SizedBox(width: 6),
      Text(
        value,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: SportPalette.textMuted,
        ),
      ),
    ],
  );
}


  Widget _reelFallback() {
    return Container(
      color: SportPalette.primaryGreen.withOpacity(0.08),
      child: Center(
        child: Icon(Icons.videocam_rounded, color: SportPalette.primaryGreen, size: 48),
      ),
    );
  }

  Widget _buildInnovationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: 'AR функции',
          subtitle: 'Новые технологии для спорта',
          icon: Icons.auto_awesome_rounded,
          color: SportPalette.primaryGreen,
          onSeeAll: null,
        ),
        const SizedBox(height: 16),
        const InnovationsSection(),
      ],
    );
  }

  Widget _buildEventsSection() {
    final sport = selectedSport ?? 'Футбол';
    final events = _eventsCache[sport] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: 'Мероприятия',
          subtitle: 'Предстоящие события',
          icon: Icons.event_rounded,
          color: SportPalette.accentGreen,
          onSeeAll: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => EventsListScreen(initialSport: sport),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: kCardHeight,
          child: events.isEmpty
              ? _buildLoadingPlaceholder()
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: EdgeInsets.only(right: index == events.length - 1 ? 0 : 16),
                      child: SizedBox(
                        width: 300,
                        child: _buildEventCard(events[index]),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event) {
    final title = (event['title'] ?? 'Событие').toString();
    final date = (event['event_date'] ?? '').toString();
    final location = (event['location'] ?? 'Локация не указана').toString();
    final imageUrl = (event['image'] ?? '').toString();

    return sportCard(
      topHeight: 140,
      bodyPadding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
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
      top: imageUrl.isNotEmpty
          ? Image.network(
              imageUrl,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, __, ___) => _eventFallback(),
            )
          : _eventFallback(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, height: 1.15),
          ),
          const SizedBox(height: 10),

          if (date.isNotEmpty) ...[
            _metaRow(Icons.calendar_today_rounded, date),
            const SizedBox(height: 6),
          ],
          _metaRow(Icons.location_on_rounded, location),

          const Spacer(),

          Row(
            children: const [
              Text('Открыть', style: TextStyle(fontWeight: FontWeight.w800)),
              Spacer(),
              Icon(Icons.chevron_right_rounded, color: SportPalette.textMuted),
            ],
          ),
        ],
      ),
    );
  }

  Widget _eventFallback() {
    return Container(
      color: SportPalette.accentGreen.withOpacity(0.10),
      child: Center(
        child: Icon(Icons.event_rounded, color: SportPalette.accentGreen, size: 48),
      ),
    );
  }

  Widget _buildVenuesSection() {
    final venues = (dataCache['venues'] ?? []) as List;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: 'Спортивные площадки',
          subtitle: 'Бронирование и информация',
          icon: Icons.location_on_rounded,
          color: SportPalette.primaryGreenLight,
          onSeeAll: venues.isNotEmpty ? _openVenuesAll : null,
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: kCardHeight,
          child: venues.isEmpty
              ? _buildLoadingPlaceholder()
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: venues.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: EdgeInsets.only(right: index == venues.length - 1 ? 0 : 16),
                      child: SizedBox(
                        width: 300,
                        child: _buildVenueCard(venues[index] as Map<String, dynamic>),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildVenueCard(Map<String, dynamic> venue) {
    return sportCard(
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
      top: Image.network(
        (venue['image'] ?? '').toString(),
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => Container(
          color: SportPalette.primaryGreenLight.withOpacity(0.08),
          child: Center(
            child: Icon(Icons.location_on_rounded, color: SportPalette.primaryGreenLight, size: 48),
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            (venue['title'] ?? '').toString(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.2),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.place_rounded, size: 14, color: SportPalette.textMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  (venue['address'] ?? '').toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: SportPalette.textMuted),
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
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: SportPalette.primaryGreenLight,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildClubsSection() {
    final teams = (dataCache['teams'] ?? []) as List<Map<String, dynamic>>;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: 'Спортивные клубы',
          subtitle: 'Профессиональные команды',
          icon: Icons.groups_rounded,
          color: SportPalette.accentGreen,
          onSeeAll: teams.isNotEmpty ? _openClubsAll : null,
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: kCardHeight,
          child: teams.isEmpty
              ? _buildLoadingPlaceholder()
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: teams.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: EdgeInsets.only(right: index == teams.length - 1 ? 0 : 16),
                      child: SizedBox(
                        width: 300,
                        child: _buildTeamCard(teams[index]),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTeamCard(Map<String, dynamic> team) {
    final name = (team['name'] ?? 'Клуб').toString();
    final sportText = (team['sport'] ?? selectedSport ?? 'Спорт').toString();
    final city = (team['city'] ?? '').toString();

    final logoUrl = _teamLogoFromAnyKey(team);
    final accent = _teamAccentBySport(sportText);

    return sportCard(
      topHeight: 132,
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
      top: Stack(
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
            ),
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0.16,
              child: Image.network(
                'https://sportotekaapp.ru/assets/patterns/noise.png',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
          Center(
            child: _teamLogoWidget(
              teamName: name,
              logoUrl: logoUrl,
              accent: accent,
              size: 84,
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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, height: 1.15),
          ),
          const SizedBox(height: 10),

          _metaRow(Icons.sports_rounded, sportText),
          const SizedBox(height: 6),
          if (city.isNotEmpty) _metaRow(Icons.place_rounded, city),

          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildTicketsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: 'Билеты на матчи',
          subtitle: 'РФ / РБ, 2025',
          icon: Icons.confirmation_number_rounded,
          color: SportPalette.primaryGreenDark,
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
          height: kCardHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _ticketsData.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.only(right: index == _ticketsData.length - 1 ? 0 : 16),
                child: SizedBox(
                  width: 300,
                  child: _buildTicketCard(_ticketsData[index]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTicketCard(Map<String, dynamic> ticket) {
    final teams = (ticket['teams'] ?? 'Матч').toString();
    final date = (ticket['date'] ?? '').toString();
    final venue = (ticket['venue'] ?? '').toString();
    final price = (ticket['price'] ?? '').toString();

    return sportCard(
      topHeight: 64,
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
      top: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [SportPalette.primaryGreenDark, Color(0xFF008C40)],
          ),
        ),
        child: Row(
          children: const [
            Icon(Icons.confirmation_number_rounded, color: Colors.white, size: 22),
            SizedBox(width: 12),
            Text(
              'БИЛЕТЫ',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 14,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            teams,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, height: 1.15),
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
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: SportPalette.primaryGreenDark,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUserPostsSection() {
    final sport = selectedSport ?? 'Футбол';
    final posts = _userPostsCache[sport] ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: 'Новости сообщества',
          subtitle: 'Обновления от пользователей',
          icon: Icons.forum_rounded,
          color: SportPalette.primaryGreen,
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
          height: 240,
          child: posts.isEmpty
              ? _buildEmptyPlaceholder(
                  icon: Icons.forum_outlined,
                  text: 'Пока нет новостей',
                )
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    final post = posts[index];
                    final hasImage = (post['imageUrl'] ?? '').toString().isNotEmpty;

                    return Padding(
                      padding: EdgeInsets.only(right: index == posts.length - 1 ? 0 : 16),
                      child: SizedBox(
                        width: hasImage ? 300 : 280,
                        child: _buildUserPostCard(post),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildUserPostCard(Map<String, dynamic> post) {
  final title = (post['title'] ?? '').toString();
  final text = (post['text'] ?? '').toString();
  final author = (post['authorName'] ?? 'Пользователь').toString();
  final imageUrl = (post['imageUrl'] ?? '').toString();
  final hasImage = imageUrl.isNotEmpty;
  final avatarUrl = (post['authorAvatar'] ?? '').toString();

  return sportCard(
    topHeight: hasImage ? 132 : 84,
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

    // ===== TOP =====
    top: hasImage
        ? Image.network(
            imageUrl,
            fit: BoxFit.cover,
            width: double.infinity,
            errorBuilder: (_, __, ___) => Container(
              color: SportPalette.primaryGreen.withOpacity(0.08),
              child: Center(
                child: Icon(Icons.image_rounded, color: SportPalette.primaryGreen, size: 48),
              ),
            ),
          )
        : Container(
            color: SportPalette.primaryGreen.withOpacity(0.06),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                _authorAvatarWidget(
                  avatarUrl: avatarUrl,
                  author: author,
                  radius: 18,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: SportPalette.text,
                    ),
                  ),
                ),
              ],
            ),
          ),

    // ===== BODY =====
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasImage) ...[
          Row(
            children: [
              _authorAvatarWidget(
                avatarUrl: avatarUrl,
                author: author,
                radius: 18,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatPostDateHome(post['date'] as DateTime),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: SportPalette.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],

        if (title.trim().isNotEmpty) ...[
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              height: 1.15,
              color: SportPalette.text,
            ),
          ),
          const SizedBox(height: 8),
        ],

        Expanded(
          child: Text(
            text.isNotEmpty ? text : 'Интересная новость от сообщества',
            maxLines: hasImage ? 4 : 5,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: hasImage ? 13 : 14,
              color: SportPalette.text,
              height: 1.5,
            ),
          ),
        ),

        const SizedBox(height: 10),
        Row(
          children: [
            Text(
              _formatPostDateHome(post['date'] as DateTime),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: SportPalette.textMuted),
            ),
            const Spacer(),
            Icon(Icons.chevron_right_rounded, size: 20, color: SportPalette.textMuted),
          ],
        ),
      ],
    ),
  );
}

Widget _authorAvatarWidget({
  required String avatarUrl,
  required String author,
  double radius = 18,
}) {
  final url = _normalizeMediaUrl(avatarUrl);

  return CircleAvatar(
    radius: radius,
    backgroundColor: SportPalette.primaryGreen.withOpacity(0.12),
    backgroundImage: url.isNotEmpty ? NetworkImage(url) : null,
    child: url.isEmpty
        ? Text(
            author.trim().isNotEmpty ? author.trim()[0].toUpperCase() : 'П',
            style: const TextStyle(
              color: SportPalette.primaryGreen,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          )
        : null,
  );
}
  
  
 

  // ================== HELPER WIDGETS ==================
  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    VoidCallback? onSeeAll,
  }) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  color: SportPalette.textMuted,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
        if (onSeeAll != null)
          GestureDetector(
            onTap: onSeeAll,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Text(
                    'Все',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.chevron_right_rounded, size: 18, color: color),
                ],
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(kRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
            ),
          ],
        ),
        padding: const EdgeInsets.all(40),
        child: const CircularProgressIndicator(
          color: SportPalette.primaryGreen,
          strokeWidth: 3,
        ),
      ),
    );
  }

  Widget _buildEmptyPlaceholder({required IconData icon, required String text}) {
    return Center(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(kRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
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
              color: SportPalette.textLight,
            ),
            const SizedBox(height: 16),
            Text(
              text,
              style: const TextStyle(
                color: SportPalette.textMuted,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================== HEADER ==================
  SliverAppBar _buildAnimatedHeaderSliver() {
    const double expandedH = 360.0;
      const double collapsedExtra = 16.0;

    return SliverAppBar(
      pinned: true,
      floating: false,
      snap: false,
      backgroundColor: AppColors.primaryGreen,
      elevation: 0,
      expandedHeight: expandedH,
      collapsedHeight: kToolbarHeight + collapsedExtra,
      automaticallyImplyLeading: false,
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final minH = kToolbarHeight + collapsedExtra;
          final maxH = expandedH;
          final currentH = constraints.biggest.height;

          // t = 1.0 когда хедер раскрыт, t = 0.0 когда схлопнут
          final t = ((currentH - minH) / (maxH - minH)).clamp(0.0, 1.0);

          final quickScale = lerpDouble(0.78, 1.0, t)!;
          final labelOpacity = lerpDouble(0.0, 1.0, t)!;
          final blockOpacity = lerpDouble(0.85, 1.0, t)!;

          // ✅ Цвет body — должен совпадать со Scaffold.backgroundColor
          final bodyBg = SportPalette.lightGreen;

          // ✅ Fade усиливается при раскрытом хедере
          final fadeH = lerpDouble(18.0, 56.0, t)!.clamp(18.0, 64.0);
          final fadeMid = lerpDouble(0.30, 0.72, t)!;
          final fadeEnd = lerpDouble(0.68, 1.00, t)!;

          return Stack(
  fit: StackFit.expand,
  children: [
    // 1) Градиент фона
    Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryDark,
            AppColors.primaryGreen,
            AppColors.primaryLight,
          ],
          stops: [0.0, 0.58, 1.0],
        ),
      ),
    ),

    // 2) Мягкая засветка
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

    // 3) Переход в цвет body
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

    // ================= SAFE AREA =================
    SafeArea(
      bottom: false,
      child: Stack(
        children: [

          // ===== ЗАГОЛОВОК + СЛОГАН (теперь исчезают при схлопывании) =====
          Positioned(
            left: kPageHPad,
            top: 14,
            child: IgnorePointer(
              ignoring: t < 0.05,
              child: Opacity(
                opacity: t, // ← вот ключевая строка
                child: Transform.translate(
                  offset: Offset(0, lerpDouble(-10.0, 0.0, t)!),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Спортотека Футбол",
                        style: AppText.h1,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Вместе к победам!",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.95),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ===== РАСКРЫТЫЙ БЛОК (быстрые действия) =====
          Positioned(
            left: 0,
            right: 0,
            top: 90,
            bottom: 16,
            child: Opacity(
              opacity: t,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: kPageHPad),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Opacity(
                      opacity: blockOpacity,
                      child: Transform.scale(
                        scale: quickScale,
                        alignment: Alignment.topCenter,
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(.18),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withOpacity(.30),
                            ),
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
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ===== СХЛОПНУТАЯ СТРОКА =====
          Positioned(
            left: kPageHPad,
            right: kPageHPad,
            bottom: 8,
            child: Opacity(
              opacity: (1.0 - t).clamp(0.0, 1.0),
              child: _CollapsedQuickRow(
                onSearchTap: _openSearch,
                onActionTap: (key) => _onQuickAction(key),
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

// ================== HEADER COMPONENTS ==================
class _CollapsedQuickRow extends StatelessWidget {
  final VoidCallback onSearchTap;
  final void Function(String) onActionTap;

  const _CollapsedQuickRow({required this.onSearchTap, required this.onActionTap});

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
                color: Colors.white.withOpacity(.18),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withOpacity(.28)),
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
              final color = a.keyName == 'Тренировки'
                  ? SportPalette.accentGreen
                  : a.keyName == 'Бронь'
                      ? SportPalette.primaryGreenLight
                      : a.keyName == 'Расписание'
                          ? SportPalette.primaryGreen
                          : SportPalette.primaryGreen;
              return _MagnetIcon(
                size: 48,
                color: color,
                icon: a.icon,
                onTap: () => onActionTap(a.keyName),
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

  const HeaderQuickActionsGrid({super.key, required this.onTap, required this.labelOpacity});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _headerActions.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: .9,
      ),
      itemBuilder: (ctx, i) {
        final item = _headerActions[i];
        final color = item.keyName == 'Тренировки'
            ? SportPalette.accentGreen
            : item.keyName == 'Бронь'
                ? SportPalette.primaryGreenLight
                : item.keyName == 'Расписание'
                    ? SportPalette.primaryGreen
                    : SportPalette.primaryGreen;
        return Column(
          children: [
            _MagnetIcon(
              size: 56,
              color: color,
              icon: item.icon,
              onTap: () => onTap(item.keyName),
            ),
            const SizedBox(height: 8),
            Opacity(
              opacity: labelOpacity,
              child: Text(
                item.titleRu,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11,
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

  const _MagnetIcon({required this.size, required this.color, required this.icon, required this.onTap});

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
                widget.color.withOpacity(.85),
                widget.color,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(_down ? .18 : .32),
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

// ================== SCHEDULE SCREEN PLACEHOLDER ==================
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

// ================== CARD HELPERS ==================
Widget sportCard({
  required Widget top,
  required Widget body,
  double topHeight = 140,
  EdgeInsets bodyPadding = const EdgeInsets.all(kCardPadding),
  VoidCallback? onTap,
}) {
  return Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(kRadius),
    clipBehavior: Clip.hardEdge,
    child: InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(kRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: topHeight, child: top),
            Expanded(
              child: Container(
                color: SportPalette.cardSoft,
                padding: bodyPadding,
                child: body,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _metaRow(IconData icon, String text) {
  return Row(
    children: [
      Icon(icon, size: 14, color: SportPalette.textMuted),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, color: SportPalette.textMuted),
        ),
      ),
    ],
  );
}

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

Color _teamAccentBySport(String sport) {
  final s = sport.toLowerCase();
  if (s.contains('фут')) return SportPalette.primaryGreen;
  if (s.contains('хок')) return SportPalette.primaryGreenDark;
  if (s.contains('баскет')) return SportPalette.accentGreen;
  if (s.contains('волей')) return SportPalette.primaryGreenLight;
  if (s.contains('теннис')) return SportPalette.accentGreen;
  return SportPalette.accentGreen;
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
  double size = 84,
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

class _HomePromoBanner extends StatefulWidget {
  final String title;
  final String subtitle;
  final String buttonText;
  final VoidCallback onClose;
  final VoidCallback onTap;
  final bool showClose;

  const _HomePromoBanner({
    required this.title,
    required this.subtitle,
    required this.buttonText,
    required this.onClose,
    required this.onTap,
    this.showClose = true,
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
    return SlideTransition(
      position: _offset,
      child: FadeTransition(
        opacity: _opacity,
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0F172A),
                  Color(0xFF0B5E36),
                  Color(0xFF00A750),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.20),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
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
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
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
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.subtitle,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.92),
                                fontSize: 13,
                                height: 1.35,
                                fontWeight: FontWeight.w600,
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
                                      foregroundColor: SportPalette.primaryGreenDark,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(vertical: 13),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: Text(
                                      widget.buttonText,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
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
