import 'dart:math' as math;
import 'package:flutter/material.dart';

/// =======================
/// LINE STYLE ENUMS
/// =======================
enum LineKind { normal, dashed, dotted, wavy, zigzag }
enum LineEnd { none, arrow, diamond, circle }
enum BorderKind { solid, dashed, dotted, doubleLine }
enum TgTextStyle { normal, underline, italic }
enum TgStrokeCap { butt, round, square }
enum TgStrokeJoin { miter, round, bevel }
enum TgLineCurve { straight, curved }
enum CurveType { line, quadratic, cubic }
enum PointType { anchor, control1, control2 }

/// =======================
/// Base + meta
/// =======================
abstract class TgElement {
  const TgElement({
    required this.id,
    this.locked = false,
    this.hidden = false,
    this.layer = "default",
    this.name,
    this.createdAt,
  });

  final String id;
  final String layer;
  final bool locked;
  final bool hidden;
  final String? name;
  final int? createdAt;

  Rect bounds();
  
  bool hitTest(Offset p, {double tolerance = 0}) =>
      bounds().inflate(tolerance).contains(p);

  Map<String, dynamic> toJson();

  Map<String, dynamic> metaJson() => {
        "id": id,
        "layer": layer,
        "locked": locked,
        "hidden": hidden,
        "name": name,
        "createdAt": createdAt,
      };

  static TgElement fromJson(Map<String, dynamic> j) {
    final t = (j["type"] ?? "").toString();
    switch (t) {
      case "line": return TgLine.fromJson(j);
      case "rect": return TgRect.fromJson(j);
      case "circle": return TgCircle.fromJson(j);
      case "text": return TgText.fromJson(j);
      case "stamp": return TgStamp.fromJson(j);
      case "polyline": return TgPolyline.fromJson(j);
      case "zone": return TgZone.fromJson(j);
      case "group": return TgGroup.fromJson(j);
      case "curve": return TgCurve.fromJson(j);
      case "editable_curve": return TgEditableCurve.fromJson(j);
      case "zigzag": return TgZigzag.fromJson(j);
      case "editable_zigzag": return TgEditableZigzag.fromJson(j);
      case "spiral": return TgSpiral.fromJson(j);
      case "editable_spiral": return TgEditableSpiral.fromJson(j);
      case "spring": return TgSpring.fromJson(j);
      case "editable_spring": return TgEditableSpring.fromJson(j);
          case "editable_wavy": return TgEditableWavy.fromJson(j); // ДОБАВЬТЕ ЭТУ СТРОКУ
       case "wavy": return TgWavy.fromJson(j);
      default:
        if (j.containsKey("asset")) return TgStamp.fromJson(j);
        return TgRect.fromJson(j);
    }
  }
}

/// =======================
/// JSON helpers
/// =======================
Offset _offFromJson(dynamic v) {
  if (v is Map) {
    final dxV = (v["dx"] ?? v["x"]);
    final dyV = (v["dy"] ?? v["y"]);
    final dx = (dxV is num) ? dxV.toDouble() : 0.0;
    final dy = (dyV is num) ? dyV.toDouble() : 0.0;
    return Offset(dx, dy);
  }
  if (v is List && v.length >= 2) {
    return Offset((v[0] as num).toDouble(), (v[1] as num).toDouble());
  }
  return Offset.zero;
}

Map<String, dynamic> _offToJson(Offset o) => {"dx": o.dx, "dy": o.dy};

Color _colorFromJson(dynamic v, {Color fallback = Colors.black}) {
  if (v is int) return Color(v);
  if (v is String) {
    final s = v.trim();
    if (s.startsWith("#")) {
      final hex = s.substring(1);
      final val = int.tryParse(hex, radix: 16);
      if (val != null) {
        if (hex.length == 6) return Color(0xFF000000 | val);
        return Color(val);
      }
    }
    final asInt = int.tryParse(s);
    if (asInt != null) return Color(asInt);
  }
  return fallback;
}

double _doubleFromJson(dynamic v, double fallback) {
  if (v is double) return v;
  if (v is int) return v.toDouble();
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? "") ?? fallback;
}

int? _intFromJson(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  final s = v?.toString();
  if (s == null) return null;
  return int.tryParse(s);
}

dynamic _enumToJson(Object e) => e.toString().split(".").last;

T _enumFromJson<T>(List<T> values, dynamic v, T fallback) {
  final s = (v ?? "").toString();
  for (final x in values) {
    if (x.toString().split(".").last == s) return x;
  }
  return fallback;
}

List<double>? _doubleListFromJson(dynamic v) {
  if (v is List) {
    final out = <double>[];
    for (final x in v) {
      if (x is num) out.add(x.toDouble());
      else {
        final p = double.tryParse(x?.toString() ?? "");
        if (p != null) out.add(p);
      }
    }
    return out.isEmpty ? null : out;
  }
  return null;
}

/// =======================
/// PLAYER COLORS
/// =======================
class PlayerColors {
  final Color jersey;
  final Color shorts;
  final Color skin;
  final Color socks;
  final bool isProp;
  
  const PlayerColors({
    required this.jersey,
    required this.shorts,
    this.skin = const Color(0xFFFBCDAA),
    this.socks = Colors.white,
    this.isProp = false,
  });

  PlayerColors copyWith({
    Color? jersey,
    Color? shorts,
    Color? skin,
    Color? socks,
    bool? isProp,
  }) {
    return PlayerColors(
      jersey: jersey ?? this.jersey,
      shorts: shorts ?? this.shorts,
      skin: skin ?? this.skin,
      socks: socks ?? this.socks,
      isProp: isProp ?? this.isProp,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PlayerColors &&
        other.jersey == jersey &&
        other.shorts == shorts &&
        other.skin == skin &&
        other.socks == socks &&
        other.isProp == isProp;
  }

  @override
  int get hashCode => Object.hash(jersey, shorts, skin, socks, isProp);
  
  Map<String, dynamic> toJson() => {
    'jersey': jersey.value,
    'shorts': shorts.value,
    'skin': skin.value,
    'socks': socks.value,
    'isProp': isProp,
  };
  
  factory PlayerColors.fromJson(Map<String, dynamic> json) {
    return PlayerColors(
      jersey: Color(json['jersey'] ?? 0xFF0068B4),
      shorts: Color(json['shorts'] ?? 0xFFFFFFFF),
      skin: Color(json['skin'] ?? 0xFFFBCDAA),
      socks: Color(json['socks'] ?? 0xFFFFFFFF),
      isProp: json['isProp'] ?? false,
    );
  }
}

/// =======================
/// LINE
/// =======================
class TgLine extends TgElement {
  const TgLine({
    required super.id,
    required this.a,
    required this.b,
    required this.color,
    required this.width,
    required this.kind,
    required this.end,
    required this.arrowSize,
    this.opacity = 1.0,
    this.cap = TgStrokeCap.round,
    this.join = TgStrokeJoin.round,
    this.dash,
    this.curveMode = TgLineCurve.straight,
    this.curveAmount = 0.0,
    super.locked,
    super.hidden,
    super.layer,
    super.name,
    super.createdAt,
  });

  final Offset a;
  final Offset b;
  final Color color;
  final double width;
  final LineKind kind;
  final LineEnd end;
  final double arrowSize;
  final double opacity;
  final TgStrokeCap cap;
  final TgStrokeJoin join;
  final List<double>? dash;
  final TgLineCurve curveMode;
  final double curveAmount;

  @override
  Rect bounds() {
    final left = math.min(a.dx, b.dx);
    final top = math.min(a.dy, b.dy);
    final right = math.max(a.dx, b.dx);
    final bottom = math.max(a.dy, b.dy);
    return Rect.fromLTRB(left, top, right, bottom).inflate(width + 10);
  }

  @override
  bool hitTest(Offset p, {double tolerance = 0}) {
    final tol = width + 10 + tolerance;
    final ap = p - a;
    final ab = b - a;
    final ab2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (ab2 <= 0.00001) return (p - a).distance <= tol;
    var t = (ap.dx * ab.dx + ap.dy * ab.dy) / ab2;
    t = t.clamp(0.0, 1.0);
    final proj = Offset(a.dx + ab.dx * t, a.dy + ab.dy * t);
    return (p - proj).distance <= tol;
  }

  TgLine copyWith({
    String? id,
    Offset? a,
    Offset? b,
    Color? color,
    double? width,
    LineKind? kind,
    LineEnd? end,
    double? arrowSize,
    double? opacity,
    TgStrokeCap? cap,
    TgStrokeJoin? join,
    List<double>? dash,
    bool dashToNull = false,
    TgLineCurve? curveMode,
    double? curveAmount,
    bool? locked,
    bool? hidden,
    String? layer,
    String? name,
    int? createdAt,
  }) {
    return TgLine(
      id: id ?? this.id,
      a: a ?? this.a,
      b: b ?? this.b,
      color: color ?? this.color,
      width: width ?? this.width,
      kind: kind ?? this.kind,
      end: end ?? this.end,
      arrowSize: arrowSize ?? this.arrowSize,
      opacity: opacity ?? this.opacity,
      cap: cap ?? this.cap,
      join: join ?? this.join,
      dash: dashToNull ? null : (dash ?? this.dash),
      curveMode: curveMode ?? this.curveMode,
      curveAmount: curveAmount ?? this.curveAmount,
      locked: locked ?? this.locked,
      hidden: hidden ?? this.hidden,
      layer: layer ?? this.layer,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        "type": "line",
        ...metaJson(),
        "a": _offToJson(a),
        "b": _offToJson(b),
        "color": color.value,
        "width": width,
        "kind": _enumToJson(kind),
        "end": _enumToJson(end),
        "arrowSize": arrowSize,
        "opacity": opacity,
        "cap": _enumToJson(cap),
        "join": _enumToJson(join),
        "dash": dash,
        "curveMode": _enumToJson(curveMode),
        "curveAmount": curveAmount,
      };

  factory TgLine.fromJson(Map<String, dynamic> j) {
    return TgLine(
      id: (j["id"] ?? "").toString(),
      a: _offFromJson(j["a"]),
      b: _offFromJson(j["b"]),
      color: _colorFromJson(j["color"], fallback: Colors.black),
      width: _doubleFromJson(j["width"], 4.0),
      kind: _enumFromJson(LineKind.values, j["kind"], LineKind.normal),
      end: _enumFromJson(LineEnd.values, j["end"], LineEnd.none),
      arrowSize: _doubleFromJson(j["arrowSize"], 16.0),
      opacity: _doubleFromJson(j["opacity"], 1.0).clamp(0.0, 1.0).toDouble(),
      cap: _enumFromJson(TgStrokeCap.values, j["cap"], TgStrokeCap.round),
      join: _enumFromJson(TgStrokeJoin.values, j["join"], TgStrokeJoin.round),
      dash: _doubleListFromJson(j["dash"]),
      curveMode: _enumFromJson(TgLineCurve.values, j["curveMode"], TgLineCurve.straight),
      curveAmount: _doubleFromJson(j["curveAmount"], 0.0).clamp(-1.0, 1.0).toDouble(),
      locked: j["locked"] == true,
      hidden: j["hidden"] == true,
      layer: (j["layer"] ?? "default").toString(),
      name: j["name"]?.toString(),
      createdAt: _intFromJson(j["createdAt"]),
    );
  }
}

/// =======================
/// RECT
/// =======================
class TgRect extends TgElement {
  const TgRect({
    required super.id,
    required this.position,
    required this.width,
    required this.height,
    required this.rotation,
    required this.fill,
    required this.opacity,
    required this.border,
    required this.borderWidth,
    required this.borderKind,
    required this.borderRadius,
    super.locked,
    super.hidden,
    super.layer,
    super.name,
    super.createdAt,
  });

