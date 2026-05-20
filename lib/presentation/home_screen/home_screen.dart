import 'dart:convert';
import 'dart:math';
import 'dart:ui' show lerpDouble;
import 'package:http/http.dart' as http;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:pool/pool.dart';
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
import 'package:sportoteka/presentation/home_screen/widget/tracking_hero_widget.dart';
import 'package:sportoteka/presentation/player_screen/player_dashboard_screen.dart';
import 'package:sportoteka/presentation/reels_screen/reels_screen.dart';
import 'package:sportoteka/presentation/service_screens/event_detail_screen.dart';
import 'package:sportoteka/presentation/service_screens/generic_service_screen.dart';
import 'package:sportoteka/presentation/subscription/subscription_screen.dart';
import 'package:sportoteka/presentation/team_screen/team_dashboard_screen.dart';
import 'package:sportoteka/presentation/team_screen/team_detail_screen.dart';
import 'package:sportoteka/presentation/tickets/tickets_section.dart';
import 'package:sportoteka/presentation/tracking/tracking_mode_screen.dart';
import 'package:sportoteka/presentation/video_lessons/video_lesson_folder_screen.dart';
import 'package:sportoteka/presentation/video_lessons/video_lessons_hub_screen.dart';
import 'package:sportoteka/presentation/club_dashboard_screen/club_dashboard_screen.dart';
import 'package:sportoteka/presentation/club_workspace/club_workspace_screen.dart';
import 'package:sportoteka/update_checker.dart';
import 'package:get/get.dart';
import 'package:sportoteka/routes/app_routes.dart';
import 'package:sportoteka/presentation/team_calendar_screen/team_calendar_screen.dart';
import 'package:sportoteka/presentation/team_roster_screen/team_roster_screen.dart';
import 'package:sportoteka/presentation/team_attendance_screen/team_attendance_journal_screen.dart';
import 'package:sportoteka/presentation/team_video_analysis/team_video_analysis_screen.dart';
import 'package:sportoteka/presentation/manager_mode/screens/manager_dashboard_screen.dart';
import 'package:sportoteka/presentation/plans/plan_folders_screen.dart';
import 'package:sportoteka/presentation/training_graphics/training_graphics_screen.dart';
import 'package:sportoteka/presentation/club_calendar_screen/club_calendar_screen.dart';
import 'package:sportoteka/presentation/club_attendance/attendance_screen.dart';
import 'package:sportoteka/presentation/club_trainers/team_trainers_screen.dart';
import 'package:sportoteka/presentation/chat_screen/chat_screen.dart';
import 'package:sportoteka/presentation/chat_screen/chat_room_screen.dart';

const String apiBaseUrl = 'https://sportotekaapp.ru/api/';
const Duration cacheDuration = Duration(minutes: 10);
const int maxConcurrentRequests = 3;

final Dio dio = Dio()
  ..options.baseUrl = apiBaseUrl
  ..options.connectTimeout = const Duration(seconds: 10)
  ..options.receiveTimeout = const Duration(seconds: 8)
  ..options.headers = {'Connection': 'keep-alive'};

final Pool requestPool = Pool(maxConcurrentRequests);

class SportPalette {
  static const primaryGreen = Color(0xFF00A750);
  static const primaryGreenDark = Color(0xFF008C40);
  static const primaryGreenLight = Color(0xFF00C060);
  static const accentGreen = Color(0xFF7ED321);

  static const navy = Color(0xFF0F172A);
  static const blue = Color(0xFF2563EB);
  static const blueSoft = Color(0xFFEFF6FF);
  static const purple = Color(0xFF7C3AED);
  static const pink = Color(0xFFDB2777);
  static const orange = Color(0xFFEA580C);
  static const teal = Color(0xFF0F766E);
  static const cyan = Color(0xFF0891B2);

  static const text = Color(0xFF1A1A1A);
  static const textMuted = Color(0xFF666666);
  static const textLight = Color(0xFF999999);
  static const slateBg = Color(0xFFF7F8FA);
  static const card = Color(0xFFFFFFFF);
}

class AppText {
  static const h1 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.7,
    color: Colors.white,
    height: 1.08,
  );

  static const h2 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.3,
    color: SportPalette.text,
    height: 1.2,
  );

  static const h3 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w900,
    color: SportPalette.text,
    height: 1.2,
    letterSpacing: -0.2,
  );

  static const body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: SportPalette.text,
    height: 1.45,
  );

  static const caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: SportPalette.textMuted,
    height: 1.3,
  );
}

const List<String> _sports = ['Футбол'];

const List<_HeaderActionItem> _headerActions = [
  _HeaderActionItem(
    keyName: 'Tracking',
    titleRu: 'Трекинг',
    subtitleRu: 'Датчики и live-сессии',
    icon: Icons.monitor_heart_rounded,
  ),
  _HeaderActionItem(
    keyName: 'Расписание',
    titleRu: 'Календарь',
    subtitleRu: 'Матчи и события',
    icon: Icons.calendar_today_rounded,
  ),
  _HeaderActionItem(
    keyName: 'Видеоуроки',
    titleRu: 'Видеоуроки',
    subtitleRu: 'Папки и обучение',
    icon: Icons.ondemand_video_rounded,
  ),
  _HeaderActionItem(
    keyName: 'Бронь',
    titleRu: 'Площадки',
    subtitleRu: 'Быстрое бронирование',
    icon: Icons.event_available_rounded,
  ),
  _HeaderActionItem(
    keyName: 'Видео',
    titleRu: 'Reels',
    subtitleRu: 'Видео сообщества',
    icon: Icons.play_circle_fill_rounded,
  ),
  _HeaderActionItem(
    keyName: 'Турниры',
    titleRu: 'Турниры',
    subtitleRu: 'Соревнования и лиги',
    icon: Icons.emoji_events_rounded,
  ),
  _HeaderActionItem(
    keyName: 'Трансляции',
    titleRu: 'Трансляции',
    subtitleRu: 'Прямые эфиры',
    icon: Icons.live_tv_rounded,
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

class HomeScreen extends StatefulWidget {
  final void Function(String)? onSportChanged;

  const HomeScreen({super.key, this.onSportChanged});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  HomeScreenDesign _homeDesign = HomeScreenDesign.defaults();

  int? _userId;
  bool isLoading = true;
  bool hasError = false;
  String? errorMessage;
  String? selectedSport = 'Футбол';

  String _currentRole = '';
  String _currentFullName = 'Пользователь';
  int _currentClubId = 0;
  int _currentTeamId = 0;
  String _currentClubName = '';
  String _currentTeamName = '';
  String _currentTeamLogoUrl = '';
  String _currentLocation = '';
  bool _hasBoundClub = false;
  int? _currentAge;

 List<Map<String, dynamic>> _catalogPreview = [];
List<Map<String, dynamic>> _ticketsData = [];
List<Map<String, dynamic>> _reelsData = [];
List<Map<String, dynamic>> _recommendedVideoFolders = [];
List<Map<String, dynamic>> _recentMatches = [];
Map<String, dynamic> _trackerSummary = {};
List<Map<String, dynamic>> _workspaceReports = [];
List<Map<String, dynamic>> _myTeams = [];
List<Map<String, dynamic>> _clubTeams = [];
List<Map<String, dynamic>> _clubTrainers = [];
List<Map<String, dynamic>> _clubEvents = [];
List<Map<String, dynamic>> _clubPlans = [];
List<Map<String, dynamic>> _recentChats = [];

Map<String, dynamic> _clubProfile = {};

int? _selectedWorkspaceTeamId;
String _selectedWorkspaceTeamName = '';



  final Map<String, dynamic> dataCache = {};
  final Map<String, DateTime> cacheTimestamps = {};
  final Map<String, List<Map<String, dynamic>>> _eventsCache = {};
  final Map<String, DateTime> _eventsCacheTimestamps = {};
  final Map<String, List<Map<String, dynamic>>> _userPostsCache = {};
  final Map<String, DateTime> _userPostsTimestamps = {};

  late final ScrollController _scrollController;
  late final PageController _quickActionsController;
  late final PageController _homeModeController;
  late final PageController _dashboardPreviewController;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  bool _collapsedHeader = false;
  int _quickActionPage = 0;
  int _homeModeIndex = 0;
  int _dashboardPreviewPage = 0;

  bool get _isClubRole => _currentRole == 'club' || _currentRole == 'federation';
  bool get _isCoachRole => _currentRole == 'coach' || _currentRole == 'trainer';
  bool get _isPlayerRole => _currentRole == 'player';
  bool get _isParentRole => _currentRole == 'parent';
bool get _isPlayerLikeRole => _isPlayerRole || _isParentRole;

bool get _isCoachWithoutTeam =>
    _isCoachRole && _currentTeamId <= 0 && _myTeams.isEmpty;

bool get _hasCoachOwnedTeams =>
    _isCoachRole && _myTeams.isNotEmpty;
    
  @override
  void initState() {
    super.initState();

    _scrollController = ScrollController()
      ..addListener(() {
        final collapsed =
            _scrollController.hasClients && _scrollController.offset > 40;
        if (collapsed != _collapsedHeader && mounted) {
          setState(() => _collapsedHeader = collapsed);
        }
      });

   _quickActionsController = PageController()
  ..addListener(() {
    final value = _quickActionsController.page?.round() ?? 0;
    if (value != _quickActionPage && mounted) {
      setState(() => _quickActionPage = value);
    }
  });
  
    _homeModeController = PageController()
      ..addListener(() {
        final value = _homeModeController.page?.round() ?? 0;
        if (value != _homeModeIndex && mounted) {
          setState(() => _homeModeIndex = value);
        }
      });

    _dashboardPreviewController = PageController()
      ..addListener(() {
        final value = _dashboardPreviewController.page?.round() ?? 0;
        if (value != _dashboardPreviewPage && mounted) {
          setState(() => _dashboardPreviewPage = value);
        }
      });

    _initAll();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _quickActionsController.dispose();
    _homeModeController.dispose();
    _dashboardPreviewController.dispose();
    super.dispose();
  }

  bool _isTablet(BuildContext context) {
    return MediaQuery.of(context).size.width >= 700;
  }

  bool _isLargeTablet(BuildContext context) {
    return MediaQuery.of(context).size.width >= 1000;
  }

  bool _isLandscape(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape;
  }

  bool _isPhoneLandscape(BuildContext context) {
    return !_isTablet(context) && _isLandscape(context);
  }

  double _responsiveFont(
    BuildContext context, {
    required double mobile,
    double? tablet,
    double landscapeDelta = -0.2,
  }) {
    final base = _isTablet(context) ? (tablet ?? mobile + 1) : mobile;
    return _isLandscape(context) ? max(9, base + landscapeDelta) : base;
  }

  double _contentMaxWidth(BuildContext context) {
  final width = MediaQuery.of(context).size.width;

  if (width >= 1400) return width - 28;
  if (width >= 1100) return width - 20;
  if (width >= 700) return width - 12;

  return width;
}

double _adaptiveHorizontalPadding(BuildContext context) {
  final width = MediaQuery.of(context).size.width;

  if (width >= 1200) return 10;
  if (width >= 900) return 8;
  return 12;
}

double _hubPreviewHeight(BuildContext context) {
  final isTools = _homeModeIndex == 0;

  if (isTools) {
    if (_isClubRole) {
      if (_isLargeTablet(context)) {
        return _isLandscape(context) ? 390 : 500;
      }
      if (_isTablet(context)) {
        return _isLandscape(context) ? 370 : 470;
      }
      return _isLandscape(context) ? 420 : 620;
    }

    if (_isLargeTablet(context)) {
      return _isLandscape(context) ? 300 : 360;
    }
    if (_isTablet(context)) {
      return _isLandscape(context) ? 290 : 350;
    }
    return _isLandscape(context) ? 360 : 470;
  }

  return 1;
}
 
 
   Color _parseVideoFolderColor(String hex) {
    try {
      final value = hex.replaceAll('#', '');
      return Color(int.parse('FF$value', radix: 16));
    } catch (_) {
      return _homeDesign.primaryColor;
    }
  }

Future<void> _loadRecentChats() async {
  print('LOAD RECENT CHATS CALLED');

  final userId = _userId ?? await PrefUtils.getUserId() ?? 0;
  print('LOAD RECENT CHATS userId=$userId');

  if (userId <= 0) {
    print('LOAD RECENT CHATS STOP userId<=0');
    if (!mounted) return;
    setState(() => _recentChats = []);
    return;
  }

  try {
    final uri = Uri.parse(
      'https://sportotekaapp.ru/api/get_user_chats.php?user_id=$userId',
    );

    print('LOAD RECENT CHATS uri=$uri');

    final res = await http.get(uri);

    print('LOAD RECENT CHATS status=${res.statusCode}');
    print('LOAD RECENT CHATS body=${res.body}');

    if (res.statusCode != 200) {
      if (!mounted) return;
      setState(() => _recentChats = []);
      return;
    }

    final data = json.decode(res.body);

    final list = (data is List)
        ? List<Map<String, dynamic>>.from(data)
        : <Map<String, dynamic>>[];

    print('LOAD RECENT CHATS listLength=${list.length}');

    final chats = list.map<Map<String, dynamic>>((chat) {
      final map = Map<String, dynamic>.from(chat);

      final isPrivate = map['is_private'] == 1 ||
          map['is_private'] == '1' ||
          map['is_private'] == true;

      final title = (() {
        final t = (map['title'] ?? '').toString().trim();
        final n = (map['name'] ?? '').toString().trim();

        if (isPrivate) {
          if (t.isNotEmpty) return t;
          if (n.isNotEmpty) return n;
          return 'Личный чат';
        }

        if (n.isNotEmpty) return n;
        if (t.isNotEmpty) return t;
        return 'Группа';
      })();

      final peerPhoto = (map['peer_photo'] ?? '').toString().trim();
      final avatar = peerPhoto.isEmpty
          ? ''
          : (peerPhoto.startsWith('http')
              ? peerPhoto
              : 'https://sportotekaapp.ru/uploads/$peerPhoto');

      return {
        'id': int.tryParse('${map['id'] ?? 0}') ?? 0,
        'title': title,
        'last_message': (map['last_message'] ?? '').toString().trim(),
        'avatar': avatar,
        'unread_count': int.tryParse('${map['unread_count'] ?? 0}') ?? 0,
        'last_time': (map['last_time'] ?? map['last_message_time'] ?? '')
            .toString()
            .trim(),
        'is_private': isPrivate,
      };
    }).toList();

    chats.sort((a, b) {
      final ta = (a['last_time'] ?? '').toString();
      final tb = (b['last_time'] ?? '').toString();
      return tb.compareTo(ta);
    });

    if (!mounted) return;
    setState(() {
      _recentChats = chats.take(3).toList();
    });

    print('LOAD RECENT CHATS finalLength=${_recentChats.length}');
  } catch (e) {
    print('LOAD RECENT CHATS ERROR=$e');
    if (!mounted) return;
    setState(() => _recentChats = []);
  }
}
Future<void> _initAll() async {
  _ticketsData = _getDefaultTickets();
  _userId = await PrefUtils.getUserId();

  await _loadCurrentLoginContext();
  await _loadCurrentUserContext();
  await _loadSavedHomeDesign();
  await _loadInitialData();
  await _loadRecentChats(); // <- добавь
  await _loadMyTeams();

  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    AppUpdateService.checkAndShow(context);
  });
}  

Widget _buildClubActivityCard({
  required IconData icon,
  required Color color,
  required String title,
  required String mainText,
  required String subText,
}) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE7ECF2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(height: 10),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          mainText,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 13,
            fontWeight: FontWeight.w900,
            height: 1.1,
          ),
        ),
        if (subText.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            subText,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
        ],
      ],
    ),
  );
}

  Map<String, dynamic>? _getLatestClubEvent() {
  return _pickLatestMapByDate(
    _clubEvents,
    ['event_date', 'date', 'created_at', 'updated_at'],
  );
}

Map<String, dynamic>? _getLatestClubPlan() {
  return _pickLatestMapByDate(
    _clubPlans,
    ['created_at', 'date', 'updated_at'],
  );
}

Map<String, dynamic>? _pickLatestMapByDate(
  List<Map<String, dynamic>> items,
  List<String> dateKeys,
) {
  if (items.isEmpty) return null;

  final copied = items.map((e) => Map<String, dynamic>.from(e)).toList();

  copied.sort((a, b) {
    final aDate = _extractDateFromMap(a, dateKeys);
    final bDate = _extractDateFromMap(b, dateKeys);

    if (aDate == null && bDate == null) return 0;
    if (aDate == null) return 1;
    if (bDate == null) return -1;

    return bDate.compareTo(aDate);
  });

  return copied.first;
}

DateTime? _extractDateFromMap(
  Map<String, dynamic> item,
  List<String> keys,
) {
  for (final key in keys) {
    final raw = (item[key] ?? '').toString().trim();
    final parsed = _tryParseLooseDate(raw);
    if (parsed != null) return parsed;
  }
  return null;
}

DateTime? _tryParseLooseDate(String raw) {
  if (raw.trim().isEmpty) return null;

  final iso = DateTime.tryParse(raw);
  if (iso != null) return iso;

  final match = RegExp(
    r'^(\d{1,2})\.(\d{1,2})\.(\d{4})(?:[ T](\d{1,2}):(\d{2}))?$',
  ).firstMatch(raw);

  if (match == null) return null;

  final day = int.tryParse(match.group(1) ?? '');
  final month = int.tryParse(match.group(2) ?? '');
  final year = int.tryParse(match.group(3) ?? '');
  final hour = int.tryParse(match.group(4) ?? '0') ?? 0;
  final minute = int.tryParse(match.group(5) ?? '0') ?? 0;

  if (day == null || month == null || year == null) return null;

  return DateTime(year, month, day, hour, minute);
}

String _buildClubEventPreview() {
  final latest = _getLatestClubEvent();
  if (latest == null) return 'Нет событий';

  final title = _pickMapString(
    latest,
    ['title', 'name', 'event_title'],
    fallback: 'Событие',
  );

  final date = _pickMapString(latest, ['event_date', 'date']);
  return date.isNotEmpty ? '$title\n$date' : title;
}

String _buildClubPlanPreview() {
  final latest = _getLatestClubPlan();
  if (latest == null) return 'Нет планов';

  final title = _pickMapString(
    latest,
    ['title', 'name', 'plan_title'],
    fallback: 'План',
  );

  final date = _pickMapString(latest, ['created_at', 'date']);
  return date.isNotEmpty ? '$title\n$date' : title;
}
  
  Future<void> _loadClubWorkspaceExtras() async {
  if (!_isClubRole && !_isCoachRole) return;

  final clubId = _currentClubId;
  if (clubId <= 0 && !_isCoachRole) return;

  List<Map<String, dynamic>> clubTeams = [];
  List<Map<String, dynamic>> clubTrainers = [];
  List<Map<String, dynamic>> clubEvents = [];
  List<Map<String, dynamic>> clubPlans = [];
  Map<String, dynamic> clubProfile = {};

  try {
    if (_isClubRole && clubId > 0) {
      try {
        final resp = await dio.post(
          'get_club_profile.php',
          data: {'club_id': clubId.toString()},
        );
        final data = resp.data;
        if (data is Map && data['club'] is Map) {
          clubProfile = Map<String, dynamic>.from(data['club']);
        }
      } catch (_) {}

      try {
        final resp = await dio.post(
          'get_club_teams.php',
          data: {'club_id': clubId.toString()},
        );
        final data = resp.data;
        final raw = data is Map ? (data['teams'] ?? []) : [];
        if (raw is List) {
          clubTeams = raw
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      } catch (_) {}

      try {
        final resp = await dio.post(
          'get_club_trainers.php',
          data: {'club_id': clubId.toString()},
        );
        final data = resp.data;
        final raw = data is Map ? (data['trainers'] ?? []) : [];
        if (raw is List) {
          clubTrainers = raw
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      } catch (_) {}

      try {
        final resp = await dio.post(
          'get_club_events.php',
          data: {'club_id': clubId.toString()},
        );
        final data = resp.data;
        final raw = data is Map ? (data['events'] ?? []) : [];
        if (raw is List) {
          clubEvents = raw
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      } catch (_) {}

      try {
        final resp = await dio.post(
          'get_training_plans.php',
          data: {'club_id': clubId.toString()},
        );
        final data = resp.data;
        final raw = data is Map ? (data['plans'] ?? []) : [];
        if (raw is List) {
          clubPlans = raw
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      } catch (_) {}
    }

    if (_isCoachRole) {
      clubTeams = _myTeams.isNotEmpty
          ? List<Map<String, dynamic>>.from(_myTeams)
          : clubTeams;
    }

    if (!mounted) return;

    setState(() {
      _clubProfile = clubProfile;
      _clubTeams = clubTeams;
      _clubTrainers = clubTrainers;
      _clubEvents = clubEvents;
      _clubPlans = clubPlans;

      if (_selectedWorkspaceTeamId == null) {
        if (_isCoachRole && _myTeams.isNotEmpty) {
          final first = _myTeams.first;
          _selectedWorkspaceTeamId =
              int.tryParse('${first['id'] ?? first['team_id'] ?? 0}') ?? 0;
          _selectedWorkspaceTeamName =
              (first['name'] ?? first['team_name'] ?? 'Команда').toString();
        } else if (_clubTeams.isNotEmpty) {
          final first = _clubTeams.first;
          _selectedWorkspaceTeamId =
              int.tryParse('${first['id'] ?? first['team_id'] ?? 0}') ?? 0;
          _selectedWorkspaceTeamName =
              (first['name'] ?? first['team_name'] ?? 'Команда').toString();
        }
      }
    });
  } catch (e) {
    debugPrint('Ошибка _loadClubWorkspaceExtras: $e');
  }
}
  
  
  Future<void> _loadMyTeams() async {
  if (!_isCoachRole) return;

  final userId = _userId ?? await PrefUtils.getUserId() ?? 0;
  if (userId <= 0) return;

  try {
    final response = await dio.get(
      'get_my_teams.php',
      queryParameters: {'user_id': userId},
    );

    final data = response.data;

    List raw = const [];
    if (data is Map) {
      raw = (data['teams'] ?? data['data'] ?? data['items'] ?? []) as List? ?? [];
    } else if (data is List) {
      raw = data;
    }

    final teams = raw.map<Map<String, dynamic>>((e) {
      return Map<String, dynamic>.from(e as Map);
    }).toList();

    if (!mounted) return;
    setState(() {
      _myTeams = teams;
    });
  } catch (e) {
    debugPrint('Ошибка загрузки моих команд: $e');
    if (!mounted) return;
    setState(() {
      _myTeams = [];
    });
  }
}

  Future<void> _loadCurrentUserContext() async {
    try {
      final firstName = await PrefUtils.getUserFirstName();
      final lastName = await PrefUtils.getUserLastName();
      final role = await PrefUtils.getRole();
      final fullName = ('$firstName $lastName').trim();

      if (!mounted) return;
      setState(() {
        _currentRole = role.trim().toLowerCase();
        _currentFullName = fullName.isEmpty ? 'Пользователь' : fullName;
      });
    } catch (e) {
      debugPrint('Ошибка загрузки контекста пользователя: $e');
    }
  }

  Future<void> _loadCurrentLoginContext() async {
    try {
      final userId = await PrefUtils.getUserId() ?? 0;
      final role = (await PrefUtils.getRole() ?? '').trim().toLowerCase();
      if (userId <= 0) return;

      final response = await dio.get(
        'get_user.php',
        queryParameters: {'user_id': userId},
      );

      final data = response.data;
      if (data is! Map) return;

      final user = (data['user'] is Map)
          ? Map<String, dynamic>.from(data['user'])
          : <String, dynamic>{};

      int clubId = 0;
      int teamId = 0;
      String clubName = '';
      String teamName = '';
      String teamLogo = '';

      if (role == 'club') {
        clubId = int.tryParse('${user['id']}') ?? 0;
        clubName = (user['club_name'] ?? user['name'] ?? '').toString().trim();
        teamLogo = _teamLogoFromAnyKey({
          'logo': user['photo'] ?? user['photo_url'],
          'logo_url': user['photo_url'] ?? user['photo'],
          'image': user['photo'],
        });
        if (clubName.isEmpty) {
          clubName = (user['first_name'] ?? '').toString().trim();
        }
      } else if (role == 'federation') {
        clubId = int.tryParse('${user['id']}') ?? 0;
        clubName = (user['club_name'] ?? user['name'] ?? user['first_name'] ?? '')
            .toString()
            .trim();
        teamLogo = _teamLogoFromAnyKey({
          'logo': user['photo'] ?? user['photo_url'],
          'logo_url': user['photo_url'] ?? user['photo'],
        });
      } else if (role == 'coach' || role == 'trainer') {
        clubId = int.tryParse('${user['club_id'] ?? user['clubId'] ?? 0}') ?? 0;
        teamId = int.tryParse('${user['team_id'] ?? user['teamId'] ?? 0}') ?? 0;
        clubName =
            (user['club_name'] ?? user['clubName'] ?? '').toString().trim();
        teamName =
            (user['team_name'] ?? user['teamName'] ?? '').toString().trim();
        teamLogo = _teamLogoFromAnyKey({
          'logo': user['logo'] ?? user['photo'],
          'logo_url': user['logo_url'] ?? user['photo_url'],
        });
      } else if (role == 'player' || role == 'parent') {
        final playerTeam = (data['player_team'] is Map)
            ? Map<String, dynamic>.from(data['player_team'])
            : <String, dynamic>{};

        if (playerTeam.isNotEmpty) {
          teamId =
              int.tryParse('${playerTeam['id'] ?? playerTeam['team_id'] ?? 0}') ??
                  0;
          clubId = int.tryParse('${playerTeam['club_id'] ?? 0}') ?? 0;
          teamName = (playerTeam['name'] ?? playerTeam['team_name'] ?? '')
              .toString()
              .trim();
          clubName = (playerTeam['club_name'] ?? '').toString().trim();
          teamLogo = _teamLogoFromAnyKey({
            'logo': playerTeam['logo_url'] ?? playerTeam['logo'],
            'logo_url': playerTeam['logo_url'],
            'image': playerTeam['image'],
          });
        }
      }

      final hasBoundClub = clubId > 0 ||
          teamId > 0 ||
          clubName.isNotEmpty ||
          teamName.isNotEmpty ||
          role == 'club' ||
          role == 'federation';

      if (!mounted) return;
      setState(() {
        _currentRole = role;
        _currentClubId = clubId;
        _currentTeamId = teamId;
        _currentClubName = clubName;
        _currentTeamName = teamName;
        _currentTeamLogoUrl = teamLogo;
        _hasBoundClub = hasBoundClub;
      });
    } catch (e) {
      debugPrint('Ошибка _loadCurrentLoginContext: $e');
    }
  }

  Future<void> _loadSavedHomeDesign() async {
    try {
      final userId = _userId ?? await PrefUtils.getUserId();
      if (userId == null) {
        if (!mounted) return;
        setState(() {
          _homeDesign = _normalizeHomeDesign(HomeScreenDesign.defaults());
        });
        return;
      }

      final raw = await PrefUtils.getString('home_design_user_$userId');
      if (raw == null || raw.trim().isEmpty) {
        if (!mounted) return;
        setState(() {
          _homeDesign = _normalizeHomeDesign(HomeScreenDesign.defaults());
        });
        return;
      }

      try {
        final parsed = _normalizeHomeDesign(HomeScreenDesign.decode(raw));
        if (!mounted) return;
        setState(() {
          _homeDesign = parsed;
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
        });
      }
    } catch (e) {
      debugPrint('Ошибка загрузки дизайна главной: $e');
      if (!mounted) return;
      setState(() {
        _homeDesign = _normalizeHomeDesign(HomeScreenDesign.defaults());
      });
    }
  }

 HomeScreenDesign _normalizeHomeDesign(HomeScreenDesign design) {
  double safeDouble(double value, double fallback) {
    if (value.isNaN || value.isInfinite) return fallback;
    return value;
  }

  HomeSectionConfig normalizeSection(HomeSectionConfig config) {
    double minHeight = 120;
    double minWidth = 180;

    switch (config.type) {
      case HomeSectionType.ringBanner:
        minHeight = 120;
        minWidth = 240;
        break;
      case HomeSectionType.reels:
        minHeight = 180;
        minWidth = 160;
        break;
      case HomeSectionType.promo:
        minHeight = 120;
        minWidth = 220;
        break;
      case HomeSectionType.innovations:
        minHeight = 120;
        minWidth = 180;
        break;
      case HomeSectionType.tips:
        minHeight = 120;
        minWidth = 180;
        break;
      case HomeSectionType.events:
        minHeight = 160;
        minWidth = 180;
        break;
      case HomeSectionType.venues:
        minHeight = 160;
        minWidth = 180;
        break;
      case HomeSectionType.clubs:
        minHeight = 160;
        minWidth = 180;
        break;
      case HomeSectionType.tickets:
        minHeight = 140;
        minWidth = 180;
        break;
      case HomeSectionType.posts:
        minHeight = 160;
        minWidth = 180;
        break;
    }

    final safeCardHeight = safeDouble(config.cardHeight, minHeight);
    final safeCardWidth = safeDouble(config.cardWidth, minWidth);

    return config.copyWith(
      cardHeight: safeCardHeight < minHeight ? minHeight : safeCardHeight,
      cardWidth: safeCardWidth < minWidth ? minWidth : safeCardWidth,
      itemLimit: config.itemLimit < 1 ? 1 : config.itemLimit,
      gridColumns: config.gridColumns < 1 ? 1 : config.gridColumns,
      aspectRatio: config.aspectRatio <= 0 ? 1.0 : config.aspectRatio,
      topSpacing: config.topSpacing < 0 ? 0 : config.topSpacing,
      bottomSpacing: config.bottomSpacing < 0 ? 0 : config.bottomSpacing,
      innerPadding: config.innerPadding < 0 ? 0 : config.innerPadding,
    );
  }

  return design.copyWith(
    headerTitleSize: safeDouble(design.headerTitleSize, 20),
    headerSubtitleSize: safeDouble(design.headerSubtitleSize, 11),
    sectionTitleSize: safeDouble(design.sectionTitleSize, 14),
    sectionSubtitleSize: safeDouble(design.sectionSubtitleSize, 11),
    cardTitleSize: safeDouble(design.cardTitleSize, 13),
    bodyTextSize: safeDouble(design.bodyTextSize, 12),
    smallTextSize: safeDouble(design.smallTextSize, 11),
    textScale: safeDouble(design.textScale, 1.0),
    cardRadius: safeDouble(design.cardRadius, 14),
    bannerRadius: safeDouble(design.bannerRadius, 18),
    borderWidth: safeDouble(design.borderWidth, 1),
    shadowOpacity: safeDouble(design.shadowOpacity, 0.06),
    shadowBlur: safeDouble(design.shadowBlur, 12),
    sectionGap: safeDouble(design.sectionGap, 12),
    pageHorizontalPadding: safeDouble(design.pageHorizontalPadding, 12),
    quickActionBubbleSize: safeDouble(design.quickActionBubbleSize, 46),
    quickActionIconSize: safeDouble(design.quickActionIconSize, 20),
    quickActionsCornerRadius: safeDouble(design.quickActionsCornerRadius, 16),
    quickActionBorderWidth: safeDouble(design.quickActionBorderWidth, 1),
    blurSigma: safeDouble(design.blurSigma, 12),
    glassOpacity: safeDouble(design.glassOpacity, 0.14),
    headerImageOpacity: safeDouble(design.headerImageOpacity, 0.18),
    headerOverlayOpacity: safeDouble(design.headerOverlayOpacity, 0.18),
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


void _runWorkspaceModuleById(String id) {
  final teamId = _selectedWorkspaceTeamId ?? _currentTeamId;
  final teamName = _selectedWorkspaceTeamName.isNotEmpty
      ? _selectedWorkspaceTeamName
      : (_currentTeamName.isNotEmpty ? _currentTeamName : _getDashboardTargetName());

  if (id == "roster" && teamId > 0) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TeamRosterScreen(
          teamId: teamId,
          teamName: teamName,
        ),
      ),
    );
    return;
  }

  if (id == "calendar" && teamId > 0) {
    Get.to(
      () => TeamCalendarScreen(
        teamId: teamId,
        teamName: teamName,
      ),
    );
    return;
  }

  if (id == "attendance" && teamId > 0) {
    Get.to(
      () => TeamAttendanceJournalScreen(
        teamId: teamId,
        teamName: teamName,
      ),
    );
    return;
  }

  if (id == "matches" && teamId > 0) {
    Get.toNamed(
      AppRoutes.teamMatchesScreen,
      arguments: teamId,
    );
    return;
  }

  if (id == "videoanalysis" && teamId > 0) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TeamVideoAnalysisScreen(
          teamId: teamId,
          teamName: teamName,
          clubId: _currentClubId,
          clubName: _currentClubName,
        ),
      ),
    );
    return;
  }

  if (id == "plans" && teamId > 0) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlanFoldersScreen(
          clubId: _currentClubId,
          clubName: _currentClubName,
          teamId: teamId,
        ),
      ),
    );
    return;
  }

  if (id == "graphics" && teamId > 0) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TrainingGraphicsScreen(
          clubId: _currentClubId,
          clubName: _currentClubName,
          teamId: teamId,
          teamName: teamName,
        ),
      ),
    );
    return;
  }

  if (id == "manager_mode" && teamId > 0) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ManagerDashboardScreen(
          teamId: teamId,
          userId: _userId ?? 0,
          teamName: teamName,
        ),
      ),
    );
    return;
  }
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
  _loadClubWorkspaceExtras(),
  _loadRecentChats(),
]);

      await _loadRoleWorkspaceData();
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
  
