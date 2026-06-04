import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';


import 'package:sportoteka/core/constants/app_colors.dart';
import 'package:sportoteka/presentation/team_video_analysis/ai_tracking_controller.dart';
import 'package:sportoteka/presentation/team_video_analysis/models/player_models.dart';
import 'package:sportoteka/presentation/team_video_analysis/models/ttd_models.dart';
import 'package:sportoteka/presentation/team_video_analysis/player_tracking_painter.dart';
import 'package:sportoteka/presentation/team_video_analysis/python_tracking_service.dart';
import 'package:sportoteka/presentation/team_video_analysis/tracked_player_models.dart';
import 'package:sportoteka/presentation/team_video_analysis/tracking_analytics_service.dart';
import 'package:sportoteka/presentation/team_video_analysis/tracking_heatmap_painter.dart';
import 'package:sportoteka/presentation/team_video_analysis/tracking_models.dart';
import 'package:sportoteka/presentation/team_video_analysis/utils/api_constants.dart';
import 'package:sportoteka/presentation/team_video_analysis/utils/formatters.dart';
import 'package:sportoteka/presentation/team_video_analysis/utils/helpers.dart';

import 'package:sportoteka/presentation/team_video_analysis/widgets/ai_tracking_panel_widget.dart';
import 'package:sportoteka/presentation/team_video_analysis/widgets/common_widgets.dart';
import 'package:sportoteka/presentation/team_video_analysis/widgets/episodes_list_widget.dart';
import 'package:sportoteka/presentation/team_video_analysis/widgets/players_list_widget.dart';
import 'package:sportoteka/presentation/team_video_analysis/widgets/report_tables_widget.dart';
import 'package:sportoteka/presentation/team_video_analysis/widgets/ttd_panel_widget.dart';
import 'package:sportoteka/presentation/team_video_analysis/widgets/video_player_widget.dart';
import 'package:sportoteka/presentation/team_video_analysis/screens/episode_ttd_detail_screen.dart'
    as episode_detail;
import 'package:sportoteka/presentation/team_video_analysis/screens/fullscreen_image_screen.dart';
import 'package:sportoteka/presentation/team_video_analysis/widgets/match_players_selection_widget.dart';
import 'package:sportoteka/presentation/team_video_analysis/services/match_players_service.dart';
import 'package:sportoteka/presentation/team_video_analysis/widgets/ai_analytics_panel_widget.dart';
import 'package:sportoteka/presentation/team_video_analysis/ai_analytics_models.dart';
import 'package:sportoteka/presentation/team_video_analysis/ai_packet_mapper.dart';
import 'package:sportoteka/presentation/team_video_analysis/ai_video_analysis_controller.dart';
import 'package:sportoteka/data/services/ai_video_analysis_service.dart';
import 'package:sportoteka/data/models/ai_video_analysis_models.dart';
import 'package:sportoteka/presentation/team_video_analysis/models/team_visual_config.dart';
import 'package:sportoteka/presentation/team_video_analysis/widgets/team_identity_setup_sheet.dart';







class VideoMatchReviewScreen extends StatefulWidget {
  final int matchId;
  final int teamId;
  final String teamName;
  final int coachId;
  final String matchTitle;
  final String videoUrl;
  final int videoId;

  /// true — режим встраивания внутрь TeamMatchDetailScreen.
  /// В этом режиме экран не создаёт отдельный Scaffold и не заставляет
  /// устройство переходить в landscape, чтобы не ломать рабочую область матча.
  final bool embedded;
  final bool forceLandscape;

  /// true — во встроенном режиме переносит вертикальное меню AI-разбора
  /// в левую часть экрана, чтобы оно заменяло общее меню матча.
  final bool railOnLeft;

  /// Управление видео из внешней нижней панели TeamMatchDetailScreen.
  final VideoMatchReviewPlaybackController? playbackController;

  /// false — внутри виджета скрывается верхняя полоса управления видео,
  /// потому что используется общий нижний плеер экрана матча.
  final bool showInternalVideoControls;

  const VideoMatchReviewScreen({
    super.key,
    required this.matchId,
    required this.teamId,
    required this.teamName,
    required this.coachId,
    required this.matchTitle,
    required this.videoUrl,
    required this.videoId,
    this.embedded = false,
    this.forceLandscape = true,
    this.railOnLeft = false,
    this.playbackController,
    this.showInternalVideoControls = true,
  });

  @override
  State<VideoMatchReviewScreen> createState() => _VideoMatchReviewScreenState();
}
String _sideTagToString(AnalysisSideTag side) {
  return side == AnalysisSideTag.home ? 'home' : 'away';
}

enum ReviewOverlayPanel {
  none,
  players,
  episodes,
  ttd,
  analytics,
}

class VideoMatchReviewPlaybackController extends ChangeNotifier {
  _VideoMatchReviewScreenState? _state;

  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  bool isReady = false;
  bool isPlaying = false;
  bool isFullscreen = false;
  double speed = 1.0;
  ReviewOverlayPanel activePanel = ReviewOverlayPanel.none;
  int tabIndex = 0;

  bool get attached => _state != null;

  void _attach(_VideoMatchReviewScreenState state) {
    _state = state;
    _syncFromState();
  }

  void _detach(_VideoMatchReviewScreenState state) {
    if (identical(_state, state)) {
      _state = null;
      isReady = false;
      isPlaying = false;
      activePanel = ReviewOverlayPanel.none;
      notifyListeners();
    }
  }

  void _syncFromState() {
    final state = _state;
    if (state == null) return;

    final value = state._controller.value;
    final nextPosition = value.position;
    final nextDuration = value.duration;
    final nextReady = state._videoReady && value.isInitialized;
    final nextPlaying = value.isPlaying;
    final nextSpeed = speed;
    final nextFullscreen = state._isVideoFullscreen || state._fullscreenRouteOpen;
    final nextPanel = state._activeOverlayPanel;
    final nextTab = state._tabController.index;

    final changed = position != nextPosition ||
        duration != nextDuration ||
        isReady != nextReady ||
        isPlaying != nextPlaying ||
        speed != nextSpeed ||
        isFullscreen != nextFullscreen ||
        activePanel != nextPanel ||
        tabIndex != nextTab;

    position = nextPosition;
    duration = nextDuration;
    isReady = nextReady;
    isPlaying = nextPlaying;
    speed = nextSpeed;
    isFullscreen = nextFullscreen;
    activePanel = nextPanel;
    tabIndex = nextTab;

    if (changed) notifyListeners();
  }

  Future<void> togglePlayPause() async {
    await _state?._togglePlayPause();
    _syncFromState();
  }

  Future<void> seekRelative(int seconds) async {
    await _state?._seekRelative(seconds);
    _syncFromState();
  }

  Future<void> seekToFraction(double fraction) async {
    final state = _state;
    if (state == null || !state._videoReady) return;

    final duration = state._controller.value.duration;
    if (duration.inMilliseconds <= 0) return;

    final clamped = fraction.clamp(0.0, 1.0).toDouble();
    final target = Duration(
      milliseconds: (duration.inMilliseconds * clamped).round(),
    );
    await state._controller.seekTo(target);
    if (state.mounted) state.setState(() {});
    _syncFromState();
  }

  Future<void> cycleSpeed() async {
    final state = _state;
    if (state == null || !state._videoReady) return;

    const speeds = <double>[1.0, 1.25, 1.5, 2.0, 0.75];
    final current = speed;
    final index = speeds.indexWhere((item) => (item - current).abs() < 0.01);
    final next = speeds[(index + 1) % speeds.length];
    await state._controller.setPlaybackSpeed(next);
    speed = next;
    notifyListeners();
    if (state.mounted) state.setState(() {});
    _syncFromState();
  }

  void toggleFullscreen() {
    _state?._toggleFullscreen();
    _syncFromState();
  }

  void openVideo() {
    final state = _state;
    if (state == null) return;
    state._tabController.animateTo(0);
    _syncFromState();
  }

  void openReport() {
    final state = _state;
    if (state == null) return;
    state._tabController.animateTo(1);
    _syncFromState();
  }

  void togglePanel(ReviewOverlayPanel panel) {
    _state?._togglePanel(panel);
    _syncFromState();
  }

  void closePanels() {
    _state?._closePanels();
    _syncFromState();
  }

  Future<void> createEpisodeFromCurrentFrame() async {
    await _state?._createEpisodeFromCurrentFrame();
    _syncFromState();
  }
}




class ReviewUiPalette {
  static const bg = Color(0xFFF4F7FA);
  static const panel = Color(0xFFFFFFFF);
  static const panelSoft = Color(0xFFF8FAFC);
  static const line = Color(0xFFD8E2EA);
  static const border = Color(0xFFD7E8DE);
  static const text = Color(0xFF101828);
  static const textMuted = Color(0xFF64748B);

  static const primary = Color(0xFF1F7A4D);
  static const primary2 = Color(0xFF22C55E);
  static const blue = Color(0xFF176BCA);
  static const green = Color(0xFF16A34A);
  static const red = Color(0xFFD64545);
  static const amber = Color(0xFFD99A00);
  static const violet = Color(0xFF7C3AED);

  static const darkOverlay = Color(0x99000000);
}


String _normalizeMetricCode(String code) {
  switch (code.trim()) {
    case 'interception_ball':
      return 'interception';
    case 'recovery_ball':
      return 'recovery';

    case 'pass_forward_short':
      return 'forward_short';
    case 'pass_forward_medium':
      return 'forward_medium';
    case 'pass_forward_long':
      return 'forward_long';

    case 'pass_side_short':
      return 'side_short';
    case 'pass_side_medium':
      return 'side_medium';
    case 'pass_side_long':
      return 'side_long';

    case 'pass_back_short':
      return 'back_short';
    case 'pass_back_medium':
      return 'back_medium';
    case 'pass_back_long':
      return 'back_long';

    case 'gk_hand_distribution':
      return 'hand_distribution';
    case 'gk_coming_out':
      return 'coming_out';
    case 'gk_close_combat':
      return 'close_combat';
    case 'gk_interceptions':
      return 'interceptions';
    case 'gk_outside_box':
      return 'outside_box';
    case 'gk_pass_short':
      return 'pass_short';
    case 'gk_pass_medium':
      return 'pass_medium';
    case 'gk_pass_long':
      return 'pass_long';
    case 'gk_saves':
      return 'saves';
    case 'gk_conceded':
      return 'conceded';

    default:
      return code.trim();
  }
}

class _VideoMatchReviewScreenState extends State<VideoMatchReviewScreen>
    with SingleTickerProviderStateMixin {
     
     void _bindAiTrackToPlayer() {
  debugPrint('bind ai track tapped');
}

void _jumpToTime(int timeMs) {
  if (!_controller.value.isInitialized) return;
  _controller.seekTo(Duration(milliseconds: timeMs));
}

void _exportAiAnalysis() {
  debugPrint('export ai analysis tapped');
}

Future<void> _confirmTopAiSuggestions() async {
  final suggestions = _aiTracking.ttdSuggestions
      .where((e) => e.confidence >= 0.75)
      .take(20)
      .toList();

  if (suggestions.isEmpty) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Нет уверенных AI-подсказок')),
    );
    return;
  }

  for (final s in suggestions) {
    await _confirmAiSuggestion(s);
  }

  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Подтверждено ${suggestions.length} AI-действий')),
  );
}
  
  bool _aiLoading = false;
  bool _aiUploading = false;
  double _aiUploadProgress = 0.0;
  bool _showAiPanel = true;


  ReviewOverlayPanel _activeOverlayPanel = ReviewOverlayPanel.none;
  

  bool _showOverlayUi = true;
  bool _showBottomQuickDock = true;
  bool _showTopCompactBar = true;
  bool _showRightRail = true;
  bool _quickTtdCollapsed = true;

  bool _isImmersiveVideoMode = true;
  bool _autoHideOverlayEnabled = false;
  bool _showDetectedBall = true;
  bool _showBallTrail = true;
  bool _showPassArrows = true;
  bool _showZones = true;

  Timer? _overlayAutoHideTimer;

  late VideoPlayerController _controller;
  late TabController _tabController;
  late final AiTrackingController _aiTracking;
  late final PythonTrackingService _pythonTrackingService;
  late final AiVideoAnalysisController _aiServerController;
  late TeamVisualConfig _myTeamConfig;
  late TeamVisualConfig _opponentTeamConfig;


final bool _useServerAi = true;
bool _isLoadingServerFrame = false;
  
  Widget _buildActionRailOnly() {
  return Align(
    alignment: Alignment.center,
    child: Container(
      width: 64,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: ReviewUiPalette.panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ReviewUiPalette.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildRailButton(
            icon: Icons.flash_on_rounded,
            isActive: _isPanelOpen(ReviewOverlayPanel.ttd),
            onTap: () => _togglePanel(ReviewOverlayPanel.ttd),
            tooltip: 'TTD',
          ),
          const SizedBox(height: 10),
          _buildRailButton(
            icon: Icons.person_outline_rounded,
            isActive: _isPanelOpen(ReviewOverlayPanel.players),
            onTap: () => _togglePanel(ReviewOverlayPanel.players),
            tooltip: 'Игроки',
          ),
          const SizedBox(height: 10),
          _buildRailButton(
            icon: Icons.video_library_outlined,
            isActive: _isPanelOpen(ReviewOverlayPanel.episodes),
            onTap: () => _togglePanel(ReviewOverlayPanel.episodes),
            tooltip: 'Эпизоды',
          ),
          const SizedBox(height: 10),
          _buildRailButton(
            icon: Icons.analytics_outlined,
            isActive: _isPanelOpen(ReviewOverlayPanel.analytics),
            onTap: () => _togglePanel(ReviewOverlayPanel.analytics),
            tooltip: 'AI',
          ),
        ],
      ),
    ),
  );
}


void _openTtdEventDetail(Map<String, dynamic> event) {
  Navigator.push(
    context,
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (context) => episode_detail.EpisodeTtdDetailScreen(
        initialEvent: event,
        videoId: widget.videoId,
        players: _matchPlayers.isNotEmpty ? _matchPlayers : _players,
        matchId: widget.matchId,
        teamId: widget.teamId,
        coachId: widget.coachId,
        onEpisodeUpdated: () async {
          await _loadMatchDataLight();
          if (mounted) setState(() {});
        },
      ),
    ),
  );
}



String? _buildLocalVideoPathFromUrl(String? url) {
  if (url == null || url.isEmpty) return null;

  const marker = '/uploads/';
  final index = url.indexOf(marker);
  if (index == -1) return null;

  final relative = url.substring(index);
  return '/var/www/sportoteka$relative';
}

Future<void> _startServerAiAnalysis() async {
  if (_aiLoading) return;

  if (mounted) {
    setState(() {
      _aiLoading = true;
      _aiStatusText = 'Запуск AI анализа...';
    });
  }

  try {
    final localVideoPath = _buildLocalVideoPathFromUrl(widget.videoUrl);

    final createdJobId = await _aiServerController.createAnalysisJob(
      matchId: widget.matchId,
      videoUrl: widget.videoUrl,
      localVideoPath: localVideoPath,
    );
debugPrint('STEP 1 createdJobId = $createdJobId'); 
    if (createdJobId == null || createdJobId.isEmpty) {
      if (mounted) {
        setState(() {
          _aiLoading = false;
          _aiStatusText =
              'Ошибка запуска AI: ${_aiServerController.errorText ?? 'unknown'}';
        });
      }
      return;
    }

    final runResult = await _aiServerController.runAnalysisJob(
      samplingFps: 1.0,
      maxMinutes: 2.0,
    );
debugPrint('STEP 2 runResult = $runResult');
debugPrint('STEP 2 tracking=${identityHashCode(_aiTracking)}');
    debugPrint('AI RUN RESULT = $runResult');

    if (runResult == null) {
      if (mounted) {
        setState(() {
          _aiLoading = false;
          _aiStatusText =
              'Не удалось запустить обработку: ${_aiServerController.errorText ?? 'unknown'}';
        });
      }
      return;
    }

    _aiTracking.applyServerAnalysis(runResult);

    debugPrint('AFTER RUN APPLY aiSummary = ${_aiTracking.aiSummary}');
    debugPrint('AFTER RUN APPLY aiMatchStats = ${_aiTracking.aiMatchStats}');

    final rawStatus = await _aiServerController.loadJobStatus();
debugPrint('STEP 4 rawStatus = $rawStatus');
    debugPrint('AI RAW STATUS = $rawStatus');

    if (rawStatus != null) {
        debugPrint('STEP 3 BEFORE APPLY');
         debugPrint('STEP 5 BEFORE RAW APPLY');
      _aiTracking.applyServerAnalysis(rawStatus);
debugPrint('STEP 3 AFTER APPLY aiSummary = ${_aiTracking.aiSummary}');
debugPrint('STEP 3 AFTER APPLY aiMatchStats = ${_aiTracking.aiMatchStats}');
 debugPrint('STEP 5 AFTER RAW APPLY aiSummary = ${_aiTracking.aiSummary}');
  debugPrint('STEP 5 AFTER RAW APPLY aiMatchStats = ${_aiTracking.aiMatchStats}');
    }

    final eventsCount =
        (rawStatus?['events'] as List?)?.length ??
        (runResult['events'] as List?)?.length ??
        0;

    final ttdCount =
        (rawStatus?['auto_ttd'] as List?)?.length ??
        (runResult['auto_ttd'] as List?)?.length ??
        0;

    if (mounted) {
      setState(() {
        _aiLoading = false;
        _aiStatusText = 'AI готов: $eventsCount событий, $ttdCount ТТД';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'AI анализ завершен! Найдено $eventsCount событий и $ttdCount ТТД',
          ),
          backgroundColor: Colors.green,
        ),
      );
    }

    if (_controller.value.isInitialized) {
      final currentMs = _controller.value.position.inMilliseconds;
      final packet = await _aiServerController.loadFramePacket(currentMs);
      if (packet != null) {
        _applyServerPacketToOverlay(packet);
      }
    }
  } catch (e, st) {
    debugPrint('AI START ERROR = $e');
    debugPrint('$st');

    if (mounted) {
      setState(() {
        _aiLoading = false;
        _aiStatusText = 'Ошибка AI: $e';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка AI анализа: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}


 void _onVideoPositionChanged() {
  if (!_aiServerController.isReady) return;
  if (!_controller.value.isInitialized) return;

  final currentMs = _controller.value.position.inMilliseconds;
  _aiServerController.loadFramePacketDebounced(currentMs);
}
 




Widget _buildPassNetworkBadge() {
  if (!_aiTracking.showPassNetwork || _aiTracking.passEdges.isEmpty) {
    return const SizedBox.shrink();
  }

  final topEdges = List.of(_aiTracking.passEdges)
    ..sort((a, b) => b.count.compareTo(a.count));

  final visible = topEdges.take(3).toList();

  return Positioned(
    right: 14,
    bottom: 14,
    child: Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.94),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ReviewUiPalette.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Связи передач',
            style: TextStyle(
              color: ReviewUiPalette.text,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          ...visible.map((e) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '${e.fromTrackId} → ${e.toTrackId} · ${e.count}',
                style: const TextStyle(
                  color: ReviewUiPalette.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          }),
        ],
      ),
    ),
  );
}



void _applyServerPacketToOverlay(AiFramePacket packet) {
  debugPrint('APPLY PACKET: ${packet.tracks.length} tracks');

  final mappedTracks = mapServerTracksToPlayerTracks(packet.tracks);

  debugPrint('MAPPED TRACKS: ${mappedTracks.length}');

  _aiTracking.tracks = mappedTracks;

  if (mappedTracks.isNotEmpty) {
    final selectedId = _aiTracking.selectedTrackId;

    PlayerTrack selected = mappedTracks.first;

    if (selectedId != null) {
      final match = mappedTracks.where((e) => e.id == selectedId).toList();
      if (match.isNotEmpty) {
        selected = match.first;
      }
    }

    _aiTracking.lockedTrack = selected;
    _aiTracking.selectedTrackId = selected.id;
    _aiTracking.selectedTrack = selected;
    _aiTracking.isLocked = true;
  } else {
    _aiTracking.lockedTrack = null;
    _aiTracking.selectedTrack = null;
    _aiTracking.selectedTrackId = null;
    _aiTracking.isLocked = false;
  }

  _aiTracking.notifyListeners();
}
     
    Widget _buildRailButton({
  required IconData icon,
  required bool isActive,
  required VoidCallback onTap,
  String? tooltip,
}) {
  final button = Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: () {
        _showOverlay();
        onTap();
      },
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          gradient: isActive
              ? const LinearGradient(
                  colors: [ReviewUiPalette.primary, ReviewUiPalette.primary2],
                )
              : null,
          color: isActive ? null : ReviewUiPalette.panelSoft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive ? ReviewUiPalette.primary : ReviewUiPalette.line,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: ReviewUiPalette.primary.withOpacity(0.20),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ]
              : const [],
        ),
        child: Icon(
          icon,
          color: isActive ? Colors.white : ReviewUiPalette.textMuted,
          size: 20,
        ),
      ),
    ),
  );

  if (tooltip == null || tooltip.isEmpty) return button;

  return Tooltip(
    message: tooltip,
    child: button,
  );
}



  double _openedPanelWidth() {
    if (_activeOverlayPanel == ReviewOverlayPanel.none) return 0;
    return 420 + 82 + 14; 
    // panel width + right rail area + outer gap
  }


  bool _showHeatmap = false;
  bool _episodesCollapsed = false;
  bool _aiFrameProcessing = false;
  bool _isCalibrating = false;
  bool _videoReady = false;
  bool _loading = true;
  bool _saving = false;
  bool _quickSaving = false;
  
  bool _reportLoading = false;
  bool _creatingEpisode = false;

  // В embedded-режиме обычный setState увеличивал видео только внутри вкладки.
  // Для настоящего полноэкранного режима открываем отдельный root route поверх
  // TeamMatchDetailScreen / ClubWorkspace, но используем тот же VideoPlayerController.
  bool _isVideoFullscreen = false;
  bool _fullscreenRouteOpen = false;

  bool _showAiPanelInline = false;
  bool _isSimpleMode = false;
  bool _quickSummaryCollapsed = true;
  
  Size? _lastAiOverlaySize;
