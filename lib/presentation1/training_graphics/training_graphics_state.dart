// lib/presentation/training_graphics/training_graphics_state.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as v;

import 'package:sportoteka/presentation/training_graphics/tg_models.dart';

enum TgTool {
  select,
  line,
  rect,
  circle,
  text,
  stamp,
  curve,
  zigzag,
  spring,
  spiral,
  editPoints,
  wavy,
}

enum TgFieldView {
  full,
  topHalf,
  bottomHalf,
  leftHalf,
  rightHalf,
}

/// Viewport transform helper used by TgCanvas:
/// - state.transform.value is ValueNotifier<Matrix4>
/// - state.transform.toScene(local) converts screen/local -> scene coords
class TgViewportTransform {
  TgViewportTransform([Matrix4? initial])
      : value = ValueNotifier<Matrix4>(initial ?? Matrix4.identity());

  final ValueNotifier<Matrix4> value;

  Offset toScene(Offset local) {
    final m = value.value;
    Matrix4 inv;
    try {
      inv = Matrix4.inverted(m);
    } catch (_) {
      inv = Matrix4.identity();
    }
    final p = v.Vector3(local.dx, local.dy, 0);
    final r = inv.transform3(p);
    return Offset(r.x, r.y);
  }

  Offset toLocal(Offset scene) {
    final m = value.value;
    final p = v.Vector3(scene.dx, scene.dy, 0);
    final r = m.transform3(p);
    return Offset(r.x, r.y);
  }
}

class TgState extends ChangeNotifier {
  TgState({
    required this.teamId,
    required this.teamName,
  });

  // ===== 3D параметры =====
  bool is3DMode = false;
  double rotationX = 0.0;
  double rotationY = 0.0;
  double rotationZ = 0.0;
  double perspective = 0.0008;
  Size fieldLogicalSize = const Size(1050, 680);

  void set3DParams({
    required bool enabled,
    double? rotationX,
    double? rotationY,
    double? rotationZ,
    double? perspective,
    Size? fieldSize,
    bool notify = true,
  }) {
    print(
      '🎮 set3DParams BEFORE: enabled=${this.is3DMode}, '
      'rx=${this.rotationX}, ry=${this.rotationY}, rz=${this.rotationZ}',
    );

    is3DMode = enabled;

    if (rotationX != null) this.rotationX = rotationX;
    if (rotationY != null) this.rotationY = rotationY;
    if (rotationZ != null) this.rotationZ = rotationZ;
    if (perspective != null) this.perspective = perspective;
    if (fieldSize != null) fieldLogicalSize = fieldSize;

    print(
      '🎮 set3DParams AFTER: enabled=$is3DMode, '
      'rx=$rotationX, ry=$rotationY, rz=$rotationZ',
    );

    if (notify) notifyListeners();
  }

  void toggle3DMode() {
    set3DParams(enabled: !is3DMode);
  }

  void reset3D() {
    set3DParams(
      enabled: false,
      rotationX: 0.0,
      rotationY: 0.0,
      rotationZ: 0.0,
    );
  }

  bool continuousDrawMode = false;

  void toggleContinuousDrawMode() {
    print('🎯 [TgState] toggleContinuousDrawMode CALLED!');
    print('🎯 [TgState] before = $continuousDrawMode');
    continuousDrawMode = !continuousDrawMode;
    print('🎯 [TgState] after = $continuousDrawMode');
    notifyListeners();
  }

  void updateSelectedWavy({
    Offset? start,
    Offset? endPoint,
    List<Offset>? controlPoints,
    Color? color,
    double? width,
    LineKind? kind,
    double? opacity,
    double? amplitude,
    double? wavelength,
    double? phase,
    LineEnd? lineEnd,
    double? arrowSize,
    TgStrokeCap? cap,
    TgStrokeJoin? join,
    List<double>? dash,
  }) {
    if (selectedIds.isEmpty) return;

    final id = selectedIds.first;
    final index = _elements.indexWhere((e) => e.id == id);
    if (index < 0) return;

    final element = _elements[index];
    if (element is! TgWavy) return;

    final updated = element.copyWith(
      start: start,
      endPoint: endPoint,
      controlPoints: controlPoints,
      color: color,
      width: width,
      kind: kind,
      opacity: opacity,
      amplitude: amplitude,
      wavelength: wavelength,
      phase: phase,
      lineEnd: lineEnd,
      arrowSize: arrowSize,
      cap: cap,
      join: join,
      dash: dash,
    );

    _elements[index] = updated;
    notifyListeners();
  }

  void editWavyPoints() {
    if (selectedIds.isEmpty) return;

    final id = selectedIds.first;
    final index = _elements.indexWhere((e) => e.id == id);
    if (index < 0) return;

    final element = _elements[index];
    if (element is! TgWavy) return;

    final editable = TgEditableWavy(
      id: element.id,
      start: element.start,
      endPoint: element.endPoint,
      controlPoints: element.controlPoints,
      color: element.color,
      width: element.width,
      kind: element.kind,
      opacity: element.opacity,
      amplitude: element.amplitude,
      wavelength: element.wavelength,
      phase: element.phase,
      lineEnd: element.lineEnd,
      arrowSize: element.arrowSize,
      cap: element.cap,
      join: element.join,
      dash: element.dash,
      locked: element.locked,
      hidden: element.hidden,
      layer: element.layer,
      name: element.name,
      createdAt: element.createdAt,
      showControlPoints: true,
      selectedPointIndex: -1,
    );

    _elements[index] = editable;
    setTool(TgTool.editPoints);
    notifyListeners();
  }

  List<Offset> _smoothPoints(List<Offset> points, {double factor = 0.3}) {
    if (points.length < 3) return points;

    final smoothed = <Offset>[];
    smoothed.add(points.first);

    for (int i = 1; i < points.length - 1; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      final next = points[i + 1];

      final smoothX = (prev.dx + curr.dx * 2 + next.dx) / 4;
      final smoothY = (prev.dy + curr.dy * 2 + next.dy) / 4;

      smoothed.add(Offset(smoothX, smoothY));
    }

    smoothed.add(points.last);
    return smoothed;
  }

  void replaceElement(
    TgElement updated, {
    bool commitUndo = false,
    bool keepSelection = true,
    TgTool? setTool,
  }) {
    final idx = _elements.indexWhere((e) => e.id == updated.id);
    if (idx < 0) {
      debugPrint('⚠️ replaceElement: element ${updated.id} not found');
      return;
    }

    if (commitUndo) _commitUndo();

    _elements[idx] = updated;

    if (keepSelection) {
      if (!selectedIds.contains(updated.id)) {
        selectedIds
          ..clear()
          ..add(updated.id);
      }
    }

    if (setTool != null) tool = setTool;

    notifyListeners();
  }

  int? _hitEditablePoint(TgElement? sel, Offset scene, {double tolerance = 25}) {
    if (sel == null) return null;

    if (sel is TgEditableCurve && sel.showControlPoints) {
      for (int i = 0; i < sel.points.length; i++) {
        if ((sel.points[i] - scene).distance <= tolerance) return i;
      }
    }

    if (sel is TgEditableZigzag && sel.showControlPoints) {
      for (int i = 0; i < sel.controlPoints.length; i++) {
        if ((sel.controlPoints[i] - scene).distance <= tolerance) return i;
      }
    }

    if (sel is TgEditableSpring && sel.showControlPoints) {
      for (int i = 0; i < sel.controlPoints.length; i++) {
        if ((sel.controlPoints[i] - scene).distance <= tolerance) return i;
      }
    }

    if (sel is TgEditableSpiral && sel.showControlPoints) {
      for (int i = 0; i < sel.controlPoints.length; i++) {
        if ((sel.controlPoints[i] - scene).distance <= tolerance) return i;
      }
    }

    if (sel is TgEditableWavy && sel.showControlPoints) {
      for (int i = 0; i < sel.controlPoints.length; i++) {
        if ((sel.controlPoints[i] - scene).distance <= tolerance) return i;
      }
    }

    return null;
  }

  void _setEditableSelectedPoint(TgElement sel, int pointIndex) {
    final idx = _elements.indexWhere((e) => e.id == sel.id);
    if (idx < 0) return;

    if (sel is TgEditableCurve) {
      _elements[idx] = sel.copyWith(selectedPointIndex: pointIndex);
    } else if (sel is TgEditableZigzag) {
      _elements[idx] = sel.copyWith(selectedPointIndex: pointIndex);
    } else if (sel is TgEditableSpring) {
      _elements[idx] = sel.copyWith(selectedPointIndex: pointIndex);
    } else if (sel is TgEditableSpiral) {
      _elements[idx] = sel.copyWith(selectedPointIndex: pointIndex);
    } else if (sel is TgEditableWavy) {
      _elements[idx] = sel.copyWith(selectedPointIndex: pointIndex);
    }
  }

  void _finishEditableMode(TgElement sel) {
    final idx = _elements.indexWhere((e) => e.id == sel.id);
    if (idx < 0) return;

    if (sel is TgEditableCurve) {
      final updated = sel.copyWith(
        showControlPoints: false,
        selectedPointIndex: -1,
      );
      _elements[idx] = updated;
      selectById(updated.id);
    } else if (sel is TgEditableZigzag) {
      final updated = sel.copyWith(
        showControlPoints: false,
        selectedPointIndex: -1,
      );
      _elements[idx] = updated;
      selectById(updated.id);
    } else if (sel is TgEditableSpring) {
      final updated = sel.copyWith(
        showControlPoints: false,
        selectedPointIndex: -1,
      );
      _elements[idx] = updated;
      selectById(updated.id);
    } else if (sel is TgEditableSpiral) {
      final updated = sel.copyWith(
        showControlPoints: false,
        selectedPointIndex: -1,
      );
      _elements[idx] = updated;
      selectById(updated.id);
    } else if (sel is TgEditableWavy) {
      final updated = sel.copyWith(
        showControlPoints: false,
        selectedPointIndex: -1,
      );
      _elements[idx] = updated;
      selectById(updated.id);
    }

    tool = TgTool.select;
  }

  final int teamId;
  final String teamName;

  // ===== viewport / modes =====
  final TgViewportTransform transform = TgViewportTransform();

  /// Режим редактирования поля / камеры
  bool fieldEditMode = false;

  /// Блокирует только жесты камеры, но не постановку объектов
  bool lockViewportGestures = false;

  /// Режим многократной постановки выбранного объекта/штампа
  bool stickyStampMode = true;

  /// Вариант отображения поля
  TgFieldView fieldView = TgFieldView.full;

  void setLockViewport(bool v) {
    lockViewportGestures = v;
    notifyListeners();
  }

  void toggleFieldEditMode() {
    fieldEditMode = !fieldEditMode;
    notifyListeners();
  }

  void toggleStickyStampMode() {
    stickyStampMode = !stickyStampMode;
    notifyListeners();
  }

  void setStickyStampMode(bool value) {
    if (stickyStampMode == value) return;
    stickyStampMode = value;
    notifyListeners();
  }

  void setFieldView(TgFieldView view) {
    if (fieldView == view) return;
    fieldView = view;
    notifyListeners();
  }

  void updateSelectedStamp({
    double? size,
    double? opacity,
    double? rotation,
    Color? color,
    PlayerColors? playerColors,
  }) {
    final sel = selected;
    if (sel is! TgStamp) return;

    _commitUndo();
    final idx = _elements.indexWhere((e) => e.id == sel.id);
    if (idx < 0) return;

    print('🎨 Updating stamp colors: ${playerColors?.jersey}');

    if (playerColors != null) {
      print('🎨 Clearing cache for ${sel.asset}');
    }

    _elements[idx] = sel.copyWith(
      size: size?.clamp(20.0, 260.0) ?? sel.size,
      opacity: opacity?.clamp(0.0, 1.0) ?? sel.opacity,
      rotation: rotation ?? sel.rotation,
      color: color ?? sel.color,
      playerColors: playerColors ?? sel.playerColors,
    );
    notifyListeners();
  }

  void resetStampColors() {
    final sel = selected;
    if (sel is! TgStamp) return;
    if (!sel.asset.contains('/player_')) return;

    _commitUndo();
    final idx = _elements.indexWhere((e) => e.id == sel.id);
    if (idx < 0) return;

    _elements[idx] = sel.copyWith(
      playerColors: null,
    );
    notifyListeners();
  }

  // ===== top editor (collapse/expand) =====
  bool topEditorCollapsed = false;

  void toggleTopEditor() {
    topEditorCollapsed = !topEditorCollapsed;
    notifyListeners();
  }

  // ===== grid =====
  bool gridEnabled = false;
  double gridStep = 22;

  void toggleGrid() {
    gridEnabled = !gridEnabled;
    notifyListeners();
  }

  // ===== snap rotation =====
  bool snapRotationEnabled = true;
  double snapRotationDegrees = 15;

  void setSnapRotation({required bool enabled, required double degrees}) {
    snapRotationEnabled = enabled;
    snapRotationDegrees = degrees.clamp(1, 90).toDouble();
    notifyListeners();
  }

