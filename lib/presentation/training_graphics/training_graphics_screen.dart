// lib/presentation/training_graphics/training_graphics_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';

import 'training_graphics_state.dart';
import 'widgets/tg_canvas.dart';
import 'widgets/tg_left_toolbar.dart';


import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/presentation/plans/plan_folders_screen.dart';
import 'package:sportoteka/presentation/plans/api/training_graphics_api.dart';
import 'package:sportoteka/presentation/training_graphics/widgets/tg_right_panel.dart';
import 'package:sportoteka/presentation/training_graphics/tg_models.dart';
import 'package:sportoteka/presentation/sportoteka_3d_pro/sportoteka_3d_pro_launcher.dart';
import 'tg_export_saver.dart';
import 'package:sportoteka/core/theme/app_typography.dart';

/// ================== ЦВЕТОВАЯ ПАЛИТРА ==================
class TgScreenPalette {
  // Премиальная светлая CMR-схема, взятая за основу из Tracker Pro.
  static const fontFamily = 'Inter';
  static const railWidth = 60.0;
  static const topBarHeight = 46.0;
  static const buttonHeight = 28.0;
  static const cardRadius = 8.0;
  static const panelRadius = 10.0;
  static const primaryGreen = Color(0xFF00A750);
  static const primaryGreenDark = Color(0xFF067A46);
  static const primaryGreenLight = Color(0xFF18C46B);
  static const lightGreen = Color(0xFFF3FBF7);

  static const background = Color(0xFFF6F7F9);
  static const surfaceDark = Color(0xFFFFFFFF);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceLight = Color(0xFFFAFBFC);
  static const surfaceHighlight = Color(0xFFF3F5F8);

  static const textPrimary = Color(0xFF0B0F14);
  static const textSecondary = Color(0xFF344054);
  static const textMuted = Color(0xFF6B7280);
  static const textLight = Color(0xFF98A2B3);

  static const border = Color(0xFFF0F2F4);
  static const borderLight = Color(0xFFE5E7EB);
  static const softLine = Color(0xFFF0F2F4);
  static const graphite = Color(0xFF344054);
  static const dim = Color(0xFF6B7280);

  static const error = Color(0xFFDC2626);
  static const warning = Color(0xFFF59E0B);
  static const success = primaryGreen;
  static const info = Color(0xFF2563EB);

  static const greenGradient = LinearGradient(
    colors: [primaryGreen, primaryGreenDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const darkGradient = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static List<BoxShadow> get windowShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(.040),
          blurRadius: 14,
          spreadRadius: -9,
          offset: const Offset(0, 6),
        ),
      ];

  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(.035),
          blurRadius: 12,
          spreadRadius: -7,
          offset: const Offset(0, 6),
        ),
      ];
}

/// ================== СТИЛИЗОВАННЫЕ КОМПОНЕНТЫ ==================
class TgScreenButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final bool isLoading;
  final Color? color;
  final double height;
  final double? width;
  final EdgeInsets padding;
  final bool isOutlined;

  const TgScreenButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.isLoading = false,
    this.color,
    this.height = 38,
    this.width,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    this.isOutlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null && !isLoading;

    return Material(
      color: isOutlined ? Colors.transparent : (color ?? TgScreenPalette.primaryGreen),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: isEnabled ? onPressed : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: height,
          width: width,
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: isOutlined
                ? Border.all(
                    color: color ?? TgScreenPalette.primaryGreen,
                    width: 1.5,
                  )
                : null,
            color: isOutlined
                ? Colors.transparent
                : (isEnabled ? null : TgScreenPalette.textLight.withOpacity(0.2)),
          ),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : child,
          ),
        ),
      ),
    );
  }
}


class TgScreenCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final bool isSelected;
  final VoidCallback? onTap;
  final double? height;
  final double? width;

  const TgScreenCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.color,
    this.isSelected = false,
    this.onTap,
    this.height,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: height,
          width: width,
          padding: padding,
          decoration: BoxDecoration(
            color: color ?? TgScreenPalette.surface,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isSelected ? TgScreenPalette.primaryGreen : TgScreenPalette.border,
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: TgScreenPalette.softShadow,
          ),
          child: child,
        ),
      ),
    );
  }
}

class TgScreenErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final VoidCallback? onDismiss;

  const TgScreenErrorBanner({
    super.key,
    required this.message,
    this.onRetry,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return TgScreenCard(
      color: TgScreenPalette.error.withOpacity(0.1),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: TgScreenPalette.error.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.error_outline,
              color: TgScreenPalette.error,
              size: 18.0,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              message,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: AppTypography.fontFamily,
                color: TgScreenPalette.textSecondary,
                fontWeight: FontWeight.w500,
                fontSize: AppTypography.bodySize,
              ),
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(width: 4),
            TgScreenButton(
              onPressed: onRetry,
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: const Text(
                "Повторить",
                style: TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: AppTypography.badgeSize,
                ),
              ),
            ),
          ],
          if (onDismiss != null) ...[
            const SizedBox(width: 4),
            IconButton(
              onPressed: onDismiss,
              icon: const Icon(Icons.close, size: 16, color: TgScreenPalette.textMuted),
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
            ),
          ],
        ],
      ),
    );
  }
}

class TgScreenLoadingOverlay extends StatelessWidget {
  final String message;

  const TgScreenLoadingOverlay({
    super.key,
    this.message = "Загрузка...",
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: TgScreenPalette.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: TgScreenPalette.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  color: TgScreenPalette.primaryGreen,
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                style: const TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  color: TgScreenPalette.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: AppTypography.sectionTitleSize,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ================== ОСНОВНОЙ ЭКРАН ==================
class TrainingGraphicsScreen extends StatefulWidget {
  const TrainingGraphicsScreen({
    super.key,
    this.teamId,
    this.teamName,
    this.clubId,
    this.clubName,
    this.selectMode = false,
    this.preselectedIds = const <int>[],
    this.graphicId,
    this.initialDocJson,
    this.initialFolderId,
    this.initialFolderTitle,
  });

  final int? teamId;
  final String? teamName;
  final int? clubId;
  final String? clubName;
  final bool selectMode;
  final List<int> preselectedIds;
  final int? graphicId;
  final dynamic initialDocJson;
  final int? initialFolderId;
  final String? initialFolderTitle;

  int get resolvedTeamId => teamId ?? 0;
  String get resolvedTeamName =>
      (teamName ?? "").trim().isNotEmpty ? teamName!.trim() : "Team";

  int get resolvedClubId => clubId ?? teamId ?? 0;
  String get resolvedClubName =>
      (clubName ?? "").trim().isNotEmpty ? clubName!.trim() : (teamName ?? "Club");

  @override
  State<TrainingGraphicsScreen> createState() => _TrainingGraphicsScreenState();
  
}



enum _ExitAction { cancel, exitWithoutSaving, saveAndExit }

class _TrainingGraphicsScreenState extends State<TrainingGraphicsScreen>
    with SingleTickerProviderStateMixin {
  late final TgState state = TgState(
    teamId: widget.resolvedTeamId,
    teamName: widget.resolvedTeamName,
  );
  
  bool _didLayoutFit = false;

// Добавьте этот метод в класс _TrainingGraphicsScreenState (в любое место внутри класса)
Future<void> _refreshSvg(String asset, PlayerColors colors) async {
  print('🔄 Refreshing SVG: $asset');
  // Здесь можно добавить логику обновления SVG если нужно
  // Например, если в TgCanvas есть метод для перезагрузки SVG:
  // if (_canvasKey.currentState != null) {
  //   await _canvasKey.currentState?.refreshSvg(asset, colors);
  // }
}


  final GlobalKey _repaintKey = GlobalKey(debugLabel: 'tg_repaint');
  final GlobalKey _exportRepaintKey = GlobalKey(debugLabel: 'tg_export_repaint');
  final GlobalKey<TgCanvasState> _canvasKey = GlobalKey<TgCanvasState>();
  final GlobalKey _rightPaneKey = GlobalKey();

  final DraggableScrollableController _panelController = DraggableScrollableController();
  late final AnimationController _animationController;
  Timer? _playbackTimer;
  bool _playbackRunning = false;
  bool _exportCleanMode = false;
  double _playbackProgress = 0.0;
  int _currentPlaybackStep = 0;
  final List<String> _playbackSteps = <String>['Шаг 1', 'Шаг 2', 'Шаг 3', 'Шаг 4'];
  final Map<String, int> _playbackRouteStepById = <String, int>{};
  final Map<String, String> _playbackRouteSubjectById = <String, String>{};
  String? _pendingPlaybackSubjectId;
  static const Duration _playbackTick = Duration(milliseconds: 60);
  static const Duration _playbackStepDuration = Duration(milliseconds: 1800);

  // ===== State =====
  bool saving = false;
  int? folderId;
  String folderTitle = "Без папки";
  int? _cmrSavedPlanId;
  DateTime? _cmrPlanSavedAt;
  int? graphicId;

  bool _docLoading = false;
  String? _docError;

  final Set<int> _selected = <int>{};
  bool _listLoading = false;
  String? _listError;
  List<Map<String, dynamic>> _items = [];

  bool _teamPlayersLoading = false;
  String? _teamPlayersError;
  List<Map<String, dynamic>> _teamPlayersFor3D = <Map<String, dynamic>>[];
  List<_TrainingTemplate> _userTrainingTemplates = <_TrainingTemplate>[];
  bool _templatesLoaded = false;
  List<_TrainingPlanExercise> _trainingPlanExercises = <_TrainingPlanExercise>[];
  bool _trainingPlanLoaded = false;
  Map<String, dynamic> _trainingCalendarMeta = <String, dynamic>{};
  Map<String, dynamic> _trainingAttendanceMeta = <String, dynamic>{};
  Map<String, dynamic> _trainingExecutionMeta = <String, dynamic>{};
  Map<String, dynamic> _trainingTrackerMeta = <String, dynamic>{};
  bool _workflowMetaLoaded = false;
  bool _workflowSyncing = false;

  String get _templatesStorageKey =>
      "${PrefUtils.prefName}tg_templates_c${widget.resolvedClubId}_t${widget.resolvedTeamId}";

  String get _trainingPlanStorageKey =>
      "${PrefUtils.prefName}tg_training_plan_c${widget.resolvedClubId}_t${widget.resolvedTeamId}";

  String get _trainingCalendarStorageKey =>
      "${PrefUtils.prefName}tg_training_calendar_c${widget.resolvedClubId}_t${widget.resolvedTeamId}";

  String get _trainingAttendanceStorageKey =>
      "${PrefUtils.prefName}tg_training_attendance_c${widget.resolvedClubId}_t${widget.resolvedTeamId}";

  String get _trainingExecutionStorageKey =>
      "${PrefUtils.prefName}tg_training_execution_c${widget.resolvedClubId}_t${widget.resolvedTeamId}";

  String get _trainingTrackerStorageKey =>
      "${PrefUtils.prefName}tg_training_tracker_c${widget.resolvedClubId}_t${widget.resolvedTeamId}";

  List<_TrainingTemplate> get _allTrainingTemplates => <_TrainingTemplate>[
        ..._builtInTrainingTemplates,
        ..._userTrainingTemplates,
      ];


  // Panel state
  bool _isPanelExpanded = false;
  bool _isPanelCollapsed = true;

  // Animation controls are opened on demand in a separate right-side window.
  // This keeps the pitch clear and prevents the timeline from covering the map.
  bool _animationPanelOpen = false;
  TgPanel _legacyPanelInitial = TgPanel.objects;

  // ===== Draft / Unsaved changes =====
  bool _dirty = false;
  bool _restoringDraft = false;
  Timer? _draftTimer;

  late final List<String> stamps = <String>[
    "assets/training/stamps/player_m/run.png",
    "assets/training/stamps/player_m/pass.png",
    "assets/training/stamps/player_m/stand.png",
    "assets/training/stamps/player_m/jump.png",
    "assets/training/stamps/player_m/goalkeeper.png",
    "assets/training/stamps/player_f/run.png",
    "assets/training/stamps/player_f/pass.png",
    "assets/training/stamps/player_f/stand.png",
    "assets/training/stamps/player_f/jump.png",
    "assets/training/stamps/player_f/goalkeeper.png",
    "assets/training/stamps/coach/male.png",
    "assets/training/stamps/coach/female.png",
    "assets/training/stamps/vorota1/back.png",
    "assets/training/stamps/vorota1/front.png",
    "assets/training/stamps/vorota1/left.png",
    "assets/training/stamps/vorota1/right.png",
    
    "assets/training/stamps/props/cap.svg",
    "assets/training/stamps/props/cone.svg",
    "assets/training/stamps/props/dummy.svg",
    "assets/training/stamps/props/flag_feet.svg",
    "assets/training/stamps/props/flag.svg",
    "assets/training/stamps/props/front.svg",
    "assets/training/stamps/props/ladder.svg",
    "assets/training/stamps/props/landscape.png",
    "assets/training/stamps/props/neutral.png",
    "assets/training/stamps/props/pole.svg",
    "assets/training/stamps/props/ring.svg",
   

   // ✅ RUN SVG variations
  "assets/training/stamps/run_svg/front_left.svg",
  "assets/training/stamps/run_svg/front_angle_left.svg",
  "assets/training/stamps/run_svg/front_angle_right.svg",
  "assets/training/stamps/run_svg/side_left.svg",
  "assets/training/stamps/run_svg/side_right.svg",
  "assets/training/stamps/run_svg/back_left.svg",
  "assets/training/stamps/run_svg/back_right.svg",
  "assets/training/stamps/run_svg/back_angle_left.svg",
  "assets/training/stamps/run_svg/back_angle_right.svg",
  "assets/training/stamps/run_svg/frontal_links.svg",
  
  
  // ✅ PASS SVG variations (добавляем сюда)
"assets/training/stamps/pass_svg/front_left.svg",
"assets/training/stamps/pass_svg/front_angle_left.svg",
"assets/training/stamps/pass_svg/front_angle_right.svg",
"assets/training/stamps/pass_svg/side_left.svg",
"assets/training/stamps/pass_svg/side_right.svg",
"assets/training/stamps/pass_svg/back_left.svg",
"assets/training/stamps/pass_svg/back_right.svg",
"assets/training/stamps/pass_svg/back_angle_left.svg",
"assets/training/stamps/pass_svg/back_angle_right.svg",
"assets/training/stamps/pass_svg/front_right.svg",



"assets/training/stamps/stand_svg/front_left.svg",
"assets/training/stamps/stand_svg/front_angle_left.svg",
"assets/training/stamps/stand_svg/front_angle_right.svg",
"assets/training/stamps/stand_svg/side_left.svg",
"assets/training/stamps/stand_svg/side_right.svg",
"assets/training/stamps/stand_svg/back_left.svg",
"assets/training/stamps/stand_svg/back_right.svg",
"assets/training/stamps/stand_svg/back_angle_left.svg",
"assets/training/stamps/stand_svg/back_angle_right.svg",
"assets/training/stamps/stand_svg/front_right.svg",

"assets/training/stamps/jump_svg/front_left.svg",
"assets/training/stamps/jump_svg/front_right.svg",
"assets/training/stamps/jump_svg/side_right.svg",
"assets/training/stamps/jump_svg/side_left.svg",
"assets/training/stamps/jump_svg/back_right.svg",
"assets/training/stamps/jump_svg/back_left.svg",

"assets/training/stamps/vrat_svg/front_left.svg",
"assets/training/stamps/vrat_svg/front_angle_left.svg",
"assets/training/stamps/vrat_svg/front_angle_right.svg",
"assets/training/stamps/vrat_svg/side_left.svg",
"assets/training/stamps/vrat_svg/side_right.svg",
"assets/training/stamps/vrat_svg/back_left.svg",
"assets/training/stamps/vrat_svg/back_right.svg",
"assets/training/stamps/vrat_svg/back_angle_left.svg",
"assets/training/stamps/vrat_svg/back_angle_right.svg",
"assets/training/stamps/vrat_svg/front_right.svg",

  
];

  static const double _topBarH = TgScreenPalette.topBarHeight;

  @override
  void initState() {
    super.initState();

    _panelController.addListener(_onPanelMoved);

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();

    _initializeState();
    _loadUserTrainingTemplates();
    _loadTrainingPlan();
    _loadTrainingWorkflowMeta();
    _loadTeamPlayersFor3D();
    state.addListener(_onStateChange);
  }

  // ==========================
  // Draft keys
  // ==========================
  String get _draftKey {
    final cid = widget.resolvedClubId;
    final tid = widget.resolvedTeamId;
    final gid = graphicId ?? 0;
    return "${PrefUtils.prefName}tg_draft_c${cid}_t${tid}_g${gid}";
  }

  String get _draftTsKey => "${_draftKey}_ts";

  // ==========================
  // Draft save/restore
  // ==========================
  void _scheduleDraftSave() {
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 600), () async {
      if (!mounted) return;
      if (_dirty) await _saveDraft();
    });
  }

  Future<void> _saveDraft() async {
    try {
      final docJson = _currentDocJsonWithPlayback();
      final jsonStr = jsonEncode(docJson);
      await PrefUtils.setStringValue(_draftKey, jsonStr);
      await PrefUtils.setStringValue(_draftTsKey, DateTime.now().toIso8601String());
    } catch (_) {}
  }

  Future<void> _clearDraft() async {
    try {
      await PrefUtils.removeKey(_draftKey);
      await PrefUtils.removeKey(_draftTsKey);
    } catch (_) {}
  }

  Future<void> _restoreDraftIfAny() async {
    try {
      final s = await PrefUtils.getStringValue(_draftKey);
      if (s == null || s.trim().isEmpty) return;

      if ((graphicId ?? 0) > 0) {
        final useDraft = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: TgScreenPalette.surface,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            title: const Text(
              "Найден черновик",
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                color: TgScreenPalette.textPrimary,
                fontWeight: FontWeight.w900,
              ),
            ),
            content: const Text(
              "Восстановить последнюю несохранённую версию схемы?",
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                color: TgScreenPalette.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text("Нет"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text("Да"),
              ),
            ],
          ),
        );
        if (useDraft != true) return;
      }