Future<void> _loadRoleWorkspaceData() async {
  final List<Map<String, dynamic>> recentMatches = [];
  final List<Map<String, dynamic>> reports = [];
  Map<String, dynamic> tracker = {};

  try {
    if (_isCoachRole && _currentTeamId <= 0) {
      if (!mounted) return;
      setState(() {
        _recentMatches = [];
        _workspaceReports = [];
        _trackerSummary = {};
      });
      return;
    }

    if (_isClubRole) {
      if (_currentClubId > 0) {
        try {
          final response = await dio.get(
            'get_team_matches.php',
            queryParameters: {'club_id': _currentClubId, 'limit': 6},
          );
          final data = response.data;
          final List raw = data is Map
              ? (data['matches'] ?? data['data'] ?? data['items'] ?? [])
                      as List? ??
                  []
              : (data is List ? data : const []);
          recentMatches.addAll(
            raw.map((e) => Map<String, dynamic>.from(e as Map)),
          );
        } catch (_) {}

        try {
          final response = await dio.get(
            'get_match_reports.php',
            queryParameters: {'club_id': _currentClubId, 'limit': 6},
          );
          final data = response.data;
          final List raw = data is Map
              ? (data['reports'] ?? data['data'] ?? data['items'] ?? [])
                      as List? ??
                  []
              : (data is List ? data : const []);
          reports.addAll(
            raw.map((e) => Map<String, dynamic>.from(e as Map)),
          );
        } catch (_) {}

        try {
          final response = await dio.get(
            'get_tracker_summary.php',
            queryParameters: {'club_id': _currentClubId},
          );
          final data = response.data;
          if (data is Map) {
            tracker = Map<String, dynamic>.from(
              data['summary'] is Map ? data['summary'] : data,
            );
          }
        } catch (_) {}
      }
    } else if (_isCoachRole) {
      if (_currentTeamId > 0) {
        try {
          final response = await dio.get(
            'get_team_matches.php',
            queryParameters: {'team_id': _currentTeamId, 'limit': 6},
          );
          final data = response.data;
          final List raw = data is Map
              ? (data['matches'] ?? data['data'] ?? data['items'] ?? [])
                      as List? ??
                  []
              : (data is List ? data : const []);
          recentMatches.addAll(
            raw.map((e) => Map<String, dynamic>.from(e as Map)),
          );
        } catch (_) {}

        try {
          final response = await dio.get(
            'get_match_reports.php',
            queryParameters: {'team_id': _currentTeamId, 'limit': 6},
          );
          final data = response.data;
          final List raw = data is Map
              ? (data['reports'] ?? data['data'] ?? data['items'] ?? [])
                      as List? ??
                  []
              : (data is List ? data : const []);
          reports.addAll(
            raw.map((e) => Map<String, dynamic>.from(e as Map)),
          );
        } catch (_) {}

        try {
          final response = await dio.get(
            'get_tracker_summary.php',
            queryParameters: {'team_id': _currentTeamId},
          );
          final data = response.data;
          if (data is Map) {
            tracker = Map<String, dynamic>.from(
              data['summary'] is Map ? data['summary'] : data,
            );
          }
        } catch (_) {}
      }
    } else if (_isPlayerRole || _isParentRole) {
      final uid = _userId ?? 0;

      if (uid > 0) {
        try {
          final response = await dio.get(
            'get_player_matches.php',
            queryParameters: {'user_id': uid, 'limit': 6},
          );
          final data = response.data;
          final List raw = data is Map
              ? (data['matches'] ?? data['data'] ?? data['items'] ?? [])
                      as List? ??
                  []
              : (data is List ? data : const []);
          recentMatches.addAll(
            raw.map((e) => Map<String, dynamic>.from(e as Map)),
          );
        } catch (_) {}

        try {
          final response = await dio.get(
            'get_player_reports.php',
            queryParameters: {'user_id': uid, 'limit': 6},
          );
          final data = response.data;
          final List raw = data is Map
              ? (data['reports'] ?? data['data'] ?? data['items'] ?? [])
                      as List? ??
                  []
              : (data is List ? data : const []);
          reports.addAll(
            raw.map((e) => Map<String, dynamic>.from(e as Map)),
          );
        } catch (_) {}

        try {
          final response = await dio.get(
            'get_tracker_summary.php',
            queryParameters: {'user_id': uid},
          );
          final data = response.data;
          if (data is Map) {
            tracker = Map<String, dynamic>.from(
              data['summary'] is Map ? data['summary'] : data,
            );
          }
        } catch (_) {}
      }
    }

    if (!_isCoachWithoutTeam) {
      if (recentMatches.isEmpty) {
        recentMatches.addAll(_buildFallbackRecentMatches());
      }

      if (reports.isEmpty) {
        reports.addAll(_buildFallbackReports());
      }

      if (tracker.isEmpty) {
        tracker = _buildFallbackTrackerSummary();
      }
    }

    if (!mounted) return;
    setState(() {
      _recentMatches = recentMatches.take(6).toList();
      _workspaceReports = reports.take(6).toList();
      _trackerSummary = tracker;
    });
  } catch (e) {
    debugPrint('Ошибка загрузки рабочей панели: $e');
    if (!mounted) return;

    if (_isCoachWithoutTeam) {
      setState(() {
        _recentMatches = [];
        _workspaceReports = [];
        _trackerSummary = {};
      });
    } else {
      setState(() {
        _recentMatches = _buildFallbackRecentMatches();
        _workspaceReports = _buildFallbackReports();
        _trackerSummary = _buildFallbackTrackerSummary();
      });
    }
  }
}


  List<Map<String, dynamic>> _buildFallbackRecentMatches() {
    final target = _getDashboardTargetName().trim().isNotEmpty
        ? _getDashboardTargetName().trim()
        : 'Команда';

    return [
      {
        'title': '$target — Минск U17',
        'date': '12.08.2025',
        'status': 'Завершён',
        'score': '2:1',
        'location': 'Домашний матч',
      },
      {
        'title': '$target — Академия Юни',
        'date': '07.08.2025',
        'status': 'Завершён',
        'score': '1:1',
        'location': 'Выезд',
      },
      {
        'title': '$target — Смена',
        'date': '03.08.2025',
        'status': 'Подготовка',
        'score': '—',
        'location': 'Тренировочная игра',
      },
    ];
  }

  List<Map<String, dynamic>> _buildFallbackReports() {
    return [
      {
        'title': 'Отчёт по последнему матчу',
        'subtitle': 'Статистика, действия, основные эпизоды',
        'type': 'Матч',
        'value': 'Готов',
      },
      {
        'title': 'Отчёт по игрокам',
        'subtitle': 'Сводка по команде и индивидуальным действиям',
        'type': 'Игроки',
        'value': 'Обновлён',
      },
      {
        'title': 'Тренировочный отчёт',
        'subtitle': 'Посещаемость, нагрузка, комментарии',
        'type': 'Тренировки',
        'value': 'Сегодня',
      },
    ];
  }

  Map<String, dynamic> _buildFallbackTrackerSummary() {
    if (_isPlayerRole || _isParentRole) {
      return {
        'title': 'Состояние игрока',
        'pulse': '128',
        'readiness': '82%',
        'load': 'Средняя',
        'distance': '6.4 км',
        'sprints': '18',
      };
    }

    return {
      'title': 'Состояние команды',
      'pulse': '124',
      'readiness': '79%',
      'load': 'Рабочая',
      'distance': '42.8 км',
      'sprints': '96',
    };
  }

  Future<List<Map<String, dynamic>>> _fetchWeeklyEvents(String sport) async {
    try {
      final response = await dio.get(
        'get_week_events.php',
        queryParameters: {'sport': sport},
      );

      if (response.data is List) {
        return List<Map<String, dynamic>>.from(response.data);
      }

      if (response.data is Map) {
        final data = response.data as Map;
        final items = data['events'] ?? data['data'] ?? data['items'] ?? [];
        return List<Map<String, dynamic>>.from(items as List);
      }

      return [];
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

      if (response.data is Map) {
        final data = response.data as Map;
        if (data['status'] != null && data['status'] != 'success') {
          throw Exception(
            'Ошибка на сервере: ${data['message'] ?? 'неизвестная ошибка'}',
          );
        }
        return List<Map<String, dynamic>>.from(
          (data['teams'] ?? data['items'] ?? data['data'] ?? []) as List,
        );
      }

      if (response.data is List) {
        return List<Map<String, dynamic>>.from(response.data);
      }

      return [];
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

      if (response.data is Map) {
        final data = response.data as Map;
        if (data['status'] == 'success') {
          return List<Map<String, dynamic>>.from(
            (data['venues'] ?? data['items'] ?? data['data'] ?? []) as List,
          );
        }
        return List<Map<String, dynamic>>.from(
          ((data['venues'] ?? data['items'] ?? data['data'] ?? []) as List?) ??
              [],
        );
      }

      if (response.data is List) {
        return List<Map<String, dynamic>>.from(response.data);
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
                  ? (data['data'] ?? data['items'] ?? data['posts'] ?? [])
                          as List? ??
                      []
                  : []);

      final sportLc = sport.toLowerCase();

      final out = raw.where((e) {
        final m = Map<String, dynamic>.from(e as Map);
        final cat = (m['category'] ?? '').toString().toLowerCase();
        return cat == sportLc || cat.isEmpty;
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
          'date':
              DateTime.tryParse((m['created_at'] ?? '').toString()) ?? DateTime.now(),
          'authorAvatar': avatarUrl,
          'authorName': full,
          'user_id': int.tryParse('${m['user_id']}') ?? 0,
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
      final res = await dio.get(
        'get_schools.php',
        queryParameters: {'limit': 12, 'offset': 0},
      );

      if (res.data is Map && res.data['items'] is List) {
        return List<Map<String, dynamic>>.from(res.data['items']);
      } else if (res.data is Map && res.data['data'] is List) {
        return List<Map<String, dynamic>>.from(res.data['data']);
      } else if (res.data is List) {
        return List<Map<String, dynamic>>.from(res.data);
      }

      return const [];
    } catch (_) {
      return const [];
    }
  }

  Future<void> _loadReels() async {
    try {
      final response = await dio.get('get_reels.php');
      final data = response.data;

      List raw;
      if (data is Map) {
        raw = (data['reels'] ?? data['data'] ?? data['items'] ?? data['list'] ?? [])
                as List? ??
            [];
      } else if (data is List) {
        raw = data;
      } else {
        raw = const [];
      }

      final normalized = raw.map<Map<String, dynamic>>((e) {
        final m = Map<String, dynamic>.from(e as Map);
        final video = (m['video_url'] ?? m['video'] ?? m['url'] ?? m['src'] ?? '')
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
        (a, b) => (b['created_at'] as DateTime).compareTo(a['created_at'] as DateTime),
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

    final events = await _fetchWeeklyEvents(sport);
    if (!mounted) return;

    setState(() {
      _eventsCache[sport] = events;
      _eventsCacheTimestamps[sport] = now;
    });
  }

  Future<void> _loadRecommendedVideoFolders() async {
    try {
      final response = await dio.get('video_lessons/get_video_lesson_authors.php');
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

        final String firstName =
            (author['first_name'] ?? author['name'] ?? author['author_name'] ?? '')
                .toString()
                .trim();
        final String lastName =
            (author['last_name'] ?? author['surname'] ?? '').toString().trim();
        final String authorName = ('$firstName $lastName').trim().isEmpty
            ? 'Автор'
            : ('$firstName $lastName').trim();
        final String authorAvatar =
            (author['avatar'] ?? author['photo'] ?? author['photo_url'] ?? '')
                .toString();

        try {
          final folders = await VideoLessonsService.getAllFoldersRecursive(
            ownerId: ownerUserId,
          );

          final foldersWithLessons = folders.where((f) => f.lessonsCount > 0).toList()
            ..shuffle(Random());

          for (final folder in foldersWithLessons) {
            if (collected.length >= 8) break;

            final uniqueKey = '${ownerUserId}_${folder.id}';
            if (usedFolderKeys.contains(uniqueKey)) continue;

            try {
              final lessons = await VideoLessonsService.getLessons(folderId: folder.id);
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

    final posts = await _fetchUserPosts(sport);
    if (!mounted) return;

    setState(() {
      _userPostsCache[sport] = posts;
      _userPostsTimestamps[sport] = now;
    });
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

    final data = await requestPool.withResource(() => _fetchWithRetry(fetchFunction));
    if (!mounted) return;

    setState(() {
      dataCache[key] = data;
      cacheTimestamps[key] = DateTime.now();
    });
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
      MaterialPageRoute(builder: (_) => BookingScreen(userId: userId)),
    );
  }

  void _openClubsAll() {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TeamListScreen()),
    );
  }

  void _openEventsAll() {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EventsListScreen(
          initialSport: selectedSport ?? 'Футбол',
        ),
      ),
    );
  }

  void _openTicketsAll() {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TicketsSection(
          selectedClub: null,
          tickets: _ticketsData,
        ),
      ),
    );
  }

  void _openSubscription() {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const SubscriptionScreen(),
      ),
    );
  }

  void _openVideoLessons() {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const VideoLessonsHubScreen(),
      ),
    );
  }

  void _openReels() {
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ReelsScreen(),
      ),
    );
  }

  void _openClubCmrPanel() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ClubWorkspaceScreen(),
      ),
    );
  }

  void _openWorkspacePrimary() {
    final targetId = _getDashboardTargetId();
    final targetName = _getDashboardTargetName().trim().isNotEmpty
        ? _getDashboardTargetName().trim()
        : _currentFullName;

    if (_isPlayerRole) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PlayerDashboardScreen(
            teamId: targetId > 0 ? targetId : _currentTeamId,
            teamName: targetName,
            userId: _userId ?? 0,
            teamLogo: _currentTeamLogoUrl,
          ),
        ),
      );
      return;
    }

    if (_isClubRole) {
      _openClubCmrPanel();
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TeamDashboardScreen(
          teamId: targetId > 0 ? targetId : _currentTeamId,
          teamName: targetName,
          clubId: _currentClubId,
          clubName: _currentClubName.isNotEmpty ? _currentClubName : targetName,
        ),
      ),
    );
  }

  void _onQuickAction(String key) async {
    if (key == 'Бронь') {
      final userId = await PrefUtils.getUserId();
      if (userId == null || !mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => BookingScreen(userId: userId)),
      );
    } else if (key == 'Видео') {
      _openReels();
    } else if (key == 'Видеоуроки') {
      _openVideoLessons();
    } else if (key == 'Расписание') {
      _openScheduleAll();
    } else if (key == 'Tracking') {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const TrackingModeScreen()),
      );
    } else if (key == 'Турниры') {
      _openEventsAll();
    } else if (key == 'Трансляции') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Трансляции скоро будут доступны')),
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

  void _openDrawer() {
    _scaffoldKey.currentState?.openDrawer();
  }

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = _adaptiveHorizontalPadding(context);
    final maxWidth = _contentMaxWidth(context);

    if (hasError) {
      return Scaffold(
        key: _scaffoldKey,
        backgroundColor: _homeDesign.backgroundColor,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
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
                    style: AppText.h3.copyWith(color: _homeDesign.textColor),
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
                        borderRadius: BorderRadius.circular(_homeDesign.smallRadius),
                      ),
                    ),
                    child: const Text('Повторить попытку'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: _homeDesign.backgroundColor,
      drawer: _CustomDrawer(
        design: _homeDesign,
        userName: _currentFullName,
        userRole: _currentRole,
        teamOrClubName: _getDashboardTargetName().trim().isNotEmpty
            ? _getDashboardTargetName().trim()
            : _currentFullName,
        teamLogoUrl: _currentTeamLogoUrl,
        onMenuItemTap: (route) {
          Navigator.pop(context);

          switch (route) {
            case 'home':
              break;
            case 'search':
              _openSearch();
              break;
            case 'tracking':
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TrackingModeScreen(),
                ),
              );
              break;
            case 'clubs':
              _openClubsAll();
              break;
            case 'venues':
              _openVenuesAll();
              break;
            case 'schedule':
              _openScheduleAll();
              break;
            case 'video_lessons':
              _openVideoLessons();
              break;
            case 'reels':
              _openReels();
              break;
            case 'events':
              _openEventsAll();
              break;
            case 'tickets':
              _openTicketsAll();
              break;
            case 'subscription':
              _openSubscription();
              break;
            case 'settings':
              _openHomeCustomizer();
              break;
            case 'help':
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GenericServiceScreen(
                    title: 'Помощь',
                    sport: selectedSport ?? 'Футбол',
                  ),
                ),
              );
              break;
          }
        },
      ),
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
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: _SportotekaHeaderDelegate(
                  collapsed: _collapsedHeader,
                  minExtentValue: _isPhoneLandscape(context) ? 58 : 65,
                  maxExtentValue: _isPhoneLandscape(context) ? 92 : 140,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxWidth),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          6,
                          horizontalPadding,
                          6,
                        ),
                        child: _buildCollapsibleHeader(context),
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        10,
                        horizontalPadding,
                        0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                  
                          _buildHomeHubSwitcher(context),
                          const SizedBox(height: 10),
                   AnimatedSwitcher(
  duration: const Duration(milliseconds: 220),
  child: isLoading
      ? _buildLoadingPlaceholder()
      : (_homeModeIndex == 0
          ? _buildToolsHubPage(context)
          : _homeModeIndex == 1
              ? _buildNewsHubPage(context)
              : _buildServicesHubPage(context)),
),
const SizedBox(height: 12),
if (!isLoading && _homeModeIndex == 0) ..._buildToolsSections(context),
if (!isLoading && _homeModeIndex == 1) ..._buildNewsSections(context),
if (!isLoading && _homeModeIndex == 2) ..._buildServicesSections(context),
       ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