  double snapRotation(double radians) {
    final step = snapRotationDegrees * math.pi / 180.0;
    if (step <= 0) return radians;
    return (radians / step).round() * step;
  }

  // ===== tool =====
  TgTool tool = TgTool.select;

  void setTool(TgTool t) {
    tool = t;
    _preview = null;
    _panStart = null;
    _lastPan = null;
    notifyListeners();
  }

  // ===== stamps palette =====
  String? _activeStampAsset;
  String? get activeStampAsset => _activeStampAsset;

  void setActiveStamp(String asset) {
    _activeStampAsset = asset;
    tool = TgTool.stamp;
    notifyListeners();
  }

  void clearActiveStamp() {
    _activeStampAsset = null;
    if (tool == TgTool.stamp) {
      tool = TgTool.select;
    }
    notifyListeners();
  }

  double _defaultStampSize(String asset) {
    final a = asset.toLowerCase();

    if (a.contains('ball') || a.contains('myach')) return 22;
    if (a.contains('cone')) return 34;
    if (a.contains('pole')) return 34;
    if (a.contains('ring')) return 34;
    if (a.contains('flag')) return 34;
    if (a.contains('ladder')) return 70;
    if (a.contains('dummy')) return 56;

    if (a.contains('/run_svg/') ||
        a.contains('/pass_svg/') ||
        a.contains('/jump_svg/') ||
        a.contains('/stand_svg/') ||
        a.contains('/vrat_svg/') ||
        a.contains('/player_') ||
        a.contains('/coach/')) {
      return 90;
    }

    if (a.contains('/vorota1/')) return 120;

    return 64;
  }

  // ===== elements / selection =====
  final List<TgElement> _elements = <TgElement>[];
  List<TgElement> get elements => List.unmodifiable(_elements);

  TgElement? _preview;
  TgElement? get previewElement => _preview;

  final Set<String> selectedIds = <String>{};
  String? get selectedId => selectedIds.isEmpty ? null : selectedIds.first;

  TgElement? get selected {
    final id = selectedId;
    if (id == null) return null;
    final idx = _elements.indexWhere((e) => e.id == id);
    if (idx < 0) return null;
    return _elements[idx];
  }

  bool get hasMultiSelection => selectedIds.length > 1;

  void clearSelection() {
    selectedIds.clear();
    notifyListeners();
  }

  void selectById(String id) {
    selectedIds
      ..clear()
      ..add(id);

    tool = TgTool.select;

    _preview = null;
    _panStart = null;
    _lastPan = null;
    _gestureBase = null;

    notifyListeners();
  }

  void selectMultiple(Set<String> ids) {
    selectedIds
      ..clear()
      ..addAll(ids);

    tool = TgTool.select;

    _preview = null;
    _panStart = null;
    _lastPan = null;
    _gestureBase = null;

    notifyListeners();
  }

  Rect selectionBounds() {
    if (selectedIds.isEmpty) return Rect.zero;
    Rect? r;
    for (final id in selectedIds) {
      final idx = _elements.indexWhere((x) => x.id == id);
      if (idx < 0) continue;
      final b = _elements[idx].bounds();
      r = (r == null) ? b : r!.expandToInclude(b);
    }
    return r ?? Rect.zero;
  }

  // ====== hit test ======
  String? hitTest(Offset scene) {
    for (int i = _elements.length - 1; i >= 0; i--) {
      final e = _elements[i];
      if (e.hitTest(scene)) return e.id;
    }
    return null;
  }

  // ====== ordering ======
  void bringToFront() {
    if (selectedIds.isEmpty) return;
    final ids = selectedIds.toList();
    for (final id in ids) {
      final idx = _elements.indexWhere((e) => e.id == id);
      if (idx >= 0) {
        final e = _elements.removeAt(idx);
        _elements.add(e);
      }
    }
    notifyListeners();
  }

  void sendToBack() {
    if (selectedIds.isEmpty) return;
    final ids = selectedIds.toList();
    for (final id in ids.reversed) {
      final idx = _elements.indexWhere((e) => e.id == id);
      if (idx >= 0) {
        final e = _elements.removeAt(idx);
        _elements.insert(0, e);
      }
    }
    notifyListeners();
  }

  void deleteSelected() {
    if (selectedIds.isEmpty) return;
    _commitUndo();
    _elements.removeWhere((e) => selectedIds.contains(e.id));
    selectedIds.clear();
    _preview = null;
    _panStart = null;
    _lastPan = null;
    _gestureBase = null;
    notifyListeners();
  }

  void duplicateSelected() {
    final sel = selected;
    if (sel == null) return;

    _commitUndo();

    const dx = 18.0;
    const dy = 18.0;

    TgElement copy;
    if (sel is TgLine) {
      copy = sel.copyWith(
        id: _newId(),
        a: sel.a + const Offset(dx, dy),
        b: sel.b + const Offset(dx, dy),
      );
    } else if (sel is TgRect) {
      copy = sel.copyWith(
        id: _newId(),
        position: sel.position + const Offset(dx, dy),
      );
    } else if (sel is TgCircle) {
      copy = sel.copyWith(
        id: _newId(),
        position: sel.position + const Offset(dx, dy),
      );
    } else if (sel is TgText) {
      copy = sel.copyWith(
        id: _newId(),
        position: sel.position + const Offset(dx, dy),
      );
    } else if (sel is TgStamp) {
      copy = sel.copyWith(id: _newId(), pos: sel.pos + const Offset(dx, dy));
    } else if (sel is TgEditableCurve) {
      copy = sel.copyWith(
        id: _newId(),
        points: sel.points.map((p) => p + const Offset(dx, dy)).toList(),
      );
    } else if (sel is TgEditableWavy) {
      copy = sel.copyWith(
        id: _newId(),
        start: sel.start + const Offset(dx, dy),
        endPoint: sel.endPoint + const Offset(dx, dy),
        controlPoints:
            sel.controlPoints.map((p) => p + const Offset(dx, dy)).toList(),
      );
    } else if (sel is TgWavy) {
      copy = sel.copyWith(
        id: _newId(),
        start: sel.start + const Offset(dx, dy),
        endPoint: sel.endPoint + const Offset(dx, dy),
        controlPoints:
            sel.controlPoints.map((p) => p + const Offset(dx, dy)).toList(),
      );
    } else if (sel is TgEditableZigzag) {
      copy = sel.copyWith(
        id: _newId(),
        start: sel.start + const Offset(dx, dy),
        endPoint: sel.endPoint + const Offset(dx, dy),
        controlPoints:
            sel.controlPoints.map((p) => p + const Offset(dx, dy)).toList(),
      );
    } else if (sel is TgEditableSpring) {
      copy = sel.copyWith(
        id: _newId(),
        start: sel.start + const Offset(dx, dy),
        endPoint: sel.endPoint + const Offset(dx, dy),
        controlPoints:
            sel.controlPoints.map((p) => p + const Offset(dx, dy)).toList(),
      );
    } else if (sel is TgEditableSpiral) {
      copy = sel.copyWith(
        id: _newId(),
        start: sel.start + const Offset(dx, dy),
        endPoint: sel.endPoint + const Offset(dx, dy),
        controlPoints:
            sel.controlPoints.map((p) => p + const Offset(dx, dy)).toList(),
      );
    } else {
      return;
    }

    _elements.add(copy);
    selectById(copy.id);
    notifyListeners();
  }

  // ====== editing helpers used by props bars ======
  void updateSelectedLine({
    Color? color,
    double? width,
    LineKind? kind,
    LineEnd? end,
    double? arrow,
    double? opacity,
    TgStrokeCap? cap,
    TgStrokeJoin? join,
    List<double>? dash,
    bool dashToNull = false,
    TgLineCurve? curveMode,
    double? curveAmount,
    Offset? a,
    Offset? b,
  }) {
    final sel = selected;

    if (sel is TgEditableCurve) {
      updateSelectedCurve(
        color: color,
        width: width,
        kind: kind,
        end: end,
        arrowSize: arrow,
        opacity: opacity,
      );
      return;
    }

    if (sel is! TgLine) return;

    _commitUndo();
    final idx = _elements.indexWhere((e) => e.id == sel.id);
    if (idx < 0) return;

    _elements[idx] = sel.copyWith(
      color: color ?? sel.color,
      width: width ?? sel.width,
      kind: kind ?? sel.kind,
      end: end ?? sel.end,
      arrowSize: arrow ?? sel.arrowSize,
      opacity: opacity ?? sel.opacity,
      cap: cap ?? sel.cap,
      join: join ?? sel.join,
      dash: dashToNull ? null : (dash ?? sel.dash),
      curveMode: curveMode ?? sel.curveMode,
      curveAmount: curveAmount ?? sel.curveAmount,
      a: a ?? sel.a,
      b: b ?? sel.b,
    );
    notifyListeners();
  }

  void updateSelectedShape({
    Color? fill,
    double? opacity,
    Color? border,
    double? borderW,
    BorderKind? kind,
    double? borderRadius,
    double? radius,
  }) {
    final sel = selected;
    if (sel == null) return;

    _commitUndo();
    final idx = _elements.indexWhere((e) => e.id == sel.id);
    if (idx < 0) return;

    if (sel is TgRect) {
      _elements[idx] = sel.copyWith(
        fill: fill ?? sel.fill,
        opacity: opacity ?? sel.opacity,
        border: border ?? sel.border,
        borderWidth: borderW ?? sel.borderWidth,
        borderKind: kind ?? sel.borderKind,
        borderRadius: borderRadius ?? sel.borderRadius,
      );
    } else if (sel is TgCircle) {
      _elements[idx] = sel.copyWith(
        fill: fill ?? sel.fill,
        opacity: opacity ?? sel.opacity,
        border: border ?? sel.border,
        borderWidth: borderW ?? sel.borderWidth,
        borderKind: kind ?? sel.borderKind,
        radius: radius ?? sel.radius,
      );
    }
    notifyListeners();
  }

  void updateSelectedText({
    String? text,
    Color? color,
    double? opacity,
    double? size,
    TgTextStyle? style,
    FontWeight? weight,
    TextAlign? align,
  }) {
    final sel = selected;
    if (sel is! TgText) return;

    _commitUndo();
    final idx = _elements.indexWhere((e) => e.id == sel.id);
    if (idx < 0) return;

    _elements[idx] = sel.copyWith(
      text: text ?? sel.text,
      color: color ?? sel.color,
      opacity: opacity ?? sel.opacity,
      size: size ?? sel.size,
      style: style ?? sel.style,
      weight: weight ?? sel.weight,
      alignment: align ?? sel.alignment,
    );
    notifyListeners();
  }

  void setSelectedStampOpacity(double o) {
    final sel = selected;
    if (sel is! TgStamp) return;

    _commitUndo();
    final idx = _elements.indexWhere((e) => e.id == sel.id);
    if (idx < 0) return;

    _elements[idx] = sel.copyWith(opacity: o.clamp(0.0, 1.0));
    notifyListeners();
  }

  void setSelectedStampSize(double size) {
    final sel = selected;
    if (sel is! TgStamp) return;

    _commitUndo();
    final idx = _elements.indexWhere((e) => e.id == sel.id);
    if (idx < 0) return;

    _elements[idx] = sel.copyWith(size: size.clamp(20.0, 260.0));
    notifyListeners();
  }

  void rotateSelected(double deltaRadians) {
    final sel = selected;
    if (sel == null) return;

    _commitUndo();
    final idx = _elements.indexWhere((e) => e.id == sel.id);
    if (idx < 0) return;

    if (sel is TgRect) {
      _elements[idx] = sel.copyWith(rotation: sel.rotation + deltaRadians);
    }
    if (sel is TgCircle) {
      _elements[idx] = sel.copyWith(rotation: sel.rotation + deltaRadians);
    }
    if (sel is TgText) {
      _elements[idx] = sel.copyWith(rotation: sel.rotation + deltaRadians);
    }
    if (sel is TgStamp) {
      _elements[idx] = sel.copyWith(rotation: sel.rotation + deltaRadians);
    }
    if (sel is TgEditableCurve) {
      _elements[idx] = sel.copyWith();
    }

    notifyListeners();
  }

  void setSelectedRotationAbsolute(double radians) {
    final sel = selected;
    if (sel == null) return;

    _commitUndo();
    final idx = _elements.indexWhere((e) => e.id == sel.id);
    if (idx < 0) return;

    if (sel is TgRect) {
      _elements[idx] = sel.copyWith(rotation: radians);
    }
    if (sel is TgCircle) {
      _elements[idx] = sel.copyWith(rotation: radians);
    }
    if (sel is TgText) {
      _elements[idx] = sel.copyWith(rotation: radians);
    }
    if (sel is TgStamp) {
      _elements[idx] = sel.copyWith(rotation: radians);
    }

    notifyListeners();
  }

  double getSelectedRotation() {
    final sel = selected;
    if (sel is TgRect) return sel.rotation;
    if (sel is TgCircle) return sel.rotation;
    if (sel is TgText) return sel.rotation;
    if (sel is TgStamp) return sel.rotation;
    return 0.0;
  }