      _restoringDraft = true;
      final parsed = jsonDecode(s);
      if (parsed is Map) {
        _applyDocJson(Map<String, dynamic>.from(parsed));
        _dirty = true;
        if (mounted) setState(() {});
      }
    } catch (_) {
    } finally {
      _restoringDraft = false;
    }
  }

  // ==========================
  // Back guard
  // ==========================
  Future<void> _handleBack() async {
    if (saving) return;

    if (!_dirty) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    final action = await showDialog<_ExitAction>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: TgScreenPalette.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: const Text(
          "Схема не сохранена",
          style: TextStyle(
            fontFamily: AppTypography.fontFamily,
            color: TgScreenPalette.textPrimary,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: const Text(
          "Сохранить изменения перед выходом?",
          style: TextStyle(
            fontFamily: AppTypography.fontFamily,
            color: TgScreenPalette.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(_ExitAction.cancel),
            child: const Text("Остаться"),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(_ExitAction.exitWithoutSaving),
            style: TextButton.styleFrom(foregroundColor: TgScreenPalette.error),
            child: const Text("Выйти без сохранения"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(_ExitAction.saveAndExit),
            style: ElevatedButton.styleFrom(
              backgroundColor: TgScreenPalette.primaryGreen,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Сохранить и выйти"),
          ),
        ],
      ),
    );

    if (!mounted) return;

    switch (action) {
      case _ExitAction.saveAndExit:
        await _saveGraphic();
        if (mounted) Navigator.of(context).pop();
        break;

      case _ExitAction.exitWithoutSaving:
        await _clearDraft();
        if (mounted) Navigator.of(context).pop();
        break;

      case _ExitAction.cancel:
      default:
        break;
    }
  }

  // ==========================
  // Panel moved
  // ==========================
  void _onPanelMoved() {
    if (!mounted) return;
    final size = _panelController.size;
    final minSize = _isPhone ? 0.10 : 0.08;
    final maxSize = _isPhone ? 0.62 : 0.52;

    setState(() {
      _isPanelExpanded = (size - maxSize).abs() < 0.01;
      _isPanelCollapsed = (size - minSize).abs() < 0.01;
    });
  }

  void _initializeState() {
  graphicId = widget.graphicId;

  folderId = (widget.initialFolderId == null || widget.initialFolderId == 0)
      ? 0
      : widget.initialFolderId!;
  folderTitle = (widget.initialFolderTitle ?? "").trim().isNotEmpty
      ? widget.initialFolderTitle!.trim()
      : "Без папки";

  // По умолчанию Training Graphics открывается в том же 3D PRO ракурсе,
  // что и карта Tracker. Сохранённая схема ниже всё равно переопределит
  // эти значения своими параметрами камеры.
  state.set3DParams(
    enabled: true,
    rotationX: -0.34,
    rotationY: 0.0,
    rotationZ: 0.0,
    perspective: 0.00135,
    cameraZoom: 0.96,
    fieldSize: const Size(1050, 680),
  );

  if (stamps.isNotEmpty) {
    state.setActiveStamp(stamps.first);
  }

  if (_isMeaningfulDoc(widget.initialDocJson)) {
    _applyDocJson(widget.initialDocJson);
  } else {
    if (!widget.selectMode && graphicId != null && graphicId! > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadDocById(graphicId!);
      });
    }
  }

  _selected.addAll(widget.preselectedIds.where((x) => x > 0));

  if (widget.selectMode) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadList();
    });
  } else {
    final hasInitialDoc = _isMeaningfulDoc(widget.initialDocJson);
    final hasGraphicToLoad = graphicId != null && graphicId! > 0;

    if (!hasInitialDoc && !hasGraphicToLoad) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fitField();
      });
    }
  }

  WidgetsBinding.instance.addPostFrameCallback((_) {
    _restoreDraftIfAny();
  });
}


  // ==========================
  // 3D Pro: реальные игроки команды
  // ==========================
  Future<void> _loadTeamPlayersFor3D() async {
    final teamId = widget.resolvedTeamId;
    if (teamId <= 0) return;

    setState(() {
      _teamPlayersLoading = true;
      _teamPlayersError = null;
    });

    try {
      final resp = await http
          .post(
            Uri.parse('https://sportotekaapp.ru/api/get_players.php'),
            headers: const {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode({'team_id': teamId}),
          )
          .timeout(const Duration(seconds: 12));

      final raw = resp.body.trim();
      if (raw.isEmpty) throw 'Пустой ответ сервера';
      if (raw.startsWith('<') || raw.toLowerCase().contains('<html')) {
        throw 'Сервер вернул HTML вместо JSON';
      }

      final decoded = jsonDecode(raw);
      final list = _tgExtractPlayersList(decoded);
      final normalized = list.map((p) {
        final item = Map<String, dynamic>.from(p);
        item['team_id'] = widget.resolvedTeamId;
        item['team_name'] = widget.resolvedTeamName;
        return item;
      }).toList();

      if (!mounted) return;
      setState(() {
        _teamPlayersFor3D = normalized;
        _teamPlayersLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _teamPlayersLoading = false;
        _teamPlayersError = e.toString();
      });
    }
  }

  List<Map<String, dynamic>> _tgExtractPlayersList(dynamic data) {
    if (data is List) {
      return data.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    }

    if (data is Map) {
      for (final key in const ['players', 'data', 'items', 'members', 'athletes']) {
        final value = data[key];
        if (value is List) {
          return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        }
      }

      for (final value in data.values) {
        if (value is List) {
          final mapped = value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
          if (mapped.isNotEmpty) return mapped;
        }
      }
    }

    return <Map<String, dynamic>>[];
  }

  void _onStateChange() {
    if (!mounted) return;

    if (!_restoringDraft) _dirty = true;
    _scheduleDraftSave();

    setState(() {});
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    _playbackTimer?.cancel();
    _panelController.removeListener(_onPanelMoved);
    _panelController.dispose();
    state.removeListener(_onStateChange);
    state.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _buildPlaybackPayload() {
    return {
      'steps': List<String>.from(_playbackSteps),
      'currentStep': _currentPlaybackStep,
      'routeSteps': Map<String, int>.from(_playbackRouteStepById),
      'routeSubjects': Map<String, String>.from(_playbackRouteSubjectById),
    };
  }

  void _restorePlaybackPayload(dynamic raw) {
    try {
      final map = raw is Map<String, dynamic>
          ? raw
          : (raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{});
      final stepsRaw = map['steps'];
      final steps = <String>[];
      if (stepsRaw is List) {
        for (final item in stepsRaw) {
          final value = item.toString().trim();
          if (value.isNotEmpty) steps.add(value);
        }
      }
      _playbackSteps
        ..clear()
        ..addAll(steps.isEmpty ? const ['Шаг 1', 'Шаг 2', 'Шаг 3', 'Шаг 4'] : steps);

      _playbackRouteStepById
        ..clear()
        ..addAll(((map['routeSteps'] is Map) ? Map<String, dynamic>.from(map['routeSteps']) : const <String, dynamic>{})
            .map((k, v) => MapEntry(k, v is int ? v : int.tryParse(v.toString()) ?? 0)));
      _playbackRouteSubjectById
        ..clear()
        ..addAll(((map['routeSubjects'] is Map) ? Map<String, dynamic>.from(map['routeSubjects']) : const <String, dynamic>{})
            .map((k, v) => MapEntry(k, v.toString())));

      _currentPlaybackStep = ((map['currentStep'] is int)
                  ? map['currentStep'] as int
                  : int.tryParse('${map['currentStep'] ?? 0}') ?? 0)
              .clamp(0, _playbackSteps.length - 1)
          as int;
      _pendingPlaybackSubjectId = null;
      _playbackProgress = 0.0;
      _playbackRunning = false;
      _playbackTimer?.cancel();
    } catch (_) {}
  }

  void _togglePlayback() {
    if (_playbackRunning) {
      _stopPlayback();
    } else {
      _startPlayback();
    }
  }

  void _startPlayback() {
    final routes = _collectPlaybackRoutes();
    if (routes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Для анимации нужны маршруты: линия, кривая или волна.')),
      );
      return;
    }
    _playbackTimer?.cancel();
    setState(() {
      _playbackRunning = true;
    });
    _playbackTimer = Timer.periodic(_playbackTick, (_) {
      if (!mounted) return;
      final inc = _playbackTick.inMilliseconds / _playbackStepDuration.inMilliseconds;
      setState(() {
        _playbackProgress += inc;
        if (_playbackProgress >= 1.0) {
          _playbackProgress = 0.0;
          _currentPlaybackStep = (_currentPlaybackStep + 1) % _playbackSteps.length;
        }
      });
    });
  }

  void _stopPlayback() {
    _playbackTimer?.cancel();
    setState(() {
      _playbackRunning = false;
    });
  }

  void _selectPlaybackStep(int index) {
    if (index < 0 || index >= _playbackSteps.length) return;
    _stopPlayback();
    setState(() {
      _currentPlaybackStep = index;
      _playbackProgress = 0.0;
    });
  }

  void _addPlaybackStep() {
    setState(() {
      _playbackSteps.add('Шаг ${_playbackSteps.length + 1}');
      _currentPlaybackStep = _playbackSteps.length - 1;
      _playbackProgress = 0.0;
    });
  }

  void _duplicatePlaybackStep() {
    final safeIndex = _currentPlaybackStep.clamp(0, _playbackSteps.length - 1) as int;
    final source = _playbackSteps[safeIndex];
    setState(() {
      final insertIndex = _currentPlaybackStep + 1;
      _playbackSteps.insert(insertIndex, '$source копия');
      final updated = <String, int>{};
      for (final entry in _playbackRouteStepById.entries) {
        final v = entry.value;
        updated[entry.key] = v >= insertIndex ? v + 1 : v;
      }
      final clones = _playbackRouteStepById.entries.where((e) => e.value == safeIndex).map((e) => e.key).toList();
      _playbackRouteStepById
        ..clear()
        ..addAll(updated);
      for (final routeId in clones) {
        _playbackRouteStepById[routeId] = insertIndex;
      }
      _currentPlaybackStep = insertIndex;
      _playbackProgress = 0.0;
    });
  }

  void _removePlaybackStep() {
    if (_playbackSteps.length <= 1) return;
    setState(() {
      final removedIndex = _currentPlaybackStep;
      _playbackSteps.removeAt(removedIndex);
      final updated = <String, int>{};
      for (final entry in _playbackRouteStepById.entries) {
        final v = entry.value;
        if (v == removedIndex) {
          continue;
        } else if (v > removedIndex) {
          updated[entry.key] = v - 1;
        } else {
          updated[entry.key] = v;
        }
      }
      _playbackRouteStepById
        ..clear()
        ..addAll(updated);
      _currentPlaybackStep = _currentPlaybackStep.clamp(0, _playbackSteps.length - 1) as int;
      _playbackProgress = 0.0;
    });
  }

  Future<void> _renamePlaybackStep() async {
    final ctrl = TextEditingController(text: _playbackSteps[_currentPlaybackStep]);
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Название шага'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Например: Розыгрыш, Передача, Завершение'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()), child: const Text('Сохранить')),
        ],
      ),
    );
    if (value == null) return;
    final clean = value.trim();
    if (clean.isEmpty) return;
    setState(() {
      _playbackSteps[_currentPlaybackStep] = clean;
    });
  }

  bool _isPlaybackRouteElement(TgElement? e) => e is TgLine || e is TgCurve || e is TgWavy;

  TgStamp? _findStampById(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final e in state.elements) {
      if (e is TgStamp && e.id == id) return e;
    }
    return null;
  }

  String _playbackSubjectLabel() {
    final stamp = _findStampById(_pendingPlaybackSubjectId);
    if (stamp == null) return 'не выбран';
    if (_isPlaybackBallStamp(stamp)) return 'мяч';
    if (stamp.asset.startsWith('sportoteka://player-avatar')) {
      final uri = Uri.tryParse(stamp.asset);
      final name = (uri?.queryParameters['name'] ?? stamp.name ?? 'Игрок').trim();
      final number = (uri?.queryParameters['number'] ?? '').trim();
      return number.isNotEmpty ? '$name #$number' : name;
    }
    return (stamp.name?.trim().isNotEmpty == true) ? stamp.name!.trim() : 'объект';
  }

  void _capturePlaybackSubject() {
    final selected = state.selected;
    if (selected is! TgStamp) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала выберите игрока или мяч на поле.')),
      );
      return;
    }
    setState(() {
      _pendingPlaybackSubjectId = selected.id;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Для анимации выбран: ${_playbackSubjectLabel()}')),
    );
  }

  void _bindSelectedRouteToCurrentStep() {
    final selected = state.selected;
    if (!_isPlaybackRouteElement(selected)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите линию, кривую или волну для привязки шага.')),
      );
      return;
    }
    if (_pendingPlaybackSubjectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сначала выберите игрока или мяч и нажмите «Взять объект».')),
      );
      return;
    }
    setState(() {
      _playbackRouteStepById[selected!.id] = _currentPlaybackStep;
      _playbackRouteSubjectById[selected.id] = _pendingPlaybackSubjectId!;
      _playbackProgress = 0.0;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Маршрут привязан к ${_playbackStepLabel(_currentPlaybackStep).toLowerCase()} для ${_playbackSubjectLabel()}')),
    );
  }

  void _clearSelectedRouteBinding() {
    final selected = state.selected;
    if (!_isPlaybackRouteElement(selected)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите маршрут, чтобы очистить привязку.')),
      );
      return;
    }
    setState(() {
      _playbackRouteStepById.remove(selected!.id);
      _playbackRouteSubjectById.remove(selected.id);
      _playbackProgress = 0.0;
    });
  }

  void _selectPlaybackBinding(String routeId) {
    if (routeId.isEmpty) return;
    state.selectById(routeId);
    _openPropertiesPanel();
  }

  void _deletePlaybackBinding(String routeId) {
    if (routeId.isEmpty) return;
    setState(() {
      _playbackRouteStepById.remove(routeId);
      _playbackRouteSubjectById.remove(routeId);
      _playbackProgress = 0.0;
    });
  }

  List<_TgStepBindingInfo> _playbackBindingsForCurrentStep() {
    final routes = _collectPlaybackRoutes().where((e) => e.stepIndex == _currentPlaybackStep).toList();
    return routes.map((route) {
      return _TgStepBindingInfo(
        routeId: route.routeId,
        routeTitle: _routeTitleById(route.routeId),
        subjectTitle: route.binding.label,
        isManual: route.manual,
      );
    }).toList();
  }

  String _routeTitleById(String id) {
    final index = state.elements.indexWhere((e) => e.id == id);
    final e = index >= 0 ? state.elements[index] : null;
    final prefix = index >= 0 ? '#${index + 1}' : '#';
    final custom = (e?.name ?? '').trim();
    if (custom.isNotEmpty) return custom;
    if (e is TgLine) return '$prefix Линия / передача';
    if (e is TgCurve) return '$prefix Кривая';
    if (e is TgWavy) return '$prefix Волна / дриблинг';
    return '$prefix Маршрут';
  }

  List<_TgPlaybackRoute> _collectPlaybackRoutes() {
    final raw = state.elements.where((e) {
      if (e.hidden) return false;
      if (e is TgLine || e is TgCurve || e is TgWavy) return true;
      return false;
    }).toList()
      ..sort((a, b) => (a.createdAt ?? 0).compareTo(b.createdAt ?? 0));

    final stamps = state.elements.whereType<TgStamp>().where((e) => !e.hidden).toList();
    final playerStamps = stamps.where(_isPlaybackPlayerStamp).toList();
    final ballStamps = stamps.where(_isPlaybackBallStamp).toList();

    if (raw.isEmpty) return const <_TgPlaybackRoute>[];
    final totalSteps = _playbackSteps.isEmpty ? 1 : _playbackSteps.length;
    final routes = <_TgPlaybackRoute>[];
    for (int i = 0; i < raw.length; i++) {
      final e = raw[i];
      final startPoint = _routeStartPoint(e);
      final endPoint = _routeEndPoint(e);
      final stepIndex = _playbackRouteStepById[e.id] ?? (((i * totalSteps ~/ raw.length).clamp(0, totalSteps - 1)) as int);
      final manualSubject = _findStampById(_playbackRouteSubjectById[e.id]);
      final nearestPlayer = _nearestStamp(playerStamps, startPoint);
      final nearestBall = _nearestStamp(ballStamps, startPoint);
      final playerDistance = nearestPlayer == null ? double.infinity : (nearestPlayer.pos - startPoint).distance;
      final ballDistance = nearestBall == null ? double.infinity : (nearestBall.pos - startPoint).distance;
      final preferBall = manualSubject != null
          ? _isPlaybackBallStamp(manualSubject)
          : (_looksLikeBallRoute(e) || ballDistance < 54 || ballDistance + 16 < playerDistance);
      final binding = manualSubject != null
          ? _TgPlaybackBinding.fromStamp(manualSubject, fallbackColor: _routeColor(e), forceBall: _isPlaybackBallStamp(manualSubject))
          : preferBall && nearestBall != null
              ? _TgPlaybackBinding.fromStamp(nearestBall, fallbackColor: const Color(0xFF0F172A), forceBall: true)
              : nearestPlayer != null
                  ? _TgPlaybackBinding.fromStamp(nearestPlayer, fallbackColor: _routeColor(e), forceBall: false)
                  : _TgPlaybackBinding.generic(label: 'Маршрут', color: _routeColor(e));

      final manual = _playbackRouteStepById.containsKey(e.id) || _playbackRouteSubjectById.containsKey(e.id);
      if (e is TgLine) {
        routes.add(_TgPlaybackRoute(
          routeId: e.id,
          stepIndex: stepIndex,
          color: e.color,
          binding: binding,
          startPoint: startPoint,
          endPoint: endPoint,
          manual: manual,
          pointAt: (t) => Offset.lerp(e.a, e.b, t) ?? e.a,
        ));
      } else if (e is TgCurve) {
        routes.add(_TgPlaybackRoute(
          routeId: e.id,
          stepIndex: stepIndex,
          color: e.color,
          binding: binding,
          startPoint: startPoint,
          endPoint: endPoint,
          manual: manual,
          pointAt: (t) => e.pointAt(t),
        ));
      } else if (e is TgWavy) {
        routes.add(_TgPlaybackRoute(
          routeId: e.id,
          stepIndex: stepIndex,
          color: e.color,
          binding: binding,
          startPoint: startPoint,
          endPoint: endPoint,
          manual: manual,
          pointAt: (t) => Offset.lerp(e.start, e.endPoint, Curves.easeInOut.transform(t)) ?? e.start,
        ));
      }
    }
    return routes;
  }

  bool _isPlaybackBallStamp(TgStamp stamp) {
    final a = stamp.asset.toLowerCase();
    return a.startsWith('sportoteka://ball') || a.contains('/ball') || a.contains('myach') || a.contains('мяч');
  }

  bool _isPlaybackPlayerStamp(TgStamp stamp) {
    final a = stamp.asset.toLowerCase();
    return a.startsWith('sportoteka://player-avatar') ||
        a.contains('/player_') ||
        a.contains('/run_svg/') ||
        a.contains('/pass_svg/') ||
        a.contains('/vrat_svg/') ||
        a.contains('/coach/');
  }

  TgStamp? _nearestStamp(List<TgStamp> stamps, Offset point) {
    TgStamp? result;
    double best = double.infinity;
    for (final stamp in stamps) {
      final d = (stamp.pos - point).distance;
      if (d < best) {
        best = d;
        result = stamp;
      }
    }
    return result;
  }

  bool _looksLikeBallRoute(TgElement e) {
    final raw = '${e.name ?? ''} ${e.layer}'.toLowerCase();
    return raw.contains('pass') ||
        raw.contains('ball') ||
        raw.contains('мяч') ||
        raw.contains('передач') ||
        raw.contains('удар') ||
        raw.contains('подач') ||
        raw.contains('corner') ||
        raw.contains('free');
  }

  Offset _routeStartPoint(TgElement e) {
    if (e is TgLine) return e.a;
    if (e is TgCurve && e.points.isNotEmpty) return e.points.first;
    if (e is TgWavy) return e.start;
    return Offset.zero;
  }

  Offset _routeEndPoint(TgElement e) {
    if (e is TgLine) return e.b;
    if (e is TgCurve && e.points.isNotEmpty) return e.points.last;
    if (e is TgWavy) return e.endPoint;
    return Offset.zero;
  }

  Color _routeColor(TgElement e) {
    if (e is TgLine) return e.color;
    if (e is TgCurve) return e.color;
    if (e is TgWavy) return e.color;
    return TgScreenPalette.primaryGreen;
  }

  String _playbackStepLabel(int index) {
    if (index < 0 || index >= _playbackSteps.length) return '';
    return _playbackSteps[index];
  }

  // ==========================
  // Utils
  // ==========================
  bool get _isPhone {
    final s = MediaQuery.of(context).size;
    // На планшетах в landscape логическая ширина часто 700–900 px.
    // Старый порог <900 включал телефонный bottom-sheet и съедал поле.
    return s.width < 700;
  }

  int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is num) return v.toInt();
    return int.tryParse((v ?? "").toString()) ?? 0;
  }

  String _asStr(dynamic v) {
    final s = '${v ?? ''}'.trim();
    return s == 'null' ? '' : s;
  }

  bool _isMeaningfulDoc(dynamic doc) {
    if (doc == null) return false;
    if (doc is String) {
      final s = doc.trim();
      if (s.isEmpty) return false;
      if (s.toLowerCase() == "null") return false;
      return true;
    }
    if (doc is Map || doc is List) return true;
    return false;
  }

  void _applyDocJson(dynamic doc) {
  try {
    _restoringDraft = true;

    final parsed = (doc is String) ? jsonDecode(doc) : doc;
    Map<String, dynamic>? parsedMap;
    if (parsed is Map<String, dynamic>) {
      parsedMap = parsed;
      state.loadFromJson(parsed);
    } else if (parsed is Map) {
      parsedMap = Map<String, dynamic>.from(parsed);
      state.loadFromJson(parsedMap);
    }

    _restorePlaybackPayload(parsedMap?['playback']);
    _dirty = false;

    // ✅ ВАЖНО:
    // если схема загружена из JSON, значит камера/viewport уже есть,
    // и повторный auto-fit делать не нужно
    _didLayoutFit = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {});
    });
  } catch (_) {
  } finally {
    _restoringDraft = false;
  }
}
  // ==========================
  // Panel fractions
  // ==========================
  double get _panelMinFrac => _isPhone ? 0.10 : 0.08;
  double get _panelInitialFrac => _isPhone ? 0.26 : 0.20;
  double get _panelMaxFrac => _isPhone ? 0.62 : 0.52;

  // ==========================
  // Panel control methods
  // ==========================
  void _expandPanel() {
    _panelController.animateTo(
      _panelMaxFrac,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _collapsePanel() {
    _panelController.animateTo(
      _panelMinFrac,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

 void _togglePanel() {
  setState(() {
    _isPanelExpanded = !_isPanelExpanded;
    _isPanelCollapsed = !_isPanelExpanded;
    if (_isPanelExpanded) _animationPanelOpen = false;
  });

  if (_isPanelExpanded) {
    _panelController.animateTo(
      _panelMaxFrac,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) _fitField();
  });
}

  void _openLegacyPanel(TgPanel panel) {
    setState(() {
      _legacyPanelInitial = panel;
      _isPanelExpanded = true;
      _isPanelCollapsed = false;
      _animationPanelOpen = false;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        _panelController.animateTo(
          _panelMaxFrac,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      } catch (_) {}
      _fitField();
    });
  }

  void _openAnimationPanel() {
    if (_animationPanelOpen) return;
    setState(() {
      _animationPanelOpen = true;
      _isPanelExpanded = false;
      _isPanelCollapsed = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fitField();
    });
  }

  void _closeAnimationPanel() {
    if (!_animationPanelOpen) return;
    setState(() => _animationPanelOpen = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fitField();
    });
  }

  void _toggleAnimationPanel() {
    if (_animationPanelOpen) {
      _closeAnimationPanel();
    } else {
      _openAnimationPanel();
    }
  }


  void _openPropertiesPanel() {
    if (state.selected == null) return;
    _openLegacyPanel(TgPanel.editor);
  }
  void _openTacticalPadSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: TgScreenPalette.borderLight),
              boxShadow: TgScreenPalette.windowShadow,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: TgScreenPalette.lightGreen,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.auto_awesome_motion_rounded, color: TgScreenPalette.primaryGreen),
                    ),
                    const SizedBox(width: 4),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('TacticalPad функции', style: TextStyle(fontFamily: AppTypography.fontFamily, color: TgScreenPalette.textPrimary, fontSize: AppTypography.screenTitleSize, fontWeight: FontWeight.w900)),
                          SizedBox(height: 2),
                          Text('Пресеты добавляются на поле и попадают в слои', style: TextStyle(fontFamily: AppTypography.fontFamily, color: TgScreenPalette.textMuted, fontSize: AppTypography.badgeSize, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    IconButton(onPressed: () => Navigator.of(ctx).pop(), icon: const Icon(Icons.close_rounded)),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _tacticalPresetButton(ctx, '4-3-3', 'Расстановка', Icons.grid_view_rounded, '433'),
                    _tacticalPresetButton(ctx, '4-4-2', 'Расстановка', Icons.grid_view_rounded, '442'),
                    _tacticalPresetButton(ctx, '3-5-2', 'Расстановка', Icons.grid_view_rounded, '352'),
                    _tacticalPresetButton(ctx, '4-2-3-1', 'Расстановка', Icons.grid_view_rounded, '4231'),
                    _tacticalPresetButton(ctx, '5-3-2', 'Расстановка', Icons.grid_view_rounded, '532'),
                    _tacticalPresetButton(ctx, 'Билдап', 'Выход из обороны', Icons.account_tree_rounded, 'build_up'),
                    _tacticalPresetButton(ctx, 'От ворот', 'Розыгрыш GK', Icons.sports_soccer_rounded, 'goal_kick'),
                    _tacticalPresetButton(ctx, 'Контратака', 'Быстрый выход', Icons.flash_on_rounded, 'counter'),
                    _tacticalPresetButton(ctx, 'Прессинг', 'Зона давления', Icons.radar_rounded, 'pressing'),
                    _tacticalPresetButton(ctx, 'Низкий блок', '5-4-1', Icons.shield_outlined, 'low_block'),
                    _tacticalPresetButton(ctx, 'Рондо', '5v2', Icons.radio_button_checked_rounded, 'rondo'),
                    _tacticalPresetButton(ctx, 'Скорость', 'Станции', Icons.speed_rounded, 'speed'),
                    _tacticalPresetButton(ctx, 'Офсайд', 'Линия защиты', Icons.align_vertical_center_rounded, 'offside'),
                    _tacticalPresetButton(ctx, 'Забегание', 'Overlap', Icons.trending_up_rounded, 'overlap'),
                    _tacticalPresetButton(ctx, '3-й игрок', 'Комбинация', Icons.hub_rounded, 'third_man'),
                    _tacticalPresetButton(ctx, 'Угловой', 'Стандарт', Icons.flag_rounded, 'corner'),
                    _tacticalPresetButton(ctx, 'Штрафной', 'Стандарт', Icons.sports_rounded, 'free_kick'),
                    _tacticalPresetButton(ctx, 'Атака 1–4', 'Шаги', Icons.play_circle_outline_rounded, 'animation_attack'),
                    _tacticalPresetButton(ctx, 'Полный пакет', 'всё сразу', Icons.auto_awesome_rounded, 'full_pack'),
                    _tacticalPresetButton(ctx, 'Очистить', 'Tactical слой', Icons.cleaning_services_rounded, 'clear_tactical'),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Каждый пресет создаёт собственную tactical-группу. Откройте «Слои» для выбора/скрытия/блокировки группы или «Свойства» для редактирования объекта.',
                  style: TextStyle(fontFamily: AppTypography.fontFamily, color: TgScreenPalette.textMuted, fontSize: AppTypography.secondarySize, height: 1.35, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _tacticalPresetButton(BuildContext sheetContext, String title, String subtitle, IconData icon, String key) {
    return SizedBox(
      width: 150,
      child: Material(
        color: TgScreenPalette.surfaceLight,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            Navigator.of(sheetContext).pop();
            state.applyTacticalPreset(key);
            _openLegacyPanel(TgPanel.layers);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _fitField();
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Добавлен тактический пресет: $title')),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: TgScreenPalette.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: TgScreenPalette.primaryGreen, size: 22),
                const SizedBox(height: 8),
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: AppTypography.fontFamily, color: TgScreenPalette.textPrimary, fontSize: AppTypography.bodySize, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: AppTypography.fontFamily, color: TgScreenPalette.textMuted, fontSize: AppTypography.badgeSize, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ),
    );
  }
  // ==========================
  // Fit field
  // ==========================
  void _fitField() {
    if (!mounted) return;

    // TacticalPad layout: поле вписываем не в весь экран, а именно в реальный
    // viewport канваса. Так оно не залезает под верхнюю/нижнюю панели и не
    // обрезается плавающими контролами.
    final canvasRb = _canvasKey.currentContext?.findRenderObject();
    if (canvasRb is RenderBox && canvasRb.hasSize && canvasRb.size.width > 0 && canvasRb.size.height > 0) {
      _canvasKey.currentState?.fitFieldToViewport(canvasRb.size);
      return;
    }

    final rb = _rightPaneKey.currentContext?.findRenderObject();
    final full = (rb is RenderBox) ? rb.size : MediaQuery.of(context).size;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final viewportH = (full.height - _topBarH - safeBottom - (120.0)).clamp(1.0, 200000.0);
    final viewportW = (full.width - 32.0).clamp(1.0, 200000.0);

    _canvasKey.currentState?.fitFieldToViewport(Size(viewportW, viewportH));
  }

  // ==========================
  // Load doc by id
  // ==========================
  Future<void> _loadDocById(int gid) async {
    if (_docLoading) return;

    setState(() {
      _docLoading = true;
      _docError = null;
    });

    try {
      final resp = await http.post(
        Uri.parse("https://sportotekaapp.ru/api/get_training_graphic.php"),
        headers: {"Content-Type": "application/json; charset=utf-8"},
        body: jsonEncode({
          "club_id": widget.resolvedClubId,
          "clubId": widget.resolvedClubId,
          "graphic_id": gid,
          "id": gid,
        }),
      );

      final raw = resp.body.trim();
      if (raw.isEmpty) throw "Empty response";

      if (raw.startsWith("<") ||
          raw.toLowerCase().contains("<br") ||
          raw.toLowerCase().contains("<html")) {
        throw "Server returned HTML instead of JSON";
      }

      final data = jsonDecode(raw);
      if (data is! Map) throw "Bad JSON: not a map";

      if (data["success"] != true) {
        throw (data["message"] ?? "Не удалось загрузить схему").toString();
      }

      dynamic item = data["item"] ?? data["data"];
      if (item == null && data["items"] is List && (data["items"] as List).isNotEmpty) {
        item = (data["items"] as List).first;
      }
      if (item is! Map) throw "No item in response";

      final dynamic doc = item["doc_json"] ??
          item["docJson"] ??
          item["json"] ??
          item["data"] ??
          item["document"] ??
          item["payload"];

      if (!_isMeaningfulDoc(doc)) {
        throw "doc_json пустой (сервер не вернул данные схемы)";
      }

      _applyDocJson(doc);

      _animationController.reset();
      _animationController.forward();
    } catch (e) {
      if (mounted) setState(() => _docError = e.toString());
    } finally {
      if (mounted) setState(() => _docLoading = false);
    }
  }

  // ==========================
  // PNG capture
  // ==========================
  Future<Uint8List?> _capturePng() async {
    return _captureBoundaryPng(_repaintKey, pixelRatio: 3.0);
  }

  Future<Uint8List?> _captureBoundaryPng(GlobalKey key, {double pixelRatio = 3.0}) async {
    try {
      await WidgetsBinding.instance.endOfFrame;
      final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final ui.Image image = await boundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) return null;
      return byteData.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List?> _captureCleanExportPng({
    int? step,
    double? progress,
    bool includeAnimation = true,
  }) async {
    final oldClean = _exportCleanMode;
    final oldStep = _currentPlaybackStep;
    final oldProgress = _playbackProgress;
    final oldRunning = _playbackRunning;
    final oldSelected = Set<String>.from(state.selectedIds);

    setState(() {
      _exportCleanMode = true;
      if (step != null) _currentPlaybackStep = step.clamp(0, _playbackSteps.length - 1) as int;
      if (progress != null) _playbackProgress = progress.clamp(0.0, 1.0).toDouble();
      _playbackRunning = includeAnimation;
    });
    state.clearSelection();

    final png = await _captureBoundaryPng(_exportRepaintKey, pixelRatio: 3.0);

    if (oldSelected.isEmpty) {
      state.clearSelection();
    } else {
      state.selectMultiple(oldSelected);
    }
    if (mounted) {
      setState(() {
        _exportCleanMode = oldClean;
        _currentPlaybackStep = oldStep;
        _playbackProgress = oldProgress;
        _playbackRunning = oldRunning;
      });
    }
    return png;
  }

  String _exportFolderName() {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return 'sportoteka_training_${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }

  Future<void> _exportCurrentPng() async {
    final folder = _exportFolderName();
    final png = await _captureCleanExportPng(step: _currentPlaybackStep, progress: _playbackProgress, includeAnimation: true);
    if (!mounted) return;
    if (png == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Не удалось собрать PNG')));
      return;
    }
    final saved = await saveTgExportFile('current_frame.png', png, mimeType: 'image/png', folderName: folder);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PNG экспортирован: $saved')));
  }

  Future<void> _exportStepPngs() async {
    final folder = _exportFolderName();
    var exported = 0;
    for (int i = 0; i < _playbackSteps.length; i++) {
      final png = await _captureCleanExportPng(step: i, progress: 1.0, includeAnimation: true);
      if (png == null) continue;
      await saveTgExportFile('step_${(i + 1).toString().padLeft(2, '0')}.png', png, mimeType: 'image/png', folderName: '$folder/steps');
      exported++;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Экспортировано шагов: $exported')));
  }

  Future<void> _exportAnimationFrames() async {
    final folder = _exportFolderName();
    const framesPerStep = 8;
    var exported = 0;
    for (int step = 0; step < _playbackSteps.length; step++) {
      for (int frame = 0; frame < framesPerStep; frame++) {
        final t = framesPerStep <= 1 ? 1.0 : frame / (framesPerStep - 1);
        final png = await _captureCleanExportPng(step: step, progress: t, includeAnimation: true);
        if (png == null) continue;
        final frameNumber = (exported + 1).toString().padLeft(3, '0');
        await saveTgExportFile('frame_$frameNumber.png', png, mimeType: 'image/png', folderName: '$folder/animation_frames');
        exported++;
      }
    }
    final docJson = state.toJson();
    docJson['playback'] = _buildPlaybackPayload();
    final manifest = jsonEncode({
      'title': 'Sportoteka Training Animation Export',
      'team': widget.resolvedTeamName,
      'steps': _playbackSteps,
      'frames_per_step': framesPerStep,
      'frames_count': exported,
      'scheme': docJson,
    });
    await saveTgExportFile('scheme.json', Uint8List.fromList(utf8.encode(manifest)), mimeType: 'application/json', folderName: folder);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Экспортировано кадров: $exported')));
  }

  Future<void> _showProExportCenter() async {
    final png = await _capturePng();
    if (!mounted) return;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.all(14),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: TgScreenPalette.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: TgScreenPalette.border),
              boxShadow: TgScreenPalette.windowShadow,
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
                      decoration: BoxDecoration(
                        color: TgScreenPalette.lightGreen,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(Icons.file_download_rounded, color: TgScreenPalette.primaryGreen, size: 19),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Экспорт FIFA / TV графики', style: TextStyle(fontFamily: AppTypography.fontFamily, color: TgScreenPalette.textPrimary, fontSize: AppTypography.sectionTitleSize, fontWeight: FontWeight.w900)),
                          SizedBox(height: 2),
                          Text('PNG собирается из текущего кадра. Для Unity/3D нужен экспорт сцены в JSON/GLB pipeline.', style: TextStyle(fontFamily: AppTypography.fontFamily, color: TgScreenPalette.textMuted, fontSize: AppTypography.secondarySize, height: 1.25, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _ExportOptionTile(
                  icon: Icons.image_rounded,
                  title: 'PNG текущего кадра',
                  subtitle: png == null
                      ? 'Не удалось собрать кадр — попробуйте ещё раз после загрузки поля'
                      : 'Чистый экспорт: поле, схема и текущий кадр анимации без панелей.',
                  active: png != null,
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await _exportCurrentPng();
                  },
                ),
                const SizedBox(height: 8),
                _ExportOptionTile(
                  icon: Icons.filter_1_rounded,
                  title: 'PNG по шагам',
                  subtitle: 'Создаёт отдельные файлы step_01.png, step_02.png и так далее.',
                  active: true,
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await _exportStepPngs();
                  },
                ),
                const SizedBox(height: 8),
                _ExportOptionTile(
                  icon: Icons.movie_creation_outlined,
                  title: 'Серия кадров анимации',
                  subtitle: 'Создаёт animation_frames/frame_001.png... и scheme.json для будущего GIF/видео.',
                  active: true,
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await _exportAnimationFrames();
                  },
                ),
                const SizedBox(height: 8),
                const _ExportOptionTile(
                  icon: Icons.picture_as_pdf_rounded,
                  title: 'PDF / GIF / видео',
                  subtitle: 'Следующий этап: сборка PDF и GIF/MP4 из экспортированных кадров.',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==========================
  // Training templates
  // ==========================
  Map<String, dynamic> _currentDocJsonWithPlayback() {
    final docJson = state.toJson();
    docJson['playback'] = _buildPlaybackPayload();
    docJson['template_meta'] = {
      'club_id': widget.resolvedClubId,
      'club_name': widget.resolvedClubName,
      'team_id': widget.resolvedTeamId,
      'team_name': widget.resolvedTeamName,
      'updated_at': DateTime.now().toIso8601String(),
    };
    return docJson;
  }

  Future<void> _loadUserTrainingTemplates() async {
    if (_templatesLoaded) return;
    try {
      final raw = await PrefUtils.getStringValue(_templatesStorageKey);
      final parsed = raw == null || raw.trim().isEmpty ? null : jsonDecode(raw);
      final list = <_TrainingTemplate>[];
      if (parsed is List) {
        for (final item in parsed) {
          if (item is Map) {
            final template = _TrainingTemplate.fromJson(Map<String, dynamic>.from(item));
            if (template != null) list.add(template);
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _userTrainingTemplates = list;
        _templatesLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _templatesLoaded = true);
    }
  }

  Future<void> _persistUserTrainingTemplates() async {
    final raw = jsonEncode(_userTrainingTemplates.map((e) => e.toJson()).toList());
    await PrefUtils.setStringValue(_templatesStorageKey, raw);
  }

  List<_TrainingTemplate> _filterTrainingTemplates(String category, String query) {
    final q = query.trim().toLowerCase();
    return _allTrainingTemplates.where((template) {
      final catOk = category == 'Все' || template.category == category;
      if (!catOk) return false;
      if (q.isEmpty) return true;
      final haystack = '${template.title} ${template.category} ${template.description}'.toLowerCase();
      return haystack.contains(q);
    }).toList();
  }

  Future<void> _showSaveTemplateDialog() async {
    final titleCtrl = TextEditingController(text: _suggestTemplateTitle());
    final descCtrl = TextEditingController(text: 'Пользовательский шаблон тренировки');
    var category = 'Атака';

    final result = await _showWorkflowPanel<_TemplateDraft>(
      title: 'Сохранить шаблон',
      subtitle: 'Шаблон попадёт в библиотеку тренировок и будет доступен в плане',
      icon: Icons.bookmark_add_outlined,
      maxWidth: 520,
      builder: (panelContext) => StatefulBuilder(
        builder: (panelContext, setPanelState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(controller: titleCtrl, decoration: _workflowInputDecoration('Название', hint: 'Например: Рондо 5v2', icon: Icons.title_rounded)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: category,
              decoration: _workflowInputDecoration('Категория', icon: Icons.category_outlined),
              items: _trainingTemplateCategories.where((e) => e != 'Все').map((e) => DropdownMenuItem<String>(value: e, child: Text(e))).toList(),
              onChanged: (v) => setPanelState(() => category = v ?? category),
            ),
            const SizedBox(height: 12),
            TextField(controller: descCtrl, minLines: 2, maxLines: 4, decoration: _workflowInputDecoration('Описание', hint: 'Цель упражнения, формат, подсказка тренеру', icon: Icons.notes_rounded)),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.of(panelContext).pop(), child: const Text('Отмена'))),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    final title = titleCtrl.text.trim();
                    if (title.isEmpty) return;
                    Navigator.of(panelContext).pop(_TemplateDraft(
                      title: title,
                      category: category,
                      description: descCtrl.text.trim().isEmpty ? 'Пользовательский шаблон' : descCtrl.text.trim(),
                    ));
                  },
                  icon: const Icon(Icons.save_outlined, size: 17),
                  label: const Text('Сохранить'),
                ),
              ),
            ]),
          ],
        ),
      ),
    );

    titleCtrl.dispose();
    descCtrl.dispose();
    if (result == null) return;

    final template = _TrainingTemplate(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      title: result.title,
      category: result.category,
      description: result.description,
      builtin: false,
      docJson: _currentDocJsonWithPlayback(),
      createdAt: DateTime.now(),
    );

    setState(() => _userTrainingTemplates.insert(0, template));
    await _persistUserTrainingTemplates();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Шаблон сохранён: ${template.title}')),
    );
  }

  String _suggestTemplateTitle() {
    final layers = state.layerNames.where((e) => e.startsWith('tactical_')).toList();
    if (layers.isNotEmpty) {
      return layers.first
          .replaceAll('tactical_', '')
          .replaceAll('_', ' ')
          .trim()
          .split(' ')
          .map((e) => e.isEmpty ? e : '${e[0].toUpperCase()}${e.substring(1)}')
          .join(' ');
    }
    return 'Новый шаблон';
  }

  Future<void> _openTrainingTemplate(_TrainingTemplate template) async {
    Navigator.of(context).maybePop();
    _stopPlayback();

    if (template.docJson != null) {
      _applyDocJson(template.docJson);
      _dirty = true;
    } else if ((template.presetKey ?? '').isNotEmpty) {
      _restoringDraft = true;
      try {
        state.applyTacticalPreset(template.presetKey!, replaceExisting: true);
        _playbackSteps
          ..clear()
          ..addAll(const ['Шаг 1', 'Шаг 2', 'Шаг 3', 'Шаг 4']);
        _playbackRouteStepById.clear();
        _playbackRouteSubjectById.clear();
        _pendingPlaybackSubjectId = null;
        _currentPlaybackStep = 0;
        _playbackProgress = 0.0;
        _dirty = true;
      } finally {
        _restoringDraft = false;
      }
    }

    _scheduleDraftSave();
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fitField();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Открыт шаблон: ${template.title}')),
    );
  }

  Future<void> _duplicateTrainingTemplate(_TrainingTemplate template) async {
    final copy = template.copyAsUser(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      title: '${template.title} копия',
    );
    setState(() => _userTrainingTemplates.insert(0, copy));
    await _persistUserTrainingTemplates();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Шаблон дублирован: ${copy.title}')),
    );
  }

  Future<void> _deleteTrainingTemplate(_TrainingTemplate template) async {
    if (template.builtin) return;
    setState(() => _userTrainingTemplates.removeWhere((e) => e.id == template.id));
    await _persistUserTrainingTemplates();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Шаблон удалён: ${template.title}')),
    );
  }

  Future<void> _exportTrainingTemplate(_TrainingTemplate template) async {
    final payload = jsonEncode({
      'type': 'sportoteka_training_template',
      'template': template.toJson(),
      'exported_at': DateTime.now().toIso8601String(),
    });
    final fileName = '${template.safeFileName}.json';
    final saved = await saveTgExportFile(
      fileName,
      Uint8List.fromList(utf8.encode(payload)),
      mimeType: 'application/json',
      folderName: 'sportoteka_templates',
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Шаблон экспортирован: $saved')),
    );
  }

  Future<void> _showTrainingTemplatesCenter() async {
    await _loadUserTrainingTemplates();
    if (!mounted) return;

    final searchCtrl = TextEditingController();
    var category = 'Все';
    var query = '';

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final templates = _filterTrainingTemplates(category, query);
            return SafeArea(
              child: Container(
                margin: const EdgeInsets.all(10),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * .82,
                  maxWidth: 780,
                ),
                decoration: BoxDecoration(
                  color: TgScreenPalette.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: TgScreenPalette.border),
                  boxShadow: TgScreenPalette.windowShadow,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
                      child: Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: TgScreenPalette.lightGreen,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.bookmarks_rounded, color: TgScreenPalette.primaryGreen, size: 17),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Шаблоны тренировок',
                                  style: TextStyle(
                                    fontFamily: AppTypography.fontFamily,
                                    color: TgScreenPalette.textPrimary,
                                    fontWeight: FontWeight.w900,
                                    fontSize: AppTypography.sectionTitleSize,
                                  ),
                                ),
                                SizedBox(height: 1),
                                Text(
                                  'Быстро открыть рондо, прессинг, билдап или сохранить свою схему.',
                                  style: TextStyle(
                                    fontFamily: AppTypography.fontFamily,
                                    color: TgScreenPalette.textMuted,
                                    fontWeight: FontWeight.w600,
                                    fontSize: AppTypography.captionSize,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _HeaderActionButton(
                            icon: Icons.add_rounded,
                            label: 'Сохранить',
                            onTap: () async {
                              await _showSaveTemplateDialog();
                              setSheetState(() {});
                            },
                            foreground: Colors.white,
                            background: TgScreenPalette.primaryGreen,
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            icon: const Icon(Icons.close_rounded, size: 18),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                      child: TextField(
                        controller: searchCtrl,
                        onChanged: (v) => setSheetState(() => query = v),
                        style: const TextStyle(fontFamily: AppTypography.fontFamily, fontSize: AppTypography.secondarySize, fontWeight: FontWeight.w700),
                        decoration: InputDecoration(
                          isDense: true,
                          prefixIcon: const Icon(Icons.search_rounded, size: 18),
                          hintText: 'Поиск шаблона',
                          filled: true,
                          fillColor: TgScreenPalette.surfaceLight,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 34,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        scrollDirection: Axis.horizontal,
                        itemCount: _trainingTemplateCategories.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 6),
                        itemBuilder: (ctx, i) {
                          final cat = _trainingTemplateCategories[i];
                          final active = cat == category;
                          return ChoiceChip(
                            selected: active,
                            label: Text(cat),
                            labelStyle: TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              color: active ? Colors.white : TgScreenPalette.textSecondary,
                              fontWeight: FontWeight.w800,
                              fontSize: AppTypography.captionSize,
                            ),
                            selectedColor: TgScreenPalette.primaryGreen,
                            backgroundColor: TgScreenPalette.surfaceLight,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            onSelected: (_) => setSheetState(() => category = cat),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 6),
                    Flexible(
                      child: templates.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(28),
                                child: Text(
                                  'Шаблоны не найдены',
                                  style: TextStyle(fontFamily: AppTypography.fontFamily, color: TgScreenPalette.textMuted, fontWeight: FontWeight.w700),
                                ),
                              ),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                              itemCount: templates.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (ctx, i) {
                                final template = templates[i];
                                return _TemplateCard(
                                  template: template,
                                  onOpen: () => _openTrainingTemplate(template),
                                  onDuplicate: () async {
                                    await _duplicateTrainingTemplate(template);
                                    setSheetState(() {});
                                  },
                                  onDelete: template.builtin
                                      ? null
                                      : () async {
                                          await _deleteTrainingTemplate(template);
                                          setSheetState(() {});
                                        },
                                  onExport: () => _exportTrainingTemplate(template),
                                  onAddToPlan: () async {
                                    await _addTemplateToTrainingPlan(template);
                                    setSheetState(() {});
                                  },
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
      },
    );
    searchCtrl.dispose();
  }


  // ==========================
  // Training plan
  // ==========================
  Future<void> _loadTrainingPlan() async {
    if (_trainingPlanLoaded) return;
    try {
      final raw = await PrefUtils.getStringValue(_trainingPlanStorageKey);
      final parsed = raw == null || raw.trim().isEmpty ? null : jsonDecode(raw);
      final list = <_TrainingPlanExercise>[];
      if (parsed is List) {
        for (final item in parsed) {
          if (item is Map) {
            final exercise = _TrainingPlanExercise.fromJson(Map<String, dynamic>.from(item));
            if (exercise != null) list.add(exercise);
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _trainingPlanExercises = list;
        _trainingPlanLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _trainingPlanLoaded = true);
    }
  }

  Future<void> _persistTrainingPlan() async {
    final raw = jsonEncode(_trainingPlanExercises.map((e) => e.toJson()).toList());
    await PrefUtils.setStringValue(_trainingPlanStorageKey, raw);
  }

  Future<Map<String, dynamic>> _readJsonMapPref(String key) async {
    try {
      final raw = await PrefUtils.getStringValue(key);
      if (raw == null || raw.trim().isEmpty) return <String, dynamic>{};
      final parsed = jsonDecode(raw);
      return parsed is Map ? Map<String, dynamic>.from(parsed) : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> _loadTrainingWorkflowMeta() async {
    if (_workflowMetaLoaded) return;
    final calendar = await _readJsonMapPref(_trainingCalendarStorageKey);
    final attendance = await _readJsonMapPref(_trainingAttendanceStorageKey);
    final execution = await _readJsonMapPref(_trainingExecutionStorageKey);
    final tracker = await _readJsonMapPref(_trainingTrackerStorageKey);
    if (!mounted) return;
    setState(() {
      _trainingCalendarMeta = calendar;
      _trainingAttendanceMeta = attendance;
      _trainingExecutionMeta = execution;
      _trainingTrackerMeta = tracker;
      _workflowMetaLoaded = true;
    });
  }

  Future<void> _persistTrainingWorkflowMeta() async {
    await PrefUtils.setStringValue(_trainingCalendarStorageKey, jsonEncode(_trainingCalendarMeta));
    await PrefUtils.setStringValue(_trainingAttendanceStorageKey, jsonEncode(_trainingAttendanceMeta));
    await PrefUtils.setStringValue(_trainingExecutionStorageKey, jsonEncode(_trainingExecutionMeta));
    await PrefUtils.setStringValue(_trainingTrackerStorageKey, jsonEncode(_trainingTrackerMeta));
  }

  int get _trainingPlanTotalMinutes => _trainingPlanExercises.fold<int>(0, (sum, e) => sum + e.durationMin);

  int get _trainingAttendancePresent {
    final v = _trainingAttendanceMeta['present'];
    return v is int ? v : int.tryParse('${v ?? 0}') ?? 0;
  }

  int get _trainingAttendanceExpected {
    final v = _trainingAttendanceMeta['expected'];
    final fromPlan = _trainingPlanExercises.isEmpty ? 0 : _trainingPlanExercises.map((e) => e.playersCount).fold<int>(0, math.max);
    return v is int ? v : int.tryParse('${v ?? fromPlan}') ?? fromPlan;
  }

  int get _trainingCompletedExercises {
    final raw = _trainingExecutionMeta['completedExerciseIds'];
    if (raw is List) return raw.length;
    return 0;
  }

  Map<String, dynamic> _buildTrainingWorkflowPayload() {
    return <String, dynamic>{
      'type': 'sportoteka_training_workflow_v35',
      'club_id': widget.resolvedClubId,
      'club_name': widget.resolvedClubName,
      'team_id': widget.resolvedTeamId,
      'team_name': widget.resolvedTeamName,
      'graphic_id': graphicId,
      'total_minutes': _trainingPlanTotalMinutes,
      'exercises_count': _trainingPlanExercises.length,
      'templates': _userTrainingTemplates.map((e) => e.toJson()).toList(),
      'plan': _trainingPlanExercises.map((e) => e.toJson()).toList(),
      'calendar': Map<String, dynamic>.from(_trainingCalendarMeta),
      'attendance': Map<String, dynamic>.from(_trainingAttendanceMeta),
      'execution': Map<String, dynamic>.from(_trainingExecutionMeta),
      'tracker': Map<String, dynamic>.from(_trainingTrackerMeta),
      'cmr_linkage': <String, dynamic>{
        'plans_module': 'cmr_plans_panel',
        'calendar_event_id': _trainingCalendarMeta['event_id'],
        'attendance_event_id': _trainingAttendanceMeta['event_id'] ?? _trainingCalendarMeta['event_id'],
        'tracker_session_id': _trainingTrackerMeta['session_id'],
      },
      'current_scheme': _currentDocJsonWithPlayback(),
      'exported_at': DateTime.now().toIso8601String(),
    };
  }

  Future<_PlanExerciseDraft?> _showExerciseDraftDialog({
    String? initialTitle,
    String? initialBlock,
    int? initialDuration,
    String? initialGoal,
    String? initialEquipment,
    int? initialPlayers,
  }) async {
    final titleCtrl = TextEditingController(text: initialTitle ?? _suggestTemplateTitle());
    final goalCtrl = TextEditingController(text: initialGoal ?? 'Цель упражнения');
    final equipmentCtrl = TextEditingController(text: initialEquipment ?? 'мячи, фишки, манишки');
    final durationCtrl = TextEditingController(text: '${initialDuration ?? 12}');
    final playersCtrl = TextEditingController(text: '${initialPlayers ?? 10}');
    var block = initialBlock ?? 'Основная часть';

    final result = await _showWorkflowPanel<_PlanExerciseDraft>(
      title: 'Добавить в план',
      subtitle: 'Упражнение станет частью структуры тренировки',
      icon: Icons.playlist_add_rounded,
      maxWidth: 560,
      builder: (panelContext) => StatefulBuilder(
        builder: (panelContext, setPanelState) => SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(controller: titleCtrl, decoration: _workflowInputDecoration('Упражнение', hint: 'Например: Рондо 5v2', icon: Icons.sports_soccer_rounded)),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: block,
                decoration: _workflowInputDecoration('Блок занятия', icon: Icons.view_agenda_outlined),
                items: _trainingPlanBlocks.map((e) => DropdownMenuItem<String>(value: e, child: Text(e))).toList(),
                onChanged: (v) => setPanelState(() => block = v ?? block),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: TextField(controller: durationCtrl, keyboardType: TextInputType.number, decoration: _workflowInputDecoration('Минуты'))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: playersCtrl, keyboardType: TextInputType.number, decoration: _workflowInputDecoration('Игроков'))),
              ]),
              const SizedBox(height: 10),
              TextField(controller: goalCtrl, minLines: 2, maxLines: 4, decoration: _workflowInputDecoration('Цель / акценты тренера', icon: Icons.flag_outlined)),
              const SizedBox(height: 10),
              TextField(controller: equipmentCtrl, minLines: 1, maxLines: 3, decoration: _workflowInputDecoration('Инвентарь', icon: Icons.inventory_2_outlined)),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: () => Navigator.of(panelContext).pop(), child: const Text('Отмена'))),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () {
                      final title = titleCtrl.text.trim();
                      if (title.isEmpty) return;
                      Navigator.of(panelContext).pop(_PlanExerciseDraft(
                        title: title,
                        block: block,
                        durationMin: (int.tryParse(durationCtrl.text.trim())?.clamp(1, 240) as num?)?.toInt() ?? 12,
                        playersCount: (int.tryParse(playersCtrl.text.trim())?.clamp(1, 99) as num?)?.toInt() ?? 10,
                        goal: goalCtrl.text.trim().isEmpty ? 'Цель упражнения' : goalCtrl.text.trim(),
                        equipment: equipmentCtrl.text.trim().isEmpty ? 'мячи, фишки, манишки' : equipmentCtrl.text.trim(),
                      ));
                    },
                    icon: const Icon(Icons.add_rounded, size: 17),
                    label: const Text('Добавить'),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );

    titleCtrl.dispose();
    goalCtrl.dispose();
    equipmentCtrl.dispose();
    durationCtrl.dispose();
    playersCtrl.dispose();
    return result;
  }

  Future<void> _addCurrentSchemeToTrainingPlan() async {
    final draft = await _showExerciseDraftDialog(initialTitle: _suggestTemplateTitle());
    if (draft == null) return;
    final exercise = _TrainingPlanExercise(
      id: 'exercise_${DateTime.now().millisecondsSinceEpoch}',
      title: draft.title,
      block: draft.block,
      durationMin: draft.durationMin,
      playersCount: draft.playersCount,
      goal: draft.goal,
      equipment: draft.equipment,
      docJson: _currentDocJsonWithPlayback(),
      createdAt: DateTime.now(),
    );
    setState(() => _trainingPlanExercises.add(exercise));
    await _persistTrainingPlan();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Добавлено в план: ${exercise.title}')));
  }

  Future<void> _addTemplateToTrainingPlan(_TrainingTemplate template) async {
    final draft = await _showExerciseDraftDialog(
      initialTitle: template.title,
      initialBlock: _blockForTemplateCategory(template.category),
      initialGoal: template.description,
      initialDuration: 12,
      initialPlayers: 10,
    );
    if (draft == null) return;
    final doc = template.docJson == null ? null : Map<String, dynamic>.from(template.docJson!);
    final exercise = _TrainingPlanExercise(
      id: 'exercise_${DateTime.now().millisecondsSinceEpoch}',
      title: draft.title,
      block: draft.block,
      durationMin: draft.durationMin,
      playersCount: draft.playersCount,
      goal: draft.goal,
      equipment: draft.equipment,
      templateId: template.id,
      templateTitle: template.title,
      presetKey: template.presetKey,
      docJson: doc,
      createdAt: DateTime.now(),
    );
    setState(() => _trainingPlanExercises.add(exercise));
    await _persistTrainingPlan();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Шаблон добавлен в план: ${exercise.title}')));
  }

  String _blockForTemplateCategory(String category) {
    switch (category) {
      case 'Разминка':
      case 'Скорость':
        return 'Разминка';
      case 'Индивидуальная':
        return 'Индивидуальная работа';
      case 'Оборона':
      case 'Прессинг':
      case 'Стандарты':
        return 'Тактика';
      default:
        return 'Основная часть';
    }
  }

  Future<void> _openTrainingPlanExercise(_TrainingPlanExercise exercise) async {
    Navigator.of(context).maybePop();
    _stopPlayback();
    if (exercise.docJson != null) {
      _applyDocJson(exercise.docJson);
    } else if ((exercise.presetKey ?? '').isNotEmpty) {
      _restoringDraft = true;
      try {
        state.applyTacticalPreset(exercise.presetKey!, replaceExisting: true);
        _playbackSteps
          ..clear()
          ..addAll(const ['Шаг 1', 'Шаг 2', 'Шаг 3', 'Шаг 4']);
        _playbackRouteStepById.clear();
        _playbackRouteSubjectById.clear();
        _pendingPlaybackSubjectId = null;
        _currentPlaybackStep = 0;
        _playbackProgress = 0.0;
      } finally {
        _restoringDraft = false;
      }
    }
    _dirty = true;
    _scheduleDraftSave();
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fitField();
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Открыто упражнение: ${exercise.title}')));
  }

  Future<void> _duplicateTrainingPlanExercise(_TrainingPlanExercise exercise) async {
    final copy = exercise.copyWith(
      id: 'exercise_${DateTime.now().millisecondsSinceEpoch}',
      title: '${exercise.title} копия',
      createdAt: DateTime.now(),
    );
    setState(() => _trainingPlanExercises.add(copy));
    await _persistTrainingPlan();
  }

  Future<void> _deleteTrainingPlanExercise(_TrainingPlanExercise exercise) async {
    setState(() => _trainingPlanExercises.removeWhere((e) => e.id == exercise.id));
    await _persistTrainingPlan();
  }

  Future<void> _moveTrainingPlanExercise(int index, int delta) async {
    final next = index + delta;
    if (next < 0 || next >= _trainingPlanExercises.length) return;
    setState(() {
      final item = _trainingPlanExercises.removeAt(index);
      _trainingPlanExercises.insert(next, item);
    });
    await _persistTrainingPlan();
  }

  Future<void> _exportTrainingPlanJson() async {
    await _loadTrainingPlan();
    await _loadTrainingWorkflowMeta();
    final payload = jsonEncode(_buildTrainingWorkflowPayload());
    final saved = await saveTgExportFile(
      'training_plan.json',
      Uint8List.fromList(utf8.encode(payload)),
      mimeType: 'application/json',
      folderName: _exportFolderName(),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('План экспортирован: $saved')));
  }



  Future<T?> _showWorkflowPanel<T>({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget Function(BuildContext panelContext) builder,
    Color accent = TgScreenPalette.primaryGreen,
    double maxWidth = 560,
  }) {
    final media = MediaQuery.of(context);
    final isPhone = media.size.width < 720;
    return showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Закрыть',
      barrierColor: Colors.black.withOpacity(.16),
      transitionDuration: const Duration(milliseconds: 210),
      pageBuilder: (dialogContext, a1, a2) {
        final height = MediaQuery.of(dialogContext).size.height;
        final width = MediaQuery.of(dialogContext).size.width;
        return SafeArea(
          child: Align(
            alignment: isPhone ? Alignment.bottomCenter : Alignment.centerRight,
            child: Padding(
              padding: EdgeInsets.fromLTRB(isPhone ? 10 : 22, 10, isPhone ? 10 : 18, isPhone ? 10 : 12),
              child: Material(
                color: Colors.transparent,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isPhone ? width - 20 : maxWidth,
                    maxHeight: isPhone ? height * .92 : height - 24,
                  ),
                  child: _WorkflowPanelShell(
                    title: title,
                    subtitle: subtitle,
                    icon: icon,
                    accent: accent,
                    child: builder(dialogContext),
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: isPhone ? const Offset(0, .08) : const Offset(.06, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  InputDecoration _workflowInputDecoration(String label, {String? hint, IconData? icon}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon, size: 17),
      isDense: true,
      filled: true,
      fillColor: TgScreenPalette.surfaceLight,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      labelStyle: const TextStyle(fontFamily: AppTypography.fontFamily, color: TgScreenPalette.textMuted, fontWeight: FontWeight.w700, fontSize: AppTypography.captionSize),
      hintStyle: const TextStyle(fontFamily: AppTypography.fontFamily, color: TgScreenPalette.textLight, fontWeight: FontWeight.w600, fontSize: AppTypography.captionSize),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: TgScreenPalette.borderLight)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: TgScreenPalette.primaryGreen, width: 1.2)),
    );
  }

  Map<String, dynamic> _decodeWorkflowMap(String raw) {
    final clear = raw.trim();
    if (clear.isEmpty) return <String, dynamic>{};
    final obj = clear.indexOf('{');
    final arr = clear.indexOf('[');
    final starts = <int>[if (obj >= 0) obj, if (arr >= 0) arr];
    if (starts.isEmpty) return <String, dynamic>{'raw': clear};
    final start = starts.reduce((a, b) => a < b ? a : b);
    final decoded = jsonDecode(clear.substring(start));
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    if (decoded is List) return <String, dynamic>{'items': decoded};
    return <String, dynamic>{'value': decoded};
  }

  Future<Map<String, int>> _loadCmrAttendanceSummaryByEventId(String eventId) async {
    final safeEventId = eventId.trim();
    if (safeEventId.isEmpty) return const <String, int>{};
    final uri = Uri.parse('https://sportotekaapp.ru/api/get_team_attendance.php').replace(queryParameters: {'event_id': safeEventId});
    final resp = await http.get(uri).timeout(const Duration(seconds: 12));
    final data = _decodeWorkflowMap(resp.body);
    final rawItems = data['items'] ?? data['data'] ?? data['attendance'];
    final rows = <Map<String, dynamic>>[];
    if (rawItems is Map) {
      for (final v in rawItems.values) {
        if (v is Map) rows.add(Map<String, dynamic>.from(v));
      }
    } else if (rawItems is List) {
      for (final v in rawItems) {
        if (v is Map) rows.add(Map<String, dynamic>.from(v));
      }
    }
    var present = 0;
    var late = 0;
    var absent = 0;
    var injured = 0;
    var individual = 0;
    for (final row in rows) {
      final status = (row['status'] ?? '').toString().toLowerCase().trim();
      if (status == 'present') present++;
      if (status == 'late') late++;
      if (status == 'absent') absent++;
      if (status == 'injured') injured++;
      if (status == 'individual') individual++;
    }
    return <String, int>{
      'expected': rows.length,
      'present': present + late + individual,
      'late': late,
      'absent': absent,
      'injured': injured,
      'individual': individual,
    };
  }

  Future<Map<String, dynamic>> _loadTrackerSummaryBySessionId(String sessionId) async {
    final sid = sessionId.trim();
    if (sid.isEmpty) return <String, dynamic>{};

    Map<String, dynamic> extract(Map<String, dynamic> data) {
      final report = data['report'] is Map ? Map<String, dynamic>.from(data['report'] as Map) : data;
      final summary = report['summary'] is Map
          ? Map<String, dynamic>.from(report['summary'] as Map)
          : (report['team_summary'] is Map ? Map<String, dynamic>.from(report['team_summary'] as Map) : report);
      Object? pick(List<String> keys) {
        for (final map in [summary, report, data]) {
          for (final key in keys) {
            if (map[key] != null && map[key].toString().trim().isNotEmpty) return map[key];
          }
        }
        return null;
      }
      return <String, dynamic>{
        'session_id': sid,
        'distance_m': double.tryParse('${pick(['distance_m', 'total_distance_m', 'team_distance_m', 'distance']) ?? 0}'.replaceAll(',', '.')) ?? 0,
        'load_score': double.tryParse('${pick(['load_score', 'team_load_score', 'load']) ?? 0}'.replaceAll(',', '.')) ?? 0,
        'sprint_count': int.tryParse('${pick(['sprint_count', 'team_sprint_count', 'sprints']) ?? 0}') ?? 0,
        'max_speed_kmh': double.tryParse('${pick(['max_speed_kmh', 'team_max_speed_kmh', 'max_speed']) ?? 0}'.replaceAll(',', '.')) ?? 0,
        'players_count': int.tryParse('${pick(['players_count', 'active_players', 'players']) ?? 0}') ?? 0,
        'pdf_url': 'https://sportotekaapp.ru/api/tracker/export_training_report_pdf.php?session_id=$sid&team_id=${widget.resolvedTeamId}&template=analytics_ru&inline=1&print=1&v=87',
        'csv_url': 'https://sportotekaapp.ru/api/tracker/export_training_report_csv.php?session_id=$sid&team_id=${widget.resolvedTeamId}&v=87',
        'loaded_from': 'tracker_report_api',
        'updated_at': DateTime.now().toIso8601String(),
      };
    }

    try {
      final reportUri = Uri.parse('https://sportotekaapp.ru/api/tracker/get_training_report.php').replace(queryParameters: {
        'session_id': sid,
        'team_id': widget.resolvedTeamId.toString(),
      });
      final resp = await http.get(reportUri).timeout(const Duration(seconds: 14));
      final data = _decodeWorkflowMap(resp.body);
      if (data.isNotEmpty && data['success'] != false) return extract(data);
    } catch (_) {}

    final resp = await http.post(
      Uri.parse('https://sportotekaapp.ru/api/get_training_tracker_summary.php'),
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode({'club_id': widget.resolvedClubId, 'team_id': widget.resolvedTeamId, 'session_id': sid}),
    ).timeout(const Duration(seconds: 12));
    final data = _decodeWorkflowMap(resp.body);
    final item = data['item'] ?? data['data'] ?? data;
    if (item is Map) return extract(Map<String, dynamic>.from(item));
    return <String, dynamic>{'session_id': sid, 'updated_at': DateTime.now().toIso8601String()};
  }

  Future<void> _showWorkflowSyncPanel() async {
    await _loadTrainingPlan();
    await _loadUserTrainingTemplates();
    await _loadTrainingWorkflowMeta();
    String statusText = 'Готово к синхронизации с CMR: планы, шаблоны, календарь, посещаемость, трекер и текущая схема.';
    bool running = false;
    await _showWorkflowPanel<void>(
      title: 'Синхронизация CMR',
      subtitle: 'Единый пакет тренировки без стандартного AlertDialog',
      icon: Icons.sync_rounded,
      maxWidth: 620,
      builder: (panelContext) => StatefulBuilder(
        builder: (panelContext, setPanelState) {
          Future<void> run() async {
            if (running) return;
            setPanelState(() {
              running = true;
              statusText = 'Собираю workflow и отправляю на сервер...';
            });
            final msg = await _syncTrainingWorkflowToServer(silent: true);
            if (!mounted) return;
            setPanelState(() {
              running = false;
              statusText = msg;
            });
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _WorkflowChip(icon: Icons.event_note_rounded, label: '${_trainingPlanExercises.length} упражн. • $_trainingPlanTotalMinutes мин', active: _trainingPlanExercises.isNotEmpty),
                  _WorkflowChip(icon: Icons.calendar_month_rounded, label: (_trainingCalendarMeta['date'] ?? '').toString().isEmpty ? 'календарь не задан' : 'календарь связан', active: (_trainingCalendarMeta['date'] ?? '').toString().isNotEmpty),
                  _WorkflowChip(icon: Icons.groups_rounded, label: 'посещаемость ${_trainingAttendancePresent}/${_trainingAttendanceExpected}', active: _trainingAttendancePresent > 0),
                  _WorkflowChip(icon: Icons.sensors_rounded, label: (_trainingTrackerMeta['session_id'] ?? '').toString().isEmpty ? 'трекер не связан' : 'трекер #${_trainingTrackerMeta['session_id']}', active: (_trainingTrackerMeta['session_id'] ?? '').toString().isNotEmpty),
                ],
              ),
              const SizedBox(height: 14),
              _WorkflowInfoCard(icon: running ? Icons.cloud_sync_rounded : Icons.cloud_done_outlined, title: running ? 'Идёт синхронизация' : 'Статус', text: statusText),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: OutlinedButton.icon(onPressed: running ? null : () => _exportTrainingPlanJson(), icon: const Icon(Icons.file_download_outlined, size: 17), label: const Text('Offline JSON'))),
                  const SizedBox(width: 10),
                  Expanded(child: FilledButton.icon(onPressed: running ? null : run, icon: running ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.sync_rounded, size: 17), label: Text(running ? 'Отправка...' : 'Синхронизировать'))),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Future<String> _syncTrainingWorkflowToServer({bool silent = false}) async {
    await _loadTrainingPlan();
    await _loadUserTrainingTemplates();
    await _loadTrainingWorkflowMeta();
    if (_workflowSyncing) return 'Синхронизация уже выполняется';
    setState(() => _workflowSyncing = true);
    try {
      final resp = await http.post(
        Uri.parse('https://sportotekaapp.ru/api/save_training_workflow.php'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode(_buildTrainingWorkflowPayload()),
      ).timeout(const Duration(seconds: 14));
      final raw = resp.body.trim();
      final ok = resp.statusCode >= 200 && resp.statusCode < 300 && raw.isNotEmpty && !raw.startsWith('<');
      if (!ok) throw 'Сервер не принял workflow';
      final data = _decodeWorkflowMap(raw);
      if (data['success'] == true || data['status'] == 'success') {
        final msg = 'План, шаблоны, календарь, посещаемость, отчёт и трекер синхронизированы с CMR';
        if (!silent && mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        return msg;
      } else {
        throw (data['message'] ?? 'Ошибка синхронизации').toString();
      }
    } catch (e) {
      final fallback = jsonEncode(_buildTrainingWorkflowPayload());
      final saved = await saveTgExportFile(
        'training_workflow_offline_sync.json',
        Uint8List.fromList(utf8.encode(fallback)),
        mimeType: 'application/json',
        folderName: _exportFolderName(),
      );
      final msg = 'Серверная синхронизация недоступна, создан offline-файл: $saved';
      if (!silent && mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      return msg;
    } finally {
      if (mounted) setState(() => _workflowSyncing = false);
    }
  }

  Future<void> _showCalendarLinkDialog() async {
    await _loadTrainingWorkflowMeta();
    final eventIdCtrl = TextEditingController(text: (_trainingCalendarMeta['event_id'] ?? '').toString());
    final titleCtrl = TextEditingController(text: (_trainingCalendarMeta['title'] ?? 'Тренировка ${widget.resolvedTeamName}').toString());
    final dateCtrl = TextEditingController(text: (_trainingCalendarMeta['date'] ?? DateTime.now().toIso8601String().substring(0, 10)).toString());
    final timeCtrl = TextEditingController(text: (_trainingCalendarMeta['time'] ?? '18:00').toString());
    final locationCtrl = TextEditingController(text: (_trainingCalendarMeta['location'] ?? 'Поле').toString());
    final noteCtrl = TextEditingController(text: (_trainingCalendarMeta['note'] ?? '').toString());
    final res = await _showWorkflowPanel<Map<String, dynamic>>(
      title: 'Календарь CMR',
      subtitle: 'Связь плана с событием команды и будущей посещаемостью',
      icon: Icons.calendar_month_rounded,
      maxWidth: 600,
      builder: (panelContext) => SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _WorkflowInfoCard(
              icon: Icons.hub_outlined,
              title: 'Связка с CMR',
              text: 'Можно указать event_id уже созданной тренировки из календаря. По нему затем подтягивается посещаемость и связывается отчёт.',
            ),
            const SizedBox(height: 12),
            TextField(controller: eventIdCtrl, keyboardType: TextInputType.number, decoration: _workflowInputDecoration('event_id из календаря', hint: 'необязательно', icon: Icons.tag_rounded)),
            const SizedBox(height: 10),
            TextField(controller: titleCtrl, decoration: _workflowInputDecoration('Название события', icon: Icons.edit_calendar_rounded)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextField(controller: dateCtrl, decoration: _workflowInputDecoration('Дата YYYY-MM-DD', icon: Icons.date_range_rounded))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: timeCtrl, decoration: _workflowInputDecoration('Время', icon: Icons.schedule_rounded))),
            ]),
            const SizedBox(height: 10),
            TextField(controller: locationCtrl, decoration: _workflowInputDecoration('Место', icon: Icons.place_outlined)),
            const SizedBox(height: 10),
            TextField(controller: noteCtrl, minLines: 2, maxLines: 4, decoration: _workflowInputDecoration('Комментарий', icon: Icons.notes_rounded)),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: () => Navigator.of(panelContext).pop(), child: const Text('Отмена'))),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => Navigator.of(panelContext).pop(<String, dynamic>{
                      'event_id': eventIdCtrl.text.trim(),
                      'title': titleCtrl.text.trim(),
                      'date': dateCtrl.text.trim(),
                      'time': timeCtrl.text.trim(),
                      'location': locationCtrl.text.trim(),
                      'note': noteCtrl.text.trim(),
                      'duration_minutes': _trainingPlanTotalMinutes,
                      'cmr_module': 'calendar',
                      'updated_at': DateTime.now().toIso8601String(),
                    }),
                    icon: const Icon(Icons.check_rounded, size: 17),
                    label: const Text('Связать'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
    eventIdCtrl.dispose();
    titleCtrl.dispose();
    dateCtrl.dispose();
    timeCtrl.dispose();
    locationCtrl.dispose();
    noteCtrl.dispose();
    if (res == null) return;
    setState(() => _trainingCalendarMeta = res);
    await _persistTrainingWorkflowMeta();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('План связан с календарём CMR')));
  }

  Future<void> _showAttendanceFactDialog() async {
    await _loadTrainingWorkflowMeta();
    final eventIdCtrl = TextEditingController(text: (_trainingAttendanceMeta['event_id'] ?? _trainingCalendarMeta['event_id'] ?? '').toString());
    final expectedCtrl = TextEditingController(text: '${_trainingAttendanceExpected == 0 ? 10 : _trainingAttendanceExpected}');
    final presentCtrl = TextEditingController(text: '${_trainingAttendancePresent == 0 ? (_trainingAttendanceExpected == 0 ? 10 : _trainingAttendanceExpected) : _trainingAttendancePresent}');
    final rpeCtrl = TextEditingController(text: (_trainingExecutionMeta['rpe'] ?? '5').toString());
    final completionCtrl = TextEditingController(text: (_trainingExecutionMeta['completionPercent'] ?? '100').toString());
    final noteCtrl = TextEditingController(text: (_trainingExecutionMeta['coachNote'] ?? '').toString());
    final done = <String>{
      ...((_trainingExecutionMeta['completedExerciseIds'] is List)
          ? (_trainingExecutionMeta['completedExerciseIds'] as List).map((e) => e.toString())
          : _trainingPlanExercises.map((e) => e.id)),
    };
    String loadStatus = 'Можно заполнить вручную или подтянуть посещаемость по event_id из CMR.';
    final res = await _showWorkflowPanel<Map<String, dynamic>>(
      title: 'Посещаемость и факт',
      subtitle: 'CMR-форма без стандартного системного окна',
      icon: Icons.fact_check_outlined,
      maxWidth: 660,
      builder: (panelContext) => StatefulBuilder(
        builder: (panelContext, setPanelState) {
          Future<void> loadFromCmr() async {
            final eventId = eventIdCtrl.text.trim();
            if (eventId.isEmpty) {
              setPanelState(() => loadStatus = 'Укажите event_id из календаря.');
              return;
            }
            setPanelState(() => loadStatus = 'Загружаю посещаемость из CMR...');
            try {
              final summary = await _loadCmrAttendanceSummaryByEventId(eventId);
              if (summary.isEmpty || (summary['expected'] ?? 0) == 0) {
                setPanelState(() => loadStatus = 'По этому event_id пока нет сохранённой посещаемости.');
                return;
              }
              setPanelState(() {
                expectedCtrl.text = '${summary['expected'] ?? expectedCtrl.text}';
                presentCtrl.text = '${summary['present'] ?? presentCtrl.text}';
                loadStatus = 'Загружено: присутствовало ${summary['present']}/${summary['expected']}, опоздали ${summary['late'] ?? 0}, отсутствовали ${summary['absent'] ?? 0}.';
              });
            } catch (e) {
              setPanelState(() => loadStatus = 'Не удалось загрузить посещаемость: $e');
            }
          }

          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: TextField(controller: eventIdCtrl, keyboardType: TextInputType.number, decoration: _workflowInputDecoration('event_id календаря', icon: Icons.tag_rounded))),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(onPressed: loadFromCmr, icon: const Icon(Icons.download_rounded, size: 17), label: const Text('Из CMR')),
                ]),
                const SizedBox(height: 10),
                _WorkflowInfoCard(icon: Icons.groups_rounded, title: 'Источник посещаемости', text: loadStatus),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextField(controller: expectedCtrl, keyboardType: TextInputType.number, decoration: _workflowInputDecoration('План игроков'))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: presentCtrl, keyboardType: TextInputType.number, decoration: _workflowInputDecoration('Присутствовало'))),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: TextField(controller: rpeCtrl, keyboardType: TextInputType.number, decoration: _workflowInputDecoration('RPE 1–10'))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: completionCtrl, keyboardType: TextInputType.number, decoration: _workflowInputDecoration('Выполнение %'))),
                ]),
                const SizedBox(height: 12),
                const Text('Выполненные упражнения', style: TextStyle(fontFamily: AppTypography.fontFamily, color: TgScreenPalette.textSecondary, fontWeight: FontWeight.w900, fontSize: AppTypography.secondarySize)),
                const SizedBox(height: 6),
                DecoratedBox(
                  decoration: BoxDecoration(color: TgScreenPalette.surfaceLight, borderRadius: BorderRadius.circular(14), border: Border.all(color: TgScreenPalette.borderLight)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final ex in _trainingPlanExercises)
                        CheckboxListTile(
                          dense: true,
                          value: done.contains(ex.id),
                          activeColor: TgScreenPalette.primaryGreen,
                          onChanged: (v) => setPanelState(() {
                            if (v == true) {
                              done.add(ex.id);
                            } else {
                              done.remove(ex.id);
                            }
                          }),
                          title: Text(ex.title, style: const TextStyle(fontFamily: AppTypography.fontFamily, fontWeight: FontWeight.w800, fontSize: AppTypography.secondarySize)),
                          subtitle: Text('${ex.block} • ${ex.durationMin} мин', style: const TextStyle(fontFamily: AppTypography.fontFamily, fontSize: AppTypography.captionSize, color: TgScreenPalette.textMuted)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                TextField(controller: noteCtrl, minLines: 3, maxLines: 5, decoration: _workflowInputDecoration('Комментарий тренера после занятия', icon: Icons.notes_rounded)),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: OutlinedButton(onPressed: () => Navigator.of(panelContext).pop(), child: const Text('Отмена'))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(panelContext).pop(<String, dynamic>{
                        'event_id': eventIdCtrl.text.trim(),
                        'expected': int.tryParse(expectedCtrl.text.trim()) ?? _trainingAttendanceExpected,
                        'present': int.tryParse(presentCtrl.text.trim()) ?? _trainingAttendancePresent,
                        'rpe': int.tryParse(rpeCtrl.text.trim()) ?? 5,
                        'completionPercent': int.tryParse(completionCtrl.text.trim()) ?? 100,
                        'coachNote': noteCtrl.text.trim(),
                        'completedExerciseIds': done.toList(),
                        'updated_at': DateTime.now().toIso8601String(),
                      }),
                      icon: const Icon(Icons.check_rounded, size: 17),
                      label: const Text('Сохранить факт'),
                    ),
                  ),
                ]),
              ],
            ),
          );
        },
      ),
    );
    eventIdCtrl.dispose();
    expectedCtrl.dispose();
    presentCtrl.dispose();
    rpeCtrl.dispose();
    completionCtrl.dispose();
    noteCtrl.dispose();
    if (res == null) return;
    setState(() {
      _trainingAttendanceMeta = <String, dynamic>{
        'event_id': res['event_id'],
        'expected': res['expected'],
        'present': res['present'],
        'updated_at': res['updated_at'],
      };
      _trainingExecutionMeta = <String, dynamic>{
        'rpe': res['rpe'],
        'completionPercent': res['completionPercent'],
        'coachNote': res['coachNote'],
        'completedExerciseIds': res['completedExerciseIds'],
        'updated_at': res['updated_at'],
      };
    });
    await _persistTrainingWorkflowMeta();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Факт тренировки сохранён')));
  }

  Future<void> _showTrackerLinkDialog() async {
    await _loadTrainingWorkflowMeta();
    final sessionCtrl = TextEditingController(text: (_trainingTrackerMeta['session_id'] ?? '').toString());
    final distanceCtrl = TextEditingController(text: (_trainingTrackerMeta['distance_m'] ?? '').toString());
    final loadCtrl = TextEditingController(text: (_trainingTrackerMeta['load_score'] ?? '').toString());
    final sprintCtrl = TextEditingController(text: (_trainingTrackerMeta['sprint_count'] ?? '').toString());
    final maxSpeedCtrl = TextEditingController(text: (_trainingTrackerMeta['max_speed_kmh'] ?? '').toString());
    final noteCtrl = TextEditingController(text: (_trainingTrackerMeta['note'] ?? '').toString());
    String loadStatus = 'Введите session_id или final session_id из трекера. Данные подтягиваются через tracker/report API.';
    final res = await _showWorkflowPanel<Map<String, dynamic>>(
      title: 'Связь с трекером',
      subtitle: 'Нагрузка тренировки + ссылка на отчёт трекера',
      icon: Icons.sensors_rounded,
      maxWidth: 620,
      builder: (panelContext) => StatefulBuilder(
        builder: (panelContext, setPanelState) {
          Future<void> fetchSummary() async {
            final sid = sessionCtrl.text.trim();
            if (sid.isEmpty) {
              setPanelState(() => loadStatus = 'Укажите session_id трекера.');
              return;
            }
            setPanelState(() => loadStatus = 'Загружаю отчёт трекера по session_id $sid...');
            try {
              final summary = await _loadTrackerSummaryBySessionId(sid);
              setPanelState(() {
                distanceCtrl.text = (summary['distance_m'] ?? distanceCtrl.text).toString();
                loadCtrl.text = (summary['load_score'] ?? loadCtrl.text).toString();
                sprintCtrl.text = (summary['sprint_count'] ?? sprintCtrl.text).toString();
                maxSpeedCtrl.text = (summary['max_speed_kmh'] ?? maxSpeedCtrl.text).toString();
                loadStatus = 'Загружено: ${summary['distance_m'] ?? 0} м, нагрузка ${summary['load_score'] ?? 0}, спринты ${summary['sprint_count'] ?? 0}, макс. скорость ${summary['max_speed_kmh'] ?? 0} км/ч.';
              });
            } catch (e) {
              setPanelState(() => loadStatus = 'Не удалось загрузить трекер: $e');
            }
          }

          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: TextField(controller: sessionCtrl, decoration: _workflowInputDecoration('session_id трекера', icon: Icons.tag_rounded))),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(onPressed: fetchSummary, icon: const Icon(Icons.download_rounded, size: 17), label: const Text('Загрузить')),
                ]),
                const SizedBox(height: 10),
                _WorkflowInfoCard(icon: Icons.analytics_outlined, title: 'Данные нагрузки', text: loadStatus),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: TextField(controller: distanceCtrl, keyboardType: TextInputType.number, decoration: _workflowInputDecoration('Дистанция, м'))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: loadCtrl, keyboardType: TextInputType.number, decoration: _workflowInputDecoration('Нагрузка'))),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: TextField(controller: sprintCtrl, keyboardType: TextInputType.number, decoration: _workflowInputDecoration('Спринты'))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: maxSpeedCtrl, keyboardType: TextInputType.number, decoration: _workflowInputDecoration('Макс. скорость, км/ч'))),
                ]),
                const SizedBox(height: 10),
                TextField(controller: noteCtrl, minLines: 2, maxLines: 4, decoration: _workflowInputDecoration('Комментарий по нагрузке', icon: Icons.notes_rounded)),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: OutlinedButton(onPressed: () => Navigator.of(panelContext).pop(), child: const Text('Отмена'))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(panelContext).pop(<String, dynamic>{
                        'session_id': sessionCtrl.text.trim(),
                        'distance_m': double.tryParse(distanceCtrl.text.trim().replaceAll(',', '.')) ?? 0,
                        'load_score': double.tryParse(loadCtrl.text.trim().replaceAll(',', '.')) ?? 0,
                        'sprint_count': int.tryParse(sprintCtrl.text.trim()) ?? 0,
                        'max_speed_kmh': double.tryParse(maxSpeedCtrl.text.trim().replaceAll(',', '.')) ?? 0,
                        'pdf_url': sessionCtrl.text.trim().isEmpty ? '' : 'https://sportotekaapp.ru/api/tracker/export_training_report_pdf.php?session_id=${sessionCtrl.text.trim()}&team_id=${widget.resolvedTeamId}&template=analytics_ru&inline=1&print=1&v=87',
                        'csv_url': sessionCtrl.text.trim().isEmpty ? '' : 'https://sportotekaapp.ru/api/tracker/export_training_report_csv.php?session_id=${sessionCtrl.text.trim()}&team_id=${widget.resolvedTeamId}&v=87',
                        'note': noteCtrl.text.trim(),
                        'cmr_module': 'tracker',
                        'updated_at': DateTime.now().toIso8601String(),
                      }),
                      icon: const Icon(Icons.link_rounded, size: 17),
                      label: const Text('Связать трекер'),
                    ),
                  ),
                ]),
              ],
            ),
          );
        },
      ),
    );
    sessionCtrl.dispose();
    distanceCtrl.dispose();
    loadCtrl.dispose();
    sprintCtrl.dispose();
    maxSpeedCtrl.dispose();
    noteCtrl.dispose();
    if (res == null) return;
    setState(() => _trainingTrackerMeta = res);
    await _persistTrainingWorkflowMeta();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Трекер привязан к тренировке')));
  }

  Future<void> _exportCoachTrainingReport() async {
    await _loadTrainingPlan();
    await _loadTrainingWorkflowMeta();
    final payload = _buildTrainingWorkflowPayload();
    payload['type'] = 'sportoteka_training_report_v35';
    final html = _buildTrainingReportHtml(payload);
    final jsonSaved = await saveTgExportFile(
      'training_report.json',
      Uint8List.fromList(utf8.encode(jsonEncode(payload))),
      mimeType: 'application/json',
      folderName: _exportFolderName(),
    );
    final htmlSaved = await saveTgExportFile(
      'training_report.html',
      Uint8List.fromList(utf8.encode(html)),
      mimeType: 'text/html',
      folderName: _exportFolderName(),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Отчёт создан: $jsonSaved / $htmlSaved')));
  }

  String _buildTrainingReportHtml(Map<String, dynamic> payload) {
    String esc(Object? v) => const HtmlEscape().convert((v ?? '').toString());
    final exercises = _trainingPlanExercises;
    final completed = ((_trainingExecutionMeta['completedExerciseIds'] is List) ? _trainingExecutionMeta['completedExerciseIds'] as List : const <dynamic>[]).map((e) => e.toString()).toSet();
    final rows = exercises.map((e) {
      final done = completed.isEmpty || completed.contains(e.id);
      return '<tr><td>${esc(e.block)}</td><td>${esc(e.title)}</td><td>${e.durationMin}</td><td>${e.playersCount}</td><td>${esc(e.goal)}</td><td>${done ? 'да' : 'нет'}</td></tr>';
    }).join();
    return '''<!doctype html><html><head><meta charset="utf-8"><title>Отчёт тренировки</title><style>body{font-family:Inter,Arial,sans-serif;margin:32px;color:#0B0F14}h1{font-size:24px;margin:0 0 6px}h2{font-size:16px;margin-top:24px}.muted{color:#6B7280}table{border-collapse:collapse;width:100%;margin-top:10px}td,th{border:1px solid #E5E7EB;padding:8px;font-size:12px;text-align:left}th{background:#F6F7F9}.kpi{display:flex;gap:10px;flex-wrap:wrap}.card{border:1px solid #E5E7EB;border-radius:12px;padding:12px;min-width:140px}</style></head><body><h1>Отчёт тренировки</h1><div class="muted">${esc(widget.resolvedClubName)} • ${esc(widget.resolvedTeamName)} • ${esc(_trainingCalendarMeta['date'])} ${esc(_trainingCalendarMeta['time'])}</div><div class="kpi"><div class="card"><b>План</b><br>${_trainingPlanTotalMinutes} мин</div><div class="card"><b>Упражнения</b><br>${exercises.length}</div><div class="card"><b>Посещаемость</b><br>${_trainingAttendancePresent}/${_trainingAttendanceExpected}</div><div class="card"><b>Выполнено</b><br>${_trainingCompletedExercises}/${exercises.length}</div><div class="card"><b>RPE</b><br>${esc(_trainingExecutionMeta['rpe'] ?? '-')}</div></div><h2>План и факт</h2><table><thead><tr><th>Блок</th><th>Упражнение</th><th>Мин</th><th>Игроков</th><th>Цель</th><th>Выполнено</th></tr></thead><tbody>$rows</tbody></table><h2>Трекер</h2><p>session_id: <b>${esc(_trainingTrackerMeta['session_id'] ?? '-')}</b><br>Дистанция: <b>${esc(_trainingTrackerMeta['distance_m'] ?? 0)} м</b><br>Нагрузка: <b>${esc(_trainingTrackerMeta['load_score'] ?? 0)}</b><br>Спринты: <b>${esc(_trainingTrackerMeta['sprint_count'] ?? 0)}</b></p><h2>Комментарий тренера</h2><p>${esc(_trainingExecutionMeta['coachNote'] ?? '')}</p></body></html>''';
  }

  String _todayIsoDate() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _suggestCmrPlanTitle() {
    if (_trainingPlanExercises.isNotEmpty) return '${widget.resolvedTeamName} · ${_todayIsoDate()} · ${_trainingPlanExercises.length} упражн.';
    return 'Тактическая тренировка ${widget.resolvedTeamName}';
  }

  String _buildCmrPlanDescription() {
    final lines = <String>[
      'Создано из тактической доски Спортотека.',
      'Команда: ${widget.resolvedTeamName}',
      'Длительность: $_trainingPlanTotalMinutes мин',
      'Упражнений: ${_trainingPlanExercises.length}',
      if (graphicId != null) 'Схема: graphic_id=$graphicId',
      '',
      for (var i = 0; i < _trainingPlanExercises.length; i++)
        '${i + 1}. ${_trainingPlanExercises[i].block}: ${_trainingPlanExercises[i].title} — ${_trainingPlanExercises[i].durationMin} мин. ${_trainingPlanExercises[i].goal}',
    ];
    return lines.join('\n').trim();
  }

  Future<Map<String, dynamic>?> _showCmrPlanSavePanel() async {
    await _loadTrainingPlan();
    final titleCtrl = TextEditingController(text: _suggestCmrPlanTitle());
    final cycleCtrl = TextEditingController(text: 'Недельный цикл');
    final dateCtrl = TextEditingController(text: _todayIsoDate());
    final locationCtrl = TextEditingController(text: 'Тренировочное поле');
    final descriptionCtrl = TextEditingController(text: _buildCmrPlanDescription());
    bool attachScheme = true;

    final result = await _showWorkflowPanel<Map<String, dynamic>>(
      title: 'Сохранить в CMR Plans',
      subtitle: 'План попадёт в выбранную папку и будет виден в разделе “Планы”',
      icon: Icons.cloud_done_rounded,
      maxWidth: 560,
      builder: (panelContext) {
        return StatefulBuilder(
          builder: (panelContext, setPanelState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _WorkflowInfoBox(
                  icon: Icons.folder_open_rounded,
                  title: folderTitle,
                  text: 'Папка сохранения CMR Plans. Можно выбрать другую, не выходя из редактора.',
                  action: OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await _showCmrFolderPickerPanel(title: 'Папка для плана');
                      if (picked == null) return;
                      setState(() {
                        folderId = _asInt(picked['id']);
                        folderTitle = _asStr(picked['title']).isNotEmpty ? _asStr(picked['title']) : 'Все материалы';
                      });
                      setPanelState(() {});
                    },
                    icon: const Icon(Icons.folder_rounded, size: 16),
                    label: const Text('Выбрать папку'),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(controller: titleCtrl, decoration: _workflowInputDecoration('Название плана', icon: Icons.edit_note_rounded)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: TextField(controller: cycleCtrl, decoration: _workflowInputDecoration('Цикл'))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: dateCtrl, decoration: _workflowInputDecoration('Дата'))),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(controller: locationCtrl, decoration: _workflowInputDecoration('Место', icon: Icons.place_outlined)),
                const SizedBox(height: 8),
                TextField(
                  controller: descriptionCtrl,
                  minLines: 4,
                  maxLines: 7,
                  decoration: _workflowInputDecoration('Описание / конспект'),
                ),
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: attachScheme,
                  activeColor: TgScreenPalette.primaryGreen,
                  onChanged: (v) => setPanelState(() => attachScheme = v),
                  title: const Text('Сохранить текущую схему и прикрепить к плану', style: TextStyle(fontFamily: AppTypography.fontFamily, fontWeight: FontWeight.w800, fontSize: AppTypography.bodySize)),
                  subtitle: Text(graphicId == null ? 'Сначала будет создана схема в этой же папке' : 'Будет обновлена схема #$graphicId', style: const TextStyle(fontFamily: AppTypography.fontFamily, fontWeight: FontWeight.w600, fontSize: AppTypography.captionSize, color: TgScreenPalette.textMuted)),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: OutlinedButton(onPressed: () => Navigator.of(panelContext).pop(), child: const Text('Отмена'))),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.of(panelContext).pop(<String, dynamic>{
                            'theme': titleCtrl.text.trim(),
                            'cycle_title': cycleCtrl.text.trim(),
                            'plan_date': dateCtrl.text.trim(),
                            'location': locationCtrl.text.trim(),
                            'description': descriptionCtrl.text.trim(),
                            'attach_scheme': attachScheme,
                          });
                        },
                        icon: const Icon(Icons.cloud_done_rounded, size: 18),
                        label: const Text('Сохранить в CMR'),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );

    titleCtrl.dispose();
    cycleCtrl.dispose();
    dateCtrl.dispose();
    locationCtrl.dispose();
    descriptionCtrl.dispose();
    return result;
  }

  Future<void> _saveTrainingPlanToCmr() async {
    if (saving) return;
    await _loadTrainingPlan();
    if (_trainingPlanExercises.isEmpty) {
      final add = await _showWorkflowPanel<bool>(
        title: 'План пустой',
        subtitle: 'Можно сначала добавить текущую схему как упражнение',
        icon: Icons.playlist_add_rounded,
        builder: (panelContext) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('В плане пока нет упражнений. Добавить текущую схему и продолжить сохранение?', style: TextStyle(fontFamily: AppTypography.fontFamily, color: TgScreenPalette.textSecondary, fontWeight: FontWeight.w700, height: 1.35)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.of(panelContext).pop(false), child: const Text('Отмена'))),
              const SizedBox(width: 8),
              Expanded(child: FilledButton(onPressed: () => Navigator.of(panelContext).pop(true), child: const Text('Добавить'))),
            ]),
          ],
        ),
      );
      if (add != true) return;
      await _addCurrentSchemeToTrainingPlan();
    }

    final meta = await _showCmrPlanSavePanel();
    if (meta == null) return;

    final createdBy = await PrefUtils.getUserId() ?? widget.resolvedClubId;
    setState(() => saving = true);

    try {
      int? linkedGraphicId = graphicId;
      if (meta['attach_scheme'] == true) {
        final png = await _capturePng();
        final docJson = state.toJson();
        docJson['playback'] = _buildPlaybackPayload();
        final graphicResp = await TrainingGraphicsApi.save(
          clubId: widget.resolvedClubId,
          teamId: widget.resolvedTeamId,
          folderId: folderId ?? 0,
          createdBy: createdBy,
          title: '${meta['theme']} · схема',
          docJson: jsonEncode(docJson),
          previewPngBytes: png,
          graphicId: graphicId,
        );
        if (graphicResp['success'] == true) {
          final id = graphicResp['id'];
          linkedGraphicId = id is int ? id : int.tryParse('${id ?? ''}');
          if (linkedGraphicId != null) graphicId = linkedGraphicId;
        }
      }

      final payload = <String, dynamic>{
        'id': _cmrSavedPlanId ?? 0,
        'plan_id': _cmrSavedPlanId ?? 0,
        'club_id': widget.resolvedClubId,
        'club_name': widget.resolvedClubName,
        'team_id': widget.resolvedTeamId,
        'team_name': widget.resolvedTeamName,
        'folder_id': folderId ?? 0,
        'folder_title': folderTitle,
        'folder_name': folderTitle,
        'theme': _asStr(meta['theme']).isEmpty ? _suggestCmrPlanTitle() : _asStr(meta['theme']),
        'cycle_title': _asStr(meta['cycle_title']).isEmpty ? 'Недельный цикл' : _asStr(meta['cycle_title']),
        'description': _asStr(meta['description']),
        'plan_description': _asStr(meta['description']),
        'plan_date': _asStr(meta['plan_date']).isEmpty ? _todayIsoDate() : _asStr(meta['plan_date']),
        'date': _asStr(meta['plan_date']).isEmpty ? _todayIsoDate() : _asStr(meta['plan_date']),
        'location': _asStr(meta['location']),
        'duration_min': _trainingPlanTotalMinutes,
        'players_count': _trainingAttendanceExpected,
        'graphic_id': linkedGraphicId ?? 0,
        'training_graphics_id': linkedGraphicId ?? 0,
        'training_plan_json': jsonEncode(_buildTrainingWorkflowPayload()),
      };

      final response = await http
          .post(
            Uri.parse('https://sportotekaapp.ru/api/create_training_plan.php'),
            headers: const {'Content-Type': 'application/json; charset=utf-8'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 16));

      final data = _decodeWorkflowMap(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300 || data['success'] != true) {
        throw data['message'] ?? response.body;
      }

      final newId = _asInt(data['plan_id'] ?? data['id'] ?? data['new_id'] ?? data['created_id'] ?? data['insert_id']);
      if (mounted) {
        setState(() {
          if (newId > 0) _cmrSavedPlanId = newId;
          _cmrPlanSavedAt = DateTime.now();
          _dirty = false;
        });
      }
      await _persistTrainingPlan();
      await _clearDraft();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('План сохранён в CMR: ${folderTitle.isEmpty ? 'Все материалы' : folderTitle}')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Не удалось сохранить в CMR: $e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _showTrainingPlanCenter() async {
    await _loadTrainingPlan();
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final grouped = <String, List<_TrainingPlanExercise>>{};
            for (final block in _trainingPlanBlocks) {
              grouped[block] = _trainingPlanExercises.where((e) => e.block == block).toList();
            }
            return SafeArea(
              child: Container(
                margin: const EdgeInsets.all(10),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * .86,
                  maxWidth: 840,
                ),
                decoration: BoxDecoration(
                  color: TgScreenPalette.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: TgScreenPalette.borderLight),
                  boxShadow: TgScreenPalette.windowShadow,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: TgScreenPalette.lightGreen,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.event_note_rounded, color: TgScreenPalette.primaryGreen, size: 18),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('План тренировки', style: TextStyle(fontFamily: AppTypography.fontFamily, color: TgScreenPalette.textPrimary, fontWeight: FontWeight.w900, fontSize: AppTypography.sectionTitleSize)),
                                const SizedBox(height: 1),
                                Text('${_trainingPlanExercises.length} упражн. • $_trainingPlanTotalMinutes мин • ${widget.resolvedTeamName}', style: const TextStyle(fontFamily: AppTypography.fontFamily, color: TgScreenPalette.textMuted, fontWeight: FontWeight.w700, fontSize: AppTypography.captionSize)),
                              ],
                            ),
                          ),
                          _MiniTemplateAction(icon: Icons.add_rounded, tooltip: 'Добавить текущую схему', onTap: () async {
                            await _addCurrentSchemeToTrainingPlan();
                            setSheetState(() {});
                          }),
                          _MiniTemplateAction(icon: Icons.cloud_done_rounded, tooltip: 'Сохранить в CMR Plans', onTap: () async {
                            await _saveTrainingPlanToCmr();
                            setSheetState(() {});
                          }),
                          _MiniTemplateAction(icon: Icons.sync_rounded, tooltip: 'Синхронизация с сервером', onTap: () async {
                            await _showWorkflowSyncPanel();
                            setSheetState(() {});
                          }),
                          _MiniTemplateAction(icon: Icons.calendar_month_rounded, tooltip: 'Календарь', onTap: () async {
                            await _showCalendarLinkDialog();
                            setSheetState(() {});
                          }),
                          _MiniTemplateAction(icon: Icons.fact_check_outlined, tooltip: 'Посещаемость / факт', onTap: () async {
                            await _showAttendanceFactDialog();
                            setSheetState(() {});
                          }),
                          _MiniTemplateAction(icon: Icons.sensors_rounded, tooltip: 'Трекер', onTap: () async {
                            await _showTrackerLinkDialog();
                            setSheetState(() {});
                          }),
                          _MiniTemplateAction(icon: Icons.article_outlined, tooltip: 'Отчёт тренера', onTap: () => _exportCoachTrainingReport()),
                          _MiniTemplateAction(icon: Icons.file_download_outlined, tooltip: 'Экспорт JSON', onTap: () => _exportTrainingPlanJson()),
                          _MiniTemplateAction(icon: Icons.close_rounded, tooltip: 'Закрыть', onTap: () => Navigator.of(ctx).pop()),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: TgScreenPalette.softLine),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                      child: Column(
                        children: [
                          _TrainingWorkflowStatusStrip(
                            calendarMeta: _trainingCalendarMeta,
                            attendanceMeta: _trainingAttendanceMeta,
                            executionMeta: _trainingExecutionMeta,
                            trackerMeta: _trainingTrackerMeta,
                            totalMinutes: _trainingPlanTotalMinutes,
                            exercisesCount: _trainingPlanExercises.length,
                          ),
                          const SizedBox(height: 7),
                          Row(
                            children: [
                              Icon(Icons.folder_open_rounded, size: 15, color: TgScreenPalette.primaryGreen),
                              const SizedBox(width: 6),
                              Expanded(child: Text('CMR папка: $folderTitle', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: AppTypography.fontFamily, color: TgScreenPalette.textMuted, fontWeight: FontWeight.w800, fontSize: AppTypography.captionSize))),
                              if (_cmrSavedPlanId != null) Text('план #$_cmrSavedPlanId', style: const TextStyle(fontFamily: AppTypography.fontFamily, color: TgScreenPalette.primaryGreen, fontWeight: FontWeight.w900, fontSize: AppTypography.captionSize)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: _trainingPlanExercises.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(28),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.event_note_outlined, color: TgScreenPalette.textLight, size: 34),
                                  const SizedBox(height: 10),
                                  const Text('План пока пустой', style: TextStyle(fontFamily: AppTypography.fontFamily, color: TgScreenPalette.textPrimary, fontWeight: FontWeight.w900, fontSize: AppTypography.sectionTitleSize)),
                                  const SizedBox(height: 4),
                                  const Text('Добавьте текущую схему или любой шаблон в тренировку.', textAlign: TextAlign.center, style: TextStyle(fontFamily: AppTypography.fontFamily, color: TgScreenPalette.textMuted, fontWeight: FontWeight.w600, fontSize: AppTypography.captionSize)),
                                  const SizedBox(height: 12),
                                  FilledButton.icon(
                                    onPressed: () async {
                                      await _addCurrentSchemeToTrainingPlan();
                                      setSheetState(() {});
                                    },
                                    icon: const Icon(Icons.add_rounded),
                                    label: const Text('Добавить текущую схему'),
                                  ),
                                ],
                              ),
                            )
                          : ListView(
                              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                              children: [
                                for (final block in _trainingPlanBlocks) ...[
                                  if ((grouped[block] ?? const <_TrainingPlanExercise>[]).isNotEmpty) ...[
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6, bottom: 6),
                                      child: Text(block, style: const TextStyle(fontFamily: AppTypography.fontFamily, color: TgScreenPalette.textSecondary, fontWeight: FontWeight.w900, fontSize: AppTypography.captionSize)),
                                    ),
                                    for (final exercise in grouped[block]!)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 8),
                                        child: _TrainingPlanExerciseCard(
                                          exercise: exercise,
                                          index: _trainingPlanExercises.indexWhere((e) => e.id == exercise.id),
                                          canMoveUp: _trainingPlanExercises.indexWhere((e) => e.id == exercise.id) > 0,
                                          canMoveDown: _trainingPlanExercises.indexWhere((e) => e.id == exercise.id) < _trainingPlanExercises.length - 1,
                                          onOpen: () => _openTrainingPlanExercise(exercise),
                                          onDuplicate: () async {
                                            await _duplicateTrainingPlanExercise(exercise);
                                            setSheetState(() {});
                                          },
                                          onDelete: () async {
                                            await _deleteTrainingPlanExercise(exercise);
                                            setSheetState(() {});
                                          },
                                          onMoveUp: () async {
                                            final index = _trainingPlanExercises.indexWhere((e) => e.id == exercise.id);
                                            await _moveTrainingPlanExercise(index, -1);
                                            setSheetState(() {});
                                          },
                                          onMoveDown: () async {
                                            final index = _trainingPlanExercises.indexWhere((e) => e.id == exercise.id);
                                            await _moveTrainingPlanExercise(index, 1);
                                            setSheetState(() {});
                                          },
                                        ),
                                      ),
                                  ],
                                ],
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
    );
  }

  // ==========================
  // Pick folder
  // ==========================
  Future<List<Map<String, dynamic>>> _loadCmrFoldersFlat() async {
    final resp = await PlanFoldersApi.list(clubId: widget.resolvedClubId);
    if (resp['success'] != true) {
      throw resp['message'] ?? 'Не удалось загрузить папки CMR';
    }

    final tree = (resp['tree'] as List?) ??
        (resp['folders'] as List?) ??
        (resp['data'] as List?) ??
        (resp['items'] as List?) ??
        const [];

    final flat = <Map<String, dynamic>>[];
    void walk(List list, [int level = 0, int? parentId]) {
      for (final item in list) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        map['_level'] = level;
        if (_asInt(map['parent_id']) == 0 && parentId != null) {
          map['parent_id'] = parentId;
        }
        final folderTeamId = _asInt(map['team_id']);
        final isGlobal = folderTeamId == 0;
        final isTeam = widget.resolvedTeamId <= 0 || folderTeamId == widget.resolvedTeamId;
        if (isGlobal || isTeam) flat.add(map);
        final children = (map['children'] as List?) ?? const [];
        if (children.isNotEmpty) walk(children, level + 1, _asInt(map['id']));
      }
    }

    walk(tree);
    return flat;
  }

  Future<Map<String, dynamic>?> _showCmrFolderPickerPanel({String title = 'Папка CMR'}) async {
    List<Map<String, dynamic>> folders = <Map<String, dynamic>>[];
    String? error;
    try {
      folders = await _loadCmrFoldersFlat();
    } catch (e) {
      error = '$e';
    }
    if (!mounted) return null;

    String q = '';
    return _showWorkflowPanel<Map<String, dynamic>>(
      title: title,
      subtitle: 'Выберите папку CMR Plans без перехода в старое окно',
      icon: Icons.folder_open_rounded,
      maxWidth: 520,
      builder: (panelContext) {
        return StatefulBuilder(
          builder: (panelContext, setPanelState) {
            final query = q.trim().toLowerCase();
            final visible = folders.where((f) {
              if (query.isEmpty) return true;
              return _asStr(f['title']).toLowerCase().contains(query) ||
                  _asStr(f['name']).toLowerCase().contains(query);
            }).toList();

            Widget folderTile(Map<String, dynamic>? folder) {
              final isAll = folder == null;
              final id = isAll ? 0 : _asInt(folder['id']);
              final level = isAll ? 0 : _asInt(folder['_level']);
              final active = (folderId ?? 0) == id;
              final title = isAll
                  ? 'Все материалы'
                  : (_asStr(folder['title']).isNotEmpty ? _asStr(folder['title']) : 'Папка');
              final hint = isAll
                  ? 'Корневая папка CMR Plans'
                  : [
                      if (_asInt(folder['plans_count']) > 0) '${_asInt(folder['plans_count'])} планов',
                      if (_asInt(folder['schemes_count']) > 0) '${_asInt(folder['schemes_count'])} схем',
                      if (_asInt(folder['files_count']) > 0) '${_asInt(folder['files_count'])} файлов',
                    ].join(' · ');

              return Padding(
                padding: EdgeInsets.only(left: isAll ? 0 : math.min(24.0, level * 12.0), bottom: 7),
                child: InkWell(
                  onTap: () => Navigator.of(panelContext).pop(<String, dynamic>{
                    'id': id,
                    'title': title,
                  }),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: active ? TgScreenPalette.lightGreen : TgScreenPalette.surfaceLight,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: active ? TgScreenPalette.primaryGreen : TgScreenPalette.borderLight),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: active ? Colors.white : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(isAll ? Icons.inventory_2_rounded : Icons.folder_rounded, color: active ? TgScreenPalette.primaryGreen : TgScreenPalette.textMuted, size: 18),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: AppTypography.fontFamily, color: TgScreenPalette.textPrimary, fontWeight: FontWeight.w900, fontSize: AppTypography.bodySize)),
                              const SizedBox(height: 2),
                              Text(hint.isEmpty ? 'CMR Plans' : hint, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: AppTypography.fontFamily, color: TgScreenPalette.textMuted, fontWeight: FontWeight.w700, fontSize: AppTypography.captionSize)),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: TgScreenPalette.textLight),
                      ],
                    ),
                  ),
                ),
              );
            }

            return ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 560),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    decoration: _workflowInputDecoration('Поиск папки', hint: 'Например: U13 / недельный цикл', icon: Icons.search_rounded),
                    onChanged: (v) => setPanelState(() => q = v),
                  ),
                  const SizedBox(height: 10),
                  if (error != null)
                    _WorkflowInfoBox(icon: Icons.error_outline_rounded, title: 'Не удалось загрузить папки', text: error!)
                  else
                    Flexible(
                      child: ListView(
                        shrinkWrap: true,
                        children: [
                          folderTile(null),
                          for (final f in visible) folderTile(f),
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

  Future<void> _pickFolder() async {
    final res = await _showCmrFolderPickerPanel(title: 'Сохранение в папку');
    if (res == null) return;

    setState(() {
      folderId = _asInt(res['id']);
      folderTitle = _asStr(res['title']).isNotEmpty ? _asStr(res['title']) : 'Все материалы';
    });

    if (widget.selectMode) {
      await _loadList();
    }
  }

  // ==========================
  // Load list (picker mode)
  // ==========================
  Future<void> _loadList() async {
    setState(() {
      _listLoading = true;
      _listError = null;
    });

    try {
      final resp = await http.post(
        Uri.parse("https://sportotekaapp.ru/api/list_training_graphics.php"),
        headers: {"Content-Type": "application/json; charset=utf-8"},
        body: jsonEncode({
          "club_id": widget.resolvedClubId,
          "team_id": widget.resolvedTeamId,
          "folder_id": folderId ?? 0,
        }),
      );

      final raw = resp.body.trim();
      if (raw.isEmpty) throw "Empty response";
      if (raw.startsWith("<") || raw.toLowerCase().contains("<br")) {
        throw "Server returned HTML instead of JSON";
      }

      final data = jsonDecode(raw);
      if (data is! Map) throw "Bad JSON: not a map";

      if (data["success"] == true) {
        final any = data["items"] ?? [];
        final list = (any is List)
            ? any.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
            : <Map<String, dynamic>>[];

        setState(() {
          _items = list;
          _listLoading = false;
        });
      } else {
        setState(() {
          _listLoading = false;
          _listError = (data["message"] ?? "Не удалось загрузить схемы").toString();
        });
      }
    } catch (e) {
      setState(() {
        _listLoading = false;
        _listError = e.toString();
      });
    }
  }

  // ==========================
  // Save graphic
  // ==========================
  Future<void> _saveGraphic() async {
    if (saving) return;

    final createdBy = await PrefUtils.getUserId() ?? 0;
    if (createdBy <= 0) {
      Get.snackbar(
        "Ошибка",
        "Не найден user_id (нужно войти в аккаунт)",
        backgroundColor: TgScreenPalette.error,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
        borderRadius: 12,
      );
      return;
    }

    setState(() => saving = true);

    try {
      final png = await _capturePng();
      final docJson = state.toJson();
      docJson['playback'] = _buildPlaybackPayload();

      final now = DateTime.now();
      final title =
          "Схема ${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}";

      final r = await TrainingGraphicsApi.save(
        clubId: widget.resolvedClubId,
        teamId: widget.resolvedTeamId,
        folderId: (folderId ?? 0),
        createdBy: createdBy,
        title: title,
        docJson: jsonEncode(docJson),
        previewPngBytes: png,
        graphicId: graphicId,
      );

      if (r["success"] == true) {
        final newId = r["id"];
        if (newId != null) {
          setState(() {
            graphicId = (newId is int) ? newId : int.tryParse(newId.toString());
          });
        }

        _dirty = false;
        await _clearDraft();

        Get.snackbar(
          "Готово",
          "Схема сохранена",
          backgroundColor: TgScreenPalette.success,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(12),
          borderRadius: 12,
        );
      } else {
        Get.snackbar(
          "Ошибка",
          (r["message"] ?? "Не удалось сохранить").toString(),
          backgroundColor: TgScreenPalette.error,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(12),
          borderRadius: 12,
        );
      }
    } catch (e) {
      Get.snackbar(
        "Сеть",
        "Ошибка: $e",
        backgroundColor: TgScreenPalette.error,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
        borderRadius: 12,
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  String _playerString(Map<String, dynamic> p, List<String> keys) {
    for (final key in keys) {
      final value = (p[key] ?? '').toString().trim();
      if (value.isNotEmpty && value.toLowerCase() != 'null') return value;
    }
    return '';
  }

  String _playerName(Map<String, dynamic> p) {
    final direct = _playerString(p, const ['name', 'full_name', 'fio', 'player_name']);
    if (direct.isNotEmpty) return direct;
    final first = _playerString(p, const ['first_name', 'firstname', 'firstName']);
    final last = _playerString(p, const ['last_name', 'lastname', 'lastName', 'surname']);
    final joined = '$first $last'.trim();
    return joined.isNotEmpty ? joined : 'Игрок';
  }

  String _playerNumber(Map<String, dynamic> p, int fallback) {
    final direct = _playerString(p, const ['number', 'shirt_number', 'jersey_number', 'game_number']);
    if (direct.isNotEmpty) return direct;
    return fallback.toString();
  }

  String _playerAvatarUrl(Map<String, dynamic> p) {
    final raw = _playerString(p, const [
      'avatar',
      'avatar_url',
      'photo',
      'photo_url',
      'image',
      'image_url',
      'profile_photo',
      'photo_path',
    ]);
    if (raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    if (raw.startsWith('//')) return 'https:$raw';
    if (raw.startsWith('/')) return 'https://sportotekaapp.ru$raw';
    return 'https://sportotekaapp.ru/$raw';
  }

  String _playerAvatarAsset(
    Map<String, dynamic> player, {
    required int index,
    required bool goalkeeper,
    required bool opponent,
  }) {
    final ring = opponent ? 'EF334D' : (goalkeeper ? '0EA5E9' : '00A750');
    final query = <String, String>{
      'id': _playerString(player, const ['id', 'player_id']).isNotEmpty
          ? _playerString(player, const ['id', 'player_id'])
          : 'player_$index',
      'name': _playerName(player),
      'number': _playerNumber(player, index + 1),
      'avatar': _playerAvatarUrl(player),
      'ring': ring,
      'team': opponent ? 'away' : 'home',
      'role': goalkeeper ? 'goalkeeper' : 'player',
    };
    return Uri(scheme: 'sportoteka', host: 'player-avatar', queryParameters: query).toString();
  }

  Future<void> _openPlayerPicker({required bool goalkeeper}) async {
    final players = _teamPlayersFor3D;
    bool opponent = false;

    if (players.isEmpty) {
      final demo = <String, dynamic>{
        'name': goalkeeper ? 'Вратарь' : 'Игрок',
        'number': goalkeeper ? '1' : '7',
      };
      state.setActiveStamp(_playerAvatarAsset(demo, index: goalkeeper ? 0 : 6, goalkeeper: goalkeeper, opponent: false));
      Get.snackbar(
        'Игрок выбран',
        'Нажмите на поле, чтобы поставить круг с аватаром.',
        backgroundColor: TgScreenPalette.primaryGreen,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(12),
        borderRadius: 12,
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              margin: const EdgeInsets.all(16),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * .72,
                maxWidth: 560,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: TgScreenPalette.borderLight),
                boxShadow: TgScreenPalette.windowShadow,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 14, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                goalkeeper ? 'Выберите вратаря' : 'Выберите игрока',
                                style: const TextStyle(
                                  fontFamily: AppTypography.fontFamily,
                                  color: TgScreenPalette.textPrimary,
                                  fontWeight: FontWeight.w900,
                                  fontSize: AppTypography.screenTitleSize,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'После выбора нажмите на поле — появится круг с аватаркой.',
                                style: TextStyle(
                                  fontFamily: AppTypography.fontFamily,
                                  color: TgScreenPalette.textMuted,
                                  fontWeight: FontWeight.w600,
                                  fontSize: AppTypography.badgeSize,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _TeamSideChip(
                            label: 'Зелёная команда',
                            active: !opponent,
                            color: TgScreenPalette.primaryGreen,
                            onTap: () => setSheetState(() => opponent = false),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _TeamSideChip(
                            label: 'Красная команда',
                            active: opponent,
                            color: const Color(0xFFEF334D),
                            onTap: () => setSheetState(() => opponent = true),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
                      itemCount: players.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) {
                        final p = players[i];
                        final name = _playerName(p);
                        final number = _playerNumber(p, i + 1);
                        final avatar = _playerAvatarUrl(p);
                        final ringColor = opponent
                            ? const Color(0xFFEF334D)
                            : (goalkeeper ? const Color(0xFF0EA5E9) : TgScreenPalette.primaryGreen);
                        return Material(
                          color: TgScreenPalette.surfaceLight,
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () {
                              state.setActiveStamp(_playerAvatarAsset(
                                p,
                                index: i,
                                goalkeeper: goalkeeper,
                                opponent: opponent,
                              ));
                              Navigator.of(ctx).pop();
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: ringColor, width: 3),
                                    ),
                                    child: ClipOval(
                                      child: avatar.isNotEmpty
                                          ? Image.network(
                                              avatar,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => _AvatarFallback(name: name, color: ringColor),
                                            )
                                          : _AvatarFallback(name: name, color: ringColor),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontFamily: AppTypography.fontFamily,
                                        color: TgScreenPalette.textPrimary,
                                        fontWeight: FontWeight.w800,
                                        fontSize: AppTypography.sectionTitleSize,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: 34,
                                    height: 34,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: ringColor,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                    child: Text(
                                      number,
                                      style: const TextStyle(
                                        fontFamily: AppTypography.fontFamily,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: AppTypography.badgeSize,
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
          },
        );
      },
    );
  }

  // ==========================
  // UI Build
  // ==========================
  Future<void> _pickFieldTexture() async {
    try {
      // file_picker 11.0.3: FilePicker использует статический pickFiles().
      // PlatformFile.size — свойство, а содержимое читаем через XFile,
      // чтобы не зависеть от dart:io и одинаково работать на desktop/mobile.
      final FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'],
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;

      final PlatformFile pickedFile = result.files.first;
      final int fileSize = pickedFile.size;
      if (fileSize > 4 * 1024 * 1024) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Текстура слишком большая. Используйте изображение до 4 МБ.')),
        );
        return;
      }

      final Uint8List bytes = pickedFile.bytes ?? await pickedFile.xFile.readAsBytes();
      if (bytes.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось прочитать изображение текстуры.')),
        );
        return;
      }

      final fileName = pickedFile.name.trim();

      state.setCustomFieldTexture(
        base64Data: base64Encode(bytes),
        name: fileName.isEmpty ? 'field_texture' : fileName,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Текстура поля: $e')),
      );
    }
  }

  void _setBoard3D(bool enabled) {
    final canvas = _canvasKey.currentState;
    if (canvas != null) {
      canvas.set3DEnabled(enabled);
      return;
    }
    state.set3DParams(
      enabled: enabled,
      rotationX: enabled ? -0.34 : 0.0,
      rotationY: 0.0,
      rotationZ: 0.0,
      perspective: 0.00135,
      cameraZoom: 0.96,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.selectMode) {
      return _buildPickerScreen();
    }

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        await _handleBack();
      },
      child: _buildEditorScreen(),
    );
  }

  Widget _buildPickerScreen() {
    return Scaffold(
      backgroundColor: TgScreenPalette.background,
      body: SafeArea(
        child: Column(
          children: [
            _TopTitleBar(
              title: "Выбор схем — ${widget.resolvedTeamName}",
              folderTitle: folderTitle,
              onBack: () => Navigator.of(context).maybePop(),
              onFit: null,
              onPickFolder: _pickFolder,
              onSave: null,
              onTogglePanel: null,
              onExport: null,
              onTemplates: null,
              onTrainingPlan: null,
              isPanelExpanded: false,
              isPanelCollapsed: false,
              selectMode: true,
              selectedCount: _selected.length,
              onAttach: _selected.isEmpty ? null : () => Navigator.of(context).pop(_selected.toList()),
              saving: false,
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _buildPickerContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPickerContent() {
    if (_listLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: TgScreenPalette.primaryGreen,
        ),
      );
    }

    if (_listError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: TgScreenPalette.error.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.wifi_off_rounded,
                  size: 48,
                  color: TgScreenPalette.error,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "Ошибка загрузки",
                style: TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  color: TgScreenPalette.textPrimary,
                  fontSize: AppTypography.screenTitleSize,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _listError!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  color: TgScreenPalette.textMuted,
                  fontSize: AppTypography.sectionTitleSize,
                ),
              ),
              const SizedBox(height: 20),
              TgScreenButton(
                onPressed: _loadList,
                width: 200,
                child: const Text(
                  "Повторить",
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: TgScreenPalette.surface,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.folder_open_outlined,
                size: 48,
                color: TgScreenPalette.textMuted,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              "В этой папке пока нет схем",
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                color: TgScreenPalette.textMuted,
                fontSize: AppTypography.screenTitleSize,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _items.length,
      itemBuilder: (ctx, i) {
        final it = _items[i];
        final id = _asInt(it["id"]);
        final title = (it["title"] ?? "").toString().trim();
        final previewUrl = (it["preview_url"] ?? "").toString().trim();
        final selected = _selected.contains(id);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TgScreenCard(
            isSelected: selected,
            onTap: () {
              if (id <= 0) return;
              setState(() {
                if (selected) {
                  _selected.remove(id);
                } else {
                  _selected.add(id);
                }
              });
            },
            child: Row(
              children: [
                Container(
                  width: 80,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                      color: Colors.transparent, 
                    border: Border.all(color: TgScreenPalette.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: previewUrl.isNotEmpty
                      ? Image.network(
                          previewUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.image_outlined,
                            color: TgScreenPalette.textMuted,
                          ),
                        )
                      : const Icon(
                          Icons.image_outlined,
                          color: TgScreenPalette.textMuted,
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.isEmpty ? "Схема #$id" : title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          color: TgScreenPalette.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: AppTypography.sectionTitleSize,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "ID: $id",
                        style: const TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: AppTypography.badgeSize,
                          color: TgScreenPalette.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected
                        ? TgScreenPalette.primaryGreen.withOpacity(0.1)
                        : Colors.transparent,
                    border: Border.all(
                      color: selected ? TgScreenPalette.primaryGreen : TgScreenPalette.border,
                      width: selected ? 2 : 1.5,
                    ),
                  ),
                  child: selected
                      ? const Icon(
                          Icons.check,
                          size: 16,
                          color: TgScreenPalette.primaryGreen,
                        )
                      : null,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEditorScreen() {
    return Scaffold(
      backgroundColor: TgScreenPalette.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, root) {
            final desktop = root.maxWidth >= 1180;
            final landscape = root.maxWidth >= root.maxHeight;
            final tabletLandscape = root.maxWidth >= 700 && landscape;
            final tabletPortrait = root.maxWidth >= 600 && root.maxWidth < 1180 && !tabletLandscape;
            final tightUi = root.maxWidth < 1180 || root.maxHeight < 760;
            final microUi = root.maxWidth < 760 || root.maxHeight < 560;
            // Панель может быть раскрыта или свернута. В свернутом состоянии
            // она не должна резервировать место и не должна скрывать нижний тулбар.
            final panelOpen = _isPanelExpanded && !_isPanelCollapsed;
            final overlayPanel = panelOpen && (microUi || root.maxWidth < 940 || root.maxHeight < 640);
            final panelAsSide = panelOpen && tabletLandscape;
            final panelAsBottom = panelOpen && !panelAsSide;
            // В micro/focus режиме панели накладываются поверх поля и не сжимают его.
            final sidePanelContentWidth = microUi
                ? math.min(286.0, math.max(220.0, root.maxWidth - 112.0))
                : (tightUi ? (root.maxWidth < 980 ? 286.0 : 322.0) : 356.0);
            final sidePanelDockReserve = microUi ? 62.0 : (tightUi ? 72.0 : 88.0);
            final sidePanelShellWidth = math.min(
              root.maxWidth - (microUi ? 10.0 : 18.0),
              sidePanelContentWidth + sidePanelDockReserve,
            ).clamp(232.0, 460.0) as double;
            // Панель может быть боковой и раскрытой, но нижняя панель инструментов
            // всё равно должна оставаться доступной слева от неё.
            final showBottomToolbars = !_exportCleanMode && (!panelOpen || panelAsSide);
            // Как в Tracker: на desktop/tablet инструменты живут в левой CMR-панели,
            // без дублирующей горизонтальной полосы над/под картой.
            final showBottomDrawingToolbar = showBottomToolbars && root.maxWidth < 920;
            final bottomToolRightInset = panelOpen && panelAsSide
                ? sidePanelShellWidth + (microUi ? 8.0 : 14.0)
                : (tightUi ? 6.0 : 0.0);
            final bottomToolLeftInset = tightUi ? 6.0 : 0.0;

            // Анимация больше не висит поверх поля снизу. Она открывается отдельным
            // окном справа; на широком экране поле освобождает для него место,
            // на узком окно аккуратно накладывается и закрывается по фону/крестику.
            final animationOpen = !_exportCleanMode && _animationPanelOpen;
            final animationAsSide = animationOpen && root.maxWidth >= 980 && root.maxHeight >= 600;
            final animationPanelShellWidth = root.maxWidth >= 1500
                ? 390.0
                : (root.maxWidth >= 1180 ? 370.0 : 340.0);

            final reservedRight = animationAsSide
                ? math.max(5.0, animationPanelShellWidth + 10.0)
                : ((!_exportCleanMode && panelAsSide && !overlayPanel)
                    ? math.max(5.0, sidePanelShellWidth + 8.0)
                    : 5.0);
            final idleBottomReserve = showBottomDrawingToolbar
                ? (microUi ? 62.0 : 70.0)
                : 10.0;
            final reservedBottom = _exportCleanMode
                ? 5.0
                : (overlayPanel
                    ? (microUi ? 44.0 : 54.0)
                    : panelAsBottom
                        ? (tabletPortrait ? 240.0 : 210.0)
                        : idleBottomReserve);
            return Container(
              color: TgScreenPalette.background,
              child: Row(
                children: [
                  TgLeftToolbar(
                    state: state,
                    workspaceWidth: root.maxWidth,
                    teamName: widget.resolvedTeamName,
                    onZoomToSelection: () => _canvasKey.currentState?.zoomToSelection(),
                    onResetView: () => _canvasKey.currentState?.resetView(),
                    onCloseEditor: _handleBack,
                    onOpenObjects: () => _openLegacyPanel(TgPanel.objects),
                    onOpenLayers: () => _openLegacyPanel(TgPanel.layers),
                    onOpenProperties: _openPropertiesPanel,
                    onOpenTactics: _openTacticalPadSheet,
                    onOpenAnimation: _toggleAnimationPanel,
                    animationOpen: _animationPanelOpen,
                    onSet3D: _setBoard3D,
                    onPickFieldTexture: _pickFieldTexture,
                    onClearFieldTexture: state.clearCustomFieldTexture,
                  ),
                  Expanded(
                    key: _rightPaneKey,
                    child: RepaintBoundary(
                      key: _exportRepaintKey,
                      child: ClipRect(
                        child: Stack(
                        children: [
                          Positioned.fill(
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(5, _exportCleanMode ? 5 : (microUi ? 38 : 49), reservedRight, reservedBottom),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: TgScreenPalette.surface,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: LayoutBuilder(
                                    builder: (context, c) {
                                      if (!_didLayoutFit) {
                                        final hasLoadedViewport =
                                            state.transform.value.value.storage[12].abs() > 0.5 ||
                                            state.transform.value.value.storage[13].abs() > 0.5 ||
                                            (state.transform.value.value.storage[0] - 1.0).abs() > 0.0001 ||
                                            (state.transform.value.value.storage[5] - 1.0).abs() > 0.0001;

                                        if (!hasLoadedViewport) {
                                          _didLayoutFit = true;
                                          WidgetsBinding.instance.addPostFrameCallback((_) {
                                            if (mounted) _fitField();
                                          });
                                        } else {
                                          _didLayoutFit = true;
                                        }
                                      }

                                      return RepaintBoundary(
                                        key: _repaintKey,
                                        child: TgCanvas(
                                          key: _canvasKey,
                                          state: state,
                                          onRequestEditSelected: _openPropertiesPanel,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (!_exportCleanMode)
                            Positioned(
                            left: 0,
                            right: 0,
                            top: 0,
                            child: _TopTitleBar(
                              title: widget.resolvedTeamName,
                              folderTitle: folderTitle,
                              onBack: _handleBack,
                              onFit: _fitField,
                              onPickFolder: _pickFolder,
                              onSave: _saveGraphic,
                              onTogglePanel: _togglePanel,
                              onExport: () => _showProExportCenter(),
                              onTemplates: () => _showTrainingTemplatesCenter(),
                              onTrainingPlan: () => _showTrainingPlanCenter(),
                              isPanelExpanded: _isPanelExpanded,
                              isPanelCollapsed: _isPanelCollapsed,
                              selectMode: false,
                              selectedCount: 0,
                              onAttach: null,
                              saving: saving,
                              clubId: widget.resolvedClubId,
                              clubName: widget.resolvedClubName,
                              teamId: widget.resolvedTeamId,
                              teamName: widget.resolvedTeamName,
                              players3d: _teamPlayersFor3D,
                              loadingPlayers3d: _teamPlayersLoading,
                              state: state,
                            ),
                          ),
                          if (!_exportCleanMode && _docLoading)
                            const Positioned.fill(
                              child: TgScreenLoadingOverlay(
                                message: 'Загрузка схемы...',
                              ),
                            ),
                          if (!_exportCleanMode && _docError != null && !_docLoading)
                            Positioned(
                              left: 20,
                              right: 20,
                              bottom: 24,
                              child: TgScreenErrorBanner(
                                message: _docError!,
                                onRetry: (graphicId == null || graphicId! <= 0)
                                    ? null
                                    : () => _loadDocById(graphicId!),
                                onDismiss: () => setState(() => _docError = null),
                              ),
                            ),
                          Positioned(
                            left: desktop ? 22 : 12,
                            right: desktop ? 22 : 12,
                            top: 60,
                            bottom: showBottomDrawingToolbar ? 70 : 12,
                            child: IgnorePointer(
                              child: _TgPlaybackOverlay(
                                canvasState: _canvasKey.currentState,
                                routes: _collectPlaybackRoutes(),
                                activeStep: _currentPlaybackStep,
                                progress: _playbackProgress,
                                visible: _playbackRunning || _collectPlaybackRoutes().isNotEmpty,
                              ),
                            ),
                          ),
                          if (showBottomDrawingToolbar)
                            Positioned(
                            left: bottomToolLeftInset,
                            right: bottomToolRightInset,
                            bottom: 10,
                            child: _ReferenceBottomToolbar(
                              state: state,
                              onObjects: () {
                                state.setTool(TgTool.stamp);
                                _openLegacyPanel(TgPanel.objects);
                              },
                              onLayers: () => _openLegacyPanel(TgPanel.layers),
                              onProperties: _openPropertiesPanel,
                              onTactical: _openTacticalPadSheet,
                              onPickPlayer: () => _openPlayerPicker(goalkeeper: false),
                              onPickGoalkeeper: () => _openPlayerPicker(goalkeeper: true),
                              onBall: () => state.setActiveStamp('sportoteka://ball'),
                              onChip: () => state.setActiveStamp('sportoteka://chip'),
                              onCone: () => state.setActiveStamp('sportoteka://cone'),
                              onDummy: () => state.setActiveStamp('sportoteka://dummy'),
                              onGoal: () => state.setActiveStamp('sportoteka://goal'),
                              onCurve: () => state.setTool(TgTool.curve),
                              onWavy: () => state.setTool(TgTool.wavy),
                            ),
                          ),
                          if (!_exportCleanMode && state.is3DMode)
                            Positioned(
                              right: animationAsSide
                                  ? animationPanelShellWidth + 18
                                  : (panelOpen && panelAsSide
                                      ? sidePanelShellWidth + 18
                                      : (tightUi ? 12 : 16)),
                              bottom: showBottomDrawingToolbar ? 58 : 14,
                              child: _TgTrackerCameraControl(
                                onOrbitDelta: (delta) => _canvasKey.currentState?.orbit3D(delta),
                                onZoomIn: () => _canvasKey.currentState?.zoom3DIn(),
                                onZoomOut: () => _canvasKey.currentState?.zoom3DOut(),
                                onReset: () => _canvasKey.currentState?.reset3DView(),
                              ),
                            ),
                          if (!_exportCleanMode && !_animationPanelOpen && state.selected != null && (!_isPanelExpanded || _isPanelCollapsed))
                            Positioned(
                              top: desktop ? 66 : 60,
                              right: tightUi ? 10 : (desktop ? 12 : 10),
                              child: _ReferenceStylePanel(state: state, onOpenProperties: _openPropertiesPanel),
                            ),
                          if (!_exportCleanMode && !_animationPanelOpen && !state.is3DMode && (!_isPanelExpanded || _isPanelCollapsed))
                            Positioned(
                            right: tightUi ? 10 : (desktop ? 12 : 10),
                            bottom: tightUi ? 58 : (desktop ? 70 : 88),
                            child: _ReferenceMiniMap(state: state),
                          ),
                          if (animationOpen && !animationAsSide)
                            Positioned.fill(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: _closeAnimationPanel,
                                child: Container(color: const Color(0x140B1220)),
                              ),
                            ),
                          if (animationOpen)
                            Positioned(
                              top: microUi ? 44 : 56,
                              right: 8,
                              bottom: 8,
                              left: animationAsSide ? null : 8,
                              width: animationAsSide ? animationPanelShellWidth : null,
                              child: _TgPlaybackWindow(
                                stepLabels: _playbackSteps,
                                currentStep: _currentPlaybackStep,
                                playing: _playbackRunning,
                                progress: _playbackProgress,
                                selectedSubjectLabel: _playbackSubjectLabel(),
                                currentBindings: _playbackBindingsForCurrentStep(),
                                onClose: _closeAnimationPanel,
                                onTogglePlay: _togglePlayback,
                                onSelectStep: _selectPlaybackStep,
                                onAddStep: _addPlaybackStep,
                                onDuplicateStep: _duplicatePlaybackStep,
                                onDeleteStep: _removePlaybackStep,
                                onRenameStep: _renamePlaybackStep,
                                onCaptureSubject: _capturePlaybackSubject,
                                onBindRoute: _bindSelectedRouteToCurrentStep,
                                onClearBinding: _clearSelectedRouteBinding,
                                onSelectBinding: _selectPlaybackBinding,
                                onDeleteBinding: _deletePlaybackBinding,
                              ),
                            ),
                          if (!_exportCleanMode && _isPanelExpanded)
                            Positioned.fill(
                              child: _TgDraggablePanel(
                                state: state,
                                stamps: stamps,
                                isPhone: _isPhone,
                                controller: _panelController,
                                isPanelCollapsed: _isPanelCollapsed,
                                onTogglePanel: _togglePanel,
                                canvasKey: _canvasKey,
                                onRefreshSvg: _refreshSvg,
                                onExportPng: () => _showProExportCenter(),
                                teamName: widget.resolvedTeamName,
                                teamPlayers: _teamPlayersFor3D,
                                teamPlayersLoading: _teamPlayersLoading,
                                teamPlayersError: _teamPlayersError,
                                initialPanel: _legacyPanelInitial,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}


class _ReferenceBottomToolbar extends StatelessWidget {
  const _ReferenceBottomToolbar({
    required this.state,
    required this.onObjects,
    required this.onLayers,
    required this.onProperties,
    required this.onTactical,
    required this.onPickPlayer,
    required this.onPickGoalkeeper,
    required this.onBall,
    required this.onChip,
    required this.onCone,
    required this.onDummy,
    required this.onGoal,
    required this.onCurve,
    required this.onWavy,
  });

  final TgState state;
  final VoidCallback onObjects;
  final VoidCallback onLayers;
  final VoidCallback onProperties;
  final VoidCallback onTactical;
  final VoidCallback onPickPlayer;
  final VoidCallback onPickGoalkeeper;
  final VoidCallback onBall;
  final VoidCallback onChip;
  final VoidCallback onCone;
  final VoidCallback onDummy;
  final VoidCallback onGoal;
  final VoidCallback onCurve;
  final VoidCallback onWavy;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (_, __) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.98),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: TgScreenPalette.borderLight.withOpacity(.72)),
                boxShadow: TgScreenPalette.windowShadow,
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ToolbarItem(icon: Icons.widgets_outlined, label: 'Объекты', active: state.tool == TgTool.stamp && (state.activeStampAsset?.startsWith('sportoteka://player-avatar') != true), onTap: onObjects),
                    _ToolbarItem(icon: Icons.auto_awesome_motion_rounded, label: 'Тактика', active: false, onTap: onTactical),
                    _ToolbarItem(icon: Icons.layers_outlined, label: 'Слои', active: false, onTap: onLayers),
                    _ToolbarItem(icon: Icons.tune_rounded, label: 'Свойства', active: state.selected != null, onTap: state.selected == null ? null : onProperties),
                    _ToolbarItem(
                      icon: Icons.person_outline_rounded,
                      label: 'Игрок',
                      active: state.activeStampAsset?.startsWith('sportoteka://player-avatar') == true,
                      onTap: onPickPlayer,
                    ),
                    _ToolbarItem(icon: Icons.sports_handball_rounded, label: 'Вратарь', active: state.activeStampAsset?.contains('role=goalkeeper') == true, onTap: onPickGoalkeeper),
                    _ToolbarItem(icon: Icons.sports_soccer_rounded, label: 'Мяч', active: state.activeStampAsset == 'sportoteka://ball', onTap: onBall),
                    _ToolbarItem(icon: Icons.circle_outlined, label: 'Фишка', active: state.activeStampAsset == 'sportoteka://chip', onTap: onChip),
                    _ToolbarItem(icon: Icons.change_history_rounded, label: 'Конус', active: state.activeStampAsset == 'sportoteka://cone', onTap: onCone),
                    _ToolbarItem(icon: Icons.table_rows_rounded, label: 'Ворота', active: state.activeStampAsset == 'sportoteka://goal', onTap: onGoal),
                    _ToolbarItem(icon: Icons.crop_free_rounded, label: 'Зона', active: state.tool == TgTool.rect, onTap: () => state.setTool(TgTool.rect)),
                    _ToolbarItem(icon: Icons.text_fields_rounded, label: 'Текст', active: state.tool == TgTool.text, onTap: () => state.setTool(TgTool.text)),
                    _ToolbarItem(icon: Icons.horizontal_rule_rounded, label: 'Линия', active: state.tool == TgTool.line, onTap: () => state.setTool(TgTool.line)),
                    _ToolbarItem(icon: Icons.draw_outlined, label: 'Кривая', active: state.tool == TgTool.curve, onTap: onCurve),
                    _ToolbarItem(icon: Icons.timeline_rounded, label: 'Волна', active: state.tool == TgTool.wavy, onTap: onWavy),
                    _ToolbarItem(icon: Icons.arrow_forward_rounded, label: 'Стрелка', active: false, onTap: () => state.setTool(TgTool.line)),
                    _ToolbarItem(icon: Icons.delete_outline_rounded, label: 'Удалить', active: false, danger: true, onTap: state.deleteSelected),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ToolbarItem extends StatelessWidget {
  const _ToolbarItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFE11D48) : (active ? TgScreenPalette.primaryGreen : TgScreenPalette.textSecondary);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Material(
        color: active ? TgScreenPalette.lightGreen : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 48,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: active ? Border.all(color: TgScreenPalette.primaryGreen.withOpacity(.18)) : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontFamily: TgScreenPalette.fontFamily,
                    fontSize: AppTypography.badgeSize,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w600,
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

class _ReferenceStylePanel extends StatelessWidget {
  const _ReferenceStylePanel({required this.state, required this.onOpenProperties});
  final TgState state;
  final VoidCallback onOpenProperties;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (_, __) {
        final selected = state.selected;
        final title = _selectedTitle(selected);
        final currentWidth = _lineWidth(selected);
        return IgnorePointer(
          ignoring: false,
          child: Container(
            width: 188,
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height - 126),
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.98),
              borderRadius: BorderRadius.circular(TgScreenPalette.panelRadius),
              border: Border.all(color: TgScreenPalette.borderLight.withOpacity(.70)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0B1220).withOpacity(.10),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.zero,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Выбран: $title',
                        style: const TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          color: TgScreenPalette.textPrimary,
                          fontSize: AppTypography.captionSize,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const Icon(Icons.close_rounded, size: 18.0, color: TgScreenPalette.textMuted),
                  ],
                ),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _colorDot(const Color(0xFF00A750), selected),
                      _colorDot(const Color(0xFFFACC15), selected),
                      _colorDot(const Color(0xFF38BDF8), selected),
                      _colorDot(const Color(0xFFF97316), selected),
                      _colorDot(const Color(0xFFEF334D), selected),
                      _colorDot(Colors.white, selected, outlined: true),
                      _colorDot(const Color(0xFF0B1220), selected),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Толщина линии',
                  style: TextStyle(fontFamily: AppTypography.fontFamily, color: TgScreenPalette.textMuted, fontWeight: FontWeight.w700, fontSize: AppTypography.captionSize),
                ),
                Row(
                  children: [
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: TgScreenPalette.primaryGreen,
                          inactiveTrackColor: TgScreenPalette.borderLight,
                          thumbColor: Colors.white,
                          overlayColor: TgScreenPalette.primaryGreen.withOpacity(.12),
                        ),
                        child: Slider(
                          value: currentWidth.clamp(1.0, 12.0),
                          min: 1,
                          max: 12,
                          onChanged: (v) => _setWidth(selected, v),
                        ),
                      ),
                    ),
                    Text('${currentWidth.round()} px', style: const TextStyle(fontFamily: AppTypography.fontFamily, color: TgScreenPalette.textMuted, fontWeight: FontWeight.w800, fontSize: AppTypography.captionSize)),
                  ],
                ),
                if (selected is TgStamp) ...[
                  const SizedBox(height: 6),
                  const Text(
                    'Размер объекта',
                    style: TextStyle(fontFamily: AppTypography.fontFamily, color: TgScreenPalette.textMuted, fontWeight: FontWeight.w700, fontSize: AppTypography.captionSize),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: TgScreenPalette.primaryGreen,
                            inactiveTrackColor: TgScreenPalette.borderLight,
                            thumbColor: Colors.white,
                            overlayColor: TgScreenPalette.primaryGreen.withOpacity(.12),
                          ),
                          child: Slider(
                            value: selected.size.clamp(20.0, 260.0).toDouble(),
                            min: 20,
                            max: 260,
                            onChanged: (v) => state.updateSelectedStamp(size: v),
                          ),
                        ),
                      ),
                      Text('${selected.size.round()}', style: const TextStyle(fontFamily: AppTypography.fontFamily, color: TgScreenPalette.textMuted, fontWeight: FontWeight.w800, fontSize: AppTypography.captionSize)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Поворот',
                    style: TextStyle(fontFamily: AppTypography.fontFamily, color: TgScreenPalette.textMuted, fontWeight: FontWeight.w700, fontSize: AppTypography.captionSize),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: TgScreenPalette.primaryGreen,
                            inactiveTrackColor: TgScreenPalette.borderLight,
                            thumbColor: Colors.white,
                          ),
                          child: Slider(
                            value: selected.rotation.clamp(-3.14159, 3.14159).toDouble(),
                            min: -3.14159,
                            max: 3.14159,
                            onChanged: (v) => state.updateSelectedStamp(rotation: v),
                          ),
                        ),
                      ),
                      Text('${(selected.rotation * 180 / math.pi).round()}°', style: const TextStyle(fontFamily: AppTypography.fontFamily, color: TgScreenPalette.textMuted, fontWeight: FontWeight.w800, fontSize: AppTypography.captionSize)),
                    ],
                  ),
                ],
                const SizedBox(height: 6),
                const Text(
                  'Стиль линии',
                  style: TextStyle(fontFamily: AppTypography.fontFamily, color: TgScreenPalette.textMuted, fontWeight: FontWeight.w700, fontSize: AppTypography.captionSize),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 34,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(
                    color: TgScreenPalette.surfaceLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: TgScreenPalette.borderLight),
                  ),
                  child: Row(
                    children: [
                      _lineStyleButton('—', LineKind.normal, selected),
                      _lineStyleButton('···', LineKind.dotted, selected),
                      _lineStyleButton('- -', LineKind.dashed, selected),
                      _arrowButton(selected),
                    ],
                  ),
                ),
                if (_canEditPoints(selected)) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _panelAction(
                          Icons.tune_rounded,
                          'Ред. точки',
                          TgScreenPalette.primaryGreen,
                          () => _editPoints(selected),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _panelAction(
                          Icons.check_circle_outline_rounded,
                          'Готово',
                          TgScreenPalette.textSecondary,
                          state.finishEditPoints,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _panelAction(Icons.delete_outline_rounded, 'Удалить', const Color(0xFFE11D48), state.deleteSelected),
                    _panelAction(Icons.copy_rounded, 'Копия', TgScreenPalette.textSecondary, state.duplicateSelected),
                    _panelAction(Icons.tune_rounded, 'Свойства', TgScreenPalette.primaryGreen, onOpenProperties),
                  ],
                ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _selectedTitle(TgElement? e) {
    if (e == null) return 'ничего не выбрано';
    if (e is TgLine) return 'линия';
    if (e is TgCurve) return 'кривая';
    if (e is TgWavy) return 'волна';
    if (e is TgZigzag) return 'зигзаг';
    if (e is TgSpring) return 'пружина';
    if (e is TgStamp) return e.asset.startsWith('sportoteka://player-avatar') ? 'игрок' : 'объект';
    if (e is TgText) return 'текст';
    return 'зона';
  }

  double _lineWidth(TgElement? e) {
    if (e is TgLine) return e.width;
    if (e is TgCurve) return e.width;
    if (e is TgWavy) return e.width;
    if (e is TgZigzag) return e.width;
    if (e is TgSpring) return e.width;
    if (e is TgRect) return e.borderWidth;
    if (e is TgCircle) return e.borderWidth;
    return 3;
  }

  Widget _colorDot(Color color, TgElement? selected, {bool outlined = false}) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        onTap: () => _setColor(selected, color),
        borderRadius: BorderRadius.circular(99),
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: outlined ? TgScreenPalette.borderLight : Colors.white,
              width: outlined ? 1.5 : 3,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.07),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _setColor(TgElement? e, Color color) {
    if (e is TgLine) state.updateSelectedLine(color: color);
    if (e is TgCurve) state.updateSelectedCurve(color: color);
    if (e is TgWavy) state.updateSelectedWavy(color: color);
    if (e is TgZigzag) state.updateSelectedZigzag(color: color);
    if (e is TgSpring) state.updateSelectedSpring(color: color);
    if (e is TgRect || e is TgCircle) state.updateSelectedShape(border: color, fill: color.withOpacity(.10));
    if (e is TgText) state.updateSelectedText(color: color);
  }

  void _setWidth(TgElement? e, double width) {
    if (e is TgLine) state.updateSelectedLine(width: width);
    if (e is TgCurve) state.updateSelectedCurve(width: width);
    if (e is TgWavy) state.updateSelectedWavy(width: width);
    if (e is TgZigzag) state.updateSelectedZigzag(width: width);
    if (e is TgSpring) state.updateSelectedSpring(width: width);
    if (e is TgRect || e is TgCircle) state.updateSelectedShape(borderW: width);
  }

  Widget _lineStyleButton(String text, LineKind kind, TgElement? selected) {
    final active = _kindOf(selected) == kind;
    return Expanded(
      child: InkWell(
        onTap: () => _setKind(selected, kind),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? TgScreenPalette.primaryGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: active ? Colors.white : TgScreenPalette.textSecondary,
              fontFamily: TgScreenPalette.fontFamily,
              fontWeight: FontWeight.w800,
              fontSize: AppTypography.sectionTitleSize,
            ),
          ),
        ),
      ),
    );
  }

  LineKind _kindOf(TgElement? e) {
    if (e is TgLine) return e.kind;
    if (e is TgCurve) return e.kind;
    if (e is TgWavy) return e.kind;
    if (e is TgZigzag) return e.kind;
    if (e is TgSpring) return e.kind;
    return LineKind.normal;
  }

  void _setKind(TgElement? e, LineKind kind) {
    if (e is TgLine) state.updateSelectedLine(kind: kind);
    if (e is TgCurve) state.updateSelectedCurve(kind: kind);
    if (e is TgWavy) state.updateSelectedWavy(kind: kind);
  }

  Widget _arrowButton(TgElement? selected) {
    final active = (selected is TgLine && selected.end == LineEnd.arrow) || (selected is TgCurve && selected.end == LineEnd.arrow) || (selected is TgWavy && selected.lineEnd == LineEnd.arrow);
    return Expanded(
      child: InkWell(
        onTap: () {
          if (selected is TgLine) {
            state.updateSelectedLine(end: active ? LineEnd.none : LineEnd.arrow);
          } else if (selected is TgCurve) {
            state.updateSelectedCurve(end: LineEnd.arrow);
          } else if (selected is TgWavy) {
            state.updateSelectedWavy(lineEnd: LineEnd.arrow);
          }
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? TgScreenPalette.primaryGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.arrow_forward_rounded, size: 18.0, color: active ? Colors.white : TgScreenPalette.textSecondary),
        ),
      ),
    );
  }


  bool _canEditPoints(TgElement? e) {
    return e is TgCurve || e is TgWavy;
  }

  void _editPoints(TgElement? e) {
    if (e is TgCurve) {
      state.editSelectedCurvePoints();
      return;
    }
    if (e is TgWavy) {
      state.editWavyPoints();
    }
  }

  Widget _panelAction(IconData icon, String text, Color color, VoidCallback onTap) {
    return SizedBox(
      width: 54,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withOpacity(.18)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: AppTypography.fontFamily, color: color, fontWeight: FontWeight.w900, fontSize: AppTypography.captionSize),
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

class _ReferenceMiniMap extends StatelessWidget {
  const _ReferenceMiniMap({required this.state});
  final TgState state;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (_, __) => Container(
        width: 126,
        height: 86,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: const Color(0xFF102017).withOpacity(.90),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withOpacity(.12)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(.22), blurRadius: 24, offset: const Offset(0, 14)),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: const [
                Expanded(child: Text('RADAR', style: TextStyle(fontFamily: AppTypography.fontFamily, color: Colors.white, fontSize: AppTypography.captionSize, fontWeight: FontWeight.w800, letterSpacing: .8))),
                Icon(Icons.visibility_outlined, size: 16, color: Colors.white70),
                SizedBox(width: 10),
                Icon(Icons.lock_outline_rounded, size: 16, color: Colors.white70),
                SizedBox(width: 10),
                Icon(Icons.fullscreen_rounded, size: 16, color: Colors.white70),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: CustomPaint(
                painter: _MiniMapPainter(state.elements),
                child: const SizedBox.expand(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniMapPainter extends CustomPainter {
  _MiniMapPainter(this.elements);
  final List<TgElement> elements;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final field = rect.deflate(5);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withOpacity(.52);
    canvas.drawRRect(RRect.fromRectAndRadius(field, const Radius.circular(5)), Paint()..color = const Color(0xFF76947B));
    final stripeW = field.width / 12.0;
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(field.deflate(1), const Radius.circular(4)));
    for (var stripe = 0; stripe < 14; stripe++) {
      canvas.drawRect(
        Rect.fromLTWH(field.left + stripe * stripeW, field.top, stripeW, field.height),
        Paint()..color = stripe.isEven ? const Color(0xFF719078) : const Color(0xFF819E86),
      );
    }
    canvas.restore();
    canvas.drawRRect(RRect.fromRectAndRadius(field, const Radius.circular(5)), p);
    canvas.drawLine(Offset(field.center.dx, field.top), Offset(field.center.dx, field.bottom), p);
    canvas.drawCircle(field.center, field.height * .17, p);
    canvas.drawRect(Rect.fromLTWH(field.left, field.center.dy - field.height * .18, field.width * .12, field.height * .36), p);
    canvas.drawRect(Rect.fromLTWH(field.right - field.width * .12, field.center.dy - field.height * .18, field.width * .12, field.height * .36), p);

    int i = 0;
    for (final e in elements) {
      if (e is! TgStamp) continue;
      final uri = Uri.tryParse(e.asset);
      final team = uri?.queryParameters['team'] ?? 'home';
      final x = field.left + (e.pos.dx / 1050.0).clamp(0.0, 1.0) * field.width;
      final y = field.top + (e.pos.dy / 680.0).clamp(0.0, 1.0) * field.height;
      final color = team == 'away' ? const Color(0xFFEF334D) : const Color(0xFF20C56B);
      canvas.drawCircle(Offset(x, y), 4.6, Paint()..color = color);
      canvas.drawCircle(Offset(x, y), 4.6, (Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = Colors.white.withOpacity(.75)));
      i++;
      if (i > 40) break;
    }
  }

  @override
  bool shouldRepaint(covariant _MiniMapPainter oldDelegate) => oldDelegate.elements != elements;
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.name, required this.color});
  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    String initials() {
      final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
      String take(String value) => value.runes.take(1).map((r) => String.fromCharCode(r)).join();
      if (parts.isEmpty) return 'И';
      if (parts.length == 1) return take(parts.first).toUpperCase();
      return (take(parts.first) + take(parts.last)).toUpperCase();
    }

    return Container(
      alignment: Alignment.center,
      color: color.withOpacity(.92),
      child: Text(
        initials(),
        style: const TextStyle(fontFamily: AppTypography.fontFamily, color: Colors.white, fontWeight: FontWeight.w900, fontSize: AppTypography.sectionTitleSize),
      ),
    );
  }
}

class _TeamSideChip extends StatelessWidget {
  const _TeamSideChip({required this.label, required this.active, required this.color, required this.onTap});
  final String label;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? color.withOpacity(.10) : TgScreenPalette.surfaceLight,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: active ? color.withOpacity(.45) : TgScreenPalette.borderLight),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              color: active ? color : TgScreenPalette.textMuted,
              fontWeight: FontWeight.w900,
              fontSize: AppTypography.badgeSize,
            ),
          ),
        ),
      ),
    );
  }
}

// =======================================================
// TRAINING TEMPLATE MODELS
// =======================================================

const List<String> _trainingTemplateCategories = <String>[
  'Все',
  'Атака',
  'Оборона',
  'Прессинг',
  'Рондо',
  'Стандарты',
  'Скорость',
  'Разминка',
  'Индивидуальная',
];

final List<_TrainingTemplate> _builtInTrainingTemplates = <_TrainingTemplate>[
  _TrainingTemplate(
    id: 'builtin_rondo_5v2',
    title: 'Рондо 5v2',
    category: 'Рондо',
    description: 'Базовое владение, нейтральные и два отбирающих.',
    builtin: true,
    presetKey: 'rondo',
  ),
  _TrainingTemplate(
    id: 'builtin_build_up_433',
    title: 'Билдап 4-3-3',
    category: 'Атака',
    description: 'Выход из обороны через фланг и опорную зону.',
    builtin: true,
    presetKey: 'build_up',
  ),
  _TrainingTemplate(
    id: 'builtin_goal_kick',
    title: 'Розыгрыш от ворот',
    category: 'Атака',
    description: 'Построение атаки от вратаря с вариантами передачи.',
    builtin: true,
    presetKey: 'goal_kick',
  ),
  _TrainingTemplate(
    id: 'builtin_counter_3v2',
    title: 'Контратака 3v2',
    category: 'Атака',
    description: 'Быстрый выход после отбора и завершение.',
    builtin: true,
    presetKey: 'counter',
  ),
  _TrainingTemplate(
    id: 'builtin_pressing_4v4',
    title: 'Прессинг 4v4',
    category: 'Прессинг',
    description: 'Ловушка давления и компактность первой линии.',
    builtin: true,
    presetKey: 'pressing',
  ),
  _TrainingTemplate(
    id: 'builtin_low_block',
    title: 'Низкий блок 5-4-1',
    category: 'Оборона',
    description: 'Компактная оборона и смещение линий.',
    builtin: true,
    presetKey: 'low_block',
  ),
  _TrainingTemplate(
    id: 'builtin_speed_stations',
    title: 'Скоростные станции',
    category: 'Скорость',
    description: 'Конусы, рывки, смена направления, финишная зона.',
    builtin: true,
    presetKey: 'speed',
  ),
  _TrainingTemplate(
    id: 'builtin_corner',
    title: 'Угловой',
    category: 'Стандарты',
    description: 'Розыгрыш углового, рывки и зоны завершения.',
    builtin: true,
    presetKey: 'corner',
  ),
  _TrainingTemplate(
    id: 'builtin_free_kick',
    title: 'Штрафной',
    category: 'Стандарты',
    description: 'Стандартное положение с подачей и добиванием.',
    builtin: true,
    presetKey: 'free_kick',
  ),
  _TrainingTemplate(
    id: 'builtin_attack_steps',
    title: 'Атака 1–4',
    category: 'Атака',
    description: 'Сценарий с несколькими шагами развития атаки.',
    builtin: true,
    presetKey: 'animation_attack',
  ),
];

class _TemplateDraft {
  const _TemplateDraft({required this.title, required this.category, required this.description});
  final String title;
  final String category;
  final String description;
}


const List<String> _trainingPlanBlocks = <String>[
  'Разминка',
  'Основная часть',
  'Тактика',
  'Индивидуальная работа',
  'Завершение',
];

class _PlanExerciseDraft {
  const _PlanExerciseDraft({
    required this.title,
    required this.block,
    required this.durationMin,
    required this.playersCount,
    required this.goal,
    required this.equipment,
  });

  final String title;
  final String block;
  final int durationMin;
  final int playersCount;
  final String goal;
  final String equipment;
}

class _TrainingPlanExercise {
  const _TrainingPlanExercise({
    required this.id,
    required this.title,
    required this.block,
    required this.durationMin,
    required this.playersCount,
    required this.goal,
    required this.equipment,
    this.templateId,
    this.templateTitle,
    this.presetKey,
    this.docJson,
    this.createdAt,
  });

  final String id;
  final String title;
  final String block;
  final int durationMin;
  final int playersCount;
  final String goal;
  final String equipment;
  final String? templateId;
  final String? templateTitle;
  final String? presetKey;
  final Map<String, dynamic>? docJson;
  final DateTime? createdAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'block': block,
        'durationMin': durationMin,
        'playersCount': playersCount,
        'goal': goal,
        'equipment': equipment,
        'templateId': templateId,
        'templateTitle': templateTitle,
        'presetKey': presetKey,
        'docJson': docJson,
        'createdAt': createdAt?.toIso8601String(),
      };

  static _TrainingPlanExercise? fromJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? '').toString().trim();
    final title = (json['title'] ?? '').toString().trim();
    if (id.isEmpty || title.isEmpty) return null;
    final rawDoc = json['docJson'];
    Map<String, dynamic>? doc;
    if (rawDoc is Map<String, dynamic>) {
      doc = rawDoc;
    } else if (rawDoc is Map) {
      doc = Map<String, dynamic>.from(rawDoc);
    }
    return _TrainingPlanExercise(
      id: id,
      title: title,
      block: (json['block'] ?? 'Основная часть').toString(),
      durationMin: json['durationMin'] is int ? json['durationMin'] as int : int.tryParse('${json['durationMin'] ?? 12}') ?? 12,
      playersCount: json['playersCount'] is int ? json['playersCount'] as int : int.tryParse('${json['playersCount'] ?? 10}') ?? 10,
      goal: (json['goal'] ?? '').toString().trim().isEmpty ? 'Цель упражнения' : (json['goal'] ?? '').toString(),
      equipment: (json['equipment'] ?? '').toString().trim().isEmpty ? 'мячи, фишки, манишки' : (json['equipment'] ?? '').toString(),
      templateId: (json['templateId'] ?? '').toString().trim().isEmpty ? null : (json['templateId'] ?? '').toString(),
      templateTitle: (json['templateTitle'] ?? '').toString().trim().isEmpty ? null : (json['templateTitle'] ?? '').toString(),
      presetKey: (json['presetKey'] ?? '').toString().trim().isEmpty ? null : (json['presetKey'] ?? '').toString(),
      docJson: doc,
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()),
    );
  }

  _TrainingPlanExercise copyWith({String? id, String? title, DateTime? createdAt}) {
    return _TrainingPlanExercise(
      id: id ?? this.id,
      title: title ?? this.title,
      block: block,
      durationMin: durationMin,
      playersCount: playersCount,
      goal: goal,
      equipment: equipment,
      templateId: templateId,
      templateTitle: templateTitle,
      presetKey: presetKey,
      docJson: docJson == null ? null : Map<String, dynamic>.from(docJson!),
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class _TrainingTemplate {
  const _TrainingTemplate({
    required this.id,
    required this.title,
    required this.category,
    required this.description,
    required this.builtin,
    this.presetKey,
    this.docJson,
    this.createdAt,
  });

  final String id;
  final String title;
  final String category;
  final String description;
  final bool builtin;
  final String? presetKey;
  final Map<String, dynamic>? docJson;
  final DateTime? createdAt;

  String get safeFileName {
    final raw = title.toLowerCase().replaceAll(RegExp(r'[^a-zа-я0-9]+', unicode: true), '_');
    return raw.replaceAll(RegExp(r'_+'), '_').replaceAll(RegExp(r'^_|_$'), '').trim().isEmpty
        ? 'training_template'
        : raw.replaceAll(RegExp(r'_+'), '_').replaceAll(RegExp(r'^_|_$'), '');
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'title': title,
        'category': category,
        'description': description,
        'builtin': builtin,
        'presetKey': presetKey,
        'docJson': docJson,
        'createdAt': createdAt?.toIso8601String(),
      };

  static _TrainingTemplate? fromJson(Map<String, dynamic> json) {
    final id = (json['id'] ?? '').toString().trim();
    final title = (json['title'] ?? '').toString().trim();
    if (id.isEmpty || title.isEmpty) return null;
    final rawDoc = json['docJson'];
    Map<String, dynamic>? doc;
    if (rawDoc is Map<String, dynamic>) {
      doc = rawDoc;
    } else if (rawDoc is Map) {
      doc = Map<String, dynamic>.from(rawDoc);
    }
    return _TrainingTemplate(
      id: id,
      title: title,
      category: (json['category'] ?? 'Атака').toString(),
      description: (json['description'] ?? '').toString(),
      builtin: json['builtin'] == true,
      presetKey: (json['presetKey'] ?? '').toString().trim().isEmpty ? null : (json['presetKey'] ?? '').toString().trim(),
      docJson: doc,
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()),
    );
  }

  _TrainingTemplate copyAsUser({required String id, required String title}) {
    return _TrainingTemplate(
      id: id,
      title: title,
      category: category,
      description: description,
      builtin: false,
      presetKey: presetKey,
      docJson: docJson == null ? null : Map<String, dynamic>.from(docJson!),
      createdAt: DateTime.now(),
    );
  }
}




class _WorkflowPanelShell extends StatelessWidget {
  const _WorkflowPanelShell({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: TgScreenPalette.borderLight),
          boxShadow: TgScreenPalette.windowShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFFFFFF), Color(0xFFF7FAF9)],
                ),
                border: Border(bottom: BorderSide(color: TgScreenPalette.softLine)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: accent, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: AppTypography.fontFamily, color: TgScreenPalette.textPrimary, fontWeight: FontWeight.w900, fontSize: AppTypography.sectionTitleSize, height: 1.1)),
                        const SizedBox(height: 2),
                        Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: AppTypography.fontFamily, color: TgScreenPalette.textMuted, fontWeight: FontWeight.w600, fontSize: AppTypography.captionSize, height: 1.18)),
                      ],
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close_rounded, size: 18, color: TgScreenPalette.textMuted),
                  ),
                ],
              ),
            ),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkflowInfoBox extends StatelessWidget {
  const _WorkflowInfoBox({required this.icon, required this.title, required this.text, this.action});
  final IconData icon;
  final String title;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TgScreenPalette.lightGreen,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TgScreenPalette.primaryGreen.withOpacity(.14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: TgScreenPalette.primaryGreen, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontFamily: AppTypography.fontFamily, color: TgScreenPalette.textPrimary, fontWeight: FontWeight.w900, fontSize: AppTypography.secondarySize)),
                const SizedBox(height: 3),
                Text(text, style: const TextStyle(fontFamily: AppTypography.fontFamily, color: TgScreenPalette.textSecondary, fontWeight: FontWeight.w600, fontSize: AppTypography.captionSize, height: 1.25)),
                if (action != null) ...[
                  const SizedBox(height: 9),
                  Align(alignment: Alignment.centerLeft, child: action!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkflowInfoCard extends StatelessWidget {
  const _WorkflowInfoCard({required this.icon, required this.title, required this.text});
  final IconData icon;
  final String title;
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TgScreenPalette.lightGreen,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: TgScreenPalette.primaryGreen.withOpacity(.14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: TgScreenPalette.primaryGreen, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontFamily: AppTypography.fontFamily, color: TgScreenPalette.textPrimary, fontWeight: FontWeight.w900, fontSize: AppTypography.secondarySize)),
                const SizedBox(height: 3),
                Text(text, style: const TextStyle(fontFamily: AppTypography.fontFamily, color: TgScreenPalette.textSecondary, fontWeight: FontWeight.w600, fontSize: AppTypography.captionSize, height: 1.25)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrainingWorkflowStatusStrip extends StatelessWidget {
  const _TrainingWorkflowStatusStrip({
    required this.calendarMeta,
    required this.attendanceMeta,
    required this.executionMeta,
    required this.trackerMeta,
    required this.totalMinutes,
    required this.exercisesCount,
  });

  final Map<String, dynamic> calendarMeta;
  final Map<String, dynamic> attendanceMeta;
  final Map<String, dynamic> executionMeta;
  final Map<String, dynamic> trackerMeta;
  final int totalMinutes;
  final int exercisesCount;

  @override
  Widget build(BuildContext context) {
    final date = (calendarMeta['date'] ?? '').toString();
    final time = (calendarMeta['time'] ?? '').toString();
    final present = (attendanceMeta['present'] ?? '-').toString();
    final expected = (attendanceMeta['expected'] ?? '-').toString();
    final completed = executionMeta['completedExerciseIds'] is List ? (executionMeta['completedExerciseIds'] as List).length : 0;
    final trackerSession = (trackerMeta['session_id'] ?? '').toString();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _WorkflowChip(icon: Icons.timer_outlined, label: '$totalMinutes мин • $exercisesCount упр.'),
        _WorkflowChip(icon: Icons.calendar_month_rounded, label: date.isEmpty ? 'календарь не задан' : '$date $time', active: date.isNotEmpty),
        _WorkflowChip(icon: Icons.groups_rounded, label: 'посещаемость $present/$expected', active: present != '-'),
        _WorkflowChip(icon: Icons.fact_check_outlined, label: 'выполнено $completed/$exercisesCount', active: completed > 0),
        _WorkflowChip(icon: Icons.sensors_rounded, label: trackerSession.isEmpty ? 'трекер не связан' : 'трекер #$trackerSession', active: trackerSession.isNotEmpty),
      ],
    );
  }
}

class _WorkflowChip extends StatelessWidget {
  const _WorkflowChip({required this.icon, required this.label, this.active = false});
  final IconData icon;
  final String label;
  final bool active;
  @override
  Widget build(BuildContext context) {
    final color = active ? TgScreenPalette.primaryGreen : TgScreenPalette.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: active ? TgScreenPalette.lightGreen : TgScreenPalette.surfaceLight,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: active ? TgScreenPalette.primaryGreen.withOpacity(.25) : TgScreenPalette.borderLight),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontFamily: AppTypography.fontFamily, color: color, fontWeight: FontWeight.w800, fontSize: AppTypography.captionSize)),
        ],
      ),
    );
  }
}