Widget _buildPlayerHomeEntrySection(
  BuildContext context, {
  EdgeInsetsGeometry margin = const EdgeInsets.only(bottom: 12),
}) {
  final teamId = _currentTeamId;
  final teamName = _currentTeamName.trim().isNotEmpty
      ? _currentTeamName.trim()
      : 'Моя команда';

  return _buildHomeSectionShell(
    title: 'Кабинет игрока',
    rightText: 'player',
    margin: margin,
    child: InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlayerDashboardScreen(
              teamId: teamId > 0 ? teamId : 0,
              teamName: teamName,
              userId: _userId ?? 0,
              teamLogo: _currentTeamLogoUrl,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE7ECF2)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.person_outline_rounded,
                color: Color(0xFF2563EB),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    teamName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF0F172A),
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Перейти в личный кабинет, матчи, задания и игровую зону',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: Color(0xFF94A3B8),
            ),
          ],
        ),
      ),
    ),
  );
}  
  
  
Widget _buildWorkspaceCommandCenterSection(
  BuildContext context, {
  EdgeInsetsGeometry margin = const EdgeInsets.only(bottom: 12),
}) {
  final isClub = _isClubRole;
  final match = _getPrimaryWorkspaceMatch();
  final report = _getPrimaryWorkspaceReport();

  return _buildHomeSectionShell(
    title: isClub ? 'Клубный матч-центр' : 'Рабочий центр команды',
    rightText: isClub ? 'CMR' : 'live',
    margin: margin,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final wide = width >= 900;
        final huge = width >= 1180;

        if (isClub) {
          if (huge) {
            return SizedBox(
              height: 260,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 5, child: _buildUpcomingMatchesCard()),
                  const SizedBox(width: 10),
                  Expanded(flex: 5, child: _buildPastMatchesStatsCard()),
                  const SizedBox(width: 10),
                  Expanded(flex: 5, child: _buildClubBriefTtdCard(match, report)),
                ],
              ),
            );
          }

          if (wide) {
            return Column(
              children: [
                SizedBox(
                  height: 245,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _buildUpcomingMatchesCard()),
                      const SizedBox(width: 10),
                      Expanded(child: _buildPastMatchesStatsCard()),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _buildClubBriefTtdCard(match, report),
              ],
            );
          }

          return Column(
            children: [
              _buildUpcomingMatchesCard(),
              const SizedBox(height: 10),
              _buildPastMatchesStatsCard(),
              const SizedBox(height: 10),
              _buildClubBriefTtdCard(match, report),
            ],
          );
        }

        if (wide) {
          return Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildLastMatchTtdCard(match)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildRecentChatsCard()),
                ],
              ),
              const SizedBox(height: 10),
              _buildNextEventCard(report),
            ],
          );
        }

        return Column(
          children: [
            _buildLastMatchTtdCard(match),
            const SizedBox(height: 10),
            _buildRecentChatsCard(),
            const SizedBox(height: 10),
            _buildNextEventCard(report),
          ],
        );
      },
    ),
  );
}

List<Map<String, dynamic>> _getUpcomingClubMatches() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final list = _recentMatches.where((match) {
    final date = _matchDate(match);
    final status = _pickMapString(match, ['status', 'match_status', 'state']).toLowerCase();
    final finished = status.contains('finish') || status.contains('completed') || status.contains('played') || status.contains('заверш') || status.contains('сыгран');
    if (finished) return false;
    return date == null || !date.isBefore(today);
  }).map((e) => Map<String, dynamic>.from(e)).toList();

  list.sort((a, b) {
    final ad = _matchDate(a);
    final bd = _matchDate(b);
    if (ad == null && bd == null) return 0;
    if (ad == null) return 1;
    if (bd == null) return -1;
    return ad.compareTo(bd);
  });

  return list.take(4).toList();
}

List<Map<String, dynamic>> _getFinishedClubMatches() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final list = _recentMatches.where((match) {
    final date = _matchDate(match);
    final status = _pickMapString(match, ['status', 'match_status', 'state']).toLowerCase();
    final finished = status.contains('finish') || status.contains('completed') || status.contains('played') || status.contains('заверш') || status.contains('сыгран');
    return finished || (date != null && date.isBefore(today));
  }).map((e) => Map<String, dynamic>.from(e)).toList();

  list.sort((a, b) {
    final ad = _matchDate(a);
    final bd = _matchDate(b);
    if (ad == null && bd == null) return 0;
    if (ad == null) return 1;
    if (bd == null) return -1;
    return bd.compareTo(ad);
  });

  return list.take(4).toList();
}

DateTime? _matchDate(Map<String, dynamic> match) {
  return _extractDateFromMap(match, ['match_date', 'date', 'event_date', 'start_date', 'datetime', 'created_at']);
}

String _matchTeamsText(Map<String, dynamic> match) {
  final title = _pickMapString(match, ['title', 'match_title', 'name']);
  if (title.isNotEmpty) return title;

  final home = _pickMapString(match, ['home_team', 'team_home', 'team1', 'team_name']);
  final away = _pickMapString(match, ['away_team', 'team_away', 'team2', 'opponent']);
  if (home.isNotEmpty && away.isNotEmpty) return '$home — $away';
  if (away.isNotEmpty) return '${_currentClubName.isNotEmpty ? _currentClubName : 'Клуб'} — $away';
  return 'Матч клуба';
}

String _matchDateText(Map<String, dynamic> match) {
  final direct = _pickMapString(match, ['match_date', 'date', 'event_date', 'start_date', 'datetime']);
  return direct.isNotEmpty ? direct : 'Дата уточняется';
}

String _clubMatchScore(Map<String, dynamic> match) {
  return _pickMapString(match, ['score', 'result', 'match_score', 'full_time_score'], fallback: '—');
}

Widget _buildUpcomingMatchesCard() {
  final matches = _getUpcomingClubMatches();

  return _buildCommandCenterCard(
    title: 'Ближайшие матчи',
    icon: Icons.event_available_outlined,
    color: const Color(0xFF178A45),
    child: Column(
      children: [
        if (matches.isEmpty)
          _buildClubEmptyState('Ближайшие матчи пока не добавлены')
        else
          ...matches.asMap().entries.map((entry) {
            final index = entry.key;
            final match = entry.value;
            return Padding(
              padding: EdgeInsets.only(bottom: index == matches.length - 1 ? 0 : 8),
              child: _buildClubMatchRow(
                icon: Icons.sports_soccer_rounded,
                iconColor: const Color(0xFF178A45),
                title: _matchTeamsText(match),
                subtitle: _matchDateText(match),
                trailing: _pickMapString(match, ['place', 'location', 'stadium'], fallback: 'матч'),
              ),
            );
          }),
      ],
    ),
  );
}

Widget _buildPastMatchesStatsCard() {
  final matches = _getFinishedClubMatches();
  final wins = _extractMetricValue(_trackerSummary, ['wins', 'club_wins'], '—');
  final goals = _extractMetricValue(_trackerSummary, ['goals', 'club_goals', 'goals_for'], '—');
  final avgPossession = _extractMetricValue(_trackerSummary, ['avg_possession', 'possession', 'team_possession'], '—');

  return _buildCommandCenterCard(
    title: 'Пройденные матчи и статистика',
    icon: Icons.insights_outlined,
    color: const Color(0xFF0F766E),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _buildCenterSmallMetric(title: 'Матчи', value: '${matches.length}', color: const Color(0xFF0F766E))),
            const SizedBox(width: 8),
            Expanded(child: _buildCenterSmallMetric(title: 'Победы', value: wins, color: const Color(0xFF178A45))),
            const SizedBox(width: 8),
            Expanded(child: _buildCenterSmallMetric(title: 'Голы', value: goals, color: const Color(0xFF111827))),
          ],
        ),
        const SizedBox(height: 8),
        _buildMetricPill('Среднее владение', avgPossession),
        const SizedBox(height: 10),
        if (matches.isEmpty)
          _buildClubEmptyState('Сыгранные матчи пока не найдены')
        else
          ...matches.take(3).toList().asMap().entries.map((entry) {
            final index = entry.key;
            final match = entry.value;
            return Padding(
              padding: EdgeInsets.only(bottom: index == 2 ? 0 : 8),
              child: _buildClubMatchRow(
                icon: Icons.check_circle_outline_rounded,
                iconColor: const Color(0xFF0F766E),
                title: _matchTeamsText(match),
                subtitle: _matchDateText(match),
                trailing: _clubMatchScore(match),
              ),
            );
          }),
      ],
    ),
  );
}

Widget _buildClubBriefTtdCard(Map<String, dynamic> match, Map<String, dynamic> report) {
  final shots = _extractMetricValue(_trackerSummary, ['shots', 'team_shots', 'shots_total'], '—');
  final shotsOnGoal = _extractMetricValue(_trackerSummary, ['shots_on_goal', 'on_target'], '—');
  final passes = _extractMetricValue(_trackerSummary, ['passes', 'team_passes', 'passes_completed'], '—');
  final interceptions = _extractMetricValue(_trackerSummary, ['interceptions', 'team_interceptions'], '—');
  final possession = _extractMetricValue(_trackerSummary, ['possession', 'team_possession'], '—');
  final duels = _extractMetricValue(_trackerSummary, ['duels_won', 'duels', 'tackles'], '—');

  return _buildCommandCenterCard(
    title: 'Краткое ТТД по матчу',
    icon: Icons.analytics_outlined,
    color: const Color(0xFF178A45),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _matchMainText(match),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13.5, fontWeight: FontWeight.w900, height: 1.1),
        ),
        const SizedBox(height: 5),
        Text(
          _reportSubText(report).isNotEmpty ? _reportSubText(report) : 'Сводка по ключевым технико-тактическим действиям',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 10.8, fontWeight: FontWeight.w600, height: 1.25),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildMetricPill('Удары', shots),
            _buildMetricPill('В створ', shotsOnGoal),
            _buildMetricPill('Передачи', passes),
            _buildMetricPill('Перехваты', interceptions),
            _buildMetricPill('Владение', possession),
            _buildMetricPill('Единоборства', duels),
          ],
        ),
      ],
    ),
  );
}

Widget _buildClubMatchRow({required IconData icon, required Color iconColor, required String title, required String subtitle, required String trailing}) {
  return Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: const Color(0xFFFAFCFB), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE4EFE8))),
    child: Row(
      children: [
        Container(width: 34, height: 34, decoration: BoxDecoration(color: iconColor.withOpacity(0.10), borderRadius: BorderRadius.circular(11)), child: Icon(icon, color: iconColor, size: 17)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 11.6, fontWeight: FontWeight.w900)),
              const SizedBox(height: 3),
              Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF64748B), fontSize: 10.4, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          constraints: const BoxConstraints(maxWidth: 92),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(color: const Color(0xFFEAF5EE), borderRadius: BorderRadius.circular(999)),
          child: Text(trailing, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF178A45), fontSize: 10.2, fontWeight: FontWeight.w900)),
        ),
      ],
    ),
  );
}

Widget _buildClubEmptyState(String text) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: const Color(0xFFFAFCFB), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE4EFE8))),
    child: Text(text, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11.5, fontWeight: FontWeight.w600)),
  );
}

Widget _buildLastMatchTtdCard(Map<String, dynamic> match) {
  final title = _matchMainText(match);
  final subtitle = _matchSubText(match);
  final score = _matchValueText(match);

  final shots = _extractMetricValue(_trackerSummary, ['shots', 'team_shots'], '12');
  final passes = _extractMetricValue(_trackerSummary, ['passes', 'team_passes'], '320');
  final interceptions =
      _extractMetricValue(_trackerSummary, ['interceptions', 'team_interceptions'], '18');
  final possession =
      _extractMetricValue(_trackerSummary, ['possession', 'team_possession'], '58%');

  return _buildCommandCenterCard(
    title: 'ТТД последнего матча',
    icon: Icons.sports_soccer_rounded,
    color: const Color(0xFF2563EB),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 13.5,
            fontWeight: FontWeight.w900,
            height: 1.12,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              score,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildMetricPill('Удары', shots),
            _buildMetricPill('Передачи', passes),
            _buildMetricPill('Перехваты', interceptions),
            _buildMetricPill('Владение', possession),
          ],
        ),
        const SizedBox(height: 10),
        _buildMiniActionLink(
          label: 'Разбор матча',
          onTap: _openWorkspacePrimary,
        ),
      ],
    ),
  );
}



Widget _buildRecentChatsCard() {
  final chats = List<Map<String, dynamic>>.from(_recentChats.take(3));

  return _buildCommandCenterCard(
    title: 'Последние чаты',
    icon: Icons.forum_outlined,
    color: const Color(0xFF7C3AED),
    child: Column(
      children: [
        if (chats.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE7ECF2)),
            ),
            child: const Text(
              'Нет активных чатов',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        else
          ...chats.asMap().entries.map((entry) {
            final index = entry.key;
            final chat = entry.value;

            final chatId =
                int.tryParse('${chat['id'] ?? chat['chat_id'] ?? 0}') ?? 0;

            final chatName =
                (chat['title'] ?? chat['name'] ?? 'Чат').toString().trim();

            final lastMessage = (chat['last_message'] ??
                    chat['message'] ??
                    chat['last_text'] ??
                    'Нет сообщений')
                .toString()
                .trim();

            final unreadCount =
                int.tryParse('${chat['unread_count'] ?? 0}') ?? 0;

            final avatarUrl = _normalizeMediaUrl(
              (chat['avatar'] ??
                      chat['photo'] ??
                      chat['photo_url'] ??
                      chat['peer_photo'] ??
                      '')
                  .toString(),
            );

            return Padding(
              padding: EdgeInsets.only(bottom: index == chats.length - 1 ? 0 : 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  if (chatId <= 0) return;

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatRoomScreen(
                        chatId: chatId,
                        userId: _userId ?? 0,
                        chatName: chatName.isNotEmpty ? chatName : 'Чат',
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE7ECF2)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor:
                            const Color(0xFF7C3AED).withOpacity(0.12),
                        backgroundImage:
                            avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                        child: avatarUrl.isEmpty
                            ? Text(
                                chatName.isNotEmpty
                                    ? chatName[0].toUpperCase()
                                    : 'Ч',
                                style: const TextStyle(
                                  color: Color(0xFF7C3AED),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              chatName.isNotEmpty ? chatName : 'Чат',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              lastMessage.isNotEmpty
                                  ? lastMessage
                                  : 'Нет сообщений',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: Color(0xFF94A3B8),
                          ),
                          if (unreadCount > 0) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF7C3AED),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                unreadCount > 99 ? '99+' : '$unreadCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        const SizedBox(height: 10),
        _buildMiniActionLink(
          label: 'Открыть чаты',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatScreen(
                  userId: _userId ?? 0,
                ),
              ),
            );
          },
        ),
      ],
    ),
  );
}

Widget _buildMiniStatsCard() {
  final teamsCount = _isCoachRole
      ? (_myTeams.isNotEmpty ? _myTeams.length : (_currentTeamId > 0 ? 1 : 0))
      : _clubTeams.length;

  final matchesCount = _recentMatches.length;
  final reportsCount = _workspaceReports.length;
  final readiness = '${_trackerSummary['readiness'] ?? '79%'}';

  return _buildCommandCenterCard(
    title: 'Мини-статистика',
    icon: Icons.analytics_outlined,
    color: const Color(0xFFEA580C),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildCenterSmallMetric(
                title: _isClubRole ? 'Команды' : 'Мои команды',
                value: '$teamsCount',
                color: const Color(0xFF2563EB),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildCenterSmallMetric(
                title: 'Матчи',
                value: '$matchesCount',
                color: const Color(0xFFEA580C),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildCenterSmallMetric(
                title: 'Отчёты',
                value: '$reportsCount',
                color: const Color(0xFF7C3AED),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildCenterSmallMetric(
                title: 'Готовность',
                value: readiness,
                color: const Color(0xFF10B981),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

Widget _buildNextEventCard(Map<String, dynamic> report) {
  final nextTitle = _reportMainText(report);
  final nextSubtitle = _reportSubText(report);
  final nextValue = _reportValueText(report);

  return _buildCommandCenterCard(
    title: 'Ближайшая активность',
    icon: Icons.event_note_outlined,
    color: const Color(0xFF10B981),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE7ECF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            nextTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 13,
              fontWeight: FontWeight.w900,
              height: 1.12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            nextSubtitle.isEmpty ? 'Следите за ближайшими событиями команды' : nextSubtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            nextValue,
            style: const TextStyle(
              color: Color(0xFF10B981),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildQuickCoachActionsGrid(BuildContext context) {
  final actions = [
    {
      'title': 'Добавить игрока',
      'icon': Icons.person_add_alt_1_outlined,
      'color': const Color(0xFF2563EB),
      'onTap': () => _runWorkspaceModuleById('roster'),
    },
    {
      'title': 'Матчи',
      'icon': Icons.sports_soccer_outlined,
      'color': const Color(0xFFEA580C),
      'onTap': () => _runWorkspaceModuleById('matches'),
    },
    {
      'title': 'Видеоанализ',
      'icon': Icons.video_camera_back_outlined,
      'color': const Color(0xFFDC2626),
      'onTap': () => _runWorkspaceModuleById('videoanalysis'),
    },
    {
      'title': 'Создать тренировку',
      'icon': Icons.draw_outlined,
      'color': const Color(0xFF7C3AED),
      'onTap': () => _runWorkspaceModuleById('graphics'),
    },
  ];

  return LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      final columns = width >= 900
          ? 4
          : width >= 600
              ? 2
              : 2;
      const spacing = 8.0;
      final itemWidth = (width - spacing * (columns - 1)) / columns;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Быстрые действия',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: actions.map((item) {
              return SizedBox(
                width: itemWidth,
                child: InkWell(
                  onTap: item['onTap'] as VoidCallback,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE7ECF2)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: (item['color'] as Color).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            item['icon'] as IconData,
                            color: item['color'] as Color,
                            size: 17,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item['title'] as String,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      );
    },
  );
}

Widget _buildCommandCenterCard({
  required String title,
  required IconData icon,
  required Color color,
  required Widget child,
}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE4EFE8)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.02),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 17),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    ),
  );
}

Widget _buildMetricPill(String title, String value) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: const Color(0xFFE7ECF2)),
    ),
    child: RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$title: ',
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 10.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildMiniActionLink({
  required String label,
  required VoidCallback onTap,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(999),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: _homeDesign.primaryColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: _homeDesign.primaryColor,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 5),
          Icon(
            Icons.arrow_forward_rounded,
            size: 15,
            color: _homeDesign.primaryColor,
          ),
        ],
      ),
    ),
  );
}

Widget _buildCenterSmallMetric({
  required String title,
  required String value,
  required Color color,
}) {
  return Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFE7ECF2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

String _extractMetricValue(
  Map<String, dynamic> data,
  List<String> keys,
  String fallback,
) {
  for (final key in keys) {
    final value = data[key];
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty && text.toLowerCase() != 'null') {
      return text;
    }
  }
  return fallback;
}
  
Widget _buildNewsHubPage(BuildContext context) {
  final posts = _userPostsCache[selectedSport ?? 'Футбол'] ?? [];

  if (posts.isEmpty) {
    return _buildEmptyPlaceholder(
      icon: Icons.newspaper_rounded,
      text: 'Пока нет новостей для этой категории спорта',
    );
  }

  final featured = posts.first;
  final secondary = posts.length > 1 ? posts[1] : null;
  final others = posts.skip(_isTablet(context) ? 2 : 1).take(_isTablet(context) ? 4 : 3).toList();

  return Container(
    decoration: BoxDecoration(
      color: _homeDesign.cardColor,
      borderRadius: BorderRadius.circular(_homeDesign.cardRadius),
      border: Border.all(color: _homeDesign.borderColor),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(_homeDesign.shadowOpacity),
          blurRadius: _homeDesign.shadowBlur,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _homeDesign.primaryColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.newspaper_rounded,
                  color: _homeDesign.primaryColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Главные новости',
                      style: TextStyle(
                        fontSize: _homeDesign.sectionTitleSize,
                        fontWeight: FontWeight.w900,
                        color: _homeDesign.textColor,
                      ),
                    ),
                    Text(
                      'Свежие публикации и материалы сообщества',
                      style: TextStyle(
                        fontSize: _homeDesign.sectionSubtitleSize - 1,
                        color: _homeDesign.mutedTextColor,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SportCommunityScreen(
                        sportName: selectedSport ?? 'Футбол',
                      ),
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: Text(
                  'Все',
                  style: TextStyle(
                    color: _homeDesign.primaryColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isTablet(context))
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 6,
                  child: Column(
                    children: [
                      _buildFeaturedNewsCard(
                        featured,
                        _postsConfig,
                        customImageHeight: 220,
                        customTextLines: 3,
                      ),
                      if (secondary != null) ...[
                        const SizedBox(height: 10),
                        _buildCompactNewsRow(
                          secondary,
                          _postsConfig,
                          forceExpanded: true,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 4,
                  child: Column(
                    children: others
                        .map(
                          (post) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _buildCompactNewsRow(post, _postsConfig),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            )
          else
            Column(
              children: [
                _buildFeaturedNewsCard(
                  featured,
                  _postsConfig,
                  customImageHeight: 190,
                  customTextLines: 3,
                ),
                if (secondary != null) ...[
                  const SizedBox(height: 10),
                  _buildCompactNewsRow(
                    secondary,
                    _postsConfig,
                    forceExpanded: true,
                  ),
                ],
                if (others.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ...others.map(
                    (post) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildCompactNewsRow(post, _postsConfig),
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    ),
  );
}

Widget _buildServicesHubPage(BuildContext context) {
  final venues = List<dynamic>.from(dataCache['venues'] ?? []);
  final teams = List<Map<String, dynamic>>.from(dataCache['teams'] ?? []);

  return Container(
    decoration: BoxDecoration(
      color: _homeDesign.cardColor,
      borderRadius: BorderRadius.circular(_homeDesign.cardRadius),
      border: Border.all(color: _homeDesign.borderColor),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(_homeDesign.shadowOpacity),
          blurRadius: _homeDesign.shadowBlur,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Сервисы',
            style: TextStyle(
              fontSize: _homeDesign.sectionTitleSize,
              fontWeight: FontWeight.w900,
              color: _homeDesign.textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Площадки, клубы и билеты',
            style: TextStyle(
              fontSize: _homeDesign.sectionSubtitleSize - 1,
              color: _homeDesign.mutedTextColor,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildServicesMiniCard(
                  title: 'Площадки',
                  value: '${venues.length}',
                  icon: Icons.location_on_outlined,
                  color: const Color(0xFF0891B2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildServicesMiniCard(
                  title: 'Клубы',
                  value: '${teams.length}',
                  icon: Icons.groups_2_outlined,
                  color: const Color(0xFF2563EB),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildServicesMiniCard(
            title: 'Билеты',
            value: '${_ticketsData.length}',
            icon: Icons.confirmation_number_outlined,
            color: const Color(0xFFEA580C),
          ),
        ],
      ),
    ),
  );
}

Widget _buildServicesMiniCard({
  required String title,
  required String value,
  required IconData icon,
  required Color color,
}) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE7ECF2)),
    ),
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

List<Widget> _buildServicesSections(BuildContext context) {
  final sections = <Widget>[];

  final venues = List<dynamic>.from(dataCache['venues'] ?? []);
  final teams = List<Map<String, dynamic>>.from(dataCache['teams'] ?? []);

  for (final config in _homeDesign.sections.where((s) => s.visible)) {
    Widget? builtSection;

    switch (config.type) {
      case HomeSectionType.venues:
        if (venues.isNotEmpty) {
          builtSection = _buildVenuesSection(config, venues, context);
        }
        break;

      case HomeSectionType.clubs:
        if (teams.isNotEmpty) {
          builtSection = _buildClubsSection(config, teams, context);
        }
        break;

      case HomeSectionType.tickets:
        builtSection = _buildTicketsSection(config, _ticketsData, context);
        break;

      default:
        builtSection = null;
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

Widget _buildWorkspaceHeroSection(
  BuildContext context, {
  EdgeInsetsGeometry margin = const EdgeInsets.only(bottom: 12),
}) {
  final targetName = _getDashboardTargetName().trim().isNotEmpty
      ? _getDashboardTargetName().trim()
      : _currentFullName;

  final trackerConnected = _isTrackerConnectedNow();

  return Container(
    margin: margin,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFFE5E7EB)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildWorkspaceWhiteHeader(
          context,
          title: _isClubRole
              ? 'Панель клуба'
              : _isCoachRole
                  ? 'Панель тренера'
                  : _isPlayerRole
                      ? 'Панель игрока'
                      : _isParentRole
                          ? 'Панель родителя'
                          : 'Рабочая панель',
          targetName: targetName,
          trackerConnected: trackerConnected,
        ),
        const SizedBox(height: 12),
        if (_isClubRole) ...[
          _buildClubHeroStatsRow(),
          const SizedBox(height: 14),
          _buildClubCmrAndOverviewRow(context),
        ] else ...[
          LayoutBuilder(
            builder: (context, constraints) {
              final cards = _buildWorkspaceHeroStats();
              final width = constraints.maxWidth;
              final columns = width >= 760 ? 3 : 2;
              final spacing = 10.0;
              final itemWidth = (width - spacing * (columns - 1)) / columns;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: cards.map((item) {
                  return SizedBox(
                    width: itemWidth,
                    child: _buildOverviewMiniCardHome(
                      title: item['title'] as String,
                      value: item['value'] as String,
                      icon: item['icon'] as IconData,
                      color: item['color'] as Color,
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 12),
          _buildWorkspacePrimaryButton(context),
        ],
      ],
    ),
  );
}

Widget _buildClubHeroStatsRow() {
  final stats = [
    {
      'title': 'Команды',
      'value': '${_clubTeams.length}',
      'icon': Icons.groups_2_outlined,
      'color': const Color(0xFF2563EB),
    },
    {
      'title': 'Тренеры',
      'value': '${_clubTrainers.length}',
      'icon': Icons.people_outline_rounded,
      'color': const Color(0xFF00A750),
    },
    {
      'title': 'События',
      'value': '${_clubEvents.length}',
      'icon': Icons.calendar_month_outlined,
      'color': const Color(0xFFEA580C),
    },
  ];

  return LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 760;
      if (!wide) {
        return Column(
          children: stats.asMap().entries.map((entry) {
            return Padding(
              padding: EdgeInsets.only(bottom: entry.key == stats.length - 1 ? 0 : 10),
              child: _buildOverviewMiniCardHome(
                title: entry.value['title'] as String,
                value: entry.value['value'] as String,
                icon: entry.value['icon'] as IconData,
                color: entry.value['color'] as Color,
              ),
            );
          }).toList(),
        );
      }

      return Row(
        children: stats.asMap().entries.map((entry) {
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: entry.key == 0 ? 0 : 12),
              child: _buildOverviewMiniCardHome(
                title: entry.value['title'] as String,
                value: entry.value['value'] as String,
                icon: entry.value['icon'] as IconData,
                color: entry.value['color'] as Color,
              ),
            ),
          );
        }).toList(),
      );
    },
  );
}

Widget _buildClubCmrAndOverviewRow(BuildContext context) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 860;
      if (!wide) {
        return Column(
          children: [
            _buildClubCmrEntryCard(context),
            const SizedBox(height: 12),
            _buildClubOverviewInlineCard(),
          ],
        );
      }

      return SizedBox(
        height: 210,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 7,
              child: _buildClubCmrEntryCard(context),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 5,
              child: _buildClubOverviewInlineCard(),
            ),
          ],
        ),
      );
    },
  );
}

Widget _buildClubCmrEntryCard(BuildContext context) {
  final matchesCount = _recentMatches.length;
  final chatsCount = _recentChats.length;
  final reportsCount = _workspaceReports.length;

  return InkWell(
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ClubWorkspaceScreen()),
      );
    },
    borderRadius: BorderRadius.circular(22),
    child: Container(
      constraints: const BoxConstraints(minHeight: 132),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE8F8EF), Color(0xFFF7FFFA)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Color(0xFF9BE7BD)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00A750).withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: const Color(0xFFCFF4DF),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF00A750).withOpacity(.16)),
            ),
            child: const Icon(
              Icons.dashboard_customize_outlined,
              color: Color(0xFF00A750),
              size: 27,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Панель клуба CMR',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Матчи, составы, календарь, чаты, ТТД и аналитика клуба в одном рабочем экране.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xFF4B6475),
                    fontSize: 11.8,
                    fontWeight: FontWeight.w700,
                    height: 1.22,
                  ),
                ),
                const SizedBox(height: 11),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildCmrEntryPill('Матчи', '$matchesCount'),
                    _buildCmrEntryPill('Чаты', '$chatsCount'),
                    _buildCmrEntryPill('Отчёты', '$reportsCount'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            decoration: BoxDecoration(
              color: const Color(0xFF00A750),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00A750).withOpacity(.20),
                  blurRadius: 14,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Открыть',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(width: 7),
                Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildCmrEntryPill(String title, String value) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(.82),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: const Color(0xFFD8EFE2)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF00A750),
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