  void scaleSelectedBy(double factor) {
    final sel = selected;
    if (sel == null) return;

    _commitUndo();
    final idx = _elements.indexWhere((e) => e.id == sel.id);
    if (idx < 0) return;

    final f = factor.clamp(0.25, 4.0);

    if (sel is TgStamp) {
      _elements[idx] = sel.copyWith(
        size: (sel.size * f).clamp(20.0, 260.0),
      );
    } else if (sel is TgRect) {
      _elements[idx] = sel.copyWith(
        width: (sel.width * f).clamp(20.0, 2000.0),
        height: (sel.height * f).clamp(20.0, 2000.0),
      );
    } else if (sel is TgCircle) {
      _elements[idx] = sel.copyWith(
        radius: (sel.radius * f).clamp(10.0, 1200.0),
      );
    } else if (sel is TgText) {
      _elements[idx] = sel.copyWith(
        size: (sel.size * f).clamp(8.0, 220.0),
      );
    } else if (sel is TgLine) {
      _elements[idx] = sel.copyWith(
        width: (sel.width * f).clamp(1.0, 60.0),
      );
    }

    notifyListeners();
  }

  // ===== gesture-driven move/transform from TgCanvas =====
  Map<String, TgElement>? _gestureBase;

  void commitOnceForGestureStart() {
    if (selectedIds.isEmpty) return;
    _commitUndo();
    _gestureBase = {
      for (final id in selectedIds) id: _elements.firstWhere((e) => e.id == id),
    };
  }

  void finishGestureCommit() {
    _gestureBase = null;
    notifyListeners();
  }

  void moveSelected(Offset delta) {
    if (selectedIds.isEmpty) return;

    for (final id in selectedIds) {
      final idx = _elements.indexWhere((e) => e.id == id);
      if (idx < 0) continue;
      final e = _elements[idx];

      if (e is TgLine) {
        _elements[idx] = e.copyWith(a: e.a + delta, b: e.b + delta);
      } else if (e is TgRect) {
        _elements[idx] = e.copyWith(position: e.position + delta);
      } else if (e is TgCircle) {
        _elements[idx] = e.copyWith(position: e.position + delta);
      } else if (e is TgText) {
        _elements[idx] = e.copyWith(position: e.position + delta);
      } else if (e is TgStamp) {
        _elements[idx] = e.copyWith(pos: e.pos + delta);
      } else if (e is TgEditableCurve) {
        _elements[idx] = e.copyWith(
          points: e.points.map((p) => p + delta).toList(),
        );
      } else if (e is TgWavy) {
        _elements[idx] = e.copyWith(
          start: e.start + delta,
          endPoint: e.endPoint + delta,
          controlPoints: e.controlPoints.map((p) => p + delta).toList(),
        );
      } else if (e is TgZigzag) {
        _elements[idx] = e.copyWith(
          start: e.start + delta,
          endPoint: e.endPoint + delta,
        );
        if (e is TgEditableZigzag) {
          _elements[idx] = e.copyWith(
            start: e.start + delta,
            endPoint: e.endPoint + delta,
            controlPoints: e.controlPoints.map((p) => p + delta).toList(),
          );
        }
      } else if (e is TgSpring) {
        _elements[idx] = e.copyWith(
          start: e.start + delta,
          endPoint: e.endPoint + delta,
        );
        if (e is TgEditableSpring) {
          _elements[idx] = e.copyWith(
            start: e.start + delta,
            endPoint: e.endPoint + delta,
            controlPoints: e.controlPoints.map((p) => p + delta).toList(),
          );
        }
      } else if (e is TgSpiral) {
        _elements[idx] = e.copyWith(
          start: e.start + delta,
          endPoint: e.endPoint + delta,
        );
        if (e is TgEditableSpiral) {
          _elements[idx] = e.copyWith(
            start: e.start + delta,
            endPoint: e.endPoint + delta,
            controlPoints: e.controlPoints.map((p) => p + delta).toList(),
          );
        }
      }
    }
    notifyListeners();
  }

  void transformSelected({
    required Offset moveDelta,
    required double absoluteRotation,
    required double absoluteScaleBase,
  }) {
    if (selectedIds.isEmpty) return;
    final base = _gestureBase;
    if (base == null || base.isEmpty) return;

    final scaleFactor = (absoluteScaleBase / 100.0).clamp(0.25, 4.0);

    for (final id in selectedIds) {
      final idx = _elements.indexWhere((e) => e.id == id);
      if (idx < 0) continue;

      final b = base[id];
      if (b == null) continue;

      if (b is TgStamp) {
        _elements[idx] = b.copyWith(
          pos: b.pos + moveDelta,
          rotation: absoluteRotation,
          size: (b.size * scaleFactor).clamp(20.0, 260.0),
        );
      } else if (b is TgRect) {
        _elements[idx] = b.copyWith(
          position: b.position + moveDelta,
          rotation: absoluteRotation,
          width: (b.width * scaleFactor).clamp(20.0, 2000.0),
          height: (b.height * scaleFactor).clamp(20.0, 2000.0),
        );
      } else if (b is TgCircle) {
        _elements[idx] = b.copyWith(
          position: b.position + moveDelta,
          rotation: absoluteRotation,
          radius: (b.radius * scaleFactor).clamp(10.0, 1200.0),
        );
      } else if (b is TgText) {
        _elements[idx] = b.copyWith(
          position: b.position + moveDelta,
          rotation: absoluteRotation,
          size: (b.size * scaleFactor).clamp(8.0, 220.0),
        );
      } else if (b is TgLine) {
        _elements[idx] = b.copyWith(
          a: b.a + moveDelta,
          b: b.b + moveDelta,
        );
      } else if (b is TgEditableCurve) {
        _elements[idx] = b.copyWith(
          points: b.points.map((p) => p + moveDelta).toList(),
        );
      } else if (b is TgWavy) {
        _elements[idx] = b.copyWith(
          start: b.start + moveDelta,
          endPoint: b.endPoint + moveDelta,
          controlPoints: b.controlPoints.map((p) => p + moveDelta).toList(),
        );
      } else if (b is TgZigzag) {
        if (b is TgEditableZigzag) {
          _elements[idx] = b.copyWith(
            start: b.start + moveDelta,
            endPoint: b.endPoint + moveDelta,
            controlPoints: b.controlPoints.map((p) => p + moveDelta).toList(),
          );
        } else {
          _elements[idx] = b.copyWith(
            start: b.start + moveDelta,
            endPoint: b.endPoint + moveDelta,
          );
        }
      } else if (b is TgSpring) {
        if (b is TgEditableSpring) {
          _elements[idx] = b.copyWith(
            start: b.start + moveDelta,
            endPoint: b.endPoint + moveDelta,
            controlPoints: b.controlPoints.map((p) => p + moveDelta).toList(),
          );
        } else {
          _elements[idx] = b.copyWith(
            start: b.start + moveDelta,
            endPoint: b.endPoint + moveDelta,
          );
        }
      } else if (b is TgSpiral) {
        if (b is TgEditableSpiral) {
          _elements[idx] = b.copyWith(
            start: b.start + moveDelta,
            endPoint: b.endPoint + moveDelta,
            controlPoints: b.controlPoints.map((p) => p + moveDelta).toList(),
          );
        } else {
          _elements[idx] = b.copyWith(
            start: b.start + moveDelta,
            endPoint: b.endPoint + moveDelta,
          );
        }
      }
    }

    notifyListeners();
  }

  // ===== drawing / pan pipeline (for non-select tools) =====
  Offset? _panStart;
  Offset? _lastPan;

  // ====== Line editing ======
  void editLineLength() {
    final sel = selected;
    if (sel is! TgLine) return;

    _commitUndo();

    final linePoints = [sel.a, sel.b];

    final lengthCurve = TgEditableCurve(
      id: sel.id,
      points: linePoints,
      color: sel.color,
      width: sel.width,
      kind: sel.kind,
      curveType: CurveType.line,
      opacity: sel.opacity,
      end: sel.end,
      arrowSize: sel.arrowSize,
      showControlPoints: true,
      selectedPointIndex: -1,
    );

    final idx = _elements.indexWhere((e) => e.id == sel.id);
    if (idx >= 0) {
      _elements[idx] = lengthCurve;
      selectById(lengthCurve.id);
      tool = TgTool.editPoints;
      notifyListeners();
    }
  }

  void editSelectedLinePoints() {
    final sel = selected;
    if (sel is! TgLine) return;

    _commitUndo();

    final midPoint = Offset(
      (sel.a.dx + sel.b.dx) / 2,
      (sel.a.dy + sel.b.dy) / 2,
    );

    final curveFactor = sel.curveAmount == 0 ? 0.3 : sel.curveAmount * 0.5;
    final controlPoint = Offset(
      midPoint.dx + (sel.b.dy - sel.a.dy) * curveFactor,
      midPoint.dy - (sel.b.dx - sel.a.dx) * curveFactor,
    );

    final curvePoints = [sel.a, controlPoint, sel.b];

    final curve = TgEditableCurve(
      id: sel.id,
      points: curvePoints,
      color: sel.color,
      width: sel.width,
      kind: sel.kind,
      curveType: CurveType.quadratic,
      opacity: sel.opacity,
      end: sel.end,
      arrowSize: sel.arrowSize,
      showControlPoints: true,
      selectedPointIndex: 1,
    );

    final idx = _elements.indexWhere((e) => e.id == sel.id);
    if (idx >= 0) {
      _elements[idx] = curve;
      selectById(curve.id);
      tool = TgTool.editPoints;
      notifyListeners();
    }
  }

  // ====== Curve handling ======
  void startCurve(Offset startPoint, CurveType type) {
    _commitUndo();

    List<Offset> points;
    switch (type) {
      case CurveType.line:
        points = [startPoint, startPoint];
        break;
      case CurveType.quadratic:
        final mid = startPoint + const Offset(100, 50);
        points = [startPoint, mid, startPoint + const Offset(200, 0)];
        break;
      case CurveType.cubic:
        points = [
          startPoint,
          startPoint + const Offset(70, -50),
          startPoint + const Offset(130, 50),
          startPoint + const Offset(200, 0),
        ];
        break;
    }

    _preview = TgEditableCurve(
      id: "_preview",
      points: points,
      color: Colors.white,
      width: 2,
      kind: LineKind.normal,
      curveType: type,
      opacity: 0.7,
      showControlPoints: true,
    );

    notifyListeners();
  }

  void updateCurvePoint(int pointIndex, Offset newPosition) {
    if (_preview is! TgEditableCurve) return;

    final curve = _preview as TgEditableCurve;
    final newPoints = List<Offset>.from(curve.points);

    if (pointIndex >= 0 && pointIndex < newPoints.length) {
      newPoints[pointIndex] = newPosition;

      _preview = curve.copyWith(
        points: newPoints,
        selectedPointIndex: pointIndex,
      );

      notifyListeners();
    }
  }

  void finishCurve() {
    if (_preview is! TgEditableCurve) return;

    _commitUndo();
    final curve = _preview as TgEditableCurve;

    final newCurve = TgEditableCurve(
      id: _newId(),
      points: curve.points,
      color: curve.color,
      width: curve.width,
      kind: curve.kind,
      curveType: curve.curveType,
      opacity: 1.0,
      end: curve.end,
      arrowSize: curve.arrowSize,
      showControlPoints: false,
    );

    _elements.add(newCurve);
    selectById(newCurve.id);

    _preview = null;
    tool = TgTool.select;

    notifyListeners();
  }

  void editSelectedCurvePoints() {
    final sel = selected;
    if (sel is! TgEditableCurve) return;

    _commitUndo();
    final idx = _elements.indexWhere((e) => e.id == sel.id);
    if (idx < 0) return;

    _elements[idx] = sel.copyWith(
      showControlPoints: true,
    );

    tool = TgTool.editPoints;
    notifyListeners();
  }

  void updateSelectedCurve({
    Color? color,
    double? width,
    LineKind? kind,
    CurveType? curveType,
    double? opacity,
    LineEnd? end,
    double? arrowSize,
    List<Offset>? points,
    bool? showControlPoints,
    int? selectedPointIndex,
  }) {
    final sel = selected;
    if (sel is! TgEditableCurve) return;

    _commitUndo();
    final idx = _elements.indexWhere((e) => e.id == sel.id);
    if (idx < 0) return;

    _elements[idx] = sel.copyWith(
      color: color,
      width: width,
      kind: kind,
      curveType: curveType,
      opacity: opacity,
      end: end,
      arrowSize: arrowSize,
      points: points,
      showControlPoints: showControlPoints,
      selectedPointIndex: selectedPointIndex ?? sel.selectedPointIndex,
    );

    notifyListeners();
  }

  int? hitTestCurvePoint(Offset scene, {double tolerance = 20}) {
    final sel = selected;
    if (sel is! TgEditableCurve || !sel.showControlPoints) return null;

    for (int i = 0; i < sel.points.length; i++) {
      if ((sel.points[i] - scene).distance <= tolerance) {
        return i;
      }
    }

    return null;
  }