class _TrainingPlanExerciseCard extends StatelessWidget {
  const _TrainingPlanExerciseCard({
    required this.exercise,
    required this.index,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onOpen,
    required this.onDuplicate,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final _TrainingPlanExercise exercise;
  final int index;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onOpen;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: TgScreenPalette.surfaceLight,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: TgScreenPalette.borderLight),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: TgScreenPalette.lightGreen,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(fontFamily: AppTypography.fontFamily, color: TgScreenPalette.primaryGreen, fontWeight: FontWeight.w900, fontSize: AppTypography.secondarySize),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: AppTypography.fontFamily, color: TgScreenPalette.textPrimary, fontWeight: FontWeight.w900, fontSize: AppTypography.bodySize),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${exercise.durationMin} мин • ${exercise.playersCount} игроков • ${exercise.equipment}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: AppTypography.fontFamily, color: TgScreenPalette.textMuted, fontWeight: FontWeight.w700, fontSize: AppTypography.captionSize),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      exercise.goal,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: AppTypography.fontFamily, color: TgScreenPalette.textSecondary, fontWeight: FontWeight.w600, fontSize: AppTypography.captionSize, height: 1.18),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _MiniTemplateAction(icon: Icons.open_in_new_rounded, tooltip: 'Открыть', onTap: onOpen),
              _MiniTemplateAction(icon: Icons.arrow_upward_rounded, tooltip: 'Выше', onTap: canMoveUp ? onMoveUp : null),
              _MiniTemplateAction(icon: Icons.arrow_downward_rounded, tooltip: 'Ниже', onTap: canMoveDown ? onMoveDown : null),
              _MiniTemplateAction(icon: Icons.copy_rounded, tooltip: 'Дублировать', onTap: onDuplicate),
              _MiniTemplateAction(icon: Icons.delete_outline_rounded, tooltip: 'Удалить', onTap: onDelete, danger: true),
            ],
          ),
        ),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.onOpen,
    required this.onDuplicate,
    required this.onExport,
    required this.onAddToPlan,
    this.onDelete,
  });

  final _TrainingTemplate template;
  final VoidCallback onOpen;
  final VoidCallback onDuplicate;
  final VoidCallback onExport;
  final VoidCallback onAddToPlan;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final icon = _iconForCategory(template.category);
    final accent = template.builtin ? TgScreenPalette.primaryGreen : TgScreenPalette.info;
    return Material(
      color: TgScreenPalette.surfaceLight,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: TgScreenPalette.borderLight),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withOpacity(.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: 20),
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
                            template.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              color: TgScreenPalette.textPrimary,
                              fontWeight: FontWeight.w900,
                              fontSize: AppTypography.bodySize,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: template.builtin ? TgScreenPalette.lightGreen : const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            template.builtin ? 'база' : 'мой',
                            style: TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              color: accent,
                              fontWeight: FontWeight.w900,
                              fontSize: AppTypography.badgeSize,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${template.category} • ${template.description}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        color: TgScreenPalette.textMuted,
                        fontWeight: FontWeight.w600,
                        fontSize: AppTypography.captionSize,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _MiniTemplateAction(icon: Icons.open_in_new_rounded, tooltip: 'Открыть', onTap: onOpen),
              _MiniTemplateAction(icon: Icons.playlist_add_rounded, tooltip: 'В план', onTap: onAddToPlan),
              _MiniTemplateAction(icon: Icons.copy_rounded, tooltip: 'Дублировать', onTap: onDuplicate),
              _MiniTemplateAction(icon: Icons.file_download_outlined, tooltip: 'Экспорт JSON', onTap: onExport),
              if (onDelete != null)
                _MiniTemplateAction(icon: Icons.delete_outline_rounded, tooltip: 'Удалить', onTap: onDelete, danger: true),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForCategory(String category) {
    switch (category) {
      case 'Атака':
        return Icons.trending_up_rounded;
      case 'Оборона':
        return Icons.shield_outlined;
      case 'Прессинг':
        return Icons.radar_rounded;
      case 'Рондо':
        return Icons.radio_button_checked_rounded;
      case 'Стандарты':
        return Icons.flag_rounded;
      case 'Скорость':
        return Icons.speed_rounded;
      case 'Разминка':
        return Icons.local_fire_department_outlined;
      case 'Индивидуальная':
        return Icons.person_pin_circle_outlined;
      default:
        return Icons.bookmark_rounded;
    }
  }
}