Widget _buildWorkspacePrimaryButton(BuildContext context) {
  return InkWell(
    onTap: _openWorkspacePrimary,
    borderRadius: BorderRadius.circular(18),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_homeDesign.primaryColor.withOpacity(0.12), _homeDesign.primaryColor.withOpacity(0.06)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _homeDesign.primaryColor.withOpacity(0.22)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: _homeDesign.primaryColor.withOpacity(0.14), borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.dashboard_customize_outlined, color: _homeDesign.primaryColor, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Подробная панель', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _homeDesign.textColor, fontSize: 13.5, fontWeight: FontWeight.w900, height: 1.0)),
                const SizedBox(height: 4),
                const Text('Открыть полный экран управления', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Color(0xFF64748B), fontSize: 10.5, fontWeight: FontWeight.w600, height: 1.0)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.arrow_forward_rounded, color: _homeDesign.primaryColor, size: 20),
        ],
      ),
    ),
  );
}

Widget _buildClubOverviewInlineCard() {
  int pct(int current, int target) {
    if (target <= 0) return 0;
    final value = ((current / target) * 100).round();
    return value.clamp(0, 100);
  }

  final structurePct = pct(_clubTeams.length, 8);
  final staffPct = pct(_clubTrainers.length, 4);
  final calendarPct = pct(_clubEvents.length, 6);
  final reportsPct = pct(_workspaceReports.length, 6);

  String statusText() {
    final avg = ((structurePct + staffPct + calendarPct + reportsPct) / 4).round();
    if (avg >= 75) return 'система заполнена хорошо';
    if (avg >= 45) return 'нужно немного данных';
    return 'нужно заполнить CMR';
  }

  final hints = <String>[
    if (_clubTrainers.isEmpty) 'Добавьте тренеров к командам',
    if (_clubEvents.isEmpty) 'Запланируйте события в календаре',
    if (_workspaceReports.isEmpty) 'Добавьте отчёты после матчей',
    if (_clubPlans.isEmpty) 'Создайте базу планов-конспектов',
  ];

  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFFBFCFB),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE4EFE8)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'CMR-готовность клуба',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _homeDesign.textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: _homeDesign.primaryColor.withOpacity(.10),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                statusText(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _homeDesign.primaryColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildCmrReadinessLine(title: 'Структура команд', value: structurePct, icon: Icons.account_tree_outlined),
        const SizedBox(height: 8),
        _buildCmrReadinessLine(title: 'Тренерский штаб', value: staffPct, icon: Icons.manage_accounts_outlined),
        const SizedBox(height: 8),
        _buildCmrReadinessLine(title: 'Календарь клуба', value: calendarPct, icon: Icons.event_note_outlined),
        const SizedBox(height: 8),
        _buildCmrReadinessLine(title: 'Матчевые отчёты', value: reportsPct, icon: Icons.analytics_outlined),
        const SizedBox(height: 12),
        Expanded(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: const Color(0xFFE4EFE8)),
            ),
            child: Row(
              children: [
                Icon(Icons.tips_and_updates_outlined, color: _homeDesign.primaryColor, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hints.isEmpty ? 'Клубная карточка выглядит готовой для работы' : hints.take(2).join(' • '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF475569),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                    ),
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

Widget _buildCmrReadinessLine({
  required String title,
  required int value,
  required IconData icon,
}) {
  final safeValue = value.clamp(0, 100);

  return Row(
    children: [
      Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: _homeDesign.primaryColor.withOpacity(.10),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, color: _homeDesign.primaryColor, size: 16),
      ),
      const SizedBox(width: 9),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF334155),
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Text(
                  '$safeValue%',
                  style: TextStyle(
                    color: _homeDesign.primaryColor,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: safeValue / 100,
                minHeight: 6,
                backgroundColor: const Color(0xFFEFF4F1),
                valueColor: AlwaysStoppedAnimation<Color>(_homeDesign.primaryColor),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
Widget _buildClubPulseRow({
  required IconData icon,
  required String title,
  required String value,
  required String meta,
  required Color color,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: const Color(0xFFE4EFE8)),
    ),
    child: Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withOpacity(.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          meta,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

Widget _buildClubPulseMini({
  required IconData icon,
  required String title,
  required String value,
  required Color color,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: const Color(0xFFE4EFE8)),
    ),
    child: Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color.withOpacity(.12),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

void _openSelectedWorkspaceTeam() {
  final teamId = _selectedWorkspaceTeamId ?? _currentTeamId;
  final teamName = _selectedWorkspaceTeamName.isNotEmpty
      ? _selectedWorkspaceTeamName
      : (_currentTeamName.isNotEmpty
          ? _currentTeamName
          : _getDashboardTargetName());

  if (teamId <= 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Команда не выбрана')),
    );
    return;
  }

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => TeamDashboardScreen(
        teamId: teamId,
        teamName: teamName,
        clubId: _currentClubId,
        clubName: _currentClubName.isNotEmpty
            ? _currentClubName
            : _getDashboardTargetName(),
      ),
    ),
  );
}

List<Map<String, dynamic>> _buildWorkspaceHeroStats() {
  if (_isClubRole) {
    return [
      {
        'title': 'Команды',
        'value': '${_clubTeams.length}',
        'icon': Icons.groups_2_outlined,
        'color': const Color(0xFF2563EB),
      },
      {
        'title': 'Тренеры',
        'value': '${_clubTrainers.length}',
        'icon': Icons.people_outline,
        'color': const Color(0xFF10B981),
      },
      {
        'title': 'События',
        'value': '${_clubEvents.length}',
        'icon': Icons.calendar_month_outlined,
        'color': const Color(0xFFEA580C),
      },
    ];
  }

  return [
    {
      'title': 'Команды',
      'value': _isCoachRole
          ? '${_myTeams.isNotEmpty ? _myTeams.length : (_currentTeamId > 0 ? 1 : 0)}'
          : '${_clubTeams.length}',
      'icon': Icons.groups_2_outlined,
      'color': const Color(0xFF2563EB),
    },
    {
      'title': 'Матчи',
      'value': '${_recentMatches.length}',
      'icon': Icons.sports_soccer_outlined,
      'color': const Color(0xFFEA580C),
    },
    {
      'title': 'Отчёты',
      'value': '${_workspaceReports.length}',
      'icon': Icons.analytics_outlined,
      'color': const Color(0xFF7C3AED),
    },
  ];
}

Widget _buildHeroPill({
  required String label,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.12),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: Colors.white.withOpacity(0.10)),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

Widget _buildHeroStatCardHome({
  required String title,
  required String value,
  required IconData icon,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.12),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Colors.white.withOpacity(0.10)),
    ),
    child: Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.18),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 17),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.82),
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
  
    Widget _buildTrackingHero() {
    const bool isTrackerConnected = false;

    return TrackingHeroWidget(
      design: _homeDesign,
      isConnected: isTrackerConnected,
      onOpenTracking: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const TrackingModeScreen(),
          ),
        );
      },
    );
  }

  Widget _buildCollapsibleHeader(BuildContext context) {
    final compact = _collapsedHeader && !_isTablet(context);
    final logoUrl = _currentTeamLogoUrl.trim();
    final targetName = _getDashboardTargetName().trim();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
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
            color: Colors.black.withOpacity(0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: _isTablet(context) ? 14 : 12,
          vertical: compact ? 8 : 10,
        ),
        child: Row(
          children: [
            _headerActionButton(
              icon: Icons.menu_rounded,
              onTap: _openDrawer,
            ),
            const SizedBox(width: 10),
            _buildHeaderBrandLogo(
              logoUrl: logoUrl,
              compact: compact,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Спортотека',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: _responsiveFont(
                        context,
                        mobile: compact ? 17 : 18,
                        tablet: compact ? 18 : 19,
                        landscapeDelta: -0.2,
                      ),
                      letterSpacing: -0.45,
                      height: 1.05,
                    ),
                  ),
                  if (!compact) ...[
                    const SizedBox(height: 2),
                    Text(
                      targetName.isNotEmpty
                          ? targetName
                          : 'Вместе к победам!',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.86),
                        fontSize: _responsiveFont(
                          context,
                          mobile: 10.5,
                          tablet: 11.5,
                          landscapeDelta: -0.2,
                        ),
                        fontWeight: FontWeight.w600,
                        height: 1.15,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!_isPhoneLandscape(context)) ...[
              _headerInfoPill(
                icon: Icons.sports_soccer_rounded,
                text: selectedSport ?? 'Футбол',
              ),
              const SizedBox(width: 6),
            ],
            _headerActionButton(
              icon: Icons.search_rounded,
              onTap: _openSearch,
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerActionButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.14),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.12),
          ),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }

  Widget _headerInfoPill({
    required IconData icon,
    required String text,
  }) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 130),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withOpacity(0.10),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: Colors.white,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: _responsiveFont(
                  context,
                  mobile: 10.5,
                  tablet: 11.2,
                  landscapeDelta: -0.2,
                ),
                fontWeight: FontWeight.w800,
                height: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBrandLogo({
    required String logoUrl,
    required bool compact,
  }) {
    final size = compact ? 34.0 : 36.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.hardEdge,
      child: logoUrl.isNotEmpty
          ? Image.network(
              logoUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.sports_soccer_rounded,
                color: Color(0xFF00A750),
                size: 20,
              ),
            )
          : const Icon(
              Icons.sports_soccer_rounded,
              color: Color(0xFF00A750),
              size: 20,
            ),
    );
  }

  Widget _buildHomeHubSwitcher(BuildContext context) {
  String title;
  String subtitle;
  IconData icon;

  switch (_homeModeIndex) {
    case 1:
      title = 'Новости';
      subtitle = 'Лента сообщества';
      icon = Icons.newspaper_rounded;
      break;
    case 2:
      title = 'Сервисы';
      subtitle = 'Площадки, клубы, билеты';
      icon = Icons.dashboard_outlined;
      break;
    default:
      title = 'Обзор';
      subtitle = 'Рабочая панель и модули';
      icon = Icons.dashboard_customize_rounded;
  }

  return Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: _homeDesign.cardColor,
      borderRadius: BorderRadius.circular(_homeDesign.cardRadius),
      border: Border.all(color: _homeDesign.borderColor),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(_homeDesign.shadowOpacity),
          blurRadius: _homeDesign.shadowBlur,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: _homeDesign.primaryColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: _homeDesign.primaryColor,
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: _homeDesign.sectionTitleSize,
                      fontWeight: FontWeight.w900,
                      color: _homeDesign.textColor,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: _homeDesign.sectionSubtitleSize - 1,
                      color: _homeDesign.mutedTextColor,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: _homeDesign.backgroundColor,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildHubModeChip(
                  index: 0,
                  title: 'Обзор',
                  icon: Icons.widgets_rounded,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _buildHubModeChip(
                  index: 1,
                  title: 'Новости',
                  icon: Icons.forum_rounded,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _buildHubModeChip(
                  index: 2,
                  title: 'Сервисы',
                  icon: Icons.grid_view_rounded,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
  }

 Widget _buildHubModeChip({
  required int index,
  required String title,
  required IconData icon,
}) {
  final active = index == _homeModeIndex;

  return GestureDetector(
    onTap: () {
      if (!mounted) return;
      setState(() {
        _homeModeIndex = index;
      });
    },
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: active ? _homeDesign.primaryColor : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 13,
            color: active ? Colors.white : _homeDesign.mutedTextColor,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: active ? Colors.white : _homeDesign.textColor,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildToolsHubPage(BuildContext context) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.maxWidth;
      return SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: _buildResponsiveToolsHubContent(context, width),
        ),
      );
    },
  );
}


List<Widget> _buildResponsiveToolsHubContent(BuildContext context, double width) {
  final isHugeTablet = width >= 1360;
  final isWideTablet = width >= 1040;
  final isTablet = width >= 760;

  if (_isClubRole) {
    if (isHugeTablet || isWideTablet) {
      return [
        _buildWorkspaceHeroSection(
          context,
          margin: const EdgeInsets.fromLTRB(0, 0, 0, 12),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 8,
              child: Column(
                children: [
                  _buildWorkspaceCommandCenterSection(
                    context,
                    margin: const EdgeInsets.only(bottom: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 4,
              child: Column(
                children: [
                  _buildWorkspaceActivitySection(
                    context,
                    margin: const EdgeInsets.only(bottom: 12),
                  ),
                  _buildWorkspaceRecentChatsSection(
                    context,
                    margin: const EdgeInsets.only(bottom: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ];
    }

    if (isTablet) {
      return [
        _buildWorkspaceHeroSection(
          context,
          margin: const EdgeInsets.fromLTRB(0, 0, 0, 12),
        ),
        _buildWorkspaceCommandCenterSection(
          context,
          margin: const EdgeInsets.only(bottom: 12),
        ),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _buildWorkspaceActivitySection(
                  context,
                  margin: const EdgeInsets.only(bottom: 12),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildWorkspaceRecentChatsSection(
                  context,
                  margin: const EdgeInsets.only(bottom: 12),
                ),
              ),
            ],
          ),
        ),
      ];
    }

    return [
      _buildWorkspaceHeroSection(
        context,
        margin: const EdgeInsets.fromLTRB(0, 0, 0, 12),
      ),
      _buildWorkspaceCommandCenterSection(
        context,
        margin: const EdgeInsets.only(bottom: 12),
      ),
      _buildWorkspaceActivitySection(
        context,
        margin: const EdgeInsets.only(bottom: 12),
      ),
      _buildWorkspaceRecentChatsSection(
        context,
        margin: const EdgeInsets.only(bottom: 12),
      ),
    ];
  }

  if (_isPlayerLikeRole) {
    return [
      _buildWorkspaceHeroSection(
        context,
        margin: const EdgeInsets.fromLTRB(0, 0, 0, 12),
      ),
      _buildPlayerHomeEntrySection(
        context,
        margin: const EdgeInsets.only(bottom: 12),
      ),
      _buildWorkspaceOverviewSection(
        context,
        margin: const EdgeInsets.only(bottom: 12),
      ),
    ];
  }

  if (isHugeTablet) {
    return [
      _buildWorkspaceHeroSection(
        context,
        margin: const EdgeInsets.fromLTRB(0, 0, 0, 12),
      ),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 8,
            child: Column(
              children: [
                _buildWorkspaceTeamPickerSection(
                  context,
                  margin: const EdgeInsets.only(bottom: 12),
                ),
                _buildCoachQuickModesSection(
                  context,
                  margin: const EdgeInsets.only(bottom: 12),
                ),
                _buildWorkspaceOverviewSection(
                  context,
                  margin: const EdgeInsets.only(bottom: 12),
                ),
                _buildWorkspaceCommandCenterSection(
                  context,
                  margin: const EdgeInsets.only(bottom: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 4,
            child: Column(
              children: [
                _buildWorkspaceActivitySection(
                  context,
                  margin: const EdgeInsets.only(bottom: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    ];
  }

  if (isWideTablet) {
    return [
      _buildWorkspaceHeroSection(
        context,
        margin: const EdgeInsets.fromLTRB(0, 0, 0, 12),
      ),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 7,
            child: Column(
              children: [
                _buildWorkspaceTeamPickerSection(
                  context,
                  margin: const EdgeInsets.only(bottom: 12),
                ),
                _buildCoachQuickModesSection(
                  context,
                  margin: const EdgeInsets.only(bottom: 12),
                ),
                _buildWorkspaceCommandCenterSection(
                  context,
                  margin: const EdgeInsets.only(bottom: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 4,
            child: IntrinsicHeight(
              child: Column(
                children: [
                  _buildWorkspaceOverviewSection(
                    context,
                    margin: const EdgeInsets.only(bottom: 12),
                  ),
                  _buildWorkspaceActivitySection(
                    context,
                    margin: const EdgeInsets.only(bottom: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ];
  }

  if (isTablet) {
    return [
      _buildWorkspaceHeroSection(
        context,
        margin: const EdgeInsets.fromLTRB(0, 0, 0, 12),
      ),
      _buildWorkspaceTeamPickerSection(
        context,
        margin: const EdgeInsets.only(bottom: 12),
      ),
      _buildCoachQuickModesSection(
        context,
        margin: const EdgeInsets.only(bottom: 12),
      ),
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _buildWorkspaceOverviewSection(
                context,
                margin: const EdgeInsets.only(bottom: 12),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildWorkspaceActivitySection(
                context,
                margin: const EdgeInsets.only(bottom: 12),
              ),
            ),
          ],
        ),
      ),
      _buildWorkspaceCommandCenterSection(
        context,
        margin: const EdgeInsets.only(bottom: 12),
      ),
    ];
  }

  return [
    _buildWorkspaceHeroSection(
      context,
      margin: const EdgeInsets.fromLTRB(0, 0, 0, 12),
    ),
    _buildWorkspaceTeamPickerSection(
      context,
      margin: const EdgeInsets.only(bottom: 12),
    ),
    _buildCoachQuickModesSection(
      context,
      margin: const EdgeInsets.only(bottom: 12),
    ),
    _buildWorkspaceOverviewSection(
      context,
      margin: const EdgeInsets.only(bottom: 12),
    ),
    _buildWorkspaceCommandCenterSection(
      context,
      margin: const EdgeInsets.only(bottom: 12),
    ),
    _buildWorkspaceActivitySection(
      context,
      margin: const EdgeInsets.only(bottom: 12),
    ),
  ];
}


Widget _buildHomeSectionShell({
  required String title,
  String? rightText,
  required Widget child,
  EdgeInsetsGeometry margin = const EdgeInsets.only(bottom: 12),
}) {
  return Container(
    margin: margin,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: _homeDesign.cardColor,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xFFE5E7EB)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
            if ((rightText ?? '').trim().isNotEmpty)
              Text(
                rightText!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}

Widget _buildCoachQuickModesSection(
  BuildContext context, {
  EdgeInsetsGeometry margin = const EdgeInsets.only(bottom: 12),
}) {
  if (_isClubRole) return const SizedBox.shrink();

  final actions = [
    {
      "title": "Состав",
      "subtitle": "Игроки и профили",
      "icon": Icons.groups_2_outlined,
      "color": const Color(0xFF2563EB),
      "onTap": () => _runWorkspaceModuleById("roster"),
    },
    {
      "title": "Календарь",
      "subtitle": "Матчи и тренировки",
      "icon": Icons.calendar_month_outlined,
      "color": const Color(0xFF16A34A),
      "onTap": () => _runWorkspaceModuleById("calendar"),
    },
    {
      "title": "Посещаемость",
      "subtitle": "Журнал команды",
      "icon": Icons.fact_check_outlined,
      "color": const Color(0xFF0891B2),
      "onTap": () => _runWorkspaceModuleById("attendance"),
    },
    {
      "title": "Матчи",
      "subtitle": "Результаты и список",
      "icon": Icons.sports_soccer_outlined,
      "color": const Color(0xFFEA580C),
      "onTap": () => _runWorkspaceModuleById("matches"),
    },
    {
      "title": "Видеоанализ",
      "subtitle": "Разбор матчей",
      "icon": Icons.video_camera_back_outlined,
      "color": const Color(0xFFDC2626),
      "onTap": () => _runWorkspaceModuleById("videoanalysis"),
    },
    {
      "title": "Планы",
      "subtitle": "Конспекты и база",
      "icon": Icons.menu_book_outlined,
      "color": const Color(0xFF7C3AED),
      "onTap": () => _runWorkspaceModuleById("plans"),
    },
    {
      "title": "Графика",
      "subtitle": "Построение тренировок",
      "icon": Icons.draw_outlined,
      "color": const Color(0xFFE11D48),
      "onTap": () => _runWorkspaceModuleById("graphics"),
    },
    {
      "title": "Менеджер",
      "subtitle": "Тактика и симуляция",
      "icon": Icons.psychology_alt_outlined,
      "color": const Color(0xFF0F766E),
      "onTap": () => _runWorkspaceModuleById("manager_mode"),
    },
  ];

  return _buildHomeSectionShell(
    title: 'Рабочие режимы',
    rightText: 'быстрый доступ',
    margin: margin,
    child: _HomeQuickActionsGrid(actions: actions),
  );
}

Widget _buildWorkspaceTeamPickerSection(
  BuildContext context, {
  EdgeInsetsGeometry margin = const EdgeInsets.only(bottom: 12),
}) {
  // Для роли клуба не показываем выбор \"рабочей команды\":
  // главная CMR-сводка собирается по всем командам, событиям и матчам клуба.
  if (_isClubRole) {
    return const SizedBox.shrink();
  }

  final source = _isCoachRole
      ? (_myTeams.isNotEmpty ? _myTeams : _clubTeams)
      : _clubTeams;

  if (!_isCoachRole || source.isEmpty) {
    return const SizedBox.shrink();
  }

  final currentTeamName = _selectedWorkspaceTeamName.isNotEmpty
      ? _selectedWorkspaceTeamName
      : (_currentTeamName.isNotEmpty ? _currentTeamName : 'Команда не выбрана');

  return _buildHomeSectionShell(
    title: 'Рабочая команда',
    rightText: '${source.length}',
    margin: margin,
    child: Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE7ECF2)),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF2FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: Color(0xFF2563EB),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Выбрана команда',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      currentTeamName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildTeamPickerActionChip(
              icon: Icons.swap_horiz_rounded,
              label: 'Сменить',
              filled: false,
              onTap: () => _pickWorkspaceTeam(context, source),
            ),
            _buildTeamPickerActionChip(
  icon: Icons.open_in_new_rounded,
  label: 'Открыть',
  filled: true,
  onTap: _openSelectedWorkspaceTeam,
),          ],
        ),
      ],
    ),
  );
}
Widget _buildTeamPickerActionChip({
  required IconData icon,
  required String label,
  required bool filled,
  required VoidCallback onTap,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(999),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: filled ? _homeDesign.primaryColor : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: filled ? _homeDesign.primaryColor : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: filled ? Colors.white : const Color(0xFF0F172A),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: filled ? Colors.white : const Color(0xFF0F172A),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ),
  );
}


Future<void> _pickWorkspaceTeam(
  BuildContext context,
  List<Map<String, dynamic>> source,
) async {
  final picked = await showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) {
      return SafeArea(
        top: false,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 14),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Выбор команды',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  itemCount: source.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = source[index];
                    final id =
                        int.tryParse('${item['id'] ?? item['team_id'] ?? 0}') ?? 0;
                    final name =
                        (item['name'] ?? item['team_name'] ?? 'Команда').toString();

                    final selected = _selectedWorkspaceTeamId == id ||
                        (_selectedWorkspaceTeamId == null &&
                            _selectedWorkspaceTeamName == name);

                    return InkWell(
                      onTap: () => Navigator.pop(
                        context,
                        {'id': id, 'name': name},
                      ),
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: selected
                              ? _homeDesign.primaryColor.withOpacity(0.08)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: selected
                                ? _homeDesign.primaryColor.withOpacity(0.35)
                                : const Color(0xFFE5E7EB),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: selected
                                    ? _homeDesign.primaryColor.withOpacity(0.14)
                                    : const Color(0xFFEAF2FF),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.shield_outlined,
                                color: selected
                                    ? _homeDesign.primaryColor
                                    : const Color(0xFF2563EB),
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF0F172A),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  height: 1.1,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              selected
                                  ? Icons.check_circle_rounded
                                  : Icons.chevron_right_rounded,
                              color: selected
                                  ? _homeDesign.primaryColor
                                  : const Color(0xFF94A3B8),
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  if (picked != null && mounted) {
    setState(() {
      _selectedWorkspaceTeamId = picked['id'] as int?;
      _selectedWorkspaceTeamName = (picked['name'] ?? '').toString();
    });
  }
}

Widget _buildWorkspaceOverviewSection(
  BuildContext context, {
  EdgeInsetsGeometry margin = const EdgeInsets.only(bottom: 12),
}) {
  return _buildHomeSectionShell(
    title: 'Обзор',
    rightText: 'live',
    margin: margin,
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildOverviewMiniCardHome(
                title: 'Клуб',
                value: _currentClubName.isNotEmpty ? _currentClubName : 'Не указан',
                icon: Icons.shield_outlined,
                color: const Color(0xFF2563EB),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildOverviewMiniCardHome(
                title: 'Роль',
                value: _roleLabel(_currentRole),
                icon: Icons.badge_outlined,
                color: const Color(0xFF7C3AED),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildOverviewMiniCardHome(
                title: 'Матчи',
                value: '${_recentMatches.length}',
                icon: Icons.sports_soccer_outlined,
                color: const Color(0xFFEA580C),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildOverviewMiniCardHome(
                title: 'Отчёты',
                value: '${_workspaceReports.length}',
                icon: Icons.analytics_outlined,
                color: const Color(0xFFE11D48),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

Widget _buildOverviewMiniCardHome({
  required String title,
  required String value,
  required IconData icon,
  required Color color,
}) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE7ECF2)),
    ),
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}


Widget _buildWorkspaceActivitySection(
  BuildContext context, {
  EdgeInsetsGeometry margin = const EdgeInsets.only(bottom: 12),
}) {
  final activityItems = _buildUnifiedClubActivityItems(context).take(4).toList();

  return _buildHomeSectionShell(
    title: 'Последние активности',
    rightText: 'live',
    margin: margin,
    child: Column(
      children: [
        if (activityItems.isEmpty)
          _buildActivityCard(
            title: 'Активность клуба',
            value: 'Пока нет новых записей',
            subtitle: 'Когда появятся дневники, комментарии тренеров или чаты — они будут здесь.',
            trailing: '',
            icon: Icons.notifications_none_rounded,
            color: const Color(0xFF178A45),
          )
        else
          ...activityItems.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            return Padding(
              padding: EdgeInsets.only(
                bottom: index == activityItems.length - 1 ? 0 : 10,
              ),
              child: _buildActivityCard(
                title: (item['title'] ?? '').toString(),
                value: (item['value'] ?? '').toString(),
                subtitle: (item['subtitle'] ?? '').toString(),
                trailing: (item['trailing'] ?? '').toString(),
                icon: item['icon'] as IconData? ?? Icons.circle_notifications_rounded,
                color: item['color'] as Color? ?? const Color(0xFF178A45),
                onTap: item['onTap'] as VoidCallback?,
              ),
            );
          }),
      ],
    ),
  );
}

List<Map<String, dynamic>> _buildUnifiedClubActivityItems(BuildContext context) {
  final items = <Map<String, dynamic>>[];
  final posts = List<Map<String, dynamic>>.from(
    _userPostsCache[selectedSport ?? 'Футбол'] ?? const [],
  );

  for (final post in posts.take(2)) {
    final author = (post['authorName'] ?? 'Игрок').toString().trim();
    final title = (post['title'] ?? '').toString().trim();
    final text = (post['text'] ?? '').toString().trim();
    final preview = text.isNotEmpty ? text : (title.isNotEmpty ? title : 'Новая запись игрока');

    items.add({
      'title': 'Дневник игрока',
      'value': author.isNotEmpty ? author : 'Игрок команды',
      'subtitle': preview,
      'trailing': 'дневник',
      'icon': Icons.edit_note_rounded,
      'color': const Color(0xFF178A45),
      'onTap': null,
    });
  }

  for (final report in _workspaceReports.take(2)) {
    final title = _pickMapString(
      report,
      ['coach_name', 'trainer_name', 'author_name', 'author'],
      fallback: 'Тренер',
    );
    final comment = _pickMapString(
      report,
      ['coach_comment', 'trainer_comment', 'comment', 'notes', 'subtitle', 'description'],
      fallback: _reportMainText(report),
    );
    final module = _pickMapString(
      report,
      ['module', 'type', 'section'],
      fallback: 'модуль',
    );

    items.add({
      'title': 'Комментарий тренера',
      'value': title,
      'subtitle': comment,
      'trailing': module,
      'icon': Icons.rate_review_rounded,
      'color': const Color(0xFF0F766E),
      'onTap': _openWorkspacePrimary,
    });
  }

  for (final chat in _recentChats.take(3)) {
    final chatId = int.tryParse('${chat['id'] ?? chat['chat_id'] ?? 0}') ?? 0;
    final chatName = (chat['title'] ?? chat['name'] ?? 'Чат').toString().trim();
    final lastMessage = (chat['last_message'] ?? chat['message'] ?? chat['last_text'] ?? 'Нет сообщений')
        .toString()
        .trim();
    final unread = int.tryParse('${chat['unread_count'] ?? 0}') ?? 0;

    items.add({
      'title': 'Последний чат',
      'value': chatName.isNotEmpty ? chatName : 'Чат команды',
      'subtitle': lastMessage.isNotEmpty ? lastMessage : 'Нет сообщений',
      'trailing': unread > 0 ? '$unread' : 'чат',
      'icon': Icons.forum_rounded,
      'color': const Color(0xFF7C3AED),
      'onTap': chatId <= 0
          ? () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ChatScreen(userId: _userId ?? 0)),
              );
            }
          : () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatRoomScreen(
                    chatId: chatId,
                    userId: _userId ?? 0,
                    chatName: chatName.isNotEmpty ? chatName : 'Чат',
                  ),
                ),
              );
            },
    });
  }

  if (items.isEmpty) {
    final match = _getPrimaryWorkspaceMatch();
    final report = _getPrimaryWorkspaceReport();

    items.addAll([
      {
        'title': 'Последний матч',
        'value': _matchMainText(match),
        'subtitle': _matchSubText(match),
        'trailing': _matchValueText(match),
        'icon': Icons.sports_soccer_rounded,
        'color': const Color(0xFF178A45),
        'onTap': _openWorkspacePrimary,
      },
      {
        'title': 'Последний отчёт',
        'value': _reportMainText(report),
        'subtitle': _reportSubText(report),
        'trailing': _reportValueText(report),
        'icon': Icons.analytics_rounded,
        'color': const Color(0xFF0F766E),
        'onTap': _openWorkspacePrimary,
      },
    ]);
  }

  return items;
}

Widget _buildActivityCard({
  required String title,
  required String value,
  required String subtitle,
  required String trailing,
  required IconData icon,
  required Color color,
  VoidCallback? onTap,
}) {
  final body = Container(
    constraints: const BoxConstraints(minHeight: 88),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFBFCFB),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE4EFE8)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (trailing.trim().isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: color.withOpacity(0.16)),
                      ),
                      child: Text(
                        trailing,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: color,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 5),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
              if (subtitle.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );

  if (onTap == null) return body;

  return InkWell(
    borderRadius: BorderRadius.circular(18),
    onTap: onTap,
    child: body,
  );
}

Widget _buildWorkspaceRecentChatsSection(
  BuildContext context, {
  EdgeInsetsGeometry margin = const EdgeInsets.only(bottom: 12),
}) {
  final chats = List<Map<String, dynamic>>.from(_recentChats.take(3));

  return _buildHomeSectionShell(
    title: 'Последние чаты',
    rightText: 'chat',
    margin: margin,
    child: Column(
      children: [
        if (chats.isEmpty)
          _buildActivityCard(
            title: 'Чаты клуба',
            value: 'Нет активных чатов',
            subtitle: 'Новые сообщения команд и тренеров появятся здесь.',
            trailing: '',
            icon: Icons.forum_outlined,
            color: const Color(0xFF7C3AED),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ChatScreen(userId: _userId ?? 0)),
              );
            },
          )
        else
          ...chats.asMap().entries.map((entry) {
            final index = entry.key;
            final chat = entry.value;
            final chatId = int.tryParse('${chat['id'] ?? chat['chat_id'] ?? 0}') ?? 0;
            final chatName = (chat['title'] ?? chat['name'] ?? 'Чат').toString().trim();
            final lastMessage = (chat['last_message'] ?? chat['message'] ?? chat['last_text'] ?? 'Нет сообщений')
                .toString()
                .trim();
            final unread = int.tryParse('${chat['unread_count'] ?? 0}') ?? 0;

            return Padding(
              padding: EdgeInsets.only(bottom: index == chats.length - 1 ? 0 : 10),
              child: _buildActivityCard(
                title: 'Командный чат',
                value: chatName.isNotEmpty ? chatName : 'Чат команды',
                subtitle: lastMessage.isNotEmpty ? lastMessage : 'Нет сообщений',
                trailing: unread > 0 ? '$unread' : 'чат',
                icon: Icons.forum_rounded,
                color: const Color(0xFF7C3AED),
                onTap: chatId <= 0
                    ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ChatScreen(userId: _userId ?? 0)),
                        );
                      }
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatRoomScreen(
                              chatId: chatId,
                              userId: _userId ?? 0,
                              chatName: chatName.isNotEmpty ? chatName : 'Чат',
                            ),
                          ),
                        );
                      },
              ),
            );
          }),
      ],
    ),
  );
}