BoxFit _lastAiOverlayFit = BoxFit.contain;

Offset? _lastTapMarkerPosition;
bool _showTapMarker = false;
Timer? _tapMarkerTimer;

  Offset? _firstCalibrationPoint;
  Offset? _secondCalibrationPoint;

  String _bottomPanelSection = 'ttd';
  String _aiStatusText = 'AI анализ не запущен';
  String? _expandedQuickMetricCode;

String _formatAiTime(int ms) {
  final totalSeconds = ms ~/ 1000;
  final minutes = totalSeconds ~/ 60;
  final seconds = totalSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}



  final TransformationController _videoTransformController =
      TransformationController();
  
  List<Map<String, dynamic>> _players = [];
  List<Map<String, dynamic>> _episodes = [];
  List<Map<String, dynamic>> _filteredPlayers = [];
  List<Map<String, dynamic>> _allTeamPlayers = [];
  List<Map<String, dynamic>> _matchPlayers = [];


  List<Map<String, dynamic>> _mainReportRows = [];
  List<Map<String, dynamic>> _passReportRows = [];
  List<Map<String, dynamic>> _goalkeeperReportRows = [];
  
  
 
 Map<String, dynamic>? _selectedPlayer;
Map<String, dynamic>? _selectedEpisode;

Map<String, dynamic>? _lastTtdAction;
bool _undoInProgress = false;

 
  Timer? _lightReloadTimer;

  Map<String, dynamic>? _findEpisodeNearCurrentTime({
    required int currentSeconds,
    int toleranceSeconds = 2,
  }) {
    for (final episode in _episodes) {
      final epSec = _i(episode['timecode_seconds']);
      if ((epSec - currentSeconds).abs() <= toleranceSeconds) {
        return episode;
      }
    }
    return null;
  }
  
  double _adaptiveRailWidth(double screenWidth) {
  if (screenWidth < 900) return 64;
  if (screenWidth < 1200) return 72;
  return 76;
}

double _adaptivePanelWidth(double screenWidth) {
  if (screenWidth < 900) {
    return 300;
  }
  if (screenWidth < 1200) {
    return 360;
  }
  return 420;
}


