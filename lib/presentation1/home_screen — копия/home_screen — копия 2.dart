import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:pool/pool.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/presentation/global_search_screen/global_search_screen.dart';
import 'package:sportoteka/presentation/booking_screen/booking_screen.dart';
import 'package:sportoteka/presentation/booking_screen/venue_booking_screen.dart';
import 'package:sportoteka/presentation/reels_screen/reels_screen.dart';
import 'package:sportoteka/presentation/service_screens/generic_service_screen.dart';
import 'package:sportoteka/presentation/service_screens/calendar_event_screen.dart';
import 'package:sportoteka/presentation/service_screens/event_detail_screen.dart';
import 'package:sportoteka/presentation/community_screen/news_detail_screen.dart';
import 'package:sportoteka/presentation/community_screen/sport_community_screen.dart';
import 'package:sportoteka/widgets/parsed_news_section.dart';
import 'package:sportoteka/presentation/add_personal_training_screen/add_personal_training_screen.dart';
import 'package:sportoteka/presentation/team_screen/team_detail_screen.dart';
import 'package:sportoteka/presentation/catalog/team_list_screen.dart';
import 'package:sportoteka/presentation/catalog/schools_catalog_screen.dart';
import 'package:sportoteka/presentation/catalog/school_list_screen.dart';
import 'package:sportoteka/presentation/school_detail_screen/school_detail_screen.dart';
import 'package:sportoteka/widgets/top_athletes_widget.dart';
import 'package:sportoteka/widgets/sportoteka_ring_banner.dart';
import 'package:sportoteka/presentation/innovation/innovations_section.dart';
import 'package:sportoteka/presentation/tickets/tickets_section.dart';
import 'package:sportoteka/update_checker.dart';

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

/// ================== SPORT PALETTE ==================
class SportPalette {
  static const blue = Color(0xFF1E74C4);
  static const blueDeep = Color(0xFF005AAB);
  static const sky = Color(0xFF5AC8FA);
  static const teal = Color(0xFF10B981);
  static const amber = Color(0xFFF59E0B);
  static const grape = Color(0xFF7C3AED);
  static const coral = Color(0xFFFB6A6A);
  static const slateBg = Color(0xFFF5F7FA);
  static const card = Colors.white;
  static const text = Color(0xFF0F172A);
  static const textMuted = Color(0xFF64748B);
  static const textLight = Color(0xFF94A3B8);
}

/// ================== IMPROVED TYPOGRAPHY ==================
class AppText {
  // HEADERS
  static const h1 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.5,
    color: Colors.white,
    height: 1.2,
  );
  
  static const h2 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.3,
    color: SportPalette.text,
    height: 1.2,
  );
  
  static const h3 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: SportPalette.text,
    height: 1.3,
  );
  
  // BODY TEXT
  static const bodyLarge = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: SportPalette.text,
    height: 1.5,
    letterSpacing: 0.1,
  );
  
  static const body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: SportPalette.text,
    height: 1.6,
  );
  
  static const bodySmall = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: SportPalette.text,
    height: 1.5,
  );
  
  // CAPTIONS
  static const caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: SportPalette.textMuted,
    height: 1.4,
    letterSpacing: 0.2,
  );
  
  static const captionSmall = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: SportPalette.textLight,
    height: 1.3,
    letterSpacing: 0.3,
  );
  
  static const overline = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: Colors.white70,
    letterSpacing: 0.5,
    height: 1.2,
  );
  
  // SPECIAL STYLES
  static const button = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: Colors.white,
    letterSpacing: 0.3,
  );
  
  static const cardTitle = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: Colors.white,
    height: 1.2,
  );
  
  static const cardSubtitle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: Colors.white70,
    height: 1.2,
  );
}

/// ================== CATEGORY COLORS ==================
final Map<String, Color> categoryColors = {
  'Бронь': SportPalette.sky,
  'Тренировки': SportPalette.teal,
  'Расписание': SportPalette.amber,
  'Видео': SportPalette.grape,
  'Новости': SportPalette.blue,
  'Сервисы и приложения': Colors.blueGrey,
  'Футбол': SportPalette.teal,
  'Сервисы': SportPalette.blue,
  'Клуб': SportPalette.blueDeep,
  'Академия': SportPalette.amber,
  'Мультимедиа': SportPalette.grape,
  'Болельщикам': SportPalette.coral,
  'Турнирная таблица': SportPalette.teal,
  'Билеты': SportPalette.amber,
  'Статистика': SportPalette.teal,
  'Инвентарь': SportPalette.amber,
  'Трансферы': SportPalette.coral,
};