  final Offset position;
  final double width;
  final double height;
  final double rotation;
  final Color fill;
  final double opacity;
  final Color border;
  final double borderWidth;
  final BorderKind borderKind;
  final double borderRadius;

  @override
  Rect bounds() =>
      Rect.fromCenter(center: position, width: width, height: height);

  TgRect copyWith({
    String? id,
    Offset? position,
    double? width,
    double? height,
    double? rotation,
    Color? fill,
    double? opacity,
    Color? border,
    double? borderWidth,
    BorderKind? borderKind,
    double? borderRadius,
    bool? locked,
    bool? hidden,
    String? layer,
    String? name,
    int? createdAt,
  }) {
    return TgRect(
      id: id ?? this.id,
      position: position ?? this.position,
      width: width ?? this.width,
      height: height ?? this.height,
      rotation: rotation ?? this.rotation,
      fill: fill ?? this.fill,
      opacity: opacity ?? this.opacity,
      border: border ?? this.border,
      borderWidth: borderWidth ?? this.borderWidth,
      borderKind: borderKind ?? this.borderKind,
      borderRadius: borderRadius ?? this.borderRadius,
      locked: locked ?? this.locked,
      hidden: hidden ?? this.hidden,
      layer: layer ?? this.layer,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        "type": "rect",
        ...metaJson(),
        "position": _offToJson(position),
        "width": width,
        "height": height,
        "rotation": rotation,
        "fill": fill.value,
        "opacity": opacity,
        "border": border.value,
        "borderWidth": borderWidth,
        "borderKind": _enumToJson(borderKind),
        "borderRadius": borderRadius,
      };

  factory TgRect.fromJson(Map<String, dynamic> j) {
    return TgRect(
      id: (j["id"] ?? "").toString(),
      position: _offFromJson(j["position"]),
      width: (j["width"] is num) ? (j["width"] as num).toDouble() : 140,
      height: (j["height"] is num) ? (j["height"] as num).toDouble() : 90,
      rotation: (j["rotation"] is num) ? (j["rotation"] as num).toDouble() : 0,
      fill: _colorFromJson(j["fill"], fallback: Colors.transparent),
      opacity: _doubleFromJson(j["opacity"], 1.0).clamp(0.0, 1.0).toDouble(),
      border: _colorFromJson(j["border"], fallback: Colors.black),
      borderWidth: (j["borderWidth"] is num) ? (j["borderWidth"] as num).toDouble() : 2.0,
      borderKind: _enumFromJson(BorderKind.values, j["borderKind"], BorderKind.solid),
      borderRadius: (j["borderRadius"] is num) ? (j["borderRadius"] as num).toDouble() : 0.0,
      locked: j["locked"] == true,
      hidden: j["hidden"] == true,
      layer: (j["layer"] ?? "default").toString(),
      name: j["name"]?.toString(),
      createdAt: _intFromJson(j["createdAt"]),
    );
  }
}

/// =======================
/// CIRCLE
/// =======================
class TgCircle extends TgElement {
  const TgCircle({
    required super.id,
    required this.position,
    required this.radius,
    required this.rotation,
    required this.fill,
    required this.opacity,
    required this.border,
    required this.borderWidth,
    required this.borderKind,
    super.locked,
    super.hidden,
    super.layer,
    super.name,
    super.createdAt,
  });

  final Offset position;
  final double radius;
  final double rotation;
  final Color fill;
  final double opacity;
  final Color border;
  final double borderWidth;
  final BorderKind borderKind;

  @override
  Rect bounds() => Rect.fromCircle(center: position, radius: radius);

  TgCircle copyWith({
    String? id,
    Offset? position,
    double? radius,
    double? rotation,
    Color? fill,
    double? opacity,
    Color? border,
    double? borderWidth,
    BorderKind? borderKind,
    bool? locked,
    bool? hidden,
    String? layer,
    String? name,
    int? createdAt,
  }) {
    return TgCircle(
      id: id ?? this.id,
      position: position ?? this.position,
      radius: radius ?? this.radius,
      rotation: rotation ?? this.rotation,
      fill: fill ?? this.fill,
      opacity: opacity ?? this.opacity,
      border: border ?? this.border,
      borderWidth: borderWidth ?? this.borderWidth,
      borderKind: borderKind ?? this.borderKind,
      locked: locked ?? this.locked,
      hidden: hidden ?? this.hidden,
      layer: layer ?? this.layer,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        "type": "circle",
        ...metaJson(),
        "position": _offToJson(position),
        "radius": radius,
        "rotation": rotation,
        "fill": fill.value,
        "opacity": opacity,
        "border": border.value,
        "borderWidth": borderWidth,
        "borderKind": _enumToJson(borderKind),
      };

  factory TgCircle.fromJson(Map<String, dynamic> j) {
    return TgCircle(
      id: (j["id"] ?? "").toString(),
      position: _offFromJson(j["position"]),
      radius: (j["radius"] is num) ? (j["radius"] as num).toDouble() : 45,
      rotation: (j["rotation"] is num) ? (j["rotation"] as num).toDouble() : 0,
      fill: _colorFromJson(j["fill"], fallback: Colors.transparent),
      opacity: _doubleFromJson(j["opacity"], 1.0).clamp(0.0, 1.0).toDouble(),
      border: _colorFromJson(j["border"], fallback: Colors.black),
      borderWidth: (j["borderWidth"] is num) ? (j["borderWidth"] as num).toDouble() : 2.0,
      borderKind: _enumFromJson(BorderKind.values, j["borderKind"], BorderKind.solid),
      locked: j["locked"] == true,
      hidden: j["hidden"] == true,
      layer: (j["layer"] ?? "default").toString(),
      name: j["name"]?.toString(),
      createdAt: _intFromJson(j["createdAt"]),
    );
  }
}



/// =======================
/// TEXT (FIXED, SINGLE VERSION)
/// =======================
class TgText extends TgElement {
  const TgText({
    required super.id,
    required this.position,
    required this.text,
    required this.size,
    required this.color,
    required this.opacity,
    required this.rotation,
    required this.fontFamily,
    required this.weight,
    required this.alignment,
    required this.style,
    super.locked,
    super.hidden,
    super.layer,
    super.name,
    super.createdAt,
  });

  final Offset position;
  final String text;
  final double size;
  final Color color;
  final double opacity;
  final double rotation;
  final String? fontFamily;
  final FontWeight weight;
  final TextAlign alignment;
  final TgTextStyle style;

  @override
  Rect bounds() {
    // Примерная оценка (достаточно для hitTest/selection)
    final charW = size * 0.6;
    final w = math.max(8.0, text.length * charW);
    final h = math.max(8.0, size * 1.4);
    return Rect.fromCenter(center: position, width: w, height: h);
  }

  @override
  bool hitTest(Offset point, {double tolerance = 0}) {
    return bounds().inflate(tolerance).contains(point);
  }

  TgText copyWith({
    String? id,
    Offset? position,
    String? text,
    double? size,
    Color? color,
    double? opacity,
    double? rotation,
    String? fontFamily,
    FontWeight? weight,
    TextAlign? alignment,
    TgTextStyle? style,
    bool? locked,
    bool? hidden,
    String? layer,
    String? name,
    int? createdAt,
  }) {
    return TgText(
      id: id ?? this.id,
      position: position ?? this.position,
      text: text ?? this.text,
      size: size ?? this.size,
      color: color ?? this.color,
      opacity: opacity ?? this.opacity,
      rotation: rotation ?? this.rotation,
      fontFamily: fontFamily ?? this.fontFamily,
      weight: weight ?? this.weight,
      alignment: alignment ?? this.alignment,
      style: style ?? this.style,
      locked: locked ?? this.locked,
      hidden: hidden ?? this.hidden,
      layer: layer ?? this.layer,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        "type": "text",
        ...metaJson(),
        "position": _offToJson(position),
        "text": text,
        "size": size,
        "color": color.value,
        "opacity": opacity,
        "rotation": rotation,
        "fontFamily": fontFamily,
        "weight": weight.index,
        "alignment": _enumToJson(alignment),
        "style": _enumToJson(style),
      };

  factory TgText.fromJson(Map<String, dynamic> j) {
    final wi = (j["weight"] is num)
        ? (j["weight"] as num).toInt()
        : FontWeight.w700.index;
    final weights = FontWeight.values;
    final w = (wi >= 0 && wi < weights.length) ? weights[wi] : FontWeight.w700;

    return TgText(
      id: (j["id"] ?? "").toString(),
      position: _offFromJson(j["position"]),
      text: (j["text"] ?? "").toString(),
      size: _doubleFromJson(j["size"], 18.0),
      color: _colorFromJson(j["color"], fallback: Colors.black),
      opacity: _doubleFromJson(j["opacity"], 1.0).clamp(0.0, 1.0).toDouble(),
      rotation: _doubleFromJson(j["rotation"], 0.0),
      fontFamily: j["fontFamily"]?.toString(),
      weight: w,
      alignment: _enumFromJson(TextAlign.values, j["alignment"], TextAlign.center),
      style: _enumFromJson(TgTextStyle.values, j["style"], TgTextStyle.normal),
      locked: j["locked"] == true,
      hidden: j["hidden"] == true,
      layer: (j["layer"] ?? "default").toString(),
      name: j["name"]?.toString(),
      createdAt: _intFromJson(j["createdAt"]),
    );
  }
}
/// =======================
/// STAMP
/// =======================
class TgStamp extends TgElement {
  final String asset;
  final Offset pos;
  final double size;
  final double rotation;
  final double opacity;
  final Color? color;
  final PlayerColors? playerColors;

  const TgStamp({
    required super.id,
    required this.asset,
    required this.pos,
    required this.size,
    required this.rotation,
    required this.opacity,
    this.color,
    this.playerColors,
    super.locked,
    super.hidden,
    super.layer,
    super.name,
    super.createdAt,
  });
  
  @override
  Rect bounds() {
    return Rect.fromCenter(
      center: pos,
      width: size,
      height: size,
    );
  }

