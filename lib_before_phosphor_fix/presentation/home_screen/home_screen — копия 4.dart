import 'dart:convert';
import 'dart:math';
import 'dart:ui' show lerpDouble;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:pool/pool.dart';
import 'package:sportoteka/core/constants/app_colors.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/data/models/video_folder_model.dart';
import 'package:sportoteka/data/services/video_lessons_service.dart';
import 'package:sportoteka/presentation/booking_screen/booking_screen.dart';
import 'package:sportoteka/presentation/booking_screen/venue_booking_screen.dart';
import 'package:sportoteka/presentation/catalog/events_list_screen.dart';
import 'package:sportoteka/presentation/catalog/team_list_screen.dart';
import 'package:sportoteka/presentation/community_screen/app_video_player_screen.dart';
import 'package:sportoteka/presentation/community_screen/in_app_web_video_screen.dart';
import 'package:sportoteka/presentation/community_screen/news_detail_screen.dart';
import 'package:sportoteka/presentation/community_screen/post_blocks.dart';
import 'package:sportoteka/presentation/community_screen/sport_community_screen.dart';
import 'package:sportoteka/presentation/global_search_screen/global_search_screen.dart';
import 'package:sportoteka/presentation/help/help_section.dart';
import 'package:sportoteka/presentation/home_screen/home_customizer_screen.dart';
import 'package:sportoteka/presentation/home_screen/home_screen_design.dart';
import 'package:sportoteka/presentation/innovation/innovations_section.dart';
import 'package:sportoteka/presentation/reels_screen/reels_screen.dart';
import 'package:sportoteka/presentation/service_screens/calendar_event_screen.dart';
import 'package:sportoteka/presentation/service_screens/event_detail_screen.dart';
import 'package:sportoteka/presentation/service_screens/generic_service_screen.dart';
import 'package:sportoteka/presentation/service_screens/ring_usage_screen.dart';
import 'package:sportoteka/presentation/subscription/subscription_screen.dart';
import 'package:sportoteka/presentation/team_screen/team_detail_screen.dart';
import 'package:sportoteka/presentation/tickets/tickets_section.dart';
import 'package:sportoteka/presentation/tracking/tracking_mode_screen.dart';
import 'package:sportoteka/presentation/venue/venues_catalog_screen.dart';
import 'package:sportoteka/presentation/video_lessons/video_lesson_folder_screen.dart';
import 'package:sportoteka/presentation/video_lessons/video_lessons_hub_screen.dart';
import 'package:sportoteka/update_checker.dart';

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

/// ================== ПАЛИТРА ==================
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
}

/// ================== СПОРТЫ ==================
const List<String> _sports = [
  'Футбол',
];

/// ================== БЫСТРЫЕ ДЕЙСТВИЯ ==================
const List<_HeaderActionItem> _headerActions = [
  _HeaderActionItem(
    keyName: 'Видеоуроки',
    titleRu: 'Видеоуроки',
    subtitleRu: 'Папки и уроки от авторов',
    icon: Icons.ondemand_video_rounded,
  ),
  _HeaderActionItem(
    keyName: 'Бронь',
    titleRu: 'Площадки',
    subtitleRu: 'Быстрое бронирование',
    icon: Icons.event_available_rounded,
  ),
  _HeaderActionItem(
    keyName: 'Расписание',
    titleRu: 'Календарь',
    subtitleRu: 'События и расписание',
    icon: Icons.calendar_today_rounded,
  ),
  _HeaderActionItem(
    keyName: 'Видео',
    titleRu: 'Reels',
    subtitleRu: 'Популярные ролики сообщества',
    icon: Icons.play_circle_fill_rounded,
  ),
  _HeaderActionItem(
    keyName: 'Tracking',
    titleRu: 'Трекинг',
    subtitleRu: 'Датчики и live-сессии',
    icon: Icons.monitor_heart_rounded,
  ),
];

class _HeaderActionItem {
  final String keyName;
  final String titleRu;
  final String subtitleRu;
  final IconData icon;

  const _HeaderActionItem({
    required this.keyName,
    required this.titleRu,
    required this.subtitleRu,
    required this.icon,
  });
}

/// ================== HOME SCREEN ==================
class HomeScreen extends StatefulWidget {
  final void Function(String)? onSportChanged;

  const HomeScreen({super.key, this.onSportChanged});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

/// ================== HELPERS ==================
bool _looksLikeHtml(String s) {
  final t = s.trim().toLowerCase();
  return t.contains('<p') ||
      t.contains('<br') ||
      t.contains('</') ||
      t.contains('<div') ||
      t.contains('<span') ||
      t.contains('<video') ||
      t.contains('<a ') ||
      t.contains('<img');
}

bool _looksLikeDirectVideoUrl(String url) {
  final clean = url.toLowerCase().split('?').first.split('#').first;
  return clean.endsWith('.mp4') ||
      clean.endsWith('.mov') ||
      clean.endsWith('.m4v') ||
      clean.endsWith('.webm') ||
      clean.endsWith('.m3u8');
}

bool _looksLikeExternalVideoPage(String url) {
  final u = url.toLowerCase();
  return u.contains('youtube.com/') ||
      u.contains('youtu.be/') ||
      u.contains('vimeo.com/') ||
      u.contains('rutube.ru/') ||
      u.contains('vkvideo.ru/') ||
      u.contains('vk.com/video') ||
      u.contains('dailymotion.com/') ||
      u.contains('tiktok.com/') ||
      u.contains('drive.google.com/') ||
      u.contains('dropbox.com/');
}

String? _tryBuildAutoThumbnail(String url) {
  try {
    final uri = Uri.parse(url);

    if (uri.host.contains('youtu.be')) {
      if (uri.pathSegments.isNotEmpty) {
        final id = uri.pathSegments.first.trim();
        if (id.isNotEmpty) {
          return 'https://img.youtube.com/vi/$id/hqdefault.jpg';
        }
      }
    }

    if (uri.host.contains('youtube.com')) {
      final v = uri.queryParameters['v'];
      if (v != null && v.trim().isNotEmpty) {
        return 'https://img.youtube.com/vi/${v.trim()}/hqdefault.jpg';
      }

      final segments = uri.pathSegments;

      final shortsIndex = segments.indexOf('shorts');
      if (shortsIndex != -1 && shortsIndex + 1 < segments.length) {
        final id = segments[shortsIndex + 1].trim();
        if (id.isNotEmpty) {
          return 'https://img.youtube.com/vi/$id/hqdefault.jpg';
        }
      }

      final embedIndex = segments.indexOf('embed');
      if (embedIndex != -1 && embedIndex + 1 < segments.length) {
        final id = segments[embedIndex + 1].trim();
        if (id.isNotEmpty) {
          return 'https://img.youtube.com/vi/$id/hqdefault.jpg';
        }
      }
    }
  } catch (_) {}

  return null;
}

Map<String, dynamic> _extractPostPreviewFromBody(String rawBody) {
  final html = _looksLikeHtml(rawBody)
      ? rawBody
      : '<p>${const HtmlEscape().convert(rawBody)}</p>';

  final blocks = PostHtmlParser.htmlToBlocks(html);

  String previewImage = '';
  String videoUrl = '';
  bool hasVideo = false;

  for (final b in blocks) {
    if (b is VideoBlock) {
      hasVideo = true;
      videoUrl = _normalizeMediaUrl(b.url);

      if (b.thumbnail.trim().isNotEmpty) {
        previewImage = _normalizeMediaUrl(b.thumbnail);
        break;
      }

      final autoThumb = _tryBuildAutoThumbnail(b.url);
      if ((autoThumb ?? '').isNotEmpty) {
        previewImage = autoThumb!;
        break;
      }
    }

    if (b is ImageBlock && previewImage.isEmpty) {
      previewImage = _normalizeMediaUrl(b.url);
    }
  }

  return {
    'hasVideo': hasVideo,
    'videoUrl': videoUrl,
    'previewImage': previewImage,
  };
}

class _HomeScreenState extends State<HomeScreen> {
  HomeScreenDesign _homeDesign = HomeScreenDesign.defaults();
  int? _userId;
  bool _designLoaded = false;

  bool isLoading = true;
  bool hasError = false;
  String? errorMessage;

  String? selectedSport = 'Футбол';

  List<Map<String, dynamic>> _catalogPreview = [];
  List<Map<String, dynamic>> _ticketsData = [];
  List<Map<String, dynamic>> _reelsData = [];
  List<Map<String, dynamic>> _recommendedVideoFolders = [];

