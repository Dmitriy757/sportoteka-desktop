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

import 'training_graphics_state.dart';
import 'widgets/tg_canvas.dart';
import 'widgets/tg_left_toolbar.dart';


import 'package:sportoteka/core/utils/pref_utils.dart';
import 'package:sportoteka/presentation/plans/plan_folders_screen.dart';
import 'package:sportoteka/presentation/plans/api/training_graphics_api.dart';
import 'package:sportoteka/presentation/training_graphics/widgets/tg_right_panel.dart';
import 'package:sportoteka/presentation/training_graphics/tg_models.dart';
import 'package:sportoteka/presentation/sportoteka_3d_pro/sportoteka_3d_pro_launcher.dart';

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
                color: TgScreenPalette.textSecondary,
                fontWeight: FontWeight.w500,
                fontSize: 13,
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
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 8.4,
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
                  color: TgScreenPalette.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
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
  final GlobalKey<TgCanvasState> _canvasKey = GlobalKey<TgCanvasState>();
  final GlobalKey _rightPaneKey = GlobalKey();

  final DraggableScrollableController _panelController = DraggableScrollableController();
  late final AnimationController _animationController;
  Timer? _playbackTimer;
  bool _playbackRunning = false;
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

  // Panel state
  bool _isPanelExpanded = false;
  bool _isPanelCollapsed = true;
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
      final jsonStr = jsonEncode(state.toJson());
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
                color: TgScreenPalette.textPrimary,
                fontWeight: FontWeight.w900,
              ),
            ),
            content: const Text(
              "Восстановить последнюю несохранённую версию схемы?",
              style: TextStyle(
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
        state.loadFromJson(Map<String, dynamic>.from(parsed));
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
            color: TgScreenPalette.textPrimary,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: const Text(
          "Сохранить изменения перед выходом?",
          style: TextStyle(
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

  state.set3DParams(
    enabled: false,
    rotationX: 0.0,
    rotationY: 0.0,
    rotationZ: 0.0,
    perspective: 0.0008,
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
  bool get _isPhone => MediaQuery.of(context).size.width < 900;

  int _asInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is num) return v.toInt();
    return int.tryParse((v ?? "").toString()) ?? 0;
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
  });

  if (_isPanelExpanded) {
    _panelController.animateTo(
      _panelMaxFrac,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }
}

  void _openLegacyPanel(TgPanel panel) {
    setState(() {
      _legacyPanelInitial = panel;
      _isPanelExpanded = true;
      _isPanelCollapsed = false;
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
    });
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
                          Text('TacticalPad функции', style: TextStyle(color: TgScreenPalette.textPrimary, fontSize: 16, fontWeight: FontWeight.w900)),
                          SizedBox(height: 2),
                          Text('Пресеты добавляются на поле и попадают в слои', style: TextStyle(color: TgScreenPalette.textMuted, fontSize: 8.4, fontWeight: FontWeight.w600)),
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
                  style: TextStyle(color: TgScreenPalette.textMuted, fontSize: 11.5, height: 1.35, fontWeight: FontWeight.w600),
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
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: TgScreenPalette.textPrimary, fontSize: 13, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: TgScreenPalette.textMuted, fontSize: 8.4, fontWeight: FontWeight.w700)),
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
    try {
      final boundary = _repaintKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;
      return byteData.buffer.asUint8List();
    } catch (_) {
      return null;
    }
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
                          Text('Экспорт FIFA / TV графики', style: TextStyle(color: TgScreenPalette.textPrimary, fontSize: 15, fontWeight: FontWeight.w900)),
                          SizedBox(height: 2),
                          Text('PNG собирается из текущего кадра. Для Unity/3D нужен экспорт сцены в JSON/GLB pipeline.', style: TextStyle(color: TgScreenPalette.textMuted, fontSize: 11.5, height: 1.25, fontWeight: FontWeight.w500)),
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
                  title: 'PNG кадр',
                  subtitle: png == null
                      ? 'Не удалось собрать кадр — попробуйте ещё раз после загрузки поля'
                      : 'Кадр собран: ${(png.lengthInBytes / 1024).toStringAsFixed(0)} KB. Следующий шаг — сохранить в файл/галерею.',
                  active: png != null,
                ),
                const SizedBox(height: 8),
                const _ExportOptionTile(
                  icon: Icons.view_in_ar_rounded,
                  title: 'Unity Scene JSON',
                  subtitle: 'Координаты поля, объекты, слои, камера и ссылки на 3D-модели для Unity-модуля.',
                ),
                const SizedBox(height: 8),
                const _ExportOptionTile(
                  icon: Icons.code_rounded,
                  title: 'GLB / glTF пакет',
                  subtitle: 'Формат для 3D-объектов: игроки, мяч, стрелки, зоны, материалы и тени.',
                ),
                const SizedBox(height: 8),
                const _ExportOptionTile(
                  icon: Icons.picture_as_pdf_rounded,
                  title: 'PDF отчёт',
                  subtitle: 'Схема, список слоёв, подписи, заметки тренера и параметры эпизода.',
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==========================
  // Pick folder
  // ==========================
  Future<void> _pickFolder() async {
    final res = await Get.to<Map<String, dynamic>>(
      () => PlanFoldersScreen(
        clubId: widget.resolvedClubId,
        clubName: widget.resolvedClubName,
        teamId: widget.resolvedTeamId,
        selectMode: true,
      ),
    );

    if (res == null) return;

    final id = res["id"];
    final title = (res["title"] ?? "").toString();

    setState(() {
      folderId = (id is int) ? id : int.tryParse(id.toString()) ?? 0;
      folderTitle = title.trim().isNotEmpty ? title.trim() : "Папка";
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
                                  color: TgScreenPalette.textPrimary,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'После выбора нажмите на поле — появится круг с аватаркой.',
                                style: TextStyle(
                                  color: TgScreenPalette.textMuted,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 8.4,
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
                                        color: TgScreenPalette.textPrimary,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
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
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 8.4,
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
                  color: TgScreenPalette.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _listError!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: TgScreenPalette.textMuted,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 20),
              TgScreenButton(
                onPressed: _loadList,
                width: 200,
                child: const Text(
                  "Повторить",
                  style: TextStyle(
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
                color: TgScreenPalette.textMuted,
                fontSize: 16,
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
                          color: TgScreenPalette.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "ID: $id",
                        style: const TextStyle(
                          fontSize: 8.4,
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
            final desktop = root.maxWidth >= 1040;
            return Container(
              color: TgScreenPalette.background,
              child: Row(
                children: [
                  TgLeftToolbar(
                    state: state,
                    onZoomToSelection: () => _canvasKey.currentState?.zoomToSelection(),
                    onResetView: () => _canvasKey.currentState?.resetView(),
                    onCloseEditor: _handleBack,
                    onOpenObjects: () => _openLegacyPanel(TgPanel.objects),
                    onOpenLayers: () => _openLegacyPanel(TgPanel.layers),
                    onOpenProperties: _openPropertiesPanel,
                    onOpenTactics: _openTacticalPadSheet,
                  ),
                  Expanded(
                    key: _rightPaneKey,
                    child: ClipRect(
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(desktop ? 5 : 5, 49, desktop ? 5 : 5, desktop ? 74 : 88),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: TgScreenPalette.surface,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: TgScreenPalette.borderLight.withOpacity(.48)),
                                  gradient: const LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [Color(0xFFFDFEFE), Color(0xFFF5F8FA)],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0x140B1220),
                                      blurRadius: 12,
                                      offset: Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
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
                          if (_docLoading)
                            const Positioned.fill(
                              child: TgScreenLoadingOverlay(
                                message: 'Загрузка схемы...',
                              ),
                            ),
                          if (_docError != null && !_docLoading)
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
                            bottom: desktop ? 80 : 96,
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
                          Positioned(
                            left: desktop ? 94 : 64,
                            right: desktop ? 94 : 64,
                            bottom: desktop ? 72 : 90,
                            child: Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 640),
                                child: _TgPlaybackTimelineBar(
                                  stepLabels: _playbackSteps,
                                  currentStep: _currentPlaybackStep,
                                  playing: _playbackRunning,
                                  progress: _playbackProgress,
                                  selectedSubjectLabel: _playbackSubjectLabel(),
                                  currentBindings: _playbackBindingsForCurrentStep(),
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
                            ),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
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
                          if (state.selected != null)
                            Positioned(
                              top: desktop ? 72 : 66,
                              right: desktop ? 12 : 10,
                              child: _ReferenceStylePanel(state: state, onOpenProperties: _openPropertiesPanel),
                            ),
                          Positioned(
                            right: desktop ? 12 : 10,
                            bottom: desktop ? 70 : 88,
                            child: _ReferenceMiniMap(state: state),
                          ),
                          if (_isPanelExpanded)
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
                    fontSize: 7.5,
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
            width: 205,
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
                          color: TgScreenPalette.textPrimary,
                          fontSize: 10.2,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const Icon(Icons.close_rounded, size: 18.0, color: TgScreenPalette.textMuted),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
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
                const SizedBox(height: 6),
                const Text(
                  'Толщина линии',
                  style: TextStyle(color: TgScreenPalette.textMuted, fontWeight: FontWeight.w700, fontSize: 10.2),
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
                    Text('${currentWidth.round()} px', style: const TextStyle(color: TgScreenPalette.textMuted, fontWeight: FontWeight.w800, fontSize: 10.2)),
                  ],
                ),
                if (selected is TgStamp) ...[
                  const SizedBox(height: 6),
                  const Text(
                    'Размер объекта',
                    style: TextStyle(color: TgScreenPalette.textMuted, fontWeight: FontWeight.w700, fontSize: 10.2),
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
                      Text('${selected.size.round()}', style: const TextStyle(color: TgScreenPalette.textMuted, fontWeight: FontWeight.w800, fontSize: 10.2)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Поворот',
                    style: TextStyle(color: TgScreenPalette.textMuted, fontWeight: FontWeight.w700, fontSize: 10.2),
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
                      Text('${(selected.rotation * 180 / math.pi).round()}°', style: const TextStyle(color: TgScreenPalette.textMuted, fontWeight: FontWeight.w800, fontSize: 10.2)),
                    ],
                  ),
                ],
                const SizedBox(height: 6),
                const Text(
                  'Стиль линии',
                  style: TextStyle(color: TgScreenPalette.textMuted, fontWeight: FontWeight.w700, fontSize: 10.2),
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
                Row(
                  children: [
                    Expanded(child: _panelAction(Icons.delete_outline_rounded, 'Удалить', const Color(0xFFE11D48), state.deleteSelected)),
                    const SizedBox(width: 10),
                    Expanded(child: _panelAction(Icons.copy_rounded, 'Копия', TgScreenPalette.textSecondary, state.duplicateSelected)),
                    const SizedBox(width: 10),
                    Expanded(child: _panelAction(Icons.tune_rounded, 'Свойства', TgScreenPalette.primaryGreen, onOpenProperties)),
                  ],
                ),
              ],
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
      padding: const EdgeInsets.only(right: 10),
      child: InkWell(
        onTap: () => _setColor(selected, color),
        borderRadius: BorderRadius.circular(99),
        child: Container(
          width: 34,
          height: 34,
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
              fontSize: 14,
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
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(.18)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 11)),
            ],
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
                Expanded(child: Text('RADAR', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: .8))),
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
    canvas.drawRRect(RRect.fromRectAndRadius(field, const Radius.circular(5)), Paint()..color = const Color(0xFF1D6B38));
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
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
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
              color: active ? color : TgScreenPalette.textMuted,
              fontWeight: FontWeight.w900,
              fontSize: 8.4,
            ),
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
                      fontSize: 13.2,
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
                      fontSize: 8.4,
                    ),
                  ),
                ],
              ),
            ),
            if (!selectMode && state != null)
              AnimatedBuilder(
                animation: state!,
                builder: (_, __) => _BoardModeSwitch(state: state!),
              ),
            if (!selectMode) ...[
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
              rotationX: -0.78,
              rotationY: 0.0,
              rotationZ: 0.0,
              perspective: 0.0008,
            );
          }),
          _seg('2D', !state.is3DMode, () {
            state.set3DParams(
              enabled: false,
              rotationX: 0.0,
              rotationY: 0.0,
              rotationZ: 0.0,
              perspective: 0.0008,
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
              fontSize: 8.4,
            ),
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
              if (!compact) ...[
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: foreground,
                    fontFamily: TgScreenPalette.fontFamily,
                    fontWeight: FontWeight.w700,
                    fontSize: 8.6,
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
                    color: Color(0xFFE11D48),
                    fontWeight: FontWeight.w800,
                    fontSize: 8.4,
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
                        fontSize: 8.6,
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
              color: active ? Colors.white : TgScreenPalette.textMuted,
              fontWeight: FontWeight.w700,
              fontSize: 8.4,
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
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
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
                    color: TgScreenPalette.textPrimary,
                    fontSize: 10.2,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: TgScreenPalette.textMuted,
                    fontSize: 8.4,
                    height: 1.25,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
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
        final desktop = constraints.maxWidth >= 1040 && !isPhone;

        if (desktop) {
          return Stack(
            children: [
              Positioned(
                top: 76,
                right: 14,
                bottom: 14,
                width: isPanelCollapsed ? 70 : 450,
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

        final minSize = isPhone ? 0.30 : 0.24;
        final initialSize = isPhone ? 0.42 : 0.34;
        final maxSize = isPhone ? 0.70 : 0.60;

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
                      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      decoration: BoxDecoration(
                        color: TgScreenPalette.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: TgScreenPalette.border),
                        boxShadow: TgScreenPalette.windowShadow,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
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
              bottom: isPanelCollapsed ? 18 : (isPhone ? 320 : 260),
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

class _TgPlaybackTimelineBar extends StatelessWidget {
  const _TgPlaybackTimelineBar({
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
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
                  fontSize: 11.2,
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
                        style: TextStyle(fontFamily: TgScreenPalette.fontFamily, fontSize: 8.4, fontWeight: FontWeight.w700, color: TgScreenPalette.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        selectedSubjectLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontFamily: TgScreenPalette.fontFamily, fontSize: 14, fontWeight: FontWeight.w800, color: TgScreenPalette.textPrimary),
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
                              fontSize: 8.4,
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
                            fontSize: 8.4,
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
    required this.onSelect,
    required this.onDelete,
  });

  final List<_TgStepBindingInfo> bindings;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    final title = bindings.isEmpty
        ? 'В этом шаге пока нет привязанных маршрутов'
        : 'В этом шаге: ${bindings.length} маршрута';
    return Container(
      height: bindings.isEmpty ? 34 : 54,
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
                    style: const TextStyle(fontSize: 8.4, fontWeight: FontWeight.w700, color: TgScreenPalette.textMuted),
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
                                style: const TextStyle(fontSize: 10.2, fontWeight: FontWeight.w900, color: TgScreenPalette.textPrimary),
                              ),
                              Text(
                                item.routeTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 8.4, fontWeight: FontWeight.w700, color: TgScreenPalette.textMuted),
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
        height: 29,
        padding: const EdgeInsets.symmetric(horizontal: 7),
        decoration: BoxDecoration(
          color: danger ? const Color(0xFFFFF1F2) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: danger ? const Color(0xFFFECDD3) : TgScreenPalette.borderLight),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: danger ? const Color(0xFFE11D48) : TgScreenPalette.textSecondary),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: TgScreenPalette.fontFamily,
                fontSize: 13,
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
        style: const TextStyle(color: Colors.white, fontSize: 8.4, fontWeight: FontWeight.w800),
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