  @override
  TgStamp copyWith({
    String? id,
    String? asset,
    Offset? pos,
    double? size,
    double? rotation,
    double? opacity,
    Color? color,
    PlayerColors? playerColors,
    bool? locked,
    bool? hidden,
    String? layer,
    String? name,
    int? createdAt,
  }) {
    return TgStamp(
      id: id ?? this.id,
      asset: asset ?? this.asset,
      pos: pos ?? this.pos,
      size: size ?? this.size,
      rotation: rotation ?? this.rotation,
      opacity: opacity ?? this.opacity,
      color: color ?? this.color,
      playerColors: playerColors ?? this.playerColors,
      locked: locked ?? this.locked,
      hidden: hidden ?? this.hidden,
      layer: layer ?? this.layer,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        "type": "stamp",
        ...metaJson(),
        "asset": asset,
        "pos": _offToJson(pos),
        "size": size,
        "rotation": rotation,
        "opacity": opacity,
        if (color != null) "color": color!.value,
        if (playerColors != null) "playerColors": playerColors!.toJson(),
      };

  factory TgStamp.fromJson(Map<String, dynamic> j) {
    return TgStamp(
      id: (j["id"] ?? "").toString(),
      asset: (j["asset"] ?? "").toString(),
      pos: _offFromJson(j["pos"]),
      size: _doubleFromJson(j["size"], 72),
      rotation: _doubleFromJson(j["rotation"], 0.0),
      opacity: _doubleFromJson(j["opacity"], 1.0).clamp(0.0, 1.0).toDouble(),
      color: j.containsKey("color") ? Color(j["color"] as int) : null,
      playerColors: j.containsKey("playerColors") ? PlayerColors.fromJson(j["playerColors"]) : null,
      locked: j["locked"] == true,
      hidden: j["hidden"] == true,
      layer: (j["layer"] ?? "default").toString(),
      name: j["name"]?.toString(),
      createdAt: _intFromJson(j["createdAt"]),
    );
  }
}

/// =======================
/// POLYLINE
/// =======================
class TgPolyline extends TgElement {
  const TgPolyline({
    required super.id,
    required this.points,
    required this.color,
    required this.width,
    required this.kind,
    required this.end,
    required this.arrowSize,
    this.opacity = 1.0,
    this.cap = TgStrokeCap.round,
    this.join = TgStrokeJoin.round,
    this.dash,
    super.locked,
    super.hidden,
    super.layer,
    super.name,
    super.createdAt,
  });

  final List<Offset> points;
  final Color color;
  final double width;
  final LineKind kind;
  final LineEnd end;
  final double arrowSize;
  final double opacity;
  final TgStrokeCap cap;
  final TgStrokeJoin join;
  final List<double>? dash;

  @override
  Rect bounds() {
    if (points.isEmpty) return Rect.zero;
    double minX = points.first.dx, minY = points.first.dy;
    double maxX = points.first.dx, maxY = points.first.dy;
    for (final p in points) {
      minX = math.min(minX, p.dx);
      minY = math.min(minY, p.dy);
      maxX = math.max(maxX, p.dx);
      maxY = math.max(maxY, p.dy);
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY).inflate(width + 12);
  }

  @override
  bool hitTest(Offset p, {double tolerance = 0}) {
    final tol = width + 10 + tolerance;
    if (points.length < 2) return false;

    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      final ap = p - a;
      final ab = b - a;
      final ab2 = ab.dx * ab.dx + ab.dy * ab.dy;
      if (ab2 <= 0.00001) {
        if ((p - a).distance <= tol) return true;
        continue;
      }
      var t = (ap.dx * ab.dx + ap.dy * ab.dy) / ab2;
      t = t.clamp(0.0, 1.0);
      final proj = Offset(a.dx + ab.dx * t, a.dy + ab.dy * t);
      if ((p - proj).distance <= tol) return true;
    }
    return false;
  }

  TgPolyline copyWith({
    List<Offset>? points,
    Color? color,
    double? width,
    LineKind? kind,
    LineEnd? end,
    double? arrowSize,
    double? opacity,
    TgStrokeCap? cap,
    TgStrokeJoin? join,
    List<double>? dash,
    bool dashToNull = false,
    bool? locked,
    bool? hidden,
    String? layer,
    String? name,
  }) {
    return TgPolyline(
      id: id,
      points: points ?? this.points,
      color: color ?? this.color,
      width: width ?? this.width,
      kind: kind ?? this.kind,
      end: end ?? this.end,
      arrowSize: arrowSize ?? this.arrowSize,
      opacity: opacity ?? this.opacity,
      cap: cap ?? this.cap,
      join: join ?? this.join,
      dash: dashToNull ? null : (dash ?? this.dash),
      locked: locked ?? this.locked,
      hidden: hidden ?? this.hidden,
      layer: layer ?? this.layer,
      name: name ?? this.name,
      createdAt: createdAt,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        "type": "polyline",
        ...metaJson(),
        "points": points.map(_offToJson).toList(),
        "color": color.value,
        "width": width,
        "kind": _enumToJson(kind),
        "end": _enumToJson(end),
        "arrowSize": arrowSize,
        "opacity": opacity,
        "cap": _enumToJson(cap),
        "join": _enumToJson(join),
        "dash": dash,
      };

  factory TgPolyline.fromJson(Map<String, dynamic> j) {
    final ptsRaw = (j["points"] is List) ? (j["points"] as List) : const [];
    final pts = <Offset>[];
    for (final x in ptsRaw) {
      pts.add(_offFromJson(x));
    }
    return TgPolyline(
      id: (j["id"] ?? "").toString(),
      points: pts,
      color: _colorFromJson(j["color"], fallback: Colors.black),
      width: _doubleFromJson(j["width"], 4.0),
      kind: _enumFromJson(LineKind.values, j["kind"], LineKind.normal),
      end: _enumFromJson(LineEnd.values, j["end"], LineEnd.none),
      arrowSize: _doubleFromJson(j["arrowSize"], 16.0),
      opacity: _doubleFromJson(j["opacity"], 1.0).clamp(0.0, 1.0).toDouble(),
      cap: _enumFromJson(TgStrokeCap.values, j["cap"], TgStrokeCap.round),
      join: _enumFromJson(TgStrokeJoin.values, j["join"], TgStrokeJoin.round),
      dash: _doubleListFromJson(j["dash"]),
      locked: j["locked"] == true,
      hidden: j["hidden"] == true,
      layer: (j["layer"] ?? "default").toString(),
      name: j["name"]?.toString(),
      createdAt: _intFromJson(j["createdAt"]),
    );
  }
}

/// =======================
/// ZONE
/// =======================
class TgZone extends TgElement {
  const TgZone({
    required super.id,
    required this.points,
    required this.fill,
    required this.opacity,
    required this.border,
    required this.borderWidth,
    required this.borderKind,
    super.locked,
    super.hidden,
    super.layer,
    super.name,
    super.createdAt,
  });

  final List<Offset> points;
  final Color fill;
  final double opacity;
  final Color border;
  final double borderWidth;
  final BorderKind borderKind;

  @override
  Rect bounds() {
    if (points.isEmpty) return Rect.zero;
    double minX = points.first.dx, minY = points.first.dy;
    double maxX = points.first.dx, maxY = points.first.dy;
    for (final p in points) {
      minX = math.min(minX, p.dx);
      minY = math.min(minY, p.dy);
      maxX = math.max(maxX, p.dx);
      maxY = math.max(maxY, p.dy);
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY).inflate(borderWidth + 12);
  }

  @override
  bool hitTest(Offset p, {double tolerance = 0}) {
    if (points.length < 3) return false;
    bool c = false;
    for (int i = 0, j = points.length - 1; i < points.length; j = i++) {
      final pi = points[i];
      final pj = points[j];
      final denom = (pj.dy - pi.dy) == 0 ? 0.00001 : (pj.dy - pi.dy);
      final intersect = ((pi.dy > p.dy) != (pj.dy > p.dy)) &&
          (p.dx < (pj.dx - pi.dx) * (p.dy - pi.dy) / denom + pi.dx);
      if (intersect) c = !c;
    }
    if (c) return true;

    final tol = borderWidth + 10 + tolerance;
    for (var i = 0; i < points.length; i++) {
      final a = points[i];
      final b = points[(i + 1) % points.length];
      final ap = p - a;
      final ab = b - a;
      final ab2 = ab.dx * ab.dx + ab.dy * ab.dy;
      if (ab2 <= 0.00001) continue;
      var t = (ap.dx * ab.dx + ap.dy * ab.dy) / ab2;
      t = t.clamp(0.0, 1.0);
      final proj = Offset(a.dx + ab.dx * t, a.dy + ab.dy * t);
      if ((p - proj).distance <= tol) return true;
    }
    return false;
  }

  TgZone copyWith({
    List<Offset>? points,
    Color? fill,
    double? opacity,
    Color? border,
    double? borderWidth,
    BorderKind? borderKind,
    bool? locked,
    bool? hidden,
    String? layer,
    String? name,
  }) {
    return TgZone(
      id: id,
      points: points ?? this.points,
      fill: fill ?? this.fill,
      opacity: opacity ?? this.opacity,
      border: border ?? this.border,
      borderWidth: borderWidth ?? this.borderWidth,
      borderKind: borderKind ?? this.borderKind,
      locked: locked ?? this.locked,
      hidden: hidden ?? this.hidden,
      layer: layer ?? this.layer,
      name: name ?? this.name,
      createdAt: createdAt,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        "type": "zone",
        ...metaJson(),
        "points": points.map(_offToJson).toList(),
        "fill": fill.value,
        "opacity": opacity,
        "border": border.value,
        "borderWidth": borderWidth,
        "borderKind": _enumToJson(borderKind),
      };

  factory TgZone.fromJson(Map<String, dynamic> j) {
    final ptsRaw = (j["points"] is List) ? (j["points"] as List) : const [];
    final pts = <Offset>[];
    for (final x in ptsRaw) {
      pts.add(_offFromJson(x));
    }
    return TgZone(
      id: (j["id"] ?? "").toString(),
      points: pts,
      fill: _colorFromJson(j["fill"], fallback: Colors.green),
      opacity: _doubleFromJson(j["opacity"], 0.25).clamp(0.0, 1.0).toDouble(),
      border: _colorFromJson(j["border"], fallback: Colors.black),
      borderWidth: _doubleFromJson(j["borderWidth"], 2.0),
      borderKind: _enumFromJson(BorderKind.values, j["borderKind"], BorderKind.solid),
      locked: j["locked"] == true,
      hidden: j["hidden"] == true,
      layer: (j["layer"] ?? "default").toString(),
      name: j["name"]?.toString(),
      createdAt: _intFromJson(j["createdAt"]),
    );
  }
}

/// =======================
/// CURVE
/// =======================
class TgCurve extends TgElement {
  const TgCurve({
    required super.id,
    required this.points,
    required this.color,
    required this.width,
    required this.kind,
    required this.curveType,
    this.opacity = 1.0,
    this.end = LineEnd.none,
    this.arrowSize = 16.0,
    this.cap = TgStrokeCap.round,
    this.join = TgStrokeJoin.round,
    this.dash,
    super.locked,
    super.hidden,
    super.layer,
    super.name,
    super.createdAt,
  });

  final List<Offset> points;
  final Color color;
  final double width;
  final LineKind kind;
  final CurveType curveType;
  final double opacity;
  final LineEnd end;
  final double arrowSize;
  final TgStrokeCap cap;
  final TgStrokeJoin join;
  final List<double>? dash;