Widget _buildWorkspaceTrackerSection(
  BuildContext context, {
  EdgeInsetsGeometry margin = const EdgeInsets.only(bottom: 12),
}) {
  return _buildHomeSectionShell(
    title: _isPlayerRole || _isParentRole ? 'Состояние игрока' : 'Трекер',
    rightText: _isTrackerConnectedNow() ? 'online' : 'offline',
    margin: margin,
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildOverviewMiniCardHome(
                title: 'Пульс',
                value: '${_trackerSummary['pulse'] ?? '124'}',
                icon: Icons.favorite_outline_rounded,
                color: const Color(0xFFE11D48),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildOverviewMiniCardHome(
                title: 'Готовность',
                value: '${_trackerSummary['readiness'] ?? '79%'}',
                icon: Icons.bolt_outlined,
                color: const Color(0xFFF59E0B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildOverviewMiniCardHome(
                title: 'Нагрузка',
                value: '${_trackerSummary['load'] ?? 'Рабочая'}',
                icon: Icons.fitness_center_outlined,
                color: const Color(0xFF2563EB),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildOverviewMiniCardHome(
                title: 'Спринты',
                value: '${_trackerSummary['sprints'] ?? '96'}',
                icon: Icons.speed_outlined,
                color: const Color(0xFF10B981),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
  Widget _buildNewsHubCard(
    BuildContext context,
    List<Map<String, dynamic>> feedPosts,
  ) {
    if (feedPosts.isEmpty) {
      return _buildEmptyPlaceholder(
        icon: Icons.newspaper_rounded,
        text: 'Пока нет новостей для этой категории спорта',
      );
    }

    final featured = feedPosts.first;
    final others = feedPosts.skip(1).toList();
    final imageUrl = (featured['imageUrl'] ?? '').toString();

    return Container(
      decoration: BoxDecoration(
        color: _homeDesign.cardColor,
        borderRadius: BorderRadius.circular(_homeDesign.cardRadius),
        border: Border.all(color: _homeDesign.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_homeDesign.shadowOpacity),
            blurRadius: _homeDesign.shadowBlur,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: _isTablet(context)
            ? Row(
                children: [
                  Expanded(
                    flex: 6,
                    child: InkWell(
                      onTap: () => _openPost(featured),
                      borderRadius: BorderRadius.circular(14),
                      child: _buildHubFeaturedNewsPreview(featured, imageUrl),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 5,
                    child: others.isEmpty
                        ? _buildEmptyPlaceholder(
                            icon: Icons.newspaper_rounded,
                            text: 'Пока нет других новостей',
                          )
                        : ListView.separated(
                            padding: EdgeInsets.zero,
                            physics: const BouncingScrollPhysics(),
                            itemCount: others.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 6),
                            itemBuilder: (context, index) {
                              return _buildCompactNewsRow(
                                others[index],
                                _postsConfig,
                              );
                            },
                          ),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () => _openPost(featured),
                    borderRadius: BorderRadius.circular(14),
                    child: _buildHubFeaturedNewsPreview(featured, imageUrl),
                  ),
                  if (others.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ...others.map(
                      (post) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _buildCompactNewsRow(post, _postsConfig),
                      ),
                    ),
                  ],
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SportCommunityScreen(
                              sportName: selectedSport ?? 'Футбол',
                            ),
                          ),
                        );
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                      ),
                      child: Text(
                        'Открыть ленту',
                        style: TextStyle(
                          color: _homeDesign.primaryColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  HomeSectionConfig get _postsConfig => _homeDesign.sections.firstWhere(
        (e) => e.type == HomeSectionType.posts,
        orElse: () => _homeDesign.sections.first,
      );

  Widget _buildHubFeaturedNewsPreview(
    Map<String, dynamic> post,
    String imageUrl,
  ) {
    final title = _stripHtml((post['title'] ?? '').toString());
    final author = (post['authorName'] ?? 'Пользователь').toString();
    final avatarUrl = (post['authorAvatar'] ?? '').toString();
    final text = _stripHtml((post['text'] ?? '').toString());

    final bool compact = _isPhoneLandscape(context);
    final double imageHeight = _isTablet(context)
        ? 180
        : (compact ? 112 : 140);

    final double titleSize = _responsiveFont(
      context,
      mobile: compact ? 12.2 : 13,
      tablet: 13.5,
      landscapeDelta: -0.15,
    );

    final double bodySize = _responsiveFont(
      context,
      mobile: compact ? 10.4 : (_homeDesign.bodyTextSize - 1),
      tablet: _homeDesign.bodyTextSize,
      landscapeDelta: -0.15,
    );

    final double metaSize = _responsiveFont(
      context,
      mobile: compact ? 9.2 : (_homeDesign.smallTextSize - 1),
      tablet: _homeDesign.smallTextSize,
      landscapeDelta: -0.1,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: imageHeight,
            width: double.infinity,
            child: imageUrl.isNotEmpty
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: _homeDesign.primaryColor.withOpacity(0.08),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.08),
                              Colors.black.withOpacity(0.18),
                              Colors.black.withOpacity(0.58),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: 10,
                        right: 10,
                        bottom: 10,
                        child: Text(
                          title.isEmpty ? 'Главная новость' : title,
                          maxLines: compact ? 2 : 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: titleSize,
                            height: 1.08,
                          ),
                        ),
                      ),
                    ],
                  )
                : Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          _homeDesign.primaryColor,
                          _homeDesign.primaryColor.withOpacity(0.72),
                        ],
                      ),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: Text(
                        title.isEmpty ? 'Главная новость' : title,
                        maxLines: compact ? 2 : 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: titleSize,
                          height: 1.08,
                        ),
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _authorAvatarWidget(
              avatarUrl: avatarUrl,
              author: author,
              radius: compact ? 11 : 12,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                author,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: metaSize,
                  fontWeight: FontWeight.w800,
                  color: _homeDesign.textColor,
                  height: 1.05,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              _formatPostDateHome(post['date'] as DateTime),
              style: TextStyle(
                fontSize: metaSize - 0.6,
                color: _homeDesign.mutedTextColor,
                height: 1.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          text.isEmpty ? 'Свежая публикация сообщества' : text,
          maxLines: compact ? 2 : 3,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: bodySize,
            color: _homeDesign.textColor,
            height: 1.24,
          ),
        ),
      ],
    );
  }

  Widget _buildMiniReelsStrip(
    BuildContext context,
    List<Map<String, dynamic>> reels,
  ) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _homeDesign.cardColor,
        borderRadius: BorderRadius.circular(_homeDesign.cardRadius),
        border: Border.all(color: _homeDesign.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_homeDesign.shadowOpacity),
            blurRadius: _homeDesign.shadowBlur,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Короткие видео',
                style: TextStyle(
                  fontSize: _homeDesign.cardTitleSize,
                  fontWeight: FontWeight.w900,
                  color: _homeDesign.textColor,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _openReels,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                ),
                child: Text(
                  'Все',
                  style: TextStyle(
                    color: _homeDesign.primaryColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (reels.isEmpty)
            Text(
              'Видео пока нет',
              style: TextStyle(
                color: _homeDesign.mutedTextColor,
                fontSize: _homeDesign.bodyTextSize - 1,
              ),
            )
          else
            SizedBox(
              height: _isTablet(context) ? 120 : 110,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: reels.length,
                itemBuilder: (context, index) {
                  final reel = reels[index];
                  final thumb = (reel['thumbnail'] ?? '').toString();
                  final desc = (reel['description'] ?? 'Видео').toString();
                  final reelId = reel['id'] is int
                      ? reel['id'] as int
                      : int.tryParse('${reel['id']}');

                  return Padding(
                    padding: EdgeInsets.only(
                      right: index == reels.length - 1 ? 0 : 8,
                    ),
                    child: InkWell(
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
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: _isTablet(context) ? 130 : 120,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: _homeDesign.backgroundColor,
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: thumb.isNotEmpty
                                  ? Image.network(
                                      _normalizeMediaUrl(thumb),
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          _reelFallback(),
                                    )
                                  : _reelFallback(),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withOpacity(0.08),
                                    Colors.black.withOpacity(0.16),
                                    Colors.black.withOpacity(0.52),
                                  ],
                                ),
                              ),
                            ),
                            const Center(
                              child: Icon(
                                Icons.play_circle_fill_rounded,
                                color: Colors.white,
                                size: 32,
                              ),
                            ),
                            Positioned(
                              left: 6,
                              right: 6,
                              bottom: 6,
                              child: Text(
                                desc,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 9,
                                  height: 1.2,
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
      ),
    );
  }
  
  Widget _buildCoachNoTeamPanel(BuildContext context) {
  return Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(32),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF06142C),
          Color(0xFF0A1C3E),
          Color(0xFF00895F),
        ],
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.16),
          blurRadius: 24,
          offset: const Offset(0, 12),
        ),
      ],
    ),
    clipBehavior: Clip.antiAlias,
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Панель тренера',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 20,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'У вас пока нет привязанной команды',
            style: TextStyle(
              color: Colors.white.withOpacity(0.82),
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.08),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.groups_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Создайте свою команду',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'После создания команды здесь появятся ваши матчи, отчёты и данные трекеров.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.74),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 14),
                InkWell(
                  onTap: _openClubsAll,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Создать команду',
                      style: TextStyle(
                        color: _homeDesign.primaryColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
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
  
Widget _buildProfessionalWorkspacePanel(BuildContext context) {
  if (_isCoachWithoutTeam) {
    return _buildCoachNoTeamPanel(context);
  }

  final targetName = _getDashboardTargetName().trim().isNotEmpty
      ? _getDashboardTargetName().trim()
      : _currentFullName;

  final trackerConnected = _isTrackerConnectedNow();
  final match = _getPrimaryWorkspaceMatch();
  final report = _getPrimaryWorkspaceReport();
  final stats = _buildWorkspaceStatCards();
  final tablet = _isTablet(context);

  return Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: const Color(0xFFE9EEF5)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 18,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    padding: EdgeInsets.all(tablet ? 16 : 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildWorkspaceWhiteHeader(
          context,
          title: _isPlayerRole
              ? 'Панель игрока'
              : _isParentRole
                  ? 'Панель родителя'
                  : _isClubRole
                      ? 'Панель клуба'
                      : _isCoachRole
                          ? 'Панель тренера'
                          : 'Рабочая панель',
          targetName: targetName,
          trackerConnected: trackerConnected,
        ),
        const SizedBox(height: 12),
        GridView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: stats.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
  crossAxisCount: _isClubRole
      ? (_isTablet(context) && _isLandscape(context) ? 4 : 2)
      : 3,
  mainAxisSpacing: 8,
  crossAxisSpacing: 8,
  childAspectRatio: _isClubRole
      ? (_isTablet(context) && _isLandscape(context) ? 2.35 : 1.8)
      : (tablet ? 2.2 : 1.15),
),
          itemBuilder: (context, index) {
            final item = stats[index];
            return _buildWorkspaceWhiteMiniStat(
              title: item['title'] as String,
              value: item['value'] as String,
              icon: item['icon'] as IconData,
              color: item['color'] as Color,
            );
          },
        ),
        const SizedBox(height: 12),
        if (tablet)
          Row(
            children: [
              Expanded(
                child: _buildWorkspaceWhiteInfoCard(
                  title: 'Последний матч',
                  icon: Icons.sports_soccer_rounded,
                  color: const Color(0xFF2563EB),
                  mainText: _matchMainText(match),
                  subText: _matchSubText(match),
                  valueText: _matchValueText(match),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildWorkspaceWhiteInfoCard(
                  title: trackerConnected
                      ? (_isPlayerRole || _isParentRole
                          ? 'Состояние игрока'
                          : 'Состояние команды')
                      : 'Трекер не подключён',
                  icon: trackerConnected
                      ? Icons.bluetooth_connected_rounded
                      : Icons.bluetooth_disabled_rounded,
                  color: trackerConnected
                      ? const Color(0xFF10B981)
                      : const Color(0xFF6B7280),
                  mainText: _trackerMainText(),
                  subText: _trackerSubText(),
                  valueText: trackerConnected ? _trackerValueText() : '',
                  actionLabel: trackerConnected ? null : 'Подключить',
                  onActionTap: trackerConnected
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TrackingModeScreen(),
                            ),
                          );
                        },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildWorkspaceWhiteInfoCard(
                  title: 'Последний отчёт',
                  icon: Icons.analytics_rounded,
                  color: const Color(0xFF7C3AED),
                  mainText: _reportMainText(report),
                  subText: _reportSubText(report),
                  valueText: _reportValueText(report),
                ),
              ),
            ],
          )
        else
          Column(
            children: [
              _buildWorkspaceWhiteInfoCard(
                title: 'Последний матч',
                icon: Icons.sports_soccer_rounded,
                color: const Color(0xFF2563EB),
                mainText: _matchMainText(match),
                subText: _matchSubText(match),
                valueText: _matchValueText(match),
              ),
              const SizedBox(height: 8),
              _buildWorkspaceWhiteInfoCard(
                title: trackerConnected
                    ? (_isPlayerRole || _isParentRole
                        ? 'Состояние игрока'
                        : 'Состояние команды')
                    : 'Трекер не подключён',
                icon: trackerConnected
                    ? Icons.bluetooth_connected_rounded
                    : Icons.bluetooth_disabled_rounded,
                color: trackerConnected
                    ? const Color(0xFF10B981)
                    : const Color(0xFF6B7280),
                mainText: _trackerMainText(),
                subText: _trackerSubText(),
                valueText: trackerConnected ? _trackerValueText() : '',
                actionLabel: trackerConnected ? null : 'Подключить',
                onActionTap: trackerConnected
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const TrackingModeScreen(),
                          ),
                        );
                      },
              ),
              const SizedBox(height: 8),
              _buildWorkspaceWhiteInfoCard(
                title: 'Последний отчёт',
                icon: Icons.analytics_rounded,
                color: const Color(0xFF7C3AED),
                mainText: _reportMainText(report),
                subText: _reportSubText(report),
                valueText: _reportValueText(report),
              ),
            ],
          ),
      ],
    ),
  );
}

Widget _buildClubModulesHorizontalSection(BuildContext context) {
  if (!_isClubRole) return const SizedBox.shrink();

  final modules = [
    {
      'title': 'Команды',
      'subtitle': 'Состав клуба',
      'icon': Icons.groups_2_outlined,
      'color': const Color(0xFF2563EB),
      'onTap': _openClubsAll,
    },
    {
      'title': 'Календарь',
      'subtitle': 'События клуба',
      'icon': Icons.calendar_month_outlined,
      'color': const Color(0xFF0EA5E9),
      'onTap': () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ClubCalendarScreen(
              clubId: _currentClubId,
              clubName: _currentClubName.isNotEmpty
                  ? _currentClubName
                  : _getDashboardTargetName(),
              teams: _clubTeams,
            ),
          ),
        );
      },
    },
    {
      'title': 'Тренеры',
      'subtitle': 'Штаб клуба',
      'icon': Icons.people_outline,
      'color': const Color(0xFF16A34A),
      'onTap': () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TeamTrainersScreen(
              clubId: _currentClubId,
              clubName: _currentClubName.isNotEmpty
                  ? _currentClubName
                  : _getDashboardTargetName(),
              teams: _clubTeams,
            ),
          ),
        );
      },
    },
    {
      'title': 'Посещаемость',
      'subtitle': 'Журнал',
      'icon': Icons.fact_check_outlined,
      'color': const Color(0xFFEA580C),
      'onTap': () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AttendanceScreen(
              clubId: _currentClubId,
              clubName: _currentClubName.isNotEmpty
                  ? _currentClubName
                  : _getDashboardTargetName(),
              teams: _clubTeams,
            ),
          ),
        );
      },
    },
    {
      'title': 'Планы',
      'subtitle': 'Конспекты',
      'icon': Icons.menu_book_outlined,
      'color': const Color(0xFF7C3AED),
      'onTap': () {
        final teamId = _selectedWorkspaceTeamId ?? _currentTeamId;
        if (teamId <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Сначала выберите команду')),
          );
          return;
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlanFoldersScreen(
              clubId: _currentClubId,
              clubName: _currentClubName.isNotEmpty
                  ? _currentClubName
                  : _getDashboardTargetName(),
              teamId: teamId,
            ),
          ),
        );
      },
    },
    {
      'title': 'Панель клуба',
      'subtitle': 'Полный экран',
      'icon': Icons.dashboard_customize_outlined,
      'color': const Color(0xFFDC2626),
      'onTap': () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const ClubWorkspaceScreen(),
          ),
        );
      },
    },
  ];

  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: _homeDesign.cardColor,
      borderRadius: BorderRadius.circular(_homeDesign.cardRadius),
      border: Border.all(color: _homeDesign.borderColor),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(_homeDesign.shadowOpacity),
          blurRadius: _homeDesign.shadowBlur,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: _homeDesign.primaryColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.dashboard_customize_rounded,
                color: _homeDesign.primaryColor,
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Модули клуба',
                style: TextStyle(
                  fontSize: _homeDesign.sectionTitleSize,
                  fontWeight: FontWeight.w900,
                  color: _homeDesign.textColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 132,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: modules.length,
            itemBuilder: (context, index) {
              final item = modules[index];
              final color = item['color'] as Color;

              return Padding(
                padding: EdgeInsets.only(
                  right: index == modules.length - 1 ? 0 : 10,
                ),
                child: InkWell(
                  onTap: item['onTap'] as VoidCallback,
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    width: 150,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE8EDF3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            item['icon'] as IconData,
                            color: color,
                            size: 18,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          item['title'] as String,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item['subtitle'] as String,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
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
    ),
  );
}

Widget _buildWorkspaceModulesBlock(BuildContext context) {
  if (_isClubRole) {
    return _buildClubModulesCompactBlock(context);
  }

  if (_isCoachRole) {
    return _buildTeamModulesCompactBlock(context);
  }

  return const SizedBox.shrink();
}

Widget _buildClubWorkspaceOverviewCard(BuildContext context) {
  if (!_isClubRole) return const SizedBox.shrink();

  final clubName = (_clubProfile['club_name'] ?? _currentClubName).toString();
  final address = (_clubProfile['club_address'] ?? '').toString();
  final description =
      _stripHtml((_clubProfile['club_description'] ?? '').toString());

  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xFFE5EAF1)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Клуб сейчас',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w900,
            fontSize: 13.5,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          clubName.isNotEmpty ? clubName : 'Клуб',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w900,
            fontSize: 15,
          ),
        ),
        if (address.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.place_rounded, size: 15, color: Color(0xFF64748B)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
        if (description.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF475569),
              fontSize: 11.5,
              height: 1.3,
            ),
          ),
        ],
      ],
    ),
  );
}