class _MiniTemplateAction extends StatelessWidget {
  const _MiniTemplateAction({required this.icon, required this.tooltip, required this.onTap, this.danger = false});
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 16,
            color: danger ? TgScreenPalette.error : TgScreenPalette.textSecondary,
          ),
        ),
      ),
    );
  }
}

// =======================================================
// TOP BAR
// =======================================================

class _TopTitleBar extends StatelessWidget {
  final String title;
  final String folderTitle;
  final VoidCallback onBack;
  final VoidCallback? onFit;
  final VoidCallback onPickFolder;
  final VoidCallback? onSave;
  final VoidCallback? onTogglePanel;
  final VoidCallback? onExport;
  final VoidCallback? onTemplates;
  final VoidCallback? onTrainingPlan;
  final bool isPanelExpanded;
  final bool isPanelCollapsed;
  final bool selectMode;
  final int selectedCount;
  final VoidCallback? onAttach;
  final bool saving;
  final int clubId;
  final String clubName;
  final int teamId;
  final String teamName;
  final List<Map<String, dynamic>> players3d;
  final bool loadingPlayers3d;
  final TgState? state;

  const _TopTitleBar({
    required this.title,
    required this.folderTitle,
    required this.onBack,
    required this.onFit,
    required this.onPickFolder,
    required this.onSave,
    required this.onTogglePanel,
    required this.onExport,
    required this.onTemplates,
    required this.onTrainingPlan,
    required this.isPanelExpanded,
    required this.isPanelCollapsed,
    required this.selectMode,
    required this.selectedCount,
    required this.onAttach,
    required this.saving,
    this.clubId = 0,
    this.clubName = '',
    this.teamId = 0,
    this.teamName = '',
    this.players3d = const <Map<String, dynamic>>[],
    this.loadingPlayers3d = false,
    this.state,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = selectMode
        ? folderTitle
        : 'Схема • ${teamName.isNotEmpty ? teamName : title}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 3, 5, 0),
      child: Container(
        height: TgScreenPalette.topBarHeight,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: const BoxDecoration(
          color: Colors.transparent,
          border: Border(bottom: BorderSide(color: TgScreenPalette.softLine)),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: TgScreenPalette.lightGreen,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.sports_soccer_rounded, color: TgScreenPalette.primaryGreen, size: 16),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectMode ? title : 'Тренировки',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: TgScreenPalette.textPrimary,
                      fontFamily: TgScreenPalette.fontFamily,
                      fontWeight: FontWeight.w700,
                      fontSize: AppTypography.bodySize,
                      letterSpacing: -.45,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: TgScreenPalette.textMuted,
                      fontFamily: TgScreenPalette.fontFamily,
                      fontWeight: FontWeight.w600,
                      fontSize: AppTypography.badgeSize,
                    ),
                  ),
                ],
              ),
            ),
            if (!selectMode) ...[
              const SizedBox(width: 4),
              _HeaderActionButton(
                icon: Icons.event_note_outlined,
                label: 'План',
                onTap: onTrainingPlan,
                foreground: TgScreenPalette.primaryGreen,
                background: Colors.white,
                compact: true,
              ),
              const SizedBox(width: 4),
              _HeaderActionButton(
                icon: Icons.bookmarks_outlined,
                label: 'Шабл.',
                onTap: onTemplates,
                foreground: TgScreenPalette.primaryGreen,
                background: Colors.white,
                compact: true,
              ),
              const SizedBox(width: 4),
              _HeaderActionButton(
                icon: Icons.file_download_outlined,
                label: 'PNG',
                onTap: onExport,
                foreground: TgScreenPalette.primaryGreen,
                background: Colors.white,
              ),
              const SizedBox(width: 4),
              _HeaderActionButton(
                icon: Icons.folder_open_rounded,
                label: 'Папка',
                onTap: onPickFolder,
                foreground: TgScreenPalette.textSecondary,
                background: Colors.white,
                compact: true,
              ),
              const SizedBox(width: 4),
              _SaveButton(saving: saving, onTap: saving ? null : onSave),
              const SizedBox(width: 4),
              _HeaderActionButton(
                icon: Icons.close_rounded,
                label: 'Закрыть',
                onTap: onBack,
                foreground: const Color(0xFFFF3B5C),
                background: Colors.white,
                danger: true,
              ),
            ] else
              _AttachButton(count: selectedCount, onTap: selectedCount == 0 ? null : onAttach),
          ],
        ),
      ),
    );
  }

}