  @override
  Rect bounds() {
    if (points.isEmpty) return Rect.zero;
    
    double minX = points.first.dx, minY = points.first.dy;
    double maxX = points.first.dx, maxY = points.first.dy;
    
    for (final p in points) {
      minX = math.min(minX, p.dx);
      minY = math.min(minY, p.dy);
      maxX = math.max(maxX, p.dx);
      maxY = math.max(maxY, p.dy);
    }
    
    final padding = width * 2 + 20;
    return Rect.fromLTRB(minX - padding, minY - padding, maxX + padding, maxY + padding);
  }

  @override
  bool hitTest(Offset p, {double tolerance = 0}) {
    final tol = width + 10 + tolerance;
    
    if (points.length < 2) return false;
    
    if (curveType == CurveType.line) {
      return _hitTestLine(p, points.first, points.last, tol);
    } else if (curveType == CurveType.quadratic && points.length >= 3) {
      return _hitTestQuadratic(p, points[0], points[1], points[2], tol);
    } else if (curveType == CurveType.cubic && points.length >= 4) {
      return _hitTestCubic(p, points[0], points[1], points[2], points[3], tol);
    }
    
    return false;
  }

  bool _hitTestLine(Offset p, Offset a, Offset b, double tol) {
    final ap = p - a;
    final ab = b - a;
    final ab2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (ab2 <= 0.00001) return (p - a).distance <= tol;
    
    var t = (ap.dx * ab.dx + ap.dy * ab.dy) / ab2;
    t = t.clamp(0.0, 1.0);
    final proj = Offset(a.dx + ab.dx * t, a.dy + ab.dy * t);
    return (p - proj).distance <= tol;
  }

  bool _hitTestQuadratic(Offset p, Offset start, Offset control, Offset end, double tol) {
    const steps = 20;
    double minDist = double.infinity;
    
    for (int i = 0; i <= steps; i++) {
      final t = i / steps;
      final point = _quadraticBezier(start, control, end, t);
      final dist = (p - point).distance;
      minDist = math.min(minDist, dist);
    }
    
    return minDist <= tol;
  }

  bool _hitTestCubic(Offset p, Offset start, Offset c1, Offset c2, Offset end, double tol) {
    const steps = 30;
    double minDist = double.infinity;
    
    for (int i = 0; i <= steps; i++) {
      final t = i / steps;
      final point = _cubicBezier(start, c1, c2, end, t);
      final dist = (p - point).distance;
      minDist = math.min(minDist, dist);
    }
    
    return minDist <= tol;
  }

  Offset _quadraticBezier(Offset start, Offset control, Offset end, double t) {
    final mt = 1 - t;
    return Offset(
      mt * mt * start.dx + 2 * mt * t * control.dx + t * t * end.dx,
      mt * mt * start.dy + 2 * mt * t * control.dy + t * t * end.dy,
    );
  }

  Offset _cubicBezier(Offset start, Offset c1, Offset c2, Offset end, double t) {
    final mt = 1 - t;
    return Offset(
      mt * mt * mt * start.dx + 
      3 * mt * mt * t * c1.dx + 
      3 * mt * t * t * c2.dx + 
      t * t * t * end.dx,
      mt * mt * mt * start.dy + 
      3 * mt * mt * t * c1.dy + 
      3 * mt * t * t * c2.dy + 
      t * t * t * end.dy,
    );
  }

  Offset pointAt(double t) {
    if (points.isEmpty) return Offset.zero;
    
    if (curveType == CurveType.line) {
      return Offset.lerp(points.first, points.last, t) ?? points.first;
    } else if (curveType == CurveType.quadratic && points.length >= 3) {
      return _quadraticBezier(points[0], points[1], points[2], t);
    } else if (curveType == CurveType.cubic && points.length >= 4) {
      return _cubicBezier(points[0], points[1], points[2], points[3], t);
    }
    
    return points.first;
  }

  TgCurve copyWith({
    String? id,
    List<Offset>? points,
    Color? color,
    double? width,
    LineKind? kind,
    CurveType? curveType,
    double? opacity,
    LineEnd? end,
    double? arrowSize,
    TgStrokeCap? cap,
    TgStrokeJoin? join,
    List<double>? dash,
    bool dashToNull = false,
    bool? locked,
    bool? hidden,
    String? layer,
    String? name,
    int? createdAt,
  }) {
    return TgCurve(
      id: id ?? this.id,
      points: points ?? this.points,
      color: color ?? this.color,
      width: width ?? this.width,
      kind: kind ?? this.kind,
      curveType: curveType ?? this.curveType,
      opacity: opacity ?? this.opacity,
      end: end ?? this.end,
      arrowSize: arrowSize ?? this.arrowSize,
      cap: cap ?? this.cap,
      join: join ?? this.join,
      dash: dashToNull ? null : (dash ?? this.dash),
      locked: locked ?? this.locked,
      hidden: hidden ?? this.hidden,
      layer: layer ?? this.layer,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        "type": "curve",
        ...metaJson(),
        "points": points.map(_offToJson).toList(),
        "color": color.value,
        "width": width,
        "kind": _enumToJson(kind),
        "curveType": _enumToJson(curveType),
        "opacity": opacity,
        "end": _enumToJson(end),
        "arrowSize": arrowSize,
        "cap": _enumToJson(cap),
        "join": _enumToJson(join),
        "dash": dash,
      };

  factory TgCurve.fromJson(Map<String, dynamic> j) {
    final ptsRaw = (j["points"] is List) ? (j["points"] as List) : const [];
    final pts = <Offset>[];
    for (final x in ptsRaw) {
      pts.add(_offFromJson(x));
    }
    
    return TgCurve(
      id: (j["id"] ?? "").toString(),
      points: pts,
      color: _colorFromJson(j["color"], fallback: Colors.white),
      width: _doubleFromJson(j["width"], 4.0),
      kind: _enumFromJson(LineKind.values, j["kind"], LineKind.normal),
      curveType: _enumFromJson(CurveType.values, j["curveType"], CurveType.line),
      opacity: _doubleFromJson(j["opacity"], 1.0).clamp(0.0, 1.0).toDouble(),
      end: _enumFromJson(LineEnd.values, j["end"], LineEnd.none),
      arrowSize: _doubleFromJson(j["arrowSize"], 16.0),
      cap: _enumFromJson(TgStrokeCap.values, j["cap"], TgStrokeCap.round),
      join: _enumFromJson(TgStrokeJoin.values, j["join"], TgStrokeJoin.round),
      dash: _doubleListFromJson(j["dash"]),
      locked: j["locked"] == true,
      hidden: j["hidden"] == true,
      layer: (j["layer"] ?? "default").toString(),
      name: j["name"]?.toString(),
      createdAt: _intFromJson(j["createdAt"]),
    );
  }
}

/// =======================
/// EDITABLE CURVE
/// =======================
class TgEditableCurve extends TgCurve {
  const TgEditableCurve({
    required super.id,
    required super.points,
    required super.color,
    required super.width,
    required super.kind,
    required super.curveType,
    super.opacity,
    super.end,
    super.arrowSize,
    super.cap,
    super.join,
    super.dash,
    super.locked,
    super.hidden,
    super.layer,
    super.name,
    super.createdAt,
    this.selectedPointIndex = -1,
    this.showControlPoints = true,
  });

  final int selectedPointIndex;
  final bool showControlPoints;

  @override
  TgEditableCurve copyWith({
    String? id,
    List<Offset>? points,
    Color? color,
    double? width,
    LineKind? kind,
    CurveType? curveType,
    double? opacity,
    LineEnd? end,
    double? arrowSize,
    TgStrokeCap? cap,
    TgStrokeJoin? join,
    List<double>? dash,
    bool dashToNull = false,
    bool? locked,
    bool? hidden,
    String? layer,
    String? name,
    int? createdAt,
    int? selectedPointIndex,
    bool? showControlPoints,
  }) {
    return TgEditableCurve(
      id: id ?? this.id,
      points: points ?? this.points,
      color: color ?? this.color,
      width: width ?? this.width,
      kind: kind ?? this.kind,
      curveType: curveType ?? this.curveType,
      opacity: opacity ?? this.opacity,
      end: end ?? this.end,
      arrowSize: arrowSize ?? this.arrowSize,
      cap: cap ?? this.cap,
      join: join ?? this.join,
      dash: dashToNull ? null : (dash ?? this.dash),
      locked: locked ?? this.locked,
      hidden: hidden ?? this.hidden,
      layer: layer ?? this.layer,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      selectedPointIndex: selectedPointIndex ?? this.selectedPointIndex,
      showControlPoints: showControlPoints ?? this.showControlPoints,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        "type": "editable_curve",
        "selectedPointIndex": selectedPointIndex,
        "showControlPoints": showControlPoints,
      };

  factory TgEditableCurve.fromJson(Map<String, dynamic> j) {
    final base = TgCurve.fromJson(j);
    return TgEditableCurve(
      id: base.id,
      points: base.points,
      color: base.color,
      width: base.width,
      kind: base.kind,
      curveType: base.curveType,
      opacity: base.opacity,
      end: base.end,
      arrowSize: base.arrowSize,
      cap: base.cap,
      join: base.join,
      dash: base.dash,
      locked: base.locked,
      hidden: base.hidden,
      layer: base.layer,
      name: base.name,
      createdAt: base.createdAt,
      selectedPointIndex: (j["selectedPointIndex"] as num?)?.toInt() ?? -1,
      showControlPoints: j["showControlPoints"] == true,
    );
  }
}

/// =======================
/// GROUP
/// =======================
class TgGroup extends TgElement {
  const TgGroup({
    required super.id,
    required this.childrenIds,
    super.locked,
    super.hidden,
    super.layer,
    super.name,
    super.createdAt,
  });

  final List<String> childrenIds;

  @override
  Rect bounds() => Rect.zero;

  TgGroup copyWith({
    List<String>? childrenIds,
    bool? locked,
    bool? hidden,
    String? layer,
    String? name,
  }) {
    return TgGroup(
      id: id,
      childrenIds: childrenIds ?? this.childrenIds,
      locked: locked ?? this.locked,
      hidden: hidden ?? this.hidden,
      layer: layer ?? this.layer,
      name: name ?? this.name,
      createdAt: createdAt,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        "type": "group",
        ...metaJson(),
        "childrenIds": childrenIds,
      };

  factory TgGroup.fromJson(Map<String, dynamic> j) {
    final raw = (j["childrenIds"] is List) ? (j["childrenIds"] as List) : const [];
    return TgGroup(
      id: (j["id"] ?? "").toString(),
      childrenIds: raw.map((e) => e.toString()).toList(),
      locked: j["locked"] == true,
      hidden: j["hidden"] == true,
      layer: (j["layer"] ?? "default").toString(),
      name: j["name"]?.toString(),
      createdAt: _intFromJson(j["createdAt"]),
    );
  }
}

/// =======================
/// SPRING (ПРУЖИНКА)
/// =======================
class TgSpring extends TgElement {
  const TgSpring({
    required super.id,
    required this.start,
    required this.endPoint,
    required this.color,
    required this.width,
    required this.kind,
    this.opacity = 1.0,
    this.amplitude = 30.0,
    this.frequency = 8.0,
    this.phase = 0.0,
    this.lineEnd = LineEnd.none,
    this.arrowSize = 16.0,
    super.locked,
    super.hidden,
    super.layer,
    super.name,
    super.createdAt,
  });