Widget _buildWorkspaceTeamSwitcherCard(BuildContext context) {
  final source = _isCoachRole
      ? (_myTeams.isNotEmpty ? _myTeams : _clubTeams)
      : _clubTeams;

  if ((!_isClubRole && !_isCoachRole) || source.isEmpty) {
    return const SizedBox.shrink();
  }

  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xFFE5EAF1)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Выбранная команда',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w900,
            fontSize: 13.5,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Text(
                _selectedWorkspaceTeamName.isNotEmpty
                    ? _selectedWorkspaceTeamName
                    : 'Команда не выбрана',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () async {
                final picked = await showModalBottomSheet<Map<String, dynamic>>(
                  context: context,
                  backgroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (_) {
                    return SafeArea(
                      top: false,
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: source.length,
                        itemBuilder: (context, index) {
                          final item = source[index];
                          final id = int.tryParse(
                                '${item['id'] ?? item['team_id'] ?? 0}',
                              ) ??
                              0;
                          final name = (item['name'] ?? item['team_name'] ?? 'Команда')
                              .toString();

                          return ListTile(
                            title: Text(name),
                            onTap: () => Navigator.pop(
                              context,
                              {'id': id, 'name': name},
                            ),
                          );
                        },
                      ),
                    );
                  },
                );

                if (picked != null && mounted) {
                  setState(() {
                    _selectedWorkspaceTeamId = picked['id'] as int?;
                    _selectedWorkspaceTeamName =
                        (picked['name'] ?? '').toString();
                  });
                }
              },
              child: const Text('Сменить'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              final teamId = _selectedWorkspaceTeamId ?? 0;
              if (teamId <= 0) return;

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TeamDashboardScreen(
                    teamId: teamId,
                    teamName: _selectedWorkspaceTeamName,
                    clubId: _currentClubId,
                    clubName: _currentClubName,
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _homeDesign.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('Открыть панель команды'),
          ),
        ),
      ],
    ),
  );
}

Widget _buildWorkspaceClubEventsCard(BuildContext context) {
  if (_clubEvents.isEmpty) return const SizedBox.shrink();

  final items = _clubEvents.take(3).toList();

  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xFFE5EAF1)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ближайшие события клуба',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w900,
            fontSize: 13.5,
          ),
        ),
        const SizedBox(height: 10),
        ...items.map((event) {
          final title =
              (event['title'] ?? event['name'] ?? 'Событие').toString();
          final date =
              (event['event_date'] ?? event['date'] ?? '').toString();
          final team =
              (event['team_name'] ?? '').toString();

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE8EDF3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDBEAFE),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.calendar_month_rounded,
                    size: 17,
                    color: Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [if (date.isNotEmpty) date, if (team.isNotEmpty) team]
                            .join(' • '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    ),
  );
}

Widget _buildWorkspaceTrainersCard(BuildContext context) {
  if (_clubTrainers.isEmpty || !_isClubRole) return const SizedBox.shrink();

  final items = _clubTrainers.take(4).toList();

  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xFFE5EAF1)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Тренеры клуба',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w900,
            fontSize: 13.5,
          ),
        ),
        const SizedBox(height: 10),
        ...items.map((trainer) {
          final first = (trainer['first_name'] ?? '').toString();
          final last = (trainer['last_name'] ?? '').toString();
          final email = (trainer['email'] ?? '').toString();
          final fullName = ('$first $last').trim().isEmpty
              ? 'Тренер'
              : ('$first $last').trim();

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE8EDF3)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFFE8F5E9),
                  child: Text(
                    fullName[0].toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFF00A750),
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF0F172A),
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                      if (email.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    ),
  );
}

Widget _buildWorkspaceWhiteHeader(
  BuildContext context, {
  required String title,
  required String targetName,
  required bool trackerConnected,
}) {
  final logoUrl = _currentTeamLogoUrl.trim();

  return Row(
    children: [
      _teamLogoWidget(
        teamName: targetName,
        logoUrl: logoUrl,
        accent: _homeDesign.primaryColor,
        size: _isTablet(context) ? 56 : 50,
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.w900,
                fontSize: 18,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              targetName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF475569),
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: trackerConnected
              ? const Color(0xFFECFDF5)
              : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          trackerConnected ? 'Трекер онлайн' : 'Трекер офлайн',
          style: TextStyle(
            color: trackerConnected
                ? const Color(0xFF059669)
                : const Color(0xFF6B7280),
            fontWeight: FontWeight.w800,
            fontSize: 10.5,
            height: 1.0,
          ),
        ),
      ),
    ],
  );
}

Widget _buildWorkspaceWhiteMiniStat({
  required String title,
  required String value,
  required IconData icon,
  required Color color,
}) {
  final isTabletLandscape = _isTablet(context) && _isLandscape(context);
  final isLongValue = value.contains('\n') || value.length > 18;

  return Container(
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE5EAF1)),
    ),
    padding: EdgeInsets.symmetric(
      horizontal: isTabletLandscape ? 10 : 10,
      vertical: isTabletLandscape ? 8 : 10,
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: isTabletLandscape ? 30 : 32,
          height: isTabletLandscape ? 30 : 32,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(
            icon,
            color: color,
            size: isTabletLandscape ? 16 : 17,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: const Color(0xFF64748B),
                  fontSize: isTabletLandscape ? 9.2 : 10,
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                maxLines: isLongValue ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: const Color(0xFF0F172A),
                  fontSize: isLongValue
                      ? (isTabletLandscape ? 10.4 : 11.2)
                      : (isTabletLandscape ? 14 : 16),
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _buildWorkspaceWhiteInfoCard({
  required String title,
  required IconData icon,
  required Color color,
  required String mainText,
  required String subText,
  required String valueText,
  String? actionLabel,
  VoidCallback? onActionTap,
}) {
  final hasAction = actionLabel != null && actionLabel.trim().isNotEmpty;

  return Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE5EAF1)),
    ),
    padding: const EdgeInsets.all(12),
    child: Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                mainText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                ),
              ),
              if (subText.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (hasAction)
          InkWell(
            onTap: onActionTap,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Подключить',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                ),
              ),
            ),
          )
        else
          Text(
            valueText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 14,
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),
      ],
    ),
  );
}

Widget _buildClubModulesCompactBlock(BuildContext context) {
  final modules = [
    {
      'title': 'Команды',
      'icon': Icons.groups_2_outlined,
      'color': const Color(0xFF2563EB),
      'onTap': _openClubsAll,
    },
    {
      'title': 'Календарь',
      'icon': Icons.calendar_month_outlined,
      'color': const Color(0xFF0EA5E9),
      'onTap': () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ClubCalendarScreen(
              clubId: _currentClubId,
              clubName: _currentClubName.isNotEmpty
                  ? _currentClubName
                  : _getDashboardTargetName(),
              teams: _clubTeams,
            ),
          ),
        );
      },
    },
    {
      'title': 'Тренеры',
      'icon': Icons.people_outline,
      'color': const Color(0xFF16A34A),
      'onTap': () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TeamTrainersScreen(
              clubId: _currentClubId,
              clubName: _currentClubName.isNotEmpty
                  ? _currentClubName
                  : _getDashboardTargetName(),
              teams: _clubTeams,
            ),
          ),
        );
      },
    },
    {
      'title': 'Посещаемость',
      'icon': Icons.fact_check_outlined,
      'color': const Color(0xFFEA580C),
      'onTap': () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AttendanceScreen(
              clubId: _currentClubId,
              clubName: _currentClubName.isNotEmpty
                  ? _currentClubName
                  : _getDashboardTargetName(),
              teams: _clubTeams,
            ),
          ),
        );
      },
    },
    {
      'title': 'Планы',
      'icon': Icons.menu_book_outlined,
      'color': const Color(0xFF7C3AED),
      'onTap': () {
        final teamId = _selectedWorkspaceTeamId ?? _currentTeamId;
        if (teamId <= 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Сначала выберите команду')),
          );
          return;
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlanFoldersScreen(
              clubId: _currentClubId,
              clubName: _currentClubName.isNotEmpty
                  ? _currentClubName
                  : _getDashboardTargetName(),
              teamId: teamId,
            ),
          ),
        );
      },
    },
    {
      'title': 'Панель клуба',
      'icon': Icons.dashboard_customize_outlined,
      'color': const Color(0xFFDC2626),
      'onTap': () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const ClubWorkspaceScreen(),
          ),
        );
      },
    },
  ];

  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xFFE5EAF1)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Модули клуба',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w900,
            fontSize: 13.5,
          ),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: modules.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _isTablet(context) ? 6 : 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: _isTablet(context) ? 1.1 : 1.0,
          ),
          itemBuilder: (context, index) {
            final item = modules[index];
            return InkWell(
              onTap: item['onTap'] as VoidCallback,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE8EDF3)),
                ),
                padding: const EdgeInsets.all(10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: (item['color'] as Color).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(
                        item['icon'] as IconData,
                        color: item['color'] as Color,
                        size: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item['title'] as String,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    ),
  );
}

Widget _buildTeamModulesCompactBlock(BuildContext context) {
  final teamId = _selectedWorkspaceTeamId ?? _currentTeamId;
  final teamName = _selectedWorkspaceTeamName.isNotEmpty
      ? _selectedWorkspaceTeamName
      : (_currentTeamName.isNotEmpty
          ? _currentTeamName
          : _getDashboardTargetName());

  if (teamId <= 0) {
    return const SizedBox.shrink();
  }
  final modules = [
    {
      'title': 'Состав',
      'icon': Icons.groups_2_outlined,
      'color': const Color(0xFF2563EB),
      'onTap': () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TeamRosterScreen(
              teamId: teamId,
              teamName: teamName,
            ),
          ),
        );
      },
    },
    {
      'title': 'Календарь',
      'icon': Icons.calendar_month_outlined,
      'color': const Color(0xFF0EA5E9),
      'onTap': () {
        Get.to(
          () => TeamCalendarScreen(
            teamId: teamId,
            teamName: teamName,
          ),
        );
      },
    },
    {
      'title': 'Посещаемость',
      'icon': Icons.fact_check_outlined,
      'color': const Color(0xFF16A34A),
      'onTap': () {
        Get.to(
          () => TeamAttendanceJournalScreen(
            teamId: teamId,
            teamName: teamName,
          ),
        );
      },
    },
    {
      'title': 'Матчи',
      'icon': Icons.sports_soccer_outlined,
      'color': const Color(0xFFEA580C),
      'onTap': () {
        Get.toNamed(
          AppRoutes.teamMatchesScreen,
          arguments: teamId,
        );
      },
    },
    {
      'title': 'Видеоанализ',
      'icon': Icons.video_camera_back_outlined,
      'color': const Color(0xFFDC2626),
      'onTap': () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TeamVideoAnalysisScreen(
              teamId: teamId,
              teamName: teamName,
              clubId: _currentClubId,
              clubName: _currentClubName,
            ),
          ),
        );
      },
    },
    {
      'title': 'Менеджер',
      'icon': Icons.psychology_alt_outlined,
      'color': const Color(0xFF7C3AED),
      'onTap': () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ManagerDashboardScreen(
              teamId: teamId,
              userId: _userId ?? 0,
              teamName: teamName,
            ),
          ),
        );
      },
    },
  ];

  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xFFE5EAF1)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Командные модули',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w900,
            fontSize: 13.5,
          ),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: modules.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _isTablet(context) ? 6 : 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: _isTablet(context) ? 1.1 : 1.0,
          ),
          itemBuilder: (context, index) {
            final item = modules[index];
            return InkWell(
              onTap: item['onTap'] as VoidCallback,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE8EDF3)),
                ),
                padding: const EdgeInsets.all(10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: (item['color'] as Color).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(
                        item['icon'] as IconData,
                        color: item['color'] as Color,
                        size: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item['title'] as String,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    ),
  );
}

Widget _buildWorkspaceCompactTop(
  BuildContext context, {
  required String title,
  required String roleLabel,
  required String targetName,
  required bool trackerConnected,
}) {
  final compact = MediaQuery.of(context).size.width < 430;
  final logoUrl = _currentTeamLogoUrl.trim();

  if (compact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _teamLogoWidget(
              teamName: targetName,
              logoUrl: logoUrl,
              accent: Colors.white,
              size: 52,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    targetName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.92),
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _buildWorkspaceChip(roleLabel),
            const SizedBox(width: 8),
            _buildWorkspaceChip(
              trackerConnected ? 'Трекер онлайн' : 'Трекер офлайн',
              color: trackerConnected
                  ? const Color(0xFF10B981)
                  : const Color(0xFF6B7280),
            ),
            const Spacer(),
            _buildWorkspaceOpenButton(),
          ],
        ),
      ],
    );
  }

  return Row(
    children: [
      _teamLogoWidget(
        teamName: targetName,
        logoUrl: logoUrl,
        accent: Colors.white,
        size: _isTablet(context) ? 60 : 54,
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 20,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              targetName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withOpacity(0.92),
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                _buildWorkspaceChip(roleLabel),
                const SizedBox(width: 8),
                _buildWorkspaceChip(
                  trackerConnected ? 'Трекер онлайн' : 'Трекер офлайн',
                  color: trackerConnected
                      ? const Color(0xFF10B981)
                      : const Color(0xFF6B7280),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(width: 12),
      _buildWorkspaceOpenButton(),
    ],
  );
}

Widget _buildWorkspaceChip(String text, {Color? color}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: (color ?? Colors.white).withOpacity(0.14),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(
        color: Colors.white.withOpacity(0.10),
      ),
    ),
    child: Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w800,
        fontSize: 10,
        height: 1.0,
      ),
    ),
  );
}

Widget _buildWorkspaceOpenButton() {
  return InkWell(
    onTap: _openWorkspacePrimary,
    borderRadius: BorderRadius.circular(16),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.open_in_new_rounded,
            size: 15,
            color: _homeDesign.primaryColor,
          ),
          const SizedBox(width: 6),
          Text(
            'Открыть',
            style: TextStyle(
              color: _homeDesign.primaryColor,
              fontWeight: FontWeight.w900,
              fontSize: 12,
              height: 1.0,
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildWorkspaceTopMiniTile({
  required IconData icon,
  required Color color,
  required String title,
  required String value,
}) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.08),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: Colors.white.withOpacity(0.08),
      ),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    child: Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withOpacity(0.18),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 17,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.75),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _buildWorkspaceCompactBanner({
  required IconData icon,
  required Color color,
  required String title,
  required String mainText,
  required String subText,
  required String valueText,
  String? actionLabel,
  VoidCallback? onActionTap,
}) {
  final hasAction = actionLabel != null && actionLabel.trim().isNotEmpty;

  return Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.08),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: Colors.white.withOpacity(0.08),
      ),
    ),
    padding: const EdgeInsets.all(14),
    child: Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withOpacity(0.18),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 18,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.76),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                mainText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                ),
              ),
              if (subText.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.68),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    height: 1.0,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (hasAction)
          InkWell(
            onTap: onActionTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                actionLabel!,
                style: TextStyle(
                  color: color,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                ),
              ),
            ),
          )
        else if (valueText.trim().isNotEmpty)
          Text(
            valueText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),
      ],
    ),
  );
}

Map<String, dynamic> _getPrimaryWorkspaceMatch() {
  if (_recentMatches.isNotEmpty) return _recentMatches.first;
  return const {
    'title': 'Матч пока не найден',
    'subtitle': 'Нет свежих данных',
    'score': '—',
  };
}

Map<String, dynamic> _getPrimaryWorkspaceReport() {
  if (_workspaceReports.isNotEmpty) return _workspaceReports.first;
  return const {
    'title': 'Отчёт пока не найден',
    'subtitle': 'Нет свежих данных',
    'value': '—',
  };
}

bool _isTrackerConnectedNow() {
  final dynamic raw = _trackerSummary['connected'] ??
      _trackerSummary['is_connected'] ??
      _trackerSummary['tracker_connected'] ??
      _trackerSummary['status'];

  if (raw is bool) return raw;
  final text = raw?.toString().toLowerCase() ?? '';
  return text == '1' ||
      text == 'true' ||
      text == 'connected' ||
      text == 'online' ||
      text == 'active' ||
      text == 'подключен' ||
      text == 'подключён';
}

String _pickMapString(
  Map<String, dynamic> map,
  List<String> keys, {
  String fallback = '',
}) {
  for (final key in keys) {
    final value = map[key];
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty && text.toLowerCase() != 'null') {
      return text;
    }
  }
  return fallback;
}

String _matchMainText(Map<String, dynamic> match) {
  return _pickMapString(
    match,
    ['title', 'match_title', 'opponent', 'teams'],
    fallback: 'Последний матч',
  );
}

String _matchSubText(Map<String, dynamic> match) {
  return _pickMapString(
    match,
    ['date', 'match_date', 'tournament', 'competition', 'subtitle'],
    fallback: '',
  );
}

String _matchValueText(Map<String, dynamic> match) {
  return _pickMapString(
    match,
    ['score', 'result', 'status'],
    fallback: '—',
  );
}

String _reportMainText(Map<String, dynamic> report) {
  return _pickMapString(
    report,
    ['title', 'name', 'label'],
    fallback: 'Последний отчёт',
  );
}

String _reportSubText(Map<String, dynamic> report) {
  return _pickMapString(
    report,
    ['subtitle', 'date', 'period', 'description'],
    fallback: '',
  );
}

String _reportValueText(Map<String, dynamic> report) {
  return _pickMapString(
    report,
    ['value', 'status'],
    fallback: '—',
  );
}

String _trackerMainText() {
  if (!_isTrackerConnectedNow()) {
    return 'Нет активного устройства';
  }

  return _pickMapString(
    _trackerSummary,
    ['team_state', 'state', 'readiness', 'readiness_text'],
    fallback: 'Состояние команды',
  );
}

String _trackerSubText() {
  if (!_isTrackerConnectedNow()) {
    return 'Подключите трекер для данных по команде';
  }

  return _pickMapString(
    _trackerSummary,
    ['load', 'load_text', 'team_load', 'trackers_online', 'connected_devices'],
    fallback: '',
  );
}

String _trackerValueText() {
  if (!_isTrackerConnectedNow()) {
    return '';
  }

  return _pickMapString(
    _trackerSummary,
    ['readiness', 'readiness_percent', 'status_text', 'players_online'],
    fallback: 'онлайн',
  );
}
Widget _buildWorkspaceSafeHeader(
  BuildContext context, {
  required String title,
  required String subtitle,
  required String targetName,
  required String roleLabel,
}) {
  final logoUrl = _currentTeamLogoUrl.trim();
  final compact = MediaQuery.of(context).size.width < 430;

  if (compact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _teamLogoWidget(
              teamName: targetName,
              logoUrl: logoUrl,
              accent: Colors.white,
              size: 56,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    targetName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.92),
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                      height: 1.05,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: Colors.white.withOpacity(0.10),
                ),
              ),
              child: Text(
                roleLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 10,
                  height: 1.0,
                ),
              ),
            ),
            const Spacer(),
            InkWell(
              onTap: _openWorkspacePrimary,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.open_in_new_rounded,
                      size: 15,
                      color: _homeDesign.primaryColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Открыть',
                      style: TextStyle(
                        color: _homeDesign.primaryColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withOpacity(0.74),
            fontWeight: FontWeight.w500,
            fontSize: 10.5,
            height: 1.18,
          ),
        ),
      ],
    );
  }

  return Row(
    children: [
      _teamLogoWidget(
        teamName: targetName,
        logoUrl: logoUrl,
        accent: Colors.white,
        size: _isTablet(context) ? 64 : 56,
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
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      height: 1.05,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.10),
                    ),
                  ),
                  child: Text(
                    roleLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                      height: 1.0,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              targetName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withOpacity(0.92),
                fontWeight: FontWeight.w700,
                fontSize: 13,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withOpacity(0.74),
                fontWeight: FontWeight.w500,
                fontSize: 11,
                height: 1.18,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(width: 12),
      InkWell(
        onTap: _openWorkspacePrimary,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.open_in_new_rounded,
                size: 16,
                color: _homeDesign.primaryColor,
              ),
              const SizedBox(width: 7),
              Text(
                'Открыть',
                style: TextStyle(
                  color: _homeDesign.primaryColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

Widget _buildWorkspaceSafeStatsGrid(BuildContext context) {
  final cards = _buildWorkspaceStatCards();
  final tablet = _isTablet(context);

  return GridView.builder(
    padding: EdgeInsets.zero,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: cards.length,
    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: tablet ? 4 : 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: tablet ? 1.8 : 1.55,
    ),
    itemBuilder: (context, index) {
      final item = cards[index];
      return _buildWorkspaceSafeStatTile(
        color: item['color'] as Color,
        icon: item['icon'] as IconData,
        title: item['title'] as String,
        value: item['value'] as String,
      );
    },
  );
}

Widget _buildWorkspaceSafeStatTile({
  required Color color,
  required IconData icon,
  required String title,
  required String value,
}) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.08),
      borderRadius: BorderRadius.circular(22),
      border: Border.all(
        color: Colors.white.withOpacity(0.08),
      ),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.18),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 18,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.76),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _buildWorkspaceSafeSectionCard({
  required String title,
  required IconData icon,
  required Color accent,
  required Widget child,
  Widget? trailing,
}) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.08),
      borderRadius: BorderRadius.circular(26),
      border: Border.all(
        color: Colors.white.withOpacity(0.08),
      ),
    ),
    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.20),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 19,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 13.5,
                  height: 1.0,
                ),
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}

Widget _buildWorkspaceSafePillButton({
  required String label,
  required VoidCallback onTap,
}) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(999),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 11,
          height: 1.0,
        ),
      ),
    ),
  );
}

Widget _buildWorkspaceSafeTextAction({
  required String label,
  required VoidCallback onTap,
}) {
  return TextButton(
    onPressed: onTap,
    style: TextButton.styleFrom(
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
    child: Text(
      label,
      style: const TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 11,
      ),
    ),
  );
}

Widget _buildWorkspaceSafeTrackerGrid(BuildContext context) {
  final pulse = (_trackerSummary['pulse'] ?? '124').toString();
  final readiness = (_trackerSummary['readiness'] ?? '79%').toString();
  final load = (_trackerSummary['load'] ?? 'Рабочая').toString();
  final sprints = (_trackerSummary['sprints'] ?? '96').toString();

  return LayoutBuilder(
    builder: (context, constraints) {
      final itemWidth = (constraints.maxWidth - 10) / 2;

      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          SizedBox(
            width: itemWidth,
            child: _buildWorkspaceSafeMetricTile(
              title: 'Пульс',
              value: pulse,
              icon: Icons.favorite_rounded,
              color: Colors.redAccent,
            ),
          ),
          SizedBox(
            width: itemWidth,
            child: _buildWorkspaceSafeMetricTile(
              title: 'Готовность',
              value: readiness,
              icon: Icons.bolt_rounded,
              color: const Color(0xFFF59E0B),
            ),
          ),
          SizedBox(
            width: itemWidth,
            child: _buildWorkspaceSafeMetricTile(
              title: 'Нагрузка',
              value: load,
              icon: Icons.fitness_center_rounded,
              color: const Color(0xFF3B82F6),
            ),
          ),
          SizedBox(
            width: itemWidth,
            child: _buildWorkspaceSafeMetricTile(
              title: 'Спринты',
              value: sprints,
              icon: Icons.speed_rounded,
              color: const Color(0xFFEC4899),
            ),
          ),
        ],
      );
    },
  );
}

Widget _buildWorkspaceSafeMetricTile({
  required String title,
  required String value,
  required IconData icon,
  required Color color,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.10),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: Colors.white.withOpacity(0.08),
      ),
    ),
    child: Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withOpacity(0.18),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(
            icon,
            size: 16,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.78),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _buildWorkspaceSafeMatchesList(BuildContext context) {
  final visibleItems = _recentMatches.take(_isTablet(context) ? 3 : 2).toList();

  if (visibleItems.isEmpty) {
    return _buildWorkspaceEmpty('Матчи пока не найдены');
  }

  return Column(
    children: List.generate(visibleItems.length, (index) {
      final match = visibleItems[index];
      return Padding(
        padding: EdgeInsets.only(
          bottom: index == visibleItems.length - 1 ? 0 : 8,
        ),
        child: _buildWorkspaceSafeMatchTile(match),
      );
    }),
  );
}