class _BoardModeSwitch extends StatelessWidget {
  const _BoardModeSwitch({required this.state});
  final TgState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: TgScreenPalette.buttonHeight,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: TgScreenPalette.borderLight),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _seg('3D', state.is3DMode, () {
            state.set3DParams(
              enabled: true,
              rotationX: -0.34,
              rotationY: 0.0,
              rotationZ: 0.0,
              perspective: 0.00135,
              cameraZoom: 0.96,
            );
          }),
          _seg('2D', !state.is3DMode, () {
            state.set3DParams(
              enabled: false,
              rotationX: 0.0,
              rotationY: 0.0,
              rotationZ: 0.0,
              perspective: 0.00135,
              cameraZoom: 0.96,
            );
          }),
        ],
      ),
    );
  }

  Widget _seg(String text, bool active, VoidCallback onTap) {
    return Material(
      color: active ? TgScreenPalette.lightGreen : Colors.transparent,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: 32,
          alignment: Alignment.center,
          child: Text(
            text,
            style: TextStyle(
              color: active ? TgScreenPalette.primaryGreen : TgScreenPalette.textPrimary,
              fontFamily: TgScreenPalette.fontFamily,
              fontWeight: FontWeight.w800,
              fontSize: AppTypography.badgeSize,
            ),
          ),
        ),
      ),
    );
  }
}


