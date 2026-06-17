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
// В начале файла добавьте импорт:
import 'package:sportoteka/presentation/training_graphics/tg_models.dart';

/// ================== ЦВЕТОВАЯ ПАЛИТРА ==================
class TgScreenPalette {
  // Основной зеленый цвет (#00a750)
  static const primaryGreen = Color(0xFF00A750);
  static const primaryGreenDark = Color(0xFF008C40);
  static const primaryGreenLight = Color(0xFF00C060);
  static const lightGreen = Color(0xFFE8F5E9);

  // Фоновые цвета
  static const background = Color(0xFF121212);
  static const surfaceDark = Color(0xFF0F1012);
  static const surface = Color(0xFF1A1C1F);
  static const surfaceLight = Color(0xFF2A2A2A);
  static const surfaceHighlight = Color(0xFF2E2E2E);

  // Текст
  static const textPrimary = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFE5E7EB);
  static const textMuted = Color(0xFF9CA3AF);
  static const textLight = Color(0xFF6B7280);

  // Границы
  static const border = Color(0xFF2A2A2A);
  static const borderLight = Color(0xFF333333);

  // Статусы
  static const error = Color(0xFFEF4444);
  static const warning = Color(0xFFF59E0B);
  static const success = primaryGreen;
  static const info = Color(0xFF3B82F6);

  // Градиенты
  static const greenGradient = LinearGradient(
    colors: [primaryGreen, primaryGreenDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const darkGradient = LinearGradient(
    colors: [Color(0xFF1A1C1F), Color(0xFF0F1012)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
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
    this.height = 44,
    this.width,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    this.isOutlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null && !isLoading;

    return Material(
      color: isOutlined ? Colors.transparent : (color ?? TgScreenPalette.primaryGreen),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: isEnabled ? onPressed : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: height,
          width: width,
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
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
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: height,
          width: width,
          padding: padding,
          decoration: BoxDecoration(
            color: color ?? TgScreenPalette.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? TgScreenPalette.primaryGreen : TgScreenPalette.border,
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
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
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
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
            const SizedBox(width: 8),
            TgScreenButton(
              onPressed: onRetry,
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: const Text(
                "Повторить",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ),
          ],
          if (onDismiss != null) ...[
            const SizedBox(width: 8),
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
            borderRadius: BorderRadius.circular(16),
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
              const SizedBox(height: 16),
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

  // Panel state
  bool _isPanelExpanded = false;
  bool _isPanelCollapsed = false;

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

  static const double _topBarH = 56.0;

  @override
  void initState() {
    super.initState();

    _panelController.addListener(_onPanelMoved);

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();

    _initializeState();
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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

  void _onStateChange() {
    if (!mounted) return;

    if (!_restoringDraft) _dirty = true;
    _scheduleDraftSave();

    setState(() {});
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    _panelController.removeListener(_onPanelMoved);
    _panelController.dispose();
    state.removeListener(_onStateChange);
    state.dispose();
    _animationController.dispose();
    super.dispose();
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
    if (parsed is Map<String, dynamic>) {
      state.loadFromJson(parsed);
    } else if (parsed is Map) {
      state.loadFromJson(Map<String, dynamic>.from(parsed));
    }

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
  // ==========================
  // Fit field
  // ==========================
  void _fitField() {
    if (!mounted) return;

    final rb = _rightPaneKey.currentContext?.findRenderObject();
    final full = (rb is RenderBox) ? rb.size : MediaQuery.of(context).size;

    final safeBottom = MediaQuery.of(context).padding.bottom;

    // ✅ учитываем только TopTitleBar (верхний бар)
    final viewportH = (full.height - _topBarH - safeBottom).clamp(1.0, 200000.0);
    final viewportW = (full.width * 1.00).clamp(1.0, 200000.0);

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
              const SizedBox(height: 16),
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
            const SizedBox(height: 16),
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
                          fontSize: 12,
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
        child: Row(
          children: [
            // ✅ СЛЕВА ОСТАВЛЯЕМ
            TgLeftToolbar(
              state: state,
              onZoomToSelection: () => _canvasKey.currentState?.zoomToSelection(),
              onResetView: () => _canvasKey.currentState?.resetView(),
            ),

            Expanded(
              key: _rightPaneKey,
              child: ClipRect(
                child: Stack(
                  children: [
                    // Canvas area
                    Positioned.fill(
                      child: LayoutBuilder(
                        builder: (context, c) {
                          final safeBottom = MediaQuery.of(context).padding.bottom;
                          final bottomPad = safeBottom;

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
                          return Padding(
                            padding: EdgeInsets.only(
                              top: _topBarH, // ✅ только верхний TopTitleBar
                              bottom: bottomPad,
                            ),
                            child: RepaintBoundary(
                              key: _repaintKey,
                              child: TgCanvas(
                                key: _canvasKey,
                                state: state,
                                onRequestEditSelected: () {},
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // Top title bar
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
                        isPanelExpanded: _isPanelExpanded,
                        isPanelCollapsed: _isPanelCollapsed,
                        selectMode: false,
                        selectedCount: 0,
                        onAttach: null,
                        saving: saving,
                      ),
                    ),

                    // Loading overlay
                    if (_docLoading)
                      const Positioned.fill(
                        child: TgScreenLoadingOverlay(
                          message: "Загрузка схемы...",
                        ),
                      ),

                    // Error overlay
                    if (_docError != null && !_docLoading)
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: (_isPhone ? 140 : 20),
                        child: TgScreenErrorBanner(
                          message: _docError!,
                          onRetry: (graphicId == null || graphicId! <= 0)
                              ? null
                              : () => _loadDocById(graphicId!),
                          onDismiss: () => setState(() => _docError = null),
                        ),
                      ),

                    // ✅ Bottom draggable panel (ЗДЕСЬ ТЕПЕРЬ ВСЁ РЕДАКТИРОВАНИЕ)
                    // ✅ Панель (если свернута — не строим лист, только кнопку внутри панели)
// Найдите этот код и убедитесь, что onRefreshSvg передан:
_TgDraggablePanel(
  state: state,
  stamps: stamps,
  isPhone: _isPhone,
  controller: _panelController,
  isPanelCollapsed: _isPanelCollapsed,
  onTogglePanel: _togglePanel,
  canvasKey: _canvasKey,
  onRefreshSvg: _refreshSvg,
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
  final bool isPanelExpanded;
  final bool isPanelCollapsed;
  final bool selectMode;
  final int selectedCount;
  final VoidCallback? onAttach;
  final bool saving;

  const _TopTitleBar({
    required this.title,
    required this.folderTitle,
    required this.onBack,
    required this.onFit,
    required this.onPickFolder,
    required this.onSave,
    required this.onTogglePanel,
    required this.isPanelExpanded,
    required this.isPanelCollapsed,
    required this.selectMode,
    required this.selectedCount,
    required this.onAttach,
    required this.saving,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: TgScreenPalette.surfaceDark,
        border: Border(
          bottom: BorderSide(
            color: TgScreenPalette.border.withOpacity(0.3),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onBack,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(8),
                child: const Icon(
                  Icons.arrow_back_rounded,
                  color: TgScreenPalette.textSecondary,
                  size: 20,
                ),
              ),
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
                  style: const TextStyle(
                    color: TgScreenPalette.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  folderTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: TgScreenPalette.textMuted,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          if (onTogglePanel != null) ...[
            _IconButton(
              tooltip: isPanelExpanded ? "Свернуть панель" : "Развернуть панель",
              onPressed: onTogglePanel,
              icon: isPanelExpanded
                  ? Icons.keyboard_arrow_down_rounded
                  : Icons.keyboard_arrow_up_rounded,
            ),
          ],

          if (onFit != null)
            _IconButton(
              tooltip: "Вписать поле",
              onPressed: onFit!,
              icon: Icons.fit_screen_rounded,
            ),

          _IconButton(
            tooltip: "Выбрать папку",
            onPressed: onPickFolder,
            icon: Icons.folder_open_rounded,
          ),

          const SizedBox(width: 4),

          if (selectMode) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: selectedCount > 0
                    ? TgScreenPalette.primaryGreen.withOpacity(0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selectedCount > 0
                      ? TgScreenPalette.primaryGreen
                      : TgScreenPalette.border,
                ),
              ),
              child: InkWell(
                onTap: (selectedCount == 0) ? null : onAttach,
                borderRadius: BorderRadius.circular(20),
                child: Text(
                  "Прикрепить ($selectedCount)",
                  style: TextStyle(
                    color: selectedCount > 0
                        ? TgScreenPalette.primaryGreen
                        : TgScreenPalette.textMuted,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ] else ...[
            _IconButton(
              tooltip: saving ? "Сохранение..." : "Сохранить",
              onPressed: saving ? null : onSave,
              icon: Icons.save_rounded,
              isLoading: saving,
            ),
          ],
        ],
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
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 40,
              height: 40,
              padding: const EdgeInsets.all(8),
              child: isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: TgScreenPalette.primaryGreen,
                      ),
                    )
                  : Icon(
                      icon,
                      color: onPressed == null
                          ? TgScreenPalette.textMuted.withOpacity(0.3)
                          : TgScreenPalette.textSecondary,
                      size: 20,
                    ),
            ),
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

  const _TgDraggablePanel({
    required this.state,
    required this.stamps,
    required this.isPhone,
    required this.controller,
    required this.isPanelCollapsed,
    required this.onTogglePanel,
    required this.canvasKey,
    required this.onRefreshSvg,
  });

  @override
  Widget build(BuildContext context) {
    final minSize = isPhone ? 0.30 : 0.24;
    final initialSize = isPhone ? 0.42 : 0.34;
    final maxSize = isPhone ? 0.70 : 0.60;

    return Stack(
      children: [
        // ✅ Когда панель свернута — вообще не перекрываем поле
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
                return TgRightPanel(
                  state: state,
                  stamps: stamps,
                  onRefreshSvg: onRefreshSvg,
                  canvasKey: canvasKey,
                );
              },
            ),
          ),

        // ✅ В свернутом виде — только маленькая кнопка
        if (isPanelCollapsed)
          Positioned(
            right: 16,
            bottom: 18,
            child: _PanelToggleButton(
              isExpanded: false,
              onTap: onTogglePanel,
            ),
          ),

        // ✅ В открытом виде — кнопка закрытия над панелью
        if (!isPanelCollapsed)
          Positioned(
            right: 16,
            bottom: isPhone ? 320 : 260,
            child: _PanelToggleButton(
              isExpanded: true,
              onTap: onTogglePanel,
            ),
          ),
      ],
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: TgScreenPalette.primaryGreen,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
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
            size: 24,
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