  void moveCurvePoint(int pointIndex, Offset delta) {
    final sel = selected;
    if (sel is! TgEditableCurve) return;

    final newPoints = List<Offset>.from(sel.points);
    if (pointIndex >= 0 && pointIndex < newPoints.length) {
      newPoints[pointIndex] = newPoints[pointIndex] + delta;

      updateSelectedCurve(
        points: newPoints,
        selectedPointIndex: pointIndex,
      );
    }
  }

  // ====== Zigzag handling ======
  void startZigzag(Offset startPoint) {
    _commitUndo();

    final endPoint = startPoint + const Offset(200, 0);
    final amplitude = 20.0;
    final frequency = 4.0;

    final controlPoints = <Offset>[];
    final dir = endPoint - startPoint;
    for (int i = 0; i <= 8; i++) {
      final t = i / 8;
      final basePos = startPoint + dir * t;
      final offsetY = math.sin(t * frequency * 2 * math.pi) * amplitude;
      controlPoints.add(Offset(basePos.dx, basePos.dy + offsetY));
    }

    _preview = TgEditableZigzag(
      id: "_preview",
      start: startPoint,
      endPoint: endPoint,
      color: Colors.white,
      width: 2,
      kind: LineKind.zigzag,
      opacity: 0.7,
      amplitude: amplitude,
      frequency: frequency,
      phase: 0.0,
      lineEnd: LineEnd.none,
      arrowSize: 16.0,
      showControlPoints: true,
      controlPoints: controlPoints,
    );

    notifyListeners();
  }

  void finishZigzag() {
    if (_preview is! TgEditableZigzag) return;

    _commitUndo();
    final zigzag = _preview as TgEditableZigzag;

    final newZigzag = TgEditableZigzag(
      id: _newId(),
      start: zigzag.start,
      endPoint: zigzag.endPoint,
      color: zigzag.color,
      width: zigzag.width,
      kind: zigzag.kind,
      opacity: 1.0,
      amplitude: zigzag.amplitude,
      frequency: zigzag.frequency,
      phase: zigzag.phase,
      lineEnd: zigzag.lineEnd,
      arrowSize: zigzag.arrowSize,
      showControlPoints: false,
      controlPoints: zigzag.controlPoints,
    );

    _elements.add(newZigzag);
    selectById(newZigzag.id);

    _preview = null;
    tool = TgTool.select;

    notifyListeners();
  }

  void editZigzagPoints() {
    final sel = selected;
    if (sel is! TgZigzag) return;

    _commitUndo();

    final dir = sel.endPoint - sel.start;
    final length = dir.distance;
    if (length < 1) return;

    final unitDir = dir / length;
    final perp = Offset(-unitDir.dy, unitDir.dx);

    final controlPts = <Offset>[];
    for (int i = 0; i <= 12; i++) {
      final t = i / 12;
      final basePos = sel.start + dir * t;
      final zigZagOffset =
          math.sin(t * sel.frequency * 2 * math.pi + sel.phase) *
          sel.amplitude;
      controlPts.add(basePos + perp * zigZagOffset);
    }

    final zigzag = TgEditableZigzag(
      id: sel.id,
      start: sel.start,
      endPoint: sel.endPoint,
      color: sel.color,
      width: sel.width,
      kind: sel.kind,
      opacity: sel.opacity,
      amplitude: sel.amplitude,
      frequency: sel.frequency,
      phase: sel.phase,
      lineEnd: sel.lineEnd,
      arrowSize: sel.arrowSize,
      showControlPoints: true,
      controlPoints: controlPts,
      selectedPointIndex: -1,
    );

    final idx = _elements.indexWhere((e) => e.id == sel.id);
    if (idx >= 0) {
      _elements[idx] = zigzag;
      selectById(zigzag.id);
      tool = TgTool.editPoints;
      notifyListeners();
    }
  }

  void updateSelectedZigzag({
    Color? color,
    double? width,
    double? opacity,
    double? amplitude,
    double? frequency,
    double? phase,
  }) {
    final sel = selected;
    if (sel == null) return;

    _commitUndo();
    final idx = _elements.indexWhere((e) => e.id == sel.id);
    if (idx < 0) return;

    if (sel is TgZigzag) {
      final updatedZigzag = sel.copyWith(
        color: color ?? sel.color,
        width: width ?? sel.width,
        opacity: opacity ?? sel.opacity,
        amplitude: amplitude ?? sel.amplitude,
        frequency: frequency ?? sel.frequency,
        phase: phase ?? sel.phase,
      );

      if (sel is TgEditableZigzag && (amplitude != null || frequency != null)) {
        final dir = updatedZigzag.endPoint - updatedZigzag.start;
        final length = dir.distance;
        if (length > 0) {
          final unitDir = dir / length;
          final perp = Offset(-unitDir.dy, unitDir.dx);

          final newControlPoints = <Offset>[];
          for (int i = 0; i <= 12; i++) {
            final t = i / 12;
            final basePos = updatedZigzag.start + dir * t;
            final zigZagOffset =
                math.sin(
                  t * updatedZigzag.frequency * 2 * math.pi +
                      updatedZigzag.phase,
                ) *
                updatedZigzag.amplitude;
            newControlPoints.add(basePos + perp * zigZagOffset);
          }

          _elements[idx] = sel.copyWith(
            controlPoints: newControlPoints,
          );
        } else {
          _elements[idx] = updatedZigzag;
        }
      } else {
        _elements[idx] = updatedZigzag;
      }

      notifyListeners();
    }
  }

  // ====== Spring handling ======
  void startSpring(Offset startPoint) {
    _commitUndo();

    final endPoint = startPoint + const Offset(200, 0);
    final amplitude = 25.0;
    final frequency = 8.0;

    final controlPoints = <Offset>[];
    final dir = endPoint - startPoint;
    for (int i = 0; i <= 12; i++) {
      final t = i / 12;
      final basePos = startPoint + dir * t;
      final offsetY = math.sin(t * frequency * 2 * math.pi) * amplitude;
      controlPoints.add(Offset(basePos.dx, basePos.dy + offsetY));
    }

    _preview = TgEditableSpring(
      id: "_preview",
      start: startPoint,
      endPoint: endPoint,
      color: Colors.white,
      width: 2,
      kind: LineKind.normal,
      opacity: 0.7,
      amplitude: amplitude,
      frequency: frequency,
      phase: 0.0,
      showControlPoints: true,
      controlPoints: controlPoints,
    );

    notifyListeners();
  }

  void finishSpring() {
    if (_preview is! TgEditableSpring) return;

    _commitUndo();
    final spring = _preview as TgEditableSpring;

    final newSpring = TgEditableSpring(
      id: _newId(),
      start: spring.start,
      endPoint: spring.endPoint,
      color: spring.color,
      width: spring.width,
      kind: spring.kind,
      opacity: 1.0,
      amplitude: spring.amplitude,
      frequency: spring.frequency,
      phase: spring.phase,
      lineEnd: spring.lineEnd,
      arrowSize: spring.arrowSize,
      showControlPoints: false,
      controlPoints: spring.controlPoints,
    );

    _elements.add(newSpring);
    selectById(newSpring.id);

    _preview = null;
    tool = TgTool.select;

    notifyListeners();
  }

  void editSpringPoints() {
    final sel = selected;
    if (sel is! TgSpring) return;

    _commitUndo();

    final dir = sel.endPoint - sel.start;
    final length = dir.distance;
    if (length < 1) return;

    final unitDir = dir / length;
    final perp = Offset(-unitDir.dy, unitDir.dx);

    final controlPts = <Offset>[];
    for (int i = 0; i <= 12; i++) {
      final t = i / 12;
      final basePos = sel.start + dir * t;
      final offset =
          math.sin(t * sel.frequency * 2 * math.pi + sel.phase) *
          sel.amplitude;
      controlPts.add(basePos + perp * offset);
    }

    final spring = TgEditableSpring(
      id: sel.id,
      start: sel.start,
      endPoint: sel.endPoint,
      color: sel.color,
      width: sel.width,
      kind: sel.kind,
      opacity: sel.opacity,
      amplitude: sel.amplitude,
      frequency: sel.frequency,
      phase: sel.phase,
      lineEnd: sel.lineEnd,
      arrowSize: sel.arrowSize,
      showControlPoints: true,
      controlPoints: controlPts,
      selectedPointIndex: -1,
    );

    final idx = _elements.indexWhere((e) => e.id == sel.id);
    if (idx >= 0) {
      _elements[idx] = spring;
      selectById(spring.id);
      tool = TgTool.editPoints;
      notifyListeners();
    }
  }

  void updateSelectedSpring({
    Color? color,
    double? width,
    double? opacity,
    double? amplitude,
    double? frequency,
    double? phase,
  }) {
    final sel = selected;
    if (sel == null) return;

    _commitUndo();
    final idx = _elements.indexWhere((e) => e.id == sel.id);
    if (idx < 0) return;

    if (sel is TgSpring) {
      final updatedSpring = sel.copyWith(
        color: color ?? sel.color,
        width: width ?? sel.width,
        opacity: opacity ?? sel.opacity,
        amplitude: amplitude ?? sel.amplitude,
        frequency: frequency ?? sel.frequency,
        phase: phase ?? sel.phase,
      );

      if (sel is TgEditableSpring && (amplitude != null || frequency != null)) {
        final dir = updatedSpring.endPoint - updatedSpring.start;
        final length = dir.distance;
        if (length > 0) {
          final unitDir = dir / length;
          final perp = Offset(-unitDir.dy, unitDir.dx);

          final newControlPoints = <Offset>[];
          for (int i = 0; i <= 12; i++) {
            final t = i / 12;
            final basePos = updatedSpring.start + dir * t;
            final offset =
                math.sin(
                  t * updatedSpring.frequency * 2 * math.pi +
                      updatedSpring.phase,
                ) *
                updatedSpring.amplitude;
            newControlPoints.add(basePos + perp * offset);
          }

          _elements[idx] = sel.copyWith(
            controlPoints: newControlPoints,
          );
        } else {
          _elements[idx] = updatedSpring;
        }
      } else {
        _elements[idx] = updatedSpring;
      }

      notifyListeners();
    }
  }

  // ====== Spiral handling ======
  void startSpiral(Offset startPoint) {
    print("🎯 TgState.startSpiral: startPoint=$startPoint");
    _commitUndo();

    final endPoint = startPoint + const Offset(200, 0);
    final amplitude = 12.0;
    final turns = 18.0;

    final controlPoints = <Offset>[];
    final dir = endPoint - startPoint;
    final length = dir.distance;

    if (length > 0) {
      final unitDir = dir / length;
      final perp = Offset(-unitDir.dy, unitDir.dx);

      for (int i = 0; i <= 20; i++) {
        final t = i / 20;
        final basePos = startPoint + dir * t;
        final angle = t * turns * 2 * math.pi;
        final offset = math.sin(angle) * amplitude;
        controlPoints.add(basePos + perp * offset);
      }
    } else {
      for (int i = 0; i <= 20; i++) {
        controlPoints.add(startPoint);
      }
    }

    _preview = TgEditableSpiral(
      id: "_preview",
      start: startPoint,
      endPoint: endPoint,
      color: Colors.white,
      width: 3,
      kind: LineKind.normal,
      opacity: 0.7,
      amplitude: amplitude,
      turns: turns,
      phase: 0.0,
      fadeEdge: 0.12,
      lineEnd: LineEnd.none,
      arrowSize: 16.0,
      showControlPoints: true,
      controlPoints: controlPoints,
    );

    notifyListeners();
  }

  void finishSpiral() {
    print("🎯 TgState.finishSpiral");
    if (_preview is! TgEditableSpiral) return;

    _commitUndo();
    final spiral = _preview as TgEditableSpiral;

    final newSpiral = TgEditableSpiral(
      id: _newId(),
      start: spiral.start,
      endPoint: spiral.endPoint,
      color: spiral.color,
      width: spiral.width,
      kind: spiral.kind,
      opacity: 1.0,
      amplitude: spiral.amplitude,
      turns: spiral.turns,
      phase: spiral.phase,
      fadeEdge: spiral.fadeEdge,
      lineEnd: spiral.lineEnd,
      arrowSize: spiral.arrowSize,
      showControlPoints: false,
      controlPoints: spiral.controlPoints,
    );

    _elements.add(newSpiral);
    selectById(newSpiral.id);

    _preview = null;
    tool = TgTool.select;

    notifyListeners();
  }

