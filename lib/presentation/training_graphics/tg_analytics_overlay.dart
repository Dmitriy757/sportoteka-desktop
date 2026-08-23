import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:sportoteka/presentation/training_graphics/tg_models.dart';

/// Lightweight Training Graphics editor adapted for Tracker analytics.
///
/// The overlay intentionally has no viewport/camera of its own. Coordinates are
/// stored in Training Graphics' logical football field space (1050 x 680), so
/// Tracker's existing 2D/3D transform can wrap this widget without rebuilding
/// GPS data or fighting a second pan/zoom system.
enum TgAnalyticsTool {
  select,
  freeDraw,
  arrow,
  circle,
  zone,
  text,
  note,
  player,
  ball,
  chip,
  cone,
  dummy,
  goal,
  stamp,
}

/// Объект из общей библиотеки Training Graphics.
///
/// В [TgStamp] сохраняются те же поля, что и в основном редакторе:
/// asset, pos, size, rotation, opacity, color, layer, name и createdAt.
class TgAnalyticsObjectSpec {
  const TgAnalyticsObjectSpec({
    required this.asset,
    required this.name,
    required this.category,
    required this.size,
    this.color,
    this.subtitle = '',
  });

  final String asset;
  final String name;
  final String category;
  final double size;
  final Color? color;
  final String subtitle;
}

const List<String> kTgAnalyticsArchiveStampAssets = <String>[
  'assets/training/stamps/player_m/run.png',
  'assets/training/stamps/player_m/pass.png',
  'assets/training/stamps/player_m/stand.png',
  'assets/training/stamps/player_m/jump.png',
  'assets/training/stamps/player_m/goalkeeper.png',
  'assets/training/stamps/player_f/run.png',
  'assets/training/stamps/player_f/pass.png',
  'assets/training/stamps/player_f/stand.png',
  'assets/training/stamps/player_f/jump.png',
  'assets/training/stamps/player_f/goalkeeper.png',
  'assets/training/stamps/coach/male.png',
  'assets/training/stamps/coach/female.png',
  'assets/training/stamps/vorota1/back.png',
  'assets/training/stamps/vorota1/front.png',
  'assets/training/stamps/vorota1/left.png',
  'assets/training/stamps/vorota1/right.png',
  'assets/training/stamps/props/cap.svg',
  'assets/training/stamps/props/cone.svg',
  'assets/training/stamps/props/dummy.svg',
  'assets/training/stamps/props/flag_feet.svg',
  'assets/training/stamps/props/flag.svg',
  'assets/training/stamps/props/front.svg',
  'assets/training/stamps/props/ladder.svg',
  'assets/training/stamps/props/landscape.png',
  'assets/training/stamps/props/neutral.png',
  'assets/training/stamps/props/pole.svg',
  'assets/training/stamps/props/ring.svg',
  'assets/training/stamps/run_svg/front_left.svg',
  'assets/training/stamps/run_svg/front_angle_left.svg',
  'assets/training/stamps/run_svg/front_angle_right.svg',
  'assets/training/stamps/run_svg/side_left.svg',
  'assets/training/stamps/run_svg/side_right.svg',
  'assets/training/stamps/run_svg/back_left.svg',
  'assets/training/stamps/run_svg/back_right.svg',
  'assets/training/stamps/run_svg/back_angle_left.svg',
  'assets/training/stamps/run_svg/back_angle_right.svg',
  'assets/training/stamps/run_svg/frontal_links.svg',
  'assets/training/stamps/pass_svg/front_left.svg',
  'assets/training/stamps/pass_svg/front_angle_left.svg',
  'assets/training/stamps/pass_svg/front_angle_right.svg',
  'assets/training/stamps/pass_svg/side_left.svg',
  'assets/training/stamps/pass_svg/side_right.svg',
  'assets/training/stamps/pass_svg/back_left.svg',
  'assets/training/stamps/pass_svg/back_right.svg',
  'assets/training/stamps/pass_svg/back_angle_left.svg',
  'assets/training/stamps/pass_svg/back_angle_right.svg',
  'assets/training/stamps/pass_svg/front_right.svg',
  'assets/training/stamps/stand_svg/front_left.svg',
  'assets/training/stamps/stand_svg/front_angle_left.svg',
  'assets/training/stamps/stand_svg/front_angle_right.svg',
  'assets/training/stamps/stand_svg/side_left.svg',
  'assets/training/stamps/stand_svg/side_right.svg',
  'assets/training/stamps/stand_svg/back_left.svg',
  'assets/training/stamps/stand_svg/back_right.svg',
  'assets/training/stamps/stand_svg/back_angle_left.svg',
  'assets/training/stamps/stand_svg/back_angle_right.svg',
  'assets/training/stamps/stand_svg/front_right.svg',
  'assets/training/stamps/jump_svg/front_left.svg',
  'assets/training/stamps/jump_svg/front_right.svg',
  'assets/training/stamps/jump_svg/side_right.svg',
  'assets/training/stamps/jump_svg/side_left.svg',
  'assets/training/stamps/jump_svg/back_right.svg',
  'assets/training/stamps/jump_svg/back_left.svg',
  'assets/training/stamps/vrat_svg/front_left.svg',
  'assets/training/stamps/vrat_svg/front_angle_left.svg',
  'assets/training/stamps/vrat_svg/front_angle_right.svg',
  'assets/training/stamps/vrat_svg/side_left.svg',
  'assets/training/stamps/vrat_svg/side_right.svg',
  'assets/training/stamps/vrat_svg/back_left.svg',
  'assets/training/stamps/vrat_svg/back_right.svg',
  'assets/training/stamps/vrat_svg/back_angle_left.svg',
  'assets/training/stamps/vrat_svg/back_angle_right.svg',
  'assets/training/stamps/vrat_svg/front_right.svg',
];

bool _isTgBundleStamp(String asset) =>
    asset.toLowerCase().startsWith('assets/training/stamps/');

String _tgArchiveDirectionLabel(String file) {
  const labels = <String, String>{
    'front_left': 'спереди слева',
    'front_right': 'спереди справа',
    'front_angle_left': 'угол слева',
    'front_angle_right': 'угол справа',
    'side_left': 'слева',
    'side_right': 'справа',
    'back_left': 'сзади слева',
    'back_right': 'сзади справа',
    'back_angle_left': 'задний угол слева',
    'back_angle_right': 'задний угол справа',
    'frontal_links': 'фронтально',
  };
  return labels[file] ?? file.replaceAll('_', ' ');
}

TgAnalyticsObjectSpec _tgArchiveObjectSpec(String asset) {
  final lower = asset.toLowerCase();
  final file = lower.split('/').last.split('.').first;
  if (lower.contains('/vorota1/')) {
    return TgAnalyticsObjectSpec(
      asset: asset,
      name: 'Ворота · ${_tgArchiveDirectionLabel(file)}',
      category: 'Ворота',
      size: 104,
    );
  }
  if (lower.contains('/props/')) {
    const names = <String, String>{
      'cap': 'Фишка',
      'cone': 'Конус',
      'dummy': 'Манекен',
      'flag_feet': 'Флаг на основании',
      'flag': 'Флаг',
      'front': 'Барьер',
      'ladder': 'Координационная лестница',
      'landscape': 'Горизонтальный маркер',
      'neutral': 'Нейтральный игрок',
      'pole': 'Стойка',
      'ring': 'Кольцо',
    };
    final name = names[file] ?? file;
    final size = file == 'ladder'
        ? 96.0
        : file == 'dummy'
            ? 68.0
            : file == 'pole' || file.startsWith('flag')
                ? 62.0
                : 48.0;
    return TgAnalyticsObjectSpec(
      asset: asset,
      name: name,
      category: 'Инвентарь',
      size: size,
    );
  }
  if (lower.contains('/coach/')) {
    return TgAnalyticsObjectSpec(
      asset: asset,
      name: lower.contains('/female.') ? 'Тренер · женщина' : 'Тренер · мужчина',
      category: 'Тренеры',
      size: 70,
    );
  }
  if (lower.contains('/player_m/') || lower.contains('/player_f/')) {
    final action = <String, String>{
          'run': 'бег',
          'pass': 'передача',
          'stand': 'позиция',
          'jump': 'прыжок',
          'goalkeeper': 'вратарь',
        }[file] ??
        file;
    return TgAnalyticsObjectSpec(
      asset: asset,
      name: '${lower.contains('/player_f/') ? 'Игрок · женщина' : 'Игрок · мужчина'} · $action',
      category: 'Игроки',
      size: 72,
    );
  }
  final category = lower.contains('/run_svg/')
      ? 'Бег'
      : lower.contains('/pass_svg/')
          ? 'Передача'
          : lower.contains('/jump_svg/')
              ? 'Прыжок'
              : lower.contains('/vrat_svg/')
                  ? 'Вратарь'
                  : 'Позиция';
  return TgAnalyticsObjectSpec(
    asset: asset,
    name: '$category · ${_tgArchiveDirectionLabel(file)}',
    category: category,
    size: 72,
  );
}

const List<Color> kTgAnalyticsPalette = <Color>[
  Color(0xFFE53935),
  Color(0xFFEF334D),
  Color(0xFFFF8A00),
  Color(0xFFF6C445),
  Color(0xFF0D7B42),
  Color(0xFF13A35F),
  Color(0xFF1976D2),
  Color(0xFF38BDF8),
  Color(0xFF7C3AED),
  Color(0xFFFFFFFF),
  Color(0xFF17201B),
];

const List<double> kTgAnalyticsStrokeOptions = <double>[3, 5, 8, 12, 16];

typedef TgAnalyticsMutationCallback = void Function(
  String sessionKey,
  List<Map<String, dynamic>> annotations,
);

enum _TgAnalyticsTransformMode { none, move, resize, rotate }

Offset _rotateAnalyticsPoint(Offset point, Offset center, double radians) {
  final local = point - center;
  final cosA = math.cos(radians);
  final sinA = math.sin(radians);
  return center + Offset(
    local.dx * cosA - local.dy * sinA,
    local.dx * sinA + local.dy * cosA,
  );
}

Offset _analyticsRotationHandle(
  Rect bounds,
  Size logicalSize, {
  double distance = 34,
}) =>
    Offset(
      bounds.center.dx.clamp(14.0, logicalSize.width - 14.0).toDouble(),
      math.max(14.0, bounds.top - distance),
    );

TgElement _scaleAnalyticsElement(
  TgElement element,
  double factor, {
  Offset? around,
}) {
  final center = around ?? element.bounds().center;
  final safe = factor.clamp(.12, 8.0).toDouble();
  Offset scalePoint(Offset point) => center + (point - center) * safe;

  if (element is TgLine) {
    return element.copyWith(a: scalePoint(element.a), b: scalePoint(element.b));
  }
  if (element is TgPolyline) {
    return element.copyWith(
      points: element.points.map(scalePoint).toList(growable: false),
    );
  }
  if (element is TgCircle) {
    return element.copyWith(
      position: scalePoint(element.position),
      radius: (element.radius * safe).clamp(8.0, 520.0).toDouble(),
    );
  }
  if (element is TgZone) {
    return element.copyWith(
      points: element.points.map(scalePoint).toList(growable: false),
    );
  }
  if (element is TgText) {
    return element.copyWith(
      position: scalePoint(element.position),
      size: (element.size * safe).clamp(8.0, 220.0).toDouble(),
    );
  }
  if (element is TgStamp) {
    return element.copyWith(
      pos: scalePoint(element.pos),
      size: (element.size * safe).clamp(18.0, 260.0).toDouble(),
    );
  }
  return element;
}