Widget _buildWorkspaceSafeMatchTile(Map<String, dynamic> match) {
  final title = (match['title'] ??
          match['match_title'] ??
          match['opponent'] ??
          'Матч')
      .toString();

  final subtitle = (match['subtitle'] ??
          match['date'] ??
          match['tournament'] ??
          match['competition'] ??
          '')
      .toString();

  final score = (match['score'] ?? match['status'] ?? '').toString();

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.08),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: Colors.white.withOpacity(0.06),
      ),
    ),
    child: Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.10),
            borderRadius: BorderRadius.circular(11),
          ),
          child: const Icon(
            Icons.sports_soccer_rounded,
            size: 16,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  height: 1.05,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.70),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    height: 1.0,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (score.isNotEmpty) ...[
          const SizedBox(width: 8),
          Text(
            score,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),
        ],
      ],
    ),
  );
}

Widget _buildWorkspaceSafeReportsList(BuildContext context) {
  final visibleItems = _workspaceReports.take(_isTablet(context) ? 3 : 3).toList();

  if (visibleItems.isEmpty) {
    return _buildWorkspaceEmpty('Отчёты пока не найдены');
  }

  return Column(
    children: List.generate(visibleItems.length, (index) {
      final report = visibleItems[index];
      return Padding(
        padding: EdgeInsets.only(
          bottom: index == visibleItems.length - 1 ? 0 : 8,
        ),
        child: _buildWorkspaceSafeReportTile(report),
      );
    }),
  );
}

Widget _buildWorkspaceSafeReportTile(Map<String, dynamic> report) {
  final title =
      (report['title'] ?? report['name'] ?? report['label'] ?? 'Отчёт')
          .toString();

  final subtitle = (report['subtitle'] ??
          report['date'] ??
          report['period'] ??
          report['description'] ??
          '')
      .toString();

  final value = (report['value'] ?? report['status'] ?? '').toString();

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.08),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: Colors.white.withOpacity(0.06),
      ),
    ),
    child: Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.10),
            borderRadius: BorderRadius.circular(11),
          ),
          child: const Icon(
            Icons.insert_chart_outlined_rounded,
            size: 16,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  height: 1.05,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.70),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    height: 1.0,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (value.isNotEmpty) ...[
          const SizedBox(width: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),
        ],
      ],
    ),
  );
}


 Widget _buildWorkspaceHeroHeader(
  BuildContext context, {
  required String title,
  required String subtitle,
  required String targetName,
  required String roleLabel,
}) {
  final logoUrl = _currentTeamLogoUrl.trim();

  return LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 430;

      if (compact) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _teamLogoWidget(
                  teamName: targetName,
                  logoUrl: logoUrl,
                  accent: Colors.white,
                  size: 56,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: _responsiveFont(
                            context,
                            mobile: 17,
                            tablet: 18,
                          ),
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              targetName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.92),
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                height: 1.05,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.10),
                              ),
                            ),
                            child: Text(
                              roleLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 10,
                                height: 1.0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withOpacity(0.74),
                fontWeight: FontWeight.w500,
                fontSize: 10.5,
                height: 1.18,
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: InkWell(
                onTap: _openWorkspacePrimary,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.open_in_new_rounded,
                        size: 15,
                        color: _homeDesign.primaryColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Открыть',
                        style: TextStyle(
                          color: _homeDesign.primaryColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      }

      return Row(
        children: [
          _teamLogoWidget(
            teamName: targetName,
            logoUrl: logoUrl,
            accent: Colors.white,
            size: _isTablet(context) ? 64 : 56,
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
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: _responsiveFont(
                            context,
                            mobile: 18,
                            tablet: 20,
                          ),
                          height: 1.05,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.10),
                        ),
                      ),
                      child: Text(
                        roleLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  targetName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.92),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.74),
                    fontWeight: FontWeight.w500,
                    fontSize: 11,
                    height: 1.18,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          InkWell(
            onTap: _openWorkspacePrimary,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.open_in_new_rounded,
                    size: 16,
                    color: _homeDesign.primaryColor,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    'Открыть',
                    style: TextStyle(
                      color: _homeDesign.primaryColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    },
  );
}

 Widget _buildWorkspaceStatsGrid(BuildContext context) {
  final cards = _buildWorkspaceStatCards();
  final tablet = _isTablet(context);

  return SizedBox(
    height: tablet ? 116 : 164,
    child: GridView.builder(
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: tablet ? 4 : 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: tablet ? 1.7 : 1.55,
      ),
      itemBuilder: (context, index) {
        final item = cards[index];
        return _buildWorkspaceMiniStatCard(
          color: item['color'] as Color,
          icon: item['icon'] as IconData,
          title: item['title'] as String,
          value: item['value'] as String,
        );
      },
    ),
  );
}


List<Map<String, dynamic>> _buildWorkspaceStatCards() {
  if (_isClubRole) {
    return [
      {
        'title': 'Команды',
        'value': '${_clubTeams.isNotEmpty ? _clubTeams.length : 0}',
        'icon': Icons.groups_rounded,
        'color': const Color(0xFF2563EB),
      },
      {
        'title': 'Тренеры',
        'value': '${_clubTrainers.length}',
        'icon': Icons.person_rounded,
        'color': const Color(0xFF10B981),
      },
      {
        'title': 'События',
        'value': _buildClubEventPreview(),
        'icon': Icons.calendar_month_rounded,
        'color': const Color(0xFFEA580C),
      },
      {
        'title': 'Планы',
        'value': _buildClubPlanPreview(),
        'icon': Icons.menu_book_rounded,
        'color': const Color(0xFF7C3AED),
      },
    ];
  }

  if (_isCoachRole) {
    return [
      {
        'title': 'Мои команды',
        'value':
            '${_myTeams.isNotEmpty ? _myTeams.length : (_currentTeamId > 0 ? 1 : 0)}',
        'icon': Icons.groups_rounded,
        'color': const Color(0xFF2563EB),
      },
      {
        'title': 'Матчи',
        'value': '${_recentMatches.length}',
        'icon': Icons.sports_score_rounded,
        'color': const Color(0xFFEA580C),
      },
      {
        'title': 'Отчёты',
        'value': '${_workspaceReports.length}',
        'icon': Icons.analytics_rounded,
        'color': const Color(0xFF7C3AED),
      },
    ];
  }

  if (_isPlayerRole || _isParentRole) {
    return [
      {
        'title': 'Матчи',
        'value': '${_recentMatches.length}',
        'icon': Icons.sports_soccer_rounded,
        'color': const Color(0xFF2563EB),
      },
      {
        'title': 'Отчёты',
        'value': '${_workspaceReports.length}',
        'icon': Icons.analytics_rounded,
        'color': const Color(0xFF7C3AED),
      },
      {
        'title': 'Статус',
        'value': '${_trackerSummary['readiness'] ?? '—'}',
        'icon': Icons.health_and_safety_rounded,
        'color': const Color(0xFF10B981),
      },
    ];
  }

  return [
    {
      'title': 'Команды',
      'value': '0',
      'icon': Icons.groups_rounded,
      'color': const Color(0xFF2563EB),
    },
    {
      'title': 'Матчи',
      'value': '${_recentMatches.length}',
      'icon': Icons.sports_score_rounded,
      'color': const Color(0xFFEA580C),
    },
    {
      'title': 'Отчёты',
      'value': '${_workspaceReports.length}',
      'icon': Icons.analytics_rounded,
      'color': const Color(0xFF7C3AED),
    },
  ];
}


Widget _buildWorkspaceMiniStatCard({
  required Color color,
  required IconData icon,
  required String title,
  required String value,
}) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.08),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: Colors.white.withOpacity(0.08),
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.74),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
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

Widget _buildWorkspaceTrackerCard(BuildContext context) {
  final title = (_trackerSummary['title'] ?? 'Состояние').toString();
  final pulse = (_trackerSummary['pulse'] ?? '124').toString();
  final readiness = (_trackerSummary['readiness'] ?? '79%').toString();
  final load = (_trackerSummary['load'] ?? 'Рабочая').toString();
  final sprints = (_trackerSummary['sprints'] ?? '96').toString();

  return _buildWorkspaceGlassCard(
    title: title,
    icon: Icons.monitor_heart_rounded,
    accent: const Color(0xFF1FA37A),
    trailing: InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const TrackingModeScreen(),
          ),
        );
      },
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: const Text(
          'Трекер',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 11,
            height: 1.0,
          ),
        ),
      ),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - 10) / 2;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            SizedBox(
              width: itemWidth,
              child: _buildTrackerCompactMetric(
                title: 'Пульс',
                value: pulse,
                icon: Icons.favorite_rounded,
                color: Colors.redAccent,
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _buildTrackerCompactMetric(
                title: 'Готовность',
                value: readiness,
                icon: Icons.bolt_rounded,
                color: const Color(0xFFF59E0B),
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _buildTrackerCompactMetric(
                title: 'Нагрузка',
                value: load,
                icon: Icons.fitness_center_rounded,
                color: const Color(0xFF3B82F6),
              ),
            ),
            SizedBox(
              width: itemWidth,
              child: _buildTrackerCompactMetric(
                title: 'Спринты',
                value: sprints,
                icon: Icons.speed_rounded,
                color: const Color(0xFFEC4899),
              ),
            ),
          ],
        );
      },
    ),
  );
}

Widget _buildTrackerCompactMetric({
  required String title,
  required String value,
  required IconData icon,
  required Color color,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.10),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: Colors.white.withOpacity(0.08),
      ),
    ),
    child: Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withOpacity(0.18),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(
            icon,
            size: 16,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.78),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

  Widget _buildTrackerMetric({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withOpacity(0.06),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withOpacity(0.16),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 15,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.68),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

Widget _buildWorkspaceMatchesCard(BuildContext context) {
  final visibleItems = _recentMatches.take(_isTablet(context) ? 3 : 2).toList();

  return _buildWorkspaceGlassCard(
    title: _isPlayerRole || _isParentRole ? 'Последние матчи' : 'Матчи и события',
    icon: Icons.sports_soccer_rounded,
    accent: const Color(0xFF2563EB),
    trailing: TextButton(
      onPressed: _openScheduleAll,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: const Text(
        'Все',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    ),
    child: visibleItems.isEmpty
        ? _buildWorkspaceEmpty('Матчи пока не найдены')
        : Column(
            children: List.generate(visibleItems.length, (index) {
              final match = visibleItems[index];
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == visibleItems.length - 1 ? 0 : 8,
                ),
                child: _buildWorkspaceMatchCompactTile(match),
              );
            }),
          ),
  );
}


Widget _buildWorkspaceMatchCompactTile(Map<String, dynamic> match) {
  final title = (match['title'] ??
          match['match_title'] ??
          match['opponent'] ??
          'Матч')
      .toString();

  final subtitle = (match['subtitle'] ??
          match['date'] ??
          match['tournament'] ??
          match['competition'] ??
          '')
      .toString();

  final score = (match['score'] ?? match['status'] ?? '').toString();

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.08),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: Colors.white.withOpacity(0.06),
      ),
    ),
    child: Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.10),
            borderRadius: BorderRadius.circular(11),
          ),
          child: const Icon(
            Icons.sports_soccer_rounded,
            size: 16,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  height: 1.05,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.70),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    height: 1.0,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (score.isNotEmpty) ...[
          const SizedBox(width: 8),
          Text(
            score,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),
        ],
      ],
    ),
  );
}
  Widget _buildWorkspaceMatchTile(Map<String, dynamic> match) {
    final title = (match['title'] ??
            match['match_title'] ??
            match['teams'] ??
            'Матч команды')
        .toString();
    final date = (match['date'] ?? match['match_date'] ?? '').toString();
    final status = (match['status'] ?? 'Запланирован').toString();
    final score = (match['score'] ?? '—').toString();
    final location =
        (match['location'] ?? match['venue'] ?? match['place'] ?? '').toString();

    final statusColor = status.toLowerCase().contains('заверш')
        ? SportPalette.primaryGreen
        : status.toLowerCase().contains('подг')
            ? SportPalette.orange
            : SportPalette.blue;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withOpacity(0.06),
        ),
      ),
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.sports_score_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 11.5,
                    height: 1.16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  location.isNotEmpty ? '$date · $location' : date,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.64),
                    fontWeight: FontWeight.w600,
                    fontSize: 9.5,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                score,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 7,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 8.5,
                    height: 1.0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

Widget _buildWorkspaceReportsCard(BuildContext context) {
  final visibleItems =
      _workspaceReports.take(_isTablet(context) ? 3 : 3).toList();

  return _buildWorkspaceGlassCard(
    title: _isPlayerRole ? 'Отчёты и статистика' : 'Отчёты и аналитика',
    icon: Icons.analytics_rounded,
    accent: const Color(0xFF7C3AED),
    trailing: TextButton(
      onPressed: _openWorkspacePrimary,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: const Text(
        'Открыть',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    ),
    child: visibleItems.isEmpty
        ? _buildWorkspaceEmpty('Отчёты пока не найдены')
        : Column(
            children: List.generate(visibleItems.length, (index) {
              final report = visibleItems[index];
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == visibleItems.length - 1 ? 0 : 8,
                ),
                child: _buildWorkspaceReportCompactTile(report),
              );
            }),
          ),
  );
}


Widget _buildWorkspaceReportCompactTile(Map<String, dynamic> report) {
  final title =
      (report['title'] ?? report['name'] ?? report['label'] ?? 'Отчёт')
          .toString();

  final subtitle = (report['subtitle'] ??
          report['date'] ??
          report['period'] ??
          report['description'] ??
          '')
      .toString();

  final value = (report['value'] ?? report['status'] ?? '').toString();

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.08),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: Colors.white.withOpacity(0.06),
      ),
    ),
    child: Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.10),
            borderRadius: BorderRadius.circular(11),
          ),
          child: const Icon(
            Icons.insert_chart_outlined_rounded,
            size: 16,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  height: 1.05,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.70),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    height: 1.0,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (value.isNotEmpty) ...[
          const SizedBox(width: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),
        ],
      ],
    ),
  );
}

  Widget _buildWorkspaceReportTile(Map<String, dynamic> report) {
    final title = (report['title'] ?? 'Отчёт').toString();
    final subtitle = (report['subtitle'] ?? report['description'] ?? '')
        .toString();
    final type = (report['type'] ?? 'Отчёт').toString();
    final value = (report['value'] ?? report['status'] ?? '').toString();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withOpacity(0.06),
        ),
      ),
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: SportPalette.purple.withOpacity(0.20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.insights_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 11.5,
                          height: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        type,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.82),
                          fontWeight: FontWeight.w700,
                          fontSize: 8.5,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ],
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.64),
                      fontWeight: FontWeight.w600,
                      fontSize: 9.5,
                      height: 1.18,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (value.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 10.5,
                height: 1.0,
              ),
            ),
          ],
        ],
      ),
    );
  }