  final Offset start;
  final Offset endPoint;
  final Color color;
  final double width;
  final LineKind kind;
  final double opacity;
  final double amplitude;
  final double frequency;
  final double phase;
  final LineEnd lineEnd;
  final double arrowSize;

  @override
  Rect bounds() {
    final left = math.min(start.dx, endPoint.dx);
    final top = math.min(start.dy, endPoint.dy);
    final right = math.max(start.dx, endPoint.dx);
    final bottom = math.max(start.dy, endPoint.dy);
    return Rect.fromLTRB(left, top, right, bottom)
        .inflate(amplitude + width + 30);
  }

  @override
  bool hitTest(Offset p, {double tolerance = 0}) {
    final tol = width + 20 + tolerance;
    if (!bounds().contains(p)) return false;
    
    final points = _generateSpringPoints(40);
    
    for (int i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      
      final ab = b - a;
      final ap = p - a;
      final ab2 = ab.dx * ab.dx + ab.dy * ab.dy;
      
      if (ab2 > 0) {
        double t = (ap.dx * ab.dx + ap.dy * ab.dy) / ab2;
        t = t.clamp(0.0, 1.0);
        final proj = a + ab * t;
        final dist = (p - proj).distance;
        if (dist <= tol) return true;
      }
    }
    return false;
  }

  List<Offset> _generateSpringPoints([int segments = 150]) {
    final points = <Offset>[];
    final dir = endPoint - start;
    final length = dir.distance;
    if (length < 1) return points;
    
    final unitDir = dir / length;
    final perp = Offset(-unitDir.dy, unitDir.dx);
    
    for (int i = 0; i <= segments; i++) {
      final t = i / segments;
      final basePos = start + dir * t;
      
      final angle = t * frequency * 2 * math.pi + phase;
      final r = amplitude * (1 - 0.5 * t); // Затухание к концу
      
      final offset = perp * (math.sin(angle) * r);
      points.add(basePos + offset);
    }
    
    return points;
  }

  Path getPath() {
    final path = Path();
    final points = _generateSpringPoints(150);
    
    if (points.isNotEmpty) {
      path.moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
    }
    return path;
  }

  TgSpring copyWith({
    String? id,
    Offset? start,
    Offset? endPoint,
    Color? color,
    double? width,
    LineKind? kind,
    double? opacity,
    double? amplitude,
    double? frequency,
    double? phase,
    LineEnd? lineEnd,
    double? arrowSize,
    bool? locked,
    bool? hidden,
    String? layer,
    String? name,
    int? createdAt,
  }) {
    return TgSpring(
      id: id ?? this.id,
      start: start ?? this.start,
      endPoint: endPoint ?? this.endPoint,
      color: color ?? this.color,
      width: width ?? this.width,
      kind: kind ?? this.kind,
      opacity: opacity ?? this.opacity,
      amplitude: amplitude ?? this.amplitude,
      frequency: frequency ?? this.frequency,
      phase: phase ?? this.phase,
      lineEnd: lineEnd ?? this.lineEnd,
      arrowSize: arrowSize ?? this.arrowSize,
      locked: locked ?? this.locked,
      hidden: hidden ?? this.hidden,
      layer: layer ?? this.layer,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        "type": "spring",
        ...metaJson(),
        "start": _offToJson(start),
        "endPoint": _offToJson(endPoint),
        "color": color.value,
        "width": width,
        "kind": _enumToJson(kind),
        "opacity": opacity,
        "amplitude": amplitude,
        "frequency": frequency,
        "phase": phase,
        "lineEnd": _enumToJson(lineEnd),
        "arrowSize": arrowSize,
      };

  factory TgSpring.fromJson(Map<String, dynamic> j) {
    return TgSpring(
      id: (j["id"] ?? "").toString(),
      start: _offFromJson(j["start"]),
      endPoint: _offFromJson(j["endPoint"]),
      color: _colorFromJson(j["color"], fallback: Colors.black),
      width: _doubleFromJson(j["width"], 4.0),
      kind: _enumFromJson(LineKind.values, j["kind"], LineKind.normal),
      opacity: _doubleFromJson(j["opacity"], 1.0).clamp(0.0, 1.0).toDouble(),
      amplitude: _doubleFromJson(j["amplitude"], 30.0),
      frequency: _doubleFromJson(j["frequency"], 8.0),
      phase: _doubleFromJson(j["phase"], 0.0),
      lineEnd: _enumFromJson(LineEnd.values, j["lineEnd"], LineEnd.none),
      arrowSize: _doubleFromJson(j["arrowSize"], 16.0),
      locked: j["locked"] == true,
      hidden: j["hidden"] == true,
      layer: (j["layer"] ?? "default").toString(),
      name: j["name"]?.toString(),
      createdAt: _intFromJson(j["createdAt"]),
    );
  }
}


/// =======================
/// WAVY (ВОЛНИСТАЯ ЛИНИЯ С КОНТРОЛЬНЫМИ ТОЧКАМИ)
/// =======================
class TgWavy extends TgElement {
  const TgWavy({
    required super.id,
    required this.start,
    required this.endPoint,
    required this.controlPoints,
    required this.color,
    required this.width,
    required this.kind,
    this.opacity = 1.0,
    this.amplitude = 15.0,
    this.wavelength = 25.0,
    this.phase = 0.0,
    this.lineEnd = LineEnd.none,
    this.arrowSize = 16.0,
    this.cap = TgStrokeCap.round,
    this.join = TgStrokeJoin.round,
    this.dash,
    super.locked,
    super.hidden,
    super.layer,
    super.name,
    super.createdAt,
  });



  final Offset start;
  final Offset endPoint;
  final List<Offset> controlPoints;
  final Color color;
  final double width;
  final LineKind kind;
  final double opacity;
  final double amplitude;
  final double wavelength;
  final double phase;
  final LineEnd lineEnd;
  final double arrowSize;
  final TgStrokeCap cap;
  final TgStrokeJoin join;
  final List<double>? dash;

  @override
  Rect bounds() {
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = -double.infinity;
    double maxY = -double.infinity;
    
    // Учитываем все точки
    final allPoints = [start, ...controlPoints, endPoint];
    for (final p in allPoints) {
      minX = math.min(minX, p.dx);
      minY = math.min(minY, p.dy);
      maxX = math.max(maxX, p.dx);
      maxY = math.max(maxY, p.dy);
    }
    
    // Добавляем запас на амплитуду волны
    final padding = amplitude + width + 40;
    return Rect.fromLTRB(
      minX - padding,
      minY - padding,
      maxX + padding,
      maxY + padding,
    );
  }

  // Генерирует опорные точки для кривой Безье с учетом контрольных точек
  List<Offset> _generateBasePoints([int _unused = 20]) {
  final pts = <Offset>[start, ...controlPoints, endPoint];
  if (pts.length < 2) return pts;

  final approxLen = _polyLen(pts);
  final seg = (approxLen / 40).round().clamp(12, 30);

  final smooth = <Offset>[];
  for (int i = 0; i < pts.length - 1; i++) {
    final p0 = i > 0 ? pts[i - 1] : pts[i];
    final p1 = pts[i];
    final p2 = pts[i + 1];
    final p3 = i < pts.length - 2 ? pts[i + 2] : pts[i + 1];

    for (int j = 0; j <= seg; j++) {
      final t = j / seg;
      smooth.add(_catmullRomSpline(p0, p1, p2, p3, t));
    }
  }
  return smooth;
}

double _polyLen(List<Offset> p) {
  double s = 0;
  for (int i = 0; i < p.length - 1; i++) {
    s += (p[i + 1] - p[i]).distance;
  }
  return s;
}

Path _smoothPathFromPoints(List<Offset> pts) {
  final path = Path();
  if (pts.isEmpty) return path;
  if (pts.length == 1) {
    path.addOval(Rect.fromCircle(center: pts.first, radius: width / 2));
    return path;
  }

  path.moveTo(pts.first.dx, pts.first.dy);

  // smooth through midpoints
  for (int i = 1; i < pts.length - 1; i++) {
    final p1 = pts[i];
    final p2 = pts[i + 1];
    final mid = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
    path.quadraticBezierTo(p1.dx, p1.dy, mid.dx, mid.dy);
  }

  path.lineTo(pts.last.dx, pts.last.dy);
  return path;
}


  // Catmull-Rom сплайн для плавного прохождения через все точки
  Offset _catmullRomSpline(Offset p0, Offset p1, Offset p2, Offset p3, double t) {
    final t2 = t * t;
    final t3 = t2 * t;
    
    return Offset(
      0.5 * ((-p0.dx + 3 * p1.dx - 3 * p2.dx + p3.dx) * t3 +
             (2 * p0.dx - 5 * p1.dx + 4 * p2.dx - p3.dx) * t2 +
             (-p0.dx + p2.dx) * t +
             2 * p1.dx),
      0.5 * ((-p0.dy + 3 * p1.dy - 3 * p2.dy + p3.dy) * t3 +
             (2 * p0.dy - 5 * p1.dy + 4 * p2.dy - p3.dy) * t2 +
             (-p0.dy + p2.dy) * t +
             2 * p1.dy)
    );
  }

  // Получает направление в точке t вдоль кривой
  Offset _getDirectionAt(List<Offset> basePoints, double t) {
    if (basePoints.length < 2) return const Offset(1, 0);
    
    final index = (t * (basePoints.length - 1)).floor();
    if (index >= basePoints.length - 1) {
      return basePoints.last - basePoints[basePoints.length - 2];
    }
    return basePoints[index + 1] - basePoints[index];
  }

  List<Offset> _generateWavyPoints([int segments = 140]) {
    final basePoints = _generateBasePoints(20);
    if (basePoints.length < 2) return [];
    
    final wavyPoints = <Offset>[];
    final totalLength = _calculatePathLength(basePoints);
    if (totalLength < 1) return basePoints;
    
    // Генерируем точки вдоль базовой кривой
    for (int i = 0; i <= segments; i++) {
      final t = i / segments;
      
      // Находим позицию на базовой кривой
      final basePos = _getPointAt(basePoints, t);
      
      // Находим направление в этой точке
      final dir = _getDirectionAt(basePoints, t);
      if (dir.distance < 0.001) {
        wavyPoints.add(basePos);
        continue;
      }
      
      // Нормализуем и получаем перпендикуляр
      final unitDir = dir / dir.distance;
      final perp = Offset(-unitDir.dy, unitDir.dx);
      
      // Вычисляем смещение волны
      final distance = t * totalLength;
      final ang = (distance / wavelength) * 2 * math.pi + phase;
      final offset = perp * (math.sin(ang) * amplitude);
      
      wavyPoints.add(basePos + offset);
    }
    
    return wavyPoints;
  }

  // Вычисляет длину пути
  double _calculatePathLength(List<Offset> points) {
    double length = 0;
    for (int i = 0; i < points.length - 1; i++) {
      length += (points[i + 1] - points[i]).distance;
    }
    return length;
  }