  void editSpiralPoints() {
    print("🎯 TgState.editSpiralPoints");
    final sel = selected;
    if (sel is! TgSpiral) return;

    _commitUndo();

    final dir = sel.endPoint - sel.start;
    final length = dir.distance;
    if (length < 1) return;

    final controlPts = <Offset>[];
    for (int i = 0; i <= 16; i++) {
      final t = i / 16;
      final basePos = sel.start + dir * t;
      final angle = t * sel.turns * 2 * math.pi + sel.phase;

      final unitDir = dir / length;
      final perp = Offset(-unitDir.dy, unitDir.dx);

      double fade = 1.0;
      if (sel.fadeEdge > 0) {
        if (t < sel.fadeEdge) {
          fade = t / sel.fadeEdge;
        } else if (t > 1 - sel.fadeEdge) {
          fade = (1 - t) / sel.fadeEdge;
        }
      }

      final offset = perp * (math.sin(angle) * sel.amplitude * fade);
      controlPts.add(basePos + offset);
    }

    final spiral = TgEditableSpiral(
      id: sel.id,
      start: sel.start,
      endPoint: sel.endPoint,
      color: sel.color,
      width: sel.width,
      kind: sel.kind,
      opacity: sel.opacity,
      amplitude: sel.amplitude,
      turns: sel.turns,
      phase: sel.phase,
      fadeEdge: sel.fadeEdge,
      lineEnd: sel.lineEnd,
      arrowSize: sel.arrowSize,
      showControlPoints: true,
      controlPoints: controlPts,
      selectedPointIndex: -1,
    );

    final idx = _elements.indexWhere((e) => e.id == sel.id);
    if (idx >= 0) {
      _elements[idx] = spiral;
      selectById(spiral.id);
      tool = TgTool.editPoints;
      notifyListeners();
    }
  }

  void updateSelectedSpiral({
    Color? color,
    double? width,
    double? opacity,
    double? amplitude,
    double? turns,
    double? phase,
    double? fadeEdge,
    LineEnd? lineEnd,
    double? arrowSize,
  }) {
    final sel = selected;
    if (sel == null) return;

    print("🎯 updateSelectedSpiral: sel type=${sel.runtimeType}");

    _commitUndo();
    final idx = _elements.indexWhere((e) => e.id == sel.id);
    if (idx < 0) return;

    if (sel is TgSpiral) {
      final updatedSpiral = sel.copyWith(
        color: color ?? sel.color,
        width: width ?? sel.width,
        opacity: opacity ?? sel.opacity,
        amplitude: amplitude ?? sel.amplitude,
        turns: turns ?? sel.turns,
        phase: phase ?? sel.phase,
        fadeEdge: fadeEdge ?? sel.fadeEdge,
        lineEnd: lineEnd ?? sel.lineEnd,
        arrowSize: arrowSize ?? sel.arrowSize,
      );

      if (sel is TgEditableSpiral &&
          (amplitude != null || turns != null || fadeEdge != null)) {
        print("🎯 updateSelectedSpiral: пересчет контрольных точек");

        final dir = updatedSpiral.endPoint - updatedSpiral.start;
        final length = dir.distance;
        if (length > 0) {
          final unitDir = dir / length;
          final perp = Offset(-unitDir.dy, unitDir.dx);

          final newControlPoints = <Offset>[];
          for (int i = 0; i <= 16; i++) {
            final t = i / 16;
            final basePos = updatedSpiral.start + dir * t;
            final angle = t * updatedSpiral.turns * 2 * math.pi + updatedSpiral.phase;

            double fade = 1.0;
            if (updatedSpiral.fadeEdge > 0) {
              if (t < updatedSpiral.fadeEdge) {
                fade = t / updatedSpiral.fadeEdge;
              } else if (t > 1 - updatedSpiral.fadeEdge) {
                fade = (1 - t) / updatedSpiral.fadeEdge;
              }
            }

            final offset = perp * (math.sin(angle) * updatedSpiral.amplitude * fade);
            newControlPoints.add(basePos + offset);
          }

          _elements[idx] = sel.copyWith(
            controlPoints: newControlPoints,
          );
        } else {
          _elements[idx] = updatedSpiral;
        }
      } else {
        _elements[idx] = updatedSpiral;
      }

      notifyListeners();
    }
  }

  // ===== Main touch handlers =====
  void onTap(Offset scene) {
    if (tool == TgTool.editPoints) {
      final sel = selected;
      final pointIndex = _hitEditablePoint(sel, scene);

      if (sel != null && pointIndex != null) {
        _setEditableSelectedPoint(sel, pointIndex);
        notifyListeners();
        return;
      }

      if (sel != null) {
        _finishEditableMode(sel);
        notifyListeners();
        return;
      }
    }

    if (tool == TgTool.select) {
      final hit = hitTest(scene);
      if (hit == null) {
        clearSelection();
      } else {
        selectById(hit);
        final selectedElem = selected;

        if (selectedElem is TgZigzag) {
          editZigzagPoints();
        } else if (selectedElem is TgSpring) {
          editSpringPoints();
        } else if (selectedElem is TgSpiral) {
          editSpiralPoints();
        } else if (selectedElem is TgWavy) {
          editWavyPoints();
        }
      }
      return;
    }

    if (tool == TgTool.text) {
      _commitUndo();
      final e = TgText(
        id: _newId(),
        position: scene,
        text: "Текст",
        size: 28,
        color: Colors.white,
        opacity: 1.0,
        rotation: 0,
        fontFamily: null,
        weight: FontWeight.w600,
        alignment: TextAlign.center,
        style: TgTextStyle.normal,
      );
      _elements.add(e);
      selectById(e.id);
      notifyListeners();
      return;
    }

    if (tool == TgTool.stamp && _activeStampAsset != null) {
      _commitUndo();

      final asset = _activeStampAsset!;
      final e = TgStamp(
        id: _newId(),
        asset: asset,
        pos: scene,
        size: _defaultStampSize(asset),
        rotation: 0,
        opacity: 0.8,
      );

      _elements.add(e);

      selectedIds
        ..clear()
        ..add(e.id);

      if (!stickyStampMode) {
        tool = TgTool.select;
        _activeStampAsset = null;
      }

      notifyListeners();
      return;
    }
  }

  void startWavy(Offset startPoint) {
    _commitUndo();

    _preview = TgWavy(
      id: "_preview",
      start: startPoint,
      endPoint: startPoint,
      controlPoints: [startPoint],
      color: Colors.white,
      width: 4,
      kind: LineKind.wavy,
      amplitude: 8.0,
      wavelength: 20.0,
      phase: 0.0,
      lineEnd: LineEnd.none,
      arrowSize: 16.0,
      opacity: 0.7,
      cap: TgStrokeCap.round,
      join: TgStrokeJoin.round,
    );

    notifyListeners();
  }

  void onPanStart(Offset scene) {
    print('🎯 onPanStart: scene=$scene, tool=$tool');

    _panStart = scene;
    _lastPan = scene;

    if (tool == TgTool.editPoints) {
      final sel = selected;
      final pointIndex = _hitEditablePoint(sel, scene);
      if (sel != null && pointIndex != null) {
        _setEditableSelectedPoint(sel, pointIndex);
        notifyListeners();
      }
      return;
    }

    if (tool == TgTool.wavy) {
      startWavy(scene);
    } else if (tool == TgTool.line) {
      _preview = TgLine(
        id: "_preview",
        a: scene,
        b: scene,
        color: Colors.white,
        width: 4,
        kind: LineKind.normal,
        end: LineEnd.none,
        arrowSize: 18,
      );
    } else if (tool == TgTool.rect) {
      _preview = TgRect(
        id: "_preview",
        position: scene,
        width: 10,
        height: 10,
        rotation: 0,
        fill: Colors.transparent,
        opacity: 1.0,
        border: Colors.white,
        borderWidth: 4,
        borderKind: BorderKind.solid,
        borderRadius: 10,
      );
    } else if (tool == TgTool.circle) {
      _preview = TgCircle(
        id: "_preview",
        position: scene,
        radius: 10,
        rotation: 0,
        fill: Colors.transparent,
        opacity: 1.0,
        border: Colors.white,
        borderWidth: 4,
        borderKind: BorderKind.solid,
      );
    } else if (tool == TgTool.stamp && _activeStampAsset != null) {
      final asset = _activeStampAsset!;
      _preview = TgStamp(
        id: "_preview",
        asset: asset,
        pos: scene,
        size: _defaultStampSize(asset),
        rotation: 0,
        opacity: 0.8,
      );
    } else if (tool == TgTool.curve) {
      startCurve(scene, CurveType.cubic);
    } else if (tool == TgTool.zigzag) {
      startZigzag(scene);
    } else if (tool == TgTool.spring) {
      startSpring(scene);
    } else if (tool == TgTool.spiral) {
      startSpiral(scene);
    } else if (tool == TgTool.text) {
      _preview = TgText(
        id: "_preview",
        position: scene,
        text: "Текст",
        size: 28,
        color: Colors.white,
        opacity: 0.7,
        rotation: 0,
        fontFamily: null,
        weight: FontWeight.w600,
        alignment: TextAlign.center,
        style: TgTextStyle.normal,
      );
    }

    notifyListeners();
  }

  void addWavyControlPoint(Offset point) {
    if (_preview is! TgWavy) return;

    final wavy = _preview as TgWavy;
    final newControlPoints = List<Offset>.from(wavy.controlPoints)..add(point);

    _preview = wavy.copyWith(
      controlPoints: newControlPoints,
    );

    notifyListeners();
  }

  void finishWavy() {
    if (_preview is! TgWavy) return;

    _commitUndo();
    final wavy = _preview as TgWavy;

    final smoothedPoints = _smoothPoints(wavy.controlPoints, factor: 0.5);

    final newWavy = TgWavy(
      id: _newId(),
      start: wavy.start,
      endPoint: wavy.endPoint,
      controlPoints: smoothedPoints,
      color: wavy.color,
      width: wavy.width,
      kind: wavy.kind,
      opacity: 1.0,
      amplitude: wavy.amplitude,
      wavelength: wavy.wavelength,
      phase: wavy.phase,
      lineEnd: wavy.lineEnd,
      arrowSize: wavy.arrowSize,
      cap: wavy.cap,
      join: wavy.join,
      dash: wavy.dash,
    );

    _elements.add(newWavy);
    selectById(newWavy.id);

    _preview = null;
    tool = TgTool.select;

    notifyListeners();
  }

