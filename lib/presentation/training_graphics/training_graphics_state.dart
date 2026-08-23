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
  bool is3DMode = true;
  double rotationX = -0.34;
  double rotationY = 0.0;
  double rotationZ = 0.0;
  double perspective = 0.00135;
  double camera3DZoom = 0.96;
  Size fieldLogicalSize = const Size(1050, 680);

  // ===== Пользовательская текстура поля =====
  // Храним изображение прямо в документе схемы, чтобы оно не зависело от
  // локального пути на Mac/iPad и открывалось на другом устройстве.
  String? customFieldTextureBase64;
  String? customFieldTextureName;
  double customFieldTextureOpacity = 0.72;

  bool get hasCustomFieldTexture =>
      customFieldTextureBase64 != null && customFieldTextureBase64!.isNotEmpty;

  void setCustomFieldTexture({
    required String base64Data,
    required String name,
  }) {
    _commitUndo();
    customFieldTextureBase64 = base64Data;
    customFieldTextureName = name.trim().isEmpty ? 'Своя текстура' : name.trim();
    notifyListeners();
  }

  void setCustomFieldTextureOpacity(double value) {
    customFieldTextureOpacity = value.clamp(0.0, 1.0).toDouble();
    notifyListeners();
  }

  void clearCustomFieldTexture() {
    if (!hasCustomFieldTexture) return;
    _commitUndo();
    customFieldTextureBase64 = null;
    customFieldTextureName = null;
    customFieldTextureOpacity = 0.72;
    notifyListeners();
  }

  Size _normalizeFootballFieldSize(Size size) {
    // Редактор футбольной тактики работает в горизонтальной системе координат.
    // Старые версии могли сохранить портретный размер 930×1300 — приводим к 1050×680,
    // чтобы пресеты и объекты не собирались в одном углу.
    if (size.width < size.height) return const Size(1050, 680);
    return size;
  }

  void set3DParams({
    required bool enabled,
    double? rotationX,
    double? rotationY,
    double? rotationZ,
    double? perspective,
    double? cameraZoom,
    Size? fieldSize,
    bool notify = true,
  }) {
    is3DMode = enabled;

    if (rotationX != null) this.rotationX = rotationX;
    if (rotationY != null) this.rotationY = rotationY;
    if (rotationZ != null) this.rotationZ = rotationZ;
    if (perspective != null) this.perspective = perspective;
    if (cameraZoom != null) camera3DZoom = cameraZoom.clamp(.96, 1.38).toDouble();
    if (fieldSize != null) fieldLogicalSize = _normalizeFootballFieldSize(fieldSize);

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
      cameraZoom: 0.96,
    );
  }

  bool continuousDrawMode = false;

  void toggleContinuousDrawMode() {
//     print('🎯 [TgState] toggleContinuousDrawMode CALLED!');
//     print('🎯 [TgState] before = $continuousDrawMode');
    continuousDrawMode = !continuousDrawMode;
//     print('🎯 [TgState] after = $continuousDrawMode');
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


  void finishEditPoints() {
    final maybeSelected = selected;
    if (maybeSelected == null) return;

    if (maybeSelected is TgEditableCurve ||
        maybeSelected is TgEditableZigzag ||
        maybeSelected is TgEditableSpring ||
        maybeSelected is TgEditableSpiral ||
        maybeSelected is TgEditableWavy) {
      _finishEditableMode(maybeSelected);
      notifyListeners();
    }
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
    if (sel is! TgStamp || sel.locked) return;

    _commitUndo();
    final idx = _elements.indexWhere((e) => e.id == sel.id);
    if (idx < 0) return;


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
    // «Выбор» всегда означает режим трансформации объекта. Если тренер
    // редактировал контрольные точки, скрываем их и возвращаем обычные
    // ручки перемещения / масштаба / поворота на поле.
    if (t == TgTool.select && tool == TgTool.editPoints) {
      final sel = selected;
      if (sel is TgEditableCurve ||
          sel is TgEditableZigzag ||
          sel is TgEditableSpring ||
          sel is TgEditableSpiral ||
          sel is TgEditableWavy) {
        _finishEditableMode(sel!);
      }
    }

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

    if (a.startsWith('sportoteka://player-avatar')) return 66;
    if (a.startsWith('sportoteka://ball')) return 28;
    if (a.startsWith('sportoteka://cone')) return 34;
    if (a.startsWith('sportoteka://chip')) return 24;
    if (a.startsWith('sportoteka://dummy')) return 58;
    if (a.startsWith('sportoteka://goal')) return 94;

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

  String _activeTacticalLayer = 'tactical';
  String get activeTacticalLayer => _activeTacticalLayer;

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
      if (e.hidden) continue;
      if (e.hitTest(scene)) return e.id;
    }
    return null;
  }

  // ====== ordering ======
  void bringToFront() {
    if (selectedIds.isEmpty) return;
    _commitUndo();
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
    _commitUndo();
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

  void moveSelectedForward() {
    if (selectedIds.isEmpty) return;
    _commitUndo();
    for (final id in selectedIds.toList()) {
      final idx = _elements.indexWhere((e) => e.id == id);
      if (idx >= 0 && idx < _elements.length - 1) {
        final e = _elements.removeAt(idx);
        _elements.insert(idx + 1, e);
      }
    }
    notifyListeners();
  }

  void moveSelectedBackward() {
    if (selectedIds.isEmpty) return;
    _commitUndo();
    for (final id in selectedIds.toList()) {
      final idx = _elements.indexWhere((e) => e.id == id);
      if (idx > 0) {
        final e = _elements.removeAt(idx);
        _elements.insert(idx - 1, e);
      }
    }
    notifyListeners();
  }

  void selectLayerItem(String id) {
    selectById(id);
  }

  void updateElementMetaById(
    String id, {
    bool? hidden,
    bool? locked,
    String? layer,
    String? name,
  }) {
    final idx = _elements.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    _commitUndo();
    final json = Map<String, dynamic>.from(_elements[idx].toJson());
    if (hidden != null) json['hidden'] = hidden;
    if (locked != null) json['locked'] = locked;
    if (layer != null) json['layer'] = layer;
    if (name != null) json['name'] = name;
    _elements[idx] = TgElement.fromJson(json);
    notifyListeners();
  }

  void deleteElementById(String id) {
    final idx = _elements.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    _commitUndo();
    _elements.removeAt(idx);
    selectedIds.remove(id);
    if (selectedId == null && _elements.isNotEmpty) {
      selectedIds.add(_elements.last.id);
    }
    notifyListeners();
  }

  void deleteLayerGroup(String layer) {
    if (layer.trim().isEmpty) return;
    final before = _elements.length;
    _commitUndo();
    _elements.removeWhere((e) => e.layer == layer);
    if (_elements.length == before) return;
    selectedIds.removeWhere((id) => !_elements.any((e) => e.id == id));
    notifyListeners();
  }



  List<String> get layerNames {
    final names = <String>{};
    for (final e in _elements) {
      if (e.layer.trim().isNotEmpty) names.add(e.layer);
    }
    final list = names.toList()..sort();
    return list;
  }

  void duplicateLayerGroup(String layer) {
    final group = _elements.where((e) => e.layer == layer).toList();
    if (group.isEmpty) return;
    _commitUndo();
    final newLayer = '${layer}_copy';
    for (final e in group) {
      final json = Map<String, dynamic>.from(e.toJson());
      json['id'] = _newId();
      json['layer'] = newLayer;
      json['name'] = '${e.name ?? 'Элемент'} copy';
      _elements.add(TgElement.fromJson(json));
    }
    notifyListeners();
  }
  void setLayerGroupHidden(String layer, bool hidden) {
    if (layer.trim().isEmpty) return;
    _commitUndo();
    for (int i = 0; i < _elements.length; i++) {
      if (_elements[i].layer != layer) continue;
      final json = Map<String, dynamic>.from(_elements[i].toJson());
      json['hidden'] = hidden;
      _elements[i] = TgElement.fromJson(json);
    }
    notifyListeners();
  }

  void setLayerGroupLocked(String layer, bool locked) {
    if (layer.trim().isEmpty) return;
    _commitUndo();
    for (int i = 0; i < _elements.length; i++) {
      if (_elements[i].layer != layer) continue;
      final json = Map<String, dynamic>.from(_elements[i].toJson());
      json['locked'] = locked;
      _elements[i] = TgElement.fromJson(json);
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

  // ====== TacticalPad presets / football quick actions ======
  void applyTacticalPreset(String key, {bool replaceExisting = true}) {
    _commitUndo();
    if (key == 'clear_tactical') {
      _elements.removeWhere((e) => e.layer == 'tactical' || e.layer.startsWith('tactical_'));
      selectedIds.clear();
      _preview = null;
      notifyListeners();
      return;
    }

    if (replaceExisting) {
      _elements.removeWhere((e) => e.layer == 'tactical' || e.layer.startsWith('tactical_'));
    }

    selectedIds.clear();
    _preview = null;
    _panStart = null;
    _lastPan = null;
    _gestureBase = null;
    _activeTacticalLayer = 'tactical_${key.replaceAll(RegExp(r'[^a-zA-Z0-9_]+'), '_')}';

    switch (key) {
      case '433':
        _addFormation('4-3-3', [1, 4, 3, 3], ['GK', 'LB', 'LCB', 'RCB', 'RB', 'LCM', 'CM', 'RCM', 'LW', 'ST', 'RW']);
        _addTextLabel('4-3-3', const Offset(112, 54));
        break;
      case '442':
        _addFormation('4-4-2', [1, 4, 4, 2], ['GK', 'LB', 'LCB', 'RCB', 'RB', 'LM', 'LCM', 'RCM', 'RM', 'ST', 'ST']);
        _addTextLabel('4-4-2', const Offset(112, 54));
        break;
      case '352':
        _addFormation('3-5-2', [1, 3, 5, 2], ['GK', 'LCB', 'CB', 'RCB', 'LWB', 'LCM', 'CM', 'RCM', 'RWB', 'ST', 'ST']);
        _addTextLabel('3-5-2', const Offset(112, 54));
        break;
      case '4231':
        _addFormation('4-2-3-1', [1, 4, 2, 3, 1], ['GK', 'LB', 'LCB', 'RCB', 'RB', 'DM', 'DM', 'LAM', 'CAM', 'RAM', 'ST']);
        _addTextLabel('4-2-3-1', const Offset(130, 54));
        break;
      case '532':
        _addFormation('5-3-2', [1, 5, 3, 2], ['GK', 'LWB', 'LCB', 'CB', 'RCB', 'RWB', 'LCM', 'CM', 'RCM', 'ST', 'ST']);
        _addTextLabel('5-3-2', const Offset(112, 54));
        break;
      case 'build_up':
        _addFormation('Build-up', [1, 4, 3, 3], ['GK', 'LB', 'LCB', 'RCB', 'RB', 'LCM', 'CM', 'RCM', 'LW', 'ST', 'RW']);
        _addBuildUpRoutes();
        _addTextLabel('Билдап: выход через фланги', const Offset(245, 64));
        break;
      case 'goal_kick':
        _addFormation('Goal-kick', [1, 4, 3, 3], ['GK', 'LB', 'LCB', 'RCB', 'RB', 'DM', 'CM', 'AM', 'LW', 'ST', 'RW']);
        _addGoalKickPattern();
        _addTextLabel('Удар от ворот: розыгрыш', const Offset(250, 64));
        break;
      case 'counter':
        _addFormation('Counter', [1, 4, 2, 3, 1], ['GK', 'LB', 'LCB', 'RCB', 'RB', 'DM', 'DM', 'LW', 'AM', 'RW', 'ST']);
        _addCounterRoutes();
        _addTextLabel('Контратака: быстрый выход', const Offset(270, 64));
        break;
      case 'pressing':
        _addFormation('Pressing', [1, 4, 3, 3], ['GK', 'LB', 'LCB', 'RCB', 'RB', 'LCM', 'CM', 'RCM', 'LW', 'ST', 'RW']);
        _addPressingZones();
        _addTextLabel('Прессинг: зона давления', const Offset(270, 64));
        break;
      case 'low_block':
        _addFormation('Low block', [1, 5, 4, 1], ['GK', 'LWB', 'LCB', 'CB', 'RCB', 'RWB', 'LM', 'LCM', 'RCM', 'RM', 'ST']);
        _addLowBlock();
        _addTextLabel('Низкий блок 5-4-1', const Offset(230, 64));
        break;
      case 'rondo':
        _addRondoDrill();
        break;
      case 'speed':
        _addSpeedStations();
        break;
      case 'offside':
        _addFormation('Offside', [1, 4, 3, 3], ['GK', 'LB', 'LCB', 'RCB', 'RB', 'LCM', 'CM', 'RCM', 'LW', 'ST', 'RW']);
        _addOffsideLine();
        _addTextLabel('Линия офсайда', const Offset(250, 64));
        break;
      case 'overlap':
        _addFormation('Overlap', [1, 4, 3, 3], ['GK', 'LB', 'LCB', 'RCB', 'RB', 'LCM', 'CM', 'RCM', 'LW', 'ST', 'RW']);
        _addOverlapPattern();
        _addTextLabel('Забегание фланга', const Offset(245, 64));
        break;
      case 'third_man':
        _addFormation('Third man', [1, 4, 3, 3], ['GK', 'LB', 'LCB', 'RCB', 'RB', 'LCM', 'CM', 'RCM', 'LW', 'ST', 'RW']);
        _addThirdManPattern();
        _addTextLabel('Третий игрок', const Offset(220, 64));
        break;
      case 'corner':
        _addSetPieceCorner();
        break;
      case 'free_kick':
        _addFreeKickPattern();
        break;
      case 'animation_attack':
        _addFormation('Attack steps', [1, 4, 3, 3], ['GK', 'LB', 'LCB', 'RCB', 'RB', 'LCM', 'CM', 'RCM', 'LW', 'ST', 'RW']);
        _addAnimatedAttackFrames();
        _addTextLabel('Атака по шагам 1–4', const Offset(265, 64));
        break;
      case 'full_pack':
        _activeTacticalLayer = 'tactical_full_433';
        _addFormation('4-3-3', [1, 4, 3, 3], ['GK', 'LB', 'LCB', 'RCB', 'RB', 'LCM', 'CM', 'RCM', 'LW', 'ST', 'RW']);
        _addTextLabel('Пакет: 4-3-3', const Offset(112, 54));
        _activeTacticalLayer = 'tactical_full_routes';
        _addBuildUpRoutes();
        _addCounterRoutes();
        _addPressingZones();
        _activeTacticalLayer = 'tactical_full_drills';
        _addRondoDrill();
        _addSpeedStations();
        _activeTacticalLayer = 'tactical_full_steps';
        _addAnimatedAttackFrames();
        break;
      default:
        return;
    }

    _fitTacticalPadToSafeBoard();
    tool = TgTool.select;
    notifyListeners();
  }

  bool _isTacticalElement(TgElement e) => e.layer == 'tactical' || e.layer.startsWith('tactical_');

  Rect? _boundsForElements(Iterable<TgElement> items) {
    Rect? out;
    for (final e in items) {
      final b = e.bounds();
      if (b.width.isNaN || b.height.isNaN || b.left.isNaN || b.top.isNaN) continue;
      out = out == null ? b : out.expandToInclude(b);
    }
    return out;
  }

  void _fitTacticalPadToSafeBoard() {
    final tactical = _elements.where(_isTacticalElement).toList(growable: false);
    if (tactical.isEmpty) return;

    final src = _boundsForElements(tactical);
    if (src == null || src.width <= 0 || src.height <= 0) return;

    // Рабочая область как в TacticalPad: схема не должна заходить под панели,
    // мини-карту и края поля. Поэтому оставляем большие поля безопасности.
    final safe = Rect.fromLTWH(92, 78, fieldLogicalSize.width - 184, fieldLogicalSize.height - 156);
    final scale = math.min(safe.width / src.width, safe.height / src.height).clamp(0.52, 1.0).toDouble();
    final center = safe.center;
    final srcCenter = src.center;

    Offset tr(Offset p) => center + (p - srcCenter) * scale;
    double sv(double v) => v * scale;

    TgElement transform(TgElement e) {
      if (!_isTacticalElement(e)) return e;
      if (e is TgStamp) {
        return e.copyWith(
          pos: tr(e.pos),
          size: sv(e.size).clamp(26.0, 64.0).toDouble(),
        );
      }
      if (e is TgLine) {
        return e.copyWith(
          a: tr(e.a),
          b: tr(e.b),
          width: sv(e.width).clamp(2.5, 5.8).toDouble(),
          arrowSize: sv(e.arrowSize).clamp(14.0, 22.0).toDouble(),
        );
      }
      if (e is TgEditableCurve) {
        return e.copyWith(
          points: e.points.map(tr).toList(),
          width: sv(e.width).clamp(2.5, 5.8).toDouble(),
          arrowSize: sv(e.arrowSize).clamp(14.0, 22.0).toDouble(),
        );
      }
      if (e is TgCurve) {
        return e.copyWith(
          points: e.points.map(tr).toList(),
          width: sv(e.width).clamp(2.5, 5.8).toDouble(),
          arrowSize: sv(e.arrowSize).clamp(14.0, 22.0).toDouble(),
        );
      }
      if (e is TgWavy) {
        return e.copyWith(
          start: tr(e.start),
          endPoint: tr(e.endPoint),
          controlPoints: e.controlPoints.map(tr).toList(),
          width: sv(e.width).clamp(2.5, 5.8).toDouble(),
          amplitude: sv(e.amplitude).clamp(7.0, 12.0).toDouble(),
          wavelength: sv(e.wavelength).clamp(20.0, 32.0).toDouble(),
          arrowSize: sv(e.arrowSize).clamp(14.0, 22.0).toDouble(),
        );
      }
      if (e is TgRect) {
        return e.copyWith(
          position: tr(e.position),
          width: sv(e.width).clamp(24.0, fieldLogicalSize.width).toDouble(),
          height: sv(e.height).clamp(24.0, fieldLogicalSize.height).toDouble(),
          borderWidth: sv(e.borderWidth).clamp(1.5, 3.5).toDouble(),
          borderRadius: sv(e.borderRadius).clamp(8.0, 22.0).toDouble(),
        );
      }
      if (e is TgCircle) {
        return e.copyWith(
          position: tr(e.position),
          radius: sv(e.radius).clamp(12.0, 22.0).toDouble(),
          borderWidth: sv(e.borderWidth).clamp(1.5, 3.5).toDouble(),
        );
      }
      if (e is TgText) {
        return e.copyWith(
          position: tr(e.position),
          size: sv(e.size).clamp(12.0, 22.0).toDouble(),
        );
      }
      return e;
    }

    for (var i = 0; i < _elements.length; i++) {
      if (_isTacticalElement(_elements[i])) {
        _elements[i] = transform(_elements[i]);
      }
    }
  }

  String _tacticalAvatarAsset(String name, String number, Color ring, {bool keeper = false}) {
    return Uri(
      scheme: 'sportoteka',
      host: 'player-avatar',
      queryParameters: {
        'name': name,
        'number': number,
        'ring': '0x${ring.value.toRadixString(16).padLeft(8, '0')}',
        'team': 'home',
        if (keeper) 'role': 'goalkeeper',
      },
    ).toString();
  }

  void _addStamp(String asset, Offset pos, {double size = 62, double rotation = 0, String? name}) {
    _elements.add(TgStamp(
      id: _newId(),
      asset: asset,
      pos: pos,
      size: size,
      rotation: rotation,
      opacity: 1.0,
      layer: _activeTacticalLayer,
      name: name,
    ));
  }

  void _addLine(Offset a, Offset b, {Color color = const Color(0xFF00A750), double width = 5, LineKind kind = LineKind.normal, LineEnd end = LineEnd.arrow, String? name}) {
    _elements.add(TgLine(
      id: _newId(),
      a: a,
      b: b,
      color: color,
      width: width,
      kind: kind,
      end: end,
      arrowSize: 22,
      opacity: 1.0,
      layer: _activeTacticalLayer,
      name: name ?? 'Маршрут',
    ));
  }

  void _addWavyRoute(Offset start, Offset end, List<Offset> controls, {Color color = const Color(0xFF38BDF8), String? name}) {
    _elements.add(TgWavy(
      id: _newId(),
      start: start,
      endPoint: end,
      controlPoints: controls,
      color: color,
      width: 4.5,
      kind: LineKind.wavy,
      amplitude: 12,
      wavelength: 30,
      lineEnd: LineEnd.arrow,
      arrowSize: 20,
      opacity: 1.0,
      layer: _activeTacticalLayer,
      name: name ?? 'Дриблинг',
    ));
  }

  void _addZone(Rect rect, {Color color = const Color(0xFF00A750), double opacity = .14, String? name}) {
    _elements.add(TgRect(
      id: _newId(),
      position: rect.center,
      width: rect.width,
      height: rect.height,
      rotation: 0,
      fill: color.withOpacity(opacity),
      opacity: 1.0,
      border: color.withOpacity(.74),
      borderWidth: 3,
      borderKind: BorderKind.dashed,
      borderRadius: 22,
      layer: _activeTacticalLayer,
      name: name ?? 'Зона',
    ));
  }

  void _addTextLabel(String label, Offset pos) {
    _elements.add(TgText(
      id: _newId(),
      position: pos,
      text: label,
      size: 24,
      color: const Color(0xFF0B1220),
      opacity: 1.0,
      rotation: 0,
      fontFamily: null,
      weight: FontWeight.w900,
      alignment: TextAlign.center,
      style: TgTextStyle.normal,
      layer: _activeTacticalLayer,
      name: 'Название тактики',
    ));
  }

  void _addFormation(String title, List<int> lines, [List<String>? roles]) {
    final ring = const Color(0xFF00A750);
    final rowsX = <double>[];
    if (lines.length == 4) rowsX.addAll([105, 285, 515, 780]);
    if (lines.length == 5) rowsX.addAll([105, 265, 430, 620, 815]);
    int number = 1;
    int roleIndex = 0;
    for (int row = 0; row < lines.length; row++) {
      final count = lines[row];
      final x = rowsX[row];
      final top = row == 0 ? 340.0 : 118.0;
      final bottom = row == 0 ? 340.0 : 562.0;
      final gap = count <= 1 ? 0.0 : (bottom - top) / (count - 1);
      for (int i = 0; i < count; i++) {
        final y = count <= 1 ? 340.0 : top + gap * i;
        final isKeeper = row == 0;
        final n = isKeeper ? '1' : (++number).toString();
        final role = (roles != null && roleIndex < roles.length) ? roles[roleIndex] : (isKeeper ? 'GK' : '$title $n');
        roleIndex++;
        _addStamp(_tacticalAvatarAsset(role, n, ring, keeper: isKeeper), Offset(x, y), size: isKeeper ? 66 : 62, name: role);
      }
    }
  }

  void _addBuildUpRoutes() {
    _addZone(const Rect.fromLTWH(135, 135, 210, 410), color: const Color(0xFF38BDF8), name: 'Зона начала атаки');
    _addLine(const Offset(165, 340), const Offset(270, 170), color: const Color(0xFF38BDF8), name: 'Пас на левый фланг');
    _addLine(const Offset(165, 340), const Offset(270, 510), color: const Color(0xFF38BDF8), name: 'Пас на правый фланг');
    _addLine(const Offset(270, 170), const Offset(510, 155), color: const Color(0xFF00A750), name: 'Продвижение слева');
    _addLine(const Offset(270, 510), const Offset(510, 525), color: const Color(0xFF00A750), name: 'Продвижение справа');
    _addWavyRoute(const Offset(510, 340), const Offset(705, 330), [const Offset(575, 300), const Offset(640, 375)], color: const Color(0xFFF97316), name: 'Ведение через центр');
  }

  void _addCounterRoutes() {
    _addZone(const Rect.fromLTWH(555, 105, 270, 470), color: const Color(0xFFF97316), opacity: .12, name: 'Зона контратаки');
    _addLine(const Offset(360, 340), const Offset(610, 210), color: const Color(0xFFF97316), width: 6, name: 'Вертикальный пас');
    _addLine(const Offset(610, 210), const Offset(820, 170), color: const Color(0xFFEF334D), width: 6, name: 'Рывок в штрафную');
    _addLine(const Offset(610, 470), const Offset(835, 505), color: const Color(0xFFEF334D), width: 6, name: 'Рывок справа');
  }

  void _addPressingZones() {
    _addZone(const Rect.fromLTWH(620, 90, 300, 500), color: const Color(0xFFEF334D), opacity: .10, name: 'Зона высокого прессинга');
    _addLine(const Offset(720, 165), const Offset(850, 165), color: const Color(0xFFEF334D), kind: LineKind.dashed, name: 'Давление фланг');
    _addLine(const Offset(720, 340), const Offset(880, 340), color: const Color(0xFFEF334D), kind: LineKind.dashed, name: 'Давление центр');
    _addLine(const Offset(720, 515), const Offset(850, 515), color: const Color(0xFFEF334D), kind: LineKind.dashed, name: 'Давление фланг');
  }

  void _addRondoDrill() {
    _addTextLabel('Рондо 5v2', const Offset(520, 84));
    _addZone(const Rect.fromLTWH(335, 190, 380, 300), color: const Color(0xFF00A750), opacity: .10, name: 'Квадрат рондо');
    final ring = const Color(0xFF00A750);
    final red = const Color(0xFFEF334D);
    final points = [const Offset(360, 215), const Offset(690, 215), const Offset(690, 465), const Offset(360, 465), const Offset(525, 340)];
    for (int i = 0; i < points.length; i++) {
      _addStamp(_tacticalAvatarAsset('Игрок ${i + 1}', '${i + 1}', ring), points[i], size: 60, name: 'Рондо игрок ${i + 1}');
    }
    _addStamp(_tacticalAvatarAsset('Прессинг 1', 'D1', red), const Offset(470, 295), size: 56, name: 'Защитник 1');
    _addStamp(_tacticalAvatarAsset('Прессинг 2', 'D2', red), const Offset(580, 390), size: 56, name: 'Защитник 2');
    _addStamp('sportoteka://ball', const Offset(525, 340), size: 30, name: 'Мяч');
    _addLine(points[0], points[1], color: const Color(0xFF38BDF8), width: 3.5, name: 'Пас');
    _addLine(points[1], points[2], color: const Color(0xFF38BDF8), width: 3.5, name: 'Пас');
    _addLine(points[2], points[3], color: const Color(0xFF38BDF8), width: 3.5, name: 'Пас');
  }

  void _addSpeedStations() {
    _addTextLabel('Скоростные станции', const Offset(530, 78));
    for (int i = 0; i < 6; i++) {
      _addStamp('sportoteka://cone', Offset(230 + i * 70.0, 190), size: 34, name: 'Конус ${i + 1}');
      _addStamp('sportoteka://chip', Offset(230 + i * 70.0, 490), size: 28, name: 'Фишка ${i + 1}');
    }
    _addWavyRoute(const Offset(210, 190), const Offset(610, 190), [const Offset(290, 150), const Offset(370, 230), const Offset(450, 150), const Offset(530, 230)], color: const Color(0xFFF97316), name: 'Слалом');
    _addLine(const Offset(210, 490), const Offset(610, 490), color: const Color(0xFF00A750), width: 6, name: 'Спринт');
    _addZone(const Rect.fromLTWH(185, 145, 480, 110), color: const Color(0xFFF97316), opacity: .08, name: 'Станция слалома');
    _addZone(const Rect.fromLTWH(185, 445, 480, 90), color: const Color(0xFF00A750), opacity: .08, name: 'Станция спринта');
  }


  void _addGoalKickPattern() {
    _addZone(const Rect.fromLTWH(75, 190, 315, 300), color: const Color(0xFF38BDF8), opacity: .10, name: 'Зона розыгрыша от ворот');
    _addStamp('sportoteka://ball', const Offset(105, 340), size: 30, name: 'Мяч');
    _addLine(const Offset(105, 340), const Offset(285, 118), color: const Color(0xFF38BDF8), name: 'Пас в левого ЦЗ');
    _addLine(const Offset(105, 340), const Offset(285, 562), color: const Color(0xFF38BDF8), name: 'Пас в правого ЦЗ');
    _addLine(const Offset(285, 118), const Offset(430, 340), color: const Color(0xFF00A750), name: 'Через опорного');
    _addLine(const Offset(285, 562), const Offset(430, 340), color: const Color(0xFF00A750), name: 'Через опорного');
  }

  void _addLowBlock() {
    _addZone(const Rect.fromLTWH(65, 72, 420, 536), color: const Color(0xFFEF334D), opacity: .08, name: 'Компактный низкий блок');
    _addLine(const Offset(260, 118), const Offset(390, 118), color: const Color(0xFFEF334D), kind: LineKind.dashed, end: LineEnd.none, name: 'Сдвиг линии');
    _addLine(const Offset(260, 562), const Offset(390, 562), color: const Color(0xFFEF334D), kind: LineKind.dashed, end: LineEnd.none, name: 'Сдвиг линии');
    _addLine(const Offset(430, 340), const Offset(610, 340), color: const Color(0xFFF97316), width: 5.5, name: 'Выход в контратаку');
  }

  void _addOverlapPattern() {
    _addZone(const Rect.fromLTWH(610, 90, 270, 210), color: const Color(0xFF38BDF8), opacity: .10, name: 'Фланговая зона перегруза');
    _addLine(const Offset(515, 118), const Offset(780, 118), color: const Color(0xFF38BDF8), width: 5.5, name: 'Пас на вингера');
    _addWavyRoute(const Offset(285, 118), const Offset(855, 95), [const Offset(420, 65), const Offset(610, 72), const Offset(740, 82)], color: const Color(0xFFF97316), name: 'Забегание фулбека');
    _addLine(const Offset(780, 118), const Offset(890, 220), color: const Color(0xFF00A750), width: 4.5, name: 'Прострел');
    _addStamp('sportoteka://ball', const Offset(780, 118), size: 30, name: 'Мяч');
  }

  void _addThirdManPattern() {
    _addZone(const Rect.fromLTWH(430, 220, 270, 240), color: const Color(0xFF00A750), opacity: .09, name: 'Треугольник третьего игрока');
    _addLine(const Offset(515, 340), const Offset(620, 230), color: const Color(0xFF38BDF8), name: 'Пас 1');
    _addLine(const Offset(620, 230), const Offset(700, 340), color: const Color(0xFF38BDF8), name: 'Сброс');
    _addWavyRoute(const Offset(515, 340), const Offset(780, 340), [const Offset(600, 410), const Offset(700, 285)], color: const Color(0xFFF97316), name: 'Вбегание третьего');
    _addStamp('sportoteka://ball', const Offset(620, 230), size: 30, name: 'Мяч');
  }

  void _addSetPieceCorner() {
    _addTextLabel('Угловой: розыгрыш', const Offset(530, 78));
    final ring = const Color(0xFF00A750);
    final red = const Color(0xFFEF334D);
    final attackers = [const Offset(900, 108), const Offset(860, 220), const Offset(800, 310), const Offset(870, 400), const Offset(770, 510)];
    for (int i = 0; i < attackers.length; i++) {
      _addStamp(_tacticalAvatarAsset('A${i + 1}', '${i + 1}', ring), attackers[i], size: 58, name: 'Атака угловой ${i + 1}');
    }
    for (int i = 0; i < 4; i++) {
      _addStamp(_tacticalAvatarAsset('D${i + 1}', 'D${i + 1}', red), Offset(835 + (i % 2) * 50.0, 260 + i * 58.0), size: 54, name: 'Защитник угловой ${i + 1}');
    }
    _addStamp('sportoteka://ball', const Offset(935, 82), size: 30, name: 'Мяч угловой');
    _addLine(const Offset(935, 82), const Offset(800, 310), color: const Color(0xFF38BDF8), width: 5.5, name: 'Подача');
    _addWavyRoute(const Offset(900, 108), const Offset(760, 250), [const Offset(890, 180), const Offset(820, 210)], color: const Color(0xFFF97316), name: 'Рывок на ближнюю');
    _addZone(const Rect.fromLTWH(730, 180, 230, 330), color: const Color(0xFFEF334D), opacity: .08, name: 'Штрафная зона');
  }

  void _addFreeKickPattern() {
    _addTextLabel('Штрафной: подача и подбор', const Offset(530, 78));
    _addZone(const Rect.fromLTWH(690, 145, 260, 390), color: const Color(0xFFEF334D), opacity: .08, name: 'Зона завершения');
    _addStamp('sportoteka://ball', const Offset(635, 510), size: 30, name: 'Мяч штрафной');
    _addLine(const Offset(635, 510), const Offset(810, 300), color: const Color(0xFF38BDF8), width: 5.5, name: 'Подача в штрафную');
    _addLine(const Offset(810, 300), const Offset(900, 250), color: const Color(0xFF00A750), width: 4, name: 'Скидка');
    _addWavyRoute(const Offset(700, 470), const Offset(815, 300), [const Offset(715, 410), const Offset(760, 350)], color: const Color(0xFFF97316), name: 'Рывок под подачу');
  }

  void _addAnimatedAttackFrames() {
    final steps = [
      (1, const Offset(305, 340), '1. Первый пас'),
      (2, const Offset(515, 230), '2. Третий игрок'),
      (3, const Offset(715, 160), '3. Забегание'),
      (4, const Offset(870, 250), '4. Завершение'),
    ];
    for (final s in steps) {
      _addCircleMarker(s.$2, '${s.$1}', color: const Color(0xFF0B1220));
      _addTextLabel(s.$3, s.$2 + const Offset(0, -48));
    }
    _addLine(steps[0].$2, steps[1].$2, color: const Color(0xFF38BDF8), name: 'Шаг 1');
    _addWavyRoute(steps[1].$2, steps[2].$2, [const Offset(590, 175), const Offset(650, 210)], color: const Color(0xFFF97316), name: 'Шаг 2');
    _addLine(steps[2].$2, steps[3].$2, color: const Color(0xFF00A750), width: 5.5, name: 'Шаг 3');
    _addStamp('sportoteka://ball', steps[0].$2, size: 28, name: 'Мяч шаг 1');
  }

  void _addCircleMarker(Offset pos, String text, {Color color = const Color(0xFF0B1220)}) {
    _elements.add(TgCircle(
      id: _newId(),
      position: pos,
      radius: 19,
      rotation: 0,
      fill: color.withOpacity(.90),
      opacity: 1,
      border: Colors.white,
      borderWidth: 3,
      borderKind: BorderKind.solid,
      layer: _activeTacticalLayer,
      name: 'Шаг $text',
    ));
    _elements.add(TgText(
      id: _newId(),
      position: pos,
      text: text,
      size: 18,
      color: Colors.white,
      opacity: 1,
      rotation: 0,
      fontFamily: null,
      weight: FontWeight.w900,
      alignment: TextAlign.center,
      style: TgTextStyle.normal,
      layer: _activeTacticalLayer,
      name: 'Номер шага $text',
    ));
  }

  void _addOffsideLine() {
    _addLine(const Offset(650, 92), const Offset(650, 590), color: const Color(0xFFEF334D), width: 4, kind: LineKind.dashed, end: LineEnd.none, name: 'Линия офсайда');
    _addZone(const Rect.fromLTWH(650, 92, 260, 498), color: const Color(0xFFEF334D), opacity: .07, name: 'Опасная зона за спиной');
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
    if (sel == null || sel.locked) return;

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
    if (sel == null || sel.locked) return;

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
    if (sel == null || sel.locked) return;

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
      if (e.locked || e.hidden) continue;

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
      } else if (e is TgCurve) {
        _elements[idx] = e.copyWith(
          points: e.points.map((p) => p + delta).toList(),
        );
      } else if (e is TgPolyline) {
        _elements[idx] = e.copyWith(
          points: e.points.map((p) => p + delta).toList(),
        );
      } else if (e is TgZone) {
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

  Offset _transformGesturePoint(
    Offset point, {
    required Offset center,
    required Offset moveDelta,
    required double scaleFactor,
    required double rotationDelta,
  }) {
    final v = point - center;
    final c = math.cos(rotationDelta);
    final sn = math.sin(rotationDelta);
    final rotated = Offset(
      v.dx * c - v.dy * sn,
      v.dx * sn + v.dy * c,
    ) * scaleFactor;
    return center + rotated + moveDelta;
  }

  List<Offset> _transformGesturePoints(
    Iterable<Offset> points, {
    required Offset center,
    required Offset moveDelta,
    required double scaleFactor,
    required double rotationDelta,
  }) {
    return points
        .map(
          (p) => _transformGesturePoint(
            p,
            center: center,
            moveDelta: moveDelta,
            scaleFactor: scaleFactor,
            rotationDelta: rotationDelta,
          ),
        )
        .toList(growable: false);
  }

  /// Transform selected elements from the snapshot captured by
  /// [commitOnceForGestureStart]. This is used by the on-canvas resize /
  /// rotate handles and by two-finger object gestures.
  void transformSelectedGesture({
    required Offset centerScene,
    required Offset moveDelta,
    required double scaleFactor,
    required double rotationDelta,
  }) {
    if (selectedIds.isEmpty) return;
    final base = _gestureBase;
    if (base == null || base.isEmpty) return;

    final f = scaleFactor.clamp(0.10, 10.0).toDouble();

    Offset tp(Offset p) => _transformGesturePoint(
          p,
          center: centerScene,
          moveDelta: moveDelta,
          scaleFactor: f,
          rotationDelta: rotationDelta,
        );
    List<Offset> tps(Iterable<Offset> points) => _transformGesturePoints(
          points,
          center: centerScene,
          moveDelta: moveDelta,
          scaleFactor: f,
          rotationDelta: rotationDelta,
        );

    for (final id in selectedIds) {
      final idx = _elements.indexWhere((e) => e.id == id);
      if (idx < 0) continue;
      final b = base[id];
      if (b == null || b.locked || b.hidden) continue;

      if (b is TgStamp) {
        _elements[idx] = b.copyWith(
          pos: tp(b.pos),
          rotation: b.rotation + rotationDelta,
          size: (b.size * f).clamp(16.0, 1200.0),
        );
      } else if (b is TgRect) {
        _elements[idx] = b.copyWith(
          position: tp(b.position),
          rotation: b.rotation + rotationDelta,
          width: (b.width * f).clamp(12.0, 4000.0),
          height: (b.height * f).clamp(12.0, 4000.0),
        );
      } else if (b is TgCircle) {
        _elements[idx] = b.copyWith(
          position: tp(b.position),
          rotation: b.rotation + rotationDelta,
          radius: (b.radius * f).clamp(6.0, 2000.0),
        );
      } else if (b is TgText) {
        _elements[idx] = b.copyWith(
          position: tp(b.position),
          rotation: b.rotation + rotationDelta,
          size: (b.size * f).clamp(7.0, 320.0),
        );
      } else if (b is TgLine) {
        _elements[idx] = b.copyWith(
          a: tp(b.a),
          b: tp(b.b),
          arrowSize: (b.arrowSize * f).clamp(5.0, 120.0),
        );
      } else if (b is TgEditableCurve) {
        _elements[idx] = b.copyWith(
          points: tps(b.points),
          arrowSize: (b.arrowSize * f).clamp(5.0, 120.0),
        );
      } else if (b is TgCurve) {
        _elements[idx] = b.copyWith(
          points: tps(b.points),
          arrowSize: (b.arrowSize * f).clamp(5.0, 120.0),
        );
      } else if (b is TgPolyline) {
        _elements[idx] = b.copyWith(
          points: tps(b.points),
          arrowSize: (b.arrowSize * f).clamp(5.0, 120.0),
        );
      } else if (b is TgZone) {
        _elements[idx] = b.copyWith(points: tps(b.points));
      } else if (b is TgEditableWavy) {
        _elements[idx] = b.copyWith(
          start: tp(b.start),
          endPoint: tp(b.endPoint),
          controlPoints: tps(b.controlPoints),
          amplitude: (b.amplitude * f).clamp(2.0, 500.0),
          wavelength: (b.wavelength * f).clamp(4.0, 1000.0),
          arrowSize: (b.arrowSize * f).clamp(5.0, 120.0),
        );
      } else if (b is TgWavy) {
        _elements[idx] = b.copyWith(
          start: tp(b.start),
          endPoint: tp(b.endPoint),
          controlPoints: tps(b.controlPoints),
          amplitude: (b.amplitude * f).clamp(2.0, 500.0),
          wavelength: (b.wavelength * f).clamp(4.0, 1000.0),
          arrowSize: (b.arrowSize * f).clamp(5.0, 120.0),
        );
      } else if (b is TgEditableZigzag) {
        _elements[idx] = b.copyWith(
          start: tp(b.start),
          endPoint: tp(b.endPoint),
          controlPoints: tps(b.controlPoints),
          amplitude: (b.amplitude * f).clamp(2.0, 500.0),
          arrowSize: (b.arrowSize * f).clamp(5.0, 120.0),
        );
      } else if (b is TgZigzag) {
        _elements[idx] = b.copyWith(
          start: tp(b.start),
          endPoint: tp(b.endPoint),
          amplitude: (b.amplitude * f).clamp(2.0, 500.0),
          arrowSize: (b.arrowSize * f).clamp(5.0, 120.0),
        );
      } else if (b is TgEditableSpring) {
        _elements[idx] = b.copyWith(
          start: tp(b.start),
          endPoint: tp(b.endPoint),
          controlPoints: tps(b.controlPoints),
          amplitude: (b.amplitude * f).clamp(2.0, 500.0),
          arrowSize: (b.arrowSize * f).clamp(5.0, 120.0),
        );
      } else if (b is TgSpring) {
        _elements[idx] = b.copyWith(
          start: tp(b.start),
          endPoint: tp(b.endPoint),
          amplitude: (b.amplitude * f).clamp(2.0, 500.0),
          arrowSize: (b.arrowSize * f).clamp(5.0, 120.0),
        );
      } else if (b is TgEditableSpiral) {
        _elements[idx] = b.copyWith(
          start: tp(b.start),
          endPoint: tp(b.endPoint),
          controlPoints: tps(b.controlPoints),
          amplitude: (b.amplitude * f).clamp(2.0, 500.0),
          arrowSize: (b.arrowSize * f).clamp(5.0, 120.0),
        );
      } else if (b is TgSpiral) {
        _elements[idx] = b.copyWith(
          start: tp(b.start),
          endPoint: tp(b.endPoint),
          amplitude: (b.amplitude * f).clamp(2.0, 500.0),
          arrowSize: (b.arrowSize * f).clamp(5.0, 120.0),
        );
      }
    }

    notifyListeners();
  }

  /// Backward-compatible wrapper used by older right-panel controls.
  void transformSelected({
    required Offset moveDelta,
    required double absoluteRotation,
    required double absoluteScaleBase,
  }) {
    final base = _gestureBase;
    if (selectedIds.isEmpty || base == null || base.isEmpty) return;

    Rect? bounds;
    for (final e in base.values) {
      bounds = bounds == null ? e.bounds() : bounds!.expandToInclude(e.bounds());
    }
    final center = (bounds ?? Rect.zero).center;

    // Older code supplied an absolute rotation for simple objects. Convert it
    // into a delta based on the first selected object where possible.
    double baseRotation = 0.0;
    final first = base.values.isEmpty ? null : base.values.first;
    if (first is TgStamp) baseRotation = first.rotation;
    if (first is TgRect) baseRotation = first.rotation;
    if (first is TgCircle) baseRotation = first.rotation;
    if (first is TgText) baseRotation = first.rotation;

    transformSelectedGesture(
      centerScene: center,
      moveDelta: moveDelta,
      scaleFactor: (absoluteScaleBase / 100.0).clamp(0.10, 10.0).toDouble(),
      rotationDelta: absoluteRotation - baseRotation,
    );
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
//     print("🎯 TgState.startSpiral: startPoint=$startPoint");
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
//     print("🎯 TgState.finishSpiral");
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
//     print("🎯 TgState.editSpiralPoints");
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

//     print("🎯 updateSelectedSpiral: sel type=${sel.runtimeType}");

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
//         print("🎯 updateSelectedSpiral: пересчет контрольных точек");

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

        if (selectedElem is TgEditableCurve) {
          editSelectedCurvePoints();
        } else if (selectedElem is TgZigzag) {
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
//     print('🎯 onPanStart: scene=$scene, tool=$tool');

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
      startCurve(scene, CurveType.quadratic);
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
      if (p.points.length >= 2) {
        final newPoints = List<Offset>.from(p.points);
        newPoints[newPoints.length - 1] = scene;
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
//     print('🎯 ===== O N   P A N   E N D =====');
//     print('🎯 tool: $tool');
//     print('🎯 continuousDrawMode: $continuousDrawMode');
//     print('🎯 _preview: $_preview');
//     print('🎯 _preview.runtimeType: ${_preview.runtimeType}');

    if (tool == TgTool.editPoints) {
//       print('🎯 editPoints mode, returning');
      _lastPan = null;
      return;
    }

    final p = _preview;
//     print('🎯 p: $p');
//     print('🎯 p?.id: ${p?.id}');
//     print('🎯 p is TgWavy? ${p is TgWavy}');

    if (p != null && p.id == "_preview") {
//       print('🎯 Preview found with id _preview');

      if (p is TgEditableCurve) {
//         print('🎯 finishing curve');
        finishCurve();
      } else if (p is TgEditableZigzag) {
//         print('🎯 finishing zigzag');
        finishZigzag();
      } else if (p is TgEditableSpring) {
//         print('🎯 finishing spring');
        finishSpring();
      } else if (p is TgEditableSpiral) {
//         print('🎯 finishing spiral');
        finishSpiral();
      } else {
//         print('🎯 regular element, committing undo');
        _commitUndo();

        TgElement e;

        if (p is TgStamp) {
//           print('🎯 processing stamp');
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

//         print('🎯 Adding element to _elements: ${e.runtimeType}');
        _elements.add(e);

//         print('🎯 CHECKING CONTINUOUS CONDITION:');
//         print('  - p is TgWavy? ${p is TgWavy}');
//         print('  - continuousDrawMode? $continuousDrawMode');

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
//           print('🎯 Continuous mode condition FAILED');
//           if (!(p is TgWavy)) print('🎯   Reason: p is not TgWavy');
          if (!continuousDrawMode) {
//             print('🎯   Reason: continuousDrawMode is false');
          }

          if (p is TgStamp && stickyStampMode && _activeStampAsset != null) {
            selectedIds
              ..clear()
              ..add(e.id);
          } else {
//             print('🎯 Just selecting');
            selectById(e.id);
          }
        }
      }
    } else {
//       print('🎯 No preview or preview id not _preview');
    }

//     print('🎯 END OF onPanEnd - resetting preview?');
//     print('🎯 continuousDrawMode: $continuousDrawMode');
//     print('🎯 tool: $tool');

    if (!continuousDrawMode) {
//       print('🎯 Continuous mode OFF - resetting preview');
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
//     print('🎯 Final notifyListeners()');
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
      "camera_3d_zoom": camera3DZoom,
      "field_logical_width": fieldLogicalSize.width,
      "field_logical_height": fieldLogicalSize.height,
      "custom_field_texture_base64": customFieldTextureBase64,
      "custom_field_texture_name": customFieldTextureName,
      "custom_field_texture_opacity": customFieldTextureOpacity,
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

    final hasSaved3DMode = json.containsKey("is_3d_mode");
    is3DMode = hasSaved3DMode ? json["is_3d_mode"] == true : true;
    rotationX = _asDouble(json["rotation_x"], is3DMode ? -0.34 : 0.0);
    rotationY = _asDouble(json["rotation_y"], 0.0);
    rotationZ = _asDouble(json["rotation_z"], 0.0);
    perspective = _asDouble(json["perspective"], 0.00135);
    camera3DZoom = _asDouble(json["camera_3d_zoom"], 0.96).clamp(.96, 1.38).toDouble();

    final fieldW = _asDouble(json["field_logical_width"], 1050.0);
    final fieldH = _asDouble(json["field_logical_height"], 680.0);
    fieldLogicalSize = _normalizeFootballFieldSize(Size(fieldW, fieldH));

    final texture = (json["custom_field_texture_base64"] ?? "").toString().trim();
    customFieldTextureBase64 = texture.isEmpty ? null : texture;
    final textureName = (json["custom_field_texture_name"] ?? "").toString().trim();
    customFieldTextureName = textureName.isEmpty ? null : textureName;
    customFieldTextureOpacity = _asDouble(
      json["custom_field_texture_opacity"],
      0.72,
    ).clamp(0.0, 1.0).toDouble();

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
      camera3DZoom: camera3DZoom,
      fieldLogicalSize: fieldLogicalSize,
      customFieldTextureBase64: customFieldTextureBase64,
      customFieldTextureName: customFieldTextureName,
      customFieldTextureOpacity: customFieldTextureOpacity,
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
    camera3DZoom = s.camera3DZoom;
    fieldLogicalSize = s.fieldLogicalSize;
    customFieldTextureBase64 = s.customFieldTextureBase64;
    customFieldTextureName = s.customFieldTextureName;
    customFieldTextureOpacity = s.customFieldTextureOpacity;

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
    required this.camera3DZoom,
    required this.fieldLogicalSize,
    required this.customFieldTextureBase64,
    required this.customFieldTextureName,
    required this.customFieldTextureOpacity,
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
  final double camera3DZoom;
  final Size fieldLogicalSize;
  final String? customFieldTextureBase64;
  final String? customFieldTextureName;
  final double customFieldTextureOpacity;
}