  // Получает точку на кривой в параметрической позиции t (0-1)
  Offset _getPointAt(List<Offset> points, double t) {
    if (points.length < 2) return points.first;
    
    final totalLength = _calculatePathLength(points);
    final targetDist = t * totalLength;
    
    double accumulated = 0;
    for (int i = 0; i < points.length - 1; i++) {
      final segmentLength = (points[i + 1] - points[i]).distance;
      if (accumulated + segmentLength >= targetDist) {
        final segmentT = (targetDist - accumulated) / segmentLength;
        return Offset.lerp(points[i], points[i + 1], segmentT)!;
      }
      accumulated += segmentLength;
    }
    
    return points.last;
  }

  Path getPath() {
  final pts = _generateBasePoints();
  return _smoothPathFromPoints(pts);
}

  @override
bool hitTest(Offset p, {double tolerance = 0}) {
  if (!bounds().contains(p)) return false;

  final tol = width + 18 + tolerance;
  final path = getPath();

  for (final m in path.computeMetrics()) {
    final len = m.length;
    if (len <= 0.001) continue;

    // частота проверки зависит от длины
    final step = (tol * 0.8).clamp(2.0, 12.0);
    for (double d = 0; d <= len; d += step) {
      final tan = m.getTangentForOffset(d);
      if (tan == null) continue;
      if ((p - tan.position).distance <= tol) return true;
    }
  }
  return false;
}
  TgWavy copyWith({
    String? id,
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
    bool dashToNull = false,
    bool? locked,
    bool? hidden,
    String? layer,
    String? name,
    int? createdAt,
  }) {
    return TgWavy(
      id: id ?? this.id,
      start: start ?? this.start,
      endPoint: endPoint ?? this.endPoint,
      controlPoints: controlPoints ?? this.controlPoints,
      color: color ?? this.color,
      width: width ?? this.width,
      kind: kind ?? this.kind,
      opacity: opacity ?? this.opacity,
      amplitude: amplitude ?? this.amplitude,
      wavelength: wavelength ?? this.wavelength,
      phase: phase ?? this.phase,
      lineEnd: lineEnd ?? this.lineEnd,
      arrowSize: arrowSize ?? this.arrowSize,
      cap: cap ?? this.cap,
      join: join ?? this.join,
      dash: dashToNull ? null : (dash ?? this.dash),
      locked: locked ?? this.locked,
      hidden: hidden ?? this.hidden,
      layer: layer ?? this.layer,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        "type": "wavy",
        ...metaJson(),
        "start": _offToJson(start),
        "endPoint": _offToJson(endPoint),
        "controlPoints": controlPoints.map(_offToJson).toList(),
        "color": color.value,
        "width": width,
        "kind": _enumToJson(kind),
        "opacity": opacity,
        "amplitude": amplitude,
        "wavelength": wavelength,
        "phase": phase,
        "lineEnd": _enumToJson(lineEnd),
        "arrowSize": arrowSize,
        "cap": _enumToJson(cap),
        "join": _enumToJson(join),
        "dash": dash,
      };

  factory TgWavy.fromJson(Map<String, dynamic> j) {
    final controlPtsRaw = (j["controlPoints"] is List) ? (j["controlPoints"] as List) : [];
    final controlPts = <Offset>[];
    for (final x in controlPtsRaw) {
      controlPts.add(_offFromJson(x));
    }
    
    return TgWavy(
      id: (j["id"] ?? "").toString(),
      start: _offFromJson(j["start"]),
      endPoint: _offFromJson(j["endPoint"]),
      controlPoints: controlPts,
      color: _colorFromJson(j["color"], fallback: Colors.black),
      width: _doubleFromJson(j["width"], 4.0),
      kind: _enumFromJson(LineKind.values, j["kind"], LineKind.wavy),
      opacity: _doubleFromJson(j["opacity"], 1.0).clamp(0.0, 1.0).toDouble(),
      amplitude: _doubleFromJson(j["amplitude"], 15.0),
      wavelength: _doubleFromJson(j["wavelength"], 25.0),
      phase: _doubleFromJson(j["phase"], 0.0),
      lineEnd: _enumFromJson(LineEnd.values, j["lineEnd"], LineEnd.none),
      arrowSize: _doubleFromJson(j["arrowSize"], 16.0),
      cap: _enumFromJson(TgStrokeCap.values, j["cap"], TgStrokeCap.round),
      join: _enumFromJson(TgStrokeJoin.values, j["join"], TgStrokeJoin.round),
      dash: _doubleListFromJson(j["dash"]),
      locked: j["locked"] == true,
      hidden: j["hidden"] == true,
      layer: (j["layer"] ?? "default").toString(),
      name: j["name"]?.toString(),
      createdAt: _intFromJson(j["createdAt"]),
    );
  }
}

/// =======================
/// РЕДАКТИРУЕМАЯ ВОЛНИСТАЯ ЛИНИЯ
/// =======================
class TgEditableWavy extends TgWavy {
  const TgEditableWavy({
    required super.id,
    required super.start,
    required super.endPoint,
    required super.controlPoints,
    required super.color,
    required super.width,
    required super.kind,
    super.opacity,
    super.amplitude,
    super.wavelength,
    super.phase,
    super.lineEnd,
    super.arrowSize,
    super.cap,
    super.join,
    super.dash,
    super.locked,
    super.hidden,
    super.layer,
    super.name,
    super.createdAt,
    this.selectedPointIndex = -1,
    this.showControlPoints = false,
  });

  final int selectedPointIndex;
  final bool showControlPoints;

  @override
  TgEditableWavy copyWith({
    String? id,
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
    bool dashToNull = false,
    bool? locked,
    bool? hidden,
    String? layer,
    String? name,
    int? createdAt,
    int? selectedPointIndex,
    bool? showControlPoints,
  }) {
    return TgEditableWavy(
      id: id ?? this.id,
      start: start ?? this.start,
      endPoint: endPoint ?? this.endPoint,
      controlPoints: controlPoints ?? this.controlPoints,
      color: color ?? this.color,
      width: width ?? this.width,
      kind: kind ?? this.kind,
      opacity: opacity ?? this.opacity,
      amplitude: amplitude ?? this.amplitude,
      wavelength: wavelength ?? this.wavelength,
      phase: phase ?? this.phase,
      lineEnd: lineEnd ?? this.lineEnd,
      arrowSize: arrowSize ?? this.arrowSize,
      cap: cap ?? this.cap,
      join: join ?? this.join,
      dash: dashToNull ? null : (dash ?? this.dash),
      locked: locked ?? this.locked,
      hidden: hidden ?? this.hidden,
      layer: layer ?? this.layer,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      selectedPointIndex: selectedPointIndex ?? this.selectedPointIndex,
      showControlPoints: showControlPoints ?? this.showControlPoints,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        "type": "editable_wavy",
        "selectedPointIndex": selectedPointIndex,
        "showControlPoints": showControlPoints,
      };

  factory TgEditableWavy.fromJson(Map<String, dynamic> j) {
    final base = TgWavy.fromJson(j);
    return TgEditableWavy(
      id: base.id,
      start: base.start,
      endPoint: base.endPoint,
      controlPoints: base.controlPoints,
      color: base.color,
      width: base.width,
      kind: base.kind,
      opacity: base.opacity,
      amplitude: base.amplitude,
      wavelength: base.wavelength,
      phase: base.phase,
      lineEnd: base.lineEnd,
      arrowSize: base.arrowSize,
      cap: base.cap,
      join: base.join,
      dash: base.dash,
      locked: base.locked,
      hidden: base.hidden,
      layer: base.layer,
      name: base.name,
      createdAt: base.createdAt,
      selectedPointIndex: (j["selectedPointIndex"] as num?)?.toInt() ?? -1,
      showControlPoints: j["showControlPoints"] == true,
    );
  }
}

/// =======================
/// РЕДАКТИРУЕМАЯ ПРУЖИНКА (ИСПРАВЛЕННАЯ)
/// =======================
class TgEditableSpring extends TgSpring {
  const TgEditableSpring({
    required super.id,
    required super.start,
    required super.endPoint,
    required super.color,
    required super.width,
    required super.kind,
    super.opacity,
    super.amplitude,
    super.frequency,
    super.phase,
    super.lineEnd,
    super.arrowSize,
    super.locked,
    super.hidden,
    super.layer,
    super.name,
    super.createdAt,
    this.selectedPointIndex = -1,
    this.showControlPoints = false,
    this.controlPoints = const [], // Оставляем const [] для const конструктора
  });

  final int selectedPointIndex;
  final bool showControlPoints;
  final List<Offset> controlPoints;

  @override
  TgEditableSpring copyWith({
    String? id,
    Offset? start,
    Offset? endPoint,
    Color? color,
    double? width,
    LineKind? kind,
    double? opacity,
    double? amplitude,
    double? frequency,
    double? phase,
    LineEnd? lineEnd,
    double? arrowSize,
    bool? locked,
    bool? hidden,
    String? layer,
    String? name,
    int? createdAt,
    int? selectedPointIndex,
    bool? showControlPoints,
    List<Offset>? controlPoints,
  }) {
    return TgEditableSpring(
      id: id ?? this.id,
      start: start ?? this.start,
      endPoint: endPoint ?? this.endPoint,
      color: color ?? this.color,
      width: width ?? this.width,
      kind: kind ?? this.kind,
      opacity: opacity ?? this.opacity,
      amplitude: amplitude ?? this.amplitude,
      frequency: frequency ?? this.frequency,
      phase: phase ?? this.phase,
      lineEnd: lineEnd ?? this.lineEnd,
      arrowSize: arrowSize ?? this.arrowSize,
      locked: locked ?? this.locked,
      hidden: hidden ?? this.hidden,
      layer: layer ?? this.layer,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      selectedPointIndex: selectedPointIndex ?? this.selectedPointIndex,
      showControlPoints: showControlPoints ?? this.showControlPoints,
      controlPoints: controlPoints ?? this.controlPoints,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        "type": "editable_spring",
        "selectedPointIndex": selectedPointIndex,
        "showControlPoints": showControlPoints,
        "controlPoints": controlPoints.map(_offToJson).toList(),
      };

  factory TgEditableSpring.fromJson(Map<String, dynamic> j) {
    final base = TgSpring.fromJson(j);
    final ptsRaw = (j["controlPoints"] is List) ? (j["controlPoints"] as List) : [];
    final pts = <Offset>[]; // Здесь создаём изменяемый список
    for (final x in ptsRaw) {
      pts.add(_offFromJson(x));
    }
    
    return TgEditableSpring(
      id: base.id,
      start: base.start,
      endPoint: base.endPoint,
      color: base.color,
      width: base.width,
      kind: base.kind,
      opacity: base.opacity,
      amplitude: base.amplitude,
      frequency: base.frequency,
      phase: base.phase,
      lineEnd: base.lineEnd,
      arrowSize: base.arrowSize,
      locked: base.locked,
      hidden: base.hidden,
      layer: base.layer,
      name: base.name,
      createdAt: base.createdAt,
      selectedPointIndex: (j["selectedPointIndex"] as num?)?.toInt() ?? -1,
      showControlPoints: j["showControlPoints"] == true,
      controlPoints: pts, // Передаём изменяемый список
    );
  }
  
  // Метод для обновления позиции контрольной точки
  TgEditableSpring updateControlPoint(int index, Offset newPos) {
    // Создаём НОВЫЙ список, а не модифицируем старый
    final newControlPoints = List<Offset>.from(controlPoints);
    if (index >= 0 && index < newControlPoints.length) {
      newControlPoints[index] = newPos;
      
      // Если это первая или последняя точка, обновляем start/endPoint
      Offset newStart = start;
      Offset newEnd = endPoint;
      
      if (index == 0) {
        newStart = newPos;
      } else if (index == newControlPoints.length - 1) {
        newEnd = newPos;
      }
      
      return copyWith(
        start: newStart,
        endPoint: newEnd,
        controlPoints: newControlPoints,
        selectedPointIndex: index,
      );
    }
    return this;
  }
  
  // Переопределяем getPath для использования контрольных точек при редактировании
  @override
Path getPath() {
  // Если есть контрольные точки И мы в режиме редактирования - используем их
  if (showControlPoints && controlPoints.isNotEmpty) {
    final path = Path();
    path.moveTo(controlPoints.first.dx, controlPoints.first.dy);
    for (int i = 1; i < controlPoints.length; i++) {
      path.lineTo(controlPoints[i].dx, controlPoints[i].dy);
    }
    return path;
  }
  // Иначе используем стандартную генерацию из параметров
  return super.getPath();
}
}    

/// =======================
/// SPIRAL
/// =======================
class TgSpiral extends TgElement {
  const TgSpiral({
    required super.id,
    required this.start,
    required this.endPoint,
    required this.color,
    required this.width,
    required this.kind,
    this.opacity = 1.0,
    this.amplitude = 10.0,
    this.turns = 14.0,
    this.phase = 0.0,
    this.fadeEdge = 0.12,
    this.grow = 0.0,
    this.lineEnd = LineEnd.none,
    this.arrowSize = 16.0,
    super.locked,
    super.hidden,
    super.layer,
    super.name,
    super.createdAt,
  });

