// lib/presentation/training_graphics/widgets/tg_canvas.dart
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart' show kDebugMode;

import 'package:flutter_svg/flutter_svg.dart' as fsvg;

import 'package:sportoteka/presentation/training_graphics/training_graphics_state.dart';
import 'package:sportoteka/presentation/training_graphics/tg_models.dart';

/// Чтобы GlobalKey мог вызывать методы Canvas извне:
abstract class TgCanvasStateProxy {
  void resetView();
  void zoomToSelection();
  void fitFieldToViewport(Size viewportSize);
}

class TgCanvas extends StatefulWidget {
  const TgCanvas({
    super.key,
    required this.state,
    required this.onRequestEditSelected,
  });

  final TgState state;
  final VoidCallback onRequestEditSelected;

  @override
  State<TgCanvas> createState() => TgCanvasState();
}

String _svgCacheKey(String asset, PlayerColors? pc) {
  final isSvg = asset.toLowerCase().endsWith('.svg');
  if (!isSvg) return asset;
  if (pc == null) return asset;

  final isPlayer =
      !pc.isProp &&
      (asset.contains('/run_svg/') ||
          asset.contains('/pass_svg/') ||
          asset.contains('/jump_svg/') ||
          asset.contains('/vrat_svg/') ||
          asset.contains('/stand_svg/'));

  final isProp = pc.isProp && asset.contains('/props/');
   final isGoal = asset.contains('/vorota1/');

  if (isProp) return '$asset?color=${pc.jersey.value}';
  if (isPlayer) return '$asset?j=${pc.jersey.value}&s=${pc.shorts.value}&sk=${pc.skin.value}&so=${pc.socks.value}';
   if (isGoal) return '$asset?goal'; // для ворот можно свой ключ кэша

  return asset;
}


class TgCanvasState extends State<TgCanvas>
    with SingleTickerProviderStateMixin
    implements TgCanvasStateProxy {
  TgState get state => widget.state;

  // ===== Field config =====
  static const String _fieldAsset = "assets/training/field.png";

  // ===== Viewport state (scale + translation) =====
  double _scale = 1.0;
  Offset _t = Offset.zero;
  Size _lastViewportSize = Size.zero;

  // ✅ важно: чтобы красиво вписывало поле при первом появлении
  bool _didInitialFit = false;

  // ===== Inertia (pan fling) =====
  late final AnimationController _anim = AnimationController(vsync: this);
  Simulation? _simX;
  Simulation? _simY;

  // ===== Pointer interaction =====
  Offset? _downScene;
  String? _downHitId;

  bool _draggingSelection = false;
  bool _panningViewport = false;
  bool _drawingTool = false;

  Offset _lastLocal = Offset.zero;
  int _lastTsMs = 0;
  Offset _velocity = Offset.zero; // px/s in local

  // ===== Image cache (PNG/JPG) =====
  ui.Image? _fieldImg;
  final Map<String, ui.Image> _stampCache = {};
  final Map<String, Future<ui.Image>> _stampLoading = {};

  // ===== SVG -> ui.Image cache =====
  final Map<String, ui.Image> _stampSvgAsImageCache = {};
  final Map<String, Future<ui.Image>> _stampSvgAsImageLoading = {};

  bool _isSvgAsset(String a) => a.toLowerCase().endsWith('.svg');

  // =========================================================
  // SVG -> ui.Image (рендер виджета в offscreen image)
  // =========================================================
  Future<ui.Image> _renderWidgetToImage(
    Widget widget, {
    double pixelRatio = 3.0,
    Size logicalSize = const Size(256, 256),
  }) async {
    try {
      // ВАЖНО: используем текущий View (для iOS это критично)
      final flutterView = View.of(context);

      final repaintBoundary = RenderRepaintBoundary();

      final renderView = RenderView(
        view: flutterView,
        configuration: ViewConfiguration(
          devicePixelRatio: pixelRatio,
          logicalConstraints: BoxConstraints.tight(logicalSize),
          physicalConstraints: BoxConstraints.tight(
            Size(logicalSize.width * pixelRatio, logicalSize.height * pixelRatio),
          ),
        ),
        child: RenderPositionedBox(
          alignment: Alignment.center,
          child: repaintBoundary,
        ),
      );

      final pipelineOwner = PipelineOwner();
      final buildOwner = BuildOwner(focusManager: FocusManager());

      pipelineOwner.rootNode = renderView;
      renderView.prepareInitialFrame();

      final rootElement = RenderObjectToWidgetAdapter<RenderBox>(
        container: repaintBoundary,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: logicalSize.width,
            height: logicalSize.height,
            child: ColoredBox(
              color: Colors.transparent,
              child: Center(
                child: ClipRect(child: widget),
              ),
            ),
          ),
        ),
      ).attachToRenderTree(buildOwner);

      buildOwner.buildScope(rootElement);
      buildOwner.finalizeTree();

      pipelineOwner.flushLayout();
      pipelineOwner.flushCompositingBits();
      pipelineOwner.flushPaint();

      // На реальном устройстве иногда нужно 1 кадр
      await Future.delayed(const Duration(milliseconds: 16));

      final image = await repaintBoundary.toImage(pixelRatio: pixelRatio);
      return image;
    } catch (e, st) {
      debugPrint('❌ _renderWidgetToImage error: $e');
      debugPrint('$st');
      rethrow;
    }
  }

  // =========================================================
// SVG -> ui.Image (REAL DEVICE FIX for flutter_svg 2.2.2)
// Uses VectorGraphicUtilities: fsvg.vg.loadPicture(loader, context)
// =========================================================