  final Map<String, dynamic> dataCache = {};
  final Map<String, DateTime> cacheTimestamps = {};
  final Map<String, List<Map<String, dynamic>>> _eventsCache = {};
  final Map<String, DateTime> _eventsCacheTimestamps = {};
  final Map<String, List<Map<String, dynamic>>> _userPostsCache = {};
  final Map<String, DateTime> _userPostsTimestamps = {};

  late final PageController _quickActionsController;
  int _quickActionPage = 0;

  @override
  void initState() {
    super.initState();
    _quickActionsController = PageController(viewportFraction: 0.90);
    _quickActionsController.addListener(() {
      final value = _quickActionsController.page?.round() ?? 0;
      if (value != _quickActionPage && mounted) {
        setState(() => _quickActionPage = value);
      }
    });
    _initAll();
  }

  @override
  void dispose() {
    _quickActionsController.dispose();
    super.dispose();
  }

  Color _parseVideoFolderColor(String hex) {
    try {
      final value = hex.replaceAll('#', '');
      return Color(int.parse('FF$value', radix: 16));
    } catch (_) {
      return _homeDesign.primaryColor;
    }
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
          _homeDesign = _normalizeHomeDesign(HomeScreenDesign.defaults());
          _designLoaded = true;
        });
        return;
      }

      final raw = await PrefUtils.getString('home_design_user_$userId');

      if (raw == null || raw.trim().isEmpty) {
        if (!mounted) return;
        setState(() {
          _homeDesign = _normalizeHomeDesign(HomeScreenDesign.defaults());
          _designLoaded = true;
        });
        return;
      }

      try {
        final parsed = _normalizeHomeDesign(HomeScreenDesign.decode(raw));

        if (!mounted) return;
        setState(() {
          _homeDesign = parsed;
          _designLoaded = true;
        });
      } catch (e) {
        debugPrint('Ошибка decode home design: $e');

        final safeDefaults = _normalizeHomeDesign(HomeScreenDesign.defaults());

        await PrefUtils.setString(
          'home_design_user_$userId',
          safeDefaults.encode(),
        );

        if (!mounted) return;
        setState(() {
          _homeDesign = safeDefaults;
          _designLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('Ошибка загрузки дизайна главной: $e');

      if (!mounted) return;
      setState(() {
        _homeDesign = _normalizeHomeDesign(HomeScreenDesign.defaults());
        _designLoaded = true;
      });
    }
  }

  HomeScreenDesign _normalizeHomeDesign(HomeScreenDesign design) {
    double safeDouble(double value, double fallback) {
      if (value.isNaN || value.isInfinite) return fallback;
      return value;
    }

    HomeSectionConfig normalizeSection(HomeSectionConfig config) {
      double minHeight;
      double minWidth;

      switch (config.type) {
        case HomeSectionType.ringBanner:
          minHeight = 180;
          minWidth = 300;
          break;
        case HomeSectionType.reels:
          minHeight = 320;
          minWidth = 210;
          break;
        case HomeSectionType.promo:
          minHeight = 170;
          minWidth = 300;
          break;
        case HomeSectionType.innovations:
          minHeight = 180;
          minWidth = 220;
          break;
        case HomeSectionType.tips:
          minHeight = 190;
          minWidth = 220;
          break;
        case HomeSectionType.events:
          minHeight = 240;
          minWidth = 230;
          break;
        case HomeSectionType.venues:
          minHeight = 230;
          minWidth = 230;
          break;
        case HomeSectionType.clubs:
          minHeight = 230;
          minWidth = 230;
          break;
        case HomeSectionType.tickets:
          minHeight = 220;
          minWidth = 230;
          break;
        case HomeSectionType.posts:
          minHeight = 250;
          minWidth = 240;
          break;
      }

      final safeCardHeight = safeDouble(config.cardHeight, minHeight);
      final safeCardWidth = safeDouble(config.cardWidth, minWidth);
      final safeAspectRatio = safeDouble(config.aspectRatio, 1.0);
      final safeTopSpacing = safeDouble(config.topSpacing, 0);
      final safeBottomSpacing = safeDouble(config.bottomSpacing, 0);
      final safeInnerPadding = safeDouble(config.innerPadding, 0);

      return config.copyWith(
        cardHeight: safeCardHeight < minHeight ? minHeight : safeCardHeight,
        cardWidth: safeCardWidth < minWidth ? minWidth : safeCardWidth,
        itemLimit: config.itemLimit < 1 ? 1 : config.itemLimit,
        gridColumns: config.gridColumns < 1 ? 1 : config.gridColumns,
        aspectRatio: safeAspectRatio <= 0 ? 1.0 : safeAspectRatio,
        topSpacing: safeTopSpacing < 0 ? 0 : safeTopSpacing,
        bottomSpacing: safeBottomSpacing < 0 ? 0 : safeBottomSpacing,
        innerPadding: safeInnerPadding < 0 ? 0 : safeInnerPadding,
      );
    }

    return design.copyWith(
      headerTitleSize: safeDouble(design.headerTitleSize, 28),
      headerSubtitleSize: safeDouble(design.headerSubtitleSize, 14),
      sectionTitleSize: safeDouble(design.sectionTitleSize, 18),
      sectionSubtitleSize: safeDouble(design.sectionSubtitleSize, 13),
      cardTitleSize: safeDouble(design.cardTitleSize, 16),
      bodyTextSize: safeDouble(design.bodyTextSize, 14),
      smallTextSize: safeDouble(design.smallTextSize, 12),
      textScale: safeDouble(design.textScale, 1.0),
      cardRadius: safeDouble(design.cardRadius, 20),
      bannerRadius: safeDouble(design.bannerRadius, 24),
      borderWidth: safeDouble(design.borderWidth, 1),
      shadowOpacity: safeDouble(design.shadowOpacity, 0.08),
      shadowBlur: safeDouble(design.shadowBlur, 16),
      cardBackgroundOpacity: safeDouble(design.cardBackgroundOpacity, 1.0),
      cardBorderOpacity: safeDouble(design.cardBorderOpacity, 1.0),
      sectionGap: safeDouble(design.sectionGap, 16),
      pageHorizontalPadding: safeDouble(design.pageHorizontalPadding, 16),
      headerExpandedHeight: safeDouble(design.headerExpandedHeight, 220),
      headerCollapsedExtraHeight:
          safeDouble(design.headerCollapsedExtraHeight, 0),
      quickActionBubbleSize: safeDouble(design.quickActionBubbleSize, 54),
      quickActionIconSize: safeDouble(design.quickActionIconSize, 24),
      quickActionsCornerRadius:
          safeDouble(design.quickActionsCornerRadius, 20),
      quickActionBorderWidth:
          safeDouble(design.quickActionBorderWidth, 1),
      blurSigma: safeDouble(design.blurSigma, 14),
      glassOpacity: safeDouble(design.glassOpacity, 0.16),
      headerImageOpacity: safeDouble(design.headerImageOpacity, 0.20),
      headerOverlayOpacity: safeDouble(design.headerOverlayOpacity, 0.20),
      sections: design.sections.map(normalizeSection).toList(),
    );
  }

  Future<void> _saveHomeDesign() async {
    final userId = _userId ?? await PrefUtils.getUserId();
    if (userId == null) return;

    final normalized = _normalizeHomeDesign(_homeDesign);

    await PrefUtils.setString(
      'home_design_user_$userId',
      normalized.encode(),
    );
  }

  void _openHomeCustomizer() {
    final safeDesign = _normalizeHomeDesign(_homeDesign);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HomeCustomizerScreen(
          initialDesign: safeDesign,
          onSave: (design) async {
            if (!mounted) return;

            final normalized = _normalizeHomeDesign(design);

            setState(() {
              _homeDesign = normalized;
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
        _loadCachedData(
          'teams',
          () => _fetchTeamsBySport(selectedSport ?? 'Футбол'),
        ),
        _loadCachedData('catalog_preview', () async {
          final data = await _fetchCatalogPreview();
          _catalogPreview = data;
          return data;
        }),
        _loadUserPosts(selectedSport ?? 'Футбол'),
        _loadReels(),
        _loadRecommendedVideoFolders(),
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

  Future<List<Map<String, dynamic>>> _fetchWeeklyEvents(String sport) async {
    try {
      final response = await dio.get(
        'get_week_events.php',
        queryParameters: {'sport': sport},
      );
      return List<Map<String, dynamic>>.from(response.data);
    } on DioException catch (e) {
      throw Exception('Ошибка загрузки мероприятий: ${e.message}');
    }
  }

  Future<List<Map<String, dynamic>>> _fetchTeamsBySport(String sport) async {
    try {
      final response = await dio.get(
        'get_teams_by_sport.php',
        queryParameters: {'sport': sport},
      );
      if (response.data['status'] != 'success') {
        throw Exception(
          'Ошибка на сервере: ${response.data['message'] ?? 'неизвестная ошибка'}',
        );
      }
      return List<Map<String, dynamic>>.from(response.data['teams']);
    } on DioException catch (e) {
      throw Exception('Ошибка загрузки команд: ${e.message}');
    }
  }

  Future<List<Map<String, dynamic>>> _fetchVenues(String sport) async {
    try {
      final response = await dio.get(
        'get_venues.php',
        queryParameters: sport != 'Все' ? {'sport': sport} : null,
      );
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

      final List raw = data is List
          ? data
          : (data is Map
              ? (data['data'] ?? data['items'] ?? data['posts'] ?? []) as List? ??
                  []
              : []);

      final sportLc = sport.toLowerCase();

      final out = raw.where((e) {
        final m = Map<String, dynamic>.from(e as Map);
        final cat = (m['category'] ?? '').toString().toLowerCase();
        return cat == sportLc;
      }).map<Map<String, dynamic>>((e) {
        final m = Map<String, dynamic>.from(e as Map);

        final first = (m['first_name'] ?? '').toString();
        final last = (m['last_name'] ?? '').toString();
        final full = ('$first $last').trim().isEmpty
            ? 'Пользователь'
            : ('$first $last').trim();

        final rawBody = (m['body'] ?? '').toString();
        final plainText = _stripHtml(rawBody);

        final rawImg = (m['image'] ?? '').toString();
        final directImageUrl = _normalizeMediaUrl(rawImg);

        final preview = _extractPostPreviewFromBody(rawBody);
        final previewImage = (preview['previewImage'] ?? '').toString();
        final hasVideo = preview['hasVideo'] == true;
        final videoUrl = (preview['videoUrl'] ?? '').toString();

        final avatarRaw = (m['photo_url'] ??
                m['photo'] ??
                m['avatar_url'] ??
                m['avatar'] ??
                m['user_avatar'] ??
                m['user_photo'] ??
                '')
            .toString();

        final avatarUrl = _normalizeMediaUrl(avatarRaw);

        return {
          'id': int.tryParse('${m['id']}') ?? 0,
          'title': _stripHtml((m['title'] ?? '').toString()),
          'text': plainText,
          'imageUrl': directImageUrl.isNotEmpty ? directImageUrl : previewImage,
          'hasVideo': hasVideo,
          'videoUrl': videoUrl,
          'date': DateTime.tryParse((m['created_at'] ?? '').toString()) ??
              DateTime.now(),
          'authorAvatar': avatarUrl,
          'authorName': full,
          'user_id': int.tryParse('${m['user_id']}') ?? 0,
        };
      }).toList();

      out.sort(
        (a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime),
      );
      return out.take(8).toList();
    } on DioException catch (e) {
      throw Exception('Ошибка загрузки постов: ${e.message}');
    }
  }

  Future<List<Map<String, dynamic>>> _fetchCatalogPreview() async {
    try {
      final res = await dio.get(
        'get_schools.php',
        queryParameters: {
          'limit': 12,
          'offset': 0,
        },
      );
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
        raw = (data['reels'] ??
                data['data'] ??
                data['items'] ??
                data['list'] ??
                []) as List? ??
            [];
      } else if (data is List) {
        raw = data;
      } else {
        raw = const [];
      }

      final normalized = raw.map<Map<String, dynamic>>((e) {
        final m = Map<String, dynamic>.from(e as Map);

        final video =
            (m['video_url'] ?? m['video'] ?? m['url'] ?? m['src'] ?? '')
                .toString();
        final thumb =
            (m['thumbnail'] ?? m['thumb'] ?? m['poster'] ?? m['preview'] ?? '')
                .toString();

        return {
          'id': int.tryParse('${m['id'] ?? m['reel_id'] ?? 0}') ?? 0,
          'video_url': video,
          'thumbnail': thumb,
          'username':
              (m['username'] ?? m['user'] ?? m['author_name'] ?? '').toString(),
          'user_avatar': (m['user_avatar'] ?? m['avatar'] ?? '').toString(),
          'description':
              (m['description'] ?? m['title'] ?? m['caption'] ?? '').toString(),
          'likes': m['likes'] ?? m['like_count'] ?? 0,
          'views': m['views'] ?? m['view_count'] ?? 0,
          'comments': m['comments'] ?? m['comment_count'] ?? 0,
          'created_at': DateTime.tryParse(
                (m['created_at'] ?? m['date'] ?? m['published_at'] ?? '')
                    .toString(),
              ) ??
              DateTime.fromMillisecondsSinceEpoch(0),
        };
      }).where((e) => (e['video_url'] as String).isNotEmpty).toList();

      normalized.sort(
        (a, b) => (b['created_at'] as DateTime)
            .compareTo(a['created_at'] as DateTime),
      );

      if (mounted) {
        setState(() {
          _reelsData = normalized.take(6).toList();
        });
      }
    } catch (e) {
      debugPrint('Ошибка загрузки reels: $e');
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

  Future<void> _loadRecommendedVideoFolders() async {
    try {
      final response =
          await dio.get('video_lessons/get_video_lesson_authors.php');

      final data = response.data;
      final List rawAuthors =
          (data is Map && data['authors'] is List) ? data['authors'] as List : [];

      if (rawAuthors.isEmpty) {
        if (mounted) {
          setState(() {
            _recommendedVideoFolders = [];
          });
        }
        return;
      }

      final shuffledAuthors = [...rawAuthors]..shuffle(Random());

      final List<Map<String, dynamic>> collected = [];
      final Set<String> usedFolderKeys = {};

      for (final raw in shuffledAuthors) {
        if (collected.length >= 8) break;

        final author = Map<String, dynamic>.from(raw as Map);

        final int ownerUserId =
            int.tryParse('${author['id'] ?? author['user_id'] ?? 0}') ?? 0;

        if (ownerUserId <= 0) continue;

        final String authorName = (
          '${author['first_name'] ?? author['author_name'] ?? author['name'] ?? ''} '
          '${author['last_name'] ?? ''}'
        ).trim().isEmpty
            ? 'Автор'
            : (
                '${author['first_name'] ?? author['author_name'] ?? author['name'] ?? ''} '
                '${author['last_name'] ?? ''}'
              ).trim();

        final String authorAvatar =
            (author['avatar'] ?? author['photo'] ?? author['photo_url'] ?? '')
                .toString();

        try {
          final folders = await VideoLessonsService.getAllFoldersRecursive(
            ownerId: ownerUserId,
          );

          final foldersWithLessons =
              folders.where((f) => f.lessonsCount > 0).toList()
                ..shuffle(Random());

          for (final folder in foldersWithLessons) {
            if (collected.length >= 8) break;

            final uniqueKey = '${ownerUserId}_${folder.id}';
            if (usedFolderKeys.contains(uniqueKey)) continue;

            try {
              final lessons = await VideoLessonsService.getLessons(
                folderId: folder.id,
              );

              if (lessons.isEmpty) continue;

              String thumbnail = '';
              for (final lesson in lessons) {
                if (lesson.thumbnail.trim().isNotEmpty) {
                  thumbnail = lesson.thumbnail;
                  break;
                }
              }

              collected.add({
                'folder': folder,
                'ownerUserId': ownerUserId,
                'authorName': authorName,
                'authorAvatar': authorAvatar,
                'thumbnail': thumbnail,
                'lessonCount': lessons.length,
                'title': folder.title,
                'color': folder.color,
              });

              usedFolderKeys.add(uniqueKey);
            } catch (_) {}
          }
        } catch (_) {}
      }

      collected.shuffle(Random());

      if (mounted) {
        setState(() {
          _recommendedVideoFolders = collected.take(6).toList();
        });
      }
    } catch (e) {
      debugPrint('Ошибка загрузки рекомендуемых папок видеоуроков: $e');
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

  Future<void> _loadCachedData(
    String key,
    Future<dynamic> Function() fetchFunction,
  ) async {
    final now = DateTime.now();
    if (dataCache.containsKey(key) &&
        cacheTimestamps.containsKey(key) &&
        now.difference(cacheTimestamps[key]!) < cacheDuration) {
      return;
    }
    try {
      final data = await requestPool.withResource(
        () => _fetchWithRetry(fetchFunction),
      );
      if (!mounted) return;
      setState(() {
        dataCache[key] = data;
        cacheTimestamps[key] = DateTime.now();
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> _fetchWithRetry(
    Future<dynamic> Function() fetchFunction, {
    int maxRetries = 3,
  }) async {
    int attempt = 0;
    while (attempt < maxRetries) {
      try {
        return await fetchFunction();
      } on DioException catch (e) {
        attempt++;
        if (attempt == maxRetries) {
          throw Exception(
            'Не удалось загрузить данные после $maxRetries попыток: ${e.message}',
          );
        }
        await Future.delayed(Duration(seconds: attempt));
      }
    }
    throw Exception('Неизвестная ошибка при выполнении запроса');
  }

  void _openSearch() {
    if (!mounted) return;
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => GlobalSearchScreen(),
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
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

  Future<void> _handleSportChanged(String sport) async {
    if (sport == selectedSport) return;

    setState(() {
      selectedSport = sport;
      isLoading = true;
    });

    widget.onSportChanged?.call(sport);

    await Future.wait([
      _loadEvents(sport),
      _loadCachedData('teams', () => _fetchTeamsBySport(sport)),
      _loadUserPosts(sport),
    ]);

    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  void _onQuickAction(String key) async {
    if (key == 'Бронь') {
      final userId = await PrefUtils.getUserId();
      if (userId == null) return;
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BookingScreen(userId: userId),
        ),
      );
    } else if (key == 'Видео') {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const ReelsScreen(),
        ),
      );
    } else if (key == 'Видеоуроки') {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const VideoLessonsHubScreen(),
        ),
      );
    } else if (key == 'Расписание') {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ScheduleScreen(sport: selectedSport ?? 'Футбол'),
        ),
      );
    } else if (key == 'Tracking') {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const TrackingModeScreen(),
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
      case HomeSectionType.tips:
        return Icons.lightbulb_rounded;
    }
  }

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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(_homeDesign.smallRadius),
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
      backgroundColor: _homeDesign.backgroundColor,
      floatingActionButton: FloatingActionButton(
        backgroundColor: _homeDesign.primaryColor,
        onPressed: _openHomeCustomizer,
        child: const Icon(Icons.tune_rounded, color: Colors.white),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: _homeDesign.primaryColor,
          onRefresh: _loadInitialData,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    _homeDesign.pageHorizontalPadding,
                    14,
                    _homeDesign.pageHorizontalPadding,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCompactHeroHeader(),
                      const SizedBox(height: 18),
                      _buildSwipeQuickActions(),
                      const SizedBox(height: 18),
                      _buildSpotlightBlock(),
                      const SizedBox(height: 18),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: _homeDesign.pageHorizontalPadding,
                  ),
                  child: isLoading
                      ? _buildLoadingPlaceholder()
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: _buildSectionsFromDesign(),
                        ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 48)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactHeroHeader() {
    final posts = _userPostsCache[selectedSport ?? 'Футбол'] ?? const [];
    final events = _eventsCache[selectedSport ?? 'Футбол'] ?? const [];
    final reels = _reelsData;
    final greetingTitle = _homeDesign.customHeaderTitle.trim().isEmpty
        ? 'Спортотека'
        : _homeDesign.customHeaderTitle;
    final greetingSubtitle = _homeDesign.customHeaderSubtitle.trim().isEmpty
        ? 'Ваш спортивный центр на каждый день'
        : _homeDesign.customHeaderSubtitle;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_homeDesign.bannerRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _homeDesign.headerStartColor,
            _homeDesign.headerMidColor,
            _homeDesign.headerEndColor,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_homeDesign.shadowOpacity + 0.06),
            blurRadius: _homeDesign.shadowBlur + 8,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        greetingTitle,
                        style: AppText.h1.copyWith(
                          fontSize: 24,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        greetingSubtitle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.90),
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.18),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.sports_soccer_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        selectedSport ?? 'Футбол',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _openSearch,
              child: Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius:
                      BorderRadius.circular(_homeDesign.smallRadius),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.20),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.search_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Поиск по клубам, площадкам, новостям',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.92),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _sports.map((sport) {
                final active = sport == selectedSport;
                return GestureDetector(
                  onTap: () => _handleSportChanged(sport),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: active
                          ? Colors.white
                          : Colors.white.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: active
                            ? Colors.white
                            : Colors.white.withOpacity(0.16),
                      ),
                    ),
                    child: Text(
                      sport,
                      style: TextStyle(
                        color: active
                            ? _homeDesign.primaryColor
                            : Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildHeroStatCard(
                    title: 'Новости',
                    value: '${posts.length}',
                    subtitle: 'свежих публикаций',
                    icon: Icons.forum_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildHeroStatCard(
                    title: 'События',
                    value: '${events.length}',
                    subtitle: 'на ближайшее время',
                    icon: Icons.event_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildHeroStatCard(
                    title: 'Видео',
                    value: '${reels.length}',
                    subtitle: 'роликов в подборке',
                    icon: Icons.play_circle_fill_rounded,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroStatCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withOpacity(0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(height: 12),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 20,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.95),
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.68),
              fontWeight: FontWeight.w600,
              fontSize: 10.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwipeQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Быстрые действия',
          style: TextStyle(
            fontSize: _homeDesign.sectionTitleSize,
            fontWeight: FontWeight.w900,
            color: _homeDesign.textColor,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Главные функции в новом формате карточек',
          style: TextStyle(
            color: _homeDesign.mutedTextColor,
            fontSize: _homeDesign.sectionSubtitleSize,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 168,
          child: PageView.builder(
            controller: _quickActionsController,
            physics: const BouncingScrollPhysics(),
            itemCount: _headerActions.length,
            itemBuilder: (context, index) {
              final item = _headerActions[index];
              return Padding(
                padding: const EdgeInsets.only(right: 10),
                child: _buildQuickActionWindow(item, index),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        _buildQuickActionsIndicator(),
      ],
    );
  }

  Widget _buildQuickActionWindow(_HeaderActionItem item, int index) {
    final color = [
      _homeDesign.primaryColor,
      _homeDesign.secondaryColor,
      const Color(0xFF2563EB),
      const Color(0xFF7C3AED),
      const Color(0xFF0F766E),
    ][index % 5];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(_homeDesign.cardRadius),
        onTap: () => _onQuickAction(item.keyName),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_homeDesign.cardRadius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color,
                color.withOpacity(0.78),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.22),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                right: -18,
                top: -10,
                child: Container(
                  width: 94,
                  height: 94,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.10),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Positioned(
                bottom: -24,
                left: -10,
                child: Container(
                  width: 86,
                  height: 86,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                child: Row(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.14),
                        ),
                      ),
                      child: Icon(
                        item.icon,
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
                            item.titleRu,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item.subtitleRu,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.88),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              height: 1.3,
                            ),
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              Text(
                                'Открыть',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.95),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ],
                          ),
                        ],
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

  Widget _buildQuickActionsIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_headerActions.length, (index) {
        final active = index == _quickActionPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active
                ? _homeDesign.primaryColor
                : _homeDesign.primaryColor.withOpacity(0.18),
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }

  Widget _buildSpotlightBlock() {
    final posts = _userPostsCache[selectedSport ?? 'Футбол'] ?? const [];
    final events = _eventsCache[selectedSport ?? 'Футбол'] ?? const [];
    final teams =
        (dataCache['teams'] ?? const []) as List<Map<String, dynamic>>;
    final reels = _reelsData;

    Map<String, dynamic>? spotlight;
    String type = 'none';

    if (posts.isNotEmpty) {
      spotlight = posts.first;
      type = 'post';
    } else if (events.isNotEmpty) {
      spotlight = events.first;
      type = 'event';
    } else if (reels.isNotEmpty) {
      spotlight = reels.first;
      type = 'reel';
    } else if (teams.isNotEmpty) {
      spotlight = teams.first;
      type = 'team';
    }

    if (spotlight == null) {
      return const SizedBox.shrink();
    }

    String title = '';
    String subtitle = '';
    String imageUrl = '';
    IconData icon = Icons.auto_awesome_rounded;
    Color accent = _homeDesign.primaryColor;

    if (type == 'post') {
      title = (spotlight['title'] ?? '').toString().trim().isNotEmpty
          ? (spotlight['title'] ?? '').toString()
          : 'Главная новость сообщества';
      subtitle = (spotlight['text'] ?? 'Открыть публикацию').toString();
      imageUrl = (spotlight['imageUrl'] ?? '').toString();
      icon = Icons.forum_rounded;
      accent = _homeDesign.primaryColor;
    } else if (type == 'event') {
      title = (spotlight['title'] ?? 'Ближайшее событие').toString();
      subtitle = (spotlight['location'] ?? 'Подробнее о событии').toString();
      imageUrl = (spotlight['image'] ?? '').toString();
      icon = Icons.event_rounded;
      accent = _homeDesign.secondaryColor;
    } else if (type == 'reel') {
      title = (spotlight['description'] ?? 'Популярное видео').toString();
      subtitle = (spotlight['username'] ?? 'Sportoteka').toString();
      imageUrl = (spotlight['thumbnail'] ?? '').toString();
      icon = Icons.play_circle_fill_rounded;
      accent = const Color(0xFF7C3AED);
    } else if (type == 'team') {
      title = (spotlight['name'] ?? 'Команда').toString();
      subtitle = (spotlight['sport'] ?? selectedSport ?? 'Спорт').toString();
      imageUrl = _teamLogoFromAnyKey(spotlight);
      icon = Icons.groups_rounded;
      accent = _teamAccentBySport(subtitle, _homeDesign.sections.first);
    }

    return GestureDetector(
      onTap: () => _openSpotlight(type, spotlight!),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_homeDesign.bannerRadius),
          color: _homeDesign.cardColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(_homeDesign.shadowOpacity),
              blurRadius: _homeDesign.shadowBlur,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(_homeDesign.bannerRadius),
              ),
              child: SizedBox(
                height: 190,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (imageUrl.isNotEmpty)
                      Image.network(
                        _normalizeMediaUrl(imageUrl),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: accent.withOpacity(0.10),
                          child: Icon(
                            icon,
                            color: accent,
                            size: 54,
                          ),
                        ),
                      )
                    else
                      Container(
                        color: accent.withOpacity(0.10),
                        child: Icon(
                          icon,
                          color: accent,
                          size: 54,
                        ),
                      ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.10),
                            Colors.black.withOpacity(0.22),
                            Colors.black.withOpacity(0.60),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      top: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.20),
                          ),
                        ),
                        child: Text(
                          type == 'post'
                              ? 'Сегодня в центре внимания'
                              : type == 'event'
                                  ? 'Ближайшее событие'
                                  : type == 'reel'
                                      ? 'Популярное видео'
                                      : 'Команда дня',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
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
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 22,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.90),
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: accent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Открыть подробнее',
                      style: TextStyle(
                        color: _homeDesign.textColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: _homeDesign.mutedTextColor,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openSpotlight(String type, Map<String, dynamic> spotlight) {
    if (type == 'post') {
      final title =
          (spotlight['title'] ?? '').toString().trim().isNotEmpty
              ? (spotlight['title'] ?? '').toString()
              : (selectedSport ?? 'Новости');

      final hasVideo = spotlight['hasVideo'] == true;
      final videoUrl = (spotlight['videoUrl'] ?? '').toString();
      final imageUrl = (spotlight['imageUrl'] ?? '').toString();
      final text = (spotlight['text'] ?? '').toString();

      if (hasVideo && videoUrl.isNotEmpty) {
        if (_looksLikeDirectVideoUrl(videoUrl)) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AppVideoPlayerScreen(
                title: title,
                videoUrl: videoUrl,
                thumbnailUrl: imageUrl,
              ),
            ),
          );
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => InAppWebVideoScreen(
                title: title,
                url: videoUrl,
              ),
            ),
          );
        }
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NewsDetailScreen(
            title: title,
            body: text,
            newsId: (spotlight['id'] as int?) ?? 0,
            imageUrl: imageUrl,
          ),
        ),
      );
      return;
    }

    if (type == 'event') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EventDetailScreen(event: spotlight),
        ),
      );
      return;
    }

    if (type == 'reel') {
      final reelId = spotlight['id'] is int
          ? spotlight['id'] as int
          : int.tryParse('${spotlight['id']}');

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReelsScreen(
            initialReelId: reelId,
            initialIndex: 0,
          ),
        ),
      );
      return;
    }

    if (type == 'team') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TeamDetailScreen(
            teamId: int.tryParse('${spotlight['id']}') ?? 0,
            teamName: (spotlight['name'] ?? 'Команда').toString(),
          ),
        ),
      );
    }
  }
  
    List<Widget> _buildSectionsFromDesign() {
    final sections = <Widget>[];

    final posts = _userPostsCache[selectedSport ?? 'Футбол'] ?? [];
    final events = _eventsCache[selectedSport ?? 'Футбол'] ?? [];
    final venues = dataCache['venues'] ?? [];
    final teams = dataCache['teams'] ?? [];

    sections.add(_buildQuickAccessGrid());
    sections.add(SizedBox(height: _homeDesign.sectionGap));

    if (posts.isNotEmpty) {
      final config = _homeDesign.sections.firstWhere(
        (e) => e.type == HomeSectionType.posts,
        orElse: () => _homeDesign.sections.first,
      );
      sections.add(_buildCommunityNewsMixedSection(config, posts));
      sections.add(SizedBox(height: _homeDesign.sectionGap));
    }

    if (_reelsData.isNotEmpty) {
      final config = _homeDesign.sections.firstWhere(
        (e) => e.type == HomeSectionType.reels,
        orElse: () => _homeDesign.sections.first,
      );
      sections.add(_buildVideoSection(config));
      sections.add(SizedBox(height: _homeDesign.sectionGap));
    }

    if (_recommendedVideoFolders.isNotEmpty) {
      sections.add(_buildRecommendedVideoFoldersSection());
      sections.add(SizedBox(height: _homeDesign.sectionGap));
    }

    for (final config in _homeDesign.sections.where((s) => s.visible)) {
      Widget? builtSection;

      switch (config.type) {
        case HomeSectionType.ringBanner:
          builtSection = _buildRingBannerSection(config);
          break;
        case HomeSectionType.reels:
          builtSection = null;
          break;
        case HomeSectionType.promo:
          if (_homeDesign.showPromoBanner) {
            builtSection = _buildPromoSection(config);
          }
          break;
        case HomeSectionType.innovations:
          builtSection = _buildInnovationsSection(config);
          break;
        case HomeSectionType.events:
          if (events.isNotEmpty) {
            builtSection = _buildEventsSection(config, events);
          }
          break;
        case HomeSectionType.venues:
          if (venues.isNotEmpty) {
            builtSection = _buildVenuesSection(config, venues);
          }
          break;
        case HomeSectionType.clubs:
          if (teams.isNotEmpty) {
            builtSection = _buildClubsSection(
              config,
              List<Map<String, dynamic>>.from(teams),
            );
          }
          break;
        case HomeSectionType.tickets:
          builtSection = _buildTicketsSection(config, _ticketsData);
          break;
        case HomeSectionType.posts:
          builtSection = null;
          break;
        case HomeSectionType.tips:
          builtSection = _buildTipsSection(config);
          break;
      }

      if (builtSection != null) {
        sections.add(SizedBox(height: config.topSpacing));
        sections.add(
          Padding(
            padding: EdgeInsets.symmetric(horizontal: config.innerPadding),
            child: builtSection,
          ),
        );
        sections.add(SizedBox(height: config.bottomSpacing));
        sections.add(SizedBox(height: _homeDesign.sectionGap));
      }
    }

    if (sections.isNotEmpty) {
      sections.removeLast();
    }

    return sections;
  }

  Widget _buildSectionHeaderFromDesign({
    required HomeSectionConfig config,
    required String title,
    required String subtitle,
    required VoidCallback? onSeeAll,
  }) {
    final accentColor = config.accentOverride ?? _homeDesign.primaryColor;

    final effectiveTitle =
        config.customTitle?.trim().isNotEmpty == true ? config.customTitle! : title;

    final effectiveSubtitle = config.customSubtitle?.trim().isNotEmpty == true
        ? config.customSubtitle!
        : subtitle;

    final canShowSeeAll = config.showSeeAll && onSeeAll != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (config.showDividerAbove)
          Divider(
            color: _homeDesign.borderColor,
            height: 20,
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          effectiveTitle,
                          style: TextStyle(
                            fontSize: _homeDesign.sectionTitleSize,
                            fontWeight: FontWeight.w800,
                            height: 1.2,
                            letterSpacing: -0.3,
                            color: _homeDesign.textColor,
                          ),
                        ),
                      ),
                      if (config.showBadge &&
                          (config.badgeText?.trim().isNotEmpty ?? false)) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: (config.badgeColor ?? accentColor)
                                .withOpacity(0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            config.badgeText!,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: config.badgeColor ?? accentColor,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (config.showSubtitle) ...[
                    const SizedBox(height: 2),
                    Text(
                      effectiveSubtitle,
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
            if (canShowSeeAll)
              GestureDetector(
                onTap: onSeeAll,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.1),
                    borderRadius:
                        BorderRadius.circular(_homeDesign.smallRadius),
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
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: accentColor,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        if (config.showDividerBelow)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Divider(
              color: _homeDesign.borderColor,
              height: 1,
            ),
          ),
      ],
    );
  }

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

    late BoxDecoration decoration;

    switch (cardStyle) {
      case HomeCardStyle.glass:
        decoration = BoxDecoration(
          color: _homeDesign.cardColor.withOpacity(_homeDesign.glassOpacity),
          borderRadius: BorderRadius.circular(_homeDesign.cardRadius),
          border: Border.all(
            color: _homeDesign.borderColor,
            width: _homeDesign.borderWidth,
          ),
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
          border: Border.all(
            color: accent,
            width: _homeDesign.borderWidth,
          ),
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
          border: Border.all(
            color: _homeDesign.borderColor,
            width: _homeDesign.borderWidth,
          ),
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

  Widget _buildCommunityNewsMixedSection(
    HomeSectionConfig config,
    List<Map<String, dynamic>> posts,
  ) {
    final first = posts.first;
    final rest = posts.skip(1).take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeaderFromDesign(
          config: config,
          title: 'Новости сообщества',
          subtitle: 'Главное и свежее в одном блоке',
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
        _buildFeaturedNewsCard(first, config),
        if (rest.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...rest.map((post) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildCompactNewsRow(post, config),
              )),
        ],
      ],
    );
  }

  Widget _buildFeaturedNewsCard(
    Map<String, dynamic> post,
    HomeSectionConfig config,
  ) {
    final title = _stripHtml((post['title'] ?? '').toString());
    final text = _stripHtml((post['text'] ?? '').toString());
    final imageUrl = (post['imageUrl'] ?? '').toString();
    final author = (post['authorName'] ?? 'Пользователь').toString();
    final avatarUrl = (post['authorAvatar'] ?? '').toString();
    final hasImage = imageUrl.isNotEmpty;

    return _buildCard(
      accentOverride: config.accentOverride,
      padding: EdgeInsets.zero,
      onTap: () => _openSpotlight('post', post),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasImage)
            ClipRRect(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(_homeDesign.cardRadius),
              ),
              child: Stack(
                children: [
                  SizedBox(
                    height: 210,
                    width: double.infinity,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: _homeDesign.primaryColor.withOpacity(0.08),
                        child: Center(
                          child: Icon(
                            Icons.image_rounded,
                            color: _homeDesign.primaryColor,
                            size: 48,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.08),
                            Colors.black.withOpacity(0.18),
                            Colors.black.withOpacity(0.52),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: 14,
                    child: Text(
                      title.isNotEmpty ? title : 'Главная новость сообщества',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        height: 1.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!hasImage)
                  Text(
                    title.isNotEmpty ? title : 'Главная новость сообщества',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: _homeDesign.cardTitleSize + 2,
                      fontWeight: FontWeight.w900,
                      color: _homeDesign.textColor,
                    ),
                  ),
                if (!hasImage) const SizedBox(height: 10),
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
                    Text(
                      _formatPostDateHome(post['date'] as DateTime),
                      style: TextStyle(
                        fontSize: _homeDesign.smallTextSize - 1,
                        color: _homeDesign.mutedTextColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  text.isNotEmpty
                      ? text
                      : 'Интересная публикация сообщества',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: _homeDesign.bodyTextSize,
                    color: _homeDesign.textColor,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactNewsRow(
    Map<String, dynamic> post,
    HomeSectionConfig config,
  ) {
    final title = _stripHtml((post['title'] ?? '').toString());
    final imageUrl = (post['imageUrl'] ?? '').toString();
    final hasImage = imageUrl.isNotEmpty;

    return _buildCard(
      accentOverride: config.accentOverride,
      padding: const EdgeInsets.all(12),
      onTap: () => _openSpotlight('post', post),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: _homeDesign.primaryColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            clipBehavior: Clip.hardEdge,
            child: hasImage
                ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.image_rounded,
                      color: _homeDesign.primaryColor,
                    ),
                  )
                : Icon(
                    Icons.article_rounded,
                    color: _homeDesign.primaryColor,
                    size: 28,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.isNotEmpty ? title : 'Новость сообщества',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: _homeDesign.bodyTextSize,
                    fontWeight: FontWeight.w800,
                    color: _homeDesign.textColor,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatPostDateHome(post['date'] as DateTime),
                  style: TextStyle(
                    fontSize: _homeDesign.smallTextSize - 1,
                    color: _homeDesign.mutedTextColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.chevron_right_rounded,
            color: _homeDesign.mutedTextColor,
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAccessGrid() {
    final items = [
      {
        'title': 'Команды',
        'subtitle': 'Клубы и составы',
        'icon': Icons.groups_rounded,
        'color': _homeDesign.primaryColor,
        'onTap': _openClubsAll,
      },
      {
        'title': 'Площадки',
        'subtitle': 'Бронь и доступность',
        'icon': Icons.stadium_rounded,
        'color': _homeDesign.secondaryColor,
        'onTap': _openVenuesAll,
      },
      {
        'title': 'Календарь',
        'subtitle': 'События и матчи',
        'icon': Icons.calendar_month_rounded,
        'color': const Color(0xFF2563EB),
        'onTap': _openScheduleAll,
      },
      {
        'title': 'Видеоуроки',
        'subtitle': 'Обучение и папки',
        'icon': Icons.video_library_rounded,
        'color': const Color(0xFF7C3AED),
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const VideoLessonsHubScreen(),
            ),
          );
        },
      },
      {
        'title': 'Reels',
        'subtitle': 'Короткие видео',
        'icon': Icons.play_circle_fill_rounded,
        'color': const Color(0xFFDB2777),
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ReelsScreen(),
            ),
          );
        },
      },
      {
        'title': 'Подписка PRO',
        'subtitle': 'Доп. функции',
        'icon': Icons.workspace_premium_rounded,
        'color': const Color(0xFFEA580C),
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const SubscriptionScreen(),
            ),
          );
        },
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Разделы',
          style: TextStyle(
            fontSize: _homeDesign.sectionTitleSize,
            fontWeight: FontWeight.w900,
            color: _homeDesign.textColor,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Быстрый доступ к основным модулям',
          style: TextStyle(
            fontSize: _homeDesign.sectionSubtitleSize,
            color: _homeDesign.mutedTextColor,
          ),
        ),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          itemCount: items.length,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.28,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            final color = item['color'] as Color;

            return Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(_homeDesign.cardRadius),
                onTap: item['onTap'] as void Function()?,
                child: Container(
                  decoration: BoxDecoration(
                    color: _homeDesign.cardColor,
                    borderRadius:
                        BorderRadius.circular(_homeDesign.cardRadius),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black
                            .withOpacity(_homeDesign.shadowOpacity),
                        blurRadius: _homeDesign.shadowBlur,
                        offset: const Offset(0, 8),
                      ),
                    ],
                    border: Border.all(
                      color: color.withOpacity(0.12),
                    ),
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          item['icon'] as IconData,
                          color: color,
                          size: 24,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        item['title'] as String,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: _homeDesign.cardTitleSize,
                          fontWeight: FontWeight.w900,
                          color: _homeDesign.textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item['subtitle'] as String,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: _homeDesign.smallTextSize,
                          color: _homeDesign.mutedTextColor,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildVideoSection(HomeSectionConfig config) {
    final visibleCount =
        _reelsData.length > config.itemLimit ? config.itemLimit : _reelsData.length;

    final double reelHeight =
        (config.cardHeight < 320 ? 380 : config.cardHeight + 80);
    final double reelWidth =
        (config.cardWidth < 190 ? 210 : config.cardWidth - 10);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeaderFromDesign(
          config: config,
          title: 'Популярные видео',
          subtitle: 'Лучшие ролики сообщества',
          onSeeAll: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ReelsScreen(),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: reelHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: visibleCount,
            itemBuilder: (context, index) {
              final reel = _reelsData[index];
              return Padding(
                padding:
                    EdgeInsets.only(right: index == visibleCount - 1 ? 0 : 16),
                child: SizedBox(
                  width: reelWidth,
                  child: _buildReelCard(
                    reel,
                    config,
                    index: index,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReelCard(
    Map<String, dynamic> reel,
    HomeSectionConfig config, {
    required int index,
  }) {
    final thumb = (reel['thumbnail'] ?? '').toString();
    final desc = (reel['description'] ?? 'Видео').toString();
    final username = (reel['username'] ?? 'Sportoteka').toString();
    final reelId =
        reel['id'] is int ? reel['id'] as int : int.tryParse('${reel['id']}');

    return _buildCard(
      accentOverride: config.accentOverride,
      padding: EdgeInsets.zero,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReelsScreen(
              initialReelId: reelId,
              initialIndex: index,
            ),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 5,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(_homeDesign.cardRadius),
                  ),
                  child: thumb.isNotEmpty
                      ? Image.network(
                          _normalizeMediaUrl(thumb),
                          fit: BoxFit.cover,
                          filterQuality: FilterQuality.medium,
                          errorBuilder: (_, __, ___) => _reelFallback(),
                        )
                      : _reelFallback(),
                ),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(_homeDesign.cardRadius),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.10),
                        Colors.black.withOpacity(0.18),
                        Colors.black.withOpacity(0.42),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          username.isEmpty ? 'Sportoteka' : username,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Center(
                  child: Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      color: (_configAccent(config) ?? _homeDesign.primaryColor)
                          .withOpacity(0.92),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.18),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    desc,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: _homeDesign.cardTitleSize,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                      color: _homeDesign.textColor,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      _statItem(
                        icon: Icons.remove_red_eye_outlined,
                        value: _formatCount('${reel['views'] ?? 0}'),
                      ),
                      const SizedBox(width: 14),
                      _statItem(
                        icon: Icons.favorite_border_rounded,
                        value: _formatCount('${reel['likes'] ?? 0}'),
                      ),
                      const SizedBox(width: 14),
                      _statItem(
                        icon: Icons.chat_bubble_outline_rounded,
                        value: _formatCount('${reel['comments'] ?? 0}'),
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
        child: Icon(
          Icons.videocam_rounded,
          color: _homeDesign.primaryColor,
          size: 48,
        ),
      ),
    );
  }

  Widget _buildRecommendedVideoFoldersSection() {
    if (_recommendedVideoFolders.isEmpty) {
      return const SizedBox.shrink();
    }

    final headerConfig = _homeDesign.sections.firstWhere(
      (e) => e.type == HomeSectionType.innovations,
      orElse: () => _homeDesign.sections.first,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeaderFromDesign(
          config: headerConfig,
          title: 'Видеоуроки',
          subtitle: 'Рекомендуемые папки от авторов',
          onSeeAll: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const VideoLessonsHubScreen(),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: _recommendedVideoFolders.length,
            itemBuilder: (context, index) {
              final item = _recommendedVideoFolders[index];
              final folder = item['folder'] as VideoFolderModel;
              final ownerUserId = item['ownerUserId'] as int;
              final thumb = (item['thumbnail'] ?? '').toString();
              final title = (item['title'] ?? '').toString();
              final lessonCount = item['lessonCount'] ?? 0;
              final color = _parseVideoFolderColor(
                (item['color'] ?? '#00A750').toString(),
              );
              final authorName = (item['authorName'] ?? 'Автор').toString();
              final authorAvatar = (item['authorAvatar'] ?? '').toString();

              return Padding(
                padding: EdgeInsets.only(
                  right: index == _recommendedVideoFolders.length - 1 ? 0 : 16,
                ),
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VideoLessonFolderScreen(
                          folder: folder,
                          ownerUserId: ownerUserId,
                          isMyMode: false,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    width: 290,
                    decoration: BoxDecoration(
                      color: _homeDesign.cardColor,
                      borderRadius:
                          BorderRadius.circular(_homeDesign.cardRadius),
                      border: Border.all(
                        color: _homeDesign.borderColor.withOpacity(0.9),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withOpacity(_homeDesign.shadowOpacity),
                          blurRadius: _homeDesign.shadowBlur,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(_homeDesign.cardRadius),
                          ),
                          child: Container(
                            height: 130,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  color,
                                  color.withOpacity(0.72),
                                ],
                              ),
                            ),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (thumb.isNotEmpty)
                                  Image.network(
                                    _normalizeMediaUrl(thumb),
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _videoFolderBannerFallback(color),
                                  )
                                else
                                  _videoFolderBannerFallback(color),
                                Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.black.withOpacity(0.08),
                                        Colors.black.withOpacity(0.16),
                                        Colors.black.withOpacity(0.38),
                                      ],
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 12,
                                  right: 12,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.25),
                                      borderRadius:
                                          BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      '$lessonCount видео',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                                const Center(
                                  child: Icon(
                                    Icons.play_circle_fill_rounded,
                                    color: Colors.white,
                                    size: 54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildHomeAuthorAvatar(
                                  avatarUrl: authorAvatar,
                                  author: authorName,
                                  radius: 20,
                                  color: color,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize:
                                              _homeDesign.cardTitleSize,
                                          color: _homeDesign.textColor,
                                          height: 1.2,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        authorName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: _homeDesign.mutedTextColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _videoFolderBannerFallback(Color color) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color,
            color.withOpacity(0.75),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.video_library_rounded,
          color: Colors.white,
          size: 48,
        ),
      ),
    );
  }

  Widget _buildHomeAuthorAvatar({
    required String avatarUrl,
    required String author,
    required double radius,
    required Color color,
  }) {
    final url = _normalizeMediaUrl(avatarUrl);

    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withOpacity(0.14),
      backgroundImage: url.isNotEmpty ? NetworkImage(url) : null,
      child: url.isEmpty
          ? Text(
              author.trim().isNotEmpty
                  ? author.trim()[0].toUpperCase()
                  : 'A',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
                fontSize: radius * 0.8,
              ),
            )
          : null,
    );
  }
  
    Widget _buildPromoSection(HomeSectionConfig config) {
    return _HomePromoBanner(
      title: 'Sportoteka PRO',
      subtitle:
          'Откройте видеоуроки, видеоанализ, heatmap и профессиональные инструменты.',
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

  Widget _buildEventsSection(
    HomeSectionConfig config,
    List<Map<String, dynamic>> events,
  ) {
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
              builder: (_) => EventsListScreen(
                initialSport: selectedSport ?? 'Футбол',
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: config.cardHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount:
                events.length > config.itemLimit ? config.itemLimit : events.length,
            itemBuilder: (context, index) {
              return Padding(
                padding:
                    EdgeInsets.only(right: index == events.length - 1 ? 0 : 16),
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

  Widget _buildEventCard(
    Map<String, dynamic> event,
    HomeSectionConfig config,
  ) {
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
            transitionsBuilder: (_, a, __, child) =>
                FadeTransition(opacity: a, child: child),
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
                          color:
                              _configAccent(config) ?? _homeDesign.primaryColor,
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

  Widget _buildVenuesSection(
    HomeSectionConfig config,
    List<dynamic> venues,
  ) {
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
            itemCount:
                venues.length > config.itemLimit ? config.itemLimit : venues.length,
            itemBuilder: (context, index) {
              return Padding(
                padding:
                    EdgeInsets.only(right: index == venues.length - 1 ? 0 : 16),
                child: SizedBox(
                  width: config.cardWidth,
                  child: _buildVenueCard(
                    venues[index] as Map<String, dynamic>,
                    config,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildVenueCard(
    Map<String, dynamic> venue,
    HomeSectionConfig config,
  ) {
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
                      Icon(
                        Icons.place_rounded,
                        size: 14,
                        color: _homeDesign.mutedTextColor,
                      ),
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
                        color:
                            _configAccent(config) ?? _homeDesign.secondaryColor,
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
    final color = _homeDesign.secondaryColor;
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

  Widget _buildClubsSection(
    HomeSectionConfig config,
    List<Map<String, dynamic>> teams,
  ) {
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
            itemCount:
                teams.length > config.itemLimit ? config.itemLimit : teams.length,
            itemBuilder: (context, index) {
              return Padding(
                padding:
                    EdgeInsets.only(right: index == teams.length - 1 ? 0 : 16),
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

  Widget _buildTeamCard(
    Map<String, dynamic> team,
    HomeSectionConfig config,
  ) {
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.30),
                      ),
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

  Widget _buildTicketsSection(
    HomeSectionConfig config,
    List<Map<String, dynamic>> tickets,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeaderFromDesign(
          config: config,
          title: 'Билеты на матчи',
          subtitle: 'Актуальные предложения',
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
            itemCount:
                tickets.length > config.itemLimit ? config.itemLimit : tickets.length,
            itemBuilder: (context, index) {
              return Padding(
                padding:
                    EdgeInsets.only(right: index == tickets.length - 1 ? 0 : 16),
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

  Widget _buildTicketCard(
    Map<String, dynamic> ticket,
    HomeSectionConfig config,
  ) {
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
                const Icon(
                  Icons.confirmation_number_rounded,
                  color: Colors.white,
                  size: 22,
                ),
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
                  if (date.isNotEmpty)
                    _metaRow(Icons.calendar_today_rounded, date),
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
                        color:
                            _configAccent(config) ?? _homeDesign.primaryColor,
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

  Widget _buildTipsSection(HomeSectionConfig config) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeaderFromDesign(
          config: config,
          title: 'Советы по Sportoteka',
          subtitle: 'Инструкции по работе с функциями приложения',
          onSeeAll: null,
        ),
        const SizedBox(height: 16),
        TipsSection(
          cardWidth: config.cardWidth,
          cardHeight: config.cardHeight,
          borderRadius: _homeDesign.cardRadius,
          cardColor: _homeDesign.cardColor,
          textColor: _homeDesign.textColor,
          mutedColor: _homeDesign.mutedTextColor,
          shadowOpacity: _homeDesign.shadowOpacity,
          shadowBlur: _homeDesign.shadowBlur,
        ),
      ],
    );
  }

  Widget _buildRingBannerSection(HomeSectionConfig config) {
    final accent = config.accentOverride ?? _homeDesign.primaryColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeaderFromDesign(
          config: config,
          title: 'Трекинг устройств',
          subtitle: 'Мониторинг датчиков и тренировочных сессий',
          onSeeAll: null,
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_homeDesign.bannerRadius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF0F172A),
                const Color(0xFF111827),
                accent.withOpacity(0.92),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color:
                    Colors.black.withOpacity(_homeDesign.shadowOpacity + 0.04),
                blurRadius: _homeDesign.shadowBlur + 6,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.12),
                        ),
                      ),
                      child: const Icon(
                        Icons.monitor_heart_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Спортотека Спорт',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: _homeDesign.sectionTitleSize + 2,
                              fontWeight: FontWeight.w900,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Панель устройств и телеметрии',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.74),
                              fontSize: _homeDesign.bodyTextSize,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16A34A).withOpacity(0.16),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: const Color(0xFF4ADE80).withOpacity(0.24),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.radio_button_on_rounded,
                            size: 12,
                            color: Color(0xFF4ADE80),
                          ),
                          SizedBox(width: 6),
                          Text(
                            'ONLINE',
                            style: TextStyle(
                              color: Color(0xFFBBF7D0),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.65,
                  children: [
                    _buildTrackingMiniCard(
                      icon: Icons.bluetooth_connected_rounded,
                      title: 'Устройства',
                      value: 'BLE / HR',
                      subtitle: 'Подключение датчиков',
                    ),
                    _buildTrackingMiniCard(
                      icon: Icons.favorite_rounded,
                      title: 'Пульс',
                      value: 'Live HR',
                      subtitle: 'Мониторинг ЧСС',
                    ),
                    _buildTrackingMiniCard(
                      icon: Icons.route_rounded,
                      title: 'Карта',
                      value: 'Heatmap',
                      subtitle: 'Маршрут и зоны',
                    ),
                    _buildTrackingMiniCard(
                      icon: Icons.play_circle_fill_rounded,
                      title: 'Сессии',
                      value: 'Team / Solo',
                      subtitle: 'Запуск тренировок',
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.10),
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildTrackingSystemRow(
                        icon: Icons.sensors_rounded,
                        label: 'Трекеры',
                        value: 'Готовы к подключению',
                      ),
                      const SizedBox(height: 10),
                      _buildTrackingSystemRow(
                        icon: Icons.favorite_border_rounded,
                        label: 'Пульсометры',
                        value: 'Поддержка BLE HR',
                      ),
                      const SizedBox(height: 10),
                      _buildTrackingSystemRow(
                        icon: Icons.sports_soccer_rounded,
                        label: 'Режимы',
                        value: 'Командный / индивидуальный',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TrackingModeScreen(),
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.open_in_new_rounded,
                          size: 18,
                        ),
                        label: const Text(
                          'Открыть модуль',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: accent,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              _homeDesign.smallRadius,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RingUsageScreen(),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withOpacity(0.16),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            _homeDesign.smallRadius,
                          ),
                        ),
                      ),
                      child: const Text(
                        'Подробнее',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTrackingMiniCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withOpacity(0.10),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 18,
          ),
          const Spacer(),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.72),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.58),
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingSystemRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          color: Colors.white.withOpacity(0.80),
          size: 16,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.74),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
  
    Widget _buildUserPostCard(
    Map<String, dynamic> post,
    HomeSectionConfig config,
  ) {
    final title = _stripHtml((post['title'] ?? '').toString());
    final text = _stripHtml((post['text'] ?? '').toString());
    final author = (post['authorName'] ?? 'Пользователь').toString();
    final imageUrl = (post['imageUrl'] ?? '').toString();
    final hasImage = imageUrl.isNotEmpty;
    final hasVideo = post['hasVideo'] == true;
    final videoUrl = (post['videoUrl'] ?? '').toString();
    final avatarUrl = (post['authorAvatar'] ?? '').toString();

    return _buildCard(
      accentOverride: config.accentOverride,
      padding: EdgeInsets.zero,
      onTap: () {
        final openTitle =
            title.trim().isNotEmpty ? title : (selectedSport ?? 'Новости');

        if (hasVideo && videoUrl.isNotEmpty) {
          if (_looksLikeDirectVideoUrl(videoUrl)) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AppVideoPlayerScreen(
                  title: openTitle,
                  videoUrl: videoUrl,
                  thumbnailUrl: imageUrl,
                ),
              ),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => InAppWebVideoScreen(
                  title: openTitle,
                  url: videoUrl,
                ),
              ),
            );
          }
          return;
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NewsDetailScreen(
              title: openTitle,
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
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: _homeDesign.primaryColor.withOpacity(0.08),
                        child: Center(
                          child: Icon(
                            Icons.image_rounded,
                            color: _homeDesign.primaryColor,
                            size: 48,
                          ),
                        ),
                      ),
                    ),
                    if (hasVideo) ...[
                      Container(
                        color: Colors.black.withOpacity(0.18),
                      ),
                      Center(
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.18),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.play_arrow_rounded,
                            color: _homeDesign.primaryColor,
                            size: 34,
                          ),
                        ),
                      ),
                    ],
                  ],
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
                      text.isNotEmpty
                          ? text
                          : 'Интересная новость от сообщества',
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

  Widget _buildEmptyPlaceholder({
    required IconData icon,
    required String text,
  }) {
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

  String _formatCount(String count) {
    final numVal = int.tryParse(count) ?? 0;
    if (numVal >= 1000000) {
      return '${(numVal / 1000000).toStringAsFixed(1)}M';
    }
    if (numVal >= 1000) {
      return '${(numVal / 1000).toStringAsFixed(1)}K';
    }
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
                          borderRadius: BorderRadius.circular(
                            widget.design.smallRadius,
                          ),
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
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 13,
                                      ),
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

String _normalizeMediaUrl(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return '';
  if (s.startsWith('http://') || s.startsWith('https://')) return s;

  if (s.startsWith('/')) return 'https://sportotekaapp.ru$s';
  return 'https://sportotekaapp.ru/$s';
}

String _stripHtml(String? html) {
  if (html == null || html.isEmpty) return '';

  var text = html;

  text = text.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
  text = text.replaceAll(RegExp(r'</p>', caseSensitive: false), '\n');
  text = text.replaceAll(RegExp(r'</div>', caseSensitive: false), '\n');
  text = text.replaceAll(RegExp(r'</li>', caseSensitive: false), '\n');
  text = text.replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '• ');
  text = text.replaceAll(
    RegExp(r'<[^>]+>', multiLine: true, caseSensitive: false),
    '',
  );

  text = text
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&ndash;', '–')
      .replaceAll('&mdash;', '—')
      .replaceAll('&laquo;', '«')
      .replaceAll('&raquo;', '»');

  text = text.replaceAll(RegExp(r'\s+\n'), '\n');
  text = text.replaceAll(RegExp(r'\n{2,}'), '\n');
  text = text.replaceAll(RegExp(r'[ \t]{2,}'), ' ');

  return text.trim();
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
  if (s.contains('фут')) {
    return config.accentOverride ?? SportPalette.primaryGreen;
  }
  if (s.contains('хок')) {
    return config.accentOverride ?? SportPalette.primaryGreenDark;
  }
  if (s.contains('баскет')) {
    return config.accentOverride ?? SportPalette.accentGreen;
  }
  if (s.contains('волей')) {
    return config.accentOverride ?? SportPalette.primaryGreenLight;
  }
  if (s.contains('теннис')) {
    return config.accentOverride ?? SportPalette.accentGreen;
  }
  return config.accentOverride ?? SportPalette.accentGreen;
}

String _teamInitials(String name) {
  final n = name.trim();
  if (n.isEmpty) return 'T';
  final parts = n.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.length == 1) {
    return parts.first.characters.take(2).toString().toUpperCase();
  }
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
      border: Border.all(
        color: Colors.white.withOpacity(0.95),
        width: 3,
      ),
    ),
    child: ClipOval(
      child: logoUrl.isNotEmpty
          ? Image.network(
              logoUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  _teamFallbackLogo(teamName, accent),
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