  final Offset start;
  final Offset endPoint;
  final Color color;
  final double width;
  final LineKind kind;
  final double opacity;
  final double amplitude;
  final double turns;
  final double phase;
  final double fadeEdge;
  final double grow;
  final LineEnd lineEnd;
  final double arrowSize;

  @override
  Rect bounds() {
    final left = math.min(start.dx, endPoint.dx);
    final top = math.min(start.dy, endPoint.dy);
    final right = math.max(start.dx, endPoint.dx);
    final bottom = math.max(start.dy, endPoint.dy);
    return Rect.fromLTRB(left, top, right, bottom).inflate(amplitude + width + 40);
  }

  @override
  bool hitTest(Offset p, {double tolerance = 0}) {
    if (!bounds().contains(p)) return false;
    final tol = width + 18 + tolerance;
    final pts = _generateSpiralPoints(180);

    for (int i = 0; i < pts.length - 1; i++) {
      final a = pts[i];
      final b = pts[i + 1];
      final ab = b - a;
      final ap = p - a;
      final ab2 = ab.dx * ab.dx + ab.dy * ab.dy;
      if (ab2 > 0.000001) {
        double t = (ap.dx * ab.dx + ap.dy * ab.dy) / ab2;
        t = t.clamp(0.0, 1.0);
        final proj = a + ab * t;
        if ((p - proj).distance <= tol) return true;
      }
    }
    return false;
  }

  List<Offset> _generateSpiralPoints([int segments = 180]) {
    final points = <Offset>[];
    final dir = endPoint - start;
    final length = dir.distance;
    if (length < 1) return points;

    final unit = dir / length;
    final perp = Offset(-unit.dy, unit.dx);
    final fe = fadeEdge.clamp(0.0, 0.49).toDouble();

    for (int i = 0; i <= segments; i++) {
      final t = i / segments;
      final basePos = start + dir * t;
      final angle = (t * turns * 2.0 * math.pi) + phase;
      final r = amplitude * (1.0 + grow * t);

      double fade = 1.0;
      if (fe > 0) {
        final fs = (t < fe) ? (t / fe) : 1.0;
        final fe2 = (t > (1.0 - fe)) ? ((1.0 - t) / fe) : 1.0;
        fade = math.min(fs, fe2).clamp(0.0, 1.0);
      }

      final offset = perp * (math.sin(angle) * r * fade);
      points.add(basePos + offset);
    }
    return points;
  }

  Path getPath() {
    final path = Path();
    final pts = _generateSpiralPoints(180);
    if (pts.isEmpty) return path;
    path.moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    return path;
  }

  TgSpiral copyWith({
    String? id,
    Offset? start,
    Offset? endPoint,
    Color? color,
    double? width,
    LineKind? kind,
    double? opacity,
    double? amplitude,
    double? turns,
    double? phase,
    double? fadeEdge,
    double? grow,
    LineEnd? lineEnd,
    double? arrowSize,
    bool? locked,
    bool? hidden,
    String? layer,
    String? name,
    int? createdAt,
  }) {
    return TgSpiral(
      id: id ?? this.id,
      start: start ?? this.start,
      endPoint: endPoint ?? this.endPoint,
      color: color ?? this.color,
      width: width ?? this.width,
      kind: kind ?? this.kind,
      opacity: opacity ?? this.opacity,
      amplitude: amplitude ?? this.amplitude,
      turns: turns ?? this.turns,
      phase: phase ?? this.phase,
      fadeEdge: fadeEdge ?? this.fadeEdge,
      grow: grow ?? this.grow,
      lineEnd: lineEnd ?? this.lineEnd,
      arrowSize: arrowSize ?? this.arrowSize,
      locked: locked ?? this.locked,
      hidden: hidden ?? this.hidden,
      layer: layer ?? this.layer,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        "type": "spiral",
        ...metaJson(),
        "start": _offToJson(start),
        "endPoint": _offToJson(endPoint),
        "color": color.value,
        "width": width,
        "kind": _enumToJson(kind),
        "opacity": opacity,
        "amplitude": amplitude,
        "turns": turns,
        "phase": phase,
        "fadeEdge": fadeEdge,
        "grow": grow,
        "lineEnd": _enumToJson(lineEnd),
        "arrowSize": arrowSize,
      };

  factory TgSpiral.fromJson(Map<String, dynamic> j) {
    return TgSpiral(
      id: (j["id"] ?? "").toString(),
      start: _offFromJson(j["start"]),
      endPoint: _offFromJson(j["endPoint"]),
      color: _colorFromJson(j["color"], fallback: Colors.black),
      width: _doubleFromJson(j["width"], 4.0),
      kind: _enumFromJson(LineKind.values, j["kind"], LineKind.normal),
      opacity: _doubleFromJson(j["opacity"], 1.0).clamp(0.0, 1.0).toDouble(),
      amplitude: _doubleFromJson(j["amplitude"], 10.0),
      turns: _doubleFromJson(j["turns"], 14.0),
      phase: _doubleFromJson(j["phase"], 0.0),
      fadeEdge: _doubleFromJson(j["fadeEdge"], 0.12).clamp(0.0, 0.49).toDouble(),
      grow: _doubleFromJson(j["grow"], 0.0).clamp(0.0, 4.0).toDouble(),
      lineEnd: _enumFromJson(LineEnd.values, j["lineEnd"], LineEnd.none),
      arrowSize: _doubleFromJson(j["arrowSize"], 16.0),
      locked: j["locked"] == true,
      hidden: j["hidden"] == true,
      layer: (j["layer"] ?? "default").toString(),
      name: j["name"]?.toString(),
      createdAt: _intFromJson(j["createdAt"]),
    );
  }
}

/// =======================
/// РЕДАКТИРУЕМАЯ СПИРАЛЬ (ИСПРАВЛЕННАЯ)
/// =======================
class TgEditableSpiral extends TgSpiral {
  const TgEditableSpiral({
    required super.id,
    required super.start,
    required super.endPoint,
    required super.color,
    required super.width,
    required super.kind,
    super.opacity,
    super.amplitude,
    super.turns,
    super.phase,
    super.fadeEdge,
    super.grow,
    super.lineEnd,
    super.arrowSize,
    super.locked,
    super.hidden,
    super.layer,
    super.name,
    super.createdAt,
    this.selectedPointIndex = -1,
    this.showControlPoints = false,
    this.controlPoints = const [],
  });

  final int selectedPointIndex;
  final bool showControlPoints;
  final List<Offset> controlPoints;

  @override
  TgEditableSpiral copyWith({
    String? id,
    Offset? start,
    Offset? endPoint,
    Color? color,
    double? width,
    LineKind? kind,
    double? opacity,
    double? amplitude,
    double? turns,
    double? phase,
    double? fadeEdge,
    double? grow,
    LineEnd? lineEnd,
    double? arrowSize,
    bool? locked,
    bool? hidden,
    String? layer,
    String? name,
    int? createdAt,
    int? selectedPointIndex,
    bool? showControlPoints,
    List<Offset>? controlPoints,
  }) {
    return TgEditableSpiral(
      id: id ?? this.id,
      start: start ?? this.start,
      endPoint: endPoint ?? this.endPoint,
      color: color ?? this.color,
      width: width ?? this.width,
      kind: kind ?? this.kind,
      opacity: opacity ?? this.opacity,
      amplitude: amplitude ?? this.amplitude,
      turns: turns ?? this.turns,
      phase: phase ?? this.phase,
      fadeEdge: fadeEdge ?? this.fadeEdge,
      grow: grow ?? this.grow,
      lineEnd: lineEnd ?? this.lineEnd,
      arrowSize: arrowSize ?? this.arrowSize,
      locked: locked ?? this.locked,
      hidden: hidden ?? this.hidden,
      layer: layer ?? this.layer,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      selectedPointIndex: selectedPointIndex ?? this.selectedPointIndex,
      showControlPoints: showControlPoints ?? this.showControlPoints,
      controlPoints: controlPoints ?? this.controlPoints,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        "type": "editable_spiral",
        "selectedPointIndex": selectedPointIndex,
        "showControlPoints": showControlPoints,
        "controlPoints": controlPoints.map(_offToJson).toList(),
      };

  factory TgEditableSpiral.fromJson(Map<String, dynamic> j) {
    final base = TgSpiral.fromJson(j);
    final ptsRaw = (j["controlPoints"] is List) ? (j["controlPoints"] as List) : [];
    final pts = <Offset>[];
    for (final x in ptsRaw) {
      pts.add(_offFromJson(x));
    }
    
    return TgEditableSpiral(
      id: base.id,
      start: base.start,
      endPoint: base.endPoint,
      color: base.color,
      width: base.width,
      kind: base.kind,
      opacity: base.opacity,
      amplitude: base.amplitude,
      turns: base.turns,
      phase: base.phase,
      fadeEdge: base.fadeEdge,
      grow: base.grow,
      lineEnd: base.lineEnd,
      arrowSize: base.arrowSize,
      locked: base.locked,
      hidden: base.hidden,
      layer: base.layer,
      name: base.name,
      createdAt: base.createdAt,
      selectedPointIndex: (j["selectedPointIndex"] as num?)?.toInt() ?? -1,
      showControlPoints: j["showControlPoints"] == true,
      controlPoints: pts,
    );
  }
  
  TgEditableSpiral updateControlPoint(int index, Offset newPos) {
    final newControlPoints = List<Offset>.from(controlPoints);
    if (index >= 0 && index < newControlPoints.length) {
      newControlPoints[index] = newPos;
      
      Offset newStart = start;
      Offset newEnd = endPoint;
      
      if (index == 0) {
        newStart = newPos;
      } else if (index == newControlPoints.length - 1) {
        newEnd = newPos;
      }
      
      return copyWith(
        start: newStart,
        endPoint: newEnd,
        controlPoints: newControlPoints,
        selectedPointIndex: index,
      );
    }
    return this;
  }
  
  @override
  Path getPath() {
    if (showControlPoints && controlPoints.isNotEmpty) {
      final path = Path();
      path.moveTo(controlPoints.first.dx, controlPoints.first.dy);
      for (int i = 1; i < controlPoints.length; i++) {
        path.lineTo(controlPoints[i].dx, controlPoints[i].dy);
      }
      return path;
    }
    return super.getPath();
  }
}



/// =======================
/// ZIGZAG
/// =======================
class TgZigzag extends TgElement {
  const TgZigzag({
    required super.id,
    required this.start,
    required this.endPoint,
    required this.color,
    required this.width,
    required this.kind,
    this.opacity = 1.0,
    this.amplitude = 20.0,
    this.frequency = 5.0,
    this.phase = 0.0,
    this.lineEnd = LineEnd.none,
    this.arrowSize = 16.0,
    super.locked,
    super.hidden,
    super.layer,
    super.name,
    super.createdAt,
  });

