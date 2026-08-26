import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart' hide FormData, MultipartFile, Response;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import 'package:sportoteka/core/constants/app_colors.dart';
import 'package:sportoteka/core/theme/app_typography.dart';
import 'package:sportoteka/presentation/workspace_os/sportoteka_workspace_icons.dart';
import 'package:sportoteka/presentation/workspace_os/workspace_entity_records.dart';
import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/presentation/team_video_analysis/match_video_player_screen.dart';
import 'package:sportoteka/presentation/team_video_analysis/video_match_review_screen.dart';
import 'package:sportoteka/presentation/advanced_video_analysis/advanced_video_analysis_screen.dart';
import 'package:sportoteka/presentation/advanced_video_analysis/models/analysis_result.dart';
import 'package:sportoteka/presentation/advanced_video_analysis/models/player_detection.dart';
import 'package:sportoteka/presentation/match_live/match_live_screen.dart';

class TeamMatchDetailScreen extends StatefulWidget {
  static const int overviewTabIndex = 0;
  static const int videoTabIndex = 4;
  static const int aiTabIndex = 5;
  static const int documentsTabIndex = 6;

  final int? matchId;
  final int? teamId;
  final int? clubId;
  final String? teamName;
  final String? clubName;
  final Map<String, dynamic>? initialMatch;

  /// true — экран работает как встроенная профессиональная рабочая область
  /// внутри CmrTeamMatchesPanel: без отдельного Scaffold, без нижней навигации
  /// и без кнопки назад, которая закрывала бы весь workspace.
  final bool embedded;

  /// Индекс вкладки, которую нужно открыть сразу. 0 = Обзор.
  /// Используется Workspace OS, чтобы открыть матч сразу на «Видео».
  final int initialTabIndex;

  /// Только рабочая область видео без внутреннего левого меню матча.
  /// Используется Video Center внутри Workspace OS.
  final bool videoOnly;

  /// Только редактор выбранного матча. Используется правой рабочей панелью CMR.
  final bool editorOnly;

  /// Только документы и заметки матча. Используется правой рабочей панелью CMR.
  final bool documentsOnly;

  /// Закрыть встроенную правую рабочую панель.
  final VoidCallback? onClose;

  /// Вызывается после сохранения встроенного редактора.
  final Future<void> Function()? onSaved;

  const TeamMatchDetailScreen({
    super.key,
    this.matchId,
    this.teamId,
    this.clubId,
    this.teamName,
    this.clubName,
    this.initialMatch,
    this.embedded = false,
    this.initialTabIndex = 0,
    this.videoOnly = false,
    this.editorOnly = false,
    this.documentsOnly = false,
    this.onClose,
    this.onSaved,
  });

  @override
  State<TeamMatchDetailScreen> createState() => _TeamMatchDetailScreenState();
}

/// Открывает детальный разбор матча как CMR-панель поверх текущего
/// экрана. На ПК это плавающее окно, а на планшете — рабочая область
/// ровно в размере inline ClubWorkspace: 10 px по бокам, 8 px сверху
/// и 92 px снизу под меню. Кнопка разворота раскрывает панель на весь экран.
void showTeamMatchDetailCmrWindow(
  BuildContext context, {
  int? matchId,
  int? teamId,
  int? clubId,
  String? teamName,
  String? clubName,
  Map<String, dynamic>? initialMatch,
  int initialTabIndex = TeamMatchDetailScreen.overviewTabIndex,
  VoidCallback? onClosed,
}) {
  OverlayState? overlay;
  try {
    overlay = Navigator.of(context, rootNavigator: true).overlay ?? Overlay.maybeOf(context);
  } catch (_) {
    overlay = Overlay.maybeOf(context);
  }
  if (overlay == null) return;

  late OverlayEntry entry;
  Offset position = const Offset(42, 32);
  bool minimized = false;
  bool maximized = false;
  bool closed = false;

  bool isTabletWorkspaceSize(Size screen) {
    final shortestSide = min(screen.width, screen.height);
    final platform = defaultTargetPlatform;
    final touchTabletPlatform = platform == TargetPlatform.android ||
        platform == TargetPlatform.iOS ||
        platform == TargetPlatform.fuchsia;

    return touchTabletPlatform &&
        (shortestSide >= 600 || (screen.width >= 700 && shortestSide >= 500));
  }

  void closeWindow() {
    if (closed) return;
    closed = true;
    entry.remove();
    onClosed?.call();
  }

  entry = OverlayEntry(
    builder: (overlayContext) {
      final media = MediaQuery.of(overlayContext);
      final screen = media.size;
      final tabletWorkspace = isTabletWorkspaceSize(screen);

      // Эти значения повторяют _buildInlineWorkspace() из ClubWorkspace:
      // EdgeInsets.fromLTRB(10, 8, 10, 92). Так панель матча открывается
      // точно в той же зоне, где на планшете живёт workspace, а нижнее меню
      // остаётся на месте.
      const double workspaceSidePadding = 10.0;
      const double workspaceTopPadding = 8.0;
      const double workspaceBottomMenuSpace = 92.0;

      final double width = tabletWorkspace
          ? (maximized ? screen.width : screen.width - workspaceSidePadding * 2)
          : maximized
              ? screen.width - 28
              : min(1280.0, max(820.0, screen.width * .84));

      final double height = tabletWorkspace
          ? maximized
              ? screen.height - media.padding.top - media.padding.bottom
              : screen.height -
                  media.padding.top -
                  media.padding.bottom -
                  workspaceTopPadding -
                  workspaceBottomMenuSpace
          : maximized
              ? screen.height - media.padding.top - media.padding.bottom - 28
              : min(840.0, max(560.0, screen.height * .84));

      final double left = tabletWorkspace
          ? (maximized ? 0.0 : workspaceSidePadding)
          : maximized
              ? 14.0
              : position.dx
                  .clamp(14.0, max(14.0, screen.width - width - 14.0))
                  .toDouble();

      final double top = tabletWorkspace
          ? media.padding.top + (maximized ? 0.0 : workspaceTopPadding)
          : maximized
              ? media.padding.top + 14.0
              : position.dy
                  .clamp(
                    media.padding.top + 14.0,
                    max(media.padding.top + 14.0, screen.height - height - 14.0),
                  )
                  .toDouble();

      if (minimized) {
        return Positioned(
          left: 18,
          bottom: media.padding.bottom + (tabletWorkspace ? workspaceBottomMenuSpace + 10 : 18),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                minimized = false;
                entry.markNeedsBuild();
              },
              borderRadius: BorderRadius.circular(18),
              child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE5ECE8)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(.10),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.sports_soccer_rounded, color: Color(0xFF00A750), size: 17),
                    SizedBox(width: 8),
                    Text(
                      'Матч',
                      style: TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 11.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      final headerTitle = 'Матчи';
      final headerSubtitle = (teamName ?? '').trim().isNotEmpty
          ? teamName!.trim()
          : ((clubName ?? '').trim().isNotEmpty ? clubName!.trim() : 'Разбор матча');

      return Positioned(
        left: left,
        top: top,
        width: width,
        height: height,
        child: Material(
          color: Colors.transparent,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(maximized ? 0 : (tabletWorkspace ? 22 : 28)),
              border: maximized ? null : Border.all(color: const Color(0xFFE3EAE7)),
              boxShadow: maximized
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(tabletWorkspace ? .10 : .16),
                        blurRadius: tabletWorkspace ? 28 : 44,
                        offset: Offset(0, tabletWorkspace ? 12 : 22),
                      ),
                    ],
            ),
            child: Column(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: maximized || tabletWorkspace
                      ? null
                      : (details) {
                          position += details.delta;
                          entry.markNeedsBuild();
                        },
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(bottom: BorderSide(color: Color(0xFFE9EEF0))),
                    ),
                    child: Row(
                      children: [
                        _TeamMatchCmrWindowButton(
                          icon: Icons.close_rounded,
                          tooltip: 'Закрыть',
                          onTap: closeWindow,
                        ),
                        const SizedBox(width: 7),
                        _TeamMatchCmrWindowButton(
                          icon: Icons.remove_rounded,
                          tooltip: 'Свернуть',
                          onTap: () {
                            minimized = true;
                            entry.markNeedsBuild();
                          },
                        ),
                        const SizedBox(width: 7),
                        _TeamMatchCmrWindowButton(
                          icon: maximized ? Icons.close_fullscreen_rounded : Icons.open_in_full_rounded,
                          tooltip: maximized ? 'Вернуть размер' : 'Развернуть',
                          onTap: () {
                            maximized = !maximized;
                            entry.markNeedsBuild();
                          },
                        ),
                        const SizedBox(width: 15),
                        Container(
                          width: 31,
                          height: 31,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F6F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.sports_soccer_rounded, color: Color(0xFF1F2937), size: 16),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                headerTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _TeamMatchUiText.title(13.2),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                headerSubtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _TeamMatchUiText.body(10.5, color: const Color(0xFF667085), weight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: TeamMatchDetailScreen(
                    matchId: matchId,
                    teamId: teamId,
                    clubId: clubId,
                    teamName: teamName,
                    clubName: clubName,
                    initialMatch: initialMatch,
                    embedded: true,
                    initialTabIndex: initialTabIndex,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  overlay.insert(entry);
}

class _TeamMatchUiText {
  static String get family => AppTypography.fontFamily;
  static const List<String> fallback = <String>[
    'Inter',
    'SF Pro Text',
    'SF Pro Display',
    'Roboto',
    'Arial',
  ];

  static TextStyle title(double size, {Color color = const Color(0xFF0B0F14)}) => AppTypography.custom(
        size: size,
        color: color,
        weight: FontWeight.w600,
        letterSpacing: -0.22,
        height: 1.08,
      );

  static TextStyle body(double size, {Color color = const Color(0xFF374151), FontWeight weight = FontWeight.w600}) => AppTypography.custom(
        size: size,
        color: color,
        weight: weight,
        letterSpacing: -0.05,
        height: 1.22,
      );

  static TextStyle action({Color color = const Color(0xFF0B0F14), double size = 12.2}) => AppTypography.action(
        color: color,
      ).copyWith(fontSize: size);

  static TextStyle screenTitle({Color color = const Color(0xFF0B0F14)}) =>
      AppTypography.screenTitle(color: color);

  static TextStyle sectionTitle({Color color = const Color(0xFF0B0F14)}) =>
      AppTypography.sectionTitle(color: color);

  static TextStyle secondary({Color color = const Color(0xFF667085)}) =>
      AppTypography.secondaryMedium(color: color);

  static TextStyle formLabel({Color color = const Color(0xFF374151)}) =>
      AppTypography.formLabel(color: color);

  static TextStyle formText({Color color = const Color(0xFF0B0F14)}) =>
      AppTypography.formText(color: color);

  static TextStyle formHint({Color color = const Color(0xFF667085)}) =>
      AppTypography.formHint(color: color);
}

class _TeamMatchCmrWindowButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _TeamMatchCmrWindowButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Компактные системные кнопки как в CMR "Команды": слева, маленькие,
    // светло-серые, без macOS-цветов и без крупных квадратных кнопок.
    final radius = BorderRadius.circular(99);

    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 250),
      child: Material(
        color: Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F4F7),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: const Color(0xFF667085),
              size: 11.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _AiPlayerMotion {
  final Offset position;
  final double timeMs;
  final double speedKmh;
  final bool sprinting;

  const _AiPlayerMotion({
    required this.position,
    required this.timeMs,
    required this.speedKmh,
    required this.sprinting,
  });
}

enum _MatchRightPanelMode { none, editor, uploadFull, uploadHighlight, documents }

class _TeamMatchDetailScreenState extends State<TeamMatchDetailScreen>
    with SingleTickerProviderStateMixin {
  static const String apiBase = "https://sportotekaapp.ru/api";
  static const String detailUrl = "$apiBase/get_team_match_detail.php";
  static const String updateUrl = "$apiBase/update_team_match_info.php";
  static const String deleteVideoUrl = "$apiBase/delete_match_video.php";
  static const String deleteMatchUrl = "$apiBase/delete_team_match.php";
  static const String ttdReportUrl = "$apiBase/get_match_ttd_report.php";

  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();

  bool _isHeaderVisible = true;
  bool loading = true;
  bool loadingTtd = false;
  bool saving = false;
  bool uploadingVideo = false;
  bool _isMatchInfoEditing = false;
  OverlayEntry? _uploadProgressOverlay;
  _MatchRightPanelMode _rightPanelMode = _MatchRightPanelMode.none;
  bool _embeddedMainNoteOpen = false;

  int matchId = 0;
  int teamId = 0;
  int _coachId = 0;
  int _workspaceClubId = 0;
  String teamName = "Моя команда";
  
  
  Map<String, dynamic> _extractTeamColors() {
  // Пытаемся получить цвета из данных матча
  // Если нет - используем стандартные
  final homeColor = _s(match?["home_team_color"]).isNotEmpty
      ? _s(match?["home_team_color"])
      : "#00A750"; // Зеленый - ваша команда
  
  final awayColor = _s(match?["away_team_color"]).isNotEmpty
      ? _s(match?["away_team_color"])
      : "#FF4444"; // Красный - соперник

  // Определяем, какая команда играет дома
  final isHome = _s(match?["our_team"]).isNotEmpty;

  return {
    'home': isHome ? homeColor : awayColor,
    'away': isHome ? awayColor : homeColor,
  };
}



  Map<String, dynamic>? match;

  final ChunkUploadService _chunkUploadService = ChunkUploadService();

  final Map<String, VideoPlayerController> _analysisVideoControllers = {};
  final Map<String, Future<void>> _analysisVideoInitFutures = {};
  final Map<String, String> _analysisVideoInitErrors = {};
  final VideoMatchReviewPlaybackController _aiReviewPlayback =
      VideoMatchReviewPlaybackController();
  final AdvancedVideoAnalysisPlaybackController _embeddedAiPlayback =
      AdvancedVideoAnalysisPlaybackController();
  final AdvancedVideoAnalysisPlaybackController _embeddedMainVideoPlayback =
      AdvancedVideoAnalysisPlaybackController();

  String? _activeAnalysisVideoKey;
  String? _selectedAnalysisPlayerKey;
  bool _bottomVideoLoading = false;
  double _matchPlaybackSpeed = 1.0;
  final List<Map<String, dynamic>> _localVideoNotes = [];

  // Live AI telemetry: эти данные приходят от встроенного AI-видеоанализа
  // и оживляют «Обзор» матча: мини-карту, скорость, спринты, нагрузку и события.
  List<PlayerDetection> _liveAiPlayers = const [];
  final Map<int, Offset> _liveAiPositions = {};
  final Map<int, List<Offset>> _liveAiTrails = {};
  final Map<int, double> _liveAiSpeedsKmh = {};
  final Map<int, double> _liveAiAccelerations = {};
  final Map<int, int> _liveAiSprints = {};
  final Map<int, double> _liveAiLoad = {};
  final Map<int, _AiPlayerMotion> _lastAiMotion = {};
  final List<Map<String, dynamic>> _liveAiEvents = [];
  String _liveAiStatus = 'AI ожидает видео';
  int _liveAiFrame = 0;
  double _liveAiTimeMs = 0;
  DateTime _lastAiSaveAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _savingLiveAiFrame = false;

  final _competitionCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  final _tourCtrl = TextEditingController();
  final _stadiumCtrl = TextEditingController();
  final _refereesCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  final _shotsCtrl = TextEditingController();
  final _shotsOnTargetCtrl = TextEditingController();
  final _cornersCtrl = TextEditingController();
  final _offsidesCtrl = TextEditingController();
  final _possessionCtrl = TextEditingController();
  final _yellowCtrl = TextEditingController();
  final _redCtrl = TextEditingController();

  final _coachCommentCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();

  String _search = '';
  String? _selectedMainTtdPlayerKey;
  String? _selectedGoalkeeperKey;

  List<Map<String, dynamic>> ttdPlayers = [];
  List<Map<String, dynamic>> episodes = [];
  List<Map<String, dynamic>> mainReport = [];
  List<Map<String, dynamic>> passReport = [];
  List<Map<String, dynamic>> goalkeeperReport = [];
  List<Map<String, dynamic>> playerVideoTotals = [];

  String? _selectedUploadVideoPath;
  String? _selectedUploadVideoName;
  int? _selectedUploadVideoSize;

  String? _selectedUploadThumbPath;
  String? _selectedUploadThumbName;
  int? _selectedUploadThumbSize;

  // Catapult B/W workspace: графитовые элементы управления + светлые панели аналитики.
  Color get primary => const Color(0xFF28A86B);
  Color get bg => Colors.white;
  Color get cardBg => Colors.white;
  Color get textPrimary => const Color(0xFF111827);
  Color get textSecondary => const Color(0xFF6B7280);
  Color get borderColor => const Color(0xFFE5E7EB);
  Color get softAccent => const Color(0xFFF3FBF7);
  Color get softSurface => const Color(0xFFF8F9FA);

  @override
  void initState() {
    super.initState();
    var requestedInitialTab = widget.initialTabIndex;
    final initialArgs = Get.arguments;
    if (initialArgs is Map) {
      requestedInitialTab = int.tryParse('${initialArgs['initial_tab_index'] ?? initialArgs['tab_index'] ?? requestedInitialTab}') ?? requestedInitialTab;
    }
    final initialTab = requestedInitialTab.clamp(0, 6).toInt();
    _tabController = TabController(length: 7, initialIndex: initialTab, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _scrollController.addListener(_onScroll);
    _readArgs();
    _init();
  }

  Future<void> _init() async {
    _coachId = await PrefUtils.getUserId() ?? 0;
    _workspaceClubId = widget.clubId ?? (await PrefUtils.getUserClubId() ?? 0);
    await load();
    if (_workspaceClubId <= 0) {
      _workspaceClubId = _i(match?["club_id"] ?? match?["clubId"]);
    }
    await _loadTtdReport();
  }

  void _readArgs() {
    if (widget.initialMatch != null) {
      match = Map<String, dynamic>.from(widget.initialMatch!);
    }

    if (widget.matchId != null && widget.matchId! > 0) {
      matchId = widget.matchId!;
    }
    if (widget.teamId != null && widget.teamId! > 0) {
      teamId = widget.teamId!;
    }
    if ((widget.teamName ?? '').trim().isNotEmpty) {
      teamName = widget.teamName!.trim();
    }

    final args = Get.arguments;
    if (args is Map) {
      final argMatch = args["match"];
      if (argMatch is Map) {
        match = Map<String, dynamic>.from(argMatch);
      }

      matchId = int.tryParse((args["match_id"] ?? matchId).toString()) ?? matchId;
      teamId = int.tryParse((args["team_id"] ?? teamId).toString()) ?? teamId;
      teamName = (args["team_name"] ?? teamName).toString();

      developer.log(
        'Received args: matchId=$matchId, teamId=$teamId, teamName=$teamName',
      );
    }
  }

  void _onScroll() {
    if (_scrollController.offset > 50 && _isHeaderVisible) {
      setState(() => _isHeaderVisible = false);
    } else if (_scrollController.offset <= 50 && !_isHeaderVisible) {
      setState(() => _isHeaderVisible = true);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();

    _competitionCtrl.dispose();
    _dateCtrl.dispose();
    _tourCtrl.dispose();
    _stadiumCtrl.dispose();
    _refereesCtrl.dispose();
    _notesCtrl.dispose();

    _shotsCtrl.dispose();
    _shotsOnTargetCtrl.dispose();
    _cornersCtrl.dispose();
    _offsidesCtrl.dispose();
    _possessionCtrl.dispose();
    _yellowCtrl.dispose();
    _redCtrl.dispose();

    _coachCommentCtrl.dispose();
    _searchCtrl.dispose();

    for (final controller in _analysisVideoControllers.values) {
      controller.dispose();
    }
    _analysisVideoControllers.clear();
    _analysisVideoInitFutures.clear();
    _analysisVideoInitErrors.clear();
    _aiReviewPlayback.dispose();
    _embeddedAiPlayback.dispose();
    _embeddedMainVideoPlayback.dispose();
    _hideUploadingDialog();

    super.dispose();
  }

  String _s(dynamic v) => (v ?? "").toString().trim();

  int _i(dynamic v) => int.tryParse('${v ?? 0}') ?? 0;

  double _d(dynamic v) => double.tryParse('${v ?? 0}') ?? 0;

  dynamic _matchValue(String key) {
    final data = match;
    if (data == null) return null;
    return data[key];
  }

  dynamic _ctrlValueOrMatch(TextEditingController controller, String key) {
    final value = controller.text.trim();
    return value.isEmpty ? _matchValue(key) : value;
  }

  String _eventTypeLabel(String raw) {
    switch (raw.toLowerCase()) {
      case 'championship':
        return 'Чемпионат';
      case 'friendly':
        return 'Товарищеский';
      case 'tournament':
        return 'Турнир';
      default:
        return raw.isEmpty ? 'Матч' : raw;
    }
  }

  Map<String, dynamic> _decodeResponse(http.Response resp) {
    try {
      final raw = utf8.decode(resp.bodyBytes, allowMalformed: true).trim();
      final start = raw.indexOf('{');
      if (start == -1) {
        return {"success": false, "message": "Некорректный ответ"};
      }
      final clean = raw.substring(start);
      final data = jsonDecode(clean);
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
      return {"success": false, "message": "Некорректный JSON"};
    } catch (_) {
      return {"success": false, "message": "Ошибка разбора ответа"};
    }
  }

  String? _normalizeUrl(String? raw) {
    if (raw == null) return null;
    final s = raw.trim();
    if (s.isEmpty || s.toLowerCase() == 'null') return null;

    final normalized = s.startsWith("http://") ||
            s.startsWith("https://") ||
            s.startsWith("file://") ||
            s.startsWith("content://")
        ? s
        : "https://sportotekaapp.ru${s.startsWith('/') ? s : '/$s'}";

    return Uri.tryParse(normalized)?.toString() ?? normalized;
  }

  bool _looksLikeOnlyId(String value) {
    final clean = value.trim();
    return clean.isEmpty || RegExp(r'^#?\d+$').hasMatch(clean);
  }

  String _firstReadableTeamName(Map<String, dynamic> source) {
    final variants = [
      source["team_name"],
      source["team_title"],
      source["our_team"],
      source["club_team_name"],
      source["home_team_name"],
      source["name"],
    ];

    for (final value in variants) {
      final label = _s(value);
      if (label.isNotEmpty && !_looksLikeOnlyId(label)) {
        return label;
      }
    }

    return _looksLikeOnlyId(teamName) ? "Моя команда" : teamName;
  }

  String? _playerPhotoUrl(Map<String, dynamic> row) {
    final directKeys = [
      "photo",
      "avatar",
      "image",
      "photo_url",
      "avatar_url",
      "image_url",
      "photo_path",
      "avatar_path",
      "image_path",
      "player_photo",
      "player_avatar",
      "player_image",
      "player_photo_url",
      "player_avatar_url",
      "player_image_url",
      "profile_photo",
      "profile_image",
      "profile_photo_url",
      "profile_image_url",
      "user_photo",
      "user_avatar",
      "user_photo_url",
      "user_avatar_url",
    ];

    String? fromMap(Map<String, dynamic> source) {
      for (final key in directKeys) {
        final value = _s(source[key]);
        if (value.isEmpty || _looksLikeOnlyId(value)) continue;
        final url = _normalizeUrl(value);
        if (url != null && url.isNotEmpty) return url;
      }
      return null;
    }

    final direct = fromMap(row);
    if (direct != null) return direct;

    for (final nestedKey in ["player", "user", "athlete", "profile"]) {
      final nested = row[nestedKey];
      if (nested is Map) {
        final url = fromMap(Map<String, dynamic>.from(nested));
        if (url != null) return url;
      }
    }

    final rowId = _playerId(row);
    final rowName = _playerName(row).toLowerCase();

    for (final list in [ttdPlayers, playerVideoTotals, mainReport, passReport]) {
      for (final item in list) {
        final sameId = rowId.isNotEmpty && _playerId(item) == rowId;
        final sameName = rowName.isNotEmpty && _playerName(item).toLowerCase() == rowName;
        if (sameId || sameName) {
          final url = fromMap(item);
          if (url != null) return url;

          for (final nestedKey in ["player", "user", "athlete", "profile"]) {
            final nested = item[nestedKey];
            if (nested is Map) {
              final nestedUrl = fromMap(Map<String, dynamic>.from(nested));
              if (nestedUrl != null) return nestedUrl;
            }
          }
        }
      }
    }

    final matchPlayers = ((match?["players"] as List?) ?? const [])
        .map((e) => e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{})
        .toList();

    for (final item in matchPlayers) {
      final sameId = rowId.isNotEmpty && _playerId(item) == rowId;
      final sameName = rowName.isNotEmpty && _playerName(item).toLowerCase() == rowName;
      if (sameId || sameName) {
        final url = fromMap(item);
        if (url != null) return url;
      }
    }

    return null;
  }

  String _playerId(Map<String, dynamic> row) {
    for (final key in ["player_id", "id", "user_id", "athlete_id", "student_id"]) {
      final value = _s(row[key]);
      if (value.isNotEmpty && value != "0" && value.toLowerCase() != "null") {
        return value;
      }
    }
    final player = row["player"];
    if (player is Map) {
      return _playerId(Map<String, dynamic>.from(player));
    }
    return "";
  }

  String _playerName(Map<String, dynamic> row) {
    final first = _s(row["first_name"] ?? row["firstname"]);
    final last = _s(row["last_name"] ?? row["lastname"]);
    final full = "$first $last".trim();
    if (full.isNotEmpty) return full;
    for (final key in ["player_name", "fullName", "full_name", "name", "title"]) {
      final value = _s(row[key]);
      if (value.isNotEmpty) return value;
    }
    final player = row["player"];
    if (player is Map) {
      return _playerName(Map<String, dynamic>.from(player));
    }
    return "Игрок";
  }

  String _mainTtdPlayerKey(Map<String, dynamic> row) {
    final id = _playerId(row);
    if (id.isNotEmpty) return "id:$id";
    return "name:${_playerName(row).toLowerCase()}";
  }

  String _playerIdentityKey(Map<String, dynamic> row) {
    final id = _playerId(row).trim();
    if (id.isNotEmpty) return "id:$id";

    final nestedPlayer = row["player"];
    if (nestedPlayer is Map) {
      final nestedId = _playerId(Map<String, dynamic>.from(nestedPlayer)).trim();
      if (nestedId.isNotEmpty) return "id:$nestedId";
    }

    final name = _playerName(row).trim().toLowerCase();
    if (name.isNotEmpty && name != "игрок") return "name:$name";

    final number = _s(row["number"] ?? row["player_number"] ?? row["shirt_number"]).trim();
    if (number.isNotEmpty) return "number:$number";

    return "row:${row.hashCode}";
  }

  List<Map<String, dynamic>> _filteredMainTtdRows() {
    return mainReport.where((row) {
      return _matchesSearch(_playerName(row));
    }).toList();
  }

  Map<String, dynamic> _summaryMainTtdRow(List<Map<String, dynamic>> rows) {
    const keys = [
      "feint_dribble",
      "shot_on_goal",
      "tackle_duel",
      "interception",
      "recovery",
      "header_play",
      "throw_ins",
      "pass_avp",
    ];

    final result = <String, dynamic>{
      "player_name": "Суммарно по матчу",
      "full_name": "Суммарно по матчу",
    };

    for (final key in keys) {
      result[key] = rows.fold<int>(0, (sum, row) => sum + _mainTtdValue(row, key));
    }

    result["ttd_total"] = rows.fold<int>(0, (sum, row) => sum + _mainTtdTotal(row));

    var effectSum = 0.0;
    var effectCount = 0;
    for (final row in rows) {
      final value = _d(row["effect_percent"]);
      if (value > 0) {
        effectSum += value;
        effectCount++;
      }
    }
    result["effect_percent"] = effectCount == 0 ? 0 : (effectSum / effectCount).toStringAsFixed(1);
    return result;
  }

  int _numericValue(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.round();
    if (v is num) return v.round();

    final raw = v.toString().replaceAll(',', '.').trim();
    if (raw.isEmpty || raw.toLowerCase() == 'null' || raw == '—') return 0;

    // В отчётах ТТД часто приходит формат "успешно/неуспешно", например "4/2".
    // Для бейджа игрока и суммарного ТТД показываем общий объём действий: 4 + 2 = 6.
    if (raw.contains('/')) {
      return raw
          .split('/')
          .map((part) => double.tryParse(part.trim())?.round() ?? 0)
          .fold<int>(0, (sum, value) => sum + value);
    }

    return double.tryParse(raw)?.round() ?? 0;
  }

  int _valueFromNested(dynamic raw, String key) {
    if (raw is Map) {
      final map = Map<String, dynamic>.from(raw);
      var total = 0;

      if (map.containsKey(key)) total += _numericValue(map[key]);

      final aliases = _mainTtdAliases[key] ?? const <String>[];
      for (final alias in aliases) {
        if (map.containsKey(alias)) total += _numericValue(map[alias]);
      }

      final byCode = map[key];
      if (byCode is Map) {
        total += _numericValue(byCode["total"]);
        total += _numericValue(byCode["count"]);
        total += _numericValue(byCode["value"]);
        total += _numericValue(byCode["success"]);
        total += _numericValue(byCode["fail"]);
      }

      for (final nested in ["success", "fail", "single", "totals", "metrics", "items", "actions", "ttd"]) {
        total += _valueFromNested(map[nested], key);
      }

      return total;
    }

    if (raw is List) {
      var total = 0;
      for (final item in raw) {
        if (item is Map) {
          final map = Map<String, dynamic>.from(item);
          final code = _s(map["code"] ?? map["key"] ?? map["type"] ?? map["action"] ?? map["action_code"]);
          final title = _s(map["title"] ?? map["name"] ?? map["label"]);
          final aliases = _mainTtdAliases[key] ?? const <String>[];
          final matches = code == key || aliases.contains(code) || aliases.contains(title);
          if (matches) {
            total += _numericValue(map["total"]);
            total += _numericValue(map["count"]);
            total += _numericValue(map["value"]);
            total += _numericValue(map["success"]);
            total += _numericValue(map["fail"]);
            total += _numericValue(map["single"]);
          } else {
            total += _valueFromNested(map, key);
          }
        }
      }
      return total;
    }

    return 0;
  }

  static const Map<String, List<String>> _mainTtdAliases = {
    "feint_dribble": ["dribble", "feint", "обводки", "финты", "Обводки / финты"],
    "shot_on_goal": ["shots", "shot", "shots_on_goal", "удары", "Удары по воротам"],
    "tackle_duel": ["tackles", "duels", "tackle", "отборы", "единоборства", "Отборы / единоборства"],
    "interception": ["interceptions", "перехваты", "Перехваты"],
    "recovery": ["recoveries", "подборы", "Подборы"],
    "header_play": ["headers", "header", "игра головой", "Игра головой"],
    "throw_ins": ["throw_in", "throwins", "вбрасывания", "Вбрасывания"],
    "pass_avp": ["avp", "key_pass", "key_passes", "острые передачи", "Острые передачи"],
  };

  int _mainTtdValue(Map<String, dynamic> row, String key) {
    var total = 0;

    total += _numericValue(row[key]);

    final aliases = _mainTtdAliases[key] ?? const <String>[];
    for (final alias in aliases) {
      total += _numericValue(row[alias]);
    }

    for (final nested in ["success", "fail", "single", "totals", "metrics", "items", "actions", "ttd"]) {
      total += _valueFromNested(row[nested], key);
    }

    return total;
  }

  int _mainTtdTotal(Map<String, dynamic> row) {
    final direct = _numericValue(row["ttd_total"] ?? row["total_ttd"] ?? row["total"] ?? row["actions_total"]);
    if (direct > 0) return direct;

    const mainKeys = [
      "feint_dribble",
      "shot_on_goal",
      "tackle_duel",
      "interception",
      "recovery",
      "header_play",
      "throw_ins",
      "pass_avp",
    ];

    var total = 0;
    for (final key in mainKeys) {
      total += _mainTtdValue(row, key);
    }

    if (total > 0) return total;

    for (final groupKey in ["success", "fail", "single"]) {
      final raw = row[groupKey];
      if (raw is Map) {
        for (final value in raw.values) {
          total += _numericValue(value);
        }
      }
    }

    return total;
  }

  int _goalkeeperTotal(Map<String, dynamic> row) {
    final direct = _numericValue(row["ttd_total"] ?? row["total_ttd"] ?? row["total"] ?? row["actions_total"]);
    if (direct > 0) return direct;

    const keys = [
      "saves",
      "conceded",
      "hand_distribution",
      "coming_out",
      "close_combat",
      "interceptions",
      "interceptions_gk",
      "outside_box",
      "pass_short",
      "pass_medium",
      "pass_long",
      "gk_pass_short",
      "gk_pass_medium",
      "gk_pass_long",
    ];

    var total = 0;
    for (final key in keys) {
      total += _numericValue(row[key]);
      for (final nested in ["success", "fail", "single", "totals", "metrics", "items", "actions", "ttd"]) {
        total += _valueFromNested(row[nested], key);
      }
    }
    return total;
  }

  Widget _cmrHint({
    required String title,
    required String text,
    IconData icon = Icons.tips_and_updates_outlined,
    Color? color,
  }) {
    final c = color ?? primary;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: softSurface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: c == primary ? softAccent : c.withOpacity(.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: c, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  text,
                  style: TextStyle(
                    color: textSecondary,
                    fontWeight: FontWeight.w600,
                    fontSize: 11.5,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatVideoTitle(String raw, String fallback) {
    final title = raw.trim();
    if (title.isEmpty) return fallback;
    return title;
  }

  String _videoMeta(Map<String, dynamic> video) {
    final parts = <String>[];
    final created = _s(video["created_at"]).isEmpty
        ? _s(video["uploaded_at"])
        : _s(video["created_at"]);
    final size = _i(video["file_size"]);

    if (created.isNotEmpty) parts.add(created);
    if (size > 0) parts.add(_formatFileSize(size));

    return parts.isEmpty ? "Видео матча" : parts.join(" • ");
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return "0 Б";
    const suffixes = ['Б', 'КБ', 'МБ', 'ГБ', 'ТБ'];
    double size = bytes.toDouble();
    int i = 0;
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    final digits = size >= 100 ? 0 : (size >= 10 ? 1 : 2);
    return "${size.toStringAsFixed(digits)} ${suffixes[i]}";
  }

  String _matchTitleForReview() {
    final title = _s(match?["title"]);
    if (title.isNotEmpty) return title;

    final ourTeam =
        _s(match?["our_team"]).isEmpty ? teamName : _s(match?["our_team"]);
    final opponent =
        _s(match?["opponent"]).isEmpty ? "Соперник" : _s(match?["opponent"]);
    final ourScore =
        _s(match?["our_score"]).isEmpty ? "0" : _s(match?["our_score"]);
    final oppScore = _s(match?["opponent_score"]).isEmpty
        ? "0"
        : _s(match?["opponent_score"]);

    return "$ourTeam $ourScore:$oppScore $opponent";
  }

  Future<void> load() async {
    setState(() => loading = true);

    try {
      final resp = await http
          .post(
            Uri.parse(detailUrl),
            headers: const {"Content-Type": "application/json; charset=utf-8"},
            body: jsonEncode({
              "match_id": matchId,
              "team_id": teamId,
            }),
          )
          .timeout(const Duration(seconds: 20));

      final data = _decodeResponse(resp);

      if (data["success"] == true || data["status"] == "success") {
        final loadedMatch = Map<String, dynamic>.from(data["match"] ?? {});

        // Некоторые PHP-обработчики возвращают видео не внутри match["videos"],
        // а отдельным верхним ключом videos. Экран ожидает именно match["videos"],
        // поэтому обязательно подкладываем список внутрь матча.
        final separatedVideos = data["videos"];
        if (separatedVideos is List) {
          loadedMatch["videos"] = separatedVideos;
        }

        // Поддержка альтернативных ключей от API: match_videos / data.videos.
        final separatedMatchVideos = data["match_videos"];
        if ((loadedMatch["videos"] is! List || (loadedMatch["videos"] as List).isEmpty) &&
            separatedMatchVideos is List) {
          loadedMatch["videos"] = separatedMatchVideos;
        }
        final nestedData = data["data"];
        if ((loadedMatch["videos"] is! List || (loadedMatch["videos"] as List).isEmpty) &&
            nestedData is Map &&
            nestedData["videos"] is List) {
          loadedMatch["videos"] = nestedData["videos"];
        }

        match = loadedMatch;
        final loadedTeamName = _firstReadableTeamName(match!);
        if (!_looksLikeOnlyId(loadedTeamName)) {
          teamName = loadedTeamName;
        }
        _fillControllers();
      } else {
        Get.snackbar(
          "Ошибка загрузки",
          data["message"]?.toString() ?? "Не удалось загрузить данные матча",
        );
      }
    } catch (_) {
      Get.snackbar(
        "Ошибка сети",
        "Проверьте интернет-соединение",
      );
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _loadTtdReport() async {
    if (matchId <= 0) return;

    setState(() => loadingTtd = true);

    try {
      final uri = Uri.parse(ttdReportUrl).replace(
        queryParameters: {
          "match_id": "$matchId",
          "team_id": "$teamId",
        },
      );

      final resp = await http.get(uri).timeout(const Duration(seconds: 30));

      final data = _decodeResponse(resp);

      debugPrint("TTD RESPONSE: ${resp.body}");

      if (data["success"] == true) {
        setState(() {
          ttdPlayers = ((data["players"] as List?) ?? const [])
              .map((e) => Map<String, dynamic>.from(e))
              .toList();

          episodes = ((data["episodes"] as List?) ?? const [])
              .map((e) => Map<String, dynamic>.from(e))
              .toList();

          mainReport = ((data["main_report"] as List?) ?? const [])
              .map((e) => Map<String, dynamic>.from(e))
              .toList();

          passReport = ((data["pass_report"] as List?) ?? const [])
              .map((e) => Map<String, dynamic>.from(e))
              .toList();

          goalkeeperReport =
              ((data["goalkeeper_report"] as List?) ?? const [])
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList();

          playerVideoTotals =
              ((data["player_video_totals"] as List?) ?? const [])
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList();
        });
      } else {
        debugPrint("TTD ERROR: ${data["message"]}");
        setState(() {
          ttdPlayers = [];
          episodes = [];
          mainReport = [];
          passReport = [];
          goalkeeperReport = [];
          playerVideoTotals = [];
        });
      }
    } catch (e) {
      debugPrint("TTD LOAD ERROR: $e");
      setState(() {
        ttdPlayers = [];
        episodes = [];
        mainReport = [];
        passReport = [];
        goalkeeperReport = [];
        playerVideoTotals = [];
      });
    } finally {
      if (mounted) setState(() => loadingTtd = false);
    }
  }

  void _fillControllers() {
    final m = match ?? {};

    _competitionCtrl.text = _s(m["competition_name"]);
    _dateCtrl.text = _s(m["info_date"]);
    _tourCtrl.text = _s(m["tour_label"]);
    _stadiumCtrl.text = _s(m["stadium"]);
    _refereesCtrl.text = _s(m["referees"]);
    _notesCtrl.text = _s(m["notes"]);

    _shotsCtrl.text = _s(m["shots"]);
    _shotsOnTargetCtrl.text = _s(m["shots_on_target"]);
    _cornersCtrl.text = _s(m["corners"]);
    _offsidesCtrl.text = _s(m["offsides"]);
    _possessionCtrl.text = _s(m["possession"]);
    _yellowCtrl.text = _s(m["yellow_cards"]);
    _redCtrl.text = _s(m["red_cards"]);

    _coachCommentCtrl.text = _s(m["ttd_text"]);
  }

  Future<void> _saveAll() async {
    setState(() => saving = true);

    try {
      final resp = await http
          .post(
            Uri.parse(updateUrl),
            headers: const {"Content-Type": "application/json; charset=utf-8"},
            body: jsonEncode({
              "match_id": matchId,
              "team_id": teamId,
              "competition_name": _competitionCtrl.text.trim(),
              "info_date": _dateCtrl.text.trim(),
              "tour_label": _tourCtrl.text.trim(),
              "stadium": _stadiumCtrl.text.trim(),
              "referees": _refereesCtrl.text.trim(),
              "notes": _notesCtrl.text.trim(),
              "shots": _shotsCtrl.text.trim(),
              "shots_on_target": _shotsOnTargetCtrl.text.trim(),
              "corners": _cornersCtrl.text.trim(),
              "offsides": _offsidesCtrl.text.trim(),
              "possession": _possessionCtrl.text.trim(),
              "yellow_cards": _yellowCtrl.text.trim(),
              "red_cards": _redCtrl.text.trim(),
              "ttd_text": _coachCommentCtrl.text.trim(),
            }),
          )
          .timeout(const Duration(seconds: 15));

      final data = _decodeResponse(resp);

      if (data["success"] == true || data["status"] == "success") {
        Get.snackbar(
          "Успешно",
          "Информация по матчу сохранена",
          backgroundColor: primary,
          colorText: Colors.white,
        );
        await load();
        await _loadTtdReport();
      } else {
        Get.snackbar(
          "Ошибка сохранения",
          data["message"]?.toString() ?? "Не удалось сохранить изменения",
        );
      }
    } catch (_) {
      Get.snackbar(
        "Ошибка сети",
        "Не удалось сохранить изменения",
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }



  String get _currentMatchActionTitle {
    final explicit = _s(match?["title"] ?? match?["match_title"]);
    if (explicit.isNotEmpty) return explicit;
    return _matchTitleForReview();
  }

  Widget _matchActionsButton({String label = 'Действия'}) {
    return Material(
      color: const Color(0xFFF6F7F9),
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: _showCurrentMatchActions,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.more_horiz_rounded, color: Color(0xFF344054), size: 18),
              SizedBox(width: 7),
              Text(
                'Действия',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Color(0xFF344054),
                  fontWeight: FontWeight.w600,
                  fontSize: 12.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openMatchDocumentsWorkspace() {
    final width = MediaQuery.maybeOf(context)?.size.width ?? 1000;
    if (width >= 560 || widget.embedded) {
      setState(() {
        _embeddedMainNoteOpen = false;
        _rightPanelMode = _MatchRightPanelMode.documents;
      });
      return;
    }
    if (_tabController.length > TeamMatchDetailScreen.documentsTabIndex) {
      _tabController.animateTo(TeamMatchDetailScreen.documentsTabIndex);
    }
  }

  Future<void> _showCurrentMatchActions() async {
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.drive_file_rename_outline_rounded,
                    color: Color(0xFF111827),
                  ),
                  title: Text(
                    'Переименовать матч',
                    style: AppTypography.menuTitle(color: const Color(0xFF111827)),
                  ),
                  subtitle: Text(
                    _currentMatchActionTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _renameCurrentMatch();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.edit_note_rounded, color: Color(0xFF28A86B)),
                  title: Text(
                    'Редактировать данные матча',
                    style: AppTypography.menuTitle(color: const Color(0xFF111827)),
                  ),
                  subtitle: Text('Турнир, дата, стадион, статистика', style: AppTypography.caption(color: const Color(0xFF758079))),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _openMatchInfoEditorSheet();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.folder_copy_outlined, color: Color(0xFF28A86B)),
                  title: Text(
                    'Документы и заметки',
                    style: AppTypography.menuTitle(color: const Color(0xFF111827)),
                  ),
                  subtitle: Text('Материалы матча и общая рабочая заметка', style: AppTypography.caption(color: const Color(0xFF758079))),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _openMatchDocumentsWorkspace();
                  },
                ),
                const Divider(height: 14),
                ListTile(
                  leading: const Icon(Icons.delete_forever_outlined, color: Colors.red),
                  title: const Text(
                    'Удалить матч',
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text('Матч будет удалён полностью'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _deleteCurrentMatch();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _renameCurrentMatch() async {
    if (matchId <= 0) {
      Get.snackbar('Ошибка', 'Некорректный id матча');
      return;
    }

    final controller = TextEditingController(text: _currentMatchActionTitle);

    final newTitle = await Get.dialog<String>(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Переименовать матч',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Название матча',
            hintText: 'Например: Гомель U13 — Минск U13',
          ),
          onSubmitted: (value) => Get.back(result: value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: controller.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF28A86B),
              foregroundColor: Colors.white,
            ),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (newTitle == null) return;
    final cleanTitle = newTitle.trim();
    if (cleanTitle.isEmpty) {
      Get.snackbar('Ошибка', 'Введите название матча');
      return;
    }

    Get.dialog(
      const Center(child: CircularProgressIndicator()),
      barrierDismissible: false,
    );

    try {
      final resp = await http
          .post(
            Uri.parse(updateUrl),
            headers: const {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode({
              'id': matchId,
              'match_id': matchId,
              'team_id': teamId,
              'title': cleanTitle,
              'match_title': cleanTitle,
            }),
          )
          .timeout(const Duration(seconds: 20));

      final data = _decodeResponse(resp);

      if (Get.isDialogOpen ?? false) Get.back();

      final ok = data['success'] == true || data['status'] == 'success';
      if (ok) {
        if (mounted) {
          setState(() {
            final next = Map<String, dynamic>.from(match ?? const {});
            next['title'] = cleanTitle;
            next['match_title'] = cleanTitle;
            match = next;
          });
        }
        Get.snackbar('Готово', 'Название матча обновлено');
        await load();
      } else {
        Get.snackbar(
          'Ошибка',
          _s(data['message']).isNotEmpty
              ? _s(data['message'])
              : 'Не удалось переименовать матч',
        );
      }
    } catch (e) {
      if (Get.isDialogOpen ?? false) Get.back();
      Get.snackbar('Ошибка', 'Ошибка переименования матча: $e');
    }
  }

  Future<void> _deleteCurrentMatch() async {
    if (matchId <= 0) {
      Get.snackbar('Ошибка', 'Некорректный id матча');
      return;
    }

    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Удалить матч?',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Матч\n\n$_currentMatchActionTitle\n\nбудет удалён полностью. Это действие нельзя отменить.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    Get.dialog(
      const Center(child: CircularProgressIndicator()),
      barrierDismissible: false,
    );

    try {
      final resp = await http
          .post(
            Uri.parse(deleteMatchUrl),
            headers: const {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode({
              'id': matchId,
              'match_id': matchId,
              'team_id': teamId,
            }),
          )
          .timeout(const Duration(seconds: 20));

      final data = _decodeResponse(resp);

      if (Get.isDialogOpen ?? false) Get.back();

      final ok = data['success'] == true || data['status'] == 'success';
      if (ok) {
        Get.snackbar('Готово', 'Матч удалён');
        if (!mounted) return;
        if (widget.embedded) {
          setState(() {
            match = {
              'title': 'Матч удалён',
              'videos': <Map<String, dynamic>>[],
            };
          });
        } else {
          Get.back(result: {'deleted': true, 'match_id': matchId});
        }
      } else {
        Get.snackbar(
          'Ошибка',
          _s(data['message']).isNotEmpty
              ? _s(data['message'])
              : 'Не удалось удалить матч',
        );
      }
    } catch (e) {
      if (Get.isDialogOpen ?? false) Get.back();
      Get.snackbar('Ошибка', 'Ошибка удаления матча: $e');
    }
  }

  Widget _matteSurface({required Widget child, VoidCallback? onTap}) {
    // Плоская поверхность без эффекта «карточка в карточке».
    // Используем только белый фон и лёгкие отступы, чтобы весь экран выглядел единым полотном.
    final content = Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      color: Colors.white,
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.white,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: content,
        ),
      );
    }
    return content;
  }

  Widget _buildHeaderCard() {
  final title = _s(match?["title"]).isEmpty ? "Матч" : _s(match?["title"]);
  final eventType = _eventTypeLabel(_s(match?["event_type"]));
  final competition = _s(match?["competition_name"]);
  final date = _s(match?["match_date"]).isEmpty
      ? _s(match?["info_date"])
      : _s(match?["match_date"]);

  final ourTeam =
      _s(match?["our_team"]).isEmpty ? teamName : _s(match?["our_team"]);
  final opponent =
      _s(match?["opponent"]).isEmpty ? "Соперник" : _s(match?["opponent"]);

  final ourScore =
      _s(match?["our_score"]).isEmpty ? "0" : _s(match?["our_score"]);
  final oppScore = _s(match?["opponent_score"]).isEmpty
      ? "0"
      : _s(match?["opponent_score"]);

  // Рассчитываем высоту динамически
  double headerHeight = 0;
  if (_isHeaderVisible) {
    headerHeight = 200; // базовая высота
    if (competition.isNotEmpty || date.isNotEmpty) {
      headerHeight += 40; // добавляем на дополнительный ряд
    }
    if (title.length > 30) {
      headerHeight += 20; // на длинный заголовок
    }
  }

  return AnimatedContainer(
    duration: const Duration(milliseconds: 220),
    curve: Curves.easeOut,
    height: _isHeaderVisible ? headerHeight : 0,
    margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
    child: _isHeaderVisible
        ? _matteSurface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: _TeamMatchUiText.screenTitle(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (eventType.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: softAccent,
                          borderRadius: BorderRadius.circular(20),
                          
                        ),
                        child: Text(
                          eventType,
                          style: AppTypography.badge(color: primary),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: _buildScoreBlock(ourTeam, ourScore, isHome: true),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        ":",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: textSecondary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: _buildScoreBlock(opponent, oppScore, isHome: false),
                    ),
                  ],
                ),
                if (competition.isNotEmpty || date.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (competition.isNotEmpty)
                        _buildInfoChip(
                          icon: Icons.emoji_events_outlined,
                          text: competition,
                        ),
                      if (date.isNotEmpty)
                        _buildInfoChip(
                          icon: Icons.calendar_today_outlined,
                          text: date,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          )
        : null,
  );
}

  Widget _buildOverviewScoreCard({bool compact = false}) {
    final ourTeam = _s(match?["our_team"]).isEmpty ? teamName : _s(match?["our_team"]);
    final opponent = _s(match?["opponent"]).isEmpty ? "Соперник" : _s(match?["opponent"]);
    final ourScore = _s(match?["our_score"]).isEmpty ? "0" : _s(match?["our_score"]);
    final oppScore = _s(match?["opponent_score"]).isEmpty ? "0" : _s(match?["opponent_score"]);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: _scoreTeamName(
              ourTeam,
              align: TextAlign.right,
              color: primary,
              compact: compact,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            constraints: BoxConstraints(
              minWidth: compact ? 76 : 92,
            ),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 12 : 16,
              vertical: compact ? 9 : 10,
            ),
            decoration: BoxDecoration(
              color: softAccent,
              borderRadius: BorderRadius.circular(999),
              
            ),
            child: Text(
              '$ourScore : $oppScore',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: compact ? 24 : 30,
                height: 1,
                fontWeight: FontWeight.w600,
                color: primary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _scoreTeamName(
              opponent,
              align: TextAlign.left,
              color: const Color(0xFF101828),
              compact: compact,
            ),
          ),
        ],
      ),
    );
  }

  Widget _scoreTeamName(
    String title, {
    required TextAlign align,
    required Color color,
    bool compact = false,
  }) {
    return Text(
      title,
      textAlign: align,
      maxLines: compact ? 2 : 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: compact ? 12 : 14,
        height: 1.15,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    );
  }

  Widget _buildScoreBlock(
    String team,
    String score, {
    required bool isHome,
    bool compact = false,
  }) {
    final accent = isHome ? primary : const Color(0xFF667085);

    return Container(
      padding: EdgeInsets.symmetric(
        vertical: compact ? 7 : 9,
        horizontal: compact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: isHome ? primary.withOpacity(0.09) : const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(16),
        
      ),
      child: Column(
        children: [
          Text(
            team,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: compact ? 11 : 12,
              height: 1.1,
              fontWeight: FontWeight.w600,
              color: accent,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            score,
            style: TextStyle(
              fontSize: compact ? 22 : 26,
              fontWeight: FontWeight.w600,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textSecondary),
          const SizedBox(width: 4),
          Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Color _overviewAccent(int index) {
    const colors = [
      Color(0xFF1F7A4D),
      Color(0xFF22C55E),
      Color(0xFFF97316),
      Color(0xFF8B5CF6),
      Color(0xFFEF4444),
      Color(0xFF14B8A6),
    ];
    return colors[index % colors.length];
  }

  Widget _overviewCircleButton({
    required IconData icon,
    required String tooltip,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              shape: BoxShape.circle,
              
            ),
            child: Icon(icon, size: 20, color: color),
          ),
        ),
      ),
    );
  }

  Widget _overviewDot({required Color color, double size = 9}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.75),
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _overviewMetricTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    String? hint,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.075),
        borderRadius: BorderRadius.circular(20),
        
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.85),
              shape: BoxShape.circle,
              
            ),
            child: Icon(icon, color: color, size: 20),
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
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: textSecondary,
                        ),
                      ),
                    ),
                    if (hint != null && hint.trim().isNotEmpty)
                      Tooltip(
                        message: hint,
                        child: Icon(
                          Icons.help_outline_rounded,
                          size: 15,
                          color: color.withOpacity(0.85),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  value.isEmpty ? '—' : value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _overviewMetricGrid({required bool isWide}) {
    final items = [
      _OverviewMetricData(
        label: 'Всего действий',
        value: '$_totalActions',
        icon: Icons.analytics_outlined,
        color: _overviewAccent(0),
        hint: 'Сумма всех ТТД по игрокам в этом матче.',
      ),
      _OverviewMetricData(
        label: 'Успешно',
        value: '$_totalSuccess',
        icon: Icons.check_circle_outline,
        color: _overviewAccent(1),
        hint: 'Количество положительно выполненных действий.',
      ),
      _OverviewMetricData(
        label: 'Неудачно',
        value: '$_totalFail',
        icon: Icons.cancel_outlined,
        color: _overviewAccent(4),
        hint: 'Действия, которые требуют разбора на тренировке.',
      ),
      _OverviewMetricData(
        label: 'Эффективность',
        value: '${_efficiency.toStringAsFixed(1)}%',
        icon: Icons.trending_up,
        color: _overviewAccent(3),
        hint: 'Процент успешных действий от общего количества.',
      ),
    ];

    if (isWide) {
      return Row(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            Expanded(
              child: _overviewMetricTile(
                label: items[i].label,
                value: items[i].value,
                icon: items[i].icon,
                color: items[i].color,
                hint: items[i].hint,
              ),
            ),
            if (i != items.length - 1) const SizedBox(width: 10),
          ],
        ],
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _overviewMetricTile(label: items[0].label, value: items[0].value, icon: items[0].icon, color: items[0].color, hint: items[0].hint)),
            const SizedBox(width: 10),
            Expanded(child: _overviewMetricTile(label: items[1].label, value: items[1].value, icon: items[1].icon, color: items[1].color, hint: items[1].hint)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _overviewMetricTile(label: items[2].label, value: items[2].value, icon: items[2].icon, color: items[2].color, hint: items[2].hint)),
            const SizedBox(width: 10),
            Expanded(child: _overviewMetricTile(label: items[3].label, value: items[3].value, icon: items[3].icon, color: items[3].color, hint: items[3].hint)),
          ],
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),

      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorSize: TabBarIndicatorSize.tab,
        labelPadding: const EdgeInsets.symmetric(horizontal: 12),
        indicatorPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        splashBorderRadius: BorderRadius.circular(18),
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        indicator: BoxDecoration(
          color: primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          
        ),
        labelColor: primary,
        unselectedLabelColor: textSecondary,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(height: 42, text: "Обзор"),
          Tab(height: 42, text: "Основные ТТД"),
          Tab(height: 42, text: "Эпизоды"),
          Tab(height: 42, text: "Нарезка"),
          Tab(height: 42, text: "Видео"),
          Tab(height: 42, text: "ИИ"),
          Tab(height: 42, text: "Документы и заметки"),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required Widget child,
    String? subtitle,
    Widget? trailing,
  }) {
    final width = MediaQuery.maybeOf(context)?.size.width ?? 1000;
    final isPhone = width < 600;
    final hasTitle = title.trim().isNotEmpty;
    final hasSubtitle = subtitle != null && subtitle.trim().isNotEmpty;
    final hasHeader = hasTitle || hasSubtitle || trailing != null;

    // Единая чистая секция: без внешней рамки, тени и «карточки в карточке».
    // Внутренние элементы остаются только как мягкие рабочие поверхности CMR.
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isPhone ? 14 : 18,
        vertical: isPhone ? 12 : 16,
      ),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasHeader) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasTitle || hasSubtitle)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (hasTitle)
                          Text(
                            title,
                            maxLines: isPhone ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                            style: _TeamMatchUiText.sectionTitle(
                              color: textPrimary,
                            ),
                          ),
                        if (hasSubtitle) ...[
                          const SizedBox(height: 5),
                          Text(
                            subtitle!.trim(),
                            maxLines: isPhone ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                            style: _TeamMatchUiText.secondary(
                              color: textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  )
                else
                  const Spacer(),
                if (trailing != null) ...[
                  const SizedBox(width: 10),
                  Flexible(flex: 0, child: trailing),
                ],
              ],
            ),
            SizedBox(height: isPhone ? 12 : 14),
          ],
          child,
        ],
      ),
    );
  }

  Widget _input(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    TextInputType? keyboardType,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: _TeamMatchUiText.formLabel(color: textSecondary),
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: softSurface,
            ),
            child: TextField(
              controller: controller,
              maxLines: maxLines,
              keyboardType: keyboardType,
              style: _TeamMatchUiText.formText(color: textPrimary)
                  .copyWith(fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: _TeamMatchUiText.formHint(color: textSecondary.withOpacity(.55)),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: maxLines > 1 ? 14 : 12,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dashboardCard({
    required String label,
    required String value,
    required IconData icon,
    Color? accent,
  }) {
    final color = accent ?? primary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: softSurface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: softAccent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallBadge(String label, String value, {Color? color}) {
    final c = color ?? primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: c == primary ? softAccent : c.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: c,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: c.withOpacity(.82),
            ),
          ),
        ],
      ),
    );
  }

  Widget _primaryButton({
    required VoidCallback? onPressed,
    required String title,
    IconData? icon,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: icon != null ? Icon(icon, size: 18) : const SizedBox.shrink(),
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _emptyState(String text, {IconData icon = Icons.inbox_outlined}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: softSurface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: softAccent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, size: 28, color: primary),
          ),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textSecondary,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchField({String hint = "Поиск..."}) {
    return Container(
      decoration: BoxDecoration(
        color: softSurface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _search = v),
        style: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: textSecondary.withOpacity(.65), fontWeight: FontWeight.w600),
          prefixIcon: Icon(Icons.search_rounded, size: 20, color: textSecondary),
          suffixIcon: _search.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() => _search = '');
                  },
                  icon: Icon(Icons.close_rounded, size: 18, color: textSecondary),
                ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  bool _matchesSearch(String value) {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return true;
    return value.toLowerCase().contains(q);
  }

  int get _totalSuccess {
    int sum = 0;
    for (final row in playerVideoTotals) {
      final success = Map<String, dynamic>.from(row["success"] ?? {});
      for (final v in success.values) {
        sum += _i(v);
      }
      final single = Map<String, dynamic>.from(row["single"] ?? {});
      sum += _i(single["saves"]);
    }
    return sum;
  }

  int get _totalFail {
    int sum = 0;
    for (final row in playerVideoTotals) {
      final fail = Map<String, dynamic>.from(row["fail"] ?? {});
      for (final v in fail.values) {
        sum += _i(v);
      }
      final single = Map<String, dynamic>.from(row["single"] ?? {});
      sum += _i(single["conceded"]);
    }
    return sum;
  }

  int get _totalActions => _totalSuccess + _totalFail;

  double get _efficiency {
    final total = _totalActions;
    if (total <= 0) return 0;
    return (_totalSuccess / total) * 100;
  }

  void _exportPdfStub() {
    Get.snackbar(
      "PDF",
      "Экспорт отчёта в разработке",
      backgroundColor: primary,
      colorText: Colors.white,
    );
  }

  Widget _buildOverviewTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;
        final isPhone = constraints.maxWidth < 620;

        return ListView(
          controller: _scrollController,
          padding: EdgeInsets.fromLTRB(
            isPhone ? 10 : 18,
            isPhone ? 10 : 14,
            isPhone ? 10 : 18,
            isPhone ? 108 : 24,
          ),
          children: [
            _buildCompactMatchSummaryCard(isWide: isWide),
            const SizedBox(height: 12),
            _buildCoachQuickActions(isWide: isWide),
            const SizedBox(height: 12),
            _overviewMetricGrid(isWide: isWide),
            const SizedBox(height: 12),
            _buildMatchStatsStrip(isWide: isWide),
          ],
        );
      },
    );
  }

  Widget _buildCompactMatchSummaryCard({required bool isWide}) {
    final competition = _s(_competitionCtrl.text);
    final date = _s(_dateCtrl.text);
    final stadium = _s(_stadiumCtrl.text);
    final tour = _s(_tourCtrl.text);
    final comment = _s(_coachCommentCtrl.text);
    final notes = _s(_notesCtrl.text);
    final description = comment.isNotEmpty ? comment : notes;

    return _buildSectionCard(
      title: 'Карточка матча',
      subtitle: 'счёт, место проведения и быстрый комментарий тренера',
      trailing: _overviewCircleButton(
        icon: Icons.edit_rounded,
        tooltip: 'Редактировать матч',
        color: const Color(0xFF1F7A4D),
        onTap: _openMatchInfoEditorSheet,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOverviewScoreCard(compact: !isWide),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (competition.isNotEmpty)
                _CmrMiniPill(icon: Icons.emoji_events_outlined, text: competition),
              if (date.isNotEmpty)
                _CmrMiniPill(icon: Icons.calendar_today_outlined, text: date),
              if (tour.isNotEmpty)
                _CmrMiniPill(icon: Icons.flag_outlined, text: tour),
              if (stadium.isNotEmpty)
                _CmrMiniPill(icon: Icons.stadium_outlined, text: stadium),
              if (competition.isEmpty && date.isEmpty && tour.isEmpty && stadium.isEmpty)
                _CmrMiniPill(icon: Icons.info_outline_rounded, text: 'Заполните данные матча'),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF6F8FA),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.notes_rounded, size: 17, color: primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.32,
                        color: textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCoachQuickActions({required bool isWide}) {
    final actions = [
      _CoachQuickAction(
        title: 'Открыть ТТД',
        subtitle: 'действия игроков',
        icon: Icons.query_stats_rounded,
        onTap: () {
          _openMatchDetailTab(1);
        },
      ),
      _CoachQuickAction(
        title: 'Эпизоды',
        subtitle: 'моменты матча',
        icon: Icons.movie_filter_outlined,
        onTap: () {
          _openMatchDetailTab(2);
        },
      ),
      _CoachQuickAction(
        title: 'Видео',
        subtitle: 'игра и нарезки',
        icon: Icons.play_circle_outline_rounded,
        onTap: () {
          _openMatchDetailTab(4);
        },
      ),
    ];

    return _buildSectionCard(
      title: 'Быстрые действия',
      subtitle: 'основные инструменты тренера после матча',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 560;
          final columns = constraints.maxWidth > 980
              ? 4
              : constraints.maxWidth > 620
                  ? 4
                  : constraints.maxWidth > 360
                      ? 2
                      : 1;
          final spacing = isNarrow ? 8.0 : 10.0;
          final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;

          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: actions
                .map(
                  (item) => SizedBox(
                    width: width,
                    child: _coachActionTile(
                      item,
                      dense: isNarrow,
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }

  Widget _coachActionTile(_CoachQuickAction action, {required bool dense}) {
    final content = dense
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),

                ),
                child: Icon(action.icon, color: primary, size: 20),
              ),
              const SizedBox(height: 10),
              Text(
                action.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13.2,
                  height: 1.12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                action.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 11.2,
                  height: 1.18,
                ),
              ),
            ],
          )
        : Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  
                ),
                child: Icon(action.icon, color: primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      action.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 11.2,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: primary.withOpacity(0.65), size: 20),
            ],
          );

    return Material(
      color: softSurface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: BoxConstraints(minHeight: dense ? 118 : 68),
          padding: EdgeInsets.all(dense ? 12 : 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            
          ),
          child: content,
        ),
      ),
    );
  }

  Widget _buildMatchStatsStrip({required bool isWide}) {
    final stats = [
      _OverviewMetricData(
        label: 'Удары',
        value: _s(_shotsCtrl.text).isEmpty ? '—' : _s(_shotsCtrl.text),
        icon: Icons.sports_soccer_rounded,
        color: _overviewAccent(0),
      ),
      _OverviewMetricData(
        label: 'В створ',
        value: _s(_shotsOnTargetCtrl.text).isEmpty ? '—' : _s(_shotsOnTargetCtrl.text),
        icon: Icons.adjust_rounded,
        color: _overviewAccent(1),
      ),
      _OverviewMetricData(
        label: 'Угловые',
        value: _s(_cornersCtrl.text).isEmpty ? '—' : _s(_cornersCtrl.text),
        icon: Icons.flag_circle_outlined,
        color: _overviewAccent(2),
      ),
      _OverviewMetricData(
        label: 'Владение',
        value: _possessionCtrl.text.isEmpty ? '—' : '${_possessionCtrl.text}%',
        icon: Icons.pie_chart_outline_rounded,
        color: _overviewAccent(5),
      ),
      _OverviewMetricData(
        label: 'Жёлтые',
        value: _s(_yellowCtrl.text).isEmpty ? '—' : _s(_yellowCtrl.text),
        icon: Icons.style_outlined,
        color: const Color(0xFFF59E0B),
      ),
      _OverviewMetricData(
        label: 'Красные',
        value: _s(_redCtrl.text).isEmpty ? '—' : _s(_redCtrl.text),
        icon: Icons.style_rounded,
        color: const Color(0xFFEF4444),
      ),
    ];

    return _buildSectionCard(
      title: 'Матчевые показатели',
      subtitle: 'быстрая сводка для тренера после игры',
      trailing: Tooltip(
        message: 'Данные можно изменить через кнопку редактирования в карточке матча.',
        child: Icon(Icons.help_outline_rounded, size: 18, color: textSecondary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: softAccent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.query_stats_rounded, size: 18, color: primary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Основные цифры',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth > 980 ? 6 : constraints.maxWidth > 620 ? 3 : 2;
              final spacing = 10.0;
              final itemWidth = (constraints.maxWidth - spacing * (columns - 1)) / columns;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: stats.map((item) {
                  return SizedBox(
                    width: itemWidth,
                    child: _overviewStatMiniTile(item),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _overviewStatMiniTile(_OverviewMetricData item) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FA),
        borderRadius: BorderRadius.circular(17),
        
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              
            ),
            child: Icon(item.icon, color: item.color, size: 17),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openMatchInfoEditorSheet() async {
    if (!mounted) return;

    final width = MediaQuery.maybeOf(context)?.size.width ?? 1000;
    if (width >= 560 || widget.embedded || widget.videoOnly) {
      setState(() => _rightPanelMode = _MatchRightPanelMode.editor);
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final width = MediaQuery.of(sheetContext).size.width;
        final isPhone = width < 600;

        return DraggableScrollableSheet(
          initialChildSize: isPhone ? 0.88 : 0.76,
          minChildSize: isPhone ? 0.58 : 0.46,
          maxChildSize: 0.96,
          expand: false,
          builder: (context, scrollController) {
            return StatefulBuilder(
              builder: (context, sheetSetState) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFF6F8FA),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      Container(
                        width: 46,
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD7E8DE),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          isPhone ? 16 : 22,
                          16,
                          isPhone ? 10 : 18,
                          10,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF2F7F4),
                                borderRadius: BorderRadius.circular(16),
                                
                              ),
                              child: const Icon(
                                Icons.edit_calendar_rounded,
                                color: Color(0xFF1F7A4D),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Редактировать матч',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: _TeamMatchUiText.screenTitle(
                                      color: const Color(0xFF101828),
                                    ),
                                  ),
                                  SizedBox(height: 3),
                                  Text(
                                    'Основные данные, статистика и комментарий тренера',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      height: 1.25,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF667085),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Закрыть',
                              onPressed: () => Navigator.of(sheetContext).pop(),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          padding: EdgeInsets.fromLTRB(
                            isPhone ? 14 : 22,
                            4,
                            isPhone ? 14 : 22,
                            120,
                          ),
                          children: [
                            _buildMatchInfoEditorFields(isPhone: isPhone),
                          ],
                        ),
                      ),
                      SafeArea(
                        top: false,
                        child: Container(
                          padding: EdgeInsets.fromLTRB(
                            isPhone ? 14 : 22,
                            10,
                            isPhone ? 14 : 22,
                            14,
                          ),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: saving
                                      ? null
                                      : () => Navigator.of(sheetContext).pop(),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF101828),
                                    side: BorderSide.none,
                                    backgroundColor: const Color(0xFFF6F8FA),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    textStyle: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  child: const Text('Отмена'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 2,
                                child: FilledButton.icon(
                                  onPressed: saving
                                      ? null
                                      : () async {
                                          await _saveAll();
                                          if (!mounted) return;
                                          sheetSetState(() {});
                                          Navigator.of(sheetContext).pop();
                                        },
                                  icon: saving
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Icons.check_rounded),
                                  label: FittedBox(fit: BoxFit.scaleDown, child: Text(saving ? 'Сохраняем...' : 'Сохранить', maxLines: 1, overflow: TextOverflow.ellipsis)),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF1F7A4D),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    textStyle: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
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
              },
            );
          },
        );
      },
    );

    if (mounted) setState(() {});
  }

  Widget _buildMatchInfoEditorFields({required bool isPhone}) {
    final fields = [
      _EditorFieldBlock(title: 'Турнир / первенство', controller: _competitionCtrl),
      _EditorFieldBlock(title: 'Дата', controller: _dateCtrl, hint: 'ГГГГ-ММ-ДД'),
      _EditorFieldBlock(title: 'Тур / этап', controller: _tourCtrl),
      _EditorFieldBlock(title: 'Стадион', controller: _stadiumCtrl),
      _EditorFieldBlock(title: 'Судьи', controller: _refereesCtrl),
      _EditorFieldBlock(title: 'Примечания', controller: _notesCtrl, maxLines: 3),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _editorGroup(
          title: 'Информация о матче',
          subtitle: 'то, что тренер чаще всего меняет перед разбором',
          child: LayoutBuilder(
            builder: (context, constraints) {
              final twoColumns = constraints.maxWidth > 720 && !isPhone;
              if (!twoColumns) {
                return Column(
                  children: fields
                      .map(
                        (field) => _input(
                          field.title,
                          field.controller,
                          hint: field.hint,
                          maxLines: field.maxLines,
                        ),
                      )
                      .toList(),
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: fields
                          .take(3)
                          .map(
                            (field) => _input(
                              field.title,
                              field.controller,
                              hint: field.hint,
                              maxLines: field.maxLines,
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      children: fields
                          .skip(3)
                          .map(
                            (field) => _input(
                              field.title,
                              field.controller,
                              hint: field.hint,
                              maxLines: field.maxLines,
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        _editorGroup(
          title: 'Статистика матча',
          subtitle: 'быстрые числовые показатели для отчёта',
          child: LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth > 760 ? 3 : constraints.maxWidth > 460 ? 2 : 1;
              final items = [
                _EditorFieldBlock(title: 'Удары', controller: _shotsCtrl),
                _EditorFieldBlock(title: 'Удары в створ', controller: _shotsOnTargetCtrl),
                _EditorFieldBlock(title: 'Угловые', controller: _cornersCtrl),
                _EditorFieldBlock(title: 'Офсайды', controller: _offsidesCtrl),
                _EditorFieldBlock(title: 'Владение, %', controller: _possessionCtrl),
                _EditorFieldBlock(title: 'Жёлтые карточки', controller: _yellowCtrl),
                _EditorFieldBlock(title: 'Красные карточки', controller: _redCtrl),
              ];
              final spacing = 10.0;
              final itemWidth = (constraints.maxWidth - spacing * (columns - 1)) / columns;

              return Wrap(
                spacing: spacing,
                runSpacing: 0,
                children: items
                    .map(
                      (field) => SizedBox(
                        width: itemWidth,
                        child: _input(field.title, field.controller),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        _editorGroup(
          title: 'Комментарий тренера',
          subtitle: 'короткий вывод: что получилось и над чем работать',
          child: _input(
            'Комментарий',
            _coachCommentCtrl,
            maxLines: 5,
            hint: 'Короткий вывод по игре, сильные стороны и что улучшить...',
          ),
        ),
      ],
    );
  }

  Widget _editorGroup({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),

      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF101828),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.25,
              fontWeight: FontWeight.w600,
              color: Color(0xFF667085),
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildMatchInfoEditor() {
    return _buildSectionCard(
      title: 'Редактирование матча',
      subtitle: 'данные матча, статистика и комментарий тренера',
      child: _buildMatchInfoEditorFields(isPhone: MediaQuery.of(context).size.width < 600),
    );
  }

  Widget _reportRowMain(Map<String, dynamic> row) {
    final playerName = _s(row["player_name"]).isEmpty ? "Игрок" : _s(row["player_name"]);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            playerName,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _smallBadge("Обводки", _s(row["feint_dribble"]))),
              const SizedBox(width: 8),
              Expanded(child: _smallBadge("Удары", _s(row["shot_on_goal"]))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _smallBadge("Отборы", _s(row["tackle_duel"]))),
              const SizedBox(width: 8),
              Expanded(child: _smallBadge("Перехваты", _s(row["interception"]))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _smallBadge("Подборы", _s(row["recovery"]))),
              const SizedBox(width: 8),
              Expanded(child: _smallBadge("Головой", _s(row["header_play"]))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _smallBadge("Вбрасывания", _s(row["throw_ins"]))),
              const SizedBox(width: 8),
              Expanded(child: _smallBadge("Острые пасы", _s(row["pass_avp"]))),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _smallBadge(
                  "Итого",
                  "${_mainTtdTotal(row)}",
                  color: primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _smallBadge(
                  "Эффект",
                  "${_s(row["effect_percent"])}%",
                  color: const Color(0xFF1F7A4D),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMainTtdTab() {
    if (loadingTtd) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    final filtered = _filteredMainTtdRows();
    final isCompact = MediaQuery.of(context).size.width < 820;
    final panelHeight = max(
      320.0,
      min(560.0, MediaQuery.of(context).size.height - (isCompact ? 220 : 300)),
    );

    if (isCompact) {
      return ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 96),
        children: [
          _buildSectionCard(
            title: "Основные ТТД",
            subtitle: "Нажмите на игрока, чтобы открыть карточку действий",
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _searchField(hint: "Поиск по игроку..."),
                const SizedBox(height: 12),
                if (filtered.isEmpty)
                  _emptyState("Нет данных по основным ТТД")
                else
                  _buildMainTtdPlayerList(filtered, compact: true),
              ],
            ),
          ),
          if (goalkeeperReport.isNotEmpty) ...[
            const SizedBox(height: 10),
            _buildGoalkeeperTtdList(compact: true),
          ],
        ],
      );
    }

    return ListView(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionCard(
          title: "Основные ТТД",
          subtitle: "Список игроков. Детальная карточка открывается в модальном окне.",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _searchField(hint: "Поиск по игроку..."),
              const SizedBox(height: 12),
              if (filtered.isEmpty)
                _emptyState("Нет данных по основным ТТД")
              else
                SizedBox(
                  height: panelHeight,
                  child: _buildMainTtdPlayerList(filtered),
                ),
            ],
          ),
        ),
        if (goalkeeperReport.isNotEmpty) ...[
          const SizedBox(height: 14),
          _buildGoalkeeperTtdList(),
        ],
      ],
    );
  }

  Future<void> _showMainTtdDetailsSheet(
    Map<String, dynamic> row, {
    required bool isSummary,
  }) async {
    if (!mounted) return;

    final title = isSummary ? "Суммарные ТТД команды" : _playerName(row);
    final subtitle = isSummary ? "Общая картина по матчу" : "Индивидуальная карточка действий";

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: .86,
          minChildSize: .48,
          maxChildSize: .96,
          builder: (context, scrollController) {
            return Container(
              margin: const EdgeInsets.fromLTRB(6, 0, 6, 6),
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                
              ),
              child: Column(
                children: [
                  _sheetHandle(),
                  Row(
                    children: [
                      isSummary
                          ? Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: softAccent,
                                borderRadius: BorderRadius.circular(17),
                              ),
                              child: Icon(Icons.groups_2_outlined, color: primary, size: 25),
                            )
                          : _PlayerAvatar(
                              imageUrl: _playerPhotoUrl(row),
                              name: title,
                              primary: primary,
                              size: 48,
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
                              style: _TeamMatchUiText.sectionTitle(
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _sheetCloseButton(() => Navigator.pop(sheetContext)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: EdgeInsets.zero,
                      children: [
                        _buildMainTtdDetailsCard(
                          row,
                          isSummary: isSummary,
                          flatMobile: true,
                          showHeader: false,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showGoalkeeperTtdDetailsSheet(Map<String, dynamic> row) async {
    if (!mounted) return;

    final playerName = _playerName(row);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: .86,
          minChildSize: .48,
          maxChildSize: .96,
          builder: (context, scrollController) {
            return Container(
              margin: const EdgeInsets.fromLTRB(6, 0, 6, 6),
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                
              ),
              child: Column(
                children: [
                  _sheetHandle(),
                  Row(
                    children: [
                      _PlayerAvatar(
                        imageUrl: _playerPhotoUrl(row),
                        name: playerName,
                        primary: primary,
                        size: 48,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              playerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _TeamMatchUiText.sectionTitle(
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              "Вратарские действия по матчу",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _sheetCloseButton(() => Navigator.pop(sheetContext)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _goalkeeperTile(row, showHeader: false),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _sheetHandle() {
    return Center(
      child: Container(
        width: 42,
        height: 5,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFD7E8DE),
          borderRadius: BorderRadius.circular(99),
        ),
      ),
    );
  }

  Widget _sheetCloseButton(VoidCallback onTap) {
    return Material(
      color: const Color(0xFFF6F8FA),
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(Icons.close_rounded, color: textSecondary, size: 21),
        ),
      ),
    );
  }

  Widget _buildMainTtdPlayerList(List<Map<String, dynamic>> rows, {bool compact = false}) {
    final selectedKey = _selectedMainTtdPlayerKey;
    final summaryActive = selectedKey == null;
    final summaryRow = _summaryMainTtdRow(rows);

    final playerButtons = rows.map((row) {
      final key = _mainTtdPlayerKey(row);
      final name = _playerName(row);
      final position = _translatePosition(_s(row["group_key"] ?? row["position"] ?? row["role"]));
      return _mainTtdPlayerButton(
        title: name,
        subtitle: position,
        active: selectedKey == key,
        imageUrl: _playerPhotoUrl(row),
        onTap: () {
          setState(() => _selectedMainTtdPlayerKey = key);
          _showMainTtdDetailsSheet(row, isSummary: false);
        },
        total: _mainTtdTotal(row),
      );
    }).toList();

    final summaryButton = _mainTtdPlayerButton(
      title: "Вся команда",
      subtitle: "суммарно по матчу",
      active: summaryActive,
      imageUrl: null,
      onTap: () {
        setState(() => _selectedMainTtdPlayerKey = null);
        _showMainTtdDetailsSheet(summaryRow, isSummary: true);
      },
      total: _i(summaryRow["ttd_total"]),
    );

    final items = <Widget>[
      summaryButton,
      const SizedBox(height: 8),
      for (final button in playerButtons) ...[
        button,
        const SizedBox(height: 8),
      ],
    ];

    if (compact) {
      return Column(children: items);
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FA),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Scrollbar(
        thumbVisibility: false,
        child: ListView(
          primary: false,
          padding: EdgeInsets.zero,
          children: items,
        ),
      ),
    );
  }

  Widget _buildGoalkeeperTtdList({bool compact = false}) {
    if (goalkeeperReport.isEmpty) return const SizedBox.shrink();

    final buttons = goalkeeperReport.asMap().entries.map((entry) {
      final index = entry.key;
      final row = entry.value;
      final key = _mainTtdPlayerKey(row);
      final active = _selectedGoalkeeperKey == key || (_selectedGoalkeeperKey == null && index == 0);

      return _mainTtdPlayerButton(
        title: _playerName(row),
        subtitle: "вратарь",
        active: active,
        imageUrl: _playerPhotoUrl(row),
        onTap: () {
          setState(() => _selectedGoalkeeperKey = key);
          _showGoalkeeperTtdDetailsSheet(row);
        },
        total: _goalkeeperTotal(row),
      );
    }).toList();

    final listChildren = <Widget>[
      for (final button in buttons) ...[
        button,
        const SizedBox(height: 8),
      ],
    ];

    return _buildSectionCard(
      title: "Вратарская статистика",
      subtitle: "Нажмите на вратаря, чтобы открыть карточку действий",
      child: compact
          ? Column(children: listChildren)
          : SizedBox(
              height: min(330.0, max(120.0, goalkeeperReport.length * 76.0 + 20.0)),
              child: Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F8FA),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Scrollbar(
                  thumbVisibility: false,
                  child: ListView(
                    primary: false,
                    padding: EdgeInsets.zero,
                    children: listChildren,
                  ),
                ),
              ),
            ),
    );
  }

  Widget _mainTtdPlayerButton({
    required String title,
    required String subtitle,
    required bool active,
    required String? imageUrl,
    required VoidCallback onTap,
    required int total,
  }) {
    return Material(
      color: active ? softAccent : const Color(0xFFF6F8FA),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            
          ),
          child: Row(
            children: [
              imageUrl == null
                  ? Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: softAccent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.groups_2_outlined, color: primary, size: 22),
                    )
                  : _PlayerAvatar(
                      imageUrl: imageUrl,
                      name: title,
                      primary: primary,
                      size: 42,
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
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: active ? primary : Colors.white,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$total',
                  style: TextStyle(
                    color: active ? Colors.white : textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainTtdDetailsCard(
    Map<String, dynamic> row, {
    required bool isSummary,
    bool flatMobile = false,
    bool showHeader = true,
  }) {
    final title = isSummary ? "Суммарные ТТД команды" : _playerName(row);
    final subtitle = isSummary ? "Общая картина по матчу" : "Индивидуальная карточка действий";

    final metrics = LayoutBuilder(
      builder: (context, c) {
        final twoCols = c.maxWidth > 520;
        final children = [
          _ttdMetricCard("Обводки", "${_mainTtdValue(row, "feint_dribble")}", Icons.directions_run_rounded),
          _ttdMetricCard("Удары", "${_mainTtdValue(row, "shot_on_goal")}", Icons.sports_soccer_rounded),
          _ttdMetricCard("Отборы", "${_mainTtdValue(row, "tackle_duel")}", Icons.shield_outlined),
          _ttdMetricCard("Перехваты", "${_mainTtdValue(row, "interception")}", Icons.swap_horiz_rounded),
          _ttdMetricCard("Подборы", "${_mainTtdValue(row, "recovery")}", Icons.restart_alt_rounded),
          _ttdMetricCard("Игра головой", "${_mainTtdValue(row, "header_play")}", Icons.sports_handball_outlined),
          _ttdMetricCard("Вбрасывания", "${_mainTtdValue(row, "throw_ins")}", Icons.north_east_rounded),
          _ttdMetricCard("Острые пасы", "${_mainTtdValue(row, "pass_avp")}", Icons.trending_up_rounded),
        ];

        if (!twoCols) {
          return Column(
            children: children
                .map((e) => Padding(padding: const EdgeInsets.only(bottom: 8), child: e))
                .toList(),
          );
        }

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: children
              .map((e) => SizedBox(width: (c.maxWidth - 8) / 2, child: e))
              .toList(),
        );
      },
    );

    final header = Row(
      children: [
        isSummary
            ? Container(
                width: flatMobile ? 46 : 52,
                height: flatMobile ? 46 : 52,
                decoration: BoxDecoration(
                  color: softAccent,
                  borderRadius: BorderRadius.circular(16),
                  
                ),
                child: Icon(Icons.analytics_outlined, color: primary, size: flatMobile ? 24 : 28),
              )
            : _PlayerAvatar(
                imageUrl: _playerPhotoUrl(row),
                name: title,
                primary: primary,
                size: flatMobile ? 46 : 52,
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
                  fontWeight: FontWeight.w600,
                  fontSize: flatMobile ? 16 : 17,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: flatMobile ? 12 : 12.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    final totals = Row(
      children: [
        Expanded(child: _smallBadge("Итого", "${_mainTtdTotal(row)}", color: primary)),
        const SizedBox(width: 8),
        Expanded(child: _smallBadge("Эффективность", "${_s(row["effect_percent"])}%", color: const Color(0xFF101828))),
      ],
    );

    // В мобильной версии этот виджет стоит внутри ListView. Expanded там ломает раскладку:
    // из-за этого вкладка «ТТД» могла казаться неоткрывшейся.
    if (flatMobile) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showHeader) ...[
              header,
              const SizedBox(height: 14),
            ],
            metrics,
            const SizedBox(height: 10),
            totals,
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),

      ),
      child: Column(
        children: [
          if (showHeader) ...[
            header,
            const SizedBox(height: 14),
          ],
          Expanded(
            child: Scrollbar(
              thumbVisibility: false,
              child: SingleChildScrollView(
                primary: false,
                child: metrics,
              ),
            ),
          ),
          const SizedBox(height: 12),
          totals,
        ],
      ),
    );
  }

  Widget _ttdMetricCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FA),
        borderRadius: BorderRadius.circular(16),
        
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              
            ),
            child: Icon(icon, size: 18, color: primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value.isEmpty ? "0" : value,
            style: TextStyle(
              color: textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _reportRowPass(Map<String, dynamic> row) {
    final playerName = _s(row["player_name"]).isEmpty ? "Игрок" : _s(row["player_name"]);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            playerName,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _smallBadge("Вперёд к.", _s(row["forward_short"]))),
              const SizedBox(width: 8),
              Expanded(child: _smallBadge("Вперёд с.", _s(row["forward_medium"]))),
              const SizedBox(width: 8),
              Expanded(child: _smallBadge("Вперёд д.", _s(row["forward_long"]))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _smallBadge("Поперёк к.", _s(row["side_short"]))),
              const SizedBox(width: 8),
              Expanded(child: _smallBadge("Поперёк с.", _s(row["side_medium"]))),
              const SizedBox(width: 8),
              Expanded(child: _smallBadge("Поперёк д.", _s(row["side_long"]))),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _smallBadge("Назад к.", _s(row["back_short"]))),
              const SizedBox(width: 8),
              Expanded(child: _smallBadge("Назад с.", _s(row["back_medium"]))),
              const SizedBox(width: 8),
              Expanded(child: _smallBadge("Назад д.", _s(row["back_long"]))),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _smallBadge(
                  "Итого",
                  _s(row["total"]),
                  color: primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _smallBadge(
                  "Эффект",
                  "${_s(row["effect_percent"])}%",
                  color: const Color(0xFF1F7A4D),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGoalkeeperTtdPanel({bool compact = false}) {
    if (goalkeeperReport.isEmpty) return const SizedBox.shrink();

    final selectedRow = _selectedGoalkeeperKey == null
        ? goalkeeperReport.first
        : goalkeeperReport.cast<Map<String, dynamic>?>().firstWhere(
              (row) => row != null && _mainTtdPlayerKey(row) == _selectedGoalkeeperKey,
              orElse: () => goalkeeperReport.first,
            )!;

    if (compact || goalkeeperReport.length == 1) {
      return _buildSectionCard(
        title: "Вратарская статистика",
        subtitle: "Та же логика: выбираем вратаря и смотрим действия в компактной карточке",
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (goalkeeperReport.length > 1) ...[
              SizedBox(
                height: 76,
                child: ListView.separated(
                  primary: false,
                  scrollDirection: Axis.horizontal,
                  itemCount: goalkeeperReport.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, index) {
                    final row = goalkeeperReport[index];
                    final key = _mainTtdPlayerKey(row);
                    return SizedBox(
                      width: 220,
                      child: _mainTtdPlayerButton(
                        title: _playerName(row),
                        subtitle: "вратарь",
                        active: _selectedGoalkeeperKey == key || (_selectedGoalkeeperKey == null && index == 0),
                        imageUrl: _playerPhotoUrl(row),
                        onTap: () => setState(() => _selectedGoalkeeperKey = key),
                        total: _goalkeeperTotal(row),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              height: 330,
              child: _goalkeeperTile(selectedRow),
            ),
          ],
        ),
      );
    }

    final h = 330.0;
    return _buildSectionCard(
      title: "Вратарская статистика",
      subtitle: "Слева список вратарей, справа зафиксированная карточка действий",
      child: SizedBox(
        height: h,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 316,
              height: h,
              child: Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F8FA),
                  borderRadius: BorderRadius.circular(18),
                  
                ),
                child: Scrollbar(
                  thumbVisibility: false,
                  child: ListView.separated(
                    primary: false,
                    padding: EdgeInsets.zero,
                    itemCount: goalkeeperReport.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final row = goalkeeperReport[index];
                      final key = _mainTtdPlayerKey(row);
                      return _mainTtdPlayerButton(
                        title: _playerName(row),
                        subtitle: "вратарь",
                        active: _selectedGoalkeeperKey == key || (_selectedGoalkeeperKey == null && index == 0),
                        imageUrl: _playerPhotoUrl(row),
                        onTap: () => setState(() => _selectedGoalkeeperKey = key),
                        total: _goalkeeperTotal(row),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: SizedBox(
                height: h,
                child: _goalkeeperTile(selectedRow),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _goalkeeperTile(Map<String, dynamic> row, {bool showHeader = true}) {
    final playerName = _s(row["player_name"]).isEmpty ? "Вратарь" : _s(row["player_name"]);
    final total = _goalkeeperTotal(row);
    final effect = _s(row["effect_percent"]).isEmpty ? "0" : _s(row["effect_percent"]);

    final items = [
      _ttdMetricCard("Сейвы", _s(row["saves"]), Icons.sports_handball_outlined),
      _ttdMetricCard("Пропущено", _s(row["conceded"]), Icons.remove_circle_outline_rounded),
      _ttdMetricCard("Ввод рукой", _s(row["hand_distribution"]), Icons.pan_tool_alt_outlined),
      _ttdMetricCard("Выходы", _s(row["coming_out"]), Icons.open_in_full_rounded),
      _ttdMetricCard("Ближний бой", _s(row["close_combat"]), Icons.shield_outlined),
      _ttdMetricCard("Перехваты", _s(row["interceptions"]).isEmpty ? _s(row["interceptions_gk"]) : _s(row["interceptions"]), Icons.swap_horiz_rounded),
      _ttdMetricCard("Вне штрафной", _s(row["outside_box"]), Icons.crop_free_rounded),
      _ttdMetricCard("Пас короткий", _s(row["pass_short"]).isEmpty ? _s(row["gk_pass_short"]) : _s(row["pass_short"]), Icons.short_text_rounded),
      _ttdMetricCard("Пас средний", _s(row["pass_medium"]).isEmpty ? _s(row["gk_pass_medium"]) : _s(row["pass_medium"]), Icons.horizontal_rule_rounded),
      _ttdMetricCard("Пас длинный", _s(row["pass_long"]).isEmpty ? _s(row["gk_pass_long"]) : _s(row["pass_long"]), Icons.trending_flat_rounded),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),

      ),
      child: Column(
        children: [
          if (showHeader) ...[
            Row(
              children: [
                _PlayerAvatar(
                  imageUrl: _playerPhotoUrl(row),
                  name: playerName,
                  primary: primary,
                  size: 48,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        playerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        "Вратарские действия по матчу",
                        style: TextStyle(
                          color: textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _smallBadge("Итого", "$total", color: primary),
                const SizedBox(width: 8),
                _smallBadge("Эффект", "$effect%", color: const Color(0xFF1F7A4D)),
              ],
            ),
            const SizedBox(height: 14),
          ],
          Expanded(
            child: Scrollbar(
              thumbVisibility: false,
              child: ListView.separated(
                primary: false,
                padding: EdgeInsets.zero,
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, index) => items[index],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<_PlayerMetricItem> _buildMetricsFromVideoTotals(Map<String, dynamic> row) {
  final success = Map<String, dynamic>.from(row["success"] ?? {});
  final fail = Map<String, dynamic>.from(row["fail"] ?? {});
  final single = Map<String, dynamic>.from(row["single"] ?? {});

  // Расширенный маппинг для всех метрик
  final metricTitles = <String, String>{
    // Полевые игроки
    'feint_dribble': 'Обводки / финты',
    'shot_on_goal': 'Удары по воротам',
    'tackle_duel': 'Отборы / единоборства',
    'interception': 'Перехваты',
    'recovery': 'Подборы',
    'header_play': 'Игра головой',
    'throw_ins': 'Вбрасывания',
    'pass_avp': 'Острые передачи',
    // Передачи
    'forward_short': 'Передачи вперёд короткие',
    'forward_medium': 'Передачи вперёд средние',
    'forward_long': 'Передачи вперёд длинные',
    'side_short': 'Передачи поперёк короткие',
    'side_medium': 'Передачи поперёк средние',
    'side_long': 'Передачи поперёк длинные',
    'back_short': 'Передачи назад короткие',
    'back_medium': 'Передачи назад средние',
    'back_long': 'Передачи назад длинные',
    // Вратарь
    'hand_distribution': 'Ввод мяча рукой',
    'coming_out': 'Игра на выходах',
    'close_combat': 'Ближний бой',
    'interceptions_gk': 'Перехваты вратаря',
    'interceptions': 'Перехваты вратаря',
    'outside_box': 'Игра за штрафной',
    'pass_short': 'Передачи вратаря короткие',
    'pass_medium': 'Передачи вратаря средние',
    'pass_long': 'Передачи вратаря длинные',
    'gk_pass_short': 'Передачи вратаря короткие',
    'gk_pass_medium': 'Передачи вратаря средние',
    'gk_pass_long': 'Передачи вратаря длинные',
    // Общие для всех
    'saves': 'Сейвы',
    'conceded': 'Пропущенные голы',
    'goal': 'Голы',
    'assist': 'Голевые передачи',
    'yellow_card': 'Жёлтые карточки',
    'red_card': 'Красные карточки',
    'foul': 'Фолы',
    'foul_on': 'Фолы на себе',
    'offside': 'Офсайды',
    'corner': 'Угловые',
    'free_kick': 'Штрафные удары',
    'penalty': 'Пенальти',
  };

  final items = <_PlayerMetricItem>[];

  // Собираем все ключи из success, fail и single
  final allKeys = <String>{};
  allKeys.addAll(success.keys);
  allKeys.addAll(fail.keys);
  allKeys.addAll(single.keys);

  for (final code in allKeys) {
    final s = _i(success[code]);
    final f = _i(fail[code]);
    final singleValue = _i(single[code]);
    
    // Пропускаем нулевые значения
    if (s + f + singleValue <= 0) continue;

    // Получаем название или используем сам код с преобразованием
    String title = metricTitles[code] ?? _normalizeKey(code);
    
    if (singleValue > 0) {
      items.add(
        _PlayerMetricItem(
          code: code,
          title: title,
          success: singleValue,
          fail: 0,
        ),
      );
    } else {
      items.add(
        _PlayerMetricItem(
          code: code,
          title: title,
          success: s,
          fail: f,
        ),
      );
    }
  }

  items.sort((a, b) => b.total.compareTo(a.total));
  return items;
}

// Вспомогательная функция для преобразования snake_case в читаемый текст
String _normalizeKey(String key) {
  // Разбиваем по подчёркиваниям
  final parts = key.split('_');
  
  // Словарь для перевода отдельных слов
  const wordMap = {
    'gk': 'вратаря',
    'pass': 'передачи',
    'short': 'короткие',
    'medium': 'средние',
    'long': 'длинные',
    'forward': 'вперёд',
    'back': 'назад',
    'side': 'поперёк',
    'hand': 'рукой',
    'distribution': 'ввод',
    'coming': 'выходы',
    'out': 'игра',
    'close': 'ближний',
    'combat': 'бой',
    'interceptions': 'перехваты',
    'outside': 'вне',
    'box': 'штрафной',
    'feint': 'обводки',
    'dribble': 'финты',
    'shot': 'удары',
    'goal': 'ворота',
    'tackle': 'отборы',
    'duel': 'единоборства',
    'interception': 'перехваты',
    'recovery': 'подборы',
    'header': 'игра',
    'play': 'головой',
    'throw': 'вбрасывания',
    'ins': 'ауты',
    'avp': 'острые',
    'saves': 'сейвы',
    'conceded': 'пропущенные',
  };
  
  // Переводим каждую часть
  final translatedParts = parts.map((part) {
    return wordMap[part.toLowerCase()] ?? part;
  }).toList();
  
  // Собираем обратно с заглавной буквы
  String result = translatedParts.join(' ');
  if (result.isNotEmpty) {
    result = result[0].toUpperCase() + result.substring(1);
  }
  
  return result;
}
 Widget _playerTotalsTile(Map<String, dynamic> row) {
  final playerName = _s(row["player_name"]).isEmpty ? "Игрок" : _s(row["player_name"]);
  final groupKey = _s(row["group_key"]);
  
  // Переводим амплуа игрока
  String position = _translatePosition(groupKey);
  
  final metrics = _buildMetricsFromVideoTotals(row);

  int totalSuccess = 0;
  int totalFail = 0;
  for (final m in metrics) {
    totalSuccess += m.success;
    totalFail += m.fail;
  }
  final total = totalSuccess + totalFail;
  final efficiency = total > 0 ? (totalSuccess / total) * 100 : 0.0;

  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),

    ),
    child: ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      leading: _PlayerAvatar(
        imageUrl: _playerPhotoUrl(row),
        name: playerName,
        primary: primary,
        size: 46,
      ),
      title: Text(
        playerName,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        position,
        style: TextStyle(
          color: textSecondary,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
      children: [
        Row(
          children: [
            Expanded(child: _smallBadge("Всего", '$total')),
            const SizedBox(width: 8),
            Expanded(
              child: _smallBadge(
                "Успешно",
                '$totalSuccess',
                color: Colors.green,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _smallBadge(
                "Ошибки",
                '$totalFail',
                color: Colors.red,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (metrics.isEmpty)
          Text(
            "Нет детальных метрик",
            style: TextStyle(color: textSecondary),
          )
        else
          ...metrics.map((m) {
            final eff = m.total > 0 ? (m.success / m.total) * 100 : 0.0;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF6F8FA),
                borderRadius: BorderRadius.circular(14),
                
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _smallBadge("Всего", '${m.total}')),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _smallBadge(
                          "Успешно",
                          '${m.success}',
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _smallBadge(
                          "Ошибка",
                          '${m.fail}',
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: (eff / 100).clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor: const Color(0xFFD7E8DE),
                      valueColor: AlwaysStoppedAnimation<Color>(primary),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Эффективность: ${eff.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 12,
                      color: textSecondary,
                      fontWeight: FontWeight.w600,
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

// Функция для перевода амплуа игрока
String _translatePosition(String key) {
  switch (key.toUpperCase()) {
    case 'GK':
      return 'Вратарь';
    case 'DEF':
      return 'Защитник';
    case 'MID':
      return 'Полузащитник';
    case 'FWD':
      return 'Нападающий';
    default:
      return key.isEmpty ? 'Игрок' : key;
  }
}
  String _episodeField(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = _s(row[key]);
      if (value.isNotEmpty && value.toLowerCase() != 'null') return value;
    }
    return '';
  }

  String? _imageFromKeys(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = _s(row[key]);
      if (value.isEmpty || _looksLikeOnlyId(value)) continue;
      final url = _normalizeUrl(value);
      if (url != null && url.isNotEmpty) return url;
    }
    return null;
  }

  String? _episodeImageUrl(Map<String, dynamic> episode) {
    const imageKeys = [
      "image",
      "image_url",
      "image_path",
      "photo",
      "photo_url",
      "photo_path",
      "thumbnail",
      "thumbnail_url",
      "thumbnail_path",
      "thumb",
      "thumb_url",
      "preview",
      "preview_url",
      "preview_path",
      "poster",
      "poster_url",
      "poster_path",
      "frame",
      "frame_url",
      "frame_path",
      "snapshot",
      "snapshot_url",
      "snapshot_path",
      "cover",
      "cover_url",
      "cover_path",
      "clip_thumbnail",
      "clip_thumbnail_url",
      "video_thumbnail",
      "video_thumbnail_url",
    ];

    final direct = _imageFromKeys(episode, imageKeys);
    if (direct != null) return direct;

    for (final nestedKey in ["episode", "event", "clip", "video", "media", "file", "preview", "thumbnail"]) {
      final nested = episode[nestedKey];
      if (nested is Map) {
        final nestedUrl = _imageFromKeys(Map<String, dynamic>.from(nested), imageKeys);
        if (nestedUrl != null) return nestedUrl;
      }
    }

    return null;
  }

  Widget _episodePreview(String imageUrl, {required String title, required String videoUrl}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        children: [
          Image.network(
            imageUrl,
            height: 148,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              height: 148,
              width: double.infinity,
              color: softAccent,
              alignment: Alignment.center,
              child: Icon(Icons.image_not_supported_outlined, color: primary, size: 28),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(.02),
                    Colors.black.withOpacity(.22),
                  ],
                ),
              ),
            ),
          ),
          if (videoUrl.isNotEmpty)
            Positioned(
              right: 10,
              bottom: 10,
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(999),
                child: InkWell(
                  onTap: () => _watchVideo(videoUrl, title: title.isEmpty ? "Эпизод матча" : title),
                  borderRadius: BorderRadius.circular(999),
                  child: SizedBox(
                    width: 42,
                    height: 42,
                    child: Icon(Icons.play_arrow_rounded, color: primary, size: 26),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _episodeTile(Map<String, dynamic> episode) {
    final player = episode["player"] is Map
        ? Map<String, dynamic>.from(episode["player"])
        : <String, dynamic>{};

    final title = _episodeField(episode, [
      "event_title",
      "title",
      "action_title",
      "action",
      "ttd_title",
      "type_title",
      "type",
    ]);
    final note = _episodeField(episode, ["note", "comment", "description", "text"]);
    final playerName = player.isEmpty ? _playerName(episode) : _playerName(player);
    final photoUrl = _playerPhotoUrl(player.isEmpty ? episode : player);
    final previewUrl = _episodeImageUrl(episode);

    final minute = _episodeField(episode, [
      "minute",
      "match_minute",
      "time_minute",
      "event_minute",
      "min",
    ]);
    final second = _episodeField(episode, [
      "second",
      "match_second",
      "time_second",
      "event_second",
      "sec",
    ]);
    final period = _episodeField(episode, ["period", "half", "time_part"]);
    final result = _episodeField(episode, ["result", "outcome", "status", "is_success"]);
    final videoUrl = _episodeField(episode, ["video_url", "clip_url", "file_url", "url"]);

    String timeLabel = '';
    if (minute.isNotEmpty && second.isNotEmpty) {
      final sec = int.tryParse(second);
      timeLabel = sec == null ? '$minute:$second' : '$minute:${sec.toString().padLeft(2, '0')}';
    } else if (minute.isNotEmpty) {
      timeLabel = "$minute мин";
    } else {
      timeLabel = _episodeField(episode, ["time", "timestamp", "match_time"]);
    }

    final chips = <Widget>[
      if (timeLabel.isNotEmpty) _episodeChip(Icons.schedule_rounded, timeLabel),
      if (period.isNotEmpty) _episodeChip(Icons.sports_soccer_rounded, period),
      if (result.isNotEmpty) _episodeChip(Icons.check_circle_outline_rounded, result),
    ];

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: softSurface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (previewUrl != null) ...[
            _episodePreview(
              previewUrl,
              title: title.isEmpty ? "Эпизод матча" : title,
              videoUrl: videoUrl,
            ),
            const SizedBox(height: 12),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PlayerAvatar(
                imageUrl: photoUrl,
                name: playerName,
                primary: primary,
                size: 44,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.isEmpty ? "Эпизод матча" : title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        height: 1.18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      playerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (videoUrl.isNotEmpty) ...[
                const SizedBox(width: 8),
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _watchVideo(videoUrl, title: title.isEmpty ? "Эпизод матча" : title),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: primary,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: chips,
            ),
          ],
          if (note.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              note,
              style: TextStyle(
                color: textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
                height: 1.32,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _episodeChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: primary),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  int _responsiveColumns(
    double width, {
    double minItemWidth = 280,
    int maxColumns = 4,
  }) {
    if (!width.isFinite || width <= 0) return 1;
    final byWidth = (width / minItemWidth).floor();
    return byWidth.clamp(1, maxColumns).toInt();
  }

  Widget _responsiveGrid({
    required List<Widget> children,
    double gap = 12,
    double minItemWidth = 280,
    int maxColumns = 4,
  }) {
    if (children.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
        final columns = _responsiveColumns(
          availableWidth,
          minItemWidth: minItemWidth,
          maxColumns: maxColumns,
        );
        final itemWidth = columns <= 1
            ? availableWidth
            : (availableWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final child in children)
              SizedBox(
                width: itemWidth,
                child: child,
              ),
          ],
        );
      },
    );
  }

  Widget _buildEpisodesTab() {
    if (loadingTtd) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    final filtered = episodes.where((e) {
      final player = e["player"] is Map
          ? Map<String, dynamic>.from(e["player"])
          : <String, dynamic>{};
      final title = _episodeField(e, ["event_title", "title", "action_title", "action", "ttd_title", "type_title", "type"]);
      final note = _episodeField(e, ["note", "comment", "description", "text"]);
      final playerName = player.isEmpty ? _playerName(e) : _playerName(player);

      return _matchesSearch("$title $note $playerName");
    }).toList();

    final isPhone = MediaQuery.of(context).size.width < 600;

    return ListView(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(isPhone ? 8 : 16, isPhone ? 8 : 16, isPhone ? 8 : 16, isPhone ? 96 : 16),
      children: [
        _buildSectionCard(
          title: "Эпизоды матча",
          subtitle: "Эпизоды и привязанные действия",
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _searchField(hint: "Поиск по эпизодам, заметкам, игрокам..."),
              const SizedBox(height: 14),
              if (filtered.isEmpty)
                _emptyState("Эпизоды не найдены", icon: Icons.movie_filter_outlined)
              else
                _responsiveGrid(
                  minItemWidth: 360,
                  maxColumns: 3,
                  children: filtered.map(_episodeTile).toList(),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showUploadVideoSheet(String type) async {
    _selectedUploadVideoPath = null;
    _selectedUploadVideoName = null;
    _selectedUploadVideoSize = null;

    _selectedUploadThumbPath = null;
    _selectedUploadThumbName = null;
    _selectedUploadThumbSize = null;

    final width = MediaQuery.maybeOf(context)?.size.width ?? 1000;
    if (width >= 560 || widget.embedded || widget.videoOnly) {
      setState(() {
        _rightPanelMode = type == 'highlight'
            ? _MatchRightPanelMode.uploadHighlight
            : _MatchRightPanelMode.uploadFull;
      });
      return;
    }

    final overlay = _rootOverlayState() ?? Overlay.of(context, rootOverlay: true);
    final closed = Completer<void>();
    late OverlayEntry entry;
    bool localSaving = false;

    void closeUploadWindow() {
      if (closed.isCompleted) return;
      entry.remove();
      closed.complete();
    }

    entry = OverlayEntry(
      builder: (overlayContext) {
        return StatefulBuilder(
          builder: (overlayContext, setSB) {
            Future<void> pickVideo() async {
              try {
                final result = await FilePicker.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: const ['mp4', 'mov', 'm4v', 'avi'],
                  allowMultiple: false,
                  withData: false,
                );

                if (result == null || result.files.isEmpty) return;

                final picked = result.files.first;
                if (picked.path == null || picked.path!.isEmpty) {
                  Get.snackbar("Ошибка", "Не удалось получить путь к видео");
                  return;
                }

                final file = File(picked.path!);
                if (!await file.exists()) {
                  Get.snackbar("Ошибка", "Файл не найден");
                  return;
                }

                final pickedExt = picked.name.contains('.')
                    ? picked.name.split('.').last.toLowerCase()
                    : '';
                if (!['mp4', 'mov', 'm4v', 'avi'].contains(pickedExt)) {
                  Get.snackbar(
                    'Видео',
                    'Поддерживаются MP4, MOV, M4V и AVI. AVI будет конвертироваться сервером в MP4 для просмотра в приложении.',
                  );
                  return;
                }

                _selectedUploadVideoPath = picked.path!;
                _selectedUploadVideoName = picked.name;
                _selectedUploadVideoSize = await file.length();

                if (mounted) setSB(() {});
              } on PlatformException catch (e) {
                final isEntitlementError = e.code == 'ENTITLEMENT_NOT_FOUND' ||
                    '${e.message}'.contains('entitlement');
                Get.snackbar(
                  'Ошибка',
                  isEntitlementError
                      ? 'macOS не разрешает выбрать файл. Добавьте entitlement User Selected File Read-Only/Read-Write в DebugProfile.entitlements и Release.entitlements.'
                      : 'Не удалось выбрать видео: ${e.message ?? e.code}',
                );
              } catch (e) {
                Get.snackbar("Ошибка", "Не удалось выбрать видео: $e");
              }
            }

            Future<void> pickThumb() async {
              try {
                final x = await ImagePicker().pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 85,
                  maxWidth: 1400,
                );

                if (x == null) return;

                final file = File(x.path);
                final size = await file.length();

                _selectedUploadThumbPath = x.path;
                _selectedUploadThumbName = x.name;
                _selectedUploadThumbSize = size;

                if (mounted) setSB(() {});
              } on PlatformException catch (e) {
                final isEntitlementError = e.code == 'ENTITLEMENT_NOT_FOUND' ||
                    '${e.message}'.contains('entitlement');
                Get.snackbar(
                  'Ошибка',
                  isEntitlementError
                      ? 'macOS не разрешает выбрать файл. Добавьте entitlement User Selected File Read-Only/Read-Write в DebugProfile.entitlements и Release.entitlements.'
                      : 'Не удалось выбрать превью: ${e.message ?? e.code}',
                );
              } catch (e) {
                Get.snackbar("Ошибка", "Не удалось выбрать превью: $e");
              }
            }

            final media = MediaQuery.of(overlayContext);
            final size = media.size;
            final isCompact = size.width < 680;
            final isHighlight = type == "highlight";
            final title = isHighlight ? "Загрузка нарезки" : "Загрузка видео матча";
            final subtitle = isHighlight
                ? "Добавьте короткий фрагмент для разбора эпизода"
                : "Добавьте полную запись игры для просмотра и AI-разбора";
            final dialogWidth = isCompact ? size.width - 20 : min(620.0, size.width - 48);
            final dialogMaxHeight = max(420.0, size.height - (isCompact ? 22 : 72));

            return Material(
              color: Colors.black.withOpacity(0.34),
              child: SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: dialogWidth,
                      maxHeight: dialogMaxHeight,
                    ),
                    child: Dialog(
                      elevation: 0,
                      insetPadding: EdgeInsets.zero,
                      backgroundColor: Colors.transparent,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(isCompact ? 24 : 28),
                        child: Container(
                          color: Colors.white,
                          child: Column(
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 16, 10, 10),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: softAccent,
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      child: Icon(
                                        isHighlight
                                            ? Icons.video_library_outlined
                                            : Icons.slow_motion_video_rounded,
                                        color: primary,
                                        size: 25,
                                      ),
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
                                            style: _TeamMatchUiText.screenTitle(
                                              color: textPrimary,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            subtitle,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              height: 1.25,
                                              fontWeight: FontWeight.w600,
                                              color: textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Закрыть',
                                      onPressed: localSaving ? null : closeUploadWindow,
                                      icon: const Icon(Icons.close_rounded),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: ListView(
                                  padding: EdgeInsets.fromLTRB(
                                    14,
                                    4,
                                    14,
                                    media.viewInsets.bottom + 18,
                                  ),
                                  children: [
                                    _uploadPickerCard(
                                      title: 'Видео файл',
                                      subtitle: _selectedUploadVideoPath == null
                                          ? 'MP4, MOV, M4V или AVI с устройства'
                                          : 'Файл выбран и готов к загрузке',
                                      buttonText: _selectedUploadVideoPath == null
                                          ? 'Выбрать видео'
                                          : 'Заменить видео',
                                      icon: Icons.video_file_outlined,
                                      selected: _selectedUploadVideoPath != null,
                                      fileName: _selectedUploadVideoName,
                                      fileSize: _selectedUploadVideoSize,
                                      onTap: localSaving ? null : pickVideo,
                                    ),
                                    const SizedBox(height: 12),
                                    _uploadPickerCard(
                                      title: 'Превью',
                                      subtitle: _selectedUploadThumbPath == null
                                          ? 'Необязательно: картинка для красивой карточки видео'
                                          : 'Превью выбрано для карточки видео',
                                      buttonText: _selectedUploadThumbPath == null
                                          ? 'Выбрать превью'
                                          : 'Заменить превью',
                                      icon: Icons.image_outlined,
                                      selected: _selectedUploadThumbPath != null,
                                      fileName: _selectedUploadThumbName,
                                      fileSize: _selectedUploadThumbSize,
                                      onTap: localSaving ? null : pickThumb,
                                    ),
                                    const SizedBox(height: 12),
                                    Container(
                                      padding: const EdgeInsets.all(13),
                                      decoration: BoxDecoration(
                                        color: softSurface,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            width: 34,
                                            height: 34,
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(13),
                                            ),
                                            child: Icon(Icons.restart_alt_rounded, color: primary, size: 19),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Загрузка по частям',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color: textPrimary,
                                                  ),
                                                ),
                                                const SizedBox(height: 3),
                                                Text(
                                                  'Большие файлы загружаются чанками. Процент загрузки будет показан отдельным окном поверх экрана.',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    height: 1.28,
                                                    fontWeight: FontWeight.w600,
                                                    color: textSecondary,
                                                  ),
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
                              SafeArea(
                                top: false,
                                child: Container(
                                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                                  color: Colors.white,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: localSaving ? null : closeUploadWindow,
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: textSecondary,
                                            side: BorderSide.none,
                                            backgroundColor: softSurface,
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                            textStyle: const TextStyle(fontWeight: FontWeight.w600),
                                          ),
                                          child: const Text('Отмена'),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        flex: 2,
                                        child: FilledButton.icon(
                                          onPressed: localSaving
                                              ? null
                                              : () async {
                                                  if (_selectedUploadVideoPath == null ||
                                                      _selectedUploadVideoPath!.isEmpty) {
                                                    Get.snackbar(
                                                      "Видео",
                                                      "Сначала выберите файл для загрузки",
                                                    );
                                                    return;
                                                  }

                                                  final videoFile = File(_selectedUploadVideoPath!);
                                                  if (!await videoFile.exists()) {
                                                    Get.snackbar(
                                                      "Ошибка",
                                                      "Выбранный файл не найден",
                                                    );
                                                    return;
                                                  }

                                                  final thumbFile = _selectedUploadThumbPath != null &&
                                                          _selectedUploadThumbPath!.isNotEmpty
                                                      ? File(_selectedUploadThumbPath!)
                                                      : null;

                                                  setSB(() => localSaving = true);
                                                  closeUploadWindow();

                                                  await _uploadVideoWithChunks(
                                                    type: type,
                                                    video: videoFile,
                                                    thumbnail: thumbFile,
                                                  );
                                                },
                                          icon: localSaving
                                              ? const SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Colors.white,
                                                  ),
                                                )
                                              : const Icon(Icons.cloud_upload_rounded),
                                          label: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              localSaving ? "Подготовка..." : "Загрузить",
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          style: FilledButton.styleFrom(
                                            backgroundColor: primary,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                            textStyle: const TextStyle(fontWeight: FontWeight.w600),
                                          ),
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
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    overlay.insert(entry);
    await closed.future;
  }


  Widget _buildEmbeddedVideoOnlySurface() {
    final content = ColoredBox(color: Colors.white, child: _buildVideosTab());
    if (widget.onClose == null) return content;
    return _profileModeSurface(
      title: 'Видео матча',
      subtitle: 'Записи, загрузка и анализ внутри рабочего окна',
      icon: Icons.video_library_outlined,
      child: content,
    );
  }

  Widget _buildEmbeddedDocumentsOnlySurface() {
    return _profileModeSurface(
      title: 'Документы и заметки',
      subtitle: 'Общие материалы матча · синхронизируются с Workspace OS',
      icon: Icons.folder_copy_outlined,
      child: _embeddedMainNoteOpen
          ? _buildInlineMatchMainNote(onClose: () => setState(() => _embeddedMainNoteOpen = false))
          : _buildDocumentsNotesTab(),
    );
  }

  Widget _buildEmbeddedEditorOnlySurface() {
    return _profileModeSurface(
      title: 'Редактирование матча',
      subtitle: 'Данные, статистика и комментарий тренера',
      icon: Icons.edit_calendar_outlined,
      footer: _profileRightEditorFooter(),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
        child: _buildMatchInfoEditorFields(isPhone: false),
      ),
    );
  }

  Widget _profileModeSurface({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
    Widget? footer,
  }) {
    return ColoredBox(
      color: Colors.white,
      child: Column(
        children: [
          _profileRightHeader(
            title: title,
            subtitle: subtitle,
            icon: icon,
            onClose: widget.onClose,
          ),
          Expanded(child: child),
          if (footer != null) footer,
        ],
      ),
    );
  }

  Widget _profileRightHeader({
    required String title,
    required String subtitle,
    required IconData icon,
    VoidCallback? onClose,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 10, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE9ECEA))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF3FAF6),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFF0B8F55)),
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
                        style: AppTypography.sectionTitle(color: const Color(0xFF101814)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const _MatchProfileBrandDots(),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption(color: const Color(0xFF758079)),
                ),
              ],
            ),
          ),
          if (onClose != null)
            IconButton(
              tooltip: 'Закрыть',
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded, size: 19, color: Color(0xFF667085)),
            ),
        ],
      ),
    );
  }

  Widget _profileRightEditorFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE9ECEA))),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: saving ? null : widget.onClose,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF667085),
                side: BorderSide.none,
                backgroundColor: const Color(0xFFF7F9F8),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text('Отмена', style: AppTypography.action(color: const Color(0xFF667085))),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: saving
                  ? null
                  : () async {
                      await _saveAll();
                      await widget.onSaved?.call();
                    },
              icon: saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_rounded, size: 18),
              label: Text(saving ? 'Сохраняем...' : 'Сохранить', style: AppTypography.action(color: Colors.white)),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0B8F55), padding: const EdgeInsets.symmetric(vertical: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchProfileRightPanel() {
    final mode = _rightPanelMode;
    final isUpload = mode == _MatchRightPanelMode.uploadFull || mode == _MatchRightPanelMode.uploadHighlight;
    final isHighlight = mode == _MatchRightPanelMode.uploadHighlight;
    final title = mode == _MatchRightPanelMode.editor
        ? 'Редактирование матча'
        : mode == _MatchRightPanelMode.documents
            ? 'Документы и заметки'
            : isHighlight
                ? 'Добавить видеонарезку'
                : 'Добавить видео матча';
    final subtitle = mode == _MatchRightPanelMode.editor
        ? 'Данные, статистика и комментарий тренера'
        : mode == _MatchRightPanelMode.documents
            ? 'Материалы матча · общий архив Sportoteka'
            : isHighlight
                ? 'Короткий фрагмент для разбора эпизода'
                : 'Полная запись матча для просмотра и AI-анализа';
    final icon = mode == _MatchRightPanelMode.editor
        ? Icons.edit_calendar_outlined
        : mode == _MatchRightPanelMode.documents
            ? Icons.folder_copy_outlined
            : Icons.video_file_outlined;

    Widget child;
    Widget? footer;
    if (mode == _MatchRightPanelMode.editor) {
      child = SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
        child: _buildMatchInfoEditorFields(isPhone: false),
      );
      footer = _rightPanelEditFooter();
    } else if (mode == _MatchRightPanelMode.documents) {
      child = _embeddedMainNoteOpen
          ? _buildInlineMatchMainNote(onClose: () => setState(() => _embeddedMainNoteOpen = false))
          : _buildDocumentsNotesTab();
    } else if (isUpload) {
      child = _buildVideoUploadRightPanel(isHighlight: isHighlight);
      footer = _rightPanelUploadFooter(type: isHighlight ? 'highlight' : 'full');
    } else {
      child = const SizedBox.shrink();
    }

    return Material(
      color: Colors.white,
      elevation: 8,
      shadowColor: Colors.black.withOpacity(.08),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(left: BorderSide(color: Color(0xFFE6EAE7))),
        ),
        child: Column(
          children: [
            _profileRightHeader(
              title: title,
              subtitle: subtitle,
              icon: icon,
              onClose: () => setState(() => _rightPanelMode = _MatchRightPanelMode.none),
            ),
            Expanded(child: child),
            if (footer != null) footer,
          ],
        ),
      ),
    );
  }

  Widget _rightPanelEditFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE9ECEA))),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: saving ? null : () => setState(() => _rightPanelMode = _MatchRightPanelMode.none),
              style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF667085), side: BorderSide.none, backgroundColor: const Color(0xFFF7F9F8)),
              child: Text('Отмена', style: AppTypography.action(color: const Color(0xFF667085))),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: saving
                  ? null
                  : () async {
                      await _saveAll();
                      if (mounted) setState(() => _rightPanelMode = _MatchRightPanelMode.none);
                    },
              icon: saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_rounded, size: 18),
              label: Text(saving ? 'Сохраняем...' : 'Сохранить', style: AppTypography.action(color: Colors.white)),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0B8F55)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickRightVideoFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['mp4', 'mov', 'm4v', 'avi'],
        allowMultiple: false,
        withData: false,
      );
      if (result == null || result.files.isEmpty) return;
      final picked = result.files.first;
      if (picked.path == null || picked.path!.isEmpty) return;
      final file = File(picked.path!);
      if (!await file.exists()) return;
      if (!mounted) return;
      setState(() {
        _selectedUploadVideoPath = picked.path!;
        _selectedUploadVideoName = picked.name;
        _selectedUploadVideoSize = picked.size > 0 ? picked.size : null;
      });
    } catch (e) {
      Get.snackbar('Видео', 'Не удалось выбрать видео: $e');
    }
  }

  Future<void> _pickRightVideoThumb() async {
    try {
      final x = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 1400);
      if (x == null) return;
      final file = File(x.path);
      final size = await file.length();
      if (!mounted) return;
      setState(() {
        _selectedUploadThumbPath = x.path;
        _selectedUploadThumbName = x.name;
        _selectedUploadThumbSize = size;
      });
    } catch (e) {
      Get.snackbar('Видео', 'Не удалось выбрать превью: $e');
    }
  }

  Widget _buildVideoUploadRightPanel({required bool isHighlight}) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
      children: [
        _uploadPickerCard(
          title: 'Видео файл',
          subtitle: _selectedUploadVideoPath == null ? 'MP4, MOV, M4V или AVI' : 'Файл выбран и готов к загрузке',
          buttonText: _selectedUploadVideoPath == null ? 'Выбрать видео' : 'Заменить видео',
          icon: Icons.video_file_outlined,
          selected: _selectedUploadVideoPath != null,
          fileName: _selectedUploadVideoName,
          fileSize: _selectedUploadVideoSize,
          onTap: uploadingVideo ? null : _pickRightVideoFile,
        ),
        const SizedBox(height: 10),
        _uploadPickerCard(
          title: 'Превью',
          subtitle: _selectedUploadThumbPath == null ? 'Необязательно · изображение для карточки' : 'Превью выбрано',
          buttonText: _selectedUploadThumbPath == null ? 'Выбрать превью' : 'Заменить превью',
          icon: Icons.image_outlined,
          selected: _selectedUploadThumbPath != null,
          fileName: _selectedUploadThumbName,
          fileSize: _selectedUploadThumbSize,
          onTap: uploadingVideo ? null : _pickRightVideoThumb,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: const Color(0xFFF7FAF8), borderRadius: BorderRadius.circular(12)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _MatchProfileBrandDots(),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isHighlight
                      ? 'Нарезка будет привязана к этому матчу и сразу появится в разделе видео.'
                      : 'Большие записи загружаются по частям. После загрузки видео сразу появится в матче и в Video Center OS.',
                  style: AppTypography.secondary(color: const Color(0xFF667085)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _rightPanelUploadFooter({required String type}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFE9ECEA)))),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: uploadingVideo ? null : () => setState(() => _rightPanelMode = _MatchRightPanelMode.none),
              style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF667085), side: BorderSide.none, backgroundColor: const Color(0xFFF7F9F8)),
              child: Text('Отмена', style: AppTypography.action(color: const Color(0xFF667085))),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: uploadingVideo || _selectedUploadVideoPath == null
                  ? null
                  : () async {
                      final video = File(_selectedUploadVideoPath!);
                      if (!await video.exists()) {
                        Get.snackbar('Видео', 'Выбранный файл не найден');
                        return;
                      }
                      final thumb = _selectedUploadThumbPath?.isNotEmpty == true ? File(_selectedUploadThumbPath!) : null;
                      await _uploadVideoWithChunks(type: type, video: video, thumbnail: thumb);
                      if (mounted) setState(() => _rightPanelMode = _MatchRightPanelMode.none);
                    },
              icon: uploadingVideo
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.cloud_upload_outlined, size: 18),
              label: Text(uploadingVideo ? 'Загрузка...' : 'Загрузить', style: AppTypography.action(color: Colors.white)),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0B8F55)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _uploadPickerCard({
    required String title,
    required String subtitle,
    required String buttonText,
    required IconData icon,
    required bool selected,
    required VoidCallback? onTap,
    String? fileName,
    int? fileSize,
  }) {
    return Material(
      color: selected ? softAccent : softSurface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      
                    ),
                    child: Icon(icon, color: primary, size: 22),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.25,
                            fontWeight: FontWeight.w600,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: selected ? primary : Colors.white,
                      shape: BoxShape.circle,
                      
                    ),
                    child: Icon(
                      selected ? Icons.check_rounded : Icons.add_rounded,
                      color: selected ? Colors.white : primary,
                      size: 18,
                    ),
                  ),
                ],
              ),
              if (fileName != null && fileName.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.attach_file_rounded, color: primary, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fileName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatFileSize(fileSize ?? 0),
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 13),
                decoration: BoxDecoration(
                  color: selected ? Colors.white : primary,
                  borderRadius: BorderRadius.circular(14),
                  
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      selected ? Icons.swap_horiz_rounded : Icons.file_upload_outlined,
                      color: selected ? primary : Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      buttonText,
                      style: TextStyle(
                        color: selected ? primary : Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
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


  Map<String, dynamic> _mapFromAny(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  String _firstNonEmptyFromMaps(
    List<Map<String, dynamic>> maps,
    List<String> keys,
  ) {
    for (final map in maps) {
      for (final key in keys) {
        final value = _s(map[key]);
        if (value.isNotEmpty && value.toLowerCase() != 'null') return value;
      }
    }
    return '';
  }

  int _firstPositiveIntFromMaps(
    List<Map<String, dynamic>> maps,
    List<String> keys,
  ) {
    for (final map in maps) {
      for (final key in keys) {
        final value = _i(map[key]);
        if (value > 0) return value;
      }
    }
    return 0;
  }

  Map<String, dynamic>? _uploadedVideoFromResult({
    required Map<String, dynamic> result,
    required String type,
    required File video,
    File? thumbnail,
  }) {
    final data = _mapFromAny(result['data']);
    final videoMap = _mapFromAny(result['video']);
    final dataVideoMap = _mapFromAny(data['video']);
    final fileMap = _mapFromAny(result['file']);

    final maps = <Map<String, dynamic>>[
      dataVideoMap,
      videoMap,
      data,
      fileMap,
      result,
    ];

    final url = _firstNonEmptyFromMaps(maps, const [
      'video_url',
      'file_url',
      'url',
      'video_path',
      'file_path',
      'path',
      'src',
    ]);

    if (url.isEmpty) return null;

    final thumbUrl = _firstNonEmptyFromMaps(maps, const [
      'thumbnail_url',
      'thumb_url',
      'preview_url',
      'poster_url',
      'thumbnail',
      'thumb',
      'preview',
      'poster',
    ]);

    final id = _firstPositiveIntFromMaps(maps, const [
      'id',
      'video_id',
      'match_video_id',
    ]);

    final fileName = _firstNonEmptyFromMaps(maps, const [
      'file_name',
      'filename',
      'name',
      'title',
    ]);

    final size = _firstPositiveIntFromMaps(maps, const [
      'file_size',
      'size',
      'bytes',
    ]);

    return {
      if (id > 0) 'id': id,
      'match_id': matchId,
      'team_id': teamId,
      'video_type': type,
      'file_name': fileName.isNotEmpty ? fileName : video.uri.pathSegments.last,
      'video_url': _normalizeUrl(url) ?? url,
      if (thumbUrl.isNotEmpty) 'thumbnail_url': _normalizeUrl(thumbUrl) ?? thumbUrl,
      'file_size': size > 0 ? size : video.lengthSync(),
      'created_at': DateTime.now().toIso8601String().substring(0, 19),
      'uploaded_at': DateTime.now().toIso8601String().substring(0, 19),
    };
  }

  bool _sameVideoIdentity(Map<String, dynamic> a, Map<String, dynamic> b) {
    final aId = _i(a['id']);
    final bId = _i(b['id']);
    if (aId > 0 && bId > 0 && aId == bId) return true;

    final aUrl = (_normalizeUrl(_s(a['video_url'])) ?? '').trim();
    final bUrl = (_normalizeUrl(_s(b['video_url'])) ?? '').trim();
    return aUrl.isNotEmpty && bUrl.isNotEmpty && aUrl == bUrl;
  }

  bool _currentMatchContainsVideo(Map<String, dynamic> uploadedVideo) {
    final videos = ((match?['videos'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e));

    for (final video in videos) {
      if (_sameVideoIdentity(video, uploadedVideo)) return true;
    }
    return false;
  }

  void _ensureUploadedVideoVisible(Map<String, dynamic> uploadedVideo) {
    if (_currentMatchContainsVideo(uploadedVideo)) return;

    final current = Map<String, dynamic>.from(match ?? <String, dynamic>{});
    final currentVideos = ((current['videos'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    currentVideos.insert(0, uploadedVideo);
    current['videos'] = currentVideos;

    if (mounted) {
      setState(() => match = current);
    }
  }

  Future<void> _uploadVideoWithChunks({
    required String type,
    required File video,
    File? thumbnail,
  }) async {
    if (matchId <= 0) {
      Get.snackbar("Ошибка", "Некорректный match_id");
      return;
    }

    setState(() => uploadingVideo = true);

    final progressNotifier = ValueNotifier<double>(0.0);
    final textNotifier = ValueNotifier<String>("Подготовка...");

    _showUploadingDialog(
      progressNotifier: progressNotifier,
      textNotifier: textNotifier,
    );

    await Future.delayed(const Duration(milliseconds: 100));

    try {
      final notes = type == "highlight" ? "Видео момента" : "Полное видео матча";

      final result = await _chunkUploadService.uploadVideoInChunks(
        videoFile: video,
        thumbnailFile: thumbnail,
        matchId: matchId,
        teamId: teamId,
        coachId: _coachId,
        notes: notes,
        videoType: type,
        onProgress: (progress, text) {
          progressNotifier.value = progress.clamp(0.0, 1.0);
          textNotifier.value = text;
        },
      );

      _hideUploadingDialog();

      if (result["success"] == true) {
        developer.log(
          'UPLOAD VIDEO COMPLETE RESULT: ${jsonEncode(result)}',
          name: 'TeamMatchDetailScreen',
        );

        final uploadedVideo = _uploadedVideoFromResult(
          result: result,
          type: type,
          video: video,
          thumbnail: thumbnail,
        );

        // После загрузки сбрасываем старые video_player контроллеры. Иначе экран
        // может пытаться открыть старый повреждённый URL и падать с OSStatus -12848.
        _clearAnalysisVideoControllers();

        // Сначала обновляем данные с сервера. Если get_team_match_detail.php пока
        // не возвращает список videos, ниже добавим видео локально из ответа
        // complete_team_match_video_upload.php, чтобы пользователь сразу увидел файл.
        await load();

        if (uploadedVideo != null) {
          _ensureUploadedVideoVisible(uploadedVideo);
        }

        final serverReturnedVideo = uploadedVideo == null
            ? (((match?["videos"] as List?) ?? const []).isNotEmpty)
            : _currentMatchContainsVideo(uploadedVideo);

        Get.snackbar(
          "Успешно",
          serverReturnedVideo
              ? "Видео добавлено"
              : "Сервер принял видео, но detail API пока не вернул его в списке videos",
          backgroundColor: primary,
          colorText: Colors.white,
          duration: const Duration(seconds: 4),
        );
      } else {
        Get.snackbar(
          "Ошибка загрузки",
          _s(result["message"]).isNotEmpty
              ? _s(result["message"])
              : "Не удалось загрузить видео",
        );
      }
    } catch (e) {
      _hideUploadingDialog();
      Get.snackbar(
        "Ошибка сети",
        "Не удалось загрузить видео: $e",
      );
    } finally {
      progressNotifier.dispose();
      textNotifier.dispose();
      if (mounted) setState(() => uploadingVideo = false);
    }
  }

  void _hideUploadingDialog() {
    _uploadProgressOverlay?.remove();
    _uploadProgressOverlay = null;
  }

  OverlayState? _rootOverlayState() {
    try {
      return Navigator.of(context, rootNavigator: true).overlay ??
          Overlay.maybeOf(context, rootOverlay: true);
    } catch (_) {
      try {
        return Overlay.maybeOf(context, rootOverlay: true);
      } catch (_) {
        return null;
      }
    }
  }

  void _showRootBanner(
    String title,
    String message, {
    Color? backgroundColor,
    IconData icon = Icons.info_outline_rounded,
  }) {
    final overlay = _rootOverlayState();
    if (overlay == null) {
      Get.snackbar(title, message);
      return;
    }

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (overlayContext) {
        final media = MediaQuery.of(overlayContext);
        return Positioned(
          top: media.padding.top + 16,
          left: 18,
          right: 18,
          child: IgnorePointer(
            ignoring: false,
            child: Material(
              color: Colors.transparent,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: backgroundColor ?? const Color(0xFF101828),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.18),
                          blurRadius: 22,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(icon, color: Colors.white, size: 21),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13.5,
                                ),
                              ),
                              if (message.trim().isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  message,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.86),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                    height: 1.18,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () {
                            if (entry.mounted) entry.remove();
                          },
                          borderRadius: BorderRadius.circular(999),
                          child: const Padding(
                            padding: EdgeInsets.all(5),
                            child: Icon(Icons.close_rounded, color: Colors.white, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 4), () {
      if (entry.mounted) entry.remove();
    });
  }

  Future<bool> _confirmDeleteVideoOverlay(String fileName) async {
    final overlay = _rootOverlayState();
    if (overlay == null) {
      final result = await showDialog<bool>(
        context: context,
        useRootNavigator: true,
        builder: (_) => AlertDialog(
          title: const Text('Удалить видео?'),
          content: Text('Будет удалено только это видео:\n\n$fileName\n\nСам матч останется без изменений.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context, rootNavigator: true).pop(false), child: const Text('Отмена')),
            FilledButton(onPressed: () => Navigator.of(context, rootNavigator: true).pop(true), child: const Text('Удалить')),
          ],
        ),
      );
      return result == true;
    }

    final completer = Completer<bool>();
    late OverlayEntry entry;

    void close(bool result) {
      if (!completer.isCompleted) completer.complete(result);
      if (entry.mounted) entry.remove();
    }

    entry = OverlayEntry(
      builder: (overlayContext) {
        return Material(
          color: Colors.black.withOpacity(0.42),
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 18),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.22),
                        blurRadius: 34,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFE9E7),
                              borderRadius: BorderRadius.circular(17),
                            ),
                            child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFD92D20)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Удалить видео?',
                              style: _TeamMatchUiText.screenTitle(
                                color: const Color(0xFF101828),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => close(false),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Будет удалено только это видео. Сам матч останется без изменений.',
                        style: const TextStyle(
                          color: Color(0xFF667085),
                          fontSize: 13,
                          height: 1.32,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF6F8FA),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          fileName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF101828),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => close(false),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF475467),
                                side: BorderSide.none,
                                backgroundColor: const Color(0xFFF2F4F7),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: const Text('Отмена', style: TextStyle(fontWeight: FontWeight.w600)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => close(true),
                              icon: const Icon(Icons.delete_outline_rounded, size: 18),
                              label: const Text('Удалить'),
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFD92D20),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                textStyle: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(entry);
    return completer.future;
  }

  void _showUploadingDialog({
    required ValueNotifier<double> progressNotifier,
    required ValueNotifier<String> textNotifier,
  }) {
    _hideUploadingDialog();

    final overlay = _rootOverlayState() ?? Overlay.of(context, rootOverlay: true);

    _uploadProgressOverlay = OverlayEntry(
      builder: (overlayContext) {
        return Material(
          color: Colors.black.withOpacity(0.36),
          child: Center(
            child: Dialog(
              elevation: 0,
              insetPadding: const EdgeInsets.symmetric(horizontal: 22),
              backgroundColor: Colors.transparent,
              child: ValueListenableBuilder<double>(
                valueListenable: progressNotifier,
                builder: (_, progress, __) {
                  return ValueListenableBuilder<String>(
                    valueListenable: textNotifier,
                    builder: (_, text, __) {
                      final normalized = progress.clamp(0.0, 1.0);
                      final percent = (normalized * 100).round();

                      return Container(
                        width: 380,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(26),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 66,
                              height: 66,
                              decoration: BoxDecoration(
                                color: softAccent,
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: Icon(
                                Icons.cloud_upload_rounded,
                                color: primary,
                                size: 32,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              "Загружаем видео",
                              textAlign: TextAlign.center,
                              style: _TeamMatchUiText.screenTitle(
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "Файл отправляется на сервер чанками",
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12.5,
                                height: 1.25,
                                fontWeight: FontWeight.w600,
                                color: textSecondary,
                              ),
                            ),
                            const SizedBox(height: 18),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                value: normalized <= 0 ? 0 : normalized,
                                minHeight: 10,
                                backgroundColor: const Color(0xFFD7E8DE),
                                valueColor: AlwaysStoppedAnimation<Color>(primary),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    text,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      height: 1.22,
                                      fontWeight: FontWeight.w600,
                                      color: textSecondary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: softAccent,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    '$percent%',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(_uploadProgressOverlay!);
  }

  // ============================================================
// МЕТОД ДЛЯ ОТКРЫТИЯ ВИДЕО В CMR-ОКНЕ
// ============================================================
void _openVideoPlayerCmrWindow(String videoUrl, {String? title}) {
  final resolvedTitle = (title ?? _matchTitleForReview()).trim().isEmpty
      ? 'Видео матча'
      : (title ?? _matchTitleForReview()).trim();
  final overlay = _rootOverlayState();

  if (overlay == null) {
    Get.to(
      () => MatchVideoPlayerScreen(
        videoUrl: videoUrl,
        title: resolvedTitle,
      ),
    );
    return;
  }

  // ← ВЕСЬ ЭТОТ КОД ДОЛЖЕН БЫТЬ ЗДЕСЬ, ВНУТРИ МЕТОДА!
  late OverlayEntry entry;
  Offset position = const Offset(82, 54);
  bool minimized = false;
  bool maximized = false;
  bool closed = false;

  void closeWindow() {
    if (closed) return;
    closed = true;
    entry.remove();
  }

  entry = OverlayEntry(
    builder: (overlayContext) {
      final media = MediaQuery.of(overlayContext);
      final screen = media.size;
      final compact = screen.width < 720;
      final double width = maximized
          ? screen.width - 20
          : compact
              ? screen.width - 16
              : min(1120.0, max(760.0, screen.width * .76));
      final double height = maximized
          ? screen.height - media.padding.top - media.padding.bottom - 20
          : compact
              ? screen.height - media.padding.top - media.padding.bottom - 20
              : min(720.0, max(500.0, screen.height * .74));
      final double left = maximized || compact
          ? (compact ? 8.0 : 10.0)
          : position.dx.clamp(12.0, max(12.0, screen.width - width - 12.0)).toDouble();
      final double top = maximized || compact
          ? media.padding.top + (compact ? 8.0 : 10.0)
          : position.dy
              .clamp(
                media.padding.top + 12.0,
                max(media.padding.top + 12.0, screen.height - height - 12.0),
              )
              .toDouble();

      if (minimized) {
        return Positioned(
          left: 18,
          bottom: media.padding.bottom + 18,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                minimized = false;
                entry.markNeedsBuild();
              },
              borderRadius: BorderRadius.circular(18),
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 13),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE5ECE8)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(.10),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.play_circle_outline_rounded, color: Color(0xFF00A750), size: 16),
                    const SizedBox(width: 8),
                    Text(
                      resolvedTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF111827),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      return Positioned(
        left: left,
        top: top,
        width: width,
        height: height,
        child: Material(
          color: Colors.transparent,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(compact || maximized ? 18 : 24),
              border: Border.all(color: const Color(0xFFE3EAE7)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.16),
                  blurRadius: 44,
                  offset: const Offset(0, 22),
                ),
              ],
            ),
            child: Column(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: maximized || compact
                      ? null
                      : (details) {
                          position += details.delta;
                          entry.markNeedsBuild();
                        },
                  child: Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(bottom: BorderSide(color: Color(0xFFE8EEE9))),
                    ),
                    child: Row(
                      children: [
                        _TeamMatchCmrWindowButton(icon: Icons.close_rounded, tooltip: 'Закрыть', onTap: closeWindow),
                        const SizedBox(width: 7),
                        _TeamMatchCmrWindowButton(
                          icon: Icons.remove_rounded,
                          tooltip: 'Свернуть',
                          onTap: () {
                            minimized = true;
                            entry.markNeedsBuild();
                          },
                        ),
                        const SizedBox(width: 7),
                        _TeamMatchCmrWindowButton(
                          icon: maximized ? Icons.close_fullscreen_rounded : Icons.open_in_full_rounded,
                          tooltip: maximized ? 'Вернуть размер' : 'Развернуть',
                          onTap: () {
                            maximized = !maximized;
                            entry.markNeedsBuild();
                          },
                        ),
                        const SizedBox(width: 15),
                        Container(
                          width: 31,
                          height: 31,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F6F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.play_circle_outline_rounded, color: Color(0xFF1F2937), size: 16),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Видео матча',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _TeamMatchUiText.title(13.0),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                resolvedTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _TeamMatchUiText.body(10.4, color: const Color(0xFF667085), weight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: ClipRect(
                    child: MatchVideoPlayerScreen(
                      videoUrl: videoUrl,
                      title: resolvedTitle,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  overlay.insert(entry);
}  // ← ЗАКРЫВАЮЩАЯ СКОБКА МЕТОДА _openVideoPlayerCmrWindow

// ============================================================
// МЕТОД ДЛЯ ПРОСМОТРА ВИДЕО
// ============================================================
void _watchVideo(String videoUrl, {String? title}) {
  final normalized = _normalizeUrl(videoUrl) ?? "";
  if (normalized.isEmpty) {
    Get.snackbar("Видео", "URL отсутствует");
    return;
  }

  _openVideoPlayerCmrWindow(
    normalized,
    title: title ?? _matchTitleForReview(),
  );
}

Map<String, dynamic> _analysisParamsForVideo(Map<String, dynamic> video, {String? fallbackUrl}) {
  final rawUrl = _s(video["video_url"]).isNotEmpty
      ? _s(video["video_url"])
      : (_s(video["file_url"]).isNotEmpty ? _s(video["file_url"]) : (fallbackUrl ?? ''));
  final normalized = _normalizeUrl(rawUrl) ?? '';
  final resolvedTeamId = teamId > 0 ? teamId : (widget.teamId ?? _i(match?["team_id"]));
  final resolvedTeamName = teamName.trim().isNotEmpty
      ? teamName.trim()
      : ((widget.teamName ?? '').trim().isNotEmpty ? widget.teamName!.trim() : 'Команда');
  final players = ((match?["players"] as List?) ?? [])
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();

  return {
    'sourceMode': 'recording',
    'matchId': matchId,
    'clubId': widget.clubId ?? _i(match?["club_id"]),
    'teamId': resolvedTeamId,
    'fieldId': _i(match?["field_id"]),
    'coachId': _coachId,
    'videoUrl': normalized,
    'teamName': resolvedTeamName,
    'matchTitle': _matchTitleForReview(),
    'videoId': _i(video["id"]),
    'teamColors': _extractTeamColors(),
    'sessionIds': _analysisTrackerSessionIds(),
    'players': players.map((player) {
      return {
        'id': player['id'],
        'number': player['number'],
        'name': _playerName(player),
        'position': player['position'],
      };
    }).toList(),
  };
}

List<int> _analysisTrackerSessionIds() {
  final raw = match?["tracker_session_ids"] ??
      match?["tracker_sessions"] ??
      match?["session_ids"] ??
      match?["tracker_session_id"];
  final values = raw is List ? raw : _s(raw).replaceAll(';', ',').split(',');
  return values
      .map((value) => int.tryParse(_s(value)) ?? 0)
      .where((value) => value > 0)
      .toSet()
      .toList();
}

Future<void> _openMatchLive({Map<String, dynamic>? video}) async {
  final params = _analysisParamsForVideo(video ?? const <String, dynamic>{});
  await MatchLiveScreen.open(context, params: params, initialMode: 'live');
}

void _openMatchRecordingAnalysis() {
  final video = _primaryAiVideo();
  if (video == null) {
    _openMatchDetailTab(4);
    Get.snackbar(
      'Анализ записи',
      'Сначала загрузите полное видео матча',
    );
    return;
  }
  _openMatchDetailTab(5);
}

// ============================================================
// МЕТОД ДЛЯ ОТКРЫТИЯ AI-АНАЛИЗА
// ============================================================
Future<void> _openMatchVideoAnalysis(Map<String, dynamic> video) async {
  final analysisParams = _analysisParamsForVideo(video);
  final normalized = _s(analysisParams['videoUrl']);

  if (normalized.isEmpty) {
    Get.snackbar("Внимание", "Видео матча отсутствует");
    return;
  }

  if (!mounted) return;

  await showAdvancedVideoAnalysisWindow(
    context,
    analysisParams,
    externalPlaybackController: _embeddedAiPlayback,
    // В полном окне Advanced Video оставляем controls: пользователь должен
    // иметь возможность остановить/запустить видео прямо там. В маленькой
    // карточке обзора controls всё равно скрыты.
    hideControls: false,
  );
}

// ============================================================
// МЕТОД ДЛЯ ОТКРЫТИЯ CMR-ОКНА С AI-АНАЛИЗОМ
// ============================================================
void _openAiReviewCmrWindow() {
  final video = _primaryAiVideo();
  if (video == null) {
    Get.snackbar('Ошибка', 'Сначала загрузите видео матча');
    return;
  }
  _openMatchVideoAnalysis(video);
}  // ← ЗАКРЫТИЕ МЕТОДА


// ============================================================
// МЕТОД ДЛЯ ПОКАЗА ДЕТАЛЕЙ ВИДЕО (Overlay)
// ============================================================
void _showVideoDetailsOverlay(
  Map<String, dynamic> video, {
  required String title,
  required bool canAnalyze,
}) {
  final overlay = _rootOverlayState();
  if (overlay == null) {
    _showRootBanner(
      'Видео',
      'Не удалось открыть детали поверх экрана',
      icon: Icons.info_outline_rounded,
    );
    return;
  }

  final fileName = _s(video['file_name']).isNotEmpty
      ? _s(video['file_name'])
      : (_s(video['title']).isNotEmpty ? _s(video['title']) : title);
  final videoUrl = _s(video['video_url']).isNotEmpty
      ? _s(video['video_url'])
      : _s(video['file_url']);
  final meta = _videoMeta(video);

  late OverlayEntry entry;

  void close() {
    if (entry.mounted) entry.remove();
  }

  Widget action({
    required IconData icon,
    required String label,
    required Color accent,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: danger ? const Color(0xFFFEF2F2) : Colors.white.withOpacity(.90),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: danger ? const Color(0xFFFECACA) : accent.withOpacity(.16),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.035),
                blurRadius: 14,
                spreadRadius: -10,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: danger ? const Color(0xFFDC2626) : accent, size: 17),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _TeamMatchUiText.action(
                    color: danger ? const Color(0xFFDC2626) : const Color(0xFF0B0F14),
                    size: 11.6,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  entry = OverlayEntry(
    builder: (overlayContext) {
      final media = MediaQuery.of(overlayContext);
      final screen = media.size;
      final isPhone = screen.width < 640;

      return Material(
        color: Colors.black.withOpacity(.24),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: close,
                  child: const SizedBox.expand(),
                ),
              ),
              Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: isPhone ? screen.width - 28 : 460),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 14),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(.86), width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(.14),
                          blurRadius: 38,
                          spreadRadius: -16,
                          offset: const Offset(0, 22),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3FBF7),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFDCEFE5)),
                              ),
                              child: const Icon(Icons.video_file_outlined, color: Color(0xFF00A750), size: 19),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Детали видео',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: _TeamMatchUiText.title(15.2),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    meta.isEmpty ? 'Файл матча' : meta,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: _TeamMatchUiText.body(
                                      11,
                                      color: const Color(0xFF6B7280),
                                      weight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            _TeamMatchCmrWindowButton(
                              icon: Icons.close_rounded,
                              tooltip: 'Закрыть',
                              onTap: close,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F9FA),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title.isEmpty ? fileName : title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: _TeamMatchUiText.title(13.2),
                              ),
                              if (fileName.trim().isNotEmpty && fileName != title) ...[
                                const SizedBox(height: 5),
                                Text(
                                  fileName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: _TeamMatchUiText.body(
                                    10.8,
                                    color: const Color(0xFF6B7280),
                                    weight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (isPhone)
                          Column(
                            children: [
                              action(
                                icon: Icons.visibility_outlined,
                                label: 'Смотреть',
                                accent: primary,
                                onTap: videoUrl.trim().isEmpty
                                    ? () {
                                        close();
                                        _showRootBanner('Видео', 'Ссылка на видео отсутствует');
                                      }
                                    : () {
                                        close();
                                        _watchVideo(videoUrl, title: title);
                                      },
                              ),
                              if (canAnalyze) ...[
                                const SizedBox(height: 8),
                                action(
                                  icon: Icons.analytics_outlined,
                                  label: 'ИИ-анализ',
                                  accent: const Color(0xFF2563EB),
                                  onTap: () {
                                    close();
                                    _openMatchVideoAnalysis(video);
                                  },
                                ),
                              ],
                              const SizedBox(height: 8),
                              action(
                                icon: Icons.delete_outline_rounded,
                                label: 'Удалить',
                                accent: const Color(0xFFDC2626),
                                danger: true,
                                onTap: () {
                                  close();
                                  _deleteVideo(video);
                                },
                              ),
                            ],
                          )
                        else
                          Row(
                            children: [
                              Expanded(
                                child: action(
                                  icon: Icons.visibility_outlined,
                                  label: 'Смотреть',
                                  accent: primary,
                                  onTap: videoUrl.trim().isEmpty
                                      ? () {
                                          close();
                                          _showRootBanner('Видео', 'Ссылка на видео отсутствует');
                                        }
                                      : () {
                                          close();
                                          _watchVideo(videoUrl, title: title);
                                        },
                                ),
                              ),
                              if (canAnalyze) ...[
                                const SizedBox(width: 8),
                                Expanded(
                                  child: action(
                                    icon: Icons.analytics_outlined,
                                    label: 'ИИ-анализ',
                                    accent: const Color(0xFF2563EB),
                                    onTap: () {
                                      close();
                                      _openMatchVideoAnalysis(video);
                                    },
                                  ),
                                ),
                              ],
                              const SizedBox(width: 8),
                              Expanded(
                                child: action(
                                  icon: Icons.delete_outline_rounded,
                                  label: 'Удалить',
                                  accent: const Color(0xFFDC2626),
                                  danger: true,
                                  onTap: () {
                                    close();
                                    _deleteVideo(video);
                                  },
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  overlay.insert(entry);
}  // ← ЗАКРЫВАЮЩАЯ СКОБКА МЕТОДА _showVideoDetailsOverlay

// ============================================================
// МЕТОД ДЛЯ УДАЛЕНИЯ ВИДЕО
// ============================================================
Future<void> _deleteVideo(Map<String, dynamic> video) async {
  final videoId = int.tryParse('${video["id"] ?? 0}') ?? 0;
  final videoUrl = _s(video["video_url"]).isNotEmpty
      ? _s(video["video_url"])
      : _s(video["file_url"]);
  final fileName = _s(video["file_name"]).isNotEmpty
      ? _s(video["file_name"])
      : (_s(video["title"]).isNotEmpty ? _s(video["title"]) : "Видео матча");

  if (videoId <= 0 && videoUrl.trim().isEmpty) {
    _showRootBanner(
      "Ошибка",
      "Не найден id или ссылка видео для удаления",
      backgroundColor: const Color(0xFFD92D20),
      icon: Icons.error_outline_rounded,
    );
    return;
  }

  final confirmed = await _confirmDeleteVideoOverlay(fileName);
  if (confirmed != true) return;

  try {
    final payload = {
      "video_id": videoId,
      "id": videoId,
      "match_video_id": videoId,
      "match_id": matchId,
      "team_id": teamId,
      "video_url": videoUrl,
      "file_url": videoUrl,
    };

    http.Response resp = await http
        .post(
          Uri.parse(deleteVideoUrl),
          headers: const {"Content-Type": "application/json; charset=utf-8"},
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 20));

    Map<String, dynamic> data = _decodeResponse(resp);

    if (!(data["success"] == true || data["status"] == "success") && resp.statusCode >= 400) {
      resp = await http
          .post(
            Uri.parse(deleteVideoUrl),
            body: payload.map((key, value) => MapEntry(key, '$value')),
          )
          .timeout(const Duration(seconds: 20));
      data = _decodeResponse(resp);
    }

    if (data["success"] == true || data["status"] == "success") {
      final current = match;
      if (current != null) {
        final list = ((current["videos"] as List?) ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .where((e) {
              final currentId = int.tryParse('${e["id"] ?? 0}') ?? 0;
              final currentUrl = _s(e["video_url"]).isNotEmpty ? _s(e["video_url"]) : _s(e["file_url"]);
              if (videoId > 0 && currentId == videoId) return false;
              if (videoUrl.trim().isNotEmpty && currentUrl == videoUrl) return false;
              return true;
            })
            .toList();
        current["videos"] = list;
        if (mounted) setState(() => match = current);
      }

      _clearAnalysisVideoControllers();
      _showRootBanner(
        "Видео удалено",
        "Матч остался без изменений",
        backgroundColor: primary,
        icon: Icons.check_circle_outline_rounded,
      );
      await load();
    } else {
      _showRootBanner(
        "Ошибка удаления",
        data["message"]?.toString() ?? "Не удалось удалить видео",
        backgroundColor: const Color(0xFFD92D20),
        icon: Icons.error_outline_rounded,
      );
    }
  } catch (e) {
    _showRootBanner(
      "Ошибка сети",
      "Не удалось удалить видео: $e",
      backgroundColor: const Color(0xFFD92D20),
      icon: Icons.wifi_off_rounded,
    );
  }
}  // ← ЗАКРЫВАЮЩАЯ СКОБКА МЕТОДА _deleteVideo

  Widget _videoAddButton({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: onTap == null ? const Color(0xFFD7E8DE) : primary,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 17),
              const SizedBox(width: 7),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHighlightsTab() {
    final videos = ((match?["videos"] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e))
        .where((e) => _s(e["video_type"]) == "highlight")
        .toList();

    final isPhone = MediaQuery.of(context).size.width < 600;

    return ListView(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(isPhone ? 8 : 16, isPhone ? 8 : 16, isPhone ? 8 : 16, isPhone ? 96 : 16),
      children: [
        _buildSectionCard(
          title: "Нарезка моментов",
          subtitle: "Короткие фрагменты игры для разбора — в таком же компактном виде, как видео матча",
          trailing: _videoAddButton(
            label: uploadingVideo ? "Загрузка..." : "Добавить",
            icon: Icons.video_library_outlined,
            onTap: uploadingVideo ? null : () => _showUploadVideoSheet("highlight"),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (videos.isEmpty)
                _emptyState("Видеонарезок пока нет", icon: Icons.video_collection_outlined)
              else
                _responsiveGrid(
                  minItemWidth: 300,
                  maxColumns: 4,
                  children: videos.map((v) {
                    final rawTitle = _s(v["file_name"]);
                    final title = _formatVideoTitle(rawTitle, "Видео момента");
                    return _VideoTile(
                      title: title,
                      subtitle: _videoMeta(v),
                      url: _s(v["video_url"]),
                      onWatch: () => _watchVideo(
                        _s(v["video_url"]),
                        title: title,
                      ),
                      onDetails: () => _showVideoDetailsOverlay(
                        v,
                        title: title,
                        canAnalyze: false,
                      ),
                      onDelete: () => _deleteVideo(v),
                      primary: primary,
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
      ],
    );
  }


  Widget _buildInlineMatchMainNote({required VoidCallback onClose}) {
    final resolvedClubId = _workspaceClubId > 0
        ? _workspaceClubId
        : (widget.clubId ?? _i(match?["club_id"] ?? match?["clubId"]));
    final resolvedMatchId = matchId > 0 ? matchId : _i(match?["match_id"] ?? match?["id"]);
    return WorkspaceEntityRecordDocument(
      ownerTitle: _currentMatchActionTitle,
      sectionTitle: 'Документы и заметки',
      title: 'Заметка матча',
      iconKind: SportotekaWorkspaceIconKind.document,
      record: Map<String, dynamic>.from(match ?? const <String, dynamic>{}),
      properties: <WorkspaceEntityProperty>[
        WorkspaceEntityProperty('Матч', _currentMatchActionTitle),
        if (_s(match?['match_date'] ?? match?['info_date']).isNotEmpty)
          WorkspaceEntityProperty('Дата', _s(match?['match_date'] ?? match?['info_date'])),
      ],
      noteKey: 'match:$resolvedMatchId',
      entityType: 'match',
      entityId: '$resolvedMatchId',
      clubId: resolvedClubId,
      serverParentKey: 'entity:match:$resolvedMatchId',
      onClose: onClose,
    );
  }

  Widget _buildDocumentsNotesTab() {
    final resolvedClubId = _workspaceClubId > 0
        ? _workspaceClubId
        : (widget.clubId ?? _i(match?["club_id"] ?? match?["clubId"]));
    final resolvedMatchId = matchId > 0 ? matchId : _i(match?["match_id"] ?? match?["id"]);

    if (resolvedMatchId <= 0) {
      return Center(
        child: Text(
          'Не удалось определить матч для документов и заметок',
          style: AppTypography.secondary(color: textSecondary),
        ),
      );
    }

    return WorkspaceEntityRecordBrowser(
      ownerTitle: _currentMatchActionTitle,
      sectionTitle: 'Документы и заметки',
      iconKind: SportotekaWorkspaceIconKind.documents,
      loadRecords: () async => <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'match-note:$resolvedMatchId',
          'title': 'Заметка матча',
          'description': 'Общая редактируемая заметка · синхронизируется с Workspace OS',
          'updated_at': _s(match?['updated_at'] ?? match?['match_date'] ?? match?['info_date']),
          '_workspace_match_main_note': true,
        },
      ],
      titleFor: (row) => _s(row['title']).isEmpty ? 'Материал матча' : _s(row['title']),
      subtitleFor: (row) => _s(row['description'] ?? row['notes'] ?? row['comment']),
      dateFor: (row) => _s(row['updated_at'] ?? row['created_at'] ?? row['date']),
      propertiesFor: (row) => <WorkspaceEntityProperty>[
        const WorkspaceEntityProperty('Матч', 'Общий рабочий документ'),
        if (_s(row['created_at']).isNotEmpty) WorkspaceEntityProperty('Создано', _s(row['created_at'])),
        if (_s(row['updated_at']).isNotEmpty) WorkspaceEntityProperty('Изменено', _s(row['updated_at'])),
      ],
      openRecord: (context, row) async {
        if (row['_workspace_match_main_note'] != true) return;
        if (widget.documentsOnly || _rightPanelMode == _MatchRightPanelMode.documents) {
          if (mounted) setState(() => _embeddedMainNoteOpen = true);
          return;
        }
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => Scaffold(
              backgroundColor: Colors.white,
              body: SafeArea(child: _buildInlineMatchMainNote(onClose: () => Navigator.of(context).maybePop())),
            ),
          ),
        );
      },
      emptyText: 'У матча пока нет документов и заметок. Добавьте заметку или перетащите сюда файл.',
      localStorageKey: 'sportoteka_match_materials_${resolvedClubId}_$resolvedMatchId',
      contextLabel: 'Матч',
      clubId: resolvedClubId,
      serverParentKey: 'entity:match:$resolvedMatchId:materials',
      attachmentEntityType: 'match',
      attachmentEntityId: resolvedMatchId,
      attachmentSectionKey: 'documents_notes',
      showBackButton: false,
    );
  }

  Widget _buildVideosTab() {
    final videos = ((match?["videos"] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e))
        .where((e) => _s(e["video_type"]) == "full")
        .toList();

    final isPhone = MediaQuery.of(context).size.width < 600;

    return ListView(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(isPhone ? 8 : 16, isPhone ? 8 : 16, isPhone ? 8 : 16, isPhone ? 96 : 16),
      children: [
        _buildSectionCard(
          title: "Видео матча",
          subtitle: "Полные записи игры без широких растянутых баннеров",
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _matchActionsButton(),
              const SizedBox(width: 8),
              _videoAddButton(
                label: uploadingVideo ? "Загрузка..." : "Добавить",
                icon: Icons.cloud_upload_outlined,
                onTap: uploadingVideo ? null : () => _showUploadVideoSheet("full"),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (videos.isEmpty)
                _emptyState("Видео матча пока нет", icon: Icons.videocam_off_outlined)
              else
                _responsiveGrid(
                  minItemWidth: 300,
                  maxColumns: 4,
                  children: videos.map((v) {
                    final rawTitle = _s(v["file_name"]);
                    final title = _formatVideoTitle(rawTitle, "Видео матча");
                    return _VideoTile(
                      title: title,
                      subtitle: _videoMeta(v),
                      url: _s(v["video_url"]),
                      onWatch: () => _watchVideo(
                        _s(v["video_url"]),
                        title: title,
                      ),
                      onAnalyze: () => _openMatchVideoAnalysis(v),
                      onDetails: () => _showVideoDetailsOverlay(
                        v,
                        title: title,
                        canAnalyze: true,
                      ),
                      onDelete: () => _deleteVideo(v),
                      primary: primary,
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
      ],
    );
  }

  List<_MatchDetailNavItem> get _matchNavItems => const [
        _MatchDetailNavItem(
          title: "Обзор",
          subtitle: "данные матча",
          icon: Icons.dashboard_customize_outlined,
        ),
        _MatchDetailNavItem(
          title: "Основные ТТД",
          subtitle: "действия",
          icon: Icons.query_stats_rounded,
        ),
        _MatchDetailNavItem(
          title: "Эпизоды",
          subtitle: "моменты",
          icon: Icons.movie_filter_outlined,
        ),
        _MatchDetailNavItem(
          title: "Нарезка",
          subtitle: "фрагменты",
          icon: Icons.video_library_outlined,
        ),
        _MatchDetailNavItem(
          title: "Видео",
          subtitle: "полная игра",
          icon: Icons.play_circle_outline_rounded,
        ),
        _MatchDetailNavItem(
          title: "Видеоанализ ИИ",
          subtitle: "разбор видео",
          icon: Icons.psychology_alt_rounded,
        ),
        _MatchDetailNavItem(
          title: "Документы и заметки",
          subtitle: "файлы и записи",
          icon: Icons.folder_copy_outlined,
        ),
      ];

  int _safeMatchTabIndex(int index) {
    final maxIndex = _matchNavItems.length - 1;
    if (maxIndex < 0) return 0;
    return max(0, min(index, maxIndex));
  }

  String get _currentTabTitle {
    final index = _safeMatchTabIndex(_tabController.index);
    return _matchNavItems[index].title;
  }

  void _openMatchDetailTab(int index) {
    final target = _safeMatchTabIndex(index);
    if (_tabController.index != target) {
      _tabController.animateTo(
        target,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
      );
    }
    if (mounted) setState(() {});
  }

  Widget _activeTabWidgetByIndex(int index) {
    switch (_safeMatchTabIndex(index)) {
      case 0:
        return _buildOverviewTab();
      case 1:
        return _buildMainTtdTab();
      case 2:
        return _buildEpisodesTab();
      case 3:
        return _buildHighlightsTab();
      case 4:
        return _buildVideosTab();
      case 5:
        return _buildAiVideoAnalysisTab();
      case 6:
        return _buildDocumentsNotesTab();
      default:
        return _buildOverviewTab();
    }
  }

  Widget _buildActiveTabContent() {
    final isPhone = (MediaQuery.maybeOf(context)?.size.width ?? 1000) < 600;

    // На телефоне TabBarView часто давал ощущение, что раздел не открылся:
    // контент жил внутри сложной прокрутки, а переключение визуально не обновлялось.
    // Поэтому мобильная версия строит активный раздел напрямую по индексу.
    if (isPhone) {
      return AnimatedBuilder(
        animation: _tabController,
        builder: (context, _) => KeyedSubtree(
          key: ValueKey('match-detail-mobile-tab-${_tabController.index}'),
          child: _activeTabWidgetByIndex(_tabController.index),
        ),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildOverviewTab(),
        _buildMainTtdTab(),
        _buildEpisodesTab(),
        _buildHighlightsTab(),
        _buildVideosTab(),
        _buildAiVideoAnalysisTab(),
        _buildDocumentsNotesTab(),
      ],
    );
  }

  Map<String, dynamic>? _primaryAiVideo() {
    final videos = ((match?["videos"] as List?) ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    if (videos.isEmpty) return null;

    Map<String, dynamic>? firstWithUrl(Iterable<Map<String, dynamic>> source) {
      for (final video in source) {
        final normalized = _normalizeUrl(_s(video["video_url"])) ?? "";
        if (normalized.isNotEmpty) return video;
      }
      return null;
    }

    return firstWithUrl(videos.where((e) => _s(e["video_type"]) == "full")) ??
        firstWithUrl(videos.where((e) => _s(e["video_type"]) == "highlight")) ??
        firstWithUrl(videos);
  }

  Widget _buildAiVideoAnalysisTab() {
    final video = _primaryAiVideo();
    final resolvedTeamId =
        teamId > 0 ? teamId : (widget.teamId ?? _i(match?['team_id']));

    if (resolvedTeamId <= 0) {
      return _matchAiEmptyState(
        icon: Icons.info_outline_rounded,
        title: 'Не удалось определить команду',
        subtitle: 'Откройте матч из карточки команды, чтобы ИИ получил teamId и состав.',
      );
    }

    if (video == null || _s(_analysisParamsForVideo(video)['videoUrl']).isEmpty) {
      return _matchAiEmptyState(
        icon: Icons.video_file_outlined,
        title: 'Добавьте полную запись матча',
        subtitle:
            'После загрузки ИИ начнёт распознавать игроков, мяч и события прямо на этой странице.',
        action: ElevatedButton.icon(
          onPressed: uploadingVideo ? null : () => _showUploadVideoSheet('full'),
          icon: const Icon(Icons.cloud_upload_outlined, size: 18),
          label: Text(uploadingVideo ? 'Загрузка...' : 'Загрузить видео'),
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: _mcGreen,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );
    }

    final params = _analysisParamsForVideo(video);

    return ColoredBox(
      color: Colors.white,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 840;
          final medium = constraints.maxWidth < 1120;
          final topSpeed = _liveAiSpeedsKmh.isEmpty
              ? 0.0
              : _liveAiSpeedsKmh.values.reduce(max);
          final sprintCount = _liveAiSprints.values.fold<int>(
            0,
            (sum, value) => sum + value,
          );
          final load = _liveAiLoad.isEmpty
              ? 0.0
              : _liveAiLoad.values.reduce((a, b) => a + b) /
                  _liveAiLoad.length;

          final videoStage = ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AdvancedVideoAnalysisScreen(
              key: ValueKey('inline-match-ai-${_i(video['id'])}-${_s(params['videoUrl'])}'),
              params: params,
              embedded: true,
              modalWindow: false,
              hideControls: true,
              connectAi: true,
              showAiOverlay: true,
              externalPlaybackController: _embeddedAiPlayback,
              onAnalysisFrame: _onLiveAiFrame,
              onStatusChanged: _onLiveAiStatus,
            ),
          );

          final metrics = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _inlineAiMetric(
                icon: Icons.people_alt_outlined,
                label: 'В кадре',
                value: '${_liveAiPlayers.length}',
                suffix: 'игроков',
              ),
              _inlineAiMetric(
                icon: Icons.speed_rounded,
                label: 'Макс. скорость',
                value: topSpeed.toStringAsFixed(1),
                suffix: 'км/ч',
              ),
              _inlineAiMetric(
                icon: Icons.bolt_rounded,
                label: 'Спринты',
                value: '$sprintCount',
                suffix: 'событий',
              ),
              _inlineAiMetric(
                icon: Icons.monitor_heart_outlined,
                label: 'Нагрузка',
                value: load.toStringAsFixed(0),
                suffix: 'средняя',
              ),
            ],
          );

          final header = Container(
            constraints: const BoxConstraints(minHeight: 58),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: _mcLine.withOpacity(.7))),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF8F1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.auto_awesome_rounded, color: _mcGreen, size: 19),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'ИИ-видеоповтор',
                        style: TextStyle(
                          color: Color(0xFF111827),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: _liveAiPlayers.isNotEmpty
                                  ? _mcGreen
                                  : const Color(0xFFF59E0B),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _liveAiStatus,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.captionMedium(color: _mcSub),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (!compact) ...[
                  TextButton.icon(
                    onPressed: () => _openMatchLive(video: video),
                    icon: const Icon(Icons.sensors_rounded, size: 17),
                    label: const Text('Онлайн-матч'),
                    style: TextButton.styleFrom(
                      foregroundColor: _mcGreen,
                      textStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 5),
                  IconButton(
                    tooltip: 'Развернуть видеоповтор',
                    onPressed: () => _openMatchVideoAnalysis(video),
                    icon: const Icon(Icons.open_in_full_rounded, size: 20),
                    color: _mcText,
                  ),
                ],
              ],
            ),
          );

          if (compact) {
            return Column(
              children: [
                header,
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AspectRatio(aspectRatio: 16 / 9, child: videoStage),
                        const SizedBox(height: 12),
                        metrics,
                        const SizedBox(height: 12),
                        SizedBox(height: 250, child: _inlineAiEventsPanel()),
                        const SizedBox(height: 12),
                        SizedBox(height: 290, child: _inlineAiPitchPanel()),
                        const SizedBox(height: 12),
                        SizedBox(height: 230, child: _inlineAiPlayersPanel()),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                child: metrics,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: medium ? 7 : 8,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: videoStage),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: medium ? 138 : 154,
                              child: _inlineAiEventsPanel(horizontal: true),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: medium ? 286 : 326,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(flex: 6, child: _inlineAiPitchPanel()),
                            const SizedBox(height: 10),
                            Expanded(flex: 4, child: _inlineAiPlayersPanel()),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _matchAiEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? action,
  }) {
    return ColoredBox(
      color: Colors.white,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF8F1),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(icon, color: _mcGreen, size: 28),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: AppTypography.sectionTitle(color: _mcText),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: AppTypography.secondary(color: _mcSub),
                ),
                if (action != null) ...[
                  const SizedBox(height: 18),
                  action,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _inlineAiMetric({
    required IconData icon,
    required String label,
    required String value,
    required String suffix,
  }) {
    return Container(
      width: 158,
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9F8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF8F1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: _mcGreen, size: 17),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: _mcSub, fontSize: 9.4, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(
                    text: value,
                    style: TextStyle(color: _mcText, fontSize: 14, fontWeight: FontWeight.w600),
                    children: [
                      TextSpan(
                        text: '  $suffix',
                        style: TextStyle(color: _mcSub, fontSize: 8.6, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _inlineAiPanel({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9F8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: TextStyle(color: _mcText, fontSize: 12.2, fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          Text(subtitle, style: TextStyle(color: _mcSub, fontSize: 9.8, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _inlineAiEventsPanel({bool horizontal = false}) {
    final events = _liveAiEvents.take(horizontal ? 4 : 8).toList();
    return _inlineAiPanel(
      title: 'События ИИ',
      subtitle: 'Распознавание синхронизировано с видеоповтором',
      child: events.isEmpty
          ? _inlineAiWaiting(
              icon: Icons.timeline_rounded,
              text: 'Запустите видео — события появятся здесь по ходу анализа.',
            )
          : ListView.separated(
              scrollDirection: horizontal ? Axis.horizontal : Axis.vertical,
              physics: const BouncingScrollPhysics(),
              itemCount: events.length,
              separatorBuilder: (_, __) => SizedBox(
                width: horizontal ? 8 : 0,
                height: horizontal ? 0 : 7,
              ),
              itemBuilder: (context, index) {
                final event = events[index];
                final color = event['color'] is Color
                    ? event['color'] as Color
                    : _mcGreen;
                return Container(
                  width: horizontal ? 210 : double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: color.withOpacity(.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          event['icon'] is IconData
                              ? event['icon'] as IconData
                              : Icons.auto_awesome_rounded,
                          color: color,
                          size: 15,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _s(event['title']),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: _mcText, fontSize: 10.2, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_s(event['minute'])}${_s(event['subtitle']).isEmpty ? '' : ' · ${_s(event['subtitle'])}'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: _mcSub, fontSize: 8.8, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _inlineAiPitchPanel() {
    return _inlineAiPanel(
      title: 'Мини-карта',
      subtitle: 'Позиции, траектории и скорость игроков',
      child: _liveAiPositions.isEmpty
          ? _inlineAiWaiting(
              icon: Icons.map_outlined,
              text: 'Жду первые координаты игроков от ИИ.',
            )
          : CustomPaint(
              painter: _MatchPitchNetworkPainter(
                vertical: true,
                livePositions: _liveAiPositions,
                liveTrails: _liveAiTrails,
                liveSpeeds: _liveAiSpeedsKmh,
              ),
            ),
    );
  }

  Widget _inlineAiPlayersPanel() {
    final players = _liveAiPlayers.take(7).toList();
    return _inlineAiPanel(
      title: 'Игроки в кадре',
      subtitle: 'Track ID и уверенность распознавания',
      child: players.isEmpty
          ? _inlineAiWaiting(
              icon: Icons.groups_2_outlined,
              text: 'Игроки появятся после запуска видеоповтора.',
            )
          : ListView.separated(
              physics: const BouncingScrollPhysics(),
              itemCount: players.length,
              separatorBuilder: (_, __) => const SizedBox(height: 5),
              itemBuilder: (context, index) {
                final player = players[index];
                final trackId = player.trackId > 0
                    ? player.trackId
                    : int.tryParse(player.id) ?? index + 1;
                return Row(
                  children: [
                    Container(
                      width: 27,
                      height: 27,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF8F1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        player.number > 0 ? '${player.number}' : '$trackId',
                        style: TextStyle(color: _mcGreen, fontSize: 9.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _liveAiPlayerLabel(trackId, player: player),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: _mcText, fontSize: 10.2, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      '${(player.confidence * 100).round()}%',
                      style: TextStyle(color: _mcSub, fontSize: 9.2, fontWeight: FontWeight.w600),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _inlineAiWaiting({required IconData icon, required String text}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFF98A2B3), size: 24),
            const SizedBox(height: 7),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: _mcSub, fontSize: 9.8, height: 1.35, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiVideoAnalysisTabLegacy() {
    final video = _primaryAiVideo();
    final normalizedVideoUrl = video == null
        ? ''
        : (_normalizeUrl(_s(video['video_url'])) ?? '');
    final resolvedTeamId =
        teamId > 0 ? teamId : (widget.teamId ?? _i(match?['team_id']));
    final hasVideo = normalizedVideoUrl.isNotEmpty;

    Widget actionButton({
      required String label,
      required IconData icon,
      required VoidCallback? onPressed,
      bool primaryAction = false,
    }) {
      final shape = RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      );
      if (primaryAction) {
        return ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 18),
          label: Text(label),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            elevation: 0,
            backgroundColor: _mcGreen,
            foregroundColor: Colors.white,
            disabledBackgroundColor: _mcGreen.withOpacity(.45),
            shape: shape,
            textStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          foregroundColor: _mcText,
          side: BorderSide(color: _mcLine),
          shape: shape,
          textStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return ColoredBox(
      color: _mcBg,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          final title = resolvedTeamId <= 0
              ? 'Команда не определена'
              : hasVideo
                  ? 'Запись готова к AI-разбору'
                  : 'Добавьте видео матча';
          final description = resolvedTeamId <= 0
              ? 'Откройте матч из карточки команды, чтобы передать teamId.'
              : hasVideo
                  ? 'Запускайте анализ записи или переходите в режим онлайн-матча. Плеер, таймлайн и управление скоростью сохраняются.'
                  : 'После загрузки полной записи здесь появятся распознавание игроков и мяча, эпизоды и тактический разбор.';

          return SingleChildScrollView(
            padding: EdgeInsets.all(compact ? 10 : 14),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 980),
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _mcLine),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        height: 42,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: _mcPanelTop,
                          border: Border(bottom: BorderSide(color: _mcLine)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.psychology_alt_rounded,
                              color: _mcGreen,
                              size: 19,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'ВИДЕОАНАЛИЗ ИИ',
                                style: TextStyle(
                                  color: _mcText,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: .5,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: hasVideo
                                    ? const Color(0xFFE8F7EF)
                                    : const Color(0xFFF2F4F7),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                hasVideo ? 'ВИДЕО ГОТОВО' : 'НЕТ ВИДЕО',
                                style: TextStyle(
                                  color: hasVideo ? _mcGreen : _mcSub,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(compact ? 16 : 22),
                        child: Flex(
                          direction: compact ? Axis.vertical : Axis.horizontal,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 58,
                              height: 58,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F7EF),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                hasVideo
                                    ? Icons.analytics_outlined
                                    : Icons.video_file_outlined,
                                color: _mcGreen,
                                size: 29,
                              ),
                            ),
                            SizedBox(
                              width: compact ? 0 : 16,
                              height: compact ? 14 : 0,
                            ),
                            if (compact)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: TextStyle(
                                      color: _mcText,
                                      fontSize: compact ? 17 : 19,
                                      fontWeight: FontWeight.w600,
                                      height: 1.15,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    description,
                                    style: TextStyle(
                                      color: _mcSub,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      height: 1.42,
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  Wrap(
                                    spacing: 9,
                                    runSpacing: 9,
                                    children: [
                                      if (resolvedTeamId > 0 && hasVideo)
                                        actionButton(
                                          label: 'Анализ записи',
                                          icon: Icons.auto_awesome_motion_rounded,
                                          onPressed: () =>
                                              _openMatchVideoAnalysis(video!),
                                          primaryAction: true,
                                        ),
                                      if (resolvedTeamId > 0 && !hasVideo)
                                        actionButton(
                                          label: uploadingVideo
                                              ? 'Загрузка...'
                                              : 'Загрузить видео',
                                          icon: Icons.cloud_upload_outlined,
                                          onPressed: uploadingVideo
                                              ? null
                                              : () =>
                                                  _showUploadVideoSheet('full'),
                                          primaryAction: true,
                                        ),
                                      if (resolvedTeamId > 0)
                                        actionButton(
                                          label: 'Онлайн-матч',
                                          icon: Icons.sensors_rounded,
                                          onPressed: () =>
                                              _openMatchLive(video: video),
                                        ),
                                      actionButton(
                                        label: 'Раздел видео',
                                        icon: Icons.video_library_outlined,
                                        onPressed: () =>
                                            _openMatchDetailTab(4),
                                      ),
                                    ],
                                  ),
                                ],
                              )
                            else
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: TextStyle(
                                        color: _mcText,
                                        fontSize: 19,
                                        fontWeight: FontWeight.w600,
                                        height: 1.15,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      description,
                                      style: TextStyle(
                                        color: _mcSub,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                        height: 1.42,
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    Wrap(
                                      spacing: 9,
                                      runSpacing: 9,
                                      children: [
                                        if (resolvedTeamId > 0 && hasVideo)
                                          actionButton(
                                            label: 'Анализ записи',
                                            icon: Icons
                                                .auto_awesome_motion_rounded,
                                            onPressed: () =>
                                                _openMatchVideoAnalysis(video!),
                                            primaryAction: true,
                                          ),
                                        if (resolvedTeamId > 0 && !hasVideo)
                                          actionButton(
                                            label: uploadingVideo
                                                ? 'Загрузка...'
                                                : 'Загрузить видео',
                                            icon: Icons.cloud_upload_outlined,
                                            onPressed: uploadingVideo
                                                ? null
                                                : () => _showUploadVideoSheet(
                                                      'full',
                                                    ),
                                            primaryAction: true,
                                          ),
                                        if (resolvedTeamId > 0)
                                          actionButton(
                                            label: 'Онлайн-матч',
                                            icon: Icons.sensors_rounded,
                                            onPressed: () =>
                                                _openMatchLive(video: video),
                                          ),
                                        actionButton(
                                          label: 'Раздел видео',
                                          icon: Icons.video_library_outlined,
                                          onPressed: () =>
                                              _openMatchDetailTab(4),
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
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Professional white Match Center layout for tablets / desktop.
  // Uses the existing loaded match, players, TTD, episodes and video data.
  // ---------------------------------------------------------------------------

  Widget _buildProDesktopLayout({
    required String title,
    required String opponent,
    required String date,
    required String competition,
    required String score,
  }) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1560),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 232,
              child: _buildProSidebar(
                title: title,
                opponent: opponent,
                date: date,
                competition: competition,
                score: score,
              ),
            ),
            Expanded(
              child: AnimatedBuilder(
                animation: _tabController,
                builder: (context, _) {
                  final index = _safeMatchTabIndex(_tabController.index);
                  if (index != 0) {
                    return Container(
                      color: Colors.white,
                      child: _activeTabWidgetByIndex(index),
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _buildProOverviewMain(
                          title: title,
                          opponent: opponent,
                          date: date,
                          competition: competition,
                        ),
                      ),
                      SizedBox(
                        width: 356,
                        child: _buildProRightRail(),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProSidebar({
    required String title,
    required String opponent,
    required String date,
    required String competition,
    required String score,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 16, 0, 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFCFB),
        borderRadius: BorderRadius.circular(26),
        
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: softAccent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.sports_soccer_rounded, color: primary, size: 22),
                ),
                const SizedBox(height: 14),
                Text('Матч', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSecondary)),
                const SizedBox(height: 6),
                Text(
                  teamName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, height: 1.15, fontWeight: FontWeight.w600, color: textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  '$score  $opponent',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: primary),
                ),
                const SizedBox(height: 14),
                _proSideMeta(Icons.calendar_month_outlined, date.isEmpty ? 'Дата не указана' : date),
                _proSideMeta(Icons.stadium_outlined, _s(_stadiumCtrl.text).isEmpty ? 'Место не указано' : _s(_stadiumCtrl.text)),
                if (competition.isNotEmpty) _proSideMeta(Icons.emoji_events_outlined, competition),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: softAccent, borderRadius: BorderRadius.circular(999)),
                  child: Text('Завершен', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: primary)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: AnimatedBuilder(
              animation: _tabController,
              builder: (context, _) {
                return ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: _matchNavItems.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = _matchNavItems[index];
                    final active = _tabController.index == index;
                    return InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () {
                        _openMatchDetailTab(index);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: active ? softAccent : Colors.transparent,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: active ? Colors.white : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(item.icon, size: 19, color: active ? primary : textSecondary),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: active ? textPrimary : textPrimary.withOpacity(.86))),
                                  const SizedBox(height: 2),
                                  Text(item.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: active ? primary : textSecondary)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          _proOutlineButton(
            icon: Icons.download_rounded,
            text: 'Скачать отчёт',
            onTap: _exportPdfStub,
          ),
        ],
      ),
    );
  }

  Widget _buildProOverviewMain({
    required String title,
    required String opponent,
    required String date,
    required String competition,
  }) {
    return RefreshIndicator(
      color: primary,
      onRefresh: () async {
        await load();
        await _loadTtdReport();
      },
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(24, 16, 18, 28),
        children: [
          _buildProHero(
            title: title,
            opponent: opponent,
            date: date,
            competition: competition,
          ),
          const SizedBox(height: 18),
          _buildMatchKpiPanel(),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 880;
              if (narrow) {
                return Column(
                  children: [
                    _buildMatchIntelligenceCard(),
                    const SizedBox(height: 16),
                    _buildPhysicalLoadCard(),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 6, child: _buildMatchIntelligenceCard()),
                  const SizedBox(width: 16),
                  Expanded(flex: 5, child: _buildPhysicalLoadCard()),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 880;
              if (narrow) {
                return Column(
                  children: [
                    _buildTacticalMapsCard(),
                    const SizedBox(height: 16),
                    _buildMiniPitchCard(),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: _buildTacticalMapsCard()),
                  const SizedBox(width: 16),
                  Expanded(flex: 6, child: _buildMiniPitchCard()),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          _buildProVideoFragmentsCard(),
        ],
      ),
    );
  }

  Widget _buildProHero({
    required String title,
    required String opponent,
    required String date,
    required String competition,
  }) {
    final ourTeam = _s(match?["our_team"]).isEmpty ? teamName : _s(match?["our_team"]);
    final ourScore = _s(match?["our_score"]).isEmpty ? '0' : _s(match?["our_score"]);
    final oppScore = _s(match?["opponent_score"]).isEmpty ? '0' : _s(match?["opponent_score"]);
    final stadium = _s(_stadiumCtrl.text).isEmpty ? _s(match?["stadium"]) : _s(_stadiumCtrl.text);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 17, 18, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1F16),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.12),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(Icons.sports_soccer_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SPORTOTEKA MATCH CENTER',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(.64),
                        fontSize: 9.7,
                        fontWeight: FontWeight.w600,
                        letterSpacing: .55,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18.5,
                        height: 1.10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$ourScore:$oppScore',
                  style: TextStyle(
                    color: primary,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _darkHeroPill(Icons.shield_outlined, '$ourTeam — $opponent'),
              if (date.isNotEmpty) _darkHeroPill(Icons.calendar_month_outlined, date),
              if (stadium.isNotEmpty) _darkHeroPill(Icons.stadium_outlined, stadium),
              if (competition.isNotEmpty) _darkHeroPill(Icons.emoji_events_outlined, competition),
              _darkHeroPill(Icons.analytics_outlined, 'AI-отчёт и ТТД'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _darkHeroPill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: Colors.white.withOpacity(.82)),
          const SizedBox(width: 7),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 210),
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withOpacity(.86),
                fontSize: 10.6,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchKpiPanel() {
    final possession = _i(_ctrlValueOrMatch(_possessionCtrl, "possession"));
    final shots = _i(_ctrlValueOrMatch(_shotsCtrl, "shots"));
    final shotsOn = _i(_ctrlValueOrMatch(_shotsOnTargetCtrl, "shots_on_target"));
    final xg = _calculatedXg(shots, shotsOn);
    final fullVideos = _videosByType('full').length;
    final metrics = [
      _ProKpi('xG', xg.toStringAsFixed(2), Icons.stacked_line_chart_rounded, const Color(0xFF2E90FA), 'качество моментов'),
      _ProKpi('Владение', possession > 0 ? '$possession%' : '—', Icons.pie_chart_rounded, primary, 'контроль мяча'),
      _ProKpi('Удары', '$shots', Icons.sports_soccer_rounded, const Color(0xFF7C3AED), 'всего'),
      _ProKpi('В створ', '$shotsOn', Icons.center_focus_strong_rounded, const Color(0xFFF59E0B), 'точность'),
      _ProKpi('ТТД', '$_totalActions', Icons.query_stats_rounded, const Color(0xFF0EA5E9), 'действий'),
      _ProKpi('Эфф.', '${_efficiency.toStringAsFixed(0)}%', Icons.bolt_rounded, const Color(0xFF12B76A), 'успешность'),
      _ProKpi('Эпизоды', '${episodes.length}', Icons.movie_filter_outlined, const Color(0xFFEF4444), 'ключевые'),
      _ProKpi('Видео', '$fullVideos', Icons.play_circle_outline_rounded, const Color(0xFF175CD3), 'полная игра'),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;
        final columns = constraints.maxWidth >= 1180 ? 4 : constraints.maxWidth >= 760 ? 3 : 2;
        final itemWidth = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in metrics)
              SizedBox(
                width: itemWidth,
                child: _proKpiTile(item),
              ),
          ],
        );
      },
    );
  }

  Widget _proKpiTile(_ProKpi item) {
    return Container(
      height: 112,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Color.alphaBlend(item.color.withOpacity(.075), Colors.white),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(item.icon, color: item.color, size: 24),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.4, fontWeight: FontWeight.w600, color: textSecondary)),
                const SizedBox(height: 5),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(item.value, maxLines: 1, style: TextStyle(fontSize: 18.5, height: 1, fontWeight: FontWeight.w600, color: textPrimary)),
                ),
                const SizedBox(height: 5),
                Text(item.hint, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.2, fontWeight: FontWeight.w600, color: textSecondary.withOpacity(.86))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchIntelligenceCard() {
    final risk = _efficiency < 55 ? 'Высокий риск брака' : _efficiency < 70 ? 'Нужен контроль темпа' : 'Команда контролировала игру';
    final bestPeriod = episodes.isEmpty ? '55–72 мин' : _bestEpisodeWindow();
    final weakZone = _totalFail > _totalSuccess * .45 ? 'центральная зона и выход из обороны' : 'переходные фазы после потерь';

    return _proCard(
      title: 'Интеллект матча',
      trailing: _proTinyBadge('AI'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            risk,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 16.2, height: 1.12, fontWeight: FontWeight.w600, color: textPrimary),
          ),
          const SizedBox(height: 10),
          Text(
            'Система сопоставляет ТТД, эпизоды, владение и видео. Главная задача после матча — быстро понять сильные отрезки, провалы и нагрузку.',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11.4, height: 1.30, fontWeight: FontWeight.w600, color: textSecondary),
          ),
          const SizedBox(height: 16),
          _proInsightRow(Icons.trending_up_rounded, 'Лучший отрезок', bestPeriod, primary),
          _proInsightRow(Icons.warning_amber_rounded, 'Зона риска', weakZone, const Color(0xFFF59E0B)),
          _proInsightRow(Icons.psychology_alt_outlined, 'Рекомендация', _aiRecommendation(), const Color(0xFF2E90FA)),
          const SizedBox(height: 14),
          _proOutlineButton(icon: Icons.query_stats_rounded, text: 'Открыть расширенный ТТД', onTap: () => _openMatchDetailTab(1)),
        ],
      ),
    );
  }

  Widget _proInsightRow(IconData icon, String title, String value, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color.alphaBlend(color.withOpacity(.07), Colors.white),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(13)),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textSecondary)),
                const SizedBox(height: 3),
                Text(value, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, height: 1.2, fontWeight: FontWeight.w600, color: textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniPitchCard() {
    return _proCard(
      title: 'Карта поля',
      trailing: _proTinyBadge('вертикально'),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final fieldHeight = constraints.maxWidth >= 520
              ? 430.0
              : constraints.maxWidth >= 420
                  ? 400.0
                  : 360.0;

          return Column(
            children: [
              SizedBox(
                width: double.infinity,
                height: fieldHeight,
                child: CustomPaint(
                  painter: _SportotekaPitchPainter(primary: primary),
                  child: LayoutBuilder(
                    builder: (context, field) {
                      final w = field.maxWidth;
                      final h = field.maxHeight;

                      return Stack(
                        children: [
                          _pitchHotZone(
                            left: w * .12,
                            top: h * .16,
                            width: w * .50,
                            height: h * .13,
                            color: const Color(0xFF12B76A),
                            label: 'Прессинг',
                          ),
                          _pitchHotZone(
                            right: w * .10,
                            top: h * .45,
                            width: w * .42,
                            height: h * .12,
                            color: const Color(0xFFF59E0B),
                            label: 'Потери',
                          ),
                          _pitchHotZone(
                            left: w * .20,
                            bottom: h * .13,
                            width: w * .54,
                            height: h * .14,
                            color: const Color(0xFF2E90FA),
                            label: 'Атаки',
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _mapFilterChip('Владение', primary, true),
                  _mapFilterChip('Удары', const Color(0xFF2E90FA), false),
                  _mapFilterChip('Передачи', const Color(0xFF7C3AED), false),
                  _mapFilterChip('Потери', const Color(0xFFF59E0B), false),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _pitchHotZone({double? left, double? right, double? top, double? bottom, required double width, required double height, required Color color, required String label}) {
    return Positioned(
      left: left,
      right: right,
      top: top,
      bottom: bottom,
      child: Container(
        width: width,
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withOpacity(.16),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(label, style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _mapFilterChip(String text, Color color, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: active ? color : color.withOpacity(.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: active ? Colors.white : color)),
    );
  }

  Widget _buildTacticalMapsCard() {
    final maps = [
      _TacticalMapData('Средние позиции', 'структура команды', Icons.hub_outlined, primary),
      _TacticalMapData('Передачи', 'связи игроков', Icons.compare_arrows_rounded, const Color(0xFF2E90FA)),
      _TacticalMapData('Прессинг', 'давление по зонам', Icons.flash_on_rounded, const Color(0xFFF59E0B)),
      _TacticalMapData('Оборона', 'компактность линий', Icons.security_rounded, const Color(0xFF7C3AED)),
    ];

    return _proCard(
      title: 'Тактические карты',
      trailing: _proTinyBadge('PRO'),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 10.0;
              final columns = constraints.maxWidth < 560 ? 2 : 4;
              final itemWidth = (constraints.maxWidth - gap * (columns - 1)) / columns;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final item in maps) SizedBox(width: itemWidth, child: _tacticalMapTile(item)),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Container(
            height: 180,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: softSurface,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                Expanded(
                  child: CustomPaint(
                    painter: _TacticalLinesPainter(primary: primary),
                    child: const SizedBox.expand(),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Автоматическая схема', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: textPrimary)),
                      const SizedBox(height: 8),
                      Text('Здесь можно подключить координаты игроков из видеоаналитики и строить связи, средние позиции, зоны прессинга и тепловую карту.', maxLines: 5, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.2, height: 1.32, fontWeight: FontWeight.w600, color: textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tacticalMapTile(_TacticalMapData item) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _openMatchDetailTab(1),
      child: Container(
        height: 96,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Color.alphaBlend(item.color.withOpacity(.07), Colors.white),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(item.icon, size: 22, color: item.color),
            const Spacer(),
            Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.2, fontWeight: FontWeight.w600, color: textPrimary)),
            const SizedBox(height: 2),
            Text(item.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildPhysicalLoadCard() {
    final load = _loadScore();
    return _proCard(
      title: 'Физика и нагрузка',
      trailing: _proTinyBadge(load >= 80 ? 'высокая' : load >= 55 ? 'средняя' : 'низкая'),
      child: Column(
        children: [
          SizedBox(
            height: 116,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 104,
                  height: 104,
                  child: CircularProgressIndicator(
                    value: (load / 100).clamp(0.0, 1.0),
                    strokeWidth: 11,
                    color: _loadColor(load),
                    backgroundColor: const Color(0xFFE4EAF0),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${load.toStringAsFixed(0)}%', style: TextStyle(fontSize: 24, height: 1, fontWeight: FontWeight.w600, color: textPrimary)),
                    const SizedBox(height: 4),
                    Text('нагрузка', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textSecondary)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _loadRow('Пробег', _physicalValue(['distance', 'distance_km', 'total_distance'], fallback: '— км'), Icons.route_rounded, primary),
          _loadRow('Спринты', _physicalValue(['sprints', 'sprint_count'], fallback: '${max(0, (_totalActions / 12).round())}'), Icons.speed_rounded, const Color(0xFF2E90FA)),
          _loadRow('Ускорения', _physicalValue(['accelerations'], fallback: '${max(0, (_totalActions / 8).round())}'), Icons.trending_up_rounded, const Color(0xFF7C3AED)),
          _loadRow('Макс. скорость', _physicalValue(['max_speed', 'top_speed'], fallback: '— км/ч'), Icons.bolt_rounded, const Color(0xFFF59E0B)),
        ],
      ),
    );
  }

  Widget _loadRow(String label, String value, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Color.alphaBlend(color.withOpacity(.06), Colors.white),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSecondary))),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: textPrimary)),
        ],
      ),
    );
  }

  Widget _buildProStatsCard() {
    final stats = _matchStatsRows();
    return _proCard(
      title: 'Статистика матча',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text(teamName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSecondary))),
              const SizedBox(width: 10),
              Expanded(child: Text(_s(match?["opponent"]).isEmpty ? 'Соперник' : _s(match?["opponent"]), textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSecondary))),
            ],
          ),
          const SizedBox(height: 14),
          for (final row in stats) _proStatCompare(row[0].toString(), row[1] as int, row[2] as int),
          const SizedBox(height: 12),
          _proOutlineButton(icon: Icons.arrow_forward_rounded, text: 'Редактировать статистику', onTap: _openMatchInfoEditorSheet),
        ],
      ),
    );
  }

  Widget _buildProTimelineCard() {
    final timelineRows = _timelineRows();
    return _proCard(
      title: 'Хронология событий',
      child: Column(
        children: [
          if (timelineRows.isEmpty)
            _emptyState('Эпизоды и события пока не добавлены', icon: Icons.timeline_rounded)
          else
            for (final row in timelineRows.take(7)) row,
          if (timelineRows.length > 7) ...[
            const SizedBox(height: 8),
            _proOutlineButton(icon: Icons.arrow_forward_rounded, text: 'Все события', onTap: () => _openMatchDetailTab(2)),
          ],
        ],
      ),
    );
  }

  Widget _buildProVideoFragmentsCard() {
    final videos = [..._videosByType('highlight'), ..._videosByType('moment'), ..._videosByType('full')].take(4).toList();
    return _proCard(
      title: 'Видеоаналитика',
      trailing: InkWell(
        onTap: () => _openMatchDetailTab(3),
        child: Text('Все фрагменты  ›', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: primary)),
      ),
      child: videos.isEmpty
          ? _emptyState('Видео пока не загружено', icon: Icons.video_collection_outlined)
          : LayoutBuilder(
              builder: (context, constraints) {
                const gap = 12.0;
                final columns = constraints.maxWidth < 640 ? 1 : constraints.maxWidth < 980 ? 2 : 4;
                final itemWidth = columns == 1
                    ? constraints.maxWidth
                    : (constraints.maxWidth - gap * (columns - 1)) / columns;

                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final video in videos) SizedBox(width: itemWidth, child: _proVideoThumb(video)),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildProRightRail() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 16, 24, 28),
      children: [
        _buildAiCoachStickyCard(),
        const SizedBox(height: 16),
        _buildProMvpCard(),
        const SizedBox(height: 16),
        _buildPhysicalLoadCard(),
        const SizedBox(height: 16),
        _buildProCoachNoteCard(),
      ],
    );
  }

  Widget _buildAiCoachStickyCard() {
    return _proCard(
      title: 'AI-блок справа',
      trailing: _proTinyBadge('coach'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Тренерский вывод',
            style: AppTypography.sectionTitle(color: textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            _aiCoachText(),
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.secondaryMedium(color: textSecondary),
          ),
          const SizedBox(height: 14),
          _proAiPoint('Эффективность: ${_efficiency.toStringAsFixed(1)}%'),
          _proAiPoint('Лучший игрок: ${_bestPlayerName()}'),
          _proAiPoint('Ключевые эпизоды: ${episodes.length}'),
          const SizedBox(height: 12),
          _proOutlineButton(icon: Icons.psychology_alt_outlined, text: 'Разобрать матч', onTap: () => _openMatchDetailTab(1)),
        ],
      ),
    );
  }

  Widget _buildProMvpCard() {
    final row = _bestPlayerRow();
    final name = row == null ? 'Игрок не выбран' : _playerName(row);
    final photo = row == null ? null : _playerPhotoUrl(row);
    final rating = _playerRating(row);
    final keyStats = _playerKeyTtdStats(row, maxItems: 4);
    return _proCard(
      title: 'Игрок матча',
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 116,
                height: 134,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(color: softAccent, borderRadius: BorderRadius.circular(22)),
                child: photo == null
                    ? Icon(Icons.person_rounded, size: 74, color: primary)
                    : Image.network(photo, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(Icons.person_rounded, size: 74, color: primary)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textPrimary))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(12)),
                          child: Text(rating, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    for (final stat in keyStats)
                      _proMiniPlayerStat(stat[0], stat[1]),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _proOutlineButton(icon: Icons.arrow_forward_rounded, text: 'Профиль игрока', onTap: row == null ? null : () => _openMatchDetailTab(1)),
        ],
      ),
    );
  }

  Widget _buildProAiCard() => _buildMatchIntelligenceCard();

  Widget _buildProCoachNoteCard() {
    return _proCard(
      title: 'Заметки тренера',
      child: Column(
        children: [
          TextField(
            controller: _coachCommentCtrl,
            minLines: 4,
            maxLines: 5,
            style: AppTypography.commentText(color: textPrimary),
            decoration: InputDecoration(
              hintText: 'Добавьте заметку о матче...',
              hintStyle: AppTypography.formHint(color: textSecondary.withOpacity(.75)),
              filled: true,
              fillColor: softSurface,
              border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.circular(18)),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
          const SizedBox(height: 12),
          _proOutlineButton(icon: Icons.save_rounded, text: saving ? 'Сохранение...' : 'Сохранить заметку', onTap: saving ? null : _saveAll),
        ],
      ),
    );
  }

  Widget _proTinyBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: softAccent, borderRadius: BorderRadius.circular(999)),
      child: Text(text.toUpperCase(), style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: primary)),
    );
  }

  Widget _proCard({required String title, required Widget child, Widget? trailing}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, color: textPrimary))), if (trailing != null) trailing]),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  double _calculatedXg(int shots, int shotsOnTarget) {
    if (_d(match?['xg']) > 0) return _d(match?['xg']);
    return (shots * 0.07) + (shotsOnTarget * 0.16);
  }

  String _bestEpisodeWindow() {
    final minutes = episodes
        .map((e) => _i(e['minute'] ?? e['time_minute'] ?? e['match_minute']))
        .where((m) => m > 0)
        .toList()
      ..sort();
    if (minutes.isEmpty) return '55–72 мин';
    final median = minutes[minutes.length ~/ 2];
    return '${max(1, median - 8)}–${min(90, median + 8)} мин';
  }

  String _aiRecommendation() {
    if (_totalActions == 0) return 'добавить ТТД и видео, чтобы Sportoteka построила точный отчёт';
    if (_efficiency < 55) return 'снизить риск при первом пасе и усилить поддержку под мяч';
    if (_efficiency < 70) return 'улучшить качество решений в центральной зоне';
    return 'сохранить модель игры и разобрать лучшие эпизоды с командой';
  }

  String _aiCoachText() {
    if (_totalActions == 0) return 'Матч готов к разбору. После добавления ТТД и видео система покажет слабые зоны, сильные отрезки и персональные рекомендации игрокам.';
    if (_efficiency < 55) return 'Команда часто теряла мяч и не успевала закрепиться после перехода в атаку. Нужны упражнения на выход из-под давления и короткие связи.';
    if (_efficiency < 70) return 'Матч был рабочим по интенсивности, но есть просадки в качестве решений. Рекомендуется разобрать эпизоды потерь и второй темп атаки.';
    return 'Команда контролировала значительную часть матча. Следующий шаг — закрепить удачные игровые связи и показать игрокам лучшие эпизоды.';
  }

  double _loadScore() {
    final fromMatch = _d(match?['load_score'] ?? match?['physical_load']);
    if (fromMatch > 0) return fromMatch.clamp(0, 100).toDouble();
    return min(100, max(22, _totalActions * .42 + episodes.length * 3 + _i(_shotsCtrl.text) * 1.4)).toDouble();
  }

  Color _loadColor(double load) {
    if (load >= 80) return const Color(0xFFEF4444);
    if (load >= 55) return const Color(0xFFF59E0B);
    return primary;
  }

  String _physicalValue(List<String> keys, {required String fallback}) {
    for (final key in keys) {
      final value = _s(match?[key]);
      if (value.isNotEmpty && value != '0') return value;
    }
    return fallback;
  }

  Widget _proQuickTile({required IconData icon, required String title, required String value, required String subtitle, required Color color, required int tabIndex}) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => _openMatchDetailTab(tabIndex),
      child: Container(
        height: 108,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Color.alphaBlend(color.withOpacity(.075), Colors.white),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)), child: Icon(icon, color: color, size: 24)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: textPrimary)),
                  const SizedBox(height: 5),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(value, maxLines: 1, style: TextStyle(fontSize: value.length > 12 ? 14 : 20, height: 1, fontWeight: FontWeight.w600, color: textPrimary)),
                  ),
                  const SizedBox(height: 5),
                  Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _proStatCompare(String label, int left, int right) {
    final total = max(1, left + right);
    final value = (left / total).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Row(
        children: [
          SizedBox(width: 46, child: Text('$left', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary))),
          Expanded(
            child: Column(
              children: [
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSecondary)),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(value: value, minHeight: 5, color: primary, backgroundColor: const Color(0xFFE4EAF0)),
                ),
              ],
            ),
          ),
          SizedBox(width: 46, child: Text('$right', textAlign: TextAlign.right, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary))),
        ],
      ),
    );
  }

  Widget _proTimelineEvent({required String minute, required IconData icon, required String title, required String player, required String subtitle, required String score, required Color color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 42, child: Text(minute, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSecondary))),
          Container(width: 30, height: 30, decoration: BoxDecoration(color: color.withOpacity(.12), shape: BoxShape.circle), child: Icon(icon, size: 17, color: color)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
                Text(player, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary)),
                if (subtitle.isNotEmpty) Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSecondary)),
              ],
            ),
          ),
          if (score.isNotEmpty) Flexible(child: Text(score, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary))),
        ],
      ),
    );
  }

  Widget _proVideoThumb(Map<String, dynamic> video) {
    final title = _formatVideoTitle(_s(video['file_name']), 'Видео момента');
    final thumb = _normalizeUrl(_s(video['thumbnail_url']).isEmpty ? _s(video['thumbnail']) : _s(video['thumbnail_url']));
    final url = _s(video['video_url']);
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: url.isEmpty ? null : () => _watchVideo(url, title: title),
      child: Container(
        height: 142,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: softSurface, borderRadius: BorderRadius.circular(18)),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (thumb != null) Image.network(thumb, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
            Container(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withOpacity(.55)]))),
            Center(child: Icon(Icons.play_circle_fill_rounded, color: Colors.white.withOpacity(.92), size: 44)),
            Positioned(left: 12, right: 12, bottom: 10, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)), Text(_videoMeta(video), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withOpacity(.78), fontSize: 11, fontWeight: FontWeight.w600))])),
          ],
        ),
      ),
    );
  }

  Widget _proOutlineButton({required IconData icon, required String text, VoidCallback? onTap}) {
    return SizedBox(
      width: double.infinity,
      height: 42,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 17),
        label: FittedBox(fit: BoxFit.scaleDown, child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis)),
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: BorderSide.none,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _proHeroTeam({required String title, required String label, required IconData icon, required Color color, bool alignRight = false}) {
    return Row(
      mainAxisAlignment: alignRight ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        if (!alignRight) _proShield(icon, color),
        if (!alignRight) const SizedBox(width: 14),
        Flexible(
          child: Column(
            crossAxisAlignment: alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: alignRight ? TextAlign.right : TextAlign.left, style: TextStyle(fontSize: 17.5, height: 1.12, fontWeight: FontWeight.w600, color: textPrimary)),
              const SizedBox(height: 8),
              Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5), decoration: BoxDecoration(color: color.withOpacity(.10), borderRadius: BorderRadius.circular(8)), child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: color))),
            ],
          ),
        ),
        if (alignRight) const SizedBox(width: 14),
        if (alignRight) _proShield(icon, color),
      ],
    );
  }

  Widget _proShield(IconData icon, Color color) {
    return Container(width: 58, height: 58, decoration: BoxDecoration(color: color.withOpacity(.09), borderRadius: BorderRadius.circular(20)), child: Icon(icon, color: color, size: 32));
  }

  Widget _proHeroMeta(IconData icon, String text) => Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 16, color: textSecondary), const SizedBox(width: 7), ConstrainedBox(constraints: const BoxConstraints(maxWidth: 220), child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: textSecondary)))]);

  Widget _proSideMeta(IconData icon, String text) => Padding(padding: const EdgeInsets.only(bottom: 9), child: Row(children: [Icon(icon, size: 16, color: textSecondary), const SizedBox(width: 8), Expanded(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSecondary)))]));

  Widget _proMiniPlayerStat(String label, String value) => Padding(padding: const EdgeInsets.only(bottom: 7), child: Row(children: [Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSecondary))), const SizedBox(width: 8), Flexible(child: Text(value.isEmpty || value == '0' ? '—' : value, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary)))]));

  Widget _proAiPoint(String text) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.check_circle_rounded, color: primary, size: 17), const SizedBox(width: 8), Expanded(child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, height: 1.25, fontWeight: FontWeight.w600, color: textSecondary)))]));

  List<Map<String, dynamic>> _videosByType(String type) {
    return ((match?["videos"] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .where((e) => _s(e["video_type"]) == type)
        .toList();
  }

  List<List<dynamic>> _matchStatsRows() {
    int field(String key, TextEditingController ctrl) {
      final fromCtrl = _i(ctrl.text);
      if (fromCtrl != 0) return fromCtrl;
      return _i(match?[key]);
    }

    final possession = field('possession', _possessionCtrl);
    final oppPossession = possession > 0 ? max(0, 100 - possession) : 0;
    return [
      ['Владение мячом', possession, oppPossession],
      ['Удары', field('shots', _shotsCtrl), _i(match?['opponent_shots'] ?? match?['opp_shots'])],
      ['Удары в створ', field('shots_on_target', _shotsOnTargetCtrl), _i(match?['opponent_shots_on_target'] ?? match?['opp_shots_on_target'])],
      ['Угловые', field('corners', _cornersCtrl), _i(match?['opponent_corners'] ?? match?['opp_corners'])],
      ['Офсайды', field('offsides', _offsidesCtrl), _i(match?['opponent_offsides'] ?? match?['opp_offsides'])],
      ['Жёлтые карточки', field('yellow_cards', _yellowCtrl), _i(match?['opponent_yellow_cards'] ?? match?['opp_yellow_cards'])],
      ['Красные карточки', field('red_cards', _redCtrl), _i(match?['opponent_red_cards'] ?? match?['opp_red_cards'])],
      ['ТТД успешно', _totalSuccess, _totalFail],
    ];
  }

  List<Widget> _timelineRows() {
    final rows = <Widget>[];
    final all = <Map<String, dynamic>>[];
    all.addAll(episodes);
    all.sort((a, b) => _i(a['minute'] ?? a['time_minute'] ?? a['match_minute']).compareTo(_i(b['minute'] ?? b['time_minute'] ?? b['match_minute'])));

    for (final e in all) {
      final type = _s(e['type'] ?? e['event_type'] ?? e['episode_type']);
      final title = _timelineTitle(type, e);
      final minuteRaw = _s(e['minute'] ?? e['time_minute'] ?? e['match_minute']);
      final minute = minuteRaw.isEmpty ? '—' : "$minuteRaw’";
      final player = _s(e['player_name'] ?? e['author_name'] ?? e['name']).isEmpty ? _s(e['title']).isEmpty ? 'Эпизод матча' : _s(e['title']) : _s(e['player_name'] ?? e['author_name'] ?? e['name']);
      final subtitle = _s(e['description'] ?? e['comment'] ?? e['note']);
      rows.add(_proTimelineEvent(minute: minute, icon: _timelineIcon(type), title: title, player: player, subtitle: subtitle, score: _s(e['score']), color: _timelineColor(type)));
    }
    return rows;
  }

  String _timelineTitle(String type, Map<String, dynamic> e) {
    final explicit = _s(e['event_title'] ?? e['title']);
    if (explicit.isNotEmpty && explicit.length < 30) return explicit;
    final t = type.toLowerCase();
    if (t.contains('goal') || t.contains('гол')) return 'ГОЛ';
    if (t.contains('yellow') || t.contains('жел')) return 'Жёлтая карточка';
    if (t.contains('red') || t.contains('крас')) return 'Красная карточка';
    if (t.contains('shot') || t.contains('удар')) return 'Удар';
    return 'Эпизод';
  }

  IconData _timelineIcon(String type) {
    final t = type.toLowerCase();
    if (t.contains('goal') || t.contains('гол')) return Icons.sports_soccer_rounded;
    if (t.contains('yellow') || t.contains('жел')) return Icons.crop_square_rounded;
    if (t.contains('red') || t.contains('крас')) return Icons.crop_square_rounded;
    return Icons.movie_filter_outlined;
  }

  Color _timelineColor(String type) {
    final t = type.toLowerCase();
    if (t.contains('goal') || t.contains('гол')) return primary;
    if (t.contains('yellow') || t.contains('жел')) return const Color(0xFFF59E0B);
    if (t.contains('red') || t.contains('крас')) return const Color(0xFFEF4444);
    return const Color(0xFF2E90FA);
  }

  List<Map<String, dynamic>> _mvpCandidateRows() {
    final byKey = <String, Map<String, dynamic>>{};

    void addRows(List<Map<String, dynamic>> rows) {
      for (final source in rows) {
        final key = _mainTtdPlayerKey(source);
        final name = _playerName(source).trim().toLowerCase();
        if (key == 'name:игрок' && name == 'игрок' && _playerTotalTtdActions(source) <= 0) {
          continue;
        }

        final existing = byKey[key];
        if (existing == null) {
          byKey[key] = Map<String, dynamic>.from(source);
        } else {
          _mergePlayerTtdRow(existing, source);
        }
      }
    }

    // Собираем одну карточку игрока из всех отчётов ТТД: общий видео-итог,
    // основные ТТД, передачи и вратарские действия. Поэтому «Игрок матча»
    // больше не зависит от заглушек и не теряет статистику из соседних отчётов.
    addRows(ttdPlayers);
    addRows(playerVideoTotals);
    addRows(mainReport);
    addRows(passReport);
    addRows(goalkeeperReport);

    final rows = byKey.values
        .where((row) => _playerTotalTtdActions(row) > 0 || _playerGoalCount(row) > 0 || _playerAssistCount(row) > 0)
        .toList();

    rows.sort((a, b) => _playerMvpScore(b).compareTo(_playerMvpScore(a)));
    return rows;
  }

  void _mergePlayerTtdRow(Map<String, dynamic> target, Map<String, dynamic> source) {
    source.forEach((key, value) {
      final current = target[key];

      if (value is Map) {
        final nextMap = Map<String, dynamic>.from(value);
        if (current is Map) {
          final merged = Map<String, dynamic>.from(current);
          nextMap.forEach((nestedKey, nestedValue) {
            final oldValue = merged[nestedKey];
            final oldNumber = _numericValue(oldValue);
            final newNumber = _numericValue(nestedValue);
            if (oldValue == null || _s(oldValue).isEmpty) {
              merged[nestedKey] = nestedValue;
            } else if (oldNumber > 0 || newNumber > 0) {
              merged[nestedKey] = oldNumber + newNumber;
            }
          });
          target[key] = merged;
        } else {
          target[key] = nextMap;
        }
        return;
      }

      if (current == null || _s(current).isEmpty || _s(current) == '0') {
        target[key] = value;
        return;
      }

      // Для числовых ТТД складываем значения из разных отчётов только по тем
      // полям, где действительно может прийти распределение действий.
      final canSum = const {
        'success_count',
        'fail_count',
        'total_count',
        'ttd_total',
        'total_ttd',
        'actions_total',
        'feint_dribble',
        'shot_on_goal',
        'tackle_duel',
        'interception',
        'recovery',
        'header_play',
        'throw_ins',
        'pass_avp',
        'saves',
        'conceded',
        'hand_distribution',
        'coming_out',
        'close_combat',
        'interceptions',
        'interceptions_gk',
        'outside_box',
        'pass_short',
        'pass_medium',
        'pass_long',
        'gk_pass_short',
        'gk_pass_medium',
        'gk_pass_long',
      }.contains(key);

      if (canSum) {
        final oldNumber = _numericValue(current);
        final newNumber = _numericValue(value);
        if (oldNumber > 0 || newNumber > 0) {
          target[key] = oldNumber + newNumber;
        }
      }
    });
  }

  int _sumTtdBucket(dynamic raw) {
    if (raw == null) return 0;
    if (raw is Map) {
      var total = 0;
      for (final value in raw.values) {
        total += _sumTtdBucket(value);
      }
      return total;
    }
    if (raw is List) {
      var total = 0;
      for (final item in raw) {
        total += _sumTtdBucket(item);
      }
      return total;
    }
    return _numericValue(raw);
  }

  int _playerSuccessActions(Map<String, dynamic> row) {
    final direct = _numericValue(
      row['success_count'] ??
          row['success_total'] ??
          row['successful'] ??
          row['success_actions'] ??
          row['successes'],
    );
    if (direct > 0) return direct;
    return _sumTtdBucket(row['success']);
  }

  int _playerFailActions(Map<String, dynamic> row) {
    final direct = _numericValue(
      row['fail_count'] ??
          row['fail_total'] ??
          row['failed'] ??
          row['fail_actions'] ??
          row['mistakes'] ??
          row['errors'],
    );
    if (direct > 0) return direct;
    return _sumTtdBucket(row['fail']);
  }

  int _playerTotalTtdActions(Map<String, dynamic> row) {
    final direct = _numericValue(
      row['total_count'] ??
          row['ttd_total'] ??
          row['total_ttd'] ??
          row['actions_total'] ??
          row['actions_count'] ??
          row['total'],
    );
    final successFailTotal = _playerSuccessActions(row) + _playerFailActions(row);
    final mainTotal = _mainTtdTotal(row);
    final gkTotal = _goalkeeperTotal(row);
    return [direct, successFailTotal, mainTotal, gkTotal].reduce(max);
  }

  double _playerEffectPercent(Map<String, dynamic> row) {
    var direct = _d(
      row['effect_percent'] ??
          row['efficiency_percent'] ??
          row['success_percent'] ??
          row['accuracy_percent'] ??
          row['effect'] ??
          row['efficiency'],
    );
    if (direct > 0 && direct <= 1) direct *= 100;
    if (direct > 0) return direct.clamp(0, 100).toDouble();

    final success = _playerSuccessActions(row);
    final fail = _playerFailActions(row);
    final total = success + fail;
    if (total <= 0) return 0;
    return ((success / total) * 100).clamp(0, 100).toDouble();
  }

  bool _sameEpisodePlayer(Map<String, dynamic> row, Map<String, dynamic> episode) {
    final rowId = _playerId(row);
    final episodeId = _s(
      episode['player_id'] ??
          episode['athlete_id'] ??
          episode['student_id'] ??
          episode['user_id'] ??
          episode['author_id'],
    );
    if (rowId.isNotEmpty && episodeId.isNotEmpty && rowId == episodeId) return true;

    final rowName = _playerName(row).trim().toLowerCase();
    if (rowName.isEmpty || rowName == 'игрок') return false;

    final episodeName = _s(
      episode['player_name'] ??
          episode['full_name'] ??
          episode['name'] ??
          episode['author_name'] ??
          episode['title'],
    ).toLowerCase();

    return episodeName.isNotEmpty &&
        (episodeName == rowName || episodeName.contains(rowName) || rowName.contains(episodeName));
  }

  int _playerEpisodeCount(Map<String, dynamic> row, List<String> markers) {
    var count = 0;
    for (final episode in episodes) {
      if (!_sameEpisodePlayer(row, episode)) continue;
      final text = [
        episode['type'],
        episode['event_type'],
        episode['episode_type'],
        episode['event_title'],
        episode['title'],
        episode['action'],
        episode['action_title'],
        episode['ttd_title'],
        episode['description'],
        episode['comment'],
      ].map(_s).join(' ').toLowerCase();
      if (markers.any(text.contains)) count++;
    }
    return count;
  }

  int _playerGoalCount(Map<String, dynamic> row) {
    final direct = _numericValue(row['goals'] ?? row['goal'] ?? row['goals_count']);
    if (direct > 0) return direct;
    return _playerEpisodeCount(row, const ['goal', 'гол']);
  }

  int _playerAssistCount(Map<String, dynamic> row) {
    final direct = _numericValue(row['assists'] ?? row['assist'] ?? row['goal_assists']);
    if (direct > 0) return direct;
    return _playerEpisodeCount(row, const ['assist', 'ассист', 'голевая', 'голевой', 'результативная']);
  }

  int _playerSharpPasses(Map<String, dynamic> row) => _mainTtdValue(row, 'pass_avp');
  int _playerShots(Map<String, dynamic> row) => _mainTtdValue(row, 'shot_on_goal');
  int _playerDribbles(Map<String, dynamic> row) => _mainTtdValue(row, 'feint_dribble');
  int _playerTackles(Map<String, dynamic> row) => _mainTtdValue(row, 'tackle_duel');
  int _playerInterceptions(Map<String, dynamic> row) =>
      max(_mainTtdValue(row, 'interception'), _numericValue(row['interceptions'] ?? row['interceptions_gk']));
  int _playerRecoveries(Map<String, dynamic> row) => _mainTtdValue(row, 'recovery');
  int _playerHeaders(Map<String, dynamic> row) => _mainTtdValue(row, 'header_play');
  int _playerSaves(Map<String, dynamic> row) => _numericValue(row['saves']);
  int _playerConceded(Map<String, dynamic> row) => _numericValue(row['conceded']);

  double _playerMvpScore(Map<String, dynamic> row) {
    final success = _playerSuccessActions(row);
    final fail = _playerFailActions(row);
    final total = _playerTotalTtdActions(row);
    final effect = _playerEffectPercent(row);

    return success * 1.0 -
        fail * .55 +
        total * .18 +
        effect * .28 +
        _playerGoalCount(row) * 12 +
        _playerAssistCount(row) * 7 +
        _playerShots(row) * 2 +
        _playerSharpPasses(row) * 1.6 +
        _playerDribbles(row) * .9 +
        _playerTackles(row) * 1.0 +
        _playerInterceptions(row) * .9 +
        _playerRecoveries(row) * .55 +
        _playerHeaders(row) * .35 +
        _playerSaves(row) * 1.1 -
        _playerConceded(row) * 3;
  }

  Map<String, dynamic>? _bestPlayerRow() {
    final candidates = _mvpCandidateRows();
    if (candidates.isEmpty) return null;
    return candidates.first;
  }

  String _bestPlayerName() {
    final row = _bestPlayerRow();
    if (row == null) return '—';
    return _playerName(row);
  }

  String _playerRating(Map<String, dynamic>? row) {
    if (row == null) return '—';
    final total = _playerTotalTtdActions(row);
    if (total <= 0) return '—';

    final effect = _playerEffectPercent(row);
    final fail = _playerFailActions(row);
    final rating = 5.8 +
        min(1.25, total / 80) +
        ((effect - 50) / 28) +
        _playerGoalCount(row) * .55 +
        _playerAssistCount(row) * .35 +
        _playerSharpPasses(row) * .08 +
        _playerShots(row) * .06 +
        _playerSaves(row) * .06 -
        fail * .012;

    return rating.clamp(5.0, 10.0).toStringAsFixed(1);
  }

  List<List<String>> _playerKeyTtdStats(Map<String, dynamic>? row, {int maxItems = 6}) {
    if (row == null) {
      return const [
        ['ТТД', 'нет данных'],
        ['Подсказка', 'загрузите отчёт'],
      ];
    }

    final success = _playerSuccessActions(row);
    final fail = _playerFailActions(row);
    final total = _playerTotalTtdActions(row);
    final effect = _playerEffectPercent(row);
    final goals = _playerGoalCount(row);
    final assists = _playerAssistCount(row);
    final shots = _playerShots(row);
    final sharpPasses = _playerSharpPasses(row);
    final dribbles = _playerDribbles(row);
    final tackles = _playerTackles(row);
    final interceptions = _playerInterceptions(row);
    final recoveries = _playerRecoveries(row);
    final saves = _playerSaves(row);

    final stats = <List<String>>[
      ['Всего ТТД', total > 0 ? '$total' : '—'],
      ['Эффективность', effect > 0 ? '${effect.toStringAsFixed(0)}%' : '—'],
      ['Успешно / брак', (success + fail) > 0 ? '$success / $fail' : '—'],
    ];

    void addIfPositive(String label, int value, {String suffix = ''}) {
      if (value > 0) stats.add([label, '$value$suffix']);
    }

    addIfPositive('Голы', goals);
    addIfPositive('Голевые передачи', assists);
    addIfPositive('Удары по воротам', shots);
    addIfPositive('Острые пасы', sharpPasses);
    addIfPositive('Обводки', dribbles);
    addIfPositive('Отборы', tackles);
    addIfPositive('Перехваты', interceptions);
    addIfPositive('Подборы', recoveries);
    addIfPositive('Сейвы', saves);

    return stats.take(maxItems).toList();
  }

  Widget _buildCmrTopBar({
    required bool compact,
    required String title,
    required String opponent,
    required String date,
    required String competition,
    bool showBackButton = true,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 18,
        vertical: compact ? 10 : 14,
      ),
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            if (showBackButton) ...[
              Container(
                width: compact ? 40 : 44,
                height: compact ? 40 : 44,
                decoration: BoxDecoration(
                  color: softAccent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => Get.back(),
                  icon: Icon(
                    Icons.arrow_back_rounded,
                    color: primary,
                    size: compact ? 21 : 23,
                  ),
                  tooltip: "Назад",
                ),
              ),
              const SizedBox(width: 12),
            ] else ...[
              Container(
                width: compact ? 40 : 44,
                height: compact ? 40 : 44,
                decoration: BoxDecoration(
                  color: softAccent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.analytics_outlined, color: primary, size: compact ? 21 : 23),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: AnimatedBuilder(
                animation: _tabController,
                builder: (context, _) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        compact ? _currentTabTitle : title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: compact ? 16 : 18,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        compact
                            ? "$teamName • $opponent"
                            : [
                                teamName,
                                if (opponent.isNotEmpty) "соперник: $opponent",
                                if (date.isNotEmpty) date,
                                if (competition.isNotEmpty) competition,
                              ].join(" • "),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: compact ? 11 : 12,
                          fontWeight: FontWeight.w600,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            if (!compact)
              _CmrToolbarButton(
                label: "PDF",
                icon: Icons.picture_as_pdf_outlined,
                onTap: _exportPdfStub,
                primary: primary,
              ),
            if (!compact) const SizedBox(width: 8),
            _CmrToolbarButton(
              label: compact ? "" : (saving ? "Сохранение" : "Сохранить"),
              icon: saving ? Icons.hourglass_top_rounded : Icons.save_rounded,
              onTap: saving ? null : _saveAll,
              primary: primary,
              filled: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCmrSidebar({
    required String title,
    required String opponent,
    required String date,
    required String score,
  }) {
    const railWidth = 156.0;
    final safeTitle = title.trim().isEmpty ? 'Матч' : title.trim();
    final safeOpponent = opponent.trim().isEmpty ? 'Соперник' : opponent.trim();

    return Container(
      width: railWidth,
      color: Colors.transparent,
      padding: const EdgeInsets.fromLTRB(9, 12, 8, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F5F8),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFF0F2F4), width: 1),
                ),
                child: const Icon(Icons.sports_soccer_rounded, color: Color(0xFF6B7280), size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      safeTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF0B0F14),
                        fontSize: 12.0,
                        height: 1.05,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -.18,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      safeOpponent,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF6B7280),
                        fontSize: 9.6,
                        height: 1.1,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -.05,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: AnimatedBuilder(
              animation: _tabController,
              builder: (context, _) {
                return ListView.separated(
                  padding: EdgeInsets.zero,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _matchNavItems.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final item = _matchNavItems[index];
                    final active = _safeMatchTabIndex(_tabController.index) == index;
                    return _MatchSidebarButton(
                      item: item,
                      active: active,
                      primary: const Color(0xFF28A86B),
                      onTap: () => _openMatchDetailTab(index),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          _buildMatchSidebarFooterAction(
            icon: Icons.refresh_rounded,
            label: 'Обновить',
            onTap: () { _init(); },
          ),
          const SizedBox(height: 6),
          _buildMatchSidebarFooterAction(
            icon: Icons.more_horiz_rounded,
            label: 'Действия',
            onTap: _showCurrentMatchActions,
          ),
          const SizedBox(height: 6),
          _buildMatchSidebarFooterAction(
            icon: Icons.edit_rounded,
            label: 'Редактировать',
            onTap: _openMatchInfoEditorSheet,
          ),
        ],
      ),
    );
  }

  Widget _buildMatchSidebarFooterAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xFFF6F7F9),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              Icon(icon, color: const Color(0xFF6B7280), size: 17),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF344054),
                    fontSize: 10.8,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -.12,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _mobileMatchBottomIndex() {
    return _tabController.index.clamp(0, _matchNavItems.length - 1);
  }

  void _handleMatchBottomTap(int index) {
    if (_tabController.index == index) {
      if (mounted) setState(() {});
      return;
    }

    // На мобильной версии переключаем раздел сразу, без ожидания анимации TabBarView.
    _openMatchDetailTab(index);
  }

  Widget _buildMatchMobileBottomMenu(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: AnimatedBuilder(
          animation: _tabController,
          builder: (context, _) {
            final activeIndex = _mobileMatchBottomIndex();
            final items = [
              (0, Icons.dashboard_customize_rounded, 'Обзор'),
              (1, Icons.query_stats_rounded, 'ТТД'),
              (2, Icons.movie_filter_outlined, 'Эпизоды'),
              (3, Icons.video_library_outlined, 'Нарезка'),
              (4, Icons.play_circle_outline_rounded, 'Видео'),
              (5, Icons.psychology_alt_rounded, 'ИИ'),
              (6, Icons.folder_copy_outlined, 'Док.'),
            ];

            return Row(
              children: items.map((item) {
                final active = activeIndex == item.$1;
                return Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => _handleMatchBottomTap(item.$1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      decoration: BoxDecoration(
                        color: active ? softAccent : Colors.transparent,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(item.$2, size: 21, color: active ? primary : textSecondary),
                          const SizedBox(height: 3),
                          Text(
                            item.$3,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.8,
                              fontWeight: FontWeight.w600,
                              color: active ? primary : textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ),
    );
  }

  void _openMatchMobileMoreMenu() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final moreIndexes = [3, 4];
        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),

            ),
            child: AnimatedBuilder(
              animation: _tabController,
              builder: (context, _) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD7E8DE),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Дополнительно',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    for (final navIndex in moreIndexes) ...[
                      _MatchMobileMoreItem(
                        item: _matchNavItems[navIndex],
                        active: _tabController.index == navIndex,
                        primary: primary,
                        textPrimary: textPrimary,
                        textSecondary: textSecondary,
                        onTap: () {
                          Navigator.of(ctx).pop();
                          _openMatchDetailTab(navIndex);
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileMenuSheet() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: AnimatedBuilder(
          animation: _tabController,
          builder: (context, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD7E8DE),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Меню матча",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Get.back(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _matchNavItems.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = _matchNavItems[index];
                      final active = _tabController.index == index;
                      return _MatchSidebarButton(
                        item: item,
                        active: active,
                        primary: primary,
                        onTap: () {
                          Get.back();
                          _openMatchDetailTab(index);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCmrCompactNav() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: softSurface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Expanded(
            child: AnimatedBuilder(
              animation: _tabController,
              builder: (context, _) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(_matchNavItems.length, (index) {
                      final item = _matchNavItems[index];
                      final active = _tabController.index == index;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () {
                            _openMatchDetailTab(index);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                            decoration: BoxDecoration(
                              color: active ? softAccent : Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Icon(item.icon, size: 18, color: active ? primary : textSecondary),
                                const SizedBox(width: 6),
                                Text(
                                  item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: active ? primary : textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            borderRadius: BorderRadius.circular(15),
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => _buildMobileMenuSheet(),
              );
            },
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: softAccent,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(Icons.menu_rounded, color: primary),
            ),
          ),
        ],
      ),
    );
  }


  // ---------------------------------------------------------------------------
  // Light professional match analytics workspace (Catapult-like composition).
  // Existing tabs stay the same: Обзор / Основные ТТД / Эпизоды / Нарезка / Видео.
  // ---------------------------------------------------------------------------

  Color get _mcBg => const Color(0xFFF6F7F6);
  Color get _mcRail => Colors.white;
  Color get _mcHeader => Colors.white;
  Color get _mcPanel => const Color(0xFFFFFFFF);
  Color get _mcPanelTop => const Color(0xFFF8F9FA);
  Color get _mcLine => const Color(0xFFE5E7EB);
  Color get _mcText => const Color(0xFF111827);
  Color get _mcSub => const Color(0xFF475467);
  Color get _mcGreen => const Color(0xFF00A750);
  Color get _mcBlue => const Color(0xFF00A750);
  Color get _mcRed => const Color(0xFFD64545);
  Color get _mcYellow => const Color(0xFFD99A00);
  Color get _mcControl => const Color(0xFF111827);
  Color get _mcControlLine => const Color(0xFF263244);
  Color get _mcOnDark => const Color(0xFFFFFFFF);
  Color get _mcOnDarkSub => const Color(0xFFCBD5E1);
  Color get _mcPlayerBar => Colors.white;
  Color get _mcPlayerLine => const Color(0xFFE5EAE7);
  Color get _mcPlayerText => const Color(0xFF111827);
  Color get _mcPlayerSub => const Color(0xFF667085);
  Color get _cmrMatchGreen => const Color(0xFF00A750);
  Color get _cmrMatchGreenSoft => const Color(0xFFEAF7F0);
  Color get _cmrMatchSurface => const Color(0xFFF7F9F8);
  Color get _cmrMatchMuted => const Color(0xFF667085);
  Color get _cmrMatchInk => const Color(0xFF111827);

  Widget _buildMatchAnalysisWorkspace({
    required String title,
    required String opponent,
    required String date,
    required String competition,
    required String score,
  }) {
    return Container(
      color: _mcBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildMatchWorkspaceContentHeader(
            title: title,
            opponent: opponent,
            date: date,
            competition: competition,
            score: score,
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compactRail = constraints.maxWidth < 860;
                final railWidth = compactRail
                    ? 56.0
                    : constraints.maxWidth < 1180
                        ? 206.0
                        : 232.0;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: railWidth,
                      child: _buildTrackerMatchSideNav(compact: compactRail),
                    ),
                    Expanded(
                      child: AnimatedBuilder(
                        animation: _tabController,
                        builder: (context, _) {
                          final index =
                              _safeMatchTabIndex(_tabController.index);
                          final content = index == 0
                              ? _matchAnalysisOverview(
                                  title: title,
                                  opponent: opponent,
                                  date: date,
                                  competition: competition,
                                  score: score,
                                )
                              : _activeTabWidgetByIndex(index);

                          return ColoredBox(
                            color: Colors.white,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 160),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeOutCubic,
                              child: KeyedSubtree(
                                key: ValueKey(
                                  'match-detail-tracker-tab-$index',
                                ),
                                child: content,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          _matchAnalysisVideoBottomTimeline(),
        ],
      ),
    );
  }

  Widget _buildTrackerMatchSideNav({required bool compact}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(
            color: _mcLine.withOpacity(.72),
            width: .8,
          ),
        ),
      ),
      child: AnimatedBuilder(
        animation: _tabController,
        builder: (context, _) {
          final activeIndex = _safeMatchTabIndex(_tabController.index);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!compact)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 13, 12, 7),
                  child: Row(
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          color: Color(0xFF00A750),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        'РАЗБОР МАТЧА',
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          color: const Color(0xFF98A2B3),
                          fontSize: 9.6,
                          fontWeight: FontWeight.w600,
                          letterSpacing: .35,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                    compact ? 7 : 9,
                    compact ? 9 : 5,
                    compact ? 7 : 9,
                    12,
                  ),
                  itemCount: _matchNavItems.length,
                  itemBuilder: (context, index) {
                    final item = _matchNavItems[index];
                    final active = activeIndex == index;
                    final label = item.title == 'Основные ТТД'
                        ? 'Основные ТТД'
                        : item.title == 'Видеоанализ ИИ'
                            ? 'ИИ-анализ'
                            : item.title;

                    final tile = Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                      child: InkWell(
                        onTap: () => _openMatchDetailTab(index),
                        borderRadius: BorderRadius.circular(9),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          curve: Curves.easeOutCubic,
                          height: compact ? 40 : 42,
                          padding: EdgeInsets.fromLTRB(
                            compact ? 0 : 7,
                            0,
                            compact ? 0 : 9,
                            0,
                          ),
                          decoration: BoxDecoration(
                            color: active
                                ? const Color(0xFFF1F7F3)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Row(
                            mainAxisAlignment: compact
                                ? MainAxisAlignment.center
                                : MainAxisAlignment.start,
                            children: [
                              if (!compact) ...[
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  width: 3,
                                  height: active ? 22 : 12,
                                  decoration: BoxDecoration(
                                    color: active
                                        ? const Color(0xFF00A750)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                ),
                                const SizedBox(width: 9),
                              ],
                              Icon(
                                item.icon,
                                size: 17,
                                color: active
                                    ? const Color(0xFF087A3A)
                                    : const Color(0xFF667085),
                              ),
                              if (!compact) ...[
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontFamily:
                                              AppTypography.fontFamily,
                                          color: active
                                              ? const Color(0xFF111827)
                                              : const Color(0xFF344054),
                                          fontSize: 12.1,
                                          fontWeight: FontWeight.w600,
                                          height: 1.05,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        item.subtitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontFamily:
                                              AppTypography.fontFamily,
                                          color: const Color(0xFF98A2B3),
                                          fontSize: 9.8,
                                          fontWeight: FontWeight.w400,
                                          height: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (index == 5)
                                  Container(
                                    width: 6,
                                    height: 6,
                                    margin: const EdgeInsets.only(left: 5),
                                    decoration: BoxDecoration(
                                      color: _liveAiPlayers.isNotEmpty
                                          ? const Color(0xFF00A750)
                                          : const Color(0xFFCBD5E1),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: compact
                          ? Tooltip(
                              message: label,
                              waitDuration:
                                  const Duration(milliseconds: 220),
                              child: tile,
                            )
                          : tile,
                    );
                  },
                ),
              ),
              if (!compact)
                Padding(
                  padding: const EdgeInsets.fromLTRB(13, 8, 13, 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F9F8),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.sports_soccer_rounded,
                          size: 14,
                          color: Color(0xFF00A750),
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            _currentTabTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              color: const Color(0xFF667085),
                              fontSize: 10.3,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTrackerStyleMatchTabs() {
    return Container(
      height: 54,
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: AnimatedBuilder(
        animation: _tabController,
        builder: (context, _) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            child: Row(
              children: List.generate(_matchNavItems.length, (index) {
                final item = _matchNavItems[index];
                final active = _safeMatchTabIndex(_tabController.index) == index;
                var label = item.title;
                if (label == 'Основные ТТД') label = 'ТТД';
                if (label == 'Видеоанализ ИИ') label = 'ИИ-анализ';

                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    onTap: () => _openMatchDetailTab(index),
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 13),
                      decoration: BoxDecoration(
                        color: active ? const Color(0xFFEAF8F1) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            item.icon,
                            size: 17,
                            color: active ? _mcGreen : _mcSub,
                          ),
                          const SizedBox(width: 7),
                          Text(
                            label,
                            style: TextStyle(
                              color: active ? _mcGreen : _mcText,
                              fontSize: 11.5,
                              fontWeight: active ? FontWeight.w600 : FontWeight.w600,
                            ),
                          ),
                          if (index == 5) ...[
                            const SizedBox(width: 7),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: _liveAiPlayers.isNotEmpty
                                    ? _mcGreen
                                    : const Color(0xFF98A2B3),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMatchWorkspaceContentHeader({
    required String title,
    required String opponent,
    required String date,
    required String competition,
    required String score,
  }) {
    final safeTitle = title.trim().isEmpty ? 'Матч' : title.trim();
    final safeOpponent = opponent.trim().isEmpty ? 'Соперник' : opponent.trim();

    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: Colors.white,
      child: Row(
        children: [
          if (!widget.embedded) ...[
            _analysisTopIcon(Icons.arrow_back_rounded, onTap: () => Get.back()),
            const SizedBox(width: 8),
            Container(width: 1, height: 24, color: _mcLine),
            const SizedBox(width: 10),
          ],
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF3FBF7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.sports_soccer_rounded, color: Color(0xFF00A750), size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  safeTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF0B0F14),
                    fontSize: 12.4,
                    fontWeight: FontWeight.w600,
                    height: 1.05,
                    letterSpacing: -.18,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    teamName,
                    safeOpponent,
                    if (date.trim().isNotEmpty) date.trim(),
                    if (competition.trim().isNotEmpty) competition.trim(),
                  ].where((e) => e.trim().isNotEmpty).join(' • '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 9.8,
                    fontWeight: FontWeight.w600,
                    height: 1.05,
                    letterSpacing: -.05,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            height: 28,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF3FBF7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              score,
              style: const TextStyle(
                color: Color(0xFF00A750),
                fontSize: 10.8,
                fontWeight: FontWeight.w600,
                height: 1,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _analysisTopIcon(Icons.more_horiz_rounded, onTap: _showCurrentMatchActions),
          const SizedBox(width: 8),
          _analysisTopIcon(Icons.tune_rounded, onTap: _openMatchInfoEditorSheet),
          const SizedBox(width: 8),
          _analysisTopIcon(Icons.save_rounded, onTap: saving ? null : _saveAll),
        ],
      ),
    );
  }

  Widget _matchWindowChrome({
    required String title,
    required String opponent,
    required String date,
    required String competition,
    required String score,
  }) {
    final safeTitle = title.trim().isEmpty ? 'Матч' : title.trim();
    final safeOpponent = opponent.trim().isEmpty ? 'Соперник' : opponent.trim();

    return SafeArea(
      bottom: false,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 7),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 860;
            return Row(
              children: [
                if (!widget.embedded) ...[
                  InkWell(
                    onTap: () => Get.back(),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _cmrMatchSurface,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.arrow_back_rounded, color: _cmrMatchInk, size: 21),
                    ),
                  ),
                  const SizedBox(width: 10),
                ] else ...[
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F9F8),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(Icons.drag_indicator_rounded, color: Color(0xFF667085), size: 16),
                  ),
                  const SizedBox(width: 10),
                ],
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _cmrMatchGreenSoft,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(Icons.sports_soccer_rounded, color: _cmrMatchGreen, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              safeTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _cmrMatchInk,
                                fontSize: compact ? 13.2 : 14.4,
                                height: 1.08,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: _cmrMatchGreenSoft,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              score,
                              style: TextStyle(
                                color: _cmrMatchGreen,
                                fontSize: 10.8,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          teamName,
                          safeOpponent,
                          if (date.trim().isNotEmpty) date.trim(),
                          if (!compact && competition.trim().isNotEmpty) competition.trim(),
                        ].join(' • '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _cmrMatchMuted,
                          fontSize: 10.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                if (!compact) ...[
                  _analysisTopButton('Экспорт', Icons.file_download_outlined, _exportPdfStub, false),
                  const SizedBox(width: 8),
                  _analysisTopButton(saving ? 'Сохраняем' : 'Сохранить', saving ? Icons.hourglass_top_rounded : Icons.save_rounded, saving ? null : _saveAll, true),
                  const SizedBox(width: 8),
                ],
                _analysisTopIcon(Icons.tune_rounded, onTap: _openMatchInfoEditorSheet),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _matchAnalysisTopTabs() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          return Row(
            children: [
              Expanded(
                child: AnimatedBuilder(
                  animation: _tabController,
                  builder: (context, _) {
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: List.generate(_matchNavItems.length, (index) {
                          final item = _matchNavItems[index];
                          final active = _safeMatchTabIndex(_tabController.index) == index;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: InkWell(
                              onTap: () => _openMatchDetailTab(index),
                              borderRadius: BorderRadius.circular(18),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                curve: Curves.easeOutCubic,
                                height: 40,
                                padding: EdgeInsets.only(
                                  left: active ? 13 : 12,
                                  right: compact ? 13 : 16,
                                ),
                                decoration: BoxDecoration(
                                  color: active ? _cmrMatchGreenSoft : _cmrMatchSurface,
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: active
                                      ? [
                                          BoxShadow(
                                            color: _cmrMatchGreen.withOpacity(.10),
                                            blurRadius: 18,
                                            offset: const Offset(0, 8),
                                          ),
                                        ]
                                      : const [],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    AnimatedContainer(
                                      duration: const Duration(milliseconds: 180),
                                      width: 4,
                                      height: active ? 22 : 0,
                                      decoration: BoxDecoration(
                                        color: _cmrMatchGreen,
                                        borderRadius: BorderRadius.circular(99),
                                      ),
                                    ),
                                    if (active) const SizedBox(width: 9),
                                    Icon(
                                      item.icon,
                                      size: 16,
                                      color: active ? _cmrMatchGreen : _cmrMatchMuted,
                                    ),
                                    const SizedBox(width: 7),
                                    Text(
                                      compact && index == 5 ? 'ИИ' : item.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: active ? _cmrMatchInk : _cmrMatchMuted,
                                        fontSize: 11.2,
                                        fontWeight: active ? FontWeight.w600 : FontWeight.w600,
                                      ),
                                    ),
                                    if (active) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: _cmrMatchGreen,
                                          borderRadius: BorderRadius.circular(99),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    );
                  },
                ),
              ),
              if (!compact) ...[
                const SizedBox(width: 10),
                Text(
                  _currentTabTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _cmrMatchMuted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }



  Widget _analysisTopIcon(IconData icon, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: _cmrMatchSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _mcLine),
        ),
        child: Icon(icon, color: _cmrMatchInk, size: 18),
      ),
    );
  }


  Widget _analysisTopButton(String label, IconData icon, VoidCallback? onTap, bool filled) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: filled ? _cmrMatchGreen : _cmrMatchSurface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: filled
              ? [
                  BoxShadow(
                    color: _cmrMatchGreen.withOpacity(.12),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : const [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: filled ? Colors.white : _cmrMatchInk, size: 17),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: filled ? Colors.white : _cmrMatchInk,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _matchAnalysisRail({
    required String title,
    required String opponent,
    required String score,
  }) {
    final safeTitle = title.trim().isEmpty ? 'Матч' : title.trim();
    final safeOpponent = opponent.trim().isEmpty ? 'Соперник' : opponent.trim();

    return Container(
      width: 72,
      margin: const EdgeInsets.all(8),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _MatchRailColors.rail,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _MatchRailColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Tooltip(
            message: safeTitle,
            waitDuration: const Duration(milliseconds: 250),
            preferBelow: false,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _openMatchDetailTab(0),
              child: AnimatedBuilder(
                animation: _tabController,
                builder: (context, _) {
                  final active = _safeMatchTabIndex(_tabController.index) == 0;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 56,
                    height: 50,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: active ? _MatchRailColors.active : _MatchRailColors.railPanel,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: active ? _MatchRailColors.active : _MatchRailColors.border),
                      boxShadow: active
                          ? [
                              BoxShadow(
                                color: Colors.black.withOpacity(.035),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : const [],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (active)
                          Positioned(
                            left: 0,
                            top: 8,
                            bottom: 8,
                            child: Container(
                              width: 3,
                              decoration: BoxDecoration(
                                color: _MatchRailColors.primaryGreen,
                                borderRadius: BorderRadius.circular(99),
                              ),
                            ),
                          ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.sports_soccer_rounded,
                              color: active ? _MatchRailColors.activeText : _MatchRailColors.railText,
                              size: 18,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Обзор',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: active ? _MatchRailColors.activeText : _MatchRailColors.railMuted,
                                fontSize: 8,
                                height: .95,
                                letterSpacing: -.25,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 6),
          _MatchRailUtilityButton(
            icon: Icons.scoreboard_rounded,
            label: score,
            tooltip: '$teamName — $safeOpponent · $score',
            active: false,
            onTap: () => _openMatchDetailTab(0),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: AnimatedBuilder(
              animation: _tabController,
              builder: (context, _) {
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  physics: const BouncingScrollPhysics(),
                  itemCount: max(0, _matchNavItems.length - 1),
                  separatorBuilder: (_, __) => const SizedBox(height: 5),
                  itemBuilder: (context, index) {
                    final navIndex = index + 1;
                    final item = _matchNavItems[navIndex];
                    final active = _safeMatchTabIndex(_tabController.index) == navIndex;

                    return _MatchRailButton(
                      item: item,
                      active: active,
                      onTap: () => _openMatchDetailTab(navIndex),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              children: [
                _MatchRailUtilityButton(
                  icon: Icons.home_rounded,
                  label: 'Матч',
                  tooltip: 'К обзору матча',
                  active: false,
                  onTap: () => _openMatchDetailTab(0),
                ),
                const SizedBox(height: 6),
                _MatchRailUtilityButton(
                  icon: Icons.tune_rounded,
                  label: 'Настр.',
                  tooltip: 'Настройки матча',
                  active: false,
                  onTap: _openMatchInfoEditorSheet,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _matchAnalysisOverview({
    required String title,
    required String opponent,
    required String date,
    required String competition,
    required String score,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;

        // Важно: не ждём огромной ширины 1260–1580 внутри workspace.
        // Экран уже забирает левый rail и боковые панели, поэтому сетка должна
        // становиться 3/4/5-колоночной намного раньше.
        final isPhoneWidth = viewportWidth < 620;
        final isTabletWidth = viewportWidth >= 620 && viewportWidth < 1120;
        final isDesktopWidth = viewportWidth >= 1120;
        final isUltraWide = viewportWidth >= 1440;

        final gap = isPhoneWidth ? 8.0 : 8.0;
        final pagePadding = isPhoneWidth
            ? const EdgeInsets.all(8)
            : const EdgeInsets.fromLTRB(8, 8, 8, 8);

        final headerHeight = isPhoneWidth ? 160.0 : 146.0;
        final compactCards = !isDesktopWidth;

        Widget fullWidthPanel({
          required double height,
          required Widget child,
        }) {
          return SizedBox(
            width: double.infinity,
            height: height,
            child: child,
          );
        }

        Widget card({
          required double height,
          required String title,
          String? subtitle,
          Widget? trailing,
          required Widget child,
        }) {
          return SizedBox(
            height: height,
            child: _analysisPanel(
              title: title,
              subtitle: subtitle,
              trailing: trailing,
              child: child,
            ),
          );
        }

        Widget flexCard({
          required int flex,
          required double height,
          required String title,
          String? subtitle,
          Widget? trailing,
          required Widget child,
        }) {
          return Expanded(
            flex: flex,
            child: card(
              height: height,
              title: title,
              subtitle: subtitle,
              trailing: trailing,
              child: child,
            ),
          );
        }

        Widget analyticsRow(List<Widget> children) {
          final items = <Widget>[];
          for (int i = 0; i < children.length; i++) {
            if (i > 0) items.add(SizedBox(width: gap));
            items.add(children[i]);
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: items,
          );
        }

        Widget rowGap() => SizedBox(height: gap);

        List<Widget> desktopRows() {
          if (isUltraWide) {
            final topHeight = 246.0;
            final lowerHeight = 318.0;
            return [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 7,
                    child: Column(
                      children: [
                        analyticsRow([
                          flexCard(
                            flex: 3,
                            height: topHeight,
                            title: 'Игроки в матче',
                            subtitle: 'Выбор игрока и быстрые ТТД',
                            child: _analysisMatchPlayersPane(),
                          ),
                          flexCard(
                            flex: 2,
                            height: topHeight,
                            title: 'Видеоаналитика',
                            subtitle: 'Тактический AI-ракурс',
                            child: _analysisVideoPane(tactical: true),
                          ),
                        ]),
                        rowGap(),
                        analyticsRow([
                          flexCard(
                            flex: 1,
                            height: lowerHeight,
                            title: 'Скорость: игроки (км/ч)',
                            subtitle: 'Макс. скорость',
                            child: _analysisSpeedBars(),
                          ),
                          flexCard(
                            flex: 1,
                            height: lowerHeight,
                            title: 'Ускорения (м/с²)',
                            subtitle: 'Распределение',
                            child: const CustomPaint(painter: _MatchHistogramPainter()),
                          ),
                        ]),
                      ],
                    ),
                  ),
                  SizedBox(width: gap),
                  Expanded(
                    flex: 3,
                    child: card(
                      height: topHeight + gap + lowerHeight,
                      title: 'Мини-карта поля',
                      subtitle: 'Вертикально: позиции и передачи',
                      trailing: _analysisDropDown(teamName),
                      child: CustomPaint(
                        painter: _MatchPitchNetworkPainter(
                          vertical: true,
                          livePositions: _liveAiPositions,
                          liveTrails: _liveAiTrails,
                          liveSpeeds: _liveAiSpeedsKmh,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              rowGap(),
              analyticsRow([
                flexCard(
                  flex: 1,
                  height: 300,
                  title: 'Интеллект матча',
                  subtitle: 'AI анализ',
                  child: _analysisAiBlock(compact: true),
                ),
                flexCard(
                  flex: 1,
                  height: 300,
                  title: 'Статистика матча',
                  child: _analysisStatsTable(compact: true),
                ),
                flexCard(
                  flex: 1,
                  height: 300,
                  title: 'Интенсивность спринтов',
                  subtitle: 'По 15-минутным отрезкам',
                  child: _analysisLiveSprintBars(),
                ),
              ]),
              rowGap(),
              analyticsRow([
                flexCard(
                  flex: 2,
                  height: 250,
                  title: 'Нагрузка игроков (IMA)',
                  subtitle: 'Импакт по отрезкам',
                  child: _analysisLiveLoadBars(),
                ),
                flexCard(
                  flex: 3,
                  height: 250,
                  title: 'Хронология событий',
                  trailing: _analysisDropDown('Все события'),
                  child: _analysisEventTimeline(wide: true),
                ),
                flexCard(
                  flex: 2,
                  height: 250,
                  title: 'Игрок матча',
                  child: _analysisMvpBlock(),
                ),
              ]),
              rowGap(),
              analyticsRow([
                flexCard(
                  flex: 1,
                  height: 248,
                  title: 'Заметки тренера',
                  child: _analysisCoachNotes(),
                ),
                flexCard(
                  flex: 1,
                  height: 248,
                  title: 'Связки и взаимодействия',
                  subtitle: 'Топ-3 связки (передачи)',
                  trailing: _analysisDropDown(teamName),
                  child: _analysisConnections(),
                ),
              ]),
            ];
          }

          final topHeight = 242.0;
          final lowerHeight = 304.0;
          return [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      analyticsRow([
                        flexCard(
                          flex: 1,
                          height: topHeight,
                          title: 'Игроки в матче',
                          subtitle: 'Выбор игрока и быстрые ТТД',
                          child: _analysisMatchPlayersPane(),
                        ),
                        flexCard(
                          flex: 1,
                          height: topHeight,
                          title: 'Видеоаналитика',
                          subtitle: 'Тактический AI-ракурс',
                          child: _analysisVideoPane(tactical: true),
                        ),
                      ]),
                      rowGap(),
                      analyticsRow([
                        flexCard(
                          flex: 1,
                          height: lowerHeight,
                          title: 'Скорость: игроки (км/ч)',
                          subtitle: 'Макс. скорость',
                          child: _analysisSpeedBars(),
                        ),
                        flexCard(
                          flex: 1,
                          height: lowerHeight,
                          title: 'Ускорения (м/с²)',
                          subtitle: 'Распределение',
                          child: const CustomPaint(painter: _MatchHistogramPainter()),
                        ),
                      ]),
                    ],
                  ),
                ),
                SizedBox(width: gap),
                Expanded(
                  flex: 1,
                  child: card(
                    height: topHeight + gap + lowerHeight,
                    title: 'Мини-карта поля',
                    subtitle: 'Вертикально: позиции и передачи',
                    trailing: _analysisDropDown(teamName),
                    child: CustomPaint(
                      painter: _MatchPitchNetworkPainter(
                        vertical: true,
                        livePositions: _liveAiPositions,
                        liveTrails: _liveAiTrails,
                        liveSpeeds: _liveAiSpeedsKmh,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            rowGap(),
            analyticsRow([
              flexCard(
                flex: 1,
                height: 256,
                title: 'Интеллект матча',
                subtitle: 'AI анализ',
                child: _analysisAiBlock(compact: true),
              ),
              flexCard(
                flex: 1,
                height: 256,
                title: 'Статистика матча',
                child: _analysisStatsTable(compact: true),
              ),
              flexCard(
                flex: 1,
                height: 256,
                title: 'Интенсивность спринтов',
                subtitle: 'По 15-минутным отрезкам',
                child: _analysisLiveSprintBars(),
              ),
            ]),
            rowGap(),
            analyticsRow([
              flexCard(
                flex: 1,
                height: 248,
                title: 'Нагрузка игроков (IMA)',
                subtitle: 'Импакт по отрезкам',
                child: _analysisLiveLoadBars(),
              ),
              flexCard(
                flex: 2,
                height: 248,
                title: 'Хронология событий',
                trailing: _analysisDropDown('Все события'),
                child: _analysisEventTimeline(wide: true),
              ),
            ]),
            rowGap(),
            analyticsRow([
              flexCard(
                flex: 1,
                height: 246,
                title: 'Игрок матча',
                child: _analysisMvpBlock(),
              ),
              flexCard(
                flex: 1,
                height: 246,
                title: 'Заметки тренера',
                child: _analysisCoachNotes(),
              ),
              flexCard(
                flex: 1,
                height: 246,
                title: 'Связки и взаимодействия',
                subtitle: 'Топ-3 связки (передачи)',
                trailing: _analysisDropDown(teamName),
                child: _analysisConnections(),
              ),
            ]),
          ];
        }

        List<Widget> tabletRows() {
          final topHeight = 236.0;
          final lowerHeight = 286.0;
          return [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      analyticsRow([
                        flexCard(
                          flex: 1,
                          height: topHeight,
                          title: 'Игроки в матче',
                          subtitle: 'Выбор игрока и быстрые ТТД',
                          child: _analysisMatchPlayersPane(),
                        ),
                        flexCard(
                          flex: 1,
                          height: topHeight,
                          title: 'Видеоаналитика',
                          subtitle: 'Тактический AI-ракурс',
                          child: _analysisVideoPane(tactical: true),
                        ),
                      ]),
                      rowGap(),
                      analyticsRow([
                        flexCard(
                          flex: 1,
                          height: lowerHeight,
                          title: 'Скорость',
                          subtitle: 'Игроки, км/ч',
                          child: _analysisSpeedBars(),
                        ),
                        flexCard(
                          flex: 1,
                          height: lowerHeight,
                          title: 'Ускорения',
                          subtitle: 'Распределение',
                          child: const CustomPaint(painter: _MatchHistogramPainter()),
                        ),
                      ]),
                    ],
                  ),
                ),
                SizedBox(width: gap),
                Expanded(
                  flex: 1,
                  child: card(
                    height: topHeight + gap + lowerHeight,
                    title: 'Мини-карта поля',
                    subtitle: 'Вертикально: позиции и передачи',
                    trailing: _analysisDropDown(teamName),
                    child: CustomPaint(
                      painter: _MatchPitchNetworkPainter(
                        vertical: true,
                        livePositions: _liveAiPositions,
                        liveTrails: _liveAiTrails,
                        liveSpeeds: _liveAiSpeedsKmh,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            rowGap(),
            analyticsRow([
              flexCard(
                flex: 1,
                height: 248,
                title: 'Спринты',
                subtitle: '15-минутные отрезки',
                child: _analysisLiveSprintBars(),
              ),
              flexCard(
                flex: 1,
                height: 248,
                title: 'Нагрузка',
                subtitle: 'IMA',
                child: _analysisLiveLoadBars(),
              ),
              flexCard(
                flex: 1,
                height: 248,
                title: 'Игрок матча',
                child: _analysisMvpBlock(),
              ),
            ]),
            rowGap(),
            analyticsRow([
              flexCard(
                flex: 1,
                height: 260,
                title: 'Интеллект матча',
                subtitle: 'AI анализ',
                child: _analysisAiBlock(compact: true),
              ),
              flexCard(
                flex: 1,
                height: 260,
                title: 'Статистика матча',
                child: _analysisStatsTable(compact: true),
              ),
            ]),
            rowGap(),
            analyticsRow([
              flexCard(
                flex: 2,
                height: 246,
                title: 'Хронология событий',
                trailing: _analysisDropDown('Все события'),
                child: _analysisEventTimeline(wide: true),
              ),
              flexCard(
                flex: 1,
                height: 246,
                title: 'Заметки тренера',
                child: _analysisCoachNotes(),
              ),
            ]),
            rowGap(),
            fullWidthPanel(
              height: 244,
              child: card(
                height: 244,
                title: 'Связки и взаимодействия',
                subtitle: 'Топ-3 связки (передачи)',
                trailing: _analysisDropDown(teamName),
                child: _analysisConnections(),
              ),
            ),
          ];
        }

        List<Widget> phoneRows() {
          final tiles = <Widget>[
            card(
              height: 260,
              title: 'Игроки в матче',
              subtitle: 'Выбор игрока и быстрые ТТД',
              child: _analysisMatchPlayersPane(),
            ),
            card(
              height: 260,
              title: 'Видеоаналитика',
              subtitle: 'Тактический AI-ракурс',
              child: _analysisVideoPane(tactical: true),
            ),
            card(
              height: 238,
              title: 'Скорость: игроки (км/ч)',
              subtitle: 'Макс. скорость',
              child: _analysisSpeedBars(),
            ),
            card(
              height: 280,
              title: 'Мини-карта поля',
              subtitle: 'Позиции и передачи',
              trailing: _analysisDropDown(teamName),
              child: CustomPaint(
                painter: _MatchPitchNetworkPainter(
                  livePositions: _liveAiPositions,
                  liveTrails: _liveAiTrails,
                  liveSpeeds: _liveAiSpeedsKmh,
                ),
              ),
            ),
            card(
              height: 238,
              title: 'Ускорения (м/с²)',
              subtitle: 'Распределение',
              child: const CustomPaint(painter: _MatchHistogramPainter()),
            ),
            card(
              height: 238,
              title: 'Интенсивность спринтов',
              subtitle: 'По 15-минутным отрезкам',
              child: _analysisLiveSprintBars(),
            ),
            card(
              height: 238,
              title: 'Нагрузка игроков (IMA)',
              subtitle: 'Импакт по отрезкам',
              child: _analysisLiveLoadBars(),
            ),
            card(
              height: 238,
              title: 'Интеллект матча',
              subtitle: 'AI анализ',
              child: _analysisAiBlock(compact: compactCards),
            ),
            card(
              height: 238,
              title: 'Статистика матча',
              child: _analysisStatsTable(compact: true),
            ),
            card(
              height: 244,
              title: 'Хронология событий',
              trailing: _analysisDropDown('Все события'),
              child: _analysisEventTimeline(wide: false),
            ),
            card(
              height: 244,
              title: 'Игрок матча',
              child: _analysisMvpBlock(),
            ),
            card(
              height: 244,
              title: 'Заметки тренера',
              child: _analysisCoachNotes(),
            ),
            card(
              height: 244,
              title: 'Связки и взаимодействия',
              subtitle: 'Топ-3 связки (передачи)',
              trailing: _analysisDropDown(teamName),
              child: _analysisConnections(),
            ),
          ];

          return [
            for (int i = 0; i < tiles.length; i++) ...[
              if (i > 0) rowGap(),
              tiles[i],
            ],
          ];
        }

        final rows = isPhoneWidth
            ? phoneRows()
            : isTabletWidth
                ? tabletRows()
                : desktopRows();

        return RefreshIndicator(
          color: _mcGreen,
          onRefresh: () async {
            await load();
            await _loadTtdReport();
          },
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: viewportWidth),
              child: Padding(
                padding: pagePadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    fullWidthPanel(
                      height: headerHeight,
                      child: _analysisMatchHeader(
                        title: title,
                        opponent: opponent,
                        date: date,
                        competition: competition,
                        score: score,
                      ),
                    ),
                    rowGap(),
                    ...rows,
                    SizedBox(height: gap + 4),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }


  Widget _sizedAnalysisPanel(double height, {String? title, String? subtitle, Widget? trailing, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(height: height, child: title == null ? child : _analysisPanel(title: title, subtitle: subtitle, trailing: trailing, child: child)),
    );
  }


  Widget _analysisPanel({
    required String title,
    String? subtitle,
    Widget? trailing,
    required Widget child,
  }) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _mcLine, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Color(0xFFE8EEE9))),
            ),
            child: Row(
              children: [
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
                          color: Color(0xFF0B0F14),
                          fontSize: 11.2,
                          fontWeight: FontWeight.w600,
                          height: .95,
                          letterSpacing: -.12,
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 9.3,
                            fontWeight: FontWeight.w600,
                            height: .95,
                          ),
                        ),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 136),
                    child: trailing,
                  ),
                  const SizedBox(width: 7),
                ],
                _analysisPanelTools(
                  onExpand: () {
                    if (title.toLowerCase().contains('видеоаналитика')) {
                      _openActiveMatchVideoFullscreen();
                      return;
                    }
                    _openAnalysisPanelFullscreen(
                      title: title,
                      subtitle: subtitle,
                      child: child,
                    );
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: child,
            ),
          ),
        ],
      ),
    );
  }


  Widget _analysisPanelTools({
    VoidCallback? onCopy,
    VoidCallback? onPin,
    VoidCallback? onExpand,
    VoidCallback? onMore,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onCopy != null) ...[
          _analysisToolButton(
            icon: Icons.copy_all_rounded,
            tooltip: 'Копировать блок',
            onTap: onCopy,
          ),
          const SizedBox(width: 3),
        ],
        if (onExpand != null)
          _analysisToolButton(
            icon: Icons.open_in_full_rounded,
            tooltip: 'Открыть шире',
            onTap: onExpand,
          ),
      ],
    );
  }

  Widget _analysisToolButton({
    required IconData icon,
    required String tooltip,
    VoidCallback? onTap,
    double iconSize = 14,
  }) {
    final enabled = onTap != null;
    final button = Material(
      color: const Color(0xFFF6F7F9),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFF0F2F4)),
          ),
          child: Icon(
            icon,
            size: iconSize,
            color: enabled ? const Color(0xFF6B7280) : const Color(0xFF98A2B3),
          ),
        ),
      ),
    );

    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 350),
      child: button,
    );
  }

  void _openAnalysisPanelFullscreen({
    required String title,
    String? subtitle,
    required Widget child,
  }) {
    OverlayState? overlay;
    try {
      overlay = Navigator.of(context, rootNavigator: true).overlay ?? Overlay.maybeOf(context);
    } catch (_) {
      overlay = Overlay.maybeOf(context);
    }
    if (overlay == null) return;

    late OverlayEntry entry;
    Offset position = const Offset(74, 54);
    bool minimized = false;
    bool maximized = false;
    bool closed = false;

    void closeWindow() {
      if (closed) return;
      closed = true;
      if (entry.mounted) entry.remove();
    }

    entry = OverlayEntry(
      builder: (overlayContext) {
        final media = MediaQuery.of(overlayContext);
        final screen = media.size;
        final isCompact = screen.width < 760;

        final double width = maximized
            ? screen.width - 28
            : (isCompact ? screen.width - 24 : min(1180.0, max(760.0, screen.width * .78)));
        final double height = maximized
            ? screen.height - media.padding.top - media.padding.bottom - 28
            : (isCompact ? screen.height - media.padding.top - media.padding.bottom - 24 : min(760.0, max(520.0, screen.height * .78)));

        final double left = maximized
            ? 14.0
            : position.dx.clamp(12.0, max(12.0, screen.width - width - 12.0)).toDouble();
        final double top = maximized
            ? media.padding.top + 14.0
            : position.dy
                .clamp(
                  media.padding.top + 12.0,
                  max(media.padding.top + 12.0, screen.height - height - media.padding.bottom - 12.0),
                )
                .toDouble();

        if (minimized) {
          return Positioned(
            left: 22,
            bottom: media.padding.bottom + 22,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  minimized = false;
                  entry.markNeedsBuild();
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 40,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE4ECE8)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(.10),
                        blurRadius: 22,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.open_in_full_rounded, color: Color(0xFF00A750), size: 16),
                      const SizedBox(width: 8),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF111827),
                          fontSize: 11.2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return Positioned(
          left: left,
          top: top,
          width: width,
          height: height,
          child: Material(
            color: Colors.transparent,
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: _mcPanel,
                borderRadius: BorderRadius.circular(isCompact || maximized ? 8 : 18),
                border: Border.all(color: _mcLine.withOpacity(.92)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(.16),
                    blurRadius: 34,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanUpdate: maximized || isCompact
                        ? null
                        : (details) {
                            position += details.delta;
                            entry.markNeedsBuild();
                          },
                    child: Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: _mcPanelTop,
                        border: Border(bottom: BorderSide(color: _mcLine.withOpacity(.82))),
                      ),
                      child: Row(
                        children: [
                          _TeamMatchCmrWindowButton(icon: Icons.close_rounded, tooltip: 'Закрыть', onTap: closeWindow),
                          const SizedBox(width: 7),
                          _TeamMatchCmrWindowButton(
                            icon: Icons.remove_rounded,
                            tooltip: 'Свернуть',
                            onTap: () {
                              minimized = true;
                              entry.markNeedsBuild();
                            },
                          ),
                          const SizedBox(width: 7),
                          _TeamMatchCmrWindowButton(
                            icon: maximized ? Icons.close_fullscreen_rounded : Icons.open_in_full_rounded,
                            tooltip: maximized ? 'Вернуть размер' : 'Развернуть',
                            onTap: () {
                              maximized = !maximized;
                              entry.markNeedsBuild();
                            },
                          ),
                          const SizedBox(width: 12),
                          Container(
                            width: 30,
                            height: 30,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F6F9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.analytics_outlined, color: _mcText, size: 16),
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
                                  style: TextStyle(color: _mcText, fontSize: 13.2, fontWeight: FontWeight.w600),
                                ),
                                if (subtitle != null && subtitle.trim().isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: _mcSub, fontSize: 10.4, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.all(isCompact ? 10 : 16),
                      child: child,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(entry);
  }

  Widget _analysisDropDown(String text) {
    final t = text.trim().isEmpty ? 'Команда' : text.trim();
    return Container(height: 22, constraints: const BoxConstraints(maxWidth: 128), padding: const EdgeInsets.symmetric(horizontal: 8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(5), border: Border.all(color: _mcLine)), child: Row(mainAxisSize: MainAxisSize.min, children: [Flexible(child: Text(t, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _mcText, fontSize: 9.5, fontWeight: FontWeight.w600))), const SizedBox(width: 4), Icon(Icons.keyboard_arrow_down_rounded, color: _mcSub, size: 14)]));
  }

  Widget _analysisMatchHeader({required String title, required String opponent, required String date, required String competition, required String score}) {
    final ourTeam = _s(match?['our_team']).isEmpty ? teamName : _s(match?['our_team']);
    final opp = opponent.isEmpty ? 'Соперник' : opponent;
    final scoreParts = score.split(RegExp(r'[:\-]'));
    final leftScore = scoreParts.isNotEmpty ? scoreParts.first.trim() : '0';
    final rightScore = scoreParts.length > 1 ? scoreParts[1].trim() : '0';
    final stadium = _s(_stadiumCtrl.text).isEmpty ? _s(match?['stadium']) : _s(_stadiumCtrl.text);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: _mcPanel, border: Border.all(color: _mcLine.withOpacity(.9)), borderRadius: BorderRadius.circular(8)),
      child: Column(children: [
        Container(height: 28, padding: const EdgeInsets.symmetric(horizontal: 10), decoration: BoxDecoration(color: _mcPanelTop, border: Border(bottom: BorderSide(color: _mcLine.withOpacity(.85)))), child: Row(children: [Icon(Icons.star_border_rounded, color: _mcSub, size: 15), const SizedBox(width: 6), Expanded(child: Text(competition.isEmpty ? 'Матч команды' : competition, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _mcSub, fontSize: 10.5, fontWeight: FontWeight.w600))), _analysisPanelTools(
          onExpand: () => _openAnalysisPanelFullscreen(
            title: competition.isEmpty ? 'Матч команды' : competition,
            subtitle: 'Информация о матче',
            child: _analysisMatchHeader(
              title: title,
              opponent: opponent,
              date: date,
              competition: competition,
              score: score,
            ),
          ),
        )])),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Row(children: [Expanded(child: _analysisTeamBadge(ourTeam, Icons.shield_rounded, _mcBlue)), const SizedBox(width: 10), Container(width: 92, height: 62, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: _mcLine)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text('$leftScore - $rightScore', style: TextStyle(color: _mcText, fontSize: 23, fontWeight: FontWeight.w600, height: 1)), const SizedBox(height: 7), Text('ЗАВЕРШЕН', style: TextStyle(color: _mcGreen, fontSize: 10.5, fontWeight: FontWeight.w600))])), const SizedBox(width: 10), Expanded(child: _analysisTeamBadge(opp, Icons.security_rounded, _mcGreen, right: true))]),
              const SizedBox(height: 9),
              Text([if (date.isNotEmpty) date, if (stadium.isNotEmpty) stadium, if (title.isNotEmpty) title].join(' · '), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _mcSub, fontSize: 10.5, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ]),
    );
  }


  bool get _hasLiveAiData => _liveAiPlayers.isNotEmpty;

  String _liveAiPlayerLabel(int trackId, {PlayerDetection? player}) {
    if (player != null) {
      final name = player.name.trim();
      if (name.isNotEmpty && !name.toLowerCase().contains('игрок')) return name;
      if (player.number > 0) return '№${player.number}';
    }
    return 'Игрок $trackId';
  }

  void _onLiveAiStatus(String status) {
    if (!mounted) return;
    setState(() => _liveAiStatus = status.replaceAll('✅', '').replaceAll('❌', '').replaceAll('⚠️', '').replaceAll('🔄', '').trim());
  }

  void _onLiveAiFrame(AnalysisResult result) {
    if (result.players.isEmpty) return;

    final timeMs = result.timestamp > 0 ? result.timestamp : result.frame * 20.0;
    final dtSec = ((_liveAiTimeMs > 0) ? (timeMs - _liveAiTimeMs) / 1000.0 : 0.0).clamp(0.04, 1.8).toDouble();
    final nextPositions = <int, Offset>{};
    final nextTrails = <int, List<Offset>>{};
    final nextSpeeds = Map<int, double>.from(_liveAiSpeedsKmh);
    final nextAccels = Map<int, double>.from(_liveAiAccelerations);
    final nextSprints = Map<int, int>.from(_liveAiSprints);
    final nextLoad = Map<int, double>.from(_liveAiLoad);
    final nextMotion = Map<int, _AiPlayerMotion>.from(_lastAiMotion);
    final events = List<Map<String, dynamic>>.from(_liveAiEvents);

    final serverEvents = <Map<String, dynamic>>[
      ...result.recentEvents,
      ...result.events,
    ];
    for (final event in serverEvents.reversed) {
      final eventId = _s(event['id']);
      if (eventId.isNotEmpty && events.any((old) => _s(old['server_event_id']) == eventId)) {
        continue;
      }
      final type = _s(event['event_type']);
      final title = <String, String>{
            'pass': 'Передача',
            'interception': 'Перехват',
            'shot': 'Удар',
            'shot_on_target': 'Удар в створ',
            'goal': 'Гол',
            'ball_out': 'Мяч вне поля',
            'corner_candidate': 'Возможный угловой',
            'free_kick_candidate': 'Возможный штрафной',
          }[type] ??
          type.replaceAll('_', ' ');
      events.insert(0, {
        'server_event_id': eventId,
        'minute': _formatMatchPlayerTime(
          Duration(milliseconds: _i(event['time_ms'])),
        ),
        'title': title,
        'subtitle': 'AI ${(100 * _d(event['confidence'])).round()}% · ${_s(event['status'])}',
        'icon': type.contains('goal') ? Icons.sports_soccer_rounded : Icons.auto_awesome_rounded,
        'color': type.contains('goal') ? _mcGreen : _mcBlue,
      });
    }
    for (final advice in <Map<String, dynamic>>[
      ...result.recentAdvice,
      ...result.advice,
    ].reversed) {
      final adviceId = _s(advice['id']);
      if (adviceId.isNotEmpty && events.any((old) => _s(old['server_event_id']) == adviceId)) {
        continue;
      }
      events.insert(0, {
        'server_event_id': adviceId,
        'minute': _formatMatchPlayerTime(Duration(milliseconds: _i(advice['time_ms']))),
        'title': _s(advice['title']).isEmpty ? 'Подсказка тренеру' : _s(advice['title']),
        'subtitle': _s(advice['message']),
        'icon': Icons.psychology_alt_rounded,
        'color': _mcYellow,
      });
    }

    for (final player in result.players) {
      final trackId = player.trackId > 0 ? player.trackId : int.tryParse(player.id) ?? player.bbox.hashCode.abs();
      if (player.bbox.isEmpty) continue;

      // Для мини-карты используем нижнюю точку bbox — условные "ноги" игрока.
      // Карта в CMR-обзоре вертикальная: X = ширина поля, Y = длина поля.
      // Камера матча перспективная, поэтому rawY из видео сжимает игроков к центру.
      // Небольшая коррекция перспективы распределяет точки по полю заметно естественнее
      // до полноценной калибровки 4 точек поля.
      final footX = player.bbox.center.dx;
      final footY = player.bbox.bottom;
      final rawX = (footX / 1920.0).clamp(0.0, 1.0).toDouble();
      final rawY = (footY / 1080.0).clamp(0.0, 1.0).toDouble();
      final fieldX = rawX;
      const visibleFieldTop = 0.22;
      const visibleFieldBottom = 0.94;
      final fieldY = ((rawY - visibleFieldTop) / (visibleFieldBottom - visibleFieldTop))
          .clamp(0.0, 1.0)
          .toDouble();

      final prev = _lastAiMotion[trackId];
      final rawPos = Offset(fieldX, fieldY);
      Offset pos = rawPos;
      var speedKmh = nextSpeeds[trackId] ?? 0.0;
      var accel = nextAccels[trackId] ?? 0.0;
      final metrics = player.metrics;
      final hasGpsSpeed = metrics.containsKey('speed_kmh');
      final hasGpsSprints = metrics.containsKey('sprint_count');
      final hasGpsLoad = metrics.containsKey('load_score');

      // Если трек не перескочил резко, слегка сглаживаем точку на мини-карте.
      // Если скачок большой — считаем, что YOLO/track_id сменился, и начинаем новый след.
      final bool resetTrail = prev != null && (rawPos - prev.position).distance > .22;
      if (prev != null && !resetTrail) {
        pos = Offset(
          prev.position.dx * .42 + rawPos.dx * .58,
          prev.position.dy * .42 + rawPos.dy * .58,
        );
      }
      nextPositions[trackId] = pos;

      final trail = resetTrail ? <Offset>[] : List<Offset>.from(_liveAiTrails[trackId] ?? const []);
      trail.add(pos);
      if (trail.length > 70) trail.removeRange(0, trail.length - 70);
      nextTrails[trackId] = trail;

      if (prev != null && dtSec > 0 && !resetTrail) {
        final dxM = (pos.dx - prev.position.dx) * 105.0;
        final dyM = (pos.dy - prev.position.dy) * 68.0;
        final meters = sqrt(dxM * dxM + dyM * dyM);
        final rawSpeed = (meters / dtSec) * 3.6;
        // Фильтр скачков bbox: YOLO иногда перескакивает между игроками.
        final filtered = rawSpeed.isFinite ? rawSpeed.clamp(0.0, 38.0).toDouble() : 0.0;
        speedKmh = speedKmh <= 0 ? filtered : speedKmh * .58 + filtered * .42;
        accel = ((speedKmh / 3.6) - (prev.speedKmh / 3.6)) / dtSec;
        accel = accel.clamp(-8.0, 8.0).toDouble();
      } else if (resetTrail) {
        speedKmh = 0.0;
        accel = 0.0;
      }

      // Физические показатели берём из GPS/Polar. Расчёт по bbox выше остаётся
      // только визуальным fallback, когда трекер конкретному track_id ещё не привязан.
      if (hasGpsSpeed) speedKmh = _d(metrics['speed_kmh']);
      if (metrics.containsKey('acceleration_mps2')) {
        accel = _d(metrics['acceleration_mps2']);
      }

      nextSpeeds[trackId] = speedKmh;
      nextAccels[trackId] = accel;
      nextLoad[trackId] = hasGpsLoad
          ? _d(metrics['load_score'])
          : ((nextLoad[trackId] ?? 0.0) + speedKmh * .035 + accel.abs() * .18)
              .clamp(0.0, 100.0)
              .toDouble();
      if (hasGpsSprints) nextSprints[trackId] = _i(metrics['sprint_count']);

      final sprintNow = speedKmh >= 22.0;
      final prevSprint = _lastAiMotion[trackId]?.sprinting == true;
      if (!hasGpsSprints && sprintNow && !prevSprint) {
        nextSprints[trackId] = (nextSprints[trackId] ?? 0) + 1;
        final label = _liveAiPlayerLabel(trackId, player: player);
        events.insert(0, {
          'minute': _formatMatchPlayerTime(Duration(milliseconds: timeMs.round())),
          'title': 'Спринт $label',
          'subtitle': '${speedKmh.toStringAsFixed(1)} км/ч',
          'icon': Icons.bolt_rounded,
          'color': _mcGreen,
        });
      }

      nextMotion[trackId] = _AiPlayerMotion(position: pos, timeMs: timeMs, speedKmh: speedKmh, sprinting: sprintNow);
    }

    if (events.length > 30) events.removeRange(30, events.length);

    if (!mounted) return;
    setState(() {
      _liveAiPlayers = result.players;
      _liveAiPositions
        ..clear()
        ..addAll(nextPositions);
      _liveAiTrails
        ..clear()
        ..addAll(nextTrails);
      _liveAiSpeedsKmh
        ..clear()
        ..addAll(nextSpeeds);
      _liveAiAccelerations
        ..clear()
        ..addAll(nextAccels);
      _liveAiSprints
        ..clear()
        ..addAll(nextSprints);
      _liveAiLoad
        ..clear()
        ..addAll(nextLoad);
      _lastAiMotion
        ..clear()
        ..addAll(nextMotion);
      _liveAiEvents
        ..clear()
        ..addAll(events);
      _liveAiFrame = result.frame;
      _liveAiTimeMs = timeMs;
      _liveAiStatus = 'Live AI: ${result.players.length} игроков';
    });

    _queueSaveLiveAiFrame(result);
  }

  void _queueSaveLiveAiFrame(AnalysisResult result) {
    final now = DateTime.now();
    if (_savingLiveAiFrame || now.difference(_lastAiSaveAt).inMilliseconds < 2200) return;
    _lastAiSaveAt = now;
    _savingLiveAiFrame = true;

    final payload = {
      'match_id': matchId,
      'team_id': teamId,
      'frame': result.frame,
      'time_ms': result.timestamp,
      'players_count': result.players.length,
      'match_live_id': result.matchLiveId,
      'source_mode': result.sourceMode,
      'ball': result.ball,
      'telemetry': result.telemetry,
      'players': result.players.map((p) => {
            'id': p.id,
            'track_id': p.trackId,
            'name': p.name,
            'confidence': p.confidence,
            'bbox': [p.bbox.left, p.bbox.top, p.bbox.right, p.bbox.bottom],
            'speed_kmh': _liveAiSpeedsKmh[p.trackId] ?? 0,
            'acceleration': _liveAiAccelerations[p.trackId] ?? 0,
            'sprints': _liveAiSprints[p.trackId] ?? 0,
            'load': _liveAiLoad[p.trackId] ?? 0,
          }).toList(),
      'events': result.recentEvents.isNotEmpty
          ? result.recentEvents.take(20).toList()
          : _liveAiEvents.take(12).map((e) => {
            'minute': _s(e['minute']),
            'title': _s(e['title']),
            'subtitle': _s(e['subtitle']),
          }).toList(),
    };

    unawaited(
      http
          .post(
            Uri.parse('$apiBase/save_match_ai_live_frame.php'),
            headers: const {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 6))
          .catchError((Object error) {
            developer.log('AI live save skipped/failed: $error', name: 'TeamMatchDetailScreen');
            return http.Response('{}', 499);
          })
          .whenComplete(() => _savingLiveAiFrame = false),
    );
  }

  Widget _analysisTeamBadge(String name, IconData icon, Color color, {bool right = false}) {
    final logo = Container(width: 54, height: 54, decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(.14), border: Border.all(color: color.withOpacity(.78), width: 2)), child: Icon(icon, color: color, size: 30));
    final text = Flexible(child: Column(crossAxisAlignment: right ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: right ? TextAlign.right : TextAlign.left, style: TextStyle(color: _mcText, fontSize: 14.5, height: 1.1, fontWeight: FontWeight.w600)), const SizedBox(height: 4), Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.star_rounded, color: _mcYellow, size: 14), const SizedBox(width: 4), Text('команда', style: TextStyle(color: _mcSub, fontSize: 9.5, fontWeight: FontWeight.w600))])]));
    return Row(mainAxisAlignment: right ? MainAxisAlignment.end : MainAxisAlignment.start, children: right ? [text, const SizedBox(width: 10), logo] : [logo, const SizedBox(width: 10), text]);
  }

  Widget _analysisLiveSprintBars() {
    if (!_hasLiveAiData || _liveAiSprints.isEmpty) {
      return const CustomPaint(painter: _MatchStackedBarsPainter());
    }
    final rows = _liveAiSprints.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows.take(7).map((entry) {
        final value = entry.value;
        return Expanded(
          child: Row(
            children: [
              SizedBox(width: 74, child: Text('Игрок ${entry.key}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _mcText, fontSize: 10.5, fontWeight: FontWeight.w600))),
              Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(value: (value / 8).clamp(0, 1), minHeight: 5, color: _mcGreen, backgroundColor: const Color(0xFFE5E7EB)))),
              const SizedBox(width: 8),
              SizedBox(width: 28, child: Text('$value', textAlign: TextAlign.right, style: TextStyle(color: _mcText, fontSize: 10.5, fontWeight: FontWeight.w600))),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _analysisLiveLoadBars() {
    if (!_hasLiveAiData || _liveAiLoad.isEmpty) {
      return const CustomPaint(painter: _MatchLoadBarsPainter());
    }
    final rows = _liveAiLoad.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows.take(8).map((entry) {
        final value = entry.value.clamp(0.0, 100.0).toDouble();
        final color = value >= 70 ? const Color(0xFFEF4444) : value >= 45 ? const Color(0xFFF59E0B) : _mcGreen;
        return Expanded(
          child: Row(
            children: [
              SizedBox(width: 74, child: Text('Игрок ${entry.key}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _mcText, fontSize: 10.5, fontWeight: FontWeight.w600))),
              Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(value: (value / 100).clamp(0, 1), minHeight: 5, color: color, backgroundColor: const Color(0xFFE5E7EB)))),
              const SizedBox(width: 8),
              SizedBox(width: 36, child: Text('${value.round()}%', textAlign: TextAlign.right, style: TextStyle(color: _mcText, fontSize: 10.5, fontWeight: FontWeight.w600))),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _analysisSpeedBars() {
    if (_hasLiveAiData && _liveAiSpeedsKmh.isNotEmpty) {
      final rows = _liveAiSpeedsKmh.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final visible = rows.take(10).toList();
      return Column(
        children: visible.map((entry) {
          final trackId = entry.key;
          final v = entry.value;
          PlayerDetection? player;
          for (final p in _liveAiPlayers) {
            final id = p.trackId > 0 ? p.trackId : int.tryParse(p.id) ?? -1;
            if (id == trackId) {
              player = p;
              break;
            }
          }
          final label = _liveAiPlayerLabel(trackId, player: player);
          return Expanded(
            child: Row(
              children: [
                SizedBox(width: 82, child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _mcText, fontSize: 10.5, fontWeight: FontWeight.w600))),
                Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(value: (v / 34).clamp(0, 1), minHeight: 4, color: v >= 22 ? _mcGreen : _mcBlue, backgroundColor: const Color(0xFFE5E7EB)))),
                const SizedBox(width: 8),
                SizedBox(width: 34, child: Text(v.toStringAsFixed(1), textAlign: TextAlign.right, style: TextStyle(color: _mcText, fontSize: 10.5, fontWeight: FontWeight.w600))),
              ],
            ),
          );
        }).toList(),
      );
    }

    final names = _analysisPlayerNames();
    final values = [33.4, 32.1, 31.8, 31.2, 30.9, 30.2, 29.8, 29.5, 29.1, 28.7];
    return Column(children: List.generate(min(names.length, values.length), (index) {
      final v = values[index];
      return Expanded(child: Row(children: [SizedBox(width: 82, child: Text(names[index], maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _mcText, fontSize: 10.5, fontWeight: FontWeight.w600))), Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(value: (v / 36).clamp(0, 1), minHeight: 4, color: _mcBlue, backgroundColor: const Color(0xFFE5E7EB)))), const SizedBox(width: 8), SizedBox(width: 30, child: Text(v.toStringAsFixed(1), textAlign: TextAlign.right, style: TextStyle(color: _mcText, fontSize: 10.5, fontWeight: FontWeight.w600)))]));
    }));
  }

  List<String> _analysisPlayerNames() {
    final names = ttdPlayers.map((e) => _playerName(e)).where((e) => e.trim().isNotEmpty).take(10).toList();
    return names.length >= 6 ? names : ['Бахар', 'Седько', 'Лисакович', 'Гречихо', 'Бегунов', 'Зеньков', 'Барковский', 'Пащенко', 'Коваль', 'Журавлев'];
  }


  List<Map<String, dynamic>> _analysisMatchPlayerRows() {
    final byKey = <String, Map<String, dynamic>>{};

    void addRows(dynamic source) {
      if (source is! Iterable) return;
      for (final item in source) {
        if (item is! Map) continue;
        final row = Map<String, dynamic>.from(item);
        final name = _playerName(row).trim();
        if (name.isEmpty || name.toLowerCase() == 'суммарно по матчу') continue;
        final key = _playerIdentityKey(row);
        byKey.putIfAbsent(key, () => row);
      }
    }

    addRows(match?['players']);
    addRows(ttdPlayers);
    addRows(playerVideoTotals);
    addRows(mainReport);
    addRows(passReport);

    if (byKey.isEmpty) {
      for (final name in _analysisPlayerNames()) {
        byKey['name:${name.toLowerCase()}'] = {'player_name': name};
      }
    }

    final rows = byKey.values.toList();
    rows.sort((a, b) => _playerMvpScore(b).compareTo(_playerMvpScore(a)));
    return rows.take(18).toList();
  }

  Widget _analysisMatchPlayersPane() {
    final rows = _analysisMatchPlayerRows();
    if (rows.isEmpty) {
      return _emptyState('Игроки матча пока не загружены', icon: Icons.groups_2_outlined);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        final avatarSize = compact ? 34.0 : 40.0;
        final rowHeight = compact ? 54.0 : 62.0;
        return Scrollbar(
          thumbVisibility: false,
          child: ListView.separated(
            padding: EdgeInsets.zero,
            physics: const BouncingScrollPhysics(),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 6),
            itemBuilder: (_, index) {
              final row = rows[index];
              final key = _playerIdentityKey(row);
              final selected = _selectedAnalysisPlayerKey == key || (_selectedAnalysisPlayerKey == null && index == 0);
              final name = _playerName(row);
              final photo = _playerPhotoUrl(row);
              final rating = _playerRating(row);
              final total = _playerTotalTtdActions(row);
              final goals = _playerGoalCount(row);
              final assists = _playerAssistCount(row);

              return Material(
                color: selected ? _mcGreen.withOpacity(.10) : const Color(0xFFF8FAF9),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    setState(() => _selectedAnalysisPlayerKey = key);
                  },
                  child: Container(
                    height: rowHeight,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: selected ? _mcGreen.withOpacity(.42) : _mcLine.withOpacity(.72)),
                    ),
                    child: Row(
                      children: [
                        _PlayerAvatar(imageUrl: photo, name: name, primary: _mcGreen, size: avatarSize),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _mcText, fontSize: compact ? 10.5 : 11.4, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 3),
                              Text('ТТД: $total · Г: $goals · А: $assists', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _mcSub, fontSize: compact ? 9.0 : 9.8, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: compact ? 34 : 40,
                          height: compact ? 24 : 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: selected ? _mcGreen : Colors.white, borderRadius: BorderRadius.circular(9), border: Border.all(color: selected ? _mcGreen : _mcLine)),
                          child: Text(rating, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: selected ? Colors.white : _mcText, fontSize: compact ? 10 : 11, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _analysisStatsTable({bool compact = false}) {
    final rows = _matchStatsRows();
    final opp = _s(match?['opponent']).isEmpty ? 'Соперник' : _s(match?['opponent']);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Row(children: [Expanded(child: Text(teamName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _mcBlue, fontSize: 10.5, fontWeight: FontWeight.w600))), Expanded(child: Text(opp, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right, style: TextStyle(color: _mcGreen, fontSize: 10.5, fontWeight: FontWeight.w600)))]), const SizedBox(height: 5), ...rows.take(compact ? 9 : rows.length).map((row) => Expanded(child: Row(children: [SizedBox(width: 38, child: Text('${row[1]}', style: TextStyle(color: _mcText, fontSize: 10.5, fontWeight: FontWeight.w600))), Expanded(child: Text(row[0].toString(), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(color: _mcSub, fontSize: 10.1, fontWeight: FontWeight.w600))), SizedBox(width: 38, child: Text('${row[2]}', textAlign: TextAlign.right, style: TextStyle(color: _mcText, fontSize: 10.5, fontWeight: FontWeight.w600)))])))]);
  }

  Widget _analysisAiBlock({bool compact = false}) {
    final liveLoad = _liveAiLoad.isEmpty ? 0.0 : _liveAiLoad.values.reduce((a, b) => a + b) / _liveAiLoad.length;
    final displayScore = _hasLiveAiData ? liveLoad.clamp(0, 100).round() : (_efficiency <= 0 ? 83 : _efficiency.clamp(0, 100).round());
    final liveTopSpeed = _liveAiSpeedsKmh.isEmpty ? 0.0 : _liveAiSpeedsKmh.values.reduce((a, b) => a > b ? a : b);
    final liveSprints = _liveAiSprints.values.fold<int>(0, (sum, value) => sum + value);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Container(width: compact ? 58 : 70, height: compact ? 58 : 70, alignment: Alignment.center, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _mcGreen, width: 5), color: _mcGreen.withOpacity(.12)), child: Text('$displayScore', style: TextStyle(color: _mcGreen, fontSize: compact ? 19 : 23, fontWeight: FontWeight.w600))), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_hasLiveAiData ? 'Live AI подключен' : 'Высокая эффективность', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _mcGreen, fontSize: 12.5, fontWeight: FontWeight.w600)), const SizedBox(height: 4), Text(_hasLiveAiData ? 'Кадр $_liveAiFrame · ${_liveAiPlayers.length} игроков · ${_formatMatchPlayerTime(Duration(milliseconds: _liveAiTimeMs.round()))}' : _aiCoachText(), maxLines: compact ? 3 : 4, overflow: TextOverflow.ellipsis, style: TextStyle(color: _mcSub, fontSize: 10.5, height: 1.25, fontWeight: FontWeight.w600))]))]),
      const SizedBox(height: 10),
      Text('Ключевые инсайты', style: TextStyle(color: _mcText, fontSize: 11.5, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      if (_hasLiveAiData) ...[
        _analysisBullet('В кадре сейчас: ${_liveAiPlayers.length} игроков'),
        _analysisBullet('Максимальная скорость live: ${liveTopSpeed.toStringAsFixed(1)} км/ч'),
        _analysisBullet('Спринтов за просмотр: $liveSprints'),
      ] else ...[
        _analysisBullet('64% атак начинались через центр'),
        _analysisBullet('Высокая интенсивность в финальной трети'),
        _analysisBullet('Компактность проседала после 60-й минуты'),
      ],
      if (!compact) ...[const SizedBox(height: 8), Text('Рекомендации', style: TextStyle(color: _mcText, fontSize: 11.5, fontWeight: FontWeight.w600)), const SizedBox(height: 6), _analysisBullet(_aiRecommendation()), _analysisBullet('Ускорять переход в атаку коротким пасом')],
    ]);
  }

  Widget _analysisBullet(String text) => Padding(padding: const EdgeInsets.only(bottom: 5), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: 4, height: 4, margin: const EdgeInsets.only(top: 6), decoration: BoxDecoration(color: _mcGreen, borderRadius: BorderRadius.circular(99))), const SizedBox(width: 7), Expanded(child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: _mcSub, fontSize: 10.2, height: 1.25, fontWeight: FontWeight.w600)))]));

  Map<String, dynamic>? _firstUploadedMatchVideo({required bool tactical}) {
    final fullVideos = _videosByType('full')
        .where((video) => _analysisVideoUrl(video) != null)
        .toList();

    if (fullVideos.isEmpty) return null;

    if (tactical) {
      final tacticalVideo = fullVideos.firstWhere(
        (video) {
          final type = _s(video['analysis_type']).toLowerCase();
          final title = '${_s(video['file_name'])} ${_s(video['title'])}'.toLowerCase();
          return type.contains('tactical') ||
              type.contains('тактик') ||
              title.contains('tactical') ||
              title.contains('тактик');
        },
        orElse: () => fullVideos.first,
      );
      return tacticalVideo;
    }

    return fullVideos.first;
  }

  String? _analysisVideoUrl(Map<String, dynamic>? video) {
    if (video == null) return null;

    for (final key in [
      'video_url',
      'file_url',
      'url',
      'path',
      'video_path',
    ]) {
      final normalized = _normalizeUrl(_s(video[key]));
      if (normalized != null && normalized.isNotEmpty) return normalized;
    }

    return null;
  }

  String? _analysisVideoThumb(Map<String, dynamic>? video) {
    if (video == null) return null;

    for (final key in [
      'thumbnail_url',
      'thumbnail',
      'preview_url',
      'preview',
      'poster',
    ]) {
      final normalized = _normalizeUrl(_s(video[key]));
      if (normalized != null && normalized.isNotEmpty) return normalized;
    }

    return null;
  }

  String _friendlyVideoPlayerError(Object error) {
    final text = error.toString();
    if (text.contains('OSStatus error -12848') ||
        text.toLowerCase().contains('cannot open') ||
        text.toLowerCase().contains('damaged')) {
      return 'Плеер macOS не смог открыть файл. Обычно это битый файл, неподдерживаемый кодек MOV/HEVC или старый повреждённый URL в базе.';
    }
    if (text.toLowerCase().contains('source error') || text.toLowerCase().contains('404')) {
      return 'Файл не найден по ссылке. Проверьте, что видео реально лежит в /uploads/team_matches/.';
    }
    return 'Видео загружено, но встроенный плеер не смог его открыть.';
  }

  void _clearAnalysisVideoControllers() {
    for (final controller in _analysisVideoControllers.values) {
      controller.dispose();
    }
    _analysisVideoControllers.clear();
    _analysisVideoInitFutures.clear();
    _analysisVideoInitErrors.clear();
    _activeAnalysisVideoKey = null;
  }

  String _analysisVideoControllerKey(String url, {required bool tactical}) {
    return '${tactical ? 'tactical' : 'main'}::$url';
  }

  VideoPlayerController _analysisVideoController(
    String url, {
    required bool tactical,
  }) {
    final key = _analysisVideoControllerKey(url, tactical: tactical);
    final existing = _analysisVideoControllers[key];
    if (existing != null) return existing;

    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _analysisVideoControllers[key] = controller;
    _analysisVideoInitErrors.remove(key);
    _analysisVideoInitFutures[key] = controller.initialize().then((_) async {
      await controller.setLooping(true);
      await controller.setVolume(0);
      if (mounted) setState(() {});
    }).catchError((Object error, StackTrace stackTrace) {
      final message = _friendlyVideoPlayerError(error);
      _analysisVideoInitErrors[key] = message;
      developer.log(
        'Video player init failed: $url',
        name: 'TeamMatchDetailScreen',
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) setState(() {});
    });
    _analysisVideoControllers[key] = controller;

    return controller;
  }

  Map<String, dynamic>? _matchVideoSourceForBottom({required bool tactical}) {
    final video = _firstUploadedMatchVideo(tactical: tactical);
    final url = _analysisVideoUrl(video);

    if (url == null || url.isEmpty) return null;

    final title = tactical
        ? 'Тактический ракурс'
        : _formatVideoTitle(_s(video?['file_name']), 'Видео матча');

    return {
      'key': _analysisVideoControllerKey(url, tactical: tactical),
      'url': url,
      'title': title,
      'tactical': tactical,
    };
  }

  Map<String, dynamic>? _activeMatchVideoSourceForBottom() {
    final tactical = _matchVideoSourceForBottom(tactical: true);
    if (tactical == null) return null;
    _activeAnalysisVideoKey ??= tactical['key'] as String;
    return tactical;
  }

  VideoPlayerController? _activeMatchVideoControllerForBottom() {
    // Нижняя панель теперь управляет только WebView-плеером AI-тактического ракурса.
    // Нативный video_player здесь не используем, чтобы не блокировать Play.
    return null;
  }

  void _activateMatchVideo(String key) {
    _activeAnalysisVideoKey = key;

    for (final entry in _analysisVideoControllers.entries) {
      if (entry.key != key && entry.value.value.isPlaying) {
        entry.value.pause();
      }
    }
  }

  bool _isBottomPlaybackPlaying() {
    return _embeddedAiPlayback.isPlaying;
  }

  bool _isBottomPlaybackReady() {
    return _embeddedAiPlayback.isReady || _embeddedAiPlayback.attached;
  }

  Duration _currentBottomPlaybackDuration() {
    return _embeddedAiPlayback.duration;
  }

  String _bottomPlaybackStatusText() {
    if (_bottomVideoLoading) return 'Подготовка AI-тактического ракурса...';
    if (!_isBottomPlaybackReady()) return 'AI-видео загружается...';
    if (_liveAiStatus.trim().isNotEmpty && !_liveAiStatus.toLowerCase().contains('ожидает')) {
      return _liveAiStatus;
    }
    return 'Готово к воспроизведению';
  }

  Future<void> _toggleBottomMatchVideo() async {
    final source = _activeMatchVideoSourceForBottom();
    if (source == null) return;

    final shouldPause = _isBottomPlaybackPlaying();

    if (shouldPause) {
      await _embeddedAiPlayback.pause();
      if (mounted) {
        setState(() {
          _bottomVideoLoading = false;
          _liveAiStatus = 'Пауза';
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _bottomVideoLoading = true;
        _liveAiStatus = 'Подготовка AI-тактического ракурса...';
      });
    }

    _activateMatchVideo(source['key'] as String);

    try {
      await _embeddedAiPlayback.setSpeed(_matchPlaybackSpeed);
      // Управляем только тактическим AI-плеером. Внутренние кнопки в карточке скрыты.
      await _embeddedAiPlayback.play();
    } catch (e) {
      developer.log('Bottom AI play failed', name: 'TeamMatchDetailScreen', error: e);
    }

    if (mounted) {
      setState(() {
        _bottomVideoLoading = false;
      });
    }
  }

  Future<void> _seekBottomMatchVideoRelative(int seconds) async {
    final duration = _currentBottomPlaybackDuration();
    final current = _currentBottomPlaybackPosition();
    final target = current + Duration(seconds: seconds);
    final safeTarget = target < Duration.zero
        ? Duration.zero
        : (duration.inMilliseconds > 0 && target > duration ? duration : target);

    await _embeddedAiPlayback.seekTo(safeTarget);
    if (mounted) setState(() {});
  }

  Future<void> _seekBottomMatchVideoToFraction(double value) async {
    final duration = _currentBottomPlaybackDuration();
    if (duration.inMilliseconds <= 0) return;

    final targetMs = (duration.inMilliseconds * value).round();
    final target = Duration(milliseconds: targetMs);

    await _embeddedAiPlayback.seekTo(target);
    if (mounted) setState(() {});
  }

  Future<void> _seekBottomMatchVideoTo(Duration position) async {
    final duration = _currentBottomPlaybackDuration();
    final safePosition = position < Duration.zero
        ? Duration.zero
        : (duration.inMilliseconds > 0 && position > duration ? duration : position);

    await _embeddedAiPlayback.seekTo(safePosition);
    if (mounted) setState(() {});
  }

  Future<void> _seekActiveBottomPlaybackTo(Duration position) async {
    final isAiTab = _safeMatchTabIndex(_tabController.index) == 5;

    if (isAiTab && _aiReviewPlayback.attached && _aiReviewPlayback.isReady) {
      final duration = _aiReviewPlayback.duration;
      if (duration.inMilliseconds > 0) {
        final safePosition = position < Duration.zero
            ? Duration.zero
            : position > duration
                ? duration
                : position;
        final fraction = safePosition.inMilliseconds / duration.inMilliseconds;
        _aiReviewPlayback.seekToFraction(fraction.clamp(0.0, 1.0).toDouble());
        return;
      }
    }

    await _seekBottomMatchVideoTo(position);
  }

  Duration _currentBottomPlaybackPosition() {
    final isAiTab = _safeMatchTabIndex(_tabController.index) == 5;
    if (isAiTab && _aiReviewPlayback.attached && _aiReviewPlayback.isReady) {
      return _aiReviewPlayback.position;
    }

    if (_embeddedAiPlayback.attached) return _embeddedAiPlayback.position;

    return Duration.zero;
  }

  Future<void> _cycleBottomMatchVideoSpeed() async {
    const speeds = [0.5, 1.0, 1.25, 1.5, 2.0];
    final currentIndex = speeds.indexWhere((s) => s == _matchPlaybackSpeed);
    final nextSpeed = speeds[(currentIndex + 1) % speeds.length];

    _matchPlaybackSpeed = nextSpeed;
    await _embeddedAiPlayback.setSpeed(nextSpeed);

    if (mounted) setState(() {});
  }

  void _openActiveMatchVideoFullscreen() {
    final video = _firstUploadedMatchVideo(tactical: true);
    final url = _analysisVideoUrl(video);
    if (url == null || url.isEmpty) return;

    final params = _analysisParamsForVideo(video ?? <String, dynamic>{}, fallbackUrl: url);
    showAdvancedVideoAnalysisWindow(
      context,
      params,
      externalPlaybackController: _embeddedAiPlayback,
      hideControls: false,
    );
  }

  Future<void> _toggleAnalysisVideoFromPane(
    VideoPlayerController controller,
    String key,
  ) async {
    // Старый нативный плеер оставлен только для совместимости. Основное управление
    // теперь идёт через нижнюю общую панель и WebView-плееры.
    await _toggleBottomMatchVideo();
  }

  List<Map<String, dynamic>> _bottomMatchEvents() {
    final result = <Map<String, dynamic>>[];

    for (final e in episodes) {
      final type = _s(e['type'] ?? e['event_type'] ?? e['episode_type']);
      final title = _timelineTitle(type, e);
      final time = _eventPositionFromMap(e);
      final player = _s(e['player_name'] ?? e['author_name'] ?? e['name']).isEmpty
          ? (_s(e['title']).isEmpty ? 'Эпизод матча' : _s(e['title']))
          : _s(e['player_name'] ?? e['author_name'] ?? e['name']);

      result.add({
        'title': title,
        'subtitle': player,
        'description': _s(e['description'] ?? e['comment'] ?? e['note']),
        'time': time,
        'timeLabel': _formatMatchPlayerTime(time),
        'icon': _timelineIcon(type),
        'color': _timelineColor(type),
      });
    }

    result.sort((a, b) => (a['time'] as Duration).compareTo(b['time'] as Duration));

    if (result.isNotEmpty) return result;

    return [
      {
        'title': 'Начало матча',
        'subtitle': teamName,
        'description': 'Стартовый отрезок',
        'time': Duration.zero,
        'timeLabel': '00:00',
        'icon': Icons.play_arrow_rounded,
        'color': _mcBlue,
      },
      {
        'title': '15 минут',
        'subtitle': 'Первый игровой отрезок',
        'description': 'Быстрый переход к 15-й минуте',
        'time': const Duration(minutes: 15),
        'timeLabel': '15:00',
        'icon': Icons.flag_rounded,
        'color': _mcGreen,
      },
      {
        'title': 'Перерыв',
        'subtitle': 'Конец первого тайма',
        'description': 'Быстрый переход к 45-й минуте',
        'time': const Duration(minutes: 45),
        'timeLabel': '45:00',
        'icon': Icons.sports_soccer_rounded,
        'color': _mcYellow,
      },
      {
        'title': '75 минут',
        'subtitle': 'Финальный отрезок',
        'description': 'Быстрый переход к 75-й минуте',
        'time': const Duration(minutes: 75),
        'timeLabel': '75:00',
        'icon': Icons.bolt_rounded,
        'color': _mcBlue,
      },
    ];
  }

  Duration _eventPositionFromMap(Map<String, dynamic> e) {
    final secondsKeys = [
      'time_seconds',
      'timestamp_seconds',
      'seconds',
      'start_second',
      'start_seconds',
    ];

    for (final key in secondsKeys) {
      final value = _i(e[key]);
      if (value > 0) return Duration(seconds: value);
    }

    final msKeys = ['time_ms', 'timestamp_ms', 'start_ms'];
    for (final key in msKeys) {
      final value = _i(e[key]);
      if (value > 0) return Duration(milliseconds: value);
    }

    final minute = _i(e['minute'] ?? e['time_minute'] ?? e['match_minute'] ?? e['min']);
    final second = _i(e['second'] ?? e['time_second'] ?? e['match_second'] ?? e['sec']);

    return Duration(minutes: minute, seconds: second);
  }

  Future<void> _openBottomMatchEventsSheet() async {
    final events = _bottomMatchEvents();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: SizedBox(
            height: min(MediaQuery.of(sheetContext).size.height * .72, 620.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 12, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'События матча',
                              style: AppTypography.sectionTitle(color: _mcText),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Нажмите на событие — видео перейдёт к нужному моменту',
                              style: TextStyle(
                                color: _mcSub,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: _mcLine),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(14),
                    itemCount: events.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final event = events[index];
                      final time = event['time'] as Duration;
                      final color = event['color'] as Color;

                      return Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () async {
                            Navigator.of(sheetContext).pop();
                            await _seekActiveBottomPlaybackTo(time);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(event['icon'] as IconData, color: color, size: 22),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: 54,
                                  child: Text(
                                    event['timeLabel'] as String,
                                    style: TextStyle(
                                      color: _mcText,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        event['title'] as String,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: _mcText,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '${event['subtitle']}${_s(event['description']).isEmpty ? '' : ' · ${event['description']}'}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: _mcSub,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right_rounded, color: _mcSub),
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
          ),
        );
      },
    );
  }

  Future<void> _openBottomMatchNotesSheet() async {
    final position = _currentBottomPlaybackPosition();
    final noteCtrl = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            Future<void> saveNote() async {
              final text = noteCtrl.text.trim();
              if (text.isEmpty) {
                Get.snackbar('Заметка', 'Введите текст заметки');
                return;
              }

              final note = {
                'time': position,
                'timeLabel': _formatMatchPlayerTime(position),
                'text': text,
                'createdAt': DateTime.now().toIso8601String(),
              };

              setState(() {
                _localVideoNotes.insert(0, note);
                final line = '[${note['timeLabel']}] $text';
                final old = _coachCommentCtrl.text.trim();
                _coachCommentCtrl.text = old.isEmpty ? line : '$old\n$line';
              });

              Navigator.of(sheetContext).pop();
              await _saveAll();
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 18,
                  right: 18,
                  top: 16,
                  bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
                ),
                child: SizedBox(
                  height: min(MediaQuery.of(sheetContext).size.height * .72, 620.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Заметка к видео',
                                  style: AppTypography.sectionTitle(color: _mcText),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Текущий момент: ${_formatMatchPlayerTime(position)}',
                                  style: AppTypography.commentMeta(color: _mcSub),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: noteCtrl,
                        minLines: 3,
                        maxLines: 5,
                        autofocus: true,
                        style: AppTypography.commentText(color: _mcText),
                        decoration: InputDecoration(
                          hintText: 'Например: плохо закрыли правый фланг после потери...',
                          hintStyle: AppTypography.formHint(color: _mcSub),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: _mcLine),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: _mcLine),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: _mcBlue, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 44,
                        child: ElevatedButton.icon(
                          onPressed: saveNote,
                          icon: const Icon(Icons.save_rounded, size: 18),
                          label: const Text('Сохранить заметку'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _mcBlue,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            textStyle: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Text(
                            'Быстрые заметки',
                            style: AppTypography.subsectionTitle(color: _mcText),
                          ),
                          const Spacer(),
                          if (_localVideoNotes.isNotEmpty)
                            Text(
                              '${_localVideoNotes.length}',
                              style: TextStyle(
                                color: _mcSub,
                                fontSize: 10.8,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: _localVideoNotes.isEmpty
                            ? Container(
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: _mcLine),
                                ),
                                child: Text(
                                  'Пока нет быстрых заметок в этой сессии',
                                  style: AppTypography.emptyText(color: _mcSub),
                                ),
                              )
                            : ListView.separated(
                                itemCount: _localVideoNotes.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 8),
                                itemBuilder: (_, index) {
                                  final note = _localVideoNotes[index];
                                  final time = note['time'] as Duration;
                                  return Material(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(12),
                                      onTap: () async {
                                        Navigator.of(sheetContext).pop();
                                        await _seekActiveBottomPlaybackTo(time);
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              note['timeLabel'] as String,
                                              style: AppTypography.commentMeta(color: _mcBlue),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                note['text'] as String,
                                                style: AppTypography.commentText(color: _mcText),
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
                ),
              ),
            );
          },
        );
      },
    );

    noteCtrl.dispose();
  }


  Widget _analysisVideoEmptyState({required bool tactical}) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _mcControl,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: .18,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: CustomPaint(
                  painter: _MatchPitchNetworkPainter(
                    vertical: true,
                    livePositions: _liveAiPositions,
                    liveTrails: _liveAiTrails,
                    liveSpeeds: _liveAiSpeedsKmh,
                  ),
                ),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.10),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      tactical ? Icons.account_tree_outlined : Icons.video_file_outlined,
                      color: _mcOnDark,
                      size: 22,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    tactical ? 'Тактическое видео не загружено' : 'Видео матча не загружено',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _mcOnDark,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Загрузите запись во вкладке «Видео»',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _mcOnDarkSub,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 10,
            right: 10,
            bottom: 8,
            child: SizedBox(
              height: 30,
              child: ElevatedButton.icon(
                onPressed: uploadingVideo ? null : () => _showUploadVideoSheet('full'),
                icon: const Icon(Icons.cloud_upload_outlined, size: 16),
                label: const Text('Загрузить видео'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: _mcControl,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  textStyle: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _analysisVideoPane({required bool tactical}) {
    if (!tactical) {
      return _analysisMatchPlayersPane();
    }

    final video = _firstUploadedMatchVideo(tactical: tactical);
    final url = _analysisVideoUrl(video);

    if (url == null || url.isEmpty) {
      return _analysisVideoEmptyState(tactical: tactical);
    }

    final title = tactical ? 'Тактический ракурс' : _formatVideoTitle(_s(video?['file_name']), 'Видео матча');

    if (!tactical) {
      return _analysisMatchPlayersPane();
    }

    if (tactical) {
      final params = _analysisParamsForVideo(video ?? <String, dynamic>{}, fallbackUrl: url);
      return Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: _mcControl,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            AdvancedVideoAnalysisScreen(
              params: params,
              embedded: true,
              modalWindow: false,
              hideControls: true,
              externalPlaybackController: _embeddedAiPlayback,
              onAnalysisFrame: _onLiveAiFrame,
              onStatusChanged: _onLiveAiStatus,
            ),
            Positioned(
              right: 10,
              top: 10,
              child: InkWell(
                onTap: () => showAdvancedVideoAnalysisWindow(
                  context,
                  params,
                  externalPlaybackController: _embeddedAiPlayback,
                  hideControls: false,
                ),
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.94),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(.16), blurRadius: 18, offset: const Offset(0, 8))],
                  ),
                  child: Icon(Icons.open_in_full_rounded, color: _mcText, size: 16),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final params = _analysisParamsForVideo(video ?? <String, dynamic>{}, fallbackUrl: url);
    _activeAnalysisVideoKey ??= _analysisVideoControllerKey(url, tactical: false);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _mcControl,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          AdvancedVideoAnalysisScreen(
            params: params,
            embedded: true,
            modalWindow: false,
            hideControls: true,
            connectAi: false,
            showAiOverlay: false,
            externalPlaybackController: _embeddedMainVideoPlayback,
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(.08),
                      Colors.transparent,
                      Colors.black.withOpacity(.52),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 10,
            top: 10,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD64545),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'ВИДЕО',
                    style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 170),
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 10,
            top: 10,
            child: InkWell(
              onTap: () => _watchVideo(url, title: title),
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.94),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(.16), blurRadius: 18, offset: const Offset(0, 8))],
                ),
                child: Icon(Icons.open_in_full_rounded, color: _mcText, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _analysisMvpBlock() {
    final row = _bestPlayerRow();
    final name = row == null ? 'Нет данных ТТД' : _playerName(row);
    final photo = row == null ? null : _playerPhotoUrl(row);
    final rating = _playerRating(row);
    final keyStats = _playerKeyTtdStats(row, maxItems: 7);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 62,
              height: 62,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: _mcLine),
              ),
              child: photo == null
                  ? Icon(Icons.person_rounded, color: _mcSub, size: 42)
                  : Image.network(
                      photo,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(Icons.person_rounded, color: _mcSub, size: 42),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _mcText,
                  fontSize: 12.5,
                  height: 1.15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(color: _mcBlue, borderRadius: BorderRadius.circular(4)),
              child: Text(
                rating,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Ключевая статистика по ТТД',
          style: TextStyle(color: _mcText, fontSize: 11, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 5),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final stat in keyStats)
                _analysisKeyStat(stat[0], stat[1]),
            ],
          ),
        ),
        SizedBox(
          height: 30,
          child: OutlinedButton(
            onPressed: row == null ? null : () => _openMatchDetailTab(1),
            style: OutlinedButton.styleFrom(
              foregroundColor: _mcText,
              side: BorderSide(color: _mcLine),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              textStyle: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600),
            ),
            child: const Text('Открыть ТТД игрока'),
          ),
        ),
      ],
    );
  }

  Widget _analysisKeyStat(String label, String value) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(children: [Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _mcSub, fontSize: 10.5, fontWeight: FontWeight.w600))), const SizedBox(width: 8), Text(value, style: TextStyle(color: _mcText, fontSize: 10.5, fontWeight: FontWeight.w600))]));

  Widget _analysisEventTimeline({required bool wide}) {
    final liveRows = _liveAiEvents.map((e) => _analysisEventLine(
          _s(e['minute']),
          e['icon'] is IconData ? e['icon'] as IconData : Icons.bolt_rounded,
          '${_s(e['title'])}${_s(e['subtitle']).isNotEmpty ? ' · ${_s(e['subtitle'])}' : ''}',
          e['color'] is Color ? e['color'] as Color : _mcGreen,
        )).toList();
    final rows = liveRows.isNotEmpty ? liveRows : _timelineRows();
    final list = rows.take(wide ? 8 : 5).toList();
    if (list.isEmpty) {
      return _inlineAiWaiting(
        icon: Icons.timeline_rounded,
        text: 'Событий пока нет. Запустите ИИ-видеоповтор или добавьте эпизоды матча.',
      );
    }
    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: list.map((e) => Expanded(child: e)).toList(),
      );
    }
    final split = (list.length / 2).ceil();
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: list.take(split).map((e) => Expanded(child: e)).toList(),
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: list.skip(split).map((e) => Expanded(child: e)).toList(),
          ),
        ),
      ],
    );
  }

  Widget _analysisEventLine(String minute, IconData icon, String title, Color color) => Row(children: [SizedBox(width: 40, child: Text(minute, style: TextStyle(color: _mcText, fontSize: 11, fontWeight: FontWeight.w600))), Icon(icon, color: color, size: 15), const SizedBox(width: 8), Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _mcSub, fontSize: 10.8, fontWeight: FontWeight.w600)))]);

  Widget _analysisCoachNotes() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Row(children: [_analysisNoteTab('Общие', true), _analysisNoteTab('Атака', false), _analysisNoteTab('Оборона', false), _analysisNoteTab('Стандарты', false)]), const SizedBox(height: 10), Expanded(child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: _mcLine.withOpacity(.65))), child: _coachCommentCtrl.text.trim().isEmpty ? _inlineAiWaiting(icon: Icons.edit_note_rounded, text: 'Заметок тренера пока нет.') : Text(_coachCommentCtrl.text.trim(), maxLines: 7, overflow: TextOverflow.ellipsis, style: TextStyle(color: _mcSub, fontSize: 10.5, height: 1.35, fontWeight: FontWeight.w600)))), if (_coachCommentCtrl.text.trim().isNotEmpty) ...[const SizedBox(height: 8), Align(alignment: Alignment.centerRight, child: Text('Сохранено в матче', style: TextStyle(color: _mcSub, fontSize: 9.5, fontWeight: FontWeight.w600)))]]);

  Widget _analysisNoteTab(String text, bool active) => Expanded(child: Container(height: 22, alignment: Alignment.center, decoration: BoxDecoration(border: Border(bottom: BorderSide(color: active ? _mcGreen : _mcLine, width: active ? 2 : 1))), child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: active ? _mcGreen : _mcSub, fontSize: 9.5, fontWeight: FontWeight.w600))));

  Widget _analysisConnections() {
    final names = _analysisPlayerNames();
    final pairs = [[names[0], names.length > 1 ? names[1] : 'Седько', '24'], [names.length > 2 ? names[2] : 'Гречихо', names.length > 3 ? names[3] : 'Лисакович', '19'], [names.length > 4 ? names[4] : 'Пащенко', names.length > 5 ? names[5] : 'Коваль', '17']];
    return Column(children: [...pairs.map((p) => Expanded(child: Row(children: [_analysisNumberCircle(p[0].toString().hashCode.abs() % 90 + 1), const SizedBox(width: 6), Expanded(child: Text(p[0], maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: _mcText, fontSize: 10.5, fontWeight: FontWeight.w600))), Icon(Icons.compare_arrows_rounded, color: _mcSub, size: 16), Expanded(child: Text(p[1], maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right, style: TextStyle(color: _mcText, fontSize: 10.5, fontWeight: FontWeight.w600))), const SizedBox(width: 8), Text(p[2], style: TextStyle(color: _mcSub, fontSize: 10.5, fontWeight: FontWeight.w600))]))), Align(alignment: Alignment.centerLeft, child: Text('Все связи  ›', style: TextStyle(color: _mcSub, fontSize: 10.5, fontWeight: FontWeight.w600)))]);
  }

  Widget _analysisNumberCircle(int number) => Container(width: 22, height: 22, alignment: Alignment.center, decoration: BoxDecoration(shape: BoxShape.circle, color: _mcBlue, border: Border.all(color: Colors.white.withOpacity(.5))), child: Text('$number', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600)));

  Widget _matchAnalysisBottomTimeline() {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: _mcPlayerBar,
        border: Border(top: BorderSide(color: _mcPlayerLine)),
      ),
      child: Row(
        children: [
          const Spacer(),
          InkWell(
            onTap: () => _openMatchLive(video: _primaryAiVideo()),
            borderRadius: BorderRadius.circular(6),
            child: _analysisBottomButton(
              'Онлайн-матч',
              icon: Icons.sensors_rounded,
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: _openMatchRecordingAnalysis,
            borderRadius: BorderRadius.circular(6),
            child: _analysisBottomButton(
              'Анализ записи',
              icon: Icons.auto_awesome_motion_rounded,
              primary: true,
            ),
          ),
          const SizedBox(width: 18),
        ],
      ),
    );
  }


  Widget _matchAnalysisVideoBottomTimeline() {
    final source = _activeMatchVideoSourceForBottom();
    final compactTimeline =
        (MediaQuery.maybeOf(context)?.size.width ?? 1200) < 1100;

    if (source == null) {
      return Container(
        height: 64,
        decoration: BoxDecoration(
          color: _mcPlayerBar,
          border: Border(top: BorderSide(color: _mcPlayerLine)),
        ),
        child: Row(
          children: [
            const SizedBox(width: 24),
            Icon(Icons.video_file_outlined, color: _mcPlayerSub, size: 22),
            const SizedBox(width: 10),
            Text('Видео матча не загружено', style: TextStyle(color: _mcPlayerSub, fontSize: 11.5, fontWeight: FontWeight.w600)),
            const Spacer(),
            InkWell(
              onTap: () => _openMatchLive(),
              borderRadius: BorderRadius.circular(6),
              child: _analysisBottomButton('Онлайн-матч', icon: Icons.sensors_rounded),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: _openMatchRecordingAnalysis,
              borderRadius: BorderRadius.circular(6),
              child: _analysisBottomButton(
                'Анализ записи',
                icon: Icons.auto_awesome_motion_rounded,
                primary: true,
              ),
            ),
            const SizedBox(width: 18),
          ],
        ),
      );
    }

    final listenables = <Listenable>[
      _embeddedAiPlayback,
    ];

    return AnimatedBuilder(
      animation: Listenable.merge(listenables),
      builder: (context, _) {
        final duration = _currentBottomPlaybackDuration();
        final position = _currentBottomPlaybackPosition();
        final hasDuration = duration.inMilliseconds > 0;
        final progress = hasDuration
            ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0).toDouble()
            : 0.0;
        final ready = _isBottomPlaybackReady();
        final playing = _isBottomPlaybackPlaying();
        final statusText = _bottomPlaybackStatusText();

        return Container(
          height: 64,
          decoration: BoxDecoration(
            color: _mcPlayerBar,
            border: Border(top: BorderSide(color: _mcPlayerLine)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 220,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _aiPlayerIconButton(icon: Icons.fast_rewind_rounded, onTap: ready ? () { _seekBottomMatchVideoRelative(-10); } : null),
                    const SizedBox(width: 12),
                    _aiPlayerIconButton(
                      icon: playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      large: true,
                      filled: true,
                      active: playing,
                      // Play разрешён сразу: если видео/AI ещё грузятся, они стартуют после canplay.
                      onTap: _toggleBottomMatchVideo,
                    ),
                    const SizedBox(width: 12),
                    _aiPlayerIconButton(icon: Icons.fast_forward_rounded, onTap: ready ? () { _seekBottomMatchVideoRelative(10); } : null),
                    const SizedBox(width: 14),
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () { _cycleBottomMatchVideoSpeed(); },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
                        child: Text(
                          '${_matchPlaybackSpeed.toStringAsFixed(_matchPlaybackSpeed == _matchPlaybackSpeed.roundToDouble() ? 0 : 2)}x',
                          style: TextStyle(color: _mcPlayerSub, fontSize: 11.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Text(_formatMatchPlayerTime(position), style: TextStyle(color: _mcPlayerSub, fontSize: 10.5, fontWeight: FontWeight.w600)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                      ),
                      child: Slider(
                        value: progress,
                        min: 0,
                        max: 1,
                        onChanged: hasDuration ? (newValue) { _seekBottomMatchVideoToFraction(newValue); } : null,
                        activeColor: _mcGreen,
                        inactiveColor: const Color(0xFFE5E7EB),
                      ),
                    ),
                    if (!ready || _bottomVideoLoading)
                      Padding(
                        padding: const EdgeInsets.only(left: 3, top: 0),
                        child: Text(
                          statusText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: _mcPlayerSub.withOpacity(.82), fontSize: 9.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(hasDuration ? _formatMatchPlayerTime(duration) : '00:00', style: TextStyle(color: _mcPlayerSub, fontSize: 10.5, fontWeight: FontWeight.w600)),
              const SizedBox(width: 14),
              InkWell(
                onTap: () => _openMatchLive(video: source),
                borderRadius: BorderRadius.circular(6),
                child: _analysisBottomButton(
                  'Онлайн-матч',
                  icon: Icons.sensors_rounded,
                  compact: compactTimeline,
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: _openMatchRecordingAnalysis,
                borderRadius: BorderRadius.circular(6),
                child: _analysisBottomButton(
                  'Анализ записи',
                  icon: Icons.auto_awesome_motion_rounded,
                  primary: true,
                  compact: compactTimeline,
                ),
              ),
              const SizedBox(width: 14),
              IconButton(
                tooltip: 'Во весь экран',
                onPressed: _openActiveMatchVideoFullscreen,
                icon: Icon(Icons.fullscreen_rounded, color: _mcPlayerText, size: 24),
              ),
              const SizedBox(width: 10),
            ],
          ),
        );
      },
    );
  }



  Widget _aiMatchReviewBottomTimeline() {
    final position = _aiReviewPlayback.position;
    final duration = _aiReviewPlayback.duration;
    final hasDuration = duration.inMilliseconds > 0;
    final progress = hasDuration
        ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0).toDouble()
        : 0.0;
    final disabled = !_aiReviewPlayback.attached || !_aiReviewPlayback.isReady;
    final compactTimeline =
        (MediaQuery.maybeOf(context)?.size.width ?? 1200) < 1100;

    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: _mcPlayerBar,
        border: Border(top: BorderSide(color: _mcPlayerLine)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 220,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _aiPlayerIconButton(icon: Icons.fast_rewind_rounded, onTap: disabled ? null : () { _aiReviewPlayback.seekRelative(-10); }),
                const SizedBox(width: 12),
                _aiPlayerIconButton(
                  icon: _aiReviewPlayback.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  large: true,
                  filled: true,
                  active: _aiReviewPlayback.isPlaying,
                  onTap: disabled ? null : () { _aiReviewPlayback.togglePlayPause(); },
                ),
                const SizedBox(width: 12),
                _aiPlayerIconButton(icon: Icons.fast_forward_rounded, onTap: disabled ? null : () { _aiReviewPlayback.seekRelative(10); }),
                const SizedBox(width: 14),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: disabled ? null : () { _aiReviewPlayback.cycleSpeed(); },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
                    child: Text(
                      '${_aiReviewPlayback.speed.toStringAsFixed(_aiReviewPlayback.speed == _aiReviewPlayback.speed.roundToDouble() ? 0 : 2)}x',
                      style: TextStyle(color: disabled ? _mcPlayerSub.withOpacity(.45) : _mcPlayerSub, fontSize: 11.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Text(_formatMatchPlayerTime(position), style: TextStyle(color: _mcPlayerSub, fontSize: 10.5, fontWeight: FontWeight.w600)),
          const SizedBox(width: 10),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 3,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: Slider(
                value: progress,
                min: 0,
                max: 1,
                onChanged: disabled || !hasDuration ? null : (value) { _aiReviewPlayback.seekToFraction(value); },
                activeColor: _mcGreen,
                inactiveColor: const Color(0xFFE5E7EB),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(_formatMatchPlayerTime(duration), style: TextStyle(color: _mcPlayerSub, fontSize: 10.5, fontWeight: FontWeight.w600)),
          const SizedBox(width: 14),
          InkWell(
            onTap: () => _openMatchLive(video: _primaryAiVideo()),
            borderRadius: BorderRadius.circular(6),
            child: _analysisBottomButton(
              'Онлайн-матч',
              icon: Icons.sensors_rounded,
              compact: compactTimeline,
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: _openMatchRecordingAnalysis,
            borderRadius: BorderRadius.circular(6),
            child: _analysisBottomButton(
              'Анализ записи',
              icon: Icons.auto_awesome_motion_rounded,
              primary: true,
              compact: compactTimeline,
            ),
          ),
          const SizedBox(width: 14),
          IconButton(
            tooltip: 'Во весь экран',
            onPressed: disabled ? null : () => _aiReviewPlayback.toggleFullscreen(),
            icon: Icon(Icons.fullscreen_rounded, color: disabled ? _mcPlayerSub.withOpacity(.45) : _mcPlayerText, size: 24),
          ),
          const SizedBox(width: 10),
        ],
      ),
    );
  }



  Widget _aiPlayerIconButton({
    required IconData icon,
    required VoidCallback? onTap,
    bool large = false,
    bool filled = false,
    bool active = false,
  }) {
    final disabled = onTap == null;

    // Светлая панель повторяет управление Tracker: зелёный акцент только
    // у главного действия, остальные кнопки остаются нейтральными.
    if (large && filled) {
      final label = active ? 'PAUSE' : 'PLAY';
      final backgroundColor = disabled
          ? const Color(0xFFF2F4F3)
          : active
              ? _mcGreen
              : const Color(0xFFEAF8F1);
      final foregroundColor = disabled
          ? _mcPlayerSub.withOpacity(.42)
          : active
              ? Colors.white
              : _mcGreen;

      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          width: active ? 108 : 100,
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: backgroundColor,
            border: Border.all(
              color: active ? _mcGreen : const Color(0xFFD8EEE2),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: foregroundColor, size: 22),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: foregroundColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: .65,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final size = large ? 40.0 : 32.0;
    final backgroundColor = disabled
        ? const Color(0xFFF5F6F6)
        : active
            ? _mcGreen
            : const Color(0xFFF2F4F3);
    final iconColor = disabled
        ? _mcPlayerSub.withOpacity(.38)
        : active
            ? Colors.white
            : _mcPlayerText;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: backgroundColor,
          border: Border.all(
            color: active ? _mcGreen : _mcPlayerLine,
          ),
        ),
        child: Icon(
          icon,
          color: iconColor,
          size: large ? 25 : 20,
        ),
      ),
    );
  }


  String _formatMatchPlayerTime(Duration value) {
    final totalSeconds = value.inSeconds;
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }


  Widget _analysisBottomButton(
    String text, {
    IconData? icon,
    bool primary = false,
    bool compact = false,
  }) =>
      Container(
        height: 32,
        alignment: Alignment.center,
        padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12),
        decoration: BoxDecoration(
          color: primary ? _mcGreen : const Color(0xFFEAF8F1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: primary ? _mcGreen : const Color(0xFFD8EEE2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: primary ? Colors.white : _mcGreen, size: 15),
              if (!compact) const SizedBox(width: 6),
            ],
            if (!compact)
              Text(
                text,
                style: TextStyle(
                  color: primary ? Colors.white : _mcGreen,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final title = _s(match?["title"]).isEmpty ? "Матч" : _s(match?["title"]);
    final competition = _s(match?["competition_name"]);
    final date = _s(match?["match_date"]).isEmpty
        ? _s(match?["info_date"])
        : _s(match?["match_date"]);
    final opponent =
        _s(match?["opponent"]).isEmpty ? "Соперник" : _s(match?["opponent"]);
    final ourScore =
        _s(match?["our_score"]).isEmpty ? "0" : _s(match?["our_score"]);
    final oppScore = _s(match?["opponent_score"]).isEmpty
        ? "0"
        : _s(match?["opponent_score"]);
    final score = "$ourScore:$oppScore";

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final useWorkspace = width >= 720 || widget.embedded;
        final isPhone = width < 600 && !widget.embedded;
        final compact = width < 980;

        final body = loading
            ? Container(
                color: Colors.white,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: useWorkspace ? _mcGreen : primary),
                      const SizedBox(height: 16),
                      Text(
                        "Загрузка данных матча...",
                        style: TextStyle(
                          color: useWorkspace ? _mcSub : textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : widget.editorOnly
                ? _buildEmbeddedEditorOnlySurface()
                : widget.documentsOnly
                    ? _buildEmbeddedDocumentsOnlySurface()
                    : widget.videoOnly
                        ? _buildEmbeddedVideoOnlySurface()
                        : useWorkspace
                    ? _buildMatchAnalysisWorkspace(
                        title: title,
                        opponent: opponent,
                        date: date,
                        competition: competition,
                        score: score,
                      )
                    : Column(
                    children: [
                      _buildCmrTopBar(
                        compact: compact,
                        title: title,
                        opponent: opponent,
                        date: date,
                        competition: competition,
                        showBackButton: !widget.embedded,
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            if (!isPhone) _buildCmrCompactNav(),
                            Expanded(child: _buildActiveTabContent()),
                          ],
                        ),
                      ),
                    ],
                  );

        final baseTheme = Theme.of(context);
        final themedBody = Theme(
          data: baseTheme.copyWith(
            textTheme: baseTheme.textTheme.apply(
              fontFamily: AppTypography.fontFamily,
              bodyColor: textPrimary,
              displayColor: textPrimary,
            ),
            primaryTextTheme: baseTheme.primaryTextTheme.apply(
              fontFamily: AppTypography.fontFamily,
              bodyColor: textPrimary,
              displayColor: textPrimary,
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(child: body),
              if (_rightPanelMode != _MatchRightPanelMode.none && !isPhone)
                Positioned(
                  top: 0,
                  right: 0,
                  bottom: 0,
                  width: min(520.0, max(390.0, width * .46)),
                  child: _buildMatchProfileRightPanel(),
                ),
            ],
          ),
        );

        if (widget.embedded) {
          return Container(
            color: Colors.white,
            child: themedBody,
          );
        }

        return Theme(
          data: baseTheme.copyWith(
            textTheme: baseTheme.textTheme.apply(
              fontFamily: AppTypography.fontFamily,
            ),
            primaryTextTheme: baseTheme.primaryTextTheme.apply(
              fontFamily: AppTypography.fontFamily,
            ),
          ),
          child: Scaffold(
            backgroundColor: Colors.white,
            body: themedBody,
            bottomNavigationBar:
                isPhone ? _buildMatchMobileBottomMenu(context) : null,
          ),
        );
      },
    );
  }
}


class _MatchProfileBrandDots extends StatelessWidget {
  const _MatchProfileBrandDots();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        3,
        (index) => Padding(
          padding: EdgeInsets.only(left: index == 0 ? 0 : 4),
          child: Container(
            width: 5.5,
            height: 5.5,
            decoration: BoxDecoration(
              color: index == 1 ? const Color(0xFF0B8F55) : const Color(0xFFB8D9C6),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}



class _MatchHistogramPainter extends CustomPainter {
  const _MatchHistogramPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final left = 36.0, top = 14.0, bottom = size.height - 28, right = size.width - 10;
    final chartH = bottom - top, chartW = right - left;
    final grid = Paint()..color = const Color(0xFFD8E2EA)..strokeWidth = 1;
    final axis = Paint()..color = const Color(0xFF64748B)..strokeWidth = 1.2;
    for (int i = 0; i <= 5; i++) canvas.drawLine(Offset(left, top + chartH * i / 5), Offset(right, top + chartH * i / 5), grid);
    for (int i = 0; i <= 6; i++) canvas.drawLine(Offset(left + chartW * i / 6, top), Offset(left + chartW * i / 6, bottom), Paint()..color = const Color(0xFFEAF1F7));
    canvas.drawLine(Offset(left, top - 2), Offset(left, bottom), axis);
    canvas.drawLine(Offset(left, bottom), Offset(right + 2, bottom), axis);
    final tp = TextPainter(textDirection: TextDirection.ltr);
    void label(String text, Offset o, {double fs = 9}) { tp.text = TextSpan(text: text, style: TextStyle(color: const Color(0xFF64748B), fontSize: fs, fontWeight: FontWeight.w600)); tp.layout(); tp.paint(canvas, o - Offset(tp.width / 2, tp.height / 2)); }
    for (int i = 0; i <= 4; i++) label('${i * 200}', Offset(18, bottom - chartH * i / 4));
    const labs = ['-5','-2.5','0','2.5','5'];
    for (int i = 0; i < labs.length; i++) label(labs[i], Offset(left + chartW * i / (labs.length - 1), size.height - 13));
    const n = 72;
    final bar = Paint()..color = const Color(0xFF159DE8);
    final rnd = Random(4);
    for (int i = 0; i < n; i++) {
      final xNorm = (i - n * .54) / (n * .12);
      final peak = exp(-xNorm * xNorm / 2);
      final tail = max(0.0, 1 - (i - n * .54).abs() / (n * .55)) * .18;
      final v = (peak * .94 + tail + rnd.nextDouble() * .035).clamp(.02, 1.0);
      final h = chartH * v * .86;
      canvas.drawRect(Rect.fromLTWH(left + i * chartW / n, bottom - h, chartW / n * .82, h), bar);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MatchStackedBarsPainter extends CustomPainter {
  const _MatchStackedBarsPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final left = 38.0, top = 18.0, bottom = size.height - 32, right = size.width - 8;
    final h = bottom - top, w = right - left;
    final grid = Paint()..color = const Color(0xFFD8E2EA)..strokeWidth = 1;
    for (int i = 0; i <= 5; i++) canvas.drawLine(Offset(left, top + h * i / 5), Offset(right, top + h * i / 5), grid);
    canvas.drawLine(Offset(left, top), Offset(left, bottom), Paint()..color = const Color(0xFF64748B)..strokeWidth = 1.2);
    canvas.drawLine(Offset(left, bottom), Offset(right, bottom), Paint()..color = const Color(0xFF64748B)..strokeWidth = 1.2);
    const vals = [52, 48, 54, 59, 47, 40];
    const labels = ['0-15','15-30','30-45','45-60','60-75','75-90'];
    final barW = w / vals.length * .48;
    final tp = TextPainter(textDirection: TextDirection.ltr, textAlign: TextAlign.center);
    for (int i = 0; i < vals.length; i++) {
      final x = left + w * (i + .5) / vals.length - barW / 2;
      final redH = h * vals[i] / 100;
      final greenH = h - redH;
      canvas.drawRect(Rect.fromLTWH(x, bottom - redH, barW, redH), Paint()..color = const Color(0xFFA9333E));
      canvas.drawRect(Rect.fromLTWH(x, top, barW, greenH), Paint()..color = const Color(0xFF0EA63B));
      for (final pair in [[vals[i], bottom - redH / 2], [100 - vals[i], top + greenH / 2]]) { tp.text = TextSpan(text: '${pair[0]}%', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)); tp.layout(); tp.paint(canvas, Offset(x + barW / 2 - tp.width / 2, (pair[1] as num).toDouble() - tp.height / 2)); }
      tp.text = TextSpan(text: labels[i], style: TextStyle(color: const Color(0xFF64748B), fontSize: 9, fontWeight: FontWeight.w600)); tp.layout(); tp.paint(canvas, Offset(x + barW / 2 - tp.width / 2, size.height - 18));
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MatchLoadBarsPainter extends CustomPainter {
  const _MatchLoadBarsPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final left = 34.0, top = 18.0, bottom = size.height - 30, right = size.width - 10;
    final h = bottom - top, w = right - left;
    final grid = Paint()..color = const Color(0xFFD8E2EA)..strokeWidth = 1;
    for (int i = 0; i <= 5; i++) canvas.drawLine(Offset(left, top + h * i / 5), Offset(right, top + h * i / 5), grid);
    canvas.drawLine(Offset(left, bottom), Offset(right, bottom), Paint()..color = const Color(0xFF64748B));
    canvas.drawLine(Offset(left, top), Offset(left, bottom), Paint()..color = const Color(0xFF64748B));
    final colors = [const Color(0xFF18A9D4), const Color(0xFF7BC56B), const Color(0xFFE7C13C), const Color(0xFFE45B45), const Color(0xFF8B3DB6)];
    const vals = [78,64,82,91,72,68];
    const labels = ['0-15','15-30','30-45','45-60','60-75','75-90'];
    final barW = w / vals.length * .46;
    final tp = TextPainter(textDirection: TextDirection.ltr);
    for (int i = 0; i < vals.length; i++) {
      final x = left + w * (i + .5) / vals.length - barW / 2;
      var y = bottom;
      for (int j = 0; j < colors.length; j++) { final hh = h * vals[i] / 100 / colors.length * (.72 + .1 * ((i + j) % 3)); y -= hh; canvas.drawRect(Rect.fromLTWH(x, y, barW, hh - 1), Paint()..color = colors[j].withOpacity(.82)); }
      tp.text = TextSpan(text: labels[i], style: TextStyle(color: const Color(0xFF64748B), fontSize: 9, fontWeight: FontWeight.w600)); tp.layout(); tp.paint(canvas, Offset(x + barW / 2 - tp.width / 2, size.height - 18));
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MatchPitchNetworkPainter extends CustomPainter {
  final bool vertical;
  final Map<int, Offset> livePositions;
  final Map<int, List<Offset>> liveTrails;
  final Map<int, double> liveSpeeds;

  const _MatchPitchNetworkPainter({
    this.vertical = false,
    this.livePositions = const {},
    this.liveTrails = const {},
    this.liveSpeeds = const {},
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (vertical || size.height > size.width * 1.12) {
      _paintVertical(canvas, size);
      return;
    }

    final field = Rect.fromLTWH(6, 8, size.width - 12, size.height - 16);
    _paintField(canvas, field, verticalMode: false);
    if (livePositions.isNotEmpty) {
      _paintLivePlayers(canvas, field);
      return;
    }

    Offset p(double x, double y) => Offset(field.left + field.width * x, field.top + field.height * y);
    final pts = <int, Offset>{
      77: p(.24, .32),
      10: p(.47, .35),
      25: p(.58, .20),
      8: p(.70, .34),
      21: p(.83, .28),
      6: p(.36, .54),
      4: p(.51, .55),
      3: p(.67, .60),
      55: p(.44, .72),
      2: p(.75, .72),
      30: p(.57, .78),
    };
    _paintStaticConnections(canvas, pts);
    _paintPlayerDots(canvas, pts, 10, 8.5);
  }

  void _paintVertical(Canvas canvas, Size size) {
    final field = Rect.fromLTWH(6, 8, size.width - 12, size.height - 16);
    _paintField(canvas, field, verticalMode: true);
    if (livePositions.isNotEmpty) {
      _paintLivePlayers(canvas, field);
      return;
    }

    Offset p(double x, double y) => Offset(field.left + field.width * y, field.top + field.height * x);
    final pts = <int, Offset>{
      77: p(.24, .32),
      10: p(.47, .35),
      25: p(.58, .20),
      8: p(.70, .34),
      21: p(.83, .28),
      6: p(.36, .54),
      4: p(.51, .55),
      3: p(.67, .60),
      55: p(.44, .72),
      2: p(.75, .72),
      30: p(.57, .78),
    };
    _paintStaticConnections(canvas, pts);
    final dotRadius = min(10.0, max(7.0, min(size.width, size.height) * .046));
    _paintPlayerDots(canvas, pts, dotRadius, 8.2);
  }

  void _paintField(Canvas canvas, Rect field, {required bool verticalMode}) {
    canvas.drawRect(field, Paint()..color = const Color(0xFF08751B));
    final stripeCount = verticalMode ? 11 : 9;
    for (int i = 0; i < stripeCount; i++) {
      canvas.drawRect(
        Rect.fromLTWH(field.left, field.top + field.height * i / stripeCount, field.width, field.height / (stripeCount * 2)),
        Paint()..color = const Color(0xFFFFFFFF).withOpacity(.08),
      );
    }

    final line = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.35;
    canvas.drawRect(field, line);

    if (verticalMode) {
      canvas.drawLine(Offset(field.left, field.center.dy), Offset(field.right, field.center.dy), line);
      canvas.drawCircle(field.center, min(field.width, field.height) * .22, line);
      final penaltyW = field.width * .68;
      final penaltyH = field.height * .15;
      final sixW = field.width * .38;
      final sixH = field.height * .07;
      canvas.drawRect(Rect.fromLTWH(field.center.dx - penaltyW / 2, field.top, penaltyW, penaltyH), line);
      canvas.drawRect(Rect.fromLTWH(field.center.dx - penaltyW / 2, field.bottom - penaltyH, penaltyW, penaltyH), line);
      canvas.drawRect(Rect.fromLTWH(field.center.dx - sixW / 2, field.top, sixW, sixH), line);
      canvas.drawRect(Rect.fromLTWH(field.center.dx - sixW / 2, field.bottom - sixH, sixW, sixH), line);
    } else {
      canvas.drawLine(Offset(field.center.dx, field.top), Offset(field.center.dx, field.bottom), line);
      canvas.drawCircle(field.center, field.height * .14, line);
      canvas.drawRect(Rect.fromLTWH(field.left, field.top + field.height * .28, field.width * .16, field.height * .44), line);
      canvas.drawRect(Rect.fromLTWH(field.right - field.width * .16, field.top + field.height * .28, field.width * .16, field.height * .44), line);
    }
  }

  void _paintStaticConnections(Canvas canvas, Map<int, Offset> pts) {
    final pass = Paint()
      ..color = const Color(0xFFEBD33D).withOpacity(.86)
      ..strokeWidth = 1.55;
    for (final pair in const [
      [77, 10], [10, 25], [25, 21], [10, 8], [8, 21], [77, 6], [6, 4],
      [4, 3], [3, 2], [4, 55], [55, 30], [30, 2], [10, 4], [6, 10],
    ]) {
      if (pts[pair[0]] != null && pts[pair[1]] != null) canvas.drawLine(pts[pair[0]]!, pts[pair[1]]!, pass);
    }
  }

  void _paintLivePlayers(Canvas canvas, Rect field) {
    final trailPaint = Paint()
      ..color = const Color(0xFF00A750).withOpacity(.46)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    Offset mapPoint(Offset p) => Offset(field.left + field.width * p.dx, field.top + field.height * p.dy);

    for (final entry in liveTrails.entries) {
      final points = entry.value.map(mapPoint).toList();
      if (points.length < 2) continue;
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, trailPaint);
    }

    final tp = TextPainter(textDirection: TextDirection.ltr, textAlign: TextAlign.center);
    for (final entry in livePositions.entries) {
      final id = entry.key;
      final pos = mapPoint(entry.value);
      final speed = liveSpeeds[id] ?? 0.0;
      final color = speed >= 22 ? const Color(0xFFFFB000) : const Color(0xFF00A750);
      final radius = speed >= 22 ? 7.2 : 6.2;
      canvas.drawCircle(pos, radius + 2.4, Paint()..color = Colors.white.withOpacity(.94));
      canvas.drawCircle(pos, radius, Paint()..color = color);
      final outline = Paint()
        ..color = const Color(0xFF111827).withOpacity(.20)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawCircle(pos, radius, outline);
      tp.text = TextSpan(text: '$id', style: const TextStyle(color: Colors.white, fontSize: 8.2, fontWeight: FontWeight.w600));
      tp.layout();
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }
  }

  void _paintPlayerDots(Canvas canvas, Map<int, Offset> pts, double radius, double fontSize) {
    final tp = TextPainter(textDirection: TextDirection.ltr, textAlign: TextAlign.center);
    pts.forEach((n, o) {
      canvas.drawCircle(o, radius, Paint()..color = const Color(0xFF1D7DE0));
      final stroke = Paint()
        ..color = const Color(0xFFFFFFFF).withOpacity(.90)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      canvas.drawCircle(o, radius, stroke);
      tp.text = TextSpan(text: '$n', style: TextStyle(color: Colors.white, fontSize: fontSize, fontWeight: FontWeight.w600));
      tp.layout();
      tp.paint(canvas, o - Offset(tp.width / 2, tp.height / 2));
    });
  }

  @override
  bool shouldRepaint(covariant _MatchPitchNetworkPainter oldDelegate) =>
      oldDelegate.vertical != vertical ||
      oldDelegate.livePositions != livePositions ||
      oldDelegate.liveTrails != liveTrails ||
      oldDelegate.liveSpeeds != liveSpeeds;
}

class _MatchVideoFieldPainter extends CustomPainter {
  final bool tactical;
  const _MatchVideoFieldPainter({required this.tactical});
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..shader=LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:[const Color(0xFF293036),const Color(0xFF11320F)]).createShader(Offset.zero & size));
    final field=Path()..moveTo(size.width*.04,size.height*.84)..lineTo(size.width*.96,size.height*.82)..lineTo(size.width*.72,size.height*.36)..lineTo(size.width*.22,size.height*.38)..close();
    canvas.drawPath(field,Paint()..color=const Color(0xFF3C7B25));
    final line=Paint()..color=const Color(0xFFFFFFFF)..strokeWidth=1.1;
    for(int i=0;i<6;i++) canvas.drawLine(Offset(size.width*(.08+.12*i),size.height*(.82-.08*i)),Offset(size.width*(.92-.05*i),size.height*(.80-.09*i)),line);
    final player=Paint()..color=tactical?const Color(0xFF1D7DE0):const Color(0xFFEED843);
    for(int i=0;i<12;i++) canvas.drawCircle(Offset(size.width*(.18+(i%6)*.13),size.height*(.50+(i~/6)*.17+((i%2)*.04))),3.8,player);
  }
  @override
  bool shouldRepaint(covariant _MatchVideoFieldPainter oldDelegate)=>oldDelegate.tactical!=tactical;
}

class _MatchEventTimelinePainter extends CustomPainter {
  const _MatchEventTimelinePainter();
  @override
  void paint(Canvas canvas, Size size){
    final mid=size.height*.54,left=18.0,right=size.width-14; final line=Paint()..color=const Color(0xFFD8E2EA)..strokeWidth=1; canvas.drawLine(Offset(left,mid),Offset(right,mid),line); final tp=TextPainter(textDirection:TextDirection.ltr);
    for(int m=0;m<=90;m+=15){final x=left+(right-left)*m/90; canvas.drawLine(Offset(x,mid-7),Offset(x,mid+7),line); tp.text=TextSpan(text:'$m',style:TextStyle(color:const Color(0xFF64748B),fontSize:9,fontWeight:FontWeight.w600)); tp.layout(); tp.paint(canvas,Offset(x-tp.width/2,mid-27));}
    const ev=[12,27,33,45,61,74,81,85]; final colors=[const Color(0xFF27B84A),const Color(0xFF27B84A),const Color(0xFFE9C232),const Color(0xFF27B84A),const Color(0xFFE9C232),const Color(0xFF2097E8),const Color(0xFF2097E8),const Color(0xFFE9C232)];
    for(int i=0;i<ev.length;i++){final x=left+(right-left)*ev[i]/90; canvas.drawCircle(Offset(x,mid+(i.isEven?22:-2)),4,Paint()..color=colors[i]);}
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate)=>false;
}

class _MatchBottomScrubberPainter extends CustomPainter {
  const _MatchBottomScrubberPainter();
  @override
  void paint(Canvas canvas, Size size){
    final left=10.0,right=size.width-28,y=size.height*.55; canvas.drawLine(Offset(left,y),Offset(right,y),Paint()..color=const Color(0xFFD8E2EA)..strokeWidth=2); canvas.drawLine(Offset(left,y),Offset(right*.82,y),Paint()..color=const Color(0xFF228BE6)..strokeWidth=3); final tp=TextPainter(textDirection:TextDirection.ltr);
    for(int m=0;m<=90;m+=15){final x=left+(right-left)*m/90; canvas.drawLine(Offset(x,y-5),Offset(x,y+5),Paint()..color=const Color(0xFF94A3B8)); tp.text=TextSpan(text:'$m',style:TextStyle(color:const Color(0xFF64748B),fontSize:10,fontWeight:FontWeight.w600)); tp.layout(); tp.paint(canvas,Offset(x-tp.width/2,y+9));}
    final ev=[12,30,45,61,66,74,81,85]; final colors=[const Color(0xFF94A3B8),const Color(0xFFE9C232),const Color(0xFF27B84A),const Color(0xFFE9C232),const Color(0xFF2097E8),const Color(0xFF27B84A),const Color(0xFFE9C232),const Color(0xFFD64545)]; for(int i=0;i<ev.length;i++){final x=left+(right-left)*ev[i]/90; canvas.drawCircle(Offset(x,y-14-(i%3)*6),3.2,Paint()..color=colors[i]);}
    tp.text=TextSpan(text:'00:00',style:TextStyle(color:const Color(0xFF64748B),fontSize:11,fontWeight:FontWeight.w600)); tp.layout(); tp.paint(canvas,Offset(left,y-31)); tp.text=TextSpan(text:'90:00',style:TextStyle(color:const Color(0xFF64748B),fontSize:11,fontWeight:FontWeight.w600)); tp.layout(); tp.paint(canvas,Offset(right-tp.width,y-31));
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate)=>false;
}

class _ProKpi {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String hint;

  const _ProKpi(this.label, this.value, this.icon, this.color, this.hint);
}

class _TacticalMapData {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _TacticalMapData(this.title, this.subtitle, this.icon, this.color);
}

class _SportotekaPitchPainter extends CustomPainter {
  final Color primary;

  const _SportotekaPitchPainter({required this.primary});

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()
      ..color = const Color(0xFFF2F7F4)
      ..style = PaintingStyle.fill;
    final line = Paint()
      ..color = primary.withOpacity(.38)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    final rect = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(22));
    canvas.drawRRect(rect, bg);

    final inset = Rect.fromLTWH(14, 14, size.width - 28, size.height - 28);
    canvas.drawRRect(RRect.fromRectAndRadius(inset, const Radius.circular(16)), line);
    canvas.drawLine(Offset(14, size.height / 2), Offset(size.width - 14, size.height / 2), line);
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), min(size.width, size.height) * .16, line);

    final penaltyWidth = size.width * .56;
    final penaltyHeight = size.height * .16;
    final goalBoxWidth = size.width * .30;
    final goalBoxHeight = size.height * .075;

    canvas.drawRect(
      Rect.fromLTWH((size.width - penaltyWidth) / 2, 14, penaltyWidth, penaltyHeight),
      line,
    );
    canvas.drawRect(
      Rect.fromLTWH((size.width - penaltyWidth) / 2, size.height - 14 - penaltyHeight, penaltyWidth, penaltyHeight),
      line,
    );
    canvas.drawRect(
      Rect.fromLTWH((size.width - goalBoxWidth) / 2, 14, goalBoxWidth, goalBoxHeight),
      line,
    );
    canvas.drawRect(
      Rect.fromLTWH((size.width - goalBoxWidth) / 2, size.height - 14 - goalBoxHeight, goalBoxWidth, goalBoxHeight),
      line,
    );
  }

  @override
  bool shouldRepaint(covariant _SportotekaPitchPainter oldDelegate) => oldDelegate.primary != primary;
}

class _TacticalLinesPainter extends CustomPainter {
  final Color primary;

  const _TacticalLinesPainter({required this.primary});

  @override
  void paint(Canvas canvas, Size size) {
    final field = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final line = Paint()
      ..color = primary.withOpacity(.25)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final pass = Paint()
      ..color = primary.withOpacity(.52)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke;
    final player = Paint()
      ..color = primary
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(18)),
      field,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(10, 10, size.width - 20, size.height - 20), const Radius.circular(14)),
      line,
    );
    canvas.drawLine(Offset(size.width / 2, 10), Offset(size.width / 2, size.height - 10), line);

    final points = <Offset>[
      Offset(size.width * .18, size.height * .52),
      Offset(size.width * .34, size.height * .28),
      Offset(size.width * .36, size.height * .72),
      Offset(size.width * .55, size.height * .50),
      Offset(size.width * .75, size.height * .35),
      Offset(size.width * .78, size.height * .68),
    ];

    for (var i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], pass);
    }
    canvas.drawLine(points[1], points[3], pass);
    canvas.drawLine(points[2], points[3], pass);
    canvas.drawLine(points[3], points[4], pass);
    canvas.drawLine(points[3], points[5], pass);

    for (final point in points) {
      canvas.drawCircle(point, 7, player);
      canvas.drawCircle(point, 10, Paint()..color = primary.withOpacity(.12));
    }
  }

  @override
  bool shouldRepaint(covariant _TacticalLinesPainter oldDelegate) => oldDelegate.primary != primary;
}

class _EditorFieldBlock {
  const _EditorFieldBlock({
    required this.title,
    required this.controller,
    this.hint,
    this.maxLines = 1,
  });

  final String title;
  final TextEditingController controller;
  final String? hint;
  final int maxLines;
}

class _CoachQuickAction {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _CoachQuickAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });
}

class _MatchMobileMoreItem extends StatelessWidget {
  final _MatchDetailNavItem item;
  final bool active;
  final Color primary;
  final Color textPrimary;
  final Color textSecondary;
  final VoidCallback onTap;

  const _MatchMobileMoreItem({
    required this.item,
    required this.active,
    required this.primary,
    required this.textPrimary,
    required this.textSecondary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? primary.withOpacity(0.10) : const Color(0xFFF6F8FA),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: active ? primary : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  item.icon,
                  size: 20,
                  color: active ? Colors.white : primary,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: active ? primary : textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: active ? primary : textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverviewMetricData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? hint;

  const _OverviewMetricData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.hint,
  });
}



class _MatchDetailNavItem {
  final String title;
  final String subtitle;
  final IconData icon;

  const _MatchDetailNavItem({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}


class _MatchRailColors {
  static const Color rail = Color(0xFF111827);
  static const Color railPanel = Color(0xFF1B2432);
  static const Color railHover = Color(0xFF263244);
  static const Color railText = Color(0xFFE5E7EB);
  static const Color railMuted = Color(0xFFAAB4C3);
  static const Color border = Color(0xFF2B3648);
  static const Color active = Color(0xFFFFFFFF);
  static const Color activeText = Color(0xFF111827);
  static const Color primaryGreen = Color(0xFF00A750);
}

class _MatchRailButton extends StatefulWidget {
  final _MatchDetailNavItem item;
  final bool active;
  final VoidCallback onTap;

  const _MatchRailButton({
    required this.item,
    required this.active,
    required this.onTap,
  });

  @override
  State<_MatchRailButton> createState() => _MatchRailButtonState();
}

class _MatchRailButtonState extends State<_MatchRailButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.active
        ? _MatchRailColors.active
        : _hovered
            ? _MatchRailColors.railHover
            : _MatchRailColors.railPanel;
    final borderColor = widget.active ? _MatchRailColors.active : _MatchRailColors.border;
    final fg = widget.active ? _MatchRailColors.activeText : _MatchRailColors.railText;
    final textColor = widget.active ? _MatchRailColors.activeText : _MatchRailColors.railMuted;
    var label = widget.item.title;
    if (label == 'Основные ТТД') label = 'ТТД';
    if (label == 'Видеоанализ ИИ') label = 'ИИ';

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Tooltip(
        message: '${widget.item.title} — ${widget.item.subtitle}',
        waitDuration: const Duration(milliseconds: 250),
        preferBelow: false,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            width: double.infinity,
            height: 50,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: borderColor),
              boxShadow: widget.active
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(.035),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : const [],
            ),
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                if (widget.active)
                  Positioned(
                    left: 0,
                    top: 8,
                    bottom: 8,
                    child: Container(
                      width: 3,
                      decoration: BoxDecoration(
                        color: _MatchRailColors.primaryGreen,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(widget.item.icon, color: fg, size: 18),
                    const SizedBox(height: 3),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 8,
                          height: .95,
                          letterSpacing: -.25,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MatchRailUtilityButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final String tooltip;
  final bool active;
  final VoidCallback onTap;

  const _MatchRailUtilityButton({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.active,
    required this.onTap,
  });

  @override
  State<_MatchRailUtilityButton> createState() => _MatchRailUtilityButtonState();
}

class _MatchRailUtilityButtonState extends State<_MatchRailUtilityButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.active;
    final bgColor = selected
        ? _MatchRailColors.active
        : _hovered
            ? _MatchRailColors.railHover
            : _MatchRailColors.railPanel;
    final borderColor = selected ? _MatchRailColors.active : _MatchRailColors.border;
    final iconColor = selected ? _MatchRailColors.activeText : _MatchRailColors.railText;
    final textColor = selected ? _MatchRailColors.activeText : _MatchRailColors.railMuted;
    var label = widget.label;
    if (label.length > 7 && label.contains(':')) label = 'Счёт';

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Tooltip(
        message: widget.tooltip,
        waitDuration: const Duration(milliseconds: 250),
        preferBelow: false,
        child: Center(
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: widget.onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              width: 56,
              height: 50,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: Colors.black.withOpacity(.035),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : const [],
              ),
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  if (selected)
                    Positioned(
                      left: 0,
                      top: 8,
                      bottom: 8,
                      child: Container(
                        width: 3,
                        decoration: BoxDecoration(
                          color: _MatchRailColors.primaryGreen,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(widget.icon, color: iconColor, size: 18),
                      const SizedBox(height: 3),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 8,
                            height: .95,
                            letterSpacing: -.25,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CmrToolbarButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final Color primary;
  final bool filled;

  const _CmrToolbarButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.primary,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: filled ? Colors.white : primary),
        if (label.isNotEmpty) ...[
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: filled ? Colors.white : const Color(0xFF101828),
                fontWeight: FontWeight.w600,
                fontSize: 11.2,
              ),
            ),
          ),
        ],
      ],
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          height: 36,
          padding: EdgeInsets.symmetric(horizontal: label.isEmpty ? 10 : 12),
          decoration: BoxDecoration(
            color: filled ? primary : const Color(0xFFF6F8FA),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _CmrMiniPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _CmrMiniPill({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F8FA),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFF667085)),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF667085),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchSidebarButton extends StatelessWidget {
  final _MatchDetailNavItem item;
  final bool active;
  final Color primary;
  final VoidCallback onTap;

  const _MatchSidebarButton({
    required this.item,
    required this.active,
    required this.primary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = active ? const Color(0xFFF3FBF7) : Colors.transparent;
    final iconColor = active ? const Color(0xFF28A86B) : const Color(0xFF6B7280);
    final textColor = active ? const Color(0xFF0B0F14) : const Color(0xFF344054);

    return Material(
      color: bgColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          height: 34,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: active ? Border.all(color: const Color(0xFFDCEFE5), width: 1) : null,
          ),
          child: Row(
            children: [
              Icon(item.icon, color: iconColor, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 10.8,
                    height: 1,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w600,
                    letterSpacing: -.12,
                  ),
                ),
              ),
              if (active)
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(color: Color(0xFF28A86B), shape: BoxShape.circle),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VideoTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String url;
  final VoidCallback onWatch;
  final VoidCallback? onAnalyze;
  final VoidCallback onDetails;
  final VoidCallback? onDelete;
  final Color primary;

  const _VideoTile({
    required this.title,
    this.subtitle,
    required this.url,
    required this.onWatch,
    this.onAnalyze,
    required this.onDetails,
    this.onDelete,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    final cleanSubtitle = (subtitle ?? '').trim();

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F9FA),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF8F3),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.play_arrow_rounded, color: primary, size: 22),
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
                          color: Color(0xFF101828),
                          fontWeight: FontWeight.w600,
                          fontSize: 12.8,
                          height: 1.12,
                        ),
                      ),
                      if (cleanSubtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          cleanSubtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF667085),
                            fontSize: 10.8,
                            height: 1.15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _VideoIconButton(
                  icon: Icons.tune_rounded,
                  tooltip: 'Детали',
                  onTap: onDetails,
                  color: const Color(0xFF0B0F14),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _VideoActionPill(
                    label: "Смотреть",
                    icon: Icons.visibility_outlined,
                    onTap: onWatch,
                    foreground: primary,
                    background: Colors.white,
                    borderColor: primary.withOpacity(0.14),
                    expanded: true,
                  ),
                ),
                if (onAnalyze != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: _VideoActionPill(
                      label: "Анализ",
                      icon: Icons.analytics_outlined,
                      onTap: onAnalyze!,
                      foreground: Colors.white,
                      background: primary,
                      borderColor: primary,
                      expanded: true,
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                Expanded(
                  child: _VideoActionPill(
                    label: "Детали",
                    icon: Icons.tune_rounded,
                    onTap: onDetails,
                    foreground: const Color(0xFF0B0F14),
                    background: Colors.white,
                    borderColor: const Color(0xFFE8EEF2),
                    expanded: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color color;

  const _VideoIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
        ),
      ),
    );
  }
}

class _VideoActionPill extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color foreground;
  final Color background;
  final Color borderColor;
  final bool expanded;

  const _VideoActionPill({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.foreground,
    required this.background,
    required this.borderColor,
    this.expanded = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 34,
          width: expanded ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: foreground),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 11.3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayerAvatar extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final Color primary;
  final double size;

  const _PlayerAvatar({
    required this.imageUrl,
    required this.name,
    required this.primary,
    this.size = 42,
  });

  @override
  Widget build(BuildContext context) {
    final initials = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .take(2)
        .map((e) => e.substring(0, 1).toUpperCase())
        .join();

    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.34),
      child: Container(
        width: size,
        height: size,
        color: primary.withOpacity(0.10),
        child: imageUrl != null && imageUrl!.isNotEmpty
            ? Image.network(
                imageUrl!,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallback(initials),
              )
            : _fallback(initials),
      ),
    );
  }

  Widget _fallback(String initials) {
    return Center(
      child: Text(
        initials.isEmpty ? "И" : initials,
        style: TextStyle(
          color: primary,
          fontWeight: FontWeight.w600,
          fontSize: size * 0.28,
        ),
      ),
    );
  }
}

class _PlayerMetricItem {
  final String code;
  final String title;
  final int success;
  final int fail;

  const _PlayerMetricItem({
    required this.code,
    required this.title,
    required this.success,
    required this.fail,
  });

  int get total => success + fail;
}

class TeamVideoUploadDraft {
  final String uploadId;
  final String videoPath;
  final String? thumbnailPath;
  final int matchId;
  final int teamId;
  final int coachId;
  final String notes;
  final String fileName;
  final int fileSize;
  final int totalChunks;
  final int lastUploadedChunk;
  final String videoType;

  const TeamVideoUploadDraft({
    required this.uploadId,
    required this.videoPath,
    required this.thumbnailPath,
    required this.matchId,
    required this.teamId,
    required this.coachId,
    required this.notes,
    required this.fileName,
    required this.fileSize,
    required this.totalChunks,
    required this.lastUploadedChunk,
    required this.videoType,
  });

  Map<String, dynamic> toJson() => {
        'upload_id': uploadId,
        'video_path': videoPath,
        'thumbnail_path': thumbnailPath,
        'match_id': matchId,
        'team_id': teamId,
        'coach_id': coachId,
        'notes': notes,
        'file_name': fileName,
        'file_size': fileSize,
        'total_chunks': totalChunks,
        'last_uploaded_chunk': lastUploadedChunk,
        'video_type': videoType,
      };

  factory TeamVideoUploadDraft.fromJson(Map<String, dynamic> json) {
    return TeamVideoUploadDraft(
      uploadId: (json['upload_id'] ?? '').toString(),
      videoPath: (json['video_path'] ?? '').toString(),
      thumbnailPath: json['thumbnail_path']?.toString(),
      matchId: int.tryParse('${json['match_id']}') ?? 0,
      teamId: int.tryParse('${json['team_id']}') ?? 0,
      coachId: int.tryParse('${json['coach_id']}') ?? 0,
      notes: (json['notes'] ?? '').toString(),
      fileName: (json['file_name'] ?? '').toString(),
      fileSize: int.tryParse('${json['file_size']}') ?? 0,
      totalChunks: int.tryParse('${json['total_chunks']}') ?? 0,
      lastUploadedChunk: int.tryParse('${json['last_uploaded_chunk']}') ?? -1,
      videoType: (json['video_type'] ?? 'full').toString(),
    );
  }
}

class ChunkUploadService {
  static const String apiBase = "https://sportotekaapp.ru/api";
  static const String uploadChunkUrl =
      "$apiBase/upload_team_match_video_chunk.php";
  static const String completeUploadUrl =
      "$apiBase/complete_team_match_video_upload.php";
  static const String uploadStatusUrl =
      "$apiBase/get_team_match_upload_status.php";
  static const String cancelUploadUrl =
      "$apiBase/cancel_team_match_video_upload.php";

  static const String _draftKey = 'team_video_upload_draft_v1';

  final Dio dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(minutes: 10),
      receiveTimeout: const Duration(minutes: 10),
      responseType: ResponseType.plain,
      validateStatus: (status) => status != null && status < 500,
    ),
  );

  Future<Map<String, dynamic>> uploadVideoInChunks({
    required File videoFile,
    File? thumbnailFile,
    required int matchId,
    required int teamId,
    required int coachId,
    required String notes,
    required String videoType,
    required void Function(double progress, String text) onProgress,
    String? resumeUploadId,
  }) async {
    if (!await videoFile.exists()) {
      return {
        "success": false,
        "message": "Видео файл не найден",
      };
    }

    final fileLength = await videoFile.length();
    final fileName = videoFile.uri.pathSegments.last;
    final ext =
        fileName.contains('.') ? fileName.split('.').last.toLowerCase() : 'mp4';

    if (!['mp4', 'mov', 'm4v', 'avi'].contains(ext)) {
      return {
        'success': false,
        'message': 'Неподдерживаемый формат видео. Поддерживаются MP4, MOV, M4V и AVI. AVI после загрузки конвертируется сервером в MP4.',
      };
    }

    const int chunkSize = 1 * 1024 * 1024;
    final int totalChunks = (fileLength / chunkSize).ceil();

    final uploadId = resumeUploadId ??
        _buildUploadId(
          matchId: matchId,
          teamId: teamId,
          coachId: coachId,
          fileName: fileName,
          fileLength: fileLength,
          videoType: videoType,
        );

    final existingDraft = await loadDraft();
    if (existingDraft == null || existingDraft.uploadId != uploadId) {
      await _saveDraft(
        TeamVideoUploadDraft(
          uploadId: uploadId,
          videoPath: videoFile.path,
          thumbnailPath: thumbnailFile?.path,
          matchId: matchId,
          teamId: teamId,
          coachId: coachId,
          notes: notes,
          fileName: fileName,
          fileSize: fileLength,
          totalChunks: totalChunks,
          lastUploadedChunk: -1,
          videoType: videoType,
        ),
      );
    }

    final uploadedChunks = await fetchUploadedChunks(uploadId);
    final raf = videoFile.openSync(mode: FileMode.read);

    try {
      for (int chunkIndex = 0; chunkIndex < totalChunks; chunkIndex++) {
        if (uploadedChunks.contains(chunkIndex)) {
          final progress = (chunkIndex + 1) / totalChunks;
          onProgress(
            progress.clamp(0.0, 0.97),
            "Пропуск чанка ${chunkIndex + 1}/$totalChunks",
          );
          await _updateDraftLastChunk(chunkIndex);
          continue;
        }

        final int start = chunkIndex * chunkSize;
        final int end = min(start + chunkSize, fileLength);
        final int currentSize = end - start;

        raf.setPositionSync(start);
        final chunkBytes = raf.readSync(currentSize);

        FormData buildChunkFormData() {
          return FormData.fromMap({
            "upload_id": uploadId,
            "match_id": matchId.toString(),
            "team_id": teamId.toString(),
            "coach_id": coachId.toString(),
            "file_name": fileName,
            "file_ext": ext,
            "file_size": fileLength.toString(),
            "chunk_index": chunkIndex.toString(),
            "total_chunks": totalChunks.toString(),
            "chunk_size": currentSize.toString(),
            "notes": notes,
            "video_type": videoType,
            "chunk": MultipartFile.fromBytes(
              chunkBytes,
              filename: "chunk_$chunkIndex.part",
            ),
          });
        }

        final response = await _postChunkWithRetry(
          buildChunkFormData,
          onSendProgress: (sent, total) {
            if (total <= 0) return;
            final chunkProgress = sent / total;
            final overall = (chunkIndex + chunkProgress) / totalChunks;
            onProgress(
              overall.clamp(0.0, 0.97),
              "Загрузка чанка ${chunkIndex + 1}/$totalChunks",
            );
          },
        );
        final decoded = _decodePlain(response.data);

        if (decoded["success"] != true) {
          return {
            "success": false,
            "message":
                decoded["message"] ?? "Ошибка загрузки чанка ${chunkIndex + 1}",
          };
        }

        await _updateDraftLastChunk(chunkIndex);

        final progress = (chunkIndex + 1) / totalChunks;
        onProgress(
          progress.clamp(0.0, 0.97),
          "Загружено ${chunkIndex + 1} из $totalChunks",
        );
      }
    } finally {
      raf.closeSync();
    }

    onProgress(0.98, ext == "avi" ? "Сборка и конвертация AVI в MP4..." : "Сборка файла на сервере...");

    String? thumbnailBase64;
    String? thumbnailName;

    if (thumbnailFile != null && await thumbnailFile.exists()) {
      final bytes = await thumbnailFile.readAsBytes();
      thumbnailBase64 = base64Encode(bytes);
      thumbnailName = thumbnailFile.uri.pathSegments.last;
    }

    final completeResp = await dio.post(
      completeUploadUrl,
      data: FormData.fromMap({
        "upload_id": uploadId,
        "match_id": matchId.toString(),
        "team_id": teamId.toString(),
        "coach_id": coachId.toString(),
        "file_name": fileName,
        "file_ext": ext,
        "file_size": fileLength.toString(),
        "total_chunks": totalChunks.toString(),
        "notes": notes,
        "video_type": videoType,
        if (thumbnailBase64 != null) "thumbnail_base64": thumbnailBase64,
        if (thumbnailName != null) "thumbnail_name": thumbnailName,
      }),
      options: Options(
        contentType: 'multipart/form-data',
      ),
    );

    final result = _decodePlain(completeResp.data);

    if (result["success"] == true) {
      await clearDraft();
    }

    onProgress(1.0, "Загрузка завершена");
    return result;
  }

  Future<Response<dynamic>> _postChunkWithRetry(
    FormData Function() buildFormData, {
    ProgressCallback? onSendProgress,
  }) async {
    DioException? lastError;

    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        // Важно: FormData в Dio одноразовый. После первой отправки он
        // finalizes, поэтому при повторной попытке нужно создать новый
        // FormData, иначе будет ошибка:
        // Bad state: The FormData has already been finalized.
        final freshFormData = buildFormData();

        return await dio.post(
          uploadChunkUrl,
          data: freshFormData,
          onSendProgress: onSendProgress,
          options: Options(
            contentType: 'multipart/form-data',
          ),
        );
      } on DioException catch (e) {
        lastError = e;
        if (attempt < 2) {
          await Future.delayed(Duration(seconds: attempt + 1));
        }
      }
    }

    throw lastError ??
        DioException(
          requestOptions: RequestOptions(path: uploadChunkUrl),
          error: "Не удалось загрузить чанк",
        );
  }

  Future<Set<int>> fetchUploadedChunks(String uploadId) async {
    try {
      final resp = await dio.post(
        uploadStatusUrl,
        data: FormData.fromMap({
          "upload_id": uploadId,
        }),
        options: Options(
          contentType: 'multipart/form-data',
        ),
      );

      final decoded = _decodePlain(resp.data);
      if (decoded["success"] == true && decoded["uploaded_chunks"] is List) {
        return (decoded["uploaded_chunks"] as List)
            .map((e) => int.tryParse('$e') ?? -1)
            .where((e) => e >= 0)
            .toSet();
      }
    } catch (_) {}

    return <int>{};
  }

  Future<void> cancelUploadOnServer(String uploadId) async {
    try {
      await dio.post(
        cancelUploadUrl,
        data: FormData.fromMap({
          "upload_id": uploadId,
        }),
        options: Options(
          contentType: 'multipart/form-data',
        ),
      );
    } catch (_) {}
  }

  Future<void> _saveDraft(TeamVideoUploadDraft draft) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_draftKey, jsonEncode(draft.toJson()));
  }

  Future<TeamVideoUploadDraft?> loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_draftKey);
    if (raw == null || raw.isEmpty) return null;

    try {
      final map = jsonDecode(raw);
      if (map is Map<String, dynamic>) {
        return TeamVideoUploadDraft.fromJson(map);
      }
      if (map is Map) {
        return TeamVideoUploadDraft.fromJson(Map<String, dynamic>.from(map));
      }
    } catch (_) {}

    return null;
  }

  Future<void> _updateDraftLastChunk(int chunkIndex) async {
    final draft = await loadDraft();
    if (draft == null) return;

    final updated = TeamVideoUploadDraft(
      uploadId: draft.uploadId,
      videoPath: draft.videoPath,
      thumbnailPath: draft.thumbnailPath,
      matchId: draft.matchId,
      teamId: draft.teamId,
      coachId: draft.coachId,
      notes: draft.notes,
      fileName: draft.fileName,
      fileSize: draft.fileSize,
      totalChunks: draft.totalChunks,
      lastUploadedChunk: chunkIndex,
      videoType: draft.videoType,
    );

    await _saveDraft(updated);
  }

  Future<void> clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
  }

  String _buildUploadId({
    required int matchId,
    required int teamId,
    required int coachId,
    required String fileName,
    required int fileLength,
    required String videoType,
  }) {
    final raw =
        "$matchId|$teamId|$coachId|$fileName|$fileLength|$videoType|resume-stable";
    return md5.convert(utf8.encode(raw)).toString();
  }

  Map<String, dynamic> _decodePlain(dynamic rawResponse) {
    try {
      final body = (rawResponse ?? "").toString().trim();
      final start = body.indexOf('{');
      if (start == -1) {
        return {
          "success": false,
          "message": "Некорректный ответ сервера",
        };
      }
      final clean = body.substring(start);
      final j = jsonDecode(clean);
      if (j is Map<String, dynamic>) return j;
      if (j is Map) return Map<String, dynamic>.from(j);
      return {"success": false, "message": "Пустой JSON"};
    } catch (e) {
      return {"success": false, "message": "Ошибка разбора ответа: $e"};
    }
  }
}