  void onPanUpdate(Offset scene) {
    if (tool == TgTool.editPoints) {
      if (selected is TgEditableCurve) {
        final curve = selected as TgEditableCurve;

        if (curve.selectedPointIndex >= 0) {
          final delta = scene - _lastPan!;

          final newPoints = List<Offset>.from(curve.points);
          newPoints[curve.selectedPointIndex] =
              newPoints[curve.selectedPointIndex] + delta;

          final idx = _elements.indexWhere((e) => e.id == curve.id);
          if (idx >= 0) {
            _elements[idx] = curve.copyWith(
              points: newPoints,
            );
          }

          _lastPan = scene;
          notifyListeners();
          return;
        }
      }

      if (selected is TgEditableZigzag) {
        final zigzag = selected as TgEditableZigzag;

        if (zigzag.selectedPointIndex >= 0) {
          final delta = scene - _lastPan!;

          final newControlPoints = List<Offset>.from(zigzag.controlPoints);
          newControlPoints[zigzag.selectedPointIndex] =
              newControlPoints[zigzag.selectedPointIndex] + delta;

          Offset newStart = zigzag.start;
          Offset newEnd = zigzag.endPoint;

          if (zigzag.selectedPointIndex == 0) {
            newStart = newControlPoints[0];
          } else if (zigzag.selectedPointIndex == newControlPoints.length - 1) {
            newEnd = newControlPoints.last;
          }

          double maxOffset = 0;
          for (int i = 1; i < newControlPoints.length - 1; i++) {
            final t = i / (newControlPoints.length - 1);
            final basePos = newStart + (newEnd - newStart) * t;
            final offset = (newControlPoints[i] - basePos).distance;
            maxOffset = math.max(maxOffset, offset);
          }

          final idx = _elements.indexWhere((e) => e.id == zigzag.id);
          if (idx >= 0) {
            _elements[idx] = zigzag.copyWith(
              start: newStart,
              endPoint: newEnd,
              amplitude: maxOffset * 1.2,
              controlPoints: newControlPoints,
              selectedPointIndex: zigzag.selectedPointIndex,
            );
            notifyListeners();
          }

          _lastPan = scene;
          return;
        }
      }

      if (selected is TgEditableSpring) {
        final spring = selected as TgEditableSpring;

        if (spring.selectedPointIndex >= 0) {
          final delta = scene - _lastPan!;

          final newControlPoints = List<Offset>.from(spring.controlPoints);
          newControlPoints[spring.selectedPointIndex] =
              newControlPoints[spring.selectedPointIndex] + delta;

          Offset newStart = spring.start;
          Offset newEnd = spring.endPoint;

          if (spring.selectedPointIndex == 0) {
            newStart = newControlPoints[0];
          } else if (spring.selectedPointIndex == newControlPoints.length - 1) {
            newEnd = newControlPoints.last;
          }

          double maxOffset = 0;
          for (int i = 1; i < newControlPoints.length - 1; i++) {
            final t = i / (newControlPoints.length - 1);
            final basePos = newStart + (newEnd - newStart) * t;
            final offset = (newControlPoints[i] - basePos).distance;
            maxOffset = math.max(maxOffset, offset);
          }

          final idx = _elements.indexWhere((e) => e.id == spring.id);
          if (idx >= 0) {
            _elements[idx] = spring.copyWith(
              start: newStart,
              endPoint: newEnd,
              amplitude: maxOffset * 1.2,
              controlPoints: newControlPoints,
              selectedPointIndex: spring.selectedPointIndex,
            );
            notifyListeners();
          }

          _lastPan = scene;
          return;
        }
      }

      if (selected is TgEditableWavy) {
        final wavy = selected as TgEditableWavy;

        if (wavy.selectedPointIndex >= 0) {
          final delta = scene - _lastPan!;

          final newControlPoints = List<Offset>.from(wavy.controlPoints);
          newControlPoints[wavy.selectedPointIndex] =
              newControlPoints[wavy.selectedPointIndex] + delta;

          Offset newStart = wavy.start;
          Offset newEnd = wavy.endPoint;

          if (wavy.selectedPointIndex == 0) {
            newStart = newControlPoints[0];
          } else if (wavy.selectedPointIndex == newControlPoints.length - 1) {
            newEnd = newControlPoints.last;
          }

          double maxOffset = 0;
          for (int i = 1; i < newControlPoints.length - 1; i++) {
            final t = i / (newControlPoints.length - 1);
            final basePos = newStart + (newEnd - newStart) * t;
            final offset = (newControlPoints[i] - basePos).distance;
            maxOffset = math.max(maxOffset, offset);
          }

          final idx = _elements.indexWhere((e) => e.id == wavy.id);
          if (idx >= 0) {
            _elements[idx] = wavy.copyWith(
              start: newStart,
              endPoint: newEnd,
              amplitude: maxOffset * 1.2,
              controlPoints: newControlPoints,
              selectedPointIndex: wavy.selectedPointIndex,
            );
            notifyListeners();
          }

          _lastPan = scene;
          return;
        }
      }
    }

    final start = _panStart;
    if (start == null) return;

    if (tool == TgTool.line && _preview is TgLine) {
      final p = _preview as TgLine;
      _preview = p.copyWith(b: scene);
    } else if (tool == TgTool.wavy && _preview is TgWavy) {
      final p = _preview as TgWavy;

      final lastPoint =
          p.controlPoints.isNotEmpty ? p.controlPoints.last : p.start;
      final distance = (scene - lastPoint).distance;

      if (distance > 15) {
        final newControlPoints = List<Offset>.from(p.controlPoints)..add(scene);

        final smoothedPoints = _smoothPoints(newControlPoints, factor: 0.3);

        _preview = p.copyWith(
          endPoint: scene,
          controlPoints: smoothedPoints,
        );
      } else {
        _preview = p.copyWith(endPoint: scene);
      }
    } else if (tool == TgTool.rect && _preview is TgRect) {
      final r = Rect.fromPoints(start, scene);
      final p = _preview as TgRect;
      _preview = p.copyWith(
        position: r.center,
        width: r.width.abs().clamp(6.0, 2000.0).toDouble(),
        height: r.height.abs().clamp(6.0, 2000.0).toDouble(),
      );
    } else if (tool == TgTool.circle && _preview is TgCircle) {
      final dist = (scene - start).distance;
      final p = _preview as TgCircle;
      _preview = p.copyWith(radius: dist.clamp(10.0, 900.0).toDouble());
    } else if (tool == TgTool.stamp && _preview is TgStamp) {
      final p = _preview as TgStamp;
      _preview = p.copyWith(pos: scene);
    } else if (tool == TgTool.curve && _preview is TgEditableCurve) {
      final p = _preview as TgEditableCurve;
      if (p.curveType == CurveType.cubic && p.points.length == 4) {
        final newPoints = List<Offset>.from(p.points);
        newPoints[3] = scene;
        _preview = p.copyWith(points: newPoints);
      }
    } else if (tool == TgTool.spring && _preview is TgEditableSpring) {
      final p = _preview as TgEditableSpring;
      final dir = scene - p.start;
      final length = dir.distance;
      if (length > 0) {
        final unitDir = dir / length;
        final perp = Offset(-unitDir.dy, unitDir.dx);

        final newControlPoints = <Offset>[];
        for (int i = 0; i <= 12; i++) {
          final t = i / 12;
          final basePos = p.start + dir * t;
          final offset =
              math.sin(t * p.frequency * 2 * math.pi + p.phase) * p.amplitude;
          newControlPoints.add(basePos + perp * offset);
        }

        _preview = p.copyWith(
          endPoint: scene,
          controlPoints: newControlPoints,
        );
      }
    } else if (tool == TgTool.spiral && _preview is TgEditableSpiral) {
      final p = _preview as TgEditableSpiral;
      final dir = scene - p.start;
      final length = dir.distance;
      if (length > 0) {
        final unitDir = dir / length;
        final perp = Offset(-unitDir.dy, unitDir.dx);

        final newControlPoints = <Offset>[];
        for (int i = 0; i <= 20; i++) {
          final t = i / 20;
          final basePos = p.start + dir * t;
          final angle = t * p.turns * 2 * math.pi + p.phase;

          double fade = 1.0;
          if (p.fadeEdge > 0) {
            if (t < p.fadeEdge) {
              fade = t / p.fadeEdge;
            } else if (t > 1 - p.fadeEdge) {
              fade = (1 - t) / p.fadeEdge;
            }
          }

          final offset = perp * (math.sin(angle) * p.amplitude * fade);
          newControlPoints.add(basePos + offset);
        }

        _preview = p.copyWith(
          endPoint: scene,
          controlPoints: newControlPoints,
        );
      }
    }

    _lastPan = scene;
    notifyListeners();
  }

  void onPanEnd() {
    print('🎯 ===== O N   P A N   E N D =====');
    print('🎯 tool: $tool');
    print('🎯 continuousDrawMode: $continuousDrawMode');
    print('🎯 _preview: $_preview');
    print('🎯 _preview.runtimeType: ${_preview.runtimeType}');

    if (tool == TgTool.editPoints) {
      print('🎯 editPoints mode, returning');
      _lastPan = null;
      return;
    }

    final p = _preview;
    print('🎯 p: $p');
    print('🎯 p?.id: ${p?.id}');
    print('🎯 p is TgWavy? ${p is TgWavy}');

    if (p != null && p.id == "_preview") {
      print('🎯 Preview found with id _preview');

      if (p is TgEditableCurve) {
        print('🎯 finishing curve');
        finishCurve();
      } else if (p is TgEditableZigzag) {
        print('🎯 finishing zigzag');
        finishZigzag();
      } else if (p is TgEditableSpring) {
        print('🎯 finishing spring');
        finishSpring();
      } else if (p is TgEditableSpiral) {
        print('🎯 finishing spiral');
        finishSpiral();
      } else {
        print('🎯 regular element, committing undo');
        _commitUndo();

        TgElement e;

        if (p is TgStamp) {
          print('🎯 processing stamp');
          if (p.asset.contains('/run_svg/') ||
              p.asset.contains('/pass_svg/') ||
              p.asset.contains('/jump_svg/') ||
              p.asset.contains('/vrat_svg/') ||
              p.asset.contains('/stand_svg/')) {
            final defaultColors = PlayerColors(
              jersey: const Color(0xFF0068B4),
              shorts: Colors.white,
              skin: const Color(0xFFFBCDAA),
              socks: Colors.white,
              isProp: false,
            );

            e = p.copyWith(
              id: _newId(),
              playerColors: defaultColors,
            );
          } else if (p.asset.contains('/props/')) {
            final defaultColors = PlayerColors(
              jersey: Colors.white,
              shorts: Colors.white,
              skin: Colors.white,
              socks: Colors.white,
              isProp: true,
            );

            e = p.copyWith(
              id: _newId(),
              playerColors: defaultColors,
            );
          } else if (p.asset.contains('/vorota1/')) {
            final defaultColors = PlayerColors(
              jersey: Colors.white,
              shorts: Colors.white,
              skin: Colors.white,
              socks: Colors.white,
              isProp: true,
            );

            e = p.copyWith(
              id: _newId(),
              playerColors: defaultColors,
            );
          } else {
            e = _cloneWithNewId(p);
          }
        } else {
          e = _cloneWithNewId(p);
        }

        print('🎯 Adding element to _elements: ${e.runtimeType}');
        _elements.add(e);

        print('🎯 CHECKING CONTINUOUS CONDITION:');
        print('  - p is TgWavy? ${p is TgWavy}');
        print('  - continuousDrawMode? $continuousDrawMode');

        if (p is TgWavy && continuousDrawMode) {
          final end = p.endPoint;

          selectedIds
            ..clear()
            ..add(e.id);

          tool = TgTool.wavy;

          _preview = TgWavy(
            id: "_preview",
            start: end,
            endPoint: end,
            controlPoints: [],
            color: p.color,
            width: p.width,
            kind: p.kind,
            amplitude: p.amplitude,
            wavelength: p.wavelength,
            phase: p.phase,
            lineEnd: p.lineEnd,
            arrowSize: p.arrowSize,
            opacity: p.opacity,
            cap: p.cap,
            join: p.join,
            dash: p.dash,
          );

          _panStart = end;
          _lastPan = null;
          _gestureBase = null;

          notifyListeners();
          return;
        } else {
          print('🎯 Continuous mode condition FAILED');
          if (!(p is TgWavy)) print('🎯   Reason: p is not TgWavy');
          if (!continuousDrawMode) {
            print('🎯   Reason: continuousDrawMode is false');
          }

          if (p is TgStamp && stickyStampMode && _activeStampAsset != null) {
            selectedIds
              ..clear()
              ..add(e.id);
          } else {
            print('🎯 Just selecting');
            selectById(e.id);
          }
        }
      }
    } else {
      print('🎯 No preview or preview id not _preview');
    }

    print('🎯 END OF onPanEnd - resetting preview?');
    print('🎯 continuousDrawMode: $continuousDrawMode');
    print('🎯 tool: $tool');

    if (!continuousDrawMode) {
      print('🎯 Continuous mode OFF - resetting preview');
      _preview = null;
      _panStart = null;

      final keepStampTool =
          tool == TgTool.stamp &&
          _activeStampAsset != null &&
          stickyStampMode;

      if (!keepStampTool) {
        tool = TgTool.select;
      }
    }

    _lastPan = null;
    _gestureBase = null;
    print('🎯 Final notifyListeners()');
    notifyListeners();
  }

  // ===== undo/redo =====
  final List<_TgSnapshot> _undo = [];
  final List<_TgSnapshot> _redo = [];

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  void undo() {
    if (_undo.isEmpty) return;
    final cur = _makeSnapshot();
    final prev = _undo.removeLast();
    _redo.add(cur);
    _restoreSnapshot(prev);
  }

  void redo() {
    if (_redo.isEmpty) return;
    final cur = _makeSnapshot();
    final next = _redo.removeLast();
    _undo.add(cur);
    _restoreSnapshot(next);
  }

  // ===== JSON export/import =====
  Map<String, dynamic> toJson() {
    return {
      "v": 1,
      "team_id": teamId,
      "team_name": teamName,
      "tool": tool.name,
      "field_edit_mode": fieldEditMode,
      "lock_viewport_gestures": lockViewportGestures,
      "sticky_stamp_mode": stickyStampMode,
      "field_view": fieldView.name,
      "grid_enabled": gridEnabled,
      "grid_step": gridStep,
      "snap_rotation_enabled": snapRotationEnabled,
      "snap_rotation_degrees": snapRotationDegrees,
      "active_stamp_asset": _activeStampAsset,
      "viewport": transform.value.value.storage.toList(),
      "elements": _elements.map(_elementToJson).toList(),
      "selected_ids": selectedIds.toList(),
      "is_3d_mode": is3DMode,
      "rotation_x": rotationX,
      "rotation_y": rotationY,
      "rotation_z": rotationZ,
      "perspective": perspective,
      "field_logical_width": fieldLogicalSize.width,
      "field_logical_height": fieldLogicalSize.height,
    };
  }

  void loadFromJson(Map<String, dynamic> json) {
    final any = json["elements"];
    final List<TgElement> loaded = [];
    if (any is List) {
      for (final it in any) {
        if (it is Map) {
          final e = _elementFromJson(Map<String, dynamic>.from(it));
          if (e != null) loaded.add(e);
        }
      }
    }

    final toolStr = (json["tool"] ?? "").toString();
    TgTool? parsedTool;
    for (final t in TgTool.values) {
      if (t.name == toolStr) {
        parsedTool = t;
        break;
      }
    }
    if (parsedTool != null) tool = parsedTool;

    fieldEditMode = (json["field_edit_mode"] == true);
    lockViewportGestures = (json["lock_viewport_gestures"] == true);
    stickyStampMode = json["sticky_stamp_mode"] != false;

    final fieldViewStr = (json["field_view"] ?? "").toString();
    fieldView = TgFieldView.values.firstWhere(
      (e) => e.name == fieldViewStr,
      orElse: () => TgFieldView.full,
    );

    gridEnabled = (json["grid_enabled"] == true);
    gridStep = _asDouble(json["grid_step"], gridStep);
    snapRotationEnabled = (json["snap_rotation_enabled"] == true);
    snapRotationDegrees = _asDouble(
      json["snap_rotation_degrees"],
      snapRotationDegrees,
    ).clamp(1, 90).toDouble();

    final stamp = (json["active_stamp_asset"] ?? "").toString().trim();
    _activeStampAsset = stamp.isEmpty ? null : stamp;

    final vp = json["viewport"];
    if (vp is List && vp.length == 16) {
      final m = Matrix4.fromList(
        vp.map((e) => _asDouble(e, 0)).toList().cast<double>(),
      );
      transform.value.value = m;
    }

    is3DMode = json["is_3d_mode"] == true;
    rotationX = _asDouble(json["rotation_x"], 0.0);
    rotationY = _asDouble(json["rotation_y"], 0.0);
    rotationZ = _asDouble(json["rotation_z"], 0.0);
    perspective = _asDouble(json["perspective"], 0.0008);

    final fieldW = _asDouble(json["field_logical_width"], 1050.0);
    final fieldH = _asDouble(json["field_logical_height"], 680.0);
    fieldLogicalSize = Size(fieldW, fieldH);

    _elements
      ..clear()
      ..addAll(loaded);

    selectedIds
      ..clear()
      ..addAll(
        ((json["selected_ids"] is List)
                ? (json["selected_ids"] as List)
                : const [])
            .map((e) => e.toString())
            .where((s) => s.isNotEmpty),
      );

    _preview = null;
    _panStart = null;
    _lastPan = null;
    _gestureBase = null;

    _undo.clear();
    _redo.clear();

    notifyListeners();
  }