TgElement _rotateAnalyticsElement(
  TgElement element,
  double deltaRadians, {
  Offset? around,
}) {
  final center = around ?? element.bounds().center;
  Offset rotatePoint(Offset point) =>
      _rotateAnalyticsPoint(point, center, deltaRadians);

  if (element is TgLine) {
    return element.copyWith(a: rotatePoint(element.a), b: rotatePoint(element.b));
  }
  if (element is TgPolyline) {
    return element.copyWith(
      points: element.points.map(rotatePoint).toList(growable: false),
    );
  }
  if (element is TgCircle) {
    return element.copyWith(
      position: rotatePoint(element.position),
      rotation: element.rotation + deltaRadians,
    );
  }
  if (element is TgZone) {
    return element.copyWith(
      points: element.points.map(rotatePoint).toList(growable: false),
    );
  }
  if (element is TgText) {
    return element.copyWith(
      position: rotatePoint(element.position),
      rotation: element.rotation + deltaRadians,
    );
  }
  if (element is TgStamp) {
    return element.copyWith(
      pos: rotatePoint(element.pos),
      rotation: element.rotation + deltaRadians,
    );
  }
  return element;
}

class TgAnalyticsOverlayController extends ChangeNotifier {
  TgAnalyticsOverlayController({
    required String sessionKey,
    this.logicalSize = const Size(1050, 680),
    this.onMutation,
  }) : _sessionKey = sessionKey {
    _restoreSession();
  }

  static final Map<String, List<Map<String, dynamic>>> _sessionCache =
      <String, List<Map<String, dynamic>>>{};

  final Size logicalSize;
  final TgAnalyticsMutationCallback? onMutation;
  String _sessionKey;
  String get sessionKey => _sessionKey;

  final List<TgElement> _elements = <TgElement>[];
  List<TgElement> get elements => List<TgElement>.unmodifiable(_elements);

  TgElement? _preview;
  TgElement? get preview => _preview;

  TgAnalyticsTool _tool = TgAnalyticsTool.select;
  TgAnalyticsTool get tool => _tool;

  String? _selectedId;
  String? get selectedId => _selectedId;
  TgElement? get selectedElement {
    final id = _selectedId;
    if (id == null) return null;
    for (final element in _elements.reversed) {
      if (element.id == id) return element;
    }
    return null;
  }

  final List<List<Map<String, dynamic>>> _undo =
      <List<Map<String, dynamic>>>[];
  final List<List<Map<String, dynamic>>> _redo =
      <List<Map<String, dynamic>>>[];
  bool _mutationOpen = false;
  final ValueNotifier<int> _stampRevision = ValueNotifier<int>(0);
  ValueListenable<int> get stampListenable => _stampRevision;

  Color drawColor = const Color(0xFFE53935);
  double strokeWidth = 5.0;
  LineKind lineKind = LineKind.normal;
  String activeStampAsset = 'sportoteka://ball';
  String activeStampName = 'Мяч';
  double activeStampSize = 40;
  Color? activeStampColor = const Color(0xFF17201B);

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  bool get hasSelection => selectedElement != null;
  int get count => _elements.length;
  List<Map<String, dynamic>> exportJson() => _snapshot();

  void switchSession(String key) {
    if (key == _sessionKey) return;
    _persistSession(notifyMutation: false);
    _sessionKey = key;
    _elements.clear();
    _undo.clear();
    _redo.clear();
    _preview = null;
    _selectedId = null;
    _mutationOpen = false;
    _restoreSession();
    _touchStampLayer();
    notifyListeners();
  }

  void setTool(TgAnalyticsTool value) {
    if (_tool == value) return;
    _tool = value;
    _preview = null;
    if (value != TgAnalyticsTool.select) _selectedId = null;
    notifyListeners();
  }

  void setStampObject(TgAnalyticsObjectSpec spec) {
    activeStampAsset = spec.asset;
    activeStampName = spec.name;
    activeStampSize = spec.size;
    activeStampColor = spec.color;
    _tool = TgAnalyticsTool.stamp;
    _preview = null;
    _selectedId = null;
    notifyListeners();
  }

  void setDrawColor(Color value, {bool applyToSelection = true}) {
    if (drawColor.value != value.value) {
      drawColor = value;
    }
    if (applyToSelection) {
      _applyStyleToSelected(color: value);
    }
    notifyListeners();
  }

  void setStrokeWidth(double value, {bool applyToSelection = true}) {
    final clamped = value.clamp(1.0, 26.0).toDouble();
    if ((strokeWidth - clamped).abs() > 0.001) {
      strokeWidth = clamped;
    }
    if (applyToSelection) {
      _applyStyleToSelected(width: clamped);
    }
    notifyListeners();
  }

  void setLineKind(LineKind value, {bool applyToSelection = true}) {
    lineKind = value;
    if (applyToSelection) {
      final selected = selectedElement;
      if (selected is TgLine) {
        _pushUndo();
        replaceElement(selected.copyWith(kind: value), notify: false);
        _persistSession();
      } else if (selected is TgPolyline) {
        _pushUndo();
        replaceElement(selected.copyWith(kind: value), notify: false);
        _persistSession();
      }
    }
    notifyListeners();
  }

  void scaleSelected(double factor) {
    final selected = selectedElement;
    if (selected == null || selected.locked) return;
    _pushUndo();
    replaceElement(
      _scaleAnalyticsElement(selected, factor),
      notify: false,
    );
    _persistSession();
    notifyListeners();
  }

  void rotateSelected(double deltaRadians) {
    final selected = selectedElement;
    if (selected == null || selected.locked) return;
    _pushUndo();
    replaceElement(
      _rotateAnalyticsElement(selected, deltaRadians),
      notify: false,
    );
    _persistSession();
    notifyListeners();
  }

  // Совместимость со старыми вызовами панели объектов.
  void scaleSelectedStamp(double factor) => scaleSelected(factor);
  void rotateSelectedStamp(double deltaRadians) =>
      rotateSelected(deltaRadians);

  void setPreview(TgElement? element) {
    _preview = element;
    notifyListeners();
  }

  void _applyStyleToSelected({Color? color, double? width}) {
    final selected = selectedElement;
    if (selected == null) return;
    final before = selected.toJson().toString();
    final updated = _styledElement(selected, color: color, width: width);
    if (identical(updated, selected) || updated.toJson().toString() == before) {
      return;
    }
    final index = _elements.indexWhere((item) => item.id == selected.id);
    if (index < 0) return;
    _pushUndo();
    _elements[index] = updated;
    if (updated is TgStamp) _touchStampLayer();
    _persistSession();
  }

  TgElement _styledElement(TgElement element, {Color? color, double? width}) {
    if (element is TgLine) {
      return element.copyWith(
        color: color ?? element.color,
        width: width ?? element.width,
      );
    }
    if (element is TgPolyline) {
      return element.copyWith(
        color: color ?? element.color,
        width: width ?? element.width,
      );
    }
    if (element is TgCircle) {
      final nextColor = color ?? element.border;
      return element.copyWith(
        border: nextColor,
        fill: nextColor.withOpacity(.10),
        borderWidth: width ?? element.borderWidth,
      );
    }
    if (element is TgZone) {
      final nextColor = color ?? element.border;
      return element.copyWith(
        border: nextColor,
        fill: nextColor,
        borderWidth: width ?? element.borderWidth,
      );
    }
    if (element is TgText) {
      return element.copyWith(color: color ?? element.color);
    }
    if (element is TgStamp) {
      return element.copyWith(
        color: color ?? element.color,
      );
    }
    return element;
  }

  void selectAt(Offset scene, {double tolerance = 16}) {
    String? hit;
    for (final element in _elements.reversed) {
      if (element.hidden || element.locked) continue;
      if (element.hitTest(scene, tolerance: tolerance)) {
        hit = element.id;
        break;
      }
    }
    if (_selectedId == hit) return;
    _selectedId = hit;
    _syncDefaultsFromSelection();
    notifyListeners();
  }

  void clearSelection() {
    if (_selectedId == null) return;
    _selectedId = null;
    notifyListeners();
  }

  void addElement(TgElement element) {
    _pushUndo();
    _elements.add(element);
    _preview = null;
    _selectedId = element.id;
    _syncDefaultsFromSelection();
    if (element is TgStamp) _touchStampLayer();
    _persistSession();
    notifyListeners();
  }

  void beginMutation() {
    if (_mutationOpen) return;
    _pushUndo();
    _mutationOpen = true;
  }

  void replaceElement(TgElement element, {bool notify = true}) {
    final index = _elements.indexWhere((item) => item.id == element.id);
    if (index < 0) return;
    final previous = _elements[index];
    _elements[index] = element;
    if (previous is TgStamp || element is TgStamp) _touchStampLayer();
    if (notify) notifyListeners();
  }

  void endMutation() {
    if (!_mutationOpen) return;
    _mutationOpen = false;
    _syncDefaultsFromSelection();
    _persistSession();
    notifyListeners();
  }

  void deleteSelected() {
    final id = _selectedId;
    if (id == null) return;
    final removingStamp = selectedElement is TgStamp;
    _pushUndo();
    _elements.removeWhere((element) => element.id == id);
    _selectedId = null;
    if (removingStamp) _touchStampLayer();
    _persistSession();
    notifyListeners();
  }

  void clearAll() {
    if (_elements.isEmpty) return;
    final hadStamps = _elements.any((element) => element is TgStamp);
    _pushUndo();
    _elements.clear();
    _selectedId = null;
    _preview = null;
    if (hadStamps) _touchStampLayer();
    _persistSession();
    notifyListeners();
  }

  void undo() {
    if (_undo.isEmpty) return;
    _redo.add(_snapshot());
    _restoreSnapshot(_undo.removeLast());
    _mutationOpen = false;
    _touchStampLayer();
    _persistSession();
    notifyListeners();
  }

  void redo() {
    if (_redo.isEmpty) return;
    _undo.add(_snapshot());
    _restoreSnapshot(_redo.removeLast());
    _mutationOpen = false;
    _syncDefaultsFromSelection();
    _touchStampLayer();
    _persistSession();
    notifyListeners();
  }

  void _syncDefaultsFromSelection() {
    final element = selectedElement;
    if (element is TgLine) {
      drawColor = element.color;
      strokeWidth = element.width;
      lineKind = element.kind;
    } else if (element is TgPolyline) {
      drawColor = element.color;
      strokeWidth = element.width;
      lineKind = element.kind;
    } else if (element is TgCircle) {
      drawColor = element.border;
      strokeWidth = element.borderWidth;
    } else if (element is TgZone) {
      drawColor = element.border;
      strokeWidth = element.borderWidth;
    } else if (element is TgText) {
      drawColor = element.color;
    } else if (element is TgStamp) {
      drawColor = element.color ?? drawColor;
    }
  }

  void _pushUndo() {
    _undo.add(_snapshot());
    if (_undo.length > 60) _undo.removeAt(0);
    _redo.clear();
  }

  List<Map<String, dynamic>> _snapshot() => _elements
      .map((element) => Map<String, dynamic>.from(element.toJson()))
      .toList(growable: false);

  void _restoreSnapshot(List<Map<String, dynamic>> json) {
    _elements
      ..clear()
      ..addAll(json.map((item) => TgElement.fromJson(item)));
    _selectedId = null;
    _preview = null;
  }

