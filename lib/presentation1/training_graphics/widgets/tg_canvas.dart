// lib/presentation/training_graphics/widgets/tg_canvas.dart
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svg/flutter_svg.dart' as fsvg;
import 'package:vector_math/vector_math_64.dart' as vector;

import 'package:sportoteka/presentation/training_graphics/tg_models.dart';
import 'package:sportoteka/presentation/training_graphics/training_graphics_state.dart';

/// Чтобы GlobalKey мог вызывать методы Canvas извне:
abstract class TgCanvasStateProxy {
  void resetView();
  void zoomToSelection();
  void fitFieldToViewport(Size viewportSize);
}

enum _PointerMode {
  idle,
  pendingObjectDrag,
  pendingViewportPan,
  draggingObject,
  panningViewport,
  drawing,
}

bool _isFieldAttachedStampAsset(String asset) {
  final a = asset.toLowerCase().replaceAll('\\', '/');

  return a.contains('/assets/training/stamps/vorota1/back.png') ||
      a.contains('/assets/training/stamps/vorota1/front.png') ||
      a.contains('/assets/training/stamps/vorota1/left.png') ||
      a.contains('/assets/training/stamps/vorota1/right.png') ||
      a.contains('/training/stamps/vorota1/back.png') ||
      a.contains('/training/stamps/vorota1/front.png') ||
      a.contains('/training/stamps/vorota1/left.png') ||
      a.contains('/training/stamps/vorota1/right.png') ||
      a.endsWith('vorota1/back.png') ||
      a.endsWith('vorota1/front.png') ||
      a.endsWith('vorota1/left.png') ||
      a.endsWith('vorota1/right.png');
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

class TgCanvasState extends State<TgCanvas>
    with SingleTickerProviderStateMixin
    implements TgCanvasStateProxy {
  TgState get state => widget.state;

  // =========================================================
  // ===== 3D режим (локальные поля + sync со state) =====
  // =========================================================
  bool _is3DMode = false;
  double _rotationX = 0.0;
  double _rotationY = 0.0;
  double _rotationZ = 0.0;

  // Для совместимости храним в state, но в орто-3D не используем perspective
  double _perspective = 0.0008;

  bool _syncing3D = false;

  late final ValueNotifier<double> rotationXNotifier;
  late final ValueNotifier<double> rotationYNotifier;

  // Размеры поля (логические)
  final double fieldLogicalWidth = 930;
  final double fieldLogicalHeight = 1300;

  // ===== Viewport state (scale + translation) =====
  double _scale = 1.0;
  Offset _t = Offset.zero;
  Size _lastViewportSize = Size.zero;

  bool _didInitialFit = false;

  // ===== Inertia (pan fling) =====
  late final AnimationController _anim = AnimationController(vsync: this);
  Simulation? _simX;
  Simulation? _simY;

  // ===== Pointer interaction =====
  Offset? _downScene;
  Offset? _downLocal;
  String? _downHitId;

  Offset? _dragStartScene;
  Offset _dragAppliedDelta = Offset.zero;

  _PointerMode _pointerMode = _PointerMode.idle;

  static const double _dragSlop = 6.0;

  int _activePointers = 0;
  bool _multiTouchActive = false;
  bool _tapConsumedByScale = false;

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

  // ===== Field config =====
  static const String _fieldAsset = "assets/training/field.png";

  bool get _locked => state.lockViewportGestures == true;

  // =========================================================
  // Helpers: current field view rect
  // =========================================================
  Rect _activeFieldRect() {
    final fs = state.fieldLogicalSize;
    switch (state.fieldView) {
      case TgFieldView.full:
        return Rect.fromLTWH(0, 0, fs.width, fs.height);
      case TgFieldView.topHalf:
        return Rect.fromLTWH(0, 0, fs.width, fs.height / 2);
      case TgFieldView.bottomHalf:
        return Rect.fromLTWH(0, fs.height / 2, fs.width, fs.height / 2);
      case TgFieldView.leftHalf:
        return Rect.fromLTWH(0, 0, fs.width / 2, fs.height);
      case TgFieldView.rightHalf:
        return Rect.fromLTWH(fs.width / 2, 0, fs.width / 2, fs.height);
    }
  }

  bool _fieldContains(Offset p) {
    return _activeFieldRect().inflate(0.01).contains(p);
  }

  bool _hasSavedViewportMatrix() {
    final m = state.transform.value.value.storage;
    final sx = m[0];
    final sy = m[5];
    final tx = m[12];
    final ty = m[13];

    return (sx - 1.0).abs() > 0.0001 ||
        (sy - 1.0).abs() > 0.0001 ||
        tx.abs() > 0.5 ||
        ty.abs() > 0.5;
  }

  void _pullMatrixFromState() {
    final m = state.transform.value.value.storage;
    final sx = m[0];
    final sy = m[5];
    final tx = m[12];
    final ty = m[13];

    final nextScale = ((sx.abs() + sy.abs()) / 2.0).clamp(0.0001, 1000.0);
    _scale = nextScale;
    _t = Offset(tx, ty);
  }

  // =========================================================
  // Public camera helpers
  // =========================================================
  void panCameraBy(Offset deltaPx) {
    if (_locked) return;
    if (_lastViewportSize == Size.zero) return;

    _t += deltaPx;
    _t = _clampTranslation(_t, _scale, _lastViewportSize);
    _stopInertia();
    _pushMatrixToState();
    if (mounted) setState(() {});
  }

  void zoomCameraBy(double delta, {double min = 0.18, double max = 6.0}) {
    if (_locked) return;
    if (_lastViewportSize == Size.zero) return;

    final oldScale = _scale;
    final nextScale = (_scale + delta).clamp(min, max);

    if ((nextScale - oldScale).abs() < 1e-6) return;

    final center = Offset(
      _lastViewportSize.width / 2,
      _lastViewportSize.height / 2,
    );

    final sceneAtCenter = (center - _t) / oldScale;
    final newT = center - sceneAtCenter * nextScale;

    _scale = nextScale;
    _t = _clampTranslation(newT, _scale, _lastViewportSize);

    _stopInertia();
    _pushMatrixToState();
    if (mounted) setState(() {});
  }

  void zoomIn() => zoomCameraBy(0.25);
  void zoomOut() => zoomCameraBy(-0.25);

  void cameraUp() => panCameraBy(const Offset(0, 70));
  void cameraDown() => panCameraBy(const Offset(0, -70));
  void cameraLeft() => panCameraBy(const Offset(70, 0));
  void cameraRight() => panCameraBy(const Offset(-70, 0));

  // =========================================================
  // Center view
  // =========================================================
  void centerView() {
    if (_lastViewportSize == Size.zero) return;

    final fieldRect = _activeFieldRect();
    final fw = fieldRect.width;
    final fh = fieldRect.height;

    final tx = (_lastViewportSize.width - fw * _scale) / 2.0 - fieldRect.left * _scale;
    final ty = (_lastViewportSize.height - fh * _scale) / 2.0 - fieldRect.top * _scale;

    _t = _clampTranslation(Offset(tx, ty), _scale, _lastViewportSize);
    _stopInertia();
    _pushMatrixToState();
    if (mounted) setState(() {});
  }

  // =========================================================
  // 3D sync from state
  // =========================================================
  void _sync3DFromState() {
    if (_syncing3D) return;

    _is3DMode = state.is3DMode;
    _rotationX = state.rotationX;
    _rotationY = state.rotationY;
    _rotationZ = state.rotationZ;
    _perspective = state.perspective;

    rotationXNotifier.value = _rotationX;
    rotationYNotifier.value = _rotationY;

    if (mounted) setState(() {});
  }

  // =========================================================
  // ✅ ОРТО-3D математика (БЕЗ перспективы => нет деформации)
  // =========================================================
  vector.Matrix4 _buildField3DMatrix() {
    if (!_is3DMode) return vector.Matrix4.identity();

    final fs = state.fieldLogicalSize;
    final cx = fs.width / 2.0;
    final cy = fs.height / 2.0;

    final tilt = _rotationX.clamp(-1.25, 0.0);
    final zRot = _rotationZ;

    const depth = 420.0;

    return vector.Matrix4.identity()
      ..translate(cx, cy, 0.0)
      ..translate(0.0, 0.0, -depth)
      ..rotateX(tilt)
      ..rotateZ(zRot)
      ..translate(0.0, 0.0, depth)
      ..translate(-cx, -cy, 0.0);
  }

  Offset _projectPoint3D(Offset p) {
    if (!state.is3DMode) return p;
    final m3d = _buildField3DMatrix();
    final out = m3d.transform(vector.Vector4(p.dx, p.dy, 0.0, 1.0));
    return Offset(out.x, out.y);
  }

  Offset _unprojectPoint3D(Offset projected) {
    if (!state.is3DMode) return projected;

    final fs = state.fieldLogicalSize;
    final m3d = _buildField3DMatrix();
    final inv = vector.Matrix4.copy(m3d);

    final ok = inv.invert();
    if (ok == 0.0) return projected;

    final out = inv.transform(
      vector.Vector4(projected.dx, projected.dy, 0.0, 1.0),
    );
    final p = Offset(out.x, out.y);

    return Offset(
      p.dx.clamp(0.0, fs.width),
      p.dy.clamp(0.0, fs.height),
    );
  }

  Offset _sceneFromLocal(Offset localPos, {bool clampToField = true}) {
    final scene2d = state.transform.toScene(localPos);

    if (!state.is3DMode) {
      if (!clampToField) return scene2d;
      final rect = _activeFieldRect();
      return Offset(
        scene2d.dx.clamp(rect.left, rect.right),
        scene2d.dy.clamp(rect.top, rect.bottom),
      );
    }

    final fieldPos = _unprojectPoint3D(scene2d);
    if (!clampToField) return fieldPos;

    final rect = _activeFieldRect();
    return Offset(
      fieldPos.dx.clamp(rect.left, rect.right),
      fieldPos.dy.clamp(rect.top, rect.bottom),
    );
  }

  Offset _fieldToLocal(Offset fieldPoint) {
    return Offset(
      _t.dx + fieldPoint.dx * _scale,
      _t.dy + fieldPoint.dy * _scale,
    );
  }

  double _billboardScaleForStamp(TgStamp e) {
    if (!state.is3DMode) return 1.0;
    final tilt = _rotationX.abs().clamp(0.0, 1.25);
    final s = (1.0 - tilt * 0.10);
    return s.clamp(0.78, 1.0);
  }

  String? _hitTestStamp3DAtLocal(Offset localPos) {
    final elements = state.elements;

    for (int i = elements.length - 1; i >= 0; i--) {
      final e = elements[i];
      if (e is! TgStamp) continue;
      if (!_fieldContains(e.pos)) continue;

      // ✅ Ворота не billboard, их проверяем обычным state.hitTest через scene
      if (_isFieldAttachedStampAsset(e.asset)) continue;

      final projected = _projectPoint3D(e.pos);
      final localCenter = _fieldToLocal(projected);

      final stampScale = _billboardScaleForStamp(e);
      final sizePx = (e.size * stampScale * _scale).clamp(24.0, 1200.0);

      final rect = Rect.fromCenter(
        center: localCenter,
        width: sizePx,
        height: sizePx,
      ).inflate(10);

      if (rect.contains(localPos)) {
        return e.id;
      }
    }

    return null;
  }

  String? _hitTestAtLocal(Offset localPos, Offset scenePos) {
    if (_fieldContains(scenePos)) {
      if (state.is3DMode) {
        final stampHit = _hitTestStamp3DAtLocal(localPos);
        if (stampHit != null) return stampHit;
      }
      return state.hitTest(scenePos);
    }

    if (state.is3DMode) {
      final stampHit = _hitTestStamp3DAtLocal(localPos);
      if (stampHit != null) return stampHit;
    }

    return null;
  }

  void _resetPointerSession() {
    _downScene = null;
    _downLocal = null;
    _downHitId = null;
    _dragStartScene = null;
    _dragAppliedDelta = Offset.zero;
    _pointerMode = _PointerMode.idle;
    _velocity = Offset.zero;
  }

  // =========================================================
  // 3D controls (PUBLIC API)
  // =========================================================
  void toggle3DMode() {
    _is3DMode = !_is3DMode;

    _pushMatrixToState();

    if (_is3DMode && _lastViewportSize != Size.zero) {
      fitFieldToViewport3D(_lastViewportSize);
    } else if (!_is3DMode && _lastViewportSize != Size.zero) {
      fitFieldToViewport(_lastViewportSize);
    }

    if (mounted) setState(() {});
  }

  void setRotationX(double value) {
    final v = value.clamp(-1.25, 0.0);
    _rotationX = v;
    rotationXNotifier.value = v;

    _syncing3D = true;
    state.set3DParams(
      enabled: true,
      rotationX: v,
      rotationY: _rotationY,
      rotationZ: _rotationZ,
      perspective: _perspective,
      fieldSize: Size(fieldLogicalWidth, fieldLogicalHeight),
      notify: true,
    );
    _syncing3D = false;

    _pushMatrixToState();
    if (mounted) setState(() {});
  }

  void setRotationY(double value) {
    final v = value.clamp(-math.pi / 2, math.pi / 2);
    _rotationY = v;
    rotationYNotifier.value = v;

    _syncing3D = true;
    state.set3DParams(
      enabled: true,
      rotationX: _rotationX,
      rotationY: v,
      rotationZ: _rotationZ,
      perspective: _perspective,
      fieldSize: Size(fieldLogicalWidth, fieldLogicalHeight),
      notify: true,
    );
    _syncing3D = false;

    _pushMatrixToState();
    if (mounted) setState(() {});
  }

  void setRotationZ(double value) {
    final v = value.clamp(-math.pi, math.pi);
    _rotationZ = v;

    _syncing3D = true;
    state.set3DParams(
      enabled: true,
      rotationX: _rotationX,
      rotationY: _rotationY,
      rotationZ: v,
      perspective: _perspective,
      fieldSize: Size(fieldLogicalWidth, fieldLogicalHeight),
      notify: true,
    );
    _syncing3D = false;

    _pushMatrixToState();
    if (mounted) setState(() {});
  }

  void reset3D() {
    _is3DMode = false;
    _rotationX = 0.0;
    _rotationY = 0.0;
    _rotationZ = 0.0;

    rotationXNotifier.value = 0.0;
    rotationYNotifier.value = 0.0;

    _syncing3D = true;
    state.set3DParams(
      enabled: false,
      rotationX: 0.0,
      rotationY: 0.0,
      rotationZ: 0.0,
      perspective: _perspective,
      fieldSize: Size(fieldLogicalWidth, fieldLogicalHeight),
      notify: true,
    );
    _syncing3D = false;

    _pushMatrixToState();
    if (mounted) setState(() {});
  }

  // =========================================================
  // ✅ Clamp по ПРОЕЦИРОВАННЫМ границам активной области поля
  // =========================================================
  Rect _projectedFieldBounds() {
    final rect = _activeFieldRect();

    if (!state.is3DMode) {
      return rect;
    }

    final m3d = _buildField3DMatrix();

    Offset proj(Offset p) {
      final out = m3d.transform(vector.Vector4(p.dx, p.dy, 0.0, 1.0));
      return Offset(out.x, out.y);
    }

    final p0 = proj(rect.topLeft);
    final p1 = proj(rect.topRight);
    final p2 = proj(rect.bottomRight);
    final p3 = proj(rect.bottomLeft);

    final xs = [p0.dx, p1.dx, p2.dx, p3.dx];
    final ys = [p0.dy, p1.dy, p2.dy, p3.dy];

    final minX = xs.reduce(math.min);
    final maxX = xs.reduce(math.max);
    final minY = ys.reduce(math.min);
    final maxY = ys.reduce(math.max);

    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  Offset _clampTranslation(Offset t, double scale, Size viewport) {
    final bounds = _projectedFieldBounds();

    final contentW = (bounds.width * scale).abs();
    final contentH = (bounds.height * scale).abs();

    double dx = t.dx;
    double dy = t.dy;

    if (contentW <= viewport.width) {
      final targetLeft = (viewport.width - contentW) / 2.0;
      dx = targetLeft - bounds.left * scale;
    } else {
      final minDx = viewport.width - bounds.right * scale;
      final maxDx = -bounds.left * scale;
      dx = dx.clamp(minDx, maxDx);
    }

    if (contentH <= viewport.height) {
      final targetTop = (viewport.height - contentH) / 2.0;
      dy = targetTop - bounds.top * scale;
    } else {
      final minDy = viewport.height - bounds.bottom * scale;
      final maxDy = -bounds.top * scale;
      dy = dy.clamp(minDy, maxDy);
    }

    return Offset(dx, dy);
  }

  void fitFieldToViewport3D(Size viewportSize) {
    if (viewportSize.width <= 0 || viewportSize.height <= 0) return;

    _lastViewportSize = viewportSize;

    final b = _projectedFieldBounds();
    if (b.width <= 0 || b.height <= 0) return;

    const pad = 18.0;
    final vw = math.max(1.0, viewportSize.width - pad * 2);
    final vh = math.max(1.0, viewportSize.height - pad * 2);

    _scale = math.min(vw / b.width, vh / b.height).clamp(0.15, 6.0);

    _t = Offset(
      (viewportSize.width - b.width * _scale) / 2.0 - b.left * _scale,
      (viewportSize.height - b.height * _scale) / 2.0 - b.top * _scale,
    );

    _stopInertia();
    _t = _clampTranslation(_t, _scale, viewportSize);
    _pushMatrixToState();
    if (mounted) setState(() {});
  }

  // =========================================================
  // Push matrix to state
  // =========================================================
  void _pushMatrixToState() {
    final matrix = vector.Matrix4.identity()
      ..translate(_t.dx, _t.dy)
      ..scale(_scale, _scale);

    state.transform.value.value = matrix;

    _syncing3D = true;
    state.set3DParams(
      enabled: _is3DMode,
      rotationX: _is3DMode ? _rotationX : 0.0,
      rotationY: _is3DMode ? _rotationY : 0.0,
      rotationZ: _is3DMode ? _rotationZ : 0.0,
      perspective: _perspective,
      fieldSize: Size(fieldLogicalWidth, fieldLogicalHeight),
      notify: true,
    );
    _syncing3D = false;
  }

  // =========================================================
  // Helpers for "edit points" menu opening
  // =========================================================
  bool _isPointsEditableElement(TgElement? e) {
    return e is TgEditableCurve ||
        e is TgEditableZigzag ||
        e is TgEditableSpiral ||
        e is TgEditableSpring ||
        e is TgEditableWavy;
  }

  TgElement? _selectedElementOrNull() {
    if (state.selectedIds.isEmpty) return null;
    final id = state.selectedIds.first;
    for (final e in state.elements) {
      if (e.id == id) return e;
    }
    return null;
  }

  void _maybeOpenEditMenuIfNeeded() {
    if (state.tool != TgTool.editPoints) return;
    final sel = _selectedElementOrNull();
    if (_isPointsEditableElement(sel)) {
      widget.onRequestEditSelected();
    }
  }

  // =========================================================
  // SVG sanitize
  // =========================================================
  String _sanitizeSvgForFlutter(String svg) {
    var s = svg;
    s = s.replaceFirst(RegExp(r'<\?xml[^>]*\?>', multiLine: true), '');
    s = s.replaceFirst(RegExp(r'<!DOCTYPE[\s\S]*?\]>', multiLine: true), '');
    s = s.replaceFirst(RegExp(r'<!DOCTYPE[^>]*>', multiLine: true), '');
    s = s.replaceAll('&ns_extend;', 'http://ns.adobe.com/Extensibility/1.0/');
    s = s.replaceAll('&ns_ai;', 'http://ns.adobe.com/AdobeIllustrator/10.0/');
    s = s.replaceAll('&ns_graphs;', 'http://ns.adobe.com/Graphs/1.0/');
    s = s.replaceAll('\u0000', '');
    return s.trim();
  }

  // =========================================================
  // SVG -> ui.Image (рендер виджета в offscreen image)
  // =========================================================
  Future<ui.Image> _renderWidgetToImage(
    Widget widget, {
    double pixelRatio = 3.0,
    Size logicalSize = const Size(256, 256),
  }) async {
    try {
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
  // SVG -> ui.Image (REAL DEVICE FIX)
  // =========================================================
  Future<ui.Image> _rasterizeSvgString(
    String svgString, {
    required double targetPx,
  }) async {
    final loader = fsvg.SvgStringLoader(svgString);
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

  // =========================================================
  // ✅ CacheKey: SVG only (players + props). Ворота PNG => не участвуют
  // =========================================================
  String svgCacheKey(String asset, PlayerColors? pc) {
    final isSvg = asset.toLowerCase().endsWith('.svg');
    if (!isSvg) return asset;
    if (pc == null) return asset;

    final assetIsPlayer =
        asset.contains('/run_svg/') ||
        asset.contains('/pass_svg/') ||
        asset.contains('/jump_svg/') ||
        asset.contains('/vrat_svg/') ||
        asset.contains('/stand_svg/');

    final assetIsProp = asset.contains('/props/');

    if (assetIsProp) {
      return '$asset?propColor=${pc.jersey.value}';
    }

    if (assetIsPlayer) {
      return '$asset?j=${pc.jersey.value}&s=${pc.shorts.value}&sk=${pc.skin.value}&so=${pc.socks.value}';
    }

    return asset;
  }

  Future<ui.Image> _loadSvgAsImage(
    String asset, {
    double targetPx = 256,
    PlayerColors? playerColors,
  }) async {
    if (kDebugMode) {
      print('🎨 _loadSvgAsImage: asset=$asset');
      print('🎨   playerColors: ${playerColors?.jersey}, isProp=${playerColors?.isProp}');
    }

    final String rawSvg = await rootBundle.loadString(asset);
    final String svgString = _sanitizeSvgForFlutter(rawSvg);

    String finalSvg = svgString;

    final bool assetIsPlayer =
        asset.contains('/run_svg/') ||
        asset.contains('/pass_svg/') ||
        asset.contains('/jump_svg/') ||
        asset.contains('/vrat_svg/') ||
        asset.contains('/stand_svg/');

    final bool assetIsProp = asset.contains('/props/');

    final bool canColor = playerColors != null;

    final bool isPlayer = canColor && !playerColors!.isProp && assetIsPlayer;
    final bool isProp = canColor && assetIsProp;

    if (kDebugMode) {
      print('🎨   isPlayer=$isPlayer, isProp=$isProp, hasColors=$canColor');
    }

    if (isPlayer) {
      finalSvg = _modifySvgColors(svgString, playerColors!);
    } else if (isProp) {
      finalSvg = _modifyPropSvgColors(svgString, playerColors!.jersey);
    } else {
      finalSvg = svgString;
    }

    final loader = fsvg.SvgStringLoader(finalSvg);
    final pictureInfo = await fsvg.vg.loadPicture(loader, context);

    final pic = pictureInfo.picture;
    final sz = pictureInfo.size;

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

    pic.dispose();
    outPicture.dispose();

    return img;
  }

  // =========================================================
  // Цвета SVG (props)
  // =========================================================
  String _modifyPropSvgColors(String svg, Color color) {
    final newHex = _colorToCss(color);
    debugPrint('🎨 _modifyPropSvgColors: color=$newHex, len=${svg.length}');

    String modified = svg;
    int cnt = 0;

    String _replaceCssPropHex(String input, String prop) {
      return input.replaceAllMapped(
        RegExp('($prop\\s*:\\s*)#[0-9A-Fa-f]{3,8}', multiLine: true),
        (m) {
          cnt++;
          return '${m.group(1)}$newHex';
        },
      );
    }

    modified = modified.replaceAllMapped(
      RegExp(r'(fill|stroke|stop-color)\s*=\s*"[^"]*"', caseSensitive: false),
      (m) {
        final prop = m.group(1)!.toLowerCase();
        if (m.group(0)!.toLowerCase().contains('="none"')) return m.group(0)!;
        cnt++;
        return '$prop="$newHex"';
      },
    );

    modified = modified.replaceAllMapped(
      RegExp(r"(fill|stroke|stop-color)\s*=\s*'[^']*'", caseSensitive: false),
      (m) {
        final prop = m.group(1)!.toLowerCase();
        if (m.group(0)!.toLowerCase().contains("='none'")) return m.group(0)!;
        cnt++;
        return "$prop='$newHex'";
      },
    );

    modified = modified.replaceAllMapped(
      RegExp(r'style\s*=\s*"[^"]*"', caseSensitive: false),
      (m) {
        var s = m.group(0)!;

        final before = s;
        s = _replaceCssPropHex(s, 'fill');
        s = _replaceCssPropHex(s, 'stroke');
        s = _replaceCssPropHex(s, 'stop-color');

        s = s.replaceAllMapped(
          RegExp(
            r'(fill|stroke|stop-color)\s*:\s*rgb\([^)]+\)',
            caseSensitive: false,
          ),
          (mm) {
            cnt++;
            return '${mm.group(1)}:$newHex';
          },
        );

        return (s == before) ? m.group(0)! : s;
      },
    );

    modified = modified.replaceAllMapped(
      RegExp(r'<style[^>]*>([\s\S]*?)</style>', caseSensitive: false),
      (m) {
        var css = m.group(1)!;

        final before = css;
        css = _replaceCssPropHex(css, 'fill');
        css = _replaceCssPropHex(css, 'stroke');
        css = _replaceCssPropHex(css, 'stop-color');

        css = css.replaceAllMapped(
          RegExp(r'(fill|stroke|stop-color)\s*:\s*#[0-9A-Fa-f]{3,8}', multiLine: true),
          (mm) {
            cnt++;
            return '${mm.group(1)}:$newHex';
          },
        );

        if (css == before) {
          debugPrint('🎨   <style> found but no rules replaced');
        }
        return '<style>$css</style>';
      },
    );

    modified = _replaceCssPropHex(modified, 'fill');
    modified = _replaceCssPropHex(modified, 'stroke');
    modified = _replaceCssPropHex(modified, 'stop-color');

    debugPrint('🎨   Total replacements: $cnt');

    modified = _forceOverrideShapes(modified, color);
    debugPrint('🎨   After override, len=${modified.length}');

    return modified;
  }

  String _forceOverrideShapes(String svg, Color color) {
    final hex = _colorToCss(color);
    String s = svg;

    s = s.replaceAll(
      RegExp('<style[^>]*>[\\s\\S]*?<\\/style>', caseSensitive: false),
      '',
    );

    final tags = <String>[
      'path',
      'rect',
      'circle',
      'ellipse',
      'polygon',
      'polyline',
      'line',
    ];

    for (final t in tags) {
      s = s.replaceAllMapped(
        RegExp('<$t\\b([\\s\\S]*?)(\\/?)>', caseSensitive: false),
        (m) {
          final rawAttrs = (m.group(1) ?? '');
          final closing = (m.group(2) ?? '');
          final isSelfClosing = closing == '/';

          if (rawAttrs.trimLeft().startsWith('/')) return m.group(0)!;

          final hasFillNone = RegExp(
            'fill\\s*=\\s*["\\\']none["\\\']',
            caseSensitive: false,
          ).hasMatch(rawAttrs);

          final hasStrokeNone = RegExp(
            'stroke\\s*=\\s*["\\\']none["\\\']',
            caseSensitive: false,
          ).hasMatch(rawAttrs);

          var newAttrs = rawAttrs;

          newAttrs = newAttrs.replaceAll(
            RegExp('\\sclass\\s*=\\s*["\\\'][^"\\\']*["\\\']', caseSensitive: false),
            '',
          );
          newAttrs = newAttrs.replaceAll(
            RegExp('\\sstyle\\s*=\\s*["\\\'][^"\\\']*["\\\']', caseSensitive: false),
            '',
          );

          newAttrs = newAttrs.replaceAll(
            RegExp('\\sfill\\s*=\\s*["\\\'][^"\\\']*["\\\']', caseSensitive: false),
            '',
          );
          newAttrs = newAttrs.replaceAll(
            RegExp('\\sstroke\\s*=\\s*["\\\'][^"\\\']*["\\\']', caseSensitive: false),
            '',
          );

          final fillPart = hasFillNone ? ' fill="none"' : ' fill="$hex"';
          final strokePart = hasStrokeNone ? ' stroke="none"' : ' stroke="$hex"';

          final end = isSelfClosing ? ' />' : '>';

          return '<$t$newAttrs$fillPart$strokePart$end';
        },
      );
    }

    return s;
  }

  // =========================================================
  // Цвета SVG (players)
  // =========================================================
  String _modifySvgColors(String svg, PlayerColors colors) {
    String modified = svg;

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
  // Loading stamps (PNG/SVG)
  // =========================================================
  void _ensureStampLoadedAny(String asset, {PlayerColors? playerColors}) {
    if (_isSvgAsset(asset)) {
      final String cacheKey = svgCacheKey(asset, playerColors);

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

    if (_stampCache.containsKey(asset)) return;
    if (_stampLoading.containsKey(asset)) return;

    _stampLoading[asset] = _loadAssetImage(asset).then((img) {
      _stampCache[asset] = img;
      _stampLoading.remove(asset);
      if (mounted) setState(() {});
      return img;
    }).catchError((e) {
      _stampLoading.remove(asset);
      debugPrint('❌ stamp load failed: $asset -> $e');
    });
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

    rotationXNotifier = ValueNotifier(0.0);
    rotationYNotifier = ValueNotifier(0.0);

    _is3DMode = state.is3DMode;
    _rotationX = state.rotationX;
    _rotationY = state.rotationY;
    _rotationZ = state.rotationZ;
    _perspective = state.perspective;

    rotationXNotifier.value = _rotationX;
    rotationYNotifier.value = _rotationY;

    _pullMatrixFromState();
    _didInitialFit = _hasSavedViewportMatrix();

    state.addListener(_sync3DFromState);

    _loadField();
    _pushMatrixToState();
    _anim.addListener(_onAnimTick);
  }

  @override
  void dispose() {
    state.removeListener(_sync3DFromState);

    rotationXNotifier.dispose();
    rotationYNotifier.dispose();

    _anim.removeListener(_onAnimTick);
    _anim.dispose();
    super.dispose();
  }

  // =========================================================
  // Public API (fit/reset/zoom selection)
  // =========================================================
  @override
  void fitFieldToViewport(Size viewportSize) {
    if (viewportSize.width <= 0 || viewportSize.height <= 0) return;
    _lastViewportSize = viewportSize;

    final rect = _activeFieldRect();

    const pad = 16.0;
    final vw = math.max(1.0, viewportSize.width - pad * 2);
    final vh = math.max(1.0, viewportSize.height - pad * 2);

    _scale = math.min(vw / rect.width, vh / rect.height).clamp(0.18, 6.0);

    _t = Offset(
      (viewportSize.width - rect.width * _scale) / 2.0 - rect.left * _scale,
      (viewportSize.height - rect.height * _scale) / 2.0 - rect.top * _scale,
    );

    _stopInertia();
    _dragStartScene = null;
    _dragAppliedDelta = Offset.zero;
    _resetPointerSession();

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

    final s = math.min(vw / target.width, vh / target.height).clamp(0.25, 6.0);
    final nextScale = s.clamp(0.25, 6.0);

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
  // Input handling
  // =========================================================
  void _beginPointer(Offset localPos) {
    if (_multiTouchActive) return;

    _stopInertia();

    _downLocal = localPos;
    _downScene = _sceneFromLocal(localPos, clampToField: false);
    _downHitId = _hitTestAtLocal(localPos, _downScene!);

    _dragStartScene = null;
    _dragAppliedDelta = Offset.zero;

    _lastLocal = localPos;
    _lastTsMs = DateTime.now().millisecondsSinceEpoch;
    _velocity = Offset.zero;

    final tool = state.tool;

    if (tool == TgTool.editPoints) {
      _pointerMode = _PointerMode.drawing;

      if (_downHitId != null && !state.selectedIds.contains(_downHitId)) {
        state.selectById(_downHitId!);
      }

      _maybeOpenEditMenuIfNeeded();
      state.onPanStart(_sceneFromLocal(localPos));
      return;
    }

    if (tool != TgTool.select) {
      _pointerMode = _PointerMode.drawing;
      state.onPanStart(_sceneFromLocal(localPos));
      return;
    }

    if (_downHitId != null) {
      if (!state.selectedIds.contains(_downHitId)) {
        state.selectById(_downHitId!);
      }
      _pointerMode = _PointerMode.pendingObjectDrag;
      return;
    }

    _pointerMode = _PointerMode.pendingViewportPan;
  }

  void _updatePointer(Offset localPos) {
    if (_multiTouchActive) return;
    if (_pointerMode == _PointerMode.idle) return;

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

    if (_pointerMode == _PointerMode.drawing || state.tool == TgTool.editPoints) {
      final scene = _sceneFromLocal(localPos);
      state.onPanUpdate(scene);
      return;
    }

    final totalMove = (_downLocal == null) ? 0.0 : (localPos - _downLocal!).distance;

    if (_pointerMode == _PointerMode.pendingObjectDrag) {
      if (totalMove < _dragSlop) return;

      state.commitOnceForGestureStart();
      _pointerMode = _PointerMode.draggingObject;

      final sceneNow = _sceneFromLocal(localPos, clampToField: false);
      _dragStartScene = _downScene ?? sceneNow;
      _dragAppliedDelta = Offset.zero;
    }

    if (_pointerMode == _PointerMode.pendingViewportPan) {
      if (totalMove < _dragSlop) return;
      if (_locked) return;
      _pointerMode = _PointerMode.panningViewport;
    }

    if (_pointerMode == _PointerMode.draggingObject) {
      final sceneNow = _sceneFromLocal(localPos, clampToField: false);

      _dragStartScene ??= sceneNow;

      final deltaTotal = sceneNow - _dragStartScene!;
      final deltaStep = deltaTotal - _dragAppliedDelta;

      _dragAppliedDelta = deltaTotal;
      state.moveSelected(deltaStep);

      if (mounted) setState(() {});
      return;
    }

    if (_pointerMode == _PointerMode.panningViewport) {
      _t += dp;
      _t = _clampTranslation(_t, _scale, _lastViewportSize);
      _pushMatrixToState();
      if (mounted) setState(() {});
      return;
    }
  }

  void _endPointer() {
    if (_pointerMode == _PointerMode.drawing || state.tool == TgTool.editPoints) {
      state.onPanEnd();
      _resetPointerSession();
      return;
    }

    if (_pointerMode == _PointerMode.draggingObject) {
      state.finishGestureCommit();
      _resetPointerSession();
      return;
    }

    if (_pointerMode == _PointerMode.panningViewport) {
      final v = _velocity;
      _resetPointerSession();
      _startInertia(v);
      return;
    }

    if (_pointerMode == _PointerMode.pendingObjectDrag) {
      if (_downHitId != null && !state.selectedIds.contains(_downHitId)) {
        state.selectById(_downHitId!);
      }

      if (_downHitId != null) {
        state.onTap(_sceneFromLocal(_downLocal ?? Offset.zero));
        _maybeOpenEditMenuIfNeeded();
      }

      _resetPointerSession();
      return;
    }

    if (_pointerMode == _PointerMode.pendingViewportPan) {
      state.clearSelection();
      _resetPointerSession();
      return;
    }

    _resetPointerSession();
  }

  // =========================================================
  // Pinch zoom
  // =========================================================
  double _scaleStart = 1.0;
  Offset _tStart = Offset.zero;
  Offset _focalStart = Offset.zero;

  void _onScaleStart(ScaleStartDetails d) {
    if (_locked) return;
    if (state.tool != TgTool.select) return;

    _tapConsumedByScale = false;

    if (_activePointers >= 2) {
      _multiTouchActive = true;
      _tapConsumedByScale = true;
      _resetPointerSession();
    }

    if (!_multiTouchActive) return;

    _stopInertia();
    _scaleStart = _scale;
    _tStart = _t;
    _focalStart = d.focalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    if (_locked) return;
    if (state.tool != TgTool.select) return;
    if (_lastViewportSize == Size.zero) return;
    if (!_multiTouchActive) return;

    final nextScale = (_scaleStart * d.scale).clamp(0.18, 6.0);

    final focal = d.focalPoint;
    final focalDelta = focal - _focalStart;

    final oldT = _tStart + focalDelta;
    final sceneFocal = (focal - oldT) / _scaleStart;

    final newT = focal - sceneFocal * nextScale;

    _scale = nextScale;
    _t = _clampTranslation(newT, _scale, _lastViewportSize);

    _pushMatrixToState();
    if (mounted) setState(() {});
  }

  void _onScaleEnd(ScaleEndDetails d) {
    if (_locked) return;
    if (state.tool != TgTool.select) return;

    if (_multiTouchActive) {
      _bounceToClamp();
    }

    _multiTouchActive = false;
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
                  if (_hasSavedViewportMatrix()) {
                    _pullMatrixFromState();
                    _didInitialFit = true;
                    setState(() {});
                  } else {
                    fitFieldToViewport(_lastViewportSize);
                  }
                }
              });
            }
          }

          return Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (e) {
              _activePointers++;

              if (_activePointers >= 2) {
                _multiTouchActive = true;
                _tapConsumedByScale = true;
                _resetPointerSession();
                return;
              }

              _beginPointer(e.localPosition);
            },
            onPointerMove: (e) {
              if (_multiTouchActive) return;
              _updatePointer(e.localPosition);
            },
            onPointerUp: (_) {
              final wasMultiTouch = _multiTouchActive;

              _activePointers = math.max(0, _activePointers - 1);

              if (wasMultiTouch) {
                if (_activePointers < 2) {
                  _multiTouchActive = false;
                }
                return;
              }

              _endPointer();
            },
            onPointerCancel: (_) {
              _activePointers = math.max(0, _activePointers - 1);

              if (_activePointers < 2) {
                _multiTouchActive = false;
              }

              _resetPointerSession();
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
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
                animation: Listenable.merge([
                  state,
                  rotationXNotifier,
                  rotationYNotifier,
                ]),
                builder: (_, __) {
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
                      svgCacheKey: svgCacheKey,
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
    required this.svgCacheKey,
  }) : super(
          repaint: Listenable.merge([
            state.transform.value,
            state,
          ]),
        );

  final TgState state;
  final ui.Image? fieldImg;
  final Map<String, ui.Image> stampImages;
  final Map<String, ui.Image> stampSvgImages;
  final String Function(String, PlayerColors?) svgCacheKey;

  bool get _is3DMode => state.is3DMode;
  double get _rotationX => state.rotationX;
  double get _rotationY => state.rotationY;
  double get _rotationZ => state.rotationZ;
  double get _perspective => state.perspective;
  Size get _fieldLogicalSize => state.fieldLogicalSize;

  Rect _activeFieldRect() {
    switch (state.fieldView) {
      case TgFieldView.full:
        return Rect.fromLTWH(0, 0, _fieldLogicalSize.width, _fieldLogicalSize.height);
      case TgFieldView.topHalf:
        return Rect.fromLTWH(0, 0, _fieldLogicalSize.width, _fieldLogicalSize.height / 2);
      case TgFieldView.bottomHalf:
        return Rect.fromLTWH(
          0,
          _fieldLogicalSize.height / 2,
          _fieldLogicalSize.width,
          _fieldLogicalSize.height / 2,
        );
      case TgFieldView.leftHalf:
        return Rect.fromLTWH(0, 0, _fieldLogicalSize.width / 2, _fieldLogicalSize.height);
      case TgFieldView.rightHalf:
        return Rect.fromLTWH(
          _fieldLogicalSize.width / 2,
          0,
          _fieldLogicalSize.width / 2,
          _fieldLogicalSize.height,
        );
    }
  }

  bool _fieldContains(Offset p) => _activeFieldRect().inflate(0.01).contains(p);

  vector.Matrix4 _buildField3DMatrix() {
    if (!state.is3DMode) return vector.Matrix4.identity();

    final fs = state.fieldLogicalSize;
    final cx = fs.width / 2.0;
    final cy = fs.height / 2.0;

    final tilt = state.rotationX.clamp(-1.25, 0.0);
    final zRot = state.rotationZ;

    const depth = 420.0;

    return vector.Matrix4.identity()
      ..translate(cx, cy, 0.0)
      ..translate(0.0, 0.0, -depth)
      ..rotateX(tilt)
      ..rotateZ(zRot)
      ..translate(0.0, 0.0, depth)
      ..translate(-cx, -cy, 0.0);
  }

  Offset _projectOnField(Offset p, vector.Matrix4 m3d) {
    if (!_is3DMode) return p;
    final out = m3d.transform(vector.Vector4(p.dx, p.dy, 0.0, 1.0));
    return Offset(out.x, out.y);
  }

  double _billboardScale(Offset p, vector.Matrix4 m3d) {
    if (!_is3DMode) return 1.0;

    final tilt = state.rotationX.abs().clamp(0.0, 1.25);
    final s = (1.0 - tilt * 0.10);
    return s.clamp(0.78, 1.0);
  }

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

  void _paintStampAttachedToField(
    Canvas canvas,
    TgStamp e,
    bool selected, {
    bool isPreview = false,
  }) {
    final scaleNow = _currentScale(state.transform.value.value);
    final isSvg = e.asset.toLowerCase().endsWith('.svg');
    final opacity = e.opacity * (isPreview ? 0.7 : 1.0);
    final cacheKey = svgCacheKey(e.asset, e.playerColors);

    final size = e.size.clamp(20.0, 400.0);

    canvas.save();
    canvas.translate(e.pos.dx, e.pos.dy);
    canvas.rotate(e.rotation);

    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: size,
      height: size,
    );

    if (isSvg) {
      final img = stampSvgImages[cacheKey];
      if (img != null) {
        final src = Rect.fromLTWH(
          0,
          0,
          img.width.toDouble(),
          img.height.toDouble(),
        );
        final dst = _fitContain(rect, img.width.toDouble(), img.height.toDouble());

        if (opacity < 1.0) {
          canvas.saveLayer(rect, Paint()..color = Colors.white.withOpacity(opacity));
          canvas.drawImageRect(
            img,
            src,
            dst,
            Paint()..filterQuality = FilterQuality.high,
          );
          canvas.restore();
        } else {
          canvas.drawImageRect(
            img,
            src,
            dst,
            Paint()..filterQuality = FilterQuality.high,
          );
        }
      } else {
        _drawPlaceholder(canvas, rect, selected, opacity);
      }
    } else {
      final img = stampImages[e.asset];
      if (img != null) {
        final src = Rect.fromLTWH(
          0,
          0,
          img.width.toDouble(),
          img.height.toDouble(),
        );
        final dst = _fitContain(rect, img.width.toDouble(), img.height.toDouble());

        if (opacity < 1.0) {
          canvas.saveLayer(rect, Paint()..color = Colors.white.withOpacity(opacity));
          canvas.drawImageRect(
            img,
            src,
            dst,
            Paint()..filterQuality = FilterQuality.high,
          );
          canvas.restore();
        } else {
          canvas.drawImageRect(
            img,
            src,
            dst,
            Paint()..filterQuality = FilterQuality.high,
          );
        }
      } else {
        _drawPlaceholder(canvas, rect, selected, opacity);
      }
    }

    if (selected) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.inflate(6), const Radius.circular(14)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0 / scaleNow
          ..color = const Color(0xFF00A750),
      );
    }

    canvas.restore();
  }

  void _paintStampBillboard(
    Canvas canvas,
    TgStamp e,
    Offset projectedPos,
    double perspectiveScale,
    bool selected, {
    bool isPreview = false,
  }) {
    final scaleNow = _currentScale(state.transform.value.value);
    final isSvg = e.asset.toLowerCase().endsWith('.svg');
    final opacity = e.opacity * (isPreview ? 0.7 : 1.0);
    final cacheKey = svgCacheKey(e.asset, e.playerColors);

    final size = (e.size * perspectiveScale).clamp(20.0, 400.0);

    canvas.save();
    canvas.translate(projectedPos.dx, projectedPos.dy);
    canvas.rotate(e.rotation);

    final rect = Rect.fromCenter(center: Offset.zero, width: size, height: size);

    if (isSvg) {
      final img = stampSvgImages[cacheKey];
      if (img != null) {
        final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
        final dst = _fitContain(rect, img.width.toDouble(), img.height.toDouble());

        if (opacity < 1.0) {
          canvas.saveLayer(rect, Paint()..color = Colors.white.withOpacity(opacity));
          canvas.drawImageRect(
            img,
            src,
            dst,
            Paint()..filterQuality = FilterQuality.high,
          );
          canvas.restore();
        } else {
          canvas.drawImageRect(
            img,
            src,
            dst,
            Paint()..filterQuality = FilterQuality.high,
          );
        }
      } else {
        _drawPlaceholder(canvas, rect, selected, opacity);
      }
    } else {
      final img = stampImages[e.asset];
      if (img != null) {
        final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
        final dst = _fitContain(rect, img.width.toDouble(), img.height.toDouble());

        if (opacity < 1.0) {
          canvas.saveLayer(rect, Paint()..color = Colors.white.withOpacity(opacity));
          canvas.drawImageRect(
            img,
            src,
            dst,
            Paint()..filterQuality = FilterQuality.high,
          );
          canvas.restore();
        } else {
          canvas.drawImageRect(
            img,
            src,
            dst,
            Paint()..filterQuality = FilterQuality.high,
          );
        }
      } else {
        _drawPlaceholder(canvas, rect, selected, opacity);
      }
    }

    if (selected) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.inflate(6), const Radius.circular(14)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0 / scaleNow
          ..color = const Color(0xFF00A750),
      );
    }

    canvas.restore();
  }

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
    if (_is3DMode) return;

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

    final points = curve.points;

    for (int i = 0; i < points.length; i++) {
      final point = points[i];
      final isSelected = curve.selectedPointIndex == i;

      final PointType type;
      if (curve.curveType == CurveType.line) {
        type = PointType.anchor;
      } else if (curve.curveType == CurveType.quadratic) {
        type = (i == 1) ? PointType.control1 : PointType.anchor;
      } else {
        if (i == 1) {
          type = PointType.control1;
        } else if (i == 2) {
          type = PointType.control2;
        } else {
          type = PointType.anchor;
        }
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

      if (curve.curveType == CurveType.cubic && points.length == 4) {
        if (i == 1) {
          _drawControlLine(canvas, points[0], points[1], scale);
        } else if (i == 2) {
          _drawControlLine(canvas, points[3], points[2], scale);
        }
      } else if (curve.curveType == CurveType.quadratic &&
          points.length == 3 &&
          i == 1) {
        _drawControlLine(canvas, points[0], points[1], scale);
        _drawControlLine(canvas, points[1], points[2], scale);
      }
    }
  }

  void _drawZigzagControlPoints(Canvas canvas, TgEditableZigzag zigzag, double scale) {
    final pointSize = 10.0 / scale;
    final points = zigzag.controlPoints;

    for (int i = 0; i < points.length; i++) {
      final isSelected = zigzag.selectedPointIndex == i;

      Color pointColor;
      if (i == 0 || i == points.length - 1) {
        pointColor = Colors.orange;
      } else {
        pointColor = Colors.cyan;
      }

      final paint = Paint()
        ..style = PaintingStyle.fill
        ..color = isSelected ? Colors.green : pointColor;

      canvas.drawCircle(points[i], pointSize, paint);

      if (isSelected) {
        canvas.drawCircle(
          points[i],
          pointSize * 1.5,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0 / scale
            ..color = Colors.white,
        );
      }
    }
  }

  void _drawSpiralControlPoints(Canvas canvas, TgEditableSpiral spiral, double scale) {
    final pointSize = 10.0 / scale;
    final points = spiral.controlPoints;

    for (int i = 0; i < points.length; i++) {
      final isSelected = spiral.selectedPointIndex == i;

      Color pointColor;
      if (i == 0 || i == points.length - 1) {
        pointColor = Colors.orange;
      } else {
        pointColor = Colors.purple;
      }

      final paint = Paint()
        ..style = PaintingStyle.fill
        ..color = isSelected ? Colors.green : pointColor;

      canvas.drawCircle(points[i], pointSize, paint);

      if (isSelected) {
        canvas.drawCircle(
          points[i],
          pointSize * 1.5,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0 / scale
            ..color = Colors.white,
        );
      }
    }
  }

  void _drawSpringControlPoints(Canvas canvas, TgEditableSpring spring, double scale) {
    final pointSize = 10.0 / scale;
    final points = spring.controlPoints;

    for (int i = 0; i < points.length; i++) {
      final isSelected = spring.selectedPointIndex == i;

      Color pointColor;
      if (i == 0 || i == points.length - 1) {
        pointColor = Colors.orange;
      } else {
        pointColor = Colors.pink;
      }

      final paint = Paint()
        ..style = PaintingStyle.fill
        ..color = isSelected ? Colors.green : pointColor;

      canvas.drawCircle(points[i], pointSize, paint);

      if (isSelected) {
        canvas.drawCircle(
          points[i],
          pointSize * 1.5,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0 / scale
            ..color = Colors.white,
        );
      }
    }
  }

  void _drawWavyControlPoints(Canvas canvas, TgEditableWavy wavy, double scale) {
    final pointSize = 10.0 / scale;
    final points = wavy.controlPoints;

    for (int i = 0; i < points.length; i++) {
      final isSelected = wavy.selectedPointIndex == i;

      Color pointColor;
      if (i == 0 || i == points.length - 1) {
        pointColor = Colors.orange;
      } else {
        pointColor = Colors.tealAccent;
      }

      final paint = Paint()
        ..style = PaintingStyle.fill
        ..color = isSelected ? Colors.green : pointColor;

      canvas.drawCircle(points[i], pointSize, paint);

      if (isSelected) {
        canvas.drawCircle(
          points[i],
          pointSize * 1.5,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0 / scale
            ..color = Colors.white,
        );
      }
    }
  }

  void _paintElement(
    Canvas canvas,
    TgElement e, {
    required bool selected,
    bool isPreview = false,
  }) {
    final scaleNow = _currentScale(state.transform.value.value);

    if (e is TgLine) {
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = e.width / scaleNow
        ..color = e.color.withOpacity(e.opacity);

      if (e.kind == LineKind.dashed) {
        _drawDashedLine(canvas, e.a, e.b, p, dash: 14, gap: 10);
      } else if (e.kind == LineKind.dotted) {
        _drawDashedLine(canvas, e.a, e.b, p, dash: 4, gap: 8);
      } else {
        canvas.drawLine(e.a, e.b, p);
      }

      if (e.end == LineEnd.arrow) {
        _drawArrow(canvas, e.a, e.b, p.color, e.arrowSize);
      }
      return;
    }

    if (e is TgRect) {
      final fill = Paint()
        ..style = PaintingStyle.fill
        ..color = e.fill.withOpacity(e.opacity * (isPreview ? 0.7 : 1.0));
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = e.borderWidth / scaleNow
        ..color = e.border.withOpacity(e.opacity);

      canvas.save();
      canvas.translate(e.position.dx, e.position.dy);
      canvas.rotate(e.rotation);

      final r = Rect.fromCenter(center: Offset.zero, width: e.width, height: e.height);
      final rr = RRect.fromRectAndRadius(r, Radius.circular(e.borderRadius));

      if (e.fill.opacity > 0.0) canvas.drawRRect(rr, fill);

      if (e.borderWidth > 0) {
        if (e.borderKind == BorderKind.dashed) {
          _drawDashedRRect(canvas, rr, stroke, dash: 14, gap: 10);
        } else if (e.borderKind == BorderKind.dotted) {
          _drawDashedRRect(canvas, rr, stroke, dash: 4, gap: 8);
        } else {
          canvas.drawRRect(rr, stroke);
        }
      }

      canvas.restore();
      return;
    }

    if (e is TgCircle) {
      final fill = Paint()
        ..style = PaintingStyle.fill
        ..color = e.fill.withOpacity(e.opacity * (isPreview ? 0.7 : 1.0));
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = e.borderWidth / scaleNow
        ..color = e.border.withOpacity(e.opacity);

      canvas.save();
      canvas.translate(e.position.dx, e.position.dy);
      canvas.rotate(e.rotation);

      if (e.fill.opacity > 0.0) canvas.drawCircle(Offset.zero, e.radius, fill);

      if (e.borderWidth > 0) {
        if (e.borderKind == BorderKind.dashed) {
          _drawDashedCircle(canvas, Offset.zero, e.radius, stroke, dash: 14, gap: 10);
        } else if (e.borderKind == BorderKind.dotted) {
          _drawDashedCircle(canvas, Offset.zero, e.radius, stroke, dash: 4, gap: 8);
        } else {
          canvas.drawCircle(Offset.zero, e.radius, stroke);
        }
      }

      canvas.restore();
      return;
    }

    if (e is TgText) {
      final tp = TextPainter(
        text: TextSpan(
          text: e.text,
          style: TextStyle(
            color: e.color.withOpacity(e.opacity),
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

    if (e is TgStamp) {
      return;
    }

    if (e is TgCurve) {
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = e.width / scaleNow
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
            e.points[1].dx,
            e.points[1].dy,
            e.points[2].dx,
            e.points[2].dy,
          );
        } else if (e.curveType == CurveType.cubic && e.points.length >= 4) {
          path.cubicTo(
            e.points[1].dx,
            e.points[1].dy,
            e.points[2].dx,
            e.points[2].dy,
            e.points[3].dx,
            e.points[3].dy,
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

    if (e is TgSpiral) {
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

      if (e is TgEditableSpiral && e.showControlPoints) {
        _drawSpiralControlPoints(canvas, e, scaleNow);
      }
      return;
    }

    if (e is TgZigzag) {
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

      if (e is TgEditableZigzag && e.showControlPoints) {
        _drawZigzagControlPoints(canvas, e, scaleNow);
      }
      return;
    }

    if (e is TgSpring) {
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

      if (e is TgEditableSpring && e.showControlPoints) {
        _drawSpringControlPoints(canvas, e, scaleNow);
      }
      return;
    }

    if (e is TgWavy) {
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

      if (e is TgEditableWavy && e.showControlPoints) {
        _drawWavyControlPoints(canvas, e, scaleNow);
      }
      return;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF0B0C0E),
    );

    final fieldRect = _activeFieldRect();

    final vp = state.transform.value.value;
    final m3d = _buildField3DMatrix();

    canvas.save();
    canvas.transform(vp.storage);

    canvas.save();
    if (_is3DMode) canvas.transform(m3d.storage);

    canvas.save();
    canvas.clipRect(fieldRect);

    _paintFieldCover(canvas, fieldRect);

    if (state.gridEnabled && !_is3DMode) {
      _paintGrid(canvas, fieldRect);
    }

    for (final e in state.elements) {
      final selected = state.selectedIds.contains(e.id);

      if (e is TgStamp) {
        if (!_fieldContains(e.pos)) continue;

        // ✅ Ворота и другие "прикреплённые к полю" штампы
        if (_isFieldAttachedStampAsset(e.asset)) {
          _paintStampAttachedToField(canvas, e, selected);
        }
        continue;
      }

      final bounds = e.bounds();
      if (!bounds.overlaps(fieldRect.inflate(2))) continue;

      _paintElement(canvas, e, selected: selected);
    }

    final prev = state.previewElement;
    if (prev != null) {
      if (prev is TgStamp) {
        if (_fieldContains(prev.pos) && _isFieldAttachedStampAsset(prev.asset)) {
          _paintStampAttachedToField(
            canvas,
            prev,
            false,
            isPreview: true,
          );
        }
      } else {
        _paintElement(canvas, prev, selected: false, isPreview: true);
      }
    }

    canvas.restore(); // clip
    canvas.restore(); // field transform

    for (final e in state.elements) {
      if (e is! TgStamp) continue;
      if (!_fieldContains(e.pos)) continue;

      // ✅ Ворота уже отрисованы вместе с полем
      if (_isFieldAttachedStampAsset(e.asset)) continue;

      final selected = state.selectedIds.contains(e.id);

      final projected = _is3DMode ? _projectOnField(e.pos, m3d) : e.pos;
      final s = _is3DMode ? _billboardScale(e.pos, m3d) : 1.0;

      _paintStampBillboard(canvas, e, projected, s, selected);
    }

    if (prev is TgStamp &&
        _fieldContains(prev.pos) &&
        !_isFieldAttachedStampAsset(prev.asset)) {
      final projected = _is3DMode ? _projectOnField(prev.pos, m3d) : prev.pos;
      final s = _is3DMode ? _billboardScale(prev.pos, m3d) : 1.0;

      _paintStampBillboard(canvas, prev, projected, s, false, isPreview: true);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TgBoardPainter oldDelegate) {
    return oldDelegate.state != state ||
        oldDelegate.fieldImg != fieldImg ||
        oldDelegate.stampImages != stampImages ||
        oldDelegate.stampSvgImages != stampSvgImages ||
        oldDelegate._is3DMode != _is3DMode ||
        oldDelegate._rotationX != _rotationX ||
        oldDelegate._rotationY != _rotationY ||
        oldDelegate._rotationZ != _rotationZ ||
        oldDelegate._perspective != _perspective;
  }
}