  // ===== Private helpers =====
  void _commitUndo() {
    _undo.add(_makeSnapshot());
    _redo.clear();
  }

  _TgSnapshot _makeSnapshot() {
    return _TgSnapshot(
      elements: List<TgElement>.from(_elements),
      selectedIds: Set<String>.from(selectedIds),
      tool: tool,
      fieldEditMode: fieldEditMode,
      lockViewportGestures: lockViewportGestures,
      stickyStampMode: stickyStampMode,
      fieldView: fieldView,
      gridEnabled: gridEnabled,
      gridStep: gridStep,
      snapRotationEnabled: snapRotationEnabled,
      snapRotationDegrees: snapRotationDegrees,
      activeStampAsset: _activeStampAsset,
      viewport: transform.value.value.clone(),
      is3DMode: is3DMode,
      rotationX: rotationX,
      rotationY: rotationY,
      rotationZ: rotationZ,
      perspective: perspective,
      fieldLogicalSize: fieldLogicalSize,
    );
  }

  void _restoreSnapshot(_TgSnapshot s) {
    _elements
      ..clear()
      ..addAll(s.elements);
    selectedIds
      ..clear()
      ..addAll(s.selectedIds);

    tool = s.tool;
    fieldEditMode = s.fieldEditMode;
    lockViewportGestures = s.lockViewportGestures;
    stickyStampMode = s.stickyStampMode;
    fieldView = s.fieldView;
    gridEnabled = s.gridEnabled;
    gridStep = s.gridStep;
    snapRotationEnabled = s.snapRotationEnabled;
    snapRotationDegrees = s.snapRotationDegrees;
    _activeStampAsset = s.activeStampAsset;
    transform.value.value = s.viewport.clone();

    is3DMode = s.is3DMode;
    rotationX = s.rotationX;
    rotationY = s.rotationY;
    rotationZ = s.rotationZ;
    perspective = s.perspective;
    fieldLogicalSize = s.fieldLogicalSize;

    _preview = null;
    _panStart = null;
    _lastPan = null;
    _gestureBase = null;

    notifyListeners();
  }