Future<ui.Image> _rasterizeSvgString(
  String svgString, {
  required double targetPx,
}) async {
  final loader = fsvg.SvgStringLoader(svgString);

  // ✅ ключевое: loadPicture находится в fsvg.vg
  final pictureInfo = await fsvg.vg.loadPicture(loader, context);

  final size = pictureInfo.size;
  final double w0 = (size.width <= 0) ? targetPx : size.width;
  final double h0 = (size.height <= 0) ? targetPx : size.height;

  final scale = targetPx / math.max(w0, h0);
  final int w = (w0 * scale).round().clamp(1, 4096);
  final int h = (h0 * scale).round().clamp(1, 4096);

  final ui.Image img = await pictureInfo.picture.toImage(w, h);
  pictureInfo.picture.dispose();
  return img;
}

Future<ui.Image> _loadSvgAsImage(
  String asset, {
  double targetPx = 256,
  PlayerColors? playerColors,
}) async {
  // 1) читаем svg
  final String svgString = await rootBundle.loadString(asset);

  // 2) перекраска
  String finalSvg = svgString;

  final isPlayer =
      playerColors != null &&
      !playerColors.isProp &&
      (asset.contains('/run_svg/') ||
          asset.contains('/pass_svg/') ||
          asset.contains('/jump_svg/') ||
          asset.contains('/vrat_svg/') ||
          asset.contains('/stand_svg/'));

  final isProp =
      playerColors != null &&
      playerColors.isProp &&
      asset.contains('/props/');
      
       final isGoal = asset.contains('/vorota1/');

  if (isPlayer) {
    finalSvg = _modifySvgColors(svgString, playerColors);
  } else if (isProp) {
    finalSvg = _modifyPropSvgColors(svgString, playerColors.jersey);
  }

  // 3) ✅ Правильный рендер в flutter_svg 2.x
  final loader = fsvg.SvgStringLoader(finalSvg);
  final pictureInfo = await fsvg.vg.loadPicture(loader, context);

  final pic = pictureInfo.picture;
  final sz = pictureInfo.size;

  // 4) fit в targetPx x targetPx
  final double w0 = (sz.width <= 0) ? targetPx : sz.width;
  final double h0 = (sz.height <= 0) ? targetPx : sz.height;

  final scale = (targetPx / math.max(w0, h0)).clamp(0.001, 1000.0);
  final outW = (w0 * scale).ceil().clamp(1, 4096);
  final outH = (h0 * scale).ceil().clamp(1, 4096);

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  final dx = (outW - w0 * scale) / 2.0;
  final dy = (outH - h0 * scale) / 2.0;

  canvas.translate(dx, dy);
  canvas.scale(scale, scale);
  canvas.drawPicture(pic);

  final outPicture = recorder.endRecording();
  final img = await outPicture.toImage(outW, outH);

  // чистим ресурсы
  pic.dispose();
  outPicture.dispose();

  return img;
}

  // =========================================================
  // Цвета SVG (props)
  // =========================================================
  String _modifyPropSvgColors(String svg, Color color) {
    String modified = svg;

    // inline fill
    modified = modified.replaceAllMapped(
      RegExp(r'fill="#[0-9A-F]{6}"', caseSensitive: false),
      (_) => 'fill="${_colorToCss(color)}"',
    );

    // inline stroke
    modified = modified.replaceAllMapped(
      RegExp(r'stroke="#[0-9A-F]{6}"', caseSensitive: false),
      (_) => 'stroke="${_colorToCss(color)}"',
    );

    // CSS fill in .st*
    modified = modified.replaceAllMapped(
      RegExp(r'\.st\d+\s*\{[^}]*fill:#[0-9A-F]{6}[^}]*\}', caseSensitive: false),
      (m) => m.group(0)!.replaceFirst(
        RegExp(r'#[0-9A-F]{6}', caseSensitive: false),
        _colorToCss(color),
      ),
    );

    // CSS stroke in .st*
    modified = modified.replaceAllMapped(
      RegExp(r'\.st\d+\s*\{[^}]*stroke:#[0-9A-F]{6}[^}]*\}', caseSensitive: false),
      (m) => m.group(0)!.replaceFirst(
        RegExp(r'#[0-9A-F]{6}', caseSensitive: false),
        _colorToCss(color),
      ),
    );

    return modified;
  }

  // =========================================================
  // Цвета SVG (players)
  // =========================================================
  String _modifySvgColors(String svg, PlayerColors colors) {
    String modified = svg;

    // jersey
    if (modified.contains('id="player-jersey"')) {
      final jerseyPattern = RegExp(r'id="player-jersey"\s+class="(st\d+)"');
      final match = jerseyPattern.firstMatch(modified);
      if (match != null) {
        final oldClass = match.group(1);
        modified = modified.replaceFirst(
          'id="player-jersey" class="$oldClass"',
          'id="player-jersey" style="fill:${_colorToCss(colors.jersey)};"',
        );
      }
    }

    // shorts ids
    for (final id in ['player-shorts', 'player-shorts-l', 'player-shorts-r']) {
      final key = 'id="$id"';
      if (modified.contains(key)) {
        final p = RegExp('$key\\s+class="(st\\d+)"');
        final m = p.firstMatch(modified);
        if (m != null) {
          final oldClass = m.group(1);
          modified = modified.replaceFirst(
            '$key class="$oldClass"',
            '$key style="fill:${_colorToCss(colors.shorts)};"',
          );
        }
      }
    }

    // skin parts
    for (final id in [
      'skin-face',
      'skin-leg-l',
      'skin-leg-r',
      'skin-arm-l',
      'skin-arm-r',
      'skin-neck',
    ]) {
      final key = 'id="$id"';
      if (modified.contains(key)) {
        final p = RegExp('$key\\s+class="(st\\d+)"');
        final m = p.firstMatch(modified);
        if (m != null) {
          final oldClass = m.group(1);
          modified = modified.replaceFirst(
            '$key class="$oldClass"',
            '$key style="fill:${_colorToCss(colors.skin)};"',
          );
        }
      }
    }

    // socks
    for (final id in ['player-sock-l', 'player-sock-r']) {
      final key = 'id="$id"';
      if (modified.contains(key)) {
        final p = RegExp('$key\\s+class="(st\\d+)"');
        final m = p.firstMatch(modified);
        if (m != null) {
          final oldClass = m.group(1);
          modified = modified.replaceFirst(
            '$key class="$oldClass"',
            '$key style="fill:${_colorToCss(colors.socks)};"',
          );
        }
      }
    }

    return modified;
  }

  String _colorToCss(Color color) {
    return '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
  }

  // =========================================================
  // Loading stamps (PNG)
  // =========================================================
  void _ensureStampLoaded(String asset) {
    if (_stampCache.containsKey(asset)) return;
    if (_stampLoading.containsKey(asset)) return;

    _stampLoading[asset] = _loadAssetImage(asset).then((img) {
      _stampCache[asset] = img;
      _stampLoading.remove(asset);
      if (mounted) setState(() {});
      return img;
    }).catchError((e) {
      _stampLoading.remove(asset);
      debugPrint('❌ PNG load failed: $asset -> $e');
    });
  }

  // =========================================================
  // Loading stamps (SVG or PNG)
  // =========================================================
 void _ensureStampLoadedAny(String asset, {PlayerColors? playerColors}) {
  if (_isSvgAsset(asset)) {
    final cacheKey = _svgCacheKey(asset, playerColors);

    if (_stampSvgAsImageCache.containsKey(cacheKey)) return;
    if (_stampSvgAsImageLoading.containsKey(cacheKey)) return;

    _stampSvgAsImageLoading[cacheKey] = _loadSvgAsImage(
      asset,
      targetPx: 256,
      playerColors: playerColors,
    ).then((img) {
      _stampSvgAsImageCache[cacheKey] = img;
      _stampSvgAsImageLoading.remove(cacheKey);
      if (mounted) setState(() {});
      return img;
    }).catchError((e) {
      _stampSvgAsImageLoading.remove(cacheKey);
      debugPrint('❌ SVG load failed: $asset -> $e');
    });

    return;
  }

  _ensureStampLoaded(asset);
}
  // =========================================================
  // Field asset
  // =========================================================
  Future<void> _loadField() async {
    try {
      final img = await _loadAssetImage(_fieldAsset);
      if (!mounted) return;
      setState(() => _fieldImg = img);
    } catch (e) {
      debugPrint('❌ field load failed: $_fieldAsset -> $e');
    }
  }

  Future<ui.Image> _loadAssetImage(String asset) async {
    final c = Completer<ui.Image>();
    final provider = AssetImage(asset);
    final stream = provider.resolve(const ImageConfiguration());
    late ImageStreamListener l;
    l = ImageStreamListener((info, _) {
      stream.removeListener(l);
      c.complete(info.image);
    }, onError: (e, _) {
      stream.removeListener(l);
      c.completeError(e);
    });
    stream.addListener(l);
    return c.future;
  }

  // =========================================================
  // Lifecycle
  // =========================================================
  @override
  void initState() {
    super.initState();
    _loadField();
    _pushMatrixToState();
    _anim.addListener(_onAnimTick);
  }

  @override
  void dispose() {
    _anim.removeListener(_onAnimTick);
    _anim.dispose();
    super.dispose();
  }

  bool get _locked => state.lockViewportGestures == true;

  // =========================================================
  // Public API
  // =========================================================
  @override
  void fitFieldToViewport(Size viewportSize) {
    if (viewportSize.width <= 0 || viewportSize.height <= 0) return;
    _lastViewportSize = viewportSize;

    _scale = 1.0;
    _t = Offset.zero;

    _stopInertia();
    _pushMatrixToState();

    _didInitialFit = true;
    if (mounted) setState(() {});
  }

  @override
  void resetView() {
    final sz = _lastViewportSize;
    if (sz == Size.zero) return;
    fitFieldToViewport(sz);
  }

  @override
  void zoomToSelection() {
    final sz = _lastViewportSize;
    if (sz == Size.zero) return;

    final b = state.selectionBounds();
    if (b == Rect.zero || b.width <= 0 || b.height <= 0) return;

    final target = b.inflate(70);
    const pad = 14.0;
    final vw = math.max(1.0, sz.width - pad * 2);
    final vh = math.max(1.0, sz.height - pad * 2);

    final s = math.min(vw / target.width, vh / target.height).clamp(0.25, 4.0);
    final nextScale = s.clamp(0.25, 4.0);

    final targetCenter = target.center;
    final newT = Offset(
      (sz.width / 2.0) - targetCenter.dx * nextScale,
      (sz.height / 2.0) - targetCenter.dy * nextScale,
    );

    _animateTo(nextScale, _clampTranslation(newT, nextScale, sz));
  }

  // =========================================================
  // Animation / inertia
  // =========================================================
  void _stopInertia() {
    _simX = null;
    _simY = null;
    if (_anim.isAnimating) _anim.stop();
  }

  void _animateTo(double scale, Offset t) {
    _stopInertia();

    final startScale = _scale;
    final startT = _t;

    const dur = Duration(milliseconds: 220);
    const curve = Curves.easeOutCubic;

    _anim.duration = dur;
    _anim.reset();

    void tick() {
      final u = curve.transform(_anim.value);
      _scale = ui.lerpDouble(startScale, scale, u) ?? scale;
      _t = Offset(
        ui.lerpDouble(startT.dx, t.dx, u) ?? t.dx,
        ui.lerpDouble(startT.dy, t.dy, u) ?? t.dy,
      );
      _pushMatrixToState();
      if (mounted) setState(() {});
      if (_anim.isCompleted || _anim.isDismissed) _anim.removeListener(tick);
    }

    _anim.addListener(tick);
    _anim.forward();
  }

  void _startInertia(Offset velocityPxPerSec) {
    final sz = _lastViewportSize;
    if (sz == Size.zero) return;

    if (velocityPxPerSec.distance < 120) {
      _bounceToClamp();
      return;
    }

    _stopInertia();

    _simX = FrictionSimulation(0.135, _t.dx, velocityPxPerSec.dx);
    _simY = FrictionSimulation(0.135, _t.dy, velocityPxPerSec.dy);

    _anim.duration = const Duration(milliseconds: 1000);
    _anim.reset();
    _anim.forward();
  }

  void _onAnimTick() {
    if (_simX == null || _simY == null) return;
    final sz = _lastViewportSize;
    final tSec = (_anim.lastElapsedDuration?.inMicroseconds ?? 0) / 1e6;

    final nx = _simX!.x(tSec);
    final ny = _simY!.x(tSec);

    _t = Offset(nx, ny);

    final clamped = _clampTranslation(_t, _scale, sz);
    final out = (clamped - _t).distance > 0.5;

    if (out) {
      _stopInertia();
      _t = clamped;
      _pushMatrixToState();
      if (mounted) setState(() {});
      _bounceToClamp();
      return;
    }

    _pushMatrixToState();
    if (mounted) setState(() {});
  }

  void _bounceToClamp() {
    final sz = _lastViewportSize;
    if (sz == Size.zero) return;

    final target = _clampTranslation(_t, _scale, sz);
    if ((target - _t).distance < 0.5) return;

    final start = _t;
    const spring = SpringDescription(mass: 1, stiffness: 520, damping: 32);
    final simX = SpringSimulation(spring, start.dx, target.dx, 0);
    final simY = SpringSimulation(spring, start.dy, target.dy, 0);

    _stopInertia();
    _anim.duration = const Duration(milliseconds: 260);
    _anim.reset();

    void tick() {
      final tSec = (_anim.lastElapsedDuration?.inMicroseconds ?? 0) / 1e6;
      _t = Offset(simX.x(tSec), simY.x(tSec));
      _pushMatrixToState();
      if (mounted) setState(() {});
      if (_anim.isCompleted || _anim.isDismissed) _anim.removeListener(tick);
    }

    _anim.addListener(tick);
    _anim.forward();
  }

  // =========================================================
  // Matrix / clamp
  // =========================================================
  void _pushMatrixToState() {
    final m = Matrix4.identity()
      ..translate(_t.dx, _t.dy)
      ..scale(_scale, _scale);
    state.transform.value.value = m;
  }

  Offset _clampTranslation(Offset t, double scale, Size viewport) {
    final fw = viewport.width * scale;
    final fh = viewport.height * scale;

    double minX, maxX, minY, maxY;

    if (fw <= viewport.width) {
      minX = maxX = (viewport.width - fw) / 2.0;
    } else {
      minX = viewport.width - fw;
      maxX = 0.0;
    }

    if (fh <= viewport.height) {
      minY = maxY = (viewport.height - fh) / 2.0;
    } else {
      minY = viewport.height - fh;
      maxY = 0.0;
    }

    return Offset(
      t.dx.clamp(minX, maxX),
      t.dy.clamp(minY, maxY),
    );
  }

  // =========================================================
  // Input handling (как у тебя)
  // =========================================================
  void _beginPointer(Offset localPos) {
    if (_locked) return;
    _stopInertia();

    _downScene = state.transform.toScene(localPos);
    _downHitId = state.hitTest(_downScene!);

    _draggingSelection = false;
    _panningViewport = false;
    _drawingTool = false;

    _lastLocal = localPos;
    _lastTsMs = DateTime.now().millisecondsSinceEpoch;
    _velocity = Offset.zero;

    final tool = state.tool;

    if (tool == TgTool.editPoints) {
      _drawingTool = true;
      state.onPanStart(_downScene!);
      return;
    }

    if (tool != TgTool.select) {
      _drawingTool = true;
      state.onPanStart(_downScene!);
      return;
    }

    if (_downHitId != null) {
      if (!state.selectedIds.contains(_downHitId)) {
        state.selectById(_downHitId!);
      }
      state.commitOnceForGestureStart();
      _draggingSelection = true;
    } else {
      _panningViewport = true;
      state.clearSelection();
    }
  }

  void _updatePointer(Offset localPos) {
    if (_locked) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final dtMs = math.max(1, now - _lastTsMs);
    final dp = localPos - _lastLocal;

    final v = dp * (1000.0 / dtMs);
    _velocity = Offset(
      ui.lerpDouble(_velocity.dx, v.dx, 0.35) ?? v.dx,
      ui.lerpDouble(_velocity.dy, v.dy, 0.35) ?? v.dy,
    );

    _lastLocal = localPos;
    _lastTsMs = now;

    if (_drawingTool || state.tool == TgTool.editPoints) {
      final scene = state.transform.toScene(localPos);
      state.onPanUpdate(scene);
      return;
    }

    if (_draggingSelection) {
      final sceneNow = state.transform.toScene(localPos);
      final scenePrev = state.transform.toScene(localPos - dp);
      final deltaScene = sceneNow - scenePrev;
      state.moveSelected(deltaScene);
      return;
    }

    if (_panningViewport) {
      _t += dp;
      _t = _clampTranslation(_t, _scale, _lastViewportSize);
      _pushMatrixToState();
      setState(() {});
      return;
    }
  }

  void _endPointer() {
    if (_locked) return;

    if (_drawingTool || state.tool == TgTool.editPoints) {
      state.onPanEnd();
      _drawingTool = false;
      return;
    }

    if (_draggingSelection) {
      state.finishGestureCommit();
      _draggingSelection = false;
      return;
    }

    if (_panningViewport) {
      _panningViewport = false;
      _startInertia(_velocity);
      return;
    }
  }

  // Pinch zoom
  double _scaleStart = 1.0;
  Offset _tStart = Offset.zero;
  Offset _focalStart = Offset.zero;

  void _onScaleStart(ScaleStartDetails d) {
    if (_locked) return;
    if (state.tool != TgTool.select) return;

    _stopInertia();
    _scaleStart = _scale;
    _tStart = _t;
    _focalStart = d.focalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    if (_locked) return;
    if (state.tool != TgTool.select) return;
    if (_lastViewportSize == Size.zero) return;

    final nextScale = (_scaleStart * d.scale).clamp(0.20, 4.0);

    final focal = d.focalPoint;
    final focalDelta = focal - _focalStart;

    final oldT = _tStart + focalDelta;
    final sceneFocal = (focal - oldT) / _scaleStart;

    final newT = focal - sceneFocal * nextScale;

    _scale = nextScale;
    _t = _clampTranslation(newT, _scale, _lastViewportSize);

    _pushMatrixToState();
    setState(() {});
  }

  void _onScaleEnd(ScaleEndDetails d) {
    if (_locked) return;
    if (state.tool != TgTool.select) return;
    _bounceToClamp();
  }

  // =========================================================
  // Build
  // =========================================================
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: LayoutBuilder(
        builder: (_, c) {
          final size = Size(c.maxWidth, c.maxHeight);

          if (size.width > 0 && size.height > 0 && size != _lastViewportSize) {
            _lastViewportSize = size;

            if (!_didInitialFit) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                if (_lastViewportSize != Size.zero) {
                  fitFieldToViewport(_lastViewportSize);
                }
              });
            }
          }

          return Listener(
            onPointerDown: (e) {
              if (_locked) return;
              _beginPointer(e.localPosition);
            },
            onPointerMove: (e) {
              if (_locked) return;
              _updatePointer(e.localPosition);
            },
            onPointerUp: (_) {
              if (_locked) return;
              _endPointer();
            },
            onPointerCancel: (_) {
              if (_locked) return;
              _endPointer();
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (d) {
                if (_locked) return;
                final scene = state.transform.toScene(d.localPosition);
                state.onTap(scene);
              },
              onDoubleTap: () {
                if (_locked) return;
                if (_lastViewportSize != Size.zero) {
                  fitFieldToViewport(_lastViewportSize);
                }
              },
              onScaleStart: _onScaleStart,
              onScaleUpdate: _onScaleUpdate,
              onScaleEnd: _onScaleEnd,
              child: AnimatedBuilder(
                animation: state,
                builder: (_, __) {
                  // pre-load stamps
                  for (final e in state.elements) {
                    if (e is TgStamp) {
                      _ensureStampLoadedAny(e.asset, playerColors: e.playerColors);
                    }
                  }
                  final p = state.previewElement;
                  if (p is TgStamp) {
                    _ensureStampLoadedAny(p.asset, playerColors: p.playerColors);
                  }

                  return CustomPaint(
                    painter: _TgBoardPainter(
                      state: state,
                      fieldImg: _fieldImg,
                      stampImages: _stampCache,
                      stampSvgImages: _stampSvgAsImageCache,
                    ),
                    isComplex: true,
                    willChange: true,
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}


class _TgBoardPainter extends CustomPainter {
  _TgBoardPainter({
    required this.state,
    required this.fieldImg,
    required this.stampImages,
    required this.stampSvgImages,
  }) : super(repaint: state.transform.value);

  final TgState state;
  final ui.Image? fieldImg;
  final Map<String, ui.Image> stampImages;
  final Map<String, ui.Image> stampSvgImages;

  Rect _fitContain(Rect dst, double srcW, double srcH) {
    if (srcW <= 0 || srcH <= 0) return dst;

    final dstAR = dst.width / dst.height;
    final srcAR = srcW / srcH;

    double w, h;
    if (srcAR > dstAR) {
      w = dst.width;
      h = w / srcAR;
    } else {
      h = dst.height;
      w = h * srcAR;
    }

    final left = dst.center.dx - w / 2;
    final top = dst.center.dy - h / 2;
    return Rect.fromLTWH(left, top, w, h);
  }

  double _currentScale(Matrix4 m) => m.storage[0].abs().clamp(0.0001, 1000.0);

  void _drawPlaceholder(Canvas canvas, Rect rect, bool selected, double opacity) {
    final scale = _currentScale(state.transform.value.value);

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(12)),
      Paint()..color = Colors.grey.withOpacity(0.30 * opacity),
    );

    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.50 * opacity)
      ..strokeWidth = 2.0 / scale
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(rect.left, rect.top),
      Offset(rect.right, rect.bottom),
      linePaint,
    );
    canvas.drawLine(
      Offset(rect.right, rect.top),
      Offset(rect.left, rect.bottom),
      linePaint,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(12)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 / scale
        ..color = Colors.white.withOpacity(0.50 * opacity),
    );

    final textPainter = TextPainter(
      text: TextSpan(
        text: 'No image',
        style: TextStyle(
          color: Colors.white,
          fontSize: 12 / scale,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(
        rect.center.dx - textPainter.width / 2,
        rect.center.dy - textPainter.height / 2,
      ),
    );
  }

  void _drawArrow(Canvas c, Offset a, Offset b, Color color, double size) {
    final dir = (b - a);
    final len = dir.distance;
    if (len < 1) return;

    final u = dir / len;
    final n = Offset(-u.dy, u.dx);

    final p1 = b - u * size;
    final left = p1 + n * (size * 0.55);
    final right = p1 - n * (size * 0.55);

    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = color;

    final path = Path()
      ..moveTo(b.dx, b.dy)
      ..lineTo(left.dx, left.dy)
      ..lineTo(right.dx, right.dy)
      ..close();

    c.drawPath(path, paint);
  }

  void _drawDashedLine(
    Canvas c,
    Offset a,
    Offset b,
    Paint p, {
    required double dash,
    required double gap,
  }) {
    final d = (b - a);
    final len = d.distance;
    if (len <= 0) return;
    final u = d / len;

    double t = 0;
    while (t < len) {
      final s = a + u * t;
      final e = a + u * math.min(t + dash, len);
      c.drawLine(s, e, p);
      t += dash + gap;
    }
  }

  void _drawDashedCircle(
    Canvas c,
    Offset center,
    double r,
    Paint p, {
    required double dash,
    required double gap,
  }) {
    final circ = 2 * math.pi * r;
    final seg = dash + gap;
    final n = math.max(8, (circ / seg).floor());

    for (int i = 0; i < n; i++) {
      final a0 = (i * seg) / r;
      final a1 = (i * seg + dash) / r;
      final path = Path()
        ..addArc(Rect.fromCircle(center: center, radius: r), a0, (a1 - a0));
      c.drawPath(path, p);
    }
  }

  void _drawDashedRRect(
    Canvas c,
    RRect rr,
    Paint p, {
    required double dash,
    required double gap,
  }) {
    final path = Path()..addRRect(rr);
    final metrics = path.computeMetrics().toList();
    for (final m in metrics) {
      double dist = 0;
      while (dist < m.length) {
        final end = math.min(dist + dash, m.length);
        c.drawPath(m.extractPath(dist, end), p);
        dist += dash + gap;
      }
    }
  }

  void _drawDashedPath(
    Canvas canvas,
    Path path,
    Paint paint, {
    required double dash,
    required double gap,
  }) {
    final metrics = path.computeMetrics().toList();
    for (final m in metrics) {
      double dist = 0;
      while (dist < m.length) {
        final end = math.min(dist + dash, m.length);
        canvas.drawPath(m.extractPath(dist, end), paint);
        dist += dash + gap;
      }
    }
  }

  void _drawControlLine(Canvas canvas, Offset a, Offset b, double scale) {
    canvas.drawLine(
      a,
      b,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5 / scale
        ..color = Colors.white.withOpacity(0.3)
        ..strokeCap = StrokeCap.round,
    );
  }

  Color _getPointColor(PointType type) {
    switch (type) {
      case PointType.anchor:
        return Colors.white;
      case PointType.control1:
        return const Color(0xFF2F80ED);
      case PointType.control2:
        return const Color(0xFFEB5757);
    }
  }

  StrokeCap _mapStrokeCap(TgStrokeCap cap) {
    switch (cap) {
      case TgStrokeCap.butt:
        return StrokeCap.butt;
      case TgStrokeCap.round:
        return StrokeCap.round;
      case TgStrokeCap.square:
        return StrokeCap.square;
    }
  }

  StrokeJoin _mapStrokeJoin(TgStrokeJoin join) {
    switch (join) {
      case TgStrokeJoin.miter:
        return StrokeJoin.miter;
      case TgStrokeJoin.round:
        return StrokeJoin.round;
      case TgStrokeJoin.bevel:
        return StrokeJoin.bevel;
    }
  }

  void _paintFieldCover(Canvas canvas, Rect fieldRect) {
    final scaleNow = _currentScale(state.transform.value.value);

    if (fieldImg != null) {
      final img = fieldImg!;
      final srcW = img.width.toDouble();
      final srcH = img.height.toDouble();

      final srcAR = srcW / srcH;
      final dstAR = fieldRect.width / fieldRect.height;

      Rect src;
      if (srcAR > dstAR) {
        final newW = srcH * dstAR;
        final left = (srcW - newW) / 2.0;
        src = Rect.fromLTWH(left, 0, newW, srcH);
      } else {
        final newH = srcW / dstAR;
        final top = (srcH - newH) / 2.0;
        src = Rect.fromLTWH(0, top, srcW, newH);
      }

      canvas.drawImageRect(
        img,
        src,
        fieldRect,
        Paint()
          ..isAntiAlias = true
          ..filterQuality = FilterQuality.high,
      );

      canvas.drawRect(
        fieldRect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0 / scaleNow
          ..color = Colors.white.withOpacity(0.06),
      );
    } else {
      canvas.drawRect(fieldRect, Paint()..color = const Color(0xFF1B3A2A));
      canvas.drawRect(
        fieldRect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0 / scaleNow
          ..color = Colors.white.withOpacity(0.10),
      );
    }
  }

  void _paintGrid(Canvas canvas, Rect fieldRect) {
    final step = state.gridStep.clamp(8.0, 80.0);
    final p = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..strokeWidth = 1.0 / _currentScale(state.transform.value.value);

    for (double x = fieldRect.left; x <= fieldRect.right; x += step) {
      canvas.drawLine(Offset(x, fieldRect.top), Offset(x, fieldRect.bottom), p);
    }
    for (double y = fieldRect.top; y <= fieldRect.bottom; y += step) {
      canvas.drawLine(Offset(fieldRect.left, y), Offset(fieldRect.right, y), p);
    }
  }

  void _drawControlPoints(Canvas canvas, TgEditableCurve curve, bool selected) {
    final scale = _currentScale(state.transform.value.value);
    final pointSize = 10.0 / scale;

    for (int i = 0; i < curve.points.length; i++) {
      final point = curve.points[i];
      final isSelected = curve.selectedPointIndex == i;

      final PointType type;
      if (curve.curveType == CurveType.line) {
        type = PointType.anchor;
      } else if (curve.curveType == CurveType.quadratic) {
        type = (i == 1) ? PointType.control1 : PointType.anchor;
      } else {
        if (i == 1) type = PointType.control1;
        else if (i == 2) type = PointType.control2;
        else type = PointType.anchor;
      }

      final paint = Paint()
        ..style = PaintingStyle.fill
        ..color = isSelected ? const Color(0xFF00A750) : _getPointColor(type);

      canvas.drawCircle(point, pointSize, paint);

      if (isSelected) {
        canvas.drawCircle(
          point,
          pointSize * 1.5,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0 / scale
            ..color = Colors.white,
        );
      }

      if (curve.curveType == CurveType.cubic && curve.points.length == 4) {
        if (i == 1) {
          _drawControlLine(canvas, curve.points[0], curve.points[1], scale);
        } else if (i == 2) {
          _drawControlLine(canvas, curve.points[3], curve.points[2], scale);
        }
      } else if (curve.curveType == CurveType.quadratic &&
          curve.points.length == 3 &&
          i == 1) {
        _drawControlLine(canvas, curve.points[0], curve.points[1], scale);
        _drawControlLine(canvas, curve.points[1], curve.points[2], scale);
      }
    }
  }

  void _paintElement(
    Canvas canvas,
    TgElement e, {
    required bool selected,
    bool isPreview = false,
  }) {
    // ===== LINE =====
    if (e is TgLine) {
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = e.width / _currentScale(state.transform.value.value)
        ..color = e.color.withOpacity(isPreview ? 0.7 : 1.0);

      if (e.kind == LineKind.dashed) {
        _drawDashedLine(canvas, e.a, e.b, p, dash: 14, gap: 10);
      } else {
        canvas.drawLine(e.a, e.b, p);
      }

      if (e.end == LineEnd.arrow) {
        _drawArrow(canvas, e.a, e.b, p.color, e.arrowSize);
      }
      return;
    }

    // ===== RECT =====
    if (e is TgRect) {
      final fill = Paint()
        ..style = PaintingStyle.fill
        ..color = e.fill.withOpacity(e.opacity * (isPreview ? 0.7 : 1.0));
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = e.borderWidth / _currentScale(state.transform.value.value)
        ..color = e.border.withOpacity(isPreview ? 0.7 : 1.0);

      canvas.save();
      canvas.translate(e.position.dx, e.position.dy);
      canvas.rotate(e.rotation);

      final r = Rect.fromCenter(center: Offset.zero, width: e.width, height: e.height);
      final rr = RRect.fromRectAndRadius(r, Radius.circular(e.borderRadius));

      if (e.fill.opacity > 0.0) canvas.drawRRect(rr, fill);

      if (e.borderWidth > 0) {
        if (e.borderKind == BorderKind.dashed) {
          _drawDashedRRect(canvas, rr, stroke, dash: 14, gap: 10);
        } else {
          canvas.drawRRect(rr, stroke);
        }
      }

      canvas.restore();
      return;
    }

    // ===== CIRCLE =====
    if (e is TgCircle) {
      final fill = Paint()
        ..style = PaintingStyle.fill
        ..color = e.fill.withOpacity(e.opacity * (isPreview ? 0.7 : 1.0));
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = e.borderWidth / _currentScale(state.transform.value.value)
        ..color = e.border.withOpacity(isPreview ? 0.7 : 1.0);

      canvas.save();
      canvas.translate(e.position.dx, e.position.dy);
      canvas.rotate(e.rotation);

      if (e.fill.opacity > 0.0) canvas.drawCircle(Offset.zero, e.radius, fill);

      if (e.borderWidth > 0) {
        if (e.borderKind == BorderKind.dashed) {
          _drawDashedCircle(canvas, Offset.zero, e.radius, stroke, dash: 14, gap: 10);
        } else {
          canvas.drawCircle(Offset.zero, e.radius, stroke);
        }
      }

      canvas.restore();
      return;
    }

    // ===== TEXT =====
    if (e is TgText) {
      final tp = TextPainter(
        text: TextSpan(
          text: e.text,
          style: TextStyle(
            color: e.color.withOpacity(e.opacity * (isPreview ? 0.7 : 1.0)),
            fontSize: e.size,
            fontWeight: e.weight,
            fontFamily: e.fontFamily,
            decoration: e.style == TgTextStyle.underline
                ? TextDecoration.underline
                : TextDecoration.none,
            fontStyle: e.style == TgTextStyle.italic
                ? FontStyle.italic
                : FontStyle.normal,
          ),
        ),
        textAlign: e.alignment,
        textDirection: TextDirection.ltr,
      )..layout();

      canvas.save();
      canvas.translate(e.position.dx, e.position.dy);
      canvas.rotate(e.rotation);
      tp.paint(canvas, Offset(-tp.width / 2.0, -tp.height / 2.0));
      canvas.restore();
      return;
    }

    // ===== STAMP =====
    if (e is TgStamp) {
      final isSvg = e.asset.toLowerCase().endsWith('.svg');
      final opacity = (e.opacity * (isPreview ? 0.7 : 1.0)).clamp(0.0, 1.0);

      // единый cacheKey
      final cacheKey = _svgCacheKey(e.asset, e.playerColors);

      canvas.save();
      canvas.translate(e.pos.dx, e.pos.dy);
      canvas.rotate(e.rotation);

     // внутри _paintElement -> if (e is TgStamp) { ... }

final rect = Rect.fromCenter(
  center: Offset.zero,
  width: e.size,
  height: e.size,
);

if (isSvg) {
  final img = stampSvgImages[cacheKey];
  if (img != null) {
    final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());

    // ✅ ВАЖНО: сохраняем пропорции
    final dst = _fitContain(rect, img.width.toDouble(), img.height.toDouble());

    if (opacity < 1.0) {
      canvas.saveLayer(rect, Paint()..color = Colors.white.withOpacity(opacity));
      canvas.drawImageRect(img, src, dst, Paint()..filterQuality = FilterQuality.high);
      canvas.restore();
    } else {
      canvas.drawImageRect(img, src, dst, Paint()..filterQuality = FilterQuality.high);
    }
  } else {
    _drawPlaceholder(canvas, rect, selected, opacity);
  }
} else {
  final img = stampImages[e.asset];
  if (img != null) {
    final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());

    // ✅ ВАЖНО: сохраняем пропорции
    final dst = _fitContain(rect, img.width.toDouble(), img.height.toDouble());

    if (opacity < 1.0) {
      canvas.saveLayer(rect, Paint()..color = Colors.white.withOpacity(opacity));
      canvas.drawImageRect(img, src, dst, Paint()..filterQuality = FilterQuality.high);
      canvas.restore();
    } else {
      canvas.drawImageRect(img, src, dst, Paint()..filterQuality = FilterQuality.high);
    }
  } else {
    _drawPlaceholder(canvas, rect, selected, opacity);
  }
}

      if (selected) {
        final hasImage = isSvg
            ? stampSvgImages.containsKey(cacheKey)
            : stampImages.containsKey(e.asset);

        if (hasImage) {
          final scaleNow = _currentScale(state.transform.value.value);
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect.inflate(6), const Radius.circular(14)),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.0 / scaleNow
              ..color = const Color(0xFF00A750),
          );
        }
      }

      canvas.restore();
      return;
    }

    // ===== CURVE =====
    if (e is TgCurve) {
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = e.width / _currentScale(state.transform.value.value)
        ..color = e.color.withOpacity(isPreview ? 0.7 : 1.0)
        ..strokeCap = _mapStrokeCap(e.cap)
        ..strokeJoin = _mapStrokeJoin(e.join);

      final path = Path();

      if (e.points.isNotEmpty) {
        path.moveTo(e.points.first.dx, e.points.first.dy);

        if (e.curveType == CurveType.line && e.points.length >= 2) {
          path.lineTo(e.points.last.dx, e.points.last.dy);
        } else if (e.curveType == CurveType.quadratic && e.points.length >= 3) {
          path.quadraticBezierTo(
            e.points[1].dx, e.points[1].dy,
            e.points[2].dx, e.points[2].dy,
          );
        } else if (e.curveType == CurveType.cubic && e.points.length >= 4) {
          path.cubicTo(
            e.points[1].dx, e.points[1].dy,
            e.points[2].dx, e.points[2].dy,
            e.points[3].dx, e.points[3].dy,
          );
        }
      }

      if (e.kind == LineKind.dashed) {
        _drawDashedPath(canvas, path, p, dash: 14, gap: 10);
      } else if (e.kind == LineKind.dotted) {
        _drawDashedPath(canvas, path, p, dash: 4, gap: 8);
      } else {
        canvas.drawPath(path, p);
      }

      if (e.end == LineEnd.arrow && e.points.length >= 2) {
        _drawArrow(
          canvas,
          e.points[e.points.length - 2],
          e.points.last,
          p.color,
          e.arrowSize,
        );
      }

      if (e is TgEditableCurve && e.showControlPoints) {
        _drawControlPoints(canvas, e, selected);
      }

      return;
    }

    // ===== SPIRAL =====
    if (e is TgSpiral) {
      final scaleNow = _currentScale(state.transform.value.value);

      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = e.width / scaleNow
        ..color = e.color.withOpacity(isPreview ? 0.7 : 1.0)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final path = e.getPath();

      if (e.kind == LineKind.dashed) {
        _drawDashedPath(canvas, path, p, dash: 14, gap: 10);
      } else if (e.kind == LineKind.dotted) {
        _drawDashedPath(canvas, path, p, dash: 4, gap: 8);
      } else {
        canvas.drawPath(path, p);
      }

      if (e.lineEnd == LineEnd.arrow) {
        final dir = e.endPoint - e.start;
        if (dir.distance > 0) {
          final u = dir / dir.distance;
          _drawArrow(canvas, e.endPoint - u * 30, e.endPoint, p.color, e.arrowSize);
        }
      }
      return;
    }

    // ===== ZIGZAG =====
    if (e is TgZigzag) {
      final scaleNow = _currentScale(state.transform.value.value);
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = e.width / scaleNow
        ..color = e.color.withOpacity(isPreview ? 0.7 : 1.0)
        ..strokeCap = StrokeCap.round;

      final path = e.getPath();
      if (e.kind == LineKind.dashed) {
        _drawDashedPath(canvas, path, p, dash: 14, gap: 10);
      } else if (e.kind == LineKind.dotted) {
        _drawDashedPath(canvas, path, p, dash: 4, gap: 8);
      } else {
        canvas.drawPath(path, p);
      }

      if (e.lineEnd == LineEnd.arrow) {
        final dir = e.endPoint - e.start;
        if (dir.distance > 0) {
          final u = dir / dir.distance;
          _drawArrow(canvas, e.endPoint - u * 30, e.endPoint, p.color, e.arrowSize);
        }
      }
      return;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    // background
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF0B0C0E),
    );

    // viewport transform
    canvas.save();
    canvas.transform(state.transform.value.value.storage);

    final fieldRect = Offset.zero & size;

    _paintFieldCover(canvas, fieldRect);

    if (state.gridEnabled) {
      _paintGrid(canvas, fieldRect);
    }

    for (final e in state.elements) {
      _paintElement(canvas, e, selected: state.selectedIds.contains(e.id));
    }

    final prev = state.previewElement;
    if (prev != null) {
      _paintElement(canvas, prev, selected: false, isPreview: true);
    }

    if (state.selectedIds.isNotEmpty) {
      final b = state.selectionBounds();
      if (b != Rect.zero) {
        final p = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0 / _currentScale(state.transform.value.value)
          ..color = const Color(0xFF00A750);
        canvas.drawRect(b.inflate(6), p);
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TgBoardPainter oldDelegate) {
    return oldDelegate.state != state ||
        oldDelegate.fieldImg != fieldImg ||
        oldDelegate.stampImages != stampImages ||
        oldDelegate.stampSvgImages != stampSvgImages;
  }
}