/// ================== UI CONSTANTS ==================
const double kPageHPad = 16;
const double kSectionGap = 20;
const double kCardHeight = 180;
const double kSmallRadius = 12;
const double kBigRadius = 16;

// Typography shortcuts
TextStyle get _title20w800 => AppText.h2.copyWith(fontSize: 20);
TextStyle get _title18w700 => AppText.h3.copyWith(fontSize: 18, fontWeight: FontWeight.w700);
TextStyle get _body16w500 => AppText.bodyLarge.copyWith(fontSize: 16);
TextStyle get _body14w400 => AppText.body;
TextStyle get _caption12w500 => AppText.caption;
TextStyle get _caption11w600 => AppText.captionSmall.copyWith(fontWeight: FontWeight.w600);

Widget vgap(double h) => SizedBox(height: h);
Widget hgap(double w) => SizedBox(width: w);

/// ================== HEADER ACTIONS ==================
const List<_HeaderActionItem> _headerActions = [
  _HeaderActionItem(keyName: 'Тренировки', titleRu: 'Тренировки', icon: Icons.fitness_center_rounded),
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

class _HomeScreenState extends State<HomeScreen> {
  bool isLoading = true;
  bool hasError = false;
  String? errorMessage;

  String? selectedSchool;
  String? selectedTeam;
  String? selectedSport = "Футбол";
  String? selectedClub = "Динамо Минск";

  bool showTeamData = false;
  bool showClubStaff = false;
  bool isLoadingTable = false;

  List<Map<String, String>> teamData = [];
  List<Map<String, dynamic>> schoolList = [];
  List<Map<String, dynamic>> _catalogPreview = [];

  // Cache
  final Map<String, dynamic> dataCache = {};
  final Map<String, DateTime> cacheTimestamps = {};
  final Map<String, List<Map<String, dynamic>>> _eventsCache = {};
  final Map<String, DateTime> _eventsCacheTimestamps = {};
  final Map<String, List<Map<String, dynamic>>> _userPostsCache = {};
  final Map<String, DateTime> _userPostsTimestamps = {};

  Future<List<dynamic>>? _reelsFuture;

  // 🎟️ Тикеты
  final List<Map<String, dynamic>> _ticketsData = [
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
    {
      'teams': 'Динамо-Минск — домашние матчи',
      'date': 'август 2025',
      'venue': 'Минск-Арена',
      'price': 'динамически',
      'url': 'https://hcdinamo.by/tickets/',
    },
    {
      'teams': 'Суперкубок России 2025',
      'date': 'лето 2025',
      'venue': 'Казань',
      'price': 'динамически',
      'url': 'https://supercup.rfs.ru/',
    },
  ];

  @override
  void initState() {
    super.initState();
    _reelsFuture = _fetchReels();
    _loadInitialData();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateChecker.checkForUpdate(context, silent: true);
    });
  }

  /// ================== NAV: OPEN ALL ==================
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

  Future<List<Map<String, dynamic>>> _fetchCatalogPreview() async {
    try {
      final res = await dio.get('get_schools.php', queryParameters: {
        'limit': 12, 'offset': 0,
      });
      if (res.data is Map && res.data['items'] is List) {
        return List<Map<String, dynamic>>.from(res.data['items']);
      } else if (res.data is List) {
        return List<Map<String, dynamic>>.from(res.data);
      }
      return const [];
    } catch (e) {
      debugPrint('Ошибка каталога (превью): $e');
      return const [];
    }
  }

  /// ================== LOAD INITIAL ==================
  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() {
      isLoading = true;
      hasError = false;
      errorMessage = null;
    });

    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        throw Exception('Нет интернет-соединения');
      }

      await Future.wait([
        _loadEvents(selectedSport ?? 'Футбол'),
        _loadCachedData('venues', () => _fetchVenues('Все')),
        _loadCachedData('schools', () => _fetchSchoolsBySport(selectedSport ?? 'Футбол')),
        _loadCachedData('teams', () => _fetchTeamsBySport(selectedSport ?? 'Футбол')),
        _loadCachedData('catalog_preview', () async {
          final data = await _fetchCatalogPreview();
          _catalogPreview = data;
          return data;
        }),
        _loadUserPosts(selectedSport ?? 'Футбол'),
      ]);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        hasError = true;
        errorMessage = e.toString();
      });
      debugPrint('Ошибка при загрузке данных: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
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
      debugPrint('Ошибка загрузки мероприятий для $sport: $e');
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
      debugPrint('Ошибка загрузки пользовательских постов для $sport: $e');
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
      debugPrint('Ошибка загрузки данных для $key: $e');
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

  /// ================== API FETCHES ==================
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
        final last  = (m['last_name'] ?? '').toString();
        final full  = ('$first $last').trim().isEmpty ? 'Пользователь' : ('$first $last').trim();
        final rawImg = (m['image'] ?? '').toString();
        final imageUrl = rawImg.isEmpty ? '' : (rawImg.startsWith('http') ? rawImg : 'https://sportotekaapp.ru/$rawImg');
        return {
          'id': int.tryParse('${m['id']}') ?? 0,
          'text': (m['body'] ?? '').toString(),
          'imageUrl': imageUrl,
          'date': DateTime.tryParse((m['created_at'] ?? '').toString()) ?? DateTime.now(),
          'authorName': full,
        };
      }).toList();

      out.sort((a,b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
      return out.take(8).toList();
    } on DioException catch (e) {
      throw Exception('Ошибка загрузки постов: ${e.message}');
    }
  }

  Future<void> _loadSchoolsBySport(String sport) async {
    try {
      final schools = await _fetchSchoolsBySport(sport);
      setState(() {
        schoolList = schools;
        dataCache['schools'] = schools;
        cacheTimestamps['schools'] = DateTime.now();
      });
    } catch (e) {
      debugPrint('Ошибка загрузки школ: $e');
    }
  }

  /// ================== REELS ==================
  Future<List<dynamic>> _fetchReels() async {
    try {
      final response = await dio.get('get_reels.php', options: Options(responseType: ResponseType.json));
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
      return normalized;
    } on DioException catch (e) {
      debugPrint('Ошибка загрузки Reels: ${e.message}');
      return [];
    } catch (e) {
      debugPrint('Ошибка парсинга Reels: $e');
      return [];
    }
  }

  /// ================== BUILD ==================
  @override
  Widget build(BuildContext context) {
    if (hasError) {
      return Scaffold(
        backgroundColor: SportPalette.slateBg,
        body: Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.06),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  errorMessage ?? 'Произошла ошибка',
                  style: AppText.h3,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadInitialData,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SportPalette.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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
      backgroundColor: SportPalette.slateBg,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Анимированный header
            _buildAnimatedHeaderSliver(),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
            SliverToBoxAdapter(child: _buildSportChipsRow()),
            const SliverToBoxAdapter(child: SizedBox(height: 12)),

            // Баннер часов
            SliverToBoxAdapter(
              child: SportotekaRingBanner(
                imageUrl: 'https://yourcdn.com/static/hero/sportoteka_ring.png',
                title: 'Sportoteka One Ring',
                subtitle: 'Пульс • Сон • HRV • Готовность',
                ctaText: 'Подробнее',
                dark: false,
                onCta: () {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Sportoteka One Ring'),
                      content: const Text(
                        'Умное кольцо для спорта и жизни: мониторинг пульса, сна, HRV, готовности к нагрузке.\nСинхронизация со Спортотекой.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Закрыть'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // Топ атлетов
            SliverToBoxAdapter(
              child: Column(
                children: [
                  TopAthletesWidget(apiUrl: 'https://sportotekaapp.ru/api/get_athletes.php'),
                  const SizedBox(height: 16),
                ],
              ),
            ),

            // Инновации
            SliverToBoxAdapter(
              child: Section(
                icon: Icons.auto_awesome_rounded,
                title: "Инновации Спортотека",
                subtitle: "Новые технологии для спорта",
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: kPageHPad),
                  child: InnovationsSection(),
                ),
              ),
            ),

            // Остальные секции
            SliverToBoxAdapter(child: _buildReelsSection()),
            SliverToBoxAdapter(child: _buildEventsSection_v2()),
            SliverToBoxAdapter(child: _buildVenuesSection_v2()),
            SliverToBoxAdapter(child: _buildCatalogSection()),

            if (dataCache['teams'] != null && (dataCache['teams'] as List).isNotEmpty)
              SliverToBoxAdapter(child: _buildClubsSectionLikeInnovations()),
            
            if (dataCache['schools'] != null && (dataCache['schools'] as List).isNotEmpty)
              SliverToBoxAdapter(child: _buildSchoolsSectionLikeInnovations()),

            SliverToBoxAdapter(child: _buildTicketsSectionLikeInnovations()),
            SliverToBoxAdapter(child: _buildUserPostsSection()),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  /// ================== ANIMATED HEADER SLIVER ==================
  SliverAppBar _buildAnimatedHeaderSliver() {
    const double expandedH = 340.0;
    return SliverAppBar(
      pinned: true,
      floating: false,
      snap: false,
      backgroundColor: SportPalette.blueDeep,
      elevation: 0,
      expandedHeight: expandedH,
      collapsedHeight: kToolbarHeight + 64,
      automaticallyImplyLeading: false,
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final minH = kToolbarHeight + 64;
          final maxH = expandedH;
          final currentH = constraints.biggest.height;
          final t = ((currentH - minH) / (maxH - minH)).clamp(0.0, 1.0);

          final quickScale = lerpDouble(0.78, 1.0, t)!;
          final labelOpacity = lerpDouble(0.0, 1.0, t)!;
          final blockOpacity = lerpDouble(0.85, 1.0, t)!;

          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(0, -1),
                end: Alignment(0, 1),
                colors: [SportPalette.blueDeep, SportPalette.blue, Color(0xFFE7F2FB)],
                stops: [0, .60, 1],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Stack(
                children: [
                  // top row
                  Positioned(
                    left: kPageHPad,
                    right: kPageHPad,
                    top: 10,
                    child: Row(
                      children: [
                        const Text("Спортотека", style: AppText.h1),
                        const Spacer(),
                        _GlassIconButton(
                          icon: Icons.search_rounded,
                          onPressed: _openSearch,
                        ),
                      ],
                    ),
                  ),
                  // expanded content
                  Positioned(
                    left: 0,
                    right: 0,
                    top: 62,
                    bottom: 12,
                    child: Opacity(
                      opacity: t,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: kPageHPad),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            Text(
                              "Категории спорта",
                              style: AppText.overline.copyWith(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Opacity(
                              opacity: blockOpacity,
                              child: Transform.scale(
                                scale: quickScale,
                                alignment: Alignment.topCenter,
                                child: Container(
                                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(.18),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.white.withOpacity(.30)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Быстрые действия",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      SizedBox(
                                        height: 96,
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
                  // collapsed row
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
          );
        },
      ),
    );
  }

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

  /// ================== SPORT CHIPS ==================
  Widget _buildSportChipsRow() {
    return SizedBox(
      height: 92,
      child: ListView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: kPageHPad),
        children: [
          _buildSportIcon("Футбол", Icons.sports_soccer_rounded),
          _buildSportIcon("Хоккей", Icons.sports_hockey_rounded),
          _buildSportIcon("Баскетбол", Icons.sports_basketball_rounded),
          _buildSportIcon("Волейбол", Icons.sports_volleyball_rounded),
          _buildSportIcon("Теннис", Icons.sports_tennis_rounded),
        ],
      ),
    );
  }

  Widget _buildSportIcon(String title, IconData iconData) {
    final isSelected = selectedSport == title;
    final bg = isSelected ? SportPalette.blue : Colors.white;
    final ic = isSelected ? Colors.white : SportPalette.text;
    
    return GestureDetector(
      onTap: () async {
        if (isSelected) return;
        setState(() {
          isLoading = true;
          selectedSport = title;
          selectedClub = null;
          showTeamData = false;
          selectedSchool = null;
        });
        try {
          await Future.wait([
            _loadEvents(title),
            _loadSchoolsBySport(title),
            _loadCachedData('teams', () => _fetchTeamsBySport(title)),
            _loadCachedData('venues', () => _fetchVenues('Все')),
            _loadUserPosts(title),
          ]);
        } finally {
          if (mounted) setState(() => isLoading = false);
        }
        widget.onSportChanged?.call(title);
      },
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(colors: [SportPalette.sky, SportPalette.blue])
                    : null,
                borderRadius: BorderRadius.circular(36),
              ),
              child: CircleAvatar(
                radius: 30,
                backgroundColor: bg,
                child: Icon(iconData, size: 28, color: ic),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: AppText.captionSmall.copyWith(
                color: isSelected ? SportPalette.blue : SportPalette.textMuted,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// ================== QUICK ACTIONS LOGIC ==================
  void _onQuickAction(String key) async {
    if (key == "Бронь") {
      final userId = await PrefUtils.getUserId();
      if (userId == null) return;
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => BookingScreen(userId: userId)));
    } else if (key == "Тренировки") {
      _showTrainingMenu(context);
    } else if (key == "Видео") {
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => ReelsScreen()));
    } else if (key == "Расписание") {
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(builder: (_) => ScheduleScreen(sport: selectedSport ?? 'Футбол')));
    } else {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => GenericServiceScreen(title: key, sport: selectedSport ?? 'Футбол')),
      );
    }
  }

  /// ================== REELS SECTION ==================
  Widget _buildReelsSection() {
    return Section(
      icon: Icons.play_circle_outline_rounded,
      title: "Ролики",
      subtitle: "Популярное видео",
      onSeeAll: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReelsScreen())),
      child: SizedBox(
        height: 260,
        child: FutureBuilder<List<dynamic>>(
          future: _reelsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  color: SportPalette.blue,
                ),
              );
            }
            if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(
                child: Text(
                  "Не удалось загрузить Ролики",
                  style: AppText.caption.copyWith(color: SportPalette.textMuted),
                ),
              );
            }
            final all = snapshot.data!;
            final reels = all.length > 12 ? all.sublist(0, 12) : all;
            return ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: kPageHPad),
              physics: const BouncingScrollPhysics(),
              itemCount: reels.length,
              itemBuilder: (context, index) {
                final reel = reels[index] as Map<String, dynamic>;
                return Padding(
                  padding: EdgeInsets.only(right: index == reels.length - 1 ? 0 : 12),
                  child: SizedBox(width: 180, child: _buildReelCard(reel)),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildReelCard(Map<String, dynamic> reel) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => ReelsScreen()));
      },
      child: Container(
        width: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.08),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Preview image
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      (reel['thumbnail'] ?? 'https://via.placeholder.com/180x320').toString(),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: SportPalette.slateBg,
                        child: const Icon(Icons.videocam_rounded, size: 40, color: SportPalette.textLight),
                      ),
                    ),
                    // Gradient overlay
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.85),
                          ],
                          stops: const [0.5, 1.0],
                        ),
                      ),
                    ),
                    // Content overlay
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 12,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (reel['description'] ?? '').toString(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.cardTitle.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildStatItem(
                                Icons.favorite_rounded,
                                _formatCount((reel['likes'] ?? '0').toString()),
                              ),
                              _buildStatItem(
                                Icons.play_arrow_rounded,
                                _formatCount((reel['views'] ?? '0').toString()),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Center(
                      child: Icon(
                        Icons.play_circle_fill_rounded,
                        size: 48,
                        color: Color.fromRGBO(255, 255, 255, 0.9),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Author info
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: SportPalette.blue.withOpacity(0.1),
                    backgroundImage: (reel['user_avatar'] != null && reel['user_avatar'].toString().isNotEmpty)
                        ? NetworkImage(reel['user_avatar'])
                        : null,
                    child: (reel['user_avatar'] == null || reel['user_avatar'].toString().isEmpty)
                        ? const Icon(Icons.person_rounded, size: 16, color: SportPalette.blue)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      (reel['username'] ?? 'Автор').toString(),
                      style: AppText.caption.copyWith(
                        color: SportPalette.text,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
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

  Widget _buildStatItem(IconData icon, String count) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.white.withOpacity(0.9)),
        const SizedBox(width: 4),
        Text(
          count,
          style: AppText.captionSmall.copyWith(
            color: Colors.white.withOpacity(0.9),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _formatCount(String count) {
    final numVal = int.tryParse(count) ?? 0;
    if (numVal >= 1000000) return '${(numVal / 1000000).toStringAsFixed(1)}M';
    if (numVal >= 1000) return '${(numVal / 1000).toStringAsFixed(1)}K';
    return count;
  }

  /// ================== EVENTS ==================
  Widget _buildEventsSection_v2() {
    final sport = selectedSport ?? 'Футбол';
    final events = _eventsCache[sport] ?? [];
    return Section(
      icon: Icons.event_rounded,
      title: "Мероприятия",
      subtitle: "Предстоящие события",
      onSeeAll: events.isNotEmpty ? _openScheduleAll : null,
      child: SizedBox(
        height: kCardHeight,
        child: events.isEmpty
            ? const Center(
                child: CircularProgressIndicator(color: SportPalette.blue),
              )
            : RefreshIndicator(
                onRefresh: () => _loadEvents(sport),
                color: SportPalette.blue,
                child: CardScroller(
                  itemCount: events.length,
                  itemBuilder: (_, i) => _buildEventCard(events[i]),
                ),
              ),
      ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => EventDetailScreen(event: event),
            transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
          ),
        );
      },
      child: _imageCard(
        imageUrl: (event['image'] ?? '').toString(),
        title: (event['title'] ?? '').toString(),
        subtitle: "${event['event_date'] ?? ''} • ${event['location'] ?? 'Локация не указана'}",
      ),
    );
  }

  /// ================== VENUES ==================
  Widget _buildVenuesSection_v2() {
    final venues = (dataCache['venues'] ?? []) as List;
    return Section(
      icon: Icons.location_on_rounded,
      title: "Площадки",
      subtitle: "Спортивные объекты",
      onSeeAll: venues.isNotEmpty ? _openVenuesAll : null,
      child: SizedBox(
        height: kCardHeight,
        child: venues.isEmpty
            ? const Center(
                child: CircularProgressIndicator(color: SportPalette.blue),
              )
            : CardScroller(
                itemCount: venues.length,
                itemBuilder: (_, i) => _venueCard(venues[i] as Map<String, dynamic>),
              ),
      ),
    );
  }

  Widget _venueCard(Map<String, dynamic> venue) {
    return GestureDetector(
      onTap: () async {
        final userId = await PrefUtils.getUserId();
        if (userId == null) return;
        if (!mounted) return;
        Navigator.push(
          context,
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => VenueBookingScreen(
              venueId: int.parse(venue['id'].toString()),
              venueTitle: (venue['title'] ?? '').toString(),
              userId: userId,
            ),
            transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
          ),
        );
      },
      child: _imageCard(
        imageUrl: (venue['image'] ?? '').toString(),
        title: (venue['title'] ?? '').toString(),
        subtitle: (venue['address'] ?? '').toString(),
      ),
    );
  }

  /// ================== CATALOG ==================
  Widget _buildCatalogSection() {
    final items = (dataCache['catalog_preview'] as List<Map<String, dynamic>>?) ?? _catalogPreview;
    return Section(
      icon: Icons.apps_rounded,
      title: "Каталог",
      subtitle: "Школы и секции",
      onSeeAll: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SchoolsCatalogScreen()),
      ),
      child: CardScroller(
        cardWidth: 260,
        itemCount: items.length,
        itemBuilder: (_, i) {
          final s = items[i];
          final name = (s['name'] ?? 'Школа').toString();
          final city = (s['city'] ?? '').toString();
          return _innovMatteTile(
            start: const Color(0xFF10B981),
            end: const Color(0xFF0EA5E9),
            title: name,
            subtitle: city.isNotEmpty ? city : (s['region'] ?? '').toString(),
            ctaText: 'Открыть',
            leadingImage: (s['logo'] ?? '').toString(),
            leadingFallbackIcon: Icons.school_rounded,
            onTap: () {
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (_, __, ___) => SchoolDetailScreen(
                    schoolId: int.tryParse('${s['id']}') ?? 0,
                    name: name,
                  ),
                  transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// ================== CLUBS ==================
  Widget _buildClubsSectionLikeInnovations() {
    final teams = (dataCache['teams'] ?? []) as List<Map<String, dynamic>>;
    return Section(
      icon: Icons.groups_rounded,
      title: "Клубы",
      subtitle: "Спортивные команды",
      onSeeAll: teams.isNotEmpty ? _openClubsAll : null,
      child: CardScroller(
        cardWidth: 260,
        itemCount: teams.length,
        itemBuilder: (_, i) {
          final t = teams[i];
          final name = (t['name'] ?? 'Клуб').toString();
          final cityOrSport = (t['sport'] ?? selectedSport ?? '').toString();
          return _innovMatteTile(
            start: const Color(0xFF1EC6DF),
            end: const Color(0xFF5B76F7),
            title: name,
            subtitle: cityOrSport,
            ctaText: 'Открыть',
            leadingImage: (t['logo'] ?? '').toString(),
            leadingFallbackIcon: Icons.shield_rounded,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TeamDetailScreen(
                    teamId: int.parse(t['id'].toString()),
                    teamName: name,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// ================== SCHOOLS ==================
  Widget _buildSchoolsSectionLikeInnovations() {
    final schools = (dataCache['schools'] ?? []) as List<Map<String, dynamic>>;
    return Section(
      icon: Icons.school_rounded,
      title: "Школы",
      subtitle: "Спортивные учреждения",
      onSeeAll: schools.isNotEmpty
          ? () {
              if (!mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SchoolListScreen(
                    initialSport: selectedSport ?? 'Футбол',
                  ),
                ),
              );
            }
          : null,
      child: CardScroller(
        cardWidth: 260,
        itemCount: schools.length,
        itemBuilder: (_, i) {
          final s = schools[i];
          final name = (s['name'] ?? 'Школа').toString();
          final city = (s['city'] ?? (selectedSport ?? 'Спорт')).toString();
          return _innovMatteTile(
            start: const Color(0xFFF4CE5E),
            end: const Color(0xFFE5B84A),
            title: name,
            subtitle: city,
            ctaText: 'Открыть',
            leadingImage: (s['logo'] ?? '').toString(),
            leadingFallbackIcon: Icons.school_rounded,
            onTap: () {
              Navigator.push(
                context,
                PageRouteBuilder(
                  pageBuilder: (_, __, ___) => SchoolDetailScreen(
                    schoolId: int.parse(s['id'].toString()),
                    name: name,
                  ),
                  transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// ================== TICKETS ==================
  Widget _buildTicketsSectionLikeInnovations() {
    return Section(
      icon: Icons.confirmation_number_rounded,
      title: "Билеты",
      subtitle: "РФ / РБ, 2025",
      onSeeAll: _ticketsData.isNotEmpty
          ? () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TicketsSection(
                    selectedClub: selectedClub,
                    tickets: _ticketsData,
                  ),
                ),
              );
            }
          : null,
      child: CardScroller(
        cardWidth: 260,
        itemCount: _ticketsData.length,
        itemBuilder: (_, i) {
          final t = _ticketsData[i];
          final title = (t['teams'] ?? 'Матч').toString();
          final date = (t['date'] ?? '').toString();
          final venue = (t['venue'] ?? '').toString();
          final price = (t['price'] ?? '').toString();
          final subtitle = [
            if (date.isNotEmpty) date,
            if (venue.isNotEmpty) venue,
            if (price.isNotEmpty) price,
          ].join(' • ');
          return _innovMatteTile(
            start: const Color(0xFF3A7BD5),
            end: const Color(0xFF3A6073),
            title: title,
            subtitle: subtitle,
            ctaText: 'Купить',
            leadingImage: '',
            leadingFallbackIcon: Icons.confirmation_number_rounded,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TicketsSection(
                    selectedClub: selectedClub,
                    tickets: _ticketsData,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// ================== USER POSTS ==================
  Widget _buildUserPostsSection() {
    final sport = selectedSport ?? 'Футбол';
    final posts = _userPostsCache[sport] ?? const [];
    return Section(
      icon: Icons.article_rounded,
      title: "Новости сообщества",
      subtitle: "Последние обновления",
      onSeeAll: posts.isNotEmpty
          ? () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SportCommunityScreen(sportName: sport),
                ),
              );
            }
          : null,
      child: SizedBox(
        height: kCardHeight,
        child: posts.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.article_outlined,
                      size: 40,
                      color: SportPalette.textLight,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Пока нет новостей',
                      style: AppText.caption.copyWith(color: SportPalette.textMuted),
                    ),
                  ],
                ),
              )
            : CardScroller(
                cardWidth: 260,
                itemCount: posts.length,
                itemBuilder: (_, i) => _userPostCard(posts[i]),
              ),
      ),
    );
  }

  Widget _userPostCard(Map<String, dynamic> post) {
    final text = (post['text'] ?? '').toString();
    final author = (post['authorName'] ?? 'Пользователь').toString();
    final date = post['date'] as DateTime;
    
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NewsDetailScreen(
              title: selectedSport ?? 'Новости',
              body: text,
              newsId: post['id'] as int,
              imageUrl: (post['imageUrl'] ?? '').toString(),
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(kBigRadius),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image section
            if ((post['imageUrl'] ?? '').toString().isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(kBigRadius)),
                child: Container(
                  height: 120,
                  color: SportPalette.slateBg,
                  child: Image.network(
                    post['imageUrl'].toString(),
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                              : null,
                          color: SportPalette.blue,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => Center(
                      child: Icon(
                        Icons.article_rounded,
                        color: SportPalette.textLight,
                        size: 40,
                      ),
                    ),
                  ),
                ),
              ),
            // Content section
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text.isNotEmpty ? text : 'Интересная новость от сообщества',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                      color: SportPalette.text,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: SportPalette.blue.withOpacity(0.1),
                        child: Text(
                          author.isNotEmpty ? author[0].toUpperCase() : 'П',
                          style: AppText.captionSmall.copyWith(
                            color: SportPalette.blue,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '$author • ${_formatPostDateHome(date)}',
                          style: AppText.captionSmall.copyWith(
                            color: SportPalette.textMuted,
                          ),
                          overflow: TextOverflow.ellipsis,
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
    );
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

  /// ================== GENERIC CARDS ==================
  Widget _imageCard({required String imageUrl, required String title, required String subtitle}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(kBigRadius),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(kBigRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background image with gradient
            Container(
              width: double.infinity,
              height: kCardHeight,
              decoration: BoxDecoration(
                color: SportPalette.blueDeep,
                borderRadius: BorderRadius.circular(kBigRadius),
              ),
              child: imageUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(kBigRadius),
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: SportPalette.blueDeep,
                            child: Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white.withOpacity(0.5),
                                ),
                              ),
                            ),
                          );
                        },
                        errorBuilder: (_, __, ___) => Container(
                          color: SportPalette.blueDeep,
                          child: Center(
                            child: Icon(
                              Icons.image_rounded,
                              color: Colors.white.withOpacity(0.3),
                              size: 50,
                            ),
                          ),
                        ),
                      ),
                    )
                  : null,
            ),
            
            // Gradient overlay for text readability
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(kBigRadius),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.3),
                      Colors.black.withOpacity(0.7),
                    ],
                    stops: const [0.4, 0.7, 1.0],
                  ),
                ),
              ),
            ),
            
            // Content
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.cardTitle.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.cardSubtitle.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
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

  Widget _innovMatteTile({
    required Color start,
    required Color end,
    required String title,
    required String subtitle,
    required String ctaText,
    required String leadingImage,
    required IconData leadingFallbackIcon,
    VoidCallback? onTap,
  }) {
    final shadow = BoxShadow(
      color: end.withOpacity(0.22),
      blurRadius: 14,
      offset: const Offset(0, 6),
    );
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kBigRadius),
        child: Container(
          height: kCardHeight,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(kBigRadius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [start, end],
            ),
            boxShadow: [shadow],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.18),
                      border: Border.all(color: Colors.white.withOpacity(0.35)),
                    ),
                    child: ClipOval(
                      child: leadingImage.isNotEmpty
                          ? Image.network(
                              leadingImage,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(
                                leadingFallbackIcon,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              leadingFallbackIcon,
                              color: Colors.white,
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        height: 1.12,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              if (subtitle.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ),
              Row(
                children: [
                  Text(
                    ctaText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const Spacer(),
                  Container(
                    width: 68,
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.88),
                      borderRadius: BorderRadius.circular(99),
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

  /// ================== NAV HELPERS ==================
  void _showTrainingMenu(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const AddPersonalTrainingScreen(),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
      ),
    );
  }
}

/// ================== SECTION WIDGET ==================
class Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onSeeAll;
  final Widget child;
  final EdgeInsetsGeometry padding;
  
  const Section({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.child,
    this.onSeeAll,
    this.padding = const EdgeInsets.symmetric(horizontal: kPageHPad),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: kSectionGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: SportPalette.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        icon,
                        color: SportPalette.blue,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: AppText.h3.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (subtitle != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              subtitle!,
                              style: AppText.captionSmall.copyWith(
                                color: SportPalette.textMuted,
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
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: SportPalette.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Text(
                                "Все",
                                style: AppText.captionSmall.copyWith(
                                  color: SportPalette.blue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 16,
                                color: SportPalette.blue,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// ================== CARD SCROLLER ==================
class CardScroller extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final double cardWidth;
  
  const CardScroller({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.cardWidth = 250,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: kCardHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: kPageHPad),
        itemCount: itemCount,
        itemBuilder: (ctx, i) => Padding(
          padding: EdgeInsets.only(right: i == itemCount - 1 ? 0 : 12),
          child: SizedBox(width: cardWidth, child: itemBuilder(ctx, i)),
        ),
      ),
    );
  }
}

/// ================== HEADER UI COMPONENTS ==================
class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  
  const _GlassIconButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(.35)),
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 20),
        onPressed: onPressed,
        padding: const EdgeInsets.all(8),
      ),
    );
  }
}

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
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.18),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(.28)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.search_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    "Поиск",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          height: 44,
          width: 200,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _headerActions.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final a = _headerActions[i];
              final color = categoryColors[a.keyName] ?? SportPalette.sky;
              return _MagnetIcon(
                size: 44,
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
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: .9,
      ),
      itemBuilder: (ctx, i) {
        final item = _headerActions[i];
        final color = categoryColors[item.keyName] ?? SportPalette.sky;
        return Column(
          children: [
            _MagnetIcon(
              size: 52,
              color: color,
              icon: item.icon,
              onTap: () => onTap(item.keyName),
            ),
            const SizedBox(height: 6),
            Opacity(
              opacity: labelOpacity,
              child: Text(
                item.titleRu,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 10,
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
                blurRadius: _down ? 10 : 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: widget.size - 8,
              height: widget.size - 8,
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