double _adaptiveGap(double screenWidth) {
  if (screenWidth < 900) return 8;
  if (screenWidth < 1200) return 10;
  return 12;
}
  
  
    Widget _buildMiniAnalyticsBoard() {
    final total = _videoAllTotal();
    final success = _videoSuccessTotal();
    final fail = _videoFailTotal();
    final single = _videoSingleTotal();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildMiniAnalyticsRow(
            title: 'Успешно / Неудачно',
            leftValue: success,
            rightValue: fail,
            leftColor: const Color(0xFF16A34A),
            rightColor: const Color(0xFFDC2626),
          ),
          const SizedBox(height: 14),
          _buildMiniAnalyticsRow(
            title: 'TTD / Счёт',
            leftValue: total,
            rightValue: single,
            leftColor: const Color(0xFF1F7A4D),
            rightColor: const Color(0xFFF59E0B),
          ),
          const SizedBox(height: 14),
          _buildMiniPercentRow(
            title: 'Эффективность',
            leftPercent: success,
            rightPercent: fail,
            leftColor: const Color(0xFF16A34A),
            rightColor: const Color(0xFFCBD5E1),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniAnalyticsRow({
    required String title,
    required int leftValue,
    required int rightValue,
    required Color leftColor,
    required Color rightColor,
  }) {
    final total = (leftValue + rightValue) == 0 ? 1 : (leftValue + rightValue);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            SizedBox(
              width: 36,
              child: Text(
                '$leftValue',
                textAlign: TextAlign.left,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: leftColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: Row(
                  children: [
                    Expanded(
                      flex: leftValue == 0 ? 1 : leftValue,
                      child: Container(
                        height: 6,
                        color: leftColor,
                      ),
                    ),
                    Expanded(
                      flex: rightValue == 0 ? 1 : rightValue,
                      child: Container(
                        height: 6,
                        color: rightColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 36,
              child: Text(
                '$rightValue',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: rightColor,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMiniPercentRow({
    required String title,
    required int leftPercent,
    required int rightPercent,
    required Color leftColor,
    required Color rightColor,
  }) {
    final total = leftPercent + rightPercent;
    final left = total == 0 ? 0 : ((leftPercent / total) * 100).round();
    final right = total == 0 ? 0 : 100 - left;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            SizedBox(
              width: 42,
              child: Text(
                '$left%',
                textAlign: TextAlign.left,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: leftColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: Row(
                  children: [
                    Expanded(
                      flex: left == 0 ? 1 : left,
                      child: Container(
                        height: 6,
                        color: leftColor,
                      ),
                    ),
                    Expanded(
                      flex: right == 0 ? 1 : right,
                      child: Container(
                        height: 6,
                        color: rightColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 42,
              child: Text(
                '$right%',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildVideoCanvas() {
  final bool panelOpen = _activeOverlayPanel != ReviewOverlayPanel.none;

  return ClipRRect(
    borderRadius: BorderRadius.circular(_isVideoFullscreen ? 0 : 22),
    child: Container(
      color: ReviewUiPalette.bg,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          final railWidth = _adaptiveRailWidth(totalWidth);
          final panelWidth = panelOpen ? _adaptivePanelWidth(totalWidth) : 0.0;
          final gap = _adaptiveGap(totalWidth);
          final railGap = widget.railOnLeft ? gap : 0.0;
          final videoWidth = totalWidth -
              railWidth -
              railGap -
              (panelOpen ? panelWidth + gap : 0);

          final rail = SizedBox(
            width: railWidth,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: _buildRightMainRail(),
            ),
          );

          final panel = SizedBox(
            width: panelWidth,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: _buildCenterSlidingPanel(),
            ),
          );

          final video = SizedBox(
            width: videoWidth.clamp(260.0, totalWidth).toDouble(),
            child: Container(
              margin: EdgeInsets.all(_isVideoFullscreen ? 0 : 10),
              decoration: BoxDecoration(
                color: ReviewUiPalette.panel,
                borderRadius: BorderRadius.circular(_isVideoFullscreen ? 0 : 18),
                border: Border.all(color: ReviewUiPalette.line),
                boxShadow: _isVideoFullscreen
                    ? const []
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(_isVideoFullscreen ? 0 : 18),
                child: Column(
                  children: [
                    if (widget.showInternalVideoControls)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                        child: _buildTopVideoTimelineBar(),
                      ),
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          10,
                          widget.showInternalVideoControls ? 0 : 10,
                          10,
                          10,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            color: Colors.black,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                _buildVideoSection(),
                                _buildSelectedPlayerOverlayCard(),
                                _buildSelectedEpisodeOverlayBadge(),
                                _buildBottomPlayersStrip(),
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

          return Row(
            children: [
              if (widget.railOnLeft) ...[
                rail,
                SizedBox(width: gap),
              ],
              video,
              if (panelOpen) ...[
                SizedBox(width: gap),
                panel,
              ],
              if (!widget.railOnLeft) rail,
            ],
          );
        },
      ),
    ),
  );
}


Widget _buildTopVideoTimelineBar() {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: ReviewUiPalette.panelSoft,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: ReviewUiPalette.line),
    ),
    child: Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: ReviewUiPalette.primary.withOpacity(0.10),
            borderRadius: BorderRadius.circular(11),
          ),
          child: IconButton(
            padding: EdgeInsets.zero,
            onPressed: _togglePlayPause,
            icon: Icon(
              _controller.value.isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              color: ReviewUiPalette.primary,
              size: 19,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          Formatters.formatDuration(_controller.value.position),
          style: const TextStyle(
            color: ReviewUiPalette.text,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: VideoProgressIndicator(
              _controller,
              allowScrubbing: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              colors: const VideoProgressColors(
                playedColor: ReviewUiPalette.primary,
                bufferedColor: Color(0xFFA8CDB8),
                backgroundColor: Color(0xFFE6EDF3),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          Formatters.formatDuration(_controller.value.duration),
          style: const TextStyle(
            color: ReviewUiPalette.textMuted,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 10),
        _buildTimelineIconButton(Icons.replay_10_rounded, () => _seekRelative(-10)),
        const SizedBox(width: 6),
        _buildTimelineIconButton(Icons.forward_10_rounded, () => _seekRelative(10)),
        const SizedBox(width: 6),
        _buildTimelineIconButton(Icons.camera_alt_outlined, _createEpisodeFromCurrentFrame),
        const SizedBox(width: 6),
        _buildTimelineIconButton(Icons.fullscreen_rounded, _toggleFullscreen),
      ],
    ),
  );
}

Widget _buildTimelineIconButton(IconData icon, VoidCallback onTap) {
  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: Ink(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: ReviewUiPalette.line),
        ),
        child: Icon(icon, color: ReviewUiPalette.textMuted, size: 18),
      ),
    ),
  );
}


Widget _buildCenterSlidingPanel() {
  return AnimatedContainer(
    duration: const Duration(milliseconds: 260),
    curve: Curves.easeOutCubic,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(28),
      border: Border.all(color: const Color(0xFFE2E8F0)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.08),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: Column(
      children: [
        _buildSlidingPanelHeader(),
        const Divider(height: 1),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(28),
              ),
              child: Container(
                color: const Color(0xFFF8FBFF),
                child: _buildActivePanelBody(),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildSlidingOverlayPanelLeftInline() {
  return Align(
    alignment: Alignment.topCenter,
    child: Container(
      margin: const EdgeInsets.only(top: 20, bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSlidingPanelHeader(),
          const Divider(height: 1),
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(28),
              ),
              child: Container(
                color: const Color(0xFFF8FBFF),
                child: _buildActivePanelBody(),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
Widget _buildPureVideoWorkArea() {
  return Stack(
    fit: StackFit.expand,
    children: [
      _buildVideoSection(),
      _buildSelectedPlayerOverlayCard(),
      _buildSelectedEpisodeOverlayBadge(),
    ],
  );
}

Widget _buildTopVideoControlsBar() {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withOpacity(0.10)),
    ),
    child: Row(
      children: [
        _glassIconButton(
          icon: Icons.arrow_back_rounded,
          onTap: _confirmCloseReview,
        ),
        const SizedBox(width: 8),
        _glassIconButton(
          icon: Icons.replay_10_rounded,
          onTap: () => _seekRelative(-10),
        ),
        const SizedBox(width: 8),
        _glassIconButton(
          icon: _controller.value.isPlaying
              ? Icons.pause_rounded
              : Icons.play_arrow_rounded,
          onTap: _togglePlayPause,
          active: true,
        ),
        const SizedBox(width: 8),
        _glassIconButton(
          icon: Icons.forward_10_rounded,
          onTap: () => _seekRelative(10),
        ),
        const SizedBox(width: 8),
        _glassIconButton(
          icon: Icons.fullscreen_rounded,
          onTap: _toggleFullscreen,
        ),
        const SizedBox(width: 12),
        Text(
          Formatters.formatDuration(_controller.value.position),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: VideoProgressIndicator(
            _controller,
            allowScrubbing: true,
            padding: const EdgeInsets.symmetric(vertical: 6),
            colors: const VideoProgressColors(
              playedColor: Colors.white,
              bufferedColor: Colors.white30,
              backgroundColor: Colors.white12,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          Formatters.formatDuration(_controller.value.duration),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

Widget _buildBottomControlsBar() {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withOpacity(0.10)),
    ),
    child: Row(
      children: [
        Text(
          Formatters.formatDuration(_controller.value.position),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: VideoProgressIndicator(
            _controller,
            allowScrubbing: true,
            padding: const EdgeInsets.symmetric(vertical: 6),
            colors: const VideoProgressColors(
              playedColor: Colors.white,
              bufferedColor: Colors.white30,
              backgroundColor: Colors.white12,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Text(
          Formatters.formatDuration(_controller.value.duration),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 14),
        _glassIconButton(
          icon: Icons.replay_10_rounded,
          onTap: () => _seekRelative(-10),
        ),
        const SizedBox(width: 8),
        _glassIconButton(
          icon: _controller.value.isPlaying
              ? Icons.pause_rounded
              : Icons.play_arrow_rounded,
          onTap: _togglePlayPause,
          active: true,
        ),
        const SizedBox(width: 8),
        _glassIconButton(
          icon: Icons.forward_10_rounded,
          onTap: () => _seekRelative(10),
        ),
        const SizedBox(width: 8),
        _glassIconButton(
          icon: Icons.fullscreen_rounded,
          onTap: _toggleFullscreen,
        ),
      ],
    ),
  );
}

Widget _buildRightMainRail() {
  return Align(
    alignment: Alignment.center,
    child: Container(
      width: 68,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: ReviewUiPalette.panel,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ReviewUiPalette.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildRailSectionLabel('АНАЛИЗ'),
            const SizedBox(height: 8),
            _buildRailButton(
              icon: Icons.flash_on_rounded,
              isActive: _isPanelOpen(ReviewOverlayPanel.ttd),
              onTap: () => _togglePanel(ReviewOverlayPanel.ttd),
              tooltip: 'TTD',
            ),
            const SizedBox(height: 10),
            _buildRailButton(
              icon: Icons.person_outline_rounded,
              isActive: _isPanelOpen(ReviewOverlayPanel.players),
              onTap: () => _togglePanel(ReviewOverlayPanel.players),
              tooltip: 'Игроки',
            ),
            const SizedBox(height: 10),
            _buildRailButton(
              icon: Icons.video_library_outlined,
              isActive: _isPanelOpen(ReviewOverlayPanel.episodes),
              onTap: () => _togglePanel(ReviewOverlayPanel.episodes),
              tooltip: 'Эпизоды',
            ),
            const SizedBox(height: 10),
            _buildRailButton(
              icon: Icons.analytics_outlined,
              isActive: _isPanelOpen(ReviewOverlayPanel.analytics),
              onTap: () => _togglePanel(ReviewOverlayPanel.analytics),
              tooltip: 'AI',
            ),
            const SizedBox(height: 14),
            _buildRailDivider(),
            const SizedBox(height: 12),
            _buildRailSectionLabel('ОТЧЁТ'),
            const SizedBox(height: 8),
            _buildRailButton(
              icon: Icons.assessment_rounded,
              isActive: _tabController.index == 1,
              onTap: () => _tabController.animateTo(1),
              tooltip: 'Отчёт',
            ),
            const SizedBox(height: 14),
            _buildRailDivider(),
            const SizedBox(height: 12),
            _buildRailSectionLabel('ВИДЕО'),
            const SizedBox(height: 8),
            _buildRailButton(
              icon: Icons.replay_10_rounded,
              isActive: false,
              onTap: () => _seekRelative(-10),
              tooltip: '-10',
            ),
            const SizedBox(height: 10),
            _buildRailButton(
              icon: _controller.value.isPlaying
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              isActive: false,
              onTap: _togglePlayPause,
              tooltip: 'Play',
            ),
            const SizedBox(height: 10),
            _buildRailButton(
              icon: Icons.forward_10_rounded,
              isActive: false,
              onTap: () => _seekRelative(10),
              tooltip: '+10',
            ),
            const SizedBox(height: 10),
            _buildRailButton(
              icon: Icons.fullscreen_rounded,
              isActive: false,
              onTap: _toggleFullscreen,
              tooltip: 'Full',
            ),
          ],
        ),
      ),
    ),
  );
}

Widget _buildRailSectionLabel(String text) {
  return Text(
    text,
    textAlign: TextAlign.center,
    style: const TextStyle(
      color: ReviewUiPalette.textMuted,
      fontSize: 9,
      fontWeight: FontWeight.w900,
      letterSpacing: 0.8,
    ),
  );
}


Widget _buildRailDivider() {
  return Container(
    width: 28,
    height: 1,
    color: ReviewUiPalette.line,
  );
}


Widget _buildSlidingOverlayPanelInline() {
  return Align(
    alignment: Alignment.topCenter,
    child: Container(
      margin: const EdgeInsets.only(top: 90, bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSlidingPanelHeader(),
          const Divider(height: 1),
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(28),
              ),
              child: Container(
                color: const Color(0xFFF8FBFF),
                child: _buildActivePanelBody(),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
  
      Widget _buildTopGradientOverlay() {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: Container(
          height: 120,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.22),
                Colors.black.withOpacity(0.08),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }
    
     Widget _buildBottomGradientOverlay() {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          height: 140,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Colors.black.withOpacity(0.24),
                Colors.black.withOpacity(0.08),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }  
  
  
    void _toggleQuickTtdCollapsed() {
    if (!mounted) return;
    setState(() {
      _quickTtdCollapsed = !_quickTtdCollapsed;
      _showOverlayUi = true;
      _showBottomQuickDock = true;
      _showRightRail = true;
      _showTopCompactBar = true;
    });
  }
  
  
  
 void _restartOverlayAutoHide() {
  _overlayAutoHideTimer?.cancel();

  if (!_autoHideOverlayEnabled) return;
  if (_activeOverlayPanel != ReviewOverlayPanel.none) return;
  if (_isVideoFullscreen) return;


  _overlayAutoHideTimer = Timer(const Duration(seconds: 4), () {
    if (!mounted) return;
    setState(() {
      _showOverlayUi = true;
      _showBottomQuickDock = true;
      _showTopCompactBar = true;
      _showRightRail = true;
    });
  });
}

void _showOverlay() {
  if (!mounted) return;
  setState(() {
    _showOverlayUi = true;
    _showBottomQuickDock = true;
    _showTopCompactBar = true;
    _showRightRail = true;
  });
  _restartOverlayAutoHide();
}
void _toggleOverlay() {
  final shouldShow = !_showOverlayUi;

  if (!mounted) return;
  setState(() {
    _showOverlayUi = shouldShow;
    _showBottomQuickDock = shouldShow;
    _showTopCompactBar = shouldShow;

    // правое меню всегда оставляем
    _showRightRail = true;

    if (!shouldShow) {
      _activeOverlayPanel = ReviewOverlayPanel.none;
    }
  });

  if (shouldShow) {
    _restartOverlayAutoHide();
  } else {
    _overlayAutoHideTimer?.cancel();
  }
}   
  void _togglePanel(ReviewOverlayPanel panel) {
    if (!mounted) return;

    setState(() {
      if (_activeOverlayPanel == panel) {
        _activeOverlayPanel = ReviewOverlayPanel.none;
      } else {
        _activeOverlayPanel = panel;
      }

      _showOverlayUi = true;
      _showBottomQuickDock = true;
      _showTopCompactBar = true;
      _showRightRail = true;
    });

    _notifyPlaybackBridge();
    _restartOverlayAutoHide();
  }

  void _closePanels() {
    if (!mounted) return;
    setState(() {
      _activeOverlayPanel = ReviewOverlayPanel.none;
    });
    _notifyPlaybackBridge();
    _restartOverlayAutoHide();
  }

  bool _isPanelOpen(ReviewOverlayPanel panel) {
    return _activeOverlayPanel == panel;
  }

  
  void _showTapPointMarker(Offset position) {
  _tapMarkerTimer?.cancel();

  setState(() {
    _lastTapMarkerPosition = position;
    _showTapMarker = true;
  });

  _tapMarkerTimer = Timer(const Duration(milliseconds: 900), () {
    if (!mounted) return;
    setState(() {
      _showTapMarker = false;
    });
  });
}
  void _toggleQuickMetricDetails(String code) {
  setState(() {
    _expandedQuickMetricCode =
        _expandedQuickMetricCode == code ? null : code;
  });
}

void _rememberLastTtdAction({
  required int eventId,
  required String metricCode,
  required bool isPositive,
  required bool isSingle,
  required int delta,
  required String title,
}) {
  _lastTtdAction = {
    'event_id': eventId,
    'metric_code': metricCode,
    'is_positive': isPositive,
    'is_single': isSingle,
    'delta': delta,
    'title': title,
    'player_id': _selectedPlayer != null ? _i(_selectedPlayer!['id']) : 0,
    'episode_id': _selectedEpisode != null ? _i(_selectedEpisode!['id']) : 0,
    'video_id': widget.videoId,
  };
}

void _showUndoSnackBar(String text) {
  if (!mounted) return;

  ScaffoldMessenger.of(context).hideCurrentSnackBar();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(text),
      duration: const Duration(seconds: 4),
      action: SnackBarAction(
        label: 'Отменить',
        onPressed: () async {
          await _undoLastTtdAction();
        },
      ),
    ),
  );
}

Widget _buildAiQuickLaunchCard() {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: const Color(0xFFE2E8F0)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.03),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.auto_graph_rounded,
                color: Color(0xFF1F7A4D),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'AI Match Analysis',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
            Switch.adaptive(
              value: _showAiPanel,
              onChanged: (v) {
                setState(() {
                  _showAiPanel = v;
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          _aiStatusText,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w600,
          ),
        ),
        if (_aiUploading) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: _aiUploadProgress.clamp(0.0, 1.0),
              minHeight: 8,
            ),
          ),
        ],
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _aiLoading ? null : _startServerAiAnalysis,
                icon: _aiLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.smart_toy_outlined),
                label: Text(_aiLoading ? 'AI работает...' : 'Запустить AI'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1F7A4D),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

Widget _buildAiAnalysisSection() {
  if (!_showAiPanel) {
    return const SizedBox.shrink();
  }

  return AiAnalyticsPanelWidget(
  aiTracking: _aiTracking,
  showHeatmap: _showHeatmap,
  statusText: _aiStatusText,
  myTeamName: _myTeamConfig.displayName,
  opponentTeamName: _opponentTeamConfig.displayName,
   myTeamTag: _sideTagToString(_myTeamConfig.sideTag),
  onToggleAi: () {
    _startServerAiAnalysis();
  },
  onToggleHeatmap: (value) {
    setState(() {
      _showHeatmap = value;
    });
  },
  onBindTrack: _bindAiTrackToPlayer,
  onJumpToTime: _jumpToTime,
  onExport: _exportAiAnalysis,
  onConfirmSuggestion: _confirmAiSuggestion,
   onConfirmTopAi: _confirmTopAiSuggestions,
     onOpenTeamSetup: _openTeamIdentitySheet,
);
}


  Widget _buildTopTabSwitcher() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTopTabButton(
            title: 'Видео',
            icon: Icons.play_circle_rounded,
            selected: _tabController.index == 0,
            onTap: () {
              _tabController.animateTo(0);
              _showOverlay();
            },
          ),
          const SizedBox(width: 4),
          _buildTopTabButton(
            title: 'Отчёт',
            icon: Icons.analytics_outlined,
            selected: _tabController.index == 1,
            onTap: () {
              _tabController.animateTo(1);
              _showOverlay();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTopTabButton({
    required String title,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    colors: [Color(0xFF1F7A4D), Color(0xFF22C55E)],
                  )
                : null,
            color: selected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 15,
                color: Colors.white,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernTopBar() {
  final selectedEpisodeId =
      _selectedEpisode != null ? _i(_selectedEpisode!['id']) : null;

  return AnimatedOpacity(
    duration: const Duration(milliseconds: 220),
    opacity: _showTopCompactBar ? 1 : 0,
    child: IgnorePointer(
      ignoring: !_showTopCompactBar,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 14, 14, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: Colors.white.withOpacity(0.10),
          ),
          boxShadow: const [],
        ),
        child: Row(
          children: [
            _glassIconButton(
              icon: Icons.arrow_back_rounded,
              onTap: _confirmCloseReview,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.matchTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.teamName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.72),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            _buildTopTabSwitcher(),
           if (selectedEpisodeId != null) ...[
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.10),
                  ),
                ),
                child: Text(
                  'EP-$selectedEpisodeId',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 10),
            _glassIconButton(
              icon: Icons.refresh_rounded,
              onTap: () async {
                await _loadPlayers();
                await _loadMatchData();
                await _loadSavedMatchPlayers();
              },
            ),
          ],
        ),
      ),
    ),
  );
}



Future<void> _confirmAiSuggestion(AiTtdSuggestion suggestion) async {
  if (_selectedPlayer == null) {
    await _pickOwnPlayerForAi();
  }

  if (_selectedPlayer == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Игрок не выбран')),
    );
    return;
  }

  if (_aiTracking.lockedTrack != null &&
      _aiTracking.lockedTrack!.boundPlayerId == null) {
    _aiTracking.bindSelectedTrackToPlayer(
      playerId: _i(_selectedPlayer!['id']),
      playerName: _playerFullName(_selectedPlayer!),
    );
  }

  await _jumpToTrackingTime(suggestion.timeMs);

  final metricCode = _normalizeMetricCode(suggestion.code);
  final metricTitle = suggestion.title;
  final isSuccess = suggestion.success;

  int rating = 5;
  if (suggestion.confidence >= 0.85) {
    rating = 8;
  } else if (suggestion.confidence >= 0.70) {
    rating = 6;
  } else if (suggestion.confidence >= 0.55) {
    rating = 5;
  } else {
    rating = 4;
  }

  _noteCtrl.text =
      'Подтверждено из ИИ-анализа • уверенность ${(suggestion.confidence * 100).round()}%';

  await _saveQuickTtd(
  metricCode,
  metricTitle,
  isSuccess,
);

  if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${suggestion.title} сохранено для ${_playerFullName(_selectedPlayer!)}',
        ),
      ),
    );
  }
}

Future<void> _deleteLastTtdByType({
  required String metricCode,
  required bool isPositive,
  required String metricTitle,
}) async {
  if (_selectedPlayer == null) {
    _showTtdPanelMessage("Сначала выбери игрока", isError: true);
    return;
  }

  setState(() => _quickSaving = true);

  try {
    final normalizedMetricCode = _normalizeMetricCode(metricCode);
    
    // ИСПОЛЬЗУЕМ ТОТ ЖЕ API, ЧТО И ДЛЯ ЗАГРУЗКИ ДАННЫХ
    final response = await http.post(
      Uri.parse(ApiConstants.getMatchTtdReportUrl), // используем работающий API
      body: {"match_id": widget.matchId.toString()},
    ).timeout(const Duration(seconds: 15));
    
    final data = _decode(response);
    
    if (data["success"] != true) {
      _showTtdPanelMessage("Не удалось загрузить данные", isError: true);
      return;
    }
    
    // Получаем все события из эпизодов
    List<Map<String, dynamic>> allEvents = [];
    
    if (data["episodes"] is List) {
      for (var episode in data["episodes"]) {
        if (episode["children"] is List) {
          for (var child in episode["children"]) {
            allEvents.add(Map<String, dynamic>.from(child));
          }
        }
      }
    }
    
    // Фильтруем по игроку, типу и положительности
    final filtered = allEvents.where((e) {
      final eventPlayerId = _i(e['player_id']);
      final selectedPlayerId = _i(_selectedPlayer!["id"]);
      final eventType = _s(e['event_type']);
      final eventIsPositive = _i(e['is_positive']) == 1;
      
      return eventPlayerId == selectedPlayerId &&
             eventType == normalizedMetricCode &&
             eventIsPositive == isPositive;
    }).toList();
    
    if (filtered.isEmpty) {
      _showTtdPanelMessage(
        isPositive 
            ? "Нет удачных действий \"$metricTitle\" для удаления" 
            : "Нет неудачных действий \"$metricTitle\" для удаления",
        isError: true,
      );
      return;
    }
    
    // Сортируем по ID (новые сверху)
    filtered.sort((a, b) => _i(b['id']).compareTo(_i(a['id'])));
    final lastEvent = filtered.first;
    final eventId = _i(lastEvent['id']);
    
    // Удаляем событие
    final deleteResponse = await http.post(
      Uri.parse(ApiConstants.deleteEventUrl),
      body: {"event_id": eventId.toString()},
    ).timeout(const Duration(seconds: 15));
    
    final deleteData = _decode(deleteResponse);
    
    if (deleteData["success"] == true) {
      // Обновляем локальные счетчики
      final key = _ttdStorageKey(
        player: _selectedPlayer,
        episode: _selectedEpisode,
       
      );
      
      if (isPositive) {
        final current = _localSuccessCounters[normalizedMetricCode] ?? 0;
        if (current > 0) {
          if (current == 1) {
            _localSuccessCounters.remove(normalizedMetricCode);
          } else {
            _localSuccessCounters[normalizedMetricCode] = current - 1;
          }
        }
        
        // Обновляем кэш
        final map = Map<String, int>.from(_ttdSuccessCountersCache[key] ?? {});
        final newValue = (map[normalizedMetricCode] ?? 0) - 1;
        if (newValue <= 0) {
          map.remove(normalizedMetricCode);
        } else {
          map[normalizedMetricCode] = newValue;
        }
        _ttdSuccessCountersCache[key] = map;
      } else {
        final current = _localFailCounters[normalizedMetricCode] ?? 0;
        if (current > 0) {
          if (current == 1) {
            _localFailCounters.remove(normalizedMetricCode);
          } else {
            _localFailCounters[normalizedMetricCode] = current - 1;
          }
        }
        
        // Обновляем кэш
        final map = Map<String, int>.from(_ttdFailCountersCache[key] ?? {});
        final newValue = (map[normalizedMetricCode] ?? 0) - 1;
        if (newValue <= 0) {
          map.remove(normalizedMetricCode);
        } else {
          map[normalizedMetricCode] = newValue;
        }
        _ttdFailCountersCache[key] = map;
      }
      
      _needsCacheUpdate = true;
      _scheduleRebuild();
      await _loadMatchDataLight();
      
      _showTtdPanelMessage("$metricTitle • действие удалено");
      _showUndoSnackBar("$metricTitle удалено");
    } else {
      _showTtdPanelMessage(
        deleteData["message"]?.toString() ?? "Не удалось удалить",
        isError: true,
      );
    }
  } catch (e) {
    debugPrint('DELETE ERROR: $e');
    _showTtdPanelMessage("Ошибка: $e", isError: true);
  } finally {
    if (mounted) setState(() => _quickSaving = false);
  }
}

Future<void> _undoLastTtdAction() async {
  if (_undoInProgress) return;
  if (_lastTtdAction == null) return;

  _undoInProgress = true;

  try {
    final eventId = _i(_lastTtdAction!['event_id']);
    final metricCode = _s(_lastTtdAction!['metric_code']);
    final isPositive = _lastTtdAction!['is_positive'] == true;
    final isSingle = _lastTtdAction!['is_single'] == true;
    final delta = _i(_lastTtdAction!['delta']);

    final resp = await http.post(
      Uri.parse(ApiConstants.deleteEventUrl),
      body: {"event_id": eventId.toString()},
    ).timeout(const Duration(seconds: 15));

    final data = _decode(resp);

    if (data["success"] == true) {
      final key = _ttdStorageKey(
        player: _selectedPlayer,
        episode: _selectedEpisode,
       
      );

      final playerId = _selectedPlayerId();

      if (isSingle) {
        final current = (_ttdSingleCountersCache[key] ?? {})[metricCode] ?? 0;
        final next = math.max(0, current - delta.abs());

        final map = Map<String, int>.from(_ttdSingleCountersCache[key] ?? {});
        if (next == 0) {
          map.remove(metricCode);
        } else {
          map[metricCode] = next;
        }
        _ttdSingleCountersCache[key] = map;
        _localSingleCounters = Map<String, int>.from(map);

        if (playerId != null) {
          final vMap = Map<String, int>.from(_videoSingleCountersCache[playerId] ?? {});
          final vCurrent = vMap[metricCode] ?? 0;
          final vNext = math.max(0, vCurrent - delta.abs());
          if (vNext == 0) {
            vMap.remove(metricCode);
          } else {
            vMap[metricCode] = vNext;
          }
          _videoSingleCountersCache[playerId] = vMap;
        }
      } else {
        if (isPositive) {
          final current = (_ttdSuccessCountersCache[key] ?? {})[metricCode] ?? 0;
          final next = math.max(0, current - 1);

          final map = Map<String, int>.from(_ttdSuccessCountersCache[key] ?? {});
          if (next == 0) {
            map.remove(metricCode);
          } else {
            map[metricCode] = next;
          }
          _ttdSuccessCountersCache[key] = map;
          _localSuccessCounters = Map<String, int>.from(map);

          if (playerId != null) {
            final vMap = Map<String, int>.from(_videoSuccessCountersCache[playerId] ?? {});
            final vCurrent = vMap[metricCode] ?? 0;
            final vNext = math.max(0, vCurrent - 1);
            if (vNext == 0) {
              vMap.remove(metricCode);
            } else {
              vMap[metricCode] = vNext;
            }
            _videoSuccessCountersCache[playerId] = vMap;
          }
        } else {
          final current = (_ttdFailCountersCache[key] ?? {})[metricCode] ?? 0;
          final next = math.max(0, current - 1);

          final map = Map<String, int>.from(_ttdFailCountersCache[key] ?? {});
          if (next == 0) {
            map.remove(metricCode);
          } else {
            map[metricCode] = next;
          }
          _ttdFailCountersCache[key] = map;
          _localFailCounters = Map<String, int>.from(map);

          if (playerId != null) {
            final vMap = Map<String, int>.from(_videoFailCountersCache[playerId] ?? {});
            final vCurrent = vMap[metricCode] ?? 0;
            final vNext = math.max(0, vCurrent - 1);
            if (vNext == 0) {
              vMap.remove(metricCode);
            } else {
              vMap[metricCode] = vNext;
            }
            _videoFailCountersCache[playerId] = vMap;
          }
        }
      }

      _needsCacheUpdate = true;
      _scheduleRebuild();
      await _loadMatchDataLight();

      _showTtdPanelMessage("Последнее действие отменено");
      _lastTtdAction = null;
    } else {
      _showTtdPanelMessage("Не удалось отменить действие", isError: true);
    }
  } catch (_) {
    _showTtdPanelMessage("Ошибка отмены действия", isError: true);
  } finally {
    _undoInProgress = false;
  }
}

Widget _buildTapMarkerOverlay() {
  if (!_showTapMarker || _lastTapMarkerPosition == null) {
    return const SizedBox.shrink();
  }

  return Positioned(
    left: _lastTapMarkerPosition!.dx - 16,
    top: _lastTapMarkerPosition!.dy - 16,
    child: IgnorePointer(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF1F7A4D).withOpacity(0.18),
          border: Border.all(
            color: const Color(0xFF1F7A4D),
            width: 2.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1F7A4D).withOpacity(0.28),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Center(
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF1F7A4D),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    ),
  );
}

    Widget _buildSelectedPlayerOverlayCard() {
  if (_selectedPlayer == null) return const SizedBox.shrink();

  final photo = _playerPhoto(_selectedPlayer!);
  final fullName = _playerFullName(_selectedPlayer!);
  final position = _playerPosition(_selectedPlayer!);
  final totalActions = _videoAllTotal();

  return AnimatedPositioned(
    duration: const Duration(milliseconds: 240),
    curve: Curves.easeOutCubic,
    left: 18,
    bottom: 106,
    child: AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      opacity: _showOverlayUi ? 1 : 0,
      child: IgnorePointer(
        ignoring: !_showOverlayUi,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              width: 260,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.94),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: ReviewUiPalette.line),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: ReviewUiPalette.primary.withOpacity(0.10),
                    backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
                    child: photo.isEmpty
                        ? const Icon(Icons.person, color: ReviewUiPalette.primary)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: ReviewUiPalette.text,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          position.isEmpty ? 'Позиция не указана' : position,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: ReviewUiPalette.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: ReviewUiPalette.primary.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: ReviewUiPalette.primary.withOpacity(0.16)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '$totalActions',
                          style: const TextStyle(
                            color: ReviewUiPalette.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'TTD',
                          style: TextStyle(
                            color: ReviewUiPalette.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            height: 1,
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
      ),
    ),
  );
}


Widget _buildQuickInlineCounterBubble({
  required int value,
  required bool positive,
}) {
  final color = positive ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
  final bg = positive ? const Color(0xFFECFDF3) : const Color(0xFFFEF2F2);
  final border = positive ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA);

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: border),
    ),
    child: Text(
      '${positive ? '+' : '-'}$value',
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: color,
        height: 1,
      ),
    ),
  );
}

Widget _buildQuickSingleValueBubble({
  required int value,
}) {
  final positive = value >= 0;
  final color = positive ? const Color(0xFF16A34A) : const Color(0xFFDC2626);
  final bg = positive ? const Color(0xFFECFDF3) : const Color(0xFFFEF2F2);
  final border = positive ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA);

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: border),
    ),
    child: Text(
      '${positive ? '+' : ''}$value',
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: color,
        height: 1,
      ),
    ),
  );
}
  File? _currentSnapshotFile;
  int _currentSnapshotMs = 0;
  final Map<String, Map<String, int>> _ttdSingleCountersCache = {};
  final Map<String, Map<String, int>> _ttdSuccessCountersCache = {};
  final Map<String, Map<String, int>> _ttdFailCountersCache = {};
  final Map<String, int> _ttdRatingsCache = {};
  final Map<int, Map<String, int>> _videoSuccessCountersCache = {};
  final Map<int, Map<String, int>> _videoFailCountersCache = {};
  final Map<int, Map<String, int>> _videoSingleCountersCache = {};
  
  final TextEditingController _noteCtrl = TextEditingController();
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _playerSearchCtrl = TextEditingController();
  final TextEditingController _editTtdNoteCtrl = TextEditingController();

  String? _ttdPanelMessage;
  bool _ttdPanelMessageIsError = false;
  String _ttdSection = 'main';
  String _quickTtdSection = 'main';
  String _eventType = "goal";
  int _rating = 5;
  bool _isPositive = true;
  
  // Переменные для редактирования ТТД
  bool _isEditingTtd = false;
  Map<String, dynamic>? _selectedTtdEvent;
  String? _editingTtdMetricCode;
  String? _editingTtdMetricTitle;
  int _editingTtdValue = 0;
  bool _editingTtdIsPositive = true;
  int _editingTtdRating = 5;
  
  // ==================== ОПТИМИЗАЦИЯ: Добавленные переменные ====================
  int _cachedQuickSuccessTotal = 0;
  int _cachedQuickFailTotal = 0;
  int _cachedQuickSingleTotal = 0;
  bool _needsCacheUpdate = true;
  Timer? _debounceTimer;
  
  Map<String, int> _localSuccessCounters = {};
  Map<String, int> _localFailCounters = {};
  Map<String, int> _localSingleCounters = {};
  
  final ValueNotifier<int> _ttdUpdateNotifier = ValueNotifier<int>(0);
  
  // ==================== КОНЕЦ ОПТИМИЗАЦИИ ====================

@override
void initState() {
  super.initState();

  _aiTracking = AiTrackingController()
    ..addListener(() {
      if (mounted) setState(() {});
    });

  _myTeamConfig = TeamVisualConfig(
    sideTag: AnalysisSideTag.home,
    displayName: widget.teamName,
    primaryColor: const Color(0xFF16A34A),
    secondaryColor: const Color(0xFFFFFFFF),
    textColor: const Color(0xFFFFFFFF),
  );

  _opponentTeamConfig = const TeamVisualConfig(
    sideTag: AnalysisSideTag.away,
    displayName: 'Соперник',
    primaryColor: Color(0xFFFFFFFF),
    secondaryColor: Color(0xFF0F172A),
    textColor: Color(0xFF0F172A),
  );

  _initializeServices();
  _setupControllers();

  _aiServerController = AiVideoAnalysisController(
    service: AiVideoAnalysisService(
      baseUrl: 'https://sportotekaapp.ru/ai',
    ),
  );

  _loadInitialData();
}


@override
void dispose() {
  _controller.removeListener(_onVideoPositionChanged);
  widget.playbackController?._detach(this);

  _playerSearchCtrl.dispose();
  _tabController.dispose();
  _debounceTimer?.cancel();
  _ttdUpdateNotifier.dispose();
  _editTtdNoteCtrl.dispose();
  _tapMarkerTimer?.cancel();
  _overlayAutoHideTimer?.cancel();

  if (!widget.embedded && widget.forceLandscape) {
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  _controller.dispose();
  _noteCtrl.dispose();
  _titleCtrl.dispose();

  _aiTracking.disposeController();
  _aiServerController.dispose();

  _videoTransformController.dispose();
  _lightReloadTimer?.cancel();

  super.dispose();
}

void _initializeServices() {
  _pythonTrackingService =
      PythonTrackingService(baseUrl: ApiConstants.aiBaseUrl);
}
void _setupControllers() {
  _tabController = TabController(length: 2, vsync: this)
    ..addListener(() {
      _notifyPlaybackBridge();
      if (mounted) setState(() {});
    });

  if (!widget.embedded && widget.forceLandscape) {
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
    ..initialize().then((_) {
      if (!mounted) return;
      setState(() => _videoReady = true);
      _notifyPlaybackBridge();
    });

  _controller.addListener(() {
    _notifyPlaybackBridge();
    if (mounted) setState(() {});
  });

  _controller.addListener(_onVideoPositionChanged);
  widget.playbackController?._attach(this);

  _playerSearchCtrl.addListener(_applyPlayerFilter);
}

void _notifyPlaybackBridge() {
  widget.playbackController?._syncFromState();
}


Future<void> _pickOwnPlayerForAi() async {
  final source = _matchPlayers.isNotEmpty ? _matchPlayers : _players;

  if (source.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Состав матча пока не загружен')),
    );
    return;
  }

  final picked = await showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      final players = List<Map<String, dynamic>>.from(source);

      return SafeArea(
        child: StatefulBuilder(
          builder: (context, setModalState) {
            final query = _playerSearchCtrl.text.trim().toLowerCase();

            final filtered = query.isEmpty
                ? players
                : players.where((p) {
                    final fullName = _playerFullName(p).toLowerCase();
                    final pos = _playerPosition(p).toLowerCase();
                    return fullName.contains(query) || pos.contains(query);
                  }).toList();

            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.72,
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Выбор игрока команды',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _playerSearchCtrl,
                      onChanged: (_) => setModalState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Поиск игрока',
                        prefixIcon: const Icon(Icons.search_rounded),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final p = filtered[index];
                        final isSelected = _selectedPlayer != null &&
                            _i(_selectedPlayer!['id']) == _i(p['id']);

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => Navigator.pop(context, p),
                            borderRadius: BorderRadius.circular(16),
                            child: Ink(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF1F7A4D).withOpacity(0.08)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF1F7A4D)
                                      : const Color(0xFFE2E8F0),
                                ),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundColor:
                                        const Color(0xFF1F7A4D).withOpacity(0.12),
                                    backgroundImage: _playerPhoto(p).isNotEmpty
                                        ? NetworkImage(_playerPhoto(p))
                                        : null,
                                    child: _playerPhoto(p).isEmpty
                                        ? Text(
                                            _playerFullName(p).isNotEmpty
                                                ? _playerFullName(p)[0].toUpperCase()
                                                : '?',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF1F7A4D),
                                            ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _playerFullName(p),
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _playerPosition(p).isEmpty
                                              ? 'Позиция не указана'
                                              : _playerPosition(p),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF64748B),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      color: Color(0xFF1F7A4D),
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
          },
        ),
      );
    },
  );

  if (picked != null && mounted) {
    setState(() {
      _selectedPlayer = picked;
    });

    if (_aiTracking.lockedTrack != null) {
      _aiTracking.bindSelectedTrackToPlayer(
        playerId: _i(picked['id']),
        playerName: _playerFullName(picked),
      );
    }
  }
}