  void replaceFromJson(
    List<Map<String, dynamic>> annotations, {
    bool clearHistory = true,
  }) {
    _restoreSnapshot(
      annotations
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false),
    );
    if (clearHistory) {
      _undo.clear();
      _redo.clear();
      _mutationOpen = false;
    }
    _sessionCache[_sessionKey] = _snapshot();
    _syncDefaultsFromSelection();
    _touchStampLayer();
    notifyListeners();
  }

  void _persistSession({bool notifyMutation = true}) {
    final snapshot = _snapshot();
    _sessionCache[_sessionKey] = snapshot;
    if (notifyMutation) {
      onMutation?.call(_sessionKey, snapshot);
    }
  }

  void _restoreSession() {
    final cached = _sessionCache[_sessionKey];
    if (cached == null) return;
    _restoreSnapshot(cached);
  }

  void _touchStampLayer() {
    _stampRevision.value = _stampRevision.value + 1;
  }

  @override
  void dispose() {
    _stampRevision.dispose();
    super.dispose();
  }

  String makeId(String prefix) =>
      '${prefix}_${DateTime.now().microsecondsSinceEpoch}_${_elements.length}';
}

class TgAnalyticsOverlay extends StatefulWidget {
  const TgAnalyticsOverlay({
    super.key,
    required this.controller,
    required this.enabled,
    required this.child,
    this.cursorElapsedMs = 0,
  });

  final TgAnalyticsOverlayController controller;
  final bool enabled;
  final Widget child;
  final int cursorElapsedMs;

  @override
  State<TgAnalyticsOverlay> createState() => _TgAnalyticsOverlayState();
}

class _TgAnalyticsOverlayState extends State<TgAnalyticsOverlay> {
  Offset? _startScene;
  TgElement? _dragBase;
  _TgAnalyticsTransformMode _transformMode =
      _TgAnalyticsTransformMode.none;
  Offset? _transformCenter;
  double _transformStartDistance = 1;
  double _transformStartAngle = 0;
  Offset? _pendingPanScene;
  bool _panFrameScheduled = false;
  double _freeDrawMinStep = 3;
  final List<Offset> _freePoints = <Offset>[];

  Offset _toScene(Offset local, Size size) {
    final logical = widget.controller.logicalSize;
    return Offset(
      (local.dx / math.max(1.0, size.width) * logical.width)
          .clamp(0.0, logical.width)
          .toDouble(),
      (local.dy / math.max(1.0, size.height) * logical.height)
          .clamp(0.0, logical.height)
          .toDouble(),
    );
  }

  Offset _sceneDelta(Offset localDelta, Size size) {
    final logical = widget.controller.logicalSize;
    return Offset(
      localDelta.dx / math.max(1.0, size.width) * logical.width,
      localDelta.dy / math.max(1.0, size.height) * logical.height,
    );
  }

  double _sceneUnitsPerPixel(Size size) {
    final logical = widget.controller.logicalSize;
    return math.max(
      logical.width / math.max(1.0, size.width),
      logical.height / math.max(1.0, size.height),
    );
  }

  double _handleHitRadius(Size size) {
    return (14.0 * _sceneUnitsPerPixel(size))
        .clamp(14.0, 42.0)
        .toDouble();
  }

  _TgAnalyticsTransformMode _hitTransformHandle(
    TgElement? selected,
    Offset scene,
    Size size,
  ) {
    if (selected == null || selected.locked) {
      return _TgAnalyticsTransformMode.none;
    }
    final uiScale = _sceneUnitsPerPixel(size).clamp(1.0, 3.0).toDouble();
    final bounds = selected.bounds().inflate(9 * uiScale);
    final tolerance = _handleHitRadius(size);
    final rotate = _analyticsRotationHandle(
      bounds,
      widget.controller.logicalSize,
      distance: 34 * uiScale,
    );
    if ((scene - rotate).distance <= tolerance) {
      return _TgAnalyticsTransformMode.rotate;
    }
    for (final corner in <Offset>[
      bounds.topLeft,
      bounds.topRight,
      bounds.bottomLeft,
      bounds.bottomRight,
    ]) {
      if ((scene - corner).distance <= tolerance) {
        return _TgAnalyticsTransformMode.resize;
      }
    }
    return _TgAnalyticsTransformMode.none;
  }

  void _onTapUp(TapUpDetails details, Size size) {
    if (!widget.enabled) return;
    final scene = _toScene(details.localPosition, size);
    switch (widget.controller.tool) {
      case TgAnalyticsTool.select:
        widget.controller.selectAt(scene);
        break;
      case TgAnalyticsTool.text:
        _requestText(scene, note: false);
        break;
      case TgAnalyticsTool.note:
        _requestText(scene, note: true);
        break;
      case TgAnalyticsTool.player:
        _addStamp(
          scene,
          'sportoteka://player-avatar?name=Игрок&number=7',
          name: 'Игрок',
          size: 70,
        );
        break;
      case TgAnalyticsTool.ball:
        _addStamp(scene, 'sportoteka://ball', name: 'Мяч', size: 40);
        break;
      case TgAnalyticsTool.chip:
        _addStamp(scene, 'sportoteka://chip', name: 'Фишка', size: 34);
        break;
      case TgAnalyticsTool.cone:
        _addStamp(scene, 'sportoteka://cone', name: 'Конус', size: 44);
        break;
      case TgAnalyticsTool.dummy:
        _addStamp(scene, 'sportoteka://dummy', name: 'Манекен', size: 66);
        break;
      case TgAnalyticsTool.goal:
        _addStamp(scene, 'sportoteka://goal', name: 'Ворота', size: 94);
        break;
      case TgAnalyticsTool.stamp:
        _addStamp(
          scene,
          widget.controller.activeStampAsset,
          name: widget.controller.activeStampName,
          size: widget.controller.activeStampSize,
          color: widget.controller.activeStampColor,
        );
        break;
      default:
        break;
    }
  }