  final Offset start;
  final Offset endPoint;
  final Color color;
  final double width;
  final LineKind kind;
  final double opacity;
  final double amplitude;
  final double frequency;
  final double phase;
  final LineEnd lineEnd;
  final double arrowSize;

  @override
  Rect bounds() {
    final left = math.min(start.dx, endPoint.dx);
    final top = math.min(start.dy, endPoint.dy);
    final right = math.max(start.dx, endPoint.dx);
    final bottom = math.max(start.dy, endPoint.dy);
    return Rect.fromLTRB(left, top, right, bottom)
        .inflate(amplitude + width + 40);
  }

  @override
  bool hitTest(Offset p, {double tolerance = 0}) {
    if (!bounds().contains(p)) return false;
    final tol = width + 20 + tolerance;
    final points = _generateZigzagPoints(50);

    for (int i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      final ab = b - a;
      final ap = p - a;
      final ab2 = ab.dx * ab.dx + ab.dy * ab.dy;
      if (ab2 > 0) {
        double t = (ap.dx * ab.dx + ap.dy * ab.dy) / ab2;
        t = t.clamp(0.0, 1.0);
        final proj = a + ab * t;
        if ((p - proj).distance <= tol) return true;
      }
    }
    return false;
  }

  List<Offset> _generateZigzagPoints([int segments = 50]) {
    final points = <Offset>[];
    final dir = endPoint - start;
    final length = dir.distance;
    if (length < 1) return points;
    
    segments = (length / 5).round().clamp(20, 200);
    
    final unitDir = dir / length;
    final perp = Offset(-unitDir.dy, unitDir.dx);
    
    for (int i = 0; i <= segments; i++) {
      final t = i / segments;
      final basePos = start + dir * t;
      
      // Используем sign(sin) для острых углов зигзага
      final zigZagValue = math.sin(t * frequency * 2 * math.pi + phase);
      final sharpZigzag = zigZagValue > 0 ? 1.0 : -1.0;
      
      final offset = perp * (sharpZigzag * amplitude);
      points.add(basePos + offset);
    }
    
    return points;
  }

  Path getPath() {
    final path = Path();
    final points = _generateZigzagPoints(50);
    
    if (points.isNotEmpty) {
      path.moveTo(points.first.dx, points.first.dy);
      for (int i = 1; i < points.length; i++) {
        path.lineTo(points[i].dx, points[i].dy);
      }
    }
    return path;
  }

  TgZigzag copyWith({
    String? id,
    Offset? start,
    Offset? endPoint,
    Color? color,
    double? width,
    LineKind? kind,
    double? opacity,
    double? amplitude,
    double? frequency,
    double? phase,
    LineEnd? lineEnd,
    double? arrowSize,
    bool? locked,
    bool? hidden,
    String? layer,
    String? name,
    int? createdAt,
  }) {
    return TgZigzag(
      id: id ?? this.id,
      start: start ?? this.start,
      endPoint: endPoint ?? this.endPoint,
      color: color ?? this.color,
      width: width ?? this.width,
      kind: kind ?? this.kind,
      opacity: opacity ?? this.opacity,
      amplitude: amplitude ?? this.amplitude,
      frequency: frequency ?? this.frequency,
      phase: phase ?? this.phase,
      lineEnd: lineEnd ?? this.lineEnd,
      arrowSize: arrowSize ?? this.arrowSize,
      locked: locked ?? this.locked,
      hidden: hidden ?? this.hidden,
      layer: layer ?? this.layer,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        "type": "zigzag",
        ...metaJson(),
        "start": _offToJson(start),
        "endPoint": _offToJson(endPoint),
        "color": color.value,
        "width": width,
        "kind": _enumToJson(kind),
        "opacity": opacity,
        "amplitude": amplitude,
        "frequency": frequency,
        "phase": phase,
        "lineEnd": _enumToJson(lineEnd),
        "arrowSize": arrowSize,
      };

  factory TgZigzag.fromJson(Map<String, dynamic> j) {
    return TgZigzag(
      id: (j["id"] ?? "").toString(),
      start: _offFromJson(j["start"]),
      endPoint: _offFromJson(j["endPoint"]),
      color: _colorFromJson(j["color"], fallback: Colors.black),
      width: _doubleFromJson(j["width"], 4.0),
      kind: _enumFromJson(LineKind.values, j["kind"], LineKind.normal),
      opacity: _doubleFromJson(j["opacity"], 1.0).clamp(0.0, 1.0).toDouble(),
      amplitude: _doubleFromJson(j["amplitude"], 20.0),
      frequency: _doubleFromJson(j["frequency"], 5.0),
      phase: _doubleFromJson(j["phase"], 0.0),
      lineEnd: _enumFromJson(LineEnd.values, j["lineEnd"], LineEnd.none),
      arrowSize: _doubleFromJson(j["arrowSize"], 16.0),
      locked: j["locked"] == true,
      hidden: j["hidden"] == true,
      layer: (j["layer"] ?? "default").toString(),
      name: j["name"]?.toString(),
      createdAt: _intFromJson(j["createdAt"]),
    );
  }
}

/// =======================
/// РЕДАКТИРУЕМЫЙ ЗИГЗАГ (ИСПРАВЛЕННЫЙ)
/// =======================
class TgEditableZigzag extends TgZigzag {
  const TgEditableZigzag({
    required super.id,
    required super.start,
    required super.endPoint,
    required super.color,
    required super.width,
    required super.kind,
    super.opacity,
    super.amplitude,
    super.frequency,
    super.phase,
    super.lineEnd,
    super.arrowSize,
    super.locked,
    super.hidden,
    super.layer,
    super.name,
    super.createdAt,
    this.selectedPointIndex = -1,
    this.showControlPoints = false,
    this.controlPoints = const [],
  });

  final int selectedPointIndex;
  final bool showControlPoints;
  final List<Offset> controlPoints;

  @override
  TgEditableZigzag copyWith({
    String? id,
    Offset? start,
    Offset? endPoint,
    Color? color,
    double? width,
    LineKind? kind,
    double? opacity,
    double? amplitude,
    double? frequency,
    double? phase,
    LineEnd? lineEnd,
    double? arrowSize,
    bool? locked,
    bool? hidden,
    String? layer,
    String? name,
    int? createdAt,
    int? selectedPointIndex,
    bool? showControlPoints,
    List<Offset>? controlPoints,
  }) {
    return TgEditableZigzag(
      id: id ?? this.id,
      start: start ?? this.start,
      endPoint: endPoint ?? this.endPoint,
      color: color ?? this.color,
      width: width ?? this.width,
      kind: kind ?? this.kind,
      opacity: opacity ?? this.opacity,
      amplitude: amplitude ?? this.amplitude,
      frequency: frequency ?? this.frequency,
      phase: phase ?? this.phase,
      lineEnd: lineEnd ?? this.lineEnd,
      arrowSize: arrowSize ?? this.arrowSize,
      locked: locked ?? this.locked,
      hidden: hidden ?? this.hidden,
      layer: layer ?? this.layer,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      selectedPointIndex: selectedPointIndex ?? this.selectedPointIndex,
      showControlPoints: showControlPoints ?? this.showControlPoints,
      controlPoints: controlPoints ?? this.controlPoints,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        ...super.toJson(),
        "type": "editable_zigzag",
        "selectedPointIndex": selectedPointIndex,
        "showControlPoints": showControlPoints,
        "controlPoints": controlPoints.map(_offToJson).toList(),
      };

  factory TgEditableZigzag.fromJson(Map<String, dynamic> j) {
    final base = TgZigzag.fromJson(j);
    final ptsRaw = (j["controlPoints"] is List) ? (j["controlPoints"] as List) : [];
    final pts = <Offset>[];
    for (final x in ptsRaw) {
      pts.add(_offFromJson(x));
    }
    
    return TgEditableZigzag(
      id: base.id,
      start: base.start,
      endPoint: base.endPoint,
      color: base.color,
      width: base.width,
      kind: base.kind,
      opacity: base.opacity,
      amplitude: base.amplitude,
      frequency: base.frequency,
      phase: base.phase,
      lineEnd: base.lineEnd,
      arrowSize: base.arrowSize,
      locked: base.locked,
      hidden: base.hidden,
      layer: base.layer,
      name: base.name,
      createdAt: base.createdAt,
      selectedPointIndex: (j["selectedPointIndex"] as num?)?.toInt() ?? -1,
      showControlPoints: j["showControlPoints"] == true,
      controlPoints: pts,
    );
  }
  
  TgEditableZigzag updateControlPoint(int index, Offset newPos) {
    final newControlPoints = List<Offset>.from(controlPoints);
    if (index >= 0 && index < newControlPoints.length) {
      newControlPoints[index] = newPos;
      
      Offset newStart = start;
      Offset newEnd = endPoint;
      
      if (index == 0) {
        newStart = newPos;
      } else if (index == newControlPoints.length - 1) {
        newEnd = newPos;
      }
      
      return copyWith(
        start: newStart,
        endPoint: newEnd,
        controlPoints: newControlPoints,
        selectedPointIndex: index,
      );
    }
    return this;
  }
  
  @override
  Path getPath() {
    if (showControlPoints && controlPoints.isNotEmpty) {
      final path = Path();
      path.moveTo(controlPoints.first.dx, controlPoints.first.dy);
      for (int i = 1; i < controlPoints.length; i++) {
        path.lineTo(controlPoints[i].dx, controlPoints[i].dy);
      }
      return path;
    }
    return super.getPath();
  }
}