class _TgTrackerCameraControl extends StatelessWidget {
  const _TgTrackerCameraControl({
    required this.onOrbitDelta,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onReset,
  });

  final ValueChanged<Offset> onOrbitDelta;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TgCameraRoundButton(
              icon: Icons.add_rounded,
              tooltip: 'Приблизить',
              onTap: onZoomIn,
            ),
            const SizedBox(height: 5),
            _TgCameraRoundButton(
              icon: Icons.remove_rounded,
              tooltip: 'Отдалить',
              onTap: onZoomOut,
            ),
            const SizedBox(height: 5),
            _TgCameraRoundButton(
              icon: Icons.center_focus_strong_rounded,
              tooltip: 'Сбросить камеру',
              onTap: onReset,
              compact: true,
            ),
          ],
        ),
        const SizedBox(width: 7),
        _TgTrackerOrbitPad(onOrbitDelta: onOrbitDelta, onReset: onReset),
      ],
    );
  }
}

class _TgTrackerOrbitPad extends StatefulWidget {
  const _TgTrackerOrbitPad({
    required this.onOrbitDelta,
    required this.onReset,
  });

  final ValueChanged<Offset> onOrbitDelta;
  final VoidCallback onReset;

  @override
  State<_TgTrackerOrbitPad> createState() => _TgTrackerOrbitPadState();
}