Future<void> _bindAiTrackToSelectedPlayer() async {
  if (_aiTracking.lockedTrack == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Сначала захвати игрока на видео')),
    );
    return;
  }

  if (_selectedPlayer == null) {
    await _pickOwnPlayerForAi();
  }

  if (_selectedPlayer == null) return;

  _aiTracking.bindSelectedTrackToPlayer(
    playerId: _i(_selectedPlayer!['id']),
    playerName: _playerFullName(_selectedPlayer!),
  );

  if (mounted) {
    setState(() {});
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        'Трек привязан к игроку: ${_playerFullName(_selectedPlayer!)}',
      ),
    ),
  );
}


  Future<void> _loadInitialData() async {
  await Future.wait([
    _loadPlayers(),
    _loadMatchData(),
  ]);

  await _loadSavedMatchPlayers();

  if (mounted) setState(() => _loading = false);
}

  Map<String, dynamic> _decode(http.Response resp) {
    return Formatters.decodeResponse(resp);
  }

  String _s(dynamic v) => Formatters.safeString(v);
  int _i(dynamic v) => Formatters.safeInt(v);

  String _playerFirstName(Map<String, dynamic> p) => PlayerHelpers.firstName(p);
  String _playerLastName(Map<String, dynamic> p) => PlayerHelpers.lastName(p);
  String _playerFullName(Map<String, dynamic> p) => PlayerHelpers.fullName(p);
  String _playerPhoto(Map<String, dynamic> p) => PlayerHelpers.photo(p);
  String _playerPosition(Map<String, dynamic> p) => PlayerHelpers.position(p);

  int _currentVideoTimeMs() {
    if (!_videoReady) return 0;
    return _controller.value.position.inMilliseconds;
  }

  String _ttdStorageKey({
  Map<String, dynamic>? player,
  Map<String, dynamic>? episode,
}) {
  final playerId = player != null ? _i(player['id']).toString() : 'no_player';

  // Для обычного episode-mode оставляем эпизод
  if (episode != null) {
    final episodeId = _i(episode['id']).toString();
    return '${playerId}_episode_$episodeId';
  }

  // Для quick mode считаем весь текущий видео-поток игрока одним ключом
  return '${playerId}_video_${widget.videoId}';
}  
  int? _selectedPlayerId() {
    if (_selectedPlayer == null) return null;
    final id = _i(_selectedPlayer!['id']);
    return id > 0 ? id : null;
  }

  Map<String, int> _currentVideoSuccessCounters() {
    final playerId = _selectedPlayerId();
    if (playerId == null) return {};
    return Map<String, int>.from(
      _videoSuccessCountersCache[playerId] ?? const <String, int>{},
    );
  }

  Map<String, int> _currentVideoFailCounters() {
    final playerId = _selectedPlayerId();
    if (playerId == null) return {};
    return Map<String, int>.from(
      _videoFailCountersCache[playerId] ?? const <String, int>{},
    );
  }

  Map<String, int> _currentVideoSingleCounters() {
    final playerId = _selectedPlayerId();
    if (playerId == null) return {};
    return Map<String, int>.from(
      _videoSingleCountersCache[playerId] ?? const <String, int>{},
    );
  }

  int _currentVideoSuccessValue(String code) {
    return _currentVideoSuccessCounters()[code] ?? 0;
  }

  int _currentVideoFailValue(String code) {
    return _currentVideoFailCounters()[code] ?? 0;
  }

  int _currentVideoSingleValue(String code) {
    return _currentVideoSingleCounters()[code] ?? 0;
  }

  int _videoSuccessTotal() {
    return _currentVideoSuccessCounters()
        .values
        .fold<int>(0, (a, b) => a + b);
  }

  int _videoFailTotal() {
    return _currentVideoFailCounters()
        .values
        .fold<int>(0, (a, b) => a + b);
  }

  int _videoSingleTotal() {
    return _currentVideoSingleCounters()
        .values
        .fold<int>(0, (a, b) => a + b);
  }

  int _videoAllTotal() {
    return _videoSuccessTotal() + _videoFailTotal() + _videoSingleTotal();
  }

  // ==================== ОПТИМИЗАЦИЯ: Обновленные методы счетчиков ====================
  Map<String, int> _currentTtdSuccessCounters() {
    final key = _ttdStorageKey(
      player: _selectedPlayer,
      episode: _selectedEpisode,
     
    );
    
    if (_localSuccessCounters.isNotEmpty && _needsCacheUpdate) {
      return _localSuccessCounters;
    }
    
    return Map<String, int>.from(
      _ttdSuccessCountersCache[key] ?? <String, int>{},
    );
  }

  Map<String, int> _currentTtdFailCounters() {
    final key = _ttdStorageKey(
      player: _selectedPlayer,
      episode: _selectedEpisode,
     
    );
    
    if (_localFailCounters.isNotEmpty && _needsCacheUpdate) {
      return _localFailCounters;
    }
    
    return Map<String, int>.from(
      _ttdFailCountersCache[key] ?? <String, int>{},
    );
  }

  Map<String, int> _currentTtdSingleCounters() {
    final key = _ttdStorageKey(
      player: _selectedPlayer,
      episode: _selectedEpisode,
     
    );
    
    if (_localSingleCounters.isNotEmpty && _needsCacheUpdate) {
      return _localSingleCounters;
    }
    
    return Map<String, int>.from(
      _ttdSingleCountersCache[key] ?? <String, int>{},
    );
  }

  int _currentTtdSingleValue(String code) {
    return _currentTtdSingleCounters()[code] ?? 0;
  }

  int _currentTtdSuccessValue(String code) {
    return _currentTtdSuccessCounters()[code] ?? 0;
  }

  int _currentTtdFailValue(String code) {
    return _currentTtdFailCounters()[code] ?? 0;
  }

  void _updateCache() {
    _cachedQuickSuccessTotal = _currentTtdSuccessCounters()
        .values
        .fold<int>(0, (a, b) => a + b);
    _cachedQuickFailTotal = _currentTtdFailCounters()
        .values
        .fold<int>(0, (a, b) => a + b);
    _cachedQuickSingleTotal = _currentTtdSingleCounters()
        .values
        .fold<int>(0, (a, b) => a + b);
    _needsCacheUpdate = false;
  }

  int _quickSuccessTotal() {
    if (_needsCacheUpdate) _updateCache();
    return _cachedQuickSuccessTotal;
  }

  int _quickFailTotal() {
    if (_needsCacheUpdate) _updateCache();
    return _cachedQuickFailTotal;
  }

  int _quickSingleTotal() {
    if (_needsCacheUpdate) _updateCache();
    return _cachedQuickSingleTotal;
  }

  int _quickAllTotal() {
    return _quickSuccessTotal() + _quickFailTotal() + _quickSingleTotal();
  }

  String _quickSuccessPercent(int success, int fail) {
    final total = success + fail;
    if (total <= 0) return '0%';
    final percent = ((success / total) * 100).round();
    return '$percent%';
  }

  void _scheduleRebuild() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 50), () {
      if (mounted) {
        _ttdUpdateNotifier.value++;
        setState(() {});
      }
    });
  }

  void _updateTtdSingleCounter(String code, int delta) {
    final key = _ttdStorageKey(
      player: _selectedPlayer,
      episode: _selectedEpisode,
     
    );

    final playerId = _selectedPlayerId();

    final current = _localSingleCounters[code] ?? 0;
    final next = math.max(0, current + delta);

    _localSingleCounters[code] = next;

    final map = Map<String, int>.from(_ttdSingleCountersCache[key] ?? {});
    map[code] = next;
    _ttdSingleCountersCache[key] = map;

    if (playerId != null) {
      final videoCurrent =
          (_videoSingleCountersCache[playerId] ?? const <String, int>{})[code] ?? 0;
      final videoNext = math.max(0, videoCurrent + delta);

      final videoMap = Map<String, int>.from(
        _videoSingleCountersCache[playerId] ?? {},
      );
      videoMap[code] = videoNext;
      _videoSingleCountersCache[playerId] = videoMap;
    }

    _needsCacheUpdate = true;
    _scheduleRebuild();
  }

  void _incrementTtdSuccess(String code) {
    final key = _ttdStorageKey(
      player: _selectedPlayer,
      episode: _selectedEpisode,
     
    );

    final playerId = _selectedPlayerId();

    _localSuccessCounters[code] = (_localSuccessCounters[code] ?? 0) + 1;

    final map = Map<String, int>.from(_ttdSuccessCountersCache[key] ?? {});
    map[code] = (map[code] ?? 0) + 1;
    _ttdSuccessCountersCache[key] = map;

    if (playerId != null) {
      final videoMap = Map<String, int>.from(
        _videoSuccessCountersCache[playerId] ?? {},
      );
      videoMap[code] = (videoMap[code] ?? 0) + 1;
      _videoSuccessCountersCache[playerId] = videoMap;
    }

    _needsCacheUpdate = true;
    _scheduleRebuild();
  }

  void _incrementTtdFail(String code) {
    final key = _ttdStorageKey(
      player: _selectedPlayer,
      episode: _selectedEpisode,
     
    );

    final playerId = _selectedPlayerId();

    _localFailCounters[code] = (_localFailCounters[code] ?? 0) + 1;

    final map = Map<String, int>.from(_ttdFailCountersCache[key] ?? {});
    map[code] = (map[code] ?? 0) + 1;
    _ttdFailCountersCache[key] = map;

    if (playerId != null) {
      final videoMap = Map<String, int>.from(
        _videoFailCountersCache[playerId] ?? {},
      );
      videoMap[code] = (videoMap[code] ?? 0) + 1;
      _videoFailCountersCache[playerId] = videoMap;
    }

    _needsCacheUpdate = true;
    _scheduleRebuild();
  }
  
  void _resetLocalCache() {
    final key = _ttdStorageKey(
      player: _selectedPlayer,
      episode: _selectedEpisode,
     
    );
    
    _localSuccessCounters = Map<String, int>.from(
      _ttdSuccessCountersCache[key] ?? {},
    );
    _localFailCounters = Map<String, int>.from(
      _ttdFailCountersCache[key] ?? {},
    );
    _localSingleCounters = Map<String, int>.from(
      _ttdSingleCountersCache[key] ?? {},
    );
    
    _needsCacheUpdate = true;
    _updateCache();
    if (mounted) setState(() {});
  }

  int _currentTtdRating() {
    final key = _ttdStorageKey(
      player: _selectedPlayer,
      episode: _selectedEpisode,
     
    );
    return _ttdRatingsCache[key] ?? 5;
  }

  void _setCurrentTtdRating(int rating) {
    final key = _ttdStorageKey(
      player: _selectedPlayer,
      episode: _selectedEpisode,
     
    );
    _ttdRatingsCache[key] = rating;
    if (mounted) setState(() {});
  }
  // ==================== КОНЕЦ ОПТИМИЗАЦИИ ====================

  // ==================== МЕТОДЫ ДЛЯ РЕДАКТИРОВАНИЯ ТТД ====================
  Future<void> _editTtdEvent(Map<String, dynamic> ttdEvent) async {
    final eventId = _i(ttdEvent['id']);
    final eventType = _s(ttdEvent['event_type']);
    final eventTitle = _s(ttdEvent['event_title']);
    final note = _s(ttdEvent['note']);
    final rating = _i(ttdEvent['rating']);
    final isPositive = _i(ttdEvent['is_positive']) == 1;
    final timeSeconds = _i(ttdEvent['timecode_seconds']);
    
    _editTtdNoteCtrl.text = note;
    _editingTtdMetricCode = eventType;
    _editingTtdMetricTitle = eventTitle;
    _editingTtdValue = rating;
    _editingTtdIsPositive = isPositive;
    _editingTtdRating = rating;
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isPositive ? Icons.check_circle : Icons.cancel,
              color: isPositive ? Colors.green : Colors.red,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                eventTitle,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Время события',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 16, color: const Color(0xFF1F7A4D)),
                        const SizedBox(width: 8),
                        Text(
                          Formatters.formatDuration(Duration(seconds: timeSeconds)),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(width: 16),
                        if (_selectedEpisode != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1F7A4D).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Эпизод #${_i(_selectedEpisode!['id'])}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1F7A4D),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              const Text(
                'Оценка действия',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildRatingButton(
                      value: 1,
                      label: 'Плохо',
                      color: Colors.red,
                      selected: _editingTtdRating == 1,
                      onTap: () => setState(() => _editingTtdRating = 1),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildRatingButton(
                      value: 3,
                      label: 'Средне',
                      color: Colors.orange,
                      selected: _editingTtdRating == 3,
                      onTap: () => setState(() => _editingTtdRating = 3),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildRatingButton(
                      value: 5,
                      label: 'Хорошо',
                      color: Colors.green,
                      selected: _editingTtdRating == 5,
                      onTap: () => setState(() => _editingTtdRating = 5),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildRatingButton(
                      value: 8,
                      label: 'Отлично',
                      color: Colors.teal,
                      selected: _editingTtdRating == 8,
                      onTap: () => setState(() => _editingTtdRating = 8),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildRatingButton(
                      value: 10,
                      label: 'Шедевр',
                      color: Colors.purple,
                      selected: _editingTtdRating == 10,
                      onTap: () => setState(() => _editingTtdRating = 10),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              TextField(
                controller: _editTtdNoteCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Заметка',
                  hintText: 'Добавьте комментарий к действию...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _updateTtdEvent(
                eventId: eventId,
                rating: _editingTtdRating,
                note: _editTtdNoteCtrl.text.trim(),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1F7A4D),
              foregroundColor: Colors.white,
            ),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingButton({
    required int value,
    required String label,
    required Color color,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? color : const Color(0xFFE2E8F0),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              value.toString(),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: selected ? color : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: selected ? color : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateTtdEvent({
    required int eventId,
    required int rating,
    required String note,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConstants.updateEventUrl),
        body: {
          "event_id": eventId.toString(),
          "rating": rating.toString(),
          "note": note,
        },
      ).timeout(const Duration(seconds: 15));
      
      final data = _decode(response);
      
      if (data["success"] == true) {
        await _loadMatchDataLight();
        _needsCacheUpdate = true;
        _scheduleRebuild();
        SnackbarHelper.showSuccess("Действие обновлено");
      } else {
        SnackbarHelper.showError("Не удалось обновить: ${data["message"]}");
      }
    } catch (e) {
      SnackbarHelper.showError("Ошибка при обновлении");
    }
  }

  Future<void> _deleteTtdEvent(int eventId, String metricCode) async {
  final normalizedMetricCode = _normalizeMetricCode(metricCode);

  final confirm = await Get.dialog<bool>(
    AlertDialog(
      title: const Text("Удалить действие?"),
      content: const Text(
        "Действие будет удалено из статистики. Это действие нельзя отменить.",
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back(result: false),
          child: const Text("Отмена"),
        ),
        ElevatedButton(
          onPressed: () => Get.back(result: true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
          ),
          child: const Text("Удалить"),
        ),
      ],
    ),
  );

  if (confirm != true) return;

  try {
    debugPrint(
      'DELETE TTD: eventId=$eventId metricCode=$metricCode normalized=$normalizedMetricCode',
    );

    final resp = await http.post(
      Uri.parse(ApiConstants.deleteEventUrl),
      body: {"event_id": eventId.toString()},
    ).timeout(const Duration(seconds: 15));

    debugPrint('DELETE TTD RESPONSE: ${resp.body}');

    final data = _decode(resp);

    if (data["success"] == true) {
      final playerId = _selectedPlayerId();
      if (playerId != null) {
        final successValue =
            _videoSuccessCountersCache[playerId]?[normalizedMetricCode] ?? 0;
        final failValue =
            _videoFailCountersCache[playerId]?[normalizedMetricCode] ?? 0;
        final singleValue =
            _videoSingleCountersCache[playerId]?[normalizedMetricCode] ?? 0;

        if (successValue > 0) {
          final map = Map<String, int>.from(
            _videoSuccessCountersCache[playerId] ?? {},
          );
          final next = successValue - 1;
          if (next <= 0) {
            map.remove(normalizedMetricCode);
          } else {
            map[normalizedMetricCode] = next;
          }
          _videoSuccessCountersCache[playerId] = map;
        } else if (failValue > 0) {
          final map = Map<String, int>.from(
            _videoFailCountersCache[playerId] ?? {},
          );
          final next = failValue - 1;
          if (next <= 0) {
            map.remove(normalizedMetricCode);
          } else {
            map[normalizedMetricCode] = next;
          }
          _videoFailCountersCache[playerId] = map;
        } else if (singleValue > 0) {
          final map = Map<String, int>.from(
            _videoSingleCountersCache[playerId] ?? {},
          );
          final next = singleValue - 1;
          if (next <= 0) {
            map.remove(normalizedMetricCode);
          } else {
            map[normalizedMetricCode] = next;
          }
          _videoSingleCountersCache[playerId] = map;
        }
      }

      await _loadMatchDataLight();
      _needsCacheUpdate = true;
      _scheduleRebuild();

      SnackbarHelper.showSuccess("Действие удалено");
    } else {
      SnackbarHelper.showError(
        _s(data["message"]).isNotEmpty
            ? _s(data["message"])
            : "Не удалось удалить",
      );
    }
  } catch (e) {
    debugPrint('DELETE TTD ERROR: $e');
    SnackbarHelper.showError("Сетевая ошибка");
  }
}


Future<void> _showTtdEventsList(String metricCode, String metricTitle) async {
  if (_selectedPlayer == null) {
    SnackbarHelper.showError("Сначала выберите игрока");
    return;
  }

  final normalizedMetricCode = _normalizeMetricCode(metricCode);

  setState(() => _reportLoading = true);

  try {
    debugPrint(
      'TTD EVENTS: metricCode=$metricCode normalized=$normalizedMetricCode',
    );

    final response = await http.post(
      Uri.parse(ApiConstants.getPlayerTtdEventsUrl),
      body: {
        "match_id": widget.matchId.toString(),
        "player_id": _i(_selectedPlayer!["id"]).toString(),
        "event_type": normalizedMetricCode,
        "get_detailed_events": "1",
      },
    ).timeout(const Duration(seconds: 15));

    debugPrint('TTD EVENTS RESPONSE: ${response.body}');

    final data = _decode(response);

    if (data["success"] == true && data["events"] is List) {
      final events = List<Map<String, dynamic>>.from(data["events"]);

      if (events.isEmpty) {
        SnackbarHelper.showInfo("Нет записей для $metricTitle");
        return;
      }

      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(20)),
                    border: const Border(
                      bottom: BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        metricTitle,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        _playerFullName(_selectedPlayer!),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: events.length,
                    itemBuilder: (context, index) {
                      final event = events[index];
                      final timeSec = _i(event['timecode_seconds']);
                      final rating = _i(event['rating']);
                      final isPositive = _i(event['is_positive']) == 1;
                      final note = _s(event['note']);
                      final episodeId = _i(event['parent_event_id']);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border:
                              Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
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
                                    color: isPositive
                                        ? Colors.green.withOpacity(0.1)
                                        : Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    isPositive ? Icons.check : Icons.close,
                                    color: isPositive ? Colors.green : Colors.red,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        Formatters.formatDuration(
                                          Duration(seconds: timeSec),
                                        ),
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      if (episodeId > 0)
                                        Text(
                                          'Эпизод #$episodeId',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF1F7A4D),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _getRatingColor(rating)
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    rating.toString(),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: _getRatingColor(rating),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (note.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  note,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    _editTtdEvent(event);
                                  },
                                  icon: const Icon(Icons.edit, size: 16),
                                  label: const Text('Редактировать'),
                                  style: TextButton.styleFrom(
                                    foregroundColor:
                                        const Color(0xFF1F7A4D),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                TextButton.icon(
                                  onPressed: () async {
                                    Navigator.pop(context);
                                    await _deleteTtdEvent(
                                      _i(event['id']),
                                      normalizedMetricCode,
                                    );
                                  },
                                  icon: const Icon(Icons.delete, size: 16),
                                  label: const Text('Удалить'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.red,
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
              ],
            );
          },
        ),
      );
    } else {
      SnackbarHelper.showError(
        _s(data["message"]).isNotEmpty
            ? _s(data["message"])
            : "Не удалось загрузить список событий",
      );
    }
  } catch (e) {
    debugPrint('TTD EVENTS ERROR: $e');
    SnackbarHelper.showError("Ошибка загрузки");
  } finally {
    if (mounted) setState(() => _reportLoading = false);
  }
}


  Color _getRatingColor(int rating) {
    if (rating <= 3) return Colors.red;
    if (rating <= 5) return Colors.orange;
    if (rating <= 8) return Colors.teal;
    return Colors.purple;
  }
  // ==================== КОНЕЦ МЕТОДОВ ДЛЯ РЕДАКТИРОВАНИЯ ТТД ====================


 
  void _scheduleLightReload() {
    _lightReloadTimer?.cancel();
    _lightReloadTimer = Timer(const Duration(milliseconds: 700), () async {
      if (!mounted) return;
      await _loadMatchDataLight();
    });
  }


  Future<void> _confirmCloseReview() async {
    final shouldClose = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('Закрыть разбор видео?'),
        content: const Text(
          'Вы выйдете из текущего экрана видеоанализа и вернётесь к выбору видео.',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Остаться'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1F7A4D),
              foregroundColor: Colors.white,
            ),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );

    if (shouldClose == true) {
      Get.back();
    }
  }

Future<void> _warmupDetections() async {
  List<DetectedPlayerBox> detections = const [];
  int usedTimeMs = _currentVideoTimeMs();

  for (int i = 0; i < 3; i++) {
    final timeMs = _currentVideoTimeMs();
    usedTimeMs = timeMs;

    debugPrint('🔥 Warmup attempt ${i + 1}, timeMs=$timeMs');

    detections = await _detectPlayersForFrame(timeMs);

    debugPrint('🔥 Warmup detections: ${detections.length}');

    if (detections.isNotEmpty) break;

    await Future.delayed(const Duration(milliseconds: 120));
  }

  _aiTracking.setDetectionsForSelection(detections, usedTimeMs);
}

  
    void _applyPlayerFilter() {
  final source = _matchPlayers.isNotEmpty ? _matchPlayers : _players;

  setState(() {
    _filteredPlayers =
        PlayerHelpers.filterPlayers(source, _playerSearchCtrl.text);
  });
}

  Size _analysisFrameSize() {
    if (!_videoReady || _controller.value.aspectRatio == 0) {
      return const Size(640, 360);
    }
    final aspect = _controller.value.aspectRatio;
    const width = 640.0;
    final height = width / aspect;
    return Size(width, height);
  }

  Rect _getFittedVideoRect({
    required Size sourceSize,
    required Size targetSize,
    required BoxFit fit,
  }) {
    final sourceAspect = sourceSize.width / sourceSize.height;
    final targetAspect = targetSize.width / targetSize.height;

    double drawWidth;
    double drawHeight;

    if (fit == BoxFit.cover) {
      if (sourceAspect > targetAspect) {
        drawHeight = targetSize.height;
        drawWidth = drawHeight * sourceAspect;
      } else {
        drawWidth = targetSize.width;
        drawHeight = drawWidth / sourceAspect;
      }
    } else {
      if (sourceAspect > targetAspect) {
        drawWidth = targetSize.width;
        drawHeight = drawWidth / sourceAspect;
      } else {
        drawHeight = targetSize.height;
        drawWidth = drawHeight * sourceAspect;
      }
    }

    final dx = (targetSize.width - drawWidth) / 2;
    final dy = (targetSize.height - drawHeight) / 2;

    return Rect.fromLTWH(dx, dy, drawWidth, drawHeight);
  }

  Offset _mapPointToOverlay({
    required Offset point,
    required Size sourceSize,
    required Size overlaySize,
    required BoxFit fit,
  }) {
    final fittedRect = _getFittedVideoRect(
      sourceSize: sourceSize,
      targetSize: overlaySize,
      fit: fit,
    );

    final scaleX = fittedRect.width / sourceSize.width;
    final scaleY = fittedRect.height / sourceSize.height;

    return Offset(
      fittedRect.left + point.dx * scaleX,
      fittedRect.top + point.dy * scaleY,
    );
  }

  Rect? _mapRectToOverlay({
    required Rect? rect,
    required Size sourceSize,
    required Size overlaySize,
    required BoxFit fit,
  }) {
    if (rect == null) return null;

    final fittedRect = _getFittedVideoRect(
      sourceSize: sourceSize,
      targetSize: overlaySize,
      fit: fit,
    );

    final scaleX = fittedRect.width / sourceSize.width;
    final scaleY = fittedRect.height / sourceSize.height;

    return Rect.fromLTWH(
      fittedRect.left + rect.left * scaleX,
      fittedRect.top + rect.top * scaleY,
      rect.width * scaleX,
      rect.height * scaleY,
    );
  }
  
  List<DetectedPlayerBox> _mapDetectionsToOverlay({
  required List<DetectedPlayerBox> detections,
  required Size overlaySize,
  required BoxFit fit,
}) {
  final sourceSize = _analysisFrameSize();

  return detections.map((d) {
    final mappedRect = _mapRectToOverlay(
      rect: d.rect,
      sourceSize: sourceSize,
      overlaySize: overlaySize,
      fit: fit,
    );

    return DetectedPlayerBox(
      id: d.id,
      rect: mappedRect ?? d.rect,
      confidence: d.confidence,
      classId: d.classId,
      label: d.label,
    );
  }).toList();
}
  

  Offset _mapTapToAnalysisSpace({
    required Offset localPosition,
    required Size sourceSize,
    required Size overlaySize,
    required BoxFit fit,
  }) {
    final fittedRect = _getFittedVideoRect(
      sourceSize: sourceSize,
      targetSize: overlaySize,
      fit: fit,
    );

    final localX =
        (localPosition.dx - fittedRect.left).clamp(0.0, fittedRect.width);
    final localY =
        (localPosition.dy - fittedRect.top).clamp(0.0, fittedRect.height);

    final scaleX = sourceSize.width / fittedRect.width;
    final scaleY = sourceSize.height / fittedRect.height;

    return Offset(localX * scaleX, localY * scaleY);
  }

  List<TrackedPlayer> _buildTrackedPlayersForOverlay({
    required Size overlaySize,
    required BoxFit fit,
  }) {
    if (!_videoReady) return [];

    final currentMs = _controller.value.position.inMilliseconds;
    final sourceSize = _analysisFrameSize();

    return _aiTracking.tracks.map<TrackedPlayer>((track) {
      final predictedPos =
          _aiTracking.getPredictedPositionForTrack(track, currentMs);
      final predictedRect =
          _aiTracking.getPredictedRectForTrack(track, currentMs);

      final recentPoints = track.points.length > 12
          ? track.points.sublist(track.points.length - 12)
          : track.points;

      final avgSpeed = recentPoints.isEmpty
          ? 0.0
          : recentPoints.fold<double>(0.0, (sum, p) => sum + p.speed) /
              recentPoints.length;

      final mappedRect = _mapRectToOverlay(
        rect: predictedRect,
        sourceSize: sourceSize,
        overlaySize: overlaySize,
        fit: fit,
      );

      final mappedPosition = _mapPointToOverlay(
        point: predictedPos,
        sourceSize: sourceSize,
        overlaySize: overlaySize,
        fit: fit,
      );

      return TrackedPlayer(
        id: track.id,
        name: track.boundPlayerName,
        color: track.color,
        position: mappedPosition,
        boundingBox: mappedRect ??
            Rect.fromCenter(center: mappedPosition, width: 36, height: 56),
        speed: (track.speed ?? 0).toDouble(),
        averageSpeed: avgSpeed,
        totalDistance: 0,
        trail: recentPoints
            .map(
              (p) => _mapPointToOverlay(
                point: p.position,
                sourceSize: sourceSize,
                overlaySize: overlaySize,
                fit: fit,
              ),
            )
            .toList(),
        isSelected: _aiTracking.selectedTrackId == track.id,
        trackPoints: recentPoints,
      );
    }).toList();
  }

  List<TrackedPlayer> _buildTrackedPlayers() {
    if (!_videoReady) return [];

    final currentMs = _controller.value.position.inMilliseconds;

    return _aiTracking.tracks.map<TrackedPlayer>((track) {
      final predictedPos =
          _aiTracking.getPredictedPositionForTrack(track, currentMs);
      final predictedRect =
          _aiTracking.getPredictedRectForTrack(track, currentMs);

      final avgSpeed = track.points.isEmpty
          ? 0.0
          : track.points.fold<double>(0.0, (sum, p) => sum + p.speed) /
              track.points.length;

      return TrackedPlayer(
        id: track.id,
        name: track.boundPlayerName,
        color: track.color,
        position: predictedPos,
        boundingBox: predictedRect ??
            Rect.fromCenter(center: predictedPos, width: 36, height: 56),
        speed: (track.speed ?? 0).toDouble(),
        averageSpeed: avgSpeed,
        totalDistance: 0,
        trail: track.points.map((p) => p.position).toList(),
        isSelected: _aiTracking.selectedTrackId == track.id,
        trackPoints: track.points,
      );
    }).toList();
  }

 Future<void> _loadPlayers() async {
  try {
    debugPrint(
      'Loading players from: ${ApiConstants.getPlayersUrl}?team_id=${widget.teamId}',
    );

    final response = await http
        .get(Uri.parse('${ApiConstants.getPlayersUrl}?team_id=${widget.teamId}'))
        .timeout(const Duration(seconds: 15));

    final body = utf8.decode(response.bodyBytes, allowMalformed: true).trim();
    final decoded = jsonDecode(body);

    if (decoded is List) {
      _players = List<Map<String, dynamic>>.from(decoded);
    } else if (decoded is Map<String, dynamic>) {
      if (decoded["players"] is List) {
        _players = List<Map<String, dynamic>>.from(decoded["players"]);
      } else if (decoded["data"] is List) {
        _players = List<Map<String, dynamic>>.from(decoded["data"]);
      } else {
        _players = [];
      }
    } else {
      _players = [];
    }

    _allTeamPlayers = List<Map<String, dynamic>>.from(_players);

    _filteredPlayers = _matchPlayers.isNotEmpty
        ? PlayerHelpers.filterPlayers(_matchPlayers, _playerSearchCtrl.text)
        : List<Map<String, dynamic>>.from(_players);

    if (mounted) setState(() {});
  } catch (e) {
    debugPrint('Error loading players: $e');
    _players = [];
    _allTeamPlayers = [];
    _filteredPlayers = [];
    if (mounted) setState(() {});
  }
}

  Future<void> _loadMatchData() async {
    try {
      if (mounted) setState(() => _reportLoading = true);

      final response = await http.post(
        Uri.parse(ApiConstants.getMatchTtdReportUrl),
        body: {"match_id": widget.matchId.toString()},
      ).timeout(const Duration(seconds: 20));

      final data = _decode(response);

      if (data["success"] == true) {
        setState(() {
          _episodes = (data["episodes"] is List)
              ? List<Map<String, dynamic>>.from(data["episodes"])
              : [];
          _mainReportRows = (data["main_report"] is List)
              ? List<Map<String, dynamic>>.from(data["main_report"])
              : [];
          _passReportRows = (data["pass_report"] is List)
              ? List<Map<String, dynamic>>.from(data["pass_report"])
              : [];
          _goalkeeperReportRows = (data["goalkeeper_report"] is List)
              ? List<Map<String, dynamic>>.from(data["goalkeeper_report"])
              : [];
        });

        if (data["player_video_totals"] is List) {
          _rebuildVideoCountersFromTotals(
            List<Map<String, dynamic>>.from(data["player_video_totals"]),
          );
        }

        _resetLocalCache();

        if (_episodes.isEmpty) {
          SnackbarHelper.showInfo("Эпизоды не найдены. Создайте новый эпизод.");
        }
      } else {
        SnackbarHelper.showError(
          "Не удалось загрузить данные: ${data["message"]}",
        );
      }
    } catch (e) {
      debugPrint('LOAD MATCH DATA ERROR: $e');
    } finally {
      if (mounted) setState(() => _reportLoading = false);
    }
  }

  Future<void> _loadMatchDataLight() async {
    try {
      final response = await http.post(
        Uri.parse(ApiConstants.getMatchTtdReportUrl),
        body: {"match_id": widget.matchId.toString()},
      ).timeout(const Duration(seconds: 10));

      final data = _decode(response);

      if (data["success"] == true && mounted) {
        setState(() {
          if (data["episodes"] is List) {
            _episodes = List<Map<String, dynamic>>.from(data["episodes"]);
          }
          if (data["main_report"] is List) {
            _mainReportRows = List<Map<String, dynamic>>.from(data["main_report"]);
          }
          if (data["pass_report"] is List) {
            _passReportRows = List<Map<String, dynamic>>.from(data["pass_report"]);
          }
          if (data["goalkeeper_report"] is List) {
            _goalkeeperReportRows =
                List<Map<String, dynamic>>.from(data["goalkeeper_report"]);
          }
        });

        if (data["player_video_totals"] is List) {
          _rebuildVideoCountersFromTotals(
            List<Map<String, dynamic>>.from(data["player_video_totals"]),
          );
        }

        _resetLocalCache();
      }
    } catch (e) {
      debugPrint('Light load error: $e');
    }
  }

  Future<void> _togglePlayPause() async {
    if (!_videoReady) return;
    if (_controller.value.isPlaying) {
      await _controller.pause();
    } else {
      await _controller.play();
    }
    if (mounted) setState(() {});
  }

  Future<void> _seekRelative(int seconds) async {
    if (!_videoReady) return;
    final current = _controller.value.position;
    final duration = _controller.value.duration;
    Duration target = current + Duration(seconds: seconds);

    if (target < Duration.zero) target = Duration.zero;
    if (target > duration) target = duration;

    await _controller.seekTo(target);
    if (mounted) setState(() {});
  }

  Future<void> _openFullscreenRoute() async {
    if (!mounted || _fullscreenRouteOpen) return;

    _fullscreenRouteOpen = true;
    setState(() => _isVideoFullscreen = true);

    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    try {
      await Navigator.of(context, rootNavigator: true).push<void>(
        PageRouteBuilder<void>(
          opaque: true,
          fullscreenDialog: true,
          barrierColor: Colors.black,
          transitionDuration: const Duration(milliseconds: 180),
          reverseTransitionDuration: const Duration(milliseconds: 140),
          pageBuilder: (routeContext, animation, secondaryAnimation) {
            return Material(
              color: Colors.black,
              child: WillPopScope(
                onWillPop: () async => true,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (_, __) => _buildFullscreenVideoOverlay(),
                ),
              ),
            );
          },
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    } finally {
      await SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      );

      _fullscreenRouteOpen = false;
      if (mounted) {
        setState(() => _isVideoFullscreen = false);
      }
    }
  }

  void _enterFullscreen() {
    _openFullscreenRoute();
  }

  void _exitFullscreen() {
    if (!mounted) return;

    if (_fullscreenRouteOpen) {
      Navigator.of(context, rootNavigator: true).maybePop();
      return;
    }

    setState(() => _isVideoFullscreen = false);
  }

  void _toggleFullscreen() {
    if (!mounted) return;

    if (_fullscreenRouteOpen || _isVideoFullscreen) {
      _exitFullscreen();
    } else {
      _openFullscreenRoute();
    }
    _notifyPlaybackBridge();
  }

  void _toggleEpisodesPanel() {
    setState(() => _episodesCollapsed = !_episodesCollapsed);
  }

Future<List<DetectedPlayerBox>> _detectPlayersForFrame(
  int timeMs, {
  Size? overlaySize,
  BoxFit? fit,
}) async {
  if (!_videoReady) return const [];
  if (_aiFrameProcessing) return const [];

  _aiFrameProcessing = true;

  try {
    debugPrint('🎬 detectFrame start: timeMs=$timeMs');

    if (mounted) {
      setState(() => _aiStatusText = 'AI: анализ кадра...');
    }

    final result = await _pythonTrackingService.detectFrameFromUrl(
      videoUrl: widget.videoUrl,
      timeMs: timeMs,
    );

    debugPrint('✅ detectFrameFromUrl result: ${result.detections.length} detections');

    if (result.ballRect != null) {
      _aiTracking.updateBall(
        rect: result.ballRect!,
        timeMs: timeMs,
        confidence: result.ballConfidence ?? 1.0,
      );
    }

    // Store the overlay size for later use if needed
    if (overlaySize != null) {
      _lastAiOverlaySize = overlaySize;
    }
    if (fit != null) {
      _lastAiOverlayFit = fit;
    }

    if (mounted) {
      setState(() {
        _aiStatusText = result.ballRect != null
            ? 'AI: ${result.detections.length} players + ball'
            : 'AI: ${result.detections.length} players';
      });
    }

    return result.detections;
  } catch (e, st) {
    debugPrint('❌ _detectPlayersForFrame error: $e');
    debugPrint('$st');

    if (mounted) {
      setState(() => _aiStatusText = 'AI error');
    }

    return const [];
  } finally {
    _aiFrameProcessing = false;
  }
}

void _toggleAiTracking() {
  if (_useServerAi) {
    _startServerAiAnalysis();
    debugPrint('AFTER APPLY aiSummary = ${_aiTracking.aiSummary}');
debugPrint('AFTER APPLY aiMatchStats = ${_aiTracking.aiMatchStats}');
debugPrint('AFTER APPLY exportJson = ${jsonEncode(_aiTracking.exportJson())}');
debugPrint('TRACKING HASH = ${identityHashCode(_aiTracking)}');
    return;
  }

  final overlaySize = _lastAiOverlaySize;
  final fit = _lastAiOverlayFit;

  if (overlaySize == null) {
    if (mounted) {
      setState(() => _aiStatusText = 'AI: видео ещё не готово');
    }
    return;
  }

  if (_aiTracking.isRunning) {
    _aiTracking.stopLoop();
    if (mounted) {
      setState(() => _aiStatusText = 'AI stopped');
    }
    return;
  }

  if (!_aiTracking.isLocked) {
    if (mounted) {
      setState(() => _aiStatusText = 'Tap a player first');
    }
    return;
  }

  _aiTracking.sampleMs = 700;
  _aiTracking.startLoop(
    frameDetector: (timeMs) {
      return _detectPlayersForFrame(
        timeMs,
        overlaySize: overlaySize,
        fit: fit,
      );
    },
    currentTimeMs: _currentVideoTimeMs,
  );

  if (mounted) {
    setState(() => _aiStatusText = 'AI started');
  }
}

void _startAiLoopDirectly({
  required Size overlaySize,
  required BoxFit fit,
}) {
  if (_aiTracking.isRunning) return;

  _aiTracking.sampleMs = 600;
  _aiTracking.startLoop(
    frameDetector: (timeMs) {
      return _detectPlayersForFrame(
        timeMs,
        overlaySize: overlaySize,
        fit: fit,
      );
    },
    currentTimeMs: _currentVideoTimeMs,
  );

  debugPrint('🚀 DIRECT AI LOOP STARTED');
  if (mounted) setState(() => _aiStatusText = 'AI started');
}

  void _bindSelectedTrackToCurrentPlayer() {
    final selectedTrack = _aiTracking.selectedTrack;
    if (selectedTrack == null) {
      SnackbarHelper.showError("Сначала выбери трек на видео");
      return;
    }
    if (_selectedPlayer == null) {
      SnackbarHelper.showError("Сначала выбери игрока из списка");
      return;
    }

    _aiTracking.bindSelectedTrackToPlayer(
      playerId: _i(_selectedPlayer!["id"]),
      playerName: _playerFullName(_selectedPlayer!),
    );

    SnackbarHelper.showSuccess("Трек привязан к игроку");
  }
  
  Future<void> _jumpToTrackingTime(int timeMs) async {
    if (!_videoReady) return;
    await _controller.pause();
    await _controller.seekTo(Duration(milliseconds: timeMs));
    if (mounted) setState(() {});
  }

  void _exportAiData() {
    final data = _aiTracking.exportJson();
    debugPrint(jsonEncode(data));
    SnackbarHelper.showSuccess('JSON аналитики выведен в debug console');
  }

 
  Future<void> _createEpisodeFromCurrentFrame() async {
    if (_creatingEpisode) return;
    if (!_videoReady) return;

    setState(() => _creatingEpisode = true);

    try {
      

      final pos = _controller.value.position;
      final totalSeconds = pos.inSeconds;
      final minute = pos.inMinutes;
      final second = pos.inSeconds.remainder(60);

      final playerId = _selectedPlayer != null ? _i(_selectedPlayer!["id"]) : 0;

      final req = http.MultipartRequest(
        "POST",
        Uri.parse(ApiConstants.addEventUrl),
      );
      req.fields["match_id"] = widget.matchId.toString();
      req.fields["team_id"] = widget.teamId.toString();
      req.fields["player_id"] = playerId.toString();
      req.fields["coach_id"] = widget.coachId.toString();
      req.fields["event_type"] = "episode";
      req.fields["event_title"] = _titleCtrl.text.trim().isNotEmpty
          ? _titleCtrl.text.trim()
          : "Эпизод ${Formatters.formatDuration(Duration(seconds: totalSeconds))}";
      req.fields["note"] = _noteCtrl.text.trim();
      req.fields["minute"] = minute.toString();
      req.fields["second"] = second.toString();
      req.fields["timecode_seconds"] = totalSeconds.toString();
      req.fields["rating"] = _rating.toString();
      req.fields["is_positive"] = "1";

     
      final streamed = await req.send().timeout(const Duration(seconds: 60));
      final resp = await http.Response.fromStream(streamed);
      final data = _decode(resp);

      if (data["success"] == true) {
        await Future.delayed(const Duration(milliseconds: 500));
        await _loadMatchData();

        _titleCtrl.clear();
        _noteCtrl.clear();

        if (_episodes.isNotEmpty) {
  setState(() {
    _selectedEpisode = _episodes.first;
  });
  _resetLocalCache();
}

        SnackbarHelper.showSuccess("Эпизод создан");
      } else {
        SnackbarHelper.showError(
          _s(data["message"]).isNotEmpty
              ? _s(data["message"])
              : "Не удалось создать эпизод",
        );
      }
    } catch (e) {
      SnackbarHelper.showError("Не удалось создать эпизод: $e");
    } finally {
      if (mounted) setState(() => _creatingEpisode = false);
    }
  }

  Future<void> _selectEpisode(Map<String, dynamic> episode) async {
   setState(() {
  _selectedEpisode = episode;
});
    _resetLocalCache();

    final timeSec = _i(episode["timecode_seconds"]);
    if (_videoReady && timeSec > 0) {
      await _controller.pause();
      await _controller.seekTo(Duration(seconds: timeSec));
    }

    _titleCtrl.text = _s(episode["event_title"]);
    _noteCtrl.text = _s(episode["note"]);

    final playerId = _i(episode["player_id"]);
    if (playerId > 0) {
      final source = _matchPlayers.isNotEmpty ? _matchPlayers : _players;
final foundPlayer =
    source.where((p) => _i(p["id"]) == playerId).toList();
      if (foundPlayer.isNotEmpty) {
        setState(() => _selectedPlayer = foundPlayer.first);
        _resetLocalCache();
      }
    }
  }

Future<void> _clearSelectedEpisode() async {
 setState(() {
  _selectedEpisode = null;
});
  _resetLocalCache();
}

  Future<void> _editEpisode(Map<String, dynamic> episode) async {
    _titleCtrl.text = _s(episode["event_title"]);
    _noteCtrl.text = _s(episode["note"]);

    Get.dialog(
      AlertDialog(
        title: const Text("Редактировать эпизод"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: "Название эпизода",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                labelText: "Заметка",
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text("Отмена"),
          ),
          ElevatedButton(
            onPressed: () async {
              Get.back();
              await _updateEpisode(episode['id']);
            },
            child: const Text("Сохранить"),
          ),
        ],
      ),
    );
  }

  Future<void> _updateEpisode(int episodeId) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConstants.updateEventUrl),
        body: {
          "event_id": episodeId.toString(),
          "event_title": _titleCtrl.text.trim(),
          "note": _noteCtrl.text.trim(),
        },
      );

      final data = _decode(response);

      if (data["success"] == true) {
        await _loadMatchData();
        SnackbarHelper.showSuccess("Эпизод обновлен");
      } else {
        SnackbarHelper.showError("Не удалось обновить эпизод");
      }
    } catch (e) {
      SnackbarHelper.showError("Сетевая ошибка");
    }
  }

  Future<void> _deleteEvent(int eventId) async {
    final confirm = await Get.dialog<bool>(
      AlertDialog(
        title: const Text("Удалить эпизод?"),
        content: const Text("Эпизод и его дочерние действия будут удалены."),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text("Отмена"),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            child: const Text("Удалить"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final resp = await http.post(
        Uri.parse(ApiConstants.deleteEventUrl),
        body: {"event_id": eventId.toString()},
      ).timeout(const Duration(seconds: 15));

      final data = _decode(resp);

      if (data["success"] == true) {
      if (_selectedEpisode != null &&
    _i(_selectedEpisode!["id"]) == eventId) {
  setState(() {
    _selectedEpisode = null;
  });
  _resetLocalCache();
}
        await _loadMatchData();
        SnackbarHelper.showSuccess("Эпизод удалён");
      } else {
        SnackbarHelper.showError(
          _s(data["message"]).isNotEmpty
              ? _s(data["message"])
              : "Не удалось удалить эпизод",
        );
      }
    } catch (_) {
      SnackbarHelper.showError("Сетевая ошибка");
    }
  }

  void _openEpisodeTtdDetail(Map<String, dynamic> episode) {
    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => episode_detail.EpisodeTtdDetailScreen(
          key: ValueKey(episode['id']),
          episode: episode,
          players: _matchPlayers.isNotEmpty ? _matchPlayers : _players,
          matchId: widget.matchId,
          teamId: widget.teamId,
          coachId: widget.coachId,
          onEpisodeUpdated: () async {
            await _loadMatchData();
            if (mounted) setState(() {});
            final updatedEpisode = _episodes.firstWhere(
              (e) => e['id'] == episode['id'],
              orElse: () => episode,
            );
            if (mounted) {
              updatedEpisode;
            }
          },
        ),
      ),
    ).then((updatedEpisode) {
      if (updatedEpisode != null && mounted) {
        setState(() {
          final index =
              _episodes.indexWhere((e) => e['id'] == updatedEpisode['id']);
          if (index != -1) _episodes[index] = updatedEpisode;
        });
      }
    });
  }

  void _showTtdPanelMessage(String text, {bool isError = false}) {
    if (!mounted) return;

    setState(() {
      _ttdPanelMessage = text;
      _ttdPanelMessageIsError = isError;
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      if (_ttdPanelMessage == text) {
        setState(() => _ttdPanelMessage = null);
      }
    });
  }

  Future<void> _saveEvent() async {
    if (_selectedPlayer == null) {
      SnackbarHelper.showError("Сначала выбери игрока");
      return;
    }

    if (!_isSimpleMode && _selectedEpisode == null) {
      _showTtdPanelMessage("Сначала выбери эпизод справа", isError: true);
      return;
    }
    if (!_isSimpleMode && _controller.value.isPlaying) {
      await _controller.pause();
    }

    setState(() => _saving = true);

    try {
      final totalSeconds = _isSimpleMode
          ? _controller.value.position.inSeconds
          : _i(_selectedEpisode!["timecode_seconds"]);

      final req = http.MultipartRequest(
        "POST",
        Uri.parse(ApiConstants.addEventUrl),
      );
      req.fields["match_id"] = widget.matchId.toString();
      req.fields["team_id"] = widget.teamId.toString();
      req.fields["player_id"] = _s(_selectedPlayer!["id"]);
      req.fields["coach_id"] = widget.coachId.toString();
      if (!_isSimpleMode && _selectedEpisode != null) {
        req.fields["parent_event_id"] = _i(_selectedEpisode!["id"]).toString();
      }
      req.fields["event_type"] = _eventType;
      req.fields["event_title"] = _titleCtrl.text.trim();
      req.fields["note"] = _noteCtrl.text.trim();
      req.fields["timecode_seconds"] = totalSeconds.toString();
      req.fields["rating"] = _rating.toString();
      req.fields["is_positive"] = _isPositive ? "1" : "0";

      final streamed = await req.send().timeout(const Duration(seconds: 60));
      final resp = await http.Response.fromStream(streamed);
      final data = _decode(resp);

      if (data["success"] == true) {
        _titleCtrl.clear();
        _noteCtrl.clear();
        await _loadMatchData();
        SnackbarHelper.showSuccess("Правка эпизода сохранена");
      } else {
        SnackbarHelper.showError(
          _s(data["message"]).isNotEmpty
              ? _s(data["message"])
              : "Не удалось сохранить",
        );
      }
    } catch (_) {
      SnackbarHelper.showError("Сбой при сохранении");
    } finally {
      setState(() => _saving = false);
    }
  }