  void _addStamp(
    Offset scene,
    String asset, {
    String? name,
    double? size,
    Color? color,
  }) {
    final lower = asset.toLowerCase();
    final bundleStamp = _isTgBundleStamp(asset);
    Color resolvedColor = color ?? widget.controller.drawColor;
    if (color == null && lower.contains('ball')) {
      resolvedColor = const Color(0xFF17201B);
    }
    if (color == null && lower.contains('cone')) {
      resolvedColor = const Color(0xFFFF8A00);
    }
    if (color == null && lower.contains('chip')) {
      resolvedColor = const Color(0xFFF6C445);
    }
    if (color == null && lower.contains('goal')) {
      resolvedColor = const Color(0xFFCBD5E1);
    }
    final decoratedAsset = lower.startsWith('sportoteka://player-avatar')
        ? _withPlayerRing(asset, resolvedColor)
        : asset;
    widget.controller.addElement(TgStamp(
      id: widget.controller.makeId('stamp'),
      asset: decoratedAsset,
      pos: scene,
      size: size ?? _defaultStampSize(asset),
      rotation: 0,
      opacity: bundleStamp ? .8 : 1,
      color: bundleStamp && color == null ? null : resolvedColor,
      layer: 'analytics',
      name: name ?? 'Объект Training Graphics',
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  String _withPlayerRing(String asset, Color color) {
    final uri = Uri.tryParse(asset);
    if (uri == null) return asset;
    final query = Map<String, String>.from(uri.queryParameters);
    query.putIfAbsent('ring', () => color.value.toString());
    return uri.replace(queryParameters: query).toString();
  }

  double _defaultStampSize(String asset) {
    final a = asset.toLowerCase();
    if (a.contains('goal')) return 94;
    if (a.contains('dummy')) return 66;
    if (a.contains('player-avatar') || a.endsWith('player')) return 70;
    if (a.contains('ball')) return 40;
    if (a.contains('chip')) return 34;
    if (a.contains('cone')) return 44;
    return 52;
  }

  Future<void> _requestText(Offset scene, {required bool note}) async {
    final result = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: note ? 'Закрыть заметку' : 'Закрыть ввод текста',
      barrierColor: const Color(0x520F1712),
      transitionDuration: const Duration(milliseconds: 220),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(.08, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
      pageBuilder: (dialogContext, animation, secondaryAnimation) =>
          _TgAnalyticsTextEntryPanel(
        note: note,
        elapsed: _formatElapsed(widget.cursorElapsedMs),
        onCancel: () => Navigator.of(dialogContext).pop(),
        onSubmit: (value) => Navigator.of(dialogContext).pop(value.trim()),
      ),
    );
    if (!mounted || result == null || result.trim().isEmpty) return;

    final elapsed = _formatElapsed(widget.cursorElapsedMs);
    final text = note ? 'ЗАМЕТКА · $elapsed\n${result.trim()}' : result.trim();
    widget.controller.addElement(TgText(
      id: widget.controller.makeId(note ? 'note' : 'text'),
      position: scene,
      text: text,
      size: note ? 22 : 25,
      color: note ? const Color(0xFF17201B) : widget.controller.drawColor,
      opacity: 1,
      rotation: 0,
      fontFamily: null,
      weight: FontWeight.w800,
      alignment: TextAlign.center,
      style: TgTextStyle.normal,
      layer: 'analytics',
      name: note ? 'analytics_note:${widget.cursorElapsedMs}' : 'analytics_text',
      createdAt: DateTime.now().millisecondsSinceEpoch,
    ));
  }

  String _formatElapsed(int ms) {
    final total = math.max(0, ms ~/ 1000);
    final min = total ~/ 60;
    final sec = total % 60;
    return '$min:${sec.toString().padLeft(2, '0')}';
  }

  void _onPanStart(DragStartDetails details, Size size) {
    if (!widget.enabled) return;
    final scene = _toScene(details.localPosition, size);
    _startScene = scene;
    _freePoints.clear();
    _dragBase = null;
    _transformMode = _TgAnalyticsTransformMode.none;
    _transformCenter = null;
    _pendingPanScene = null;
    _freeDrawMinStep =
        math.max(3.0, _sceneUnitsPerPixel(size) * 2.4).toDouble();

    switch (widget.controller.tool) {
      case TgAnalyticsTool.select:
        final selectedBefore = widget.controller.selectedElement;
        final handleMode = _hitTransformHandle(selectedBefore, scene, size);
        if (handleMode != _TgAnalyticsTransformMode.none) {
          _dragBase = selectedBefore;
          _transformMode = handleMode;
        } else {
          widget.controller.selectAt(
            scene,
            tolerance: _handleHitRadius(size) * .55,
          );
          _dragBase = widget.controller.selectedElement;
          if (_dragBase != null) {
            _transformMode = _TgAnalyticsTransformMode.move;
          }
        }
        final base = _dragBase;
        if (base != null) {
          final center = base.bounds().center;
          _transformCenter = center;
          _transformStartDistance =
              math.max(1.0, (scene - center).distance);
          _transformStartAngle =
              math.atan2(scene.dy - center.dy, scene.dx - center.dx);
          widget.controller.beginMutation();
        }
        break;
      case TgAnalyticsTool.freeDraw:
        _freePoints.add(scene);
        break;
      case TgAnalyticsTool.arrow:
        widget.controller.setPreview(TgLine(
          id: 'preview_arrow',
          a: scene,
          b: scene,
          color: widget.controller.drawColor,
          width: widget.controller.strokeWidth,
          kind: widget.controller.lineKind,
          end: LineEnd.arrow,
          arrowSize: 22,
          layer: 'analytics',
        ));
        break;
      case TgAnalyticsTool.circle:
        widget.controller.setPreview(TgCircle(
          id: 'preview_circle',
          position: scene,
          radius: 1,
          rotation: 0,
          fill: widget.controller.drawColor.withOpacity(.08),
          opacity: 1,
          border: widget.controller.drawColor,
          borderWidth: widget.controller.strokeWidth,
          borderKind: BorderKind.solid,
          layer: 'analytics',
        ));
        break;
      case TgAnalyticsTool.zone:
        widget.controller.setPreview(_zoneFromDrag(scene, scene));
        break;
      default:
        break;
    }
  }

  void _onPanUpdate(DragUpdateDetails details, Size size) {
    if (!widget.enabled || _startScene == null) return;
    _pendingPanScene = _toScene(details.localPosition, size);
    if (_panFrameScheduled) return;
    _panFrameScheduled = true;
    WidgetsBinding.instance.scheduleFrameCallback((_) {
      _panFrameScheduled = false;
      if (!mounted) {
        _pendingPanScene = null;
        return;
      }
      _flushPendingPanScene();
    });
  }

  void _flushPendingPanScene() {
    final scene = _pendingPanScene;
    _pendingPanScene = null;
    if (scene == null || !widget.enabled || _startScene == null) return;
    _applyPanScene(scene);
  }

  void _applyPanScene(Offset scene) {
    final start = _startScene!;

    switch (widget.controller.tool) {
      case TgAnalyticsTool.select:
        final base = _dragBase;
        if (base == null) return;
        final center = _transformCenter ?? base.bounds().center;
        switch (_transformMode) {
          case _TgAnalyticsTransformMode.move:
            widget.controller.replaceElement(_translate(base, scene - start));
            break;
          case _TgAnalyticsTransformMode.resize:
            final currentDistance = math.max(1.0, (scene - center).distance);
            final factor = currentDistance / _transformStartDistance;
            widget.controller.replaceElement(
              _scaleAnalyticsElement(base, factor, around: center),
            );
            break;
          case _TgAnalyticsTransformMode.rotate:
            final currentAngle =
                math.atan2(scene.dy - center.dy, scene.dx - center.dx);
            widget.controller.replaceElement(
              _rotateAnalyticsElement(
                base,
                currentAngle - _transformStartAngle,
                around: center,
              ),
            );
            break;
          case _TgAnalyticsTransformMode.none:
            break;
        }
        break;
      case TgAnalyticsTool.freeDraw:
        if (_freePoints.isNotEmpty &&
            (_freePoints.last - scene).distance < _freeDrawMinStep) return;
        _freePoints.add(scene);
        widget.controller.setPreview(TgPolyline(
          id: 'preview_free',
          points: List<Offset>.from(_freePoints),
          color: widget.controller.drawColor,
          width: widget.controller.strokeWidth,
          // Сложный dashed/wavy path строим один раз после отпускания. Во
          // время жеста показываем дешёвую непрерывную линию без визуального
          // отставания пера.
          kind: LineKind.normal,
          end: LineEnd.none,
          arrowSize: 18,
          layer: 'analytics',
        ));
        break;
      case TgAnalyticsTool.arrow:
        widget.controller.setPreview(TgLine(
          id: 'preview_arrow',
          a: start,
          b: scene,
          color: widget.controller.drawColor,
          width: widget.controller.strokeWidth,
          kind: widget.controller.lineKind,
          end: LineEnd.arrow,
          arrowSize: 22,
          layer: 'analytics',
        ));
        break;
      case TgAnalyticsTool.circle:
        widget.controller.setPreview(TgCircle(
          id: 'preview_circle',
          position: start,
          radius: math.max(2.0, (scene - start).distance),
          rotation: 0,
          fill: widget.controller.drawColor.withOpacity(.08),
          opacity: 1,
          border: widget.controller.drawColor,
          borderWidth: widget.controller.strokeWidth,
          borderKind: BorderKind.solid,
          layer: 'analytics',
        ));
        break;
      case TgAnalyticsTool.zone:
        widget.controller.setPreview(_zoneFromDrag(start, scene));
        break;
      default:
        break;
    }
  }

  void _onPanEnd(DragEndDetails details, Size size) {
    if (!widget.enabled) return;
    _flushPendingPanScene();
    switch (widget.controller.tool) {
      case TgAnalyticsTool.select:
        widget.controller.endMutation();
        break;
      case TgAnalyticsTool.freeDraw:
        if (_freePoints.length >= 2) {
          widget.controller.addElement(TgPolyline(
            id: widget.controller.makeId('free'),
            points: List<Offset>.from(_freePoints),
            color: widget.controller.drawColor,
            width: widget.controller.strokeWidth,
            kind: widget.controller.lineKind,
            end: LineEnd.none,
            arrowSize: 18,
            layer: 'analytics',
            name: 'analytics_free',
            createdAt: DateTime.now().millisecondsSinceEpoch,
          ));
        } else {
          widget.controller.setPreview(null);
        }
        break;
      case TgAnalyticsTool.arrow:
      case TgAnalyticsTool.circle:
      case TgAnalyticsTool.zone:
        final preview = widget.controller.preview;
        if (preview != null && _isLargeEnough(preview)) {
          widget.controller.addElement(_withFreshId(preview));
        } else {
          widget.controller.setPreview(null);
        }
        break;
      default:
        widget.controller.setPreview(null);
        break;
    }
    _startScene = null;
    _dragBase = null;
    _transformMode = _TgAnalyticsTransformMode.none;
    _transformCenter = null;
    _pendingPanScene = null;
    _freePoints.clear();
  }

  TgZone _zoneFromDrag(Offset a, Offset b) {
    final left = math.min(a.dx, b.dx);
    final right = math.max(a.dx, b.dx);
    final top = math.min(a.dy, b.dy);
    final bottom = math.max(a.dy, b.dy);
    return TgZone(
      id: 'preview_zone',
      points: <Offset>[
        Offset(left, top),
        Offset(right, top),
        Offset(right, bottom),
        Offset(left, bottom),
      ],
      fill: widget.controller.drawColor,
      opacity: .16,
      border: widget.controller.drawColor,
      borderWidth: widget.controller.strokeWidth * .75,
      borderKind: BorderKind.solid,
      layer: 'analytics',
    );
  }

  bool _isLargeEnough(TgElement element) {
    final bounds = element.bounds();
    return bounds.width >= 8 || bounds.height >= 8;
  }

  TgElement _withFreshId(TgElement element) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (element is TgLine) {
      return element.copyWith(
        id: widget.controller.makeId('arrow'),
        name: 'analytics_arrow',
        createdAt: now,
      );
    }
    if (element is TgCircle) {
      return element.copyWith(
        id: widget.controller.makeId('circle'),
        name: 'analytics_circle',
        createdAt: now,
      );
    }
    if (element is TgZone) {
      return TgZone(
        id: widget.controller.makeId('zone'),
        points: List<Offset>.from(element.points),
        fill: element.fill,
        opacity: element.opacity,
        border: element.border,
        borderWidth: element.borderWidth,
        borderKind: element.borderKind,
        layer: 'analytics',
        name: 'analytics_zone',
        createdAt: now,
      );
    }
    return element;
  }

  TgElement _translate(TgElement element, Offset delta) {
    if (element is TgLine) {
      return element.copyWith(a: element.a + delta, b: element.b + delta);
    }
    if (element is TgPolyline) {
      return element.copyWith(
        points: element.points.map((point) => point + delta).toList(),
      );
    }
    if (element is TgCircle) {
      return element.copyWith(position: element.position + delta);
    }
    if (element is TgZone) {
      return element.copyWith(
        points: element.points.map((point) => point + delta).toList(),
      );
    }
    if (element is TgText) {
      return element.copyWith(position: element.position + delta);
    }
    if (element is TgStamp) {
      return element.copyWith(pos: element.pos + delta);
    }
    return element;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final size = Size(
        math.max(1.0, constraints.maxWidth),
        math.max(1.0, constraints.maxHeight),
      );
      final tapOnly = const <TgAnalyticsTool>{
        TgAnalyticsTool.text,
        TgAnalyticsTool.note,
        TgAnalyticsTool.player,
        TgAnalyticsTool.ball,
        TgAnalyticsTool.chip,
        TgAnalyticsTool.cone,
        TgAnalyticsTool.dummy,
        TgAnalyticsTool.goal,
        TgAnalyticsTool.stamp,
      }.contains(widget.controller.tool);
      final paint = RepaintBoundary(
        child: CustomPaint(
          painter: _TgAnalyticsPainter(
            controller: widget.controller,
            logicalSize: widget.controller.logicalSize,
          ),
          child: const SizedBox.expand(),
        ),
      );

      return Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.hardEdge,
        children: [
          // GPS route/players stay in their own raster layer while the pencil
          // repaints. Controller notifications now repaint only CustomPaint.
          RepaintBoundary(child: widget.child),
          Positioned.fill(
            child: IgnorePointer(
              child: _TgAnalyticsAssetStampLayer(
                controller: widget.controller,
              ),
            ),
          ),
          if (widget.enabled)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (details) => _onTapUp(details, size),
              // Для текста, заметок и объектов оставляем только TapRecognizer.
              // Иначе PanRecognizer выигрывает arena даже при небольшом
              // движении мыши и окно ввода визуально "не срабатывает".
              onPanStart:
                  tapOnly ? null : (details) => _onPanStart(details, size),
              onPanUpdate:
                  tapOnly ? null : (details) => _onPanUpdate(details, size),
              onPanEnd: tapOnly ? null : (details) => _onPanEnd(details, size),
              child: paint,
            )
          else
            IgnorePointer(child: paint),
        ],
      );
    });
  }
}

class _TgAnalyticsTextEntryPanel extends StatefulWidget {
  const _TgAnalyticsTextEntryPanel({
    required this.note,
    required this.elapsed,
    required this.onCancel,
    required this.onSubmit,
  });

  final bool note;
  final String elapsed;
  final VoidCallback onCancel;
  final ValueChanged<String> onSubmit;

  @override
  State<_TgAnalyticsTextEntryPanel> createState() =>
      _TgAnalyticsTextEntryPanelState();
}