class _TgTrackerOrbitPadState extends State<_TgTrackerOrbitPad> {
  Offset _thumb = Offset.zero;

  void _updateThumb(Offset local, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    var delta = local - center;
    const maxRadius = 20.0;
    if (delta.distance > maxRadius) {
      delta = Offset.fromDirection(delta.direction, maxRadius);
    }
    setState(() => _thumb = delta);
  }

  @override
  Widget build(BuildContext context) {
    const size = 78.0;
    return Tooltip(
      message: 'Тяните внутри круга: поворот и наклон камеры. Двойное нажатие — сброс.',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTap: widget.onReset,
        onPanStart: (details) =>
            _updateThumb(details.localPosition, const Size(size, size)),
        onPanUpdate: (details) {
          _updateThumb(details.localPosition, const Size(size, size));
          widget.onOrbitDelta(details.delta);
        },
        onPanEnd: (_) => setState(() => _thumb = Offset.zero),
        onPanCancel: () => setState(() => _thumb = Offset.zero),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.94),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFE9ECEA), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.12),
                blurRadius: 12,
                spreadRadius: -4,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Positioned(
                top: 6,
                child: Icon(Icons.keyboard_arrow_up_rounded,
                    size: 17, color: Color(0xFF5F6670)),
              ),
              const Positioned(
                bottom: 6,
                child: Icon(Icons.keyboard_arrow_down_rounded,
                    size: 17, color: Color(0xFF5F6670)),
              ),
              const Positioned(
                left: 6,
                child: Icon(Icons.keyboard_arrow_left_rounded,
                    size: 17, color: Color(0xFF5F6670)),
              ),
              const Positioned(
                right: 6,
                child: Icon(Icons.keyboard_arrow_right_rounded,
                    size: 17, color: Color(0xFF5F6670)),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 70),
                transform: Matrix4.translationValues(_thumb.dx, _thumb.dy, 0),
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: TgScreenPalette.primaryGreen,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: TgScreenPalette.primaryGreen.withOpacity(.24),
                      blurRadius: 8,
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: const Icon(Icons.open_with_rounded, size: 14, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TgCameraRoundButton extends StatelessWidget {
  const _TgCameraRoundButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.compact = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final side = compact ? 27.0 : 31.0;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withOpacity(.95),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: side,
            height: side,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE9ECEA), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.09),
                  blurRadius: 9,
                  spreadRadius: -4,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, size: compact ? 13 : 16, color: const Color(0xFF111827)),
          ),
        ),
      ),
    );
  }
}


class _HeaderActionButton extends StatelessWidget {
  const _HeaderActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.foreground,
    required this.background,
    this.danger = false,
    this.compact = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color foreground;
  final Color background;
  final bool danger;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final veryCompact = MediaQuery.of(context).size.width < 760;
    final hideLabel = compact || veryCompact;
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          height: TgScreenPalette.buttonHeight,
          padding: EdgeInsets.symmetric(horizontal: compact ? 7 : 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: danger ? foreground.withOpacity(.28) : TgScreenPalette.borderLight,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: foreground, size: 12.5),
              if (!hideLabel) ...[
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: foreground,
                    fontFamily: TgScreenPalette.fontFamily,
                    fontWeight: FontWeight.w700,
                    fontSize: AppTypography.badgeSize,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MacDots extends StatelessWidget {
  const _MacDots({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    Widget dot({required VoidCallback? onTap, bool close = false}) {
      final child = Container(
        width: 12,
        height: 12,
        margin: const EdgeInsets.only(right: 7),
        decoration: BoxDecoration(
          color: close ? const Color(0xFFFFE4E6) : const Color(0xFFD8DEE6),
          shape: BoxShape.circle,
          border: Border.all(
            color: close ? const Color(0xFFFB7185) : const Color(0xFFC8D0DA),
            width: .8,
          ),
        ),
        child: close
            ? const Icon(Icons.close_rounded, size: 8, color: Color(0xFFE11D48))
            : null,
      );

      return Tooltip(
        message: close ? 'Закрыть' : '',
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: child,
        ),
      );
    }

    return Row(
      children: [
        dot(onTap: onClose, close: true),
        dot(onTap: null),
        dot(onTap: null),
      ],
    );
  }
}

class _CloseEditorButton extends StatelessWidget {
  const _CloseEditorButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Закрыть редактор',
      child: Material(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFFCDD2)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.close_rounded, size: 16, color: Color(0xFFE11D48)),
                SizedBox(width: 5),
                Text(
                  'Закрыть',
                  style: TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    color: Color(0xFFE11D48),
                    fontWeight: FontWeight.w800,
                    fontSize: AppTypography.badgeSize,
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

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.saving, required this.onTap});
  final bool saving;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: TgScreenPalette.textPrimary,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          height: TgScreenPalette.buttonHeight,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          child: saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.save_rounded, color: Colors.white, size: 12.5),
                    SizedBox(width: 5),
                    Text(
                      'Сохранить',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: TgScreenPalette.fontFamily,
                        fontWeight: FontWeight.w700,
                        fontSize: AppTypography.badgeSize,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _AttachButton extends StatelessWidget {
  const _AttachButton({required this.count, required this.onTap});
  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final active = count > 0;
    return Material(
      color: active ? TgScreenPalette.primaryGreen : TgScreenPalette.surfaceHighlight,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: TgScreenPalette.buttonHeight,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          alignment: Alignment.center,
          child: Text(
            'Прикрепить ($count)',
            style: TextStyle(
              fontFamily: AppTypography.fontFamily,
              color: active ? Colors.white : TgScreenPalette.textMuted,
              fontWeight: FontWeight.w700,
              fontSize: AppTypography.badgeSize,
            ),
          ),
        ),
      ),
    );
  }
}


class _IconButton extends StatelessWidget {
  final String tooltip;
  final VoidCallback? onPressed;
  final IconData icon;
  final bool isLoading;

  const _IconButton({
    required this.tooltip,
    required this.onPressed,
    required this.icon,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: TgScreenPalette.surfaceHighlight,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 38,
              height: 38,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: TgScreenPalette.border),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: TgScreenPalette.primaryGreen,
                      ),
                    )
                  : Icon(
                      icon,
                      color: onPressed == null
                          ? TgScreenPalette.textLight
                          : TgScreenPalette.textSecondary,
                      size: 18.0,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}


class _ExportOptionTile extends StatelessWidget {
  const _ExportOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.active = false,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: active ? TgScreenPalette.lightGreen : TgScreenPalette.surfaceLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: active ? TgScreenPalette.primaryGreen.withOpacity(.24) : TgScreenPalette.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: TgScreenPalette.border),
            ),
            child: Icon(
              icon,
              size: 18.0,
              color: active ? TgScreenPalette.primaryGreen : TgScreenPalette.textSecondary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    color: TgScreenPalette.textPrimary,
                    fontSize: AppTypography.captionSize,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    color: TgScreenPalette.textMuted,
                    fontSize: AppTypography.badgeSize,
                    height: 1.25,
                    fontWeight: FontWeight.w500,
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
}

class _TgDraggablePanel extends StatelessWidget {
  final TgState state;
  final List<String> stamps;
  final bool isPhone;
  final DraggableScrollableController controller;
  final bool isPanelCollapsed;
  final VoidCallback onTogglePanel;
  final GlobalKey<TgCanvasState> canvasKey;
  final Future<void> Function(String, PlayerColors) onRefreshSvg;
  final VoidCallback? onExportPng;
  final String teamName;
  final List<Map<String, dynamic>> teamPlayers;
  final bool teamPlayersLoading;
  final String? teamPlayersError;
  final VoidCallback? onOpen3DPro;
  final TgPanel initialPanel;

  const _TgDraggablePanel({
    required this.state,
    required this.stamps,
    required this.isPhone,
    required this.controller,
    required this.isPanelCollapsed,
    required this.onTogglePanel,
    required this.canvasKey,
    required this.onRefreshSvg,
    this.onExportPng,
    this.teamName = '',
    this.teamPlayers = const <Map<String, dynamic>>[],
    this.teamPlayersLoading = false,
    this.teamPlayersError,
    this.onOpen3DPro,
    this.initialPanel = TgPanel.objects,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final micro = constraints.maxWidth < 760 || constraints.maxHeight < 560;
        final compactSide = constraints.maxWidth < 1280 || constraints.maxHeight < 820;
        // Планшет landscape получает боковую выезжающую панель, а не высокий bottom-sheet.
        final sidePanel = constraints.maxWidth >= 700 && constraints.maxWidth >= constraints.maxHeight * .78 && !isPhone;
        final contentWidth = micro
            ? math.min(286.0, math.max(220.0, constraints.maxWidth - 112.0))
            : (compactSide ? (constraints.maxWidth < 980 ? 286.0 : 322.0) : 356.0);
        final panelTop = micro ? 44.0 : (compactSide ? 54.0 : 70.0);
        final panelRight = micro ? 4.0 : (compactSide ? 8.0 : 12.0);
        final panelBottom = micro ? 4.0 : (compactSide ? 8.0 : 12.0);
        final dockReserve = micro ? 62.0 : (compactSide ? 72.0 : 88.0);
        final sideShellWidth = math.min(
          constraints.maxWidth - (micro ? 10.0 : 18.0),
          contentWidth + dockReserve,
        ).clamp(232.0, 460.0) as double;

        if (sidePanel) {
          return Stack(
            children: [
              Positioned(
                top: panelTop,
                right: panelRight,
                bottom: panelBottom,
                width: isPanelCollapsed ? (compactSide ? 54 : 70) : sideShellWidth,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: isPanelCollapsed
                      ? Align(
                          alignment: Alignment.topRight,
                          child: _PanelToggleButton(
                            isExpanded: false,
                            onTap: onTogglePanel,
                          ),
                        )
                      : TgRightPanel(
                          state: state,
                          stamps: stamps,
                          onRefreshSvg: onRefreshSvg,
                          canvasKey: canvasKey,
                          onExportPng: onExportPng,
                          teamName: teamName,
                          teamPlayers: teamPlayers,
                          teamPlayersLoading: teamPlayersLoading,
                          teamPlayersError: teamPlayersError,
                          onOpen3DPro: onOpen3DPro,
                          initialPanel: initialPanel,
                        ),
                ),
              ),
            ],
          );
        }

        final minSize = micro ? 0.18 : (isPhone ? 0.24 : 0.18);
        final initialSize = micro ? 0.30 : (isPhone ? 0.38 : 0.26);
        final maxSize = micro ? 0.46 : (isPhone ? 0.58 : 0.44);

        return Stack(
          children: [
            if (!isPanelCollapsed)
              Align(
                alignment: Alignment.bottomCenter,
                child: DraggableScrollableSheet(
                  controller: controller,
                  initialChildSize: initialSize,
                  minChildSize: minSize,
                  maxChildSize: maxSize,
                  expand: false,
                  snap: true,
                  snapSizes: [minSize, initialSize, maxSize],
                  builder: (context, scrollController) {
                    return Container(
                      margin: EdgeInsets.fromLTRB(micro ? 6 : 12, 0, micro ? 6 : 12, micro ? 6 : 12),
                      decoration: BoxDecoration(
                        color: TgScreenPalette.surface,
                        borderRadius: BorderRadius.circular(micro ? 14 : 22),
                        border: Border.all(color: TgScreenPalette.border),
                        boxShadow: TgScreenPalette.windowShadow,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(micro ? 14 : 22),
                        child: TgRightPanel(
                          state: state,
                          stamps: stamps,
                          onRefreshSvg: onRefreshSvg,
                          canvasKey: canvasKey,
                          onExportPng: onExportPng,
                          teamName: teamName,
                          teamPlayers: teamPlayers,
                          teamPlayersLoading: teamPlayersLoading,
                          teamPlayersError: teamPlayersError,
                          onOpen3DPro: onOpen3DPro,
                          initialPanel: initialPanel,
                        ),
                      ),
                    );
                  },
                ),
              ),
            Positioned(
              right: 16,
              bottom: isPanelCollapsed ? 14 : (micro ? 172 : (isPhone ? 260 : 210)),
              child: _PanelToggleButton(
                isExpanded: !isPanelCollapsed,
                onTap: onTogglePanel,
              ),
            ),
          ],
        );
      },
    );
  }
}