Future<void> _saveQuickTtd(
  String metricCode,
  String metricTitle,
  bool isSuccess,
) async {
  if (_selectedPlayer == null) {
    _showTtdPanelMessage("Сначала выбери игрока", isError: true);
    return;
  }

  if (!_videoReady) {
    _showTtdPanelMessage("Видео ещё не готово", isError: true);
    return;
  }

  setState(() => _quickSaving = true);

  try {
    final pos = _controller.value.position;
    final totalSeconds = pos.inSeconds;
    final minute = pos.inMinutes;
    final second = pos.inSeconds.remainder(60);

    final req = http.MultipartRequest(
      "POST",
      Uri.parse(ApiConstants.addEventUrl),
    );

    req.fields["match_id"] = widget.matchId.toString();
    req.fields["team_id"] = widget.teamId.toString();
    req.fields["player_id"] = _s(_selectedPlayer!["id"]);
    req.fields["coach_id"] = widget.coachId.toString();
    req.fields["event_type"] = _normalizeMetricCode(metricCode);
    req.fields["event_title"] = metricTitle;
    req.fields["note"] = _noteCtrl.text.trim();
    req.fields["minute"] = minute.toString();
    req.fields["second"] = second.toString();
    req.fields["timecode_seconds"] = totalSeconds.toString();
    req.fields["rating"] = isSuccess ? "8" : "3";
    req.fields["is_positive"] = isSuccess ? "1" : "0";

    final streamed = await req.send().timeout(const Duration(seconds: 60));
    final resp = await http.Response.fromStream(streamed);
    final data = _decode(resp);

    if (data["success"] == true) {
      final eventId = _i(data["event_id"]);

      if (isSuccess) {
        _incrementTtdSuccess(_normalizeMetricCode(metricCode));
      } else {
        _incrementTtdFail(_normalizeMetricCode(metricCode));
      }

      _rememberLastTtdAction(
        eventId: eventId,
        metricCode: _normalizeMetricCode(metricCode),
        isPositive: isSuccess,
        isSingle: false,
        delta: 1,
        title: metricTitle,
      );

      await _loadMatchDataLight();
      _showTtdPanelMessage(
        "$metricTitle • ${Formatters.formatDuration(pos)}",
      );
      _showUndoSnackBar("$metricTitle добавлено");
    } else {
      _showTtdPanelMessage(
        _s(data["message"]).isNotEmpty
            ? _s(data["message"])
            : "Не удалось сохранить",
        isError: true,
      );
    }
  } catch (e) {
    _showTtdPanelMessage("Сбой при сохранении: $e", isError: true);
  } finally {
    if (mounted) setState(() => _quickSaving = false);
  }
}


  Future<void> _saveSingleTtd(
  String metricCode,
  String metricTitle,
  int value,
) async {
  if (_selectedPlayer == null) {
    _showTtdPanelMessage("Сначала выбери игрока", isError: true);
    return;
  }

  if (!_videoReady) {
    _showTtdPanelMessage("Видео ещё не готово", isError: true);
    return;
  }

  setState(() => _quickSaving = true);

  try {
    final pos = _controller.value.position;
    final totalSeconds = pos.inSeconds;
    final minute = pos.inMinutes;
    final second = pos.inSeconds.remainder(60);

    final req = http.MultipartRequest(
      "POST",
      Uri.parse(ApiConstants.addEventUrl),
    );

    req.fields["match_id"] = widget.matchId.toString();
    req.fields["team_id"] = widget.teamId.toString();
    req.fields["player_id"] = _s(_selectedPlayer!["id"]);
    req.fields["coach_id"] = widget.coachId.toString();
    req.fields["event_type"] = _normalizeMetricCode(metricCode);
    req.fields["event_title"] = metricTitle;
    req.fields["note"] = _noteCtrl.text.trim();
    req.fields["minute"] = minute.toString();
    req.fields["second"] = second.toString();
    req.fields["timecode_seconds"] = totalSeconds.toString();
    req.fields["rating"] = value.abs().toString();
    req.fields["is_positive"] = value >= 0 ? "1" : "0";

    final streamed = await req.send().timeout(const Duration(seconds: 60));
    final resp = await http.Response.fromStream(streamed);
    final data = _decode(resp);

    if (data["success"] == true) {
      final eventId = _i(data["event_id"]);

      _updateTtdSingleCounter(_normalizeMetricCode(metricCode), value.abs());

      _rememberLastTtdAction(
        eventId: eventId,
        metricCode: _normalizeMetricCode(metricCode),
        isPositive: value >= 0,
        isSingle: true,
        delta: value.abs(),
        title: metricTitle,
      );

      await _loadMatchDataLight();
      _showTtdPanelMessage(
        "$metricTitle • ${value >= 0 ? '+' : '-'}${value.abs()} • ${Formatters.formatDuration(pos)}",
      );
      _showUndoSnackBar("$metricTitle изменено");
    } else {
      _showTtdPanelMessage(
        _s(data["message"]).isNotEmpty
            ? _s(data["message"])
            : "Не удалось сохранить",
        isError: true,
      );
    }
  } catch (e) {
    _showTtdPanelMessage("Сбой при сохранении: $e", isError: true);
  } finally {
    if (mounted) setState(() => _quickSaving = false);
  }
}




  void _openTtdPanel() {
    _showSideAnalysisPanel(
      title: 'ТТД',
      subtitle: 'Технико-тактические действия по выбранному эпизоду',
      icon: Icons.table_chart_rounded,
      width: 540,
     child: TtdPanelWidget(
  selectedPlayer: _selectedPlayer,
  selectedEpisode: _selectedEpisode,
  quickSaving: _quickSaving,
  saving: _saving,
  noteCtrl: _noteCtrl,
  message: _ttdPanelMessage,
  isMessageError: _ttdPanelMessageIsError,
  ttdSection: _ttdSection,
  onSectionChanged: (section) => setState(() => _ttdSection = section),
  onSaveEvent: _saveEvent,
  onSaveQuickTtd: _saveQuickTtd,
  onSaveSingleTtd: _saveSingleTtd,
  successCounters: _currentTtdSuccessCounters(),
  failCounters: _currentTtdFailCounters(),
  singleCounters: _currentTtdSingleCounters(),
  currentRating: _currentTtdRating(),
),
    );
  }

  void _openAiPanel() {
    _showSideAnalysisPanel(
      title: 'AI-анализ',
      subtitle: 'Трекинг игроков, heatmap и аналитика по видео',
      icon: Icons.track_changes_rounded,
      width: 500,
     child: AiAnalyticsPanelWidget(
  aiTracking: _aiTracking,
  showHeatmap: _showHeatmap,
  statusText: _aiStatusText,
  myTeamName: _myTeamConfig.displayName,
  opponentTeamName: _opponentTeamConfig.displayName,
  myTeamTag: _sideTagToString(_myTeamConfig.sideTag),
  onToggleAi: () {
    _startServerAiAnalysis();
  },
  onToggleHeatmap: (value) {
    setState(() {
      _showHeatmap = value;
    });
  },
  onBindTrack: _bindAiTrackToPlayer,
  onJumpToTime: _jumpToTime,
  onExport: _exportAiAnalysis,
  onConfirmSuggestion: _confirmAiSuggestion,
  onConfirmTopAi: _confirmTopAiSuggestions,
  onOpenTeamSetup: _openTeamIdentitySheet,
),
      );
  }

  void _showSideAnalysisPanel({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
    double width = 540,
  }) {
    showGeneralDialog(
      context: context,
      barrierLabel: title,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.22),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        final media = MediaQuery.of(context);
        final panelWidth =
            width > media.size.width - 32 ? media.size.width - 32 : width;

        return SafeArea(
          child: Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(top: 12, right: 12, bottom: 12),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: panelWidth,
                  height: media.size.height - 24,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    color: Colors.white,
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.16),
                        blurRadius: 30,
                        offset: const Offset(-8, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildSidePanelHeader(
                        title: title,
                        subtitle: subtitle,
                        icon: icon,
                      ),
                      const Divider(height: 1),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(28),
                          ),
                          child: Container(
                            width: double.infinity,
                            color: const Color(0xFFF8FBFF),
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
                              child: child,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );

        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.12, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  
 
  Widget _buildSidePanelHeader({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 12, 14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF1F7A4D).withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: const Color(0xFF1F7A4D), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () => Get.back(),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 20,
                color: Color(0xFF334155),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFloatingAnalysisDialog({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
    double width = 720,
    double height = 520,
  }) {
    showGeneralDialog(
      context: context,
      barrierLabel: title,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.28),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) {
        final media = MediaQuery.of(context);
        final maxWidth = media.size.width - 48;
        final maxHeight = media.size.height - 48;

        final dialogWidth = width > maxWidth ? maxWidth : width;
        final dialogHeight = height > maxHeight ? maxHeight : height;

        return SafeArea(
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: dialogWidth,
                height: dialogHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFFFFFF), Color(0xFFF8FBFF)],
                  ),
                  border: Border.all(color: Colors.white70, width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.18),
                      blurRadius: 36,
                      offset: const Offset(0, 18),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildFloatingDialogHeader(
                      title: title,
                      subtitle: subtitle,
                      icon: icon,
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(30),
                        ),
                        child: Container(
                          width: double.infinity,
                          color: Colors.white.withOpacity(0.80),
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                          child: SizedBox.expand(child: child),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved =
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildFloatingDialogHeader({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 12, 14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF1F7A4D).withOpacity(0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: const Color(0xFF1F7A4D), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => Get.back(),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 20,
                color: Color(0xFF334155),
              ),
            ),
          ),
        ],
      ),
    );
  }

 Widget _buildCompactHeader() {
  final selectedEpisodeId =
      _selectedEpisode != null ? "EP-${_i(_selectedEpisode!["id"])}" : null;

  return SizedBox(
    height: 54,
    child: Row(
      children: [
        const SizedBox(width: 4),
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              widget.matchTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
                letterSpacing: -0.2,
              ),
            ),
          ),
        ),
        Container(
          height: 46,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.92),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: const Color(0xFFE2E8F0),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              _buildCompactTab(
                title: "Видео",
                icon: Icons.play_circle_rounded,
                index: 0,
              ),
              _buildHeaderPillButton(
                title: _episodesCollapsed ? "Эпизоды" : "Скрыть",
                icon: Icons.grid_view_rounded,
                onTap: _toggleEpisodesPanel,
              ),
              _buildCompactTab(
                title: "Отчёт",
                icon: Icons.analytics_outlined,
                index: 1,
                isLast: true,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _buildHeaderActionButton(
          icon: Icons.refresh_rounded,
          onTap: () async {
            await _loadPlayers();
            await _loadMatchData();
          },
          iconColor: AppColors.primaryGreen,
          accent: true,
        ),
        const SizedBox(width: 10),
        if (selectedEpisodeId != null) ...[
          const SizedBox(width: 10),
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF1F7A4D).withOpacity(0.10),
                  const Color(0xFF22C55E).withOpacity(0.06),
                ],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: const Color(0xFF1F7A4D).withOpacity(0.22),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F7A4D).withOpacity(0.14),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.bolt_rounded,
                      size: 12,
                      color: Color(0xFF1F7A4D),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  selectedEpisodeId,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1F7A4D),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: _clearSelectedEpisode,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1F7A4D).withOpacity(0.10),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: Color(0xFF1F7A4D),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(width: 10),
        _buildHeaderActionButton(
          icon: Icons.close_rounded,
          onTap: _confirmCloseReview,
          iconColor: const Color(0xFF475569),
        ),
      ],
    ),
  );
}