class _TgAnalyticsTextEntryPanelState
    extends State<_TgAnalyticsTextEntryPanel> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final width =
        math.min(460.0, math.max(280.0, media.size.width - 24)).toDouble();
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Align(
          alignment: Alignment.centerRight,
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            padding: EdgeInsets.fromLTRB(
              12,
              12,
              12,
              math.max(12.0, media.viewInsets.bottom + 12).toDouble(),
            ),
            child: Container(
              width: width,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFE5E7EB)),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x260F1712),
                    blurRadius: 30,
                    spreadRadius: -8,
                    offset: Offset(0, 14),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF6EE),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          widget.note
                              ? Icons.sticky_note_2_outlined
                              : Icons.text_fields_rounded,
                          color: const Color(0xFF0D7B42),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              widget.note
                                  ? 'Заметка эпизода'
                                  : 'Текст на поле',
                              style: const TextStyle(
                                color: Color(0xFF17201B),
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.note
                                  ? 'Стоп-кадр ${widget.elapsed} · заметка сохранится вместе с разбором'
                                  : 'Подпись можно перемещать, вращать и менять по размеру',
                              style: const TextStyle(
                                color: Color(0xFF718078),
                                fontSize: 10.5,
                                height: 1.3,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Закрыть',
                        onPressed: widget.onCancel,
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Color(0xFF55635B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _controller,
                    autofocus: true,
                    enableInteractiveSelection: true,
                    textCapitalization: TextCapitalization.sentences,
                    keyboardType: widget.note
                        ? TextInputType.multiline
                        : TextInputType.text,
                    minLines: widget.note ? 4 : 1,
                    maxLines: widget.note ? 7 : 3,
                    textInputAction:
                        widget.note
                            ? TextInputAction.newline
                            : TextInputAction.done,
                    style: const TextStyle(
                      color: Color(0xFF17201B),
                      fontSize: 14,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: InputDecoration(
                      hintText: widget.note
                          ? 'Что важно в этом эпизоде?'
                          : 'Введите подпись',
                      hintStyle: const TextStyle(
                        color: Color(0xFF9AA69F),
                        fontWeight: FontWeight.w600,
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF6F8F7),
                      contentPadding: const EdgeInsets.all(15),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: Color(0xFF80C99B),
                          width: 1.5,
                        ),
                      ),
                      suffixIcon: IconButton(
                        tooltip: 'Вставить из буфера',
                        onPressed: () async {
                          final data =
                              await Clipboard.getData(Clipboard.kTextPlain);
                          final clipboardText = data?.text ?? '';
                          if (clipboardText.isEmpty) return;
                          final selection = _controller.selection;
                          final start = selection.isValid
                              ? selection.start
                                  .clamp(0, _controller.text.length)
                                  .toInt()
                              : _controller.text.length;
                          final end = selection.isValid
                              ? selection.end
                                  .clamp(0, _controller.text.length)
                                  .toInt()
                              : _controller.text.length;
                          final next = _controller.text.replaceRange(
                            math.min(start, end),
                            math.max(start, end),
                            clipboardText,
                          );
                          final cursor = math.min(start, end) +
                              clipboardText.length;
                          _controller.value = TextEditingValue(
                            text: next,
                            selection: TextSelection.collapsed(offset: cursor),
                          );
                        },
                        icon: const Icon(
                          Icons.content_paste_rounded,
                          size: 19,
                          color: Color(0xFF0D7B42),
                        ),
                      ),
                    ),
                    onSubmitted: widget.note
                        ? null
                        : (_) => widget.onSubmit(_controller.text),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      TextButton(
                        onPressed: widget.onCancel,
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF59675F),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 13,
                          ),
                        ),
                        child: const Text(
                          'Отмена',
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: () => widget.onSubmit(_controller.text),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0D7B42),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 13,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                        ),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text(
                          'Добавить',
                          style: TextStyle(fontWeight: FontWeight.w900),
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

class _TgAnalyticsAssetStampLayer extends StatelessWidget {
  const _TgAnalyticsAssetStampLayer({required this.controller});

  final TgAnalyticsOverlayController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: controller.stampListenable,
      builder: (context, revision, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final logical = controller.logicalSize;
            final sx = constraints.maxWidth / math.max(1.0, logical.width);
            final sy = constraints.maxHeight / math.max(1.0, logical.height);
            final stamps = controller.elements
                .whereType<TgStamp>()
                .where((item) => !item.hidden && _isTgBundleStamp(item.asset));
            return Stack(
              clipBehavior: Clip.hardEdge,
              children: <Widget>[
                for (final stamp in stamps)
                  Positioned(
                    left: (stamp.pos.dx - stamp.size / 2) * sx,
                    top: (stamp.pos.dy - stamp.size / 2) * sy,
                    width: stamp.size * sx,
                    height: stamp.size * sy,
                    child: RepaintBoundary(
                      key: ValueKey<String>(stamp.id),
                      child: Transform.rotate(
                        angle: stamp.rotation,
                        child: Opacity(
                          opacity: stamp.opacity.clamp(0.0, 1.0).toDouble(),
                          child: _TgAnalyticsAssetStamp(
                            asset: stamp.asset,
                            color: stamp.color,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _TgAnalyticsAssetStamp extends StatelessWidget {
  const _TgAnalyticsAssetStamp({required this.asset, this.color});

  final String asset;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (asset.toLowerCase().endsWith('.svg')) {
      return SvgPicture.asset(
        asset,
        fit: BoxFit.contain,
        placeholderBuilder: (_) => const SizedBox.expand(),
      );
    }
    return Image.asset(
      asset,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      errorBuilder: (context, error, stackTrace) => Icon(
        Icons.category_outlined,
        color: color ?? const Color(0xFF0D7B42),
      ),
    );
  }
}

class TgAnalyticsToolbar extends StatelessWidget {
  const TgAnalyticsToolbar({
    super.key,
    required this.controller,
    this.teamName = '',
    this.teamPlayers = const <Map<String, dynamic>>[],
  });

  final TgAnalyticsOverlayController controller;
  final String teamName;
  final List<Map<String, dynamic>> teamPlayers;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _tool(Icons.near_me_rounded, 'Выбор', TgAnalyticsTool.select),
                _tool(Icons.gesture_rounded, 'Рисовать', TgAnalyticsTool.freeDraw),
                _tool(Icons.trending_flat_rounded, 'Стрелка', TgAnalyticsTool.arrow),
                _tool(Icons.circle_outlined, 'Круг', TgAnalyticsTool.circle),
                _tool(Icons.crop_square_rounded, 'Зона', TgAnalyticsTool.zone),
                _tool(Icons.text_fields_rounded, 'Текст', TgAnalyticsTool.text),
                _tool(Icons.sticky_note_2_outlined, 'Заметка', TgAnalyticsTool.note),
                PopupMenuButton<Color>(
                  tooltip: 'Цвет',
                  onSelected: controller.setDrawColor,
                  itemBuilder: (context) => kTgAnalyticsPalette
                      .map(
                        (color) => PopupMenuItem<Color>(
                          value: color,
                          child: _TgColorItem(
                            color: color,
                            label: _colorName(color),
                          ),
                        ),
                      )
                      .toList(),
                  child: _TgStyleButton(
                    label: 'Цвет',
                    child: Container(
                      width: 15,
                      height: 15,
                      decoration: BoxDecoration(
                        color: controller.drawColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: controller.drawColor == Colors.white
                              ? const Color(0xFFCAD5CF)
                              : Colors.white,
                          width: 2,
                        ),
                        boxShadow: const [
                          BoxShadow(color: Color(0x22000000), blurRadius: 3),
                        ],
                      ),
                    ),
                  ),
                ),
                PopupMenuButton<double>(
                  tooltip: 'Толщина линии',
                  onSelected: controller.setStrokeWidth,
                  itemBuilder: (context) => kTgAnalyticsStrokeOptions
                      .map(
                        (value) => PopupMenuItem<double>(
                          value: value,
                          child: _TgStrokeItem(
                            stroke: value,
                            color: controller.drawColor,
                            selected: (controller.strokeWidth - value).abs() < .01,
                          ),
                        ),
                      )
                      .toList(),
                  child: _TgStyleButton(
                    label: '${controller.strokeWidth.toStringAsFixed(controller.strokeWidth == controller.strokeWidth.roundToDouble() ? 0 : 1)} px',
                    child: SizedBox(
                      width: 18,
                      child: CustomPaint(
                        painter: _TgStrokePreviewPainter(
                          color: controller.drawColor,
                          strokeWidth: controller.strokeWidth,
                        ),
                      ),
                    ),
                  ),
                ),
                _lineKindChip('Сплошная', LineKind.normal),
                _lineKindChip('Пунктир', LineKind.dashed),
                _lineKindChip('Волна', LineKind.wavy),
                _lineKindChip('Зигзаг', LineKind.zigzag),
                GestureDetector(
                  onTap: () => _openObjectLibrary(context),
                  child: _TgAnalyticsToolChip(
                    icon: Icons.category_outlined,
                    label: 'Объекты',
                    active: const <TgAnalyticsTool>{
                      TgAnalyticsTool.player,
                      TgAnalyticsTool.ball,
                      TgAnalyticsTool.chip,
                      TgAnalyticsTool.cone,
                      TgAnalyticsTool.dummy,
                      TgAnalyticsTool.goal,
                      TgAnalyticsTool.stamp,
                    }.contains(controller.tool),
                  ),
                ),
                const SizedBox(width: 5),
                _action(
                  Icons.remove_rounded,
                  'Меньше',
                  controller.hasSelection
                      ? () => controller.scaleSelected(.86)
                      : null,
                ),
                _action(
                  Icons.add_rounded,
                  'Больше',
                  controller.hasSelection
                      ? () => controller.scaleSelected(1.16)
                      : null,
                ),
                _action(
                  Icons.rotate_left_rounded,
                  '−15°',
                  controller.hasSelection
                      ? () => controller.rotateSelected(-math.pi / 12)
                      : null,
                ),
                _action(
                  Icons.rotate_right_rounded,
                  '+15°',
                  controller.hasSelection
                      ? () => controller.rotateSelected(math.pi / 12)
                      : null,
                ),
                _action(
                  Icons.undo_rounded,
                  'Назад',
                  controller.canUndo ? controller.undo : null,
                ),
                _action(
                  Icons.redo_rounded,
                  'Вперёд',
                  controller.canRedo ? controller.redo : null,
                ),
                _action(
                  Icons.delete_outline_rounded,
                  'Удалить',
                  controller.hasSelection ? controller.deleteSelected : null,
                ),
                _action(
                  Icons.layers_clear_outlined,
                  'Очистить',
                  controller.count > 0 ? () => _confirmClear(context) : null,
                ),
                if (controller.count > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    height: 28,
                    padding: const EdgeInsets.symmetric(horizontal: 9),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5EC),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      '${controller.count} объектов',
                      style: const TextStyle(
                        color: Color(0xFF157347),
                        fontSize: 9.2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openObjectLibrary(BuildContext context) async {
    final picked = await showGeneralDialog<TgAnalyticsObjectSpec>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Закрыть библиотеку объектов',
      barrierColor: const Color(0x520F1712),
      transitionDuration: const Duration(milliseconds: 220),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(.08, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
      pageBuilder: (panelContext, animation, secondaryAnimation) =>
          _TgAnalyticsObjectLibraryPanel(
        teamName: teamName,
        teamPlayers: teamPlayers,
        onClose: () => Navigator.of(panelContext).pop(),
        onPick: (spec) => Navigator.of(panelContext).pop(spec),
      ),
    );
    if (picked != null) controller.setStampObject(picked);
  }

  Widget _tool(IconData icon, String label, TgAnalyticsTool tool) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: GestureDetector(
        onTap: () => controller.setTool(tool),
        child: _TgAnalyticsToolChip(
          icon: icon,
          label: label,
          active: controller.tool == tool,
        ),
      ),
    );
  }

  Widget _lineKindChip(String label, LineKind kind) {
    final active = controller.lineKind == kind;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: GestureDetector(
        onTap: () => controller.setLineKind(kind),
        child: _TgAnalyticsToolChip(
          icon: kind == LineKind.dashed
              ? Icons.more_horiz_rounded
              : kind == LineKind.wavy
                  ? Icons.waves_rounded
                  : kind == LineKind.zigzag
                      ? Icons.show_chart_rounded
                      : Icons.horizontal_rule_rounded,
          label: label,
          active: active,
        ),
      ),
    );
  }

  Widget _action(IconData icon, String label, VoidCallback? onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Opacity(
        opacity: onTap == null ? .38 : 1,
        child: GestureDetector(
          onTap: onTap,
          child: _TgAnalyticsToolChip(
            icon: icon,
            label: label,
            active: false,
          ),
        ),
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Очистить разбор?'),
            content: const Text(
              'Все стрелки, зоны, объекты и заметки этого разбора будут удалены.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Очистить'),
              ),
            ],
          ),
        ) ??
        false;
    if (confirmed) controller.clearAll();
  }
}

class _TgAnalyticsObjectLibraryPanel extends StatefulWidget {
  const _TgAnalyticsObjectLibraryPanel({
    required this.teamName,
    required this.teamPlayers,
    required this.onClose,
    required this.onPick,
  });

  final String teamName;
  final List<Map<String, dynamic>> teamPlayers;
  final VoidCallback onClose;
  final ValueChanged<TgAnalyticsObjectSpec> onPick;

  @override
  State<_TgAnalyticsObjectLibraryPanel> createState() =>
      _TgAnalyticsObjectLibraryPanelState();
}

class _TgAnalyticsObjectLibraryPanelState
    extends State<_TgAnalyticsObjectLibraryPanel> {
  final TextEditingController _search = TextEditingController();
  String _category = 'Все';

  String _playerValue(Map<String, dynamic> player, List<String> keys) {
    for (final key in keys) {
      final value = '${player[key] ?? ''}'.trim();
      if (value.isNotEmpty && value.toLowerCase() != 'null') return value;
    }
    return '';
  }

  String _playerName(Map<String, dynamic> player) {
    final direct = _playerValue(
      player,
      const <String>['name', 'full_name', 'fullName', 'player_name', 'fio'],
    );
    if (direct.isNotEmpty) return direct;
    final first = _playerValue(
      player,
      const <String>['first_name', 'firstName', 'firstname'],
    );
    final last = _playerValue(
      player,
      const <String>['last_name', 'lastName', 'lastname', 'surname'],
    );
    final joined = <String>[last, first]
        .where((item) => item.isNotEmpty)
        .join(' ')
        .trim();
    return joined.isEmpty ? 'Игрок' : joined;
  }

  String _playerAvatar(Map<String, dynamic> player) {
    final raw = _playerValue(player, const <String>[
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

  TgAnalyticsObjectSpec _playerSpec(
    Map<String, dynamic> player,
    int index,
  ) {
    final name = _playerName(player);
    final number = _playerValue(player, const <String>[
      'number',
      'player_number',
      'shirt_number',
      'jersey_number',
    ]);
    final id = _playerValue(
      player,
      const <String>['id', 'player_id', 'user_id'],
    );
    final position = _playerValue(
      player,
      const <String>['position', 'role', 'amplua', 'player_position'],
    );
    final goalkeeper = position.toLowerCase().contains('врат') ||
        position.toLowerCase().contains('goal') ||
        position.toLowerCase() == 'gk';
    final ring = goalkeeper ? const Color(0xFF0EA5E9) : const Color(0xFF00A750);
    final asset = Uri(
      scheme: 'sportoteka',
      host: 'player-avatar',
      queryParameters: <String, String>{
        'id': id.isEmpty ? 'player_$index' : id,
        'name': name,
        'number': number.isEmpty ? '${index + 1}' : number,
        'avatar': _playerAvatar(player),
        'ring': ring.value.toString(),
        'team': 'home',
        'role': goalkeeper ? 'goalkeeper' : 'player',
      },
    ).toString();
    return TgAnalyticsObjectSpec(
      asset: asset,
      name: number.isEmpty ? name : '№$number · $name',
      subtitle: position.isEmpty ? 'Игрок состава' : position,
      category: 'Состав',
      size: goalkeeper ? 74 : 70,
      color: ring,
    );
  }

  List<TgAnalyticsObjectSpec> get _objects {
    final roster = <TgAnalyticsObjectSpec>[
      for (var i = 0; i < widget.teamPlayers.length; i++)
        _playerSpec(widget.teamPlayers[i], i),
    ];
    return <TgAnalyticsObjectSpec>[
      ...roster,
      const TgAnalyticsObjectSpec(
        asset: 'sportoteka://ball',
        name: 'Мяч',
        category: 'Тактика',
        size: 40,
        color: Color(0xFF17201B),
      ),
      const TgAnalyticsObjectSpec(
        asset: 'sportoteka://chip',
        name: 'Фишка',
        category: 'Тактика',
        size: 34,
        color: Color(0xFFF6C445),
      ),
      const TgAnalyticsObjectSpec(
        asset: 'sportoteka://cone',
        name: 'Конус',
        category: 'Тактика',
        size: 44,
        color: Color(0xFFFF8A00),
      ),
      const TgAnalyticsObjectSpec(
        asset: 'sportoteka://dummy',
        name: 'Манекен',
        category: 'Тактика',
        size: 66,
        color: Color(0xFF17201B),
      ),
      const TgAnalyticsObjectSpec(
        asset: 'sportoteka://goal',
        name: 'Ворота',
        category: 'Тактика',
        size: 94,
        color: Color(0xFFCBD5E1),
      ),
      if (roster.isEmpty)
        const TgAnalyticsObjectSpec(
          asset: 'sportoteka://player-avatar?name=Игрок&number=7&ring=4278236992',
          name: 'Игрок без привязки',
          subtitle: 'Состав команды не передан',
          category: 'Состав',
          size: 70,
          color: Color(0xFF00A750),
        ),
      ...kTgAnalyticsArchiveStampAssets.map(_tgArchiveObjectSpec),
    ];
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final width =
        math.min(590.0, math.max(300.0, media.size.width - 20)).toDouble();
    final categories = <String>[
      'Все',
      ..._objects.map((item) => item.category).toSet(),
    ];
    final query = _search.text.trim().toLowerCase();
    final visible = _objects.where((item) {
      final categoryMatches = _category == 'Все' || item.category == _category;
      final queryMatches = query.isEmpty ||
          item.name.toLowerCase().contains(query) ||
          item.subtitle.toLowerCase().contains(query) ||
          item.category.toLowerCase().contains(query);
      return categoryMatches && queryMatches;
    }).toList(growable: false);

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Align(
          alignment: Alignment.centerRight,
          child: Container(
            width: width,
            height: math
                .min(760.0, math.max(260.0, media.size.height - 24))
                .toDouble(),
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x260F1712),
                  blurRadius: 30,
                  spreadRadius: -8,
                  offset: Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 12, 12),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF6EE),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.category_outlined,
                          color: Color(0xFF0D7B42),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Text(
                              'Объекты Training Graphics',
                              style: TextStyle(
                                color: Color(0xFF17201B),
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              widget.teamName.trim().isEmpty
                                  ? 'Состав и библиотека из графического редактора'
                                  : '${widget.teamName.trim()} · состав и библиотека редактора',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF718078),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Закрыть',
                        onPressed: widget.onClose,
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(
                      color: Color(0xFF17201B),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Поиск игрока или объекта',
                      prefixIcon: const Icon(Icons.search_rounded, size: 19),
                      suffixIcon: query.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _search.clear();
                                setState(() {});
                              },
                              icon: const Icon(Icons.close_rounded, size: 18),
                            ),
                      filled: true,
                      fillColor: const Color(0xFFF6F8F7),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(13),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    itemCount: categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (context, index) {
                      final category = categories[index];
                      final active = category == _category;
                      return ChoiceChip(
                        selected: active,
                        showCheckmark: false,
                        label: Text(category),
                        onSelected: (_) => setState(() => _category = category),
                        side: BorderSide.none,
                        backgroundColor: const Color(0xFFF4F6F5),
                        selectedColor: const Color(0xFFE1F4E7),
                        labelStyle: TextStyle(
                          color: active
                              ? const Color(0xFF0D6A3A)
                              : const Color(0xFF59675F),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: visible.isEmpty
                      ? const Center(
                          child: Text(
                            'Ничего не найдено',
                            style: TextStyle(
                              color: Color(0xFF718078),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                      : LayoutBuilder(
                          builder: (context, constraints) {
                            final columns = constraints.maxWidth >= 480 ? 3 : 2;
                            return GridView.builder(
                              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: columns,
                                crossAxisSpacing: 9,
                                mainAxisSpacing: 9,
                                childAspectRatio: columns == 3 ? 1.08 : 1.25,
                              ),
                              itemCount: visible.length,
                              itemBuilder: (context, index) {
                                final item = visible[index];
                                return _TgAnalyticsObjectCard(
                                  spec: item,
                                  onTap: () => widget.onPick(item),
                                );
                              },
                            );
                          },
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

class _TgAnalyticsObjectCard extends StatelessWidget {
  const _TgAnalyticsObjectCard({required this.spec, required this.onTap});

  final TgAnalyticsObjectSpec spec;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF7F9F8),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Center(
                  child: _TgAnalyticsObjectThumb(spec: spec),
                ),
              ),
              const SizedBox(height: 7),
              Text(
                spec.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF17201B),
                  fontSize: 10.5,
                  height: 1.12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (spec.subtitle.isNotEmpty) ...<Widget>[
                const SizedBox(height: 2),
                Text(
                  spec.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF7D8982),
                    fontSize: 8.5,
                    fontWeight: FontWeight.w600,
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

class _TgAnalyticsObjectThumb extends StatelessWidget {
  const _TgAnalyticsObjectThumb({required this.spec});

  final TgAnalyticsObjectSpec spec;

  @override
  Widget build(BuildContext context) {
    final asset = spec.asset;
    if (_isTgBundleStamp(asset)) {
      if (asset.toLowerCase().endsWith('.svg')) {
        return SvgPicture.asset(asset, fit: BoxFit.contain);
      }
      return Image.asset(
        asset,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, __, ___) => const Icon(Icons.category_outlined),
      );
    }
    final uri = Uri.tryParse(asset);
    if (uri?.host == 'player-avatar') {
      final avatar = uri?.queryParameters['avatar'] ?? '';
      final label = uri?.queryParameters['number'] ??
          uri?.queryParameters['name'] ??
          'P';
      return Container(
        width: 54,
        height: 54,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(
            color: spec.color ?? const Color(0xFF00A750),
            width: 3,
          ),
        ),
        child: avatar.isEmpty
            ? Center(
                child: Text(
                  label,
                  maxLines: 1,
                  style: const TextStyle(
                    color: Color(0xFF17201B),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              )
            : Image.network(
                avatar,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Center(
                  child: Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ),
      );
    }
    final icon = asset.contains('ball')
        ? Icons.sports_soccer_rounded
        : asset.contains('cone')
            ? Icons.change_history_rounded
            : asset.contains('goal')
                ? Icons.table_rows_rounded
                : asset.contains('dummy')
                    ? Icons.accessibility_new_rounded
                    : Icons.circle_rounded;
    return Icon(
      icon,
      size: 48,
      color: spec.color ?? const Color(0xFF0D7B42),
    );
  }
}

String _colorName(Color color) {
  switch (color.value) {
    case 0xFFE53935:
      return 'Красный';
    case 0xFFEF334D:
      return 'Малиновый';
    case 0xFFFF8A00:
      return 'Оранжевый';
    case 0xFFF6C445:
      return 'Жёлтый';
    case 0xFF0D7B42:
      return 'Зелёный';
    case 0xFF13A35F:
      return 'Лайм';
    case 0xFF1976D2:
      return 'Синий';
    case 0xFF38BDF8:
      return 'Голубой';
    case 0xFF7C3AED:
      return 'Фиолетовый';
    case 0xFFFFFFFF:
      return 'Белый';
    case 0xFF17201B:
      return 'Чёрный';
  }
  return 'Цвет';
}

class _TgStyleButton extends StatelessWidget {
  const _TgStyleButton({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFFDDE4DF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          child,
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF465149),
              fontSize: 9.2,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _TgStrokePreviewPainter extends CustomPainter {
  const _TgStrokePreviewPainter({required this.color, required this.strokeWidth});

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    canvas.drawLine(
      Offset(0, y),
      Offset(size.width, y),
      Paint()
        ..color = color
        ..strokeWidth = strokeWidth.clamp(2, 12)
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _TgStrokePreviewPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}

class _TgStrokeItem extends StatelessWidget {
  const _TgStrokeItem({
    required this.stroke,
    required this.color,
    required this.selected,
  });

  final double stroke;
  final Color color;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 48,
          height: 20,
          child: CustomPaint(
            painter: _TgStrokePreviewPainter(color: color, strokeWidth: stroke),
          ),
        ),
        const SizedBox(width: 10),
        Text('${stroke.toStringAsFixed(stroke == stroke.roundToDouble() ? 0 : 1)} px'),
        if (selected) ...[
          const SizedBox(width: 8),
          const Icon(Icons.check_rounded, size: 16, color: Color(0xFF0D7B42)),
        ],
      ],
    );
  }
}

class _TgColorItem extends StatelessWidget {
  const _TgColorItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 9),
      Text(label),
    ]);
  }
}

class _TgAnalyticsToolChip extends StatelessWidget {
  const _TgAnalyticsToolChip({
    required this.icon,
    required this.label,
    required this.active,
  });

  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFE1F4E7) : Colors.white,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: active ? const Color(0xFF8ED3A7) : const Color(0xFFDDE4DF),
        ),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(
          icon,
          size: 14,
          color: active ? const Color(0xFF0D7B42) : const Color(0xFF67736C),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: active
                ? const Color(0xFF0D6A3A)
                : const Color(0xFF465149),
            fontSize: 9.2,
            fontWeight: FontWeight.w800,
          ),
        ),
      ]),
    );
  }
}

class _TgAnalyticsPainter extends CustomPainter {
  _TgAnalyticsPainter({
    required this.controller,
    required this.logicalSize,
  }) : super(repaint: controller);

  final TgAnalyticsOverlayController controller;
  final Size logicalSize;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / math.max(1.0, logicalSize.width);
    final sy = size.height / math.max(1.0, logicalSize.height);
    final selectionUiScale =
        (1 / math.max(.001, math.min(sx, sy))).clamp(1.0, 3.0).toDouble();
    canvas.save();
    canvas.scale(sx, sy);
    for (final element in controller.elements) {
      if (element.hidden) continue;
      _paintElement(
        canvas,
        element,
        selected: element.id == controller.selectedId,
        selectionUiScale: selectionUiScale,
      );
    }
    final p = controller.preview;
    if (p != null) {
      _paintElement(
        canvas,
        p,
        selected: false,
        preview: true,
        selectionUiScale: selectionUiScale,
      );
    }
    canvas.restore();
  }

  void _paintElement(
    Canvas canvas,
    TgElement element, {
    required bool selected,
    bool preview = false,
    required double selectionUiScale,
  }) {
    if (element is TgLine) {
      final paint = Paint()
        ..color = element.color.withOpacity(element.opacity * (preview ? .72 : 1))
        ..strokeWidth = element.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      final path = Path()
        ..moveTo(element.a.dx, element.a.dy)
        ..lineTo(element.b.dx, element.b.dy);
      _strokePath(canvas, path, paint, element.kind);
      _drawLineEnding(canvas, element.a, element.b, paint, element.end, element.arrowSize);
    } else if (element is TgPolyline) {
      if (element.points.length >= 2) {
        final path = Path()..moveTo(element.points.first.dx, element.points.first.dy);
        for (final point in element.points.skip(1)) {
          path.lineTo(point.dx, point.dy);
        }
        final paint = Paint()
          ..color = element.color.withOpacity(element.opacity * (preview ? .72 : 1))
          ..strokeWidth = element.width
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke;
        _strokePath(canvas, path, paint, element.kind);
        if (element.end != LineEnd.none && element.points.length >= 2) {
          _drawLineEnding(
            canvas,
            element.points[element.points.length - 2],
            element.points.last,
            paint,
            element.end,
            element.arrowSize,
          );
        }
      }
    } else if (element is TgCircle) {
      canvas.drawCircle(
        element.position,
        element.radius,
        Paint()
          ..color = element.fill.withOpacity(.12 * (preview ? .7 : 1))
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        element.position,
        element.radius,
        Paint()
          ..color = element.border.withOpacity(preview ? .7 : 1)
          ..strokeWidth = element.borderWidth
          ..style = PaintingStyle.stroke,
      );
    } else if (element is TgZone) {
      if (element.points.length >= 3) {
        final path = Path()..moveTo(element.points.first.dx, element.points.first.dy);
        for (final point in element.points.skip(1)) {
          path.lineTo(point.dx, point.dy);
        }
        path.close();
        canvas.drawPath(
          path,
          Paint()
            ..color = element.fill.withOpacity(element.opacity * (preview ? .72 : 1))
            ..style = PaintingStyle.fill,
        );
        canvas.drawPath(
          path,
          Paint()
            ..color = element.border.withOpacity(preview ? .72 : 1)
            ..strokeWidth = element.borderWidth
            ..style = PaintingStyle.stroke,
        );
      }
    } else if (element is TgText) {
      _paintText(canvas, element);
    } else if (element is TgStamp) {
      // Реальные PNG/SVG из Training Graphics рисуются отдельным widget-слоем.
      // CustomPainter оставляет поверх них выделение и ручки трансформации.
      if (!_isTgBundleStamp(element.asset)) {
        _paintStamp(canvas, element);
      }
    }

    if (selected && !element.locked) {
      final bounds = element.bounds().inflate(9 * selectionUiScale);
      final rotationHandle = _analyticsRotationHandle(
        bounds,
        logicalSize,
        distance: 34 * selectionUiScale,
      );
      final selectionPaint = Paint()
        ..color = const Color(0xFF0D7B42)
        ..strokeWidth = 2.2 * selectionUiScale
        ..style = PaintingStyle.stroke;
      canvas.drawRRect(
        RRect.fromRectAndRadius(bounds, const Radius.circular(8)),
        selectionPaint,
      );
      canvas.drawLine(bounds.topCenter, rotationHandle, selectionPaint);
      for (final point in <Offset>[
        bounds.topLeft,
        bounds.topRight,
        bounds.bottomLeft,
        bounds.bottomRight,
      ]) {
        canvas.drawCircle(
          point,
          7 * selectionUiScale,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.fill,
        );
        canvas.drawCircle(
          point,
          7 * selectionUiScale,
          Paint()
            ..color = const Color(0xFF0D7B42)
            ..strokeWidth = 2 * selectionUiScale
            ..style = PaintingStyle.stroke,
        );
      }
      canvas.drawCircle(
        rotationHandle,
        9 * selectionUiScale,
        Paint()
          ..color = const Color(0xFF0D7B42)
          ..style = PaintingStyle.fill,
      );
      final arcRect = Rect.fromCircle(
        center: rotationHandle,
        radius: 4.5 * selectionUiScale,
      );
      canvas.drawArc(
        arcRect,
        -.35,
        math.pi * 1.45,
        false,
        Paint()
          ..color = Colors.white
          ..strokeWidth = 1.8 * selectionUiScale
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke,
      );
    }
  }

  void _paintText(Canvas canvas, TgText element) {
    final note = (element.name ?? '').startsWith('analytics_note:');
    canvas.save();
    canvas.translate(element.position.dx, element.position.dy);
    canvas.rotate(element.rotation);
    canvas.translate(-element.position.dx, -element.position.dy);
    try {
      final painter = TextPainter(
        text: TextSpan(
          text: element.text,
          style: TextStyle(
            color: element.color.withOpacity(element.opacity),
            fontSize: element.size,
            fontWeight: element.weight,
            height: 1.18,
          ),
        ),
        textAlign: element.alignment,
        textDirection: TextDirection.ltr,
        maxLines: note ? 7 : 3,
        ellipsis: '…',
      )..layout(maxWidth: note ? 330 : 360);

      final topLeft =
          element.position - Offset(painter.width / 2, painter.height / 2);
      if (note) {
        final bubble = Rect.fromLTWH(
          topLeft.dx - 14,
          topLeft.dy - 11,
          painter.width + 28,
          painter.height + 22,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(bubble, const Radius.circular(14)),
          Paint()
            ..color = Colors.white.withOpacity(.94)
            ..style = PaintingStyle.fill,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(bubble, const Radius.circular(14)),
          Paint()
            ..color = const Color(0xFF86C89D)
            ..strokeWidth = 2
            ..style = PaintingStyle.stroke,
        );
      }
      painter.paint(canvas, topLeft);
    } finally {
      canvas.restore();
    }
  }

  void _paintStamp(Canvas canvas, TgStamp element) {
    final center = element.pos;
    final size = element.size;
    final asset = element.asset.toLowerCase();
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(element.rotation);
    canvas.translate(-center.dx, -center.dy);
    try {
    if (asset.startsWith('sportoteka://player-avatar') ||
        asset.endsWith('player') ||
        asset == 'analytics://player') {
      _paintPlayerStamp(canvas, element, center, size);
      return;
    }
    if (asset.startsWith('sportoteka://ball') || asset == 'analytics://ball') {
      _paintBallStamp(canvas, element, center, size);
      return;
    }
    if (asset.startsWith('sportoteka://chip')) {
      _paintChipStamp(canvas, element, center, size);
      return;
    }
    if (asset.startsWith('sportoteka://cone') || asset == 'analytics://cone') {
      _paintConeStamp(canvas, element, center, size);
      return;
    }
    if (asset.startsWith('sportoteka://dummy')) {
      _paintDummyStamp(canvas, element, center, size);
      return;
    }
    if (asset.startsWith('sportoteka://goal')) {
      _paintGoalStamp(canvas, element, center, size);
      return;
    }
    _paintChipStamp(canvas, element, center, size);
    } finally {
      canvas.restore();
    }
  }

  void _strokePath(Canvas canvas, Path path, Paint paint, LineKind kind) {
    switch (kind) {
      case LineKind.normal:
        canvas.drawPath(path, paint);
        return;
      case LineKind.dashed:
        _drawDashedPath(
          canvas,
          path,
          paint,
          dash: paint.strokeWidth * 2.6,
          gap: paint.strokeWidth * 1.8,
        );
        return;
      case LineKind.dotted:
        _drawDashedPath(
          canvas,
          path,
          paint,
          dash: .01,
          gap: paint.strokeWidth * 1.7,
          dots: true,
        );
        return;
      case LineKind.wavy:
        _drawOffsetPath(canvas, path, paint, zigzag: false);
        return;
      case LineKind.zigzag:
        _drawOffsetPath(canvas, path, paint, zigzag: true);
        return;
    }
  }

  void _drawOffsetPath(
    Canvas canvas,
    Path source,
    Paint paint, {
    required bool zigzag,
  }) {
    final output = Path();
    bool started = false;
    for (final metric in source.computeMetrics()) {
      final wavelength = math.max(16.0, paint.strokeWidth * 4.5);
      final amplitude = math.max(5.0, paint.strokeWidth * 1.35);
      final step = math.max(3.0, paint.strokeWidth * .65);
      for (double d = 0; d <= metric.length; d += step) {
        final tangent = metric.getTangentForOffset(d.clamp(0.0, metric.length));
        if (tangent == null) continue;
        final angle = tangent.angle + math.pi / 2;
        final phase = (d / wavelength) * math.pi * 2;
        final offsetAmount = zigzag
            ? (math.sin(phase) >= 0 ? amplitude : -amplitude)
            : math.sin(phase) * amplitude;
        final p = tangent.position + Offset.fromDirection(angle, offsetAmount);
        if (!started) {
          output.moveTo(p.dx, p.dy);
          started = true;
        } else {
          output.lineTo(p.dx, p.dy);
        }
      }
    }
    canvas.drawPath(output, paint);
  }

  void _drawDashedPath(
    Canvas canvas,
    Path source,
    Paint paint, {
    required double dash,
    required double gap,
    bool dots = false,
  }) {
    for (final metric in source.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final end = (distance + dash).clamp(0.0, metric.length).toDouble();
        final segment = metric.extractPath(distance, end);
        if (dots) {
          final tangent = metric.getTangentForOffset(distance);
          if (tangent != null) {
            canvas.drawCircle(
              tangent.position,
              paint.strokeWidth / 2,
              Paint()..color = paint.color,
            );
          }
        } else {
          canvas.drawPath(segment, paint);
        }
        distance += dash + gap;
      }
    }
  }

  void _drawLineEnding(
    Canvas canvas,
    Offset from,
    Offset to,
    Paint paint,
    LineEnd end,
    double size,
  ) {
    switch (end) {
      case LineEnd.none:
        return;
      case LineEnd.arrow:
        _drawArrowHead(canvas, from, to, paint, size);
        return;
      case LineEnd.circle:
        canvas.drawCircle(
          to,
          size * .35,
          Paint()
            ..color = paint.color
            ..style = PaintingStyle.fill,
        );
        return;
      case LineEnd.diamond:
        final delta = to - from;
        if (delta.distance < 1) return;
        final angle = math.atan2(delta.dy, delta.dx);
        final p1 = to - Offset.fromDirection(angle, size * .55);
        final p2 = to - Offset.fromDirection(angle - math.pi / 2, size * .32);
        final p3 = to - Offset.fromDirection(angle + math.pi, size * .55);
        final p4 = to - Offset.fromDirection(angle + math.pi / 2, size * .32);
        final path = Path()
          ..moveTo(to.dx, to.dy)
          ..lineTo(p2.dx, p2.dy)
          ..lineTo(p3.dx, p3.dy)
          ..lineTo(p4.dx, p4.dy)
          ..close();
        canvas.drawPath(
          path,
          Paint()
            ..color = paint.color
            ..style = PaintingStyle.fill,
        );
        canvas.drawLine(from, p1, paint);
        return;
    }
  }

  String _stampInitials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'P';
    if (parts.length == 1) return parts.first.characters.first.toUpperCase();
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  Color _stampRingColor(TgStamp element) {
    final uri = Uri.tryParse(element.asset);
    final ringRaw = uri?.queryParameters['ring'];
    final normalized = (ringRaw ?? '').trim();
    final ringValue = normalized.toLowerCase().startsWith('0x')
        ? int.tryParse(normalized.substring(2), radix: 16)
        : RegExp(r'[a-fA-F]').hasMatch(normalized)
            ? int.tryParse(normalized, radix: 16)
            : int.tryParse(normalized);
    if (ringValue != null) return Color(ringValue);
    return element.color ?? const Color(0xFF0D7B42);
  }

  void _drawSoftShadow(Canvas canvas, Offset center, double width, double height) {
    canvas.drawOval(
      Rect.fromCenter(
        center: center + Offset(0, height * .12),
        width: width,
        height: height,
      ),
      Paint()..color = const Color(0x22000000),
    );
  }

  void _paintPlayerStamp(
    Canvas canvas,
    TgStamp element,
    Offset center,
    double size,
  ) {
    final uri = Uri.tryParse(element.asset);
    final name = (uri?.queryParameters['name'] ?? element.name ?? 'Игрок').trim();
    final number = (uri?.queryParameters['number'] ?? '').trim();
    final ring = _stampRingColor(element);
    _drawSoftShadow(canvas, center, size * .72, size * .24);
    canvas.drawCircle(center, size * .42, Paint()..color = const Color(0xFFF8FAFC));
    canvas.drawCircle(
      center,
      size * .42,
      Paint()
        ..color = ring.withOpacity(element.opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size * .11,
    );
    canvas.drawCircle(
      center,
      size * .31,
      Paint()..color = ring.withOpacity(.14 * element.opacity),
    );
    final initials = _stampInitials(name);
    final tp = TextPainter(
      text: TextSpan(
        text: initials,
        style: TextStyle(
          color: const Color(0xFF0F172A),
          fontSize: size * .23,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2 + size * .03));
    if (number.isNotEmpty) {
      final badge = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: center + Offset(0, size * .34),
          width: size * .42,
          height: size * .22,
        ),
        Radius.circular(size * .11),
      );
      canvas.drawRRect(badge, Paint()..color = ring.withOpacity(element.opacity));
      final np = TextPainter(
        text: TextSpan(
          text: number,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * .15,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      np.paint(canvas, center + Offset(-np.width / 2, size * .34 - np.height / 2));
    }
  }

  void _paintBallStamp(Canvas canvas, TgStamp element, Offset center, double size) {
    _drawSoftShadow(canvas, center, size * .58, size * .18);
    final r = size * .34;
    canvas.drawCircle(center, r, Paint()..color = Colors.white.withOpacity(element.opacity));
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = const Color(0xFF0F172A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size * .05,
    );
    final pentagon = <Offset>[];
    for (var i = 0; i < 5; i++) {
      final angle = -math.pi / 2 + i * math.pi * 2 / 5;
      pentagon.add(center + Offset(math.cos(angle) * r * .34, math.sin(angle) * r * .34));
    }
    final path = Path()..moveTo(pentagon.first.dx, pentagon.first.dy);
    for (final p in pentagon.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = const Color(0xFF0F172A));
    for (final p in pentagon) {
      canvas.drawLine(
        center,
        p,
        Paint()
          ..color = const Color(0xFF0F172A)
          ..strokeWidth = size * .035,
      );
    }
  }

  void _paintChipStamp(Canvas canvas, TgStamp element, Offset center, double size) {
    final color = element.color ?? const Color(0xFFF6C445);
    _drawSoftShadow(canvas, center, size * .60, size * .16);
    canvas.drawOval(
      Rect.fromCenter(
        center: center + Offset(0, size * .04),
        width: size * .72,
        height: size * .24,
      ),
      Paint()..color = color.withOpacity(.45),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: center - Offset(0, size * .02),
        width: size * .72,
        height: size * .24,
      ),
      Paint()..color = color.withOpacity(element.opacity),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: center - Offset(0, size * .02),
        width: size * .72,
        height: size * .24,
      ),
      Paint()
        ..color = Colors.white.withOpacity(.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size * .06,
    );
  }

  void _paintConeStamp(Canvas canvas, TgStamp element, Offset center, double size) {
    final color = element.color ?? const Color(0xFFFF8A00);
    _drawSoftShadow(canvas, center, size * .68, size * .18);
    final h = size * .82;
    final w = size * .68;
    final path = Path()
      ..moveTo(center.dx, center.dy - h / 2)
      ..lineTo(center.dx - w / 2, center.dy + h / 2)
      ..lineTo(center.dx + w / 2, center.dy + h / 2)
      ..close();
    canvas.drawPath(path, Paint()..color = color.withOpacity(element.opacity));
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withOpacity(.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = size * .045,
    );
    canvas.drawLine(
      Offset(center.dx - w * .28, center.dy - h * .02),
      Offset(center.dx + w * .20, center.dy - h * .02),
      Paint()
        ..color = Colors.white.withOpacity(.90)
        ..strokeWidth = size * .08
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(center.dx - w * .35, center.dy + h * .18),
      Offset(center.dx + w * .28, center.dy + h * .18),
      Paint()
        ..color = Colors.white.withOpacity(.90)
        ..strokeWidth = size * .08
        ..strokeCap = StrokeCap.round,
    );
  }

  void _paintDummyStamp(Canvas canvas, TgStamp element, Offset center, double size) {
    final color = element.color ?? const Color(0xFF0D7B42);
    _drawSoftShadow(canvas, center, size * .82, size * .18);
    final stroke = Paint()
      ..color = color.withOpacity(element.opacity)
      ..strokeWidth = size * .07
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawCircle(center - Offset(0, size * .28), size * .11, stroke);
    final body = Path()
      ..moveTo(center.dx, center.dy - size * .15)
      ..lineTo(center.dx, center.dy + size * .14)
      ..moveTo(center.dx - size * .18, center.dy - size * .02)
      ..lineTo(center.dx + size * .18, center.dy - size * .02)
      ..moveTo(center.dx, center.dy + size * .14)
      ..lineTo(center.dx - size * .14, center.dy + size * .38)
      ..moveTo(center.dx, center.dy + size * .14)
      ..lineTo(center.dx + size * .14, center.dy + size * .38);
    canvas.drawPath(body, stroke);
    canvas.drawLine(center + Offset(0, size * .38), center + Offset(0, size * .50), stroke);
    canvas.drawLine(
      center + Offset(-size * .20, size * .50),
      center + Offset(size * .20, size * .50),
      Paint()
        ..color = const Color(0xFF64748B)
        ..strokeWidth = size * .08
        ..strokeCap = StrokeCap.round,
    );
  }

  void _paintGoalStamp(Canvas canvas, TgStamp element, Offset center, double size) {
    _drawSoftShadow(canvas, center, size * .90, size * .16);
    final rect = Rect.fromCenter(
      center: center,
      width: size * .88,
      height: size * .48,
    );
    final frame = Paint()
      ..color = const Color(0xFFF8FAFC)
      ..strokeWidth = size * .06
      ..style = PaintingStyle.stroke;
    canvas.drawRect(rect, frame);
    final net = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = size * .018
      ..style = PaintingStyle.stroke;
    for (int i = 1; i < 5; i++) {
      final x = rect.left + rect.width * i / 5;
      canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), net);
    }
    for (int i = 1; i < 3; i++) {
      final y = rect.top + rect.height * i / 3;
      canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), net);
    }
  }

  void _drawArrowHead(
    Canvas canvas,
    Offset from,
    Offset to,
    Paint paint,
    double arrowSize,
  ) {
    final delta = to - from;
    if (delta.distance < 1) return;
    final angle = math.atan2(delta.dy, delta.dx);
    const spread = .58;
    final p1 = to - Offset.fromDirection(angle - spread, arrowSize);
    final p2 = to - Offset.fromDirection(angle + spread, arrowSize);
    final path = Path()
      ..moveTo(to.dx, to.dy)
      ..lineTo(p1.dx, p1.dy)
      ..moveTo(to.dx, to.dy)
      ..lineTo(p2.dx, p2.dy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TgAnalyticsPainter oldDelegate) =>
      !identical(oldDelegate.controller, controller) ||
      oldDelegate.logicalSize != logicalSize;
}