// Кнопка для управления панелью
class _PanelToggleButton extends StatelessWidget {
  final bool isExpanded;
  final VoidCallback onTap;

  const _PanelToggleButton({
    required this.isExpanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: isExpanded ? 'Свернуть панели' : 'Открыть панели',
      child: Material(
        color: TgScreenPalette.surface,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: TgScreenPalette.border),
              boxShadow: TgScreenPalette.softShadow,
            ),
            child: AnimatedRotation(
              duration: const Duration(milliseconds: 180),
              turns: isExpanded ? 0.5 : 0,
              child: Icon(
                isExpanded ? Icons.keyboard_arrow_down_rounded : Icons.dashboard_customize_rounded,
                color: TgScreenPalette.textSecondary,
                size: 21,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
/// ===== ЛАКОНИЧНАЯ КРУГЛАЯ КНОПКА =====
class _SimsDragHandle extends StatelessWidget {
  final bool isExpanded;
  final VoidCallback onTap;

  const _SimsDragHandle({
    required this.isExpanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF00A750),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: AnimatedRotation(
          duration: const Duration(milliseconds: 200),
          turns: isExpanded ? 0.5 : 0,
          child: const Icon(
            Icons.keyboard_arrow_up,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }
}

String _tgPlaybackInitials(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((e) => e.trim().isNotEmpty)
      .toList();
  String firstChars(String value, int count) {
    if (value.isEmpty) return '';
    return value.runes.take(count).map((r) => String.fromCharCode(r)).join();
  }
  if (parts.isEmpty) return 'P';
  if (parts.length == 1) {
    return firstChars(parts.first, 2).toUpperCase();
  }
  return (firstChars(parts.first, 1) + firstChars(parts.last, 1)).toUpperCase();
}

Color _tgPlaybackColorFromHex(String? raw, Color fallback) {
  final s = (raw ?? '').trim().replaceAll('#', '').replaceAll('0x', '');
  if (s.isEmpty) return fallback;
  final normalized = s.length == 6 ? 'FF$s' : s;
  final value = int.tryParse(normalized, radix: 16);
  if (value == null) return fallback;
  return Color(value);
}

enum _TgPlaybackSubject { player, ball, generic }

class _TgPlaybackBinding {
  const _TgPlaybackBinding({
    required this.subject,
    required this.label,
    required this.initials,
    required this.number,
    required this.color,
    required this.size,
  });

  final _TgPlaybackSubject subject;
  final String label;
  final String initials;
  final String number;
  final Color color;
  final double size;

  factory _TgPlaybackBinding.generic({required String label, required Color color}) {
    return _TgPlaybackBinding(
      subject: _TgPlaybackSubject.generic,
      label: label,
      initials: _tgPlaybackInitials(label),
      number: '',
      color: color,
      size: 20.0,
    );
  }

  factory _TgPlaybackBinding.fromStamp(TgStamp stamp, {required Color fallbackColor, required bool forceBall}) {
    final asset = stamp.asset;
    if (forceBall || asset.toLowerCase().startsWith('sportoteka://ball')) {
      return const _TgPlaybackBinding(
        subject: _TgPlaybackSubject.ball,
        label: 'Мяч',
        initials: '',
        number: '',
        color: Color(0xFF0F172A),
        size: 18.0,
      );
    }
    if (asset.startsWith('sportoteka://player-avatar')) {
      final uri = Uri.tryParse(asset);
      final name = (uri?.queryParameters['name'] ?? stamp.name ?? 'Игрок').trim();
      final number = (uri?.queryParameters['number'] ?? '').trim();
      final ring = _tgPlaybackColorFromHex(uri?.queryParameters['ring'], fallbackColor);
      return _TgPlaybackBinding(
        subject: _TgPlaybackSubject.player,
        label: name,
        initials: _tgPlaybackInitials(name),
        number: number,
        color: ring,
        size: (stamp.size.clamp(42.0, 68.0) as num).toDouble(),
      );
    }
    final name = (stamp.name ?? 'Игрок').trim();
    return _TgPlaybackBinding(
      subject: _TgPlaybackSubject.player,
      label: name,
      initials: _tgPlaybackInitials(name),
      number: '',
      color: stamp.color ?? fallbackColor,
      size: (stamp.size.clamp(42.0, 68.0) as num).toDouble(),
    );
  }
}

class _TgStepBindingInfo {
  const _TgStepBindingInfo({
    required this.routeId,
    required this.routeTitle,
    required this.subjectTitle,
    required this.isManual,
  });

  final String routeId;
  final String routeTitle;
  final String subjectTitle;
  final bool isManual;
}

class _TgPlaybackRoute {
  const _TgPlaybackRoute({
    required this.routeId,
    required this.stepIndex,
    required this.color,
    required this.binding,
    required this.startPoint,
    required this.endPoint,
    required this.manual,
    required this.pointAt,
  });

  final String routeId;
  final int stepIndex;
  final Color color;
  final _TgPlaybackBinding binding;
  final Offset startPoint;
  final Offset endPoint;
  final bool manual;
  final Offset Function(double t) pointAt;
}

class _TgPlaybackWindow extends StatelessWidget {
  const _TgPlaybackWindow({
    required this.stepLabels,
    required this.currentStep,
    required this.playing,
    required this.progress,
    required this.selectedSubjectLabel,
    required this.currentBindings,
    required this.onClose,
    required this.onTogglePlay,
    required this.onSelectStep,
    required this.onAddStep,
    required this.onDuplicateStep,
    required this.onDeleteStep,
    required this.onRenameStep,
    required this.onCaptureSubject,
    required this.onBindRoute,
    required this.onClearBinding,
    required this.onSelectBinding,
    required this.onDeleteBinding,
  });

  final List<String> stepLabels;
  final int currentStep;
  final bool playing;
  final double progress;
  final String selectedSubjectLabel;
  final List<_TgStepBindingInfo> currentBindings;
  final VoidCallback onClose;
  final VoidCallback onTogglePlay;
  final ValueChanged<int> onSelectStep;
  final VoidCallback onAddStep;
  final VoidCallback onDuplicateStep;
  final VoidCallback onDeleteStep;
  final VoidCallback onRenameStep;
  final VoidCallback onCaptureSubject;
  final VoidCallback onBindRoute;
  final VoidCallback onClearBinding;
  final ValueChanged<String> onSelectBinding;
  final ValueChanged<String> onDeleteBinding;

  @override
  Widget build(BuildContext context) {
    final safeStep = stepLabels.isEmpty
        ? 0
        : (currentStep.clamp(0, stepLabels.length - 1) as num).toInt();
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.99),
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F0B1220),
              blurRadius: 30,
              offset: Offset(0, 12),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 10),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: TgScreenPalette.lightGreen,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(
                      Icons.play_circle_outline_rounded,
                      size: 18,
                      color: TgScreenPalette.primaryGreen,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Анимация',
                          style: TextStyle(
                            fontFamily: TgScreenPalette.fontFamily,
                            fontSize: AppTypography.bodySize,
                            fontWeight: FontWeight.w800,
                            color: TgScreenPalette.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Шаги, маршруты и воспроизведение',
                          style: TextStyle(
                            fontFamily: TgScreenPalette.fontFamily,
                            fontSize: AppTypography.captionSize,
                            fontWeight: FontWeight.w500,
                            color: TgScreenPalette.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: onClose,
                    borderRadius: BorderRadius.circular(9),
                    child: const SizedBox(
                      width: 32,
                      height: 32,
                      child: Icon(Icons.close_rounded, size: 18, color: TgScreenPalette.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFF0F3F1)),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        InkWell(
                          onTap: onTogglePlay,
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: TgScreenPalette.primaryGreen,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 23,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      stepLabels.isEmpty ? 'Нет шагов' : stepLabels[safeStep],
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontFamily: TgScreenPalette.fontFamily,
                                        fontSize: AppTypography.captionSize,
                                        fontWeight: FontWeight.w700,
                                        color: TgScreenPalette.textPrimary,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    stepLabels.isEmpty ? '0 / 0' : '${safeStep + 1} / ${stepLabels.length}',
                                    style: const TextStyle(
                                      fontFamily: TgScreenPalette.fontFamily,
                                      fontSize: AppTypography.captionSize,
                                      fontWeight: FontWeight.w700,
                                      color: TgScreenPalette.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(99),
                                child: LinearProgressIndicator(
                                  value: (progress.clamp(0.0, 1.0) as num).toDouble(),
                                  minHeight: 5,
                                  backgroundColor: const Color(0xFFEFF3F6),
                                  valueColor: const AlwaysStoppedAnimation<Color>(TgScreenPalette.primaryGreen),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const _PlaybackWindowSectionLabel('ШАГИ'),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Expanded(
                          child: _PlaybackWindowAction(
                            icon: Icons.add_rounded,
                            label: 'Добавить',
                            onTap: onAddStep,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _PlaybackWindowAction(
                            icon: Icons.copy_rounded,
                            label: 'Копия',
                            onTap: onDuplicateStep,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: _PlaybackWindowAction(
                            icon: Icons.edit_outlined,
                            label: 'Переименовать',
                            onTap: onRenameStep,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _PlaybackWindowAction(
                            icon: Icons.delete_outline_rounded,
                            label: 'Удалить',
                            danger: true,
                            onTap: onDeleteStep,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (stepLabels.isEmpty)
                      const _PlaybackWindowEmpty(text: 'Добавьте первый шаг анимации')
                    else
                      ...List<Widget>.generate(stepLabels.length, (index) {
                        final active = index == safeStep;
                        return Padding(
                          padding: EdgeInsets.only(bottom: index == stepLabels.length - 1 ? 0 : 5),
                          child: InkWell(
                            onTap: () => onSelectStep(index),
                            borderRadius: BorderRadius.circular(9),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.fromLTRB(9, 7, 9, 7),
                              decoration: BoxDecoration(
                                color: active ? TgScreenPalette.lightGreen : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 23,
                                    height: 23,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: active ? TgScreenPalette.primaryGreen : Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '${index + 1}',
                                      style: TextStyle(
                                        fontFamily: TgScreenPalette.fontFamily,
                                        fontSize: AppTypography.badgeSize,
                                        fontWeight: FontWeight.w800,
                                        color: active ? Colors.white : TgScreenPalette.textMuted,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      stepLabels[index],
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontFamily: TgScreenPalette.fontFamily,
                                        fontSize: AppTypography.captionSize,
                                        fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                                        color: active ? TgScreenPalette.primaryGreenDark : TgScreenPalette.textPrimary,
                                      ),
                                    ),
                                  ),
                                  if (active)
                                    const Icon(Icons.chevron_right_rounded, size: 16, color: TgScreenPalette.primaryGreen),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    const SizedBox(height: 16),
                    const _PlaybackWindowSectionLabel('ОБЪЕКТ ДЛЯ АНИМАЦИИ'),
                    const SizedBox(height: 7),
                    Container(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.ads_click_rounded, size: 16, color: TgScreenPalette.textMuted),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              selectedSubjectLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: TgScreenPalette.fontFamily,
                                fontSize: AppTypography.secondarySize,
                                fontWeight: FontWeight.w700,
                                color: TgScreenPalette.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Expanded(
                          child: _PlaybackWindowAction(
                            icon: Icons.ads_click_rounded,
                            label: 'Взять объект',
                            onTap: onCaptureSubject,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _PlaybackWindowAction(
                            icon: Icons.link_rounded,
                            label: 'Привязать',
                            onTap: onBindRoute,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _PlaybackWindowAction(
                      icon: Icons.link_off_rounded,
                      label: 'Очистить привязку',
                      danger: true,
                      onTap: onClearBinding,
                    ),
                    const SizedBox(height: 16),
                    const _PlaybackWindowSectionLabel('МАРШРУТЫ ТЕКУЩЕГО ШАГА'),
                    const SizedBox(height: 7),
                    if (currentBindings.isEmpty)
                      const _PlaybackWindowEmpty(text: 'В этом шаге пока нет привязанных маршрутов')
                    else
                      ...currentBindings.map((item) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: InkWell(
                            onTap: () => onSelectBinding(item.routeId),
                            borderRadius: BorderRadius.circular(9),
                            child: Container(
                              padding: const EdgeInsets.fromLTRB(9, 7, 7, 7),
                              decoration: BoxDecoration(
                                color: item.isManual ? TgScreenPalette.lightGreen : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 26,
                                    height: 26,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: item.isManual ? TgScreenPalette.primaryGreen : Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      item.isManual ? Icons.link_rounded : Icons.auto_awesome_rounded,
                                      size: 14,
                                      color: item.isManual ? Colors.white : TgScreenPalette.textMuted,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.subjectTitle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontFamily: TgScreenPalette.fontFamily,
                                            fontSize: AppTypography.captionSize,
                                            fontWeight: FontWeight.w700,
                                            color: TgScreenPalette.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          item.routeTitle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontFamily: TgScreenPalette.fontFamily,
                                            fontSize: AppTypography.badgeSize,
                                            fontWeight: FontWeight.w500,
                                            color: TgScreenPalette.textMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () => onDeleteBinding(item.routeId),
                                    borderRadius: BorderRadius.circular(8),
                                    child: const Padding(
                                      padding: EdgeInsets.all(5),
                                      child: Icon(Icons.close_rounded, size: 15, color: Color(0xFFE11D48)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaybackWindowSectionLabel extends StatelessWidget {
  const _PlaybackWindowSectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontFamily: TgScreenPalette.fontFamily,
        fontSize: AppTypography.badgeSize,
        fontWeight: FontWeight.w700,
        letterSpacing: .42,
        color: TgScreenPalette.textMuted,
      ),
    );
  }
}

class _PlaybackWindowAction extends StatelessWidget {
  const _PlaybackWindowAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final fg = danger ? const Color(0xFFE11D48) : TgScreenPalette.textPrimary;
    final bg = danger ? const Color(0xFFFFF3F5) : const Color(0xFFF6F8F7);
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: fg),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: TgScreenPalette.fontFamily,
                    fontSize: AppTypography.captionSize,
                    fontWeight: FontWeight.w700,
                    color: fg,
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

class _PlaybackWindowEmpty extends StatelessWidget {
  const _PlaybackWindowEmpty({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, size: 15, color: TgScreenPalette.textMuted),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontFamily: TgScreenPalette.fontFamily,
                fontSize: AppTypography.captionSize,
                height: 1.3,
                fontWeight: FontWeight.w500,
                color: TgScreenPalette.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TgPlaybackTimelineBar extends StatelessWidget {
  const _TgPlaybackTimelineBar({
    this.compact = false,
    required this.stepLabels,
    required this.currentStep,
    required this.playing,
    required this.progress,
    required this.selectedSubjectLabel,
    required this.currentBindings,
    required this.onTogglePlay,
    required this.onSelectStep,
    required this.onAddStep,
    required this.onDuplicateStep,
    required this.onDeleteStep,
    required this.onRenameStep,
    required this.onCaptureSubject,
    required this.onBindRoute,
    required this.onClearBinding,
    required this.onSelectBinding,
    required this.onDeleteBinding,
  });

  final bool compact;
  final List<String> stepLabels;
  final int currentStep;
  final bool playing;
  final double progress;
  final String selectedSubjectLabel;
  final List<_TgStepBindingInfo> currentBindings;
  final VoidCallback onTogglePlay;
  final ValueChanged<int> onSelectStep;
  final VoidCallback onAddStep;
  final VoidCallback onDuplicateStep;
  final VoidCallback onDeleteStep;
  final VoidCallback onRenameStep;
  final VoidCallback onCaptureSubject;
  final VoidCallback onBindRoute;
  final VoidCallback onClearBinding;
  final ValueChanged<String> onSelectBinding;
  final ValueChanged<String> onDeleteBinding;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.97),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: TgScreenPalette.borderLight),
          boxShadow: const [
            BoxShadow(color: Color(0x140B1220), blurRadius: 20, offset: Offset(0, 8)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                InkWell(
                  onTap: onTogglePlay,
                  borderRadius: BorderRadius.circular(9),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(color: TgScreenPalette.primaryGreen, borderRadius: BorderRadius.circular(8)),
                    child: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 20),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: (progress.clamp(0.0, 1.0) as num).toDouble(),
                      minHeight: 5,
                      backgroundColor: const Color(0xFFEFF3F6),
                      valueColor: const AlwaysStoppedAnimation<Color>(TgScreenPalette.primaryGreen),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                _TimelineAction(icon: Icons.add_rounded, onTap: onAddStep),
                const SizedBox(width: 4),
                _TimelineAction(icon: Icons.copy_rounded, onTap: onDuplicateStep),
                const SizedBox(width: 4),
                _TimelineAction(icon: Icons.edit_outlined, onTap: onRenameStep),
                const SizedBox(width: 4),
                _TimelineAction(icon: Icons.delete_outline_rounded, danger: true, onTap: onDeleteStep),
              ],
            ),
            const SizedBox(height: 5),
            SizedBox(
              height: 31,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  Container(
                    width: 118,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: TgScreenPalette.borderLight),
                    ),
                    child: Text(
                      selectedSubjectLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: TgScreenPalette.fontFamily, fontSize: AppTypography.captionSize, fontWeight: FontWeight.w800, color: TgScreenPalette.textPrimary),
                    ),
                  ),
                  const SizedBox(width: 4),
                  _TimelineWideAction(label: 'Взять', icon: Icons.ads_click_rounded, onTap: onCaptureSubject),
                  const SizedBox(width: 4),
                  _TimelineWideAction(label: 'Привязать', icon: Icons.link_rounded, onTap: onBindRoute),
                  const SizedBox(width: 4),
                  _TimelineWideAction(label: 'Очистить', icon: Icons.link_off_rounded, onTap: onClearBinding, danger: true),
                ],
              ),
            ),
            if (currentBindings.isNotEmpty) ...[
              const SizedBox(height: 4),
              _TgStepBindingsStrip(bindings: currentBindings, compact: true, onSelect: onSelectBinding, onDelete: onDeleteBinding),
            ],
            const SizedBox(height: 5),
            SizedBox(
              height: 27,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: stepLabels.length,
                separatorBuilder: (_, __) => const SizedBox(width: 4),
                itemBuilder: (context, index) {
                  final active = index == currentStep;
                  return InkWell(
                    onTap: () => onSelectStep(index),
                    borderRadius: BorderRadius.circular(8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: active ? TgScreenPalette.primaryGreen.withOpacity(0.12) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: active ? TgScreenPalette.primaryGreen : TgScreenPalette.borderLight, width: active ? 1.6 : 1),
                      ),
                      child: Text(
                        '${index + 1}. ${stepLabels[index]}',
                        style: TextStyle(
                          fontFamily: TgScreenPalette.fontFamily,
                          fontSize: AppTypography.captionSize,
                          fontWeight: FontWeight.w800,
                          color: active ? TgScreenPalette.primaryGreenDark : TgScreenPalette.textSecondary,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TgScreenPalette.borderLight),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140B1220),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              InkWell(
                onTap: onTogglePlay,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: TgScreenPalette.primaryGreen,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                'Анимация',
                style: TextStyle(
                  fontFamily: TgScreenPalette.fontFamily,
                  fontSize: AppTypography.secondarySize,
                  fontWeight: FontWeight.w800,
                  color: TgScreenPalette.textPrimary,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: (progress.clamp(0.0, 1.0) as num).toDouble(),
                    minHeight: 5,
                    backgroundColor: const Color(0xFFEFF3F6),
                    valueColor: const AlwaysStoppedAnimation<Color>(TgScreenPalette.primaryGreen),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _TimelineAction(icon: Icons.add_rounded, onTap: onAddStep),
              const SizedBox(width: 4),
              _TimelineAction(icon: Icons.copy_rounded, onTap: onDuplicateStep),
              const SizedBox(width: 4),
              _TimelineAction(icon: Icons.edit_outlined, onTap: onRenameStep),
              const SizedBox(width: 4),
              _TimelineAction(icon: Icons.delete_outline_rounded, danger: true, onTap: onDeleteStep),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: TgScreenPalette.borderLight),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Объект для анимации',
                        style: TextStyle(fontFamily: TgScreenPalette.fontFamily, fontSize: AppTypography.badgeSize, fontWeight: FontWeight.w700, color: TgScreenPalette.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        selectedSubjectLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontFamily: TgScreenPalette.fontFamily, fontSize: AppTypography.sectionTitleSize, fontWeight: FontWeight.w800, color: TgScreenPalette.textPrimary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              _TimelineWideAction(label: 'Взять объект', icon: Icons.ads_click_rounded, onTap: onCaptureSubject),
              const SizedBox(width: 4),
              _TimelineWideAction(label: 'Привязать', icon: Icons.link_rounded, onTap: onBindRoute),
              const SizedBox(width: 4),
              _TimelineWideAction(label: 'Очистить', icon: Icons.link_off_rounded, onTap: onClearBinding, danger: true),
            ],
          ),
          const SizedBox(height: 6),
          _TgStepBindingsStrip(
            bindings: currentBindings,
            onSelect: onSelectBinding,
            onDelete: onDeleteBinding,
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 28,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, index) {
                final active = index == currentStep;
                return InkWell(
                  onTap: () => onSelectStep(index),
                  borderRadius: BorderRadius.circular(8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                    decoration: BoxDecoration(
                      color: active ? TgScreenPalette.primaryGreen.withOpacity(0.12) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: active ? TgScreenPalette.primaryGreen : TgScreenPalette.borderLight,
                        width: active ? 1.8 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: active ? TgScreenPalette.primaryGreen : Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: active ? TgScreenPalette.primaryGreen : TgScreenPalette.borderLight,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: AppTypography.badgeSize,
                              fontWeight: FontWeight.w800,
                              color: active ? Colors.white : TgScreenPalette.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          stepLabels[index],
                          style: TextStyle(
                            fontFamily: TgScreenPalette.fontFamily,
                            fontSize: AppTypography.badgeSize,
                            fontWeight: FontWeight.w700,
                            color: active ? TgScreenPalette.primaryGreenDark : TgScreenPalette.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(width: 4),
              itemCount: stepLabels.length,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineAction extends StatelessWidget {
  const _TimelineAction({required this.icon, required this.onTap, this.danger = false});

  final IconData icon;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: danger ? const Color(0xFFFFF1F2) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: danger ? const Color(0xFFFECDD3) : TgScreenPalette.borderLight),
        ),
        child: Icon(icon, size: 18.0, color: danger ? const Color(0xFFE11D48) : TgScreenPalette.textSecondary),
      ),
    );
  }
}

class _TgStepBindingsStrip extends StatelessWidget {
  const _TgStepBindingsStrip({
    required this.bindings,
    this.compact = false,
    required this.onSelect,
    required this.onDelete,
  });

  final List<_TgStepBindingInfo> bindings;
  final bool compact;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    final title = bindings.isEmpty
        ? 'В этом шаге пока нет привязанных маршрутов'
        : 'В этом шаге: ${bindings.length} маршрута';
    if (compact && bindings.isNotEmpty) {
      return Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFFBFCFD),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: TgScreenPalette.borderLight),
        ),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: bindings.length,
          separatorBuilder: (_, __) => const SizedBox(width: 5),
          itemBuilder: (context, index) {
            final item = bindings[index];
            return InkWell(
              onTap: () => onSelect(item.routeId),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 154,
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: item.isManual ? TgScreenPalette.lightGreen : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: item.isManual ? TgScreenPalette.primaryGreen.withOpacity(.35) : TgScreenPalette.borderLight),
                ),
                child: Row(
                  children: [
                    Icon(item.isManual ? Icons.link_rounded : Icons.auto_awesome_rounded, size: 13, color: item.isManual ? TgScreenPalette.primaryGreen : TgScreenPalette.textMuted),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${item.subjectTitle} · ${item.routeTitle}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontFamily: AppTypography.fontFamily, fontSize: AppTypography.captionSize, fontWeight: FontWeight.w800, color: TgScreenPalette.textPrimary),
                      ),
                    ),
                    InkWell(
                      onTap: () => onDelete(item.routeId),
                      borderRadius: BorderRadius.circular(8),
                      child: const Padding(
                        padding: EdgeInsets.all(3),
                        child: Icon(Icons.close_rounded, size: 13, color: Color(0xFFE11D48)),
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

    return Container(
      height: bindings.isEmpty ? 34 : 62,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFCFD),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: TgScreenPalette.borderLight),
      ),
      child: bindings.isEmpty
          ? Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 16, color: TgScreenPalette.textMuted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: AppTypography.fontFamily, fontSize: AppTypography.badgeSize, fontWeight: FontWeight.w700, color: TgScreenPalette.textMuted),
                  ),
                ),
              ],
            )
          : ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: bindings.length,
              separatorBuilder: (_, __) => const SizedBox(width: 4),
              itemBuilder: (context, index) {
                final item = bindings[index];
                return InkWell(
                  onTap: () => onSelect(item.routeId),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 196,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: item.isManual ? TgScreenPalette.lightGreen : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: item.isManual ? TgScreenPalette.primaryGreen.withOpacity(.35) : TgScreenPalette.borderLight),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: item.isManual ? TgScreenPalette.primaryGreen : Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: item.isManual ? TgScreenPalette.primaryGreen : TgScreenPalette.borderLight),
                          ),
                          child: Icon(item.isManual ? Icons.link_rounded : Icons.auto_awesome_rounded, size: 15, color: item.isManual ? Colors.white : TgScreenPalette.textMuted),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                item.subjectTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontFamily: AppTypography.fontFamily, fontSize: AppTypography.captionSize, fontWeight: FontWeight.w900, color: TgScreenPalette.textPrimary),
                              ),
                              Text(
                                item.routeTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontFamily: AppTypography.fontFamily, fontSize: AppTypography.badgeSize, fontWeight: FontWeight.w700, color: TgScreenPalette.textMuted),
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: () => onDelete(item.routeId),
                          borderRadius: BorderRadius.circular(10),
                          child: const Padding(
                            padding: EdgeInsets.all(5),
                            child: Icon(Icons.close_rounded, size: 16, color: Color(0xFFE11D48)),
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
}

class _TimelineWideAction extends StatelessWidget {
  const _TimelineWideAction({required this.label, required this.icon, required this.onTap, this.danger = false});

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 28,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          color: danger ? const Color(0xFFFFF1F2) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: danger ? const Color(0xFFFECDD3) : TgScreenPalette.borderLight),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: danger ? const Color(0xFFE11D48) : TgScreenPalette.textSecondary),
            const SizedBox(width: 3),
            Text(
              label,
              style: TextStyle(
                fontFamily: TgScreenPalette.fontFamily,
                fontSize: AppTypography.captionSize,
                fontWeight: FontWeight.w700,
                color: danger ? const Color(0xFFE11D48) : TgScreenPalette.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TgPlaybackOverlay extends StatelessWidget {
  const _TgPlaybackOverlay({
    required this.canvasState,
    required this.routes,
    required this.activeStep,
    required this.progress,
    required this.visible,
  });

  final TgCanvasState? canvasState;
  final List<_TgPlaybackRoute> routes;
  final int activeStep;
  final double progress;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible || canvasState == null || routes.isEmpty) return const SizedBox.shrink();
    return CustomPaint(
      painter: _TgPlaybackPainter(
        canvasState: canvasState!,
        routes: routes,
        activeStep: activeStep,
        progress: progress,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _TgPlaybackPainter extends CustomPainter {
  const _TgPlaybackPainter({
    required this.canvasState,
    required this.routes,
    required this.activeStep,
    required this.progress,
  });

  final TgCanvasState canvasState;
  final List<_TgPlaybackRoute> routes;
  final int activeStep;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final active = routes.where((e) => e.stepIndex == activeStep).toList();
    for (int i = 0; i < active.length; i++) {
      final route = active[i];
      final t = Curves.easeInOut.transform((progress.clamp(0.0, 1.0) as num).toDouble());
      final scene = route.pointAt(t);
      final pos = canvasState.sceneToViewport(scene);
      if (pos.dx < -60 || pos.dy < -60 || pos.dx > size.width + 60 || pos.dy > size.height + 60) {
        continue;
      }
      final start = canvasState.sceneToViewport(route.startPoint);
      final pathPaint = Paint()
        ..color = route.binding.color.withOpacity(0.18)
        ..strokeWidth = route.binding.subject == _TgPlaybackSubject.ball ? 3 : 4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(start, pos, pathPaint);
      switch (route.binding.subject) {
        case _TgPlaybackSubject.ball:
          _drawBall(canvas, pos);
          break;
        case _TgPlaybackSubject.player:
          _drawPlayer(canvas, pos, route.binding);
          break;
        case _TgPlaybackSubject.generic:
          _drawGeneric(canvas, pos, route.binding);
          break;
      }
    }
  }

  void _drawBall(Canvas canvas, Offset pos) {
    final shadow = Paint()
      ..color = Colors.black.withOpacity(0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(pos + const Offset(0, 7), 10, shadow);
    canvas.drawCircle(pos, 10, Paint()..color = Colors.white);
    canvas.drawCircle(pos, 10, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.8..color = const Color(0xFF0F172A));
    canvas.drawCircle(pos, 3.2, Paint()..color = const Color(0xFF0F172A));
  }

  void _drawPlayer(Canvas canvas, Offset pos, _TgPlaybackBinding binding) {
    final shadow = Paint()
      ..color = Colors.black.withOpacity(0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(pos + const Offset(0, 9), 15, shadow);
    canvas.drawCircle(pos, 14, Paint()..color = const Color(0xFFF8FAFC));
    canvas.drawCircle(pos, 14, Paint()..style = PaintingStyle.stroke..strokeWidth = 2.2..color = Colors.white.withOpacity(0.96));
    canvas.drawCircle(pos, 11.6, Paint()..color = binding.color);
    final tp = TextPainter(
      text: TextSpan(
        text: binding.number.isNotEmpty ? binding.number : binding.initials,
        style: const TextStyle(fontFamily: AppTypography.fontFamily, color: Colors.white, fontSize: AppTypography.badgeSize, fontWeight: FontWeight.w800),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
  }

  void _drawGeneric(Canvas canvas, Offset pos, _TgPlaybackBinding binding) {
    final glow = Paint()
      ..color = binding.color.withOpacity(0.24)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    canvas.drawCircle(pos, 16, glow);
    canvas.drawCircle(pos, 11, Paint()..color = binding.color.withOpacity(0.96));
    canvas.drawCircle(pos, 11, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = Colors.white.withOpacity(0.96));
  }

  @override
  bool shouldRepaint(covariant _TgPlaybackPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.activeStep != activeStep ||
        oldDelegate.routes != routes ||
        oldDelegate.canvasState != canvasState;
  }
}