Widget _buildWorkspaceGlassCard({
  required String title,
  required IconData icon,
  required Color accent,
  required Widget child,
  Widget? trailing,
}) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.08),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: Colors.white.withOpacity(0.08),
      ),
    ),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.20),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 19,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13.5,
                    height: 1.0,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 12),
          Expanded(child: child),
        ],
      ),
    ),
  );
}
  Widget _buildWorkspaceEmpty(String text) {
    return Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white.withOpacity(0.64),
          fontSize: 11,
          fontWeight: FontWeight.w600,
          height: 1.2,
        ),
      ),
    );
  }

  Widget _buildQuickActionCarousel() {
    final isDenseLayout = _isLandscape(context) || _isTablet(context);

    return Container(
      decoration: BoxDecoration(
        color: _homeDesign.cardColor,
        borderRadius: BorderRadius.circular(_homeDesign.cardRadius),
        border: Border.all(
          color: _homeDesign.borderColor,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(_homeDesign.shadowOpacity),
            blurRadius: _homeDesign.shadowBlur,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _homeDesign.primaryColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  Icons.flash_on_rounded,
                  color: _homeDesign.primaryColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Быстрый доступ',
                      style: TextStyle(
                        fontSize: _responsiveFont(
                          context,
                          mobile: 13,
                          tablet: 13.8,
                        ),
                        fontWeight: FontWeight.w900,
                        color: _homeDesign.textColor,
                        height: 1.05,
                      ),
                    ),
                    Text(
                      'Основные модули без перегруза',
                      style: TextStyle(
                        fontSize: _responsiveFont(
                          context,
                          mobile: 10,
                          tablet: 10.5,
                        ),
                        color: _homeDesign.mutedTextColor,
                        height: 1.05,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (isDenseLayout)
            Expanded(
              child: GridView.builder(
                padding: EdgeInsets.zero,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _headerActions.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _isTablet(context) ? 4 : 3,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: _isTablet(context) ? 2.4 : 2.1,
                ),
                itemBuilder: (context, index) {
                  final item = _headerActions[index];
                  return _buildQuickActionCard(
                    item,
                    index,
                    dense: true,
                  );
                },
              ),
            )
          else
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: PageView.builder(
                      controller: _quickActionsController,
                      physics: const BouncingScrollPhysics(),
                      itemCount: _headerActions.length,
                      itemBuilder: (context, index) {
                        final item = _headerActions[index];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _buildQuickActionCard(
                            item,
                            index,
                            dense: false,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildPagerDots(
                    count: _headerActions.length,
                    currentPage: _quickActionPage,
                    activeColor: _homeDesign.primaryColor,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard(
    _HeaderActionItem item,
    int index, {
    required bool dense,
  }) {
    final color = [
      const Color(0xFF0F766E),
      const Color(0xFF2563EB),
      const Color(0xFF7C3AED),
      _homeDesign.primaryColor,
      const Color(0xFFDB2777),
      const Color(0xFFEA580C),
      const Color(0xFF0891B2),
    ][index % 7];

    final titleSize = dense
        ? _responsiveFont(context, mobile: 10.5, tablet: 11.5)
        : _responsiveFont(context, mobile: 13, tablet: 13.5);

    final subtitleSize = dense
        ? _responsiveFont(context, mobile: 8.4, tablet: 9)
        : _responsiveFont(context, mobile: 9, tablet: 9.5);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(_homeDesign.cardRadius),
        onTap: () => _onQuickAction(item.keyName),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_homeDesign.cardRadius),
            color: color.withOpacity(0.08),
            border: Border.all(
              color: color.withOpacity(0.18),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: dense ? 8 : 10,
              vertical: dense ? 8 : 9,
            ),
            child: Row(
              children: [
                Container(
                  width: dense ? 30 : 34,
                  height: dense ? 30 : 34,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    item.icon,
                    color: color,
                    size: dense ? 16 : 18,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: dense
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.titleRu,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _homeDesign.textColor,
                                fontWeight: FontWeight.w900,
                                fontSize: titleSize,
                                height: 1.05,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.subtitleRu,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _homeDesign.mutedTextColor,
                                fontWeight: FontWeight.w600,
                                fontSize: subtitleSize,
                                height: 1.05,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.titleRu,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _homeDesign.textColor,
                                fontWeight: FontWeight.w900,
                                fontSize: titleSize,
                                height: 1.05,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.subtitleRu,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _homeDesign.mutedTextColor,
                                fontWeight: FontWeight.w600,
                                fontSize: subtitleSize,
                                height: 1.05,
                              ),
                            ),
                            const Spacer(),
                            Row(
                              children: [
                                Text(
                                  'Открыть',
                                  style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 9,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Icon(
                                  Icons.arrow_forward_rounded,
                                  color: color,
                                  size: 12,
                                ),
                              ],
                            ),
                          ],
                        ),
                ),
                if (dense)
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: color,
                      size: 16,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPagerDots({
    required int count,
    required int currentPage,
    required Color activeColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final active = index == currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 16 : 5,
          height: 5,
          decoration: BoxDecoration(
            color: active ? activeColor : activeColor.withOpacity(0.18),
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }

  List<Widget> _buildToolsSections(BuildContext context) {
  final sections = <Widget>[];

  final events = _eventsCache[selectedSport ?? 'Футбол'] ?? [];
  final venues = List<dynamic>.from(dataCache['venues'] ?? []);
  final teams = List<Map<String, dynamic>>.from(dataCache['teams'] ?? []);

 
  for (final config in _homeDesign.sections.where(
    (s) => s.visible && s.type != HomeSectionType.tips,
  )) {
    Widget? builtSection;

    switch (config.type) {
      case HomeSectionType.ringBanner:
        builtSection = null;
        break;

      case HomeSectionType.reels:
      case HomeSectionType.posts:
        builtSection = null;
        break;

      case HomeSectionType.promo:
        if (_homeDesign.showPromoBanner) {
          builtSection = _buildPromoSection(config);
        }
        break;

      case HomeSectionType.innovations:
        builtSection = null;
        break;

      case HomeSectionType.events:
        if (events.isNotEmpty) {
          builtSection = _buildEventsSection(config, events, context);
        }
        break;

      case HomeSectionType.venues:
      case HomeSectionType.clubs:
      case HomeSectionType.tickets:
        builtSection = null;
        break;

      case HomeSectionType.tips:
        builtSection = null;
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

  final HomeSectionConfig? tipsConfig = _homeDesign.sections
      .where((s) => s.visible && s.type == HomeSectionType.tips)
      .cast<HomeSectionConfig?>()
      .firstWhere((s) => s != null, orElse: () => null);

  if (tipsConfig != null) {
    sections.add(const SizedBox(height: 8));
    sections.add(
      Padding(
        padding: EdgeInsets.symmetric(horizontal: tipsConfig.innerPadding),
        child: _buildTipsSection(tipsConfig),
      ),
    );
    sections.add(SizedBox(height: tipsConfig.bottomSpacing));
    sections.add(SizedBox(height: _homeDesign.sectionGap));
  }

  if (sections.isNotEmpty) {
    sections.removeLast();
  }

  return sections;
  }



List<Widget> _buildNewsSections(BuildContext context) {
  final sections = <Widget>[];

  if (_recommendedVideoFolders.isNotEmpty) {
    sections.add(_buildRecommendedVideoFoldersSection(context));
    sections.add(SizedBox(height: _homeDesign.sectionGap));
  }

  if (_reelsData.isNotEmpty) {
    final reelsConfig = _homeDesign.sections.firstWhere(
      (e) => e.type == HomeSectionType.reels,
      orElse: () => _homeDesign.sections.first,
    );
    sections.add(_buildVideoSection(reelsConfig, context));
    sections.add(SizedBox(height: _homeDesign.sectionGap));
  }

  if (sections.isNotEmpty) {
    sections.removeLast();
  }

  return sections;
}

  Widget _buildCard({
    required Widget child,
    required Color? accentOverride,
    VoidCallback? onTap,
    EdgeInsetsGeometry padding = const EdgeInsets.all(10),
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
              offset: const Offset(0, 4),
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
              blurRadius: (_homeDesign.shadowBlur + 4).clamp(0, 40),
              offset: const Offset(0, 8),
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
              offset: const Offset(0, 4),
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
    BuildContext context,
  ) {
    final first = posts.first;
    final rest = posts.skip(1).take(_isTablet(context) ? 5 : 4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeaderFromDesign(
          config: config,
          title: 'Новости сообщества',
          subtitle: 'Главное и свежее',
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
        const SizedBox(height: 12),
        if (_isTablet(context))
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 6,
                child: _buildFeaturedNewsCard(first, config),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 5,
                child: Column(
                  children: rest
                      .map(
                        (post) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: _buildCompactNewsRow(post, config),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          )
        else ...[
          _buildFeaturedNewsCard(first, config),
          if (rest.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...rest.map(
              (post) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _buildCompactNewsRow(post, config),
              ),
            ),
          ],
        ],
      ],
    );
  }

 Widget _buildFeaturedNewsCard(
  Map<String, dynamic> post,
  HomeSectionConfig config, {
  double? customImageHeight,
  int customTextLines = 2,
}) {
    final title = _stripHtml((post['title'] ?? '').toString());
    final text = _stripHtml((post['text'] ?? '').toString());
    final imageUrl = (post['imageUrl'] ?? '').toString();
    final author = (post['authorName'] ?? 'Пользователь').toString();
    final avatarUrl = (post['authorAvatar'] ?? '').toString();
    final hasImage = imageUrl.isNotEmpty;

    return _buildCard(
      accentOverride: config.accentOverride,
      padding: EdgeInsets.zero,
      onTap: () => _openPost(post),
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
  height: customImageHeight ?? (_isTablet(context) ? 180 : 160),
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
                            size: 36,
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
                    left: 10,
                    right: 10,
                    bottom: 10,
                    child: Text(
                      title.isNotEmpty ? title : 'Главная новость',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        height: 1.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!hasImage)
                  Text(
                    title.isNotEmpty ? title : 'Главная новость',
                  maxLines: customTextLines,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: _homeDesign.cardTitleSize,
                      fontWeight: FontWeight.w900,
                      color: _homeDesign.textColor,
                    ),
                  ),
                if (!hasImage) const SizedBox(height: 6),
                Row(
                  children: [
                    _authorAvatarWidget(
                      avatarUrl: avatarUrl,
                      author: author,
                      radius: 12,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: _homeDesign.smallTextSize - 1,
                          fontWeight: FontWeight.w800,
                          color: _homeDesign.textColor,
                        ),
                      ),
                    ),
                    Text(
                      _formatPostDateHome(post['date'] as DateTime),
                      style: TextStyle(
                        fontSize: _homeDesign.smallTextSize - 2,
                        color: _homeDesign.mutedTextColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  text.isNotEmpty ? text : 'Интересная публикация',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: _homeDesign.bodyTextSize - 1,
                    color: _homeDesign.textColor,
                    height: 1.3,
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
  HomeSectionConfig config, {
  bool forceExpanded = false,
}) {
  final title = _stripHtml((post['title'] ?? '').toString());
  final text = _stripHtml((post['text'] ?? '').toString());
  final imageUrl = (post['imageUrl'] ?? '').toString();
  final hasImage = imageUrl.isNotEmpty;
  final isTablet = _isTablet(context);
final tileSize = forceExpanded ? 78.0 : (isTablet ? 64.0 : 72.0);

  return _buildCard(
    accentOverride: config.accentOverride,
    padding: const EdgeInsets.all(10),
    onTap: () => _openPost(post),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
         width: tileSize,
height: tileSize,
          decoration: BoxDecoration(
            color: _homeDesign.primaryColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.hardEdge,
          child: hasImage
              ? Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.image_rounded,
                    color: _homeDesign.primaryColor,
                    size: 22,
                  ),
                )
              : Icon(
                  Icons.article_rounded,
                  color: _homeDesign.primaryColor,
                  size: 24,
                ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title.isNotEmpty ? title : 'Новость',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: isTablet
                      ? _homeDesign.bodyTextSize - 1
                      : _homeDesign.bodyTextSize,
                  fontWeight: FontWeight.w800,
                  color: _homeDesign.textColor,
                  height: 1.18,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                text.isNotEmpty ? text : 'Материал сообщества',
               maxLines: forceExpanded ? 2 : (isTablet ? 1 : 2),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: _homeDesign.smallTextSize,
                  color: _homeDesign.mutedTextColor,
                  height: 1.18,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _formatPostDateHome(post['date'] as DateTime),
                style: TextStyle(
                  fontSize: _homeDesign.smallTextSize - 1,
                  color: _homeDesign.mutedTextColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        Icon(
          Icons.chevron_right_rounded,
          color: _homeDesign.mutedTextColor,
          size: 18,
        ),
      ],
    ),
  );
}
Widget _buildSectionHeaderFromDesign({
  required HomeSectionConfig config,
  required String title,
  required String subtitle,
  required VoidCallback? onSeeAll,
}) {
  final accentColor = config.accentOverride ?? _homeDesign.primaryColor;
  final effectiveTitle = config.customTitle?.trim().isNotEmpty == true
      ? config.customTitle!
      : title;
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
          height: 14,
        ),
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (_homeDesign.showSectionIcons && config.showIcon)
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(_homeDesign.smallRadius),
              ),
              child: Icon(
                _sectionIcon(config.type),
                color: accentColor,
                size: 16,
              ),
            ),
          if (_homeDesign.showSectionIcons && config.showIcon)
            const SizedBox(width: 8),
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
                          fontSize: _homeDesign.sectionTitleSize - 1,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                          letterSpacing: -0.2,
                          color: _homeDesign.textColor,
                        ),
                      ),
                    ),
                    if (config.showBadge &&
                        (config.badgeText?.trim().isNotEmpty ?? false)) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: (config.badgeColor ?? accentColor)
                              .withOpacity(0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          config.badgeText!,
                          style: TextStyle(
                            fontSize: 8,
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
                      fontSize: _homeDesign.sectionSubtitleSize - 1,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(
                    _homeDesign.smallRadius,
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      'Все',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: accentColor,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 14,
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
          padding: const EdgeInsets.only(top: 8),
          child: Divider(
            color: _homeDesign.borderColor,
            height: 1,
          ),
        ),
    ],
  );
}
  Widget _buildVideoSection(
    HomeSectionConfig config,
    BuildContext context,
  ) {
    final visibleCount = _reelsData.length > config.itemLimit
        ? config.itemLimit
        : _reelsData.length;

    final double reelHeight = _isTablet(context)
        ? 250
        : (config.cardHeight < 200 ? 250 : config.cardHeight + 40);

    final double reelWidth = _isTablet(context)
        ? 180
        : (config.cardWidth < 150 ? 160 : config.cardWidth - 10);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeaderFromDesign(
          config: config,
          title: 'Популярные видео',
          subtitle: 'Лучшие ролики',
          onSeeAll: _openReels,
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: reelHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: visibleCount,
            itemBuilder: (context, index) {
              final reel = _reelsData[index];
              return Padding(
                padding: EdgeInsets.only(
                  right: index == visibleCount - 1 ? 0 : 12,
                ),
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
    final reelId = reel['id'] is int
        ? reel['id'] as int
        : int.tryParse('${reel['id']}');

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
                  top: 8,
                  left: 8,
                  right: 8,
                  child: Text(
                    username.isEmpty ? 'Sportoteka' : username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 9,
                    ),
                  ),
                ),
                Center(
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: (_configAccent(config) ?? _homeDesign.primaryColor)
                          .withOpacity(0.92),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.18),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    desc,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: _homeDesign.cardTitleSize - 2,
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
                      const SizedBox(width: 8),
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
        child: Icon(
          Icons.videocam_rounded,
          color: _homeDesign.primaryColor,
          size: 32,
        ),
      ),
    );
  }

  Widget _buildRecommendedVideoFoldersSection(BuildContext context) {
    if (_recommendedVideoFolders.isEmpty) {
      return const SizedBox.shrink();
    }

    final headerConfig = _homeDesign.sections.firstWhere(
      (e) => e.type == HomeSectionType.innovations,
      orElse: () => _homeDesign.sections.first,
    );

    final cardWidth = _isTablet(context) ? 220.0 : 240.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
  children: [
    Expanded(
      child: _buildSectionHeaderFromDesign(
        config: headerConfig,
        title: 'Видеоуроки',
        subtitle: 'Рекомендуемые папки',
        onSeeAll: null,
      ),
    ),
    TextButton(
      onPressed: _openVideoLessons,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      child: Text(
        'Все',
        style: TextStyle(
          color: _homeDesign.primaryColor,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    ),
  ],
),
        const SizedBox(height: 12),
        SizedBox(
          height: 180,
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
                  right: index == _recommendedVideoFolders.length - 1 ? 0 : 12,
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
                    width: cardWidth,
                    decoration: BoxDecoration(
                      color: _homeDesign.cardColor,
                      borderRadius:
                          BorderRadius.circular(_homeDesign.cardRadius),
                      border: Border.all(
                        color: _homeDesign.borderColor.withOpacity(0.9),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(
                            _homeDesign.shadowOpacity,
                          ),
                          blurRadius: _homeDesign.shadowBlur,
                          offset: const Offset(0, 4),
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
                            height: 100,
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
                                  top: 6,
                                  right: 6,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.25),
                                      borderRadius:
                                          BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      '$lessonCount',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 8,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ),
                                const Center(
                                  child: Icon(
                                    Icons.play_circle_fill_rounded,
                                    color: Colors.white,
                                    size: 38,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildHomeAuthorAvatar(
                                  avatarUrl: authorAvatar,
                                  author: authorName,
                                  radius: 16,
                                  color: color,
                                ),
                                const SizedBox(width: 6),
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
                                              _homeDesign.cardTitleSize - 2,
                                          color: _homeDesign.textColor,
                                          height: 1.2,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        authorName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 9,
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
          size: 36,
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
                fontSize: radius * 0.6,
              ),
            )
          : null,
    );
  }

  Widget _buildEventsSection(
    HomeSectionConfig config,
    List<Map<String, dynamic>> events,
    BuildContext context,
  ) {
    final cardWidth = _isTablet(context) ? 200.0 : config.cardWidth;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeaderFromDesign(
          config: config,
          title: 'Мероприятия',
          subtitle: 'Предстоящие события',
          onSeeAll: _openEventsAll,
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: _isTablet(context) ? 200 : config.cardHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount:
                events.length > config.itemLimit ? config.itemLimit : events.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.only(
                  right: index == events.length - 1 ? 0 : 12,
                ),
                child: SizedBox(
                  width: cardWidth,
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
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: _homeDesign.cardTitleSize - 1,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                      color: _homeDesign.textColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (date.isNotEmpty) ...[
                    _metaRow(Icons.calendar_today_rounded, date),
                    const SizedBox(height: 4),
                  ],
                  _metaRow(Icons.location_on_rounded, location),
                  const Spacer(),
                  Row(
                    children: [
                      Text(
                        'Открыть',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                          color: _configAccent(config) ?? _homeDesign.primaryColor,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: _homeDesign.mutedTextColor,
                        size: 16,
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
          size: 36,
        ),
      ),
    );
  }

  Widget _buildVenuesSection(
    HomeSectionConfig config,
    List<dynamic> venues,
    BuildContext context,
  ) {
    final cardWidth = _isTablet(context) ? 200.0 : config.cardWidth;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeaderFromDesign(
          config: config,
          title: 'Площадки',
          subtitle: 'Бронирование',
          onSeeAll: venues.isNotEmpty ? _openVenuesAll : null,
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: _isTablet(context) ? 200 : config.cardHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount:
                venues.length > config.itemLimit ? config.itemLimit : venues.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.only(
                  right: index == venues.length - 1 ? 0 : 12,
                ),
                child: SizedBox(
                  width: cardWidth,
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
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (venue['title'] ?? '').toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: _homeDesign.cardTitleSize - 1,
                      fontWeight: FontWeight.w800,
                      color: _homeDesign.textColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.place_rounded,
                        size: 11,
                        color: _homeDesign.mutedTextColor,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          (venue['address'] ?? '').toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
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
                        fontSize: 10,
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
    final color = _homeDesign.secondaryColor;
    return Container(
      color: color.withOpacity(0.08),
      child: Center(
        child: Icon(
          Icons.location_on_rounded,
          color: color,
          size: 36,
        ),
      ),
    );
  }

  Widget _buildClubsSection(
    HomeSectionConfig config,
    List<Map<String, dynamic>> teams,
    BuildContext context,
  ) {
    final cardWidth = _isTablet(context) ? 200.0 : config.cardWidth;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeaderFromDesign(
          config: config,
          title: 'Клубы',
          subtitle: 'Профессиональные команды',
          onSeeAll: teams.isNotEmpty ? _openClubsAll : null,
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: _isTablet(context) ? 200 : config.cardHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount:
                teams.length > config.itemLimit ? config.itemLimit : teams.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.only(
                  right: index == teams.length - 1 ? 0 : 12,
                ),
                child: SizedBox(
                  width: cardWidth,
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
                    size: 50,
                  ),
                ),
                Positioned(
                  left: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
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
                        fontSize: 9,
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
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: _homeDesign.cardTitleSize - 1,
                      fontWeight: FontWeight.w800,
                      color: _homeDesign.textColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _metaRow(Icons.sports_rounded, sportText),
                  const SizedBox(height: 4),
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
    BuildContext context,
  ) {
    final cardWidth = _isTablet(context) ? 200.0 : config.cardWidth;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeaderFromDesign(
          config: config,
          title: 'Билеты',
          subtitle: 'На матчи',
          onSeeAll: _openTicketsAll,
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: _isTablet(context) ? 180 : config.cardHeight,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount:
                tickets.length > config.itemLimit ? config.itemLimit : tickets.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.only(
                  right: index == tickets.length - 1 ? 0 : 12,
                ),
                child: SizedBox(
                  width: cardWidth,
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
      onTap: _openTicketsAll,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
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
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  'БИЛЕТЫ',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 9,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    teams,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: _homeDesign.cardTitleSize - 1,
                      fontWeight: FontWeight.w800,
                      color: _homeDesign.textColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (date.isNotEmpty)
                    _metaRow(Icons.calendar_today_rounded, date),
                  if (venue.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    _metaRow(Icons.place_rounded, venue),
                  ],
                  const Spacer(),
                  if (price.isNotEmpty)
                    Text(
                      price,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
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

  Widget _buildPromoSection(HomeSectionConfig config) {
    return _HomePromoBanner(
      title: 'Sportoteka PRO',
      subtitle:
          'Откройте видеоуроки, видеоанализ, heatmap и профессиональные инструменты.',
      buttonText: 'Подробнее',
      showClose: false,
      onClose: () {},
      onTap: _openSubscription,
      design: _homeDesign,
      config: config,
    );
  }

  Widget _buildTipsSection(HomeSectionConfig config) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeaderFromDesign(
          config: config,
          title: 'Советы',
          subtitle: 'Инструкции по работе',
          onSeeAll: null,
        ),
        const SizedBox(height: 12),
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

  Widget _authorAvatarWidget({
    required String avatarUrl,
    required String author,
    double radius = 12,
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
                fontSize: radius * 0.6,
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
          size: 11,
          color: _homeDesign.mutedTextColor,
        ),
        const SizedBox(width: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 9,
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
        Icon(icon, size: 11, color: _homeDesign.mutedTextColor),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
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
        width: double.infinity,
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
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: _homeDesign.primaryColor,
              strokeWidth: 2.5,
            ),
            const SizedBox(height: 12),
            Text(
              'Загрузка...',
              style: TextStyle(
                color: _homeDesign.textColor,
                fontSize: _homeDesign.bodyTextSize - 1,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
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
        width: double.infinity,
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
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 42,
              color: _homeDesign.mutedTextColor,
            ),
            const SizedBox(height: 12),
            Text(
              text,
              style: TextStyle(
                color: _homeDesign.mutedTextColor,
                fontSize: _homeDesign.bodyTextSize - 1,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _openPost(Map<String, dynamic> post) {
    final title = _stripHtml((post['title'] ?? '').toString());
    final text = _stripHtml((post['text'] ?? '').toString());
    final imageUrl = (post['imageUrl'] ?? '').toString();
    final hasVideo = post['hasVideo'] == true;
    final videoUrl = (post['videoUrl'] ?? '').toString();
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
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'club':
        return 'Клуб';
      case 'coach':
      case 'trainer':
        return 'Тренер';
      case 'player':
        return 'Игрок';
      case 'parent':
        return 'Родитель';
      case 'federation':
        return 'Федерация';
      default:
        return 'Пользователь';
    }
  }

  int _getDashboardTargetId() {
    switch (_currentRole) {
      case 'club':
      case 'federation':
        return _currentClubId;
      case 'player':
      case 'parent':
        return _currentTeamId;
      case 'coach':
      case 'trainer':
        return _currentTeamId > 0 ? _currentTeamId : _currentClubId;
      default:
        return _currentTeamId > 0 ? _currentTeamId : _currentClubId;
    }
  }

  String _getDashboardTargetName() {
    switch (_currentRole) {
      case 'club':
      case 'federation':
        return _currentClubName;
      case 'player':
      case 'parent':
        return _currentTeamName;
      case 'coach':
      case 'trainer':
        return _currentTeamName.isNotEmpty ? _currentTeamName : _currentClubName;
      default:
        return _currentTeamName.isNotEmpty ? _currentTeamName : _currentClubName;
    }
  }

  String _getDashboardTypeLabel() {
    switch (_currentRole) {
      case 'club':
      case 'federation':
        return 'Клуб';
      case 'player':
      case 'parent':
        return 'Команда';
      case 'coach':
      case 'trainer':
        return _currentTeamId > 0 ? 'Команда' : 'Клуб';
      default:
        return _currentTeamId > 0 ? 'Команда' : 'Клуб';
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
    if (d.inHours < 1) return '${d.inMinutes} мин';
    if (d.inDays < 1) return '${d.inHours} ч';
    if (d.inDays < 7) return '${d.inDays} дн';
    return '${date.day}.${date.month}';
  }
  }

class _CustomDrawer extends StatelessWidget {
  final HomeScreenDesign design;
  final String userName;
  final String userRole;
  final String teamOrClubName;
  final String teamLogoUrl;
  final Function(String) onMenuItemTap;

  const _CustomDrawer({
    required this.design,
    required this.userName,
    required this.userRole,
    required this.teamOrClubName,
    required this.teamLogoUrl,
    required this.onMenuItemTap,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width >= 900
        ? 360.0
        : MediaQuery.of(context).size.width * 0.86;

    final displayTeamName =
        teamOrClubName.trim().isNotEmpty ? teamOrClubName.trim() : 'Спортотека';

    return Drawer(
      width: width,
      child: SafeArea(
        child: Container(
          color: design.backgroundColor,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        design.primaryColor,
                        design.primaryColor.withOpacity(0.86),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: design.primaryColor.withOpacity(0.18),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      _teamLogoWidget(
                        teamName: displayTeamName,
                        logoUrl: teamLogoUrl,
                        accent: design.primaryColor,
                        size: 58,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                height: 1.05,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _getRoleLabel(userRole),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.88),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.14),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.12),
                                ),
                              ),
                              child: Text(
                                displayTeamName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  height: 1.0,
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
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  children: [
                    _sectionLabel('Навигация'),
                    _buildDrawerItem(
                      icon: Icons.home_rounded,
                      title: 'Главная',
                      routeKey: 'home',
                    ),
                    _buildDrawerItem(
                      icon: Icons.search_rounded,
                      title: 'Поиск',
                      routeKey: 'search',
                    ),
                    _buildDrawerItem(
                      icon: Icons.monitor_heart_rounded,
                      title: 'Трекинг',
                      routeKey: 'tracking',
                    ),
                    _buildDrawerItem(
                      icon: Icons.groups_rounded,
                      title: 'Клубы и команды',
                      routeKey: 'clubs',
                    ),
                    _buildDrawerItem(
                      icon: Icons.stadium_rounded,
                      title: 'Площадки',
                      routeKey: 'venues',
                    ),
                    _buildDrawerItem(
                      icon: Icons.calendar_month_rounded,
                      title: 'Расписание',
                      routeKey: 'schedule',
                    ),
                    _buildDrawerItem(
                      icon: Icons.video_library_rounded,
                      title: 'Видеоуроки',
                      routeKey: 'video_lessons',
                    ),
                    _buildDrawerItem(
                      icon: Icons.play_circle_fill_rounded,
                      title: 'Reels',
                      routeKey: 'reels',
                    ),
                    _buildDrawerItem(
                      icon: Icons.event_rounded,
                      title: 'События',
                      routeKey: 'events',
                    ),
                    _buildDrawerItem(
                      icon: Icons.confirmation_number_rounded,
                      title: 'Билеты',
                      routeKey: 'tickets',
                    ),
                    const SizedBox(height: 10),
                    _sectionLabel('Аккаунт'),
                    _buildDrawerItem(
                      icon: Icons.workspace_premium_rounded,
                      title: 'PRO подписка',
                      routeKey: 'subscription',
                    ),
                    _buildDrawerItem(
                      icon: Icons.tune_rounded,
                      title: 'Настройки экрана',
                      routeKey: 'settings',
                    ),
                    _buildDrawerItem(
                      icon: Icons.help_outline_rounded,
                      title: 'Помощь',
                      routeKey: 'help',
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

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
      child: Text(
        text,
        style: TextStyle(
          color: design.mutedTextColor,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required String routeKey,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => onMenuItemTap(routeKey),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: design.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: design.borderColor.withOpacity(0.9),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: design.primaryColor.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: design.primaryColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: design.textColor,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      height: 1.05,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: design.mutedTextColor,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getRoleLabel(String role) {
    switch (role) {
      case 'club':
        return 'Клуб';
      case 'coach':
      case 'trainer':
        return 'Тренер';
      case 'player':
        return 'Игрок';
      case 'parent':
        return 'Родитель';
      case 'federation':
        return 'Федерация';
      default:
        return 'Пользователь';
    }
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
      duration: const Duration(milliseconds: 350),
    );
    _opacity = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _offset = Tween<Offset>(
      begin: const Offset(0, 0.12),
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
                  top: -14,
                  right: -6,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned(
                  bottom: -18,
                  left: -10,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(
                            widget.design.smallRadius,
                          ),
                        ),
                        child: const Icon(
                          Icons.workspace_premium_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.title,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: widget.design.sectionTitleSize,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.subtitle,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.92),
                                fontSize: widget.design.bodyTextSize - 1,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 10),
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
                                        vertical: 9,
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
                                        fontSize: widget.design.bodyTextSize - 1,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (widget.showClose)
                        InkWell(
                          onTap: _close,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: 16,
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


class _HomeQuickActionsGrid extends StatelessWidget {
  final List<Map<String, dynamic>> actions;

  const _HomeQuickActionsGrid({
    required this.actions,
  });

 int _columnsForWidth(double width) {
  if (width >= 1500) return 6;
  if (width >= 1220) return 5;
  if (width >= 920) return 4;
  if (width >= 680) return 3;
  if (width >= 320) return 2;
  return 1;
}

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = _columnsForWidth(width);
        final spacing = width >= 1000 ? 8.0 : 10.0;
        final itemWidth =
            columns == 1 ? width : (width - spacing * (columns - 1)) / columns;

        final compact = columns >= 4 || width >= 980;
        final veryCompact = columns >= 5 || width >= 1280;

        final cardHeight = veryCompact
            ? 88.0
            : compact
                ? 96.0
                : 108.0;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: actions.map((item) {
            return SizedBox(
              width: itemWidth,
              child: _HomeQuickActionCard(
                title: item["title"] as String,
                subtitle: item["subtitle"] as String,
                icon: item["icon"] as IconData,
                color: item["color"] as Color,
                height: cardHeight,
                onTap: item["onTap"] as VoidCallback,
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _HomeQuickActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final double height;
  final VoidCallback onTap;

  const _HomeQuickActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.height,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final compact = height <= 96;
    final veryCompact = height <= 88;
    final iconBox = veryCompact ? 32.0 : (compact ? 34.0 : 40.0);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: height,
        padding: EdgeInsets.all(veryCompact ? 10 : (compact ? 11 : 13)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE7ECF2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: iconBox,
                  height: iconBox,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: veryCompact ? 16 : (compact ? 17 : 20),
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_outward_rounded,
                  size: veryCompact ? 14 : 16,
                  color: const Color(0xFF64748B).withOpacity(0.7),
                ),
              ],
            ),
            const Spacer(),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: const Color(0xFF0F172A),
                fontWeight: FontWeight.w900,
                fontSize: veryCompact ? 11.0 : (compact ? 11.5 : 13.0),
                height: 1.0,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              maxLines: veryCompact ? 1 : 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w600,
                fontSize: veryCompact ? 9.2 : (compact ? 9.8 : 11.0),
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeModulesWrap extends StatelessWidget {
  final List<Map<String, dynamic>> items;

  const _HomeModulesWrap({
    required this.items,
  });

  int _columnsForWidth(double width) {
    if (width >= 1500) return 6;
    if (width >= 1220) return 5;
    if (width >= 920) return 4;
    if (width >= 680) return 3;
    if (width >= 360) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = _columnsForWidth(width);
        final spacing = width >= 1000 ? 8.0 : 10.0;
        final itemWidth =
            columns == 1 ? width : (width - spacing * (columns - 1)) / columns;

        final compact = columns >= 4 || width >= 980;
        final veryCompact = columns >= 5 || width >= 1280;

        final cardHeight = veryCompact
            ? 96.0
            : compact
                ? 108.0
                : 126.0;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items.map((item) {
            return SizedBox(
              width: itemWidth,
              child: _HomeModuleCard(
                title: item["title"] as String,
                subtitle: item["subtitle"] as String,
                icon: item["icon"] as IconData,
                color: item["color"] as Color,
                height: cardHeight,
                onTap: item["onTap"] as VoidCallback,
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _HomeModuleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final double height;
  final VoidCallback onTap;

  const _HomeModuleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.height,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final compact = height <= 108;
    final veryCompact = height <= 96;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(compact ? 16 : 20),
      child: Container(
        height: height,
        padding: EdgeInsets.all(veryCompact ? 10 : (compact ? 11 : 13)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(compact ? 16 : 20),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.025),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: veryCompact ? 30 : (compact ? 34 : 42),
                  height: veryCompact ? 30 : (compact ? 34 : 42),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(compact ? 10 : 14),
                  ),
                  child: Icon(
                    icon,
                    size: veryCompact ? 15 : (compact ? 17 : 22),
                    color: color,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_outward_rounded,
                  size: compact ? 14 : 18,
                  color: const Color(0xFF64748B).withOpacity(0.7),
                ),
              ],
            ),
            SizedBox(height: compact ? 6 : 10),
            Text(
              title,
              maxLines: veryCompact ? 1 : 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: veryCompact ? 10.6 : (compact ? 11.4 : 13.4),
                height: 1.08,
                color: const Color(0xFF0F172A),
              ),
            ),
            SizedBox(height: compact ? 3 : 5),
            Expanded(
              child: Text(
                subtitle,
                maxLines: veryCompact ? 2 : 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: veryCompact ? 8.9 : (compact ? 9.7 : 11.2),
                  color: const Color(0xFF64748B),
                  height: 1.08,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class _SportotekaHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double minExtentValue;
  final double maxExtentValue;
  final bool collapsed;

  const _SportotekaHeaderDelegate({
    required this.child,
    required this.minExtentValue,
    required this.maxExtentValue,
    required this.collapsed,
  });

  @override
  double get minExtent => minExtentValue;

  @override
  double get maxExtent => maxExtentValue;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _SportotekaHeaderDelegate oldDelegate) {
    return oldDelegate.child != child ||
        oldDelegate.minExtentValue != minExtentValue ||
        oldDelegate.maxExtentValue != maxExtentValue ||
        oldDelegate.collapsed != collapsed;
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
    team['photo'],
    team['photo_url'],
  ].map((e) => (e ?? '').toString()).toList();

  for (final c in candidates) {
    final trimmed = c.trim();
    if (trimmed.isEmpty) continue;

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }

    final url = _normalizeMediaUrl(trimmed);
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
    final one = parts.first;
    return one.length >= 2 ? one.substring(0, 2).toUpperCase() : one.toUpperCase();
  }

  final a = parts[0].substring(0, 1).toUpperCase();
  final b = parts[1].substring(0, 1).toUpperCase();
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
          color: Colors.black.withOpacity(0.12),
          blurRadius: 12,
          offset: const Offset(0, 6),
        ),
      ],
      border: Border.all(
        color: Colors.white.withOpacity(0.95),
        width: 2.5,
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
          fontSize: 18,
          fontWeight: FontWeight.w900,
          color: accent,
          letterSpacing: 0.5,
        ),
      ),
    ),
  );
}