Future<void> _loadSavedMatchPlayers() async {
  try {
    final players = await MatchPlayersService.getMatchPlayers(
      matchId: widget.matchId,
    );

    if (!mounted) return;

    setState(() {
      _matchPlayers = List<Map<String, dynamic>>.from(players);
      _filteredPlayers =
          PlayerHelpers.filterPlayers(_matchPlayers, _playerSearchCtrl.text);

      if (_selectedPlayer != null) {
        final exists = _matchPlayers.any(
          (p) => Formatters.safeString(p['id']) ==
              Formatters.safeString(_selectedPlayer!['id']),
        );
        if (!exists) {
          _selectedPlayer = null;
        }
      }
    });
  } catch (e) {
    debugPrint('Ошибка загрузки состава матча: $e');
  }
}
  Widget _buildCompactTab({
    required String title,
    required IconData icon,
    required int index,
    bool isLast = false,
  }) {
    final bool isSelected = _tabController.index == index;

    return Padding(
      padding: EdgeInsets.only(right: isLast ? 0 : 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            if (_tabController.index != index) {
              _tabController.animateTo(index);
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? const LinearGradient(
                      colors: [Color(0xFF1F7A4D), Color(0xFF22C55E)],
                    )
                  : null,
              color: isSelected ? null : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFF1F7A4D).withOpacity(0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withOpacity(0.18)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: 14,
                    color:
                        isSelected ? Colors.white : const Color(0xFF475569),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color:
                        isSelected ? Colors.white : const Color(0xFF475569),
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderPillButton({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Container(
            height: 38,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: 14,
                    color: const Color(0xFF475569),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF475569),
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


Widget _buildVideoToolbar() {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: ReviewUiPalette.panel,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: ReviewUiPalette.line),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _toolbarButton(
          icon: Icons.auto_awesome_rounded,
          label: _aiLoading ? 'AI...' : 'AI анализ',
          onTap: _aiLoading ? null : _startServerAiAnalysis,
        ),
        _toolbarButton(
          icon: Icons.palette_outlined,
          label: 'Команды',
          onTap: _openTeamIdentitySheet,
        ),
        _toolbarButton(
          icon: _showHeatmap
              ? Icons.local_fire_department_rounded
              : Icons.heat_pump_outlined,
          label: _showHeatmap ? 'Карта ON' : 'Карта OFF',
          onTap: () {
            setState(() {
              _showHeatmap = !_showHeatmap;
            });
          },
        ),
      ],
    ),
  );
}


Widget _toolbarButton({
  required IconData icon,
  required String label,
  required VoidCallback? onTap,
}) {
  final disabled = onTap == null;

  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: disabled
              ? const Color(0xFFF1F5F9)
              : ReviewUiPalette.primary.withOpacity(0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: disabled
                ? ReviewUiPalette.line
                : ReviewUiPalette.primary.withOpacity(0.24),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: disabled
                  ? const Color(0xFF94A3B8)
                  : ReviewUiPalette.primary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: disabled
                    ? const Color(0xFF94A3B8)
                    : ReviewUiPalette.text,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}


Future<void> _openTeamIdentitySheet() async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => TeamIdentitySetupSheet(
      myTeamConfig: _myTeamConfig,
      opponentTeamConfig: _opponentTeamConfig,
      onApply: (myCfg, oppCfg) {
        setState(() {
          _myTeamConfig = myCfg;
          _opponentTeamConfig = oppCfg;
        });
      },
    ),
  );
}

Widget _buildVideoSection() {
  if (!_videoReady) {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  return Stack(
    fit: StackFit.expand,
    children: [
      FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: _controller.value.size.width,
          height: _controller.value.size.height,
          child: VideoPlayer(_controller),
        ),
      ),
      Positioned.fill(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final overlaySize = Size(
              constraints.maxWidth,
              constraints.maxHeight,
            );

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) async {
                _showOverlay();
                _showTapPointMarker(details.localPosition);

                final mappedTap = _mapTapToAnalysisSpace(
                  localPosition: details.localPosition,
                  sourceSize: _analysisFrameSize(),
                  overlaySize: overlaySize,
                  fit: BoxFit.contain,
                );

              
                if (_useServerAi) {
                  return;
                }

                await _warmupDetections();
                _aiTracking.selectTrackByTap(mappedTap);

                if (_aiTracking.isLocked && !_aiTracking.isRunning) {
                  _startAiLoopDirectly(
                    overlaySize: overlaySize,
                    fit: BoxFit.contain,
                  );
                }
              },
              child: CustomPaint(
                painter: PlayerTrackingPainter(
                  controller: _aiTracking,
                  currentTimeMs: _controller.value.position.inMilliseconds,
                  fieldSize: overlaySize,
                ),
              ),
            );
          },
        ),
      ),
      if (_showHeatmap && _aiTracking.selectedTrack != null)
        Positioned.fill(
          child: CustomPaint(
            painter: TrackingHeatmapPainter(
              points: _aiTracking.selectedTrack!.points,
              color: _aiTracking.selectedTrack!.color,
            ),
          ),
        ),
      _buildTapMarkerOverlay(),
      _buildPossessionBadge(),
      _buildPassNetworkBadge(),
    ],
  );
}


 
  Widget _buildMiniActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool filled = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color:
                filled ? const Color(0xFF1F7A4D) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color:
                  filled ? const Color(0xFF1F7A4D) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: filled ? Colors.white : const Color(0xFF1F7A4D),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: filled ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isPrimary
                ? const Color(0xFF1F7A4D)
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color:
                  isPrimary ? const Color(0xFF1F7A4D) : const Color(0xFFDCE3EC),
            ),
            boxShadow: [
              BoxShadow(
                color: isPrimary
                    ? const Color(0xFF1F7A4D).withOpacity(0.18)
                    : Colors.black.withOpacity(0.03),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: isPrimary
                      ? Colors.white.withOpacity(0.16)
                      : const Color(0xFF1F7A4D).withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: isPrimary ? Colors.white : const Color(0xFF1F7A4D),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: isPrimary
                          ? Colors.white
                          : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isPrimary
                          ? Colors.white.withOpacity(0.85)
                          : const Color(0xFF64748B),
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

  Widget _buildPlayersSidePanel() {
  return PlayersListWidget(
    players: _filteredPlayers,
    selectedPlayer: _selectedPlayer,
    searchController: _playerSearchCtrl,
    onPlayerSelected: (player) => setState(() {
      _selectedPlayer = player;
      _resetLocalCache();
    }),
    onSelectMatchPlayers: _openMatchPlayersSelection, // Добавьте эту строку
  );
}

Widget _buildPlayersPanelWithBottomSelection() {
  return Column(
    children: [
      Expanded(
        child: _buildPlayersSidePanel(),
      ),
      const SizedBox(height: 10),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _openMatchPlayersSelection,
          icon: const Icon(Icons.group_add_rounded),
          label: const Text('Выбрать игроков матча'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1F7A4D),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    ],
  );
}

  Widget _buildEpisodesPanelWrapper() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      width: _episodesCollapsed ? 44 : 360,
      child: _episodesCollapsed
          ? Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Center(
                child: IconButton(
                  onPressed: _toggleEpisodesPanel,
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
              ),
            )
          : EpisodesListWidget(
  episodes: _episodes,
  players: _matchPlayers.isNotEmpty ? _matchPlayers : _players,
  selectedEpisode: _selectedEpisode,
  creatingEpisode: _creatingEpisode,
  isVideoFullscreen: _isVideoFullscreen,
  onEpisodeSelected: _selectEpisode,
  onEpisodeDeleted: (id) => _deleteEvent(id),
  onEpisodeEdited: _editEpisode,
  onEpisodeDetail: _openEpisodeTtdDetail,
  onCreateEpisode: _createEpisodeFromCurrentFrame,
  onExitFullscreen: _exitFullscreen,
),
    );
  }

  Widget _quickTtdButton(
    String title,
    IconData icon,
    bool positive,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: _quickSaving ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: positive
              ? Colors.green.withOpacity(0.08)
              : Colors.red.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: positive
                ? Colors.green.withOpacity(0.22)
                : Colors.red.withOpacity(0.22),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: positive
                    ? Colors.green.withOpacity(0.14)
                    : Colors.red.withOpacity(0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 18,
                color: positive ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

   Widget _buildQuickSelectedInfoCard() {
    final currentPos = _videoReady ? _controller.value.position : Duration.zero;
    final photo = _selectedPlayer != null ? _playerPhoto(_selectedPlayer!) : '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1F7A4D).withOpacity(0.10),
            const Color(0xFF22C55E).withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFFEFF6FF),
            backgroundImage:
                photo.isNotEmpty ? NetworkImage(photo) as ImageProvider : null,
            child: photo.isEmpty
                ? const Icon(Icons.person, color: Color(0xFF1F7A4D))
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedPlayer != null
                      ? _playerFullName(_selectedPlayer!)
                      : 'Игрок не выбран',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _selectedPlayer != null
                      ? (_playerPosition(_selectedPlayer!).isEmpty
                          ? 'Позиция не указана'
                          : _playerPosition(_selectedPlayer!))
                      : 'Выбери игрока для быстрого TTD',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              Formatters.formatDuration(currentPos),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1F7A4D),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildQuickTtdDockCompact() {
  return RepaintBoundary(
    child: ValueListenableBuilder(
      valueListenable: _ttdUpdateNotifier,
      builder: (context, _, __) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          // ⭐ ВЕСЬ КОНТЕНТ ПРОКРУЧИВАЕТСЯ ⭐
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                  child: Row(
                    children: [
                      const Expanded(child: SizedBox()),
                      if (_quickSaving)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: _buildQuickSelectedInfoCard(),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: _buildMiniAnalyticsBoard(), // Этот метод не меняем
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: _buildQuickTtdSectionTabs(),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: TextField(
                    controller: _noteCtrl,
                    maxLines: 2,
                    minLines: 1,
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Комментарий к действию',
                      isDense: true,
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  child: _buildQuickTtdSectionBody(),
                ),
                if (_ttdPanelMessage != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _ttdPanelMessageIsError
                          ? Colors.red.withOpacity(0.08)
                          : Colors.green.withOpacity(0.08),
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(26),
                      ),
                    ),
                    child: Text(
                      _ttdPanelMessage!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _ttdPanelMessageIsError
                            ? Colors.red.shade700
                            : Colors.green.shade700,
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
  
  Widget _buildQuickTtdSectionTabs() {
   final sections = [
  {'id': 'main', 'label': 'Осн.'},
  {'id': 'pass', 'label': 'Пасы'},
  {'id': 'gk', 'label': 'Врат.'},
];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: sections.map((section) {
          final isSelected = _quickTtdSection == section['id'];

          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _quickTtdSection = section['id']! as String;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    section['label']! as String,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: isSelected
                          ? const Color(0xFF1F7A4D)
                          : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildQuickMainSection() {
  return Column(
    children: [
      _buildQuickTtdRow('Финт/дриблинг', 'feint_dribble'),
      const SizedBox(height: 8),
      _buildQuickTtdRow('Удар', 'shot_on_goal'),
      const SizedBox(height: 8),
      _buildQuickTtdRow('Отбор', 'tackle_duel'),
      const SizedBox(height: 8),
      _buildQuickTtdRow('Перехват', 'interception'),
      const SizedBox(height: 8),
      _buildQuickTtdRow('Подбор', 'recovery'),
      const SizedBox(height: 8),
      _buildQuickTtdRow('Игра головой', 'header_play'),
      const SizedBox(height: 8),
      _buildQuickTtdRow('Аут', 'throw_ins'),
      const SizedBox(height: 8),
      _buildQuickTtdRow('Пас АВП', 'pass_avp'),
    ],
  );
}

  Widget _buildQuickPassSection() {
  return Column(
    children: [
      _buildQuickTtdRow('Вперед К', 'forward_short'),
      const SizedBox(height: 8),
      _buildQuickTtdRow('Вперед С', 'forward_medium'),
      const SizedBox(height: 8),
      _buildQuickTtdRow('Вперед Д', 'forward_long'),
      const SizedBox(height: 8),
      _buildQuickTtdRow('Поперек К', 'side_short'),
      const SizedBox(height: 8),
      _buildQuickTtdRow('Поперек С', 'side_medium'),
      const SizedBox(height: 8),
      _buildQuickTtdRow('Поперек Д', 'side_long'),
      const SizedBox(height: 8),
      _buildQuickTtdRow('Назад К', 'back_short'),
      const SizedBox(height: 8),
      _buildQuickTtdRow('Назад С', 'back_medium'),
      const SizedBox(height: 8),
      _buildQuickTtdRow('Назад Д', 'back_long'),
    ],
  );
}

  Widget _buildQuickDefenseSection() {
    return ListView(
      children: [
        _buildQuickTtdRow('Отбор', 'tackle_duel'),
        _buildQuickTtdRow('Перехват', 'interception'),
        _buildQuickTtdRow('Подбор', 'recovery'),
        _buildQuickTtdRow('Игра головой', 'header_play'),
        _buildQuickTtdRow('Аут', 'throw_ins'),
      ],
    );
  }

 Widget _buildQuickGoalkeeperSection() {
  return Column(
    children: [
      _buildQuickTtdRow('Ввод рукой', 'hand_distribution'),
      const SizedBox(height: 8),
      _buildQuickTtdRow('Выход', 'coming_out'),
      const SizedBox(height: 8),
      _buildQuickTtdRow('Ближний бой', 'close_combat'),
      const SizedBox(height: 8),
      _buildQuickTtdRow('Перехват', 'interceptions'),
      const SizedBox(height: 8),
      _buildQuickTtdRow('За штрафной', 'outside_box'),
      const SizedBox(height: 8),
      _buildQuickTtdRow('Пас К', 'pass_short'),
      const SizedBox(height: 8),
      _buildQuickTtdRow('Пас С', 'pass_medium'),
      const SizedBox(height: 8),
      _buildQuickTtdRow('Пас Д', 'pass_long'),
      const SizedBox(height: 8),
      _buildQuickTtdRowCounter('Сэйв', 'saves'),
      const SizedBox(height: 8),
      _buildQuickTtdRowCounter('Пропущено', 'conceded'),
    ],
  );
}

  void _rebuildVideoCountersFromTotals(List<Map<String, dynamic>> rows) {
    _videoSuccessCountersCache.clear();
    _videoFailCountersCache.clear();
    _videoSingleCountersCache.clear();

    for (final row in rows) {
      final playerId = _i(row['player_id']);
      if (playerId <= 0) continue;

      final rawSuccess = row['success'];
      if (rawSuccess is Map) {
        final map = <String, int>{};
        rawSuccess.forEach((key, value) {
          map[key.toString()] = _i(value);
        });
        _videoSuccessCountersCache[playerId] = map;
      }

      final rawFail = row['fail'];
      if (rawFail is Map) {
        final map = <String, int>{};
        rawFail.forEach((key, value) {
          map[key.toString()] = _i(value);
        });
        _videoFailCountersCache[playerId] = map;
      }

      final rawSingle = row['single'];
      if (rawSingle is Map) {
        final map = <String, int>{};
        rawSingle.forEach((key, value) {
          map[key.toString()] = _i(value);
        });
        _videoSingleCountersCache[playerId] = map;
      }
    }

    _needsCacheUpdate = true;
    _scheduleRebuild();
  }

 Widget _buildQuickTtdRow(String label, String code) {
  final totalSuccessValue = _currentVideoSuccessValue(code);
  final totalFailValue = _currentVideoFailValue(code);

  final previewSuccess = totalSuccessValue;
  final previewFail = totalFailValue;

  final totalPercent = _quickSuccessPercent(
    totalSuccessValue,
    totalFailValue,
  );

  final hasValue = (totalSuccessValue + totalFailValue) > 0;

  final hasEvents = hasValue;
  final isExpanded = _expandedQuickMetricCode == code;

  return AnimatedContainer(
    duration: const Duration(milliseconds: 220),
    curve: Curves.easeOut,
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      gradient: isExpanded
          ? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF1F7A4D).withOpacity(0.04),
                Colors.white,
              ],
            )
          : null,
      color: isExpanded ? null : Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: isExpanded
            ? const Color(0xFFBFDBFE)
            : const Color(0xFFE2E8F0),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.025),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _toggleQuickMetricDetails(code),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.sports_soccer_rounded,
                    size: 18,
                    color: Color(0xFF1F7A4D),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                if (!isExpanded) ...[
                  if (previewSuccess > 0) ...[
                    _buildQuickInlineCounterBubble(
                      value: previewSuccess,
                      positive: true,
                    ),
                    const SizedBox(width: 6),
                  ],
                  if (previewFail > 0) ...[
                    _buildQuickInlineCounterBubble(
                      value: previewFail,
                      positive: false,
                    ),
                    const SizedBox(width: 6),
                  ],
                ],
                if (hasEvents)
                  GestureDetector(
                    onTap: () => _showTtdEventsList(code, label),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.history_rounded,
                        size: 16,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxHeight: 260,
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      _buildStatSection(
                        title: 'Всего',
                        success: totalSuccessValue,
                        fail: totalFailValue,
                        percent: totalPercent,
                        successColor: const Color(0xFF16A34A),
                        failColor: const Color(0xFFDC2626),
                        percentColor: const Color(0xFF1F7A4D),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildQuickWideActionButton(
                              icon: Icons.add_rounded,
                              text: 'Успешно',
                              color: const Color(0xFF16A34A),
                              bg: const Color(0xFFECFDF3),
                              border: const Color(0xFFBBF7D0),
                              onTap: () async {
                                await _saveQuickTtd(code, label, true);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildQuickWideActionButton(
                              icon: Icons.remove_rounded,
                              text: 'Неудачно',
                              color: const Color(0xFFDC2626),
                              bg: const Color(0xFFFEF2F2),
                              border: const Color(0xFFFECACA),
                              onTap: () async {
                                await _saveQuickTtd(code, label, false);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildQuickWideActionButton(
                              icon: Icons.undo_rounded,
                              text: 'Убрать +',
                              color: const Color(0xFF15803D),
                              bg: const Color(0xFFF0FDF4),
                              border: const Color(0xFFBBF7D0),
                              onTap: () async {
                                await _deleteLastTtdByType(
                                  metricCode: code,
                                  isPositive: true,
                                  metricTitle: label,
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildQuickWideActionButton(
                              icon: Icons.undo_rounded,
                              text: 'Убрать -',
                              color: const Color(0xFFB91C1C),
                              bg: const Color(0xFFFEF2F2),
                              border: const Color(0xFFFECACA),
                              onTap: () async {
                                await _deleteLastTtdByType(
                                  metricCode: code,
                                  isPositive: false,
                                  metricTitle: label,
                                );
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
          ),
        ],
      ),
    ),
  );
}

  Widget _buildStatSection({
    required String title,
    required int success,
    required int fail,
    required String percent,
    required Color successColor,
    required Color failColor,
    required Color percentColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildStatChip(
                label: '',
                value: success.toString(),
                color: successColor,
                icon: Icons.check_circle_outline,
              ),
              const SizedBox(width: 8),
              _buildStatChip(
                label: '',
                value: fail.toString(),
                color: failColor,
                icon: Icons.cancel_outlined,
              ),
              const SizedBox(width: 8),
              _buildStatChip(
                label: '',
                value: percent,
                color: percentColor,
                icon: Icons.trending_up,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(width: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: color.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

Widget _buildQuickSummaryRow() {
  final total = _videoAllTotal();
  final success = _videoSuccessTotal();
  final fail = _videoFailTotal();
  final single = _videoSingleTotal();
  final efficiency = _quickSuccessPercent(success, fail);

  return AnimatedContainer(
    duration: const Duration(milliseconds: 220),
    curve: Curves.easeOut,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          const Color(0xFF1F7A4D).withOpacity(0.06),
          const Color(0xFF7C3AED).withOpacity(0.025),
        ],
      ),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFE2E8F0)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.025),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            setState(() {
              _quickSummaryCollapsed = !_quickSummaryCollapsed;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F7A4D).withOpacity(0.10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.analytics_outlined,
                    size: 18,
                    color: Color(0xFF1F7A4D),
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Статистика',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: _quickSummaryCollapsed ? 0 : 0.5,
                  duration: const Duration(milliseconds: 220),
                  child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 220),
          crossFadeState: _quickSummaryCollapsed
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryStat(
                        label: 'Всего',
                        value: total.toString(),
                        color: const Color(0xFF1F7A4D),
                        icon: Icons.analytics_outlined,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildSummaryStat(
                        label: 'Успешно',
                        value: success.toString(),
                        color: const Color(0xFF16A34A),
                        icon: Icons.check_circle_outline,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildSummaryStat(
                        label: 'Неудачно',
                        value: fail.toString(),
                        color: const Color(0xFFDC2626),
                        icon: Icons.cancel_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryStat(
                        label: 'Счёт',
                        value: single.toString(),
                        color: const Color(0xFFF59E0B),
                        icon: Icons.score_outlined,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildSummaryStat(
                        label: 'Эффективность',
                        value: efficiency,
                        color: const Color(0xFF7C3AED),
                        icon: Icons.percent,
                      ),
                    ),
                    const Expanded(child: SizedBox()),
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


Widget _buildSummaryStat({
  required String label,
  required String value,
  required Color color,
  required IconData icon,
}) {
  return Container(
    height: 92,
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withOpacity(0.10)),
      boxShadow: [
        BoxShadow(
          color: color.withOpacity(0.05),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 15, color: color),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: color,
            height: 1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: Color(0xFF64748B),
            height: 1.1,
          ),
        ),
      ],
    ),
  );
}

Widget _buildMiniSummaryChip({
  required String value,
  required String label,
  required Color color,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: color.withOpacity(0.12)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: color.withOpacity(0.85),
          ),
        ),
      ],
    ),
  );
}
Widget _buildQuickTtdRowCounter(String label, String code) {
  final episodeValue = _currentTtdSingleValue(code);
  final matchValue = _currentVideoSingleValue(code);
  final previewValue = episodeValue != 0 ? episodeValue : matchValue;

  final hasValue = episodeValue > 0 || matchValue > 0;
  final isExpanded = _expandedQuickMetricCode == code;

  return AnimatedContainer(
    duration: const Duration(milliseconds: 220),
    curve: Curves.easeOut,
    margin: const EdgeInsets.only(bottom: 12),
    decoration: BoxDecoration(
      gradient: isExpanded
          ? LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFFFFFBEB),
                Colors.white,
              ],
            )
          : null,
      color: isExpanded ? null : Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: isExpanded
            ? const Color(0xFFFDE68A)
            : const Color(0xFFE2E8F0),
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.025),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _toggleQuickMetricDetails(code),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.scoreboard_outlined,
                    size: 18,
                    color: Color(0xFFF59E0B),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                if (!isExpanded && previewValue != 0) ...[
                  _buildQuickSingleValueBubble(value: previewValue),
                  const SizedBox(width: 6),
                ],
                if (hasValue)
                  GestureDetector(
                    onTap: () => _showTtdEventsList(code, label),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.history_rounded,
                        size: 16,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                AnimatedRotation(
                  turns: isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: isExpanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        _buildCounterStat(
                          label: 'В эпизоде',
                          value: episodeValue.toString(),
                          color: const Color(0xFFF59E0B),
                          icon: Icons.video_label_outlined,
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 1,
                          height: 40,
                          color: const Color(0xFFE2E8F0),
                        ),
                        const SizedBox(width: 12),
                        _buildCounterStat(
                          label: 'За матч',
                          value: matchValue.toString(),
                          color: const Color(0xFF7C3AED),
                          icon: Icons.analytics_outlined,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildQuickWideActionButton(
                          icon: Icons.add_rounded,
                          text: '+1',
                          color: const Color(0xFF16A34A),
                          bg: const Color(0xFFECFDF3),
                          border: const Color(0xFFBBF7D0),
                          onTap: () async {
                            await _saveSingleTtd(code, label, 1);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildQuickWideActionButton(
                          icon: Icons.remove_rounded,
                          text: '-1',
                          color: const Color(0xFFDC2626),
                          bg: const Color(0xFFFEF2F2),
                          border: const Color(0xFFFECACA),
                          onTap: () async {
                            if (episodeValue <= 0 && matchValue <= 0) return;
                            await _saveSingleTtd(code, label, -1);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildPossessionBadge() {
  if (!_aiTracking.showPossessionOverlay) {
    return const SizedBox.shrink();
  }

  final ownerName = _aiTracking.currentBallOwnerName;
  if (ownerName == null || ownerName.isEmpty) {
    return const SizedBox.shrink();
  }

  const myTeamTag = 'home';
  const opponentTeamName = 'Соперник';

  final teamTag = _aiTracking.currentBallOwnerTeamTag;
  final dotColor = teamTag == myTeamTag
      ? ReviewUiPalette.primary
      : ReviewUiPalette.red;

  final teamName = teamTag == myTeamTag ? widget.teamName : opponentTeamName;

  return Positioned(
    right: 14,
    top: 14,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.94),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: dotColor.withOpacity(0.28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Владение: $ownerName • $teamName',
            style: const TextStyle(
              color: ReviewUiPalette.text,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ),
  );
}



  Widget _buildCounterStat({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 12, color: color.withOpacity(0.7)),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: color.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickWideActionButton({
    required IconData icon,
    required String text,
    required Color color,
    required Color bg,
    required Color border,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: _quickSaving ? null : onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 6),
            Text(
              text,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

 Widget _buildQuickTtdSectionBody() {
  return SingleChildScrollView(
    physics: const BouncingScrollPhysics(),
    child: (() {
      switch (_quickTtdSection) {
        case 'pass':
          return _buildQuickPassSection();
        case 'gk':
          return _buildQuickGoalkeeperSection();
        case 'main':
        default:
          return _buildQuickMainSection();
      }
    })(),
  );
}
  Widget _buildQuickTtdDock() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                const Icon(Icons.flash_on_rounded, color: Color(0xFF1F7A4D)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Быстрый ввод ТТД',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                if (_selectedPlayer != null)
                  Flexible(
                    child: Text(
                      _playerFullName(_selectedPlayer!),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F7A4D),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: TextField(
              controller: _noteCtrl,
              decoration: InputDecoration(
                hintText: 'Комментарий',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: GridView.count(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.2,
             children: [
  _quickTtdButton(
    'Передача +',
    Icons.arrow_forward_rounded,
    true,
    () => _saveQuickTtd(
      'pass_success',
      'Передача +',
      true,
    ),
  ),
  _quickTtdButton(
    'Передача -',
    Icons.close_rounded,
    false,
    () => _saveQuickTtd(
      'pass_fail',
      'Передача -',
      false,
    ),
  ),
  _quickTtdButton(
    'Отбор +',
    Icons.shield_rounded,
    true,
    () => _saveQuickTtd(
      'tackle_success',
      'Отбор +',
      true,
    ),
  ),
  _quickTtdButton(
    'Отбор -',
    Icons.gpp_bad_rounded,
    false,
    () => _saveQuickTtd(
      'tackle_fail',
      'Отбор -',
      false,
    ),
  ),
  _quickTtdButton(
    'Удар +',
    Icons.sports_soccer_rounded,
    true,
    () => _saveQuickTtd(
      'shot_success',
      'Удар +',
      true,
    ),
  ),
  _quickTtdButton(
    'Удар -',
    Icons.sports_soccer_outlined,
    false,
    () => _saveQuickTtd(
      'shot_fail',
      'Удар -',
      false,
    ),
  ),
  _quickTtdButton(
    'Перехват',
    Icons.ads_click_rounded,
    true,
    () => _saveQuickTtd(
      'interception',
      'Перехват',
      true,
    ),
  ),
  _quickTtdButton(
    'Потеря',
    Icons.remove_circle_outline_rounded,
    false,
    () => _saveQuickTtd(
      'loss',
      'Потеря',
      false,
    ),
  ),
  _quickTtdButton(
    'Гол',
    Icons.emoji_events_rounded,
    true,
    () => _saveQuickTtd(
      'goal',
      'Гол',
      true,
    ),
  ),
  _quickTtdButton(
    'Ассист',
    Icons.star_rounded,
    true,
    () => _saveQuickTtd(
      'assist',
      'Ассист',
      true,
    ),
  ),
],
            ),
          ),
          if (_ttdPanelMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _ttdPanelMessageIsError
                    ? Colors.red.withOpacity(0.08)
                    : Colors.green.withOpacity(0.08),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(20),
                ),
              ),
              child: Text(
                _ttdPanelMessage!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _ttdPanelMessageIsError
                      ? Colors.red.shade700
                      : Colors.green.shade700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSimpleModeLayout() {
    return Column(
      children: [
        _buildCompactHeader(),
        const SizedBox(height: 6),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    _buildVideoToolbar(),
                    Expanded(
                      child: _buildVideoSection(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 220,
                child: _buildPlayersSidePanel(),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 300,
                child: Column(
                  children: [
                    _buildQuickSelectedInfoCard(),
                    const SizedBox(height: 8),
                    Expanded(
                      child: _buildQuickTtdDockCompact(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Future<void> _openMatchPlayersSelection() async {
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) {
      return FractionallySizedBox(
        heightFactor: 0.92,
        child: MatchPlayersSelectionWidget(
          players: _allTeamPlayers.isNotEmpty ? _allTeamPlayers : _players,
          initiallySelectedPlayers: _matchPlayers,
          onApply: (selectedPlayers) async {
            try {
              await MatchPlayersService.saveMatchPlayers(
                matchId: widget.matchId,
                teamId: widget.teamId,
                players: selectedPlayers,
              );

              setState(() {
                _matchPlayers = List<Map<String, dynamic>>.from(selectedPlayers);
                _filteredPlayers =
                    List<Map<String, dynamic>>.from(selectedPlayers);

                if (_selectedPlayer != null) {
                  final exists = selectedPlayers.any(
                    (p) => Formatters.safeString(p['id']) ==
                        Formatters.safeString(_selectedPlayer!['id']),
                  );
                  if (!exists) {
                    _selectedPlayer = null;
                  }
                }
              });

              if (mounted) Navigator.pop(context);

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Состав матча сохранён'),
                  ),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Ошибка: $e')),
                );
              }
            }
          },
        ),
      );
    },
  );
}

  Widget _buildVideoEpisodesTab() {
    if (_isSimpleMode) {
      return _buildSimpleModeLayout();
    }

    return Column(
      children: [
        _buildCompactHeader(),
        const SizedBox(height: 6),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  children: [
                    _buildVideoToolbar(),
                    Expanded(
                      child: _buildVideoSection(),
                    ),
                  ],
                ),
              ),
              // В методе _buildVideoEpisodesTab() замените:
if (_showAiPanelInline) ...[
  const SizedBox(width: 8),
  Container(
    width: 420,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFE2E8F0)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.track_changes_rounded, color: Color(0xFF7C3AED)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'AI Анализ',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _showAiPanelInline = false;
                  });
                },
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
           child: AiAnalyticsPanelWidget(
  aiTracking: _aiTracking,
  showHeatmap: _showHeatmap,
  statusText: _aiStatusText,
  myTeamName: widget.teamName,
  opponentTeamName: 'Соперник',
  myTeamTag: 'home',
  onToggleAi: () {
    _startServerAiAnalysis();
  },
  onToggleHeatmap: (value) {
    setState(() {
      _showHeatmap = value;
    });
  },
  onBindTrack: _bindAiTrackToPlayer,
  onJumpToTime: _jumpToTime,
  onExport: _exportAiAnalysis,
  onConfirmSuggestion: _confirmAiSuggestion,
),          ),
        ),
      ],
    ),
  ),
],
              if (!_isVideoFullscreen && !_showAiPanelInline) ...[
                const SizedBox(width: 8),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 280),
                  child: _buildPlayersSidePanel(),
                ),
                const SizedBox(width: 8),
                _buildEpisodesPanelWrapper(),
              ],
            ],
          ),
        ),
      ],
    );
  }
  
 
  Widget _buildHeaderActionButton({
    required IconData icon,
    required VoidCallback onTap,
    required Color iconColor,
    bool accent = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            gradient: accent
                ? LinearGradient(
                    colors: [
                      AppColors.primaryGreen.withOpacity(0.10),
                      AppColors.primaryGreen.withOpacity(0.04),
                    ],
                  )
                : null,
            color: accent ? null : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: accent
                  ? AppColors.primaryGreen.withOpacity(0.18)
                  : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, size: 20, color: iconColor),
        ),
      ),
    );
  }

  Widget _buildReportsTab() {
    return Column(
      children: [
        _buildCompactHeader(),
        const SizedBox(height: 4),
        Expanded(
          child: ReportTablesWidget(
  mainReportRows: _mainReportRows,
  passReportRows: _passReportRows,
  goalkeeperReportRows: _goalkeeperReportRows,
  reportLoading: _reportLoading,
  selectedMatchPlayers: _matchPlayers,
  onBack: () {
    _tabController.animateTo(0);  },
            ),
          
        ),
      ],
    );
  }

   Widget _buildFullscreenVideoOverlay() {
    if (!_videoReady) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          Positioned.fill(
            child: Center(
              child: GestureDetector(
                onTap: _toggleOverlay,
                onDoubleTap: _togglePlayPause,
                child: AspectRatio(
                  aspectRatio: _controller.value.aspectRatio == 0
                      ? 16 / 9
                      : _controller.value.aspectRatio,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: _controller.value.size.width,
                            height: _controller.value.size.height,
                            child: VideoPlayer(_controller),
                          ),
                        ),
                      ),
                      if (_showHeatmap && _aiTracking.selectedTrack != null)
                        Positioned.fill(
                          child: CustomPaint(
                            painter: TrackingHeatmapPainter(
                              points: _aiTracking.selectedTrack!.points,
                              color: _aiTracking.selectedTrack!.color,
                            ),
                          ),
                        ),
                      Positioned.fill(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final overlaySize = Size(
                              constraints.maxWidth,
                              constraints.maxHeight,
                            );

                            return Stack(
                              children: [
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTapUp: (details) async {
                                    _showOverlay();
                                    _showTapPointMarker(details.localPosition);

                                    final mappedTap = _mapTapToAnalysisSpace(
                                      localPosition: details.localPosition,
                                      sourceSize: _analysisFrameSize(),
                                      overlaySize: overlaySize,
                                      fit: BoxFit.cover,
                                    );

                                    
                                    await _warmupDetections();
                                    _aiTracking.selectTrackByTap(mappedTap);

                                    if (_aiTracking.isLocked &&
                                        !_aiTracking.isRunning) {
                                      _startAiLoopDirectly(
  overlaySize: overlaySize,
  fit: BoxFit.cover,
);
                                    }
                                  },
                                 child: CustomPaint(
  painter: PlayerTrackingPainter(
    controller: _aiTracking,
    currentTimeMs: _controller.value.position.inMilliseconds,
    fieldSize: overlaySize,
  ),
),
                                ),
                                _buildTapMarkerOverlay(),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

         // if (_showOverlayUi) _buildTopGradientOverlay(),
         // if (_showOverlayUi) _buildBottomGradientOverlay(),

          Positioned(
            top: 14,
            left: 14,
            right: 14,
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  _glassIconButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: _exitFullscreen,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.35),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.08),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.matchTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.teamName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.72),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
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

          Positioned(
            left: 14,
            right: 14,
            bottom: 14,
            child: SafeArea(
              top: false,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: VideoProgressIndicator(
                            _controller,
                            allowScrubbing: true,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            colors: const VideoProgressColors(
                              playedColor: Colors.white,
                              bufferedColor: Colors.white30,
                              backgroundColor: Colors.white12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Text(
                              Formatters.formatDuration(
                                _controller.value.position,
                              ),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            _glassIconButton(
                              icon: Icons.replay_10_rounded,
                              onTap: () => _seekRelative(-10),
                            ),
                            const SizedBox(width: 8),
                            _glassIconButton(
                              icon: _controller.value.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              onTap: _togglePlayPause,
                              active: true,
                            ),
                            const SizedBox(width: 8),
                            _glassIconButton(
                              icon: Icons.forward_10_rounded,
                              onTap: () => _seekRelative(10),
                            ),
                            const SizedBox(width: 8),
                            _glassIconButton(
                              icon: Icons.camera_alt_outlined,
                              onTap: _createEpisodeFromCurrentFrame,
                            ),
                            const Spacer(),
                            Text(
                              Formatters.formatDuration(
                                _controller.value.duration,
                              ),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
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
          ),
        ],
      ),
    );
  }
  
    
  
    Widget _glassIconButton({
  required IconData icon,
  required VoidCallback onTap,
  bool active = false,
}) {
  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: active ? const Color(0xFF1F7A4D) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.white.withOpacity(0.10),
          ),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 20,
        ),
      ),
    ),
  );
}
  
     

  Widget _buildModePillButton({
    required String title,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    colors: [Color(0xFF1F7A4D), Color(0xFF22C55E)],
                  )
                : null,
            color: selected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 15,
                color: Colors.white,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
    Widget _buildSlidingOverlayPanel() {
    final bool isOpen = _activeOverlayPanel != ReviewOverlayPanel.none;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      right: isOpen ? 82 : -460,
      top: 90,
      bottom: 20,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        opacity: isOpen ? 1 : 0,
        child: IgnorePointer(
          ignoring: !isOpen,
          child: Container(
            width: 380,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.16),
                  blurRadius: 28,
                  offset: const Offset(-8, 14),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildSlidingPanelHeader(),
                const Divider(height: 1),
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(28),
                    ),
                    child: Container(
                      color: const Color(0xFFF8FBFF),
                      child: _buildActivePanelBody(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
   Widget _buildSlidingPanelHeader() {
  String title = 'Панель';
  IconData icon = Icons.widgets_outlined;
  String subtitle = 'Инструменты анализа';

  switch (_activeOverlayPanel) {
    case ReviewOverlayPanel.players:
      title = 'Игроки';
      icon = Icons.people_alt_outlined;
      subtitle = 'Выбор игрока для анализа';
      break;
    case ReviewOverlayPanel.episodes:
      title = 'Эпизоды';
      icon = Icons.video_library_outlined;
      subtitle = 'Эпизоды для Pro режима';
      break;
   case ReviewOverlayPanel.ttd:
  title = 'TTD';
  icon = Icons.flash_on_rounded;
  subtitle = 'Быстрый ввод технико-тактических действий';
      break;
    case ReviewOverlayPanel.analytics:
      title = 'Аналитика';
      icon = Icons.analytics_outlined;
      subtitle = 'AI, heatmap и расширенный анализ';
      break;
    case ReviewOverlayPanel.none:
      break;
  }

  return Padding(
    padding: const EdgeInsets.fromLTRB(18, 16, 12, 14),
    child: Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFF1F7A4D).withOpacity(0.10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: const Color(0xFF1F7A4D), size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
        InkWell(
          onTap: _closePanels,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.close_rounded,
              color: Color(0xFF334155),
            ),
          ),
        ),
      ],
    ),
  );
}

  Widget _buildBottomPlayersStrip() {
  final source = _matchPlayers.isNotEmpty ? _matchPlayers : _players;

  if (source.isEmpty) return const SizedBox.shrink();

  return Positioned(
    left: 12,
    right: 12,
    bottom: 12,
    child: IgnorePointer(
      ignoring: false,
      child: SizedBox(
        height: 86,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: source.length,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (context, index) {
            final player = source[index];
            final isSelected = _selectedPlayer != null &&
                _i(_selectedPlayer!['id']) == _i(player['id']);
            final photo = _playerPhoto(player);

            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedPlayer = player;
                });
                _resetLocalCache();
                _showOverlay();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: 180,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? ReviewUiPalette.primary
                      : Colors.white.withOpacity(0.94),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? ReviewUiPalette.primary2
                        : ReviewUiPalette.line,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isSelected ? 0.16 : 0.10),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: isSelected
                          ? Colors.white.withOpacity(0.18)
                          : ReviewUiPalette.primary.withOpacity(0.10),
                      backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
                      child: photo.isEmpty
                          ? Text(
                              _playerFullName(player).isNotEmpty
                                  ? _playerFullName(player)[0].toUpperCase()
                                  : '?',
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : ReviewUiPalette.primary,
                                fontWeight: FontWeight.w900,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _playerFullName(player),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : ReviewUiPalette.text,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _playerPosition(player).isEmpty
                                ? 'Позиция'
                                : _playerPosition(player),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white.withOpacity(0.78)
                                  : ReviewUiPalette.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}

  
     Widget _buildActivePanelBody() {
  switch (_activeOverlayPanel) {
    case ReviewOverlayPanel.players:
      return Padding(
        padding: const EdgeInsets.all(12),
        child: _buildPlayersPanelWithBottomSelection(),
      );

    case ReviewOverlayPanel.episodes:
      return Padding(
        padding: const EdgeInsets.all(12),
        child: EpisodesListWidget(
  episodes: _episodes,
  players: _matchPlayers.isNotEmpty ? _matchPlayers : _players,
  selectedEpisode: _selectedEpisode,
  creatingEpisode: _creatingEpisode,
  isVideoFullscreen: _isVideoFullscreen,
  onEpisodeSelected: _selectEpisode,
  onEpisodeDeleted: (id) => _deleteEvent(id),
  onEpisodeEdited: _editEpisode,
  onEpisodeDetail: _openEpisodeTtdDetail,
  onCreateEpisode: _createEpisodeFromCurrentFrame,
  onExitFullscreen: _exitFullscreen,
),
      );

    case ReviewOverlayPanel.ttd:
  return Padding(
  padding: const EdgeInsets.all(12),
  child: _buildQuickTtdDockCompact(),
);
      return SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: TtdPanelWidget(
          selectedPlayer: _selectedPlayer,
          selectedEpisode: _selectedEpisode,
          quickSaving: _quickSaving,
          saving: _saving,
          noteCtrl: _noteCtrl,
          message: _ttdPanelMessage,
          isMessageError: _ttdPanelMessageIsError,
          ttdSection: _ttdSection,
          onSectionChanged: (section) => setState(() => _ttdSection = section),
          onSaveEvent: _saveEvent,
          onSaveQuickTtd: _saveQuickTtd,
          onSaveSingleTtd: _saveSingleTtd,
          successCounters: _currentTtdSuccessCounters(),
          failCounters: _currentTtdFailCounters(),
          singleCounters: _currentTtdSingleCounters(),
          currentRating: _currentTtdRating(),
        ),
      );

    case ReviewOverlayPanel.analytics:
      return SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: AiAnalyticsPanelWidget(
          aiTracking: _aiTracking,
          showHeatmap: _showHeatmap,
          statusText: _aiStatusText,
          onToggleAi: _startServerAiAnalysis,
          onToggleHeatmap: (v) => setState(() => _showHeatmap = v),
          onBindTrack: _bindAiTrackToSelectedPlayer,
          onJumpToTime: _jumpToTrackingTime,
          onExport: _exportAiData,
          onConfirmSuggestion: _confirmAiSuggestion,
        ),
      );

    case ReviewOverlayPanel.none:
      return const SizedBox.shrink();
  }
}

    Widget _buildBottomCenterProToolbar() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      left: 18,
      right: 90,
      bottom: 18,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        opacity: _showBottomQuickDock ? 1 : 0,
        child: IgnorePointer(
          ignoring: !_showBottomQuickDock,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.38),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.16),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    _buildProDockButton(
                      icon: Icons.people_alt_outlined,
                      label: 'Игроки',
                      onTap: () => _togglePanel(ReviewOverlayPanel.players),
                    ),
                    const SizedBox(width: 8),
                    _buildProDockButton(
                      icon: Icons.replay_10_rounded,
                      label: '-10',
                      onTap: () => _seekRelative(-10),
                    ),
                    const SizedBox(width: 8),
                    _buildProDockButton(
                      icon: _controller.value.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      label: _controller.value.isPlaying ? 'Пауза' : 'Старт',
                      onTap: _togglePlayPause,
                      primary: true,
                    ),
                    const SizedBox(width: 8),
                    _buildProDockButton(
                      icon: Icons.forward_10_rounded,
                      label: '+10',
                      onTap: () => _seekRelative(10),
                    ),
                    const SizedBox(width: 8),
                    _buildProDockButton(
                      icon: Icons.camera_alt_outlined,
                      label: 'Эпизод',
                      onTap: _createEpisodeFromCurrentFrame,
                    ),
                    const SizedBox(width: 8),
                    _buildProDockButton(
                      icon: Icons.analytics_outlined,
                      label: 'AI',
                      onTap: () => _togglePanel(ReviewOverlayPanel.analytics),
                    ),
                    const Spacer(),
                    _buildTimelineInfoPill(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  
    Widget _buildProDockButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool primary = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          _showOverlay();
          onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            gradient: primary
                ? const LinearGradient(
                    colors: [Color(0xFF1F7A4D), Color(0xFF22C55E)],
                  )
                : null,
            color: primary ? null : Colors.white.withOpacity(0.10),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: primary
                  ? Colors.transparent
                  : Colors.white.withOpacity(0.08),
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: Colors.white,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
    Widget _buildTimelineInfoPill() {
    final pos = _videoReady ? _controller.value.position : Duration.zero;
    final dur = _videoReady ? _controller.value.duration : Duration.zero;

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.schedule_rounded,
            color: Colors.white,
            size: 17,
          ),
          const SizedBox(width: 8),
          Text(
            '${Formatters.formatDuration(pos)} / ${Formatters.formatDuration(dur)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
  
    Widget _buildModernReportsTab() {
    return Column(
      children: [
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F7A4D).withOpacity(0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.analytics_outlined,
                    color: Color(0xFF1F7A4D),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Отчёты и аналитика',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Сводные таблицы по TTD, передачам и вратарским действиям',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _buildHeaderStatChip(
                  label: 'Игроков',
                  value: '${_matchPlayers.length}',
                  color: const Color(0xFF1F7A4D),
                ),
                const SizedBox(width: 8),
                _buildHeaderStatChip(
                  label: 'Эпизодов',
                  value: '${_episodes.length}',
                  color: const Color(0xFF16A34A),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 14,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: ReportTablesWidget(
  mainReportRows: _mainReportRows,
  passReportRows: _passReportRows,
  goalkeeperReportRows: _goalkeeperReportRows,
  reportLoading: _reportLoading,
  selectedMatchPlayers: _matchPlayers,
  onBack: () {
    _tabController.animateTo(0);
  },
),              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
    Widget _buildHeaderStatChip({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.14)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: color,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
  
  
       Widget _buildFloatingQuickDock() {
    final bool visible =
       _showBottomQuickDock;
       
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      right: 86,
      bottom: 18,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 220),
        opacity: visible ? 1 : 0,
        child: IgnorePointer(
          ignoring: !visible,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            width: _quickTtdCollapsed ? 72 : 420,
            height: _quickTtdCollapsed ? 72 : 500,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.16),
                  blurRadius: 26,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: _quickTtdCollapsed
                ? _buildCollapsedQuickTtdButton()
                : _buildExpandedQuickTtdPanel(),
          ),
        ),
      ),
    );
  }
  
    Widget _buildCollapsedQuickTtdButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _toggleQuickTtdCollapsed,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1F7A4D), Color(0xFF22C55E)],
            ),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.flash_on_rounded,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                'TTD',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.95),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
   Widget _buildExpandedQuickTtdPanel() {
  return Column(
    children: [
      Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 10),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xFFE2E8F0)),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.flash_on_rounded,
                size: 18,
                color: Color(0xFF1F7A4D),
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Быстрый TTD',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
            InkWell(
              onTap: _toggleQuickTtdCollapsed,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF475569),
                ),
              ),
            ),
          ],
        ),
      ),
      Expanded(
        child: _buildQuickTtdDockCompact(),
      ),
    ],
  );
}

   Widget _buildFallbackPortrait() {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 14,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.screen_rotation_alt_rounded,
                    size: 56,
                    color: Color(0xFF1F7A4D),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Поверни устройство',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Для удобной работы с видеоанализом открой экран в горизонтальном режиме.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  
    Widget _buildSelectedEpisodeOverlayBadge() {
  if (_selectedEpisode == null) {
    return const SizedBox.shrink();
  }

  final title = _s(_selectedEpisode!['event_title']).trim().isEmpty
      ? 'Эпизод'
      : _s(_selectedEpisode!['event_title']);
  final timeSec = _i(_selectedEpisode!['timecode_seconds']);

  return AnimatedPositioned(
    duration: const Duration(milliseconds: 240),
    curve: Curves.easeOutCubic,
    left: 18,
    top: 18,
    child: AnimatedOpacity(
      duration: const Duration(milliseconds: 220),
      opacity: _showOverlayUi ? 1 : 0,
      child: IgnorePointer(
        ignoring: !_showOverlayUi,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 320),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.94),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: ReviewUiPalette.line),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: ReviewUiPalette.primary.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.video_library_outlined,
                      color: ReviewUiPalette.primary,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: ReviewUiPalette.text,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Таймкод: ${Formatters.formatDuration(Duration(seconds: timeSec))}',
                          style: const TextStyle(
                            color: ReviewUiPalette.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  InkWell(
                    onTap: _clearSelectedEpisode,
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                        border: Border.all(color: ReviewUiPalette.line),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 14,
                        color: ReviewUiPalette.textMuted,
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
  );
}

  
    @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    Widget loadingBody() {
      return const ColoredBox(
        color: Color(0xFFF4F7FA),
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    Widget reviewBody() {
      final content = Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.all(_isVideoFullscreen ? 0 : 12),
              child: _tabController.index == 0
                  ? _buildVideoCanvas()
                  : _buildModernReportsTab(),
            ),
          ),
        ],
      );

      if (widget.embedded) {
        return content;
      }

      return SafeArea(child: content);
    }

    if (_loading) {
      final body = loadingBody();
      if (widget.embedded) return body;

      return const Scaffold(
        backgroundColor: Color(0xFFF4F7FA),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (widget.embedded) {
      return Container(
        color: const Color(0xFFF4F7FA),
        child: reviewBody(),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      body: isLandscape ? reviewBody() : _buildFallbackPortrait(),
    );
  }
}
