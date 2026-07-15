import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as v;

import 'package:sportoteka/presentation/training_graphics/tg_models.dart';

/// ✅ ВАЖНО: без этого у тебя валится всё (TgTool not found)
enum TgTool {
  select,
  line,
  wavyLine,
  rect,
  circle,
  text,
  stamp,
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

  final int teamId;
  final String teamName;

  // ===== viewport / modes =====
  final TgViewportTransform transform = TgViewportTransform();
  bool fieldEditMode = false;
  bool lockViewportGestures = false;

  void setLockViewport(bool v) {
    lockViewportGestures = v;
    notifyListeners();
  }

  void toggleFieldEditMode() {
    fieldEditMode = !fieldEditMode;
    notifyListeners();
  }

  // ===== top editor (collapse/expand) ✅ ADDED =====
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

    tool = TgTool.select; // ✅ важно

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

    tool = TgTool.select; // ✅ важно

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
  
  void updateSelectedStamp({
  double? size,
  double? opacity,
  double? rotation,
  Color? color, // Добавлено
}) {
  final sel = selected;
  if (sel is! TgStamp) return;

  _commitUndo();
  final idx = _elements.indexWhere((e) => e.id == sel.id);
  if (idx < 0) return;

  _elements[idx] = sel.copyWith(
    size: size?.clamp(20.0, 260.0) ?? sel.size,
    opacity: opacity?.clamp(0.0, 1.0) ?? sel.opacity,
    rotation: rotation ?? sel.rotation,
    color: color ?? sel.color, // Добавлено
  );
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
      copy = sel.copyWith(id: _newId(), position: sel.position + const Offset(dx, dy));
    } else if (sel is TgCircle) {
      copy = sel.copyWith(id: _newId(), position: sel.position + const Offset(dx, dy));
    } else if (sel is TgText) {
      copy = sel.copyWith(id: _newId(), position: sel.position + const Offset(dx, dy));
    } else if (sel is TgStamp) {
      copy = sel.copyWith(id: _newId(), pos: sel.pos + const Offset(dx, dy));
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
  }) {
    final sel = selected;
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
    );
    notifyListeners();
  }

  void updateSelectedShape({
    Color? fill,
    double? opacity,
    Color? border,
    double? borderW,
    BorderKind? kind,
    double? borderRadius, // rect
    double? radius, // circle
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

  _elements[idx] = sel.copyWith(
    opacity: o.clamp(0.0, 1.0),
    color: sel.color, // Сохраняем цвет
  );
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

    if (sel is TgRect) _elements[idx] = sel.copyWith(rotation: sel.rotation + deltaRadians);
    if (sel is TgCircle) _elements[idx] = sel.copyWith(rotation: sel.rotation + deltaRadians);
    if (sel is TgText) _elements[idx] = sel.copyWith(rotation: sel.rotation + deltaRadians);
    if (sel is TgStamp) _elements[idx] = sel.copyWith(rotation: sel.rotation + deltaRadians);

    notifyListeners();
  }

  void setSelectedRotationAbsolute(double radians) {
  final sel = selected;
  if (sel == null) return;

  _commitUndo();
  final idx = _elements.indexWhere((e) => e.id == sel.id);
  if (idx < 0) return;

  if (sel is TgRect) _elements[idx] = sel.copyWith(rotation: radians);
  if (sel is TgCircle) _elements[idx] = sel.copyWith(rotation: radians);
  if (sel is TgText) _elements[idx] = sel.copyWith(rotation: radians);
  if (sel is TgStamp) _elements[idx] = sel.copyWith(
    rotation: radians,
    color: sel.color, // Сохраняем цвет
  );

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

  // ===== scale helper for toolbar zoom buttons ✅ ADDED =====
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
      }
    }
    notifyListeners();
  }

  void transformSelected({
    required Offset moveDelta,
    required double absoluteRotation,
    required double absoluteScaleBase, // 100 * scale
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
            color: b.color, // Сохраняем цвет
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
      }
    }

    notifyListeners();
  }

  // ===== drawing / pan pipeline (for non-select tools) =====
  Offset? _panStart;
  Offset? _lastPan;

  void onTap(Offset scene) {
    if (tool == TgTool.select) {
      final hit = hitTest(scene);
      if (hit == null) {
        clearSelection();
      } else {
        selectById(hit);
      }
      return;
    }
    
    
case "stamp":
  return TgStamp(
    id: id,
    asset: (m["asset"] ?? "").toString(),
    pos: readPos(m["pos"]),
    size: _asDouble(m["size"], 90),
    rotation: _asDouble(m["rot"], 0),
    opacity: _asDouble(m["opacity"], 1.0).clamp(0.0, 1.0).toDouble(),
    color: m.containsKey("color") 
        ? Color((m["color"] as int)) 
        : null, // Добавлено
  );


    // ✅ Текст — создаём по тапу
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

    // ✅ Штамп — ставим по тапу (один раз)
    if (tool == TgTool.stamp && _activeStampAsset != null) {
      _commitUndo();
      final e = TgStamp(
        id: _newId(),
        asset: _activeStampAsset!,
        pos: scene,
        size: 90,
        rotation: 0,
        opacity: 0.8,
      );
      _elements.add(e);
      selectById(e.id);
      notifyListeners();
      return;
    }
  }

  void onPanStart(Offset scene) {
    _panStart = scene;
    _lastPan = scene;

    if (tool == TgTool.line || tool == TgTool.wavyLine) {
  _preview = TgLine(
    id: "_preview",
    a: scene,
    b: scene,
    color: Colors.white,
    width: 4,
    kind: (tool == TgTool.wavyLine) ? LineKind.wavy : LineKind.normal, // ✅
    end: LineEnd.none,
    arrowSize: 18,
  );
}
 else if (tool == TgTool.rect) {
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
      _preview = TgStamp(
        id: "_preview",
        asset: _activeStampAsset!,
        pos: scene,
        size: 90,
        rotation: 0,
        opacity: 0.8,
      );
    }

    notifyListeners();
  }

  void onPanUpdate(Offset scene) {
    final start = _panStart;
    if (start == null) return;

    if (tool == TgTool.line && _preview is TgLine) {
      final p = _preview as TgLine;
      _preview = p.copyWith(b: scene);
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
       color: p.color, // Сохраняем цвет
    }

    _lastPan = scene;
    notifyListeners();
  }

  void onPanEnd() {
    final p = _preview;
    if (p != null && p.id == "_preview") {
      _commitUndo();
      final e = _cloneWithNewId(p);
      _elements.add(e);
      selectById(e.id);

      // ✅ возвращаемся на select после “рисования”
      tool = TgTool.select;
    }

    _preview = null;
    _panStart = null;
    _lastPan = null;
    _gestureBase = null;
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
      gridEnabled: gridEnabled,
      gridStep: gridStep,
      snapRotationEnabled: snapRotationEnabled,
      snapRotationDegrees: snapRotationDegrees,
      activeStampAsset: _activeStampAsset,
      viewport: transform.value.value.clone(),
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
    gridEnabled = s.gridEnabled;
    gridStep = s.gridStep;
    snapRotationEnabled = s.snapRotationEnabled;
    snapRotationDegrees = s.snapRotationDegrees;
    _activeStampAsset = s.activeStampAsset;
    transform.value.value = s.viewport.clone();

    _preview = null;
    _panStart = null;
    _lastPan = null;
    _gestureBase = null;

    notifyListeners();
  }

  // ===============================
  // JSON export/import for server
  // ===============================
  Map<String, dynamic> toJson() {
    return {
      "v": 1,
      "team_id": teamId,
      "team_name": teamName,
      "tool": tool.name,
      "field_edit_mode": fieldEditMode,
      "grid_enabled": gridEnabled,
      "grid_step": gridStep,
      "snap_rotation_enabled": snapRotationEnabled,
      "snap_rotation_degrees": snapRotationDegrees,
      "active_stamp_asset": _activeStampAsset,
      "viewport": transform.value.value.storage.toList(),
      "elements": _elements.map(_elementToJson).toList(),
      "selected_ids": selectedIds.toList(),
    };
  }

  void loadFromJson(Map<String, dynamic> json) {
    // elements
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

    // tool
    final toolStr = (json["tool"] ?? "").toString();
    TgTool? parsedTool;
    for (final t in TgTool.values) {
      if (t.name == toolStr) {
        parsedTool = t;
        break;
      }
    }
    if (parsedTool != null) tool = parsedTool;

    // flags/settings
    fieldEditMode = (json["field_edit_mode"] == true);

    gridEnabled = (json["grid_enabled"] == true);
    gridStep = _asDouble(json["grid_step"], gridStep);

    snapRotationEnabled = (json["snap_rotation_enabled"] == true);
    snapRotationDegrees =
        _asDouble(json["snap_rotation_degrees"], snapRotationDegrees).clamp(1, 90).toDouble();

    final stamp = (json["active_stamp_asset"] ?? "").toString().trim();
    _activeStampAsset = stamp.isEmpty ? null : stamp;

    // viewport
    final vp = json["viewport"];
    if (vp is List && vp.length == 16) {
      final m = Matrix4.fromList(
        vp.map((e) => _asDouble(e, 0)).toList().cast<double>(),
      );
      transform.value.value = m;
    }

    // apply loaded
    _elements
      ..clear()
      ..addAll(loaded);

    // selection (optional)
    selectedIds
      ..clear()
      ..addAll(((json["selected_ids"] is List) ? (json["selected_ids"] as List) : const [])
          .map((e) => e.toString())
          .where((s) => s.isNotEmpty));

    // reset transient
    _preview = null;
    _panStart = null;
    _lastPan = null;
    _gestureBase = null;

    // clear undo/redo because we loaded a new doc
    _undo.clear();
    _redo.clear();

    notifyListeners();
  }

  // ---------- helpers ----------
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
      return {
        "type": "stamp",
        "id": e.id,
        "asset": e.asset,
        "pos": {"x": e.pos.dx, "y": e.pos.dy},
        "size": e.size,
        "rot": e.rotation,
        "opacity": e.opacity,
          if (e.color != null) "color": e.color!.value, // Добавлено
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

    LineKind parseLineKind(String s) {
      return LineKind.values.firstWhere((e) => e.name == s, orElse: () => LineKind.normal);
    }

    LineEnd parseLineEnd(String s) {
      return LineEnd.values.firstWhere((e) => e.name == s, orElse: () => LineEnd.none);
    }

    BorderKind parseBorderKind(String s) {
      return BorderKind.values.firstWhere((e) => e.name == s, orElse: () => BorderKind.solid);
    }

    TgTextStyle parseTextStyle(String s) {
      return TgTextStyle.values.firstWhere((e) => e.name == s, orElse: () => TgTextStyle.normal);
    }

    TextAlign parseAlign(String s) {
      return TextAlign.values.firstWhere((e) => e.name == s, orElse: () => TextAlign.center);
    }

    FontWeight parseWeight(dynamic w) {
      if (w is int && w >= 0 && w < FontWeight.values.length) return FontWeight.values[w];
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
          borderKind: parseBorderKind((m["border_kind"] ?? "solid").toString()),
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
          borderKind: parseBorderKind((m["border_kind"] ?? "solid").toString()),
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
          fontFamily: (m["font_family"] == null) ? null : (m["font_family"] as String),
          weight: parseWeight(m["weight"]),
          alignment: parseAlign((m["align"] ?? "center").toString()),
          style: parseTextStyle((m["style"] ?? "normal").toString()),
        );
      case "stamp":
        return TgStamp(
          id: id,
          asset: (m["asset"] ?? "").toString(),
          pos: readPos(m["pos"]),
          size: _asDouble(m["size"], 90),
          rotation: _asDouble(m["rot"], 0),
          opacity: _asDouble(m["opacity"], 1.0).clamp(0.0, 1.0).toDouble(),
        );
      default:
        return null;
    }
  }

  // ===== utils =====
  String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

 TgElement _cloneWithNewId(TgElement e) {
  final id = _newId();
  if (e is TgLine) return e.copyWith(id: id);
  if (e is TgRect) return e.copyWith(id: id);
  if (e is TgCircle) return e.copyWith(id: id);
  if (e is TgText) return e.copyWith(id: id);
  if (e is TgStamp) return e.copyWith(
    id: id,
    color: e.color, // Сохраняем цвет
  );
  return e;
}
}

class _TgSnapshot {
  _TgSnapshot({
    required this.elements,
    required this.selectedIds,
    required this.tool,
    required this.fieldEditMode,
    required this.gridEnabled,
    required this.gridStep,
    required this.snapRotationEnabled,
    required this.snapRotationDegrees,
    required this.activeStampAsset,
    required this.viewport,
  });

  final List<TgElement> elements;
  final Set<String> selectedIds;

  final TgTool tool;
  final bool fieldEditMode;

  final bool gridEnabled;
  final double gridStep;

  final bool snapRotationEnabled;
  final double snapRotationDegrees;

  final String? activeStampAsset;

  final Matrix4 viewport;
}