  double _asDouble(dynamic v, double fallback) {
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? "") ?? fallback;
  }

  Map<String, dynamic> _elementToJson(TgElement e) {
    if (e is TgLine) {
      return {
        "type": "line",
        "id": e.id,
        "a": {"x": e.a.dx, "y": e.a.dy},
        "b": {"x": e.b.dx, "y": e.b.dy},
        "color": e.color.value,
        "width": e.width,
        "kind": e.kind.name,
        "end": e.end.name,
        "arrow_size": e.arrowSize,
        "opacity": e.opacity,
        "cap": e.cap.name,
        "join": e.join.name,
        "dash": e.dash,
        "curveMode": e.curveMode.name,
        "curveAmount": e.curveAmount,
      };
    }

    if (e is TgWavy) {
      return {
        "type": e is TgEditableWavy ? "editable_wavy" : "wavy",
        "id": e.id,
        "start": {"x": e.start.dx, "y": e.start.dy},
        "endPoint": {"x": e.endPoint.dx, "y": e.endPoint.dy},
        "controlPoints": e.controlPoints
            .map((p) => {"x": p.dx, "y": p.dy})
            .toList(),
        "color": e.color.value,
        "width": e.width,
        "kind": e.kind.name,
        "amplitude": e.amplitude,
        "wavelength": e.wavelength,
        "phase": e.phase,
        "lineEnd": e.lineEnd.name,
        "arrowSize": e.arrowSize,
        "opacity": e.opacity,
        "cap": e.cap.name,
        "join": e.join.name,
        "dash": e.dash,
        if (e is TgEditableWavy) "showControlPoints": e.showControlPoints,
        if (e is TgEditableWavy) "selectedPointIndex": e.selectedPointIndex,
      };
    }

    if (e is TgRect) {
      return {
        "type": "rect",
        "id": e.id,
        "pos": {"x": e.position.dx, "y": e.position.dy},
        "w": e.width,
        "h": e.height,
        "rot": e.rotation,
        "fill": e.fill.value,
        "opacity": e.opacity,
        "border": e.border.value,
        "border_w": e.borderWidth,
        "border_kind": e.borderKind.name,
        "border_radius": e.borderRadius,
      };
    }

    if (e is TgCircle) {
      return {
        "type": "circle",
        "id": e.id,
        "pos": {"x": e.position.dx, "y": e.position.dy},
        "r": e.radius,
        "rot": e.rotation,
        "fill": e.fill.value,
        "opacity": e.opacity,
        "border": e.border.value,
        "border_w": e.borderWidth,
        "border_kind": e.borderKind.name,
      };
    }

    if (e is TgText) {
      return {
        "type": "text",
        "id": e.id,
        "pos": {"x": e.position.dx, "y": e.position.dy},
        "text": e.text,
        "size": e.size,
        "color": e.color.value,
        "opacity": e.opacity,
        "rot": e.rotation,
        "font_family": e.fontFamily,
        "weight": e.weight.index,
        "align": e.alignment.name,
        "style": e.style.name,
      };
    }

    if (e is TgStamp) {
      final json = <String, dynamic>{
        "type": "stamp",
        "id": e.id,
        "asset": e.asset,
        "pos": {"x": e.pos.dx, "y": e.pos.dy},
        "size": e.size,
        "rot": e.rotation,
        "opacity": e.opacity,
      };

      if (e.color != null) {
        json["color"] = e.color!.value;
      }

      if (e.playerColors != null) {
        json["playerColors"] = {
          "jersey": e.playerColors!.jersey.value,
          "shorts": e.playerColors!.shorts.value,
          "skin": e.playerColors!.skin.value,
          "socks": e.playerColors!.socks.value,
          "isProp": e.playerColors!.isProp,
        };
      }

      return json;
    }

    if (e is TgEditableCurve) {
      return {
        "type": "editable_curve",
        "id": e.id,
        "points": e.points.map((p) => {"x": p.dx, "y": p.dy}).toList(),
        "color": e.color.value,
        "width": e.width,
        "kind": e.kind.name,
        "curveType": e.curveType.name,
        "opacity": e.opacity,
        "end": e.end.name,
        "arrow_size": e.arrowSize,
        "showControlPoints": e.showControlPoints,
        "selectedPointIndex": e.selectedPointIndex,
      };
    }

    if (e is TgEditableZigzag) {
      return {
        "type": "editable_zigzag",
        "id": e.id,
        "start": {"x": e.start.dx, "y": e.start.dy},
        "endPoint": {"x": e.endPoint.dx, "y": e.endPoint.dy},
        "color": e.color.value,
        "width": e.width,
        "kind": e.kind.name,
        "opacity": e.opacity,
        "amplitude": e.amplitude,
        "frequency": e.frequency,
        "phase": e.phase,
        "lineEnd": e.lineEnd.name,
        "arrowSize": e.arrowSize,
        "showControlPoints": e.showControlPoints,
        "selectedPointIndex": e.selectedPointIndex,
        "controlPoints": e.controlPoints
            .map((p) => {"x": p.dx, "y": p.dy})
            .toList(),
      };
    }

    if (e is TgEditableSpring) {
      return {
        "type": "editable_spring",
        "id": e.id,
        "start": {"x": e.start.dx, "y": e.start.dy},
        "endPoint": {"x": e.endPoint.dx, "y": e.endPoint.dy},
        "color": e.color.value,
        "width": e.width,
        "kind": e.kind.name,
        "opacity": e.opacity,
        "amplitude": e.amplitude,
        "frequency": e.frequency,
        "phase": e.phase,
        "lineEnd": e.lineEnd.name,
        "arrowSize": e.arrowSize,
        "showControlPoints": e.showControlPoints,
        "selectedPointIndex": e.selectedPointIndex,
        "controlPoints": e.controlPoints
            .map((p) => {"x": p.dx, "y": p.dy})
            .toList(),
      };
    }

    if (e is TgEditableSpiral) {
      return {
        "type": "editable_spiral",
        "id": e.id,
        "start": {"x": e.start.dx, "y": e.start.dy},
        "endPoint": {"x": e.endPoint.dx, "y": e.endPoint.dy},
        "color": e.color.value,
        "width": e.width,
        "kind": e.kind.name,
        "opacity": e.opacity,
        "amplitude": e.amplitude,
        "turns": e.turns,
        "phase": e.phase,
        "fadeEdge": e.fadeEdge,
        "grow": e.grow,
        "lineEnd": e.lineEnd.name,
        "arrowSize": e.arrowSize,
        "showControlPoints": e.showControlPoints,
        "selectedPointIndex": e.selectedPointIndex,
        "controlPoints": e.controlPoints
            .map((p) => {"x": p.dx, "y": p.dy})
            .toList(),
      };
    }

    return {"type": "unknown", "id": e.id};
  }

  TgElement? _elementFromJson(Map<String, dynamic> m) {
    final type = (m["type"] ?? "").toString();

    Offset readPos(dynamic obj, {String x = "x", String y = "y"}) {
      if (obj is Map) {
        return Offset(_asDouble(obj[x], 0), _asDouble(obj[y], 0));
      }
      return Offset.zero;
    }

    List<double>? _doubleListFromJson(dynamic v) {
      if (v is List) {
        final out = <double>[];
        for (final x in v) {
          if (x is num) {
            out.add(x.toDouble());
          } else {
            final p = double.tryParse(x?.toString() ?? "");
            if (p != null) out.add(p);
          }
        }
        return out.isEmpty ? null : out;
      }
      return null;
    }

    LineKind parseLineKind(String s) {
      return LineKind.values.firstWhere(
        (e) => e.name == s,
        orElse: () => LineKind.normal,
      );
    }

    LineEnd parseLineEnd(String s) {
      return LineEnd.values.firstWhere(
        (e) => e.name == s,
        orElse: () => LineEnd.none,
      );
    }

    BorderKind parseBorderKind(String s) {
      return BorderKind.values.firstWhere(
        (e) => e.name == s,
        orElse: () => BorderKind.solid,
      );
    }

    TgTextStyle parseTextStyle(String s) {
      return TgTextStyle.values.firstWhere(
        (e) => e.name == s,
        orElse: () => TgTextStyle.normal,
      );
    }

    CurveType parseCurveType(String s) {
      return CurveType.values.firstWhere(
        (e) => e.name == s,
        orElse: () => CurveType.line,
      );
    }

    TgStrokeCap parseStrokeCap(String s) {
      return TgStrokeCap.values.firstWhere(
        (e) => e.name == s,
        orElse: () => TgStrokeCap.round,
      );
    }

    TgStrokeJoin parseStrokeJoin(String s) {
      return TgStrokeJoin.values.firstWhere(
        (e) => e.name == s,
        orElse: () => TgStrokeJoin.round,
      );
    }

    TgLineCurve parseLineCurve(String s) {
      return TgLineCurve.values.firstWhere(
        (e) => e.name == s,
        orElse: () => TgLineCurve.straight,
      );
    }

    TextAlign parseAlign(String s) {
      return TextAlign.values.firstWhere(
        (e) => e.name == s,
        orElse: () => TextAlign.center,
      );
    }

    FontWeight parseWeight(dynamic w) {
      if (w is int && w >= 0 && w < FontWeight.values.length) {
        return FontWeight.values[w];
      }
      return FontWeight.w600;
    }

    final id = (m["id"] ?? "").toString();
    if (id.isEmpty) return null;

    switch (type) {
      case "line":
        return TgLine(
          id: id,
          a: readPos(m["a"]),
          b: readPos(m["b"]),
          color: Color((m["color"] ?? Colors.white.value) as int),
          width: _asDouble(m["width"], 4),
          kind: parseLineKind((m["kind"] ?? "normal").toString()),
          end: parseLineEnd((m["end"] ?? "none").toString()),
          arrowSize: _asDouble(m["arrow_size"], 18),
          opacity: _asDouble(m["opacity"], 1.0),
          cap: parseStrokeCap(m["cap"]?.toString() ?? "round"),
          join: parseStrokeJoin(m["join"]?.toString() ?? "round"),
          dash: _doubleListFromJson(m["dash"]),
          curveMode: parseLineCurve(m["curveMode"]?.toString() ?? "straight"),
          curveAmount: _asDouble(m["curveAmount"], 0.0),
        );

      case "wavy":
        final controlPtsRaw = (m["controlPoints"] is List)
            ? (m["controlPoints"] as List)
            : const [];
        final controlPts = <Offset>[];
        for (final x in controlPtsRaw) {
          controlPts.add(readPos(x));
        }

        return TgWavy(
          id: id,
          start: readPos(m["start"]),
          endPoint: readPos(m["endPoint"]),
          controlPoints: controlPts,
          color: Color((m["color"] ?? Colors.white.value) as int),
          width: _asDouble(m["width"], 4),
          kind: parseLineKind((m["kind"] ?? "wavy").toString()),
          amplitude: _asDouble(m["amplitude"], 15.0),
          wavelength: _asDouble(m["wavelength"], 25.0),
          phase: _asDouble(m["phase"], 0.0),
          lineEnd: parseLineEnd((m["lineEnd"] ?? "none").toString()),
          arrowSize: _asDouble(m["arrowSize"], 18.0),
          opacity: _asDouble(m["opacity"], 1.0).clamp(0.0, 1.0).toDouble(),
          cap: parseStrokeCap(m["cap"]?.toString() ?? "round"),
          join: parseStrokeJoin(m["join"]?.toString() ?? "round"),
          dash: _doubleListFromJson(m["dash"]),
        );

      case "editable_wavy":
        final controlPtsRaw = (m["controlPoints"] is List)
            ? (m["controlPoints"] as List)
            : const [];
        final controlPts = <Offset>[];
        for (final x in controlPtsRaw) {
          controlPts.add(readPos(x));
        }

        return TgEditableWavy(
          id: id,
          start: readPos(m["start"]),
          endPoint: readPos(m["endPoint"]),
          controlPoints: controlPts,
          color: Color((m["color"] ?? Colors.white.value) as int),
          width: _asDouble(m["width"], 4),
          kind: parseLineKind((m["kind"] ?? "wavy").toString()),
          amplitude: _asDouble(m["amplitude"], 15.0),
          wavelength: _asDouble(m["wavelength"], 25.0),
          phase: _asDouble(m["phase"], 0.0),
          lineEnd: parseLineEnd((m["lineEnd"] ?? "none").toString()),
          arrowSize: _asDouble(m["arrowSize"], 18.0),
          opacity: _asDouble(m["opacity"], 1.0).clamp(0.0, 1.0).toDouble(),
          cap: parseStrokeCap(m["cap"]?.toString() ?? "round"),
          join: parseStrokeJoin(m["join"]?.toString() ?? "round"),
          dash: _doubleListFromJson(m["dash"]),
          showControlPoints: m["showControlPoints"] == true,
          selectedPointIndex: (m["selectedPointIndex"] as num?)?.toInt() ?? -1,
        );

      case "rect":
        return TgRect(
          id: id,
          position: readPos(m["pos"]),
          width: _asDouble(m["w"], 10),
          height: _asDouble(m["h"], 10),
          rotation: _asDouble(m["rot"], 0),
          fill: Color((m["fill"] ?? Colors.transparent.value) as int),
          opacity: _asDouble(m["opacity"], 1.0).clamp(0.0, 1.0).toDouble(),
          border: Color((m["border"] ?? Colors.white.value) as int),
          borderWidth: _asDouble(m["border_w"], 4),
          borderKind: parseBorderKind(
            (m["border_kind"] ?? "solid").toString(),
          ),
          borderRadius: _asDouble(m["border_radius"], 10),
        );

      case "circle":
        return TgCircle(
          id: id,
          position: readPos(m["pos"]),
          radius: _asDouble(m["r"], 10),
          rotation: _asDouble(m["rot"], 0),
          fill: Color((m["fill"] ?? Colors.transparent.value) as int),
          opacity: _asDouble(m["opacity"], 1.0).clamp(0.0, 1.0).toDouble(),
          border: Color((m["border"] ?? Colors.white.value) as int),
          borderWidth: _asDouble(m["border_w"], 4),
          borderKind: parseBorderKind(
            (m["border_kind"] ?? "solid").toString(),
          ),
        );

      case "text":
        return TgText(
          id: id,
          position: readPos(m["pos"]),
          text: (m["text"] ?? "").toString(),
          size: _asDouble(m["size"], 28),
          color: Color((m["color"] ?? Colors.white.value) as int),
          opacity: _asDouble(m["opacity"], 1.0).clamp(0.0, 1.0).toDouble(),
          rotation: _asDouble(m["rot"], 0),
          fontFamily: (m["font_family"] == null)
              ? null
              : (m["font_family"] as String),
          weight: parseWeight(m["weight"]),
          alignment: parseAlign((m["align"] ?? "center").toString()),
          style: parseTextStyle((m["style"] ?? "normal").toString()),
        );

      case "stamp":
        PlayerColors? playerColors;
        if (m.containsKey("playerColors")) {
          final pc = m["playerColors"] as Map;
          playerColors = PlayerColors(
            jersey: Color((pc["jersey"] ?? 0xFF0068B4) as int),
            shorts: Color((pc["shorts"] ?? 0xFFFFFFFF) as int),
            skin: Color((pc["skin"] ?? 0xFFFBCDAA) as int),
            socks: Color((pc["socks"] ?? 0xFFFFFFFF) as int),
            isProp: pc["isProp"] == true,
          );
        }
        return TgStamp(
          id: id,
          asset: (m["asset"] ?? "").toString(),
          pos: readPos(m["pos"]),
          size: _asDouble(m["size"], 90),
          rotation: _asDouble(m["rot"], 0),
          opacity: _asDouble(m["opacity"], 1.0).clamp(0.0, 1.0).toDouble(),
          color: m.containsKey("color") ? Color(m["color"] as int) : null,
          playerColors: playerColors,
        );

      case "editable_curve":
        final ptsRaw = (m["points"] is List) ? (m["points"] as List) : const [];
        final pts = <Offset>[];
        for (final x in ptsRaw) {
          pts.add(readPos(x));
        }
        return TgEditableCurve(
          id: id,
          points: pts,
          color: Color((m["color"] ?? Colors.white.value) as int),
          width: _asDouble(m["width"], 4),
          kind: parseLineKind((m["kind"] ?? "normal").toString()),
          curveType: parseCurveType((m["curveType"] ?? "line").toString()),
          opacity: _asDouble(m["opacity"], 1.0).clamp(0.0, 1.0).toDouble(),
          end: parseLineEnd((m["end"] ?? "none").toString()),
          arrowSize: _asDouble(m["arrow_size"], 16),
          showControlPoints: m["showControlPoints"] == true,
          selectedPointIndex: (m["selectedPointIndex"] as num?)?.toInt() ?? -1,
        );

      case "editable_zigzag":
        final start = readPos(m["start"]);
        final endPoint = readPos(m["endPoint"]);
        final controlPtsRaw = (m["controlPoints"] is List)
            ? (m["controlPoints"] as List)
            : const [];
        final controlPts = <Offset>[];
        for (final x in controlPtsRaw) {
          controlPts.add(readPos(x));
        }

        return TgEditableZigzag(
          id: id,
          start: start,
          endPoint: endPoint,
          color: Color((m["color"] ?? Colors.white.value) as int),
          width: _asDouble(m["width"], 2),
          kind: parseLineKind((m["kind"] ?? "zigzag").toString()),
          opacity: _asDouble(m["opacity"], 1.0).clamp(0.0, 1.0).toDouble(),
          amplitude: _asDouble(m["amplitude"], 20.0),
          frequency: _asDouble(m["frequency"], 4.0),
          phase: _asDouble(m["phase"], 0.0),
          lineEnd: parseLineEnd((m["lineEnd"] ?? "none").toString()),
          arrowSize: _asDouble(m["arrowSize"], 16.0),
          showControlPoints: m["showControlPoints"] == true,
          selectedPointIndex: (m["selectedPointIndex"] as num?)?.toInt() ?? -1,
          controlPoints: controlPts,
        );

      case "editable_spring":
        final start = readPos(m["start"]);
        final endPoint = readPos(m["endPoint"]);
        final controlPtsRaw = (m["controlPoints"] is List)
            ? (m["controlPoints"] as List)
            : const [];
        final controlPts = <Offset>[];
        for (final x in controlPtsRaw) {
          controlPts.add(readPos(x));
        }

        return TgEditableSpring(
          id: id,
          start: start,
          endPoint: endPoint,
          color: Color((m["color"] ?? Colors.white.value) as int),
          width: _asDouble(m["width"], 2),
          kind: parseLineKind((m["kind"] ?? "normal").toString()),
          opacity: _asDouble(m["opacity"], 1.0).clamp(0.0, 1.0).toDouble(),
          amplitude: _asDouble(m["amplitude"], 25.0),
          frequency: _asDouble(m["frequency"], 8.0),
          phase: _asDouble(m["phase"], 0.0),
          lineEnd: parseLineEnd((m["lineEnd"] ?? "none").toString()),
          arrowSize: _asDouble(m["arrowSize"], 16.0),
          showControlPoints: m["showControlPoints"] == true,
          selectedPointIndex: (m["selectedPointIndex"] as num?)?.toInt() ?? -1,
          controlPoints: controlPts,
        );

      case "editable_spiral":
        final start = readPos(m["start"]);
        final endPoint = readPos(m["endPoint"]);
        final controlPtsRaw = (m["controlPoints"] is List)
            ? (m["controlPoints"] as List)
            : const [];
        final controlPts = <Offset>[];
        for (final x in controlPtsRaw) {
          controlPts.add(readPos(x));
        }

        return TgEditableSpiral(
          id: id,
          start: start,
          endPoint: endPoint,
          color: Color((m["color"] ?? Colors.white.value) as int),
          width: _asDouble(m["width"], 3),
          kind: parseLineKind((m["kind"] ?? "normal").toString()),
          opacity: _asDouble(m["opacity"], 1.0).clamp(0.0, 1.0).toDouble(),
          amplitude: _asDouble(m["amplitude"], 12.0),
          turns: _asDouble(m["turns"], 18.0),
          phase: _asDouble(m["phase"], 0.0),
          fadeEdge: _asDouble(m["fadeEdge"], 0.12).clamp(0.0, 0.49).toDouble(),
          grow: _asDouble(m["grow"], 0.0).clamp(0.0, 4.0).toDouble(),
          lineEnd: parseLineEnd((m["lineEnd"] ?? "none").toString()),
          arrowSize: _asDouble(m["arrowSize"], 16.0),
          showControlPoints: m["showControlPoints"] == true,
          selectedPointIndex: (m["selectedPointIndex"] as num?)?.toInt() ?? -1,
          controlPoints: controlPts,
        );

      default:
        return null;
    }
  }

  String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

  TgElement _cloneWithNewId(TgElement e) {
    final id = _newId();
    if (e is TgLine) return e.copyWith(id: id);
    if (e is TgEditableWavy) return e.copyWith(id: id);
    if (e is TgWavy) return e.copyWith(id: id);
    if (e is TgRect) return e.copyWith(id: id);
    if (e is TgCircle) return e.copyWith(id: id);
    if (e is TgText) return e.copyWith(id: id);
    if (e is TgStamp) return e.copyWith(id: id);
    if (e is TgEditableCurve) return e.copyWith(id: id);
    if (e is TgEditableZigzag) return e.copyWith(id: id);
    if (e is TgEditableSpring) return e.copyWith(id: id);
    if (e is TgEditableSpiral) return e.copyWith(id: id);
    return e;
  }
}

class _TgSnapshot {
  _TgSnapshot({
    required this.elements,
    required this.selectedIds,
    required this.tool,
    required this.fieldEditMode,
    required this.lockViewportGestures,
    required this.stickyStampMode,
    required this.fieldView,
    required this.gridEnabled,
    required this.gridStep,
    required this.snapRotationEnabled,
    required this.snapRotationDegrees,
    required this.activeStampAsset,
    required this.viewport,
    required this.is3DMode,
    required this.rotationX,
    required this.rotationY,
    required this.rotationZ,
    required this.perspective,
    required this.fieldLogicalSize,
  });

  final List<TgElement> elements;
  final Set<String> selectedIds;

  final TgTool tool;
  final bool fieldEditMode;
  final bool lockViewportGestures;
  final bool stickyStampMode;
  final TgFieldView fieldView;

  final bool gridEnabled;
  final double gridStep;

  final bool snapRotationEnabled;
  final double snapRotationDegrees;

  final String? activeStampAsset;

  final Matrix4 viewport;

  final bool is3DMode;
  final double rotationX;
  final double rotationY;
  final double rotationZ;
  final double perspective;
  final Size fieldLogicalSize;
}